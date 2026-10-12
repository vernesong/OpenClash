-- Run from the repository root: lua5.1 tests/oix_managed_test.lua
-- All filesystem, UCI, network and service operations stay inside test fixtures.
local SOURCE = '/etc/openclash/config/oixCloud - smart.yaml'
local PROVIDER = '/etc/openclash/proxy_provider/oixCloud'
local TOKEN_FILE = '/etc/openclash/.oix_token'
local OLD_CONFIG = '/etc/openclash/config/ordinary.yaml'
local TOKEN, OLD_TOKEN, REBOUND_TOKEN = string.rep('a', 32), string.rep('b', 32), string.rep('c', 32)
local state, scenario, calls, files, progress, permissions, commits
local function equal(actual, expected, message)
    assert(actual == expected, (message or 'unexpected value') .. ': ' .. tostring(actual) .. ' ~= ' .. tostring(expected))
end
local function copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = copy(v) end
    return result
end
local cursor = {}
function cursor:get(_, section, key)
    return key and state[section] and state[section][key] or (not key and state[section] and state[section]['.type'])
end
function cursor:set(_, section, key, value) state[section] = state[section] or {}; state[section][key] = value; return true end
function cursor:delete(_, section, key)
    if key then if state[section] then state[section][key] = nil end else state[section] = nil end
    return true
end
function cursor:commit()
    commits = commits + 1
    return not scenario.commit_failed and commits ~= scenario.fail_commit_number
end
function cursor:get_all(_, section) return copy(state[section]) end
function cursor:foreach(_, kind, callback)
    for _, id in ipairs({'legacy', 'other', 'managed'}) do
        local section = state[id]
        if section and section['.type'] == kind then callback(section) end
    end
end
function cursor:section(_, kind, id, values)
    id = id or 'managed'
    state[id] = copy(values); state[id]['.name'] = id; state[id]['.type'] = kind
    return id
end
local nixio = {
    getpid = function() return 17 end,
    open_flags = function(...) return {...} end,
    nanosleep = function() end,
}
function nixio.open(path, flags, mode)
    if path == '/tmp/lock/openclash_oix.lock' then
        return {lock=function(_, command) return command ~= 'tlock' or not scenario.locked end, close=function() end}
    end
    if scenario.write_failed or (scenario.restore_write_failed and path == SOURCE .. '.oix-17') then return nil end
    if files[path] then return nil end
    permissions[path] = mode
    return {
        writeall = function(_, data) files[path] = data; return true end,
        sync = function() return true end,
        close = function() end,
    }
end
local nfs = {
    readfile = function(path) return files[path] end,
    stat = function(path)
        return files[path] and {mtime=os.time() + (scenario.cache_clock_shift or 0), type=scenario.cache_type or 'reg', size=scenario.cache_size or #files[path]}
    end,
    chmod = function(path, mode) permissions[path] = mode; return true end,
    access = function(path) return files[path] ~= nil end,
    unlink = function(path) if scenario.unlink_failed and path == PROVIDER then return nil end; files[path] = nil; return true end,
    rename = function(from, to)
        if scenario.rename_failed and to == SOURCE then return nil end
        if not files[from] then return nil end
        files[to], files[from] = files[from], nil
        permissions[to], permissions[from] = permissions[from], nil
        return true
    end,
}
local json = {}
function json.stringify(value)
    if type(value) == 'string' then return string.format('%q', value) end
    if type(value) ~= 'table' then return tostring(value) end
    local members = {}
    for key, item in pairs(value) do members[#members + 1] = string.format('%q', key) .. ':' .. json.stringify(item) end
    return '{' .. table.concat(members, ',') .. '}'
end
function json.parse(body)
    if body == 'remote_error' then return {ret=500, msg='sensitive-fixture-error https://fixture.invalid/private?token=' .. TOKEN} end
    if body == 'information' then return {ret=200, data={token_client=scenario.token_client or (scenario.foreign_client and 'oixclash' or 'openclash')}} end
    if body == 'rebound' then return {ret=200, data={token_client='openclash', token=REBOUND_TOKEN}} end
    if body == 'login' then return {ret=200, data={token=TOKEN}} end
    if body == 'subscription' then return {ret=200, openclash='https://fixture.invalid/config?token=fixture'} end
    if body == 'missing_url' then return {ret=200} end
    if body == 'checkin' then return {ret=200, data={checkin='fixture'}} end
    if body == 'groups' then
        return {proxies={MAIN={type='Selector', all=scenario.unreferenced_groups and {'DIRECT'} or {'Fixture Fusion'}}, GLOBAL={type='Selector', all={'Fixture Fusion'}}}}
    end
    if body == 'provider' then return {vehicleType=scenario.http_provider and 'HTTP' or 'File', proxies=scenario.empty_provider and {} or {{name='Fixture Fusion'}}} end
    error('invalid fixture JSON')
end
package.loaded.nixio = nixio
package.loaded['nixio.fs'] = nfs
package.loaded['luci.openclash'] = {}
package.loaded['luci.jsonc'] = json
package.loaded['luci.model.uci'] = {cursor=function() return cursor end}
local real_open = io.open
io.open = function(path, mode)
    if path == '/tmp/openclash.log' then
        return {write=function(_, ...)
            local line = table.concat({...})
            assert(not line:find(TOKEN, 1, true) and not line:find(OLD_TOKEN, 1, true), 'token leaked in log')
        end, close=function() end}
    end
    return real_open(path, mode)
end
local managed = assert(loadfile('luci-app-openclash/luasrc/openclash_oix.lua'))()
local function request_result(body, status) return body .. '\n' .. tostring(status or 200) end
local function run(argv, input, env)
    calls[#calls + 1] = {argv=copy(argv), input=input, env=copy(env)}
    for _, value in ipairs(argv) do
        assert(not value:find(TOKEN, 1, true) and not value:find(OLD_TOKEN, 1, true) and not value:find(REBOUND_TOKEN, 1, true), 'token in command arguments')
    end
    if argv[1] == '/usr/bin/curl' then
        equal(#argv, 3); equal(argv[2], '--config'); equal(argv[3], '-')
        local deadline = input:find('/version"', 1, true) and 2 or 45
        assert(input:find('max%-time = ' .. deadline) and input:find('max%-filesize = 16777216'), 'missing request bounds')
        if scenario.remote_error and input:find('/' .. scenario.remote_error .. '"', 1, true) then return request_result('remote_error') end
        if input:find('/information"', 1, true) then return request_result('information', scenario.auth_failed and 401 or 200) end
        if input:find('/token/rebind"', 1, true) then return request_result('rebound', scenario.rebind_failed and 500 or 200) end
        if input:find('/api/v1/login"', 1, true) then return request_result('login') end
        if input:find('/checkin"', 1, true) then return request_result('checkin', scenario.checkin_failed and 500 or 200) end
        if input:find('/managed/clash"', 1, true) then return request_result(scenario.missing_url and 'missing_url' or 'subscription') end
        if input:find('fixture.invalid/config', 1, true) then return request_result('original-yaml-with-subscription-url', scenario.fetch_failed and 500 or 200) end
        assert(input:find('noproxy = "*"', 1, true), 'local controller must bypass HTTP proxies')
        if input:find('/version"', 1, true) then return request_result('version', scenario.not_ready and 503 or 200) end
        if input:find('/oix/login"', 1, true) then
            if scenario.core_login_failed then return request_result('', 403) end
            files[PROVIDER], files[TOKEN_FILE] = 'new-encrypted-provider', state.config.oix_token
            return request_result('', 204)
        end
        if input:find('/providers/proxies/oixCloud"', 1, true) then return request_result('provider', scenario.provider_failed and 500 or 200) end
        if input:find('/proxies"', 1, true) then return request_result('groups', scenario.groups_failed and 500 or 200) end
        error('unexpected request fixture')
    end
    if argv[1] == '/usr/share/openclash/openclash_core.sh' then
        equal(env.OIX_INSTALL_ONLY, '1')
        return not scenario.install_failed and '' or nil
    end
    if argv[2] == '-v' then return scenario.wrong_core and 'Mihomo upstream' or 'Mihomo oix' end
    if argv[1] == '/usr/bin/ruby' then
        if scenario.invalid_yaml then return nil end
        files[argv[#argv]] = 'cleaned-yaml-file-provider'
        return ''
    end
    if argv[2] == '-t' then
        equal(env.OIX_CLIENT, 'openclash'); equal(files[argv[#argv]], 'cleaned-yaml-file-provider')
        return not scenario.invalid_config and '' or nil
    end
    if argv[1] == '/etc/init.d/openclash' then
        if argv[2] == 'restart' then
            assert(state.managed and not state.legacy, 'legacy URL must be removed before restart')
            assert(not state.config.oix_email and not state.config.oix_passwd, 'saved password must be cleared before restart')
            if scenario.restart_failed then return nil end
        end
        if argv[2] == 'stop' and scenario.stop_failed then return nil end
        if argv[2] == 'start' and scenario.start_failed then return nil end
        return ''
    end
    error('unexpected command fixture')
end
-- Replace only the subprocess boundary, preserving the production request,
-- validation, persistence, activation and rollback implementations.
local visited = {}
local function replace_run(fn)
    if visited[fn] then return end
    visited[fn] = true
    for index = 1, 100 do
        local name, value = debug.getupvalue(fn, index)
        if not name then break end
        if name == 'run' then debug.setupvalue(fn, index, run)
        elseif type(value) == 'function' then replace_run(value) end
    end
end
for _, fn in pairs(managed) do if type(fn) == 'function' then replace_run(fn) end end
local function reset(options)
    scenario, calls, progress, permissions, commits = options or {}, {}, {}, {}, 0
    state = {
        config = {oix_token=OLD_TOKEN, config_path=OLD_CONFIG, enable='1', oix_email='fixture@example.invalid', oix_passwd='fixture-only'},
        legacy = {['.name']='legacy', ['.type']='config_subscribe', name='oixCloud - smart', address={'https://fixture.invalid/old-secret'}},
        other = {['.name']='other', ['.type']='config_subscribe', name='ordinary', address={'https://fixture.invalid/ordinary'}},
    }
    files = {[SOURCE]='old-source', [PROVIDER]='old-provider', [TOKEN_FILE]=OLD_TOKEN, [OLD_CONFIG]='ordinary-source'}
end
local function callback(step, message)
    assert(not message:find(TOKEN, 1, true), 'token in progress')
    progress[#progress + 1] = step
end
local function has_command(action)
    for _, call in ipairs(calls) do if call.argv[1] == '/etc/init.d/openclash' and call.argv[2] == action then return true end end
    return false
end
local count = 0
local function test(name, callback)
    callback(); count = count + 1; print('PASS ' .. name)
end
for _, failure in ipairs({'auth_failed','missing_url','fetch_failed','write_failed','rename_failed','install_failed','wrong_core','invalid_yaml','invalid_config','restart_failed','not_ready','core_login_failed','provider_failed','empty_provider','http_provider','unreferenced_groups','groups_failed','locked'}) do
    test('login failure restores state: ' .. failure, function()
        reset({[failure]=true})
        local ok, err = managed.login({token=TOKEN}, callback)
        assert(not ok and type(err) == 'string', 'failure must not be reported as successful login')
        equal(state.config.oix_token, OLD_TOKEN); equal(state.config.config_path, OLD_CONFIG); equal(state.config.enable, '1')
        equal(files[SOURCE], 'old-source'); equal(files[PROVIDER], 'old-provider'); equal(files[TOKEN_FILE], OLD_TOKEN)
        assert(state.legacy and not state.managed, 'subscription migration must happen after verified activation')
        if has_command('restart') then assert(has_command('stop') and has_command('start'), 'previous service was not restored') end
        for path in pairs(files) do assert(not path:find('.oix-', 1, true), 'temporary file left after failure') end
    end)
end
test('login requires authenticated loaded provider and removes old subscription', function()
    reset(); assert(managed.login({token=TOKEN}, callback))
    equal(state.config.oix_token, TOKEN); equal(state.config.config_path, SOURCE); equal(state.config.oix_previous_config, OLD_CONFIG)
    equal(files[SOURCE], 'cleaned-yaml-file-provider'); equal(permissions[SOURCE], 384)
    assert(not state.legacy and state.managed.oix_managed == '1' and state.managed.enabled == '0' and not state.managed.address)
    assert(state.other and not state.config.oix_email and not state.config.oix_passwd)
    equal(files[TOKEN_FILE], TOKEN); assert(has_command('restart')); equal(progress[#progress], 'loading')
end)
test('email login passes credentials through request input', function()
    reset(); assert(managed.login({email='fixture@example.invalid', passwd='quote"slash\\\nfixture'}, callback))
    for _, call in ipairs(calls) do for _, arg in ipairs(call.argv) do assert(not arg:find('fixture@example.invalid', 1, true), 'email leaked in arguments') end end
end)
test('foreign client token uses rebound token', function()
    reset({foreign_client=true}); assert(managed.login({token=TOKEN}, callback)); equal(state.config.oix_token, REBOUND_TOKEN)
end)
test('refresh skips core installation and verifies active managed nodes', function()
    reset(); state.config.config_path=SOURCE; assert(managed.refresh(callback))
    for _, call in ipairs(calls) do assert(call.argv[1] ~= '/usr/share/openclash/openclash_core.sh', 'refresh unnecessarily installs core') end
    equal(state.config.oix_token, OLD_TOKEN); equal(files[TOKEN_FILE], OLD_TOKEN)
end)
test('invalid token performs no network or service operation', function()
    reset(); assert(not managed.login({token='invalid'}, callback)); equal(#calls, 0)
end)
test('logout restores ordinary config and removes managed files', function()
    reset(); state.config.config_path=SOURCE; state.config.oix_previous_config=OLD_CONFIG
    assert(managed.logout()); equal(state.config.config_path, OLD_CONFIG); assert(not state.config.oix_token and not state.legacy)
    assert(not files[SOURCE] and not files[PROVIDER] and not files[TOKEN_FILE]); assert(has_command('stop') and has_command('start'))
    assert(state.other and files[OLD_CONFIG])
end)
test('logout without previous config disables service', function()
    reset(); state.config.config_path=SOURCE
    assert(managed.logout()); equal(state.config.enable, '0'); assert(not state.config.config_path and not has_command('start'))
end)
test('failed logout preserves credentials and configuration', function()
    reset({stop_failed=true}); local ok, err=managed.logout(); assert(not ok and err)
    equal(state.config.oix_token, OLD_TOKEN); equal(files[SOURCE], 'old-source'); assert(state.legacy)
end)
test('foreign token rebind failure stops before installation', function()
    reset({foreign_client=true, rebind_failed=true}); local ok, err=managed.login({token=TOKEN}, callback)
    assert(not ok and err); equal(state.config.oix_token, OLD_TOKEN)
    for _, call in ipairs(calls) do equal(call.argv[1], '/usr/bin/curl') end
end)
test('website token with empty client remains compatible', function()
    reset({token_client=''}); assert(managed.login({token=TOKEN}, callback))
    equal(state.config.oix_token, TOKEN)
    for _, call in ipairs(calls) do assert(not call.input or not call.input:find('/token/rebind', 1, true), 'website token unnecessarily rebound') end
end)
test('refresh uses rebound token for managed activation', function()
    reset({foreign_client=true}); state.config.config_path=SOURCE; assert(managed.refresh(callback))
    equal(state.config.oix_token, REBOUND_TOKEN); equal(files[TOKEN_FILE], REBOUND_TOKEN)
end)
test('refresh rebind failure preserves active configuration', function()
    reset({foreign_client=true, rebind_failed=true}); assert(not managed.refresh(callback))
    equal(state.config.config_path, OLD_CONFIG); equal(files[SOURCE], 'old-source')
end)
test('refresh without token performs no network operation', function()
    reset(); state.config.oix_token=nil; assert(not managed.refresh(callback)); equal(#calls, 0)
end)
test('account info cache uses private file permissions', function()
    reset(); local info=managed.information(); assert(info and info.ret == 200)
    equal(permissions['/tmp/oix_info'], 384)
end)
test('scheduled checkin honors disabled setting and interval', function()
    reset(); assert(not managed.checkin(true)); equal(#calls, 0)
    state.config.oix_checkin='1'; files['/tmp/oix_checkin']='cached-result'
    assert(not managed.checkin(true)); equal(#calls, 0)
end)
test('successful checkin clears account cache and writes private result', function()
    reset(); files['/tmp/oix_info']='cached-info'; local info=managed.checkin(false)
    assert(info and info.ret == 200 and not files['/tmp/oix_info'])
    equal(permissions['/tmp/oix_checkin'], 384)
end)
test('failed checkin reports failure without clearing account cache', function()
    reset({checkin_failed=true}); files['/tmp/oix_info']='cached-info'
    assert(not managed.checkin(false)); equal(files['/tmp/oix_info'], 'cached-info')
end)
test('refresh updates an inactive account configuration without switching ordinary config', function()
    reset(); assert(managed.refresh(callback))
    equal(state.config.config_path, OLD_CONFIG); equal(state.config.enable, '1')
    equal(files[SOURCE], 'cleaned-yaml-file-provider'); equal(files[PROVIDER], 'old-provider')
    assert(state.managed and not state.legacy and not has_command('restart') and not has_command('stop'))
    for _, call in ipairs(calls) do assert(not call.input or not call.input:find('/oix/login', 1, true), 'inactive refresh changed the running account') end
end)
test('refresh of disabled managed config does not enable or restart service', function()
    reset(); state.config.config_path=SOURCE; state.config.enable='0'
    assert(managed.refresh(callback)); equal(state.config.enable, '0'); equal(state.config.config_path, SOURCE)
    assert(not has_command('restart') and not has_command('start'))
end)
test('failed UCI activation commit restores credentials, marker and source', function()
    reset({fail_commit_number=1}); local ok, err=managed.login({token=TOKEN}, callback)
    assert(not ok and err); equal(state.config.oix_token, OLD_TOKEN); equal(state.config.config_path, OLD_CONFIG)
    equal(state.config.oix_email, 'fixture@example.invalid'); equal(state.config.oix_passwd, 'fixture-only')
    equal(files[SOURCE], 'old-source'); assert(state.legacy and not state.managed)
    assert(not has_command('restart'))
end)
test('rollback restart failure is reported separately', function()
    reset({provider_failed=true, start_failed=true}); local ok, err=managed.login({token=TOKEN}, callback)
    assert(not ok and err and err:find('restore', 1, true), 'rollback failure must remain visible')
end)
test('rollback private file restore failure remains visible', function()
    reset({provider_failed=true, restore_write_failed=true}); local ok, err=managed.login({token=TOKEN}, callback)
    assert(not ok and err and err:find('restore', 1, true), 'file restoration failure must remain visible')
end)
test('logout without managed ownership is a no-op', function()
    reset(); state.config.oix_token=nil; files[TOKEN_FILE]=nil
    assert(managed.logout()); equal(#calls, 0); equal(files[SOURCE], 'old-source'); assert(state.legacy)
end)
test('failed logout commit retains managed source and token file', function()
    reset({fail_commit_number=1}); local ok, err=managed.logout()
    assert(not ok and err); equal(files[SOURCE], 'old-source'); equal(files[TOKEN_FILE], OLD_TOKEN)
    equal(state.config.oix_token, OLD_TOKEN); assert(state.legacy and has_command('start'))
end)
test('logout cleanup failure is not reported as success', function()
    reset({unlink_failed=true}); local ok, err=managed.logout()
    assert(not ok and err); equal(files[PROVIDER], 'old-provider')
    equal(state.config.oix_token, OLD_TOKEN); equal(files[SOURCE], 'old-source'); assert(state.legacy and has_command('start'))
end)
test('logout restore start failure is not reported as success', function()
    reset({start_failed=true}); state.config.config_path=SOURCE; state.config.oix_previous_config=OLD_CONFIG
    local ok, err=managed.logout(); assert(not ok and err); equal(state.config.config_path, OLD_CONFIG); assert(not state.config.oix_token and not files[TOKEN_FILE])
end)
test('valid account cache is private and avoids a network request', function()
    reset(); files['/tmp/oix_info']='information'; permissions['/tmp/oix_info']=420
    local info=managed.information(); assert(info and info.ret == 200); equal(#calls, 0); equal(permissions['/tmp/oix_info'], 384)
end)
for name, options in pairs({future={cache_clock_shift=60}, stale={cache_clock_shift=-901}, oversized={cache_size=16777217}, directory={cache_type='dir'}}) do
    test('invalid account cache is refreshed: ' .. name, function()
        reset(options); files['/tmp/oix_info']='information'; local info=managed.information()
        assert(info and info.ret == 200); equal(#calls, 1)
    end)
end
test('future scheduled checkin timestamp does not suppress checkin', function()
    reset({cache_clock_shift=3600}); state.config.oix_checkin='1'; files['/tmp/oix_checkin']='checkin'
    local info=managed.checkin(true); assert(info and info.ret == 200); equal(#calls, 1)
end)
test('rollback UCI commit failure is reported separately', function()
    reset({provider_failed=true, fail_commit_number=2}); local ok, err=managed.login({token=TOKEN}, callback)
    assert(not ok and err and err:find('restore', 1, true)); assert(not has_command('start'))
end)
test('rollback stops before restoring files and fails safely if stop fails', function()
    reset({provider_failed=true, stop_failed=true}); local ok, err=managed.login({token=TOKEN}, callback)
    assert(not ok and err and err:find('restore', 1, true))
    equal(files[SOURCE], 'cleaned-yaml-file-provider'); equal(state.config.oix_token, TOKEN); assert(not has_command('start'))
end)
test('inactive refresh commit failure restores ordinary service selection without restart', function()
    reset({fail_commit_number=1}); local ok, err=managed.refresh(callback)
    assert(not ok and err); equal(state.config.config_path, OLD_CONFIG); equal(state.config.enable, '1')
    equal(files[SOURCE], 'old-source'); assert(state.legacy and not has_command('restart') and not has_command('stop'))
end)
for name, options in pairs({
    token_login={path='information', method='login', input={token=TOKEN}},
    email_login={path='api/v1/login', method='login', input={email='fixture@example.invalid', passwd='fixture-only'}},
    refresh={path='managed/clash', method='refresh'},
    core_login={path='oix/login', method='login', input={token=TOKEN}},
}) do
    test('remote sensitive error is not exposed: ' .. name, function()
        reset({remote_error=options.path})
        local ok, err
        if options.method == 'login' then ok, err=managed.login(options.input, callback)
        else ok, err=managed.refresh(callback) end
        assert(not ok and type(err) == 'string')
        assert(not err:find(TOKEN, 1, true) and not err:find('sensitive-fixture-error', 1, true) and not err:find('https://', 1, true), 'remote error leaked across module boundary')
    end)
end
test('remote sensitive checkin error is not returned or cached', function()
    reset({remote_error='checkin'}); local info=managed.checkin(false)
    local value=json.stringify(info or {}) .. (files['/tmp/oix_checkin'] or '')
    assert(not value:find(TOKEN, 1, true) and not value:find('sensitive-fixture-error', 1, true), 'remote checkin error leaked')
end)
test('settings persist validated values without touching account state or services', function()
    reset()
    assert(managed.save_settings({checkin='1', interval='720', multiple='100', show_info_page='0'}))
    equal(state.config.oix_checkin, '1'); equal(state.config.oix_checkin_interval, '720')
    equal(state.config.oix_checkin_multiple, '100'); equal(state.config.oix_show_info_page, '0')
    assert(managed.save_settings({checkin='0'}))
    equal(state.config.oix_checkin, '0'); equal(state.config.oix_checkin_multiple, '100')
    equal(state.config.oix_token, OLD_TOKEN); equal(#calls, 0); equal(commits, 2)
end)
for _, input in ipairs({
    {checkin='yes'}, {show_info_page='2'}, {interval='0'}, {interval='721'},
    {interval='1.5'}, {multiple='101'}, {multiple='-1'}, {multiple='1.2'},
    {multiple='nan'}, {multiple='inf'}, {multiple='1tail'},
}) do
    test('invalid settings are rejected before any write', function()
        reset(); input.checkin=input.checkin or '1'
        assert(not managed.save_settings(input)); equal(commits, 0)
        for key in pairs(state.config) do
            assert(not key:find('oix_checkin',1,true) and key ~= 'oix_show_info_page')
        end
        equal(#calls, 0)
    end)
end
test('settings honor the account operation lock', function()
    reset({locked=true}); assert(not managed.save_settings({checkin='1'}))
    equal(state.config.oix_checkin, nil); equal(commits, 0)
end)
test('settings commit failure is not reported as success', function()
    reset({commit_failed=true}); assert(not managed.save_settings({checkin='1'})); equal(commits, 1)
end)
io.open = real_open
print(string.format('%d offline managed-flow cases passed', count))
