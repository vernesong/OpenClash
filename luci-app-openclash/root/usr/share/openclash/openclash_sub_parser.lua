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

local function url_decode(str)
  return str:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
end

local function parse_query_params(query_string)
  local params = {}
  if not query_string then return params end
  
  for param in query_string:gmatch("([^&]+)") do
    local key, value = param:match("([^=]*)=?(.*)")
    if key then
      params[key] = url_decode(value or "")
    end
  end
  return params
end

local function parse_url(url_str)
  local scheme, rest = url_str:match("^([%w%-]+)://(.+)")
  if not scheme then return nil end
  
  local userinfo, host_part = rest:match("^([^@]+)@(.+)")
  if not userinfo then
    userinfo = ""
    host_part = rest
  end
  
  local path_query_fragment = host_part:match("^[^/]*(.*)") or ""
  local host_port = host_part:match("^([^/]*)")
  
  local host, port = host_port:match("^%[([^%]]+)%]:(%d+)") -- IPv6
  if not host then
    host, port = host_port:match("^([^:]+):(%d+)")
  end
  if not host then
    host = host_port
    port = nil
  end
  
  local path, query_fragment = path_query_fragment:match("^([^?]*)(.*)")
  path = path or ""
  
  local query, fragment
  if query_fragment then
    if query_fragment:sub(1,1) == "?" then
      query, fragment = query_fragment:sub(2):match("^([^#]*)(.*)")
      if fragment and fragment:sub(1,1) == "#" then
        fragment = fragment:sub(2)
      end
    elseif query_fragment:sub(1,1) == "#" then
      fragment = query_fragment:sub(2)
    end
  end
  
  local username, password = userinfo:match("^([^:]*):?(.*)")
  
  return {
    scheme = scheme:lower(),
    username = username or "",
    password = password or "",
    host = host,
    port = port,
    path = path,
    query = query,
    fragment = fragment
  }
end

local function get_server_from_url(line)
    line = util.trim(line)
    local scheme, original_body = line:match("^([%w%-]+)://(.+)")
    if not scheme or not original_body then return nil end

    local server = nil
    scheme = scheme:lower()
    
    if scheme == "vmess" then
        -- fragment
        original_body = original_body:match("([^#]+)") or original_body
        
        -- base64
        local decoded = raw_base64_decode(original_body)
        if decoded then
            -- V2RayN JSON
            local ok, data = pcall(jsonc.parse, decoded)
            if ok and type(data) == "table" and data.add and data.add ~= "" then
                server = data.add
            end
        else
            -- Xray VMessAEAD
            local url_parts = parse_url(line)
            if url_parts and url_parts.host then
                server = url_parts.host
            end
        end
        
    elseif scheme == "vless" then
        local url_parts = parse_url(line)
        if url_parts and url_parts.host then
            server = url_parts.host
        end
        
    elseif scheme == "trojan" then
        local url_parts = parse_url(line)
        if url_parts and url_parts.host then
            server = url_parts.host
        end
        
    elseif scheme == "ss" then
        local url_parts = parse_url(line)
        if url_parts and url_parts.host then
            server = url_parts.host
        else
            -- ss://base64
            original_body = original_body:match("([^#]+)") or original_body
            local decoded = raw_base64_decode(original_body)
            if decoded then
                server = decoded:match("@([^:/]+)")
            else
                server = original_body:match("[^@]+@([^:/]+)")
            end
        end
        
    elseif scheme == "ssr" then
        original_body = original_body:match("([^#]+)") or original_body
        local decoded = raw_base64_decode(original_body)
        if decoded then
            -- ssr://host:port:protocol:method:obfs:urlsafebase64pass/?params
            local before_query = decoded:match("^([^/?]+)")
            if before_query then
                local parts = {}
                for part in before_query:gmatch("([^:]+)") do
                    table.insert(parts, part)
                end
                -- host:port:protocol:method:obfs:password
                if #parts == 6 then
                    server = parts[1]
                end
            end
        end
        
    elseif scheme == "hysteria" or scheme == "hysteria2" or scheme == "hy2" then
        local url_parts = parse_url(line)
        if url_parts and url_parts.host then
            server = url_parts.host
        end
        
    elseif scheme == "tuic" then
        local url_parts = parse_url(line)
        if url_parts and url_parts.host then
            server = url_parts.host
        end
        
    elseif scheme == "socks" or scheme == "socks5" or scheme == "socks5h" or 
           scheme == "http" or scheme == "https" then
        local url_parts = parse_url(line)
        if url_parts and url_parts.host then
            server = url_parts.host
        end
        
    elseif scheme == "anytls" then
        local url_parts = parse_url(line)
        if url_parts and url_parts.host then
            server = url_parts.host
        end
    end
    
    -- fallback
    if not server then
        local body_to_parse = raw_base64_decode(original_body) or original_body
        server = body_to_parse:match("@([^:/]+)") or  -- user@host
                 body_to_parse:match("([^:/]+)") or   -- host
                 body_to_parse:match("//([^:/]+)")    -- //host
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