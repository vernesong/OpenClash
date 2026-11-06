-- Run with the OpenWrt Lua/LuCI runtime. All configuration and service writes are isolated.
local root = assert(arg[1])
local cbi = require "luci.cbi"
local http = require "luci.http"
local sys = require "luci.sys"
local uci_module = require "luci.model.uci"
local native_fs = require "nixio.fs"
local fs = require "luci.openclash"
dofile(root .. "/luci-app-openclash/luasrc/openclash.lua")
local dispatcher = require "luci.dispatcher"
local profiles = dofile(root .. "/luci-app-openclash/luasrc/openclash_profiles.lua")
package.loaded['luci.openclash_profiles'] = profiles
package.loaded['luci.openclash_resources'] = dofile(root .. "/luci-app-openclash/luasrc/openclash_resources.lua")
local directory = "/tmp/oc-profile-editor-test"
native_fs.mkdir(directory)
native_fs.mkdir(directory .. "/saved")
local real_cursor = uci_module.cursor
uci_module.cursor = function() return real_cursor(directory, directory .. "/saved") end
local parameters, handler, redirects, calls, files, writes = {}, nil, {}, {}, {}, 0
http.formvalue = function(key) return parameters[key] end
http.getenv = function(key) return key == "REQUEST_METHOD" and "GET" or nil end
http.setfilehandler = function(fn) handler = fn end
http.redirect = function(url) redirects[#redirects + 1] = url end
http.status = function(code) error("Unexpected HTTP status " .. code) end
dispatcher.build_url = function(...) return "/" .. table.concat({...}, "/") end
sys.call = function(command) calls[#calls + 1] = command; return 0 end
fs.glob = function() local out = {}; for name in pairs(files) do out[#out+1] = "/etc/openclash/config/" .. name end; return out end
fs.stat = function(path) return files[path:match("([^/]+)$")] and {type="regular",size=42,mtime=1} end
fs.access = function() return false end
fs.readfile = function(path) return files[path:match("([^/]+)$")] end
fs.writefile = function(path, content) writes = writes + 1; files[path:match("([^/]+)$")] = content; return true end
fs.config_subscribe_schedule = function(id, cursor) return {auto_update=cursor:get("openclash",id,"auto_update") or "0"} end

local function eq(a, b, label) assert(a == b, (label or "value") .. ": " .. tostring(a) .. " ~= " .. tostring(b)) end
local function load_editor(automatic, exists, local_only, overrides)
    native_fs.writefile(directory .. "/openclash", "config openclash 'config'\n option config_path '/etc/openclash/config/sample.yaml'\nconfig config_subscribe 'remote'\n option name 'sample'\n option address 'https://example.com/sub'\n option auto_update '" .. automatic .. "'\n")
    native_fs.unlink(directory .. "/saved/openclash")
    if overrides then
        local cursor = uci_module.cursor()
        for key, value in pairs(overrides) do cursor:set("openclash", "remote", key, value) end
        cursor:commit("openclash")
    end
    if local_only then
        local cursor = uci_module.cursor()
        cursor:delete("openclash", "remote")
        cursor:commit("openclash")
    end
    files = exists and {['sample.yaml']="proxies: []\n"} or {}
    parameters = {file="/etc/openclash/config/sample.yaml"}
    writes, calls, redirects = 0, {}, {}
    local env = setmetatable({arg={}, translate=require("luci.i18n").translate, translatef=string.format}, {__index=function(_, key) return cbi[key] or _G[key] end})
    local fn = assert(loadfile(root .. "/luci-app-openclash/luasrc/model/cbi/openclash/config-subscribe-edit.lua"))
    setfenv(fn, env)
    local map = fn()
    local options = {}
    for _, section in ipairs(map.children) do
        for _, option in ipairs(section.children or {}) do options[option.option] = option end
    end
    return map, options
end

local function load_model(name)
    if name == "proxy-providers-file-manage" or name == "rule-providers-file-manage" or name == "config-backup" then parameters['tab.openclash_resources.navigation'] = name end
    local env = setmetatable({arg={"config"}, translate=require("luci.i18n").translate, translatef=string.format}, {__index=function(_, key) return cbi[key] or _G[key] end})
    local fn = assert(loadfile(root .. "/luci-app-openclash/luasrc/model/cbi/openclash/" .. name .. ".lua"))
    setfenv(fn, env)
    return fn()
end

local map, options = load_editor("1", true)
eq(options._profile_flow, nil, "flow source settings are not exposed by the unified editor")
eq(options.address.rows, 4, "subscription address has room for long URLs")
eq(options.address.size, nil, "native textarea fills the available field width")
eq(options.auto_update.keylist[1], "1", "automatic update uses native Yes / No options")
eq(options.auto_update.keylist[2], "0")
eq(options.config_update_interval, nil, "individual update frequencies are not exposed")
eq(options.name.description, nil, "readonly profile name has no redundant warning")
assert(not options.sub_ua.description:find("<strong>", 1, true), "ordinary hints use native description styling")
eq(options._profile_source.readonly, true, "scheduled source readonly")
options._profile_source:write("config", "malicious")
handler({name="oc_editor_content"}, "malicious", true)
options.Commit:write("1")
map:commit_handler()
eq(writes, 0, "readonly source cannot be overwritten")
eq(#calls, 0, "failed save does not reload or restart")

map, options = load_editor("1", true, false, {config_update_interval="15"})
assert(options.auto_update.description:find("config_update_interval=15", 1, true), "retained native schedule overrides are visible")

map, options = load_editor("0", true)
eq(options._profile_source.readonly, false)
handler({name="oc_editor_content"}, "proxies: [updated]\n", true)
options.Commit:write("1")
map:commit_handler()
eq(files['sample.yaml'], "proxies: [updated]\n", "streamed source saved")
eq(#calls, 1, "save only reloads scheduler")
assert(not calls[1]:find("restart", 1, true))

map, options = load_editor("0", true)
options._profile_source:write("config", "proxies: [buffered]\r\n")
options.Apply:write("1")
map:commit_handler()
eq(files['sample.yaml'], "proxies: [buffered]\n")
eq(#calls, 2, "explicit apply restarts")
assert(calls[2]:find("restart", 1, true))

map, options = load_editor("0", false)
eq(options._profile_source.readonly, true, "missing source readonly")
eq(options.Apply, nil, "cannot apply missing profile")
assert(options._update, "missing subscription can be retried")
map, options = load_editor("0", true, true)
eq(options.auto_update, nil, "local files have no remote update policy")
eq(options._profile_source.readonly, false, "local source editable")
eq(options._profile_running, nil, "inactive profile has no runtime preview")
local saved_running_name = profiles.running_name
profiles.running_name = function() return "sample.yaml" end
map, options = load_editor("0", true, true)
eq(options._profile_running.readonly, true, "active runtime always readonly")
profiles.running_name = saved_running_name

local function submit(map, options)
    parameters['cbi.submit'] = "1"
    for name, option in pairs(options) do
        local section = option.section.section or "1"
        local value = option:cfgvalue(section) or option.default
        if value then parameters[option:cbid(section)] = value end
        if option.enabled ~= nil and option.disabled ~= nil then
            parameters['cbi.cbe.openclash.' .. section .. '.' .. name] = "1"
            if tostring(value) == "0" then parameters[option:cbid(section)] = nil end
        end
    end
    parameters[options.Commit:cbid("1")] = "1"
end

map, options = load_editor("0", true)
submit(map, options)
parameters[options._profile_source:cbid("config")] = "proxies: [parsed]\n"
map:parse()
eq(map.save, true, "valid CBI form saves")
eq(files['sample.yaml'], "proxies: [parsed]\n", "real CBI parse reaches save handler")

map, options = load_editor("0", true)
submit(map, options)
parameters[options.auto_update:cbid("remote")] = "1"
handler({name="oc_editor_content"}, "proxies: [discarded]\n", true)
map:parse()
eq(uci_module.cursor():get("openclash", "remote", "auto_update"), "1", "enabling updates must persist using the native option")
eq(writes, 0, "enabling updates does not save local source")

map, options = load_editor("0", true)
submit(map, options)
parameters[options.address:cbid("remote")] = ""
parameters[options._profile_source:cbid("config")] = "must not save"
map:parse()
eq(map.save, false, "invalid subscription rejected")
eq(writes, 0, "invalid form does not save file")
eq(#calls, 0, "invalid form does not restart")

load_editor("1", true)
fs.uci_get_config = function(section, key) return uci_module.cursor():get("openclash", section, key) end

local original_realpath = native_fs.realpath
fs.get_file_path_from_request = function() return "/etc/openclash/./config/sample.yaml" end
native_fs.realpath = function() return "/etc/openclash/config/sample.yaml" end
handler = nil
load_model("other-file-edit")
eq(handler, nil, "legacy editor redirects before installing write handler")
assert(redirects[#redirects]:find("config%-edit"))
load_editor("1", true)
local server_map = load_model("servers")
for _, section in ipairs(server_map.children) do
    for _, option in ipairs(section.children or {}) do
        if option.option == "Apply" then option:write("1") end
    end
end
eq(server_map.save, false, "servers editor cannot apply protected source")
eq(#calls, 0, "servers editor does not invoke YAML writer")
native_fs.realpath = original_realpath
print("PASS independent editor, source policy, streaming, save/apply boundaries")

for _, resource in ipairs({"proxy-providers-file-manage", "rule-providers-file-manage"}) do
    files = {['sample.yaml']="payload", ['geoip.mrs']="binary"}
    local form = load_model(resource)
    form.readinput = true
    local option = form.children[1].children[4]
    eq(option.option, "apply", "submit field is distinct from the action payload")
    parameters["cbid." .. option.map.config .. ".2.actions"] = "edit"
    local before = #redirects
    option:write(2)
    eq(#redirects, before + 1, "provider edit dispatches from the shared action column")
    assert(redirects[#redirects]:find(resource, 1, true))
    parameters["cbid." .. option.map.config .. ".1.actions"] = "edit"
    option:write(1)
    eq(#redirects, before + 1, "binary MRS editing is rejected server-side")
end
print("PASS provider action dispatch and binary edit protection")

load_editor("0", true)
local original_running = profiles.running_name
profiles.running_name = function() return "sample.yaml" end
local running_form = load_model("config")
local running_action = running_form.children[1].children[8]
local original_unlink = fs.unlink
local deleted = 0
fs.unlink = function() deleted = deleted + 1 end
parameters['cbid.table.1.actions'] = 'remove'
running_action:write(1)
eq(deleted, 0, "running configuration cannot be removed by a forged form submission")
fs.unlink = original_unlink
profiles.running_name = function() return "different.yaml" end
local inactive_form = load_model("config")
parameters['cbid.table.1.actions'] = 'download_run'
local original_open = nixio.open
nixio.open = function() error("inactive running-config download must not open a file") end
inactive_form.children[1].children[8]:write(1)
nixio.open = original_open
profiles.running_name = original_running
print("PASS running configuration action guards")

load_editor("1", true)
files['sample.yml'] = "local variant"
local refs = 0
local original_refs = fs.config_refs
fs.config_refs = function(_, _, preserve) refs = refs + 1; eq(preserve, true, "shared subscription metadata is preserved") end
fs.unlink = function() return true end
profiles.running_name = function() return nil end
local variant_forms = {load_model("config")}
parameters['cbid.table.2.actions'] = 'remove'
variant_forms[1].children[1].children[8]:write(2)
eq(refs, 1, "local extension removal still maintains file-specific references")
fs.config_refs = original_refs
profiles.running_name = original_running

load_editor("0", true)
local schedule = require("luci.openclash_resources").schedule()
parameters = {['cbi.submit']='1', ['cbid.table.1.apply']='1'}
schedule:parse()
eq(uci_module.cursor():get('openclash', 'config', 'auto_update'), nil, 'row actions cannot save the independent global schedule')
eq(#calls, 0, 'row actions cannot reload the schedule')
parameters = {['cbi.submit']='1', ['cbid.table.1.CommitSchedule']='1',
    ['cbid.openclash.config.auto_update']='1', ['cbid.openclash.config.config_auto_update_mode']='1',
    ['cbid.openclash.config.config_update_interval']='30'}
schedule = require("luci.openclash_resources").schedule()
schedule:parse()
eq(uci_module.cursor():get('openclash', 'config', 'config_update_interval'), '30', 'global schedule uses the existing UCI interval')
eq(#calls, 1, 'saving global settings reloads cron once')
assert(calls[1]:find('reload cron', 1, true) and not calls[1]:find('restart', 1, true))
print("PASS independent global schedule saves without restarting the core")

if arg[2] then
    local template = require "luci.template"
    local util = require "luci.util"
    local i18n = require "luci.i18n"
    local parser = require "luci.template.parser"
    i18n.i18ndir = directory .. "/"
    i18n.setlanguage(arg[2])
    local function attribute(condition, key, value, env)
        if not condition then return "" end
        if type(value) == "table" then
            if not next(value) then return "" end
            value = util.serialize_json(value)
        end
        local scope = type(env.self) == "table" and env.self or {}
        value = value or (type(env[key]) ~= "function" and env[key]) or (type(scope[key]) ~= "function" and scope[key]) or ""
        return ' ' .. key .. '="' .. util.pcdata(tostring(value)) .. '"'
    end
    template.context.viewns = setmetatable({
        write = http.write,
        include = function(name) template.render(name, getfenv(2)) end,
        translate = i18n.translate, translatef = i18n.translatef,
        pcdata = util.pcdata, striptags = util.striptags,
        attr = function(key, value) return attribute(true, key, value, getfenv(2)) end,
        ifattr = function(condition, key, value) return attribute(condition, key, value, getfenv(2)) end,
        url = dispatcher.build_url, media="/luci-static/bootstrap", resource="/luci-static/resources",
        export = function(key, value) template.context.viewns[key] = value end,
    }, {__index=_G})
    local render = template.render
    template.render = function(name, scope)
        local source = native_fs.readfile(root .. "/luci-app-openclash/luasrc/view/" .. name .. ".htm")
        if source then return template.Template(nil, source):render(scope or getfenv(2)) end
        return render(name, scope or getfenv(2))
    end
    fs.render_page_head = function() http.write('<script src="/cgi-bin/luci/admin/services/openclash/translate_js?f=common"></script>') end
    for _, case in ipairs({{"0", true, false, "0"}, {"1", true, false, "1"}, {"0", true, true, "local"}, {"1", false, false, "pending"}}) do
        map, options = load_editor(case[1], case[2], case[3])
        map.title = "sample.yaml"
        parameters = {file="/etc/openclash/config/sample.yaml"}
        local output = assert(io.open(directory .. "/editor-" .. arg[2] .. "-" .. case[4] .. ".html", "w"))
        http.write = function(value) output:write(value or "") end
        template.context.viewns.write = http.write
        output:write('<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="stylesheet" href="/luci-static/bootstrap/cascade.css"><link rel="stylesheet" href="/luci-static/resources/openclash/css/oc-common.css"><script src="/luci-static/resources/cbi.js"></script><script src="/luci-static/resources/xhr.js"></script></head><body><main class="container"><h2>sample.yaml</h2><form>')
        map:prepare()
        map:render_children()
        output:write('</form></main><script>cbi_init();</script></body></html>')
        output:close()
        assert(native_fs.readfile(directory .. "/editor-" .. arg[2] .. "-" .. case[4] .. ".html"):find("form.action = '/admin/services/openclash/config-edit?file=", 1, true), "editor form must preserve the profile query parameter")
        assert(native_fs.readfile(directory .. "/editor-" .. arg[2] .. "-" .. case[4] .. ".html"):find('id="tab.openclash_resources.navigation.config" class="cbi-tab"', 1, true), "native config tab must be active")
    end
    load_editor("1", true)
    local forms = {load_model("config")}
    local output = assert(io.open(directory .. "/list-" .. arg[2] .. ".html", "w"))
    http.write = function(value) output:write(value or "") end
    template.context.viewns.write = http.write
    output:write('<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="stylesheet" href="/luci-static/bootstrap/cascade.css"><link rel="stylesheet" href="/luci-static/resources/openclash/css/oc-common.css"><script src="/luci-static/resources/cbi.js"></script><script src="/luci-static/resources/xhr.js"></script></head><body><main class="container"><h2>Config Manage</h2>')
    for _, form in ipairs(forms) do output:write('<form><div id="cbi-' .. form.config .. '">'); form:prepare(); form:render_children(); output:write('</div></form>') end
    output:write('</main><script>cbi_init();</script></body></html>')
    output:close()
    local list_html = native_fs.readfile(directory .. "/list-" .. arg[2] .. ".html")
    assert(list_html:find('class="cbi-map-descr"', 1, true) < list_html:find('class="cbi-tabmenu"', 1, true), "shared notes precede the resource tabs")
    assert(list_html:find('/admin/services/openclash/config-backup', 1, true), "backup is a separate resource tab")
    eq(#forms, 2, "configuration list and global schedule have independent forms")
    assert(not list_html:find('Configuration has not been downloaded', 1, true), "download availability is not a configuration state")
    assert(not list_html:find('id="ulfile"', 1, true), "legacy upload block is removed")
    assert(list_html:find('<option value="update">', 1, true), "remote configuration update is in the overflow menu")
    assert(list_html:find("no_restart:'1'", 1, true), "manual updates never apply or restart implicitly")
    for _, resource in ipairs({"proxy-providers-file-manage", "rule-providers-file-manage"}) do
        files = {['sample.yaml']="payload", ['geoip.mrs']="binary"}
        local form = load_model(resource)
        output = assert(io.open(directory .. "/" .. resource .. ".html", "w"))
        http.write = function(value) output:write(value or "") end
        template.context.viewns.write = http.write
        output:write('<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="/luci-static/bootstrap/cascade.css"><link rel="stylesheet" href="/luci-static/resources/openclash/css/oc-common.css"><script src="/luci-static/resources/cbi.js"></script></head><body><main class="container"><form>')
        form:prepare()
        form:render_children()
        output:write('</form></main><script>cbi_init();</script></body></html>')
        output:close()
        assert(native_fs.readfile(directory .. "/" .. resource .. ".html"):find('id="tab.openclash_resources.navigation.' .. resource .. '" class="cbi-tab"', 1, true), "native provider resource tab must be active")
    end
    local backup = load_model("config-backup")
    output = assert(io.open(directory .. "/backup-" .. arg[2] .. ".html", "w"))
    http.write = function(value) output:write(value or "") end
    template.context.viewns.write = http.write
    backup:prepare()
    backup:render_children()
    output:close()
    local backup_html = native_fs.readfile(directory .. "/backup-" .. arg[2] .. ".html")
    local _, nodes = backup_html:gsub('class="cbi%-section%-node"', '')
    eq(nodes, 2, "backup and restore reuse the system page's native section nodes")
    assert(backup_html:find('class="cbi-button cbi-button-apply"', 1, true), "archive generation uses the native system button")
    assert(not backup_html:find('class="footer-btn"', 1, true), "backup introduces no custom button styling")
    for _, name in ipairs({"common", "editors", "config_upload", "subconverter-version"}) do
        output = assert(io.open(directory .. "/" .. name .. ".js", "w"))
        http.write = function(value) output:write(value or "") end
        template.context.viewns.write = http.write
        template.Template(nil, assert(native_fs.readfile(root .. "/luci-app-openclash/root/www/luci-static/resources/openclash/js/" .. name .. ".js"))):render({})
        output:close()
    end
    print("PASS native CBI render " .. arg[2])
end
