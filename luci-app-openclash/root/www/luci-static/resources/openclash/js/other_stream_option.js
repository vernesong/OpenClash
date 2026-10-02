// Shared test buttons for the multi-instance stream option template.
// <%:Message%> markers and <%=...%> islands are compiled server-side by the "openclash/translate_js" controller action.

function ocStreamTest(btn, kind, type, idName) {
    var legend = document.getElementById(kind + '-' + idName + '-test-state');
    var output = document.getElementById(kind + '-' + idName + '-test-output');
    ocConfirm({
        title: '<%:Start Test%>',
        body: '<%:Network instability may occur during testing, Are you sure want to start test?%>',
        buttons: [
            { label: '<%:Cancel%>', value: null },
            { label: '<%:OK%>', value: 'start', kind: 'primary' }
        ]
    }).then(function(choice) {
        if (choice !== 'start') return;
        if (legend && output) {
            var title = kind === 'manual' ? '<%:Unlock Test Result%>' : '<%:All Proxies Test Result%>';
            output.innerHTML =
                '<div class="oc-oplog"><div class="oc-oplog-h"><b>' + title + '</b><span class="oc-oplog-live"><i></i>LIVE</span></div>' +
                '<div class="oc-oplog-body"><span class="loading-spinner" style="vertical-align:middle"></span> <%:Waiting for command to complete...%></div></div>';
            legend.textContent = '<%:Collecting data...%>';
            legend.parentNode.classList.remove('oc-hidden');
            legend.style.display = 'none';
        }
        var xhr = new XMLHttpRequest();
        xhr.timeout = 0;
        var url = btn.getAttribute('data-url') + '?type=' + encodeURIComponent(type);
        xhr.open('GET', url, true);
        xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
        var editorName = kind === 'manual' ? 'manual_stream_unlock_test' : 'all_proxies_stream_test';
        var editor = null, editorReady = false;
        function updateStreamOutput() {
            if (!editor || !editor.setValue) return;
            editor.setValue(xhr.responseText.split('\n').map(function(l) { return l.trim(); }).filter(function(l) { return l !== ''; }).join('\n'));
            editor.dispatch({ selection: { anchor: editor.state.doc.length } });
            if (editor.scrollDOM) editor.scrollDOM.scrollTop = editor.scrollDOM.scrollHeight;
        }
        xhr.onprogress = function() {
            if (!editorReady) {
                output.innerHTML = '<div class="oc-oplog"><div class="oc-oplog-h"><b>' + title + '</b><span class="oc-oplog-live"><i></i>LIVE</span></div><div class="oc-editor-host"></div></div>';
                var ta = document.createElement('textarea');
                output.querySelector('.oc-editor-host').appendChild(ta);
                log_editor(ta, editorName, true, '600px', '250px', function(v) {
                    editor = v;
                    updateStreamOutput();
                });
                editorReady = true;
            }
            updateStreamOutput();
        };
        xhr.onload = function() {
            updateStreamOutput();
            legend.textContent = kind === 'manual' ? '<%:Unlock Test Result%>' : '<%:All Proxies Test Result%>';
            if (xhr.status != 200 && xhr.responseText == "") {
                output.innerHTML = '<span class="error"><%:Something Wrong While Testing...%></span>';
            }
        };
        xhr.ontimeout = function() {
            if (xhr.responseText == "") {
                output.innerHTML = '<span class="error"><%:Request Timeout...%></span>';
            }
        };
        xhr.onerror = function() {
            if (xhr.responseText == "") {
                output.innerHTML = '<span class="error"><%:Something Wrong While Testing...%></span>';
            }
        };
        xhr.send();
    });
}
