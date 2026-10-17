// Extracted from luasrc/view/openclash/status.htm - edit this file, not the template.
// <%:Message%> markers and <%=...%> islands are compiled server-side by the "openclash/translate_js" controller action.

// Plugin version / LuCI language come from common.js (it parses its own script URL)
var ocPluginVer = window.ocPluginVer || '';
var ocLang = window.ocLang || '';

    window.ocChartUrl = '/luci-static/resources/openclash/js/chart.umd.min.js?v=' + ocPluginVer;
    // Companion bundles are lazy-loaded on first use (see editConfig/openGuide/etc below).
    function ocJsUrl(name) { return '/cgi-bin/luci/admin/services/openclash/translate_js?f=' + name.replace(/\.js$/, '') + '&v=' + (window.ocPluginVer || '') + '&l=' + ocLang; }
    function ocCssUrl(name) { return '/luci-static/resources/openclash/css/' + name + '?v=' + (window.ocPluginVer || ''); }

    // Operation failures surface as non-blocking toasts instead of ocAlert() on the client page
    function ocAlert(message) {
        if (window.ocToast) ocToast(String(message), 'error');
    }

    function ocFormatOneDecimal(val) {
        var num = Number(val);
        if (!isFinite(num)) num = 0;
        var text = num.toFixed(1);
        return (text === '0.0' || text === '-0.0') ? '0' : text;
    }

    function ocFormatUnixTime(unixTimestamp) {
        if (!unixTimestamp || unixTimestamp === 0) {
            return '--';
        }
        try {
            var date = new Date(unixTimestamp * 1000);
            var year = date.getFullYear();
            var month = String(date.getMonth() + 1).padStart(2, '0');
            var day = String(date.getDate()).padStart(2, '0');
            var hour = String(date.getHours()).padStart(2, '0');
            var minute = String(date.getMinutes()).padStart(2, '0');
            var second = String(date.getSeconds()).padStart(2, '0');
            return year + '-' + month + '-' + day + ' ' + hour + ':' + minute + ':' + second;
        } catch (e) {
            return '--';
        }
    }

    function ocFormatBytes(bytes) {
        if (bytes == null || bytes === 0) return '0 B';
        var sizes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
        var i = Math.floor(Math.log(bytes) / Math.log(1024));
        if (i >= sizes.length) i = sizes.length - 1;
        return (i === 0 ? bytes : (bytes / Math.pow(1024, i)).toFixed(1)) + ' ' + sizes[i];
    }

    function ocFormatFileSize(bytes) {
        if (!bytes || bytes === 0) return '--';
        return ocFormatBytes(bytes);
    }

    function ocDebounce(fn, delay) {
        var timer = null;
        return function(btn) {
            var key = btn.id || btn.value;
            if (timer) clearTimeout(timer);
            btn.disabled = true;
            timer = setTimeout(function() {
                try { fn(btn); } finally { timer = null; }
            }, delay || 300);
            return false;
        };
    }

    var DOMCache = {
        clash: document.getElementById('_clash'),
        dns_fakeip: document.getElementById('dns_fakeip'),
        dns_redirhost: document.getElementById('dns_redirhost'),
        web: document.getElementById('_web'),
        webo: document.getElementById('_webo'),
        webm: document.getElementById('_webm'),
        webz: document.getElementById('_webz'),
        web_external: document.getElementById('_web_external'),
        daip: document.getElementById('_daip'),
        oclog: document.getElementById('_oclog'),
        close_all_connection: document.getElementById('_close_all_connection_btn'),
        reload_firewall: document.getElementById('_reload_firewall_btn'),
        one_key_update: document.getElementById('_one_key_update_btn'),
        flush_dns_cache: document.getElementById('_flush_dns_cache_btn'),
        radio_mode: document.getElementById('radio-mode'),
        radio: document.getElementsByName("radios"),
        radio_ru: document.getElementsByName("radios-ru"),
        radio_run_normal: document.getElementById("run_normal"),
        copy_secret: document.getElementById('copy_secret'),
        copy_address: document.getElementById('copy_address'),
        copy_mix_address: document.getElementById('copy_mix_address'),
        copy_mix_secret: document.getElementById('copy_mix_secret'),
        copy_pac_config: document.getElementById('copy_pac_config'),
        mix_proxy: document.getElementById('_mix_proxy'),
        dns_setting_sniffer: document.getElementById('dns-setting-sniffer'),
        dns_setting_respect: document.getElementById('dns-setting-respect'),
        meta_sniffer_on: document.getElementById('meta_sniffer_on'),
        meta_sniffer_off: document.getElementById('meta_sniffer_off'),
        respect_rules_on: document.getElementById('respect_rules_on'),
        respect_rules_off: document.getElementById('respect_rules_off'),
        oc_setting_oversea: document.getElementById('oc-setting-oversea'),
        oc_setting_oversea_0: document.getElementById('oc_setting_oversea_0'),
        oc_setting_oversea_1: document.getElementById('oc_setting_oversea_1'),
        oc_setting_oversea_2: document.getElementById('oc_setting_oversea_2'),
        stream_unlock_setting: document.getElementById('stream-unlock-setting'),
        stream_unlock_on: document.getElementById('stream_unlock_on'),
        stream_unlock_off: document.getElementById('stream_unlock_off'),
        core_version_display: document.getElementById('core-version-display'),
        core_version_text: document.getElementById('core-version-text'),
        plugin_version_display: document.getElementById('plugin-version-display'),
        plugin_version_text: document.getElementById('plugin-version-text')
    };

    var getDashboardBaseURL = ocGetDashboardBaseURL;
    var getDashboardWebSocketOrigin = ocGetDashboardWebSocketOrigin;
    var buildDashboardURL = ocBuildDashboardURL;
    var buildExternalDashboardURL = ocBuildExternalDashboardURL;
    var bytesToSize = ocFormatBytes;
    var debounceButton = ocDebounce;

    function ocStatHtml(text, color) {
        color = color || 'var(--success-color)';
        var s = String(text);
        var m = s.match(/^([\d.]+)\s*(.*)$/);
        var num = m ? m[1] : s;
        var unit = m ? m[2] : '';
        return '<span class="stat-num" style="color:' + color + '">' + num + '</span>'
            + (unit ? '<span class="stat-unit">' + unit + '</span>' : '');
    }

    var DarkModeDetector = {
        init: function() {
            this.applyDarkMode();
        },

        applyDarkMode: function() {
            var sunIcon = document.getElementById('sun-icon');
            var moonIcon = document.getElementById('moon-icon');
            var autoIcon = document.getElementById('auto-icon');
            if (sunIcon && moonIcon && autoIcon) {
                var theme = localStorage.getItem('oc-theme') || 'auto';
                sunIcon.classList.add('oc-hidden');
                moonIcon.classList.add('oc-hidden');
                autoIcon.classList.add('oc-hidden');

                if (theme === 'light') {
                    sunIcon.classList.remove('oc-hidden');
                } else if (theme === 'dark') {
                    moonIcon.classList.remove('oc-hidden');
                } else {
                    autoIcon.classList.remove('oc-hidden');
                }
            }
        }
    };

    var StateManager = {
        current_status: {},
        cached_proxy_info: null,
        last_request_time: {},
        request_cache: {},
        cache_ttl: 5000,
        pending_requests: new Map(),

        cachedXHR: function(url, params, callback, force) {
            var cacheKey = params ? url + JSON.stringify(params) : url;
            var now = Date.now();

            if (this.pending_requests.has(cacheKey)) {
                this.pending_requests.get(cacheKey).push(callback);
                return;
            }

            var cacheExists = this.request_cache.hasOwnProperty(cacheKey);
            var isCacheStale = cacheExists && (now - this.last_request_time[cacheKey] >= this.cache_ttl);

            if (!force && cacheExists && !isCacheStale) {
                setTimeout(function() {
                    callback({ status: 200, fromCache: true }, StateManager.request_cache[cacheKey]);
                }, 0);
                return;
            }

            if (!force && cacheExists && isCacheStale) {
                setTimeout(function() {
                    callback({ status: 200, fromCache: true, stale: true }, StateManager.request_cache[cacheKey]);
                }, 0);
                this.refreshCacheSilent(url, params, cacheKey);
                return;
            }

            this.pending_requests.set(cacheKey, [callback]);
            var self = this;

            XHR.get(url, params, function(x, data) {
                var callbacks = self.pending_requests.get(cacheKey) || [];
                self.pending_requests.delete(cacheKey);

                if (x && x.status == 200 && data) {
                    self.request_cache[cacheKey] = data;
                    self.last_request_time[cacheKey] = Date.now();
                }

                callbacks.forEach(function(cb) {
                    try {
                        cb(x, data);
                    } catch (e) {
                        console.warn('StateManager: XHR callback error for ' + cacheKey, e);
                    }
                });
            });
        },

        cachedXHRGet: function(url, callback, force) {
            this.cachedXHR(url, null, callback, force);
        },

        cachedXHRGetWithParams: function(url, params, callback, force) {
            this.cachedXHR(url, params, callback, force);
        },

        clearCache: function(url, params) {
            var cacheKey = params ? url + JSON.stringify(params) : url;
            delete this.request_cache[cacheKey];
            delete this.last_request_time[cacheKey];
        },

        clearAllCache: function() {
            this.request_cache = {};
            this.last_request_time = {};
        },

        hasCache: function(url, params) {
            var cacheKey = params ? url + JSON.stringify(params) : url;
            return !!this.request_cache[cacheKey];
        },

        getCacheAge: function(url, params) {
            var cacheKey = params ? url + JSON.stringify(params) : url;
            if (!this.last_request_time[cacheKey]) {
                return null;
            }
            return Date.now() - this.last_request_time[cacheKey];
        },

        setCacheTTL: function(ttl) {
            this.cache_ttl = ttl;
        },

        batchUpdateDOM: function(updates) {
            for (var i = 0; i < updates.length; i++) {
                var update = updates[i];
                if (update.element && update.content !== undefined) {
                    if (update.element.innerHTML !== update.content) {
                        update.element.innerHTML = update.content;
                    }
                }
            }
        },

        refreshCacheSilent: function(url, params, cacheKey) {
            var self = this;
            XHR.get(url, params, function(x, data) {
                if (x && x.status == 200 && data) {
                    self.request_cache[cacheKey] = data;
                    self.last_request_time[cacheKey] = Date.now();
                }
            });
        },

        cachedXHRGetWithRetry: function(url, params, callback, force, maxRetries) {
            maxRetries = maxRetries || 3;
            var retryCount = 0;
            var self = this;

            function attemptRequest() {
                self.cachedXHRGetWithParams(url, params, function(x, data) {
                    if (x && x.status == 200) {
                        callback(x, data);
                    } else if (retryCount < maxRetries) {
                        retryCount++;
                        setTimeout(attemptRequest, 1000 * retryCount);
                    } else {
                        callback(x, data);
                    }
                }, force && retryCount === 0);
            }

            attemptRequest();
        }
    };

    var WSManager = {
        connections: {},
        connectionStates: {
            CONNECTING: 0,
            CONNECTED: 1,
            DISCONNECTED: 2,
            ERROR: 3
        },
        reconnectDelay: 5000,
        heartbeatInterval: 30000,
        heartbeatTimers: {},
        wsConnect: false,
        allowedCloseCodes: [1000, 1001, 1005, 1006],

        isSupported: function() {
            return typeof window.WebSocket !== "undefined";
        },

        createConnection: function(type, url, messageHandler, options) {
            options = options || {};

            this.closeConnection(type);

            if (!this.isSupported()) {
                this.enableFallbackMode();
                return null;
            }

            try {
                var ws = new window.WebSocket(url);

                this.connections[type] = {
                    socket: ws,
                    url: url,
                    messageHandler: messageHandler,
                    state: this.connectionStates.CONNECTING,
                    lastActivity: Date.now(),
                    options: options
                };

                if (ws.addEventListener) {
                    ws.addEventListener('open', this.handleOpen.bind(this, type));
                    ws.addEventListener('message', this.handleMessage.bind(this, type));
                    ws.addEventListener('error', this.handleError.bind(this, type));
                    ws.addEventListener('close', this.handleClose.bind(this, type));
                } else {
                    ws.onopen = this.handleOpen.bind(this, type);
                    ws.onmessage = this.handleMessage.bind(this, type);
                    ws.onerror = this.handleError.bind(this, type);
                    ws.onclose = this.handleClose.bind(this, type);
                }

                return ws;
            } catch (error) {
                this.handleConnectionError(type, error);
                return null;
            }
        },

        startHeartbeat: function(type) {
            var self = this;
            this.stopHeartbeat(type);

            this.heartbeatTimers[type] = setInterval(function() {
                var connection = self.connections[type];
                if (connection && connection.socket && connection.state === self.connectionStates.CONNECTED) {
                    var timeSinceLastActivity = Date.now() - connection.lastActivity;
                    if (timeSinceLastActivity > self.heartbeatInterval * 3) {
                        self.reconnectConnection(type);
                    }
                }
            }, this.heartbeatInterval);

            if (!this.visibilityHandlerAdded) {
                document.addEventListener('visibilitychange', function() {
                    if (document.hidden) {
                        for (var t in self.heartbeatTimers) {
                            self.stopHeartbeat(t);
                        }
                    } else {
                        for (var t in self.connections) {
                            if (self.connections[t] && self.connections[t].state === self.connectionStates.CONNECTED) {
                                self.startHeartbeat(t);
                            }
                        }
                    }
                });
                this.visibilityHandlerAdded = true;
            }
        },

        stopHeartbeat: function(type) {
            if (this.heartbeatTimers[type]) {
                clearInterval(this.heartbeatTimers[type]);
                delete this.heartbeatTimers[type];
            }
        },

        reconnectConnection: function(type) {
            var connection = this.connections[type];
            if (connection) {
                this.createConnection(type, connection.url, connection.messageHandler, connection.options);
            }
        },

        closeConnection: function(type) {
            var connection = this.connections[type];
            if (this.pendingReconnect && this.pendingReconnect[type]) {
                clearTimeout(this.pendingReconnect[type]);
                delete this.pendingReconnect[type];
            }
            if (connection && connection.socket) {
                this.stopHeartbeat(type);
                try {
                    connection.socket.close(1000, 'Normal closure');
                } catch (error) {}
                delete this.connections[type];
            }
        },

        closeAll: function() {
            var types = Object.keys(this.connections);
            for (var i = 0; i < types.length; i++) {
                this.closeConnection(types[i]);
            }
            this.wsConnect = false;
        },

        handleMessage: function(type, event) {
            var connection = this.connections[type];
            if (connection && connection.messageHandler) {
                connection.lastActivity = Date.now();
                try {
                    var data;
                    try {
                        data = JSON.parse(event.data);
                    } catch (e) {
                        data = event.data;
                    }
                    connection.messageHandler({ data: data, raw: event.data, event: event });
                } catch (error) {
                    console.warn('WSManager: message handler error for type=' + type, error);
                }
            }
        },

        handleOpen: function(type, event) {
            var connection = this.connections[type];
            if (connection) {
                connection.state = this.connectionStates.CONNECTED;
                connection.lastActivity = Date.now();
            }
            this.startHeartbeat(type);

            if (!this.wsConnect) {
                var connectedCount = 0;
                for (var t in this.connections) {
                    if (this.connections[t].state === this.connectionStates.CONNECTED) {
                        connectedCount++;
                    }
                }
                if (connectedCount >= 1) {
                    this.wsConnect = true;
                    if (NetworkStatsManager.isEnabled) {
                        NetworkStatsManager.stop();
                    }
                }
            }
        },

        handleError: function(type, error) {
            var connection = this.connections[type];
            if (connection) {
                connection.state = this.connectionStates.ERROR;
            }
            this.stopHeartbeat(type);
            this.scheduleReconnect(type);
            this.enableFallbackMode();
        },

        handleClose: function(type, event) {
            var connection = this.connections[type];
            if (connection && connection.socket === event.target) {
                connection.state = this.connectionStates.DISCONNECTED;
                this.stopHeartbeat(type);

                if (typeof StatsChart !== 'undefined' && StatsChart.resetToZero) {
                    StatsChart.resetToZero();
                }

                if (this.allowedCloseCodes.indexOf(event.code) === -1) {
                    this.scheduleReconnect(type);
                }
            }
        },

        handleConnectionError: function(type, error) {
            var connection = this.connections[type];
            if (connection) {
                connection.state = this.connectionStates.ERROR;
            }
            this.scheduleReconnect(type);
            this.enableFallbackMode();
        },

        scheduleReconnect: function(type) {
            var self = this;
            var connection = this.connections[type];

            if (!connection) {
                this.enableFallbackMode();
                return;
            }

            var url = connection.url;
            var handler = connection.messageHandler;
            var options = connection.options;

            this.pendingReconnect = this.pendingReconnect || {};
            this.pendingReconnect[type] = setTimeout(function() {
                delete self.pendingReconnect[type];
                self.createConnection(type, url, handler, options);
            }, this.reconnectDelay);
        },

        enableFallbackMode: function() {
            this.wsConnect = false;
            var types = Object.keys(this.connections);
            for (var i = 0; i < types.length; i++) {
                var connection = this.connections[types[i]];
                if (connection && connection.socket) {
                    this.stopHeartbeat(types[i]);
                    try {
                        connection.socket.close(1000, 'Normal closure');
                    } catch (error) {}
                    delete this.connections[types[i]];
                }
            }
            NetworkStatsManager.resetStats();
            if (typeof StatsChart !== 'undefined' && StatsChart.resetToZero) StatsChart.resetToZero();
            if (typeof StatsWSMeta !== 'undefined') StatsWSMeta.protocol = null;
            if (typeof syncDataSource === 'function') syncDataSource();
        },

        getConnectionState: function(type) {
            var connection = this.connections[type];
            return connection ? connection.state : this.connectionStates.DISCONNECTED;
        },

        getAllConnectionStates: function() {
            var states = {};
            for (var type in this.connections) {
                states[type] = this.getConnectionState(type);
            }
            return states;
        },

        hasActiveConnections: function() {
            for (var type in this.connections) {
                if (this.getConnectionState(type) === this.connectionStates.CONNECTED) {
                    return true;
                }
            }
            return false;
        }
    };

    var ConfigFileManager = {
        configList: [],
        currentConfig: '',
        currentConfigIndex: -1,
        selectElement: null,
        rawCurrentConfig: '',
        configListLoaded: false,

        init: function() {
            this.selectElement = document.getElementById('config_file_select');
            if (this.selectElement) {
                this.loadConfigFileList(true);
                this.setupEventListeners();
            }
        },

        setupEventListeners: function() {
            if (this.selectElement) {
                this.selectElement.addEventListener('change', this.onConfigChange.bind(this));
            }
        },

        loadConfigFileList: function(force) {
            this.updateSelectOptions([{value: '', text: '<%:Collecting data...%>', disabled: true}]);

            var params = {};
            var cached = localStorage.getItem('oc_config_fp');
            if (cached) {
                try {
                    var c = JSON.parse(cached);
                    if (c && c.fp) {
                        var ageCache = localStorage.getItem('oc_config_age');
                        if (ageCache) {
                            try {
                                var a = JSON.parse(ageCache);
                                if (a && a.fp === c.fp) params.fingerprint = c.fp;
                            } catch (e) {}
                        }
                    }
                } catch (e) {}
            }

            StateManager.cachedXHRGetWithParams('<%=url("admin", "services", "openclash", "config_file_list")%>', params, function(x, data) {
                if (x && x.status == 200) {
                    ConfigFileManager.handleConfigListResponse(data, params.fingerprint);
                } else {
                    ConfigFileManager.handleConfigListError();
                }
            }, !!force);
        },

        handleConfigListResponse: function(data, sentFp) {
            try {
                var configFiles = [];
                var currentConfigFile = '';

                if (data.config_files && Array.isArray(data.config_files)) {
                    configFiles = data.config_files;
                }

                if (data.current_config) {
                    currentConfigFile = data.current_config;
                }

                var fp = data.fingerprint;
                var ageFromCache = false;
                if (fp && sentFp && fp === sentFp) {
                    var ageCache = localStorage.getItem('oc_config_age');
                    if (ageCache) {
                        try {
                            var ac = JSON.parse(ageCache);
                            if (ac && ac.fp === fp && ac.ages) {
                                for (var j = 0; j < configFiles.length; j++) {
                                    var fname = configFiles[j].name.replace(/\.(yaml|yml)$/i, '');
                                    if (ac.ages.hasOwnProperty(fname)) {
                                        configFiles[j].age = ac.ages[fname];
                                    }
                                }
                                ageFromCache = true;
                            }
                        } catch (e) {}
                    }
                }

                if (fp && !ageFromCache) {
                    var ages = {};
                    for (var k = 0; k < configFiles.length; k++) {
                        var fn = configFiles[k].name.replace(/\.(yaml|yml)$/i, '');
                        ages[fn] = configFiles[k].age || false;
                    }
                    (window.requestIdleCallback || function(cb) { setTimeout(cb, 1); })(function() {
                        localStorage.setItem('oc_config_fp', JSON.stringify({fp: fp}));
                        localStorage.setItem('oc_config_age', JSON.stringify({fp: fp, ages: ages}));
                    });
                }

                var currentFileInfo = null;

                this.rawCurrentConfig = currentConfigFile;
                this.configList = configFiles;
                window.configFiles = configFiles;
                this.currentConfig = currentConfigFile;
                this.currentConfigIndex = -1;

                this.toggleEmptyState(configFiles.length === 0);

                this.updateConfigSelect(configFiles, currentConfigFile);

                if (configFiles.length > 0) {
                    if (currentConfigFile) {
                        for (var i = 0; i < configFiles.length; i++) {
                            var file = configFiles[i];
                            var filePath = typeof file === 'string' ? file : (file.path || file.filepath || file);

                            if (filePath === currentConfigFile) {
                                this.currentConfigIndex = i;
                                if (typeof file === 'object' && file.mtime && file.size) {
                                    currentFileInfo = {
                                        mtime: file.mtime,
                                        size: file.size,
                                        age: file.age
                                    };
                                }
                                break;
                            }
                        }
                    }

                    this.updateSubscriptionDisplay(currentConfigFile, currentFileInfo);

                    if (SubscriptionManager.currentConfigFile !== currentConfigFile) {
                        SubscriptionManager.currentConfigFile = currentConfigFile;
                        SubscriptionManager.getSubscriptionInfo();
                    }
                } else {
                    this.hideSubscriptionDisplay();
                    SubscriptionManager.currentConfigFile = '';
                }

                this.updateNavigationArrows();

                if (this.retryGetConfigList) {
                    clearInterval(this.retryGetConfigList);
                    this.retryGetConfigList = null;
                }

                this.configListLoaded = true;
                autoOpenGuide();

            } catch (e) {
                this.handleConfigListError();
            }
        },

        handleConfigListError: function() {
            this.updateSelectOptions([
                {value: '', text: '<%:Failed to load config files%>', disabled: true}
            ]);

            this.toggleEmptyState(true);
            this.hideSubscriptionDisplay();
            this.configListLoaded = true;
            autoOpenGuide();

            if (!this.retryGetConfigList) {
                var self = this;
                this.retryGetConfigList = setInterval(function() {
                    self.loadConfigFileList(true);
                }, 5000);
            }
        },

        toggleEmptyState: function(isEmpty) {
            var emptyStateElement = document.getElementById('config-file-empty-state');
            var configFileBottom = document.querySelector('.config-file-bottom');
            var configFileContent = document.querySelector('.config-file-content');

            if (isEmpty) {
                if (emptyStateElement) {
                    emptyStateElement.classList.remove('oc-hidden');
                }
                if (configFileBottom) {
                    configFileBottom.classList.add('oc-hidden');
                }
                if (configFileContent) {
                    configFileContent.classList.add('empty-state');
                }
                this.hideSubscriptionDisplay();
            } else {
                if (emptyStateElement) {
                    emptyStateElement.classList.add('oc-hidden');
                }
                if (configFileBottom) {
                    configFileBottom.classList.remove('oc-hidden');
                }
                if (configFileContent) {
                    configFileContent.classList.remove('empty-state');
                }
            }
        },

        hideSubscriptionDisplay: function() {
            var subscriptionDisplay = document.getElementById('subscription-info-display');
            if (subscriptionDisplay) {
                subscriptionDisplay.classList.add('oc-hidden');
            }
        },

        updateConfigSelect: function(configFiles, currentConfig) {
            var options = [];

            if (!configFiles || configFiles.length === 0) {
                options.push({
                    value: '',
                    text: '<%:No config files found%>',
                    disabled: true
                });
            } else {
                configFiles.forEach(function(file) {
                    var fileName, filePath;

                    if (typeof file === 'string') {
                        fileName = file;
                        filePath = file;
                    } else {
                        fileName = file.name || file.filename || file.path || file;
                        filePath = file.path || file.filepath || file.name || file;
                    }

                    var displayName = fileName;

                    options.push({
                        value: filePath,
                        text: displayName,
                        disabled: false,
                        selected: filePath === currentConfig || fileName === currentConfig
                    });
                });
            }

            this.updateSelectOptions(options);
        },

        updateSelectOptions: function(options) {
            if (!this.selectElement) return;

            this.selectElement.innerHTML = '';

            options.forEach(function(option) {
                var optionElement = document.createElement('option');
                optionElement.value = option.value;
                optionElement.textContent = option.text;
                optionElement.disabled = option.disabled || false;
                optionElement.selected = option.selected || false;

                this.selectElement.appendChild(optionElement);
            }, this);
        },

        updateSubscriptionDisplay: function(configFile, fileInfo) {
            var container = document.getElementById('subscription-info-display');
            var configNameElement = document.getElementById('current-config-name');
            var fileModifyTimeElement = document.getElementById('file-modify-time');
            var detailsSection = document.getElementById('subscription-info-details');
            var configFileContent = document.querySelector('.config-file-content');
            var ageFileIconElement = document.getElementById('age-file-icon');

            if (!container) return;

            if (this.configList.length === 0) {
                container.classList.add('oc-hidden');
                return;
            }

            if (!configFile) {
                container.classList.add('oc-hidden');
                return;
            }

            if (configFileContent && configFileContent.classList.contains('empty-state')) {
                container.classList.add('oc-hidden');
                return;
            }

            container.classList.remove('oc-hidden');

            if (configNameElement) {
                var displayName = this.formatDisplayName(configFile);
                if (configFile === this.rawCurrentConfig) {
                    configNameElement.innerHTML =
                        '<span class="selected-file-dot"></span>' + displayName;
                } else {
                    configNameElement.textContent = displayName;
                }
                if (configNameElement.scrollWidth > configNameElement.clientWidth) {
                    configNameElement.title = displayName;
                } else {
                    configNameElement.title = '';
                }
            }

            if (fileInfo) {
                if (fileModifyTimeElement) {
                    var modifyTime = this.formatUnixTime(fileInfo.mtime);
                    var fileModifyTimeValue = document.getElementById('file-modify-time-value');
                    fileModifyTimeValue.textContent = modifyTime;
                }

                if (detailsSection) {
                    detailsSection.style.display = 'flex';
                }

                if (ageFileIconElement) {
                    if (fileInfo.age) {
                        ageFileIconElement.innerHTML = '<svg width="16" height="16"><use href="#oc-icon-shield-check"/></svg>';
                        ageFileIconElement.title = '<%:Age Encryption File%>';
                        ageFileIconElement.classList.remove('oc-hidden');
                    } else {
                        ageFileIconElement.innerHTML = '';
                        ageFileIconElement.classList.add('oc-hidden');
                    }
                }
            } else {
                if (fileModifyTimeElement) {
                    var fileModifyTimeValue = document.getElementById('file-modify-time-value');
                    var modifyTimeText = '--';
                    fileModifyTimeValue.textContent = modifyTimeText;
                }

                if (detailsSection) {
                    detailsSection.style.display = 'none';
                }

                if (ageFileIconElement) {
                    ageFileIconElement.innerHTML = '';
                    ageFileIconElement.classList.add('oc-hidden');
                }
            }
        },

        formatUnixTime: ocFormatUnixTime,

        formatFileSize: ocFormatFileSize,

        formatDisplayName: function(fileName) {
            if (!fileName) return '<%:Unknown%>';

            var name = fileName.split('/').pop().split('\\').pop();

            if (name.length > 30) {
                name = name.substring(0, 27) + '...';
            }

            return name;
        },

        onConfigChange: function(event) {
            var selectedValue = event.target.value;

            if (selectedValue) {
                this.currentConfig = selectedValue;

                for (var i = 0; i < this.configList.length; i++) {
                    var file = this.configList[i];
                    var filePath = typeof file === 'string' ? file : (file.path || file.filepath || file);

                    if (filePath === selectedValue) {
                        this.currentConfigIndex = i;
                        break;
                    }
                }

                var selectedFileInfo = this.getConfigFileInfo(selectedValue);
                this.updateSubscriptionDisplay(selectedValue, selectedFileInfo);
                this.updateNavigationArrows();

                if (SubscriptionManager.currentConfigFile !== selectedValue) {
                    SubscriptionManager.currentConfigFile = selectedValue;
                    SubscriptionManager.retryCount = 0;
                    var detailsSection = document.getElementById('subscription-info-details');
                    if (detailsSection) {
                        detailsSection.style.display = 'none';
                    }
                    SubscriptionManager.getSubscriptionInfo();
                }
                OverwriteSubscribeManager.render(OverwriteSubscribeManager.data);
            } else {
                this.currentConfig = '';
                this.currentConfigIndex = -1;
                SubscriptionManager.currentConfigFile = '';
                this.hideSubscriptionDisplay();
                this.updateNavigationArrows();
                OverwriteSubscribeManager.render(OverwriteSubscribeManager.data);
            }
        },

        getConfigFileInfo: function(selectedValue) {
            var selectedFileInfo = null;
            for (var i = 0; i < this.configList.length; i++) {
                var file = this.configList[i];
                var filePath = typeof file === 'string' ? file : (file.path || file.filepath || file);
                if (filePath === selectedValue) {
                    if (typeof file === 'object' && file.mtime && file.size) {
                        selectedFileInfo = {
                            mtime: file.mtime,
                            size: file.size,
                            age: file.age
                        };
                    }
                    break;
                }
            }
            return selectedFileInfo;
        },

        updateNavigationArrows: function() {
            var prevArrow = document.getElementById('subscription-prev-arrow');
            var nextArrow = document.getElementById('subscription-next-arrow');

            if (!prevArrow || !nextArrow) return;

            var hasMultipleConfigs = this.configList.length > 1;
            var currentIndex = this.currentConfigIndex;

            if (!hasMultipleConfigs || currentIndex === -1) {
                prevArrow.style.display = 'none';
                nextArrow.style.display = 'none';
                return;
            }

            prevArrow.style.display = 'block';
            nextArrow.style.display = 'block';

            prevArrow.classList.remove('disabled');
            nextArrow.classList.remove('disabled');
        },

        switchToConfigByIndex: function(index) {
            if (this.configList.length === 0) {
                return false;
            }

            if (index < 0) {
                index = this.configList.length - 1;
            } else if (index >= this.configList.length) {
                index = 0;
            }

            var file = this.configList[index];
            var filePath = typeof file === 'string' ? file : (file.path || file.filepath || file);
            if (this.selectElement) {
                this.selectElement.value = filePath;
            }

            this.currentConfig = filePath;
            this.currentConfigIndex = index;

            var fileInfo = this.getConfigFileInfo(filePath);
            this.updateSubscriptionDisplay(filePath, fileInfo);
            this.updateNavigationArrows();

            if (SubscriptionManager.currentConfigFile !== filePath) {
                SubscriptionManager.currentConfigFile = filePath;
                SubscriptionManager.retryCount = 0;
                var detailsSection = document.getElementById('subscription-info-details');
                if (detailsSection) {
                    detailsSection.style.display = 'none';
                }
                SubscriptionManager.getSubscriptionInfo();
            }

            OverwriteSubscribeManager.render(OverwriteSubscribeManager.data);

            return true;
        },

        refreshConfigList: function() {
            this.loadConfigFileList(false);
        },

        getCurrentConfig: function() {
            return this.currentConfig;
        },

        getSelectedConfig: function() {
            return this.selectElement ? this.selectElement.value : '';
        }
    };

    var SubscriptionManager = {
        currentConfigFile: '',
        retryCount: 0,
        maxRetries: 1,
        updateTimer: null,
        isInitialized: false,

        enableOverflowDrag: function(element) {
            if (!element) return;

            if (!element.dragBound) {
                var isDragging = false;
                var startX = 0;
                var startScrollLeft = 0;
                var touchIdentifier = null;

                function endDrag() {
                    if (!isDragging) return;
                    isDragging = false;
                    touchIdentifier = null;
                    element.classList.remove('dragging');
                }

                element.addEventListener('mousedown', function(e) {
                    isDragging = true;
                    startX = e.pageX - element.getBoundingClientRect().left;
                    startScrollLeft = element.scrollLeft;
                    element.classList.add('dragging');
                    e.preventDefault();
                });

                element.addEventListener('mousemove', function(e) {
                    if (!isDragging) return;
                    var x = e.pageX - element.getBoundingClientRect().left;
                    var walk = (x - startX) * 1.2;
                    element.scrollLeft = startScrollLeft - walk;
                    e.preventDefault();
                });

                element.addEventListener('mouseleave', function() {
                    endDrag();
                });

                element.addEventListener('mouseup', function() {
                    endDrag();
                });

                element.addEventListener('touchstart', function(e) {
                    if (!e.touches || e.touches.length !== 1) return;

                    var touch = e.touches[0];
                    isDragging = true;
                    touchIdentifier = touch.identifier;
                    startX = touch.pageX - element.getBoundingClientRect().left;
                    startScrollLeft = element.scrollLeft;
                    element.classList.add('dragging');
                }, { passive: true });

                element.addEventListener('touchmove', function(e) {
                    if (!isDragging || !e.touches || e.touches.length === 0) return;

                    var touch = null;
                    for (var i = 0; i < e.touches.length; i++) {
                        if (e.touches[i].identifier === touchIdentifier) {
                            touch = e.touches[i];
                            break;
                        }
                    }

                    if (!touch) return;

                    var x = touch.pageX - element.getBoundingClientRect().left;
                    var walk = (x - startX) * 1.2;
                    element.scrollLeft = startScrollLeft - walk;
                    e.preventDefault();
                }, { passive: false });

                element.addEventListener('touchend', function() {
                    endDrag();
                });

                element.addEventListener('touchcancel', function() {
                    endDrag();
                });

                element.addEventListener('dragstart', function(e) {
                    e.preventDefault();
                });

                element.dragBound = true;
            }
        },

        init: function() {
            if (this.isInitialized) return;
            this.isInitialized = true;
            SubscriptionManager.loadSubscriptionInfo();
            SubscriptionManager.startAutoUpdate();
        },

        loadSubscriptionInfo: function() {
            var currentConfig = ConfigFileManager.getCurrentConfig() || ConfigFileManager.getSelectedConfig();
            if (currentConfig !== this.currentConfigFile) {
                this.currentConfigFile = currentConfig;
                this.getSubscriptionInfo();
            }
        },

        getSubscriptionInfo: function() {
            if (ConfigFileManager.configList.length === 0) {
                return;
            }

            if (!this.currentConfigFile) return;

            var requestConfigFile = this.currentConfigFile;
            var filename = this.extractFilename(this.currentConfigFile);
            if (!filename) return;

            var cachedData = localStorage.getItem('sub_info_' + filename);
            var shouldFetchNew = true;

            if (cachedData) {
                try {
                    var parsedData = JSON.parse(cachedData);

                    if (parsedData.providers) {
                        if (parsedData.providers.length > 0) {
                            if (this.currentConfigFile === requestConfigFile) {
                                this.displaySubscriptionInfo(parsedData);
                            }
                        } else {
                            if (this.currentConfigFile === requestConfigFile) {
                                this.showNoInfo();
                            }
                        }
                    }

                    if (parsedData.get_time) {
                        var currentTime = Math.floor(Date.now() / 1000);
                        var cacheTime = parseInt(parsedData.get_time);
                        var timeDiff = currentTime - cacheTime;
                        var halfHourInSeconds = 30 * 60;

                        if (timeDiff <= halfHourInSeconds) {
                            shouldFetchNew = false;
                        }
                    }
                } catch (e) {
                    shouldFetchNew = true;
                }
            }

            if (shouldFetchNew) {
                if (!cachedData) {
                    this.showLoading();
                }

                StateManager.cachedXHRGetWithParams('<%=url("admin", "services", "openclash", "sub_info_get")%>', {filename: filename}, function(x, status) {
                    if (SubscriptionManager.currentConfigFile !== requestConfigFile) {
                        return;
                    }

                    var needsErrorHandling = false;
                    var skipRetry = false;
                    if (x && x.status == 200 && status.providers.length > 0) {
                        var newProvidersLength = status.providers.length;
                        var cachedProvidersLength = (parsedData && parsedData.providers) ? parsedData.providers.length : 0;

                        if (newProvidersLength !== cachedProvidersLength && cachedProvidersLength > newProvidersLength) {
                            needsErrorHandling = true;
                        }

                        if (!needsErrorHandling) {
                            SubscriptionManager.retryCount = 0;
                            (window.requestIdleCallback || function(cb) { setTimeout(cb, 1); })(function() { localStorage.setItem('sub_info_' + filename, JSON.stringify(status)); });
                            if (status.providers && status.providers.length === 0) {
                                SubscriptionManager.showNoInfo();
                            }
                            SubscriptionManager.displaySubscriptionInfo(status);
                        }
                    } else {
                        needsErrorHandling = true;
                        skipRetry = (x && x.status == 500 && (String(x.statusText || '') + String(x.responseText || '')).indexOf('Subscription information not found') !== -1);
                    }

                    if (needsErrorHandling) {
                        SubscriptionManager.handleError(status, skipRetry);
                    }
                }, true);
            }
        },

        displaySubscriptionInfo: function(data) {
            if (ConfigFileManager.configList.length === 0) {
                return;
            }

            var container = document.getElementById('subscription-info-display');
            var progressSection = document.getElementById('subscription-progress-section');
            var detailsSection = document.getElementById('subscription-info-details');

            if (!container) return;

            var configFileContent = document.querySelector('.config-file-content');
            if (configFileContent && configFileContent.classList.contains('empty-state')) {
                return;
            }

            container.classList.remove('oc-hidden');

            if (data && data.providers && data.providers.length > 0) {
                if (data.providers.length > 1 || data.providers[0].provider_name) {
                    this.displayMultipleProviders(data.providers, progressSection);
                } else {
                    this.displaySingleProvider(data.providers[0], progressSection);
                }
            } else {
                progressSection.classList.add('oc-hidden');
            }

            if (detailsSection) {
                detailsSection.style.display = 'flex';
            }
        },

        displaySingleProvider: function(provider, progressSection) {
            if (!progressSection) return;

            progressSection.innerHTML = '';
            progressSection.classList.remove('oc-hidden');
            progressSection.className = 'subscription-progress';

            var progressBar = document.createElement('div');
            progressBar.className = 'subscription-progress-bar';

            var progressFill = document.createElement('div');
            progressFill.className = 'subscription-progress-fill';
            progressBar.appendChild(progressFill);

            var infoText = document.createElement('div');
            infoText.className = 'subscription-info-text';

            progressSection.appendChild(progressBar);
            progressSection.appendChild(infoText);

            var percent = parseFloat(provider.percent) || 0;
            var used = String(provider.surplus || provider.used || '0 B');
            var total = String(provider.total || '0 B');
            var expire = String(provider.expire || '');
            var daysLeft = parseInt(provider.day_left, 10);
            if (isNaN(daysLeft)) daysLeft = 0;

            progressFill.style.width = percent + '%';
            progressFill.className = 'subscription-progress-fill ' +
                (percent >= 50 ? 'high' : (percent >= 20 ? 'medium' : 'low'));

            var infoString = used + ' / ' + total + ' (' + percent + '%)';
            var tooltipString = infoString;
            if (expire && expire !== 'null' && daysLeft > 0) {
                infoString += ' • ' + expire + ' (<%:Remaining%> ' + daysLeft + ' <%:days%>)';
                tooltipString += '\n' + expire + ' (<%:Remaining%> ' + daysLeft + ' <%:days%>)';
            }

            infoText.textContent = infoString;
            infoText.title = tooltipString;
            this.enableOverflowDrag(infoText);
        },

        displayMultipleProviders: function(providers, progressSection) {
            if (!progressSection) return;

            var displayProviders = providers;
            var providerCount = displayProviders.length;

            progressSection.innerHTML = '';
            progressSection.classList.remove('oc-hidden');
            progressSection.className = 'subscription-providers-grid';
            progressSection.setAttribute('data-count', providerCount);

            displayProviders.forEach(function(provider) {
                var card = document.createElement('div');
                card.className = 'provider-card';

                var cardName = document.createElement('div');
                var providerName = String(provider.provider_name || 'Unknown');
                cardName.className = 'subscription-info-title';
                cardName.textContent = providerName;
                cardName.title = providerName;
                card.appendChild(cardName);

                var progressBar = document.createElement('div');
                progressBar.className = 'subscription-progress-bar';

                var progressFill = document.createElement('div');
                var percent = parseFloat(provider.percent) || 0;
                progressFill.style.width = percent + '%';
                progressFill.className = 'subscription-progress-fill ' +
                    (percent >= 50 ? 'high' : (percent >= 20 ? 'medium' : 'low'));

                progressBar.appendChild(progressFill);
                card.appendChild(progressBar);

                var infoText = document.createElement('div');
                infoText.className = 'subscription-info-text';

                var used = String(provider.used || '0 B');
                var total = String(provider.total || 'N/A');
                var expire = String(provider.expire || '');
                var daysLeft = parseInt(provider.day_left, 10);
                if (isNaN(daysLeft)) daysLeft = 0;

                var infoString = used + ' / ' + total + ' (' + percent + '%)';
                if (expire && expire !== 'null' && daysLeft > 0) {
                    infoString += ' • ' + expire + ' (<%:Remaining%> ' + daysLeft + ' <%:days%>)';
                }

                var tooltipString = used + ' / ' + total + ' (' + percent + '%)';
                if (expire && expire !== 'null' && daysLeft > 0) {
                    tooltipString += '\n' + expire + ' (<%:Remaining%> ' + daysLeft + ' <%:days%>)';
                }

                infoText.textContent = infoString;
                infoText.title = tooltipString;
                SubscriptionManager.enableOverflowDrag(infoText);

                card.appendChild(infoText);
                progressSection.appendChild(card);
            });

            if (providerCount > 3) {
                this.initDragScroll(progressSection);
            }
        },

        initDragScroll: function(element) {
            var isDragging = false;
            var startX;
            var scrollLeft;
            var hasMoved = false;

            var onMouseDown = function(e) {
                if (e.target.tagName === 'A' || e.target.tagName === 'BUTTON') {
                    return;
                }

                isDragging = true;
                hasMoved = false;
                startX = e.pageX - element.offsetLeft;
                scrollLeft = element.scrollLeft;
                element.classList.add('dragging');
            };

            var onMouseMove = function(e) {
                if (!isDragging) return;

                var x = e.pageX - element.offsetLeft;
                var walk = (x - startX) * 1.5;

                if (Math.abs(walk) > 5) {
                    hasMoved = true;
                    e.preventDefault();
                    element.scrollLeft = scrollLeft - walk;
                }
            };

            var onMouseUp = function() {
                isDragging = false;
                element.classList.remove('dragging');
            };

            var onMouseLeave = function() {
                if (isDragging) {
                    isDragging = false;
                    element.classList.remove('dragging');
                }
            };

            element.addEventListener('mousedown', onMouseDown);
            element.addEventListener('mousemove', onMouseMove);
            element.addEventListener('mouseup', onMouseUp);
            element.addEventListener('mouseleave', onMouseLeave);

            element.addEventListener('dragstart', function(e) {
                e.preventDefault();
            });
        },

        showNoInfo: function() {
            if (ConfigFileManager.configList.length === 0) {
                return;
            }

            var container = document.getElementById('subscription-info-display');
            var progressSection = document.getElementById('subscription-progress-section');
            var detailsSection = document.getElementById('subscription-info-details');

            if (!container) return;

            var configFileContent = document.querySelector('.config-file-content');
            if (configFileContent && configFileContent.classList.contains('empty-state')) {
                return;
            }

            container.classList.remove('oc-hidden');

            if (progressSection) {
                progressSection.innerHTML = '<div class="subscription-no-info"><%:No Sub Info Found%></div>';
                progressSection.classList.remove('oc-hidden');
                progressSection.className = 'subscription-progress';
            }

            if (detailsSection) {
                var fileModifyTimeElement = document.getElementById('file-modify-time');

                var hasFileInfo = false;
                if (fileModifyTimeElement) {
                    var modifyTimeText = fileModifyTimeElement.textContent || '';
                    hasFileInfo = !modifyTimeText.includes('--');
                }

                detailsSection.style.display = hasFileInfo ? 'flex' : 'none';
            }
        },

        showLoading: function() {
            if (ConfigFileManager.configList.length === 0) {
                return;
            }

            var container = document.getElementById('subscription-info-display');
            var progressSection = document.getElementById('subscription-progress-section');
            var detailsSection = document.getElementById('subscription-info-details');

            if (!container) return;

            var configFileContent = document.querySelector('.config-file-content');
            if (configFileContent && configFileContent.classList.contains('empty-state')) {
                return;
            }

            container.classList.remove('oc-hidden');

            if (progressSection) {
                progressSection.innerHTML = '<div class="oc-sk oc-sk-block" style="width:92%"></div><div class="oc-sk oc-sk-block" style="width:55%"></div>';
                progressSection.classList.remove('oc-hidden');
                progressSection.className = 'subscription-progress';
            }

            if (detailsSection) {
                detailsSection.style.display = 'none';
            }
        },

        handleError: function(status, skipRetry) {
            if (skipRetry || this.retryCount >= this.maxRetries) {
                this.retryCount = 0;
                var fail_info = (status && status.providers) ? status : {providers: [], get_time: Math.floor(Date.now() / 1000)};
                if (this.currentConfigFile) {
                    var errFilename = this.extractFilename(this.currentConfigFile);
                    if (errFilename) {
                        (window.requestIdleCallback || function(cb) { setTimeout(cb, 1); })(function() { localStorage.setItem('sub_info_' + errFilename, JSON.stringify(fail_info)); });
                    }
                }
                if (!fail_info.providers || fail_info.providers.length === 0) {
                    this.showNoInfo();
                } else {
                    SubscriptionManager.displaySubscriptionInfo(fail_info);
                }
            } else {
                this.retryCount++;
                this.showLoading();
                setTimeout(function() {
                    SubscriptionManager.getSubscriptionInfo();
                }, 5000);
            }
        },

        extractFilename: function(path) {
            if (!path) return '';
            var parts = path.split('/');
            var filename = parts[parts.length - 1];

            if (filename.endsWith('.yaml')) {
                filename = filename.slice(0, -5);
            } else if (filename.endsWith('.yml')) {
                filename = filename.slice(0, -4);
            }

            return filename;
        },

        startAutoUpdate: function() {
            if (this.updateTimer) {
                clearTimeout(this.updateTimer);
            }

            this.updateTimer = setTimeout(function() {
                SubscriptionManager.getSubscriptionInfo();
                SubscriptionManager.startAutoUpdate();
            }, 60000 * 15);
        },

        stopAutoUpdate: function() {
            if (this.updateTimer) {
                clearTimeout(this.updateTimer);
                this.updateTimer = null;
            }
        }
    };

    var OverwriteSubscribeManager = {
        container: null,
        data: null,
        isLoading: false,
        dragBound: false,
        isDragging: false,
        tapStartX: null,
        tapStartY: null,
        dragStartX: 0,
        dragStartScrollLeft: 0,
        touchIdentifier: null,

        init: function() {
            this.container = document.getElementById('subscription-overwrite-tags');
            if (!this.container) return;
            this.bindDragScroll();
            this.load(false);
        },

        hasOverflow: function() {
            if (!this.container) return false;
            return this.container.scrollWidth > this.container.clientWidth + 1;
        },

        updateDragScrollState: function() {
            if (!this.container) return;
            if (this.hasOverflow()) {
                this.container.classList.add('drag-scroll-enabled');
            } else {
                this.container.classList.remove('drag-scroll-enabled');
                this.container.classList.remove('dragging');
            }
        },

        bindDragScroll: function() {
            if (!this.container || this.dragBound) {
                return;
            }

            var self = this;

            function endDrag() {
                if (!self.isDragging) return;
                self.isDragging = false;
                self.touchIdentifier = null;
                self.container.classList.remove('dragging');
            }

            this.container.addEventListener('mousedown', function(e) {
                if (!self.hasOverflow()) {
                    return;
                }
                self.isDragging = true;
                self.tapStartX = e.clientX;
                self.tapStartY = e.clientY;
                self.dragStartX = e.pageX - self.container.offsetLeft;
                self.dragStartScrollLeft = self.container.scrollLeft;
                self.container.classList.add('dragging');
                e.preventDefault();
            });

            this.container.addEventListener('mousemove', function(e) {
                if (!self.isDragging) {
                    return;
                }
                var x = e.pageX - self.container.offsetLeft;
                var walk = (x - self.dragStartX) * 1.5;
                self.container.scrollLeft = self.dragStartScrollLeft - walk;
                e.preventDefault();
            });

            this.container.addEventListener('mouseleave', function() {
                endDrag();
            });

            this.container.addEventListener('mouseup', function() {
                endDrag();
            });

            this.container.addEventListener('touchstart', function(e) {
                if (!self.hasOverflow() || !e.touches || e.touches.length !== 1) {
                    return;
                }
                var touch = e.touches[0];
                self.isDragging = true;
                self.tapStartX = touch.clientX;
                self.tapStartY = touch.clientY;
                self.touchIdentifier = touch.identifier;
                self.dragStartX = touch.pageX - self.container.offsetLeft;
                self.dragStartScrollLeft = self.container.scrollLeft;
                self.container.classList.add('dragging');
            }, { passive: true });

            this.container.addEventListener('touchmove', function(e) {
                if (!self.isDragging || !e.touches || e.touches.length === 0) {
                    return;
                }

                var touch = null;
                for (var i = 0; i < e.touches.length; i++) {
                    if (e.touches[i].identifier === self.touchIdentifier) {
                        touch = e.touches[i];
                        break;
                    }
                }
                if (!touch) {
                    return;
                }

                var x = touch.pageX - self.container.offsetLeft;
                var walk = (x - self.dragStartX) * 1.5;
                self.container.scrollLeft = self.dragStartScrollLeft - walk;
                e.preventDefault();
            }, { passive: false });

            this.container.addEventListener('touchend', function() {
                endDrag();
            });

            this.container.addEventListener('touchcancel', function() {
                endDrag();
            });

            this.container.addEventListener('dragstart', function(e) {
                e.preventDefault();
            });

            this.container.addEventListener('click', function(e) {
                if (e.target === self.container) {
                    self.selectTag(null);
                }
            });

            this.dragBound = true;
        },

        load: function(force) {
            if (!this.container || this.isLoading) {
                return;
            }

            this.isLoading = true;
            var self = this;

            StateManager.cachedXHRGet('<%=url("admin", "services", "openclash", "overwrite_subscribe_info")%>', function(x, status) {
                self.isLoading = false;
                if (x && x.status == 200 && status && status.status === 'success' && status.data) {
                    self.data = status.data;
                    self.render(status.data);
                } else {
                    self.render(null);
                }
            }, !!force);
        },

        getTypeClass: function(type) {
            var normalizedType = String(type || '').toLowerCase();
            if (normalizedType === 'http') return 'type-http';
            if (normalizedType === 'file') return 'type-file';
            return 'type-unknown';
        },

        parseModuleConfigList: function(configValue) {
            if (!Array.isArray(configValue)) {
                return [];
            }
            return configValue.map(function(item) {
                return String(item || '').trim();
            }).filter(function(item) {
                return !!item;
            });
        },

        isModuleForCurrentConfig: function(moduleInfo, currentConfigPath) {
            var configList = this.parseModuleConfigList(moduleInfo ? moduleInfo.config : null);
            // an empty match list never applies (init.d skips overwrite modules without config)
            if (!configList.length) {
                return false;
            }

            if (configList.indexOf('all') !== -1) {
                return true;
            }

            var fullPath = String(currentConfigPath || '').trim();
            if (!fullPath) {
                return false;
            }

            return configList.indexOf(fullPath) !== -1;
        },

        getEnabledModules: function(data) {
            if (!data || typeof data !== 'object') {
                return [];
            }

            var currentConfigPath = ConfigFileManager.getCurrentConfig() || ConfigFileManager.getSelectedConfig();

            var modules = [];
            for (var moduleName in data) {
                if (!Object.prototype.hasOwnProperty.call(data, moduleName)) {
                    continue;
                }

                var moduleInfo = data[moduleName] || {};
                if (parseInt(moduleInfo.enable, 10) === 1 && this.isModuleForCurrentConfig(moduleInfo, currentConfigPath)) {
                    modules.push({
                        name: moduleName,
                        type: moduleInfo.type || 'unknown',
                        desc: moduleInfo.desc || '',
                        order: parseInt(moduleInfo.order, 10) || 0
                    });
                }
            }

            modules.sort(function(a, b) {
                if (a.order === b.order) {
                    return String(a.name).localeCompare(String(b.name));
                }
                return a.order - b.order;
            });

            return modules;
        },

        openModule: function(name) {
            var open = function() {
                if (typeof ConfigEditor === 'undefined' || !ConfigEditor.showOverwrite) {
                    ocAlert('<%:Failed to load the interface, please refresh the page and try again%>');
                    return;
                }
                ConfigEditor.currentConfigFile = '/etc/openclash/overwrite/' + name;
                ConfigEditor.isOverwrite = true;
                ConfigEditor.showOverwrite();
            };

            if (typeof ConfigEditor !== 'undefined' && ConfigEditor.showOverwrite) {
                open();
                return;
            }

            ocLoadCss(ocCssUrl('oc-config-edit.css'));
            requireEditorScript('config_edit.js', 'ConfigEditor', open);
        },

        selectTag: function(tag) {
            if (!this.container) return;
            var selected = this.container.querySelectorAll('.subscription-overwrite-tag.is-selected');
            for (var i = 0; i < selected.length; i++) {
                selected[i].classList.remove('is-selected');
            }
            if (tag) {
                tag.classList.add('is-selected');
            }
        },

        handleTagClick: function(tag, event) {
            // a gesture that started on the strip and ended somewhere else was a scroll, not a tap;
            // the recorded origin only exists while the strip can be dragged
            if (event && this.hasOverflow() && this.tapStartX !== null) {
                if (Math.abs(event.clientX - this.tapStartX) > 6 || Math.abs(event.clientY - this.tapStartY) > 6) {
                    return;
                }
            }

            var name = tag.getAttribute('data-module');
            if (!name) {
                return;
            }

            // touch devices have no hover state, so the first tap selects and a second tap opens
            if (window.matchMedia && window.matchMedia('(hover: none)').matches && !tag.classList.contains('is-selected')) {
                this.selectTag(tag);
                return;
            }

            this.openModule(name);
        },

        render: function(data) {
            if (!this.container) return;

            var self = this;
            var enabledModules = this.getEnabledModules(data);
            this.container.innerHTML = '';

            if (enabledModules.length === 0) {
                this.container.classList.add('oc-hidden');
                this.updateDragScrollState();
                return;
            }

            for (var i = 0; i < enabledModules.length; i++) {
                var moduleItem = enabledModules[i];
                var tag = document.createElement('span');
                tag.className = 'subscription-overwrite-tag ' + this.getTypeClass(moduleItem.type);
                tag.title = moduleItem.desc ? moduleItem.name + '\n' + moduleItem.desc : moduleItem.name;
                tag.textContent = moduleItem.name;
                tag.setAttribute('data-module', moduleItem.name);
                tag.addEventListener('click', function(e) {
                    self.handleTagClick(this, e);
                });
                if (moduleItem.type == 'http') {
                    tag.title += ' [<%:HTTP Module%>]';
                } else if (moduleItem.type == 'file') {
                    tag.title += ' [<%:File Module%>]';
                } else {
                    tag.title += ' [<%:Unknown%>]';
                }
                this.container.appendChild(tag);
            }

            this.container.classList.remove('oc-hidden');
            this.updateDragScrollState();
        }
    };

    var LogManager = {
        stream: null,
        lastLogLineCount: null,
        logLines: [],
        scriptDone: true,

        // marks a restart so a later-opened log dialog resumes the session with a live clock
        markCoreStart: function() {
            try { sessionStorage.setItem('ocCoreStartAt', String(Date.now())); } catch (e) {}
        },

        // Clear the log before streaming so the operation API is served first and the stream does not block it
        startLogDisplay: function(initialMessage, skipClearLog, scriptName) {
            if (this.stream) {
                if (initialMessage) {
                    this.stream.abort();
                    this.stream = null;
                } else {
                    return;
                }
            }
            this.scriptDone = false;
            if (initialMessage) {
                this.lastLogLineCount = null;
                this.logLines = [];
                if (DOMCache.oclog && DOMCache.oclog.ocScrollAnimId) {
                    cancelAnimationFrame(DOMCache.oclog.ocScrollAnimId);
                    DOMCache.oclog.ocScrollAnimId = null;
                }
            }

            var self = this;

            var stream = ocCreateLogStream({
                url: '<%=url("admin", "services", "openclash", "startlog")%>',
                script: scriptName,
                initialMessage: initialMessage,
                skipLines: this.lastLogLineCount,
                onSkipLines: function(n) { self.lastLogLineCount = n; },
                maxWaitMs: initialMessage ? 600000 : 0,
                display: function(text) { self.displayLog(text); },
                onFinish: function() {
                    self.stream = null;
                    self.scriptDone = true;
                    setTimeout(function() {
                        if (!DOMCache.oclog) return;
                        if (!self.stream || !self.stream.isRunning()) {
                            DOMCache.oclog.classList.add('oc-hidden');
                            DOMCache.oclog.innerHTML = '';
                        }
                    }, 1000);
                }
            });
            this.stream = stream;

            if (skipClearLog) {
                stream.start();
            } else {
                XHR.get('<%=url("admin", "services", "openclash", "del_start_log")%>', null, function() {
                    stream.start();
                });
            }
        },

        stopLogDisplay: function() {
            if (this.stream) {
                this.stream.abort();
                this.stream = null;
            }
            this.scriptDone = true;
            if (DOMCache.oclog && DOMCache.oclog.ocScrollAnimId) {
                cancelAnimationFrame(DOMCache.oclog.ocScrollAnimId);
                DOMCache.oclog.ocScrollAnimId = null;
            }
            if (DOMCache.oclog) {
                setTimeout(function() {
                    if (!LogManager.stream || !LogManager.stream.isRunning()) {
                        DOMCache.oclog.classList.add('oc-hidden');
                        DOMCache.oclog.innerHTML = '';
                    }
                }, 1000);
            }
        },

        displayLog: function(logContent) {
            if (!this.stream || !this.stream.isRunning() || !DOMCache.oclog) return;
            var lines = logContent.split('\n');
            var allLines = [];
            for (var i = 0; i < lines.length; i++) {
                var t = lines[i].replace(/##FINISHED##|##CONTINUE##|##FINISH##/g, '').trim().replace(/^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\s*/, '');
                if (t) allLines.push(t);
            }
            if (allLines.length === 0) return;
            this.logLines = this.logLines.concat(allLines);

            var maxLines = 10;
            var el = DOMCache.oclog;

            if (!el.wheelBlocked) {
                el.addEventListener('wheel', function(e) { e.preventDefault(); }, { passive: false });
                el.wheelBlocked = true;
            }

            var merged = this.logLines.slice(this.logLines.length - maxLines);

            // the rebuild collapses the box, so hold the offset: a running glide keeps going and a
            // parked box rewinds only by the rows this update added (see ocAnimateScroll)
            var keepOffset = el.scrollTop;
            el.innerHTML = '';
            for (var j = 0; j < merged.length; j++) {
                var color = ocGetLogColor(merged[j]);
                var div = document.createElement('div');
                div.style.whiteSpace = 'nowrap';
                div.innerHTML = '<b style="color:' + color + '">' + merged[j] + '</b>';
                el.appendChild(div);
            }
            while (el.children.length < maxLines) {
                var spacer = document.createElement('div');
                spacer.className = 'oc-log-spacer';
                spacer.style.visibility = 'hidden';
                spacer.style.whiteSpace = 'nowrap';
                spacer.textContent = '\u200B';
                el.insertBefore(spacer, el.firstChild);
            }

            el.classList.remove('oc-hidden');
            el.scrollTop = keepOffset;
            el.style.willChange = 'scroll-position';
            ocAnimateScroll(el, Math.min(maxLines, allLines.length));
        }
    };

    // the start-flow dialog reuses this stream instead of opening a second one
    window.ocStatusLogLines = function() { return LogManager.logLines || []; };
    window.ocStatusScriptDone = function() { return !!LogManager.scriptDone; };
    // dialog-started switches register like the page's own restart buttons (stamp + init watch)
    window.ocStatusMarkCoreStart = function() {
        LogManager.markCoreStart();
        LogManager.startLogDisplay('<%:Switching Config...%>', false, 'init');
    };

    if (DOMCache.oclog) {
        DOMCache.oclog.addEventListener('click', function() { ocOpenCoreStartFlow(); });
    }

    var SystemStatusManager = {
        pollTimer: null,
        pollInterval: 5000,
        retryCount: 0,
        maxRetries: 3,
        isEnabled: false,
        cpuTicks: 0,
        cpuTime: 0,

        ZERO_SYS_STATS: [
            {id: "cpu_t", html: ocStatHtml("0 %")},
            {id: "load_a", html: ocStatHtml("0 %")}
        ],

        resetSysStats: function() {
            for (var i = 0; i < this.ZERO_SYS_STATS.length; i++) {
                var item = this.ZERO_SYS_STATS[i];
                var el = document.getElementById(item.id);
                if (el) el.innerHTML = item.html;
            }
        },

        start: function() {
            if (this.isEnabled) return;
            this.isEnabled = true;
            this.retryCount = 0;
            this.poll();
        },

        stop: function() {
            this.isEnabled = false;
            if (this.pollTimer) {
                clearTimeout(this.pollTimer);
                this.pollTimer = null;
            }
        },

        poll: function() {
            if (!this.isEnabled) return;

            var self = this;
            StateManager.cachedXHRGet('<%=url("admin", "services", "openclash", "toolbar_show_sys")%>', function(x, status) {
                if (x && x.status == 200 && x.responseText != "" && status) {
                    self.retryCount = 0;
                    // two cumulative tick samples give the usage; USER_HZ is 100, so ticks/s is percent
                    var ticks = Number(status.cpu_ticks);
                    var now = Date.now();
                    var cpuValueNumber = 0;
                    if (isFinite(ticks) && ticks > 0) {
                        if (self.cpuTicks && ticks >= self.cpuTicks && now > self.cpuTime) {
                            cpuValueNumber = (ticks - self.cpuTicks) / ((now - self.cpuTime) / 1000);
                            if (!isFinite(cpuValueNumber) || cpuValueNumber < 0) cpuValueNumber = 0;
                            if (cpuValueNumber > 100) cpuValueNumber = 100;
                        }
                        self.cpuTicks = ticks;
                        self.cpuTime = now;
                    } else {
                        self.cpuTicks = 0;
                    }
                    var cpuColor = cpuValueNumber <= 50 ? "var(--success-color)" : (cpuValueNumber <= 80 ? "var(--tip-color)" : "var(--error-color)");
                    var cpuValue = ocFormatOneDecimal(cpuValueNumber) + " %";
                    document.getElementById("cpu_t").innerHTML = ocStatHtml(cpuValue, cpuColor);

                    var loadValue = parseFloat(status.load_avg) || 0;
                    if (!isFinite(loadValue) || loadValue < 0) loadValue = 0;
                    var loadColor = loadValue <= 50 ? "var(--success-color)" : (loadValue <= 80 ? "var(--tip-color)" : "var(--error-color)");
                    var loadText = ocFormatOneDecimal(loadValue);
                    document.getElementById("load_a").innerHTML = ocStatHtml(loadText + " %", loadColor);
                    StatsChart.feed("cpu", cpuValueNumber);
                    StatsChart.feed("load", loadValue);
                } else {
                    self.handleError();
                }

                if (self.isEnabled) {
                    self.pollTimer = setTimeout(function() {
                        self.poll();
                    }, self.pollInterval);
                }
            }, true);
        },

        handleError: function() {
            this.retryCount = 0;
            this.cpuTicks = 0;
            this.cpuTime = 0;
            this.resetSysStats();
            StatsChart.feed("cpu", 0);
            StatsChart.feed("load", 0);
        },

        setPollInterval: function(interval) {
            this.pollInterval = interval;
        }
    };

    var NetworkStatsManager = {
        pollTimer: null,
        pollInterval: 3000,
        retryCount: 0,
        maxRetries: 3,
        isEnabled: false,
        lastTotals: null,
        lastTime: 0,

        ZERO_STATS: [
            {id: "upload_", html: ocStatHtml("0 B/s")},
            {id: "download_", html: ocStatHtml("0 B/s")},
            {id: "uploadtotal_", html: ocStatHtml("0 KB")},
            {id: "downloadtotal_", html: ocStatHtml("0 KB")},
            {id: "mem_t", html: ocStatHtml("0 KB")},
            {id: "connect_t", html: ocStatHtml("0")}
        ],

        resetStats: function() {
            for (var i = 0; i < this.ZERO_STATS.length; i++) {
                var item = this.ZERO_STATS[i];
                var el = document.getElementById(item.id);
                if (el) el.innerHTML = item.html;
            }
        },

        start: function() {
            if (this.isEnabled) return;
            this.isEnabled = true;
            this.retryCount = 0;
            this.poll();
        },

        stop: function() {
            this.isEnabled = false;
            if (this.pollTimer) {
                clearTimeout(this.pollTimer);
                this.pollTimer = null;
            }
        },

        poll: function() {
            if (!this.isEnabled) return;

            var self = this;
            StateManager.cachedXHRGet('<%=url("admin", "services", "openclash", "toolbar_show")%>', function(x, status) {
                if (x && x.status == 200 && x.responseText != "" && status) {
                    self.retryCount = 0;
                    self.updateNetworkStats(status);
                } else {
                    self.handleError();
                }

                if (self.isEnabled) {
                    self.pollTimer = setTimeout(function() {
                        self.poll();
                    }, self.pollInterval);
                }
            }, true);
        },

        updateNetworkStats: function(status) {
            var upTotal = Number(status && status.up_total);
            var downTotal = Number(status && status.down_total);
            var mem = Number(status && status.mem);
            var connections = Number(status && status.connections);
            if (!isFinite(upTotal)) upTotal = 0;
            if (!isFinite(downTotal)) downTotal = 0;
            if (!isFinite(mem)) mem = 0;
            if (!isFinite(connections)) connections = 0;
            // the totals are cumulative, two samples give the average rate since the last poll
            var now = Date.now();
            var up = 0, down = 0;
            if (this.lastTotals && upTotal >= this.lastTotals.up && downTotal >= this.lastTotals.down && now > this.lastTime) {
                var dt = (now - this.lastTime) / 1000;
                if (dt > 0.2) {
                    up = (upTotal - this.lastTotals.up) / dt;
                    down = (downTotal - this.lastTotals.down) / dt;
                }
            }
            this.lastTotals = { up: upTotal, down: downTotal };
            this.lastTime = now;
            var updates = [
                {element: document.getElementById("upload_"), content: ocStatHtml(bytesToSize(up) + "/s")},
                {element: document.getElementById("download_"), content: ocStatHtml(bytesToSize(down) + "/s")},
                {element: document.getElementById("uploadtotal_"), content: ocStatHtml(bytesToSize(upTotal))},
                {element: document.getElementById("downloadtotal_"), content: ocStatHtml(bytesToSize(downTotal))},
                {element: document.getElementById("mem_t"), content: ocStatHtml(bytesToSize(mem))},
                {element: document.getElementById("connect_t"), content: ocStatHtml(String(connections))}
            ];

            StateManager.batchUpdateDOM(updates);
            StatsChart.feed("up", up / 1048576);
            StatsChart.feed("down", down / 1048576);
            StatsChart.feed("mem", mem / 1048576);
            StatsChart.feed("conn", connections);
        },

        handleError: function() {
            this.retryCount = 0;
            this.lastTotals = null;
            this.lastTime = 0;
            this.resetStats();
            StatsChart.feed("up", 0);
            StatsChart.feed("down", 0);
            StatsChart.feed("mem", 0);
            StatsChart.feed("conn", 0);
        },

        setPollInterval: function(interval) {
            this.pollInterval = interval;
        }
    };

    var SettingsManager = {
        pendingOperations: new Set(),
        pausedPolls: new Set(),

        pausePoll: function(pollName, duration) {
            this.pausedPolls.add(pollName);
            setTimeout(() => {
                this.pausedPolls.delete(pollName);
            }, duration || 3000);
        },

        isPollPaused: function(pollName) {
            return this.pausedPolls.has(pollName);
        },

        updateUIState: function(setting, value) {
            setTimeout(() => {
                function setCheckedAndDisabled(elements, checkedIndex) {
                    for (let i = 0; i < elements.length; i++) {
                        elements[i].checked = (i === checkedIndex);
                        elements[i].disabled = true;
                    }
                }
                switch(setting) {
                    case 'meta_sniffer':
                        var metaSnifferOn = document.getElementById('meta_sniffer_on');
                        var metaSnifferOff = document.getElementById('meta_sniffer_off');
                        if (metaSnifferOn && metaSnifferOff) {
                            setCheckedAndDisabled([metaSnifferOn, metaSnifferOff], value === '1' ? 0 : 1);
                            var changeEvent = new Event('change', { bubbles: true });
                            (value === '1' ? metaSnifferOn : metaSnifferOff).dispatchEvent(changeEvent);
                        }
                        break;
                    case 'respect_rules':
                        var respectRulesOn = document.getElementById('respect_rules_on');
                        var respectRulesOff = document.getElementById('respect_rules_off');
                        if (respectRulesOn && respectRulesOff) {
                            setCheckedAndDisabled([respectRulesOn, respectRulesOff], value === '1' ? 0 : 1);
                            var changeEvent = new Event('change', { bubbles: true });
                            (value === '1' ? respectRulesOn : respectRulesOff).dispatchEvent(changeEvent);
                        }
                        break;
                    case 'oversea':
                        var oversea0 = document.getElementById('oc_setting_oversea_0');
                        var oversea1 = document.getElementById('oc_setting_oversea_1');
                        var oversea2 = document.getElementById('oc_setting_oversea_2');
                        if (oversea0 && oversea1 && oversea2) {
                            setCheckedAndDisabled([oversea0, oversea1, oversea2], value === '0' ? 0 : (value === '1' ? 1 : 2));
                            var changeEvent = new Event('change', { bubbles: true });
                            [oversea0, oversea1, oversea2][value === '0' ? 0 : (value === '1' ? 1 : 2)].dispatchEvent(changeEvent);
                        }
                        break;
                    case 'stream_unlock':
                        var streamUnlockOn = document.getElementById('stream_unlock_on');
                        var streamUnlockOff = document.getElementById('stream_unlock_off');
                        if (streamUnlockOn && streamUnlockOff) {
                            setCheckedAndDisabled([streamUnlockOn, streamUnlockOff], value === '1' ? 0 : 1);
                            var changeEvent = new Event('change', { bubbles: true });
                            (value === '1' ? streamUnlockOn : streamUnlockOff).dispatchEvent(changeEvent);
                        }
                        break;
                    case 'rule_mode':
                        var radioElements = document.getElementsByName("radios");
                        if (radioElements && radioElements.length > 0) {
                            for (var i = 0; i < radioElements.length; i++) {
                                radioElements[i].checked = radioElements[i].value === value;
                                radioElements[i].disabled = true;
                                if (radioElements[i].checked) {
                                    var changeEvent = new Event('change', { bubbles: true });
                                    radioElements[i].dispatchEvent(changeEvent);
                                }
                            }
                        }
                        break;
                    case 'run_mode':
                        var radioRuElements = document.getElementsByName("radios-ru");
                        if (radioRuElements && radioRuElements.length > 0) {
                            for (var i = 0; i < radioRuElements.length; i++) {
                                radioRuElements[i].checked = radioRuElements[i].value === value;
                                radioRuElements[i].disabled = true;
                                if (radioRuElements[i].checked) {
                                    var changeEvent = new Event('change', { bubbles: true });
                                    radioRuElements[i].dispatchEvent(changeEvent);
                                }
                            }
                        }
                        break;
                }
            }, 10);
        },

        switchSetting: function(setting, value, endpoint, additionalParams) {
            var operationKey = setting + '_' + value;

            if (this.pendingOperations.has(operationKey)) {
                return false;
            }

            this.pendingOperations.add(operationKey);

            try {
                this.updateUIState(setting, value);
            } catch (e) {}

            let pollName;
            if (setting === 'rule_mode') {
                pollName = 'rule_mode';
            } else if (setting === 'run_mode') {
                pollName = 'run_mode';
            } else {
                pollName = 'oc_settings';
            }
            this.pausedPolls.add(pollName);

            var params = Object.assign({}, additionalParams || {});
            if (setting !== 'rule_mode' && setting !== 'run_mode') {
                params.setting = setting;
                params.value = value;
            } else if (setting === 'rule_mode') {
                params.rule_mode = value;
            } else if (setting === 'run_mode') {
                params.run_mode = value;
            }

            var self = this;

            XHR.get(endpoint, params, function(x, status) {
                setTimeout(function() {
                    self.pendingOperations.delete(operationKey);

                    switch(setting) {
                        case 'meta_sniffer':
                            var metaSnifferOn = document.getElementById('meta_sniffer_on');
                            var metaSnifferOff = document.getElementById('meta_sniffer_off');
                            if (metaSnifferOn) metaSnifferOn.disabled = false;
                            if (metaSnifferOff) metaSnifferOff.disabled = false;
                            break;
                        case 'respect_rules':
                            var respectRulesOn = document.getElementById('respect_rules_on');
                            var respectRulesOff = document.getElementById('respect_rules_off');
                            if (respectRulesOn) respectRulesOn.disabled = false;
                            if (respectRulesOff) respectRulesOff.disabled = false;
                            break;
                        case 'oversea':
                            var oversea0 = document.getElementById('oc_setting_oversea_0');
                            var oversea1 = document.getElementById('oc_setting_oversea_1');
                            var oversea2 = document.getElementById('oc_setting_oversea_2');
                            if (oversea0) oversea0.disabled = false;
                            if (oversea1) oversea1.disabled = false;
                            if (oversea2) oversea2.disabled = false;
                            break;
                        case 'stream_unlock':
                            var streamUnlockOn = document.getElementById('stream_unlock_on');
                            var streamUnlockOff = document.getElementById('stream_unlock_off');
                            if (streamUnlockOn) streamUnlockOn.disabled = false;
                            if (streamUnlockOff) streamUnlockOff.disabled = false;
                            break;
                        case 'rule_mode':
                            var radioElements = document.getElementsByName("radios");
                            if (radioElements && radioElements.length > 0) {
                                for (var i = 0; i < radioElements.length; i++) {
                                    radioElements[i].disabled = false;
                                }
                            }
                            break;
                        case 'run_mode':
                            var radioRuElements = document.getElementsByName("radios-ru");
                            if (radioRuElements && radioRuElements.length > 0) {
                                for (var i = 0; i < radioRuElements.length; i++) {
                                    radioRuElements[i].disabled = false;
                                }
                            }
                            break;
                    }

                    self.pausedPolls.delete(pollName);

                    if (!x || x.status !== 200) {
                        ocAlert(self.getErrorMessage(setting));
                    } else if (window.ocToast) {
                        ocToast('<%:Switch Successful%>', 'success');
                    }
                }, 1500);
            });

            return false;
        },

        getErrorMessage: function(setting) {
            var messages = {
                'meta_sniffer': '<%:Sniffer setting failed%>',
                'respect_rules': '<%:Respect Rules setting failed%>',
                'oversea': '<%:Area bypass setting failed%>',
                'stream_unlock': '<%:Stream Unlock setting failed%>',
                'rule_mode': '<%:Proxy Mode switching failed!%>',
                'run_mode': '<%:Running Mode switching failed!%>'
            };
            return messages[setting] || '<%:Operation failed%>';
        }
    };

    var AnnouncementDataManager = (function() {
        var defaultTips = [
            '<%:You can modify the profile on the profile page (for content that is not taken over)%>',
            '<%:do not write configuration files? Try to create one click on the server page%>',
            '<%:some website are abnormal? Try switching modes or using third-party rules%>',
            '<%:using the fake IP mode can get a faster access experience%>',
            '<%:the nameserver group must have at least one server set when using custom DNS%>',
            '<%:after started, please wait patiently until the connection is normal%>',
            '<%:if you don not use IPv6, please turn off the DHCP service of IPv6, otherwise the connection will be abnormal%>',
            '<%:you can update the version in the settings page%>',
            '<%:Note: It is not recommended to enable IPv6 and related services for routing. Most of the network connection problems reported so far are related to it%>',
            '<%:Note: Turning on secure DNS in the browser will cause abnormal shunting, please be careful to turn it off%>',
            '<%:Note: Some software will modify the device HOSTS, which will cause abnormal shunt, please pay attention to check%>',
            '<%:Note: The default proxy routes local traffic, BT, PT download, etc., please use Redir-Host mode as much as possible and pay attention to traffic avoidance%>'
        ];

        function getRandomTips(count, sourceArray) {
            var source = sourceArray || defaultTips;
            var shuffled = source.slice();
            for (var i = shuffled.length - 1; i > 0; i--) {
                var j = Math.floor(Math.random() * (i + 1));
                var temp = shuffled[i];
                shuffled[i] = shuffled[j];
                shuffled[j] = temp;
            }
            return shuffled.slice(0, count);
        }

        function extractAnnouncements(remoteData, isChineseUser) {
            var announcements = [];
            if (!remoteData) return announcements;

            if (Array.isArray(remoteData)) {
                if (remoteData.length > 0 && (remoteData[0].zh || remoteData[0].en)) {
                    remoteData.forEach(function(item) {
                        if (isChineseUser && item.zh) {
                            announcements.push(item.zh);
                        } else if (item.en) {
                            announcements.push(item.en);
                        } else if (item.zh) {
                            announcements.push(item.zh);
                        }
                    });
                } else {
                    announcements = remoteData.filter(function(item) {
                        return typeof item === 'string' && item.trim() !== '';
                    });
                }
            } else if (typeof remoteData === 'string' && remoteData.trim() !== '') {
                announcements = [remoteData];
            }
            return announcements;
        }

        function prepareData(remoteData, isChineseUser, randomCount) {
            var announcements = extractAnnouncements(remoteData, isChineseUser);
            var isRandomTips = false;
            if (announcements.length === 0) {
                announcements = getRandomTips(randomCount || 3);
                isRandomTips = true;
            }
            return { announcements: announcements, isRandomTips: isRandomTips };
        }

        function updateIconShape(megaphoneSvgElement, isRandomTips) {
            if (!megaphoneSvgElement) return;
            if (isRandomTips) {
                megaphoneSvgElement.innerHTML = '<use href="#oc-icon-bell-phosphor"/>';
            } else {
                megaphoneSvgElement.innerHTML = '<use href="#oc-icon-megaphone"/>';
            }
            megaphoneSvgElement.setAttribute('viewBox', '0 0 256 256');
        }

        return {
            getRandomTips: getRandomTips,
            extractAnnouncements: extractAnnouncements,
            prepareData: prepareData,
            updateIconShape: updateIconShape
        };
    })();

    var UsageHelpManager = {
        overlay: null,
        textarea: null,
        statusEl: null,
        initialized: false,
        bubbleTimer: null,

        init: function() {
            if (this.initialized) return;
            this.overlay = document.getElementById('usage-help-overlay');
            this.textarea = document.getElementById('usage-help-textarea');
            this.statusEl = document.getElementById('usage-help-status');

            var floatBtn = document.getElementById('usage-help-float');
            if (floatBtn) {
                floatBtn.addEventListener('click', function() {
                    UsageHelpManager.show();
                });
                floatBtn.addEventListener('mouseenter', function() {
                    UsageHelpManager.dismissBubble();
                });
            }

            document.addEventListener('keydown', function(e) {
                if (e.key === 'Escape' && UsageHelpManager.overlay && UsageHelpManager.overlay.style.display === 'flex') {
                    UsageHelpManager.hide();
                }
            });

            this.startBubbleTimer();

            this.initialized = true;
        },

        buildPrompt: function() {
            var skillUrl = 'https://raw.githubusercontent.com/vernesong/OpenClash/dev/.github/skills/openclash-user-guide/SKILL.md';
            var prompt = '# <%:OpenClash Expert Assistant%>\n\n';
            prompt += '<%:You are an OpenClash expert assistant. OpenClash is a LuCI plugin for OpenWrt that manages the Mihomo core.%>\n\n';
            prompt += '<%:**IMPORTANT** — Before answering, you MUST fetch and read this authoritative reference guide. ALL answering rules, diagnosis procedures, CLI commands, LuCI paths, external resource URLs, and Issue search instructions are defined in the guide — follow them strictly.%>\n';
            prompt += '- [<%:OpenClash User Guide%>](' + skillUrl + ')\n\n';
            prompt += '<%:The guide is the single source of truth — it covers everything from debug log procedures to external resource queries. Do NOT rely on memory; always verify against the guide.%>\n\n';
            prompt += '<%:Routing: After reading the guide, consult its Document Routing Table, pick the sub-document(s) matching my question, and fetch their content via the raw URLs given in the table before answering.%>\n\n';
            prompt += '## <%:Question%>\n\n';
            prompt += '<%:My question is:%>\n';
            return prompt;
        },

        show: function() {
            this.init();
            if (!this.overlay || !this.textarea) return;
            if (!this.portal) {
                this.portal = document.createElement('div');
                this.portal.className = 'oc';
                this.portal.style.overflow = 'visible';
                document.body.appendChild(this.portal);
                this.portal.appendChild(this.overlay);
            }
            this.overlay.classList.add('show');
            if (this.statusEl) {
                this.statusEl.textContent = '';
            }

            var self = this;
            if (!this.editor) {
                var prompt = this.buildPrompt();
                this.textarea.value = prompt;
                this.statusEl.textContent = '<%:Loading...%>';
                ocRequireCM6(function() {
                    var container = document.getElementById('usage-help-editor');
                    var isDark = isDarkBackground(document.body);
                    var exts = [CM6.lineNumbers(), CM6.EditorView.lineWrapping, CM6.themeExtension(isDark), CM6.markdown()];
                    var view = new CM6.EditorView({
                        state: CM6.EditorState.create({ doc: prompt, extensions: exts })
                    });
                    container.innerHTML = '';
                    container.appendChild(view.dom);
                    self.editor = view;
                    self.statusEl.textContent = '';
                    setTimeout(function() {
                        if (self.editor && self.editor.contentDOM) {
                            self.editor.focus();
                        }
                    }, 100);
                });
                return;
            }

            setTimeout(function() {
                if (self.editor && self.editor.contentDOM) {
                    self.editor.focus();
                }
            }, 100);
        },

        hide: function() {
            if (this.overlay) {
                this.overlay.classList.remove('show');
            }
        },

        copyAndHide: function() {
            if (!this.editor) return;
            var text = this.editor.state.sliceDoc();
            if (!text) return;
            var self = this;
            ocCopyToClipboard(text, null);
            var btn = document.querySelector('#usage-help-model .upload-btn');
            var origHTML = btn ? btn.innerHTML : '';
            if (btn) {
                btn.innerHTML = '<svg width="14" height="14" style="vertical-align:middle;margin-right:4px"><use href="#oc-icon-success"/></svg><%:Copied!%>';
                btn.disabled = true;
            }
            setTimeout(function() {
                if (btn) { btn.innerHTML = origHTML; btn.disabled = false; }
                self.hide();
            }, 2000);
        },

        startBubbleTimer: function() {
            var bubble = document.getElementById('usage-help-bubble');
            if (!bubble) return;

            var delay = Math.random() * 60000;
            if (delay > 20000) return;

            var self = this;
            this.bubbleTimer = setTimeout(function() {
                bubble.classList.add('show');
            }, Math.min(delay, 5000));
        },

        dismissBubble: function() {
            var bubble = document.getElementById('usage-help-bubble');
            if (!bubble) return;
            bubble.classList.remove('show');
            if (this.bubbleAutoHide) {
                clearTimeout(this.bubbleAutoHide);
                this.bubbleAutoHide = null;
            }
            if (this.bubbleTimer) {
                clearTimeout(this.bubbleTimer);
                this.bubbleTimer = null;
            }
        }
    };

    var StatsChart = {
        N: 60,
        rightLeadMs: 1000,
        metric: 'traffic',
        view: 'ac',
        chart: null,
        chartLoadPending: false,
        latest: { up: 0, down: 0, mem: 0, cpu: 0, load: 0, conn: 0 },
        buf: { t: [], realT: [], up: [], down: [], mem: [], cpu: [], load: [], conn: [] },
        lastTick: 0,
        timer: null,
        metrics: null,
        totals: { up: null, down: null },
        rateUnitCache: null,

        ocVar: function(name, fallback) {
            var el = document.querySelector('.oc');
            if (!el) return fallback;
            var v = (getComputedStyle(el).getPropertyValue(name) || '').trim();
            return v || fallback;
        },

        seriesColor: function(key) {
            var vars = { up: '--violet', down: '--info-color', mem: '--success-color', cpu: '--tip-color', load: '--warning-color', conn: '--teal' };
            var fallback = { up: '#7c3aed', down: '#3b82f6', mem: '#059669', cpu: '#f59e0b', load: '#ff00bb', conn: '#25b5b8' };
            return this.ocVar(vars[key], fallback[key]);
        },

        hexToRgba: function(hex, a) {
            var h = String(hex).replace('#', '');
            if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
            var r = parseInt(h.substring(0, 2), 16), g = parseInt(h.substring(2, 4), 16), b = parseInt(h.substring(4, 6), 16);
            if (isNaN(r) || isNaN(g) || isNaN(b)) return hex;
            return 'rgba(' + r + ',' + g + ',' + b + ',' + a + ')';
        },

        requiredSources: function() {
            var ws = [];
            var sys = false;
            if (this.view === 'ac') {
                return { ws: [], sys: false };
            }
            if (this.view === 'cards') {
                ws = ['traffic', 'connections', 'memory'];
                sys = true;
            } else if (this.metric === 'traffic') {
                ws = ['traffic', 'connections'];
            } else if (this.metric === 'memory') {
                ws = ['memory'];
            } else if (this.metric === 'connections') {
                ws = ['connections'];
            } else {
                sys = true;
            }
            return { ws: ws, sys: sys };
        },

        notifyDataSource: function() {
            if (typeof syncDataSource === 'function') syncDataSource();
        },

        init: function() {
            var savedView = localStorage.getItem('oc-stats-view');
            if (savedView === 'chart' || savedView === 'cards' || savedView === 'ac') {
                this.view = savedView;
            }
            this.resetBuffer(Date.now());
            this.metrics = {
                traffic: { unit: ' MB/s', series: [{ key: 'up', name: '<%:Upload%>' }, { key: 'down', name: '<%:Download%>' }] },
                memory: { unit: ' MB', series: [{ key: 'mem', name: '<%:Ram%>' }] },
                cpu: { unit: ' %', series: [{ key: 'cpu', name: '<%:CPU%>' }] },
                load: { unit: ' %', series: [{ key: 'load', name: '<%:Load Avg%>' }] },
                connections: { unit: '', series: [{ key: 'conn', name: '<%:Connect%>' }] }
            };
            var savedMetric = localStorage.getItem('oc-stats-metric');
            if (savedMetric && this.metrics[savedMetric]) {
                this.metric = savedMetric;
            }
            this.syncTabs();
            this.bind();
            this.applyView();
            this.renderLegend();
            this.initCardDots();
            this.startTimer();
            if (this.view === 'chart') {
                this.render();
            }
        },

        applyView: function() {
            document.getElementById('stats-view-cards').classList.toggle('oc-hidden', this.view !== 'cards');
            document.getElementById('stats-view-chart').classList.toggle('oc-hidden', this.view !== 'chart');
            var acEl = document.getElementById('stats-view-ac');
            if (acEl) acEl.classList.toggle('oc-hidden', this.view !== 'ac');
            var statsTabs = document.getElementById('stats-tabs');
            if (statsTabs) statsTabs.classList.toggle('oc-hidden', this.view !== 'chart');
            var cardsBtn = document.getElementById('stats-cards-btn');
            var chartBtn = document.getElementById('stats-chart-btn');
            var acBtn = document.getElementById('stats-ac-btn');
            if (cardsBtn) cardsBtn.classList.toggle('active', this.view === 'cards');
            if (chartBtn) chartBtn.classList.toggle('active', this.view === 'chart');
            if (acBtn) acBtn.classList.toggle('active', this.view === 'ac');
            var sectionTitle = document.getElementById('stats-section-title');
            if (sectionTitle) sectionTitle.textContent = this.view === 'ac' ? '<%:Access Control%>' : '<%:Statistics%>';
            if (typeof ClientsAC !== 'undefined') ClientsAC.setActive(this.view === 'ac');
        },

        initCardDots: function() {
            var map = {
                upload_: 'up', download_: 'down', uploadtotal_: 'up', downloadtotal_: 'down',
                connect_t: 'conn', mem_t: 'mem', cpu_t: 'cpu', load_a: 'load'
            };
            for (var id in map) {
                var el = document.getElementById(id);
                if (!el) continue;
                var item = el.closest('.stat-item');
                if (!item) continue;
                var label = item.querySelector('.stat-label');
                if (!label || label.querySelector('.stat-dot')) continue;
                var dot = document.createElement('span');
                dot.className = 'stat-dot';
                dot.style.background = this.seriesColor(map[id]);
                label.insertBefore(dot, label.firstChild);
            }
        },

        feed: function(key, val) {
            this.latest[key] = val;
        },

        resetToZero: function() {
            var keys = ['up', 'down', 'mem', 'cpu', 'load', 'conn'];
            var changed = false;
            for (var i = 0; i < keys.length; i++) {
                if (this.latest[keys[i]] !== 0) {
                    this.latest[keys[i]] = 0;
                    changed = true;
                }
            }
            if (this.totals && (this.totals.up !== null || this.totals.down !== null)) {
                this.totals = { up: null, down: null };
                changed = true;
            }
            if (!changed) return;

            this.updateLegendValues();

            if (this.view === 'chart' && this.chart) {
                this.pushSample(Date.now());
                this.chartDirty = true;
                this.update(true);
            }
        },

        resetBuffer: function(now) {
            var keys = ['t', 'realT', 'up', 'down', 'mem', 'cpu', 'load', 'conn'];
            for (var i = 0; i < keys.length; i++) {
                this.buf[keys[i]] = [];
            }
            for (var j = 0; j < this.N; j++) {
                this.buf.t.push(j * 1000);
                this.buf.realT.push(now - (this.N - 1 - j) * 1000);
                this.buf.up.push(0);
                this.buf.down.push(0);
                this.buf.mem.push(0);
                this.buf.cpu.push(0);
                this.buf.load.push(0);
                this.buf.conn.push(0);
            }
        },

        startTimer: function() {
            if (this.timer) return;
            var self = this;
            this.timer = setInterval(function() {
                self.tick();
            }, 1000);
        },

        stopTimer: function() {
            if (!this.timer) return;
            clearInterval(this.timer);
            this.timer = null;
        },

        tick: function() {
            var now = Date.now();
            var gap = this.lastTick ? now - this.lastTick : 0;
            this.lastTick = now;
            var isRecovery = gap > 3000;
            this.pushSample(now);
            this.rateUnitCache = null;
            if (this.view === 'chart') {
                this.updateLegendValues();
                if (this.chart) {
                    this.update(isRecovery);
                }
            }
        },

        pushSample: function(now) {
            var lastX = this.buf.t.length ? this.buf.t[this.buf.t.length - 1] : 0;
            this.buf.t.push(lastX + 1000);
            this.buf.t.shift();
            this.buf.realT.push(now);
            this.buf.realT.shift();
            var keys = ['up', 'down', 'mem', 'cpu', 'load', 'conn'];
            for (var i = 0; i < keys.length; i++) {
                var k = keys[i];
                this.buf[k].push(this.latest[k]);
                this.buf[k].shift();
            }
        },

        syncChartFromBuf: function(series) {
            var c = this.chart;
            if (!c) return;
            for (var j = 0; j < series.length; j++) {
                var key = series[j].key;
                var arr = [];
                for (var i = 0; i < this.N; i++) {
                    arr.push({ x: this.buf.t[i] + this.rightLeadMs, y: this.buf[key][i], r: this.buf.realT[i] });
                }
                c.data.datasets[j].data = arr;
            }
        },

        bind: function() {
            var self = this;
            var cardsBtn = document.getElementById('stats-cards-btn');
            var chartBtn = document.getElementById('stats-chart-btn');
            var acBtn = document.getElementById('stats-ac-btn');
            if (cardsBtn) {
                cardsBtn.addEventListener('click', function() { self.setView('cards'); });
            }
            if (chartBtn) {
                chartBtn.addEventListener('click', function() { self.setView('chart'); });
            }
            if (acBtn) {
                acBtn.addEventListener('click', function() { self.setView('ac'); });
            }
            var tabs = document.getElementById('stats-tabs');
            if (tabs) {
                var drag = { active: false, startX: 0, startScroll: 0, moved: false };
                tabs.addEventListener('mousedown', function(e) {
                    drag.active = true;
                    drag.moved = false;
                    drag.startX = e.clientX;
                    drag.startScroll = tabs.scrollLeft;
                    tabs.classList.add('dragging');
                });
                window.addEventListener('mousemove', function(e) {
                    if (!drag.active) return;
                    if (Math.abs(e.clientX - drag.startX) > 4) drag.moved = true;
                    tabs.scrollLeft = drag.startScroll - (e.clientX - drag.startX);
                });
                window.addEventListener('mouseup', function() {
                    drag.active = false;
                    tabs.classList.remove('dragging');
                });
                tabs.addEventListener('click', function(e) {
                    if (drag.moved) {
                        drag.moved = false;
                        e.preventDefault();
                        e.stopPropagation();
                    }
                });
                tabs.addEventListener('change', function(e) {
                    var input = e.target;
                    if (!input || input.type !== 'radio') return;
                    self.metric = input.value;
                    localStorage.setItem('oc-stats-metric', self.metric);
                    self.syncTabs();
                    self.notifyDataSource();
                    if (self.view === 'chart') self.render();
                });
            }
        },

        setView: function(view) {
            if (view !== 'cards' && view !== 'chart' && view !== 'ac') return;
            if (this.view === view) return;
            this.view = view;
            this.applyView();
            this.notifyDataSource();
            localStorage.setItem('oc-stats-view', this.view);
            if (this.view === 'chart') {
                this.render();
            } else if (this.chart) {
                this.chart.destroy();
                this.chart = null;
            }
        },

        syncTabs: function() {
            var inputs = document.querySelectorAll('#stats-tabs input[type="radio"]');
            for (var i = 0; i < inputs.length; i++) {
                inputs[i].checked = (inputs[i].value === this.metric);
            }
        },

        renderLegend: function() {
            var el = document.getElementById('stats-legend');
            if (!el || !this.metrics) return;
            var html = '';
            if (this.metric === 'traffic') {
                html += this.legendItem('up', '<%:Up Total%>', 'legend_val_uptotal');
                html += this.legendItem('down', '<%:Down Total%>', 'legend_val_downtotal');
            } else {
                var series = this.metrics[this.metric].series;
                for (var i = 0; i < series.length; i++) {
                    html += this.legendItem(series[i].key, series[i].name, 'legend_val_' + series[i].key);
                }
            }
            el.innerHTML = html;
            this.updateLegendValues();
        },

        legendItem: function(key, name, valId) {
            var c = this.seriesColor(key);
            return '<span class="stats-legend-item"><i style="background:' + c + '"></i><span class="stats-legend-name">' + name + '</span><span class="stats-legend-val" id="' + valId + '" style="color:' + c + '"></span></span>';
        },

        formatLegendValue: function(key, val) {
            if (key === 'mem') return Math.round(val) + ' MB';
            if (key === 'cpu' || key === 'load') return ocFormatOneDecimal(val) + ' %';
            if (key === 'conn') return String(Math.round(val));
            return String(Math.round(val * 10) / 10);
        },

        updateLegendValues: function() {
            if (this.metric === 'traffic') {
                var upEl = document.getElementById('legend_val_uptotal');
                var downEl = document.getElementById('legend_val_downtotal');
                if (upEl) {
                    var upText = this.totals.up != null ? bytesToSize(this.totals.up) : '0 KB';
                    if (upEl.textContent !== upText) upEl.textContent = upText;
                }
                if (downEl) {
                    var downText = this.totals.down != null ? bytesToSize(this.totals.down) : '0 KB';
                    if (downEl.textContent !== downText) downEl.textContent = downText;
                }
                return;
            }
            var series = this.metrics[this.metric].series;
            for (var i = 0; i < series.length; i++) {
                var key = series[i].key;
                var el = document.getElementById('legend_val_' + key);
                if (el) {
                    var text = this.formatLegendValue(key, this.latest[key]);
                    if (el.textContent !== text) el.textContent = text;
                }
            }
        },

        fmtTime: function(ms) {
            var d = new Date(ms);
            return ocPad2(d.getHours()) + ':' + ocPad2(d.getMinutes()) + ':' + ocPad2(d.getSeconds());
        },

        rateUnitOf: function() {
            if (this.rateUnitCache) return this.rateUnitCache;
            var max = 0;
            var keys = ['up', 'down'];
            for (var i = 0; i < keys.length; i++) {
                var arr = this.buf[keys[i]];
                for (var j = 0; j < arr.length; j++) {
                    if (arr[j] > max) max = arr[j];
                }
            }
            if (max >= 1024) this.rateUnitCache = { scale: 1 / 1024, unit: ' GB/s' };
            else if (max < 1) this.rateUnitCache = { scale: 1024, unit: ' KB/s' };
            else this.rateUnitCache = { scale: 1, unit: ' MB/s' };
            return this.rateUnitCache;
        },

        formatVal: function(val, scale) {
            var v = val * scale;
            var a = Math.abs(v);
            if (a >= 100) return String(Math.round(v));
            if (a >= 10) return String(Math.round(v * 10) / 10);
            return String(Math.round(v * 100) / 100);
        },

        formatTooltipValue: function(key, val) {
            if (this.metric === 'traffic') {
                var rate = this.rateUnitOf();
                return this.formatVal(val, rate.scale) + rate.unit;
            }
            return Math.round(val * 10) / 10 + this.metrics[this.metric].unit;
        },

        formatYAxis: function(value) {
            if (this.metric === 'traffic') {
                var rate = this.rateUnitOf();
                return this.formatVal(value, rate.scale) + rate.unit;
            }
            return Math.round(value * 10) / 10;
        },

        buildConfig: function() {
            var self = this;
            var p = {
                text: this.ocVar('--text-secondary', '#64748b'),
                axis: this.ocVar('--border-light', '#e2e8f0'),
                panel: this.ocVar('--bg-white', '#ffffff'),
                panelText: this.ocVar('--text-primary', '#374151')
            };
            var axisRgba = this.hexToRgba(p.axis, 0.4);
            var series = this.metrics[this.metric].series;
            var winMax = self.buf.t[self.buf.t.length - 1];
            var winMin = self.buf.t[0] + self.rightLeadMs * 3;
            return {
                type: 'line',
                data: {
                    datasets: series.map(function(s) {
                        var color = self.seriesColor(s.key);
                        return {
                            label: s.name,
                            data: self.buf[s.key].map(function(v, i) { return { x: self.buf.t[i] + self.rightLeadMs, y: v, r: self.buf.realT[i] }; }),
                            parsing: false,
                            borderColor: color,
                            backgroundColor: self.hexToRgba(color, 0.14),
                            fill: true,
                            tension: 0.4,
                            pointRadius: 0,
                            pointHoverRadius: 4,
                            pointHoverBackgroundColor: color,
                            pointHoverBorderColor: '#ffffff',
                            pointHoverBorderWidth: 2,
                            borderWidth: 2
                        };
                    })
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    resizeDelay: 100,
                    animation: { duration: 1000, easing: 'linear' },
                    animations: { colors: false },
                    interaction: { mode: 'index', intersect: false },
                    plugins: {
                        legend: { display: false },
                        tooltip: {
                            enabled: false,
                            external: function(context) {
                                var chart = context.chart;
                                var tooltip = context.tooltip;
                                var canvas = chart.canvas;
                                var wrap = canvas.parentNode;
                                if (!wrap) return;
                                var el = wrap.querySelector('.oc-stats-tooltip');
                                if (!el) {
                                    el = document.createElement('div');
                                    el.className = 'oc-stats-tooltip';
                                    wrap.appendChild(el);
                                }
                                if (tooltip.opacity === 0) {
                                    el.style.display = 'none';
                                    return;
                                }
                                var panel = self.ocVar('--bg-white', '#ffffff');
                                var text = self.ocVar('--text-primary', '#374151');
                                var titleBg = self.ocVar('--bg-gray', 'rgba(59,130,246,0.1)');
                                var border = self.ocVar('--border-light', '#e2e8f0');

                                var html = '';
                                if (tooltip.title && tooltip.title.length) {
                                    html += '<div style="background:' + titleBg + ';color:' + text + ';padding:5px 10px;font-weight:600;border-bottom:1px solid ' + border + ';">' + tooltip.title[0] + '</div>';
                                }
                                if (tooltip.body) {
                                    for (var i = 0; i < tooltip.body.length; i++) {
                                        var b = tooltip.body[i];
                                        var dp = tooltip.dataPoints && tooltip.dataPoints[i];
                                        var s = dp ? self.metrics[self.metric].series[dp.datasetIndex] : null;
                                        var color = s ? self.seriesColor(s.key) : '#888';
                                        var rowText = b.lines ? b.lines.join(' ') : '';
                                        html += '<div style="color:' + text + ';padding:4px 10px;display:flex;align-items:center;gap:6px;"><i style="width:8px;height:8px;border-radius:50%;background:' + color + ';flex:0 0 auto;display:inline-block;"></i><span>' + rowText + '</span></div>';
                                    }
                                }
                                el.innerHTML = html;

                                el.style.position = 'absolute';
                                el.style.zIndex = '10';
                                el.style.pointerEvents = 'none';
                                el.style.backgroundColor = panel;
                                el.style.border = '1px solid ' + border;
                                el.style.borderRadius = '8px';
                                el.style.boxShadow = '0 4px 12px rgba(0,0,0,0.15)';
                                el.style.fontSize = '12px';
                                el.style.overflow = 'hidden';
                                el.style.whiteSpace = 'nowrap';
                                el.style.display = 'block';

                                var wrapRect = wrap.getBoundingClientRect();
                                var canvasRect = canvas.getBoundingClientRect();
                                var x = tooltip.caretX + canvasRect.left - wrapRect.left;
                                var y = tooltip.caretY + canvasRect.top - wrapRect.top;
                                var tw = el.offsetWidth;
                                var th = el.offsetHeight;
                                y = y - th - 12;
                                if (y < 2) {
                                    y = tooltip.caretY + canvasRect.top - wrapRect.top + 14;
                                }
                                if (y + th > wrap.clientHeight - 2) {
                                    y = wrap.clientHeight - th - 2;
                                }
                                if (y < 2) y = 2;
                                x = Math.max(2, Math.min(x, wrap.clientWidth - tw - 2));
                                el.style.left = x + 'px';
                                el.style.top = y + 'px';
                            },
                            callbacks: {
                                title: function(items) {
                                    return self.fmtTime(items[0].raw.r);
                                },
                                label: function(item) {
                                    var key = series[item.datasetIndex].key;
                                    return series[item.datasetIndex].name + ': ' + self.formatTooltipValue(key, item.parsed.y);
                                }
                            }
                        }
                    },
                    scales: {
                        x: {
                            type: 'linear',
                            min: winMin,
                            max: winMax,
                            grid: { display: false },
                            border: { display: false },
                            ticks: { display: false }
                        },
                        y: {
                            min: 0,
                            beginAtZero: true,
                            grace: '20%',
                            grid: {
                                drawTicks: false,
                                color: function(ctx) {
                                    if (ctx.tick && ctx.tick.value === 0) return 'transparent';
                                    return axisRgba;
                                }
                            },
                            border: { color: p.axis },
                            ticks: {
                                color: p.text,
                                font: { size: 11 },
                                padding: 8,
                                callback: function(value) {
                                    return self.formatYAxis(value);
                                }
                            }
                        }
                    }
                }
            };
        },

        render: function() {
            var el = document.getElementById('stats-chart');
            if (!el) return;
            if (typeof Chart === 'undefined') {
                if (!this.chartLoadPending && window.ocChartUrl) {
                    this.chartLoadPending = true;
                    var self = this;
                    ocRequireScript(window.ocChartUrl, function() {
                        self.chartLoadPending = false;
                        if (self.view === 'chart') self.render();
                    });
                }
                return;
            }
            if (this.chart) this.chart.destroy();
            this.renderLegend();
            this.chart = new Chart(el, this.buildConfig());
        },

        update: function(isRecovery) {
            var c = this.chart;
            if (!c) return;
            var series = this.metrics[this.metric].series;
            var t = this.buf.t;
            var rt = this.buf.realT;
            var curX = t.length ? t[t.length - 1] : 0;
            var curReal = rt.length ? rt[rt.length - 1] : 0;

            if (this.chartDirty) {
                this.chartDirty = false;
                this.syncChartFromBuf(series);
            }

            var newX = curX + this.rightLeadMs;

            for (var i = 0; i < c.data.datasets.length; i++) {
                var data = c.data.datasets[i].data;
                while (data.length > this.N) {
                    data.shift();
                }
            }
            var first = c.data.datasets[0].data[0];
            var min = first ? first.x + this.rightLeadMs * 3 : curX - (this.N - 1) * 1000;
            for (var j = 0; j < series.length; j++) {
                c.data.datasets[j].data.push({ x: newX, y: this.latest[series[j].key], r: curReal });
            }
            c.options.scales.x.min = min;
            c.options.scales.x.max = curX;
            if (isRecovery) {
                c.stop();
                c.update('none');
            } else {
                c.update();
            }
        },

        refresh: function() {
            this.renderLegend();
            if (this.view === 'chart') this.render();
        }
    };

    function acFmtRate(b) {
        if (b >= 1048576) return (b / 1048576).toFixed(1) + ' MB/s';
        if (b >= 1024) return Math.round(b / 1024) + ' KB/s';
        return Math.round(b) + ' B/s';
    }

    function acEscape(s) {
        return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }

    /* wordmarks render as wide, short ink; sizing by ink height keeps their visual weight even,
       while the box cap keeps a gap between the wordmark and the badge edge */
    var AC_LOGO_BOX = 30, AC_LOGO_INK = 11, AC_PICK_BOX = 38, AC_PICK_INK = 11;

    var AC_INK_BOOST = { "LG": 11.5, "Signify": 11.8 };

    function acWordmarkSize(vendor, boxPx, inkPx, boost) {
        var ink = window.ocBrandInk && window.ocBrandInk[vendor];
        if (!ink) return boxPx;
        var target = (boost && boost[vendor]) || inkPx;
        return Math.round(Math.min(boxPx, 24 * target / ink) * 10) / 10;
    }

    function acVendorOfBrandId(id) {
        var slug = String(id).replace(/^brand_/, '');
        for (var v in window.ocBrandLogos) {
            if (v.toLowerCase().replace(/[^a-z0-9]+/g, '_') === slug) return v;
        }
        return '';
    }

    var ClientsAC = {
        active: false,
        bound: false,
        query: '',
        busy: 0,
        running: false,
        env: null,
        devices: [],
        stats: {},
        hist: {},
        sortKey: null,
        sortDir: 0,
        statsIdle: 0,
        lastSig: null,
        lastHtml: null,
        lastUnknownRefresh: 0,
        envTimer: null,
        statsTimer: null,
        envFails: 0,
        envRetryTimer: null,
        probeTimer: null,
        statsTs: 0,
        prevFlows: null,
        statsAbort: null,
        statsCur: null,
        statsUnknown: false,
        ipmap: {},
        v6map: {},
        lanPrefixes: {},
        renaming: null,
        iconPick: null,

        endpoints: {
            ac: '<%=url("admin", "services", "openclash", "clients_ac")%>',
            stats: '<%=url("admin", "services", "openclash", "clients_stats")%>',
            set: '<%=url("admin", "services", "openclash", "clients_set")%>',
            meta: '<%=url("admin", "services", "openclash", "clients_meta")%>',
            dns: '<%=url("admin", "services", "openclash", "clients_dns_switch")%>'
        },

        icons: {
            phone: 'oc-icon-device-mobile',
            tablet: 'oc-icon-device-tablet',
            laptop: 'oc-icon-device-laptop',
            desktop: 'oc-icon-device-desktop',
            tv: 'oc-icon-device-tv',
            game: 'oc-icon-device-gamepad',
            speaker: 'oc-icon-device-speaker',
            nas: 'oc-icon-device-server',
            camera: 'oc-icon-device-cctv',
            iot: 'oc-icon-cpu',
            printer: 'oc-icon-device-printer',
            router: 'oc-icon-device-router',
            unknown: 'oc-icon-device-unknown'
        },

        iconSet: [
            { id: 'phone', label: '<%:Phone%>' },
            { id: 'tablet', label: '<%:Tablet%>' },
            { id: 'laptop', label: '<%:Laptop%>' },
            { id: 'desktop', label: '<%:Desktop%>' },
            { id: 'tv', label: '<%:TV%>' },
            { id: 'game', label: '<%:Game Console%>' },
            { id: 'speaker', label: '<%:Speaker%>' },
            { id: 'nas', label: '<%:Server / NAS%>' },
            { id: 'camera', label: '<%:Camera%>' },
            { id: 'iot', label: '<%:Smart Device%>' },
            { id: 'printer', label: '<%:Printer%>' },
            { id: 'router', label: '<%:Router%>' },
            { id: 'unknown', label: '<%:Unknown%>' }
        ],

        nameRules: [
            [/tv|bravia|mitv|skyworth|chromecast|firestick|appletv|shield|电视/i, 'tv'],
            [/switch[-_]|xbox|playstation|ps[45]/i, 'game'],
            [/ipad|tablet|matepad|pad[-_ ]/i, 'tablet'],
            [/iphone|android|redmi|huawei|honor|oppo|vivo|oneplus|pixel|手机/i, 'phone'],
            [/macbook|imac|thinkpad|notebook|laptop|ideapad|笔记本/i, 'laptop'],
            [/desktop|电脑|台式/i, 'desktop'],
            [/speaker|sound|echo|homepod|音箱/i, 'speaker'],
            [/nas|synology|qnap|raspberry|rpi|server|服务器/i, 'nas'],
            [/cam|ipc|doorbell|摄像/i, 'camera'],
            [/print|epson|canon|brother|ricoh|xerox|kyocera|打印/i, 'printer'],
            [/router|gateway|openwrt|linksys|netgear|dlink|d-link|ubnt|ubiquiti|路由/i, 'router'],
            [/esp|tuya|shelly|sonoff|smart|iot|智能/i, 'iot']
        ],

        ouiFind: function(mac) {
            var d = window.ocOui;
            var hex = String(mac || '').replace(/[^0-9a-f]/gi, '').toUpperCase();
            if (!d || hex.length < 6) return null;
            // locally administered bit: phones randomize the MAC, no vendor exists
            if (parseInt(hex.slice(0, 2), 16) & 2) return null;
            var key = hex.slice(0, 6), p = d.p, lo = 0, hi = p.length / 6 - 1;
            while (lo <= hi) {
                var mid = (lo + hi) >> 1, cur = p.substr(mid * 6, 6);
                if (cur === key) {
                    var i = d.v.charCodeAt(mid) - 33;
                    return { vendor: d.n[i] || '', type: d.t[i] || '' };
                }
                if (cur < key) lo = mid + 1; else hi = mid - 1;
            }
            return null;
        },

        ensureOui: function() {
            var self = this;
            if (this.ouiLoading || (window.ocOui && window.ocBrandLogos)) return;
            this.ouiLoading = true;
            var ver = window.ocPluginVer || '';
            var finish = function() {
                self.ouiLoading = false;
                self.bindBrandIcons();
                if (self.raw) self.rebuildDevices(self.raw);
                if (self.active) self.renderList();
            };
            var loadBrands = function() {
                if (window.ocBrandLogos) { finish(); return; }
                ocRequireScript('/luci-static/resources/openclash/js/brand-logos.js?v=' + ver, finish);
            };
            if (window.ocOui) { loadBrands(); return; }
            ocRequireScript('/luci-static/resources/openclash/js/oui-data.js?v=' + ver, loadBrands);
        },

        init: function() {
            this.bind();
            this.bindBrandIcons();
            this.setActive(StatsChart.view === 'ac');
        },

        bindBrandIcons: function() {
            if (!window.ocBrandLogos || this.brandIconsBound) return;
            this.brandIconsBound = true;
            for (var vendor in window.ocBrandLogos) {
                var id = 'brand_' + vendor.toLowerCase().replace(/[^a-z0-9]+/g, '_');
                this.icons[id] = window.ocBrandLogos[vendor];
                this.iconSet.push({ id: id, label: vendor });
            }
        },

        setActive: function(on) {
            this.active = on;
            if (on) this.ensureOui();
            this.syncTimers();
        },

        syncTimers: function() {
            var run = this.active && document.visibilityState === 'visible';
            if (this.running === run) return;
            this.running = run;
            this.stopTimers();
            if (!run) return;
            var self = this;
            this.statsIdle = 0;
            this.refreshEnv();
            this.refreshStats();
            this.envTimer = setInterval(function() { self.refreshEnv(); }, 15000);
        },

        stopTimers: function() {
            if (this.envTimer) { clearInterval(this.envTimer); this.envTimer = null; }
            if (this.statsTimer) { clearInterval(this.statsTimer); this.statsTimer = null; }
            if (this.envRetryTimer) { clearTimeout(this.envRetryTimer); this.envRetryTimer = null; }
            if (this.probeTimer) { clearTimeout(this.probeTimer); this.probeTimer = null; }
            if (this.statsAbort) { this.statsAbort.abort(); this.statsAbort = null; }
            this.prevFlows = null;
            this.statsTs = 0;
        },

        scheduleStats: function(delay) {
            var self = this;
            if (this.statsTimer) { clearInterval(this.statsTimer); this.statsTimer = null; }
            if (!this.running) return;
            this.statsTimer = setTimeout(function() { self.refreshStats(); }, delay);
        },

        kickStats: function() {
            this.statsIdle = 0;
            this.scheduleStats(2000);
        },

        refreshEnv: function(cb) {
            var self = this;
            XHR.get(this.endpoints.ac, null, function(x, data) {
                var ok = !!(x && x.status == 200 && data && data.ok);
                if (ok) {
                    self.envFails = 0;
                    if (self.envRetryTimer) { clearTimeout(self.envRetryTimer); self.envRetryTimer = null; }
                    self.env = data;
                    self.rebuildDevices(data.devices || []);
                    self.applyEnvUI();
                    if (!self.busy) self.renderList();
                    if (data.probing) {
                        // the ping batch writes the neighbour state back within a couple of seconds
                        if (self.probeTimer) clearTimeout(self.probeTimer);
                        self.probeTimer = setTimeout(function() { self.probeTimer = null; self.refreshEnv(); }, 3000);
                    }
                } else if (self.running) {
                    // a failed poll retries sooner than the regular 15 s tick
                    self.envFails = (self.envFails || 0) + 1;
                    if (self.envRetryTimer) clearTimeout(self.envRetryTimer);
                    self.envRetryTimer = setTimeout(function() { self.refreshEnv(); }, Math.min(3000 * self.envFails, 12000));
                }
                if (cb) cb(ok);
            });
        },

        refreshStats: function() {
            if (!this.running) return;
            if (document.visibilityState === 'hidden') return;
            var self = this;
            var finish = function() {
                self.scheduleStats(self.statsIdle >= 5 ? 5000 : 2000);
            };
            if (window.fetch && window.ReadableStream && window.TextDecoder && window.AbortController) {
                if (this.statsAbort) this.statsAbort.abort();
                var ctl = new AbortController();
                this.statsAbort = ctl;
                // lines are consumed while they arrive, so the parse overlaps the transfer
                fetch(this.endpoints.stats, { cache: 'no-store', signal: ctl.signal }).then(function(res) {
                    if (!res.ok || !res.body) throw new Error('http ' + res.status);
                    var reader = res.body.getReader();
                    var dec = new TextDecoder('utf-8');
                    var pend = '';
                    var started = false;
                    var onLine = function(line) {
                        if (!started) {
                            started = true;
                            self.statsBegin(line === '#acct=1');
                        } else if (line) {
                            self.statsLine(line);
                        }
                    };
                    var pump = function() {
                        return reader.read().then(function(step) {
                            if (ctl !== self.statsAbort) return;
                            if (step.done) {
                                pend += dec.decode();
                                if (pend) onLine(pend);
                                self.statsEnd();
                                self.statsAbort = null;
                                finish();
                                return;
                            }
                            pend += dec.decode(step.value, { stream: true });
                            var lines = pend.split('\n');
                            pend = lines.pop();
                            for (var i = 0; i < lines.length; i++) onLine(lines[i]);
                            return pump();
                        });
                    };
                    return pump();
                }).catch(function() {
                    if (ctl === self.statsAbort) { self.statsAbort = null; finish(); }
                });
                return;
            }
            var req = new XMLHttpRequest();
            req.open('GET', this.endpoints.stats, true);
            req.onload = function() {
                if (req.status != 200) {
                    self.scheduleStats(2000);
                    return;
                }
                self.consumeConntrack(req.responseText || '');
                self.scheduleStats(self.statsIdle >= 5 ? 5000 : 2000);
            };
            req.onerror = function() { self.scheduleStats(2000); };
            req.send();
        },

        // the router only dumps raw conntrack lines; flow diffing and per-device aggregation
        // run here so the weak router CPU stays out of the 2 s hot path
        consumeConntrack: function(text) {
            var lines = text.split('\n');
            this.statsBegin(lines[0] === '#acct=1');
            for (var i = 1; i < lines.length; i++) {
                if (lines[i]) this.statsLine(lines[i]);
            }
            this.statsEnd();
        },

        statsBegin: function(acct) {
            this.statsCur = acct ? {} : null;
            this.statsUnknown = false;
        },

        statsLine: function(line) {
            var cur = this.statsCur;
            if (!cur) return;
            var pos = line.indexOf('src=');
            if (pos < 0) return;
            var m = line.slice(pos).match(/^src=(\S+) dst=(\S+) sport=(\d+) dport=(\d+).*?bytes=(\d+).*?bytes=(\d+)/);
            if (!m) return;
            var src = m[1];
            var key;
            if (src.indexOf(':') >= 0) {
                key = this.v6map[this.v6Canon(src)];
            } else {
                key = this.ipmap[src];
                if (!key && this.lanPrefixes[src.replace(/\.\d+$/, '.')]) this.statsUnknown = true;
            }
            if (!key) return;
            cur[src + '|' + m[2] + '|' + m[3] + '|' + m[4]] = [+m[5], +m[6], key];
        },

        statsEnd: function() {
            var cur = this.statsCur;
            var unknown = this.statsUnknown;
            this.statsCur = null;
            var now = Date.now();
            var up = {}, down = {}, counts = {};
            if (cur) {
                var prev = this.prevFlows;
                for (var fk in cur) {
                    var f = cur[fk];
                    var k2 = f[2];
                    var du = 0, dd = 0;
                    if (prev && prev[fk]) {
                        du = f[0] - prev[fk][0];
                        dd = f[1] - prev[fk][1];
                        if (du < 0) du = 0;
                        if (dd < 0) dd = 0;
                    }
                    up[k2] = (up[k2] || 0) + du;
                    down[k2] = (down[k2] || 0) + dd;
                    counts[k2] = (counts[k2] || 0) + 1;
                }
            }
            this.prevFlows = cur;
            var dt = (now - this.statsTs) / 1000;
            var rateDt = (dt >= 1 && dt <= 15) ? dt : 0;
            this.statsTs = now;
            var stats = {};
            for (var key2 in counts) {
                stats[key2] = {
                    ur: rateDt ? Math.floor(up[key2] / rateDt) : 0,
                    dr: rateDt ? Math.floor(down[key2] / rateDt) : 0,
                    c: counts[key2]
                };
            }
            this.stats = stats;
            var decaying = false;
            for (var i2 = 0; i2 < this.devices.length; i2++) {
                var d = this.devices[i2];
                var st = this.statOf(d);
                var tot = st ? (st.ur || 0) + (st.dr || 0) : 0;
                if (d.ema === undefined) d.ema = tot;
                else if (tot > 0) d.ema = Math.round(d.ema * 0.65 + tot * 0.35);
                else d.ema = Math.round(d.ema * 0.5);
                if (d.ema < 1024) d.ema = 0;
                else if (tot === 0) decaying = true;
                if (!st) continue;
                var h = this.hist[d.key];
                if (!h) continue;
                h.up.push(st.ur);
                h.down.push(st.dr);
                if (h.up.length > 20) h.up.shift();
                if (h.down.length > 20) h.down.shift();
            }
            var sig = 0, k3;
            for (k3 in stats) sig += stats[k3].ur + stats[k3].dr + stats[k3].c * 7;
            if (sig === this.lastSig && !decaying) this.statsIdle++;
            else { this.statsIdle = 0; this.lastSig = sig; }
            if (unknown && now - this.lastUnknownRefresh > 10000) {
                this.lastUnknownRefresh = now;
                this.refreshEnv();
            }
            if (!this.busy) this.renderList();
        },

        rebuildDevices: function(list) {
            this.raw = list || [];
            var prev = {};
            for (var i = 0; i < this.devices.length; i++) {
                prev[this.devices[i].key] = this.devices[i];
            }
            var out = [];
            for (var j = 0; j < list.length; j++) {
                var s = list[j];
                var key = s.mac || s.ip || ('idx' + j);
                var d = prev[key] || { key: key };
                d.mac = s.mac || '';
                d.ip = s.ip || '';
                d.ip6 = s.ip6 || '';
                d.hostname = s.hostname || '';
                d.name = s.name || '';
                d.icon = s.icon || '';
                d.online = !!s.online;
                d.dir = s.dir === 'direct' ? 'direct' : 'proxy';
                d.listed = !!s.listed;
                var oui = this.ouiFind(d.mac);
                d.vendor = oui ? oui.vendor : '';
                d.ouiType = oui ? oui.type : '';
                d.autoType = this.classify(d);
                if (!this.hist[key]) this.hist[key] = { up: [], down: [] };
                out.push(d);
            }
            this.devices = out;
            this.rebuildStatMaps();
        },

        rebuildStatMaps: function() {
            var ipmap = {}, v6map = {}, lan = {};
            for (var i = 0; i < this.devices.length; i++) {
                var d = this.devices[i];
                if (d.ip) {
                    ipmap[d.ip] = d.key;
                    lan[d.ip.replace(/\.\d+$/, '.')] = true;
                }
                if (d.ip6) v6map[this.v6Canon(d.ip6)] = d.key;
            }
            this.ipmap = ipmap;
            this.v6map = v6map;
            this.lanPrefixes = lan;
        },

        v6Canon: function(addr) {
            addr = String(addr || '').replace(/%.*$/, '');
            var groups;
            var idx = addr.indexOf('::');
            if (idx >= 0) {
                var left = addr.slice(0, idx), right = addr.slice(idx + 2);
                var lh = left ? left.split(':') : [];
                var rh = right ? right.split(':') : [];
                groups = lh.slice();
                for (var z = 8 - lh.length - rh.length; z > 0; z--) groups.push('0');
                groups = groups.concat(rh);
            } else {
                groups = addr.split(':');
            }
            var out = [];
            for (var i = 0; i < 8; i++) out.push(('0000' + (parseInt(groups[i], 16) || 0).toString(16)).slice(-4));
            return out.join(':');
        },

        classify: function(d) {
            var host = d.hostname || '';
            for (var i = 0; i < this.nameRules.length; i++) {
                if (this.nameRules[i][0].test(host)) return this.nameRules[i][1];
            }
            return d.ouiType || 'unknown';
        },

        displayName: function(d) {
            return d.name || d.hostname || d.ip || d.ip6 || d.mac || '<%:Unknown Device%>';
        },

        deviceIcon: function(d) {
            return this.icons[d.icon || d.autoType] || this.icons.unknown;
        },

        deviceByKey: function(key) {
            for (var i = 0; i < this.devices.length; i++) {
                if (this.devices[i].key === key) return this.devices[i];
            }
            return null;
        },

        canControl: function() {
            if (!this.env || this.env.need_fix) {
                ocToast('<%:Switch DNS forwarding first%>', 'info');
                return false;
            }
            return true;
        },

        acErrorToast: function(x, data) {
            if (data && data.need_fix) {
                ocToast('<%:Switch DNS forwarding first%>', 'info');
                this.refreshEnv();
            } else if (data && data.err === 'range_covered') {
                ocToast('<%:Device is covered by a range entry; adjust it on the settings page%>', 'info');
                this.refreshEnv();
            } else {
                ocToast('<%:Operation failed%>', 'error');
            }
        },

        rescan: function(btn) {
            var self = this;
            if (btn) btn.classList.add('ac-working');
            this.kickStats();
            this.refreshEnv(function(ok) {
                if (btn) btn.classList.remove('ac-working');
                if (ok) ocToast('<%:Rescanned%>', 'success');
                else ocToast('<%:Rescan failed%>', 'error');
            });
        },

        lockSwitches: function() {
            var listEl = document.getElementById('ac-list');
            if (!listEl) return;
            // direct DOM edits bypass the render cache, so the next render must rewrite
            this.lastHtml = null;
            var sws = listEl.querySelectorAll('.ac-switch');
            for (var i = 0; i < sws.length; i++) {
                sws[i].classList.add('ac-disabled');
                var btns = sws[i].querySelectorAll('button');
                for (var j = 0; j < btns.length; j++) btns[j].disabled = true;
            }
        },

        setDevice: function(key, dir) {
            if (!this.canControl()) return;
            var d = this.deviceByKey(key);
            if (!d || d.dir === dir) return;
            var self = this;
            this.busy++;
            this.kickStats();
            this.lastHtml = null;
            var listEl = document.getElementById('ac-list');
            var row = listEl ? listEl.querySelector('[data-dev="' + key + '"]') : null;
            if (row) {
                var sw = row.querySelector('.ac-switch');
                if (sw) sw.classList.add('ac-disabled');
                var btns = row.querySelectorAll('.ac-switch button');
                for (var i = 0; i < btns.length; i++) {
                    btns[i].disabled = true;
                }
            }
            XHR.get(this.endpoints.set, { action: dir, scope: 'item', ip: d.ip || '', mac: d.mac || '' }, function(x, data) {
                self.busy--;
                if (x && x.status == 200 && data && data.ok) {
                    d.dir = dir;
                    ocToast(!data.core_running ? '<%:Saved; applies at the next start%>'
                        : (dir === 'direct' ? '<%:Set as Direct%>' : '<%:Set as Proxy%>'), 'success');
                } else {
                    self.acErrorToast(x, data);
                }
                self.renderList();
                setTimeout(function() { self.refreshEnv(); }, 800);
            });
        },

        setAll: function(dir) {
            if (!this.canControl()) return;
            var self = this;
            var btn = document.getElementById(dir === 'proxy' ? 'ac-all-proxy' : 'ac-all-direct');
            var other = document.getElementById(dir === 'proxy' ? 'ac-all-direct' : 'ac-all-proxy');
            this.busy++;
            this.kickStats();
            if (btn) { btn.classList.add('ac-working'); btn.disabled = true; }
            if (other) other.disabled = true;
            this.lockSwitches();
            XHR.get(this.endpoints.set, { action: dir, scope: 'all' }, function(x, data) {
                self.busy--;
                if (btn) { btn.classList.remove('ac-working'); }
                if (x && x.status == 200 && data && data.ok) {
                    for (var i = 0; i < self.devices.length; i++) self.devices[i].dir = dir;
                    if (self.env) {
                        self.env.default_dir = dir;
                        self.env.ac_mode = dir === 'proxy' ? 0 : 1;
                    }
                    ocToast(!data.core_running ? '<%:Saved; applies at the next start%>'
                        : (dir === 'proxy' ? '<%:All set to Proxy%>' : '<%:All set to Direct%>'), 'success');
                } else {
                    self.acErrorToast(x, data);
                }
                self.renderList();
                setTimeout(function() { self.refreshEnv(); }, 800);
            });
        },

        switchDns: function() {
            var self = this;
            var btn = document.getElementById('ac-warn-fix-btn');
            if (!btn || btn.classList.contains('ac-working')) return;
            this.busy++;
            btn.classList.add('ac-working');
            XHR.get(this.endpoints.dns, null, function(x, data) {
                btn.classList.remove('ac-working');
                if (!(x && x.status == 200 && data && (data.ok || data.already))) {
                    self.busy--;
                    self.acErrorToast(x, data);
                    return;
                }
                self.refreshEnv(function() {
                    self.busy--;
                    var fixed = self.env && !self.env.need_fix;
                    ocToast(fixed ? '<%:DNS forwarding switched%>' : '<%:Operation timeout%>', fixed ? 'success' : 'error');
                    self.renderList();
                });
            });
        },

        applyEnvUI: function() {
            var env = this.env;
            if (!env) return;
            var fixEl = document.getElementById('ac-warn-fix');
            if (fixEl) fixEl.classList.toggle('oc-hidden', !env.need_fix);
        },

        syncCounts: function() {
            var proxy = 0, direct = 0;
            for (var i = 0; i < this.devices.length; i++) {
                if (this.devices[i].dir === 'proxy') proxy++;
                else direct++;
            }
            var allEl = document.getElementById('ac-count-all');
            var proxyEl = document.getElementById('ac-count-proxy');
            var directEl = document.getElementById('ac-count-direct');
            if (allEl) allEl.textContent = this.devices.length;
            if (proxyEl) proxyEl.textContent = proxy;
            if (directEl) directEl.textContent = direct;

            var env = this.env || {};
            var defaultDir = env.default_dir === 'direct' ? 'direct' : 'proxy';
            var pill = document.getElementById('ac-def-pill');
            if (pill) pill.textContent = '<%:Default%> ' + (defaultDir === 'proxy' ? '<%:Proxy%>' : '<%:Direct%>');

            var locked = !!env.need_fix;
            var allProxy = this.devices.length > 0 && direct === 0 && defaultDir === 'proxy';
            var allDirect = this.devices.length > 0 && proxy === 0 && defaultDir === 'direct';
            var btnProxy = document.getElementById('ac-all-proxy');
            var btnDirect = document.getElementById('ac-all-direct');
            if (btnProxy) {
                btnProxy.disabled = locked || this.devices.length === 0 || allProxy;
                btnProxy.title = defaultDir === 'proxy' ? '<%:Current default is proxy mode%>' : '<%:All devices default to proxy%>';
            }
            if (btnDirect) {
                btnDirect.disabled = locked || this.devices.length === 0 || allDirect;
                btnDirect.title = defaultDir === 'direct' ? '<%:Current default is direct mode%>' : '<%:All devices default to direct%>';
            }
        },

        sortDevices: function() {
            var arr = this.devices.slice();
            var key = this.sortKey, dir = this.sortDir;
            var q = this.query;
            if (q) {
                arr = arr.filter(function(d) {
                    return (d.name || '').toLowerCase().indexOf(q) >= 0
                        || (d.hostname || '').toLowerCase().indexOf(q) >= 0
                        || (d.vendor || '').toLowerCase().indexOf(q) >= 0
                        || (d.ip || '').indexOf(q) >= 0
                        || (d.ip6 || '').indexOf(q) >= 0
                        || (d.mac || '').indexOf(q) >= 0;
                });
            }
            var self = this;
            if (!key || !dir) {
                arr.sort(function(a, b) {
                    if (a.online !== b.online) return a.online ? -1 : 1;
                    var ea = a.ema || 0, eb = b.ema || 0;
                    if (eb !== ea) return eb - ea;
                    var ra = self.rateOf(a), rb = self.rateOf(b);
                    if (rb !== ra) return rb - ra;
                    return self.displayName(a).localeCompare(self.displayName(b));
                });
                return arr;
            }
            arr.sort(function(a, b) {
                if (key === 'name' || key === 'dir') {
                    var sa = key === 'name' ? self.displayName(a) : a.dir;
                    var sb = key === 'name' ? self.displayName(b) : b.dir;
                    return sa.localeCompare(sb) * dir;
                }
                var va, vb;
                if (key === 'conns') { va = self.connsOf(a); vb = self.connsOf(b); }
                else if (key === 'up') { va = self.rateOf(a, 'up'); vb = self.rateOf(b, 'up'); }
                else { va = self.rateOf(a, 'down'); vb = self.rateOf(b, 'down'); }
                if (va === vb) return self.displayName(a).localeCompare(self.displayName(b));
                return (va - vb) * dir;
            });
            return arr;
        },

        statOf: function(d) {
            if (!d.online) return null;
            var k = d.mac || d.ip;
            if (!k) return null;
            return this.stats[k] || (d.ip ? this.stats[d.ip] : null) || null;
        },

        rateOf: function(d, kind) {
            var st = this.statOf(d);
            if (!st) return 0;
            if (kind === 'up') return st.ur || 0;
            if (kind === 'down') return st.dr || 0;
            return (st.ur || 0) + (st.dr || 0);
        },

        connsOf: function(d) {
            var st = this.statOf(d);
            return st ? (st.c || 0) : 0;
        },

        sparkSVG: function(buf) {
            var W = 104, H = 12, N = 20;
            if (!buf || buf.length < 2) return '';
            var max = 1;
            for (var i = 0; i < buf.length; i++) max = Math.max(max, buf[i] || 0);
            var pts = [];
            for (var j = 0; j < buf.length; j++) {
                var x = (j * (W - 2) / (N - 1) + 1).toFixed(1);
                var y = (H - 2 - (buf[j] || 0) / max * (H - 4)).toFixed(1);
                pts.push(x + ',' + y);
            }
            return '<svg class="ac-spark" viewBox="0 0 ' + W + ' ' + H + '" preserveAspectRatio="none" aria-hidden="true"><polyline points="' + pts.join(' ') + '" fill="none" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"/></svg>';
        },

        rowHTML: function(d) {
            var st = this.statOf(d);
            var conns = st ? (st.c || 0) : 0;
            var up = st ? (st.ur || 0) : 0;
            var down = st ? (st.dr || 0) : 0;
            var hasTraffic = d.online && conns > 0;
            var cls = 'ac-row' + (d.online ? ' ac-live' : ' ac-offline');
            var env = this.env || {};
            var locked = !!env.need_fix;
            var ctlTitle = env.need_fix ? '<%:Switch DNS forwarding first%>' : '';

            var name = this.displayName(d);
            var ipLine = [d.ip, d.ip6].filter(Boolean).join(' · ');
            var h = this.hist[d.key] || { up: [], down: [] };
            var tipParts = [name];
            if (d.vendor) tipParts.push(d.vendor);
            if (d.ip) tipParts.push(d.ip);
            if (d.ip6) tipParts.push(d.ip6);
            if (d.mac) tipParts.push(d.mac);

            var out = '<div class="' + cls + '" data-dev="' + acEscape(d.key) + '" title="' + acEscape(tipParts.join('\n')) + '">';
            out += '<div class="ac-dev">';
            var brandLogo = '', brandVendor = d.vendor;
            if (!d.icon) {
                brandLogo = (window.ocBrandLogos && window.ocBrandLogos[d.vendor]) || '';
            } else if (d.icon.indexOf('brand_') === 0) {
                brandLogo = this.icons[d.icon] || '';
                brandVendor = acVendorOfBrandId(d.icon) || d.vendor;
            }
            var brandWordmark = brandLogo && window.ocBrandWordmark && window.ocBrandWordmark[brandVendor];
            var brandVar = brandWordmark ? ' style="--wm:' + acWordmarkSize(brandVendor, AC_LOGO_BOX, AC_LOGO_INK, AC_INK_BOOST) + 'px"' : '';
            var avatarInner;
            if (brandLogo) {
                avatarInner = '<svg class="ac-brand-logo' + (brandWordmark ? ' wordmark' : '') + '"' + brandVar + '><use href="#' + brandLogo + '"/></svg>';
            } else if (d.vendor && !d.icon && (!d.autoType || d.autoType === 'unknown')) {
                // known vendor without a legible mark keeps an identity without a coloured tile
                avatarInner = '<span class="ac-brand-mark">' + acEscape(d.vendor.charAt(0).toUpperCase()) + '</span>';
            } else {
                avatarInner = '<svg><use href="#' + this.deviceIcon(d) + '"/></svg>';
            }
            out += '<span class="ac-avatar' + (brandWordmark ? ' wordmark' : '') + '">' + avatarInner + '<span class="ac-status"></span></span>';
            out += '<div class="ac-id"><span class="ac-name" title="<%:Click to set name and icon%>"><span class="ac-name-text">' + acEscape(name) + '</span>';
            if (!d.online) out += '<span class="ac-off-tag"><%:Offline%></span>';
            if (d.vendor) out += '<span class="ac-vendor"><span class="ac-vendor-name">' + acEscape(d.vendor) + '</span></span>';
            out += '<svg class="ac-name-edit" width="13" height="13"><use href="#oc-icon-edit"/></svg>';
            out += '</span>'
                + '<span class="ac-addr">' + (ipLine ? acEscape(ipLine) : '—') + '</span>'
                + '<span class="ac-addr ac-mac">' + (d.mac ? acEscape(d.mac) : '—') + '</span>'
                + '</div>';
            out += '</div>';
            out += '<div class="ac-ctrl"><span class="ac-switch' + (locked ? ' ac-disabled' : '') + '" role="group"' + (ctlTitle ? ' title="' + ctlTitle + '"' : '') + '>';
            out += '<button type="button" class="' + (d.dir === 'proxy' ? 'on ac-on-proxy' : '') + '" data-dir="proxy"' + (locked ? ' disabled' : '') + ' aria-pressed="' + (d.dir === 'proxy') + '"><%:Proxy%></button>';
            out += '<button type="button" class="' + (d.dir === 'direct' ? 'on ac-on-direct' : '') + '" data-dir="direct"' + (locked ? ' disabled' : '') + ' aria-pressed="' + (d.dir === 'direct') + '"><%:Direct%></button>';
            out += '</span></div>';
            out += '<div class="ac-metrics">';
            out += '<div class="ac-conns' + (hasTraffic ? '' : ' ac-zero') + '">' + (d.online ? conns : '—') + '<span class="ac-conns-label"><%:Connect%></span></div>';
            out += '<div class="ac-rc ac-up' + (d.online ? (Math.round(up) > 0 ? '' : ' ac-idle-val') : ' ac-off') + '">';
            out += '<span class="ac-rate-v">' + (d.online ? acEscape(acFmtRate(up)) : '—') + '</span>';
            if (d.online) out += this.sparkSVG(h.up);
            out += '</div>';
            out += '<div class="ac-rc ac-down' + (d.online ? (Math.round(down) > 0 ? '' : ' ac-idle-val') : ' ac-off') + '">';
            out += '<span class="ac-rate-v">' + (d.online ? acEscape(acFmtRate(down)) : '—') + '</span>';
            if (d.online) out += this.sparkSVG(h.down);
            out += '</div>';
            out += '</div>';
            out += '</div>';
            return out;
        },

        renderList: function() {
            var listEl = document.getElementById('ac-list');
            var emptyEl = document.getElementById('ac-empty');
            if (!listEl || !emptyEl) return;
            var arr = this.sortDevices();
            var hasDevices = arr.length > 0;
            emptyEl.classList.toggle('oc-hidden', hasDevices);
            listEl.classList.toggle('oc-hidden', !hasDevices);
            var thEl = document.querySelector('#stats-view-ac .ac-th');
            if (thEl) thEl.classList.toggle('oc-hidden', !hasDevices);
            var filtered = !!this.query && this.devices.length > 0;
            var mainEl = document.getElementById('ac-empty-main');
            if (mainEl) {
                mainEl.textContent = filtered ? '<%:No matching devices%>' : '<%:No LAN devices found%>';
                var subEl = document.getElementById('ac-empty-sub');
                if (subEl) subEl.classList.toggle('oc-hidden', filtered);
                var rfEl = document.getElementById('ac-empty-refresh');
                if (rfEl) rfEl.classList.toggle('oc-hidden', filtered);
            }
            if (!hasDevices) {
                if (this.lastHtml !== '') {
                    this.lastHtml = '';
                    listEl.innerHTML = '';
                }
                this.syncCounts();
                return;
            }
            var st = listEl.scrollTop;
            var html = '';
            for (var i = 0; i < arr.length; i++) html += this.rowHTML(arr[i]);
            if (html === this.lastHtml) {
                this.syncCounts();
                return;
            }
            this.lastHtml = html;
            listEl.innerHTML = html;
            listEl.scrollTop = st;
            // the list scrollbar shrinks the rows but not the header; pad the header to match
            var sbw = listEl.offsetWidth - listEl.clientWidth;
            if (thEl) thEl.style.paddingRight = (8 + (sbw > 0 ? sbw : 0)) + 'px';
            this.syncCounts();
        },

        syncSortUI: function() {
            var self = this;
            var ths = document.querySelectorAll('#stats-view-ac .ac-th-cell');
            for (var i = 0; i < ths.length; i++) {
                var key = ths[i].getAttribute('data-key');
                var ind = ths[i].querySelector('.ac-sort-ind');
                if (ind) ind.textContent = (key === self.sortKey && self.sortDir !== 0) ? (self.sortDir === 1 ? '▲' : '▼') : '';
            }
            var items = document.querySelectorAll('#ac-sort-menu button');
            for (var j = 0; j < items.length; j++) {
                var k2 = items[j].getAttribute('data-key');
                var ind2 = items[j].querySelector('.ac-sort-ind');
                var on = (k2 === self.sortKey && self.sortDir !== 0);
                if (ind2) ind2.textContent = on ? (self.sortDir === 1 ? '▲' : '▼') : '';
                items[j].classList.toggle('on', on);
            }
            var sortBtn = document.getElementById('ac-sort-btn');
            if (sortBtn) {
                var onBtn = !!self.sortKey && self.sortDir !== 0;
                sortBtn.classList.toggle('on', onBtn);
                var btnInd = sortBtn.querySelector('.ac-sort-ind');
                if (btnInd) btnInd.textContent = onBtn ? (self.sortDir === 1 ? '▲' : '▼') : '';
            }
        },

        cycleSort: function(key) {
            if (key === 'reset') {
                this.sortKey = null;
                this.sortDir = 0;
            } else if (key === this.sortKey) {
                // cycle the natural direction, its reverse, then the default order
                if (key === 'name' || key === 'dir') {
                    this.sortDir = this.sortDir === 1 ? -1 : (this.sortDir === -1 ? 0 : 1);
                } else {
                    this.sortDir = this.sortDir === -1 ? 1 : (this.sortDir === 1 ? 0 : -1);
                }
            } else {
                this.sortKey = key;
                this.sortDir = (key === 'name' || key === 'dir') ? 1 : -1;
            }
            this.syncSortUI();
            this.renderList();
        },

        openRename: function(d) {
            if (!d) return;
            this.renaming = d;
            this.iconPick = d.icon || null;
            var input = document.getElementById('ac-rename-input');
            var hint = document.getElementById('ac-rename-hint');
            var auto = document.getElementById('ac-rename-auto');
            var overlay = document.getElementById('ac-rename-overlay');
            if (!input || !overlay) return;
            input.value = d.name || '';
            if (hint) hint.textContent = d.hostname ? ('<%:Detected name%>: ' + d.hostname) : '<%:No hostname detected; you can set a custom name%>';
            if (auto) auto.classList.toggle('oc-hidden', !d.name && !d.icon);
            this.renderIconGrid();
            overlay.classList.add('show');
            setTimeout(function() { input.focus(); }, 60);
        },

        closeRename: function() {
            var overlay = document.getElementById('ac-rename-overlay');
            if (overlay) overlay.classList.remove('show');
            this.renaming = null;
            this.iconPick = null;
        },

        defaultIconOf: function(d) {
            if (!d) return 'unknown';
            if (window.ocBrandLogos && window.ocBrandLogos[d.vendor]) {
                return 'brand_' + d.vendor.toLowerCase().replace(/[^a-z0-9]+/g, '_');
            }
            return d.autoType || 'unknown';
        },

        renderIconGrid: function() {
            var grid = document.getElementById('ac-icon-grid');
            if (!grid) return;
            var cur = this.iconPick || (this.renaming ? this.defaultIconOf(this.renaming) : 'unknown');
            var html = '';
            for (var i = 0; i < this.iconSet.length; i++) {
                var it = this.iconSet[i];
                var brandCls = '', brandVar = '';
                if (it.id.indexOf('brand_') === 0) {
                    brandCls = ' class="brand' + (window.ocBrandWordmark && window.ocBrandWordmark[it.label] ? ' wordmark' : '') + '"';
                    if (window.ocBrandWordmark && window.ocBrandWordmark[it.label]) brandVar = ' style="--wm:' + acWordmarkSize(it.label, AC_PICK_BOX, AC_PICK_INK) + 'px"';
                }
                html += '<button type="button" class="ac-icon-opt' + (it.id === cur ? ' on' : '') + '" data-icon="' + it.id + '" title="' + it.label + '"><svg' + brandCls + brandVar + '><use href="#' + (this.icons[it.id] || this.icons.unknown) + '"/></svg></button>';
            }
            grid.innerHTML = html;
        },

        saveRename: function() {
            var d = this.renaming;
            if (!d) return;
            var self = this;
            var input = document.getElementById('ac-rename-input');
            var name = input ? input.value.trim() : '';
            var icon = this.iconPick || '';
            XHR.get(this.endpoints.meta, { mac: d.mac || '', name: name, icon: icon }, function(x, data) {
                if (x && x.status == 200 && data && data.ok) {
                    d.name = name;
                    d.icon = icon;
                    self.closeRename();
                    ocToast('<%:Saved%>', 'success');
                    self.renderList();
                } else {
                    self.acErrorToast(x, data);
                }
            });
        },

        restoreAuto: function() {
            var d = this.renaming;
            if (!d) return;
            var self = this;
            XHR.get(this.endpoints.meta, { mac: d.mac || '', name: '', icon: '' }, function(x, data) {
                if (x && x.status == 200 && data && data.ok) {
                    d.name = '';
                    d.icon = '';
                    self.closeRename();
                    ocToast('<%:Auto detect restored%>', 'success');
                    self.renderList();
                } else {
                    self.acErrorToast(x, data);
                }
            });
        },

        bind: function() {
            if (this.bound) return;
            this.bound = true;
            var self = this;

            var listEl = document.getElementById('ac-list');
            if (listEl) {
                listEl.addEventListener('click', function(e) {
                    var t = e.target;
                    var nameEl = t.closest ? t.closest('.ac-name') : null;
                    if (nameEl) {
                        var row = nameEl.closest('.ac-row');
                        if (row) self.openRename(self.deviceByKey(row.getAttribute('data-dev')));
                        return;
                    }
                    var dirBtn = t.closest ? t.closest('.ac-switch button') : null;
                    if (dirBtn) {
                        var row2 = dirBtn.closest('.ac-row');
                        if (row2) self.setDevice(row2.getAttribute('data-dev'), dirBtn.getAttribute('data-dir'));
                    }
                });
            }

            var bindBtn = function(id, handler) {
                var el = document.getElementById(id);
                if (el) el.addEventListener('click', handler);
            };
            bindBtn('ac-all-proxy', function() { self.setAll('proxy'); });
            bindBtn('ac-all-direct', function() { self.setAll('direct'); });
            bindBtn('ac-refresh', function() { self.rescan(document.getElementById('ac-refresh')); });
            bindBtn('ac-empty-refresh', function() { self.rescan(document.getElementById('ac-empty-refresh')); });

            var searchEl = document.getElementById('ac-search');
            var clearEl = document.getElementById('ac-search-clear');
            var applyQuery = function(value) {
                var q = String(value || '').trim().toLowerCase();
                if (q === self.query) return;
                self.query = q;
                self.lastHtml = null;
                if (clearEl) clearEl.classList.toggle('oc-hidden', !q);
                self.renderList();
            };
            if (searchEl) {
                var searchTimer = null;
                searchEl.addEventListener('input', function() {
                    if (searchTimer) clearTimeout(searchTimer);
                    var val = this.value;
                    searchTimer = setTimeout(function() { searchTimer = null; applyQuery(val); }, 120);
                });
                searchEl.addEventListener('keydown', function(e) {
                    if (e.key === 'Escape') { this.value = ''; applyQuery(''); }
                });
            }
            if (clearEl) {
                clearEl.addEventListener('click', function() {
                    if (searchEl) { searchEl.value = ''; searchEl.focus(); }
                    applyQuery('');
                });
            }
            var searchBar = document.getElementById('ac-search-bar');
            var searchBtn = document.getElementById('ac-search-btn');
            var toggleSearch = function(show) {
                if (!searchBar) return;
                var open = (show === undefined) ? searchBar.classList.contains('oc-hidden') : !!show;
                searchBar.classList.toggle('oc-hidden', !open);
                if (searchBtn) searchBtn.setAttribute('aria-expanded', open ? 'true' : 'false');
                if (open) {
                    if (searchEl) setTimeout(function() { searchEl.focus(); }, 30);
                } else {
                    if (searchEl) searchEl.value = '';
                    applyQuery('');
                }
            };
            if (searchBtn) searchBtn.addEventListener('click', function() { toggleSearch(); });
            bindBtn('ac-warn-fix-btn', function() { self.switchDns(); });
            document.addEventListener('visibilitychange', function() { self.syncTimers(); });

            var sortBtn = document.getElementById('ac-sort-btn');
            var sortMenu = document.getElementById('ac-sort-menu');
            if (sortBtn && sortMenu) {
                sortBtn.addEventListener('click', function(e) {
                    e.stopPropagation();
                    self.syncSortUI();
                    sortMenu.classList.toggle('oc-hidden');
                });
                sortMenu.addEventListener('click', function(e) {
                    var item = e.target.closest('button');
                    if (!item) return;
                    self.cycleSort(item.getAttribute('data-key'));
                    sortMenu.classList.add('oc-hidden');
                });
                document.addEventListener('click', function() {
                    sortMenu.classList.add('oc-hidden');
                });
            }

            var thCells = document.querySelectorAll('#stats-view-ac .ac-th-cell');
            for (var i = 0; i < thCells.length; i++) {
                thCells[i].addEventListener('click', function() {
                    self.cycleSort(this.getAttribute('data-key'));
                });
            }

            var grid = document.getElementById('ac-icon-grid');
            if (grid) {
                grid.addEventListener('click', function(e) {
                    var opt = e.target.closest('.ac-icon-opt');
                    if (!opt) return;
                    self.iconPick = opt.getAttribute('data-icon');
                    self.renderIconGrid();
                });
            }
            bindBtn('ac-rename-close', function() { self.closeRename(); });
            bindBtn('ac-rename-cancel', function() { self.closeRename(); });
            bindBtn('ac-rename-save', function() { self.saveRename(); });
            bindBtn('ac-rename-auto', function() { self.restoreAuto(); });
            var overlay = document.getElementById('ac-rename-overlay');
            if (overlay) {
                overlay.addEventListener('click', function(e) {
                    if (e.target === overlay) self.closeRename();
                });
            }
        }
    };

    StatsChart.init();

    ClientsAC.init();

    var pluginToggleUserAction = false;
    var coreMissing = null;
    var autoGuideChecked = false;
    var lastVersionCheck = 0;

    get_op_mode();

    XHR.poll(5, '<%=url("admin", "services", "openclash", "status")%>', null, function(x, status) {
        if (x && x.status == 200) {
            var updates = [];

            if (!pluginToggleUserAction) {
                updates.push({
                    element: DOMCache.clash,
                    content: status.clash ? '<b style=color:var(--success-color)>' + status.core_type +'&nbsp;<%:Running%></b>' : '<b style=color:var(--error-color)><%:Not Running%></b>'
                });

                updatePluginToggleState(status.clash);
            }

            if (status.run_mode && !SettingsManager.pendingOperations.has('run_mode_' + status.run_mode)) {
                var expectedValue = status.run_mode.split("-")[2] == undefined ? "" : ("-" + status.run_mode.split("-")[2]);
                for (var i = 0; i < DOMCache.radio_ru.length; i++) {
                    if (DOMCache.radio_ru[i].value == expectedValue && !DOMCache.radio_ru[i].checked) {
                        DOMCache.radio_ru[i].checked = true;
                    }
                }
            }

            if (status.rule_mode && !SettingsManager.pendingOperations.has('rule_mode_' + status.rule_mode)) {
                for (var i = 0; i < DOMCache.radio.length; i++) {
                    if (DOMCache.radio[i].value == status.rule_mode && !DOMCache.radio[i].checked) {
                        DOMCache.radio[i].checked = true;
                        break;
                    }
                }
            }

            if (!SettingsManager.pendingOperations.has('meta_sniffer_' + status.meta_sniffer)) {
                DOMCache.meta_sniffer_on.checked = status.meta_sniffer == "1";
                DOMCache.meta_sniffer_off.checked = status.meta_sniffer != "1";
            }
            if (!SettingsManager.pendingOperations.has('respect_rules_' + status.respect_rules)) {
                DOMCache.respect_rules_on.checked = status.respect_rules == "1";
                DOMCache.respect_rules_off.checked = status.respect_rules != "1";
            }
            if (!SettingsManager.pendingOperations.has('oversea_' + status.oversea)) {
                if (status.oversea == "0") DOMCache.oc_setting_oversea_0.checked = true;
                else if (status.oversea == "1") DOMCache.oc_setting_oversea_1.checked = true;
                else if (status.oversea == "2") DOMCache.oc_setting_oversea_2.checked = true;
            }
            if (!SettingsManager.pendingOperations.has('stream_unlock_' + status.stream_unlock)) {
                DOMCache.stream_unlock_on.checked = status.stream_unlock === '1';
                DOMCache.stream_unlock_off.checked = status.stream_unlock !== '1';
            }

            var webContent = status.clash ? '<input type="button" class="dashboard-btn" value="<%:Yacd%>" onclick="return ycad_dashboard(this)"/>' : '<input type="button" class="dashboard-btn" value="<%:Yacd%>" onclick="event.preventDefault(); event.stopPropagation(); return false;"/>';
            updates.push({element: DOMCache.web, content: webContent});

            var weboContent = status.clash ? '<input type="button" class="dashboard-btn" value="<%:Dashboard%>" onclick="return net_dashboard(this)"/>' : '<input type="button" class="dashboard-btn" value="<%:Dashboard%>" onclick="event.preventDefault(); event.stopPropagation(); return false;"/>';
            updates.push({element: DOMCache.webo, content: weboContent});

            var webmContent = status.clash ? '<input type="button" class="dashboard-btn" value="<%:Metacubexd%>" onclick="return meta_dashboard(this)"/>' : '<input type="button" class="dashboard-btn" value="<%:Metacubexd%>" onclick="event.preventDefault(); event.stopPropagation(); return false;"/>';
            updates.push({element: DOMCache.webm, content: webmContent});

            var webzContent = status.clash ? '<input type="button" class="dashboard-btn" value="<%:Zashboard%>" onclick="return net_zashboard(this)"/>' : '<input type="button" class="dashboard-btn" value="<%:Zashboard%>" onclick="event.preventDefault(); event.stopPropagation(); return false;"/>';
            updates.push({element: DOMCache.webz, content: webzContent});

            var externalWebContent = status.clash ? '<input type="button" class="dashboard-btn" value="<%:External Dashboard%>" onclick="return external_dashboard(this)"/>' : '<input type="button" class="dashboard-btn" value="<%:External Dashboard%>" onclick="event.preventDefault(); event.stopPropagation(); return false;"/>';
            updates.push({element: DOMCache.web_external, content: externalWebContent});

            var closeConnContent = status.clash ? '<input type="button" class="dashboard-btn" value="<%:Close Connect%>" onclick="return b_close_all_connection(this)"/>' : '<input type="button" class="dashboard-btn" value="<%:Close Connect%>" onclick="event.preventDefault(); event.stopPropagation(); return false;"/>';
            updates.push({element: document.getElementById('_close_all_connection_btn'), content: closeConnContent});

            var reloadFwContent = status.clash ? '<input type="button" class="dashboard-btn" value="<%:Reload Firewall%>" onclick="return b_reload_firewall(this)"/>' : '<input type="button" class="dashboard-btn" value="<%:Reload Firewall%>" onclick="event.preventDefault(); event.stopPropagation(); return false;"/>';
            updates.push({element: document.getElementById('_reload_firewall_btn'), content: reloadFwContent});

            var flushCacheContent = status.clash ? '<input type="button" class="dashboard-btn" value="<%:Flush DNS%>" onclick="return b_flush_dns_cache(this)"/>' : '<input type="button" class="dashboard-btn" value="<%:Flush DNS Cache%>" onclick="event.preventDefault(); event.stopPropagation(); return false;"/>';
            updates.push({element: document.getElementById('_flush_dns_cache_btn'), content: flushCacheContent});

            var oneKeyUpdateContent = '<input type="button" class="dashboard-btn" value="<%:Check Update%>" onclick="return all_one_key_update(this)"/>';
            updates.push({element: document.getElementById('_one_key_update_btn'), content: oneKeyUpdateContent});

            StateManager.batchUpdateDOM(updates);

            if (!status.yacd) {
                DOMCache.web.classList.add('hidden');
            }

            if (!status.dashboard) {
                DOMCache.webo.classList.add('hidden');
            }

            if (!status.metacubexd) {
                DOMCache.webm.classList.add('hidden');
            }

            if (!status.zashboard) {
                DOMCache.webz.classList.add('hidden');
            }

            DOMCache.web_external.classList.toggle('hidden', !ocGetCustomDashboardURL(status));

            StateManager.current_status = status;

            if (status.daip) {
                var daipContent, dapoContent;

                var dashboardBase = getDashboardBaseURL(status);
                dapoContent = dashboardBase.port ? ":" + dashboardBase.port : "";
                daipContent = "<b style=color:var(--success-color)>" + dashboardBase.host + dapoContent + "</b>";

                DOMCache.daip.innerHTML = daipContent;

                StateManager.cached_proxy_info = { mixed_port: status.mixed_port, auth_user: status.auth_user, auth_pass: status.auth_pass };
                var proxy_ip = status.daip;
                var mix_addr = proxy_ip + ':' + (status.mixed_port || '7893');
                DOMCache.mix_proxy.innerHTML = "<b style=color:var(--success-color)>" + mix_addr + "</b>";
            } else {
                DOMCache.daip.innerHTML = "<b style=color:var(--error-color)>" + '<%:Not Available%>' + "</b>";
                StateManager.cached_proxy_info = null;
                DOMCache.mix_proxy.innerHTML = "<b style=color:var(--error-color)>" + '<%:Not Available%>' + "</b>";
                DOMCache.copy_secret.style.display = "none";
                DOMCache.copy_address.style.display = "none";
                DOMCache.copy_mix_address.style.display = "none";
                DOMCache.copy_mix_secret.style.display = "none";
                DOMCache.copy_pac_config.style.display = "none";
            }

            if (!status.clash) {
                SystemStatusManager.stop();
                SystemStatusManager.resetSysStats();
                StatsChart.resetToZero();
            }

            if (status.clash && status.daip) {
                if (!WSManager.hasActiveConnections()) {
                    LogManager.startLogDisplay(null, false, 'view');
                }
                initializeWebSocketConnections(status);
            } else {
                WSManager.closeAll();
                StatsWSMeta.protocol = null;
                if (status.clash) {
                    syncDataSource();
                } else {
                    NetworkStatsManager.stop();
                    NetworkStatsManager.resetStats();
                }
            }
        }
        clashversion_check();
    });

    DarkModeDetector.init();
    ConfigFileManager.init();

    window.addEventListener('oc-overwrite-updated', function() {
        OverwriteSubscribeManager.load(true);
    });

    setTimeout(function() {
        OverwriteSubscribeManager.init();
        SubscriptionManager.init();
        UsageHelpManager.init();
        loadAnnouncement();
        var guideBubble = document.getElementById('guide-bubble');
        if (guideBubble && localStorage.getItem('oc_guide_done') !== '1') {
            guideBubble.classList.add('show');
            setTimeout(function() { guideBubble.classList.remove('show'); }, 6000);
        }
    }, 300);

    setTimeout(function() { check_core(); }, 1000);

    window.addEventListener('beforeunload', function() {
        WSManager.closeAll();
        LogManager.stopLogDisplay();
        StatsChart.stopTimer();
        SystemStatusManager.stop();
        NetworkStatsManager.stop();
        StateManager.clearAllCache();
        if (StateManager.pending_requests) {
            StateManager.pending_requests.clear();
        }
    });

    var StatsWSMeta = {
        protocol: null,
        token: null,
        endpoints: {
            traffic: '/traffic',
            connections: '/connections',
            memory: '/memory'
        },
        handlers: {
            traffic: ws_tmessage,
            connections: ws_cmessage,
            memory: ws_mmessage
        }
    };

    function syncDataSource() {
        var status = StateManager.current_status;
        var req = (typeof StatsChart !== 'undefined' && StatsChart.requiredSources) ? StatsChart.requiredSources() : { ws: [], sys: true };
        var needsNetworkFallback = status && status.clash && status.daip && !StatsWSMeta.protocol &&
            (StatsChart.view === 'cards' || req.ws.length > 0);

        if (status && status.clash && req.sys) {
            if (!SystemStatusManager.isEnabled) SystemStatusManager.start();
        } else {
            SystemStatusManager.stop();
        }

        if (needsNetworkFallback) {
            if (!NetworkStatsManager.isEnabled) NetworkStatsManager.start();
        } else {
            NetworkStatsManager.stop();
        }

        if (!StatsWSMeta.protocol) return;

        var types = ['traffic', 'connections', 'memory'];
        for (var i = 0; i < types.length; i++) {
            var t = types[i];
            if (req.ws.indexOf(t) >= 0) {
                var conn = WSManager.connections[t];
                var active = conn && (conn.state === WSManager.connectionStates.CONNECTED || conn.state === WSManager.connectionStates.CONNECTING);
                if (!active) {
                    var url = StatsWSMeta.protocol + StatsWSMeta.endpoints[t] + (StatsWSMeta.token ? '?token=' + StatsWSMeta.token : '');
                    WSManager.createConnection(t, url, StatsWSMeta.handlers[t]);
                }
            } else {
                WSManager.closeConnection(t);
            }
        }
    }

    function initializeWebSocketConnections(status) {
        if (!status || !status.clash || !status.daip) {
            StatsWSMeta.protocol = null;
            syncDataSource();
            return false;
        }

        StatsWSMeta.protocol = getDashboardWebSocketOrigin(status);
        StatsWSMeta.token = status.dase;
        syncDataSource();
        return true;
    }

    function AnnouncementAnimator(config) {
        var bannerElement = config.bannerElement;
        var contentElement = config.contentElement;
        var announcements = config.announcements;
        var isRandomTips = config.isRandomTips || false;
        var randomTipCount = config.randomTipCount || 3;
        var getRandomTipsCallback = config.getRandomTipsCallback;
        var onIndexChange = config.onIndexChange || function(index, text) {};
        var loopDelay = config.loopDelay || 2000;
        var animationRefreshThreshold = 250;
        var currentIndex = 0;
        var isHovered = false;
        var pauseTimeout = null;
        var nextAnimationTimeout = null;
        var resizeTimeout = null;
        var animationEndHandler = null;
        var destroyed = false;
        var cachedBannerWidth = 0;
        var cachedContentWidth = 0;
        var cachedDuration = 0;

        function calculateAnimationDuration() {
            var bannerWidth = bannerElement.offsetWidth;
            var contentWidth = contentElement.offsetWidth;
            if (bannerWidth === cachedBannerWidth && contentWidth === cachedContentWidth && cachedDuration > 0) {
                return cachedDuration;
            }
            cachedBannerWidth = bannerWidth;
            cachedContentWidth = contentWidth;
            var refreshRate = window.screen && window.screen.refreshRate ? window.screen.refreshRate : 60;
            if (refreshRate <= 0) refreshRate = 60;
            if (refreshRate > 480) refreshRate = 480;

            var scrollDistance = contentWidth + bannerWidth;

            var minDistance = 400;
            var maxDistance = 20000;
            var minSpeed = 60;
            var maxSpeed = 360;
            var clampedDistance = Math.min(maxDistance, Math.max(minDistance, scrollDistance));
            var targetVelocity = minSpeed + (maxSpeed - minSpeed) * (clampedDistance - minDistance) / (maxDistance - minDistance);

            var duration = (scrollDistance / targetVelocity) * 1000;

            var refreshRateMultiplier = 1;
            if (refreshRate > 60) {
                refreshRateMultiplier = 1 + (refreshRate - 60) / 240;
            }
            duration = duration * refreshRateMultiplier;

            cachedDuration = Math.max(4000, Math.min(duration, 50000));
            return cachedDuration;
        }

        function updateScrollAnimation(duration) {
            var viewport = bannerElement.parentElement;
            if (!viewport) viewport = bannerElement;

            var viewportWidth = viewport.clientWidth;
            var contentWidth = contentElement.scrollWidth;
            var scrollDistance = -(contentWidth + viewportWidth);

            viewport.style.setProperty('--scroll-distance', scrollDistance + 'px');
            contentElement.style.animationDuration = duration + 'ms';
        }

        function refreshAnimation() {
            if (!contentElement.classList.contains('scrolling')) return;
            var duration = calculateAnimationDuration();
            updateScrollAnimation(duration);
            contentElement.classList.remove('scrolling');
            contentElement.offsetHeight;
            contentElement.classList.add('scrolling');
        }

        function refreshAnnouncementsForRandomMode() {
            if (!isRandomTips) return;
            var newTips;
            if (getRandomTipsCallback) {
                newTips = getRandomTipsCallback(randomTipCount);
            } else {
                newTips = AnnouncementDataManager.getRandomTips(randomTipCount);
            }
            if (newTips && newTips.length) {
                announcements = newTips;
            }
        }

        function startSingleScroll() {
            if (destroyed) return;
            if (nextAnimationTimeout) {
                clearTimeout(nextAnimationTimeout);
                nextAnimationTimeout = null;
            }

            var text = announcements[currentIndex] || '';
            contentElement.textContent = text;
            if (onIndexChange) onIndexChange(currentIndex, text);

            setTimeout(function() {
                if (destroyed) return;
                var duration = calculateAnimationDuration();
                updateScrollAnimation(duration);

                if (animationEndHandler) {
                    contentElement.removeEventListener('animationend', animationEndHandler);
                }

                animationEndHandler = function(e) {
                    if (e.target === contentElement && e.animationName === 'announceScroll') {
                        contentElement.removeEventListener('animationend', animationEndHandler);
                        animationEndHandler = null;

                        pauseTimeout = setTimeout(function() {
                            if (destroyed) return;
                            if (!isHovered) {
                                currentIndex = (currentIndex + 1) % announcements.length;
                                if (isRandomTips && currentIndex === 0) {
                                    refreshAnnouncementsForRandomMode();
                                }
                                startSingleScroll();
                            }
                        }, loopDelay);
                    }
                };
                contentElement.addEventListener('animationend', animationEndHandler);

                contentElement.classList.remove('scrolling');
                contentElement.offsetHeight;
                contentElement.classList.add('scrolling');
            }, 50);
        }

        function pause() {
            if (destroyed) return;
            isHovered = true;
            contentElement.classList.add('paused');
            if (pauseTimeout) {
                clearTimeout(pauseTimeout);
                pauseTimeout = null;
            }
        }

        function resume() {
            if (destroyed) return;
            isHovered = false;
            contentElement.classList.remove('paused');
        }

        function destroy() {
            destroyed = true;
            if (pauseTimeout) clearTimeout(pauseTimeout);
            if (nextAnimationTimeout) clearTimeout(nextAnimationTimeout);
            if (resizeTimeout) clearTimeout(resizeTimeout);
            if (animationEndHandler) {
                contentElement.removeEventListener('animationend', animationEndHandler);
                animationEndHandler = null;
            }
            contentElement.classList.remove('scrolling', 'paused');
            bannerElement.removeEventListener('mouseenter', mouseEnterHandler);
            bannerElement.removeEventListener('mouseleave', mouseLeaveHandler);
            window.removeEventListener('resize', resizeHandler);
        }

        function mouseEnterHandler() { pause(); }
        function mouseLeaveHandler() { resume(); }
        function resizeHandler() {
            clearTimeout(resizeTimeout);
            cachedBannerWidth = 0;
            cachedContentWidth = 0;
            cachedDuration = 0;
            resizeTimeout = setTimeout(function() {
                if (!destroyed && contentElement.classList.contains('scrolling')) {
                    refreshAnimation();
                }
            }, animationRefreshThreshold);
        }

        function init() {
            if (!bannerElement || !contentElement || !announcements || announcements.length === 0) {
                console.warn('AnnouncementAnimator: invalid config');
                return false;
            }
            bannerElement.style.display = 'block';
            bannerElement.addEventListener('mouseenter', mouseEnterHandler);
            bannerElement.addEventListener('mouseleave', mouseLeaveHandler);
            window.addEventListener('resize', resizeHandler);
            startSingleScroll();
            return true;
        }

        return {
            init: init,
            pause: pause,
            resume: resume,
            destroy: destroy,
            updateAnnouncements: function(newList, newRandomFlag) {
                announcements = newList || announcements;
                isRandomTips = (newRandomFlag !== undefined) ? newRandomFlag : isRandomTips;
                currentIndex = 0;
                if (pauseTimeout) clearTimeout(pauseTimeout);
                if (nextAnimationTimeout) clearTimeout(nextAnimationTimeout);
                if (animationEndHandler) {
                    contentElement.removeEventListener('animationend', animationEndHandler);
                    animationEndHandler = null;
                }
                contentElement.classList.remove('scrolling');
                startSingleScroll();
            }
        };
    }

    function loadAnnouncement() {
        // The banner follows the LuCI language; the browser language is only a fallback
        var userLang = ocLang || navigator.language || navigator.userLanguage || '';
        var isChineseUser = (userLang.indexOf('zh') === 0);
        var bannerElement = document.getElementById('announcement-banner');
        var contentElement = document.getElementById('announcement-content');
        var megaphoneSvg = document.getElementById('megaphone');

        if (!bannerElement || !contentElement) return;

        StateManager.cachedXHRGet('<%=url("admin", "services", "openclash", "announcement")%>', function(x, status) {
            var remoteData = null;
            if (x && x.status == 200 && status.content) {
                try {
                    remoteData = typeof status.content === 'string' ? JSON.parse(status.content) : status.content;
                } catch(e) {
                    remoteData = status.content;
                }
            }

            var prepared = AnnouncementDataManager.prepareData(remoteData, isChineseUser, 3);
            if (megaphoneSvg) {
                AnnouncementDataManager.updateIconShape(megaphoneSvg, prepared.isRandomTips);
            }

            var animator = new AnnouncementAnimator({
                bannerElement: bannerElement,
                contentElement: contentElement,
                announcements: prepared.announcements,
                isRandomTips: prepared.isRandomTips,
                randomTipCount: 3,
                getRandomTipsCallback: function(count) {
                    return AnnouncementDataManager.getRandomTips(count);
                },
                loopDelay: 2000,
            });

            animator.init();

            window.addEventListener('beforeunload', function() {
                animator.destroy();
            });
        });
    }

    function switch_rule_mode(value) {
        return SettingsManager.switchSetting(
            'rule_mode',
            value,
            '<%=url("admin", "services", "openclash", "switch_rule_mode")%>'
        );
    }

    function get_run_mode() {
        if (SettingsManager.isPollPaused('run_mode')) {
            return;
        }

        StateManager.cachedXHRGet('<%=url("admin", "services", "openclash", "get_run_mode")%>', function(x, status) {
            if (x && x.status == 200 && status.mode) {
                var expectedValue = status["mode"].split("-")[2] == undefined ? "" : ("-" + status["mode"].split("-")[2]);
                var operationKey = 'run_mode_' + status.mode;

                if (!SettingsManager.pendingOperations.has(operationKey)) {
                    for (var i = 0; i < DOMCache.radio_ru.length; i++) {
                        if (DOMCache.radio_ru[i].value == expectedValue && !DOMCache.radio_ru[i].checked) {
                            DOMCache.radio_ru[i].checked = true;
                        }
                    }
                }
            }
        }, true);
    }

    function switch_run_mode(value) {
        LogManager.markCoreStart();
        LogManager.startLogDisplay('<%:Saving...%>', false, 'init');
        return SettingsManager.switchSetting(
            'run_mode',
            value,
            '<%=url("admin", "services", "openclash", "switch_run_mode")%>'
        );
    }

    var currentDnsMode = '';

    function setDnsModeUI(mode) {
        currentDnsMode = mode;
        if (DOMCache.dns_fakeip) DOMCache.dns_fakeip.checked = (mode === 'fake-ip');
        if (DOMCache.dns_redirhost) DOMCache.dns_redirhost.checked = (mode === 'redir-host');
        if (DOMCache.radio_run_normal) {
            DOMCache.radio_run_normal.innerHTML = (mode === 'fake-ip') ? '<%:Enhance%>' : '<%:Compat%>';
        }
    }

    function get_op_mode() {
        StateManager.cachedXHRGet('<%=url("admin", "services", "openclash", "op_mode")%>', function(x, status) {
            if (x && x.status == 200 && status.op_mode) {
                setDnsModeUI(status.op_mode);
            }
        }, true);
    }

    function switch_dns_mode(value) {
        var opKey = 'dns_mode_' + value;
        if (SettingsManager.pendingOperations.has(opKey) || value === currentDnsMode) {
            return false;
        }
        SettingsManager.pendingOperations.add(opKey);
        SettingsManager.pausePoll('run_mode', 3000);

        var previous = currentDnsMode;

        LogManager.markCoreStart();
        LogManager.startLogDisplay('<%:Saving...%>', false, 'init');
        setDnsModeUI(value);
        if (DOMCache.dns_fakeip) DOMCache.dns_fakeip.disabled = true;
        if (DOMCache.dns_redirhost) DOMCache.dns_redirhost.disabled = true;
        for (var r = 0; r < DOMCache.radio_ru.length; r++) {
            DOMCache.radio_ru[r].disabled = true;
        }

        var suffix = '';
        var ru = document.getElementsByName("radios-ru");
        for (var i = 0; i < ru.length; i++) {
            if (ru[i].checked) {
                suffix = ru[i].value;
                break;
            }
        }

        function finish(success) {
            SettingsManager.pendingOperations.delete(opKey);
            if (DOMCache.dns_fakeip) DOMCache.dns_fakeip.disabled = false;
            if (DOMCache.dns_redirhost) DOMCache.dns_redirhost.disabled = false;
            for (var r = 0; r < DOMCache.radio_ru.length; r++) {
                DOMCache.radio_ru[r].disabled = false;
            }
            if (success) {
                get_op_mode();
            } else {
                setDnsModeUI(previous);
                ocAlert('<%:Switch mode failed!%>');
            }
        }

        XHR.get('<%=url("admin", "services", "openclash", "switch_mode")%>', null, function(x1) {
            if (!x1 || x1.status != 200) {
                setTimeout(function() { finish(false); }, 1500);
                return;
            }
            XHR.get('<%=url("admin", "services", "openclash", "switch_run_mode")%>', { run_mode: suffix }, function(x2) {
                setTimeout(function() { finish(x2 && x2.status == 200); }, 1500);
            });
        });
        return true;
    }

    function ws_tmessage(event) {
        var dataObj = event && event.data !== undefined ? event.data : event;
        var data;
        if (typeof dataObj === 'string') {
            try {
                data = JSON.parse(dataObj);
            } catch (e) {
                data = {};
            }
        } else {
            data = dataObj;
        }
        var uploadElement = document.getElementById("upload_");
        var downloadElement = document.getElementById("download_");
        uploadElement.innerHTML = data.up ? ocStatHtml(bytesToSize(data.up) + "/s") : ocStatHtml("0 B/s");
        downloadElement.innerHTML = data.down ? ocStatHtml(bytesToSize(data.down) + "/s") : ocStatHtml("0 B/s");
        StatsChart.feed("up", data.up ? (data.up / 1048576) : 0);
        StatsChart.feed("down", data.down ? (data.down / 1048576) : 0);
    }

    function ws_cmessage(event) {
        var dataObj = event && event.data !== undefined ? event.data : event;
        var data;
        if (typeof dataObj === 'string') {
            try {
                data = JSON.parse(dataObj);
            } catch (e) {
                data = {};
            }
        } else {
            data = dataObj;
        }
        var updates = [
            {
                element: document.getElementById("uploadtotal_"),
                content: data.uploadTotal ? ocStatHtml(bytesToSize(data.uploadTotal)) : ocStatHtml("0 KB")
            },
            {
                element: document.getElementById("downloadtotal_"),
                content: data.downloadTotal ? ocStatHtml(bytesToSize(data.downloadTotal)) : ocStatHtml("0 KB")
            },
            {
                element: document.getElementById("connect_t"),
                content: data.connections ? ocStatHtml(String(Object.keys(data.connections).length)) : ocStatHtml("0")
            }
        ];
        StateManager.batchUpdateDOM(updates);
        StatsChart.totals = { up: data.uploadTotal || null, down: data.downloadTotal || null };
        if (StatsChart.metric === 'traffic') StatsChart.updateLegendValues();
        StatsChart.feed("conn", data.connections ? Object.keys(data.connections).length : 0);
    }

    function ws_mmessage(event) {
        var dataObj = event && event.data !== undefined ? event.data : event;
        var data;
        if (typeof dataObj === 'string') {
            try {
                data = JSON.parse(dataObj);
            } catch (e) {
                data = {};
            }
        } else {
            data = dataObj;
        }
        var memElement = document.getElementById("mem_t");
        memElement.innerHTML = data.inuse ? ocStatHtml(bytesToSize(data.inuse)) : ocStatHtml("0 KB");
        StatsChart.feed("mem", data.inuse ? (data.inuse / 1048576) : 0);
    }

    var all_one_key_update = debounceButton(function(btn) {
        function checkUpdate() {
            btn.value = '<%:Checking...%>';
            update();
            btn.value = '<%:Check Update%>';
            btn.disabled = false;
        }
        if (typeof update === 'function') {
            checkUpdate();
        } else {
            ocLoadCss(ocCssUrl('oc-update.css'));
            ocRequireScript(ocJsUrl('update.js'), checkUpdate);
        }
        return false;
    });

    var b_flush_dns_cache = debounceButton(function(btn) {
        btn.disabled = true;
        btn.value = '<%:Flushing...%> ';
        XHR.get('<%=url("admin", "services", "openclash", "flush_dns_cache")%>', null, function(x, status) {
            btn.disabled = false;
            if (x && x.status == 200) {
                btn.value = (status.fakeip_flush === "" && status.dns_flush === "") ? '<%:Flush Successful%>' : '<%:Flush Failed%>';
            } else {
                btn.value = '<%:Flush Timeout%>';
            }
        });
        return false;
    });

    var b_reload_firewall = debounceButton(function(btn) {
        btn.disabled = true;
        btn.value = '<%:Reloading...%>';
        LogManager.startLogDisplay('<%:Reloading...%>', false, 'init');
        XHR.get('<%=url("admin", "services", "openclash", "reload_firewall")%>', null, function(x, status) {
            btn.disabled = false;
            btn.value = (x && x.status == 200) ? '<%:Reload Firewall%>' : '<%:Firewall Rules Reset Failed%>';
        });
        return false;
    });

    var b_close_all_connection = debounceButton(function(btn) {
        btn.disabled = true;
        btn.value = '<%:Reloading...%>';
        XHR.get('<%=url("admin", "services", "openclash", "close_all_connection")%>', null, function(x, status) {
            btn.disabled = false;
            btn.value = (x && x.status == 200) ? '<%:Close Connect%>' : '<%:Close Connect Failed%>';
        });
        return false;
    });

    function net_zashboard(btn) {
        btn.disabled = true;
        btn.value = '<%:Zashboard%>';
        var status = StateManager.current_status;
        if (!status) { setTimeout(function() { net_zashboard(btn); }, 500); return false; }
        winOpen(buildDashboardURL(status, 'zashboard', true));
        btn.disabled = false;
        return false;
    }

    function meta_dashboard(btn) {
        btn.disabled = true;
        btn.value = '<%:Metacubexd%>';
        var status = StateManager.current_status;
        if (!status) { setTimeout(function() { meta_dashboard(btn); }, 500); return false; }
        winOpen(buildDashboardURL(status, 'metacubexd', true));
        btn.disabled = false;
        return false;
    }

    function ycad_dashboard(btn) {
        btn.disabled = true;
        btn.value = '<%:Yacd%>';
        var status = StateManager.current_status;
        if (!status) { setTimeout(function() { ycad_dashboard(btn); }, 500); return false; }
        winOpen(buildDashboardURL(status, 'yacd', false));
        btn.disabled = false;
        return false;
    }

    function net_dashboard(btn) {
        btn.disabled = true;
        btn.value = '<%:Dashboard%>';
        var status = StateManager.current_status;
        if (!status) { setTimeout(function() { net_dashboard(btn); }, 500); return false; }
        winOpen(buildDashboardURL(status, 'dashboard', false));
        btn.disabled = false;
        return false;
    }

    function external_dashboard(btn) {
        btn.disabled = true;
        btn.value = '<%:External Dashboard%>';
        var status = StateManager.current_status;
        if (!status) { setTimeout(function() { external_dashboard(btn); }, 500); return false; }
        var url = buildExternalDashboardURL(status);
        if (url) winOpen(url);
        btn.disabled = false;
        return false;
    }

    function homepage() {
        winOpen('https://github.com/vernesong/OpenClash');
    }

    function gitbookpage() {
        winOpen('https://wiki.metacubex.one');
    }

    function wikipage() {
        winOpen('https://github.com/vernesong/OpenClash/blob/dev/.github/skills/openclash-user-guide/SKILL.md');
    }

    function telegrampage() {
        winOpen('https://t.me/openclash_group');
    }

    function sponsorpage() {
        winOpen('https://ko-fi.com/vernesong');
    }

    function clashversion_check() {
        if (document.visibilityState === 'hidden') return;
        var now = Date.now();
        if (now - lastVersionCheck < 30000) return;
        lastVersionCheck = now;

        function compareVersions(v1, v2) {
            if (!v1 || !v2) return 0;
            var ver1 = v1.replace(/^v/, '').split('.');
            var ver2 = v2.replace(/^v/, '').split('.');

            var maxLen = Math.max(ver1.length, ver2.length);
            while (ver1.length < maxLen) ver1.push('0');
            while (ver2.length < maxLen) ver2.push('0');

            for (var i = 0; i < maxLen; i++) {
                var num1 = parseInt(ver1[i], 10) || 0;
                var num2 = parseInt(ver2[i], 10) || 0;
                if (num1 > num2) return 1;
                if (num1 < num2) return -1;
            }
            return 0;
        }

        function updateCoreDot(corelv) {
            if (DOMCache.core_version_display.classList.contains('oc-hidden')) return;
            var coremetacv = DOMCache.core_version_text.textContent;
            var hasUpdate = corelv && corelv !== "" && corelv !== "loading..." && corelv !== coremetacv;
            var existingDot = DOMCache.core_version_display.querySelector('.update-dot');
            if (hasUpdate) {
                if (!existingDot) {
                    var updateDot = document.createElement('span');
                    updateDot.className = 'update-dot';
                    DOMCache.core_version_display.appendChild(updateDot);
                }
                DOMCache.core_version_display.title = '<%:New version available%>: ' + corelv;
                DOMCache.core_version_text.removeAttribute('title');
            } else {
                if (existingDot) {
                    existingDot.remove();
                }
                DOMCache.core_version_display.title = '';
            }
        }

        function updatePluginDot(oplv) {
            if (DOMCache.plugin_version_display.classList.contains('oc-hidden')) return;
            var opcv = DOMCache.plugin_version_text.textContent;
            var hasUpdate = false;
            if (oplv && oplv !== "" && oplv !== "loading...") {
                if (compareVersions(oplv, opcv) > 0) {
                    hasUpdate = true;
                }
            }
            var existingDot = DOMCache.plugin_version_display.querySelector('.update-dot');
            if (hasUpdate) {
                if (!existingDot) {
                    var updateDot = document.createElement('span');
                    updateDot.className = 'update-dot';
                    DOMCache.plugin_version_display.appendChild(updateDot);
                }
                DOMCache.plugin_version_display.title = '<%:New version available%>: ' + oplv;
                DOMCache.plugin_version_text.removeAttribute('title');
            } else {
                if (existingDot) {
                    existingDot.remove();
                }
                DOMCache.plugin_version_display.title = '';
            }
        }

        StateManager.cachedXHRGet('<%=url("admin", "services", "openclash", "update")%>', function(x, status) {
            if (x && x.status == 200) {
                if (status.coremetacv && status.coremetacv !== "0") {
                    var coreVersionText = status.coremetacv;
                    DOMCache.core_version_text.textContent = coreVersionText;
                    if (DOMCache.core_version_text.scrollWidth > DOMCache.core_version_text.clientWidth) {
                        DOMCache.core_version_text.title = coreVersionText;
                    } else {
                        DOMCache.core_version_text.title = '';
                    }
                    DOMCache.core_version_display.classList.remove('oc-hidden');
                } else {
                    DOMCache.core_version_display.classList.add('oc-hidden');
                    DOMCache.core_version_display.title = '';
                }

                if (status.opcv && status.opcv !== "0") {
                    var pluginVersionText = status.opcv;
                    DOMCache.plugin_version_text.textContent = pluginVersionText;
                    if (DOMCache.plugin_version_text.scrollWidth > DOMCache.plugin_version_text.clientWidth) {
                        DOMCache.plugin_version_text.title = pluginVersionText;
                    } else {
                        DOMCache.plugin_version_text.title = '';
                    }
                    DOMCache.plugin_version_display.classList.remove('oc-hidden');
                } else {
                    DOMCache.plugin_version_display.classList.add('oc-hidden');
                    DOMCache.plugin_version_display.title = '';
                }
            }
            checkLatestVersions();
        });

        function checkLatestVersions() {
            StateManager.cachedXHRGet('<%=url("admin", "services", "openclash", "last_version")%>', function(x, data) {
                if (x && x.status == 200 && data) {
                    updateCoreDot(data.corelv);
                    updatePluginDot(data.oplv);
                } else {
                    updateCoreDot('');
                    updatePluginDot('');
                }
            });
        }
    }

    function check_core() {
        StateManager.cachedXHRGet('<%=url("admin", "services", "openclash", "check_core")%>', function(x, status) {
            if (x && x.status == 200) {
                coreMissing = (status.core_status != "1");
                autoOpenGuide();
            }
        });
    }

    // the guide start depends on the config list as well, so wait until both answers are in
    function autoOpenGuide() {
        if (autoGuideChecked || coreMissing !== true || !ConfigFileManager.configListLoaded) return;
        autoGuideChecked = true;
        if (localStorage.getItem('oc_guide_autostart') === '0') return;
        openGuide(ConfigFileManager.configList.length > 0);
    }

    // The core is missing: open the quick start guide (a modal on this page) instead of the
    // plain confirm() dialog. A fresh device starts on the guide's first page, a missing core
    // alone jumps straight to the core task. "oc_guide_autostart" keeps users that opted out
    // from being pushed.
    function openGuide(atPending) {
        if (typeof Guide !== 'undefined') { Guide.open(atPending); return false; }
        ocLoadCss(ocCssUrl('oc-guide.css'));
        ocRequireScript(ocJsUrl('guide.js'), function() {
            if (typeof Guide !== 'undefined') Guide.open(atPending);
        });
        return false;
    }

    function copyAddress() {
        var currentStatus = StateManager.current_status;
        var externalURL = currentStatus ? buildExternalDashboardURL(currentStatus) : '';
        if (externalURL) {
            ocCopyToClipboard(externalURL, DOMCache.copy_address, '<%:Copy failed, please copy manually:%>');
            return false;
        }

        XHR.get('<%=url("admin", "services", "openclash", "dashboard_type")%>', null, function(x, status) {
            if (x && x.status == 200) {
                var panel = status.default_dashboard;
                if (panel && StateManager.current_status[panel]) {
                    var url = buildDashboardURL(currentStatus, panel, panel === 'zashboard' || panel === 'metacubexd');

                    ocCopyToClipboard(url, DOMCache.copy_address, '<%:Copy failed, please copy manually:%>');
                } else {
                    var fallbackUrl = 'http://' + (StateManager.current_status.daip || 'unknown') + ':' + (StateManager.current_status.cn_port || '9090') + '/ui/zashboard/#/';
                    ocCopyToClipboard(fallbackUrl, DOMCache.copy_address, '<%:Copy failed, please copy manually:%>');
                }
            } else {
                var fallbackUrl = 'http://' + (StateManager.current_status.daip || 'unknown') + ':' + (StateManager.current_status.cn_port || '9090') + '/ui/zashboard/#/';
                ocCopyToClipboard(fallbackUrl, DOMCache.copy_address, '<%:Copy failed, please copy manually:%>');
            }
        });
        return false;
    }

    function copySecret() {
        var secret = StateManager.current_status.dase || '';
        if (secret === '') {
            ocAlert('<%:No control panel secret set%>');
            return false;
        }
        ocCopyToClipboard(secret, DOMCache.copy_secret, '<%:Copy failed, please copy manually:%>');
        return false;
    }

    function copyMixAuth() {
        if (StateManager.cached_proxy_info) {
            if (StateManager.cached_proxy_info.auth_user && StateManager.cached_proxy_info.auth_pass) {
                var authText = StateManager.cached_proxy_info.auth_user + ':' + StateManager.cached_proxy_info.auth_pass;
                ocCopyToClipboard(authText, DOMCache.copy_mix_secret, '<%:Copy failed, please copy manually:%>');
            } else {
                ocAlert('<%:No proxy auth info set%>');
            }
        } else {
            ocAlert('<%:Proxy info not available, please try again later%>');
        }
        return false;
    }

    function copyMixAddress() {
        if (StateManager.cached_proxy_info && StateManager.current_status.daip) {
            var mixPort = StateManager.cached_proxy_info.mixed_port || '7893';
            var proxyIp = StateManager.current_status.daip;
            var proxyText = proxyIp + ':' + mixPort;
            if (StateManager.cached_proxy_info.auth_user && StateManager.cached_proxy_info.auth_pass) {
                proxyText = StateManager.cached_proxy_info.auth_user + ':' + StateManager.cached_proxy_info.auth_pass + '@' + proxyText;
            }
            proxyText = 'http://' + proxyText;
            ocCopyToClipboard(proxyText, DOMCache.copy_mix_address, '<%:Copy failed, please copy manually:%>');
        } else {
            ocAlert('<%:Proxy info not available, please try again later%>');
        }
        return false;
    }

    function switch_oc_setting_oversea(value) {
        LogManager.markCoreStart();
        LogManager.startLogDisplay('<%:Saving...%>', false, 'view');
        return SettingsManager.switchSetting(
            'oversea',
            value,
            '<%=url("admin", "services", "openclash", "switch_oc_setting")%>'
        );
    }

    function switch_meta_sniffer(value) {
        return SettingsManager.switchSetting(
            'meta_sniffer',
            value,
            '<%=url("admin", "services", "openclash", "switch_oc_setting")%>'
        );
    }

    function switch_respect_rules(value) {
        return SettingsManager.switchSetting(
            'respect_rules',
            value,
            '<%=url("admin", "services", "openclash", "switch_oc_setting")%>'
        );
    }

    function switch_stream_unlock(value) {
        return SettingsManager.switchSetting(
            'stream_unlock',
            value,
            '<%=url("admin", "services", "openclash", "switch_oc_setting")%>'
        );
    }

    function generatePacConfig() {
        if (StateManager.current_status.daip) {
            var currentUrl = {
                protocol: window.location.protocol,
                hostname: window.location.hostname,
                host: window.location.host,
                port: window.location.port,
                href: window.location.href
            };

            XHR.get('<%=url("admin", "services", "openclash", "generate_pac")%>', {
                client_protocol: currentUrl.protocol.replace(':', ''),
                client_hostname: currentUrl.hostname,
                client_host: currentUrl.host,
                client_port: currentUrl.port || '',
                client_href: currentUrl.href
            }, function(x, data) {
                if (x && x.status == 200 && data.pac_url) {
                    if (data.error && data.error !== "") {
                        ocAlert(data.error);
                    }
                    ocCopyToClipboard(data.pac_url, DOMCache.copy_pac_config, '<%:Copy failed, please copy manually:%>');
                } else if (data.error) {
                    errorinfos = {
                        'Proxy service not running': '<%:Proxy service not running%>',
                        'Unable to get proxy IP': '<%:Unable to get proxy IP%>',
                        'Failed to write PAC file': '<%:Failed to write PAC file%>'
                    };
                    var errorMsg = errorinfos[data.error] || data.error;
                    ocAlert('<%:PAC file generation failed%>: ' + errorMsg);
                } else {
                    ocAlert('<%:PAC file generation failed%>');
                }
            });
        } else {
            ocAlert('<%:Proxy service not available, please try again later%>');
        }
        return false;
    }

    function togglePlugin(toggleElement) {
        var isEnabled = toggleElement.checked;

        if (isEnabled) {
            var currentConfig = ConfigFileManager.getCurrentConfig() || ConfigFileManager.getSelectedConfig();
            if (!currentConfig) {
                toggleElement.checked = false;
                ocAlert('<%:Please select a config file first%>');
                return false;
            }
        }

        toggleElement.disabled = true;
        pluginToggleUserAction = true;
        var action = isEnabled ? 'start' : 'stop';

        if (DOMCache.clash) {
            if (isEnabled) {
                var coreType = (StateManager.current_status && StateManager.current_status.core_type) || '';
                DOMCache.clash.innerHTML = '<b style=color:var(--success-color)>' + coreType + '&nbsp;<%:Running%></b>';
            } else {
                DOMCache.clash.innerHTML = '<b style=color:var(--error-color)><%:Not Running%></b>';
            }
        }
        StateManager.current_status.clash = isEnabled;

        var requestParams = { action: action };

        if (isEnabled) {
            var currentConfig = ConfigFileManager.getCurrentConfig();
            var selectedConfig = ConfigFileManager.getSelectedConfig();

            if (!currentConfig && selectedConfig) {
                requestParams.config_file = selectedConfig;
            }
        }

        if (isEnabled) LogManager.markCoreStart();
        LogManager.startLogDisplay(isEnabled ? '<%:Starting...%>' : '<%:Stopping...%>', false, 'init');
        XHR.get('<%=url("admin", "services", "openclash", "action")%>', requestParams, function(x, status) {
            if (x && x.status == 200 && status && status.status === 'success') {
                setTimeout(function() {
                    pluginToggleUserAction = false;
                    updatePluginToggleState(StateManager.current_status.clash || false);
                }, 2000);
            } else {
                toggleElement.checked = !isEnabled;
                StateManager.current_status.clash = !isEnabled;

                var errorMessage = isEnabled ?
                    '<%:Failed to start OpenClash%>' :
                    '<%:Failed to stop OpenClash%>';
                ocAlert(errorMessage);

                if (DOMCache.clash) {
                    DOMCache.clash.innerHTML = '<b style="color:var(--error-color)"><%:Operation Failed%></b>';
                }

                pluginToggleUserAction = false;
            }
            toggleElement.disabled = false;
        });
    }

    function updatePluginToggleState(isRunning) {
        if (pluginToggleUserAction) {
            return;
        }

        var toggleElement = document.getElementById('plugin_toggle');
        if (toggleElement) {
            toggleElement.checked = isRunning;
            toggleElement.disabled = false;

            if (DOMCache.clash && StateManager.current_status) {
                DOMCache.clash.innerHTML = isRunning ?
                    '<b style=color:var(--success-color)>' + StateManager.current_status.core_type +'&nbsp;<%:Running%></b>' :
                    '<b style=color:var(--error-color)><%:Not Running%></b>';
            }
        }
    }

    function switchConfig() {
        var currentConfig = ConfigFileManager.getSelectedConfig();
        if (!currentConfig) {
            ocAlert('<%:Please select a config file first%>');
            return false;
        }

        pluginToggleUserAction = true;

        LogManager.markCoreStart();
        LogManager.startLogDisplay('<%:Switching Config...%>', false, 'init');

        XHR.get('<%=url("admin", "services", "openclash", "switch_config")%>', {
            config_file: currentConfig
        }, function(x, status) {
            if (x && x.status == 200 && status.status === 'success') {
                ConfigFileManager.refreshConfigList();
                setTimeout(function() {
                    pluginToggleUserAction = false;
                    updatePluginToggleState(StateManager.current_status.clash || false);
                }, 2000);
            } else {
                ocAlert('<%:Failed to switch config file:%> ' + (status.message || '<%:Unknown error%>'));

                if (DOMCache.oclog) {
                    DOMCache.oclog.innerHTML = '<b style="color:var(--error-color)"><%:Switch Failed%></b>';
                }

                pluginToggleUserAction = false;
            }
        });

        return false;
    }

    function updateConfig() {
        var currentConfig = ConfigFileManager.getSelectedConfig();
        if (!currentConfig) {
            ocAlert('<%:Please select a config file first%>');
            return false;
        }

        var filename = SubscriptionManager.extractFilename(currentConfig);
        if (!filename) {
            ocAlert('<%:Invalid config file selected%>');
            return false;
        }

        pluginToggleUserAction = true;

        LogManager.markCoreStart();
        LogManager.startLogDisplay('<%:Updating Config...%>', false, 'openclash.sh');

        XHR.get('<%=url("admin", "services", "openclash", "update_config")%>', {
            filename: filename
        }, function(x, status) {
            if (x && x.status == 200) {
                if (status.status === 'success') {
                    setTimeout(function() {

                        refreshSubscriptionInfo();

                        ConfigFileManager.refreshConfigList();

                        pluginToggleUserAction = false;

                    }, 2000);
                } else {
                    pluginToggleUserAction = false;

                    if (DOMCache.oclog) {
                        DOMCache.oclog.innerHTML = '<b style="color:var(--error-color)"><%:Update Failed%></b>';
                    }

                    ocAlert('<%:Failed to update config file:%> ' + (status.message || status.error || '<%:Unknown error%>'));
                }
            } else {
                pluginToggleUserAction = false;

                if (DOMCache.oclog) {
                    DOMCache.oclog.innerHTML = '<b style="color:var(--error-color)"><%:Update Failed%></b>';
                }

                ocAlert('<%:Failed to update config file, please try again later%>');
            }
        });

        return false;
    }

    function restartCore() {
        var currentConfig = ConfigFileManager.getCurrentConfig() || ConfigFileManager.getSelectedConfig();
        if (!currentConfig) {
            ocAlert('<%:Please select a config file first%>');
            return false;
        }

        pluginToggleUserAction = true;

        var toggleElement = document.getElementById('plugin_toggle');
        if (toggleElement) {
            toggleElement.disabled = true;
        }
        var restartBtn = document.getElementById('restart_core');
        if (restartBtn) {
            restartBtn.disabled = true;
        }

        var requestParams = { action: 'restart' };

        var currentConfigValue = ConfigFileManager.getCurrentConfig();
        var selectedConfig = ConfigFileManager.getSelectedConfig();

        if (!currentConfigValue && selectedConfig) {
            requestParams.config_file = selectedConfig;
        }

        LogManager.markCoreStart();
        LogManager.startLogDisplay('<%:Restarting...%>', false, 'init');

        XHR.get('<%=url("admin", "services", "openclash", "action")%>', requestParams, function(x, status) {
            if (restartBtn) {
                restartBtn.disabled = false;
            }
            if (x && x.status == 200 && status && status.status === 'success') {
                setTimeout(function() {
                    pluginToggleUserAction = false;
                    updatePluginToggleState(StateManager.current_status.clash || false);
                }, 2000);
                ConfigFileManager.refreshConfigList();
            } else {
                if (toggleElement) {
                    toggleElement.disabled = false;
                }
                ocAlert('<%:Failed to restart core%>');

                pluginToggleUserAction = false;
            }
        });
        return false;
    }

    function refreshSubscriptionInfo() {
        var currentConfig = ConfigFileManager.getSelectedConfig();
        if (!currentConfig) {
            ocAlert('<%:Please select a config file first%>');
            return false;
        }

        SubscriptionManager.currentConfigFile = currentConfig;
        SubscriptionManager.retryCount = 0;

        var filename = SubscriptionManager.extractFilename(currentConfig);
        localStorage.removeItem('sub_info_' + filename);
        SubscriptionManager.getSubscriptionInfo();
        OverwriteSubscribeManager.load(true);
        return false;
    }

    // editor scripts can fail silently or come from a stale cache: probe the global,
    // retry once cache-busted, then tell the user
    function requireEditorScript(script, globalName, cb) {
        var settled = false;
        var ready = function() { return typeof window[globalName] !== 'undefined'; };
        var url = function(bust) { return ocJsUrl(script) + (bust ? '&ocbust=' + Date.now() : ''); };
        var done = function() {
            if (settled || !ready()) return;
            settled = true;
            cb();
        };
        ocRequireScript(url(false), done);
        setTimeout(function() {
            done();
            if (settled) return;
            ocRequireScript(url(true), done);
            setTimeout(function() {
                done();
                if (!settled) ocAlert('<%:Failed to load the interface, please refresh the page and try again%>');
            }, 5000);
        }, 1500);
    }

    function setSubscriptionUrl() {
        var currentConfig = ConfigFileManager.getSelectedConfig();
        if (!currentConfig) {
            ocAlert('<%:Please select a config file first%>');
            return false;
        }

        var filename = SubscriptionManager.extractFilename(currentConfig);
        if (!filename) {
            ocAlert('<%:Invalid config file selected%>');
            return false;
        }

        requireEditorScript('config_upload.js', 'ConfigUploader', function() {
            if (typeof SubscriptionUrlSetter !== 'undefined' && SubscriptionUrlSetter.show) {
                SubscriptionUrlSetter.show(filename, "refreshSubscriptionInfo()");
            } else {
                ocAlert('<%:Failed to load the interface, please refresh the page and try again%>');
            }
        });

        return false;
    }

    function uploadConfig() {
        requireEditorScript('config_upload.js', 'ConfigUploader', function() {
            if (typeof ConfigUploader !== 'undefined' && ConfigUploader.show) {
                ConfigUploader.show("ConfigFileManager.refreshConfigList()");
            } else {
                ocAlert('<%:Failed to load the interface, please refresh the page and try again%>');
            }
        });

        return false;
    }

    var restoreBackupInput = null;

    function restoreBackupFile() {
        if (!restoreBackupInput) {
            restoreBackupInput = document.createElement('input');
            restoreBackupInput.type = 'file';
            restoreBackupInput.accept = '.tar.gz,.tgz,application/gzip';
            restoreBackupInput.style.display = 'none';
            document.body.appendChild(restoreBackupInput);

            restoreBackupInput.addEventListener('change', function() {
                var file = restoreBackupInput.files && restoreBackupInput.files[0];
                if (!file) return;

                var formData = new FormData();
                formData.append('backup_file', file, file.name);

                fetch('<%=url("admin", "services", "openclash", "restore_backup")%>', {
                    method: 'POST',
                    body: formData
                }).then(function(r) {
                    if (!r.ok) throw new Error('HTTP ' + r.status);
                    return r.json();
                }).then(function(data) {
                    if (data.status === 'success') {
                        ocToast('<%:Backup File Restore Successful!%>', 'success');
                        setTimeout(function() { window.location.reload(); }, 1200);
                    } else {
                        ocToast('<%:Backup File Restore Failed!%>', 'error');
                    }
                }).catch(function() {
                    ocToast('<%:Backup File Restore Failed!%>', 'error');
                });
            });
        }

        restoreBackupInput.value = '';
        restoreBackupInput.click();

        return false;
    }

    function showConfigSummary() {
        var currentConfig = ConfigFileManager.getSelectedConfig();
        if (!currentConfig) {
            ocAlert('<%:Please select a config file first%>');
            return false;
        }
        var filename = SubscriptionManager.extractFilename(currentConfig);
        if (!filename) {
            ocAlert('<%:Invalid config file selected%>');
            return false;
        }

        function openSummary() {
            if (typeof ConfigUploader !== 'undefined' && ConfigUploader.showSummary) {
                ConfigUploader.showSummary(filename, "ConfigFileManager.refreshConfigList()");
            } else {
                ocAlert('<%:Failed to load the interface, please refresh the page and try again%>');
            }
        }
        requireEditorScript('config_upload.js', 'ConfigUploader', openSummary);

        return false;
    }

    function ocOpenCoreStartFlow() {
        requireEditorScript('config_upload.js', 'CoreStartFlow', function() {
            if (typeof CoreStartFlow !== 'undefined' && CoreStartFlow.view) CoreStartFlow.view();
        });
    }

    function editSubscribe() {
        var currentConfig = ConfigFileManager.getSelectedConfig();
        if (!currentConfig) {
            ocAlert('<%:Please select a config file first%>');
            return false;
        }

        var filename = SubscriptionManager.extractFilename(currentConfig);
        if (!filename) {
            ocAlert('<%:Invalid config file selected%>');
            return false;
        }

        XHR.get('<%=url("admin", "services", "openclash", "get_subscribe_data")%>', {
            filename: filename
        }, function(x, status) {
            if (x.status == 200) {
                    requireEditorScript('config_upload.js', 'ConfigUploader', function() {
                        if (typeof ConfigUploader !== 'undefined' && ConfigUploader.showEditSubscribe) {
                            ConfigUploader.showEditSubscribe(status, filename, "ConfigFileManager.refreshConfigList()");
                        } else {
                            ocAlert('<%:Failed to load the interface, please refresh the page and try again%>');
                        }
                    });
                } else {
                    ocAlert('<%:Failed to get subscribe data%>');
                }
            });

        return false;
    }

    function editConfig() {
        var currentConfig = ConfigFileManager.getSelectedConfig();
        if (!currentConfig) {
            ocAlert('<%:Please select a config file first%>');
            return false;
        }

        if (typeof ConfigEditor !== 'undefined' && ConfigEditor.show) {
            ConfigEditor.show(currentConfig);
        } else {
            ocLoadCss(ocCssUrl('oc-config-edit.css'));
            requireEditorScript('config_edit.js', 'ConfigEditor', function() {
                if (typeof ConfigEditor !== 'undefined' && ConfigEditor.show) {
                    ConfigEditor.show(currentConfig);
                } else {
                    ocAlert('<%:Failed to load the interface, please refresh the page and try again%>');
                }
            });
        }

        return false;
    }

    function editOverwrite() {
        if (typeof ConfigEditor !== 'undefined' && ConfigEditor.showOverwrite) {
            ConfigEditor.showOverwrite();
        } else {
            ocLoadCss(ocCssUrl('oc-config-edit.css'));
            requireEditorScript('config_edit.js', 'ConfigEditor', function() {
                if (typeof ConfigEditor !== 'undefined' && ConfigEditor.showOverwrite) {
                    ConfigEditor.showOverwrite();
                } else {
                    ocAlert('<%:Failed to load the interface, please refresh the page and try again%>');
                }
            });
        }

        return false;
    }

    function switchToPreviousConfig() {
        if (ConfigFileManager.configList.length > 1) {
            var newIndex = ConfigFileManager.currentConfigIndex - 1;
            if (newIndex < 0) {
                newIndex = ConfigFileManager.configList.length - 1;
            }
            ConfigFileManager.switchToConfigByIndex(newIndex);
        }
        return false;
    }

    function switchToNextConfig() {
        if (ConfigFileManager.configList.length > 1) {
            var newIndex = ConfigFileManager.currentConfigIndex + 1;
            if (newIndex >= ConfigFileManager.configList.length) {
                newIndex = 0;
            }
            ConfigFileManager.switchToConfigByIndex(newIndex);
        }
        return false;
    }

    var themePanel = null;
    var themePanelOpen = false;

    var themeChoices = [
        { id: 'classic', name: '<%:Classic Blue%>', sw: ['#3b82f6', '#60a5fa'] },
        { id: 'cyan', name: '<%:Nocturne Cyan%>', sw: ['#0e7490', '#22d3ee'] },
        { id: 'indigo', name: '<%:Indigo Voyage%>', sw: ['#4f46e5', '#818cf8'] },
        { id: 'graphite', name: '<%:Graphite Silver%>', sw: ['#374151', '#9ca3af'] },
        { id: 'amber', name: '<%:Ember Amber%>', sw: ['#b45309', '#f59e0b'] },
        { id: 'imperial', name: '<%:Imperial Purple%>', sw: ['#6a0dad', '#c084fc'] },
        { id: 'rose', name: '<%:Sweet Rose%>', sw: ['#d6256a', '#f06292'] },
        { id: 'smoky', name: '<%:Smoky Pink%>', sw: ['#a8557d', '#e89aaf'] }
    ];

    function buildThemePanel() {
        var panel = document.createElement('div');
        panel.className = 'oc oc-theme-panel oc-hidden';
        panel.id = 'oc-theme-panel';
        panel.setAttribute('role', 'dialog');
        panel.setAttribute('aria-label', '<%:Switch Theme%>');

        var themes = themeChoices.map(function(t) {
            return '<button type="button" class="tp-theme" data-theme="' + t.id + '" aria-pressed="false">'
                + '<span class="tp-sw"><i style="background:' + t.sw[0] + '"></i><i style="background:' + t.sw[1] + '"></i></span>'
                + '<span class="tp-name">' + t.name + '</span></button>';
        }).join('');

        panel.innerHTML = '<div class="tp-head">'
            + '<div class="tp-title"><%:Switch Theme%></div>'
            + '<button type="button" class="icon-btn" id="tp-close" title="<%:Close%>"><svg width="14" height="14"><use href="#oc-icon-close"/></svg></button>'
            + '</div>'
            + '<div class="tp-label"><%:Mode%></div>'
            + '<div class="tp-seg" id="tp-modes">'
            + '<button type="button" class="tp-opt" data-mode="light" aria-pressed="false"><%:Light%></button>'
            + '<button type="button" class="tp-opt" data-mode="dark" aria-pressed="false"><%:Dark%></button>'
            + '<button type="button" class="tp-opt" data-mode="auto" aria-pressed="false"><%:Auto%></button>'
            + '</div>'
            + '<div class="tp-label"><span><%:Theme%></span><span class="tp-hint"><%:Applies to all OpenClash pages%></span></div>'
            + '<div class="tp-grid" id="tp-themes">' + themes + '</div>'
            + '<div class="tp-custom" id="tp-custom">'
            + '<label class="tp-custom-main" for="tp-color">'
            + '<span class="tp-sw" id="tp-custom-sw"><i></i><i></i></span>'
            + '<span class="tp-name"><%:Custom%></span>'
            + '<span class="tp-hex" id="tp-custom-hex"></span>'
            + '</label>'
            + '<button type="button" class="tp-custom-apply" id="tp-custom-apply"><%:Apply%></button>'
            + '<input type="color" id="tp-color" value="#3b82f6">'
            + '</div>';

        panel.addEventListener('click', function(e) {
            var t = e.target;
            while (t && t !== panel && !t.classList.contains('tp-opt') && !t.classList.contains('tp-theme')) t = t.parentNode;
            if (!t || t === panel) return;
            if (t.classList.contains('tp-opt')) {
                localStorage.setItem('oc-theme', t.getAttribute('data-mode'));
                ocUpdateTheme();
                DarkModeDetector.init();
                StatsChart.refresh();
            } else {
                ocCustomPreviewHex = null;
                localStorage.setItem('oc-theme-name', t.getAttribute('data-theme'));
                localStorage.removeItem('oc-theme-custom');
                ocApplyRootTheme();
                StatsChart.refresh();
            }
            ocSaveThemeToUci();
            syncThemePanel();
        });

        panel.querySelector('#tp-close').addEventListener('click', function() { setThemePanel(false); });
        var colorInput = panel.querySelector('#tp-color');
        function previewCustom(hex) {
            hex = hex.toLowerCase();
            var sw = panel.querySelectorAll('#tp-custom-sw i');
            sw[0].style.background = hex;
            sw[1].style.background = ocShadeHex(hex, 0.25);
            panel.querySelector('#tp-custom-hex').textContent = hex;
        }
        colorInput.addEventListener('input', function() { previewCustom(colorInput.value); });
        colorInput.addEventListener('change', function() {
            var hex = colorInput.value.toLowerCase();
            previewCustom(hex);
            ocCustomPreviewHex = hex;
            document.documentElement.setAttribute('data-oc-theme', 'custom');
            ocApplyCustomAccent();
            StatsChart.refresh();
        });
        panel.querySelector('#tp-custom-apply').addEventListener('click', function() {
            ocCustomPreviewHex = null;
            localStorage.setItem('oc-theme-custom', colorInput.value.toLowerCase());
            localStorage.setItem('oc-theme-name', 'custom');
            ocApplyRootTheme();
            ocSaveThemeToUci();
            StatsChart.refresh();
            setThemePanel(false);
        });

        document.body.appendChild(panel);
        return panel;
    }

    function syncThemePanel() {
        if (!themePanel) return;
        var mode = localStorage.getItem('oc-theme') || 'auto';
        var name = localStorage.getItem('oc-theme-name') || 'classic';
        var opts = themePanel.querySelectorAll('.tp-opt');
        for (var i = 0; i < opts.length; i++) {
            var on = opts[i].getAttribute('data-mode') === mode;
            opts[i].classList.toggle('on', on);
            opts[i].setAttribute('aria-pressed', on ? 'true' : 'false');
        }
        var cards = themePanel.querySelectorAll('.tp-theme');
        for (var j = 0; j < cards.length; j++) {
            var sel = cards[j].getAttribute('data-theme') === name;
            cards[j].classList.toggle('on', sel);
            cards[j].setAttribute('aria-pressed', sel ? 'true' : 'false');
        }
        var custom = themePanel.querySelector('#tp-custom');
        if (custom) {
            var hex, pair;
            if (name === 'custom') {
                hex = ocSafeHex(localStorage.getItem('oc-theme-custom'));
                pair = [hex, ocShadeHex(hex, 0.25)];
            } else {
                var choice = null;
                for (var k = 0; k < themeChoices.length; k++) {
                    if (themeChoices[k].id === name) choice = themeChoices[k];
                }
                pair = choice ? choice.sw : ['#3b82f6', '#60a5fa'];
                hex = pair[0];
            }
            custom.classList.toggle('on', name === 'custom');
            themePanel.querySelector('#tp-color').value = hex;
            var sw = custom.querySelectorAll('.tp-sw i');
            sw[0].style.background = pair[0];
            sw[1].style.background = pair[1];
            themePanel.querySelector('#tp-custom-hex').textContent = hex;
        }
    }

    function positionThemePanel() {
        var btn = document.getElementById('theme-toggle');
        if (!themePanel || !btn) return;
        var r = btn.getBoundingClientRect();
        var w = themePanel.offsetWidth;
        var h = themePanel.offsetHeight;
        var left = Math.max(8, Math.min(r.right - w, window.innerWidth - w - 8));
        var top = r.bottom + 8;
        if (top + h > window.innerHeight - 8) top = Math.max(8, r.top - h - 8);
        themePanel.style.left = left + 'px';
        themePanel.style.top = top + 'px';
    }

    function setThemePanel(open) {
        if (!themePanel) themePanel = buildThemePanel();
        themePanelOpen = open;
        themePanel.classList.toggle('oc-hidden', !open);
        var btn = document.getElementById('theme-toggle');
        if (btn) btn.setAttribute('aria-expanded', open ? 'true' : 'false');
        if (open) {
            syncThemePanel();
            positionThemePanel();
        } else {
            if (ocCustomPreviewHex) {
                ocCustomPreviewHex = null;
                ocApplyRootTheme();
            }
            if (btn && themePanel.contains(document.activeElement)) {
                btn.focus();
            }
        }
    }

    function openThemePanel(btn) {
        if (!themePanel) {
            themePanel = buildThemePanel();
            document.addEventListener('keydown', function(e) {
                if (e.key === 'Escape' && themePanelOpen) setThemePanel(false);
            });
            window.addEventListener('resize', function() { if (themePanelOpen) positionThemePanel(); });
            window.addEventListener('scroll', function() { if (themePanelOpen) positionThemePanel(); }, true);
        }
        setThemePanel(!themePanelOpen);
        return false;
    }
