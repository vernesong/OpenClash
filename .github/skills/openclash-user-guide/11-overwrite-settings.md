## 覆写设置页面 (Overwrite Settings / config-overwrite)

> **用途**: 覆写订阅配置中的字段。启动时由 `yml_change.sh` / `yml_rules_change.sh` 写入运行 YAML，覆写值优先于订阅原值。
> **LuCI 路径**: 服务 → OpenClash → 插件设置 → 覆写设置
> **UCI Section**: `openclash.config_overwrite`
> **生效**: 改完需重启插件（「应用设置」会自动执行 `/etc/init.d/openclash restart`）
> **小节**: §11.1 总览 · §11.2 常规 · §11.3 DNS · §11.4 Meta · §11.5 Smart · §11.6 规则 · §11.7 认证

### 11.1 实现总览

| 脚本 | 处理内容 |
|------|----------|
| `yml_change.sh` | 端口、运行模式、DNS（`yml_dns_custom()`）、TUN、Sniffer、认证、Meta、GEO、Smart 收集、NTP |
| `yml_rules_change.sh` | `tolerance` / url-test 地址覆写、GitHub CDN 替换、`enable_rule_proxy` 注入、自定义规则、策略组类型转换 |

两者在 `start_service()` 中先于内核启动执行；`yml_change.sh` 用 YAML 深度合并覆盖，`yml_rules_change.sh` 用 Ruby YAML 库操作策略组/规则/规则集。

### 11.2 常规设置 (General Settings / settings)

| § | 项 (UCI key) | 默认 | 取值 | YAML | 说明 |
|---|---|---|---|---|---|
| 11.2.1 | 绑定网络接口 `interface_name` | 0 | 网卡名 | `interface-name` | 核心所有出站（节点连接、DNS 查询、GEO 下载）走该网卡；多 WAN 指定出口 |
| 11.2.2 | URL-Test 切换灵敏度 `tolerance` | 0 | 毫秒 | `proxy-groups[].tolerance`（仅 url-test 组） | 新最快节点比当前快超过该值才切换；0 = 每次切到最快 |
| 11.2.3 | 测速地址修改 `urltest_address_mod` | 0 | `http://www.gstatic.com/generate_204` / `http://cp.cloudflare.com/generate_204` / `https://cp.cloudflare.com/generate_204` / `http://captive.apple.com/generate_204` | url-test 组 `url` | 替换所有 url-test 组的测速 URL |
| 11.2.4 | GitHub 地址修改 `github_address_mod` | 0 | jsdelivr CDN 预设（首选 `https://testingcf.jsdelivr.net/`） | rule-providers / proxy-providers 的 `url` | 按正则 `/raw\.githubusercontent\.com/` 替换域名。**仅作用于 provider URL**；Dashboard 与 GEO 下载脚本（`openclash_download_dashboard.sh` / `openclash_geo.sh`）用硬编码直连地址，不受此变量影响。插件/内核更新、GEO 与 Dashboard 下载都依赖 GitHub 连通性，建议首次启动前就设好 |
| 11.2.5 | 日志等级 `log_level` | 0 | `0` / `info` / `warning` / `error` / `debug` / `silent` | `log-level` | 0 = 不覆写，沿用订阅值 |

#### 11.2.6 端口设置

| 端口用途 | UCI Key | 默认 | YAML |
|---|---|---|---|
| DNS 端口 (DNS Port) | `dns_port` | 7874 | `dns.listen` |
| 流量转发端口 (Redir Port) | `proxy_port` | 7892 | `listeners.redirect`（仅 TCP） |
| TProxy 端口 (TProxy Port) | `tproxy_port` | 7895 | `listeners.tproxy`（TCP+UDP） |
| HTTP(S) 代理端口 | `http_port` | 7890 | `listeners.http` |
| SOCKS5 代理端口 | `socks_port` | 7891 | `listeners.socks` |
| Mixed 代理端口 | `mixed_port` | 7893 | `listeners.mixed`（HTTP+SOCKS） |

内核在这些端口创建监听器，接受 iptables/nftables 重定向流量或客户端直连。

### 11.3 DNS 设置 (DNS Settings / dns)

> **生效路径**: `yml_change.sh` 的 `yml_dns_custom()` 构建完整 `dns:` 段合并进运行配置。
> **字段语义**: 查 [Mihomo DNS 配置文档](https://wiki.metacubex.one/config/dns/)，配置写法按本页覆写方式给出，而非只给文档链接。

| § | 项 (UCI key) | 默认 | 取值 / 文件 | YAML | 说明 |
|---|---|---|---|---|---|
| 11.3.1 | 自定义上游 DNS `enable_custom_dns` | 0 | 由 §11.3.13 列表构建 | `dns.nameserver` / `fallback` / `default-nameserver` | 关闭时沿用订阅 `dns` 段 |
| 11.3.2 | 遵守路由规则 `enable_respect_rules` | 0 | — | `dns.respect-rules` | DNS 查询本身按 `rules` 出站（防泄露），须同时配 `proxy-server-nameserver`，否则内核启动报错 |
| 11.3.3 | 附加上游 DNS `append_wan_dns` | 出厂 `/etc/config/openclash` 显式 `0`（CBI 默认 1） | — | 追加进 `dns.nameserver` | 追加 WAN 口运营商 DNS 与网关，支持 `dhcp://`；主路由拨号推荐开启，用 DoH/DoT 时应关闭 |
| 11.3.4 | Fake-IP 范围 `fakeip_range` | 0 | 预设 `198.18.0.1/16` | `dns.fake-ip-range` | 仅 Fake-IP 模式显示 |
| 11.3.5 | 持久化 Fake-IP `store_fakeip` | 出厂显式 `0`（CBI 默认 1） | — | `profile.store-fake-ip` | 映射存 `cache.db`，重启免重解析 |
| 11.3.6 | Fallback-Filter `custom_fallback_filter` | 0 | `openclash_custom_fallback_filter.yaml` | `dns.fallback-filter` | 防污染回退过滤 |
| 11.3.7 | Fake-IP-Filter `custom_fakeip_filter` | 0 | `openclash_custom_fake_filter.list`（同 §11.3.9） | `dns.fake-ip-filter` | 仅 Fake-IP 模式显示 |
| 11.3.8 | Fake-IP-Filter 模式 `custom_fakeip_filter_mode` | `blacklist` | `blacklist` / `whitelist` / `rule` | `dns.fake-ip-filter-mode` | `blacklist` 命中不返 Fake-IP；`whitelist` 仅命中返；`rule` 支持 GEOSITE / rule-set / DOMAIN* |
| 11.3.9 | 域名过滤文件 | — | `openclash_custom_fake_filter.list` | `dns.fake-ip-filter` | 每行一个通配符（`*.lan`、`+.example.com`） |
| 11.3.10 | Nameserver-Policy `custom_name_policy` | 0 | `openclash_custom_domain_dns_policy.list` | `dns.nameserver-policy` | 每行 `域名=DNS服务器组`，支持 geosite / rule-set |
| 11.3.11 | Proxy-Server-Nameserver-Policy `custom_proxy_server_policy` | 0 | `openclash_custom_proxy_server_dns_policy.list` | `dns.proxy-server-nameserver-policy` | 只解析代理节点域名 |
| 11.3.12 | 自定义 Hosts `custom_host` | 0 | `openclash_custom_hosts.list` | `dns.hosts` | 仅内核 DNS 生效 |
| 11.3.14 | 系统 Hosts `custom_system_host` | 0 | `openclash_custom_system_hosts.list` | 写 `/etc/hosts`；启用时另写 `dns.use-system-hosts: true` | 见下方「系统 Hosts」 |

自定义文件均在 `/etc/openclash/custom/` 下。

**Fake-IP 模式下的 DNS 配置建议**（§11.3.1）：
- Nameserver 只解析直连类域名（运营商 DNS 或国内 DoH）；**不配 fallback**——非直连域名交由远端节点解析，结果与实际出站链路一致，CDN 命中更准且无泄露
- 出站侧解析不可用时才启用 fallback 兜底，并同时开启 §11.3.2「遵守路由规则」
- 不要叠加 MosDNS / SmartDNS / AdGuardHome：缓存不一致、内网延迟上升，并破坏 Mihomo 传给客户端的 TTL

#### 11.3.13 DNS 服务器列表 (dns_servers TypedSection)

| 字段 | UCI Key | 说明 |
|------|---------|------|
| 启用 | `enabled` | Flag，默认 1 |
| 分组 | `group` | `nameserver`（默认DNS）/ `fallback`（后备DNS）/ `default`（默认DNS） |
| 地址 | `ip` | 服务器 IP 或域名 |
| 端口 | `port` | 端口号 |
| 类型 | `type` | `udp` / `tcp` / `tls` / `https` / `quic` |
| 禁用 IPv6 | `disable_ipv6` | 丢弃 AAAA 记录 |

**地址后缀语法**（`nameserver` / `fallback` / `default-nameserver` / `proxy-server-nameserver` / `nameserver-policy` 均支持，多个用 `&` 连接）：

| 后缀 | 含义 |
|------|------|
| `#RULES` | 按内核 `rules` 决定该 DNS 查询出站，无需写策略组名；不触发 `respect-rules` 对 `proxy-server-nameserver` 的强校验 |
| `#<策略组/节点名>` | 强制经该组/节点查询；**名字必须精确存在**，否则被当作网卡名而静默失败 |
| `#<网卡名>` | 从指定网卡发出 |
| `#k=v` | 协议参数，如 `h3=true`、`skip-cert-verify=true`、`disable-reuse=true`、`ecs=`、`disable-ipv4=true` / `disable-ipv6=true` |

示例：`'https://dns.google/dns-query#RULES'`、`'https://dns.google/dns-query#Proxy&h3=true'`、`'8.8.8.8#eth0'`。

#### 11.3.14 系统 Hosts（`custom_system_host`）说明

- **覆写模块**: `[General] SYSTEM_HOST=1.2.3.4 a.com,5.6.7.8 b.com`（逗号分隔，有值即启用，无需打开界面开关）
- **标记**: 写入的每一行带行尾标记 `#openclash-system-hosts`（与 cron 的 `#openclash-cron-task` 同思路）；重建时只删带标记的行，不影响其它服务或手动添加的 `/etc/hosts` 条目
- **过滤**: 非法行（IP 非 IPv4/IPv6，或字段不足两个）忽略；重复整行去重；同域名多 IP 保留多条
- **生效时机**: 仅在 OpenClash **启动**时重建并 `SIGHUP` dnsmasq；「配置重载」不重建；关闭开关或停用插件后重启会移除标记行

客户端能否解析到取决于 DNS 劫持模式（`enable_redirect_dns`）：

| 模式 | 客户端查询路径 | 读取系统 hosts 的一方 |
|------|----------------|----------------------|
| `0` 关闭 | 直接问上游 DNS | 无（条目仍写入，仅本机程序有效） |
| `1` dnsmasq 转发 | 客户端 → dnsmasq → 内核 | dnsmasq（启动时载入内存，靠 `SIGHUP` 重载） |
| `2` 防火墙转发 | 客户端 → iptables `REDIRECT --to-ports 7874` → 内核（绕过 dnsmasq） | Mihomo 内核（`use-system-hosts`），改条目后最多 5 秒生效 |

**与 `custom_host` 的区别**: `custom_host` 只写运行配置 `dns.hosts`（仅内核 DNS）；`custom_system_host` 改系统 `/etc/hosts`，dnsmasq 与宿主机程序都能读到。

### 11.4 Meta 设置 (Meta Settings / meta)

> **生效路径**: `yml_change.sh` 写入 YAML，启动时加载；sniffer 支持运行时通过 API 热改。
> **字段语义**: 查 [Mihomo 全局配置](https://wiki.metacubex.one/config/general/) 与 [Sniffer 文档](https://wiki.metacubex.one/config/sniff/)。

| § | 项 (UCI key) | 默认 | 取值 | YAML | 说明 |
|---|---|---|---|---|---|
| 11.4.1 | 启用 TCP 并发 `enable_tcp_concurrent` | 0 | — | `tcp-concurrent` | 解析出的所有 IP 并发握手，用最先成功的，降低首连延迟 |
| 11.4.2 | 启用统一延迟 `enable_unified_delay` | 0 | — | `unified-delay` | 用 RTT 计延迟，不同协议节点可公平比较 |
| 11.4.3 | 启用进程规则 `find_process_mode` | 0 | `0` / `off` / `always` / `strict` | `find-process-mode` | 依赖 `kmod-inet-diag`；路由器推荐 `off` |
| 11.4.4 | 启用流量探测 `enable_meta_sniffer` | 0 | — | `sniffer`（默认内容见下） | 嗅探 TLS/HTTP/QUIC 握手取真实域名，防域名代理与 DNS 劫持失败 |
| 11.4.5 | 探测纯 IP 连接 `enable_meta_sniffer_pure_ip` | 1 | — | `sniffer.parse-pure-ip` | 对拿不到域名的连接也强制嗅探 |
| 11.4.6 | 自定义嗅探设置 `enable_meta_sniffer_custom` | 0 | — | 用 §11.4.7 内容替代默认 `sniffer` | — |
| 11.4.7 | 自定义 Sniffer `sniffer_custom` | — | `openclash_custom_sniffer.yaml` | `sniffer` | 仅 `enable_meta_sniffer_custom=1` 生效 |
| 11.4.8 | Geodata 加载方式 `geodata_loader` | 0 | `0` / `memconservative` / `standard` | `geodata-loader` | 0 时不写该键；小内存设备用 `memconservative`（逐段读取） |
| 11.4.9 | 启用 GeoIP Dat 数据库 `enable_geoip_dat` | 0 | — | `geodata-mode` | 用 Dat 替代 MMDB；Dat 文件需单独下载（GEO 数据库订阅页） |
| 11.4.10 | 全局 User-Agent `global_ua` | 0 | `clash-verge/v2.5.10` / `clash.meta/1.19.33` / `Clash` | `global-ua` | 内核下载外部资源时使用；0 = 系统默认 `clash.meta` |

**默认 `sniffer` 内容**（`enable_meta_sniffer=1` 且未自定义时写入）：
- `sniff.TLS.ports: [443, 8443]`（SNI）、`sniff.HTTP.ports: [80, 8080-8880]`（Host 头）、`sniff.QUIC.ports: [443]`
- `force-dns-mapping: true`（仅 Redir-Host）、`override-destination: false`
- `force-domain` 预置 Netflix/Amazon 相关域名；`skip-domain` 预置 `Mijia Cloud`、`dlg.io.mi.com`、`+.oray.com`、`+.sunlogin.net`、`+.push.apple.com`

### 11.5 智能设置 (Smart Settings / smart)

> **生效路径**: `yml_change.sh` 写 `profile.smart-collector-size` 与 LGBM 相关键；`yml_rules_change.sh` 把 url-test / load-balance 组转为 `type: smart` 并写 per-group 参数。节点选择由内核 Smart 模块完成，无外部脚本。
> **前提**: Smart 是 Smart 核心（`vernesong/mihomo`）独有类型，上游 Mihomo 无此特性；策略组类型必须为 `smart`（靠 §11.5.1 自动转换或手改 YAML）。
> **选节点逻辑**（`adapter/outboundgroup/smart.go` → `selectProxies()`）: 目标 ASN → 手动选择 → 持久化缓存（boltDB）→ 预取缓存 → `store.GetBestProxyForTarget()` 综合延迟/抖动/丢包与 LGBM 权重 → `filterProxies()` 排序；后台任务维护排名、预取、稳定性检查与封禁恢复（`updateNodeRanking` / `runPrefetch` / `checkNodesStable` / `checkBlockedNodes` / `checkHostStatus`）。
> **自行训练模型**: 数据来自 `component/smart/lightgbm/collector.go`（开启 `smart_collect` 后生成 CSV），特征见 `transform.go`，LightGBM 版本看 `go.mod` 的 `vernesong/leaves` 依赖；训练后导出 `Model.bin`，用 §11.5.11 指定 URL 或直接放到 `/etc/openclash/Model.bin`。多数用户开 §11.5.9 用预训练模型即可。

| § | 项 (UCI key) | 默认 | 取值 | YAML | 说明 |
|---|---|---|---|---|---|
| 11.5.1 | Smart 策略自动切换 `auto_smart_switch` | 0 | — | `proxy-groups[].type: smart` | 把 url-test / load-balance 组全部转为 smart |
| 11.5.2 | 策略优先级 `smart_policy_priority` | — | `策略名:系数;策略名:系数`（如 `Premium:0.9;SG:1.3`） | `proxy-groups[].policy-priority` | `<1` 降权、`>1` 提权，默认 1；支持正则/字符串匹配组名 |
| 11.5.3 | 优先 ASN 查询 `smart_prefer_asn` | 0 | — | `prefer-asn` | 强制查目标 ASN，优先同 ASN 的更稳定节点 |
| 11.5.4 | 启用 LightGBM `smart_enable_lgbm` | 0 | — | `uselightgbm` + LGBM 下载键 | 模型由 `openclash_lgbm.sh` 下载到 `/etc/openclash/Model.bin`（小闪存模式 `/tmp/etc/openclash/Model.bin`） |
| 11.5.5 | Smart 延迟容差 `smart_tolerance` | 0 | `0` / `100` / `150` ms | `proxy-groups[].tolerance`（仅 smart 组） | 容差内视为等效、按权重排序，避免抖动导致频繁切换 |
| 11.5.6 | 收集训练数据 `smart_collect` | 0 | — | `proxy-groups[].collectdata` | 全局开关，对所有 smart 组生效 |
| 11.5.7 | 收集文件大小 `smart_collect_size` | 100 | MB | `profile.smart-collector-size` | 依赖 `smart_collect=1` |
| 11.5.8 | 数据采样率 `smart_collect_rate` | 1 | 0–1 | `proxy-groups[].sample-rate` | 依赖 `smart_collect=1` |
| 11.5.9 | 自动更新模型 `lgbm_auto_update` | 0 | — | `lgbm-auto-update` / `lgbm-url` / `lgbm-update-interval` | — |
| 11.5.10 | 模型更新间隔 `lgbm_update_interval` | 72 | 小时 | `lgbm-update-interval` | 依赖 `lgbm_auto_update=1` |
| 11.5.11 | 自定义模型地址 `lgbm_custom_url` | 轻量版 `Model.bin`（GitHub releases） | 中量版 `Model-middle.bin` / 重量版 `Model-large.bin` | `lgbm-url` | 模型越大预测越准、占内存越多；依赖 `lgbm_auto_update=1` |
| 11.5.12 | 手动更新模型按钮 | — | — | — | 触发 `openclash_lgbm.sh` 立即下载并显示模型时间戳 |
| 11.5.13 | 刷新 Smart 缓存按钮 | — | — | — | `POST /cache/smart/flush`，清空 Smart 缓存并重新评估节点 |

#### 11.5.14 按策略组的 Smart 设置 (Per-Group Smart Settings)

> **LuCI 路径**: 服务 → OpenClash → 配置管理 → 节点管理 → 编辑按钮（groups-config，controller 中注册为 `nil`，属隐藏子页）
> **UCI Section**: `openclash.proxy_groups`（每条一个策略组，CBI 为 `proxy-groups-config.lua`）
> **优先级**: per-group 值覆盖 §11.5 的全局值，但仅影响该组。

| 选项 | UCI Key | 默认 | YAML | 说明 |
|------|---------|------|------|------|
| 启用 LightGBM | `uselightgbm` | `false` | `proxy-groups[].uselightgbm` | 覆盖全局 `smart_enable_lgbm` |
| 收集训练数据 | `collectdata` | `false` | `proxy-groups[].collectdata` | 覆盖全局 `smart_collect` |
| 策略优先级 | `policy_priority` | 空 | `proxy-groups[].policy-priority` | 同 §11.5.2 格式，支持正则匹配节点名 |
| 延迟容差 | `tolerance` | `150` | `proxy-groups[].tolerance` | 仅 `type=url-test` 组显示（`o:depends("type","url-test")`）；smart 组用全局 §11.5.5，单组设置需走覆写模块 `[YAML]` 段 |

Smart 组与 url-test / fallback / load-balance 共享 `test_url`（测速地址）与 `test_interval`（测速间隔，秒）。

### 11.6 规则设置 (Rules Settings / rules)

| § | 项 (UCI key) | 默认 | 取值 / 文件 | 说明 |
|---|---|---|---|---|
| 11.6.1 | 仅代理命中规则流量 `enable_rule_proxy` | 0 | — | 追加 PROCESS-NAME 与 DST-PORT 规则，仅匹配规则的流量走代理（BT/P2P 直连） |
| 11.6.2 | 自定义规则 `enable_custom_clash_rules` | 0 | — | 开启后把 §11.6.3/11.6.4 内容注入运行配置 `rules:` |
| 11.6.3 | 优先规则 `custom_rules` | 0 | `openclash_custom_rules.list` | 每行一条规则，插入 `rules:` 顶部（优先匹配） |
| 11.6.4 | 扩展规则 `custom_rules_2` | 0 | `openclash_custom_rules_2.list` | 每行一条规则，插入 `rules:` 底部 |

#### 11.6.5 规则编写指南

> **来源**: `rules:` 语法查 [Mihomo 路由规则](https://wiki.metacubex.one/config/rules/)；`rule-providers:` 字段查 [规则集文档](https://wiki.metacubex.one/config/rule-providers/)；`GEOSITE` / `GEOIP` 分类名查 [meta-rules-dat meta 分支](https://github.com/MetaCubeX/meta-rules-dat/tree/meta) 的 `geo/geosite/` 与 `geo/geoip/` 目录（**分类名拼错会导致规则不匹配**），`.mrs` 文件可直接作 `url`。

**支持的规则类型**:

| 类型 | 格式 | 示例 |
|------|------|------|
| `DOMAIN` | `DOMAIN,域名,策略` | `DOMAIN,www.google.com,Proxy` |
| `DOMAIN-SUFFIX` | `DOMAIN-SUFFIX,后缀,策略` | `DOMAIN-SUFFIX,google.com,Proxy` |
| `DOMAIN-KEYWORD` | `DOMAIN-KEYWORD,关键词,策略` | `DOMAIN-KEYWORD,youtube,Proxy` |
| `DOMAIN-REGEX` | `DOMAIN-REGEX,正则,策略` | `DOMAIN-REGEX,^api\.example\.com$,Proxy` |
| `GEOSITE` | `GEOSITE,分类,策略` | `GEOSITE,netflix,NETFLIX` |
| `GEOIP` | `GEOIP,国家代码,策略` | `GEOIP,CN,DIRECT` |
| `IP-CIDR` / `IP-CIDR6` | `IP-CIDR,IP/掩码,策略` | `IP-CIDR,10.0.0.0/8,DIRECT` |
| `IP-ASN` | `IP-ASN,ASN号,策略` | `IP-ASN,13335,Proxy` |
| `RULE-SET` | `RULE-SET,规则集名,策略` | `RULE-SET,reject,REJECT` |
| `PROCESS-NAME` | `PROCESS-NAME,进程名,策略` | `PROCESS-NAME,aria2c,DIRECT` |
| `DST-PORT` / `SRC-PORT` | `DST-PORT,端口,策略` | `DST-PORT,80,Proxy` |
| `SRC-IP-CIDR` | `SRC-IP-CIDR,IP/掩码,策略` | `SRC-IP-CIDR,192.168.1.0/24,DIRECT` |
| `MATCH` | `MATCH,策略` | `MATCH,Proxy` |

**策略目标**: `DIRECT` / `Proxy` / `REJECT` / `REJECT-DROP` / `GLOBAL` / 任意自定义策略组名。
**格式**: 逗号分隔、大小写不敏感、从上到下匹配、命中即停。`AND` / `OR` / `NOT` / `SUB-RULE` 等进阶类型见规则文档。

**常见需求 → 写法**:

| 需求 | 规则 |
|------|------|
| 某域名走代理 | `DOMAIN-SUFFIX,google.com,Proxy` |
| 国内域名直连 | `GEOSITE,cn,DIRECT` |
| 流媒体走专用组 | `GEOSITE,netflix,NETFLIX` |
| 屏蔽域名 | `DOMAIN-SUFFIX,badsite.com,REJECT` |
| BT 直连 | `PROCESS-NAME,qbittorrent,DIRECT` |
| 指定设备不走代理 | `SRC-IP-CIDR,192.168.1.100/32,DIRECT` |
| 全部走代理 | `MATCH,Proxy` |

`rule-providers` 示例（字段以规则集文档为准）：

```yaml
rule-providers:
  openai:
    type: http
    behavior: domain
    format: mrs
    url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/openai.mrs"
    path: ./ruleset/openai.mrs
    interval: 86400
```

引用方式：`RULE-SET,openai,PROXY`。

### 11.7 认证设置 (Authentication)

位于常规设置标签页，为 SOCKS / HTTP / Mixed 代理加用户认证。

| 字段 | UCI Key | 默认 | 说明 |
|------|---------|------|------|
| 启用 | `enabled` | 1 | Flag |
| 用户名 | `username` | — | 代理认证用户名 |
| 密码 | `password` | — | 代理认证密码 |

**YAML**: `authentication` 列表，格式 `["user:pass"]`。
