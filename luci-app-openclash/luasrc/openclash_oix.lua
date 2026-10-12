-- Account-managed configurations keep transport details inside the router.
local nixio = require "nixio"
local nfs = require "nixio.fs"
local json = require "luci.jsonc"
local uci_model = require "luci.model.uci"
local M = {}
local NAME = "oixCloud - smart"
local SOURCE = "/etc/openclash/config/" .. NAME .. ".yaml"
local PROVIDER = "/etc/openclash/proxy_provider/oixCloud"
local API = "https://oix-api.dler.io/api/v1/"
local MAX_RESPONSE = 16 * 1024 * 1024

-- Anonymous files avoid putting credentials in argv, shell text or named files.
local function run(argv, input, env)
	local inf = nixio.mkstemp("openclash-oix-in")
	local out = nixio.mkstemp("openclash-oix-out")
	if not inf or not out then
		if inf then inf:close() end
		if out then out:close() end
		return nil
	end
	if input and not inf:writeall(input) then inf:close(); out:close(); return nil end
	inf:seek(0)
	local pid = nixio.fork()
	if pid == 0 then
		nixio.dup(inf, nixio.stdin)
		nixio.dup(out, nixio.stdout)
		local null = nixio.open("/dev/null", "w")
		if null then nixio.dup(null, nixio.stderr); null:close() end
		inf:close(); out:close()
		for key, value in pairs(env or {}) do nixio.setenv(key, value) end
		nixio.exec(unpack(argv))
		os.exit(127)
	end
	inf:close()
	if not pid then out:close(); return nil end
	local _, reason, code = nixio.waitpid(pid)
	local size = out:stat("size")
	if reason ~= "exited" or code ~= 0 or not size or size > MAX_RESPONSE then
		out:close()
		return nil
	end
	out:seek(0)
	local chunks = {}
	while true do
		local chunk = out:read(8192)
		if not chunk then out:close(); return nil end
		if chunk == "" then break end
		chunks[#chunks + 1] = chunk
	end
	out:close()
	return table.concat(chunks)
end

local function curl_quote(value)
	return '"' .. tostring(value):gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\r', '\\r'):gsub('\n', '\\n') .. '"'
end

local function request(url, method, token, payload, local_request, timeout)
	local options = {
		"silent", "show-error", "connect-timeout = 5", "max-time = " .. (timeout or 45),
		"max-filesize = 16777216", 'write-out = "\\n%{http_code}"',
		"url = " .. curl_quote(url), "request = " .. curl_quote(method),
		'header = "Content-Type: application/json"',
	}
	if local_request then
		options[#options + 1] = 'noproxy = "*"'
	else
		options[#options + 1] = 'proto = "=https"'
		options[#options + 1] = 'user-agent = "OpenClash for oixCloud"'
		options[#options + 1] = 'header = "X-oixCloud-Client: openclash"'
	end
	if token and token ~= "" then
		if token:find("[%c]") then return nil end
		options[#options + 1] = "header = " .. curl_quote("Authorization: Bearer " .. token)
	end
	if payload then options[#options + 1] = "data-binary = " .. curl_quote(json.stringify(payload)) end
	local raw = run({"/usr/bin/curl", "--config", "-"}, table.concat(options, "\n") .. "\n")
	if not raw then return nil end
	local body, status = raw:match("^(.*)\n(%d%d%d)$")
	return body, tonumber(status)
end

function M.api(path, token, payload)
	local body, status = request(API .. path, "POST", token, payload)
	if status ~= 200 or not body then return nil end
	local ok, result = pcall(json.parse, body)
	return ok and type(result) == "table" and result.ret == 200 and result or nil
end

local function core_request(path, method, payload, timeout)
	local c = uci_model.cursor()
	local port = tonumber(c:get("openclash", "config", "cn_port")) or 9090
	if port < 1 or port > 65535 or port % 1 ~= 0 then return nil end
	return request("http://127.0.0.1:" .. port .. path, method or "GET", c:get("openclash", "config", "dashboard_password"), payload, true, timeout)
end

local function valid_token(token)
	return type(token) == "string" and #token >= 32 and #token <= 128 and not token:find("[^0-9a-f]")
end

local function locked(action)
	local fd = nixio.open("/tmp/lock/openclash_oix.lock", "w", 384)
	if not fd then return nil, "Unable to save managed configuration" end
	if not fd:lock("tlock") then fd:close(); return nil, "An oixCloud operation is already in progress" end
	local ok, result, err = pcall(action)
	fd:lock("ulock"); fd:close()
	if not ok then return nil, "Unable to load managed configuration" end
	return result, err
end

local function private_write(path, data)
	local tmp = path .. ".oix-" .. nixio.getpid()
	local fd = nixio.open(tmp, nixio.open_flags("creat", "excl", "wronly"), 384)
	if not fd then return false end
	local ok = fd:writeall(data) and fd:sync()
	fd:close()
	if ok then ok = nfs.rename(tmp, path) end
	if not ok then nfs.unlink(tmp) end
	return ok
end

local function core_path(c)
	return c:get("openclash", "config", "small_flash_memory") == "1"
		and "/tmp/etc/openclash/core/clash_meta" or "/etc/openclash/core/clash_meta"
end

local function ensure_core(c, progress)
	progress("downloading_core", "Checking oixCloud core...")
	-- The install-only mode avoids a restart halfway through login.
	if not run({"/usr/share/openclash/openclash_core.sh", "Oix"}, nil, {OIX_INSTALL_ONLY="1"}) then
		return nil, "Unable to update the oixCloud core"
	end
	local version = run({core_path(c), "-v"})
	if not version or not version:find("oix", 1, true) then return nil, "Unable to update the oixCloud core" end
	return true
end

local function prepare(token, c, progress)
	progress("fetching_sub", "Fetching managed configuration...")
	local result = M.api("managed/clash", token)
	local url = result and result.ret == 200 and result.openclash
	if type(url) ~= "string" or not url:match("^https://[^/%s]+/") or url:find("[%c]") then
		return nil, "Unable to fetch managed configuration"
	end
	local body, status = request(url, "GET")
	if status ~= 200 or not body or body == "" then return nil, "Unable to fetch managed configuration" end
	local tmp = SOURCE .. ".oix-check-" .. nixio.getpid()
	if not private_write(tmp, body) then return nil, "Unable to save managed configuration" end
	-- Keep the base routing config; the signed core API owns all node delivery.
	-- No ordinary subscription URL is retained in the generated provider.
	local ruby = [[
require 'yaml'
p = ARGV.fetch(0)
c = YAML.load_file(p)
raise 'invalid configuration' unless c.is_a?(Hash) && c['proxy-providers'].is_a?(Hash) && c['proxy-providers']['oixCloud'].is_a?(Hash)
g = c['proxy-groups']
raise 'missing managed groups' unless g.is_a?(Array) && g.any? { |v| v.is_a?(Hash) && Array(v['use']).include?('oixCloud') }
c['proxy-providers']['oixCloud'] = {'type'=>'file', 'path'=>'./proxy_provider/oixCloud'}
File.open(p, 'w', 0600) { |f| f.write(YAML.dump(c)) }
]]
	local cleaned = run({"/usr/bin/ruby", "-e", ruby, tmp})
	local checked = cleaned and run({core_path(c), "-t", "-d", "/etc/openclash", "-f", tmp}, nil, {OIX_TOKEN=token, OIX_CLIENT="openclash"})
	if not checked then nfs.unlink(tmp); return nil, "Invalid managed configuration" end
	return tmp
end

local function verify_loaded(token, progress)
	progress("loading", "Loading managed nodes...")
	local ready = false
	for _ = 1, 10 do
		local _, status = core_request("/version", "GET", nil, 2)
		if status == 200 then ready = true; break end
		nixio.nanosleep(1)
	end
	if not ready then return nil, "The oixCloud core did not start" end
	local _, status = core_request("/oix/login", "POST", {token=token})
	if status ~= 204 then return nil, "Unable to load managed nodes" end
	local body, provider_status = core_request("/providers/proxies/oixCloud")
	local ok, provider = pcall(json.parse, body or "")
	if provider_status ~= 200 or not ok or type(provider) ~= "table" or provider.vehicleType ~= "File"
		or type(provider.proxies) ~= "table" or #provider.proxies == 0 then
		return nil, "No managed nodes were loaded"
	end
	local names = {}
	for _, proxy in ipairs(provider.proxies) do
		if type(proxy) == "table" and type(proxy.name) == "string" then names[proxy.name] = true end
	end
	local groups_body, groups_status = core_request("/proxies")
	local parsed, groups = pcall(json.parse, groups_body or "")
	if groups_status == 200 and parsed and type(groups) == "table" and type(groups.proxies) == "table" then
		for name, group in pairs(groups.proxies) do
			if name ~= "GLOBAL" and type(group) == "table" and type(group.all) == "table" then
				for _, member in ipairs(group.all) do if names[member] then return true end end
			end
		end
	end
	return nil, "Managed nodes are not referenced by any proxy group"
end

local STATE_KEYS = {"oix_token", "config_path", "enable", "oix_previous_config", "oix_email", "oix_passwd",
	"oix_checkin", "oix_checkin_interval", "oix_checkin_multiple", "oix_params", "oix_default_params", "oix_show_info_page"}

local function subscriptions(c)
	local result = {}
	c:foreach("openclash", "config_subscribe", function(s)
		if s.name == NAME then
			local values = {}
			for key, value in pairs(s) do if key:sub(1, 1) ~= "." then values[key] = value end end
			result[#result + 1] = {id=s[".name"], values=values}
		end
	end)
	return result
end

local function clear_subscriptions(c)
	for _, s in ipairs(subscriptions(c)) do assert(c:delete("openclash", s.id)) end
end

local function snapshot(c)
	local saved = {values={}, sections=subscriptions(c), files={}}
	for _, key in ipairs(STATE_KEYS) do saved.values[key] = c:get("openclash", "config", key) end
	for _, path in ipairs({SOURCE, "/etc/openclash/" .. NAME .. ".yaml", PROVIDER, "/etc/openclash/.oix_token"}) do
		local data = nfs.readfile(path)
		if not data and nfs.access(path) then return nil end
		saved.files[path] = data or false
	end
	return saved
end

local function delete_option(c, key)
	if c:get("openclash", "config", key) ~= nil then assert(c:delete("openclash", "config", key)) end
end

local function restore(c, saved, stopped)
	-- Never restore files while an updater may still be writing them.
	if stopped and not run({"/etc/init.d/openclash", "stop"}) then return false end
	local called, committed = pcall(function()
		for _, key in ipairs(STATE_KEYS) do
			if saved.values[key] ~= nil then assert(c:set("openclash", "config", key, saved.values[key]))
			else delete_option(c, key) end
		end
		clear_subscriptions(c)
		for _, s in ipairs(saved.sections) do assert(c:section("openclash", "config_subscribe", s.id, s.values)) end
		return c:commit("openclash")
	end)
	local ok = called and committed
	for path, data in pairs(saved.files) do
		-- Before restart, only the source changed; leave the live updater's files alone.
		if stopped or path == SOURCE then
			local written
			if data then written = private_write(path, data)
			else written = not nfs.access(path) or nfs.unlink(path) end
			if not written then ok = false end
		end
	end
	if stopped and ok and saved.values.enable == "1" and saved.values.config_path and nfs.access(saved.values.config_path) then
		ok = run({"/etc/init.d/openclash", "start"}) ~= nil
	end
	return ok
end

local function activate(token, progress, install)
	local c = uci_model.cursor()
	if install then
		local ok, err = ensure_core(c, progress)
		if not ok then return nil, err end
	end
	local tmp, err = prepare(token, c, progress)
	if not tmp then return nil, err end
	local saved = snapshot(c)
	if not saved then nfs.unlink(tmp); return nil, "Unable to save managed configuration" end
	if not nfs.rename(tmp, SOURCE) then nfs.unlink(tmp); return nil, "Unable to save managed configuration" end
	local previous = saved.values
	local should_load = install or (previous.config_path == SOURCE and previous.enable == "1")
	local stopped = false
	-- Include marker migration in the same commit as token/config selection.
	local called, ok = pcall(function()
		assert(c:set("openclash", "config", "oix_token", token))
		if install then
			if previous.config_path ~= SOURCE and previous.config_path and nfs.access(previous.config_path) then
				assert(c:set("openclash", "config", "oix_previous_config", previous.config_path))
			end
			assert(c:set("openclash", "config", "config_path", SOURCE))
			assert(c:set("openclash", "config", "enable", "1"))
		end
		clear_subscriptions(c)
		assert(c:section("openclash", "config_subscribe", nil, {name=NAME, oix_managed="1", enabled="0"}))
		delete_option(c, "oix_email")
		delete_option(c, "oix_passwd")
		if not c:commit("openclash") then err = "Unable to save managed configuration"; return false end
		if should_load then
			progress("restarting", "Restarting...")
			stopped = true
			if not run({"/etc/init.d/openclash", "restart"}) then err = "The oixCloud core did not start"; return false end
			local loaded
			loaded, err = verify_loaded(token, progress)
			return loaded
		end
		return true
	end)
	if not called or not ok then
		if not restore(c, saved, stopped) then return nil, "Unable to restore the previous configuration. Check OpenClash status" end
		return nil, err or "Unable to save managed configuration"
	end
	nfs.unlink("/tmp/oix_info")
	nfs.unlink("/tmp/oix_checkin")
	return true
end

local function account_token(token)
	if not valid_token(token) then return nil, "invalid token" end
	local info = M.api("information", token)
	if not info or info.ret ~= 200 or type(info.data) ~= "table" then return nil, "login failed" end
	if type(info.data.token_client) == "string" and info.data.token_client ~= "" and info.data.token_client ~= "openclash" then
		local rebound = M.api("token/rebind", token)
		if rebound and rebound.ret == 200 and type(rebound.data) == "table"
			and rebound.data.token_client == "openclash" and valid_token(rebound.data.token) then
			return rebound.data.token
		end
		return nil, "Unable to select the OpenClash account"
	end
	return token
end

function M.login(input, progress)
	progress = progress or function() end
	return locked(function()
		local token = input.token
		if token and token ~= "" then
			progress("logging_in", "Logging in...")
			local err
			token, err = account_token(token)
			if not token then return nil, err end
		else
			if type(input.email) ~= "string" or input.email == "" or type(input.passwd) ~= "string" or input.passwd == "" then return nil, "email or passwd is wrong" end
			progress("logging_in", "Logging in...")
			local result = M.api("login", nil, {email=input.email, passwd=input.passwd, token_expire="365"})
			if not result or result.ret ~= 200 or type(result.data) ~= "table" or not valid_token(result.data.token) then return nil, "login failed" end
			token = result.data.token
		end
		return activate(token, progress, true)
	end)
end

function M.refresh(progress)
	return locked(function()
		local token = uci_model.cursor():get("openclash", "config", "oix_token")
		if not valid_token(token) then return nil, "Please sign in to oixCloud first" end
		local err
		token, err = account_token(token)
		if not token then return nil, err end
		return activate(token, progress or function() end, false)
	end)
end

function M.save_settings(input)
	return locked(function()
		local settings = {}
		for key, limit in pairs({checkin=1, show_info_page=1, interval=720, multiple=100}) do
			local value = input[key]
			if value ~= nil then
				local flag = key == "checkin" or key == "show_info_page"
				local number = tonumber(value)
				if flag then
					if value ~= "0" and value ~= "1" then return false end
				elseif not number or number % 1 ~= 0 or number < 1 or number > limit then
					return false
				end
				local option = (key == "interval" or key == "multiple") and "oix_checkin_" .. key or "oix_" .. key
				settings[option] = flag and value or tostring(number)
			end
		end
		local c = uci_model.cursor()
		for key, value in pairs(settings) do assert(c:set("openclash", "config", key, value)) end
		return c:commit("openclash")
	end)
end

function M.logout()
	return locked(function()
		local c = uci_model.cursor()
		local owns_config = valid_token(c:get("openclash", "config", "oix_token")) or nfs.access("/etc/openclash/.oix_token")
		c:foreach("openclash", "config_subscribe", function(section)
			if section.name == NAME and section.oix_managed == "1" then owns_config = true end
		end)
		if not owns_config then return true end
		local saved = snapshot(c)
		if not saved then return nil, "Unable to save managed configuration" end
		local managed_active = saved.values.config_path == SOURCE
		local previous = saved.values.oix_previous_config
		-- Stop before deleting state, so the running updater cannot recreate it.
		if not run({"/etc/init.d/openclash", "stop"}) then return nil, "Unable to stop the oixCloud core" end
		local err = "Unable to save managed configuration"
		local called, ok = pcall(function()
			for _, key in ipairs(STATE_KEYS) do
				if key ~= "config_path" and key ~= "enable" then delete_option(c, key) end
			end
			clear_subscriptions(c)
			if managed_active then
				if previous and previous ~= SOURCE and nfs.access(previous) then assert(c:set("openclash", "config", "config_path", previous))
				else delete_option(c, "config_path"); assert(c:set("openclash", "config", "enable", "0")) end
			end
			if not c:commit("openclash") then return false end
			err = "Unable to remove managed configuration"
			for _, path in ipairs({SOURCE, "/etc/openclash/" .. NAME .. ".yaml", PROVIDER, "/etc/openclash/.oix_token", "/etc/openclash/.oix_profile", "/tmp/oix_info", "/tmp/oix_checkin"}) do
				if nfs.access(path) and not nfs.unlink(path) then return false end
			end
			return true
		end)
		if not called or not ok then
			if not restore(c, saved, true) then return nil, "Unable to restore the previous configuration. Check OpenClash status" end
			return nil, err
		end
		if c:get("openclash", "config", "enable") == "1" and not run({"/etc/init.d/openclash", "start"}) then
			return nil, "The previous configuration could not be started"
		end
		return true
	end)
end

function M.information()
	return locked(function()
		local token = uci_model.cursor():get("openclash", "config", "oix_token")
		if not valid_token(token) then return nil end
		local path = "/tmp/oix_info"
		local stat = nfs.stat(path)
		local age = stat and os.time() - stat.mtime
		if stat and stat.type == "reg" and stat.size <= MAX_RESPONSE and age >= 0 and age < 900 and nfs.chmod(path, 384) then
			local ok, info = pcall(json.parse, nfs.readfile(path) or "")
			if ok and type(info) == "table" and info.ret == 200 then return info end
		end
		local info = M.api("information", token)
		if info and info.ret == 200 then private_write(path, json.stringify(info)) end
		return info
	end)
end

function M.checkin(scheduled)
	return locked(function()
		local c = uci_model.cursor()
		local token = c:get("openclash", "config", "oix_token")
		if not valid_token(token) then return nil end
		local path = "/tmp/oix_checkin"
		if scheduled then
			if c:get("openclash", "config", "oix_checkin") ~= "1" then return nil end
			local interval = math.max(1, math.min(720, tonumber(c:get("openclash", "config", "oix_checkin_interval")) or 1))
			local stat = nfs.stat(path)
			local age = stat and os.time() - stat.mtime
			if age and age >= 0 and age < interval * 3600 then return nil end
		end
		local multiple = math.max(1, math.min(100, tonumber(c:get("openclash", "config", "oix_checkin_multiple")) or 1))
		local info = M.api("checkin", token, {multiple=tostring(multiple)})
		private_write(path, json.stringify(info or {ret=503}))
		local success = info and info.ret == 200
		if success then nfs.unlink("/tmp/oix_info") end
		local log = io.open("/tmp/openclash.log", "a")
		if log then log:write(os.date("%Y-%m-%d %H:%M:%S"), " [Info] oixCloud Checkin ", success and "Successful" or "Failed", "\n"); log:close() end
		return info
	end)
end

return M
