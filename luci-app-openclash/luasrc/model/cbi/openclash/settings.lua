
local NXFS = require "nixio.fs"
local SYS  = require "luci.sys"
local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"
local UTIL = require "luci.util"
local fs = require "luci.openclash"
local uci = require "luci.model.uci".cursor()
local json = require "luci.jsonc"
local datatypes = require "luci.cbi.datatypes"

-- 优化 CBI UI（新版 LuCI 专用）
local function optimize_cbi_ui()
	luci.http.write([[
		<script type="text/javascript">
			// 修正上移、下移按钮名称
			document.querySelectorAll("input.btn.cbi-button.cbi-button-up").forEach(function(btn) {
				btn.value = "]] .. translate("Move up") .. [[";
			});
			document.querySelectorAll("input.btn.cbi-button.cbi-button-down").forEach(function(btn) {
				btn.value = "]] .. translate("Move down") .. [[";
			});
			// 删除控件和说明之间的多余换行
			document.querySelectorAll("div.cbi-value-description").forEach(function(descDiv) {
				var prev = descDiv.previousSibling;
				while (prev && prev.nodeType === Node.TEXT_NODE && prev.textContent.trim() === "") {
					prev = prev.previousSibling;
				}
				if (prev && prev.nodeType === Node.ELEMENT_NODE && prev.tagName === "BR") {
					prev.remove();
				}
			});
		</script>
	]])
end

font_green = [[<b style=color:green>]]
font_red = [[<b style=color:red>]]
font_off = [[</b>]]
bold_on  = [[<strong>]]
bold_off = [[</strong>]]

local op_mode = fs.uci_get("config", "operation_mode")
if not op_mode then op_mode = "redir-host" end
local lan_ip = fs.lanip()
m = Map("openclash", translate("Plugin Settings"))
m.pageaction = false
m.description = translate("Note: To restore the default configuration, try accessing:").." <a href='javascript:void(0)' onclick='javascript:restore_config(this)'>http://"..lan_ip.."/cgi-bin/luci/admin/services/openclash/restore</a>"..
"<br/>"..translate("Note: It is not recommended to enable IPv6 and related services for routing. Most of the network connection problems reported so far are related to it")..
"<br/>"..font_green..translate("Note: Turning on secure DNS in the browser will cause abnormal shunting, please be careful to turn it off")..font_off..
"<br/>"..font_green..translate("Note: Some software will modify the device HOSTS, which will cause abnormal shunt, please pay attention to check")..font_off..
"<br/>"..font_green..translate("Note: Game proxy please use nodes except VMess")..font_off..
"<br/>"..font_green..translate("Note: If you need to perform client access control in Fake-IP mode, please change the DNS hijacking mode to firewall forwarding")..font_off..
"<br/>"..translate("Note: The default proxy routes local traffic, BT, PT download, etc., please use Redir-Host mode as much as possible and pay attention to traffic avoidance")..
"<br/>"..translate("Note: If the connection is abnormal, please follow the steps on this page to check first")..": ".."<a href='javascript:void(0)' onclick='javascript:return winOpen(\"https://github.com/vernesong/OpenClash/wiki/%E7%BD%91%E7%BB%9C%E8%BF%9E%E6%8E%A5%E5%BC%82%E5%B8%B8%E6%97%B6%E6%8E%92%E6%9F%A5%E5%8E%9F%E5%9B%A0\")'>"..font_green..bold_on..translate("Click to the page")..bold_off..font_off.."</a>"..
"<br/>"..font_green..translate("For More Useful Meta Core Functions Go Wiki")..": "..font_off.."<a href='javascript:void(0)' onclick='javascript:return winOpen(\"https://wiki.metacubex.one/\")'>"..translate("https://wiki.metacubex.one/").."</a>"

s = m:section(TypedSection, "openclash")
s.anonymous = true

s:tab("op_mode", translate("Operation Mode"))
s:tab("traffic_control", translate("Traffic Control"))
s:tab("dns", "DNS "..translate("Settings"))
s:tab("stream_enhance", translate("Streaming Enhance"))
s:tab("lan_ac", translate("Black&White"))
s:tab("dashboard", translate("Dashboard Settings"))
s:tab("ipv6", translate("IPv6 Settings"))
s:tab("rules_update", translate("Rules Update"))
s:tab("geo_update", translate("GEO Update"))
s:tab("chnr_update", translate("Chnroute Update"))
s:tab("auto_restart", translate("Auto Restart"))
s:tab("version_update", translate("Version Update"))
s:tab("developer", translate("Developer Settings"))
s:tab("debug", translate("Debug Logs"))
s:tab("dlercloud", translate("Dler Cloud"))

o = s:taboption("op_mode", ListValue, "en_mode", font_red..bold_on..translate("Select Mode")..bold_off..font_off)
o.description = translate("Select Mode For OpenClash Work, Try Flush DNS Cache If Network Error")
if op_mode == "redir-host" then
o:value("redir-host", translate("redir-host"))
o:value("redir-host-tun", translate("redir-host(tun mode)"))
o:value("redir-host-mix", translate("redir-host-mix(tun mix mode)"))
o.default = "redir-host"
else
o:value("fake-ip", translate("fake-ip"))
o:value("fake-ip-tun", translate("fake-ip(tun mode)"))
o:value("fake-ip-mix", translate("fake-ip-mix(tun mix mode)"))
o.default = "fake-ip"
end

o = s:taboption("op_mode", Flag, "enable_udp_proxy", translate("Proxy UDP Traffics"))
o.description = translate("The Servers Must Support UDP forwarding").."<br>"..font_red..bold_on.."1."..translate("If Docker is Installed, UDP May Not Forward Normally").."<br>2."..translate("In Fake-ip Mode, Even If This Option is Turned Off, Domain Type Connections Still Pass Through The Core For The Availability")..bold_off..font_off
o:depends("en_mode", "redir-host")
o:depends("en_mode", "fake-ip")
o.default = 1

o = s:taboption("op_mode", ListValue, "stack_type", translate("Select Stack Type"))
o.description = translate("Select Stack Type For TUN Mode, According To The Running Speed on Your Machine")
o:depends("en_mode", "redir-host-tun")
o:depends("en_mode", "fake-ip-tun")
o:depends("en_mode", "redir-host-mix")
o:depends("en_mode", "fake-ip-mix")
o:value("system", translate("System　"))
o:value("gvisor", translate("gVisor"))
o:value("mixed", translate("Mixed"))
o.default = "system"

o = s:taboption("op_mode", ListValue, "proxy_mode", translate("Proxy Mode"))
o.description = translate("Select Proxy Mode")
o:value("rule", translate("Rule Proxy Mode"))
o:value("global", translate("Global Proxy Mode"))
o:value("direct", translate("Direct Proxy Mode"))
o.default = "rule"

o = s:taboption("op_mode", Value, "delay_start", translate("Delay Start (s)"))
o.description = translate("Delay Start On Boot")
o.default = "0"
o.datatype = "uinteger"

o = s:taboption("op_mode", Value, "log_size", translate("Log Size (KB)"))
o.description = translate("Set Log File Size (KB)")
o.default = "1024"

o = s:taboption("op_mode", Flag, "bypass_gateway_compatible", translate("Bypass Gateway Compatible"))
o.description = translate("If The Network Cannot be Connected in Bypass Gateway Mode, Please Try to Enable.")..font_red..bold_on..translate("Suggestion: If The Device Does Not Have WLAN, Please Disable The Lan Interface's Bridge Option")..bold_off..font_off
o.default = 0

o = s:taboption("op_mode", Flag, "disable_quic_go_gso", translate("Disable quic-go GSO Support"))
o.description = font_red..bold_on..translate("Suggestion: If Encountering Issues With QUIC UDP on The Linux Kernel Version Above 6.6, Please Try to Enable.")..bold_off..font_off
o.default = 0

o = s:taboption("op_mode", Flag, "small_flash_memory", translate("Small Flash Memory"))
o.description = translate("Move Core And GEOIP Data File To /tmp/etc/openclash For Small Flash Memory Device")
o.default = 0

---- Operation Mode
switch_mode = s:taboption("op_mode", DummyValue, "", nil)
switch_mode.template = "openclash/switch_mode"

---- DNS Settings
o = s:taboption("dns", ListValue, "enable_redirect_dns", font_red..bold_on..translate("Redirect Local DNS Setting")..bold_off..font_off)
o.description = translate("Set Local DNS Redirect")
o.default = 1
o:value("0", translate("Disable"))
o:value("1", translate("Dnsmasq Redirect"))
o:value("2", translate("Firewall Redirect"))

o = s:taboption("dns", DummyValue, "flush_dns_cache", translate("Flush DNS Cache"))
o.template = "openclash/flush_dns_cache"

o = s:taboption("dns", Flag, "enable_custom_domain_dns_server", translate("Enable Specify DNS Server"))
o.default = 0
o:depends("enable_redirect_dns", "1")
o:depends("enable_redirect_dns", "0")

o = s:taboption("dns", Value, "custom_domain_dns_server", translate("Specify DNS Server"))
o.description = translate("Specify DNS Server For List, Only One IP Server Address Support")
o.default = "114.114.114.114"
o.placeholder = translate("114.114.114.114 or 127.0.0.1#5300")
o:depends{enable_redirect_dns = "1", enable_custom_domain_dns_server = "1"}

custom_domain_dns = s:taboption("dns", Value, "custom_domain_dns")
custom_domain_dns.template = "cbi/tvalue"
custom_domain_dns.description = translate("Domain Names In The List Do Not Return Fake-IP, One rule per line, Depend on Dnsmasq")
custom_domain_dns.rows = 20
custom_domain_dns.wrap = "off"
custom_domain_dns:depends{enable_redirect_dns = "1", enable_custom_domain_dns_server = "1"}

function custom_domain_dns.cfgvalue(self, section)
	return NXFS.readfile("/etc/openclash/custom/openclash_custom_domain_dns.list") or ""
end
function custom_domain_dns.write(self, section, value)
	if value then
		value = value:gsub("\r\n?", "\n")
		local old_value = NXFS.readfile("/etc/openclash/custom/openclash_custom_domain_dns.list")
	  if value ~= old_value then
			NXFS.writefile("/etc/openclash/custom/openclash_custom_domain_dns.list", value)
		end
	end
end

---- Access Control
o = s:taboption("lan_ac", ListValue, "lan_ac_mode", translate("LAN Access Control Mode"))
o.description = font_red..bold_on..translate("To Use in Fake-IP Mode, Please Switch The Dns Redirect Mode To Firewall Forwarding")..bold_off..font_off
o:value("0", translate("Black List Mode"))
o:value("1", translate("White List Mode"))
o.default = "0"
o:depends("enable_redirect_dns", "2")
o:depends("en_mode", "redir-host")
o:depends("en_mode", "redir-host-tun")
o:depends("en_mode", "redir-host-mix")

ip_b = s:taboption("lan_ac", DynamicList, "lan_ac_black_ips", translate("LAN Bypassed Host List"))
ip_b.datatype = "ipmask"
ip_b:depends({lan_ac_mode = "0", enable_redirect_dns = "2"})
ip_b:depends({lan_ac_mode = "0", en_mode = "redir-host"})
ip_b:depends({lan_ac_mode = "0", en_mode = "redir-host-tun"})
ip_b:depends({lan_ac_mode = "0", en_mode = "redir-host-mix"})

mac_b = s:taboption("lan_ac", DynamicList, "lan_ac_black_macs", translate("LAN Bypassed Mac List"))
mac_b.datatype = "list(macaddr)"
mac_b.rmempty  = true
mac_b:depends("lan_ac_mode", "0")

ip_w = s:taboption("lan_ac", DynamicList, "lan_ac_white_ips", translate("LAN Proxied Host List"))
ip_w.datatype = "ipmask"
ip_w:depends({lan_ac_mode = "1", enable_redirect_dns = "2"})
ip_w:depends({lan_ac_mode = "1", en_mode = "redir-host"})
ip_w:depends({lan_ac_mode = "1", en_mode = "redir-host-tun"})
ip_w:depends({lan_ac_mode = "1", en_mode = "redir-host-mix"})

mac_w = s:taboption("lan_ac", DynamicList, "lan_ac_white_macs", translate("LAN Proxied Mac List"))
mac_w.datatype = "list(macaddr)"
mac_w.rmempty  = true
mac_w:depends("lan_ac_mode", "1")

o = s:taboption("lan_ac", DynamicList, "wan_ac_black_ips", translate("WAN Bypassed Host List"))
o.datatype = "ipmask"
o.description = translate("In The Fake-IP Mode, Only Pure IP Requests Are Supported")

s2 = m:section(TypedSection, "lan_ac_traffic", translate("Lan Traffic Access List"),
	"1."..translate("The Traffic From The Local Specified Port Will Not Pass The Core, Try To Set When The Bypass Gateway Forwarding Fails").."; ".."2."..translate("In The Fake-IP Mode, Only Pure IP Requests Are Supported"))

s2.template  = "cbi/tblsection"
s2.sortable  = true
s2.anonymous = true
s2.addremove = true
s2.rmempty = false
s2.render = function(self, ...)
	Map.render(self, ...)
	if type(optimize_cbi_ui) == "function" then
		optimize_cbi_ui()
	end
end

o = s2:option(Value, "comment", translate("Comment"))
o.rmempty = true

o = s2:option(Flag, "enabled", translate("Enable"))
o.rmempty = false
o.default = o.enabled
o.cfgvalue = function(...)
    return Flag.cfgvalue(...) or "1"
end

ip_ac = s2:option(Value, "src_ip", translate("Internal addresses"))
ip_ac.datatype = "or(ipmask, string)"
ip_ac.placeholder = "0.0.0.0/0"
ip_ac.rmempty = true
ip_ac:value("localnetwork", translate("Local Network"))

o = s2:option(Value, "src_port", translate("Internal ports"))
o.datatype = "or(port, portrange)"
o.placeholder = translate("5000 or 1234-2345")
o.rmempty = false

o = s2:option(ListValue, "proto", translate("Proto"))
o:value("udp", translate("UDP"))
o:value("tcp", translate("TCP"))
o:value("both", translate("Both"))
o.default = "tcp"
o.rmempty = false

o = s2:option(ListValue, "family", translate("Family"))
o:value("ipv4", translate("IPv4"))
o:value("ipv6", translate("IPv6"))
o:value("both", translate("Both"))
o.default = "tcp"
o.rmempty = false

o = s2:option(ListValue, "target", translate("Target"))
o:value("return", translate("RETURN"))
o:value("accept", translate("ACCEPT"))
o:value("drop", translate("DROP"))
o.rmempty = false

local function ip_compare(a, b)
    local function ipv4_to_number(ip)
        local p1, p2, p3, p4 = ip:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
        if p1 and p2 and p3 and p4 then
            local n1, n2, n3, n4 = tonumber(p1), tonumber(p2), tonumber(p3), tonumber(p4)
            if n1 <= 255 and n2 <= 255 and n3 <= 255 and n4 <= 255 then
                return n1 * 16777216 + n2 * 65536 + n3 * 256 + n4
            end
        end
        return 0
    end
    
    local a_is_ipv4 = datatypes.ip4addr(a.dest)
    local b_is_ipv4 = datatypes.ip4addr(b.dest)
    
    if a_is_ipv4 and not b_is_ipv4 then
        return true
    elseif not a_is_ipv4 and b_is_ipv4 then
        return false
    elseif a_is_ipv4 and b_is_ipv4 then
        return ipv4_to_number(a.dest) < ipv4_to_number(b.dest)
    else
        return a.dest < b.dest
    end
end

local all_neighbors = {}

luci.ip.neighbors({ family = 4 }, function(n)
    if n.mac and n.dest then
        table.insert(all_neighbors, {dest = n.dest:string(), mac = n.mac, family = 4})
    end
end)

if string.len(SYS.exec("/usr/share/openclash/openclash_get_network.lua 'gateway6'")) ~= 0 then
    luci.ip.neighbors({ family = 6 }, function(n)
        if n.mac and n.dest then
            table.insert(all_neighbors, {dest = n.dest:string(), mac = n.mac, family = 6})
        end
    end)
end

table.sort(all_neighbors, ip_compare)

local mac_ip_map = {}
local mac_order = {}

for _, item in ipairs(all_neighbors) do
    ip_b:value(item.dest)
    ip_w:value(item.dest)
    ip_ac:value(item.dest)
    if not mac_ip_map[item.mac] then
        mac_ip_map[item.mac] = {}
        table.insert(mac_order, item.mac)
    end
    table.insert(mac_ip_map[item.mac], item.dest)
end

for _, mac in ipairs(mac_order) do
    local ips = mac_ip_map[mac]
    table.sort(ips, function(a, b)
        local a_is_ipv4 = datatypes.ip4addr(a)
        local b_is_ipv4 = datatypes.ip4addr(b)
        if a_is_ipv4 and not b_is_ipv4 then
            return true
        elseif not a_is_ipv4 and b_is_ipv4 then
            return false
        elseif a_is_ipv4 and b_is_ipv4 then
            local function ipv4_to_number(ip)
                local p1, p2, p3, p4 = ip:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
                return p1 and p2 and p3 and p4 and (tonumber(p1)*16777216+tonumber(p2)*65536+tonumber(p3)*256+tonumber(p4)) or 0
            end
            return ipv4_to_number(a) < ipv4_to_number(b)
        else
            return a < b
        end
    end)
    local ip_str = table.concat(ips, "|")
    mac_b:value(mac, "%s (%s)" %{ mac, ip_str })
    mac_w:value(mac, "%s (%s)" %{ mac, ip_str })
end

---- Traffic Control
o = s:taboption("traffic_control", Flag, "router_self_proxy", font_red..bold_on..translate("Router-Self Proxy")..bold_off..font_off)
o.description = translate("Only Supported for Rule Mode")..", "..font_red..bold_on..translate("ALL Functions In Stream Enhance Tag Will Not Work After Disable")..bold_off..font_off
o.default = 1

o = s:taboption("traffic_control", Flag, "disable_udp_quic", font_red..bold_on..translate("Disable QUIC")..bold_off..font_off)
o.description = translate("Prevent YouTube and Others To Use QUIC Transmission")..", "..font_red..bold_on..translate("REJECT UDP Traffic(Not Include bypassed regions via China IP Route setting) On Port 443")..bold_off..font_off
o.default = 1

o = s:taboption("traffic_control", Flag, "skip_proxy_address", translate("Skip Proxy Address"))
o.description = translate("Bypassing Server Addresses And Preventing Duplicate Proxies")
o.default = 0

o = s:taboption("traffic_control", Value, "common_ports", font_red..bold_on..translate("Common Ports Proxy Mode")..bold_off..font_off)
o.description = translate("Only Common Ports, Prevent BT/P2P Passing")
o:value("0", translate("Disable"))
o:value("21 22 23 53 80 123 143 194 443 465 587 853 993 995 998 2052 2053 2082 2083 2086 2095 2096 5222 5228 5229 5230 8080 8443 8880 8888 8889", translate("Default Common Ports"))
o.default = 0
o.placeholder = translate("443 or 21-443, Use Space to Separate")
o:depends("en_mode", "redir-host")
o:depends("en_mode", "redir-host-tun")
o:depends("en_mode", "redir-host-mix")

o = s:taboption("traffic_control", ListValue, "china_ip_route", translate("China IP Route"))
o.description = translate("Bypass Specified Regions Network Flows, Improve Performance, If Inaccessibility on Bypass Gateway, Try to Enable Bypass Gateway Compatible Option")
o.default = 0
o:value("0", translate("Disable"))
o:value("1", translate("Bypass Mainland China"))
o:value("2", translate("Bypass Overseas"))

o = s:taboption("traffic_control", Flag, "intranet_allowed", translate("Only intranet allowed"))
o.description = translate("When Enabled, The Control Panel And The Connection Broker Port Will Not Be Accessible From The Public Network")
o.default = 1

o = s:taboption("traffic_control", DynamicList, "intranet_allowed_wan_name", translate("WAN Interface Name"))
o.description = translate("Select WAN Interface Name For The Intranet Allowed")
o:depends("intranet_allowed", "1")
local interfaces = SYS.exec("ls -l /sys/class/net/ 2>/dev/null |awk '{print $9}' 2>/dev/null")
for interface in string.gmatch(interfaces, "%S+") do
   o:value(interface)
end

o = s:taboption("traffic_control", ListValue, "lan_interface_name", translate("LAN Interface Name"))
o.description = translate("Select LAN Interface Name")
o:value("0", translate("Disable"))
o.default = "0"
for interface in string.gmatch(interfaces, "%S+") do
   o:value(interface)
end

o = s:taboption("traffic_control", Value, "local_network_pass", translate("Local IPv4 Network Bypassed List"))
o.template = "cbi/tvalue"
o.description = translate("The Traffic of The Destination For The Specified Address Will Not Pass The Core")
o.rows = 20
o.wrap = "off"

function o.cfgvalue(self, section)
	return NXFS.readfile("/etc/openclash/custom/openclash_custom_localnetwork_ipv4.list") or ""
end
function o.write(self, section, value)
	if value then
		value = value:gsub("\r\n?", "\n")
		local old_value = NXFS.readfile("/etc/openclash/custom/openclash_custom_localnetwork_ipv4.list")
	  if value ~= old_value then
			NXFS.writefile("/etc/openclash/custom/openclash_custom_localnetwork_ipv4.list", value)
		end
	end
end

o = s:taboption("traffic_control", Value, "chnroute_pass", translate("Chnroute Bypassed List"))
o.template = "cbi/tvalue"
o.description = translate("Domains or IPs in The List Will Not be Affected by The China IP Route Option, Depend on Dnsmasq")
o.rows = 20
o.wrap = "off"
o:depends("enable_redirect_dns", "1")
o:depends("enable_redirect_dns", "0")

function o.cfgvalue(self, section)
	return NXFS.readfile("/etc/openclash/custom/openclash_custom_chnroute_pass.list") or ""
end
function o.write(self, section, value)
	if value then
		value = value:gsub("\r\n?", "\n")
		local old_value = NXFS.readfile("/etc/openclash/custom/openclash_custom_chnroute_pass.list")
	  if value ~= old_value then
			NXFS.writefile("/etc/openclash/custom/openclash_custom_chnroute_pass.list", value)
		end
	end
end

--Stream Enhance
o = s:taboption("stream_enhance", Flag, "stream_auto_select", font_red..bold_on..translate("Auto Select Unlock Proxy")..bold_off..font_off)
o.description = translate("Auto Select Proxy For Streaming Unlock, Support Netflix, Disney Plus, HBO And YouTube Premium, etc")
o.default = 0
o:depends("router_self_proxy", "1")

o = s:taboption("stream_enhance", Button, translate("Flush Unlock Test Cache")) 
o.title = translate("Flush Unlock Test Cache")
o.inputtitle = translate("Flush Cache")
o.inputstyle = "reload"
o.write = function()
  SYS.call("rm -rf /etc/openclash/history/streaming_unlock_cache >/dev/null 2>&1 &")
end
o:depends("stream_auto_select", "1")

o = s:taboption("stream_enhance", Value, "stream_auto_select_interval", translate("Auto Select Interval(min)"))
o.default = "30"
o.datatype = "uinteger"
o:depends("stream_auto_select", "1")
o.rmempty = true

o = s:taboption("stream_enhance", ListValue, "stream_auto_select_logic", font_red..bold_on..translate("Auto Select Logic")..bold_off..font_off)
o.default = "urltest"
o:value("urltest", translate("Urltest"))
o:value("random", translate("Random"))
o:depends("stream_auto_select", "1")

o = s:taboption("stream_enhance", Flag, "stream_auto_select_expand_group", font_red..bold_on..translate("Expand Group")..bold_off..font_off)
o.description = translate("Automatically Expand The Group When Selected")
o.default = 0
o:depends("stream_auto_select", "1")

o = s:taboption("stream_enhance", Flag, "stream_auto_select_close_con", translate("Close Old Connections"))
o.description = translate("Automatically Close Old Connections When New Unlock Node Selected")
o.default = 1
o:depends("stream_auto_select", "1")

--Netflix
o = s:taboption("stream_enhance", Flag, "stream_auto_select_netflix", font_red..translate("Netflix")..font_off)
o.default = 0
o:depends("stream_auto_select", "1")

o = s:taboption("stream_enhance", Value, "stream_auto_select_group_key_netflix", translate("Group Filter"))
o.placeholder = "Netflix|奈飞"
o.description = translate("It Will Be Searched According To The Regex When Auto Search Group Fails")
o:depends("stream_auto_select_netflix", "1")
o.rmempty = true

o = s:taboption("stream_enhance", Value, "stream_auto_select_region_key_netflix", translate("Unlock Region Filter"))
o.placeholder = "HK|SG|TW"
o.description = translate("It Will Be Selected Region(Country Shortcode) According To The Regex")
o:depends("stream_auto_select_netflix", "1")
o.rmempty = true

o = s:taboption("stream_enhance", Value, "stream_auto_select_node_key_netflix", translate("Unlock Nodes Filter"))
o.description = translate("It Will Be Selected Nodes According To The Regex")
o:depends("stream_auto_select_netflix", "1")
o.rmempty = true

o = s:taboption("stream_enhance", DummyValue, "Netflix", translate("Manual Test"))
o.rawhtml = true
o.template = "openclash/other_stream_option"
o.value = "Netflix"
o:depends("stream_auto_select_netflix", "1")

--Disney Plus
o = s:taboption("stream_enhance", Flag, "stream_auto_select_disney", font_red..translate("Disney Plus")..font_off)
o.default = 0
o:depends("stream_auto_select", "1")

o = s:taboption("stream_enhance", Value, "stream_auto_select_group_key_disney", translate("Group Filter"))
o.placeholder = "Disney|迪士尼"
o.description = translate("It Will Be Searched According To The Regex When Auto Search Group Fails")
o:depends("stream_auto_select_disney", "1")
o.rmempty = true

o = s:taboption("stream_enhance", Value, "stream_auto_select_region_key_disney", translate("Unlock Region Filter"))
o.placeholder = "HK|SG|TW"
o.description = translate("It Will Be Selected Region(Country Shortcode) According To The Regex")
o:depends("stream_auto_select_disney", "1")
o.rmempty = true

o = s:taboption("stream_enhance", Value, "stream_auto_select_node_key_disney", translate("Unlock Nodes Filter"))
o.description = translate("It Will Be Selected Nodes According To The Regex")
o:depends("stream_auto_select_disney", "1")
o.rmempty = true

o = s:taboption("stream_enhance", DummyValue, "Disney Plus", translate("Manual Test"))
o.rawhtml = true
o.template = "openclash/other_stream_option"
o.value = "Disney Plus"
o:depends("stream_auto_select_disney", "1")

--YouTube Premium
o = s:taboption("stream_enhance", Flag, "stream_auto_select_ytb", font_red..translate("YouTube Premium")..font_off)
o.default = 0
o:depends("stream_auto_select", "1")

o = s:taboption("stream_enhance", Value, "stream_auto_select_group_key_ytb", translate("Group Filter"))
o.placeholder = "YouTube|油管"
o.description = translate("It Will Be Searched According To The Regex When Auto Search Group Fails")
o:depends("stream_auto_select_ytb", "1")
o.rmempty = true

o = s:taboption("stream_enhance", Value, "stream_auto_select_region_key_ytb", translate("Unlock Region Filter"))
o.placeholder = "HK|US"
o.description = translate("It Will Be Selected Region(Country Shortcode) According To The Regex")
o:depends("stream_auto_select_ytb", "1")
o.rmempty = true

o = s:taboption("stream_enhance", Value, "stream_auto_select_node_key_ytb", translate("Unlock Nodes Filter"))
o.description = translate("It Will Be Selected Nodes According To The Regex")
o:depends("stream_auto_select_ytb", "1")
o.rmempty = true

o = s:taboption("stream_enhance", DummyValue, "YouTube Premium", translate("Manual Test"))
o.rawhtml = true
o.template = "openclash/other_stream_option"
o.value = "YouTube Premium"
o:depends("stream_auto_select_ytb", "1")

--Amazon Prime Video
o = s:taboption("stream_enhance", Flag, "stream_auto_select_prime_video", font_red..translate("Amazon Prime Video")..font_off)
o.default = 0
o:depends("stream_auto_select", "1")

o = s:taboption("stream_enhance", Value, "stream_auto_select_group_key_prime_video", translate("Group Filter"))
o.placeholder = "Amazon|Prime Video"
o.description = translate("It Will Be Searched According To The Regex When Auto Search Group Fails")
o:depends("stream_auto_select_prime_video", "1")
o.rmempty = true

o = s:taboption("stream_enhance", Value, "stream_auto_select_region_key_prime_video", translate("Unlock Region Filter"))
o.placeholder = "HK|US|SG"
o.description = translate("It Will Be Selected Region(Country Shortcode) According To The Regex")
o:depends("stream_auto_select_prime_video", "1")
o.rmempty = true

o = s:taboption("stream_enhance", Value, "stream_auto_select_node_key_prime_video", translate("Unlock Nodes Filter"))
o.description = translate("It Will Be Selected Nodes According To The Regex")
o:depends("stream_auto_select_prime_video", "1")
o.rmempty = true

o = s:taboption("stream_enhance", DummyValue, "Amazon Prime Video", translate("Manual Test"))
o.rawhtml = true
o.template = "openclash/other_stream_option"
o.value = "Amazon Prime Video"
o:depends("stream_auto_select_prime_video", "1")

--HBO Max
o = s:taboption("stream_enhance", Flag, "stream_auto_select_hbo_max", font_red..translate("HBO Max")..font_off)
o.default = 0
o:depends("stream_auto_select", "1")

o = s:taboption("stream_enhance", Value, "stream_auto_select_group_key_hbo_max", translate("Group Filter"))
o.placeholder = "HBO|HBOMax|HBO Max"
o.description = translate("It Will Be Searched According To The Regex When Auto Search Group Fails")
o:depends("stream_auto_select_hbo_max", "1")
o.rmempty = true

o = s:taboption("stream_enhance", Value, "stream_auto_select_region_key_hbo_max", translate("Unlock Region Filter"))
o.placeholder = "US"
o.description = translate("It Will Be Selected Region(Country Shortcode) According To The Regex")
o:depends("stream_auto_select_hbo_max", "1")
o.rmempty = true

o = s:taboption("stream_enhance", Value, "stream_auto_select_node_key_hbo_max", translate("Unlock Nodes Filter"))
o.description = translate("It Will Be Selected Nodes According To The Regex")
o:depends("stream_auto_select_hbo_max", "1")
o.rmempty = true

o = s:taboption("stream_enhance", DummyValue, "HBO Max", translate("Manual Test"))
o.rawhtml = true
o.template = "openclash/other_stream_option"
o.value = "HBO Max"
o:depends("stream_auto_select_hbo_max", "1")

--TVB Anywhere+
o = s:taboption("stream_enhance", Flag, "stream_auto_select_tvb_anywhere", font_red..translate("TVB Anywhere+")..font_off)
o.default = 0
o:depends("stream_auto_select", "1")

o = s:taboption("stream_enhance", Value, "stream_auto_select_group_key_tvb_anywhere", translate("Group Filter"))
o.placeholder = "TVB"
o.description = translate("It Will Be Searched According To The Regex When Auto Search Group Fails")
o:depends("stream_auto_select_tvb_anywhere", "1")
o.rmempty = true

o = s:taboption("stream_enhance", Value, "stream_auto_select_region_key_tvb_anywhere", translate("Unlock Region Filter"))
o.placeholder = "HK|SG|TW"
o.description = translate("It Will Be Selected Region(Country Shortcode) According To The Regex")
o:depends("stream_auto_select_tvb_anywhere", "1")
o.rmempty = true

o = s:taboption("stream_enhance", Value, "stream_auto_select_node_key_tvb_anywhere", translate("Unlock Nodes Filter"))
o.description = translate("It Will Be Selected Nodes According To The Regex")
o:depends("stream_auto_select_tvb_anywhere", "1")
o.rmempty = true

o = s:taboption("stream_enhance", DummyValue, "TVB Anywhere+", translate("Manual Test"))
o.rawhtml = true
o.template = "openclash/other_stream_option"
o.value = "TVB Anywhere+"
o:depends("stream_auto_select_tvb_anywhere", "1")

--DAZN
o = s:taboption("stream_enhance", Flag, "stream_auto_select_dazn", font_red..translate("DAZN")..font_off)
o.default = 0
o:depends("stream_auto_select", "1")

o = s:taboption("stream_enhance", Value, "stream_auto_select_group_key_dazn", translate("Group Filter"))
o.placeholder = "DAZN"
o.description = translate("It Will Be Searched According To The Regex When Auto Search Group Fails")
o:depends("stream_auto_select_dazn", "1")
o.rmempty = true

o = s:taboption("stream_enhance", Value, "stream_auto_select_region_key_dazn", translate("Unlock Region Filter"))
o.placeholder = "DE"
o.description = translate("It Will Be Selected Region(Country Shortcode) According To The Regex")
o:depends("stream_auto_select_dazn", "1")
o.rmempty = true

o = s:taboption("stream_enhance", Value, "stream_auto_select_node_key_dazn", translate("Unlock Nodes Filter"))
o.description = translate("It Will Be Selected Nodes According To The Regex")
o:depends("stream_auto_select_dazn", "1")
o.rmempty = true

o = s:taboption("stream_enhance", DummyValue, "DAZN", translate("Manual Test"))
o.rawhtml = true
o.template = "openclash/other_stream_option"
o.value = "DAZN"
o:depends("stream_auto_select_dazn", "1")

--Paramount Plus
o = s:taboption("stream_enhance", Flag, "stream_auto_select_paramount_plus", font_red..translate("Paramount Plus")..font_off)
o.default = 0
o:depends("stream_auto_select", "1")

o = s:taboption("stream_enhance", Value, "stream_auto_select_group_key_paramount_plus", translate("Group Filter"))
o.placeholder = "Paramount"
o.description = translate("It Will Be Searched According To The Regex When Auto Search Group Fails")
o:depends("stream_auto_select_paramount_plus", "1")
o.rmempty = true

o = s:taboption("stream_enhance", Value, "stream_auto_select_region_key_paramount_plus", translate("Unlock Region Filter"))
o.placeholder = "US"
o.description = translate("It Will Be Selected Region(Country Shortcode) According To The Regex")
o:depends("stream_auto_select_paramount_plus", "1")
o.rmempty = true

o = s:taboption("stream_enhance", Value, "stream_auto_select_node_key_paramount_plus", translate("Unlock Nodes Filter"))
o.description = translate("It Will Be Selected Nodes According To The Regex")
o:depends("stream_auto_select_paramount_plus", "1")
o.rmempty = true

o = s:taboption("stream_enhance", DummyValue, "Paramount Plus", translate("Manual Test"))
o.rawhtml = true
o.template = "openclash/other_stream_option"
o.value = "Paramount Plus"
o:depends("stream_auto_select_paramount_plus", "1")

--Discovery Plus
o = s:taboption("stream_enhance", Flag, "stream_auto_select_discovery_plus", font_red..translate("Discovery Plus")..font_off)
o.default = 0
o:depends("stream_auto_select", "1")

o = s:taboption("stream_enhance", Value, "stream_auto_select_group_key_discovery_plus", translate("Group Filter"))
o.placeholder = "Discovery"
o.description = translate("It Will Be Searched According To The Regex When Auto Search Group Fails")
o:depends("stream_auto_select_discovery_plus", "1")
o.rmempty = true

o = s:taboption("stream_enhance", Value, "stream_auto_select_region_key_discovery_plus", translate("Unlock Region Filter"))
o.placeholder = "US"
o.description = translate("It Will Be Selected Region(Country Shortcode) According To The Regex")
o:depends("stream_auto_select_discovery_plus", "1")
o.rmempty = true

o = s:taboption("stream_enhance", Value, "stream_auto_select_node_key_discovery_plus", translate("Unlock Nodes Filter"))
o.description = translate("It Will Be Selected Nodes According To The Regex")
o:depends("stream_auto_select_discovery_plus", "1")
o.rmempty = true

o = s:taboption("stream_enhance", DummyValue, "Discovery Plus", translate("Manual Test"))
o.rawhtml = true
o.template = "openclash/other_stream_option"
o.value = "Discovery Plus"
o:depends("stream_auto_select_discovery_plus", "1")

--Bilibili
o = s:taboption("stream_enhance", Flag, "stream_auto_select_bilibili", font_red..translate("Bilibili")..font_off)
o.default = 0
o:depends("stream_auto_select", "1")

o = s:taboption("stream_enhance", Value, "stream_auto_select_group_key_bilibili", translate("Group Filter"))
o.placeholder = "Bilibili"
o.description = translate("It Will Be Searched According To The Regex When Auto Search Group Fails")
o:depends("stream_auto_select_bilibili", "1")
o.rmempty = true

o = s:taboption("stream_enhance", ListValue, "stream_auto_select_region_key_bilibili", translate("Unlock Region Filter"))
o.default = "CN"
o:value("CN", translate("China Mainland Only"))
o:value("HK/MO/TW", translate("Hongkong/Macau/Taiwan"))
o:value("TW", translate("Taiwan Only"))
o.description = translate("It Will Be Selected Region(Country Shortcode) According To The Regex")
o:depends("stream_auto_select_bilibili", "1")
o.rmempty = false

o = s:taboption("stream_enhance", Value, "stream_auto_select_node_key_bilibili", translate("Unlock Nodes Filter"))
o.description = translate("It Will Be Selected Nodes According To The Regex")
o:depends("stream_auto_select_bilibili", "1")
o.rmempty = true

o = s:taboption("stream_enhance", DummyValue, "Bilibili", translate("Manual Test"))
o.rawhtml = true
o.template = "openclash/other_stream_option"
o.value = "Bilibili"
o:depends("stream_auto_select_bilibili", "1")

--Google not cn
o = s:taboption("stream_enhance", Flag, "stream_auto_select_google_not_cn", font_red..translate("Google Not CN")..font_off)
o.default = 0
o:depends("stream_auto_select", "1")

o = s:taboption("stream_enhance", Value, "stream_auto_select_group_key_google_not_cn", translate("Group Filter"))
o.placeholder = "Google"
o.description = translate("It Will Be Searched According To The Regex When Auto Search Group Fails")
o:depends("stream_auto_select_google_not_cn", "1")
o.rmempty = true

o = s:taboption("stream_enhance", Value, "stream_auto_select_node_key_google_not_cn", translate("Unlock Nodes Filter"))
o.description = translate("It Will Be Selected Nodes According To The Regex")
o:depends("stream_auto_select_google_not_cn", "1")
o.rmempty = true

o = s:taboption("stream_enhance", DummyValue, "Google", translate("Manual Test"))
o.rawhtml = true
o.template = "openclash/other_stream_option"
o.value = "Google"
o:depends("stream_auto_select_google_not_cn", "1")

--OpenAI
o = s:taboption("stream_enhance", Flag, "stream_auto_select_openai", font_red..translate("OpenAI")..font_off)
o.default = 0
o:depends("stream_auto_select", "1")

o = s:taboption("stream_enhance", Value, "stream_auto_select_group_key_openai", translate("Group Filter"))
o.placeholder = "OpenAI|ChatGPT|AI"
o.description = translate("It Will Be Searched According To The Regex When Auto Search Group Fails")
o:depends("stream_auto_select_openai", "1")
o.rmempty = true

o = s:taboption("stream_enhance", Value, "stream_auto_select_region_key_openai", translate("Unlock Region Filter"))
o.placeholder = "US"
o.description = translate("It Will Be Selected Region(Country Shortcode) According To The Regex")
o:depends("stream_auto_select_openai", "1")
o.rmempty = true

o = s:taboption("stream_enhance", Value, "stream_auto_select_node_key_openai", translate("Unlock Nodes Filter"))
o.description = translate("It Will Be Selected Nodes According To The Regex")
o:depends("stream_auto_select_openai", "1")
o.rmempty = true

o = s:taboption("stream_enhance", DummyValue, "OpenAI", translate("Manual Test"))
o.rawhtml = true
o.template = "openclash/other_stream_option"
o.value = "OpenAI"
o:depends("stream_auto_select_openai", "1")

---- update Settings
o = s:taboption("rules_update", Flag, "other_rule_auto_update", translate("Auto Update"))
o.description = font_red..bold_on..translate("Auto Update Other Rules")..bold_off..font_off
o.default = 0

o = s:taboption("rules_update", ListValue, "other_rule_update_week_time", translate("Update Time (Every Week)"))
o:depends("other_rule_auto_update", "1")
o:value("*", translate("Every Day"))
o:value("1", translate("Every Monday"))
o:value("2", translate("Every Tuesday"))
o:value("3", translate("Every Wednesday"))
o:value("4", translate("Every Thursday"))
o:value("5", translate("Every Friday"))
o:value("6", translate("Every Saturday"))
o:value("0", translate("Every Sunday"))
o.default = "1"

o = s:taboption("rules_update", ListValue, "other_rule_update_day_time", translate("Update time (every day)"))
o:depends("other_rule_auto_update", "1")
for t = 0,23 do
o:value(t, t..":00")
end
o.default = "0"

o = s:taboption("rules_update", Button, translate("Other Rules Update")) 
o:depends("other_rule_auto_update", "1")
o.title = translate("Update Other Rules")
o.inputtitle = translate("Check And Update")
o.description = translate("Other Rules Update(Only in Use)")..", "..translate("Current Version:").." "..font_green..bold_on..translate(fs.get_resourse_mtime("/usr/share/openclash/res/lhie1.yaml"))..bold_off..font_off
o.inputstyle = "reload"
o.write = function()
  m.uci:set("openclash", "config", "enable", 1)
  m.uci:commit("openclash")
  SYS.call("/usr/share/openclash/openclash_rule.sh >/dev/null 2>&1 &")
  HTTP.redirect(DISP.build_url("admin", "services", "openclash"))
end

o = s:taboption("geo_update", Flag, "geo_auto_update", font_red..bold_on..translate("Auto Update GeoIP MMDB")..bold_off..font_off)
o.default = 0

o = s:taboption("geo_update", ListValue, "geo_update_week_time", translate("Update Time (Every Week)"))
o:value("*", translate("Every Day"))
o:value("1", translate("Every Monday"))
o:value("2", translate("Every Tuesday"))
o:value("3", translate("Every Wednesday"))
o:value("4", translate("Every Thursday"))
o:value("5", translate("Every Friday"))
o:value("6", translate("Every Saturday"))
o:value("0", translate("Every Sunday"))
o.default = "1"
o:depends("geo_auto_update", "1")

o = s:taboption("geo_update", ListValue, "geo_update_day_time", translate("Update time (every day)"))
for t = 0,23 do
o:value(t, t..":00")
end
o.default = "0"
o:depends("geo_auto_update", "1")

o = s:taboption("geo_update", Value, "geo_custom_url")
o.title = translate("Custom GeoIP MMDB URL")
o.rmempty = true
o.description = translate("Custom GeoIP MMDB URL, Click Button Below To Refresh After Edit")
o:value("https://testingcf.jsdelivr.net/gh/alecthw/mmdb_china_ip_list@release/lite/Country.mmdb", translate("Alecthw-lite-Version")..translate("(Default mmdb)"))
o:value("https://testingcf.jsdelivr.net/gh/alecthw/mmdb_china_ip_list@release/Country.mmdb", translate("Alecthw-Version")..translate("(All Info mmdb)"))
o:value("https://testingcf.jsdelivr.net/gh/Hackl0us/GeoIP2-CN@release/Country.mmdb", translate("Hackl0us-Version")..translate("(Only CN)"))
o.default = "https://testingcf.jsdelivr.net/gh/alecthw/mmdb_china_ip_list@release/lite/Country.mmdb"
o:depends("geo_auto_update", "1")

o = s:taboption("geo_update", Button, translate("GEOIP Update")) 
o.title = translate("Update GeoIP MMDB")
o.description = translate("Current Version:").." "..font_green..bold_on..translate(fs.get_resourse_mtime("/etc/openclash/Country.mmdb"))..bold_off..font_off
o.inputtitle = translate("Check And Update")
o.inputstyle = "reload"
o.write = function()
  m.uci:set("openclash", "config", "enable", 1)
  m.uci:commit("openclash")
  SYS.call("/usr/share/openclash/openclash_ipdb.sh >/dev/null 2>&1 &")
  HTTP.redirect(DISP.build_url("admin", "services", "openclash"))
end

o = s:taboption("geo_update", Flag, "geoip_auto_update", font_red..bold_on..translate("Auto Update GeoIP Dat")..bold_off..font_off)
o.default = 0

o = s:taboption("geo_update", ListValue, "geoip_update_week_time", translate("Update Time (Every Week)"))
o:value("*", translate("Every Day"))
o:value("1", translate("Every Monday"))
o:value("2", translate("Every Tuesday"))
o:value("3", translate("Every Wednesday"))
o:value("4", translate("Every Thursday"))
o:value("5", translate("Every Friday"))
o:value("6", translate("Every Saturday"))
o:value("0", translate("Every Sunday"))
o.default = "1"
o:depends("geoip_auto_update", "1")

o = s:taboption("geo_update", ListValue, "geoip_update_day_time", translate("Update time (every day)"))
for t = 0,23 do
o:value(t, t..":00")
end
o.default = "0"
o:depends("geoip_auto_update", "1")

o = s:taboption("geo_update", Value, "geoip_custom_url")
o.title = translate("Custom GeoIP Dat URL")
o.rmempty = true
o.description = translate("Custom GeoIP Dat URL, Click Button Below To Refresh After Edit")
o:value("https://testingcf.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geoip.dat", translate("Loyalsoldier-testingcf-jsdelivr-Version")..translate("(Default)"))
o:value("https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geoip.dat", translate("Loyalsoldier-fastly-jsdelivr-Version"))
o.default = "https://testingcf.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geoip.dat"
o:depends("geoip_auto_update", "1")

o = s:taboption("geo_update", Button, translate("GEOIP Dat Update")) 
o.title = translate("Update GeoIP Dat")
o.description = translate("Current Version:").." "..font_green..bold_on..translate(fs.get_resourse_mtime("/etc/openclash/GeoIP.dat"))..bold_off..font_off
o.inputtitle = translate("Check And Update")
o.inputstyle = "reload"
o.write = function()
  m.uci:set("openclash", "config", "enable", 1)
  m.uci:commit("openclash")
  SYS.call("/usr/share/openclash/openclash_geoip.sh >/dev/null 2>&1 &")
  HTTP.redirect(DISP.build_url("admin", "services", "openclash"))
end

o = s:taboption("geo_update", Flag, "geosite_auto_update", font_red..bold_on..translate("Auto Update GeoSite")..bold_off..font_off)
o.default = 0

o = s:taboption("geo_update", ListValue, "geosite_update_week_time", translate("Update Time (Every Week)"))
o:value("*", translate("Every Day"))
o:value("1", translate("Every Monday"))
o:value("2", translate("Every Tuesday"))
o:value("3", translate("Every Wednesday"))
o:value("4", translate("Every Thursday"))
o:value("5", translate("Every Friday"))
o:value("6", translate("Every Saturday"))
o:value("0", translate("Every Sunday"))
o.default = "1"
o:depends("geosite_auto_update", "1")

o = s:taboption("geo_update", ListValue, "geosite_update_day_time", translate("Update time (every day)"))
for t = 0,23 do
o:value(t, t..":00")
end
o.default = "0"
o:depends("geosite_auto_update", "1")

o = s:taboption("geo_update", Value, "geosite_custom_url")
o.title = translate("Custom GeoSite URL")
o.rmempty = true
o.description = translate("Custom GeoSite Data URL, Click Button Below To Refresh After Edit")
o:value("https://testingcf.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geosite.dat", translate("Loyalsoldier-testingcf-jsdelivr-Version")..translate("(Default)"))
o:value("https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geosite.dat", translate("Loyalsoldier-fastly-jsdelivr-Version"))
o.default = "https://testingcf.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geosite.dat"
o:depends("geosite_auto_update", "1")

o = s:taboption("geo_update", Button, translate("GEOSITE Update")) 
o.title = translate("Update GeoSite Database")
o.description = translate("Current Version:").." "..font_green..bold_on..translate(fs.get_resourse_mtime("/etc/openclash/GeoSite.dat"))..bold_off..font_off
o.inputtitle = translate("Check And Update")
o.inputstyle = "reload"
o.write = function()
  m.uci:set("openclash", "config", "enable", 1)
  m.uci:commit("openclash")
  SYS.call("/usr/share/openclash/openclash_geosite.sh >/dev/null 2>&1 &")
  HTTP.redirect(DISP.build_url("admin", "services", "openclash"))
end

o = s:taboption("geo_update", Flag, "geoasn_auto_update", font_red..bold_on..translate("Auto Update Geo ASN")..bold_off..font_off)
o.default = 0

o = s:taboption("geo_update", ListValue, "geoasn_update_week_time", translate("Update Time (Every Week)"))
o:value("*", translate("Every Day"))
o:value("1", translate("Every Monday"))
o:value("2", translate("Every Tuesday"))
o:value("3", translate("Every Wednesday"))
o:value("4", translate("Every Thursday"))
o:value("5", translate("Every Friday"))
o:value("6", translate("Every Saturday"))
o:value("0", translate("Every Sunday"))
o.default = "1"
o:depends("geoasn_auto_update", "1")

o = s:taboption("geo_update", ListValue, "geoasn_update_day_time", translate("Update time (every day)"))
for t = 0,23 do
o:value(t, t..":00")
end
o.default = "0"
o:depends("geoasn_auto_update", "1")

o = s:taboption("geo_update", Value, "geoasn_custom_url")
o.title = translate("Custom Geo ASN URL")
o.rmempty = true
o.description = translate("Custom Geo ASN Data URL, Click Button Below To Refresh After Edit")
o:value("https://testingcf.jsdelivr.net/gh/xishang0128/geoip@release/GeoLite2-ASN.mmdb", translate("xishang0128-testingcf-jsdelivr-Version")..translate("(Default)"))
o:value("https://fastly.jsdelivr.net/gh/xishang0128/geoip@release/GeoLite2-ASN.mmdb", translate("xishang0128-fastly-jsdelivr-Version"))
o.default = "https://testingcf.jsdelivr.net/gh/xishang0128/geoip@release/GeoLite2-ASN.mmdb"
o:depends("geoasn_auto_update", "1")

o = s:taboption("geo_update", Button, translate("ASN Update")) 	
o.title = translate("Update Geo ASN Database")
o.description = translate("Current Version:").." "..font_green..bold_on..translate(fs.get_resourse_mtime("/etc/openclash/ASN.mmdb"))..bold_off..font_off
o.inputtitle = translate("Check And Update")
o.inputstyle = "reload"
o.write = function()
  m.uci:set("openclash", "config", "enable", 1)
  m.uci:commit("openclash")
  SYS.call("/usr/share/openclash/openclash_geoasn.sh >/dev/null 2>&1 &")
  HTTP.redirect(DISP.build_url("admin", "services", "openclash"))
end

o = s:taboption("chnr_update", Flag, "chnr_auto_update", translate("Auto Update"))
o.description = translate("Auto Update Chnroute Lists")
o.default = 0

o = s:taboption("chnr_update", ListValue, "chnr_update_week_time", translate("Update Time (Every Week)"))
o:value("*", translate("Every Day"))
o:value("1", translate("Every Monday"))
o:value("2", translate("Every Tuesday"))
o:value("3", translate("Every Wednesday"))
o:value("4", translate("Every Thursday"))
o:value("5", translate("Every Friday"))
o:value("6", translate("Every Saturday"))
o:value("0", translate("Every Sunday"))
o.default = "1"

o = s:taboption("chnr_update", ListValue, "chnr_update_day_time", translate("Update time (every day)"))
for t = 0,23 do
o:value(t, t..":00")
end
o.default = "0"

o = s:taboption("chnr_update", Value, "chnr_custom_url")
o.title = translate("Custom Chnroute Lists URL")
o.rmempty = false
o.description = translate("Custom Chnroute Lists URL, Click Button Below To Refresh After Edit")
o:value("https://ispip.clang.cn/all_cn.txt", translate("Clang-CN")..translate("(Default)"))
o:value("https://ispip.clang.cn/all_cn_cidr.txt", translate("Clang-CN-CIDR"))
o:value("https://fastly.jsdelivr.net/gh/Hackl0us/GeoIP2-CN@release/CN-ip-cidr.txt", translate("Hackl0us-CN-CIDR-fastly-jsdelivr"))
o:value("https://testingcf.jsdelivr.net/gh/Hackl0us/GeoIP2-CN@release/CN-ip-cidr.txt", translate("Hackl0us-CN-CIDR-testingcf-jsdelivr"))
o.default = "https://ispip.clang.cn/all_cn.txt"

o = s:taboption("chnr_update", Value, "chnr6_custom_url")
o.title = translate("Custom Chnroute6 Lists URL")
o.rmempty = false
o.description = translate("Custom Chnroute6 Lists URL, Click Button Below To Refresh After Edit")
o:value("https://ispip.clang.cn/all_cn_ipv6.txt", translate("Clang-CN-IPV6")..translate("(Default)"))
o.default = "https://ispip.clang.cn/all_cn_ipv6.txt"

o = s:taboption("chnr_update", Button, translate("Chnroute Lists Update")) 
o.title = translate("Update Chnroute Lists")
o.inputtitle = translate("Check And Update")
o.inputstyle = "reload"
o.write = function()
  m.uci:set("openclash", "config", "enable", 1)
  m.uci:commit("openclash")
  SYS.call("/usr/share/openclash/openclash_chnroute.sh >/dev/null 2>&1 &")
  HTTP.redirect(DISP.build_url("admin", "services", "openclash"))
end

o = s:taboption("auto_restart", Flag, "auto_restart", translate("Auto Restart"))
o.description = translate("Auto Restart OpenClash")
o.default = 0

o = s:taboption("auto_restart", ListValue, "auto_restart_week_time", translate("Restart Time (Every Week)"))
o:value("*", translate("Every Day"))
o:value("1", translate("Every Monday"))
o:value("2", translate("Every Tuesday"))
o:value("3", translate("Every Wednesday"))
o:value("4", translate("Every Thursday"))
o:value("5", translate("Every Friday"))
o:value("6", translate("Every Saturday"))
o:value("0", translate("Every Sunday"))
o.default = "1"

o = s:taboption("auto_restart", ListValue, "auto_restart_day_time", translate("Restart time (every day)"))
for t = 0,23 do
o:value(t, t..":00")
end
o.default = "0"

---- Dashboard Settings
local cn_port=SYS.exec("uci get openclash.config.cn_port 2>/dev/null |tr -d '\n'")
o = s:taboption("dashboard", Value, "cn_port")
o.title = translate("Dashboard Port")
o.default = "9090"
o.datatype = "port"
o.rmempty = false
o.description = translate("Dashboard Address Example:").." "..font_green..bold_on..lan_ip..':'..cn_port..'/ui/yacd'..'、'..lan_ip..':'..cn_port..'/ui/dashboard'..bold_off..font_off

o = s:taboption("dashboard", Value, "dashboard_password")
o.title = translate("Dashboard Secret")
o.rmempty = true
o.description = translate("Set Dashboard Secret")

o = s:taboption("dashboard", Value, "dashboard_forward_domain")
o.title = translate("Public Dashboard Address")
o.datatype = "or(host, string)"
o.placeholder = "example.com"
o.rmempty = true
o.description = translate("Domain Name For Dashboard Login From Public Network")

o = s:taboption("dashboard", Value, "dashboard_forward_port")
o.title = translate("Public Dashboard Port")
o.datatype = "port"
o.rmempty = true
o.description = translate("Port For Dashboard Login From Public Network")

o = s:taboption("dashboard", Flag, "dashboard_forward_ssl")
o.title = translate("Public Dashboard SSL enabled")
o.default = 0
o.description = translate("Is SSL enabled For Dashboard Login From Public Network")

o = s:taboption("dashboard", DummyValue, "Dashboard", translate("Switch(Update) Dashboard Version"))
o.template="openclash/switch_dashboard"
o.rawhtml = true

o = s:taboption("dashboard", DummyValue, "Yacd", translate("Switch(Update) Yacd Version"))
o.template="openclash/switch_dashboard"
o.rawhtml = true

o = s:taboption("dashboard", DummyValue, "Metacubexd", translate("Update Metacubexd Version"))
o.template="openclash/switch_dashboard"
o.rawhtml = true

o = s:taboption("dashboard", DummyValue, "Zashboard", translate("Update Zashboard Version"))
o.template="openclash/switch_dashboard"
o.rawhtml = true

---- ipv6
o = s:taboption("ipv6", Flag, "ipv6_enable", translate("Proxy IPv6 Traffic"))
o.description = font_red..bold_on..translate("The Gateway and DNS of The Connected Device Must be The Router IP, Disable IPv6 DHCP To Avoid Abnormal Connection If You Do Not Use")..bold_off..font_off
o.default = 0

o = s:taboption("ipv6", ListValue, "ipv6_mode", translate("IPv6 Proxy Mode"))
o:value("0", translate("TProxy Mode"))
o:value("1", translate("Redirect Mode"))
o:value("2", translate("TUN Mode"))
o:value("3", translate("Mix Mode"))
o.default = "0"
o:depends("ipv6_enable", "1")

o = s:taboption("ipv6", ListValue, "stack_type_v6", translate("Select Stack Type"))
o.description = translate("Select Stack Type For TUN Mode, According To The Running Speed on Your Machine")
o:depends({ipv6_mode= "2", en_mode = "redir-host"})
o:depends({ipv6_mode= "2", en_mode = "fake-ip"})
o:depends({ipv6_mode= "3", en_mode = "redir-host"})
o:depends({ipv6_mode= "3", en_mode = "fake-ip"})
o:value("system", translate("System　"))
o:value("gvisor", translate("gVisor"))
o:value("mixed", translate("Mixed"))
o.default = "system"

o = s:taboption("ipv6", Flag, "enable_v6_udp_proxy", translate("Proxy UDP Traffics"))
o.description = translate("The Servers Must Support UDP forwarding").."<br>"..font_red..bold_on..translate("If Docker is Installed, UDP May Not Forward Normally")..bold_off..font_off
o:depends("ipv6_mode", "0")
o:depends("ipv6_mode", "1")
o.default = 1

o = s:taboption("ipv6", Flag, "ipv6_dns", translate("IPv6 DNS Resolve"))
o.description = translate("Enable to Resolve IPv6 DNS Requests")
o.default = 0

o = s:taboption("ipv6", ListValue, "china_ip6_route", translate("China IPv6 Route"))
o.description = translate("Bypass Specified Regions Network Flows, Improve Performance, If Inaccessibility on Bypass Gateway, Try to Enable Bypass Gateway Compatible Option")
o.default = 0
o:value("0", translate("Disable"))
o:value("1", translate("Bypass Mainland China"))
o:value("2", translate("Bypass Overseas"))
o:depends("ipv6_enable", "1")

o = s:taboption("ipv6", Value, "local_network6_pass", translate("Local IPv6 Network Bypassed List"))
o.template = "cbi/tvalue"
o.description = translate("The Traffic of The Destination For The Specified Address Will Not Pass The Core")
o.rows = 20
o.wrap = "off"
o:depends("ipv6_enable", "1")

function o.cfgvalue(self, section)
	return NXFS.readfile("/etc/openclash/custom/openclash_custom_localnetwork_ipv6.list") or ""
end
function o.write(self, section, value)
	if value then
		value = value:gsub("\r\n?", "\n")
		local old_value = NXFS.readfile("/etc/openclash/custom/openclash_custom_localnetwork_ipv6.list")
	  if value ~= old_value then
			NXFS.writefile("/etc/openclash/custom/openclash_custom_localnetwork_ipv6.list", value)
		end
	end
end

o = s:taboption("ipv6", Value, "chnroute6_pass", translate("Chnroute6 Bypassed List"))
o.template = "cbi/tvalue"
o.description = translate("Domains or IPs in The List Will Not be Affected by The China IP Route Option, Depend on Dnsmasq")
o.rows = 20
o.wrap = "off"
o:depends({ipv6_enable = "1", enable_redirect_dns = "1"})

function o.cfgvalue(self, section)
	return NXFS.readfile("/etc/openclash/custom/openclash_custom_chnroute6_pass.list") or ""
end
function o.write(self, section, value)
	if value then
		value = value:gsub("\r\n?", "\n")
		local old_value = NXFS.readfile("/etc/openclash/custom/openclash_custom_chnroute6_pass.list")
		if value ~= old_value then
			NXFS.writefile("/etc/openclash/custom/openclash_custom_chnroute6_pass.list", value)
		end
	end
end

---- version update
core_update = s:taboption("version_update", DummyValue, "", nil)
core_update.template = "openclash/update"

---- developer
o = s:taboption("developer", Value, "firewall_custom")
o.template = "cbi/tvalue"
o.description = translate("Custom Firewall Rules, Support IPv4 and IPv6, All Rules Will Be Added After Plugin Own Completely")
o.rows = 30
o.wrap = "off"

function o.cfgvalue(self, section)
	return NXFS.readfile("/etc/openclash/custom/openclash_custom_firewall_rules.sh") or ""
end
function o.write(self, section, value)
	if value then
		value = value:gsub("\r\n?", "\n")
		local old_value = NXFS.readfile("/etc/openclash/custom/openclash_custom_firewall_rules.sh")
		if value ~= old_value then
			NXFS.writefile("/etc/openclash/custom/openclash_custom_firewall_rules.sh", value)
		end
	end
end

---- debug
o = s:taboption("debug", DummyValue, "", nil)
o.template = "openclash/debug"

---- dlercloud
o = s:taboption("dlercloud", Value, "dler_email")
o.title = translate("Account Email Address")
o.rmempty = true

o = s:taboption("dlercloud", Value, "dler_passwd")
o.title = translate("Account Password")
o.password = true
o.rmempty = true

if fs.uci_get("config", "dler_token") then
	o = s:taboption("dlercloud", Flag, "dler_checkin")
	o.title = translate("Checkin")
	o.default = 0
	o.rmempty = true
end

o = s:taboption("dlercloud", Value, "dler_checkin_interval")
o.title = translate("Checkin Interval (hour)")
o:depends("dler_checkin", "1")
o.default = "1"
o.rmempty = true

o = s:taboption("dlercloud", Value, "dler_checkin_multiple")
o.title = translate("Checkin Multiple")
o.datatype = "uinteger"
o.default = "1"
o:depends("dler_checkin", "1")
o.rmempty = true
o.description = font_green..bold_on..translate("Multiple Must Be a Positive Integer and No More Than 100")..bold_off..font_off
function o.validate(self, value)
	if tonumber(value) < 1 then
		return "1"
	end
	if tonumber(value) > 100 then
		return "100"
	end
	return value
end

o = s:taboption("dlercloud", DummyValue, "dler_login", translate("Account Login"))
o.template = "openclash/dler_login"
if fs.uci_get("config", "dler_token") then
	o.value = font_green..bold_on..translate("Account logged in")..bold_off..font_off
else
	o.value = font_red..bold_on..translate("Account not logged in")..bold_off..font_off
end

local t = {
    {Commit, Apply}
}

local CORE_VERSION = HTTP.formvalue("CORE_VERSION")
local RELEASE_BRANCH = HTTP.formvalue("RELEASE_BRANCH")
local SMART_ENABLE = HTTP.formvalue("SMART_ENABLE")

a = m:section(Table, t)

o = a:option(Button, "Commit", " ")
o.inputtitle = translate("Commit Settings")
o.inputstyle = "apply"
o.write = function()
    if CORE_VERSION and RELEASE_BRANCH and SMART_ENABLE then
        m.uci:set("openclash", "config", "core_version", CORE_VERSION)
        m.uci:set("openclash", "config", "release_branch", RELEASE_BRANCH)
        m.uci:set("openclash", "config", "smart_enable", SMART_ENABLE)
    end
    m.uci:commit("openclash")
end

o = a:option(Button, "Apply", " ")
o.inputtitle = translate("Apply Settings")
o.inputstyle = "apply"
o.write = function()
    if CORE_VERSION and RELEASE_BRANCH and SMART_ENABLE then
        m.uci:set("openclash", "config", "core_version", CORE_VERSION)
        m.uci:set("openclash", "config", "release_branch", RELEASE_BRANCH)
        m.uci:set("openclash", "config", "smart_enable", SMART_ENABLE)
    end
    m.uci:set("openclash", "config", "enable", 1)
    m.uci:commit("openclash")
    SYS.call("/etc/init.d/openclash restart >/dev/null 2>&1 &")
    HTTP.redirect(DISP.build_url("admin", "services", "openclash"))
end

m:append(Template("openclash/config_editor"))
m:append(Template("openclash/toolbar_show"))
m:append(Template("openclash/select_git_cdn"))

return m
