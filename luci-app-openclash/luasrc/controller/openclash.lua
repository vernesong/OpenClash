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
	entry({"admin", "services", "openclash", "startlog"},call("action_start")).leaf=true
	entry({"admin", "services", "openclash", "refresh_log"},call("action_refresh_log"))
	entry({"admin", "services", "openclash", "del_log"},call("action_del_log"))
	entry({"admin", "services", "openclash", "del_start_log"},call("action_del_start_log"))
	entry({"admin", "services", "openclash", "close_all_connection"},call("action_close_all_connection"))
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
	entry({"admin", "services", "openclash", "proxy-provider-file-manage"},form("openclash/proxy-provider-file-manage"), nil).leaf = true
	entry({"admin", "services", "openclash", "rule-providers-file-manage"},form("openclash/rule-providers-file-manage"), nil).leaf = true
	entry({"admin", "services", "openclash", "config-subscribe-edit"},cbi("openclash/config-subscribe-edit"), nil).leaf = true
	entry({"admin", "services", "openclash", "servers-config"},cbi("openclash/servers-config"), nil).leaf = true
	entry({"admin", "services", "openclash", "groups-config"},cbi("openclash/groups-config"), nil).leaf = true
	entry({"admin", "services", "openclash", "proxy-provider-config"},cbi("openclash/proxy-provider-config"), nil).leaf = true
	entry({"admin", "services", "openclash", "config"},form("openclash/config"),_("Config Manage"), 80).leaf = true
	entry({"admin", "services", "openclash", "log"},cbi("openclash/log"),_("Server Logs"), 90).leaf = true
	entry({"admin", "services", "openclash", "myip_check"}, call("action_myip_check"))
	entry({"admin", "services", "openclash", "website_check"}, call("action_website_check"))
	entry({"admin", "services", "openclash", "version_history"}, call("action_version_history"))
	entry({"admin", "services", "openclash", "addr_info"}, call("action_cdn_info"))
	entry({"admin", "services", "openclash", "save_github_address_mod"}, call("action_save_github_address_mod"))
	entry({"admin", "services", "openclash", "proxy_info"}, call("action_proxy_info"))
	entry({"admin", "services", "openclash", "oc_settings"}, call("action_oc_settings"))
	entry({"admin", "services", "openclash", "switch_oc_setting"}, call("action_switch_oc_setting"))
	entry({"admin", "services", "openclash", "generate_pac"}, call("action_generate_pac"))
	entry({"admin", "services", "openclash", "action"}, call("action_oc_action"))
	entry({"admin", "services", "openclash", "config_file_list"}, call("action_config_file_list"))
	entry({"admin", "services", "openclash", "config_file_read"}, call("action_config_file_read"))
	entry({"admin", "services", "openclash", "config_file_save"}, call("action_config_file_save"))
	entry({"admin", "services", "openclash", "upload_config"}, call("action_upload_config"))
	entry({"admin", "services", "openclash", "add_subscription"}, call("action_add_subscription"))
	entry({"admin", "services", "openclash", "subconverter_version"}, call("action_subconverter_version"))
	entry({"admin", "services", "openclash", "generate_age_key"}, call("action_generate_age_key"))
	entry({"admin", "services", "openclash", "cal_age_public_key"}, call("action_cal_age_public_key"))
	entry({"admin", "services", "openclash", "add_age_config"}, call("action_add_age_config"))
	entry({"admin", "services", "openclash", "upload_overwrite"}, call("action_upload_overwrite"))
	entry({"admin", "services", "openclash", "overwrite_subscribe_info"}, call("action_overwrite_subscribe_info"))
	entry({"admin", "services", "openclash", "overwrite_file_list"}, call("action_overwrite_file_list"))
	entry({"admin", "services", "openclash", "delete_overwrite_file"}, call("delete_overwrite_file"))
	entry({"admin", "services", "openclash", "get_subscribe_data"}, call("action_get_subscribe_data"))
	entry({"admin", "services", "openclash", "get_subscribe_info_data"}, call("action_get_subscribe_info_data"))
	entry({"admin", "services", "openclash", "oix_info"}, call("oix_info"))
	entry({"admin", "services", "openclash", "oix_checkin"}, call("oix_checkin"))
	entry({"admin", "services", "openclash", "oix_logout"}, call("oix_logout"))
	entry({"admin", "services", "openclash", "oix_login"}, call("oix_login"))
	entry({"admin", "services", "openclash", "oix_login_info_save"}, call("oix_login_info_save"))
	entry({"admin", "services", "openclash", "oix_params_sync"}, call("oix_params_sync"))
	entry({"admin", "services", "openclash", "oix_params_get"}, call("oix_params_get"))
end

local SYS = require "luci.sys"
local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"
local UTIL = require "luci.util"
local fs = require "luci.openclash"
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

local function db_foward_domain()
	return fs.uci_get_config("config", "dashboard_forward_domain")
end

local function db_foward_port()
	return fs.uci_get_config("config", "dashboard_forward_port")
end

local function db_foward_ssl()
	return fs.uci_get_config("config", "dashboard_forward_ssl") or 0
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
	local v = "0"
	if not fs.access(meta_core_path) then
		return v
	else
		v = SYS.exec(string.format("%s -v 2>/dev/null |awk -F ' ' '{print $3}' |head -1 |tr -d '\n'", meta_core_path))
		if not v or v == "" then
			return "0"
		end
	end
	return v
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
		if fs.pkg_type() == "opkg" then
			v = fs.read_pkg_field("luci-app-openclash", "Version")
		else
			v = fs.read_pkg_field("luci-app-openclash", "V"):match("[%d%.]+") or ""
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
		local daip = daip()
		local dase = dase() or ""
		local cn_port = cn_port()
		if daip and cn_port then
			fake_ip_state = SYS.exec(string.format('curl -sL -m 3 --retry 2 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XPOST http://"%s":"%s"/cache/fakeip/flush', dase, daip, cn_port))
			dns_state = SYS.exec(string.format('curl -sL -m 3 --retry 2 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XPOST http://"%s":"%s"/cache/dns/flush', dase, daip, cn_port))
		end
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
		local daip = daip()
		local dase = dase() or ""
		local cn_port = cn_port()
		if daip and cn_port then
			flush_state = SYS.exec(string.format('curl -sL -m 3 --retry 2 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XPOST http://"%s":"%s"/cache/smart/flush', dase, daip, cn_port))
		end
	end
	HTTP.prepare_content("application/json")
	HTTP.write_json({
		flush_status = flush_state;
	})
end

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

	local update_result = SYS.call(string.format("/usr/share/openclash/openclash.sh '%s' >/dev/null 2>&1", filename))

	if update_result == 0 then
		HTTP.write_json({
			status = "success",
			message = "Config update started successfully",
			filename = filename
		})
	else
		HTTP.write_json({
			status = "error",
			message = "Failed to update config"
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

	uci:foreach("openclash", "config_subscribe",
		function(s)
			if s.name == filename then
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

	if filename and not is_start() then
		url_result = get_sub_url(filename)

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
		local dase_val = dase() or ""
		local cn_port_val = cn_port()
		if daip_val and cn_port_val then
			local info = json.parse(SYS.exec(string.format(
				'curl -sL -m 3 --retry 2 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XGET http://"%s":"%s"/configs',
				dase_val, daip_val, cn_port_val)))
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
		SYS.exec("/etc/init.d/openclash restart >/dev/null 2>&1 &")
	end
end

function action_log_level()
	local level, info
	if is_running() then
		local daip = daip()
		local dase = dase() or ""
		local cn_port = cn_port()
		if not daip or not cn_port then return end
		info = json.parse(SYS.exec(string.format('curl -sL -m 3 --retry 2 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XGET http://"%s":"%s"/configs', dase, daip, cn_port)))
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

local function s(e)
local a={' B/S',' KB/S',' MB/S',' GB/S',' TB/S',' PB/S'}
local t=0
if (e<=1024) then
	return e..a[1]
else
	repeat
		e=e/1024
		t=t+1
	until(e<=1024)
	return math.floor(e * 10 + 0.5) / 10 .. a[t]
	end
end

function action_toolbar_show_sys()
	local cpu = "0"
	local load_avg = "0"
	local cpu_count = SYS.exec("grep -c ^processor /proc/cpuinfo 2>/dev/null"):gsub("\n", "") or 1
	local pid = SYS.exec("pgrep -f '^[^ ]*clash' | head -1 | tr -d '\n' 2>/dev/null")

	if pid and pid ~= "" then
		cpu = SYS.exec(string.format([[
		top -b -n1 | awk -v pid="%s" '
			BEGIN { cpu_col=0; }
			$0 ~ /%%CPU/ { 
				for(i=1;i<=NF;i++) if($i=="%%CPU") cpu_col=i;
				next
			}
			cpu_col>0 && $1==pid { print $cpu_col }
		'
		]], pid))
		if cpu and cpu ~= "" then
			cpu = string.match(cpu, "%d+%.?%d*") or "0"
		else
			cpu = "0"
		end

		load_avg = SYS.exec("awk '{print $2; exit}' /proc/loadavg 2>/dev/null"):gsub("\n", "") or "0"

		if not string.match(load_avg, "^[0-9]*%.?[0-9]*$") then
			load_avg = "0"
		end
	end

	HTTP.prepare_content("application/json")
	HTTP.write_json({
		cpu = cpu,
		load_avg = tostring(math.floor(tonumber(load_avg) / tonumber(cpu_count) * 100));
	})
end

function action_toolbar_show()
	local pid = SYS.exec("pgrep -f '^[^ ]*clash' | head -1 | tr -d '\n' 2>/dev/null")
	local traffic, connections, connection, up, down, up_total, down_total, mem, cpu, load_avg, cpu_count
	if pid and pid ~= "" then
		local daip = daip()
		local dase = dase() or ""
		local cn_port = cn_port()
		if not daip or not cn_port then return end

		-- Parallel curl helper
		local function fork_curl(endpoint)
			local fdi, fdo = nixio.pipe()
			if not fdi or not fdo then return nil end
			local cmd = string.format(
				'curl -sL -m 3 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XGET "http://%s:%s/%s"',
				dase, daip, cn_port, endpoint
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

		local t_job = fork_curl("traffic")
		local c_job = fork_curl("connections")

		if t_job and c_job then
			local t_done, c_done = false, false
			local delay = 50000000
			local max_wait = 40
			for _ = 1, max_wait do
				if not t_done then
					local buf = try_read(t_job.fdi, 4096)
					if buf then t_job.buf = t_job.buf .. buf end
					if nixio.waitpid(t_job.pid, "nohang") then
						while true do
							local b = try_read(t_job.fdi, 4096)
							if not b then break end
							t_job.buf = t_job.buf .. b
						end
						pcall(t_job.fdi.close, t_job.fdi)
						t_done = true
					end
				end
				if not c_done then
					local buf = try_read(c_job.fdi, 4096)
					if buf then c_job.buf = c_job.buf .. buf end
					if nixio.waitpid(c_job.pid, "nohang") then
						while true do
							local b = try_read(c_job.fdi, 4096)
							if not b then break end
							c_job.buf = c_job.buf .. b
						end
						pcall(c_job.fdi.close, c_job.fdi)
						c_done = true
					end
				end
				if t_done and c_done then break end
				nixio.nanosleep(0, delay)
				delay = math.min(delay * 2, 200000000)
			end
			if not t_done then
				pcall(t_job.fdi.close, t_job.fdi)
				nixio.kill(t_job.pid, 9)
			end
			if not c_done then
				pcall(c_job.fdi.close, c_job.fdi)
				nixio.kill(c_job.pid, 9)
			end
			traffic = t_done and t_job.buf ~= "" and json.parse(t_job.buf) or nil
			connections = c_done and c_job.buf ~= "" and json.parse(c_job.buf) or nil
		else
			if t_job then pcall(t_job.fdi.close, t_job.fdi) end
			if c_job then pcall(c_job.fdi.close, c_job.fdi) end
			traffic = json.parse(SYS.exec(string.format('curl -sL -m 3 --retry 2 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XGET http://"%s":"%s"/traffic', dase, daip, cn_port)))
			connections = json.parse(SYS.exec(string.format('curl -sL -m 3 --retry 2 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XGET http://"%s":"%s"/connections', dase, daip, cn_port)))
		end

		if traffic and connections and connections.connections then
			connection = #(connections.connections)
			up = s(traffic.up)
			down = s(traffic.down)
			up_total = fs.filesize(connections.uploadTotal)
			down_total = fs.filesize(connections.downloadTotal)
		else
			up = "0 B/S"
			down = "0 B/S"
			up_total = "0 KB"
			down_total = "0 KB"
			connection = "0"
		end

		mem = tonumber(SYS.exec(string.format("cat /proc/%s/status 2>/dev/null |grep -w VmRSS |awk '{print $2}'", pid)))
		cpu = SYS.exec(string.format([[
		top -b -n1 | awk -v pid="%s" '
			BEGIN { cpu_col=0; }
			$0 ~ /%%CPU/ { 
				for(i=1;i<=NF;i++) if($i=="%%CPU") cpu_col=i;
				next
			}
			cpu_col>0 && $1==pid { print $cpu_col }
		'
		]], pid))

		if mem and cpu then
			mem = fs.filesize(mem*1024) or "0 KB"
			cpu = string.match(cpu, "%d+%.?%d*") or "0"
		else
			mem = "0 KB"
			cpu = "0"
		end

		load_avg = SYS.exec("awk '{print $2; exit}' /proc/loadavg 2>/dev/null"):gsub("\n", "") or "0"
		cpu_count = SYS.exec("grep -c ^processor /proc/cpuinfo 2>/dev/null"):gsub("\n", "") or 1

		if not string.match(load_avg, "^[0-9]*%.?[0-9]*$") then
			load_avg = "0"
		end
	else
		return
	end

	HTTP.prepare_content("application/json")
	HTTP.write_json({
		connections = connection,
		up = up,
		down = down,
		up_total = up_total,
		down_total = down_total,
		mem = mem,
		cpu = cpu,
		load_avg = tostring(math.floor(tonumber(load_avg) / tonumber(cpu_count) * 100));
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
		db_foward_port = db_foward_port(),
		db_foward_domain = db_foward_domain(),
		cn_port = cn_port()
	}
	if internal then return data end
	HTTP.prepare_content("application/json")
	HTTP.write_json(data)
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
		db_forward_ssl = db_foward_ssl(),
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
-- New LuCI: luci.http.write = L.print() (http.lua) is C-stdio buffered
-- (musl 4096B / glibc 8192B), io.flush() can't reach it -> use L.http:write.
-- Old LuCI (18.06): no L global; HTTP.write = coroutine.yield, immediate.
-- CRITICAL: on old LuCI HTTP.write = coroutine.yield, and Lua 5.1 cannot
-- yield across a C function boundary. Wrapping write_padded() in pcall()
-- throws "attempt to yield across C-call boundary" -> pcall swallows the
-- error and the chunk is silently lost while the rest of the script keeps
-- running (backend logs look fine but the frontend receives nothing).
-- Callers MUST call write_padded() directly, never through pcall.
-- 8192-space first line only helps the old buffered path.
-- Ref: openwrt/luci master: libs/luci-lib-base/luasrc/http.lua
--      modules/luci-base/ucode/http.uc, htdocs/cgi-bin/luci
--      immortalwrt/luci 18.06-k5.4: modules/luci-base/luasrc/http.lua
--      jow-/ucode: vm.c (uc_vm_insn_print), lib/fs.c, main.c
--
-- Nginx mode (ImmortalWrt luci-nginx / luci-ssl-nginx): LuCI is not run by
-- uhttpd directly; nginx forwards /cgi-bin/luci over the uwsgi protocol to
-- the uwsgi-cgi plugin (luci-webui vassal), which forks the CGI and pipes its
-- stdout back through nginx. The CGI-side flush (io.flush / L.http:write)
-- only gets data into the pipe; nginx still buffers the whole response body
-- by default (uwsgi_buffering on, ~8KB) and only pushes it once the buffer
-- fills or the response ends, so the 8192-space first line alone cannot keep
-- the stream alive. To make nginx forward every chunk in real time, the CGI
-- response must carry the "X-Accel-Buffering: no" header (honored by nginx
-- proxy/fastcgi/uwsgi modules). It is emitted unconditionally on the very
-- first write, before any body, so it lands in the response header block.
-- Backend detection via SERVER_SOFTWARE was deliberately dropped: the value
-- is not reliable (custom uwsgi_params may pre-set it to "nginx", defeating
-- the check). The header is only meaningful to nginx and is stripped by it
-- before reaching the client; under uhttpd it is simply passed through and
-- ignored, so sending it always is harmless.
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
	["init"] = "/etc/init.d/[o]penclash",
	["openclash.sh"] = "[o]penclash\\.sh",
	["openclash_core.sh"] = "[o]penclash_core\\.sh",
	["openclash_update.sh"] = "[o]penclash_update\\.sh",
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
	local pattern = START_SCRIPT_PATTERNS[HTTP.formvalue("script")]

	local cmd
	if pattern then
		cmd = string.format(
			"logfile='%s'; pattern='%s'; " ..
			"if [ \"$(ps --version 2>&1 | grep -c procps-ng)\" -eq 1 ]; then PS_CMD='ps -efw'; else PS_CMD='ps -w'; fi; " ..
			"bytes=$(wc -c < \"$logfile\" 2>/dev/null); bytes=${bytes:-0}; " ..
			"[ \"$bytes\" -gt 0 ] && tail -c +1 \"$logfile\" 2>/dev/null; " ..
			"seen=0; [ \"$bytes\" -gt 0 ] && seen=1; " ..
			"elapsed=0; " ..
			"while true; do " ..
			"new_bytes=$(wc -c < \"$logfile\" 2>/dev/null); new_bytes=${new_bytes:-0}; " ..
			"if [ \"$new_bytes\" -gt \"$bytes\" ] 2>/dev/null; then " ..
			"if [ \"$(tail -c 1 \"$logfile\" 2>/dev/null)\" = \"$(printf '\\n')\" ]; then " ..
			"tail -c +$((bytes + 1)) \"$logfile\" 2>/dev/null; bytes=$new_bytes; " ..
			"else tail -c +$((bytes + 1)) \"$logfile\" 2>/dev/null | awk '{ if (p) printf \"%%s\\n\", prev; prev = $0; p = 1 }'; " ..
			"bytes=$((new_bytes - $(tail -c +$((bytes + 1)) \"$logfile\" 2>/dev/null | awk 'END { print length($0) }'))); " ..
			"fi; " ..
			"elif [ \"$new_bytes\" -lt \"$bytes\" ] 2>/dev/null; then " ..
			"if [ \"$(tail -c 1 \"$logfile\" 2>/dev/null)\" = \"$(printf '\\n')\" ]; then " ..
			"tail -c +1 \"$logfile\" 2>/dev/null; bytes=$new_bytes; " ..
			"else tail -c +1 \"$logfile\" 2>/dev/null | awk '{ if (p) printf \"%%s\\n\", prev; prev = $0; p = 1 }'; " ..
			"bytes=$((new_bytes - $(tail -c +1 \"$logfile\" 2>/dev/null | awk 'END { print length($0) }'))); " ..
			"fi; " ..
			"fi; " ..
			"liveness=$($PS_CMD | grep -v grep | grep \"$pattern\" | grep -v \"openclash_start\" | grep -c \"^\"); " ..
			"[ \"$liveness\" -gt 0 ] 2>/dev/null && seen=1; " ..
			"if [ \"$seen\" -eq 1 ]; then " ..
			"if [ \"$liveness\" = \"0\" ]; then echo '##FINISHED##'; exit 0; fi; " ..
			"if [ \"$elapsed\" -ge 50 ]; then echo '##CONTINUE##'; exit 0; fi; " ..
			"else " ..
			"if [ \"$elapsed\" -ge 5 ]; then echo '##FINISHED##'; exit 0; fi; " ..
			"fi; " ..
			"sleep 1; elapsed=$((elapsed + 1)); " ..
			"done",
			logfile, pattern
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
	local limit = core_refresh and 1000 or 2000
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
		local util = io.popen(cmd)
		if util and util ~= "" then
			while true do
				local ln = util:read("*l")
				if not ln then break end
				write_padded(ln)
			end
			util:close()
		end
		return
	end
	HTTP.status(500, "Bad address")
end

function action_diag_dns()
	local addr = HTTP.formvalue("addr")
	if addr and datatype.hostname(addr)then
		local cmd = string.format("/usr/share/openclash/openclash_debug_dns.lua %s", addr)
		HTTP.prepare_content("text/plain")
		local util = io.popen(cmd)
		if util and util ~= "" then
			while true do
				local ln = util:read("*l")
				if not ln then break end
				write_padded(ln)
			end
			util:close()
		end
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

function create_file()
	local file_name = HTTP.formvalue("filename")
	local file_path = HTTP.formvalue("filepath")..file_name
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

		local ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
		local cmd = string.format(
			'curl -SsL -m 10 -A "%s" "%s" 2>/dev/null',
			ua, service.url
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
			'curl -sL -m 10 --retry 2 -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" "https://api.ip.sb/geoip/%s" 2>/dev/null',
			result.ipify.ip
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
		if [ "$LATENCY" = "null" ] || [ "$C_TIME" -lt "$LATENCY" ] 2>/dev/null; then
			LATENCY=$C_TIME
		fi
	elif [ "$LATENCY" != "null" ] && [ "$LATENCY" != "-3" ]; then
		:
	else
		[ "$C_CODE" = "404" ] && LATENCY=-3 || LATENCY=-2
	fi
elif [ $C_EXIT -ne 0 ]; then
	[ "$LATENCY" = "null" ] && LATENCY=-1
else
	[ "$LATENCY" = "null" ] && LATENCY=-2
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
								'HTTP' => { 'ports' => [80, '8080-8880'], 'override-destination' => true }
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
			SYS.exec("/etc/init.d/openclash restart >/dev/null 2>&1 &")
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

local function is_safe_filename(filename)
	return filename and filename:match("^[%w%._%-]+$") and not filename:match("^%.")
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
							local age_symbol = content:find("BEGIN AGE ENCRYPTED FILE")
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
	local upload = HTTP.formvalue("config_file")
	local filename = HTTP.formvalue("filename")

	HTTP.prepare_content("application/json")

	if not upload or upload == "" then
		HTTP.write_json({
			status = "error",
			message = "No file uploaded"
		})
		return
	end

	if not filename or filename == "" then
		filename = "upload_" .. os.date("%Y%m%d_%H%M%S")
	end

	if not is_safe_filename(filename) then
		HTTP.write_json({
			status = "error",
			message = "Invalid filename"
		})
		return
	end

	if not string.match(filename, "%.ya?ml$") then
		filename = filename .. ".yaml"
	end

	local config_dir = "/etc/openclash/config/"
	local target_path = config_dir .. filename

	if string.len(upload) == 0 then
		HTTP.write_json({
			status = "error",
			message = "Uploaded file is empty"
		})
		return
	end

	local file_size = string.len(upload)
	if file_size > 10 * 1024 * 1024 then
		HTTP.write_json({
			status = "error",
			message = string.format("File size (%s) exceeds 10MB limit", fs.filesize(file_size))
		})
		return
	end

	local yaml_valid = false
	local content_start = string.sub(upload, 1, 5000)

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

	SYS.call("mkdir -p " .. config_dir)

	local fp = io.open(target_path, "w")
	if fp then
		fp:write(upload)
		fp:close()

		SYS.call(string.format("chmod 644 '%s'", target_path))
		SYS.call(string.format("chown root:root '%s'", target_path))

		local written_content = fs.readfile(target_path)
		if not written_content or string.len(written_content) ~= file_size then
			fs.unlink(target_path)
			HTTP.write_json({
				status = "error",
				message = "File write verification failed"
			})
			return
		end

		HTTP.write_json({
			status = "success",
			message = "Config file uploaded successfully",
			filename = filename,
			file_path = target_path,
			file_size = file_size,
			readable_size = fs.filesize(file_size)
		})
	else
		HTTP.write_json({
			status = "error",
			message = "Failed to save config file to disk"
		})
	end
end

function action_config_file_read()
	local config_file = HTTP.formvalue("config_file")
	HTTP.prepare_content("application/json")

	if not config_file then
		HTTP.write_json({
			status = "error",
			message = "Missing config_file parameter"
		})
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
		HTTP.write_json({
			status = "error",
			message = "Invalid config file path"
		})
		return
	end

	if not fs.access(config_file) then
		HTTP.write_json({
			status = "success",
			content = "",
			file_info = {
				path = config_file,
				size = 0,
				mtime = 0,
				readable_size = "0 KB",
				last_modified = ""
			}
		})
		return
	end

	local stat = fs.stat(config_file)
	if not stat or stat.type ~= "regular" then
		HTTP.write_json({
			status = "error",
			message = "Config file is not a regular file"
		})
		return
	end

	if stat.size > 10 * 1024 * 1024 then
		HTTP.write_json({
			status = "error",
			message = "Config file too large (max 10MB)"
		})
		return
	end

	local content = fs.readfile(config_file)
	if content == nil then
		HTTP.write_json({
			status = "error",
			message = "Failed to read config file"
		})
		return
	end

	HTTP.write_json({
		status = "success",
		content = content,
		file_info = {
			path = config_file,
			size = stat.size,
			mtime = stat.mtime,
			readable_size = fs.filesize(stat.size),
			last_modified = os.date("%Y-%m-%d %H:%M:%S", stat.mtime)
		}
	})
end

function action_config_file_save()
	local config_file = HTTP.formvalue("config_file")
	local content = HTTP.formvalue("content")
	HTTP.prepare_content("application/json")
	if content then
		content = content:gsub("\r\n", "\n"):gsub("\r", "\n")
	end

	if not config_file then
		HTTP.write_json({
			status = "error",
			message = "Missing config_file parameter"
		})
		return
	end

	if not content then
		HTTP.write_json({
			status = "error",
			message = "Missing content parameter"
		})
		return
	end

	local is_overwrite = (config_file == "/etc/openclash/custom/openclash_custom_overwrite.sh" or config_file:match("^/etc/openclash/overwrite/[^/]+$"))

	if not is_overwrite then
		if not string.match(config_file, "^/etc/openclash/config/[^/]+%.ya?ml$") or string.find(config_file, "%.%.") then
			HTTP.write_json({
				status = "error",
				message = "Invalid config file path"
			})
			return
		end
	else
		if not (config_file == "/etc/openclash/custom/openclash_custom_overwrite.sh" or (config_file:match("^/etc/openclash/overwrite/[^/]+$") and not string.find(config_file, "%.%."))) then
			HTTP.write_json({
				status = "error",
				message = "Invalid overwrite file path"
			})
			return
		end
	end

	if string.len(content) > 10 * 1024 * 1024 then
		HTTP.write_json({
			status = "error",
			message = "Content too large (max 10MB)"
		})
		return
	end

	local backup_file = nil
	if fs.access(config_file) then
		backup_file = config_file .. ".backup." .. os.time()
		local backup_success = SYS.call(string.format("cp '%s' '%s'", config_file, backup_file))
		if backup_success ~= 0 then
			HTTP.write_json({
				status = "error",
				message = "Failed to create backup file"
			})
			return
		end
	end

	local success = fs.writefile(config_file, content)
	if not success then
		if backup_file then
			SYS.call(string.format("mv '%s' '%s'", backup_file, config_file))
		end

		HTTP.write_json({
			status = "error",
			message = "Failed to write config file"
		})
		return
	end

	local written_content = fs.readfile(config_file)
	if written_content ~= content then
		if backup_file then
			SYS.call(string.format("mv '%s' '%s'", backup_file, config_file))
		end

		HTTP.write_json({
			status = "error",
			message = "File write verification failed"
		})
		return
	end

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
	local custom_params = HTTP.formvalue("custom_params") or ""
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

	local is_valid_url = false

	if address and address ~= "" and sub_convert == "1" then
		local prefixed_http_pattern = "^[^,%s]+,https?://.+"
		local encoded_prefixed_http_pattern = "^[^%%%s]+%%2[Cc]https?%%3[Aa]%%2[Ff]%%2[Ff].+"

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
						or string.find(link, prefixed_http_pattern)
						or string.find(link, encoded_prefixed_http_pattern) then
						is_valid_url = true
						break
					end
				end
			end
		else
			if string.find(address, "^https?://")
				or string.find(address, "^[a-zA-Z]+://")
				or string.find(address, prefixed_http_pattern)
				or string.find(address, encoded_prefixed_http_pattern) then
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

function action_upload_overwrite()
	local upload = HTTP.formvalue("config_file")
	local filename = HTTP.formvalue("filename")
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
	HTTP.prepare_content("application/json")
	if not upload or upload == "" then
		HTTP.write_json({status = "error", message = "No file uploaded"})
		return
	end
	if not filename or filename == "" then
		filename = "upload_" .. os.date("%Y%m%d_%H%M%S")
	end
	if not is_safe_filename(filename) then
		HTTP.write_json({status = "error", message = "Invalid filename"})
		return
	end
	local overwrite_dir = "/etc/openclash/overwrite/"
	SYS.call("mkdir -p " .. overwrite_dir)
	local target_path = overwrite_dir .. filename
	if string.len(upload) == 0 then
		HTTP.write_json({status = "error", message = "Uploaded file is empty"})
		return
	end
	local file_size = string.len(upload)
	if file_size > 10 * 1024 * 1024 then
		HTTP.write_json({status = "error", message = string.format("File size (%s) exceeds 10MB limit", require("luci.openclash").filesize(file_size))})
		return
	end
	local fp = io.open(target_path, "w")
	if fp then
		fp:write(upload)
		fp:close()
		SYS.call(string.format("chmod 644 '%s'", target_path))
		SYS.call(string.format("chown root:root '%s'", target_path))
		local written_content = fs.readfile(target_path)
		if not written_content or string.len(written_content) ~= file_size then
			fs.unlink(target_path)
			HTTP.write_json({status = "error", message = "File write verification failed"})
			return
		end

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
				if s.order == nil or (s.order ~= nil and s.order ~= order and order ~= nil) then
					if order == nil then
						local max_order = -1
						uci:foreach("openclash", "config_overwrite", function(s)
							local o = tonumber(s.order)
							if o and o > max_order then max_order = o end
						end)
						order = tostring(max_order + 1)
					end
					uci:set("openclash", s[".name"], "order", order)
				else
					uci:set("openclash", s[".name"], "order", tonumber(order))
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
	else
		HTTP.write_json({status = "error", message = "Failed to save file to disk"})
	end
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
					local config_list = {}
					for _, item in ipairs(s.config) do
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

		if typ == "http" then
			if not url or url == "" then
				HTTP.prepare_content("application/json")
				HTTP.write_json({
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
				HTTP.prepare_content("application/json")
				HTTP.write_json({
					status = "error",
					message = "Invalid subscribe URL format, only single HTTP/HTTPS link is supported"
				})
				return
			end
		end

		local found = false
		if old_section_name and old_section_name ~= "" and old_section_name ~= section_name then
			uci:foreach("openclash", "config_overwrite", function(s)
				if s.name == old_section_name then
					uci:set("openclash", s[".name"], "name", section_name)
					uci:set("openclash", s[".name"], "url", url)
					uci:delete("openclash", s[".name"], "config")
					if #config_values > 0 then
						uci:set_list("openclash", s[".name"], "config", config_values)
					end
					uci:set("openclash", s[".name"], "update_days", update_days)
					uci:set("openclash", s[".name"], "update_hour", update_hour)
					uci:set("openclash", s[".name"], "type", typ)
					uci:set("openclash", s[".name"], "param", param)
					if s.order == nil or (s.order ~= nil and s.order ~= order and order ~= nil) then
						if order == nil then
							local max_order = -1
							uci:foreach("openclash", "config_overwrite", function(s)
								local o = tonumber(s.order)
								if o and o > max_order then max_order = o end
							end)
							order = tostring(max_order + 1)
						end
						uci:set("openclash", s[".name"], "order", order)
					else
						uci:set("openclash", s[".name"], "order", tonumber(order) or 1)
					end
					if s.enable == nil or (s.enable ~= nil and enable ~= nil) then
						if enable == nil then
							enable = 0
						end
						uci:set("openclash", s[".name"], "enable", tostring(enable))
					end
					found = true
					return false
				end
			end)
			local overwrite_dir = "/etc/openclash/overwrite/"
			local old_file = overwrite_dir .. old_section_name
			local new_file = overwrite_dir .. section_name
			if fs.access(old_file) and not fs.access(new_file) then
				fs.rename(old_file, new_file)
			end
			uci:commit("openclash")
			HTTP.prepare_content("application/json")
			HTTP.write_json({status="success"})
			return
		end
		if not found then
			uci:foreach("openclash", "config_overwrite", function(s)
				if s.name == section_name then
					uci:set("openclash", s[".name"], "url", url)
					uci:delete("openclash", s[".name"], "config")
					if #config_values > 0 then
						uci:set_list("openclash", s[".name"], "config", config_values)
					end
					uci:set("openclash", s[".name"], "update_days", update_days)
					uci:set("openclash", s[".name"], "update_hour", update_hour)
					uci:set("openclash", s[".name"], "type", typ)
					uci:set("openclash", s[".name"], "param", param)
					if s.order == nil or (s.order ~= nil and s.order ~= order and order ~= nil) then
						if order == nil then
							local max_order = -1
							uci:foreach("openclash", "config_overwrite", function(s)
								local o = tonumber(s.order)
								if o and o > max_order then max_order = o end
							end)
							order = tostring(max_order + 1)
						end
						uci:set("openclash", s[".name"], "order", order)
					else
						uci:set("openclash", s[".name"], "order", tonumber(order))
					end
					if s.enable == nil or (s.enable ~= nil and enable ~= nil) then
						if enable == nil then
							enable = 0
						end
						uci:set("openclash", s[".name"], "enable", tostring(enable))
					end
					found = true
					return false
				end
			end)
		end
		if not found then
			local sid = uci:add("openclash", "config_overwrite")
			uci:set("openclash", sid, "name", section_name)
			uci:set("openclash", sid, "url", url)
			uci:delete("openclash", sid, "config")
			if #config_values > 0 then
				uci:set_list("openclash", sid, "config", config_values)
			end
			uci:set("openclash", sid, "update_days", update_days)
			uci:set("openclash", sid, "update_hour", update_hour)
			uci:set("openclash", sid, "type", typ)
			uci:set("openclash", sid, "param", param)
			if order == nil then
				local max_order = -1
				uci:foreach("openclash", "config_overwrite", function(s)
					local o = tonumber(s.order)
					if o and o > max_order then max_order = o end
				end)
				order = tostring(max_order + 1)
			else
				order = tostring(order)
			end
			uci:set("openclash", sid, "order", order)
			uci:set("openclash", sid, "enable", 0)
		end
		uci:commit("openclash")

		if typ == "file" then
			local overwrite_dir = "/etc/openclash/overwrite/"
			local file_path = overwrite_dir .. section_name
			if not fs.access(file_path) then
				fs.writefile(file_path, "")
			end
		elseif typ == "http" then
			local overwrite_dir = "/etc/openclash/overwrite/"
			local file_path = overwrite_dir .. section_name
			if url and url ~= "" then
				local cmd = string.format('curl -sL --connect-timeout 5 -m 15 --retry 2 "%s" -o "%s"', url, file_path)
				local ret = SYS.call(cmd)
				if not fs.access(file_path) then
					fs.writefile(file_path, "")
				end
				if ret ~= 0 or not fs.access(file_path) or fs.stat(file_path).size == 0 then
					HTTP.prepare_content("application/json")
					HTTP.write_json({status="error", message="Download failed"})
					return
				end
			else
				if not fs.access(file_path) then
					fs.writefile(file_path, "")
				end
			end
		end

		HTTP.prepare_content("application/json")
		HTTP.write_json({status="success"})
		return
	else
		HTTP.status(500, "Method Not Allowed")
	end
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
				if stat and stat.type == "regular" then
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
		uci:set("openclash", item.section, "order", tostring(idx - 1))
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
	uci:foreach("openclash", "config_subscribe", function(s)
		if s.name == filename then
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
		if a.name == filename and (not a.hidden or a.hidden ~= "true") then
			if a.secret then data.config_age_secret = a.secret end
			if a.public then data.config_age_public = a.public end
			if a.algo then data.config_age_algo = a.algo end
			return false
		end
		if a.name == filename and a.hidden and a.hidden == "true" then
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
		"-H " .. util.shellquote("Accept: text/plain, */*"),
		"-H " .. util.shellquote("Origin: https://openclash.local"),
		"-H " .. util.shellquote("Sec-Fetch-Mode: cors"),
		"-H " .. util.shellquote("Sec-Fetch-Dest: empty"),
		"-H " .. util.shellquote("User-Agent: OpenClash Subconverter Version Check"),
		util.shellquote(version_url),
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
	local age_section_id, age_section_hidden

	HTTP.prepare_content("application/json")

	if not name or name == "" then
		HTTP.write_json({status = "error", message = "Missing name parameter"})
		return
	end

	uci:foreach("openclash", "config_age_secret", function(s)
		if s.name == name then
			age_section_id = s['.name']
			age_section_hidden = s.hidden and s.hidden == "true"
			return false
		end
	end)

	if age_section_hidden then
		HTTP.write_json({status = "error", message = "Cannot modify hidden age configuration"})
		return
	end

	if not age_section_id and (age_secret ~= "" or age_public ~= "" or age_algo ~= "") then
		age_section_id = uci:add("openclash", "config_age_secret")
		if age_section_id then
			uci:set("openclash", age_section_id, "name", name)
		end
	end

	if age_section_id then
		if (age_secret == "" and age_public == "") then
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
	local token = HTTP.formvalue("token")
	if token and token ~= "" then
		uci:set("openclash", "config", "oix_token", token)
	else
		local email = HTTP.formvalue("email")
		local passwd = HTTP.formvalue("passwd")
		if email then uci:set("openclash", "config", "oix_email", email) end
		if passwd then uci:set("openclash", "config", "oix_passwd", passwd) end
	end
	local checkin = HTTP.formvalue("checkin")
	if checkin then uci:set("openclash", "config", "oix_checkin", checkin) end
	local interval = tonumber(HTTP.formvalue("interval"))
	if interval then
		if interval < 1 then interval = 1 end
		if interval > 720 then interval = 720 end
		uci:set("openclash", "config", "oix_checkin_interval", tostring(interval))
	end
	local multiple = tonumber(HTTP.formvalue("multiple"))
	if multiple then
		if multiple < 1 then multiple = 1 end
		if multiple > 100 then multiple = 100 end
		uci:set("openclash", "config", "oix_checkin_multiple", tostring(multiple))
	end
	local show_info_page = HTTP.formvalue("show_info_page")
	if show_info_page then uci:set("openclash", "config", "oix_show_info_page", show_info_page) end
	local default_params = HTTP.formvalue("default_params")
	if default_params then uci:set("openclash", "config", "oix_default_params", default_params) end
	uci:commit("openclash")
	HTTP.prepare_content("application/json")
	HTTP.write_json({status = "success"})
end

function oix_params_sync()
	local params = HTTP.formvalue("params") or ""
	if #params > 8192 then
		HTTP.status(400, "Params too long")
		HTTP.write_json({status = "error", msg = "params too long"})
		return
	end

	uci:set("openclash", "config", "oix_params", params)
	uci:commit("openclash")

	if is_running() then
		local dase_val = dase() or ""
		local daip_val = daip()
		local cn_port_val = cn_port()
		local auth_header = ""
		if dase_val and dase_val ~= "" then
			auth_header = string.format('-H "Authorization: Bearer %s"', dase_val)
		end

		if params == "" then
			SYS.exec(string.format('curl -sL -m 3 --retry 2 -H "Content-Type: application/json" %s -XDELETE http://"%s":"%s"/oix/options', auth_header, daip_val, cn_port_val))
		else
			local encoded = params:gsub('"', '\\"'):gsub('\n', '')
			SYS.exec(string.format('curl -sL -m 3 --retry 2 -H "Content-Type: application/json" %s -XPUT -d \'{"params":"%s"}\' http://"%s":"%s"/oix/options', auth_header, encoded, daip_val, cn_port_val))
		end
	end

	HTTP.prepare_content("application/json")
	HTTP.write_json({status = "success"})
end

function oix_params_get()
	local result = {params = "", default_params = ""}
	local home_dir = "/etc/openclash"
	local params_file = home_dir .. "/.oix_params"
	local default_params_file = home_dir .. "/.oix_default_params"

	local uci_params = fs.uci_get_config("config", "oix_params")
	if uci_params and uci_params ~= "" then
		result.params = uci_params
	elseif fs.access(params_file) then
		local content = fs.readfile(params_file)
		if content then
			result.params = content:gsub("%s+", "")
		end
	end

	local uci_default = fs.uci_get_config("config", "oix_default_params")
	if uci_default and uci_default ~= "" then
		result.default_params = uci_default
	elseif fs.access(default_params_file) then
		local content = fs.readfile(default_params_file)
		if content then
			result.default_params = content:gsub("%s+", "")
		end
	end

	HTTP.prepare_content("application/json")
	HTTP.write_json(result)
end

local function fetch_oix_sub(token)
	write_padded('{"stage":"fetching_sub","text":"' .. luci.i18n.translate("Fetching subscription...") .. '"}')
	local get_sub = string.format("curl -sL -H 'Content-Type: application/json' -H 'Authorization: Bearer %s' -X POST https://oix-api.dler.io/api/v1/managed/clash", token)
	local sub_info = SYS.exec(get_sub)
	if sub_info then sub_info = json.parse(sub_info) end
	if sub_info and sub_info.ret == 200 then
		local sub_key = {"openclash"}
		for _,v in ipairs(sub_key) do
			while true do
				local sub_match, sub_convert, sid = false, false, nil
				uci:foreach("openclash", "config_subscribe",
				function(s)
					if s.name == "oixCloud - smart" and s.address == sub_info[v] then
						sub_match = true; return false
					end
					if s.name == "oixCloud - smart" and s.address ~= sub_info[v] then
						sub_convert = true; sid = s['.name']; return false
					end
				end)
				if sub_match then break end
				if sub_convert then uci:set("openclash", sid, "address", sub_info[v])
				elseif sub_info[v] then
					sid = uci:add("openclash", "config_subscribe")
					uci:set("openclash", sid, "name", "oixCloud - smart")
					uci:set("openclash", sid, "address", sub_info[v])
				end
				uci:commit("openclash")
				break
			end
			if sub_info[v] then
				write_padded('{"stage":"downloading_config","text":"' .. luci.i18n.translate("Downloading config...") .. '"}')
				SYS.exec(string.format('curl -sL -m 10 --retry 2 --user-agent "clash" "%s" -o "/etc/openclash/config/oixCloud - smart.yaml" >/dev/null 2>&1', sub_info[v]))
				local core = coremetacv()
				if core ~= "0" and not string.match(core, "oix") then
					write_padded('{"stage":"downloading_core","text":"' .. luci.i18n.translate("Downloading core...") .. '"}')
					SYS.exec("/usr/share/openclash/openclash_core.sh Oix")
				else
					write_padded('{"stage":"restarting","text":"' .. luci.i18n.translate("Restarting...") .. '"}')
					SYS.call("/etc/init.d/openclash restart >/dev/null 2>&1 &")
				end
			end
		end
		return true
	end
	return false
end

function oix_login()
	HTTP.prepare_content("text/plain; charset=utf-8")
	local result, info, token
	local input_token = HTTP.formvalue("token")
	local email = fs.uci_get_config("config", "oix_email")
	local passwd = fs.uci_get_config("config", "oix_passwd")
	if input_token and input_token ~= "" then
		-- Token direct login mode
		write_padded('{"stage":"saving_token","text":"' .. luci.i18n.translate("Saving token...") .. '"}')
		token = input_token
		if fetch_oix_sub(token) then
			uci:set("openclash", "config", "oix_token", input_token)
			uci:commit("openclash")
			write_padded('{"stage":"done","result":200}')
		else
			write_padded('{"stage":"error","result":' .. json.stringify(luci.i18n.translate("invalid token")) .. '}')
		end
	else
		-- Email/password login mode
		token = fs.uci_get_config("config", "oix_token")
		if email and passwd then
			write_padded('{"stage":"logging_in","text":"' .. luci.i18n.translate("Logging in...") .. '"}')
			info = SYS.exec(string.format("curl -sL -H 'Content-Type: application/json' -H 'User-Agent: OpenClash for oixCloud' -d '{\"email\":\"%s\", \"passwd\":\"%s\", \"token_expire\":\"365\" }' -X POST https://oix-api.dler.io/api/v1/login", email, passwd))
			if info then
				info = json.parse(info)
			end
			if info and info.ret == 200 then
				if token and token ~= "" then
					oix_logout(token)
				end
				token = info.data.token
				uci:set("openclash", "config", "oix_token", token)
				uci:commit("openclash")
				result = info.ret
				fetch_oix_sub(token)
				write_padded('{"stage":"done","result":200}')
			else
				uci:delete("openclash", "config", "oix_token")
				uci:commit("openclash")
				fs.unlink("/tmp/oix_checkin")
				fs.unlink("/tmp/oix_info")
				if info and info.msg then
					result = info.msg
				else
					result = luci.i18n.translate("login failed")
				end
				write_padded('{"stage":"error","result":' .. json.stringify(result) .. '}')
			end
		else
			uci:delete("openclash", "config", "oix_token")
			uci:commit("openclash")
			fs.unlink("/tmp/oix_checkin")
			fs.unlink("/tmp/oix_info")
			result = luci.i18n.translate("email or passwd is wrong")
			write_padded('{"stage":"error","result":' .. json.stringify(result) .. '}')
		end
	end
end

function oix_logout(oldtoken)
	local info, result, token
	local is_token_login = false
	if not oldtoken then
		token = fs.uci_get_config("config", "oix_token")
		is_token_login = not fs.uci_get_config("config", "oix_email")
	else
		token = oldtoken
	end
	if token then
		if is_token_login then
			uci:delete("openclash", "config", "oix_token")
			uci:delete("openclash", "config", "oix_checkin")
			uci:delete("openclash", "config", "oix_checkin_interval")
			uci:delete("openclash", "config", "oix_checkin_multiple")
			uci:delete("openclash", "config", "oix_params")
			uci:delete("openclash", "config", "oix_default_params")
			uci:delete("openclash", "config", "oix_show_info_page")
			uci:commit("openclash")
			fs.unlink("/tmp/oix_checkin")
			fs.unlink("/tmp/oix_info")
			result = 200
		else
			info = SYS.exec(string.format("curl -sL -H 'Content-Type: application/json' -H 'Authorization: Bearer %s' -X POST https://oix-api.dler.io/api/v1/logout", token))
			if info then
				info = json.parse(info)
			end
			if info and info.ret == 200 then
				uci:delete("openclash", "config", "oix_token")
				if not oldtoken then
					uci:delete("openclash", "config", "oix_email")
					uci:delete("openclash", "config", "oix_passwd")
					uci:delete("openclash", "config", "oix_checkin")
					uci:delete("openclash", "config", "oix_checkin_interval")
					uci:delete("openclash", "config", "oix_checkin_multiple")
					uci:delete("openclash", "config", "oix_params")
					uci:delete("openclash", "config", "oix_default_params")
					uci:delete("openclash", "config", "oix_show_info_page")
				end
				uci:commit("openclash")
				fs.unlink("/tmp/oix_checkin")
				fs.unlink("/tmp/oix_info")
				result = info.ret
			else
				if info and info.msg then
					result = info.msg
				else
					result = "logout failed"
				end
			end
		end
	else
		result = "logout failed"
	end
	if not oldtoken then
		HTTP.prepare_content("application/json")
		HTTP.write_json({result = result})
	end
end

function oix_info()
	local info, path, get_info
	local result = "error"
	local token = fs.uci_get_config("config", "oix_token")
	path = "/tmp/oix_info"
	if token then
		get_info = string.format("curl -sL -H 'Content-Type: application/json' -H 'Authorization: Bearer %s' -X POST https://oix-api.dler.io/api/v1/information -o %s", token, path)
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
	HTTP.write_json({result = result})
end

function oix_checkin()
	local info, result
	local path = "/tmp/oix_checkin"
	local token = fs.uci_get_config("config", "oix_token")
	local multiple = fs.uci_get_config("config", "oix_checkin_multiple") or 1
	if token then
		info = SYS.exec(string.format("curl -sL -H 'Content-Type: application/json' -H 'Authorization: Bearer %s' -d '{\"multiple\":\"%s\"}' -X POST https://oix-api.dler.io/api/v1/checkin", token, multiple))
		if info then
			info = json.parse(info)
		end
		if info and info.ret == 200 then
			fs.unlink("/tmp/oix_info")
			fs.writefile(path, info)
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
