// Extracted from luasrc/view/openclash/update.htm - edit this file, not the template.
// <%:Message%> markers and <%=...%> islands are compiled server-side by the "openclash/translate_js" controller action.

    var core_version = document.getElementById('CORE_VERSION');
    var release_branch = document.getElementById('RELEASE_BRANCH');
    var smart_enable = document.getElementById('SMART_ENABLE');
    var versionTabMode = document.getElementById('selectPopup').classList.contains('select-popup-tab');
    var currentDownloadType = 'one_key';
    var refreshTimer = null;
    var updateInfoTimer = null;
    var versionRetryTimer = null;
    var retryTimer = null;
    var addrInfoBusy = false;
    var addrInfoXHR = null;
    var addrInfoError = false;
    var addrDataReceived = false;
    var reqUpdateDone = false;
    var reqVersionHistoryDone = false;
    var reqAddrInfoDone = false;
    var versionHistoryBusy = false;
    var versionHistoryXHR = null;
    var hintTimer = null;
    var defaultTipTimer = null;
    var logStream = null;
    var lastLogLineCount = null;
    var logLines = [];
    var fetchedBranch = null;
    var isOix = false;
    var pkgType = 'opkg';
    var forceRefresh = false;
    var infoCache = {};
    var currentProxyAddr = '';
    var addrSortDirty = true;

    function isValidURL(str) {
        var pattern = new RegExp('^(https?:\\/\\/)?'+ // protocol
            '((([a-z\\d]([a-z\\d-]*[a-z\\d])*)\\.)+[a-z]{2,}|'+ // domain name
            '((\\d{1,3}\\.){3}\\d{1,3}))'+ // OR ip (v4) address
            '(\\:\\d+)?(\\/[-a-z\\d%_.&#126;+]*)*'+ // port and path
            '(\\?[;&a-z\\d%_.&#126;+=-]*)?'+ // query string
            '(\\#[-a-z\\d_]*)?'+'\/$','i');
        return !!pattern.test(str);
    }

    function showHint(message, duration) {
        var hint = document.getElementById('version-hint');
        if (defaultTipTimer) { clearTimeout(defaultTipTimer); defaultTipTimer = null; }
        if (hintTimer) { clearTimeout(hintTimer); hintTimer = null; }
        hint.innerHTML = '<svg><use href="#oc-icon-alert-circle"/></svg><span>' + message + '</span>';
        hint.classList.add('show');
        hint.classList.remove('note');
        if (duration === 0) return;
        hintTimer = setTimeout(function() {
            showDefaultNote();
            hintTimer = null;
        }, duration || 5000);
    }

    function showDefaultNote() {
        var hint = document.getElementById('version-hint');
        if (hintTimer) { clearTimeout(hintTimer); hintTimer = null; }
        if (defaultTipTimer) { clearTimeout(defaultTipTimer); defaultTipTimer = null; }
        var tips = [
            '<%:Note: manual upload works if the update fails%>',
            '<%:Note: squashfs firmware may not free disk space%>'
        ];
        var tip = tips[Math.floor(Math.random() * tips.length)];
        hint.innerHTML = '<svg><use href="#oc-icon-alert-circle"/></svg><span>' + tip + '</span>';
        hint.classList.add('show');
        hint.classList.add('note');
        defaultTipTimer = setTimeout(function() {
            defaultTipTimer = null;
            showDefaultNote();
        }, 5000);
    }

    function classifyAddr(url) {
        if (!url || url === '') return 'raw';
        if (/raw\.githubusercontent\.com/i.test(url)) return 'raw';
        if (/jsdelivr|fastly|testingcf/i.test(url)) return 'jsdelivr';
        if (/dl\.dler\.io/i.test(url)) return 'dler';
        return 'proxy';
    }

    function buildDownloadURL(addr, type, branch, version, sha, arch) {
        var isJsDelivr = classifyAddr(addr) === 'jsdelivr';
        var filename, pathPrefix;

        if (type === 'core' && isOix) {
            if (!version) return '';
            filename = 'mihomo-' + arch + '-' + version + '.gz';
            var oixURL = 'https://github.com/vernesong/mihomo-oix/releases/download/Pre-Alpha/' + filename;
            var proxyURL = 'https://dl.dler.io/mihomo-oix/' + filename + '?tag=Pre-Alpha';
            var ctype = classifyAddr(addr);
            if (ctype === 'dler') {
                return proxyURL;
            }
            if (addr && addr !== '' && ctype !== 'raw' && ctype !== 'jsdelivr') {
                return addr + oixURL;
            }
            return proxyURL;
        }

        if (type === 'plugin') {
            var verNoV = version.replace(/^v/, '');
            if (pkgType === 'apk') {
                filename = 'luci-app-openclash-' + verNoV + '.apk';
            } else {
                filename = 'luci-app-openclash_' + verNoV + '_all.ipk';
            }
            pathPrefix = 'package/' + branch;
        } else {
            filename = 'clash-' + arch + '.tar.gz';
            var coreSubPath = (smart_enable.value === '1') ? 'smart' : 'meta';
            pathPrefix = 'core/' + branch + '/' + coreSubPath;
        }

        if (sha) {
            var refPath = (type === 'plugin') ? branch : branch + '/' + coreSubPath;
            if (isJsDelivr)
                return addr + 'gh/vernesong/OpenClash@' + sha + '/' + refPath + '/' + filename;
            else if (classifyAddr(addr) === 'raw')
                return 'https://raw.githubusercontent.com/vernesong/OpenClash/' + sha + '/' + refPath + '/' + filename;
            else
                return addr + 'https://raw.githubusercontent.com/vernesong/OpenClash/' + sha + '/' + refPath + '/' + filename;
        } else {
            if (isJsDelivr)
                return addr + 'gh/vernesong/OpenClash@' + pathPrefix + '/' + filename;
            else if (classifyAddr(addr) === 'raw')
                return 'https://raw.githubusercontent.com/vernesong/OpenClash/' + pathPrefix + '/' + filename;
            else
                return addr + 'https://raw.githubusercontent.com/vernesong/OpenClash/' + pathPrefix + '/' + filename;
        }
    }

    function findSHAbyVersion(selectEl, targetVer) {
        if (!targetVer || !selectEl) return '';
        for (var i = 0; i < selectEl.options.length; i++) {
            if (selectEl.options[i].getAttribute('data-ver') === targetVer) {
                var v = selectEl.options[i].value;
                return (v && v !== '__latest__') ? v : '';
            }
        }
        return '';
    }

    function escAttr(s) {
        return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/"/g, '&quot;');
    }

    function makeVerCell(addrUrl, type, version) {
        var branch = fetchedBranch || release_branch.value || 'dev';
        var arch = core_version.value;
        var selectEl = type === 'plugin'
            ? document.getElementById('select-plugin-ver')
            : document.getElementById('select-core-ver');
        var verText = version;
        var isLatest = false;

        if (!verText) {
            if (type === 'plugin') {
                return null;
            }

            var selectedOption = selectEl.options[selectEl.selectedIndex];
            isLatest = !selectedOption || selectedOption.value === '__latest__';

            if (!isLatest) {
                verText = selectedOption.getAttribute('data-ver');
            }

            if (!verText) return null;
        }

        var useVersion = (verText === 'Latest') ? '' : verText;
        var sha = useVersion ? findSHAbyVersion(selectEl, useVersion) : '';
        var dlUrl = buildDownloadURL(addrUrl, type, branch, useVersion, sha, arch);

        var verLink = '<a href="javascript:void(0)" class="ver-link" data-type="' + type + '" data-ver="' + escAttr(useVersion) + '" data-dl="' + escAttr(dlUrl) + '" title="<%:Click to Install%>">' + verText + '</a>';
        if (!dlUrl) {
            return verLink;
        }
        return verLink +
            '<a href="' + escAttr(dlUrl) + '" target="_blank" rel="noopener" class="dl-btn" title="<%:Download%>"><svg width="11" height="11"><use href="#oc-icon-download"/></svg></a>';
    }

    var verColsTimer = null;

    // the plugin and core columns are as wide as the versions in them need: the widest cell is
    // measured and written as a custom property, so the header and the rows stay on the same tracks
    // and a version with a long suffix is not cut behind an ellipsis
    function syncVersionColumns() {
        var body = document.getElementById('addr-list-body');
        if (!body) return;
        var widest = { plugin: 0, core: 0 };
        document.querySelectorAll('#addr-list-body .addr-row .ver-text').forEach(function (cell) {
            var link = cell.querySelector('.ver-link');
            if (!link) return;
            var key = cell.classList.contains('ver-plugin') ? 'plugin' : (cell.classList.contains('ver-core') ? 'core' : null);
            if (!key) return;
            // the range reads the full text even while the cell clips it, the paddings and the download
            // button are what the cell has to hold around that text
            var range = document.createRange();
            range.selectNodeContents(link);
            var linkStyle = getComputedStyle(link);
            var cellStyle = getComputedStyle(cell);
            var btn = cell.querySelector('.dl-btn');
            var width = range.getBoundingClientRect().width
                + parseFloat(linkStyle.paddingLeft) + parseFloat(linkStyle.paddingRight)
                + parseFloat(cellStyle.paddingLeft) + parseFloat(cellStyle.paddingRight)
                + (btn ? btn.offsetWidth + parseFloat(cellStyle.columnGap || 0) : 0)
                + 2;
            if (width > widest[key]) widest[key] = width;
        });
        if (widest.plugin > 0) body.style.setProperty('--addr-ver-plugin', Math.ceil(widest.plugin) + 'px');
        if (widest.core > 0) body.style.setProperty('--addr-ver-core', Math.ceil(widest.core) + 'px');
    }

    function queueVersionColumns() {
        if (verColsTimer) return;
        verColsTimer = setTimeout(function () {
            verColsTimer = null;
            syncVersionColumns();
        }, 60);
    }

    // a breakpoint change also changes the font size of the cells, so the measurement is redone
    function resetVersionColumns() {
        var body = document.getElementById('addr-list-body');
        if (!body) return;
        body.style.removeProperty('--addr-ver-plugin');
        body.style.removeProperty('--addr-ver-core');
        queueVersionColumns();
    }

    function updateAddrRow(row, addrUrl, info) {
        var smart = smart_enable.value || '0';
        var latencyEl = row.querySelector('.addr-status');
        var verSpans = row.querySelectorAll('.ver-text');
        var pluginEl = verSpans[0];
        var coreEl = verSpans[1];
        var coreVer = (smart === '1' && info.core_smart_ver) ? info.core_smart_ver : info.core_meta_ver;
        var errText = '';
        if (info.latency === -1) {
            errText = '<%:Access Timed Out%>';
        } else if (info.latency === -2) {
            errText = '<%:Access Denied%>';
        } else if (info.latency > 0 && (!info.plugin_ver || !coreVer)) {
            errText = info.core_error === 'timeout' ? '<%:Access Timed Out%>' : '<%:Access Denied%>';
        }
        row.classList.toggle('row-error', !!errText);

        infoCache[addrUrl] = {
            plugin_ver: info.plugin_ver || null,
            core_meta_ver: info.core_meta_ver || null,
            core_smart_ver: info.core_smart_ver || null,
            latency: info.latency,
            core_error: info.core_error || null,
            error: errText || null
        };

        if (errText) {
            latencyEl.textContent = errText;
            latencyEl.className = 'addr-status err';
            latencyEl.title = '';
            if (pluginEl) { pluginEl.textContent = '--'; pluginEl.classList.remove('has-data', 'err'); }
            if (coreEl) { coreEl.textContent = '--'; coreEl.classList.remove('has-data', 'err'); }
            queueVersionColumns();
            return;
        }

        if (info.latency != null && info.latency > 0) {
            var ms = parseInt(info.latency);
            latencyEl.textContent = ms + ' ms';
            latencyEl.className = 'addr-status ' + (ms <= 500 ? 'fast' : ms <= 1000 ? 'medium' : 'slow');
            latencyEl.title = '';
        } else {
            latencyEl.textContent = '--';
            latencyEl.className = 'addr-status';
            latencyEl.title = '';
        }

        if (pluginEl) {
            if (info.plugin_ver) {
                pluginEl.innerHTML = makeVerCell(addrUrl, 'plugin', info.plugin_ver);
                pluginEl.classList.add('has-data');
                pluginEl.classList.remove('err');
            } else {
                pluginEl.textContent = '--';
                pluginEl.classList.remove('has-data', 'err');
            }
        }
        if (coreEl) {
            if (coreVer) {
                coreEl.innerHTML = makeVerCell(addrUrl, 'core', coreVer);
                coreEl.classList.add('has-data');
                coreEl.classList.remove('err');
            } else {
                coreEl.textContent = '--';
                coreEl.classList.remove('has-data', 'err');
            }
        }

        queueVersionColumns();
    }

    function buildAddrRows(st) {
        var listBody = document.querySelector('#addr-list-body .addr-list-scroll') || document.getElementById('addr-list-body');
        var customOpt = document.getElementById('custom-addr-option');
        var existing = {};
        listBody.querySelectorAll('.addr-row').forEach(function(row) {
            var v = row.dataset.value;
            if (v) existing[v] = true;
        });
        function addRow(val) {
            if (!val || existing[val]) return;
            var div = document.createElement('div');
            div.className = 'select-option addr-row';
            div.dataset.value = val;
            div.innerHTML = '<span class="addr-row-index"></span><span class="addr-row-url">' + val + '</span><span class="addr-status">--</span><span class="ver-text ver-plugin">--</span><span class="ver-text ver-core">--</span>';
            listBody.insertBefore(div, customOpt);
            existing[val] = true;
            addrSortDirty = true;
        }
        var mod = st.github_address_mod;
        if (mod && mod !== '0') addRow(mod);
        (st.cdn_list || []).forEach(addRow);
    }

    function renderProxyStates() {
        document.querySelectorAll('#addr-list-body .addr-row').forEach(function(row) {
            if (classifyAddr(row.dataset.value) === 'raw') return;
            var el = row.querySelector('.addr-proxy');
            if (!el) {
                el = document.createElement('span');
                el.className = 'addr-proxy';
                row.appendChild(el);
            }
            var on = (row.dataset.value === currentProxyAddr);
            el.textContent = on ? '<%:Enabled%>' : '<%:Disabled%>';
            el.className = 'addr-proxy ' + (on ? 'on' : 'off');
        });
    }

    function toggleProxy(row) {
        var val = row.dataset.value;
        if (!val) return;
        var newVal = (val === currentProxyAddr) ? '0' : val;
        XHR.get('<%=url("admin", "services", "openclash", "save_github_address_mod")%>', {value: newVal}, function(x) {
            if (x && x.status == 200) {
                currentProxyAddr = newVal;
                renderProxyStates();
            } else {
                showHint('<%:Failed to save%>');
            }
        });
    }

    function fetchUpdateInfo(opts) {
        var silent = !!(opts && opts.silent);
        if (!silent) {
            core_version.disabled = true;
            release_branch.disabled = true;
            smart_enable.disabled = true;
            document.getElementById('select-plugin-ver').disabled = true;
            document.getElementById('select-core-ver').disabled = true;
        }
        XHR.get('<%=url("admin", "services", "openclash", "update")%>', null, function(x, st) {
            if (x && x.status == 200) {
                if (st.corever && st.corever != '0') core_version.value = st.corever; else core_version.value = '0';
                if (st.release_branch) release_branch.value = st.release_branch; else release_branch.value = 'master';
                if (st.smart_enable) smart_enable.value = st.smart_enable; else smart_enable.value = '0';
                isOix = !!(st.oix_core);
                pkgType = st.pkg_type || 'opkg';
                document.getElementById('installed-plugin').textContent = (st.opcv && st.opcv != '0') ? st.opcv : '--';
                document.getElementById('installed-core').textContent = (st.coremetacv && st.coremetacv != '0') ? st.coremetacv : '--';
                var cpuArchEl = document.getElementById('CPU_ARCH_VALUE');
                if (cpuArchEl) {
                    cpuArchEl.textContent = (st.coremodel && st.coremodel != '') ? st.coremodel : '--';
                }
                currentProxyAddr = (st.github_address_mod || '0');
                buildAddrRows(st);
                renderProxyStates();
            }
            if (!silent) {
                core_version.disabled = false;
                release_branch.disabled = false;
                smart_enable.disabled = false;
            }
            fetchedBranch = release_branch.value;
            updateDataStatus({ update: true });
            if (!silent) {
                fetchVersionHistory(!!(opts && opts.force), {cancel: true});
                refreshAddrInfo({cancel: true, user: true});
            }
        });
    }

    function initAllData() {
        fetchUpdateInfo();
        if (refreshTimer) { clearInterval(refreshTimer); refreshTimer = null; }
        refreshTimer = setInterval(refreshAddrInfo, ocRandomInterval(10000, 20000));
        if (updateInfoTimer) { clearInterval(updateInfoTimer); updateInfoTimer = null; }
        updateInfoTimer = setInterval(function() { fetchUpdateInfo({silent: true}); }, ocRandomInterval(30000, 60000));
    }

    function fetchVersionHistory(force, opts) {
        if (document.getElementById('selectPopup').classList.contains('hidden')) return;
        if (versionHistoryBusy) {
            if (!(opts && opts.cancel)) return;
            if (versionHistoryXHR) { try { versionHistoryXHR.abort(); } catch(e) {} versionHistoryXHR = null; }
            versionHistoryBusy = false;
        }
        versionHistoryBusy = true;
        updateDataStatus({ version: false });
        var branch = fetchedBranch || release_branch.value || 'dev';
        var pluginSelect = document.getElementById('select-plugin-ver');
        var coreSelect = document.getElementById('select-core-ver');
        var hint = document.getElementById('version-hint');
        var params = { branch: branch };
        var smart = smart_enable.value || '0';

        var appendHistoryEntry = function(entry) {
            var selectEl = null;
            if (entry.type === 'plugin' && entry.version) {
                selectEl = pluginSelect;
            } else if (!isOix && entry.type === 'core_meta' && smart !== '1' && entry.version) {
                selectEl = coreSelect;
            } else if (!isOix && entry.type === 'core_smart' && smart === '1' && entry.version) {
                selectEl = coreSelect;
            }
            if (!selectEl) return;
            var option = new Option(
                entry.version + ' (<%:Date%>: ' + (entry.date || '').substring(0, 10) + ')',
                entry.sha
            );
            option.setAttribute('data-ver', entry.version);
            selectEl.appendChild(option);
        };

        if (force) params.force = '1';

        pluginSelect.disabled = true;
        coreSelect.disabled = true;

        pluginSelect.innerHTML = '<option value="__latest__"><%:Latest%></option>';
        coreSelect.innerHTML = '<option value="__latest__"><%:Latest%></option>';

        var url = '<%=url("admin", "services", "openclash", "version_history")%>?' +
            Object.keys(params).map(function(k) { return encodeURIComponent(k) + '=' + encodeURIComponent(params[k]); }).join('&');
        var xhr = new XMLHttpRequest();
        xhr.timeout = 0;
        xhr.open('GET', url, true);
        xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
        var lastLen = 0;
        var pendingBuf = '';
        xhr.onprogress = function() {
            if (xhr.status != 200) return;
            var text = xhr.responseText;
            if (text.length <= lastLen) return;
            var newText = text.substring(lastLen);
            lastLen = text.length;
            pendingBuf += newText;
            var lines = pendingBuf.split('\n');
            pendingBuf = lines.pop();
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim();
                if (!line) continue;
                try {
                    var entry = JSON.parse(line);
                    if (entry.complete) {
                        if (entry.error) {
                            showHint('<%:Failed to get version history%>');
                            pluginSelect.disabled = true;
                            coreSelect.disabled = true;
                            if (!versionRetryTimer) {
                                versionRetryTimer = setInterval(fetchVersionHistory, 10000);
                            }
                        } else {
                            pluginSelect.disabled = false;
                            coreSelect.disabled = false;
                            if (versionRetryTimer) { clearInterval(versionRetryTimer); versionRetryTimer = null; }
                        }
                        continue;
                    }
                    appendHistoryEntry(entry);
                } catch(e) {}
            }
        };
        xhr.onload = function() {
            if (xhr.status != 200 || !xhr.responseText) {
                showHint('<%:Failed to get version history%>');
                if (!versionRetryTimer) {
                    versionRetryTimer = setInterval(fetchVersionHistory, 10000);
                }
                return;
            }
            var text = xhr.responseText;
            if (text.length > lastLen) {
                var newText = text.substring(lastLen);
                lastLen = text.length;
                pendingBuf += newText;
                var lines = pendingBuf.split('\n');
                pendingBuf = lines.pop();
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (!line) continue;
                    try {
                        var entry = JSON.parse(line);
                        if (entry.complete) {
                            if (entry.error) {
                                showHint('<%:Failed to get version history%>');
                                pluginSelect.disabled = true;
                                coreSelect.disabled = true;
                                if (!versionRetryTimer) {
                                    versionRetryTimer = setInterval(fetchVersionHistory, 10000);
                                }
                            } else {
                                pluginSelect.disabled = false;
                                coreSelect.disabled = false;
                                if (versionRetryTimer) { clearInterval(versionRetryTimer); versionRetryTimer = null; }
                            }
                            continue;
                        }
                        appendHistoryEntry(entry);
                    } catch(e) {}
                }
            }
            if (pendingBuf && pendingBuf.trim()) {
                var line = pendingBuf.trim();
                pendingBuf = '';
                try {
                    var entry = JSON.parse(line);
                    if (entry.complete) {
                        if (entry.error) {
                            showHint('<%:Failed to get version history%>');
                            pluginSelect.disabled = true;
                            coreSelect.disabled = true;
                            if (!versionRetryTimer) {
                                versionRetryTimer = setInterval(fetchVersionHistory, 10000);
                            }
                        } else {
                            pluginSelect.disabled = false;
                            coreSelect.disabled = false;
                            if (versionRetryTimer) { clearInterval(versionRetryTimer); versionRetryTimer = null; }
                        }
                    } else {
                        appendHistoryEntry(entry);
                    }
                } catch(e) {}
            }

        };
        xhr.onerror = function() {
            showHint('<%:Failed to get version history%>');
            if (!versionRetryTimer) {
                versionRetryTimer = setInterval(fetchVersionHistory, 10000);
            }
        };
        xhr.onloadend = function() {
            if (versionHistoryXHR === xhr) {
                versionHistoryXHR = null;
                versionHistoryBusy = false;
            }
            updateDataStatus({ version: true });
        };
        xhr.send();
        versionHistoryXHR = xhr;
    }

    function saveOptions() {
        XHR.get('<%=url("admin", "services", "openclash", "save_corever_branch")%>', {
            core_ver: core_version.value,
            release_branch: release_branch.value,
            smart_enable: smart_enable.value
        },function() {});
    }

    function onArchChange() {
        saveOptions();
        document.querySelectorAll('#addr-list-body .addr-row').forEach(function(row) {
            var addrUrl = row.dataset.value;
            if (!addrUrl || addrUrl === 'custom') return;
            var info = infoCache[addrUrl];
            if (info) updateAddrRow(row, addrUrl, info);
        });
    }

    function onBranchChange() {
        fetchedBranch = release_branch.value;
        if (versionRetryTimer) { clearInterval(versionRetryTimer); versionRetryTimer = null; }
        if (retryTimer) { clearInterval(retryTimer); retryTimer = null; }
        saveOptions();
        resetDataStatus(true);
        fetchVersionHistory(false, {cancel: true});
        forceRefresh = true;
        refreshAddrInfo({cancel: true, user: true});
    }

    function onSmartChange() {
        saveOptions();
        resetDataStatus(true);
        fetchVersionHistory(false, {cancel: true});
        forceRefresh = true;
        refreshAddrInfo({cancel: true, user: true});
    }

    function setAddrListLoading(loading) {
        var overlay = document.getElementById('addr-list-loading');
        if (overlay) overlay.classList.toggle('oc-hidden', !loading);
    }

    function clearAddrRows() {
        document.querySelectorAll('#addr-list-body .addr-row').forEach(function(row) {
            var latencyEl = row.querySelector('.addr-status');
            var verSpans = row.querySelectorAll('.ver-text');
            if (latencyEl) {
                latencyEl.textContent = '--';
                latencyEl.className = 'addr-status';
            }
            verSpans.forEach(function(el) {
                el.textContent = '--';
                el.classList.remove('has-data', 'err');
            });
            row.classList.remove('row-error');
        });
        addrSortDirty = true;
        updateAddrListState();
    }

    function addrLatencyRank(addrUrl) {
        var info = infoCache[addrUrl];
        if (!info || info.error || info.latency == null || info.latency <= 0) return Infinity;
        return info.latency;
    }

    function sortAddrRows() {
        var listBody = document.querySelector('#addr-list-body .addr-list-scroll') || document.getElementById('addr-list-body');
        var customOpt = document.getElementById('custom-addr-option');
        if (!listBody || !customOpt) return;
        var rows = Array.prototype.slice.call(listBody.querySelectorAll('.addr-row'));
        var pinned = [];
        var sortable = [];
        rows.forEach(function(row) {
            if (classifyAddr(row.dataset.value) === 'raw') pinned.push(row);
            else sortable.push(row);
        });
        sortable.sort(function(a, b) {
            var ka = addrLatencyRank(a.dataset.value);
            var kb = addrLatencyRank(b.dataset.value);
            if (ka === kb) return 0;
            return ka < kb ? -1 : 1;
        });
        pinned.concat(sortable).forEach(function(row) { listBody.insertBefore(row, customOpt); });
    }

    function updateAddrListState() {
        var card = document.getElementById('addr-list-empty');
        var scroll = document.querySelector('#addr-list-body .addr-list-scroll');
        if (!card || !scroll) return;
        var rows = Array.prototype.slice.call(scroll.querySelectorAll('.addr-row'));
        var known = 0;
        var reachable = 0;
        rows.forEach(function(row) {
            var info = infoCache[row.dataset.value];
            if (!info || info.latency == null) return;
            known++;
            if (info.latency > 0 || info.latency === -3) reachable++;
        });
        var mode = rows.length === 0 ? 'empty' : (known > 0 && reachable === 0 ? 'error' : '');
        card.classList.toggle('err', mode === 'error');
        card.classList.toggle('oc-hidden', !mode);
        scroll.classList.toggle('all-failed', mode === 'error');
        if (!mode) return;
        document.getElementById('addr-empty-title').textContent = mode === 'empty'
            ? '<%:No mirror address%>'
            : '<%:All mirrors are unreachable%>';
        document.getElementById('addr-empty-text').textContent = mode === 'empty'
            ? '<%:Add a custom CDN address below, then retry.%>'
            : '<%:Check the network or proxy settings, then retry.%>';
    }

    function updateDataStatus(flags) {
        if (flags) {
            if ('update' in flags) reqUpdateDone = flags.update;
            if ('version' in flags) reqVersionHistoryDone = flags.version;
            if ('addr' in flags) reqAddrInfoDone = flags.addr;
        }
        var status = document.getElementById('addr-list-status');
        if (!status) return;
        if (addrInfoError) {
            status.textContent = '<%:Failed to get data, will retry%>';
            return;
        }
        status.textContent = (reqUpdateDone && reqVersionHistoryDone && reqAddrInfoDone) ? '<%:Ready%>' : '<%:Fetching data...%>';
    }

    function resetDataStatus(keepUpdate) {
        if (!keepUpdate) reqUpdateDone = false;
        reqVersionHistoryDone = false;
        reqAddrInfoDone = false;
        addrInfoError = false;
        updateDataStatus();
    }

    function refreshAddrInfo(opts) {
        if (document.getElementById('selectPopup').classList.contains('hidden')) return;
        var addrs = [];
        document.querySelectorAll('#addr-list-body .addr-row').forEach(function(row) {
            var v = row.dataset.value;
            if (v && v !== 'custom' && isValidURL(v)) addrs.push(v);
        });
        if (addrs.length === 0) return;
        if (addrInfoBusy) {
            if (!(opts && opts.cancel)) return;
            if (addrInfoXHR) { try { addrInfoXHR.abort(); } catch(e) {} addrInfoXHR = null; }
            addrInfoBusy = false;
        }
        addrInfoBusy = true;
        if (opts && opts.user) updateDataStatus({ addr: false });

        var branch = fetchedBranch || release_branch.value || 'dev';
        var smart = smart_enable.value || '0';
        var pluginVer = document.getElementById('select-plugin-ver').value;
        var coreVer = document.getElementById('select-core-ver').value;
        var params = {
            addrs: addrs.join(','),
            branch: branch,
            smart: smart,
            plugin_ver: pluginVer || '',
            core_ver: coreVer || ''
        };
        if (opts && opts.merge) {
            params.merge = '1';
        }
        if (forceRefresh) {
            params.force = '1';
            forceRefresh = false;
            infoCache = {};
            addrDataReceived = false;
            showDefaultNote();
            clearAddrRows();
        }
        if (opts && opts.user && !addrDataReceived) setAddrListLoading(true);
        var url = '<%=url("admin", "services", "openclash", "addr_info")%>?' +
            Object.keys(params).map(function(k) { return encodeURIComponent(k) + '=' + encodeURIComponent(params[k]); }).join('&');
        var xhr = new XMLHttpRequest();
        xhr.timeout = 0;
        xhr.open('GET', url, true);
        xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
        var lastLen = 0;
        var pendingBuf = '';
        xhr.onprogress = function() {
            if (xhr.status != 200) return;
            var text = xhr.responseText;
            if (text.length <= lastLen) return;
            var newText = text.substring(lastLen);
            lastLen = text.length;
            pendingBuf += newText;
            var lines = pendingBuf.split('\n');
            pendingBuf = lines.pop();
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim();
                if (!line) continue;
                try {
                    var info = JSON.parse(line);
                    if (info.complete) {
                        if (info.error === 'version_stale') {
                            fetchVersionHistory(true);
                        }
                        if (addrSortDirty) {
                            addrSortDirty = false;
                            sortAddrRows();
                        }
                        updateAddrListState();
                        continue;
                    }
                    var addrUrl = info.addr;
                    if (!addrUrl) continue;
                    if (!addrDataReceived) { addrDataReceived = true; setAddrListLoading(false); }
                    var rows = document.querySelectorAll('#addr-list-body .addr-row[data-value="' + CSS.escape(addrUrl) + '"]');
                    rows.forEach(function(row) { updateAddrRow(row, addrUrl, info); });
                } catch(e) {}
            }
        };
        xhr.onload = function() {
            if (xhr.status != 200 || !xhr.responseText) {
                if (retryTimer) { clearInterval(retryTimer); retryTimer = null; }
                if (refreshTimer) { clearInterval(refreshTimer); refreshTimer = null; }
                addrInfoError = true;
                if (!retryTimer) {
                    retryTimer = setInterval(refreshAddrInfo, 10000);
                }
                return;
            }
            addrInfoError = false;
            var text = xhr.responseText;
            if (text.length > lastLen) {
                var newText = text.substring(lastLen);
                lastLen = text.length;
                pendingBuf += newText;
                var lines = pendingBuf.split('\n');
                pendingBuf = lines.pop();
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (!line) continue;
                    try {
                        var info = JSON.parse(line);
                        if (info.complete) {
                            if (info.error === 'version_stale') {
                                fetchVersionHistory(true);
                            }
                            if (addrSortDirty) {
                                addrSortDirty = false;
                                sortAddrRows();
                            }
                            updateAddrListState();
                            continue;
                        }
                        var addrUrl = info.addr;
                        if (!addrUrl) continue;
                        if (!addrDataReceived) { addrDataReceived = true; setAddrListLoading(false); }
                        var rows = document.querySelectorAll('#addr-list-body .addr-row[data-value="' + CSS.escape(addrUrl) + '"]');
                        rows.forEach(function(row) { updateAddrRow(row, addrUrl, info); });
                    } catch(e) {}
                }
            }

            if (retryTimer) { clearInterval(retryTimer); retryTimer = null; }
            if (!refreshTimer) {
                refreshTimer = setInterval(refreshAddrInfo, ocRandomInterval(10000, 20000));
            }
        };
        xhr.onerror = function() {
            if (refreshTimer) { clearInterval(refreshTimer); refreshTimer = null; }
            if (retryTimer) { clearInterval(retryTimer); retryTimer = null; }
            addrInfoError = true;
            retryTimer = setInterval(refreshAddrInfo, 10000);
        };
        xhr.onloadend = function() {
            if (addrInfoXHR === xhr) {
                addrInfoXHR = null;
                addrInfoBusy = false;
            }
            if (opts && opts.user) updateDataStatus({ addr: true });
        };
        xhr.send();
        addrInfoXHR = xhr;
    }

    function initHeaderDrag() {
        var popup = document.getElementById('selectPopup');
        var header = popup ? popup.querySelector('.select-popup-header') : null;
        if (!popup || !header || popup.classList.contains('select-popup-tab')) return;
        if (header.dataset.ocDragInit) return;
        header.dataset.ocDragInit = '1';
        header.classList.add('oc-draggable');

        var dragging = false;
        var startX = 0, startY = 0, startLeft = 0, startTop = 0;

        header.addEventListener('pointerdown', function(e) {
            if (e.target.closest && e.target.closest('button, a, select, input')) return;
            dragging = true;
            var rect = popup.getBoundingClientRect();
            startX = e.clientX;
            startY = e.clientY;
            startLeft = rect.left;
            startTop = rect.top;
            popup.style.transform = 'none';
            popup.style.left = rect.left + 'px';
            popup.style.top = rect.top + 'px';
            popup.style.transition = 'none';
            if (header.setPointerCapture) {
                try { header.setPointerCapture(e.pointerId); } catch(err) {}
            }
            e.preventDefault();
        });

        header.addEventListener('pointermove', function(e) {
            if (!dragging) return;
            popup.style.left = (startLeft + (e.clientX - startX)) + 'px';
            popup.style.top = (startTop + (e.clientY - startY)) + 'px';
        });

        function stopDrag(e) {
            if (!dragging) return;
            dragging = false;
            popup.style.transition = '';
            if (header.releasePointerCapture) {
                try { header.releasePointerCapture(e.pointerId); } catch(err) {}
            }
        }
        header.addEventListener('pointerup', stopDrag);
        header.addEventListener('pointercancel', stopDrag);
    }

    function update(btn, type) {
        var selectPopup = document.getElementById('selectPopup');
        var customOptionInput = document.getElementById('customOptionInput');
        var addCustomOption = document.getElementById('addCustomOption');

        currentDownloadType = type || 'one_key';
        customOptionInput.classList.add('oc-hidden');
        addCustomOption.classList.add('oc-hidden');
        customOptionInput.value = 'https://ghfast.top/';
        fetchedBranch = null;
        addrDataReceived = false;
        resetDataStatus();

        selectPopup.classList.remove('hidden');
        selectPopup.onclick = function(event) { click_handler(event); };
        setAddrListLoading(true);
        initAllData();
        initHeaderDrag();
    }

    function handleVersionUpdate(verLink) {
        var row = verLink.closest ? verLink.closest('.addr-row') : null;
        var addrUrl = row ? row.dataset.value : '';
        var type = verLink.getAttribute('data-type');
        var ver = verLink.getAttribute('data-ver') || '';
        var dlUrl = verLink.getAttribute('data-dl') || '';

        var branch = fetchedBranch || release_branch.value || 'dev';
        var arch = core_version.value;
        var selectEl = type === 'plugin'
            ? document.getElementById('select-plugin-ver')
            : document.getElementById('select-core-ver');

        if (type === 'core' && (!arch || arch === '0')) {
            showHint('<%:No Compiled Version Selected, Please Select In Update Page And Try Again!%>');
            return;
        }
        var sha = ver ? findSHAbyVersion(selectEl, ver) : '';
        var selOpt = selectEl.options[selectEl.selectedIndex];
        var isLatest = !selOpt || selOpt.value === '__latest__';
        if (ver && !sha && !isLatest && !(type === 'core' && isOix)) {
            showHint('<%:The selected version is not in the version history, please refresh and try again%>');
            return;
        }

        if (ver) {
            dlUrl = buildDownloadURL(addrUrl, type, branch, ver, sha, arch);
        }

        showDefaultNote();

        var addrInfo = infoCache[addrUrl];
        if (!addrInfo || addrInfo.latency == null) {
            showHint('<%:Version info not ready, please wait and try again%>');
            return;
        }
        if (addrInfo.latency === -1 || addrInfo.latency === -2 || addrInfo.latency === -3) {
            var errMsg = addrInfo.latency === -1 ? '<%:Link access timed out, cannot download%>' : '<%:Link access failed, cannot download%>';
            showHint(errMsg);
            return;
        }

        if (!dlUrl) {
            showHint('<%:Failed to get download link%>');
            return;
        }

        if (type === 'plugin') {
            var installedVer = (document.getElementById('installed-plugin').textContent || '').trim();
            if (ver && installedVer && installedVer !== '--' && installedVer === ver) {
                showHint('<%:The selected version is the same as the installed version, no need to update%>');
                return;
            }
        } else {
            var installedCoreVer = (document.getElementById('installed-core').textContent || '').trim();
            if (ver && installedCoreVer && installedCoreVer !== '--' && installedCoreVer === ver) {
                showHint('<%:The selected version is the same as the installed version, no need to update%>');
                return;
            }
        }

        startLog('<%:Checking...%>', false, type === 'core' ? 'openclash_core.sh' : 'openclash_update.sh');

        var addr = addrUrl;
        if (addr === 'https://raw.githubusercontent.com/') addr = '';

        if (type === 'core') {
            var params = {download_url: dlUrl};
            if (addr && addr !== '') params.url = addr;
            XHR.get('<%=url("admin", "services", "openclash", "core_download")%>', params, function() {});
        } else {
            var pParams = {url: addr, download_url: dlUrl, update_type: 'plugin'};
            XHR.get('<%=url("admin", "services", "openclash", "one_key_update")%>', pParams, function() {});
        }
    }

    function initPopupResizeObserver() {
        var popup = document.getElementById('selectPopup');
        if (!popup || typeof ResizeObserver === 'undefined') return;
        if (popup.dataset.ocResizeInit) return;
        popup.dataset.ocResizeInit = '1';
        new ResizeObserver(function() {
            if (popup.offsetWidth > 0 && popup.offsetHeight > 0) {
                if (popup.classList.contains('select-popup-tab')) return;
                if (popup.style.left || popup.style.top) return;
                popup.style.transform = 'translate(' + Math.round(-popup.offsetWidth / 2) + 'px, ' + Math.round(-popup.offsetHeight / 2) + 'px)';
            }
        }).observe(popup);
    }

    function click_handler(event) {
        var target = event.target;
        var customInput = document.getElementById('customOptionInput');
        var addBtn = document.getElementById('addCustomOption');
        var optionElem = target.closest ? target.closest('.select-option') : null;

        var staticEl = target.closest ? target.closest('.addr-proxy-static') : null;
        if (staticEl) return;

        var verLink = target.closest ? target.closest('.ver-link') : null;
        if (verLink) {
            handleVersionUpdate(verLink);
            return;
        }
        var dlBtn = target.closest ? target.closest('.dl-btn') : null;
        if (dlBtn) {
            return;
        }
        var proxyEl = target.closest ? target.closest('.addr-proxy') : null;
        if (proxyEl) {
            var prow = proxyEl.closest('.addr-row');
            if (prow) toggleProxy(prow);
            return;
        }

        if (optionElem && optionElem.dataset.value === 'custom' && !customInput.classList.contains('oc-hidden')) {
            customInput.classList.add('oc-hidden');
            addBtn.classList.add('oc-hidden');
        } else if (optionElem && optionElem.dataset.value === 'custom') {
            customInput.classList.remove('oc-hidden');
            addBtn.classList.remove('oc-hidden');
            customInput.focus();
        } else if (target === customInput) {
            customInput.classList.remove('oc-hidden');
            addBtn.classList.remove('oc-hidden');
        } else if (target === addBtn) {
            var val = customInput.value.trim();
            var listBody = document.querySelector('#addr-list-body .addr-list-scroll') || document.getElementById('addr-list-body');
            var alreadyListed = false;
            listBody.querySelectorAll('.addr-row').forEach(function(row) {
                if (row.dataset.value === val) alreadyListed = true;
            });
            if (alreadyListed) {
                customInput.classList.add('oc-hidden');
                addBtn.classList.add('oc-hidden');
            } else if (val !== '' && isValidURL(val)) {
                var div = document.createElement('div');
                div.className = 'select-option addr-row';
                div.dataset.value = val;
                div.innerHTML = '<span class="addr-row-index"></span><span class="addr-row-url">' + val + '</span><span class="addr-status">--</span><span class="ver-text ver-plugin">--</span><span class="ver-text ver-core">--</span>';
                listBody.insertBefore(div, document.getElementById('custom-addr-option'));
                customInput.classList.add('oc-hidden');
                addBtn.classList.add('oc-hidden');
                addrSortDirty = true;
                renderProxyStates();
                refreshAddrInfo({merge: true, cancel: true, user: true});
                XHR.get('<%=url("admin", "services", "openclash", "save_custom_addr")%>', {addr: val}, function(x) {
                    if (!x || x.status != 200) showHint('<%:Failed to save%>');
                });
            } else {
                alert('<%:Please enter a valid URL!%>');
            }
        } else if (optionElem && optionElem.classList.contains('addr-row') && target.closest('.addr-row-url')) {
            var addr = optionElem.dataset.value;

            showDefaultNote();

            var addrInfo = infoCache[addr];
            if (!addrInfo || addrInfo.latency == null) {
                showHint('<%:Version info not ready, please wait and try again%>');
                return;
            }
            if (addrInfo.latency === -1 || addrInfo.latency === -2 || addrInfo.latency === -3) {
                var errMsg = addrInfo.latency === -1 ? '<%:Link access timed out, cannot download%>' : '<%:Link access failed, cannot download%>';
                showHint(errMsg);
                return;
            }

            var branch = fetchedBranch || release_branch.value || 'dev';
            var arch = core_version.value;
            var v = core_version.value;
            var r = release_branch.value;
            var s = smart_enable.value;

            if (!arch || arch === '0') {
                showHint('<%:No Compiled Version Selected, Please Select In Update Page And Try Again!%>');
                return;
            }

            var pluginSel = document.getElementById('select-plugin-ver');
            var coreSel = document.getElementById('select-core-ver');
            var pluginOpt = pluginSel.options[pluginSel.selectedIndex];
            var coreOpt = coreSel.options[coreSel.selectedIndex];
            var isPluginLatest = !pluginOpt || pluginOpt.value === '__latest__';
            var isCoreLatest = !coreOpt || coreOpt.value === '__latest__';

            var pluginVer = addrInfo.plugin_ver || '';
            var coreVer = (s === '1' && addrInfo.core_smart_ver)
                ? addrInfo.core_smart_ver
                : (addrInfo.core_meta_ver || '');

            var pluginSHA = (!isPluginLatest && addrInfo.plugin_ver) ? findSHAbyVersion(pluginSel, addrInfo.plugin_ver) : '';
            var useCoreVer = (s === '1' && addrInfo.core_smart_ver) ? addrInfo.core_smart_ver : addrInfo.core_meta_ver;
            var coreSHA = (!isCoreLatest && useCoreVer) ? findSHAbyVersion(coreSel, useCoreVer) : '';

            if (currentDownloadType !== 'core_download' && !isPluginLatest && addrInfo.plugin_ver && !pluginSHA) {
                showHint('<%:The selected version is not in the version history, please refresh and try again%>');
                return;
            }
            if (!isCoreLatest && useCoreVer && !coreSHA) {
                showHint('<%:The selected version is not in the version history, please refresh and try again%>');
                return;
            }

            if (currentDownloadType !== 'core_download') {
                // One-key update: both plugin and core will be updated
                if (!pluginVer) {
                    showHint('<%:Failed to get plugin version info from this link, please check again later%>');
                    return;
                }
                if (!coreVer) {
                    showHint('<%:Failed to get core version info from this link, please check again later%>');
                    return;
                }

                var installedVer = (document.getElementById('installed-plugin').textContent || '').trim();
                var installedCoreVer = (document.getElementById('installed-core').textContent || '').trim();
                var pluginSame = installedVer && installedVer !== '--' && installedVer === pluginVer;
                var coreSame = installedCoreVer && installedCoreVer !== '--' && installedCoreVer === coreVer;

                if (pluginSame && coreSame) {
                    showHint('<%:The selected version is the same as the installed version, no need to update%>');
                    return;
                }
            } else {
                // Core download only: check core only
                if (!coreVer) {
                    showHint('<%:Failed to get core version info from this link, please check again later%>');
                    return;
                }

                var installedCoreVer = (document.getElementById('installed-core').textContent || '').trim();
                if (installedCoreVer && installedCoreVer !== '--' && installedCoreVer === coreVer) {
                    showHint('<%:The selected version is the same as the installed version, no need to update%>');
                    return;
                }
            }

            startLog('<%:Checking...%>', false, currentDownloadType === 'core_download' ? 'openclash_core.sh' : 'openclash_update.sh');

            if (addr === 'https://raw.githubusercontent.com/') addr = '';

            if (currentDownloadType === 'core_download') {
                var coreURL = buildDownloadURL(addr, 'core', r, coreVer, coreSHA, arch);
                var params = {download_url: coreURL};
                if (addr && addr !== '') params.url = addr;
                XHR.get('<%=url("admin", "services", "openclash", "core_download")%>', params, function() {});
            } else {
                var pluginURL = buildDownloadURL(addr, 'plugin', r, pluginVer, pluginSHA, arch);
                var oneKeyParams = {url: addr};
                if (!pluginSame) {
                    oneKeyParams.download_url = pluginURL;
                }
                XHR.get('<%=url("admin", "services", "openclash", "one_key_update")%>', oneKeyParams, function() {});
            }
        }
    }

    function refreshAllData() {
        showDefaultNote();
        infoCache = {};
        addrDataReceived = false;
        resetDataStatus();
        setAddrListLoading(true);
        forceRefresh = true;
        clearAddrRows();
        if (versionRetryTimer) { clearInterval(versionRetryTimer); versionRetryTimer = null; }
        if (retryTimer) { clearInterval(retryTimer); retryTimer = null; }
        if (refreshTimer) { clearInterval(refreshTimer); refreshTimer = null; }
        if (updateInfoTimer) { clearInterval(updateInfoTimer); updateInfoTimer = null; }
        fetchedBranch = null;
        fetchUpdateInfo({force: true});
        refreshTimer = setInterval(refreshAddrInfo, ocRandomInterval(10000, 20000));
        updateInfoTimer = setInterval(function() { fetchUpdateInfo({silent: true}); }, ocRandomInterval(30000, 60000));
    }

    function closeSelectPopup() {
        var popup = document.getElementById('selectPopup');
        var customInput = document.getElementById('customOptionInput');
        var addBtn = document.getElementById('addCustomOption');
        if (!versionTabMode) {
            popup.classList.add('hidden');
            popup.style.transform = '';
            popup.style.left = '';
            popup.style.top = '';
            popup.style.transition = '';
        }
        if (addrInfoXHR) { try { addrInfoXHR.abort(); } catch(e) {} addrInfoXHR = null; }
        if (versionHistoryXHR) { try { versionHistoryXHR.abort(); } catch(e) {} versionHistoryXHR = null; }
        addrInfoBusy = false;
        versionHistoryBusy = false;
        if (!logStream || !logStream.isRunning()) { showDefaultNote(); }
        if (refreshTimer) { clearInterval(refreshTimer); refreshTimer = null; }
        if (updateInfoTimer) { clearInterval(updateInfoTimer); updateInfoTimer = null; }
        if (versionRetryTimer) { clearInterval(versionRetryTimer); versionRetryTimer = null; }
        if (retryTimer) { clearInterval(retryTimer); retryTimer = null; }
        customInput.classList.add('oc-hidden');
        addBtn.classList.add('oc-hidden');
    }

    function remove_all_core(btn) {
        if (confirm('<%:Are you sure want to remove all core files?%>')) {
            ocSetBtnBusy(btn, true, '<%:Removing...%>');
            XHR.get('<%=url("admin", "services", "openclash", "remove_all_core")%>', null, function(x) {
                alert((x && x.status == 200) ? '<%:Remove succeeded!%>' : '<%:Remove failed!%>');
                ocSetBtnBusy(btn, false);
            });
        }
        return false;
    }

    function backup_file(btn) {
        var endpoint = document.getElementById('BACKUP_SELECT').value;
        var url = '<%=url("admin", "services", "openclash")%>/' + endpoint;
        ocSetBtnBusy(btn, true, '<%:Backing up...%>');
        var xhr = new XMLHttpRequest();
        xhr.open('GET', url, true);
        xhr.responseType = 'blob';
        xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
        xhr.onload = function() {
            ocSetBtnBusy(btn, false);
            if (xhr.status == 200 && xhr.response) {
                var disposition = xhr.getResponseHeader('Content-Disposition') || '';
                var match = disposition.match(/filename="?([^";]+)"?/);
                var filename = match ? match[1] : endpoint + '.tar.gz';
                var blobUrl = URL.createObjectURL(xhr.response);
                var a = document.createElement('a');
                a.href = blobUrl;
                a.download = filename;
                document.body.appendChild(a);
                a.click();
                document.body.removeChild(a);
                setTimeout(function() { URL.revokeObjectURL(blobUrl); }, 1000);
            } else {
                alert('<%:Backup failed!%>');
            }
        };
        xhr.onerror = function() {
            ocSetBtnBusy(btn, false);
            alert('<%:Backup failed!%>');
        };
        xhr.send();
        return false;
    }

    function restore_config(btn) {
        if (confirm('<%:Are you sure want to restore the default config?%>')) {
            ocSetBtnBusy(btn, true, '<%:Restoring...%>');
            XHR.get('<%=url("admin", "services", "openclash", "restore")%>', null, function(x) {
                ocSetBtnBusy(btn, false);
                if (x && x.status == 200) {
                    alert('<%:Restore succeeded!%>');
                } else {
                    alert('<%:Restore failed!%>');
                }
                window.location.href = '<%=url("admin", "services", "openclash", "settings")%>';
            });
        }
        return false;
    }

    function startLog(initialMessage, skipClearLog, scriptName) {
        if (logStream) {
            if (initialMessage) {
                logStream.abort();
                logStream = null;
            } else {
                return;
            }
        }
        if (initialMessage) {
            lastLogLineCount = null;
            logLines = [];
            var initialHint = document.getElementById('version-hint');
            if (defaultTipTimer) { clearTimeout(defaultTipTimer); defaultTipTimer = null; }
            if (hintTimer) { clearTimeout(hintTimer); hintTimer = null; }
            if (initialHint) {
                initialHint.classList.add('logging');
                initialHint.innerHTML = '';
                initialHint.ocScrollPending = false;
                initialHint.ocScrollFlush = null;
                if (initialHint.ocScrollAnimId) {
                    cancelAnimationFrame(initialHint.ocScrollAnimId);
                }
                initialHint.ocScrollAnimId = null;
                initialHint.ocScrollAnim = null;
                initialHint.style.willChange = '';
                initialHint.scrollTop = 0;
            }
        }

        function resetHint() {
            var hint = document.getElementById('version-hint');
            if (!hint) return;
            if (hint.ocScrollAnimId) { cancelAnimationFrame(hint.ocScrollAnimId); }
            hint.ocScrollAnimId = null;
            hint.ocScrollAnim = null;
            hint.ocScrollPending = false;
            hint.ocScrollFlush = null;
            hint.style.willChange = '';
            hint.classList.remove('logging');
            showDefaultNote();
        }

        var stream = ocCreateLogStream({
            url: '<%=url("admin", "services", "openclash", "startlog")%>',
            script: scriptName,
            initialMessage: initialMessage ? '<b style="color:var(--info-color)">' + initialMessage + '</b>' : '',
            skipLines: lastLogLineCount,
            onSkipLines: function(n) { lastLogLineCount = n; },
            maxWaitMs: initialMessage ? 600000 : 0,
            display: displayLog,
            onFinish: function() { logStream = null; resetHint(); },
            onTimeout: function() { logStream = null; resetHint(); }
        });
        logStream = stream;

        if (skipClearLog) {
            stream.start();
        } else {
            XHR.get('<%=url("admin", "services", "openclash", "del_start_log")%>', null, function() {
                stream.start();
            });
        }
    }

    function renderUpdateLog() {
        var hint = document.getElementById('version-hint');
        if (!hint) return;
        if (!hint.classList.contains('logging')) {
            hint.classList.add('logging');
            hint.innerHTML = '';
            hint.scrollTop = 0;
        }
        hint.innerHTML = '';
        var fragment = document.createDocumentFragment();
        for (var j = 0; j < logLines.length; j++) {
            var color = ocGetLogColor(logLines[j]);
            var div = document.createElement('div');
            div.style.whiteSpace = 'nowrap';
            div.innerHTML = '<b style="color:' + color + '">' + logLines[j] + '</b>';
            fragment.appendChild(div);
        }
        hint.appendChild(fragment);
    }

    function flushUpdateLog() {
        var hint = document.getElementById('version-hint');
        if (!hint) return;
        renderUpdateLog();
        ocAnimateScroll(hint, flushUpdateLog);
    }

    function displayLog(logContent) {
        var hint = document.getElementById('version-hint');
        if (!hint) return;

        var lines = logContent.split('\n');
        var allLines = [];
        for (var i = 0; i < lines.length; i++) {
            var t = lines[i].replace(/##FINISHED##|##CONTINUE##|##FINISH##/g, '').trim().replace(/^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\s*/, '');
            if (t) allLines.push(t);
        }
        if (allLines.length === 0) return;

        var isFirst = logLines.length === 0 && allLines.length === 1;
        logLines = logLines.concat(allLines);

        // A batch is still animating: buffer the lines and let the current
        // animation finish before rendering the next batch.
        if (hint.ocScrollAnim) {
            ocAnimateScroll(hint, flushUpdateLog);
            return;
        }

        renderUpdateLog();
        ocAnimateScroll(hint, flushUpdateLog, isFirst);
    }

    showDefaultNote();
    if (versionTabMode) {
        var tabPopup = document.getElementById('selectPopup');
        if (tabPopup) {
            tabPopup.onclick = function(event) { click_handler(event); };
        }
        setAddrListLoading(true);
        resetDataStatus();
        initAllData();
    }

    function stopLogStream() {
        if (logStream) {
            logStream.abort();
            logStream = null;
        }
        var hint = document.getElementById('version-hint');
        if (hint) {
            hint.ocScrollPending = false;
            hint.ocScrollFlush = null;
            if (hint.ocScrollAnimId) {
                cancelAnimationFrame(hint.ocScrollAnimId);
                hint.ocScrollAnimId = null;
                hint.ocScrollAnim = null;
                hint.style.willChange = '';
            }
            hint.classList.remove('logging');
            showDefaultNote();
        }
    }
    window.addEventListener('beforeunload', stopLogStream);
    window.addEventListener('pagehide', stopLogStream);
    window.addEventListener('resize', resetVersionColumns);
    initPopupResizeObserver();
