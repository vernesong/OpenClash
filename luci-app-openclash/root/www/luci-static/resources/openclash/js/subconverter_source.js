// Shared by the subscription form and upload dialog; address remains the saved format.
(function(window, document) {
	'use strict';
	if (window.OpenClashSubconverterSource) return;

	var remoteFields = ['provider', 'interval', 'proxy_direct'];
	var fields = [
		['tag', '<%:Tag (Optional)%>', 'text', '<%:Leave blank by default%>'],
		['provider', '<%:Proxy Provider Name%>', 'text', '<%:Automatic if blank%>'],
		['interval', '<%:Update Interval (Seconds)%>', 'number', '<%:Default: 3600%>'],
		['proxy_direct', '<%:Proxy Provider Download Method%>', 'select']
	];
	var protocol = /^[a-z][a-z0-9+.-]*:\/\/\S+$/i;
	var remote = /^https?:\/\/\S+$/i;

	function parseSource(source) {
		var value = source, encoded = false;
		if (/^(?:%3c)?(?:tag|provider|interval|proxy_direct)(?:%3a|:)/i.test(value) &&
			!/^<?(?:tag|provider|interval|proxy_direct):[^,]*,/i.test(value)) {
			try { value = decodeURIComponent(value); encoded = true; } catch (e) { return null; }
		}
		var item = {url: '', tag: '', provider: '', interval: '', proxy_direct: '', original: source, encoded: encoded};
		var seen = {}, bracketed = false, match;
		while ((match = value.match(/^(<)?(tag|provider|interval|proxy_direct):([^,]*),(>)?/i))) {
			var key = match[2].toLowerCase();
			if (seen[key]) return null;
			seen[key] = true;
			item[key] = match[3].trim();
			bracketed = bracketed || !!match[1] || !!match[4];
			value = value.slice(match[0].length).trim();
		}
		if (bracketed && value.slice(-1) === '>') value = value.slice(0, -1).trim();
		if (!protocol.test(value)) return null;
		item.url = value;
		item.proxy_direct = item.proxy_direct.toLowerCase();
		if (item.proxy_direct === '1') item.proxy_direct = 'true';
		if (item.proxy_direct === '0') item.proxy_direct = 'false';
		if (seen.proxy_direct && !/^(true|false)$/.test(item.proxy_direct)) return null;
		if (seen.interval && (!/^\d+$/.test(item.interval) || Number(item.interval) > 2147483647)) return null;
		if (!remote.test(value) && remoteFields.some(function(key) { return !!item[key]; })) return null;
		return item;
	}

	function parseSources(value) {
		var sources = String(value || '').split(/[\r\n|]+/).map(function(source) { return source.trim(); }).filter(Boolean), items = [];
		for (var i = 0; i < sources.length; i++) {
			var item = parseSource(sources[i].trim());
			if (!item) return null;
			items.push(item);
		}
		return items;
	}

	function serialize(item) {
		if (item.original) return item.original;
		var parts = [];
		fields.forEach(function(field) {
			var key = field[0], value = item[key].trim();
			if (value && (key === 'tag' || remote.test(item.url))) parts.push(key + ':' + value);
		});
		var url = item.url.trim().replace(/\|/g, '%7C');
		// Removing the last encoded prefix must preserve the backend's single URL decode.
		if (!parts.length) return item.encoded ? item.url.trim().replace(/%/g, '%25').replace(/\|/g, '%7C') : url;
		parts.push(item.url.trim());
		return item.encoded ? encodeURIComponent(parts.join(',')) : parts.join(',');
	}

	function element(tag, className, text) {
		var node = document.createElement(tag);
		if (className) node.className = className;
		if (text) node.textContent = text;
		return node;
	}

	function init(textarea) {
		if (!textarea) return null;
		if (textarea.ocSourceEditor) return textarea.ocSourceEditor;
		textarea.classList.add('sce-raw');
		ocLoadCss('/luci-static/resources/openclash/css/subconverter-source.css?v=' + (window.ocPluginVer || ''));
		var items = [], active = false, rawMode = false, family = 'unknown';
		var root = element('div', 'oc sce-editor');
		var actions = element('div', 'sce-actions');
		var list = element('div', 'sce-list');
		var batch = element('div', 'sce-import');
		var batchInput = element('textarea', 'form-textarea');
		batchInput.rows = 4;
		batchInput.placeholder = '<%:One subscription per line; vertical bars are also supported%>';
		var message = element('div', 'sce-message');
		message.setAttribute('role', 'alert');
		root.hidden = batch.hidden = message.hidden = true;
		root.appendChild(actions);
		root.appendChild(list);
		root.appendChild(batch);
		root.appendChild(message);
		textarea.parentNode.insertBefore(root, textarea);

		function button(parent, text, handler) {
			var node = element('button', 'footer-btn', text);
			node.type = 'button';
			node.addEventListener('click', handler);
			parent.appendChild(node);
			return node;
		}

		function error(text) {
			message.textContent = text || '';
			message.hidden = !text;
			if (text) root.hidden = false;
			return !text;
		}

		function sync() {
			textarea.value = items.map(serialize).join('\n');
			textarea.dispatchEvent(new Event('input', {bubbles: true}));
		}

		function render() {
			list.textContent = '';
			items.forEach(function(item, index) {
				var card = element('div', 'sce-item');
				var row = element('div', 'sce-row');
				row.appendChild(element('span', 'sce-index', String(index + 1) + '.'));
				var url = element('input', 'form-input sce-url');
				url.type = 'text';
				url.value = item.url;
				url.placeholder = '<%:Subscription URL or Node URI%>';
				url.setAttribute('aria-label', url.placeholder + ' ' + (index + 1));
				row.appendChild(url);
				var details = element('div', 'sce-fields');
				details.hidden = true;
				var toggle = button(row, '<%:Parameters%>', function() {
					details.hidden = !details.hidden;
					toggle.setAttribute('aria-expanded', String(!details.hidden));
				});
				toggle.setAttribute('aria-expanded', 'false');
				if (items.length > 1) button(row, '<%:Remove%>', function() {
					items.splice(index, 1);
					sync();
					render();
				});
				function updateFields() {
					Array.prototype.forEach.call(details.children, function(field, i) {
						field.hidden = i > 0 && !remote.test(item.url);
					});
				}
				fields.forEach(function(field) {
					var label = element('label', 'sce-field');
					label.appendChild(element('span', '', field[1]));
					var input = element(field[2] === 'select' ? 'select' : 'input', field[2] === 'select' ? 'form-select' : 'form-input');
					if (field[2] === 'select') {
						[['', '<%:Follow Backend Settings%>'], ['true', '<%:Direct%>'], ['false', '<%:Follow Rules%>']].forEach(function(option) {
							var node = element('option', '', option[1]);
							node.value = option[0];
							input.appendChild(node);
						});
					} else {
						input.type = field[2];
						input.placeholder = field[3];
						if (field[2] === 'number') { input.min = '0'; input.max = '2147483647'; input.step = '1'; }
					}
					input.value = item[field[0]];
					input.addEventListener(field[2] === 'select' ? 'change' : 'input', function() {
						item[field[0]] = input.value;
						item.original = '';
						sync();
					});
					label.appendChild(input);
					details.appendChild(label);
				});
				url.addEventListener('input', function() {
					item.url = url.value;
					item.original = '';
					updateFields();
					sync();
				});
				updateFields();
				card.appendChild(row);
				card.appendChild(details);
				list.appendChild(card);
			});
		}

		function show() {
			active = false;
			if (!rawMode) {
				items = parseSources(textarea.value);
				if (!items) {
					rawMode = true;
					error('<%:This address contains syntax that cannot be edited safely. Continue with the original text.%>');
				} else {
					if (!items.length) items = [{url: '', tag: '', provider: '', interval: '', proxy_direct: ''}];
					active = true;
					render();
				}
			}
			root.hidden = false;
			actions.hidden = false;
			list.hidden = !active;
			textarea.hidden = active;
			add.hidden = importButton.hidden = !active;
			rawButton.textContent = active ? '<%:Raw Text%>' : '<%:Form View%>';
		}

		var rawButton = button(actions, '<%:Raw Text%>', function() {
			rawMode = active;
			batch.hidden = true;
			error('');
			show();
		});
		var add = button(actions, '<%:Add Subscription%>', function() {
			items.push({url: '', tag: '', provider: '', interval: '', proxy_direct: ''});
			sync();
			render();
			list.querySelectorAll('.sce-url')[items.length - 1].focus();
		});
		var importButton = button(actions, '<%:Batch Import%>', function() {
			batch.hidden = false;
			batchInput.focus();
		});
		batch.appendChild(batchInput);
		var batchActions = element('div', 'sce-actions');
		batch.appendChild(batchActions);
		button(batchActions, '<%:Import Subscriptions%>', function() {
			var imported = parseSources(batchInput.value);
			if (!imported || !imported.length) return error('<%:The imported text contains an unsupported or invalid subscription.%>');
			items = !textarea.value.trim() ? imported : items.concat(imported);
			batchInput.value = '';
			batch.hidden = true;
			sync();
			render();
		});
		button(batchActions, '<%:Cancel%>', function() { batch.hidden = true; });
		textarea.addEventListener('input', function() { error(''); });

		textarea.ocSourceEditor = {
			setBackend: function(next) {
				if (family !== next) error('');
				family = next;
				if (family === 'subconverter-extended') {
					if (!active) show();
				} else {
					active = false;
					root.hidden = message.hidden;
					textarea.hidden = false;
					actions.hidden = list.hidden = batch.hidden = true;
				}
			},
			validate: function() {
				var parsed = active ? items : parseSources(textarea.value);
				if (active) {
					for (var i = 0; i < items.length; i++) {
						var item = items[i];
						if (!protocol.test(item.url.trim())) return error('<%:Subscription {index} is not a valid subscription URL or node URI.%>'.replace('{index}', i + 1));
						if (/[,|\r\n\0\x7f]/.test(item.tag) || (remote.test(item.url) && /[,|\r\n\0\x7f]/.test(item.provider))) return error('<%:Subscription {index} contains an invalid prefix value.%>'.replace('{index}', i + 1));
						if (remote.test(item.url) && item.interval && (!/^\d+$/.test(item.interval) || Number(item.interval) > 2147483647)) return error('<%:Subscription {index} has an invalid update interval.%>'.replace('{index}', i + 1));
					}
				}
				if (parsed && parsed.some(function(item) {
					return family === 'disabled' ? fields.some(function(field) { return !!item[field[0]]; }) :
						family === 'subconverter' && remoteFields.some(function(key) { return !!item[key]; });
				})) return error('<%:The selected backend does not support these subscription parameters. Edit the original text or select a compatible backend.%>');
				return error('');
			},
			reset: function() {
				active = rawMode = false;
				family = 'unknown';
				items = [];
				root.hidden = batch.hidden = true;
				textarea.hidden = false;
				batchInput.value = '';
				error('');
			}
		};
		return textarea.ocSourceEditor;
	}

	window.OpenClashSubconverterSource = {init: init};
})(window, document);
