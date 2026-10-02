// Extracted from luasrc/view/openclash/oix_login.htm - edit this file, not the template.
// <%:Message%> markers and <%=...%> islands are compiled server-side by the "openclash/translate_js" controller action.

var OIX_URLS = {
    info: '<%=url("admin", "services", "openclash", "oix_info")%>',
    login: '<%=url("admin", "services", "openclash", "oix_login")%>',
    logout: '<%=url("admin", "services", "openclash", "oix_logout")%>',
    save: '<%=url("admin", "services", "openclash", "oix_login_info_save")%>',
    checkin: '<%=url("admin", "services", "openclash", "oix_checkin")%>',
    params: '<%=url("admin", "services", "openclash", "oix_params_sync")%>',
    paramsGet: '<%=url("admin", "services", "openclash", "oix_params_get")%>'
};

var OixCloud = {
    loggedIn: window.ocOixBoot.loggedIn,
    activeTab: 'account',
    pollTimer: null,
    paramsRetry: 0,
    paramsMaxRetry: 30,
    paramsRetryTimer: null,
    origCheckinInterval: window.ocOixBoot.checkinInterval,
    origCheckinMultiple: window.ocOixBoot.checkinMultiple,
    origParams: window.ocOixBoot.params,

    init: function() {
        if (this.loggedIn) { this.loadAccountInfo(); this.startPolling(); this.fetchParams(); }
    },

    fetchParams: function() {
        var input = document.getElementById('oix-params');
        if (!input || input.value !== '') return;
        var self = this;
        var uciDefault = window.ocOixBoot.defaultParams;
        XHR.get(OIX_URLS.paramsGet, null, function(x, status) {
            if (x && x.status == 200 && status) {
                if (status.params) {
                    input.value = status.params;
                    self.paramsRetry = 0;
                    if (status.default_params) {
                        XHR.get(OIX_URLS.save, {default_params: status.default_params}, function() {});
                    }
                } else if (status.default_params) {
                    input.value = status.default_params;
                    input.placeholder = status.default_params;
                    self.paramsRetry = 0;
                } else if (uciDefault) {
                    input.value = uciDefault;
                    input.placeholder = uciDefault;
                    self.paramsRetry = 0;
                } else {
                    if (self.paramsRetry < self.paramsMaxRetry) {
                        self.paramsRetry++;
                        self.paramsRetryTimer = setTimeout(function() { self.fetchParams(); }, 5000);
                    } else {
                        self.paramsRetry = 0;
                    }
                }
            } else {
                if (self.paramsRetry < self.paramsMaxRetry) {
                    self.paramsRetry++;
                    self.paramsRetryTimer = setTimeout(function() { self.fetchParams(); }, 5000);
                } else if (uciDefault) {
                    input.value = uciDefault;
                    input.placeholder = uciDefault;
                }
            }
        });
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
            var passwd = document.getElementById('oix-passwd').value.trim();
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
            var info = '<%:oixCloud Login Successful%>, <%:Note: oixCloud need a specific core installed, OpenClash will auto download, After the core start, an oixCloud nodes provider will be added, which you can customize as needed%>';
            OixMsg.show(info, 'success', 20000);
            self.loggedIn = true; self.showLoggedIn(); self.loadAccountInfo(); self.startPolling(); self.fetchParams();
        };

        var onLoginError = function(msg) {
            btns.forEach(function(b){ ocSetBtnBusy(b, false); });
            OixMsg.show('<%:oixCloud Login Failed:%> ' + msg, 'error');
            self.rebuildCredentials();
        };

        var doStreamLogin = function(loginData) {
            var xhr = new XMLHttpRequest();
            var url = OIX_URLS.login;
            var sep = url.indexOf('?') >= 0 ? '&' : '?';
            if (loginData) {
                url += sep + Object.keys(loginData).map(function(k){ return encodeURIComponent(k)+'='+encodeURIComponent(loginData[k]); }).join('&');
            }
            xhr.open('GET', url, true);
            xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
            var lastIndex = 0;

            var parseLines = function(text) {
                var lines = text.split('\n');
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (!line) continue;
                    try {
                        var obj = JSON.parse(line);
                        if (obj.stage === 'done') {
                            onLoginSuccess();
                        } else if (obj.stage === 'error') {
                            onLoginError(obj.result || '<%:oixCloud Login Failed%>');
                        } else if (obj.text) {
                            updateBtnText(obj.text);
                        }
                    } catch(e) {}
                }
            };

            xhr.onprogress = function() {
                var newText = xhr.responseText.substring(lastIndex);
                lastIndex = xhr.responseText.length;
                parseLines(newText);
            };
            xhr.onload = function() {
                if (lastIndex < xhr.responseText.length) {
                    parseLines(xhr.responseText.substring(lastIndex));
                }
                if (xhr.status !== 200) {
                    onLoginError('<%:Network request failed, please check your connection and try again%>');
                } else if (xhr.responseText.indexOf('"stage":"done"') === -1 &&
                           xhr.responseText.indexOf('"stage":"error"') === -1) {
                    onLoginError('<%:Server response error, please try again later%>');
                }
            };
            xhr.onerror = function() {
                onLoginError('<%:Network request failed, please check your connection and try again%>');
            };
            xhr.send();
        };

        if (isToken) {
            doStreamLogin({token: data.token});
        } else {
            XHR.get(OIX_URLS.save, data, function(x, status) {
                if (!x || x.status != 200) { OixMsg.show('<%:Network request failed, please check your connection and try again%>', 'error'); btns.forEach(function(b){ocSetBtnBusy(b, false);}); return; }
                doStreamLogin(null);
            });
        }
    },

    doLogout: function() {
        var self = this;
        var btn = document.querySelector('#oix-logged-section .oix-btn-danger');
        if (btn) { btn.origHTML = btn.innerHTML; btn.disabled = true; var svg = btn.querySelector('svg'); btn.innerHTML = (svg ? svg.outerHTML : '') + ' <span><%:Logout...%></span>'; }
        XHR.get(OIX_URLS.logout, null, function(x, status) {
            if (btn) { btn.disabled = false; btn.innerHTML = btn.origHTML; }
            if (x && x.status == 200 && status.result == 200) {
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
        this.stopParamsRetry();
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
        document.getElementById('oix-params').value = '';
    },

    loadAccountInfo: function() {
        var self = this;
        XHR.get(OIX_URLS.info, null, function(x, status) {
            if (x && x.status == 200 && status.result && typeof status.result === 'object') {
                self.renderAccountInfo(status.result);
                self.renderAnnouncement(status.result);
            } else {
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
    },

    toggleInfoPage: function() {
        var on = document.getElementById('oix-show-info-page').checked;
        XHR.get(OIX_URLS.save, {show_info_page: on?'1':'0'}, function(x, status) {
            if (x && x.status == 200) { OixMsg.show('<%:Setting saved%>', 'success', 2000); }
        });
    },

    startPolling: function() { this.stopPolling(); var s=this; s.fetchParams(); this.pollTimer=setInterval(function(){s.loadAccountInfo();s.fetchParams();},600000); },
    stopPolling: function() { if(this.pollTimer){clearInterval(this.pollTimer);this.pollTimer=null;} },
    stopParamsRetry: function() { if(this.paramsRetryTimer){clearTimeout(this.paramsRetryTimer);this.paramsRetryTimer=null;} this.paramsRetry = 0; },

    doCheckin: function() {
        var self = this;
        var btn = document.querySelector('#oix-logged-section .oix-btn-primary');
        if (btn) { btn.origHTML = btn.innerHTML; btn.disabled = true; var svg = btn.querySelector('svg'); btn.innerHTML = (svg ? svg.outerHTML : '') + ' <span><%:Checkin...%></span>'; }
        XHR.get(OIX_URLS.checkin, null, function(x, status) {
            if (btn) { btn.disabled = false; btn.innerHTML = btn.origHTML; }
            if (x && x.status == 200 && status.result && status.result.ret == 200) {
                OixMsg.show('<%:oixCloud Checkin Successful, Result:%> ' + (status.result.data && status.result.data.checkin || ''), 'success', 4000);
                self.loadAccountInfo();
            } else {
                var msg = (status.result && status.result.msg) ? status.result.msg : '<%:oixCloud Checkin Failed! Please Check And Try Again...%>';
                OixMsg.show('<%:Checkin Failed:%> ' + msg, 'error');
            }
        });
    },

    toggleCheckin: function() {
        var on = document.getElementById('oix-checkin-enable').checked;
        var interval = document.getElementById('oix-checkin-interval').value || '1';
        var multiple = document.getElementById('oix-checkin-multiple').value || '1';
        XHR.get(OIX_URLS.save, {checkin: on?'1':'0', interval: interval, multiple: multiple}, function(x, status) {
            if (x && x.status == 200) { OixMsg.show('<%:Setting saved%>', 'success', 2000); }
        });
    },

    saveCheckin: function() {
        OixMsg.clearAll();
        var on = document.getElementById('oix-checkin-enable').checked;
        var interval = parseInt(document.getElementById('oix-checkin-interval').value, 10);
        var multiple = parseInt(document.getElementById('oix-checkin-multiple').value, 10);
        var valid = true;
        if (isNaN(interval) || interval < 1 || interval > 720) { OixMsg.field('oix-checkin-interval', '<%:Checkin interval must be between 1 and 720%>'); OixMsg.show('<%:Checkin interval must be between 1 and 720%>', 'error'); valid = false; }
        if (isNaN(multiple) || multiple < 1 || multiple > 100) { OixMsg.field('oix-checkin-multiple', '<%:Multiple Must Be a Positive Integer and No More Than 100%>'); OixMsg.show('<%:Multiple Must Be a Positive Integer and No More Than 100%>', 'error'); valid = false; }
        if (!valid) return;
        var newInterval = String(isNaN(interval) ? 1 : interval);
        var newMultiple = String(isNaN(multiple) ? 1 : multiple);
        if (newInterval === this.origCheckinInterval && newMultiple === this.origCheckinMultiple) return;
        var self = this;
        XHR.get(OIX_URLS.save, {checkin: on?'1':'0', interval: newInterval, multiple: newMultiple}, function(x, status) {
            if (x && x.status == 200) {
                self.origCheckinInterval = newInterval;
                self.origCheckinMultiple = newMultiple;
                OixMsg.show('<%:Checkin settings saved%>', 'success', 4000);
            }
            else { OixMsg.show('<%:Failed to save checkin settings, please try again%>', 'error'); }
        });
    },

    saveParams: function() {
        OixMsg.clearAll();
        var params = document.getElementById('oix-params').value.trim();
        if (params !== '' && !params.match(/^&[a-zA-Z][a-zA-Z0-9-]*(=[^&\s]*)?(&[a-zA-Z][a-zA-Z0-9-]*(=[^&\s]*)?)*$/)) {
            OixMsg.field('oix-params', '<%:Invalid params format, must start with & and use key=value pairs%>');
            OixMsg.show('<%:Invalid params format%>', 'error');
            return;
        }
        if (params.length > 8192) {
            OixMsg.field('oix-params', '<%:Params too long, max 8192 characters%>');
            OixMsg.show('<%:Params too long%>', 'error');
            return;
        }
        if (params === this.origParams) return;
        var self = this;
        XHR.get(OIX_URLS.params, {params: params}, function(x, status) {
            if (x && x.status == 200) {
                self.origParams = params;
                OixMsg.show('<%:Optional parameters saved%>', 'success', 4000);
            }
            else { OixMsg.show('<%:Failed to save optional parameters, please try again%>', 'error'); }
        });
    },

    validateParams: function(inp) {
        if (!inp) return;
        var v = inp.value.trim();
        if (v === '') { OixMsg.field('oix-params', ''); return; }
        if (!v.startsWith('&')) {
            OixMsg.field('oix-params', '<%:Must start with &%>');
            return;
        }
        if (/\s/.test(v)) {
            OixMsg.field('oix-params', '<%:Params must not contain spaces%>');
            return;
        }
        if (v.length > 8192) {
            OixMsg.field('oix-params', '<%:Params too long, max 8192 characters%>');
            return;
        }
        if (!v.match(/^&[a-zA-Z][a-zA-Z0-9-]*(=[^&\s]*)?(&[a-zA-Z][a-zA-Z0-9-]*(=[^&\s]*)?)*$/)) {
            OixMsg.field('oix-params', '<%:Invalid params format, must start with & and use key=value pairs%>');
            return;
        }
        OixMsg.field('oix-params', '');
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
                ? '<use href="#oc-icon-eye-off"/>'
                : '<use href="#oc-icon-eye"/>';
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
        bar.classList.remove('oc-hidden'); bar.innerHTML = (icons[level] || icons.info) + '<span>' + msg + '</span>';
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
            var isNum = id === 'oix-checkin-interval' || id === 'oix-checkin-multiple' || id === 'oix-params';
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
