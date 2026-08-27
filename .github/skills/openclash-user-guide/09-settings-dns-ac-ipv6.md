## 插件设置：DNS、黑白名单、流媒体、外部控制与 IPv6

> **用途**: 插件设置页的 DNS、黑白名单、流媒体、外部控制与 IPv6 标签页（§9.1–9.5）。

### 9.1 DNS 设置标签页 (dns)

> **生效路径**: DNS 选项通过三条路径生效：
> 1. `yml_change.sh` 修改 YAML `dns:` 段 → Mihomo 内核使用
> 2. `change_dnsmasq()` 修改系统 dnsmasq → LAN 客户端 DNS 被劫持到 Mihomo
> 3. `openclash_custom_domain_dns.sh` 为自定义域名配置独立 DNS
>
> **AI 行为指引**: 当用户询问 DNS 劫持相关问题时（如"DNS 重定向模式选哪个"、"自定义上游 DNS 服务器怎么写"、
> "Fake-IP 和 Redir-Host 的 DNS 行为有何不同"、"如何让特定域名不走 Fake-IP"），AI 应结合本文档的
> `04/05/06-firewall-*.md`（防火墙与 DNS 规则详解）章节和 [Mihomo DNS 配置文档](https://wiki.metacubex.one/config/dns/)
> 解释底层原理，然后告知用户在 LuCI 中的操作路径。
> 涉及 dnsmasq 劫持实现时可查阅 [OpenClash 源码](https://github.com/vernesong/OpenClash/tree/dev) 中
> `init.d/openclash` 的 `change_dnsmasq()` 函数。对于 DNS 劫持失败的排查，首先让用户检查
> 「运行状态」页面查看 DNS 端口是否在监听。

#### 9.1.1 enable_redirect_dns — 本地 DNS 劫持 (Redirect Local DNS Setting)
- **UCI 选项**: `openclash.@openclash[0].enable_redirect_dns`
- **可选值**:
  - `0` — 禁用
  - `1` — Dnsmasq 转发 (将 LAN 的 DNS 请求转发给核心)
  - `2` — 防火墙重定向 (通过 iptables/nftables 劫持 53 端口)
- **默认**: 1
- **说明**:
  - **值1（Dnsmasq 转发）**: 让网关自带的 `dnsmasq` 把 LAN 客户端的 DNS 查询转交给核心（`dns_port=7874`），可沿用 dnsmasq 的缓存与分流。
  - **值2（防火墙重定向）**: 在网络层把发往 53 端口的请求直接转给核心，跳过 dnsmasq，更快；Fake-IP 模式下使用 LAN 访问控制必须选此项
- **Mihomo 对应**: DNS 监听配置 `dns.listen: 0.0.0.0:7874`
- **实现详解**:
  - **值1 (Dnsmasq)**: `change_dnsmasq()` 函数先备份 dnsmasq 原有配置到 `openclash.config.*`，然后设置 `dhcp.@dnsmasq[0].server=127.0.0.1#<dns_port>`，`noresolv=1`，`cachesize=0`。效果：所有 LAN 客户端的 DNS 查询 → dnsmasq → 转发到 Mihomo DNS (7874) → Mihomo 根据 `enhanced-mode` 处理。
  - **值2 (防火墙)**: 创建 `openclash_dns_redirect` nftables 链，对目标端口 53 的 UDP/TCP 流量 DNAT 到 `dns_port`。同时保留 dnsmasq 处理本地 DNS 缓存。此模式允许 `lan_ac_*` 访问控制（需要 Fake-IP 模式）。
  - **恢复**: `revert_dnsmasq()` 还原所有原始 dnsmasq 配置（servers、noresolv、resolvfile、cachesize）。规则细节（AC 过滤 / router_self_proxy OUTPUT 劫持等）见 `06-firewall-options-dnsmasq.md` §6.2「各选项对防火墙规则的具体影响 → `enable_redirect_dns`」。

#### 9.1.2 flush_dns_cache — 清空 DNS 缓存按钮 (Flush DNS Cache)
- **模板**: `openclash/flush_dns_cache`
- **功能**: 通过 POST `/cache/fakeip/flush` + `/cache/dns/flush` API 清空 Fake-IP 和 DNS 缓存

#### 9.1.3 dnsmasq_fix — Dnsmasq 修复按钮 (Dnsmasq Fix)
- **功能**: 停止 OpenClash 后 DNS 异常时使用。恢复 Dnsmasq 默认配置:
  1. 设置 `noresolv=0`, `localuse=1`
  2. 恢复 `resolvfile` 为有效的 DNS 配置文件
  3. 若无有效配置则创建 `/tmp/resolv.conf.d/resolv.conf.auto` (114.114.114.114, 8.8.8.8)
  4. 重启 dnsmasq

#### 9.1.4 enable_custom_domain_dns_server — 启用第二 DNS 服务器 (Enable Specify DNS Server)
- **UCI 选项**: `openclash.@openclash[0].enable_custom_domain_dns_server`
- **默认**: 0
- **说明**: 为自定义域名列表指定专用 DNS 服务器，完全独立于内核 DNS 查询

#### 9.1.5 custom_domain_dns_server — 指定服务器 (Specify DNS Server)
- **UCI 选项**: `openclash.@openclash[0].custom_domain_dns_server`
- **默认**: `114.114.114.114`
- **格式**: `IP地址` 或 `IP地址#端口` (如 `127.0.0.1#5300`)

#### 9.1.6 custom_domain_dns — 自定义域名列表 (Custom Domain DNS)
- **存储文件**: `/etc/openclash/custom/openclash_custom_domain_dns.list`
- **格式**: 每行一个域名
- **说明**: 列表中的域名不返回 Fake-IP，使用指定的上游 DNS 服务器解析

---

### 9.2 黑白名单标签页 (Black&White / lan_ac)

> **生效路径**: 访问控制完全在防火墙层面实现，不修改 YAML。
>
> **AI 行为指引**: 当用户询问访问控制问题时（如"如何让某个设备不走代理"、"如何让内网某设备全局代理"、
> "代理黑名单和白名单的区别"），AI 应结合本章节的防火墙规则详解
> （特别是 `06-firewall-options-dnsmasq.md` §6.2「各选项对防火墙规则的具体影响」表格）告知用户各选项组合的效果。
> 涉及黑白名单匹配逻辑时，查阅 [OpenClash 源码](https://github.com/vernesong/OpenClash/tree/dev) 中
> `init.d/openclash` 的 `firewall_lan_ac_traffic()` 函数和 `set_firewall()` 中的 `ipset`/`nft set` 创建逻辑。
> 对于 IP 段/CIDR 的写法问题，解释 `192.168.1.0/24` 等标准 CIDR 格式。
> **注意**：如需按接口/用户/DSCP 等维度精细绕过，请使用「插件设置页面底部 → 来源流量访问控制」（`10-settings-geo-misc-src.md` §10.3）。
> **依赖**: `enable_redirect_dns=2`（防火墙重定向模式）仅在 **Fake-IP 模式**下强制要求——因为 Fake-IP 返回虚拟 IP，客户端不知道真实目标，
> 必须通过防火墙重定向 DNS 才能实现基于真实目标的访问控制。Redir-Host 模式下此依赖为可选（LuCI UI 中同样要求，但底层机制不同）。

#### 9.2.1 lan_ac_mode — 局域网访问控制模式 (LAN Access Control Mode)
- **UCI 选项**: `openclash.@openclash[0].lan_ac_mode`
- **可选值**: `0` (黑名单模式) / `1` (白名单模式)
- **默认**: 0
- **说明**:
  - **黑名单模式**: 列表中的设备/主机不走代理 (直连)
  - **白名单模式**: 只有列表中的设备/主机走代理
- **依赖**: `enable_redirect_dns=2` (仅防火墙重定向模式) + Redir-Host 系列模式（LuCI 界面中 `lan_ac_mode` 及其 IP 列表同时要求 `en_mode` 为 redir-host 系列；MAC 列表仅要求 `lan_ac_mode` 匹配）
- **实现细节**: fw4 通过 `nft` 的 `ether saddr`（MAC）与 `ip saddr`（IP）在 `inet fw4` 各代理链中匹配；fw3 通过 `ipset hash:mac` / `hash:ip` 配合 `-m set --match-set` 匹配。黑白名单决定规则的 return 行为取反（黑名单=匹配到则 return 直连，白名单=不匹配则 return 直连）。

#### 9.2.2 lan_ac_black_ips — 不走代理的局域网设备 IP (LAN Bypassed Host List)
- **UCI 选项**: `openclash.@openclash[0].lan_ac_black_ips` (DynamicList)
- **格式**: IP 地址或 CIDR 网段
- **依赖**: `lan_ac_mode=0`
- **实现细节**: 生成 nftables set `openclash_lan_black_ip` / `openclash_lan_black_ip6`，在 `openclash` redirect 链中插入 `ip saddr @openclash_lan_black_ip counter return` 跳过规则。

#### 9.2.3 lan_ac_black_macs — 不走代理的局域网设备 Mac (LAN Bypassed Mac List)
- **UCI 选项**: `openclash.@openclash[0].lan_ac_black_macs` (DynamicList)
- **格式**: MAC 地址
- **实现细节**: fw4 创建 `lan_ac_black_macs` set（`type ether_addr`）并在各代理链用 `ether saddr @lan_ac_black_macs counter return` 匹配；fw3 创建 `ipset hash:mac` 并用 `-m set --match-set lan_ac_black_macs src` 匹配。匹配到的流量跳过代理。

#### 9.2.4 lan_ac_white_ips — 走代理的局域网设备 IP (LAN Proxied Host List)
- **UCI 选项**: `openclash.@openclash[0].lan_ac_white_ips`
- **依赖**: `lan_ac_mode=1`

#### 9.2.5 lan_ac_white_macs — 走代理的局域网设备 Mac (LAN Proxied Mac List)
- **UCI 选项**: `openclash.@openclash[0].lan_ac_white_macs`

#### 9.2.6 wan_ac_black_ips — 不走代理的 WAN IP (WAN Bypassed Host List)
- **UCI 选项**: `openclash.@openclash[0].wan_ac_black_ips`
- **说明**: Fake-IP 模式下仅支持纯 IP 请求，域名请求需先设置 Fake-IP-Filter

#### 9.2.7 wan_ac_black_ports — 不走代理的 WAN 端口 (WAN Bypassed Port List)
- **UCI 选项**: `openclash.@openclash[0].wan_ac_black_ports`
- **格式**: 端口号或端口范围

---

### 9.3 流媒体增强标签页 (stream_enhance)

> **生效路径**: `openclash_streaming_unlock.lua` 脚本在核心启动后被守护进程调用，
> 定期测试各流媒体服务的解锁情况，自动将策略组切换到支持该服务的节点。
>
> **AI 行为指引**: 当用户询问流媒体相关问题时（如"如何解锁 Netflix/Disney+"、"Bilibili 地区选项代表什么"、
> "如何添加新的流媒体服务"、"Group Filter 正则怎么写"），AI 应查阅 [Mihomo 规则文档](https://wiki.metacubex.one/config/rules/)
> 了解 GEOSITE/RULE-SET 等规则类型，并结合 OpenClash 的流媒体增强设置告知用户具体配置步骤。
> 涉及流媒体解锁检测逻辑时，查阅 [OpenClash 源码](https://github.com/vernesong/OpenClash/tree/dev) 中
> `openclash_streaming_unlock.lua` 脚本。
> 注意：`openclash_streaming_unlock.lua` 仅负责已配置服务的节点测试和自动切换，不负责 Smart 策略。

所有子选项依赖 `stream_auto_select=1`。每个流媒体服务有一组独立配置：

| 服务 | 启用 UCI | 默认 | 说明 |
|------|----------|------|------|
| Netflix | `stream_auto_select_netflix` | 0 | 启用后自动选择支持 Netflix 的节点 |
| Disney Plus | `stream_auto_select_disney_plus` | 0 | |
| HBO Max | `stream_auto_select_hbo_max` | 0 | |
| YouTube Premium | `stream_auto_select_ytb` | 0 | |
| TVB Anywhere+ | `stream_auto_select_tvb_anywhere` | 0 | |
| DAZN | `stream_auto_select_dazn` | 0 | |
| Prime Video | `stream_auto_select_prime_video` | 0 | |
| Paramount Plus | `stream_auto_select_paramount_plus` | 0 | |
| Discovery Plus | `stream_auto_select_discovery_plus` | 0 | |
| Bilibili | `stream_auto_select_bilibili` | 0 | 解锁地区选项：CN(仅大陆)/HK/MO/TW/TW(仅台湾) |
| Google Not CN | `stream_auto_select_google_not_cn` | 0 | 自动选择非中国 Google 节点 |
| OpenAI | `stream_auto_select_openai` | 0 | |
| Claude | `stream_auto_select_claude` | 0 | |
| Gemini | `stream_auto_select_gemini` | 0 | |

每个服务配置项：
- **策略组筛选 (Group Filter)**: `stream_auto_select_group_key_<service>` — 匹配策略组的正则表达式
- **解锁区域筛选 (Unlock Region Filter)**: `stream_auto_select_region_key_<service>` — 解锁地区国家缩写
- **解锁节点筛选 (Unlock Nodes Filter)**: `stream_auto_select_node_key_<service>` — 节点名称正则过滤
- **手动测试按钮**: 调用 `openclash_streaming_unlock.lua` 执行解锁测试
- **实现详解**: `openclash_streaming_unlock.lua` 是一个独立 Lua 脚本，由看门狗 `openclash_watchdog.sh` 在每个周期按已启用的服务逐个调用（非 procd 服务，`/etc/init.d/openclash` 仅 procd 启动核心与看门狗）。工作流程：
  1. 读取 YAML 中所有策略组和节点，构建节点-策略组映射
  2. 对每个启用的流媒体服务，尝试用各节点连接服务域名（如 `netflix.com`）
  3. 检查 HTTP 响应码或页面内容判断是否解锁（如 Netflix 返回 200 且不含地区限制页面则解锁）
  4. 找到能解锁的节点后，通过 Mihomo API `PUT /proxies/{group}` 自动切换策略组到该节点
  5. 定期重新测试（间隔可配置），节点失效时自动切换

---

### 9.4 外部控制标签页 (Dashboard Settings / dashboard)

> **生效路径**: 仪表盘选项写入 YAML 的 `external-controller`、`secret`、`external-ui` 等字段，
> 由 Mihomo 内核直接读取并提供 HTTP API。下载/切换通过 `openclash_download_dashboard.sh` 执行。

| 选项 | UCI Key | 默认 | 说明 |
|------|---------|------|------|
| 管理页面端口 (Dashboard Port) | `cn_port` | 9090 | 对应 Mihomo `external-controller: 0.0.0.0:9090` |
| 管理页面登录密钥 (Dashboard Secret) | `dashboard_password` | 空 | 对应 Mihomo `secret`，留空则不验证 |
| 管理页面公网域名 (Public Dashboard Address) | `dashboard_forward_domain` | 空 | 用于公网访问面板 |
| 管理页面映射端口 (Public Dashboard Port) | `dashboard_forward_port` | 空 | |
| 管理页面公网 SSL 访问 (Public Dashboard SSL enabled) | `dashboard_forward_ssl` | 0 | |

仪表盘版本管理通过 `action_switch_dashboard` → `openclash_download_dashboard.sh` 自动下载切换。
- **实现细节**: `yml_change.sh` 将 `cn_port`、`dashboard_password` 写入 YAML → Mihomo 内核启动 HTTP API。`openclash_download_dashboard.sh` 从 GitHub Releases 下载 Dashboard 静态文件 (yacd/metacubexd/zashboard)，解压到 `/usr/share/openclash/ui`。前端 `status.htm` 中的 JS 根据以下逻辑构造仪表盘 URL：1) 若当前浏览器 hostname 与路由器 LAN IP 相同 → `http://<lan_ip>:<cn_port>/ui/<dashboard>/`；2) 若设置了 `dashboard_forward_domain` + `dashboard_forward_port`（公网访问）→ 协议由 `dashboard_forward_ssl` 决定（0=http, 1=https），地址为 `<protocol>://<domain>:<port>/ui/<dashboard>/`；3) 其他情况 → 取当前页面协议 + LAN IP + cn_port。四个仪表盘的子路径分别为 `/ui/dashboard/`、`/ui/yacd/`、`/ui/metacubexd/`、`/ui/zashboard/`。

---

### 9.5 IPv6 设置标签页 (ipv6)

> **注意：** 不建议为路由器开启 IPv6 及相关服务。IPv6 方案仅适用于**主路由拨号环境**（需运营商支持 IPv6-PD 前缀下发），旁路由环境不适用
> **生效路径**: IPv6 选项通过 `yml_change.sh` 写入 YAML（`ipv6`、`dns.ipv6`、`dns.fake-ip-range6`），
> 同时 `set_firewall()` 生成独立的 IPv6 防火墙规则链（`openclash_v6`、`openclash_mangle_v6` 等）。
> IPv6 使用单独的 TProxy/Redirect/TUN 规则链，与 IPv4 互不影响。
>
> **IPv6 DNS 核心最佳实践**：DNS 解析请求（包括 AAAA 记录查询）可以通过 IPv4 链路发送，无需 IPv6 DNS 服务器。推荐策略：① LAN 接口 DHCP 服务器中**不分配 IPv6 DNS**，强制设备用路由器 IPv4 地址做 DNS 解析；② 取消 `过滤 IPv6 AAAA 记录`（Dnsmasq 高级设置）；③ 开启 OpenClash 的「允许 IPv6 类型 DNS 解析」选项。效果：DNS 走 IPv4 通道查询（经过 OpenClash 分流），流量走 IPv6 通道传输——既防止 IPv6 DNS 抢答导致的泄露，又保证 IPv6 站点可访问

| 选项 | UCI Key | 默认 | 说明 |
|------|---------|------|------|
| IPv6 代理 (Proxy IPv6 Traffic) | `ipv6_enable` | 0 | 开启 IPv6 流量代理。网关和 DNS 须为路由器 IP |
| IPv6 代理模式 (IPv6 Proxy Mode) | `ipv6_mode` | TProxy(0) | TProxy/Redirect/TUN/Mix |
| IPv6 堆栈类型 (Select Stack Type) | `stack_type_v6` | system | system/gvisor/mixed。仅 TUN/Mix 模式 |
| IPv6 UDP 代理 (Proxy UDP Traffics) | `enable_v6_udp_proxy` | 1 | 仅 TProxy/Redirect 模式 |
| 允许 IPv6 类型 DNS 解析 (IPv6 DNS Resolve) | `ipv6_dns` | 0 | 对应 Mihomo `dns.ipv6` — 控制 Mihomo DNS 是否返回 AAAA 记录 |
| IPv6 Fake-IP 范围 (Fake-IP Range) | `fakeip_range6` | 禁用 | 仅 Fake-IP 模式。对应 `dns.fake-ip-range6` |
| 实验性：绕过指定区域 IPv6 (China IPv6 Route) | `china_ip6_route` | 0 | 0=关闭, 1=绕过大陆, 2=绕过海外 |
| 本地 IPv6 绕过地址 (Local IPv6 Network Bypassed List) | `local_network6_pass` | — | 文件: `/etc/openclash/custom/openclash_custom_localnetwork_ipv6.list` |
| 绕过指定区域 IPv6 黑名单 (Chnroute6 Bypassed List) | `chnroute6_pass` | — | 文件: `/etc/openclash/custom/openclash_custom_chnroute6_pass.list`。将列表中域名/IP 加入 `china_ip6_route_pass` nft set，不受 IPv6 绕行选项影响。依赖: `ipv6_enable=1` + `enable_redirect_dns=1` |

---
