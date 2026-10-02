// Extracted from luasrc/view/openclash/config_editor.htm - edit this file, not the template.
// <%:Message%> markers and <%=...%> islands are compiled server-side by the "openclash/translate_js" controller action.

// All editable editors use EditorView.updateListener (not view.dispatch)
// to sync content back to the hidden textarea.  The dispatch override is
// unreliable because CM6 can pass either a Transaction (with docChanged)
// or a TransactionSpec (without docChanged) to dispatch().

// Streamed viewers replace their whole document on every update; dispatching
// a minimal edit keeps that proportional to what actually changed.
function ocDiffSetValue(view, value) {
    value = value || '';
    var old = view.state.doc.toString();
    if (old === value) return;
    var oldLen = old.length, newLen = value.length;
    var prefix = 0, suffix = 0;
    while (prefix < oldLen && prefix < newLen && old.charCodeAt(prefix) === value.charCodeAt(prefix)) prefix++;
    while (suffix < oldLen - prefix && suffix < newLen - prefix && old.charCodeAt(oldLen - 1 - suffix) === value.charCodeAt(newLen - 1 - suffix)) suffix++;
    view.dispatch({ changes: { from: prefix, to: oldLen - suffix, insert: value.slice(prefix, newLen - suffix) } });
}

function editor(id, readOnly, wid, height) {
    id.style.display = 'none';
    id.parentNode.classList.add('oc');
    ocShowLoading(id.parentNode, '<%:Loading...%>', height);
    ocQueueEditor(id.parentNode, function() {
        var isDark = isDarkBackground(document.body);
        var exts = [CM6.baseExtensions(), CM6.themeExtension(isDark), CM6.placeholderExtension('<%:Enter YAML configuration...%>')];
        var topSearch = (CM6 && CM6.topSearchExtension) ? CM6.topSearchExtension() : null;
        if (topSearch) exts.push(topSearch);
        exts.push(CM6.yaml());
        exts.push(CM6.yamlLinter());
        exts.push(CM6.lintGutter());
        exts.push(CM6.autocompletion({ override: [CM6.mihomoCompletion] }));
        exts.push(CM6.indentUnit.of("  "));
        exts.push(CM6.indentMarkerExtension());
        if (readOnly) exts.push(CM6.EditorState.readOnly.of(true));

        exts.push(CM6.EditorView.updateListener.of(function(update) {
            if (update.docChanged) id.value = update.state.doc.toString();
        }));

        var view = new CM6.EditorView({
            state: CM6.EditorState.create({ doc: id.value, extensions: exts })
        });
        id.parentNode.insertBefore(view.dom, id.nextSibling);
        ocHideLoading(id.parentNode);
        if (wid && height) {
            view.dom.style.width = wid;
            view.dom.style.height = height;
        }
        return view;
    });
}

function shell_editor(id, readOnly, wid, height) {
    id.style.display = 'none';
    id.parentNode.classList.add('oc');
    ocShowLoading(id.parentNode, '<%:Loading...%>', height);
    ocQueueEditor(id.parentNode, function() {
        var isDark = isDarkBackground(document.body);
        var exts = [CM6.baseExtensions(), CM6.themeExtension(isDark), CM6.placeholderExtension('<%:Enter shell script...%>')];
        var topSearch = (CM6 && CM6.topSearchExtension) ? CM6.topSearchExtension() : null;
        if (topSearch) exts.push(topSearch);
        exts.push(CM6.StreamLanguage.define(CM6.shell));
        if (readOnly) exts.push(CM6.EditorState.readOnly.of(true));

        exts.push(CM6.EditorView.updateListener.of(function(update) {
            if (update.docChanged) id.value = update.state.doc.toString();
        }));

        var view = new CM6.EditorView({
            state: CM6.EditorState.create({ doc: id.value, extensions: exts })
        });
        id.parentNode.insertBefore(view.dom, id.nextSibling);
        ocHideLoading(id.parentNode);
        if (wid && height) {
            view.dom.style.width = wid;
            view.dom.style.height = height;
        }
        return view;
    });
}

function other_editor(id, readOnly, wid, height) {
    id.style.display = 'none';
    id.parentNode.classList.add('oc');
    ocShowLoading(id.parentNode, '<%:Loading...%>', height);
    ocQueueEditor(id.parentNode, function() {
        var isDark = isDarkBackground(document.body);
        var exts = [CM6.baseExtensions(), CM6.themeExtension(isDark), CM6.placeholderExtension('<%:Enter configuration...%>')];
        var topSearch = (CM6 && CM6.topSearchExtension) ? CM6.topSearchExtension() : null;
        if (topSearch) exts.push(topSearch);
        exts.push(CM6.StreamLanguage.define(CM6.properties));
        if (readOnly) exts.push(CM6.EditorState.readOnly.of(true));

        exts.push(CM6.EditorView.updateListener.of(function(update) {
            if (update.docChanged) id.value = update.state.doc.toString();
        }));

        var view = new CM6.EditorView({
            state: CM6.EditorState.create({ doc: id.value, extensions: exts })
        });
        id.parentNode.insertBefore(view.dom, id.nextSibling);
        ocHideLoading(id.parentNode);
        if (wid && height) {
            view.dom.style.width = wid;
            view.dom.style.height = height;
        }
        return view;
    });
}

function log_editor(id, name, readOnly, wid, height, onReady) {
    id.style.display = 'none';
    id.parentNode.classList.add('oc');
    ocShowLoading(id.parentNode, '<%:Loading...%>', height);
    ocQueueEditor(id.parentNode, function() {
        var isDark = isDarkBackground(document.body);
        var exts = [CM6.lineNumbers(), CM6.EditorView.lineWrapping, CM6.EditorState.readOnly.of(true), CM6.themeExtension(isDark)];
        var topSearch = (CM6 && CM6.topSearchExtension) ? CM6.topSearchExtension() : null;
        if (topSearch) exts.push(topSearch);
        exts.push(CM6.highlightActiveLine());
        exts.push(CM6.drawSelection());
        exts.push(CM6.highlightSelectionMatches());
        exts.push(CM6.keymap.of(CM6.searchKeymap));
        exts.push(CM6.logLanguage);
        exts.push(CM6.syntaxHighlighting(CM6.logHighlightStyle));

        var view = new CM6.EditorView({
            state: CM6.EditorState.create({ doc: id.value, extensions: exts })
        });
        id.parentNode.insertBefore(view.dom, id.nextSibling);
        ocHideLoading(id.parentNode);
        if (CM6.dispatchTheme) CM6.dispatchTheme(view, isDark);
        window['editor_' + name] = view;
        if (id.value && id.value.length > 0) {
            requestAnimationFrame(function() { view.requestMeasure(); });
        }
        if (wid && height) {
            view.dom.style.width = wid;
            view.dom.style.height = height;
        }
        view.getValue = function() { return view.state.doc.toString(); };
        view.setValue = function(v) { ocDiffSetValue(view, v); };
        view.refresh = function() { view.dispatch({}); if (view.requestMeasure) view.requestMeasure(); };
        view.getScrollInfo = function() { var sd = view.scrollDOM; return { top: sd.scrollTop, left: sd.scrollLeft, height: sd.scrollHeight, width: sd.scrollWidth, clientHeight: sd.clientHeight, clientWidth: sd.clientWidth }; };
        view.scrollTo = function(l, t) { if (typeof l === 'object') { t = l.top; l = l.left; } view.scrollDOM.scrollTop = t || 0; view.scrollDOM.scrollLeft = l || 0; };
        view.getCursor = function() { var h = view.state.selection.main.head, ln = view.state.doc.lineAt(h); return { line: ln.number - 1, ch: h - ln.from }; };
        view.setCursor = function(p) { var ln = view.state.doc.line(p.line + 1); view.dispatch({ selection: { anchor: ln.from + p.ch } }); };
        var hasFocusDesc = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(view), 'hasFocus');
        var hf;
        if (hasFocusDesc && hasFocusDesc.get) {
            try { hf = function() { return hasFocusDesc.get.call(view); }; } catch(e) { hf = null; }
        }
        if (!hf) {
            hf = function() { try { return view.contentDOM.ownerDocument.activeElement === view.contentDOM; } catch(e) { return false; } };
        }
        Object.defineProperty(view, 'hasFocus', { value: hf, writable: true, configurable: true });
        view.somethingSelected = function() { return !view.state.selection.main.empty; };
        view.setSelection = function(f, t) { var lf = view.state.doc.line(f.line + 1), lt = view.state.doc.line(t.line + 1); view.dispatch({ selection: { anchor: lf.from + f.ch, head: lt.from + t.ch } }); };
        view.scrollIntoView = function(p, m) { if (p && p.line !== undefined) { var ln = view.state.doc.line(p.line + 1); view.dispatch({ selection: { anchor: ln.from + (p.ch || 0) }, scrollIntoView: true }); } else { view.dispatch({ selection: { anchor: view.state.selection.main.head }, scrollIntoView: true }); } };
        if (view.state.doc.length > 0 && view.state.doc.lines >= 1) {
            var fl = view.state.doc.line(1);
            view.dispatch({ selection: { anchor: fl.to } });
        }
        return view;
    }, onReady);
}

function markdown_editor(id, name, readOnly, wid, height, onReady) {
    id.style.display = 'none';
    id.parentNode.classList.add('oc');
    ocShowLoading(id.parentNode, '<%:Loading...%>', height);
    ocQueueEditor(id.parentNode, function() {
        var isDark = isDarkBackground(document.body);
        var exts = [CM6.lineNumbers(), CM6.EditorView.lineWrapping, CM6.themeExtension(isDark), CM6.markdown()];
        if (readOnly) exts.push(CM6.EditorState.readOnly.of(true));

        var view = new CM6.EditorView({
            state: CM6.EditorState.create({ doc: id.value || '', extensions: exts })
        });
        id.parentNode.insertBefore(view.dom, id.nextSibling);
        ocHideLoading(id.parentNode);
        if (CM6.dispatchTheme) CM6.dispatchTheme(view, isDark);
        window['editor_' + name] = view;
        if (id.value && id.value.length > 0) {
            requestAnimationFrame(function() { view.requestMeasure(); });
        }
        if (wid && height) {
            view.dom.style.width = wid;
            view.dom.style.height = height;
        }
        view.getValue = function() { return view.state.doc.toString(); };
        view.setValue = function(v) { ocDiffSetValue(view, v); };
        view.refresh = function() { view.dispatch({}); };
        view.dom = view.dom;
        return view;
    }, onReady);
}

ocRegisterEditorHotkeys();
