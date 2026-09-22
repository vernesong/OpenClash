
local m, s, o
local openclash = "openclash"
local uci = luci.model.uci.cursor()
local fs = require "luci.openclash"
local sys = require "luci.sys"
local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"
local sid = arg[1]
local uuid = luci.sys.exec("cat /proc/sys/kernel/random/uuid")
local file_path = fs.get_file_path_from_request()

if not file_path then
	HTTP.redirect(DISP.build_url("admin", "services", "openclash", "servers"))
	return
end

-- A section written before the option names were unified keeps the credentials of
-- socks5/http/ssh/trusttunnel below auth_name/auth_pass.
for _, legacy in ipairs({{"auth_name", "username"}, {"auth_pass", "password"}}) do
	local value = uci:get(openclash, sid, legacy[1])
	if value then
		if not uci:get(openclash, sid, legacy[2]) then
			uci:set(openclash, sid, legacy[2], value)
		end
		uci:delete(openclash, sid, legacy[1])
	end
end

font_red = [[<b style=color:red>]]
font_off = [[</b>]]
bold_on = [[<strong>]]
bold_off = [[</strong>]]



local encrypt_methods_ss = {
	-- stream
	"none",
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
	"aes-128-gcm-siv",
	"aes-256-gcm-siv",
	"aes-128-ccm",
	"aes-192-ccm",
	"aes-256-ccm",
	"lea-128-gcm",
	"lea-192-gcm",
	"lea-256-gcm",
	"chacha20",
	"chacha20-ietf",
	"xchacha20",
	"chacha20-ietf-poly1305",
	"xchacha20-ietf-poly1305",
	"chacha8-ietf-poly1305",
	"xchacha8-ietf-poly1305",
	"2022-blake3-aes-128-gcm",
	"2022-blake3-aes-256-gcm",
	"2022-blake3-chacha20-poly1305",
	"rabbit128-poly1305",
	"aegis-128l",
	"aegis-256",
	"aez-384",
	"deoxys-ii-256-128"
}

local securitys = {
	"auto",
	"none",
	"zero",
	"aes-128-gcm",
	"chacha20-poly1305"
}

local protocols = {
	"origin",
	"auth_sha1_v4",
	"auth_aes128_md5",
	"auth_aes128_sha1",
	"auth_chain_a",
	"auth_chain_b"
}

local hysteria_protocols = {
	"udp",
	"wechat-video",
	"faketcp"
}

local obfs = {
	"plain",
	"http_simple",
	"http_post",
	"random_head",
	"tls1.2_ticket_auth",
	"tls1.2_ticket_fastauth"
}

-- several types share one option, the select shows the values of every type it serves
local function add_option_values(option, lists)
	local seen = {}
	for _, list in ipairs(lists) do
		for _, value in ipairs(list) do
			if not seen[value] then
				seen[value] = true
				option:value(value)
			end
		end
	end
end

-- A field of some node types must not be required for the others and a hidden field must
-- not keep the value of the previous type: the requirement follows the type dependencies
-- of the field, `optional` names the types whose field is optional.
local function require_by_type(option, optional)
	optional = optional or {}
	local parse = option.parse
	function option.parse(self, section, novld)
		local node_type = self.map:get(section, "type") or ""
		local needed = false
		for _, dependency in ipairs(self.deps) do
			if dependency.type == node_type and not optional[node_type] then
				needed = true
			end
		end
		self.rmempty = not needed
		return parse(self, section, novld)
	end
	return option
end

local function certificate(section, name, title, ...)
	local option = section:option(TextValue, name, translate(title))
	option.rmempty = true
	option.rows = 6
	for _, node_type in ipairs({...}) do
		option:depends("type", node_type)
	end
	function option.validate(self, value)
		if value then
			value = value:gsub("\r\n?", "\n")
		end
		return value
	end
	return option
end

-- A key of a nested block: the label is its yaml path, the kind is the one mihomo reads,
-- `deps` shows the field for the option values that select the block and `constraint` is
-- the datatype of a Value or the values of a ListValue.
local function block_field(section, kind, name, label, deps, constraint)
	local option = section:option(kind, name, translate(label))
	option.rmempty = true
	if constraint then
		if type(constraint) == "table" then
			for _, value in ipairs(constraint) do
				option:value(value)
			end
		else
			option.datatype = constraint
		end
	end
	for key, value in pairs(deps or {}) do
		option:depends(key, value)
	end
	return option
end

m = Map(openclash, translate("Edit Server"))
m.uci = uci
m.pageaction = false
m.redirect = DISP.build_url("admin/services/openclash/servers") .. "?file=" .. HTTP.urlencode(file_path)

if m.uci:get(openclash, sid) ~= "proxies" then
	HTTP.redirect(m.redirect)
	return
end

-- [[ Servers Setting ]] --
s = m:section(NamedSection, sid, "proxies")
s.anonymous = true
s.addremove = false

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
		if fs.IsYamlExt(e[t].name) then
			o:value(e[t].name)
		end
	end
end

o = s:option(ListValue, "type", translate("Server Node Type"))
o:value("ss", translate("Shadowsocks"))
o:value("ssr", translate("ShadowsocksR"))
o:value("vmess", translate("Vmess"))
o:value("trojan", translate("trojan"))
o:value("vless", translate("Vless"))
o:value("hysteria", translate("Hysteria"))
o:value("hysteria2", translate("Hysteria2"))
o:value("wireguard", translate("WireGuard"))
o:value("tuic", translate("Tuic"))
o:value("snell", translate("Snell"))
o:value("mieru", translate("Mieru"))
o:value("anytls", translate("AnyTLS"))
o:value("sudoku", translate("Sudoku"))
o:value("socks5", translate("Socks5"))
o:value("http", translate("HTTP(S)"))
o:value("direct", translate("DIRECT"))
o:value("dns", translate("DNS"))
o:value("ssh", translate("SSH"))
o:value("masque", translate("MASQUE"))
o:value("trusttunnel", translate("TrustTunnel"))
o:value("tailscale", translate("Tailscale"))
o:value("zerotier", translate("ZeroTier"))
o:value("openvpn", translate("OpenVPN"))
o:value("shadowquic", translate("ShadowQUIC"))
o:value("gost-relay", translate("GostRelay"))

o.description = translate("Using incorrect encryption mothod may causes service fail to start")

o = s:option(Value, "name", translate("Server Alias"))
o.rmempty = false
o.default = "Server - "..sid

o = s:option(Value, "server", translate("Server Address"))
o.datatype = "host"
o.rmempty = true
o:depends("type", "ss")
o:depends("type", "ssr")
o:depends("type", "vmess")
o:depends("type", "trojan")
o:depends("type", "vless")
o:depends("type", "hysteria")
o:depends("type", "hysteria2")
o:depends("type", "wireguard")
o:depends("type", "tuic")
o:depends("type", "mieru")
o:depends("type", "anytls")
o:depends("type", "sudoku")
o:depends("type", "snell")
o:depends("type", "socks5")
o:depends("type", "http")
o:depends("type", "ssh")
o:depends("type", "masque")
o:depends("type", "trusttunnel")

o = s:option(Value, "port", translate("Server Port"))
o.datatype = "port"
o.rmempty = false
o.default = "443"
o:depends("type", "ss")
o:depends("type", "ssr")
o:depends("type", "vmess")
o:depends("type", "trojan")
o:depends("type", "vless")
o:depends("type", "hysteria")
o:depends("type", "hysteria2")
o:depends("type", "wireguard")
o:depends("type", "tuic")
o:depends("type", "mieru")
o:depends("type", "anytls")
o:depends("type", "sudoku")
o:depends("type", "snell")
o:depends("type", "socks5")
o:depends("type", "http")
o:depends("type", "ssh")
o:depends("type", "masque")
o:depends("type", "trusttunnel")

o = s:option(Flag, "flag_port_hopping", translate("Enable Port Hopping"))
o:depends("type", "hysteria")
o:depends("type", "hysteria2")
o.rmempty = true
o.default = "0"

o = s:option(Value, "ports", translate("Port Range"))
o.datatype = "portrange"
o.rmempty = true
o.default = "20000-40000"
o.placeholder = translate("20000-40000")
o:depends({type = "hysteria", flag_port_hopping = true})
o:depends({type = "hysteria2", flag_port_hopping = true})

o = s:option(Value, "password", translate("Password"))
o.password = true
o.rmempty = false
o:depends("type", "ss")
o:depends("type", "ssr")
o:depends("type", "trojan")
o:depends("type", "hysteria2")
o:depends("type", "mieru")
o:depends("type", "anytls")
o:depends("type", "tuic")

o = s:option(Value, "sudoku_key", translate("Key"))
o.rmempty = true
o.placeholder = translate("<client_key>")
o:depends("type", "sudoku")

o = s:option(ListValue, "aead_method", translate("Aead-method"))
o.rmempty = true
o.default = "chacha20-poly1305"
o:value("chacha20-poly1305")
o:value("aes-128-gcm")
o:value("none")
o:depends("type", "sudoku")

o = s:option(Value, "padding_min", translate("Padding-min"))
o.rmempty = true
o.datatype = "uinteger"
o.placeholder = translate("2")
o:depends("type", "sudoku")

o = s:option(Value, "padding_max", translate("Padding-max"))
o.rmempty = true
o.datatype = "uinteger"
o.placeholder = translate("7")
o:depends("type", "sudoku")

o = s:option(ListValue, "table_type", translate("Table-type"))
o.rmempty = true
o.default = "prefer_ascii"
o:value("prefer_ascii")
o:value("prefer_entropy")
o:depends("type", "sudoku")

o = s:option(ListValue, "http_mask", translate("Http-mask"))
o.rmempty = true
o.default = "true"
o:value("true")
o:value("false")
o:depends("type", "sudoku")

o = s:option(ListValue, "sudoku_enable_pure_downlink", translate("enable-pure-downlink"))
o.rmempty = true
o:value("true")
o:value("false")
o:depends("type", "sudoku")

o = s:option(ListValue, "sudoku_http_mask_mode", translate("http-mask-mode"))
o.rmempty = true
o.default = "legacy"
o:value("legacy")
o:value("stream")
o:value("poll")
o:value("auto")
o:value("ws")
o:depends("type", "sudoku")

o = s:option(ListValue, "sudoku_http_mask_tls", translate("http-mask-tls"))
o.rmempty = true
o:value("true")
o:value("false")
o.description = translate("only for http-mask-mode stream, poll or auto")
o:depends("type", "sudoku")

o = s:option(Value, "sudoku_http_mask_host", translate("http-mask-host"))
o.rmempty = true
o.placeholder = translate("example.com:443")
o:depends("type", "sudoku")

o = s:option(ListValue, "sudoku_multiplex", translate("multiplex"))
o.rmempty = true
o.default = "off"
o:value("off")
o:value("auto")
o:value("on")
o:depends("type", "sudoku")

o = s:option(ListValue, "sudoku_http_mask_multiplex", translate("http-mask-multiplex"))
o.rmempty = true
o:value("off")
o:value("auto")
o:value("on")
o:depends("type", "sudoku")

o = s:option(Value, "sudoku_path_root", translate("path-root"))
o.rmempty = true
o.placeholder = translate("/prefix")
o:depends("type", "sudoku")

o = s:option(Value, "sudoku_custom_table", translate("custom-table"))
o.rmempty = true
o.placeholder = translate("xpxvvpvv")
o:depends("type", "sudoku")

o = s:option(DynamicList, "sudoku_custom_tables", translate("custom-tables"))
o.rmempty = true
o.placeholder = translate("xpxvvpvv")
o:depends("type", "sudoku")

o = s:option(Value, "port_range", translate("Port Range"))
o.datatype = "portrange"
o.rmempty = true
o.default = "20000-40000"
o.placeholder = translate("20000-40000")
o:depends("type", "mieru")

o = s:option(Value, "username", translate("Username"))
o.rmempty = false
o.placeholder = "user"
o:depends("type", "mieru")

o = s:option(ListValue, "transport", translate("Transport"))
o.rmempty = false
o.default = "TCP"
o:value("TCP")
o:depends("type", "mieru")

o = s:option(ListValue, "multiplexing", translate("Multiplexing"))
o.rmempty = false
o.default = "MULTIPLEXING_LOW"
o:value("MULTIPLEXING_OFF")
o:value("MULTIPLEXING_LOW")
o:value("MULTIPLEXING_MIDDLE")
o:value("MULTIPLEXING_HIGH")
o:depends("type", "mieru")

o = s:option(Value, "token", translate("Token (tuicV4 only)"))
o.rmempty = true
o:depends("type", "tuic")

o = s:option(ListValue, "udp_relay_mode", translate("UDP Relay Mode"))
o.rmempty = true
o.default = "native"
o:value("native")
o:value("quic")
o:depends("type", "tuic")

o = s:option(ListValue, "congestion_controller", translate("Congestion Controller"))
o.rmempty = true
o.default = "cubic"
o:value("cubic")
o:value("bbr")
o:value("new_reno")
o:depends("type", "tuic")

o = s:option(DynamicList, "alpn", translate("Alpn"))
o.rmempty = true
o:value("h3")
o:value("h2")
o:depends("type", "tuic")
o:depends("type", "hysteria")
o:depends("type", "hysteria2")
o:depends("type", "shadowquic")

o = s:option(ListValue, "disable_sni", translate("Disable SNI"))
o.rmempty = true
o.default = "true"
o:value("true")
o:value("false")
o:depends("type", "tuic")

o = s:option(ListValue, "reduce_rtt", translate("Reduce RTT"))
o.rmempty = true
o.default = "true"
o:value("true")
o:value("false")
o:depends("type", "tuic")

o = s:option(Value, "heartbeat_interval", translate("Heartbeat Interval"))
o.rmempty = true
o:depends("type", "tuic")
o.default = "8000"

o = s:option(Value, "request_timeout", translate("Request Timeout"))
o.rmempty = true
o.default = "8000"
o:depends("type", "tuic")

o = s:option(Value, "max_udp_relay_packet_size", translate("Max UDP Relay Packet Size"))
o.rmempty = true
o.default = "1500"
o:depends("type", "tuic")

o = s:option(Value, "max_open_streams", translate("Max Open Streams"))
o.rmempty = true
o.default = "100"
o:depends("type", "tuic")

o = s:option(Value, "ip", translate("IP"))
o.rmempty = true
o.placeholder = translate("127.0.0.1")
o.datatype = "or(ip4addr, ip6addr)"
o:depends("type", "tuic")
o:depends("type", "wireguard")
o:depends("type", "masque")

o = s:option(Value, "ipv6", translate("IPv6"))
o.rmempty = true
o.placeholder = translate("your_ipv6")
o.datatype = "ip6addr"
o:depends("type", "wireguard")
o:depends("type", "masque")

o = s:option(Value, "private_key", translate("Private Key"))
o.rmempty = true
o.placeholder = translate("eCtXsJZ27+4PbhDkHnB923tkUn2Gj59wZw5wFA75MnU=")
o:depends("type", "wireguard")
o:depends("type", "masque")
o:depends("type", "gost-relay")

o = s:option(Value, "public_key", translate("Public Key"))
o.rmempty = true
o.placeholder = translate("Cr8hWlKvtDt7nrvf+f0brNQQzabAqrjfBvas9pmowjo=")
o:depends("type", "wireguard")
o:depends("type", "masque")

o = s:option(Value, "preshared_key", translate("Preshared Key"))
o.rmempty = true
o.placeholder = translate("base64")
o:depends("type", "wireguard")

o = s:option(DynamicList, "dns", translate("DNS"))
o.rmempty = true
o:value("1.1.1.1")
o:value("8.8.8.8")
o:depends("type", "wireguard")
o:depends("type", "masque")

o = s:option(Value, "mtu", translate("MTU"))
o.rmempty = true
o.default = "1420"
o.placeholder = translate("1420")
o:depends("type", "wireguard")
o:depends("type", "masque")

o = s:option(Flag, "flag_transport", translate("Enable Transport Protocol Settings"))
o:depends("type", "hysteria")
o.rmempty = true
o.default = "0"

o = s:option(ListValue, "hysteria_protocol", translate("Protocol"))
add_option_values(o, {hysteria_protocols})
o.rmempty = true
o:depends({type = "hysteria", flag_transport = true})

o = s:option(Value, "hysteria_up", translate("Uplink Capacity(Default:Mbps)"))
o.rmempty = false
o.description = translate("Required")
o:depends("type", "hysteria")
o:depends("type", "hysteria2")

o = s:option(Value, "hysteria_down", translate("Downlink Capacity(Default:Mbps)"))
o.rmempty = false
o.description = translate("Required")
o:depends("type", "hysteria")
o:depends("type", "hysteria2")

o = s:option(Value, "psk", translate("Psk"))
o.rmempty = true
o:depends("type", "snell")

o = s:option(ListValue, "snell_version", translate("Version"))
o:value("2")
o:value("3")
o:depends("type", "snell")

o = s:option(ListValue, "cipher", translate("Encrypt Method"))
add_option_values(o, {encrypt_methods_ss, securitys})
o.rmempty = true
o:depends("type", "ss")
o:depends("type", "ssr")
o:depends("type", "vmess")

o = s:option(ListValue, "protocol", translate("Protocol"))
for _, v in ipairs(protocols) do o:value(v) end
o.rmempty = true
o:depends("type", "ssr")

o = s:option(Value, "protocol_param", translate("Protocol param(optional)"))
o:depends("type", "ssr")

o = s:option(ListValue, "obfs_ssr", translate("Obfs"))
for _, v in ipairs(obfs) do o:value(v) end
o.rmempty = true
o:depends("type", "ssr")

o = s:option(Value, "obfs_param", translate("Obfs param(optional)"))
o:depends("type", "ssr")

o = s:option(Value, "alterId", translate("AlterId"))
o.default = "32"
o.rmempty = true
o:depends("type", "vmess")

o = s:option(Value, "uuid", translate("UUID"))
o.rmempty = true
o.default = uuid
o:depends("type", "vmess")
o:depends("type", "vless")
o:depends("type", "tuic")

o = s:option(ListValue, "udp", translate("UDP Enable"))
o.rmempty = true
o.default = "true"
o:value("true")
o:value("false")
o:depends("type", "ss")
o:depends("type", "ssr")
o:depends("type", "vmess")
o:depends("type", "vless")
o:depends("type", "socks5")
o:depends("type", "trojan")
o:depends({type = "snell", snell_version = "3"})
o:depends("type", "wireguard")
o:depends("type", "direct")
o:depends("type", "anytls")
o:depends("type", "masque")
o:depends("type", "trusttunnel")

o = s:option(ListValue, "udp_over_tcp", translate("udp-over-tcp"))
o.rmempty = true
o.default = "false"
o:value("true")
o:value("false")
o:depends("type", "ss")

o = s:option(ListValue, "xudp", translate("XUDP Enable"))
o.rmempty = true
o.default = "true"
o:value("true")
o:value("false")
o:depends({type = "vmess", udp = "true"})
o:depends({type = "vless", udp = "true"})

o = s:option(ListValue, "obfs", translate("obfs-mode"))
o.rmempty = true
o.default = "none"
o:value("none")
o:value("tls")
o:value("http")
o:value("websocket", translate("websocket (ws)"))
o:value("shadow-tls", translate("shadow-tls"))
o:value("restls", translate("restls"))
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
o.default = "tcp"
o:value("tcp", translate("tcp"))
o:value("ws", translate("websocket (ws)"))
o:value("grpc", translate("grpc"))
o:value("xhttp", translate("xhttp"))
o:value("http", translate("http"))
o:value("h2", translate("h2"))
o:depends("type", "vless")

o = s:option(ListValue, "obfs_vmess", translate("obfs-mode"))
o.rmempty = true
o.default = "none"
o:value("none")
o:value("websocket", translate("websocket (ws)"))
o:value("http", translate("http"))
o:value("h2", translate("h2"))
o:value("grpc", translate("grpc"))
o:value("mkcp", translate("mkcp"))
o:value("mekya", translate("mekya"))
o:depends("type", "vmess")

o = s:option(ListValue, "obfs_trojan", translate("obfs-mode"))
o.rmempty = true
o.default = "none"
o:value("none")
o:value("tcp", translate("tcp"))
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
o:depends("obfs", "shadow-tls")
o:depends("obfs", "restls")
o:depends("obfs_snell", "tls")
o:depends("obfs_snell", "http")

o = s:option(Value, "obfs_password", translate("obfs-password"))
o.rmempty = true
o:depends("obfs", "shadow-tls")
o:depends("obfs", "restls")
o:depends("type", "hysteria2")

o = s:option(ListValue, "obfs_version_hint", translate("version-hint"))
o.rmempty = true
o:value("tls13")
o:value("tls12")
o:depends("obfs", "restls")

o = s:option(Value, "obfs_restls_script", translate("restls-script"))
o.rmempty = true
o:depends("obfs", "restls")
o.placeholder = translate("1000?100<1,500~100,350~100,600~100,400~200")

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

o = s:option(Value, "ws_path", translate("ws-opts-path"))
o.rmempty = true
o.placeholder = translate("/path")
o:depends("obfs_vmess", "websocket")
o:depends("obfs_vless", "ws")
o:depends("obfs_trojan", "ws")

o = s:option(DynamicList, "ws_headers", translate("ws-opts-headers"))
o.rmempty = true
o.placeholder = translate("Host: v2ray.com")
o:depends("obfs_vmess", "websocket")
o:depends("obfs_vless", "ws")
o:depends("obfs_trojan", "ws")

o = s:option(Value, "xhttp_opts_path", translate("xhttp-opts-path"))
o.rmempty = true
o.placeholder = translate("/path")
o:depends("obfs_vless", "xhttp")

o = s:option(Value, "xhttp_opts_host", translate("xhttp-opts-host"))
o.rmempty = true
o.placeholder = translate("xxx.com")
o:depends("obfs_vless", "xhttp")

-- [[ HTTP and H2 transport of vless ]]--
block_field(s, Value, "vless_http_method", "http-opts-method", {obfs_vless = "http"})
block_field(s, DynamicList, "vless_http_path", "http-opts-path", {obfs_vless = "http"})
block_field(s, DynamicList, "vless_http_headers", "http-opts-headers", {obfs_vless = "http"})
block_field(s, DynamicList, "vless_h2_host", "h2-opts-host", {obfs_vless = "h2"}, "host")
block_field(s, Value, "vless_h2_path", "h2-opts-path", {obfs_vless = "h2"})

o = s:option(Value, "vless_encryption", translate("encryption"))
o.rmempty = true
o.placeholder = translate("mlkem768x25519plus.native/xorpub/random.1rtt/0rtt.(padding len).(padding gap).(X25519 Password).(ML-KEM-768 Client)...")
o:depends("obfs_vless", "tcp")

o = s:option(Value, "vless_flow", translate("flow"))
o.rmempty = true
o.default = "xtls-rprx-direct"
o:value("xtls-rprx-direct")
o:value("xtls-rprx-origin")
o:value("xtls-rprx-vision")
o:depends("obfs_vless", "tcp")

o = s:option(Value, "grpc_service_name", translate("grpc-service-name"))
o.rmempty = true
o.datatype = "host"
o.placeholder = translate("example")
o:depends("obfs_trojan", "grpc")
o:depends("obfs_vmess", "grpc")
o:depends("obfs_vless", "grpc")

o = s:option(Value, "reality_public_key", translate("public-key(reality)"))
o.rmempty = true
o.placeholder = translate("CrrQSjAG_YkHLwvM2M-7XkKJilgL5upBKCp0od0tLhE")
o:depends("obfs_vless", "grpc")
o:depends("obfs_vless", "tcp")

o = s:option(Value, "reality_short_id", translate("short-id(reality)"))
o.rmempty = true
o.placeholder = translate("10f897e26c4b9478")
o:depends("obfs_vless", "grpc")
o:depends("obfs_vless", "tcp")

-- [[ ShadowSocks inside trojan ]]--
block_field(s, ListValue, "trojan_ss_enabled", "ss-opts-enabled", {type = "trojan"}, {"true", "false"})
block_field(s, ListValue, "trojan_ss_method", "ss-opts-method", {type = "trojan"}, {"none", "aes-128-gcm", "aes-256-gcm", "chacha20-ietf-poly1305", "2022-blake3-aes-128-gcm", "2022-blake3-aes-256-gcm", "2022-blake3-chacha20-poly1305"})
block_field(s, Value, "trojan_ss_password", "ss-opts-password", {type = "trojan"})

o = s:option(Value, "max_early_data", translate("max-early-data"))
o.rmempty = true
o.placeholder = translate("2048")
o:depends("obfs_vmess", "websocket")

o = s:option(Value, "early_data_header_name", translate("early-data-header-name"))
o.rmempty = true
o.placeholder = translate("Sec-WebSocket-Protocol")
o:depends("obfs_vmess", "websocket")

o = s:option(ListValue, "skip_cert_verify", translate("skip-cert-verify"))
o.rmempty = true
o.default = "true"
o:value("true")
o:value("false")
o:depends("obfs", "websocket")
o:depends("obfs_vmess", "none")
o:depends("obfs_vmess", "grpc")
o:depends("obfs_vmess", "websocket")
o:depends("type", "socks5")
o:depends("type", "http")
o:depends("type", "trojan")
o:depends("type", "vless")
o:depends("type", "hysteria")
o:depends("type", "hysteria2")
o:depends("type", "tuic")
o:depends("type", "anytls")
o:depends("type", "trusttunnel")
o:depends("type", "masque")

o = s:option(ListValue, "tls", translate("TLS"))
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

block_field(s, Value, "mkcp_mtu", "mkcp-opts-mtu", {obfs_vmess = "mkcp"}, "uinteger")
block_field(s, Value, "mkcp_tti", "mkcp-opts-tti", {obfs_vmess = "mkcp"}, "uinteger")
block_field(s, Value, "mkcp_uplink_capacity", "mkcp-opts-uplink-capacity", {obfs_vmess = "mkcp"}, "uinteger")
block_field(s, Value, "mkcp_downlink_capacity", "mkcp-opts-downlink-capacity", {obfs_vmess = "mkcp"}, "uinteger")
block_field(s, ListValue, "mkcp_congestion", "mkcp-opts-congestion", {obfs_vmess = "mkcp"}, {"true", "false"})
block_field(s, Value, "mkcp_write_buffer", "mkcp-opts-write-buffer", {obfs_vmess = "mkcp"}, "uinteger")
block_field(s, Value, "mkcp_read_buffer", "mkcp-opts-read-buffer", {obfs_vmess = "mkcp"}, "uinteger")
block_field(s, Value, "mkcp_seed", "mkcp-opts-seed", {obfs_vmess = "mkcp"})
block_field(s, ListValue, "mkcp_header", "mkcp-opts-header", {obfs_vmess = "mkcp"}, {"none", "srtp", "utp", "wechat-video", "dtls", "wireguard"})

block_field(s, Value, "mekya_url", "mekya-opts-url", {obfs_vmess = "mekya"})
block_field(s, Value, "mekya_h2_pool_size", "mekya-opts-h2-pool-size", {obfs_vmess = "mekya"}, "uinteger")
block_field(s, Value, "mekya_max_write_delay", "mekya-opts-max-write-delay", {obfs_vmess = "mekya"}, "uinteger")
block_field(s, Value, "mekya_max_request_size", "mekya-opts-max-request-size", {obfs_vmess = "mekya"}, "uinteger")
block_field(s, Value, "mekya_polling_interval_initial", "mekya-opts-polling-interval-initial", {obfs_vmess = "mekya"}, "uinteger")
block_field(s, Value, "mekya_max_write_size", "mekya-opts-max-write-size", {obfs_vmess = "mekya"}, "uinteger")
block_field(s, Value, "mekya_max_write_duration_ms", "mekya-opts-max-write-duration-ms", {obfs_vmess = "mekya"}, "uinteger")
block_field(s, Value, "mekya_max_simultaneous_write_connection", "mekya-opts-max-simultaneous-write-connection", {obfs_vmess = "mekya"}, "uinteger")
block_field(s, Value, "mekya_packet_writing_buffer", "mekya-opts-packet-writing-buffer", {obfs_vmess = "mekya"}, "uinteger")
block_field(s, Value, "mekya_kcp_mtu", "mekya-opts-kcp-mtu", {obfs_vmess = "mekya"}, "uinteger")
block_field(s, Value, "mekya_kcp_tti", "mekya-opts-kcp-tti", {obfs_vmess = "mekya"}, "uinteger")
block_field(s, Value, "mekya_kcp_uplink_capacity", "mekya-opts-kcp-uplink-capacity", {obfs_vmess = "mekya"}, "uinteger")
block_field(s, Value, "mekya_kcp_downlink_capacity", "mekya-opts-kcp-downlink-capacity", {obfs_vmess = "mekya"}, "uinteger")
block_field(s, ListValue, "mekya_kcp_congestion", "mekya-opts-kcp-congestion", {obfs_vmess = "mekya"}, {"true", "false"})
block_field(s, Value, "mekya_kcp_write_buffer", "mekya-opts-kcp-write-buffer", {obfs_vmess = "mekya"}, "uinteger")
block_field(s, Value, "mekya_kcp_read_buffer", "mekya-opts-kcp-read-buffer", {obfs_vmess = "mekya"}, "uinteger")
block_field(s, Value, "mekya_kcp_seed", "mekya-opts-kcp-seed", {obfs_vmess = "mekya"})
block_field(s, ListValue, "mekya_kcp_header", "mekya-opts-kcp-header", {obfs_vmess = "mekya"}, {"none", "srtp", "utp", "wechat-video", "dtls", "wireguard"})

-- [[ TLS Mirror ]]--
block_field(s, Value, "tlsmirror_primary_key", "tlsmirror-opts-primary-key", {type = "vmess"})
block_field(s, ListValue, "tlsmirror_sequence_watermarking", "tlsmirror-opts-sequence-watermarking-enabled", {type = "vmess"}, {"true", "false"})
block_field(s, DynamicList, "tlsmirror_explicit_nonce_ciphersuites", "tlsmirror-opts-explicit-nonce-ciphersuites", {type = "vmess"})

o = s:option(Value, "keep_alive", translate("keep-alive"))
o.rmempty = true
o.default = "true"
o:value("true")
o:value("false")
o:depends("obfs_vmess", "http")

o = s:option(ListValue, "mux", translate("mux"))
o.rmempty = true
o.default = "false"
o:value("true")
o:value("false")
o:depends("obfs", "websocket")

o = s:option(Value, "sni", translate("sni"))
o.datatype = "host"
o.placeholder = translate("example.com")
o.rmempty = true
o:depends("type", "trojan")
o:depends("type", "http")
o:depends("type", "hysteria")
o:depends("type", "hysteria2")
o:depends("type", "anytls")
o:depends("type", "trusttunnel")
o:depends("type", "tuic")
o:depends("type", "masque")

o = s:option(DynamicList, "http_headers", translate("headers"))
o.rmempty = true
o.placeholder = translate("User-Agent: okhttp/3.11.0 Dalvik/2.1.0 ...... ")
o:depends("type", "http")

-- the socks5/http/ssh/trusttunnel user and password are the shared username/password fields

o = s:option(Value, "private_key", translate("private-key"))
o:depends("type", "ssh")
o:depends("type", "anytls")
o:depends("type", "http")
o:depends("type", "hysteria")
o:depends("type", "hysteria2")
o:depends("type", "socks5")
o:depends("type", "trojan")
o:depends("type", "trusttunnel")
o:depends("type", "tuic")
o:depends("type", "vless")
o:depends("type", "vmess")
o.rmempty = true

o = s:option(Value, "private_key_passphrase", translate("private-key-passphrase"))
o:depends("type", "ssh")
o.rmempty = true

o = s:option(DynamicList, "host_key", translate("host-key"))
o:depends("type", "ssh")
o.rmempty = true

o = s:option(DynamicList, "host_key_algorithms", translate("host-key-algorithms"))
o:depends("type", "ssh")
o.rmempty = true

o = s:option(DynamicList, "alpn", translate("alpn"))
o.rmempty = true
o:value("h2")
o:value("http/1.1")
o:depends("type", "trojan")
o:depends("type", "anytls")
o:depends("type", "trusttunnel")

-- the alpn list of hysteria / hysteria2 / tuic is the shared `alpn` option, see above

o = s:option(Value, "hysteria_obfs", translate("obfs"))
o.rmempty = true
o.placeholder = translate("obfs-str")
o:depends("type", "hysteria")
o:depends("type", "hysteria2")

-- [[ hysteria_obfs_password ]]-- is the shared obfs_password option, see above

o = s:option(Value, "hysteria_auth", translate("auth"))
o.rmempty = true
o.placeholder = translate("[BASE64]")
o:depends("type", "hysteria")

o = s:option(Value, "hysteria_auth_str", translate("auth_str"))
o.rmempty = true
o.placeholder = translate("yubiyubi")
o:depends("type", "hysteria")

o = s:option(Flag, "flag_quicparam", translate("Hysterir QUIC parameters"))
o:depends("type", "hysteria")
o:depends("type", "hysteria2")
o.rmempty = true
o.default = "0"

o = s:option(Value, "recv_window_conn", translate("recv_window_conn"))
o.rmempty = true
o.placeholder = translate("QUIC stream receive window")
o.datatype = "uinteger"
o:depends({type = "hysteria", flag_quicparam = true})

o = s:option(Value, "recv_window", translate("recv_window"))
o.rmempty = true
o.placeholder = translate("QUIC connection receive window")
o.datatype = "uinteger"
o:depends({type = "hysteria", flag_quicparam = true})

o = s:option(Value, "initial_stream_receive_window", translate("initial_stream_receive_window"))
o.rmempty = true
o.placeholder = translate("QUIC init stream receive window")
o.datatype = "uinteger"
o:depends({type = "hysteria2", flag_quicparam = true})

o = s:option(Value, "max_stream_receive_window", translate("max_stream_receive_window"))
o.rmempty = true
o.placeholder = translate("QUIC max stream receive window")
o.datatype = "uinteger"
o:depends({type = "hysteria2", flag_quicparam = true})

o = s:option(Value, "initial_connection_receive_window", translate("initial_connection_receive_window"))
o.rmempty = true
o.placeholder = translate("QUIC init connection receive window")
o.datatype = "uinteger"
o:depends({type = "hysteria2", flag_quicparam = true})

o = s:option(Value, "max_connection_receive_window", translate("max_connection_receive_window"))
o.rmempty = true
o.placeholder = translate("QUIC max connection receive window")
o.datatype = "uinteger"
o:depends({type = "hysteria2", flag_quicparam = true})

o = s:option(Value, "hop_interval", translate("Hop Interval (Unit:second)"))
o.rmempty = true
o.default = "10"
o:depends({type = "hysteria", flag_transport = true, flag_port_hopping = true})
o:depends({type = "hysteria2", flag_port_hopping = true})

o = s:option(ListValue, "disable_mtu_discovery", translate("disable_mtu_discovery"))
o.rmempty = true
o:value("true")
o:value("false")
o.default = "false"
o:depends({type = "hysteria", flag_quicparam = true})

o = s:option(ListValue, "packet_addr", translate("Packet-Addr"))
o.rmempty = true
o.default = "true"
o:value("true")
o:value("false")
o:depends({type = "vless", xudp = "false"})
o:depends({type = "vmess", xudp = "false"})

o = s:option(Value, "packet_encoding", translate("Packet-Encoding"))
o.rmempty = true
o:depends("type", "vmess")
o:depends("type", "vless")

o = s:option(ListValue, "global_padding", translate("Global-Padding"))
o.rmempty = true
o.default = "false"
o:value("true")
o:value("false")
o:depends("type", "vmess")

o = s:option(ListValue, "authenticated_length", translate("Authenticated-Length"))
o.rmempty = true
o.default = "false"
o:value("true")
o:value("false")
o:depends("type", "vmess")

-- [[ AnyTLS ]] --
o = s:option(Value, "idle_session_check_interval", translate("idle-session-check-interval"))
o.rmempty = true
o.default = "30"
o:depends("type", "anytls")

o = s:option(Value, "idle_session_timeout", translate("idle-session-timeout"))
o.rmempty = true
o.default = "30"
o:depends("type", "anytls")

o = s:option(Value, "min_idle_session", translate("min-idle-session"))
o.rmempty = true
o.default = "0"
o:depends("type", "anytls")

-- [[ MASQUE ]] --
o = s:option(ListValue, "remote_dns_resolve", translate("Remote DNS Resolve"))
o.rmempty = true
o.default = "true"
o:value("true")
o:value("false")
o:depends("type", "masque")

o = s:option(ListValue, "masque_network", translate("network"))
o.rmempty = true
o:value("h3")
o:value("h2")
o:value("h3-l4proxy")
o:depends("type", "masque")

-- [[ TrustTunnel ]] --
o = s:option(ListValue, "trusttunnel_health_check", translate("Health Check"))
o.rmempty = true
o.default = "true"
o:value("true")
o:value("false")
o:depends("type", "trusttunnel")

o = s:option(ListValue, "trusttunnel_quic", translate("QUIC"))
o.rmempty = true
o.default = "false"
o:value("true")
o:value("false")
o:depends("type", "trusttunnel")

o = s:option(ListValue, "trusttunnel_congestion_controller", translate("Congestion Controller"))
o.rmempty = true
o.default = "bbr"
o:value("bbr")
o:depends("type", "trusttunnel")

o = s:option(Value, "trusttunnel_max_connections", translate("max-connections"))
o.rmempty = true
o.datatype = "uinteger"
o:depends("type", "trusttunnel")

o = s:option(Value, "trusttunnel_min_streams", translate("min-streams"))
o.rmempty = true
o.datatype = "uinteger"
o:depends("type", "trusttunnel")

o = s:option(Value, "trusttunnel_max_streams", translate("max-streams"))
o.rmempty = true
o.datatype = "uinteger"
o:depends("type", "trusttunnel")

-- [[ Fast Open ]]--
o = s:option(ListValue, "fast_open", translate("Fast Open"))
o.rmempty = true
o.default = "true"
o:value("true")
o:value("false")
o:depends("type", "hysteria")
o:depends("type", "tuic")

o = s:option(ListValue, "tfo", translate("TFO"))
o.rmempty = true
o.default = "false"
o:value("true")
o:value("false")
o:depends("type", "http")
o:depends("type", "socks5")
o:depends("type", "trojan")
o:depends("type", "vless")
o:depends("type", "vmess")
o:depends("type", "ss")
o:depends("type", "ssr")
o:depends("type", "snell")

o = s:option(Value, "fingerprint", translate("Fingerprint"))
o.rmempty = true
o:depends("type", "hysteria")
o:depends("type", "hysteria2")
o:depends("type", "socks5")
o:depends("type", "http")
o:depends("type", "trojan")
o:depends("type", "vless")
o:depends("type", "anytls")
o:depends("type", "trusttunnel")
o:depends("type", "tuic")
o:depends({type = "ss", obfs = "websocket"})
o:depends({type = "ss", obfs = "shadow-tls"})
o:depends({type = "vmess", obfs_vmess = "websocket"})
o:depends({type = "vmess", obfs_vmess = "h2"})
o:depends({type = "vmess", obfs_vmess = "grpc"})

o = s:option(ListValue, "client_fingerprint", translate("Client Fingerprint"))
o.rmempty = true
o:value("none")
o:value("random")
o:value("chrome")
o:value("firefox")
o:value("safari")
o:value("ios")
o.default = "none"
o:depends("type", "vless")
o:depends({type = "ss", obfs = "restls"})
o:depends({type = "ss", obfs = "shadow-tls"})
o:depends({type = "trojan", obfs_vmess = "grpc"})
o:depends({type = "vmess", obfs_vmess = "websocket"})
o:depends({type = "vmess", obfs_vmess = "http"})
o:depends({type = "vmess", obfs_vmess = "h2"})
o:depends({type = "vmess", obfs_vmess = "grpc"})
o:depends("type", "anytls")
o:depends("type", "trusttunnel")

-- [[ ip version ]]--
o = s:option(ListValue, "ip_version", translate("IP Version"))
o.rmempty = true
o:value("dual")
o:value("ipv4")
o:value("ipv4-prefer")
o:value("ipv6")
o:value("ipv6-prefer")
o.default = "ipv4-prefer"
o:depends("type", "ss")
o:depends("type", "ssr")
o:depends("type", "vmess")
o:depends("type", "trojan")
o:depends("type", "vless")
o:depends("type", "hysteria")
o:depends("type", "hysteria2")
o:depends("type", "wireguard")
o:depends("type", "tuic")
o:depends("type", "mieru")
o:depends("type", "snell")
o:depends("type", "socks5")
o:depends("type", "http")
o:depends("type", "ssh")
o:depends("type", "direct")

o = s:option(ListValue, "multiplex", translate("Multiplex"))
o.rmempty = false
o:value("true")
o:value("false")
o.default = "false"
o:depends({type = "ss", obfs = "none"})

o = s:option(ListValue, "multiplex_protocol", translate("Protocol"))
o.rmempty = true
o:value("smux")
o:value("yamux")
o:value("h2mux")
o.default = "smux"
o:depends("multiplex", "true")

o = s:option(Value, "multiplex_max_connections", translate("Max-connections"))
o.rmempty = true
o.placeholder = "4"
o.default = "4"
o.datatype = "uinteger"
o:depends("multiplex", "true")

o = s:option(Value, "multiplex_min_streams", translate("Min-streams"))
o.rmempty = true
o.placeholder = "4"
o.default = "4"
o.datatype = "uinteger"
o:depends("multiplex", "true")

o = s:option(Value, "multiplex_max_streams", translate("Max-streams"))
o.rmempty = true
o.placeholder = "0"
o.default = "0"
o.datatype = "uinteger"
o:depends("multiplex", "true")

o = s:option(ListValue, "multiplex_padding", translate("Padding"))
o.rmempty = false
o:value("true")
o:value("false")
o.default = "false"
o:depends("multiplex", "true")

o = s:option(ListValue, "multiplex_statistic", translate("Statistic"))
o.rmempty = false
o:value("true")
o:value("false")
o.default = "false"
o:depends("multiplex", "true")

o = s:option(ListValue, "multiplex_only_tcp", translate("Only-tcp"))
o.rmempty = false
o:value("true")
o:value("false")
o.default = "false"
o:depends("multiplex", "true")

-- [[ Fields mihomo accepts that had no uci option before ]] --

o = s:option(ListValue, "udp_over_tcp_version", translate("udp-over-tcp-version"))
o.rmempty = true
o:value("1")
o:value("2")
o:depends("type", "ss")

o = s:option(Flag, "ws_opts_v2ray_http_upgrade", translate("v2ray-http-upgrade"))
o.rmempty = true
o.default = "0"
o:depends("obfs_vmess", "websocket")
o:depends("obfs_vless", "ws")
o:depends("obfs_trojan", "ws")

o = s:option(Flag, "ws_opts_v2ray_http_upgrade_fast_open", translate("v2ray-http-upgrade-fast-open"))
o.rmempty = true
o.default = "0"
o:depends("obfs_vmess", "websocket")
o:depends("obfs_vless", "ws")
o:depends("obfs_trojan", "ws")

o = s:option(Flag, "reality_support_x25519mlkem768", translate("support-x25519mlkem768"))
o.rmempty = true
o.default = "0"
o:depends("obfs_vless", "tcp")
o:depends("obfs_vless", "grpc")

o = s:option(Value, "name_cert_verify", translate("name-cert-verify"))
o.rmempty = true
o.placeholder = translate("example.com")
o:depends("type", "vmess")
o:depends("type", "vless")
o:depends("type", "trojan")
o:depends("type", "hysteria")
o:depends("type", "hysteria2")
o:depends("type", "tuic")
o:depends("type", "anytls")
o:depends("type", "masque")
o:depends("type", "trusttunnel")
o:depends("type", "socks5")
o:depends("type", "http")

o = s:option(Value, "hysteria_up_speed", translate("up-speed (Mbps)"))
o.rmempty = true
o.datatype = "uinteger"
o:depends("type", "hysteria")

o = s:option(Value, "hysteria_down_speed", translate("down-speed (Mbps)"))
o.rmempty = true
o.datatype = "uinteger"
o:depends("type", "hysteria")

o = s:option(ListValue, "hysteria_obfs_protocol", translate("obfs-protocol"))
o.rmempty = true
o:value("salamander")
o:depends("type", "hysteria")

o = s:option(Value, "hysteria_obfs_min_packet_size", translate("obfs-min-packet-size"))
o.rmempty = true
o.datatype = "uinteger"
o:depends("type", "hysteria2")

o = s:option(Value, "hysteria_obfs_max_packet_size", translate("obfs-max-packet-size"))
o.rmempty = true
o.datatype = "uinteger"
o:depends("type", "hysteria2")

o = s:option(Value, "cwnd", translate("cwnd"))
o.rmempty = true
o.datatype = "uinteger"
o:depends("type", "hysteria2")
o:depends("type", "tuic")
o:depends("type", "masque")
o:depends("type", "trusttunnel")

o = s:option(ListValue, "bbr_profile", translate("bbr-profile"))
o.rmempty = true
o:value("conservative")
o:value("standard")
o:value("aggressive")
o:depends("type", "hysteria2")
o:depends("type", "tuic")
o:depends("type", "masque")
o:depends("type", "trusttunnel")

o = s:option(Value, "udp_mtu", translate("udp-mtu"))
o.rmempty = true
o.datatype = "uinteger"
o:depends("type", "hysteria2")

o = s:option(Value, "handshake_timeout", translate("handshake-timeout"))
o.rmempty = true
o.datatype = "uinteger"
o:depends("type", "hysteria2")
o:depends("type", "masque")

o = s:option(Value, "max_datagram_frame_size", translate("max-datagram-frame-size"))
o.rmempty = true
o.datatype = "uinteger"
o:depends("type", "tuic")

o = s:option(Flag, "udp_over_stream", translate("udp-over-stream"))
o.rmempty = true
o.default = "0"
o:depends("type", "tuic")

o = s:option(Value, "udp_over_stream_version", translate("udp-over-stream-version"))
o.rmempty = true
o.datatype = "uinteger"
o:depends("type", "tuic")

o = s:option(Value, "persistent_keepalive", translate("persistent-keepalive"))
o.rmempty = true
o.datatype = "uinteger"
o:depends("type", "wireguard")

o = s:option(Value, "workers", translate("workers"))
o.rmempty = true
o.datatype = "uinteger"
o:depends("type", "wireguard")

o = s:option(DynamicList, "reserved", translate("reserved"))
o.rmempty = true
o.datatype = "uinteger"
o.placeholder = translate("0, 0, 0")
o:depends("type", "wireguard")

o = s:option(ListValue, "ip_stack", translate("ip-stack"))
o.rmempty = true
o:value("system")
o:value("gvisor")
o:value("mixed")
o:depends("type", "wireguard")
o:depends("type", "masque")

o = s:option(Value, "refresh_server_ip_interval", translate("refresh-server-ip-interval"))
o.rmempty = true
o.datatype = "uinteger"
o:depends("type", "wireguard")

block_field(s, Value, "amnezia_version", "amnezia-wg-option-version", {type = "wireguard"}, "uinteger")
block_field(s, Value, "amnezia_jc", "amnezia-wg-option-jc", {type = "wireguard"}, "uinteger")
block_field(s, Value, "amnezia_jmin", "amnezia-wg-option-jmin", {type = "wireguard"}, "uinteger")
block_field(s, Value, "amnezia_jmax", "amnezia-wg-option-jmax", {type = "wireguard"}, "uinteger")
block_field(s, Value, "amnezia_s1", "amnezia-wg-option-s1", {type = "wireguard"}, "uinteger")
block_field(s, Value, "amnezia_s2", "amnezia-wg-option-s2", {type = "wireguard"}, "uinteger")
block_field(s, Value, "amnezia_s3", "amnezia-wg-option-s3", {type = "wireguard"}, "uinteger")
block_field(s, Value, "amnezia_s4", "amnezia-wg-option-s4", {type = "wireguard"}, "uinteger")
block_field(s, Value, "amnezia_h1", "amnezia-wg-option-h1", {type = "wireguard"})
block_field(s, Value, "amnezia_h2", "amnezia-wg-option-h2", {type = "wireguard"})
block_field(s, Value, "amnezia_h3", "amnezia-wg-option-h3", {type = "wireguard"})
block_field(s, Value, "amnezia_h4", "amnezia-wg-option-h4", {type = "wireguard"})

o = s:option(Flag, "anytls_disable_reuse", translate("disable-reuse"))
o.rmempty = true
o.default = "0"
o:depends("type", "anytls")

o = s:option(Value, "anytls_client_metadata", translate("client-metadata"))
o.rmempty = true
o:depends("type", "anytls")

o = s:option(ListValue, "mieru_handshake_mode", translate("handshake-mode"))
o.rmempty = true
o:value("HANDSHAKE_STANDARD")
o:value("HANDSHAKE_NO_WAIT")
o:depends("type", "mieru")

o = s:option(Value, "mieru_traffic_pattern", translate("traffic-pattern"))
o.rmempty = true
o:depends("type", "mieru")

o = s:option(Flag, "snell_reuse", translate("reuse"))
o.rmempty = true
o.default = "0"
o:depends("type", "snell")

o = s:option(Value, "uri", translate("uri"))
o.rmempty = true
o:depends("type", "masque")

-- [[ Tailscale ]] --
o = s:option(Value, "hostname", translate("hostname"))
o.rmempty = true
o.placeholder = translate("openclash-node")
o:depends("type", "tailscale")

o = s:option(Value, "auth_key", translate("auth-key"))
o.rmempty = true
o.password = true
o.placeholder = translate("tskey-auth-xxxxxxxxxxxxxxxx")
o:depends("type", "tailscale")

o = s:option(Value, "control_url", translate("control-url"))
o.rmempty = true
o.placeholder = translate("https://controlplane.tailscale.com")
o:depends("type", "tailscale")

o = s:option(Value, "exit_node", translate("exit-node"))
o.rmempty = true
o.placeholder = translate("100.64.0.1")
o:depends("type", "tailscale")

o = s:option(ListValue, "ephemeral", translate("ephemeral"))
o.rmempty = true
o.default = "false"
o:value("true")
o:value("false")
o:depends("type", "tailscale")

o = s:option(ListValue, "accept_routes", translate("accept-routes"))
o.rmempty = true
o.default = "false"
o:value("true")
o:value("false")
o:depends("type", "tailscale")

o = s:option(ListValue, "exit_node_allow_lan_access", translate("exit-node-allow-lan-access"))
o.rmempty = true
o.default = "false"
o:value("true")
o:value("false")
o:depends("type", "tailscale")

-- [[ ZeroTier ]] --
o = s:option(Value, "network", translate("network"))
o.rmempty = true
o.placeholder = translate("8056c2e21c000001")
o:depends("type", "zerotier")

o = s:option(Value, "planet", translate("planet"))
o.rmempty = true
o.placeholder = translate("/etc/openclash/planet")
o.description = font_red..bold_on..translate("A custom planet file. An orbit (a world and its seed) belongs to Other Parameters")..bold_off..font_off
o:depends("type", "zerotier")

o = s:option(Value, "state_dir", translate("state-dir"))
o.rmempty = true
o.placeholder = translate("/etc/openclash/state")
o:depends("type", "tailscale")
o:depends("type", "zerotier")

o = s:option(Value, "physical_mtu", translate("physical-mtu"))
o.rmempty = true
o.datatype = "uinteger"
o.placeholder = translate("1400")
o:depends("type", "zerotier")

o = s:option(Value, "primary_port", translate("primary-port"))
o.rmempty = true
o.datatype = "port"
o.placeholder = translate("9993")
o:depends("type", "zerotier")

o = s:option(Value, "secondary_port", translate("secondary-port"))
o.rmempty = true
o.datatype = "port"
o.placeholder = translate("9993")
o:depends("type", "zerotier")

o = s:option(Value, "tcp_fallback_relay", translate("tcp-fallback-relay"))
o.rmempty = true
o.placeholder = translate("host:port")
o:depends("type", "zerotier")

o = s:option(ListValue, "tcp_fallback_mode", translate("tcp-fallback-mode"))
o.rmempty = true
o:value("auto")
o:value("force")
o:value("disable")
o.description = translate("auto: relay only when the direct path fails, force: always relay, disable: off")
o:depends("type", "zerotier")

o = s:option(ListValue, "low_bandwidth", translate("low-bandwidth"))
o.rmempty = true
o.default = "false"
o:value("true")
o:value("false")
o:depends("type", "zerotier")

o = s:option(ListValue, "encrypted_hello", translate("encrypted-hello"))
o.rmempty = true
o.default = "false"
o:value("true")
o:value("false")
o:depends("type", "zerotier")

o = s:option(Value, "remote_trace_target", translate("remote-trace-target"))
o.rmempty = true
o:depends("type", "zerotier")

o = s:option(Value, "remote_trace_level", translate("remote-trace-level"))
o.rmempty = true
o.datatype = "uinteger"
o.placeholder = translate("0")
o:depends("type", "zerotier")

-- [[ OpenVPN ]] --
o = s:option(ListValue, "proto", translate("proto"))
o.rmempty = true
o.default = "udp"
o:value("udp")
o:value("tcp")
o:depends("type", "openvpn")

o = s:option(Value, "dev", translate("dev"))
o.rmempty = true
o.placeholder = translate("tun")
o:depends("type", "openvpn")

o = s:option(Value, "cipher", translate("cipher"))
o.rmempty = true
o.placeholder = translate("AES-256-GCM")
o:depends("type", "openvpn")

o = s:option(DynamicList, "data_ciphers", translate("data-ciphers"))
o.rmempty = true
o.placeholder = translate("AES-256-GCM")
o:depends("type", "openvpn")

o = s:option(Value, "data_ciphers_fallback", translate("data-ciphers-fallback"))
o.rmempty = true
o.placeholder = translate("AES-256-CBC")
o:depends("type", "openvpn")

o = s:option(Value, "auth", translate("auth"))
o.rmempty = true
o.placeholder = translate("SHA256")
o:depends("type", "openvpn")

o = s:option(ListValue, "comp_lzo", translate("comp-lzo"))
o.rmempty = true
o:value("no")
o:value("yes")
o:value("adaptive")
o:depends("type", "openvpn")

o = s:option(ListValue, "key_direction", translate("key-direction"))
o.rmempty = true
o:value("0")
o:value("1")
o:depends("type", "openvpn")

o = s:option(Value, "ping", translate("ping"))
o.rmempty = true
o.datatype = "uinteger"
o:depends("type", "openvpn")

o = s:option(Value, "ping_restart", translate("ping-restart"))
o.rmempty = true
o.datatype = "uinteger"
o:depends("type", "openvpn")

o = s:option(Value, "tran_window", translate("tran-window"))
o.rmempty = true
o.datatype = "uinteger"
o:depends("type", "openvpn")

o = s:option(DynamicList, "peer_info", translate("peer-info"))
o.rmempty = true
o.placeholder = translate("key: value")
o:depends("type", "openvpn")

certificate(s, "ca", "ca", "openvpn")
certificate(s, "cert", "cert", "openvpn")
certificate(s, "key", "key", "openvpn")
certificate(s, "tls_auth", "tls-auth", "openvpn")
certificate(s, "tls_crypt", "tls-crypt", "openvpn")
certificate(s, "tls_crypt_v2", "tls-crypt-v2", "openvpn")

-- [[ ShadowQUIC ]] --
o = s:option(Value, "keep_alive_interval", translate("keep-alive-interval"))
o.rmempty = true
o.datatype = "uinteger"
o:depends("type", "shadowquic")

o = s:option(ListValue, "zero_rtt", translate("zero-rtt"))
o.rmempty = true
o.default = "false"
o:value("true")
o:value("false")
o:depends("type", "shadowquic")

o = s:option(DynamicList, "quic_versions", translate("quic-versions"))
o.rmempty = true
o.placeholder = translate("v1")
o:depends("type", "shadowquic")

-- [[ GostRelay ]] --
o = s:option(ListValue, "forward", translate("forward"))
o.rmempty = true
o.default = "false"
o:value("true")
o:value("false")
o:depends("type", "gost-relay")

certificate(s, "certificate", "certificate", "gost-relay", "anytls", "http", "hysteria", "hysteria2", "socks5", "trojan", "trusttunnel", "tuic", "vless", "vmess")

o = s:option(Value, "interface_name", translate("interface-name"))
o.rmempty = true
o.placeholder = translate("eth0")
o:depends("type", "ss")
o:depends("type", "ssr")
o:depends("type", "vmess")
o:depends("type", "trojan")
o:depends("type", "vless")
o:depends("type", "hysteria")
o:depends("type", "hysteria2")
o:depends("type", "wireguard")
o:depends("type", "tuic")
o:depends("type", "mieru")
o:depends("type", "snell")
o:depends("type", "socks5")
o:depends("type", "http")
o:depends("type", "ssh")
o:depends("type", "direct")

o = s:option(Value, "routing_mark", translate("routing-mark"))
o.rmempty = true
o.placeholder = translate("2333")
o:depends("type", "ss")
o:depends("type", "ssr")
o:depends("type", "vmess")
o:depends("type", "trojan")
o:depends("type", "vless")
o:depends("type", "hysteria")
o:depends("type", "hysteria2")
o:depends("type", "wireguard")
o:depends("type", "tuic")
o:depends("type", "mieru")
o:depends("type", "snell")
o:depends("type", "socks5")
o:depends("type", "http")
o:depends("type", "ssh")
o:depends("type", "direct")

o = s:option(Value, "other_parameters", translate("Other Parameters"))
o.template = "cbi/tvalue"
o.rows = 20
o.wrap = "off"
o.description = font_red..bold_on..translate("Edit Your Other Parameters Here")..bold_off..font_off
o.rmempty = true
function o.cfgvalue(self, section)
	if self.map:get(section, "other_parameters") == nil then
		return "# Example:\n"..
		"# Only support YAML, four spaces need to be reserved at the beginning of each line to maintain formatting alignment\n"..
		"# 示例：\n"..
		"# 仅支持 YAML, 每行行首需要多保留四个空格以使脚本处理后能够与上方配置保持格式对齐\n"..
		"#    type: ss\n"..
		"#    server: \"127.0.0.1\"\n"..
		"#    port: 443\n"..
		"#    cipher: rc4-md5\n"..
		"#    password: \"123456\"\n"..
		"#    udp: true\n"..
		"#    udp-over-tcp: false\n"..
		"#    ip-version: \"dual\"\n"..
		"#    tfo: true\n"..
		"#    smux:\n"..
		"#      enabled: false\n"..
		"#    plugin-opts:\n"..
		"#      mode: tls\n"..
		"#      host: world.taobao.com"
	else
		return Value.cfgvalue(self, section)
	end
end
function o.validate(self, value)
	if value then
		value = value:gsub("\r\n?", "\n")
		value = value:gsub("%c*$", "")
	end
	return value
end

o = s:option(Value, "dialer_proxy", translate("Dialer-proxy"))
o.rmempty = true
o.description = font_red..bold_on..translate("The added Dialer Proxy or Group Must Exist")..bold_off..font_off
m.uci:foreach("openclash", "proxy_groups",
function(s)
	if s.name ~= "" and s.name ~= nil and (s.config == m.uci:get(openclash, sid, "config") or s.config == "all") then
		o:value(s.name)
	end
end)

o = s:option(DynamicList, "groups", translate("Proxy Group (Support Regex)"))
o.description = font_red..bold_on..translate("The added Proxy Groups Must Exist")..bold_off..font_off
o.rmempty = true
o:value("all", translate("All Groups"))
m.uci:foreach("openclash", "proxy_groups",
function(s)
	if s.name ~= "" and s.name ~= nil and (s.config == m.uci:get(openclash, sid, "config") or s.config == "all") then
		o:value(s.name)
	end
end)

-- [[ Fields the node types above share ]] --
-- The types added later take part in the fields declared above instead of repeating them,
-- so a dependency of such a field is declared here.
local shared_fields = {
	server = {"openvpn", "shadowquic", "gost-relay"},
	port = {"openvpn", "shadowquic", "gost-relay"},
	udp = {"tailscale", "zerotier", "openvpn", "gost-relay"},
	tfo = {"tailscale", "zerotier", "openvpn", "shadowquic", "gost-relay"},
	ip_version = {"tailscale", "zerotier", "openvpn", "shadowquic", "gost-relay"},
	interface_name = {"tailscale", "zerotier", "openvpn", "shadowquic", "gost-relay"},
	routing_mark = {"tailscale", "zerotier", "openvpn", "shadowquic", "gost-relay"},
	dns = {"zerotier", "openvpn"},
	mtu = {"openvpn", "zerotier"},
	ip_stack = {"openvpn", "zerotier"},
	remote_dns_resolve = {"zerotier", "openvpn", "wireguard"},
	handshake_timeout = {"openvpn"},
	username = {"socks5", "http", "ssh", "trusttunnel", "openvpn", "shadowquic", "gost-relay"},
	password = {"socks5", "http", "ssh", "trusttunnel", "openvpn", "shadowquic", "gost-relay"},
	tls = {"gost-relay"},
	skip_cert_verify = {"gost-relay"},
	sni = {"shadowquic", "gost-relay"},
	fingerprint = {"gost-relay"},
	client_fingerprint = {"gost-relay"},
	name_cert_verify = {"gost-relay"},
	mux = {"gost-relay"},
	hysteria_up = {"shadowquic"},
	hysteria_down = {"shadowquic"},
	cwnd = {"shadowquic"},
	bbr_profile = {"shadowquic"},
	congestion_controller = {"shadowquic"},
	recv_window = {"shadowquic"},
	recv_window_conn = {"shadowquic"},
	disable_mtu_discovery = {"shadowquic"},
	max_open_streams = {"shadowquic"},
	max_datagram_frame_size = {"shadowquic"},
	udp_over_stream = {"shadowquic"}
}
for name, types in pairs(shared_fields) do
	local field = s.fields[name]
	if field then
		for _, node_type in ipairs(types) do
			field:depends("type", node_type)
		end
	end
end

-- A password is a field of every type above, but only some of them need one
require_by_type(s.fields.port)
require_by_type(s.fields.hysteria_up)
require_by_type(s.fields.hysteria_down)
require_by_type(s.fields.username, {socks5 = true, http = true, ssh = true, trusttunnel = true, openvpn = true, shadowquic = true, ["gost-relay"] = true})
require_by_type(s.fields.password, {socks5 = true, http = true, ssh = true, trusttunnel = true, openvpn = true, shadowquic = true, ["gost-relay"] = true})

local t = {
	{Commit, Back}
}
a = m:section(Table, t)

o = a:option(Button,"Commit", " ")
o.inputtitle = translate("Commit Settings")
o.inputstyle = "apply"
o.write = function()
	m.uci:commit(openclash)
	HTTP.redirect(m.redirect)
end

o = a:option(Button,"Back", " ")
o.inputtitle = translate("Back Settings")
o.inputstyle = "reset"
o.write = function()
	m.uci:revert(openclash, sid)
	HTTP.redirect(m.redirect)
end

m:append(Template("openclash/toolbar_show"))
m:append(Template("openclash/config_editor"))
return m
