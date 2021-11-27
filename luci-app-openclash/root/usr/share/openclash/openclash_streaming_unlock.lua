#!/usr/bin/lua

require "nixio"
require "luci.util"
require "luci.sys"

local uci = require("luci.model.uci").cursor()
local fs = require "luci.openclash"
local json = require "luci.jsonc"
local UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/94.0.4606.61 Safari/537.36"
local filmId = 81215567
local type = arg[1]
local enable = tonumber(uci:get("openclash", "config", "stream_auto_select")) or 0
local now_name, group_name, group_type, group_show, status
local groups = {}
local proxies = {}

if enable == 0 then os.exit(0) end
if not type then os.exit(0) end

function unlock_auto_select()
	local key_group, region, now, proxy, group_match, proxy_default, auto_get_group, info
	local port = uci:get("openclash", "config", "cn_port")
	local passwd = uci:get("openclash", "config", "dashboard_password") or ""
	local ip = luci.sys.exec("uci -q get network.lan.ipaddr |awk -F '/' '{print $1}' 2>/dev/null |tr -d '\n'")
	local original = {}
	local key_groups = {}
	local tested_proxy = {}
	local gorup_i18 = "Group:"
	local full_support = "full support, area:"
	local only_original = "only support homemade!"
	local test_faild = "unlock test faild!"
	local test_start = "Start auto select unlock proxy..."
	local original_no_select = "only support homemade! the type of group is not select, auto select could not work!"
	local faild_no_select = "unlock test faild! the type of group is not select, auto select could not work!"
	local original_test_start = "only support homemade! start auto select unlock proxy..."
	local faild_test_start = "unlock test faild! start auto select unlock proxy..."
	
	if not ip or ip == "" then
		ip = luci.sys.exec("ip addr show 2>/dev/null | grep -w 'inet' | grep 'global' | grep 'brd' | grep -Eo 'inet [0-9\.]+' | awk '{print $2}' | head -n 1 | tr -d '\n'")
	end
	if not ip or not port then
		os.exit(0)
	end
	
	info = luci.sys.exec(string.format('curl -sL -m 3 --retry 2 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XGET http://%s:%s/proxies', passwd, ip, port))
	if info then
		info = json.parse(info)
		if not info then os.exit(0) end
	end
	
	if not info.proxies then
		os.exit(0)
	end
	
	--auto get group
	if type == "Netflix" then
		luci.sys.call('curl -sL --limit-rate 5k https://www.netflix.com >/dev/null 2>&1 &')
	elseif type == "Disney" then
		luci.sys.call('curl -sL --limit-rate 5k https://www.disneyplus.com >/dev/null 2>&1 &')
	end
	os.execute("sleep 1")
	local con = luci.sys.exec(string.format('curl -sL -m 3 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XGET http://%s:%s/connections', passwd, ip, port))
	if con then
		con = json.parse(con)
	end
	if con then
		for i = 1, #(con.connections) do
			if type == "Netflix" then
				if string.match(con.connections[i].metadata.host, "www%.netflix%.com") then
					auto_get_group = con.connections[i].chains[#(con.connections[i].chains)]
					break
				end
			elseif type == "Disney" then
				if string.match(con.connections[i].metadata.host, "www%.disneyplus%.com") then
					auto_get_group = con.connections[i].chains[#(con.connections[i].chains)]
					break
				end
			end
		end
	end

	if not auto_get_group then
		if type == "Netflix" then
			key_group = uci:get("openclash", "config", "stream_auto_select_group_key_netflix") or "netflix|奈飞"
		elseif type == "Disney" then
			key_group = uci:get("openclash", "config", "stream_auto_select_group_key_disney") or "disney|迪士尼"
		end
		string.gsub(key_group, '[^%|]+', function(w) table.insert(key_groups, w) end)
		if #key_groups == 0 then table.insert(key_groups, type) end
	else
		table.insert(key_groups, auto_get_group)
	end

	--save group name
	for _, value in pairs(info.proxies) do
		if value.all then
			table.insert(groups, value.name)
		end
	end

	for _, value in pairs(info.proxies) do
		--match only once
		group_match = false
		for g = 1, #key_groups do
			while true do
				--find group
				if not string.find(string.lower(value.name), string.lower(key_groups[g])) then
					break
				else
					--get groups info
					get_proxy(info, value.name, value.name)
					table.insert(tested_proxy, now_name)
					group_match = true
					--test now proxy
					region = proxy_unlock_test()
					now = os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..group_show.." ➟ "..now_name.."】"
					if status ~= 2 then
						region = proxy_unlock_test()
					end
					if status == 2 then
						print(now..full_support.."【"..region.."】")
						break
					elseif status == 1 then
						print(now..original_test_start)
					else
						print(now..faild_test_start)
					end
					
					--find new unlock
					if value.type == "Selector" then
						--loop proxy test
						for i = 1, #(value.all) do
							--save group current selected
							proxy_default = value.now
							while true do
								if value.all[i] == "REJECT" or value.all[i] == "DIRECT" then
									break
								else
									get_proxy(info, value.all[i], value.name)
									if group_type == "Selector" then
										if group_name == value.all[i] then
											luci.sys.exec(string.format("curl -sL -m 3 --retry 2 -w %%{http_code} -o /dev/null -H 'Authorization: Bearer %s' -H 'Content-Type:application/json' -X PUT -d '{\"name\":\"%s\"}' http://%s:%s/proxies/%s", passwd, group_name, ip, port, urlencode(value.name)))
										end
										for p = 1, #(proxies) do
											proxy = proxies[p]
											now = os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..group_show.." ➟ "..proxy.."】"
											--skip tested proxy
											while true do
												if table_include(tested_proxy, proxy) then
													break
												else
													table.insert(tested_proxy, proxy)
												end
												while true do
													if proxy == "REJECT" or proxy == "DIRECT" then
														break
													else
														luci.sys.exec(string.format("curl -sL -m 3 --retry 2 -w %%{http_code} -o /dev/null -H 'Authorization: Bearer %s' -H 'Content-Type:application/json' -X PUT -d '{\"name\":\"%s\"}' http://%s:%s/proxies/%s", passwd, proxy, ip, port, urlencode(group_name)))
														region = proxy_unlock_test()
														if status == 2 then
															print(now..full_support.."【"..region.."】")
														elseif status == 1 then
															table.insert(original, {group_name, proxy})
															print(now..only_original)
														else
															print(now..test_faild)
														end
													end
													break
												end
												if status == 2 then
													break
												elseif p == #(proxies) and #(proxies) ~= 1 then
													luci.sys.exec(string.format("curl -sL -m 3 --retry 2 -w %%{http_code} -o /dev/null -H 'Authorization: Bearer %s' -H 'Content-Type:application/json' -X PUT -d '{\"name\":\"%s\"}' http://%s:%s/proxies/%s", passwd, now_name, ip, port, urlencode(group_name)))
												end
												break
											end
											if status == 2 then break end
										end
									else
										--only group expand
										luci.sys.exec(string.format("curl -sL -m 3 --retry 2 -w %%{http_code} -o /dev/null -H 'Authorization: Bearer %s' -H 'Content-Type:application/json' -X PUT -d '{\"name\":\"%s\"}' http://%s:%s/proxies/%s", passwd, value.all[i], ip, port, urlencode(group_name)))
										while true do
											if table_include(tested_proxy, now_name) then
												break
											else
												table.insert(tested_proxy, now_name)
											end
												region = proxy_unlock_test()
												now = os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..group_show.." ➟ "..now_name.."】"
												if status == 2 then
													print(now..full_support.."【"..region.."】")
												elseif status == 1 then
													table.insert(original, {group_name, value.all[i]})
													print(now..original_no_select)
												else
													print(now..faild_no_select)
												end
											break
										end
									end
									if status == 2 then
										break
									elseif i == #(value.all) and #original > 0 then
										for k, v in pairs(original) do
											luci.sys.exec(string.format("curl -sL -m 3 --retry 2 -w %%{http_code} -o /dev/null -H 'Authorization: Bearer %s' -H 'Content-Type:application/json' -X PUT -d '{\"name\":\"%s\"}' http://%s:%s/proxies/%s", passwd, v[1], ip, port, urlencode(value.name)))
											luci.sys.exec(string.format("curl -sL -m 3 --retry 2 -w %%{http_code} -o /dev/null -H 'Authorization: Bearer %s' -H 'Content-Type:application/json' -X PUT -d '{\"name\":\"%s\"}' http://%s:%s/proxies/%s", passwd, v[2], ip, port, urlencode(v[1])))
											break
										end
									elseif i == #(value.all) then
										luci.sys.exec(string.format("curl -sL -m 3 --retry 2 -w %%{http_code} -o /dev/null -H 'Authorization: Bearer %s' -H 'Content-Type:application/json' -X PUT -d '{\"name\":\"%s\"}' http://%s:%s/proxies/%s", passwd, proxy_default, ip, port, urlencode(value.name)))
									end
								end
								break
							end
							if status == 2 then break end
						end
					else
						region = proxy_unlock_test()
						if status == 2 then
							print(now..full_support.."【"..region.."】")
							break
						elseif status == 1 then
							print(now..original_no_select)
						else
							print(now..faild_no_select)
						end
					end
				end
				break
			end
			if group_match then break end
		end
		if status == 2 then	break end
	end
end

function proxy_unlock_test()
	if type == "Netflix" then
		region = netflix_unlock_test()
	elseif type == "Disney" then
		region = disney_unlock_test()
	end
	return region
end

function table_include(table, value)
	if table == nil then
		return false
	end

	for k, v in pairs(table) do
		if v == value then
			return true
		end
	end
	return false
end

function get_proxy(info, group, name)
	--group maybe a proxy
	proxies = {}
	group_show = ""
	local expand_group = tonumber(uci:get("openclash", "config", "stream_auto_select_expand_group")) or 0

	if expand_group == 1 then
		if table_include(groups, group) then
			while table_include(groups, group) do
				for _, value in pairs(info.proxies) do
					if value.name == group then
						if group_show ~= "" then
							group_show = group_show .. " ➟ " .. group
						else
							if name == group then
								group_show = group
							else
								group_show = name .. " ➟ " .. group
							end
						end
						group_name = group
						group = value.now
						now_name = value.now
						proxies = value.all
						group_type = value.type
						break
					end
				end
			end
			if group_type ~= "Selector" then
				for _, value in pairs(info.proxies) do
					if value.name == name then
						group_name = name
						proxies = {}
						table.insert(proxies, group)
						break
					end
				end
			end
		else
			for _, value in pairs(info.proxies) do
				if value.name == name then
					group_show = name
					group_name = name
					now_name = value.now
					table.insert(proxies, group)
					group_type = value.type
					break
				end
			end
		end
	else
		if table_include(groups, group) then
			for _, value in pairs(info.proxies) do
				if value.name == name then
					group_name = name
					now_name = value.now
					table.insert(proxies, group)
					group_type = value.type
				end
			end
			while table_include(groups, group) do
				for _, value in pairs(info.proxies) do
					if value.name == group then
						if group_show ~= "" then
							group_show = group_show .. " ➟ " .. group
						else
							if name == group then
								group_show = group
							else
								group_show = name .. " ➟ " .. group
							end
						end
						group = value.now
						break
					end
				end
			end
		else
			for _, value in pairs(info.proxies) do
				if value.name == name then
					table.insert(proxies, group)
					now_name = value.now
					group_show = name
					group_name = name
					group_type = value.type
					break
				end
			end
		end
	end
end

function urlencode(data)
	local data = luci.sys.exec(string.format('curl -s -o /dev/null -w %%{url_effective} --get --data-urlencode "%s" ""', data))
	return luci.sys.exec(string.format("echo %s |sed 's/+/%%20/g'", string.match(data, "/%?(.+)")))
end

function netflix_unlock_test()
	status = 0
	local url = "https://www.netflix.com/title/"..filmId
	local headers = "User-Agent: "..UA
	local info = luci.sys.exec(string.format('curl -sLI -m 10 --retry 2 -o /dev/null -w %%{json} -H "Content-Type: application/json" -H "%s" -XGET %s', headers, url))
	local result = {}
	local region
	if info then
		info = json.parse(info)
	end
	if info then
		if info.http_code == 200 then
			status = 2
			string.gsub(info.url_effective, '[^/]+', function(w) table.insert(result, w) end)
			region = string.upper(string.match(result[3], "^%a+"))
		elseif info.http_code == 404 then
			status = 1
		else
			status = 0
		end
	end
	return region or "Unknow"
end

function disney_unlock_test()
	status = 0
	local url = "https://global.edge.bamgrid.com/token"
	local url2 = "https://www.disneyplus.com"
	local headers = '-H "Accept-Language: en" -H "authorization: Bearer ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" -H "Content-Type: application/x-www-form-urlencoded"'
	local auth = '"grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Atoken-exchange&latitude=0&longitude=0&platform=browser&subject_token=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzUxMiJ9.eyJzdWIiOiJiNDAzMjU0NS0yYmE2LTRiZGMtOGFlOS04ZWI3YTY2NzBjMTIiLCJhdWQiOiJ1cm46YmFtdGVjaDpzZXJ2aWNlOnRva2VuIiwibmJmIjoxNjIyNjM3OTE2LCJpc3MiOiJ1cm46YmFtdGVjaDpzZXJ2aWNlOmRldmljZSIsImV4cCI6MjQ4NjYzNzkxNiwiaWF0IjoxNjIyNjM3OTE2LCJqdGkiOiI0ZDUzMTIxMS0zMDJmLTQyNDctOWQ0ZC1lNDQ3MTFmMzNlZjkifQ.g-QUcXNzMJ8DwC9JqZbbkYUSKkB1p4JGW77OON5IwNUcTGTNRLyVIiR8mO6HFyShovsR38HRQGVa51b15iAmXg&subject_token_type=urn%3Abamtech%3Aparams%3Aoauth%3Atoken-type%3Adevice"'
	local httpcpde = luci.sys.exec(string.format("curl -sL -m 10 --retry 2 -o /dev/null -w %%{http_code} %s -H 'User-Agent: %s' -d %s -XPOST %s", headers, UA, auth, url))
	local region
	if tonumber(httpcpde) == 200 then
		local url_effective = luci.sys.exec(string.format("curl -sL -m 10 --retry 2 -o /dev/null -w %%{url_effective} -H 'User-Agent: %s' %s", UA, url2))
		if url_effective == "https://disneyplus.disney.co.jp/" then
			region = "JP"
			return region
		elseif string.find(url_effective,"hotstar") then
			return "Unknow"
		end
		local region = luci.sys.exec(string.format("curl -sL -m 10 --retry 2 -H 'User-Agent: %s' %s |grep 'Region: ' |awk '{print $2}' |tr -d '\n'", UA, url2))
		if region and region ~= "" then
			status = 2
			return region
		else
			return "Unknow"
		end
	else
		return "Unknow"
	end
end

unlock_auto_select()