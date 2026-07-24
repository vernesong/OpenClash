local NXFS = require "nixio.fs"
local SYS = require "luci.sys"
local HTTP = require "luci.http"
local fs = require "luci.openclash"
local DISP = require "luci.dispatcher"
local file_path = fs.get_file_path_from_request()

if not file_path then
	HTTP.redirect(DISP.build_url("admin", "services", "openclash", "%s") % arg[1])
	return
end

m = Map("openclash", translate("File Edit"))
m.pageaction = false
m.redirect = DISP.build_url("admin", "services", "openclash", "other-file-edit", "%s") % arg[1].."?file="..HTTP.urlencode(file_path)
s = m:section(TypedSection, "openclash")
s.anonymous = true
s.addremove=false

o = s:option(TextValue, "edit_file")
o.rows = 50
o.wrap = "off"

function o.write(self, section, value)
	if value then
		value = value:gsub("\r\n?", "\n")
		local old_value = fs.readfile(file_path)
		if value ~= old_value then
			fs.writefile(file_path, value)
		end
	end
	return true
end

function o.cfgvalue(self, section)
	return fs.readfile(file_path) or ""
end

local t = {
	{Commit, Back}
}

a = m:section(Table, t)

o = a:option(Button, "Commit", " ")
o.inputtitle = translate("Commit Settings")
o.inputstyle = "apply"
o.write = function()
	HTTP.redirect(m.redirect)
end

o = a:option(Button,"Back", " ")
o.inputtitle = translate("Back Settings")
o.inputstyle = "reset"
o.write = function()
	HTTP.redirect(DISP.build_url("admin", "services", "openclash", "%s") % arg[1])
end

m:append(Template("openclash/config_editor"))
m:append(Template("openclash/toolbar_show"))
return m