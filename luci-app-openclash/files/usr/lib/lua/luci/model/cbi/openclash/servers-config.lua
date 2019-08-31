-- Copyright (C) 2017 yushi studio <ywb94@qq.com> github.com/ywb94
-- Licensed to the public under the GNU General Public License v3.

local m, s, o
local openclash = "openclash"
local uci = luci.model.uci.cursor()
local ipkg = require("luci.model.ipkg")
local fs = require "nixio.fs"
local sys = require "luci.sys"
local sid = arg[1]
local uuid = luci.sys.exec("cat /proc/sys/kernel/random/uuid")


local server_table = {}

local encrypt_methods_ss = {
	-- aead
	"AEAD_AES_128_GCM",
	"AEAD_AES_192_GCM",
	"AEAD_AES_256_GCM",
	"AEAD_CHACHA20_POLY1305",
	
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
	"chacha20",
	"chacha20-ietf",
	"chacha20-ietf-poly1305",
	"xchacha20-ietf-poly1305",
}

local securitys = {
    "auto",
    "none",
    "aes-128-gcm",
    "chacha20-poly1305"
}

m = Map(openclash, translate("Edit Server"))
m.redirect = luci.dispatcher.build_url("admin/services/openclash/servers")
if m.uci:get(openclash, sid) ~= "servers" then
	luci.http.redirect(m.redirect) 
	return
end

-- [[ Servers Setting ]]--
s = m:section(NamedSection, sid, "servers")
s.anonymous = true
s.addremove   = false

o = s:option(ListValue, "type", translate("Server Node Type"))
o:value("ss", translate("Shadowsocks"))
o:value("vmess", translate("Vmess"))
o:value("socks5", translate("Socks5"))
o:value("http", translate("HTTP(S)"))

o.description = translate("Using incorrect encryption mothod may causes service fail to start")

o = s:option(Value, "name", translate("Alias"))
o.default = "Server"
o.rmempty = false

o = s:option(Value, "server", translate("Server Address"))
o.datatype = "host"
o.rmempty = false

o = s:option(Value, "port", translate("Server Port"))
o.datatype = "port"
o.rmempty = false

o = s:option(Value, "password", translate("Password"))
o.password = true
o.rmempty = true
o:depends("type", "ss")

o = s:option(ListValue, "cipher", translate("Encrypt Method"))
for _, v in ipairs(encrypt_methods_ss) do o:value(v) end
o.rmempty = true
o:depends("type", "ss")

o = s:option(ListValue, "securitys", translate("Encrypt Method"))
for _, v in ipairs(securitys) do o:value(v, v:upper()) end
o.rmempty = true
o:depends("type", "vmess")

o = s:option(ListValue, "udp", translate("UDP Enable"))
o.rmempty = false
o.default = "false"
o:value("true")
o:value("false")
o:depends("type", "ss")

o = s:option(ListValue, "obfs", translate("obfs-mode"))
o.rmempty = false
o.default = "none"
o:value("none")
o:value("tls")
o:value("http")
o:value("websocket", translate("websocket (ws)"))
o:depends("type", "ss")

o = s:option(ListValue, "obfs_vmess", translate("obfs-mode"))
o.rmempty = false
o.default = "none"
o:value("none")
o:value("websocket", translate("websocket (ws)"))
o:depends("type", "vmess")

o = s:option(Value, "host", translate("obfs-hosts"))
o.datatype = "host"
o.rmempty = true
o:depends("obfs", "tls")
o:depends("obfs", "http")

o = s:option(Value, "custom", translate("ws-headers"))
o.rmempty = true
o:depends("obfs", "websocket")
o:depends("obfs_vmess", "websocket")

-- [[ WS部分 ]]--

-- WS路径
o = s:option(Value, "path", translate("ws-Path"))
o.rmempty = true
o:depends("obfs", "websocket")
o:depends("obfs_vmess", "websocket")

-- AlterId
o = s:option(Value, "alterId", translate("AlterId"))
o.datatype = "port"
o.default = 16
o.rmempty = true
o:depends("type", "vmess")

-- VmessId
o = s:option(Value, "uuid", translate("VmessId (UUID)"))
o.rmempty = true
o.default = uuid
o:depends("type", "vmess")

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

-- [[ skip-cert-verify ]]--
o = s:option(ListValue, "skip_cert_verify", translate("Skip Cert Verify"))
o.rmempty = true
o.default = "false"
o:value("true")
o:value("false")
o:depends("type", "vmess")
o:depends("type", "socks5")
o:depends("type", "http")

-- [[ TLS ]]--
o = s:option(ListValue, "tls", translate("TLS"))
o.rmempty = true
o.default = "false"
o:value("true")
o:value("false")
o:depends("type", "vmess")
o:depends("type", "socks5")
o:depends("type", "http")

return m
