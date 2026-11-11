// Extracted from luasrc/view/openclash/config_actions.htm - edit this file, not the template.
// <%:...%> markers and <%=...%> islands are rendered server-side by the translate_js action.

window.configRowAction = function(select, id) {
    var action = select.value;
    var file = select.dataset.file;
    select.value = '';
    if (!action) return false;
    if (action === 'rename') {
        ocPrompt('<%:Paste the new file name (including the extension) here:%>', file, function(value, setError, close) {
            if (!value) return;
            if (!/\.ya?ml$/.test(value)) {
                setError('<%:Illegal extension!%>');
                return;
            }
            XHR.get('<%=luci.dispatcher.build_url("admin", "services", "openclash", "rename_file")%>', {new_file_name: value, file_path: '/etc/openclash/config/', file_name: file}, function(x) {
                if (x && x.status === 200) { close(); location.reload(); }
                else setError('<%:Rename Failed%>');
            });
        });
        return false;
    }
    if (action === 'remove' && !window.confirm('<%:Remove%> ' + file + '?')) return false;
    document.getElementById(id).value = action;
    select.parentNode.parentNode.querySelector('button[type="submit"]').click();
    return false;
};
window.configRowMenu = function(btn) {
    var select = btn.nextElementSibling;
    if (!select) return false;
    if (select.showPicker) {
        try { select.showPicker(); return false; } catch (e) {}
    }
    select.focus();
    return false;
};
