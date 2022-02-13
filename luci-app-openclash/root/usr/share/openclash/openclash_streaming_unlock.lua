#!/usr/bin/lua

require "nixio"
require "luci.util"
require "luci.sys"

local uci = require("luci.model.uci").cursor()
local fs = require "luci.openclash"
local json = require "luci.jsonc"
local UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/94.0.4606.61 Safari/537.36"
local filmId = 70143836
local type = arg[1]
local enable = tonumber(uci:get("openclash", "config", "stream_auto_select")) or 0
local now_name, group_name, group_type, group_show, status, ip, port, passwd, group_match_name
local groups = {}
local proxies = {}

if enable == 0 or not type then os.exit(0) end

function unlock_auto_select()
	local key_group, region, now, proxy, group_match, proxy_default, auto_get_group, info, group_now
	local original = {}
	local other_region_unlock = {}
	local tested_proxy = {}
	local fallback_select = {}
	local gorup_i18 = "Group:"
	local no_group_find = "failed to search based on keywords and automatically obtain the group, please confirm the validity of the regex!"
	local full_support_no_area = "full support."
	local full_support = "full support, area:"
	local only_original = "only support homemade!"
	local no_unlock = "not support unlock!"
	local select_success = "unlock node auto selected successfully, the current selected is"
	local select_faild = "unlock node auto selected failed, no node available, rolled back to the"
	local test_faild = "unlock test faild!"
	local test_start = "Start auto select unlock proxy..."
	local original_no_select = "only support homemade! the type of group is not select, auto select could not work!"
	local no_unlock_no_select = "not support unlock! the type of group is not select, auto select could not work!"
	local faild_no_select = "unlock test faild! the type of group is not select, auto select could not work!"
	local original_test_start = "only support homemade! start auto select unlock proxy..."
	local no_unlock_test_start = "not support unlock! start auto select unlock proxy..."
	local faild_test_start = "unlock test faild! start auto select unlock proxy..."
	local area_i18 = ", area:"
	local select_faild_other_region = "unlock node auto selected failed, no node match the regex, rolled back to other full support node"
	local other_region_unlock_test = "full support but not match the regex!"
	local other_region_unlock_no_select = "but not match the regex! the type of group is not select, auto select could not work!"
	local other_region_unlock_test_start = "full support but not match the regex! start auto select unlock proxy..."
	
	--Get ip port and password
	get_auth_info()
	
	info = luci.sys.exec(string.format('curl -sL -m 3 --retry 2 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XGET http://%s:%s/proxies', passwd, ip, port))
	if info then
		info = json.parse(info)
		if not info or not info.proxies then os.exit(0) end
	end
	
	--try to get group instead of matching the key
	auto_get_group = auto_get_policy_group(passwd, ip, port)
	
	if not auto_get_group then
		auto_get_group = auto_get_policy_group(passwd, ip, port)
	end

	if not auto_get_group then
		if type == "Netflix" then
			key_group = uci:get("openclash", "config", "stream_auto_select_group_key_netflix") or "netflix|奈飞"
		elseif type == "Disney Plus" then
			key_group = uci:get("openclash", "config", "stream_auto_select_group_key_disney") or "disney|迪士尼"
		elseif type == "HBO Now" then
			key_group = uci:get("openclash", "config", "stream_auto_select_group_key_hbo_now") or "hbo|hbonow|hbo now"
		elseif type == "HBO Max" then
			key_group = uci:get("openclash", "config", "stream_auto_select_group_key_hbo_max") or "hbo|hbomax|hbo max"
		elseif type == "HBO GO Asia" then
			key_group = uci:get("openclash", "config", "stream_auto_select_group_key_hbo_go_asia") or "hbo|hbogo|hbo go"
		elseif type == "YouTube Premium" then
			key_group = uci:get("openclash", "config", "stream_auto_select_group_key_ytb") or "youtobe|油管"
		elseif type == "TVB Anywhere+" then
			key_group = uci:get("openclash", "config", "stream_auto_select_group_key_tvb_anywhere") or "tvb"
		elseif type == "Amazon Prime Video" then
			key_group = uci:get("openclash", "config", "stream_auto_select_group_key_prime_video") or "prime video|amazon"
		end
		if not key_group then key_group = type end
	else
		key_group = "^" .. auto_get_group .. "$"
	end

	--save group name
	for _, value in pairs(info.proxies) do
		if value.all then
			table.insert(groups, value.name)
		end
	end

	group_match = false
	for _, value in pairs(info.proxies) do
		--match only once
		while true do
			--find group
			if not datamatch(value.name, key_group) then
				break
			else
				--get groups info
				group_match_name = value.name
				get_proxy(info, value.name, value.name)
				table.insert(tested_proxy, now_name)
				group_match = true
				--test now proxy
				region = proxy_unlock_test()
				if table_include(groups, now_name) then
					now = os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..group_show.."】"
				else
					now = os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..group_show.." ➟ "..now_name.."】"
				end
				if status ~= 2 then
					os.execute("sleep 3")
					region = proxy_unlock_test()
				end
				if status == 2 then
					if region and region ~= "" then
						print(now..full_support.."【"..region.."】")
					else
						print(now..full_support_no_area)
					end
					break
				elseif status == 3 then
					table.insert(other_region_unlock, {get_group_now(info, value.name), group_name, now_name})
					print(now..other_region_unlock_test_start)
				elseif status == 1 then
					table.insert(original, {get_group_now(info, value.name), group_name, now_name})
					if type == "Netflix" then
						print(now..original_test_start)
					else
						print(now..no_unlock_test_start)
					end
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
										if table_include(groups, proxy) then
											group_now = get_group_now(info, proxy)
											now = os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..group_show.." ➟ "..group_now.."】"
										else
											now = os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..group_show.." ➟ "..proxy.."】"
										end
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
														if region and region ~= "" then
															print(now..full_support.."【"..region.."】")
															print(os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..value.name.."】"..select_success.."【"..proxy.."】"..area_i18.."【"..region.."】")
														else
															print(now..full_support_no_area)
															print(os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..value.name.."】"..select_success.."【"..proxy.."】")
														end
													elseif status == 3 then
														table.insert(other_region_unlock, {value.all[i], group_name, proxy})
														print(now..other_region_unlock_test)
													elseif status == 1 then
														table.insert(original, {value.all[i], group_name, proxy})
														if type == "Netflix" then
															print(now..only_original)
														else
															print(now..no_unlock)
														end
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
										if table_include(groups, now_name) then
											now = os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..group_show.."】"
										else
											now = os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..group_show.." ➟ "..now_name.."】"
										end
										if status == 2 then
											if region and region ~= "" then
												print(now..full_support.."【"..region.."】")
												print(os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..value.name.."】"..select_success.."【"..get_group_now(info, now_name).."】"..area_i18.."【"..region.."】")
											else
												print(now..full_support_no_area)
												print(os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..value.name.."】"..select_success.."【"..get_group_now(info, now_name).."】")
											end
										elseif status == 3 then
											table.insert(other_region_unlock, {value.all[i], group_name, value.all[i]})
											print(now..full_support.."【"..region.."】"..other_region_unlock_no_select)
										elseif status == 1 then
											table.insert(original, {value.all[i], group_name, value.all[i]})
											if type == "Netflix" then
												print(now..original_no_select)
											else
												print(now..no_unlock_no_select)
											end
										else
											print(now..faild_no_select)
										end
										break
									end
								end
							end
							break
						end
						if status == 2 then
							close_connections()
							break
						elseif i == #(value.all) and (#original > 0 or #other_region_unlock > 0) then
							if #other_region_unlock > 0 then
								fallback_select = other_region_unlock
							else
								fallback_select = original
							end
							for k, v in pairs(fallback_select) do
								luci.sys.exec(string.format("curl -sL -m 3 --retry 2 -w %%{http_code} -o /dev/null -H 'Authorization: Bearer %s' -H 'Content-Type:application/json' -X PUT -d '{\"name\":\"%s\"}' http://%s:%s/proxies/%s", passwd, v[1], ip, port, urlencode(value.name)))
								luci.sys.exec(string.format("curl -sL -m 3 --retry 2 -w %%{http_code} -o /dev/null -H 'Authorization: Bearer %s' -H 'Content-Type:application/json' -X PUT -d '{\"name\":\"%s\"}' http://%s:%s/proxies/%s", passwd, v[3], ip, port, urlencode(v[2])))
								if #other_region_unlock > 0 then
									close_connections()
									print(os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..value.name.."】"..select_faild_other_region.."【"..v[3].."】")
								else
									print(os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..value.name.."】"..select_faild.."【"..v[3].."】")
								end
								break
							end
						elseif i == #(value.all) then
							luci.sys.exec(string.format("curl -sL -m 3 --retry 2 -w %%{http_code} -o /dev/null -H 'Authorization: Bearer %s' -H 'Content-Type:application/json' -X PUT -d '{\"name\":\"%s\"}' http://%s:%s/proxies/%s", passwd, proxy_default, ip, port, urlencode(value.name)))
							print(os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..value.name.."】"..select_faild.."【"..proxy_default.."】")
						end
					end
				else
					region = proxy_unlock_test()
					if status == 2 then
						if region and region ~= "" then
							print(now..full_support.."【"..region.."】")
							print(os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..value.name.."】"..select_success.."【"..get_group_now(info, value.name).."】"..area_i18.."【"..region.."】")
						else
							print(now..full_support_no_area)
							print(os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..value.name.."】"..select_success.."【"..get_group_now(info, value.name).."】")
						end
						break
					elseif status == 3 then
						print(now..full_support.."【"..region.."】"..other_region_unlock_no_select)
					elseif status == 1 then
						if type == "Netflix" then
							print(now..original_no_select)
						else
							print(now..no_unlock_no_select)
						end
					else
						print(now..faild_no_select)
					end
				end
			end
			break
		end
		if auto_get_group and group_match then break end
		if status == 2 then	break end
	end
	if not group_match and not auto_get_group then
		print(os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..key_group.."】"..no_group_find)
	end
end

function get_auth_info()
	port = uci:get("openclash", "config", "cn_port")
	passwd = uci:get("openclash", "config", "dashboard_password") or ""
	ip = luci.sys.exec("uci -q get network.lan.ipaddr |awk -F '/' '{print $1}' 2>/dev/null |tr -d '\n'")
	
	if not ip or ip == "" then
		ip = luci.sys.exec("ip addr show 2>/dev/null | grep -w 'inet' | grep 'global' | grep 'brd' | grep -Eo 'inet [0-9\.]+' | awk '{print $2}' | head -n 1 | tr -d '\n'")
	end
	if not ip or not port then
		os.exit(0)
	end
end

function close_connections()
	local con
	local group_cons_id = {}
	con = luci.sys.exec(string.format('curl -sL -m 5 --retry 2 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XGET http://%s:%s/connections', passwd, ip, port))
	if con then
		con = json.parse(con)
	end
	if con then
		for i = 1, #(con.connections) do
			if con.connections[i].chains[#(con.connections[i].chains)] == group_match_name then
				table.insert(group_cons_id, (con.connections[i].id))
			end
		end
		--close connections
		if #(group_cons_id) > 0 then
			for i = 1, #(group_cons_id) do
				luci.sys.exec(string.format('curl -sL -m 5 --retry 2 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -X DELETE http://%s:%s/connections/%s >/dev/null 2>&1', passwd, ip, port, group_cons_id[i]))
			end
		end
	end
end

function proxy_unlock_test()
	if type == "Netflix" then
		region = netflix_unlock_test()
	elseif type == "Disney Plus" then
		region = disney_unlock_test()
	elseif type == "HBO Now" then
		region = hbo_now_unlock_test()
	elseif type == "HBO Max" then
		region = hbo_max_unlock_test()
	elseif type == "HBO GO Asia" then
		region = hbo_go_asia_unlock_test()
	elseif type == "YouTube Premium" then
		region = ytb_unlock_test()
	elseif type == "TVB Anywhere+" then
		region = tvb_anywhere_unlock_test()
	elseif type == "Amazon Prime Video" then
		region = prime_video_unlock_test()
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

function auto_get_policy_group(passwd, ip, port)
	local auto_get_group, con
	
	if type == "Netflix" then
		luci.sys.call('curl -sL -m 5 --limit-rate 1k -o /dev/null https://www.netflix.com &')
	elseif type == "Disney Plus" then
		luci.sys.call('curl -sL -m 5 --limit-rate 1k -o /dev/null https://www.disneyplus.com &')
	elseif type == "HBO Now" then
		luci.sys.call('curl -s -m 5 --limit-rate 50B -o /dev/null https://play.hbonow.com/assets/fonts/Street2-Medium.ttf &')
	elseif type == "HBO Max" then
		luci.sys.call('curl -sL -m 5 --limit-rate 1k -o /dev/null https://www.hbomax.com &')
	elseif type == "HBO GO Asia" then
		luci.sys.call('curl -s -m 5 --limit-rate 50B -o /dev/null https://www.hbogoasia.sg/static/media/GothamLight.8566e233.ttf &')
	elseif type == "YouTube Premium" then
		luci.sys.call('curl -sL -m 5 --limit-rate 1k -o /dev/null https://m.youtube.com/premium &')
	elseif type == "TVB Anywhere+" then
		luci.sys.call('curl -sL -m 5 --limit-rate 1k -o /dev/null https://uapisfm.tvbanywhere.com.sg &')
	elseif type == "Amazon Prime Video" then
		luci.sys.call('curl -sL -m 5 --limit-rate 1k -o /dev/null https://www.primevideo.com &')
	end
	os.execute("sleep 1")
	con = luci.sys.exec(string.format('curl -sL -m 5 --retry 2 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XGET http://%s:%s/connections', passwd, ip, port))
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
			elseif type == "Disney Plus" then
				if string.match(con.connections[i].metadata.host, "www%.disneyplus%.com") then
					auto_get_group = con.connections[i].chains[#(con.connections[i].chains)]
					break
				end
			elseif type == "HBO Now" then
				if string.match(con.connections[i].metadata.host, "play%.hbonow%.com") then
					auto_get_group = con.connections[i].chains[#(con.connections[i].chains)]
					break
				end
			elseif type == "HBO Max" then
				if string.match(con.connections[i].metadata.host, "www%.hbomax%.com") then
					auto_get_group = con.connections[i].chains[#(con.connections[i].chains)]
					break
				end
			elseif type == "HBO GO Asia" then
				if string.match(con.connections[i].metadata.host, "www%.hbogoasia%.sg") then
					auto_get_group = con.connections[i].chains[#(con.connections[i].chains)]
					break
				end
			elseif type == "YouTube Premium" then
				if string.match(con.connections[i].metadata.host, "m%.youtube%.com") then
					auto_get_group = con.connections[i].chains[#(con.connections[i].chains)]
					break
				end
			elseif type == "TVB Anywhere+" then
				if string.match(con.connections[i].metadata.host, "uapisfm%.tvbanywhere%.com%.sg") then
					auto_get_group = con.connections[i].chains[#(con.connections[i].chains)]
					break
				end
			elseif type == "Amazon Prime Video" then
				if string.match(con.connections[i].metadata.host, "www%.primevideo%.com") then
					auto_get_group = con.connections[i].chains[#(con.connections[i].chains)]
					break
				end
			end
		end
	end
	return auto_get_group
end

function get_group_now(info, group)
	local now
	local group_ = group
	if table_include(groups, group_) then
		while table_include(groups, group_) do
			for _, value in pairs(info.proxies) do
				if value.name == group_ then
					now = value.now
					group_ = value.now
				end
			end
		end
	end
	return now or group
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
						now_name = value.now or group_name
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
					now_name = value.now or name
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
						now_name = value.now or group
						group = value.now
						break
					end
				end
			end
		else
			for _, value in pairs(info.proxies) do
				if value.name == name then
					table.insert(proxies, group)
					now_name = value.now or name
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

function datamatch(data, regex)
	local result = luci.sys.exec(string.format('ruby -E UTF-8 -e "x=\'%s\'; if x =~ /%s/i then print \'true\' else print \'false\' end"', data, regex))
	if result == "true" then return true else return false end
end

-- Thanks https://github.com/lmc999/RegionRestrictionCheck --

function netflix_unlock_test()
	status = 0
	local url = "https://www.netflix.com/title/"..filmId
	local headers = "User-Agent: "..UA
	local info = luci.sys.exec(string.format('curl -sLI -m 3 --retry 2 -o /dev/null -w %%{json} -H "Content-Type: application/json" -H "%s" -XGET %s', headers, url))
	local result = {}
	local region
	local regex = uci:get("openclash", "config", "stream_auto_select_region_key_netflix") or ""
	if info then
		info = json.parse(info)
	end
	if info then
		if info.http_code == 200 then
			status = 2
			string.gsub(info.url_effective, '[^/]+', function(w) table.insert(result, w) end)
			region = string.upper(string.match(result[3], "^%a+"))
			if region == "TITLE" then region = "US" end
			if not datamatch(region, regex) then
				status = 3
			end
			return region
		elseif info.http_code == 404 or info.http_code == 403 then
			status = 1
		end
	end
	return
end

function disney_unlock_test()
	status = 0
	local url = "https://global.edge.bamgrid.com/devices"
	local url2 = "https://global.edge.bamgrid.com/token"
	local url3 = "https://disney.api.edge.bamgrid.com/graph/v1/device/graphql"
	local headers = '-H "Accept-Language: en" -H "Content-Type: application/json" -H "authorization: ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84"'
	local auth = '-H "authorization: Bearer ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84"'
	local body = '{"query":"mutation registerDevice($input: RegisterDeviceInput!) { registerDevice(registerDevice: $input) { grant { grantType assertion } } }","variables":{"input":{"deviceFamily":"browser","applicationRuntime":"chrome","deviceProfile":"windows","deviceLanguage":"en","attributes":{"osDeviceIds":[],"manufacturer":"microsoft","model":null,"operatingSystem":"windows","operatingSystemVersion":"10.0","browserName":"chrome","browserVersion":"96.0.4606"}}}}'
	local region, assertion, data, preassertion, disneycookie, tokencontent
	local regex = uci:get("openclash", "config", "stream_auto_select_region_key_disney") or ""
	
	preassertion = luci.sys.exec(string.format("curl -sL -m 3 --retry 2 %s -H 'User-Agent: %s' -H 'content-type: application/json; charset=UTF-8' -d '{\"deviceFamily\":\"browser\",\"applicationRuntime\":\"chrome\",\"deviceProfile\":\"windows\",\"attributes\":{}}' -XPOST %s", auth, UA, url))

	if preassertion and json.parse(preassertion) then
		assertion = json.parse(preassertion).assertion
	end
	
	if not assertion then return end

	disneycookie = "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Atoken-exchange&latitude=0&longitude=0&platform=browser&subject_token="..assertion.."&subject_token_type=urn%3Abamtech%3Aparams%3Aoauth%3Atoken-type%3Adevice"
	tokencontent = luci.sys.exec(string.format("curl -sL -m 3 --retry 2 %s -H 'User-Agent: %s' -d '%s' -XPOST %s", auth, UA, disneycookie, url2))

	if tokencontent and json.parse(tokencontent) then
		if json.parse(tokencontent).error_description then
			status = 1
			return
		end
	end
	
	data = luci.sys.exec(string.format("curl -sL -m 3 --retry 2 %s -H 'User-Agent: %s' -d '%s' -XPOST %s", headers, UA, body, url3))

	if data and json.parse(data) then
		status = 1
		if json.parse(data).extensions and json.parse(data).extensions.sdk and json.parse(data).extensions.sdk.session then
			region = json.parse(data).extensions.sdk.session.location.countryCode or ""
			inSupportedLocation = json.parse(data).extensions.sdk.session.inSupportedLocation or ""
			if region == "JP" then
				status = 2
				if not datamatch(region, regex) then
					status = 3
				end
				return region
			end

			if region and region ~= "" and inSupportedLocation then
				status = 2
				if not datamatch(region, regex) then
					status = 3
				end
				return region
			end
		end
	end
	return
end

function hbo_now_unlock_test()
	status = 0
	local url = "https://play.hbonow.com/"
	local data = luci.sys.exec(string.format("curl -sL -m 3 --retry 2 -o /dev/null -w %%{json} -H 'Content-Type: application/json' -H 'User-Agent: %s' %s", UA, url))
	if data then
		data = json.parse(data)
	end
	if data then
		if data.http_code == 200 then
			status = 1
			if string.find(data.url_effective,"play%.hbonow%.com") then
				status = 2
			end
		end
	end
	return
end

function hbo_max_unlock_test()
	status = 0
	local url = "https://www.hbomax.com/"
	local data = luci.sys.exec(string.format("curl -sL -m 3 --retry 2 -o /dev/null -w %%{json} -H 'Content-Type: application/json' -H 'User-Agent: %s' %s", UA, url))
	local result = {}
	local region = ""
	local regex = uci:get("openclash", "config", "stream_auto_select_region_key_hbo_max") or ""
	if data then
		data = json.parse(data)
	end
	if data then
		if data.http_code == 200 then
			status = 1
			if not string.find(data.url_effective,"geo%-availability") then
				status = 2
				string.gsub(data.url_effective, '[^/]+', function(w) table.insert(result, w) end)
				if result[3] then
					region = string.upper(string.match(result[3], "^%a+"))
				end
				if not datamatch(region, regex) then
					status = 3
				end
				return region
			end
		end
	end
	return
end

function hbo_go_asia_unlock_test()
	status = 0
	local url = "https://api2.hbogoasia.com/v1/geog?lang=undefined&version=0&bundleId=www.hbogoasia.com"
	local httpcode = luci.sys.exec(string.format("curl -sL -m 3 --retry 2 -o /dev/null -w %%{http_code} -H 'Content-Type: application/json' -H 'User-Agent: %s' %s", UA, url))
	local regex = uci:get("openclash", "config", "stream_auto_select_region_key_hbo_go_asia") or ""
	local region = ""
	if tonumber(httpcode) == 200 then
		status = 1
		local data = luci.sys.exec(string.format("curl -sL -m 3 --retry 2 -H 'Content-Type: application/json' -H 'User-Agent: %s' %s", UA, url))
		if data then
			data = json.parse(data)
		end
		if data then
			if data.territory then
				status = 2
				if data.country then
					region = string.upper(data.country)
				end
				if not datamatch(region, regex) then
					status = 3
				end
				return region
			end
		end
	end
	return
end

function ytb_unlock_test()
	status = 0
	local url = "https://m.youtube.com/premium"
	local httpcode = luci.sys.exec(string.format("curl -sL -m 3 --retry 2 -o /dev/null -w %%{http_code} -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' %s", UA, url))
	local region = ""
	local regex = uci:get("openclash", "config", "stream_auto_select_region_key_ytb") or ""
	if tonumber(httpcode) == 200 then
		status = 1
		local data = luci.sys.exec(string.format("curl -sL -m 3 --retry 2 -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' %s", UA, url))
		if string.find(data, "is not available in your country") then
	  	return
	  end
	  region = string.sub(string.match(data, "\"GL\":\"%a+\""), 7, -2)
		if region then
			status = 2
		else
			if not string.find(data,"www%.google%.cn") then
	  		status = 2
	  		region = "US"
	  	end
		end
		if not datamatch(region, regex) then
			status = 3
		end
	end
	return region
end

function tvb_anywhere_unlock_test()
	status = 0
	local url = "https://uapisfm.tvbanywhere.com.sg/geoip/check/platform/android"
	local httpcode = luci.sys.exec(string.format("curl -sL -m 3 --retry 2 -o /dev/null -w %%{http_code} -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' %s", UA, url))
	local region = ""
	local regex = uci:get("openclash", "config", "stream_auto_select_region_key_tvb_anywhere") or ""
	if tonumber(httpcode) == 200 then
		status = 1
		local data = luci.sys.exec(string.format("curl -sL -m 3 --retry 2 -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' %s", UA, url))
		if data then
			data = json.parse(data)
		end
		if data and data.allow_in_this_country then
			status = 2
			if data.country then
	  		region = string.upper(data.country)
	  	end
	  	if not datamatch(region, regex) then
				status = 3
			end
		end
	end
	return region
end

function prime_video_unlock_test()
	status = 0
	local url = "https://www.primevideo.com"
	local httpcode = luci.sys.exec(string.format("curl -sL -m 3 --retry 2 -o /dev/null -w %%{http_code} -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' %s", UA, url))
	local region
	local regex = uci:get("openclash", "config", "stream_auto_select_region_key_prime_video") or ""
	if tonumber(httpcode) == 200 then
		status = 1
		local data = luci.sys.exec(string.format("curl -sL -m 3 --retry 2 -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' %s", UA, url))
		if data then
	  	region = string.sub(string.match(data, "\"currentTerritory\":\"%a+\""), 21, -2)
			if region then
				status = 2
				if not datamatch(region, regex) then
					status = 3
				end
				return region
			end
		end
	end
	return
end

unlock_auto_select()