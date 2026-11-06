local root = assert(arg[1]) .. "/luci-app-openclash/luasrc/"
local fs = require "nixio.fs"
local parser = require "luci.template.parser"
local count = 0
local function scan(directory)
    for name in fs.dir(directory) do
        local path = directory .. "/" .. name
        if fs.stat(path, "type") == "dir" then scan(path)
        elseif name:match("%.lua$") and name:sub(1, 1) ~= "." then assert(loadfile(path)); count = count + 1 end
    end
end
scan(root)
for _, name in ipairs({"config_resources", "config_add", "config_actions", "sub_info_show", "update_config", "profile_editor", "config_back", "management_form", "config_backup", "config_editor", "config_upload"}) do
    local fn, code, message = parser.parse(root .. "view/openclash/" .. name .. ".htm")
    assert(fn, tostring(code) .. ": " .. tostring(message))
end
print("PASS " .. count .. " Lua modules and 11 LuCI templates compile")
