#!/usr/bin/lua

require "nixio"
require "luci.sys"
require "luci.model.uci"
local fs = require "luci.openclash"
local json = require "luci.jsonc"

local SYS = luci.sys

local M = {}

local VERSION_CACHE_FILE = "/tmp/openclash_version_history.json"
local CDN_CACHE_FILE = "/tmp/openclash_cdn_info.json"

local function trim(s)
	if not s then return "" end
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function M.is_valid_version(s)
	if not s or s == "" then return false end
	s = trim(s)
	if s == "" then return false end
	if s:match("^<") then return false end
	return true
end

function M.is_oix_mode()
	local oix_token = fs.uci_get_config("config", "oix_token") or ""
	return oix_token ~= ""
end

function try_read(fd, maxlen)
	local pfds = {
		{ fd = fd, events = nixio.poll_flags("in", "hup", "err") }
	}
	local nfds = nixio.poll(pfds, 0)
	if nfds and nfds > 0 then
		local buf = fd:read(maxlen or 4096)
		if buf and #buf > 0 then
			return buf
		end
	end
	return nil
end

local function read_json(path)
	if not fs.access(path) then return nil end
	local raw = fs.readfile(path)
	if not raw or raw == "" then return nil end
	local ok, parsed = pcall(json.parse, raw)
	if ok and parsed and type(parsed) == "table" then
		return parsed
	end
	return nil
end

local function write_json(path, data)
	local tmp = path .. ".tmp"
	fs.writefile(tmp, json.stringify(data))
	os.rename(tmp, path)
end

local function read_version_cache()
	return read_json(VERSION_CACHE_FILE)
end

local function update_version_cache(updater)
	local parsed = read_version_cache() or {}
	updater(parsed)
	write_json(VERSION_CACHE_FILE, parsed)
end

local function build_latest_url(mod, owner, branch, file)
	if mod == "0" or mod == "" then
		return "https://raw.githubusercontent.com/vernesong/OpenClash/" .. owner .. "/" .. branch .. "/" .. file
	end
	if mod == "https://cdn.jsdelivr.net/" or mod == "https://fastly.jsdelivr.net/" or mod == "https://testingcf.jsdelivr.net/" then
		return mod .. "gh/vernesong/OpenClash@" .. owner .. "/" .. branch .. "/" .. file
	end
	return mod .. "https://raw.githubusercontent.com/vernesong/OpenClash/" .. owner .. "/" .. branch .. "/" .. file
end

function M.prepare_oix_cdn_data(force)
	if not M.is_oix_mode() then
		return false, "", ""
	end

	local parsed = read_version_cache()
	if parsed and parsed.oix and parsed.oix.cached_at then
		local age = os.time() - parsed.oix.cached_at
		local ttl = parsed.oix.cache_ttl or 300
		if age < 5 or (not force and age < ttl) then
			return true, parsed.oix.ver or "", parsed.oix.error or ""
		end
	end

	local function fork_oix_version(url)
		local fdi, fdo = nixio.pipe()
		if not fdi or not fdo then return nil end
		local cmd = string.format('curl -sL -m 3 --connect-timeout 3 "%s" 2>/dev/null', url)
		local child = nixio.fork()
		if child > 0 then
			fdo:close()
			return { pid = child, fdi = fdi, buf = "" }
		elseif child == 0 then
			nixio.dup(fdo, nixio.stdout)
			fdi:close()
			fdo:close()
			nixio.exec("/bin/sh", "-c", cmd)
		else
			if fdi then fdi:close() end
			if fdo then fdo:close() end
			return nil
		end
	end

	local jobs = {}
	local dl_job = fork_oix_version("https://dl.dler.io/mihomo-oix/version.txt?tag=Pre-Alpha")
	if dl_job then jobs[#jobs + 1] = dl_job end
	local gh_job = fork_oix_version("https://github.com/vernesong/mihomo-oix/releases/download/Pre-Alpha/version.txt")
	if gh_job then jobs[#jobs + 1] = gh_job end

	if #jobs == 0 then
		return true, "", "error"
	end

	local ver = ""
	local delay = 50000000
	local max_wait = 40
	for _ = 1, max_wait do
		for _, job in ipairs(jobs) do
			if not job.done then
				local ok_r, buf = pcall(try_read, job.fdi, 4096)
				if ok_r and buf then job.buf = job.buf .. buf end
				local ok_w, wpid = pcall(nixio.waitpid, job.pid, "nohang")
				if ok_w and wpid then
					while true do
						local ok_b, b = pcall(try_read, job.fdi, 4096)
						if not ok_b or not b then break end
						job.buf = job.buf .. b
					end
					pcall(job.fdi.close, job.fdi)
					job.done = true
				end
			end
		end
		for _, job in ipairs(jobs) do
			if job.done and ver == "" then
				local candidate = trim(job.buf:gsub("[\n\r]+", ""))
				if M.is_valid_version(candidate) then
					ver = candidate
				end
			end
		end
		if ver ~= "" then
			for _, job in ipairs(jobs) do
				if not job.done then
					pcall(job.fdi.close, job.fdi)
					nixio.kill(job.pid, 9)
				end
			end
			update_version_cache(function(p) p.oix = { ver = ver, error = "", cache_ttl = 300, cached_at = os.time() } end)
			return true, ver, ""
		end
		local all_done = true
		for _, job in ipairs(jobs) do
			if not job.done then all_done = false break end
		end
		if all_done then break end
		nixio.nanosleep(0, delay)
		delay = math.min(delay * 2, 200000000)
	end

	for _, job in ipairs(jobs) do
		if not job.done then
			pcall(job.fdi.close, job.fdi)
			nixio.kill(job.pid, 9)
		end
	end

	update_version_cache(function(p) p.oix = { ver = "", error = "error", cache_ttl = 5, cached_at = os.time() } end)
	return true, "", "error"
end

local function fork_file_fetch(sha, file_path)
	local fdi, fdo = nixio.pipe()
	if not fdi or not fdo then return nil end
	local url = "https://raw.githubusercontent.com/vernesong/OpenClash/" .. sha .. "/" .. file_path
	local cmd = 'curl -sL -m 10 "' .. url .. '" 2>/dev/null'
	local child = nixio.fork()
	if child > 0 then
		fdo:close()
		return { pid = child, fdi = fdi, buf = "", sha = sha }
	elseif child == 0 then
		nixio.dup(fdo, nixio.stdout)
		fdi:close()
		fdo:close()
		nixio.exec("/bin/sh", "-c", cmd)
	else
		if fdi then fdi:close() end
		if fdo then fdo:close() end
		return nil
	end
end

local function collect_fork_results(jobs, max_jobs)
	local results = {}
	local active = 0
	local delay = 50000000
	local max_iter = 150

	for _ = 1, max_iter do
		while active < max_jobs do
			local launched = false
			for _, job in ipairs(jobs) do
				if not job.launched then
					job.launched = true
					active = active + 1
					launched = true
					break
				end
			end
			if not launched then break end
		end

		for _, job in ipairs(jobs) do
			if job.launched and not job.done then
				local ok_r, buf = pcall(try_read, job.fdi, 4096)
				if ok_r and buf then job.buf = job.buf .. buf end
				local ok_w, wpid = pcall(nixio.waitpid, job.pid, "nohang")
				if ok_w and wpid then
					while true do
						local ok_b, b = pcall(try_read, job.fdi, 4096)
						if not ok_b or not b then break end
						job.buf = job.buf .. b
					end
					pcall(job.fdi.close, job.fdi)
					job.done = true
					active = active - 1
					if job.buf ~= "" then
						results[job.sha] = trim(job.buf)
					end
				end
			end
		end

		local all_done = true
		for _, job in ipairs(jobs) do
			if not job.done then all_done = false break end
		end
		if all_done then break end

		nixio.nanosleep(0, delay)
		delay = math.min(delay * 2, 200000000)
	end

	for _, job in ipairs(jobs) do
		if not job.done then
			pcall(job.fdi.close, job.fdi)
			nixio.kill(job.pid, 9)
		end
	end

	return results
end

local function html_unescape(s)
	if not s then return "" end
	s = s:gsub("&amp;", "&")
	s = s:gsub("&lt;", "<")
	s = s:gsub("&gt;", ">")
	s = s:gsub("&quot;", '"')
	s = s:gsub("&#39;", "'")
	s = s:gsub("&#x27;", "'")
	return s
end

local function fetch_commit_feed(ref, path)
	local url = "https://github.com/vernesong/OpenClash/commits/" .. ref .. "/" .. path .. ".atom"
	return SYS.exec('curl -sL -m 10 "' .. url .. '" 2>/dev/null')
end

local function parse_commit_feed(raw, max_count)
	local commits = {}
	if raw and raw ~= "" then
		local n = 0
		for entry in raw:gmatch("<entry>(.-)</entry>") do
			n = n + 1
			if n > max_count then break end
			local sha = entry:match("<id>[^<]*/([0-9a-f]+)</id>")
			if sha then
				local date = entry:match("<updated>(.-)</updated>") or ""
				local title = entry:match("<title>(.-)</title>") or ""
				title = trim(title)
				commits[#commits + 1] = { sha = sha, date = date, message = html_unescape(title) }
			end
		end
	end
	return commits
end

function M.fetch_version_history(branch, force, cdn, latest_only)
	local result = { plugin = {}, core_meta = {}, core_smart = {}, latest = nil, error = nil, oix_ver = "" }
	local cur_oix = M.is_oix_mode()
	local skip_core = cur_oix

	if not force then
		local parsed = read_version_cache()
		if parsed and parsed[branch] and parsed[branch].cached_at then
			local blk = parsed[branch]
			local ttl = blk.cache_ttl or 300
			if os.time() - blk.cached_at < ttl and blk.oix == cur_oix then
				if latest_only then
					local lt = blk.latest
					if lt and lt.plugin and lt.plugin ~= "" and (cur_oix or (lt.core_meta and lt.core_meta ~= "")) then
						return blk
					end
				elseif blk.plugin and #blk.plugin > 0 then
					return blk
				end
			end
		end
	end

	if latest_only then
		local github_address_mod = fs.uci_get_config("config", "github_address_mod") or "0"
		if cdn and cdn ~= "" then
			github_address_mod = cdn
			if github_address_mod:match("raw%.githubusercontent%.com") then
				github_address_mod = "0"
			end
		end

		local plugin_latest = ""
		local core_meta_latest = ""
		local core_smart_latest = ""

		local plugin_url = build_latest_url(github_address_mod, "package", branch, "version")
		local plugin_raw = SYS.exec('curl -sL -m 10 "' .. plugin_url .. '" 2>/dev/null')
		if plugin_raw and plugin_raw ~= "" then
			plugin_latest = trim(plugin_raw:match("^[^\n\r]*") or "")
		end

		if not cur_oix then
			local core_url = build_latest_url(github_address_mod, "core", branch, "core_version")
			local core_raw = SYS.exec('curl -sL -m 10 "' .. core_url .. '" 2>/dev/null')
			if core_raw and core_raw ~= "" then
				core_meta_latest = trim(core_raw:match("^[^\n\r]*") or "")
				local after = core_raw:match("[\n\r]+(.*)")
				if after then
					core_smart_latest = trim(after:match("^[^\n\r]*") or "")
				end
			end
		end

		result.latest = { plugin = plugin_latest, core_meta = core_meta_latest, core_smart = core_smart_latest }
		if plugin_latest == "" then
			result.error = "network_error"
		end
		if cur_oix then
			M.prepare_oix_cdn_data(force)
		end
		result.cache_ttl = (plugin_latest == "") and 5 or 300
		result.cached_at = os.time()
		result.oix = cur_oix

		update_version_cache(function(parsed)
			local blk = parsed[branch] or {}
			blk.latest = result.latest
			blk.error = result.error
			blk.cache_ttl = result.cache_ttl
			blk.cached_at = result.cached_at
			blk.oix = cur_oix
			blk.plugin = nil
			blk.core_meta = nil
			blk.core_smart = nil
			blk.oix_ver = nil
			parsed[branch] = blk
		end)

		return result
	end

	local plugin_feed = fetch_commit_feed("package", branch .. "/version")
	local plugin_commits = parse_commit_feed(plugin_feed, 5)
	if #plugin_commits > 0 then
		local file_jobs = {}
		for _, c in ipairs(plugin_commits) do
			local job = fork_file_fetch(c.sha, branch .. "/version")
			if job then file_jobs[#file_jobs + 1] = job end
		end

		local file_results = collect_fork_results(file_jobs, 3)

		for _, c in ipairs(plugin_commits) do
			local raw = file_results[c.sha]
			local ver
			if raw and raw ~= "" then
				ver = trim(raw:match("^[^\n\r]*") or "")
				if not M.is_valid_version(ver) then ver = nil end
			end
			result.plugin[#result.plugin + 1] = {
				version = ver,
				date = c.date,
				sha = c.sha,
				message = c.message
			}
		end
	end

	if not skip_core then
		local core_feed = fetch_commit_feed("core", branch .. "/core_version")
		local core_commits = parse_commit_feed(core_feed, 5)
		if #core_commits > 0 then
			local file_jobs = {}
			for _, c in ipairs(core_commits) do
				local job = fork_file_fetch(c.sha, branch .. "/core_version")
				if job then file_jobs[#file_jobs + 1] = job end
			end

			local file_results = collect_fork_results(file_jobs, 3)

			for _, c in ipairs(core_commits) do
				local content = file_results[c.sha]
				if content and content ~= "" then
					local meta_ver = content:match("^[^\n\r]*")
					local after_first = content:match("[\n\r]+(.*)")
					local smart_ver = after_first and after_first:match("^[^\n\r]*") or nil
					if meta_ver then
						meta_ver = trim(meta_ver)
						if M.is_valid_version(meta_ver) then
							result.core_meta[#result.core_meta + 1] = { version = meta_ver, date = c.date, sha = c.sha }
						end
					end
					if smart_ver then
						smart_ver = trim(smart_ver)
						if M.is_valid_version(smart_ver) then
							result.core_smart[#result.core_smart + 1] = { version = smart_ver, date = c.date, sha = c.sha }
						end
					end
				end
			end
		end
	end

	result.latest = {
		plugin = (result.plugin[1] and result.plugin[1].version) or "",
		core_meta = (result.core_meta[1] and result.core_meta[1].version) or "",
		core_smart = (result.core_smart[1] and result.core_smart[1].version) or ""
	}

	if cur_oix then
		local _, oix_ver = M.prepare_oix_cdn_data(force)
		if oix_ver and oix_ver ~= "" then
			result.oix_ver = oix_ver
		end
	end

	local cache_ttl = 300
	if #result.plugin == 0 then
		if not plugin_feed or plugin_feed == "" then
			result.error = "network_error"
			cache_ttl = 5
		else
			result.error = "parse_error"
			cache_ttl = 5
		end
	end

	result.cache_ttl = cache_ttl
	result.cached_at = os.time()
	result.oix = cur_oix

	update_version_cache(function(parsed)
		parsed[branch] = result
	end)

	return result
end

if arg and arg[0] and arg[0]:match("openclash_version%.lua$") then
	local branch = fs.uci_get_config("config", "release_branch") or "master"
	M.fetch_version_history(branch, arg[2], arg[1], true)
end

return M
