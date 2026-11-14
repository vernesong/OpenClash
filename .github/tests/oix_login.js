// Run from the repository root with Node.js; no browser or router is required.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('luci-app-openclash/root/www/luci-static/resources/openclash/js/oix_login.js', 'utf8');
let cases = 0;
function fixture(reply) {
    const messages = [];
    const context = {
        window: {ocOixBoot: {loggedIn: true}},
        document: {addEventListener() {}, getElementById() { return {classList: {add() {}, remove() {}}}; }},
        ocSetBtnBusy() {},
        XMLHttpRequest: function() {
            this.open = () => {};
            this.setRequestHeader = () => {};
            this.send = body => {
                context.sent = body;
                this.status = 200;
                this.responseText = JSON.stringify(reply) + '\n';
                this.onload();
            };
        },
        XHR: {get(url, data, callback) { callback({status: 200}, reply); }}
    };
    vm.createContext(context);
    vm.runInContext(source, context);
    context.OixMsg = {hide() {}, show(...args) {messages.push(args);}};
    const app = context.OixCloud;
    app.showLoggedIn = () => {};
    app.showLoggedOut = () => {};
    app.stopPolling = () => {context.stopped = true;};
    app.startPolling = () => {};
    app.rebuildCredentials = () => {};
    app.showNodeFilter = () => {};
    return {context, app, messages};
}
for (const reply of [
    {stage: 'done', result: 200, warning: 'Signed in, but subscription update failed'},
    {stage: 'done', result: 200},
    {stage: 'error', code: 'auth', result: 'expired'},
    {stage: 'error', result: 'network failure'}
]) {
    const {context, app, messages} = fixture(reply);
    app.loadAccountInfo = () => {};
    app.updateSubscription({});
    assert.equal(context.sent, 'refresh=1', 'retry must reuse the stored session');
    assert.equal(app.loggedIn, reply.code !== 'auth');
    if (reply.warning) {
        assert.equal(messages[0][0], reply.warning);
        assert.equal(messages[0][1], 'info');
    }
    if (reply.code === 'auth') assert.equal(context.stopped, true);
    cases++;
}
for (const reply of [{result: 'error', code: 'auth', error: 'expired'}, {result: 'error'}]) {
    const {context, app, messages} = fixture(reply);
    app.loadAccountInfo();
    assert.equal(app.loggedIn, reply.code !== 'auth');
    if (reply.code === 'auth') {
        assert.equal(context.stopped, true);
        assert.equal(messages[0][0], 'expired');
    }
    cases++;
}
console.log(`OpenClash login UI: ${cases} behavior cases passed`);
