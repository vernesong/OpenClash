(function(window, document) {
	'use strict';

	var cache = {};
	var defaultLabels = {
		checking: 'Checking backend version...',
		versionPrefix: 'Backend Version',
		empty: 'Please enter backend URL',
		invalid: 'Invalid backend URL',
		unrecognized: 'Backend version information not detected',
		failed: 'Unable to detect backend version'
	};

	function $(target) {
		if (!target) return null;
		if (typeof target === 'string') return document.querySelector(target);
		return target;
	}

	function isElement(target) {
		return target && target.nodeType === 1;
	}

	function extend(base, extra) {
		var result = {};
		var key;
		for (key in base) result[key] = base[key];
		extra = extra || {};
		for (key in extra) result[key] = extra[key];
		return result;
	}

	function normalizeBackendURL(value) {
		value = String(value || '').trim();
		if (!value) return { error: 'empty' };

		if (!/^[a-z][a-z0-9+\-.]*:\/\//i.test(value)) {
			value = 'https://' + value;
		}

		try {
			var url = new URL(value);
			if (url.protocol !== 'http:' && url.protocol !== 'https:') {
				return { error: 'invalid' };
			}
			var versionURLs = buildVersionURLs(url);
			return {
				base: url.origin,
				versionURL: versionURLs[0],
				versionURLs: versionURLs
			};
		} catch (e) {
			return { error: 'invalid' };
		}
	}

	function addUniqueURL(list, value) {
		if (list.indexOf(value) === -1) list.push(value);
	}

	function buildVersionURLs(url) {
		var versionURLs = [];
		var path = (url.pathname || '').replace(/\/+$/, '');
		var pathBase;

		if (path && path !== '/') {
			pathBase = path.replace(/\/sub$/i, '');
			if (pathBase) addUniqueURL(versionURLs, url.origin + pathBase + '/version');
		}

		addUniqueURL(versionURLs, url.origin + '/version');
		return versionURLs;
	}

	function readElementValue(element) {
		var selected;
		var hidden;

		if (!element) return '';
		if (element.classList && element.classList.contains('cbi-dropdown')) {
			if (typeof element.value !== 'undefined' && element.value !== null) return element.value;
			selected = element.querySelector('li[selected][data-value]');
			if (selected) return selected.getAttribute('data-value') || '';
			hidden = element.querySelector('input[type="hidden"]');
			return hidden ? hidden.value : '';
		}
		return element.value || '';
	}

	function getSelectedBackend(selectEl, customInputEl) {
		if (!selectEl) return '';
		if (readElementValue(selectEl) === 'custom') {
			return readElementValue(customInputEl);
		}
		return readElementValue(selectEl);
	}

	function renderStatus(statusEl, state, message, labels) {
		if (!statusEl) return;

		statusEl.hidden = false;
		statusEl.setAttribute('data-state', state);

		var labelEl = statusEl.querySelector('.subconverter-version-label');
		var textEl = statusEl.querySelector('.subconverter-version-text');
		var showLabel = state === 'success';

		if (labelEl) {
			labelEl.textContent = showLabel ? labels.versionPrefix + ':' : '';
			labelEl.style.display = showLabel ? '' : 'none';
		}

		if (textEl) textEl.textContent = message || '';
		else statusEl.textContent = message || '';
	}

	function hideStatus(statusEl) {
		if (!statusEl) return;
		statusEl.hidden = true;
		statusEl.setAttribute('data-state', 'idle');
	}

	function sanitizeVersionText(text) {
		text = String(text || '').replace(/\r/g, '\n').split('\n').map(function(line) {
			return line.trim();
		}).filter(Boolean).join(' ');
		text = text.replace(/\s+/g, ' ').trim();

		if (!text) return '';
		if (/<\s*\/?\s*[a-z!][^>]*>/i.test(text)) return '';
		if (text.length > 220) return '';
		if (!/(subconverter|backend|\bversion\b|v?\d+(?:\.\d+){1,})/i.test(text)) return '';

		return text;
	}

	function fetchDirectVersion(versionURL, timeoutMs, signal) {
		var controller = typeof AbortController !== 'undefined' ? new AbortController() : null;
		var timeoutId;

		if (controller && signal) {
			if (signal.aborted) controller.abort();
			else signal.addEventListener('abort', function() {
				controller.abort();
			}, { once: true });
		}

		if (controller && timeoutMs > 0) {
			timeoutId = window.setTimeout(function() {
				controller.abort();
			}, timeoutMs);
		}

		return fetch(versionURL, {
			method: 'GET',
			mode: 'cors',
			credentials: 'omit',
			cache: 'no-store',
			referrerPolicy: 'no-referrer',
			headers: {
				'Accept': 'text/plain, */*'
			},
			signal: controller ? controller.signal : undefined
		}).then(function(response) {
			if (!response.ok) {
				throw new Error('HTTP ' + response.status);
			}
			return response.text();
		}).then(function(text) {
			if (timeoutId) window.clearTimeout(timeoutId);
			var version = sanitizeVersionText(text);
			if (!version) return { state: 'unrecognized', text: '' };
			return { state: 'success', text: version };
		}).catch(function(error) {
			if (timeoutId) window.clearTimeout(timeoutId);
			if (signal && signal.aborted) return { state: 'aborted', text: '' };
			throw error;
		});
	}

	function fetchProxiedVersion(versionURL, proxyURL, timeoutMs, signal) {
		if (!proxyURL) return Promise.reject(new Error('Proxy endpoint unavailable'));

		var controller = typeof AbortController !== 'undefined' ? new AbortController() : null;
		var timeoutId;
		var separator = proxyURL.indexOf('?') === -1 ? '?' : '&';

		if (controller && signal) {
			if (signal.aborted) controller.abort();
			else signal.addEventListener('abort', function() {
				controller.abort();
			}, { once: true });
		}

		if (controller && timeoutMs > 0) {
			timeoutId = window.setTimeout(function() {
				controller.abort();
			}, timeoutMs);
		}

		return fetch(proxyURL + separator + 'url=' + encodeURIComponent(versionURL), {
			method: 'GET',
			credentials: 'same-origin',
			cache: 'no-store',
			headers: {
				'Accept': 'application/json'
			},
			signal: controller ? controller.signal : undefined
		}).then(function(response) {
			if (!response.ok) throw new Error('HTTP ' + response.status);
			return response.json();
		}).then(function(data) {
			if (timeoutId) window.clearTimeout(timeoutId);
			if (data && data.status === 'success') {
				var version = sanitizeVersionText(data.version || '');
				if (version) return { state: 'success', text: version };
			}
			if (data && data.status === 'unrecognized') return { state: 'unrecognized', text: '' };
			throw new Error((data && data.message) || 'Proxy request failed');
		}).catch(function(error) {
			if (timeoutId) window.clearTimeout(timeoutId);
			if (signal && signal.aborted) return { state: 'aborted', text: '' };
			throw error;
		});
	}

	function fetchVersion(versionURL, timeoutMs, signal, proxyURL) {
		return fetchDirectVersion(versionURL, timeoutMs, signal).catch(function(error) {
			if (signal && signal.aborted) return { state: 'aborted', text: '' };
			if (!proxyURL) throw error;
			return fetchProxiedVersion(versionURL, proxyURL, timeoutMs, signal);
		});
	}

	function fetchVersionCandidates(versionURLs, timeoutMs, signal, proxyURL) {
		var index = 0;
		var sawUnrecognized = false;

		function next() {
			if (signal && signal.aborted) return Promise.resolve({ state: 'aborted', text: '' });

			return fetchVersion(versionURLs[index++], timeoutMs, signal, proxyURL).then(function(result) {
				if (result.state === 'success' || result.state === 'aborted') return result;
				sawUnrecognized = true;
				if (index < versionURLs.length) return next();
				return result;
			}).catch(function(error) {
				if (signal && signal.aborted) return { state: 'aborted', text: '' };
				if (index < versionURLs.length) return next();
				if (sawUnrecognized) return { state: 'unrecognized', text: '' };
				throw error;
			});
		}

		return next();
	}

	function init(options) {
		options = options || {};
		var selectTarget = options.select;
		var customInputTarget = options.customInput;
		var enableTarget = options.enable;
		var selectEl = $(selectTarget);
		var customInputEl = $(customInputTarget);
		var enableEl = $(enableTarget);
		var statusEl = $(options.status);
		var labels = extend(defaultLabels, options.labels);
		var debounceMs = typeof options.debounceMs === 'number' ? options.debounceMs : 500;
		var timeoutMs = typeof options.timeoutMs === 'number' ? options.timeoutMs : 6000;
		var cacheMs = typeof options.cacheMs === 'number' ? options.cacheMs : 60000;
		var proxyURL = options.proxyURL || '';
		var debounceTimer = null;
		var activeController = null;
		var requestId = 0;

		if (!selectEl || !statusEl) {
			return {
				update: function() {},
				hide: function() {}
			};
		}

		function refreshTargets() {
			selectEl = $(selectTarget);
			customInputEl = $(customInputTarget);
			enableEl = $(enableTarget);
		}

		function enabled() {
			refreshTargets();
			return !enableEl || !!enableEl.checked;
		}

		function run() {
			window.clearTimeout(debounceTimer);
			refreshTargets();

			if (!enabled()) {
				hideStatus(statusEl);
				return;
			}

			var selected = getSelectedBackend(selectEl, customInputEl);
			var normalized = normalizeBackendURL(selected);

			if (normalized.error === 'empty') {
				renderStatus(statusEl, 'empty', labels.empty, labels);
				return;
			}

			if (normalized.error === 'invalid') {
				renderStatus(statusEl, 'error', labels.invalid, labels);
				return;
			}

			var now = Date.now();
			var cacheKey = normalized.versionURLs.join('|');
			var cached = cache[cacheKey];
			if (cached && now - cached.time < cacheMs) {
				renderStatus(statusEl, cached.state, cached.message, labels);
				return;
			}

			if (activeController) activeController.abort();
			activeController = typeof AbortController !== 'undefined' ? new AbortController() : null;
			var currentRequestId = ++requestId;

			renderStatus(statusEl, 'checking', labels.checking, labels);

			fetchVersionCandidates(normalized.versionURLs, timeoutMs, activeController ? activeController.signal : null, proxyURL).then(function(result) {
				if (currentRequestId !== requestId || result.state === 'aborted') return;

				var state = result.state;
				var message = state === 'success' ? result.text : labels.unrecognized;

				cache[cacheKey] = {
					time: Date.now(),
					state: state,
					message: message
				};
				renderStatus(statusEl, state, message, labels);
			}).catch(function() {
				if (currentRequestId !== requestId) return;
				renderStatus(statusEl, 'error', labels.failed, labels);
			});
		}

		function schedule() {
			window.clearTimeout(debounceTimer);
			debounceTimer = window.setTimeout(run, debounceMs);
		}

		selectEl.addEventListener('change', run);
		selectEl.addEventListener('input', schedule);
		if (customInputEl) {
			customInputEl.addEventListener('input', schedule);
			customInputEl.addEventListener('change', run);
		}
		if (enableEl) enableEl.addEventListener('change', run);
		if (options.watchDocument) {
			document.addEventListener('change', run, true);
			document.addEventListener('input', schedule, true);
			document.addEventListener('click', schedule, true);
		}
		var watchRootEl = $(options.watchRoot);
		if (isElement(watchRootEl)) {
			watchRootEl.addEventListener('change', run, true);
			watchRootEl.addEventListener('input', schedule, true);
			watchRootEl.addEventListener('click', schedule, true);
		}

		run();

		return {
			update: run,
			schedule: schedule,
			hide: function() {
				if (activeController) activeController.abort();
				hideStatus(statusEl);
			}
		};
	}

	window.OpenClashSubconverterVersion = {
		init: init,
		normalizeBackendURL: normalizeBackendURL
	};
})(window, document);
