
local NXFS = require "nixio.fs"
local SYS  = require "luci.sys"
local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"
local UTIL = require "luci.util"
local fs = require "luci.openclash"
local uci = require("luci.model.uci").cursor()

m = SimpleForm("openclash",translate("OpenClash"))
m.description = translate("A Clash Client For OpenWrt")
m.reset = false
m.submit = false

m:section(SimpleSection).template  = "openclash/status"
if fs.uci_get_config("config", "dler_token") then
	m:append(Template("openclash/dlercloud"))
end

m:append(Template("openclash/myip"))
m:append(Template("openclash/developer"))
m:append(Template("openclash/select_git_cdn"))
m:append(Template("openclash/config_edit"))
m:append(Template("openclash/config_upload"))

return m

