// OpenClash shared utilities
// Guard: skip if already loaded (handles multi-template page loads)
_ocGuard: { if (window._ocCommonLoaded) break _ocGuard; window._ocCommonLoaded = true; }

// ═══ Remove LuCI's global @media (prefers-reduced-motion: reduce) ═══
(function() {
    var sheets = document.styleSheets;
    for (var i = sheets.length - 1; i >= 0; i--) {
        try {
            var rules = sheets[i].cssRules || sheets[i].rules;
            if (!rules) continue;
            for (var j = rules.length - 1; j >= 0; j--) {
                var rule = rules[j];
                if (rule.type === CSSRule.MEDIA_RULE &&
                    /prefers-reduced-motion.*reduce/.test(rule.conditionText)) {
                    sheets[i].deleteRule(j);
                }
            }
        } catch(e) {}
    }
})();

// ═══ Internal helpers ═══

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

function detectInitialAutoDark() {
    var html = document.documentElement,
        v, cls, lum;
    // 1. HTML data-* attributes (Bootstrap 5.3, Material, OpenClash, and generic)
    var bs = html.getAttribute('data-bs-theme'),
        th = html.getAttribute('data-theme'),
        dm = html.getAttribute('data-darkmode');
    v = bs || th || dm;
    if (v === 'dark' || v === 'dim' || v === 'true') return true;
    if (v === 'light' || v === 'false') return false;
    // 2. HTML class name (Argon dark-mode, generic theme-dark, etc.)
    cls = ' ' + (html.className || '') + ' ';
    if (cls.indexOf(' dark ') >= 0 || cls.indexOf(' dark-mode ') >= 0 ||
        cls.indexOf(' theme-dark ') >= 0 || cls.indexOf(' night-mode ') >= 0) return true;
    // 3. localStorage keys used by popular LuCI themes
    var keys = [['mode', 'dark'], ['dark_mode', '1'], ['argon_dark_mode', '1'],
                ['theme', 'dark'], ['luci-theme-mode', 'dark']];
    for (var i = 0; i < keys.length; i++) {
        v = localStorage.getItem(keys[i][0]);
        if (v === keys[i][1]) return true;
        if (v === 'light' || v === '0' || v === 'false') return false;
    }
    // 4. CSS custom properties for dark themes
    var style = getComputedStyle(html),
        checkBg = style.getPropertyValue('--bs-body-bg').trim()
               || style.getPropertyValue('--body-bg').trim()
               || style.getPropertyValue('--theme-bg').trim();
    if (checkBg && checkBg !== 'transparent' && checkBg !== 'rgba(0, 0, 0, 0)')
        return luminanceFromColor(checkBg) < 128;

    // 5. System preference (ultimate fallback)
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

// ═══ Theme system ═══

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
    var m = document.querySelector('meta[name="color-scheme"]');
    if (!m) {
        m = document.createElement('meta');
        m.name = 'color-scheme';
        document.head.appendChild(m);
    }
    m.content = d ? 'dark' : 'light';
}

function ocInitTheme() {
	if (window._ocThemeInited) {
		ocUpdateTheme();
		return;
	}
	window._ocThemeInited = true;

	ocApplyRootTheme();

	var needsCorrection = (localStorage.getItem('oc-theme') || 'auto') === 'auto';

	function _ocDomReady() {
		if (needsCorrection) ocApplyRootTheme();
		ocApplyEditorTheme();
		ocHideEmptyCbiElements();
		ocCenterCbiActions();
	}

	if (document.readyState === 'loading') {
		document.addEventListener('DOMContentLoaded', _ocDomReady);
	} else {
		_ocDomReady();
	}
}

function ocUpdateTheme() {
	ocApplyRootTheme();
	ocApplyEditorTheme();
}

if (window.matchMedia) {
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function() {
        if ((localStorage.getItem('oc-theme') || 'auto') === 'auto') {
            ocApplyRootTheme();
            if (document.body) ocUpdateTheme();
        }
    });
}

// ═══ General utilities ═══

function winOpen(url) {
	var win = window.open(url);
	if (win == null) {
		window.location.href = url;
	}
	return false;
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

function ocGetDashboardBaseURL(status) {
	var host, port, proto;
	if (status.daip && window.location.hostname === status.daip) {
		host = window.location.hostname;
		port = status.cn_port;
		proto = 'http://';
	} else if (status.daip && status.db_foward_domain && status.db_foward_port) {
		host = status.db_foward_domain;
		port = status.db_foward_port;
		proto = (status.db_forward_ssl == 0 ? 'http://' : 'https://');
	} else {
		host = window.location.hostname;
		port = status.cn_port;
		proto = 'http://';
	}
	return { host: host, port: port, proto: proto, secret: status.dase || '' };
}

function ocBuildDashboardURL(status, uiPath, needsSetup) {
	var base = ocGetDashboardBaseURL(status);
	var url = base.proto + base.host + ':' + base.port + '/ui/' + uiPath;
	if (needsSetup) {
		url += '/#/setup?hostname=' + base.host + '&port=' + base.port;
		if (base.secret) url += '&secret=' + base.secret;
	} else if (uiPath === 'yacd') {
		url += '/?hostname=' + base.host + '&port=' + base.port;
		if (base.secret) url += '&secret=' + base.secret;
	} else if (uiPath === 'dashboard') {
		url += '/#/?host=' + base.host + '&port=' + base.port;
		if (base.secret) url += '&secret=' + base.secret;
	}
	return url;
}

// ═══ Editor state ═══

window._ocFullscreenActive = false;
window._ocMergeShowDifferences = true;
window._ocEditorHotkeysBound = false;
window._ocFullscreenPatch = null;

window._ocZoomLevels = [75, 90, 100, 110, 125, 150, 200];
window._ocCurrentZoom = 100;

// ═══ Editor — fullscreen ═══
// Walk ancestors and patch stacking contexts so position:fixed can
// break out. backdrop-filter traps fixed children (creates a
// containing block); positioned+z-index creates a stacking context.
// We fix the closest backdrop-filter and the outermost z-index.

// Handles both EditorView (.dom) and MergeView (.a.dom, .b.dom)
function ocGetEditorDom(instance) {
	if (!instance) return null;
	if (instance.dom) return instance.dom;
	if (instance.a && instance.a.dom) return instance.a.dom;
	return null;
}

function _ocEnterFullscreen(dom) {
	_ocExitFullscreen();
	var patch = window._ocFullscreenPatch = {};
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

function _ocExitFullscreen() {
	var p = window._ocFullscreenPatch;
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
	window._ocFullscreenPatch = null;
}

// ═══ Editor — lookup ═══
// Priority: merge editor state > ConfigEditor modal > CM6.getActiveEditor()

function ocGetActiveEditorInstance() {
	if (window._mergeEditorState && window._mergeEditorState.instance) {
		return window._mergeEditorState.instance;
	}
	if (window.ConfigEditor && window.ConfigEditor.editorInstance) {
		return window.ConfigEditor.editorInstance;
	}
	if (typeof CM6 !== 'undefined' && CM6.getActiveEditor) {
		return CM6.getActiveEditor();
	}
	return null;
}

// ═══ Editor — zoom ═══
// Applies zoom-{level} CSS class to .cm-editor elements.
// For MergeView, applies to BOTH side panels so the .oc .cm-editor.zoom-XX rules match.

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
		window._ocZoomLevels.forEach(function(level) {
			dom.classList.remove('zoom-' + level);
		});
		if (zoomLevel !== 100) {
			dom.classList.add('zoom-' + zoomLevel);
		}
	});
	window._ocCurrentZoom = zoomLevel;
}

// Returns new zoom level without applying it
function ocZoomIn(currentZoom) {
	var cur = typeof currentZoom === 'number' ? currentZoom : window._ocCurrentZoom;
	var idx = window._ocZoomLevels.indexOf(cur);
	if (idx < window._ocZoomLevels.length - 1) {
		return window._ocZoomLevels[idx + 1];
	}
	return cur;
}

function ocZoomOut(currentZoom) {
	var cur = typeof currentZoom === 'number' ? currentZoom : window._ocCurrentZoom;
	var idx = window._ocZoomLevels.indexOf(cur);
	if (idx > 0) {
		return window._ocZoomLevels[idx - 1];
	}
	return cur;
}

function ocResetZoom() {
	return 100;
}

// Passthrough for CM5-era _cmWhenReady compatibility
window._cmWhenReady = function(cb) { cb(); };

// ═══ Theme — CM6 & CBI helpers ═══

// Apply CM6 editor themes + highlight.js theme based on current data-darkmode.
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

function ocHideEmptyCbiElements() {
	var emptyEls = document.querySelectorAll('.cbi-section-table-titles, .cbi-section-table-descr, .cbi-section-descr');
	for (var i = 0; i < emptyEls.length; i++) {
		if (emptyEls[i].textContent.trim() === '') { emptyEls[i].style.display = 'none'; }
	}
}

function ocCenterCbiActions() {
	var ids = ['Commit', 'Apply', 'Create', 'Back', 'Load_Config',
		'Delete_Unused_Servers', 'Delete_Servers', 'Delete_Proxy_Provider', 'Delete_Groups',
		'proxy_mg', 'rule_mg', 'pro_mg'];
	for (var i = 0; i < ids.length; i++) {
		var els = document.querySelectorAll('[id$="-' + ids[i] + '"]');
		for (var j = 0; j < els.length; j++) {
			els[j].style.textAlign = 'center';
		}
	}
}

// ═══ Hotkeys ═══
// F11 fullscreen, F10 diff toggle, Esc exit, Ctrl+/-/0 zoom, Ctrl+Wheel zoom.
// Registered once globally (capture phase so it beats CM6's own key handling).

function ocRegisterEditorHotkeys() {
	if (window._ocEditorHotkeysBound) return;
	window._ocEditorHotkeysBound = true;

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
			if (window._ocFullscreenActive) {
				var fsEl = document.getElementById('oc-fullscreen-active');
				if (fsEl && typeof CM6 !== 'undefined' && CM6.toggleFullscreen) {
					CM6.toggleFullscreen(fsEl);
				}
				_ocExitFullscreen();
				window._ocFullscreenActive = false;
				if (window.ConfigEditor) window.ConfigEditor.isFullscreen = false;
			} else {
				if (typeof CM6 !== 'undefined' && CM6.getActiveEditor && CM6.toggleFullscreen) {
					var target = CM6.getActiveEditor();
					if (target) {
						_ocEnterFullscreen(target);
						window._ocFullscreenActive = !!CM6.toggleFullscreen(target);
						if (window.ConfigEditor) window.ConfigEditor.isFullscreen = window._ocFullscreenActive;
					}
				}
			}
			ocApplyEditorTheme();
			return;
		}

		if (e.key === 'F10' && window._mergeViewInstance && window._mergeViewInstance.reconfigure) {
			e.preventDefault();
			window._ocMergeShowDifferences = !window._ocMergeShowDifferences;
			window._mergeViewInstance.reconfigure({
				highlightChanges: window._ocMergeShowDifferences,
				gutter: window._ocMergeShowDifferences
			});
			if (window._mergeViewInstance.dom) {
				window._mergeViewInstance.dom.classList.toggle('oc-diff-hidden', !window._ocMergeShowDifferences);
			}
			return;
		}

		if (e.key === 'Escape' && window._ocFullscreenActive) {
			e.preventDefault();
			e.stopPropagation();
			var fsEl = document.getElementById('oc-fullscreen-active');
			if (fsEl && typeof CM6 !== 'undefined' && CM6.toggleFullscreen) {
				CM6.toggleFullscreen(fsEl);
			}
			_ocExitFullscreen();
			window._ocFullscreenActive = false;
			if (window.ConfigEditor) window.ConfigEditor.isFullscreen = false;
			ocApplyEditorTheme();
		}
	}, true);

	// Separate listener — wheel needs {passive:false} for preventDefault
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

// ═══ Loading overlay ═══

var _ocLoadingMap = typeof WeakMap !== 'undefined' ? new WeakMap() : (function(){
	var m = {};
	return {
		get: function(k) { return m[k._ocLid]; },
		set: function(k, v) { var id = '_ocl' + Math.random(); k._ocLid = id; m[id] = v; },
		delete: function(k) { delete m[k._ocLid]; }
	};
})();

function ocShowLoading(container, message, minHeight) {
	if (!container) return;
	var prevPos = container.style.position;
	var prevMinH = container.style.minHeight;
	container.style.position = 'relative';
	if (minHeight) container.style.minHeight = minHeight;
	var el = document.createElement('div');
	el.className = 'config-editor-loading';
	el.innerHTML = '<div class="loading-spinner"></div><span>' + (message || 'Loading\u2026') + '</span>';
	container.appendChild(el);
	_ocLoadingMap.set(container, { el: el, prevPos: prevPos, prevMinH: prevMinH });
}

function ocHideLoading(container) {
	if (!container) return;
	var handle = _ocLoadingMap.get(container);
	if (!handle) return;
	if (handle.el && handle.el.parentNode) handle.el.remove();
	container.style.position = handle.prevPos || '';
	if (handle.prevMinH !== undefined) {
		container.style.minHeight = handle.prevMinH;
	}
	_ocLoadingMap.delete(container);
}

// ═══ Clipboard ═══

window.ocCopyToClipboard = function(text, btnElement, successMessage, failMessage) {
	if (navigator.clipboard && navigator.clipboard.writeText) {
		navigator.clipboard.writeText(text).then(function() {
			ocShowCopySuccess(btnElement);
		}).catch(function() {
			ocFallbackCopy(text, btnElement, successMessage, failMessage);
		});
	} else {
		ocFallbackCopy(text, btnElement, successMessage, failMessage);
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

function ocFallbackCopy(text, btnElement, successMessage, failMessage) {
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


ocInitTheme();
