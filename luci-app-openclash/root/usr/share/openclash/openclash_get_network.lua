#!/usr/bin/lua

require "nixio"
require "luci.sys"
local util = require "luci.util"
local ntm = require "luci.model.network".init()
local cidr = require "luci.ip"
local fs = require "luci.openclash"
local type = arg[1]
local rv = {}
local wan, wan6

if not type then os.exit(0) end

local function get_all_wan_networks()
	local nets = { }
	local _, object
	for _, object in ipairs(util.ubus()) do
		local name = object:match("^network%.interface%.(.+)")
		if name then
			local stat = util.ubus(object, "status", { })
			if stat and stat.route then
				local rt
				for _, rt in ipairs(stat.route) do
					if not rt.table and rt.target == "0.0.0.0" and rt.mask == 0 then
						local net = ntm:get_network(name)
						if net then
							nets[#nets+1] = net
						end
						break
					end
				end
			end
		end
	end
	return nets
end

local function get_all_wan6_networks()
	local nets = { }
	local _, object
	for _, object in ipairs(util.ubus()) do
		local name = object:match("^network%.interface%.(.+)")
		if name then
			local stat = util.ubus(object, "status", { })
			if stat and stat.route then
				local rt
				for _, rt in ipairs(stat.route) do
					if not rt.table and rt.target == "::" and rt.mask == 0 then
						local net = ntm:get_network(name)
						if net then
							nets[#nets+1] = net
						end
						break
					end
				end
			end
		end
	end
	return nets
end

local ok = pcall(function() wan = get_all_wan_networks(); wan6 = get_all_wan6_networks(); end)
if not ok then
	ok = pcall(function() wan = ntm:get_wan_networks(); wan6 = ntm:get_wan6_networks(); end)
end
if not ok then
	ok = pcall(function() wan = { ntm:get_wannet() }; wan6 = { ntm:get_wan6net() }; end)
end
if not ok then
	os.exit(0)
end

if wan then
	rv.wan = {}
	for i = 1, #wan do
		rv.wan[i] = {
			ipaddr  = wan[i]:ipaddr(),
			ip6addr  = wan[i]:ip6addr(),
			gwaddr  = wan[i]:gwaddr(),
			netmask = wan[i]:netmask(),
			dns     = wan[i]:dnsaddrs(),
			expires = wan[i]:expires(),
			uptime  = wan[i]:uptime(),
			proto   = wan[i]:proto(),
			ifname  = wan[i]:ifname()
		}
	end
end

if wan6 then
	rv.wan6 = {}
	for i = 1, #wan6 do
		rv.wan6[i] = {
			ip6addr   = wan6[i]:ip6addr(),
			gw6addr   = wan6[i]:gw6addr(),
			dns       = wan6[i]:dns6addrs(),
			ip6prefix = wan6[i]:ip6prefix(),
			uptime    = wan6[i]:uptime(),
			proto     = wan6[i]:proto(),
			ifname    = wan6[i]:ifname()
		}
	end
end

if type == "dns" then
	if wan then
		for o = 1, #(rv.wan) do
			for i = 1, #(rv.wan[o].dns) do
				if rv.wan[o].dns[i] ~= rv.wan[o].gwaddr and rv.wan[o].dns[i] ~= rv.wan[o].ipaddr then
					print(rv.wan[o].dns[i])
				end
			end
		end
	end
end

if type == "dns6" then
	if wan6 then
		for o = 1, #(rv.wan6) do
			for i = 1, #(rv.wan6[o].dns) do
				if rv.wan6[o].dns[i] ~= rv.wan6[o].gw6addr and rv.wan6[o].ip6addr then
					print(rv.wan6[o].dns[i])
				end
			end
		end
	end
end

if type == "gateway" then
	if wan then
		for o = 1, #(rv.wan) do
			print(rv.wan[o].gwaddr)
		end
	end
end

if type == "gateway6" then
	if wan6 then
		for o = 1, #(rv.wan6) do
			print(rv.wan6[o].gw6addr)
		end
	end
end

if type == "dhcp" then
	if wan then
		for o = 1, #(rv.wan) do
			if rv.wan[o].proto == "dhcp" then
				print(rv.wan[o].ifname)
			end
		end
	end
	if wan6 then
		for o = 1, #(rv.wan6) do
			if rv.wan6[o].proto == "dhcpv6" then
				print(rv.wan6[o].ifname)
			end
		end
	end
end

if type == "pppoe" then
	if wan then
		for o = 1, #(rv.wan) do
			if rv.wan[o].proto == "pppoe" then
				print(rv.wan[o].ifname)
			end
		end
	end
	if wan6 then
		for o = 1, #(rv.wan6) do
			if rv.wan6[o].proto == "pppoe" then
				print(rv.wan6[o].ifname)
			end
		end
	end
end

if type == "wanip" then
	if wan then
		for o = 1, #(rv.wan) do
			if rv.wan[o].proto == "pppoe" then
				print(rv.wan[o].ipaddr)
			end
		end
	end
end

if type == "wanip6" then
	if wan6 then
		for o = 1, #(rv.wan6) do
			if rv.wan6[o].proto == "pppoe" or rv.wan6[o].proto == "dhcpv6" then
				print(rv.wan6[o].ip6addr)
			end
		end
	end
end

if type == "lan_cidr" then
	if wan then
		for o = 1, #(rv.wan) do
			if rv.wan[o].proto ~= "pppoe" then
				if rv.wan[o].ipaddr and rv.wan[o].netmask then
					local network = cidr.IPv4(rv.wan[o].ipaddr, rv.wan[o].netmask):network():string()
					local prefix = cidr.IPv4(rv.wan[o].ipaddr, rv.wan[o].netmask):prefix()
					print(network.."/"..prefix)
				end
			end
		end
	end
end

if type == "lan_cidr6" then
	if wan then
		for o = 1, #(rv.wan) do
			if rv.wan[o].proto ~= "pppoe" then
				if rv.wan[o].ip6addr then
					local ip6, prefix = rv.wan[o].ip6addr:match("([^/]+)/(%d+)")
					local network = cidr.IPv6(ip6, tonumber(prefix)):network():string()
					local prefix = cidr.IPv6(ip6, tonumber(prefix)):prefix()
					print(network.."/"..prefix)
				end
			end
		end
	end
end

os.exit(0)