local M = {}
local cbi = require "luci.cbi"
local fs = require "luci.openclash"
local nixio = require "nixio"
local http = require "luci.http"
local dispatcher = require "luci.dispatcher"
local translate = require("luci.i18n").translate

function M.form(kind)
    assert(kind == "proxy" or kind == "rule")
    local route = kind == "proxy" and "proxy-providers-file-manage" or "rule-providers-file-manage"
    local directory = "/etc/openclash/" .. kind .. "_provider/"
    local url = dispatcher.build_url("admin", "services", "openclash", route)
    local selected = "?tab.openclash_resources.navigation=" .. route
    if http.getenv("REQUEST_METHOD") == "GET" and http.formvalue("tab.openclash_resources.navigation") ~= route then
        http.redirect(url .. selected)
        return
    end
    local rows = {}
    for _, path in ipairs(fs.glob(directory .. "*")) do
        local stat = fs.stat(path)
        if stat and stat.type == "regular" then
            rows[#rows+1] = {name=fs.basename(path), mtime=os.date("%Y-%m-%d %H:%M:%S", stat.mtime), size=fs.filesize(stat.size)}
        end
    end
    table.sort(rows, function(a, b) return a.name < b.name end)
    local form = cbi.SimpleForm(kind .. "_provider_file_list", translate("Config Manage"))
    form.template = "openclash/management_form"
    form.reset, form.submit = false, false
    local list = form:section(cbi.Table, rows)
    list:option(cbi.DummyValue, "name", translate("File Name"))
    list:option(cbi.DummyValue, "mtime", translate("Update Time"))
    list:option(cbi.DummyValue, "size", translate("Size"))
    local actions = list:option(cbi.Button, "apply", translate("Actions"))
    actions.template = "openclash/config_actions"
    actions.render = function(self, index, scope)
        if not rows[index] then return end
        scope = scope or {}
        scope.config_name = rows[index].name
        scope.config_script = not self.script_rendered
        scope.row_actions = {}
        if not rows[index].name:lower():match("%.mrs$") then scope.row_actions[#scope.row_actions+1] = {"edit", "Edit"} end
        scope.row_actions[#scope.row_actions+1] = {"download", "Download"}
        scope.row_actions[#scope.row_actions+1] = {"remove", "Remove"}
        self.script_rendered = true
        cbi.Button.render(self, index, scope)
    end
    actions.write = function(self, index)
        local row = rows[index]
        if not row then return end
        local action = self.map:formvalue("cbid." .. self.map.config .. "." .. index .. ".actions")
        local path = directory .. fs.basename(row.name)
        if action == "edit" and not row.name:lower():match("%.mrs$") then
            http.redirect(dispatcher.build_url("admin", "services", "openclash", "other-file-edit", route) .. "?file=" .. http.urlencode(path))
        elseif action == "download" then
            local fd = nixio.open(path, "r")
            if not fd then return end
            http.header("Content-Disposition", 'attachment; filename="' .. row.name .. '"')
            http.prepare_content("application/octet-stream")
            while true do
                local block = fd:read(nixio.const.buffersize)
                if not block or #block == 0 then break end
                http.write(block)
            end
            fd:close()
            http.close()
        elseif action == "remove" then
            fs.unlink(path)
            http.redirect(url .. selected)
        end
    end
    form:append(cbi.Template("openclash/config_upload"))
    local render_children = form.render_children
    form.render_children = function(self, ...)
        fs.render_page_head()
        luci.template.render("openclash/config_resources")
        luci.template.render("openclash/config_add", {resource_kind=kind})
        render_children(self, ...)
    end
    return form
end

function M.schedule()
    local form = cbi.Map("openclash")
    form.template = "openclash/management_form"
    form.pageaction = false
    local settings = form:section(cbi.NamedSection, "config", "openclash", translate("Global Update Frequency"))
    settings.description = translate("Subscriptions inherit these defaults unless they have explicit overrides. Per-subscription Auto Update and existing frequency overrides take precedence.")
    local option = settings:option(cbi.ListValue, "auto_update", translate("Default Auto Update"))
    option:value("1", translate("Yes"))
    option:value("0", translate("No"))
    option.default, option.rmempty = "0", false
    option = settings:option(cbi.ListValue, "config_auto_update_mode", translate("Update Mode"))
    option:value("0", translate("Appointment Mode"))
    option:value("1", translate("Loop Mode"))
    option.default = "0"
    option:depends("auto_update", "1")
    option = settings:option(cbi.ListValue, "config_update_week_time", translate("Update Time (Every Week)"))
    option:value("*", translate("Every Day"))
    for day, label in ipairs({"Every Monday", "Every Tuesday", "Every Wednesday", "Every Thursday", "Every Friday", "Every Saturday"}) do option:value(tostring(day), translate(label)) end
    option:value("0", translate("Every Sunday"))
    option.default = "1"
    option:depends({auto_update="1", config_auto_update_mode="0"})
    option = settings:option(cbi.ListValue, "auto_update_time", translate("Update time (every day)"))
    for hour=0,23 do option:value(tostring(hour), hour .. ":00") end
    option.default = "0"
    option:depends({auto_update="1", config_auto_update_mode="0"})
    option = settings:option(cbi.Value, "config_update_interval", translate("Update Interval(min)"))
    option.default = "60"
    option.datatype = "and(uinteger, min(1), max(525600))"
    option:depends({auto_update="1", config_auto_update_mode="1"})
    local save = form:section(cbi.Table, {{}}):option(cbi.Button, "CommitSchedule", " ")
    save.inputtitle, save.inputstyle = translate("Commit Settings"), "apply"
    local requested = false
    save.write = function() requested = true end
    local parse = form.parse
    form.parse = function(self, ...)
        if not http.formvalue("cbid.table.1.CommitSchedule") then
            self.readinput = false
            self.state = cbi.FORM_NODATA
            return self.state
        end
        return parse(self, true, ...)
    end
    form.commit_handler = function(self)
        if requested then
            self.uci:commit("openclash")
            require("luci.sys").call("/etc/init.d/openclash reload cron >/dev/null 2>&1")
            http.redirect(dispatcher.build_url("admin", "services", "openclash", "config"))
        end
    end
    return form
end

return M
