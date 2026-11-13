#!/usr/bin/lua

require "nixio"
require "luci.util"
require "luci.sys"
local uci = require("luci.model.uci").cursor()
local fs = require "luci.openclash"
local json = require "luci.jsonc"
local datatype = require "luci.cbi.datatypes"
local addr = arg[1]

if addr and not (datatype.hostname(addr) or datatype.ipaddr(addr)) then
	os.exit(0)
end

local function fetch_connections(ip, port, passwd)
	local raw = luci.sys.exec(string.format('curl -sL -m 3 -H "Content-Type: application/json" -H %s -XGET %s',
		luci.util.shellquote("Authorization: Bearer " .. passwd), luci.util.shellquote("http://" .. ip .. ":" .. port .. "/connections")))
	if not raw or raw == "" then
		return nil
	end
	return json.parse(raw)
end

local function print_connection(c)
	print("id: "..(c.id))
	print("start: "..(c.start))
	print("download: "..fs.filesize(c.download))
	print("upload: "..fs.filesize(c.upload))
	print("rule: "..(c.rule))
	print("rulePayload: "..(c.rulePayload))
	print("chains: ")
	for o = 1, #(c.chains) do
		print("  "..o..": "..(c.chains[o]))
	end
	print("metadata: ")
	print("  sourceIP: "..(c.metadata.sourceIP))
	print("  sourcePort: "..(c.metadata.sourcePort))
	print("  host: "..(c.metadata.host == "" and "Empty" or c.metadata.host))
	print("  destinationIP: "..(c.metadata.destinationIP))
	print("  destinationPort: "..(c.metadata.destinationPort))
	print("  network: "..(c.metadata.network))
	print("  type: "..(c.metadata.type))
	print("")
end

local function scan_connections(ip, port, passwd)
	local info = fetch_connections(ip, port, passwd)
	if not info then
		return false
	end
	local found = false
	for i = 1, #(info.connections) do
		local c = info.connections[i]
		local host = (c.metadata.host == "" and "Empty" or c.metadata.host)
		if (datatype.hostname(addr) and string.lower(addr) == host) or (datatype.ipaddr(addr) and addr == c.metadata.destinationIP) then
			found = true
			print_connection(c)
		end
	end
	return found
end

local function dump_connections(info)
	local conn_lines = {}
	for i = 1, #(info.connections) do
		local c = info.connections[i]
		local host = (c.metadata.host == "" and "Empty" or c.metadata.host)
		conn_lines[#conn_lines + 1] = string.format("%d. SourceIP:【%s】 - Host:【%s】 - DestinationIP:【%s】 - Network:【%s】 - RulePayload:【%s】 - Lastchain:【%s】\n",
			i,
			tostring(c.metadata.sourceIP),
			tostring(host),
			tostring(c.metadata.destinationIP),
			tostring(c.metadata.network),
			tostring(c.rulePayload),
			tostring(c.chains and c.chains[1]))
	end
	if #conn_lines > 0 then
		local existing = fs.readfile("/tmp/openclash_debug.log") or ""
		fs.writefile("/tmp/openclash_debug.log", existing .. table.concat(conn_lines))
	end
end

local function debug_getcon()
	local ip = fs.lanip(true)
	local port = fs.uci_get_config("config", "cn_port")
	local passwd = fs.uci_get_config("config", "dashboard_password") or ""
	if not ip or not port then
		os.exit(0)
	end

	if not addr then
		local info = fetch_connections(ip, port, passwd)
		if info then
			dump_connections(info)
		end
		os.exit(0)
	end

	local found = scan_connections(ip, port, passwd)
	if not found then
		luci.sys.call(string.format('( (sleep 5) | nc %s 443 ) >/dev/null 2>&1 &', addr))
		luci.sys.call(string.format('( (sleep 5) | openssl s_client -connect %s:443 -servername %s -quiet -no_ign_eof ) >/dev/null 2>&1 &', addr, addr))
		local deadline = os.time() + 5
		local polls = 0
		while os.time() < deadline and not found and polls < 5 do
			polls = polls + 1
			found = scan_connections(ip, port, passwd)
			if not found and polls < 5 then
				luci.sys.call("sleep 1")
			end
		end
	end
	os.exit(0)
end

debug_getcon()