
local NXFS = require "nixio.fs"
local SYS  = require "luci.sys"
local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"
local UTIL = require "luci.util"
local fs = require "luci.openclash"
local uci = require "luci.model.uci".cursor()
local json = require "luci.jsonc"
local datatype = require "luci.cbi.datatypes"

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

local op_mode = string.sub(luci.sys.exec('uci get openclash.config.operation_mode 2>/dev/null'),0,-2)
if not op_mode then op_mode = "redir-host" end
local lan_ip = fs.lanip()
m = Map("openclash", translate("Overwrite Settings"))
m.pageaction = false
m.description = translate("Note: To restore the default configuration, try accessing:").." <a href='javascript:void(0)' onclick='javascript:restore_config(this)'>http://"..lan_ip.."/cgi-bin/luci/admin/services/openclash/restore</a>"..
"<br/>"..font_green..translate("For More Useful Meta Core Functions Go Wiki")..": "..font_off.."<a href='javascript:void(0)' onclick='javascript:return winOpen(\"https://wiki.metacubex.one/\")'>"..translate("https://wiki.metacubex.one/").."</a>"

s = m:section(TypedSection, "openclash")
s.anonymous = true

s:tab("settings", translate("General Settings"))
s:tab("dns", "DNS "..translate("Settings"))
s:tab("meta", translate("Meta Settings"))
s:tab("smart", translate("Smart Settings"))
s:tab("rules", translate("Rules Setting"))
s:tab("developer", translate("Developer Settings"))

----- General Settings
o = s:taboption("settings", ListValue, "interface_name", translate("Bind Network Interface"))
local de_int = SYS.exec("ip route |grep 'default' |awk '{print $5}' 2>/dev/null") or SYS.exec("/usr/share/openclash/openclash_get_network.lua 'dhcp'")
o.description = translate("Default Interface Name:").." "..font_green..bold_on..de_int..bold_off..font_off..translate(",Try Enable If Network Loopback")
local interfaces = SYS.exec("ls -l /sys/class/net/ 2>/dev/null |awk '{print $9}' 2>/dev/null")
for interface in string.gmatch(interfaces, "%S+") do
   o:value(interface)
end
o:value("0", translate("Disable"))
o.default = "0"

o = s:taboption("settings", Value, "tolerance", translate("URL-Test Group Tolerance").."(ms)")
o.description = translate("Switch To The New Proxy When The Delay Difference Between Old and The Fastest Currently is Greater Than This Value")
o:value("0", translate("Disable"))
o:value("100")
o:value("150")
o.datatype = "uinteger"
o.default = "0"

o = s:taboption("settings", Value, "urltest_interval_mod", translate("URL-Test Interval Modify").."(s)")
o.description = translate("Modify The URL-Test Interval In The Config")
o:value("0", translate("Disable"))
o:value("180")
o:value("300")
o.datatype = "uinteger"
o.default = "0"

o = s:taboption("settings", Value, "urltest_address_mod", translate("URL-Test Address Modify"))
o.description = translate("Modify The URL-Test Address In The Config")
o:value("0", translate("Disable"))
o:value("http://www.gstatic.com/generate_204")
o:value("http://cp.cloudflare.com/generate_204")
o:value("https://cp.cloudflare.com/generate_204")
o:value("http://captive.apple.com/generate_204")
o.default = "0"

o = s:taboption("settings", Value, "github_address_mod", translate("Github Address Modify"))
o.description = translate("Modify The Github Address In The Config And OpenClash With Proxy(CDN) To Prevent File Download Faild. Format Reference:").." ".."<a href='javascript:void(0)' onclick='javascript:return winOpen(\"https://ghfast.top/\")'>https://ghfast.top/</a>"
o:value("0", translate("Disable"))
o:value("https://fastly.jsdelivr.net/")
o:value("https://testingcf.jsdelivr.net/")
o:value("https://cdn.jsdelivr.net/")
o.default = "0"

o = s:taboption("settings", ListValue, "log_level", translate("Log Level"))
o.description = translate("Select Core's Log Level")
o:value("0", translate("Disable"))
o:value("info", translate("Info Mode"))
o:value("warning", translate("Warning Mode"))
o:value("error", translate("Error Mode"))
o:value("debug", translate("Debug Mode"))
o:value("silent", translate("Silent Mode"))
o.default = "0"

o = s:taboption("settings", Value, "dns_port")
o.title = translate("DNS Port")
o.default = "7874"
o.datatype = "port"
o.rmempty = false
o.description = translate("Please Make Sure Ports Available")

o = s:taboption("settings", Value, "proxy_port")
o.title = translate("Redir Port")
o.default = "7892"
o.datatype = "port"
o.rmempty = false
o.description = translate("Please Make Sure Ports Available")

o = s:taboption("settings", Value, "tproxy_port")
o.title = translate("TProxy Port")
o.default = "7895"
o.datatype = "port"
o.rmempty = false
o.description = translate("Please Make Sure Ports Available")

o = s:taboption("settings", Value, "http_port")
o.title = translate("HTTP(S) Port")
o.default = "7890"
o.datatype = "port"
o.rmempty = false
o.description = translate("Please Make Sure Ports Available")

o = s:taboption("settings", Value, "socks_port")
o.title = translate("SOCKS5 Port")
o.default = "7891"
o.datatype = "port"
o.rmempty = false
o.description = translate("Please Make Sure Ports Available")

o = s:taboption("settings", Value, "mixed_port")
o.title = translate("Mixed Port")
o.default = "7893"
o.datatype = "port"
o.rmempty = false
o.description = translate("Please Make Sure Ports Available")

---- DNS Settings

o = s:taboption("dns", Flag, "enable_custom_dns", font_red..bold_on..translate("Custom DNS Setting")..bold_off..font_off)
o.description = font_red..bold_on..translate("Set OpenClash Upstream DNS Resolve Server")..bold_off..font_off
o.default = 0

o = s:taboption("dns", Flag, "enable_respect_rules", font_red..bold_on..translate("Respect Rules").."(respect-rules)"..bold_off..font_off)
o.description = font_red..bold_on..translate("Whether or not The Connection to the DNS Server Follow the Rules in Config")..bold_off..font_off
o.default = 0

o = s:taboption("dns", Flag, "append_wan_dns", translate("Append Upstream DNS"))
o.description = translate("Append The Upstream Assigned DNS And Gateway IP To The Nameserver")
o.default = 1

o = s:taboption("dns", Flag, "append_default_dns", translate("Append Default DNS"))
o.description = translate("Automatically Append Compliant DNS to default-nameserver")
o.default = 1

if op_mode == "fake-ip" then
o = s:taboption("dns", Value, "fakeip_range", translate("Fake-IP Range (IPv4 Cidr)"))
o.description = translate("Set Fake-IP Range (IPv4 Cidr)")
o:value("0", translate("Disable"))
o:value("198.18.0.1/16")
o.default = "0"
o.placeholder = "198.18.0.1/16"
function o.validate(self, value)
	if value == "0" then
		return "0"
	end
	if datatype.cidr4(value) then
		return value
	end
	return "198.18.0.1/16"
end

o = s:taboption("dns", Flag, "store_fakeip", translate("Persistence Fake-IP"))
o.description = font_red..bold_on..translate("Cache Fake-IP DNS Resolution Records To File, Improve The Response Speed After Startup")..bold_off..font_off
o.default = 1

end

o = s:taboption("dns", Flag, "custom_fallback_filter", translate("Fallback-Filter"))
o.description = translate("Take Effect If Fallback DNS Setted, Prevent DNS Pollution")
o.default = 0

custom_fallback_filter = s:taboption("dns", Value, "custom_fallback_fil")
custom_fallback_filter.template = "cbi/tvalue"
custom_fallback_filter.rows = 20
custom_fallback_filter.wrap = "off"
custom_fallback_filter:depends("custom_fallback_filter", "1")

function custom_fallback_filter.cfgvalue(self, section)
	return NXFS.readfile("/etc/openclash/custom/openclash_custom_fallback_filter.yaml") or ""
end
function custom_fallback_filter.write(self, section, value)
	if value then
		value = value:gsub("\r\n?", "\n")
		local old_value = NXFS.readfile("/etc/openclash/custom/openclash_custom_fallback_filter.yaml")
	  if value ~= old_value then
			NXFS.writefile("/etc/openclash/custom/openclash_custom_fallback_filter.yaml", value)
		end
	end
end

if op_mode == "fake-ip" then
o = s:taboption("dns", Flag, "custom_fakeip_filter", translate("Fake-IP-Filter"))
o.default = 0

o = s:taboption("dns", ListValue, "custom_fakeip_filter_mode", translate("Fake-IP-Filter-Mode"))
o.description = translate("Fake-IP is not returned if the matching succeeds when blacklist mode or Fake-IP is returned if the matching succeeds when whitelist mode")
o.default = "blacklist"
o:value("blacklist", translate("Blacklist Mode"))
o:value("whitelist", translate("Whitelist Mode"))
o:depends("custom_fakeip_filter", "1")

custom_fake_black = s:taboption("dns", Value, "custom_fake_filter")
custom_fake_black.template = "cbi/tvalue"
custom_fake_black.description = translate("Domain Names In The List Do Not Return Fake-IP, One rule per line")
custom_fake_black.rows = 20
custom_fake_black.wrap = "off"
custom_fake_black:depends("custom_fakeip_filter", "1")

function custom_fake_black.cfgvalue(self, section)
	return NXFS.readfile("/etc/openclash/custom/openclash_custom_fake_filter.list") or ""
end
function custom_fake_black.write(self, section, value)
	if value then
		value = value:gsub("\r\n?", "\n")
		local old_value = NXFS.readfile("/etc/openclash/custom/openclash_custom_fake_filter.list")
	  if value ~= old_value then
			NXFS.writefile("/etc/openclash/custom/openclash_custom_fake_filter.list", value)
		end
	end
end
end

o = s:taboption("dns", Flag, "custom_name_policy", translate("Nameserver-Policy"))
o.default = 0

custom_domain_dns_policy = s:taboption("dns", Value, "custom_domain_dns_core")
custom_domain_dns_policy.template = "cbi/tvalue"
custom_domain_dns_policy.description = translate("Domain Names In The List Use The Custom DNS Server, But Still Return Fake-IP Results, One rule per line")
custom_domain_dns_policy.rows = 20
custom_domain_dns_policy.wrap = "off"
custom_domain_dns_policy:depends("custom_name_policy", "1")

function custom_domain_dns_policy.cfgvalue(self, section)
	return NXFS.readfile("/etc/openclash/custom/openclash_custom_domain_dns_policy.list") or ""
end
function custom_domain_dns_policy.write(self, section, value)
	if value then
		value = value:gsub("\r\n?", "\n")
		local old_value = NXFS.readfile("/etc/openclash/custom/openclash_custom_domain_dns_policy.list")
	  if value ~= old_value then
			NXFS.writefile("/etc/openclash/custom/openclash_custom_domain_dns_policy.list", value)
		end
	end
end

o = s:taboption("dns", Flag, "custom_host", translate("Hosts"))
o.default = 0

custom_hosts = s:taboption("dns", Value, "custom_hosts")
custom_hosts.template = "cbi/tvalue"
custom_hosts.description = translate("Custom Hosts Here, You May Need to Turn off The Rebinding Protection Option of Dnsmasq When Hosts Has Set a Reserved Address, For More Go:").." ".."<a href='javascript:void(0)' onclick='javascript:return winOpen(\"https://lancellc.gitbook.io/clash/clash-config-file/dns/host\")'>https://lancellc.gitbook.io/clash/clash-config-file/dns/host</a>"
custom_hosts.rows = 20
custom_hosts.wrap = "off"
custom_hosts:depends("custom_host", "1")

function custom_hosts.cfgvalue(self, section)
	return NXFS.readfile("/etc/openclash/custom/openclash_custom_hosts.list") or ""
end
function custom_hosts.write(self, section, value)
	if value then
		value = value:gsub("\r\n?", "\n")
		local old_value = NXFS.readfile("/etc/openclash/custom/openclash_custom_hosts.list")
	  if value ~= old_value then
			NXFS.writefile("/etc/openclash/custom/openclash_custom_hosts.list", value)
		end
	end
end

-- Meta
o = s:taboption("meta", Flag, "enable_tcp_concurrent", font_red..bold_on..translate("Enable Tcp Concurrent")..bold_off..font_off)
o.description = font_red..bold_on..translate("TCP Concurrent Request IPs, Choose The Lowest Latency One To Connection")..bold_off..font_off
o.default = "0"

o = s:taboption("meta", Flag, "enable_unified_delay", font_red..bold_on..translate("Enable Unified Delay")..bold_off..font_off)
o.description = font_red..bold_on..translate("Change The Delay Calculation Method To Remove Extra Delays Such as Handshaking")..bold_off..font_off
o.default = "0"

o = s:taboption("meta", ListValue, "find_process_mode", translate("Enable Process Rule"))
o.description = translate("Whether to Enable Process Rules, Only Works on Routerself, If You Are Not Sure, Please Choose off Which Useful in Router Environment, Depend on kmod-inet-diag")
o:value("0", translate("Disable"))
o:value("off", translate("OFF　"))
o:value("always", translate("Always　"))
o:value("strict", translate("strict　"))
o.default = "0"

o = s:taboption("meta", ListValue, "global_client_fingerprint", translate("Client Fingerprint"))
o.description = translate("Change The Client Fingerprint, Only Support TLS Transport in TCP/GRPC/WS/HTTP For Vless/Vmess and Trojan")
o:value("0", translate("Disable"))
o:value("none", translate("None　"))
o:value("random", translate("Random"))
o:value("chrome", translate("Chrome"))
o:value("firefox", translate("Firefox"))
o:value("safari", translate("Safari"))
o:value("ios", translate("IOS"))
o:value("android", translate("Android"))
o:value("edge", translate("Edge"))
o:value("360", translate("360"))
o:value("qq", translate("QQ"))
o.default = "0"

o = s:taboption("meta", ListValue, "geodata_loader", translate("Geodata Loader Mode"))
o:value("0", translate("Disable"))
o:value("memconservative", translate("Memconservative"))
o:value("standard", translate("Standard"))
o.default = "0"

o = s:taboption("meta", Flag, "enable_geoip_dat", translate("Enable GeoIP Dat"))
o.description = translate("Replace GEOIP MMDB With GEOIP Dat, Large Size File")..", "..font_red..bold_on..translate("Need Download First")..bold_off..font_off
o.default = 0

o = s:taboption("meta", Flag, "enable_meta_sniffer", font_red..bold_on..translate("Enable Sniffer")..bold_off..font_off)
o.description = font_red..bold_on..translate("Sniffer Will Prevent Domain Name Proxy and DNS Hijack Failure")..bold_off..font_off
o.default = 1

o = s:taboption("meta", Flag, "enable_meta_sniffer_pure_ip", translate("Forced Sniff Pure IP"))
o.description = translate("Forced Sniff Pure IP Connections")
o.default = 1
o:depends("enable_meta_sniffer", "1")

o = s:taboption("meta", Flag, "enable_meta_sniffer_custom", translate("Custom Sniffer Settings"))
o.description = translate("Custom The Force and Skip Sniffing Doamin Lists")
o.default = 0
o:depends("enable_meta_sniffer", "1")

sniffer_custom = s:taboption("meta", Value, "sniffer_custom")
sniffer_custom:depends("enable_meta_sniffer_custom", "1")
sniffer_custom.template = "cbi/tvalue"
sniffer_custom.rows = 20
sniffer_custom.wrap = "off"

function sniffer_custom.cfgvalue(self, section)
	return NXFS.readfile("/etc/openclash/custom/openclash_custom_sniffer.yaml") or ""
end
function sniffer_custom.write(self, section, value)
	if value then
		value = value:gsub("\r\n?", "\n")
		local old_value = NXFS.readfile("/etc/openclash/custom/openclash_custom_sniffer.yaml")
	  if value ~= old_value then
			NXFS.writefile("/etc/openclash/custom/openclash_custom_sniffer.yaml", value)
		end
	end
end

-- Smart Settings
o = s:taboption("smart", Flag, "auto_smart_switch", font_red..bold_on..translate("Smart Auto Switch")..bold_off..font_off)
o.description = font_red..bold_on..translate("Auto Switch Url-test and Load-balance Group to Smart Group")..bold_off..font_off
o.default = 0

o = s:taboption("smart", ListValue, "smart_strategy", translate("Node Select Strategy"))
o:value("sticky-sessions", translate("Sticky-sessions"))
o:value("round-robin", translate("Round-robin"))
o.default = "sticky-sessions"
o:depends("auto_smart_switch", "1")
o.description = translate("Before Node Data Collect Completely, The Default is Sticky-sessions")

o = s:taboption("smart", Value, "smart_policy_priority", translate("Policy Priority"))
o.default = ""
o.placeholder = "Premium:0.9;SG:1.3"
o.description = translate("Nodes Weight Priority, <1 Means Lower Priority, >1 Means Higher Priority, The Default is 1, Pattern Support Regex and String")

o = s:taboption("smart", Flag, "smart_collect", translate("Colletct Training Data"))
o.default = 0

o = s:taboption("smart", Value, "smart_collect_size", translate("Data Colletct File Size (MB)"))
o.default = 100
o:depends("smart_collect", "1")
o.description = translate("Limit The File Size of Collected Data, The Default is 100MB")

o = s:taboption("smart", Value, "smart_collect_rate", translate("Data Colletct Rate"))
o.default = 1
o:depends("smart_collect", "1")
o.description = translate("Data Acquisition Rate, Desirable Values are 0-1, The Default is 1")

o = s:taboption("smart", Flag, "lgbm_auto_update", translate("Auto Update LightGBM Model"))
o.default = 0

o = s:taboption("smart", Value, "lgbm_update_interval", translate("Update Interval(hour)"))
o.default = "72"
o:depends("lgbm_auto_update", "1")

o = s:taboption("smart", Value, "lgbm_custom_url")
o.title = translate("Custom Model URL")
o.rmempty = true
o.description = translate("Custom LightGBM Model URL, Click Button Below To Refresh After Edit")
o:value("https://github.com/vernesong/mihomo/releases/download/LightGBM-Model/Model.bin", translate("Light Version").." "..translate("(Default)"))
o:value("https://github.com/vernesong/mihomo/releases/download/LightGBM-Model/Model-middle.bin", translate("Middle Version"))
o:value("https://github.com/vernesong/mihomo/releases/download/LightGBM-Model/Model-large.bin", translate("Large Version"))
o.default = "https://github.com/vernesong/mihomo/releases/download/LightGBM-Model/Model.bin"
o:depends("lgbm_auto_update", "1")

o = s:taboption("smart", Button, translate("Model Update"))
o.description = translate("Current Version:").." "..font_green..bold_on..translate(fs.get_resourse_mtime("/etc/openclash/Model.bin"))..bold_off..font_off
o.title = translate("Update Model")
o.inputtitle = translate("Check And Update")
o.inputstyle = "reload"
o.write = function()
  m.uci:set("openclash", "config", "enable", 1)
  m.uci:commit("openclash")
  SYS.call("/usr/share/openclash/openclash_lgbm.sh >/dev/null 2>&1 &")
  HTTP.redirect(DISP.build_url("admin", "services", "openclash"))
end

o = s:taboption("smart", DummyValue, "flush_smart_cache", translate("Flush Smart Cache"))
o.template = "openclash/flush_smart_cache"

---- Rules Settings
o = s:taboption("rules", Flag, "rule_source", translate("Enable Other Rules"))
o.description = translate("Use Other Rules")
o.default = 0

o = s:taboption("rules", Flag, "enable_rule_proxy", translate("Rule Match Proxy Mode"))
o.description = translate("Append Some Rules to Config, Allow Only Traffic Proxies that Match the Rule, Prevent BT/P2P Passing")
o.default = 0

o = s:taboption("rules", Flag, "enable_custom_clash_rules", font_red..bold_on..translate("Custom Clash Rules")..bold_off..font_off)
o.description = translate("Use Custom Rules")
o.default = 0

custom_rules = s:taboption("rules", Value, "custom_rules")
custom_rules:depends("enable_custom_clash_rules", 1)
custom_rules.template = "cbi/tvalue"
custom_rules.description = font_green..bold_on..translate("(Priority)")..bold_off..font_off.." "..translate("Custom Rules Here, For More Go:").." ".."<a href='javascript:void(0)' onclick='javascript:return winOpen(\"https://wiki.metacubex.one/config/rules/\")'>https://wiki.metacubex.one/config/rules/</a>".." ,"..translate("IP To CIDR:").." ".."<a href='javascript:void(0)' onclick='javascript:return winOpen(\"http://ip2cidr.com\")'>http://ip2cidr.com</a>"
custom_rules.rows = 20
custom_rules.wrap = "off"

function custom_rules.cfgvalue(self, section)
	return NXFS.readfile("/etc/openclash/custom/openclash_custom_rules.list") or ""
end
function custom_rules.write(self, section, value)
	if value then
		value = value:gsub("\r\n?", "\n")
		local old_value = NXFS.readfile("/etc/openclash/custom/openclash_custom_rules.list")
	  if value ~= old_value then
			NXFS.writefile("/etc/openclash/custom/openclash_custom_rules.list", value)
		end
	end
end

custom_rules_2 = s:taboption("rules", Value, "custom_rules_2")
custom_rules_2:depends("enable_custom_clash_rules", 1)
custom_rules_2.template = "cbi/tvalue"
custom_rules_2.description = font_green..bold_on..translate("(Extended)")..bold_off..font_off.." "..translate("Custom Rules Here, For More Go:").." ".."<a href='javascript:void(0)' onclick='javascript:return winOpen(\"https://wiki.metacubex.one/config/rules/\")'>https://wiki.metacubex.one/config/rules/</a>".." ,"..translate("IP To CIDR:").." ".."<a href='javascript:void(0)' onclick='javascript:return winOpen(\"http://ip2cidr.com\")'>http://ip2cidr.com</a>"
custom_rules_2.rows = 20
custom_rules_2.wrap = "off"

function custom_rules_2.cfgvalue(self, section)
	return NXFS.readfile("/etc/openclash/custom/openclash_custom_rules_2.list") or ""
end
function custom_rules_2.write(self, section, value)
	if value then
		value = value:gsub("\r\n?", "\n")
		local old_value = NXFS.readfile("/etc/openclash/custom/openclash_custom_rules_2.list")
	  if value ~= old_value then
			NXFS.writefile("/etc/openclash/custom/openclash_custom_rules_2.list", value)
		end
	end
end

---- developer
o = s:taboption("developer", Value, "ymchange_custom")
o.template = "cbi/tvalue"
o.description = translate("Custom Config Overwrite Scripts Which Will Run After Plugin Own Completely, Please Be Careful, The Wrong Changes May Lead to Exceptions")
o.rows = 30
o.wrap = "off"

function o.cfgvalue(self, section)
	return NXFS.readfile("/etc/openclash/custom/openclash_custom_overwrite.sh") or ""
end
function o.write(self, section, value)
	if value then
		value = value:gsub("\r\n?", "\n")
		local old_value = NXFS.readfile("/etc/openclash/custom/openclash_custom_overwrite.sh")
		if value ~= old_value then
			NXFS.writefile("/etc/openclash/custom/openclash_custom_overwrite.sh", value)
		end
	end
end

-- [[ Edit Custom DNS ]] --
ds = m:section(TypedSection, "dns_servers", translate("Add Custom DNS Servers")..translate("(Take Effect After Choose Above)"))
ds.anonymous = true
ds.addremove = true
ds.sortable = true
ds.template = "openclash/tblsection_dns"
ds.extedit = luci.dispatcher.build_url("admin/services/openclash/custom-dns-edit/%s")
function ds.create(...)
	local sid = TypedSection.create(...)
	if sid then
		luci.http.redirect(ds.extedit % sid)
		return
	end
end

---- enable flag
o = ds:option(Flag, "enabled", translate("Enable"))
o.rmempty     = false
o.default     = o.enabled
o.cfgvalue    = function(...)
    return Flag.cfgvalue(...) or "1"
end

---- group
o = ds:option(ListValue, "group", translate("DNS Server Group"))
o:value("nameserver", translate("NameServer "))
o:value("fallback", translate("FallBack "))
o:value("default", translate("Default-NameServer"))
o.default     = "nameserver"
o.rempty      = false

---- IP address
o = ds:option(Value, "ip", translate("DNS Server Address"))
o.placeholder = translate("Not Null")
o.datatype = "or(host, string)"
o.rmempty = true

---- port
o = ds:option(Value, "port", translate("DNS Server Port"))
o.datatype    = "port"
o.rempty      = true

---- type
o = ds:option(ListValue, "type", translate("DNS Server Type"))
o:value("udp", translate("UDP"))
o:value("tcp", translate("TCP"))
o:value("tls", translate("TLS"))
o:value("https", translate("HTTPS"))
o:value("quic", translate("QUIC"))
o.default     = "udp"
o.rempty      = false

---- Disable-IPv6
o = ds:option(Flag, "disable_ipv6", translate("Disable-IPv6"))
o.rmempty     = false
o.default     = o.disbled

-- [[ Other Rules Manage ]]--
ss = m:section(TypedSection, "other_rules", translate("Other Rules Edit")..translate("(Take Effect After Choose Above)"))
ss.anonymous = true
ss.addremove = true
ss.sortable = true
ss.template = "cbi/tblsection"
ss.extedit = luci.dispatcher.build_url("admin/services/openclash/other-rules-edit/%s")
function ss.create(...)
	local sid = TypedSection.create(...)
	if sid then
		luci.http.redirect(ss.extedit % sid)
		return
	end
end
ss.render = function(self, ...)
	Map.render(self, ...)
	if type(optimize_cbi_ui) == "function" then
		optimize_cbi_ui()
	end
end

o = ss:option(Flag, "enabled", translate("Enable"))
o.rmempty     = false
o.default     = o.enabled
o.cfgvalue    = function(...)
    return Flag.cfgvalue(...) or "1"
end

o = ss:option(DummyValue, "config", translate("Config File"))
function o.cfgvalue(...)
	return Value.cfgvalue(...) or translate("None")
end

o = ss:option(DummyValue, "rule_name", translate("Other Rules Name"))
function o.cfgvalue(...)
	if Value.cfgvalue(...) == "lhie1" then
		return translate("lhie1 Rules")
	else
		return translate("None")
	end
end

o = ss:option(DummyValue, "Note", translate("Note"))
function o.cfgvalue(...)
	return Value.cfgvalue(...) or translate("None")
end

-- [[ Edit Authentication ]] --
s = m:section(TypedSection, "authentication", translate("Set Authentication of SOCKS5/HTTP(S)"))
s.anonymous = true
s.addremove = true
s.sortable = false
s.template = "cbi/tblsection"
s.rmempty = false
s.render = function(self, ...)
	Map.render(self, ...)
	if type(optimize_cbi_ui) == "function" then
		optimize_cbi_ui()
	end
end

---- enable flag
o = s:option(Flag, "enabled", translate("Enable"))
o.rmempty     = false
o.default     = o.enabled
o.cfgvalue    = function(...)
    return Flag.cfgvalue(...) or "1"
end

---- username
o = s:option(Value, "username", translate("Username"))
o.placeholder = translate("Not Null")
o.rempty      = true

---- password
o = s:option(Value, "password", translate("Password"))
o.placeholder = translate("Not Null")
o.rmempty = true

local t = {
    {Commit, Apply}
}

a = m:section(Table, t)

o = a:option(Button, "Commit", " ")
o.inputtitle = translate("Commit Settings")
o.inputstyle = "apply"
o.write = function()
  m.uci:commit("openclash")
end

o = a:option(Button, "Apply", " ")
o.inputtitle = translate("Apply Settings")
o.inputstyle = "apply"
o.write = function()
  m.uci:set("openclash", "config", "enable", 1)
  m.uci:commit("openclash")
  SYS.call("/etc/init.d/openclash restart >/dev/null 2>&1 &")
  HTTP.redirect(DISP.build_url("admin", "services", "openclash"))
end

m:append(Template("openclash/config_editor"))
m:append(Template("openclash/toolbar_show"))

return m
