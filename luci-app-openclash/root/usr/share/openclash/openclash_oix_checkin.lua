#!/usr/bin/lua

require "nixio"
require "luci.util"
require "luci.sys"
local uci = require("luci.model.uci").cursor()
local fs = require "luci.openclash"
local json = require "luci.jsonc"

local function oix_checkin()
	local info, path
	local token = fs.uci_get_config("config", "oix_token")
	local enable = fs.uci_get_config("config", "oix_checkin") or 0
	local interval = fs.uci_get_config("config", "oix_checkin_interval") or 1
	local multiple = fs.uci_get_config("config", "oix_checkin_multiple") or 1
	path = "/tmp/oix_checkin"
	if token and enable == "1" then
		local function checkin()
			local reply = fs.oix_cli("checkin", {token = token, multiple = math.floor(tonumber(multiple) or 1)})
			if reply then
				fs.writefile(path, json.stringify(reply.error and {msg = reply.error} or {ret = 200, data = {checkin = reply.checkin}}))
			end
		end
		if fs.readfile(path) == "" or not fs.readfile(path) then
			checkin()
		else
			if (os.time() - fs.mtime(path) > interval*3600+1) then
				fs.unlink(path)
				checkin()
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
			fs.append_log(string.format("%s [Info] oixCloud Checkin Successful, Result:【%s】", os.date("%Y-%m-%d %H:%M:%S"), tostring(info.data.checkin)))
		else
			if info and info.msg then
				fs.append_log(string.format("%s [Info] oixCloud Checkin Failed, Result:【%s】", os.date("%Y-%m-%d %H:%M:%S"), tostring(info.msg)))
			else
				fs.append_log(os.date("%Y-%m-%d %H:%M:%S") .. " [Info] oixCloud Checkin Failed! Please Check And Try Again...")
			end
		end
	end
	os.exit(0)
end

oix_checkin()
