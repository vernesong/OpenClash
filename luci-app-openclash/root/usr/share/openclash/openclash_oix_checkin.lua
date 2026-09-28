#!/usr/bin/lua

require "nixio"
require "luci.util"
require "luci.sys"
local uci = require("luci.model.uci").cursor()
local fs = require "luci.openclash"
local json = require "luci.jsonc"

local function oix_checkin()
	local info, path, checkin
	local token = fs.uci_get_config("config", "oix_token")
	local enable = fs.uci_get_config("config", "oix_checkin") or 0
	local interval = fs.uci_get_config("config", "oix_checkin_interval") or 1
	local multiple = fs.uci_get_config("config", "oix_checkin_multiple") or 1
	path = "/tmp/oix_checkin"
	if token and enable == "1" then
		checkin = string.format("curl -sL -H 'Content-Type: application/json' -H 'User-Agent: OpenClash for oixCloud' -H 'X-oixCloud-Client: openclash' -H 'Authorization: Bearer %s' -d '{\"multiple\":\"%s\"}' -X POST https://oix-api.dler.io/api/v1/checkin -o %s", token, multiple, path)
		if fs.readfile(path) == "" or not fs.readfile(path) then
			luci.sys.exec(checkin)
		else
			if (os.time() - fs.mtime(path) > interval*3600+1) then
				fs.unlink(path)
				luci.sys.exec(checkin)
			else
				os.exit(0)
			end
		end
		if fs.readfile(path) == "" or not fs.readfile(path) then
			fs.writefile(path, " ")
		end
		info = fs.readfile(path)
		if info then
			info = json.parse(info)
		end
		if info and info.ret == 200 then
			luci.sys.exec(string.format('echo "%s [Info] oixCloud Checkin Successful, Result:【%s】" >> /tmp/openclash.log', os.date("%Y-%m-%d %H:%M:%S"), info.data.checkin))
		else
			if info and info.msg then
				luci.sys.exec(string.format('echo "%s [Info] oixCloud Checkin Failed, Result:【%s】" >> /tmp/openclash.log', os.date("%Y-%m-%d %H:%M:%S"), info.msg))
			else
				luci.sys.exec(string.format('echo "%s [Info] oixCloud Checkin Failed! Please Check And Try Again..." >> /tmp/openclash.log', os.date("%Y-%m-%d %H:%M:%S")))
			end
		end
	end
	os.exit(0)
end

oix_checkin()