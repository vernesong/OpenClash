// Extracted from luasrc/view/openclash/config_upload.htm - edit this file, not the template.
// <%:Message%> markers and <%=...%> islands are compiled server-side by the "openclash/translate_js" controller action.

var UrlValidator = {
    httpRe: /^https?:\/\/\S+$/i,
    anyProtocolRe: /^[a-zA-Z][a-zA-Z0-9+.-]*:\/\/\S+$/i,

    // Extract individual URLs from input. Supports:
    //   - Newline-separated: url1\nurl2
    //   - | -separated:     url1|url2  (| only when followed by protocol)
    //   - Comma-separated:  node1,https://sub.com
    //   - URL-encoded comma: node1%2Chttps%3A%2F%2Fsub.com
    // Correctly preserves | inside query parameters (e.g., ?lv=2|3|5|6.js).
    extractUrls: function(input, allowNonHttp) {
        if (!input) return [];
        var protocolPat = allowNonHttp ? '[a-zA-Z][a-zA-Z0-9+.-]*://' : 'https?://';
        var protocolRe = new RegExp(protocolPat, 'gi');
        var urls = [];

        function extractFrom(text) {
            var positions = [];
            var m;
            protocolRe.lastIndex = 0;
            while ((m = protocolRe.exec(text)) !== null) {
                positions.push(m.index);
            }
            if (positions.length === 0) return false;

            for (var i = 0; i < positions.length; i++) {
                var start = positions[i];
                var end = (i + 1 < positions.length) ? positions[i + 1] : text.length;
                var raw = text.substring(start, end);
                raw = raw.replace(/[\s|,]+$/, '').trim();
                if (raw) urls.push(raw);
            }
            return true;
        }

        if (!extractFrom(input)) {
            if (/%[23][aA]/i.test(input)) {
                try {
                    var decoded = decodeURIComponent(input);
                    if (decoded !== input) extractFrom(decoded);
                } catch(e) {}
            }
        }

        return urls;
    },

    validateUrl: function(url, allowNonHttp) {
        var urlPart = url.replace(/#name=.*$/, '');
        if (!urlPart) return { valid: false, reason: '<%:Empty URL%>' };

        var re = allowNonHttp ? this.anyProtocolRe : this.httpRe;
        if (!re.test(urlPart)) {
            if (!allowNonHttp && /^[a-zA-Z][a-zA-Z0-9+.-]*:\/\/\S/.test(urlPart)) {
                return { valid: false, reason: '<%:Only HTTP/HTTPS URLs are supported%>' };
            }
            return { valid: false, reason: '<%:Invalid URL format%>' };
        }

        if (/^https?:\/\//i.test(urlPart)) {
            var hostMatch = urlPart.match(/^https?:\/\/([^\/\s?#]+)/i);
            if (!hostMatch || hostMatch[1].length === 0) {
                return { valid: false, reason: '<%:URL missing hostname%>' };
            }
        }
        return { valid: true };
    },

    anyValid: function(urlList, allowNonHttp) {
        for (var i = 0; i < urlList.length; i++) {
            if (this.validateUrl(urlList[i], allowNonHttp).valid) return true;
        }
        return false;
    }
};

var SubscriptionUrlSetter = {
    filename: '',
    onSuccess: '',

    show: function(filename, onSuccess) {
        this.filename = filename;
        this.onSuccess = onSuccess || '';
        var overlay = document.getElementById('subscription-url-overlay');
        var textarea = document.getElementById('subscription-url-textarea');
        if (overlay && textarea) {
            textarea.value = '';
            this.clearError();
            overlay.classList.add('show');
            textarea.focus();
            this.bindEvents();
            this.loadUrls();
        }
    },

    hide: function() {
        var overlay = document.getElementById('subscription-url-overlay');
        if (overlay) {
            overlay.classList.remove('show');
        }
        this.clearError();
        this.unbindEvents();
    },

    bindEvents: function() {
        var textarea = document.getElementById('subscription-url-textarea');
        if (textarea) {
            textarea.addEventListener('keydown', this.handleKeyDown.bind(this));
            textarea.addEventListener('input', this.clearError.bind(this));
        }
    },

    unbindEvents: function() {
        var textarea = document.getElementById('subscription-url-textarea');
        if (textarea) {
            textarea.removeEventListener('keydown', this.handleKeyDown.bind(this));
        }
    },

    clearError: function() {
        var statusEl = document.getElementById('subscription-url-status');
        var textarea = document.getElementById('subscription-url-textarea');
        if (statusEl) statusEl.textContent = '';
        if (textarea) textarea.classList.remove('oc-invalid');
    },

    handleKeyDown: function(event) {
        if (event.key === 'Enter' && (event.ctrlKey || event.metaKey)) {
            this.submit();
        } else if (event.key === 'Escape') {
            this.hide();
        }
    },

    submit: function() {
        var textarea = document.getElementById('subscription-url-textarea');
        if (!textarea) return;

        var urls = textarea.value.trim();
        var urlList = urls.split('\n').map(function(url) {
            return url.trim();
        }).filter(function(url) {
            return url !== '';
        });
        var newUrl = urlList.join('\n');
        var statusEl = document.getElementById('subscription-url-status');

        for (var i = 0; i < urlList.length; i++) {
            var result = UrlValidator.validateUrl(urlList[i], false);
            if (!result.valid) {
                if (statusEl) statusEl.textContent = result.reason;
                textarea.classList.add('oc-invalid');
                return;
            }
        }

        XHR.get('<%=url("admin", "services", "openclash", "set_subinfo_url")%>', {
            filename: this.filename,
            url: newUrl
        }, function(x, status) {
            if (x && x.status == 200 && (status.info === "Success" || status.info === "Delete success")) {
                SubscriptionUrlSetter.hide();
                if (SubscriptionUrlSetter.onSuccess) setTimeout(SubscriptionUrlSetter.onSuccess, 0);
            } else if (statusEl) {
                statusEl.textContent = '<%:Specify subscribe infos sources url failed:%> ' + ((status && status.info) || (x && ('HTTP ' + x.status)) || '<%:Unknown error%>');
            }
        });
    },

    // strip any existing #name= marker before appending, or the chain grows on save
    handleSubURL: function(urlresult) {
        var textarea = document.getElementById('subscription-url-textarea');
        if (!textarea) return;

        var urls = '';
        if (urlresult.type && urlresult.type === "multiple") {
            for (var data in urlresult.providers) {
                var providerUrl = String(urlresult.providers[data].url || '').split('#name=')[0];
                urls += providerUrl + '#name=' + urlresult.providers[data].name + '\n';
            }
        }
        if (urlresult.type && urlresult.type === "single") {
            urls = urlresult.url;
        }
        textarea.value = urls;
    },

    // live endpoint is the source of truth; localStorage only backs it up on failure
    loadUrls: function() {
        var self = this;
        var useCached = function() {
            var existingData = localStorage.getItem('sub_info_' + self.filename);
            if (!existingData) return;
            try {
                existingData = JSON.parse(existingData);
            } catch (e) {
                return;
            }
            if (existingData.url_result) self.handleSubURL(existingData.url_result);
        };

        XHR.get('<%=url("admin", "services", "openclash", "get_subscribe_info_data")%>', {
            filename: this.filename
        }, function(x, status) {
            if (x && x.status == 200 && status) {
                self.handleSubURL(status);
            } else {
                useCached();
            }
        });
    }
};

function ocFormatSize(bytes) {
    var value = parseFloat(bytes);
    if (isNaN(value) || value < 0) return '—';
    var units = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    while (value >= 1024 && i < units.length - 1) {
        value = value / 1024;
        i++;
    }
    return (i === 0 ? String(Math.round(value)) : value.toFixed(1)) + ' ' + units[i];
}

function ocStatBox(value, label, unit) {
    var box = document.createElement('div');
    box.className = 'oc-sub-stat';
    var b = document.createElement('b');
    b.textContent = value;
    if (unit) {
        var u = document.createElement('i');
        u.className = 'oc-stat-unit';
        u.textContent = unit;
        b.appendChild(u);
    }
    var s = document.createElement('span');
    s.textContent = label;
    box.appendChild(b);
    box.appendChild(s);
    return box;
}

function ocSizeStatBox(bytes) {
    var text = ocFormatSize(bytes);
    var sp = text.indexOf(' ');
    return ocStatBox(sp > 0 ? text.slice(0, sp) : text, '<%:Size%>', sp > 0 ? text.slice(sp + 1) : '');
}

function ocCssVar(name, fallback) {
    var root = document.querySelector('.oc') || document.documentElement;
    var value = getComputedStyle(root).getPropertyValue(name);
    value = (value || '').trim();
    return value || fallback;
}

function ocChartTheme() {
    return {
        text: ocCssVar('--text-secondary', '#64748b'),
        border: ocCssVar('--border-light', '#e2e8f0'),
        panel: ocCssVar('--bg-white', '#ffffff'),
        title: ocCssVar('--text-primary', '#374151')
    };
}

function ocChartTooltip(theme, labelCallback) {
    var opts = {
        backgroundColor: theme.panel,
        titleColor: theme.title,
        bodyColor: theme.text,
        borderColor: theme.border,
        borderWidth: 1,
        padding: 8,
        cornerRadius: 6,
        displayColors: true,
        boxWidth: 8,
        boxHeight: 8,
        usePointStyle: true,
        titleFont: { size: 11.5, weight: '600' },
        bodyFont: { size: 11.5 }
    };
    if (labelCallback) opts.callbacks = { label: labelCallback };
    return opts;
}

// suppress the canvas tooltip where a DOM tooltip is used (chart.js draws while opacity > 0)
var ocHideBuiltinTooltip = {
    id: 'ocHideBuiltinTooltip',
    beforeTooltipDraw: function() { return false; }
};

var CHART_PALETTE = ['#3b82f6', '#7c3aed', '#25b5b8', '#f59e0b', '#ec4899', '#059669', '#8b5cf6', '#0ea5e9', '#f97316'];
// neighbouring targets stay far apart in color; green/red reserved for DIRECT/REJECT
var CHART_TARGET_PALETTE = ['#3b82f6', '#f97316', '#a855f7', '#0ea5e9', '#ec4899', '#84cc16', '#6366f1', '#f59e0b', '#14b8a6', '#d946ef'];
var CHART_GRAY = '#94a3b8';
var CHART_LOCAL = '#64748b';

var CHART_PROTO = {
    ss: { name: 'SS', color: '#3b82f6' },
    shadowsocks: { name: 'SS', color: '#3b82f6' },
    ssr: { name: 'SSR', color: '#60a5fa' },
    shadowsocksr: { name: 'SSR', color: '#60a5fa' },
    vmess: { name: 'VMess', color: '#7c3aed' },
    vless: { name: 'VLESS', color: '#a78bfa' },
    trojan: { name: 'Trojan', color: '#059669' },
    hysteria: { name: 'Hysteria', color: '#f59e0b' },
    hysteria2: { name: 'Hysteria2', color: '#f97316' },
    tuic: { name: 'TUIC', color: '#25b5b8' },
    anytls: { name: 'AnyTLS', color: '#ec4899' },
    snell: { name: 'Snell', color: '#8b5cf6' },
    wireguard: { name: 'WireGuard', color: '#64748b' },
    socks5: { name: 'SOCKS5', color: '#0ea5e9' },
    http: { name: 'HTTP', color: '#14b8a6' },
    ssh: { name: 'SSH', color: '#84cc16' },
    mieru: { name: 'Mieru', color: '#d946ef' },
    shadowtls: { name: 'ShadowTLS', color: '#6366f1' }
};

var CHART_RULE_COLORS = {
    'RULE-SET': '#3b82f6', GEOSITE: '#7c3aed', GEOIP: '#25b5b8',
    'DOMAIN-SUFFIX': '#f59e0b', DOMAIN: '#f97316', 'DOMAIN-KEYWORD': '#ec4899',
    'IP-CIDR': '#059669', 'IP-CIDR6': '#10b981', 'PROCESS-NAME': '#8b5cf6',
    'SRC-IP-CIDR': '#0ea5e9', MATCH: '#64748b'
};

var CHART_GROUP_COLORS = { smart: '#7c3aed', select: '#3b82f6', 'url-test': '#f59e0b', fallback: '#25b5b8', 'load-balance': '#ec4899', relay: '#64748b' };

function ocChartProtoInfo(key) {
    var clean = String(key).toLowerCase().replace(/[\s-]/g, '');
    return CHART_PROTO[clean] || null;
}

function ocChartTargetColor(name, index) {
    if (/^DIRECT$/i.test(name) || /直连/.test(name)) return ocCssVar('--success-color', '#059669');
    if (/^REJECT/i.test(name) || /拦截|拒绝/.test(name)) return ocCssVar('--error-color', '#dc2626');
    if (name === 'PASS') return CHART_GRAY;
    return CHART_TARGET_PALETTE[index % CHART_TARGET_PALETTE.length];
}

function ocChartTruncate(text, max) {
    text = String(text);
    return text.length > max ? text.slice(0, max - 1) + '…' : text;
}

function ocChartProtoItems(nodesTypes, providerItems) {
    var raw = {};
    var merge = function(map) {
        for (var key in map) {
            if (Object.prototype.hasOwnProperty.call(map, key)) raw[key] = (raw[key] || 0) + map[key];
        }
    };
    merge(nodesTypes || {});
    for (var i = 0; i < providerItems.length; i++) merge(providerItems[i].types || {});
    var items = [];
    var total = 0;
    for (var key in raw) {
        if (!Object.prototype.hasOwnProperty.call(raw, key)) continue;
        var info = ocChartProtoInfo(key) || { name: key, color: CHART_PALETTE[items.length % CHART_PALETTE.length] };
        items.push({ name: info.name, value: raw[key], color: info.color });
        total += raw[key];
    }
    items.sort(function(a, b) { return b.value - a.value; });
    return { items: items, total: total };
}

function ocChartCountItems(counts, limit, decorate) {
    var keys = [];
    for (var key in counts) {
        if (Object.prototype.hasOwnProperty.call(counts, key)) keys.push(key);
    }
    keys.sort(function(a, b) { return counts[b] - counts[a]; });
    var items = [];
    var shown = Math.min(limit, keys.length);
    var restValue = 0;
    for (var i = 0; i < shown; i++) {
        var info = decorate(keys[i], i);
        items.push({ name: info.name, value: counts[keys[i]], color: info.color });
    }
    for (var j = shown; j < keys.length; j++) restValue += counts[keys[j]];
    if (restValue > 0) items.push({ name: '<%:Other%>', value: restValue, color: CHART_GRAY });
    return items;
}

function ocChartPercentages(items, total) {
    // largest remainder rounding so the shown percentages add up to 100
    var out = [];
    if (!total) return out;
    var floors = [];
    var used = 0;
    for (var i = 0; i < items.length; i++) {
        var exact = items[i].value / total * 100;
        if (exact > 0 && exact < 1) {
            out.push('<1%');
            floors.push(null);
            continue;
        }
        var fl = Math.floor(exact);
        out.push(fl + '%');
        floors.push(exact - fl);
        used += fl;
    }
    var rest = 100 - used;
    while (rest > 0) {
        var best = -1;
        for (var j = 0; j < floors.length; j++) {
            if (floors[j] !== null && floors[j] >= 0 && (best < 0 || floors[j] > floors[best])) best = j;
        }
        if (best < 0) break;
        out[best] = (parseInt(out[best], 10) + 1) + '%';
        floors[best] = -1;
        rest--;
    }
    return out;
}

function ocChartLegend(host, items, total) {
    var percents = ocChartPercentages(items, total);
    for (var i = 0; i < items.length; i++) {
        var item = items[i];
        var leg = document.createElement('span');
        leg.className = 'oc-chart-leg';
        var dot = document.createElement('i');
        dot.style.background = item.color;
        leg.appendChild(dot);
        var name = document.createElement('span');
        name.textContent = item.name;
        leg.appendChild(name);
        var value = document.createElement('b');
        value.textContent = String(item.value);
        leg.appendChild(value);
        if (total) {
            var percent = document.createElement('em');
            percent.textContent = percents[i];
            leg.appendChild(percent);
        }
        leg.title = item.name + ' · ' + item.value;
        host.appendChild(leg);
    }
}

function ocChartDonut(host, items, centerValue, centerLabel) {
    var theme = ocChartTheme();
    var total = 0;
    for (var t = 0; t < items.length; t++) total += items[t].value;
    var wrap = document.createElement('div');
    wrap.className = 'oc-donut-wrap';
    var canvas = document.createElement('canvas');
    wrap.appendChild(canvas);
    var center = document.createElement('div');
    center.className = 'oc-donut-center';
    var value = document.createElement('b');
    value.textContent = centerValue;
    center.appendChild(value);
    var label = document.createElement('span');
    label.textContent = centerLabel;
    center.appendChild(label);
    wrap.appendChild(center);
    host.appendChild(wrap);
    // the 96px canvas would clip a built-in tooltip, so it renders as a DOM layer on the card
    var tip = document.createElement('div');
    tip.className = 'oc-chart-exttip';
    var card = null;
    var mouse = null;
    canvas.addEventListener('mousemove', function(e) { mouse = e; });
    var pctOf = function(value) {
        var pct = total ? value / total * 100 : 0;
        return pct > 0 && pct < 1 ? '<1%' : Math.round(pct) + '%';
    };
    return new Chart(canvas, {
        type: 'doughnut',
        data: {
            labels: items.map(function(i) { return i.name; }),
            datasets: [{
                data: items.map(function(i) { return i.value; }),
                backgroundColor: items.map(function(i) { return i.color; }),
                borderWidth: 1,
                borderColor: theme.panel,
                spacing: 0,
                hoverOffset: 3
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            cutout: '68%',
            devicePixelRatio: Math.min(window.devicePixelRatio || 1, 2),
            animation: { duration: 280 },
            plugins: { legend: { display: false }, tooltip: {
                enabled: true,
                external: function(context) {
                    var model = context.tooltip;
                    if (!model.opacity || !model.dataPoints || !model.dataPoints.length) {
                        tip.classList.remove('show');
                        return;
                    }
                    var item = items[model.dataPoints[0].dataIndex];
                    if (!item) {
                        tip.classList.remove('show');
                        return;
                    }
                    if (!tip.parentNode) {
                        card = host.closest('.oc-chart-card') || host.parentNode;
                        card.appendChild(tip);
                    }
                    tip.innerHTML = '';
                    var line = document.createElement('span');
                    line.className = 'oc-chart-tip-row is-hot';
                    var dot = document.createElement('i');
                    dot.style.background = item.color;
                    line.appendChild(dot);
                    var nameEl = document.createElement('em');
                    nameEl.textContent = item.name;
                    line.appendChild(nameEl);
                    var valEl = document.createElement('span');
                    valEl.textContent = String(item.value);
                    line.appendChild(valEl);
                    var pctEl = document.createElement('u');
                    pctEl.textContent = pctOf(item.value);
                    line.appendChild(pctEl);
                    tip.appendChild(line);
                    tip.classList.add('show');
                    var canvasRect = context.chart.canvas.getBoundingClientRect();
                    var cardRect = card.getBoundingClientRect();
                    var x = mouse ? (mouse.clientX - cardRect.left) : (canvasRect.left - cardRect.left + model.caretX);
                    var y = mouse ? (mouse.clientY - cardRect.top) : (canvasRect.bottom - cardRect.top);
                    var left = Math.max(4, Math.min(x - tip.offsetWidth / 2, card.clientWidth - tip.offsetWidth - 4));
                    tip.style.left = left + 'px';
                    tip.style.top = (y + 14) + 'px';
                }
            } }
        },
        plugins: [ocHideBuiltinTooltip]
    });
}

function ocChartValueLabels() {
    return {
        id: 'ocValueLabels',
        afterDatasetsDraw: function(chart) {
            var theme = ocChartTheme();
            var ctx = chart.ctx;
            var meta = chart.getDatasetMeta(0);
            ctx.save();
            ctx.fillStyle = theme.text;
            ctx.font = '600 10.5px "Microsoft Yahei", sans-serif';
            ctx.textBaseline = 'middle';
            for (var i = 0; i < meta.data.length; i++) {
                var bar = meta.data[i];
                var value = chart.data.datasets[0].data[i];
                if (value == null) continue;
                ctx.fillText(String(value), bar.x + 6, bar.y);
            }
            ctx.restore();
        }
    };
}

function ocChartHBars(host, items, behavior) {
    var theme = ocChartTheme();
    var canvas = document.createElement('canvas');
    host.appendChild(canvas);
    var max = 0;
    var total = 0;
    for (var i = 0; i < items.length; i++) {
        max = Math.max(max, items[i].value);
        total += items[i].value;
    }
    return new Chart(canvas, {
        type: 'bar',
        data: {
            labels: items.map(function(i) { return i.name; }),
            datasets: [{
                data: items.map(function(i) { return i.value; }),
                backgroundColor: items.map(function(i) { return i.color; }),
                borderRadius: 4,
                barThickness: 11
            }]
        },
        options: {
            indexAxis: 'y',
            responsive: true,
            maintainAspectRatio: false,
            devicePixelRatio: Math.min(window.devicePixelRatio || 1, 2),
            animation: { duration: 280 },
            layout: { padding: { right: 30, top: 2, bottom: 2 } },
            onHover: function(evt, elements, chart) {
                var clickable = behavior && elements && elements.length && elements[0].index < behavior.clickable;
                chart.canvas.style.cursor = clickable ? 'pointer' : 'default';
            },
            onClick: function(evt, elements) {
                if (behavior && behavior.onBar && elements && elements.length && elements[0].index < behavior.clickable) {
                    behavior.onBar(elements[0].index);
                }
            },
            scales: {
                x: { display: false, beginAtZero: true, max: max * 1.02 },
                y: {
                    grid: { display: false },
                    border: { display: false },
                    ticks: {
                        color: theme.text,
                        font: { size: 11 },
                        padding: 6,
                        callback: function(value) { return ocChartTruncate(String(this.getLabelForValue(value)), 13); }
                    }
                }
            },
            plugins: {
                legend: { display: false },
                tooltip: ocChartTooltip(theme, function(item) {
                    var pct = total ? Math.round(item.parsed.x / total * 100) : 0;
                    return ' ' + item.parsed.x + ' (' + pct + '%)';
                })
            }
        },
        plugins: [ocChartValueLabels()]
    });
}

function ocChartStackRow(host, items, title) {
    var theme = ocChartTheme();
    var canvas = document.createElement('canvas');
    host.appendChild(canvas);
    var total = 0;
    for (var i = 0; i < items.length; i++) total += items[i].value;
    // the 12px bar canvas cannot host the chart.js tooltip, so it is drawn as a DOM layer on the row
    var tip = document.createElement('div');
    tip.className = 'oc-chart-exttip';
    var row = host.closest('.oc-chart-row') || host.parentNode;
    var mouse = null;
    canvas.addEventListener('mousemove', function(e) { mouse = e; });
    var pctOf = function(value) {
        var pct = total ? value / total * 100 : 0;
        return pct > 0 && pct < 1 ? '<1%' : Math.round(pct) + '%';
    };
    return new Chart(canvas, {
        type: 'bar',
        data: {
            labels: [''],
            datasets: items.map(function(item) {
                return { label: item.name, data: [item.value], backgroundColor: item.color, stack: 's', barThickness: 12, borderColor: theme.panel, borderWidth: 1 };
            })
        },
        options: {
            indexAxis: 'y',
            responsive: true,
            maintainAspectRatio: false,
            devicePixelRatio: Math.min(window.devicePixelRatio || 1, 2),
            animation: false,
            scales: {
                x: { stacked: true, display: false, beginAtZero: true, max: total },
                y: { stacked: true, display: false }
            },
            plugins: {
                legend: { display: false },
                tooltip: {
                    enabled: true,
                    external: function(context) {
                        var model = context.tooltip;
                        if (!model.opacity) {
                            tip.classList.remove('show');
                            return;
                        }
                        if (!tip.parentNode) row.appendChild(tip);
                        var hot = -1;
                        if (model.dataPoints && model.dataPoints.length) hot = model.dataPoints[0].datasetIndex;
                        tip.innerHTML = '';
                        var head = document.createElement('b');
                        head.textContent = title || '';
                        tip.appendChild(head);
                        for (var d = 0; d < items.length; d++) {
                            var line = document.createElement('span');
                            line.className = 'oc-chart-tip-row' + (d === hot ? ' is-hot' : '');
                            var dot = document.createElement('i');
                            dot.style.background = items[d].color;
                            line.appendChild(dot);
                            var nameEl = document.createElement('em');
                            nameEl.textContent = items[d].name;
                            line.appendChild(nameEl);
                            var valEl = document.createElement('span');
                            valEl.textContent = String(items[d].value);
                            line.appendChild(valEl);
                            var pctEl = document.createElement('u');
                            pctEl.textContent = pctOf(items[d].value);
                            line.appendChild(pctEl);
                            tip.appendChild(line);
                        }
                        tip.classList.add('show');
                        var canvasRect = context.chart.canvas.getBoundingClientRect();
                        var rowRect = row.getBoundingClientRect();
                        var x = mouse ? (mouse.clientX - rowRect.left) : (canvasRect.left - rowRect.left + model.caretX);
                        var left = Math.max(4, Math.min(x - tip.offsetWidth / 2, row.clientWidth - tip.offsetWidth - 4));
                        tip.style.left = left + 'px';
                        tip.style.top = (canvasRect.height + 4) + 'px';
                    }
                }
            }
        },
        plugins: [ocHideBuiltinTooltip]
    });
}

var SubPanel = {
    view: 'form',
    stream: null,
    stage: 0,
    swStage: 0,
    seconds: 0,
    timer: null,
    logLineCount: null,
    lastParams: null,
    resultSize: null,
    kernelResult: null,
    swOnClosed: '',
    charts: [],
    chartsPending: false,
    chartsFailed: false,
    chartSource: null,

    el: function(id) {
        return document.getElementById(id);
    },

    setView: function(view) {
        if (view !== 'progress') this.stopStream();
        this.view = view;
        var model = this.el('config-upload-model');
        if (model) {
            model.classList.toggle('summary-wide', view === 'result');
            model.classList.toggle('oc-busy', view === 'progress');
        }
        var views = {
            form: ['sub-form-content', 'sub-form-footer'],
            progress: ['sub-view-progress', 'sub-progress-footer'],
            result: ['sub-view-result', 'sub-result-footer']
        };
        for (var key in views) {
            if (!Object.prototype.hasOwnProperty.call(views, key)) continue;
            var visible = key === view;
            var nodes = views[key];
            for (var i = 0; i < nodes.length; i++) {
                var node = this.el(nodes[i]);
                if (node) node.classList.toggle('oc-hidden', !visible);
            }
        }
    },

    reset: function() {
        this.stopStream();
        this.stopTimer();
        this.stage = 0;
        this.swStage = 0;
        this.failed = false;
        this.clearError();
        this.setRefreshLoading(false);
        var resultStatus = this.el('sub-result-status');
        if (resultStatus) resultStatus.textContent = '<%:Config saved%>';
        var resultName = this.el('sub-result-name');
        if (resultName) resultName.textContent = '';
        var resultUpdated = this.el('sub-result-updated');
        if (resultUpdated) resultUpdated.textContent = '';
        this.setView('form');
    },

    resetStage: function() {
        this.stage = 0;
        this.failed = false;
        this.renderStepper();
    },

    setStage: function(stage) {
        if (stage > this.stage) {
            this.stage = stage;
            this.renderStepper();
        }
    },

    renderStepper: function() {
        var stepper = this.el('sub-stepper');
        if (!stepper) return;
        var steps = stepper.querySelectorAll('.oc-sub-step');
        for (var i = 0; i < steps.length; i++) {
            steps[i].classList.remove('done', 'active', 'fail');
            var icon = steps[i].querySelector('i');
            icon.classList.remove('oc-icon-check', 'oc-icon-cross');
            if (i < this.stage) {
                steps[i].classList.add('done');
                icon.classList.add('oc-icon-check');
                icon.textContent = '✓';
            } else if (i === this.stage && this.failed) {
                steps[i].classList.add('fail');
                icon.classList.add('oc-icon-cross');
                icon.textContent = '✕';
            } else if (i === this.stage && this.stage < steps.length) {
                steps[i].classList.add('active');
                icon.innerHTML = '<span class="oc-spin"></span>';
            } else {
                icon.textContent = String(i + 1);
            }
        }
        var texts = ['<%:Requesting subscription...%>', '<%:Downloading config...%>', '<%:Verifying...%>', '<%:Applying...%>', '<%:Done%>'];
        var status = this.el('sub-progress-status');
        if (status) status.textContent = texts[Math.min(this.stage, texts.length - 1)] || '';
    },

    resetSwitchStage: function(idle) {
        this.swStage = idle ? -1 : 0;
        this.failed = false;
        this.offlinePolls = 0;
        this.restartSeen = false;
        var note = this.el('sw-error-note');
        if (note) note.classList.add('oc-hidden');
        this.renderSwitchStepper();
    },

    setSwitchStage: function(stage) {
        if (stage > this.swStage) {
            this.swStage = stage;
            this.renderSwitchStepper();
        }
    },

    renderSwitchStepper: function() {
        var stepper = this.el('sw-stepper');
        if (!stepper) return;
        var steps = stepper.querySelectorAll('.oc-sub-step');
        for (var i = 0; i < steps.length; i++) {
            steps[i].classList.remove('done', 'active', 'fail');
            var icon = steps[i].querySelector('i');
            icon.classList.remove('oc-icon-check', 'oc-icon-cross');
            if (i < this.swStage) {
                steps[i].classList.add('done');
                icon.classList.add('oc-icon-check');
                icon.textContent = '✓';
            } else if (i === this.swStage && this.failed) {
                steps[i].classList.add('fail');
                icon.classList.add('oc-icon-cross');
                icon.textContent = '✕';
            } else if (i === this.swStage && this.swStage < steps.length) {
                steps[i].classList.add('active');
                icon.innerHTML = '<span class="oc-spin"></span>';
            } else {
                icon.textContent = String(i + 1);
            }
        }
        var texts = ['<%:Executing...%>', '<%:Starting kernel...%>', '<%:Waiting for core...%>', '<%:Finishing startup...%>', '<%:Done%>'];
        var status = this.el('sw-status');
        if (status) status.textContent = texts[Math.min(this.swStage, texts.length - 1)] || '';
    },

    startTimer: function(labelId, max) {
        var self = this;
        var label = this.el(labelId);
        this.stopTimer();
        this.seconds = 0;
        if (label) label.textContent = '00:00';
        this.timer = setInterval(function() {
            self.seconds += 1;
            var m = Math.floor(self.seconds / 60);
            var s = self.seconds % 60;
            if (label) label.textContent = (m < 10 ? '0' + m : m) + ':' + (s < 10 ? '0' + s : s);
            if (max && self.seconds >= max) self.stopTimer();
        }, 1000);
    },

    stopTimer: function() {
        if (this.timer) {
            clearInterval(this.timer);
            this.timer = null;
        }
    },

    // single owner of the start log stream (the status page polls it too): a concurrent
    // truncation must not make the byte cursor replay lines already shown in this console
    claimLogStream: function(stream) {
        if (typeof LogManager === 'undefined') return;
        if (LogManager.stream && LogManager.stream !== stream) {
            LogManager.stream.abort();
        }
        LogManager.stream = stream;
    },

    releaseLogStream: function(stream) {
        if (typeof LogManager !== 'undefined' && LogManager.stream === stream) {
            LogManager.stream = null;
        }
    },

    stopStream: function() {
        if (this.stream) {
            this.releaseLogStream(this.stream);
            this.stream.abort();
            this.stream = null;
        }
    },

    stopPoll: function() {
        if (this.pollXhr) {
            try { this.pollXhr.abort(); } catch (e) {}
            this.pollXhr = null;
        }
    },

    ensureLogView: function(hostId, cb) {
        var host = this.el(hostId);
        if (!host) return;
        if (host.ocLogView) {
            cb(host);
            return;
        }
        ocRequireCM6(function() {
            if (host.ocLogView) {
                cb(host);
                return;
            }
            var isDark = isDarkBackground(document.body);
            var exts = [CM6.EditorView.lineWrapping, CM6.EditorState.readOnly.of(true), CM6.themeExtension(isDark)];
            if (CM6.topSearchExtension) exts.push(CM6.topSearchExtension());
            exts.push(CM6.keymap.of(CM6.searchKeymap));
            exts.push(CM6.logLanguage);
            exts.push(CM6.syntaxHighlighting(CM6.logHighlightStyle));
            var view = new CM6.EditorView({
                state: CM6.EditorState.create({ doc: '', extensions: exts })
            });
            host.appendChild(view.dom);
            host.ocFollow = true;
            view.scrollDOM.addEventListener('scroll', function() {
                host.ocFollow = view.scrollDOM.scrollTop + view.scrollDOM.clientHeight >= view.scrollDOM.scrollHeight - 24;
            });
            host.ocLogView = view;
            if (CM6.dispatchTheme) CM6.dispatchTheme(view, isDark);
            cb(host);
        });
    },

    clearLog: function(hostId) {
        var host = this.el(hostId);
        if (host && host.ocLogView) {
            host.ocFollow = true;
            host.ocLogView.dispatch({ changes: { from: 0, to: host.ocLogView.state.doc.length, insert: '' } });
        }
    },

    appendLog: function(hostId, text) {
        var host = this.el(hostId);
        if (!host || !host.ocLogView) return;
        var view = host.ocLogView;
        // Every stream response starts with an 8KB space line that flushes the proxy buffer.
        var body = text.replace(/ {4096,}/g, '').replace(/^\n+/, '');
        if (!body) return;
        var first = view.state.doc.length === 0;
        view.dispatch({ changes: { from: view.state.doc.length, insert: (first ? '' : '\n') + body } });
        if (host.ocFollow !== false) {
            var pin = function() {
                view.dispatch({ effects: CM6.EditorView.scrollIntoView(view.state.doc.length, { y: 'end' }) });
            };
            pin();
            // the editor can be unmeasured right after open: pin once more after layout
            if (first) requestAnimationFrame(pin);
        }
    },

    startStream: function(hostId, script, onReady) {
        var self = this;
        this.stopStream();
        this.streamDone = false;
        this.logLineCount = null;
        ocShowLoading(this.el(hostId), '<%:Loading...%>', 120);
        this.ensureLogView(hostId, function() {
            ocHideLoading(self.el(hostId));
            self.clearLog(hostId);
            XHR.get('<%=url("admin", "services", "openclash", "del_start_log")%>', null, function() {
                self.openLogStream(hostId, script, onReady);
            });
        });
    },

    // like the other log managers: one stream + line cursor shared across reconnects
    // (each response replays the whole file from the top)
    openLogStream: function(hostId, script, onReady) {
        var self = this;
        var stream = ocCreateLogStream({
            url: '<%=url("admin", "services", "openclash", "startlog")%>',
            script: script,
            initialMessage: null,
            skipLines: this.logLineCount,
            onSkipLines: function(n) { self.logLineCount = n; },
            maxWaitMs: 600000,
            // the runtime poll judges the restart, so no default grace period after ##FINISHED##
            finishDelayMs: 3000,
            display: function(text) {
                self.appendLog(hostId, text);
                self.stageFromLog(text);
            },
            onFinish: function() {
                self.releaseLogStream(stream);
                self.stream = null;
                self.streamDone = true;
            },
            onTimeout: function() {
                self.releaseLogStream(stream);
                self.stream = null;
                self.streamDone = true;
            }
        });
        this.stream = stream;
        this.claimLogStream(stream);
        stream.start();
        if (onReady) onReady();
    },

    // Stream lines arrive translated, so every match lists the shipped languages.
    stageFromLog: function(text) {
        if (/测试成功|Test Successful|configuración válido/i.test(text)) this.kernelResult = 'ok';
        else if (/测试失败|Tested Failed|configuración ha fallado/i.test(text)) this.kernelResult = 'fail';
        if (this.view !== 'progress') return;
        if (/更新成功|Update Successful|Actualización realizada/i.test(text)) this.setStage(4);
        else if (/开始创建|开始替换|Start To Create|Start Replacing|creando nuevo/i.test(text)) this.setStage(3);
        else if (/下载成功|Download Successful|Descarga completada/i.test(text)) this.setStage(2);
        else if (/开始更新配置文件|Start Updating|Iniciando actualización/i.test(text)) this.setStage(1);
    },

    markProgressDone: function() {
        var model = this.el('config-upload-model');
        if (model) model.classList.remove('oc-busy');
        var primary = this.el('sub-progress-primary');
        if (primary) {
            primary.classList.remove('oc-hidden');
            primary.disabled = false;
            primary.textContent = '<%:View Summary%>';
        }
        var cancel = this.el('sub-progress-cancel');
        if (cancel) cancel.classList.add('oc-hidden');
        var status = this.el('sub-progress-status');
        if (status) status.textContent = '<%:Download and check complete%>';
    },

    clearError: function() {
        this.failed = false;
        var model = this.el('config-upload-model');
        if (model) model.classList.remove('oc-busy');
        var note = this.el('sub-error-note');
        if (note) note.classList.add('oc-hidden');
        var cancel = this.el('sub-progress-cancel');
        if (cancel) {
            cancel.disabled = true;
            cancel.classList.add('oc-hidden');
        }
        var primary = this.el('sub-progress-primary');
        if (primary) {
            primary.classList.add('oc-hidden');
            primary.disabled = true;
            primary.innerHTML = '<span class="oc-spin"></span><%:Processing...%>';
        }
        var status = this.el('sub-progress-status');
        if (status) status.textContent = '<%:Running, cannot cancel%>';
    },

    showError: function(message) {
        this.stopStream();
        this.stopTimer();
        this.stopPoll();
        this.failed = true;
        this.renderStepper();
        var model = this.el('config-upload-model');
        if (model) model.classList.remove('oc-busy');
        var status = this.el('sub-progress-status');
        if (status) status.textContent = '<%:Operation failed%>';
        var note = this.el('sub-error-note');
        var text = this.el('sub-error-text');
        if (text) text.textContent = message || '<%:Operation failed%>';
        if (note) note.classList.remove('oc-hidden');
        var cancel = this.el('sub-progress-cancel');
        if (cancel) {
            cancel.disabled = false;
            cancel.classList.remove('oc-hidden');
        }
        var primary = this.el('sub-progress-primary');
        if (primary) primary.classList.add('oc-hidden');
    },

    chip: function(text, kind) {
        var span = document.createElement('span');
        span.className = 'oc-sub-chip' + (kind ? ' ' + kind : '');
        span.textContent = text;
        return span;
    },

    clearResult: function() {
        var view = this.el('sub-view-result');
        if (view) {
            var host = this.resultMaskHost || view.closest('.config-upload-content') || view;
            ocHideLoading(host);
            host.classList.remove('oc-scroll-lock');
            this.resultMaskHost = null;
            view.classList.remove('oc-sub-age-missing');
        }
        this.destroyCharts();
        var chips = this.el('sub-result-chips');
        if (chips) chips.innerHTML = '';
        var stats = this.el('sub-result-stats');
        if (stats) stats.innerHTML = '';
        this.resultSize = null;
        var checkNote = this.el('sub-check-note');
        if (checkNote) checkNote.classList.add('oc-hidden');
        var groupsPane = this.el('sub-pane-groups');
        if (groupsPane) {
            groupsPane.innerHTML = '';
            groupsPane.classList.remove('oc-hidden');
        }
        var rulesPane = this.el('sub-pane-rules');
        if (rulesPane) {
            rulesPane.innerHTML = '';
            rulesPane.classList.add('oc-hidden');
        }
        var structTabs = document.querySelectorAll('#sub-struct-tabs .oc-tpl-tab');
        for (var st = 0; st < structTabs.length; st++) {
            structTabs[st].classList.toggle('active', structTabs[st].getAttribute('data-tab') === 'groups');
        }
        var providerNote = this.el('sub-provider-note');
        if (providerNote) {
            providerNote.className = 'oc-sub-note oc-sub-note-info oc-hidden';
            providerNote.textContent = '';
        }
        var ageNote = this.el('sub-age-note');
        if (ageNote) {
            ageNote.classList.add('oc-hidden');
            ageNote.textContent = '';
        }
        var infoBox = this.el('sub-info-box');
        if (infoBox) infoBox.classList.add('oc-hidden');
        var subinfo = this.el('sub-subinfo');
        if (subinfo) subinfo.innerHTML = '';
    },

    renderChips: function(params) {
        var host = this.el('sub-result-chips');
        if (!host || params.plain) return;
        if (params.sub_convert === '1') {
            host.appendChild(this.chip('<%:Subscribe Convert%>', 'oc-sub-chip-on'));
        }
        if (params.template_label) {
            host.appendChild(this.chip(params.template_label));
        }
        if (params.keyword_option === '1') {
            host.appendChild(this.chip('<%:Node Filtering%>'));
        }
        if (params.age_secret) {
            host.appendChild(this.chip('<%:Age encrypted / decrypted%>'));
        }
        if (params.sub_headers && params.sub_headers.replace(/\s/g, '') !== '') {
            host.appendChild(this.chip('<%:Custom Headers%>'));
        }
    },

    renderStats: function(data, params) {
        var host = this.el('sub-result-stats');
        var view = this.el('sub-view-result');
        if (!host) return;
        host.innerHTML = '';
        var ageNote = this.el('sub-age-note');
        var providerNote = this.el('sub-provider-note');
        if (view) view.classList.toggle('oc-sub-age-missing', !!data.need_key);
        if (ageNote) {
            if (data.need_key) {
                ageNote.classList.remove('oc-hidden');
                ageNote.textContent = '<%:Age key missing, stats unavailable%>';
            } else {
                ageNote.classList.add('oc-hidden');
            }
        }
        if (providerNote) providerNote.classList.add('oc-hidden');
        if (data.need_key) {
            this.structureUnavailable();
            return;
        }

        var providerMode = data.mode === 'provider';
        var nodes = data.nodes || {};
        var groups = data.groups || {};
        var rules = data.rules || {};
        var providers = data.providers || {};
        var resolved = providers.nodes_total || 0;
        var nodeValue = providerMode ? (resolved > 0 ? String(resolved) : '—') : String(nodes.total || 0);
        host.appendChild(ocStatBox(nodeValue, '<%:Nodes%>'));
        host.appendChild(ocStatBox(String(providers.proxy || 0), '<%:Proxy Providers%>'));
        host.appendChild(ocStatBox(String(groups.total || 0), '<%:Groups%>'));
        host.appendChild(ocStatBox(String(rules.total || 0), '<%:Rules%>'));
        host.appendChild(ocStatBox(String(rules.refs || 0), '<%:Rule Sets%>'));
        host.appendChild(ocSizeStatBox(data.size));

        this.renderStructure(data);
        this.renderCharts(data);

        if (providerNote && providerMode && resolved === 0) {
            providerNote.className = 'oc-sub-note oc-sub-note-info';
            providerNote.textContent = '<%:proxy-providers not downloaded, unable to read%>';
        }
    },

    renderStructure: function(stats) {
        var box = this.el('sub-groups-box');
        if (box) box.classList.remove('oc-hidden');
        var counts = {};
        var providerItems = (stats.providers && stats.providers.items) || [];
        for (var p = 0; p < providerItems.length; p++) {
            var item = providerItems[p];
            var count = item.nodes || item.count || 0;
            if (item.name && count) counts[item.name] = count;
        }
        var groups = [];
        var items = (stats.groups && stats.groups.items) || [];
        for (var i = 0; i < items.length; i++) {
            var members = [];
            var raw = items[i].members || [];
            for (var m = 0; m < raw.length; m++) {
                var member = raw[m];
                if (member.k === 'provider' && counts[member.v]) {
                    member = { k: 'provider', v: member.v, c: counts[member.v] };
                }
                members.push(member);
            }
            groups.push({ name: items[i].n, type: items[i].t, refs: items[i].refs || 0, members: members });
        }
        TemplatePreview.renderGroupPane(this.el('sub-pane-groups'), groups);
        TemplatePreview.renderRuleTargets(this.el('sub-pane-rules'), (stats.rules && stats.rules.targets) || [], (stats.rules && stats.rules.total) || 0);
    },

    structureUnavailable: function() {
        this.destroyCharts();
        var box = this.el('sub-groups-box');
        if (box) box.classList.add('oc-hidden');
        var groupsPane = this.el('sub-pane-groups');
        var rulesPane = this.el('sub-pane-rules');
        if (groupsPane) {
            groupsPane.innerHTML = '';
            groupsPane.appendChild(this.unavailableBox());
        }
        if (rulesPane) {
            rulesPane.innerHTML = '';
            rulesPane.appendChild(this.unavailableBox());
        }
    },

    showStatsUnavailable: function() {
        var note = this.el('sub-provider-note');
        if (note) {
            note.className = 'oc-sub-note oc-sub-note-warn';
            note.textContent = '<%:Stats unavailable%>';
        }
        this.structureUnavailable();
    },

    unavailableBox: function() {
        var div = document.createElement('div');
        div.className = 'oc-sub-empty';
        div.textContent = '<%:Stats unavailable%>';
        return div;
    },

    refreshSubInfo: function(name) {
        var self = this;
        XHR.get('<%=url("admin", "services", "openclash", "sub_info_get")%>', {
            filename: name
        }, function(x, data) {
            self.resultLoadDone();
            var box = self.el('sub-subinfo');
            if (!box) return;
            box.innerHTML = '';
            var providers = (x && x.status == 200 && data && data.providers) ? data.providers : [];
            for (var i = 0; i < providers.length; i++) {
                var provider = providers[i];
                var block = document.createElement('div');
                block.className = 'oc-sub-subinfo';
                if (providers.length > 1 && provider.provider_name) {
                    var head = document.createElement('div');
                    head.className = 'oc-sub-subinfo-h';
                    var label = document.createElement('b');
                    label.textContent = provider.provider_name;
                    head.appendChild(label);
                    block.appendChild(head);
                }
                var bar = document.createElement('div');
                bar.className = 'oc-sub-bar';
                var fill = document.createElement('i');
                var percent = parseFloat(provider.percent);
                fill.style.width = Math.min(isNaN(percent) ? 0 : percent, 100) + '%';
                if (!isNaN(percent)) {
                    if (percent <= 20) fill.className = 'is-danger';
                    else if (percent <= 50) fill.className = 'is-warn';
                }
                bar.appendChild(fill);
                block.appendChild(bar);
                var meta = document.createElement('div');
                meta.className = 'oc-sub-bar-meta';
                var traffic = document.createElement('span');
                traffic.textContent = (provider.surplus || provider.used || '') + ' / ' + (provider.total || '');
                var expire = document.createElement('span');
                if (provider.expire && provider.expire !== 'null') {
                    expire.textContent = provider.expire + (parseInt(provider.day_left) > 0 ? ' · <%:Remaining%> ' + provider.day_left + ' <%:days%>' : '');
                }
                meta.appendChild(traffic);
                meta.appendChild(expire);
                block.appendChild(meta);
                box.appendChild(block);
            }
            var visible = providers.length > 0;
            var infoBox = self.el('sub-info-box');
            if (infoBox) infoBox.classList.toggle('oc-hidden', !visible);
        });
    },

    renderKernelResult: function() {
        var note = this.el('sub-check-note');
        var sw = this.el('sub-switch-btn');
        if (sw) sw.disabled = this.kernelResult === 'fail';
        if (!note) return;
        if (this.kernelResult === 'ok') {
            note.className = 'oc-sub-note oc-sub-note-ok';
            note.innerHTML = '';
            var icon = document.createElement('span');
            icon.className = 'oc-icon-check';
            icon.textContent = '✓';
            var text = document.createElement('span');
            text.textContent = '<%:Config check passed%>';
            note.appendChild(icon);
            note.appendChild(text);
        } else if (this.kernelResult === 'fail') {
            note.className = 'oc-sub-note oc-sub-note-error';
            note.innerHTML = '';
            var failIcon = document.createElement('span');
            failIcon.className = 'oc-icon-cross';
            failIcon.textContent = '✕';
            var failText = document.createElement('span');
            failText.textContent = '<%:Config check failed%>';
            note.appendChild(failIcon);
            note.appendChild(failText);
        } else {
            note.classList.add('oc-hidden');
        }
    },

    showResult: function(params) {
        var self = this;
        this.lastParams = params;
        this.clearResult();
        this.setView('result');
        this.startResultLoading();
        this.renderKernelResult();
        var nameEl = this.el('sub-result-name');
        if (nameEl) nameEl.textContent = /\.ya?ml$/i.test(params.name) ? params.name : params.name + '.yaml';
        this.renderChips(params);
        XHR.get('<%=url("admin", "services", "openclash", "config_stats")%>', {
            filename: params.name
        }, function(x, data) {
            if (x && x.status == 200 && data && data.status === 'success') {
                self.renderFromStats(data, params);
            } else {
                self.showStatsUnavailable();
                self.resultLoadDone();
            }
        });
        this.refreshSubInfo(params.name);
    },

    // mask the result view until every pane's request is in; a hard timeout keeps a
    // dead request from pinning it
    startResultLoading: function() {
        var view = this.el('sub-view-result');
        if (!view) return;
        var host = view.closest('.config-upload-content') || view;
        this.resultMaskHost = host;
        host.scrollTop = 0;
        host.classList.add('oc-scroll-lock');
        ocShowLoading(host, '<%:Loading...%>', 160);
        var status = this.el('sub-result-status');
        if (status) status.textContent = '<%:Loading...%>';
        this.setRefreshLoading(true);
        this.pendingLoads = 2;
        if (this.resultLoadTimer) clearTimeout(this.resultLoadTimer);
        var self = this;
        this.resultLoadTimer = setTimeout(function() { self.finishResultLoading(); }, 8000);
    },

    resultLoadDone: function() {
        if (this.pendingLoads > 0) this.pendingLoads--;
        if (this.pendingLoads <= 0) this.finishResultLoading();
    },

    finishResultLoading: function() {
        if (this.resultLoadTimer) {
            clearTimeout(this.resultLoadTimer);
            this.resultLoadTimer = null;
        }
        this.pendingLoads = 0;
        var host = this.resultMaskHost || this.el('sub-view-result');
        if (host) {
            ocHideLoading(host);
            host.classList.remove('oc-scroll-lock');
        }
        this.resultMaskHost = null;
        var status = this.el('sub-result-status');
        if (status) status.textContent = '<%:File parsed%>';
        this.setRefreshLoading(false);
    },

    setRefreshLoading: function(on) {
        var btn = this.el('sub-refresh-btn');
        if (btn) btn.disabled = !!on;
    },

    // a running config is answered by the core only; the stored file is parsed otherwise
    renderFromStats: function(data, params) {
        this.resultSize = data.size;
        if (data.active) {
            this.renderRuntimeStats();
        } else {
            this.renderStats(data, params);
            this.resultLoadDone();
        }
        this.setUpdatedTime(data);
    },

    renderRuntimeStats: function(attempt) {
        var self = this;
        attempt = attempt || 0;
        XHR.get('<%=url("admin", "services", "openclash", "runtime_stats")%>', null, function(x, data) {
            var online = x && x.status == 200 && data && data.status === 'success' && data.online;
            var groups = (data && data.structure && data.structure.groups) || [];
            var empty = online && (!data.nodes || !data.nodes.total) && !groups.length;
            // a core that has just reloaded can answer before its config is back
            if (empty && attempt < 2) {
                setTimeout(function() { self.renderRuntimeStats(attempt + 1); }, 1200);
                return;
            }
            if (online) {
                self.renderRuntime(data);
                self.resultLoadDone();
                return;
            }
            self.renderStaticStats();
        });
    },

    // the core can be away mid-restart; the stored file keeps the summary readable
    renderStaticStats: function() {
        var self = this;
        var params = this.lastParams;
        XHR.get('<%=url("admin", "services", "openclash", "config_stats")%>', {
            filename: params ? params.name : '',
            static: '1'
        }, function(x, data) {
            if (self.lastParams !== params) return;
            if (x && x.status == 200 && data && data.status === 'success') {
                self.resultSize = data.size;
                self.renderStats(data, params);
                self.setUpdatedTime(data);
                self.resultLoadDone();
                self.runtimeRecheck(params);
                return;
            }
            self.showStatsUnavailable();
            self.resultLoadDone();
        });
    },

    // give a restarting core one later chance and swap the fresher numbers in when it answers
    runtimeRecheck: function(params) {
        var self = this;
        setTimeout(function() {
            if (self.lastParams !== params || self.view !== 'result') return;
            XHR.get('<%=url("admin", "services", "openclash", "runtime_stats")%>', null, function(x, data) {
                var online = x && x.status == 200 && data && data.status === 'success' && data.online;
                if (online && self.lastParams === params && self.view === 'result') self.renderRuntime(data);
            });
        }, 15000);
    },

    renderRuntime: function(data) {
        var host = this.el('sub-result-stats');
        if (!host) return;
        var groups = (data.structure && data.structure.groups) || [];
        host.innerHTML = '';
        host.appendChild(ocStatBox(String(data.nodes.total || 0), '<%:Nodes%>'));
        host.appendChild(ocStatBox(String(((data.providers && data.providers.items) || []).length), '<%:Proxy Providers%>'));
        host.appendChild(ocStatBox(String(groups.length), '<%:Groups%>'));
        host.appendChild(ocStatBox(String((data.rules && data.rules.total) || 0), '<%:Rules%>'));
        host.appendChild(ocStatBox(String((data.rules && data.rules.sets) || 0), '<%:Rule Sets%>'));
        host.appendChild(ocSizeStatBox(this.resultSize));
        this.renderStructure({
            groups: { items: groups },
            providers: data.providers,
            rules: { targets: (data.structure && data.structure.rules && data.structure.rules.targets) || [], total: (data.rules && data.rules.total) || 0 }
        });
        this.renderCharts(data);
        var note = this.el('sub-provider-note');
        if (note) note.classList.add('oc-hidden');
    },

    destroyCharts: function() {
        if (this.charts && this.charts.length) {
            for (var i = 0; i < this.charts.length; i++) {
                try { this.charts[i].destroy(); } catch (e) {}
            }
        }
        this.charts = [];
        var slot = this.el('sub-charts-slot');
        if (slot) {
            slot.innerHTML = '';
            slot.classList.add('oc-hidden');
        }
    },

    renderCharts: function(source) {
        this.destroyCharts();
        if (!source || source.need_key) return;
        if (typeof Chart === 'undefined') {
            this.chartSource = source;
            if (this.chartsFailed || this.chartsPending) return;
            var self = this;
            var url = window.ocChartUrl || ('/luci-static/resources/openclash/js/chart.umd.min.js?v=' + (window.ocPluginVer || ''));
            this.chartsPending = true;
            ocRequireScript(url, function() {
                self.chartsPending = false;
                if (typeof Chart !== 'undefined') {
                    if (self.view === 'result') self.renderCharts(self.chartSource);
                    return;
                }
                self.chartsFailed = true;
            });
            return;
        }
        var slot = this.el('sub-charts-slot');
        if (!slot) return;
        var nodes = source.nodes || {};
        var providers = (source.providers && source.providers.items) || [];
        var groups = (source.groups && source.groups.items) || (source.structure && source.structure.groups) || [];
        var targets = (source.rules && source.rules.targets) || (source.structure && source.structure.rules && source.structure.rules.targets) || [];
        var ruleTypes = (source.rules && source.rules.types) || {};
        var provTotal = 0;
        for (var p = 0; p < providers.length; p++) provTotal += providers[p].nodes || providers[p].count || 0;
        // the core's node total already includes provider nodes; a stored file lists its own proxies only
        var nodesTotal = parseInt(nodes.total, 10) || 0;
        var localCount = source.online ? Math.max(0, nodesTotal - provTotal) : nodesTotal;
        this.buildProtoCard(slot, nodes, providers, localCount);
        this.buildTargetsCard(slot, targets);
        this.buildComposeCard(slot, ruleTypes, groups, providers, localCount);
        if (slot.childNodes.length) slot.classList.remove('oc-hidden');
    },

    buildProtoCard: function(grid, nodes, providers, localCount) {
        var card = document.createElement('div');
        card.className = 'oc-chart-card';
        var head = document.createElement('div');
        head.className = 'oc-chart-h';
        var title = document.createElement('span');
        title.textContent = '<%:Node Protocols%>';
        head.appendChild(title);
        card.appendChild(head);
        var proto = ocChartProtoItems(nodes.types || {}, providers);
        var nodesTotal = localCount || 0;
        for (var p = 0; p < providers.length; p++) nodesTotal += providers[p].nodes || providers[p].count || 0;
        var unread = nodesTotal > proto.total ? nodesTotal - proto.total : 0;
        if (!proto.total) {
            var hint = document.createElement('em');
            hint.textContent = '<%:Unavailable%>';
            head.appendChild(hint);
            var empty = document.createElement('div');
            empty.className = 'oc-chart-empty';
            empty.textContent = '<%:No protocol data%>';
            card.appendChild(empty);
            grid.appendChild(card);
            return;
        }
        var meta = document.createElement('em');
        meta.textContent = (nodesTotal || proto.total) + ' <%:Nodes%>';
        head.appendChild(meta);
        var flex = document.createElement('div');
        flex.className = 'oc-chart-flex';
        var slices = proto.items.slice(0, 5);
        var rest = proto.items.slice(5);
        if (rest.length) {
            var restValue = 0;
            for (var i = 0; i < rest.length; i++) restValue += rest[i].value;
            slices = slices.concat([{ name: '<%:Other%>', value: restValue, color: CHART_GRAY }]);
        }
        var inst = ocChartDonut(flex, slices, String(proto.total), '<%:Nodes%>');
        if (inst) this.charts.push(inst);
        var legend = document.createElement('div');
        legend.className = 'oc-chart-legend';
        ocChartLegend(legend, slices, proto.total);
        flex.appendChild(legend);
        card.appendChild(flex);
        if (unread) {
            var note = document.createElement('div');
            note.className = 'oc-chart-note';
            note.textContent = unread + ' <%:nodes from proxy sets, protocol not read%>';
            card.appendChild(note);
        }
        grid.appendChild(card);
    },

    buildTargetsCard: function(grid, targets) {
        if (!targets.length) return;
        var self = this;
        var sorted = targets.slice().sort(function(a, b) { return b.c - a.c; });
        var items = [];
        var top = Math.min(sorted.length, 6);
        var names = [];
        for (var i = 0; i < top; i++) {
            names.push(sorted[i].t);
            items.push({ name: sorted[i].t, value: sorted[i].c, color: ocChartTargetColor(sorted[i].t, i) });
        }
        if (sorted.length > 6) {
            var restValue = 0;
            for (var j = 6; j < sorted.length; j++) restValue += sorted[j].c;
            items.push({ name: '<%:Other%> (' + (sorted.length - 6) + ')', value: restValue, color: CHART_GRAY });
        }
        var card = document.createElement('div');
        card.className = 'oc-chart-card';
        var head = document.createElement('div');
        head.className = 'oc-chart-h';
        var title = document.createElement('span');
        title.textContent = '<%:Rule Targets%>';
        var meta = document.createElement('em');
        meta.textContent = '<%:Top 6 Targets%>';
        head.appendChild(title);
        head.appendChild(meta);
        card.appendChild(head);
        var body = document.createElement('div');
        body.className = 'oc-chart-body';
        card.appendChild(body);
        var inst = ocChartHBars(body, items, {
            clickable: top,
            onBar: function(index) { self.jumpToRuleTarget(names[index]); }
        });
        if (inst) this.charts.push(inst);
        grid.appendChild(card);
    },

    buildComposeCard: function(grid, ruleTypes, groups, providers, localCount) {
        var ruleItems = ocChartCountItems(ruleTypes, 5, function(key) {
            var name = String(key).toUpperCase();
            return { name: name, color: CHART_RULE_COLORS[name] || CHART_GRAY };
        });
        var groupCounts = {};
        var groupNames = {};
        for (var g = 0; g < groups.length; g++) {
            var gt = TemplatePreview.groupType(groups[g].t || groups[g].type);
            groupCounts[gt.key] = (groupCounts[gt.key] || 0) + 1;
            groupNames[gt.key] = gt.name;
        }
        var groupItems = ocChartCountItems(groupCounts, 5, function(key) {
            return { name: groupNames[key] || key, color: CHART_GROUP_COLORS[key] || CHART_GRAY };
        });
        // inline proxies are not a provider, the sentinel key cannot collide with provider names
        var localKey = '\u0000local';
        var providerCounts = {};
        if (localCount > 0) providerCounts[localKey] = localCount;
        for (var p = 0; p < providers.length; p++) {
            var item = providers[p];
            var count = item.nodes || item.count || 0;
            if (item.name && count) providerCounts[item.name] = (providerCounts[item.name] || 0) + count;
        }
        var providerItems = ocChartCountItems(providerCounts, 5, function(key, index) {
            if (key === localKey) return { name: '<%:Builtin%>', color: CHART_LOCAL };
            return { name: key, color: CHART_PALETTE[index % CHART_PALETTE.length] };
        });
        var defs = [
            ['<%:Rule Types%>', ruleItems],
            ['<%:Groups%>', groupItems],
            ['<%:Proxy Sources%>', providerItems]
        ];
        var rowsHost = document.createElement('div');
        rowsHost.className = 'oc-chart-rows';
        for (var r = 0; r < defs.length; r++) {
            var items = defs[r][1];
            if (!items.length) continue;
            var row = document.createElement('div');
            row.className = 'oc-chart-row';
            var head = document.createElement('div');
            head.className = 'oc-chart-row-head';
            var label = document.createElement('span');
            label.className = 'oc-chart-row-label';
            label.textContent = defs[r][0];
            head.appendChild(label);
            row.appendChild(head);
            var bar = document.createElement('div');
            bar.className = 'oc-chart-bar';
            row.appendChild(bar);
            var foot = document.createElement('div');
            foot.className = 'oc-chart-row-foot';
            var legend = document.createElement('div');
            legend.className = 'oc-chart-legend';
            foot.appendChild(legend);
            row.appendChild(foot);
            var total = 0;
            for (var t = 0; t < items.length; t++) total += items[t].value;
            var inst = ocChartStackRow(bar, items, defs[r][0]);
            if (inst) this.charts.push(inst);
            ocChartLegend(legend, items, total);
            rowsHost.appendChild(row);
        }
        if (!rowsHost.childNodes.length) return;
        var card = document.createElement('div');
        card.className = 'oc-chart-card wide';
        card.appendChild(rowsHost);
        grid.appendChild(card);
    },

    jumpToRuleTarget: function(name) {
        var tabs = document.querySelectorAll('#sub-struct-tabs .oc-tpl-tab');
        for (var i = 0; i < tabs.length; i++) {
            if (tabs[i].getAttribute('data-tab') === 'rules') tabs[i].click();
        }
        var pane = this.el('sub-pane-rules');
        if (!pane) return;
        var rows = pane.querySelectorAll('.oc-tpl-r');
        for (var r = 0; r < rows.length; r++) {
            var pill = rows[r].querySelector('.oc-sub-chip-accent');
            if (!pill || pill.textContent !== name) continue;
            rows[r].scrollIntoView({ block: 'center', behavior: 'smooth' });
            (function(row) {
                row.classList.add('oc-jump-flash');
                setTimeout(function() { row.classList.remove('oc-jump-flash'); }, 1600);
            })(rows[r]);
            break;
        }
    },

    setUpdatedTime: function(stats) {
        var updated = this.el('sub-result-updated');
        if (!updated) return;
        updated.textContent = (stats && stats.mtime) ? '<%:Updated at%> ' + stats.mtime : '';
    },

    startSwitch: function(name, onClosed) {
        var self = this;
        this.switchName = name;
        this.swOnClosed = onClosed || '';
        var retry = this.el('sw-retry-btn');
        if (retry) retry.classList.add('oc-hidden');
        CoreStartFlow.beginRun();
        this.resetSwitchStage();
        this.stopPoll();
        this.startTimer('sw-elapsed', 0);
        this.startStream('sw-log-host', 'init');
        XHR.get('<%=url("admin", "services", "openclash", "switch_config")%>', {
            config_file: '/etc/openclash/config/' + name + '.yaml'
        }, function(x, data) {
            if (x && x.status == 200 && data && data.status === 'success') {
                self.setSwitchStage(1);
                self.pollRuntime(0);
            } else {
                self.finishSwitchFail((data && data.message) || '<%:Switch failed%>');
            }
        });
    },

    // the readback accepts data only after the restart finished (init log stream end);
    // a core up before its config loads gets a short grace, a hanging request is retried
    pollRuntime: function(attempt) {
        var self = this;
        if (!CoreStartFlow.isShown()) return;
        if (attempt > 80) {
            self.finishSwitchFail();
            return;
        }
        this.stopPoll();
        var xhr = new XMLHttpRequest();
        this.pollXhr = xhr;
        var retry = function() {
            if (self.pollXhr !== xhr) return;
            self.pollXhr = null;
            setTimeout(function() { self.pollRuntime(attempt + 1); }, 1500);
        };
        xhr.timeout = 6000;
        xhr.onerror = retry;
        xhr.ontimeout = retry;
        xhr.onload = function() {
            if (self.pollXhr !== xhr) return;
            self.pollXhr = null;
            var data = null;
            try { data = JSON.parse(xhr.responseText); } catch (e) {}
            var online = xhr.status == 200 && data && data.status === 'success' && data.online;
            var groups = (data && data.structure && data.structure.groups) || [];
            var empty = online && (!data.nodes || !data.nodes.total) && !groups.length;
            // the old core still answers right after the switch: probe results count as fresh
            // only once the restart became visible (down sample), the script exited, or the fallback elapsed
            if (!data || data.service_running === false || !online || self.streamDone) self.restartSeen = true;
            var fresh = self.restartSeen || attempt >= 10;
            // the procd state is the authority once the restart script has exited
            if (self.streamDone && data && data.service_running === false) {
                self.finishSwitchFail('<%:Kernel service is not running%>');
                return;
            }
            if (fresh && data && data.service_running === true) self.setSwitchStage(2);
            if (fresh && online) self.setSwitchStage(3);
            if (online && self.streamDone && (!empty || attempt >= 10)) {
                self.setSwitchStage(4);
                self.applyRuntime(data);
                self.finishSwitch();
                return;
            }
            if (self.streamDone && !online) {
                self.offlinePolls = (self.offlinePolls || 0) + 1;
                if (self.offlinePolls >= 20) {
                    self.finishSwitchFail();
                    return;
                }
            }
            setTimeout(function() {
                self.pollRuntime(attempt + 1);
            }, 1500);
        };
        xhr.open('GET', '<%=url("admin", "services", "openclash", "runtime_stats")%>', true);
        xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
        xhr.send();
    },

    finishSwitchFail: function(message) {
        this.stopTimer();
        this.stopPoll();
        CoreStartFlow.lastElapsed = this.seconds || 0;
        CoreStartFlow.dropSession();
        this.failed = true;
        var retry = this.el('sw-retry-btn');
        if (retry) retry.classList.remove('oc-hidden');
        this.renderSwitchStepper();
        var status = this.el('sw-status');
        if (status) status.textContent = '<%:Operation failed%>';
        var note = this.el('sw-error-note');
        var text = this.el('sw-error-text');
        if (text) text.textContent = message || '<%:Core failed to start, check the log above%>';
        if (note) note.classList.remove('oc-hidden');
    },

    applyRuntime: function(data) {
        if (!data || !data.nodes) return;
        this.renderRuntime(data);
    },

    finishSwitch: function() {
        this.stopTimer();
        this.stopPoll();
        CoreStartFlow.lastElapsed = this.seconds || 0;
        CoreStartFlow.dropSession();
        var retry = this.el('sw-retry-btn');
        if (retry) retry.classList.add('oc-hidden');
        this.markStatusDone();
    },

    // the flex row centres the badge; never add a manual offset
    markStatusDone: function() {
        var status = this.el('sw-status');
        if (!status) return;
        status.innerHTML = '';
        var line = document.createElement('span');
        line.className = 'oc-status-line';
        var dot = document.createElement('i');
        dot.className = 'oc-ok-dot oc-icon-check';
        dot.textContent = '✓';
        line.appendChild(dot);
        line.appendChild(document.createTextNode('<%:Config enabled%>'));
        status.appendChild(line);
    },

    closeSwitch: function() {
        this.stopStream();
        this.stopTimer();
        this.stopPoll();
        var done = this.swOnClosed;
        this.swOnClosed = '';
        CoreStartFlow.hideOverlay();
        ConfigUploader.hide();
        if (done) setTimeout(done, 0);
    }
};

var TemplatePreview = {
    overlay: null,
    last: null,

    init: function() {
        var self = this;
        this.overlay = document.getElementById('template-preview-overlay');
        if (!this.overlay) return;
        document.getElementById('template-preview-close').addEventListener('click', function() { self.hide(); });
        document.getElementById('tpl-close-btn').addEventListener('click', function() { self.hide(); });
        document.getElementById('tpl-refresh-btn').addEventListener('click', function() {
            if (self.last) self.load(self.last.name, self.last.url, true);
        });
        var tabs = document.querySelectorAll('#tpl-tabs .oc-tpl-tab');
        for (var i = 0; i < tabs.length; i++) {
            tabs[i].addEventListener('click', function() {
                self.switchTab(this.getAttribute('data-tab'));
            });
        }
        this.overlay.addEventListener('click', function(e) {
            if (e.target === self.overlay) self.hide();
        });
    },

    el: function(id) {
        return document.getElementById(id);
    },

    isOpen: function() {
        return !!this.overlay && this.overlay.classList.contains('show');
    },

    show: function(name, url) {
        if (!this.overlay) return;
        this.overlay.classList.add('show');
        if (!name && !url) {
            this.clearData();
            this.showError('<%:Enter the template URL first%>');
            return;
        }
        this.load(name, url, false);
    },

    hide: function() {
        if (this.overlay) this.overlay.classList.remove('show');
        this.destroyCharts();
    },

    charts: [],

    clearData: function() {
        this.destroyCharts();
        var fields = ['tpl-name', 'tpl-source', 'tpl-cache'];
        for (var i = 0; i < fields.length; i++) {
            var field = this.el(fields[i]);
            if (field) field.textContent = '';
        }
        var stats = this.el('tpl-stats');
        if (stats) stats.innerHTML = '';
        var panes = ['tpl-pane-groups', 'tpl-pane-rules', 'tpl-pane-extra'];
        for (var j = 0; j < panes.length; j++) {
            var pane = this.el(panes[j]);
            if (pane) pane.innerHTML = '';
        }
    },

    showError: function(message) {
        var note = this.el('tpl-error');
        var text = this.el('tpl-error-text');
        if (text) text.textContent = message || '<%:Failed to fetch template%>';
        if (note) note.classList.remove('oc-hidden');
    },

    clearError: function() {
        var note = this.el('tpl-error');
        if (note) note.classList.add('oc-hidden');
    },

    load: function(name, url, force) {
        var self = this;
        var sameTarget = !!this.last && this.last.name === name && this.last.url === url;
        this.last = { name: name, url: url };
        this.clearError();
        if (!sameTarget) this.clearData();
        var nameEl = this.el('tpl-name');
        if (nameEl) {
            var label = name || url || '';
            nameEl.textContent = label;
            nameEl.title = label;
        }
        var srcEl = this.el('tpl-source');
        if (srcEl) {
            srcEl.textContent = '<%:Template URL%>';
            srcEl.title = url || '';
            srcEl.href = url || 'javascript:void(0)';
        }
        var cacheEl = this.el('tpl-cache');
        if (cacheEl) cacheEl.textContent = '';
        // A refresh racing an in-flight load must not be overwritten by it.
        this.reqId = (this.reqId || 0) + 1;
        var reqId = this.reqId;
        var status = this.el('tpl-status');
        if (status) status.textContent = '<%:Loading...%>';
        var model = this.el('template-preview-model');
        var content = model && model.querySelector('.config-upload-content');
        if (content) {
            content.scrollTop = 0;
            content.classList.add('oc-scroll-lock');
        }
        ocShowLoading(content, '<%:Loading...%>', 160);
        this.setRefreshing(true);
        XHR.get('<%=url("admin", "services", "openclash", "template_preview")%>', {
            name: name,
            url: url,
            force: force ? '1' : ''
        }, function(x, data) {
            if (reqId !== self.reqId) return;
            ocHideLoading(content);
            if (content) content.classList.remove('oc-scroll-lock');
            self.setRefreshing(false);
            if (x && x.status == 200 && data && data.status === 'success') {
                if (status) status.textContent = '<%:Template parsed%>';
                self.render(data);
            } else {
                if (status) status.textContent = '';
                var msg = '<%:Failed to fetch template%>';
                if (data && data.message === 'Template not found') {
                    msg = '<%:Template not found%>';
                } else if (data && data.message === 'Unsupported template format') {
                    msg = '<%:Unsupported template format%>';
                } else if (data && data.message === 'YAML template') {
                    msg = '<%:YAML template, no static structure to preview%>';
                }
                self.showError(msg);
            }
        });
    },

    setRefreshing: function(on) {
        var btn = this.el('tpl-refresh-btn');
        if (btn) btn.disabled = !!on;
    },

    switchTab: function(tab) {
        var tabs = document.querySelectorAll('#tpl-tabs .oc-tpl-tab');
        for (var i = 0; i < tabs.length; i++) {
            tabs[i].classList.toggle('active', tabs[i].getAttribute('data-tab') === tab);
        }
        var panes = ['groups', 'rules', 'extra'];
        for (var j = 0; j < panes.length; j++) {
            var pane = this.el('tpl-pane-' + panes[j]);
            if (pane) pane.classList.toggle('oc-hidden', panes[j] !== tab);
        }
    },

    render: function(data) {
        var name = this.el('tpl-name');
        if (name) {
            name.textContent = data.source.name || '';
            name.title = data.source.name || '';
        }
        var cache = this.el('tpl-cache');
        if (cache) {
            if (data.source.from_cache) {
                var age = data.source.age || 0;
                var minutes = Math.floor(age / 60);
                cache.textContent = '<%:Local cache%>' + ' · ' + (minutes > 0 ? minutes + ' <%:minutes ago%>' : age + ' <%:seconds ago%>');
            } else {
                cache.textContent = '<%:Just fetched%>';
            }
        }
        var link = this.el('tpl-source');
        if (link) {
            var tplUrl = data.source.url || '';
            link.textContent = '<%:Template URL%>';
            link.title = tplUrl;
            link.href = tplUrl || 'javascript:void(0)';
        }
        this.renderStats(data.summary);
        this.renderGroups(data.groups);
        this.renderRules(data.rulesets);
        this.renderExtra(data.extra);
        this.renderCharts(data);
    },

    renderStats: function(summary) {
        var host = this.el('tpl-stats');
        if (!host) return;
        host.innerHTML = '';
        var tiles = [
            [String(summary.groups || 0), '<%:Groups%>'],
            [String(summary.sets || 0), '<%:Rule Sets%>'],
            [String(summary.tests || 0), '<%:Test Groups%>'],
            [summary.smart > 0 ? '✓ ' + summary.smart : '—', '<%:Smart Groups%>']
        ];
        for (var i = 0; i < tiles.length; i++) {
            host.appendChild(ocStatBox(tiles[i][0], tiles[i][1]));
        }
    },

    section: function(text) {
        var div = document.createElement('div');
        div.className = 'oc-sub-sec';
        div.textContent = text;
        return div;
    },

    groupType: function(type) {
        var key = String(type || '').toLowerCase().replace(/[\s_-]/g, '');
        if (key === 'smart') return { key: 'smart', name: 'Smart' };
        if (key === 'select' || key === 'selector') return { key: 'select', name: 'Select' };
        if (key === 'urltest') return { key: 'url-test', name: 'URLTest' };
        if (key === 'fallback') return { key: 'fallback', name: 'Fallback' };
        if (key === 'loadbalance') return { key: 'load-balance', name: 'LoadBalance' };
        if (key === 'relay') return { key: 'relay', name: 'Relay' };
        return { key: key || 'other', name: String(type || '') };
    },

    renderGroupPane: function(host, groups) {
        if (!host) return;
        host.innerHTML = '';
        var order = ['smart', 'select', 'url-test', 'fallback', 'load-balance', 'relay'];
        var byKey = {};
        var buckets = [];
        for (var i = 0; i < groups.length; i++) {
            var gt = this.groupType(groups[i].type);
            if (!byKey[gt.key]) {
                byKey[gt.key] = { key: gt.key, name: gt.name, list: [] };
                buckets.push(byKey[gt.key]);
            }
            byKey[gt.key].list.push(groups[i]);
        }
        buckets.sort(function(a, b) {
            var ia = order.indexOf(a.key);
            var ib = order.indexOf(b.key);
            return (ia < 0 ? order.length : ia) - (ib < 0 ? order.length : ib);
        });
        for (var s = 0; s < buckets.length; s++) {
            var title = buckets[s].name ? buckets[s].name + ' <%:Groups%>' : '<%:Groups%>';
            host.appendChild(this.section(title));
            for (var j = 0; j < buckets[s].list.length; j++) host.appendChild(this.groupCard(buckets[s].list[j]));
        }
        var cards = host.querySelectorAll('.oc-tpl-g');
        for (var c = 0; c < cards.length; c++) {
            var next = cards[c].nextElementSibling;
            if (next && next.classList.contains('oc-sub-sec')) cards[c].classList.add('oc-tpl-g-end');
        }
    },

    renderRuleTargets: function(host, targets, total) {
        if (!host) return;
        host.innerHTML = '';
        var maxCount = 0;
        for (var mx = 0; mx < targets.length; mx++) maxCount = Math.max(maxCount, targets[mx].c || 0);
        for (var j = 0; j < targets.length; j++) {
            var item = targets[j];
            var row = document.createElement('div');
            row.className = 'oc-tpl-r';
            var head = document.createElement('div');
            head.className = 'oc-tpl-rh';
            var pill = document.createElement('span');
            pill.className = 'oc-sub-chip oc-sub-chip-accent';
            pill.textContent = item.t;
            head.appendChild(pill);
            var count = document.createElement('span');
            count.className = 'oc-tpl-refs';
            var pct = total ? (item.c || 0) / total * 100 : 0;
            count.textContent = (item.c || 0) + ' <%:Rules%>' + (total ? ' · ' + (pct > 0 && pct < 1 ? '<1%' : Math.round(pct) + '%') : '');
            head.appendChild(count);
            row.appendChild(head);
            if (total) {
                var share = document.createElement('div');
                share.className = 'oc-tpl-rbar';
                var fill = document.createElement('i');
                fill.style.width = (maxCount ? Math.min((item.c || 0) / maxCount * 100, 100) : 0) + '%';
                share.appendChild(fill);
                row.appendChild(share);
            }
            var box = document.createElement('div');
            box.className = 'oc-tpl-m';
            var sets = item.sets || [];
            for (var k = 0; k < sets.length; k++) {
                var chip = document.createElement('span');
                chip.className = 'oc-sub-chip';
                chip.textContent = sets[k];
                chip.title = sets[k];
                box.appendChild(chip);
            }
            var labelList = item.rules || [];
            for (var m = 0; m < labelList.length; m++) {
                var ruleChip = document.createElement('span');
                ruleChip.className = 'oc-sub-chip t-filter';
                ruleChip.textContent = labelList[m];
                ruleChip.title = labelList[m];
                box.appendChild(ruleChip);
            }
            if (box.childNodes.length) row.appendChild(box);
            host.appendChild(row);
        }
    },

    renderGroups: function(groups) {
        this.renderGroupPane(this.el('tpl-pane-groups'), groups);
    },

    groupCard: function(group) {
        var card = document.createElement('div');
        card.className = 'oc-tpl-g';
        var head = document.createElement('div');
        head.className = 'oc-tpl-gh';
        var name = document.createElement('span');
        name.textContent = group.name;
        head.appendChild(name);
        if (group.type) {
            var gt = this.groupType(group.type);
            var type = document.createElement('span');
            var isTest = gt.key === 'url-test' || gt.key === 'fallback' || gt.key === 'load-balance';
            type.className = 'oc-tpl-type' + (gt.key === 'smart' ? ' is-smart' : (isTest ? ' is-test' : ''));
            type.textContent = gt.name;
            head.appendChild(type);
        }
        if (group.refs > 0) {
            var refs = document.createElement('span');
            refs.className = 'oc-tpl-refs';
            refs.textContent = group.refs + ' <%:refs%>';
            head.appendChild(refs);
        }
        var members = [];
        var rawMembers = group.members || [];
        for (var m = 0; m < rawMembers.length; m++) {
            // the test url and the health check numbers are group options, not members
            if (rawMembers[m].k === 'test' || rawMembers[m].k === 'param') continue;
            members.push(rawMembers[m]);
        }
        var providerCount = 0;
        for (var p = 0; p < members.length; p++) {
            if (members[p].k === 'provider') providerCount++;
        }
        if (providerCount > 0) {
            var provs = document.createElement('span');
            provs.className = 'oc-tpl-refs';
            provs.textContent = providerCount + ' <%:providers%>';
            head.appendChild(provs);
        }
        card.appendChild(head);
        if (members.length) {
            var box = document.createElement('div');
            box.className = 'oc-tpl-m';
            for (var i = 0; i < members.length; i++) {
                box.appendChild(this.memberChip(members[i]));
            }
            card.appendChild(box);
        }
        return card;
    },

    memberChip: function(member) {
        var chip = document.createElement('span');
        chip.className = 'oc-sub-chip t-' + member.k;
        if (member.k === 'all') {
            chip.textContent = '<%:All Nodes%>';
        } else if (member.k === 'nodes') {
            chip.textContent = member.v + ' <%:Nodes%>';
        } else if (member.k === 'provider' && member.c) {
            chip.textContent = member.v + ' · ' + member.c;
        } else {
            chip.textContent = member.v;
        }
        if (!chip.title) chip.title = chip.textContent;
        return chip;
    },

    renderRules: function(rulesets) {
        var host = this.el('tpl-pane-rules');
        if (!host) return;
        host.innerHTML = '';
        var order = [], byTarget = {};
        for (var i = 0; i < rulesets.length; i++) {
            var item = rulesets[i];
            if (!byTarget[item.target]) {
                byTarget[item.target] = [];
                order.push(item.target);
            }
            byTarget[item.target].push(item);
        }
        for (var j = 0; j < order.length; j++) {
            var sets = byTarget[order[j]];
            var row = document.createElement('div');
            row.className = 'oc-tpl-r';
            var head = document.createElement('div');
            head.className = 'oc-tpl-rh';
            var pill = document.createElement('span');
            pill.className = 'oc-sub-chip oc-sub-chip-accent';
            pill.textContent = order[j];
            head.appendChild(pill);
            var count = document.createElement('span');
            count.className = 'oc-tpl-refs';
            count.textContent = sets.length + ' <%:Rule Sets%>';
            head.appendChild(count);
            row.appendChild(head);
            var box = document.createElement('div');
            box.className = 'oc-tpl-m';
            for (var k = 0; k < sets.length; k++) {
                var chip = document.createElement('span');
                chip.className = 'oc-sub-chip' + (sets[k].kind === 'rule' ? ' t-filter' : '');
                chip.textContent = sets[k].label;
                chip.title = sets[k].label;
                box.appendChild(chip);
            }
            row.appendChild(box);
            host.appendChild(row);
        }
    },

    renderExtra: function(extra) {
        var host = this.el('tpl-pane-extra');
        if (!host) return;
        host.innerHTML = '';
        if (!extra || !extra.length) {
            var empty = document.createElement('div');
            empty.className = 'oc-sub-empty';
            empty.textContent = '<%:No extra settings%>';
            host.appendChild(empty);
            return;
        }
        var grid = document.createElement('div');
        grid.className = 'oc-tpl-kv';
        for (var i = 0; i < extra.length; i++) {
            var row = document.createElement('div');
            row.className = 'oc-tpl-kvrow';
            var key = document.createElement('b');
            key.className = 'oc-tpl-kvkey';
            key.textContent = extra[i].k;
            var value = document.createElement('span');
            value.className = 'oc-tpl-kvval';
            var text = String(extra[i].v == null ? '' : extra[i].v);
            if (text === 'true' || text === 'false') {
                var badge = document.createElement('i');
                badge.className = 'oc-tpl-kvb ' + (text === 'true' ? 'on' : 'off');
                badge.textContent = text;
                value.appendChild(badge);
            } else if (text.length > 64) {
                value.textContent = text.slice(0, 40) + '…' + text.slice(-18);
                value.title = text;
            } else {
                value.textContent = text;
            }
            row.appendChild(key);
            row.appendChild(value);
            grid.appendChild(row);
        }
        host.appendChild(grid);
    },

    destroyCharts: function() {
        if (this.charts && this.charts.length) {
            for (var i = 0; i < this.charts.length; i++) {
                try { this.charts[i].destroy(); } catch (e) {}
            }
        }
        this.charts = [];
        var slot = this.el('tpl-charts');
        if (slot) {
            slot.innerHTML = '';
            slot.classList.add('oc-hidden');
        }
    },

    renderCharts: function(data) {
        this.destroyCharts();
        var groups = data.groups || [];
        var rulesets = data.rulesets || [];
        if (typeof Chart === 'undefined') {
            var self = this;
            this.chartData = data;
            if (this.chartsPending || this.chartsFailed) return;
            var url = window.ocChartUrl || ('/luci-static/resources/openclash/js/chart.umd.min.js?v=' + (window.ocPluginVer || ''));
            this.chartsPending = true;
            ocRequireScript(url, function() {
                self.chartsPending = false;
                if (typeof Chart !== 'undefined') self.renderCharts(self.chartData);
                else self.chartsFailed = true;
            });
            return;
        }
        var slot = this.el('tpl-charts');
        if (!slot) return;
        var typeCounts = {};
        var typeNames = {};
        for (var g = 0; g < groups.length; g++) {
            var gt = this.groupType(groups[g].type || groups[g].t || '');
            typeCounts[gt.key] = (typeCounts[gt.key] || 0) + 1;
            typeNames[gt.key] = gt.name || gt.key;
        }
        var typeItems = ocChartCountItems(typeCounts, 6, function(key) {
            return { name: typeNames[key] || key, color: CHART_GROUP_COLORS[key] || CHART_GRAY };
        });
        if (typeItems.length) {
            var card = document.createElement('div');
            card.className = 'oc-chart-card';
            var head = document.createElement('div');
            head.className = 'oc-chart-h';
            var title = document.createElement('span');
            title.textContent = '<%:Group Types%>';
            var meta = document.createElement('em');
            meta.textContent = groups.length + ' <%:Groups%>';
            head.appendChild(title);
            head.appendChild(meta);
            card.appendChild(head);
            var flex = document.createElement('div');
            flex.className = 'oc-chart-flex';
            var inst = ocChartDonut(flex, typeItems, String(groups.length), '<%:Groups%>');
            if (inst) this.charts.push(inst);
            var legend = document.createElement('div');
            legend.className = 'oc-chart-legend';
            ocChartLegend(legend, typeItems, groups.length);
            flex.appendChild(legend);
            card.appendChild(flex);
            slot.appendChild(card);
        }
        var targetCounts = {};
        for (var r = 0; r < rulesets.length; r++) {
            var target = rulesets[r].target || '';
            targetCounts[target] = (targetCounts[target] || 0) + 1;
        }
        var targetItems = ocChartCountItems(targetCounts, 6, function(key, index) {
            return { name: key, color: ocChartTargetColor(key, index) };
        });
        if (targetItems.length) {
            var barCard = document.createElement('div');
            barCard.className = 'oc-chart-card';
            var barHead = document.createElement('div');
            barHead.className = 'oc-chart-h';
            var barTitle = document.createElement('span');
            barTitle.textContent = '<%:Rule Targets%>';
            var barMeta = document.createElement('em');
            barMeta.textContent = rulesets.length + ' <%:Rule Sets%>';
            barHead.appendChild(barTitle);
            barHead.appendChild(barMeta);
            barCard.appendChild(barHead);
            var body = document.createElement('div');
            body.className = 'oc-chart-body';
            barCard.appendChild(body);
            var barInst = ocChartHBars(body, targetItems, {});
            if (barInst) this.charts.push(barInst);
            slot.appendChild(barCard);
        }
        if (slot.childNodes.length) slot.classList.remove('oc-hidden');
    }
};

var ConfigUploaderFocus = { restoreTarget: null };

(function() {
    var bind = function() {
        var model = document.getElementById('config-upload-model');
        if (!model || model.dataset.ocTrapBound) return;
        model.dataset.ocTrapBound = '1';
        model.addEventListener('keydown', function(e) {
            if (e.key !== 'Tab') return;
            var all = model.querySelectorAll('a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])');
            var visible = [];
            for (var i = 0; i < all.length; i++) {
                if (all[i].offsetParent !== null) visible.push(all[i]);
            }
            if (!visible.length) return;
            var first = visible[0];
            var last = visible[visible.length - 1];
            if (e.shiftKey && document.activeElement === first) {
                e.preventDefault();
                last.focus();
            } else if (!e.shiftKey && document.activeElement === last) {
                e.preventDefault();
                first.focus();
            }
        });
    };
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', bind);
    } else {
        bind();
    }
})();

var ConfigUploader = {
    overlay: null,
    model: null,
    selectedFile: null,
    isProcessing: false,
    formDirty: false,
    submitAttempted: false,
    currentMode: 'file',
    onSuccess: '',
    subconverterVersionChecker: null,
    linkRe: null,

    init: function() {
        this.overlay = document.getElementById('config-upload-overlay');
        this.model = document.getElementById('config-upload-model');

        if (!this.overlay || !this.model) {
            return;
        }

        this.bindEvents();
    },

    bindEvents: function() {
        var self = this;
        var uploadZone = document.getElementById('upload-zone');
        var fileInput = document.getElementById('config-file-input');

        document.getElementById('upload-mode-file').addEventListener('click', function() {
            self.switchMode('file');
        });

        document.getElementById('upload-mode-subscribe').addEventListener('click', function() {
            self.switchMode('subscribe');
        });

        uploadZone.addEventListener('click', function() {
            if (!self.isProcessing && self.currentMode === 'file') {
                fileInput.click();
            }
        });

        fileInput.addEventListener('change', function(e) {
            if (e.target.files.length > 0) {
                self.handleFileSelect(e.target.files[0]);
            }
        });

        uploadZone.addEventListener('dragover', function(e) {
            e.preventDefault();
            if (!self.isProcessing && self.currentMode === 'file') {
                uploadZone.classList.add('dragover');
            }
        });

        uploadZone.addEventListener('dragleave', function(e) {
            e.preventDefault();
            uploadZone.classList.remove('dragover');
        });

        uploadZone.addEventListener('drop', function(e) {
            e.preventDefault();
            uploadZone.classList.remove('dragover');

            if (!self.isProcessing && self.currentMode === 'file' && e.dataTransfer.files.length > 0) {
                self.handleFileSelect(e.dataTransfer.files[0]);
            }
        });

        var subscribeUrlInput = document.getElementById('subscribe-url-input');

        var subscribeContent = document.getElementById('mode-subscribe-content');
        if (subscribeContent) {
            subscribeContent.addEventListener('input', function() {
                self.updateFoldSummaries();
            });
            subscribeContent.addEventListener('change', function() {
                self.updateFoldSummaries();
            });
        }

        var filenameInput = document.getElementById('config-filename-input');
        var subscribeUaSelect = document.getElementById('subscribe-ua-input');
        var subscribeUaCustom = document.getElementById('subscribe-ua-custom');
        var subConvertEnable = document.getElementById('sub-convert-enable');
        var subConvertOptions = document.getElementById('sub-convert-options');
        var convertAddressSelect = document.getElementById('convert-address-input');
        var convertAddressCustom = document.getElementById('convert-address-custom');
        var templateSelect = document.getElementById('template-select');
        var customTemplateGroup = document.getElementById('custom-template-group');
        var advancedOptionsEnable = document.getElementById('advanced-options-enable');
        var advancedOptionsContainer = document.getElementById('advanced-options-container');
        var advancedOptionsEnableFile = document.getElementById('advanced-options-enable-file');
        var advancedOptionsContainerFile = document.getElementById('advanced-options-container-file');
        var ageFormNode = document.getElementById('age-encryption-group');
        var subVersionStatus = document.getElementById('subconverter-version-status-upload');
        var keywordOptionsEnable = document.getElementById('keyword-options-enable');
        var keywordOptionsContainer = document.getElementById('keyword-options-container');

        ocRequireScript('/luci-static/resources/openclash/js/subconverter-version.js?v=' + (window.ocPluginVer || ''), function() {
        if (window.OpenClashSubconverterVersion && subVersionStatus) {
            self.subconverterVersionChecker = window.OpenClashSubconverterVersion.init({
                select: convertAddressSelect,
                customInput: convertAddressCustom,
                enable: subConvertEnable,
                status: subVersionStatus,
                proxyURL: '<%=url("admin", "services", "openclash", "subconverter_version")%>',
                labels: {
                    checking: '<%:Checking backend version...%>',
                    versionPrefix: '<%:Backend Version%>',
                    empty: '<%:Please enter backend URL%>',
                    invalid: '<%:Invalid backend URL%>',
                    unrecognized: '<%:Backend version information not detected%>',
                    failed: '<%:Unable to detect backend version%>'
                }
            });
        }
        });

        subscribeUrlInput.addEventListener('input', function() {
            self.autoFillConfigName();
            self.updateUrlFeedback();
            self.updateSubmitButton();

            var convertEnable = document.getElementById('sub-convert-enable');
            if (convertEnable && !convertEnable.checked && /(?:^|[\s|,;"'<(])(?!https?:\/\/)[a-z][a-z0-9+.-]*:\/\//i.test(subscribeUrlInput.value)) {
                convertEnable.checked = true;
                convertEnable.dispatchEvent(new Event('change', { bubbles: true }));
            }
        });

        filenameInput.addEventListener('input', function() {
            self.setFilenameError('');
            self.updateSubmitButton();
            self.updateUrlFeedback();
        });

        subscribeUaSelect.addEventListener('change', function() {
            subscribeUaCustom.classList.toggle('oc-hidden', this.value !== 'custom');
        });

        advancedOptionsEnable.addEventListener('change', function() {
            if (this.checked) {
                advancedOptionsContainer.classList.remove('oc-hidden');
            } else {
                advancedOptionsContainer.classList.add('oc-hidden');
                self.updateSubmitButton();
            }
            if (ageFormNode && advancedOptionsContainer && ageFormNode.parentNode !== advancedOptionsContainer) {
                advancedOptionsContainer.appendChild(ageFormNode);
            }
        });

        if (advancedOptionsEnableFile) {
            advancedOptionsEnableFile.addEventListener('change', function() {
                if (this.checked) {
                    advancedOptionsContainerFile.classList.remove('oc-hidden');
                    if (ageFormNode && advancedOptionsContainerFile && ageFormNode.parentNode !== advancedOptionsContainerFile) {
                        advancedOptionsContainerFile.appendChild(ageFormNode);
                    }
                } else {
                    advancedOptionsContainerFile.classList.add('oc-hidden');
                    self.updateSubmitButton();
                    if (ageFormNode && advancedOptionsContainer && ageFormNode.parentNode === advancedOptionsContainerFile) {
                        advancedOptionsContainer.appendChild(ageFormNode);
                    }
                }
            });
        }

        subConvertEnable.addEventListener('change', function() {
            subConvertOptions.classList.toggle('oc-hidden', !this.checked);
            self.updateSubconverterVersionStatus();
            self.updateUrlFeedback();
            self.updateSubmitButton();
        });

        keywordOptionsEnable.addEventListener('change', function() {
            keywordOptionsContainer.classList.toggle('oc-hidden', !this.checked);
        });

        convertAddressSelect.addEventListener('change', function() {
            convertAddressCustom.classList.toggle('oc-hidden', this.value !== 'custom');
            self.updateSubconverterVersionStatus();
        });

        templateSelect.addEventListener('change', function() {
            customTemplateGroup.classList.toggle('oc-hidden', this.value !== '0');
        });

        var ageGenerateBtn = document.getElementById('age-generate-btn');
        var ageCopyPublic = document.getElementById('age-copy-public');
        var ageCopySecret = document.getElementById('age-copy-secret');
        var agePublicInput = document.getElementById('age-public-input');
        var ageSecretInput = document.getElementById('age-secret-input');
        var ageCalPublic = document.getElementById('age-calculate-public');

        if (ageGenerateBtn) {
            ageGenerateBtn.addEventListener('click', function() {
                var algo = document.getElementById('age-algo-select') ? document.getElementById('age-algo-select').value : 'keygen';
                ageGenerateBtn.disabled = true;
                self.setAgeError('');
                XHR.get('<%=url("admin", "services", "openclash", "generate_age_key")%>', {
                    algo: algo
                }, function(x, data) {
                    ageGenerateBtn.disabled = false;
                    if (x && x.status == 200 && data.status === 'success') {
                        if (ageSecretInput) {
                            ageSecretInput.value = data.secret || '';
                        }
                        if (agePublicInput) {
                            agePublicInput.value = data.public || '';
                        }
                        self.updateSubmitButton();
                        self.updateFoldSummaries();
                    } else {
                        self.setAgeError('<%:Failed to generate age key%>');
                    }
                });
            });
        }

        if (ageCopyPublic) {
            ageCopyPublic.addEventListener('click', function() {
                var v = agePublicInput.value || '';
                if (v === '') { self.setAgeError('<%:No public key%>'); return; }
                ocCopyToClipboard(v, ageCopyPublic);
            });
        }

        if (ageCopySecret) {
            ageCopySecret.addEventListener('click', function() {
                var v = ageSecretInput.value || '';
                if (v === '') { self.setAgeError('<%:No secret key%>'); return; }
                ocCopyToClipboard(v, ageCopySecret);
            });
        }

        if (ageCalPublic) {
            ageCalPublic.addEventListener('click', function() {
                var secret = ageSecretInput.value || '';
                if (secret === '') { self.setAgeError('<%:Please enter the Age Secret Key to calculate the public key!%>'); return; }
                ageCalPublic.disabled = true;
                self.setAgeError('');
                XHR.get('<%=url("admin", "services", "openclash", "cal_age_public_key")%>', {
                    secret: secret
                }, function(x, data) {
                    ageCalPublic.disabled = false;
                    if (x && x.status == 200 && data.status === 'success') {
                        if (agePublicInput) {
                            agePublicInput.value = data.public || '';
                        }
                        self.updateSubmitButton();
                        self.updateFoldSummaries();
                    } else {
                        self.setAgeError('<%:Failed to calculate public key%>');
                    }
                });
            });
        }

        var onAgeInput = function() {
            self.setAgeError('');
            self.updateSubmitButton();
            self.updateFoldSummaries();
        };
        if (agePublicInput) agePublicInput.addEventListener('input', onAgeInput);
        if (ageSecretInput) ageSecretInput.addEventListener('input', onAgeInput);

        document.getElementById('subscribe-headers-add').addEventListener('click', function() {
            self.addHeaderRow('', '');
        });

        document.getElementById('config-upload-submit').addEventListener('click', function() {
            self.submitAttempted = true;
            if (self.currentMode === 'file') {
                self.uploadFile();
            } else {
                self.processSubscription();
            }
        });

        var subscribePane = document.getElementById('mode-subscribe-content');
        if (subscribePane) {
            var markDirty = function() {
                if (self.formDirty) return;
                self.formDirty = true;
                var statusEl = document.getElementById('config-upload-status-text');
                if (self.currentMode === 'subscribe' && statusEl && statusEl.dataset.ocRequired !== '1') {
                    statusEl.textContent = '<%:Unsaved changes%>';
                }
            };
            subscribePane.addEventListener('input', markDirty);
            subscribePane.addEventListener('change', markDirty);
        }

        document.getElementById('config-upload-cancel').addEventListener('click', function() {
            if (self.isProcessing) return;
            self.hide();
        });

        document.getElementById('config-upload-close').addEventListener('click', function() {
            if (self.isProcessing) {
                self.nudgeClose();
                return;
            }
            self.hide();
        });

        document.getElementById('sub-progress-cancel').addEventListener('click', function() {
            if (!self.isProcessing) {
                self.hide();
            }
        });

        document.getElementById('sub-progress-primary').addEventListener('click', function() {
            self.openPendingResult();
        });

        var subHelp = document.getElementById('sub-help-btn');
        if (subHelp) subHelp.addEventListener('click', function() {
            CoreStartFlow.openHelp();
        });

        document.getElementById('sub-retry-btn').addEventListener('click', function() {
            self.retryOperation(false);
        });

        document.getElementById('sub-retry-plain-btn').addEventListener('click', function() {
            self.retryOperation(true);
        });

        document.getElementById('sub-refresh-btn').addEventListener('click', function() {
            self.refreshResult();
        });

        document.getElementById('sub-switch-btn').addEventListener('click', function() {
            self.switchCurrent();
        });

        document.getElementById('sw-retry-btn').addEventListener('click', function() {
            if (SubPanel.switchName) SubPanel.startSwitch(SubPanel.switchName, SubPanel.swOnClosed);
        });

        document.getElementById('sw-close-btn').addEventListener('click', function() {
            CoreStartFlow.close();
        });

        document.getElementById('template-preview-btn').addEventListener('click', function() {
            var select = document.getElementById('template-select');
            var customInput = document.getElementById('custom-template-input');
            if (select && select.value === '0') {
                TemplatePreview.show('', customInput ? customInput.value.trim() : '');
            } else {
                TemplatePreview.show(select ? select.value : '', '');
            }
        });

        var structTabs = document.querySelectorAll('#sub-struct-tabs .oc-tpl-tab');
        for (var st = 0; st < structTabs.length; st++) {
            structTabs[st].addEventListener('click', function() {
                var tab = this.getAttribute('data-tab');
                var tabs = document.querySelectorAll('#sub-struct-tabs .oc-tpl-tab');
                for (var i = 0; i < tabs.length; i++) {
                    tabs[i].classList.toggle('active', tabs[i].getAttribute('data-tab') === tab);
                }
                SubPanel.el('sub-pane-groups').classList.toggle('oc-hidden', tab !== 'groups');
                SubPanel.el('sub-pane-rules').classList.toggle('oc-hidden', tab !== 'rules');
            });
        }

        document.addEventListener('keydown', function(e) {
            if (e.key !== 'Escape') return;
            if (TemplatePreview.isOpen()) {
                TemplatePreview.hide();
                return;
            }
            if (!self.overlay.classList.contains('show')) return;
            if (self.isProcessing) {
                self.nudgeClose();
                return;
            }
            if (self.currentMode === 'subscribe' && self.formDirty) {
                self.confirmDiscard();
                return;
            }
            self.hide();
        });
    },

    show: function(onSuccess) {
        this.onSuccess = onSuccess || '';
        this.overlay.classList.add('show');
        document.getElementById('config-upload-title').textContent = '<%:Add Config%>';
        this.reset();
        ConfigUploaderFocus.restoreTarget = document.activeElement;
        setTimeout(function() {
            var first = document.getElementById('config-filename-input');
            if (first) first.focus();
        }, 30);
    },

    showSummary: function(filename, onSuccess) {
        var self = this;
        if (!filename) return;
        SubPanel.kernelResult = null;
        this.isEditMode = false;
        this.onSuccess = onSuccess || '';
        this.overlay.classList.add('show');
        document.getElementById('config-upload-title').textContent = '<%:Config Summary%>';
        SubPanel.clearError();
        SubPanel.clearResult();
        SubPanel.setView('result');
        SubPanel.startResultLoading();
        XHR.get('<%=url("admin", "services", "openclash", "get_subscribe_data")%>', {
            filename: filename
        }, function(x, data) {
            var params = { name: filename, sub_convert: '0', plain: true };
            if (x && x.status == 200 && data && data.address) {
                params.plain = false;
                params.sub_convert = data.sub_convert === '1' ? '1' : '0';
                params.keyword_option = data.keyword_option || '';
                params.sub_headers = data.sub_headers || '';
                if (data.config_age_secret) params.age_secret = '1';
                if (params.sub_convert === '1') {
                    params.template_label = (data.template && data.template !== '0') ? data.template : (data.custom_template_url || '');
                }
            }
            self.lastParams = params;
            SubPanel.showResult(params);
        });
    },

    showEditSubscribe: function(subscribeData, filename, onSuccess) {
        this.onSuccess = onSuccess || '';
        this.overlay.classList.add('show');
        this.reset();
        this.editFilename = filename;

        var isSubscribe = subscribeData && subscribeData.address;
        var advFileEnable = document.getElementById('advanced-options-enable-file');
        var advFileContainer = document.getElementById('advanced-options-container-file');
        var ageNode = document.getElementById('age-encryption-group');
        var secretEl = document.getElementById('age-secret-input');
        var publicEl = document.getElementById('age-public-input');
        var algoSelect = document.getElementById('age-algo-select');
        this.isEditMode = true;

        if (isSubscribe) {
            this.switchMode('subscribe');
            document.getElementById('config-upload-title').textContent = '<%:Edit Subscription%>';
            document.getElementById('config-upload-submit').textContent = '<%:Save Subscription%>';
            this.fillSubscribeForm(subscribeData);
        } else {
            this.switchMode('file');
            document.getElementById('config-upload-title').textContent = '<%:Edit Config%>';
            document.getElementById('config-upload-submit').textContent = '<%:Edit Config%>';
            document.getElementById('config-filename-input').value = this.editFilename || '';

            try {
                if (subscribeData) {
                    var hasAge = false;
                    if (subscribeData.config_age_secret) {
                        if (secretEl) secretEl.value = subscribeData.config_age_secret;
                        hasAge = true;
                    }
                    if (subscribeData.config_age_public) {
                        if (publicEl) publicEl.value = subscribeData.config_age_public;
                        hasAge = true;
                    }
                    if (subscribeData.config_age_algo) {
                        if (algoSelect) try { algoSelect.value = subscribeData.config_age_algo; } catch (e) {}
                        hasAge = true;
                    }

                    if (hasAge && advFileEnable && advFileContainer) {
                        advFileEnable.checked = true;
                        advFileContainer.classList.remove('oc-hidden');

                        if (ageNode && ageNode.parentNode !== advFileContainer) advFileContainer.appendChild(ageNode);
                    }
                    if (hasAge) {
                        var advEnable = document.getElementById('advanced-options-enable');
                        var advContainer = document.getElementById('advanced-options-container');
                        if (advEnable) advEnable.checked = true;
                        if (advContainer) advContainer.classList.remove('oc-hidden');
                    }
                    if (ageNode) ageNode.style.display = '';
                }
            } catch (e) {}
        }

        if (subscribeData) {
            if (subscribeData.config_age_hidden) {
                advFileEnable.parentNode.parentNode.style.display = 'none';
                ageNode.style.display = 'none';
            }
        }

        this.updateSubmitButton();
    },

    hide: function() {
        this.overlay.classList.remove('show');
        this.reset();
        var target = ConfigUploaderFocus.restoreTarget;
        ConfigUploaderFocus.restoreTarget = null;
        if (target && target.focus) target.focus();
    },

    nudgeClose: function() {
        var btn = document.getElementById('config-upload-close');
        if (!btn) return;
        btn.classList.remove('oc-nudge');
        void btn.offsetWidth;
        btn.classList.add('oc-nudge');
        setTimeout(function() { btn.classList.remove('oc-nudge'); }, 400);
    },

    confirmDiscard: function() {
        var self = this;
        ocConfirm({
            title: '<%:Discard unsaved changes?%>',
            body: '<%:The edits in this form will be lost.%>',
            buttons: [
                { label: '<%:Keep editing%>', value: 'keep' },
                { label: '<%:Discard%>', value: 'discard', kind: 'danger' }
            ]
        }).then(function(choice) {
            if (choice === 'discard') self.hide();
        });
    },

    updateSubconverterVersionStatus: function() {
        if (this.subconverterVersionChecker) {
            this.subconverterVersionChecker.update();
        }
    },

    resetAdvancedOptions: function() {
        document.getElementById('sub-convert-enable').checked = false;
        document.getElementById('sub-convert-options').classList.add('oc-hidden');
        document.getElementById('convert-address-input').selectedIndex = 0;
        document.getElementById('convert-address-custom').classList.add('oc-hidden');
        document.getElementById('convert-address-custom').value = '';

        var templateSelect = document.getElementById('template-select');
        if (templateSelect && templateSelect.options.length > 1) {
            templateSelect.selectedIndex = 0;
        }

        document.getElementById('custom-template-group').classList.add('oc-hidden');
        document.getElementById('custom-template-input').value = '';

        document.getElementById('emoji-enable').checked = false;
        document.getElementById('udp-enable').checked = false;
        document.getElementById('skip-cert-verify').checked = true;
        document.getElementById('sort-enable').checked = false;
        document.getElementById('node-type-enable').checked = false;
        document.getElementById('rule-provider-enable').checked = false;
        document.getElementById('tfo-enable').checked = false;
        document.getElementById('tls13-enable').checked = false;
        document.getElementById('custom-params-input').value = '';

        document.getElementById('keyword-input').value = '';
        document.getElementById('exclude-keyword-input').value = '';
        document.getElementById('exclude-expire').checked = false;
        document.getElementById('exclude-traffic').checked = false;
        document.getElementById('exclude-plan').checked = false;
        document.getElementById('exclude-website').checked = false;
        var keyOptEnable = document.getElementById('keyword-options-enable');
        if (keyOptEnable) keyOptEnable.checked = false;
        var keyOptContainer = document.getElementById('keyword-options-container');
        if (keyOptContainer) keyOptContainer.classList.add('oc-hidden');
        document.getElementById('age-secret-input').value = '';
        document.getElementById('age-public-input').value = '';
        var advFileEnable = document.getElementById('advanced-options-enable-file');
        if (advFileEnable) advFileEnable.checked = false;
        var advFileContainer = document.getElementById('advanced-options-container-file');
        if (advFileContainer) advFileContainer.classList.add('oc-hidden');
        if (this.subconverterVersionChecker) this.subconverterVersionChecker.hide();
    },

    reset: function() {
        SubPanel.reset();
        this.selectedFile = null;
        this.isProcessing = false;
        this.currentMode = 'file';
        this.isEditMode = false;
        this.formDirty = false;
        this.submitAttempted = false;
        this.editFilename = null;

        this.switchMode('file');
        document.getElementById('config-filename-input').value = '';
        document.getElementById('subscribe-url-input').value = '';
        document.getElementById('subscribe-ua-input').value = 'clash-verge/v2.4.5';
        document.getElementById('subscribe-ua-custom').classList.add('oc-hidden');
        var hdrContainer = document.getElementById('subscribe-headers-container');
        hdrContainer.innerHTML = '';
        hdrContainer.classList.add('oc-hidden');

        document.getElementById('advanced-options-enable').checked = false;
        document.getElementById('advanced-options-container').classList.add('oc-hidden');
        var ageNodeEl = document.getElementById('age-encryption-group');
        if (ageNodeEl) ageNodeEl.style.display = '';
        var advFileEnableEl = document.getElementById('advanced-options-enable-file');
        if (advFileEnableEl && advFileEnableEl.parentNode && advFileEnableEl.parentNode.parentNode) {
            advFileEnableEl.parentNode.parentNode.style.display = '';
        }
        document.getElementById('config-upload-cancel').disabled = false;
        this.resetAdvancedOptions();

        var templateSelect = document.getElementById('template-select');
        if (templateSelect && templateSelect.options.length > 1) {
            templateSelect.selectedIndex = 0;
        }

        document.getElementById('upload-progress').classList.add('oc-hidden');
        var resetStatus = document.getElementById('config-upload-status-text');
        resetStatus.textContent = '<%:Ready to add config%>';
        resetStatus.classList.remove('is-error');
        document.getElementById('config-upload-submit').textContent = '<%:Add Config%>';
        this.setFilenameError('');
        this.setAgeError('');
        this.updateSubmitButton();
        this.updateFoldSummaries();
    },

    fillSubscribeForm: function(data) {
        if (!data) return;

        if (this.editFilename) {
            document.getElementById('config-filename-input').value = this.editFilename;
        }

        if (data.address) {
            document.getElementById('subscribe-url-input').value = data.address;
        }
        if (data.sub_ua) {
            if (data.sub_ua === 'clash.meta/1.19.20' || data.sub_ua === 'clash-verge/v2.4.5' || data.sub_ua === 'Clash' || data.sub_ua === 'custom') {
                document.getElementById('subscribe-ua-input').value = data.sub_ua;
                if (data.sub_ua === 'custom') {
                    document.getElementById('subscribe-ua-custom').classList.remove('oc-hidden');
                    document.getElementById('subscribe-ua-custom').value = data.sub_ua_custom || '';
                }
            } else {
                document.getElementById('subscribe-ua-input').value = 'custom';
                document.getElementById('subscribe-ua-custom').classList.remove('oc-hidden');
                document.getElementById('subscribe-ua-custom').value = data.sub_ua;
            }
        }

        if (data.sub_headers) {
            var container = document.getElementById('subscribe-headers-container');
            container.innerHTML = '';
            var lines = data.sub_headers.split('\n');
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim();
                if (line) {
                    var colonIdx = line.indexOf(':');
                    var name = colonIdx > 0 ? line.substring(0, colonIdx).trim() : line;
                    var value = colonIdx > 0 ? line.substring(colonIdx + 1).trim() : '';
                    ConfigUploader.addHeaderRow(name, value);
                }
            }
        }

        var hasAge = data.config_age_secret || data.config_age_public || data.config_age_algo;
        if (data.sub_headers || hasAge) {
            var advContainer = document.getElementById('advanced-options-container');
            var ageNode = document.getElementById('age-encryption-group');
            document.getElementById('advanced-options-enable').checked = true;
            if (advContainer) advContainer.classList.remove('oc-hidden');
            if (ageNode && advContainer && ageNode.parentNode !== advContainer) advContainer.appendChild(ageNode);
            if (ageNode) ageNode.style.display = '';
        }
        if (hasAge) {
            var advFileEnable = document.getElementById('advanced-options-enable-file');
            var advFileContainer = document.getElementById('advanced-options-container-file');
            if (advFileEnable) advFileEnable.checked = true;
            if (advFileContainer) advFileContainer.classList.remove('oc-hidden');
        }

        if (data.sub_convert === '1') {
            document.getElementById('sub-convert-enable').checked = true;
            document.getElementById('sub-convert-options').classList.remove('oc-hidden');

            if (data.convert_address) {
                if (data.convert_address === 'https://api.wcc.best/sub' || data.convert_address === 'https://api.asailor.org/sub') {
                    document.getElementById('convert-address-input').value = data.convert_address;
                    if (data.convert_address === 'custom') {
                        document.getElementById('convert-address-custom').classList.remove('oc-hidden');
                        document.getElementById('convert-address-custom').value = data.convert_address_custom || '';
                    }
                } else {
                    document.getElementById('convert-address-input').value = 'custom';
                    document.getElementById('convert-address-custom').classList.remove('oc-hidden');
                    document.getElementById('convert-address-custom').value = data.convert_address;
                }
            }

            if (data.template) {
                var templateSelect = document.getElementById('template-select');
                var found = false;
                for (var i = 0; i < templateSelect.options.length; i++) {
                    if (templateSelect.options[i].value === data.template) {
                        templateSelect.selectedIndex = i;
                        found = true;
                        break;
                    }
                }
                if (!found && data.template !== '0') {
                    templateSelect.value = '0';
                    document.getElementById('custom-template-group').classList.remove('oc-hidden');
                    document.getElementById('custom-template-input').value = data.template;
                } else if (data.template === '0') {
                    templateSelect.value = '0';
                    document.getElementById('custom-template-group').classList.remove('oc-hidden');
                    document.getElementById('custom-template-input').value = data.custom_template_url || data.custom_template || '';
                }
            }

            document.getElementById('emoji-enable').checked = data.emoji === 'true';
            document.getElementById('udp-enable').checked = data.udp === 'true';
            document.getElementById('skip-cert-verify').checked = data.skip_cert_verify === 'true';
            document.getElementById('sort-enable').checked = data.sort === 'true';
            document.getElementById('node-type-enable').checked = data.node_type === 'true';
            document.getElementById('rule-provider-enable').checked = data.rule_provider === 'true';
            document.getElementById('tfo-enable').checked = data.tfo === 'true';
            document.getElementById('tls13-enable').checked = data.tls13 === 'true';

            if (data.custom_params) {
                document.getElementById('custom-params-input').value = data.custom_params;
            }
        }

        if (data.keyword_option === '1' || data.keyword || data.ex_keyword || data.de_ex_keyword) {
            var keyOptEnable = document.getElementById('keyword-options-enable');
            if (keyOptEnable) keyOptEnable.checked = true;
            var keyOptContainer = document.getElementById('keyword-options-container');
            if (keyOptContainer) keyOptContainer.classList.remove('oc-hidden');
        }

        if (data.keyword) {
            document.getElementById('keyword-input').value = data.keyword;
        }
        if (data.ex_keyword) {
            document.getElementById('exclude-keyword-input').value = data.ex_keyword;
        }
        if (data.de_ex_keyword) {
            var defaults = data.de_ex_keyword.split(' ');
            document.getElementById('exclude-expire').checked = defaults.indexOf(document.getElementById('exclude-expire').value) !== -1;
            document.getElementById('exclude-traffic').checked = defaults.indexOf(document.getElementById('exclude-traffic').value) !== -1;
            document.getElementById('exclude-plan').checked = defaults.indexOf(document.getElementById('exclude-plan').value) !== -1;
            document.getElementById('exclude-website').checked = defaults.indexOf(document.getElementById('exclude-website').value) !== -1;
        }

        var secretEl = document.getElementById('age-secret-input');
        var publicEl = document.getElementById('age-public-input');
        if (secretEl) secretEl.value = data.config_age_secret || '';
        if (publicEl) publicEl.value = data.config_age_public || '';
        if (data.config_age_algo) {
            var algoSelect = document.getElementById('age-algo-select');
            if (algoSelect) {
                try { algoSelect.value = data.config_age_algo; } catch (e) {}
            }
        }

        this.updateSubconverterVersionStatus();
        this.updateFoldSummaries();
        this.updateUrlFeedback();
    },

    switchMode: function(mode) {
        this.currentMode = mode;

        var modeFileTab = document.getElementById('upload-mode-file');
        var modeSubscribeTab = document.getElementById('upload-mode-subscribe');
        var modeFileContent = document.getElementById('mode-file-content');
        var modeSubscribeContent = document.getElementById('mode-subscribe-content');
        var statusText = document.getElementById('config-upload-status-text');
        var uploadZone = document.getElementById('upload-zone');

        modeFileTab.classList.remove('oc-hidden');
        modeSubscribeTab.classList.remove('oc-hidden');

        modeFileTab.classList.remove('active');
        modeSubscribeTab.classList.remove('active');
        modeFileContent.classList.add('oc-hidden');
        modeSubscribeContent.classList.add('oc-hidden');

        statusText.classList.remove('is-error');
        this.setFilenameError('');
        if (mode === 'file') {
            modeFileTab.classList.add('active');
            modeFileContent.classList.remove('oc-hidden');
            statusText.textContent = '<%:Ready to upload file%>';
        } else if (mode === 'subscribe') {
            modeSubscribeTab.classList.add('active');
            modeSubscribeContent.classList.remove('oc-hidden');
            statusText.textContent = this.formDirty ? '<%:Unsaved changes%>' : (this.isEditMode ? '<%:Ready to edit subscription%>' : '<%:Ready to add subscription%>');
        }

        var ageNode = document.getElementById('age-encryption-group');
        var advancedOptionsEnableEl = document.getElementById('advanced-options-enable');
        var advancedOptionsContainerEl = document.getElementById('advanced-options-container');
        var advancedOptionsEnableFileEl = document.getElementById('advanced-options-enable-file');
        var advancedOptionsContainerFileEl = document.getElementById('advanced-options-container-file');

        if (ageNode) {
            if (mode === 'file') {
                if (advancedOptionsEnableFileEl && advancedOptionsEnableFileEl.checked && advancedOptionsContainerFileEl) {
                    if (ageNode.parentNode !== advancedOptionsContainerFileEl) advancedOptionsContainerFileEl.appendChild(ageNode);
                } else if (advancedOptionsContainerEl) {
                    if (ageNode.parentNode !== advancedOptionsContainerEl) advancedOptionsContainerEl.appendChild(ageNode);
                }
            } else if (mode === 'subscribe') {
                if (advancedOptionsContainerEl) {
                    if (ageNode.parentNode !== advancedOptionsContainerEl) advancedOptionsContainerEl.appendChild(ageNode);
                }
            }
        }

        this.selectedFile = null;
        uploadZone.classList.remove('has-file');
        uploadZone.querySelector('.upload-primary').textContent = '<%:Click to select file or drag and drop%>';
        uploadZone.querySelector('.upload-secondary').textContent = '<%:Support YAML file, max size 10MB%>';

        this.updateSubmitButton();
        this.updateFoldSummaries();
        if (mode === 'subscribe') this.updateUrlFeedback();
    },

    handleFileSelect: function(file) {
        this.selectedFile = file;
        var uploadZone = document.getElementById('upload-zone');
        var filenameInput = document.getElementById('config-filename-input');
        var statusText = document.getElementById('config-upload-status-text');
        this.setFilenameError('');

        if (!file) {
            uploadZone.classList.remove('has-file');
            this.updateSubmitButton();
            statusText.classList.remove('is-error');
            statusText.textContent = '<%:Ready to upload file%>';
            return;
        }

        if (!file.name.match(/\.(yaml|yml)$/i)) {
            this.selectedFile = null;
            uploadZone.classList.remove('has-file');
            uploadZone.querySelector('.upload-primary').textContent = '<%:Click to select file or drag and drop%>';
            uploadZone.querySelector('.upload-secondary').textContent = '<%:Support YAML file, max size 10MB%>';
            statusText.classList.add('is-error');
            statusText.textContent = '<%:Please select a YAML file%>';
            this.updateSubmitButton();
            return;
        }

        if (file.size > 10 * 1024 * 1024) {
            this.selectedFile = null;
            uploadZone.classList.remove('has-file');
            uploadZone.querySelector('.upload-primary').textContent = '<%:Click to select file or drag and drop%>';
            uploadZone.querySelector('.upload-secondary').textContent = '<%:Support YAML file, max size 10MB%>';
            statusText.classList.add('is-error');
            statusText.textContent = '<%:File size exceeds 10MB limit%>';
            this.updateSubmitButton();
            return;
        }

        uploadZone.classList.add('has-file');
        uploadZone.querySelector('.upload-primary').textContent = '<%:File selected:%> ' + file.name;
        uploadZone.querySelector('.upload-secondary').textContent = '<%:Size:%> ' + ocFormatSize(file.size);

        var defaultName = file.name.replace(/\.(yaml|yml)$/i, '');
        filenameInput.value = defaultName;

        this.updateSubmitButton();
        statusText.classList.remove('is-error');
        statusText.textContent = '<%:File ready to upload%>';
    },

    updateSubmitButton: function() {
        var filename = document.getElementById('config-filename-input').value.trim();
        var submitBtn = document.getElementById('config-upload-submit');
        var isValidFormat = false;

        if (this.currentMode === 'file') {
            isValidFormat = !!filename;
        } else if (this.currentMode === 'subscribe') {
            var url = document.getElementById('subscribe-url-input').value.trim();
            var agePublic = document.getElementById('age-public-input') ? document.getElementById('age-public-input').value.trim() : '';
            var ageSecret = document.getElementById('age-secret-input') ? document.getElementById('age-secret-input').value.trim() : '';

            if (url && filename) {
                isValidFormat = this.validateSubscribeUrl().state === 'ok';
            } else if (filename && (agePublic || ageSecret)) {
                isValidFormat = this.isEditMode;
            }
        }
        else if (this.currentMode === 'age') {
            isValidFormat = !!filename;
        }

        submitBtn.disabled = !isValidFormat || this.isProcessing;
    },

    validateSubscribeUrl: function() {
        var input = document.getElementById('subscribe-url-input');
        var url = input ? input.value.trim() : '';

        if (!url) return { state: 'empty' };

        if (document.getElementById('sub-convert-enable').checked) {
            var links = UrlValidator.extractUrls(url, true);
            if (links.length > 0 && UrlValidator.anyValid(links, true)) return { state: 'ok' };
            return { state: 'invalid', reason: links.length > 0 ? UrlValidator.validateUrl(links[0], true).reason : '<%:Invalid URL format%>' };
        }

        if (!/^https?:\/\//.test(url) || url.indexOf('\n') !== -1) {
            return { state: 'invalid', reason: '<%:Invalid URL format%>' };
        }
        var singleUrls = UrlValidator.extractUrls(url, false);
        if (singleUrls.length === 1 && UrlValidator.validateUrl(singleUrls[0], false).valid) return { state: 'ok' };
        return { state: 'invalid', reason: singleUrls.length === 1 ? UrlValidator.validateUrl(singleUrls[0], false).reason : '<%:Invalid URL format%>' };
    },

    updateUrlFeedback: function() {
        if (this.currentMode !== 'subscribe') return;
        var input = document.getElementById('subscribe-url-input');
        var errEl = document.getElementById('subscribe-url-error');
        var statusEl = document.getElementById('config-upload-status-text');
        if (!input || !errEl || !statusEl || this.isProcessing) return;

        var result = this.validateSubscribeUrl();
        if (result.state === 'invalid') {
            errEl.textContent = result.reason;
            errEl.classList.remove('oc-hidden');
        } else {
            errEl.classList.add('oc-hidden');
        }
        input.classList.toggle('oc-invalid', result.state === 'invalid');

        var filename = document.getElementById('config-filename-input').value.trim();
        var ageSecret = document.getElementById('age-secret-input') ? document.getElementById('age-secret-input').value.trim() : '';
        var agePublic = document.getElementById('age-public-input') ? document.getElementById('age-public-input').value.trim() : '';
        var ageOnly = this.isEditMode && (ageSecret || agePublic);

        var hardError = false;
        if (result.state === 'empty' && !(ageOnly && filename)) {
            statusEl.textContent = '<%:Still required: Subscribe URL%>';
            statusEl.dataset.ocRequired = '1';
        } else if (result.state === 'invalid') {
            statusEl.textContent = '<%:Invalid subscription URL format%>';
            statusEl.dataset.ocRequired = '1';
            hardError = true;
        } else if (!filename) {
            statusEl.textContent = '<%:Still required: Config Name%>';
            statusEl.dataset.ocRequired = '1';
        } else if (statusEl.dataset.ocRequired === '1') {
            statusEl.textContent = this.formDirty ? '<%:Unsaved changes%>' : (this.isEditMode ? '<%:Ready to edit subscription%>' : '<%:Ready to add subscription%>');
            delete statusEl.dataset.ocRequired;
        }
        statusEl.classList.toggle('is-error', statusEl.dataset.ocRequired === '1' && (hardError || this.submitAttempted));
    },

    updateFoldSummaries: function() {
        var sumConvert = document.getElementById('sum-convert');
        if (sumConvert) {
            if (!document.getElementById('sub-convert-enable').checked) {
                sumConvert.textContent = '<%:Convert: off%>';
            } else {
                var addrSelect = document.getElementById('convert-address-input');
                var addr = addrSelect.value === 'custom' ? (document.getElementById('convert-address-custom').value.trim() || '<%:Custom%>') : (addrSelect.options[addrSelect.selectedIndex] ? addrSelect.options[addrSelect.selectedIndex].textContent : addrSelect.value);
                var tplSelect = document.getElementById('template-select');
                var tpl = tplSelect.value === '0' ? '<%:Custom Template%>' : (tplSelect.options[tplSelect.selectedIndex] ? tplSelect.options[tplSelect.selectedIndex].textContent : tplSelect.value);
                tpl = tpl.split('（')[0].split('(')[0].trim() || tpl;
                sumConvert.textContent = '<%:Convert: on%>' + ' · ' + addr + ' · ' + tpl;
            }
        }

        var sumFilter = document.getElementById('sum-filter');
        if (sumFilter) {
            if (!document.getElementById('keyword-options-enable').checked) {
                sumFilter.textContent = '<%:Filter: off%>';
            } else {
                var parts = [];
                var countLines = function(id) {
                    var v = document.getElementById(id).value.trim();
                    if (!v) return 0;
                    var n = 0;
                    var lines = v.split('\n');
                    for (var i = 0; i < lines.length; i++) {
                        if (lines[i].trim() !== '') n++;
                    }
                    return n;
                };
                var includeCount = countLines('keyword-input');
                var excludeCount = countLines('exclude-keyword-input');
                var defaultCount = 0;
                var defaultIds = ['exclude-expire', 'exclude-traffic', 'exclude-plan', 'exclude-website'];
                for (var d = 0; d < defaultIds.length; d++) {
                    if (document.getElementById(defaultIds[d]).checked) defaultCount++;
                }
                if (includeCount > 0) parts.push('<%:Include%> ' + includeCount);
                if (excludeCount > 0) parts.push('<%:Exclude%> ' + excludeCount);
                if (defaultCount > 0) parts.push('<%:Auto Exclude%> ' + defaultCount);
                sumFilter.textContent = '<%:Filter: on%>' + (parts.length > 0 ? ' · ' + parts.join(' · ') : '');
            }
        }

        var sumAdvanced = document.getElementById('sum-advanced');
        if (sumAdvanced) {
            var headerRows = document.querySelectorAll('#subscribe-headers-container .header-row');
            var headerCount = 0;
            for (var h = 0; h < headerRows.length; h++) {
                if (headerRows[h].querySelectorAll('input')[0].value.trim()) headerCount++;
            }
            var ageSecret = document.getElementById('age-secret-input') ? document.getElementById('age-secret-input').value.trim() : '';
            var agePublic = document.getElementById('age-public-input') ? document.getElementById('age-public-input').value.trim() : '';

            var advParts = [];
            if (headerCount > 0) advParts.push('<%:Custom Headers%> ' + headerCount);
            if (ageSecret || agePublic) advParts.push('<%:Age Key%>');
            sumAdvanced.textContent = advParts.length > 0 ? advParts.join(' · ') : '<%:Default%>';
        }
    },

    setFilenameError: function(message) {
        var errEl = document.getElementById('config-filename-error');
        var input = document.getElementById('config-filename-input');
        if (errEl) {
            if (message) {
                errEl.textContent = message;
                errEl.classList.remove('oc-hidden');
            } else {
                errEl.classList.add('oc-hidden');
            }
        }
        if (input) input.classList.toggle('oc-invalid', !!message);
    },

    setAgeError: function(message) {
        var errEl = document.getElementById('age-key-error');
        if (!errEl) return;
        if (message) {
            errEl.textContent = message;
            errEl.classList.remove('oc-hidden');
        } else {
            errEl.classList.add('oc-hidden');
        }
    },

    finishUpload: function(filename) {
        this.isProcessing = false;
        this.lastParams = { name: filename, plain: true };
        SubPanel.clearError();
        SubPanel.setView('result');
        var status = document.getElementById('sub-result-status');
        if (status) status.textContent = '<%:Config saved%>';
        SubPanel.showResult(this.lastParams);
        if (this.onSuccess) setTimeout(this.onSuccess, 0);
    },

    uploadFile: function() {
        if (this.isProcessing) return;
        var filename = document.getElementById('config-filename-input').value.trim();
        if (!filename) {
            this.setFilenameError('<%:Please enter a filename%>');
            return;
        }

        if (!/^[a-zA-Z0-9_\-\s\u4e00-\u9fa5\.]+$/.test(filename)) {
            this.setFilenameError('<%:Filename contains invalid characters%>');
            return;
        }
        this.setFilenameError('');

        if (this.editFilename || this.selectedFile) {
            var advFileEnableEl = document.getElementById('advanced-options-enable-file');
            var advFileChecked = advFileEnableEl ? advFileEnableEl.checked : false;
            var ageSecret = advFileChecked ? (document.getElementById('age-secret-input').value || '') : '';
            var agePublic = advFileChecked ? (document.getElementById('age-public-input').value || '') : '';
            var ageAlgoEl = document.getElementById('age-algo-select'), ageAlgo = advFileChecked ? (ageAlgoEl ? ageAlgoEl.value : '') : '';

            XHR.get('<%=url("admin", "services", "openclash", "add_age_config")%>', {
                name: filename,
                age_secret: ageSecret,
                age_public: agePublic,
                age_algo: ageAlgo
            }, function(x3, data3) {

            });
        }

        var self = this;
        this.isProcessing = true;

        var submitBtn = document.getElementById('config-upload-submit');
        var cancelBtn = document.getElementById('config-upload-cancel');
        var statusText = document.getElementById('config-upload-status-text');
        var progressContainer = document.getElementById('upload-progress');
        var progressFill = document.getElementById('upload-progress-fill');
        var progressText = document.getElementById('upload-progress-text');

        submitBtn.disabled = true;
        cancelBtn.disabled = true;
        statusText.classList.remove('is-error');
        statusText.textContent = '<%:Uploading...%>';

        if (!this.selectedFile) {
            if (this.editFilename) {
                this.finishUpload(filename);
                return;
            }
            var targetName = /\.ya?ml$/i.test(filename) ? filename : filename + '.yaml';
            XHR.get('<%=url("admin", "services", "openclash", "create_file")%>', {
                filename: targetName,
                filepath: '/etc/openclash/config/'
            }, function(x, status) {
                if (x && x.status == 200) {
                    self.finishUpload(targetName);
                } else {
                    self.handleError('<%:Upload failed%>');
                }
            });
            return;
        }

        progressContainer.classList.remove('oc-hidden');

        var progress = 0;
        var progressInterval = setInterval(function() {
            if (progress < 90) {
                progress += Math.random() * 15;
                progressFill.style.width = Math.min(progress, 90) + '%';
                progressText.textContent = '<%:Uploading...%> ' + Math.floor(Math.min(progress, 90)) + '%';
            }
        }, 100);

        var reader = new FileReader();
        reader.onload = function(e) {
            var fileContent = e.target.result;

            var formData = new FormData();
            formData.append('config_file', fileContent);
            formData.append('filename', filename);

            fetch('<%=url("admin", "services", "openclash", "upload_config")%>', {
                method: 'POST',
                body: formData
            })
            .then(function(response) {
                clearInterval(progressInterval);

                if (!response.ok) {
                    throw new Error('HTTP error! status: ' + response.status);
                }
                return response.json();
            })
            .then(function(data) {
                progressFill.style.width = '100%';
                progressText.textContent = '<%:Upload completed%> 100%';

                if (data.status === 'success') {
                    self.finishUpload(filename);
                } else {
                    throw new Error(data.message || '<%:Upload failed%>');
                }
            })
            .catch(function(error) {
                self.handleError('<%:Upload failed:%> ' + error.message);
            });
        };

        reader.onerror = function() {
            clearInterval(progressInterval);
            self.handleError('<%:Failed to read file%>');
        };

        reader.readAsText(this.selectedFile, 'UTF-8');
    },

    processSubscription: function() {
        var url = document.getElementById('subscribe-url-input').value.trim();
        var filename = document.getElementById('config-filename-input').value.trim();
        var userAgent = document.getElementById('subscribe-ua-input').value;
        var subscribeUaCustom = document.getElementById('subscribe-ua-custom');

        var subConvert = document.getElementById('sub-convert-enable').checked;

        var convertAddress = '';
        var template = '';
        var emoji = false;
        var udp = false;
        var skipCert = false;
        var sort = false;
        var nodeType = false;
        var ruleProvider = false;
        var tfo = false;
        var tls13 = false;
        var customTemplateUrl = '';
        var customParams = '';
        var keywords = '';
        var excludeKeywords = '';
        var excludeDefaults = [];
        var customHeaders = ConfigUploader.collectHeaders();

        if (subConvert) {
            convertAddress = document.getElementById('convert-address-input').value;
            var convertAddressCustom = document.getElementById('convert-address-custom').value;
            template = document.getElementById('template-select').value;
            var customTemplate = document.getElementById('custom-template-input').value;
            emoji = document.getElementById('emoji-enable').checked;
            udp = document.getElementById('udp-enable').checked;
            skipCert = document.getElementById('skip-cert-verify').checked;
            sort = document.getElementById('sort-enable').checked;
            nodeType = document.getElementById('node-type-enable').checked;
            ruleProvider = document.getElementById('rule-provider-enable').checked;
            tfo = document.getElementById('tfo-enable').checked;
            tls13 = document.getElementById('tls13-enable').checked;
            customParams = document.getElementById('custom-params-input').value;

            if (convertAddress === 'custom') {
                convertAddress = convertAddressCustom.trim();
            }

            if (template === '0') {
                customTemplateUrl = customTemplate.trim();
            }
        }

        var keywordOption = document.getElementById('keyword-options-enable').checked;

        if (keywordOption) {
            keywords = document.getElementById('keyword-input').value;
            excludeKeywords = document.getElementById('exclude-keyword-input').value;

            if (document.getElementById('exclude-expire').checked) excludeDefaults.push(document.getElementById('exclude-expire').value);
            if (document.getElementById('exclude-traffic').checked) excludeDefaults.push(document.getElementById('exclude-traffic').value);
            if (document.getElementById('exclude-plan').checked) excludeDefaults.push(document.getElementById('exclude-plan').value);
            if (document.getElementById('exclude-website').checked) excludeDefaults.push(document.getElementById('exclude-website').value);
        }

        if (userAgent === 'custom') {
            userAgent = subscribeUaCustom.value.trim();
        }

        var advancedEnable = document.getElementById('advanced-options-enable') ? document.getElementById('advanced-options-enable').checked : false;
        var ageSecretVal = '';
        var agePublicVal = '';
        if (advancedEnable) {
            ageSecretVal = document.getElementById('age-secret-input') ? document.getElementById('age-secret-input').value.trim() : '';
            agePublicVal = document.getElementById('age-public-input') ? document.getElementById('age-public-input').value.trim() : '';
        }

        if (!filename) {
            this.setFilenameError('<%:Please enter subscription config name%>');
            return;
        }
        this.setFilenameError('');

        var urlInput = document.getElementById('subscribe-url-input');
        if ((!url || url === '') && !ageSecretVal) {
            this.updateUrlFeedback();
            if (urlInput) urlInput.focus();
            return;
        }

        var isValidFormat = (!url || url === '') ?
            (this.isEditMode && !!ageSecretVal) :
            this.validateSubscribeUrl().state === 'ok';

        if (!isValidFormat) {
            this.updateUrlFeedback();
            if (urlInput) urlInput.focus();
            return;
        }

        var self = this;
        this.isProcessing = true;

        var submitBtn = document.getElementById('config-upload-submit');
        var cancelBtn = document.getElementById('config-upload-cancel');
        var statusText = document.getElementById('config-upload-status-text');

        submitBtn.disabled = true;
        cancelBtn.disabled = true;
        statusText.classList.remove('is-error');
        statusText.textContent = this.isEditMode ? '<%:Updating subscription...%>' : '<%:Adding subscription...%>';

        var ageSecret = advancedEnable ? (document.getElementById('age-secret-input').value || '') : '';
        var agePublic = advancedEnable ? (document.getElementById('age-public-input').value || '') : '';
        var ageAlgoEl = document.getElementById('age-algo-select'), ageAlgo = advancedEnable ? (ageAlgoEl ? ageAlgoEl.value : '') : '';

        var finishSave = function() {
            statusText.textContent = self.isEditMode ? '<%:Subscription updated successfully%>' : '<%:Subscription added successfully%>';
            setTimeout(function() {
                self.hide();
                self.isProcessing = false;
                if (self.onSuccess) setTimeout(self.onSuccess, 0);
            }, 1200);
        };

        var templateLabel = '';
        if (subConvert) {
            if (template === '0') {
                templateLabel = customTemplateUrl;
            } else {
                var tSelect = document.getElementById('template-select');
                if (tSelect && tSelect.selectedIndex >= 0 && tSelect.options[tSelect.selectedIndex]) {
                    templateLabel = tSelect.options[tSelect.selectedIndex].textContent || template;
                } else {
                    templateLabel = template;
                }
            }
        }

        var params = {
            name: filename,
            address: url,
            sub_ua: userAgent,
            sub_convert: subConvert ? '1' : '0',
            convert_address: convertAddress,
            template: template,
            custom_template_url: customTemplateUrl,
            emoji: emoji ? 'true' : 'false',
            udp: udp ? 'true' : 'false',
            skip_cert_verify: skipCert ? 'true' : 'false',
            sort: sort ? 'true' : 'false',
            node_type: nodeType ? 'true' : 'false',
            rule_provider: ruleProvider ? 'true' : 'false',
            tfo: tfo ? 'true' : 'false',
            tls13: tls13 ? 'true' : 'false',
            custom_params: customParams,
            keyword_option: keywordOption ? '1' : '0',
            keyword: keywords,
            ex_keyword: excludeKeywords,
            de_ex_keyword: excludeDefaults.join(' '),
            sub_headers: customHeaders,
            template_label: templateLabel,
            age_secret: (ageSecret || agePublic) ? '1' : ''
        };
        this.lastParams = params;

        XHR.get('<%=url("admin", "services", "openclash", "add_age_config")%>', {
            name: filename,
            age_secret: ageSecret,
            age_public: agePublic,
            age_algo: ageAlgo
        }, function(x3, data3) {
            if (!url) {
                self.isProcessing = false;
                finishSave();
                return;
            }
            self.runSubscription(params);
        });
    },

    // The update call defers the core restart to the switch step of this flow.
    runSubscription: function(params) {
        var self = this;
        this.isProcessing = true;
        this.pendingResult = null;
        SubPanel.kernelResult = null;
        SubPanel.clearError();
        SubPanel.setView('progress');
        SubPanel.resetStage();
        SubPanel.startTimer('sub-elapsed', 0);
        SubPanel.startStream('sub-log-host', 'openclash.sh', function() {
            XHR.get('<%=url("admin", "services", "openclash", "add_subscription")%>', params, function(x, data) {
                if (x && x.status == 200 && data && data.status === 'success') {
                    XHR.get('<%=url("admin", "services", "openclash", "update_config")%>', {
                        filename: params.name,
                        no_restart: '1'
                    }, function(x2, data2) {
                        if (x2 && x2.status == 200 && data2 && data2.status === 'success') {
                            SubPanel.stopTimer();
                            self.isProcessing = false;
                            self.whenStreamSettled(params);
                            return;
                        }
                        self.isProcessing = false;
                        SubPanel.showError(self.isEditMode ? '<%:Failed to update subscription config%>' : '<%:Failed to download subscription config%>');
                    });
                } else {
                    self.isProcessing = false;
                    SubPanel.showError(self.isEditMode ? '<%:Failed to update subscription%>' : '<%:Failed to add subscription%>');
                }
            });
        });
    },

    // failures and the test result arrive a moment after the update returns: wait for the
    // stream's last line instead of racing it
    whenStreamSettled: function(params) {
        var self = this;
        var tries = 0;
        var check = function() {
            if (SubPanel.streamDone || ++tries > 20) {
                self.showResultOrError(params);
                return;
            }
            setTimeout(check, 500);
        };
        check();
    },

    // failures come through the script exit code, so a settled stream means the work is done;
    // the summary fetches its stats on demand, letting the footer leave the running state early
    showResultOrError: function(params) {
        SubPanel.setStage(4);
        SubPanel.markProgressDone();
        this.pendingResult = { params: params };
    },

    openPendingResult: function() {
        if (!this.pendingResult) return;
        var pending = this.pendingResult;
        this.pendingResult = null;
        SubPanel.showResult(pending.params);
    },

    retryOperation: function(plain) {
        var params = this.lastParams;
        if (!params) return;
        var source = {};
        for (var k in params) {
            if (Object.prototype.hasOwnProperty.call(params, k)) {
                source[k] = params[k];
            }
        }
        if (plain) {
            source.sub_convert = '0';
            source.template = '';
            source.custom_template_url = '';
            source.convert_address = '';
        }
        this.runSubscription(source);
    },

    resultFilename: function() {
        return this.lastParams ? this.lastParams.name : '';
    },

    refreshResult: function() {
        if (!this.lastParams) return;
        var self = this;
        SubPanel.startResultLoading();
        XHR.get('<%=url("admin", "services", "openclash", "config_stats")%>', {
            filename: this.lastParams.name
        }, function(x, data) {
            if (x && x.status == 200 && data && data.status === 'success') {
                SubPanel.renderFromStats(data, self.lastParams);
            } else {
                SubPanel.showStatsUnavailable();
                SubPanel.resultLoadDone();
            }
        });
        SubPanel.refreshSubInfo(this.lastParams.name);
    },

    switchCurrent: function() {
        var name = this.resultFilename();
        if (!name) return;
        var self = this;
        CoreStartFlow.run(name, function() {
            if (self.onSuccess) setTimeout(self.onSuccess, 0);
        });
    },

    autoFillConfigName: function() {
        var url = document.getElementById('subscribe-url-input').value.trim();
        var filenameInput = document.getElementById('config-filename-input');

        if (!filenameInput.value.trim() && url) {
            try {
                var match = url.match(/https?:\/\/[^,\s|]+/i);
                if (!match) {
                    try {
                        var decoded = decodeURIComponent(url);
                        match = decoded.match(/https?:\/\/[^,\s|]+/i);
                    } catch (e) {
                        match = null;
                    }
                }

                var urlToParse = match ? match[0] : url;
                var urlObj = new URL(urlToParse);
                var hostname = urlObj.hostname;

                var configName = hostname
                    .replace(/^(www\.|api\.|sub\.|subscribe\.)/, '')
                    .replace(/\.(com|net|org|cn|io|me|cc|xyz|top)$/, '')
                    .replace(/[^a-zA-Z0-9\u4e00-\u9fa5]/g, '_')
                    .replace(/_{2,}/g, '_')
                    .replace(/^_|_$/g, '');

                if (!configName || configName.length < 2) {
                    configName = 'subscription_' + Date.now().toString().slice(-6);
                }

                if (configName.length > 30) {
                    configName = configName.substring(0, 30);
                }

                filenameInput.value = configName;
            } catch (e) {
            }
        }
    },

    addHeaderRow: function(name, value) {
        var container = document.getElementById('subscribe-headers-container');
        var row = document.createElement('div');
        row.className = 'form-row header-row';
        row.style.cssText = 'align-items: center; gap: 6px; margin-bottom: 6px;';

        var nameInput = document.createElement('input');
        nameInput.type = 'text';
        nameInput.className = 'form-input';
        nameInput.placeholder = 'Header-Name';
        nameInput.value = name || '';
        nameInput.style.cssText = 'flex: 1; height: 32px;';

        var valueInput = document.createElement('input');
        valueInput.type = 'text';
        valueInput.className = 'form-input';
        valueInput.placeholder = 'value';
        valueInput.value = value || '';
        valueInput.style.cssText = 'flex: 1.5; height: 32px;';

        var removeBtn = document.createElement('button');
        removeBtn.type = 'button';
        removeBtn.className = 'icon-btn';
        removeBtn.title = '<%:Remove%>';
        removeBtn.style.cssText = 'flex-shrink: 0;';
        removeBtn.innerHTML = '<svg width="14" height="14"><use href="#oc-icon-close"/></svg>';
        removeBtn.addEventListener('click', function() {
            row.parentNode.removeChild(row);
            if (container.children.length === 0) {
                container.classList.add('oc-hidden');
            }
            ConfigUploader.updateFoldSummaries();
        });

        row.appendChild(nameInput);
        row.appendChild(valueInput);
        row.appendChild(removeBtn);
        container.appendChild(row);
        container.classList.remove('oc-hidden');
        this.updateFoldSummaries();
    },

    collectHeaders: function() {
        var rows = document.querySelectorAll('#subscribe-headers-container .header-row');
        var headers = [];
        for (var i = 0; i < rows.length; i++) {
            var inputs = rows[i].querySelectorAll('input');
            var name = inputs[0].value.trim();
            var value = inputs[1].value.trim();
            if (name) {
                headers.push(name + ': ' + (value || ''));
            }
        }
        return headers.join('\n');
    },

    handleError: function(message) {
        var statusText = document.getElementById('config-upload-status-text');
        var progressText = document.getElementById('upload-progress-text');
        var progressFill = document.getElementById('upload-progress-fill');
        var submitBtn = document.getElementById('config-upload-submit');
        var cancelBtn = document.getElementById('config-upload-cancel');
        var progressContainer = document.getElementById('upload-progress');

        statusText.textContent = message || '<%:Process failed%>';
        statusText.classList.add('is-error');
        progressText.textContent = '<%:Process failed%>';
        progressFill.style.width = '0%';

        this.isProcessing = false;
        submitBtn.disabled = false;
        cancelBtn.disabled = false;
        progressContainer.classList.add('oc-hidden');
    }
};

// start flow (steps + log) shared by the summary switch action and the status page log
// viewer; the viewer reuses the status log stream instead of opening a second one
var CoreStartFlow = {
    overlay: null,
    mode: '',
    mirrorTimer: null,
    shownLines: 0,
    lastMirrored: null,
    lastElapsed: 0,
    sessionStart: 0,
    viewTimer: null,
    viewPollTimer: null,
    viewPollXhr: null,
    viewRestartSeen: false,

    init: function() {
        this.overlay = document.getElementById('core-start-overlay');
        if (!this.overlay) return;
        var self = this;
        document.getElementById('core-start-close').addEventListener('click', function() { self.close(); });
        var help = document.getElementById('sw-help-btn');
        if (help) help.addEventListener('click', function() { self.openHelp(); });
        document.addEventListener('keydown', function(e) {
            if (e.key !== 'Escape' || !self.isShown() || TemplatePreview.isOpen()) return;
            self.close();
        });
    },

    isShown: function() {
        return !!(this.overlay && this.overlay.classList.contains('show'));
    },

    beginRun: function() {
        if (this.mirrorTimer) {
            clearInterval(this.mirrorTimer);
            this.mirrorTimer = null;
        }
        this.mode = 'run';
        // keep the start time: a later log dialog resumes the session with a live clock
        try { sessionStorage.setItem('ocCoreStartAt', String(Date.now())); } catch (e) {}
        if (typeof window.ocStatusMarkCoreStart === 'function') window.ocStatusMarkCoreStart();
        var title = document.getElementById('core-start-title');
        if (title) title.textContent = '<%:Program starting...%>';
        this.showOverlay();
    },

    run: function(name, onClosed) {
        ConfigUploader.hide();
        SubPanel.startSwitch(name, onClosed);
    },

    // the prompt dialog lives in the status bundle, the guide page is the fallback
    openHelp: function() {
        if (typeof UsageHelpManager !== 'undefined' && UsageHelpManager.show) {
            UsageHelpManager.show();
            return;
        }
        winOpen('https://github.com/vernesong/OpenClash/blob/dev/.github/skills/openclash-user-guide/SKILL.md');
    },

    view: function() {
        if (this.mode === 'run') return;
        if (this.mode === 'view' && this.isShown()) return;
        this.mode = 'view';
        this.shownLines = 0;
        this.lastMirrored = null;
        this.viewRestartSeen = false;
        this.viewDone = false;
        this.downPolls = 0;
        this.sessionStart = 0;
        try {
            var started = parseInt(sessionStorage.getItem('ocCoreStartAt') || '0', 10);
            if (started && Date.now() - started < 600000) this.sessionStart = started;
            else if (started) sessionStorage.removeItem('ocCoreStartAt');
        } catch (e) {}
        this.showOverlay();
        var self = this;
        var title = document.getElementById('core-start-title');
        if (title) title.textContent = '<%:Running Log%>';
        SubPanel.resetSwitchStage(true);
        SubPanel.stopTimer();
        this.updateViewElapsed();
        if (this.sessionStart) {
            this.viewTimer = setInterval(function() { self.updateViewElapsed(); }, 1000);
        }
        var status = SubPanel.el('sw-status');
        if (status) status.textContent = '';
        SubPanel.ensureLogView('sw-log-host', function() {
            if (self.mode !== 'view') return;
            SubPanel.clearLog('sw-log-host');
            self.syncLog();
        });
        this.viewPoll(0);
        this.mirrorTimer = setInterval(function() { self.syncLog(); }, 1500);
    },

    updateViewElapsed: function() {
        var elapsed = SubPanel.el('sw-elapsed');
        if (!elapsed) return;
        var s = this.sessionStart ? Math.max(0, Math.round((Date.now() - this.sessionStart) / 1000)) : (this.lastElapsed || 0);
        var m = Math.floor(s / 60);
        elapsed.textContent = (m < 10 ? '0' + m : m) + ':' + ((s % 60) < 10 ? '0' + (s % 60) : (s % 60));
    },

    // restarts can start elsewhere, so keep polling: the dialog opens mid-restart showing live progress
    viewPoll: function(attempt) {
        var self = this;
        if (this.mode !== 'view' || !this.isShown()) return;
        if (attempt > 80) return;
        var xhr = new XMLHttpRequest();
        this.viewPollXhr = xhr;
        var retry = function() {
            if (self.viewPollXhr !== xhr) return;
            self.viewPollXhr = null;
            self.viewPollTimer = setTimeout(function() { self.viewPoll(attempt + 1); }, 1500);
        };
        xhr.timeout = 6000;
        xhr.onerror = retry;
        xhr.ontimeout = retry;
        xhr.onload = function() {
            if (self.viewPollXhr !== xhr) return;
            self.viewPollXhr = null;
            if (self.mode !== 'view' || !self.isShown()) return;
            var data = null;
            try { data = JSON.parse(xhr.responseText); } catch (e) {}
            self.applyViewSample(xhr, data, attempt);
            self.viewPollTimer = setTimeout(function() { self.viewPoll(attempt + 1); }, 1500);
        };
        xhr.open('GET', '<%=url("admin", "services", "openclash", "runtime_stats")%>', true);
        xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
        xhr.send();
    },

    applyViewSample: function(xhr, data, attempt) {
        var status = SubPanel.el('sw-status');
        var online = !!(xhr && xhr.status == 200 && data && data.status === 'success' && data.online);
        if (!data || data.service_running === false || !online) this.viewRestartSeen = true;
        // the old core may still answer a session restart: trust up only after a down
        // sample, the script exit, or a few seconds
        var scriptDone = !!(window.ocStatusScriptDone && window.ocStatusScriptDone());
        var fresh = !this.sessionStart || this.viewRestartSeen || scriptDone || (Date.now() - this.sessionStart > 10000) || attempt >= 10;
        if (data && data.service_running === false) {
            if (this.sessionStart && !scriptDone) {
                // the script rebuilds the config with the core down: this is the starting phase
                SubPanel.setSwitchStage(1);
            } else {
                if (SubPanel.swStage !== -1 || SubPanel.failed) SubPanel.resetSwitchStage(true);
                if (status) status.textContent = '<%:Kernel service is not running%>';
            }
            this.viewDone = false;
            this.downPolls = (this.downPolls || 0) + 1;
            if (this.sessionStart && scriptDone && this.downPolls >= 10) {
                // the script is gone and the service stays down: end the session so the clock freezes
                CoreStartFlow.lastElapsed = Math.max(0, Math.round((Date.now() - this.sessionStart) / 1000));
                this.dropSession();
                if (this.viewTimer) {
                    clearInterval(this.viewTimer);
                    this.viewTimer = null;
                }
                this.updateViewElapsed();
            }
            return;
        }
        this.downPolls = 0;
        if (!online) {
            SubPanel.setSwitchStage(2);
            this.viewDone = false;
            return;
        }
        if (!fresh) {
            // the old core still answers: only the starting phase is certain
            SubPanel.setSwitchStage(1);
            this.viewDone = false;
            return;
        }
        if (!scriptDone) {
            // the script still runs: done only comes with its exit, same rule as the run flow
            SubPanel.setSwitchStage(3);
            this.viewDone = false;
            return;
        }
        SubPanel.setSwitchStage(4);
        if (status && !this.viewDone) {
            this.viewDone = true;
            SubPanel.markStatusDone();
        }
        if (this.sessionStart) {
            // the session carried over from another page ends here: freeze the elapsed time
            CoreStartFlow.lastElapsed = Math.max(0, Math.round((Date.now() - this.sessionStart) / 1000));
            this.dropSession();
            if (this.viewTimer) {
                clearInterval(this.viewTimer);
                this.viewTimer = null;
            }
            this.updateViewElapsed();
        }
    },

    dropSession: function() {
        this.sessionStart = 0;
        try { sessionStorage.removeItem('ocCoreStartAt'); } catch (e) {}
    },

    syncLog: function() {
        if (this.mode !== 'view') return;
        var lines = (window.ocStatusLogLines && window.ocStatusLogLines()) || [];
        // realign when another operation emptied the status log array: a stale cursor
        // would freeze the mirror forever
        if (this.shownLines > lines.length || (this.shownLines > 0 && lines[this.shownLines - 1] !== this.lastMirrored)) {
            this.shownLines = 0;
            this.lastMirrored = null;
            SubPanel.clearLog('sw-log-host');
        }
        if (lines.length <= this.shownLines) return;
        var slice = lines.slice(this.shownLines);
        this.shownLines = lines.length;
        this.lastMirrored = lines[lines.length - 1];
        SubPanel.appendLog('sw-log-host', slice.join('\n'));
    },

    close: function() {
        if (this.mirrorTimer) {
            clearInterval(this.mirrorTimer);
            this.mirrorTimer = null;
        }
        if (this.viewTimer) {
            clearInterval(this.viewTimer);
            this.viewTimer = null;
        }
        if (this.viewPollTimer) {
            clearTimeout(this.viewPollTimer);
            this.viewPollTimer = null;
        }
        if (this.viewPollXhr) {
            try { this.viewPollXhr.abort(); } catch (e) {}
            this.viewPollXhr = null;
        }
        if (this.mode === 'view') {
            this.mode = '';
            this.hideOverlay();
            return;
        }
        this.mode = '';
        SubPanel.closeSwitch();
    },

    showOverlay: function() {
        if (!this.overlay) this.overlay = document.getElementById('core-start-overlay');
        if (!this.overlay) return;
        this.overlay.classList.add('show');
    },

    hideOverlay: function() {
        if (this.overlay) this.overlay.classList.remove('show');
    }
};

// Call init directly when the script is lazy-loaded after DOMContentLoaded.
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function() {
        ConfigUploader.init();
        TemplatePreview.init();
        CoreStartFlow.init();
    });
} else {
    ConfigUploader.init();
    TemplatePreview.init();
    CoreStartFlow.init();
}
