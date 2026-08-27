## 覆写设置页面 (Overwrite Settings / config-overwrite)

> **用途**: 覆写设置页各 CBI 选项：常规、DNS、Meta、Smart、规则与认证（§11.1–11.7）。

> **小节索引**: §11.1 实现总览 · §11.2 常规 · §11.3 DNS · §11.4 Meta · §11.5 Smart · §11.6 规则 · §11.7 认证

> UCI Section: `openclash.config_overwrite`
> 此页面用于覆写订阅配置中的特定字段，设置后通过 openclash.sh 脚本注入到生成的 YAML 中

### 11.1 实现总览

```
 UCI config_overwrite 写入
        │
        ▼
 yml_change.sh (优先级最高)         yml_rules_change.sh
 ├─ 端口、模式、DNS、TUN            ├─ tolerance / url-test 覆写
 ├─ Sniffer、认证、Meta             ├─ GitHub CDN 替换
 ├─ GEO、Smart、NTP                 ├─ enable_rule_proxy → BT/P2P 直连
 └─ 自定义 DNS servers              └─ 自定义规则注入
```

**关键机制**: `yml_change.sh` 以 YAML 深度合并 + 覆盖的方式修改配置，覆写优先级高于订阅原始值。
`yml_rules_change.sh` 使用 Ruby YAML 库操作策略组、规则、URL-Test 参数和规则提供者地址。
两个脚本在 `start_service()` 流程中先于核心启动执行。

### 11.2 常规设置标签页 (General Settings / settings)

#### 11.2.1 interface_name — 绑定网络接口 (Bind Network Interface)
- **UCI**: `openclash.@config_overwrite[0].interface_name`
- **默认**: 0 (禁用)
- **说明**: 绑定核心出站流量到指定网络接口
- **Mihomo 对应**: `interface-name`
- **实现细节**: `yml_change.sh` 将值写入 YAML `interface-name`。Mihomo 内核所有出站连接（代理节点连接、DNS 查询、GEO 下载）都通过此接口发送。用于多 WAN 环境指定出口。

#### 11.2.2 tolerance — URL-Test 策略组切换灵敏度 (URL-Test Group Tolerance)
- **UCI**: `openclash.@config_overwrite[0].tolerance`
- **默认**: 0 (禁用)
- **说明**: 当前代理与新最快代理的延迟差值大于此值时自动切换。0 表示关闭
- **Mihomo 对应**: proxy-groups 中 url-test 类型的 `tolerance` 字段
- **实现细节**: `yml_rules_change.sh` 遍历所有 `type: url-test` 的策略组，设置其 `tolerance` 值。Mihomo 内核定期测试组内所有节点延迟，当当前选中节点的延迟与新最快节点的延迟差 > tolerance 时自动切换。设为 0 则每次测试都切换到最快节点。

#### 11.2.3 urltest_address_mod — 测速（连通性）地址修改 (URL-Test Address Modify)
- **UCI**: `openclash.@config_overwrite[0].urltest_address_mod`
- **默认**: 0 (禁用)
- **预设**: `http://www.gstatic.com/generate_204` / `http://cp.cloudflare.com/` / `https://cp.cloudflare.com/` / `http://captive.apple.com/`
- **Mihomo 对应**: proxy-groups 中 url-test 类型的 `url` 字段
- **实现细节**: `yml_rules_change.sh` 替换所有 url-test 策略组的测试 URL。Mihomo 内核周期性向此 URL 发送 HTTP HEAD/GET 请求测量延迟，作为节点选择的依据。

#### 11.2.4 github_address_mod — Github 地址修改 (Github Address Proxy)
- **UCI**: `openclash.@config_overwrite[0].github_address_mod`
- **说明**: 通过代理/CDN 加速 GitHub 文件下载。**强烈推荐在 OpenClash 启动前就设置好此项**，因为插件和内核更新、GEO 数据库下载、Dashboard 下载均依赖 GitHub 连通性。推荐优先尝试 `https://testingcf.jsdelivr.net/`（jsDelivr 的 Cloudflare CDN），如不可用再切换其他 CDN
- **预设**: 多个 jsdelivr CDN 地址（testingcf / fastly 等）
- **实现细节**: `yml_rules_change.sh` 用 Ruby 正则 `/raw\.githubusercontent\.com/` 匹配所有 rule-providers 和 proxy-providers 的 `url` 字段，将域名替换为 CDN 地址。解决中国大陆无法访问 GitHub 的问题。
- **已知限制**: `github_address_mod` 仅对 rule-providers 和 proxy-providers 的 URL 生效。`openclash_download_dashboard.sh`（Dashboard 下载）和 `openclash_geo.sh`（GEO 更新）**不使用此变量**，这些脚本的下载 URL 为硬编码的 GitHub 直连地址。如需对 Dashboard/GEO 下载使用 CDN，可通过覆写模块的 `[General]` 段设置 `DOWNLOAD_FILE` 或使用自定义规则使相关域名直连。

#### 11.2.5 log_level — 日志等级 (Log Level)
- **UCI**: `openclash.@config_overwrite[0].log_level`
- **可选值**: `0`(禁用) / `info` / `warning` / `error` / `debug` / `silent`
- **Mihomo 对应**: `log-level`
- 0 表示不覆写，使用订阅原有设置
- **实现细节**: `yml_change.sh` 将值写入 YAML `log-level`。Mihomo 内核根据级别过滤日志输出：`silent`(无输出) → `error`(仅错误) → `warning`(+警告) → `info`(+一般信息) → `debug`(+调试详情)。

#### 11.2.6 端口设置
| 端口用途 | UCI Key | 默认 | Mihomo 对应 |
|----------|---------|------|-------------|
| **DNS 端口 (DNS Port)** | `dns_port` | 7874 | `dns.listen` |
| **流量转发端口 (Redir Port)** | `proxy_port` | 7892 | `listeners.redirect` (仅 TCP) |
| **TProxy 端口 (TProxy Port)** | `tproxy_port` | 7895 | `listeners.tproxy` (TCP+UDP) |
| **HTTP(S) 代理端口 (HTTP(S) Port)** | `http_port` | 7890 | `listeners.http` |
| **SOCKS5 代理端口 (SOCKS5 Port)** | `socks_port` | 7891 | `listeners.socks` |
| **HTTP(S)&SOCKS5 混合代理端口 (Mixed Port)** | `mixed_port` | 7893 | `listeners.mixed` (HTTP+SOCKS) |

- **端口实现细节**: `yml_change.sh` 将所有端口写入 YAML 对应字段。Mihomo 内核启动时在这些端口上创建监听器，接受来自 iptables/nftables 重定向的流量或客户端直连的代理请求。修改后需重启核心。

### 11.3 DNS 设置标签页 (DNS Settings / dns)

> **生效路径**: DNS 覆写通过 `yml_change.sh` 的 `yml_dns_custom()` 函数处理，
> 构建完整的 `dns:` YAML 段并合并到运行配置。
>
> **AI 行为指引**: 当用户询问 DNS 配置问题时（如"如何配置 DoH/DoT"、"nameserver-policy 怎么写"、"hosts 格式是什么"、
> "fallback-filter 各字段含义"等），AI 应查阅 [Mihomo DNS 配置文档](https://wiki.metacubex.one/config/dns/)
> 了解各字段的详细含义和用法，涉及 OpenClash 侧 DNS 覆写实现时查阅
> [OpenClash 源码](https://github.com/vernesong/OpenClash/tree/dev) 中 `yml_change.sh` 的 `yml_dns_custom()` 函数，
> 然后**结合 OpenClash 覆写模块的操作方式**告知用户如何配置，而非仅给出文档链接。

#### 11.3.1 enable_custom_dns — 自定义上游 DNS 服务器 (Custom DNS Setting)
- **UCI**: `openclash.@config_overwrite[0].enable_custom_dns`
- **默认**: 0
- **说明**: 开启后将通过 TypedSection `dns_servers` 中的配置覆写 YAML 的 `dns` 段
- **最佳实践**: 在 Fake-IP 模式下推荐以下配置策略：① Nameserver 仅负责直连类域名的解析（使用运营商 DNS 或国内 DoH 如 AliDNS/DNSPod）；② **取消所有 Fallback 服务器**——Fake-IP 模式下若无 Fallback，非直连域名的解析请求将交由远端（代理节点侧）完成，解析结果与实际出站链路一致，可获得更一致的 CDN 命中并防止 DNS 泄露；③ 若出站侧解析不可用（罕见），可启用 Fallback 作为兜底并同时开启「遵循规则」功能。**不建议套娃其他 DNS 插件**（如 MosDNS/SmartDNS/AdGuardHome），多插件叠加会引入缓存一致性问题、增加内网解析延迟，且破坏 Mihomo 向客户端传递的 TTL 值
- **实现细节**: 开启后 `yml_dns_custom()` 遍历所有 `dns_servers` 条目，按 group 分类（nameserver/fallback/default）构建 DNS 服务器列表，通过 Ruby YAML 合并写入 `dns.nameserver`、`dns.fallback`、`dns.default-nameserver`。

#### 11.3.2 enable_respect_rules — 遵守路由规则 (Enable Respect Rules)
- **UCI**: `openclash.@config_overwrite[0].enable_respect_rules`
- **默认**: 0
- **Mihomo 对应**: `dns.respect-rules`
- **说明**: DNS 连接是否遵守 YAML 中的路由规则
- **实现细节**: 写入 YAML `dns.respect-rules: true`。Mihomo 内核的 DNS 解析器发出的连接将经过 `rules` 规则引擎匹配——意味着 DNS 查询本身也会被代理（通过匹配的代理节点发出），防止 DNS 泄露。需要配合 `proxy-server-nameserver` 防止鸡生蛋问题。

#### 11.3.3 append_wan_dns — 附加上游 DNS (Append WAN DNS)
- **UCI**: `openclash.@config_overwrite[0].append_wan_dns`
- **默认**: 1
- **说明**: 将 WAN 口自动分配的运营商 DNS 和网关 IP 追加到 nameserver 列表。**主路由拨号环境推荐启用**：运营商 DNS 对直连类域名的解析延迟通常最低（1-2ms），CDN 命中更接近实际链路，省去手动配置的麻烦。若使用第三方加密 DNS（如 DoH/DoT），则需禁用此项并在 NameServer 中手动添加服务器
- **实现细节**: `sys_dns_append()` 调用 `openclash_get_network.lua` 获取 WAN 口的 DNS 和网关地址，追加到 `/tmp/yaml_config.namedns.yaml`，后续被合并到 YAML `dns.nameserver`。支持 dhcp:// 协议直接从 DHCP 接口获取 DNS。

#### 11.3.4 fakeip_range — Fake-IP 范围 (IPv4) (Fake-IP Range)
- **UCI**: `openclash.@config_overwrite[0].fakeip_range`
- **默认**: 0 (禁用)
- **预设**: `198.18.0.1/16` (标准 Fake-IP 段)
- **Mihomo 对应**: `dns.fake-ip-range`
- **仅**: Fake-IP 模式显示
- **实现细节**: 写入 YAML `dns.fake-ip-range`。Mihomo 在 Fake-IP 模式下，将 DNS 查询的域名映射到此 CIDR 段中的虚拟 IP。应用连接到虚拟 IP 时内核通过路由表将流量导向 Mihomo，Mihomo 根据映射表还原真实域名后进行规则匹配。

#### 11.3.5 store_fakeip — 持久化 Fake-IP (Store Fake-IP)
- **UCI**: `openclash.@config_overwrite[0].store_fakeip`
- **默认**: 1
- **Mihomo 对应**: `profile.store-fake-ip`
- **说明**: 缓存 Fake-IP DNS 解析记录到文件，启动后加速响应
- **实现细节**: 写入 YAML `profile.store-fake-ip: true`。Mihomo 将域名→Fake-IP 映射持久化到 `cache.db` 文件，重启后恢复映射，避免重启后所有域名需要重新解析。

#### 11.3.6 custom_fallback_filter — 自定义 Fallback-Filter (Custom Fallback Filter)
- **UCI**: `openclash.@config_overwrite[0].custom_fallback_filter`
- **默认**: 0
- **说明**: 配置 DNS 防污染回退过滤器
- **配置文件**: `/etc/openclash/custom/openclash_custom_fallback_filter.yaml`
- **Mihomo 对应**: `dns.fallback-filter` 段

> Fallback-Filter 格式示例:
> ```yaml
> geoip: true
> geoip-code: CN
> geosite:
>   - gfw
> domain:
>   - '+.google.com'
> ```

#### 11.3.7 custom_fakeip_filter — 自定义 Fake-IP-Filter (Custom Fake-IP Filter)
- **UCI**: `openclash.@config_overwrite[0].custom_fakeip_filter`
- **默认**: 0
- **仅**: Fake-IP 模式显示
- **Mihomo 对应**: `dns.fake-ip-filter`

#### 11.3.8 custom_fakeip_filter_mode — Fake-IP-Filter 模式 (Custom Fake-IP Filter Mode)
- **UCI**: `openclash.@config_overwrite[0].custom_fakeip_filter_mode`
- **可选**: `blacklist` / `whitelist` / `rule`
- **默认**: `blacklist`
- **说明**:
  - `blacklist`: 匹配成功的域名不返回 Fake-IP (黑名单)
  - `whitelist`: 只有匹配成功的域名返回 Fake-IP (白名单)
  - `rule`: 规则模式，支持 GEOSITE、RuleSet、DOMAIN* 等语法
- **Mihomo 对应**: `dns.fake-ip-filter-mode`

#### 11.3.9 域名过滤文件 (custom_fake_filter)
- **文件**: `/etc/openclash/custom/openclash_custom_fake_filter.list`
- **格式**: 每行一个域名通配符，如 `*.lan`, `+.example.com`

#### 11.3.10 custom_name_policy — 自定义 Nameserver-Policy (Custom Name Policy)
- **UCI**: `openclash.@config_overwrite[0].custom_name_policy`
- **文件**: `/etc/openclash/custom/openclash_custom_domain_dns_policy.list`
- **Mihomo 对应**: `dns.nameserver-policy`
- **格式**: 每行 `域名=DNS服务器组` 或使用 geosite/rule-set

#### 11.3.11 custom_proxy_server_policy — 自定义 Proxy-Server-Nameserver-Policy (Custom Proxy Server Policy)
- **UCI**: `openclash.@config_overwrite[0].custom_proxy_server_policy`
- **文件**: `/etc/openclash/custom/openclash_custom_proxy_server_dns_policy.list`
- **Mihomo 对应**: `dns.proxy-server-nameserver-policy`
- **说明**: 仅用于解析代理节点域名的 DNS 策略

#### 11.3.12 custom_host — 自定义 Hosts (Custom Hosts)
- **UCI**: `openclash.@config_overwrite[0].custom_host`
- **文件**: `/etc/openclash/custom/openclash_custom_hosts.list`
- **Mihomo 对应**: `dns.hosts`

#### 11.3.13 DNS 服务器列表 (dns_servers TypedSection)

> **AI 行为指引**: 当用户询问 DNS 服务器类型（如"DoH 和 DoT 有什么区别"、"quic 类型怎么用"、
> "dns 服务器的 `#proxy` 和 `#RULES` 后缀是什么意思"）时，AI 应查阅
> [Mihomo DNS 类型文档](https://wiki.metacubex.one/config/dns/type/) 了解每种 DNS 协议的使用方法和参数，
> 涉及 OpenClash 侧实现时查阅 [OpenClash 源码](https://github.com/vernesong/OpenClash/tree/dev) 中
> `yml_change.sh` 的 DNS 相关逻辑，然后告知用户具体的配置写法。

用户可以添加多条 DNS 服务器记录，每条包含：

| 字段 | UCI Key | 说明 |
|------|---------|------|
| 启用 | `enabled` | Flag，默认 1 |
| 分组 | `group` | `nameserver`(默认DNS) / `fallback`(后备DNS) / `default`(默认DNS) |
| 地址 | `ip` | DNS 服务器 IP |
| 端口 | `port` | 端口号 |
| 类型 | `type` | `udp` / `tcp` / `tls` / `https` / `quic` |
| 禁用 IPv6 | `disable_ipv6` | 丢弃 AAAA 记录 |

**Mihomo YAML 格式示例**:
```yaml
dns:
  nameserver:
    - 223.5.5.5
    - tls://8.8.4.4
  fallback:
    - tls://1.1.1.1
```

### 11.4 Meta 设置标签页 (Meta Settings / meta)

> **生效路径**: Meta 选项通过 `yml_change.sh` 写入 YAML，所有选项在 Mihomo 启动时加载生效。
> 部分选项（sniffer）支持运行时通过 API 热修改。
>
> **AI 行为指引**: 当用户询问 Meta 相关问题（如"tcp-concurrent 和 unified-delay 有什么区别"、
> "find-process-mode 各模式的含义"、"sniffer 如何自定义"、"geodata-loader 选哪个"），
> AI 应查阅 [Mihomo 全局配置文档](https://wiki.metacubex.one/config/general/) 和
> [Mihomo Sniffer 文档](https://wiki.metacubex.one/config/sniff/) 了解各选项的详细含义，
> 涉及 OpenClash 侧 Meta 选项注入实现时查阅 [OpenClash 源码](https://github.com/vernesong/OpenClash/tree/dev) 中
> `yml_change.sh` 的 sniffer/Meta 相关段，然后结合 OpenClash 的覆写设置操作路径告知用户。

#### 11.4.1 enable_tcp_concurrent — 启用 TCP 并发 (Enable Tcp Concurrent)
- **UCI**: `openclash.@config_overwrite[0].enable_tcp_concurrent`
- **默认**: 0
- **Mihomo 对应**: `tcp-concurrent: true`
- **说明**: 同时使用 DNS 解析的所有 IP 地址发起连接，使用最先成功的连接
- **实现细节**: `yml_change.sh` 写入 YAML `tcp-concurrent: true`。Mihomo 对每个目标域名解析出所有 IP 后，同时向所有 IP 发起 TCP 连接，使用第一个 TCP 握手成功的连接，丢弃其余。可大幅降低首次连接延迟，但会增加并发连接数。

#### 11.4.2 enable_unified_delay — 启用统一延迟 (Enable Unified Delay)
- **UCI**: `openclash.@config_overwrite[0].enable_unified_delay`
- **默认**: 0
- **Mihomo 对应**: `unified-delay: true`
- **说明**: 消除连接握手等带来的不同类型节点延迟差异
- **实现细节**: 写入 YAML `unified-delay: true`。Mihomo 在 URL-Test 延迟测量时计算 RTT（Round-Trip Time），而非简单的 TCP 握手时间 + HTTP 响应时间。这样 Shadowsocks、Trojan、VMess 等不同协议的节点延迟可公平比较。

#### 11.4.3 find_process_mode — 启用进程规则 (Find Process Mode)
- **UCI**: `openclash.@config_overwrite[0].find_process_mode`
- **可选值**: `0`(禁用) / `off` / `always` / `strict`
- **默认**: 0
- **Mihomo 对应**: `find-process-mode`
- **说明**: 依赖 `kmod-inet-diag` 内核模块。路由器上推荐 `off` 以提升性能
- **实现细节**: 写入 YAML `find-process-mode`。控制 Mihomo 是否通过 Netlink INET_DIAG 匹配每个连接的发起进程名（用于 PROCESS-NAME 规则）。路由器上设为 `off` 可避免内核模块依赖和性能开销。

#### 11.4.4 enable_meta_sniffer — 启用流量（域名）探测 (Enable Sniffer)
- **UCI**: `openclash.@config_overwrite[0].enable_meta_sniffer`
- **默认**: 1
- **Mihomo 对应**: `sniffer.enable: true`
- **说明**: 防止域名代理和 DNS 劫持失败。通过嗅探 TLS/HTTP/QUIC 握手获取真实目标域名
- **实现细节**: `yml_change.sh` 写入完整的 `sniffer:` YAML 段：
  - `sniff.TLS.ports: [443, 8443]` — 解析 TLS ClientHello 中的 SNI 字段获取域名
  - `sniff.HTTP.ports: [80, 8080-8880]` — 解析 HTTP Host 头获取域名
  - `sniff.QUIC.ports: [443]` — 解析 QUIC Initial 包中的 SNI
  - `force-dns-mapping: true` (仅 Redir-Host) — 对 DNS 解析过的 IP 强制嗅探
  - `override-destination: true` — 用嗅探到的域名覆盖连接目标，确保规则基于域名匹配
  - 预置 `force-domain: [netflix, nflxvideo, amazonaws, media.dssott.com]` — 强制嗅探流媒体
  - 预置 `skip-domain: [Mijia Cloud, dlg.io.mi.com, oray.com, sunlogin.net, push.apple.com]` — 跳过智能家居/推送

#### 11.4.5 enable_meta_sniffer_pure_ip — 探测（嗅探）纯 IP 连接 (Forced Sniff Pure IP)
- **UCI**: `openclash.@config_overwrite[0].enable_meta_sniffer_pure_ip`
- **默认**: 1
- **Mihomo 对应**: `sniffer.parse-pure-ip: true`
- **说明**: 强制识别所有拿不到域名的连接（比如直接连 IP 的流量）

#### 11.4.6 enable_meta_sniffer_custom — 自定义流量探测（嗅探）设置 (Custom Sniffer Settings)
- **UCI**: `openclash.@config_overwrite[0].enable_meta_sniffer_custom`
- **默认**: 0
- **说明**: 启用后将使用下方文本框中的自定义 sniffer YAML 配置替代默认嗅探设置

#### 11.4.7 sniffer_custom — 自定义 Sniffer 文本框 (Sniffer Custom)
- **UCI**: `openclash.@config_overwrite[0].sniffer_custom`
- **存储**: `/etc/openclash/custom/openclash_custom_sniffer.yaml`
- **说明**: 多行 YAML 文本框，可自定义完整的 `sniffer:` 配置段。仅在 `enable_meta_sniffer_custom=1` 时生效

#### 11.4.8 geodata_loader — Geodata 数据加载方式 (Geodata Loader)
- **UCI**: `openclash.@config_overwrite[0].geodata_loader`
- **可选值**: `0`(禁用) / `memconservative` / `standard`
- **默认**: `memconservative`
- **Mihomo 对应**: `geodata-loader`
- **说明**: `memconservative` 专为小内存设备优化的加载器（逐段读取），`standard` 为标准加载器（一次性加载到内存，速度快但占内存）

#### 11.4.9 enable_geoip_dat — 启用 GeoIP Dat 版数据库 (Enable GeoIP Dat)
- **UCI**: `openclash.@config_overwrite[0].enable_geoip_dat`
- **默认**: 0
- **Mihomo 对应**: `geodata-mode: true`
- **说明**: 使用 Dat 格式替换 MMDB 格式 GeoIP 文件。Dat 文件较大需单独下载，可通过「GEO 数据库订阅」页面获取

#### 11.4.10 global_ua — 全局 User-Agent (Global UA)
- **UCI**: `openclash.@config_overwrite[0].global_ua`
- **默认**: 0 (禁用，使用系统默认 `clash.meta`)
- **Mihomo 对应**: `global-ua`
- **预设**: `clash-verge/v2.4.5` / `clash.meta/1.19.20` / `Clash`
- **说明**: 设置 Mihomo 下载外部资源（GEO 文件、规则集等）时使用的 User-Agent

> Sniffer YAML 格式示例:
> ```yaml
> sniffer:
>   enable: true
>   force-dns-mapping: true
>   parse-pure-ip: true
>   override-destination: false
>   sniff:
>     HTTP:
>       ports: [80, 8080-8880]
>     TLS:
>       ports: [443, 8443]
>     QUIC:
>       ports: [443, 8443]
>   force-domain:
>     - +.v2ex.com
>   skip-domain:
>     - Mijia Cloud
> ```

### 11.5 智能设置标签页 (Smart Settings / smart)

> **生效路径**: Smart 策略是智能代理选择引擎，基于 LightGBM 机器学习模型。
> `yml_change.sh` 将 Smart 训练数据收集配置写入 YAML（`profile.smart-collector-size`），
> `yml_rules_change.sh` 负责将 url-test/load-balance 策略组类型转换为 `type: smart` 并设置 Smart 相关参数（uselightgbm、collectdata、sample-rate、policy-priority、prefer-asn）。
> Smart 策略的运行时节点选择由 **Mihomo 内核 Smart 模块内部处理**，无需外部脚本干预。
>
> **AI 行为指引**: 当用户询问 Smart 策略相关问题时（如"Smart 和 url-test 有什么区别"、"如何训练 Smart 模型"、
> "prefer-asn 是什么"、"sample-rate 怎么设置"、"LGBM 模型如何自定义下载"），AI 应：
> 1. 首先查阅下方「智能设置标签页」中对应 UCI 选项的说明，给出 LuCI 操作路径（覆写设置 → Smart 设置）
> 2. Smart 策略组是 **Smart 核心源码独有的功能**（上游 Mihomo 核心无此特性），所有实现细节均应查阅
>    [Smart 核心源码](https://github.com/vernesong/mihomo/tree/Alpha)：
>    - 策略组节点选择逻辑 → `adapter/outboundgroup/smart.go`（`selectProxies()`、`Unwrap()`、`InitSmart()`）
>    - LightGBM 模型加载/推理/数据收集 → `component/smart/lightgbm/`（`lightgbm.go`、`collector.go`、`transform.go`）
>    - Smart 持久化存储与权重计算 → `component/smart/cachefile.go`、`component/smart/weight.go`
> 3. **Smart 节点选择逻辑简述**（`adapter/outboundgroup/smart.go` → `selectProxies()`）：
>    ① 获取目标 IP/域名的 ASN 信息 → ② 优先检查用户手动选择的节点 → ③ 查持久化缓存
>    （boltDB 存储的历史最优结果）→ ④ 查预取缓存（周期性后台预计算）→ ⑤ 实时调用
>    `store.GetBestProxyForTarget()` 综合历史延迟、抖动、丢包率及 LightGBM 模型预测权重
>    计算最优节点 → ⑥ `filterProxies()` 按权重排序过滤。后台定时任务持续维护排名
>    （`updateNodeRanking`）、预取（`runPrefetch`）、稳定性检查（`checkNodesStable`）、
>    被封节点恢复检测（`checkBlockedNodes`）、主机状态检查（`checkHostStatus`）。
> 4. **关于"如何训练 Smart 模型"**：用户如需自行训练模型（而非使用预训练模型），AI 应主动读取
>    [Smart 核心源码](https://github.com/vernesong/mihomo/tree/Alpha) 中 `component/smart/lightgbm/` 目录，
>    了解并告知用户以下信息：
>    - **数据来源**：`component/smart/lightgbm/collector.go` — 开启 `smart_collect` 后核心会在 `/etc/openclash/` 下生成 CSV 训练数据文件（含延迟、抖动、丢包率等特征；特征工程见 `transform.go`）
>    - **LightGBM 版本**：查阅 `go.mod` 中 `vernesong/leaves` 依赖确认支持的 LightGBM 版本
>    - **环境搭建**：在 PC/服务器上安装对应版本的 LightGBM Python 包，准备训练环境
>    - **训练脚本**：参考 `component/smart/lightgbm/` 中的特征处理与模型结构，为用户创建可运行的示例训练脚本（读取 CSV → 特征变换 → 训练 LightGBM → 导出 Model.bin）
>    - **模型部署**：训练完成后将 `Model.bin` 上传到可访问的 URL，通过 `lgbm_custom_url` 指定；或替换 `/etc/openclash/Model.bin`；模型加载与推理见 `lightgbm.go` 中的 `WeightModel`
>    - **日常使用**：大多数用户无需自行训练，开启 `lgbm_auto_update` 即可自动下载预训练模型
> **关键提醒**：Smart 策略使用 LightGBM 模型进行节点质量预测，需要在配置文件中将策略组类型设为 `smart`
> 才能启用（通过 `auto_smart_switch` 自动转换或手动修改 YAML）。Smart 核心在运行时根据模型预测结果
> 和实时延迟数据综合选择最优节点，无需外部脚本干预。

#### 11.5.1 auto_smart_switch — Smart 策略自动切换 (Smart Auto Switch)
- **UCI**: `openclash.@config_overwrite[0].auto_smart_switch`
- **默认**: 0
- **说明**: 自动将 url-test/load-balance 类型的策略组切换为 Smart 智能策略组
- **实现细节**: `yml_rules_change.sh` 遍历所有策略组，将 `type: url-test` 或 `type: load-balance` 替换为 `type: smart`。Smart 策略组综合延迟、丢包率、历史表现等多维指标选择最优节点。

#### 11.5.2 smart_policy_priority — 策略优先级 (Policy Priority)
- **UCI**: `openclash.@config_overwrite[0].smart_policy_priority`
- **格式**: `策略名:系数;策略名:系数`，如 `Premium:0.9;SG:1.3`
- **说明**: `<1` 降低优先级，`>1` 提高优先级，默认权重为 1。支持正则和字符串匹配策略组名称

#### 11.5.3 smart_prefer_asn — 优先 ASN 查询 (Smart Prefer ASN)
- **UCI**: `openclash.@config_overwrite[0].smart_prefer_asn`
- **默认**: 0
- **说明**: 强制查询并使用目标 ASN（自治系统号）信息，优先选择同一 ASN 的更稳定节点

#### 11.5.4 smart_enable_lgbm — 启用 LightGBM 模型 (Enable LightGBM Model)
- **UCI**: `openclash.@config_overwrite[0].smart_enable_lgbm`
- **默认**: 0
- **说明**: 使用 LightGBM 机器学习模型预测节点权重
- **实现细节**: `yml_change.sh` 配置 YAML 中的模型下载 URL 和更新间隔。`openclash_lgbm.sh` 定期下载训练好的 LightGBM 模型文件到 `/etc/openclash/Model.bin`（小闪存模式下为 `/tmp/etc/openclash/Model.bin`）。Mihomo Smart 模块加载模型后，根据节点历史延迟、抖动、丢包率等特征预测最优节点。

#### 11.5.5 smart_tolerance — Smart 组延迟容差 (Smart Group Tolerance)
- **UCI**: `openclash.@config_overwrite[0].smart_tolerance`
- **默认**: 0 (禁用)
- **可选值**: `0`(禁用) / `100` / `150` (ms)
- **Mihomo YAML 映射**: `proxy-groups[].tolerance: <value>` (单位 ms, 仅对 smart 类型策略组设置)
- **说明**: 当多个代理节点延迟在容差范围内时视为等效，按权重排序而非严格按延迟排序，防止因网络抖动导致频繁切换节点
- **实现细节**: `yml_rules_change.sh` 在 smart auto switch 处理中，对每个 `type: smart` 的策略组设置 `group['tolerance']`

#### 11.5.6 smart_collect — 收集训练数据 (Collectdata)
- **UCI**: `openclash.@config_overwrite[0].smart_collect`
- **默认**: 0
- **Mihomo YAML 映射**: `proxy-groups[].collectdata: true`, `proxy-groups[].sample-rate: <rate>`
- **说明**: 在节点选择过程中收集延迟/抖动等数据供 LightGBM 模型训练。全局开关，会对所有 smart 类型策略组生效

#### 11.5.7 smart_collect_size — 数据收集文件大小 (Smart Collect Size)
- **UCI**: `openclash.@config_overwrite[0].smart_collect_size`
- **默认**: 100 (MB)
- **Mihomo YAML 映射**: `profile.smart-collector-size: <size>` (全局配置)
- **依赖**: `smart_collect=1`
- **实现细节**: `yml_change.sh` 通过 `Value['profile']['smart-collector-size'] = <size>` 写入 YAML

#### 11.5.8 smart_collect_rate — 数据采样率 (Smart Collect Rate)
- **UCI**: `openclash.@config_overwrite[0].smart_collect_rate`
- **默认**: 1 (范围 0-1)
- **Mihomo YAML 映射**: `proxy-groups[].sample-rate: <rate>`
- **依赖**: `smart_collect=1`

#### 11.5.9 lgbm_auto_update — 自动更新 LightGBM 模型 (LGBM Auto Update)
- **UCI**: `openclash.@config_overwrite[0].lgbm_auto_update`
- **默认**: 0
- **Mihomo YAML 映射**: `lgbm-auto-update: true`, `lgbm-url: <url>`, `lgbm-update-interval: <hours>`
- **实现细节**: `yml_change.sh` 设置为 1 时写入 `lgbm-auto-update: true` 及对应 URL 和间隔

#### 11.5.10 lgbm_update_interval — 模型更新间隔 (LGBM Update Interval)
- **UCI**: `openclash.@config_overwrite[0].lgbm_update_interval`
- **默认**: 72 (小时)
- **依赖**: `lgbm_auto_update=1`

#### 11.5.11 lgbm_custom_url — 自定义模型下载地址 (LGBM Custom URL)
- **UCI**: `openclash.@config_overwrite[0].lgbm_custom_url`
- **默认**: `https://github.com/vernesong/mihomo/releases/download/LightGBM-Model/Model.bin`（轻量版）
- **可选**: 中量版 (`Model-middle.bin`)、重量版 (`Model-large.bin`) — 模型越大预测越准确但占用更多内存
- **依赖**: `lgbm_auto_update=1`

#### 11.5.12 手动更新模型按钮
- **功能**: 点击触发 `openclash_lgbm.sh` 立即下载最新模型并显示当前模型文件时间戳

#### 11.5.13 刷新 Smart 缓存按钮
- **功能**: 通过 Mihomo API `POST /cache/smart/flush` 清空 Smart 策略缓存，强制重新评估所有节点

#### 11.5.14 按策略组的 Smart 设置 (Per-Group Smart Settings)

> **LuCI 路径**: 服务 → OpenClash → 配置管理 → 节点管理 → 编辑按钮 (groups-config)
> **注意**: groups-config 不是主菜单页面，而是通过「配置管理 → 节点 & 策略组管理」页面中的编辑按钮加载进入的隐藏子页面（controller 中注册为 `nil` 显示名）。
> **UCI Section**: `openclash.groups_config` (多条，每条对应一个策略组)
> 以下为 `type=smart` 策略组独有的配置选项，用于**覆盖**全局 Smart 设置中的对应值。

| 选项 | UCI Key | 默认值 | Mihomo YAML 映射 | 说明 |
|------|---------|--------|-----------------|------|
| **启用 LightGBM** (Uselightgbm) | `uselightgbm` | `false` | `proxy-groups[].uselightgbm: true/false` | 是否为此策略组启用 LightGBM 模型预测权重。优先级高于全局 `smart_enable_lgbm` |
| **收集训练数据** (Collectdata) | `collectdata` | `false` | `proxy-groups[].collectdata: true/false` | 是否为此策略组收集训练数据。优先级高于全局 `smart_collect` |
| **策略优先级** (Policy Priority) | `policy_priority` | *(空)* | `proxy-groups[].policy-priority: "<pattern>"` | 此策略组内节点的权重优先级，格式同全局 `smart_policy_priority`（如 `Premium:0.9;SG:1.3`）。支持正则匹配节点名称 |
| **延迟容差** (Tolerance) | `tolerance` | *(空)* | `proxy-groups[].tolerance: <ms>` | 此策略组的延迟容差（ms），覆盖全局 `smart_tolerance`。注意：该字段在 groups-config.lua 中存在但不直接写入 YAML——`yml_rules_change.sh` 的 smart 段**不读取** per-group tolerance，仅使用全局 `smart_tolerance` 统一设置所有 smart 策略组 |

> **注意**: Per-group 的 `tolerance` 字段在 LuCI 界面中可配置，但实际 YAML 生成脚本（`yml_rules_change.sh`）在 smart auto switch 处理中统一使用全局 `smart_tolerance` 值应用到**所有** smart 类型策略组。如需对不同策略组设置不同 tolerance，需通过覆写模块的 `[YAML]` 段手动指定。
>
> **Per-group Smart 设置的生效方式**: 这些字段直接写入策略组的 YAML 配置中（如 `proxy-groups[0].uselightgbm: true`），由 Mihomo Smart 核心在运行时读取。它们与全局 Smart 设置（覆写设置 → Smart 设置）的关系是：**per-group 设置覆盖全局设置，但仅影响该策略组**。
>
> **Smart 策略组通用选项** (与 url-test/fallback/load-balance 共享):
> - `test_url` — 延迟测试 URL
> - `test_interval` — 延迟测试间隔 (秒)

---

### 11.6 规则设置标签页 (Rules Settings / rules)

> 此标签页用于管理自定义 Clash/Mihomo 路由规则。Mihomo 支持多种规则类型，
> 用户在 LuCI 文本框中编写规则时需遵循特定格式。

#### 11.6.1 enable_rule_proxy — 仅代理命中规则流量 (Rule Match Proxy Mode)
- **UCI**: `openclash.@config_overwrite[0].enable_rule_proxy`
- **默认**: 0
- **说明**: 开启后向配置追加 PROCESS-NAME 和 DST-PORT 规则，仅允许匹配规则的流量走代理，其余流量（如 BT/P2P）直连

#### 11.6.2 enable_custom_clash_rules — 自定义规则 (Custom Clash Rules)
- **UCI**: `openclash.@config_overwrite[0].enable_custom_clash_rules`
- **默认**: 0
- **说明**: 开启后将在运行配置的 `rules:` 段注入自定义规则文件中的内容

#### 11.6.3 custom_rules — 优先规则编辑框 (Custom Rules Priority)
- **UCI**: `openclash.@config_overwrite[0].custom_rules`
- **存储**: `/etc/openclash/custom/openclash_custom_rules.list`
- **格式**: 每行一条 Mihomo 规则，插入到规则列表顶部（优先匹配）
- **依赖**: `enable_custom_clash_rules=1`

#### 11.6.4 custom_rules_2 — 扩展规则编辑框 (Custom Rules Extended)
- **UCI**: `openclash.@config_overwrite[0].custom_rules_2`
- **存储**: `/etc/openclash/custom/openclash_custom_rules_2.list`
- **格式**: 每行一条 Mihomo 规则，插入到规则列表底部
- **依赖**: `enable_custom_clash_rules=1`

#### 11.6.5 规则编写指南

> **当用户描述需求（如"我想让某个域名走代理"、"禁止某个 IP 走代理"）时，AI 应查阅 [Mihomo 路由规则文档](https://wiki.metacubex.one/config/rules/) 了解各规则类型的作用，涉及规则注入实现时查阅 [OpenClash 源码](https://github.com/vernesong/OpenClash/tree/dev) 中 `yml_rules_change.sh` 和 `custom_rules*.list` 的处理逻辑，然后告知用户具体的规则写法。**
>
> **用 meta-rules-dat 确认分类名（写 `GEOSITE`/`GEOIP` 规则前必查）**：当用户想按分类添加规则（如 `GEOSITE,netflix,NETFLIX`、`GEOIP,telegram,PROXY`）时，先用 [meta-rules-dat meta 分支](https://github.com/MetaCubeX/meta-rules-dat/tree/meta) 的目录确认分类名是否存在及正确拼写——`geo/geosite/` 列出全部 GeoSite 域名分类（如 cn/netflix/google/youtube/biliintl/onedrive/steam@cn），`geo/geoip/` 列出 GeoIP 分类（如 telegram/cloudflare/netflix）。分类名不存在或拼错会导致规则不匹配。各分类内容来源与 `@cn` 等变体含义见 [master 分支 README](https://github.com/MetaCubeX/meta-rules-dat)。meta 分支同时提供 `.mrs` 规则集文件（`https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/<分类>.mrs`），可直接作 rule-providers 的下载地址。

> **编写规范参考来源（`rules:` / `rule-providers:`）**：
> - **`rules:` 段**（逐条规则的类型/格式/匹配顺序）→ 权威来源为 [Mihomo 路由规则文档](https://wiki.metacubex.one/config/rules/)，下方「Mihomo 支持的规则类型速查」即其精简版
> - **`rule-providers:` 段**（规则集声明：`type` http/file、`behavior` domain/ipcidr、`format` yaml/text/mrs、`url`、`interval`、`path` 等字段）→ [Mihomo 规则集文档](https://wiki.metacubex.one/config/rule-providers/)
> - **`RULE-SET` 引用的规则集内容 / GEOSITE/GEOIP 分类名** → [meta-rules-dat](https://github.com/MetaCubeX/meta-rules-dat)（见上，`.mrs` 可直接作 `url`）
> - **OpenClash 侧注入实现**（自定义规则文件如何并入 `rules:` 段）→ [OpenClash 源码](https://github.com/vernesong/OpenClash/tree/dev) 中 `yml_rules_change.sh` 与 `custom_rules*.list` 的处理逻辑
>
> rule-providers 格式示例（完整字段以规则集文档为准）：
> ```yaml
> rule-providers:
>   openai:
>     type: http
>     behavior: domain
>     format: mrs            # yaml / text / mrs 均可
>     url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/openai.mrs"
>     path: ./ruleset/openai.mrs
>     interval: 86400
> ```
> 引用方式：规则中写 `RULE-SET,openai,PROXY`。

**Mihomo 支持的规则类型速查**:

| 规则类型 | 格式 | 用途 | 示例 |
|---------|------|------|------|
| `DOMAIN` | `DOMAIN,域名,策略` | 精确匹配域名 | `DOMAIN,www.google.com,Proxy` |
| `DOMAIN-SUFFIX` | `DOMAIN-SUFFIX,域名后缀,策略` | 匹配域名后缀（含所有子域名） | `DOMAIN-SUFFIX,google.com,Proxy` |
| `DOMAIN-KEYWORD` | `DOMAIN-KEYWORD,关键词,策略` | 匹配域名含关键词 | `DOMAIN-KEYWORD,youtube,Proxy` |
| `DOMAIN-REGEX` | `DOMAIN-REGEX,正则,策略` | 域名正则匹配 | `DOMAIN-REGEX,^api\.example\.com$,Proxy` |
| `GEOSITE` | `GEOSITE,类别,策略` | 按 GeoSite 类别匹配域名 | `GEOSITE,netflix,NETFLIX` |
| `GEOIP` | `GEOIP,国家代码,策略` | 按 GeoIP 国家匹配 IP | `GEOIP,CN,DIRECT` |
| `IP-CIDR` | `IP-CIDR,IP/掩码,策略` | IP 段匹配 | `IP-CIDR,10.0.0.0/8,DIRECT` |
| `IP-CIDR6` | `IP-CIDR6,IPv6/掩码,策略` | IPv6 段匹配 | `IP-CIDR6,::1/128,DIRECT` |
| `IP-ASN` | `IP-ASN,ASN号,策略` | 自治系统号匹配 | `IP-ASN,13335,Proxy` |
| `RULE-SET` | `RULE-SET,规则集名,策略` | 引用 rule-provider 规则集 | `RULE-SET,reject,REJECT` |
| `PROCESS-NAME` | `PROCESS-NAME,进程名,策略` | 按进程名匹配 | `PROCESS-NAME,aria2c,DIRECT` |
| `DST-PORT` | `DST-PORT,端口,策略` | 目标端口匹配 | `DST-PORT,80,Proxy` |
| `SRC-PORT` | `SRC-PORT,端口,策略` | 源端口匹配 | `SRC-PORT,8080,DIRECT` |
| `SRC-IP-CIDR` | `SRC-IP-CIDR,IP/掩码,策略` | 源 IP 段匹配 | `SRC-IP-CIDR,192.168.1.0/24,DIRECT` |
| `MATCH` | `MATCH,策略` | 兜底匹配所有流量 | `MATCH,Proxy` |

**可用策略目标**: `DIRECT`(直连)、`Proxy`(走默认代理组)、`REJECT`(拒绝)、`REJECT-DROP`(静默丢弃)、`GLOBAL`(走全局组)、任意自定义策略组名称

**编写格式**: 不区分大小写，逗号分隔。每行一条规则。规则按顺序从上到下匹配，命中后不再继续。

**常见需求 → 规则示例**:

| 用户需求 | 规则写法 |
|---------|---------|
| Google 走代理 | `DOMAIN-SUFFIX,google.com,Proxy` |
| 国内域名直连 | `GEOSITE,cn,DIRECT` |
| Netflix 走专用策略组 | `GEOSITE,netflix,NETFLIX` |
| 禁止访问某域名 | `DOMAIN-SUFFIX,badsite.com,REJECT` |
| BT 下载直连 | `PROCESS-NAME,qbittorrent,DIRECT` |
| 特定 IP 段直连 | `IP-CIDR,192.168.0.0/16,DIRECT` |
| GitHub 直连加速 | `DOMAIN-SUFFIX,github.com,DIRECT` |
| 所有流量走代理 | `MATCH,Proxy` |
| 排除某设备走代理 | `SRC-IP-CIDR,192.168.1.100/32,DIRECT` |

> **进阶规则类型**（如 `AND`/`OR`/`NOT` 逻辑规则、`SUB-RULE` 子规则等）请查阅 [Mihomo 路由规则文档](https://wiki.metacubex.one/config/rules/)。

---

### 11.7 认证设置 (Authentication)

位于常规设置标签页中，为 SOCKS/HTTP/Mixed 代理添加用户认证：

| 字段 | UCI Key | 说明 |
|------|---------|------|
| 启用 | `enabled` | Flag, 默认 1 |
| 用户名 | `username` | 代理认证用户名 |
| 密码 | `password` | 代理认证密码 |

**Mihomo 对应**: `authentication` 列表，格式 `["user:pass"]`

---
