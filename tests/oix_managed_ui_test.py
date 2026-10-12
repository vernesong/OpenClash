"""Run from any directory: python3 tests/oix_managed_ui_test.py.

Execute production Lua helpers and JavaScript methods with isolated fixtures.
Requires Lua and Node.js; LUA and NODE may select alternate executables.
"""
from pathlib import Path
import os
import re
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1] / 'luci-app-openclash/luasrc'
lua = os.environ.get('LUA', 'lua')
node = os.environ.get('NODE', 'node')


def run_fixture(name, content, runtime, *arguments):
    with tempfile.TemporaryDirectory(prefix='oix-ui-test-') as directory:
        path = Path(directory) / name
        path.write_text(content)
        subprocess.run([runtime, *arguments, str(path)], check=True)

helper=(root/'openclash.lua').read_text();helper=helper[helper.index('function oix_config_path()'):helper.index('function get_file_path_from_request()')]
helper_environment='''local sections = {}
local token = nil
local uci = { foreach=function(_, _, _, cb) for _, section in ipairs(sections) do if cb(section) == false then break end end end }
function uci_get_config() return token end
package.preload['luci.i18n'] = function() return { translate=function(text) return text end } end
'''+helper
harness=helper_environment+'''
assert(is_oix_managed_config('@oix'))
assert(not is_oix_managed_config(nil))
assert(not is_oix_managed_config('oixCloud - smart.yaml'))
token='token'
for _, value in ipairs({'oixCloud - smart', 'oixCloud - smart.yaml', oix_config_path(), '/etc/openclash/oixCloud - smart.yaml'}) do assert(is_oix_managed_config(value), value) end
for _, value in ipairs({'ordinary.yaml', '/tmp/oixCloud - smart.yaml', 'custom-oixCloud - smart.yaml', '/etc/openclash/config/nested/oixCloud - smart.yaml'}) do assert(not is_oix_managed_config(value), value) end
token=nil
sections={{name='oixCloud - smart',oix_managed='1'}}
assert(is_oix_managed_config(oix_config_path()))
assert(config_display_name(oix_config_path())=='oixCloud Managed Configuration')
assert(config_display_name('ordinary.yaml')=='ordinary.yaml')
assert(is_oix_managed_file('/etc/openclash/proxy_provider/oixCloud'))
assert(is_oix_managed_file('/etc/openclash/proxy_provider/./oixCloud'))
assert(is_oix_managed_file('/etc/openclash/proxy_provider//oixCloud'))
assert(not is_oix_managed_config('/etc/openclash/proxy_provider/oixCloud'))
assert(not is_oix_managed_file('/tmp/oixCloud'))
assert(not is_oix_managed_file('/etc/openclash/proxy_provider/ordinary'))
sections={{name='ordinary',oix_managed='1'}}
assert(not is_oix_managed_config(oix_config_path()))
assert(not is_oix_managed_file('/etc/openclash/proxy_provider/oixCloud'))
print('Managed identity behavior passed: signed in, signed out, explicit marker, ordinary paths')
'''
run_fixture('managed-helper.lua', harness, lua)

provider_model = (root / 'model/cbi/openclash/proxy-providers-file-manage.lua').read_text()
provider_fixture = helper_environment + r"""
token='fixture-token'
local managed_cache='/etc/openclash/proxy_provider/oixCloud'
local ordinary_cache='/etc/openclash/proxy_provider/ordinary.yaml'
local commands, unlinks, redirects, options, form_sections = {}, {}, {}, {}, {}
local provider_fs={
  is_oix_managed_file=is_oix_managed_file,
  glob=function() return {managed_cache, ordinary_cache} end,
  stat=function() return {mtime=1,size=1} end,
  basename=function(path) return path:match('([^/]+)$') end,
  filesize=function() return '1 B' end,
  unlink=function(path) unlinks[#unlinks+1]=path; return true end
}
package.preload['luci.openclash']=function() return provider_fs end
package.preload['nixio.fs']=function() return {basename=provider_fs.basename} end
package.preload['luci.sys']=function() return {call=function(command) commands[#commands+1]=command;return 0 end} end
package.preload['luci.http']=function() return {urlencode=function(value) return value end,redirect=function(value) redirects[#redirects+1]=value end} end
package.preload['luci.dispatcher']=function() return {build_url=function() return '/fixture' end} end
package.preload['luci.util']=function() return {shellquote=function(value) return "'"..value.."'" end} end
package.preload['luci.model.uci']=function() return {cursor=function() return {} end} end
function translate(value) return value end
function Template(value) return value end
Table={};Button={};DummyValue={}
function SimpleForm()
  return {
    section=function(_, _, data)
      form_sections[#form_sections+1]=data
      return {option=function(_, _, key)
        local option={};options[key]=option;return option
      end}
    end,
    append=function() end
  }
end
local provider_form=assert((loadstring or load)([====[
""" + provider_model + r"""
]====]))()
local rows=form_sections[1]
assert(#rows==1 and rows[1].name=='ordinary.yaml', 'managed cache leaked into file list')
options.edit.write(nil,1)
assert(#redirects==1 and redirects[1]:find('ordinary.yaml',1,true))
options.Delete_all.write()
assert(#commands==1 and commands[1]:find(ordinary_cache,1,true))
assert(not commands[1]:find(managed_cache,1,true), 'delete all removed managed cache')
options.remove1.write(nil,1)
assert(#unlinks==1 and unlinks[1]==ordinary_cache)
rows[1]={name='oixCloud'}
local redirect_count=#redirects
options.edit.write(nil,1)
options.download1.write(nil,1)
options.remove1.write(nil,1)
assert(#redirects==redirect_count and #unlinks==1 and rows[1].name=='oixCloud', 'managed cache action was allowed')
print('Provider file manager passed: hidden cache, direct action guards, ordinary delete, safe delete all')
"""
run_fixture('provider-file-manager.lua', provider_fixture, lua)

for model_name in ['proxies-config.lua', 'proxy-groups-config.lua', 'proxy-providers-config.lua']:
    model = (root / 'model/cbi/openclash' / model_name).read_text()
    fixture = helper_environment + r"""
token='fixture-token'
local request_path, redirects = nil, 0
local cursor={get=function() return nil end}
luci={model={uci={cursor=function() return cursor end}},sys={exec=function() return 'fixture-uuid' end}}
package.preload['luci.openclash']=function() return {get_file_path_from_request=function() return request_path end,is_oix_managed_file=is_oix_managed_file} end
package.preload['luci.sys']=function() return luci.sys end
package.preload['luci.http']=function() return {redirect=function() redirects=redirects+1 end} end
package.preload['luci.dispatcher']=function() return {build_url=function() return '/fixture' end} end
function translate(value) return value end
function Map() error('ordinary editor reached') end
local render_model=assert((loadstring or load)([====[
""" + model + r"""
]====]))
for _, path in ipairs({oix_config_path(),'/etc/openclash/oixCloud - smart.yaml','/etc/openclash/proxy_provider/oixCloud'}) do
  request_path=path
  assert(render_model()==nil)
end
assert(redirects==3, 'managed deep link was not redirected')
request_path='/etc/openclash/config/ordinary.yaml'
local ok, err=pcall(render_model)
assert(not ok and err:find('ordinary editor reached',1,true), 'ordinary editor was incorrectly blocked')
"""
    run_fixture(model_name, fixture, lua)
print('Server editor deep links passed: managed source/runtime/cache rejected, ordinary editors remain reachable')
# Exercise the new upstream streamed editor before it can open a file.
config_model = (root / 'model/cbi/openclash/config.lua').read_text()
start = config_model.index('\tfunction(meta, chunk, eof)')
end = config_model.index('\n\t\tlocal fp = HTTP.formvalue("file_type")', start)
stream_handler = config_model[start:end] + '\nend'
run_fixture('managed-stream.lua', helper_environment + """
token='fixture-token'
local opened, written, closed = 0, 0, 0
local edit_fd
local conf=oix_config_path()
local fs={is_oix_managed_file=is_oix_managed_file}
local nixio={open=function() opened=opened+1; return {
  write=function(_, value) written=written+#value end,
  close=function() closed=closed+1 end
} end}
local handler =
""" + stream_handler + """
handler({name='oc_editor_content'},'replacement',true)
assert(opened==0 and written==0 and closed==0, 'managed file was written by streamed editor')
conf='/etc/openclash/config/ordinary.yaml'
handler({name='oc_editor_content'},'ordinary',true)
assert(opened==1 and written==8 and closed==1, 'ordinary streamed editor failed')
print('Streamed CBI editor passed: managed write blocked, ordinary write preserved')
""", lua)
s=(root.parent/'root/www/luci-static/resources/openclash/js/status.js').read_text()
s=re.sub(r'<%:(.*?)%>',lambda m:m.group(1),s,flags=re.S)
s=re.sub(r'<%.*?%>','/endpoint',s,flags=re.S)
objects=s[s.index('    var ConfigFileManager = {'):s.index('    var OverwriteSubscribeManager = {')]
update=s[s.index('    function updateConfig()'):s.index('    function restartCore()')]
script=r'''
const assert = require('assert');
const nodes = new Map();
function element() { const classes = new Set(); return { textContent:'', innerHTML:'', title:'', disabled:false, style:{}, scrollWidth:0,clientWidth:100, classList:{add:c=>classes.add(c),remove:c=>classes.delete(c),contains:c=>classes.has(c),toggle:(c,on)=>on?classes.add(c):classes.delete(c)}, insertBefore(child){this.dot=child}, firstChild:null }; }
const document={getElementById:id=>{if(!nodes.has(id))nodes.set(id,element());return nodes.get(id);},querySelector:()=>element(),createElement:()=>element()};
const ocFormatUnixTime=x=>String(x),ocFormatFileSize=x=>String(x);
const localStorage={getItem:()=>null,removeItem:()=>{}};
let requestCount=0, lastParams;
const StateManager={cachedXHRGetWithParams:()=>{requestCount++}};
const XHR={get:(_,params)=>{requestCount++;lastParams=params}};
const LogManager={startLogDisplay:()=>{},markCoreStart:()=>{}};
let alerts=0;function alert(){alerts++}
'''+objects+update+r'''
ConfigFileManager.configList=[{name:'oixCloud',path:'@oix',id:'@oix',managed:true,available:false},{name:'ordinary.yaml',path:'/etc/openclash/config/ordinary.yaml'}];
ConfigFileManager.selectElement={value:'@oix'};
ConfigFileManager.rawCurrentConfig='@oix';
ConfigFileManager.currentConfig='@oix';
SubscriptionManager.currentConfigFile='@oix';
ConfigFileManager.updateSubscriptionDisplay('@oix',null);
assert.equal(document.getElementById('current-config-name').textContent,'oixCloud Managed Configuration');
assert(document.getElementById('edit_config').classList.contains('oc-hidden'));
assert(document.getElementById('edit_subscribe').classList.contains('oc-hidden'));
assert(document.getElementById('config-subscription-url').classList.contains('oc-hidden'));
assert.equal(document.getElementById('update_config').disabled,true);
assert.equal(document.getElementById('switch_config').disabled,true);
assert.equal(document.getElementById('subscription-progress-section').textContent,'Sign in to oixCloud to use this configuration');
SubscriptionManager.getSubscriptionInfo();
assert.equal(requestCount,0);
updateConfig();assert.equal(requestCount,0);assert.equal(alerts,1);
ConfigFileManager.configList[0].available=true;
ConfigFileManager.updateSubscriptionDisplay('@oix',null);
assert.equal(document.getElementById('update_config').disabled,false);
updateConfig();assert.equal(requestCount,1);assert.equal(lastParams.filename,'@oix');
ConfigFileManager.selectElement.value='/etc/openclash/config/ordinary.yaml';
ConfigFileManager.updateSubscriptionDisplay('/etc/openclash/config/ordinary.yaml',{mtime:1,size:1});
assert.equal(document.getElementById('current-config-name').textContent,'ordinary.yaml');
assert(!document.getElementById('edit_config').classList.contains('oc-hidden'));
assert(!document.getElementById('edit_subscribe').classList.contains('oc-hidden'));
assert(!document.getElementById('config-subscription-url').classList.contains('oc-hidden'));
console.log('Managed UI behavior passed: labels, hidden actions, token guard, opaque update, ordinary restore');
'''
run_fixture('managed-behavior.js', script, node)
login = (root.parent/'root/www/luci-static/resources/openclash/js/oix_login.js').read_text()
login = re.sub(r'<%:(.*?)%>', lambda match: match.group(1), login, flags=re.S)
start = login.index('doLogin: function() {') + len('doLogin: function() {')
end = login.index('var self = this, btns', start)
validation = login[start:end]
run_fixture('login-password.js', """
const assert = require('node:assert/strict');
const inputs = {'oix-email': {value: 'fixture@example.invalid'}, 'oix-passwd': {value: '  fixture-only password  '}};
const document = {getElementById: id => inputs[id]};
const errors = [];
const OixMsg = {clearAll() {}, field(id, message) {errors.push([id, message]);}};
function validateLogin() {
""" + validation + """
    return data;
}
assert.equal(validateLogin.call({activeTab: 'account'}).passwd, inputs['oix-passwd'].value);
assert.equal(errors.length, 0);
inputs['oix-passwd'].value = '';
assert.equal(validateLogin.call({activeTab: 'account'}), undefined);
assert.equal(errors[0][0], 'oix-passwd');
console.log('Login validation passed: password whitespace is preserved, empty password rejected');
""", node)
account_script = re.sub(r'<%.*?%>', '/fixture', login, flags=re.S)
run_fixture('account-responses.js', r'''
const assert = require('node:assert/strict');
const elements = new Map();
function element() {
    const classes = new Set();
    const span = {textContent: ''};
    return {checked: false, disabled: false, value: '1', innerHTML: '', textContent: '', style: {},
        classList: {add: v => classes.add(v), remove: v => classes.delete(v),
            contains: v => classes.has(v), toggle: (v,on) => on ? classes.add(v) : classes.delete(v)},
        querySelector: selector => selector === 'span' ? span : null};
}
const document = {addEventListener() {}, querySelector: () => null,
    getElementById(id) {if (!elements.has(id)) elements.set(id, element()); return elements.get(id);}};
const window = {ocOixBoot: {loggedIn: true, checkinInterval: '1', checkinMultiple: '1'}};
const setTimeout = () => 1, clearTimeout = () => {};
let response, statusCode = 200, params, requestCount = 0;
const XHR = {get(url, data, callback) {requestCount++; params=data; callback({status:statusCode}, response);}};
''' + account_script + r'''
const malicious = '<img src=x onerror=fixture()> & data';
OixMsg.show(malicious, 'error');
const bar = document.getElementById('oix-msg-bar');
assert.equal(bar.querySelector('span').textContent, malicious);
assert(!bar.innerHTML.includes(malicious), 'response text was interpreted as HTML');
for (const result of [undefined, null, {status:'error'}]) {
    response = result;
    OixCloud.loggedIn = true;
    OixCloud.doLogout(); assert.equal(OixCloud.loggedIn, true);
    OixCloud.doCheckin(); assert.equal(bar.className, 'oix-msg-bar oix-msg-error');
    OixCloud.loadAccountInfo(); assert(document.getElementById('oix-cards').classList.contains('oc-hidden'));
    for (const [method, id] of [['toggleInfoPage','oix-show-info-page'], ['toggleCheckin','oix-checkin-enable']]) {
        document.getElementById(id).checked = true;
        OixCloud[method]();
        assert.equal(document.getElementById(id).checked, false);
        assert.equal(bar.className, 'oix-msg-bar oix-msg-error');
    }
    document.getElementById('oix-checkin-interval').value = '12';
    OixCloud.saveCheckin();
    assert.equal(OixCloud.origCheckinInterval, '1');
}
response = {result:{plan:'Fixture plan'}};
OixCloud.loadAccountInfo();
assert(!document.getElementById('oix-cards').classList.contains('oc-hidden'), 'account cards stayed hidden after recovery');
assert.equal(document.getElementById('oix-header-plan').textContent, 'Fixture plan');
response = {status:'success'};
statusCode = 500;
OixCloud.saveCheckin(); assert.equal(OixCloud.origCheckinInterval, '1');
statusCode = 200;
OixCloud.saveCheckin(); assert.equal(OixCloud.origCheckinInterval, '12');
assert.equal(bar.className, 'oix-msg-bar oix-msg-success');
for (const invalid of ['', '1.5', '12tail', 'Infinity', '721']) {
    document.getElementById('oix-checkin-interval').value = invalid;
    const before = requestCount; OixCloud.saveCheckin(); assert.equal(requestCount, before);
}
document.getElementById('oix-checkin-enable').checked = true;
OixCloud.toggleCheckin();
assert.deepEqual(params, {checkin:'1'}, 'toggling checkin submitted unsaved numeric fields');
assert.equal(document.getElementById('oix-checkin-enable').checked, true);
console.log('Account UI passed: empty responses, failed saves, integer validation, recovery, and text-only messages');
''', node)
for name in ['status','config_edit','oix_login']:
 text=(root.parent/'root/www/luci-static/resources/openclash/js'/f'{name}.js').read_text();text=re.sub(r'<%.*?%>','LuciValue',text,flags=re.S)
 chunks=[text]
 run_fixture(f'{name}.js', '\n'.join(chunks), node, '--check')
print('JavaScript parse passed: status, config editor, login')
