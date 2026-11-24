// Extracted from luasrc/view/openclash/input_file_name.htm - edit this file, not the template.
// <%:...%> markers and <%=...%> islands are rendered server-side by the translate_js action.

//<![CDATA[
function import_file_name(btn, option, file_path) {
	ocPrompt('<%:Paste the name of the new file (including the extension) here:%>', '', function(value, setError, close) {
		if (!value) return;
		XHR.get('<%=luci.dispatcher.build_url("admin", "services", "openclash", "create_file")%>', {filename: value, filepath: file_path}, function(x, status) {
			if (x && x.status == 200)
			{
				close();
				location.reload();
			}
			else
			{
				setError('<%:Create File Failed%>');
			}
		});
	});
	return false;
}
//]]>
