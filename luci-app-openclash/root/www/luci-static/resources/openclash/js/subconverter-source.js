(function(window, document) {
	'use strict';
	if (window.OpenClashSubconverterSource) return;

	var REMOTE_FIELDS = ['provider', 'interval', 'proxyDirect'];
	var editorSerial = 0;
	var defaults = {
		source: 'Subscription',
		url: 'Subscription URL or Node URI',
		tag: 'Tag (Optional)',
		tagPlaceholder: 'Leave blank by default',
		provider: 'Proxy Provider Name',
		providerPlaceholder: 'Automatic if blank',
		providerHint: 'When blank, the proxy provider name is generated as Provider_ plus the first 6 characters of the URL MD5.',
		interval: 'Update Interval (Seconds)',
		intervalPlaceholder: 'Default: 3600',
		proxyDirect: 'Proxy Provider Download Method',
		backendDefault: 'Follow Backend Settings',
		direct: 'Direct',
		notDirect: 'Follow Rules',
		add: 'Add Subscription',
		remove: 'Remove',
		parameters: 'Parameters',
		batch: 'Batch Import',
		batchPlaceholder: 'One subscription per line; vertical bars are also supported',
		import: 'Import Subscriptions',
		cancel: 'Cancel',
		raw: 'Raw Text',
		structured: 'Form View',
		fallback: 'This address contains syntax that cannot be edited safely. Continue with the original text.',
		empty: 'Please enter at least one subscription URL or node URI.',
		invalidUrl: 'Subscription {index} is not a valid subscription URL or node URI.',
		invalidText: 'Subscription {index} contains an invalid prefix value.',
		invalidInterval: 'Subscription {index} has an invalid update interval.',
		invalidImport: 'The imported text contains an unsupported or invalid subscription.'
	};

	function $(target) {
		if (!target) return null;
		if (typeof target === 'string') return document.querySelector(target);
		return target;
	}

	function extend(base, extra) {
		var result = {};
		var key;
		for (key in base) result[key] = base[key];
		extra = extra || {};
		for (key in extra) result[key] = extra[key];
		return result;
	}

	function format(message, index) {
		return String(message || '').replace('{index}', String(index + 1));
	}

	function splitSources(value) {
		var lines = String(value || '').replace(/\r\n?/g, '\n').split('\n');
		var result = [];
		lines.forEach(function(line) {
			line.split('|').forEach(function(item) {
				item = item.trim();
				if (item) result.push(item);
			});
		});
		return result;
	}

	function isProtocolSource(value) {
		return /^[a-z][a-z0-9+.-]*:\/\/\S+$/i.test(String(value || '').trim());
	}

	function isRemoteSource(value) {
		value = String(value || '').trim();
		return !value || /^https?:\/\/\S+$/i.test(value);
	}

	function maybeDecodePrefixedSource(value) {
		if (/^<?(?:tag|provider|interval|proxy_direct):[^,]*,/i.test(value) ||
			!/^(?:%3c)?(?:tag|provider|interval|proxy_direct)(?:%3a|:)/i.test(value)) {
			return { value: value, encoded: false };
		}
		try {
			return { value: decodeURIComponent(value), encoded: true };
		} catch (e) {
			return { value: value, encoded: false };
		}
	}

	function parseSource(value) {
		var original = String(value || '').trim();
		var decoded = maybeDecodePrefixedSource(original);
		var remainder = decoded.value.trim();
		var item = {
			url: '',
			tag: '',
			provider: '',
			interval: '',
			proxyDirect: '',
			encoded: decoded.encoded,
			original: original,
			dirty: false
		};
		var seen = {};
		var parsed = false;
		var bracketed = false;

		while (remainder) {
			var match = remainder.match(/^(<)?(tag|provider|interval|proxy_direct):([^,]*),(>)?/i);
			if (!match) break;
			var token = match[2].toLowerCase();
			var key = token === 'proxy_direct' ? 'proxyDirect' : token;
			if (seen[key]) return null;
			seen[key] = true;
			item[key] = match[3].trim();
			parsed = true;
			bracketed = bracketed || !!match[1] || !!match[4];
			remainder = remainder.slice(match[0].length).trim();
		}

		if (bracketed && remainder.charAt(remainder.length - 1) === '>') {
			remainder = remainder.slice(0, -1).trim();
		}
		if (!parsed) remainder = original;
		if (!isProtocolSource(remainder)) return null;
		if (!isRemoteSource(remainder) && REMOTE_FIELDS.some(function(key) { return !!item[key]; })) return null;

		item.proxyDirect = item.proxyDirect.toLowerCase();
		if (item.proxyDirect === '1') item.proxyDirect = 'true';
		if (item.proxyDirect === '0') item.proxyDirect = 'false';
		if (item.proxyDirect && item.proxyDirect !== 'true' && item.proxyDirect !== 'false') return null;
		if (item.interval && (!/^\d+$/.test(item.interval) || Number(item.interval) > 2147483647)) return null;

		item.url = remainder;
		return item;
	}

	function parseSources(value, allowEmpty) {
		var sources = splitSources(value);
		if (!sources.length) {
			return allowEmpty ? [{
				url: '', tag: '', provider: '', interval: '', proxyDirect: '', original: '', dirty: true
			}] : [];
		}
		var items = [];
		for (var i = 0; i < sources.length; i++) {
			var parsed = parseSource(sources[i]);
			if (!parsed) return null;
			items.push(parsed);
		}
		return items;
	}

	function validPrefixText(value) {
		return !/[,|\r\n\0\x7f]/.test(String(value || ''));
	}

	function serializeSource(item) {
		if (!item.dirty && item.original) return item.original;
		var parts = [];
		var remote = isRemoteSource(item.url);
		if (item.tag.trim()) parts.push('tag:' + item.tag.trim());
		if (remote && item.provider.trim()) parts.push('provider:' + item.provider.trim());
		if (remote && item.interval.trim()) parts.push('interval:' + item.interval.trim());
		if (remote && item.proxyDirect) parts.push('proxy_direct:' + item.proxyDirect);
		if (!parts.length) {
			// SCE decodes unprefixed URLs once; keep the effective URL unchanged.
			return item.encoded
				? item.url.trim().replace(/%/g, '%25').replace(/\|/g, '%7C')
				: plainUrl(item);
		}
		parts.push(item.url.trim());
		var source = parts.join(',');
		return item.encoded ? encodeURIComponent(source) : source;
	}

	function serializeSources(items) {
		return items.map(serializeSource).join('\n');
	}

	function plainUrl(item) {
		return item.url.trim().replace(/\|/g, '%7C');
	}

	function plainSources(items) {
		return items.map(plainUrl).filter(Boolean).join('\n');
	}

	function legacySources(items) {
		return items.map(function(item) {
			var url = plainUrl(item);
			if (!url) return '';
			var tag = item.tag.trim();
			return tag ? 'tag:' + tag + ',' + url : url;
		}).filter(Boolean).join('\n');
	}

	function createElement(tag, className, text) {
		var element = document.createElement(tag);
		if (className) element.className = className;
		if (typeof text !== 'undefined') element.textContent = text;
		return element;
	}

	function init(options) {
		options = options || {};
		var textarea = $(options.textarea);
		var labels = extend(defaults, options.labels);
		var onChange = typeof options.onChange === 'function' ? options.onChange : function() {};
		var items = [];
		var active = false;
		var rawMode = false;
		var rawMessage = '';
		var programmatic = false;
		var preservedItems = null;
		var preservedPlain = '';
		var expandedDetails = null;
		var expandedButton = null;

		if (!textarea) return null;
		var editorId = ++editorSerial;
		textarea.classList.add('subconverter-source-raw');

		var root = createElement('div', 'oc subconverter-source-editor');
		root.hidden = true;
		var list = createElement('div', 'subconverter-source-list');
		var actions = createElement('div', 'subconverter-source-actions');
		var addButton = createElement('button', 'btn cbi-button cbi-button-action', labels.add);
		addButton.type = 'button';
		var batchButton = createElement('button', 'btn cbi-button cbi-button-action', labels.batch);
		batchButton.type = 'button';
		var rawButton = createElement('button', 'btn cbi-button cbi-button-action', labels.raw);
		rawButton.type = 'button';
		actions.appendChild(rawButton);
		actions.appendChild(addButton);
		actions.appendChild(batchButton);

		var batchPanel = createElement('div', 'subconverter-source-import');
		batchPanel.hidden = true;
		var batchInput = createElement('textarea', 'cbi-input-textarea');
		batchInput.rows = 4;
		batchInput.placeholder = labels.batchPlaceholder;
		var importActions = createElement('div', 'subconverter-source-actions');
		var importButton = createElement('button', 'btn cbi-button cbi-button-apply', labels.import);
		importButton.type = 'button';
		var cancelButton = createElement('button', 'btn cbi-button cbi-button-neutral', labels.cancel);
		cancelButton.type = 'button';
		importActions.appendChild(importButton);
		importActions.appendChild(cancelButton);
		batchPanel.appendChild(batchInput);
		batchPanel.appendChild(importActions);

		var message = createElement('div', 'subconverter-source-message');
		message.hidden = true;
		root.appendChild(actions);
		root.appendChild(list);
		root.appendChild(batchPanel);
		root.appendChild(message);
		textarea.parentNode.insertBefore(root, textarea);

		function setMessage(text, fallback) {
			message.textContent = text || '';
			message.hidden = !text;
			message.classList.toggle('is-fallback', !!fallback);
		}

		function setTextarea(value) {
			programmatic = true;
			textarea.value = value;
			programmatic = false;
			onChange(value);
		}

		function markDirty(item) {
			item.dirty = true;
			item.original = '';
			preservedItems = null;
			preservedPlain = '';
			setMessage('');
			setTextarea(serializeSources(items));
		}

		function makeField(label, value, type, onInput, placeholder, title) {
			var field = createElement('label', 'subconverter-source-field');
			field.appendChild(createElement('span', '', label));
			var input;
			if (type === 'select') {
				input = document.createElement('select');
				[
					['', labels.backendDefault],
					['true', labels.direct],
					['false', labels.notDirect]
				].forEach(function(option) {
					var node = createElement('option', '', option[1]);
					node.value = option[0];
					input.appendChild(node);
				});
			} else {
				input = document.createElement('input');
				input.type = type || 'text';
				if (type === 'number') {
					input.min = '0';
					input.max = '2147483647';
					input.step = '1';
				}
				if (placeholder) input.placeholder = placeholder;
			}
			if (title) input.title = title;
			input.value = value || '';
			input.addEventListener(type === 'select' ? 'change' : 'input', function() { onInput(input.value); });
			field.appendChild(input);
			return { field: field, input: input };
		}

		function render() {
			list.textContent = '';
			expandedDetails = null;
			expandedButton = null;
			items.forEach(function(item, index) {
				var card = createElement('div', 'subconverter-source-item');
				var row = createElement('div', 'subconverter-source-row');
				row.appendChild(createElement('span', 'subconverter-source-index', String(index + 1) + '.'));

				var urlInput = createElement('input', 'subconverter-source-url');
				urlInput.type = 'text';
				urlInput.value = item.url;
				urlInput.placeholder = labels.url;
				urlInput.setAttribute('aria-label', labels.url + ' ' + (index + 1));
				urlInput.addEventListener('input', function() {
					item.url = urlInput.value;
					markDirty(item);
					updateRemoteFields();
					updateParametersButton();
				});
				row.appendChild(urlInput);

				var rowActions = createElement('div', 'subconverter-source-row-actions');
				var parametersButton = createElement('button', 'btn cbi-button cbi-button-neutral', labels.parameters);
				parametersButton.type = 'button';
				parametersButton.setAttribute('aria-expanded', 'false');
				rowActions.appendChild(parametersButton);
				if (items.length > 1) {
					var removeButton = createElement('button', 'btn cbi-button cbi-button-remove', labels.remove);
					removeButton.type = 'button';
					removeButton.setAttribute('aria-label', labels.remove + ' ' + labels.source + ' ' + (index + 1));
					removeButton.addEventListener('click', function() {
						items.splice(index, 1);
						preservedItems = null;
						setTextarea(serializeSources(items));
						render();
					});
					rowActions.appendChild(removeButton);
				}
				row.appendChild(rowActions);
				card.appendChild(row);

				var details = createElement('div', 'subconverter-source-details');
				details.id = 'subconverter-source-details-' + editorId + '-' + index;
				details.hidden = true;
				parametersButton.setAttribute('aria-controls', details.id);
				var remoteFields = [];
				function updateRemoteFields() {
					var hidden = !isRemoteSource(item.url);
					remoteFields.forEach(function(field) { field.hidden = hidden; });
				}
				function updateParametersButton() {
					var count = item.tag.trim() ? 1 : 0;
					if (isRemoteSource(item.url)) {
						if (item.provider.trim()) count++;
						if (item.interval.trim()) count++;
						if (item.proxyDirect) count++;
					}
					parametersButton.textContent = labels.parameters + (count ? ' (' + count + ')' : '');
				}

				var grid = createElement('div', 'subconverter-source-grid');
				grid.appendChild(makeField(labels.tag, item.tag, 'text', function(value) {
					item.tag = value;
					markDirty(item);
					updateParametersButton();
				}, labels.tagPlaceholder).field);
				remoteFields.push(makeField(labels.provider, item.provider, 'text', function(value) {
					item.provider = value;
					markDirty(item);
					updateParametersButton();
				}, labels.providerPlaceholder, labels.providerHint).field);
				remoteFields.push(makeField(labels.interval, item.interval, 'number', function(value) {
					item.interval = value;
					markDirty(item);
					updateParametersButton();
				}, labels.intervalPlaceholder).field);
				remoteFields.push(makeField(labels.proxyDirect, item.proxyDirect, 'select', function(value) {
					item.proxyDirect = value;
					markDirty(item);
					updateParametersButton();
				}).field);
				remoteFields.forEach(function(field) { grid.appendChild(field); });
				updateRemoteFields();
				updateParametersButton();
				details.appendChild(grid);
				card.appendChild(details);
				parametersButton.addEventListener('click', function() {
					var expanding = details.hidden;
					if (expandedDetails && expandedDetails !== details) {
						expandedDetails.hidden = true;
						expandedDetails.parentNode.classList.remove('is-expanded');
						expandedButton.setAttribute('aria-expanded', 'false');
					}
					details.hidden = !expanding;
					card.classList.toggle('is-expanded', expanding);
					parametersButton.setAttribute('aria-expanded', String(expanding));
					expandedDetails = expanding ? details : null;
					expandedButton = expanding ? parametersButton : null;
				});
				list.appendChild(card);
			});
		}

		function validate() {
			setMessage('');
			if (!active) return true;
			if (!items.length) {
				setMessage(labels.empty);
				return false;
			}
			for (var i = 0; i < items.length; i++) {
				var item = items[i];
				if (!isProtocolSource(item.url)) {
					setMessage(format(labels.invalidUrl, i));
					return false;
				}
				if (!validPrefixText(item.tag) || !validPrefixText(item.provider)) {
					setMessage(format(labels.invalidText, i));
					return false;
				}
				if (item.interval && (!/^\d+$/.test(item.interval) || Number(item.interval) > 2147483647)) {
					setMessage(format(labels.invalidInterval, i));
					return false;
				}
			}
			setTextarea(serializeSources(items));
			return true;
		}

		function showRaw(messageText, fallback) {
			active = false;
			rawMode = true;
			rawMessage = messageText || '';
			root.classList.add('is-raw');
			textarea.hidden = false;
			root.hidden = false;
			list.hidden = true;
			actions.hidden = false;
			addButton.hidden = true;
			batchButton.hidden = true;
			batchPanel.hidden = true;
			rawButton.textContent = labels.structured;
			setMessage(rawMessage, !!fallback);
		}

		function showFallback() {
			showRaw(labels.fallback, true);
		}

		function activate(parsed) {
			var parentStyle = window.getComputedStyle(textarea.parentNode);
			var gap = /flex|grid/.test(parentStyle.display) ? parseFloat(parentStyle.rowGap) || 0 : 0;
			list.style.marginTop = gap + 'px';
			items = parsed;
			active = true;
			rawMode = false;
			rawMessage = '';
			root.classList.remove('is-raw');
			textarea.hidden = true;
			root.hidden = false;
			list.hidden = false;
			actions.hidden = false;
			addButton.hidden = false;
			batchButton.hidden = false;
			rawButton.textContent = labels.raw;
			setMessage('');
			render();
		}

		function setExtended(enabled) {
			if (!enabled) {
				active = false;
				root.hidden = true;
				textarea.hidden = false;
				return;
			}
			if (rawMode) {
				showRaw(rawMessage, message.classList.contains('is-fallback'));
				return;
			}
			if (active) return;

			if (preservedItems && textarea.value.trim() === preservedPlain) {
				items = preservedItems;
				setTextarea(serializeSources(items));
				preservedItems = null;
				preservedPlain = '';
				activate(items);
				return;
			}

			var parsed = parseSources(textarea.value, true);
			if (!parsed) {
				showFallback();
				return;
			}
			activate(parsed);
		}

		function prepareForBackend(serializer) {
			var parsed = !active && preservedItems && textarea.value.trim() === preservedPlain
				? preservedItems
				: (active ? items : parseSources(textarea.value, true));
			if (parsed) {
				preservedItems = parsed;
				preservedPlain = serializer(parsed);
				setTextarea(preservedPlain);
			}
			setExtended(false);
		}

		function preparePlain() {
			prepareForBackend(plainSources);
		}

		function prepareLegacy() {
			prepareForBackend(legacySources);
		}

		addButton.addEventListener('click', function() {
			items.push({url: '', tag: '', provider: '', interval: '', proxyDirect: '', original: '', dirty: true});
			setTextarea(serializeSources(items));
			render();
			var inputs = list.querySelectorAll('.subconverter-source-url');
			if (inputs.length) inputs[inputs.length - 1].focus();
		});
		batchButton.addEventListener('click', function() {
			batchPanel.hidden = false;
			batchInput.focus();
		});
		cancelButton.addEventListener('click', function() {
			batchInput.value = '';
			batchPanel.hidden = true;
		});
		rawButton.addEventListener('click', function() {
			if (!rawMode) {
				showRaw('', false);
				return;
			}
			var parsed = parseSources(textarea.value, true);
			if (!parsed) {
				showFallback();
				return;
			}
			activate(parsed);
		});
		importButton.addEventListener('click', function() {
			var imported = parseSources(batchInput.value, false);
			if (!imported || !imported.length) {
				setMessage(labels.invalidImport);
				return;
			}
			var onlyBlank = items.length === 1 && !items[0].url && !items[0].tag && !items[0].provider && !items[0].interval && !items[0].proxyDirect;
			items = onlyBlank ? imported : items.concat(imported);
			batchInput.value = '';
			batchPanel.hidden = true;
			preservedItems = null;
			setTextarea(serializeSources(items));
			render();
		});
		textarea.addEventListener('input', function() {
			if (!programmatic && !active) {
				preservedItems = null;
				preservedPlain = '';
			}
		});

		return {
			setExtended: setExtended,
			preparePlain: preparePlain,
			prepareLegacy: prepareLegacy,
			validate: validate,
			isActive: function() { return active; },
			reset: function() {
				active = false;
				rawMode = false;
				rawMessage = '';
				items = [];
				preservedItems = null;
				preservedPlain = '';
				batchInput.value = '';
				batchPanel.hidden = true;
				root.hidden = true;
				textarea.hidden = false;
				setMessage('');
			}
		};
	}

	window.OpenClashSubconverterSource = {
		init: init,
		parseSource: parseSource,
		parseSources: parseSources,
		serializeSource: serializeSource,
		serializeSources: serializeSources
	};
})(window, document);
