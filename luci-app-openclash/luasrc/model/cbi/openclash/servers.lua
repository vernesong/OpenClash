
local m, s, o
local openclash = "openclash"
local uci = luci.model.uci.cursor()
local fs = require "luci.openclash"
local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"
local file_path = fs.get_file_path_from_request()

local function commit_all()
	uci:commit("openclash")
end

if not file_path then
	HTTP.redirect(DISP.build_url("admin", "services", "openclash", "config"))
	return
end

m = Map(openclash, translate("Servers & Groups manage"))
m.uci = uci
m.pageaction = false
m.redirect = DISP.build_url("admin/services/openclash/servers") .. "?file=" .. HTTP.urlencode(file_path)
m.description=translate("Attention:")..
"<br/>"..translate("1. Before modifying the configuration file, please click the button below to read the configuration file")..
"<br/>"..translate("2. Proxy-providers address can be directly filled in the subscription link")..
"<br/>"..
"<br/>"..translate("Introduction to proxy usage:").." <a href='javascript:void(0)' onclick='javascript:return winOpen(\"https://wiki.metacubex.one/config/proxies/\")'>"..translate("https://wiki.metacubex.one/config/proxies/").."</a>"..
"<br/>"..translate("Introduction to proxy-provider usage:").." <a href='javascript:void(0)' onclick='javascript:return winOpen(\"https://wiki.metacubex.one/config/proxy-providers/\")'>"..translate("https://wiki.metacubex.one/config/proxy-providers/").."</a>"

-- [[ Groups Manage ]]--
gs = m:section(TypedSection, "proxy_groups", translate("Proxy Groups"))
gs.config = "proxy_groups"
gs.anonymous = true
gs.addremove = true
gs.sortable = true
gs.template = "openclash/tblsection"
gs.extedit = DISP.build_url("admin/services/openclash/proxy-groups-config/%s").."?file="..file_path
function gs.create(self, section)
	local sid = TypedSection.create(self, section)
	if sid then
		local name = HTTP.formvalue("cbi.cts.tagname.".. self.config .. "." .. self.sectiontype)
		if name and #name > 0 then
			self.map:set(sid, "config", name)
		end
		HTTP.redirect(gs.extedit % sid)
		return
	end
end

---- enable flag
o = gs:option(Flag, "enabled", translate("Enable"))
o.rmempty = false
o.default = o.enabled
o.cfgvalue = function(...)
	return Flag.cfgvalue(...) or "1"
end

o = gs:option(DummyValue, "config", translate("Config File"))
function o.cfgvalue(...)
	return Value.cfgvalue(...) or translate("all")
end

o = gs:option(DummyValue, "type", translate("Group Type"))
function o.cfgvalue(...)
	return Value.cfgvalue(...) or translate("None")
end

o = gs:option(DummyValue, "name", translate("Group Name"))
function o.cfgvalue(...)
	return Value.cfgvalue(...) or translate("None")
end

-- [[ Proxy-Provider Manage ]]--
ps = m:section(TypedSection, "proxy_providers", translate("Proxy-Provider"))
ps.config = "proxy_providers"
ps.anonymous = true
ps.addremove = true
ps.sortable = true
ps.template = "openclash/tblsection"
ps.extedit = DISP.build_url("admin/services/openclash/proxy-providers-config/%s").."?file="..file_path
function ps.create(self, section)
	local sid = TypedSection.create(self, section)
	if sid then
		local name = HTTP.formvalue("cbi.cts.tagname.".. self.config .. "." .. self.sectiontype)
		if name and #name > 0 then
			self.map:set(sid, "config", name)
		end
		HTTP.redirect(ps.extedit % sid)
		return
	end
end

o = ps:option(Flag, "enabled", translate("Enable"))
o.rmempty = false
o.default = o.enabled
o.cfgvalue = function(...)
	return Flag.cfgvalue(...) or "1"
end

o = ps:option(DummyValue, "config", translate("Config File"))
function o.cfgvalue(...)
	return Value.cfgvalue(...) or translate("all")
end

o = ps:option(DummyValue, "type", translate("Provider Type"))
function o.cfgvalue(...)
	return Value.cfgvalue(...) or translate("None")
end

o = ps:option(DummyValue, "name", translate("Provider Name"))
function o.cfgvalue(...)
	return Value.cfgvalue(...) or translate("None")
end

-- [[ Servers Manage ]]--
ss = m:section(TypedSection, "proxies", translate("Proxies"))
ss.config = "proxies"
ss.anonymous = true
ss.addremove = true
ss.sortable = true
ss.template = "openclash/tblsection"
ss.extedit = DISP.build_url("admin/services/openclash/proxies-config/%s").."?file="..file_path
function ss.create(self, section)
	local sid = TypedSection.create(self, section)
	if sid then
		local name = HTTP.formvalue("cbi.cts.tagname.".. self.config .. "." .. self.sectiontype)
		if name and #name > 0 then
			self.map:set(sid, "config", name)
		end
		HTTP.redirect(ss.extedit % sid)
		return
	end
end

---- enable flag
o = ss:option(Flag, "enabled", translate("Enable"))
o.rmempty = false
o.default = o.enabled
o.cfgvalue = function(...)
	return Flag.cfgvalue(...) or "1"
end

o = ss:option(DummyValue, "config", translate("Config File"))
function o.cfgvalue(...)
	return Value.cfgvalue(...) or translate("all")
end

o = ss:option(DummyValue, "type", translate("Type"))
function o.cfgvalue(...)
	return Value.cfgvalue(...) or translate("None")
end

o = ss:option(DummyValue, "name", translate("Server Alias"))
function o.cfgvalue(...)
	return Value.cfgvalue(...) or translate("None")
end

o = ss:option(DummyValue, "server", translate("Server Address"))
function o.cfgvalue(...)
	return Value.cfgvalue(...) or translate("None")
end

o = ss:option(DummyValue, "port", translate("Server Port"))
function o.cfgvalue(...)
	return Value.cfgvalue(...) or translate("None")
end

o = ss:option(DummyValue, "udp", translate("UDP Support"))
function o.cfgvalue(...)
	if Value.cfgvalue(...) == "true" then
		return translate("Enable")
	elseif Value.cfgvalue(...) == "false" then
		return translate("Disable")
	else
		return translate("None")
	end
end

local tt = {
	{Delete_Unused_Servers, Delete_Servers, Delete_Proxy_Provider, Delete_Groups}
}

b = m:section(Table, tt)

o = b:option(Button,"Delete_Unused_Servers", " ")
o.inputtitle = translate("Delete Unused Servers")
o.inputstyle = "reset"
o.write = function()
	m.uci:foreach("openclash", "proxies",
	function(s)
		if s.enabled ~= "1" then
			m.uci:delete("openclash", s[".name"])
		end
	end)
	commit_all()
	HTTP.redirect(m.redirect)
end

o = b:option(Button,"Delete_Servers", " ")
o.inputtitle = translate("Delete Servers")
o.inputstyle = "reset"
o.write = function()
	m.uci:delete_all("openclash", "proxies", function(s) return true end)
	commit_all()
	HTTP.redirect(m.redirect)
end

o = b:option(Button,"Delete_Proxy_Provider", " ")
o.inputtitle = translate("Delete Proxy Providers")
o.inputstyle = "reset"
o.write = function()
	m.uci:delete_all("openclash", "proxy_providers", function(s) return true end)
	commit_all()
	HTTP.redirect(m.redirect)
end

o = b:option(Button,"Delete_Groups", " ")
o.inputtitle = translate("Delete Groups")
o.inputstyle = "reset"
o.write = function()
	m.uci:delete_all("openclash", "proxy_groups", function(s) return true end)
	commit_all()
	HTTP.redirect(m.redirect)
end

local t = {
	{Load_Config, Commit, Apply, Back}
}

a = m:section(Table, t)

o = a:option(Button,"Load_Config", " ")
o.inputtitle = translate("Read Config")
o.inputstyle = "apply"
o.write = function()
	commit_all()
	luci.sys.call("/usr/share/openclash/yml_groups_get.sh \"%s\" 2>/dev/null" % file_path)
	HTTP.redirect(m.redirect)
end

o = a:option(Button, "Commit", " ") 
o.inputtitle = translate("Commit Settings")
o.inputstyle = "apply"
o.write = function()
	commit_all()
	HTTP.redirect(m.redirect)
end

o = a:option(Button, "Apply", " ")
o.inputtitle = translate("Apply Settings")
o.inputstyle = "apply"
o.write = function()
	commit_all()
	luci.sys.call("/usr/share/openclash/yml_groups_set.sh \"%s\" >/dev/null 2>&1 &" % file_path)
	HTTP.redirect(m.redirect)
end

o = a:option(Button,"Back", " ")
o.inputtitle = translate("Back Settings")
o.inputstyle = "apply"
o.write = function()
	HTTP.redirect(DISP.build_url("admin", "services", "openclash", "config"))
end

m:append(Template("openclash/toolbar_show"))

return m
