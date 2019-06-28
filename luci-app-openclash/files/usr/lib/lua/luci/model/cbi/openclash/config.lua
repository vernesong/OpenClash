
local NXFS = require "nixio.fs"
local SYS  = require "luci.sys"
local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"
local UTIL = require "luci.util"
local CHIF = "0"

m = Map("openclash", translate("Server Configuration"))
s = m:section(TypedSection, "openclash")
s.anonymous = true
s.addremove=false


local conf = "/etc/openclash/config.yml"
sev = s:option(Value, "sev")
sev.template = "cbi/tvalue"
sev.description = translate("You Can Modify config file Here")
sev.rows = 20
sev.wrap = "off"
sev.cfgvalue = function(self, section)
	return NXFS.readfile(conf) or ""
end
sev.write = function(self, section, value)
if (CHIF == "0") then
    value = value:gsub("\r\n", "\n")
		NXFS.writefile("/etc/openclash/config.yml", value)
end
end

ful = SimpleForm("upload", nil)
ful.reset = false
ful.submit = false

sul =ful:section(SimpleSection, "")
o = sul:option(FileUpload, "")
o.template = "openclash/clash_upload"
um = sul:option(DummyValue, "", nil)
um.template = "openclash/clash_dvalue"

local dir, fd
dir = "/etc/openclash/"
HTTP.setfilehandler(
	function(meta, chunk, eof)
		if not fd then
			if not meta then return end

			if	meta and chunk then fd = nixio.open(dir .. meta.file, "w") end

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
			um.value = translate("File saved to") .. ' "/etc/openclash/' .. meta.file .. '"'
			if (meta.file == "config.yml") then
			   SYS.exec("cp /etc/openclash/config.yml /etc/openclash/config.bak")
			elseif (meta.file == "config.yaml") then
			   SYS.exec("cp /etc/openclash/config.yaml /etc/openclash/config.bak")
			end
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

local t = {
    {Commit, Apply}
}

s = ful:section(Table, t)

o = s:option(Button, "Commit") 
o.inputtitle = translate("Commit Configurations")
o.inputstyle = "apply"
o.write = function()
  os.execute("uci commit openclash")
end

o = s:option(Button, "Apply")
o.inputtitle = translate("Apply Configurations")
o.inputstyle = "apply"
o.write = function()
  os.execute("uci commit openclash && /etc/init.d/openclash restart >/dev/null 2>&1 &")
  HTTP.redirect(DISP.build_url("admin", "services", "openclash"))
end


return m , ful
