--
local NXFS = require "nixio.fs"
local SYS  = require "luci.sys"
local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"
local UTIL = require "luci.util"

m = Map("openclash", translate("Update Setting"))
s = m:section(TypedSection, "openclash", translate("Subscription Update"))
s.anonymous = true

o = s:option(Flag, "auto_update", translate("Auto Update"))
o.description = translate("Auto Update Server subscription")
o.default=0
o.rmempty = false

o = s:option(ListValue, "auto_update_time", translate("Update time (every day)"))
for t = 0,23 do
o:value(t, t..":00")
end
o.default=0
o.rmempty = false

o = s:option(Value, "subscribe_url")
o.title = translate("Subcription Url")
o.description = translate("Server Subscription Address")
o.rmempty = true

o = s:option(Button,translate("Config File Update")) 
o.title = translate("Update Subcription")
o.inputtitle = translate("Update Configuration")
o.inputstyle = "reload"
o.write = function()
  SYS.call("uci commit openclash && sh /usr/share/openclash/openclash.sh >/dev/null 2>&1 &")
  HTTP.redirect(DISP.build_url("admin", "services", "openclash"))
end

f = m:section(TypedSection, "openclash", translate("Other Rules Update(Only in Use)"))
f.anonymous = true
o = f:option(Flag, "other_rule_auto_update", translate("Auto Update"))
o.description = translate("Auto Update Other Rules")
o.default=0
o.rmempty = false

o = f:option(ListValue, "other_rule_update_week_time", translate("Update Time (Every Week)"))
o:value("1", translate("Every Monday"))
o:value("2", translate("Every Tuesday"))
o:value("3", translate("Every Wednesday"))
o:value("4", translate("Every Thursday"))
o:value("5", translate("Every Friday"))
o:value("6", translate("Every Saturday"))
o:value("7", translate("Every Sunday"))
o.default=1

o = f:option(ListValue, "other_rule_update_day_time", translate("Update time (every day)"))
for t = 0,23 do
o:value(t, t..":00")
end
o.default=0

o = f:option(Button,translate("Other Rules Update")) 
o.title = translate("Update Other Rules")
o.inputtitle = translate("Start Update Other Rules")
o.inputstyle = "reload"
o.write = function()
  SYS.call("uci commit openclash && sh /usr/share/openclash/openclash_rule.sh >/dev/null 2>&1 &")
  HTTP.redirect(DISP.build_url("admin", "services", "openclash"))
end

u = m:section(TypedSection, "openclash", translate("GEOIP(By MaxMind) Update"))
u.anonymous = true
o = u:option(Button,translate("GEOIP Database Update")) 
o.title = translate("Update GEOIP Database")
o.inputtitle = translate("Start Update GEOIP Database")
o.inputstyle = "reload"
o.write = function()
  SYS.call("sh /usr/share/openclash/openclash_ipdb.sh >/dev/null 2>&1 &")
  HTTP.redirect(DISP.build_url("admin", "services", "openclash"))
end

local t = {
    {Commit}
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

return m , a
