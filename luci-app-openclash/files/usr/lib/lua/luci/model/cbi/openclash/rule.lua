--
local NXFS = require "nixio.fs"
local SYS  = require "luci.sys"
local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"
local UTIL = require "luci.util"

m = Map("openclash", translate("Rules Setting"))
s = m:section(TypedSection, "openclash")
s.anonymous = true

o = s:option(ListValue, "enable_custom_clash_rules", translate("Custom Clash Rules"))
o.description = translate("Use Custom Rules")
o:value("0", translate("Disable Custom Clash Rules"))
o:value("1", translate("Enable Custom Clash Rules"))
o.default = 0

o = s:option(ListValue, "rule_source", translate("Enable Other Rules"))
o.description = translate("Use Other Rules")
o:value("0", translate("Disable Other Rules"))
o:value("lhie1", translate("lhie1 Rules"))
o:value("ConnersHua", translate("ConnersHua Rules"))
o:value("ConnersHua_return", translate("ConnersHua Return Rules"))

os.execute("awk '/Proxy Group:/,/Rule:/{print}' /etc/openclash/config.yaml |grep ^-  |grep name: |sed 's/,.*//' |awk -F 'name: ' '{print $2}' |sed 's/\"//g' >/tmp/Proxy_Group 2>&1")
os.execute("echo 'DIRECT' >>/tmp/Proxy_Group")
os.execute("echo 'REJECT' >>/tmp/Proxy_Group")
file = io.open("/tmp/Proxy_Group", "r"); 

o = s:option(ListValue, "GlobalTV", translate("GlobalTV"))
o:depends("rule_source", "lhie1")
o:depends("rule_source", "ConnersHua")
 for l in file:lines() do
   o:value(l)
   end
   file:seek("set")
o = s:option(ListValue, "AsianTV", translate("AsianTV"))
o:depends("rule_source", "lhie1")
o:depends("rule_source", "ConnersHua")
 for l in file:lines() do
   o:value(l)
   end
   file:seek("set")
o = s:option(ListValue, "Proxy", translate("Proxy"))
o:depends("rule_source", "lhie1")
o:depends("rule_source", "ConnersHua")
o:depends("rule_source", "ConnersHua_return")
 for l in file:lines() do
   o:value(l)
   end
   file:seek("set")
o = s:option(ListValue, "Apple", translate("Apple"))
o:depends("rule_source", "lhie1")
o:depends("rule_source", "ConnersHua")
 for l in file:lines() do
   o:value(l)
   end
   file:seek("set")
o = s:option(ListValue, "AdBlock", translate("AdBlock"))
o:depends("rule_source", "lhie1")
o:depends("rule_source", "ConnersHua")
 for l in file:lines() do
   o:value(l)
   end
   file:seek("set")
o = s:option(ListValue, "Domestic", translate("Domestic"))
o:depends("rule_source", "lhie1")
o:depends("rule_source", "ConnersHua")
 for l in file:lines() do
   o:value(l)
   end
   file:seek("set")
o = s:option(ListValue, "Others", translate("Others"))
o:depends("rule_source", "lhie1")
o:depends("rule_source", "ConnersHua")
o:depends("rule_source", "ConnersHua_return")
o.description = translate("Choose Proxy Group, Base On Your Servers Group in config.yaml")
 for l in file:lines() do
   o:value(l)
   end
   file:close()

custom_rules = s:option(Value, "custom_rules", translate("Custom Clash Rules Here"), translate("For More Go Github:https://github.com/Dreamacro/clash"))
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

local t = {
    {Commit, Apply}
}

a = SimpleForm("apply")
a.reset = false
a.submit = false
s = a:section(Table, t)

o = s:option(Button, "Commit") 
o.inputtitle = translate("Commit Configurations")
o.inputstyle = "apply"
o.write = function()
  os.execute("uci commit openclash")
end

o = s:option(Button, "Apply")
o.inputtitle = translate("Apply Configurations")
o.inputstyle = "apply"
o.write = function()
  os.execute("uci set openclash.config.enable=1 && uci commit openclash && /etc/init.d/openclash restart >/dev/null 2>&1 &")
  HTTP.redirect(DISP.build_url("admin", "services", "openclash"))
end

return m , a
