## 插件设置：DNS、黑白名单、流媒体、外部控制与 IPv6

> **用途**: 插件设置页的 DNS、黑白名单、流媒体增强、外部控制与 IPv6 标签页（§9.1–9.5）。
> **LuCI 路径**: 服务 → OpenClash → 插件设置 → 对应标签页

### 9.1 DNS 设置标签页 (dns)

> **生效路径**: 三条独立路径——① `yml_change.sh` 改运行 YAML 的 `dns:`（内核使用）；② `change_dnsmasq()` 改系统 dnsmasq（LAN 客户端 DNS 被劫持到内核）；③ `openclash_custom_domain_dns.sh` 为自定义域名配独立 DNS。
> **排查**: DNS 劫持失败先看「运行状态」页的 DNS 端口是否在监听；dnsmasq 侧实现见 `init.d/openclash` 的 `change_dnsmasq()`。

| § | 项 (UCI key) | 默认 | 取值 / 文件 | 说明 |
|---|---|---|---|---|
| 9.1.1 | 本地 DNS 劫持 `enable_redirect_dns` | 1 | `0` 禁用 / `1` dnsmasq 转发 / `2` 防火墙重定向 | 行为见下表 |
| 9.1.2 | 清空 DNS 缓存按钮 | — | — | `POST /cache/fakeip/flush` + `/cache/dns/flush` |
| 9.1.3 | Dnsmasq 修复按钮 | — | — | 停止 OpenClash 后 DNS 异常时用：`noresolv=0`、`localuse=1`、恢复有效 `resolvfile`（无则写 `/tmp/resolv.conf.d/resolv.conf.auto`，含 119.29.29.29 / 8.8.8.8），重启 dnsmasq |
| 9.1.4 | 启用第二 DNS 服务器 `enable_custom_domain_dns_server` | 0 | — | 为 §9.1.6 列表指定专用 DNS，完全独立于内核 DNS |
| 9.1.5 | 指定服务器 `custom_domain_dns_server` | `114.114.114.114` | `IP` 或 `IP#端口` | 依赖 §9.1.4 |
| 9.1.6 | 自定义域名列表 `custom_domain_dns` | — | `openclash_custom_domain_dns.list` | 每行一个域名；列表内域名不返 Fake-IP，改用 §9.1.5 的服务器解析 |

**`enable_redirect_dns` 三种模式**（`dns_port` 默认 7874）：

| 值 | 做法 | 效果 |
|---|---|---|
| `1` dnsmasq 转发 | `change_dnsmasq()` 设 `dhcp.@dnsmasq[0].server=127.0.0.1#<dns_port>`、`noresolv=1`、`cachesize=0` | LAN 查询 → dnsmasq → 内核；沿用 dnsmasq 缓存与分流 |
| `2` 防火墙重定向 | 建 `openclash_dns_redirect` 链，把 dport 53 的 UDP/TCP DNAT 到 `dns_port` | 跳过 dnsmasq，更快；Fake-IP + LAN 访问控制可自动按设备分流 DNS |
| `0` 禁用 | 不改 dnsmasq、不建链 | 不做劫持，DNS 路径需用户自行保证 |

`revert_dnsmasq()` 在停止时还原 servers / noresolv / resolvfile / cachesize。规则细节（AC 过滤、路由器自身 OUTPUT 劫持）见 `06-firewall-options-dnsmasq.md` §6.2。

### 9.2 黑白名单标签页 (Black&White / lan_ac)

> **生效路径**: 完全在防火墙层实现，不改 YAML；匹配逻辑见 `init.d/openclash` 的 `firewall_lan_ac_traffic()` 与 `set_firewall()` 的 set 创建。
> **需要按接口/用户/DSCP 精细绕过**: 用 `10-settings-geo-misc-src.md` §10.3「来源流量访问控制」。

| § | 项 (UCI key) | 默认 | 取值 / 文件 | 说明 |
|---|---|---|---|---|
| 9.2.1 | 访问控制模式 `lan_ac_mode` | 0 | `0` 黑名单 / `1` 白名单 | 黑名单=列表内直连；白名单=仅列表内走代理 |
| 9.2.2 | 直连设备 IP `lan_ac_black_ips` | — | IP / CIDR 列表 | 依赖 `lan_ac_mode=0`；fw4 用 `ip saddr @openclash_lan_black_ip counter return` |
| 9.2.3 | 直连设备 MAC `lan_ac_black_macs` | — | MAC 列表 | fw4 用 `ether saddr`，fw3 用 `ipset hash:mac` |
| 9.2.4 | 代理设备 IP `lan_ac_white_ips` | — | IP / CIDR 列表 | 依赖 `lan_ac_mode=1` |
| 9.2.5 | 代理设备 MAC `lan_ac_white_macs` | — | MAC 列表 | 依赖 `lan_ac_mode=1` |
| 9.2.6 | WAN 直连 IP `wan_ac_black_ips` | — | IP / CIDR 列表 | Fake-IP 下仅对纯 IP 请求生效，域名请求需先配 Fake-IP-Filter |
| 9.2.7 | WAN 直连端口 `wan_ac_black_ports` | — | 端口或范围 | — |

- **集合维护**: 六个 `lan_ac_*` 集合启动时无条件创建（与列表是否为空无关）；运行状态页的逐设备分流由 `openclash_client_ac.sh` 热更新集合内容，不重建防火墙；只有切换 `lan_ac_mode` 才重建规则
- **匹配取反**: 黑白名单只改变 return 的方向（黑名单=命中即 return 直连，白名单=未命中即 return 直连）

**Fake-IP 下的 DNS 分流依赖**（Redir-Host 系列不受此限制）：

| `enable_redirect_dns` | Fake-IP + 访问控制 | 说明 |
|---|---|---|
| `2` 防火墙重定向 | 开箱可用 | 防火墙自动按设备分流 DNS |
| `0` 禁用 | 可用 | DNS 路径需自备（第三方转发或系统 DNS）；切换设备时卡片顶部提示：切为代理始终提示，切为直连仅在 Fake-IP 下提示 |
| `1` dnsmasq 转发 | 不可用 | 所有客户端都经内核拿 Fake-IP，直连设备会命中 fake-IP 段兜底重定向（不断网但被代理）→ 运行状态页锁定分流开关，需先点提示条改为防火墙转发 |

### 9.3 流媒体增强标签页 (stream_enhance)

> **生效路径**: `openclash_streaming_unlock.lua` 由看门狗 `openclash_watchdog.sh` 定期调用，测试解锁情况并用 `PUT /proxies/{group}` 自动切换策略组。该脚本只处理已配置服务的测试与切换，不涉及 Smart 策略。
> **流程**: 读 YAML 策略组与节点 → 逐节点请求服务域名 → 按响应码/页面内容判定解锁 → 切换策略组到可用节点 → 定期重测，节点失效自动换。

所有子选项依赖 `stream_auto_select=1`。

| 服务 | 启用 UCI | 默认 |
|------|----------|------|
| Netflix | `stream_auto_select_netflix` | 0 |
| Disney Plus | `stream_auto_select_disney` | 0 |
| HBO Max | `stream_auto_select_hbo_max` | 0 |
| YouTube Premium | `stream_auto_select_ytb` | 0 |
| TVB Anywhere+ | `stream_auto_select_tvb_anywhere` | 0 |
| DAZN | `stream_auto_select_dazn` | 0 |
| Prime Video | `stream_auto_select_prime_video` | 0 |
| Paramount Plus | `stream_auto_select_paramount_plus` | 0 |
| Discovery Plus | `stream_auto_select_discovery_plus` | 0 |
| Bilibili | `stream_auto_select_bilibili` | 0 |
| Google Not CN | `stream_auto_select_google_not_cn` | 0 |
| OpenAI | `stream_auto_select_openai` | 0 |
| Claude | `stream_auto_select_claude` | 0 |
| Gemini | `stream_auto_select_gemini` | 0 |

每个服务的子项：`stream_auto_select_group_key_<service>`（策略组正则）、`stream_auto_select_region_key_<service>`（解锁地区缩写）、`stream_auto_select_node_key_<service>`（节点名正则）、手动测试按钮（调用同一 Lua 脚本）。
Bilibili 额外有解锁地区选项：CN（仅大陆）/ HK/MO/TW（港澳台）/ TW（仅台湾）。

### 9.4 外部控制标签页 (Dashboard Settings / dashboard)

> **生效路径**: 选项写入 YAML 的 `external-controller` / `secret` / `external-ui` / `external-controller-cors`，由内核提供 HTTP API；下载切换由 `openclash_download_dashboard.sh` 执行（从 GitHub Releases 取 yacd / metacubexd / zashboard，解压到 `/usr/share/openclash/ui`）。

| 选项 | UCI Key | 默认 | 说明 |
|------|---------|------|------|
| 管理页面端口 | `cn_port` | 9090 | 写入 `external-controller: 0.0.0.0:9090` |
| 管理页面登录密钥 | `dashboard_password` | 空 | 写入 `secret`，留空不验证 |
| 管理页面公网域名/地址 | `dashboard_forward_domain` | 空 | 公网访问用的域名或 IP（含 IPv6 如 `[2001:db8::1]`），**不带 `http://` 前缀**，可内嵌端口 |
| 管理页面映射端口 | `dashboard_forward_port` | 空 | 留空时默认 443（启用 SSL）或 80 |
| 管理页面公网 SSL 访问 | `dashboard_forward_ssl` | 0 | 决定公网协议（0=http / 1=https）与默认端口 |
| 自定义仪表盘地址 | `dashboard_custom_url` | 空 | 完整 HTTP(S) URL，用于外部托管面板；OpenClash 追加 hostname/端口/secret 参数，不追加本地 UI 路径；hash 路由面板需自带 `#/setup` 之类片段 |
| 仪表盘兼容模式 | `dashboard_custom_clash_compatible` | 0 | 仅配了 `dashboard_custom_url` 时生效：用 `#/?host=...` 兼容参数而非标准 hostname 参数 |

- **CORS**: `yml_change.sh` 按 `dashboard_custom_url` > `dashboard_forward_domain`+`dashboard_forward_port`+`dashboard_forward_ssl` 的优先级算出 origin，写入 `external-controller-cors.allow-origins` 并设 `allow-private-network=true`；算不出合法 origin 则不写该段
- **前端 URL 构造**（`status.htm` + `common.js` 的 `ocGetDashboardBaseURL` / `ocGetDashboardWebSocketOrigin` / `ocGetDashboardLoginParams` / `ocBuildExternalDashboardURL`）：优先用浏览器 hostname 匹配 LAN IP，否则用公网地址，最后回退 LAN IP + `cn_port`；配了 `dashboard_custom_url` 时运行状态页多一个 **External Dashboard** 按钮，复制控制面板地址也优先用它
- **子路径**: `/ui/dashboard/`、`/ui/yacd/`、`/ui/metacubexd/`、`/ui/zashboard/`

### 9.5 IPv6 设置标签页 (ipv6)

> **不建议**为路由器开启 IPv6。该方案面向**主路由拨号环境**（需运营商支持 IPv6-PD）；旁路由必须按 §9.5.1 配置客户端地址来源与网关，否则会出现「国内 IPv6 不通」或「IPv6 绕过代理」。
> **生效路径**: `yml_change.sh` 写 `ipv6` / `dns.ipv6` / `dns.fake-ip-range6`；`set_firewall()` 生成独立的 IPv6 链（`openclash_v6`、`openclash_mangle_v6` 等），与 IPv4 互不影响。
> **DNS 最佳实践**: AAAA 查询可走 IPv4 链路，无需 IPv6 DNS。做法：LAN DHCP **不下发 IPv6 DNS**（设备仍用路由器 IPv4 地址解析）+ 取消 dnsmasq 的「过滤 IPv6 AAAA 记录」+ 开启 §9.5 `ipv6_dns`。结果：DNS 走 IPv4 经 OpenClash 分流、流量走 IPv6 传输，既防 IPv6 DNS 抢答泄露又保证 IPv6 站点可达。

| 选项 | UCI Key | 默认 | 说明 |
|------|---------|------|------|
| IPv6 代理 | `ipv6_enable` | 0 | 网关与 DNS 须为路由器 IP |
| IPv6 代理模式 | `ipv6_mode` | TProxy(0) | TProxy / Redirect / TUN / Mix |
| IPv6 堆栈类型 | `stack_type_v6` | mips | system / gvisor / mixed / mips；仅 TUN/Mix，含义见 `08-settings-mode-traffic.md` §8.2.12 |
| IPv6 UDP 代理 | `enable_v6_udp_proxy` | 1 | 仅 TProxy / Redirect 模式 |
| 允许 IPv6 类型 DNS 解析 | `ipv6_dns` | 0 | 写入 `dns.ipv6`，控制是否返回 AAAA |
| IPv6 Fake-IP 范围 | `fakeip_range6` | 0 | 写入 `dns.fake-ip-range6`；仅 Fake-IP 模式。禁用时未被 `fake-ip-filter` 放行的外网域名无 AAAA（回落 IPv4），启用后解析到虚拟 IPv6 并由代理接管 |
| 绕过指定区域 IPv6 | `china_ip6_route` | 0 | `0` 关闭 / `1` 绕过大陆 / `2` 绕过海外 |
| 本地 IPv6 绕过地址 | `local_network6_pass` | — | `openclash_custom_localnetwork_ipv6.list` |
| 绕过指定区域 IPv6 黑名单 | `chnroute6_pass` | — | `openclash_custom_chnroute6_pass.list`，成员加入 `china_ip6_route_pass` set，不受绕行选项影响；依赖 `ipv6_enable=1` + `enable_redirect_dns=1` |

#### 9.5.1 旁路由 + IPv6 使用指引（客户端侧）

**机制**: 旁路由转发的 IPv6 **不做 SNAT**；`china_ip6_route` 命中的流量按原生转发（要求客户端地址上游可回程），其余 TCP 由 `openclash` 链 `REDIRECT` 到代理端口（UDP 打 mark `0x162` → tun）。被代理流量由内核以自身身份出站，与 NAT66 开关无关。

| 做法 | 客户端 IPv6 网关 | 客户端地址 | 效果 | 代价 |
|------|-----------------|-----------|------|------|
| ① 经旁路由（推荐） | 旁路由 | 主路由下发的 ISP 前缀 GUA | 国内 v6 直连、国外 v6 走代理 | 需指定 v6 网关（或旁路由中继主路由 RA） |
| ② 直连（省事） | 主路由 | 同上 | 国内 v6 通、国外 v6 **完全绕过代理** | IPv6 泄漏，分流对 v6 失效 |
| ③ 关闭 IPv6 | — | 不配置 | 全部走 IPv4 | 双栈站点先等 v6 超时再回落 |

- 客户端只拿到旁路由下发的 ULA 却把网关指向主路由时，v6 全部不通（源地址上游不可回程）——「旁路由 IPv6 国内打不开」的典型形态，同网段多 RA 源也会造成
- 客户端设置（地址仍由主路由 RA/SLAAC 下发，只改默认网关）：
  - OpenWrt / Linux：`ip -6 route replace default via <旁路由 IPv6 地址> dev <iface>`
  - Windows（管理员）：`New-NetRoute -DestinationPrefix "::/0" -InterfaceAlias "<网卡名>" -NextHop "<旁路由 IPv6 地址>" -RouteMetric 1`（撤销用 `Remove-NetRoute` 同参数）；启停网卡 IPv6 用 `Enable-NetAdapterBinding` / `Disable-NetAdapterBinding -ComponentID ms_tcpip6`
- 旁路由侧要求（`ipv6_enable=1`）：
  - 关闭自身 RA/DHCPv6（`dhcp.lan.ra='disabled'`、`dhcp.lan.dhcpv6='disabled'`，或改 relay），避免与主路由争夺客户端配置（多 RA 源 = IPv6 时通时断）
  - 直连回程不可靠时开 NAT66：`masq6` 只覆盖 IPv6；`bypass_gateway_compatible` 是双栈开关且只 SNAT 被绕过的转发流量（代理/内网/路由器自身不受影响）
  - 国内 IPv6 列表用 `chnr6_custom_url` 保持更新，否则国内 v6 也会被代理
  - 要让**外网域名**走 IPv6，启用 `fakeip_range6`（如 `fdfe:dcba:9876::1/64`）；禁用（默认）时外网域名无 AAAA，只能走 IPv4（内核 `dns/middleware.go` 的 `withFakeIP()`），国内域名在 `fake-ip-filter` 内始终解析真实地址。该池属 ULA：dnsmasq 位于客户端与内核之间且开重绑定保护时会丢弃这些 AAAA 应答（见 `06-firewall-options-dnsmasq.md` §6.4）
- **排错**: `ip -6 route get <国内 IPv6 目标>` 看 `src`（ULA/私有前缀 ⇒ 回程不保）；「国内 v6 不通、国外正常」依次查地址来源 → RA 多源 → 上游回程（不可靠时开 NAT66）；「v6 全通但不走代理」是客户端网关指向了主路由（做法 ②）
