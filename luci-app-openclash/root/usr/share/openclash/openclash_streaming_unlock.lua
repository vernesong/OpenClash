#!/usr/bin/lua

-- Probe status:
-- 0 = reset / not tested
-- 1 = reachable
-- 2 = unlocked & region matches
-- 3 = unlocked but region regex mismatch
-- 4 = unlocked but region differs from cached old_region but not unlocked

local SYS = require "luci.sys"
local HTTP = require "luci.http"
local FS = require "luci.openclash"
local JSON = require "luci.jsonc"
local UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
local class_type = type
local type = arg[1]
local all_test = arg[2] == "all"
math.randomseed(os.time())
local status, ip, port, passwd, group_match_name
local tested_set = {}
local proxy_index = {}
local group_set = {}
local config_cache = {}
local unlock_cache_file = "/etc/openclash/history/streaming_unlock_cache"
local unlock_cache_info = {}

-- MSG holds every fixed log fragment. Fragments outside the 【】 markers are
-- translated through exact msgid matches by luci-app-openclash trans_line, so
-- wording and spacing must stay byte-identical with the po files.
local MSG = {
	info = " [Info] ",
	error = " [Error] ",

	err_no_type = "Streaming Unlock Has No Parameter of Type, Exiting...",
	err_router_self_proxy = "Streaming Unlock Could not Work Because of Router-Self Proxy Disabled, Exiting...",
	err_multiple_scripts = "Multiple Scripts Running, Exiting...",
	err_network = "Network Anomaly, Suspend Unlock Detection...",

	no_group_find = "failed to search based on keywords and automatically obtain the group, please confirm the validity of the regex!",

	full_support = "full support, area:",
	full_support_no_area = "full support",
	area = ", area:",

	only_original = "only support homemade!",
	no_unlock = "not support unlock!",
	test_failed = "unlock test failed!",

	select_success = "unlock node auto selected successfully, the current selected is",
	select_failed = "unlock node auto selected failed, no node available, rolled back to the",
	select_failed_other_region = "unlock node auto selected failed, no node match the regex, rolled back to other full support node",
	select_success_no_old_region = "unlock node auto selected successfully, no node match the old region, rolled back to other full support node",
	select_all_full_support = "unlock node test finished, rolled back to the full support node",
	select_all_other_region = "unlock node test finished, no node match the regex, rolled back to other full support node",
	select_all_no_old_region = "unlock node test finished, no node match the old region, rolled back to other full support node",
	select_all_failed = "unlock node test finished, no node available, rolled back to the",

	original_no_select = "only support homemade! the type of group is not select, auto select could not work!",
	no_unlock_no_select = "not support unlock! the type of group is not select, auto select could not work!",
	failed_no_select = "unlock test failed! the type of group is not select, auto select could not work!",

	original_test_start = "only support homemade! start auto select unlock proxy...",
	no_unlock_test_start = "not support unlock! start auto select unlock proxy...",
	failed_test_start = "unlock test failed! start auto select unlock proxy...",

	other_region_unlock_test = ", but not match the regex!",
	other_region_unlock_test_start = ", but not match the regex! start auto select unlock proxy...",
	other_region_unlock_no_select = ", but not match the regex! the type of group is not select, auto select could not work!",

	no_old_region_unlock_test = "full support but not match the old region!",
	no_old_region_unlock_old_region = ", but not match the old region:",
	no_old_region_unlock_old_region_no_select = ", the type of group is not select, auto select could not work!",
	no_old_region_unlock_no_select = "but not match the old region! the type of group is not select, auto select could not work!",

	no_nodes_filter = "no nodes name match the regex!",

	cached_nodes = "Cached Compliant Nodes Number:",
	cached_nodes_excluded = ", Cached Non-compliant Nodes Number:",
	cached_nodes_priority = ", Prioritize Testing With Cached Compliant Nodes...",
}

local function log_prefix()
	return os.date("%Y-%m-%d %H:%M:%S")..MSG.info
end

local function log_info(text)
	print(log_prefix()..text)
end

local function log_error(text)
	print(os.date("%Y-%m-%d %H:%M:%S")..MSG.error..text)
end

local function get_config(key)
	if key == nil then
		return nil
	end
	local value = config_cache[key]
	if value == nil then
		value = FS.uci_get_config("config", key)
		if value == nil then
			value = false
		end
		config_cache[key] = value
	end
	if value == false then
		return nil
	end
	return value
end

local unlock_cache = FS.readfile(unlock_cache_file)
if unlock_cache then
	unlock_cache_info = JSON.parse(unlock_cache) or {}
end

if not type then
	log_error(MSG.err_no_type)
	os.exit(0)
end

MSG.group = "【"..type.."】Group:"

local self_status = SYS.exec(string.format('ps -w |grep -v grep |grep -c "openclash_streaming_unlock.lua %s"', type))
local select_logic = get_config("stream_auto_select_logic") or "urltest"

if (tonumber(get_config("router_self_proxy")) or 1) == 0 then
	log_error(MSG.err_router_self_proxy)
	os.exit(0)
elseif tonumber(self_status) > 1 then
	log_error(MSG.err_multiple_scripts)
	os.exit(0)
end

-- One row per streaming service: setting keys, connection sniff site and host.
local streams = {
	["Netflix"] = { group_key = "stream_auto_select_group_key_netflix", group_default = "netflix|奈飞", region_key = "stream_auto_select_region_key_netflix", node_key = "stream_auto_select_node_key_netflix", site = "https://www.netflix.com", host = "www%.netflix%.com" },
	["Disney Plus"] = { group_key = "stream_auto_select_group_key_disney", group_default = "disney|迪士尼", region_key = "stream_auto_select_region_key_disney", node_key = "stream_auto_select_node_key_disney", site = "https://www.disneyplus.com", host = "www%.disneyplus%.com" },
	["HBO Max"] = { group_key = "stream_auto_select_group_key_hbo_max", group_default = "hbo|hbomax|hbo max", region_key = "stream_auto_select_region_key_hbo_max", node_key = "stream_auto_select_node_key_hbo_max", site = "https://www.max.com", host = "www%.max%.com" },
	["YouTube Premium"] = { group_key = "stream_auto_select_group_key_ytb", group_default = "youtobe|油管", region_key = "stream_auto_select_region_key_ytb", node_key = "stream_auto_select_node_key_ytb", site = "https://m.youtube.com/premium", host = "m%.youtube%.com" },
	["TVB Anywhere+"] = { group_key = "stream_auto_select_group_key_tvb_anywhere", group_default = "tvb", region_key = "stream_auto_select_region_key_tvb_anywhere", node_key = "stream_auto_select_node_key_tvb_anywhere", site = "https://www.tvbanywhere.com/img/tvb/vip_purchase.png", host = "www%.tvbanywhere%.com" },
	["Amazon Prime Video"] = { group_key = "stream_auto_select_group_key_prime_video", group_default = "prime video|amazon", region_key = "stream_auto_select_region_key_prime_video", node_key = "stream_auto_select_node_key_prime_video", site = "https://www.primevideo.com", host = "www%.primevideo%.com" },
	["DAZN"] = { group_key = "stream_auto_select_group_key_dazn", group_default = "dazn", region_key = "stream_auto_select_region_key_dazn", node_key = "stream_auto_select_node_key_dazn", site = "https://www.dazn.com", host = "www%.dazn%.com" },
	["Paramount Plus"] = { group_key = "stream_auto_select_group_key_paramount_plus", group_default = "paramount", region_key = "stream_auto_select_region_key_paramount_plus", node_key = "stream_auto_select_node_key_paramount_plus", site = "https://www.paramountplus.com/", host = "www%.paramountplus%.com" },
	["Discovery Plus"] = { group_key = "stream_auto_select_group_key_discovery_plus", group_default = "discovery", region_key = "stream_auto_select_region_key_discovery_plus", node_key = "stream_auto_select_node_key_discovery_plus", site = "https://www.discoveryplus.com/", host = "www%.discoveryplus%.com" },
	["Bilibili"] = { group_key = "stream_auto_select_group_key_bilibili", group_default = "bilibili", region_key = "stream_auto_select_region_key_bilibili", node_key = "stream_auto_select_node_key_bilibili", site = "https://www.bilibili.com/", host = "www%.bilibili%.com" },
	["Google"] = { group_key = "stream_auto_select_group_key_google_not_cn", group_default = "google|谷歌", node_key = "stream_auto_select_node_key_google_not_cn", site = "https://timeline.google.com", host = "timeline%.google%.com" },
	["OpenAI"] = { group_key = "stream_auto_select_group_key_openai", group_default = "OpenAI|ChatGPT", region_key = "stream_auto_select_region_key_openai", node_key = "stream_auto_select_node_key_openai", site = "https://chatgpt.com/", host = "chatgpt%.com" },
	["Claude"] = { group_key = "stream_auto_select_group_key_claude", group_default = "Claude", region_key = "stream_auto_select_region_key_claude", node_key = "stream_auto_select_node_key_claude", site = "https://claude.ai/", host = "claude%.ai" },
	["Gemini"] = { group_key = "stream_auto_select_group_key_gemini", group_default = "Gemini", region_key = "stream_auto_select_region_key_gemini", node_key = "stream_auto_select_node_key_gemini", site = "https://gemini.google.com/", host = "gemini%.google%.com" },
}

local function stream_config(field)
	local stream = streams[type]
	return stream and stream[field]
end

local function get_region_regex()
	return get_config(stream_config("region_key"))
end

local function get_node_regex()
	return get_config(stream_config("node_key")) or ""
end

-- Pattern fast path: ASCII-only case folding matches ruby /i exactly, and CJK/symbol
-- code points (>= U+3000) are case-invariant, so those patterns can be matched literally.
local function has_case_mapping(text)
	local i = 1
	while i <= #text do
		local b = text:byte(i)
		local code
		if b < 0x80 then
			code = b
			i = i + 1
		elseif b >= 0xF0 then
			local b1, b2, b3 = text:byte(i + 1), text:byte(i + 2), text:byte(i + 3)
			if not (b1 and b2 and b3) then
				return true
			end
			code = (b % 0x08) * 0x40000 + (b1 % 0x40) * 0x1000 + (b2 % 0x40) * 0x40 + b3 % 0x40
			i = i + 4
		elseif b >= 0xE0 then
			local b1, b2 = text:byte(i + 1), text:byte(i + 2)
			if not (b1 and b2) then
				return true
			end
			code = (b % 0x10) * 0x1000 + (b1 % 0x40) * 0x40 + b2 % 0x40
			i = i + 3
		elseif b >= 0xC0 then
			local b1 = text:byte(i + 1)
			if not b1 then
				return true
			end
			code = (b % 0x20) * 0x40 + b1 % 0x40
			i = i + 2
		else
			return true
		end
		if code >= 0x80 and (code < 0x3000 or (code >= 0xFF00 and code <= 0xFFEF)) then
			return true
		end
	end
	return false
end

local regex_meta = { ".", "^", "$", "*", "+", "?", "(", ")", "[", "]", "{", "}", "\\" }

local function build_plain_pattern(regex)
	local first = regex:sub(1, 1)
	local last = regex:sub(-1)
	if first == "^" and last == "$" and #regex > 2 then
		local inner = regex:sub(2, -2)
		if inner ~= "" and not inner:find("|", 1, true) then
			local ok = true
			for _, meta in ipairs(regex_meta) do
				if inner:find(meta, 1, true) then
					ok = false
					break
				end
			end
			if ok and not has_case_mapping(inner) then
				return { exact = string.lower(inner) }
			end
		end
		return nil
	end
	if first == "|" or last == "|" or regex:find("||", 1, true) then
		return nil
	end
	for _, meta in ipairs(regex_meta) do
		if regex:find(meta, 1, true) then
			return nil
		end
	end
	if has_case_mapping(regex) then
		return nil
	end
	local parts = {}
	for part in regex:gmatch("[^|]+") do
		parts[#parts + 1] = string.lower(part)
	end
	return { parts = parts }
end

local pattern_cache = {}

local function shell_quote(value)
	return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function datamatch(data, regex)
	if not data or not regex then
		return false
	end
	if regex == "" then
		return true
	end
	local pattern = pattern_cache[regex]
	if pattern == nil then
		pattern = build_plain_pattern(regex) or false
		pattern_cache[regex] = pattern
	end
	if pattern then
		if pattern.exact then
			for line in (string.lower(data) .. "\n"):gmatch("([^\n]*)\n") do
				if line == pattern.exact then
					return true
				end
			end
			return false
		end
		local target = string.lower(data)
		for i = 1, #pattern.parts do
			if target:find(pattern.parts[i], 1, true) then
				return true
			end
		end
		return false
	end
	local result = SYS.exec(string.format("OC_MATCH_TARGET=%s OC_MATCH_PATTERN=%s ruby -E UTF-8 -e 'print((ENV[\"OC_MATCH_TARGET\"] =~ Regexp.new(ENV[\"OC_MATCH_PATTERN\"], Regexp::IGNORECASE)) ? \"true\" : \"false\")'", shell_quote(data), shell_quote(regex)))
	return result == "true"
end

local function get_cache_value(key, stream_type)
	local entry = unlock_cache_info[stream_type or type]
	local value = entry and entry[key]
	if value == nil or value == false then
		return ""
	end
	return value
end

local function get_old_region(stream_type)
	return get_cache_value("old_region", stream_type)
end

local function get_old_regex(stream_type)
	return get_cache_value("old_regex", stream_type)
end

local function write_cache(stream_type, node, value)
	if not value then
		value = ""
	end
	if not unlock_cache_info[stream_type] then
		unlock_cache_info[stream_type] = {}
	end
	unlock_cache_info[stream_type][node] = value
end

local function delete_cache(stream_type, node)
	if unlock_cache_info[stream_type] and unlock_cache_info[stream_type][node] then
		unlock_cache_info[stream_type][node] = nil
	end
end

local function is_group(name)
	return name ~= nil and group_set[name] == true
end

local function is_tested(name)
	return name ~= nil and tested_set[name] == true
end

local function mark_tested(name)
	if name ~= nil then
		tested_set[name] = true
	end
end

local function build_proxy_index(info)
	proxy_index = {}
	group_set = {}
	for _, value in pairs(info.proxies) do
		proxy_index[value.name] = value
		if value.all then
			group_set[value.name] = true
		end
	end
end

local function get_group_now(group)
	local now
	local name = group
	local visited = {}
	while group_set[name] and not visited[name] do
		visited[name] = true
		local value = proxy_index[name]
		if not value then
			break
		end
		now = value.now
		name = value.now
	end
	return now or group
end

local function get_proxy(group, name)
	--group maybe a proxy
	local ctx = { show = "", name = "", now = nil, type = nil, nodes = {} }
	local expand_group = tonumber(get_config("stream_auto_select_expand_group")) or 0

	if expand_group == 1 then
		if group_set[group] then
			local visited = {}
			while group_set[group] and not visited[group] do
				visited[group] = true
				local value = proxy_index[group]
				if not value then
					break
				end
				if ctx.show ~= "" then
					ctx.show = ctx.show .. " ➟ " .. group
				else
					if name == group then
						ctx.show = group
					else
						ctx.show = name .. " ➟ " .. group
					end
				end
				ctx.name = group
				group = value.now
				ctx.now = value.now or ctx.name
				ctx.nodes = value.all
				ctx.type = value.type
			end
			if ctx.type ~= "Selector" then
				local value = proxy_index[name]
				if value then
					ctx.name = name
					ctx.nodes = {}
					table.insert(ctx.nodes, group)
				end
			end
		else
			local value = proxy_index[name]
			if value then
				ctx.show = name
				ctx.name = name
				ctx.now = value.now or name
				table.insert(ctx.nodes, group)
				ctx.type = value.type
			end
		end
	else
		if group_set[group] then
			local value = proxy_index[name]
			if value then
				ctx.name = name
				table.insert(ctx.nodes, group)
				ctx.type = value.type
			end
			local visited = {}
			while group_set[group] and not visited[group] do
				visited[group] = true
				local target = proxy_index[group]
				if not target then
					break
				end
				if ctx.show ~= "" then
					ctx.show = ctx.show .. " ➟ " .. group
				else
					if name == group then
						ctx.show = group
					else
						ctx.show = name .. " ➟ " .. group
					end
				end
				ctx.now = target.now or group
				group = target.now
			end
		else
			local value = proxy_index[name]
			if value then
				table.insert(ctx.nodes, group)
				ctx.now = value.now or name
				ctx.show = name
				ctx.name = name
				ctx.type = value.type
			end
		end
	end
	return ctx
end

local function nodes_filter(t)
	if t == nil then
		return
	end
	local tab = {}
	local regex = get_node_regex()

	if class_type(t) == "table" then
		if regex == "" then
			return t
		end
		for n = 1, #t do
			if is_group(t[n]) then
				if datamatch(get_group_now(t[n]), regex) then
					table.insert(tab, t[n])
				end
			elseif datamatch(t[n], regex) then
				table.insert(tab, t[n])
			end
		end
	else
		if regex == "" then
			table.insert(tab, t)
			return tab
		end
		if is_group(t) then
			if datamatch(get_group_now(t), regex) then
				table.insert(tab, t)
			end
		elseif datamatch(t, regex) then
			table.insert(tab, t)
		end
	end
	return tab
end

local function urlencode(data)
	if not data then
		return
	end
	return HTTP.urlencode(data) or data
end

local function table_rand(t, d)
	if t == nil then
		return
	end
	local tab = {}
	while #t ~= 0 do
		local n = math.random(0, #t)
		if t[n] ~= nil then
			if type == "YouTube Premium" and get_old_region("Google") == t[n] then
				table.insert(tab, 1, t[n])
			elseif d ~= nil and is_group(d) and d == t[n] then
				table.insert(tab, 1, t[n])
			else
				table.insert(tab, t[n])
			end
			table.remove(t, n)
		end
	end
	return tab
end

local function table_sort_by_urltest(t, d)
	local tab = {}
	local result = {}

	if t == nil then
		return
	end

	local providers = SYS.exec(string.format('curl -sL -m 5 --retry 2 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XGET http://%s:%s/providers/proxies', passwd, ip, port))
	if providers then
		providers = JSON.parse(providers)
		if not providers or not providers.providers then return t end
	end

	-- Provider nodes are not listed by /proxies, their delay history comes from /providers/proxies,
	-- while inline nodes and groups carry their own history in the /proxies snapshot.
	local delay_map = {}
	for name, proxy in pairs(proxy_index) do
		if proxy.history and #(proxy.history) ~= 0 and proxy.history[#(proxy.history)].delay ~= 0 then
			delay_map[name] = proxy.history[#(proxy.history)].delay
		end
	end
	for _, provider in pairs(providers.providers) do
		if provider.proxies and provider.name ~= "default" then
			for _, proxy in pairs(provider.proxies) do
				if delay_map[proxy.name] == nil and proxy.history and #(proxy.history) ~= 0 and proxy.history[#(proxy.history)].delay ~= 0 then
					delay_map[proxy.name] = proxy.history[#(proxy.history)].delay
				end
			end
		end
	end

	local delay_url
	local urltest_address_mod = get_config("urltest_address_mod")
	if urltest_address_mod and urltest_address_mod ~= "0" then
		delay_url = urltest_address_mod
	else
		delay_url = "http://www.gstatic.com/generate_204"
	end

	for n = 1, #(t) do
		local delay = delay_map[t[n]]
		if not delay and (is_group(t[n]) or t[n] == "DIRECT") then
			local group_delay = SYS.exec(string.format('curl -sL -m 60 --retry 2 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XGET "http://%s:%s/proxies/%s/delay?timeout=5000&url=%s"', passwd, ip, port, urlencode(t[n]), urlencode(delay_url)))
			if group_delay then
				group_delay = JSON.parse(group_delay)
			end
			if group_delay and group_delay.delay and group_delay.delay ~= 0 then
				delay = group_delay.delay
			end
		end
		table.insert(tab, {t[n], delay or 123456})
	end

	table.sort(tab, function(a, b)
		return a[2] < b[2]
	end)

	for _, value in ipairs(tab) do
		if type == "YouTube Premium" and get_old_region("Google") == value[1] then
			table.insert(result, 1, value[1])
		elseif d ~= nil and is_group(d) and d == value[1] then
			table.insert(result, 1, value[1])
		else
			table.insert(result, value[1])
		end
	end
	return result
end

local function table_sort_by_cache(t)
	local tab = {}
	local tab_b = {}
	local old_region = get_old_region()
	for n = 1, #(t) do
		if unlock_cache_info and unlock_cache_info[type] and unlock_cache_info[type][t[n]] and unlock_cache_info[type][t[n]] == old_region then
			table.insert(tab, t[n])
		else
			table.insert(tab_b, t[n])
		end
	end
	if #tab > 0 then
		print(log_prefix().."【"..group_match_name.."】"..MSG.cached_nodes.."【"..#(tab).."】"..MSG.cached_nodes_excluded.."【"..#(tab_b).."】"..MSG.cached_nodes_priority)
	end
	for _, v in ipairs(tab_b) do table.insert(tab, v) end
	return tab
end

local function set_selected(group, node)
	SYS.exec(string.format("curl -sL -m 5 --retry 2 -w %%{http_code} -o /dev/null -H 'Authorization: Bearer %s' -H 'Content-Type:application/json' -X PUT -d '{\"name\":\"%s\"}' http://%s:%s/proxies/%s", passwd, node, ip, port, urlencode(group)))
end

local function get_auth_info()
	port = get_config("cn_port")
	passwd = get_config("dashboard_password") or ""
	ip = FS.lanip(true)
	if not ip or not port then
		os.exit(0)
	end
end

local function close_connections()
	local enable = tonumber(get_config("stream_auto_select_close_con")) or 1
	if enable == 0 then return end
	local con = SYS.exec(string.format('curl -sL -m 5 --retry 2 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XGET http://%s:%s/connections', passwd, ip, port))
	if con then
		con = JSON.parse(con)
	end
	if not con or not con.connections then
		return
	end
	local group_cons_id = {}
	for i = 1, #(con.connections) do
		local chains = con.connections[i].chains
		if chains and #chains ~= 0 and chains[#chains] == group_match_name then
			table.insert(group_cons_id, (con.connections[i].id))
		end
	end
	--close connections
	for i = 1, #(group_cons_id) do
		SYS.exec(string.format('curl -sL -m 5 --retry 2 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -X DELETE http://%s:%s/connections/%s >/dev/null 2>&1 &', passwd, ip, port, group_cons_id[i]))
	end
end

local function finish_region_test(region, regex, old_region, old_regex)
	if not datamatch(region, regex) then
		status = 3
	elseif old_regex ~= regex and not all_test then
		status = 2
	elseif old_region ~= "" and region ~= old_region and not all_test then
		status = 4
	end
	if status == 2 and not all_test and region ~= old_region then
		write_cache(type, "old_region", region)
	end
	if status == 2 and not all_test and regex ~= old_regex then
		write_cache(type, "old_regex", regex)
	end
end

-- The service probes are defined at the end of the file, the entries below resolve them at call time
local netflix_unlock_test, disney_unlock_test, hbo_max_unlock_test, ytb_unlock_test,
	tvb_anywhere_unlock_test, prime_video_unlock_test, dazn_unlock_test, paramount_plus_unlock_test,
	discovery_plus_unlock_test, bilibili_unlock_test, google_not_cn_test, openai_unlock_test,
	claude_unlock_test, gemini_unlock_test

local unlock_tests = {
	["Netflix"] = function(tested) return netflix_unlock_test(tested) end,
	["Disney Plus"] = function(tested) return disney_unlock_test(tested) end,
	["HBO Max"] = function(tested) return hbo_max_unlock_test(tested) end,
	["YouTube Premium"] = function(tested) return ytb_unlock_test(tested) end,
	["TVB Anywhere+"] = function(tested) return tvb_anywhere_unlock_test(tested) end,
	["Amazon Prime Video"] = function(tested) return prime_video_unlock_test(tested) end,
	["DAZN"] = function(tested) return dazn_unlock_test(tested) end,
	["Paramount Plus"] = function(tested) return paramount_plus_unlock_test(tested) end,
	["Discovery Plus"] = function(tested) return discovery_plus_unlock_test(tested) end,
	["Bilibili"] = function(tested) return bilibili_unlock_test(tested) end,
	["Google"] = function(tested) return google_not_cn_test(tested) end,
	["OpenAI"] = function(tested) return openai_unlock_test(tested) end,
	["Claude"] = function(tested) return claude_unlock_test(tested) end,
	["Gemini"] = function(tested) return gemini_unlock_test(tested) end,
}

local function proxy_unlock_test(tested)
	local unlock_test = unlock_tests[type]
	if not unlock_test then
		return ""
	end
	return unlock_test(tested)
end

local function get_sniffed_group(host)
	local con = SYS.exec(string.format('curl -sL -m 5 --retry 2 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XGET http://%s:%s/connections', passwd, ip, port))
	if con then
		con = JSON.parse(con)
	end
	if not con or not con.connections then
		return nil
	end
	for i = 1, #(con.connections) do
		local metadata = con.connections[i].metadata
		if metadata and metadata.host and string.match(metadata.host, host) then
			return con.connections[i].chains[#(con.connections[i].chains)]
		end
	end
end

local function auto_get_policy_group()
	local site = stream_config("site")
	local host = stream_config("host")
	if not site then
		return
	end
	SYS.call(string.format('curl -sL -m 5 --limit-rate 1k -o /dev/null %s &', site))
	local group = get_sniffed_group(host)
	if not group then
		os.execute("sleep 1")
		group = get_sniffed_group(host)
	end
	return group
end

local function load_proxies()
	local info = SYS.exec(string.format('curl -sL -m 5 --retry 2 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XGET http://%s:%s/proxies', passwd, ip, port))
	if info then
		info = JSON.parse(info)
		if not info or not info.proxies then os.exit(0) end
	end
	--save group name
	build_proxy_index(info)
	return info
end

--try to get group instead of matching the key
local function build_key_group(auto_get_group)
	if auto_get_group then
		return "^" .. auto_get_group .. "$"
	end
	local key_group = get_config(stream_config("group_key")) or stream_config("group_default")
	if not key_group then
		key_group = type
	end
	return key_group
end

local function test_matched_group(value, job)
	--get groups info
	group_match_name = value.name
	local ctx = get_proxy(value.name, value.name)
	mark_tested(ctx.now)
	--test now proxy
	local region = proxy_unlock_test(ctx.now)
	if is_group(ctx.now) then
		job.now = log_prefix()..MSG.group.."【"..ctx.show.."】"
	else
		job.now = log_prefix()..MSG.group.."【"..ctx.show.." ➟ "..ctx.now.."】"
	end
	if status ~= 2 and status ~= 4 then
		region = proxy_unlock_test(ctx.now)
	end
	local group_node = get_group_now(value.now)
	if status == 2 or status == 4 then
		if region ~= "" then
			table.insert(job.full_support, {value.now, value.now, group_node, region})
			print(job.now..MSG.full_support.."【"..region.."】")
			write_cache(type, group_node, region)
		else
			table.insert(job.full_support, {value.now, value.now, group_node})
			print(job.now..MSG.full_support_no_area)
			write_cache(type, group_node)
		end
		if all_test or #nodes_filter(ctx.now) == 0 then
			status = 0
			return false
		end
		if status == 4 then
			status = 2
			if region ~= "" then
				write_cache(type, "old_region", region)
			end
		end
		if status == 2 and type == "Google" then
			write_cache(type, "old_region", ctx.now)
		end
		return true
	elseif status == 3 then
		if region ~= "" then
			table.insert(job.other_region, {value.now, value.now, group_node, region})
			write_cache(type, group_node, region)
		else
			table.insert(job.other_region, {value.now, value.now, group_node})
			write_cache(type, group_node)
		end
		if not all_test then
			if region ~= "" then
				print(job.now..MSG.full_support.."【"..region.."】"..MSG.other_region_unlock_test_start)
			else
				print(job.now..MSG.full_support_no_area..MSG.other_region_unlock_test_start)
			end
		else
			if region ~= "" then
				print(job.now..MSG.full_support.."【"..region.."】"..MSG.other_region_unlock_test)
			else
				print(job.now..MSG.full_support_no_area..MSG.other_region_unlock_test)
			end
		end
		return false
	elseif status == 1 then
		table.insert(job.original, {value.now, value.now, group_node})
		if not all_test then
			if type == "Netflix" then
				print(job.now..MSG.original_test_start)
			else
				print(job.now..MSG.no_unlock_test_start)
			end
		else
			if type == "Netflix" then
				print(job.now..MSG.only_original)
			else
				print(job.now..MSG.no_unlock)
			end
		end
		delete_cache(type, group_node)
		return false
	else
		if not all_test then
			print(job.now..MSG.failed_test_start)
		else
			print(job.now..MSG.test_failed)
		end
		return false
	end
end

local function test_candidate(value, job, nctx, candidate, pnode)
	--skip tested proxy
	local pnode_now = get_group_now(pnode)
	if is_tested(pnode_now) then
		return
	end
	mark_tested(pnode)
	if pnode == "REJECT" or pnode == "REJECT-DROP" or pnode == "PASS" or pnode_now == "REJECT" or pnode_now == "REJECT-DROP" or pnode_now == "PASS" then
		return
	end
	local now
	if is_group(pnode) then
		now = log_prefix()..MSG.group.."【"..nctx.show.." ➟ "..pnode_now.."】"
	else
		now = log_prefix()..MSG.group.."【"..nctx.show.." ➟ "..pnode.."】"
	end
	set_selected(nctx.name, pnode)
	local region = proxy_unlock_test(pnode_now)
	if status == 2 then
		if region ~= "" then
			table.insert(job.full_support, {candidate, nctx.name, pnode, region})
			if not all_test then
				print(now..MSG.full_support.."【"..region.."】")
				print(log_prefix()..MSG.group.."【"..value.name.."】"..MSG.select_success.."【"..pnode.."】"..MSG.area.."【"..region.."】")
			else
				print(now..MSG.full_support.."【"..region.."】")
			end
			write_cache(type, pnode, region)
		else
			table.insert(job.full_support, {candidate, nctx.name, pnode})
			if not all_test then
				print(now..MSG.full_support_no_area)
				print(log_prefix()..MSG.group.."【"..value.name.."】"..MSG.select_success.."【"..pnode.."】")
			else
				print(now..MSG.full_support_no_area)
			end
			write_cache(type, pnode)
		end
	elseif status == 3 then
		if region ~= "" then
			table.insert(job.other_region, {candidate, nctx.name, pnode, region})
			print(now..MSG.full_support.."【"..region.."】"..MSG.other_region_unlock_test)
			write_cache(type, pnode, region)
		else
			table.insert(job.other_region, {candidate, nctx.name, pnode})
			print(now..MSG.full_support_no_area..MSG.other_region_unlock_test)
			write_cache(type, pnode)
		end
	elseif status == 4 then
		if region ~= "" then
			table.insert(job.no_old_region, {candidate, nctx.name, pnode, region})
			print(now..MSG.full_support.."【"..region.."】"..MSG.no_old_region_unlock_old_region.."【"..job.old_region.."】")
			write_cache(type, pnode, region)
		else
			table.insert(job.no_old_region, {candidate, nctx.name, pnode})
			print(now..MSG.no_old_region_unlock_test)
			write_cache(type, pnode)
		end
	elseif status == 1 then
		table.insert(job.original, {candidate, nctx.name, pnode})
		if type == "Netflix" then
			print(now..MSG.only_original)
		else
			print(now..MSG.no_unlock)
		end
		delete_cache(type, pnode)
	else
		print(now..MSG.test_failed)
	end
end

local function test_selector_nodes(value, job, nctx, candidate)
	for p = 1, #(nctx.nodes) do
		local pnode = nctx.nodes[p]
		test_candidate(value, job, nctx, candidate, pnode)
		if status == 2 and not all_test then
			break
		elseif p == #(nctx.nodes) and #(nctx.nodes) ~= 1 then
			set_selected(nctx.name, nctx.now)
		end
	end
end

local function test_expand_candidate(value, job, nctx, candidate)
	--only group expand
	set_selected(nctx.name, candidate)
	if is_tested(nctx.now) or #nodes_filter(nctx.now) == 0 then
		return
	end
	mark_tested(nctx.now)
	local expand_now = get_group_now(nctx.now)
	local region = proxy_unlock_test(expand_now)
	local now
	if is_group(nctx.now) then
		now = log_prefix()..MSG.group.."【"..nctx.show.."】"
	else
		now = log_prefix()..MSG.group.."【"..nctx.show.." ➟ "..nctx.now.."】"
	end
	if status == 2 then
		if region ~= "" then
			table.insert(job.full_support, {candidate, nctx.name, candidate, region})
			if not all_test then
				print(now..MSG.full_support.."【"..region.."】")
				print(log_prefix()..MSG.group.."【"..value.name.."】"..MSG.select_success.."【"..expand_now.."】"..MSG.area.."【"..region.."】")
			else
				print(now..MSG.full_support.."【"..region.."】")
			end
			write_cache(type, candidate, region)
		else
			table.insert(job.full_support, {candidate, nctx.name, candidate})
			if not all_test then
				print(now..MSG.full_support_no_area)
				print(log_prefix()..MSG.group.."【"..value.name.."】"..MSG.select_success.."【"..expand_now.."】")
			else
				print(now..MSG.full_support_no_area)
			end
			write_cache(type, candidate)
		end
	elseif status == 3 then
		if region ~= "" then
			table.insert(job.other_region, {candidate, nctx.name, candidate, region})
			print(now..MSG.full_support.."【"..region.."】"..MSG.other_region_unlock_no_select)
			write_cache(type, candidate, region)
		else
			table.insert(job.other_region, {candidate, nctx.name, candidate})
			print(now..MSG.full_support_no_area..MSG.other_region_unlock_no_select)
			write_cache(type, candidate)
		end
	elseif status == 4 then
		if region ~= "" then
			table.insert(job.no_old_region, {candidate, nctx.name, candidate, region})
			print(now..MSG.full_support.."【"..region.."】"..MSG.no_old_region_unlock_old_region.."【"..job.old_region.."】"..MSG.no_old_region_unlock_old_region_no_select)
			write_cache(type, candidate, region)
		else
			table.insert(job.no_old_region, {candidate, nctx.name, candidate})
			print(now..MSG.full_support_no_area..MSG.no_old_region_unlock_no_select)
			write_cache(type, candidate)
		end
	elseif status == 1 then
		table.insert(job.original, {candidate, nctx.name, candidate})
		if type == "Netflix" then
			print(now..MSG.original_no_select)
		else
			print(now..MSG.no_unlock_no_select)
		end
		delete_cache(type, candidate)
	else
		print(now..MSG.failed_no_select)
	end
end

local function apply_fallback_select(value, job)
	local fallback_select
	if #job.full_support > 0 then
		fallback_select = job.full_support
	elseif #job.no_old_region > 0 then
		fallback_select = job.no_old_region
	elseif #job.other_region > 0 then
		fallback_select = job.other_region
	else
		fallback_select = job.original
	end
	for _, v in ipairs(fallback_select) do
		if #nodes_filter(v[3]) ~= 0 then
			if v[4] then
				table.insert(fallback_select, 1, {v[1], v[2], v[3], v[4]})
				write_cache(type, "old_region", v[4])
			else
				table.insert(fallback_select, 1, {v[1], v[2], v[3]})
			end
			break
		end
	end
	for _, v in ipairs(fallback_select) do
		set_selected(value.name, v[1])
		set_selected(v[2], v[3])
		local group_now
		if is_group(v[3]) then
			group_now = "【".. v[3] .. " ➟ " .. get_group_now(v[3]) .. "】"
		else
			group_now = "【".. v[3] .. "】"
		end
		if v[4] then
			group_now = group_now .. MSG.area.."【"..v[4].."】"
		end
		if #job.full_support > 0 then
			print(log_prefix()..MSG.group.."【"..value.name.."】"..MSG.select_all_full_support..group_now)
		elseif #job.no_old_region > 0 then
			if not all_test then
				print(log_prefix()..MSG.group.."【"..value.name.."】"..MSG.select_success_no_old_region..group_now)
			else
				print(log_prefix()..MSG.group.."【"..value.name.."】"..MSG.select_all_no_old_region..group_now)
			end
		elseif #job.other_region > 0 then
			if not all_test then
				print(log_prefix()..MSG.group.."【"..value.name.."】"..MSG.select_failed_other_region..group_now)
			else
				print(log_prefix()..MSG.group.."【"..value.name.."】"..MSG.select_all_other_region..group_now)
			end
		else
			if not all_test then
				print(log_prefix()..MSG.group.."【"..value.name.."】"..MSG.select_failed..group_now)
			else
				print(log_prefix()..MSG.group.."【"..value.name.."】"..MSG.select_all_failed..group_now)
			end
		end
		close_connections()
		break
	end
end

local function find_new_unlock(value, job)
	if value.type ~= "Selector" then
		local node_now = get_group_now(value.name)
		if #nodes_filter(node_now) == 0 then
			return
		end
		local region = proxy_unlock_test(node_now)
		if status == 2 then
			if region ~= "" then
				if not all_test then
					print(job.now..MSG.full_support.."【"..region.."】")
				end
				print(log_prefix()..MSG.group.."【"..value.name.."】"..MSG.select_success.."【"..node_now.."】"..MSG.area.."【"..region.."】")
			else
				if not all_test then
					print(job.now..MSG.full_support_no_area)
				end
				print(log_prefix()..MSG.group.."【"..value.name.."】"..MSG.select_success.."【"..node_now.."】")
			end
		elseif status == 3 then
			if region ~= "" then
				print(job.now..MSG.full_support.."【"..region.."】"..MSG.other_region_unlock_no_select)
			else
				print(job.now..MSG.full_support_no_area..MSG.other_region_unlock_no_select)
			end
		elseif status == 4 then
			if region ~= "" then
				print(job.now..MSG.full_support.."【"..region.."】"..MSG.no_old_region_unlock_old_region.."【"..job.old_region.."】"..MSG.no_old_region_unlock_old_region_no_select)
			else
				print(job.now..MSG.full_support_no_area..MSG.no_old_region_unlock_no_select)
			end
		elseif status == 1 then
			if type == "Netflix" then
				print(job.now..MSG.original_no_select)
			else
				print(job.now..MSG.no_unlock_no_select)
			end
		else
			print(job.now..MSG.failed_no_select)
		end
		return
	end
	--save group current selected
	local proxy_default = value.now
	if not all_test then
		--filter nodes
		value.all = nodes_filter(value.all)
		if #value.all > 1 then
			if select_logic == "random" then
				--sort by random
				value.all = table_rand(value.all, proxy_default)
			else
				--sort by urltest
				value.all = table_sort_by_urltest(value.all, proxy_default)
			end
			--sort by cache
			value.all = table_sort_by_cache(value.all)
		end
	end
	if #(value.all) == 0 then
		log_info(MSG.group.."【"..value.name.."】"..MSG.no_nodes_filter)
		return
	end
	--loop proxy test
	for i = 1, #(value.all) do
		local candidate = value.all[i]
		if candidate ~= "REJECT" and candidate ~= "REJECT-DROP" and candidate ~= "PASS" then
			local nctx = get_proxy(candidate, value.name)
			if nctx.type == "Selector" then
				if nctx.name == candidate then
					set_selected(value.name, nctx.name)
				end
				if not all_test then
					--filter nodes
					nctx.nodes = nodes_filter(nctx.nodes)
					if #nctx.nodes > 1 then
						if select_logic == "random" then
							--sort by random
							nctx.nodes = table_rand(nctx.nodes)
						else
							--sort by urltest
							nctx.nodes = table_sort_by_urltest(nctx.nodes)
						end
						--sort by cache
						nctx.nodes = table_sort_by_cache(nctx.nodes)
					end
				end
				if #(nctx.nodes) == 0 then
					log_info(MSG.group.."【"..nctx.show.."】"..MSG.no_nodes_filter)
				else
					test_selector_nodes(value, job, nctx, candidate)
				end
			else
				test_expand_candidate(value, job, nctx, candidate)
			end
		end
		if status == 2 and not all_test then
			close_connections()
			break
		elseif i == #(value.all) and (#job.original > 0 or #job.other_region > 0 or #job.no_old_region > 0 or #job.full_support > 0) then
			apply_fallback_select(value, job)
		elseif i == #(value.all) then
			set_selected(value.name, proxy_default)
			local group_now
			if is_group(proxy_default) then
				group_now = value.name.." ➟ "..proxy_default.." ➟ "..get_group_now(proxy_default)
			else
				group_now = value.name.." ➟ "..proxy_default
			end
			print(log_prefix()..MSG.group.."【"..value.name.."】"..MSG.select_failed.."【"..group_now.."】")
		end
	end
end

local function unlock_auto_select()
	--Get ip port and password
	get_auth_info()

	local info = load_proxies()

	--try to get group instead of matching the key
	local auto_get_group = auto_get_policy_group()
	local key_group = build_key_group(auto_get_group)

	local job = {
		now = nil,
		old_region = get_old_region(),
		full_support = {},
		other_region = {},
		no_old_region = {},
		original = {},
	}
	local group_match = false
	for _, value in pairs(info.proxies) do
		--match only once
		if datamatch(value.name, key_group) then
			group_match = true
			if not test_matched_group(value, job) then
				--find new unlock
				find_new_unlock(value, job)
			end
		end
		if auto_get_group and group_match then break end
		if status == 2 and not all_test then break end
	end
	if not group_match and not auto_get_group then
		log_info(MSG.group.."【"..key_group.."】"..MSG.no_group_find)
	end
	--write cache
	FS.writefile(unlock_cache_file, JSON.stringify(unlock_cache_info))
end

local function response_code(data)
	local tag = string.match(data or "", "_TAG_%d+_TAG_")
	return tag and tonumber(string.sub(tag, 6, 8))
end

local function trace_region(data)
	local loc = string.match(data or "", "loc=%a+")
	if not loc then
		return nil
	end
	return string.upper(string.sub(loc, 5, -1))
end

-- Thanks https://github.com/lmc999/RegionRestrictionCheck --

function netflix_unlock_test()
	status = 0
	local filmId = 70143836
	local url = "https://www.netflix.com/title/"..filmId
	local headers = "User-Agent: "..UA
	local info = SYS.exec(string.format('curl -sLI --connect-timeout 5 -m 5 --speed-time 5 --speed-limit 1 --retry 2 -o /dev/null -w %%{json} -H "Content-Type: application/json" -H "host: www.netflix.com" -H "accept-language: en-US,en;q=0.9" -H "sec-ch-ua: Google Chrome;v=125, Chromium;v=125, Not.A/Brand;v=24" -H "sec-ch-ua-mobile: ?0" -H "sec-ch-ua-platform: Windows" -H "sec-fetch-site: none" -H "sec-fetch-mode: navigate" -H "sec-fetch-user: ?1" -H "sec-fetch-dest: document" -H "%s" -XGET %s', headers, url))
	local result = {}
	local region = ""
	local old_region = get_old_region()
	local old_regex = get_old_regex()
	local regex = get_region_regex() or ""
	if info then
		info = JSON.parse(info)
	end
	if info then
		if info.http_code == 200 then
			status = 2
			string.gsub(info.url_effective, '[^/]+', function(w) table.insert(result, w) end)
			if string.match(result[3], "^%a+") then
				region = string.upper(string.match(result[3], "^%a+"))
				if region == "TITLE" then
					region = "US"
				end
				finish_region_test(region, regex, old_region, old_regex)
			end
		elseif info.http_code == 404 or info.http_code == 403 then
			status = 1
		end
	end
	return region
end

function disney_unlock_test()
	status = 0
	local url = "https://disney.api.edge.bamgrid.com/devices"
	local url2 = "https://disney.api.edge.bamgrid.com/token"
	local url3 = "https://disney.api.edge.bamgrid.com/graph/v1/device/graphql"
	local headers = '-H "Accept-Language: en" -H "Content-Type: application/json" -H "authorization: ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84"'
	local auth = '-H "authorization: Bearer ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84"'
	local body = '{"query":"mutation registerDevice($input: RegisterDeviceInput!) { registerDevice(registerDevice: $input) { grant { grantType assertion } } }","variables":{"input":{"deviceFamily":"browser","applicationRuntime":"chrome","deviceProfile":"windows","deviceLanguage":"en","attributes":{"osDeviceIds":[],"manufacturer":"microsoft","model":null,"operatingSystem":"windows","operatingSystemVersion":"10.0","browserName":"chrome","browserVersion":"96.0.4606"}}}}'
	local region = ""
	local assertion, disneycookie
	local regex = get_region_regex() or ""
	local old_region = get_old_region()
	local old_regex = get_old_regex()

	local preassertion = SYS.exec(string.format("curl -sL --connect-timeout 5 -m 5 --speed-time 5 --speed-limit 1 --retry 2 %s -H 'User-Agent: %s' -H 'content-type: application/json; charset=UTF-8' -d '{\"deviceFamily\":\"browser\",\"applicationRuntime\":\"chrome\",\"deviceProfile\":\"windows\",\"attributes\":{}}' -XPOST %s", auth, UA, url))

	if preassertion then
		local preassertion_info = JSON.parse(preassertion)
		if preassertion_info then
			assertion = preassertion_info.assertion
		end
	end

	if not assertion then return region end

	disneycookie = "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Atoken-exchange&latitude=0&longitude=0&platform=browser&subject_token="..assertion.."&subject_token_type=urn%3Abamtech%3Aparams%3Aoauth%3Atoken-type%3Adevice"
	local tokencontent = SYS.exec(string.format("curl -sL --connect-timeout 5 -m 5 --speed-time 5 --speed-limit 1 --retry 2 %s -H 'User-Agent: %s' -d '%s' -XPOST %s", auth, UA, disneycookie, url2))

	if tokencontent then
		local token_info = JSON.parse(tokencontent)
		if token_info and token_info.error_description then
			status = 1
			return region
		end
	end

	local data = SYS.exec(string.format("curl -sL --connect-timeout 5 -m 5 --speed-time 5 --speed-limit 1 --retry 2 %s -H 'User-Agent: %s' -d '%s' -XPOST %s", headers, UA, body, url3))

	if data then
		data = JSON.parse(data)
		if data then
			status = 1
		end
	end
	if data and data.extensions and data.extensions.sdk and data.extensions.sdk.session and data.extensions.sdk.session.location and data.extensions.sdk.session.location.countryCode then
		region = data.extensions.sdk.session.location.countryCode
		local inSupportedLocation = data.extensions.sdk.session.inSupportedLocation or ""
		if region == "JP" then
			status = 2
			if not datamatch(region, regex) then
				status = 3
			elseif old_regex ~= regex and not all_test then
				status = 2
			elseif old_region ~= "" and not datamatch(region, old_region) and not all_test then
				status = 4
			end
			if status == 2 and not all_test and region ~= "" and region ~= old_region then
				write_cache(type, "old_region", region)
			end
			if status == 2 and not all_test and regex ~= old_regex then
				write_cache(type, "old_regex", regex)
			end
			return region
		end

		if region ~= "" and inSupportedLocation then
			status = 2
			if not datamatch(region, regex) then
				status = 3
			elseif old_region ~= "" and not datamatch(region, old_region) and not all_test then
				status = 4
			end
			if status == 2 and not all_test and region ~= old_region then
				write_cache(type, "old_region", region)
			end
			if status == 2 and not all_test and regex ~= old_regex then
				write_cache(type, "old_regex", regex)
			end
			return region
		end
	end
	return region
end

function hbo_max_unlock_test()
	status = 0
	local url = "https://www.max.com/"
	local data = SYS.exec(string.format("curl -sL --connect-timeout 5 -m 5 --speed-time 5 --speed-limit 1 --retry 2 -w '_TAG_%%{http_code}_TAG_' -H 'Content-Type: application/json' -H 'User-Agent: %s' %s", UA, url))
	local region = ""
	local outofregion
	local old_region = get_old_region()
	local old_regex = get_old_regex()
	local regex = get_region_regex() or ""
	if response_code(data) == 200 then
		status = 1
		if string.match(data, "\"isUserOutOfRegion\":%a+") then
			outofregion = string.lower(string.sub(string.match(data, "\"isUserOutOfRegion\":%a+"), 21, -1))
		end
		if string.match(data, "\"userCountry\":\"%a+\"") then
			region = string.upper(string.sub(string.match(data, "\"userCountry\":\"%a+\""), 16, -2))
		end
		if region ~= "" and outofregion == "false" then
			status = 2
			finish_region_test(region, regex, old_region, old_regex)
		end
	end
	return region
end

function ytb_unlock_test()
	status = 0
	local url = "https://m.youtube.com/premium"
	local region = ""
	local old_region = get_old_region()
	local data, he_data
	local regex = get_region_regex() or ""
	local old_regex = get_old_regex()
	data = SYS.exec(string.format("curl -sL --connect-timeout 5 -m 5 --speed-time 5 --speed-limit 1 --retry 2 -w '_TAG_%%{http_code}_TAG_' -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' -b 'YSC=BiCUU3-5Gdk; CONSENT=YES+cb.20220301-11-p0.en+FX+700; GPS=1; VISITOR_INFO1_LIVE=4VwPMkB7W5A; PREF=tz=Asia.Shanghai; _gcl_au=1.1.1809531354.1646633279' %s", UA, url))
	if response_code(data) == 200 then
		status = 1
		if string.find(data,"www%.google%.cn") or string.find(data, "is not available in your country") then
			return region
	  	end
		if string.match(data, "\"GL\":\"%a+\"") then
	  		region = string.sub(string.match(data, "\"GL\":\"%a+\""), 7, -2)
			status = 2
		else
			he_data = SYS.exec(string.format("curl -sIL --connect-timeout 5 -m 5 --speed-time 5 --speed-limit 1 --retry 2 -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' %s", UA, url))
			if string.match(he_data, "gl=%a+") then
				region = string.sub(string.match(he_data, "gl=%a+"), 4, -1)
				status = 2
			else
				region = "US"
			end
		end
		finish_region_test(region, regex, old_region, old_regex)
	end
	return region
end

function tvb_anywhere_unlock_test()
	status = 0
	local url = "https://uapisfm.tvbanywhere.com.sg/geoip/check/platform/android"
	local region = ""
	local old_region = get_old_region()
	local old_regex = get_old_regex()
	local regex = get_region_regex() or ""
	local data = SYS.exec(string.format("curl -sL --connect-timeout 5 -m 5 --speed-time 5 --speed-limit 1 --retry 2 -w '_TAG_%%{http_code}_TAG_' -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' %s", UA, url))
	if response_code(data) == 200 then
		status = 1
		data = JSON.parse(data)
		if data and data.allow_in_this_country then
			status = 2
			if data.country then
	  			region = string.upper(data.country)
	  		end
			if region ~= "" then
				finish_region_test(region, regex, old_region, old_regex)
			end
		end
	end
	return region
end

function prime_video_unlock_test()
	status = 0
	local url = "https://www.primevideo.com"
	local region = ""
	local old_region = get_old_region()
	local old_regex = get_old_regex()
	local regex = get_region_regex() or ""
	local data = SYS.exec(string.format("curl -sL --connect-timeout 5 -m 5 --speed-time 5 --speed-limit 1 --retry 2 -w '_TAG_%%{http_code}_TAG_' -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' %s", UA, url))
	if response_code(data) == 200 then
		status = 1
		if string.match(data, "\"currentTerritory\":\"%a+\"") then
			region = string.sub(string.match(data, "\"currentTerritory\":\"%a+\""), 21, -2)
			status = 2
			finish_region_test(region, regex, old_region, old_regex)
		end
	end
	return region
end

function dazn_unlock_test()
	status = 0
	local url = "https://startup.core.indazn.com/misl/v5/Startup"
	local region = ""
	local old_region = get_old_region()
	local old_regex = get_old_regex()
	local regex = get_region_regex() or ""
	local data = SYS.exec(string.format("curl -sL --connect-timeout 5 -m 5 --speed-time 5 --speed-limit 1 --retry 2 -w '_TAG_%%{http_code}_TAG_' -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' -X POST -d '{\"LandingPageKey\":\"generic\",\"Languages\":\"zh-CN,zh,en\",\"Platform\":\"web\",\"PlatformAttributes\":{},\"Manufacturer\":\"\",\"PromoCode\":\"\",\"Version\":\"2\"}' %s", UA, url))
	if response_code(data) == 200 then
		status = 1
		data = JSON.parse(data)
		if data and data.Region and data.Region.isAllowed then
			status = 2
			if data.Region.GeolocatedCountry then
	  			region = string.upper(data.Region.GeolocatedCountry)
	  		end
			if region ~= "" then
				finish_region_test(region, regex, old_region, old_regex)
			end
		end
	end
	return region
end

function paramount_plus_unlock_test()
	status = 0
	local url = "https://www.paramountplus.com/"
	local region = ""
	local old_region = get_old_region()
	local old_regex = get_old_regex()
	local regex = get_region_regex() or ""
	local data = SYS.exec(string.format("curl -sL --connect-timeout 5 -m 5 --speed-time 5 --speed-limit 1 --retry 2 -w '_TAG_%%{http_code}_TAG_%%{url_effective}_TAGS_' -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' %s", UA, url))
	if response_code(data) == 200 then
		status = 1
		if string.match(data, "_TAG_[^\n]+_TAGS_") then
			if not string.find(string.match(data, "_TAG_[^\n]+_TAGS_"), "intl") then
				status = 2
				local edition = string.match(data, "\"siteEdition\":\"%a+|%a+\"")
				local region_start = 19
				if not edition then
					edition = string.match(data, "property: '%a+'")
					region_start = 12
				end
				if edition then
					region = string.upper(string.sub(edition, region_start, -2))
					finish_region_test(region, regex, old_region, old_regex)
				end
			end
		end
	end
	return region
end

function discovery_plus_unlock_test()
	status = 0
	local url = "https://us1-prod-direct.discoveryplus.com/token?deviceId=d1a4a5d25212400d1e6985984604d740&realm=go&shortlived=true"
	local url1 = "https://us1-prod-direct.discoveryplus.com/users/me"
	local region = ""
	local old_region = get_old_region()
	local old_regex = get_old_regex()
	local regex = get_region_regex() or ""
	local token_resp = SYS.exec(string.format("curl -sL --connect-timeout 5 -m 5 --speed-time 5 --speed-limit 1 --retry 2 -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' '%s'", UA, url))
	local token_info = token_resp and JSON.parse(token_resp)
	if token_info and token_info.data and token_info.data.attributes then
		status = 1
		local token = token_info.data.attributes.token
		local cookie = string.format("-b \"_gcl_au=1.1.858579665.1632206782; _rdt_uuid=1632206782474.6a9ad4f2-8ef7-4a49-9d60-e071bce45e88; _scid=d154b864-8b7e-4f46-90e0-8b56cff67d05; _pin_unauth=dWlkPU1qWTRNR1ZoTlRBdE1tSXdNaTAwTW1Nd0xUbGxORFV0WWpZMU0yVXdPV1l6WldFeQ; _sctr=1|1632153600000; aam_fw=aam%%3D9354365%%3Baam%%3D9040990; aam_uuid=24382050115125439381416006538140778858; st=%s; gi_ls=0; _uetvid=a25161a01aa711ec92d47775379d5e4d; AMCV_BC501253513148ED0A490D45%%40AdobeOrg=-1124106680%%7CMCIDTS%%7C18894%%7CMCMID%%7C24223296309793747161435877577673078228%%7CMCAAMLH-1633011393%%7C9%%7CMCAAMB-1633011393%%7CRKhpRz8krg2tLO6pguXWp5olkAcUniQYPHaMWWgdJ3xzPWQmdj0y%%7CMCOPTOUT-1632413793s%%7CNONE%%7CvVersion%%7C5.2.0; ass=19ef15da-95d6-4b1d-8fa2-e9e099c9cc38.1632408400.1632406594\"", token)
		local data = SYS.exec(string.format("curl -sL --connect-timeout 5 -m 5 --speed-time 5 --speed-limit 1 --retry 2 -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' %s %s", UA, cookie, url1))
		local body = data and JSON.parse(data)
		if body and body.data and body.data.attributes and (body.data.attributes.currentLocationSovereignTerritory or body.data.attributes.currentLocationTerritory) then
			region = body.data.attributes.currentLocationTerritory or body.data.attributes.currentLocationSovereignTerritory
			if region ~= "" then
				region = string.upper(region)
				status = 2
				finish_region_test(region, regex, old_region, old_regex)
	  		end
		end
	end
	return region
end

function bilibili_unlock_test()
	status = 0
	local randsession = SYS.exec("cat /dev/urandom 2>/dev/null | head -n 32 | md5sum | head -c 32")
	local region = ""
	local data, url
	local regex = get_region_regex() or "CN"
	local old_region = get_old_region()
	local old_regex = get_old_regex()
	if regex == "HK/MO/TW" then
		url = string.format("https://api.bilibili.com/pgc/player/web/playurl?avid=18281381&cid=29892777&qn=0&type=&otype=json&ep_id=183799&fourk=1&fnver=0&fnval=16&session=%s&module=bangumi", randsession)
		region = "HK/MO/TW"
	elseif regex == "TW" then
		url = string.format("https://api.bilibili.com/pgc/player/web/playurl?avid=50762638&cid=100279344&qn=0&type=&otype=json&ep_id=268176&fourk=1&fnver=0&fnval=16&session=%s&module=bangumi", randsession)
		region = "TW"
	else
		url = string.format("https://api.bilibili.com/pgc/player/web/playurl?avid=82846771&qn=0&type=&otype=json&ep_id=307247&fourk=1&fnver=0&fnval=16&session=%s&module=bangumi", randsession)
		region = "CN"
	end
	data = SYS.exec(string.format("curl -sL --connect-timeout 5 -m 5 --speed-time 5 --speed-limit 1 --retry 2 -w '_TAG_%%{http_code}_TAG_' -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' '%s'", UA, url))
	if response_code(data) == 200 then
		data = JSON.parse(data)
		status = 1
		if data and data.code and data.code == 0 then
			status = 2
			if old_region ~= "" and region ~= old_region and not all_test then
				status = 4
			end
			if status == 2 and not all_test and region ~= old_region then
				write_cache(type, "old_region", region)
			end
			if status == 2 and not all_test and regex ~= old_regex then
				write_cache(type, "old_regex", regex)
			end
		end
	end
	return region
end

function google_not_cn_test(tested)
	status = 0
	local url = "https://timeline.google.com"
	local region = ""
	local httpcode = SYS.exec(string.format("curl -sL --connect-timeout 5 -m 5 --speed-time 5 --speed-limit 1 --retry 2 -o /dev/null -w %%{http_code} -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' '%s'", UA, url))
	if httpcode then
		if tonumber(httpcode) == 200 then
			status = 2
			region = "NOT CN"
			if not all_test and tested then
				write_cache(type, "old_region", tested)
			end
		else
			region = "CN"
			status = 1
		end
	end
	return region
end

function openai_unlock_test()
	status = 0
	local url = "https://api.openai.com/compliance/cookie_requirements"
	local url2 = "https://ios.chat.openai.com/"
	local region_url = "https://chat.openai.com/cdn-cgi/trace"
	local UA_SEC_CH_UA = '"Google Chrome";v="125", "Chromium";v="125", "Not.A/Brand";v="24"'
	local regex = get_region_regex() or ""
	local region = ""
	local region_data
	local old_region = get_old_region()
	local old_regex = get_old_regex()
	local data = SYS.exec(string.format("curl -sIL --connect-timeout 5 -m 5 --speed-time 5 --speed-limit 1 --retry 2 -H 'authority: api.openai.com' -H 'accept: */*' -H 'accept-language: en-US,en;q=0.9' -H 'authorization: Bearer null' -H 'content-type: application/json' -H 'origin: https://platform.openai.com' -H 'referer: https://platform.openai.com/' -H 'sec-ch-ua: %s' -H 'sec-ch-ua-mobile: ?0' -H 'sec-ch-ua-platform: \"Windows\"' -H 'sec-fetch-dest: empty' -H 'sec-fetch-mode: cors' -H 'sec-fetch-site: same-site' -H 'User-Agent: %s' '%s'", UA_SEC_CH_UA, UA, url))
	local datas = SYS.exec(string.format("curl -sIL --connect-timeout 5 -m 5 --speed-time 5 --speed-limit 1 --retry 2 -H 'authority: ios.chat.openai.com' -H 'accept: */*;q=0.8,application/signed-exchange;v=b3;q=0.7' -H 'accept-language: en-US,en;q=0.9' -H 'sec-ch-ua: %s' -H 'sec-ch-ua-mobile: ?0' -H 'sec-ch-ua-platform: \"Windows\"' -H 'sec-fetch-dest: document' -H 'sec-fetch-mode: navigate' -H 'sec-fetch-site: none' -H 'sec-fetch-user: ?1' -H 'upgrade-insecure-requests: 1' -H 'User-Agent: %s' '%s'", UA_SEC_CH_UA, UA, url2))
	if data and datas then
		if string.find(data, "unsupported_country") or string.find(datas, "VPN") then
			status = 1
		else
			status = 2
			region_data = SYS.exec(string.format("curl -sL --connect-timeout 5 -m 5 --speed-time 5 --speed-limit 1 --retry 2 -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' '%s'", UA, region_url))
			local loc = trace_region(region_data)
			if loc then
				region = loc
				finish_region_test(region, regex, old_region, old_regex)
	  		end
		end
	end
	return region
end

function claude_unlock_test()
	status = 0
	local url = "https://claude.ai/"
	local region_url = "https://claude.ai/cdn-cgi/trace"
	local regex = get_region_regex() or ""
	local region = ""
	local old_region = get_old_region()
	local old_regex = get_old_regex()
	local data = SYS.exec(string.format("curl -sIL --connect-timeout 5 -m 5 --speed-time 5 --speed-limit 1 --retry 2 -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' '%s'", UA, url))
	if data then
		if string.find(data, "App unavailable in region") then
			status = 1
		else
			status = 2
			local region_data = SYS.exec(string.format("curl -sL --connect-timeout 5 -m 5 --speed-time 5 --speed-limit 1 --retry 2 -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' '%s'", UA, region_url))
			local loc = trace_region(region_data)
			if loc then
				region = loc
				finish_region_test(region, regex, old_region, old_regex)
	  		end
		end
	end
	return region
end

function gemini_unlock_test()
	status = 0
	local url = "https://gemini.google.com/"
	local regex = get_region_regex() or ""
	local region = ""
	local old_region = get_old_region()
	local old_regex = get_old_regex()
	local data = SYS.exec(string.format("curl -sL --connect-timeout 5 -m 5 --speed-time 5 --speed-limit 1 --retry 2 -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' '%s'", UA, url))
	if not data or string.sub(data, 1, 4) == "curl" then
		status = 1
		return region
	end

	if string.find(data, "45631641,null,true", 1, true) then
		local cc = string.match(data, ',2,1,200,"([A-Z][A-Z][A-Z])"')
		if cc and cc ~= "" then
			region = cc
		end
		status = 2
		if region ~= "" then
			finish_region_test(region, regex, old_region, old_regex)
		end
	else
		status = 1
	end
	return region
end

local function network_test()
	local test_url1 = "https://www.gstatic.com/generate_204"
	local test_url2 = "https://cp.cloudflare.com/generate_204"
	local httpcode1 = SYS.exec(string.format("curl -sL --connect-timeout 10 -m 15 --speed-time 5 --speed-limit 1 --retry 2 -o /dev/null -w %%{http_code} -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' '%s'", UA, test_url1))
	local httpcode2 = SYS.exec(string.format("curl -sL --connect-timeout 10 -m 15 --speed-time 5 --speed-limit 1 --retry 2 -o /dev/null -w %%{http_code} -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'User-Agent: %s' '%s'", UA, test_url2))
	if httpcode1 or httpcode2 then
		if tonumber(httpcode1) == 204 or tonumber(httpcode2) == 204 then
			unlock_auto_select()
			return
		end
	end
	log_error(MSG.err_network)
end

network_test()
