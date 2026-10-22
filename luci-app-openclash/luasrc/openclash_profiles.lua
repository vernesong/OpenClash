local M = {}
local directory = "/etc/openclash/config/"

function M.auto_update(sub, default)
    local value = sub.auto_update
    if value == nil or value == "" then value = default end
    return tostring(value or "0") == "1"
end

function M.running_name(fs, sys)
    for pid in (sys.exec("pidof clash_meta 2>/dev/null") or ""):gmatch("%d+") do
        local command = fs.readfile("/proc/" .. pid .. "/cmdline") or ""
        local path = command:match("%-f%z([^%z]+)")
        local name = path and path:match("^/etc/openclash/([^/]+)$")
        if name and name:lower():match("%.ya?ml$") then return name end
    end
end

function M.list(fs, uci)
    local rows, by_name = {}, {}
    local current = uci:get("openclash", "config", "config_path")
    local function add(name)
        if by_name[name] then return by_name[name] end
        local stat = fs.stat(directory .. name)
        local row = {name = name, path = directory .. name, exists = stat ~= nil and stat.type == "regular",
            stat = stat, remote = false, automatic = false, subscriptions = {}, current = current == directory .. name}
        rows[#rows + 1], by_name[name] = row, row
        return row
    end
    for _, path in ipairs(fs.glob(directory .. "*")) do
        local name = path:match("([^/]+)$")
        if name and name:lower():match("%.ya?ml$") and fs.is_safe_filename(name) then add(name) end
    end
    uci:foreach("openclash", "config_subscribe", function(sub)
        local name = sub.name and sub.name ~= "" and sub.name or "config"
        if not fs.is_safe_filename(name) then return end
        do
            local row = add(name .. ".yaml")
            row.remote = true
            row.subscriptions[#row.subscriptions + 1] = sub['.name']
            row.sid = row.subscriptions[1]
            row.automatic = row.automatic or (M.auto_update(sub, uci:get("openclash", "config", "auto_update")) and sub.address ~= nil and sub.address ~= "")
            row.ambiguous = #row.subscriptions > 1
        end
    end)
    for _, row in ipairs(rows) do
        row.editable = row.exists and not row.automatic and not row.ambiguous
        local destination = by_name[row.name:gsub("%.[^.]+$", "") .. ".yaml"]
        row.preserve_subscription = not row.remote and destination ~= nil and destination.remote
    end
    table.sort(rows, function(a, b) return a.name < b.name end)
    return rows
end

function M.find(path, fs, uci)
    local name = type(path) == "string" and path:match("^/etc/openclash/config/([^/]+)$")
    if not name or not name:lower():match("%.ya?ml$") or not fs.is_safe_filename(name) then return nil end
    for _, row in ipairs(M.list(fs, uci)) do
        if row.name == name then return row end
    end
end

function M.writable(path, fs, uci)
    local row = M.find(path, fs, uci)
    return row ~= nil and row.editable == true
end

return M
