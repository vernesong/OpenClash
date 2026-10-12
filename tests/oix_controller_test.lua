-- Run from the repository root: lua5.1 tests/oix_controller_test.lua
-- All controller requests use fixture UCI, filesystem, HTTP and service modules.
luci = {i18n = {translate=function(s) return s end}}
local source = arg[1] or 'luci-app-openclash/luasrc/controller/openclash.lua'
local managed_path = '/etc/openclash/config/oixCloud - smart.yaml'
local provider_path = '/etc/openclash/proxy_provider/oixCloud'
local form, output, calls, changes = {}, nil, {}, {}
local filehandler, parsed, response_headers = nil, false, {}
local token = 'fixture-token'
local current = managed_path
local refreshing = true
local refresh_error = "Managed nodes are not referenced by any proxy group"
local refreshes = 0
local saved_settings, save_success
local sections = {
  config_subscribe = {{['.name']='managed', name='oixCloud - smart', oix_managed='1', address='https://private.example/token'}, {['.name']='ordinary', name='ordinary', address='https://ordinary.example/sub'}},
  config_overwrite = {{['.name']='overwrite1', name='test', config={managed_path, '/etc/openclash/config/ordinary.yaml'}, type='file', enable='1'}},
  config_age_secret = {{['.name']='age1', name='oixCloud - smart', secret='secret'}}
}
local function managed(v)
  if v == '@oix' then return true end
  if type(v) ~= 'string' then return false end
  local name = v:match('([^/]+)$') or v
  name = name:gsub('%.ya?ml$', '')
  return name == 'oixCloud - smart'
end
local fs = {
  oix_config_path=function() return managed_path end,
  oix_config_id=function() return '@oix' end,
  is_oix_managed_config=managed,
  is_oix_managed_file=function(value) return managed(value) or value == provider_path end,
  uci_get_config=function(_, key)
    if key == 'oix_token' then return token end
    if key == 'config_path' then return current end
  end,
  basename=function(v) return v:match('([^/]+)$') end,
  access=function() return true end,
  stat=function() return {type='regular', size=12, mtime=42} end,
  dir=function() return {'oixCloud - smart.yaml', 'ordinary.yaml'} end,
  glob=function() return {managed_path, '/etc/openclash/config/ordinary.yaml'} end,
  readfile=function() return 'ordinary: true' end,
  filesize=function() return '12 B' end,
  writefile=function(...) changes[#changes+1]={'writefile',...}; return true end,
  rename=function(...) changes[#changes+1]={'rename',...}; return true end,
  isfile=function() return true end,
  ps_cmd=function() return 'ps' end
}
local cursor = {}
function cursor:get(package, section, key)
  if section == 'config' and key == 'config_path' then return current end
  if section == 'config' and key == 'enable' then return '1' end
end
function cursor:foreach(package, kind, fn)
  for _, s in ipairs(sections[kind] or {}) do if fn(s) == false then break end end
end
function cursor:set(package, section, key, value)
  changes[#changes+1]={'set',section,key,value}
  if section == 'config' and key == 'config_path' then current=value end
  for _, group in pairs(sections) do for _, s in ipairs(group) do if s['.name']==section then s[key]=value end end end
end
function cursor:set_list(package, section, key, value) self:set(package, section, key, value) end
function cursor:commit() changes[#changes+1]={'commit'} end
function cursor:delete(...) changes[#changes+1]={'delete',...} end
function cursor:get_list(package, section, key) return {} end
package.preload['luci.sys']=function() return {exec=function(cmd) calls[#calls+1]=cmd; return '' end, call=function(cmd) calls[#calls+1]=cmd; return 0 end} end
package.preload['luci.http']=function() return {
  setfilehandler=function(handler) filehandler=handler end,
  formvalue=function(key, query_only)
    if filehandler and not query_only and not parsed then
      parsed=true
      filehandler({file=form.filename or ''},form.content or form.config_file or '',true)
    end
    return form[key]
  end,
  prepare_content=function(value) response_headers.content_type=value end,
  header=function(key,value) response_headers[key]=value end,
  write=function(value) output=(output or '')..value end,
  write_json=function(value) output=value end,
  status=function(code) output={http_status=code} end,
  getenv=function() return form.method end
} end

package.preload['luci.openclash']=function() return fs end
package.preload['luci.openclash_oix']=function() return {
  refresh=function() refreshes=refreshes+1; return refreshing, refresh_error end,
  save_settings=function(input) saved_settings=input; return save_success end,
} end
package.preload['luci.model.uci']=function() return {cursor=function() return cursor end} end
package.preload['luci.jsonc']=function() return {parse=function() return {} end} end
for _, name in ipairs({'luci.dispatcher','luci.util','luci.cbi.datatypes'}) do package.preload[name]=function() return {} end end
dofile = function(path) assert(path == '/usr/share/openclash/openclash_version.lua'); return {} end
assert(loadfile(source))()
local controller=package.loaded['luci.controller.openclash']
package.loaded['luci.util'].shellquote=function(value) return "'"..value.."'" end
controller.ltn12_popen=function(command)
  assert(command=="exec cat '/etc/openclash/config/ordinary.yaml'")
  return setmetatable({kill=function() end},{__call=function() return 'ordinary: true' end})
end
luci.ltn12={pump={all=function(reader,writer) writer(reader()) end}}

local cases=0
local function invoke(name, values)
  form=values or {}; output=nil; calls={}; changes={}; filehandler=nil; parsed=false; response_headers={}
  controller[name]()
  cases=cases+1
  return output
end
local function contains(value, needle)
  if type(value)=='string' then return value:find(needle,1,true) ~= nil end
  if type(value)=='table' then for k,v in pairs(value) do if contains(k,needle) or contains(v,needle) then return true end end end
  return false
end
local function private_result(result)
  assert(not contains(result,'oixCloud - smart'), 'managed filename leaked')
  assert(not contains(result,'private.example'), 'managed subscription URL leaked')
end
local list=invoke('action_config_file_list')
assert(list.current_config=='@oix' and list.total_count==2)
assert(list.config_files[1].name=='oixCloud' and list.config_files[1].path=='@oix' and list.config_files[1].id=='@oix' and list.config_files[1].managed and list.config_files[1].available)
assert(list.config_files[2].name=='ordinary.yaml' and list.config_files[2].path=='/etc/openclash/config/ordinary.yaml')
assert(list.fingerprint=='@oix:42|ordinary.yaml:42')
private_result(list)
local names=invoke('action_config_name')
assert(names.config_path=='@oix' and names.config_name[1].name=='@oix' and names.config_name[1].label=='oixCloud')
private_result(names)
assert(controller.get_sub_url('oixCloud - smart').type=='managed')
assert(controller.get_sub_url('ordinary').url=='https://ordinary.example/sub')
for _, path in ipairs({'@oix', managed_path, '/etc/openclash/oixCloud - smart.yaml', provider_path}) do
  for _, action in ipairs({'action_config_file_read','action_config_file_save'}) do
    local result=invoke(action, {config_file=path, content='replacement'})
    assert(result.status=='error' and result.managed and #changes==0 and #calls==0)
    private_result(result)
  end
end
for _, spec in ipairs({
  {'action_get_subscribe_data', {filename='oixCloud - smart'}},
  {'action_get_subscribe_info_data', {filename='oixCloud - smart'}},
  {'sub_info_get', {filename='@oix'}},
  {'set_subinfo_url', {filename='@oix',url='https://replacement.example'}},
  {'action_add_subscription', {name='oixCloud - smart',address='https://replacement.example'}},
  {'action_add_age_config', {name='oixCloud - smart'}},
  {'action_upload_config', {filename='@oix',config_file='replacement'}},
  {'action_upload_config', {filename='oixCloud - smart.yaml',config_file='replacement'}},
  {'action_config_stats', {filename='@oix'}},
  {'action_config_stats', {filename='oixCloud - smart.yaml',static='1'}},
  {'create_file', {filename='@oix',filepath='/etc/openclash/config/'}},
  {'create_file', {filename='oixCloud',filepath='/etc/openclash/proxy_provider/'}},
  {'rename_file', {file_name='oixCloud',new_file_name='renamed',file_path='/etc/openclash/proxy_provider/'}},
  {'rename_file', {file_name='ordinary',new_file_name='oixCloud',file_path='/etc/openclash/proxy_provider/'}},
  {'rename_file', {file_name='oixCloud - smart.yaml',new_file_name='renamed.yaml',file_path='/etc/openclash/config/'}},
  {'rename_file', {file_name='ordinary.yaml',new_file_name='oixCloud - smart.yaml',file_path='/etc/openclash/config/'}}
}) do
  local result=invoke(spec[1],spec[2]); assert(result.type=='managed' and #changes==0 and #calls==0); private_result(result)
end
local switched=invoke('action_switch_config',{config_name='@oix'})
assert(switched.status=='success' and switched.config_file=='@oix' and current==managed_path)
private_result(switched)
local updated=invoke('action_update_config',{filename='@oix'})
assert(updated.status=='success' and refreshes==1 and #calls==0)
refreshing=false
updated=invoke('action_update_config',{filename='@oix'})
assert(updated.status=='error' and updated.message==refresh_error and refreshes==2); private_result(updated)
token=''
for _, spec in ipairs({{'action_switch_config',{config_file='@oix'}},{'action_update_config',{filename='@oix'}},{'action_oc_action',{config_file='@oix',action='start'}}}) do
  local result=invoke(spec[1],spec[2]); assert(result.status=='error' and #changes==0 and #calls==0); private_result(result)
end
list=invoke('action_config_file_list'); assert(not list.config_files[1].available); private_result(list)
local stopped=invoke('action_oc_action',{config_file='@oix',action='stop'}); assert(stopped.status=='success')
token='fixture-token'
local action=invoke('action_oc_action',{config_file='@oix',action='restart'}); assert(action.status=='success' and current==managed_path)
local overwrite=invoke('action_overwrite_subscribe_info',{method='GET'})
assert(overwrite.data.test.config[1]=='@oix' and overwrite.data.test.config[2]=='/etc/openclash/config/ordinary.yaml'); private_result(overwrite)
local saved=invoke('action_overwrite_subscribe_info',{method='POST',filename='test',config='@oix\nall',type='file'})
assert(saved.status=='success')
assert(sections.config_overwrite[1].config[1]==managed_path and sections.config_overwrite[1].config[2]=='all')
current='/etc/openclash/config/ordinary.yaml'
local ordinary=invoke('action_config_file_read',{config_file=current}); assert(ordinary=='ordinary: true' and response_headers.content_type=='text/plain; charset=utf-8' and response_headers['X-Oc-Size']=='12')
for _, success in ipairs({true,false}) do
  save_success=success
  local result=invoke('oix_login_info_save',{checkin='1',interval='12',multiple='2',show_info_page='0'})
  assert(result.status==(success and 'success' or 'error'))
  assert(saved_settings.checkin=='1' and saved_settings.interval=='12' and saved_settings.multiple=='2' and saved_settings.show_info_page=='0')
  assert(#changes==0 and response_headers['Cache-Control']=='no-store')
end
print(string.format('PASS: %d controller requests, managed masking, operation guards, update failures, and overwrite round-trip',cases))
