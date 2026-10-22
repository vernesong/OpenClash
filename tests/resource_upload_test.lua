-- Execute the real upload handler with all filesystem paths redirected to fixtures.
local root = assert(arg[1])
local native = require "nixio.fs"
local nixio = require "nixio"
local source = assert(native.readfile(root .. "/luci-app-openclash/luasrc/controller/openclash.lua"))
local handler_source = assert(source:match("(function action_upload_config%(%)\n.-)\nfunction action_restore_backup"))
local directory = "/tmp/oc-resource-upload-test"
native.mkdir(directory)
local uploaded, parameters, handler, response, status, protected, calls
local function path(value) return directory .. "/" .. value:gsub("/", "_") end
local env = setmetatable({
    nixio = nixio,
    HTTP = {
        formvalue = function(key, query)
            if query then return parameters[key] end
            handler({name="config_file", file=uploaded.name}, uploaded.body, true)
        end,
        setfilehandler = function(fn) handler = fn end,
        prepare_content = function() end,
        write_json = function(value) response = value end,
        status = function(code) status = code end
    },
    SYS = {call=function() calls = calls + 1; return 0 end},
    fs = {
        unlink=function(value) return native.unlink(path(value)) end,
        rename=function(a, b) return native.rename(path(a), path(b)) end,
        filesize=function(value) return tostring(value) end
    },
    io = {open=function(value, mode) return io.open(path(value), mode) end},
    uci = {},
    is_safe_filename=function(name) return not name:find("[/\\]") and name ~= "." and name ~= ".." end,
    require=function(name)
        if name == "luci.openclash_profiles" then return {find=function() return protected and {editable=false} or nil end} end
        return require(name)
    end
}, {__index=_G})
local fn = assert(loadstring(handler_source .. "\nreturn action_upload_config"))
setfenv(fn, env)
local upload = fn()
local function run(kind, name, body, locked)
    parameters, uploaded, protected = {resource=kind}, {name=name, body=body}, locked
    response, status, calls = nil, nil, 0
    upload()
    return response
end
local existing = path("/etc/openclash/config/sample.yaml")
native.writefile(existing, "old content")
assert(run("config", "sample.yaml", "not a configuration").status == "error")
assert(native.readfile(existing) == "old content", "invalid upload preserves the previous configuration")
assert(run("config", "sample.yaml", "proxies: []", true).status == "error")
assert(native.readfile(existing) == "old content", "automatic source cannot be overwritten")
assert(run("config", "sample.yaml", "proxies: []").status == "success")
assert(native.readfile(existing) == "proxies: []")
assert(run("proxy", "sample.yaml", "proxies: []").status == "success")
assert(run("rule", "sample.mrs", "\0binary\255").status == "success")
assert(native.readfile(path("/etc/openclash/rule_provider/sample.mrs")) == "\0binary\255")
assert(run("rule", "sample.lua", "payload").status == "error")
run("../../tmp", "sample.yaml", "payload")
assert(status == 400 and calls == 0, "resource targets use a fixed allowlist")
assert(run("rule", "../sample.mrs", "payload").status == "error")
local create_source = assert(source:match("(function create_file%(%)\n.-)\nfunction rename_file"))
env.plugin_file_dirs = {['/etc/openclash/config/']=true, ['/etc/openclash/rule_provider/']=true}
env.HTTP.formvalue = function(key) return parameters[key] end
env.fs.access = function(value) return native.access(path(value)) end
env.fs.isfile = env.fs.access
env.fs.writefile = function(value, content) return native.writefile(path(value), content) end
fn = assert(loadstring(create_source .. "\nreturn create_file"))
setfenv(fn, env)
local create = fn()
parameters, protected, status = {filename="sample.yaml", filepath="/etc/openclash/config/"}, false, nil
create()
assert(status == 409 and native.readfile(existing) == "proxies: []", "create cannot truncate an existing file")
parameters, protected, status = {filename="pending.yaml", filepath="/etc/openclash/config/"}, true, nil
create()
assert(status == 409 and not native.access(path("/etc/openclash/config/pending.yaml")), "create cannot bypass subscription policy")
print("PASS shared uploads, binary providers, source policy, failure preservation and path allowlist")
local rename_source = assert(source:match("(function rename_file%(%)\n.-)\nfunction manual_stream_unlock_test"))
fn = assert(loadstring(rename_source .. "\nreturn rename_file"))
setfenv(fn, env)
parameters, status = {file_path="/etc/openclash/config/", file_name="sample.yaml", new_file_name="sample.txt"}, nil
fn()()
assert(status == 400 and native.readfile(existing) == "proxies: []", "rename rejects non-YAML targets before changing files")
print("PASS server-side configuration rename extension guard")
