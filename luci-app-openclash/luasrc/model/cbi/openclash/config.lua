
local NXFS = require "nixio.fs"
local SYS = require "luci.sys"
local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"
local fs = require "luci.openclash"
local uci = require("luci.model.uci").cursor()
local profiles = require "luci.openclash_profiles"
local function default_config_set(f)
	local cf = fs.uci_get_config("config", "config_path")
	if cf == "/etc/openclash/config/"..f or not cf or cf == "" or not fs.isfile(cf) then
		local fis = fs.glob("/etc/openclash/config/*")[1]
		if fis ~= nil then
			local fcf = fs.basename(fis)
			if fcf then
				uci:set("openclash", "config", "config_path", "/etc/openclash/config/"..fcf)
				uci:commit("openclash")
			end
		else
			uci:set("openclash", "config", "config_path", "/etc/openclash/config/config.yaml")
			uci:commit("openclash")
		end
	end
end

local e = profiles.list(fs, uci)
local running_name = profiles.running_name(NXFS, SYS)
for _, row in ipairs(e) do
	row.mtime = row.exists and os.date("%Y-%m-%d %H:%M:%S", row.stat.mtime) or "-"
	row.state = row.current and "Enabled" or "Disabled"
	row.size = row.exists and fs.filesize(row.stat.size) or "-"
	row.source = row.remote and translate("Remote") or translate("Local")
	row.update = row.remote and (row.automatic and translate("Yes") or translate("No")) or "-"
end

form=SimpleForm("config_file_list",translate("Config Manage"))
form.template="openclash/management_form"
form.reset=false
form.submit=false
tb=form:section(Table,e)
st=tb:option(DummyValue,"state",translate("State"))
nm=tb:option(DummyValue,"name",translate("Config Alias"))
tb:option(DummyValue,"source",translate("Source"))
tb:option(DummyValue,"update",translate("Auto Update"))
sb=tb:option(DummyValue,"name",translate("Subscription Info"))
mt=tb:option(DummyValue,"mtime",translate("Update Time"))
sz=tb:option(DummyValue,"size",translate("Size"))
st.template="openclash/cfg_check"
sb.template="openclash/sub_info_show"
sb.render = function(self, section, scope)
	scope = scope or {}
	scope.unified_config = true
	DummyValue.render(self, section, scope)
end

local btnapply = tb:option(Button, "apply", translate("Actions"))
btnapply.template = "openclash/config_actions"
btnapply.render = function(self, section, scope)
	if not e[section] then return end
	scope = scope or {}
	scope.config_name = e[section].name
	scope.is_yaml = fs.IsYamlExt(e[section].name)
	scope.is_current = e[section].current
	scope.is_running = running_name == e[section].name
	scope.has_running = scope.is_running and NXFS.access("/etc/openclash/" .. e[section].name)
	scope.config_script = not self.script_rendered
	scope.has_file = e[section].exists
	scope.has_subscription = e[section].remote
	scope.source_editable = e[section].editable
	scope.unified_config = true
	self.script_rendered = true
	Button.render(self, section, scope)
end
btnapply.inputstyle = "apply"
btnapply.write = function(self, t)
	if not e[t] then return end
	local action = self.map:formvalue("cbid." .. self.map.config .. "." .. t .. ".actions")
	if action == "download_run" and running_name ~= e[t].name then return end
	if (action == "rename" or action == "remove") and running_name == e[t].name then return end
	if not e[t].exists and action ~= "edit" and action ~= "remove" then return end

	if action == "switch" and fs.IsYamlExt(e[t].name) then
		uci:set("openclash", "config", "config_path", "/etc/openclash/config/" .. e[t].name)
		uci:commit("openclash")
		HTTP.redirect(DISP.build_url("admin", "services", "openclash", "config"))
	elseif action == "edit" then
		local file_path = "/etc/openclash/config/" .. fs.basename(e[t].name)
		HTTP.redirect(DISP.build_url("admin", "services", "openclash", "config-edit") .. "?file=" .. HTTP.urlencode(file_path))
	elseif action == "servers_manage" and e[t].editable then
		local file_path = "/etc/openclash/config/" .. fs.basename(e[t].name)
		HTTP.redirect(DISP.build_url("admin", "services", "openclash", "servers") .. "?file=" .. HTTP.urlencode(file_path))
	elseif action == "copy" then
		local num = 1
		while true do
			num = num + 1
			if not fs.isfile("/etc/openclash/config/"..fs.filename(e[t].name).."("..num..")"..".yaml") then
				fs.copy("/etc/openclash/config/"..e[t].name, "/etc/openclash/config/"..fs.filename(e[t].name).."("..num..")"..".yaml")
				break
			end
		end
		HTTP.redirect(DISP.build_url("admin", "services", "openclash", "config"))
	elseif action == "download" then
		local sPath, sFile, fd, block
		sPath = "/etc/openclash/config/"..e[t].name
		sFile = NXFS.basename(sPath)
		if fs.isdirectory(sPath) then
			fd = io.popen('tar -C "%s" -cz .' % {sPath}, "r")
			sFile = sFile .. ".tar.gz"
		else
			fd = nixio.open(sPath, "r")
		end
		if not fd then return end
		HTTP.header('Content-Disposition', 'attachment; filename="%s"' % {sFile})
		HTTP.prepare_content("application/octet-stream")
		while true do
			block = fd:read(nixio.const.buffersize)
			if (not block) or (#block == 0) then break end
			HTTP.write(block)
		end
		fd:close()
		HTTP.close()
	elseif action == "download_run" then
		local sPath, sFile, fd, block
		sPath = "/etc/openclash/"..e[t].name
		sFile = NXFS.basename(sPath)
		if fs.isdirectory(sPath) then
			fd = io.popen('tar -C "%s" -cz .' % {sPath}, "r")
			sFile = sFile .. ".tar.gz"
		else
			fd = nixio.open(sPath, "r")
		end
		if not fd then return end
		HTTP.header('Content-Disposition', 'attachment; filename="%s"' % {sFile})
		HTTP.prepare_content("application/octet-stream")
		while true do
			block = fd:read(nixio.const.buffersize)
			if (not block) or (#block == 0) then break end
			HTTP.write(block)
		end
		fd:close()
		HTTP.close()
	elseif action == "remove" then
		local file_name = fs.basename(e[t].name)
		fs.config_refs(file_name, nil, e[t].preserve_subscription)
		SYS.call("/etc/init.d/openclash reload cron >/dev/null 2>&1")
		if not e[t].preserve_subscription then fs.unlink("/etc/openclash/history/"..fs.filename(e[t].name)..".db") end
		fs.unlink("/etc/openclash/"..file_name)
		local a=fs.unlink("/etc/openclash/config/"..file_name)
		default_config_set(fs.basename(e[t].name))
		if a then table.remove(e,t) end
		HTTP.redirect(DISP.build_url("admin", "services", "openclash","config"))
	end
end

form:append(Template("openclash/config_upload"))
local render_children = form.render_children
form.render_children = function(self, ...)
	fs.render_page_head()
	luci.template.render("openclash/config_resources")
	luci.template.render("openclash/config_add")
	render_children(self, ...)
end

return form, require("luci.openclash_resources").schedule()
