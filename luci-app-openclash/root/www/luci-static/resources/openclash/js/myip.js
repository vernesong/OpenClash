// Extracted from luasrc/view/openclash/myip.htm - edit this file, not the template.
// <%:Message%> markers and <%=...%> islands are compiled server-side by the "openclash/translate_js" controller action.

    var overflowTitleFrame = null;
    var overflowTitleElements = null;
    var cardHeightFrame = null;
    function syncCardHeights() {
        if (cardHeightFrame) return;
        var schedule = window.requestAnimationFrame || function(callback) { return setTimeout(callback, 0); };
        cardHeightFrame = schedule(function() {
            cardHeightFrame = null;
            var items = document.querySelectorAll('.myip-card-item');
            if (!items.length) return;
            items.forEach(function(item) {
                item.style.transition = 'none';
                item.style.minHeight = '';
            });
            var max = 0;
            items.forEach(function(item) {
                var h = item.getBoundingClientRect().height;
                if (h > max) max = h;
            });
            max = max ? Math.ceil(max) + 'px' : '';
            items.forEach(function(item) {
                item.style.minHeight = max;
                item.style.transition = '';
            });
        });
    }
    function addTitleOnOverflow() {
        if (overflowTitleFrame) return;
        var schedule = window.requestAnimationFrame || function(callback) { return setTimeout(callback, 0); };
        overflowTitleFrame = schedule(function() {
            overflowTitleFrame = null;
            if (!overflowTitleElements) {
                overflowTitleElements = document.querySelectorAll('.myip-ip-addr, .myip-ip-geo');
            }
            var isPrivate = localStorage.getItem('privacy_my_ip') === 'true';
            overflowTitleElements.forEach(function (span) {
                if (!isPrivate && span.scrollWidth > span.clientWidth) {
                    span.setAttribute('title', span.textContent);
                } else {
                    span.removeAttribute('title');
                }
            });
            syncCardHeights();
        });
    }
    function ip_skk()
    {
        url2='https://ip.skk.moe';
        window.open(url2);
    }
    const $$ = document;
    var ip_ipip_ip;
    var ip_ipsb_ip;
    var ip_pcol_ip;
    var ip_ipify_ip;

    var INTERVAL = {
        HTTP_CHECK_MIN: 20 * 1000,   // accessibility check
        HTTP_CHECK_MAX: 50 * 1000,
        UNLOCK_CHECK_MIN: 30 * 1000,
        UNLOCK_CHECK_MAX: 60 * 1000,
        IP_CHECK_MIN: 50 * 1000,     // IP info
        IP_CHECK_MAX: 80 * 1000
    };

    function startHttpInterval() {
        if (unlock_view) return;
        if (refresh_http) clearInterval(refresh_http);
        refresh_http = setInterval(HTTP.runcheck, ocRandomInterval(INTERVAL.HTTP_CHECK_MIN, INTERVAL.HTTP_CHECK_MAX));
    }

    var unlock_timers = {};

    function stopUnlockTimers() {
        Object.keys(unlock_timers).forEach(function(key) {
            clearTimeout(unlock_timers[key]);
            delete unlock_timers[key];
        });
    }

    // Periodic checks run on staggered per-service timers so they never fire as one batch.
    function startUnlockTimers() {
        stopUnlockTimers();
        if (!unlock_view || unlock_gear) return;
        var keys = UNLOCK_SERVICES.map(function(s) { return s.key; }).filter(unlock_is_selected);
        keys.forEach(function(key, i) {
            var tick = function() {
                delete unlock_timers[key];
                if (!unlock_view || unlock_gear) return;
                if (!Object.keys(unlock_find_keys).length && !unlock_xhrs[key]) {
                    run_unlock_check([key], false, true);
                }
                unlock_timers[key] = setTimeout(tick, ocRandomInterval(INTERVAL.UNLOCK_CHECK_MIN, INTERVAL.UNLOCK_CHECK_MAX));
            };
            var first = Math.round((i + 1) * ocRandomInterval(INTERVAL.UNLOCK_CHECK_MIN, INTERVAL.UNLOCK_CHECK_MAX) / keys.length);
            unlock_timers[key] = setTimeout(tick, first);
        });
    }

    function startIpInterval() {
        if (refresh_ip) clearInterval(refresh_ip);
        if (localStorage.getItem('privacy_my_ip') === 'true') return;
        refresh_ip = setInterval(
            use_router_mode ? get_router_ip_info : myip_Load,
            ocRandomInterval(INTERVAL.IP_CHECK_MIN, INTERVAL.IP_CHECK_MAX)
        );
    }

    function clearAllIntervals() {
        if (refresh_http) { clearInterval(refresh_http); refresh_http = null; }
        stopUnlockTimers();
        if (refresh_ip) { clearInterval(refresh_ip); refresh_ip = null; }
    }

    function abortAllRequests() {
        if (ipCheckXHR) { try { ipCheckXHR.abort(); } catch(e) {} ipCheckXHR = null; }
        if (httpCheckXHR) { try { httpCheckXHR.abort(); } catch(e) {} httpCheckXHR = null; }
        unlock_abort_checks();
    }

    var refresh_http;
    var refresh_ip;
    var ipCheckXHR = null;
    var httpCheckXHR = null;
    function querying_html() {
        return ocSpinnerRow('<%:Querying...%>');
    }
    $$.getElementById('ip-ipip').innerHTML = querying_html();
    $$.getElementById('ip-ipify').innerHTML = querying_html();
    $$.getElementById('ip-pcol').innerHTML = querying_html();
    $$.getElementById('ip-ipsb').innerHTML = querying_html();

    var SpeedHistory = {
        max: 10,
        data: { baidu:[], 163:[], github:[], youtube:[] },
        prevPath: { baidu: null, 163: null, github: null, youtube: null },
        push: function(svc, ms) {
            this.data[svc].push(ms);
            if (this.data[svc].length > this.max) this.data[svc].shift();
        },
        buildPath: function(pts) {
            var w = 90, h = 20, pad = 4;
            var max = Math.max.apply(null, pts), min = Math.min.apply(null, pts);
            var range = max - min || 1;
            var stepX = (w - pad * 2) / (this.max - 1);
            var endX, endY;
            var points = [];
            var d = pts.map(function(v, i) {
                var x = (pad + i * stepX).toFixed(1);
                var y = (h - pad - (v - min) / range * (h - pad * 2)).toFixed(1);
                points.push({ x: x, y: y, v: v });
                if (i === pts.length - 1) { endX = x; endY = y; }
                return (i === 0 ? 'M' : 'L') + x + ',' + y;
            }).join(' ');
            return { d: d, w: w, h: h, endX: endX, endY: endY, points: points, stepX: stepX };
        },
        renderSparkline: function(svc, el, lc) {
            var pts = this.data[svc];
            var stroke = latencyColor(lc);
            if (!el) return;
            if (pts.length < 2) {
                var w = 90, h = 20;
                var d = 'M28.0,10.0 L36.0,10.0 L40.0,5.0 L43.0,15.0 L47.0,10.0 L61.0,10.0';
                el.innerHTML =
                    '<svg viewBox="0 0 ' + w + ' ' + h + '" class="myip-sparkline-svg">' +
                    '<path d="' + d + '" class="spark-ghost" style="stroke:' + stroke + '"/>' +
                    '</svg>';
                var ghostEl = el.querySelector('.spark-ghost');
                if (ghostEl) {
                    var len = ghostEl.getTotalLength();
                    if (len > 0) {
                        ghostEl.style.strokeDasharray = len;
                        ghostEl.animate([
                            { strokeDashoffset: len, offset: 0 },
                            { strokeDashoffset: 0, offset: 0.55 },
                            { strokeDashoffset: 0, offset: 1 }
                        ], {
                            duration: 5500,
                            easing: 'ease-out',
                            iterations: Infinity
                        });
                    }
                }
                return;
            }

            var g = this.buildPath(pts);
            var points = g.points || [];

            var ghostHTML = '';
            if (this.prevPath[svc] && pts.length >= 3) {
                ghostHTML = '<path d="' + this.prevPath[svc] + '" class="spark-ghost" style="stroke:' + stroke + '"/>';
            }
            this.prevPath[svc] = g.d;

            el.innerHTML =
                '<svg viewBox="0 0 ' + g.w + ' ' + g.h + '" class="myip-sparkline-svg">' +
                ghostHTML +
                '<path d="' + g.d + '" class="spark-line" style="stroke:' + stroke + '"/>' +
                '<line x1="' + g.endX + '" y1="0" x2="' + g.endX + '" y2="' + g.h + '" class="spark-crosshair" stroke="' + stroke + '" stroke-width="1" vector-effect="non-scaling-stroke" style="display:none"/>' +
                '<circle cx="' + g.endX + '" cy="' + g.endY + '" r="3" class="spark-hover-dot" style="fill:' + stroke + ';display:none"/>' +
                '<circle cx="' + g.endX + '" cy="' + g.endY + '" r="3" class="spark-dot-glow" style="fill:' + stroke + '"/>' +
                '<circle cx="' + g.endX + '" cy="' + g.endY + '" r="2.5" class="spark-dot" style="fill:' + stroke + '"/>' +
                '</svg>';

            var lineEl = el.querySelector('.spark-line');
            if (lineEl) {
                var len = lineEl.getTotalLength();
                if (len > 0) {
                    lineEl.style.strokeDasharray = len;
                    lineEl.style.strokeDashoffset = len;
                    lineEl.getBoundingClientRect();
                    lineEl.style.transition = 'stroke-dashoffset 3s ease-out';
                    requestAnimationFrame(function() {
                        lineEl.style.strokeDashoffset = '0';
                    });
                }
            }

            var svgEl = el.querySelector('.myip-sparkline-svg');
            var crosshair = el.querySelector('.spark-crosshair');
            if (svgEl && crosshair && points.length >= 2) {
                var hoverDot = el.querySelector('.spark-hover-dot');
                var tip = document.createElement('div');
                tip.className = 'spark-tip';
                tip.style.display = 'none';
                el.appendChild(tip);

                function showAt(clientX, clientY) {
                    // A naive (clientX - left) / width * w
                    // mapping ignores those margins and drifts from the real
                    // endpoint positions. getScreenCTM() returns the exact
                    // user-space transform (scale + letterbox offset)
                    var svgRect = svgEl.getBoundingClientRect();
                    var ctm = null;
                    try { ctm = svgEl.getScreenCTM(); } catch(err) {}
                    var x = -1;
                    if (ctm) {
                        var pt = svgEl.createSVGPoint();
                        pt.x = clientX;
                        pt.y = clientY;
                        x = pt.matrixTransform(ctm.inverse()).x;
                    }
                    if (x < 0) return;

                    var nearest = points[0];
                    var best = Math.abs(parseFloat(points[0].x) - x);
                    for (var k = 1; k < points.length; k++) {
                        var d = Math.abs(parseFloat(points[k].x) - x);
                        if (d < best) { best = d; nearest = points[k]; }
                    }

                    var snapRadius = g.stepX / 2;
                    if (best > snapRadius) {
                        hideAll();
                        return;
                    }

                    crosshair.setAttribute('x1', nearest.x);
                    crosshair.setAttribute('x2', nearest.x);
                    crosshair.setAttribute('y1', 0);
                    crosshair.setAttribute('y2', g.h);
                    crosshair.style.display = 'block';

                    hoverDot.setAttribute('cx', nearest.x);
                    hoverDot.setAttribute('cy', nearest.y);
                    hoverDot.style.display = 'block';

                    var elRect = el.getBoundingClientRect();
                    var ep = svgEl.createSVGPoint();
                    ep.x = parseFloat(nearest.x);
                    ep.y = parseFloat(nearest.y);
                    var epScreen = ep.matrixTransform(ctm);
                    var px = epScreen.x - elRect.left;
                    tip.textContent = nearest.v + ' ms';
                    tip.style.color = latencyColor(getLatencyClass(nearest.v));
                    tip.style.display = 'block';
                    var tw = tip.offsetWidth;
                    var left = px - tw / 2;
                    left = Math.max(0, Math.min(left, el.clientWidth - tw));
                    tip.style.left = left + 'px';
                    tip.style.top = '-17px';
                }

                function hideAll() {
                    crosshair.style.display = 'none';
                    hoverDot.style.display = 'none';
                    tip.style.display = 'none';
                }

                el.onmousemove = function(e) { showAt(e.clientX, e.clientY); };
                el.onmouseleave = hideAll;

                el.ontouchstart = function(e) {
                    e.preventDefault();
                    var t = e.touches && e.touches[0];
                    if (t) showAt(t.clientX, t.clientY);
                };
                el.ontouchmove = function(e) {
                    e.preventDefault();
                    var t = e.touches && e.touches[0];
                    if (t) showAt(t.clientX, t.clientY);
                };
                el.ontouchend = hideAll;
                el.ontouchcancel = hideAll;
            }
        },
        reset: function(svc) {
            this.data[svc] = [];
            this.prevPath[svc] = null;
        }
    };

    function getLatencyClass(ms) {
        if (ms <= 500) return 'myip-latency-fast';
        if (ms <= 1000) return 'myip-latency-mid';
        return 'myip-latency-slow';
    }

    function latencyColor(lc) {
        if (lc === 'myip-latency-mid') return 'var(--warning-color)';
        if (lc === 'myip-latency-slow') return 'var(--error-color)';
        return 'var(--success-color)';
    }

    function updateCheckCard(svc, status, latency) {
        if (unlock_view) return;
        var dot = document.getElementById('dot-' + svc);
        var lat = document.getElementById('latency-' + svc);
        var spk = document.getElementById('spark-' + svc);
        if (status === 'ok') {
            var lc = getLatencyClass(latency);
            dot.className = 'myip-status-dot ' + lc;
            dot.title = '<%:Access Normal%>';
            lat.textContent = latency;
            lat.className = 'myip-latency ' + lc;
            SpeedHistory.push(svc, latency);
            SpeedHistory.renderSparkline(svc, spk, lc);
        } else if (status === 'timeout') {
            dot.className = 'myip-status-dot err';
            dot.title = '<%:Access Timed Out%>';
            lat.textContent = '--';
            lat.className = 'myip-latency';
            spk.innerHTML = '<span class="myip-sparkline-error"><%:Access Timed Out%></span>';
        } else if (status === 'denied') {
            dot.className = 'myip-status-dot err';
            dot.title = '<%:Access Denied%>';
            lat.textContent = '--';
            lat.className = 'myip-latency';
            spk.innerHTML = '<span class="myip-sparkline-error"><%:Access Denied%></span>';
        } else {
            dot.className = 'myip-status-dot testing';
            dot.title = '<%:Testing...%>';
            lat.innerHTML = '<span class="loading-spinner"></span>';
            lat.className = 'myip-latency';
        }
    }

    let random = parseInt(Math.random() * 100000000);
    let IP = {
        get: (url, type) =>
            fetch(url, { method: 'GET' }).then((resp) => {
                if (type === 'text')
                    return Promise.all([resp.ok, resp.status, resp.text(), resp.headers]);
                else {
                    return Promise.all([resp.ok, resp.status, resp.json(), resp.headers]);
                }
            }).then(([ok, status, data, headers]) => {
                if (ok) {
                    let json = {
                        ok,
                        status,
                        data,
                        headers
                    }
                    return json;
                } else {
                    throw new Error(JSON.stringify(json.error));
                }
            }).catch(error => {
                throw error;
            }),
        parseIPIpip: (ip, elID) => {
            const v4 = '(?:25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]\\d|\\d)(?:\\.(?:25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]\\d|\\d)){3}';
            const v4Exact = new RegExp(`^${v4}$`);
            const anonymizedIp = (() => {
                if (v4Exact.test(ip)) {
                    const [a, b, c] = ip.split('.');
                    return `${a}.${b}.${c}.0`;
                }
                return ip;
            })();

            fetch(`https://api.ip.sb/geoip/${anonymizedIp}`, {
            referrerPolicy: 'no-referrer-when-downgrade',
            }).then(r => r.json())
            .then(resp => {
                if ( resp.country && resp.country != '' && resp.isp && resp.isp != '' ) {
                    $$.getElementById(elID).innerHTML = resp.country + ' ' + resp.isp;
                }
                else {
                    fetch(`https://qqwry.api.skk.moe/${anonymizedIp}`, {
                    referrerPolicy: 'no-referrer-when-downgrade',
                    }).then(r => r.json())
                    .then(resp => {
                        if ( resp.geo.indexOf('skk.moe') == -1 ) {
                            $$.getElementById(elID).innerHTML = resp.geo;
                        }
                        else {
                            $$.getElementById(elID).innerHTML = 'Unknown';
                        }
                    })
                }
            })
        },
        getPcolIP: () => {
            document.querySelectorAll('script[data-pcol]').forEach(function(el) {
                el.parentNode.removeChild(el);
            });
            window.IPCallBack = null;

            var script = document.createElement('script');
            script.setAttribute('data-pcol', '');
            script.src = 'https://whois.pconline.com.cn/ipJson.jsp?z=' + random;
            window.IPCallBack = function(data) {
                if (data && data.ip) {
                    $$.getElementById('ip-pcol').innerHTML = localStorage.getItem('privacy_my_ip') == 'true' ? '***.***.***.***' : data.ip;
                    var geo = [];
                    if (data.pro) geo.push(data.pro);
                    if (data.city) geo.push(data.city);
                    if (data.addr) {
                        var ispMatch = data.addr.match(/\s(\S+)$/);
                        if (ispMatch) geo.push(ispMatch[1]);
                    }
                    $$.getElementById('ip-pcol-geo').innerHTML = geo.join(' ');
                }
                addTitleOnOverflow();
            };
            document.head.appendChild(script);
        },
        getIpipIP: () => {
            IP.get(`https://myip.ipip.net?z=${random}`, 'text')
            .then(resp => {
                const ipMatch = resp.data.match(/当前 IP：([0-9A-Fa-f:.]+)/);
                const geoMatch = resp.data.match(/来自于：(.+)/);

                if (ipMatch && geoMatch) {
                    $$.getElementById('ip-ipip').innerHTML = localStorage.getItem('privacy_my_ip') == 'true' ? '***.***.***.***' : ipMatch[1];
                    $$.getElementById('ip-ipip-geo').innerHTML = geoMatch[1].trim();
                    addTitleOnOverflow();
                }
            })
        },
        getIpifyIP: () => {
            IP.get(`https://api.ipify.org/?format=json&z=${random}`, 'json')
            .then(resp => {
                $$.getElementById('ip-ipify').innerHTML = localStorage.getItem('privacy_my_ip') == 'true' ? '***.***.***.***' : resp.data.ip;
                return resp.data.ip;
            })
            .then(ip => {
                IP.parseIPIpip(ip, 'ip-ipify-geo');
                addTitleOnOverflow();
            })
        },
        getIpsbIP: () => {
            fetch(`https://api.ip.sb/geoip?z=${random}`)
                .then(response => response.json())
                .then(data => {
                    $$.getElementById('ip-ipsb').innerHTML = localStorage.getItem('privacy_my_ip') == 'true' ? '***.***.***.***' : data.ip;
                    $$.getElementById('ip-ipsb-geo').innerHTML = `${data.country} ${data.isp}`;
                    addTitleOnOverflow();
                })
        }
    };

    let HTTP = {
        checker_browser: function(svcName, domain, timeoutMs) {
            var img = new Image;
            var img_start_time = (+new Date());
            var t = timeoutMs || 5000;
            var timeout = setTimeout(function() {
                img.onerror = img.onload = null;
                updateCheckCard(svcName, 'timeout');
            }, t);

            img.onerror = function() {
                clearTimeout(timeout);
                updateCheckCard(svcName, 'denied');
            };

            img.onload = function() {
                clearTimeout(timeout);
                var img_load_time = (new Date()) - img_start_time;
                updateCheckCard(svcName, 'ok', img_load_time);
            };

            img.src = 'https://' + domain + '/favicon.ico?' + (+(new Date));
        },
        runcheck: function() {
            if (unlock_view) return;
            if (!use_router_mode) {
                HTTP.checker_browser('baidu', 'www.baidu.com');
                HTTP.checker_browser('163', 's1.music.126.net/style');
                HTTP.checker_browser('github', 'github.com');
                HTTP.checker_browser('youtube', 'www.youtube.com');
                return;
            }

            var svcDomains = [
                { svc: 'baidu', domain: 'www.baidu.com' },
                { svc: '163', domain: 's1.music.126.net/style' },
                { svc: 'github', domain: 'github.com' },
                { svc: 'youtube', domain: 'www.youtube.com' }
            ];
            var domainParam = svcDomains.map(function(d) { return encodeURIComponent(d.domain); }).join(',');
            var domainToSvc = {};
            svcDomains.forEach(function(d) { domainToSvc[d.domain] = d.svc; });

            if (httpCheckXHR) { try { httpCheckXHR.abort(); } catch(e) {} httpCheckXHR = null; }
            var xhr = new XMLHttpRequest();
            xhr.open('GET', '/cgi-bin/luci/admin/services/openclash/website_check?domains=' + domainParam, true);
            xhr.timeout = 0;
            var lastIndex = 0;
            var pendingBuf = '';

            xhr.onprogress = function() {
                var newText = xhr.responseText.substring(lastIndex);
                lastIndex = xhr.responseText.length;
                pendingBuf += newText;
                var lines = pendingBuf.split('\n');
                pendingBuf = lines.pop();
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (!line) continue;
                    try {
                        var response = JSON.parse(line);
                        var svc = domainToSvc[response.domain];
                        if (!svc) continue;
                        if (response.success) {
                            updateCheckCard(svc, 'ok', response.response_time);
                        } else if (response.error === 'timeout') {
                            updateCheckCard(svc, 'timeout');
                        } else {
                            updateCheckCard(svc, 'denied');
                        }
                    } catch(e) {}
                }
            };

            xhr.onerror = function() {
                svcDomains.forEach(function(d) { updateCheckCard(d.svc, 'denied'); });
            };

            xhr.onloadend = function() { if (httpCheckXHR === xhr) httpCheckXHR = null; };
            xhr.send();
            httpCheckXHR = xhr;
        }
    };

    var UNLOCK_SERVICES = [
        { key: 'prime_video', name: 'Amazon Prime Video', short: 'Prime Video', icon: 'oc-icon-brand-primevideo', iconClass: 'ic-primevideo' },
        { key: 'bahamut', name: 'Bahamut Anime', short: 'Bahamut', icon: 'oc-icon-brand-bahamut', iconClass: 'ic-bahamut' },
        { key: 'bilibili', name: 'Bilibili', icon: 'oc-icon-brand-bilibili', iconClass: 'ic-bilibili' },
        { key: 'claude', name: 'Claude', icon: 'oc-icon-brand-claude', iconClass: 'ic-claude' },
        { key: 'dazn', name: 'DAZN', icon: 'oc-icon-brand-dazn', iconClass: 'ic-dazn' },
        { key: 'discovery', name: 'Discovery Plus', short: 'Discovery+', icon: 'oc-icon-brand-warnerbros', iconClass: 'ic-discovery' },
        { key: 'disney', name: 'Disney Plus', short: 'Disney+', icon: 'oc-icon-brand-disney', iconClass: 'ic-disney' },
        { key: 'gemini', name: 'Gemini', icon: 'oc-icon-brand-gemini', iconClass: 'ic-gemini' },
        { key: 'google', name: 'Google', icon: 'oc-icon-brand-google', iconClass: 'ic-google' },
        { key: 'hbo_max', name: 'HBO Max', icon: 'oc-icon-brand-hbomax', iconClass: 'ic-hbomax' },
        { key: 'netflix', name: 'Netflix', icon: 'oc-icon-brand-netflix', iconClass: 'ic-netflix' },
        { key: 'openai', name: 'OpenAI', icon: 'oc-icon-brand-openai', iconClass: 'ic-openai' },
        { key: 'paramount', name: 'Paramount Plus', short: 'Paramount+', icon: 'oc-icon-brand-paramount', iconClass: 'ic-paramount' },
        { key: 'spotify', name: 'Spotify', icon: 'oc-icon-brand-spotify', iconClass: 'ic-spotify' },
        { key: 'steam', name: 'Steam', icon: 'oc-icon-brand-steam', iconClass: 'ic-steam' },
        { key: 'tvb', name: 'TVB Anywhere+', short: 'TVB', icon: 'oc-icon-brand-tvb', iconClass: 'ic-tvb' },
        { key: 'ytb', name: 'YouTube Premium', short: 'YouTube', icon: 'oc-icon-brand-youtube', iconClass: 'ic-youtube' }
    ];
    var ACCESS_SLOTS = ['baidu', '163', 'github', 'youtube'];
    var unlock_view = false;
    var unlock_gear = false;
    var unlock_xhrs = {};
    var unlock_pending = {};
    var unlock_dom = null;
    var unlock_results = {};
    var unlock_find_keys = {};
    var unlock_auto_allowed = true;
    var unlock_auto_reason = '';
    var unlock_services = ['netflix', 'ytb', 'openai', 'claude'];

    try {
        var unlock_cache = JSON.parse(localStorage.getItem('myip_unlock_results') || 'null');
        if (unlock_cache && unlock_cache.data) unlock_results = unlock_cache.data;
    } catch (e) {
        unlock_results = {};
    }

    try {
        var unlock_services_saved = JSON.parse(localStorage.getItem('myip_unlock_services') || 'null');
        if (unlock_services_saved && unlock_services_saved.length) {
            var unlock_services_valid = [];
            unlock_services_saved.forEach(function(k) {
                if (unlock_services_valid.length < 4 && unlock_services_valid.indexOf(k) < 0 && unlock_service_index(k) >= 0) {
                    unlock_services_valid.push(k);
                }
            });
            if (unlock_services_valid.length) unlock_services = unlock_services_valid;
        }
    } catch (e) {}

    function unlock_load_services() {
        var xhr = new XMLHttpRequest();
        xhr.open('GET', '/cgi-bin/luci/admin/services/openclash/unlock_services', true);
        xhr.timeout = 10000;
        xhr.onloadend = function() {
            if (xhr.status !== 200) return;
            var data = null;
            try { data = JSON.parse(xhr.responseText); } catch (e) { return; }
            if (!data) return;
            if (typeof data.auto_ready !== 'undefined') {
                unlock_auto_allowed = !!data.auto_ready;
                unlock_auto_reason = unlock_auto_allowed ? '' : (data.enable ? 'self_proxy' : 'enable');
                unlock_set_find_buttons();
            }
            if (!data.services || !data.services.length) return;
            var valid = [];
            data.services.forEach(function(k) {
                if (valid.length < 4 && valid.indexOf(k) < 0 && unlock_service_index(k) >= 0) valid.push(k);
            });
            if (!valid.length) return;
            unlock_services = valid;
            unlock_save_services();
            if (unlock_view && !unlock_gear) {
                unlock_fill_slots();
                unlock_render_all();
            }
        };
        xhr.send();
    }
    unlock_load_services();

    function unlock_service_index(key) {
        for (var i = 0; i < UNLOCK_SERVICES.length; i++) {
            if (UNLOCK_SERVICES[i].key === key) return i;
        }
        return -1;
    }

    function unlock_init_dom() {
        if (unlock_dom) return unlock_dom;
        unlock_dom = {};
        ACCESS_SLOTS.forEach(function(slot) {
            var card = document.querySelector('.myip-check-item[data-svc="' + slot + '"]');
            var label = card.querySelector('.myip-card-label');
            unlock_dom[slot] = {
                card: card,
                label: label,
                labelHtml: label.innerHTML,
                node: card.querySelector('.myip-unlock-node-name'),
                region: card.querySelector('.myip-unlock-region'),
                ribbon: card.querySelector('.myip-unlock-ribbon'),
                spark: document.getElementById('spark-' + slot)
            };
            unlock_dom[slot].ribbon.addEventListener('click', function() {
                var key = card.getAttribute('data-svc');
                if (!key || unlock_pending[key]) return;
                run_unlock_check([key], true);
            });
        });
        unlock_watch_region_layout();
        return unlock_dom;
    }

    function unlock_save_results() {
        try {
            localStorage.setItem('myip_unlock_results', JSON.stringify({ ts: Date.now(), data: unlock_results }));
        } catch (e) {}
    }

    function unlock_save_services() {
        try {
            localStorage.setItem('myip_unlock_services', JSON.stringify(unlock_services));
        } catch (e) {}
    }

    function unlock_is_selected(key) {
        return unlock_services.indexOf(key) >= 0;
    }

    function unlock_service(key) {
        var i = unlock_service_index(key);
        return i >= 0 ? UNLOCK_SERVICES[i] : null;
    }

    function unlock_slots() {
        var keys = [];
        unlock_services.forEach(function(k) {
            if (keys.length < 4 && keys.indexOf(k) < 0 && unlock_service_index(k) >= 0) keys.push(k);
        });
        return keys;
    }

    function unlock_slot_index(key) {
        return unlock_slots().indexOf(key);
    }

    function unlock_fill_slots() {
        var dom = unlock_init_dom();
        var slots = unlock_slots();
        ACCESS_SLOTS.forEach(function(slot, i) {
            var d = dom[slot];
            var svc = slots[i] ? unlock_service(slots[i]) : null;
            if (!svc) {
                d.card.style.display = 'none';
                return;
            }
            d.card.style.display = '';
            d.card.setAttribute('data-svc', svc.key);
            d.label.innerHTML = '<svg class="myip-card-icon ' + svc.iconClass + '"><use href="#' + svc.icon + '"/></svg><span>' + (svc.short || svc.name) + '</span>';
            d.label.title = svc.name;
            d.spark.innerHTML = '';
            var btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'myip-find-btn';
            btn.setAttribute('data-key', svc.key);
            btn.textContent = '<%:Auto Select%>';
            btn.addEventListener('click', function() { unlock_find_node(svc.key); });
            d.spark.appendChild(btn);
        });
        unlock_set_find_buttons();
        unlock_sync_ribbons();
    }

    function unlock_set_gear_icon(on) {
        var icon = document.getElementById('unlock-gear-icon');
        if (icon) icon.classList.toggle('oc-gear-on', !!on);
    }

    var unlock_gear_list = [];
    var unlock_gear_rows = {};

    function unlock_gear_input(key) {
        var row = unlock_gear_rows[key];
        return row ? row.querySelector('input') : null;
    }

    function unlock_gear_selected() {
        return unlock_gear_list.filter(function(k) {
            var input = unlock_gear_input(k);
            return !!(input && input.checked);
        });
    }

    function unlock_sync_gear(panel) {
        panel = panel || document.getElementById('myip-unlock-gear');
        if (!panel) return;
        var selected = unlock_gear_selected();
        var full = selected.length >= 4;
        unlock_gear_list.forEach(function(key) {
            var row = unlock_gear_rows[key];
            if (!row) return;
            var input = row.querySelector('input');
            var disabled = full && !input.checked;
            input.disabled = disabled;
            row.classList.toggle('selected', input.checked);
            row.classList.toggle('oc-dim', disabled);
            var state = row.querySelector('.myip-gear-state');
            if (state) state.textContent = input.checked ? '✓' : '';
        });
        var hint = panel.querySelector('.myip-gear-hint');
        if (hint) {
            hint.textContent = full ? '<%:4 Services Selected%>' : '<%:Must Select 4 Services%>';
            hint.classList.toggle('oc-warn', !full);
        }
        var ok = panel.querySelector('.myip-gear-ok');
        if (ok) ok.disabled = selected.length !== 4;
    }

    var unlock_drag_key = null;
    var unlock_drag_target = null;
    var unlock_drag_y = null;
    var unlock_scroll_timer = null;
    var unlock_touch_start = null;
    var unlock_touch_timer = null;
    var unlock_touch_row = null;
    var unlock_touch_moved = false;
    var unlock_touch_dragging = false;

    function unlock_gear_reorder_dom() {
        var listEl = document.getElementById('myip-unlock-gear-list');
        if (!listEl) return;
        unlock_gear_list.forEach(function(k) {
            listEl.appendChild(unlock_gear_rows[k]);
        });
        unlock_sync_gear();
    }

    function unlock_gear_drag_clear() {
        unlock_gear_list.forEach(function(k) {
            var row = unlock_gear_rows[k];
            if (row) row.classList.remove('dragging', 'drag-before', 'drag-after');
        });
        unlock_drag_key = null;
        unlock_drag_target = null;
        unlock_drag_y = null;
        if (unlock_scroll_timer) {
            clearInterval(unlock_scroll_timer);
            unlock_scroll_timer = null;
        }
        if (unlock_touch_timer) {
            clearTimeout(unlock_touch_timer);
            unlock_touch_timer = null;
        }
        unlock_touch_start = null;
        unlock_touch_row = null;
        unlock_touch_moved = false;
        unlock_touch_dragging = false;
    }

    function unlock_gear_drop() {
        if (!unlock_drag_key || unlock_drag_target === null) {
            unlock_gear_drag_clear();
            return;
        }
        var from = unlock_gear_list.indexOf(unlock_drag_key);
        var target = unlock_drag_target;
        if (from >= 0 && target >= 0 && target <= unlock_gear_list.length) {
            if (from < target) target -= 1;
            if (target !== from) {
                unlock_gear_list.splice(from, 1);
                unlock_gear_list.splice(target, 0, unlock_drag_key);
                unlock_gear_reorder_dom();
            }
        }
        unlock_gear_drag_clear();
    }

    function unlock_gear_set_indicator(targetKey, after) {
        if (!targetKey || targetKey === unlock_drag_key) return;
        unlock_gear_list.forEach(function(k) {
            var r = unlock_gear_rows[k];
            if (r) r.classList.remove('drag-before', 'drag-after');
        });
        var row = unlock_gear_rows[targetKey];
        if (!row) return;
        row.classList.add(after ? 'drag-after' : 'drag-before');
        var to = unlock_gear_list.indexOf(targetKey);
        unlock_drag_target = after ? to + 1 : to;
    }

    function unlock_gear_indicator_at(clientY) {
        var keys = unlock_gear_list.filter(function(k) { return !!unlock_gear_rows[k]; });
        for (var i = 0; i < keys.length; i++) {
            var rect = unlock_gear_rows[keys[i]].getBoundingClientRect();
            if (clientY < rect.top + rect.height / 2) {
                unlock_gear_set_indicator(keys[i], false);
                return;
            }
        }
        if (keys.length) unlock_gear_set_indicator(keys[keys.length - 1], true);
    }

    function unlock_gear_autoscroll(clientY) {
        var listEl = document.getElementById('myip-unlock-gear-list');
        if (!listEl) return;
        var rect = listEl.getBoundingClientRect();
        if (clientY - rect.top < 24 && listEl.scrollTop > 0) {
            listEl.scrollTop -= 10;
        } else if (rect.bottom - clientY < 24 && listEl.scrollTop + listEl.clientHeight < listEl.scrollHeight) {
            listEl.scrollTop += 10;
        }
    }

    // Timer driven so the list keeps scrolling while the pointer rests near an edge.
    function unlock_gear_scroll_tick() {
        var listEl = document.getElementById('myip-unlock-gear-list');
        if (!listEl || !unlock_drag_key || unlock_drag_y === null) return;
        var before = listEl.scrollTop;
        unlock_gear_autoscroll(unlock_drag_y);
        if (listEl.scrollTop !== before) unlock_gear_indicator_at(unlock_drag_y);
    }

    function unlock_gear_scroll_start() {
        if (unlock_scroll_timer) return;
        unlock_scroll_timer = setInterval(unlock_gear_scroll_tick, 50);
    }

    function unlock_gear_touch_begin(row, touch) {
        unlock_gear_drag_clear();
        var key = row.getAttribute('data-key');
        if (!key) return;
        unlock_touch_row = row;
        unlock_touch_start = { x: touch.clientX, y: touch.clientY };
        unlock_touch_timer = setTimeout(function() {
            if (unlock_touch_moved || unlock_touch_row !== row) return;
            unlock_touch_dragging = true;
            unlock_drag_key = key;
            unlock_drag_target = null;
            unlock_drag_y = unlock_touch_start.y;
            row.classList.add('dragging');
            unlock_gear_scroll_start();
            if (navigator.vibrate) navigator.vibrate(50);
        }, 500);
    }

    function unlock_gear_touch_end(drop) {
        if (!unlock_touch_start && !unlock_touch_dragging) return false;
        var dragging = unlock_touch_dragging;
        var moved = unlock_touch_moved;
        if (drop && dragging && unlock_drag_key) {
            unlock_gear_drop();
        } else {
            unlock_gear_drag_clear();
        }
        return moved || dragging;
    }

    function unlock_gear_mouse_begin(row, e) {
        unlock_gear_drag_clear();
        var key = row.getAttribute('data-key');
        if (!key) return;
        var startX = e.clientX;
        var startY = e.clientY;
        var moved = false;
        var onMove = function(me) {
            if (!moved) {
                if (Math.abs(me.clientX - startX) < 6 && Math.abs(me.clientY - startY) < 6) return;
                moved = true;
                unlock_drag_key = key;
                unlock_drag_target = null;
                row.classList.add('dragging');
                unlock_gear_scroll_start();
            }
            me.preventDefault();
            unlock_drag_y = me.clientY;
            unlock_gear_indicator_at(me.clientY);
        };
        var onUp = function() {
            document.removeEventListener('mousemove', onMove);
            document.removeEventListener('mouseup', onUp);
            if (moved && unlock_drag_key) {
                unlock_gear_drop();
            } else {
                unlock_gear_drag_clear();
            }
        };
        document.addEventListener('mousemove', onMove);
        document.addEventListener('mouseup', onUp);
    }

    function unlock_gear_confirm(panel) {
        var selected = unlock_gear_selected();
        if (selected.length !== 4) return;
        var ok = panel.querySelector('.myip-gear-ok');
        ok.disabled = true;
        var xhr = new XMLHttpRequest();
        xhr.open('POST', '/cgi-bin/luci/admin/services/openclash/unlock_services', true);
        xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
        xhr.timeout = 15000;
        xhr.onloadend = function() {
            var done = false;
            if (xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText);
                    done = !!(data && data.services && data.services.join(',') === selected.join(','));
                } catch (e) {}
            }
            ok.disabled = false;
            if (!done) {
                ocToast('<%:Save failed%>', 'error');
                return;
            }
            unlock_services = selected;
            unlock_save_services();
            ocToast('<%:Saved%>', 'success');
            unlock_apply_view(true);
            run_unlock_check(null, true);
        };
        xhr.send('services=' + encodeURIComponent(selected.join(',')));
    }

    function unlock_gear_dom() {
        var panel = document.getElementById('myip-unlock-gear');
        if (panel) return panel;
        panel = document.createElement('div');
        panel.id = 'myip-unlock-gear';
        panel.className = 'myip-gear-panel oc-hidden';
        panel.innerHTML = '<div class="myip-gear-list" id="myip-unlock-gear-list"></div>' +
            '<div class="myip-gear-footer"><p class="myip-gear-hint"></p><button type="button" class="myip-gear-ok"><%:OK%></button></div>';
        var listEl = panel.querySelector('.myip-gear-list');
        var touchPrimary = window.matchMedia && window.matchMedia('(hover: none)').matches;
        UNLOCK_SERVICES.forEach(function(svc) {
            var row = document.createElement('div');
            row.className = 'myip-gear-row';
            row.setAttribute('data-key', svc.key);
            row.innerHTML = '<label class="myip-gear-left"><input type="checkbox" data-key="' + svc.key + '">' +
                '<span class="myip-gear-state"></span>' +
                '<svg class="myip-card-icon ' + svc.iconClass + '"><use href="#' + svc.icon + '"/></svg>' +
                '<span class="myip-gear-name">' + svc.name + '</span></label>' +
                '<span class="myip-gear-grip"><svg viewBox="0 0 24 24" width="14" height="14" fill="currentColor"><circle cx="9" cy="6" r="1.5"/><circle cx="15" cy="6" r="1.5"/><circle cx="9" cy="12" r="1.5"/><circle cx="15" cy="12" r="1.5"/><circle cx="9" cy="18" r="1.5"/><circle cx="15" cy="18" r="1.5"/></svg></span>';
            row.addEventListener('mousedown', function(e) {
                if (e.button !== 0) return;
                if (touchPrimary && !(e.target.closest && e.target.closest('.myip-gear-grip'))) return;
                unlock_gear_mouse_begin(row, e);
            });
            unlock_gear_rows[svc.key] = row;
            listEl.appendChild(row);
        });
        panel.addEventListener('change', function(e) {
            if (!e.target || e.target.type !== 'checkbox') return;
            unlock_sync_gear(panel);
        });
        panel.addEventListener('touchstart', function(e) {
            if (e.touches.length !== 1) return;
            var row = e.target && e.target.closest ? e.target.closest('.myip-gear-row') : null;
            if (!row || (e.target.closest && e.target.closest('input'))) return;
            unlock_gear_touch_begin(row, e.touches[0]);
        });
        panel.addEventListener('touchmove', function(e) {
            if (e.touches.length !== 1) return;
            var touch = e.touches[0];
            if (unlock_touch_dragging) {
                e.preventDefault();
                unlock_drag_y = touch.clientY;
                unlock_gear_indicator_at(touch.clientY);
                return;
            }
            if (!unlock_touch_start || unlock_touch_moved) return;
            if (Math.abs(touch.clientX - unlock_touch_start.x) > 12 || Math.abs(touch.clientY - unlock_touch_start.y) > 12) {
                unlock_touch_moved = true;
                if (unlock_touch_timer) {
                    clearTimeout(unlock_touch_timer);
                    unlock_touch_timer = null;
                }
            }
        }, { passive: false });
        panel.addEventListener('touchend', function(e) {
            var changed = e.changedTouches && e.changedTouches[0];
            if (unlock_touch_dragging && unlock_drag_target === null && changed) {
                unlock_gear_indicator_at(changed.clientY);
            }
            if (unlock_gear_touch_end(true)) e.preventDefault();
        });
        panel.addEventListener('touchcancel', function() {
            unlock_gear_touch_end(false);
        });
        panel.addEventListener('contextmenu', function(e) {
            if (unlock_touch_start || unlock_touch_dragging) e.preventDefault();
        });
        panel.querySelector('.myip-gear-ok').addEventListener('click', function() { unlock_gear_confirm(panel); });
        document.querySelector('.myip-check-list').appendChild(panel);
        return panel;
    }

    var unlock_ribbon_icons = {
        check: 'M5 12.5l4.5 4.5L19 7',
        question: 'M12 13.5a1.5 1.5 0 0 1 1 -1.5a2.6 2.6 0 1 0 -3 -4M12 17l0 .01',
        cross: 'M6.5 6.5l11 11M17.5 6.5l-11 11',
        dash: 'M6.5 12h11',
        dots: 'M7 12h.01M12 12h.01M17 12h.01'
    };

    function unlock_set_ribbon(d, state, icon, title) {
        d.ribbon.className = 'myip-unlock-ribbon ' + state;
        var viewBox = icon === 'question' ? '4.7 4.4 15.2 15.2' : '0 0 24 24';
        d.ribbon.innerHTML = '<svg viewBox="' + viewBox + '"><path d="' + unlock_ribbon_icons[icon] + '"/></svg>';
        d.ribbon.title = title;
    }

    // In-flight checks show the ellipsis marker unless quiet (periodic), which keeps
    // the last marker; the busy flag lives in an attribute as className is rewritten.
    function unlock_render_ribbon(d, key) {
        var quiet = unlock_pending[key] === 'quiet';
        if (unlock_pending[key] && !quiet) {
            d.ribbon.setAttribute('data-busy', '');
            unlock_set_ribbon(d, 'rib-t', 'dots', '<%:Testing...%>');
            return;
        }
        d.ribbon.removeAttribute('data-busy');
        var r = unlock_results[key];
        if (!r) {
            unlock_set_ribbon(d, 'rib-n', 'dash', quiet ? '<%:Testing...%>' : '<%:Not Tested%>');
            return;
        }
        var st = Number(r.st) || 0;
        var text, state, icon;
        if (st === 2) {
            text = '<%:Unlocked%>';
            state = 'rib-g';
            icon = 'check';
        } else if (st === 1) {
            text = (key === 'netflix') ? '<%:Originals Only%>' : '<%:Not Unlocked%>';
            state = 'rib-p';
            icon = 'question';
        } else {
            text = '<%:Test failed%>';
            state = 'rib-r';
            icon = 'cross';
        }
        var regionName = (st !== 0 && r.region) ? String(r.region).toUpperCase() : '';
        unlock_set_ribbon(d, state, icon, quiet ? '<%:Testing...%>' : text + (regionName ? ' · ' + regionName : ''));
    }

    function unlock_sync_ribbons() {
        var dom = unlock_init_dom();
        ACCESS_SLOTS.forEach(function(slot) {
            var d = dom[slot];
            unlock_render_ribbon(d, d.card.getAttribute('data-svc'));
        });
    }

    function unlock_set_region(d, region) {
        d.region.textContent = region;
        d.region.classList.toggle('oc-hidden', !region);
        if (region) unlock_align_region(d);
    }

    function unlock_align_region(d) {
        if (!d || !d.region || d.region.classList.contains('oc-hidden')) return;
        var range = document.createRange();
        range.selectNodeContents(d.node);
        var rects = range.getClientRects();
        if (!rects.length) {
            d.region.style.left = '';
            return;
        }
        var top = rects[0].top;
        var right = rects[0].right;
        for (var i = 1; i < rects.length; i++) {
            if (Math.abs(rects[i].top - top) > 2) break;
            if (rects[i].right > right) right = rects[i].right;
        }
        var parentLeft = d.region.parentNode.getBoundingClientRect().left;
        var left = Math.round(right - parentLeft + 5);
        var card = d.region.closest('.myip-check-item');
        if (card) {
            var maxLeft = Math.floor(card.getBoundingClientRect().right - d.region.offsetWidth - 4 - parentLeft);
            if (left > maxLeft) left = maxLeft;
        }
        d.region.style.left = left + 'px';
    }

    function unlock_watch_region_layout() {
        if (!window.ResizeObserver) return;
        var observer = new ResizeObserver(function(entries) {
            if (!unlock_view) return;
            entries.forEach(function(entry) {
                ACCESS_SLOTS.forEach(function(slot) {
                    var d = unlock_dom[slot];
                    if (d && d.node === entry.target) unlock_align_region(d);
                });
            });
        });
        ACCESS_SLOTS.forEach(function(slot) {
            observer.observe(unlock_dom[slot].node);
        });
    }

    var unlock_align_frame = null;

    function unlock_schedule_align() {
        if (!unlock_view || !unlock_dom || unlock_align_frame) return;
        var schedule = window.requestAnimationFrame || function(callback) { return setTimeout(callback, 0); };
        unlock_align_frame = schedule(function() {
            unlock_align_frame = null;
            if (!unlock_view) return;
            ACCESS_SLOTS.forEach(function(slot) { unlock_align_region(unlock_dom[slot]); });
        });
    }

    var UNLOCK_REGION_CODES = {
        'HONG KONG': 'HK', 'SINGAPORE': 'SG', 'TAIWAN': 'TW', 'JAPAN': 'JP',
        'SOUTH KOREA': 'KR', 'KOREA': 'KR', 'UNITED STATES': 'US', 'UNITED KINGDOM': 'UK',
        'MALAYSIA': 'MY', 'THAILAND': 'TH', 'VIETNAM': 'VN', 'VIET NAM': 'VN',
        'PHILIPPINES': 'PH', 'INDONESIA': 'ID', 'INDIA': 'IN', 'AUSTRALIA': 'AU',
        'CANADA': 'CA', 'GERMANY': 'DE', 'FRANCE': 'FR', 'NETHERLANDS': 'NL',
        'SWITZERLAND': 'CH', 'SWEDEN': 'SE', 'SPAIN': 'ES', 'ITALY': 'IT',
        'BRAZIL': 'BR', 'MEXICO': 'MX', 'TURKEY': 'TR', 'RUSSIA': 'RU'
    };

    function unlock_render(key) {
        var i = unlock_slot_index(key);
        if (i < 0) return;
        var d = unlock_init_dom()[ACCESS_SLOTS[i]];
        var r = unlock_results[key];
        unlock_render_ribbon(d, key);
        if (!r) {
            d.node.textContent = '--';
            d.node.className = 'myip-unlock-node-name';
            unlock_set_region(d, '');
            return;
        }
        var st = Number(r.st) || 0;
        var cls;
        if (st === 2) {
            cls = 'myip-latency-fast';
        } else if (st === 1) {
            cls = 'myip-latency-mid';
        } else {
            cls = 'myip-latency-slow';
        }
        var regionName = (st !== 0 && r.region) ? String(r.region).toUpperCase() : '';
        var region = st === 0 ? 'N/A' : (UNLOCK_REGION_CODES[regionName] || regionName);
        d.node.textContent = r.node || '--';
        d.node.className = 'myip-unlock-node-name' + (r.node ? '' : ' ' + cls);
        unlock_set_region(d, region);
    }

    function unlock_render_all() {
        UNLOCK_SERVICES.forEach(function(svc) { unlock_render(svc.key); });
        syncCardHeights();
    }

    function unlock_set_pending(key, spinner, quiet) {
        var i = unlock_slot_index(key);
        if (i < 0) return;
        var d = unlock_init_dom()[ACCESS_SLOTS[i]];
        if (spinner) {
            d.node.innerHTML = '<span class="loading-spinner"></span><%:Testing...%>';
            d.node.className = 'myip-unlock-node-name';
            unlock_set_region(d, '');
        }
        unlock_pending[key] = quiet ? 'quiet' : true;
        unlock_render_ribbon(d, key);
    }

    function unlock_abort_checks() {
        Object.keys(unlock_xhrs).forEach(function(key) {
            var xhr = unlock_xhrs[key];
            delete unlock_xhrs[key];
            delete unlock_pending[key];
            try { xhr.abort(); } catch (e) {}
        });
        unlock_sync_ribbons();
    }

    function unlock_is_failed(key) {
        var r = unlock_results[key];
        return (Number(r && r.st) || 0) === 0;
    }

    function unlock_notify_failure(keys, manual) {
        if (!manual || !keys.every(unlock_is_failed)) return;
        if (keys.some(function(key) { return unlock_xhrs[key]; })) return;
        ocToast('<%:Unlock check failed, please check the network and try again%>', 'error');
    }

    // Services that failed are retried once, one parallel request each.
    function unlock_retry_failed(keys, manual, list, quiet) {
        var left = keys.length;
        keys.forEach(function(key) {
            if (unlock_xhrs[key]) { left--; return; }
            unlock_set_pending(key, manual || !unlock_results[key], quiet);
            var xhr = new XMLHttpRequest();
            xhr.open('GET', '/cgi-bin/luci/admin/services/openclash/unlock_check?service=' + encodeURIComponent(key), true);
            xhr.timeout = 90000;
            xhr.onloadend = function() {
                if (unlock_xhrs[key] === xhr) {
                    delete unlock_xhrs[key];
                    delete unlock_pending[key];
                    unlock_sync_ribbons();
                }
                // A newer request owns the service, so its own callback does the rendering.
                if (unlock_view && !unlock_xhrs[key]) {
                    var res = null;
                    if (xhr.status === 200) {
                        var lines = (xhr.responseText || '').split('\n');
                        for (var c = lines.length - 1; c >= 0 && !res; c--) {
                            var line = lines[c].trim();
                            if (line.charAt(0) !== '{') continue;
                            try {
                                var parsed = JSON.parse(line);
                                if (parsed && parsed.service === key) res = parsed;
                            } catch (e) {}
                        }
                    }
                    if (res) {
                        unlock_results[key] = { st: Number(res.st) || 0, region: res.region || '', node: res.node || '', ts: Date.now() };
                        unlock_save_results();
                    }
                    unlock_render(key);
                }
                left--;
                if (left || !unlock_view) return;
                syncCardHeights();
                unlock_notify_failure(list, manual);
            };
            xhr.send();
            unlock_xhrs[key] = xhr;
        });
        unlock_sync_ribbons();
    }

    function run_unlock_check(services, manual, quiet) {
        if (!unlock_view) return;
        var list = (services && services.length) ? services.slice() : UNLOCK_SERVICES.map(function(s) { return s.key; }).filter(unlock_is_selected);
        if (services && services.length) {
            list = list.filter(function(key) { return !unlock_xhrs[key]; });
        } else {
            var dropped = Object.keys(unlock_xhrs).filter(function(key) { return list.indexOf(key) < 0; });
            unlock_abort_checks();
            dropped.forEach(unlock_render);
        }
        if (!list.length) return;
        list.forEach(function(key) {
            unlock_set_pending(key, manual || !unlock_results[key], quiet);
        });

        var xhr = new XMLHttpRequest();
        var url = '/cgi-bin/luci/admin/services/openclash/unlock_check';
        if (list.length === 1) url += '?service=' + encodeURIComponent(list[0]);
        xhr.open('GET', url, true);
        xhr.timeout = 90000;
        var lastIndex = 0;
        var pendingBuf = '';
        var got = {};

        xhr.onprogress = function() {
            var newText = xhr.responseText.substring(lastIndex);
            lastIndex = xhr.responseText.length;
            pendingBuf += newText;
            var lines = pendingBuf.split('\n');
            pendingBuf = lines.pop();
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim();
                if (!line) continue;
                var obj = null;
                try { obj = JSON.parse(line); } catch (e) { continue; }
                if (!obj || !obj.service || list.indexOf(obj.service) < 0) continue;
                got[obj.service] = true;
                delete unlock_pending[obj.service];
                unlock_results[obj.service] = { st: obj.st, region: obj.region || '', node: obj.node || '', ts: Date.now() };
                unlock_save_results();
                if (unlock_view) unlock_render(obj.service);
            }
        };

        xhr.onloadend = function() {
            if (unlock_xhrs[list[0]] !== xhr) return;
            list.forEach(function(key) {
                delete unlock_xhrs[key];
                delete unlock_pending[key];
            });
            unlock_sync_ribbons();
            if (!unlock_view) return;
            list.forEach(function(key) {
                if (!got[key]) {
                    unlock_results[key] = { st: 0, region: '', node: '', ts: Date.now() };
                    unlock_render(key);
                }
            });
            unlock_save_results();
            syncCardHeights();
            var failed = list.filter(unlock_is_failed);
            if (failed.length) {
                unlock_retry_failed(failed, manual, list, quiet);
                return;
            }
            unlock_notify_failure(list, manual);
        };

        xhr.send();
        list.forEach(function(key) { unlock_xhrs[key] = xhr; });
        unlock_sync_ribbons();
    }

    function unlock_auto_reason_text() {
        if (unlock_auto_reason === 'enable') return '<%:Auto select requires the plugin to be enabled%>';
        if (unlock_auto_reason === 'self_proxy') return '<%:Auto select requires Router-Self Proxy, enable it in Plugin Settings - Traffic Control%>';
        return '';
    }

    function unlock_set_find_buttons() {
        var reason = unlock_auto_allowed ? '' : unlock_auto_reason_text();
        var btns = document.querySelectorAll('.myip-find-btn');
        Array.prototype.forEach.call(btns, function(b) {
            var busy = !!unlock_find_keys[b.getAttribute('data-key')];
            b.disabled = busy;
            b.classList.toggle('oc-disabled', !busy && !unlock_auto_allowed);
            if (busy) {
                b.textContent = '<%:Selecting...%>';
                b.title = '';
            } else {
                b.textContent = '<%:Auto Select%>';
                b.title = reason;
            }
        });
    }

    function unlock_find_node(key) {
        var i = unlock_service_index(key);
        if (i < 0 || unlock_find_keys[key] || !unlock_auto_allowed) return;
        ocConfirm({
            title: '<%:Start Test%>',
            body: '<%:Network instability may occur during testing, Are you sure want to start test?%>',
            buttons: [
                { label: '<%:Cancel%>', value: null },
                { label: '<%:OK%>', value: 'start', kind: 'primary' }
            ]
        }).then(function(choice) {
            if (choice !== 'start') return;
            unlock_find_keys[key] = true;
            unlock_set_find_buttons();
            unlock_set_pending(key, true);
            var xhr = new XMLHttpRequest();
            xhr.open('GET', '/cgi-bin/luci/admin/services/openclash/manual_stream_unlock_test?type=' + encodeURIComponent(UNLOCK_SERVICES[i].name) + '&result=1', true);
            xhr.timeout = 300000;
            xhr.onloadend = function() {
                var res = null;
                if (xhr.status === 200) {
                    var lines = (xhr.responseText || '').split('\n');
                    for (var c = lines.length - 1; c >= 0 && !res; c--) {
                        var line = lines[c].trim();
                        if (line.charAt(0) !== '{') continue;
                        try {
                            var parsed = JSON.parse(line);
                            if (parsed && parsed.service === UNLOCK_SERVICES[i].name) res = parsed;
                        } catch (e) {}
                    }
                }
                delete unlock_pending[key];
                if (res) {
                    unlock_results[key] = { st: Number(res.st) || 0, region: res.region || '', node: res.node || '', ts: Date.now() };
                    unlock_save_results();
                    if (unlock_view) {
                        unlock_render(key);
                        syncCardHeights();
                        if ((Number(res.st) || 0) === 0) {
                            ocToast('<%:Unlock check failed, please check the network and try again%>', 'error');
                        }
                    }
                } else {
                    if (unlock_view) {
                        unlock_render(key);
                        ocToast('<%:Test failed%>', 'error');
                    }
                }
                delete unlock_find_keys[key];
                unlock_set_find_buttons();
            };
            xhr.send();
        });
    }

    // Gear panel height tracks the card grid so switching views does not resize the page.
    function unlock_sync_gear_height() {
        var panel = unlock_gear_dom();
        var dom = unlock_init_dom();
        var cards = ACCESS_SLOTS.map(function(slot) { return dom[slot].card; });
        var cardsHidden = cards[0].style.display === 'none';
        var panelHidden = panel.classList.contains('oc-hidden');
        if (!panelHidden) panel.classList.add('oc-hidden');
        if (cardsHidden) cards.forEach(function(card) { card.style.display = ''; });
        var h = Math.round(document.querySelector('.myip-check-list').getBoundingClientRect().height);
        if (cardsHidden) cards.forEach(function(card) { card.style.display = 'none'; });
        if (!panelHidden) panel.classList.remove('oc-hidden');
        panel.style.height = h + 'px';
    }

    function unlock_enter_gear() {
        unlock_gear = true;
        stopUnlockTimers();
        var panel = unlock_gear_dom();
        var listEl = panel.querySelector('.myip-gear-list');
        var selected = unlock_slots();
        var rest = UNLOCK_SERVICES.map(function(s) { return s.key; }).filter(function(k) { return selected.indexOf(k) < 0; });
        unlock_gear_list = selected.concat(rest);
        unlock_gear_list.forEach(function(key) {
            var input = unlock_gear_input(key);
            if (input) input.checked = selected.indexOf(key) >= 0;
            listEl.appendChild(unlock_gear_rows[key]);
        });
        unlock_sync_gear(panel);
        unlock_sync_gear_height();
        var dom = unlock_init_dom();
        ACCESS_SLOTS.forEach(function(slot) {
            dom[slot].card.style.display = 'none';
        });
        panel.classList.remove('oc-hidden');
        unlock_set_gear_icon(true);
        var title = document.getElementById('myip-check-title');
        if (title) title.textContent = '<%:Unlock Services%>';
        syncCardHeights();
    }

    function toggle_unlock_by_icon(svgElement) {
        if (!unlock_view) {
            unlock_apply_view(true);
            run_unlock_check();
        } else {
            unlock_apply_view(false);
        }
        return false;
    }

    function toggle_unlock_gear_by_icon(svgElement) {
        if (unlock_gear) {
            unlock_apply_view(true);
        } else {
            if (!unlock_view) unlock_apply_view(true);
            unlock_enter_gear();
        }
        return false;
    }

    function unlock_apply_view(on) {
        unlock_view = !!on;
        unlock_gear = false;
        unlock_gear_drag_clear();
        localStorage.setItem('myip_unlock_view', unlock_view ? 'true' : 'false');
        unlock_abort_checks();
        var dom = unlock_init_dom();
        var title = document.getElementById('myip-check-title');
        var icon = document.getElementById('unlock-icon');
        var mainCard = document.querySelector('.myip-main-card');

        if (unlock_view) {
            if (mainCard) mainCard.classList.add('oc-unlock-view');
            unlock_set_gear_icon(false);
            unlock_gear_dom().classList.add('oc-hidden');
            unlock_gear_dom().style.height = '';
            if (title) title.textContent = '<%:Unlock Check%>';
            if (icon) {
                icon.classList.add('oc-unlock-on');
                var t = icon.querySelector('title');
                if (t) t.textContent = '<%:Unlock Check%>';
            }
            if (refresh_http) { clearInterval(refresh_http); refresh_http = null; }
            if (httpCheckXHR) { try { httpCheckXHR.abort(); } catch (e) {} httpCheckXHR = null; }
            unlock_fill_slots();
            unlock_render_all();
            unlock_set_find_buttons();
            unlock_load_services();
            startUnlockTimers();
        } else {
            stopUnlockTimers();
            if (mainCard) mainCard.classList.remove('oc-unlock-view');
            unlock_set_gear_icon(false);
            unlock_gear_dom().classList.add('oc-hidden');
            unlock_gear_dom().style.height = '';
            if (title) title.textContent = '<%:Access Check%>';
            if (icon) {
                icon.classList.remove('oc-unlock-on');
                var t2 = icon.querySelector('title');
                if (t2) t2.textContent = '<%:Access Check%>';
            }
            ACCESS_SLOTS.forEach(function(slot) {
                var d = dom[slot];
                d.card.setAttribute('data-svc', slot);
                d.card.style.display = '';
                d.label.innerHTML = d.labelHtml;
                d.label.removeAttribute('title');
                d.spark.innerHTML = '';
            });
            showAllGhosts();
            HTTP.runcheck();
            startHttpInterval();
            syncCardHeights();
        }
    }

    function myip_Load()
    {
        IP.getPcolIP();
        IP.getIpipIP();
        IP.getIpifyIP();
        IP.getIpsbIP();
    };

    function update_eye_icon(isOpen) {
        var eyeIcon = document.getElementById('eye-icon');
        var eyeOpen = document.getElementById('eye-open');
        var eyeClosed = document.getElementById('eye-closed');
        var titleElement = eyeIcon.querySelector('title');

        if (isOpen) {
            eyeOpen.classList.remove('oc-hidden');
            eyeClosed.classList.add('oc-hidden');
            if (titleElement) titleElement.textContent = '<%:Show IP%>';
        } else {
            eyeOpen.classList.add('oc-hidden');
            eyeClosed.classList.remove('oc-hidden');
            if (titleElement) titleElement.textContent = '<%:Hide IP%>';
        }
    };

    function privacy_my_ip(svgElement) {
        var isCurrentlyOpen = !document.getElementById('eye-open').classList.contains('oc-hidden');

        if (isCurrentlyOpen) {
            if (refresh_ip) { clearInterval(refresh_ip); refresh_ip = null; }
            localStorage.setItem('privacy_my_ip', 'true');
            update_eye_icon(false);

            ip_ipip_ip = $$.getElementById('ip-ipip').innerHTML;
            ip_ipsb_ip = $$.getElementById('ip-ipsb').innerHTML;
            ip_pcol_ip = $$.getElementById('ip-pcol').innerHTML;
            ip_ipify_ip = $$.getElementById('ip-ipify').innerHTML;
            $$.getElementById('ip-ipip').innerHTML = '***.***.***.***';
            $$.getElementById('ip-ipsb').innerHTML = '***.***.***.***';
            $$.getElementById('ip-pcol').innerHTML = '***.***.***.***';
            $$.getElementById('ip-ipify').innerHTML = '***.***.***.***';
            addTitleOnOverflow();
        } else {
            update_eye_icon(true);
            localStorage.removeItem('privacy_my_ip');

            if (ip_ipip_ip && ip_ipsb_ip && ip_pcol_ip && ip_ipify_ip) {
                $$.getElementById('ip-ipip').innerHTML = ip_ipip_ip;
                $$.getElementById('ip-ipsb').innerHTML = ip_ipsb_ip;
                $$.getElementById('ip-pcol').innerHTML = ip_pcol_ip;
                $$.getElementById('ip-ipify').innerHTML = ip_ipify_ip;
            } else {
                if (use_router_mode) {
                    get_router_ip_info();
                } else {
                    myip_Load();
                }
            }

            startIpInterval();
            addTitleOnOverflow();
        }
    };

    var use_router_mode = true;

    function toggle_mode_by_icon(svgElement) {
        if (use_router_mode) {
            use_router_mode = false;
            localStorage.setItem('myip_check_mode', 'false');
            update_mode_icon();
            clearAllIntervals();
            init_browser_mode();
        } else {
            use_router_mode = true;
            localStorage.setItem('myip_check_mode', 'true');
            update_mode_icon();
            clearAllIntervals();
            init_router_mode();
        }
    }

    function update_mode_icon() {
        var modeIcon = document.getElementById('mode-icon');
        var titleElement = modeIcon.querySelector('title');

        if (use_router_mode) {
            modeIcon.classList.remove('mode-browser');
            if (titleElement) titleElement.textContent = '<%:Router Mode%>';
        } else {
            modeIcon.classList.add('mode-browser');
            if (titleElement) titleElement.textContent = '<%:Browser Mode%>';
        }
    }

    function showAllGhosts() {
        if (unlock_view) return;
        ['baidu','163','github','youtube'].forEach(function(svc) {
            SpeedHistory.renderSparkline(svc, document.getElementById('spark-' + svc));
        });
    }

    function init_router_mode() {
        if (refresh_ip) { clearInterval(refresh_ip); refresh_ip = null; }

        if (localStorage.getItem('privacy_my_ip') === 'true') {
            $$.getElementById('ip-ipip').innerHTML = '***.***.***.***';
            $$.getElementById('ip-ipsb').innerHTML = '***.***.***.***';
            $$.getElementById('ip-pcol').innerHTML = '***.***.***.***';
            $$.getElementById('ip-ipify').innerHTML = '***.***.***.***';
        }

        showAllGhosts();
        get_router_ip_info();
        HTTP.runcheck();

        startHttpInterval();
        startIpInterval();
    }

    function init_browser_mode() {
        if (localStorage.getItem('privacy_my_ip') === 'true') {
            $$.getElementById('ip-ipip').innerHTML = '***.***.***.***';
            $$.getElementById('ip-ipsb').innerHTML = '***.***.***.***';
            $$.getElementById('ip-pcol').innerHTML = '***.***.***.***';
            $$.getElementById('ip-ipify').innerHTML = '***.***.***.***';
            $$.getElementById('ip-ipip-geo').innerHTML = '';
            $$.getElementById('ip-ipsb-geo').innerHTML = '';
            $$.getElementById('ip-pcol-geo').innerHTML = '';
            $$.getElementById('ip-ipify-geo').innerHTML = '';
        } else {
            reset_display();
        }

        showAllGhosts();
        myip_Load();
        HTTP.runcheck();

        startHttpInterval();
        startIpInterval();
    }

    function get_router_ip_info() {
        if (ipCheckXHR) { try { ipCheckXHR.abort(); } catch(e) {} ipCheckXHR = null; }
        var xhr = new XMLHttpRequest();
        xhr.open('GET', '/cgi-bin/luci/admin/services/openclash/myip_check', true);
        xhr.timeout = 35000;
        var lastIndex = 0;
        var pendingBuf = '';

        xhr.onprogress = function() {
            var newText = xhr.responseText.substring(lastIndex);
            lastIndex = xhr.responseText.length;
            pendingBuf += newText;
            var lines = pendingBuf.split('\n');
            pendingBuf = lines.pop();
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim();
                if (!line) continue;
                try {
                    var obj = JSON.parse(line);
                    if (obj.complete) {
                        addTitleOnOverflow();
                        return;
                    }
                    update_ip_single(obj);
                } catch(e) {}
            }
        };

        xhr.onload = function() {
            if (xhr.status !== 200) {
                if (!has_ip_cache()) show_querying_state();
            }
            addTitleOnOverflow();
        };

        xhr.ontimeout = function() {
            if (!has_ip_cache()) show_querying_state();
        };

        xhr.onerror = function() {
            if (!has_ip_cache()) show_querying_state();
        };

        xhr.onloadend = function() { if (ipCheckXHR === xhr) ipCheckXHR = null; };
        xhr.send();
        ipCheckXHR = xhr;
    }

    function update_ip_single(obj) {
        if (!obj || !obj.service) return;
        var key = obj.service;
        var isPrivacy = localStorage.getItem('privacy_my_ip') === 'true';

        var fieldMap = {
            'pcol': { id: 'ip-pcol', geo: 'ip-pcol-geo' },
            'ipip': { id: 'ip-ipip', geo: 'ip-ipip-geo' },
            'ipsb': { id: 'ip-ipsb', geo: 'ip-ipsb-geo' },
            'ipify': { id: 'ip-ipify', geo: 'ip-ipify-geo' }
        };

        var el = fieldMap[key];
        if (!el) return;

        if (obj.error) {
            var curIp = $$.getElementById(el.id).textContent;
            if (!curIp || curIp === '<%:Querying...%>' || curIp === '***.***.***.***') {
                $$.getElementById(el.id).innerHTML = (obj.error === 'timeout') ? '<%:Timeout%>' : querying_html();
            }
            $$.getElementById(el.geo).innerHTML = '';
            return;
        }

        if (obj.ip) {
            $$.getElementById(el.id).innerHTML = isPrivacy ? '***.***.***.***' : obj.ip;
        }
        if (obj.geo) {
            var geoText = obj.geo;
            if (obj.raw) {
                try {
                    // decode percent-encoded GBK bytes without UTF-8 validation
                    // (decodeURIComponent rejects non-UTF-8 bytes like %b9)
                    var latin1 = geoText.replace(/%([0-9A-Fa-f]{2})/g, function(_, h) {
                        return String.fromCharCode(parseInt(h, 16));
                    });
                    var rawBytes = Uint8Array.from(latin1, function(c) { return c.charCodeAt(0); });
                    geoText = new TextDecoder('gbk').decode(rawBytes);
                } catch(e) { geoText = ''; }
            }
            $$.getElementById(el.geo).innerHTML = geoText;
        }
    }

    function has_ip_cache() {
        const ip_ids = ['ip-ipip', 'ip-ipsb', 'ip-pcol', 'ip-ipify'];
        for (let id of ip_ids) {
            let val = document.getElementById(id).textContent;
            if (
                val &&
                val !== '<%:Querying...%>' &&
                val !== '***.***.***.***'
            ) {
                return true;
            }
        }
        return false;
    }

    function show_querying_state() {
        if (localStorage.getItem('privacy_my_ip') === 'true') {
            $$.getElementById('ip-ipip').innerHTML = '***.***.***.***';
            $$.getElementById('ip-ipsb').innerHTML = '***.***.***.***';
            $$.getElementById('ip-pcol').innerHTML = '***.***.***.***';
            $$.getElementById('ip-ipify').innerHTML = '***.***.***.***';
        } else {
            $$.getElementById('ip-ipip').innerHTML = querying_html();
            $$.getElementById('ip-ipsb').innerHTML = querying_html();
            $$.getElementById('ip-pcol').innerHTML = querying_html();
            $$.getElementById('ip-ipify').innerHTML = querying_html();
        }
        $$.getElementById('ip-ipip-geo').innerHTML = '';
        $$.getElementById('ip-ipsb-geo').innerHTML = '';
        $$.getElementById('ip-pcol-geo').innerHTML = '';
        $$.getElementById('ip-ipify-geo').innerHTML = '';
    }

    function reset_display() {
        $$.getElementById('ip-ipip').innerHTML = querying_html();
        $$.getElementById('ip-ipify').innerHTML = querying_html();
        $$.getElementById('ip-pcol').innerHTML = querying_html();
        $$.getElementById('ip-ipsb').innerHTML = querying_html();

        $$.getElementById('ip-ipip-geo').innerHTML = '';
        $$.getElementById('ip-ipify-geo').innerHTML = '';
        $$.getElementById('ip-pcol-geo').innerHTML = '';
        $$.getElementById('ip-ipsb-geo').innerHTML = '';
    }

    function refresh_myip(svgElement) {
        clearAllIntervals();
        reset_display();

        if (use_router_mode) {
            get_router_ip_info();
        } else {
            myip_Load();
        }
        if (!unlock_view) {
            ACCESS_SLOTS.forEach(function(svc) { updateCheckCard(svc, 'testing'); });
            HTTP.runcheck();
        } else if (!unlock_gear) {
            run_unlock_check(null, true);
        }

        startHttpInterval();
        startIpInterval();
        startUnlockTimers();

        return false;
    }
    function init_page() {
        if (localStorage.getItem('myip_unlock_view') === 'true') {
            unlock_apply_view(true);
            run_unlock_check();
        }

        var saved_mode = localStorage.getItem('myip_check_mode');
        if (saved_mode === 'true' || saved_mode === null) {
            use_router_mode = true;
            update_mode_icon();
            init_router_mode();
        } else {
            use_router_mode = false;
            update_mode_icon();
            init_browser_mode();
        }

        if (localStorage.getItem('privacy_my_ip') === 'true') {
            update_eye_icon(false);
        } else {
            update_eye_icon(true);
        }

        syncCardHeights();
        if (document.hidden) clearAllIntervals();
    }

    // Run immediately when the script is lazy-loaded after the load event.
    if (document.readyState === 'complete') {
        init_page();
    } else {
        window.addEventListener('load', function() {
            init_page();
        });
    }

    window.addEventListener('resize', function() {
        syncCardHeights();
        unlock_schedule_align();
        if (unlock_gear) unlock_sync_gear_height();
    });

    window.addEventListener('beforeunload', function() {
        clearAllIntervals();
        abortAllRequests();
    });
    window.addEventListener('pagehide', function() {
        clearAllIntervals();
        abortAllRequests();
    });

    document.addEventListener('visibilitychange', function() {
        if (document.hidden) {
            clearAllIntervals();
            return;
        }
        if (!unlock_view) {
            startHttpInterval();
            HTTP.runcheck();
        } else {
            startUnlockTimers();
        }
        startIpInterval();
        if (localStorage.getItem('privacy_my_ip') !== 'true') {
            if (use_router_mode) {
                get_router_ip_info();
            } else {
                myip_Load();
            }
        }
    });
