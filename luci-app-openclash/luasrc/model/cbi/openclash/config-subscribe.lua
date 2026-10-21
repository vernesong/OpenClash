
local m, s, o
local openclash = "openclash"
local NXFS = require "nixio.fs"
local SYS = require "luci.sys"
local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"
local UTIL = require "luci.util"
local fs = require "luci.openclash"
local uci = require "luci.model.uci".cursor()

font_red = [[<b class="oc-txt-bad">]]
font_off = [[</b>]]
bold_on = [[<strong>]]
bold_off = [[</strong>]]

m = Map("openclash", translate("Config Subscribe"))
m.pageaction = false

-- [[ Edit Server ]] --
s = m:section(TypedSection, "config_subscribe")
s.anonymous = true
s.addremove = true
s.sortable = true
s.template = "cbi/tblsection"
s.extedit = DISP.build_url("admin/services/openclash/config-subscribe-edit/%s")
function s.create(...)
	local sid = TypedSection.create(...)
	if sid then
		HTTP.redirect(s.extedit % sid)
		return
	end
end
s.render = function(self, ...)
	Map.render(self, ...)
	if type(fs.optimize_cbi_ui) == "function" then
		fs.optimize_cbi_ui()
	end
end

---- name
o = s:option(DummyValue, "name", translate("Config Alias"))
function o.cfgvalue(...)
	return Value.cfgvalue(...) or translate("config")
end

---- address
o = s:option(TextValue, "address", translate("Subscribe Address"))
function o.cfgvalue(...)
	return Value.cfgvalue(...) or translate("None")

end
function o.validate(self, value)
	if value then
		value = value:gsub("\r\n?", "\n")
		value = value:gsub("%c*$", "")
	end
	return value
end

---- template
o = s:option(DummyValue, "template", translate("Template Name"))
function o.cfgvalue(...)
	if Value.cfgvalue(...) ~= "0" then
		return Value.cfgvalue(...) or translate("None")
	else
		return translate("Custom Template")
	end
end

---- auto update schedule
o = s:option(DummyValue, "update_schedule", translate("Auto Update"))
o.width = "14%"
function o.cfgvalue(self, section)
	local address = uci:get(openclash, section, "address")
	if not address or address == "" then
		return translate("Disabled")
	end
	local schedule = fs.config_subscribe_schedule(section, uci)
	if schedule.auto_update ~= "1" then
		return translate("Disabled")
	end
	if schedule.mode == "1" then
		return string.format("%s %s", translate("Update Interval(min)"), schedule.interval)
	end
	local hour = tonumber(schedule.hour) or 0
	if hour < 0 or hour > 23 then hour = 0 end
	local day
	if schedule.week == "*" then
		day = translate("Every Day")
	else
		local weekdays = {
			"Every Sunday", "Every Monday", "Every Tuesday", "Every Wednesday",
			"Every Thursday", "Every Friday", "Every Saturday"
		}
		local week = tonumber(schedule.week) or 0
		if week < 0 or week > 6 then week = 0 end
		day = translate(weekdays[week + 1])
	end
	return string.format("%s %02d:00", day, hour)
end

---- update
o = s:option(DummyValue, "name", translate("Update"))
o.template = "openclash/update_config"

local t = {
	{Commit, Apply}
}

a = m:section(Table, t)

o = a:option(Button, "Commit", " ")
o.inputtitle = translate("Commit Settings")
o.inputstyle = "apply"
o.write = function()
	m.uci:commit("openclash")
	uci:load("openclash")
	SYS.call("/etc/init.d/openclash reload cron >/dev/null 2>&1")
end

o = a:option(Button, "Apply", " ")
o.inputtitle = translate("Update Config")
o.inputstyle = "apply"
o.write = function()
	m.uci:set("openclash", "config", "enable", 1)
	m.uci:commit("openclash")
	SYS.call("/etc/init.d/openclash reload cron >/dev/null 2>&1")
	SYS.call("/usr/share/openclash/openclash.sh >/dev/null 2>&1 &")
	HTTP.redirect(DISP.build_url("admin", "services", "openclash"))
end

local render_children = m.render_children
m.render_children = function(self, ...)
	fs.render_page_head()
	render_children(self, ...)
end

return m
