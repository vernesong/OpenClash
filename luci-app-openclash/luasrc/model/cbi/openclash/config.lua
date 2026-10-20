
local NXFS = require "nixio.fs"
local SYS = require "luci.sys"
local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"
local UTIL = require "luci.util"
local fs = require "luci.openclash"
local uci = require("luci.model.uci").cursor()
local CHIF = "0"

font_green = [[<b class="oc-txt-good">]]
font_off = [[</b>]]
bold_on = [[<strong>]]
bold_off = [[</strong>]]
align_mid = [[<p align="center">]]
align_mid_off = [[</p>]]

function default_config_set(f)
	local cf = fs.uci_get_config("config", "config_path")
	if cf == "/etc/openclash/config/"..f or not cf or cf == "" or not fs.isfile(cf) then
		if CHIF == "1" and cf == "/etc/openclash/config/"..f then
			return
		end
		local fis = fs.glob("/etc/openclash/config/*")[1]
		if fis ~= nil then
			fcf = fs.basename(fis)
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

ful = SimpleForm("upload", translate("Config Manage"), nil)
ful.reset = false
ful.submit = false

sul =ful:section(SimpleSection, "")
o = sul:option(FileUpload, "")
o.template = "openclash/upload"
o.cfgvalue = function(self, section)
	return self.value
end

local dir, fd, clash
local conf = fs.uci_get_config("config", "config_path")
if not conf then conf = "/etc/openclash/config/config.yaml" end
local edit_fd
dir = "/etc/openclash/config/"
proxy_pro_dir="/etc/openclash/proxy_provider/"
rule_pro_dir="/etc/openclash/rule_provider/"
core_dir="/etc/openclash/core/core/"
backup_dir="/tmp/"

HTTP.setfilehandler(
	function(meta, chunk, eof)
		if meta and meta.name == "oc_editor_content" then
			if not edit_fd and chunk then
				edit_fd = nixio.open(conf, "w")
			end
			if edit_fd and chunk then
				edit_fd:write(chunk)
			end
			if eof and edit_fd then
				edit_fd:close()
				edit_fd = nil
			end
			return
		end

		local fp = HTTP.formvalue("file_type")
		if not fd then
			if not meta then return end

			if fp == "config" then
				if meta and chunk then fd = nixio.open(dir .. meta.file, "w") end
			elseif fp == "proxy-provider" then
				if meta and chunk then fd = nixio.open(proxy_pro_dir .. meta.file, "w") end
			elseif fp == "rule-provider" then
				if meta and chunk then fd = nixio.open(rule_pro_dir .. meta.file, "w") end
			elseif fp == "clash_meta" then
				create_core_dir=fs.mkdir(core_dir)
				if meta and chunk then fd = nixio.open(core_dir .. meta.file, "w") end
			elseif fp == "backup-file" then
				if meta and chunk then fd = nixio.open(backup_dir .. meta.file, "w") end
			end

			if not fd then
				o.value = translate("upload file error.")
				return
			end
		end
		if chunk and fd then
			fd:write(chunk)
		end
		if eof and fd then
			fd:close()
			fd = nil
			if fp == "config" then
				CHIF = "1"
				if fs.IsYamlExt(meta.file) then
					if string.lower(meta.file):sub(-4) ~= ".yml" then
						default_config_set(meta.file)
					else
						local ymlname=string.lower(string.sub(meta.file,0,-5))
						local c=fs.rename(dir .. meta.file,"/etc/openclash/config/".. ymlname .. ".yaml")
						default_config_set(ymlname .. ".yaml")
					end
				end
				o.value = translate("File saved to") .. ' "/etc/openclash/config/"'
			elseif fp == "proxy-provider" then
				o.value = translate("File saved to") .. ' "/etc/openclash/proxy_provider/"'
			elseif fp == "rule-provider" then
				o.value = translate("File saved to") .. ' "/etc/openclash/rule_provider/"'
			elseif fp == "clash_meta" then
				local archive_path = core_dir .. meta.file
				if string.lower(string.sub(meta.file, -7, -1)) == ".tar.gz" then
					-- tar.gz
					os.execute(string.format("tar -C '/etc/openclash/core/core' -xzf '%s' >/dev/null 2>&1", archive_path))
					os.execute(string.format("rm -f '%s' >/dev/null 2>&1", archive_path))
					local first_file_cmd = "find /etc/openclash/core/core -type f ! -name '*.tar.gz' ! -name '*.tar' ! -name '*.gz' 2>/dev/null | head -1"
					local first_file = io.popen(first_file_cmd):read("*line")
					if first_file and first_file ~= "" then
						os.execute(string.format("mv '%s' '/etc/openclash/core/%s' >/dev/null 2>&1", first_file, fp))
					end
				elseif string.lower(string.sub(meta.file, -4, -1)) == ".tar" then
					-- tar
					os.execute(string.format("tar -C '/etc/openclash/core/core' -xf '%s' >/dev/null 2>&1", archive_path))
					os.execute(string.format("rm -f '%s' >/dev/null 2>&1", archive_path))
					local first_file_cmd = "find /etc/openclash/core/core -type f ! -name '*.tar' ! -name '*.gz' 2>/dev/null | head -1"
					local first_file = io.popen(first_file_cmd):read("*line")
					if first_file and first_file ~= "" then
						os.execute(string.format("mv '%s' '/etc/openclash/core/%s' >/dev/null 2>&1", first_file, fp))
					end
				elseif string.lower(string.sub(meta.file, -3, -1)) == ".gz" then
					-- gz
					os.execute(string.format("gzip -fd '%s' >/dev/null 2>&1", archive_path))
					os.execute(string.format("rm -f '%s' >/dev/null 2>&1", archive_path))
					local first_file_cmd = "find /etc/openclash/core/core -type f ! -name '*.gz' 2>/dev/null | head -1"
					local first_file = io.popen(first_file_cmd):read("*line")
					if first_file and first_file ~= "" then
						os.execute(string.format("mv '%s' '/etc/openclash/core/%s' >/dev/null 2>&1", first_file, fp))
					end
				else
					os.execute(string.format("mv '%s' '/etc/openclash/core/%s' >/dev/null 2>&1", (core_dir .. meta.file), fp))
				end

				os.execute(string.format("chmod 4755 '/etc/openclash/core/%s' >/dev/null 2>&1", fp))
				os.execute(string.format("rm -rf %s >/dev/null 2>&1", core_dir))
				o.value = translate("File saved to") .. ' "/etc/openclash/core/"'
			elseif fp == "backup-file" then
				local archive = backup_dir .. meta.file
				if fs.restore_backup(archive) then
					o.value = translate("Backup File Restore Successful!")
				else
					o.value = translate("Backup File Restore Failed!")
				end
				fs.unlink(archive)
			end
		end
	end
)

if HTTP.formvalue("upload") then
	if not o.value then
		o.value = translate("No Specify Upload File")
	end
end

local e,a={}
for t,o in ipairs(fs.glob("/etc/openclash/config/*"))do
a=fs.stat(o)
if a then
e[t]={}
e[t].name=fs.basename(o)
e[t].mtime=os.date("%Y-%m-%d %H:%M:%S",a.mtime)
if fs.uci_get_config("config", "config_path") and string.sub(fs.uci_get_config("config", "config_path"), 23, -1) == e[t].name then
	e[t].state="Enabled"
else
	e[t].state="Disabled"
end
e[t].size=fs.filesize(a.size)
e[t].remove=0
end
end

form=SimpleForm("config_file_list",translate("Config File List"))
form.reset=false
form.submit=false
tb=form:section(Table,e)
st=tb:option(DummyValue,"state",translate("State"))
nm=tb:option(DummyValue,"name",translate("Config Alias"))
sb=tb:option(DummyValue,"name",translate("Subscription Info"))
mt=tb:option(DummyValue,"mtime",translate("Update Time"))
sz=tb:option(DummyValue,"size",translate("Size"))
st.template="openclash/cfg_check"
sb.template="openclash/sub_info_show"

local btnapply = tb:option(Button, "apply", translate("Actions"))
btnapply.template = "openclash/config_actions"
btnapply.render = function(self, section, scope)
	if not e[section] then return end
	scope = scope or {}
	scope.config_name = e[section].name
	scope.is_yaml = fs.IsYamlExt(e[section].name)
	scope.has_running = NXFS.access("/etc/openclash/" .. e[section].name)
	scope.config_script = not self.script_rendered
	self.script_rendered = true
	Button.render(self, section, scope)
end
btnapply.inputstyle = "apply"
btnapply.write = function(self, t)
	if not e[t] then return end
	local action = self.map:formvalue("cbid." .. self.map.config .. "." .. t .. ".actions")

	if action == "switch" and fs.IsYamlExt(e[t].name) then
		uci:set("openclash", "config", "config_path", "/etc/openclash/config/" .. e[t].name)
		uci:commit("openclash")
		HTTP.redirect(DISP.build_url("admin", "services", "openclash", "config"))
	elseif action == "edit" then
		local file_path = "/etc/openclash/config/" .. fs.basename(e[t].name)
		HTTP.redirect(DISP.build_url("admin", "services", "openclash", "other-file-edit", "config") .. "?file=" .. HTTP.urlencode(file_path))
	elseif action == "servers_manage" then
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
		fs.config_refs(file_name)
		SYS.call("/etc/init.d/openclash reload cron >/dev/null 2>&1")
		fs.unlink("/etc/openclash/history/"..fs.filename(e[t].name)..".db")
		fs.unlink("/etc/openclash/"..file_name)
		local a=fs.unlink("/etc/openclash/config/"..file_name)
		default_config_set(fs.basename(e[t].name))
		if a then table.remove(e,t) end
		HTTP.redirect(DISP.build_url("admin", "services", "openclash","config"))
	end
end

p = SimpleForm("provider_file_manage",translate("Provider File Manage"))
p.reset = false
p.submit = false

local provider_manage = {
	{proxy_mg, rule_mg}
}

promg = p:section(Table, provider_manage)

o = promg:option(Button, "proxy_mg", " ")
o.inputtitle = translate("Proxy Provider File List")
o.inputstyle = "reload"
o.write = function()
	HTTP.redirect(DISP.build_url("admin", "services", "openclash", "proxy-providers-file-manage"))
end

o = promg:option(Button, "rule_mg", " ")
o.inputtitle = translate("Rule Providers File List")
o.inputstyle = "reload"
o.write = function()
	HTTP.redirect(DISP.build_url("admin", "services", "openclash", "rule-providers-file-manage"))
end

m = SimpleForm("openclash",translate("Config File Edit"))
m.reset = false
m.submit = false

local tab = {
	{user, default}
}

s = m:section(Table, tab)
s.anonymous = true
s.addremove = false

local dconf = "/usr/share/openclash/res/default.yaml"
local conf_name = fs.basename(conf)
if not conf_name then conf_name = "config.yaml"  end
local sconf = "/etc/openclash/"..conf_name

s.description = align_mid..translate("Current Config")..": "..font_green..bold_on..conf_name..bold_off..font_off..align_mid_off

sev = s:option(TextValue, "user")
---sev.description = align_mid..translate("Modify Your Config file:").." "..font_green..bold_on..conf_name..bold_off..font_off.." "..translate("Here, Except The Settings That Were Taken Over")..align_mid_off
sev.rows = 40
sev.wrap = "off"
sev.cfgvalue = function(self, section)
	return fs.readfile(conf) or fs.readfile(dconf) or ""
end
sev.write = function(self, section, value)
if (CHIF == "0" and value and value ~= "oc-editor-streamed") then
	value = value:gsub("\r\n?", "\n")
	local old_value = fs.readfile(conf)
	if value ~= old_value then
		fs.writefile(conf, value)
	end
end
end

def = s:option(TextValue, "default")
if fs.isfile(sconf) then
	---def.description = align_mid..translate("Config File Edited By OpenClash For Running")..align_mid_off
else
	---def.description = align_mid..translate("Default Config File With Correct Template")..align_mid_off
end
def.rows = 40
def.wrap = "off"
def.readonly = true
def.cfgvalue = function(self, section)
	return fs.readfile(sconf) or fs.readfile(dconf) or ""
end
def.write = function(self, section, value)
end

local t = {
	{Commit, Create, Apply}
}

a = m:section(Table, t)

o = a:option(Button, "Commit", " ")
o.inputtitle = translate("Commit Settings")
o.inputstyle = "apply"
o.write = function()
	uci:commit("openclash")
end

o = a:option(DummyValue, "Create", " ")
o.rawhtml = true
o.template = "openclash/input_file_name"
o.value = "/etc/openclash/config/"

o = a:option(Button, "Apply", " ")
o.inputtitle = translate("Apply Settings")
o.inputstyle = "apply"
o.write = function()
	uci:set("openclash", "config", "enable", 1)
	uci:commit("openclash")
	SYS.call("/etc/init.d/openclash restart >/dev/null 2>&1 &")
	HTTP.redirect(DISP.build_url("admin", "services", "openclash"))
end

m:append(Template("openclash/config_merge_editor"))
m:append(Template("openclash/config_upload"))

return ful , form , p , m
