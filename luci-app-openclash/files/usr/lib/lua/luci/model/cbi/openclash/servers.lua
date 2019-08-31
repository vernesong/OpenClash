-- Licensed to the public under the GNU General Public License v3.

local m, s, o
local openclash = "openclash"

local uci = luci.model.uci.cursor()

m = Map(openclash,  translate("Servers manage and Config create"))
m.pageaction = false

s = m:section(TypedSection, "openclash")
s.anonymous = true

o = s:option(ListValue, "rule_sources", translate("Choose Template For Create Config"))
o.description = translate("Use Other Rules To Create Config")
o.default = "0"
o:value("0", translate("Disable Create Config"))
o:value("lhie1", translate("lhie1 Rules"))
o:value("ConnersHua", translate("ConnersHua Rules"))
o:value("ConnersHua_return", translate("ConnersHua Return Rules"))

local t = {
    {Commit, Apply, Load_Severs, Delete_Severs}
}

a = m:section(Table, t)

o = a:option(Button, "Commit") 
o.inputtitle = translate("Commit Configurations")
o.inputstyle = "apply"
o.write = function()
  uci:commit("openclash")
end

o = a:option(Button, "Apply")
o.inputtitle = translate("Apply Configurations")
o.inputstyle = "apply"
o.write = function()
  uci:set("openclash", "config", "enable", 1)
  uci:commit("openclash")
  luci.sys.call("/usr/share/openclash/yml_proxys_set.sh >/dev/null 2>&1 &")
  luci.http.redirect(luci.dispatcher.build_url("admin", "services", "openclash"))
end

o = a:option(Button,"Load_Severs")
o.inputtitle = translate("Load Config Severs")
o.inputstyle = "apply"
o.write = function()
  uci:delete_all("openclash", "servers", function(s) return true end)
  luci.sys.call("sh /usr/share/openclash/yml_proxys_get.sh 2>/dev/null") 
  luci.http.redirect(luci.dispatcher.build_url("admin", "services", "openclash", "servers"))
end

o = a:option(Button,"Delete_Severs")
o.inputtitle = translate("Delete severs")
o.inputstyle = "reset"
o.write = function()
  uci:delete_all("openclash", "servers", function(s) return true end)
  luci.sys.call("uci commit openclash") 
  luci.http.redirect(luci.dispatcher.build_url("admin", "services", "openclash", "servers"))
end

-- [[ Servers Manage ]]--
s = m:section(TypedSection, "servers")
s.anonymous = true
s.addremove = true
s.sortable = false
s.template = "cbi/tblsection"
s.extedit = luci.dispatcher.build_url("admin/services/openclash/servers/%s")
function s.create(...)
	local sid = TypedSection.create(...)
	if sid then
		luci.http.redirect(s.extedit % sid)
		return
	end
end

o = s:option(DummyValue, "type", translate("Type"))
function o.cfgvalue(...)
	return Value.cfgvalue(...) or translate("None")
end

o = s:option(DummyValue, "name", translate("Alias"))
function o.cfgvalue(...)
	return Value.cfgvalue(...) or translate("None")
end

o = s:option(DummyValue, "server", translate("Server Address"))
function o.cfgvalue(...)
	return Value.cfgvalue(...) or translate("None")
end

o = s:option(DummyValue, "port", translate("Server Port"))
function o.cfgvalue(...)
	return Value.cfgvalue(...) or translate("None")
end


return m
