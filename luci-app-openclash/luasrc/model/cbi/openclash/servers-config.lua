
local m, s, o
local openclash = "openclash"
local uci = luci.model.uci.cursor()
local fs = require "luci.openclash"
local sys = require "luci.sys"
local sid = arg[1]
local uuid = luci.sys.exec("cat /proc/sys/kernel/random/uuid")

font_red = [[<b style=color:red>]]
font_off = [[</b>]]
bold_on  = [[<strong>]]
bold_off = [[</strong>]]

function IsYamlFile(e)
   e=e or""
   local e=string.lower(string.sub(e,-5,-1))
   return e == ".yaml"
end
function IsYmlFile(e)
   e=e or""
   local e=string.lower(string.sub(e,-4,-1))
   return e == ".yml"
end

local encrypt_methods_ss = {

	-- stream
	"rc4-md5",
	"aes-128-cfb",
	"aes-192-cfb",
	"aes-256-cfb",
	"aes-128-ctr",
	"aes-192-ctr",
	"aes-256-ctr",
	"aes-128-gcm",
	"aes-192-gcm",
	"aes-256-gcm",
	"chacha20-ietf",
	"xchacha20",
	"chacha20-ietf-poly1305",
	"xchacha20-ietf-poly1305",
}

local encrypt_methods_ssr = {

	"rc4-md5",
	"aes-128-cfb",
	"aes-192-cfb",
	"aes-256-cfb",
	"aes-128-ctr",
	"aes-192-ctr",
	"aes-256-ctr",
	"chacha20-ietf",
	"xchacha20",
}

local securitys = {
	"auto",
	"none",
	"aes-128-gcm",
	"chacha20-poly1305"
}

local protocols = {
	"origin",
	"auth_sha1_v4",
	"auth_aes128_md5",
	"auth_aes128_sha1",
	"auth_chain_a",
	"auth_chain_b",
}

local obfs = {
	"plain",
	"http_simple",
	"http_post",
	"random_head",
	"tls1.2_ticket_auth",
	"tls1.2_ticket_fastauth",
}

m = Map(openclash, translate("Edit Server"))
m.pageaction = false
m.redirect = luci.dispatcher.build_url("admin/services/openclash/servers")

if m.uci:get(openclash, sid) ~= "servers" then
	luci.http.redirect(m.redirect)
	return
end

-- [[ Servers Setting ]] --
s = m:section(NamedSection, sid, "servers")
s.anonymous = true
s.addremove   = false

o = s:option(DummyValue, "server_url", "SS/SSR/VMESS/TROJAN URL")
o.rawhtml = true
o.template = "openclash/server_url"
o.value = sid

o = s:option(ListValue, "config", translate("Config File"))
o:value("all", translate("Use For All Config File"))
local e,a={}
for t,f in ipairs(fs.glob("/etc/openclash/config/*"))do
	a=fs.stat(f)
	if a then
    e[t]={}
    e[t].name=fs.basename(f)
    if IsYamlFile(e[t].name) or IsYmlFile(e[t].name) then
       o:value(e[t].name)
    end
  end
end

o = s:option(ListValue, "type", translate("Server Node Type"))
o:value("ss", translate("Shadowsocks"))
o:value("ssr", translate("ShadowsocksR"))
o:value("vmess", translate("Vmess"))
o:value("vless", translate("Vless ")..translate("(Only Meta Core)"))
o:value("trojan", translate("trojan"))
o:value("snell", translate("Snell"))
o:value("socks5", translate("Socks5"))
o:value("http", translate("HTTP(S)"))
o.description = translate("Using incorrect encryption mothod may causes service fail to start")

o = s:option(Value, "name", translate("Server Alias"))
o.rmempty = false
o.default = "Server - "..sid
if not m.uci:get("openclash", sid, "name") then
	m.uci:set("openclash", sid, "manual", 1)
end

o = s:option(Value, "server", translate("Server Address"))
o.datatype = "host"
o.rmempty = true

o = s:option(Value, "port", translate("Server Port"))
o.datatype = "port"
o.rmempty = false
o.default = "443"

o = s:option(Value, "password", translate("Password"))
o.password = true
o.rmempty = false
o:depends("type", "ss")
o:depends("type", "ssr")
o:depends("type", "trojan")

o = s:option(Value, "psk", translate("Psk"))
o.rmempty = false
o:depends("type", "snell")

o = s:option(ListValue, "snell_version", translate("Version"))
o:value("2")
o:value("3")
o:depends("type", "snell")

o = s:option(ListValue, "cipher", translate("Encrypt Method"))
for _, v in ipairs(encrypt_methods_ss) do o:value(v) end
o.rmempty = true
o:depends("type", "ss")

o = s:option(ListValue, "cipher_ssr", translate("Encrypt Method"))
for _, v in ipairs(encrypt_methods_ssr) do o:value(v) end
o:value("dummy", "none")
o.rmempty = true
o:depends("type", "ssr")

o = s:option(ListValue, "protocol", translate("Protocol"))
for _, v in ipairs(protocols) do o:value(v) end
o.rmempty = true
o:depends("type", "ssr")

o = s:option(Value, "protocol_param", translate("Protocol param(optional)"))
o:depends("type", "ssr")

o = s:option(ListValue, "securitys", translate("Encrypt Method"))
for _, v in ipairs(securitys) do o:value(v) end
o.rmempty = true
o:depends("type", "vmess")

o = s:option(ListValue, "obfs_ssr", translate("Obfs"))
for _, v in ipairs(obfs) do o:value(v) end
o.rmempty = true
o:depends("type", "ssr")

o = s:option(Value, "obfs_param", translate("Obfs param(optional)"))
o:depends("type", "ssr")

-- AlterId
o = s:option(Value, "alterId", translate("AlterId"))
o.datatype = "port"
o.default = "32"
o.rmempty = true
o:depends("type", "vmess")

-- VmessId
o = s:option(Value, "uuid", translate("UUID"))
o.rmempty = true
o.default = uuid
o:depends("type", "vmess")
o:depends("type", "vless")

o = s:option(ListValue, "udp", translate("UDP Enable"))
o.rmempty = true
o.default = "false"
o:value("true")
o:value("false")
o:depends("type", "ss")
o:depends("type", "ssr")
o:depends("type", "vmess")
o:depends("type", "vless")
o:depends("type", "socks5")
o:depends("type", "trojan")
o:depends({type = "snell", snell_version = "3"})

o = s:option(ListValue, "obfs", translate("obfs-mode"))
o.rmempty = true
o.default = "none"
o:value("none")
o:value("tls")
o:value("http")
o:value("websocket", translate("websocket (ws)"))
o:depends("type", "ss")

o = s:option(ListValue, "obfs_snell", translate("obfs-mode"))
o.rmempty = true
o.default = "none"
o:value("none")
o:value("tls")
o:value("http")
o:depends("type", "snell")

o = s:option(ListValue, "obfs_vless", translate("obfs-mode"))
o.rmempty = true
o.default = "none"
o:value("none")
o:value("ws", translate("websocket (ws)"))
o:value("grpc", translate("grpc"))
o:depends("type", "vless")

o = s:option(ListValue, "obfs_vmess", translate("obfs-mode"))
o.rmempty = true
o.default = "none"
o:value("none")
o:value("websocket", translate("websocket (ws)"))
o:value("http", translate("http"))
o:value("h2", translate("h2"))
o:value("grpc", translate("grpc"))
o:depends("type", "vmess")

o = s:option(ListValue, "obfs_trojan", translate("obfs-mode"))
o.rmempty = true
o.default = "none"
o:value("none")
o:value("ws", translate("websocket (ws)"))
o:value("grpc", translate("grpc"))
o:depends("type", "trojan")

o = s:option(Value, "host", translate("obfs-hosts"))
o.datatype = "host"
o.placeholder = translate("example.com")
o.rmempty = true
o:depends("obfs", "tls")
o:depends("obfs", "http")
o:depends("obfs", "websocket")
o:depends("obfs_snell", "tls")
o:depends("obfs_snell", "http")

-- vmess路径
o = s:option(Value, "path", translate("path"))
o.rmempty = true
o.placeholder = translate("/")
o:depends("obfs", "websocket")

o = s:option(DynamicList, "h2_host", translate("host"))
o.rmempty = true
o.placeholder = translate("http.example.com")
o.datatype = "host"
o:depends("obfs_vmess", "h2")

o = s:option(Value, "h2_path", translate("path"))
o.rmempty = true
o.default = "/"
o:depends("obfs_vmess", "h2")

o = s:option(DynamicList, "http_path", translate("path"))
o.rmempty = true
o:value("/")
o:value("/video")
o:depends("obfs_vmess", "http")

o = s:option(Value, "custom", translate("headers"))
o.rmempty = true
o.placeholder = translate("v2ray.com")
o:depends("obfs", "websocket")

o = s:option(Value, "ws_opts_path", translate("ws-opts-path"))
o.rmempty = true
o.placeholder = translate("/path")
o:depends("obfs_vmess", "websocket")
o:depends("obfs_vless", "ws")

o = s:option(DynamicList, "ws_opts_headers", translate("ws-opts-headers"))
o.rmempty = true
o.placeholder = translate("Host: v2ray.com")
o:depends("obfs_vmess", "websocket")
o:depends("obfs_vless", "ws")

o = s:option(Value, "max_early_data", translate("max-early-data"))
o.rmempty = true
o.placeholder = translate("2048")
o:depends("obfs_vmess", "websocket")

o = s:option(Value, "early_data_header_name", translate("early-data-header-name"))
o.rmempty = true
o.placeholder = translate("Sec-WebSocket-Protocol")
o:depends("obfs_vmess", "websocket")

-- [[ skip-cert-verify ]]--
o = s:option(ListValue, "skip_cert_verify", translate("skip-cert-verify"))
o.rmempty = true
o.default = "false"
o:value("true")
o:value("false")
o:depends("obfs", "websocket")
o:depends("obfs_vmess", "none")
o:depends("obfs_vmess", "websocket")
o:depends("obfs_vmess", "grpc")
o:depends("type", "socks5")
o:depends("type", "http")
o:depends("type", "trojan")
o:depends("type", "vless")

-- [[ TLS ]]--
o = s:option(ListValue, "tls", translate("tls"))
o.rmempty = true
o.default = "false"
o:value("true")
o:value("false")
o:depends("obfs", "websocket")
o:depends("type", "vmess")
o:depends("type", "vless")
o:depends("type", "socks5")
o:depends("type", "http")

o = s:option(Value, "servername", translate("servername"))
o.rmempty = true
o.datatype = "host"
o.placeholder = translate("example.com")
o:depends({obfs_vmess = "websocket", tls = "true"})
o:depends({obfs_vmess = "grpc", tls = "true"})
o:depends({obfs_vmess = "none", tls = "true"})
o:depends("type", "vless")

o = s:option(Value, "vless_flow", translate("flow"))
o.rmempty = true
o.default = "xtls-rprx-direct"
o:value("xtls-rprx-direct")
o:value("xtls-rprx-origin")
o:depends("obfs_vless", "none")

o = s:option(Value, "keep_alive", translate("keep-alive"))
o.rmempty = true
o.default = "true"
o:value("true")
o:value("false")
o:depends("obfs_vmess", "http")

-- [[ MUX ]]--
o = s:option(ListValue, "mux", translate("mux"))
o.rmempty = true
o.default = "false"
o:value("true")
o:value("false")
o:depends("obfs", "websocket")

-- [[ sni ]]--
o = s:option(Value, "sni", translate("sni"))
o.datatype = "host"
o.placeholder = translate("example.com")
o.rmempty = true
o:depends("type", "trojan")
o:depends("type", "http")

-- 验证用户名
o = s:option(Value, "auth_name", translate("Auth Username"))
o:depends("type", "socks5")
o:depends("type", "http")
o.rmempty = true

-- 验证密码
o = s:option(Value, "auth_pass", translate("Auth Password"))
o:depends("type", "socks5")
o:depends("type", "http")
o.rmempty = true

-- [[ alpn ]]--
o = s:option(DynamicList, "alpn", translate("alpn"))
o.rmempty = true
o:value("h2")
o:value("http/1.1")
o:depends("type", "trojan")

-- [[ grpc ]]--
o = s:option(Value, "grpc_service_name", translate("grpc-service-name"))
o.rmempty = true
o.datatype = "host"
o.placeholder = translate("example")
o:depends("obfs_trojan", "grpc")
o:depends("obfs_vmess", "grpc")
o:depends("obfs_vless", "grpc")

-- [[ trojan-ws-path ]]--
o = s:option(Value, "trojan_ws_path", translate("Path"))
o.rmempty = true
o.placeholder = translate("/path")
o:depends("obfs_trojan", "ws")

-- [[ trojan-ws-headers ]]--
o = s:option(DynamicList, "trojan_ws_headers", translate("Headers"))
o.rmempty = true
o.placeholder = translate("Host: v2ray.com")
o:depends("obfs_trojan", "ws")

-- [[ interface-name ]]--
o = s:option(Value, "interface_name", translate("interface-name"))
o.rmempty = true
o.placeholder = translate("eth0")

-- [[ routing-mark ]]--
o = s:option(Value, "routing_mark", translate("routing-mark"))
o.rmempty = true
o.placeholder = translate("2333")

o = s:option(DynamicList, "groups", translate("Proxy Group"))
o.description = font_red..bold_on..translate("No Need Set when Config Create, The added Proxy Groups Must Exist")..bold_off..font_off
o.rmempty = true
o:value("all", translate("All Groups"))
m.uci:foreach("openclash", "groups",
		function(s)
			if s.name ~= "" and s.name ~= nil then
			   o:value(s.name)
			end
		end)

local t = {
    {Commit, Back}
}
a = m:section(Table, t)

o = a:option(Button,"Commit", " ")
o.inputtitle = translate("Commit Settings")
o.inputstyle = "apply"
o.write = function()
   m.uci:commit(openclash)
   sys.call("/usr/share/openclash/cfg_servers_address_fake_filter.sh &")
   luci.http.redirect(m.redirect)
end

o = a:option(Button,"Back", " ")
o.inputtitle = translate("Back Settings")
o.inputstyle = "reset"
o.write = function()
   m.uci:revert(openclash, sid)
   luci.http.redirect(m.redirect)
end

return m
