#!/usr/bin/env node

'use strict';

var assert = require('assert');
var fs = require('fs');
var path = require('path');

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

[
	'oc-theme-argon',
	'oc-cbi-value-tabs',
	'oc-cbi-value-tab',
	'oc-standalone-editor',
	'oc-checkbox-row'
].forEach(function(marker) {
	assert(commonJs.includes(marker), 'common.js must generate .' + marker);
});

var updateBreakpoint = css.match(/@media \(max-width: (\d+)px\) \{\s*\.oc-update table,/);
assert(updateBreakpoint && Number(updateBreakpoint[1]) >= 991,
	'update page must stack before Argon narrows the content below 623px');

console.log('UI layout regression checks passed');
