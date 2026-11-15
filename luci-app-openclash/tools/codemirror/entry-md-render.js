// ============================================================
// OpenClash markdown preview renderer — marked + highlight.js
// Lazy-loaded by CM6.ensureMarkdown(); exposes window.OCMarkdown.
// Build: npx esbuild tools/codemirror/entry-md-render.js --bundle --format=iife --global-name=OCMarkdown --minify --target=es2019 --outfile=root/www/luci-static/resources/openclash/js/md-render.min.js --legal-comments=none --loader:.css=text
// ============================================================

import { Marked, marked } from "marked"
import hljs from "highlight.js/lib/core"
import yamlLang from "highlight.js/lib/languages/yaml"
import bashLang from "highlight.js/lib/languages/bash"
import jsonLang from "highlight.js/lib/languages/json"
import githubLightCSS from "highlight.js/styles/github.css"
import githubDarkCSS from "highlight.js/styles/github-dark-dimmed.css"

function ocIsDark() {
    return document.documentElement.getAttribute('data-darkmode') === 'true';
}

var ocHljsReady = false;
function ocEnsureHljs() {
    if (ocHljsReady) return;
    ocHljsReady = true;
    hljs.registerLanguage("yaml", yamlLang);
    hljs.registerLanguage("yml", yamlLang);
    hljs.registerLanguage("bash", bashLang);
    hljs.registerLanguage("sh", bashLang);
    hljs.registerLanguage("shell", bashLang);
    hljs.registerLanguage("json", jsonLang);
}

var hljsCSSInjected = false
function injectHljsCSS() {
    if (hljsCSSInjected) return
    hljsCSSInjected = true
    ocEnsureHljs();
    var isDark = ocIsDark()
    var style = document.createElement("style")
    style.id = "hljs-theme"
    style.textContent = isDark ? githubDarkCSS : githubLightCSS
    document.head.appendChild(style)
}

function switchHljsTheme(isDark) {
    if (!hljsCSSInjected) { injectHljsCSS(); if (!hljsCSSInjected) return }
    var style = document.getElementById("hljs-theme")
    if (style) style.textContent = isDark ? githubDarkCSS : githubLightCSS
}

function escapeHtml(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;")
}

var ocMarkedReady = false;
function ocEnsureMarked() {
    if (ocMarkedReady) return;
    ocMarkedReady = true;
    ocEnsureHljs();
    marked.use({
        breaks: true,
        gfm: true,
        silent: true,
        renderer: {
            code: function(token) {
                var lang = token.lang || ""
                if (lang && hljs.getLanguage(lang)) {
                    injectHljsCSS()
                    var result = hljs.highlight(token.text, { language: lang, ignoreIllegals: true })
                    return '<pre><code class="hljs language-' + lang + '"><span class="code-content">' + result.value + '</span></code></pre>'
                }
                return '<pre><code><span class="code-content">' + escapeHtml(token.text) + '</span></code></pre>'
            }
        }
    })
}

function renderMarkdown(text) {
    if (!text) return ''
    ocEnsureMarked();
    try { return marked.parse(text) } catch(e) { return text }
}

function isWebURL(href) {
    try {
        const url = new URL(href);
        return (url.protocol === 'https:' || url.protocol === 'http:') && Boolean(url.hostname);
    } catch {
        return false;
    }
}

const announcementMarkdown = new Marked({
    breaks: true,
    gfm: true,
    renderer: {
        html({ text }) { return escapeHtml(text); },
        link(token) {
            return isWebURL(token.href) ? false : this.parser.parseInline(token.tokens);
        },
        image(token) {
            return isWebURL(token.href) ? false : escapeHtml(token.text);
        }
    }
});

function announcementContent(announcement) {
    const format = announcement && announcement.content_format;
    if (format == null || typeof announcement.content !== 'string' || !announcement.content.trim()) return null;
    const kind = typeof format === 'string' ? format.trim().toLowerCase() : 'text';
    if (kind === 'html') return null;
    const template = document.createElement('template');
    if (kind === 'markdown') {
        template.innerHTML = announcementMarkdown.parse(announcement.content);
    } else {
        const text = document.createElement('div');
        text.style.whiteSpace = 'pre-wrap';
        text.textContent = announcement.content;
        template.content.appendChild(text);
    }
    return template.content;
}

export {
    announcementContent,
    renderMarkdown,
    switchHljsTheme
}
