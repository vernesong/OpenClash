-- Run from the repository root with Lua 5.1 or LuaJIT.
local function read(path)
 local f = assert(io.open(path)); local data = f:read('*a'); f:close(); return data
end
local controller = read('luci-app-openclash/luasrc/controller/openclash.lua')
local helpers = read('luci-app-openclash/luasrc/openclash.lua')
local function extract(source, name, next_marker, env, global)
 local start = assert(source:find((global and 'function ' or 'local function ') .. name .. '(', 1, true))
 local finish = assert(source:find('\n' .. next_marker, start, true))
 local chunk = assert(loadstring(source:sub(start, finish - 1) .. '\nreturn ' .. name))
 setfenv(chunk, setmetatable(env, {__index = _G}))
 return chunk()
end
local function encode(s)
 return (s:gsub('[^%w%-%.%_%~]', function(c) return string.format('%%%02X', c:byte()) end))
end
local cases = 0
for _, mode in ipairs({'reachable', 'offline', 'alternate', 'unreferenced', 'empty'}) do
 local probes = {}
 local env = {
  oix_progress = function() end, HTTP = {urlencode = encode},
  nixio = {nanosleep = function() end}, json = {parse = function(x) return x end}
 }
 env.oix_core_api = function(_, path)
  if path == '/version' then return {}, 200 end
  if path == '/providers/proxies/oixCloud' then
   return {proxies = mode == 'empty' and {} or {{name='node /1',alive=false},{name='node2',alive=false},{name='node3',alive=false},{name='node4',alive=false}}}, 200
  end
  if path == '/proxies' then return {proxies={Proxy={now='node /1',all= mode=='unreferenced' and {'DIRECT'} or {'node /1','node2'}}}},200 end
  probes[#probes+1] = path
  assert(path:find('/healthcheck?timeout=3000',1,true))
  assert(not path:find('node /1',1,true), 'node name must be escaped')
  if mode=='reachable' or mode=='alternate' and path:find('/node2/',1,true) then return {delay=12},200 end
  return {},504
 end
 local wait = extract(controller,'oix_wait_loaded','local function fetch_oix_sub',env)
 local ready, warning = wait()
 if mode=='empty' or mode=='unreferenced' then assert(not ready and warning and #probes==0)
 elseif mode=='reachable' then assert(ready and not warning and #probes==1)
 else assert(ready and warning and #probes<=3); if mode=='alternate' then assert(warning:find('selected node',1,true)) end end
 cases=cases+1
end
local errorMessage = extract(controller,'oix_cli_error','local function oix_account_token', {OIX_CORE_MISSING='missing core'})
assert(errorMessage({code='rejected',error='the request was refused by the server'},'fallback')=='the request was refused by the server')
assert(errorMessage({code='auth',error='wrong password'},'fallback')=='wrong password')
cases=cases+2

for _, mode in ipairs({'success','offline','start_failed','load_failed','download_failed','session_changed','activation_save_failed','subscription_save_failed'}) do
 local values={config_path='/etc/openclash/config/previous.yaml', enable='0',oix_token=mode=='session_changed' and 'new-session' or 'fixture-token'}
 local commits=0
 local uci={set=function(_,_,_,key,value) values[key]=value end,get=function(_,_,_,key)return values[key] end,
  commit=function()commits=commits+1;return not (mode=='activation_save_failed' and commits==1 or mode=='subscription_save_failed' and commits==2)end,load=function()end,
  foreach=function()end,add=function()return 'subscription' end}
 local env={uci=uci, OIX_MANAGED_ADDRESS='oixcloud://managed',oix_valid_token=function()return true end,
  oix_progress=function()end, oix_quote=function(x)return x end,meta_core_path='/fixture/core',
  luci={i18n={translate=function(x)return x end}},oix_cli_error=errorMessage,
  oix_wait_loaded=function() if mode=='load_failed' then return nil,'No managed nodes were loaded' end;return true,mode=='offline' and 'connectivity warning' or nil end,
  fs={oix_cli=function()return mode=='download_failed' and {code='timeout',error='timeout'} or {} end,
   unlink=function()end,rename=function()return true end,chmod=function()end,config_refs=function()end},
  SYS={exec=function(command)
   if command:find('mktemp',1,true) then return '/etc/openclash/config/.oixCloud.fixture' end
   if command:find('subscription_status',1,true) then return 'OK:0' end
   return ''
  end,call=function(command)
   if command:find(' restart ',1,true) then
    assert(mode~='activation_save_failed' and mode~='subscription_save_failed','restart after settings save failure')
    if mode=='start_failed' then return 1 end
   end
   return 0
  end}
 }
 local fetch=extract(controller,'fetch_oix_sub','function oix_login()',env)
 local ok,warning=fetch('fixture-token')
 if mode=='download_failed' or mode=='session_changed' then assert(not ok and values.config_path=='/etc/openclash/config/previous.yaml' and values.enable=='0')
 else
  assert(ok and values.config_path=='/etc/openclash/config/oixCloud.yaml' and values.enable=='1')
  assert((mode=='success' and not warning) or (mode~='success' and warning))
  if mode=='activation_save_failed' or mode=='subscription_save_failed' then assert(warning:find('settings could not be saved',1,true))end
 end
 cases=cases+1
end

for _,mode in ipairs({'stopped','authenticated','default_enabled','empty_password'}) do
 local running = mode ~= 'stopped'
 local payload,commands
 commands={}
 local env={uci_get_config=function(_,key) if key=='mixed_port' then return '7893' end end,
  uci={foreach=function(_,_,_,fn)
   local section={username='fixture user',password=mode=='empty_password' and '' or 'fixture@password'}
   if mode~='default_enabled' then section.enabled='1' end
   fn(section)
  end},
  fs={access=function()return true end,writefile=function()return true end,remove=function()end},
  HTTP={urlencode=encode},UTIL={shellquote=function(x)return x end},
  json={stringify=function(request)payload=request;return '{}' end,parse=function()return {}end},
  SYS={call=function()return running and 0 or 1 end,exec=function(cmd)
   commands[#commands+1]=cmd
   if cmd:find(' -v ',1,true) then return 'mihomo oix' end
   if cmd:find('mktemp',1,true) then return '/tmp/.oix_cli.fixture' end
   return '{}'
  end}
 }
 local cli=extract(helpers,'oix_cli','--- Appends',env,true)
 assert(cli('managed-config',{token='fixture-token'}))
 if not running then assert(not payload.proxy)
 elseif mode=='empty_password' then assert(payload.proxy=='http://127.0.0.1:7893')
 else assert(payload.proxy=='http://fixture%20user:fixture%40password@127.0.0.1:7893') end
 for _,cmd in ipairs(commands)do assert(not cmd:find('fixture-token',1,true) and not cmd:find('fixture@password',1,true))end
 cases=cases+1
end

-- Account refresh distinguishes authentication failures from temporary outages.
for _,mode in ipairs({'auth','rejected','network','success','fresh','switched','signed_out'}) do
 local values={oix_token=mode~='signed_out' and 'fixture-token' or nil}
 local files={['/tmp/oix_info']={ret=200,data={plan='cached'}},['/tmp/oix_checkin']='old'}
 local output,calls=nil,0
 local env={OIX_MANAGED_ADDRESS='oixcloud://managed',oix_valid_token=function(v)return v~=nil end,
  oix_ensure_core=function()return true end,luci={i18n={translate=function(v)return v end}},
  json={stringify=function(v)return v end,parse=function(v)return v end},SYS={call=function()return 0 end},
  HTTP={prepare_content=function()end,header=function()end,write_json=function(v)output=v end}}
 env.uci={load=function()end,get=function(_,_,_,key)return values[key]end,
  delete=function(_,_,_,key)values[key]=nil end,foreach=function()end,commit=function()end}
 env.fs={uci_get_config=function(_,key)return values[key]end,readfile=function(path)return files[path]end,
  writefile=function(path,v)files[path]=v end,unlink=function(path)files[path]=nil end,
  access=function(path)return files[path]~=nil end,mtime=function()return mode=='fresh' and os.time() or 0 end,
  oix_cli=function()
   calls=calls+1
   if mode=='switched' then values.oix_token='new-session';files['/tmp/oix_info']={ret=200,data={plan='new-session'}} end
   if mode=='success' then return {information={plan='updated'}} end
   return {code=mode=='switched' and 'auth' or mode,error='fixture-error'}
  end}
 env.oix_clear_account=extract(controller,'oix_clear_account','local function oix_core_ready',env)
 local info=extract(controller,'oix_info','function oix_checkin()',env,true)
 info()
 if mode=='auth' or mode=='signed_out' then
  assert(output.code=='auth' and output.result=='error' and not values.oix_token)
  if mode=='auth' then assert(not files['/tmp/oix_info'] and not files['/tmp/oix_checkin'])end
 elseif mode=='rejected' then assert(output.result=='error' and not output.code and values.oix_token)
 elseif mode=='switched' then assert(not output.code and values.oix_token=='new-session' and files['/tmp/oix_info'].data.plan=='new-session')
 else assert(output.result.plan==(mode=='success' and 'updated' or 'cached') and values.oix_token) end
 assert(calls==((mode=='fresh' or mode=='signed_out') and 0 or 1))
 cases=cases+1
end

-- Authentication is persisted even when configuration download/validation fails.
for _,mode in ipairs({'success','download_failed','activation_failed','auth','refresh','refresh_signed_out','save_failed','auth_switched','download_signed_out'}) do
 local values={oix_token=mode=='refresh' and 'fixture-token' or nil}
 local output,cliCalls,fetchCalls=nil,0,0
 local form=mode:find('refresh',1,true) and {refresh='1'} or {email='fixture@example.test',passwd='fixture-password'}
 local env={OIX_CORE_MISSING='missing core',oix_ensure_core=function()return true end,
  oix_valid_token=function(v)return v=='fixture-token' end,oix_cli_error=errorMessage,
  luci={i18n={translate=function(v)return v end}},json={stringify=function(v)return v end},
  write_padded=function(v)if type(v)=='table' then output=v end end,
  HTTP={prepare_content=function()end,header=function()end,formvalue=function(key)return form[key]end}}
 env.uci={set=function(_,_,_,key,value)values[key]=value end,commit=function()return mode~='save_failed' end,
  load=function()end,get=function(_,_,_,key)return values[key]end}
 env.fs={unlink=function()end,uci_get_config=function(_,key)return values[key]end,
  oix_cli=function()cliCalls=cliCalls+1;return {token='fixture-token'}end}
 env.oix_clear_account=function(token)if values.oix_token~=token then return false end;values.oix_token=nil;return true end
 env.fetch_oix_sub=function(token)
  fetchCalls=fetchCalls+1
  assert(values.oix_token==token,'subscription started before authentication was saved')
  if mode=='auth_switched' then values.oix_token='new-session';return nil,'expired','auth' end
  if mode=='download_signed_out' then values.oix_token=nil;return nil,'network failure','network' end
  if mode=='auth' then return nil,'expired','auth' end
  if mode=='download_failed' then return nil,'download timeout' end
  return true,mode=='activation_failed' and 'activation failed' or nil
 end
 local login=extract(controller,'oix_login','function oix_google_begin()',env,true)
 login()
 if mode=='auth_switched' or mode=='download_signed_out' then
  assert(output.stage=='error' and output.code=='session_changed')
  assert(values.oix_token==(mode=='auth_switched' and 'new-session' or nil))
 elseif mode=='save_failed' then assert(output.stage=='error' and output.result:find('Unable to save sign-in',1,true))
 elseif mode=='auth' or mode=='refresh_signed_out' then assert(output.stage=='error' and output.code=='auth' and not values.oix_token)
 else
  assert(output.stage=='done' and output.result==200 and values.oix_token=='fixture-token')
  if mode=='download_failed' then assert(output.warning=='Signed in, but subscription update failed: download timeout')end
  if mode=='activation_failed' then assert(output.warning=='activation failed')end
 end
 assert(cliCalls==(form.refresh and 0 or 1))
 assert(fetchCalls==((mode=='refresh_signed_out' or mode=='save_failed') and 0 or 1))
 cases=cases+1
end
print(string.format('OpenClash connectivity: %d behavior cases passed',cases))
