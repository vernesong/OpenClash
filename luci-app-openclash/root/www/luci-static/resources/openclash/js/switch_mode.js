// Extracted from luasrc/view/openclash/switch_mode.htm - edit this file, not the template.
// <%:...%> markers and <%=...%> islands are rendered server-side by the translate_js action.

//<![CDATA[
	var switch_mode  = document.getElementById('switch_mode');
	XHR.get('<%=luci.dispatcher.build_url("admin", "services", "openclash", "op_mode")%>', null, function(x, status) {
		if ( x && x.status == 200 ) {
			if ( status.op_mode == "redir-host" ) {
				switch_mode.innerHTML = '<input type="button" class="btn cbi-button cbi-button-reset oc oc-switch-mode-btn" value="<%:Switch page to Fake-IP mode%>" onclick="return switch_modes(this)"/>';
			}
			else {
				switch_mode.innerHTML = '<input type="button" class="btn cbi-button cbi-button-reset oc oc-switch-mode-btn" value="<%:Switch page to Redir-Host mode%>" onclick="return switch_modes(this)"/>';
			}
		}
	});

	function switch_modes(btn)
	{
		ocConfirm({
			body: '<%:Switching the DNS mode requires a plugin restart to take effect. Continue?%>',
			buttons: [
				{ label: '<%:Cancel%>', value: null },
				{ label: '<%:OK%>', value: 'ok', kind: 'primary' }
			]
		}).then(function(choice) {
			if (choice !== 'ok') return;
			btn.disabled = true;
			XHR.get('<%=luci.dispatcher.build_url("admin", "services", "openclash", "switch_mode")%>', null, function(x, status) {
				if ( x && x.status == 200 ) {
					var msg = ( status.switch_mode == "redir-host" )
						? '<%:Page has been switched to Fake-IP mode!%>'
						: '<%:Page has been switched to Redir-Host mode!%>';
					switch_mode.innerHTML = '<span class="oc-status-ok">' + msg + '</span>';
					setTimeout(function() {
						window.location.href='<%=luci.dispatcher.build_url("admin", "services", "openclash", "settings")%>';
					}, 1200);
				}
				else {
					btn.disabled = false;
					switch_mode.innerHTML = '<span class="oc-status-err"><%:Switch Failed%></span>';
				}
			});
		});
		return false;
	}

//]]>
