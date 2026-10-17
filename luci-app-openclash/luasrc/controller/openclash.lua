module("luci.controller.openclash", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/openclash") then
		return
	end

	local page

	page = entry({"admin", "services", "openclash"}, alias("admin", "services", "openclash", "client"), _("OpenClash"), 50)
	page.dependent = true
	page.acl_depends = { "luci-app-openclash" }
	entry({"admin", "services", "openclash", "client"},form("openclash/client"),_("Overviews"), 20).leaf = true
	entry({"admin", "services", "openclash", "conn_status"},call("action_conn_status")).leaf=true
	entry({"admin", "services", "openclash", "status"},call("action_status")).leaf=true
	entry({"admin", "services", "openclash", "translate_js"},call("action_translate_js")).leaf=true
	entry({"admin", "services", "openclash", "startlog"},call("action_start")).leaf=true
	entry({"admin", "services", "openclash", "refresh_log"},call("action_refresh_log"))
	entry({"admin", "services", "openclash", "del_log"},call("action_del_log"))
	entry({"admin", "services", "openclash", "del_start_log"},call("action_del_start_log"))
	entry({"admin", "services", "openclash", "close_all_connection"},call("action_close_all_connection"))
	entry({"admin", "services", "openclash", "clients_ac"}, call("action_clients_ac"))
	entry({"admin", "services", "openclash", "clients_stats"}, call("action_clients_stats"))
	entry({"admin", "services", "openclash", "clients_set"}, call("action_clients_set"))
	entry({"admin", "services", "openclash", "clients_meta"}, call("action_clients_meta"))
	entry({"admin", "services", "openclash", "clients_dns_switch"}, call("action_clients_dns_switch"))
	entry({"admin", "services", "openclash", "reload_firewall"},call("action_reload_firewall"))
	entry({"admin", "services", "openclash", "save_corever_branch"},call("action_save_corever_branch"))
	entry({"admin", "services", "openclash", "update"},call("action_update"))
	entry({"admin", "services", "openclash", "last_version"},call("action_last_version"))
	entry({"admin", "services", "openclash", "opupdate"},call("action_opupdate"))
	entry({"admin", "services", "openclash", "coreupdate"},call("action_coreupdate"))
	entry({"admin", "services", "openclash", "flush_dns_cache"}, call("action_flush_dns_cache"))
	entry({"admin", "services", "openclash", "flush_smart_cache"}, call("action_flush_smart_cache"))
	entry({"admin", "services", "openclash", "update_config"}, call("action_update_config"))
	entry({"admin", "services", "openclash", "download_rule"}, call("action_download_rule"))
	entry({"admin", "services", "openclash", "restore"}, call("action_restore_config"))
	entry({"admin", "services", "openclash", "backup"}, call("action_backup"))
	entry({"admin", "services", "openclash", "backup_ex_core"}, call("action_backup_ex_core"))
	entry({"admin", "services", "openclash", "backup_only_core"}, call("action_backup_only_core"))
	entry({"admin", "services", "openclash", "backup_only_config"}, call("action_backup_only_config"))
	entry({"admin", "services", "openclash", "backup_only_rule"}, call("action_backup_only_rule"))
	entry({"admin", "services", "openclash", "backup_only_proxy"}, call("action_backup_only_proxy"))
	entry({"admin", "services", "openclash", "remove_all_core"}, call("action_remove_all_core"))
	entry({"admin", "services", "openclash", "one_key_update"}, call("action_one_key_update"))
	entry({"admin", "services", "openclash", "one_key_update_check"}, call("action_one_key_update_check"))
	entry({"admin", "services", "openclash", "switch_mode"}, call("action_switch_mode"))
	entry({"admin", "services", "openclash", "op_mode"}, call("action_op_mode"))
	entry({"admin", "services", "openclash", "sub_info_get"}, call("sub_info_get"))
	entry({"admin", "services", "openclash", "config_name"}, call("action_config_name"))
	entry({"admin", "services", "openclash", "switch_config"}, call("action_switch_config"))
	entry({"admin", "services", "openclash", "toolbar_show"}, call("action_toolbar_show"))
	entry({"admin", "services", "openclash", "toolbar_show_sys"}, call("action_toolbar_show_sys"))
	entry({"admin", "services", "openclash", "diag_connection"}, call("action_diag_connection"))
	entry({"admin", "services", "openclash", "diag_dns"}, call("action_diag_dns"))
	entry({"admin", "services", "openclash", "gen_debug_logs"}, call("action_gen_debug_logs"))
	entry({"admin", "services", "openclash", "get_debug_logs"}, call("action_get_debug_logs"))
	entry({"admin", "services", "openclash", "log_level"}, call("action_log_level"))
	entry({"admin", "services", "openclash", "switch_log"}, call("action_switch_log"))
	entry({"admin", "services", "openclash", "rule_mode"}, call("action_rule_mode"))
	entry({"admin", "services", "openclash", "switch_rule_mode"}, call("action_switch_rule_mode"))
	entry({"admin", "services", "openclash", "switch_run_mode"}, call("action_switch_run_mode"))
	entry({"admin", "services", "openclash", "dashboard_type"}, call("action_dashboard_type"))
	entry({"admin", "services", "openclash", "switch_dashboard"}, call("action_switch_dashboard"))
	entry({"admin", "services", "openclash", "delete_dashboard"}, call("action_delete_dashboard"))
	entry({"admin", "services", "openclash", "default_dashboard"}, call("action_default_dashboard"))
	entry({"admin", "services", "openclash", "get_run_mode"}, call("action_get_run_mode"))
	entry({"admin", "services", "openclash", "create_file"}, call("create_file"))
	entry({"admin", "services", "openclash", "rename_file"}, call("rename_file"))
	entry({"admin", "services", "openclash", "manual_stream_unlock_test"}, call("manual_stream_unlock_test"))
	entry({"admin", "services", "openclash", "all_proxies_stream_test"}, call("all_proxies_stream_test"))
	entry({"admin", "services", "openclash", "set_subinfo_url"}, call("set_subinfo_url"))
	entry({"admin", "services", "openclash", "check_core"}, call("action_check_core"))
	entry({"admin", "services", "openclash", "core_download"}, call("core_download"))
	entry({"admin", "services", "openclash", "announcement"}, call("action_announcement"))
	entry({"admin", "services", "openclash", "settings"},cbi("openclash/settings"),_("Plugin Settings"), 30).leaf = true
	entry({"admin", "services", "openclash", "config-overwrite"},cbi("openclash/config-overwrite"),_("Overwrite Settings"), 40).leaf = true
	entry({"admin", "services", "openclash", "config-subscribe"},cbi("openclash/config-subscribe"),_("Config Subscribe"), 60).leaf = true
	entry({"admin", "services", "openclash", "servers"},cbi("openclash/servers"),nil).leaf = true
	entry({"admin", "services", "openclash", "other-rules-edit"},cbi("openclash/other-rules-edit"), nil).leaf = true
	entry({"admin", "services", "openclash", "custom-dns-edit"},cbi("openclash/custom-dns-edit"), nil).leaf = true
	entry({"admin", "services", "openclash", "other-file-edit"},cbi("openclash/other-file-edit"), nil).leaf = true
	entry({"admin", "services", "openclash", "proxy-providers-file-manage"},form("openclash/proxy-providers-file-manage"), nil).leaf = true
	entry({"admin", "services", "openclash", "rule-providers-file-manage"},form("openclash/rule-providers-file-manage"), nil).leaf = true
	entry({"admin", "services", "openclash", "config-subscribe-edit"},cbi("openclash/config-subscribe-edit"), nil).leaf = true
	entry({"admin", "services", "openclash", "proxies-config"},cbi("openclash/proxies-config"), nil).leaf = true
	entry({"admin", "services", "openclash", "proxy-groups-config"},cbi("openclash/proxy-groups-config"), nil).leaf = true
	entry({"admin", "services", "openclash", "proxy-providers-config"},cbi("openclash/proxy-providers-config"), nil).leaf = true
	entry({"admin", "services", "openclash", "config"},form("openclash/config"),_("Config Manage"), 80).leaf = true
	entry({"admin", "services", "openclash", "log"},cbi("openclash/log"),_("Server Logs"), 90).leaf = true
	entry({"admin", "services", "openclash", "myip_check"}, call("action_myip_check"))
	entry({"admin", "services", "openclash", "website_check"}, call("action_website_check"))
	entry({"admin", "services", "openclash", "unlock_check"}, call("action_unlock_check"))
	entry({"admin", "services", "openclash", "unlock_services"}, call("action_unlock_services"))
	entry({"admin", "services", "openclash", "version_history"}, call("action_version_history"))
	entry({"admin", "services", "openclash", "addr_info"}, call("action_cdn_info"))
	entry({"admin", "services", "openclash", "save_github_address_mod"}, call("action_save_github_address_mod"))
	entry({"admin", "services", "openclash", "save_custom_addr"}, call("action_save_custom_addr"))
	entry({"admin", "services", "openclash", "proxy_info"}, call("action_proxy_info"))
	entry({"admin", "services", "openclash", "oc_settings"}, call("action_oc_settings"))
	entry({"admin", "services", "openclash", "switch_oc_setting"}, call("action_switch_oc_setting"))
	entry({"admin", "services", "openclash", "generate_pac"}, call("action_generate_pac"))
	entry({"admin", "services", "openclash", "action"}, call("action_oc_action"))
	entry({"admin", "services", "openclash", "config_file_list"}, call("action_config_file_list"))
	entry({"admin", "services", "openclash", "config_file_read"}, call("action_config_file_read"))
	entry({"admin", "services", "openclash", "config_file_save"}, call("action_config_file_save"))
	entry({"admin", "services", "openclash", "upload_config"}, call("action_upload_config"))
	entry({"admin", "services", "openclash", "restore_backup"}, call("action_restore_backup"))
	entry({"admin", "services", "openclash", "add_subscription"}, call("action_add_subscription"))
	entry({"admin", "services", "openclash", "config_stats"}, call("action_config_stats"))
	entry({"admin", "services", "openclash", "runtime_stats"}, call("action_runtime_stats"))
	entry({"admin", "services", "openclash", "template_preview"}, call("action_template_preview"))
	entry({"admin", "services", "openclash", "subconverter_version"}, call("action_subconverter_version"))
	entry({"admin", "services", "openclash", "generate_age_key"}, call("action_generate_age_key"))
	entry({"admin", "services", "openclash", "cal_age_public_key"}, call("action_cal_age_public_key"))
	entry({"admin", "services", "openclash", "add_age_config"}, call("action_add_age_config"))
	entry({"admin", "services", "openclash", "upload_overwrite"}, call("action_upload_overwrite"))
	entry({"admin", "services", "openclash", "overwrite_subscribe_info"}, call("action_overwrite_subscribe_info"))
	entry({"admin", "services", "openclash", "overwrite_module_preview"}, call("action_overwrite_module_preview"))
	entry({"admin", "services", "openclash", "overwrite_file_list"}, call("action_overwrite_file_list"))
	entry({"admin", "services", "openclash", "delete_overwrite_file"}, call("delete_overwrite_file"))
	entry({"admin", "services", "openclash", "get_subscribe_data"}, call("action_get_subscribe_data"))
	entry({"admin", "services", "openclash", "get_subscribe_info_data"}, call("action_get_subscribe_info_data"))
	entry({"admin", "services", "openclash", "oix_info"}, call("oix_info"))
	entry({"admin", "services", "openclash", "oix_checkin"}, call("oix_checkin"))
	entry({"admin", "services", "openclash", "oix_logout"}, call("oix_logout"))
	entry({"admin", "services", "openclash", "oix_login"}, call("oix_login"))
	entry({"admin", "services", "openclash", "oix_login_info_save"}, call("oix_login_info_save"))
	entry({"admin", "services", "openclash", "theme_get"}, call("action_theme_get"))
	entry({"admin", "services", "openclash", "theme_save"}, call("action_theme_save"))
end

local SYS = require "luci.sys"
local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"
local UTIL = require "luci.util"
local fs = require "luci.openclash"
local is_safe_filename = fs.is_safe_filename
local json = require "luci.jsonc"
local uci = require("luci.model.uci").cursor()
local datatype = require "luci.cbi.datatypes"
local opkg
local device_name = uci:get("system", "@system[0]", "hostname")
local device_arh = SYS.exec("uname -m |tr -d '\n'")

if pcall(require, "luci.model.ipkg") then
	opkg = require "luci.model.ipkg"
else
	opkg = nil
end

local core_path_mode = fs.uci_get_config("config", "small_flash_memory")
if core_path_mode ~= "1" then
	meta_core_path="/etc/openclash/core/clash_meta"
else
	meta_core_path="/tmp/etc/openclash/core/clash_meta"
end

local function is_running()
	return SYS.call("pidof clash >/dev/null") == 0
end

-- the procd instance state is the authority after an init.d restart, pidof can still
-- see a dying process; nil means ubus itself is unavailable
local function service_running()
	local out = SYS.exec("ubus call service list '{\"name\":\"openclash\"}' 2>/dev/null")
	if not out or out == "" then
		return nil
	end
	local ok, data = pcall(json.parse, out)
	if not ok or type(data) ~= "table" or type(data.openclash) ~= "table" then
		return nil
	end
	local instances = data.openclash.instances
	if type(instances) ~= "table" then
		return false
	end
	for _, inst in pairs(instances) do
		if type(inst) == "table" and inst.running == true then
			return true
		end
	end
	return false
end

local CONFIG_PATH_PREFIX = "/etc/openclash/config/"
local CONFIG_PATH_PREFIX_LEN = #CONFIG_PATH_PREFIX + 1

local function is_start()
	return process_status("/etc/init.d/openclash")
end

local function cn_port()
	return fs.uci_get_config("config", "cn_port") or "9090"
end

local function mode()
	return fs.uci_get_config("config", "en_mode")
end

local function daip()
	return fs.lanip()
end

local function dase()
	return fs.uci_get_config("config", "dashboard_password")
end

-- curl startup is slow on some builds, uclient-fetch (aliased as wget on newer images) is slower than curl
local function core_http_client()
	if fs.access("/usr/bin/wget") then
		local target = nixio.fs.readlink("/usr/bin/wget")
		if not (target and target:find("uclient%-fetch", 1)) then
			return "wget"
		end
	end
	return "curl"
end

-- the core answers in a millisecond, curl startup on weak routers costs far more
local function core_api_get(path)
	local ip = daip()
	local port = cn_port()
	if not ip or not port then
		return nil
	end
	local url = string.format("http://%s:%s%s", ip, port, path)
	local auth = UTIL.shellquote("Authorization: Bearer " .. (dase() or ""))
	local out
	if core_http_client() == "wget" then
		out = SYS.exec("wget -q -T 5 -O - --header=" .. auth .. " " .. UTIL.shellquote(url) .. " 2>/dev/null")
	else
		out = SYS.exec("curl -sL -m 5 --retry 1 -H " .. auth .. " " .. UTIL.shellquote(url) .. " 2>/dev/null")
	end
	if not out or out == "" then
		return nil
	end
	return out
end

-- the core API write path
local function core_api_post(path)
	local ip = daip()
	local port = cn_port()
	if not ip or not port then
		return ""
	end
	local url = string.format("http://%s:%s%s", ip, port, path)
	local auth = UTIL.shellquote("Authorization: Bearer " .. (dase() or ""))
	local out
	if core_http_client() == "wget" then
		out = SYS.exec("wget -q -T 3 -t 2 -O - --header=" .. auth .. " --header='Content-Type: application/json' --post-data='' " .. UTIL.shellquote(url) .. " 2>/dev/null")
	else
		out = SYS.exec("curl -sL -m 3 --retry 2 -H 'Content-Type: application/json' -H " .. auth .. " -XPOST " .. UTIL.shellquote(url) .. " 2>/dev/null")
	end
	return out or ""
end

local function dashboard_forward_domain()
	return fs.uci_get_config("config", "dashboard_forward_domain")
end

local function dashboard_forward_port()
	return fs.uci_get_config("config", "dashboard_forward_port")
end

local function dashboard_forward_ssl()
	return fs.uci_get_config("config", "dashboard_forward_ssl") or 0
end

local function dashboard_custom_url()
	return fs.uci_get_config("config", "dashboard_custom_url")
end

local function dashboard_custom_clash_compatible()
	return fs.uci_get_config("config", "dashboard_custom_clash_compatible") or 0
end

local function coremodel()
	local rel = fs.readfile("/etc/openwrt_release")
	if rel then
		local arch = rel:match("DISTRIB_ARCH='([^']+)'")
		if arch and arch ~= "" then
			return arch
		end
	end
	if opkg then
		local info = opkg.info("libc")
		if info and info["libc"] and info["libc"]["Architecture"] then
			return info["libc"]["Architecture"]
		end
	end
	if fs.pkg_type() == "opkg" then
		return fs.read_pkg_field("libc", "Architecture")
	else
		return fs.read_pkg_field("libc", "A")
	end
end

local function check_core()
	if not fs.access(meta_core_path) then
		return "0"
	else
		return "1"
	end
end

local function parse_subconverter_version_url(raw_url)
	raw_url = (raw_url or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if raw_url == "" then return nil, "empty" end
	if not raw_url:match("^[a-zA-Z][a-zA-Z0-9+%.%-]*://") then
		raw_url = "https://" .. raw_url
	end

	local scheme, authority, path = raw_url:match("^(https?)://([^/?#]+)([^?#]*)")
	if not scheme or not authority then return nil, "invalid" end
	if authority:find("@", 1, true) then return nil, "invalid" end
	if authority:match("%s") then return nil, "invalid" end
	if raw_url:find("?", 1, true) or raw_url:find("#", 1, true) then return nil, "invalid" end

	local host, port
	if authority:sub(1, 1) == "[" then
		host, port = authority:match("^(%[[0-9a-fA-F:%.]+%]):?(%d*)$")
	else
		host, port = authority:match("^([^:]+):?(%d*)$")
	end
	if not host or host == "" then return nil, "invalid" end
	if port and port ~= "" then
		port = tonumber(port)
		if not port or port < 1 or port > 65535 then return nil, "invalid" end
	end

	path = (path and path ~= "") and path or "/"
	if path ~= "/version" and not path:match("/version$") then return nil, "invalid" end

	return scheme .. "://" .. authority .. path
end

local function sanitize_subconverter_version_text(text)
	text = tostring(text or ""):gsub("\r", "\n")
	local lines = {}
	for line in text:gmatch("[^\n]+") do
		line = line:gsub("^%s+", ""):gsub("%s+$", "")
		if line ~= "" then lines[#lines + 1] = line end
	end
	text = table.concat(lines, " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" or #text > 220 then return "" end
	if text:match("<%s*/?%s*[%a!][^>]*>") then
		return ""
	end
	if not text:lower():match("subconverter") and not text:lower():match("backend") and not text:lower():match("version") and not text:match("v?%d+%.%d+") then
		return ""
	end
	return text
end

local ov = dofile("/usr/share/openclash/openclash_version.lua")

local function coremetacv()
	if not fs.access(meta_core_path) then
		return "0"
	end

	local st = nixio.fs.stat(meta_core_path)
	local key = st and (tostring(st.mtime) .. "-" .. tostring(st.size)) or ""

	local v = fs.cached_value("core_cv_cache", key, function()
		local out = SYS.exec(string.format("%s -v 2>/dev/null |awk -F ' ' '{print $3}' |head -1 |tr -d '\n'", meta_core_path))
		if not out or out == "" then return nil end
		return out
	end)

	return v or "0"
end

function release_branch()
	return fs.uci_get_config("config", "release_branch") or "master"
end

local function smart_enable()
	return fs.uci_get_config("config", "smart_enable") or "0"
end

local function is_oix()
	local token = fs.uci_get_config("config", "oix_token")
	return token ~= nil and token ~= ""
end

local function corever()
	return fs.uci_get_config("config", "core_version") or "0"
end

local function corelv()
	local core_meta_lv = ""
	local core_smart_enable = fs.uci_get_config("config", "smart_enable") or "0"
	local oix_token = fs.uci_get_config("config", "oix_token") or ""

	local cache = ov.fetch_version_history(release_branch(), false)
	if cache then
		if oix_token ~= "" then
			core_meta_lv = cache.oix_ver or ""
		elseif core_smart_enable == "1" then
			core_meta_lv = (cache.core_smart and cache.core_smart[1] and cache.core_smart[1].version) or ""
		else
			core_meta_lv = (cache.core_meta and cache.core_meta[1] and cache.core_meta[1].version) or ""
		end
	end

	if core_meta_lv and core_meta_lv ~= "" then
		return core_meta_lv
	end

	return "loading..."
end

local function opcv()
	local v
	local info = opkg and opkg.info("luci-app-openclash")
	if info and info["luci-app-openclash"] and info["luci-app-openclash"]["Version"] and info["luci-app-openclash"]["Installed-Time"] then
		v = info["luci-app-openclash"]["Version"]
	else
		v = fs.oc_version()
		if v == "0" then
			return "0"
		end
		if fs.pkg_type() ~= "opkg" then
			v = v:match("[%d%.]+") or ""
		end
	end
	if v and v ~= "" then
		return "v" .. v
	else
		return "0"
	end
end

local function oplv()
	local oplv = ""

	local cache = ov.fetch_version_history(release_branch(), false)
	if cache and cache.plugin and cache.plugin[1] and cache.plugin[1].version then
		return cache.plugin[1].version
	end

	return "loading..."
end

local function opup()
	return SYS.call("bash /usr/share/openclash/openclash_update.sh >/dev/null 2>&1 &")
end

local function coreup()
	uci:set("openclash", "config", "enable", "1")
	uci:commit("openclash")
	local type = HTTP.formvalue("core_type")
	return SYS.call(string.format("/usr/share/openclash/openclash_core.sh '%s' >/dev/null 2>&1 &", type))
end

local function save_corever_branch()
	if HTTP.formvalue("core_ver") then
		uci:set("openclash", "config", "core_version", HTTP.formvalue("core_ver"))
	end
	if HTTP.formvalue("release_branch") then
		uci:set("openclash", "config", "release_branch", HTTP.formvalue("release_branch"))
	end
	if HTTP.formvalue("smart_enable") then
		uci:set("openclash", "config", "smart_enable", HTTP.formvalue("smart_enable"))
	end
	uci:commit("openclash")
	return "success"
end

function core_download()
	local download_url = HTTP.formvalue("download_url")
	local core_type = is_oix() and "Oix" or "Meta"

	if download_url and download_url ~= "" then
		SYS.call(string.format("bash /usr/share/openclash/openclash_core.sh '%s' '%s' >/dev/null 2>&1 &", core_type, download_url))
	else
		SYS.call(string.format("bash /usr/share/openclash/openclash_core.sh '%s' >/dev/null 2>&1 &", core_type))
	end

end

function action_flush_dns_cache()
	local fake_ip_state = ""
	local dns_state = ""
	if is_running() then
		fake_ip_state = core_api_post("/cache/fakeip/flush")
		dns_state = core_api_post("/cache/dns/flush")
	end
	HTTP.prepare_content("application/json")
	HTTP.write_json({
		fakeip_flush = fake_ip_state;
		dns_flush = dns_state;
		flush_status = (fake_ip_state == "" and dns_state == "") and "" or (fake_ip_state ~= "" and fake_ip_state or dns_state);
	})
end

function action_flush_smart_cache()
	local flush_state = ""
	if is_running() then
		flush_state = core_api_post("/cache/smart/flush")
	end
	HTTP.prepare_content("application/json")
	HTTP.write_json({
		flush_status = flush_state;
	})
end

-- no_restart is passed by the config upload flow, which restarts at its own switch step
function action_update_config()
	-- filename is basename
	local filename = HTTP.formvalue("filename")

	HTTP.prepare_content("application/json")

	if not filename then
		HTTP.write_json({
			status = "error",
			message = "Config file not found"
		})
		return
	end

	if not is_safe_filename(filename) then
		HTTP.write_json({
			status = "error",
			message = "Invalid filename"
		})
		return
	end

	local no_restart = HTTP.formvalue("no_restart")
	local restart_arg = no_restart == "1" and " norestart" or ""

	local update_result = SYS.call(string.format("/usr/share/openclash/openclash.sh '%s'%s >/dev/null 2>&1", filename, restart_arg))

	if update_result == 0 then
		HTTP.write_json({
			status = "success",
			message = "Config update started successfully",
			filename = filename
		})
	else
		HTTP.write_json({
			status = "error",
			message = luci.i18n.translate("Subscription update failed; existing configuration was kept")
		})
	end
end

function action_restore_config()
	uci:set("openclash", "config", "enable", "0")
	uci:commit("openclash")
	SYS.call("mkdir -p /etc/openclash/custom >/dev/null 2>&1")
	SYS.call("mkdir -p /etc/openclash/overwrite >/dev/null 2>&1")
	SYS.call("mkdir -p /etc/openclash/rule_provider >/dev/null 2>&1")
	SYS.call("/etc/init.d/openclash stop >/dev/null 2>&1")
	SYS.call("cp -f /usr/share/openclash/backup/openclash /etc/config/openclash >/dev/null 2>&1 &")
	SYS.call("cp -f /usr/share/openclash/backup/openclash_custom* /etc/openclash/custom/ >/dev/null 2>&1 &")
	SYS.call("cp -f /usr/share/openclash/backup/openclash_force_sniffing* /etc/openclash/custom/ >/dev/null 2>&1 &")
	SYS.call("cp -f /usr/share/openclash/backup/openclash_sniffing* /etc/openclash/custom/ >/dev/null 2>&1 &")
	SYS.call("cp -f /usr/share/openclash/backup/china_ip_route.ipset /etc/openclash/china_ip_route.ipset >/dev/null 2>&1 &")
	SYS.call("cp -f /usr/share/openclash/backup/china_ip6_route.ipset /etc/openclash/china_ip6_route.ipset >/dev/null 2>&1 &")
	SYS.call("cp -f /usr/share/openclash/backup/overwrite/default /etc/openclash/overwrite/default >/dev/null 2>&1 &")
	SYS.call("cp -f /usr/share/openclash/backup/oc-cn-domain.mrs /etc/openclash/rule_provider/oc-cn-domain.mrs >/dev/null 2>&1 &")
	SYS.call("rm -rf /etc/openclash/history/* >/dev/null 2>&1 &")
end

function action_remove_all_core()
	SYS.call("rm -rf /etc/openclash/core/* >/dev/null 2>&1")
end

function action_one_key_update()
	local cdn_url = HTTP.formvalue("url")
	local download_url = HTTP.formvalue("download_url")
	local version = HTTP.formvalue("version")
	local sha = HTTP.formvalue("sha")
	local update_type = HTTP.formvalue("update_type")

	if update_type == "plugin" then
		if download_url and download_url ~= "" then
			return SYS.call(string.format("bash /usr/share/openclash/openclash_update.sh 'plugin_update' '%s' '%s' >/dev/null 2>&1 &",
				cdn_url or "", download_url))
		elseif cdn_url and cdn_url ~= "" then
			return SYS.call(string.format("bash /usr/share/openclash/openclash_update.sh 'plugin_update' '%s' >/dev/null 2>&1 &", cdn_url))
		else
			return SYS.call("bash /usr/share/openclash/openclash_update.sh 'plugin_update' >/dev/null 2>&1 &")
		end
	end

	if download_url and download_url ~= "" then
		-- Full download URL: pass as $3 to the update script
		return SYS.call(string.format("bash /usr/share/openclash/openclash_update.sh 'one_key_update' '%s' '%s' >/dev/null 2>&1 &",
			cdn_url or "", download_url))
	elseif cdn_url and cdn_url ~= "" then
		return SYS.call(string.format("bash /usr/share/openclash/openclash_update.sh 'one_key_update' '%s' >/dev/null 2>&1 &", cdn_url))
	else
		return SYS.call("bash /usr/share/openclash/openclash_update.sh 'one_key_update' >/dev/null 2>&1 &")
	end
end

local function config_name()
	local e,a={}
	for t,o in ipairs(fs.glob("/etc/openclash/config/*"))do
		a=fs.stat(o)
		if a then
			e[t]={}
			e[t].name=fs.basename(o)
		end
	end
	return e
end

local function config_path()
	local p = fs.uci_get_config("config", "config_path")
	return p and string.sub(p, CONFIG_PATH_PREFIX_LEN) or ""
end

function action_switch_config()
	local config_file = HTTP.formvalue("config_file")
	local config_name = HTTP.formvalue("config_name")

	if not config_file and config_name then
		config_file = "/etc/openclash/config/" .. config_name
	end

	if not config_file then
		HTTP.prepare_content("application/json")
		HTTP.write_json({
			status = "error",
			message = "No config file specified"
		})
		return
	end

	if not fs.access(config_file) then
		HTTP.prepare_content("application/json")
		HTTP.write_json({
			status = "error",
			message = "Config file does not exist: " .. config_file
		})
		return
	end

	uci:set("openclash", "config", "config_path", config_file)
	uci:set("openclash", "config", "enable", "1")
	uci:commit("openclash")

	SYS.call("/etc/init.d/openclash restart >/dev/null 2>&1 &")

	HTTP.prepare_content("application/json")
	HTTP.write_json({
		status = "success",
		message = "Config file switched successfully",
		config_file = config_file
	})
end

function set_subinfo_url()
	local filename, url, info
	filename = HTTP.formvalue("filename")
	url = HTTP.formvalue("url")
	if not filename then
		info = "Oops: The config file name seems to be incorrect"
	end
	if url and url ~= "" and not string.find(url, "http") then
		info = "Oops: The url link format seems to be incorrect"
	end
	if not info then
		uci:foreach("openclash", "subscribe_info",
			function(s)
				if s.name == filename then
					if not url or url == "" then
						uci:delete("openclash", s[".name"])
						uci:commit("openclash")
						info = "Delete success"
						return false
					else
						local url_list = {}
						for line in string.gmatch(url, "[^\n]+") do
							if line ~= "" then
								table.insert(url_list, line)
							end
						end
						uci:delete("openclash", s[".name"], "url")
						uci:set_list("openclash", s[".name"], "url", url_list)
						uci:commit("openclash")
						info = "Success"
						return false
					end
				end
			end
		)
		if not info then
			if not url or url == "" then
				info = "Delete success"
			else
				local url_list = {}
				for line in string.gmatch(url, "[^\n]+") do
					if line ~= "" then
						url_list[#url_list + 1] = line
					end
				end
				uci:section("openclash", "subscribe_info", nil, {name = filename, url = url_list})
				uci:commit("openclash")
				info = "Success"
			end
		end
	end
	HTTP.prepare_content("application/json")
	HTTP.write_json({
		info = info;
	})
end

function fetch_sub_info(sub_url, sub_ua, sub_headers, raw_info)
	local info, upload, download, total, day_expire, http_code
	local used, expire, day_left, percent, surplus

	if raw_info then
		info = raw_info
	else
		local header_args = ""
		if sub_headers and sub_headers ~= "" then
			for hdr in sub_headers:gmatch("[^\n]+") do
				hdr = hdr:match("^%s*(.-)%s*$")
				if hdr and hdr ~= "" then
					header_args = header_args .. string.format(" -H '%s'", hdr:gsub("'", "'\\''"))
				end
			end
		end

		info = SYS.exec(string.format("curl -sLI -X GET -m 5 --retry 2 -w 'http_code=%%{http_code}' -H 'User-Agent: %s'%s '%s'", sub_ua, header_args, sub_url))
		local http_match = string.match(info, "http_code=(%d+)")
		if not info or not http_match or tonumber(http_match) ~= 200 then
			info = SYS.exec(string.format("curl -sLI -X GET -m 5 --retry 2 -w 'http_code=%%{http_code}' -H 'User-Agent: Quantumultx'%s '%s'", header_args, sub_url))
		end
	end

	local http_match = string.match(info, "http_code=(%d+)")
	if info and http_match then
		http_code = http_match
		if tonumber(http_code) == 200 then
			info = string.lower(info)
			if string.find(info, "subscription%-userinfo") then
				local sub_info_line = ""
				for line in info:gmatch("[^\r\n]+") do
					if string.find(line, "subscription%-userinfo") then
						sub_info_line = line
						break
					end
				end
				info = sub_info_line
				local upload_match = string.match(info, "upload=(%d+)")
				local download_match = string.match(info, "download=(%d+)")
				local total_match = string.match(info, "total=(%d+)")
				local expire_match = string.match(info, "expire=(%d+)")

				upload = upload_match and tonumber(upload_match) or nil
				download = download_match and tonumber(download_match) or nil
				total = total_match and tonumber(string.format("%.1f", total_match)) or nil
				used = upload and download and tonumber(string.format("%.1f", upload + download)) or nil
				day_expire = expire_match and tonumber(expire_match) or nil

				if day_expire and day_expire == 0 then
					expire = luci.i18n.translate("Long-term")
				elseif day_expire then
					expire = os.date("%Y-%m-%d %H:%M:%S", day_expire) or "null"
				else
					expire = "null"
				end

				if day_expire and day_expire ~= 0 and os.time() <= day_expire then
					day_left = math.ceil((day_expire - os.time()) / (3600*24))
					if math.ceil(day_left / 365) > 50 then
						day_left = "∞"
					end
				elseif day_expire and day_expire == 0 then
					day_left = "∞"
				elseif day_expire == nil then
					day_left = "null"
				else
					day_left = 0
				end

				if used and total and used <= total and total > 0 then
					percent = string.format("%.1f",((total-used)/total)*100) or "100"
					surplus = fs.filesize(total - used)
				elseif used and total and used > total and total > 0 then
					percent = "0"
					surplus = "-"..fs.filesize(total - used)
				elseif used and total and used < total and total == 0.0 then
					percent = "0"
					surplus = fs.filesize(total - used)
				elseif used and total and used == total and total == 0.0 then
					percent = "0"
					surplus = "0.0 KB"
				elseif used and total and used > total and total == 0.0 then
					percent = "100"
					surplus = fs.filesize(total - used)
				elseif used == nil and total and total > 0.0 then
					percent = 100
					surplus = fs.filesize(total)
				elseif used == nil and total and total == 0.0 then
					percent = 100
					surplus = "∞"
				else
					percent = 0
					surplus = "null"
				end

				local total_formatted, used_formatted
				if total and total > 0 then
					total_formatted = fs.filesize(total)
				elseif total and total == 0.0 then
					total_formatted = "∞"
				else
					total_formatted = "null"
				end
				used_formatted = fs.filesize(used)

				return {
					http_code = http_code,
					surplus = surplus,
					used = used_formatted,
					total = total_formatted,
					percent = percent,
					day_left = day_left,
					expire = expire
				}
			end
		end
	end

	return nil
end

local function parse_url_with_name(raw_url, default_name)
	local url, name = string.match(raw_url, "^(.-)#name=(.+)$")
	if url then
		return url, name
	else
		return raw_url, default_name
	end
end

function get_sub_url(filename)
	local sub_url = nil
	local info_tb = {}
	local providers = {}

	-- Priority 1: subscribe_info
	uci:foreach("openclash", "subscribe_info",
		function(s)
			if s.name == filename and s.url then
				if type(s.url) == "table" then
					for _, v in ipairs(s.url) do
						info_tb[#info_tb + 1] = v
					end
				else
					string.gsub(s.url, '[^\n]+', function(w) info_tb[#info_tb + 1] = w end)
				end
				if #info_tb == 1 then
					local url, name = parse_url_with_name(info_tb[1], filename)
					if url ~= info_tb[1] then
						providers[#providers + 1] = {name = name, url = url}
					else
						sub_url = url
					end
				elseif #info_tb > 1 then
					for _, raw in ipairs(info_tb) do
						local url, name = parse_url_with_name(raw, filename)
						providers[#providers + 1] = {name = name, url = url}
					end
				end
				return false
			end
		end
	)

	if sub_url then
		return {type = "single", url = sub_url}
	end

	if #providers > 0 then
		return {type = "multiple", providers = providers}
	end

	-- Priority 2: YAML proxy-providers (use actual config file content first)
	local config_path = "/etc/openclash/config/" .. fs.basename(filename .. ".yaml")

	if fs.access(config_path) then
		local ruby_result = SYS.exec(string.format([[
			ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e '
			begin
				config = YAML.load_file("%s")
				providers = []
				if config && config["proxy-providers"]
					config["proxy-providers"].each do |name, provider|
						# Only include providers with non-empty URLs
						if provider && provider["url"] && !provider["url"].to_s.empty?
							providers << {"name" => name, "url" => provider["url"].to_s}
						end
					end
				end
				# Manual JSON output (ruby-json is not a dependency)
				result = "["
				providers.each_with_index do |p, i|
					result << "," if i > 0
					# Escape quotes in name and URL
					name_escaped = p["name"].gsub("\"", "\\\\\"")
					url_escaped = p["url"].gsub("\"", "\\\\\"")
					result << "{\"name\":\"#{name_escaped}\",\"url\":\"#{url_escaped}\"}"
				end
				result << "]"
				puts result
			rescue => e
				puts "[]"
			end
			' 2>/dev/null || echo '[]'
		]], config_path)):gsub("\n", "")

		if ruby_result and ruby_result ~= "" and ruby_result ~= "[]" then
			local success, parsed_providers = pcall(function()
				return json.parse(ruby_result)
			end)

			if success and parsed_providers and #parsed_providers > 0 then
				return {type = "multiple", providers = parsed_providers}
			end
		end
	end

	-- Priority 3: config_subscribe table (last fallback)
	uci:foreach("openclash", "config_subscribe",
		function(s)
			if s.name == filename and s.address and string.find(s.address, "http") then
				string.gsub(s.address, '[^\n]+', function(w) info_tb[#info_tb + 1] = w end)
				if #info_tb == 1 then
					local url, _ = parse_url_with_name(info_tb[1], filename)
					sub_url = url
				elseif #info_tb > 1 then
					for _, raw in ipairs(info_tb) do
						local url, name = parse_url_with_name(raw, filename)
						providers[#providers + 1] = {name = name, url = url}
					end
				end
			end
		end
	)

	if sub_url then
		return {type = "single", url = sub_url}
	end

	if #providers > 0 then
		return {type = "multiple", providers = providers}
	end

	return nil
end

function sub_info_get()
	local sub_ua, sub_headers, filename, sub_info, url_result
	local providers_data = {}

	filename = HTTP.formvalue("filename")
	sub_info = ""
	sub_ua = "Clash"
	sub_headers = ""

	-- the config list passes the file name; subscription entries are keyed by the bare config name
	local base = filename and filename:gsub("%.ya?ml$", "") or filename
	uci:foreach("openclash", "config_subscribe",
		function(s)
			if s.name == filename or s.name == base then
				if s.sub_ua then
					sub_ua = s.sub_ua
				end
				local raw = uci:get_list("openclash", s['.name'], "sub_headers")
				if raw then
					sub_headers = table.concat(raw, "\n")
				end
				return false
			end
		end
	)

	if base and not is_start() then
		url_result = get_sub_url(base)

		if url_result then
			if url_result.type == "single" then
				local info = fetch_sub_info(url_result.url, sub_ua, sub_headers)
				if info then
					providers_data[#providers_data + 1] = info
				end
			elseif #url_result.providers <= 1 then
				for i, provider in ipairs(url_result.providers) do
					local info = fetch_sub_info(provider.url, sub_ua, sub_headers)
					if info then
						info.provider_name = provider.name
						providers_data[#providers_data + 1] = info
					end
				end
			else
				local header_args = ""
				if sub_headers and sub_headers ~= "" then
					for hdr in sub_headers:gmatch("[^\n]+") do
						hdr = hdr:match("^%s*(.-)%s*$")
						if hdr and hdr ~= "" then
							header_args = header_args .. string.format(" -H '%s'", hdr:gsub("'", "'\\''"))
						end
					end
				end

				local function fork_provider_curl(url)
					local fdi, fdo = nixio.pipe()
					if not fdi or not fdo then return nil end
					local cmd = string.format(
						'OUT=$(curl -sLI -X GET -m 5 --retry 2 -w "http_code=%%{http_code}" -H "User-Agent: %s"%s "%s" 2>/dev/null); '
						.. 'CODE=$(echo "$OUT" | grep -o "http_code=[0-9]*" | head -1 | cut -d= -f2); '
						.. 'if [ -n "$OUT" ] && [ "$CODE" = "200" ]; then echo "$OUT"; '
						.. 'else curl -sLI -X GET -m 5 --retry 2 -w "http_code=%%{http_code}" -H "User-Agent: Quantumultx"%s "%s" 2>/dev/null; fi',
						sub_ua, header_args, url, header_args, url
					)
					local child = nixio.fork()
					if child > 0 then
						fdo:close()
						return {pid = child, fdi = fdi, buf = ""}
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

				local providers = url_result.providers
				local jobs = {}

				for i, provider in ipairs(providers) do
					local job = fork_provider_curl(provider.url)
					if job then
						job.idx = i
						job.name = provider.name
						jobs[#jobs + 1] = job
					end
				end

				if #jobs > 0 then
					local done_count = 0
					local delay = 50000000
					local max_wait = 40
					for _ = 1, max_wait do
						for _, job in ipairs(jobs) do
							if not job.done then
								local buf = try_read(job.fdi, 4096)
								if buf then job.buf = job.buf .. buf end
								if nixio.waitpid(job.pid, "nohang") then
									while true do
										local b = try_read(job.fdi, 4096)
										if not b then break end
										job.buf = job.buf .. b
									end
									pcall(job.fdi.close, job.fdi)
									job.done = true
									done_count = done_count + 1
								end
							end
						end
						if done_count >= #jobs then break end
						nixio.nanosleep(0, delay)
						delay = math.min(delay * 2, 200000000)
					end
					for _, job in ipairs(jobs) do
						if not job.done then
							pcall(job.fdi.close, job.fdi)
							nixio.kill(job.pid, 9)
						end
					end
					for _, job in ipairs(jobs) do
						if job.done and job.buf ~= "" then
							local info = fetch_sub_info(providers[job.idx].url, sub_ua, sub_headers, job.buf)
							if info then
								info.provider_name = job.name
								providers_data[#providers_data + 1] = info
							end
						end
					end
				end
				-- Fallback: if all forks failed, try serial
				if #providers_data == 0 then
					for i, provider in ipairs(providers) do
						local info = fetch_sub_info(provider.url, sub_ua, sub_headers)
						if info then
							info.provider_name = provider.name
							providers_data[#providers_data + 1] = info
						end
					end
				end
			end
		end
	end

	if #providers_data == 0 then
		if not url_result then
			HTTP.status(500, "Subscription information not found")
			return
		end
	end

	HTTP.prepare_content("application/json")
	HTTP.write_json({
		providers = providers_data,
		get_time = os.time(),
		url_result = url_result
	})
end

function action_rule_mode(internal)
	local mode
	if is_running() then
		local daip_val = daip()
		local cn_port_val = cn_port()
		if daip_val and cn_port_val then
			local info = json.parse(core_api_get("/configs"))
			if info and info["mode"] then
				mode = info["mode"]
			end
		end
	end
	mode = mode or fs.uci_get_config("config", "proxy_mode") or "rule"
	if internal then return { mode = mode } end
	HTTP.prepare_content("application/json")
	HTTP.write_json({ mode = mode })
end

function action_switch_rule_mode()
	local mode, info
	local daip = daip()
	local dase = dase() or ""
	local cn_port = cn_port()
	mode = HTTP.formvalue("rule_mode")

	if not mode then
		HTTP.status(500, "Missing parameters")
		return
	end

	if is_running() then
		if not daip or not cn_port then HTTP.status(500, "Switch Failed") return end
		info = SYS.exec(string.format('curl -sL -m 3 --retry 2 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XPATCH http://"%s":"%s"/configs -d \'{\"mode\": \"%s\"}\'', dase, daip, cn_port, mode))
		if info ~= "" then
			HTTP.status(500, "Switch Failed")
		end
		HTTP.prepare_content("application/json")
		HTTP.write_json({
			info = info;
		})
	end
	uci:set("openclash", "config", "proxy_mode", mode)
	uci:set("openclash", "@overwrite[0]", "proxy_mode", mode)
	uci:commit("openclash")
end

function action_get_run_mode()
	if mode() then
		HTTP.prepare_content("application/json")
		HTTP.write_json({
			mode = mode();
		})
	else
		HTTP.status(500, "Get Failed")
		return
	end
end

function action_switch_run_mode()
	local mode, operation_mode
	mode = HTTP.formvalue("run_mode")
	operation_mode = fs.uci_get_config("config", "operation_mode")
	if operation_mode == "redir-host" then
		uci:set("openclash", "config", "en_mode", "redir-host"..mode)
		uci:set("openclash", "@overwrite[0]", "en_mode", "redir-host"..mode)
	elseif operation_mode == "fake-ip" then
		uci:set("openclash", "config", "en_mode", "fake-ip"..mode)
		uci:set("openclash", "@overwrite[0]", "en_mode", "fake-ip"..mode)
	end
	uci:commit("openclash")
	if is_running() then
		SYS.exec("/etc/init.d/openclash restart >/dev/null 2>&1")
	end
end

function action_log_level()
	local level, info
	if is_running() then
		local daip = daip()
		local cn_port = cn_port()
		if not daip or not cn_port then return end
		info = json.parse(core_api_get("/configs"))
		if info then
			level = info["log-level"]
		else
			level = fs.uci_get_config("config", "log_level") or "info"
		end
	else
		level = fs.uci_get_config("config", "log_level") or "info"
	end
	HTTP.prepare_content("application/json")
	HTTP.write_json({
		log_level = level;
	})
end

function action_switch_log()
	local level, info
	if is_running() then
		local daip = daip()
		local dase = dase() or ""
		local cn_port = cn_port()
		level = HTTP.formvalue("log_level")
		if not daip or not cn_port or not level then HTTP.status(500, "Switch Failed") return end
		info = SYS.exec(string.format('curl -sL -m 3 --retry 2 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XPATCH http://"%s":"%s"/configs -d \'{\"log-level\": \"%s\"}\'', dase, daip, cn_port, level))
		if info ~= "" then
			HTTP.status(500, "Switch Failed")
		end
	else
		HTTP.status(500, "Switch Failed")
	end
	HTTP.prepare_content("application/json")
	HTTP.write_json({
		info = info;
	})
end

local function proc_cpu_count()
	local content = nixio.fs.readfile("/proc/cpuinfo")
	if not content then
		return "1"
	end
	local count = 0
	for line in content:gmatch("[^\n]+") do
		if line:match("^processor") then
			count = count + 1
		end
	end
	return count > 0 and tostring(count) or "1"
end

local function proc_find_core_pid()
	local iter = nixio.fs.dir("/proc")
	if not iter then
		return nil
	end
	local pids = {}
	for entry in iter do
		if entry:match("^%d+$") then
			pids[#pids + 1] = tonumber(entry)
		end
	end
	table.sort(pids)
	for _, pid in ipairs(pids) do
		local cmdline = nixio.fs.readfile("/proc/" .. pid .. "/cmdline")
		if cmdline and cmdline:gsub("%z", " "):match("^[^ ]*clash") then
			return tostring(pid)
		end
	end
	return nil
end

-- utime+stime in ticks, read once; the page turns two samples into a percentage
local function proc_core_cpu_ticks(pid)
	local stat = fs.readfile("/proc/" .. pid .. "/stat")
	if not stat then return nil end
	local last_bracket = 0
	for pos in stat:gmatch("()%)") do
		last_bracket = pos
	end
	if last_bracket == 0 then return nil end
	local fields = {}
	for field in stat:sub(last_bracket + 1):gmatch("%S+") do
		fields[#fields + 1] = field
	end
	local utime = tonumber(fields[12])
	local stime = tonumber(fields[13])
	if not utime or not stime then return nil end
	return utime + stime
end

function action_toolbar_show_sys()
	local load_avg = "0"
	local cpu_ticks = "0"
	local cpu_count = tonumber(proc_cpu_count()) or 1
	local pid = proc_find_core_pid()

	if pid and pid ~= "" then
		local ticks = proc_core_cpu_ticks(pid)
		if ticks then
			cpu_ticks = tostring(ticks)
		end

		local loadavg = nixio.fs.readfile("/proc/loadavg")
		if loadavg then
			load_avg = loadavg:match("^%S+%s+(%S+)") or "0"
		end

		if not string.match(load_avg, "^[0-9]*%.?[0-9]*$") then
			load_avg = "0"
		end
	end

	HTTP.prepare_content("application/json")
	HTTP.write_json({
		cpu_ticks = cpu_ticks,
		cpu_count = tostring(cpu_count),
		load_avg = tostring(tonumber(load_avg) / cpu_count * 100);
	})
end

function action_toolbar_show()
	local pid = proc_find_core_pid()
	local connection, up_total, down_total = "0", "0", "0"
	local mem, cpu_ticks = 0, 0
	local load_avg = "0"
	local cpu_count = proc_cpu_count()
	if pid and pid ~= "" then
		local daip = daip()
		local cn_port = cn_port()
		if not daip or not cn_port then return end

		-- the totals are cumulative, the page turns two samples into the current rate
		local connections = json.parse(core_api_get("/connections"))
		if connections and connections.connections then
			connection = #(connections.connections)
			up_total = connections.uploadTotal
			down_total = connections.downloadTotal
		end

		mem = tonumber((fs.readfile("/proc/" .. pid .. "/status") or ""):match("VmRSS:%s+(%d+)")) or 0
		mem = mem * 1024
		cpu_ticks = proc_core_cpu_ticks(pid) or 0

		load_avg = (nixio.fs.readfile("/proc/loadavg") or ""):match("^%S+%s+(%S+)") or "0"
		if not string.match(load_avg, "^[0-9]*%.?[0-9]*$") then
			load_avg = "0"
		end
	end

	HTTP.prepare_content("application/json")
	HTTP.write_json({
		connections = connection,
		up_total = up_total,
		down_total = down_total,
		mem = mem,
		cpu_ticks = tostring(cpu_ticks),
		cpu_count = tostring(cpu_count),
		load_avg = tostring(tonumber(load_avg) / tonumber(cpu_count) * 100);
	})
end

function action_config_name()
	HTTP.prepare_content("application/json")
	HTTP.write_json({
		config_name = config_name(),
		config_path = config_path();
	})
end

function action_save_corever_branch()
	HTTP.prepare_content("application/json")
	HTTP.write_json({
		save_corever_branch = save_corever_branch();
	})
end

function action_one_key_update_check()
	HTTP.prepare_content("application/json")
	HTTP.write_json({
		corever = corever();
	})
end

function action_dashboard_type()
	local dashboard_type = fs.uci_get_config("config", "dashboard_type") or "Official"
	local yacd_type = fs.uci_get_config("config", "yacd_type") or "Official"
	local default_dashboard = fs.uci_get_config("config", "default_dashboard") or ""
	if not fs.isdirectory("/usr/share/openclash/ui/" .. default_dashboard) then
		default_dashboard = ""
	end
	HTTP.prepare_content("application/json")
	HTTP.write_json({
		dashboard_type = dashboard_type,
		yacd_type = yacd_type,
		yacd = fs.isdirectory("/usr/share/openclash/ui/yacd"),
		dashboard = fs.isdirectory("/usr/share/openclash/ui/dashboard"),
		metacubexd = fs.isdirectory("/usr/share/openclash/ui/metacubexd"),
		zashboard = fs.isdirectory("/usr/share/openclash/ui/zashboard"),
		default_dashboard = default_dashboard;
	})
end

function action_default_dashboard()
	local default_dashboard = HTTP.formvalue("name")
	if not default_dashboard or (default_dashboard ~= "Dashboard" and default_dashboard ~= "Yacd" and default_dashboard ~= "Metacubexd" and default_dashboard ~= "Zashboard") then
		HTTP.status(500, "Set Failed")
		return
	end
	if not fs.isdirectory("/usr/share/openclash/ui/" .. string.lower(default_dashboard)) then
		HTTP.status(500, "Set Failed")
		return
	end
	uci:set("openclash", "config", "default_dashboard", string.lower(default_dashboard))
	uci:commit("openclash")
	HTTP.prepare_content("application/json")
	HTTP.write_json({
		default_dashboard = default_dashboard;
	})
end

function action_switch_dashboard()
	local switch_name = HTTP.formvalue("name")
	local switch_type = HTTP.formvalue("type")
	local state = SYS.call(string.format('/usr/share/openclash/openclash_download_dashboard.sh "%s" "%s" >/dev/null 2>&1', switch_name, switch_type))
	if switch_name == "Dashboard" and tonumber(state) == 0 then
		if switch_type == "Official" then
			uci:set("openclash", "config", "dashboard_type", "Official")
			uci:commit("openclash")
		else
			uci:set("openclash", "config", "dashboard_type", "Meta")
			uci:commit("openclash")
		end
	elseif switch_name == "Yacd" and tonumber(state) == 0 then
		if switch_type == "Official" then
			uci:set("openclash", "config", "yacd_type", "Official")
			uci:commit("openclash")
		else
			uci:set("openclash", "config", "yacd_type", "Meta")
			uci:commit("openclash")
		end
	end
	HTTP.prepare_content("application/json")
	HTTP.write_json({
		download_state = state;
	})
end

function action_delete_dashboard()
	local delete_name = HTTP.formvalue("name")
	local delete_path = string.format("/usr/share/openclash/ui/%s", string.lower(delete_name))

	local panels = {
		"/usr/share/openclash/ui/dashboard",
		"/usr/share/openclash/ui/yacd",
		"/usr/share/openclash/ui/metacubexd",
		"/usr/share/openclash/ui/zashboard"
	}
	local existing_panels = 0
	for _, path in ipairs(panels) do
		if fs.isdirectory(path) then
			existing_panels = existing_panels + 1
		end
	end

	if existing_panels <= 1 then
		HTTP.prepare_content("application/json")
		HTTP.write_json({
			delete_state = 0,
			error = "Cannot delete the last remaining dashboard"
		})
		return
	end

	local state = SYS.call(string.format("rm -rf '%s' >/dev/null 2>&1", delete_path)) == 0 and 1 or 0
	if tonumber(state) == 1 then
		if delete_name == "Dashboard" then
			uci:set("openclash", "config", "dashboard_type", "Official")
			uci:commit("openclash")
		elseif delete_name == "Yacd" then
			uci:set("openclash", "config", "yacd_type", "Official")
			uci:commit("openclash")
		end
		if fs.uci_get_config("config", "default_dashboard") == string.lower(delete_name) then
			uci:set("openclash", "config", "default_dashboard", "")
			uci:commit("openclash")
		end
	end
	HTTP.prepare_content("application/json")
	HTTP.write_json({
		delete_state = state;
	})
end

function action_op_mode()
	local op_mode = fs.uci_get_config("config", "operation_mode")
	HTTP.prepare_content("application/json")
	HTTP.write_json({
		op_mode = op_mode;
	})
end

function action_switch_mode()
	local switch_mode = fs.uci_get_config("config", "operation_mode")
	if switch_mode == "redir-host" then
		uci:set("openclash", "config", "operation_mode", "fake-ip")
		uci:commit("openclash")
	else
		uci:set("openclash", "config", "operation_mode", "redir-host")
		uci:commit("openclash")
	end
	HTTP.prepare_content("application/json")
	HTTP.write_json({
		switch_mode = switch_mode;
	})
end

function action_conn_status(internal)
	local data = {
		clash = uci:get("openclash", "config", "enable") == "1",
		daip = daip(),
		dase = dase(),
		-- Keep the misspelled JSON keys for compatibility with existing views.
		db_foward_port = dashboard_forward_port(),
		db_foward_domain = dashboard_forward_domain(),
		db_forward_ssl = dashboard_forward_ssl(),
		cn_port = cn_port()
	}
	if internal then return data end
	HTTP.prepare_content("application/json")
	HTTP.write_json(data)
end

-- Serve page js files with translations compiled server-side: the <%:Message%> markers and
-- <%=...%> islands inside them are only valid after this rendering step.
function action_translate_js()
	local name = HTTP.formvalue("f") or ""
	local src = name:match("^[%w_]+$") and fs.readfile("/www/luci-static/resources/openclash/js/" .. name .. ".js")
	if not src then
		HTTP.status(404, "Not Found")
		return
	end
	-- loadc is absent on the ucode-based LuCI, where the catalogs load with the language
	local i18n = require("luci.i18n")
	if i18n.loadc then i18n.loadc("openclash") end
	HTTP.prepare_content("application/javascript; charset=UTF-8")
	-- safe to cache long: the htm templates stamp the script URL per release
	HTTP.header("Cache-Control", "private, max-age=31536000, immutable")
	require("luci.template").render_string(src)
end

function action_status()
	local status_data = action_conn_status(true)
	local rule_data = action_rule_mode(true)
	local oc_data = action_oc_settings(true)
	local proxy_data = action_proxy_info(true)

	local result = {
		-- status fields
		clash = status_data.clash,
		daip = status_data.daip,
		dase = status_data.dase,
		db_foward_port = status_data.db_foward_port,
		db_foward_domain = status_data.db_foward_domain,
		db_forward_ssl = status_data.db_forward_ssl,
		dashboard_custom_url = dashboard_custom_url(),
		dashboard_custom_clash_compatible = dashboard_custom_clash_compatible(),
		cn_port = status_data.cn_port,
		yacd = fs.isdirectory("/usr/share/openclash/ui/yacd"),
		dashboard = fs.isdirectory("/usr/share/openclash/ui/dashboard"),
		metacubexd = fs.isdirectory("/usr/share/openclash/ui/metacubexd"),
		zashboard = fs.isdirectory("/usr/share/openclash/ui/zashboard"),
		core_type = fs.uci_get_config("config", "core_type") or "Meta",
		-- run_mode
		run_mode = mode(),
		-- rule_mode
		rule_mode = rule_data.mode,
		-- oc_settings
		meta_sniffer = oc_data.meta_sniffer,
		respect_rules = oc_data.respect_rules,
		oversea = oc_data.oversea,
		stream_unlock = oc_data.stream_unlock,
		-- proxy_info
		mixed_port = proxy_data.mixed_port,
		auth_user = proxy_data.auth_user,
		auth_pass = proxy_data.auth_pass,
	}

	HTTP.prepare_content("application/json")
	HTTP.write_json(result)
end

-- Streaming write.
-- New LuCI buffers luci.http.write in C stdio and io.flush cannot reach it, so L.http:write
-- is used there; old LuCI has no L global and writes immediately.
-- pcall must never wrap write_padded: on old LuCI HTTP.write yields and Lua 5.1 cannot
-- yield across a C call. The first line fills the old path's buffer, the X-Accel-Buffering
-- header makes nginx forward every chunk, uhttpd passes it through.
local write_padded_first = true

local function write_padded(data)
	if write_padded_first then
		if L and L.http then
			L.http:header("X-Accel-Buffering", "no")
		else
			HTTP.header("X-Accel-Buffering", "no")
		end
		if L and L.http then
			L.http:write(string.rep(" ", 8192) .. "\n")
			L.http:write(data .. "\n")
		else
			HTTP.write(string.rep(" ", 8192) .. "\n")
			HTTP.write(data .. "\n")
		end
		write_padded_first = false
	else
		if L and L.http then
			L.http:write(data .. "\n")
		else
			HTTP.write(data .. "\n")
		end
	end
	io.flush()
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

function trans_line(data)
	if data == nil or data == "" then
		return ""
	end

	local line_trans = ""

	local has_timestamp = string.len(data) >= 19 and string.match(string.sub(data, 1, 19), "%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d")
	local time_part = ""
	local level_part = ""
	local content_start = has_timestamp and 21 or 1

	if has_timestamp then
		time_part = string.sub(data, 1, 20)
		local level_start, level_end, level_content = string.find(data, "%[([^%]]+)%]", 21)
		if level_start and level_end and level_start == 21 then
			level_part = "[" .. luci.i18n.translate(level_content) .. "] "
			content_start = level_end + 2
		end
	end

	local segments = {}
	local last_pos = content_start
	local pos = string.find(data, "【", content_start)

	while pos do
		if pos > last_pos then
			segments[#segments + 1] = {
				type = "trans",
				text = string.sub(data, last_pos, pos - 1)
			}
		end

		local close_pos = string.find(data, "】", pos + 1)
		if not close_pos then
			segments[#segments + 1] = {
				type = "trans",
				text = string.sub(data, pos, -1)
			}
			break
		end

		segments[#segments + 1] = {
			type = "no_trans",
			text = string.sub(data, pos, close_pos + 2)
		}

		last_pos = close_pos + 3
		pos = string.find(data, "【", last_pos)
	end

	if last_pos <= string.len(data) then
		segments[#segments + 1] = {
			type = "trans",
			text = string.sub(data, last_pos, -1)
		}
	end

	line_trans = time_part .. level_part
	for _, seg in ipairs(segments) do
		if seg.type == "trans" then
			line_trans = line_trans .. luci.i18n.translate(seg.text)
		else
			line_trans = line_trans .. seg.text
		end
	end

	return line_trans
end

function process_status(name)
	local cmd = string.format("%s |grep '%s' |grep -v grep", fs.ps_cmd(), name)
	local result = SYS.exec(cmd)
	return result ~= nil and result ~= "" and not result:match("^%s*$")
end

local START_SCRIPT_PATTERNS = {
	["init"] = { "/etc/init.d/[o]penclash" },
	["openclash.sh"] = { "[o]penclash\\.sh", "/etc/init\\.d/[o]penclash" },
	["openclash_core.sh"] = { "[o]penclash_core\\.sh", "/etc/init\\.d/[o]penclash" },
	["openclash_update.sh"] = { "[o]penclash_update\\.sh", "/etc/init\\.d/[o]penclash" },
}

local function stream_log_and_parse(reader)
	local buf = ""

	while true do
		local chunk = reader()
		if not chunk then break end
		buf = buf .. chunk
		while true do
			local nl = buf:find("\n")
			if not nl then break end
			local line = buf:sub(1, nl - 1)
			buf = buf:sub(nl + 1)
			line = line:gsub("^%s+", ""):gsub("%s+$", "")
			if line ~= "" then
				if line == "##FINISHED##" or line == "##CONTINUE##" then
					write_padded(line)
				else
					write_padded(trans_line(line))
				end
			end
		end
	end
	reader.kill()
end

function action_start()
	HTTP.prepare_content("text/plain; charset=utf-8")
	local logfile = "/tmp/openclash_start.log"
	local patterns = START_SCRIPT_PATTERNS[HTTP.formvalue("script")]
	if type(patterns) == "string" then
		patterns = { patterns }
	end

	local cmd
	if patterns then
		local pattern_cases = {}
		for idx, p in ipairs(patterns) do
			pattern_cases[#pattern_cases + 1] = string.format(
				"%d) %s | grep -v grep | grep \"%s\" | grep -v \"openclash_start\" | grep -c \"^\";;",
				idx, "$PS_CMD", p
			)
		end
		local check_fn = string.format(
			"check_liveness() { case \"$1\" in %s *) echo 0;; esac; }; ",
			table.concat(pattern_cases, " ")
		)
		cmd = string.format(
			"logfile='%s'; " ..
			check_fn ..
			"if [ \"$(ps --version 2>&1 | grep -c procps-ng)\" -eq 1 ]; then PS_CMD='ps -efw'; else PS_CMD='ps -w'; fi; " ..
			"bytes=$(wc -c < \"$logfile\" 2>/dev/null); bytes=${bytes:-0}; " ..
			"[ \"$bytes\" -gt 0 ] && tail -c +1 \"$logfile\" 2>/dev/null; " ..
			"seen=0; [ \"$bytes\" -gt 0 ] && seen=1; " ..
			"elapsed=0; i=1; miss=0; total=%d; " ..
			"while true; do " ..
			"new_bytes=$(wc -c < \"$logfile\" 2>/dev/null); new_bytes=${new_bytes:-0}; " ..
			"if [ \"$new_bytes\" -gt \"$bytes\" ] 2>/dev/null; then " ..
			"if [ \"$(tail -c 1 \"$logfile\" 2>/dev/null)\" = \"$(printf '\\n')\" ]; then " ..
			"tail -c +$((bytes + 1)) \"$logfile\" 2>/dev/null; bytes=$new_bytes; " ..
			"else tail -c +$((bytes + 1)) \"$logfile\" 2>/dev/null | awk '{ if (p) printf \"%%s\\n\", prev; prev = $0; p = 1 }'; " ..
			"bytes=$((new_bytes - $(tail -c +$((bytes + 1)) \"$logfile\" 2>/dev/null | awk 'END { print length($0) }'))); " ..
			"fi; seen=1; " ..
			"elif [ \"$new_bytes\" -lt \"$bytes\" ] 2>/dev/null; then " ..
			"if [ \"$(tail -c 1 \"$logfile\" 2>/dev/null)\" = \"$(printf '\\n')\" ]; then " ..
			"tail -c +1 \"$logfile\" 2>/dev/null; bytes=$new_bytes; " ..
			"else tail -c +1 \"$logfile\" 2>/dev/null | awk '{ if (p) printf \"%%s\\n\", prev; prev = $0; p = 1 }'; " ..
			"bytes=$((new_bytes - $(tail -c +1 \"$logfile\" 2>/dev/null | awk 'END { print length($0) }'))); " ..
			"fi; seen=1; " ..
			"fi; " ..
			"found=0; i=1; " ..
			"while [ \"$i\" -le \"$total\" ]; do " ..
			"liveness=$(check_liveness \"$i\"); " ..
			"if [ \"$liveness\" -gt 0 ] 2>/dev/null; then found=1; seen=1; break; fi; " ..
			"i=$((i + 1)); " ..
			"done; " ..
			"if [ \"$found\" = \"1\" ]; then miss=0; " ..
			"if [ \"$elapsed\" -ge 50 ]; then echo '##CONTINUE##'; exit 0; fi; " ..
			"else " ..
			"miss=$((miss + 1)); " ..
			"if [ \"$seen\" -eq 1 ] && [ \"$miss\" -ge 3 ]; then echo '##FINISHED##'; exit 0; fi; " ..
			"if [ \"$elapsed\" -ge 8 ]; then echo '##FINISHED##'; exit 0; fi; " ..
			"fi; " ..
			"sleep 1; elapsed=$((elapsed + 1)); " ..
			"done",
			logfile, #patterns
		)
	else
		cmd = string.format(
			"logfile='%s'; " ..
			"bytes=$(wc -c < \"$logfile\" 2>/dev/null); bytes=${bytes:-0}; " ..
			"[ \"$bytes\" -gt 0 ] && tail -c +1 \"$logfile\" 2>/dev/null; " ..
			"observed=0; [ \"$bytes\" -gt 0 ] && observed=1; " ..
			"elapsed=0; idle=0; " ..
			"while true; do " ..
			"new_bytes=$(wc -c < \"$logfile\" 2>/dev/null); new_bytes=${new_bytes:-0}; " ..
			"if [ \"$new_bytes\" -gt \"$bytes\" ] 2>/dev/null; then " ..
			"if [ \"$(tail -c 1 \"$logfile\" 2>/dev/null)\" = \"$(printf '\\n')\" ]; then " ..
			"tail -c +$((bytes + 1)) \"$logfile\" 2>/dev/null; bytes=$new_bytes; " ..
			"else tail -c +$((bytes + 1)) \"$logfile\" 2>/dev/null | awk '{ if (p) printf \"%%s\\n\", prev; prev = $0; p = 1 }'; " ..
			"bytes=$((new_bytes - $(tail -c +$((bytes + 1)) \"$logfile\" 2>/dev/null | awk 'END { print length($0) }'))); " ..
			"fi; observed=1; idle=0; " ..
			"elif [ \"$new_bytes\" -lt \"$bytes\" ] 2>/dev/null; then " ..
			"if [ \"$(tail -c 1 \"$logfile\" 2>/dev/null)\" = \"$(printf '\\n')\" ]; then " ..
			"tail -c +1 \"$logfile\" 2>/dev/null; bytes=$new_bytes; " ..
			"else tail -c +1 \"$logfile\" 2>/dev/null | awk '{ if (p) printf \"%%s\\n\", prev; prev = $0; p = 1 }'; " ..
			"bytes=$((new_bytes - $(tail -c +1 \"$logfile\" 2>/dev/null | awk 'END { print length($0) }'))); " ..
			"fi; observed=1; idle=0; " ..
			"else idle=$((idle + 1)); fi; " ..
			"if [ \"$observed\" -eq 1 ] && [ \"$idle\" -ge 10 ]; then echo '##FINISHED##'; exit 0; fi; " ..
			"if [ \"$elapsed\" -ge 50 ]; then echo '##FINISHED##'; exit 0; fi; " ..
			"if [ \"$observed\" -eq 0 ] && [ \"$elapsed\" -ge 3 ]; then echo '##FINISHED##'; exit 0; fi; " ..
			"sleep 1; elapsed=$((elapsed + 1)); " ..
			"done",
			logfile
		)
	end

	local reader = ltn12_popen(cmd)
	if not reader then return end

	stream_log_and_parse(reader)
end

function action_update()
	HTTP.prepare_content("application/json")
	HTTP.write_json({
		coremodel = coremodel(),
		corever = corever(),
		release_branch = release_branch(),
		smart_enable = smart_enable(),
		oix_core = is_oix(),
		pkg_type = fs.pkg_type(),
		coremetacv = coremetacv(),
		opcv = opcv(),
		github_address_mod = fs.uci_get_config("config", "github_address_mod") or "0",
		cdn_list = fs.cdn_list();
	})
end

function action_save_github_address_mod()
	local value = HTTP.formvalue("value") or ""
	uci:set("openclash", "config", "github_address_mod", value)
	uci:commit("openclash")
	HTTP.prepare_content("application/json")
	HTTP.write_json({
		success = true;
	})
end

function action_save_custom_addr()
	local addr = HTTP.formvalue("addr") or ""
	addr = addr:gsub("^%s+", ""):gsub("%s+$", "")
	local success = false
	if addr ~= "" and #addr <= 256 and addr:match("^https?://%S+$") then
		local list = {}
		local seen = {}
		local custom = uci:get("openclash", "config", "github_addr_custom")
		if type(custom) == "table" then
			for _, v in ipairs(custom) do
				if v ~= "" and not seen[v] then
					seen[v] = true
					list[#list + 1] = v
				end
			end
		elseif type(custom) == "string" then
			for v in custom:gmatch("%S+") do
				if not seen[v] then
					seen[v] = true
					list[#list + 1] = v
				end
			end
		end
		if not seen[addr] then
			list[#list + 1] = addr
			uci:set_list("openclash", "config", "github_addr_custom", list)
			uci:commit("openclash")
		end
		success = true
	end
	HTTP.prepare_content("application/json")
	HTTP.write_json({
		success = success;
	})
end

function action_last_version()
	HTTP.prepare_content("application/json")
	HTTP.write_json({
		corelv = corelv(),
		oplv = oplv();
	})
end

function action_opupdate()
	HTTP.prepare_content("application/json")
	HTTP.write_json({
		opup = opup();
	})
end

function action_check_core()
	HTTP.prepare_content("application/json")
	HTTP.write_json({
		core_status = check_core();
	})
end

function action_coreupdate()
	HTTP.prepare_content("application/json")
	HTTP.write_json({
		coreup = coreup();
	})
end

function action_close_all_connection()
	return SYS.call("sh /usr/share/openclash/openclash_history_get.sh 'close_all_conection'")
end

function action_reload_firewall()
	return SYS.call("/etc/init.d/openclash reload 'manual' >/dev/null 2>&1 &")
end

function action_download_rule()
	HTTP.prepare_content("application/json")
	HTTP.write_json({
		rule_download_status = download_rule();
	})
end

function action_refresh_log()
	HTTP.prepare_content("application/json")
	local logfile = "/tmp/openclash.log"
	local log_len = tonumber(HTTP.formvalue("log_len")) or 0
	local core_refresh = HTTP.formvalue("core_refresh") == "true"

	if not fs.access(logfile) then
		HTTP.write_json({
			len = 0,
			update = false,
			core_log = "",
			oc_log = ""
		})
		return
	end

	local total_lines = tonumber(SYS.exec("wc -l < " .. logfile)) or 0

	if total_lines == log_len and log_len > 0 then
		HTTP.write_json({
			len = total_lines,
			update = false,
			core_log = "",
			oc_log = ""
		})
		return
	end

	local exclude_pattern = "UDP%-Receive%-Buffer%-Size|^Sec%-Fetch%-Mode|^User%-Agent|^Access%-Control|^Accept|^Origin|^Referer|^Connection|^Pragma|^Cache%-"
	local core_pattern = "level=|^time="
	local limit = core_refresh and 2500 or 5000
	local start_line = (log_len > 0 and total_lines > log_len) and (log_len + 1) or 1
	local read_count = math.max(0, total_lines - start_line + 1)
	local core_raw, oc_raw
	local oc_truncated = false
	local core_truncated = false
	local core_log = ""
	local oc_log = ""

	local sed_range = string.format("sed -n '%d,%dp' '%s'", start_line, start_line + read_count - 1, logfile)

	local oc_cmd = string.format(
		"%s | grep -v -E '%s' | grep -v -E '%s' | tail -n %d",
		sed_range, exclude_pattern, core_pattern, limit + 1
	)

	oc_raw = SYS.exec(oc_cmd)

	if oc_raw and oc_raw ~= "" then
		local oc_logs = {}
		local oc_count = 0
		for line in oc_raw:gmatch("[^\n]+") do
			oc_count = oc_count + 1
			if not string.match(string.sub(line, 1, 19), "%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d") then
				line = os.date("%Y-%m-%d %H:%M:%S") .. ' [Fatal] ' .. line
			end
			oc_logs[#oc_logs + 1] = trans_line(line)
		end

		oc_truncated = (oc_count > limit)
		if oc_truncated and #oc_logs > limit then
			local kept = {}
			for i = #oc_logs - limit + 1, #oc_logs do
				kept[#kept + 1] = oc_logs[i]
			end
			oc_logs = kept
		end
		oc_log = #oc_logs > 0 and table.concat(oc_logs, "\n") or ""
	end

	if core_refresh then
		local core_cmd = string.format(
			"%s | grep -v -E '%s' | grep -E '%s' | tail -n %d",
			sed_range, exclude_pattern, core_pattern, limit + 1
		)
		core_raw = SYS.exec(core_cmd)

		if core_raw and core_raw ~= "" then
			local _, core_count = core_raw:gsub("\n", "")
			if core_raw:sub(-1) ~= "\n" then
				core_count = core_count + 1
			end

			core_truncated = (core_count > limit)
			if core_truncated then
				core_log = core_raw:match("\n(.+)") or ""
				core_log = core_log:gsub("\n$", "")
			else
				core_log = core_raw:gsub("\n$", "")
			end
		end
	end

	if core_truncated and core_log ~= "" then
		core_log = "...\n" .. core_log
	end
	if oc_truncated and oc_log ~= "" then
		oc_log = "...\n" .. oc_log
	end

	HTTP.write_json({
		len = total_lines,
		update = true,
		core_log = core_log,
		oc_log = oc_log
	})
end

function action_del_log()
	local log_type = HTTP.formvalue("type")
	if log_type == "debug" then
		SYS.exec(": > /tmp/openclash_debug.log")
	else
		SYS.exec(": > /tmp/openclash.log")
	end
	return
end

function action_del_start_log()
	fs.writefile("/tmp/openclash_start.log", "")
end

function action_diag_connection()
	local addr = HTTP.formvalue("addr")
	if addr and (datatype.hostname(addr) or datatype.ipaddr(addr)) then
		local cmd = string.format("/usr/share/openclash/openclash_debug_getcon.lua %s", addr)
		HTTP.prepare_content("text/plain")
		local reader = ltn12_popen(cmd)
		if not reader then return end
		local buf = ""
		while true do
			local chunk = reader()
			if not chunk then break end
			buf = buf .. chunk
			while true do
				local nl = buf:find("\n")
				if not nl then break end
				local line = buf:sub(1, nl - 1)
				buf = buf:sub(nl + 1)
				write_padded(line)
			end
		end
		reader.kill()
		return
	end
	HTTP.status(500, "Bad address")
end

function action_diag_dns()
	local addr = HTTP.formvalue("addr")
	if addr and datatype.hostname(addr)then
		local cmd = string.format("/usr/share/openclash/openclash_debug_dns.lua %s", addr)
		HTTP.prepare_content("text/plain")
		local reader = ltn12_popen(cmd)
		if not reader then return end
		local buf = ""
		while true do
			local chunk = reader()
			if not chunk then break end
			buf = buf .. chunk
			while true do
				local nl = buf:find("\n")
				if not nl then break end
				local line = buf:sub(1, nl - 1)
				buf = buf:sub(nl + 1)
				write_padded(line)
			end
		end
		reader.kill()
		return
	end
	HTTP.status(500, "Bad address")
end

function action_gen_debug_logs()
	HTTP.prepare_content("text/plain; charset=utf-8")
	local logfile = "/tmp/openclash_debug.log"

	local cmd = string.format(
		"logfile='%s'; : > \"$logfile\"; " ..
		"/usr/share/openclash/openclash_debug.sh >/dev/null 2>&1 & DEBUG_PID=$!; " ..
		"bytes=0; elapsed=0; while true; do " ..
		"new_bytes=$(wc -c < \"$logfile\" 2>/dev/null); new_bytes=${new_bytes:-0}; " ..
		"if [ \"$new_bytes\" -gt \"$bytes\" ] 2>/dev/null; then " ..
		"if [ \"$(tail -c 1 \"$logfile\" 2>/dev/null)\" = \"$(printf '\\n')\" ]; then " ..
		"tail -c +$((bytes + 1)) \"$logfile\" 2>/dev/null; bytes=$new_bytes; " ..
		"else tail -c +$((bytes + 1)) \"$logfile\" 2>/dev/null | awk '{ if (p) printf \"%%s\\n\", prev; prev = $0; p = 1 }'; " ..
		"bytes=$((new_bytes - $(tail -c +$((bytes + 1)) \"$logfile\" 2>/dev/null | awk 'END { print length($0) }'))); " ..
		"fi; elapsed=0; fi; " ..
		"if ! kill -0 $DEBUG_PID 2>/dev/null; then " ..
		"exit 0; " ..
		"fi; sleep 1; elapsed=$((elapsed + 1)); " ..
		"if [ $elapsed -ge 60 ]; then exit 0; fi; done",
		logfile
	)
	local reader = ltn12_popen(cmd)
	if not reader then return end

	local buf = ""

	while true do
		local chunk = reader()
		if not chunk then break end
		buf = buf .. chunk
		while true do
			local nl = buf:find("\n")
			if not nl then break end
			local line = buf:sub(1, nl - 1)
			buf = buf:sub(nl + 1)
			write_padded(line)
		end
	end
	reader.kill()
end

function action_get_debug_logs()
	local logfile = "/tmp/openclash_debug.log"
	if not fs.access(logfile) then
		return
	end
	HTTP.prepare_content("text/plain; charset=utf-8")
	local reader = ltn12_popen("exec cat '" .. logfile .. "'")
	luci.ltn12.pump.all(reader, HTTP.write)
	reader.kill()
end

function action_backup()
	local config = SYS.call("cp /etc/config/openclash /etc/openclash/openclash >/dev/null 2>&1")
	local reader = ltn12_popen("exec tar -C '/etc/openclash/' -cz . 2>/dev/null")

	HTTP.header(
		'Content-Disposition', 'attachment; filename="Backup-OpenClash-%s-%s-%s.tar.gz"' %{
			device_name, device_arh, os.date("%Y-%m-%d-%H-%M-%S")
		})

	HTTP.prepare_content("application/x-targz")
	luci.ltn12.pump.all(reader, HTTP.write)
	reader.kill()
	SYS.call("rm -rf /etc/openclash/openclash >/dev/null 2>&1")
end

function action_backup_ex_core()
	local config = SYS.call("cp /etc/config/openclash /etc/openclash/openclash >/dev/null 2>&1")
	local reader = ltn12_popen("echo 'core' > /tmp/oc_exclude.txt && exec tar -C '/etc/openclash/' -X '/tmp/oc_exclude.txt' -cz . 2>/dev/null")

	HTTP.header(
		'Content-Disposition', 'attachment; filename="Backup-OpenClash-Exclude-Cores-%s-%s-%s.tar.gz"' %{
			device_name, device_arh, os.date("%Y-%m-%d-%H-%M-%S")
		})

	HTTP.prepare_content("application/x-targz")
	luci.ltn12.pump.all(reader, HTTP.write)
	reader.kill()
	SYS.call("rm -rf /etc/openclash/openclash >/dev/null 2>&1")
end

function action_backup_only_config()
	local reader = ltn12_popen("exec tar -C '/etc/openclash' -cz './config' 2>/dev/null")

	HTTP.header(
		'Content-Disposition', 'attachment; filename="Backup-OpenClash-Config-%s-%s-%s.tar.gz"' %{
			device_name, device_arh, os.date("%Y-%m-%d-%H-%M-%S")
		})

	HTTP.prepare_content("application/x-targz")
	luci.ltn12.pump.all(reader, HTTP.write)
	reader.kill()
end

function action_backup_only_core()
	local reader = ltn12_popen("exec tar -C '/etc/openclash' -cz './core' 2>/dev/null")

	HTTP.header(
		'Content-Disposition', 'attachment; filename="Backup-OpenClash-Cores-%s-%s-%s.tar.gz"' %{
			device_name, device_arh, os.date("%Y-%m-%d-%H-%M-%S")
		})

	HTTP.prepare_content("application/x-targz")
	luci.ltn12.pump.all(reader, HTTP.write)
	reader.kill()
end

function action_backup_only_rule()
	local reader = ltn12_popen("exec tar -C '/etc/openclash' -cz './rule_provider' 2>/dev/null")

	HTTP.header(
		'Content-Disposition', 'attachment; filename="Backup-OpenClash-Only-Rule-Provider-%s-%s-%s.tar.gz"' %{
			device_name, device_arh, os.date("%Y-%m-%d-%H-%M-%S")
		})

	HTTP.prepare_content("application/x-targz")
	luci.ltn12.pump.all(reader, HTTP.write)
	reader.kill()
end

function action_backup_only_proxy()
	local reader = ltn12_popen("exec tar -C '/etc/openclash' -cz './proxy_provider' 2>/dev/null")

	HTTP.header(
		'Content-Disposition', 'attachment; filename="Backup-OpenClash-Proxy-Provider-%s-%s-%s.tar.gz"' %{
			device_name, device_arh, os.date("%Y-%m-%d-%H-%M-%S")
		})

	HTTP.prepare_content("application/x-targz")
	luci.ltn12.pump.all(reader, HTTP.write)
	reader.kill()
end

function ltn12_popen(command)
	local fdi, fdo = nixio.pipe()
	if not fdi or not fdo then return nil end

	local pid = nixio.fork()

	if pid > 0 then
		fdo:close()
		local reaped = false

		local function pipe_read()
			local ok_r, buffer = pcall(try_read, fdi, 16384)
			if ok_r and buffer then
				return buffer
			end

			if not reaped then
				local ok_w, wpid = pcall(nixio.waitpid, pid, "nohang")
				if ok_w and wpid then
					reaped = true
				end
			end

			if reaped then
				local ok_l, last = pcall(try_read, fdi, 16384)
				if ok_l and last then
					return last
				end
				pcall(fdi.close, fdi)
				return nil
			else
				nixio.nanosleep(0, 50000000)
				return ""
			end
		end

		local function pipe_kill()
			if not reaped then
				pcall(nixio.kill, pid, nixio.const.SIGTERM)
				nixio.nanosleep(0, 100000000)
				pcall(nixio.kill, pid, nixio.const.SIGKILL)
				nixio.waitpid(pid)
				reaped = true
			end
			pcall(fdi.close, fdi)
		end

		-- Lua 5.1 does not allow setting fields on functions.
		-- Use a callable table: reader() invokes __call, reader.kill() is a table field.
		local wrapper = { kill = pipe_kill }
		setmetatable(wrapper, { __call = function(_, ...) return pipe_read(...) end })
		return wrapper
	elseif pid == 0 then
		nixio.dup(fdo, nixio.stdout)
		fdi:close()
		fdo:close()
		nixio.exec("/bin/sh", "-c", command)
		os.exit(127)
	else
		fdi:close()
		fdo:close()
		return nil
	end
end

-- Only the plugin's own directories may be written, and the directory comes from this
-- table instead of the request; names are validated by is_safe_filename().
local plugin_file_dirs = {
	["/etc/openclash/config/"] = true,
	["/etc/openclash/proxy_provider/"] = true,
	["/etc/openclash/rule_provider/"] = true,
}

function create_file()
	local file_name = HTTP.formvalue("filename")
	local file_dir = HTTP.formvalue("filepath")
	if not plugin_file_dirs[file_dir] or not is_safe_filename(file_name) then
		HTTP.status(400, "Invalid file path")
		return
	end
	local file_path = file_dir..file_name
	fs.writefile(file_path, "")
	if not fs.isfile(file_path) then
		HTTP.status(500, "Create File Failed")
	end
	return
end

function rename_file()
	local new_file_name = HTTP.formvalue("new_file_name")
	local file_path = HTTP.formvalue("file_path")
	local old_file_name = HTTP.formvalue("file_name")
	if not plugin_file_dirs[file_path] or not is_safe_filename(old_file_name) or not is_safe_filename(new_file_name) then
		HTTP.status(400, "Invalid file path")
		return
	end
	local old_file_path = file_path .. old_file_name
	local new_file_path = file_path .. new_file_name
	local old_run_file_path = "/etc/openclash/" .. old_file_name
	local new_run_file_path = "/etc/openclash/" .. new_file_name
	if fs.rename(old_file_path, new_file_path) then
		if file_path == "/etc/openclash/config/" then
			if fs.uci_get_config("config", "config_path") == old_file_path then
				uci:set("openclash", "config", "config_path", new_file_path)
			end

			if fs.isfile(old_run_file_path) then
				fs.rename(old_run_file_path, new_run_file_path)
			end

			fs.config_refs(old_file_name, new_file_name)
		end
		HTTP.status(200, "Rename File Successful")
	else
		HTTP.status(500, "Rename File Failed")
	end
	return
end

function manual_stream_unlock_test()
	local type = HTTP.formvalue("type")
	local cmd = string.format('/usr/share/openclash/openclash_streaming_unlock.lua "%s"', type)
	if HTTP.formvalue("result") == "1" then
		cmd = cmd .. ' "result"'
	end
	HTTP.prepare_content("text/plain; charset=utf-8")
	local util = io.popen(cmd)
	if util and util ~= "" then
		while true do
			local ln = util:read("*l")
			if not ln then break end
			if ln ~= "" then
				write_padded(trans_line(ln))
			end
			if not process_status("openclash_streaming_unlock.lua "..type) or not process_status("openclash_streaming_unlock.lua ") then
				while true do
					ln = util:read("*l")
					if not ln then break end
					if ln ~= "" then
						write_padded(trans_line(ln))
					end
				end
				break
			end
		end
		util:close()
		return
	end
	HTTP.status(500, "Something Wrong While Testing...")
end

function all_proxies_stream_test()
	local type = HTTP.formvalue("type")
	local cmd = string.format('/usr/share/openclash/openclash_streaming_unlock.lua "%s" "%s"', type, "all")
	HTTP.prepare_content("text/plain; charset=utf-8")
	local util = io.popen(cmd)
	if util and util ~= "" then
		while true do
			local ln = util:read("*l")
			if not ln then break end
			if ln ~= "" then
				write_padded(trans_line(ln))
			end
			if not process_status("openclash_streaming_unlock.lua "..type) or not process_status("openclash_streaming_unlock.lua ") then
				break
			end
		end
		util:close()
		return
	end
	HTTP.status(500, "Something Wrong While Testing...")
end

function action_announcement()
	if not fs.access("/tmp/openclash_announcement") or fs.readfile("/tmp/openclash_announcement") == "" or fs.mtime("/tmp/openclash_announcement") < (os.time() - 86400) then
		local HTTP_CODE = SYS.exec("curl -SsL -m 5 -w '%{http_code}' -o /tmp/openclash_announcement https://raw.githubusercontent.com/vernesong/OpenClash/dev/announcement 2>/dev/null")
		if HTTP_CODE ~= "200" then
			fs.unlink("/tmp/openclash_announcement")
		end
	end
	local info = SYS.exec("cat /tmp/openclash_announcement 2>/dev/null") or ""
	HTTP.prepare_content("application/json")
	HTTP.write_json({
		content = info;
	})
end

function action_myip_check()
	local result = {}
	local random = math.random(100000000)
	HTTP.prepare_content("text/plain; charset=utf-8")

	local services = {
		{
			name = "pcol",
			url = string.format("https://whois.pconline.com.cn/ipJson.jsp?json=true&z=%d", random),
			parser = function(data)
				if data and data ~= "" then
					-- json.parse tolerates GBK bytes in string values (JSON structure is ASCII)
					local ok, parsed = pcall(json.parse, data)
					if ok and parsed and parsed.ip then
						local geo_parts = {}
						if parsed.pro and parsed.pro ~= "" then
							table.insert(geo_parts, parsed.pro)
						end
						if parsed.city and parsed.city ~= "" then
							table.insert(geo_parts, parsed.city)
						end
						if parsed.addr and parsed.addr ~= "" then
							local isp = string.match(parsed.addr, "%s(%S+)$")
							if isp then
								table.insert(geo_parts, isp)
							end
						end
						local geo = table.concat(geo_parts, " ")
						return {
							ip = parsed.ip,
							geo = HTTP.urlencode(geo),
							raw = true
						}
					end
				end
				return nil
			end
		},
		{
			name = "ipip",
			url = string.format("http://myip.ipip.net?z=%d", random),
			parser = function(data)
				if data and data ~= "" then
					local ip = string.match(data, "当前 IP：([%x:%.]+)")
					local geo = string.match(data, "来自于：(.+)")

					if ip and geo then
						geo = string.gsub(geo, "%s+", " ")
						geo = string.gsub(geo, "^%s*(.-)%s*$", "%1")

						return {
							ip = ip,
							geo = geo
						}
					end
				end
				return nil
			end
		},
		{
			name = "ipsb",
			url = string.format("https://api.ip.sb/geoip?z=%d", random),
			parser = function(data)
				if data and data ~= "" then
					local ok, ipsb_json = pcall(json.parse, data)
					if ok and ipsb_json and ipsb_json.ip then
						local geo_parts = {}
						if ipsb_json.country and ipsb_json.country ~= "" then
							table.insert(geo_parts, ipsb_json.country)
						end
						if ipsb_json.isp and ipsb_json.isp ~= "" then
							table.insert(geo_parts, ipsb_json.isp)
						end

						return {
							ip = ipsb_json.ip,
							geo = table.concat(geo_parts, " ")
						}
					end
				end
				return nil
			end
		},
		{
			name = "ipify",
			url = string.format("https://api.ipify.org/?format=json&z=%d", random),
			parser = function(data)
				if data and data ~= "" then
					local ok, ipify_json = pcall(json.parse, data)
					if ok and ipify_json and ipify_json.ip then
						return {
							ip = ipify_json.ip,
							geo = ""
						}
					end
				end
				return nil
			end
		}
	}

	local function create_concurrent_query(service)
		local fdi, fdo = nixio.pipe()
		if not fdi or not fdo then
			return nil
		end

		local cmd = string.format(
			'curl -SsL -m 10 -A "%s" "%s" 2>/dev/null',
			fs.user_agent, service.url
		)

		local pid = nixio.fork()

		if pid > 0 then
			fdo:close()
			return {
				pid = pid,
				service_name = service.name,
				fdi = fdi,
				closed = false,
				reader = function()
					return try_read(fdi, 4096)
				end,
				close = function()
					if fdi and not fdi.closed then
						pcall(fdi.close, fdi)
						fdi.closed = true
					end
				end
			}
		elseif pid == 0 then
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

	local queries = {}
	local pending_services = {}
	local MAX_CONCURRENT = 3

	for _, service in ipairs(services) do
		table.insert(pending_services, service)
	end

	for _ = 1, MAX_CONCURRENT do
		if #pending_services == 0 then break end
		local s = table.remove(pending_services, 1)
		local query = create_concurrent_query(s)
		if query then
			queries[s.name] = {
				query = query,
				parser = s.parser,
				data = ""
			}
		end
	end

	if next(queries) == nil then
		HTTP.prepare_content("application/json")
		HTTP.write_json({
			error = "Failed to create any queries"
		})
		return
	end

	local max_iterations = 150
	local iteration = 0
	local delay = 50000000
	local completed = {}

	while iteration < max_iterations do
		iteration = iteration + 1
		local new_queries = {}

		for name, info in pairs(queries) do
			if not completed[name] then
				local ok_w, wpid = pcall(nixio.waitpid, info.query.pid, "nohang")
				local ok_r, buffer = pcall(info.query.reader)

				if ok_r and buffer then
					info.data = info.data .. buffer
				end

				if ok_w and wpid then
					pcall(info.query.close)
					completed[name] = true

					local parsed_result = info.parser(info.data)
					if parsed_result then
						result[name] = parsed_result
						local ok_j, jdata = pcall(json.stringify, {
							service = name,
							ip = parsed_result.ip,
							geo = parsed_result.geo,
							raw = parsed_result.raw
						})
						if ok_j and jdata then write_padded(jdata) end
					end

					while #pending_services > 0 do
						local next_s = table.remove(pending_services, 1)
						local next_q = create_concurrent_query(next_s)
						if next_q then
							new_queries[next_s.name] = {
								query = next_q,
								parser = next_s.parser,
								data = ""
							}
							break
						end
					end
				else
					local ok_k, still_running = pcall(nixio.kill, info.query.pid, 0)
					if not (ok_k and still_running) then
						pcall(info.query.close)
						completed[name] = true

						local parsed_result = info.parser(info.data)
						if parsed_result then
							result[name] = parsed_result
							local ok_j, jdata = pcall(json.stringify, {
								service = name,
								ip = parsed_result.ip,
								geo = parsed_result.geo,
								raw = parsed_result.raw
							})
							if ok_j and jdata then write_padded(jdata) end
						end

						while #pending_services > 0 do
							local next_s = table.remove(pending_services, 1)
							local next_q = create_concurrent_query(next_s)
							if next_q then
								new_queries[next_s.name] = {
									query = next_q,
									parser = next_s.parser,
									data = ""
								}
								break
							end
						end
					end
				end
			end
		end

		for name, _ in pairs(queries) do
			if completed[name] then
				queries[name] = nil
			end
		end
		for name, info in pairs(new_queries) do
			queries[name] = info
		end

		if next(queries) == nil then
			break
		end

		nixio.nanosleep(0, delay)
		delay = math.min(delay * 2, 200000000)
	end

	for name, info in pairs(queries) do
		if not completed[name] then
			result[name] = { ip = "", geo = "", error = "timeout" }
			write_padded(json.stringify({ service = name, error = "timeout" }))
			pcall(nixio.kill, info.query.pid, nixio.const.SIGTERM)
			local reaped = false
			for _ = 1, 20 do
				local ok_w, wpid = pcall(nixio.waitpid, info.query.pid, "nohang")
				if ok_w and wpid then reaped = true break end
				local ok_k, alive = pcall(nixio.kill, info.query.pid, 0)
				if not (ok_k and alive) then
					pcall(nixio.waitpid, info.query.pid, 0)
					reaped = true
					break
				end
				nixio.nanosleep(0, 50000000)
			end
			if not reaped then
				pcall(nixio.kill, info.query.pid, nixio.const.SIGKILL)
				pcall(nixio.waitpid, info.query.pid, 0)
			end
			pcall(info.query.close)
		end
	end

	if result.ipify and result.ipify.ip and result.ipify.ip ~= "" then
		local geo_cmd = string.format(
			'wget -q -T 10 -O - -U %s %s 2>/dev/null',
			UTIL.shellquote(fs.user_agent), UTIL.shellquote("https://api.ip.sb/geoip/" .. result.ipify.ip)
		)
		local geo_data = SYS.exec(geo_cmd)

		if geo_data and geo_data ~= "" then
			local ok_geo, geo_json = pcall(json.parse, geo_data)
			if ok_geo and geo_json and geo_json.ip then
				local geo_parts = {}
				if geo_json.country and geo_json.country ~= "" then
					table.insert(geo_parts, geo_json.country)
				end
				if geo_json.isp and geo_json.isp ~= "" then
					table.insert(geo_parts, geo_json.isp)
				end
				local geo = table.concat(geo_parts, " ")
				result.ipify.geo = geo
				write_padded(json.stringify({ service = "ipify", geo = geo }))
			end
		end
	end

	write_padded(json.stringify({ complete = true }))
end

function latency_test(addr, on_result)
	local result = { success = false, response_time = 0, error = "" }

	if not addr then
		result.error = "Missing domain parameter"
		return result
	end

	if addr:match("^https?://") then
		addr = addr:gsub("^https?://([^/]+)/?.*$", "%1")
	end

	local urls = {}
	table.insert(urls, "https://" .. addr .. "/favicon.ico")
	table.insert(urls, "https://" .. addr)

	local queries = {}
	for _, test_url in ipairs(urls) do
		local fdi, fdo = nixio.pipe()
		if fdi and fdo then
			local cmd = string.format(
				'curl -sI -m 10 --connect-timeout 3 -w "%%{http_code},%%{time_total},%%{time_connect},%%{time_appconnect}" "%s" -o /dev/null 2>/dev/null',
				test_url
			)
			local pid = nixio.fork()
			if pid > 0 then
				fdo:close()
				table.insert(queries, { pid = pid, fdi = fdi, data = "" })
			elseif pid == 0 then
				nixio.dup(fdo, nixio.stdout)
				fdi:close()
				fdo:close()
				nixio.exec("/bin/sh", "-c", cmd)
			else
				if fdi then fdi:close() end
				if fdo then fdo:close() end
			end
		end
	end

	local function parse_output(data)
		if not data or data == "" then
			return nil, "No response"
		end
		local http_code, time_total, time_connect, time_appconnect =
			data:match("(%d+),([%d%.]+),([%d%.]+),([%d%.]+)")
		if not http_code then
			http_code, time_total, time_appconnect = data:match("(%d+),([%d%.]+),([%d%.]+)")
		end
		if http_code and tonumber(http_code) then
			local code = tonumber(http_code)
			local rt = 0
			if time_appconnect and tonumber(time_appconnect) > 0 then
				rt = math.floor(tonumber(time_appconnect) * 1000)
			elseif time_connect and tonumber(time_connect) > 0 then
				rt = math.floor(tonumber(time_connect) * 1000)
			else
				rt = math.floor((tonumber(time_total) or 0) * 1000)
			end
			if (code >= 200 and code < 400) or code == 403 or code == 404 then
				return rt, nil
			else
				return rt, "HTTP " .. code
			end
		end
		return nil, "Invalid response"
	end

	local completed = {}
	local delay = 50000000
	local max_iter = 140
	local iter = 0
	local first_success = nil
	local last_failure = { response_time = 0, error = "No response" }

	while iter < max_iter do
		iter = iter + 1
		for i, q in ipairs(queries) do
			if not completed[i] then
				local ok_r, buf = pcall(try_read, q.fdi, 4096)
				if ok_r and buf then q.data = q.data .. buf end
				local ok_w, wpid = pcall(nixio.waitpid, q.pid, "nohang")
				if ok_w and wpid then
					while true do
						local ok_b, b = pcall(try_read, q.fdi, 4096)
						if not ok_b or not b then break end
						q.data = q.data .. b
					end
					pcall(q.fdi.close, q.fdi)
					completed[i] = true
					local rt, err = parse_output(q.data)
					if rt and not err then
						if not first_success then
							first_success = rt
						end
					else
						last_failure.response_time = rt or 0
						last_failure.error = err or "No response"
					end
				else
					local ok_k, alive = pcall(nixio.kill, q.pid, 0)
					if not (ok_k and alive) then
						while true do
							local ok_b, b = pcall(try_read, q.fdi, 4096)
							if not ok_b or not b then break end
							q.data = q.data .. b
						end
						pcall(q.fdi.close, q.fdi)
						completed[i] = true
						local rt, err = parse_output(q.data)
						if rt and not err then
							if not first_success then
								first_success = rt
							end
						else
							last_failure.response_time = rt or 0
							last_failure.error = err or "No response"
						end
					end
				end
			end
		end

		if first_success then
			for i, q in ipairs(queries) do
				if not completed[i] then
					pcall(nixio.kill, q.pid, nixio.const.SIGTERM)
					local reaped = false
					for _ = 1, 20 do
						local ok_w, wpid = pcall(nixio.waitpid, q.pid, "nohang")
						if ok_w and wpid then reaped = true break end
						local ok_k, alive = pcall(nixio.kill, q.pid, 0)
						if not (ok_k and alive) then
							pcall(nixio.waitpid, q.pid, 0)
							reaped = true
							break
						end
						nixio.nanosleep(0, 50000000)
					end
					if not reaped then
						pcall(nixio.kill, q.pid, nixio.const.SIGKILL)
						pcall(nixio.waitpid, q.pid, 0)
					end
					pcall(q.fdi.close, q.fdi)
				end
			end
			result.success = true
			result.response_time = first_success
			result.error = ""
			if on_result then on_result(result) end
			return result
		end

		local remaining = 0
		for i, _ in ipairs(queries) do
			if not completed[i] then remaining = remaining + 1 end
		end
		if remaining == 0 then break end

		nixio.nanosleep(0, delay)
		delay = math.min(delay * 2, 200000000)
	end

	for i, q in ipairs(queries) do
		if not completed[i] then
			pcall(nixio.kill, q.pid, nixio.const.SIGTERM)
			local reaped = false
			for _ = 1, 20 do
				local ok_w, wpid = pcall(nixio.waitpid, q.pid, "nohang")
				if ok_w and wpid then reaped = true break end
				local ok_k, alive = pcall(nixio.kill, q.pid, 0)
				if not (ok_k and alive) then
					pcall(nixio.waitpid, q.pid, 0)
					reaped = true
					break
				end
				nixio.nanosleep(0, 50000000)
			end
			if not reaped then
				pcall(nixio.kill, q.pid, nixio.const.SIGKILL)
				pcall(nixio.waitpid, q.pid, 0)
			end
			pcall(q.fdi.close, q.fdi)
		end
	end

	result.success = false
	result.response_time = last_failure.response_time
	result.error = last_failure.error
	if on_result then on_result(result) end
	return result
end

local unlock_service_keys = { "prime_video", "bahamut", "bilibili", "claude", "dazn", "discovery", "disney", "gemini", "google", "hbo_max", "netflix", "openai", "paramount", "spotify", "steam", "tvb", "ytb" }
local unlock_service_labels = {
	prime_video = "Amazon Prime Video",
	bahamut = "Bahamut Anime",
	bilibili = "Bilibili",
	claude = "Claude",
	dazn = "DAZN",
	discovery = "Discovery Plus",
	disney = "Disney Plus",
	gemini = "Gemini",
	google = "Google",
	hbo_max = "HBO Max",
	netflix = "Netflix",
	openai = "OpenAI",
	paramount = "Paramount Plus",
	spotify = "Spotify",
	steam = "Steam",
	tvb = "TVB Anywhere+",
	ytb = "YouTube Premium",
}
local unlock_service_default = { "netflix", "ytb", "openai", "claude" }

function action_unlock_check()
	local service = HTTP.formvalue("service")
	local services = {}
	if service and service ~= "" then
		for _, name in ipairs(unlock_service_keys) do
			if name == service then
				services[#services + 1] = name
			end
		end
	else
		local selected = uci:get("openclash", "config", "unlock_check_services") or ""
		local seen = {}
		for name in selected:gmatch("[^,]+") do
			name = name:match("^%s*(.-)%s*$")
			if name ~= "" and not seen[name] and #services < 4 then
				for _, key in ipairs(unlock_service_keys) do
					if key == name then
						seen[key] = true
						services[#services + 1] = key
						break
					end
				end
			end
		end
		if #services == 0 then
			services = unlock_service_default
		end
	end

	HTTP.prepare_content("text/plain; charset=utf-8")

	if #services == 0 then
		write_padded(json.stringify({ complete = true }))
		return
	end

	local queries = {}
	for _, name in ipairs(services) do
		local fdi, fdo = nixio.pipe()
		if fdi and fdo then
			local cmd = string.format('lua "/usr/share/openclash/openclash_streaming_unlock.lua" "%s" "check"', unlock_service_labels[name] or name)
			local pid = nixio.fork()
			if pid > 0 then
				fdo:close()
				queries[#queries + 1] = { pid = pid, name = name, fdi = fdi, data = "", done = false }
			elseif pid == 0 then
				nixio.dup(fdo, nixio.stdout)
				fdi:close()
				fdo:close()
				nixio.exec("/bin/sh", "-c", cmd)
			else
				if fdi then fdi:close() end
				if fdo then fdo:close() end
			end
		end
	end

	if #queries == 0 then
		HTTP.prepare_content("application/json")
		HTTP.write_json({ error = "Failed to create any queries" })
		return
	end

	local pending = #queries
	local delay = 50000000
	local max_iterations = 280

	for _ = 1, max_iterations do
		for _, q in ipairs(queries) do
			if not q.done then
				local ok_r, buf = pcall(try_read, q.fdi, 4096)
				if ok_r and buf then
					q.data = q.data .. buf
				end

				local ok_w, wpid = pcall(nixio.waitpid, q.pid, "nohang")
				local finished = false
				if ok_w and wpid then
					finished = true
				else
					local ok_k, alive = pcall(nixio.kill, q.pid, 0)
					if not (ok_k and alive) then
						finished = true
						pcall(nixio.waitpid, q.pid, 0)
					end
				end

				if finished then
					local guard = 0
					while guard < 64 do
						guard = guard + 1
						local ok_b, b = pcall(try_read, q.fdi, 4096)
						if not ok_b or not b then break end
						q.data = q.data .. b
					end
					pcall(q.fdi.close, q.fdi)
					q.done = true
					pending = pending - 1

					local st = 0
					local region = ""
					local node = ""
					local ok_j, parsed = pcall(json.parse, string.gsub(q.data or "", "%s+$", ""))
					if ok_j and parsed and type(parsed) == "table" and parsed.st then
						st = tonumber(parsed.st) or 0
						region = parsed.region or ""
						node = parsed.node or ""
					end
					write_padded(json.stringify({ service = q.name, st = st, region = region, node = node }))
				end
			end
		end

		if pending == 0 then
			break
		end

		nixio.nanosleep(0, delay)
		delay = math.min(delay * 2, 200000000)
	end

	for _, q in ipairs(queries) do
		if not q.done then
			write_padded(json.stringify({ service = q.name, st = 0, region = "", node = "" }))
			pcall(nixio.kill, q.pid, nixio.const.SIGTERM)
			local reaped = false
			for _ = 1, 20 do
				local ok_w, wpid = pcall(nixio.waitpid, q.pid, "nohang")
				if ok_w and wpid then reaped = true break end
				local ok_k, alive = pcall(nixio.kill, q.pid, 0)
				if not (ok_k and alive) then
					pcall(nixio.waitpid, q.pid, 0)
					reaped = true
					break
				end
				nixio.nanosleep(0, 50000000)
			end
			if not reaped then
				pcall(nixio.kill, q.pid, nixio.const.SIGKILL)
				pcall(nixio.waitpid, q.pid, 0)
			end
			pcall(q.fdi.close, q.fdi)
		end
	end

	write_padded(json.stringify({ complete = true }))
end

function action_unlock_services()
	local valid = {}
	for _, name in ipairs(unlock_service_keys) do
		valid[name] = true
	end
	local input = HTTP.formvalue("services")
	local saved = false
	local raw = uci:get("openclash", "config", "unlock_check_services") or ""
	if input and input ~= "" then
		raw = input
		saved = true
	end
	local seen = {}
	local list = {}
	for item in raw:gmatch("[^,]+") do
		item = item:gsub("^%s+", ""):gsub("%s+$", "")
		if valid[item] and not seen[item] and #list < 4 then
			seen[item] = true
			list[#list + 1] = item
		end
	end
	if #list == 0 then
		list = unlock_service_default
	elseif saved then
		uci:set("openclash", "config", "unlock_check_services", table.concat(list, ","))
		uci:commit("openclash")
	end
	local enable = fs.uci_get_config("config", "enable") == "1"
	local self_proxy = fs.uci_get_config("config", "router_self_proxy")
	if self_proxy == nil then self_proxy = "1" end
	HTTP.prepare_content("application/json")
	HTTP.write_json({ services = list, enable = enable, auto_ready = enable and self_proxy == "1" })
end

function action_website_check()
	local domains_raw = HTTP.formvalue("domains")
	local domain = HTTP.formvalue("domain")

	local domain_list = {}
	if domains_raw and domains_raw ~= "" then
		for d in domains_raw:gmatch("[^,]+") do
			d = d:gsub("^%s+", ""):gsub("%s+$", "")
			if d ~= "" then domain_list[#domain_list + 1] = d end
		end
	elseif domain and domain ~= "" then
		domain_list[#domain_list + 1] = domain
	end

	if #domain_list == 0 then
		HTTP.prepare_content("application/json")
		HTTP.write_json({
			success = false,
			response_time = 0,
			error = "Missing domain parameter"
		})
		return
	end

	HTTP.prepare_content("text/plain; charset=utf-8")

	if #domain_list == 1 then
		latency_test(domain_list[1], function(r)
			write_padded(json.stringify(r))
		end)
		return
	end

	local MAX_CONCURRENT_DOMAINS = 2
	local pending_domains = {}
	for _, d in ipairs(domain_list) do
		table.insert(pending_domains, d)
	end

	local function launch_domain(d)
		local urls = {
			"https://" .. d .. "/favicon.ico",
			"https://" .. d
		}
		local sub_queries = {}
		for _, test_url in ipairs(urls) do
			local fdi, fdo = nixio.pipe()
			if fdi and fdo then
				local cmd = string.format(
					'curl -sI -m 10 --connect-timeout 3 -w "%%{http_code},%%{time_total},%%{time_connect},%%{time_appconnect}" "%s" -o /dev/null 2>/dev/null',
					test_url
				)
				local pid = nixio.fork()
				if pid > 0 then
					fdo:close()
					sub_queries[#sub_queries + 1] = { pid = pid, fdi = fdi, data = "", done = false }
				elseif pid == 0 then
					nixio.dup(fdo, nixio.stdout)
					fdi:close()
					fdo:close()
					nixio.exec("/bin/sh", "-c", cmd)
				else
					if fdi then fdi:close() end
					if fdo then fdo:close() end
				end
			end
		end
		return sub_queries
	end

	local function kill_domain_queries(sub_queries)
		for _, sq in ipairs(sub_queries) do
			if not sq.done then
				pcall(nixio.kill, sq.pid, nixio.const.SIGTERM)
				local reaped = false
				for _ = 1, 20 do
					local ok_w, wpid = pcall(nixio.waitpid, sq.pid, "nohang")
					if ok_w and wpid then reaped = true break end
					local ok_k, alive = pcall(nixio.kill, sq.pid, 0)
					if not (ok_k and alive) then
						pcall(nixio.waitpid, sq.pid, 0)
						reaped = true
						break
					end
					nixio.nanosleep(0, 50000000)
				end
				if not reaped then
					pcall(nixio.kill, sq.pid, nixio.const.SIGKILL)
					pcall(nixio.waitpid, sq.pid, 0)
				end
				pcall(sq.fdi.close, sq.fdi)
				sq.done = true
			end
		end
	end

	local function parse_latency(data)
		if not data or data == "" then return nil, "No response" end
		local http_code, time_total, time_connect, time_appconnect =
			data:match("(%d+),([%d%.]+),([%d%.]+),([%d%.]+)")
		if not http_code then
			http_code, time_total, time_appconnect = data:match("(%d+),([%d%.]+),([%d%.]+)")
		end
		if http_code and tonumber(http_code) then
			local code = tonumber(http_code)
			local rt = 0
			if time_appconnect and tonumber(time_appconnect) > 0 then
				rt = math.floor(tonumber(time_appconnect) * 1000)
			elseif time_connect and tonumber(time_connect) > 0 then
				rt = math.floor(tonumber(time_connect) * 1000)
			else
				rt = math.floor((tonumber(time_total) or 0) * 1000)
			end
			if (code >= 200 and code < 400) or code == 403 or code == 404 then
				return rt, nil
			else
				return rt, "HTTP " .. code
			end
		end
		return nil, "Invalid response"
	end

	local function check_sub_query(sq)
		local ok_r, buf = pcall(try_read, sq.fdi, 4096)
		if ok_r and buf then sq.data = sq.data .. buf end
		local ok_w, wpid = pcall(nixio.waitpid, sq.pid, "nohang")
		if ok_w and wpid then
			while true do
				local ok_b, b = pcall(try_read, sq.fdi, 4096)
				if not ok_b or not b then break end
				sq.data = sq.data .. b
			end
			pcall(sq.fdi.close, sq.fdi)
			sq.done = true
			return parse_latency(sq.data)
		else
			local ok_k, alive = pcall(nixio.kill, sq.pid, 0)
			if not (ok_k and alive) then
				while true do
					local ok_b, b = pcall(try_read, sq.fdi, 4096)
					if not ok_b or not b then break end
					sq.data = sq.data .. b
				end
				pcall(sq.fdi.close, sq.fdi)
				sq.done = true
				return parse_latency(sq.data)
			end
		end
		return nil, nil  -- still running
	end

	local active_domains = {}  -- { [domain] = { sub_queries, domain_done } }
	local domains_completed = {}
	local delay = 50000000
	local max_iter = 150
	local iter = 0

	while #pending_domains > 0 and #active_domains < MAX_CONCURRENT_DOMAINS do
		local d = table.remove(pending_domains, 1)
		local sqs = launch_domain(d)
		if #sqs > 0 then
			active_domains[d] = { sub_queries = sqs, domain_done = false }
		else
			domains_completed[d] = true
			write_padded(json.stringify({ domain = d, success = false, response_time = 0, error = "Failed to launch" }))
		end
	end

	while iter < max_iter do
		iter = iter + 1

		for d, ad in pairs(active_domains) do
			if not ad.domain_done then
				local first_success_result = nil
				local last_failure_result = nil
				local all_done = true

				for _, sq in ipairs(ad.sub_queries) do
					if not sq.done then
						local rt, err = check_sub_query(sq)
						if rt and not err then
							first_success_result = { success = true, response_time = rt, error = "" }
						elseif rt or err then
							last_failure_result = { success = false, response_time = rt or 0, error = err or "No response" }
						else
							all_done = false
						end
					end
				end

				if first_success_result or all_done then
					ad.domain_done = true
					domains_completed[d] = true
					kill_domain_queries(ad.sub_queries)

					local result = first_success_result or last_failure_result or { success = false, response_time = 0, error = "No response" }
					result.domain = d
					write_padded(json.stringify(result))

					while #pending_domains > 0 do
						local next_d = table.remove(pending_domains, 1)
						local sqs = launch_domain(next_d)
						if #sqs > 0 then
							active_domains[next_d] = { sub_queries = sqs, domain_done = false }
							break
						else
							domains_completed[next_d] = true
							write_padded(json.stringify({ domain = next_d, success = false, response_time = 0, error = "Failed to launch" }))
						end
					end
				end
			end
		end

		local all_done = true
		for _, d in ipairs(domain_list) do
			if not domains_completed[d] then all_done = false; break end
		end
		if all_done then break end

		nixio.nanosleep(0, delay)
		delay = math.min(delay * 2, 200000000)
	end

	for d, ad in pairs(active_domains) do
		if not domains_completed[d] then
			kill_domain_queries(ad.sub_queries)
			domains_completed[d] = true
			write_padded(json.stringify({ domain = d, success = false, response_time = 0, error = "timeout" }))
		end
	end

	for _, d in ipairs(pending_domains) do
		write_padded(json.stringify({ domain = d, success = false, response_time = 0, error = "timeout" }))
	end
end

function action_version_history()
	local branch = HTTP.formvalue("branch") or "master"
	local force = HTTP.formvalue("force") == "1"
	local parsed = ov.fetch_version_history(branch, force)

	HTTP.prepare_content("text/plain; charset=utf-8")
	if parsed.plugin then
		for _, entry in ipairs(parsed.plugin) do
			entry.type = "plugin"
			write_padded(json.stringify(entry))
		end
	end
	if parsed.core_meta then
		for _, entry in ipairs(parsed.core_meta) do
			entry.type = "core_meta"
			write_padded(json.stringify(entry))
		end
	end
	if parsed.core_smart then
		for _, entry in ipairs(parsed.core_smart) do
			entry.type = "core_smart"
			write_padded(json.stringify(entry))
		end
	end
	local complete_line = {complete = true}
	if parsed.error then
		complete_line.error = parsed.error
	end
	write_padded(json.stringify(complete_line))
end

-- action_cdn_info: stream per-CDN plugin/core version + latency via forked
-- subprocesses (text/plain JSON-lines, one line per CDN + a complete line).
-- LuCI ucode-bridge caveats that were fixed here:
--   * fork children must not call uci/fs.uci_get_config (inherits the parent
--     uci lock -> deadlock); build all URLs and the shell cmd in the parent.
--   * children must do zero Lua work and exec immediately, otherwise the
--     leftover LuCI/ucode runtime renders a 500 page into the pipe.
--   * MAX_CONCURRENT=4; curl -m 5 and max_iter=250: the poll loop waits at
--     most ~50s (delay ramps 50ms->200ms), covering 15 CDNs / 4 waves x 15s
--     (2 curls + core fallback at 5s each), still within the uhttpd 60s
--     script_timeout; core curl falls back to raw.githubusercontent.com
--     when the CDN fails.
function action_cdn_info()
	HTTP.prepare_content("text/plain; charset=utf-8")
	local cdns_raw = HTTP.formvalue("addrs")
	local branch = HTTP.formvalue("branch") or "dev"
	local plugin_ver = HTTP.formvalue("plugin_ver") or ""
	local core_ver = HTTP.formvalue("core_ver") or ""

	if not cdns_raw or cdns_raw == "" then
		write_padded('{"complete":true,"error":"Missing addrs parameter"}')
		return
	end

	local cdns = {}
	local seen = {}
	for c in cdns_raw:gmatch("[^,]+") do
		c = c:gsub("^%s+", ""):gsub("%s+$", "")
		if c ~= "" and not seen[c] then
			seen[c] = true
			table.insert(cdns, c)
		end
	end

	if #cdns == 0 then
		write_padded('{"complete":true,"error":"No valid CDNs"}')
		return
	end

	-- Read cache (skip if forced refresh)
	local force = HTTP.formvalue("force") == "1"
	local merge = HTTP.formvalue("merge") == "1"
	local cur_oix = is_oix()
	local function version_ident(v)
		if v ~= "" and v ~= "__latest__" then return v end
		return nil
	end
	local p_ident = version_ident(plugin_ver)
	local c_ident = version_ident(core_ver)
	local ver_key
	if p_ident and c_ident then
		ver_key = (p_ident == c_ident) and p_ident or (p_ident .. "_" .. c_ident)
	elseif p_ident then
		ver_key = p_ident
	elseif c_ident then
		ver_key = c_ident
	else
		ver_key = "latest"
	end
	local cache_key = branch .. "_" .. ver_key
	local cache_file = "/tmp/openclash_cdn_info.json"
	local parsed_cache = nil
	if fs.access(cache_file) then
		local cached = fs.readfile(cache_file)
		if cached then
			local ok, parsed = pcall(json.parse, cached)
			if ok and parsed and type(parsed) == "table" then
				local entry = parsed[cache_key]
				if entry and entry.cached_at and entry.oix == cur_oix then
					local ttl = entry.cache_ttl or 300
					if (os.time() - entry.cached_at) < ttl then
						parsed_cache = entry
					end
				end
			end
		end
	end

	if not force and not merge and parsed_cache then
		if parsed_cache.result then
			for cdn, info in pairs(parsed_cache.result) do
				info.addr = cdn
				write_padded(json.stringify(info))
			end
		end
		local complete_line = {complete = true}
		if parsed_cache.result and parsed_cache.result.error then
			complete_line.error = parsed_cache.result.error
		end
		write_padded(json.stringify(complete_line))
		return
	end

	local function classify_cdn(url)
		if not url or url == "" then return "raw" end
		if url:match("raw%.githubusercontent%.com") then return "raw" end
		if url:match("jsdelivr") or url:match("fastly") or url:match("testingcf") then return "jsdelivr" end
		if url:match("dl%.dler%.io") then return "dler" end
		return "proxy"
	end

	local function build_version_url(cdn, file_type)
		if file_type == "core" and is_oix() then
			local oix_version = "https://github.com/vernesong/mihomo-oix/releases/download/Pre-Alpha/version.txt"
			local oix_dler = "https://dl.dler.io/mihomo-oix/version.txt?tag=Pre-Alpha"
			local ctype = classify_cdn(cdn)
			if ctype == "dler" then
				return oix_dler
			elseif ctype == "proxy" then
				return cdn .. oix_version
			elseif ctype == "jsdelivr" then
				return oix_dler
			end
			return oix_version
		end

		local file = file_type == "plugin" and branch .. "/version" or branch .. "/core_version"
		local ref
		if file_type == "plugin" then
			ref = (plugin_ver ~= "" and plugin_ver ~= "__latest__") and plugin_ver or "package"
		else
			ref = (core_ver ~= "" and core_ver ~= "__latest__") and core_ver or "core"
		end
		local ctype = classify_cdn(cdn)

		if ctype == "raw" then
			return "https://raw.githubusercontent.com/vernesong/OpenClash/" .. ref .. "/" .. file
		elseif ctype == "jsdelivr" then
			return cdn .. "gh/vernesong/OpenClash@" .. ref .. "/" .. file
		else
			return cdn .. "https://raw.githubusercontent.com/vernesong/OpenClash/" .. ref .. "/" .. file
		end
	end

	local function parse_cdn_data(data)
		if not data or data == "" then return nil end
		local ok, parsed = pcall(json.parse, data)
		if not ok or not parsed or type(parsed) ~= "table" then return nil end
		if parsed.plugin_ver and not ov.is_valid_version(parsed.plugin_ver) then parsed.plugin_ver = "" end
		if parsed.core_meta_ver and not ov.is_valid_version(parsed.core_meta_ver) then parsed.core_meta_ver = "" end
		if parsed.core_smart_ver and not ov.is_valid_version(parsed.core_smart_ver) then parsed.core_smart_ver = "" end
		return parsed
	end

	local queries = {}
	local result = {}
	local pending_cdns = {}
	local MAX_CONCURRENT = 4
	local active = 0
	local completed = {}
	local delay = 50000000
	local max_iter = 250
	local iter = 0

	local oix_mode, oix_core_ver, oix_core_error = ov.prepare_oix_cdn_data(force)

	if merge and parsed_cache and parsed_cache.result then
		for cdn, info in pairs(parsed_cache.result) do
			if seen[cdn] and type(info) == "table" and not result[cdn] then
				result[cdn] = info
				result[cdn].addr = cdn
				write_padded(json.stringify(info))
			end
		end
	end

	for _, cdn in ipairs(cdns) do
		if not result[cdn] then
			table.insert(pending_cdns, cdn)
		end
	end

	local function launch_cdn(cdn)
		pcall(io.flush)
		local plugin_url = build_version_url(cdn, "plugin")
		local core_url = build_version_url(cdn, "core")
		local raw_core_url = ""
		if not is_oix() then
			local raw_ref = (core_ver ~= "" and core_ver ~= "__latest__") and core_ver or "core"
			raw_core_url = "https://raw.githubusercontent.com/vernesong/OpenClash/" .. raw_ref .. "/" .. branch .. "/core_version"
		end
		local cmd = string.format([[
PLUGIN_VER=""
CORE_META_VER="%s"
CORE_SMART_VER=""
CORE_ERR="%s"
OIX_MODE="%s"
RAW_CORE_URL="%s"
LATENCY="null"

PLUGIN_RAW=$(curl -sL -m 5 -w '\n%%{http_code} %%{time_starttransfer}' "%s" 2>/dev/null)
P_EXIT=$?

if [ $P_EXIT -eq 0 ] && [ -n "$PLUGIN_RAW" ]; then
	P_CODE=$(echo "$PLUGIN_RAW" | tail -1 | awk '{print $1}')
	P_TIME=$(echo "$PLUGIN_RAW" | tail -1 | awk '{printf "%%d", $2 * 1000}')
	if [ "$P_CODE" -ge 200 ] 2>/dev/null && [ "$P_CODE" -lt 400 ] 2>/dev/null && [ "$P_TIME" -gt 0 ] 2>/dev/null; then
		PLUGIN_VER=$(echo "$PLUGIN_RAW" | sed '$d' | head -1 | tr -d '\n\r')
		LATENCY=$P_TIME
	else
		[ "$P_CODE" = "404" ] && LATENCY=-3 || LATENCY=-2
	fi
elif [ $P_EXIT -ne 0 ]; then
	LATENCY=-1
else
	LATENCY=-2
fi

CORE_RAW=$(curl -sL -m 5 -w '\n%%{http_code} %%{time_starttransfer}' "%s" 2>/dev/null)
C_EXIT=$?
if [ $C_EXIT -ne 0 ] && [ -n "$RAW_CORE_URL" ]; then
	CORE_RAW=$(curl -sL -m 5 -w '\n%%{http_code} %%{time_starttransfer}' "$RAW_CORE_URL" 2>/dev/null)
	C_EXIT=$?
fi

if [ $C_EXIT -eq 0 ] && [ -n "$CORE_RAW" ]; then
	C_CODE=$(echo "$CORE_RAW" | tail -1 | awk '{print $1}')
	C_TIME=$(echo "$CORE_RAW" | tail -1 | awk '{printf "%%d", $2 * 1000}')
	if [ "$C_CODE" -ge 200 ] 2>/dev/null && [ "$C_CODE" -lt 400 ] 2>/dev/null && [ "$C_TIME" -gt 0 ] 2>/dev/null; then
		CORE_META_VER=$(echo "$CORE_RAW" | sed '$d' | sed -n '1p' | tr -d '\n\r')
		CORE_SMART_VER=$(echo "$CORE_RAW" | sed '$d' | sed -n '2p' | tr -d '\n\r')
		CORE_ERR=""
		if [ "$LATENCY" = "null" ] || [ "$C_TIME" -lt "$LATENCY" ] 2>/dev/null; then
			LATENCY=$C_TIME
		fi
	elif [ "$LATENCY" != "null" ] && [ "$LATENCY" != "-3" ]; then
		CORE_ERR="denied"
	else
		[ "$C_CODE" = "404" ] && LATENCY=-3 || LATENCY=-2
		CORE_ERR="denied"
	fi
elif [ $C_EXIT -ne 0 ]; then
	[ "$LATENCY" = "null" ] && LATENCY=-1
	CORE_ERR="timeout"
else
	[ "$LATENCY" = "null" ] && LATENCY=-2
	CORE_ERR="denied"
fi

printf '{"plugin_ver":"%%s","core_meta_ver":"%%s","core_smart_ver":"%%s","latency":%%s,"core_error":"%%s"}\n' \
	"$PLUGIN_VER" "$CORE_META_VER" "$CORE_SMART_VER" "${LATENCY:-null}" "$CORE_ERR"
]], oix_core_ver, oix_core_error, oix_mode and "1" or "0", raw_core_url, plugin_url, core_url)
		local fdi, fdo = nixio.pipe()
		if fdi and fdo then
			local pid = nixio.fork()
			if pid > 0 then
				fdo:close()
				queries[cdn] = { pid = pid, fdi = fdi, data = "" }
				active = active + 1
			elseif pid == 0 then
				nixio.dup(fdo, nixio.stdout)
				fdi:close()
				fdo:close()
				nixio.exec("/bin/sh", "-c", cmd)
			else
				if fdi then fdi:close() end
				if fdo then fdo:close() end
			end
		end
	end

	while active < MAX_CONCURRENT do
		local next_cdn = nil
		for i, cdn in ipairs(pending_cdns) do
			if not completed[cdn] then
				next_cdn = cdn
				table.remove(pending_cdns, i)
				break
			end
		end
		if not next_cdn then break end
		launch_cdn(next_cdn)
	end

	if next(queries) == nil then
		if next(result) == nil then
			write_padded('{"complete":true,"error":"Failed to create queries"}')
			return
		end
	end

	iter = 0

	while iter < max_iter do
		iter = iter + 1

		for cdn, q in pairs(queries) do
			if not completed[cdn] then
				local ok_r, buf = pcall(try_read, q.fdi, 4096)
				if ok_r and buf then q.data = q.data .. buf end
				local ok_w, wpid = pcall(nixio.waitpid, q.pid, "nohang")
				if ok_w and wpid then
					while true do
						local ok_b, b = pcall(try_read, q.fdi, 4096)
						if not ok_b or not b then break end
						q.data = q.data .. b
					end
					pcall(q.fdi.close, q.fdi)
					completed[cdn] = true
					active = active - 1
					local parsed = parse_cdn_data(q.data)
					if parsed then result[cdn] = parsed end
					if not result[cdn] then
						result[cdn] = { plugin_ver = "", core_meta_ver = "", latency = -1 }
					end
					result[cdn].addr = cdn
					local ok_j, jdata = pcall(json.stringify, result[cdn])
					if ok_j and jdata then write_padded(jdata) end
					queries[cdn] = nil
				else
					local ok_k, alive = pcall(nixio.kill, q.pid, 0)
					if not (ok_k and alive) then
						while true do
							local ok_b, b = pcall(try_read, q.fdi, 4096)
							if not ok_b or not b then break end
							q.data = q.data .. b
						end
						pcall(q.fdi.close, q.fdi)
						completed[cdn] = true
						active = active - 1
						local parsed = parse_cdn_data(q.data)
						if parsed then result[cdn] = parsed end
						if not result[cdn] then
							result[cdn] = { plugin_ver = "", core_meta_ver = "", latency = -1 }
						end
						result[cdn].addr = cdn
						local ok_j, jdata = pcall(json.stringify, result[cdn])
						if ok_j and jdata then write_padded(jdata) end
						queries[cdn] = nil
					end
				end
			end
		end

		while active < MAX_CONCURRENT do
			local next_cdn = nil
			for i, cdn in ipairs(pending_cdns) do
				if not completed[cdn] then
					next_cdn = cdn
					table.remove(pending_cdns, i)
					break
				end
			end
			if not next_cdn then break end
			launch_cdn(next_cdn)
		end

		local remaining = 0
		for _ in pairs(queries) do remaining = remaining + 1 end
		for _ in pairs(pending_cdns) do remaining = remaining + 1 end
		if remaining == 0 then break end

		nixio.nanosleep(0, delay)
		delay = math.min(delay * 2, 200000000)
	end

	for cdn, q in pairs(queries) do
		if not completed[cdn] then
			pcall(nixio.kill, q.pid, nixio.const.SIGTERM)
			local reaped = false
			for _ = 1, 20 do
				local ok_w, wpid = pcall(nixio.waitpid, q.pid, "nohang")
				if ok_w and wpid then reaped = true break end
				local ok_k, alive = pcall(nixio.kill, q.pid, 0)
				if not (ok_k and alive) then
					pcall(nixio.waitpid, q.pid, 0)
					reaped = true
					break
				end
				nixio.nanosleep(0, 50000000)
			end
			if not reaped then
				pcall(nixio.kill, q.pid, nixio.const.SIGKILL)
				pcall(nixio.waitpid, q.pid, 0)
			end
			while true do
				local ok_b, b = pcall(try_read, q.fdi, 4096)
				if not ok_b or not b then break end
				q.data = q.data .. b
			end
			pcall(q.fdi.close, q.fdi)
			local parsed = parse_cdn_data(q.data)
			if parsed then result[cdn] = parsed end
			if not result[cdn] then
				result[cdn] = { plugin_ver = "", core_meta_ver = "", latency = -1 }
			end
			result[cdn].addr = cdn
			local ok_j, jdata = pcall(json.stringify, result[cdn])
			if ok_j and jdata then write_padded(jdata) end
		end
	end

	for _, cdn in ipairs(pending_cdns) do
		if not result[cdn] then
			result[cdn] = { plugin_ver = "", core_meta_ver = "", latency = -1 }
			result[cdn].addr = cdn
			local ok_j, jdata = pcall(json.stringify, result[cdn])
			if ok_j and jdata then write_padded(jdata) end
		end
	end

	-- Determine cache TTL
	local cache_ttl = 300
	local has_data = false
	local all_stale = true
	for _, v in pairs(result) do
		if (v.plugin_ver and v.plugin_ver ~= "") or (v.core_meta_ver and v.core_meta_ver ~= "") or (v.latency and v.latency > 0) then
			has_data = true
			all_stale = false
			break
		end
		if v.latency ~= -3 then
			all_stale = false
		end
	end
	if not has_data then
		cache_ttl = 5
	end
	if all_stale and next(result) ~= nil then
		result.error = "version_stale"
		write_padded('{"complete":true,"error":"version_stale"}')
	else
		write_padded('{"complete":true}')
	end

	local cdn_cache = {}
	if fs.access(cache_file) then
		local cached = fs.readfile(cache_file)
		if cached then
			local ok, parsed = pcall(json.parse, cached)
			if ok and parsed and type(parsed) == "table" then
				cdn_cache = parsed
			end
		end
	end
	local now = os.time()
	for k, v in pairs(cdn_cache) do
		if type(v) == "table" and v.cached_at then
			local ttl = v.cache_ttl or 300
			if now - v.cached_at > ttl then
				cdn_cache[k] = nil
			end
		end
	end
	cdn_cache[cache_key] = {
		result = result,
		cache_ttl = cache_ttl,
		cached_at = now,
		oix = cur_oix
	}
	fs.writefile(cache_file, json.stringify(cdn_cache))
end

function action_proxy_info(internal)
	local result = {
		mixed_port = "",
		auth_user = "",
		auth_pass = ""
	}

	local mixed_port = fs.uci_get_config("config", "mixed_port")
	if mixed_port and mixed_port ~= "" then
		result.mixed_port = mixed_port
	else
		result.mixed_port = "7893"
	end

	uci:foreach("openclash", "authentication", function(section)
		if section.enabled == "1" and result.auth_user == "" then
			if section.username and section.username ~= "" then
				result.auth_user = section.username
			end
			if section.password and section.password ~= "" then
				result.auth_pass = section.password
			end
			return false
		end
	end)

	if internal then return result end
	HTTP.prepare_content("application/json")
	HTTP.write_json(result)
end

function action_oc_settings(internal)
	local result = {
		meta_sniffer = "0",
		respect_rules = "0",
		oversea = "0",
		stream_unlock = "0"
	}

	local meta_sniffer = fs.uci_get_config("config", "enable_meta_sniffer")
	if meta_sniffer == "1" then
		result.meta_sniffer = "1"
	end

	local respect_rules = fs.uci_get_config("config", "enable_respect_rules")
	if respect_rules == "1" then
		result.respect_rules = "1"
	end

	local oversea = fs.uci_get_config("config", "china_ip_route")
	if oversea == "1" then
		result.oversea = "1"
	elseif oversea == "2" then
		result.oversea = "2"
	else
		result.oversea = "0"
	end

	local stream_unlock = fs.uci_get_config("config", "stream_auto_select")
	if stream_unlock == "1" then
		result.stream_unlock = "1"
	end

	if internal then return result end
	HTTP.prepare_content("application/json")
	HTTP.write_json(result)
end

function action_switch_oc_setting()
	local setting = HTTP.formvalue("setting")
	local value = HTTP.formvalue("value")

	if not setting or not value then
		HTTP.status(500, "Missing parameters")
		return
	end

	local function get_runtime_config_path()
		local config_path = fs.uci_get_config("config", "config_path")
		if not config_path then
			return nil
		end
		local config_filename = fs.basename(config_path)
		return "/etc/openclash/" .. config_filename
	end

	local function update_runtime_config(ruby_cmd)
		local runtime_config_path = get_runtime_config_path()
		if not runtime_config_path then
			HTTP.status(500, "No config path found")
			return false
		end

		local ruby_result = SYS.call(ruby_cmd)
		if ruby_result ~= 0 then
			HTTP.status(500, "Failed to modify config file")
			return false
		end

		local daip = daip()
		local dase = dase() or ""
		local cn_port = cn_port()
		if not daip or not cn_port then
			HTTP.status(500, "Switch Failed")
			return false
		end

		local reload_result = SYS.exec(string.format('curl -sL -m 5 --connect-timeout 2 --retry 2 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XPUT http://"%s":"%s"/configs?force=true -d \'{"path":"%s"}\' 2>&1', dase, daip, cn_port, runtime_config_path))

		if reload_result ~= "" then
			HTTP.status(500, "Switch Failed")
			return false
		end

		return true
	end

	if setting == "meta_sniffer" then
		if is_running() then
			local runtime_config_path = get_runtime_config_path()
			local ruby_cmd

			if value == "1" then
				ruby_cmd = string.format([[
					ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e "
					begin
						config_path = '%s'

						config = File.exist?(config_path) ? YAML.load_file(config_path) : {}
						config ||= {}

						if config['sniffer']&.dig('enable') == true &&
						   config['sniffer']&.dig('parse-pure-ip') == true &&
						   config['sniffer']&.dig('sniff')
							exit 0
						end

						config['sniffer'] = {
							'enable' => true,
							'parse-pure-ip' => true,
							'override-destination' => false
						}

						custom_sniffer_path = '/etc/openclash/custom/openclash_custom_sniffer.yaml'
						if File.exist?(custom_sniffer_path)
							begin
								custom_sniffer = YAML.load_file(custom_sniffer_path)
								if custom_sniffer&.dig('sniffer')
									config['sniffer'].merge!(custom_sniffer['sniffer'])
								end
							rescue
							end
						end

						unless config['sniffer']['sniff']
							config['sniffer']['sniff'] = {
								'QUIC' => { 'ports' => [443] },
								'TLS' => { 'ports' => [443, '8443'] },
								'HTTP' => { 'ports' => [80, '8080-8880'], 'override-destination' => false }
							}
						end

						unless config['sniffer']['force-domain']
							config['sniffer']['force-domain'] = ['+.netflix.com', '+.nflxvideo.net', '+.amazonaws.com']
						end

						unless config['sniffer']['skip-domain']
							config['sniffer']['skip-domain'] = ['+.apple.com', 'Mijia Cloud', 'dlg.io.mi.com']
						end

						YAML.dump(config, config_path)

					rescue => e
						exit 1
					end
					" 2>/dev/null
				]], runtime_config_path)
			else
				ruby_cmd = string.format([[
					ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e "
					begin
						config_path = '%s'

						if File.exist?(config_path)
							config = YAML.load_file(config_path)
							if config&.dig('sniffer', 'enable') == false
								exit 0
							end
						else
							config = {}
						end

						config ||= {}
						config['sniffer'] = { 'enable' => false }

						YAML.dump(config, config_path)

					rescue => e
						exit 1
					end
					" 2>/dev/null
				]], runtime_config_path)
			end

			if not update_runtime_config(ruby_cmd) then
				return
			end
		end
		uci:set("openclash", "config", "enable_meta_sniffer", tonumber(value))
		uci:set("openclash", "config", "enable_meta_sniffer_pure_ip", tonumber(value))
		uci:set("openclash", "@overwrite[0]", "enable_meta_sniffer", tonumber(value))
		uci:set("openclash", "@overwrite[0]", "enable_meta_sniffer_pure_ip", tonumber(value))
		uci:commit("openclash")
	elseif setting == "respect_rules" then
		if is_running() then
			local runtime_config_path = get_runtime_config_path()
			local target_value = (value == "1") and "true" or "false"

			local ruby_cmd = string.format([[
				ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e "
				begin
					config_path = '%s'
					target_value = %s

					if File.exist?(config_path)
						config = YAML.load_file(config_path)
						if config&.dig('dns', 'respect-rules') == target_value
							if target_value == true && (!config&.dig('dns', 'proxy-server-nameserver') || config['dns']['proxy-server-nameserver'].empty?)
							else
								exit 0
							end
						end
					else
						config = {}
					end

					config ||= {}
					config['dns'] ||= {}
					config['dns']['respect-rules'] = target_value

					if target_value == true
						if !config['dns']['proxy-server-nameserver'] || config['dns']['proxy-server-nameserver'].empty?
							config['dns']['proxy-server-nameserver'] = ['114.114.114.114', '119.29.29.29', '8.8.8.8', '1.1.1.1']
						end
					end

					YAML.dump(config, config_path)

				rescue => e
					exit 1
				end
				" 2>/dev/null
			]], runtime_config_path, target_value)

			if not update_runtime_config(ruby_cmd) then
				return
			end
		end
		uci:set("openclash", "config", "enable_respect_rules", tonumber(value))
		uci:set("openclash", "@overwrite[0]", "enable_respect_rules", tonumber(value))
		uci:commit("openclash")
	elseif setting == "oversea" then
		oversea_v6_setting = fs.uci_get_config("config", "ipv6_enable") or "0"
		if oversea_v6_setting ~= "0" then
			uci:set("openclash", "config", "china_ip6_route", value)
		end
		uci:set("openclash", "config", "china_ip_route", value)
		uci:commit("openclash")
		if is_running() then
			if oversea_v6_setting ~= "0" then
				uci:set("openclash", "@overwrite[0]", "china_ip6_route", value)
			end
			uci:set("openclash", "@overwrite[0]", "china_ip_route", value)
			uci:commit("openclash")
			SYS.exec("/etc/init.d/openclash restart >/dev/null 2>&1")
		end
	elseif setting == "stream_unlock" then
		uci:set("openclash", "config", "stream_auto_select", value)
		if not fs.uci_get_config("config", "stream_auto_select_interval") then
			uci:set("openclash", "config", "stream_auto_select_interval", "10")
		end
		if not fs.uci_get_config("config", "stream_auto_select_logic") then
			uci:set("openclash", "config", "stream_auto_select_logic", "Urltest")
		end
		if not fs.uci_get_config("config", "stream_auto_select_expand_group") then
			uci:set("openclash", "config", "stream_auto_select_expand_group", "0")
		end

		uci:set("openclash", "config", "stream_auto_select_netflix", "1")
		if not fs.uci_get_config("config", "stream_auto_select_group_key_netflix") then
			uci:set("openclash", "config", "stream_auto_select_group_key_netflix", "Netflix|奈飞")
		end

		uci:set("openclash", "config", "stream_auto_select_disney", "1")
		if not fs.uci_get_config("config", "stream_auto_select_group_key_disney") then
			uci:set("openclash", "config", "stream_auto_select_group_key_disney", "Disney|迪士尼")
		end

		uci:set("openclash", "config", "stream_auto_select_hbo_max", "1")
		if not fs.uci_get_config("config", "stream_auto_select_group_key_hbo_max") then
			uci:set("openclash", "config", "stream_auto_select_group_key_hbo_max", "HBO|HBO Max")
		end
		uci:commit("openclash")
	else
		HTTP.status(500, "Invalid setting")
		return
	end

	HTTP.prepare_content("application/json")
	HTTP.write_json({
		status = "success",
		setting = setting,
		value = value
	})
end

function action_generate_pac()
	local result = {
		pac_url = "",
		error = ""
	}

	local auth_user = ""
	local auth_pass = ""

	uci:foreach("openclash", "authentication", function(section)
		if section.enabled == "1" and section.username and section.username ~= ""
			and section.password and section.password ~= "" then
			auth_user = section.username
			auth_pass = section.password
			return false
		end
	end)

	local proxy_ip = daip()
	local mixed_port = fs.uci_get_config("config", "mixed_port") or "7893"

	if not proxy_ip then
		result.error = luci.i18n.translate("Unable to get proxy IP")
		HTTP.prepare_content("application/json")
		HTTP.write_json(result)
		return
	end

	local function generate_random_string()
		local random_cmd = "tr -cd 'a-zA-Z0-9' </dev/urandom 2>/dev/null| head -c16 || date +%N| md5sum |head -c16"
		local random_string = SYS.exec(random_cmd):gsub("\n", "")
		return random_string
	end

	local function count_pac_lines(content)
		if not content or content == "" then
			return 0
		end
		local lines = 0
		for _ in content:gmatch("[^\n]*\n?") do
			lines = lines + 1
		end
		if not content:match("\n$") then
			lines = lines - 1
		end
		return lines
	end

	local new_proxy_string = string.format("PROXY %s:%s; DIRECT", proxy_ip, mixed_port)
	local new_pac_content = generate_pac_content(proxy_ip, mixed_port, auth_user, auth_pass)
	local new_pac_lines = count_pac_lines(new_pac_content)

	local pac_dir = "/www/luci-static/resources/openclash/pac/"
	local pac_filename = nil
	local pac_file_path = nil
	local random_suffix = nil
	local need_update = true

	SYS.call("mkdir -p " .. pac_dir)

	local find_cmd = "find " .. pac_dir .. " -name 'pac_*' -type f 2>/dev/null"
	local existing_files = SYS.exec(find_cmd)
	if existing_files and existing_files ~= "" then
		for file_path in existing_files:gmatch("[^\n]+") do
			if fs.access(file_path) then
				local file_content = fs.readfile(file_path)
				if file_content then
					local existing_proxy = string.match(file_content, 'return%s+"(PROXY%s+[^"]*)"')
					if not existing_proxy then
						existing_proxy = string.match(file_content, 'return%s*"(PROXY%s+[^"]*)"')
					end

					if existing_proxy and existing_proxy == new_proxy_string then
						local existing_lines = count_pac_lines(file_content)
						if existing_lines == new_pac_lines then
							pac_filename = file_path:match("([^/]+)$")
							pac_file_path = file_path
							random_suffix = pac_filename:match("^pac_(.+)$")
							need_update = false
							break
						else
							local file = io.open(file_path, "w")
							if file then
								file:write(new_pac_content)
								file:close()
								SYS.call("chmod 644 " .. file_path)

								pac_filename = file_path:match("([^/]+)$")
								pac_file_path = file_path
								random_suffix = pac_filename:match("^pac_(.+)$")
								need_update = false
								break
							end
						end
					elseif existing_proxy and string.find(existing_proxy, "^PROXY%s+[%d%.]+:[%d]+") then
						local updated_content = string.gsub(file_content,
							'return%s*"PROXY%s+[^"]*"',
							'return "' .. new_proxy_string .. '"')

						if updated_content ~= file_content then
							local updated_lines = count_pac_lines(updated_content)
							local final_content

							if updated_lines == new_pac_lines then
								final_content = updated_content
							else
								final_content = new_pac_content
							end

							local file = io.open(file_path, "w")
							if file then
								file:write(final_content)
								file:close()
								SYS.call("chmod 644 " .. file_path)

								pac_filename = file_path:match("([^/]+)$")
								pac_file_path = file_path
								random_suffix = pac_filename:match("^pac_(.+)$")
								need_update = false
								break
							end
						end
					end
				end
			end
		end
	end

	if need_update then
		SYS.call("rm -f " .. pac_dir .. "pac_* 2>/dev/null")

		random_suffix = generate_random_string()
		pac_filename = "pac_" .. random_suffix
		pac_file_path = pac_dir .. pac_filename

		local file = io.open(pac_file_path, "w")
		if file then
			file:write(new_pac_content)
			file:close()

			SYS.call("chmod 644 " .. pac_file_path)
		else
			result.error = luci.i18n.translate("Failed to write PAC file")
			HTTP.prepare_content("application/json")
			HTTP.write_json(result)
			return
		end
	else
		SYS.call(string.format("find %s -name 'pac_*' -type f ! -name '%s' -delete 2>/dev/null", pac_dir, pac_filename))
	end

	local pac_url = generate_pac_url_with_client_info(pac_filename, random_suffix)
	result.pac_url = pac_url

	if not auth_exists then
		result.error = luci.i18n.translate("No authentication configured, please be aware of the risk of information leakage!")
	end

	HTTP.prepare_content("application/json")
	HTTP.write_json(result)
end

function generate_pac_url_with_client_info(pac_filename, random_suffix)
	local client_protocol = HTTP.formvalue("client_protocol")
	local client_hostname = HTTP.formvalue("client_hostname")
	local client_host = HTTP.formvalue("client_host")
	local client_port = HTTP.formvalue("client_port")

	local request_scheme = "http"
	local host = "localhost"

	if client_protocol and (client_protocol == "http" or client_protocol == "https") then
		request_scheme = client_protocol
	else
		if HTTP.getenv("HTTPS") == "on" or
		   HTTP.getenv("HTTP_X_FORWARDED_PROTO") == "https" or
		   HTTP.getenv("REQUEST_SCHEME") == "https" then
			request_scheme = "https"
		end
	end

	if client_host and client_host ~= "" then
		host = client_host
	elseif client_hostname and client_hostname ~= "" then
		host = client_hostname
		if client_port and client_port ~= "" then
			if (request_scheme == "http" and client_port ~= "80") or
			   (request_scheme == "https" and client_port ~= "443") then
				host = host .. ":" .. client_port
			end
		end
	else
		local server_name = HTTP.getenv("SERVER_NAME")
		local http_host = HTTP.getenv("HTTP_HOST")
		local server_port = HTTP.getenv("SERVER_PORT")
		local proxy_ip = daip()

		if http_host and http_host ~= "" then
			host = http_host
		elseif server_name and server_name ~= "" then
			host = server_name
			if server_port and server_port ~= "" then
				if (request_scheme == "http" and server_port ~= "80") or
				   (request_scheme == "https" and server_port ~= "443") then
					host = host .. ":" .. server_port
				end
			end
		elseif proxy_ip and proxy_ip ~= "" then
			host = proxy_ip
			if server_port and server_port ~= "" then
				if (request_scheme == "http" and server_port ~= "80") or
				   (request_scheme == "https" and server_port ~= "443") then
					host = host .. ":" .. server_port
				end
			end
		end
	end

	local random_param = ""
	if random_suffix and #random_suffix >= 8 then
		math.randomseed(os.time())
		for i = 1, 8 do
			local pos = math.random(1, #random_suffix)
			random_param = random_param .. string.sub(random_suffix, pos, pos)
		end
	else
		random_param = random_suffix or tostring(os.time())
	end

	local pac_url = request_scheme .. "://" .. host .. "/luci-static/resources/openclash/pac/" .. pac_filename .. "?v=" .. random_param

	return pac_url
end

function generate_pac_content(proxy_ip, proxy_port, auth_user, auth_pass)
	local proxy_string = string.format("PROXY %s:%s; DIRECT", proxy_ip, proxy_port)

	local ipv4_networks = {}
	local ipv4_file = "/etc/openclash/custom/openclash_custom_localnetwork_ipv4.list"
	if fs.access(ipv4_file) then
		local content = fs.readfile(ipv4_file)
		if content then
			for line in content:gmatch("[^\r\n]+") do
				line = line:match("^%s*(.-)%s*$")
				if line and line ~= "" and not line:match("^//") and not line:match("^#") then
					local network, mask = line:match("([%d%.]+)/(%d+)")
					if network and mask then
						local mask_bits = tonumber(mask)
						if mask_bits and mask_bits >= 0 and mask_bits <= 32 then
							local subnet_masks = {
								[0] = "0.0.0.0", [1] = "128.0.0.0", [2] = "192.0.0.0", [3] = "224.0.0.0",
								[4] = "240.0.0.0", [5] = "248.0.0.0", [6] = "252.0.0.0", [7] = "254.0.0.0",
								[8] = "255.0.0.0", [9] = "255.128.0.0", [10] = "255.192.0.0", [11] = "255.224.0.0",
								[12] = "255.240.0.0", [13] = "255.248.0.0", [14] = "255.252.0.0", [15] = "255.254.0.0",
								[16] = "255.255.0.0", [17] = "255.255.128.0", [18] = "255.255.192.0", [19] = "255.255.224.0",
								[20] = "255.255.240.0", [21] = "255.255.248.0", [22] = "255.255.252.0", [23] = "255.255.254.0",
								[24] = "255.255.255.0", [25] = "255.255.255.128", [26] = "255.255.255.192", [27] = "255.255.255.224",
								[28] = "255.255.255.240", [29] = "255.255.255.248", [30] = "255.255.255.252", [31] = "255.255.255.254",
								[32] = "255.255.255.255"
							}
							local subnet_mask = subnet_masks[mask_bits]
							if subnet_mask then
								table.insert(ipv4_networks, {network = network, mask = subnet_mask})
							end
						end
					else
						local single_ip = line:match("^([%d%.]+)$")
						if single_ip and single_ip:match("^%d+%.%d+%.%d+%.%d+$") then
							table.insert(ipv4_networks, {network = single_ip, mask = "255.255.255.255"})
						end
					end
				end
			end
		end
	end

	local ipv6_networks = {}
	local ipv6_file = "/etc/openclash/custom/openclash_custom_localnetwork_ipv6.list"
	if fs.access(ipv6_file) then
		local content = fs.readfile(ipv6_file)
		if content then
			for line in content:gmatch("[^\r\n]+") do
				line = line:match("^%s*(.-)%s*$")
				if line and line ~= "" and not line:match("^//") and not line:match("^#") then
					local prefix, prefix_len = line:match("([:%da-fA-F]+)/(%d+)")
					if prefix and prefix_len then
						table.insert(ipv6_networks, {prefix = prefix, prefix_len = tonumber(prefix_len)})
					else
						local single_ipv6 = line:match("^([:%da-fA-F]+)$")
						if single_ipv6 and single_ipv6:match("^[:%da-fA-F]+$") then
							table.insert(ipv6_networks, {prefix = single_ipv6, prefix_len = 128})
						end
					end
				end
			end
		end
	end

	local ipv4_checks = {}
	for _, net in ipairs(ipv4_networks) do
		table.insert(ipv4_checks, string.format('isInNet(resolved_ip, "%s", "%s")', net.network, net.mask))
	end
	local ipv4_check_code = ""
	if #ipv4_checks > 0 then
		ipv4_check_code = "if (" .. table.concat(ipv4_checks, " ||\n			") .. ") {\n			return \"DIRECT\";\n		}"
	end

	local ipv6_checks = {}
	for _, net in ipairs(ipv6_networks) do
		if net.prefix_len == 128 then
			table.insert(ipv6_checks, string.format('resolved_ipv6 === "%s"', net.prefix))
		else
			local prefix_hex = net.prefix:gsub(":+$", "")
			table.insert(ipv6_checks, string.format('resolved_ipv6.indexOf("%s") === 0', prefix_hex))
		end
	end
	local ipv6_check_code = ""
	if #ipv6_checks > 0 then
		ipv6_check_code = "if (" .. table.concat(ipv6_checks, " ||\n			") .. ") {\n			return \"DIRECT\";\n		}"
	end

	local pac_script = string.format([[
// OpenClash PAC File
var failureCount = 0;
var lastCheckTime = 0;
var isProxyDown = false;
var checkInterval = 300000; // 5分钟 = 300000毫秒

// Access Check
function checkNetworkConnectivity() {
	var currentTime = Date.now();

	if (currentTime - lastCheckTime < checkInterval) {
		return !isProxyDown;
	}

	lastCheckTime = currentTime;

	try {
		var test1 = dnsResolve("www.gstatic.com");
		var test2 = dnsResolve("captive.apple.com");

		if (test1 || test2) {
			if (isProxyDown) {
				isProxyDown = false;
				failureCount = 0;
			}
			return true;
		} else {
			failureCount++;
			if (failureCount >= 3) {
				isProxyDown = true;
			}
			return false;
		}
	} catch (e) {
		failureCount++;
		if (failureCount >= 3) {
			isProxyDown = true;
		}
		return false;
	}
}

function FindProxyForURL(url, host) {
	if (isPlainHostName(host) ||
		host === "127.0.0.1" ||
		host === "::1" ||
		host === "localhost") {
		return "DIRECT";
	}

	// IPv4
	var resolved_ip = dnsResolve(host);
	if (resolved_ip) {
		%s
	}

	// IPv6
	var resolved_ipv6 = dnsResolveEx(host);
	if (resolved_ipv6) {
		%s
	}

	if (checkNetworkConnectivity()) {
		return "%s";
	} else {
		return "DIRECT";
	}
}

function FindProxyForURLEx(url, host) {
	return FindProxyForURL(url, host);
}
]], ipv4_check_code, ipv6_check_code, proxy_string)

	return pac_script
end

local function kill_process()
	local cmd = string.format("%s |grep -E 'openclash|clash|mihomo' |grep -v grep |awk '{print $1}' |xargs -r kill -9 >/dev/null 2>&1", fs.ps_cmd())
	SYS.call(cmd)
end

function action_oc_action()
	local action = HTTP.formvalue("action")
	local config_file = HTTP.formvalue("config_file")

	if not action then
		HTTP.status(500, "Missing action parameter")
		return
	end

	if config_file and config_file ~= "" then
		local config_path = "/etc/openclash/config/" .. config_file
		if not fs.access(config_path) then
			HTTP.status(500, "Config file not found")
			return
		end

		if uci:get("openclash", "config", "config_path") ~= config_path then
			uci:set("openclash", "config", "config_path", config_path)
		end
	end

	if action == "start" then
		if uci:get("openclash", "config", "enable") ~= "1" then
			uci:set("openclash", "config", "enable", "1")
			uci:commit("openclash")
		end
		if not is_running() then
			kill_process()
			SYS.call("/etc/init.d/openclash start >/dev/null 2>&1")
		else
			SYS.call("/etc/init.d/openclash restart >/dev/null 2>&1")
		end
	elseif action == "stop" then
		if uci:get("openclash", "config", "enable") ~= "0" then
			uci:set("openclash", "config", "enable", "0")
			uci:commit("openclash")
		end
		kill_process()
		SYS.call("/etc/init.d/openclash stop >/dev/null 2>&1")
	elseif action == "restart" then
		if uci:get("openclash", "config", "enable") ~= "1" then
			uci:set("openclash", "config", "enable", "1")
			uci:commit("openclash")
		end
		kill_process()
		SYS.call("/etc/init.d/openclash restart >/dev/null 2>&1")
	else
		HTTP.status(500, "Invalid action parameter")
		return
	end

	HTTP.prepare_content("application/json")
	HTTP.write_json({status = "success", action = action})
end

function action_config_file_list()
	local config_files = {}
	local age_files = {}
	local current_config = ""
	local config_path = fs.uci_get_config("config", "config_path")

	if config_path then
		current_config = config_path
	end

	uci:foreach("openclash", "config_age_secret", function(a)
		if a.name and (a.secret or a.public) then
			table.insert(age_files, {
				name = a.name,
				secret = a.secret or "",
				public = a.public or ""
			})
		else
			uci:delete("openclash", "config_age_secret", a[".name"])
			uci:commit("openclash")
		end
	end)

	local config_dir = "/etc/openclash/config/"
	local fingerprint_parts = {}
	local cache_valid = false
	local client_fp = HTTP.formvalue("fingerprint")

	if fs.access(config_dir) then
		local files = fs.dir(config_dir)
		if files then
			local yaml_files = {}
			for _, f in ipairs(files) do
				if string.match(f, "%.ya?ml$") then
					local stat = fs.stat(config_dir .. f)
					if stat and stat.type == "regular" then
						yaml_files[#yaml_files + 1] = f .. ":" .. (stat.mtime or 0)
					end
				end
			end
			table.sort(yaml_files)
			fingerprint_parts[#fingerprint_parts + 1] = table.concat(yaml_files, "|")
		end
	end
	for _, a in ipairs(age_files) do
		fingerprint_parts[#fingerprint_parts + 1] = "AGE:" .. a.name .. ":" .. (a.secret ~= "" and "1" or "0")
	end
	local fingerprint = table.concat(fingerprint_parts, "||")

	if client_fp and client_fp == fingerprint then
		cache_valid = true
	end

	if fs.access(config_dir) then
		local files = fs.dir(config_dir)
		if files then
			for _, file in ipairs(files) do
				local full_path = config_dir .. file
				local stat = fs.stat(full_path)
				local name_no_ext = file:match("^(.*)%.ya?ml$")
				if stat and stat.type == "regular" and string.match(file, "%.ya?ml$") then
					if name_no_ext and #age_files > 0 and not cache_valid then
						local cfile = io.open(full_path,"r")
						if cfile then
							local content = cfile:read(1024)
							local age_symbol = content:find("BEGIN AGE ENCRYPTED FILE", 1, true)
							for _, age in pairs(age_files) do
								if age.name == name_no_ext and age.secret and age_symbol then
									stat.age = true
									break
								end
							end
							cfile:close()
						end
					end
					table.insert(config_files, {
						name = file,
						path = full_path,
						size = stat.size,
						mtime = stat.mtime,
						age = stat.age or false
					})
				end
			end
		end

		table.sort(config_files, function(a, b)
			return string.lower(a.name) < string.lower(b.name)
		end)
	end

	HTTP.prepare_content("application/json")
	HTTP.write_json({
		config_files = config_files,
		current_config = current_config,
		total_count = #config_files,
		fingerprint = fingerprint
	})
end

function action_upload_config()
	local config_dir = "/etc/openclash/config/"
	local started, fp, filename, target_path, file_size, stream_err = false, nil, nil, nil, 0, nil

	HTTP.setfilehandler(function(meta, chunk, eof)
		if stream_err then
			return
		end

		if not started then
			if not chunk then
				return
			end

			started = true

			local name = (meta and meta.file) or ""
			if name == "" or not is_safe_filename(name) then
				stream_err = "Invalid filename"
				return
			end

			if not string.match(name, "%.ya?ml$") then
				name = name .. ".yaml"
			end

			filename = name
			target_path = config_dir .. name

			SYS.call("mkdir -p " .. config_dir)

			fp = io.open(target_path, "w")
			if not fp then
				stream_err = "Failed to save config file to disk"
				return
			end
		end

		if #chunk > 0 then
			if not fp:write(chunk) then
				stream_err = "Failed to save config file to disk"
				return
			end

			file_size = file_size + #chunk
		end

		if eof then
			fp:close()
			fp = nil
		end
	end)

	HTTP.formvalue("config_file")
	HTTP.prepare_content("application/json")

	if stream_err then
		if target_path then
			fs.unlink(target_path)
		end

		HTTP.write_json({
			status = "error",
			message = stream_err
		})
		return
	end

	if not target_path then
		HTTP.write_json({
			status = "error",
			message = "No file uploaded"
		})
		return
	end

	if file_size == 0 then
		fs.unlink(target_path)
		HTTP.write_json({
			status = "error",
			message = "Uploaded file is empty"
		})
		return
	end

	local yaml_valid = false
	local content_start = ""
	local rfp = io.open(target_path, "r")
	if rfp then
		content_start = rfp:read(5000) or ""
		rfp:close()
	end

	if string.find(content_start, "proxy%-providers:") or
	   string.find(content_start, "proxies:") or
	   string.find(content_start, "rules:") or
	   string.find(content_start, "port:") or
	   string.find(content_start, "mode:") then
		yaml_valid = true
	end

	if not yaml_valid then
		HTTP.write_json({
			status = "error",
			message = "Invalid config file format - missing required YAML sections"
		})
		return
	end

	SYS.call(string.format("chmod 644 '%s'", target_path))
	SYS.call(string.format("chown root:root '%s'", target_path))

	HTTP.write_json({
		status = "success",
		message = "Config file uploaded successfully",
		filename = filename,
		file_path = target_path,
		file_size = file_size,
		readable_size = fs.filesize(file_size)
	})
end

function action_restore_backup()
	local backup_dir = "/tmp/"
	local started, fp, target_path, stream_err = false, nil, nil, nil

	HTTP.setfilehandler(function(meta, chunk, eof)
		if stream_err then
			return
		end

		if not started then
			if not chunk then
				return
			end

			started = true

			local name = (meta and meta.file) or ""
			if name == "" or not is_safe_filename(name) then
				stream_err = "Invalid filename"
				return
			end

			target_path = backup_dir .. name

			fp = io.open(target_path, "w")
			if not fp then
				stream_err = "Failed to save backup file to disk"
				return
			end
		end

		if chunk and fp then
			fp:write(chunk)
		end

		if eof and fp then
			fp:close()
			fp = nil
		end
	end)

	HTTP.formvalue("backup_file")
	HTTP.prepare_content("application/json")

	if stream_err then
		if target_path then
			fs.unlink(target_path)
		end

		HTTP.write_json({
			status = "error",
			message = stream_err
		})
		return
	end

	if not target_path then
		HTTP.write_json({
			status = "error",
			message = "No file uploaded"
		})
		return
	end

	local restored = fs.restore_backup(target_path)
	fs.unlink(target_path)

	if restored then
		HTTP.write_json({
			status = "success",
			message = "Backup File Restore Successful!"
		})
	else
		HTTP.write_json({
			status = "error",
			message = "Backup File Restore Failed!"
		})
	end
end

function action_config_file_read()
	local config_file = HTTP.formvalue("config_file")

	if not config_file then
		HTTP.status(400, "Missing config_file parameter")
		return
	end

	local allow = false
	if config_file == "/etc/openclash/custom/openclash_custom_overwrite.sh" then
		allow = true
	elseif config_file:match("^/etc/openclash/overwrite/[^/]+$") and not string.find(config_file, "%.%.") then
		allow = true
	elseif config_file:match("^/etc/openclash/[^/]+%.ya?ml$") then
		allow = true
	elseif config_file:match("^/etc/openclash/config/[^/]+%.ya?ml$") and not string.find(config_file, "%.%.") then
		allow = true
	end

	if not allow then
		HTTP.status(403, "Invalid config file path")
		return
	end

	local stat = fs.stat(config_file)
	if stat and stat.type ~= "regular" then
		HTTP.status(500, "Config file is not a regular file")
		return
	end

	HTTP.header("X-Oc-Size", stat and tostring(stat.size) or "0")
	HTTP.header("X-Oc-Mtime", stat and tostring(stat.mtime) or "0")
	HTTP.prepare_content("text/plain; charset=utf-8")

	if not stat then
		return
	end

	local reader = ltn12_popen("exec cat " .. UTIL.shellquote(config_file))
	if not reader then
		return
	end
	luci.ltn12.pump.all(reader, HTTP.write)
	reader.kill()
end

function action_config_file_save()
	local config_file, fp, file_size, backup_file, stream_err, started, opened = nil, nil, 0, nil, nil, false, false

	HTTP.setfilehandler(function(meta, chunk, eof)
		if stream_err then
			return
		end

		if not started then
			if not chunk then
				return
			end

			started = true

			config_file = HTTP.formvalue("config_file", true)
			if not config_file then
				stream_err = "Missing config_file parameter"
				return
			end

			local is_overwrite = (config_file == "/etc/openclash/custom/openclash_custom_overwrite.sh" or config_file:match("^/etc/openclash/overwrite/[^/]+$"))
			if not is_overwrite then
				if not string.match(config_file, "^/etc/openclash/config/[^/]+%.ya?ml$") or string.find(config_file, "%.%.") then
					stream_err = "Invalid config file path"
					return
				end
			else
				if not (config_file == "/etc/openclash/custom/openclash_custom_overwrite.sh" or (config_file:match("^/etc/openclash/overwrite/[^/]+$") and not string.find(config_file, "%.%."))) then
					stream_err = "Invalid overwrite file path"
					return
				end
			end

			if fs.access(config_file) then
				backup_file = config_file .. ".backup." .. os.time()
				if SYS.call(string.format("cp '%s' '%s'", config_file, backup_file)) ~= 0 then
					backup_file = nil
					stream_err = "Failed to create backup file"
					return
				end
			end
		end

		if #chunk > 0 then
			if not fp then
				fp = io.open(config_file, "w")
				if not fp then
					stream_err = "Failed to write config file"
					return
				end

				opened = true
			end

			if not fp:write(chunk) then
				stream_err = "Failed to write config file"
				return
			end

			file_size = file_size + #chunk
		end

		if eof and fp then
			fp:close()
			fp = nil
		end
	end)

	HTTP.formvalue("config_file")
	HTTP.prepare_content("application/json")

	if not stream_err and not config_file then
		stream_err = "Missing config_file parameter"
	end

	if not stream_err and file_size == 0 then
		stream_err = "Missing content parameter"
	end

	if not stream_err then
		local saved = fs.stat(config_file)
		if not saved or saved.size ~= file_size then
			stream_err = "File write verification failed"
		end
	end

	if stream_err then
		if opened then
			if backup_file then
				SYS.call(string.format("mv '%s' '%s'", backup_file, config_file))
			else
				fs.unlink(config_file)
			end
		end

		HTTP.write_json({
			status = "error",
			message = stream_err
		})
		return
	end

	local is_overwrite = (config_file == "/etc/openclash/custom/openclash_custom_overwrite.sh" or config_file:match("^/etc/openclash/overwrite/[^/]+$"))

	if not is_overwrite then
		SYS.call(string.format("chmod 644 '%s'", config_file))
	end
	SYS.call(string.format("chown root:root '%s'", config_file))

	if backup_file then
		SYS.call(string.format([[
			(
				config_dir="$(dirname '%s')"
				config_basename="$(basename '%s')"
				cd "$config_dir" 2>/dev/null || exit 0
				rm -f "${config_basename}.backup."* 2>/dev/null
			) &
		]], config_file, config_file))
	end

	local stat = fs.stat(config_file)
	local file_info = {}
	if stat then
		file_info = {
			path = config_file,
			size = stat.size,
			mtime = stat.mtime,
			readable_size = fs.filesize(stat.size),
			last_modified = os.date("%Y-%m-%d %H:%M:%S", stat.mtime)
		}
	end

	HTTP.write_json({
		status = "success",
		message = "Config file saved successfully",
		file_info = file_info,
		backup_created = backup_file and true or false
	})
end

function action_add_subscription()
	local name = HTTP.formvalue("name")
	local address = HTTP.formvalue("address")
	local sub_ua = HTTP.formvalue("sub_ua") or "clash-verge/v2.4.5"
	local sub_convert = HTTP.formvalue("sub_convert") or "0"
	local convert_address = HTTP.formvalue("convert_address") or ""
	local template = HTTP.formvalue("template") or ""
	local custom_template_url = HTTP.formvalue("custom_template_url") or ""
	local emoji = HTTP.formvalue("emoji") or "false"
	local udp = HTTP.formvalue("udp") or "false"
	local skip_cert_verify = HTTP.formvalue("skip_cert_verify") or "false"
	local sort = HTTP.formvalue("sort") or "false"
	local node_type = HTTP.formvalue("node_type") or "false"
	local rule_provider = HTTP.formvalue("rule_provider") or "false"
	local tfo = HTTP.formvalue("tfo") or "false"
	local tls13 = HTTP.formvalue("tls13") or "false"
	local custom_params = HTTP.formvalue("custom_params") or ""
	local keyword_option = HTTP.formvalue("keyword_option") or "0"
	local keyword = HTTP.formvalue("keyword") or ""
	local ex_keyword = HTTP.formvalue("ex_keyword") or ""
	local de_ex_keyword = HTTP.formvalue("de_ex_keyword") or ""
	local sub_headers = HTTP.formvalue("sub_headers") or ""
	HTTP.prepare_content("application/json")

	if not name then
		HTTP.write_json({
			status = "error",
			message = "Missing name parameter"
		})
		return
	end

	if not is_safe_filename(name) then
		HTTP.write_json({
			status = "error",
			message = "Invalid filename"
		})
		return
	end

	local is_valid_url = false

	if address and address ~= "" and sub_convert == "1" then
		local prefixed_pattern = "^[^,%s]+,%a[%w+.-]*://.+"
		local encoded_prefixed_pattern = "^[^%%%s]+%%2[Cc]%a[%%%w+.-]*%%3[Aa]%%2[Ff]%%2[Ff].+"

		if string.find(address, "\n") or string.find(address, "|") then
			local links = {}
			if string.find(address, "\n") then
				for line in address:gmatch("[^\n]+") do
					table.insert(links, line:match("^%s*(.-)%s*$"))
				end
			else
				for link in address:gmatch("[^|]+") do
					table.insert(links, link:match("^%s*(.-)%s*$"))
				end
			end

			for _, link in ipairs(links) do
				if link and link ~= "" then
					if string.find(link, "^https?://")
						or string.find(link, "^[a-zA-Z]+://")
						or string.find(link, prefixed_pattern)
						or string.find(link, encoded_prefixed_pattern) then
						is_valid_url = true
						break
					end
				end
			end
		else
			if string.find(address, "^https?://")
				or string.find(address, "^[a-zA-Z]+://")
				or string.find(address, prefixed_pattern)
				or string.find(address, encoded_prefixed_pattern) then
				is_valid_url = true
			end
		end
	elseif address and address ~= "" then
		if string.find(address, "^https?://") and not string.find(address, "\n") and not string.find(address, "|") then
			is_valid_url = true
		end
	else
		is_valid_url = true
	end

	if not is_valid_url then
		local error_msg
		if sub_convert == "1" then
			error_msg = "Invalid subscription URL format. Support: HTTP/HTTPS subscription URLs, or protocol links, can be separated by newlines or |"
		else
			error_msg = "Invalid subscription URL format. Only single HTTP/HTTPS subscription URL is supported when subscription conversion is disabled"
		end

		HTTP.write_json({
			status = "error",
			message = error_msg
		})
		return
	end

	local existing_section_id = nil
	uci:foreach("openclash", "config_subscribe", function(s)
		if s.name == name then
			existing_section_id = s['.name']
			return false
		end
	end)

	local normalized_address = address
	if sub_convert == "1" and (string.find(address, "\n") or string.find(address, "|")) then
		local links = {}
		if string.find(address, "\n") then
			for line in address:gmatch("[^\n]+") do
				local link = line:match("^%s*(.-)%s*$")
				if link and link ~= "" then
					table.insert(links, link)
				end
			end
		else
			for link in address:gmatch("[^|]+") do
				local clean_link = link:match("^%s*(.-)%s*$")
				if clean_link and clean_link ~= "" then
					table.insert(links, clean_link)
				end
			end
		end
		normalized_address = table.concat(links, "\n")
	else
		normalized_address = address:match("^%s*(.-)%s*$")
	end

	local section_id
	if existing_section_id then
		section_id = existing_section_id
	else
		section_id = uci:add("openclash", "config_subscribe")
	end

	if section_id then
		uci:set("openclash", section_id, "name", name)
		if normalized_address and normalized_address ~= "" then
			uci:set("openclash", section_id, "address", normalized_address)
		else
			uci:delete("openclash", section_id, "address")
		end
		uci:set("openclash", section_id, "sub_ua", sub_ua)

		uci:delete("openclash", section_id, "sub_headers")
		if sub_headers and sub_headers ~= "" then
			local headers = {}
			for line in sub_headers:gmatch("[^\n]+") do
				local h = line:match("^%s*(.-)%s*$")
				if h and h ~= "" then
					table.insert(headers, h)
				end
			end
			if #headers > 0 then
				uci:set_list("openclash", section_id, "sub_headers", headers)
			end
		end

		uci:set("openclash", section_id, "sub_convert", sub_convert)
		if sub_convert == "1" then
			uci:set("openclash", section_id, "convert_address", convert_address)
			uci:set("openclash", section_id, "template", template)
			if template == "0" then
				uci:set("openclash", section_id, "custom_template_url", custom_template_url)
			else
				uci:delete("openclash", section_id, "custom_template_url")
			end
		else
			uci:delete("openclash", section_id, "convert_address")
			uci:delete("openclash", section_id, "template")
			uci:delete("openclash", section_id, "custom_template_url")
		end
		uci:set("openclash", section_id, "emoji", emoji)
		uci:set("openclash", section_id, "udp", udp)
		uci:set("openclash", section_id, "skip_cert_verify", skip_cert_verify)
		uci:set("openclash", section_id, "sort", sort)
		uci:set("openclash", section_id, "node_type", node_type)
		uci:set("openclash", section_id, "rule_provider", rule_provider)
		uci:set("openclash", section_id, "tfo", tfo)
		uci:set("openclash", section_id, "tls13", tls13)

		uci:delete("openclash", section_id, "custom_params")
		if custom_params and custom_params ~= "" and sub_convert == "1" then
			local params = {}
			for line in custom_params:gmatch("[^\n]+") do
				local param = line:match("^%s*(.-)%s*$")
				if param and param ~= "" then
					table.insert(params, param)
				end
			end
			if #params > 0 then
				uci:set_list("openclash", section_id, "custom_params", params)
			end
		end

		uci:set("openclash", section_id, "keyword_option", keyword_option)

		uci:delete("openclash", section_id, "keyword")
		if keyword and keyword ~= "" then
			local keywords = {}
			for line in keyword:gmatch("[^\n]+") do
				local kw = line:match("^%s*(.-)%s*$")
				if kw and kw ~= "" then
					table.insert(keywords, kw)
				end
			end
			if #keywords > 0 then
				uci:set_list("openclash", section_id, "keyword", keywords)
			end
		end

		uci:delete("openclash", section_id, "ex_keyword")
		if ex_keyword and ex_keyword ~= "" then
			local ex_keywords = {}
			for line in ex_keyword:gmatch("[^\n]+") do
				local ex_kw = line:match("^%s*(.-)%s*$")
				if ex_kw and ex_kw ~= "" then
					table.insert(ex_keywords, ex_kw)
				end
			end
			if #ex_keywords > 0 then
				uci:set_list("openclash", section_id, "ex_keyword", ex_keywords)
			end
		end

		uci:set("openclash", section_id, "de_ex_keyword", de_ex_keyword)

		uci:commit("openclash")

		local action_msg = existing_section_id and "Subscription updated successfully" or "Subscription added successfully"
		HTTP.write_json({
			status = "success",
			message = action_msg,
			name = name,
			address = normalized_address,
			sub_ua = sub_ua,
			sub_convert = sub_convert,
			multiple_links = sub_convert == "1" and (string.find(normalized_address, "\n") and true or false)
		})
	else
		HTTP.write_json({
			status = "error",
			message = "Failed to add/update subscription configuration"
		})
	end
end

function action_config_stats()
	local filename = HTTP.formvalue("filename")
	HTTP.prepare_content("application/json")

	if not filename or filename == "" then
		HTTP.write_json({ status = "error", message = "Missing filename" })
		return
	end

	local base = filename:match("([^/]+)$")
	if not base or not is_safe_filename(base) then
		HTTP.write_json({ status = "error", message = "Invalid filename" })
		return
	end

	local path = "/etc/openclash/config/" .. base
	if not fs.access(path) and not base:match("%.ya?ml$") then
		path = path .. ".yaml"
	end
	if not fs.access(path) then
		HTTP.write_json({ status = "error", message = "Config file not found" })
		return
	end

	-- a running config is answered by the core; static=1 parses the stored file instead (core unreachable)
	local active_path = fs.uci_get_config("config", "config_path")
	if active_path == path and HTTP.formvalue("static") ~= "1" then
		local st = fs.stat(path)
		HTTP.write_json({
			status = "success",
			active = true,
			size = (st and st.size) or 0,
			mtime = (st and st.mtime) and os.date("%Y-%m-%d %H:%M:%S", st.mtime) or ""
		})
		return
	end

	local stats = SYS.exec(string.format("/usr/share/openclash/yml_stats_get.sh %s 2>/dev/null", UTIL.shellquote(path)))
	stats = stats:gsub("%s+$", "")
	if stats == "" or not stats:find("{", 1, true) then
		HTTP.write_json({ status = "error", message = "Stats unavailable" })
		return
	end
	local decoded = json.parse(stats)
	if decoded and type(decoded) == "table" then
		local st = fs.stat(path)
		decoded.size = (st and st.size) or 0
		HTTP.write_json(decoded)
	else
		HTTP.write(stats)
	end
end

function action_runtime_stats()
	HTTP.prepare_content("application/json")

	local service_up = service_running()
	local offline = { status = "success", online = false }
	if service_up ~= nil then offline.service_running = service_up end

	if not is_running() then
		HTTP.write_json(offline)
		return
	end

	local version_data = nil
	local version_raw = core_api_get("/version")
	if version_raw and version_raw:find("version") then
		version_data = json.parse(version_raw)
	end
	if not version_data then
		HTTP.write_json(offline)
		return
	end

	local result = {
		status = "success",
		online = true,
		version = version_data.version or "",
		nodes = { total = 0, types = {} },
		rules = { total = 0, types = {} },
		providers = { total = 0, items = {} }
	}
	if service_up ~= nil then result.service_running = service_up end

	local proxies_raw = core_api_get("/proxies")
	local proxies = proxies_raw and json.parse(proxies_raw) or nil
	if proxies and type(proxies.proxies) == "table" then
		-- the core reports group types in CamelCase without dashes (Selector, URLTest, ...)
		local group_types = { select = true, urltest = true, fallback = true, loadbalance = true, smart = true, relay = true, selector = true }
		local builtin_types = { direct = true, reject = true, rejectdrop = true, pass = true, passrule = true, compatible = true }
		local group_names = {}
		for name, p in pairs(proxies.proxies) do
			local t = string.lower(p.type or "")
			if group_types[(t:gsub("%-", ""))] and name ~= "GLOBAL" then
				group_names[name] = true
			end
		end
		for name, p in pairs(proxies.proxies) do
			-- provider nodes are not listed in /proxies, the rest are groups and builtin entries
			local t = p.type or "unknown"
			local tk = string.lower(t):gsub("%-", "")
			if name ~= "GLOBAL" and not group_names[name] and not builtin_types[tk] then
				result.nodes.total = result.nodes.total + 1
				result.nodes.types[t] = (result.nodes.types[t] or 0) + 1
			end
		end
		local ref_counts = {}
		for name, p in pairs(proxies.proxies) do
			if group_names[name] and type(p.all) == "table" then
				local seen = {}
				for _, m in ipairs(p.all) do
					if type(m) == "string" and m ~= name and group_names[m] and not seen[m] then
						seen[m] = true
						ref_counts[m] = (ref_counts[m] or 0) + 1
					end
				end
			end
		end
		local groups_out = {}
		for name, p in pairs(proxies.proxies) do
			if group_names[name] and type(p.all) == "table" then
				local members, seen = {}, {}
				local node_count = 0
				for _, m in ipairs(p.all) do
					if type(m) == "string" and m ~= name and not seen[m] then
						seen[m] = true
						if m == "DIRECT" then
							members[#members + 1] = { k = "direct", v = "DIRECT" }
						elseif m:match("^REJECT") or m == "PASS" then
							members[#members + 1] = { k = "reject", v = m }
						elseif group_names[m] then
							members[#members + 1] = { k = "ref", v = m }
						else
							node_count = node_count + 1
						end
					end
				end
				if node_count > 0 then
					members[#members + 1] = { k = "nodes", v = node_count }
				end
				groups_out[#groups_out + 1] = { n = name, t = p.type, refs = ref_counts[name] or 0, members = members }
			end
		end
		table.sort(groups_out, function(a, b)
			if a.refs ~= b.refs then return a.refs > b.refs end
			return a.n < b.n
		end)
		result.structure = result.structure or {}
		result.structure.groups = groups_out
	end

	local rules_raw = core_api_get("/rules")
	local rules = rules_raw and json.parse(rules_raw) or nil
	if rules and type(rules.rules) == "table" then
		result.rules.total = #rules.rules
		-- map the core's CamelCase types (DomainSuffix / RuleSet) back to the config
		-- spelling so both stats sources feed the same charts
		local rule_type_names = {
			domain = "DOMAIN", domainsuffix = "DOMAIN-SUFFIX", domainkeyword = "DOMAIN-KEYWORD",
			domainregex = "DOMAIN-REGEX", domainwildcard = "DOMAIN-WILDCARD", geosite = "GEOSITE",
			geoip = "GEOIP", srcgeoip = "SRC-GEOIP", ipasn = "IP-ASN", srcipasn = "SRC-IP-ASN",
			ipcidr = "IP-CIDR", srcipcidr = "SRC-IP-CIDR", ipsuffix = "IP-SUFFIX", srcipsuffix = "SRC-IP-SUFFIX",
			srcport = "SRC-PORT", dstport = "DST-PORT", inport = "IN-PORT", dscp = "DSCP",
			inuser = "IN-USER", inname = "IN-NAME", intype = "IN-TYPE",
			processname = "PROCESS-NAME", processpath = "PROCESS-PATH",
			processnameregex = "PROCESS-NAME-REGEX", processpathregex = "PROCESS-PATH-REGEX",
			processnamewildcard = "PROCESS-NAME-WILDCARD", processpathwildcard = "PROCESS-PATH-WILDCARD",
			rematchname = "REMATCH-NAME", ruleset = "RULE-SET", match = "MATCH", network = "NETWORK",
			uid = "UID", ["and"] = "AND", ["or"] = "OR", ["not"] = "NOT",
		}
		local targets, order = {}, {}
		for _, r in ipairs(rules.rules) do
			local raw_type = type(r) == "table" and type(r.type) == "string" and r.type or ""
			local tkey = raw_type ~= "" and (string.lower(raw_type):gsub("[^%w]", "")) or ""
			local tname = rule_type_names[tkey]
			if tname then
				result.rules.types[tname] = (result.rules.types[tname] or 0) + 1
			elseif raw_type ~= "" then
				result.rules.types[raw_type] = (result.rules.types[raw_type] or 0) + 1
			end
			local target = type(r) == "table" and r.proxy or nil
			if type(target) == "string" and target ~= "" then
				local entry = targets[target]
				if not entry then
					entry = { t = target, c = 0, sets = {}, rules = {} }
					targets[target] = entry
					order[#order + 1] = target
				end
				entry.c = entry.c + 1
				local label = type(r.payload) == "string" and r.payload or ""
				if tkey == "ruleset" then
					if #entry.sets < 48 and label ~= "" then
						entry.sets[#entry.sets + 1] = label
					end
				elseif #entry.rules < 48 and label ~= "" then
					entry.rules[#entry.rules + 1] = label
				end
			end
		end
		local target_list = {}
		for _, name in ipairs(order) do
			target_list[#target_list + 1] = targets[name]
		end
		result.structure = result.structure or {}
		result.structure.rules = { targets = target_list }
	end

	local rprov_raw = core_api_get("/providers/rules")
	local rprov = rprov_raw and json.parse(rprov_raw) or nil
	if rprov and type(rprov.providers) == "table" then
		local prov_count = 0
		for _ in pairs(rprov.providers) do
			prov_count = prov_count + 1
		end
		result.rules.sets = prov_count
	end

	local prov_raw = core_api_get("/providers/proxies")
	local prov = prov_raw and json.parse(prov_raw) or nil
	if prov and type(prov.providers) == "table" then
		for name, info in pairs(prov.providers) do
			-- the smart core exposes every group as a compatible provider, only real ones count
			if info.vehicleType ~= "Compatible" then
				local items = type(info.proxies) == "table" and info.proxies or {}
				local ptypes = {}
				for _, px in ipairs(items) do
					local t = type(px) == "table" and px.type or nil
					if type(t) == "string" and t ~= "" then
						ptypes[t] = (ptypes[t] or 0) + 1
					end
				end
				table.insert(result.providers.items, { name = name, count = #items, types = ptypes })
				result.providers.total = result.providers.total + #items
				result.nodes.total = result.nodes.total + #items
			end
		end
	end

	HTTP.write_json(result)
end

local TPL_CACHE_DIR = "/tmp/openclash_tpl_cache"
local TPL_CACHE_TTL = 1800

local function tpl_cache_path(id)
	local safe = id:gsub("[^%w%.%-]", "_")
	if #safe > 96 then safe = safe:sub(1, 96) end
	return TPL_CACHE_DIR .. "/" .. safe
end

-- The github address mod is tried before the direct URL (same rewriting as yml_rules_change.sh).
local function tpl_source_urls(url)
	local mod = fs.uci_get_config("config", "github_address_mod") or "0"
	if mod == "" or mod == "0" then
		return { url }
	end
	if mod == "https://cdn.jsdelivr.net/" or mod == "https://fastly.jsdelivr.net/" or mod == "https://testingcf.jsdelivr.net/" then
		local owner, repo, file = url:match("^https://raw%.githubusercontent%.com/([^/]+)/([^/]+)/(.+)$")
		if not owner then
			return { url }
		end
		return { mod .. "gh/" .. owner .. "/" .. repo .. "@" .. file, url }
	end
	if url:match("^https://raw%.githubusercontent%.com/") or url:match("^https://gist%.githubusercontent%.com/") or url:match("^https://raw%.github%.com/") then
		return { mod .. url, url }
	end
	return { url }
end

-- Returns ok, fetched; a failed download keeps the expired cache for offline preview.
local function tpl_fetch(url, path, force)
	fs.mkdir(TPL_CACHE_DIR)
	local st = fs.stat(path)
	if st and st.size > 0 and not force and (os.time() - st.mtime) < TPL_CACHE_TTL then
		return true, false
	end
	for _, source in ipairs(tpl_source_urls(url)) do
		SYS.call(string.format("wget -q -T 15 -O %s -U %s %s 2>/dev/null",
			UTIL.shellquote(path), UTIL.shellquote(fs.user_agent), UTIL.shellquote(source)))
		local st2 = fs.stat(path)
		if st2 and st2.size > 0 then
			return true, true
		end
	end
	return false, false
end

local function tpl_add_group(acc, line)
	local parts = {}
	for tok in line:gmatch("[^`]+") do
		parts[#parts + 1] = tok
	end
	local name = parts[1]
	if not name or name == "" then return end
	local members = {}
	for i = 3, #parts do
		local arg = parts[i]
		local k, label
		local ref = arg:match("^%[%](.+)$")
		if arg == ".*" then
			k, label = "all", ".*"
		elseif ref then
			if ref == "DIRECT" then
				k, label = "direct", "DIRECT"
			elseif ref == "REJECT" or ref:match("^REJECT") or ref == "PASS" then
				k, label = "reject", ref
			else
				k, label = "ref", ref
			end
		elseif arg:match("^https?://") then
			k, label = "test", arg
		elseif arg:match("^%d+[%d,]*$") then
			k, label = "param", arg
		elseif arg:match("[%%%*%[%]%(%)|%^%$\\]") then
			k, label = "filter", arg
		else
			k, label = "node", arg
		end
		members[#members + 1] = { k = k, v = label }
	end
	acc.groups[#acc.groups + 1] = { name = name, type = parts[2] or "", members = members }
end

local function tpl_add_ruleset(acc, rest)
	local target, body = rest:match("^([^,]+),(.+)$")
	if not target then return end
	local kind, label
	if body:match("^%[%]") then
		kind, label = "rule", body:sub(3)
	else
		kind = "file"
		label = body:match("^[^,]+") or body
		label = label:match("([^/]+)$") or label
	end
	acc.rulesets[#acc.rulesets + 1] = { target = target, kind = kind, label = label }
end

local function tpl_parse(path, acc, depth, force)
	local file = io.open(path, "r")
	if not file then return end
	local content = file:read("*a")
	file:close()
	for line in content:gmatch("[^\r\n]+") do
		local t = line:gsub("^%s+", ""):gsub("%s+$", "")
		if t ~= "" and not t:match("^[;#]") and not t:match("^%[.*%]$") then
			-- imported lists carry bare lines (NAME`type`members / TARGET,url); the main file prefixes them
			local value, is_group
			if t:match("^custom_proxy_group=") then
				value, is_group = t:sub(20), true
			elseif t:match("^ruleset=") then
				value = t:sub(9)
			elseif not t:match("=") and t:match("`") then
				value, is_group = t, true
			elseif not t:match("=") and t:match("^[^,]+,.+$") then
				value = t
			end
			local iurl = value and value:match("^!!import:(.+)$") or nil
			if iurl then
				if depth < 3 then
					local ipath = tpl_cache_path(iurl)
					if tpl_fetch(iurl, ipath, force) then
						tpl_parse(ipath, acc, depth + 1, force)
					end
				end
			elseif value and is_group then
				tpl_add_group(acc, value)
			elseif value then
				tpl_add_ruleset(acc, value)
			else
				local key, val = t:match("^([^=]+)=(.*)$")
				if key then
					acc.extra[#acc.extra + 1] = { k = key, v = val }
				end
			end
		end
	end
end

function action_template_preview()
	HTTP.prepare_content("application/json")
	local name = HTTP.formvalue("name") or ""
	local custom = HTTP.formvalue("url") or ""
	local force = HTTP.formvalue("force") == "1"

	local url, cache_id, label
	if custom ~= "" then
		if not custom:match("^https?://") then
			HTTP.write_json({ status = "error", message = "Invalid template URL" })
			return
		end
		url = custom
		cache_id = "custom_" .. custom
		label = custom:match("([^/]+)$") or custom
	else
		local file = io.open("/usr/share/openclash/res/sub_ini.list", "r")
		local tpl_file
		if file then
			for line in file:lines() do
				local n, fl, u = line:match("^([^,]*),([^,]*),(.+)$")
				if n == name and u then
					url, tpl_file = u, fl
					break
				end
			end
			file:close()
		end
		if not url then
			HTTP.write_json({ status = "error", message = "Template not found" })
			return
		end
		cache_id = tpl_file or name
		label = name
	end

	local path = tpl_cache_path(cache_id)
	local ok, fetched = tpl_fetch(url, path, force)
	if not ok then
		HTTP.write_json({ status = "error", message = "Failed to fetch template" })
		return
	end

	local acc = { groups = {}, rulesets = {}, extra = {} }
	tpl_parse(path, acc, 0, force)
	if #acc.groups == 0 and #acc.rulesets == 0 then
		-- the newer YAML templates only fill their structure in at generation time
		local is_yaml = url:match("%.ya?ml") ~= nil
		if not is_yaml then
			local f = io.open(path, "r")
			if f then
				local head = f:read(512) or ""
				f:close()
				is_yaml = head:match("^%s*custom%s*:") ~= nil
			end
		end
		if is_yaml then
			HTTP.write_json({ status = "error", message = "YAML template" })
		else
			HTTP.write_json({ status = "error", message = "Unsupported template format" })
		end
		return
	end

	local refs = {}
	local tests, smart = 0, 0
	for _, g in ipairs(acc.groups) do
		if g.type == "url-test" or g.type == "fallback" or g.type == "load-balance" then
			tests = tests + 1
		elseif g.type == "smart" then
			smart = smart + 1
		end
		for _, m in ipairs(g.members) do
			if m.k == "ref" then
				refs[m.v] = (refs[m.v] or 0) + 1
			end
		end
	end
	for _, g in ipairs(acc.groups) do
		g.refs = refs[g.name] or 0
	end

	local st = fs.stat(path)
	HTTP.write_json({
		status = "success",
		source = { name = label, url = url, age = st and (os.time() - st.mtime) or 0, from_cache = not fetched },
		summary = { groups = #acc.groups, sets = #acc.rulesets, tests = tests, smart = smart },
		groups = acc.groups,
		rulesets = acc.rulesets,
		extra = acc.extra
	})
end

function action_upload_overwrite()
	local overwrite_dir = "/etc/openclash/overwrite/"
	local started, fp, filename, target_path, file_size, stream_err = false, nil, nil, nil, 0, nil

	HTTP.setfilehandler(function(meta, chunk, eof)
		if stream_err then
			return
		end

		if not started then
			if not chunk then
				return
			end

			started = true

			local name = (meta and meta.file) or ""
			if name == "" or not is_safe_filename(name) then
				stream_err = "Invalid filename"
				return
			end

			filename = name
			target_path = overwrite_dir .. name

			SYS.call("mkdir -p " .. overwrite_dir)

			fp = io.open(target_path, "w")
			if not fp then
				stream_err = "Failed to save file to disk"
				return
			end
		end

		if #chunk > 0 then
			if not fp:write(chunk) then
				stream_err = "Failed to save file to disk"
				return
			end

			file_size = file_size + #chunk
		end

		if eof then
			fp:close()
			fp = nil
		end
	end)

	HTTP.formvalue("config_file")
	HTTP.prepare_content("application/json")

	if stream_err then
		if target_path then
			fs.unlink(target_path)
		end

		HTTP.write_json({status = "error", message = stream_err})
		return
	end

	if not target_path then
		HTTP.write_json({status = "error", message = "No file uploaded"})
		return
	end

	if file_size == 0 then
		fs.unlink(target_path)
		HTTP.write_json({status = "error", message = "Uploaded file is empty"})
		return
	end

	local config_values = {}
	local raw_config = HTTP.formvalue("config") or ""
	if raw_config ~= "" then
		for line in raw_config:gmatch("[^\n]+") do
			local config_value = line:match("^%s*(.-)%s*$")
			if config_value and config_value ~= "" then
				table.insert(config_values, config_value)
			end
		end
	end
	local enable = HTTP.formvalue("enable")
	local order = HTTP.formvalue("order")
	local param = HTTP.formvalue("param")
	local desc = HTTP.formvalue("desc")

	if target_path then
		local section_name = filename
		local found = false

		uci:foreach("openclash", "config_overwrite", function(s)
			if s.name == section_name then
				found = true
				uci:delete("openclash", s[".name"], "config")
				if #config_values > 0 then
					uci:set_list("openclash", s[".name"], "config", config_values)
				end
				if s.enable == nil or (s.enable ~= nil and enable ~= nil) then
					if enable == nil then
						enable = 0
					end
					uci:set("openclash", s[".name"], "enable", tostring(enable))
				end
				-- an uploaded local file replaces the remote source of this module
				uci:set("openclash", s[".name"], "type", "file")
				uci:set("openclash", s[".name"], "url", "")
				if param ~= nil then
					uci:set("openclash", s[".name"], "param", param)
				end
				if desc ~= nil then
					uci:set("openclash", s[".name"], "desc", desc)
				end
				if order ~= nil then
					uci:set("openclash", s[".name"], "order", tostring(tonumber(order) or 0))
				end
				return false
			end
		end)
		if not found then
			local sid = uci:add("openclash", "config_overwrite")
			uci:set("openclash", sid, "name", section_name)
			uci:set("openclash", sid, "type", "file")
			uci:delete("openclash", sid, "config")
			if #config_values > 0 then
				uci:set_list("openclash", sid, "config", config_values)
			end
			if param ~= nil then
				uci:set("openclash", sid, "param", param)
			end
			if desc ~= nil then
				uci:set("openclash", sid, "desc", desc)
			end
			if enable ~= nil then
				uci:set("openclash", sid, "enable", tostring(enable))
			else
				uci:set("openclash", sid, "enable", 0)
			end
			if order ~= nil then
				uci:set("openclash", sid, "order", tostring(order))
			else
				local max_order = -1
				uci:foreach("openclash", "config_overwrite", function(s)
					local o = tonumber(s.order)
					if o and o > max_order then max_order = o end
				end)
				uci:set("openclash", sid, "order", tostring(max_order + 1))
			end
		end

		uci:commit("openclash")

		HTTP.write_json({
			status = "success",
			message = "Overwrite file uploaded successfully",
			filename = filename,
			file_path = target_path,
			file_size = file_size,
			readable_size = fs.filesize(file_size)
		})
	end
end

-- Runs one curl download while streaming NDJSON progress lines, so the browser bar follows real bytes.
-- Returns the curl exit code, or nil when the wait ran out.
local function stream_curl_download(url, tmp_file, max_filesize, emit_progress)
	local hdr_file = tmp_file .. ".hdr"
	local rc_file = tmp_file .. ".rc"
	SYS.call(string.format("rm -f '%s' '%s' '%s'", tmp_file, hdr_file, rc_file))
	local cmd = string.format(
		"curl -fsSL --connect-timeout 5 -m 60 --retry 2%s -D '%s' -o '%s' %s >/dev/null 2>&1; echo $? > '%s'",
		max_filesize and (" --max-filesize " .. tostring(max_filesize)) or "",
		hdr_file, tmp_file, UTIL.shellquote(url), rc_file
	)
	local pid = nixio.fork()
	if not pid or pid < 0 then
		return nil
	end
	if pid == 0 then
		nixio.exec("/bin/sh", "-c", cmd)
	end

	local total = 0
	local reported = -1
	local code = nil
	local waited = 0
	while waited < 120 do
		local stat = fs.stat(tmp_file)
		local received = (stat and stat.type == "regular" and stat.size) or 0
		if total == 0 then
			local header_text = nixio.fs.readfile(hdr_file)
			for value in (header_text or ""):gmatch("[Cc]ontent%-[Ll]ength:%s*(%d+)") do
				total = tonumber(value) or total
			end
		end
		if received ~= reported then
			if emit_progress then
				write_padded(json.stringify({type = "progress", received = received, total = total}))
			end
			reported = received
		end
		if nixio.fs.access(rc_file) then
			local rc_code = tonumber((nixio.fs.readfile(rc_file) or ""):match("%d+"))
			if rc_code then
				code = rc_code
				break
			end
		end
		nixio.nanosleep(0, 250000000)
		waited = waited + 0.25
	end

	if code == nil then
		pcall(nixio.kill, pid, nixio.const.SIGTERM)
	end
	for _ = 1, 20 do
		local ok_w, wpid = pcall(nixio.waitpid, pid, "nohang")
		if ok_w and wpid then break end
		local ok_k, alive = pcall(nixio.kill, pid, 0)
		if not (ok_k and alive) then break end
		nixio.nanosleep(0, 50000000)
	end
	SYS.call(string.format("rm -f '%s' '%s'", hdr_file, rc_file))
	return code
end

function action_overwrite_subscribe_info()
	local method = HTTP.getenv("REQUEST_METHOD")
	local filename = HTTP.formvalue("filename")
	local old_filename = HTTP.formvalue("old_filename")
	local typ = HTTP.formvalue("type") or "file"
	local section_name = nil
	local old_section_name = nil

	if filename and not is_safe_filename(filename) then
		HTTP.prepare_content("application/json")
		HTTP.write_json({status = "error", message = "Invalid filename"})
		return
	end

	if filename then
		section_name = filename:match("([^/]+)$")
	end
	if old_filename then
		old_section_name = old_filename:match("([^/]+)$")
	end

	if method == "GET" then
		local result = {}
		uci:foreach("openclash", "config_overwrite", function(s)
			if s.name then
				local config_value = ""
				if s.config then
					local config_items = type(s.config) == "table" and s.config or { s.config }
					local config_list = {}
					for _, item in ipairs(config_items) do
						if item and item ~= "" then
							table.insert(config_list, tostring(item))
						end
					end
					if #config_list > 0 then
						config_value = config_list
					end
				end

				result[s.name] = {
					url = s.url or "",
					config = config_value,
					update_days = s.update_days or "",
					update_hour = s.update_hour or "",
					order = tonumber(s.order) or 0,
					type = s.type or "file",
					param = s.param or "",
					desc = s.desc or "",
					official = tonumber(s.official) or 0,
					enable = tonumber(s.enable) or 0
				}
			end
		end)
		HTTP.prepare_content("application/json")
		HTTP.write_json({status="success", data=result})
		return
	elseif method == "POST" then
		if not section_name then
			HTTP.status(500, "Missing filename")
			return
		end
		local url = HTTP.formvalue("url") or ""
		local update_days = HTTP.formvalue("update_days") or ""
		local update_hour = HTTP.formvalue("update_hour") or ""
		local order = HTTP.formvalue("order")
		local param = HTTP.formvalue("param") or ""
		local desc = HTTP.formvalue("desc")
		local config_values = {}
		local raw_config = HTTP.formvalue("config") or ""
		if raw_config ~= "" then
			for line in raw_config:gmatch("[^\n]+") do
				local config_value = line:match("^%s*(.-)%s*$")
				if config_value and config_value ~= "" then
					table.insert(config_values, config_value)
				end
			end
		end
		typ = HTTP.formvalue("type") or typ or "file"
		local enable = HTTP.formvalue("enable")
		local stream_progress = HTTP.formvalue("stream") == "1"

		-- a streamed reply already carries progress lines, its result must travel the same channel
		local function respond_json(payload)
			if stream_progress then
				write_padded(json.stringify(payload))
				return
			end
			HTTP.prepare_content("application/json")
			HTTP.write_json(payload)
		end

		if typ == "http" then
			if not url or url == "" then
				respond_json({
					status = "error",
					message = "Subscribe URL cannot be empty"
				})
				return
			end
			local is_valid_url = false
			if url:match("^https?://") and not url:find("\n") and not url:find("|") then
				is_valid_url = true
			end
			if not is_valid_url then
				respond_json({
					status = "error",
					message = "Invalid subscribe URL format, only single HTTP/HTTPS link is supported"
				})
				return
			end
		end

		-- locate the section to update (rename source or the section with the target name)
		local target_section = nil
		local rename_source = nil
		uci:foreach("openclash", "config_overwrite", function(s)
			if s.name == section_name then
				target_section = s
			end
			if old_section_name and old_section_name ~= "" and old_section_name ~= section_name and s.name == old_section_name then
				rename_source = s
			end
		end)

		local file_path = "/etc/openclash/overwrite/" .. section_name
		-- only refresh the module body when it is really needed (new url / explicit refresh / missing file)
		local need_download = false
		if typ == "http" and url ~= "" then
			local known_url = ""
			if target_section and target_section.url then
				known_url = target_section.url
			elseif rename_source and rename_source.url then
				known_url = rename_source.url
			end
			if HTTP.formvalue("refresh") == "1" or known_url ~= url or not fs.access(file_path) then
				need_download = true
			end
		end

		if need_download then
			local tmp_file = "/tmp/openclash_overwrite_download"
			if stream_progress then
				HTTP.prepare_content("text/plain; charset=utf-8")
			end
			local ret = stream_curl_download(url, tmp_file, nil, stream_progress)
			local stat = fs.stat(tmp_file)
			if ret ~= 0 or not stat or stat.type ~= "regular" or stat.size == 0 then
				SYS.call("rm -f " .. tmp_file)
				respond_json({status="error", message="Download failed"})
				return
			end
			SYS.call(string.format("mkdir -p /etc/openclash/overwrite && mv -f '%s' '%s' && chmod 644 '%s'", tmp_file, file_path, file_path))
			if not fs.access(file_path) then
				respond_json({status="error", message="Failed to save downloaded file"})
				return
			end
		end

		if old_section_name and old_section_name ~= "" and old_section_name ~= section_name then
			local old_file = "/etc/openclash/overwrite/" .. old_section_name
			if fs.access(old_file) then
				if need_download or fs.access(file_path) then
					fs.unlink(old_file)
				else
					fs.rename(old_file, file_path)
				end
			end
		end

		if not fs.access(file_path) then
			fs.writefile(file_path, "")
		end
		local section = rename_source or target_section
		local sid = nil
		if section then
			sid = section[".name"]
			if section_name ~= old_section_name and rename_source and rename_source[".name"] == sid then
				uci:set("openclash", sid, "name", section_name)
			end
		else
			-- never register a module without a config match: it would stay inactive forever
			if #config_values == 0 then
				HTTP.prepare_content("application/json")
				HTTP.write_json({status="error", message="Config file match cannot be empty"})
				return
			end
			sid = uci:add("openclash", "config_overwrite")
			uci:set("openclash", sid, "name", section_name)
		end
		uci:set("openclash", sid, "type", typ)
		uci:set("openclash", sid, "url", url)
		uci:set("openclash", sid, "update_days", update_days)
		uci:set("openclash", sid, "update_hour", update_hour)
		uci:set("openclash", sid, "param", param)
		-- desc stays untouched when the caller does not send one
		if desc ~= nil then
			uci:set("openclash", sid, "desc", desc)
		end
		if #config_values > 0 then
			uci:delete("openclash", sid, "config")
			uci:set_list("openclash", sid, "config", config_values)
		end
		local order_num = tonumber(order)
		if order_num == nil then
			order_num = section and tonumber(section.order) or nil
		end
		if order_num == nil then
			local max_order = -1
			uci:foreach("openclash", "config_overwrite", function(s)
				local o = tonumber(s.order)
				if o and o > max_order then max_order = o end
			end)
			order_num = max_order + 1
		end
		uci:set("openclash", sid, "order", tostring(order_num))
		local enable_num = tonumber(enable)
		if enable_num == nil then
			enable_num = section and tonumber(section.enable) or 0
		end
		uci:set("openclash", sid, "enable", tostring(enable_num == 1 and 1 or 0))
		uci:commit("openclash")

		respond_json({status="success"})
		return
	else
		HTTP.status(500, "Method Not Allowed")
	end
end

-- Reads the head of a remote module file so the add dialog can prefill its fields from the #! markers.
function action_overwrite_module_preview()
	local url = HTTP.formvalue("url") or ""

	if not url:match("^https?://") or url:find("%s") or url:find("|") then
		HTTP.prepare_content("application/json")
		HTTP.write_json({status = "error", message = "Invalid subscribe URL format, only single HTTP/HTTPS link is supported"})
		return
	end

	HTTP.prepare_content("text/plain; charset=utf-8")
	local tmp_file = "/tmp/openclash_overwrite_preview"
	local ret = stream_curl_download(url, tmp_file, 524288, true)
	local stat = fs.stat(tmp_file)
	if ret ~= 0 or not stat or stat.type ~= "regular" or stat.size == 0 then
		SYS.call("rm -f " .. tmp_file)
		write_padded(json.stringify({type = "result", status = "error", message = "Download failed"}))
		return
	end

	-- only the head is needed: the markers live at the top of the file
	local f = io.open(tmp_file, "r")
	local head = f and f:read(131072) or nil
	if f then
		f:close()
	end
	SYS.call("rm -f " .. tmp_file)

	if not head then
		write_padded(json.stringify({type = "result", status = "error", message = "Failed to read the downloaded file"}))
		return
	end

	-- raw control bytes would break the JSON response; whitespace stays intact
	head = head:gsub("[%z\1-\8\11\12\14-\31\127]", "")
	write_padded(json.stringify({type = "result", status = "success", content = head}))
end

function action_overwrite_file_list()
	local overwrite_files = {}
	local custom_file = "/etc/openclash/custom/openclash_custom_overwrite.sh"

	if fs.access(custom_file) then
		local stat = fs.stat(custom_file)
		if stat and stat.type == "regular" then
			table.insert(overwrite_files, {
				name = "openclash_custom_overwrite.sh",
				path = custom_file,
				size = stat.size,
				mtime = stat.mtime
			})
		end
	end

	local overwrite_dir = "/etc/openclash/overwrite/"
	if fs.access(overwrite_dir) then
		local files = fs.dir(overwrite_dir)
		if files then
			for _, file in ipairs(files) do
				local full_path = overwrite_dir .. file
				local stat = fs.stat(full_path)
				if stat and stat.type == "regular" and file:sub(1, 1) ~= "." and not file:match("%.backup%.") and not file:match("%.tmp$") then
					table.insert(overwrite_files, {
						name = file,
						path = full_path,
						size = stat.size,
						mtime = stat.mtime
					})
				end
			end
		end
	end

	table.sort(overwrite_files, function(a, b)
		return (a.mtime or 0) > (b.mtime or 0)
	end)

	HTTP.prepare_content("application/json")
	HTTP.write_json({
		overwrite_files = overwrite_files,
		total_count = #overwrite_files
	})
end

function delete_overwrite_file()
	local filename = HTTP.formvalue("filename")
	if not filename or filename == "" then
		HTTP.prepare_content("application/json")
		HTTP.write_json({status="error", message="Missing filename"})
		return
	end
	if not is_safe_filename(filename) then
		HTTP.prepare_content("application/json")
		HTTP.write_json({status="error", message="Invalid filename"})
		return
	end
	local overwrite_dir = "/etc/openclash/overwrite/"
	local file_path = overwrite_dir .. filename

	if fs.access(file_path) then
		fs.unlink(file_path)
	end

	uci:foreach("openclash", "config_overwrite", function(s)
		if s.name == filename then
			uci:delete("openclash", s[".name"])
			return false
		end
	end)
	uci:commit("openclash")

	local order_list = {}
	uci:foreach("openclash", "config_overwrite", function(s)
		table.insert(order_list, { section = s[".name"], order = tonumber(s.order) or 0 })
	end)
	table.sort(order_list, function(a, b) return a.order < b.order end)
	for idx, item in ipairs(order_list) do
		uci:set("openclash", item.section, "order", tostring(idx))
	end
	uci:commit("openclash")

	HTTP.prepare_content("application/json")
	HTTP.write_json({status="success"})
end

function action_get_subscribe_data()
	local filename = HTTP.formvalue("filename")
	if not filename then
		HTTP.status(500, "Bad Request")
		return
	end

	local data = {}
	-- the config list passes the file name; subscription entries are keyed by the bare config name
	local base = filename:gsub("%.ya?ml$", "")
	uci:foreach("openclash", "config_subscribe", function(s)
		if s.name == filename or s.name == base then
			data = s
			-- UCI list fields: convert to newline-separated strings for frontend
			local sid = s['.name']
			for _, field in ipairs({"sub_headers", "keyword", "ex_keyword", "custom_params"}) do
				local raw = uci:get_list("openclash", sid, field)
				if raw then
					data[field] = table.concat(raw, "\n")
				end
			end
			return false
		end
	end)

	uci:foreach("openclash", "config_age_secret", function(a)
		if (a.name == filename or a.name == base) and (not a.hidden or a.hidden ~= "true") then
			if a.secret then data.config_age_secret = a.secret end
			if a.public then data.config_age_public = a.public end
			if a.algo then data.config_age_algo = a.algo end
			return false
		end
		if (a.name == filename or a.name == base) and a.hidden and a.hidden == "true" then
			data.config_age_hidden = true
			return false
		end
	end)

	HTTP.prepare_content("application/json")
	HTTP.write_json(data)
end

function action_get_subscribe_info_data()
	local filename = HTTP.formvalue("filename")
	if not filename then
		HTTP.status(500, "Bad Request")
		return
	end
	HTTP.prepare_content("application/json")
	HTTP.write_json(get_sub_url(filename))
end

function action_subconverter_version()
	local raw_url = HTTP.formvalue("url") or ""
	local version_url, err = parse_subconverter_version_url(raw_url)
	HTTP.prepare_content("application/json")

	if not version_url then
		HTTP.write_json({status = "error", message = err or "invalid"})
		return
	end

	local cmd = table.concat({
		"curl -fsS --connect-timeout 3 -m 6 --retry 0",
		"-H " .. UTIL.shellquote("Accept: text/plain, */*"),
		"-H " .. UTIL.shellquote("Origin: https://openclash.local"),
		"-H " .. UTIL.shellquote("Sec-Fetch-Mode: cors"),
		"-H " .. UTIL.shellquote("Sec-Fetch-Dest: empty"),
		"-H " .. UTIL.shellquote("User-Agent: OpenClash Subconverter Version Check"),
		UTIL.shellquote(version_url),
		"2>/dev/null | head -c 4096"
	}, " ")
	local version = sanitize_subconverter_version_text(SYS.exec(cmd))

	if version == "" then
		HTTP.write_json({status = "unrecognized"})
	else
		HTTP.write_json({status = "success", version = version})
	end
end

function action_generate_age_key()
	local algo = HTTP.formvalue("algo") or "keygen"
	local cmd = string.format("%s age %s", meta_core_path, (algo == "pq" and "keygen-pq" or "keygen"))
	local out = SYS.exec(cmd .. " 2>/dev/null")
	local secret = out:match("(AGE%-SECRET%-KEY%-%S+)")
	local public = out:match("# public key: ([^\n\r]+)")
	HTTP.prepare_content("application/json")
	if not secret then
		HTTP.write_json({status = "error", message = "Failed to generate age key", output = out})
		return
	end
	HTTP.write_json({status = "success", secret = secret, public = public})
end

function action_cal_age_public_key()
	local secret = HTTP.formvalue("secret") or ""
	if secret == "" then
		HTTP.prepare_content("application/json")
		HTTP.write_json({status = "error", message = "Secret key is required"})
		return
	end
	local cmd = string.format("%s age convert %s", meta_core_path, secret)
	local out = SYS.exec(cmd .. " 2>/dev/null")
	HTTP.prepare_content("application/json")
	if out and out:match("^age") then
		HTTP.write_json({status = "success", public = out})
	else
		HTTP.write_json({status = "error", message = "Failed to calculate public key, invalid secret key", output = out})
	end
end

function action_add_age_config()
	local name = HTTP.formvalue("name")
	local age_secret = HTTP.formvalue("age_secret") or ""
	local age_public = HTTP.formvalue("age_public") or ""
	local age_algo = HTTP.formvalue("age_algo") or ""
	local age_section_id, age_section_hidden, age_section_secret

	HTTP.prepare_content("application/json")

	if not name or name == "" then
		HTTP.write_json({status = "error", message = "Missing name parameter"})
		return
	end

	uci:foreach("openclash", "config_age_secret", function(s)
		if s.name == name then
			age_section_id = s['.name']
			age_section_hidden = s.hidden and s.hidden == "true"
			age_section_secret = s.secret
			return false
		end
	end)

	if age_section_hidden then
		HTTP.write_json({status = "error", message = "Cannot modify hidden age configuration"})
		return
	end

	if not age_section_id and age_secret ~= "" then
		age_section_id = uci:add("openclash", "config_age_secret")
		if age_section_id then
			uci:set("openclash", age_section_id, "name", name)
		end
	end

	if age_section_id then
		if (age_secret == "") then
			-- Before removing the age keys, decrypt the config file if it is
			-- age-encrypted so it stays readable after the keys are gone.
			if age_section_secret and age_section_secret ~= "" then
				local config_paths = {
					"/etc/openclash/config/" .. name .. ".yaml",
					"/etc/openclash/" .. name .. ".yaml",
				}
				for _, config_path in ipairs(config_paths) do
					if fs.access(config_path) then
						local fp = io.open(config_path, "rb")
						if fp then
							local content = fp:read("*a")
							fp:close()
							if content and content:find("BEGIN AGE ENCRYPTED FILE", 1, true) then
								local plain = fs.age_decrypt(age_section_secret, content)
								if plain and plain ~= "" then
									local fo = io.open(config_path, "wb")
									if fo then
										fo:write(plain)
										fo:close()
									end
								else
									HTTP.write_json({status = "error", message = "Failed to decrypt config file, age config cannot be removed"})
									return
								end
							end
						end
					end
				end
			end
			uci:delete("openclash", age_section_id)
		else
			if age_secret and age_secret ~= "" then
				uci:set("openclash", age_section_id, "secret", age_secret)
			else
				uci:delete("openclash", age_section_id, "secret")
			end
			if age_public and age_public ~= "" then
				uci:set("openclash", age_section_id, "public", age_public)
			else
				uci:delete("openclash", age_section_id, "public")
			end
			if age_algo and age_algo ~= "" then
				uci:set("openclash", age_section_id, "algo", age_algo)
			else
				uci:delete("openclash", age_section_id, "algo")
			end
		end
		uci:commit("openclash")
	end

	HTTP.write_json({status = "success"})
end

function oix_login_info_save()
	local ok = true
	local checkin = HTTP.formvalue("checkin")
	local show_info_page = HTTP.formvalue("show_info_page")
	local interval = HTTP.formvalue("interval")
	local multiple = HTTP.formvalue("multiple")

	if checkin ~= nil and checkin ~= "0" and checkin ~= "1" then ok = false end
	if show_info_page ~= nil and show_info_page ~= "0" and show_info_page ~= "1" then ok = false end
	if interval ~= nil then
		local n = tonumber(interval)
		if not n or n % 1 ~= 0 or n < 1 or n > 720 then ok = false end
	end
	if multiple ~= nil then
		local n = tonumber(multiple)
		if not n or n % 1 ~= 0 or n < 1 or n > 100 then ok = false end
	end

	if ok then
		if checkin then uci:set("openclash", "config", "oix_checkin", checkin) end
		if show_info_page then uci:set("openclash", "config", "oix_show_info_page", show_info_page) end
		if interval then uci:set("openclash", "config", "oix_checkin_interval", tostring(tonumber(interval))) end
		if multiple then uci:set("openclash", "config", "oix_checkin_multiple", tostring(tonumber(multiple))) end
		ok = uci:commit("openclash")
	end

	HTTP.prepare_content("application/json")
	HTTP.header("Cache-Control", "no-store")
	HTTP.write_json({status = ok and "success" or "error"})
end

function action_theme_get()
	local result = {
		mode = uci:get("openclash", "config", "theme_mode") or "",
		name = uci:get("openclash", "config", "theme_name") or "",
		custom = uci:get("openclash", "config", "theme_custom") or ""
	}
	HTTP.prepare_content("application/json")
	HTTP.write_json(result)
end

function action_theme_save()
	local mode = HTTP.formvalue("mode") or ""
	local name = HTTP.formvalue("name") or ""
	local custom = HTTP.formvalue("custom")
	if mode ~= "" then
		if mode ~= "light" and mode ~= "dark" and mode ~= "auto" then
			HTTP.status(400, "Invalid mode")
			HTTP.write_json({status = "error", msg = "invalid mode"})
			return
		end
		uci:set("openclash", "config", "theme_mode", mode)
	end
	if name ~= "" then
		local valid = {classic = true, cyan = true, indigo = true, graphite = true, amber = true, imperial = true, rose = true, smoky = true, custom = true}
		if not valid[name] then
			HTTP.status(400, "Invalid theme")
			HTTP.write_json({status = "error", msg = "invalid theme"})
			return
		end
		uci:set("openclash", "config", "theme_name", name)
	end
	if custom ~= nil then
		custom = custom:lower()
		if custom == "" then
			uci:delete("openclash", "config", "theme_custom")
		elseif custom:match("^#%x%x%x%x%x%x$") then
			uci:set("openclash", "config", "theme_custom", custom)
		else
			HTTP.status(400, "Invalid color")
			HTTP.write_json({status = "error", msg = "invalid color"})
			return
		end
	end
	uci:commit("openclash")
	HTTP.prepare_content("application/json")
	HTTP.write_json({status = "success"})
end

local function oix_valid_token(token)
	return type(token) == "string" and #token >= 32 and #token <= 128 and token:match("^[0-9a-f]+$") ~= nil
end

local function oix_quote(value)
	return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function oix_progress(stage, text)
	write_padded('{"stage":"' .. stage .. '","text":"' .. luci.i18n.translate(text) .. '"}')
end

local function oix_api(path, token, payload, timeout, with_ua)
	local cmd = string.format("curl -sL -m %d --retry 2 -H 'Content-Type: application/json'", timeout or 20)
	if with_ua then
		cmd = cmd .. " -H 'User-Agent: OpenClash for oixCloud'"
	end
	if token then
		cmd = cmd .. " -H 'Authorization: Bearer " .. token .. "'"
	end
	if payload then
		cmd = cmd .. " -d " .. oix_quote(payload)
	end
	local out = SYS.exec(cmd .. " -X POST https://oix-api.dler.io/api/v1/" .. path)
	if not out or out == "" then return nil end
	local ok, res = pcall(json.parse, out)
	if ok and type(res) == "table" then return res end
	return nil
end

local function oix_account_token(token)
	if not oix_valid_token(token) then return nil, "invalid token" end
	local info = oix_api("information", token)
	if not info or info.ret ~= 200 or type(info.data) ~= "table" then return nil, "login failed" end
	if type(info.data.token_client) == "string" and info.data.token_client ~= "" and info.data.token_client ~= "openclash" then
		local rebound = oix_api("token/rebind", token)
		if rebound and rebound.ret == 200 and type(rebound.data) == "table"
			and rebound.data.token_client == "openclash" and oix_valid_token(rebound.data.token) then
			return rebound.data.token
		end
		return nil, "Unable to select the OpenClash account"
	end
	return token
end

local function oix_core_api(method, path, timeout)
	local cmd = string.format("curl -s -m %d --noproxy '*' -o - -w '\\n%%{http_code}' -H 'Content-Type: application/json'", timeout or 5)
	local secret = dase()
	if secret and secret ~= "" then
		cmd = cmd .. " -H " .. oix_quote("Authorization: Bearer " .. secret)
	end
	cmd = cmd .. " -X " .. method .. " http://127.0.0.1:" .. cn_port() .. path
	local out = SYS.exec(cmd)
	if not out then return nil end
	local response, status = out:match("^(.*)\n(%d%d%d)%s*$")
	return response, tonumber(status)
end

local function oix_wait_loaded()
	oix_progress("loading", "Loading managed nodes...")
	local ready = false
	for _ = 1, 15 do
		local _, status = oix_core_api("GET", "/version", 2)
		if status == 200 then ready = true; break end
		nixio.nanosleep(1, 0)
	end
	if not ready then return nil, "The oixCloud core did not start" end
	local body, status = oix_core_api("GET", "/providers/proxies/oixCloud", 5)
	if status ~= 200 then return nil, "Unable to load managed nodes" end
	local ok, provider = pcall(json.parse, body or "")
	if not ok or type(provider) ~= "table" or type(provider.proxies) ~= "table" or #provider.proxies == 0 then
		return nil, "No managed nodes were loaded"
	end
	local names = {}
	for _, proxy in ipairs(provider.proxies) do
		if type(proxy) == "table" and type(proxy.name) == "string" then names[proxy.name] = true end
	end
	local groups_body, groups_status = oix_core_api("GET", "/proxies", 5)
	if groups_status == 200 then
		local parsed, groups = pcall(json.parse, groups_body or "")
		if parsed and type(groups) == "table" and type(groups.proxies) == "table" then
			for name, group in pairs(groups.proxies) do
				if name ~= "GLOBAL" and type(group) == "table" and type(group.all) == "table" then
					for _, member in ipairs(group.all) do
						if names[member] then return true end
					end
				end
			end
		end
	end
	return nil, "Managed nodes are not referenced by any proxy group"
end

local function fetch_oix_sub(token)
	if not oix_valid_token(token) then
		return nil, "invalid token"
	end
	oix_progress("fetching_sub", "Fetching subscription...")
	local sub_info = oix_api("managed/clash", token, nil, 30)
	local sub_url = sub_info and sub_info.ret == 200 and sub_info.openclash
	if type(sub_url) ~= "string" or not sub_url:match("^https://[^/%s]+/") or sub_url:find("[%c]") then
		return nil, "Unable to fetch managed configuration"
	end
	oix_progress("downloading_config", "Downloading config...")
	local temporary = SYS.exec("mktemp /etc/openclash/config/.oixCloud.XXXXXX 2>/dev/null")
	temporary = temporary and temporary:match("^(/etc/openclash/config/%.oixCloud%.[%w]+)%s*$")
	if not temporary then
		return nil, "Unable to save subscription; existing configuration was kept"
	end
	local function fail(message, detail)
		fs.unlink(temporary)
		if detail then message = string.format(luci.i18n.translate(message), detail) end
		return nil, message
	end
	local result = SYS.exec(string.format("curl -fsSL --connect-timeout 10 -m 10 --retry 2 --proto '=https' --proto-redir '=https' --user-agent clash -w '%%{http_code}' -o %s -- %s 2>/dev/null; printf ':%%s' \"$?\"", oix_quote(temporary), oix_quote(sub_url)))
	local status, code = (result or ""):match("^(%d%d%d):(%d+)$")
	if status and status ~= "000" and status ~= "200" then
		return fail("Subscription download failed (HTTP %s); existing configuration was kept", status)
	end
	if code == "28" then
		return fail("Subscription download timed out; existing configuration was kept")
	end
	if code ~= "0" or status ~= "200" then
		return fail("Subscription request failed (curl %s); existing configuration was kept", code or "unknown")
	end
	local validation_result = SYS.exec("ruby -ryaml -rYAML -I /usr/share/openclash -E UTF-8 -e 'puts YAML.subscription_status(ARGV[0], ARGV.drop(1))' " .. oix_quote(temporary) .. " oixCloud 'oixCloud - smart' 2>/dev/null; printf ':%s' \"$?\"")
	local validation, validation_code = (validation_result or ""):match("^%s*([%u_]+)%s*:(%d+)$")
	if validation_code ~= "0" then validation = nil end
	if validation == "EMPTY" then
		return fail("Subscription response is empty; existing configuration was kept")
	elseif validation == "INVALID" then
		return fail("Subscription is not a valid Clash configuration; existing configuration was kept")
	elseif validation == "NO_PROXIES" then
		return fail("Subscription has no proxies or proxy providers; existing configuration was kept")
	elseif validation ~= "OK" then
		return fail("Subscription validation could not run; check Ruby dependencies. Existing configuration was kept")
	end
	local core = coremetacv()
	if core == "0" or not string.match(core, "oix") then
		oix_progress("downloading_core", "Installing oixCloud core and restarting...")
		SYS.call("OIX_INSTALL_ONLY=1 /usr/share/openclash/openclash_core.sh Oix >/dev/null 2>&1")
		local installed = coremetacv()
		if installed == "0" or not string.match(installed, "oix") then
			return fail("Unable to update the oixCloud core")
		end
	end
	local age_secret = SYS.exec("(. /usr/share/openclash/uci.sh; uci_get_age_secret_keys oixCloud; uci_get_age_secret_keys 'oixCloud - smart') 2>/dev/null") or ""
	if SYS.call("OIX_TOKEN=" .. oix_quote(token) .. " OIX_CLIENT=openclash /etc/openclash/clash -t -d /etc/openclash -f " .. oix_quote(temporary) .. " -age-secret-key " .. oix_quote(age_secret) .. " >/dev/null 2>&1") ~= 0 then
		return fail("Subscription failed core validation; existing configuration was kept")
	end
	local config_file = "/etc/openclash/config/oixCloud.yaml"
	local legacy_file = "/etc/openclash/config/oixCloud - smart.yaml"
	if not fs.rename(temporary, config_file) then
		return fail("Unable to save subscription; existing configuration was kept")
	end
	fs.chmod(config_file, "rw-r--r--")
	uci:set("openclash", "config", "oix_token", token)
	local current_config = uci:get("openclash", "config", "config_path")
	if not current_config or current_config == "" or current_config == legacy_file then
		uci:set("openclash", "config", "config_path", config_file)
	end
	uci:commit("openclash")
	local managed_sids = {}
	uci:foreach("openclash", "config_subscribe", function(s)
		if s.name == "oixCloud - smart" then managed_sids[s['.name']] = true end
	end)
	fs.config_refs("oixCloud - smart.yaml", "oixCloud.yaml")
	uci:load("openclash")
	local sid, duplicates = nil, {}
	uci:foreach("openclash", "config_subscribe", function(s)
		-- adopt only sections renamed from the legacy name or still pointing at the managed URL
		if s.name == "oixCloud" and (managed_sids[s['.name']] or s.address == nil or s.address == "" or s.address == sub_url) then
			if not sid then sid = s['.name'] else duplicates[#duplicates + 1] = s['.name'] end
		end
	end)
	sid = sid or uci:add("openclash", "config_subscribe")
	uci:set("openclash", sid, "name", "oixCloud")
	uci:set("openclash", sid, "address", sub_url)
	for _, duplicate in ipairs(duplicates) do uci:delete("openclash", duplicate) end
	uci:foreach("openclash", "overwrite", function(s)
		local paths, changed = s.config, false
		if type(paths) == "string" then paths = {paths} end
		if type(paths) == "table" then
			for i, path in ipairs(paths) do
				if path == legacy_file then paths[i] = config_file; changed = true end
			end
			if changed then uci:set("openclash", s['.name'], "config", paths) end
		end
	end)
	uci:commit("openclash")
	fs.unlink(legacy_file)
	oix_progress("restarting", "Restarting...")
	SYS.exec("/etc/init.d/openclash restart >/dev/null 2>&1")
	return oix_wait_loaded()
end

function oix_login()
	HTTP.prepare_content("text/plain; charset=utf-8")
	HTTP.header("Cache-Control", "no-store")
	local token, err
	local input_token = HTTP.formvalue("token")
	local email = HTTP.formvalue("email")
	local passwd = HTTP.formvalue("passwd")
	if input_token and input_token ~= "" then
		write_padded('{"stage":"logging_in","text":"' .. luci.i18n.translate("Logging in...") .. '"}')
		token, err = oix_account_token(input_token)
		if not token then
			write_padded('{"stage":"error","result":' .. json.stringify(luci.i18n.translate(err)) .. '}')
			return
		end
	else
		if not email or email == "" or not passwd or passwd == "" then
			write_padded('{"stage":"error","result":' .. json.stringify(luci.i18n.translate("email or passwd is wrong")) .. '}')
			return
		end
		write_padded('{"stage":"logging_in","text":"' .. luci.i18n.translate("Logging in...") .. '"}')
		local info = oix_api("login", nil, json.stringify({email = email, passwd = passwd, token_expire = "365"}), 30, true)
		if not info or info.ret ~= 200 or type(info.data) ~= "table" or not oix_valid_token(info.data.token) then
			local message = (info and info.msg) or luci.i18n.translate("login failed")
			write_padded('{"stage":"error","result":' .. json.stringify(message) .. '}')
			return
		end
		token = info.data.token
	end
	local ok, ferr = fetch_oix_sub(token)
	if ok then
		write_padded('{"stage":"done","result":200}')
	else
		write_padded('{"stage":"error","result":' .. json.stringify(luci.i18n.translate(ferr or "login failed")) .. '}')
	end
end

function oix_logout()
	local token = fs.uci_get_config("config", "oix_token")
	if oix_valid_token(token) then
		SYS.call(string.format("curl -sL -m 10 --proto '=https' --proto-redir '=https' -H 'User-Agent: OpenClash for oixCloud' -H 'X-oixCloud-Client: openclash' -H 'Content-Type: application/json' -H 'Authorization: Bearer %s' -X POST https://oix-api.dler.io/api/v1/logout >/dev/null 2>&1", token))
	end
	uci:delete("openclash", "config", "oix_token")
	uci:delete("openclash", "config", "oix_email")
	uci:delete("openclash", "config", "oix_passwd")
	uci:delete("openclash", "config", "oix_checkin")
	uci:delete("openclash", "config", "oix_checkin_interval")
	uci:delete("openclash", "config", "oix_checkin_multiple")
	uci:delete("openclash", "config", "oix_params")
	uci:delete("openclash", "config", "oix_default_params")
	uci:delete("openclash", "config", "oix_show_info_page")
	uci:commit("openclash")
	fs.unlink("/tmp/oix_checkin")
	fs.unlink("/tmp/oix_info")
	HTTP.prepare_content("application/json")
	HTTP.write_json({result = 200})
end

function oix_info()
	local info, path, get_info
	local result = "error"
	local token = fs.uci_get_config("config", "oix_token")
	path = "/tmp/oix_info"
	if token and oix_valid_token(token) then
		get_info = string.format("curl -sL -m 15 -H 'Content-Type: application/json' -H 'Authorization: Bearer %s' -X POST https://oix-api.dler.io/api/v1/information -o %s", token, path)
		if not fs.access(path) then
			SYS.exec(get_info)
		else
			if fs.readfile(path) == "" or not fs.readfile(path) then
				SYS.exec(get_info)
			else
				if (os.time() - fs.mtime(path) > 900) then
					SYS.exec(get_info)
				end
			end
		end
		if fs.access(path) then
			SYS.call("chmod 600 " .. path .. " >/dev/null 2>&1")
		end
		info = fs.readfile(path)
		if info then
			info = json.parse(info)
		end
		if info and info.ret == 200 and info.data then
			result = info.data
		elseif info and info.msg then
			fs.writefile(path, json.stringify(info))
		else
			fs.unlink(path)
		end
	end
	HTTP.prepare_content("application/json")
	HTTP.header("Cache-Control", "no-store")
	HTTP.write_json({result = result})
end

function oix_checkin()
	local info, result
	local path = "/tmp/oix_checkin"
	local token = fs.uci_get_config("config", "oix_token")
	local multiple = fs.uci_get_config("config", "oix_checkin_multiple") or 1
	if token then
		info = SYS.exec(string.format("curl -sL -m 20 --proto '=https' --proto-redir '=https' -H 'User-Agent: OpenClash for oixCloud' -H 'X-oixCloud-Client: openclash' -H 'Content-Type: application/json' -H 'Authorization: Bearer %s' -d '{\"multiple\":\"%s\"}' -X POST https://oix-api.dler.io/api/v1/checkin", token, multiple))
		if info then
			info = json.parse(info)
		end
		if info and info.ret == 200 then
			fs.unlink("/tmp/oix_info")
			fs.writefile(path, json.stringify(info))
			SYS.exec(string.format("echo -e %s [Info] oixCloud Checkin Successful, Result:【%s】 >> /tmp/openclash.log", os.date("%Y-%m-%d %H:%M:%S"), info.data.checkin))
			result = info
		else
			if info and info.msg then
				SYS.exec(string.format("echo -e %s [Info] oixCloud Checkin Failed, Result:【%s】 >> /tmp/openclash.log", os.date("%Y-%m-%d %H:%M:%S"), info.msg))
			else
				SYS.exec(string.format("echo -e %s [Info] oixCloud Checkin Failed! Please Check And Try Again... >> /tmp/openclash.log",os.date("%Y-%m-%d %H:%M:%S")))
			end
			result = info
		end
	else
		result = "error"
	end
	HTTP.prepare_content("application/json")
	HTTP.write_json({result = result})
end

-- client access control: device list, per-client stats, access list hot updates, DNS hijack switch

local CLIENTS_META_PATH = "/etc/openclash/history/clients.json"
local CLIENTS_CACHE_PATH = "/tmp/openclash_clients.json"
local CLIENTS_PROBE_TTL = 45
local CLIENTS_PROBE_MAX = 16
local CLIENTS_ICONS = {
	phone = true, tablet = true, laptop = true, desktop = true, tv = true,
	game = true, speaker = true, nas = true, camera = true, iot = true,
	printer = true, router = true, unknown = true
}

local function clients_icon_ok(icon)
	return CLIENTS_ICONS[icon] == true or icon:match("^brand_[a-z0-9_]+$") ~= nil
end

-- cut on a UTF-8 character boundary, #value alone would split a multibyte name
local function clients_utf8_cut(value, limit)
	local count, pos = 0, 1
	while pos <= #value do
		local byte = value:byte(pos)
		local size = byte < 0x80 and 1 or (byte < 0xE0 and 2 or (byte < 0xF0 and 3 or 4))
		count = count + 1
		if count > limit then
			return value:sub(1, pos - 1)
		end
		pos = pos + size
	end
	return value
end

local function clients_json(t)
	HTTP.prepare_content("application/json")
	HTTP.write_json(t)
end

-- one runtime cache for the whole feature: local nets, neighbour probes and ip to MAC history
local function clients_cache_read()
	local data = fs.readfile(CLIENTS_CACHE_PATH)
	if data then
		local ok, parsed = pcall(json.parse, data)
		if ok and type(parsed) == "table" then return parsed end
	end
	return {}
end

local function clients_cache_write(cache)
	fs.writefile(CLIENTS_CACHE_PATH, json.stringify(cache))
end

local function ip4_to_int(ip)
	local a, b, c, d = (ip or ""):match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
	if not a then return nil end
	a, b, c, d = tonumber(a), tonumber(b), tonumber(c), tonumber(d)
	if a > 255 or b > 255 or c > 255 or d > 255 then return nil end
	return a * 16777216 + b * 65536 + c * 256 + d
end

-- own addresses, subnets and interface MACs; cached since they only change on reconfiguration
local function clients_local_nets(cache)
	cache = cache or clients_cache_read()
	local lan = cache.lan
	local now = os.time()
	if type(lan) == "table" and type(lan.nets) == "table" and type(lan.own) == "table"
		and type(lan.own_macs) == "table" and (now - (tonumber(lan.ts) or 0)) < 60 then
		return lan.nets, lan.own, lan.own_macs
	end
	local nets, own, own_macs = {}, {}, {}
	-- family filtering drops the link/ether lines, so ask for every family here
	local out = SYS.exec("ip addr show 2>/dev/null")
	local iface_mac
	for line in (out or ""):gmatch("[^\n]+") do
		local mac = line:match("^%s*link/ether%s+(%x%x:%x%x:%x%x:%x%x:%x%x:%x%x)")
		if mac then iface_mac = mac:lower() end
		local ip, len = line:match("^%s*inet%s+([%d%.]+)/(%d+)")
		if ip then
			own[ip] = true
			if iface_mac then own_macs[iface_mac] = true end
			local n = ip4_to_int(ip)
			len = tonumber(len)
			if n and len and len >= 8 and len <= 32 then
				local space = 2 ^ (32 - len)
				nets[#nets + 1] = { space = space, net = n - (n % space), octets = math.floor(len / 8) }
			end
		end
	end
	cache.lan = { ts = now, nets = nets, own = own, own_macs = own_macs }
	clients_cache_write(cache)
	return nets, own, own_macs
end

local function clients_is_lan_ip(ip, nets, own)
	if own[ip] then return false end
	local n = ip4_to_int(ip)
	if not n then return false end
	for _, net in ipairs(nets) do
		if n - (n % net.space) == net.net then
			return true
		end
	end
	return false
end

-- one IPv6 per MAC: global beats unique-local; link-local entries carry no extra info
local function clients_v6_rank(addr)
	if addr:find("^f[cd]") then return 2 end
	return 3
end

-- conntrack prints IPv6 fully expanded (240e:03b6:...), the kernel neigh table compresses it,
-- so both sides are folded into one canonical form before matching
local function clients_v6_canon(addr)
	addr = addr:gsub("%%[%w%.]+$", "")
	local hex = {}
	local left, right = addr:match("^(.-)::(.*)$")
	if left then
		for g in (left .. (left ~= "" and ":" or "")):gmatch("[^:]+") do hex[#hex + 1] = g end
		local right_hex = {}
		for g in right:gmatch("[^:]+") do right_hex[#right_hex + 1] = g end
		for _ = 1, 8 - #hex - #right_hex do hex[#hex + 1] = "0" end
		for i = 1, #right_hex do hex[#hex + 1] = right_hex[i] end
	else
		for g in addr:gmatch("[^:]+") do hex[#hex + 1] = g end
	end
	local out = {}
	for i = 1, 8 do
		out[i] = string.format("%04x", tonumber(hex[i] or "0", 16) or 0)
	end
	return table.concat(out, ":")
end

-- one neigh dump drives both families: one IPv6 address per MAC (global beats ULA) + IPv4 states/MACs
local function clients_neighbors(own_macs)
	local map, v4_state, v4_mac, v4_dev = {}, {}, {}, {}
	local out = SYS.exec("ip neigh show 2>/dev/null")
	for line in (out or ""):gmatch("[^\n]+") do
		local addr, dev = line:match("^([%x:%.]+)%s+dev%s+(%S+)")
		if addr then
			local mac = line:match("lladdr%s+(%x%x:%x%x:%x%x:%x%x:%x%x:%x%x)")
			if addr:find(":", 1, true) then
				if mac and not addr:find("^fe80:") then
					mac = mac:lower()
					if not own_macs[mac] then
						local prev = map[mac]
						if not prev or clients_v6_rank(addr) > clients_v6_rank(prev) then
							map[mac] = addr
						end
					end
				end
			else
				v4_state[addr] = line:match("([A-Z]+)%s*$") or ""
				v4_dev[addr] = dev
				if mac then v4_mac[addr] = mac:lower() end
			end
		end
	end
	return map, v4_state, v4_mac, v4_dev
end

-- stale neighbours are confirmed by a small batch of parallel pings, rotating across
-- polls; the result is written back into the kernel neighbour state the next poll reads
local function clients_probe_trigger(cache, candidates)
	local now = os.time()
	local pinged = type(cache.ping) == "table" and cache.ping or {}
	cache.ping = pinged
	local todo = {}
	for _, item in ipairs(candidates) do
		if item.dev and now - (tonumber(pinged[item.mac]) or 0) >= CLIENTS_PROBE_TTL then
			todo[#todo + 1] = item
		end
	end
	for mac, t in pairs(pinged) do
		if now - (tonumber(t) or 0) > 600 then pinged[mac] = nil end
	end
	if #todo == 0 then return false end
	local cursor = (tonumber(cache.probe_cursor) or 0) % #todo
	local args = {}
	for i = 1, math.min(#todo, CLIENTS_PROBE_MAX) do
		local item = todo[(cursor + i - 1) % #todo + 1]
		pinged[item.mac] = now
		args[#args + 1] = UTIL.shellquote(item.dev) .. " " .. UTIL.shellquote(item.ip) .. " " .. UTIL.shellquote(item.mac)
	end
	cache.probe_cursor = (cursor + #args) % #todo
	SYS.call("sh /usr/share/openclash/openclash_client_ac.sh probe " .. table.concat(args, " ") .. " >/dev/null 2>&1 &")
	return true
end

local function clients_meta_read()
	local data = fs.readfile(CLIENTS_META_PATH)
	if not data then return {} end
	local ok, parsed = pcall(json.parse, data)
	if ok and type(parsed) == "table" then return parsed end
	return {}
end

local function clients_meta_write(meta)
	SYS.call("mkdir -p /etc/openclash/history")
	local tmp = CLIENTS_META_PATH .. ".tmp"
	if fs.writefile(tmp, json.stringify(meta)) then
		os.rename(tmp, CLIENTS_META_PATH)
	end
end

local function clients_lease_names()
	local by_mac, by_ip = {}, {}
	local data = fs.readfile("/tmp/dhcp.leases")
	if data then
		for line in data:gmatch("[^\n]+") do
			local mac, ip, name = line:match("^%d+ (%S+) (%S+) (%S+)")
			if mac and mac ~= "*" and ip and ip ~= "*" then
				if name and name ~= "*" then
					by_mac[mac:lower()] = name
					by_ip[ip] = name
				end
			end
		end
	end
	return by_mac, by_ip
end

local function clients_list_values(key)
	local values = uci:get_list("openclash", "config", key) or {}
	local out = {}
	for _, v in ipairs(values) do
		v = UTIL.trim(v)
		if v ~= "" then out[#out + 1] = v end
	end
	return out
end

local function clients_apply_list(key, values)
	if #values == 0 then
		uci:delete("openclash", "config", key)
	else
		uci:set_list("openclash", "config", key, values)
	end
end

local function clients_is_mac_like(v)
	return v:match("^%x%x:%x%x:%x%x:%x%x:%x%x:%x%x$") ~= nil
end

local function clients_range_cover(values, ip)
	local m = ip4_to_int(ip or "")
	if not m then return false end
	for _, v in ipairs(values) do
		local net, len = v:match("^([%d%.]+)/(%d+)$")
		local n = net and ip4_to_int(net)
		len = tonumber(len)
		if n and len and len >= 8 and len <= 32 then
			local space = 2 ^ (32 - len)
			if m - (m % space) == n - (n % space) then return true end
		end
	end
	return false
end

-- a list entry may be an IPv4 address, an IPv4 range, an IPv6 address or a MAC;
-- IPv6 forms are folded through clients_v6_canon before comparing
local function clients_list_matcher(values)
	local exact, ranges = {}, {}
	for _, v in ipairs(values) do
		local net, len = v:match("^([%d%.]+)/(%d+)$")
		local n = net and ip4_to_int(net)
		len = tonumber(len)
		if n and len and len >= 8 and len <= 32 then
			local space = 2 ^ (32 - len)
			ranges[#ranges + 1] = { space = space, net = n - (n % space) }
		elseif v:find(":", 1, true) and not clients_is_mac_like(v) then
			exact[clients_v6_canon(v)] = true
		else
			exact[v:lower()] = true
		end
	end
	return function(value)
		if not value or value == "" then return false end
		if value:find(":", 1, true) and not clients_is_mac_like(value) then
			return exact[clients_v6_canon(value)] or false
		end
		if exact[value:lower()] then return true end
		local n = ip4_to_int(value)
		if n then
			for _, r in ipairs(ranges) do
				if n - (n % r.space) == r.net then return true end
			end
		end
		return false
	end
end

local function clients_ac_mode()
	return tonumber(fs.uci_get_config("config", "lan_ac_mode") or "0") or 0
end

local function clients_need_fix()
	local en_mode = fs.uci_get_config("config", "en_mode") or ""
	local redirect_dns = tonumber(fs.uci_get_config("config", "enable_redirect_dns") or "0") or 0
	return (en_mode:find("fake%-ip") ~= nil) and redirect_dns ~= 2
end

function action_clients_ac()
	local cache = clients_cache_read()
	local nets, own, own_macs = clients_local_nets(cache)
	local ip6_by_mac, v4_state, v4_mac, v4_dev = clients_neighbors(own_macs)
	local ac_mode = clients_ac_mode()
	local meta = clients_meta_read()
	local lease_by_mac, lease_by_ip = clients_lease_names()

	local black_ips = clients_list_values("lan_ac_black_ips")
	local white_ips = clients_list_values("lan_ac_white_ips")
	local black_mac_list = clients_list_values("lan_ac_black_macs")
	local white_mac_list = clients_list_values("lan_ac_white_macs")
	local black_macs, white_macs = {}, {}
	local match_black = clients_list_matcher(black_ips)
	local match_white = clients_list_matcher(white_ips)
	for _, mac in ipairs(black_mac_list) do black_macs[mac:lower()] = true end
	for _, mac in ipairs(white_mac_list) do white_macs[mac:lower()] = true end

	local devices, by_mac, by_ip = {}, {}, {}
	local function ensure(mac, ip)
		local d
		if mac and by_mac[mac] then d = by_mac[mac]
		elseif ip and by_ip[ip] then d = by_ip[ip]
		else d = { ips = {} }; devices[#devices + 1] = d end
		if mac and not d.mac then d.mac = mac end
		if mac then by_mac[mac] = d end
		if ip and not by_ip[ip] then
			by_ip[ip] = d
			d.ip = d.ip or ip
			local exists = false
			for _, v in ipairs(d.ips) do if v == ip then exists = true end end
			if not exists then d.ips[#d.ips + 1] = ip end
		end
		return d
	end

	local probe = type(cache.probe) == "table" and cache.probe or {}
	cache.probe = probe
	local ip_mac = type(cache.ip_mac) == "table" and cache.ip_mac or {}
	cache.ip_mac = ip_mac
	local now = os.time()
	local candidates = {}
	for ip, mac in pairs(ip_mac) do
		if now - (tonumber(mac.t) or 0) > 600 then ip_mac[ip] = nil end
	end
	for ip, state in pairs(v4_state) do
		local mac = v4_mac[ip]
		-- a failed address keeps no lladdr, the last seen MAC names the device
		local last = ip_mac[ip]
		if not mac and type(last) == "table" then mac = last.mac end
		if mac and clients_is_lan_ip(ip, nets, own) then
			ip_mac[ip] = { mac = mac, t = now }
			local d = ensure(mac, ip)
			-- DELAY/PROBE are transitional states, they are confirmed by ping below
			if state == "STALE" or state == "DELAY" or state == "PROBE" then
				local p = probe[mac]
				-- a known-offline device stays offline until a reply is observed
				if type(p) == "table" and (now - (tonumber(p.t) or 0) < CLIENTS_PROBE_TTL or p.ok == 0) then
					d.online = p.ok == 1
				else
					d.online = true
				end
				candidates[#candidates + 1] = { mac = mac, ip = ip, dev = v4_dev[ip] }
			elseif state == "FAILED" or state == "INCOMPLETE" then
				d.online = false
				probe[mac] = { t = now, ok = 0 }
				candidates[#candidates + 1] = { mac = mac, ip = ip, dev = v4_dev[ip] }
			else
				d.online = true
				probe[mac] = { t = now, ok = 1 }
			end
		end
	end

	local probing = clients_probe_trigger(cache, candidates)

	-- list entries without a current neighbour stay manageable while offline
	for _, ip in ipairs(black_ips) do
		if not by_ip[ip] and clients_is_lan_ip(ip, nets, own) then ensure(nil, ip) end
	end
	for _, ip in ipairs(white_ips) do
		if not by_ip[ip] and clients_is_lan_ip(ip, nets, own) then ensure(nil, ip) end
	end
	for _, mac in ipairs(black_mac_list) do
		if not by_mac[mac:lower()] then ensure(mac:lower(), nil) end
	end
	for _, mac in ipairs(white_mac_list) do
		if not by_mac[mac:lower()] then ensure(mac:lower(), nil) end
	end

	-- IPv6-only devices still belong to the list
	for mac in pairs(ip6_by_mac) do
		if not by_mac[mac] then
			local d = ensure(mac, nil)
			d.online = true
		end
	end

	local out = {}
	for _, d in ipairs(devices) do
		local mac = d.mac
		local m = mac and meta[mac] or nil
		local ip6 = mac and ip6_by_mac[mac] or nil
		-- set_firewall only loads the list of the active mode, so the direction of
		-- a device is decided by the current mode's list alone
		local in_black = (mac and black_macs[mac]) or match_black(d.ip) or match_black(ip6) or false
		local in_white = (mac and white_macs[mac]) or match_white(d.ip) or match_white(ip6) or false
		local dir
		if ac_mode == 1 then
			dir = in_white and "proxy" or "direct"
		else
			dir = in_black and "direct" or "proxy"
		end
		out[#out + 1] = {
			mac = mac,
			ip = d.ip,
			ip6 = ip6,
			hostname = d.hostname or (mac and lease_by_mac[mac]) or (d.ip and lease_by_ip[d.ip]) or nil,
			name = m and m.name or nil,
			icon = m and m.icon or nil,
			online = d.online or false,
			dir = dir,
			listed = in_black or in_white
		}
	end
	clients_cache_write(cache)

	clients_json({
		ok = true,
		core_running = is_running(),
		en_mode = fs.uci_get_config("config", "en_mode"),
		redirect_dns = tonumber(fs.uci_get_config("config", "enable_redirect_dns") or "0") or 0,
		ac_mode = ac_mode,
		default_dir = ac_mode == 1 and "direct" or "proxy",
		need_fix = clients_need_fix(),
		probing = probing,
		devices = out
	})
end

-- raw conntrack dump for the browser to parse and aggregate
function action_clients_stats()
	local acct = fs.readfile("/proc/sys/net/netfilter/nf_conntrack_acct")
	acct = acct and acct:gsub("%s", "") == "1" or false
	HTTP.prepare_content("text/plain")
	HTTP.header("Cache-Control", "no-store")
	HTTP.header("X-Accel-Buffering", "no")
	if not acct then
		HTTP.write("#acct=0\n")
		return
	end
	HTTP.write("#acct=1\n")

	local file = io.open("/proc/net/nf_conntrack", "r")
	if not file then return end

	-- flows started by the router itself map to no device, dropping them keeps the payload small
	local _, own = clients_local_nets()
	local skip = {}
	for ip in pairs(own or {}) do skip[#skip + 1] = "src=" .. ip .. " " end

	-- written in batches: the table never sits in one Lua string and the browser starts parsing
	-- while the rest is still streaming
	local chunk = {}
	for line in file:lines() do
		local drop = false
		for i = 1, #skip do
			if line:find(skip[i], 1, true) then
				drop = true
				break
			end
		end
		if not drop then
			chunk[#chunk + 1] = line
			if #chunk >= 256 then
				HTTP.write(table.concat(chunk, "\n") .. "\n")
				chunk = {}
			end
		end
	end
	file:close()
	if #chunk > 0 then
		HTTP.write(table.concat(chunk, "\n") .. "\n")
	end
end

function action_clients_set()
	if clients_need_fix() then
		return clients_json({ ok = false, need_fix = true })
	end
	-- the lists live in uci, so they can be prepared while the core is stopped
	local running = is_running()

	local action = HTTP.formvalue("action")
	local scope = HTTP.formvalue("scope") or "item"
	if action ~= "proxy" and action ~= "direct" then
		return clients_json({ ok = false, err = "invalid_action" })
	end
	if scope ~= "all" and scope ~= "item" then
		return clients_json({ ok = false, err = "invalid_scope" })
	end

	local ac_mode = clients_ac_mode()
	local color, script_args, flush_color = nil, nil, nil

	if scope == "all" then
		local target_mode = action == "direct" and 1 or 0
		uci:set("openclash", "config", "lan_ac_mode", tostring(target_mode))
		if target_mode == 1 then
			clients_apply_list("lan_ac_white_ips", {})
			clients_apply_list("lan_ac_white_macs", {})
			flush_color = "white"
		else
			clients_apply_list("lan_ac_black_ips", {})
			clients_apply_list("lan_ac_black_macs", {})
			flush_color = "black"
		end
		ac_mode = target_mode
	else
		local ip = UTIL.trim(HTTP.formvalue("ip") or "")
		local mac = UTIL.trim(HTTP.formvalue("mac") or ""):lower()
		if (ip ~= "" and not ip4_to_int(ip)) or (mac ~= "" and not mac:match("^%x%x:%x%x:%x%x:%x%x:%x%x:%x%x$")) then
			return clients_json({ ok = false, err = "invalid_device" })
		end
		if ip == "" and mac == "" then
			return clients_json({ ok = false, err = "invalid_device" })
		end

		-- exceptions always live in the list matching the current default policy
		if ac_mode == 1 then
			color = "white"
		else
			color = "black"
		end
		local list_ips = color == "white" and "lan_ac_white_ips" or "lan_ac_black_ips"
		local list_macs = color == "white" and "lan_ac_white_macs" or "lan_ac_black_macs"
		local other_ips = color == "white" and "lan_ac_black_ips" or "lan_ac_white_ips"
		local other_macs = color == "white" and "lan_ac_black_macs" or "lan_ac_white_macs"

		-- add = make this device an exception of the current default policy
		local add = (ac_mode == 1 and action == "proxy") or (ac_mode == 0 and action == "direct")
		if add then
			local ips = clients_list_values(list_ips)
			if ip ~= "" then
				local dup = false
				for _, v in ipairs(ips) do if v == ip then dup = true end end
				if not dup then ips[#ips + 1] = ip end
			end
			clients_apply_list(list_ips, ips)
			local macs = clients_list_values(list_macs)
			if mac ~= "" then
				local dup = false
				for _, v in ipairs(macs) do if v:lower() == mac then dup = true end end
				if not dup then macs[#macs + 1] = mac end
			end
			clients_apply_list(list_macs, macs)
			-- drop the same device from the opposite list so the new direction wins
			if ip ~= "" then
				local others = {}
				for _, v in ipairs(clients_list_values(other_ips)) do
					if v ~= ip then others[#others + 1] = v end
				end
				clients_apply_list(other_ips, others)
			end
			if mac ~= "" then
				local others = {}
				for _, v in ipairs(clients_list_values(other_macs)) do
					if v:lower() ~= mac then others[#others + 1] = v end
				end
				clients_apply_list(other_macs, others)
			end
			script_args = { color, "add", ip, mac }
		else
			-- an IPv4 range around the device keeps the entry effective even after
			-- the exact address is removed; surface it instead of a silent no-op
			if ip ~= "" and clients_range_cover(clients_list_values(list_ips), ip) then
				return clients_json({ ok = false, err = "range_covered" })
			end
			local ips = {}
			for _, v in ipairs(clients_list_values(list_ips)) do
				if not (ip ~= "" and v == ip) then ips[#ips + 1] = v end
			end
			clients_apply_list(list_ips, ips)
			local macs = {}
			for _, v in ipairs(clients_list_values(list_macs)) do
				if not (mac ~= "" and v:lower() == mac) then macs[#macs + 1] = v end
			end
			clients_apply_list(list_macs, macs)
			script_args = { color, "del", ip, mac }
		end
	end
	uci:commit("openclash")

	local applying = false
	if running then
		if flush_color then
			SYS.call(string.format("sh /usr/share/openclash/openclash_client_ac.sh %s flush >/dev/null 2>&1", flush_color))
			-- a mode flip swaps the sets the firewall rules point at, so the rules must be rebuilt
			applying = true
			SYS.call("/etc/init.d/openclash reload 'manual' >/dev/null 2>&1 &")
		elseif script_args then
			local quoted = {}
			for i = 1, 4 do quoted[i] = UTIL.shellquote(script_args[i] or "") end
			local rc = SYS.call(string.format("sh /usr/share/openclash/openclash_client_ac.sh %s %s %s %s >/dev/null 2>&1", quoted[1], quoted[2], quoted[3], quoted[4]))
			if rc == 3 then
				applying = true
				SYS.call("/etc/init.d/openclash reload 'manual' >/dev/null 2>&1 &")
			end
		end

		-- drop existing connections so the change applies to them immediately
		if applying then
			SYS.call("(sleep 3; sh /usr/share/openclash/openclash_history_get.sh close_all_conection) >/dev/null 2>&1 &")
		else
			SYS.call("sh /usr/share/openclash/openclash_history_get.sh close_all_conection >/dev/null 2>&1 &")
		end
	end

	clients_json({
		ok = true,
		applying = applying,
		core_running = running,
		ac_mode = ac_mode,
		default_dir = ac_mode == 1 and "direct" or "proxy"
	})
end

function action_clients_meta()
	local mac = UTIL.trim(HTTP.formvalue("mac") or ""):lower()
	if not mac:match("^%x%x:%x%x:%x%x:%x%x:%x%x:%x%x$") then
		return clients_json({ ok = false, err = "invalid_mac" })
	end

	local name = HTTP.formvalue("name")
	local icon = HTTP.formvalue("icon")
	if icon ~= nil then
		icon = UTIL.trim(icon)
		if icon ~= "" and not clients_icon_ok(icon) then
			return clients_json({ ok = false, err = "invalid_icon" })
		end
	end

	local meta = clients_meta_read()
	local entry = meta[mac] or {}
	if name ~= nil then
		name = clients_utf8_cut(UTIL.trim(name), 20)
		entry.name = name ~= "" and name or nil
	end
	if icon ~= nil then
		entry.icon = icon ~= "" and icon or nil
	end
	if entry.name or entry.icon then
		meta[mac] = entry
	else
		meta[mac] = nil
	end
	clients_meta_write(meta)

	clients_json({ ok = true })
end

function action_clients_dns_switch()
	local redirect_dns = tonumber(fs.uci_get_config("config", "enable_redirect_dns") or "0") or 0
	if redirect_dns == 2 then
		return clients_json({ ok = true, already = true })
	end
	uci:set("openclash", "config", "enable_redirect_dns", "2")
	uci:commit("openclash")
	-- a stopped core applies the value at its next start
	if not is_running() then
		return clients_json({ ok = true, reloaded = false, core_running = false })
	end
	-- blocks until the rules are applied so the caller can show the real progress
	local ok = SYS.call("/etc/init.d/openclash reload 'dns-switch' >/dev/null 2>&1") == 0
	clients_json({ ok = ok, reloaded = ok, core_running = true })
end
