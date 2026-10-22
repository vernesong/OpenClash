local profiles = dofile(arg[1] .. "/luci-app-openclash/luasrc/openclash_profiles.lua")
local files, subscriptions, current, global = {}, {}, nil, {}
local fs = {
    glob = function() local out = {}; for name in pairs(files) do out[#out+1] = "/etc/openclash/config/"..name end; return out end,
    stat = function(path) return files[path:match("([^/]+)$")] end,
    is_safe_filename = function(name) return name ~= "" and not name:find("/", 1, true) and not name:find("..", 1, true) end,
    config_subscribe_schedule = function(id, uci)
        return {auto_update = uci:get("openclash", id, "auto_update") or global.auto_update or "0"}
    end
}
local uci = {
    foreach = function(_, _, kind, fn) if kind == "config_subscribe" then for _, s in ipairs(subscriptions) do fn(s) end end end,
    get = function(_, _, id, option)
        if id == "config" then return option == "config_path" and current or global[option] end
        for _, s in ipairs(subscriptions) do if s['.name'] == id then return s[option] end end
    end
}
local function reset() files = {}; subscriptions = {}; global = {}; current = nil end
local function sub(name, auto, enabled) subscriptions[#subscriptions+1] = {['.name']="cfg"..#subscriptions, name=name, address="https://example.com/sub",auto_update=auto,enabled=enabled} end
local function file(name) files[name] = {type="regular",size=123,mtime=100} end
local function eq(actual, expected, label) assert(actual == expected, (label or "value")..": expected "..tostring(expected)..", got "..tostring(actual)) end
reset(); file("local.yaml"); file("local.yaml.backup.1"); current="/etc/openclash/config/local.yaml"
local rows=profiles.list(fs,uci); eq(#rows,1,"YAML only"); eq(rows[1].remote,false); eq(rows[1].current,true); eq(rows[1].editable,true)
reset(); sub("pending","1"); rows=profiles.list(fs,uci); eq(#rows,1); eq(rows[1].exists,false); eq(rows[1].editable,false); eq(rows[1].remote,true)
reset(); sub("remote","1"); file("remote.yaml"); rows=profiles.list(fs,uci); eq(#rows,1); eq(rows[1].editable,false); eq(rows[1].automatic,true)
subscriptions[1].auto_update="0"; eq(profiles.list(fs,uci)[1].editable,true,"native automatic update setting controls editing")
subscriptions[1].auto_update="1"; subscriptions[1].enabled="0"; eq(profiles.list(fs,uci)[1].editable,false,"retired enabled flag is ignored by current upstream")
subscriptions[1].enabled="1"; global.auto_update="0"; eq(profiles.list(fs,uci)[1].editable,false,"own schedule wins")
subscriptions[1].auto_update=nil; global.auto_update="1"; eq(profiles.list(fs,uci)[1].editable,false,"legacy schedule")
global.auto_update="0"; eq(profiles.list(fs,uci)[1].automatic,false,"missing native flag inherits global default")
reset(); sub("both","1"); file("both.yaml"); file("both.yml"); rows=profiles.list(fs,uci); eq(#rows,2); for _,r in ipairs(rows) do eq(r.remote,r.name=="both.yaml","only updater destination is remote"); eq(r.editable,r.name=="both.yml","extension variant remains independent") end
reset(); sub("only-yml","1"); file("only-yml.yml"); rows=profiles.list(fs,uci); eq(#rows,2,"subscription destination remains a separate pending YAML entry")
reset(); sub("duplicate","1"); sub("duplicate","0"); file("duplicate.yaml"); rows=profiles.list(fs,uci); eq(rows[1].editable,false,"duplicate records fail closed")
eq(profiles.writable("/etc/openclash/config/../bad.yaml",fs,uci),false,"path traversal")
eq(profiles.writable("/etc/openclash/config/remote.yaml/child",fs,uci),false,"nested path")
reset(); sub("locked","1"); file("locked.yaml"); eq(profiles.writable("/etc/openclash/config/locked.yaml",fs,uci),false)
reset(); file("editable.yml"); eq(profiles.writable("/etc/openclash/config/editable.yml",fs,uci),true)
reset(); sub("uppercase","1"); file("uppercase.YML"); eq(profiles.writable("/etc/openclash/config/uppercase.YML",fs,uci),true,"uppercase extension is not the updater destination")
reset(); sub("","1"); file("config.yaml"); eq(profiles.writable("/etc/openclash/config/config.yaml",fs,uci),false,"empty alias uses updater default")
print("PASS config profile projection and source write policy")
local process_fs = {readfile=function(path) return path == '/proc/123/cmdline' and '/etc/openclash/clash\0-d\0/etc/openclash\0-f\0/etc/openclash/active.yaml\0' or '' end}
eq(profiles.running_name(process_fs, {exec=function() return '123 456' end}), 'active.yaml', 'running configuration comes from the process, not selected UCI state')
eq(profiles.running_name(process_fs, {exec=function() return '' end}), nil, 'stopped core has no running configuration')

local source_file = assert(io.open(arg[1] .. "/luci-app-openclash/luasrc/openclash.lua"))
local source = source_file:read("*a"); source_file:close()
local helper = assert(source:match("(function config_refs%([^\n]+\n.-)\n%-%-%- Effective auto update"))
local records = {
    config_subscribe={{['.name']='sub', name='same'}},
    subscribe_info={{['.name']='info', name='same'}},
    config_age_secret={{['.name']='secret', name='same'}},
    proxy_groups={{['.name']='group', config='same.yml'}},
    proxy_providers={{['.name']='provider', config='same.yml'}},
    proxies={{['.name']='proxy', config='same.yml'}}
}
local changed = {}
local ref_cursor = {
    foreach=function(_, _, kind, fn) for _, item in ipairs(records[kind] or {}) do fn(item) end end,
    set=function(_, _, sid, key, value) changed[sid] = value end,
    delete=function(_, _, sid) changed[sid] = 'deleted' end,
    commit=function() end
}
local fn = assert(loadstring(helper .. "\nreturn config_refs"))
setfenv(fn, setmetatable({uci=ref_cursor, basename=function(p) return p:match('([^/]+)$') end,
    filename=function(p) return p:gsub('%.[^.]+$', '') end, isfile=function() return false end}, {__index=_G}))
local refs = fn()
refs('same.yml', nil, true)
eq(changed.sub, nil, 'extension variant preserves subscription')
eq(changed.info, nil, 'extension variant preserves subscription metadata')
eq(changed.secret, nil, 'extension variant preserves shared secret')
eq(changed.group, 'deleted', 'extension variant still removes file-specific group references')
eq(changed.provider, 'deleted'); eq(changed.proxy, 'deleted')
changed = {}
refs('same.yml', 'renamed.yml', false)
eq(changed.group, 'renamed.yml', 'ordinary local renames retain reference maintenance')
print('PASS shared subscription metadata and local reference maintenance')
