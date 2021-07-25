module("luci.controller.openclash", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/openclash") then
		return
	end

	local page
	
	page = entry({"admin", "services", "openclash"}, alias("admin", "services", "openclash", "client"), _("OpenClash"), 50)
	page.dependent = true
	page.acl_depends = { "luci-app-openclash" }
	entry({"admin", "services", "openclash", "client"},cbi("openclash/client"),_("Overviews"), 20).leaf = true
	entry({"admin", "services", "openclash", "status"},call("action_status")).leaf=true
	entry({"admin", "services", "openclash", "state"},call("action_state")).leaf=true
	entry({"admin", "services", "openclash", "startlog"},call("action_start")).leaf=true
	entry({"admin", "services", "openclash", "refresh_log"},call("action_refresh_log"))
	entry({"admin", "services", "openclash", "del_log"},call("action_del_log"))
	entry({"admin", "services", "openclash", "close_all_connection"},call("action_close_all_connection"))
	entry({"admin", "services", "openclash", "reload_firewall"},call("action_reload_firewall"))
	entry({"admin", "services", "openclash", "update_subscribe"},call("action_update_subscribe"))
	entry({"admin", "services", "openclash", "update_other_rules"},call("action_update_other_rules"))
	entry({"admin", "services", "openclash", "update_geoip"},call("action_update_geoip"))
	entry({"admin", "services", "openclash", "currentversion"},call("action_currentversion"))
	entry({"admin", "services", "openclash", "lastversion"},call("action_lastversion"))
	entry({"admin", "services", "openclash", "save_corever"},call("action_save_corever"))
	entry({"admin", "services", "openclash", "update"},call("action_update"))
	entry({"admin", "services", "openclash", "update_ma"},call("action_update_ma"))
	entry({"admin", "services", "openclash", "opupdate"},call("action_opupdate"))
	entry({"admin", "services", "openclash", "coreupdate"},call("action_coreupdate"))
	entry({"admin", "services", "openclash", "ping"}, call("act_ping"))
	entry({"admin", "services", "openclash", "download_rule"}, call("action_download_rule"))
	entry({"admin", "services", "openclash", "restore"}, call("action_restore_config"))
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
	entry({"admin", "services", "openclash", "settings"},cbi("openclash/settings"),_("Global Settings"), 30).leaf = true
	entry({"admin", "services", "openclash", "servers"},cbi("openclash/servers"),_("Servers and Groups"), 40).leaf = true
	entry({"admin", "services", "openclash", "other-rules-edit"},cbi("openclash/other-rules-edit"), nil).leaf = true
	entry({"admin", "services", "openclash", "rule-providers-settings"},cbi("openclash/rule-providers-settings"),_("Rule Providers and Groups"), 50).leaf = true
	entry({"admin", "services", "openclash", "game-rules-manage"},form("openclash/game-rules-manage"), nil).leaf = true
	entry({"admin", "services", "openclash", "rule-providers-manage"},form("openclash/rule-providers-manage"), nil).leaf = true
	entry({"admin", "services", "openclash", "proxy-provider-file-manage"},form("openclash/proxy-provider-file-manage"), nil).leaf = true
	entry({"admin", "services", "openclash", "rule-providers-file-manage"},form("openclash/rule-providers-file-manage"), nil).leaf = true
	entry({"admin", "services", "openclash", "config-subscribe"},cbi("openclash/config-subscribe"),_("Config Update"), 60).leaf = true
	entry({"admin", "services", "openclash", "config-subscribe-edit"},cbi("openclash/config-subscribe-edit"), nil).leaf = true
	entry({"admin", "services", "openclash", "servers-config"},cbi("openclash/servers-config"), nil).leaf = true
	entry({"admin", "services", "openclash", "groups-config"},cbi("openclash/groups-config"), nil).leaf = true
	entry({"admin", "services", "openclash", "proxy-provider-config"},cbi("openclash/proxy-provider-config"), nil).leaf = true
	entry({"admin", "services", "openclash", "rule-providers-config"},cbi("openclash/rule-providers-config"), nil).leaf = true
	entry({"admin", "services", "openclash", "config"},form("openclash/config"),_("Config Manage"), 70).leaf = true
	entry({"admin", "services", "openclash", "log"},cbi("openclash/log"),_("Server Logs"), 80).leaf = true

end
local fs = require "luci.openclash"
local json = require "luci.jsonc"
local uci = require("luci.model.uci").cursor()

local core_path_mode = uci:get("openclash", "config", "small_flash_memory")
if core_path_mode ~= "1" then
	dev_core_path="/etc/openclash/core/clash"
	tun_core_path="/etc/openclash/core/clash_tun"
	game_core_path="/etc/openclash/core/clash_game"
else
	dev_core_path="/tmp/etc/openclash/core/clash"
	tun_core_path="/tmp/etc/openclash/core/clash_tun"
	game_core_path="/tmp/etc/openclash/core/clash_game"
end

local function is_running()
	return luci.sys.call("pidof clash >/dev/null") == 0
end

local function is_web()
	return luci.sys.call("pidof clash >/dev/null") == 0
end

local function restricted_mode()
	return uci:get("openclash", "config", "restricted_mode")
end

local function is_watchdog()
	local ps_version = luci.sys.exec("ps --version 2>&1 |grep -c procps-ng |tr -d '\n'")
	if ps_version == "0" then
		return luci.sys.call("ps |grep openclash_watchdog.sh |grep -v grep >/dev/null") == 0
	else
		return luci.sys.call("ps -ef |grep openclash_watchdog.sh |grep -v grep >/dev/null") == 0
	end
end

local function cn_port()
	return uci:get("openclash", "config", "cn_port")
end

local function mode()
	return uci:get("openclash", "config", "en_mode")
end

local function ipdb()
	return os.date("%Y-%m-%d %H:%M:%S",fs.mtime("/etc/openclash/Country.mmdb"))
end

local function lhie1()
	return os.date("%Y-%m-%d %H:%M:%S",fs.mtime("/usr/share/openclash/res/lhie1.yaml"))
end

local function ConnersHua()
	return os.date("%Y-%m-%d %H:%M:%S",fs.mtime("/usr/share/openclash/res/ConnersHua.yaml"))
end

local function ConnersHua_return()
	return os.date("%Y-%m-%d %H:%M:%S",fs.mtime("/usr/share/openclash/res/ConnersHua_return.yaml"))
end

local function chnroute()
	return os.date("%Y-%m-%d %H:%M:%S",fs.mtime("/etc/openclash/rule_provider/ChinaIP.yaml"))
end

local function daip()
	local daip = luci.sys.exec("uci -q get network.lan.ipaddr |awk -F '/' '{print $1}' 2>/dev/null |tr -d '\n'")
	if not daip or daip == "" then
		local daip = luci.sys.exec("ip addr show 2>/dev/null | grep -w 'inet' | grep 'global' | grep 'brd' | grep -Eo 'inet [0-9\.]+' | awk '{print $2}' | head -n 1 | tr -d '\n'")
	end
	return daip
end

local function dase()
	return uci:get("openclash", "config", "dashboard_password")
end

local function check_lastversion()
	luci.sys.exec("sh /usr/share/openclash/openclash_version.sh 2>/dev/null")
	return luci.sys.exec("sed -n '/^https:/,$p' /tmp/openclash_last_version 2>/dev/null")
end

local function check_currentversion()
	return luci.sys.exec("sed -n '/^data:image/,$p' /usr/share/openclash/res/openclash_version 2>/dev/null")
end

local function startlog()
	local info = ""
	if nixio.fs.access("/tmp/openclash_start.log") then
		info = luci.sys.exec("sed -n '$p' /tmp/openclash_start.log 2>/dev/null")
		if not string.find (info, "【") and not string.find (info, "】") then
   		info = luci.i18n.translate(string.sub(info, 0, -1))
   	else
   		local a = string.find (info, "【")
   		local b = string.find (info, "】")+2
   		if a <= 1 then
   			info = string.sub(info, 0, b)..luci.i18n.translate(string.sub(info, b+1, -1))
   		elseif b < string.len(info) then
   			info = luci.i18n.translate(string.sub(info, 0, a-1))..string.sub(info, a, b)..luci.i18n.translate(string.sub(info, b+1, -1))
   		elseif b == string.len(info) then
   			info = luci.i18n.translate(string.sub(info, 0, a-1))..string.sub(info, a, -1)
   		end
   	end
	end
	return info
end

local function coremodel()
  local coremodel = luci.sys.exec("cat /usr/lib/os-release 2>/dev/null |grep OPENWRT_ARCH 2>/dev/null |awk -F '\"' '{print $2}' 2>/dev/null")
  local coremodel2 = luci.sys.exec("opkg status libc 2>/dev/null |grep 'Architecture' |awk -F ': ' '{print $2}' 2>/dev/null")
  if not coremodel or coremodel == "" then
     return coremodel2 .. "," .. coremodel2
  else
     return coremodel .. "," .. coremodel2
  end
end

local function corecv()
if not nixio.fs.access(dev_core_path) then
  return "0"
else
	return luci.sys.exec(string.format("%s -v 2>/dev/null |awk -F ' ' '{print $2}'",dev_core_path))
end
end

local function coretuncv()
if not nixio.fs.access(tun_core_path) then
  return "0"
else
	return luci.sys.exec(string.format("%s -v 2>/dev/null |awk -F ' ' '{print $2}'",tun_core_path))
end
end

local function coregamecv()
if not nixio.fs.access(game_core_path) then
  return "0"
else
	return luci.sys.exec(string.format("%s -v 2>/dev/null |awk -F ' ' '{print $2}'",game_core_path))
end
end

local function corelv()
	luci.sys.call("sh /usr/share/openclash/clash_version.sh")
	local core_lv = luci.sys.exec("sed -n 1p /tmp/clash_last_version 2>/dev/null")
	local core_tun_lv = luci.sys.exec("sed -n 2p /tmp/clash_last_version 2>/dev/null")
	local core_game_lv = luci.sys.exec("sed -n 3p /tmp/clash_last_version 2>/dev/null")
	return core_lv .. "," .. core_tun_lv .. "," .. core_game_lv
end

local function opcv()
	return luci.sys.exec("sed -n 1p /usr/share/openclash/res/openclash_version 2>/dev/null")
end

local function oplv()
	 local new = luci.sys.call(string.format("sh /usr/share/openclash/openclash_version.sh"))
	 local oplv = luci.sys.exec("sed -n 1p /tmp/openclash_last_version 2>/dev/null")
   return oplv .. "," .. new
end

local function opup()
   luci.sys.call("rm -rf /tmp/*_last_version 2>/dev/null && sh /usr/share/openclash/openclash_version.sh >/dev/null 2>&1")
   return luci.sys.call("sh /usr/share/openclash/openclash_update.sh >/dev/null 2>&1 &")
end

local function coreup()
	uci:set("openclash", "config", "enable", "1")
	uci:commit("openclash")
	local type = luci.http.formvalue("core_type")
	luci.sys.call("rm -rf /tmp/*_last_version 2>/dev/null && sh /usr/share/openclash/clash_version.sh >/dev/null 2>&1")
	return luci.sys.call(string.format("/usr/share/openclash/openclash_core.sh '%s' >/dev/null 2>&1 &", type))
end

local function corever()
	return uci:get("openclash", "config", "core_version")
end

local function save_corever()
	uci:set("openclash", "config", "core_version", luci.http.formvalue("core_ver"))
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

local function historychecktime()
	local CONFIG_FILE = uci:get("openclash", "config", "config_path")
  local HISTORY_PATH = "/etc/openclash/history/" .. string.sub(luci.sys.exec(string.format("$(basename '%s' .yml) 2>/dev/null || $(basename '%s' .yaml) 2>/dev/null",CONFIG_FILE,CONFIG_FILE)), 1, -2)
	if not nixio.fs.access(HISTORY_PATH) then
  	return "0"
	else
		return os.date("%Y-%m-%d %H:%M:%S",fs.mtime(HISTORY_PATH))
	end
end

function download_rule()
	local filename = luci.http.formvalue("filename")
  local state = luci.sys.call(string.format('/usr/share/openclash/openclash_download_rule_list.sh "%s" >/dev/null 2>&1',filename))
  return state
end

function action_restore_config()
	luci.sys.call("/etc/init.d/openclash stop >/dev/null 2>&1")
	luci.sys.call("cp '/usr/share/openclash/backup/openclash' '/etc/config/openclash' >/dev/null 2>&1 &")
	luci.sys.call("cp '/usr/share/openclash/backup/openclash_custom_rules.list' '/etc/openclash/custom/openclash_custom_rules.list' >/dev/null 2>&1 &")
	luci.sys.call("cp '/usr/share/openclash/backup/openclash_custom_rules_2.list' '/etc/openclash/custom/openclash_custom_rules_2.list' >/dev/null 2>&1 &")
	luci.sys.call("cp '/usr/share/openclash/backup/openclash_custom_fake_black.conf' '/etc/openclash/custom/openclash_custom_fake_black.conf' >/dev/null 2>&1 &")
	luci.sys.call("cp '/usr/share/openclash/backup/openclash_custom_hosts.list' '/etc/openclash/custom/openclash_custom_hosts.list' >/dev/null 2>&1 &")
	luci.sys.call("cp '/usr/share/openclash/backup/openclash_custom_domain_dns.list' '/etc/openclash/custom/openclash_custom_domain_dns.list' >/dev/null 2>&1 &")
end

function action_remove_all_core()
	luci.sys.call("rm -rf /etc/openclash/core/* >/dev/null 2>&1")
end

function action_one_key_update()
  return luci.sys.call("sh /usr/share/openclash/openclash_update.sh 'one_key_update' >/dev/null 2>&1 &")
end

local function dler_login_info_save()
	uci:set("openclash", "config", "dler_email", luci.http.formvalue("email"))
	uci:set("openclash", "config", "dler_passwd", luci.http.formvalue("passwd"))
	uci:set("openclash", "config", "dler_checkin", luci.http.formvalue("checkin"))
	uci:set("openclash", "config", "dler_checkin_interval", luci.http.formvalue("interval"))
	if tonumber(luci.http.formvalue("multiple")) > 50 then
		uci:set("openclash", "config", "dler_checkin_multiple", "50")
	elseif tonumber(luci.http.formvalue("multiple")) < 1 or not tonumber(luci.http.formvalue("multiple")) then
		uci:set("openclash", "config", "dler_checkin_multiple", "1")
	else
		uci:set("openclash", "config", "dler_checkin_multiple", luci.http.formvalue("multiple"))
	end
	uci:commit("openclash")
	return "success"
end

local function dler_login()
	local info, token, get_sub
	local sub_path = "/tmp/dler_sub"
	local email = uci:get("openclash", "config", "dler_email")
	local passwd = uci:get("openclash", "config", "dler_passwd")
	if email and passwd then
		info = luci.sys.exec(string.format("curl -sL -H 'Content-Type: application/json' -d '{\"email\":\"%s\", \"passwd\":\"%s\"}' -X POST https://dler.cloud/api/v1/login", email, passwd))
		if info then
			info = json.parse(info)
		end
		if info.ret == 200 then
			token = info.data.token
			uci:set("openclash", "config", "dler_token", token)
			uci:commit("openclash")
			get_sub = string.format("curl -sL -H 'Content-Type: application/json' -d '{\"access_token\":\"%s\"}' -X POST https://dler.cloud/api/v1/managed/clash -o %s", token, sub_path)
			luci.sys.exec(get_sub)
			return info.ret
		else
			uci:delete("openclash", "config", "dler_token")
			uci:commit("openclash")
			fs.unlink(sub_path)
			fs.unlink("/tmp/dler_checkin")
			fs.unlink("/tmp/dler_info")
			return "402"
		end
	else
		uci:delete("openclash", "config", "dler_token")
		uci:commit("openclash")
		fs.unlink(sub_path)
		fs.unlink("/tmp/dler_checkin")
		fs.unlink("/tmp/dler_info")
		return "402"
	end
end

local function dler_logout()
	local info, token
	local token = uci:get("openclash", "config", "dler_token")
	if token then
		info = luci.sys.exec(string.format("curl -sL -H 'Content-Type: application/json' -d '{\"access_token\":\"%s\"}' -X POST https://dler.cloud/api/v1/logout", token))
		if info then
			info = json.parse(info)
		end
		if info.ret == 200 then
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
			return "403"
		end
	else
		return "403"
	end
end

local function dler_info()
	local info, path, get_info
	local token = uci:get("openclash", "config", "dler_token")
	local email = uci:get("openclash", "config", "dler_email")
	local passwd = uci:get("openclash", "config", "dler_passwd")
	path = "/tmp/dler_info"
	if token and email and passwd then
		get_info = string.format("curl -sL -H 'Content-Type: application/json' -d '{\"email\":\"%s\", \"passwd\":\"%s\"}' -X POST https://dler.cloud/api/v1/information -o %s", email, passwd, path)
		if not nixio.fs.access(path) then
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
		if info.ret == 200 then
			return info.data
		else
			fs.unlink(path)
			luci.sys.exec(string.format("echo -e %s Dler Cloud Account Login Failed! Please Check And Try Again... >> /tmp/openclash.log", os.date("%Y-%m-%d %H:%M:%S")))
			return "errorget"
		end
	else
		return "error"
	end
end

local function dler_checkin()
	local info
	local path = "/tmp/dler_checkin"
	local token = uci:get("openclash", "config", "dler_token")
	local email = uci:get("openclash", "config", "dler_email")
	local passwd = uci:get("openclash", "config", "dler_passwd")
	local multiple = uci:get("openclash", "config", "dler_checkin_multiple") or 1
	if token and email and passwd then
		info = luci.sys.exec(string.format("curl -sL -H 'Content-Type: application/json' -d '{\"email\":\"%s\", \"passwd\":\"%s\", \"multiple\":\"%s\"}' -X POST https://dler.cloud/api/v1/checkin", email, passwd, multiple))
		if info then
			info = json.parse(info)
		end
		if info.ret == 200 then
			fs.unlink("/tmp/dler_info")
			fs.writefile(path, info)
			luci.sys.exec(string.format("echo -e %s Dler Cloud Checkin Successful, Result:【%s】 >> /tmp/openclash.log", os.date("%Y-%m-%d %H:%M:%S"), info.data.checkin))
			return info
		else
			if info.msg then
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


function action_save_corever()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		save_corever = save_corever();
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
	luci.sys.call("rm -rf /tmp/*_last_version 2>/dev/null")
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		corever = corever(),
		corelv = corelv(),
		oplv = oplv();
	})
end

function action_op_mode()
	local op_mode = uci:get("openclash", "config", "operation_mode")
	luci.http.prepare_content("application/json")
	luci.http.write_json({
	  op_mode = op_mode;
	})
end

function action_switch_mode()
	local switch_mode = uci:get("openclash", "config", "operation_mode")
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
		watchdog = is_watchdog(),
		daip = daip(),
		dase = dase(),
		web = is_web(),
		cn_port = cn_port(),
		restricted_mode = restricted_mode(),
		mode = mode();
	})
end

function action_state()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		lhie1 = lhie1(),
		ConnersHua = ConnersHua(),
		ConnersHua_return = ConnersHua_return(),
		ipdb = ipdb(),
		historychecktime = historychecktime(),
		chnroute = chnroute();
	})
end

function action_lastversion()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
			lastversion = check_lastversion();
	})
end

function action_currentversion()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
			currentversion = check_currentversion();
	})
end

function action_start()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
			startlog = startlog();
	})
end

function action_update()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
			coremodel = coremodel(),
			corecv = corecv(),
			coretuncv = coretuncv(),
			coregamecv = coregamecv(),
			opcv = opcv(),
			corever = corever(),
			upchecktime = upchecktime(),
			corelv = corelv(),
			oplv = oplv();
	})
end

function action_update_ma()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
			oplv = oplv(),
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
	return luci.sys.call("/etc/init.d/openclash reload")
end

function action_update_subscribe()
	fs.unlink("/tmp/Proxy_Group")
	return luci.sys.call("/usr/share/openclash/openclash.sh >/dev/null 2>&1")
end

function action_update_other_rules()
	return luci.sys.call("/usr/share/openclash/openclash_rule.sh >/dev/null 2>&1")
end

function action_update_geoip()
	return luci.sys.call("/usr/share/openclash/openclash_ipdb.sh >/dev/null 2>&1")
end

function act_ping()
	local e={}
	e.index=luci.http.formvalue("index")
	e.ping=luci.sys.exec("ping -c 1 -W 1 %q 2>&1 | grep -o 'time=[0-9]*.[0-9]' | awk -F '=' '{print$2}'"%luci.http.formvalue("domain"))
	luci.http.prepare_content("application/json")
	luci.http.write_json(e)
end

function action_download_rule()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		rule_download_status = download_rule();
	})
end

function action_refresh_log()
	local logfile="/tmp/openclash.log"
	if not fs.access(logfile) then
		luci.http.write("")
		return
	end
	luci.http.prepare_content("text/plain; charset=utf-8")
	local file=io.open(logfile, "r+")
	file:seek("set")
	local info = ""
	for line in file:lines() do
		if not string.find (line, "level=") then
			if not string.find (line, "【") and not string.find (line, "】") then
   			line = string.sub(line, 0, 20)..luci.i18n.translate(string.sub(line, 21, -1))
   		else
   			local a = string.find (line, "【")
   			local b = string.find (line, "】")+2
   			if a <= 21 then
   				line = string.sub(line, 0, b)..luci.i18n.translate(string.sub(line, b+1, -1))
   			elseif b < string.len(line) then
   				line = string.sub(line, 0, 20)..luci.i18n.translate(string.sub(line, 21, a-1))..string.sub(line, a, b)..luci.i18n.translate(string.sub(line, b+1, -1))
   			elseif b == string.len(line) then
   				line = string.sub(line, 0, 20)..luci.i18n.translate(string.sub(line, 21, a-1))..string.sub(line, a, b)
   			end
   		end
		end
		if info ~= "" then
			info = info.."\n"..line
		else
			info = line
		end
	end
	file:close()
	luci.http.write(info)
end

function action_del_log()
	luci.sys.exec(": > /tmp/openclash.log")
	return
end