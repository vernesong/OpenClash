#!/usr/bin/lua

require "nixio"
require "luci.util"
require "luci.sys"
local uci = require("luci.model.uci").cursor()
local fs = require "luci.openclash"
local json = require "luci.jsonc"

local function oix_checkin()
	local token = fs.uci_get_config("config", "oix_token")
	if not token or fs.uci_get_config("config", "oix_checkin") ~= "1" then return end
	local path = "/tmp/oix_checkin"
	local interval = tonumber(fs.uci_get_config("config", "oix_checkin_interval")) or 1
	local cached = fs.readfile(path)
	if cached and cached ~= "" and os.time() - (fs.mtime(path) or 0) <= interval * 3600 + 1 then return end

	local multiple = tonumber(fs.uci_get_config("config", "oix_checkin_multiple")) or 1
	local reply = fs.oix_cli("checkin", {token = token, multiple = math.floor(multiple)})
	uci:load("openclash")
	if uci:get("openclash", "config", "oix_token") ~= token then return end

	local now = os.date("%Y-%m-%d %H:%M:%S")
	if reply and not reply.error and reply.checkin then
		fs.writefile(path, json.stringify({ret = 200, data = {checkin = reply.checkin}}))
		fs.unlink("/tmp/oix_info")
		fs.append_log(string.format("%s [Info] oixCloud Checkin Successful, Result:【%s】", now, tostring(reply.checkin)))
	elseif reply and reply.error then
		if reply.code == "auth" then fs.unlink("/tmp/oix_info") end
		fs.writefile(path, json.stringify({msg = reply.error}))
		fs.append_log(string.format("%s [Info] oixCloud Checkin Failed, Result:【%s】", now, tostring(reply.error)))
	else
		fs.writefile(path, " ")
		fs.append_log(now .. " [Info] oixCloud Checkin Failed! Please Check And Try Again...")
	end
end

oix_checkin()
