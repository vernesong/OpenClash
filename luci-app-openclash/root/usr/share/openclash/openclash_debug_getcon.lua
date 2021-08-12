#!/usr/bin/lua

require "nixio"
require "luci.util"
require "luci.sys"
local uci = require("luci.model.uci").cursor()
local fs = require "luci.openclash"
local json = require "luci.jsonc"

local function debug_getcon()
	local info, ip, host
	ip = luci.sys.exec("uci -q get network.lan.ipaddr |awk -F '/' '{print $1}' 2>/dev/null |tr -d '\n'")
	if not ip or ip == "" then
		ip = luci.sys.exec("ip addr show 2>/dev/null | grep -w 'inet' | grep 'global' | grep 'brd' | grep -Eo 'inet [0-9\.]+' | awk '{print $2}' | head -n 1 | tr -d '\n'")
	end
	local port = uci:get("openclash", "config", "cn_port")
	local passwd = uci:get("openclash", "config", "dashboard_password") or ""
	if ip and port then
		info = luci.sys.exec(string.format('curl -sL -m 3 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XGET http://"%s":"%s"/connections', passwd, ip, port))
		if info then
			info = json.parse(info)
		end
		if info then
			for i = 1, #(info.connections) do
				if info.connections[i].metadata.host == "" then
					host = "Not exist"
				else
					host = info.connections[i].metadata.host
				end
				luci.sys.exec(string.format('echo "%s: SourceIP:【%s】 - Host:【%s】 - DestinationIP:【%s】 - Network:【%s】 - RulePayload:【%s】 - Lastchain:【%s】" >> /tmp/openclash_debug.log', i, (info.connections[i].metadata.sourceIP), host, (info.connections[i].metadata.destinationIP), (info.connections[i].metadata.network), (info.connections[i].rulePayload),(info.connections[i].chains[1])))
			end
		end
	end
	os.exit(0)
end

debug_getcon()