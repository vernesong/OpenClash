
local m, s, o
local openclash = "openclash"
local NXFS = require "nixio.fs"
local SYS  = require "luci.sys"
local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"
local UTIL = require "luci.util"
local uci = require "luci.model.uci".cursor()

font_red = [[<font color="red">]]
font_off = [[</font>]]
bold_on  = [[<strong>]]
bold_off = [[</strong>]]

m = Map(openclash,  translate("Config Update"))
m.pageaction = false

s = m:section(TypedSection, "openclash")
s.anonymous = true

---- update Settings
o = s:option(ListValue, "auto_update", translate("Auto Update"))
o.description = translate("Auto Update Server subscription")
o:value("0", translate("Disable"))
o:value("1", translate("Enable"))
o.default=0

o = s:option(ListValue, "config_update_week_time", translate("Update Time (Every Week)"))
o:value("*", translate("Every Day"))
o:value("1", translate("Every Monday"))
o:value("2", translate("Every Tuesday"))
o:value("3", translate("Every Wednesday"))
o:value("4", translate("Every Thursday"))
o:value("5", translate("Every Friday"))
o:value("6", translate("Every Saturday"))
o:value("0", translate("Every Sunday"))
o.default=1

o = s:option(ListValue, "auto_update_time", translate("Update time (every day)"))
for t = 0,23 do
o:value(t, t..":00")
end
o.default=0
o.rmempty = false

o = s:option(Button, translate("Config File Update")) 
o.title = translate("Update Subcription")
o.inputtitle = translate("Check And Update")
o.inputstyle = "reload"
o.write = function()
  m.uci:set("openclash", "config", "enable", 1)
  m.uci:commit("openclash")
  local config_name=string.sub(luci.sys.exec("uci get openclash.config.config_path"), 23, -2)
  SYS.call("rm -rf /etc/openclash/backup/* 2>/dev/null")
  SYS.call("/usr/share/openclash/openclash.sh >/dev/null 2>&1 &")
  HTTP.redirect(DISP.build_url("admin", "services", "openclash"))
end

-- [[ Edit Server ]] --
s = m:section(TypedSection, "config_subscribe")
s.anonymous = true
s.addremove = true
s.sortable = false
s.template = "cbi/tblsection"
s.rmempty = false

---- enable flag
o = s:option(Flag, "enabled", translate("Enable"), font_red..bold_on..translate("(Enable or Disable Subscribe)")..bold_off..font_off)
o.rmempty     = false
o.default     = o.enabled
o.cfgvalue    = function(...)
    return Flag.cfgvalue(...) or "1"
end

---- name
o = s:option(Value, "name", translate("Config Alias"))
o.description = font_red..bold_on..translate("(Name For Distinguishing)")..bold_off..font_off
o.placeholder = translate("config")
o.rmempty = true

---- type
o = s:option(ListValue, "type", translate("Subscribe Type"))
o.description = font_red..bold_on..translate("(Power By fndroid)")..bold_off..font_off
o:value("clash", translate("Clash"))
o:value("v2rayn", translate("V2rayN"))
o:value("surge", translate("Surge"))
o.default="clash"
o.rempty      = false

---- address
o = s:option(Value, "address", translate("Subscribe Address"))
o.description = font_red..bold_on..translate("(Not Null)")..bold_off..font_off
o.placeholder = translate("Not Null")
o.datatype = "or(host, string)"
o.rmempty = true

---- key
o = s:option(DynamicList, "keyword", font_red..bold_on..translate("Keyword Match")..bold_off..font_off)
o.description = font_red..bold_on..translate("(eg: hk or tw&bgp)")..bold_off..font_off
o.rmempty = true

local t = {
    {Commit, Apply}
}

a = m:section(Table, t)

o = a:option(Button, "Commit") 
o.inputtitle = translate("Commit Configurations")
o.inputstyle = "apply"
o.write = function()
  m.uci:commit("openclash")
end

o = a:option(Button, "Apply")
o.inputtitle = translate("Apply Configurations")
o.inputstyle = "apply"
o.write = function()
  m.uci:set("openclash", "config", "enable", 1)
  m.uci:commit("openclash")
  SYS.call("/etc/init.d/openclash restart >/dev/null 2>&1 &")
  HTTP.redirect(DISP.build_url("admin", "services", "openclash"))
end

return m
