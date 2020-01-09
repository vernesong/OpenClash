
local m, s, o
local openclash = "openclash"
local uci = luci.model.uci.cursor()
local fs = require "nixio.fs"
local sys = require "luci.sys"
local sid = arg[1]

font_red = [[<font color="red">]]
font_off = [[</font>]]
bold_on  = [[<strong>]]
bold_off = [[</strong>]]

m = Map(openclash, translate("Edit Proxy-Provider"))
m.pageaction = false
m.redirect = luci.dispatcher.build_url("admin/services/openclash/servers")
if m.uci:get(openclash, sid) ~= "proxy-provider" then
	luci.http.redirect(m.redirect)
	return
end

-- [[ Provider Setting ]]--
s = m:section(NamedSection, sid, "proxy-provider")
s.anonymous = true
s.addremove   = false

o = s:option(ListValue, "type", translate("Provider Type"))
o.rmempty = true
o.description = translate("Choose The Provider Type")
o:value("http")
o:value("file")

o = s:option(Value, "name", translate("Provider Name"))
o.rmempty = false

o = s:option(Value, "path", translate("Provider Path"))
o.description = translate("【HTTP Type】./hk.yaml or 【File Type】/etc/openclash/config/hk.yaml")
o.rmempty = false

o = s:option(Value, "provider_url", translate("Provider URL"))
o.rmempty = false
o:depends("type", "http")

o = s:option(Value, "provider_interval", translate("Provider Interval(s)"))
o.default = "3600"
o.rmempty = false
o:depends("type", "http")

o = s:option(ListValue, "health_check", translate("Provider Health Check"))
o:value("false", translate("Disable"))
o:value("true", translate("Enable"))
o.default=true

o = s:option(Value, "health_check_url", translate("Health Check URL"))
o.default = "http://www.gstatic.com/generate_204"
o.rmempty = false

o = s:option(Value, "health_check_interval", translate("Health Check Interval(s)"))
o.default = "300"
o.rmempty = false

o = s:option(DynamicList, "groups", translate("Proxy Group"))
o.description = font_red..bold_on..translate("No Need Set when Config Create, The added Proxy Groups Must Exist")..bold_off..font_off
o.rmempty = true
m.uci:foreach("openclash", "groups",
		function(s)
			o:value(s.name)
		end)

local t = {
    {Commit, Back}
}
a = m:section(Table, t)

o = a:option(Button,"Commit")
o.inputtitle = translate("Commit Configurations")
o.inputstyle = "apply"
o.write = function()
   m.uci:commit(openclash)
   luci.http.redirect(m.redirect)
end

o = a:option(Button,"Back")
o.inputtitle = translate("Back Configurations")
o.inputstyle = "reset"
o.write = function()
   m.uci:revert(openclash)
   luci.http.redirect(m.redirect)
end

return m
