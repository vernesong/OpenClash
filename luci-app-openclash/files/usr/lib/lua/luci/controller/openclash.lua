module("luci.controller.openclash", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/openclash") then
		return
	end


	entry({"admin", "services", "openclash"},alias("admin", "services", "openclash", "client"), _("OpenClash"), 50).dependent = true
	entry({"admin", "services", "openclash", "client"},cbi("openclash/client"),_("Clash Global State"), 20).leaf = true
	entry({"admin", "services", "openclash", "status"},call("action_status")).leaf=true
	entry({"admin", "services", "openclash", "state"},call("action_state")).leaf=true
	entry({"admin", "services", "openclash", "startlog"},call("action_start")).leaf=true
	entry({"admin", "services", "openclash", "currentversion"},call("action_currentversion"))
	entry({"admin", "services", "openclash", "lastversion"},call("action_lastversion"))
	entry({"admin", "services", "openclash", "config"},cbi("openclash/config"),_("Server Config"), 30).leaf = true
	entry({"admin", "services", "openclash", "settings"},cbi("openclash/settings"),_("Clash Settings"), 40).leaf = true
	entry({"admin", "services", "openclash", "update"},cbi("openclash/update"),_("Update Setting"), 50).leaf = true
	entry({"admin", "services", "openclash", "rule"},cbi("openclash/rule"),_("Rules Setting"), 60).leaf = true
	entry({"admin", "services", "openclash", "log"},cbi("openclash/log"),_("Logs"), 70).leaf = true

	
end


local function is_running()
	return luci.sys.call("pidof clash >/dev/null") == 0
end

local function is_web()
	return luci.sys.call("pidof clash >/dev/null") == 0
end

local function is_watchdog()
	return luci.sys.exec("ps |grep openclash_watchdog.sh |grep -v grep 2>/dev/null")
end

local function config_check()
	return luci.sys.call("grep '^Proxy Group:$' /etc/openclash/config.yml 1>/dev/null && grep '^Rule:$' /etc/openclash/config.yml 1>/dev/null && grep '^- GEOIP' /etc/openclash/config.yml 1>/dev/null && grep '  nameserver:$' /etc/openclash/config.yml 1>/dev/null") == 0
end

local function cn_port()
	return luci.sys.exec("uci get openclash.config.cn_port 2>/dev/null")
end

local function config()
	return luci.sys.exec("ls -l --full-time /etc/openclash/config.bak|awk '{print $6,$7;}' 2>/dev/null")
end

local function ipdb()
	return luci.sys.exec("ls -l --full-time /etc/openclash/Country.mmdb|awk '{print $6,$7;}' 2>/dev/null")
end

local function lhie1()
	return luci.sys.exec("ls -l --full-time /etc/openclash/lhie1.yml|awk '{print $6,$7;}' 2>/dev/null")
end

local function ConnersHua()
	return luci.sys.exec("ls -l --full-time /etc/openclash/ConnersHua.yml|awk '{print $6,$7;}' 2>/dev/null")
end

local function ConnersHua_return()
	return luci.sys.exec("ls -l --full-time /etc/openclash/ConnersHua_return.yml|awk '{print $6,$7;}' 2>/dev/null")
end

local function daip()
	return luci.sys.exec("uci get network.lan.ipaddr")
end

local function dase()
	return luci.sys.exec("uci get openclash.config.dashboard_password 2>/dev/null")
end

local function check_lastversion()
	return luci.sys.exec("sh /usr/share/openclash/openclash_version.sh && sed -n '/^data:/,$p' /tmp/openclash_last_version 2>/dev/null")
end

local function check_currentversion()
	return luci.sys.exec("sed -n '/^data:/,$p' /etc/openclash/openclash_version 2>/dev/null")
end

local function startlog()
	return luci.sys.exec("sed -n '$p' /tmp/openclash_start.log 2>/dev/null")
end

function action_status()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
	  clash = is_running(),
		watchdog = is_watchdog(),
		daip = daip(),
		dase = dase(),
		web = is_web(),
		cn_port = cn_port();
	})
end
function action_state()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		config_check = config_check(),
		config = config(),
		lhie1 = lhie1(),
		ConnersHua = ConnersHua(),
		ConnersHua_return = ConnersHua_return(),
		ipdb = ipdb();
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
