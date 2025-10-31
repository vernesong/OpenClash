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
	entry({"admin", "services", "openclash", "status"},call("action_status")).leaf=true
	entry({"admin", "services", "openclash", "startlog"},call("action_start")).leaf=true
	entry({"admin", "services", "openclash", "refresh_log"},call("action_refresh_log"))
	entry({"admin", "services", "openclash", "del_log"},call("action_del_log"))
	entry({"admin", "services", "openclash", "del_start_log"},call("action_del_start_log"))
	entry({"admin", "services", "openclash", "close_all_connection"},call("action_close_all_connection"))
	entry({"admin", "services", "openclash", "reload_firewall"},call("action_reload_firewall"))
	entry({"admin", "services", "openclash", "lastversion"},call("action_lastversion"))
	entry({"admin", "services", "openclash", "save_corever_branch"},call("action_save_corever_branch"))
	entry({"admin", "services", "openclash", "update"},call("action_update"))
	entry({"admin", "services", "openclash", "get_last_version"},call("action_get_last_version"))
	entry({"admin", "services", "openclash", "update_info"},call("action_update_info"))
	entry({"admin", "services", "openclash", "update_ma"},call("action_update_ma"))
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
	entry({"admin", "services", "openclash", "dler_info"}, call("action_dler_info"))
	entry({"admin", "services", "openclash", "dler_checkin"}, call("action_dler_checkin"))
	entry({"admin", "services", "openclash", "dler_logout"}, call("action_dler_logout"))
	entry({"admin", "services", "openclash", "dler_login"}, call("action_dler_login"))
	entry({"admin", "services", "openclash", "dler_login_info_save"}, call("action_dler_login_info_save"))
	entry({"admin", "services", "openclash", "sub_info_get"}, call("sub_info_get"))
	entry({"admin", "services", "openclash", "config_name"}, call("action_config_name"))
	entry({"admin", "services", "openclash", "switch_config"}, call("action_switch_config"))
	entry({"admin", "services", "openclash", "toolbar_show"}, call("action_toolbar_show"))
	entry({"admin", "services", "openclash", "toolbar_show_sys"}, call("action_toolbar_show_sys"))
	entry({"admin", "services", "openclash", "diag_connection"}, call("action_diag_connection"))
	entry({"admin", "services", "openclash", "diag_dns"}, call("action_diag_dns"))
	entry({"admin", "services", "openclash", "gen_debug_logs"}, call("action_gen_debug_logs"))
	entry({"admin", "services", "openclash", "log_level"}, call("action_log_level"))
	entry({"admin", "services", "openclash", "switch_log"}, call("action_switch_log"))
	entry({"admin", "services", "openclash", "rule_mode"}, call("action_rule_mode"))
	entry({"admin", "services", "openclash", "switch_rule_mode"}, call("action_switch_rule_mode"))
	entry({"admin", "services", "openclash", "switch_run_mode"}, call("action_switch_run_mode"))
	entry({"admin", "services", "openclash", "dashboard_type"}, call("action_dashboard_type"))
	entry({"admin", "services", "openclash", "switch_dashboard"}, call("action_switch_dashboard"))
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
	entry({"admin", "services", "openclash", "servers"},cbi("openclash/servers"),_("Onekey Create"), 50).leaf = true
	entry({"admin", "services", "openclash", "other-rules-edit"},cbi("openclash/other-rules-edit"), nil).leaf = true
	entry({"admin", "services", "openclash", "custom-dns-edit"},cbi("openclash/custom-dns-edit"), nil).leaf = true
	entry({"admin", "services", "openclash", "other-file-edit"},cbi("openclash/other-file-edit"), nil).leaf = true
	entry({"admin", "services", "openclash", "rule-providers-settings"},cbi("openclash/rule-providers-settings"),_("Rule Providers Append"), 60).leaf = true
	entry({"admin", "services", "openclash", "game-rules-manage"},form("openclash/game-rules-manage"), nil).leaf = true
	entry({"admin", "services", "openclash", "rule-providers-manage"},form("openclash/rule-providers-manage"), nil).leaf = true
	entry({"admin", "services", "openclash", "proxy-provider-file-manage"},form("openclash/proxy-provider-file-manage"), nil).leaf = true
	entry({"admin", "services", "openclash", "rule-providers-file-manage"},form("openclash/rule-providers-file-manage"), nil).leaf = true
	entry({"admin", "services", "openclash", "game-rules-file-manage"},form("openclash/game-rules-file-manage"), nil).leaf = true
	entry({"admin", "services", "openclash", "config-subscribe"},cbi("openclash/config-subscribe"),_("Config Subscribe"), 70).leaf = true
	entry({"admin", "services", "openclash", "config-subscribe-edit"},cbi("openclash/config-subscribe-edit"), nil).leaf = true
	entry({"admin", "services", "openclash", "servers-config"},cbi("openclash/servers-config"), nil).leaf = true
	entry({"admin", "services", "openclash", "groups-config"},cbi("openclash/groups-config"), nil).leaf = true
	entry({"admin", "services", "openclash", "proxy-provider-config"},cbi("openclash/proxy-provider-config"), nil).leaf = true
	entry({"admin", "services", "openclash", "rule-providers-config"},cbi("openclash/rule-providers-config"), nil).leaf = true
	entry({"admin", "services", "openclash", "config"},form("openclash/config"),_("Config Manage"), 80).leaf = true
	entry({"admin", "services", "openclash", "log"},cbi("openclash/log"),_("Server Logs"), 90).leaf = true
	entry({"admin", "services", "openclash", "myip_check"}, call("action_myip_check"))
	entry({"admin", "services", "openclash", "website_check"}, call("action_website_check"))
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
    entry({"admin", "services", "openclash", "upload_overwrite"}, call("action_upload_overwrite"))
    entry({"admin", "services", "openclash", "overwrite_subscribe_info"}, call("action_overwrite_subscribe_info"))
    entry({"admin", "services", "openclash", "overwrite_file_list"}, call("action_overwrite_file_list"))
    entry({"admin", "services", "openclash", "delete_overwrite_file"}, call("delete_overwrite_file"))
end

local fs = require "luci.openclash"
local json = require "luci.jsonc"
local uci = require("luci.model.uci").cursor()
local datatype = require "luci.cbi.datatypes"
local opkg
local device_name = uci:get("system", "@system[0]", "hostname")
local device_arh = luci.sys.exec("uname -m |tr -d '\n'")

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
	return luci.sys.call("pidof clash >/dev/null") == 0
end

local function is_start()
	return process_status("/etc/init.d/openclash")
end

local function cn_port()
    if is_running() then
        local config_path = fs.uci_get_config("config", "config_path")
        if config_path then
            local config_filename = fs.basename(config_path)
            local runtime_config_path = "/etc/openclash/" .. config_filename
            local ruby_result = luci.sys.exec(string.format([[
                ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e "
                begin
                    config = YAML.load_file('%s')
                    if config
                        port = config['external-controller']
                        if port
                            port = port.to_s
                            if port:include?(':')
                                port = port.split(':')[-1]
                            end
                            puts port
                        end
                    end
                end
                " 2>/dev/null || echo "__RUBY_ERROR__"
            ]], runtime_config_path)):gsub("\n", "")
            if ruby_result and ruby_result ~= "" and ruby_result ~= "__RUBY_ERROR__" then
                return ruby_result
            end
        end
    end
    return fs.uci_get_config("config", "cn_port") or "9090"
end

local function mode()
	return fs.uci_get_config("config", "en_mode")
end

local function daip()
	return fs.lanip()
end

local function dase()
    if is_running() then
        local config_path = fs.uci_get_config("config", "config_path")
        if config_path then
            local config_filename = fs.basename(config_path)
            local runtime_config_path = "/etc/openclash/" .. config_filename
            local ruby_result = luci.sys.exec(string.format([[
                ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e "
                begin
                    config = YAML.load_file('%s')
                    if config
                        dase = config['secret']
                        puts \"#{dase}\"
                    end
                end
                " 2>/dev/null || echo "__RUBY_ERROR__"
            ]], runtime_config_path)):gsub("\n", "")
            if ruby_result and ruby_result ~= "" and ruby_result ~= "__RUBY_ERROR__" then
                return ruby_result
            end
        end
    end
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

local function check_lastversion()
	luci.sys.exec("bash /usr/share/openclash/openclash_version.sh 2>/dev/null")
	return luci.sys.exec("sed -n '/^https:/,$p' /tmp/openclash_last_version 2>/dev/null")
end

local function startlog()
	local info = ""
	local line_trans = ""
	if fs.access("/tmp/openclash_start.log") then
		info = luci.sys.exec("sed -n '$p' /tmp/openclash_start.log 2>/dev/null")
		line_trans = info
		if string.len(info) > 0 then
			if not string.find (info, "【") or not string.find (info, "】") then
				line_trans = trans_line_nolabel(info)
   			else
   				line_trans = trans_line(info)
   			end
   		end
	end
	return line_trans
end

local function pkg_type()
	if fs.access("/usr/bin/apk") then
		return "apk"
	else
		return "opkg"
	end
end

local function coremodel()
	if opkg and opkg.info("libc") and opkg.info("libc")["libc"] then
		return opkg.info("libc")["libc"]["Architecture"]
	else
		if pkg_type() == "opkg" then
			return luci.sys.exec("rm -f /var/lock/opkg.lock && opkg status libc 2>/dev/null |grep 'Architecture' |awk -F ': ' '{print $2}' 2>/dev/null")
		else
			return luci.sys.exec("apk list libc 2>/dev/null |awk '{print $2}'")
		end
	end
end

local function check_core()
	if not fs.access(meta_core_path) then
		return "0"
	else
		return "1"
	end
end

local function coremetacv()
    local v = "0"
	if not fs.access(meta_core_path) then
		return v
	else
		v = luci.sys.exec(string.format("%s -v 2>/dev/null |awk -F ' ' '{print $3}' |head -1 |tr -d '\n'", meta_core_path))
        if not v or v == "" then
            return "0"
        end
    end
    return v
end

local function corelv()
	local status = process_status("/usr/share/openclash/clash_version.sh")
    local core_meta_lv = ""
	local core_smart_enable = fs.uci_get_config("config", "smart_enable") or "0"
    if not status then
		if fs.access("/tmp/clash_last_version") and tonumber(os.time() - fs.mtime("/tmp/clash_last_version")) < 1800 then
			if core_smart_enable == "1" then
				core_meta_lv = luci.sys.exec("sed -n 2p /tmp/clash_last_version 2>/dev/null |tr -d '\n'")
			else
        		core_meta_lv = luci.sys.exec("sed -n 1p /tmp/clash_last_version 2>/dev/null |tr -d '\n'")
			end
		else
			action_get_last_version()
			core_meta_lv = "loading..."
		end
	else
		core_meta_lv = "loading..."
	end
	return core_meta_lv
end

local function opcv()
    local v
    local info = opkg and opkg.info("luci-app-openclash")
    if info and info["luci-app-openclash"] and info["luci-app-openclash"]["Version"] and info["luci-app-openclash"]["Installed-Time"] then
        v = info["luci-app-openclash"]["Version"]
    else
        if pkg_type() == "opkg" then
            v = luci.sys.exec("rm -f /var/lock/opkg.lock && opkg status luci-app-openclash 2>/dev/null |grep 'Version' |awk -F 'Version: ' '{print $2}' |tr -d '\n'")
        else
            v = luci.sys.exec("apk list luci-app-openclash 2>/dev/null|grep 'installed' | grep -oE '[0-9]+(\\.[0-9]+)*' | head -1 |tr -d '\n'")
        end
    end
    if v and v ~= "" then
        return "v" .. v
    else
        return "0"
    end
end

local function oplv()
	local status = process_status("/usr/share/openclash/openclash_version.sh")
    local oplv = ""
    if not status then
		if fs.access("/tmp/openclash_last_version") and tonumber(os.time() - fs.mtime("/tmp/openclash_last_version")) < 1800 then
        	oplv = luci.sys.exec("sed -n 1p /tmp/openclash_last_version 2>/dev/null |tr -d '\n'")
		else
			action_get_last_version()
			oplv = "loading..."
		end
	else
		oplv = "loading..."
    end
	return oplv
end

local function opup()
	luci.sys.call("rm -rf /tmp/*_last_version 2>/dev/null && bash /usr/share/openclash/openclash_version.sh >/dev/null 2>&1")
	return luci.sys.call("bash /usr/share/openclash/openclash_update.sh >/dev/null 2>&1 &")
end

local function coreup()
	uci:set("openclash", "config", "enable", "1")
	uci:commit("openclash")
	local type = luci.http.formvalue("core_type")
	luci.sys.call("rm -rf /tmp/*_last_version 2>/dev/null && bash /usr/share/openclash/clash_version.sh >/dev/null 2>&1")
	return luci.sys.call(string.format("/usr/share/openclash/openclash_core.sh '%s' >/dev/null 2>&1 &", type))
end

local function corever()
	return fs.uci_get_config("config", "core_version") or "0"
end

local function release_branch()
	return fs.uci_get_config("config", "release_branch") or "master"
end

local function smart_enable()
	return fs.uci_get_config("config", "smart_enable") or "0"
end

local function save_corever_branch()
	if luci.http.formvalue("core_ver") then
		uci:set("openclash", "config", "core_version", luci.http.formvalue("core_ver"))
	end
	if luci.http.formvalue("release_branch") then
		uci:set("openclash", "config", "release_branch", luci.http.formvalue("release_branch"))
	end
	if luci.http.formvalue("smart_enable") then
		uci:set("openclash", "config", "smart_enable", luci.http.formvalue("smart_enable"))
	end
	uci:commit("openclash")
	return "success"
end

local function upchecktime()
	local corecheck = os.date("%Y-%m-%d %H:%M:%S",fs.mtime("/tmp/clash_last_version"))
	local opcheck
	if not corecheck or corecheck == "" then
    	opcheck = os.date("%Y-%m-%d %H:%M:%S",fs.mtime("/tmp/openclash_last_version"))
    	if not opcheck or opcheck == "" then
        	return "1"
    	else
        	return opcheck
    	end
	else
    	return corecheck
	end
end

function core_download()
	local cdn_url = luci.http.formvalue("url")
	if cdn_url then
		luci.sys.call(string.format("rm -rf /tmp/clash_last_version 2>/dev/null && bash /usr/share/openclash/clash_version.sh '%s' >/dev/null 2>&1", cdn_url))
		luci.sys.call(string.format("bash /usr/share/openclash/openclash_core.sh 'Meta' '%s' >/dev/null 2>&1 &", cdn_url))
	else
		luci.sys.call("rm -rf /tmp/clash_last_version 2>/dev/null && bash /usr/share/openclash/clash_version.sh >/dev/null 2>&1")
		luci.sys.call("bash /usr/share/openclash/openclash_core.sh 'Meta' >/dev/null 2>&1 &")
	end

end

function download_rule()
	local filename = luci.http.formvalue("filename")
	local state = luci.sys.call(string.format('/usr/share/openclash/openclash_download_rule_list.sh "%s" >/dev/null 2>&1',filename))
	return state
end

function action_flush_dns_cache()
	local state = 0
	if is_running() then
		local daip = daip()
		local dase = dase() or ""
		local cn_port = cn_port()
		if not daip or not cn_port then return end
		fake_ip_state = luci.sys.exec(string.format('curl -sL -m 3 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XPOST http://"%s":"%s"/cache/fakeip/flush', dase, daip, cn_port))
        dns_state = luci.sys.exec(string.format('curl -sL -m 3 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XPOST http://"%s":"%s"/cache/dns/flush', dase, daip, cn_port))
    end
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		flush_status = dns_state;
	})
end

function action_flush_smart_cache()
	local state = 0
	if is_running() then
		local daip = daip()
		local dase = dase() or ""
		local cn_port = cn_port()
		if not daip or not cn_port then return end
        flush_state = luci.sys.exec(string.format('curl -sL -m 3 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XPOST http://"%s":"%s"/cache/smart/flush', dase, daip, cn_port))
    end
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		flush_status = flush_state;
	})
end

function action_update_config()
	-- filename or config_file is basename
    local filename = luci.http.formvalue("filename")
    local config_file = luci.http.formvalue("config_file")
    
    if not filename and config_file then
        filename = config_file
    end
    
    luci.http.prepare_content("application/json")

    if not filename then
        luci.http.write_json({
            status = "error",
            message = "Config file not found"
        })
        return
    end
    
    local update_result = luci.sys.call(string.format("/usr/share/openclash/openclash.sh '%s' >/dev/null 2>&1", filename))
    
    if update_result == 0 then
        luci.http.write_json({
            status = "success",
            message = "Config update started successfully",
            filename = filename
        })
    else
        luci.http.write_json({
            status = "error",
            message = "Failed to start config update"
        })
    end
end

function action_restore_config()
	uci:set("openclash", "config", "enable", "0")
	uci:commit("openclash")
    luci.sys.call("mkdir -p /etc/openclash/custom >/dev/null 2>&1")
    luci.sys.call("mkdir -p /etc/openclash/overwrite >/dev/null 2>&1")
	luci.sys.call("/etc/init.d/openclash stop >/dev/null 2>&1")
	luci.sys.call("cp /usr/share/openclash/backup/openclash /etc/config/openclash >/dev/null 2>&1 &")
	luci.sys.call("cp /usr/share/openclash/backup/openclash_custom* /etc/openclash/custom/ >/dev/null 2>&1 &")
	luci.sys.call("cp /usr/share/openclash/backup/openclash_force_sniffing* /etc/openclash/custom/ >/dev/null 2>&1 &")
	luci.sys.call("cp /usr/share/openclash/backup/openclash_sniffing* /etc/openclash/custom/ >/dev/null 2>&1 &")
	luci.sys.call("cp /usr/share/openclash/backup/china_ip_route.ipset /etc/openclash/china_ip_route.ipset >/dev/null 2>&1 &")
	luci.sys.call("cp /usr/share/openclash/backup/china_ip6_route.ipset /etc/openclash/china_ip6_route.ipset >/dev/null 2>&1 &")
    luci.sys.call("cp /usr/share/openclash/backup/overwrite/default /etc/openclash/overwrite/default >/dev/null 2>&1 &")
	luci.sys.call("rm -rf /etc/openclash/history/* >/dev/null 2>&1 &")
end

function action_remove_all_core()
	luci.sys.call("rm -rf /etc/openclash/core/* >/dev/null 2>&1")
end

function action_one_key_update()
	local cdn_url = luci.http.formvalue("url")
	if cdn_url then
		return luci.sys.call(string.format("rm -rf /tmp/*_last_version 2>/dev/null && bash /usr/share/openclash/openclash_update.sh 'one_key_update' '%s' >/dev/null 2>&1 &", cdn_url))
	else
		return luci.sys.call("rm -rf /tmp/*_last_version 2>/dev/null && bash /usr/share/openclash/openclash_update.sh 'one_key_update' >/dev/null 2>&1 &")
	end
end

local function dler_login_info_save()
	uci:set("openclash", "config", "dler_email", luci.http.formvalue("email"))
	uci:set("openclash", "config", "dler_passwd", luci.http.formvalue("passwd"))
	uci:set("openclash", "config", "dler_checkin", luci.http.formvalue("checkin"))
	uci:set("openclash", "config", "dler_checkin_interval", luci.http.formvalue("interval"))
	if tonumber(luci.http.formvalue("multiple")) > 100 then
		uci:set("openclash", "config", "dler_checkin_multiple", "100")
	elseif tonumber(luci.http.formvalue("multiple")) < 1 or not tonumber(luci.http.formvalue("multiple")) then
		uci:set("openclash", "config", "dler_checkin_multiple", "1")
	else
		uci:set("openclash", "config", "dler_checkin_multiple", luci.http.formvalue("multiple"))
	end
	uci:commit("openclash")
	return "success"
end

local function dler_login()
	local info, token, get_sub, sub_info, sub_key, sub_match, sub_convert, sid
	local sub_path = "/tmp/dler_sub"
	local email = fs.uci_get_config("config", "dler_email")
	local passwd = fs.uci_get_config("config", "dler_passwd")
	if email and passwd then
		info = luci.sys.exec(string.format("curl -sL -H 'Content-Type: application/json' -d '{\"email\":\"%s\", \"passwd\":\"%s\", \"token_expire\":\"365\" }' -X POST https://dler.cloud/api/v1/login", email, passwd))
		if info then
			info = json.parse(info)
		end
		if info and info.ret == 200 then
			token = info.data.token
			uci:set("openclash", "config", "dler_token", token)
			uci:commit("openclash")
			get_sub = string.format("curl -sL -H 'Content-Type: application/json' -d '{\"access_token\":\"%s\"}' -X POST https://dler.cloud/api/v1/managed/clash -o %s", token, sub_path)
			luci.sys.exec(get_sub)
			sub_info = fs.readfile(sub_path)
			if sub_info then
				sub_info = json.parse(sub_info)
			end
			if sub_info and sub_info.ret == 200 then
				sub_key = {"smart","ss","vmess","trojan"}
				for _,v in ipairs(sub_key) do
					while true do
						sub_match = false
						sub_convert = false
						uci:foreach("openclash", "config_subscribe",
						function(s)
							if s.name == "Dler Cloud - " .. v and s.address == sub_info[v] then
								sub_match = true
							end
							if s.name == "Dler Cloud - " .. v and s.address ~= sub_info[v] then
								sub_convert = true
								sid = s['.name']
							end
						end)
						if sub_match then break end
						if sub_convert then
							uci:set("openclash", sid, "address", sub_info[v])
						else
							sid = uci:add("openclash", "config_subscribe")
							uci:set("openclash", sid, "name", "Dler Cloud - " .. v)
							uci:set("openclash", sid, "address", sub_info[v])
						end
						uci:commit("openclash")
						break
					end
					luci.sys.exec(string.format('curl -sL -m 3 --retry 2 --user-agent "clash" "%s" -o "/etc/openclash/config/Dler Cloud - %s.yaml" >/dev/null 2>&1', sub_info[v], v))
				end
			end
			return info.ret
		else
			uci:delete("openclash", "config", "dler_token")
			uci:commit("openclash")
			fs.unlink(sub_path)
			fs.unlink("/tmp/dler_checkin")
			fs.unlink("/tmp/dler_info")
			if info and info.msg then
				return info.msg
			else
				return "login faild"
			end
		end
	else
		uci:delete("openclash", "config", "dler_token")
		uci:commit("openclash")
		fs.unlink(sub_path)
		fs.unlink("/tmp/dler_checkin")
		fs.unlink("/tmp/dler_info")
		return "email or passwd is wrong"
	end
end

local function dler_logout()
	local info, token
	local token = fs.uci_get_config("config", "dler_token")
	if token then
		info = luci.sys.exec(string.format("curl -sL -H 'Content-Type: application/json' -d '{\"access_token\":\"%s\"}' -X POST https://dler.cloud/api/v1/logout", token))
		if info then
			info = json.parse(info)
		end
		if info and info.ret == 200 then
			uci:delete("openclash", "config", "dler_token")
			uci:delete("openclash", "config", "dler_checkin")
			uci:delete("openclash", "config", "dler_checkin_interval")
			uci:delete("openclash", "config", "dler_checkin_multiple")
			uci:commit("openclash")
			fs.unlink("/tmp/dler_sub")
			fs.unlink("/tmp/dler_checkin")
			fs.unlink("/tmp/dler_info")
			return info.ret
		else
			if info and info.msg then
				return info.msg
			else
				return "logout faild"
			end
		end
	else
		return "logout faild"
	end
end

local function dler_info()
	local info, path, get_info
	local token = fs.uci_get_config("config", "dler_token")
	path = "/tmp/dler_info"
	if token then
		get_info = string.format("curl -sL -H 'Content-Type: application/json' -d '{\"access_token\":\"%s\"}' -X POST https://dler.cloud/api/v1/information -o %s", token, path)
		if not fs.access(path) then
			luci.sys.exec(get_info)
		else
			if fs.readfile(path) == "" or not fs.readfile(path) then
				luci.sys.exec(get_info)
			else
				if (os.time() - fs.mtime(path) > 900) then
					luci.sys.exec(get_info)
				end
			end
		end
		info = fs.readfile(path)
		if info then
			info = json.parse(info)
		end
		if info and info.ret == 200 and info.data then
			return info.data
		elseif info and info.msg and info.msg ~= "api error, ignore" then
			luci.sys.exec(string.format("echo -e %s Dler Cloud Account Login Failed, The Error Info is【%s】 >> /tmp/openclash.log", os.date("%Y-%m-%d %H:%M:%S"), info.msg))
			info.msg = "api error, ignore"
			fs.writefile(path, json.stringify(info))
		elseif info and info.msg and info.msg == "api error, ignore" then
			return "error"
		else
			fs.unlink(path)
			luci.sys.exec(string.format("echo -e %s Dler Cloud Account Login Failed! Please Check And Try Again... >> /tmp/openclash.log", os.date("%Y-%m-%d %H:%M:%S")))
		end
		return "error"
	else
		return "error"
	end
end

local function dler_checkin()
	local info
	local path = "/tmp/dler_checkin"
	local token = fs.uci_get_config("config", "dler_token")
	local multiple = fs.uci_get_config("config", "dler_checkin_multiple") or 1
	if token then
		info = luci.sys.exec(string.format("curl -sL -H 'Content-Type: application/json' -d '{\"access_token\":\"%s\", \"multiple\":\"%s\"}' -X POST https://dler.cloud/api/v1/checkin", token, multiple))
		if info then
			info = json.parse(info)
		end
		if info and info.ret == 200 then
			fs.unlink("/tmp/dler_info")
			fs.writefile(path, info)
			luci.sys.exec(string.format("echo -e %s Dler Cloud Checkin Successful, Result:【%s】 >> /tmp/openclash.log", os.date("%Y-%m-%d %H:%M:%S"), info.data.checkin))
			return info
		else
			if info and info.msg then
				luci.sys.exec(string.format("echo -e %s Dler Cloud Checkin Failed, Result:【%s】 >> /tmp/openclash.log", os.date("%Y-%m-%d %H:%M:%S"), info.msg))
			else
				luci.sys.exec(string.format("echo -e %s Dler Cloud Checkin Failed! Please Check And Try Again... >> /tmp/openclash.log",os.date("%Y-%m-%d %H:%M:%S")))
			end
			return info
		end
	else
		return "error"
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
	return json.parse(json.stringify(e)) or e
end

local function config_path()
	if fs.uci_get_config("config", "config_path") then
		return string.sub(fs.uci_get_config("config", "config_path"), 23, -1)
	else
		 return ""
	end
end

function action_switch_config()
    local config_file = luci.http.formvalue("config_file")
    local config_name = luci.http.formvalue("config_name")
    
    if not config_file and config_name then
        config_file = "/etc/openclash/config/" .. config_name
    end
    
    if not config_file then
        luci.http.prepare_content("application/json")
        luci.http.write_json({
            status = "error",
            message = "No config file specified"
        })
        return
    end
    
    if not fs.access(config_file) then
        luci.http.prepare_content("application/json")
        luci.http.write_json({
            status = "error",
            message = "Config file does not exist: " .. config_file
        })
        return
    end
    
    uci:set("openclash", "config", "config_path", config_file)
	uci:set("openclash", "config", "enable", "1")
    uci:commit("openclash")

	luci.sys.call("/etc/init.d/openclash restart >/dev/null 2>&1 &")
    
    luci.http.prepare_content("application/json")
    luci.http.write_json({
        status = "success",
        message = "Config file switched successfully",
        config_file = config_file
    })
end

function set_subinfo_url()
	local filename, url, info
	filename = luci.http.formvalue("filename")
	url = luci.http.formvalue("url")
	if not filename then
		info = "Oops: The config file name seems to be incorrect"
	end
	if url ~= "" and not string.find(url, "http") then
		info = "Oops: The url link format seems to be incorrect"
	end
	if not info then
		uci:foreach("openclash", "subscribe_info",
			function(s)
				if s.name == filename then
					if url == "" then
						uci:delete("openclash", s[".name"])
						uci:commit("openclash")
						info = "Delete success"
					else
						uci:set("openclash", s[".name"], "url", url)
						uci:commit("openclash")
						info = "Success"
					end
				end
			end
		)
		if not info then
			if url == "" then
				info = "Delete success"
			else
				uci:section("openclash", "subscribe_info", nil, {name = filename, url = url})
				uci:commit("openclash")
				info = "Success"
			end
		end
	end
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		info = info;
	})
end

function sub_info_get()
	local sub_ua, filepath, filename, sub_url, sub_info, info, upload, download, total, expire, http_code, len, percent, day_left, day_expire, surplus, used
	local info_tb = {}
	filename = luci.http.formvalue("filename")
	sub_info = ""
	sub_ua = "Clash"
	uci:foreach("openclash", "config_subscribe",
		function(s)
			if s.name == filename and s.sub_ua then
				sub_ua = s.sub_ua
			end
		end
	)
	if filename and not is_start() then
		uci:foreach("openclash", "subscribe_info",
			function(s)
				if s.name == filename and s.url and string.find(s.url, "http") then
					string.gsub(s.url, '[^\n]+', function(w) table.insert(info_tb, w) end)
					sub_url = info_tb[1]
				end
			end
		)
		if not sub_url then
			uci:foreach("openclash", "config_subscribe",
				function(s)
					if s.name == filename and s.address and string.find(s.address, "http") then
						string.gsub(s.address, '[^\n]+', function(w) table.insert(info_tb, w) end)
						sub_url = info_tb[1]
					end
				end
			)
		end
		if not sub_url then
			sub_info = "No Sub Info Found"
		else
			info = luci.sys.exec(string.format("curl -sLI -X GET -m 10 -w 'http_code='%%{http_code} -H 'User-Agent: %s' '%s'", sub_ua, sub_url))
			if not info or tonumber(string.sub(string.match(info, "http_code=%d+"), 11, -1)) ~= 200 then
				info = luci.sys.exec(string.format("curl -sLI -X GET -m 10 -w 'http_code='%%{http_code} -H 'User-Agent: Quantumultx' '%s'", sub_url))
			end
			if info then
				http_code=string.sub(string.match(info, "http_code=%d+"), 11, -1)
				if tonumber(http_code) == 200 then
					info = string.lower(info)
					if string.find(info, "subscription%-userinfo") then
						info = luci.sys.exec("echo '%s' |grep 'subscription-userinfo'" %info)
						upload = string.sub(string.match(info, "upload=%d+"), 8, -1) or nil
						download = string.sub(string.match(info, "download=%d+"), 10, -1) or nil
						total = tonumber(string.format("%.1f",string.sub(string.match(info, "total=%d+"), 7, -1))) or nil
						used = tonumber(string.format("%.1f",(upload + download))) or nil
						if string.match(info, "expire=%d+") then
							day_expire = tonumber(string.sub(string.match(info, "expire=%d+"), 8, -1)) or nil
						end

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
						if total and total > 0 then
							total = fs.filesize(total)
						elseif total and total == 0.0 then
							total = "∞"
						else
							total = "null"
						end
						used = fs.filesize(used)
						sub_info = "Successful"
					else
						sub_info = "No Sub Info Found"
					end
				end
			end
		end
	end
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		http_code = http_code,
		sub_info = sub_info,
		surplus = surplus,
		used = used,
		total = total,
		percent = percent,
		day_left = day_left,
		expire = expire,
		get_time = os.time();
	})
end

function action_rule_mode()
	local mode, info
	if is_running() then
		local daip = daip()
		local dase = dase() or ""
		local cn_port = cn_port()
		if not daip or not cn_port then return end
		info = json.parse(luci.sys.exec(string.format('curl -sL -m 3 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XGET http://"%s":"%s"/configs', dase, daip, cn_port)))
		if info then
			mode = info["mode"]
		else
			mode = fs.uci_get_config("config", "proxy_mode") or "rule"
		end
    else
        mode = fs.uci_get_config("config", "proxy_mode") or "rule"
	end
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		mode = mode;
	})
end

function action_switch_rule_mode()
	local mode, info
    local daip = daip()
    local dase = dase() or ""
    local cn_port = cn_port()
    mode = luci.http.formvalue("rule_mode")

    if not mode then
        luci.http.status(400, "Missing parameters")
        return
    end

    if is_running() then
		if not daip or not cn_port then luci.http.status(500, "Switch Faild") return end
		info = luci.sys.exec(string.format('curl -sL -m 3 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XPATCH http://"%s":"%s"/configs -d \'{\"mode\": \"%s\"}\'', dase, daip, cn_port, mode))
		if info ~= "" then
			luci.http.status(500, "Switch Faild")
		end
        luci.http.prepare_content("application/json")
        luci.http.write_json({
            info = info;
        })
    end
    uci:set("openclash", "config", "proxy_mode", mode)
    uci:set("openclash", "@overwrite[0]", "proxy_mode", mode)
    uci:commit("openclash")
end

function action_get_run_mode()
	if mode() then
		luci.http.prepare_content("application/json")
		luci.http.write_json({
			mode = mode();
		})
	else
		luci.http.status(500, "Get Faild")
		return
	end
end

function action_switch_run_mode()
	local mode, operation_mode
    mode = luci.http.formvalue("run_mode")
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
		luci.sys.exec("/etc/init.d/openclash restart >/dev/null 2>&1 &")
	end
end

function action_log_level()
	local level, info
	if is_running() then
		local daip = daip()
		local dase = dase() or ""
		local cn_port = cn_port()
		if not daip or not cn_port then return end
		info = json.parse(luci.sys.exec(string.format('curl -sL -m 3 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XGET http://"%s":"%s"/configs', dase, daip, cn_port)))
		if info then
			level = info["log-level"]
		else
			level = fs.uci_get_config("config", "log_level") or "info"
		end
	else
		level = fs.uci_get_config("config", "log_level") or "info"
	end
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		log_level = level;
	})
end

function action_switch_log()
	local level, info
	if is_running() then
		local daip = daip()
		local dase = dase() or ""
		local cn_port = cn_port()
		level = luci.http.formvalue("log_level")
		if not daip or not cn_port then luci.http.status(500, "Switch Faild") return end
		info = luci.sys.exec(string.format('curl -sL -m 3 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XPATCH http://"%s":"%s"/configs -d \'{\"log-level\": \"%s\"}\'', dase, daip, cn_port, level))
		if info ~= "" then
			luci.http.status(500, "Switch Faild")
		end
	else
		luci.http.status(500, "Switch Faild")
	end
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		info = info;
	})
end

local function s(e)
local t=0
local a={' B/S',' KB/S',' MB/S',' GB/S',' TB/S',' PB/S'}
if (e<=1024) then
	return e..a[1]
else
repeat
e=e/1024
t=t+1
until(e<=1024)
return string.format("%.1f",e)..a[t]
end
end

function action_toolbar_show_sys()
    local cpu = "0"
    local load_avg = "0"
    local cpu_count = luci.sys.exec("grep -c ^processor /proc/cpuinfo 2>/dev/null"):gsub("\n", "") or 1
    
    local pid = luci.sys.exec("pgrep -f '^[^ ]*clash' | head -1 | tr -d '\n' 2>/dev/null")
    
    if pid and pid ~= "" then
        cpu = luci.sys.exec(string.format([[
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

        load_avg = luci.sys.exec("awk '{print $2; exit}' /proc/loadavg 2>/dev/null"):gsub("\n", "") or "0"
        
        if not string.match(load_avg, "^[0-9]*%.?[0-9]*$") then
            load_avg = "0"
        end
    end
    
    luci.http.prepare_content("application/json")
    luci.http.write_json({
        cpu = cpu,
        load_avg = tostring(math.floor(tonumber(load_avg) / tonumber(cpu_count) * 100));
    })
end

function action_toolbar_show()
    local pid = luci.sys.exec("pgrep -f '^[^ ]*clash' | head -1 | tr -d '\n' 2>/dev/null")
    local traffic, connections, connection, up, down, up_total, down_total, mem, cpu, load_avg, cpu_count
    if pid and pid ~= "" then
        local daip = daip()
        local dase = dase() or ""
        local cn_port = cn_port()
        if not daip or not cn_port then return end
        
        traffic = json.parse(luci.sys.exec(string.format('curl -sL -m 3 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XGET http://"%s":"%s"/traffic', dase, daip, cn_port)))
        connections = json.parse(luci.sys.exec(string.format('curl -sL -m 3 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XGET http://"%s":"%s"/connections', dase, daip, cn_port)))
        
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
        
        mem = tonumber(luci.sys.exec(string.format("cat /proc/%s/status 2>/dev/null |grep -w VmRSS |awk '{print $2}'", pid)))
        cpu = luci.sys.exec(string.format([[
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

        load_avg = luci.sys.exec("awk '{print $2; exit}' /proc/loadavg 2>/dev/null"):gsub("\n", "") or "0"
        cpu_count = luci.sys.exec("grep -c ^processor /proc/cpuinfo 2>/dev/null"):gsub("\n", "") or 1

        if not string.match(load_avg, "^[0-9]*%.?[0-9]*$") then
            load_avg = "0"
        end
    else
        return
    end
    
    luci.http.prepare_content("application/json")
    luci.http.write_json({
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
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		config_name = config_name(),
		config_path = config_path();
	})
end

function action_save_corever_branch()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		save_corever_branch = save_corever_branch();
	})
end

function action_dler_login_info_save()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		dler_login_info_save = dler_login_info_save();
	})
end

function action_dler_info()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		dler_info = dler_info();
	})
end

function action_dler_checkin()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		dler_checkin = dler_checkin();
	})
end

function action_dler_logout()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		dler_logout = dler_logout();
	})
end

function action_dler_login()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		dler_login = dler_login();
	})
end

function action_one_key_update_check()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		corever = corever();
	})
end

function action_dashboard_type()
	local dashboard_type = fs.uci_get_config("config", "dashboard_type") or "Official"
	local yacd_type = fs.uci_get_config("config", "yacd_type") or "Official"
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		dashboard_type = dashboard_type,
		yacd_type = yacd_type;
	})
end

function action_switch_dashboard()
	local switch_name = luci.http.formvalue("name")
	local switch_type = luci.http.formvalue("type")
	local state = luci.sys.call(string.format('/usr/share/openclash/openclash_download_dashboard.sh "%s" "%s" >/dev/null 2>&1', switch_name, switch_type))
	if switch_name == "Dashboard" and tonumber(state) == 1 then
		if switch_type == "Official" then
			uci:set("openclash", "config", "dashboard_type", "Official")
			uci:commit("openclash")
		else
			uci:set("openclash", "config", "dashboard_type", "Meta")
			uci:commit("openclash")
		end
	elseif switch_name == "Yacd" and tonumber(state) == 1 then
		if switch_type == "Official" then
			uci:set("openclash", "config", "yacd_type", "Official")
			uci:commit("openclash")
		else
			uci:set("openclash", "config", "yacd_type", "Meta")
			uci:commit("openclash")
		end
	end
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		download_state = state;
	})
end

function action_op_mode()
	local op_mode = fs.uci_get_config("config", "operation_mode")
	luci.http.prepare_content("application/json")
	luci.http.write_json({
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
	luci.http.prepare_content("application/json")
	luci.http.write_json({
	    switch_mode = switch_mode;
	})
end

function action_status()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		clash = is_running(),
		daip = daip(),
		dase = dase(),
		db_foward_port = db_foward_port(),
		db_foward_domain = db_foward_domain(),
		db_forward_ssl = db_foward_ssl(),
		cn_port = cn_port(),
		core_type = fs.uci_get_config("config", "core_type") or "Meta";
	})
end

function action_lastversion()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		lastversion = check_lastversion();
	})
end

function action_start()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		startlog = startlog();
	})
end

function action_get_last_version()
    if not process_status("/usr/share/openclash/clash_version.sh") then
        luci.sys.call("bash /usr/share/openclash/clash_version.sh &")
    end
    if not process_status("/usr/share/openclash/openclash_version.sh") then
        luci.sys.call("bash /usr/share/openclash/openclash_version.sh &")
    end
end

function action_update()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		coremodel = coremodel(),
		coremetacv = coremetacv(),
		corelv = corelv(),
		opcv = opcv(),
		oplv = oplv(),
		upchecktime = upchecktime();
	})
end

function action_update_info()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
        corever = corever(),
        release_branch = release_branch(),
        smart_enable = smart_enable();
	})
end

function action_update_ma()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
        oplv = oplv(),
        pkg_type = pkg_type(),
        corelv = corelv(),
        corever = corever();
	})
end

function action_opupdate()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
        opup = opup();
	})
end

function action_check_core()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
        core_status = check_core();
	})
end

function action_coreupdate()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
        coreup = coreup();
	})
end

function action_close_all_connection()
	return luci.sys.call("sh /usr/share/openclash/openclash_history_get.sh 'close_all_conection'")
end

function action_reload_firewall()
	return luci.sys.call("/etc/init.d/openclash reload 'manual' >/dev/null 2>&1 &")
end

function action_download_rule()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		rule_download_status = download_rule();
	})
end

function action_refresh_log()
    luci.http.prepare_content("application/json")
    local logfile = "/tmp/openclash.log"
    local log_len = tonumber(luci.http.formvalue("log_len")) or 0
    
    if not fs.access(logfile) then
        luci.http.write_json({
            len = 0,
            update = false,
            core_log = "",
            oc_log = ""
        })
        return
    end
    
    local total_lines = tonumber(luci.sys.exec("wc -l < " .. logfile)) or 0
    
    if total_lines == log_len and log_len > 0 then
        luci.http.write_json({
            len = total_lines,
            update = false,
            core_log = "",
            oc_log = ""
        })
        return
    end
    
    local exclude_pattern = "UDP%-Receive%-Buffer%-Size|^Sec%-Fetch%-Mode|^User%-Agent|^Access%-Control|^Accept|^Origin|^Referer|^Connection|^Pragma|^Cache%-"
    local core_pattern = " DBG | INF |level=| WRN | ERR | FTL "
    local limit = 1000
    local start_line = (log_len > 0 and total_lines > log_len) and (log_len + 1) or 1
    
    local core_cmd = string.format(
        "tail -n +%d '%s' | grep -v -E '%s' | grep -E '%s' | tail -n %d",
        start_line, logfile, exclude_pattern, core_pattern, limit
    )
    local core_raw = luci.sys.exec(core_cmd)
    
    local oc_cmd = string.format(
        "tail -n +%d '%s' | grep -v -E '%s' | grep -v -E '%s' | tail -n %d",
        start_line, logfile, exclude_pattern, core_pattern, limit
    )
    local oc_raw = luci.sys.exec(oc_cmd)
    
    local core_log = ""
    if core_raw and core_raw ~= "" then
        local core_logs = {}
        for line in core_raw:gmatch("[^\n]+") do
            local line_trans = line
			if string.match(string.sub(line, 0, 8), "%d%d:%d%d:%d%d") then
				line_trans = '"'..os.date("%Y-%m-%d", os.time()).. " "..os.date("%H:%M:%S", tonumber(string.sub(line, 0, 8)))..'"'..string.sub(line, 9, -1)
			end
            table.insert(core_logs, line_trans)
        end
        if #core_logs > 0 then
            core_log = table.concat(core_logs, "\n")
        end
    end
    
    local oc_log = ""
    if oc_raw and oc_raw ~= "" then
        local oc_logs = {}
        for line in oc_raw:gmatch("[^\n]+") do
            local line_trans
            if not string.find(line, "【") or not string.find(line, "】") then
                line_trans = trans_line_nolabel(line)
            else
                line_trans = trans_line(line)
            end
            table.insert(oc_logs, line_trans)
        end
        if #oc_logs > 0 then
            oc_log = table.concat(oc_logs, "\n")
        end
    end
    
    luci.http.write_json({
        len = total_lines,
        update = true,
        core_log = core_log,
        oc_log = oc_log
    })
end

function action_del_log()
	luci.sys.exec(": > /tmp/openclash.log")
	return
end

function action_del_start_log()
	luci.sys.exec("echo '##FINISH##' > /tmp/openclash_start.log")
	return
end

function split(str,delimiter)
	local dLen = string.len(delimiter)
	local newDeli = ''
	for i=1,dLen,1 do
		newDeli = newDeli .. "["..string.sub(delimiter,i,i).."]"
	end

	local locaStart,locaEnd = string.find(str,newDeli)
	local arr = {}
	local n = 1
	while locaStart ~= nil
	do
		if locaStart>0 then
			arr[n] = string.sub(str,1,locaStart-1)
			n = n + 1
		end

		str = string.sub(str,locaEnd+1,string.len(str))
		locaStart,locaEnd = string.find(str,newDeli)
	end
	if str ~= nil then
		arr[n] = str
	end
	return arr
end

function action_diag_connection()
	local addr = luci.http.formvalue("addr")
	if addr and (datatype.hostname(addr) or datatype.ipaddr(addr)) then
		local cmd = string.format("/usr/share/openclash/openclash_debug_getcon.lua %s", addr)
		luci.http.prepare_content("text/plain")
		local util = io.popen(cmd)
		if util and util ~= "" then
			while true do
				local ln = util:read("*l")
				if not ln then break end
				luci.http.write(ln)
				luci.http.write("\n")
			end
			util:close()
		end
		return
	end
	luci.http.status(500, "Bad address")
end

function action_diag_dns()
	local addr = luci.http.formvalue("addr")
	if addr and datatype.hostname(addr)then
		local cmd = string.format("/usr/share/openclash/openclash_debug_dns.lua %s", addr)
		luci.http.prepare_content("text/plain")
		local util = io.popen(cmd)
		if util and util ~= "" then
			while true do
				local ln = util:read("*l")
				if not ln then break end
				luci.http.write(ln)
				luci.http.write("\n")
			end
			util:close()
		end
		return
	end
	luci.http.status(500, "Bad address")
end

function action_gen_debug_logs()
	local gen_log = luci.sys.call("/usr/share/openclash/openclash_debug.sh")
	if not gen_log then return end
	local logfile = "/tmp/openclash_debug.log"
	if not fs.access(logfile) then
		return
	end
	luci.http.prepare_content("text/plain; charset=utf-8")
	local file=io.open(logfile, "r+")
	file:seek("set")
	local info = ""
	for line in file:lines() do
		if info ~= "" then
			info = info.."\n"..line
		else
			info = line
		end
	end
	file:close()
	luci.http.write(info)
end

function action_backup()
	local config = luci.sys.call("cp /etc/config/openclash /etc/openclash/openclash >/dev/null 2>&1")
	local reader = ltn12_popen("tar -C '/etc/openclash/' -cz . 2>/dev/null")

	luci.http.header(
		'Content-Disposition', 'attachment; filename="Backup-OpenClash-%s-%s-%s.tar.gz"' %{
			device_name, device_arh, os.date("%Y-%m-%d-%H-%M-%S")
		})

	luci.http.prepare_content("application/x-targz")
	luci.ltn12.pump.all(reader, luci.http.write)
	luci.sys.call("rm -rf /etc/openclash/openclash >/dev/null 2>&1")
end

function action_backup_ex_core()
	local config = luci.sys.call("cp /etc/config/openclash /etc/openclash/openclash >/dev/null 2>&1")
	local reader = ltn12_popen("echo 'core' > /tmp/oc_exclude.txt && tar -C '/etc/openclash/' -X '/tmp/oc_exclude.txt' -cz . 2>/dev/null")

	luci.http.header(
		'Content-Disposition', 'attachment; filename="Backup-OpenClash-Exclude-Cores-%s-%s-%s.tar.gz"' %{
			device_name, device_arh, os.date("%Y-%m-%d-%H-%M-%S")
		})

	luci.http.prepare_content("application/x-targz")
	luci.ltn12.pump.all(reader, luci.http.write)
	luci.sys.call("rm -rf /etc/openclash/openclash >/dev/null 2>&1")
end

function action_backup_only_config()
	local reader = ltn12_popen("tar -C '/etc/openclash' -cz './config' 2>/dev/null")

	luci.http.header(
		'Content-Disposition', 'attachment; filename="Backup-OpenClash-Config-%s-%s-%s.tar.gz"' %{
			device_name, device_arh, os.date("%Y-%m-%d-%H-%M-%S")
		})

	luci.http.prepare_content("application/x-targz")
	luci.ltn12.pump.all(reader, luci.http.write)
end

function action_backup_only_core()
	local reader = ltn12_popen("tar -C '/etc/openclash' -cz './core' 2>/dev/null")

	luci.http.header(
		'Content-Disposition', 'attachment; filename="Backup-OpenClash-Cores-%s-%s-%s.tar.gz"' %{
			device_name, device_arh, os.date("%Y-%m-%d-%H-%M-%S")
		})

	luci.http.prepare_content("application/x-targz")
	luci.ltn12.pump.all(reader, luci.http.write)
end

function action_backup_only_rule()
	local reader = ltn12_popen("tar -C '/etc/openclash' -cz './rule_provider' 2>/dev/null")

	luci.http.header(
		'Content-Disposition', 'attachment; filename="Backup-OpenClash-Only-Rule-Provider-%s-%s-%s.tar.gz"' %{
			device_name, device_arh, os.date("%Y-%m-%d-%H-%M-%S")
		})

	luci.http.prepare_content("application/x-targz")
	luci.ltn12.pump.all(reader, luci.http.write)
end

function action_backup_only_proxy()
	local reader = ltn12_popen("tar -C '/etc/openclash' -cz './proxy_provider' 2>/dev/null")

	luci.http.header(
		'Content-Disposition', 'attachment; filename="Backup-OpenClash-Proxy-Provider-%s-%s-%s.tar.gz"' %{
			device_name, device_arh, os.date("%Y-%m-%d-%H-%M-%S")
		})

	luci.http.prepare_content("application/x-targz")
	luci.ltn12.pump.all(reader, luci.http.write)
end

function ltn12_popen(command)

	local fdi, fdo = nixio.pipe()
	local pid = nixio.fork()

	if pid > 0 then
		fdo:close()
		local close
		return function()
			local buffer = fdi:read(2048)
			local wpid, stat = nixio.waitpid(pid, "nohang")
			if not close and wpid and stat == "exited" then
				close = true
			end

			if buffer and #buffer > 0 then
				return buffer
			elseif close then
				fdi:close()
				return nil
			end
		end
	elseif pid == 0 then
		nixio.dup(fdo, nixio.stdout)
		fdi:close()
		fdo:close()
		nixio.exec("/bin/sh", "-c", command)
	end
end

function create_file()
	local file_name = luci.http.formvalue("filename")
	local file_path = luci.http.formvalue("filepath")..file_name
	fs.writefile(file_path, "")
	if not fs.isfile(file_path) then
		luci.http.status(500, "Create File Faild")
	end
	return
end

function rename_file()
	local new_file_name = luci.http.formvalue("new_file_name")
	local file_path = luci.http.formvalue("file_path")
	local old_file_name = luci.http.formvalue("file_name")
	local old_file_path = file_path .. old_file_name
	local new_file_path = file_path .. new_file_name
	local old_run_file_path = "/etc/openclash/" .. old_file_name
	local new_run_file_path = "/etc/openclash/" .. new_file_name
	local old_backup_file_path = "/etc/openclash/backup/" .. old_file_name
	local new_backup_file_path = "/etc/openclash/backup/" .. new_file_name
	if fs.rename(old_file_path, new_file_path) then
		if file_path == "/etc/openclash/config/" then
			if fs.uci_get_config("config", "config_path") == old_file_path then
				uci:set("openclash", "config", "config_path", new_file_path)
			end
			
			if fs.isfile(old_run_file_path) then
				fs.rename(old_run_file_path, new_run_file_path)
			end
			
			if fs.isfile(old_backup_file_path) then
				fs.rename(old_backup_file_path, new_backup_file_path)
			end
			
			uci:foreach("openclash", "config_subscribe",
			function(s)
				if s.name == fs.filename(old_file_name) and fs.filename(new_file_name) ~= new_file_name then
					uci:set("openclash", s[".name"], "name", fs.filename(new_file_name))
				end
			end)
			
			uci:foreach("openclash", "other_rules",
			function(s)
				if s.config == old_file_name and fs.filename(new_file_name) ~= new_file_name then
					uci:set("openclash", s[".name"], "config", new_file_name)
				end
			end)
			
			uci:foreach("openclash", "groups",
			function(s)
				if s.config == old_file_name and fs.filename(new_file_name) ~= new_file_name then
					uci:set("openclash", s[".name"], "config", new_file_name)
				end
			end)
			
			uci:foreach("openclash", "proxy-provider",
			function(s)
				if s.config == old_file_name and fs.filename(new_file_name) ~= new_file_name then
					uci:set("openclash", s[".name"], "config", new_file_name)
				end
			end)
			
			uci:foreach("openclash", "rule_provider_config",
			function(s)
				if s.config == old_file_name and fs.filename(new_file_name) ~= new_file_name then
					uci:set("openclash", s[".name"], "config", new_file_name)
				end
			end)
			
			uci:foreach("openclash", "servers",
			function(s)
				if s.config == old_file_name and fs.filename(new_file_name) ~= new_file_name then
					uci:set("openclash", s[".name"], "config", new_file_name)
				end
			end)
			
			uci:foreach("openclash", "game_config",
			function(s)
				if s.config == old_file_name and fs.filename(new_file_name) ~= new_file_name then
					uci:set("openclash", s[".name"], "config", new_file_name)
				end
			end)
			
			uci:foreach("openclash", "rule_providers",
			function(s)
				if s.config == old_file_name and fs.filename(new_file_name) ~= new_file_name then
					uci:set("openclash", s[".name"], "config", new_file_name)
				end
			end)
			
			uci:commit("openclash")
		end
		luci.http.status(200, "Rename File Successful")
	else
		luci.http.status(500, "Rename File Faild")
	end
	return
end

function manual_stream_unlock_test()
	local type = luci.http.formvalue("type")
	local cmd = string.format('/usr/share/openclash/openclash_streaming_unlock.lua "%s"', type)
	local line_trans
	luci.http.prepare_content("text/plain; charset=utf-8")
	local util = io.popen(cmd)
	if util and util ~= "" then
		while true do
			local ln = util:read("*l")
			if ln then
				if not string.find (ln, "【") or not string.find (ln, "】") then
					line_trans = trans_line_nolabel(ln)
   				else
   					line_trans = trans_line(ln)
   				end
				luci.http.write(line_trans)
				luci.http.write("\n")
			end
			if not process_status("openclash_streaming_unlock.lua "..type) or not process_status("openclash_streaming_unlock.lua ") then
				break
			end
		end
		util:close()
		return
	end
	luci.http.status(500, "Something Wrong While Testing...")
end

function all_proxies_stream_test()
	local type = luci.http.formvalue("type")
	local cmd = string.format('/usr/share/openclash/openclash_streaming_unlock.lua "%s" "%s"', type, "all")
	local line_trans
	luci.http.prepare_content("text/plain; charset=utf-8")
	local util = io.popen(cmd)
	if util and util ~= "" then
		while true do
			local ln = util:read("*l")
			if ln then
				if not string.find (ln, "【") or not string.find (ln, "】") then
					line_trans = trans_line_nolabel(ln)
   				else
   					line_trans = trans_line(ln)
   				end
				luci.http.write(line_trans)
				luci.http.write("\n")
			end
			if not process_status("openclash_streaming_unlock.lua "..type) or not process_status("openclash_streaming_unlock.lua ") then
				break
			end
		end
		util:close()
		return
	end
	luci.http.status(500, "Something Wrong While Testing...")
end

function trans_line_nolabel(data)
    if data == nil or data == "" then
        return ""
    end
    
    local line_trans = ""
    if string.len(data) >= 19 and string.match(string.sub(data, 0, 19), "%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d") then
        line_trans = string.sub(data, 0, 20)..luci.i18n.translate(string.sub(data, 21, -1))
    else
        line_trans = luci.i18n.translate(data)
    end
    return line_trans
end

function trans_line(data)
    if data == nil or data == "" then
        return ""
    end
    
    local no_trans = {}
    local line_trans = ""
    local a = string.find(data, "【")
    
    if not a then
        if string.len(data) >= 19 and string.match(string.sub(data, 0, 19), "%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d") then
            return string.sub(data, 0, 20) .. luci.i18n.translate(string.sub(data, 21, -1))
        else
            return luci.i18n.translate(data)
        end
    end
    
    local b_pos = string.find(data, "】")
    if not b_pos then
        return luci.i18n.translate(data)
    end
    
    local b = b_pos + 2
    local c = 21
    local d = 0
    local v
    local x
    
    while true do
        table.insert(no_trans, a)
        table.insert(no_trans, b)
        
        local next_a = string.find(data, "【", b+1)
        local next_b = string.find(data, "】", b+1)
        
        if next_a and next_b then
            a = next_a
            b = next_b + 2
        else
            break
        end
    end
    
    if #no_trans % 2 ~= 0 then
        table.remove(no_trans)
    end
    
    for k = 1, #no_trans, 2 do
        x = no_trans[k]
        v = no_trans[k+1]
        
        if x and v then
            if x <= 21 or not string.match(string.sub(data, 0, 19), "%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d") then
                line_trans = line_trans .. luci.i18n.translate(string.sub(data, d, x - 1)) .. string.sub(data, x, v)
                d = v + 1
            elseif v <= string.len(data) then
                line_trans = line_trans .. luci.i18n.translate(string.sub(data, c, x - 1)) .. string.sub(data, x, v)
            end
            c = v + 1
        end
    end
    
    if c > string.len(data) then
        if d == 0 then
            if string.match(string.sub(data, 0, 19), "%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d") then
                line_trans = string.sub(data, 0, 20) .. line_trans
            end
        end
    else
        if d == 0 then
            if string.match(string.sub(data, 0, 19), "%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d") then
                line_trans = string.sub(data, 0, 20) .. line_trans .. luci.i18n.translate(string.sub(data, c, -1))
            end
        else
            line_trans = line_trans .. luci.i18n.translate(string.sub(data, c, -1))
        end
    end
    
    return line_trans
end

function process_status(name)
    local ps_version = luci.sys.exec("ps --version 2>&1 |grep -c procps-ng |tr -d '\n'")
    local cmd
    if ps_version == "1" then
        cmd = string.format("ps -efw |grep '%s' |grep -v grep", name)
    else
        cmd = string.format("ps -w |grep '%s' |grep -v grep", name)
    end
    local result = luci.sys.exec(cmd)
    return result ~= nil and result ~= "" and not result:match("^%s*$")
end

function action_announcement()
	if not fs.access("/tmp/openclash_announcement") or fs.readfile("/tmp/openclash_announcement") == "" or fs.mtime("/tmp/openclash_announcement") < (os.time() - 86400) then
		local HTTP_CODE = luci.sys.exec("curl -SsL -m 5 -w '%{http_code}' -o /tmp/openclash_announcement https://raw.githubusercontent.com/vernesong/OpenClash/dev/announcement 2>/dev/null")
		if HTTP_CODE ~= "200" then
			fs.unlink("/tmp/openclash_announcement")
		end
	end
	local info = luci.sys.exec("cat /tmp/openclash_announcement 2>/dev/null") or ""
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		content = info;
	})
end

function action_myip_check()
    local result = {}
    local random = math.random(100000000)
    
    local services = {
        {
            name = "upaiyun",
            url = string.format("https://pubstatic.b0.upaiyun.com/?_upnode&z=%d", random),
            parser = function(data)
                if data and data ~= "" then
                    local ok, upaiyun_json = pcall(json.parse, data)
                    if ok and upaiyun_json and upaiyun_json.remote_addr then
                        local geo_parts = {}
                        if upaiyun_json.remote_addr_location then
                            if upaiyun_json.remote_addr_location.country and upaiyun_json.remote_addr_location.country ~= "" then
                                table.insert(geo_parts, upaiyun_json.remote_addr_location.country)
                            end
                            if upaiyun_json.remote_addr_location.province and upaiyun_json.remote_addr_location.province ~= "" then
                                table.insert(geo_parts, upaiyun_json.remote_addr_location.province)
                            end
                            if upaiyun_json.remote_addr_location.city and upaiyun_json.remote_addr_location.city ~= "" then
                                table.insert(geo_parts, upaiyun_json.remote_addr_location.city)
                            end
                            if upaiyun_json.remote_addr_location.isp and upaiyun_json.remote_addr_location.isp ~= "" then
                                table.insert(geo_parts, upaiyun_json.remote_addr_location.isp)
                            end
                        end
                        
                        return {
                            ip = upaiyun_json.remote_addr,
                            geo = table.concat(geo_parts, " ")
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
                    local ip = string.match(data, "当前 IP：([%d%.]+)")
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
            url = string.format("https://api-ipv4.ip.sb/geoip?z=%d", random),
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
        
        local pid = nixio.fork()
        
        if pid > 0 then
            fdo:close()
            return {
                pid = pid,
                service_name = service.name,
                fdi = fdi,
                closed = false,
                reader = function()
                    local buffer = fdi:read(4096)
                    if buffer and #buffer > 0 then
                        return buffer
                    else
                        return nil
                    end
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
            
            local cmd = string.format(
                'curl -SsL -m 5 -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" "%s" 2>/dev/null',
                service.url
            )
            nixio.exec("/bin/sh", "-c", cmd)
        else
            if fdi then fdi:close() end
            if fdo then fdo:close() end
            return nil
        end
    end
    
    local queries = {}
    
    for _, service in ipairs(services) do
        local query = create_concurrent_query(service)
        if query then
            queries[service.name] = {
                query = query,
                parser = service.parser,
                data = ""
            }
        end
    end
    
    if next(queries) == nil then
        luci.http.prepare_content("application/json")
        luci.http.write_json({
            error = "Failed to create any queries"
        })
        return
    end
    
    local max_iterations = 140
    local iteration = 0
    local completed = {}
    
    while iteration < max_iterations do
        iteration = iteration + 1
        
        for name, info in pairs(queries) do
            if not completed[name] then
                local wpid, stat = nixio.waitpid(info.query.pid, "nohang")
                local buffer = info.query.reader()
                
                if buffer then
                    info.data = info.data .. buffer
                end
                
                if wpid then
                    pcall(info.query.close)
                    completed[name] = true
                    
                    local parsed_result = info.parser(info.data)
                    if parsed_result then
                        result[name] = parsed_result
                    end
                    
                    queries[name] = nil
                else
                    local still_running = luci.sys.call(string.format("kill -0 %d 2>/dev/null", info.query.pid)) == 0
                    if not still_running then
                        pcall(info.query.close)
                        completed[name] = true
                        
                        local parsed_result = info.parser(info.data)
                        if parsed_result then
                            result[name] = parsed_result
                        end
                        
                        queries[name] = nil
                    end
                end
            end
        end
        
        local remaining_count = 0
        for _ in pairs(queries) do
            remaining_count = remaining_count + 1
        end
        
        if remaining_count == 0 then
            break
        end
        
        nixio.nanosleep(0, 50000000)
    end
    
    for name, info in pairs(queries) do
        if not completed[name] then
            result[name] = { ip = "", geo = "", error = "timeout" }
            pcall(nixio.kill, info.query.pid, nixio.const.SIGTERM)
            pcall(nixio.waitpid, info.query.pid, 0)
            pcall(info.query.close)
        end
    end
    
    if result.ipify and result.ipify.ip then
        local geo_cmd = string.format(
            'curl -sL -m 5 -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" "https://api-ipv4.ip.sb/geoip/%s" 2>/dev/null',
            result.ipify.ip
        )
        local geo_data = luci.sys.exec(geo_cmd)
        
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
                result.ipify.geo = table.concat(geo_parts, " ")
            end
        end
    end
    
    luci.http.prepare_content("application/json")
    luci.http.write_json(result)
end

function action_website_check()
    local domain = luci.http.formvalue("domain")
    local result = {
        success = false,
        response_time = 0,
        error = ""
    }
    
    if not domain then
        result.error = "Missing domain parameter"
        luci.http.prepare_content("application/json")
        luci.http.write_json(result)
        return
    end

    local test_domain = domain
    local test_url

    if test_domain:match("^https?://") then
        test_domain = test_domain:gsub("^https?://([^/]+)/?.*$", "%1")
    end

    if domain == "https://raw.githubusercontent.com/" or test_domain == "raw.githubusercontent.com" then
        test_url = "https://raw.githubusercontent.com/vernesong/OpenClash/dev/img/logo.png"
    else
        test_url = "https://" .. test_domain .. "/favicon.ico"
    end

    local cmd = string.format(
        'curl -sL -m 5 --connect-timeout 3 -w "%%{http_code},%%{time_total},%%{time_connect},%%{time_appconnect}" "%s" -o /dev/null 2>/dev/null',
        test_url
    )
    
    local output = luci.sys.exec(cmd)
    
    if output and output ~= "" then
        local http_code, time_total, time_connect, time_appconnect = output:match("(%d+),([%d%.]+),([%d%.]+),([%d%.]+)")
        
        if http_code and tonumber(http_code) then
            local code = tonumber(http_code)
            local response_time = 0
            if time_appconnect and tonumber(time_appconnect) and tonumber(time_appconnect) > 0 then
                response_time = math.floor(tonumber(time_appconnect) * 1000)
            elseif time_connect and tonumber(time_connect) then
                response_time = math.floor(tonumber(time_connect) * 1000)
            else
                response_time = math.floor((tonumber(time_total) or 0) * 1000)
            end
            
            if code >= 200 and code < 400 then
                result.success = true
                result.response_time = response_time
            elseif code == 403 or code == 404 then
                result.success = true
                result.response_time = response_time
            else
                local fallback_url
                if domain == "https://raw.githubusercontent.com/" or test_domain == "raw.githubusercontent.com" then
                    fallback_url = "https://raw.githubusercontent.com/vernesong/OpenClash/dev/img/logo.png"
                else
                    fallback_url = "https://" .. test_domain .. "/"
                end
                local fallback_cmd = string.format(
                    'curl -sI -m 5 --connect-timeout 3 -w "%%{http_code},%%{time_total},%%{time_appconnect}" "%s" -o /dev/null 2>/dev/null',
                    fallback_url
                )
                local fallback_output = luci.sys.exec(fallback_cmd)
                
                if fallback_output and fallback_output ~= "" then
                    local fb_code, fb_total, fb_appconnect = fallback_output:match("(%d+),([%d%.]+),([%d%.]+)")
                    if fb_code and tonumber(fb_code) then
                        local fb_code_num = tonumber(fb_code)
                        local fb_response_time = 0
                        if fb_appconnect and tonumber(fb_appconnect) and tonumber(fb_appconnect) > 0 then
                            fb_response_time = math.floor(tonumber(fb_appconnect) * 1000)
                        else
                            fb_response_time = math.floor((tonumber(fb_total) or 0) * 1000)
                        end
                        
                        if fb_code_num >= 200 and fb_code_num < 400 then
                            result.success = true
                            result.response_time = fb_response_time
                        elseif fb_code_num == 403 or fb_code_num == 404 then
                            result.success = true
                            result.response_time = fb_response_time
                        else
                            result.success = false
                            result.error = "HTTP " .. fb_code_num
                            result.response_time = fb_response_time
                        end
                    else
                        result.success = false
                        result.error = "Connection failed"
                    end
                else
                    result.success = false
                    result.error = "Connection failed"
                end
            end
        else
            result.success = false
            result.error = "Invalid response"
        end
    else
        result.success = false
        result.error = "No response"
    end
    
    luci.http.prepare_content("application/json")
    luci.http.write_json(result)
end

function action_proxy_info()
    local result = {
        mixed_port = "",
        auth_user = "",
        auth_pass = ""
    }
    
    local function get_info_from_uci()
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
    end

    local config_path = fs.uci_get_config("config", "config_path")
    if config_path then
        local config_filename = fs.basename(config_path)
        local runtime_config_path = "/etc/openclash/" .. config_filename
        
        if fs.access(runtime_config_path) then
            local ruby_result = luci.sys.exec(string.format([[
                ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e "
                begin
                    config = YAML.load_file('%s')
                    mixed_port = ''
                    auth_user = ''
                    auth_pass = ''
                    
                    if config
                        if config['mixed-port']
                            mixed_port = config['mixed-port'].to_s
                        end
                        
                        if config['authentication'] && config['authentication'].is_a?(Array) && !config['authentication'].empty?
                            auth_entry = config['authentication'][0]
                            if auth_entry.is_a?(String) && auth_entry.include?(':')
                                username, password = auth_entry.split(':', 2)
                                auth_user = username || ''
                                auth_pass = password || ''
                            end
                        end
                    end
                    
                    puts \"#{mixed_port},#{auth_user},#{auth_pass}\"
                rescue
                    puts ',,'
                end
                " 2>/dev/null || echo "__RUBY_ERROR__"
            ]], runtime_config_path)):gsub("\n", "")
            
            if ruby_result and ruby_result ~= "" and ruby_result ~= "__RUBY_ERROR__" then
                local runtime_mixed_port, runtime_auth_user, runtime_auth_pass = ruby_result:match("([^,]*),([^,]*),([^,]*)")
                
                if runtime_mixed_port and runtime_mixed_port ~= "" then
                    result.mixed_port = runtime_mixed_port
                else
                    local uci_mixed_port = fs.uci_get_config("config", "mixed_port")
                    if uci_mixed_port and uci_mixed_port ~= "" then
                        result.mixed_port = uci_mixed_port
                    else
                        result.mixed_port = "7893"
                    end
                end
                
                if runtime_auth_user and runtime_auth_user ~= "" and runtime_auth_pass and runtime_auth_pass ~= "" then
                    result.auth_user = runtime_auth_user
                    result.auth_pass = runtime_auth_pass
                else
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
                end
                luci.http.prepare_content("application/json")
                luci.http.write_json(result)
                return
            end
        end
    end

    get_info_from_uci()
    
    luci.http.prepare_content("application/json")
    luci.http.write_json(result)
end

function action_oc_settings()
    local result = {
        meta_sniffer = "0",
        respect_rules = "0",
        oversea = "0",
        stream_unlock = "0"
    }

    local function get_uci_settings()
        local meta_sniffer = fs.uci_get_config("config", "enable_meta_sniffer")
        if meta_sniffer == "1" then
            result.meta_sniffer = "1"
        end
        
        local respect_rules = fs.uci_get_config("config", "enable_respect_rules")
        if respect_rules == "1" then
            result.respect_rules = "1"
        end
    end

    if is_running() then
        local config_path = fs.uci_get_config("config", "config_path")
        if config_path then
            local config_filename = fs.basename(config_path)
            local runtime_config_path = "/etc/openclash/" .. config_filename
            
            if fs.access(runtime_config_path) then
                local ruby_result = luci.sys.exec(string.format([[
                    ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e "
                    begin
                        config = YAML.load_file('%s')
                        if config
                            sniffer_enabled = config['sniffer'] && config['sniffer']['enable'] == true ? '1' : '0'
                            respect_rules_enabled = config['dns'] && config['dns']['respect-rules'] == true ? '1' : '0'
                            puts \"#{sniffer_enabled},#{respect_rules_enabled}\"
                        else
                            puts '0,0'
                        end
                    rescue
                        puts '0,0'
                    end
                    " 2>/dev/null || echo "__RUBY_ERROR__"
                ]], runtime_config_path)):gsub("\n", "")
                
                if ruby_result and ruby_result ~= "" and ruby_result ~= "__RUBY_ERROR__" then
                    local sniffer_result, respect_rules_result = ruby_result:match("(%d),(%d)")
                    if sniffer_result and respect_rules_result then
                        result.meta_sniffer = sniffer_result
                        result.respect_rules = respect_rules_result
                    else
                        get_uci_settings()
                    end
                else
                    get_uci_settings()
                end
            else
                get_uci_settings()
            end
        else
            get_uci_settings()
        end
    else
        get_uci_settings()
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
    
    luci.http.prepare_content("application/json")
    luci.http.write_json(result)
end

function action_switch_oc_setting()
    local setting = luci.http.formvalue("setting")
    local value = luci.http.formvalue("value")
    
    if not setting or not value then
        luci.http.status(400, "Missing parameters")
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
            luci.http.status(500, "No config path found")
            return false
        end
        
        local ruby_result = luci.sys.call(ruby_cmd)
        if ruby_result ~= 0 then
            luci.http.status(500, "Failed to modify config file")
            return false
        end
        
        local daip = daip()
        local dase = dase() or ""
        local cn_port = cn_port()
        if not daip or not cn_port then 
            luci.http.status(500, "Switch Failed") 
            return false
        end
        
        local reload_result = luci.sys.exec(string.format('curl -sL -m 5 --connect-timeout 2 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XPUT http://"%s":"%s"/configs?force=true -d \'{"path":"%s"}\' 2>&1', dase, daip, cn_port, runtime_config_path))
        
        if reload_result ~= "" then
            luci.http.status(500, "Switch Failed")
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
                        
                        temp_path = config_path + '.tmp'
                        File.open(temp_path, 'w') { |f| YAML.dump(config, f) }
                        File.rename(temp_path, config_path)
                        
                    rescue => e
                        File.unlink(temp_path) if File.exist?(temp_path)
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
                        
                        temp_path = config_path + '.tmp'
                        File.open(temp_path, 'w') { |f| YAML.dump(config, f) }
                        File.rename(temp_path, config_path)
                        
                    rescue => e
                        File.unlink(temp_path) if File.exist?(temp_path)
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
                    
                    temp_path = config_path + '.tmp'
                    File.open(temp_path, 'w') { |f| YAML.dump(config, f) }
                    File.rename(temp_path, config_path)
                    
                rescue => e
                    File.unlink(temp_path) if File.exist?(temp_path)
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
        uci:set("openclash", "config", "china_ip_route", value)
        uci:commit("openclash")
        if is_running() then
            uci:set("openclash", "@overwrite[0]", "china_ip_route", value)
            uci:commit("openclash")
            luci.sys.exec("/etc/init.d/openclash restart >/dev/null 2>&1 &")
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
        luci.http.status(400, "Invalid setting")
        return
    end
    
    luci.http.prepare_content("application/json")
    luci.http.write_json({
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
    local auth_exists = false
    
    local function get_auth_from_uci()
        uci:foreach("openclash", "authentication", function(section)
            if section.enabled == "1" and section.username and section.username ~= "" 
               and section.password and section.password ~= "" then
                auth_user = section.username
                auth_pass = section.password
                auth_exists = true
                return false
            end
        end)
    end

    local config_path = fs.uci_get_config("config", "config_path")
    if config_path then
        local config_filename = fs.basename(config_path)
        local runtime_config_path = "/etc/openclash/" .. config_filename
        
        if fs.access(runtime_config_path) then
            local ruby_result = luci.sys.exec(string.format([[
                ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e "
                begin
                    config = YAML.load_file('%s')
                    if config && config['authentication'] && config['authentication'].is_a?(Array) && !config['authentication'].empty?
                        auth_entry = config['authentication'][0]
                        if auth_entry.is_a?(String) && auth_entry.include?(':')
                            username, password = auth_entry.split(':', 2)
                            puts \"#{username},#{password}\"
                        else
                            puts ','
                        end
                    else
                        puts ','
                    end
                rescue
                    puts ','
                end
                " 2>/dev/null || echo "__RUBY_ERROR__"
            ]], runtime_config_path)):gsub("\n", "")

            if ruby_result and ruby_result ~= "" and ruby_result ~= "__RUBY_ERROR__" then
                local runtime_user, runtime_pass = ruby_result:match("([^,]*),([^,]*)")
                if runtime_user and runtime_user ~= "" and runtime_pass and runtime_pass ~= "" then
                    auth_user = runtime_user
                    auth_pass = runtime_pass
                    auth_exists = true
                end
            end
        end
    end

    if not auth_exists then
        get_auth_from_uci()
    end
    
    local proxy_ip = daip()
    local mixed_port = fs.uci_get_config("config", "mixed_port") or "7893"
    
    if not proxy_ip then
        result.error = "Unable to get proxy IP"
        luci.http.prepare_content("application/json")
        luci.http.write_json(result)
        return
    end
    
    local function generate_random_string()
        local random_cmd = "tr -cd 'a-zA-Z0-9' </dev/urandom 2>/dev/null| head -c16 || date +%N| md5sum |head -c16"
        local random_string = luci.sys.exec(random_cmd):gsub("\n", "")
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

    luci.sys.call("mkdir -p " .. pac_dir)

    local find_cmd = "find " .. pac_dir .. " -name 'pac_*' -type f 2>/dev/null"
    local existing_files = luci.sys.exec(find_cmd)
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
                                luci.sys.call("chmod 644 " .. file_path)
                                
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
                                luci.sys.call("chmod 644 " .. file_path)
                                
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
        luci.sys.call("rm -f " .. pac_dir .. "pac_* 2>/dev/null")
        
        random_suffix = generate_random_string()
        pac_filename = "pac_" .. random_suffix
        pac_file_path = pac_dir .. pac_filename
        
        local file = io.open(pac_file_path, "w")
        if file then
            file:write(new_pac_content)
            file:close()
            
            luci.sys.call("chmod 644 " .. pac_file_path)
        else
            result.error = "Failed to write PAC file"
            luci.http.prepare_content("application/json")
            luci.http.write_json(result)
            return
        end
    else
        luci.sys.call(string.format("find %s -name 'pac_*' -type f ! -name '%s' -delete 2>/dev/null", pac_dir, pac_filename))
    end
    
    local pac_url = generate_pac_url_with_client_info(pac_filename, random_suffix)
    result.pac_url = pac_url
    
    if not auth_exists then
        result.error = "warning: No authentication configured, please be aware of the risk of information leakage!"
    end
    
    luci.http.prepare_content("application/json")
    luci.http.write_json(result)
end

function generate_pac_url_with_client_info(pac_filename, random_suffix)
    local client_protocol = luci.http.formvalue("client_protocol")
    local client_hostname = luci.http.formvalue("client_hostname")
    local client_host = luci.http.formvalue("client_host")
    local client_port = luci.http.formvalue("client_port")
    
    local request_scheme = "http"
    local host = "localhost"
    
    if client_protocol and (client_protocol == "http" or client_protocol == "https") then
        request_scheme = client_protocol
    else
        if luci.http.getenv("HTTPS") == "on" or 
           luci.http.getenv("HTTP_X_FORWARDED_PROTO") == "https" or
           luci.http.getenv("REQUEST_SCHEME") == "https" then
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
        local server_name = luci.http.getenv("SERVER_NAME")
        local http_host = luci.http.getenv("HTTP_HOST")
        local server_port = luci.http.getenv("SERVER_PORT")
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
        ipv4_check_code = "if (" .. table.concat(ipv4_checks, " ||\n            ") .. ") {\n            return \"DIRECT\";\n        }"
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
        ipv6_check_code = "if (" .. table.concat(ipv6_checks, " ||\n            ") .. ") {\n            return \"DIRECT\";\n        }"
    end
    
    local pac_script = string.format([[
// OpenClash PAC File
var _failureCount = 0;
var _lastCheckTime = 0;
var _isProxyDown = false;
var _checkInterval = 300000; // 5分钟 = 300000毫秒

// Access Check
function _checkNetworkConnectivity() {
    var currentTime = Date.now();
    
    if (currentTime - _lastCheckTime < _checkInterval) {
        return !_isProxyDown;
    }
    
    _lastCheckTime = currentTime;
    
    try {
        var test1 = dnsResolve("www.gstatic.com");
        var test2 = dnsResolve("captive.apple.com");
        
        if (test1 || test2) {
            if (_isProxyDown) {
                _isProxyDown = false;
                _failureCount = 0;
            }
            return true;
        } else {
            _failureCount++;
            if (_failureCount >= 3) {
                _isProxyDown = true;
            }
            return false;
        }
    } catch (e) {
        _failureCount++;
        if (_failureCount >= 3) {
            _isProxyDown = true;
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
    
    if (_checkNetworkConnectivity()) {
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

function action_oc_action()
	local action = luci.http.formvalue("action")
    local config_file = luci.http.formvalue("config_file")
	
	if not action then
		luci.http.status(400, "Missing action parameter")
		return
	end

    if config_file and config_file ~= "" then
        local config_path = "/etc/openclash/config/" .. config_file
        if not fs.access(config_path) then
            luci.http.status(404, "Config file not found")
            return
        end
        
        uci:set("openclash", "config", "config_path", config_path)
    end
	
	if action == "start" then
		uci:set("openclash", "config", "enable", "1")
		uci:commit("openclash")
        if not is_running() then
            luci.sys.call("/etc/init.d/openclash start >/dev/null 2>&1")
        else
            luci.sys.call("/etc/init.d/openclash restart >/dev/null 2>&1")
        end
	elseif action == "stop" then
		uci:set("openclash", "config", "enable", "0")
		uci:commit("openclash")
		luci.sys.call("ps | grep openclash | grep -v grep | awk '{print $1}' | xargs -r kill -9 >/dev/null 2>&1")
		luci.sys.call("/etc/init.d/openclash stop >/dev/null 2>&1")
	elseif action == "restart" then
		uci:set("openclash", "config", "enable", "1")
		uci:commit("openclash")
		luci.sys.call("/etc/init.d/openclash restart >/dev/null 2>&1")
	else
		luci.http.status(400, "Invalid action parameter")
		return
	end
	
	luci.http.prepare_content("application/json")
	luci.http.write_json({status = "success", action = action})
end

function action_config_file_list()
    local config_files = {}
    local current_config = ""
    
    local config_path = fs.uci_get_config("config", "config_path")
    if config_path then
        current_config = config_path
    end
    
    local config_dir = "/etc/openclash/config/"
    if fs.access(config_dir) then
        local files = fs.dir(config_dir)
        if files then
            for _, file in ipairs(files) do
                local full_path = config_dir .. file
                local stat = fs.stat(full_path)
                if stat and stat.type == "regular" then
                    if string.match(file, "%.ya?ml$") then
                        table.insert(config_files, {
                            name = file,
                            path = full_path,
                            size = stat.size,
                            mtime = stat.mtime
                        })
                    end
                end
            end
        end
        
        table.sort(config_files, function(a, b)
            return a.mtime > b.mtime
        end)
    end
    
    luci.http.prepare_content("application/json")
    luci.http.write_json({
        config_files = config_files,
        current_config = current_config,
        total_count = #config_files
    })
end

function action_upload_config()
    local upload = luci.http.formvalue("config_file")
    local filename = luci.http.formvalue("filename")
    
    luci.http.prepare_content("application/json")
    
    if not upload or upload == "" then
        luci.http.write_json({
            status = "error",
            message = "No file uploaded"
        })
        return
    end
    
    if not filename or filename == "" then
        filename = "upload_" .. os.date("%Y%m%d_%H%M%S")
    end

    if not is_safe_filename(filename) then
        luci.http.write_json({
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
        luci.http.write_json({
            status = "error",
            message = "Uploaded file is empty"
        })
        return
    end
    
    local file_size = string.len(upload)
    if file_size > 10 * 1024 * 1024 then
        luci.http.write_json({
            status = "error",
            message = string.format("File size (%s) exceeds 10MB limit", fs.filesize(file_size))
        })
        return
    end
    
    local yaml_valid = false
    local content_start = string.sub(upload, 1, 1000)
    
    if string.find(content_start, "proxy%-providers:") or 
       string.find(content_start, "proxies:") or
       string.find(content_start, "rules:") or
       string.find(content_start, "port:") or
       string.find(content_start, "mode:") then
        yaml_valid = true
    end
    
    if not yaml_valid then
        luci.http.write_json({
            status = "error",
            message = "Invalid config file format - missing required YAML sections"
        })
        return
    end
    
    luci.sys.call("mkdir -p " .. config_dir)
    
    local fp = io.open(target_path, "w")
    if fp then
        fp:write(upload)
        fp:close()
        
        luci.sys.call(string.format("chmod 644 '%s'", target_path))
        luci.sys.call(string.format("chown root:root '%s'", target_path))
        
        local written_content = fs.readfile(target_path)
        if not written_content or string.len(written_content) ~= file_size then
            fs.unlink(target_path)
            luci.http.write_json({
                status = "error",
                message = "File write verification failed"
            })
            return
        end
        
        luci.http.write_json({
            status = "success",
            message = "Config file uploaded successfully",
            filename = filename,
            file_path = target_path,
            file_size = file_size,
            readable_size = fs.filesize(file_size)
        })
    else
        luci.http.write_json({
            status = "error",
            message = "Failed to save config file to disk"
        })
    end
end

function action_config_file_read()
    local config_file = luci.http.formvalue("config_file")

    if not config_file then
        luci.http.status(400, "Missing config_file parameter")
        return
    end

    local allow = false
    if config_file == "/etc/openclash/custom/openclash_custom_overwrite.sh" then
        allow = true
    elseif config_file:match("^/etc/openclash/overwrite/[^/]+$") then
        allow = true
    elseif config_file:match("^/etc/openclash/[^/]+%.ya?ml$") then
        allow = true
    elseif config_file:match("^/etc/openclash/config/[^/]+%.ya?ml$") then
        allow = true
    end

    if not allow then
        luci.http.prepare_content("application/json")
        luci.http.write_json({
            status = "error",
            message = "Invalid config file path"
        })
        return
    end

    if not fs.access(config_file) then
        luci.http.prepare_content("application/json")
        luci.http.write_json({
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
        luci.http.prepare_content("application/json")
        luci.http.write_json({
            status = "error",
            message = "Config file is not a regular file"
        })
        return
    end

    if stat.size > 10 * 1024 * 1024 then
        luci.http.prepare_content("application/json")
        luci.http.write_json({
            status = "error",
            message = "Config file too large (max 10MB)"
        })
        return
    end

    local content = fs.readfile(config_file)
    if content == nil then
        luci.http.prepare_content("application/json")
        luci.http.write_json({
            status = "error",
            message = "Failed to read config file"
        })
        return
    end

    luci.http.prepare_content("application/json")
    luci.http.write_json({
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
    local config_file = luci.http.formvalue("config_file")
    local content = luci.http.formvalue("content")
    if content then
        content = content:gsub("\r\n", "\n"):gsub("\r", "\n")
    end

    if not config_file then
        luci.http.status(400, "Missing config_file parameter")
        return
    end

    if not content then
        luci.http.status(400, "Missing content parameter")
        return
    end

    local is_overwrite = (config_file == "/etc/openclash/custom/openclash_custom_overwrite.sh" or config_file:match("^/etc/openclash/overwrite/[^/]+$"))

    if not is_overwrite then
        if not string.match(config_file, "^/etc/openclash/config/[^/%.]+%.ya?ml$") then
            luci.http.prepare_content("application/json")
            luci.http.write_json({
                status = "error",
                message = "Invalid config file path"
            })
            return
        end
    else
        if not (config_file == "/etc/openclash/custom/openclash_custom_overwrite.sh" or config_file:match("^/etc/openclash/overwrite/[^/]+$")) then
            luci.http.prepare_content("application/json")
            luci.http.write_json({
                status = "error",
                message = "Invalid overwrite file path"
            })
            return
        end
    end

    if string.len(content) > 10 * 1024 * 1024 then
        luci.http.prepare_content("application/json")
        luci.http.write_json({
            status = "error",
            message = "Content too large (max 10MB)"
        })
        return
    end

    local backup_file = nil
    if fs.access(config_file) then
        backup_file = config_file .. ".backup." .. os.time()
        local backup_success = luci.sys.call(string.format("cp '%s' '%s'", config_file, backup_file))
        if backup_success ~= 0 then
            luci.http.prepare_content("application/json")
            luci.http.write_json({
                status = "error",
                message = "Failed to create backup file"
            })
            return
        end
    end

    local success = fs.writefile(config_file, content)
    if not success then
        if backup_file then
            luci.sys.call(string.format("mv '%s' '%s'", backup_file, config_file))
        end

        luci.http.prepare_content("application/json")
        luci.http.write_json({
            status = "error",
            message = "Failed to write config file"
        })
        return
    end

    local written_content = fs.readfile(config_file)
    if written_content ~= content then
        if backup_file then
            luci.sys.call(string.format("mv '%s' '%s'", backup_file, config_file))
        end

        luci.http.prepare_content("application/json")
        luci.http.write_json({
            status = "error",
            message = "File write verification failed"
        })
        return
    end

    if not is_overwrite then
        luci.sys.call(string.format("chmod 644 '%s'", config_file))
    end
    luci.sys.call(string.format("chown root:root '%s'", config_file))

    if backup_file then
        luci.sys.call(string.format([[
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

    luci.http.prepare_content("application/json")
    luci.http.write_json({
        status = "success",
        message = "Config file saved successfully",
        file_info = file_info,
        backup_created = backup_file and true or false
    })
end

function action_add_subscription()
    local name = luci.http.formvalue("name")
    local address = luci.http.formvalue("address")
    local sub_ua = luci.http.formvalue("sub_ua") or "clash.meta"
    local sub_convert = luci.http.formvalue("sub_convert") or "0"
    local convert_address = luci.http.formvalue("convert_address") or "https://api.dler.io/sub"
    local template = luci.http.formvalue("template") or ""
    local emoji = luci.http.formvalue("emoji") or "false"
    local udp = luci.http.formvalue("udp") or "false"
    local skip_cert_verify = luci.http.formvalue("skip_cert_verify") or "false"
    local sort = luci.http.formvalue("sort") or "false"
    local node_type = luci.http.formvalue("node_type") or "false"
    local rule_provider = luci.http.formvalue("rule_provider") or "false"
    local custom_params = luci.http.formvalue("custom_params") or ""
    local keyword = luci.http.formvalue("keyword") or ""
    local ex_keyword = luci.http.formvalue("ex_keyword") or ""
    local de_ex_keyword = luci.http.formvalue("de_ex_keyword") or ""
    
    luci.http.prepare_content("application/json")
    
    if not name or not address then
        luci.http.write_json({
            status = "error",
            message = "Missing name or address parameter"
        })
        return
    end
    
    local is_valid_url = false
    
    if sub_convert == "1" then
        if string.find(address, "^https?://") and not string.find(address, "\n") and not string.find(address, "|") then
            is_valid_url = true
        elseif string.find(address, "\n") or string.find(address, "|") then
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
                    if string.find(link, "^https?://") or string.find(link, "^[a-zA-Z]+://") then
                        is_valid_url = true
                        break
                    end
                end
            end
        else
            if string.find(address, "^[a-zA-Z]+://") and
               not string.find(address, "\n") and not string.find(address, "|") then
                is_valid_url = true
            end
        end
    else
        if string.find(address, "^https?://") and not string.find(address, "\n") and not string.find(address, "|") then
            is_valid_url = true
        end
    end
    
    if not is_valid_url then
        local error_msg
        if sub_convert == "1" then
            error_msg = "Invalid subscription URL format. Support: HTTP/HTTPS subscription URLs, or protocol links, can be separated by newlines or |"
        else
            error_msg = "Invalid subscription URL format. Only single HTTP/HTTPS subscription URL is supported when subscription conversion is disabled"
        end
        
        luci.http.write_json({
            status = "error",
            message = error_msg
        })
        return
    end
    
    local exists = false
    uci:foreach("openclash", "config_subscribe", function(s)
        if s.name == name then
            exists = true
            return false
        end
    end)
    
    if exists then
        luci.http.write_json({
            status = "error",
            message = "Subscription with this name already exists"
        })
        return
    end
    
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
    
    local section_id = uci:add("openclash", "config_subscribe")
    if section_id then
        uci:set("openclash", section_id, "name", name)
        uci:set("openclash", section_id, "address", normalized_address)
        uci:set("openclash", section_id, "sub_ua", sub_ua)
        uci:set("openclash", section_id, "sub_convert", sub_convert)
        uci:set("openclash", section_id, "convert_address", convert_address)
        uci:set("openclash", section_id, "template", template)
        uci:set("openclash", section_id, "emoji", emoji)
        uci:set("openclash", section_id, "udp", udp)
        uci:set("openclash", section_id, "skip_cert_verify", skip_cert_verify)
        uci:set("openclash", section_id, "sort", sort)
        uci:set("openclash", section_id, "node_type", node_type)
        uci:set("openclash", section_id, "rule_provider", rule_provider)
        
        if custom_params and custom_params ~= "" then
            local params = {}
            for line in custom_params:gmatch("[^\n]+") do
                local param = line:match("^%s*(.-)%s*$")
                if param and param ~= "" then
                    table.insert(params, param)
                end
            end
            if #params > 0 then
                for i, param in ipairs(params) do
                    uci:set_list("openclash", section_id, "custom_params", param)
                end
            end
        end
        
        if keyword and keyword ~= "" then
            local keywords = {}
            for line in keyword:gmatch("[^\n]+") do
                local kw = line:match("^%s*(.-)%s*$")
                if kw and kw ~= "" then
                    table.insert(keywords, kw)
                end
            end
            if #keywords > 0 then
                for i, kw in ipairs(keywords) do
                    uci:set_list("openclash", section_id, "keyword", kw)
                end
            end
        end
        
        if ex_keyword and ex_keyword ~= "" then
            local ex_keywords = {}
            for line in ex_keyword:gmatch("[^\n]+") do
                local ex_kw = line:match("^%s*(.-)%s*$")
                if ex_kw and ex_kw ~= "" then
                    table.insert(ex_keywords, ex_kw)
                end
            end
            if #ex_keywords > 0 then
                for i, ex_kw in ipairs(ex_keywords) do
                    uci:set_list("openclash", section_id, "ex_keyword", ex_kw)
                end
            end
        end
        
        if de_ex_keyword and de_ex_keyword ~= "" then
            local de_ex_keywords = {}
            for line in de_ex_keyword:gmatch("[^\n]+") do
                local de_ex_kw = line:match("^%s*(.-)%s*$")
                if de_ex_kw and de_ex_kw ~= "" then
                    table.insert(de_ex_keywords, de_ex_kw)
                end
            end
            if #de_ex_keywords > 0 then
                for i, de_ex_kw in ipairs(de_ex_keywords) do
                    uci:set_list("openclash", section_id, "de_ex_keyword", de_ex_kw)
                end
            end
        end
        
        uci:commit("openclash")
        
        luci.http.write_json({
            status = "success",
            message = "Subscription added successfully",
            name = name,
            address = normalized_address,
            sub_ua = sub_ua,
            sub_convert = sub_convert,
            multiple_links = sub_convert == "1" and (string.find(normalized_address, "\n") and true or false)
        })
    else
        luci.http.write_json({
            status = "error",
            message = "Failed to add subscription configuration"
        })
    end
end

function action_upload_overwrite()
    local upload = luci.http.formvalue("config_file")
    local filename = luci.http.formvalue("filename")
    local enable = luci.http.formvalue("enable")
    local order = luci.http.formvalue("order")
    luci.http.prepare_content("application/json")
    if not upload or upload == "" then
        luci.http.write_json({status = "error", message = "No file uploaded"})
        return
    end
    if not filename or filename == "" then
        filename = "upload_" .. os.date("%Y%m%d_%H%M%S")
    end
    if not is_safe_filename(filename) then
        luci.http.write_json({status = "error", message = "Invalid filename"})
        return
    end
    local overwrite_dir = "/etc/openclash/overwrite/"
    luci.sys.call("mkdir -p " .. overwrite_dir)
    local target_path = overwrite_dir .. filename
    if string.len(upload) == 0 then
        luci.http.write_json({status = "error", message = "Uploaded file is empty"})
        return
    end
    local file_size = string.len(upload)
    if file_size > 10 * 1024 * 1024 then
        luci.http.write_json({status = "error", message = string.format("File size (%s) exceeds 10MB limit", require("luci.openclash").filesize(file_size))})
        return
    end
    local fp = io.open(target_path, "w")
    if fp then
        fp:write(upload)
        fp:close()
        luci.sys.call(string.format("chmod 644 '%s'", target_path))
        luci.sys.call(string.format("chown root:root '%s'", target_path))
        local written_content = fs.readfile(target_path)
        if not written_content or string.len(written_content) ~= file_size then
            fs.unlink(target_path)
            luci.http.write_json({status = "error", message = "File write verification failed"})
            return
        end

        local section_name = filename
        local found = false

        uci:foreach("openclash", "config_overwrite", function(s)
            if s.name == section_name then
                found = true
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
            end
        end)
        if not found then
            local sid = uci:add("openclash", "config_overwrite")
            uci:set("openclash", sid, "name", section_name)
            uci:set("openclash", sid, "type", "file")
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

        luci.http.write_json({
            status = "success",
            message = "Overwrite file uploaded successfully",
            filename = filename,
            file_path = target_path,
            file_size = file_size,
            readable_size = fs.filesize(file_size)
        })
    else
        luci.http.write_json({status = "error", message = "Failed to save file to disk"})
    end
end

function action_overwrite_subscribe_info()
    local method = luci.http.getenv("REQUEST_METHOD")
    local filename = luci.http.formvalue("filename")
    local old_filename = luci.http.formvalue("old_filename")
    local typ = luci.http.formvalue("type") or "file"
    local section_name = nil
    local old_section_name = nil

    if filename and not is_safe_filename(filename) then
        luci.http.prepare_content("application/json")
        luci.http.write_json({status = "error", message = "Invalid filename"})
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
                result[s.name] = {
                    url = s.url or "",
                    update_days = s.update_days or "",
                    update_hour = s.update_hour or "",
                    order = tonumber(s.order) or 0,
                    type = s.type or "file",
                    param = s.param or "",
                    enable = tonumber(s.enable) or 0
                }
            end
        end)
        luci.http.prepare_content("application/json")
        luci.http.write_json({status="success", data=result})
        return
    elseif method == "POST" then
        if not section_name then
            luci.http.status(400, "Missing filename")
            return
        end
        local url = luci.http.formvalue("url") or ""
        local update_days = luci.http.formvalue("update_days") or ""
        local update_hour = luci.http.formvalue("update_hour") or ""
        local order = luci.http.formvalue("order")
        local param = luci.http.formvalue("param") or ""
        typ = luci.http.formvalue("type") or typ or "file"
        local enable = luci.http.formvalue("enable")

        if typ == "http" then
            if not url or url == "" then
                luci.http.prepare_content("application/json")
                luci.http.write_json({
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
                luci.http.prepare_content("application/json")
                luci.http.write_json({
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
                end
            end)
            local overwrite_dir = "/etc/openclash/overwrite/"
            local old_file = overwrite_dir .. old_section_name
            local new_file = overwrite_dir .. section_name
            if fs.access(old_file) and not fs.access(new_file) then
                fs.rename(old_file, new_file)
            end
            uci:commit("openclash")
            luci.http.prepare_content("application/json")
            luci.http.write_json({status="success"})
            return
        end
        if not found then
            uci:foreach("openclash", "config_overwrite", function(s)
                if s.name == section_name then
                    uci:set("openclash", s[".name"], "url", url)
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
                end
            end)
        end
        if not found then
            local sid = uci:add("openclash", "config_overwrite")
            uci:set("openclash", sid, "name", section_name)
            uci:set("openclash", sid, "url", url)
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
                local cmd = string.format('curl -sL --connect-timeout 5 -m 15 "%s" -o "%s"', url, file_path)
                local ret = luci.sys.call(cmd)
                if not fs.access(file_path) then
                    fs.writefile(file_path, "")
                end
                if ret ~= 0 or not fs.access(file_path) or fs.stat(file_path).size == 0 then
                    luci.http.prepare_content("application/json")
                    luci.http.write_json({status="error", message="Download failed"})
                    return
                end
            else
                if not fs.access(file_path) then
                    fs.writefile(file_path, "")
                end
            end
        end

        luci.http.prepare_content("application/json")
        luci.http.write_json({status="success"})
        return
    else
        luci.http.status(405, "Method Not Allowed")
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

    luci.http.prepare_content("application/json")
    luci.http.write_json({
        overwrite_files = overwrite_files,
        total_count = #overwrite_files
    })
end

function delete_overwrite_file()
    local filename = luci.http.formvalue("filename")
    if not filename or filename == "" then
        luci.http.prepare_content("application/json")
        luci.http.write_json({status="error", message="Missing filename"})
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

    luci.http.prepare_content("application/json")
    luci.http.write_json({status="success"})
end