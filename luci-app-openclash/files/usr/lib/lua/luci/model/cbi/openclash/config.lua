
local NXFS = require "nixio.fs"
local SYS  = require "luci.sys"
local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"
local UTIL = require "luci.util"
local CHIF = "0"

m = SimpleForm("openclash")
m.reset = false
m.submit = false
s = m:section(SimpleSection, "")


local conf = "/etc/openclash/config.yaml"
local yconf = "/etc/openclash/config.yml"
local dconf = "/etc/openclash/default.yaml"
sev = s:option(Value, "sev")
sev.template = "cbi/tvalue"
sev.description = translate("You Can Modify config file Here, Except The Settings That Were Taken Over")
sev.rows = 20
sev.wrap = "off"
sev.cfgvalue = function(self, section)
	return NXFS.readfile(conf) or NXFS.readfile(yconf) or NXFS.readfile(dconf) or ""
end
sev.write = function(self, section, value)
if (CHIF == "0") then
    value = value:gsub("\r\n", "\n")
		NXFS.writefile("/etc/openclash/config.yaml", value)
end
end

local t = {
    {Commit, Apply}
}

a = m:section(Table, t)

o = a:option(Button, "Commit") 
o.inputtitle = translate("Commit Configurations")
o.inputstyle = "apply"
o.write = function()
  os.execute("uci commit openclash")
end

o = a:option(Button, "Apply")
o.inputtitle = translate("Apply Configurations")
o.inputstyle = "apply"
o.write = function()
  os.execute("uci set openclash.config.enable=1 && uci commit openclash && /etc/init.d/openclash restart >/dev/null 2>&1 &")
  HTTP.redirect(DISP.build_url("admin", "services", "openclash"))
end

ful = SimpleForm("upload", translate("Server Configuration"), nil)
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
			if (meta.file == "config.yml") then
			   SYS.exec("cp /etc/openclash/config.yml /etc/openclash/config.bak")
			   SYS.exec("mv /etc/openclash/config.yml /etc/openclash/config.yaml")
			elseif (meta.file == "config.yaml") then
			   SYS.exec("cp /etc/openclash/config.yaml /etc/openclash/config.bak")
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


return ful , m
