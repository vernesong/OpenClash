local http = require "luci.http"
local dispatcher = require "luci.dispatcher"
local fs = require "luci.openclash"
if http.getenv("REQUEST_METHOD") == "GET" and http.formvalue("tab.openclash_resources.navigation") ~= "config-backup" then
    http.redirect(dispatcher.build_url("admin", "services", "openclash", "config-backup") .. "?tab.openclash_resources.navigation=config-backup")
    return
end
local form = SimpleForm("config_backup", translate("Config Manage"))
form.template = "openclash/management_form"
form.reset, form.submit = false, false
form:append(Template("openclash/config_backup"))
local render_children = form.render_children
form.render_children = function(self, ...)
    fs.render_page_head()
    luci.template.render("openclash/config_resources")
    render_children(self, ...)
end
return form
