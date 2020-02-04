
local m, s, o
local openclash = "openclash"
local NXFS = require "nixio.fs"
local SYS  = require "luci.sys"
local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"
local UTIL = require "luci.util"
local fs = require "luci.openclash"
local uci = require "luci.model.uci".cursor()

m = Map(openclash,  translate("Game Rules and Groups"))
m.pageaction = false
m.description=translate("注意事项：<br/>游戏代理为测试功能，不保证可用性。其中游戏模式使用的内核由comzyh修改 \
<br/>项目地址：https://github.com/comzyh/clash <br/>使用步骤： \
<br/>1、在《服务器与策略组管理》页面创建您准备使用的游戏策略组和游戏节点（节点添加时必须选择要加入的策略组），策略组类型建议:FallBack，游戏节点必须支持UDP \
<br/>2、在此页面的游戏规则列表下载您要使用的游戏规则 \
<br/>3、在此页面上方设置您已下载的游戏规则的对应策略组并保存设置 \
<br/>4、替换内核一，下载地址：https://github.com/Dreamacro/clash/releases/tag/TUN \
<br/>或替换内核二，下载地址：https://github.com/vernesong/OpenClash/releases/tag/TUN \
<br/>5、在《全局设置》-《常规设置》-《运行模式》中选择TUN模式（内核一）或者游戏模式（内核二）并启动")


function IsRuleFile(e)
e=e or""
local e=string.lower(string.sub(e,-6,-1))
return e==".rules"
end

if not NXFS.access("/tmp/rules_name") then
   SYS.call("awk -F ',' '{print $1}' /etc/openclash/game_rules.list > /tmp/rules_name 2>/dev/null")
end
file = io.open("/tmp/rules_name", "r");

-- [[ Edit Game Rule ]] --
s = m:section(TypedSection, "game_config")
s.anonymous = true
s.addremove = true
s.sortable = false
s.template = "cbi/tblsection"
s.rmempty = false

---- enable flag
o = s:option(Flag, "enabled", translate("Enable"))
o.rmempty     = false
o.default     = o.enabled
o.cfgvalue    = function(...)
    return Flag.cfgvalue(...) or "1"
end

---- rule name
o = s:option(DynamicList, "rule_name", translate("Game Rule's Name"))
local e,a={}
for t,f in ipairs(fs.glob("/etc/openclash/game_rules/*"))do
	a=fs.stat(f)
	if a then
    e[t]={}
    e[t].filename=fs.basename(f)
    if IsRuleFile(e[t].filename) then
       e[t].name=luci.sys.exec(string.format("grep -F '%s' /etc/openclash/game_rules.list |awk -F ',' '{print $1}' 2>/dev/null",e[t].filename))
       o:value(e[t].name)
    end
  end
end
   
o.rmempty = true

---- Proxy Group
o = s:option(ListValue, "group", translate("Select Proxy Group"))
uci:foreach("openclash", "groups",
		function(s)
		  if s.name ~= "" and s.name ~= nil then
			   o:value(s.name)
			end
		end)
o:value("DIRECT")
o:value("REJECT")
o.rmempty = true

---- Rules List
local e={},o,t
if NXFS.access("/tmp/rules_name") then
for o in file:lines() do
table.insert(e,o)
end
for t,o in ipairs(e) do
e[t]={}
e[t].num=string.format(t)
e[t].name=o
e[t].filename=string.sub(luci.sys.exec(string.format("grep -F '%s,' /etc/openclash/game_rules.list |awk -F ',' '{print $3}' 2>/dev/null",e[t].name)),1,-2)
if e[t].filename == "" then
e[t].filename=string.sub(luci.sys.exec(string.format("grep -F '%s,' /etc/openclash/game_rules.list |awk -F ',' '{print $2}' 2>/dev/null",e[t].name)),1,-2)
end
RULE_FILE="/etc/openclash/game_rules/".. e[t].filename
if fs.mtime(RULE_FILE) then
e[t].mtime=os.date("%Y-%m-%d %H:%M:%S",fs.mtime(RULE_FILE))
else
e[t].mtime="/"
end
if fs.isfile(RULE_FILE) then
   e[t].exist=translate("Exist")
else
   e[t].exist=translate("Not Exist")
end
e[t].remove=0
end
end
file:close()

form=SimpleForm("filelist",  translate("Game Rules List"))
form.description=translate("规则项目: SSTap-Rule ( https://github.com/FQrabbit/SSTap-Rule )<br/>")
form.reset=false
form.submit=false
tb=form:section(Table,e)
nu=tb:option(DummyValue,"num",translate("Order Number"))
st=tb:option(DummyValue,"exist",translate("State"))
nm=tb:option(DummyValue,"name",translate("Rule Name"))
fm=tb:option(DummyValue,"filename",translate("File Name"))
mt=tb:option(DummyValue,"mtime",translate("Update Time"))

btnis=tb:option(DummyValue,"filename",translate("Download Rule"))
btnis.template="openclash/download_game_rule"

btnrm=tb:option(Button,"remove",translate("Remove"))
btnrm.render=function(e,t,a)
e.inputstyle="reset"
Button.render(e,t,a)
end
btnrm.write=function(a,t)
fs.unlink("/etc/openclash/game_rules/"..e[t].filename)
HTTP.redirect(DISP.build_url("admin", "services", "openclash", "game-settings"))
end

local t = {
    {Commit, Apply}
}

ss = m:section(Table, t)

o = ss:option(Button, "Commit") 
o.inputtitle = translate("Commit Configurations")
o.inputstyle = "apply"
o.write = function()
  m.uci:commit("openclash")
end

o = ss:option(Button, "Apply")
o.inputtitle = translate("Apply Configurations")
o.inputstyle = "apply"
o.write = function()
  m.uci:set("openclash", "config", "enable", 1)
  m.uci:commit("openclash")
  SYS.call("/etc/init.d/openclash restart >/dev/null 2>&1 &")
  HTTP.redirect(DISP.build_url("admin", "services", "openclash"))
end

return m, form
