// Run from the repository root: node tests/oix_login_stream_test.js
// Execute the actual login transport function with an in-memory XHR fixture.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const view = fs.readFileSync('luci-app-openclash/root/www/luci-static/resources/openclash/js/oix_login.js', 'utf8');
const start = view.indexOf('var doStreamLogin = function(loginData) {');
const end = view.indexOf('\n        doStreamLogin(data);', start);
assert(start >= 0 && end > start, 'login transport function was not found');
const script = view.slice(start, end).replace(/<%:([^]*?)%>/g, '$1');
let count = 0;
function fixture() {
    const events = [];
    let xhr;
    const context = {
        OIX_URLS: {login: '/fixture/oix_login'},
        onLoginSuccess() { events.push(['success']); },
        onLoginError(message) { events.push(['error', message]); },
        updateBtnText(text) { events.push(['progress', text]); },
        XMLHttpRequest: function() {
            xhr = this;
            this.responseText = '';
            this.status = 200;
            this.headers = {};
            this.open = function(...args) { this.openArgs = args; };
            this.setRequestHeader = function(name, value) { this.headers[name] = value; };
            this.send = function(body) { this.body = body; };
        },
    };
    vm.runInNewContext(script + '\ndoStreamLogin({token:"fixture-only-token"});', context);
    assert.deepEqual(xhr.openArgs, ['POST', '/fixture/oix_login', true]);
    assert.equal(xhr.body, 'token=fixture-only-token');
    assert(!xhr.openArgs[1].includes('token'), 'credentials must not enter request URL');
    assert.equal(xhr.headers['Content-Type'], 'application/x-www-form-urlencoded');
    return {
        xhr, events,
        feed(text) { xhr.responseText += text; xhr.onprogress(); },
        done() { xhr.onload(); },
    };
}
function test(name, fn) { fn(); count++; console.log('PASS ' + name); }
const progress = JSON.stringify({stage: 'loading', text: 'Loading managed nodes...'});
const done = JSON.stringify({stage: 'done', result: 200});
const failed = JSON.stringify({stage: 'error', result: 'Unable to load managed nodes'});
test('character-sized chunks preserve progress and terminal result', () => {
    const f = fixture();
    for (const char of progress + '\n' + ' '.repeat(4096) + done + '\n') f.feed(char);
    f.done(); assert.deepEqual(f.events, [['progress', 'Loading managed nodes...'], ['success']]);
});
test('every split position preserves a terminal JSON record', () => {
    for (let index=0; index <= done.length; index++) {
        const f=fixture(); f.feed(done.slice(0,index)); f.feed(done.slice(index)); f.done();
        assert.deepEqual(f.events, [['success']]);
    }
});
test('duplicate terminal records settle once', () => {
    const f=fixture(); f.feed(done+'\n'+done+'\n'+failed+'\n'); f.done(); f.xhr.onerror();
    assert.deepEqual(f.events, [['success']]);
});
test('error record prevents later false success', () => {
    const f=fixture(); f.feed(failed+'\n'+done+'\n'); f.done();
    assert.deepEqual(f.events, [['error', 'Unable to load managed nodes']]);
});
test('HTTP error cannot accept a success payload', () => {
    const f=fixture(); f.xhr.status=500; f.feed(done+'\n'); f.done();
    assert.equal(f.events.length,1); assert.equal(f.events[0][0],'error');
});
test('a stream without terminal confirmation reports failure', () => {
    const f=fixture(); f.feed(progress+'\n'); f.done();
    assert.equal(f.events.length,2); assert.equal(f.events[1][0],'error');
});
test('malformed terminal JSON reports failure', () => {
    const f=fixture(); f.feed('{"stage":"done","result":20'); f.done();
    assert.equal(f.events.length,1); assert.equal(f.events[0][0],'error');
});
test('transport failure settles once', () => {
    const f=fixture(); f.xhr.onerror(); f.done(); f.xhr.onerror();
    assert.equal(f.events.length,1); assert.equal(f.events[0][0],'error');
});
console.log(count+' offline login stream cases passed');
