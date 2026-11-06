
local m, s, o
local openclash = "openclash"
local uci = luci.model.uci.cursor()
local fs = require "luci.openclash"
local sys = require "luci.sys"
local json = require "luci.jsonc"
local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"
local sid = arg[1]
local age_section
local profiles = require "luci.openclash_profiles"
local file_path = HTTP.formvalue("file", true)
local unified = file_path ~= nil
local profile = unified and profiles.find(file_path, fs, uci)
local source_content, stream, stream_error, commit_requested, apply_requested
if unified then
	if not profile or profile.ambiguous then
		HTTP.status(409, "Conflicting or invalid configuration")
		return
	end
	sid = profile.sid
	HTTP.setfilehandler(function(meta, chunk, eof)
		if not meta or meta.name ~= "oc_editor_content" then return end
		if not profile.editable then stream_error = true; return end
		if not stream and chunk then stream = io.tmpfile() end
		if not stream then stream_error = true; return end
		if chunk and not stream:write(chunk) then stream_error = true end
		if eof then stream:flush() end
	end)
end

local backend_version_status = [[
<div class="oc">
	<div id="subconverter-version-status-cbi" class="subconverter-version-status" data-state="idle" hidden>
		<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M5 4h14a2 2 0 0 1 2 2v2a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2Z"/><path d="M5 14h14a2 2 0 0 1 2 2v2a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-2a2 2 0 0 1 2-2Z"/><path d="M7 7h.01M7 17h.01"/></svg>
		<span class="subconverter-version-label"></span>
		<span class="subconverter-version-text"></span>
	</div>
</div>
]]



m = Map(openclash, translate("Config Subscribe Edit"))
m.pageaction = false
m.redirect = DISP.build_url("admin/services/openclash/config")
if unified then
	m.title = profile.name
	m.description = ""
	m.redirect = DISP.build_url("admin/services/openclash/config-edit") .. "?file=" .. HTTP.urlencode(file_path)
end
if not unified and (not sid or m.uci:get(openclash, sid) ~= "config_subscribe") then
	HTTP.redirect(m.redirect)
	return
end
if not unified then
	for _, row in ipairs(profiles.list(fs, m.uci)) do
		for _, subscription in ipairs(row.subscriptions) do
			if subscription == sid then
				HTTP.redirect(DISP.build_url("admin", "services", "openclash", "config-edit") .. "?file=" .. HTTP.urlencode(row.path))
				return
			end
		end
	end
	HTTP.redirect(DISP.build_url("admin", "services", "openclash", "config"))
	return
end

-- [[ Config Subscribe Setting ]]--
if profile.remote then
s = m:section(NamedSection, sid, "config_subscribe")
s.anonymous = true
s.addremove = false

---- name
o = s:option(Value, "name", translate("Config Alias"))
o.description = translate("Name For Distinguishing")
o.placeholder = translate("config")
o.rmempty = true
if unified then
	o.readonly = true
	o.cfgvalue = function() return profile.name end
	o.description = nil
	o.write = function() end
	o.remove = function() end
end
function o.validate(self, value)
	if value and value ~= "" and not fs.is_safe_filename(value) then
		return nil
	end
	return value
end

---- address
o = s:option(Value, "address", translate("Subscribe Address"))
o.template = "cbi/tvalue"
o.rows = 4
o.size = nil
o.wrap = "off"
o.description = translate("SS/SSR/Vmess or Other Link And Subscription Address is Supported When Online Subscription Conversion is Enabled, Multiple Links Should be One Per Line or Separated By |")
o.placeholder = translate("Not Null")
o.rmempty = false
function o.validate(self, value)
	if value then
		value = value:gsub("\r\n?", "\n")
		value = value:gsub("%c*$", "")
	end
	return value
end

---- UA
o = s:option(Value, "sub_ua", "User-Agent")
o.default = "clash-verge/v2.4.5"
o.description = translate("Used for Downloading Subscriptions, Defaults to").." "..o.default
o:value("clash-verge/v2.4.5")
o:value("clash.meta/1.19.20")
o:value("Clash")
o.rmempty = true

---- automatic update participation
o = s:option(ListValue, "auto_update", translate("Auto Update"))
o:value("1", translate("Yes"))
o:value("0", translate("No"))
o.default, o.rmempty = "0", false
o.cfgvalue = function() return profile.automatic and "1" or "0" end
local schedule_keys = {"config_auto_update_mode", "config_update_week_time", "auto_update_time", "config_update_interval"}
local overrides = {}
for _, key in ipairs(schedule_keys) do
	local value = m.uci:get(openclash, sid, key)
	if value ~= nil and value ~= "" then overrides[#overrides + 1] = key .. "=" .. value end
end
if #overrides > 0 then
	o.description = translate("Existing subscription frequency overrides take precedence over the global frequency:") .. " " .. table.concat(overrides, ", ")
end

---- subconverter
o = s:option(Flag, "sub_convert", translate("Subscribe Convert Online"))
o.description = translate("Convert Subscribe Online With Template")
o.default = 0

---- Convert Address
o = s:option(Value, "convert_address", translate("Convert Address"))
o.rmempty = true
o.description = backend_version_status..'<div class="oc-warn-strip"><svg viewBox="0 0 24 24" width="14" height="14"><path d="M12 3 2 20h20ZM12 10v4m0 3h.01" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg><span>'..translate("Note: There is A Risk of Privacy Leakage in Online Convert")..'</span></div>'
o:depends("sub_convert", "1")
o:value("https://api.asailor.org/sub", translate("api.asailor.org"))
o:value("https://api.wcc.best/sub", translate("api.wcc.best"))
o.default = "https://api.asailor.org/sub"
o.placeholder = "https://api.asailor.org/sub"

---- Template
o = s:option(ListValue, "template", translate("Template Name"))
o.rmempty = true
o:depends("sub_convert", "1")
file = io.open("/usr/share/openclash/res/sub_ini.list", "r");
for l in file:lines() do
	if l ~= "" then
		o:value(l:match("^([^,]*)"))
	end
end
file:close()
o:value("0", translate("Custom Template"))

---- Custom Template
o = s:option(Value, "custom_template_url", translate("Custom Template URL"))
o.rmempty = true
o.placeholder = translate("Not Null")
o.datatype = "or(host, string)"
o:depends("template", "0")

---- emoji
o = s:option(ListValue, "emoji", translate("Emoji"))
o.rmempty = false
o:value("false", translate("Disable"))
o:value("true", translate("Enable"))
o.default = "false"
o:depends("sub_convert", "1")

---- udp
o = s:option(ListValue, "udp", translate("UDP Enable"))
o.rmempty = false
o:value("false", translate("Disable"))
o:value("true", translate("Enable"))
o.default = "false"
o:depends("sub_convert", "1")

---- skip-cert-verify
o = s:option(ListValue, "skip_cert_verify", translate("skip-cert-verify"))
o.rmempty = false
o:value("false", translate("Disable"))
o:value("true", translate("Enable"))
o.default = "true"
o:depends("sub_convert", "1")

---- sort
o = s:option(ListValue, "sort", translate("Sort"))
o.rmempty = false
o:value("false", translate("Disable"))
o:value("true", translate("Enable"))
o.default = "false"
o:depends("sub_convert", "1")

---- node type
o = s:option(ListValue, "node_type", translate("Append Node Type"))
o.rmempty = false
o:value("false", translate("Disable"))
o:value("true", translate("Enable"))
o.default = "false"
o:depends("sub_convert", "1")

---- rule provider
o = s:option(ListValue, "rule_provider", translate("Use Rule Provider"))
o.description = translate("Note: Please Make Sure Backend Service Supports This Feature")
o.rmempty = false
o:value("false", translate("Disable"))
o:value("true", translate("Enable"))
o.default = "false"
o:depends("sub_convert", "1")

---- custom params
o = s:option(DynamicList, "custom_params", translate("Custom Params"))
o.description = translate("eg: \"rename=match@replace\" , \"rename=\\s+([2-9])[xX]@ (HIGH:$1)\"")
o.rmempty = false
o:depends("sub_convert", "1")

---- Node Filtering
o = s:option(Flag, "keyword_option", translate("Node Filtering"))
o.description = translate("Show node filter options")
o.default = 0

---- key
o = s:option(DynamicList, "keyword", translate("Keyword Match"))
o.description = translate("eg: hk or tw&bgp")
o.rmempty = true
o:depends("keyword_option", "1")

---- exkey
o = s:option(DynamicList, "ex_keyword", translate("Exclude Keyword Match"))
o.description = translate("eg: hk or tw&bgp")
o.rmempty = true
o:depends("keyword_option", "1")

---- de_exkey
o = s:option(MultiValue, "de_ex_keyword", translate("Exclude Keyword Match Default"))
o.rmempty = true
o:depends("keyword_option", "1")
o:value(translate("Expire"))
o:value(translate("Traffic"))
o:value(translate("Plan"))
o:value(translate("Official"))


---- Advanced Options
o = s:option(Flag, "ad_option", translate("Advanced Options"))
o.description = translate("Show more subscription options")
o.default = 0

---- Custom Headers
o = s:option(DynamicList, "sub_headers", translate("Custom Headers"))
o.description = translate("Custom HTTP request headers, one per line, format: Header-Name: value")
o.rmempty = true
o.placeholder = "x-hwid: my-device-id"
o:depends("ad_option", "1")

o = s:option(ListValue, "config_age_algo", translate("Age Key Type"))
o:depends("ad_option", "1")
o.description = translate("Age Encryption For Config, Click For More:").." ".."<a href='javascript:void(0)' onclick='javascript:return winOpen(\"https://wiki.metacubex.one/config/proxy-providers/?age-secret-key#age-secret-key\")'>"..translate("Age Encryption Introduce").."</a>"
o:value("keygen", "x25519")
o:value("pq", "PQ (mlkem768-x25519)")
o.rmempty = true
function o.cfgvalue(self, section)
	local name = m.uci:get(openclash, section, "name") or section
	local v = ""
	m.uci:foreach(openclash, "config_age_secret", function(s)
		if s.name == name then
			v = s.algo or ""
			age_section = s['.name']
			return false
		end
	end)
	return v
end
function o.write(self, section, value)
	local name = m.uci:get(openclash, section, "name") or section
	m.uci:foreach(openclash, "config_age_secret", function(s)
		if s.name == name then
			age_section = s['.name']
			return false
		end
	end)
	if not age_section and value and value ~= "" then
		age_section = m.uci:add(openclash, "config_age_secret")
		if age_section then m.uci:set(openclash, age_section, "name", name) end
	end
	if age_section then
		if value and value ~= "" then
			m.uci:set(openclash, age_section, "algo", value)
		else
			m.uci:delete(openclash, age_section, "algo")
		end
	end
end
function o.remove(self, section)
	self:write(section, "")
end

o = s:option(Value, "config_age_secret", translate("Secret Key"))
o.rmempty = true
o:depends("ad_option", "1")
o.placeholder = "AGE-SECRET-KEY-..."
function o.cfgvalue(self, section)
	local name = m.uci:get(openclash, section, "name") or section
	local v = ""
	m.uci:foreach(openclash, "config_age_secret", function(s)
		if s.name == name then
			v = s.secret or ""
			age_section = s['.name']
			return false
		end
	end)
	return v
end
function o.write(self, section, value)
	local name = m.uci:get(openclash, section, "name") or section
	m.uci:foreach(openclash, "config_age_secret", function(s)
		if s.name == name then
			age_section = s['.name']
			return false
		end
	end)
	if not age_section and value and value ~= "" then
		age_section = m.uci:add(openclash, "config_age_secret")
		if age_section then m.uci:set(openclash, age_section, "name", name) end
	end
	if age_section then
		if value and value ~= "" then
			m.uci:set(openclash, age_section, "secret", value)
		else
			m.uci:delete(openclash, age_section, "secret")
		end
	end
end
function o.remove(self, section)
	self:write(section, "")
end

o = s:option(Value, "config_age_public", translate("Public Key"))
o.rmempty = true
o:depends("ad_option", "1")
o.placeholder = "age..."
function o.cfgvalue(self, section)
	local name = m.uci:get(openclash, section, "name") or section
	local v = ""
	m.uci:foreach(openclash, "config_age_secret", function(s)
		if s.name == name then
			v = s.public or ""
			age_section = s['.name']
			return false
		end
	end)
	return v
end
function o.write(self, section, value)
	local name = m.uci:get(openclash, section, "name") or section
	m.uci:foreach(openclash, "config_age_secret", function(s)
		if s.name == name then
			age_section = s['.name']
			return false
		end
	end)
	if not age_section and value and value ~= "" then
		age_section = m.uci:add(openclash, "config_age_secret")
		if age_section then m.uci:set(openclash, age_section, "name", name) end
	end
	if age_section then
		if value and value ~= "" then
			m.uci:set(openclash, age_section, "public", value)
		else
			m.uci:delete(openclash, age_section, "public")
		end
	end
end
function o.remove(self, section)
	self:write(section, "")
end

o = s:option(DummyValue, "_generate_age_btn", "")
o:depends("ad_option", "1")
o.template = "openclash/generate_age"
if unified then
	o = s:option(DummyValue, "_update", translate("Update Config"))
	o.cfgvalue = function() return profile.name end
	o.template = "openclash/update_config"
	o.confirm_overwrite = true
	o.reload_after_update = true
	o.no_restart = true
end
end

if unified then
	local section = m:section(NamedSection, "config", "openclash", translate("Config File Edit"))
	section:tab("source", translate("Config File"))
	local runtime_stat = fs.stat("/etc/openclash/" .. profile.name)
	local has_running = profiles.running_name(fs, sys) == profile.name and runtime_stat and runtime_stat.type == "regular"
	if has_running then section:tab("running", translate("Running Config")) end
	o = section:taboption("source", profile.exists and TextValue or DummyValue, "_profile_source")
	o.rows, o.wrap, o.readonly = 30, "off", not profile.editable
	o.description = profile.automatic and profile.exists and translate("Disable automatic updates and save before editing this configuration") or ""
	o.cfgvalue = function() return profile.exists and (fs.readfile(file_path) or "") or translate("Configuration has not been downloaded") end
	o.write = function(self, section, value)
		if profile.editable and value and value ~= "oc-editor-streamed" then source_content = value:gsub("\r\n?", "\n") end
	end
	o.remove = function() end
	if has_running then
	o = section:taboption("running", TextValue, "_profile_running")
	o.rows, o.wrap, o.readonly = 30, "off", true
	o.cfgvalue = function() return fs.readfile("/etc/openclash/" .. profile.name) or "" end
	o.write = function() end
	o.remove = function() end
	end
end

local t = {
	{Commit, Back}
}
a = m:section(Table, t)

o = a:option(Button,"Commit", " ")
o.inputtitle = translate("Commit Settings")
o.inputstyle = "apply"
o.write = function()
	commit_requested = true
end

m.commit_handler = function(self)
	if not commit_requested then return end
	if stream_error then
		if stream then stream:close(); stream = nil end
		self.message = translate("Failed to save config file to disk")
		return
	end
	if unified and profile.editable and (stream or source_content) then
		if stream then stream:seek("set"); source_content = stream:read("*a"); stream:close(); stream = nil end
		local scheduled = sid and profiles.auto_update({auto_update=m.uci:get(openclash, sid, "auto_update")}, m.uci:get(openclash, "config", "auto_update"))
		if source_content and not scheduled and source_content ~= fs.readfile(file_path) then
			if not profiles.writable(file_path, fs, luci.model.uci.cursor()) then
				self.message = translate("Disable automatic updates and save before editing this configuration")
				return
			end
			if not fs.writefile(file_path, source_content) then
				self.message = translate("Failed to save config file to disk")
				return
			end
		end
	end
	local to_delete = {}
	m.uci:foreach(openclash, "config_age_secret", function(s)
		local sec = m.uci:get(openclash, s['.name'], "secret") or ""
		if (not unified or s.name == fs.filename(profile.name)) and (sec == "" or sec == nil) then
			table.insert(to_delete, { sid = s['.name'], name = s.name or "" })
		end
	end)
	-- Before removing the age keys, decrypt each affected config file so it
	-- stays readable after the keys are gone. The field writes above have
	-- already dropped the secret in the working cursor, so read the previous
	-- value from a fresh cursor (the change is not committed to disk yet).
	local old_uci = luci.model.uci.cursor()
	for _, d in ipairs(to_delete) do
		local old_secret = old_uci:get(openclash, d.sid, "secret") or ""
		local can_delete = true
		if old_secret ~= "" and d.name and d.name ~= "" then
			local config_paths = {
				"/etc/openclash/config/" .. d.name .. ".yaml",
				"/etc/openclash/" .. d.name .. ".yaml",
			}
			for _, config_path in ipairs(config_paths) do
				if fs.access(config_path) then
					local fp = io.open(config_path, "rb")
					if fp then
						local content = fp:read("*a")
						fp:close()
						if content and content:find("BEGIN AGE ENCRYPTED FILE", 1, true) then
							local plain = fs.age_decrypt(old_secret, content)
							if plain and plain ~= "" then
								local fo = io.open(config_path, "wb")
								if fo then
									fo:write(plain)
									fo:close()
								end
							else
								can_delete = false
							end
						end
					end
				end
			end
		end
		if can_delete then
			m.uci:delete(openclash, d.sid)
		end
	end
	m.uci:commit(openclash)
	sys.call("/etc/init.d/openclash reload cron >/dev/null 2>&1")
	if apply_requested and unified and profile.exists then
		m.uci:set(openclash, "config", "config_path", file_path)
		m.uci:set(openclash, "config", "enable", "1")
		m.uci:commit(openclash)
		sys.call("/etc/init.d/openclash restart >/dev/null 2>&1 &")
	end
	HTTP.redirect(m.redirect)
end

if unified and profile.exists then
	o = a:option(Button, "Apply", " ")
	o.inputtitle, o.inputstyle = translate("Apply Settings"), "apply"
	o.write = function() commit_requested = true; apply_requested = true end
end

o = a:option(Button,"Back", " ")
o.inputtitle = translate("Back Settings")
o.inputstyle = "reset"
if unified then o.template = "openclash/config_back" end
o.write = function()
	if sid then m.uci:revert(openclash, sid) end
	if age_section then
		m.uci:revert(openclash, age_section)
	end
	HTTP.redirect(DISP.build_url("admin/services/openclash/config"))
end

local render_children = m.render_children
m.render_children = function(self, ...)
	fs.render_page_head()
	if unified then luci.template.render("openclash/config_resources") end
	render_children(self, ...)
end

if unified then
	local editor = Template("openclash/profile_editor")
	editor.profile_name = profile.name
	editor.profile_path = file_path
	m:append(editor)
end
m:append(Template("openclash/subconverter_version"))
return m
