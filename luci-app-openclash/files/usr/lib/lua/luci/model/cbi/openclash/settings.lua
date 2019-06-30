
local NXFS = require "nixio.fs"
local SYS  = require "luci.sys"
local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"
local UTIL = require "luci.util"

local t = {
    {Commit, Apply}
}

a = SimpleForm("apply")
a.reset = false
a.submit = false
s = a:section(Table, t)

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
  os.execute("uci set openclash.config.enable=1 && uci commit openclash && /etc/init.d/openclash restart >/dev/null 2>&1 &")
  HTTP.redirect(DISP.build_url("admin", "services", "openclash"))
end

m = Map("openclash", translate("Clash Settings"))
m.pageaction = false

s = m:section(TypedSection, "openclash")
s.anonymous = true

o = s:option(ListValue, "en_mode", translate("Select Mode"))
o.description = translate("Will to Take Over Your General Settings, Network Error Try Flush DNS Cache")
o:value("0", translate("Disable Mode Control (Use Redir-Host Default If Not Set)"))
o:value("redir-host", translate("redir-host"))
o:value("fake-ip", translate("fake-ip"))
o.default = 0

o = s:option(Flag, "enable_custom_dns", translate("Custom DNS Setting"))
o.description = translate("Set OpenClash Upstream DNS Resolve Server")
o.default = 0
o.rmempty = false

o = s:option(Flag, "ipv6_enable", translate("Enable ipv6 Resolve"))
o.description = translate("Force Enable to Resolve ipv6 DNS Requests")
o.default=0
o.rmempty = false

o = s:option(Value, "proxy_port")
o.title = translate("OpenClash Redir Port")
o.default = 7892
o.datatype = "port"
o.rmempty = false
o.description = translate("Please Make Sure Ports Available")

o = s:option(Value, "cn_port")
o.title = translate("Dashboard Port")
o.default = 9090
o.datatype = "port"
o.rmempty = false
o.description = translate("Dashboard Address Example: 192.168.1.1/openclash、192.168.1.1:9090/ui")

o = s:option(Value, "dashboard_password")
o.title = translate("Dashboard Secret")
o.default = 123456
o.rmempty = false
o.description = translate("Set Dashboard Secret")

-- [[ Edit Server ]] --
s = m:section(TypedSection, "dns_servers", translate("Add Custom DNS Servers"))
s.anonymous = true
s.addremove = true
s.sortable = false
s.template = "cbi/tblsection"
s.rmempty = false

---- group
o = s:option(ListValue, "group", translate("DNS Server Group"))
o.description = translate("(NameServer Group Must Be Set)")
o:value("nameserver", translate("NameServer"))
o:value("fallback", translate("FallBack"))
o.default     = "nameserver"
o.rempty      = false

---- IP address
o = s:option(Value, "ip", translate("DNS Server Address"))
o.description = translate("(Do Not Add Type Ahead)")
o.datatype = "or(host, string)"
o.rmempty = false

---- port
o = s:option(Value, "port", translate("DNS Server Port"))
o.description = translate("(Require When Use Non-Standard Port)")
o.datatype    = "port"
o.rempty      = false

---- type
o = s:option(ListValue, "type", translate("DNS Server Type"))
o.description = translate("(Communication protocol)")
o:value("udp", translate("UDP"))
o:value("tcp", translate("TCP"))
o:value("tls", translate("TLS"))
o:value("https", translate("HTTPS"))
o.default     = "udp"
o.rempty      = false

return m, a


