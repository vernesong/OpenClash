
local m, s, o
local openclash = "openclash"
local uci = luci.model.uci.cursor()
local fs = require "luci.openclash"
local sys = require "luci.sys"
local sid = arg[1]

font_red = [[<b style=color:red>]]
font_off = [[</b>]]
bold_on  = [[<strong>]]
bold_off = [[</strong>]]

function IsYamlFile(e)
   e=e or""
   local e=string.lower(string.sub(e,-5,-1))
   return e == ".yaml"
end
function IsYmlFile(e)
   e=e or""
   local e=string.lower(string.sub(e,-4,-1))
   return e == ".yml"
end

m = Map(openclash, translate("Edit Group"))
m.pageaction = false
m.redirect = luci.dispatcher.build_url("admin/services/openclash/servers")
if m.uci:get(openclash, sid) ~= "groups" then
	luci.http.redirect(m.redirect)
	return
end

-- [[ Groups Setting ]]--
s = m:section(NamedSection, sid, "groups")
s.anonymous = true
s.addremove   = false

o = s:option(ListValue, "config", translate("Config File"))
o:value("all", translate("Use For All Config File"))
local e,a={}
for t,f in ipairs(fs.glob("/etc/openclash/config/*"))do
	a=fs.stat(f)
	if a then
    e[t]={}
    e[t].name=fs.basename(f)
    if IsYamlFile(e[t].name) or IsYmlFile(e[t].name) then
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
o:value("relay", translate("Relay-Traffic"))

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

o = s:option(ListValue, "strategy_smart", translate("Strategy Type"))
o.rmempty = true
o.description = translate("Choose The Smart's Strategy Type")
o:value("round-robin", translate("Round-robin"))
o:value("sticky-sessions", translate("Sticky-sessions"))
o:depends("type", "smart")

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

o = s:option(DynamicList, "other_group", translate("Other Group (Support Regex)"))
o.description = font_red..bold_on..translate("The Added Proxy Groups Must Exist Except 'DIRECT' & 'REJECT' & 'REJECT-DROP' & 'PASS' & 'GLOBAL'")..bold_off..font_off
o:value("all", translate("All Groups"))
uci:foreach("openclash", "groups",
		function(s)
		  if s.name ~= "" and s.name ~= nil and s.name ~= m.uci:get(openclash, sid, "name") then
			   o:value(s.name)
			end
		end)
o:value("DIRECT")
o:value("REJECT")
o:value("REJECT-DROP")
o:value("PASS")
o:value("GLOBAL")
o.rmempty = true

local t = {
    {Commit, Back}
}
a = m:section(Table, t)

o = a:option(Button,"Commit", " ")
o.inputtitle = translate("Commit Settings")
o.inputstyle = "apply"
o.write = function()
   m.uci:commit(openclash)
   sys.call("/usr/share/openclash/yml_groups_name_ch.sh")
   luci.http.redirect(m.redirect)
end

o = a:option(Button,"Back", " ")
o.inputtitle = translate("Back Settings")
o.inputstyle = "reset"
o.write = function()
   m.uci:revert(openclash, sid)
   luci.http.redirect(m.redirect)
end

m:append(Template("openclash/toolbar_show"))
return m
