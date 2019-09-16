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

local fs	= require "nixio.fs"

local type  = type

--- LuCI filesystem library.
module "luci.openclash"

--- Checks wheather the given path exists and points to a directory.
-- @param dirname	String containing the path of the directory to test
-- @return			Boolean indicating wheather given path points to directory
function isdirectory(dirname)
	return fs.stat(dirname, "type") == "dir"
end
