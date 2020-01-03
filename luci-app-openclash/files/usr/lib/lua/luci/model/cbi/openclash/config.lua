
local NXFS = require "nixio.fs"
local SYS  = require "luci.sys"
local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"
local UTIL = require "luci.util"
local fs = require "luci.openclash"
local uci = require("luci.model.uci").cursor()
local CHIF = "0"

ful = SimpleForm("upload", translate("Server Configuration"), nil)
ful.reset = false
ful.submit = false

sul =ful:section(SimpleSection, "")
o = sul:option(FileUpload, "")
o.template = "openclash/upload"
um = sul:option(DummyValue, "", nil)
um.template = "openclash/dvalue"

local dir, fd, clash
clash = "/etc/openclash/clash"
dir = "/etc/openclash/config/"
bakck_dir="/etc/openclash/backup"
create_bakck_dir=fs.mkdir(bakck_dir)
HTTP.setfilehandler(
	function(meta, chunk, eof)
		if not fd then
			if not meta then return end

			if meta and chunk then fd = nixio.open(dir .. meta.file, "w") end

			if not fd then
				um.value = translate("upload file error.")
				return
			end
		end
		if chunk and fd then
			fd:write(chunk)
		end
		if eof and fd then
			fd:close()
			fd = nil
			function IsYamlFile(e)
         e=e or""
         local e=string.lower(string.sub(e,-5,-1))
         return e==".yaml"
      end
      function IsYmlFile(e)
         e=e or""
         local e=string.lower(string.sub(e,-4,-1))
         return e==".yml"
      end
      if IsYamlFile(meta.file)then
         local yamlbackup="/etc/openclash/backup/" .. meta.file
         local c=fs.copy(dir .. meta.file,yamlbackup)
      end
      if IsYmlFile(meta.file)then
      	 local ymlname=string.lower(string.sub(meta.file,0,-5))
         local ymlbackup="/etc/openclash/backup/".. ymlname .. ".yaml"
         local c=fs.rename(dir .. meta.file,"/etc/openclash/config/".. ymlname .. ".yaml")
         local c=fs.copy("/etc/openclash/config/".. ymlname .. ".yaml",ymlbackup)
      end
			if (meta.file == "clash") then
			   NXFS.chmod(clash, 755)
			end
			um.value = translate("File saved to") .. ' "/etc/openclash"'
			CHIF = "1"
		end
	end
)

if HTTP.formvalue("upload") then
	local f = HTTP.formvalue("ulfile")
	if #f <= 0 then
		um.value = translate("No specify upload file.")
	end
end

local e,a={}
for t,o in ipairs(fs.glob("/etc/openclash/config/*"))do
a=fs.stat(o)
if a then
e[t]={}
e[t].name=fs.basename(o)
BACKUP_FILE="/etc/openclash/backup/".. e[t].name
e[t].mtime=os.date("%Y-%m-%d %H:%M:%S",fs.mtime(BACKUP_FILE)) or os.date("%Y-%m-%d %H:%M:%S",a.mtime)
if string.sub(luci.sys.exec("uci get openclash.config.config_path"), 23, -2) == e[t].name then
   e[t].state=translate("Enable")
else
   e[t].state=translate("Disable")
end
e[t].size=tostring(a.size)
e[t].remove=0
e[t].enable=false
end
end

form=SimpleForm("filelist",translate("Config File List"),nil)
form.reset=false
form.submit=false
tb=form:section(Table,e)
st=tb:option(DummyValue,"state",translate("State"))
nm=tb:option(DummyValue,"name",translate("File Name"))
mt=tb:option(DummyValue,"mtime",translate("Update Time"))
sz=tb:option(DummyValue,"size",translate("Size"))
function IsYamlFile(e)
e=e or""
local e=string.lower(string.sub(e,-5,-1))
return e==".yaml"
end

btnis=tb:option(Button,"switch",translate("Switch Config"))
btnis.template="cbi/other_button"
btnis.render=function(o,t,a)
if not e[t]then return false end
if IsYamlFile(e[t].name)then
a.display=""
else
a.display="none"
end
o.inputstyle="apply"
Button.render(o,t,a)
end
btnis.write=function(a,t)
luci.sys.exec(string.format('uci set openclash.config.config_path="/etc/openclash/config/%s"',e[t].name))
uci:commit("openclash")
HTTP.redirect(luci.dispatcher.build_url("admin", "services", "openclash", "config"))
end

btndl = tb:option(Button,"download",translate("Download Configurations")) 
btndl.template="cbi/other_button"
btndl.render=function(o,t,a)
if not e[t]then return false end
if IsYamlFile(e[t].name)then
a.display=""
else
a.display="none"
end
o.inputstyle="remove"
Button.render(o,t,a)
end
btndl.write = function (a,t)
	local sPath, sFile, fd, block
	sPath = "/etc/openclash/config/"..e[t].name
	sFile = NXFS.basename(sPath)
	if fs.isdirectory(sPath) then
		fd = io.popen('tar -C "%s" -cz .' % {sPath}, "r")
		sFile = sFile .. ".tar.gz"
	else
		fd = nixio.open(sPath, "r")
	end
	if not fd then
		return
	end
	HTTP.header('Content-Disposition', 'attachment; filename="%s"' % {sFile})
	HTTP.prepare_content("application/octet-stream")
	while true do
		block = fd:read(nixio.const.buffersize)
		if (not block) or (#block ==0) then
			break
		else
			HTTP.write(block)
		end
	end
	fd:close()
	HTTP.close()
end

btnrm=tb:option(Button,"remove",translate("Remove"))
btnrm.render=function(e,t,a)
e.inputstyle="reset"
Button.render(e,t,a)
end
btnrm.write=function(a,t)
local a=fs.unlink("/etc/openclash/config/"..luci.openclash.basename(e[t].name))
local db=fs.unlink("/etc/openclash/backup/"..luci.openclash.basename(e[t].name))
if a then table.remove(e,t)end
return a
end

m = SimpleForm("openclash")
m.reset = false
m.submit = false

local tab = {
 {user, default}
}

s = m:section(Table, tab)

local conf = string.sub(luci.sys.exec("uci get openclash.config.config_path"), 1, -2)
local dconf = "/etc/openclash/default.yaml"

sev = s:option(Value, "user")
sev.template = "cbi/tvalue"
sev.description = translate("You Can Modify config file Here, Except The Settings That Were Taken Over")
sev.rows = 20
sev.wrap = "off"
sev.cfgvalue = function(self, section)
	return NXFS.readfile(conf) or NXFS.readfile(dconf) or ""
end
sev.write = function(self, section, value)
if (CHIF == "0") then
    value = value:gsub("\r\n?", "\n")
		NXFS.writefile(conf, value)
end
end

def = s:option(Value, "default")
def.template = "cbi/tvalue"
def.description = translate("Default Config File With Correct General-Settings")
def.rows = 20
def.wrap = "off"
def.readonly = true
def.cfgvalue = function(self, section)
	return NXFS.readfile(dconf) or ""
end
def.write = function(self, section, value)
end


local t = {
    {Commit, Apply}
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
  SYS.call("/etc/init.d/openclash restart >/dev/null 2>&1 &")
  HTTP.redirect(DISP.build_url("admin", "services", "openclash"))
end

return ful , form , m
