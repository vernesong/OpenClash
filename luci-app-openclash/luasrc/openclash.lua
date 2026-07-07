--[[
LuCI - Filesystem tools

Description:
A module offering often needed filesystem manipulation functions

FileId:
$Id$

License:
Copyright 2008 Steven Barth <steven@midlink.org>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

]]--

local io    = require "io"
local os    = require "os"
local ltn12 = require "luci.ltn12"
local fs	= require "nixio.fs"
local nutil = require "nixio.util"
local uci = require "luci.model.uci".cursor()
local SYS  = require "luci.sys"
local HTTP = require "luci.http"

local type  = type
local string  = string
local tostring = tostring
local table = table
local math = math
local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

--- LuCI filesystem library.
module "luci.openclash"

--- Test for file access permission on given path.
-- @class		function
-- @name		access
-- @param str	String value containing the path
-- @return		Number containing the return code, 0 on sucess or nil on error
-- @return		String containing the error description (if any)
-- @return		Number containing the os specific errno (if any)
access = fs.access

--- Evaluate given shell glob pattern and return a table containing all matching
-- file and directory entries.
-- @class			function
-- @name			glob
-- @param filename	String containing the path of the file to read
-- @return			Table containing file and directory entries or nil if no matches
-- @return			String containing the error description (if no matches)
-- @return			Number containing the os specific errno (if no matches)
function glob(...)
	local iter, code, msg = fs.glob(...)
	if iter then
		return nutil.consume(iter)
	else
		return nil, code, msg
	end
end

--- Checks wheather the given path exists and points to a regular file.
-- @param filename	String containing the path of the file to test
-- @return			Boolean indicating wheather given path points to regular file
function isfile(filename)
	return fs.stat(filename, "type") == "reg"
end

--- Checks wheather the given path exists and points to a directory.
-- @param dirname	String containing the path of the directory to test
-- @return			Boolean indicating wheather given path points to directory
function isdirectory(dirname)
	return fs.stat(dirname, "type") == "dir"
end

--- Read the whole content of the given file into memory.
-- @param filename	String containing the path of the file to read
-- @return			String containing the file contents or nil on error
-- @return			String containing the error message on error
-- Wrapped readfile: if file is age-encrypted, try to decrypt with matching UCI secret first
function readfile(filename)
	local content, err = fs.readfile(filename)
	if not content then return nil, err end
	if content:find("BEGIN AGE ENCRYPTED FILE") then
		local keys = get_age_keys(filename)
		if keys and keys.secret and keys.secret ~= "" then
			return age_decrypt(keys.secret, content) or content
		else
			return content
		end
	end
	return content
end

--- Write the contents of given string to given file.
-- @param filename	String containing the path of the file to read
-- @param data		String containing the data to write
-- @return			Boolean containing true on success or nil on error
-- @return			String containing the error message on error
-- Wrapped writefile: if public key exists for filename, encrypt before writing
function writefile(filename, data)
	local keys = get_age_keys(filename)
	if keys and keys.public and keys.public ~= "" then
		return fs.writefile(filename, age_encrypt(keys.public, data) or data)
	end
	return fs.writefile(filename, data)
end

--- Copies a file.
-- @param source	Source file
-- @param dest		Destination
-- @return			Boolean containing true on success or nil on error
copy = fs.datacopy

--- Renames a file.
-- @param source	Source file
-- @param dest		Destination
-- @return			Boolean containing true on success or nil on error
rename = fs.move

--- Get the last modification time of given file path in Unix epoch format.
-- @param path	String containing the path of the file or directory to read
-- @return		Number containing the epoch time or nil on error
-- @return		String containing the error description (if any)
-- @return		Number containing the os specific errno (if any)
function mtime(path)
	return fs.stat(path, "mtime")
end

--- Set the last modification time  of given file path in Unix epoch format.
-- @param path	String containing the path of the file or directory to read
-- @param mtime	Last modification timestamp
-- @param atime Last accessed timestamp
-- @return		0 in case of success nil on error
-- @return		String containing the error description (if any)
-- @return		Number containing the os specific errno (if any)
function utime(path, mtime, atime)
	return fs.utimes(path, atime, mtime)
end

--- Return the last element - usually the filename - from the given path with
-- the directory component stripped.
-- @class		function
-- @name		basename
-- @param path	String containing the path to strip
-- @return		String containing the base name of given path
-- @see			dirname
basename = fs.basename

--- Return the directory component of the given path with the last element
-- stripped of.
-- @class		function
-- @name		dirname
-- @param path	String containing the path to strip
-- @return		String containing the directory component of given path
-- @see			basename
dirname = fs.dirname

--- Return a table containing all entries of the specified directory.
-- @class		function
-- @name		dir
-- @param path	String containing the path of the directory to scan
-- @return		Table containing file and directory entries or nil on error
-- @return		String containing the error description on error
-- @return		Number containing the os specific errno on error
function dir(...)
	local iter, code, msg = fs.dir(...)
	if iter then
		local t = nutil.consume(iter)
		t[#t+1] = "."
		t[#t+1] = ".."
		return t
	else
		return nil, code, msg
	end
end

--- Create a new directory, recursively on demand.
-- @param path		String with the name or path of the directory to create
-- @param recursive	Create multiple directory levels (optional, default is true)
-- @return			Number with the return code, 0 on sucess or nil on error
-- @return			String containing the error description on error
-- @return			Number containing the os specific errno on error
function mkdir(path, recursive)
	return recursive and fs.mkdirr(path) or fs.mkdir(path)
end

--- Remove the given empty directory.
-- @class		function
-- @name		rmdir
-- @param path	String containing the path of the directory to remove
-- @return		Number with the return code, 0 on sucess or nil on error
-- @return		String containing the error description on error
-- @return		Number containing the os specific errno on error
rmdir = fs.rmdir

local stat_tr = {
	reg = "regular",
	dir = "directory",
	lnk = "link",
	chr = "character device",
	blk = "block device",
	fifo = "fifo",
	sock = "socket"
}
--- Get information about given file or directory.
-- @class		function
-- @name		stat
-- @param path	String containing the path of the directory to query
-- @return		Table containing file or directory properties or nil on error
-- @return		String containing the error description on error
-- @return		Number containing the os specific errno on error
function stat(path, key)
	local data, code, msg = fs.stat(path)
	if data then
		data.mode = data.modestr
		data.type = stat_tr[data.type] or "?"
	end
	return key and data and data[key] or data, code, msg
end

--- Set permissions on given file or directory.
-- @class		function
-- @name		chmod
-- @param path	String containing the path of the directory
-- @param perm	String containing the permissions to set ([ugoa][+-][rwx])
-- @return		Number with the return code, 0 on sucess or nil on error
-- @return		String containing the error description on error
-- @return		Number containing the os specific errno on error
chmod = fs.chmod

--- Create a hard- or symlink from given file (or directory) to specified target
-- file (or directory) path.
-- @class			function
-- @name			link
-- @param path1		String containing the source path to link
-- @param path2		String containing the destination path for the link
-- @param symlink	Boolean indicating wheather to create a symlink (optional)
-- @return			Number with the return code, 0 on sucess or nil on error
-- @return			String containing the error description on error
-- @return			Number containing the os specific errno on error
function link(src, dest, sym)
	return sym and fs.symlink(src, dest) or fs.link(src, dest)
end

--- Remove the given file.
-- @class		function
-- @name		unlink
-- @param path	String containing the path of the file to remove
-- @return		Number with the return code, 0 on sucess or nil on error
-- @return		String containing the error description on error
-- @return		Number containing the os specific errno on error
unlink = fs.unlink

--- Retrieve target of given symlink.
-- @class		function
-- @name		readlink
-- @param path	String containing the path of the symlink to read
-- @return		String containing the link target or nil on error
-- @return		String containing the error description on error
-- @return		Number containing the os specific errno on error
readlink = fs.readlink

function filename(str)
	if not str then
		return nil
	end
	local idx = str:match(".+()%.%w+$")
	if idx then
		return str:sub(1, idx-1)
	else
		return str
	end
end

function filesize(e)
	local t=0
	local a={' KB',' MB',' GB',' TB',' PB'}
	if e < 0 then
        e = -e
    end
	repeat
		e=e/1024
		t=t+1
	until(e<=1024)
	return string.format("%.1f",e)..a[t] or "0.0 KB"
end

function lanip()
	local lan_int_name = uci:get("openclash", "@overwrite[0]", "lan_interface_name") or uci:get("openclash", "config", "lan_interface_name") or "0"
	local lan_ip
	if lan_int_name == "0" then
		lan_ip = SYS.exec("uci -q get network.lan.ipaddr 2>/dev/null |awk -F '/' '{print $1}' 2>/dev/null |tr -d '\n'")
	else
		lan_ip = SYS.exec(string.format("ip address show %s 2>/dev/null | grep -w 'inet' 2>/dev/null | grep -Eo 'inet [0-9\.]+' | awk '{print $2}' | head -1 | tr -d '\n'", lan_int_name))
	end
	if not lan_ip or lan_ip == "" then
		lan_ip = SYS.exec("ip address show $(uci -q -p /tmp/state get network.lan.ifname || uci -q -p /tmp/state get network.lan.device) | grep -w 'inet'  2>/dev/null | grep -Eo 'inet [0-9\.]+' | awk '{print $2}' | head -1 | tr -d '\n'")
	end
	if not lan_ip or lan_ip == "" then
		lan_ip = SYS.exec("ip addr show 2>/dev/null | grep -w 'inet' | grep 'global' | grep 'brd' | grep -Eo 'inet [0-9\.]+' | awk '{print $2}' | head -n 1 | tr -d '\n'")
	end
	return lan_ip
end

function find_case_insensitive_path(path)
    local dir = dirname(path)
    local base = basename(path)
    local files = dir and fs.dir(dir)
    if not files then
        return nil
    end

    for f in files do
        if f:lower() == base:lower() then
            return dir .. "/" .. f
        end
    end
    return nil
end

function get_resourse_mtime(path)
    local real_path = path
    if not fs.access(path) then
        local found = find_case_insensitive_path(path)
        if found then
            real_path = found
        else
            return "File Not Exist"
        end
    end
    local file = fs.readlink(real_path) or real_path
	local resourse_etag_version = SYS.exec(string.format("source /usr/share/openclash/openclash_etag.sh && GET_ETAG_TIMESTAMP_BY_PATH '%s'", real_path))
    if resourse_etag_version and resourse_etag_version ~= "" then
		return resourse_etag_version
	end
	local resourse_version = os.date("%Y-%m-%d %H:%M:%S", mtime(real_path))
	if resourse_version and resourse_version ~= "" then
        return resourse_version
	end
    return "Unknown"
end

function uci_get_config(section, key)
	local val
	if section == "config" then
    	val = uci:get("openclash", "@overwrite[0]", key)
	end
    if val == nil then
    	val = uci:get("openclash", section, key)
    end
    return val
end

function get_file_path_from_request()
	local file_path
	local referer = HTTP.getenv("HTTP_REFERER")
	if referer then
		local _, _, file_value = referer:find("file=([^&]*)$")
		if file_value and file_value ~= "" then
			file_path = HTTP.urldecode(file_value)
		end
	end

	if not file_path or file_path == "/" then
		file_path = HTTP.formvalue("file")
		if not file_path then
			file_path = HTTP.urldecode(file_path)
		end
	end

	return file_path
end

function get_age_keys(file)
	local name = filename(basename(file))
	local pub, sec
	uci:foreach("openclash", "config_age_secret", function(s)
		if s and s.name then
			if s.name == name and (not s.hidden or (s.hidden ~= "true")) then
				if not pub and s.public then pub = s.public end
				if not sec and s.secret then sec = s.secret end
			end
			return false
		end
	end)
	return { public = pub, secret = sec }
end

function age_encrypt(public, content)
    if not public or public == "" or not content then return nil end

    local tmp_in = os.tmpname()
    local tmp_out = os.tmpname()
    local f = io.open(tmp_in, "w")
    if not f then return nil end
    f:write(content)
    f:close()

    local cmd = string.format(
        "/etc/openclash/core/clash_meta age encrypt %s %s %s 2>/dev/null",
        public, tmp_in, tmp_out
    )
    os.execute(cmd)

    local out = nil
    local f_out = io.open(tmp_out, "r")
    if f_out then
        out = f_out:read("*a") or ""
        f_out:close()
    end

    os.remove(tmp_in)
    os.remove(tmp_out)

    return out
end

function age_decrypt(secret, content)
    if not secret or secret == "" or not content then return nil end

    local tmp_in = os.tmpname()
    local tmp_out = os.tmpname()
    local f = io.open(tmp_in, "w")
    if not f then return nil end
    f:write(content)
    f:close()

    local cmd = string.format(
        "/etc/openclash/core/clash_meta age decrypt %s %s %s 2>/dev/null",
        secret, tmp_in, tmp_out
    )
    os.execute(cmd)

    local out = nil
    local f_out = io.open(tmp_out, "r")
    if f_out then
        out = f_out:read("*a") or ""
        f_out:close()
    end

    os.remove(tmp_in)
    os.remove(tmp_out)

    return out
end

function decode64(data)
	if not data then return nil end
	data = data:gsub('[%s]', '')
	if #data % 4 ~= 0 then return nil end

	local out = {}
	for i = 1, #data, 4 do
		local c1, c2, c3, c4 = data:byte(i, i+3)
		local i1 = b64chars:find(string.char(c1), 1, true) - 1
		local i2 = b64chars:find(string.char(c2), 1, true) - 1
		local i3 = (c3 == 61) and -1 or (b64chars:find(string.char(c3), 1, true) - 1)
		local i4 = (c4 == 61) and -1 or (b64chars:find(string.char(c4), 1, true) - 1)

		if not i1 or not i2 or (c3 ~= 61 and not i3) or (c4 ~= 61 and not i4) then
			return nil
		end

		local x = i1 * 0x40000 + i2 * 0x1000
		if i3 >= 0 then x = x + i3 * 0x40 end
		if i4 >= 0 then x = x + i4 end

		table.insert(out, string.char(math.floor(x / 0x10000) % 0x100))
		if i3 >= 0 then
			table.insert(out, string.char(math.floor(x / 0x100) % 0x100))
		end
		if i4 >= 0 then
			table.insert(out, string.char(x % 0x100))
		end
	end

	return table.concat(out)
end

function config_refs(old_file_name, new_file_name)
	if not old_file_name or old_file_name == "" then return end
	local old_name_no_ext = filename(basename(old_file_name))
	local old_file_full = basename(old_file_name)
	local is_rename = new_file_name and new_file_name ~= ""
	local new_name_no_ext, new_file_full

	if is_rename then
		new_name_no_ext = filename(basename(new_file_name))
		new_file_full = basename(new_file_name)
	end

	uci:foreach("openclash", "config_subscribe",
		function(s)
			if s.name == old_name_no_ext then
				if is_rename and new_name_no_ext ~= new_file_name then
					uci:set("openclash", s[".name"], "name", new_name_no_ext)
				else
					uci:delete("openclash", s[".name"])
				end
				return false
			end
		end
	)

	uci:foreach("openclash", "subscribe_info",
		function(s)
			if s.name == old_name_no_ext then
				if is_rename and new_name_no_ext ~= new_file_name then
					uci:set("openclash", s[".name"], "name", new_name_no_ext)
				else
					uci:delete("openclash", s[".name"])
				end
				return false
			end
		end
	)

	uci:foreach("openclash", "groups",
		function(s)
			if s.config == old_file_full then
				if is_rename and new_name_no_ext ~= new_file_name then
					uci:set("openclash", s[".name"], "config", new_file_full)
				else
					uci:delete("openclash", s[".name"])
				end
			end
		end
	)

	uci:foreach("openclash", "proxy-provider",
		function(s)
			if s.config == old_file_full then
				if is_rename and new_name_no_ext ~= new_file_name then
					uci:set("openclash", s[".name"], "config", new_file_full)
				else
					uci:delete("openclash", s[".name"])
				end
			end
		end
	)

	uci:foreach("openclash", "servers",
		function(s)
			if s.config == old_file_full then
				if is_rename and new_name_no_ext ~= new_file_name then
					uci:set("openclash", s[".name"], "config", new_file_full)
				else
					uci:delete("openclash", s[".name"])
				end
			end
		end
	)

	uci:foreach("openclash", "config_age_secret",
		function(s)
			if s.name == old_name_no_ext then
				if is_rename and new_name_no_ext ~= new_file_name then
					uci:set("openclash", s[".name"], "name", new_name_no_ext)
				else
					uci:delete("openclash", s[".name"])
				end
				return false
			end
		end
	)

	uci:commit("openclash")
end

--- Returns the appropriate ps command string for the system's ps implementation.
-- Detects procps-ng (ps -efw) vs busybox (ps -w).
-- @return String containing the ps command prefix
function ps_cmd()
	local ps_version = SYS.exec("ps --version 2>&1 |grep -c procps-ng |tr -d '\n'")
	if ps_version == "1" then
		return "ps -efw"
	else
		return "ps -w"
	end
end

--- Returns the package manager type (opkg or apk).
-- @return String "opkg" or "apk"
function pkg_type()
	if fs.access("/usr/bin/apk") then
		return "apk"
	else
		return "opkg"
	end
end

--- Returns the installed version of luci-app-openclash.
-- Supports both opkg and apk package managers.
-- @return String containing the version number, or "0" if not found
function oc_version()
	local v
	if pkg_type() == "opkg" then
		v = SYS.exec("rm -f /var/lock/opkg.lock && opkg status luci-app-openclash 2>/dev/null |grep '^Version:' |awk '{print $2}' |tr -d '\n'")
	else
		v = SYS.exec("rm -f /lib/apk/db/lock && apk info luci-app-openclash 2>/dev/null |grep '^luci-app-openclash-[0-9]' |sed 's/luci-app-openclash-//' |tr -d '\n'")
	end
	if v == "" then
		v = "0"
	end
	return v
end

function IsYamlExt(e)
	e = e or ""
	local lower = string.lower(e)
	return lower:sub(-5) == ".yaml" or lower:sub(-4) == ".yml"
end
