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

file_path = NXFS.realpath(file_path)
if not file_path then HTTP.status(404, "File not found"); return end
if file_path:match("^/etc/openclash/config/") then
	HTTP.redirect(DISP.build_url("admin", "services", "openclash", "config-edit") .. "?file=" .. HTTP.urlencode(file_path))
	return
end
if not (file_path:match("^/etc/openclash/proxy_provider/[^/]+$") or file_path:match("^/etc/openclash/rule_provider/[^/]+$")) then
	HTTP.status(403, "Invalid provider file path")
	return
end
if file_path:lower():match("%.mrs$") then
	HTTP.status(403, "Binary rule providers cannot be edited as text")
	return
end

local stream_fd
HTTP.setfilehandler(
	function(meta, chunk, eof)
		if not meta or meta.name ~= "oc_editor_content" then
			return
		end

		if not stream_fd and chunk then
			stream_fd = nixio.open(file_path, "w")
		end

		if stream_fd and chunk then
			stream_fd:write(chunk)
		end

		if eof and stream_fd then
			stream_fd:close()
			stream_fd = nil
		end
	end
)

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
	if value and value ~= "oc-editor-streamed" then
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

local editor = Template("openclash/config_editor")
editor.form_action = m.redirect
m:append(editor)
return m
