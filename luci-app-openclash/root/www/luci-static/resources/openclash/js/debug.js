// Extracted from luasrc/view/openclash/debug.htm - edit this file, not the template.
// <%:...%> markers and <%=...%> islands are rendered server-side by the translate_js action.

//<![CDATA[
	function show_diag_info(addr)
	{
		var legend = document.getElementById('diag-rc-legend');
		var output = document.getElementById('diag-rc-output');

		if (legend && output)
		{
			XHR.get('<%=luci.dispatcher.build_url("admin", "services", "openclash", "diag_connection")%>', {addr: addr}, function(x, status) {
				legend.textContent = '<%:Connection Test Result%>';
				if (x && x.status == 200 && x.responseText != "")
				{
					output.innerHTML = '<div class="oc-oplog"><div class="oc-oplog-h"><b><%:Connection Test Result%></b><span class="oc-oplog-live"><i></i>LIVE</span></div><div class="oc-editor-host"></div></div>';
					var ta = document.createElement('textarea');
					ta.style.width = '100%';
					ta.value = x.responseText.split('\n').map(function(l) { return l.trim(); }).filter(function(l) { return l !== ''; }).join('\n');
					output.querySelector('.oc-editor-host').appendChild(ta);
					other_editor(ta, true, '100%', '400px');
				}
				else if (x.status == 500)
				{
					output.innerHTML = '<span class="error"><%:Bad address specified!%></span>';
				}
				else
				{
					output.innerHTML = '<span class="error"><%:Could not find any connection logs!%></br></br><%:1. It may be that the plugin is not running%></br></br><%:2. It may be that the cache causes the browser to directly use the IP for access%></br></br><%:3. It may be that DNS hijacking did not take effect, so the domain name cannot be reversed%></br></br><%:4. It may be that the filled address cannot be resolved and connected%></span>';
				}
			});
		}
	}

	function update_status(field)
	{
		var addr = field.value;
		var legend = document.getElementById('diag-rc-legend');
		var output = document.getElementById('diag-rc-output');

		if (legend && output)
		{
			output.innerHTML =
				'<div class="oc-oplog"><div class="oc-oplog-h"><b><%:Connection Test Result%></b><span class="oc-oplog-live"><i></i>LIVE</span></div>' +
				'<div class="oc-oplog-body">' + ocSpinnerRow('<%:Waiting for command to complete...%>') + '</div></div>';

			legend.textContent = '<%:Collecting data...%>';
			legend.parentNode.classList.remove('oc-hidden');
			legend.style.display = 'none';
		}

		let HTTP = {
			checker: (domain) => {
			let img = new Image;
			let timeout = setTimeout(() => {
				img.onerror = img.onload = null;
				show_diag_info(addr);
				}, 10000);

				img.onerror = () => {
					clearTimeout(timeout);
					show_diag_info(addr);
				}

				img.onload = () => {
					clearTimeout(timeout);
					show_diag_info(addr);
				}

				img.src = `https://${domain}/favicon.ico?${+(new Date)}`
			},
			runcheck: () => {
				HTTP.checker(addr);
			}
			};
		HTTP.runcheck();
	}

	function diag_dns(field)
	{
		var addr = field.value;
		var legend = document.getElementById('dns-rc-legend');
		var output = document.getElementById('dns-rc-output');

		if (legend && output)
		{
			output.innerHTML =
				'<div class="oc-oplog"><div class="oc-oplog-h"><b><%:DNS Test Result%></b><span class="oc-oplog-live"><i></i>LIVE</span></div>' +
				'<div class="oc-oplog-body">' + ocSpinnerRow('<%:Waiting for command to complete...%>') + '</div></div>';

			legend.textContent = '<%:Collecting data...%>';
			legend.parentNode.classList.remove('oc-hidden');
			legend.style.display = 'none';
		}

		if (legend && output)
		{
			XHR.get('<%=luci.dispatcher.build_url("admin", "services", "openclash", "diag_dns")%>', {addr: addr}, function(x, status) {
				legend.textContent = '<%:DNS Test Result%>';
				if (x && x.status == 200 && x.responseText != "")
				{
					output.innerHTML = '<div class="oc-oplog"><div class="oc-oplog-h"><b><%:DNS Test Result%></b><span class="oc-oplog-live"><i></i>LIVE</span></div><div class="oc-editor-host"></div></div>';
					var ta = document.createElement('textarea');
					ta.style.width = '100%';
					ta.value = x.responseText.split('\n').map(function(l) { return l.trim(); }).filter(function(l) { return l !== ''; }).join('\n');
					output.querySelector('.oc-editor-host').appendChild(ta);
					other_editor(ta, true, '100%', '400px');
				}
				else if (x.status == 500)
				{
					output.innerHTML = '<span class="error"><%:Bad address specified!%></span>';
				}
				else
				{
					output.innerHTML = '<span class="error"><%:No Response Found!%></span>';
				}
			});
		}
	}
//]]>
