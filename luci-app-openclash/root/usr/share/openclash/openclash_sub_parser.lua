#!/usr/bin/lua
-- Prints one server address per node of a subscription file, the fallback of the watchdog
-- for provider files that are not YAML.
--
-- The share links are the ones mihomo accepts (common/convert/converter.go), they follow
-- the schemes of the clients themselves:
--   ss://        SIP002, with the plugin query, or the legacy fully encoded form
--   ssr://       base64 of host:port:protocol:method:obfs:password/?params
--   vmess://     V2RayN base64 json, or the Xray VMessAEAD uri (XTLS/Xray-core#716)
--   vless://     Xray uri, the host of the uri may be base64 encoded
--   trojan://    password as userinfo
--   hysteria://  github.com/apernet/hysteria (docs/developers/URI-Scheme)
--   hysteria2:// and hy2://, also with the +realm suffix and with port hopping
--   tuic://      temporary unofficial standard, uuid:password or the v5 token as userinfo
--   anytls://    github.com/anytls/anytls-go (docs/uri_scheme.md)
--   mierus://    one uri per profile, the port and protocol query keys are repeated
--   socks5://, socks5h://, http://, https://
--
-- Only the server address is needed, every other part of the uri is ignored.

local util = require "luci.util"
local jsonc = require "luci.jsonc"

local BASE64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local BASE64_PAD = 61

-- Decodes base64 in every form a subscription may use: standard or url safe, padded or not.
-- A string that is not base64 at all is not a link payload, the caller gets nil.
local function decode64(text)
	if not text then
		return nil
	end
	text = text:gsub("[%s]", ""):gsub("%-", "+"):gsub("_", "/"):gsub("=+$", "")
	if text == "" or #text % 4 == 1 or not text:match("^[A-Za-z0-9+/]+$") then
		return nil
	end
	text = text .. ("===="):sub(1, (4 - #text % 4) % 4)
	local result = {}
	for group in text:gmatch("....") do
		local c3, c4 = group:byte(3, 4)
		local i1 = BASE64:find(group:sub(1, 1), 1, true)
		local i2 = BASE64:find(group:sub(2, 2), 1, true)
		local i3 = c3 == BASE64_PAD and 0 or BASE64:find(group:sub(3, 3), 1, true)
		local i4 = c4 == BASE64_PAD and 0 or BASE64:find(group:sub(4, 4), 1, true)
		if not (i1 and i2 and i3 and i4) then
			return nil
		end
		i1, i2, i3, i4 = i1 - 1, i2 - 1, i3 - 1, i4 - 1
		result[#result + 1] = string.char(i1 * 4 + math.floor(i2 / 16))
		if c3 ~= BASE64_PAD then
			result[#result + 1] = string.char((i2 % 16) * 16 + math.floor(i3 / 4))
		end
		if c4 ~= BASE64_PAD then
			result[#result + 1] = string.char((i3 % 4) * 64 + i4)
		end
	end
	return table.concat(result)
end

-- scheme, userinfo, host, port, query and fragment of a uri. A host without a port and an
-- IPv6 host in brackets are accepted, the port of a hop link is a list of ports.
local function parse_uri(uri)
	local scheme, body = uri:match("^([%w%+%-%.]+)://(.*)$")
	if not scheme then
		return nil
	end
	local authority = body:match("^([^/%?#]*)") or ""
	local remainder = body:sub(#authority + 1)
	local userinfo, hostport = authority:match("^(.*)@([^@]+)$")
	if not hostport then
		userinfo, hostport = nil, authority
	end
	local host, port
	if hostport:match("^%[") then
		host, port = hostport:match("^%[([^%]]+)%]:?([%d,%-]*)$")
	else
		host, port = hostport:match("^([^:]*):([%d,%-]*)$")
	end
	return {
		scheme = scheme:lower(),
		userinfo = userinfo,
		host = host or hostport,
		port = port,
		path = remainder:match("^[^%?#]*"),
		query = remainder:match("%?([^#]*)"),
		fragment = remainder:match("#(.*)$")
	}
end

-- mihomo decodes the host of a vless uri when it is base64 encoded, the watchdog can only
-- use it when the result looks like an address
local function decoded_host(host)
	local decoded = decode64(host)
	if decoded and decoded:match("^[%w%.%-%_]+$") and decoded:find("%.") then
		return decoded
	end
	return host
end

local function without_brackets(host)
	if not host then
		return nil
	end
	return host:match("^%[(.-)%]$") or host
end

-- The server address of one share link, nil when the line is not a link the plugin knows
local function server_of(uri)
	local parsed = parse_uri(uri)
	if not parsed then
		return nil
	end
	local scheme = parsed.scheme
	local host = parsed.host

	if scheme == "vmess" then
		-- V2RayN: the whole link body is the base64 of a json document
		local decoded = decode64((uri:match("^%w+://([^#]+)") or ""))
		if decoded and decoded:sub(1, 1) == "{" then
			local ok, node = pcall(jsonc.parse, decoded)
			if ok and type(node) == "table" and type(node.add) == "string" and node.add ~= "" then
				return without_brackets(node.add)
			end
			return nil
		end
		-- Xray VMessAEAD: uuid@host:port
		return host
	end

	if scheme == "ss" then
		if parsed.port and parsed.port ~= "" then
			return host
		end
		-- the legacy link is the base64 of method:password@host:port
		local decoded = decode64(host)
		if decoded then
			return decoded:match("@%[([^%]]+)%]") or decoded:match("@([^:/]+)")
		end
		return nil
	end

	if scheme == "ssr" then
		local decoded = decode64((uri:match("^%w+://([^#]+)") or ""))
		if not decoded then
			return nil
		end
		return decoded:match("^([^:]+):")
	end

	if scheme == "hysteria2" or scheme == "hy2" or scheme == "hysteria2+realm" or scheme == "hy2+realm" then
		return without_brackets(host)
	end

	if scheme == "vless" then
		return decoded_host(host)
	end

	if scheme == "hysteria" or scheme == "tuic" or scheme == "trojan" or scheme == "mierus"
		or scheme == "anytls" or scheme == "socks" or scheme == "socks5" or scheme == "socks5h"
		or scheme == "http" or scheme == "https" then
		return without_brackets(host)
	end

	return nil
end

-- A provider file that is a broken yaml still names the address of its nodes
local function server_of_yaml(line)
	local value = line:match("^%s*server%s*:%s*([^%s#%]]+)")
	if not value then
		return nil
	end
	return value:gsub("^[\"']", ""):gsub("[\"']$", "")
end

local path = arg[1]
local file = path and io.open(path, "r")
if not file then
	os.exit(1)
end
local content = file:read("*a")
file:close()

local decoded = decode64(content:gsub("%s+", ""))
if decoded and decoded:find("://", 1, true) then
	content = decoded
end

for line in content:gmatch("[^\r\n]+") do
	local text = util.trim(line)
	local ok, server = pcall(server_of, text)
	if not ok or not server or server == "" then
		server = server_of_yaml(text)
	end
	if server and server ~= "" then
		print(server)
	end
end
