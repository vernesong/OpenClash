#!/usr/bin/env node

'use strict';

var assert = require('assert');
var fs = require('fs');
var path = require('path');
var vm = require('vm');

var packageRoot = process.env.OPENCLASH_PACKAGE_ROOT || path.resolve(__dirname, '..');
var css = fs.readFileSync(path.join(packageRoot,
	'root/www/luci-static/resources/openclash/css/oc.css'), 'utf8');
var commonJs = fs.readFileSync(path.join(packageRoot,
	'root/www/luci-static/resources/openclash/js/common.js'), 'utf8');

var normalizerStart = css.indexOf('/* Keep native CBI layout on other themes.');
var normalizerEnd = css.indexOf(' * SECTION 1:', normalizerStart);
assert(normalizerStart >= 0 && normalizerEnd > normalizerStart,
	'Argon CBI normalizer block must remain discoverable');

var normalizer = css.slice(normalizerStart, normalizerEnd);
assert(!normalizer.includes(':has('),
	'Argon CBI normalizer must not depend on unsupported :has() selectors');
assert(normalizer.includes('html.oc-theme-argon'),
	'Argon CBI normalizer must use the compatibility theme marker');
assert(commonJs.includes("html.classList[isArgon ? 'add' : 'remove']('oc-theme-argon')"),
	'theme marker must be removed when Argon is not active');
assert(commonJs.includes("document.documentElement.classList.contains('oc-theme-argon')"),
	'late widget observation must remain scoped to Argon');

[
	'oc-theme-argon',
	'oc-cbi-value-tabs',
	'oc-cbi-value-tab',
	'oc-standalone-editor',
	'oc-checkbox-row'
].forEach(function(marker) {
	assert(commonJs.includes(marker), 'common.js must generate .' + marker);
});

// LuCI may render MultiValue checkboxes after DOMContentLoaded. The final
// layout pass must still discover the completed widget.
function makeClassList(initial) {
	var classes = new Set(initial || []);
	return {
		add: classes.add.bind(classes),
		remove: classes.delete.bind(classes),
		contains: classes.has.bind(classes)
	};
}

var checkboxRendered = false;
var field = {
	classList: makeClassList(['cbi-value-field']),
	getElementsByClassName: function(name) {
		return name === 'cbi-checkbox' && checkboxRendered ? [{}] : [];
	}
};
var title = {
	classList: makeClassList(['cbi-value-title']),
	getElementsByClassName: function() { return []; },
	nextElementSibling: field
};
field.nextElementSibling = null;
var row = {
	classList: makeClassList(['cbi-value']),
	firstElementChild: title
};
var root = {
	getElementsByClassName: function(name) {
		return name === 'cbi-value' && checkboxRendered ? [row] : [];
	}
};
var loadHandler;
var mutationHandler;
var observedRoot;
var observedOptions;
var documentMock = {
	readyState: 'complete',
	documentElement: { classList: makeClassList() },
	getElementsByTagName: function() {
		return [{ getAttribute: function() { return '/luci-static/argon/cascade.css'; } }];
	},
	getElementById: function(id) { return id === 'cbi-openclash' ? root : null; }
};
var layoutBootstrap = commonJs.slice(0, commonJs.indexOf('// ═══ Internal helpers ═══'));
vm.runInNewContext(layoutBootstrap, {
	document: documentMock,
	window: {
		addEventListener: function(name, handler) {
			if (name === 'load') loadHandler = handler;
		},
		MutationObserver: function(handler) {
			mutationHandler = handler;
			this.observe = function(target, options) {
				observedRoot = target;
				observedOptions = options;
			};
		}
	}
});

assert(!row.classList.contains('oc-checkbox-row'),
	'fixture must not expose the checkbox before LuCI renders it');
loadHandler();
checkboxRendered = true;
assert.strictEqual(typeof mutationHandler, 'function',
	'layout initializer must observe late LuCI widget rendering');
assert.strictEqual(observedRoot, root, 'layout observer must be scoped to the CBI form');
assert(observedOptions.childList && observedOptions.subtree,
	'layout observer must include nested widget additions');
mutationHandler();
assert(row.classList.contains('oc-checkbox-row'),
	'late-rendered checkbox rows must receive the layout marker');

var updateBreakpoint = css.match(/@media \(max-width: (\d+)px\) \{\s*\.oc-update table,/);
assert(updateBreakpoint && Number(updateBreakpoint[1]) >= 991,
	'update page must stack before Argon narrows the content below 623px');

console.log('UI layout regression checks passed');
