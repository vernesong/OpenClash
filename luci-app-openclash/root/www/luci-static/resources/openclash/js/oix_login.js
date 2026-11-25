// Extracted from luasrc/view/openclash/oix_login.htm - edit this file, not the template.
// <%:Message%> markers and <%=...%> islands are compiled server-side by the "openclash/translate_js" controller action.

var OIX_URLS = {
    info: '<%=url("admin", "services", "openclash", "oix_info")%>',
    login: '<%=url("admin", "services", "openclash", "oix_login")%>',
    googleBegin: '<%=url("admin", "services", "openclash", "oix_google_begin")%>',
    logout: '<%=url("admin", "services", "openclash", "oix_logout")%>',
    save: '<%=url("admin", "services", "openclash", "oix_login_info_save")%>',
    checkin: '<%=url("admin", "services", "openclash", "oix_checkin")%>',
    webLink: '<%=url("admin", "services", "openclash", "oix_web_link")%>',
    deviceStatus: '<%=url("admin", "services", "openclash", "oix_device_status")%>'
};

var OixCloud = {
    loggedIn: window.ocOixBoot.loggedIn,
    activeTab: 'account',
    pollTimer: null,
    infoRequest: 0,
    accountSession: 0,
    googlePopup: null,
    googleChannel: null,
    googleTimer: null,
    origCheckinInterval: window.ocOixBoot.checkinInterval,
    origCheckinMultiple: window.ocOixBoot.checkinMultiple,

    init: function() {
        if (this.loggedIn) { this.loadAccountInfo(); this.startPolling(); }
    },

    switchTab: function(tab) {
        this.activeTab = tab;
        document.getElementById('oix-tab-account').classList.toggle('active', tab === 'account');
        document.getElementById('oix-tab-token').classList.toggle('active', tab === 'token');
        document.getElementById('oix-panel-account').classList.toggle('oc-hidden', tab !== 'account');
        document.getElementById('oix-panel-token').classList.toggle('oc-hidden', tab !== 'token');
        OixMsg.clearAll();
    },

    doLogin: function() {
        OixMsg.clearAll();
        // A Google sign-in finished later must not sign in a second time
        this.stopGoogleWait();
        var isToken = this.activeTab === 'token', data = {};
        if (isToken) {
            var token = document.getElementById('oix-token').value.trim();
            if (!token) { OixMsg.field('oix-token', '<%:Please enter a valid token%>'); return; }
            data.token = token;
        } else {
            var email = document.getElementById('oix-email').value.trim();
            var passwd = document.getElementById('oix-passwd').value;
            if (!email) { OixMsg.field('oix-email', '<%:Please enter email address%>'); return; }
            if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) { OixMsg.field('oix-email', '<%:Please enter a valid email address%>'); return; }
            if (!passwd) { OixMsg.field('oix-passwd', '<%:Please enter password%>'); return; }
            data.email = email; data.passwd = passwd;
        }
        this.streamLogin(data, document.querySelectorAll('#oix-login-section .oix-btn-primary'));
    },

    updateSubscription: function(button) {
        this.streamLogin({refresh: '1'}, [button]);
    },

    googleLogin: function() {
        OixMsg.clearAll();
        if (!window.BroadcastChannel) { OixMsg.show('<%:This browser does not support Google sign-in%>', 'error'); return; }
        this.stopGoogleWait();
        // Open the window inside the click so pop-up blockers allow it, then point it at the sign-in page
        // The opener is kept: without it this page could not close the window once it shows oixcloud.com
        var popup = this.googlePopup = window.open('', '_blank', 'width=520,height=680');
        if (!popup) { OixMsg.show('<%:Allow pop-up windows for this page to sign in with Google%>', 'error'); return; }
        var self = this;
        XHR.get(OIX_URLS.googleBegin, {origin: window.location.origin}, function(x, flow) {
            if (popup !== self.googlePopup) return;
            if (!x || x.status != 200 || !flow || !flow.url || !flow.state) {
                self.stopGoogleWait();
                OixMsg.show('<%:oixCloud Login Failed:%> ' + ((flow && flow.error) || '<%:Unable to start Google sign-in%>'), 'error');
                return;
            }
            // Closed while the router prepared the sign-in; some browsers throw on navigating it
            try {
                if (popup.closed) throw new Error('closed');
                popup.location.replace(flow.url);
            } catch (e) {
                self.stopGoogleWait();
                return;
            }
            // The callback page on this router relays the one-time code back over this channel
            self.googleChannel = new BroadcastChannel('openclash-oix-google');
            self.googleChannel.onmessage = function(event) {
                var data = event.data || {};
                if (data.state !== flow.state || typeof data.code !== 'string') return;
                self.stopGoogleWait();
                self.streamLogin({google_code: data.code, google_state: data.state}, document.querySelectorAll('#oix-login-section .oix-btn-google'));
            };
            self.googleTimer = setTimeout(function() {
                self.stopGoogleWait();
                OixMsg.show('<%:Google sign-in timed out, please try again%>', 'error');
            }, 600000);
            OixMsg.show('<%:Complete Google sign-in in the pop-up window%>', 'info', 0);
        });
    },

    stopGoogleWait: function() {
        if (this.googleChannel) { this.googleChannel.close(); this.googleChannel = null; }
        if (this.googlePopup) { this.googlePopup.close(); this.googlePopup = null; }
        clearTimeout(this.googleTimer);
        this.googleTimer = null;
    },

    streamLogin: function(data, btns, suggestAfterApproval) {
        var self = this;
        var session = this.accountSession;
        OixMsg.hide();
        btns.forEach(function(b){ ocSetBtnBusy(b, true, data.refresh ? '<%:Downloading config...%>' : '<%:Login...%>'); });

        var updateBtnText = function(text) {
            if (session !== self.accountSession) return;
            btns.forEach(function(b){
                var span = b.querySelector('span:not(.loading-spinner)');
                if (span) { span.textContent = text; }
            });
        };

        var onLoginSuccess = function(suggestNodeFilter, warning) {
            btns.forEach(function(b){ ocSetBtnBusy(b, false); });
            if (session !== self.accountSession) return;
            if (!data.refresh) session = ++self.accountSession;
            var info = warning || '<%:oixCloud configuration is active and a node passed the connectivity check%>';
            OixMsg.show(info, warning ? 'info' : 'success', 20000);
            self.loggedIn = true; self.showLoggedIn(); self.loadAccountInfo(); self.startPolling();
            if (suggestNodeFilter) {
                ocConfirm({
                    title: '<%:Node Filter%>',
                    body: '<%:Review the recommended nodes for your plan on the oixCloud website%>',
                    buttons: [
                        {label: '<%:Cancel%>', value: false},
                        {label: '<%:Node Filter%>', value: true, kind: 'primary'}
                    ]
                }).then(function(open) {
                    if (open && self.loggedIn && session === self.accountSession) self.openNodeFilter();
                });
            }
        };

        var onLoginError = function(msg, code) {
            btns.forEach(function(b){ ocSetBtnBusy(b, false); });
            if (session !== self.accountSession) return;
            if (code === 'session_changed') { window.location.reload(); return; }
            if (code === 'auth') {
                self.loggedIn = false; self.stopPolling(); self.showLoggedOut();
            }
            OixMsg.show((data.refresh ? '<%:Subscription update failed:%>' : '<%:oixCloud Login Failed:%>') + ' ' + msg, 'error');
            self.rebuildCredentials();
        };

        var doStreamLogin = function(loginData) {
            var xhr = new XMLHttpRequest();
            var url = OIX_URLS.login;
            var body = Object.keys(loginData).map(function(k){ return encodeURIComponent(k)+'='+encodeURIComponent(loginData[k]); }).join('&');
            xhr.open('POST', url, true);
            xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
            xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
            var lastIndex = 0, pending = '', finished = false;

            var parseLines = function(text, complete) {
                pending += text;
                var lines = pending.split('\n');
                pending = complete ? '' : lines.pop();
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (!line || finished) continue;
                    try {
                        var obj = JSON.parse(line);
                        if (obj.stage === 'done' && obj.result === 200) {
                            finished = true;
                            onLoginSuccess(suggestAfterApproval || obj.suggest_node_filter === true, obj.warning);
                        } else if (obj.stage === 'approval') {
                            finished = true;
                            btns.forEach(function(b){ ocSetBtnBusy(b, false); });
                            if (session !== self.accountSession) return;
                            if (!data.refresh) session = ++self.accountSession;
                            self.loggedIn = true;
                            self.showLoggedIn();
                            if (!data.refresh) { self.loadAccountInfo(); self.startPolling(); }
                            // once approved, carry on with the download this sign-in or update started
                            self.showDeviceApproval(obj.approval, function() {
                                self.streamLogin({refresh: '1', activate: data.activate || (data.refresh ? '0' : '1')}, btns,
                                    suggestAfterApproval || obj.suggest_node_filter === true);
                            });
                        } else if (obj.stage === 'error') {
                            finished = true;
                            onLoginError(obj.result || '<%:oixCloud Login Failed%>', obj.code);
                        } else if (obj.text) {
                            updateBtnText(obj.text);
                        }
                    } catch(e) {}
                }
            };

            xhr.onprogress = function() {
                if (xhr.status !== 200) return;
                var newText = xhr.responseText.substring(lastIndex);
                lastIndex = xhr.responseText.length;
                parseLines(newText);
            };
            xhr.onload = function() {
                if (finished) return;
                if (xhr.status !== 200) {
                    finished = true;
                    onLoginError('<%:Network request failed, please check your connection and try again%>');
                    return;
                }
                parseLines(xhr.responseText.substring(lastIndex), true);
                if (!finished) {
                    finished = true;
                    onLoginError('<%:Server response error, please try again later%>');
                }
            };
            xhr.onerror = function() {
                if (finished) return;
                finished = true;
                onLoginError('<%:Network request failed, please check your connection and try again%>');
            };
            xhr.send(body);
        };

        doStreamLogin(data);
    },

    // Shows the approval code until the router is approved on the website or with the
    // Telegram bot: enrolling again every 5 seconds answers the same request, so the
    // dialog closes by itself; it also shows a new code if the old one expired
    showDeviceApproval: function(approval, onApproved) {
        var self = this, session = this.accountSession;
        var box = document.createElement('div'), fields = {}, timer = null, closeDialog = null, stopped = false;
        var deadlineTimer, shown = '', pending = {}, operation = null;
        box.className = 'oix-approval';
        var addText = function(className, text) {
            var p = document.createElement('p');
            p.className = className;
            p.textContent = text;
            box.appendChild(p);
            return p;
        };
        var addRow = function(name, label, node) {
            var row = document.createElement('div'), title = document.createElement('span');
            row.className = 'oix-approval-row';
            title.className = 'oix-approval-label';
            title.textContent = label;
            node.className = 'oix-approval-value';
            row.appendChild(title);
            row.appendChild(node);
            box.appendChild(row);
            fields[name] = node;
            return row;
        };
        var form = document.createElement('div'), caption = document.createElement('label'), input = document.createElement('input');
        var send = document.createElement('button'), verify = document.createElement('button'), message = document.createElement('p');
        input.type = 'text';
        input.inputMode = 'numeric';
        input.autocomplete = 'one-time-code';
        caption.appendChild(document.createTextNode(''));
        caption.appendChild(input);
        form.appendChild(caption);
        send.type = verify.type = 'button';
        send.className = verify.className = 'cbi-button cbi-button-action';
        send.textContent = '<%:Send email code%>';
        verify.textContent = '<%:Approve this device%>';
        form.appendChild(send);
        form.appendChild(verify);
        message.setAttribute('role', 'status');
        form.appendChild(message);
        box.appendChild(form);
        var enableActions = function() {
            send.disabled = operation !== null;
            verify.disabled = operation !== null || !(pending.approval_method === 'email' ? /^[0-9]{8}$/ : /^[0-9]{6}$/).test(input.value);
        };
        input.oninput = enableActions;
        var submit = function(action) {
            if (stopped || operation || session !== self.accountSession || !self.loggedIn) return;
            var xhr = new XMLHttpRequest(), body = 'action=' + action + '&request_id=' + pending.request_id + '&fingerprint=' + pending.device_fingerprint;
            if (action === 'verify') {
                if (verify.disabled) return;
                body += '&code=' + encodeURIComponent(input.value);
            }
            operation = xhr;
            enableActions();
            message.textContent = '';
            xhr.open('POST', OIX_URLS.deviceStatus, true);
            xhr.timeout = 65000;
            xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
            xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
            xhr.onloadend = function() {
                if (stopped || operation !== xhr || session !== self.accountSession || !self.loggedIn) return;
                operation = null;
                enableActions();
                var reply;
                try { reply = JSON.parse(xhr.responseText); } catch(e) {}
                if (reply && reply.code === 'session_changed') { finish(false); window.location.reload(); return; }
                if (reply && reply.approval && reply.approval.approved === true) { finish(true); return; }
                if (action === 'email' && reply && reply.approval && reply.approval.approved === false) {
                    message.textContent = '<%:Check your account email for the code%>';
                } else {
                    message.textContent = reply && reply.error || '<%:Device verification failed%>';
                }
            };
            xhr.send(body);
        };
        send.onclick = function() { submit('email'); };
        verify.onclick = function() { submit('verify'); };
        var alternatives = document.createElement('details'), summary = document.createElement('summary');
        summary.textContent = '<%:Other approval methods%>';
        alternatives.appendChild(summary);
        box.appendChild(alternatives);
        alternatives.appendChild(addText('oix-approval-intro', '<%:Approve this router on the oixCloud website or with your linked Telegram bot, after checking that the fingerprint matches. This window closes by itself once approved%>'));
        var link = document.createElement('a');
        link.target = '_blank';
        link.rel = 'noopener noreferrer';
        var linkRow = addRow('url', '<%:Approval page%>', link);
        alternatives.appendChild(linkRow);
        alternatives.appendChild(addRow('code', '<%:Confirmation code%>', document.createElement('code')));
        alternatives.appendChild(addRow('telegram', '<%:Telegram command%>', document.createElement('code')));
        alternatives.appendChild(addRow('fingerprint', '<%:Device fingerprint%>', document.createElement('code')));
        var status = addText('oix-approval-status', '<%:Waiting for approval...%>');
        status.setAttribute('role', 'status');
        var retry = document.createElement('button');
        retry.type = 'button';
        retry.className = 'cbi-button cbi-button-action';
        retry.textContent = '<%:Request approval again%>';
        box.appendChild(retry);
        var bound = function(a) {
            return /^[0-9a-f]{32}$/.test(a.request_id || '') && /^[0-9a-f]{64}$/.test(a.device_fingerprint || '');
        };
        var render = function(a) {
            retry.style.display = a.denied ? '' : 'none';
            alternatives.style.display = a.denied ? 'none' : '';
            if (a.denied) {
                clearTimeout(timer);
                clearTimeout(deadlineTimer);
                var inflight = operation;
                operation = null;
                if (inflight) inflight.abort();
                pending = a;
                input.value = '';
                shown = '';
                form.style.display = 'none';
                status.textContent = bound(a) ? '<%:This device approval request was denied%>' : '<%:This request was denied. With an older server, wait for the original code to expire before requesting again%>';
                return;
            }
            var supported = (a.approval_method === 'email' || a.approval_method === 'totp') && bound(a);
            if (a.request_id !== pending.request_id || a.approval_method !== pending.approval_method || a.code !== shown) {
                var previous = operation;
                operation = null;
                if (previous) previous.abort();
                input.value = '';
                message.textContent = '';
                alternatives.open = !supported;
            }
            pending = a;
            form.style.display = supported ? '' : 'none';
            summary.style.display = supported ? '' : 'none';
            send.style.display = a.approval_method === 'email' ? '' : 'none';
            input.maxLength = a.approval_method === 'email' ? 8 : 6;
            caption.firstChild.nodeValue = a.approval_method === 'email' ? '<%:8-digit email code%>' : '<%:6-digit authenticator code%>';
            enableActions();
            // the core checks the page; link only to the website, as the other website links do
            var page = typeof a.url === 'string' && a.url.indexOf('https://oixcloud.com/') === 0 && !/[\s"'<>]/.test(a.url) ? a.url : '';
            link.href = page || '#';
            link.textContent = page;
            linkRow.style.display = page ? '' : 'none';
            fields.code.textContent = a.code || '';
            fields.telegram.textContent = a.telegram || '';
            fields.fingerprint.textContent = a.fingerprint || '';
            shown = a.code;
        };
        var finish = function(result) {
            stopped = true;
            if (operation) { operation.abort(); operation = null; }
            clearTimeout(timer);
            clearTimeout(deadlineTimer);
            if (closeDialog) closeDialog(result);
        };
        var startPolling = function() {
            deadlineTimer = setTimeout(function() { finish('timeout'); }, 600000);
            poll();
        };
        var reapply = function() {
            if (stopped || operation || session !== self.accountSession || !self.loggedIn || !pending.denied) return;
            var hasTarget = bound(pending), xhr = new XMLHttpRequest();
            operation = xhr;
            retry.disabled = true;
            xhr.open(hasTarget ? 'POST' : 'GET', OIX_URLS.deviceStatus, true);
            xhr.timeout = 65000;
            xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
            if (hasTarget) xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
            xhr.onloadend = function() {
                if (stopped || operation !== xhr || session !== self.accountSession || !self.loggedIn) return;
                operation = null;
                retry.disabled = false;
                var reply;
                try { reply = JSON.parse(xhr.responseText); } catch(e) {}
                if (reply && reply.code === 'session_changed') { finish(false); window.location.reload(); return; }
                var a = reply && reply.approval;
                if (a && a.approved === true) { finish(true); return; }
                if (a && a.denied) {
                    render(a);
                    if (!hasTarget && bound(a)) reapply();
                } else if (a && typeof a.code === 'string') {
                    render(a);
                    status.textContent = '<%:Waiting for approval...%>';
                    startPolling();
                } else {
                    status.textContent = reply && reply.error || '<%:Device verification failed%>';
                }
            };
            xhr.send(hasTarget ? 'action=retry&request_id=' + pending.request_id + '&fingerprint=' + pending.device_fingerprint : null);
        };
        retry.onclick = reapply;
        var poll = function() {
            timer = setTimeout(function() {
                if (stopped) return;
                if (session !== self.accountSession || !self.loggedIn) { finish(false); return; }
                XHR.get(OIX_URLS.deviceStatus, null, function(x, reply) {
                    if (stopped) return;
                    if (session !== self.accountSession) { finish(false); return; }
                    if (reply && reply.code === 'session_changed') { finish(false); window.location.reload(); return; }
                    if (reply && reply.code === 'auth') {
                        finish(false);
                        self.loggedIn = false; self.stopPolling(); self.showLoggedOut();
                        OixMsg.show(reply.error || '<%:Sign-in token is invalid or expired, please sign in again%>', 'error');
                        return;
                    }
                    if (reply && (reply.code === 'device_approval_denied' || (reply.approval && reply.approval.denied))) {
                        render(reply.approval || {denied: true});
                        return;
                    }
                    if (reply && (reply.code === 'device_limit' || reply.code === 'invalid_enrollment')) {
                        finish(false);
                        OixMsg.show(reply.error || '<%:Server response error, please try again later%>', 'error');
                        return;
                    }
                    var a = x && x.status == 200 && reply && reply.approval;
                    if (a && a.approved === true) { finish(true); return; }
                    if (a && typeof a.code === 'string') {
                        status.textContent = a.code !== shown ? '<%:A new confirmation code was issued%>' : '<%:Waiting for approval...%>';
                        render(a);
                    } else {
                        status.textContent = (reply && reply.error) || '<%:Unable to check the approval, retrying...%>';
                    }
                    poll();
                });
            }, 5000);
        };
        render(approval || {});
        ocConfirm({
            title: '<%:Approve this device%>',
            content: box,
            buttons: [{label: '<%:Cancel%>', value: false}],
            onOpen: function(close) { closeDialog = close; }
        }).then(function(result) {
            finish(result);
            if (session !== self.accountSession || !self.loggedIn) return;
            if (result === true) onApproved();
            else if (result === 'timeout') OixMsg.show('<%:Device approval timed out; update the subscription to get a new code%>', 'info', 0);
        });
        if (!pending.denied) startPolling();
    },

    doLogout: function() {
        var self = this;
        var session = this.accountSession;
        var btn = document.querySelector('#oix-logged-section .oix-btn-danger');
        if (btn) { btn.origHTML = btn.innerHTML; btn.disabled = true; var svg = btn.querySelector('svg'); btn.innerHTML = (svg ? svg.outerHTML : '') + ' <span><%:Logout...%></span>'; }
        this.stopGoogleWait();
        XHR.get(OIX_URLS.logout, null, function(x, status) {
            if (btn) { btn.disabled = false; btn.innerHTML = btn.origHTML; }
            if (session !== self.accountSession) return;
            if (status && status.code === 'session_changed') { window.location.reload(); return; }
            if (x && x.status == 200 && status && status.result == 200) {
                if (status.warning) { OixMsg.show(status.warning, 'error'); }
                else { OixMsg.show('<%:oixCloud Logout Successful%>', 'success', 2000); }
                self.loggedIn = false; self.stopPolling(); self.showLoggedOut();
            } else {
                var msg = (status && status.result) ? status.result : '<%:oixCloud Logout Failed%>';
                OixMsg.show('<%:oixCloud Logout Failed:%> ' + msg, 'error');
            }
        });
    },

    showLoggedIn: function() {
        document.getElementById('oix-login-section').classList.add('oc-hidden');
        document.getElementById('oix-logged-section').classList.remove('oc-hidden');
    },

    showLoggedOut: function() {
        ++this.accountSession;
        ++this.infoRequest;
        document.getElementById('oix-login-section').classList.remove('oc-hidden');
        document.getElementById('oix-logged-section').classList.add('oc-hidden');
        this.showNodeFilter(null);
        this.clearForm();
        this.switchTab('account');
        this.rebuildCredentials();
    },

    rebuildCredentials: function() {
        var self = this;
        setTimeout(function() {
            if (self.loggedIn) return;
            ['oix-email', 'oix-passwd'].forEach(function(id) {
                var oldEl = document.getElementById(id);
                if (oldEl) {
                    var newEl = oldEl.cloneNode(false);
                    newEl.removeAttribute('value');
                    newEl.value = '';
                    oldEl.parentNode.replaceChild(newEl, oldEl);
                }
            });
        }, 150);
    },

    clearForm: function() {
        document.getElementById('oix-email').value = '';
        document.getElementById('oix-passwd').value = '';
        document.getElementById('oix-token').value = '';
        document.getElementById('oix-checkin-enable').checked = false;
        document.getElementById('oix-checkin-interval').value = '1';
        document.getElementById('oix-checkin-multiple').value = '1';
    },

    loadAccountInfo: function() {
        var self = this;
        var request = ++this.infoRequest;
        XHR.get(OIX_URLS.info, null, function(x, status) {
            if (!self.loggedIn || request !== self.infoRequest) return;
            if (x && x.status == 200 && status && status.code === 'auth') {
                if (self.loggedIn) {
                    self.loggedIn = false; self.stopPolling(); self.showLoggedOut();
                    OixMsg.show(status.error || '<%:Sign-in token is invalid or expired, please sign in again%>', 'error');
                }
            } else if (x && x.status == 200 && status && status.result && typeof status.result === 'object') {
                document.getElementById('oix-cards').classList.remove('oc-hidden');
                self.renderAccountInfo(status.result);
                self.renderAnnouncement(status.result);
            } else {
                self.showNodeFilter(null);
                var cards = document.getElementById('oix-cards');
                if (cards) cards.classList.add('oc-hidden');
                var ann = document.getElementById('oix-announce');
                if (ann) ann.classList.add('oc-hidden');
            }
        });
    },

    renderAnnouncement: function(result) {
        var announcement = result.announcement;
        var content = window.OCMarkdown && OCMarkdown.announcementContent &&
            OCMarkdown.announcementContent(announcement);
        if (content) {
            var el = document.getElementById('oix-announce');
            var body = document.getElementById('oix-announce-body');
            var arrow = document.getElementById('oix-announce-arrow');
            if (el && body) {
                el.classList.remove('oc-hidden');
                body.textContent = '';
                if (announcement.date) {
                    var date = document.createElement('strong');
                    date.textContent = announcement.date;
                    body.appendChild(date);
                }
                body.appendChild(content);
                body.classList.remove('oix-collapsed');
                if (arrow) {
                    arrow.classList.add('oc-hidden');
                    arrow.style.transform = '';
                }
                var ref = document.getElementById('oix-cards');
                var measureContent = function() {
                    if (!ref || ref.offsetWidth === 0) return;
                    var cs = getComputedStyle(body);
                    var fontSize = parseFloat(cs.fontSize) || 12;
                    var maxH = fontSize * 5.6;
                    var expandable = body.scrollHeight > maxH + 4;
                    if (expandable && arrow && arrow.classList.contains('oc-hidden')) {
                        body.classList.add('oix-collapsed');
                    } else if (!expandable) {
                        body.classList.remove('oix-collapsed');
                        if (arrow) arrow.style.transform = '';
                    }
                    if (arrow) arrow.classList.toggle('oc-hidden', !expandable);
                };
                body.querySelectorAll('img').forEach(function(image) {
                    var onImageSettled = function() {
                        if (body.contains(image)) measureContent();
                    };
                    image.addEventListener('load', onImageSettled, { once: true });
                    image.addEventListener('error', onImageSettled, { once: true });
                });
                if (ref && ref.offsetWidth > 0) {
                    measureContent();
                } else {
                    var tabContainer = document.getElementById('container.openclash.config.oixcloud');
                    if (tabContainer && window.MutationObserver) {
                        var observer = new MutationObserver(function() {
                            if (ref && ref.offsetWidth > 0) {
                                observer.disconnect();
                                measureContent();
                            }
                        });
                        observer.observe(tabContainer, { attributes: true, attributeFilter: ['style', 'class'] });
                    }
                }
            }
        } else {
            var el2 = document.getElementById('oix-announce');
            if (el2) el2.classList.add('oc-hidden');
        }
    },

    renderAccountInfo: function(d) {
        document.getElementById('oix-header-plan').textContent = d.plan || '--';
        document.getElementById('oix-affmoney').textContent = d.aff_money || '--';
        document.getElementById('oix-plantime').textContent = d.plan_time || '--';
        document.getElementById('oix-money').textContent = d.money || '--';
        document.getElementById('oix-integral').textContent = d.integral || '--';
        document.getElementById('oix-traffic').textContent = d.traffic || '--';
        document.getElementById('oix-used').textContent = d.used || '--';
        document.getElementById('oix-unused').textContent = d.unused || '--';
        document.getElementById('oix-today-used').textContent = d.today_used || '--';
        this.showNodeFilter(d.plan_rank);
    },

    showNodeFilter: function(rank) {
        var hidden = !(this.loggedIn && Number(rank) > 0);
        ['oix-node-filter', 'oix-node-filter-help'].forEach(function(id) {
            var element = document.getElementById(id);
            if (element) element.classList.toggle('oc-hidden', hidden);
        });
    },

    openNodeFilter: function() {
        // Open the window inside the click so pop-up blockers allow it; the core gives the address
        var popup = window.open('', '_blank');
        if (!popup) { OixMsg.show('<%:Allow pop-up windows for this page%>', 'error'); return; }
        XHR.get(OIX_URLS.webLink, {page: 'node-filter'}, function(x, reply) {
            var address = x && x.status == 200 && reply && reply.url;
            if (!address || String(address).indexOf('https://oixcloud.com/') !== 0) {
                popup.close();
                OixMsg.show((reply && reply.error) || '<%:Unable to open the page%>', 'error');
                return;
            }
            // Closed while the router answered; some browsers throw on navigating it
            try {
                if (popup.closed) return;
                popup.opener = null;
                popup.location.replace(address);
            } catch (e) {
                popup.close();
            }
        });
    },

    toggleInfoPage: function() {
        var on = document.getElementById('oix-show-info-page').checked;
        XHR.get(OIX_URLS.save, {show_info_page: on?'1':'0'}, function(x, status) {
            if (x && x.status == 200 && status && status.status === 'success') { OixMsg.show('<%:Setting saved%>', 'success', 2000); }
            else {
                document.getElementById('oix-show-info-page').checked = !on;
                OixMsg.show('<%:Save failed%>', 'error');
            }
        });
    },

    startPolling: function() { this.stopPolling(); var s=this; this.pollTimer=setInterval(function(){s.loadAccountInfo();},600000); },
    stopPolling: function() { if(this.pollTimer){clearInterval(this.pollTimer);this.pollTimer=null;} },

    doCheckin: function() {
        var self = this;
        var session = this.accountSession;
        var btn = document.querySelector('#oix-logged-section .oix-btn-primary');
        if (btn) { btn.origHTML = btn.innerHTML; btn.disabled = true; var svg = btn.querySelector('svg'); btn.innerHTML = (svg ? svg.outerHTML : '') + ' <span><%:Checkin...%></span>'; }
        XHR.get(OIX_URLS.checkin, null, function(x, status) {
            if (btn) { btn.disabled = false; btn.innerHTML = btn.origHTML; }
            if (!self.loggedIn || session !== self.accountSession) return;
            if (status && status.code === 'auth') {
                self.loggedIn = false;
                self.stopPolling();
                self.showLoggedOut();
                OixMsg.show((status.result && status.result.msg) || '<%:Sign-in token is invalid or expired, please sign in again%>', 'error');
                return;
            }
            if (x && x.status == 200 && status && status.result && status.result.ret == 200) {
                OixMsg.show('<%:oixCloud Checkin Successful, Result:%> ' + (status.result.data && status.result.data.checkin || ''), 'success', 4000);
                self.loadAccountInfo();
            } else {
                var msg = (status && status.result && status.result.msg) ? status.result.msg : '';
                OixMsg.show(msg ? ('<%:Checkin Failed:%> ' + msg) : '<%:oixCloud Checkin Failed! Please Check And Try Again...%>', 'error');
            }
        });
    },

    toggleCheckin: function() {
        var on = document.getElementById('oix-checkin-enable').checked;
        XHR.get(OIX_URLS.save, {checkin: on?'1':'0'}, function(x, status) {
            if (x && x.status == 200 && status && status.status === 'success') { OixMsg.show('<%:Setting saved%>', 'success', 2000); }
            else {
                document.getElementById('oix-checkin-enable').checked = !on;
                OixMsg.show('<%:Failed to save checkin settings, please try again%>', 'error');
            }
        });
    },

    saveCheckin: function() {
        OixMsg.clearAll();
        var on = document.getElementById('oix-checkin-enable').checked;
        var interval = Number(document.getElementById('oix-checkin-interval').value);
        var multiple = Number(document.getElementById('oix-checkin-multiple').value);
        var valid = true;
        if (interval % 1 !== 0 || interval < 1 || interval > 720) { OixMsg.field('oix-checkin-interval', '<%:Checkin interval must be between 1 and 720%>'); OixMsg.show('<%:Checkin interval must be between 1 and 720%>', 'error'); valid = false; }
        if (multiple % 1 !== 0 || multiple < 1 || multiple > 100) { OixMsg.field('oix-checkin-multiple', '<%:Multiple Must Be a Positive Integer and No More Than 100%>'); OixMsg.show('<%:Multiple Must Be a Positive Integer and No More Than 100%>', 'error'); valid = false; }
        if (!valid) return;
        var newInterval = String(interval);
        var newMultiple = String(multiple);
        if (newInterval === this.origCheckinInterval && newMultiple === this.origCheckinMultiple) return;
        var self = this;
        XHR.get(OIX_URLS.save, {checkin: on?'1':'0', interval: newInterval, multiple: newMultiple}, function(x, status) {
            if (x && x.status == 200 && status && status.status === 'success') {
                self.origCheckinInterval = newInterval;
                self.origCheckinMultiple = newMultiple;
                OixMsg.show('<%:Checkin settings saved%>', 'success', 4000);
            }
            else { OixMsg.show('<%:Failed to save checkin settings, please try again%>', 'error'); }
        });
    },

    validateMultiple: function(inp) {
        if (!inp) return;
        var v = inp.value.trim();
        if (v === '') { OixMsg.field('oix-checkin-multiple', ''); return; }
        var n = parseInt(v, 10);
        if (isNaN(n) || n < 1 || n > 100 || String(n) !== v) {
            OixMsg.field('oix-checkin-multiple', '<%:Multiple Must Be a Positive Integer and No More Than 100%>');
            OixMsg.show('<%:Multiple Must Be a Positive Integer and No More Than 100%>', 'error');
        } else {
            OixMsg.field('oix-checkin-multiple', '');
        }
    },

    togglePwd: function(id) {
        var inp = document.getElementById(id);
        if (!inp) return;
        var isPwd = inp.type === 'password';
        inp.type = isPwd ? 'text' : 'password';
        var btn = inp.parentNode.querySelector('.oix-pwd-toggle');
        if (btn) {
            btn.title = isPwd ? btn.getAttribute('data-hide') : btn.getAttribute('data-show');
        }
        var icon = inp.parentNode.querySelector('svg');
        if (icon) {
            icon.innerHTML = isPwd
                ? '<use href="#oc-icon-eye"/>'
                : '<use href="#oc-icon-eye-off"/>';
        }
    },

    toggleAnnounce: function() {
        var body = document.getElementById('oix-announce-body');
        var arrow = document.getElementById('oix-announce-arrow');
        if (!body) return;
        if (body.classList.contains('oix-collapsed')) {
            body.classList.remove('oix-collapsed');
            if (arrow) arrow.style.transform = 'rotate(180deg)';
        } else {
            body.classList.add('oix-collapsed');
            if (arrow) arrow.style.transform = 'rotate(0deg)';
        }
    },

    openWebsite: function() {
        window.open('https://oixcloud.com/');
    }
};

var OixMsg = {
    timer: null,
    show: function(msg, level, timeout) {
        var bar = document.getElementById('oix-msg-bar');
        var icons = {
            success: '<svg width="15" height="15"><use href="#oc-icon-success"/></svg>',
            error:   '<svg width="15" height="15"><use href="#oc-icon-error"/></svg>',
            info:    '<svg width="15" height="15"><use href="#oc-icon-alert-circle"/></svg>'
        };
        bar.classList.remove('oc-hidden'); bar.innerHTML = (icons[level] || icons.info) + '<span></span>';
        bar.querySelector('span').textContent = msg;
        bar.className = 'oix-msg-bar oix-msg-' + (level || 'info');
        clearTimeout(this.timer);
        var t = (timeout !== undefined) ? timeout : (level === 'error' ? 6000 : 3000);
        if (t > 0) { var s=this; this.timer=setTimeout(function(){s.hide();},t); }
    },
    hide: function() { document.getElementById('oix-msg-bar').classList.add('oc-hidden'); },
    field: function(id, msg) {
        var hint = document.getElementById(id + '-hint'), inp = document.getElementById(id);
        if (hint) { hint.textContent = msg || ''; hint.className = msg ? 'oix-field-hint oix-field-error' : 'oix-field-hint oix-field-help'; }
        if (inp) {
            var isNum = id === 'oix-checkin-interval' || id === 'oix-checkin-multiple';
            var base = isNum ? 'oix-input-num' : 'oix-input';
            inp.className = msg ? (base + ' oix-input-err') : (base + ' oix-input-ok');
        }
    },
    clearAll: function() {
        this.hide();
        ['oix-email','oix-passwd','oix-token'].forEach(function(id) {
            var hint = document.getElementById(id + '-hint'), inp = document.getElementById(id);
            if (hint) { hint.textContent = ''; hint.className = 'oix-field-hint oix-field-help'; }
            if (inp) { inp.className = 'oix-input oix-input-ok'; }
        });
        ['oix-checkin-interval','oix-checkin-multiple'].forEach(function(id) {
            var hint = document.getElementById(id + '-hint'), inp = document.getElementById(id);
            if (hint) { hint.textContent = ''; hint.className = 'oix-field-hint oix-field-help'; }
            if (inp) { inp.className = 'oix-input-num oix-input-ok'; }
        });
    }
};

document.addEventListener('DOMContentLoaded', function() { OixCloud.init(); });
