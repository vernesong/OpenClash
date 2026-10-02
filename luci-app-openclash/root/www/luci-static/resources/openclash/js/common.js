// OpenClash shared utilities

// Version/language read from this file's own URL (translate_js?f=common&v=&l=); shared by all page scripts.
var ocScriptUrl = (document.currentScript && document.currentScript.src) || '';
window.ocPluginVer = (ocScriptUrl.match(/[?&]v=([^&]*)/) || [])[1] || '';
window.ocLang = (ocScriptUrl.match(/[?&]l=([^&]*)/) || [])[1] || '';
if (!window.ocCM6Url) window.ocCM6Url = '/luci-static/resources/openclash/js/cm6.min.js?v=' + window.ocPluginVer;

// Load CodeMirror 6 on demand (pages that only need it after a user action)
function ocRequireCM6(cb) {
    if (window.CM6) { if (cb) cb(); return; }
    if (!window.ocCM6Waiters) window.ocCM6Waiters = [];
    if (cb) window.ocCM6Waiters.push(cb);
    if (window.ocCM6State === 1 || window.ocCM6State === 2) return;
    window.ocCM6State = 1;
    // CM6 styles travel with the bundle (pages that never open an editor never fetch it)
    if (!window.ocCM6CssInjected) {
        window.ocCM6CssInjected = true;
        var l = document.createElement('link');
        l.rel = 'stylesheet';
        l.href = (window.ocCM6Url || '/luci-static/resources/openclash/js/cm6.min.js').replace('/js/cm6.min.js', '/css/oc-cm6.css');
        document.head.appendChild(l);
    }
    var s = document.createElement('script');
    s.src = window.ocCM6Url || '/luci-static/resources/openclash/js/cm6.min.js';
    s.onload = function() {
        window.ocCM6State = 2;
        var waiters = window.ocCM6Waiters;
        window.ocCM6Waiters = [];
        for (var i = 0; i < waiters.length; i++) {
            try { waiters[i](); } catch (e) {}
        }
    };
    s.onerror = function() {
        window.ocCM6State = 0;
        // wake the waiters anyway so editors fall back to their textarea instead of keeping the overlay
        var failed = window.ocCM6Waiters;
        window.ocCM6Waiters = [];
        for (var i = 0; i < failed.length; i++) {
            try { failed[i](); } catch (e) {}
        }
    };
    document.head.appendChild(s);
}

function luminanceFromColor(color) {
    var r, g, b;

    if (color.indexOf('lab(') === 0) {
        var labM = color.match(/[\d.]+%?/g);
        if (labM && labM.length >= 1) {
            var L = parseFloat(labM[0]);
            return L * 2.55;
        }
        return 128;
    }

    if (color[0] === '#') {
        if (color.length === 4) {
            r = parseInt(color[1] + color[1], 16);
            g = parseInt(color[2] + color[2], 16);
            b = parseInt(color[3] + color[3], 16);
        } else {
            r = parseInt(color.substr(1, 2), 16);
            g = parseInt(color.substr(3, 2), 16);
            b = parseInt(color.substr(5, 2), 16);
        }
    } else {
        var m = color.match(/[\d.]+/g);
        if (!m || m.length < 3) return 128;
        r = parseInt(m[0]); g = parseInt(m[1]); b = parseInt(m[2]);
    }
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

// Dark detection order: HTML data-* attributes, HTML class names, theme localStorage keys,
// CSS background luminance, then the system preference
function detectInitialAutoDark() {
    var html = document.documentElement,
        v, cls, lum;
    var bs = html.getAttribute('data-bs-theme'),
        th = html.getAttribute('data-theme'),
        dm = html.getAttribute('data-darkmode');
    v = bs || th || dm;
    if (v === 'dark' || v === 'dim' || v === 'true') return true;
    if (v === 'light' || v === 'false') return false;
    cls = ' ' + (html.className || '') + ' ';
    if (cls.indexOf(' dark ') >= 0 || cls.indexOf(' dark-mode ') >= 0 ||
        cls.indexOf(' theme-dark ') >= 0 || cls.indexOf(' night-mode ') >= 0) return true;
    var keys = [['mode', 'dark'], ['dark_mode', '1'], ['argon_dark_mode', '1'],
                ['theme', 'dark'], ['luci-theme-mode', 'dark']];
    for (var i = 0; i < keys.length; i++) {
        v = localStorage.getItem(keys[i][0]);
        if (v === keys[i][1]) return true;
        if (v === 'light' || v === '0' || v === 'false') return false;
    }
    var style = getComputedStyle(html),
        checkBg = style.getPropertyValue('--bs-body-bg').trim()
               || style.getPropertyValue('--body-bg').trim()
               || style.getPropertyValue('--theme-bg').trim();
    if (checkBg && checkBg !== 'transparent' && checkBg !== 'rgba(0, 0, 0, 0)')
        return luminanceFromColor(checkBg) < 128;

    return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
}

function isDarkBackground(element) {
    var cachedTheme = localStorage.getItem('oc-theme');
    if (cachedTheme === 'dark') return true;
    if (cachedTheme === 'light') return false;

    var style = window.getComputedStyle(element);
    var bgColor = style.backgroundColor;
    if (!bgColor || bgColor === 'transparent' || bgColor === 'rgba(0, 0, 0, 0)') {
        bgColor = window.getComputedStyle(document.documentElement).backgroundColor;
    }
    var lum = luminanceFromColor(bgColor);
    if (lum > 100 && lum < 156 && window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) return true;
    return lum < 128;
}

/* palette ids, kept in sync with the panel list in status.js */
var ocThemeNames = ['classic', 'cyan', 'indigo', 'graphite', 'amber', 'imperial', 'rose', 'smoky', 'custom'];

// non-null while the colour picker shows an unsaved preview (set/cleared by the theme panel)
var ocCustomPreviewHex = null;

function ocApplyRootTheme() {
    var t = localStorage.getItem('oc-theme') || 'auto',
        d;
    if (t === 'dark') {
        d = true;
    } else if (t === 'light') {
        d = false;
    } else {
        d = document.body ? isDarkBackground(document.body) : detectInitialAutoDark();
    }
    document.documentElement.setAttribute('data-darkmode', d ? 'true' : 'false');
    var n = localStorage.getItem('oc-theme-name') || 'classic';
    if (ocThemeNames.indexOf(n) < 0) n = 'classic';
    document.documentElement.setAttribute('data-oc-theme', n);
    ocApplyCustomAccent();
    var m = document.querySelector('meta[name="color-scheme"]');
    if (!m) {
        m = document.createElement('meta');
        m.name = 'color-scheme';
        document.head.appendChild(m);
    }
    m.content = d ? 'dark' : 'light';
}

function ocHexToRgb(hex) {
    return [parseInt(hex.slice(1, 3), 16), parseInt(hex.slice(3, 5), 16), parseInt(hex.slice(5, 7), 16)];
}

// amt > 0 mixes towards white, amt < 0 towards black
function ocShadeHex(hex, amt) {
    var rgb = ocHexToRgb(hex).map(function(v) {
        return Math.max(0, Math.min(255, Math.round(amt >= 0 ? v + (255 - v) * amt : v * (1 + amt))));
    });
    return '#' + rgb.map(function(v) {
        return ('0' + v.toString(16)).slice(-2);
    }).join('');
}

function ocHexToHsl(hex) {
    var rgb = ocHexToRgb(hex).map(function(v) { return v / 255; }),
        max = Math.max(rgb[0], rgb[1], rgb[2]),
        min = Math.min(rgb[0], rgb[1], rgb[2]),
        l = (max + min) / 2,
        d = max - min,
        h = 0,
        s = 0;
    if (d) {
        s = d / (1 - Math.abs(2 * l - 1));
        if (max === rgb[0]) h = (rgb[1] - rgb[2]) / d + (rgb[1] < rgb[2] ? 6 : 0);
        else if (max === rgb[1]) h = (rgb[2] - rgb[0]) / d + 2;
        else h = (rgb[0] - rgb[1]) / d + 4;
        h *= 60;
    }
    return [h, s * 100, l * 100];
}

function ocHslHex(h, s, l) {
    s /= 100;
    l /= 100;
    var c = (1 - Math.abs(2 * l - 1)) * s,
        x = c * (1 - Math.abs(h / 60 % 2 - 1)),
        m = l - c / 2,
        rgb = h < 60 ? [c, x, 0] : h < 120 ? [x, c, 0] : h < 180 ? [0, c, x] : h < 240 ? [0, x, c] : h < 300 ? [x, 0, c] : [c, 0, x];
    return '#' + rgb.map(function(v) {
        return ('0' + Math.round((v + m) * 255).toString(16)).slice(-2);
    }).join('');
}

function ocAccentVars(hex, dark) {
    var base = dark ? ocShadeHex(hex, 0.25) : hex,
        rgb = ocHexToRgb(base),
        lum = rgb[0] * 0.2126 + rgb[1] * 0.7152 + rgb[2] * 0.0722,
        hsl = ocHexToHsl(hex),
        hue = hsl[0],
        sat = hsl[1],
        vars = '--primary-color:' + base + ';'
            + '--btn-primary-hover:' + ocShadeHex(base, dark ? -0.15 : -0.12) + ';'
            + '--text-on-primary:' + (lum > 170 ? '#1f2937' : '#ffffff') + ';'
            + '--announcement-end:' + ocShadeHex(base, -0.35) + ';'
            + '--radio-hover-bg:rgba(' + rgb.join(', ') + ',' + (dark ? '0.2' : '0.1') + ');'
            + '--primary-a5:rgba(' + rgb.join(', ') + ',0.05);'
            + '--primary-a10:rgba(' + rgb.join(', ') + ',0.1);'
            + '--primary-a20:rgba(' + rgb.join(', ') + ',0.2);'
            + '--primary-a30:rgba(' + rgb.join(', ') + ',0.3);'
            + '--primary-a40:rgba(' + rgb.join(', ') + ',0.4);'
            + '--primary-a50:rgba(' + rgb.join(', ') + ',0.5);'
            + '--primary-a60:rgba(' + rgb.join(', ') + ',0.6);';
    // surfaces and texts tinted by the accent hue, mirroring the named palettes
    if (dark) {
        vars += '--primary-bright:' + ocShadeHex(base, 0.15) + ';--primary-soft:' + ocShadeHex(base, 0.35) + ';'
            + '--bg-white:' + ocHslHex(hue, Math.min(sat, 30), 11) + ';'
            + '--bg-light:' + ocHslHex(hue, Math.min(sat, 30), 14) + ';'
            + '--bg-gray:' + ocHslHex(hue, Math.min(sat, 28), 18) + ';'
            + '--text-primary:' + ocHslHex(hue, Math.min(sat, 35), 94) + ';'
            + '--text-secondary:' + ocHslHex(hue, Math.min(sat, 18), 70) + ';'
            + '--text-title:' + ocHslHex(hue, Math.min(sat, 35), 92) + ';'
            + '--border-light:' + ocHslHex(hue, Math.min(sat, 26), 24) + ';'
            + '--switch-off-bg:' + ocHslHex(hue, Math.min(sat, 24), 28) + ';'
            + '--tab-text-dark:' + ocHslHex(hue, Math.min(sat, 18), 70) + ';'
            + '--tab-hover-dark-bg:' + ocHslHex(hue, Math.min(sat, 28), 18) + ';';
    } else {
        vars += '--bg-light:' + ocHslHex(hue, Math.min(sat, 35), 98) + ';'
            + '--bg-gray:' + ocHslHex(hue, Math.min(sat, 35), 95) + ';'
            + '--text-primary:' + ocHslHex(hue, Math.min(sat, 18), 16) + ';'
            + '--text-secondary:' + ocHslHex(hue, Math.min(sat, 12), 44) + ';'
            + '--text-title:' + ocHslHex(hue, Math.min(sat, 20), 14) + ';'
            + '--border-light:' + ocHslHex(hue, Math.min(sat, 28), 90) + ';'
            + '--switch-off-bg:' + ocHslHex(hue, Math.min(sat, 30), 92) + ';';
    }
    return vars;
}

function ocSafeHex(hex) {
    hex = (hex || '').toLowerCase();
    return /^#[0-9a-f]{6}$/.test(hex) ? hex : '#3b82f6';
}

function ocApplyCustomAccent() {
    var styleEl = document.getElementById('oc-custom-theme'),
        name = localStorage.getItem('oc-theme-name') || 'classic',
        hex = ocCustomPreviewHex;
    if (!hex && name !== 'custom') {
        if (styleEl) styleEl.parentNode.removeChild(styleEl);
        return;
    }
    hex = ocSafeHex(hex || localStorage.getItem('oc-theme-custom'));
    if (!styleEl) {
        styleEl = document.createElement('style');
        styleEl.id = 'oc-custom-theme';
        document.head.appendChild(styleEl);
    }
    styleEl.textContent = 'html[data-oc-theme="custom"] .oc{' + ocAccentVars(hex, false) + '}'
        + 'html[data-darkmode="true"][data-oc-theme="custom"] .oc{' + ocAccentVars(hex, true) + '}';
}

// the router-side copy (uci theme_mode/theme_name/theme_custom) wins on load so every
// browser follows the theme that was saved once
function ocSyncThemeFromUci() {
    var xhr = new XMLHttpRequest();
    xhr.open('GET', '/cgi-bin/luci/admin/services/openclash/theme_get', true);
    xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
    xhr.onreadystatechange = function() {
        if (xhr.readyState !== 4 || xhr.status !== 200) return;
        var d = null;
        try { d = JSON.parse(xhr.responseText); } catch (e) { return; }
        if (!d) return;
        var changed = false;
        if (d.mode && d.mode !== (localStorage.getItem('oc-theme') || 'auto')) { localStorage.setItem('oc-theme', d.mode); changed = true; }
        if (d.name && d.name !== (localStorage.getItem('oc-theme-name') || 'classic')) { localStorage.setItem('oc-theme-name', d.name); changed = true; }
        if (d.custom && /^#[0-9a-f]{6}$/i.test(d.custom) && d.custom !== localStorage.getItem('oc-theme-custom')) { localStorage.setItem('oc-theme-custom', d.custom); changed = true; }
        if (!changed) return;
        ocUpdateTheme();
        if (typeof DarkModeDetector !== 'undefined') DarkModeDetector.init();
        if (typeof StatsChart !== 'undefined' && StatsChart.refresh) StatsChart.refresh();
    };
    xhr.send();
}

function ocSaveThemeToUci() {
    var xhr = new XMLHttpRequest();
    xhr.open('POST', '/cgi-bin/luci/admin/services/openclash/theme_save', true);
    xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
    xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
    xhr.send('mode=' + encodeURIComponent(localStorage.getItem('oc-theme') || 'auto')
        + '&name=' + encodeURIComponent(localStorage.getItem('oc-theme-name') || 'classic')
        + '&custom=' + encodeURIComponent(localStorage.getItem('oc-theme-custom') || ''));
}

function ocInitTheme() {
    if (window.ocThemeInited) {
        ocUpdateTheme();
        return;
    }
    window.ocThemeInited = true;

    ocApplyRootTheme();
    ocSyncThemeFromUci();

    var needsCorrection = (localStorage.getItem('oc-theme') || 'auto') === 'auto';

    function ocDomReady() {
        if (needsCorrection) ocApplyRootTheme();
        ocApplyEditorTheme();
        ocHideEmptyCbiElements();
        ocWrapCbiActions();
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', ocDomReady);
    } else {
        ocDomReady();
    }
}

function ocUpdateTheme() {
    ocApplyRootTheme();
    ocApplyEditorTheme();
}

// React to OS light/dark changes while the theme is on auto (register once per page)
if (window.matchMedia && !window.ocThemeMediaBound) {
    window.ocThemeMediaBound = true;
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function() {
        if ((localStorage.getItem('oc-theme') || 'auto') === 'auto') {
            ocApplyRootTheme();
            if (document.body) ocUpdateTheme();
        }
    });
}

// Level tag text shown in logs, used to colour whole lines by their [Info]/[Warning]/... tag
function ocGetLogColor(log) {
    if (log.indexOf('[<%:Info%>]') >= 0) return 'var(--info-color)';
    if (log.indexOf('[<%:Warning%>]') >= 0) return 'var(--warning-color)';
    if (log.indexOf('[<%:Error%>]') >= 0) return 'var(--error-color)';
    if (log.indexOf('[<%:Debug%>]') >= 0) return 'var(--debug-color)';
    if (log.indexOf('[<%:Tip%>]') >= 0) return 'var(--tip-color)';
    if (log.indexOf('[<%:Watchdog%>]') >= 0) return 'var(--watchdog-color)';
    if (log.indexOf('[<%:Fatal%>]') >= 0) return 'var(--fatal-color)';
    return 'var(--info-color)';
}

function ocLogLevelText(level) {
    if (level === 'info') return '<%:Info%>';
    if (level === 'warning') return '<%:Warning%>';
    if (level === 'error') return '<%:Error%>';
    if (level === 'debug') return '<%:Debug%>';
    if (level === 'tip') return '<%:Tip%>';
    if (level === 'watchdog') return '<%:Watchdog%>';
    if (level === 'fatal') return '<%:Fatal%>';
    return level;
}

// winOpen is called from inline onclick markup generated by Lua models (config-overwrite,
// config-subscribe-edit, servers, settings) and status.htm, so it lives in common.js.
function winOpen(url) {
    var win = window.open(url);
    if (win == null) {
        window.location.href = url;
    }
    return false;
}

function imgerrorfuns(imgobj, imgSrc) {
    setTimeout(function() {
        imgobj.src = imgSrc;
        imgobj.loading = "lazy";
    }, 1000 * 10);
}

function ocMaxScroll(element) {
    var computed = window.getComputedStyle(element);
    var contentHeight = (parseFloat(computed.paddingTop) || 0) + (parseFloat(computed.paddingBottom) || 0);
    var children = element.children;
    for (var i = 0; i < children.length; i++) {
        contentHeight += children[i].offsetHeight || 0;
    }
    var rowGap = parseFloat(computed.rowGap) || 0;
    if (rowGap && children.length > 1) {
        contentHeight += rowGap * (children.length - 1);
    }
    return Math.max(0, contentHeight - element.clientHeight);
}

// Scroll to the bottom, centring the last line (upstream behaviour). A new call cancels the
// running animation and restarts from the current position.
function ocAnimateScroll(element) {
    if (!element) return;
    if (element.ocScrollAnimId) cancelAnimationFrame(element.ocScrollAnimId);
    var start = element.scrollTop;
    var duration = 500;
    var startTime = null;
    function step(timestamp) {
        if (!startTime) startTime = timestamp;
        var elapsed = timestamp - startTime;
        var progress = Math.min(elapsed / duration, 1);
        var eased = 1 - (1 - progress) * (1 - progress);
        var lastChild = element.lastElementChild || element.lastChild;
        var lastLineH = (lastChild && lastChild.offsetHeight) ? lastChild.offsetHeight : 0;
        var maxScroll = Math.max(0, element.scrollHeight - element.clientHeight);
        var target = Math.max(0, element.scrollHeight - (element.clientHeight + lastLineH) / 2);
        if (target > maxScroll) target = maxScroll;
        var distance = target - start;
        element.scrollTop = Math.round(start + distance * eased);
        if (progress < 1) {
            element.ocScrollAnimId = requestAnimationFrame(step);
        } else {
            element.ocScrollAnimId = null;
            element.style.willChange = '';
        }
    }
    element.ocScrollAnimId = requestAnimationFrame(step);
}

function ocPad2(n) {
    return (n < 10 ? '0' : '') + n;
}

function ocRandomInterval(min, max) {
    return Math.floor(Math.random() * (max - min + 1) + min);
}

function ocGetCustomDashboardURL(status) {
    var raw = status && status.dashboard_custom_url ? String(status.dashboard_custom_url).trim() : '';
    if (!raw) return '';
    if (/[\x00-\x20\\<>"{}|^`\x7f-\uffff]/.test(raw) || /%(?![0-9a-f]{2})/i.test(raw)) return '';
    try {
        var parsed = new URL(raw);
        if ((parsed.protocol !== 'http:' && parsed.protocol !== 'https:') || !parsed.hostname || parsed.username || parsed.password) return '';
        return raw;
    } catch (e) {
        return '';
    }
}

function ocGetDashboardBaseURL(status) {
    var publicHost = status.db_foward_domain ? String(status.db_foward_domain).trim() : '';
    var embeddedPortMatch = publicHost.match(/\]:(\d+)(?:[\/?#]|$)/) || publicHost.match(/^(?:https?:\/\/)?[^:\/?#]+:(\d+)(?:[\/?#]|$)/i);
    var embeddedPort = embeddedPortMatch ? embeddedPortMatch[1] : '';
    var publicPort = status.db_foward_port ? String(status.db_foward_port).trim() : '';
    var validPublicPort = /^\d+$/.test(publicPort) && Number(publicPort) > 0 && Number(publicPort) <= 65535;
    var usePublic = !!(status.daip && window.location.hostname !== status.daip && publicHost);
    var rawHost = usePublic ? publicHost : window.location.hostname;
    var proto = usePublic && status.db_forward_ssl != 0 ? 'https:' : 'http:';
    var configuredPort = usePublic ? publicPort : status.cn_port;
    var parsed;

    try {
        parsed = new URL(/^https?:\/\//i.test(rawHost) ? rawHost : 'http://' + rawHost);
        if (!parsed.hostname || parsed.username || parsed.password) throw new Error('invalid dashboard host');
        var legacyPort = embeddedPort || parsed.port;
        parsed.protocol = proto;
        parsed.pathname = '/';
        parsed.search = '';
        parsed.hash = '';
        if (usePublic && validPublicPort) {
            parsed.port = String(configuredPort);
        } else if (usePublic && legacyPort) {
            parsed.port = legacyPort;
        } else if (usePublic) {
            parsed.port = proto === 'https:' ? '443' : '80';
        } else if (!usePublic && configuredPort && /^\d+$/.test(String(configuredPort)) && Number(configuredPort) > 0 && Number(configuredPort) <= 65535) {
            parsed.port = String(configuredPort);
        }
    } catch (e) {
        parsed = new URL('http://' + window.location.hostname);
        if (status.cn_port) parsed.port = status.cn_port;
        usePublic = false;
    }

    var effectivePort = parsed.port || (parsed.protocol === 'https:' ? '443' : '80');
    return { host: parsed.hostname, port: effectivePort, proto: parsed.protocol + '//', origin: parsed.origin, secret: status.dase || '', isPublic: usePublic };
}

// LuCI over https: the control panel API needs the same-origin proxy (nginx /oc-api/),
// the controller has no TLS listener and plain ws:// would be mixed content.
function ocGetDashboardApiOrigin(status) {
    var base = ocGetDashboardBaseURL(status);
    if (!base.isPublic && window.location.protocol === 'https:') {
        return 'https://' + window.location.host + '/oc-api';
    }
    return base.origin;
}

function ocGetDashboardWebSocketOrigin(status) {
    return ocGetDashboardApiOrigin(status).replace(/^http/, 'ws');
}

function ocGetDashboardLoginParams(base, clashCompatible) {
    var params = new URLSearchParams();
    params.set(clashCompatible ? 'host' : 'hostname', base.host);
    params.set('port', base.port);
    if (base.secret) params.set('secret', base.secret);
    return params;
}

function ocBuildExternalDashboardURL(status) {
    var customURL = ocGetCustomDashboardURL(status);
    if (!customURL) return '';

    var base = ocGetDashboardBaseURL(status);
    var clashCompatible = String(status.dashboard_custom_clash_compatible) === '1';
    var parsed = new URL(customURL);
    var params = ocGetDashboardLoginParams(base, clashCompatible);

    if (clashCompatible) {
        var compatHash = parsed.hash.substring(1);
        var compatSeparator = compatHash.indexOf('?');
        var compatParams = new URLSearchParams(compatSeparator === -1 ? '' : compatHash.substring(compatSeparator + 1));
        compatParams.delete('hostname');
        params.forEach(function(value, key) { compatParams.set(key, value); });
        parsed.hash = '#/?' + compatParams.toString();
    } else if (!parsed.hash) {
        parsed.searchParams.delete('host');
        params.forEach(function(value, key) { parsed.searchParams.set(key, value); });
    } else {
        var hash = parsed.hash.substring(1);
        var separator = hash.indexOf('?');
        var route = separator === -1 ? hash : hash.substring(0, separator);
        var hashParams = new URLSearchParams(separator === -1 ? '' : hash.substring(separator + 1));
        hashParams.delete('host');
        params.forEach(function(value, key) { hashParams.set(key, value); });
        parsed.hash = '#' + route + '?' + hashParams.toString();
    }
    return parsed.toString();
}

function ocBuildDashboardURL(status, uiPath, needsSetup) {
    var base = ocGetDashboardBaseURL(status);
    var url = base.origin + '/ui/' + uiPath;
    var params = ocGetDashboardLoginParams(base, uiPath === 'dashboard').toString();
    if (needsSetup) {
        url += '/#/setup?' + params;
    } else if (uiPath === 'yacd') {
        url += '/?' + params;
    } else if (uiPath === 'dashboard') {
        url += '/#/?' + params;
    }
    return url;
}

window.ocFullscreenActive = false;
window.ocMergeShowDifferences = true;
window.ocEditorHotkeysBound = false;
window.ocFullscreenPatch = null;

window.ocZoomLevels = [75, 90, 100, 110, 125, 150, 200];
window.ocCurrentZoom = 100;

// Enter fullscreen: patch ancestor stacking contexts so position:fixed can break
// out (clear the closest backdrop-filter, raise the outermost positioned z-index)
function ocEnterFullscreen(dom) {
    ocExitFullscreen();
    var patch = window.ocFullscreenPatch = {};
    var el = dom.parentNode;
    while (el && el !== document.body && el !== document.documentElement) {
        var cs = window.getComputedStyle(el);
        if (!patch.bfEl) {
            var bf = cs.backdropFilter || cs.webkitBackdropFilter;
            if (bf && bf !== 'none') {
                patch.bfEl = el;
                patch.bfOld = el.style.backdropFilter;
                el.style.backdropFilter = 'none';
            }
        }
        var pos = cs.position;
        var zi = cs.zIndex;
        if ((pos === 'relative' || pos === 'absolute' || pos === 'fixed' || pos === 'sticky') && zi !== 'auto') {
            patch.zEl = el;
            patch.zOld = el.style.zIndex;
        }
        el = el.parentNode;
    }
    if (patch.zEl) {
        patch.zEl.style.setProperty('z-index', '999999', 'important');
    }
}

function ocExitFullscreen() {
    var p = window.ocFullscreenPatch;
    if (!p) return;
    if (p.zEl) {
        if (p.zOld !== undefined && p.zOld !== '') {
            p.zEl.style.zIndex = p.zOld;
        } else {
            p.zEl.style.removeProperty('z-index');
        }
    }
    if (p.bfEl) {
        if (p.bfOld !== undefined && p.bfOld !== '') {
            p.bfEl.style.backdropFilter = p.bfOld;
        } else {
            p.bfEl.style.removeProperty('backdrop-filter');
        }
    }
    window.ocFullscreenPatch = null;
}

// Return the active editor: merge editor state, then the ConfigEditor modal,
// then CM6's own active editor
function ocGetActiveEditorInstance() {
    if (window.mergeEditorState && window.mergeEditorState.instance) {
        return window.mergeEditorState.instance;
    }
    if (window.ConfigEditor && window.ConfigEditor.editorInstance) {
        return window.ConfigEditor.editorInstance;
    }
    if (typeof CM6 !== 'undefined' && CM6.getActiveEditor) {
        return CM6.getActiveEditor();
    }
    return null;
}

// Apply the zoom-{level} class to .cm-editor elements (both panels of a MergeView)
function ocApplyZoom(instance, zoomLevel) {
    var doms = [];
    if (instance) {
        if (instance.a && instance.a.dom && instance.b && instance.b.dom) {
            doms = [instance.a.dom, instance.b.dom];
        } else if (instance.dom) {
            doms = [instance.dom];
        } else if (instance.classList && instance.classList.contains('cm-editor')) {
            doms = [instance];
        }
    }

    if (!doms.length) {
        var activeEl = document.activeElement;
        if (activeEl) {
            var ed = activeEl.closest('.cm-editor');
            if (ed) doms = [ed];
        }
    }
    if (!doms.length) return;

    doms.forEach(function(dom) {
        window.ocZoomLevels.forEach(function(level) {
            dom.classList.remove('zoom-' + level);
        });
        if (zoomLevel !== 100) {
            dom.classList.add('zoom-' + zoomLevel);
        }
    });
    window.ocCurrentZoom = zoomLevel;
}

// Zoom step helpers: return the new level without applying it
function ocZoomIn(currentZoom) {
    var cur = typeof currentZoom === 'number' ? currentZoom : window.ocCurrentZoom;
    var idx = window.ocZoomLevels.indexOf(cur);
    if (idx < window.ocZoomLevels.length - 1) {
        return window.ocZoomLevels[idx + 1];
    }
    return cur;
}

function ocZoomOut(currentZoom) {
    var cur = typeof currentZoom === 'number' ? currentZoom : window.ocCurrentZoom;
    var idx = window.ocZoomLevels.indexOf(cur);
    if (idx > 0) {
        return window.ocZoomLevels[idx - 1];
    }
    return cur;
}

function ocResetZoom() {
    return 100;
}

// Apply the CM6 editor themes and the highlight.js theme for the current dark mode
function ocApplyEditorTheme() {
    var isDark = document.documentElement.getAttribute('data-darkmode') === 'true';
    if (typeof CM6 !== 'undefined' && CM6.dispatchTheme) {
        var editors = document.querySelectorAll('.cm-editor');
        for (var j = 0; j < editors.length; j++) {
            var view = editors[j].cmView && editors[j].cmView.view;
            if (view) {
                try { CM6.dispatchTheme(view, isDark); } catch(e) {}
            }
        }
    }
    if (typeof CM6 !== 'undefined' && CM6.mirrorThemeScrollbar) {
        try { CM6.mirrorThemeScrollbar(); } catch(e) {}
    }
    if (typeof CM6 !== 'undefined' && CM6.switchHljsTheme) {
        CM6.switchHljsTheme(isDark);
    }
}

// Register the editor hotkeys once, in the capture phase so they beat CM6's own key
// handling. Ctrl+Wheel zoom needs a separate non-passive wheel listener.
function ocRegisterEditorHotkeys() {
    if (window.ocEditorHotkeysBound) return;
    window.ocEditorHotkeysBound = true;

    document.addEventListener('keydown', function(e) {
        if ((e.ctrlKey || e.metaKey) && (e.key === '=' || e.key === '+')) {
            var inst = ocGetActiveEditorInstance();
            if (inst) {
                e.preventDefault();
                var newZoom = ocZoomIn();
                ocApplyZoom(inst, newZoom);
            }
            return;
        }

        if ((e.ctrlKey || e.metaKey) && e.key === '-') {
            var inst = ocGetActiveEditorInstance();
            if (inst) {
                e.preventDefault();
                var newZoom = ocZoomOut();
                ocApplyZoom(inst, newZoom);
            }
            return;
        }

        if ((e.ctrlKey || e.metaKey) && e.key === '0') {
            var inst = ocGetActiveEditorInstance();
            if (inst) {
                e.preventDefault();
                var newZoom = ocResetZoom();
                ocApplyZoom(inst, newZoom);
            }
            return;
        }

        if (e.key === 'F11') {
            e.preventDefault();
            if (window.ocFullscreenActive) {
                var fsEl = document.getElementById('oc-fullscreen-active');
                if (fsEl && typeof CM6 !== 'undefined' && CM6.toggleFullscreen) {
                    CM6.toggleFullscreen(fsEl);
                }
                ocExitFullscreen();
                window.ocFullscreenActive = false;
                if (window.ConfigEditor) window.ConfigEditor.isFullscreen = false;
            } else {
                if (typeof CM6 !== 'undefined' && CM6.getActiveEditor && CM6.toggleFullscreen) {
                    var target = CM6.getActiveEditor();
                    if (target) {
                        ocEnterFullscreen(target);
                        window.ocFullscreenActive = !!CM6.toggleFullscreen(target);
                        if (window.ConfigEditor) window.ConfigEditor.isFullscreen = window.ocFullscreenActive;
                    }
                }
            }
            ocApplyEditorTheme();
            return;
        }

        if (e.key === 'F10' && window.mergeViewInstance && window.mergeViewInstance.reconfigure) {
            e.preventDefault();
            window.ocMergeShowDifferences = !window.ocMergeShowDifferences;
            window.mergeViewInstance.reconfigure({
                highlightChanges: window.ocMergeShowDifferences,
                gutter: window.ocMergeShowDifferences
            });
            if (window.mergeViewInstance.dom) {
                window.mergeViewInstance.dom.classList.toggle('oc-diff-hidden', !window.ocMergeShowDifferences);
            }
            return;
        }

        if (e.key === 'Escape' && window.ocFullscreenActive) {
            e.preventDefault();
            e.stopPropagation();
            var fsEl = document.getElementById('oc-fullscreen-active');
            if (fsEl && typeof CM6 !== 'undefined' && CM6.toggleFullscreen) {
                CM6.toggleFullscreen(fsEl);
            }
            ocExitFullscreen();
            window.ocFullscreenActive = false;
            if (window.ConfigEditor) window.ConfigEditor.isFullscreen = false;
            ocApplyEditorTheme();
        }
    }, true);

    document.addEventListener('wheel', function(e) {
        if (e.ctrlKey || e.metaKey) {
            if (e.target.closest && e.target.closest('#config-editor-overlay')) return;
            var inst = ocGetActiveEditorInstance();
            if (inst) {
                e.preventDefault();
                var newZoom = e.deltaY < 0 ? ocZoomIn() : ocZoomOut();
                ocApplyZoom(inst, newZoom);
            }
        }
    }, { passive: false });
}

function ocHideEmptyCbiElements() {
    var emptyEls = document.querySelectorAll('.cbi-section-table-titles, .cbi-section-table-descr, .cbi-section-descr');
    for (var i = 0; i < emptyEls.length; i++) {
        if (emptyEls[i].textContent.trim() === '') { emptyEls[i].style.display = 'none'; }
    }
}

// Tags the legacy cbi action buttons (.cbi-button inside the known id cells) with .oc so
// the shared variables and the footer-btn look in oc-common.css (.oc.cbi-button) apply;
// the host table also gets .oc-cbi-table so its fixed layout gives every button one width.
function ocWrapCbiActions() {
    var ids = ['Commit', 'Apply', 'Create', 'Back', 'Load_Config', 'Refresh',
        'Delete_Unused_Servers', 'Delete_Servers', 'Delete_Proxy_Provider', 'Delete_Groups', 'Delete_all',
        'proxy_mg', 'rule_mg', 'pro_mg'];
    for (var i = 0; i < ids.length; i++) {
        var btns = document.querySelectorAll('[id$="-' + ids[i] + '"] .cbi-button');
        for (var j = 0; j < btns.length; j++) {
            btns[j].classList.add('oc');
            var tbl = btns[j].closest('table');
            if (tbl) tbl.classList.add('oc-cbi-table');
        }
    }
}

var ocLoadingMap = typeof WeakMap !== 'undefined' ? new WeakMap() : (function(){
    var m = {};
    return {
        get: function(k) { return m[k.ocLid]; },
        set: function(k, v) { var id = '_ocl' + Math.random(); k.ocLid = id; m[id] = v; },
        delete: function(k) { delete m[k.ocLid]; }
    };
})();

function ocShowLoading(container, message, minHeight) {
    if (!container) return;
    if (ocLoadingMap.get(container)) return;
    var prevPos = container.style.position;
    var prevMinH = container.style.minHeight;
    container.style.position = 'relative';
    if (minHeight) container.style.minHeight = minHeight;
    var el = document.createElement('div');
    el.className = 'config-editor-loading';
    el.innerHTML = '<div class="loading-spinner"></div><span>' + (message || 'Loading\u2026') + '</span>';
    container.appendChild(el);
    ocLoadingMap.set(container, { el: el, prevPos: prevPos, prevMinH: prevMinH });
}

function ocHideLoading(container) {
    if (!container) return;
    var handle = ocLoadingMap.get(container);
    if (!handle) return;
    if (handle.el && handle.el.parentNode) handle.el.remove();
    container.style.position = handle.prevPos || '';
    if (handle.prevMinH !== undefined) {
        container.style.minHeight = handle.prevMinH;
    }
    ocLoadingMap.delete(container);
}

// Injects a stylesheet once; links already stamped by the template are kept as-is.
function ocLoadCss(url) {
    if (!url) return;
    if (!window.ocCssState) window.ocCssState = {};
    if (window.ocCssState[url]) return;
    var links = document.head.querySelectorAll('link[rel="stylesheet"]');
    for (var i = 0; i < links.length; i++) {
        if (links[i].getAttribute('href') === url) { window.ocCssState[url] = true; return; }
    }
    window.ocCssState[url] = true;
    var link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = url;
    document.head.appendChild(link);
}

function ocRequireScript(url, cb) {
    if (!url) return;
    if (!window.ocScriptState) { window.ocScriptState = {}; window.ocScriptWaiters = {}; }
    var state = window.ocScriptState[url];
    if (state === 2) { if (cb) cb(); return; }
    if (!window.ocScriptWaiters[url]) window.ocScriptWaiters[url] = [];
    if (cb) window.ocScriptWaiters[url].push(cb);
    if (state === 1) return;
    window.ocScriptState[url] = 1;
    var s = document.createElement('script');
    s.src = url;
    s.onload = function() {
        window.ocScriptState[url] = 2;
        var waiters = window.ocScriptWaiters[url] || [];
        window.ocScriptWaiters[url] = [];
        for (var i = 0; i < waiters.length; i++) {
            try { waiters[i](); } catch (e) {}
        }
    };
    s.onerror = function() {
        window.ocScriptState[url] = 0;
        // wake the waiters anyway so editors fall back to their textarea instead of keeping the overlay
        var failed = window.ocScriptWaiters[url] || [];
        window.ocScriptWaiters[url] = [];
        for (var i = 0; i < failed.length; i++) {
            try { failed[i](); } catch (e) {}
        }
    };
    document.head.appendChild(s);
}

// Contract: never-visible containers are never created and repeated queue
// calls for the same container are ignored. The fallback timer covers
// documents whose rendering is throttled while hidden (IntersectionObserver
// never fires there).
function ocQueueEditor(container, factory, onReady) {
    if (!container || typeof factory !== 'function') return;
    if (container.ocQueueStarted) return;
    container.ocQueueStarted = true;
    var started = false;
    function start() {
        if (started) return;
        started = true;
        ocRequireCM6(function() {
            var view = null;
            var failed = false;
            try { view = factory(); } catch (e) { failed = true; if (window.console) console.error(e); }
            if (failed) ocEditorFallback(container.querySelector('textarea'));
            if (view && typeof onReady === 'function') {
                try { onReady(view); } catch (e) {}
            }
        });
    }
    function fallbackCheck() {
        if (started || document.visibilityState !== 'visible') return;
        var cs = getComputedStyle(container);
        if (cs.display === 'none' || (container.offsetParent === null && cs.position !== 'fixed')) return;
        start();
    }
    if (!window.IntersectionObserver || !container.isConnected) { start(); return; }
    var io = new IntersectionObserver(function(entries) {
        for (var i = 0; i < entries.length; i++) {
            if (entries[i].isIntersecting) { io.disconnect(); start(); return; }
        }
    }, { rootMargin: '320px 0px' });
    io.observe(container);
    var fallbackTimer = setTimeout(function() {
        fallbackCheck();
        if (!started) document.addEventListener('visibilitychange', onVisibilityChange);
    }, 4000);
    function onVisibilityChange() {
        if (started) {
            document.removeEventListener('visibilitychange', onVisibilityChange);
            return;
        }
        fallbackCheck();
    }
}

// textarea fallback for a failed CM6 bundle or editor factory: show it again
// instead of leaving the loading overlay behind
function ocEditorFallback(id) {
    if (!id || !id.parentNode) return;
    var container = id.parentNode;
    id.style.display = '';
    if (!container.querySelector('.oc-editor-fallback')) {
        var box = document.createElement('div');
        box.className = 'oc-editor-fallback';
        box.textContent = '<%:Editor failed to load, showing the plain text box%>';
        container.insertBefore(box, id);
    }
    ocHideLoading(container);
}

// Single source for the F10/F11/Esc key hint line shared by the config editors.
function ocEditorHelpHtml(withCompare) {
    var html = '<%:Press%>' + (withCompare ? ' <b class="oc-kbd">F10</b> <%:to toggle differences,%>' : '') +
        ' <b class="oc-kbd">F11</b> <%:for fullscreen,%> <b class="oc-kbd">Esc</b> <%:to exit fullscreen,%>' +
        ' <b class="oc-kbd">Ctrl + <%:Mouse Wheel%></b> <%:to zoom%>';
    return html;
}

// Load an external script (and its optional companion stylesheet) once the anchor
// element approaches the viewport (320px margin). Used for below-the-fold bundles
// whose UI lives further down the page.
function ocLazyScriptOnView(el, url, cssUrl) {
    if (!el || !url) return;
    if (!window.IntersectionObserver) { ocLoadCss(cssUrl); ocRequireScript(url); return; }
    var io = new IntersectionObserver(function(entries) {
        for (var i = 0; i < entries.length; i++) {
            if (entries[i].isIntersecting) { io.disconnect(); ocLoadCss(cssUrl); ocRequireScript(url); return; }
        }
    }, { rootMargin: '320px 0px' });
    io.observe(el);
}

// SSE-style log streamer shared by the status overview and the update page.
// The server streams /tmp/openclash_start.log from the beginning and ends the
// response with ##FINISHED## when the watched script exits (##CONTINUE## while
// it is still running). A watch stream that ended without ##FINISHED## reconnects
// after a second; the lines that were already shown are skipped by counting them
// in skipLines / onSkipLines.
// opts: { url, script, initialMessage, skipLines, onSkipLines, maxWaitMs,
//         display(text), onFinish(), onTimeout() }
function ocCreateLogStream(opts) {
    var xhr = null;
    var reconnectTimer = null;
    var maxWaitTimer = null;
    var stopped = false;
    var lastLineCount = opts.skipLines != null ? opts.skipLines : null;
    var watchMode = !!opts.script && opts.script !== 'view';
    var streamUrl = opts.url + (watchMode ? '?script=' + encodeURIComponent(opts.script) : '');

    function openStream() {
        if (stopped) return;
        if (xhr) { xhr.abort(); xhr = null; }
        var req = new XMLHttpRequest();
        req.timeout = 0;
        req.open('GET', streamUrl, true);
        req.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
        var streamEnded = false;
        var processedLength = 0;
        var pendingLine = '';
        var cursorInitialized = false;
        var finishTimer = null;

        function consume(text, flush) {
            if (!cursorInitialized) {
                if (lastLineCount != null) {
                    for (var lineIndex = 0; lineIndex < lastLineCount; lineIndex++) {
                        var newlineIndex = text.indexOf('\n', processedLength);
                        if (newlineIndex < 0) {
                            processedLength = text.length;
                            break;
                        }
                        processedLength = newlineIndex + 1;
                    }
                }
                cursorInitialized = true;
            }
            if (text.length < processedLength) {
                processedLength = 0;
                pendingLine = '';
            }
            pendingLine += text.substring(processedLength);
            processedLength = text.length;
            var parts = pendingLine.split('\n');
            if (flush) {
                pendingLine = '';
            } else {
                pendingLine = parts.pop() || '';
            }
            var raw = parts.join('\n').replace(/##FINISHED##|##CONTINUE##|##FINISH##/g, '');
            if (raw.trim()) opts.display(raw);
        }

        function rememberLines() {
            lastLineCount = (req.responseText || '').replace(/##FINISHED##\s*$|##CONTINUE##\s*$/, '').replace(/\n+$/, '').split('\n').length;
            if (opts.onSkipLines) opts.onSkipLines(lastLineCount);
        }

        function finishPermanent() {
            xhr = null;
            if (maxWaitTimer) { clearTimeout(maxWaitTimer); maxWaitTimer = null; }
            // update the cursor before closing so a restart with skipLines resumes exactly here
            rememberLines();
            try { req.abort(); } catch (e) {}
            if (opts.onFinish) opts.onFinish();
        }

        function scheduleFinish() {
            if (finishTimer) return;
            finishTimer = setTimeout(function() {
                streamEnded = true;
                if (xhr !== req) return;
                finishPermanent();
            }, opts.finishDelayMs || 10000);
        }

        function reconnect() {
            if (stopped || reconnectTimer) return;
            reconnectTimer = setTimeout(function() {
                reconnectTimer = null;
                if (!xhr && !stopped) openStream();
            }, 1000);
        }

        req.onprogress = function() {
            if (xhr !== req || streamEnded) return;
            var text = req.responseText || '';
            consume(text, false);
            if (/##FINISHED##\s*$/.test(text)) scheduleFinish();
        };

        req.onload = function() {
            if (xhr !== req || streamEnded) return;
            var text = req.responseText || '';
            consume(text, true);
            if (!watchMode || /##FINISHED##\s*$/.test(text)) {
                scheduleFinish();
                return;
            }
            if (finishTimer) { clearTimeout(finishTimer); finishTimer = null; }
            streamEnded = true;
            rememberLines();
            xhr = null;
            reconnect();
        };

        req.onerror = function() {
            if (xhr !== req) return;
            if (finishTimer) { clearTimeout(finishTimer); finishTimer = null; }
            streamEnded = true;
            rememberLines();
            xhr = null;
            if (watchMode) reconnect();
        };

        req.send();
        xhr = req;
        if (opts.initialMessage) opts.display(opts.initialMessage);
    }

    function abort() {
        stopped = true;
        if (reconnectTimer) { clearTimeout(reconnectTimer); reconnectTimer = null; }
        if (maxWaitTimer) { clearTimeout(maxWaitTimer); maxWaitTimer = null; }
        if (xhr) { xhr.abort(); xhr = null; }
    }

    return {
        start: function() {
            if (opts.maxWaitMs && !maxWaitTimer) {
                maxWaitTimer = setTimeout(function() {
                    maxWaitTimer = null;
                    abort();
                    if (opts.onTimeout) opts.onTimeout();
                }, opts.maxWaitMs);
            }
            openStream();
        },
        abort: abort,
        isRunning: function() { return !!xhr; }
    };
}

window.ocCopyToClipboard = function(text, btnElement, failMessage) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(function() {
            ocShowCopySuccess(btnElement);
        }).catch(function() {
            ocFallbackCopy(text, btnElement, failMessage);
        });
    } else {
        ocFallbackCopy(text, btnElement, failMessage);
    }
};

function ocShowCopySuccess(element) {
    if (!element) return;
    var origHTML = element.innerHTML;
    element.innerHTML = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>';
    element.classList.add('copy-success');
    setTimeout(function() {
        element.innerHTML = origHTML;
        element.classList.remove('copy-success');
    }, 1500);
}

function ocFallbackCopy(text, btnElement, failMessage) {
    var ta = document.createElement('textarea');
    ta.value = text;
    ta.style.cssText = 'position:fixed;top:0;left:0;opacity:0';
    document.body.appendChild(ta);
    ta.select();
    var ok = false;
    try { ok = document.execCommand('copy'); } catch(e) {}
    document.body.removeChild(ta);
    if (ok) {
        ocShowCopySuccess(btnElement);
    } else if (failMessage) {
        prompt(failMessage, text);
    }
}

function ocSetBtnLoading(btn, loading) {
    var svg = btn.querySelector('svg');
    if (loading) {
        if (svg && !btn.dataset.ocSvgHtml) {
            btn.dataset.ocSvgHtml = svg.outerHTML;
            var spinner = document.createElement('span');
            spinner.className = 'loading-spinner oc-btn-spinner';
            spinner.style.verticalAlign = 'middle';
            var svgW = parseInt(svg.getAttribute('width'), 10);
            var size = (!isNaN(svgW) && svgW > 0) ? svgW : 14;
            spinner.style.width = size + 'px';
            spinner.style.height = size + 'px';
            btn.replaceChild(spinner, svg);
        }
        btn.disabled = true;
    } else {
        btn.disabled = false;
        if (btn.dataset.ocSvgHtml) {
            var holder = document.createElement('span');
            holder.innerHTML = btn.dataset.ocSvgHtml;
            var newSvg = holder.firstChild;
            var cur = btn.querySelector('.loading-spinner');
            if (cur && newSvg) {
                btn.replaceChild(newSvg, cur);
            }
            delete btn.dataset.ocSvgHtml;
        }
    }
}

// Toggle a button's spinner and swap its label while an action runs; the original
// label is kept in ocBtnOriginalText so showing it again needs no second parameter.
function ocSetBtnBusy(btn, busy, busyText) {
    if (!btn) return;
    var btnText = btn.querySelector('span:not(.loading-spinner)');
    if (busy) {
        if (btnText && !btn.dataset.ocBtnOriginalText) {
            btn.dataset.ocBtnOriginalText = btnText.textContent;
        }
        if (btnText && busyText) { btnText.textContent = busyText; }
        ocSetBtnLoading(btn, true);
    } else {
        ocSetBtnLoading(btn, false);
        if (btnText && btn.dataset.ocBtnOriginalText) {
            btnText.textContent = btn.dataset.ocBtnOriginalText;
            delete btn.dataset.ocBtnOriginalText;
        }
    }
}

// bottom-right transient toasts; the stack element carries .oc itself so it keeps the
// theme variables on pages without a common .oc root wrapper.
// Toast whitelist: the client page (status.js/config_edit.js/oixcloud.htm) and the log page;
// other pages use inline status feedback instead
function ocToast(message, kind) {
    if (!message) return null;
    message = String(message).replace(/\s*[:：]\s*$/, '');
    var stack = document.getElementById('ocToastStack');
    if (!stack) {
        stack = document.createElement('div');
        stack.id = 'ocToastStack';
        stack.className = 'oc oc-toast-stack';
        stack.setAttribute('role', 'region');
        stack.setAttribute('aria-label', 'Notifications');
        document.body.appendChild(stack);
    }
    stack.style.bottom = ocToastClearance() + 'px';
    if (kind !== 'success' && kind !== 'error') kind = 'info';
    var icons = {
        success: '<polyline points="20 6 9 17 4 12"></polyline>',
        error: '<line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line>',
        info: '<circle cx="12" cy="12" r="9"></circle><line x1="12" y1="11" x2="12" y2="16"></line><line x1="12" y1="8" x2="12" y2="8.01"></line>'
    };
    var toast = document.createElement('div');
    toast.className = 'oc-toast oc-toast-' + kind;
    toast.setAttribute('role', 'status');
    toast.innerHTML = '<span class="oc-toast-badge"><svg class="oc-toast-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">' + icons[kind] + '</svg></span><span class="oc-toast-text"></span>';
    toast.querySelector('.oc-toast-text').textContent = message;
    stack.appendChild(toast);
    while (stack.children.length > 4) stack.removeChild(stack.firstChild);
    var dismissed = false;
    function dismiss() {
        if (dismissed) return;
        dismissed = true;
        toast.classList.add('oc-toast-out');
        setTimeout(function() {
            if (toast.parentNode) toast.parentNode.removeChild(toast);
        }, 190);
    }
    toast.addEventListener('click', dismiss);
    setTimeout(dismiss, 3200);
    return toast;
}

// keep toasts clear of the floating action buttons (CSS default when the page has none)
function ocToastClearance() {
    var clearance = 86;
    var floats = document.querySelectorAll('.oc-usage-help-float');
    for (var i = 0; i < floats.length; i++) {
        var r = floats[i].getBoundingClientRect();
        if (!r.width && !r.height) continue;
        var need = window.innerHeight - r.top + 12;
        if (need > clearance) clearance = need;
    }
    return clearance;
}

// input modal replacing native prompt() (unavailable in embedded browsers);
// onSubmit(value, setError, close)
function ocPrompt(title, value, onSubmit) {
    var overlay = document.createElement('div');
    overlay.className = 'oc oc-prompt-overlay';
    overlay.innerHTML =
        '<div class="oc-prompt" role="dialog" aria-modal="true">' +
        '<div class="oc-prompt-title"></div>' +
        '<input class="oc-prompt-input" type="text" spellcheck="false">' +
        '<div class="oc-prompt-error" role="alert"></div>' +
        '<div class="oc-prompt-actions">' +
        '<button type="button" class="footer-btn oc-prompt-cancel"></button>' +
        '<button type="button" class="footer-btn oc-prompt-ok"></button>' +
        '</div></div>';
    var win = overlay.firstElementChild;
    var input = win.querySelector('.oc-prompt-input');
    var err = win.querySelector('.oc-prompt-error');
    var prevFocus = document.activeElement;
    win.querySelector('.oc-prompt-title').textContent = title || '';
    win.querySelector('.oc-prompt-cancel').textContent = '<%:Cancel%>';
    win.querySelector('.oc-prompt-ok').textContent = '<%:OK%>';
    input.value = value || '';
    function close() {
        if (overlay.parentNode) overlay.parentNode.removeChild(overlay);
        document.removeEventListener('keydown', onKey, true);
        if (prevFocus && prevFocus.focus) prevFocus.focus();
    }
    function submit() {
        onSubmit(input.value.trim(), function(text) { err.textContent = text || ''; }, close);
    }
    function onKey(e) {
        if (e.key === 'Escape') { e.preventDefault(); close(); }
        else if (e.key === 'Enter' && e.target === input) { e.preventDefault(); submit(); }
    }
    win.querySelector('.oc-prompt-cancel').addEventListener('click', close);
    win.querySelector('.oc-prompt-ok').addEventListener('click', submit);
    overlay.addEventListener('click', function(e) { if (e.target === overlay) close(); });
    document.addEventListener('keydown', onKey, true);
    document.body.appendChild(overlay);
    input.focus();
    input.select();
    return overlay;
}

// confirm modal: resolves the chosen button value, null when dismissed (Esc/backdrop);
// options.buttons: {label, value, kind: 'primary' | 'danger'}
function ocConfirm(options) {
    options = options || {};
    return new Promise(function(resolve) {
        var overlay = document.createElement('div');
        overlay.className = 'oc oc-confirm-overlay';
        var buttonsHtml = '';
        (options.buttons || []).forEach(function(b, i) {
            var kind = b.kind === 'primary' ? ' oc-confirm-primary'
                : (b.kind === 'danger' ? ' oc-confirm-danger' : '');
            buttonsHtml += '<button type="button" class="oc-confirm-btn' + kind +
                '" data-index="' + i + '"></button>';
        });
        overlay.innerHTML =
            '<div class="oc-confirm" role="dialog" aria-modal="true">' +
            '<div class="oc-confirm-title"></div>' +
            '<div class="oc-confirm-body"></div>' +
            '<div class="oc-confirm-actions">' + buttonsHtml + '</div>' +
            '</div>';
        var win = overlay.firstElementChild;
        var prevFocus = document.activeElement;
        if (options.title) {
            win.querySelector('.oc-confirm-title').textContent = options.title;
        } else {
            win.querySelector('.oc-confirm-title').remove();
        }
        win.querySelector('.oc-confirm-body').textContent = options.body || '';
        var nodes = win.querySelectorAll('.oc-confirm-btn');
        var i;
        for (i = 0; i < nodes.length; i++) {
            nodes[i].textContent = (options.buttons[i] && options.buttons[i].label) || '';
            nodes[i].addEventListener('click', (function(index) {
                return function() { close(options.buttons[index].value); };
            })(i));
        }
        function close(value) {
            if (overlay.parentNode) overlay.parentNode.removeChild(overlay);
            document.removeEventListener('keydown', onKey, true);
            if (prevFocus && prevFocus.focus) prevFocus.focus();
            resolve(value);
        }
        function onKey(e) {
            if (e.key === 'Escape') {
                e.preventDefault();
                e.stopPropagation();
                close(null);
            }
        }
        overlay.addEventListener('click', function(e) { if (e.target === overlay) close(null); });
        document.addEventListener('keydown', onKey, true);
        document.body.appendChild(overlay);
        if (nodes.length) nodes[0].focus();
    });
}

ocInitTheme();
