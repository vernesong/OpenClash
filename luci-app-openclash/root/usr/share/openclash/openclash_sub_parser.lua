#!/usr/bin/lua
-- Parse subscription files (plain or base64) and extract server addresses.

local nixio = require "nixio"
local jsonc = require "luci.jsonc"
local util = require "luci.util"

if not nixio.fs.access("/usr/bin/base64") and not nixio.fs.access("/bin/base64") then
  os.exit(1)
end

local file_path = arg[1]
if not file_path or not nixio.fs.access(file_path) then
  os.exit(1)
end

local function raw_base64_decode(str)
  if not str or str == "" then return nil end
  
  str = str:gsub("-", "+"):gsub("_", "/")
  
  local padding = #str % 4
  if padding > 0 then
    str = str .. string.rep("=", 4 - padding)
  end
  
  local cmd = "printf '%s' '" .. str .. "' | base64 -d 2>/dev/null"
  local f = io.popen(cmd, "r")
  if not f then return nil end
  local result = f:read("*a")
  f:close()
  
  if result and result ~= "" then
    return result
  end
  
  return nil
end

local function base64_decode_subscription(str)
  local result = raw_base64_decode(str)
  if result and result:find("://") then
    return result
  end
  return nil
end

local function get_server_from_url(line)
    line = util.trim(line)
    local scheme, original_body = line:match("^([%w%-]+)://(.+)")
    if not scheme or not original_body then return nil end

    local server = nil
    scheme = scheme:lower()
    original_body = original_body:match("([^#]+)")

    local body_to_parse = raw_base64_decode(original_body) or original_body

    if scheme == "vmess" then
        local ok, data = pcall(jsonc.parse, body_to_parse)
        if ok and type(data) == "table" and data.add and data.add ~= "" then
            server = data.add
        end
    elseif scheme == "ss" then
        server = body_to_parse:match("[^@]+@([^:/]+)")
    elseif scheme == "ssr" then
        server = body_to_parse:match("([^:]+)")
    end
    
    if not server then
        server = body_to_parse:match("(?:[^@]+@)?([^:/]+)")
    end

    return server
end

local f = io.open(file_path, "r")
if not f then os.exit(1) end
local content = f:read("*a")
f:close()

local decoded_content = base64_decode_subscription(content:gsub("%s+", ""))
if decoded_content then
  content = decoded_content
end

for line in content:gmatch("([^\r\n]+)") do
  local server = get_server_from_url(line)
  if server and util.trim(server) ~= "" then
    print(util.trim(server))
  end
end