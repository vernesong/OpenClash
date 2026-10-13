// Extracted from luasrc/view/openclash/oix_login.htm - edit this file, not the template.
// <%:Message%> markers and <%=...%> islands are compiled server-side by the "openclash/translate_js" controller action.

var OIX_URLS = {
    info: '<%=url("admin", "services", "openclash", "oix_info")%>',
    login: '<%=url("admin", "services", "openclash", "oix_login")%>',
    logout: '<%=url("admin", "services", "openclash", "oix_logout")%>',
    save: '<%=url("admin", "services", "openclash", "oix_login_info_save")%>',
    checkin: '<%=url("admin", "services", "openclash", "oix_checkin")%>',
    nodeFilter: 'https://oixcloud.com/user/node_filter?client=OpenClash'
};

var OixCloud = {
    loggedIn: window.ocOixBoot.loggedIn,
    activeTab: 'account',
    pollTimer: null,
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
        var self = this, btns = document.querySelectorAll('#oix-login-section .oix-btn-primary');
        btns.forEach(function(b){ ocSetBtnBusy(b, true, '<%:Login...%>'); });

        var updateBtnText = function(text) {
            btns.forEach(function(b){
                var span = b.querySelector('span:not(.loading-spinner)');
                if (span) { span.textContent = text; }
            });
        };

        var onLoginSuccess = function() {
            btns.forEach(function(b){ ocSetBtnBusy(b, false); });
            var info = '<%:oixCloud configuration and nodes are ready%>';
            OixMsg.show(info, 'success', 20000);
            self.loggedIn = true; self.showLoggedIn(); self.loadAccountInfo(); self.startPolling();
        };

        var onLoginError = function(msg) {
            btns.forEach(function(b){ ocSetBtnBusy(b, false); });
            OixMsg.show('<%:oixCloud Login Failed:%> ' + msg, 'error');
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
                            onLoginSuccess();
                        } else if (obj.stage === 'error') {
                            finished = true;
                            onLoginError(obj.result || '<%:oixCloud Login Failed%>');
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

    doLogout: function() {
        var self = this;
        var btn = document.querySelector('#oix-logged-section .oix-btn-danger');
        if (btn) { btn.origHTML = btn.innerHTML; btn.disabled = true; var svg = btn.querySelector('svg'); btn.innerHTML = (svg ? svg.outerHTML : '') + ' <span><%:Logout...%></span>'; }
        XHR.get(OIX_URLS.logout, null, function(x, status) {
            if (btn) { btn.disabled = false; btn.innerHTML = btn.origHTML; }
            if (x && x.status == 200 && status && status.result == 200) {
                OixMsg.show('<%:oixCloud Logout Successful%>', 'success', 2000);
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
        XHR.get(OIX_URLS.info, null, function(x, status) {
            if (x && x.status == 200 && status && status.result && typeof status.result === 'object') {
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
        if (result.announcement && result.announcement.content) {
            var el = document.getElementById('oix-announce');
            var body = document.getElementById('oix-announce-body');
            var arrow = document.getElementById('oix-announce-arrow');
            if (el && body) {
                el.classList.remove('oc-hidden');
                body.innerHTML = '<strong>' + (result.announcement.date || '') + ': </strong>' + result.announcement.content;
                body.classList.remove('oix-collapsed');
                var ref = document.getElementById('oix-cards');
                var measureContent = function() {
                    if (!ref || ref.offsetWidth === 0) return;
                    var cs = getComputedStyle(body);
                    var fontSize = parseFloat(cs.fontSize) || 12;
                    var maxH = fontSize * 5.6;
                    var measure = document.createElement('div');
                    measure.style.font = cs.font;
                    measure.style.lineHeight = cs.lineHeight;
                    measure.style.wordBreak = cs.wordBreak;
                    measure.style.width = ref.offsetWidth + 'px';
                    measure.style.position = 'absolute';
                    measure.style.visibility = 'hidden';
                    measure.innerHTML = (result.announcement.date || '') + ': ' + result.announcement.content;
                    ref.parentElement.appendChild(measure);
                    var fullH = measure.scrollHeight;
                    ref.parentElement.removeChild(measure);
                    if (fullH > maxH + 4) {
                        body.classList.add('oix-collapsed');
                        if (arrow) arrow.classList.remove('oc-hidden');
                    } else {
                        if (arrow) arrow.classList.add('oc-hidden');
                    }
                };
                if (ref && ref.offsetWidth > 0) {
                    measureContent();
                } else {
                    var tabContainer = document.getElementById('tab.openclash.config.oixcloud');
                    var observer = new MutationObserver(function() {
                        if (ref && ref.offsetWidth > 0) {
                            observer.disconnect();
                            measureContent();
                        }
                    });
                    observer.observe(tabContainer, { attributes: true, attributeFilter: ['style', 'class'] });
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
        var btn = document.getElementById('oix-node-filter');
        if (btn) btn.classList.toggle('oc-hidden', !(this.loggedIn && Number(rank) >= 20));
    },

    openNodeFilter: function() {
        window.open(OIX_URLS.nodeFilter, '_blank', 'noopener');
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
        var btn = document.querySelector('#oix-logged-section .oix-btn-primary');
        if (btn) { btn.origHTML = btn.innerHTML; btn.disabled = true; var svg = btn.querySelector('svg'); btn.innerHTML = (svg ? svg.outerHTML : '') + ' <span><%:Checkin...%></span>'; }
        XHR.get(OIX_URLS.checkin, null, function(x, status) {
            if (btn) { btn.disabled = false; btn.innerHTML = btn.origHTML; }
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
            btn.title = isPwd ? btn.getAttribute('data-show') : btn.getAttribute('data-hide');
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
