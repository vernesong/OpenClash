// Extracted from luasrc/view/openclash/flush_dns_cache.htm and flush_smart_cache.htm.
// <%:...%> markers and <%=...%> islands are rendered server-side by the translate_js action.

// Shared by the DNS and Smart cache buttons: only the endpoint, the status element and the
// success predicate differ, all of which come from the caller.
function ocFlushCache(btn, opts) {
    var statusEl = document.getElementById(opts.statusId);
    btn.disabled = true;
    btn.value = '<%:Flushing...%> ';
    if (statusEl) { statusEl.textContent = ''; statusEl.className = 'oc-flush-status'; }
    XHR.get(opts.url, null, function(x, status) {
        var msg, ok;
        btn.disabled = false;
        btn.value = '<%:Flush%>';
        if (x && x.status == 200) {
            ok = opts.ok(status);
            msg = ok ? '<%:Flush Successful%>' : '<%:Flush Failed%>';
        } else {
            ok = false;
            msg = '<%:Flush Timeout%>';
        }
        if (statusEl) {
            statusEl.textContent = msg;
            statusEl.className = 'oc-flush-status' + (ok ? '' : ' err');
        }
    });
    return false;
}

function act_flush_dns_cache(btn) {
    return ocFlushCache(btn, {
        statusId: 'oc_flush_dns_status',
        url: '<%=luci.dispatcher.build_url("admin", "services", "openclash","flush_dns_cache")%>',
        ok: function(s) { return s.fakeip_flush === '' && s.dns_flush === ''; }
    });
}

function act_flush_smart_cache(btn) {
    return ocFlushCache(btn, {
        statusId: 'oc_flush_smart_status',
        url: '<%=luci.dispatcher.build_url("admin", "services", "openclash","flush_smart_cache")%>',
        ok: function(s) { return s.flush_status === ''; }
    });
}
