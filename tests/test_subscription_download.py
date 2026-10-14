"""Run with python3 -m unittest discover -s tests (requires curl, Ruby, Lua, OpenSSL)."""

import base64
import http.server
import os
from pathlib import Path
import shlex
import ssl
import subprocess
import tempfile
import threading
import unittest


ROOT = Path(__file__).resolve().parents[1] / "luci-app-openclash"
SHARE = ROOT / "root/usr/share/openclash"
VALID = b"proxies:\n  - {name: test, type: socks5, server: 127.0.0.1, port: 1080}\n"
PROVIDER = b"proxy-providers:\n  oixCloud: {type: http, url: 'https://example.invalid/nodes'}\n"
ALIASES = b"node: &node {name: test, type: socks5, server: 127.0.0.1, port: 1080}\nproxies: [*node]\n"
ORIGINAL = b"# original configuration\n" + VALID
RESPONSES = {
    "/valid": (200, VALID),
    "/provider": (200, PROVIDER),
    "/aliases": (200, ALIASES),
    "/base64": (200, base64.b64encode(VALID)),
    "/503": (503, b"Subscription temporarily unavailable"),
    "/404": (404, b"not found"),
    "/empty": (200, b""),
    "/text": (200, b"Subscription temporarily unavailable"),
    "/html": (200, b"<html>upstream error</html>"),
    "/broken": (200, b"proxies: [\n"),
    "/missing": (200, b"port: 7890\n"),
    "/no-nodes": (200, b"proxies: []\nproxy-providers: {}\n"),
    "/wrong-type": (200, b"proxies: error\n"),
    "/wrong-entry": (200, b"proxy-providers: {nodes: error}\n"),
    "/object-tag": (200, b"--- !ruby/hash:Hash\n" + VALID),
    "/partial": (200, VALID),
}


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        status, body = RESPONSES[self.path]
        self.send_response(status)
        self.send_header("Content-Length", str(len(body) + (100 if self.path == "/partial" else 0)))
        self.send_header("ETag", '"new-subscription"')
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


class SubscriptionDownloadTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tls = tempfile.TemporaryDirectory(prefix="openclash-tls-")
        cert = Path(cls.tls.name) / "cert.pem"
        key = Path(cls.tls.name) / "key.pem"
        subprocess.run([
            "openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
            "-keyout", str(key), "-out", str(cert), "-days", "1",
            "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost",
        ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        cls.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(cert, key)
        cls.server.socket = context.wrap_socket(cls.server.socket, server_side=True)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.url = f"https://localhost:{cls.server.server_port}"
        cls.cert = str(cert)

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()
        cls.tls.cleanup()

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="openclash-subscription-")
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name)
        self.config = self.path / "etc/openclash/config/oixCloud.yaml"
        self.config.parent.mkdir(parents=True)
        self.config.write_bytes(ORIGINAL)
        (self.path / "tmp").mkdir()
        self.share = self.path / "share"
        self.share.mkdir()
        for name in ["YAML.rb", "log.sh", "openclash_curl.sh", "openclash_etag.sh"]:
            # Avoid shadowing Ruby's yaml.rb on case-insensitive macOS volumes.
            target = "openclash_yaml.rb" if name == "YAML.rb" else name
            (self.share / target).write_text(self.paths((SHARE / name).read_text()))
        core = self.path / "etc/openclash/clash"
        core.write_text('#!/bin/sh\nexit "${CORE_EXIT:-0}"\n')
        core.chmod(0o755)
        self.env = dict(os.environ, CURL_CA_BUNDLE=self.cert, NO_PROXY="localhost,127.0.0.1", LC_ALL="C")

    def paths(self, text):
        return (text.replace("-rYAML", "-ropenclash_yaml")
                .replace("/usr/share/openclash", str(self.path / "share"))
                .replace("/etc/openclash", str(self.path / "etc/openclash"))
                .replace("/tmp/", str(self.path / "tmp") + "/"))

    def login(self, endpoint, failure="", legacy=False):
        source = (ROOT / "luasrc/controller/openclash.lua").read_text()
        source = source[source.index("local function oix_valid_token("):source.index("\nfunction oix_login()")]
        references = (ROOT / "luasrc/openclash.lua").read_text()
        references = references[references.index("function config_refs("):references.index("\n--- Returns the appropriate ps command")]
        harness = r'''
local root, share, url, failure = arg[1], arg[2], arg[3], arg[4]
local writes, restarts = 0, 0
local old_file = "/etc/openclash/config/oixCloud - smart.yaml"
local state = {config = {config_path = "/etc/openclash/config/oixCloud.yaml"}}
if arg[5] == "legacy" then
    state.config.config_path = old_file
    state.existing = {[".type"] = "config_subscribe", [".name"] = "existing", name = "oixCloud - smart", address = url}
    state.overwrite = {[".type"] = "overwrite", [".name"] = "overwrite", config = {old_file, "/etc/openclash/config/other.yaml"}}
    state.age = {[".type"] = "config_age_secret", [".name"] = "age", name = "oixCloud - smart"}
end
local function path(value)
    return (value:gsub("%-rYAML", "-ropenclash_yaml")
        :gsub("/etc/openclash", function() return root .. "/etc/openclash" end)
        :gsub("/usr/share/openclash", function() return share end))
end
local function execute(command)
    local pipe = assert(io.popen(command))
    local output = pipe:read("*a")
    pipe:close()
    return output
end
SYS = {
    exec = function(command)
        if command:find("/etc/init.d/openclash restart", 1, true) then restarts = restarts + 1; return "" end
        if failure == "ruby" and command:match("^ruby ") then return "" end
        if failure == "ruby-exit" and command:match("^ruby ") then return "OK\n:1" end
        if failure == "timeout" and command:match("^curl ") then return "000:28" end
        local output = execute(path(command))
        if command:match("^mktemp ") then
            return output:sub(#root + 1)
        end
        return output
    end,
    call = function(command)
        return tonumber(execute(path(command) .. "; printf '%s' \"$?\""))
    end
}
fs = {
    unlink = function(file) return os.remove(path(file)) end,
    rename = function(from, to)
        if failure == "rename" then return nil end
        return os.rename(path(from), path(to))
    end
}
luci = {i18n = {translate = function(text) return text end}}
uci = {
    get = function(_, _, section, key) return state[section] and state[section][key] end,
    set = function(_, _, section, key, value) writes = writes + 1; state[section][key] = value end,
    commit = function() writes = writes + 1 end,
    load = function() end,
    foreach = function(_, _, kind, callback)
        for _, section in pairs(state) do
            if section[".type"] == kind and callback(section) == false then break end
        end
    end,
    add = function(_, _, kind)
        assert(not state.subscription, "duplicate subscription")
        state.subscription = {[".type"] = kind, [".name"] = "subscription"}
        return "subscription"
    end,
    delete = function(_, _, section) writes = writes + 1; state[section] = nil end
}
dynamic_uci = uci
function basename(value) return value:match("([^/]+)$") end
function filename(value) return (value:gsub("%.[^.]+$", "")) end
function write_padded() end
function coremetacv() return "mihomo-oix" end
'''
        harness += references + '\nfs.config_refs = config_refs\n' + source + r'''
oix_api = function() return {ret = 200, openclash = url} end
oix_wait_loaded = function() return true end
local ok, message = fetch_oix_sub(string.rep("a", 64))
print(ok and "OK" or "ERROR")
print(message or "")
print(writes .. ":" .. restarts)
print(state.config.config_path)
if arg[5] == "legacy" then
    print(state.existing.name)
    print(state.overwrite.config[1])
    print(state.age.name)
    assert(not state.subscription, "legacy subscription was duplicated")
end
'''
        script = self.path / "login.lua"
        script.write_text(harness)
        result = subprocess.run(["lua", str(script), str(self.path), str(self.share), self.url + endpoint, failure,
                                 "legacy" if legacy else "current"],
                                env=self.env, text=True, capture_output=True, check=True, timeout=60)
        return result.stdout.splitlines()

    def update(self, endpoint, failure="", direct=False):
        source = (SHARE / "openclash.sh").read_text()
        source = self.paths(source[source.index("config_test()\n"):source.index("#分别获取订阅信息进行处理")])
        prelude = f'''
. {shlex.quote(str(self.share / "openclash_curl.sh"))}
GET_ETAG_BY_PATH() {{ :; }}
SAVE_ETAG_TO_CACHE() {{ echo "$2" > {shlex.quote(str(self.path / "etag"))}; }}
config_get() {{
    local field="$1" key="$3" value="$4"
    case "$key" in
        name) value="oixCloud" ;;
        address) value={shlex.quote(self.url + endpoint)} ;;
        sub_convert) value=0 ;;
    esac
    printf -v "$field" '%s' "$value"
}}
config_get_bool() {{ config_get "$@"; }}
config_list_foreach() {{ :; }}
uci_get_age_secret_keys() {{ :; }}
pidof() {{ return {0 if direct else 1}; }}
procd_send_signal() {{ :; }}
kill_streaming_unlock() {{ :; }}
sleep() {{ :; }}
CLASH={shlex.quote(str(self.path / "etc/openclash/clash"))}
CLASH_CONFIG={shlex.quote(str(self.path / "etc/openclash"))}
CONFIG_PATH={shlex.quote(str(self.config))}
router_self_proxy=1
norestart=0
restart=0
exit_code=0
'''
        tail = '\nchange_dns() { :; }\n'
        if failure == "ruby":
            tail += "ruby() { return 127; }\n"
        if failure == "rename":
            tail += 'mv() { if [ "${@: -1}" = "$CONFIG_FILE" ]; then return 1; fi; command mv "$@"; }\n'
        if failure == "copy":
            tail += "cp() { return 1; }\n"
        if failure == "filter":
            tail += 'config_cus_up() { printf "proxies: []\\n" > "$CFG_FILE"; }\n'
        tail += 'sub_info_get subscription\nprintf "RESULT %s:%s\\n" "$exit_code" "$restart"\n'
        script = self.path / "update.sh"
        script.write_text(prelude + source + tail)
        result = subprocess.run(["bash", str(script)], env=self.env, text=True, capture_output=True,
                                check=True, timeout=60)
        log = self.path / "tmp/openclash.log"
        return result.stdout, log.read_text() if log.exists() else ""

    def assert_preserved(self):
        self.assertEqual(self.config.read_bytes(), ORIGINAL)
        self.assertFalse(list(self.config.parent.glob(".oixCloud.*")))
        self.assertFalse(list(self.config.parent.glob(".subscription.*")))

    def test_login_rejects_http_and_invalid_content(self):
        for endpoint, message in [
            ("/503", "HTTP 503"), ("/404", "HTTP 404"), ("/empty", "empty"),
            ("/text", "not a valid"), ("/html", "not a valid"), ("/broken", "not a valid"),
            ("/missing", "no proxies"), ("/no-nodes", "no proxies"),
            ("/wrong-type", "not a valid"), ("/wrong-entry", "not a valid"),
            ("/object-tag", "not a valid"),
            ("/partial", "curl 18"),
        ]:
            with self.subTest(endpoint=endpoint):
                result = self.login(endpoint)
                self.assertEqual(result[0], "ERROR")
                self.assertIn(message, result[1])
                self.assertEqual(result[2], "0:0")
                self.assert_preserved()

    def test_login_preserves_config_on_local_failures(self):
        for failure, message in [("ruby", "could not run"), ("ruby-exit", "could not run"),
                                 ("rename", "Unable to save"), ("timeout", "timed out")]:
            with self.subTest(failure=failure):
                result = self.login("/valid", failure)
                self.assertIn(message, result[1])
                self.assertEqual(result[2], "0:0")
                self.assert_preserved()
        self.env["CORE_EXIT"] = "7"
        result = self.login("/valid")
        self.assertIn("core validation", result[1])
        self.assertEqual(result[2], "0:0")
        self.assert_preserved()

    def test_login_accepts_nodes_and_provider_configurations(self):
        for endpoint in ["/valid", "/provider", "/aliases", "/base64"]:
            with self.subTest(endpoint=endpoint):
                result = self.login(endpoint)
                self.assertEqual(result[0], "OK")
                self.assertTrue(result[2].endswith(":1"))
                self.assertEqual(self.config.read_bytes(), RESPONSES[endpoint][1])
                self.assertFalse(list(self.config.parent.glob(".oixCloud.*")))

    def test_legacy_name_migrates_only_after_successful_validation(self):
        legacy = self.config.parent / "oixCloud - smart.yaml"
        self.config.rename(legacy)
        result = self.login("/text", legacy=True)
        self.assertEqual(result[0], "ERROR")
        self.assertEqual(result[2], "0:0")
        self.assertEqual(legacy.read_bytes(), ORIGINAL)
        self.assertFalse(self.config.exists())
        self.assertEqual(result[4], "oixCloud - smart")

        result = self.login("/provider", legacy=True)
        self.assertEqual(result[0], "OK")
        self.assertEqual(result[3:], ["/etc/openclash/config/oixCloud.yaml", "oixCloud",
                                     "/etc/openclash/config/oixCloud.yaml", "oixCloud"])
        self.assertEqual(self.config.read_bytes(), PROVIDER)
        self.assertFalse(legacy.exists())

    def test_encrypted_temporary_file_uses_original_key_name(self):
        encrypted = self.config.parent / ".oixCloud.test"
        encrypted.write_text("-----BEGIN AGE ENCRYPTED FILE-----\nfixture\n")
        script = r'''
YAML.define_singleton_method(:age_keys) do
  { 'oixCloud - smart' => { publics: [], secrets: ['fixture-secret'] } }
end
YAML.define_singleton_method(:decrypt_content_with_secret) do |secret, _|
  raise 'unexpected key' unless secret == 'fixture-secret'
  File.read(ARGV[1])
end
puts YAML.subscription_status(ARGV[0], ['oixCloud', 'oixCloud - smart'])
'''
        result = subprocess.run(["ruby", "-ryaml", "-ropenclash_yaml", "-I", str(self.share),
                                 "-e", script, str(encrypted), str(self.config)],
                                env=self.env, text=True, capture_output=True, check=True)
        self.assertEqual(result.stdout.strip(), "OK")

    def test_regular_update_rejects_bad_downloads_without_caching_etag(self):
        for endpoint in ["/503", "/empty", "/text", "/broken", "/no-nodes", "/partial"]:
            with self.subTest(endpoint=endpoint):
                output, log = self.update(endpoint)
                self.assertIn("RESULT 1:0", output)
                self.assertIn("existing configuration was kept", log)
                self.assertFalse((self.path / "etag").exists())
                self.assert_preserved()

    def test_regular_update_fails_closed_on_validator_and_filter_failures(self):
        for failure in ["ruby", "filter", "rename", "copy"]:
            with self.subTest(failure=failure):
                output, log = self.update("/valid", failure)
                self.assertIn("RESULT 1:0", output)
                self.assertIn("existing configuration was kept", log)
                self.assertFalse((self.path / "etag").exists())
                self.assert_preserved()
        self.env["CORE_EXIT"] = "7"
        output, log = self.update("/valid")
        self.assertIn("RESULT 1:0", output)
        self.assertIn("core validation", log)
        self.assert_preserved()

    def test_regular_direct_retry_also_fails_closed(self):
        output, log = self.update("/valid", "ruby", direct=True)
        self.assertIn("RESULT 1:0", output)
        self.assertIn("could not run", log)
        self.assert_preserved()

    def test_regular_update_commits_valid_configuration_and_etag(self):
        output, _ = self.update("/provider")
        self.assertIn("RESULT 0:1", output)
        self.assertEqual(self.config.read_bytes(), PROVIDER)
        self.assertEqual((self.path / "etag").read_text().strip(), "new-subscription")
        self.assertFalse(list(self.config.parent.glob(".subscription.*")))


if __name__ == "__main__":
    unittest.main()
