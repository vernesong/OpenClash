
local NXFS = require "nixio.fs"
local SYS  = require "luci.sys"
local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"
local UTIL = require "luci.util"

m = Map("openclash", translate("Takeover Settings"))

s = m:section(TypedSection, "openclash")
s.anonymous = true

s:tab("settings", translate("General Settings"))
s:tab("rules", translate("Rules Setting"))
s:tab("dashboard", translate("Dashboard Settings"))
s:tab("config_update", translate("Config Update"))
s:tab("rules_update", translate("Rules Update"))
s:tab("geo_update", translate("GEOIP Update"))

---- General Settings
o = s:taboption("settings", ListValue, "en_mode", translate("Select Mode"))
o.description = translate("Will to Take Over Your General Settings, Network Error Try Flush DNS Cache")
o:value("0", translate("Disable Mode Control (Use Redir-Host Default If Not Set)"))
o:value("redir-host", translate("redir-host"))
o:value("fake-ip", translate("fake-ip"))
o.default = 0

o = s:taboption("settings", Flag, "enable_custom_dns", translate("Custom DNS Setting"))
o.description = translate("Set OpenClash Upstream DNS Resolve Server")
o.default = 0
o.rmempty = false

o = s:taboption("settings", Flag, "ipv6_enable", translate("Enable ipv6 Resolve"))
o.description = translate("Force Enable to Resolve ipv6 DNS Requests")
o.default=0
o.rmempty = false

o = s:taboption("settings", Value, "proxy_port")
o.title = translate("Redir Port")
o.default = 7892
o.datatype = "port"
o.rmempty = false
o.description = translate("Please Make Sure Ports Available")

o = s:taboption("settings", Value, "http_port")
o.title = translate("HTTP(S) Port")
o.default = 7890
o.datatype = "port"
o.rmempty = false
o.description = translate("Please Make Sure Ports Available")

o = s:taboption("settings", Value, "socks_port")
o.title = translate("SOCKS5 Port")
o.default = 7891
o.datatype = "port"
o.rmempty = false
o.description = translate("Please Make Sure Ports Available")

---- Rules Settings
o = s:taboption("rules", ListValue, "enable_custom_clash_rules", translate("Custom Clash Rules"))
o.description = translate("Use Custom Rules")
o:value("0", translate("Disable Custom Clash Rules"))
o:value("1", translate("Enable Custom Clash Rules"))
o.default = 0

o = s:taboption("rules", ListValue, "rule_source", translate("Enable Other Rules"))
o.description = translate("Use Other Rules")
o:value("0", translate("Disable Other Rules"))
o:value("lhie1", translate("lhie1 Rules"))
o:value("ConnersHua", translate("ConnersHua Rules"))
o:value("ConnersHua_return", translate("ConnersHua Return Rules"))

os.execute("awk '/Proxy Group:/,/Rule:/{print}' /etc/openclash/config.yaml |grep ^-  |grep name: |sed 's/,.*//' |awk -F 'name: ' '{print $2}' |sed 's/\"//g' >/tmp/Proxy_Group 2>&1")
os.execute("echo 'DIRECT' >>/tmp/Proxy_Group")
os.execute("echo 'REJECT' >>/tmp/Proxy_Group")
file = io.open("/tmp/Proxy_Group", "r"); 

o = s:taboption("rules", ListValue, "GlobalTV", translate("GlobalTV"))
o:depends("rule_source", "lhie1")
o:depends("rule_source", "ConnersHua")
 for l in file:lines() do
   o:value(l)
   end
   file:seek("set")
o = s:taboption("rules", ListValue, "AsianTV", translate("AsianTV"))
o:depends("rule_source", "lhie1")
o:depends("rule_source", "ConnersHua")
 for l in file:lines() do
   o:value(l)
   end
   file:seek("set")
o = s:taboption("rules", ListValue, "Proxy", translate("Proxy"))
o:depends("rule_source", "lhie1")
o:depends("rule_source", "ConnersHua")
o:depends("rule_source", "ConnersHua_return")
 for l in file:lines() do
   o:value(l)
   end
   file:seek("set")
o = s:taboption("rules", ListValue, "Apple", translate("Apple"))
o:depends("rule_source", "lhie1")
o:depends("rule_source", "ConnersHua")
 for l in file:lines() do
   o:value(l)
   end
   file:seek("set")
o = s:taboption("rules", ListValue, "AdBlock", translate("AdBlock"))
o:depends("rule_source", "lhie1")
o:depends("rule_source", "ConnersHua")
 for l in file:lines() do
   o:value(l)
   end
   file:seek("set")
o = s:taboption("rules", ListValue, "Domestic", translate("Domestic"))
o:depends("rule_source", "lhie1")
o:depends("rule_source", "ConnersHua")
 for l in file:lines() do
   o:value(l)
   end
   file:seek("set")
o = s:taboption("rules", ListValue, "Others", translate("Others"))
o:depends("rule_source", "lhie1")
o:depends("rule_source", "ConnersHua")
o:depends("rule_source", "ConnersHua_return")
o.description = translate("Choose Proxy Group, Base On Your Servers Group in config.yaml")
 for l in file:lines() do
   o:value(l)
   end
   file:close()

custom_rules = s:taboption("rules", Value, "custom_rules", translate("Custom Clash Rules Here"), translate("For More Go Github:https://github.com/Dreamacro/clash"))
custom_rules.template = "cbi/tvalue"
custom_rules.rows = 20
custom_rules.wrap = "off"
custom_rules:depends("enable_custom_clash_rules", 1)

function custom_rules.cfgvalue(self, section)
	return NXFS.readfile("/etc/config/openclash_custom_rules.list") or ""
end
function custom_rules.write(self, section, value)
	if value then
		value = value:gsub("\r\n", "\n")
		NXFS.writefile("/etc/config/openclash_custom_rules.list", value)
	end
end

---- update Settings
o = s:taboption("config_update", Flag, "auto_update", translate("Auto Update"))
o.description = translate("Auto Update Server subscription")
o.default=0
o.rmempty = false

o = s:taboption("config_update", ListValue, "config_update_week_time", translate("Update Time (Every Week)"))
o:value("*", translate("Every Day"))
o:value("1", translate("Every Monday"))
o:value("2", translate("Every Tuesday"))
o:value("3", translate("Every Wednesday"))
o:value("4", translate("Every Thursday"))
o:value("5", translate("Every Friday"))
o:value("6", translate("Every Saturday"))
o:value("7", translate("Every Sunday"))
o.default=1

o = s:taboption("config_update", ListValue, "auto_update_time", translate("Update time (every day)"))
for t = 0,23 do
o:value(t, t..":00")
end
o.default=0
o.rmempty = false

o = s:taboption("config_update", Value, "subscribe_url")
o.title = translate("Subcription Url")
o.description = translate("Server Subscription Address")
o.rmempty = true

o = s:taboption("config_update", Button, translate("Config File Update")) 
o.title = translate("Update Subcription")
o.inputtitle = translate("Update Configuration")
o.inputstyle = "reload"
o.write = function()
  SYS.call("uci set openclash.config.enable=1 && uci commit openclash && sh /usr/share/openclash/openclash.sh >/dev/null 2>&1 &")
  HTTP.redirect(DISP.build_url("admin", "services", "openclash"))
end

o = s:taboption("rules_update", Flag, "other_rule_auto_update", translate("Auto Update"))
o.description = translate("Auto Update Other Rules")
o.default=0
o.rmempty = false

o = s:taboption("rules_update", ListValue, "other_rule_update_week_time", translate("Update Time (Every Week)"))
o:value("*", translate("Every Day"))
o:value("1", translate("Every Monday"))
o:value("2", translate("Every Tuesday"))
o:value("3", translate("Every Wednesday"))
o:value("4", translate("Every Thursday"))
o:value("5", translate("Every Friday"))
o:value("6", translate("Every Saturday"))
o:value("7", translate("Every Sunday"))
o.default=1

o = s:taboption("rules_update", ListValue, "other_rule_update_day_time", translate("Update time (every day)"))
for t = 0,23 do
o:value(t, t..":00")
end
o.default=0

o = s:taboption("rules_update", Button, translate("Other Rules Update")) 
o.title = translate("Update Other Rules")
o.inputtitle = translate("Start Update Other Rules")
o.description = translate("Other Rules Update(Only in Use)")
o.inputstyle = "reload"
o.write = function()
  SYS.call("uci set openclash.config.enable=1 && uci commit openclash && sh /usr/share/openclash/openclash_rule.sh >/dev/null 2>&1 &")
  HTTP.redirect(DISP.build_url("admin", "services", "openclash"))
end

o = s:taboption("geo_update", Flag, "geo_auto_update", translate("Auto Update"))
o.description = translate("Auto Update GEOIP Database")
o.default=0
o.rmempty = false

o = s:taboption("geo_update", ListValue, "geo_update_week_time", translate("Update Time (Every Week)"))
o:value("*", translate("Every Day"))
o:value("1", translate("Every Monday"))
o:value("2", translate("Every Tuesday"))
o:value("3", translate("Every Wednesday"))
o:value("4", translate("Every Thursday"))
o:value("5", translate("Every Friday"))
o:value("6", translate("Every Saturday"))
o:value("7", translate("Every Sunday"))
o.default=1

o = s:taboption("geo_update", ListValue, "geo_update_day_time", translate("Update time (every day)"))
for t = 0,23 do
o:value(t, t..":00")
end
o.default=0

o = s:taboption("geo_update", Button, translate("GEOIP Update")) 
o.title = translate("Update GEOIP Database")
o.inputtitle = translate("Start Update GEOIP Database")
o.inputstyle = "reload"
o.write = function()
  SYS.call("uci set openclash.config.enable=1 && uci commit openclash && sh /usr/share/openclash/openclash_ipdb.sh >/dev/null 2>&1 &")
  HTTP.redirect(DISP.build_url("admin", "services", "openclash"))
end

---- Dashboard Settings
o = s:taboption("dashboard", Value, "cn_port")
o.title = translate("Dashboard Port")
o.default = 9090
o.datatype = "port"
o.rmempty = false
o.description = translate("Dashboard Address Example: 192.168.1.1/openclash、192.168.1.1:9090/ui")

o = s:taboption("dashboard", Value, "dashboard_password")
o.title = translate("Dashboard Secret")
o.default = 123456
o.rmempty = false
o.description = translate("Set Dashboard Secret")

-- [[ Edit Server ]] --
s = m:section(TypedSection, "dns_servers", translate("Add Custom DNS Servers"))
s.anonymous = true
s.addremove = true
s.sortable = false
s.template = "cbi/tblsection"
s.rmempty = false

---- enable flag
o = s:option(Flag, "enabled", translate("Enable"), translate("(Enable or Disable)"))
o.rmempty     = false
o.default     = o.enabled
o.cfgvalue    = function(...)
    return Flag.cfgvalue(...) or "1"
end

---- group
o = s:option(ListValue, "group", translate("DNS Server Group"))
o.description = translate("(NameServer Group Must Be Set)")
o:value("nameserver", translate("NameServer"))
o:value("fallback", translate("FallBack"))
o.default     = "nameserver"
o.rempty      = false

---- IP address
o = s:option(Value, "ip", translate("DNS Server Address"))
o.description = translate("(Do Not Add Type Ahead)")
o.placeholder = translate("Not Null")
o.datatype = "or(host, string)"
o.rmempty = true

---- port
o = s:option(Value, "port", translate("DNS Server Port"))
o.description = translate("(Require When Use Non-Standard Port)")
o.datatype    = "port"
o.rempty      = true

---- type
o = s:option(ListValue, "type", translate("DNS Server Type"))
o.description = translate("(Communication protocol)")
o:value("udp", translate("UDP"))
o:value("tcp", translate("TCP"))
o:value("tls", translate("TLS"))
o:value("https", translate("HTTPS"))
o.default     = "udp"
o.rempty      = false

-- [[ Edit Authentication ]] --
s = m:section(TypedSection, "authentication", translate("Set Authentication of SOCKS5/HTTP(S)"))
s.anonymous = true
s.addremove = true
s.sortable = false
s.template = "cbi/tblsection"
s.rmempty = false

---- enable flag
o = s:option(Flag, "enabled", translate("Enable"))
o.rmempty     = false
o.default     = o.enabled
o.cfgvalue    = function(...)
    return Flag.cfgvalue(...) or "1"
end

---- username
o = s:option(Value, "username", translate("Username"))
o.placeholder = translate("Not Null")
o.rempty      = true

---- password
o = s:option(Value, "password", translate("Password"))
o.placeholder = translate("Not Null")
o.rmempty = true

local apply = HTTP.formvalue("cbi.apply")
if apply then
	SYS.call("uci set openclash.config.enable=1 && uci commit openclash && /etc/init.d/openclash restart >/dev/null 2>&1 &")
  HTTP.redirect(DISP.build_url("admin", "services", "openclash"))
end

local commit = HTTP.formvalue("cbi.submit")
if commit then
	SYS.call("uci commit openclash")
end

return m


