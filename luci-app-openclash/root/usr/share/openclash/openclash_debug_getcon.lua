#!/usr/bin/lua

require "nixio"
require "luci.util"
require "luci.sys"
local uci = require("luci.model.uci").cursor()
local fs = require "luci.openclash"
local json = require "luci.jsonc"
local datatype = require "luci.cbi.datatypes"
local addr = arg[1]

local function debug_getcon()
	local info, ip, host, diag_info
	ip = fs.lanip()
	local port = fs.uci_get_config("config", "cn_port")
	local passwd = fs.uci_get_config("config", "dashboard_password") or ""
	if ip and port then
		info = luci.sys.exec(string.format('curl -sL -m 3 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XGET http://"%s":"%s"/connections', passwd, ip, port))
		if info then
			info = json.parse(info)
		end
		if info then
			local conn_lines = {}
			for i = 1, #(info.connections) do
				if info.connections[i].metadata.host == "" then
					host = "Empty"
				else
					host = info.connections[i].metadata.host
				end
				if not addr then
					conn_lines[#conn_lines + 1] = string.format("%d. SourceIP:【%s】 - Host:【%s】 - DestinationIP:【%s】 - Network:【%s】 - RulePayload:【%s】 - Lastchain:【%s】\n",
						i,
						tostring(info.connections[i].metadata.sourceIP),
						tostring(host),
						tostring(info.connections[i].metadata.destinationIP),
						tostring(info.connections[i].metadata.network),
						tostring(info.connections[i].rulePayload),
						tostring(info.connections[i].chains and info.connections[i].chains[1]))
				else
					if datatype.hostname(addr) and string.lower(addr) == host  or datatype.ipaddr(addr) and addr == (info.connections[i].metadata.destinationIP) then
						print("id: "..(info.connections[i].id))
						print("start: "..(info.connections[i].start))
						print("download: "..fs.filesize(info.connections[i].download))
						print("upload: "..fs.filesize(info.connections[i].upload))
						print("rule: "..(info.connections[i].rule))
						print("rulePayload: "..(info.connections[i].rulePayload))
						print("chains: ")
						for o = 1, #(info.connections[i].chains) do
							print("  "..o..": "..(info.connections[i].chains[o]))
						end
						print("metadata: ")
						print("  sourceIP: "..(info.connections[i].metadata.sourceIP))
						print("  sourcePort: "..(info.connections[i].metadata.sourcePort))
						print("  host: "..host)
						print("  destinationIP: "..(info.connections[i].metadata.destinationIP))
						print("  destinationPort: "..(info.connections[i].metadata.destinationPort))
						print("  network: "..(info.connections[i].metadata.network))
						print("  type: "..(info.connections[i].metadata.type))
						print("")
					end
				end
			end
			if not addr and #conn_lines > 0 then
				local existing = fs.readfile("/tmp/openclash_debug.log") or ""
				fs.writefile("/tmp/openclash_debug.log", existing .. table.concat(conn_lines))
			end
		end
	end
	os.exit(0)
end

debug_getcon()