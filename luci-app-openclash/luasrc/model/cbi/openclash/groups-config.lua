
local m, s, o
local openclash = "openclash"
local uci = luci.model.uci.cursor()
local fs = require "luci.openclash"
local sys = require "luci.sys"
local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"
local sid = arg[1]
local file_path = fs.get_file_path_from_request()

if not file_path then
	HTTP.redirect(DISP.build_url("admin", "services", "openclash", "servers"))
	return
end

font_red = [[<b style=color:red>]]
font_off = [[</b>]]
bold_on = [[<strong>]]
bold_off = [[</strong>]]

m = Map(openclash, translate("Edit Group"))
m.pageaction = false
m.redirect = DISP.build_url("admin/services/openclash/servers") .. "?file=" .. HTTP.urlencode(file_path)
if m.uci:get(openclash, sid) ~= "groups" then
	HTTP.redirect(m.redirect)
	return
end

-- [[ Groups Setting ]]--
s = m:section(NamedSection, sid, "groups")
s.anonymous = true
s.addremove = false

o = s:option(ListValue, "config", translate("Config File"))
o:value("all", translate("Use For All Config File"))
local e,a={}
for t,f in ipairs(fs.glob("/etc/openclash/config/*"))do
	a=fs.stat(f)
	if a then
		e[t]={}
		e[t].name=fs.basename(f)
		if fs.IsYamlExt(e[t].name) then
			o:value(e[t].name)
		end
	end
end

o = s:option(ListValue, "type", translate("Group Type"))
o.rmempty = false
o.description = translate("Choose The Operation Mode")
o:value("select", translate("Manual-Select"))
o:value("smart", translate("Smart-Select"))
o:value("url-test", translate("URL-Test"))
o:value("fallback", translate("Fallback"))
o:value("load-balance", translate("Load-Balance"))

o = s:option(Value, "name", translate("Group Name"))
o.rmempty = false
o.default = "Group - "..sid

o = s:option(ListValue, "disable_udp", translate("Disable UDP"))
o:value("false", translate("Disable"))
o:value("true", translate("Enable"))
o.default = "false"
o.rmempty = true

o = s:option(Value, "test_url", translate("Test URL"))
o:value("http://cp.cloudflare.com/generate_204")
o:value("http://www.gstatic.com/generate_204")
o:value("https://cp.cloudflare.com/generate_204")
o.rmempty = true
o:depends("type", "url-test")
o:depends("type", "fallback")
o:depends("type", "load-balance")
o:depends("type", "smart")

o = s:option(Value, "test_interval", translate("Test Interval(s)"))
o.default = "300"
o.rmempty = true
o:depends("type", "url-test")
o:depends("type", "fallback")
o:depends("type", "load-balance")
o:depends("type", "smart")

o = s:option(ListValue, "strategy", translate("Strategy Type"))
o.rmempty = true
o.description = translate("Choose The Load-Balance's Strategy Type")
o:value("round-robin", translate("Round-robin"))
o:value("consistent-hashing", translate("Consistent-hashing"))
o:value("sticky-sessions", translate("Sticky-sessions"))
o:depends("type", "load-balance")

o = s:option(ListValue, "uselightgbm", translate("Uselightgbm"))
o.description = translate("Use LightGBM Model For Smart Group Weight Prediction")
o:value("false", translate("Disable"))
o:value("true", translate("Enable"))
o.default = "false"
o.rmempty = true
o:depends("type", "smart")

o = s:option(ListValue, "collectdata", translate("Collectdata"))
o.description = translate("Collect Datas For Smart Group Model Training")
o:value("false", translate("Disable"))
o:value("true", translate("Enable"))
o.default = "false"
o.rmempty = true
o:depends("type", "smart")

o = s:option(Value, "policy_priority", translate("Policy Priority"))
o.description = translate("The Priority Of The Nodes, The Higher Than 1, The More Likely It Is To Be Selected, The Default Is 1, Support Regex")
o.rmempty = true
o.placeholder = "Premium:0.9;SG:1.3"
o.rmempty = true
o:depends("type", "smart")

o = s:option(Value, "tolerance", translate("Tolerance(ms)"))
o.default = "150"
o.rmempty = true
o:depends("type", "url-test")

o = s:option(Value, "policy_filter", translate("Provider Filter"))
o.rmempty = true
o.placeholder = "bgp|sg"

o = s:option(Value, "icon", translate("Icon"))
o.rmempty = true

-- [[ other-setting ]]--
o = s:option(Value, "other_parameters", translate("Other Parameters"))
o.template = "cbi/tvalue"
o.rows = 20
o.wrap = "off"
o.description = font_red..bold_on..translate("Edit Your Other Parameters Here")..bold_off..font_off
o.rmempty = true
function o.cfgvalue(self, section)
	if self.map:get(section, "other_parameters") == nil then
		return "# Example:\n"..
		"# Only support YAML, four spaces need to be reserved at the beginning of each line to maintain formatting alignment\n"..
		"# 示例：\n"..
		"# 仅支持 YAML, 每行行首需要多保留四个空格以使脚本处理后能够与上方配置保持格式对齐\n"..
		"#      type: select\n"..
		"#      proxies:\n"..
		"#      - DIRECT\n"..
		"#      - ss\n"..
		"#      use:\n"..
		"#      - provider1\n"..
		"#      - provider1\n"..
		"#      url: 'https://www.gstatic.com/generate_204'\n"..
		"#      interval: 300\n"..
		"#      lazy: true\n"..
		"#      timeout: 5000\n"..
		"#      max-failed-times: 5\n"..
		"#      disable-udp: true\n"..
		"#      interface-name: en0\n"..
		"#      routing-mark: 11451\n"..
		"#      include-all: false\n"..
		"#      include-all-proxies: false\n"..
		"#      include-all-providers: false\n"..
		"#      filter: \"(?i)港|hk|hongkong|hong kong\"\n"..
		"#      exclude-filter: \"美|日\"\n"..
		"#      exclude-type: \"Shadowsocks|Http\"\n"..
		"#      expected-status: 204\n"..
		"#      hidden: true\n"..
		"#      icon: xxx"
	else
		return Value.cfgvalue(self, section)
	end
end
function o.validate(self, value)
	if value then
		value = value:gsub("\r\n?", "\n")
		value = value:gsub("%c*$", "")
	end
	return value
end

o = s:option(DynamicList, "other_group", translate("Other Group (Support Regex)"))
o.description = font_red..bold_on..translate("The Added Proxy Groups Must Exist Except 'DIRECT' & 'REJECT' & 'REJECT-DROP' & 'PASS' & 'GLOBAL'")..bold_off..font_off
o:value("all", translate("All Groups"))
uci:foreach("openclash", "groups",
	function(s)
		if s.name ~= "" and s.name ~= nil and s.name ~= m.uci:get(openclash, sid, "name") and (s.config == m.uci:get(openclash, sid, "config") or s.config == "all") then
			o:value(s.name)
		end
	end)
o:value("DIRECT")
o:value("REJECT")
o:value("REJECT-DROP")
o:value("PASS")
o:value("GLOBAL")
o.rmempty = true

local function sync_group_name(section, old_name, new_name)
	if old_name == "" or old_name == nil or old_name == new_name then
		return
	end

	local function matches(value, pattern)
		if not value or not pattern then
			return false
		end

		local ok, result = pcall(function() return string.match(value, pattern) end)
		if ok and result then
			return true
		end
		return value == pattern
	end

	-- servers 的 groups 列表
	uci:foreach(openclash, "servers", function(s)
		local groups = uci:get(openclash, s[".name"], "groups")
		if groups then
			local new_groups = {}
			local changed = false
			for _, item in ipairs(groups) do
				if matches(old_name, item) then
					table.insert(new_groups, new_name)
					changed = true
				else
					table.insert(new_groups, item)
				end
			end
			if changed then
				uci:delete(openclash, s[".name"], "groups")
				uci:set_list(openclash, s[".name"], "groups", new_groups)
			end
		end
	end)

	-- proxy-provider 的 groups 列表
	uci:foreach(openclash, "proxy-provider", function(s)
		local groups = uci:get(openclash, s[".name"], "groups")
		if groups then
			local new_groups = {}
			local changed = false
			for _, item in ipairs(groups) do
				if matches(old_name, item) then
					table.insert(new_groups, new_name)
					changed = true
				else
					table.insert(new_groups, item)
				end
			end
			if changed then
				uci:delete(openclash, s[".name"], "groups")
				uci:set_list(openclash, s[".name"], "groups", new_groups)
			end
		end
	end)

	-- groups 的 other_group 列表
	uci:foreach(openclash, "groups", function(s)
		if s[".name"] ~= section then
			local other_group = uci:get(openclash, s[".name"], "other_group")
			if other_group then
				local new_other = {}
				local changed = false
				for _, item in ipairs(other_group) do
					if matches(old_name, item) then
						table.insert(new_other, new_name)
						changed = true
					else
						table.insert(new_other, item)
					end
				end
				if changed then
					uci:delete(openclash, s[".name"], "other_group")
					uci:set_list(openclash, s[".name"], "other_group", new_other)
				end
			end
		end
	end)

	-- dns_servers 的 specific_group 选项
	uci:foreach(openclash, "dns_servers", function(s)
		local specific_group = uci:get(openclash, s[".name"], "specific_group")
		if matches(old_name, specific_group) then
			uci:set(openclash, s[".name"], "specific_group", new_name)
		end
	end)

	-- servers 的 dialer_proxy 选项
	uci:foreach(openclash, "servers", function(s)
		local dialer_proxy = uci:get(openclash, s[".name"], "dialer_proxy")
		if matches(old_name, dialer_proxy) then
			uci:set(openclash, s[".name"], "dialer_proxy", new_name)
		end
	end)

	uci:commit(openclash)
end

local t = {
	{Commit, Back}
}
a = m:section(Table, t)

o = a:option(Button,"Commit", " ")
o.inputtitle = translate("Commit Settings")
o.inputstyle = "apply"
o.write = function()
	local old_name = m.uci:get(openclash, sid, "old_name") or ""
	local new_name = HTTP.formvalue("cbid.openclash." .. sid .. ".name") or m.uci:get(openclash, sid, "name")
	sync_group_name(sid, old_name, new_name)
	m.uci:set(openclash, sid, "old_name", new_name)
	m.uci:commit(openclash)
	HTTP.redirect(m.redirect)
end

o = a:option(Button,"Back", " ")
o.inputtitle = translate("Back Settings")
o.inputstyle = "reset"
o.write = function()
	m.uci:revert(openclash, sid)
	HTTP.redirect(m.redirect)
end

m:append(Template("openclash/toolbar_show"))
m:append(Template("openclash/config_editor"))
return m
