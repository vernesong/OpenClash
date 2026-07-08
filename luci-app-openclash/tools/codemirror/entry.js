// ============================================================
// CodeMirror 6 Bundle — OpenClash
// Build: npx esbuild tools/codemirror/entry.js --bundle --format=iife --global-name=CM6 --minify --target=es2019 --outfile=root/www/luci-static/resources/openclash/js/cm6.min.js --legal-comments=none --loader:.css=text
// ============================================================

// ---- Core ----
import { EditorView, ViewPlugin, Decoration } from "@codemirror/view"
import { EditorState, Compartment, RangeSetBuilder } from "@codemirror/state"

// ---- View extensions ----
import {
    lineNumbers, highlightActiveLine, highlightActiveLineGutter,
    highlightSpecialChars, drawSelection, dropCursor,
    rectangularSelection, crosshairCursor, keymap as cmKeymap, placeholder
} from "@codemirror/view"

// ---- Commands ----
import {
    defaultKeymap, history, historyKeymap, indentWithTab, indentMore,
    toggleComment
} from "@codemirror/commands"

// ---- Language core ----
import {
    syntaxHighlighting, HighlightStyle, bracketMatching,
    foldGutter, indentOnInput, StreamLanguage, foldKeymap, indentUnit,
    getIndentUnit, foldable
} from "@codemirror/language"

// ---- Tags ----
import { Tag } from "@lezer/highlight"

// ---- Custom log tags ----
const logTag = {
    timestamp: Tag.define(),
    bracket: Tag.define(),
    category: Tag.define(),
    logString: Tag.define(),
    logLink: Tag.define(),
    levelInfo: Tag.define(),
    levelWarning: Tag.define(),
    levelError: Tag.define(),
    levelDebug: Tag.define(),
    levelTip: Tag.define(),
    levelFatal: Tag.define(),
    levelWatchdog: Tag.define(),
}

// ---- Language packages ----
import { yaml } from "@codemirror/lang-yaml"
import { markdown } from "@codemirror/lang-markdown"

// ---- Legacy modes ----
import { shell } from "@codemirror/legacy-modes/mode/shell"
import { properties } from "@codemirror/legacy-modes/mode/properties"

// ---- Lint ----
import { linter, lintGutter } from "@codemirror/lint"
import { loadAll, YAML11_SCHEMA } from "js-yaml"

// ---- Search ----
import { search, searchKeymap, highlightSelectionMatches } from "@codemirror/search"

// ---- Autocomplete ----
import {
    autocompletion, closeBrackets, closeBracketsKeymap, snippetCompletion,
    acceptCompletion
} from "@codemirror/autocomplete"

// ---- Theme ----
import { githubDark, githubLight } from "@fsegurai/codemirror-theme-bundle"

// ---- Merge view ----
import { MergeView } from "@codemirror/merge"

// ---- Markdown rendering ----
import { marked } from "marked"
import hljs from "highlight.js/lib/core"
import yamlLang from "highlight.js/lib/languages/yaml"
import bashLang from "highlight.js/lib/languages/bash"
import jsonLang from "highlight.js/lib/languages/json"
import githubLightCSS from "highlight.js/styles/github.css"
import githubDarkCSS from "highlight.js/styles/github-dark-dimmed.css"

hljs.registerLanguage("yaml", yamlLang)
hljs.registerLanguage("yml", yamlLang)
hljs.registerLanguage("bash", bashLang)
hljs.registerLanguage("sh", bashLang)
hljs.registerLanguage("shell", bashLang)
hljs.registerLanguage("json", jsonLang)

// ============================================================
// Mihomo / Clash YAML keyword completion
// ============================================================
const mihomoKeywords = [
    { label: "port", type: "keyword", detail: "HTTP proxy port", info: "Invalid when mixed port is enabled" },
    { label: "socks-port", type: "keyword", detail: "SOCKS5 proxy port" },
    { label: "mixed-port", type: "keyword", detail: "HTTP/SOCKS mixed port", info: "Overrides port and socks-port when set" },
    { label: "redir-port", type: "keyword", detail: "Transparent proxy port" },
    { label: "tproxy-port", type: "keyword", detail: "TPROXY transparent proxy port" },
    { label: "mode", type: "keyword", detail: "Run mode: rule / global / direct" },
    { label: "log-level", type: "keyword", detail: "Log level: debug / info / warning / error / silent" },
    { label: "ipv6", type: "keyword", detail: "IPv6 traffic handling: true / false" },
    { label: "allow-lan", type: "keyword", detail: "Allow LAN connections: true / false" },
    { label: "bind-address", type: "keyword", detail: "Bind address, default *" },
    { label: "authentication", type: "keyword", detail: "HTTP/SOCKS authentication, array format" },
    { label: "external-controller", type: "keyword", detail: "RESTful API listen address" },
    { label: "external-ui", type: "keyword", detail: "Dashboard path" },
    { label: "secret", type: "keyword", detail: "API secret" },
    { label: "interface-name", type: "keyword", detail: "Outbound interface name" },
    { label: "routing-mark", type: "keyword", detail: "Routing mark" },
    { label: "hosts", type: "keyword", detail: "Custom hosts mapping" },
    { label: "profile", type: "keyword", detail: "Profiling configuration" },
    { label: "global-ua", type: "keyword", detail: "Global User-Agent" },
    { label: "unified-delay", type: "keyword", detail: "Unified delay: true / false" },
    { label: "tcp-concurrent", type: "keyword", detail: "TCP concurrent connections" },
    { label: "find-process-mode", type: "keyword", detail: "Find process mode: off / strict / always" },
    { label: "sniffing", type: "keyword", detail: "Domain sniffing: true / false" },
    { label: "keep-alive-interval", type: "keyword", detail: "TCP keep-alive interval (seconds)" },
    { label: "geodata-mode", type: "keyword", detail: "GEO data mode: true / false" },
    { label: "geodata-loader", type: "keyword", detail: "GEO loader: memconservative / standard" },
    { label: "geox-url", type: "keyword", detail: "GEOX custom URL template" },
    { label: "geosite", type: "keyword", detail: "GeoSite configuration" },
    { label: "geo-auto-update", type: "keyword", detail: "GEO auto update: true / false" },
    { label: "geo-update-interval", type: "keyword", detail: "GEO update interval (hours)" },
    { label: "tun", type: "keyword", detail: "TUN mode configuration" },
    { label: "enable", type: "property", detail: "Enable: true / false" },
    { label: "stack", type: "property", detail: "Protocol stack: system / gvisor / mixed" },
    { label: "device", type: "property", detail: "TUN device name" },
    { label: "dns-hijack", type: "property", detail: "DNS hijack address list" },
    { label: "auto-route", type: "property", detail: "Auto set route: true / false" },
    { label: "auto-detect-interface", type: "property", detail: "Auto detect interface: true / false" },
    { label: "mtu", type: "property", detail: "MTU value" },
    { label: "inet4-address", type: "property", detail: "IPv4 address range" },
    { label: "inet6-address", type: "property", detail: "IPv6 address range" },
    { label: "strict-route", type: "property", detail: "Strict route: true / false" },
    { label: "endpoint-independent-nat", type: "property", detail: "Endpoint-independent NAT: true / false" },
    { label: "udp-timeout", type: "property", detail: "UDP timeout" },
    { label: "dns", type: "keyword", detail: "DNS configuration" },
    { label: "nameserver", type: "property", detail: "DNS upstream servers" },
    { label: "fallback", type: "property", detail: "Fallback DNS servers" },
    { label: "fallback-filter", type: "property", detail: "Fallback filter configuration" },
    { label: "default-nameserver", type: "property", detail: "Default DNS servers" },
    { label: "nameserver-policy", type: "property", detail: "DNS by domain name" },
    { label: "proxy-server-nameserver", type: "property", detail: "Proxy DNS servers" },
    { label: "use-hosts", type: "property", detail: "Use hosts: true / false" },
    { label: "enhanced-mode", type: "property", detail: "DNS mode: normal / redir-host / fake-ip" },
    { label: "fake-ip-range", type: "property", detail: "Fake-IP address range" },
    { label: "fake-ip-filter", type: "property", detail: "Fake-IP filter domains" },
    { label: "type", type: "type", detail: "ss / ssr / vmess / trojan / snell / http / socks5 / hysteria / vless / tuic / wireguard" },
    { label: "server", type: "property", detail: "Server address" },
    { label: "name", type: "property", detail: "Proxy name" },
    { label: "password", type: "property", detail: "Password" },
    { label: "cipher", type: "property", detail: "Encryption method" },
    { label: "udp", type: "property", detail: "UDP relay: true / false" },
    { label: "xudp", type: "property", detail: "XUDP mode" },
    { label: "tfo", type: "property", detail: "TCP Fast Open: true / false" },
    { label: "mptcp", type: "property", detail: "Multipath TCP: true / false" },
    { label: "skip-cert-verify", type: "property", detail: "Skip certificate verification: true / false" },
    { label: "sni", type: "property", detail: "TLS SNI" },
    { label: "alpn", type: "property", detail: "TLS ALPN protocol list" },
    { label: "fingerprint", type: "property", detail: "TLS fingerprint" },
    { label: "client-fingerprint", type: "property", detail: "Client fingerprint" },
    { label: "servername", type: "property", detail: "TLS server name" },
    { label: "network", type: "property", detail: "Transport: tcp / ws / grpc / http" },
    { label: "plugin", type: "property", detail: "Plugin: obfs / v2ray-plugin etc." },
    { label: "plugin-opts", type: "property", detail: "Plugin options" },
    { label: "smux", type: "property", detail: "Connection multiplexing config" },
    { label: "proxy-groups", type: "class", detail: "Proxy group list" },
    { label: "proxies", type: "property", detail: "Sub-proxy/sub-group name list" },
    { label: "url", type: "property", detail: "Health check URL" },
    { label: "interval", type: "property", detail: "Check interval (seconds)" },
    { label: "timeout", type: "property", detail: "Check timeout (ms)" },
    { label: "lazy", type: "property", detail: "Lazy loading: true / false" },
    { label: "strategy", type: "property", detail: "Load balance strategy: consistent-hashing / round-robin" },
    { label: "max-failed-times", type: "property", detail: "Max failed times" },
    { label: "tolerance", type: "property", detail: "Latency tolerance (ms)" },
    { label: "disable-udp", type: "property", detail: "Disable UDP: true / false" },
    { label: "hidden", type: "property", detail: "Hidden: true / false" },
    { label: "icon", type: "property", detail: "Icon URL" },
    { label: "filter", type: "property", detail: "Node filter" },
    { label: "exclude-filter", type: "property", detail: "Exclude filter" },
    { label: "exclude-type", type: "property", detail: "Exclude type" },
    { label: "DOMAIN", type: "keyword", info: "Domain name" },
    { label: "DOMAIN-SUFFIX", type: "keyword", info: "Domain suffix" },
    { label: "DOMAIN-KEYWORD", type: "keyword", info: "Domain keyword" },
    { label: "DOMAIN-REGEX", type: "keyword", info: "Domain regex" },
    { label: "GEOSITE", type: "keyword", info: "GeoSite category" },
    { label: "GEOIP", type: "keyword", info: "Country/region code" },
    { label: "IP-CIDR", type: "keyword", info: "IP CIDR range" },
    { label: "IP-CIDR6", type: "keyword", info: "IPv6 CIDR range" },
    { label: "IP-ASN", type: "keyword", info: "ASN number" },
    { label: "SRC-IP-CIDR", type: "keyword", info: "Source IP CIDR" },
    { label: "SRC-PORT", type: "keyword", info: "Source port" },
    { label: "DST-PORT", type: "keyword", info: "Destination port" },
    { label: "PROCESS-NAME", type: "keyword", info: "Process name" },
    { label: "PROCESS-PATH", type: "keyword", info: "Process path" },
    { label: "RULE-SET", type: "keyword", info: "Rule set name" },
    { label: "AND", type: "keyword", info: "Logical AND" },
    { label: "OR", type: "keyword", info: "Logical OR" },
    { label: "NOT", type: "keyword", info: "Logical NOT" },
    { label: "MATCH", type: "keyword", info: "Match all (fallback)" },
    { label: "no-resolve", type: "keyword", info: "Rule modifier: skip DNS resolution" },
    { label: "proxy-providers", type: "class", detail: "Proxy provider configuration" },
    { label: "rule-providers", type: "class", detail: "Rule provider configuration" },
    { label: "behavior", type: "property", detail: "Behavior: classical / ipcidr / domain" },
    { label: "path", type: "property", detail: "Local path" },
    { label: "format", type: "property", detail: "Format: yaml / text / mrs" },
    { label: "health-check", type: "property", detail: "Health check configuration" },
]

// ============================================================
// Mihomo config snippet templates (based on default.yaml)
// ============================================================
const mihomoSnippets = [
    // --- Basic configuration ---
    snippetCompletion("mixed-port: #{1}\nmode: #{2}\nlog-level: #{3}\nallow-lan: #{4}\nbind-address: \"#{5}\"\nipv6: #{6}\nexternal-controller: 0.0.0.0:9093\n#{}", {
        label: "config-base", type: "snippet", detail: "Basic configuration"
    }),

    // --- Node templates ---
    snippetCompletion("- name: \"#{1}\"\n  type: ss\n  server: \"#{2}\"\n  port: #{3}\n  cipher: #{4}\n  password: \"#{5}\"\n  # udp: true\n  # plugin: obfs\n  # plugin-opts:\n  #   mode: tls\n  #   host: bing.com\n  # client-fingerprint: chrome\n  # smux:\n  #   enabled: false\n#{}", {
        label: "ss-template", type: "snippet", detail: "Shadowsocks node"
    }),
    snippetCompletion("- name: \"#{1}\"\n  type: ssr\n  server: \"#{2}\"\n  port: #{3}\n  cipher: #{4}\n  password: \"#{5}\"\n  obfs: #{6}\n  protocol: #{7}\n  # obfs-param: \"\"\n  # protocol-param: \"\"\n  # udp: true\n#{}", {
        label: "ssr-template", type: "snippet", detail: "ShadowsocksR node"
    }),
    snippetCompletion("- name: \"#{1}\"\n  type: vmess\n  server: \"#{2}\"\n  port: #{3}\n  uuid: \"#{4}\"\n  alterId: #{5}\n  cipher: auto\n  # udp: true\n  # network: ws\n  # tls: true\n  # servername: \"\"\n  # skip-cert-verify: false\n  # client-fingerprint: chrome\n  # ws-opts:\n  #   path: /\n  #   headers:\n  #     Host: \"\"\n#{}", {
        label: "vmess-template", type: "snippet", detail: "VMess node"
    }),
    snippetCompletion("- name: \"#{1}\"\n  type: vmess\n  server: \"#{2}\"\n  port: #{3}\n  uuid: \"#{4}\"\n  alterId: 0\n  cipher: auto\n  network: grpc\n  tls: true\n  servername: \"#{5}\"\n  # skip-cert-verify: false\n  # client-fingerprint: chrome\n  grpc-opts:\n    grpc-service-name: \"#{6}\"\n#{}", {
        label: "vmess-grpc", type: "snippet", detail: "VMess gRPC node"
    }),
    snippetCompletion("- name: \"#{1}\"\n  type: trojan\n  server: \"#{2}\"\n  port: #{3}\n  password: \"#{4}\"\n  # udp: true\n  # sni: \"\"\n  # skip-cert-verify: false\n  # client-fingerprint: chrome\n  # network: ws\n  # ws-opts:\n  #   path: /\n#{}", {
        label: "trojan-template", type: "snippet", detail: "Trojan node"
    }),
    snippetCompletion("- name: \"#{1}\"\n  type: vless\n  server: \"#{2}\"\n  port: #{3}\n  uuid: \"#{4}\"\n  # udp: true\n  # network: tcp\n  # tls: true\n  # servername: \"\"\n  # flow: xtls-rprx-vision\n  # client-fingerprint: chrome\n  # reality-opts:\n  #   public-key: \"\"\n  #   short-id: \"\"\n#{}", {
        label: "vless-template", type: "snippet", detail: "VLESS node"
    }),
    snippetCompletion("- name: \"#{1}\"\n  type: vless\n  server: \"#{2}\"\n  port: #{3}\n  uuid: \"#{4}\"\n  network: tcp\n  tls: true\n  udp: true\n  flow: xtls-rprx-vision\n  client-fingerprint: chrome\n  servername: \"#{5}\"\n  reality-opts:\n    public-key: \"#{6}\"\n    short-id: \"#{7}\"\n#{}", {
        label: "vless-reality", type: "snippet", detail: "VLESS REALITY node"
    }),
    snippetCompletion("- name: \"#{1}\"\n  type: hysteria2\n  server: \"#{2}\"\n  port: #{3}\n  password: \"#{4}\"\n  # up: \"30 Mbps\"\n  # down: \"200 Mbps\"\n  # sni: \"\"\n  # skip-cert-verify: false\n  # obfs: salamander\n  # obfs-password: \"\"\n#{}", {
        label: "hysteria2-template", type: "snippet", detail: "Hysteria2 node"
    }),
    snippetCompletion("- name: \"#{1}\"\n  type: tuic\n  server: \"#{2}\"\n  port: #{3}\n  uuid: \"#{4}\"\n  password: \"#{5}\"\n  # udp-relay-mode: native\n  # sni: \"\"\n  # skip-cert-verify: false\n  # alpn:\n  #   - h3\n  # congestion-controller: bbr\n#{}", {
        label: "tuic-template", type: "snippet", detail: "TUIC node"
    }),
    snippetCompletion("- name: \"#{1}\"\n  type: wireguard\n  server: \"#{2}\"\n  port: #{3}\n  ip: \"#{4}\"\n  # ipv6: \"\"\n  public-key: \"#{5}\"\n  private-key: \"#{6}\"\n  udp: true\n  # reserved: \"\"\n  # dialer-proxy: \"\"\n#{}", {
        label: "wireguard-template", type: "snippet", detail: "WireGuard node"
    }),
    snippetCompletion("- name: \"#{1}\"\n  type: socks5\n  server: \"#{2}\"\n  port: #{3}\n  # username: \"\"\n  # password: \"\"\n  # tls: true\n  # skip-cert-verify: true\n  # udp: true\n#{}", {
        label: "socks5-template", type: "snippet", detail: "SOCKS5 node"
    }),
    snippetCompletion("- name: \"#{1}\"\n  type: http\n  server: \"#{2}\"\n  port: #{3}\n  # username: \"\"\n  # password: \"\"\n  # tls: true\n  # skip-cert-verify: true\n#{}", {
        label: "http-template", type: "snippet", detail: "HTTP node"
    }),
    snippetCompletion("- name: \"#{1}\"\n  type: snell\n  server: \"#{2}\"\n  port: #{3}\n  psk: \"#{4}\"\n  version: #{5}\n  # udp: true\n  # obfs-opts:\n  #   mode: http\n  #   host: bing.com\n#{}", {
        label: "snell-template", type: "snippet", detail: "Snell node"
    }),
    snippetCompletion("- name: \"#{1}\"\n  type: hysteria\n  server: \"#{2}\"\n  port: #{3}\n  auth-str: \"#{4}\"\n  protocol: udp\n  up: \"#{5}\"\n  down: \"#{6}\"\n  # sni: \"\"\n  # skip-cert-verify: false\n  # alpn:\n  #   - h3\n#{}", {
        label: "hysteria-template", type: "snippet", detail: "Hysteria (v1) node"
    }),
    snippetCompletion("- name: \"#{1}\"\n  type: mieru\n  server: \"#{2}\"\n  port: #{3}\n  transport: TCP\n  username: \"#{4}\"\n  password: \"#{5}\"\n  udp: true\n  # multiplexing: MULTIPLEXING_LOW\n  # handshake-mode: HANDSHAKE_STANDARD\n#{}", {
        label: "mieru-template", type: "snippet", detail: "Mieru node"
    }),
    snippetCompletion("- name: \"#{1}\"\n  type: anytls\n  server: \"#{2}\"\n  port: #{3}\n  password: \"#{4}\"\n  # udp: true\n  # sni: \"\"\n  # skip-cert-verify: true\n  # client-fingerprint: chrome\n  # alpn:\n  #   - h2\n#{}", {
        label: "anytls-template", type: "snippet", detail: "AnyTLS node"
    }),
    snippetCompletion("- name: \"#{1}\"\n  type: trusttunnel\n  server: \"#{2}\"\n  port: #{3}\n  username: \"#{4}\"\n  password: \"#{5}\"\n  udp: true\n  # sni: \"\"\n  # skip-cert-verify: true\n  # client-fingerprint: chrome\n  # quic: true\n  # congestion-controller: bbr\n#{}", {
        label: "trusttunnel-template", type: "snippet", detail: "TrustTunnel node"
    }),
    snippetCompletion("- name: \"#{1}\"\n  type: sudoku\n  server: \"#{2}\"\n  port: #{3}\n  key: \"#{4}\"\n  aead-method: #{5}\n  # padding-min: 2\n  # padding-max: 7\n  # table-type: prefer_ascii\n  # httpmask:\n  #   disable: false\n  #   mode: legacy\n#{}", {
        label: "sudoku-template", type: "snippet", detail: "Sudoku node"
    }),
    snippetCompletion("- name: \"#{1}\"\n  type: openvpn\n  server: \"#{2}\"\n  port: #{3}\n  proto: udp\n  # username: \"\"\n  # password: \"\"\n  ca: |\n    -----BEGIN CERTIFICATE-----\n    ...\n    -----END CERTIFICATE-----\n  cert: |\n    -----BEGIN CERTIFICATE-----\n    ...\n    -----END CERTIFICATE-----\n  key: |\n    -----BEGIN PRIVATE KEY-----\n    ...\n    -----END PRIVATE KEY-----\n  udp: true\n#{}", {
        label: "openvpn-template", type: "snippet", detail: "OpenVPN node"
    }),
    snippetCompletion("- name: \"#{1}\"\n  type: ssh\n  server: \"#{2}\"\n  port: #{3}\n  username: \"#{4}\"\n  # password: \"\"\n  # privateKey: path\n#{}", {
        label: "ssh-template", type: "snippet", detail: "SSH node"
    }),
    snippetCompletion("- name: \"#{1}\"\n  type: dns\n#{}", {
        label: "dns-out-template", type: "snippet", detail: "DNS outbound"
    }),
    snippetCompletion("- name: \"#{1}\"\n  type: direct\n  # interface-name: en0\n  # routing-mark: 6667\n#{}", {
        label: "direct-template", type: "snippet", detail: "Direct outbound (custom interface)"
    }),

    // --- Proxy groups ---
    snippetCompletion("- name: \"#{1}\"\n  type: select\n  proxies:\n    - \"#{2}\"\n  # disable-udp: false\n#{}", {
        label: "group-select", type: "snippet", detail: "Select manual proxy group"
    }),
    snippetCompletion("- name: \"#{1}\"\n  type: url-test\n  proxies:\n    - \"#{2}\"\n  url: \"#{3}\"\n  interval: #{4}\n  # tolerance: 150\n  # lazy: true\n#{}", {
        label: "group-url-test", type: "snippet", detail: "URL-Test auto speed test group"
    }),
    snippetCompletion("- name: \"#{1}\"\n  type: fallback\n  proxies:\n    - \"#{2}\"\n  url: \"#{3}\"\n  interval: #{4}\n#{}", {
        label: "group-fallback", type: "snippet", detail: "Fallback failover group"
    }),
    snippetCompletion("- name: \"#{1}\"\n  type: load-balance\n  proxies:\n    - \"#{2}\"\n  url: \"#{3}\"\n  interval: #{4}\n  # strategy: consistent-hashing\n#{}", {
        label: "group-load-balance", type: "snippet", detail: "Load-Balance group"
    }),
    snippetCompletion("- name: \"#{1}\"\n  type: smart\n  proxies:\n    - \"#{2}\"\n  url: \"#{3}\"\n  interval: #{4}\n  # timeout: 5000\n  # max-failed-times: 3\n  # lazy: true\n  # disable-udp: false\n  # filter: \"HK|SG\"\n  # policy-priority: \"\"\n  # uselightgbm: false\n  # collectdata: false\n  # sample-rate: 1.0\n  # prefer-asn: false\n#{}", {
        label: "group-smart", type: "snippet", detail: "Smart selection group"
    }),

    // --- Rules ---
    snippetCompletion("- DOMAIN-SUFFIX,#{1},#{2}\n#{}", {
        label: "rule-domain-suffix", type: "snippet", detail: "Domain suffix rule"
    }),
    snippetCompletion("- DOMAIN,#{1},#{2}\n#{}", {
        label: "rule-domain", type: "snippet", detail: "Domain rule"
    }),
    snippetCompletion("- DOMAIN-KEYWORD,#{1},#{2}\n#{}", {
        label: "rule-domain-keyword", type: "snippet", detail: "Domain keyword rule"
    }),
    snippetCompletion("- GEOSITE,#{1},#{2}\n#{}", {
        label: "rule-geosite", type: "snippet", detail: "GeoSite rule"
    }),
    snippetCompletion("- GEOIP,#{1},#{2}\n#{}", {
        label: "rule-geoip", type: "snippet", detail: "GEOIP rule"
    }),
    snippetCompletion("- IP-CIDR,#{1},#{2}\n#{}", {
        label: "rule-ip-cidr", type: "snippet", detail: "IP-CIDR rule"
    }),
    snippetCompletion("- RULE-SET,#{1},#{2}\n#{}", {
        label: "rule-set", type: "snippet", detail: "RULE-SET rule"
    }),
    snippetCompletion("- MATCH,#{1}\n#{}", {
        label: "rule-match", type: "snippet", detail: "MATCH fallback rule"
    }),

    // --- DNS ---
    snippetCompletion("dns:\n  enable: #{1}\n  listen: 0.0.0.0:53\n  enhanced-mode: #{2}\n  default-nameserver:\n    - 114.114.114.114\n    - 8.8.8.8\n  nameserver:\n    - \"#{3}\"\n  # fallback:\n  #   - \"\"\n  # fallback-filter:\n  #   geoip: true\n  #   geoip-code: CN\n#{}", {
        label: "dns-template", type: "snippet", detail: "DNS configuration"
    }),
    snippetCompletion("nameserver-policy:\n  \"#{1}\":\n    - \"#{2}\"\n#{}", {
        label: "dns-nameserver-policy", type: "snippet", detail: "DNS nameserver-policy"
    }),

    // --- TUN ---
    snippetCompletion("tun:\n  enable: #{1}\n  stack: #{2}\n  device: utun\n  auto-route: #{3}\n  auto-detect-interface: #{4}\n  dns-hijack:\n    - any:53\n  # auto-redirect: false\n  # mtu: 9000\n#{}", {
        label: "tun-template", type: "snippet", detail: "TUN configuration"
    }),

    // --- proxy-provider ---
    snippetCompletion("proxy-providers:\n  #{1}:\n    type: http\n    url: \"#{2}\"\n    interval: #{3}\n    path: ./proxy_provider/#{1}.yaml\n    # proxy: DIRECT\n    # header:\n    #   User-Agent:\n    #     - \"mihomo/1.0\"\n    health-check:\n      enable: #{4}\n      url: https://cp.cloudflare.com/generate_204\n      interval: #{5}\n    # override:\n    #   skip-cert-verify: true\n    #   udp: true\n    # filter: \"HK|TW|SG\"\n    # exclude-filter: \"Expired|Traffic\"\n#{}", {
        label: "proxy-providers", type: "snippet", detail: "Proxy provider configuration"
    }),

    // --- rule-provider ---
    snippetCompletion("rule-providers:\n  #{1}:\n    type: http\n    behavior: #{2}\n    url: \"#{3}\"\n    interval: #{4}\n    path: ./rule_provider/#{1}.#{5}\n    format: #{6}\n#{}", {
        label: "rule-providers", type: "snippet", detail: "Rule provider configuration"
    }),
    snippetCompletion("rule-providers:\n  #{1}:\n    type: file\n    behavior: #{2}\n    path: /path/to/#{1}.yaml\n    format: #{3}\n#{}", {
        label: "rule-providers-file", type: "snippet", detail: "Rule provider (local file)"
    }),
    snippetCompletion("rule-providers:\n  #{1}:\n    type: inline\n    behavior: #{2}\n    payload:\n      - '#{3}'\n#{}", {
        label: "rule-providers-inline", type: "snippet", detail: "Rule provider (inline)"
    }),

    // --- hosts ---
    snippetCompletion("hosts:\n  '#{1}': #{2}\n  # '*.: 127.0.0.1\n  # 'alpha..': '::1'\n  # 'baidu.com': google.com\n#{}", {
        label: "hosts", type: "snippet", detail: "Custom hosts mapping"
    }),

    // --- fake-ip-filter ---
    snippetCompletion("fake-ip-filter:\n  - '#{1}'\n  - '+.#{2}'\n  # - rule-set:fakeip-filter\n  # - geosite:fakeip-filter\n  # - '*.lan'\n  # - localhost.ptlogin2.qq.com\n#{}", {
        label: "fake-ip-filter", type: "snippet", detail: "Fake-IP filter list"
    }),

    // --- sniffer ---
    snippetCompletion("sniffer:\n  enable: #{1}\n  override-destination: #{2}\n  sniff:\n    TLS:\n      ports: [443]\n    HTTP:\n      ports: [80, 8080-8880]\n      override-destination: true\n    QUIC:\n      ports: [443]\n  # force-domain:\n  #   - +.v2ex.com\n  # skip-domain:\n  #   - Mijia Cloud\n  # parse-pure-ip: true\n  # force-dns-mapping: true\n#{}", {
        label: "sniffer", type: "snippet", detail: "Domain sniffing configuration"
    }),

    // --- dns (enhanced) ---
    snippetCompletion("dns:\n  enable: #{1}\n  enhanced-mode: #{2}\n  listen: 0.0.0.0:53\n  ipv6: #{3}\n  default-nameserver:\n    - 114.114.114.114\n    - 8.8.8.8\n  nameserver:\n    - 114.114.114.114\n    - tls://223.5.5.5:853\n    - https://doh.pub/dns-query\n  # fallback:\n  #   - tls://1.1.1.1\n  # fallback-filter:\n  #   geoip: true\n  #   geoip-code: CN\n  # proxy-server-nameserver:\n  #   - https://doh.pub/dns-query\n  # respect-rules: false\n#{}", {
        label: "dns", type: "snippet", detail: "DNS configuration"
    }),

    // --- nameserver-policy (enhanced) ---
    snippetCompletion("nameserver-policy:\n  \"#{1}\":\n    - \"#{2}\"\n  # \"geosite:cn,private,apple\":\n  #   - https://doh.pub/dns-query\n  #   - https://dns.alidns.com/dns-query\n  # \"geosite:category-ads-all\": rcode://success\n  # \"rule-set:global,dns\": 8.8.8.8\n#{}", {
        label: "nameserver-policy", type: "snippet", detail: "DNS by domain/geo/rule-set"
    }),

    // --- fallback-filter ---
    snippetCompletion("fallback-filter:\n  geoip: #{1}\n  geoip-code: #{2}\n  ipcidr:\n    - 240.0.0.0/4\n    - 0.0.0.0/32\n  # domain:\n  #   - '+.google.com'\n  #   - '+.facebook.com'\n#{}", {
        label: "fallback-filter", type: "snippet", detail: "DNS fallback filter criteria"
    }),

    // --- TUN ---
    snippetCompletion("tun:\n  enable: #{1}\n  stack: #{2}\n  device: utun\n  auto-route: #{3}\n  auto-detect-interface: #{4}\n  dns-hijack:\n    - any:53\n  # auto-redirect: false\n  # mtu: 9000\n  # strict-route: true\n  # endpoint-independent-nat: false\n#{}", {
        label: "tun", type: "snippet", detail: "TUN mode configuration"
    }),

    // --- authentication ---
    snippetCompletion("authentication:\n  - \"#{1}:#{2}\"\n#{}", {
        label: "authentication", type: "snippet", detail: "HTTP/SOCKS authentication"
    }),

    // --- geox-url ---
    snippetCompletion("geox-url:\n  geoip: \"#{1}\"\n  geosite: \"#{2}\"\n  mmdb: \"#{3}\"\n#{}", {
        label: "geox-url", type: "snippet", detail: "Custom GEO data source URL"
    }),

    // --- profile ---
    snippetCompletion("profile:\n  store-selected: #{1}\n  store-fake-ip: #{2}\n#{}", {
        label: "profile", type: "snippet", detail: "Persistent storage configuration"
    }),

    // --- proxy-groups with use/filter ---
    snippetCompletion("- name: \"#{1}\"\n  type: select\n  use:\n    - #{2}\n  # filter: \"HK|SG\"\n  # exclude-filter: \"Expired|Traffic\"\n  proxies:\n    - DIRECT\n#{}", {
        label: "proxy-group-use", type: "snippet", detail: "Proxy group (reference provider)"
    }),

    // --- listeners ---
    snippetCompletion("listeners:\n  - name: socks5-in\n    type: socks\n    port: #{1}\n    # listen: 0.0.0.0\n    # udp: true\n#{}", {
        label: "listener-socks", type: "snippet", detail: "SOCKS5 inbound"
    }),
    snippetCompletion("listeners:\n  - name: http-in\n    type: http\n    port: #{1}\n    # listen: 0.0.0.0\n#{}", {
        label: "listener-http", type: "snippet", detail: "HTTP inbound"
    }),
    snippetCompletion("listeners:\n  - name: mixed-in\n    type: mixed\n    port: #{1}\n    # listen: 0.0.0.0\n    # udp: true\n    # users:\n    #   - username: aaa\n    #     password: aaa\n#{}", {
        label: "listener-mixed", type: "snippet", detail: "HTTP/SOCKS mixed inbound"
    }),
    snippetCompletion("listeners:\n  - name: tun-in\n    type: tun\n    # stack: system\n    # dns-hijack:\n    #   - 0.0.0.0:53\n    # auto-route: true\n    # mtu: 9000\n#{}", {
        label: "listener-tun", type: "snippet", detail: "TUN inbound"
    }),

    // --- sub-rules ---
    snippetCompletion("sub-rules:\n  #{1}:\n    - DOMAIN,#{2},#{3}\n    - DOMAIN-SUFFIX,#{4},#{5}\n    - IP-CIDR,#{6},#{7}\n    - MATCH,#{8}\n#{}", {
        label: "sub-rules", type: "snippet", detail: "Sub-rule set definition"
    }),

    // --- tunnels ---
    snippetCompletion("tunnels:\n  - tcp/udp,127.0.0.1:#{1},#{2}:#{3},#{4}\n#{}", {
        label: "tunnels", type: "snippet", detail: "Tunnel forwarding (short format)"
    }),
    snippetCompletion("tunnels:\n  - network: [tcp, udp]\n    address: 127.0.0.1:#{1}\n    target: #{2}:#{3}\n    proxy: #{4}\n#{}", {
        label: "tunnels-full", type: "snippet", detail: "Tunnel forwarding (full format)"
    }),

    // --- additional node types ---
    snippetCompletion("- name: \"#{1}\"\n  type: masque\n  server: \"#{2}\"\n  port: #{3}\n  public-key: \"#{4}\"\n  private-key: \"#{5}\"\n  ip: \"#{6}\"\n  udp: true\n  # network: h3 # h3 / h2 / h3-l4proxy\n  # dialer-proxy: \"\"\n#{}", {
        label: "masque-template", type: "snippet", detail: "MASQUE node"
    }),
    snippetCompletion("- name: \"#{1}\"\n  type: rematch\n  target-rematch-name: \"#{2}\"\n  # target-sub-rule: \"\"\n#{}", {
        label: "rematch-template", type: "snippet", detail: "Rematch node"
    }),
    snippetCompletion("- name: \"#{1}\"\n  type: gost-relay\n  server: \"#{2}\"\n  port: #{3}\n  udp: true\n  tls: true\n  # mux: true\n  # username: \"\"\n  # password: \"\"\n#{}", {
        label: "gost-relay-template", type: "snippet", detail: "GOST Relay node"
    }),
]

function mihomoCompletion(context) {
    const word = context.matchBefore(/[\w-]+/)
    if (!word || (word.from === word.to && !context.explicit)) return null
    const filtered = mihomoKeywords.filter(k =>
        k.label.toLowerCase().startsWith(word.text.toLowerCase())
    )
    const snippets = mihomoSnippets.filter(s => {
        const label = (s.label || s.name || '')
        return label.toLowerCase().startsWith(word.text.toLowerCase())
    })
    const options = [...filtered, ...snippets]
    if (!options.length) return null
    return { from: word.from, options, validFor: /^[\w-]*$/ }
}

function yamlLinter() {
    return linter(view => {
        const diagnostics = []
        try { loadAll(view.state.doc.toString(), { schema: YAML11_SCHEMA }) } catch (e) {
            const mark = e.mark
            if (mark && mark.line !== undefined) {
                const lineNo = mark.line + 1
                if (lineNo <= view.state.doc.lines) {
                    const line = view.state.doc.line(lineNo)
                    const pos = Math.min(line.from + (mark.column || 0), line.to)
                    diagnostics.push({ from: pos, to: Math.min(pos + 1, line.to), severity: "error", message: e.reason || e.message })
                }
            } else {
                diagnostics.push({ from: 0, to: 0, severity: "error", message: e.reason || e.message })
            }
        }
        return diagnostics
    })
}

var _levelTagMap = null
var _levelRegex = null
function _buildLevelCache() {
    if (!window.levelTranslations) { _levelTagMap = {}; _levelRegex = /(?!)/; return }
    var map = {}, parts = []
    for (var key in window.levelTranslations) {
        if (window.levelTranslations.hasOwnProperty(key)) {
            var text = window.levelTranslations[key]
            map[text] = key
            parts.push(text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'))
        }
    }
    _levelTagMap = map
    _levelRegex = new RegExp('^\\[(' + parts.join('|') + ')\\]')
}

const logLanguage = StreamLanguage.define({
    tokenTable: {
        timestamp: logTag.timestamp,
        bracket: logTag.bracket,
        category: logTag.category,
        logString: logTag.logString,
        logLink: logTag.logLink,
        levelInfo: logTag.levelInfo,
        levelWarning: logTag.levelWarning,
        levelError: logTag.levelError,
        levelDebug: logTag.levelDebug,
        levelTip: logTag.levelTip,
        levelFatal: logTag.levelFatal,
        levelWatchdog: logTag.levelWatchdog,
    },
    startState() { return { tabDone: false } },
    token(stream, state) {
        if (stream.sol()) {
            state.tabDone = false
            if (stream.match(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/)) return "timestamp"
        }
        if (stream.eatSpace()) return null
        var ch = stream.peek()
        if (!ch) { stream.skipToEnd(); return null }
        if (ch === '\u3010' && stream.match(/\u3010[^\u3011]*\u3011/)) return "bracket"
        if (state.tabDone) { stream.next(); return "logString" }
        if (ch === '[') {
            if (_levelTagMap === null) _buildLevelCache()
            var levelMatch = stream.match(_levelRegex)
            if (levelMatch) {
                var levelKey = _levelTagMap[levelMatch[1]]
                if (levelKey) {
                    var styleName = 'level' + levelKey.charAt(0).toUpperCase() + levelKey.slice(1)
                    if (logTag[styleName]) return styleName
                }
                return "category"
            }
            if (stream.match(/\[[A-Z][^\]]*\]/)) return "category"
        }
        if (ch !== '[') { state.tabDone = true }
        stream.next()
        return "logString"
    }
})

const logHighlightStyle = HighlightStyle.define([
    { tag: logTag.timestamp, class: "cmt-log-timestamp" },
    { tag: logTag.bracket, class: "cmt-log-bracket" },
    { tag: logTag.category, class: "cmt-log-category" },
    { tag: logTag.logString, class: "cmt-log-string" },
    { tag: logTag.logLink, class: "cmt-log-link" },
    { tag: logTag.levelInfo, class: "cmt-log-level-info" },
    { tag: logTag.levelWarning, class: "cmt-log-level-warning" },
    { tag: logTag.levelError, class: "cmt-log-level-error" },
    { tag: logTag.levelDebug, class: "cmt-log-level-debug" },
    { tag: logTag.levelTip, class: "cmt-log-level-tip" },
    { tag: logTag.levelFatal, class: "cmt-log-level-fatal" },
    { tag: logTag.levelWatchdog, class: "cmt-log-level-watchdog" },
])

function baseExtensions(extra = []) {
    return [
        lineNumbers(), highlightActiveLine(), highlightActiveLineGutter(),
        highlightSpecialChars(), drawSelection(), dropCursor(),
        rectangularSelection(), crosshairCursor(),
        bracketMatching(), foldGutter({ placeholderDOM: null }),
        indentOnInput(), history(),
        highlightSelectionMatches(), EditorView.lineWrapping,
        closeBrackets(),
        cmKeymap.of([...defaultKeymap, ...historyKeymap, ...searchKeymap, ...closeBracketsKeymap, ...foldKeymap, { key: 'Tab', run: function(v) { return acceptCompletion(v) || indentMore(v) } }]),
        ...extra
    ]
}

// ============================================================
// Custom indentation markers
// Fixes left:2px→6px: @codemirror/view >=~6.29 changed .cm-line
// padding from "0 2px" to "0 2px 0 6px".
// The ::before pseudo-element fills the full line height (no gaps)
// but is capped at one visual row (--oc-lh) so it never bleeds
// through wrapped text on long lines.
// ============================================================

const _ocImBaseTheme = EditorView.baseTheme({
    '.cm-line': { position: 'relative' },
    '.cm-oc-im::before': {
        content: '""',
        position: 'absolute',
        top: 0,
        left: '6px',
        right: 0,
        height: 'var(--oc-lh, 100%)',
        background: 'var(--oc-im)',
        pointerEvents: 'none',
        zIndex: '-1',
    },
    '&light': { '--oc-im-c': '#e1e4e8', '--oc-im-ca': '#d0d7de' },
    '&dark':  { '--oc-im-c': '#30363d', '--oc-im-ca': '#484f58' },
})

function _ocImIndent(text, ts) {
    let n = 0
    for (let i = 0; i < text.length; i++) {
        if (text[i] === ' ') n++
        else if (text[i] === '\t') n += ts
        else break
    }
    return n
}

function _foldDepth(state, fl, ll, doc) {
    var ranges = []
    for (var n = fl; n <= ll; n++) {
        var fr = foldable(state, doc.line(n).from, doc.line(n).to)
        if (fr) ranges.push({ from: fr.from, to: fr.to })
    }

    var depths = new Int32Array(ll - fl + 1)
    for (var n = fl; n <= ll; n++) {
        var pos = doc.line(n).from, d = 0
        for (var i = 0; i < ranges.length; i++)
            if (ranges[i].from < pos && pos < ranges[i].to) d++
        depths[n - fl] = d
    }
    return depths
}

function _foldDepth1(state, lineNo, fl, ll, doc) {
    var pos = doc.line(lineNo).from, d = 0
    for (var n = fl; n <= ll; n++) {
        var fr = foldable(state, doc.line(n).from, doc.line(n).to)
        if (fr && fr.from < pos && pos < fr.to) d++
    }
    return d
}

function indentMarkerExtension({ highlightActiveBlock = true, hideFirstIndent = false, thickness = 1, colors } = {}) {
    var extra = colors ? EditorView.baseTheme({
        '&light': { '--oc-im-c': colors.light || '#e1e4e8', '--oc-im-ca': colors.activeLight || '#d0d7de' },
        '&dark':  { '--oc-im-c': colors.dark  || '#30363d', '--oc-im-ca': colors.activeDark  || '#484f58' },
    }) : []

    return [
        _ocImBaseTheme,
        extra,
        ViewPlugin.fromClass(class {
            constructor(view) {
                this._view = view
                this._stepPx = null
                this._measurePending = false
                this.decorations = this._build(view)
                this._scheduleMeasure(view)
            }

            update(u) {
                this._view = u.view
                var needsRebuild = u.docChanged || u.viewportChanged ||
                    (highlightActiveBlock && u.selectionSet)
                if (needsRebuild) {
                    this._stepPx = null
                    this._measurePending = false
                    this.decorations = this._build(u.view)
                    this._scheduleMeasure(u.view)
                } else if (this._measurePending) {
                    this._measurePending = false
                    this.decorations = this._build(u.view)
                }
            }

            _scheduleMeasure(view) {
                if (this._measureId !== undefined) view.cancelMeasure(this._measureId)
                this._measureId = view.requestMeasure(this._mkSpec())
            }

            _mkSpec() {
                var self = this
                return {
                    read: function(view) {
                        var state = view.state, iw = getIndentUnit(state), ts = state.tabSize, doc = state.doc
                        var fl = doc.lineAt(view.viewport.from).number
                        var ll = doc.lineAt(view.viewport.to).number

                        var hasIndent = false
                        for (var n = fl; n <= ll; n++) {
                            if (_ocImIndent(doc.line(n).text, ts) >= iw) { hasIndent = true; break }
                        }

                        var stepPx = 0, lineHeight = 0

                        if (hasIndent) {
                            for (var n = fl; n <= ll; n++) {
                                var t = doc.line(n).text
                                if (t.trim() === '') continue
                                if (_ocImIndent(t, ts) >= iw) {
                                    var c0 = view.coordsAtPos(doc.line(n).from)
                                    var c1 = view.coordsAtPos(doc.line(n).from + iw)
                                    if (c0 && c1) { stepPx = Math.round((c1.left - c0.left) * 100) / 100; break }
                                }
                            }
                        }

                        if (fl < doc.lines) {
                            var c0 = view.coordsAtPos(doc.line(fl).from)
                            var c1 = view.coordsAtPos(doc.line(fl + 1).from)
                            if (c0 && c1) lineHeight = Math.round(c1.top - c0.top)
                        }

                        return lineHeight > 0
                            ? { stepPx: stepPx > 0 ? stepPx : -1, lineHeight: lineHeight }
                            : (stepPx > 0 ? stepPx : -1)
                    },
                    write: function(result) {
                        var stepPx, lineHeight
                        if (typeof result === 'number') {
                            stepPx = result; lineHeight = 0
                        } else if (result) {
                            stepPx = result.stepPx; lineHeight = result.lineHeight || 0
                        } else {
                            stepPx = -1; lineHeight = 0
                        }
                        if (typeof stepPx === 'number') {
                            self._stepPx = stepPx > 0 ? stepPx : -1
                            self._lineHeight = lineHeight
                            self._measurePending = true
                            var v = self._view
                            // Defer dispatch past the current update cycle
                            queueMicrotask(function() {
                                if (v && self._measurePending) v.dispatch({})
                            })
                        }
                    }
                }
            }

            _build(view) {
                var sa = hideFirstIndent ? 1 : 0
                var state = view.state
                var iw = getIndentUnit(state)
                var ts = state.tabSize
                var doc = state.doc
                var fl = doc.lineAt(view.viewport.from).number
                var ll = doc.lineAt(view.viewport.to).number
                var bl = Math.max(1, fl - 80), el = Math.min(doc.lines, ll + 80)

                var lvls = new Int32Array(el - bl + 1)
                var bk = new Uint8Array(el - bl + 1)
                for (var n = bl; n <= el; n++) {
                    var t = doc.line(n).text
                    var b = t.trim() === ''
                    bk[n - bl] = b ? 1 : 0
                    lvls[n - bl] = b ? -1 : Math.floor(_ocImIndent(t, ts) / iw)
                }
                for (var n = bl; n <= el; n++) {
                    if (!bk[n - bl]) continue
                    var p = 0, nx = 0
                    for (var x = n - 1; x >= bl; x--) if (!bk[x - bl]) { p = lvls[x - bl]; break }
                    for (var x = n + 1; x <= el; x++) if (!bk[x - bl]) { nx = lvls[x - bl]; break }
                    lvls[n - bl] = Math.min(p, nx)
                }

                var maxLvl = 0
                for (var n = fl; n <= ll; n++) {
                    var lv = lvls[n - bl]
                    if (lv > maxLvl) maxLvl = lv
                }
                if (maxLvl <= sa) return Decoration.none

                var scopeOpen = new Uint8Array(maxLvl)
                var showGuides = new Array(ll - fl + 1)

                for (var n = bl; n <= el; n++) {
                    var lv = lvls[n - bl]
                    var isBlank = bk[n - bl] === 1

                    if (!isBlank) {
                        for (var k = lv; k < maxLvl; k++) scopeOpen[k] = 0
                    }

                    if (n >= fl && n <= ll) {
                        var guides = new Uint8Array(maxLvl)
                        showGuides[n - fl] = guides
                        if (lv > sa) {
                            for (var k = sa; k < lv && k < maxLvl; k++) {
                                if (scopeOpen[k]) guides[k] = 1
                            }
                        }
                    }

                    if (!isBlank) {
                        var nextN = -1, nextLv = -1
                        for (var x = n + 1; x <= el; x++) {
                            if (!bk[x - bl]) { nextN = x; nextLv = lvls[x - bl]; break }
                        }
                        if (nextN >= 0 && nextLv > lv && lv < maxLvl) {
                            scopeOpen[lv] = 1
                        }
                    }
                }

                var activeLvl = undefined
                if (highlightActiveBlock) {
                    var cn = doc.lineAt(state.selection.main.head).number
                    if (cn >= fl && cn <= ll) {
                        var cl = lvls[cn - bl]
                        var cGuides = showGuides[cn - fl]
                        if (cGuides && cl > sa) {
                            for (var k = cl - 1; k >= sa; k--) {
                                if (cGuides[k]) { activeLvl = k; break }
                            }
                        }
                    }
                }

                var stepPx = this._stepPx
                if (stepPx === null || stepPx <= 0)
                    stepPx = iw * (view.defaultCharacterWidth || 8)
                var lh = this._lineHeight

                var builder = new RangeSetBuilder()
                for (var n = fl; n <= ll; n++) {
                    var guides = showGuides[n - fl]
                    if (!guides) continue
                    var parts = []
                    for (var k = sa; k < maxLvl; k++) {
                        if (!guides[k]) continue
                        var pos = Math.round(k * stepPx)
                        var cv = (activeLvl !== undefined && k === activeLvl)
                            ? 'var(--oc-im-ca)' : 'var(--oc-im-c)'
                        parts.push('linear-gradient(' + cv + ',' + cv + ') ' + pos + 'px 0/' + thickness + 'px 100% no-repeat')
                    }
                    if (!parts.length) continue
                    var line = doc.line(n)
                    var style = '--oc-im:' + parts.join(',')
                    if (lh > 0) style += ';--oc-lh:' + lh + 'px'
                    builder.add(line.from, line.from, Decoration.line({
                        class: 'cm-oc-im',
                        attributes: { style: style }
                    }))
                }
                return builder.finish()
            }
        }, { decorations: v => v.decorations })
    ]
}

function topSearchExtension() {
    return search({ top: true })
}

function placeholderExtension(text) {
    return placeholder(text)
}

const mergeDefaultConfig = {
    diffConfig: { scanLimit: 5000 },
    gutter: true,
    revertControls: "b-to-a",
    collapseUnchanged: false,
}

// ============================================================
// Theme compartment — allows dynamic light/dark switching
// ============================================================
const themeCompartment = new Compartment

function themeExtension(isDark) {
    return themeCompartment.of(isDark ? githubDark : githubLight)
}

function dispatchTheme(view, isDark) {
    view.dispatch({
        effects: themeCompartment.reconfigure(isDark ? githubDark : githubLight)
    })
}

// ============================================================
// Fullscreen utility
// ============================================================

function getActiveEditor() {
    var active = document.activeElement;
    if (active && active.closest) {
        var mw = active.closest('.cm-mergeView');
        if (mw) return mw;
        var ed = active.closest('.cm-editor');
        if (ed) return ed;
    }
    return document.querySelector('.cm-editor') || null;
}

function toggleFullscreen(dom) {
    if (!dom) return false;
    if (dom.classList.contains('cm-fullscreen')) {
        dom.classList.remove('cm-fullscreen');
        dom.id = '';
        return false;
    } else {
        dom.classList.add('cm-fullscreen');
        dom.id = 'oc-fullscreen-active';
        return true;
    }
}

// ============================================================
// Theme observer — watch data-darkmode on <html> for all CM6 editors
// ============================================================
var _themeObserverInstalled = false;

function startThemeObserver() {
    if (_themeObserverInstalled || typeof MutationObserver === 'undefined') return;
    _themeObserverInstalled = true;
    var observer = new MutationObserver(function() {
        var theme = localStorage.getItem('oc-theme') || 'auto';
        var isDark;
        if (theme === 'dark') isDark = true;
        else if (theme === 'light') isDark = false;
        else isDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
        switchHljsTheme(isDark);
        var editors = document.querySelectorAll('.cm-editor');
        for (var i = 0; i < editors.length; i++) {
            var view = editors[i].cmView && editors[i].cmView.view;
            if (view) {
                try { dispatchTheme(view, isDark); } catch(e) {}
            }
        }
    });
    observer.observe(document.body, { attributes: true, attributeFilter: ['data-darkmode'], subtree: true });
}

// ============================================================
// Markdown rendering (for debug log preview)
// ============================================================

var _hljsCSSInjected = false
function injectHljsCSS() {
    if (_hljsCSSInjected) return
    _hljsCSSInjected = true
    var theme = localStorage.getItem('oc-theme') || 'auto'
    var isDark
    if (theme === 'dark') isDark = true
    else if (theme === 'light') isDark = false
    else isDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches
    var style = document.createElement("style")
    style.id = "hljs-theme"
    style.textContent = isDark ? githubDarkCSS : githubLightCSS
    document.head.appendChild(style)
}

function switchHljsTheme(isDark) {
    if (!_hljsCSSInjected) { injectHljsCSS(); if (!_hljsCSSInjected) return }
    var style = document.getElementById("hljs-theme")
    if (style) style.textContent = isDark ? githubDarkCSS : githubLightCSS
}

function escapeHtml(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;")
}

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
                return '<pre><code class="hljs language-' + lang + '">' + result.value + '</code></pre>'
            }
            return '<pre><code>' + escapeHtml(token.text) + '</code></pre>'
        }
    }
})

function renderMarkdown(text) {
    if (!text) return ''
    try { return marked.parse(text) } catch(e) { return text }
}

export {
    EditorView, EditorState, Compartment,
    lineNumbers, highlightActiveLine, highlightActiveLineGutter,
    highlightSpecialChars, drawSelection, dropCursor,
    rectangularSelection, crosshairCursor, cmKeymap as keymap,
    defaultKeymap, history, historyKeymap, indentWithTab,
    toggleComment, foldKeymap,
    syntaxHighlighting, HighlightStyle, bracketMatching,
    foldGutter, indentOnInput, StreamLanguage, indentUnit,
    yaml, markdown, shell, properties,
    linter, lintGutter, yamlLinter,
    search, searchKeymap, highlightSelectionMatches,
    autocompletion, closeBrackets, closeBracketsKeymap,
    snippetCompletion, mihomoCompletion,
    githubDark, githubLight,
    MergeView,
    logLanguage, logHighlightStyle,
    baseExtensions, placeholderExtension, indentMarkerExtension,
    topSearchExtension, mergeDefaultConfig,
    themeExtension, dispatchTheme,
    startThemeObserver,
    renderMarkdown,
    getActiveEditor, toggleFullscreen
}
