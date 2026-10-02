// ============================================================
// YAML lint worker — parses the document off the main thread
// (entry.js keeps only the diagnostic position mapping).
// Build (from tools/codemirror):
//   npx esbuild entry-lint-worker.js --bundle --format=iife --minify --target=es2019 --outfile=../../root/www/luci-static/resources/openclash/js/lint-worker.min.js --legal-comments=none
// ============================================================

import { loadAll, YAML11_SCHEMA } from "js-yaml"

self.onmessage = function (e) {
    var data = e.data || {}
    var error = null
    try {
        loadAll(data.text, { schema: YAML11_SCHEMA })
    } catch (err) {
        var mark = err.mark
        error = {
            line: mark && mark.line !== undefined ? mark.line : null,
            column: mark && mark.column !== undefined ? mark.column : 0,
            message: err.reason || err.message
        }
    }
    self.postMessage({ id: data.id, error: error })
}
