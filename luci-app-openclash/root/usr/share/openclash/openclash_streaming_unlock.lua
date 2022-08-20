#!/usr/bin/lua

require "nixio"
require "luci.util"
require "luci.sys"

local uci = require("luci.model.uci").cursor()
local fs = require "luci.openclash"
local json = require "luci.jsonc"
local UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/94.0.4606.61 Safari/537.36"
local filmId = 70143836
local class_type = type
local type = arg[1]
local all_test
local router_self_proxy = tonumber(uci:get("openclash", "config", "router_self_proxy")) or 1
local now_name, group_name, group_type, group_show, status, ip, port, passwd, group_match_name
local groups = {}
local proxies = {}
local self_status = luci.sys.exec(string.format('ps -w |grep -v grep |grep -c "openclash_streaming_unlock.lua %s"', type))
local select_logic = uci:get("openclash", "config", "stream_auto_select_logic") or "urltest"

if not type then
	print(os.date("%Y-%m-%d %H:%M:%S").." ".."Error: Streaming Unlock Has No Parameter of Type, Exiting...")
	os.exit(0)
elseif router_self_proxy == 0 then
	print(os.date("%Y-%m-%d %H:%M:%S").." ".."Error: Streaming Unlock Could not Work Because of Router-Self Proxy Disabled, Exiting...")
	os.exit(0)
elseif tonumber(self_status) > 1 then
	print(os.date("%Y-%m-%d %H:%M:%S").." ".."Error: Multiple Scripts Running, Exiting...")
	os.exit(0)
end

if arg[2] == "all" then all_test = true else all_test = false end

function unlock_auto_select()
	local key_group, region, now, proxy, group_match, proxy_default, auto_get_group, info, group_now
	local original = {}
	local other_region_unlock = {}
	local no_old_region_unlock = {}
	local full_support_list = {}
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
	local select_all_full_support = "unlock node test finished, rolled back to the full support node"
	local select_all_other_region = "unlock node test finished, no node match the regex, rolled back to other full support node"
	local select_all_faild = "unlock node test finished, no node available, rolled back to the"
	local no_nodes_filter = "no nodes name match the regex!"
	local select_success_no_old_region = "unlock node auto selected successfully, no node match the old region, rolled back to other full support node"
	local no_old_region_unlock_test = "full support but not match the old region!"
	local no_old_region_unlock_no_select = "but not match the old region! the type of group is not select, auto select could not work!"
	local select_all_no_old_region = "unlock node test finished, no node match the old region, rolled back to other full support node"

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
		elseif type == "DAZN" then
			key_group = uci:get("openclash", "config", "stream_auto_select_group_key_dazn") or "dazn"
		elseif type == "Paramount Plus" then
			key_group = uci:get("openclash", "config", "stream_auto_select_group_key_paramount_plus") or "paramount"
		elseif type == "Discovery Plus" then
			key_group = uci:get("openclash", "config", "stream_auto_select_group_key_discovery_plus") or "discovery"
		elseif type == "Bilibili" then
			key_group = uci:get("openclash", "config", "stream_auto_select_group_key_bilibili") or "bilibili"
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
				if status ~= 2 and status ~= 4 then
					os.execute("sleep 3")
					region = proxy_unlock_test()
				end
				if status == 2 or status == 4 then
					if region and region ~= "" then
						table.insert(full_support_list, {value.now, value.now, get_group_now(info, value.now), region})
						print(now..full_support.."【"..region.."】")
					else
						table.insert(full_support_list, {value.now, value.now, get_group_now(info, value.now)})
						print(now..full_support_no_area)
					end
					if not all_test and #nodes_filter(now_name, info) ~= 0 then
						if status == 4 then
							status = 2
							if region and region ~= "" then
								fs.writefile(string.format("/tmp/openclash_%s_region", type), region)
							end
						end
						break
					else
						status = 0
					end
				elseif status == 3 then
					if region and region ~= "" then
						table.insert(other_region_unlock, {value.now, value.now, get_group_now(info, value.now), region})
					else
						table.insert(other_region_unlock, {value.now, value.now, get_group_now(info, value.now)})
					end
					if not all_test then
						print(now..other_region_unlock_test_start)
					else
						print(now..other_region_unlock_test)
					end
				elseif status == 1 then
					table.insert(original, {value.now, value.now, get_group_now(info, value.now)})
					if not all_test then
						if type == "Netflix" then
							print(now..original_test_start)
						else
							print(now..no_unlock_test_start)
						end
					else
						if type == "Netflix" then
							print(now..only_original)
						else
							print(now..no_unlock)
						end
					end
				else
					if not all_test then
						print(now..faild_test_start)
					else
						print(now..test_faild)
					end
				end
				
				--find new unlock
				if value.type == "Selector" then
					--save group current selected
					proxy_default = value.now
					if not all_test then
						--filter nodes
						value.all = nodes_filter(value.all, info)
						if select_logic == "random" then
							--sort by random
							value.all = table_rand(value.all)
						else
							--sort by urltest
							value.all = table_sort_by_urltest(value.all)
						end
					end
					if #(value.all) == 0 then
						print(os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..value.name.."】"..no_nodes_filter)
						break
					end
					--loop proxy test
					for i = 1, #(value.all) do
						while true do
							if value.all[i] == "REJECT" then
								break
							else
								get_proxy(info, value.all[i], value.name)
								if group_type == "Selector" then
									if group_name == value.all[i] then
										luci.sys.exec(string.format("curl -sL -m 3 --retry 2 -w %%{http_code} -o /dev/null -H 'Authorization: Bearer %s' -H 'Content-Type:application/json' -X PUT -d '{\"name\":\"%s\"}' http://%s:%s/proxies/%s", passwd, group_name, ip, port, urlencode(value.name)))
									end
									if not all_test then
										--filter nodes
										proxies = nodes_filter(proxies, info)
										if select_logic == "random" then
											--sort by random
											proxies = table_rand(proxies)
										else
											--sort by urltest
											proxies = table_sort_by_urltest(proxies)
										end
									end
									if #(proxies) == 0 then
										print(os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..group_show.."】"..no_nodes_filter)
										break
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
											if table_include(tested_proxy, get_group_now(info, proxy)) then
												break
											else
												table.insert(tested_proxy, proxy)
											end
											while true do
												if proxy == "REJECT" or get_group_now(info, proxy) == "REJECT" then
													break
												else
													luci.sys.exec(string.format("curl -sL -m 3 --retry 2 -w %%{http_code} -o /dev/null -H 'Authorization: Bearer %s' -H 'Content-Type:application/json' -X PUT -d '{\"name\":\"%s\"}' http://%s:%s/proxies/%s", passwd, proxy, ip, port, urlencode(group_name)))
													region = proxy_unlock_test()
													if status == 2 then
														if region and region ~= "" then
															table.insert(full_support_list, {value.all[i], group_name, proxy, region})
															if not all_test then
																print(now..full_support.."【"..region.."】")
																print(os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..value.name.."】"..select_success.."【"..proxy.."】"..area_i18.."【"..region.."】")
															else
																print(now..full_support.."【"..region.."】")
															end
														else
															table.insert(full_support_list, {value.all[i], group_name, proxy})
															if not all_test then
																print(now..full_support_no_area)
																print(os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..value.name.."】"..select_success.."【"..proxy.."】")
															else
																print(now..full_support_no_area)
															end
														end
													elseif status == 3 then
														if region and region ~= "" then
															table.insert(other_region_unlock, {value.all[i], group_name, proxy, region})
														else
															table.insert(other_region_unlock, {value.all[i], group_name, proxy})
														end
														print(now..other_region_unlock_test)
													elseif status == 4 then
														if region and region ~= "" then
															table.insert(no_old_region_unlock, {value.all[i], group_name, proxy, region})
														else
															table.insert(no_old_region_unlock, {value.all[i], group_name, proxy})
														end
														print(now..no_old_region_unlock_test)
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
											if status == 2 and not all_test then
												break
											elseif p == #(proxies) and #(proxies) ~= 1 then
												luci.sys.exec(string.format("curl -sL -m 3 --retry 2 -w %%{http_code} -o /dev/null -H 'Authorization: Bearer %s' -H 'Content-Type:application/json' -X PUT -d '{\"name\":\"%s\"}' http://%s:%s/proxies/%s", passwd, now_name, ip, port, urlencode(group_name)))
											end
											break
										end
										if status == 2 and not all_test then break end
									end
								else
									--only group expand
									luci.sys.exec(string.format("curl -sL -m 3 --retry 2 -w %%{http_code} -o /dev/null -H 'Authorization: Bearer %s' -H 'Content-Type:application/json' -X PUT -d '{\"name\":\"%s\"}' http://%s:%s/proxies/%s", passwd, value.all[i], ip, port, urlencode(group_name)))
									while true do
										if table_include(tested_proxy, now_name) or #nodes_filter(now_name, info) == 0 then
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
												table.insert(full_support_list, {value.all[i], group_name, value.all[i], region})
												if not all_test then
													print(now..full_support.."【"..region.."】")
													print(os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..value.name.."】"..select_success.."【"..get_group_now(info, now_name).."】"..area_i18.."【"..region.."】")
												else
													print(now..full_support.."【"..region.."】")
												end
											else
												table.insert(full_support_list, {value.all[i], group_name, value.all[i]})
												if not all_test then
													print(now..full_support_no_area)
													print(os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..value.name.."】"..select_success.."【"..get_group_now(info, now_name).."】")
												else
													print(now..full_support_no_area)
												end
											end
										elseif status == 3 then
											if region and region ~= "" then
												table.insert(other_region_unlock, {value.all[i], group_name, value.all[i], region})
											else
												table.insert(other_region_unlock, {value.all[i], group_name, value.all[i]})
											end
											print(now..full_support.."【"..region.."】"..other_region_unlock_no_select)
										elseif status == 4 then
											if region and region ~= "" then
												table.insert(no_old_region_unlock, {value.all[i], group_name, value.all[i], region})
											else
												table.insert(no_old_region_unlock, {value.all[i], group_name, value.all[i]})
											end
											print(now..full_support.."【"..region.."】"..no_old_region_unlock_no_select)
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
						if status == 2 and not all_test then
							close_connections()
							break
						elseif i == #(value.all) and (#original > 0 or #other_region_unlock > 0 or #no_old_region_unlock > 0 or #full_support_list > 0) then
							if #full_support_list > 0 then
								fallback_select = full_support_list
							elseif #no_old_region_unlock > 0 then
								fallback_select = no_old_region_unlock
							elseif #other_region_unlock > 0 then
								fallback_select = other_region_unlock
							else
								fallback_select = original
							end
							for k, v in pairs(fallback_select) do
								if #nodes_filter(v[3], info) ~= 0 then
									if v[4] then 
										table.insert(fallback_select, 1, {v[1], v[2], v[3], v[4]})
										fs.writefile(string.format("/tmp/openclash_%s_region", type), v[4])
									else
										table.insert(fallback_select, 1, {v[1], v[2], v[3]})
									end
									break
								end
							end
							for k, v in pairs(fallback_select) do
								luci.sys.exec(string.format("curl -sL -m 3 --retry 2 -w %%{http_code} -o /dev/null -H 'Authorization: Bearer %s' -H 'Content-Type:application/json' -X PUT -d '{\"name\":\"%s\"}' http://%s:%s/proxies/%s", passwd, v[1], ip, port, urlencode(value.name)))
								luci.sys.exec(string.format("curl -sL -m 3 --retry 2 -w %%{http_code} -o /dev/null -H 'Authorization: Bearer %s' -H 'Content-Type:application/json' -X PUT -d '{\"name\":\"%s\"}' http://%s:%s/proxies/%s", passwd, v[3], ip, port, urlencode(v[2])))
								if table_include(groups, v[3]) then
									group_now = "【".. v[3] .. " ➟ " .. get_group_now(info, v[3]) .. "】"
								else
									group_now = "【".. v[3] .. "】"
								end
								if v[4] then
									group_now = group_now .. area_i18 .. "【"..v[4].."】"
								else
									group_now = group_now .. area_i18 .. "【"..v[4].."】"
								end
								if #full_support_list > 0 then
									print(os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..value.name.."】"..select_all_full_support..group_now)
								elseif #no_old_region_unlock > 0 then
									if not all_test then
										print(os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..value.name.."】"..select_success_no_old_region..group_now)
									else
										print(os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..value.name.."】"..select_all_no_old_region..group_now)
									end
								elseif #other_region_unlock > 0 then
									if not all_test then
										print(os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..value.name.."】"..select_faild_other_region..group_now)
									else
										print(os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..value.name.."】"..select_all_other_region..group_now)
									end
								else
									if not all_test then
										print(os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..value.name.."】"..select_faild..group_now)
									else
										print(os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..value.name.."】"..select_all_faild..group_now)
									end
								end
								close_connections()
								break
							end
						elseif i == #(value.all) then
							luci.sys.exec(string.format("curl -sL -m 3 --retry 2 -w %%{http_code} -o /dev/null -H 'Authorization: Bearer %s' -H 'Content-Type:application/json' -X PUT -d '{\"name\":\"%s\"}' http://%s:%s/proxies/%s", passwd, proxy_default, ip, port, urlencode(value.name)))
							if table_include(groups, proxy_default) then
								group_now = value.name.." ➟ "..proxy_default.." ➟ "..get_group_now(info, proxy_default)
							else
								group_now = value.name.." ➟ "..proxy_default
							end
							print(os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..value.name.."】"..select_faild.."【"..group_now.."】")
						end
					end
				elseif #nodes_filter(get_group_now(info, value.name), info) ~= 0 then
					region = proxy_unlock_test()
					if status == 2 then
						if region and region ~= "" then
							if not all_test then
								print(now..full_support.."【"..region.."】")
							end
							print(os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..value.name.."】"..select_success.."【"..get_group_now(info, value.name).."】"..area_i18.."【"..region.."】")
						else
							if not all_test then
								print(now..full_support_no_area)
							end
							print(os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..value.name.."】"..select_success.."【"..get_group_now(info, value.name).."】")
						end
						if not all_test then
							break
						end
					elseif status == 3 then
						print(now..full_support.."【"..region.."】"..other_region_unlock_no_select)
					elseif status == 4 then
						print(now..full_support.."【"..region.."】"..no_old_region_unlock_no_select)
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
		if status == 2 and not all_test then break end
	end
	if not group_match and not auto_get_group then
		print(os.date("%Y-%m-%d %H:%M:%S").." "..type.." "..gorup_i18.."【"..key_group.."】"..no_group_find)
	end
end

function urlencode(data)
	local data = luci.sys.exec(string.format('curl -s -o /dev/null -w %%{url_effective} --get --data-urlencode "key=%s" ""', data))
	return luci.sys.exec(string.format("echo -n %s |sed 's/+/%%20/g'", string.match(data, "/%?key=(.+)")))
end

function datamatch(data, regex)
	local result = luci.sys.exec(string.format('ruby -E UTF-8 -e "x=\'%s\'; if x =~ /%s/i then print \'true\' else print \'false\' end"', data, regex))
	if result == "true" then return true else return false end
end

function table_rand(t)
	if t == nil then
		return
	end
	local tab = {}
	math.randomseed(tostring(os.time()):reverse():sub(1, 9))
	while #t ~= 0 do
		local n = math.random(0, #t)
		if t[n] ~= nil then
			table.insert(tab, t[n])
			table.remove(t, n)
		end
	end
	return tab
end

function table_sort_by_urltest(t)
	local info, get_delay, group_delay
	local count = 1
	local tab = {}
	local result = {}

	if t == nil then
		return
	end

	info = luci.sys.exec(string.format('curl -sL -m 3 --retry 2 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XGET http://%s:%s/providers/proxies', passwd, ip, port))
	if info then
		info = json.parse(info)
		if not info or not info.providers then return t end
	end

	for n = 1, #(t) do
		get_delay = false
		for _, value in pairs(info.providers) do
			if value.proxies and value.name ~= "default" then
				for _, v in pairs(value.proxies) do
					if v.name == t[n] then
						if v.history and #(v.history) ~= 0 and v.history[#(v.history)].delay ~= 0 then
							table.insert(tab, {v.name, v.history[#(v.history)].delay})
							get_delay = true
						end
					end
					if get_delay then break end
				end
			end
			if get_delay then break end
		end
		if not get_delay then
			if table_include(groups, t[n]) or t[n] == "DIRECT" then
				group_delay = luci.sys.exec(string.format('curl -sL -m 5 --retry 2 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XGET "http://%s:%s/proxies/%s/delay?timeout=5000&url=http%%3A%%2F%%2F%s"', passwd, ip, port, urlencode(t[n]), "www.gstatic.com%2Fgenerate_204"))
				if group_delay then
					group_delay = json.parse(group_delay)
				end
				if group_delay.delay and group_delay.delay ~= 0 then
					table.insert(tab, {t[n], group_delay.delay})
				else
					table.insert(tab, {t[n], 123456})
				end
			else
				table.insert(tab, {t[n], 123456})
			end
		end
	end

	table.sort(tab, function(a, b)
		return a[2] < b[2]
	end)

	for _, value in pairs(tab) do
		table.insert(result, value[1])
	end

	return result
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

function get_auth_info()
	port = uci:get("openclash", "config", "cn_port")
	passwd = uci:get("openclash", "config", "dashboard_password") or ""
	ip = luci.sys.exec("uci -q get network.lan.ipaddr |awk -F '/' '{print $1}' 2>/dev/null |tr -d '\n'")
	
	if not ip or ip == "" then
		ip = luci.sys.exec("ip address show $(uci -q -p /tmp/state get network.lan.ifname || uci -q -p /tmp/state get network.lan.device) | grep -w 'inet' 2>/dev/null |grep -Eo 'inet [0-9\.]+' | awk '{print $2}' | tr -d '\n'")
	end
	
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
	local enable = tonumber(uci:get("openclash", "config", "stream_auto_select_close_con")) or 1
	if enable == 0 then return end
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
				luci.sys.exec(string.format('curl -sL -m 3 --retry 2 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -X DELETE http://%s:%s/connections/%s >/dev/null 2>&1 &', passwd, ip, port, group_cons_id[i]))
			end
		end
	end
end

function nodes_filter(t, info)
	if t == nil then return end
	local tab = {}
	local regex, group_now
	
	if type == "Netflix" then
		regex = uci:get("openclash", "config", "stream_auto_select_node_key_netflix") or ""
	elseif type == "Disney Plus" then
		regex = uci:get("openclash", "config", "stream_auto_select_node_key_disney") or ""
	elseif type == "HBO Now" then
		regex = uci:get("openclash", "config", "stream_auto_select_node_key_hbo_now") or ""
	elseif type == "HBO Max" then
		regex = uci:get("openclash", "config", "stream_auto_select_node_key_hbo_max") or ""
	elseif type == "HBO GO Asia" then
		regex = uci:get("openclash", "config", "stream_auto_select_node_key_hbo_go_asia") or ""
	elseif type == "YouTube Premium" then
		regex = uci:get("openclash", "config", "stream_auto_select_node_key_ytb") or ""
	elseif type == "TVB Anywhere+" then
		regex = uci:get("openclash", "config", "stream_auto_select_node_key_tvb_anywhere") or ""
	elseif type == "Amazon Prime Video" then
		regex = uci:get("openclash", "config", "stream_auto_select_node_key_prime_video") or ""
	elseif type == "DAZN" then
		regex = uci:get("openclash", "config", "stream_auto_select_node_key_dazn") or ""
	elseif type == "Paramount Plus" then
		regex = uci:get("openclash", "config", "stream_auto_select_node_key_paramount_plus") or ""
	elseif type == "Discovery Plus" then
		regex = uci:get("openclash", "config", "stream_auto_select_node_key_discovery_plus") or ""
	elseif type == "Bilibili" then
		regex = uci:get("openclash", "config", "stream_auto_select_node_key_bilibili") or ""
	end

	if class_type(t) == "table" then
		if not regex or regex == "" then
			tab = t
			return tab
		end
		for n = 1, #t do
			if table_include(groups, t[n]) and info then
				group_now = get_group_now(info, t[n])
				if datamatch(group_now, regex) then
					table.insert(tab, t[n])
				end
			elseif datamatch(t[n], regex) and not table_include(groups, t[n]) then
				table.insert(tab, t[n])
			end
		end
	else
		if not regex or regex == "" then
			table.insert(tab, t)
			return tab
		end
		if table_include(groups, t) and info then
			group_now = get_group_now(info, t)
			if datamatch(group_now, regex) then
				table.insert(tab, t)
			end
		elseif datamatch(t, regex) and not table_include(groups, t) then
			table.insert(tab, t)
		end
	end
	return tab
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
	elseif type == "DAZN" then
		region = dazn_unlock_test()
	elseif type == "Paramount Plus" then
		region = paramount_plus_unlock_test()
	elseif type == "Discovery Plus" then
		region = discovery_plus_unlock_test()
	elseif type == "Bilibili" then
		region = bilibili_unlock_test()
	end
	return region
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
	elseif type == "DAZN" then
		luci.sys.call('curl -sL -m 5 --limit-rate 1k -o /dev/null https://www.dazn.com &')
	elseif type == "Paramount Plus" then
		luci.sys.call('curl -sL -m 5 --limit-rate 1k -o /dev/null https://www.paramountplus.com/ &')
	elseif type == "Discovery Plus" then
		luci.sys.call('curl -sL -m 5 --limit-rate 1k -o /dev/null https://www.discoveryplus.com/ &')
	elseif type == "Bilibili" then
		luci.sys.call('curl -sL -m 5 --limit-rate 1k -o /dev/null https://www.bilibili.com/ &')
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
			elseif type == "DAZN" then
				if string.match(con.connections[i].metadata.host, "www%.dazn%.com") then
					auto_get_group = con.connections[i].chains[#(con.connections[i].chains)]
					break
				end
			elseif type == "Paramount Plus" then
				if string.match(con.connections[i].metadata.host, "www%.paramountplus%.com") then
					auto_get_group = con.connections[i].chains[#(con.connections[i].chains)]
					break
				end
			elseif type == "Discovery Plus" then
				if string.match(con.connections[i].metadata.host, "www%.discoveryplus%.com") then
					auto_get_group = con.connections[i].chains[#(con.connections[i].chains)]
					break
				end
			elseif type == "Bilibili" then
				if string.match(con.connections[i].metadata.host, "www%.bilibili%.com") then
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
					break
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
					break
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

-- Thanks https://github.com/lmc999/RegionRestrictionCheck --

function netflix_unlock_test()
	status = 0
	local url = "https://www.netflix.com/title/"..filmId
	local headers = "User-Agent: "..UA
	local info = luci.sys.exec(string.format('curl -sLI --connect-timeout 5 -m 10 --speed-time 5 --speed-limit 1 --retry 2 -o /dev/null -w %%{json} -H "Content-Type: application/json" -H "%s" -XGET %s', headers, url))
	local result = {}
	local region, old_region
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
			if fs.isfile(string.format("/tmp/openclash_%s_region", type)) then
				old_region = fs.readfile(string.format("/tmp/openclash_%s_region", type))
			end
			if not datamatch(region, regex) then
				status = 3
			elseif old_region and region ~= old_region and not all_test then
				status = 4
			end
			if status == 2 and region ~= old_region and not all_test then
				fs.writefile(string.format("/tmp/openclash_%s_region", type), region)
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
	local region, old_region, assertion, data, preassertion, disneycookie, tokencontent
	local regex = uci:get("openclash", "config", "stream_auto_select_region_key_disney") or ""
	
	preassertion = luci.sys.exec(string.format("curl -sL --connect-timeout 5 -m 10 --speed-time 5 --speed-limit 1 --retry 2 %s -H 'User-Agent: %s' -H 'content-type: application/json; charset=UTF-8' -d '{\"deviceFamily\":\"browser\",\"applicationRuntime\":\"chrome\",\"deviceProfile\":\"windows\",\"attributes\":{}}' -XPOST %s", auth, UA, url))

	if preassertion and json.parse(preassertion) then
		assertion = json.parse(preassertion).assertion
	end
	
	if not assertion then return end

	disneycookie = "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Atoken-exchange&latitude=0&longitude=0&platform=browser&subject_token="..assertion.."&subject_token_type=urn%3Abamtech%3Aparams%3Aoauth%3Atoken-type%3Adevice"
	tokencontent = luci.sys.exec(string.format("curl -sL --connect-timeout 5 -m 10 --speed-time 5 --speed-limit 1 --retry 2 %s -H 'User-Agent: %s' -d '%s' -XPOST %s", auth, UA, disneycookie, url2))

	if tokencontent and json.parse(tokencontent) then
		if json.parse(tokencontent).error_description then
			status = 1
			return
		end
	end
	
	data = luci.sys.exec(string.format("curl -sL --connect-timeout 5 -m 10 --speed-time 5 --speed-limit 1 --retry 2 %s -H 'User-Agent: %s' -d '%s' -XPOST %s", headers, UA, body, url3))

	if data and json.parse(data) then
		status = 1
		if json.parse(data).extensions and json.parse(data).extensions.sdk and json.parse(data).extensions.sdk.session then
			region = json.parse(data).extensions.sdk.session.location.countryCode or ""
			inSupportedLocation = json.parse(data).extensions.sdk.session.inSupportedLocation or ""
			if region == "JP" then
				status = 2
				if fs.isfile(string.format("/tmp/openclash_%s_region", type)) then
					old_region = fs.readfile(string.format("/tmp/openclash_%s_region", type))
				end
				if not datamatch(region, regex) then
					status = 3
				elseif old_region and not datamatch(region, old_region) and not all_test then
					status = 3
				end
				if status == 2 and not all_test then
					fs.writefile(string.format("/tmp/openclash_%s_region", type), region)
				end
				return region
			end

			if region and region ~= "" and inSupportedLocation then
				status = 2
				if fs.isfile(string.format("/tmp/openclash_%s_region", type)) then
					old_region = fs.readfile(string.format("/tmp/openclash_%s_region", type))
				end
				if not datamatch(region, regex) then
					status = 3
				elseif old_region and region ~= old_region and not all_test then
					status = 4
				end
				if status == 2 and region ~= old_region and not all_test then
					fs.writefile(string.format("/tmp/openclash_%s_region", type), region)
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
	local data = luci.sys.exec(string.format("curl -sL --connect-timeout 5 -m 10 --speed-time 5 --speed-limit 1 --retry 2 -o /dev/null -w %%{json} -H 'Content-Type: application/json' -H 'User-Agent: %s' %s", UA, url))
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
	local data = luci.sys.exec(string.format("curl -sL --connect-timeout 5 -m 10 --speed-time 5 --speed-limit 1 --retry 2 -o /dev/null -w %%{json} -H 'Content-Type: application/json' -H 'User-Agent: %s' %s", UA, url))
	local result = {}
	local region = ""
	local old_region = ""
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
				if fs.isfile(string.format("/tmp/openclash_%s_region", type)) then
					old_region = fs.readfile(string.format("/tmp/openclash_%s_region", type))
				end
				if not datamatch(region, regex) then
					status = 3
				elseif region ~= old_region and not all_test then
					status = 4
				end
				if status == 2 and not all_test and region ~= old_region then
					fs.writefile(string.format("/tmp/openclash_%s_region", type), region)
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
	local httpcode = luci.sys.exec(string.format("curl -sL --connect-timeout 5 -m 10 --speed-time 5 --speed-limit 1 --retry 2 -o /dev/null -w %%{http_code} -H 'Content-Type: application/json' -H 'User-Agent: %s' %s", UA, url))
	local regex = uci:get("openclash", "config", "stream_auto_select_region_key_hbo_go_asia") or ""
	local region = ""
	local old_region = ""
	if tonumber(httpcode) == 200 then
		status = 1
		local data = luci.sys.exec(string.format("curl -sL --connect-timeout 5 -m 10 --speed-time 5 --speed-limit 1 --retry 2 -H 'Content-Type: application/json' -H 'User-Agent: %s' %s", UA, url))
		if data then
			data = json.parse(data)
		end
		if data then
			if data.territory then
				status = 2
				if data.country then
					region = string.upper(data.country)
				end
				if fs.isfile(string.format("/tmp/openclash_%s_region", type)) then
					old_region = fs.readfile(string.format("/tmp/openclash_%s_region", type))
				end
				if not datamatch(region, regex) then
					status = 3
				elseif region ~= old_region and not all_test then
					status = 4
				end
				if status == 2 and not all_test and region ~= old_region then
					fs.writefile(string.format("/tmp/openclash_%s_region", type), region)
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
	local httpcode = luci.sys.exec(string.format("curl -sL --connect-timeout 5 -m 10 --speed-time 5 --speed-limit 1 --retry 2 -o /dev/null -w %%{http_code} -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' %s", UA, url))
	local region = ""
	local old_region = ""
	local data, he_data
	local regex = uci:get("openclash", "config", "stream_auto_select_region_key_ytb") or ""
	if tonumber(httpcode) == 200 then
		status = 1
		data = luci.sys.exec(string.format("curl -sL --connect-timeout 5 -m 10 --speed-time 5 --speed-limit 1 --retry 2 -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' -b 'YSC=BiCUU3-5Gdk; CONSENT=YES+cb.20220301-11-p0.en+FX+700; GPS=1; VISITOR_INFO1_LIVE=4VwPMkB7W5A; PREF=tz=Asia.Shanghai; _gcl_au=1.1.1809531354.1646633279' %s", UA, url))
		if string.find(data,"www%.google%.cn") or string.find(data, "is not available in your country") then
	  		return
	  	end
	  	region = string.sub(string.match(data, "\"GL\":\"%a+\""), 7, -2)
		if region then
			status = 2
		else
			he_data = luci.sys.exec(string.format("curl -sIL --connect-timeout 5 -m 10 --speed-time 5 --speed-limit 1 --retry 2 -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' %s", UA, url))
			region = string.sub(string.match(he_data, "gl=%a+"), 4, -1)
			if region then
				status = 2
			else
				region = "US"
			end
		end
		if fs.isfile(string.format("/tmp/openclash_%s_region", type)) then
			old_region = fs.readfile(string.format("/tmp/openclash_%s_region", type))
		end
		if not datamatch(region, regex) then
			status = 3
		elseif region ~= old_region and not all_test then
			status = 4
		end
		if status == 2 and not all_test and region ~= old_region then
			fs.writefile(string.format("/tmp/openclash_%s_region", type), region)
		end
	end
	return region
end

function tvb_anywhere_unlock_test()
	status = 0
	local url = "https://uapisfm.tvbanywhere.com.sg/geoip/check/platform/android"
	local httpcode = luci.sys.exec(string.format("curl -sL --connect-timeout 5 -m 10 --speed-time 5 --speed-limit 1 --retry 2 -o /dev/null -w %%{http_code} -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' %s", UA, url))
	local region = ""
	local old_region = ""
	local regex = uci:get("openclash", "config", "stream_auto_select_region_key_tvb_anywhere") or ""
	if tonumber(httpcode) == 200 then
		status = 1
		local data = luci.sys.exec(string.format("curl -sL --connect-timeout 5 -m 10 --speed-time 5 --speed-limit 1 --retry 2 -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' %s", UA, url))
		if data then
			data = json.parse(data)
		end
		if data and data.allow_in_this_country then
			status = 2
			if data.country then
	  			region = string.upper(data.country)
	  		end
	  		if fs.isfile(string.format("/tmp/openclash_%s_region", type)) then
				old_region = fs.readfile(string.format("/tmp/openclash_%s_region", type))
			end
			if not datamatch(region, regex) then
				status = 3
			elseif region ~= old_region and not all_test then
				status = 4
			end
			if status == 2 and not all_test and region ~= old_region then
				fs.writefile(string.format("/tmp/openclash_%s_region", type), region)
			end
		end
	end
	return region
end

function prime_video_unlock_test()
	status = 0
	local url = "https://www.primevideo.com"
	local httpcode = luci.sys.exec(string.format("curl -sL --connect-timeout 5 -m 10 --speed-time 5 --speed-limit 1 --retry 2 -o /dev/null -w %%{http_code} -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' %s", UA, url))
	local region
	local old_region
	local regex = uci:get("openclash", "config", "stream_auto_select_region_key_prime_video") or ""
	if tonumber(httpcode) == 200 then
		status = 1
		local data = luci.sys.exec(string.format("curl -sL --connect-timeout 5 -m 10 --speed-time 5 --speed-limit 1 --retry 2 -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' %s", UA, url))
		if data then
	  	region = string.sub(string.match(data, "\"currentTerritory\":\"%a+\""), 21, -2)
			if region then
				status = 2
				if fs.isfile(string.format("/tmp/openclash_%s_region", type)) then
					old_region = fs.readfile(string.format("/tmp/openclash_%s_region", type))
				end
				if not datamatch(region, regex) then
					status = 3
				elseif old_region and region ~= old_region and not all_test then
					status = 4
				end
				if status == 2 and not all_test and region ~= old_region then
					fs.writefile(string.format("/tmp/openclash_%s_region", type), region)
				end
				return region
			end
		end
	end
	return
end

function dazn_unlock_test()
	status = 0
	local url = "https://www.dazn.com"
	local url2 = "https://startup.core.indazn.com/misl/v5/Startup"
	local httpcode = luci.sys.exec(string.format("curl -sL --connect-timeout 5 -m 10 --speed-time 5 --speed-limit 1 --retry 2 -o /dev/null -w %%{http_code} -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' %s", UA, url))
	local region
	local old_region
	local regex = uci:get("openclash", "config", "stream_auto_select_region_key_dazn") or ""
	if tonumber(httpcode) == 200 then
		status = 1
		local data = luci.sys.exec(string.format("curl -sL --connect-timeout 5 -m 10 --speed-time 5 --speed-limit 1 --retry 2 -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' -X POST -d '{\"LandingPageKey\":\"generic\",\"Languages\":\"zh-CN,zh,en\",\"Platform\":\"web\",\"PlatformAttributes\":{},\"Manufacturer\":\"\",\"PromoCode\":\"\",\"Version\":\"2\"}' %s", UA, url2))
		if data then
			data = json.parse(data)
		end
		if data and data.Region and data.Region.isAllowed then
			status = 2
			if data.Region.GeolocatedCountry then
	  			region = string.upper(data.Region.GeolocatedCountry)
	  		end
	  		if fs.isfile(string.format("/tmp/openclash_%s_region", type)) then
				old_region = fs.readfile(string.format("/tmp/openclash_%s_region", type))
			end
			if not datamatch(region, regex) then
				status = 3
			elseif old_region and region ~= old_region and not all_test then
				status = 4
			end
			if status == 2 and not all_test and region ~= old_region then
				fs.writefile(string.format("/tmp/openclash_%s_region", type), region)
			end
		end
	end
	return region
end

function paramount_plus_unlock_test()
	status = 0
	local url = "https://www.paramountplus.com/"
	local region
	local old_region
	local regex = uci:get("openclash", "config", "stream_auto_select_region_key_paramount_plus") or ""
	local data = luci.sys.exec(string.format("curl -sL --connect-timeout 5 -m 10 --speed-time 5 --speed-limit 1 --retry 2 -o /dev/null -w %%{json} -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' %s", UA, url))
	data = json.parse(data)
	if data and tonumber(data.http_code) == 200 then
		status = 1
		if not string.find(data.url_effective, "intl") then
			status = 2
			data = luci.sys.exec(string.format("curl -sL --connect-timeout 5 -m 10 --speed-time 5 --speed-limit 1 --retry 2 -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' %s", UA, url))
			region = string.upper(string.sub(string.match(data, "\"siteEdition\":\"%a+|%a+\""), 19, -1)) or string.upper(string.sub(string.match(data, "property: '%a+'"), 12, -2))
			if region then
				if fs.isfile(string.format("/tmp/openclash_%s_region", type)) then
					old_region = fs.readfile(string.format("/tmp/openclash_%s_region", type))
				end
				if not datamatch(region, regex) then
					status = 3
				elseif old_region and region ~= old_region and not all_test then
					status = 4
				end
				if status == 2 and not all_test and region ~= old_region then
					fs.writefile(string.format("/tmp/openclash_%s_region", type), region)
				end
	  			return region
	  		end
		end
	end
end

function discovery_plus_unlock_test()
	status = 0
	local url = "https://us1-prod-direct.discoveryplus.com/token?deviceId=d1a4a5d25212400d1e6985984604d740&realm=go&shortlived=true"
	local url1 = "https://us1-prod-direct.discoveryplus.com/users/me"
	local region
	local regex = uci:get("openclash", "config", "stream_auto_select_region_key_discovery_plus") or ""
	local token = luci.sys.exec(string.format("curl -sL --connect-timeout 5 -m 10 --speed-time 5 --speed-limit 1 --retry 2 -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' '%s'", UA, url))
	if token and json.parse(token) and json.parse(token).data and json.parse(token).data.attributes then
		status = 1
		token = json.parse(token).data.attributes.token
		local cookie = string.format("-b \"_gcl_au=1.1.858579665.1632206782; _rdt_uuid=1632206782474.6a9ad4f2-8ef7-4a49-9d60-e071bce45e88; _scid=d154b864-8b7e-4f46-90e0-8b56cff67d05; _pin_unauth=dWlkPU1qWTRNR1ZoTlRBdE1tSXdNaTAwTW1Nd0xUbGxORFV0WWpZMU0yVXdPV1l6WldFeQ; _sctr=1|1632153600000; aam_fw=aam%%3D9354365%%3Baam%%3D9040990; aam_uuid=24382050115125439381416006538140778858; st=%s; gi_ls=0; _uetvid=a25161a01aa711ec92d47775379d5e4d; AMCV_BC501253513148ED0A490D45%%40AdobeOrg=-1124106680%%7CMCIDTS%%7C18894%%7CMCMID%%7C24223296309793747161435877577673078228%%7CMCAAMLH-1633011393%%7C9%%7CMCAAMB-1633011393%%7CRKhpRz8krg2tLO6pguXWp5olkAcUniQYPHaMWWgdJ3xzPWQmdj0y%%7CMCOPTOUT-1632413793s%%7CNONE%%7CvVersion%%7C5.2.0; ass=19ef15da-95d6-4b1d-8fa2-e9e099c9cc38.1632408400.1632406594\"", token)
		local data = luci.sys.exec(string.format("curl -sL --connect-timeout 5 -m 10 --speed-time 5 --speed-limit 1 --retry 2 -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' %s %s", UA, cookie, url1))
		if data and json.parse(data) and json.parse(data).data and json.parse(data).data.attributes and json.parse(data).data.attributes.currentLocationSovereignTerritory then
			region = string.upper(json.parse(data).data.attributes.currentLocationTerritory) or string.upper(json.parse(data).data.attributes.currentLocationSovereignTerritory)
			if region then
				status = 2
				if fs.isfile(string.format("/tmp/openclash_%s_region", type)) then
					old_region = fs.readfile(string.format("/tmp/openclash_%s_region", type))
				end
				if not datamatch(region, regex) then
					status = 3
				elseif old_region and region ~= old_region and not all_test then
					status = 4
				end
				if status == 2 and not all_test and region ~= old_region then
					fs.writefile(string.format("/tmp/openclash_%s_region", type), region)
				end
	  			return region
	  		end
		end
	end
end

function bilibili_unlock_test()
	status = 0
	local randsession = luci.sys.exec("cat /dev/urandom | head -n 32 | md5sum | head -c 32")
	local region, httpcode, data, url
	local regex = uci:get("openclash", "config", "stream_auto_select_region_key_bilibili") or ""
	if regex == "HK/MO/TW" then
		url = string.format("https://api.bilibili.com/pgc/player/web/playurl?avid=18281381&cid=29892777&qn=0&type=&otype=json&ep_id=183799&fourk=1&fnver=0&fnval=16&session=%s&module=bangumi", randsession)
		region = "HK/MO/TW"
	elseif regex == "TW" then
		url = string.format("https://api.bilibili.com/pgc/player/web/playurl?avid=50762638&cid=100279344&qn=0&type=&otype=json&ep_id=268176&fourk=1&fnver=0&fnval=16&session=%s&module=bangumi", randsession)
		region = "TW"
	elseif regex == "CN" then
		url = string.format("https://api.bilibili.com/pgc/player/web/playurl?avid=82846771&qn=0&type=&otype=json&ep_id=307247&fourk=1&fnver=0&fnval=16&session=%s&module=bangumi", randsession)
		region = "CN"
	end
	httpcode = luci.sys.exec(string.format("curl -sL --connect-timeout 5 -m 10 --speed-time 5 --speed-limit 1 --retry 2 -o /dev/null -w %%{http_code} -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' '%s'", UA, url))
	if httpcode and tonumber(httpcode) == 200 then
		data = luci.sys.exec(string.format("curl -sL --connect-timeout 5 -m 10 --speed-time 5 --speed-limit 1 --retry 2 -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' '%s'", UA, url))
		if data then
			data = json.parse(data)
			status = 1
			if data.code then
				if data.code == 0 then
					status = 2
					if fs.isfile(string.format("/tmp/openclash_%s_region", type)) then
						old_region = fs.readfile(string.format("/tmp/openclash_%s_region", type))
					end
					if old_region and region ~= old_region and not all_test then
						status = 4
					end
					if status == 2 and not all_test and region ~= old_region then
						fs.writefile(string.format("/tmp/openclash_%s_region", type), region)
					end
					return region
				end
			end
		end
	end
end

unlock_auto_select()