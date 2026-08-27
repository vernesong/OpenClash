## 插件设置页面 (Plugin Settings / settings)

> **用途**: 插件设置页的模式与流量控制标签页各选项（UCI 与实现，§8.1–8.3）。

> **小节索引**: §8.1 实现总览（§8.1.1 强制覆盖/禁用）· §8.2 模式设置（en_mode / stack_type / proxy_mode / …）· §8.3 流量控制（router_self_proxy / disable_udp_quic / china_ip_route / …）

> UCI Section: `openclash` (anonymous section)
> 所有选项通过 `uci set openclash.@openclash[0].<option>=<value>` 设置

### 8.1 实现总览

插件设置页的选项通过以下路径生效：

```
 UCI 写入 → init.d start_service() → get_config() 读取所有 UCI 变量
                                            │
                    ┌───────────────────────┼───────────────────────┐
                    ▼                       ▼                       ▼
            yml_change.sh           set_firewall()          change_dnsmasq()
         (修改 YAML 配置)         (iptables/nftables)      (DNS 劫持转发)
                    │                       │                       │
                    ▼                       ▼                       ▼
              Mihomo 核心              系统防火墙规则            Dnsmasq → Mihomo DNS
```

| 脚本 | 输入 | 输出 | 负责的设置 |
|------|------|------|-----------|
| `yml_change.sh` | ~48 个 UCI 参数 | 修改运行 YAML | 端口、模式、DNS、TUN、Sniffer、认证、Meta、GEO、Smart |
| `yml_rules_change.sh` | UCI 覆写 + 自定义规则 | 修改运行 YAML | URL-Test 覆写、GitHub CDN、自定义规则注入、BT 直连规则 |
| `set_firewall()` | 所有流量控制 UCI | iptables/nftables 规则 | 透明代理、黑白名单访问控制、中国 IP 绕行、QUIC 阻断、UPNP 排除 |
| `change_dnsmasq()` | DNS 相关 UCI | dnsmasq 配置修改 | DNS 劫持转发、自定义域名 DNS、chnroute 旁路 |

#### 8.1.1 插件强制覆盖/禁用的设置（用户不可修改）

> **重要**：以下设置由 `yml_change.sh` 在每次启动时**无条件硬编码**写入 YAML，用户在 LuCI 中**无法修改或关闭**。但可以通过覆写模块的 `[YAML]` 段和 `[Overwrite]` 段尝试覆盖，插件不保证覆写后的效果及工作逻辑正常。

| 强制设置 | 硬编码值 | 说明 |
|----------|----------|------|
| `allow-lan` | `true` | 始终允许局域网设备使用代理端口 |
| `bind-address` | `*` | 始终监听所有网络接口 |
| `external-controller` | `0.0.0.0:<cn_port>` | API 始终监听所有接口 (非仅 127.0.0.1) |
| `external-ui` | `/usr/share/openclash/ui` | Dashboard 路径不可更改 |
| `dns.listen` | `0.0.0.0:<dns_port>` | DNS 始终监听所有接口 |
| `profile.store-selected` | `true` | 始终保存策略组选择状态 |
| `sniffer.sniff` | HTTP:80,8080-8880 / TLS:443,8443 / QUIC:443 | 嗅探端口不可修改 |
| `sniffer.override-destination` | `true` | 始终用嗅探结果覆盖连接目标 |
| `sniffer.force-domain` | `netflix, nflxvideo, amazonaws, media.dssott.com` | 强制嗅探的流媒体域名 |
| `sniffer.skip-domain` | `Mijia Cloud, dlg.io.mi.com, +.oray.com, +.sunlogin.net, +.push.apple.com` | 跳过嗅探的智能家居/推送域名 |
| `sniffer.force-dns-mapping` | `true` (Redir-Host 时) | Redir-Host 模式下强制 DNS 映射嗅探 |
| `iptables` | **删除** | 强制移除 iptables 相关配置 |
| `ebpf` | **删除** | 强制移除 eBPF 相关配置 |
| `auto-redir` | **删除** | 强制移除 auto-redir（由 OpenClash 防火墙管理） |
| `routing-mark` | `6666` (非自定义标记时) | 固定路由标记值 |
| `external-controller-cors.allow-private-network` | `true` (有 CORS origin 时) | 允许私有网络访问 API |

**有条件默认设置**（仅在用户未配置时自动添加）：

| 设置 | 默认值 | 条件 |
|------|--------|------|
| `keep-alive-interval` | `15` | 仅当配置中未设置 |
| `keep-alive-idle` | `600` | 仅当配置中未设置 |
| `ntp.enable` | `true` | 无条件启用（`yml_change.sh` 始终设置）；仅 server/port/interval/write-to-system 为未设置时添加 |
| `ntp.server` | `time.apple.com` | 仅当配置中未设置 |
| `ntp.port` | `123` | 仅当配置中未设置 |
| `ntp.interval` | `30` (分钟) | 仅当配置中未设置 |
| `ntp.write-to-system` | `true` | 仅当配置中未设置 |

**防火墙固定值**（硬编码在 `init.d/openclash` 中）：

| 常量 | 值 | 说明 |
|------|-----|------|
| `PROXY_FWMARK` | `0x162` | 所有被代理流量的防火墙标记，不可修改 |
| `PROXY_ROUTE_TABLE` | `0x162` | 策略路由表 ID，不可修改 |
| `SKIP_GROUP` | `65534` | 绕过代理的组 ID (skgid) |

**内核模块依赖**（缺少时会导致启动报错）：

| 运行模式 | fw4 (nftables) 需要的 kmod | fw3 (iptables) 需要的 kmod |
|----------|---------------------------|---------------------------|
| Redir-Host / Fake-IP (非TUN) | `kmod-nft-tproxy` | `kmod-ipt-tproxy` |
| TUN 模式 | `kmod-tun` + `kmod-nft-tproxy` | `kmod-tun` + `kmod-ipt-tproxy` |
| 混合模式 (Mix) | `kmod-tun` + `kmod-nft-tproxy` | `kmod-tun` + `kmod-ipt-tproxy` |

> **故障排查**：如果启动日志提示 "nft_tproxy module not found"，请在 LuCI 的「系统 → 软件包」中搜索安装 `kmod-nft-tproxy`；提示 "xt_TPROXY module not found"，安装 `kmod-ipt-tproxy`。TUN 模式还需 `kmod-tun`（同样在 LuCI 软件包页面安装）。注意 fw4 环境下应检查 `nft_tproxy` 而非 `xt_TPROXY`。

### 8.2 模式设置标签页 (op_mode)

#### 8.2.1 en_mode — 选择运行模式 (Select Mode)
- **UCI 选项**: `openclash.@openclash[0].en_mode`
- **可选值**:
  - `redir-host` — 兼容模式 (Redir-Host)
  - `redir-host-tun` — 兼容模式 (TUN)
  - `redir-host-mix` — 兼容模式 (混合)
  - `fake-ip` — Fake-IP 模式
  - `fake-ip-tun` — Fake-IP (TUN)
  - `fake-ip-mix` — Fake-IP (混合)
- **Mihomo 对应配置**: `dns.enhanced-mode` (fake-ip / redir-host)
- **Redir-Host 模式**: DNS 解析在客户端完成，核心根据 IP 规则分流。适合 BT/PT 下载
- **Fake-IP 模式**: DNS 解析在核心完成，返回虚假 IP (198.18.x.x)，性能更高。规则基于域名匹配。**推荐作为日常使用首选**：「Fake-IP 模式」(选项 `fake-ip`)——DNS 解析快、占资源低，日常够用；若个别应用连不上（NAT 问题）改用「Fake-IP 混合」(选项 `fake-ip-mix`)；若固件装了 Docker 可直接用「Fake-IP TUN」(选项 `fake-ip-tun`)
- **TUN 模式**: 创建虚拟网卡，以网络层接管所有流量。对应 Mihomo `tun.enable=true`。需要 `kmod-tun` 内核模块
- **混合模式**: TCP 使用 system 栈 (redirect)，UDP 使用 gvisor 栈 (TUN)。对应 Mihomo `tun.stack=mixed`。适合非直连游戏等对 NAT 类型有要求的场景

#### 8.2.2 stack_type — TUN 堆栈类型 (Stack Type)
- **UCI 选项**: `openclash.@openclash[0].stack_type`
- **可选值**: `system` / `gvisor` / `mixed`
- **Mihomo 对应配置**: `tun.stack`
- **system**: 使用 Linux 系统协议栈，性能和稳定性最好
- **gvisor**: 用户空间网络协议栈，隔离性更好，避免内核态/用户态切换
- **mixed**: TCP 用 system、UDP 用 gvisor
- **依赖**: 仅在 TUN/混合模式下显示

#### 8.2.3 proxy_mode — 代理模式 (Proxy Mode)
- **UCI 选项**: `openclash.@openclash[0].proxy_mode`
- **可选值**: `rule` / `global` / `direct`
- **Mihomo 对应配置**: `mode`
- **默认**: `rule`
- 此选项等同一键切换全局/规则/直连模式

#### 8.2.4 enable_udp_proxy — UDP 流量转发 (Proxy UDP Traffics)
- **UCI 选项**: `openclash.@openclash[0].enable_udp_proxy`
- **默认**: 1 (开启)
- **说明**: 节点需支持 UDP 转发。Docker 环境可能导致 UDP 异常
- **依赖**: 仅 Redir-Host 模式显示
- **注意**: Fake-IP 模式即使关闭此选项，域名类 UDP 连接仍会经过核心

#### 8.2.5 delay_start — 延迟启动（秒） (Delay Start)
- **UCI 选项**: `openclash.@openclash[0].delay_start`
- **默认**: 0 (不延迟)
- **说明**: 开机后延迟指定秒数再启动 OpenClash

#### 8.2.6 log_size — 日志大小（KB） (Log Size)
- **UCI 选项**: `openclash.@openclash[0].log_size`
- **默认**: 1024 (1MB)
- **说明**: 核心日志文件 `/tmp/openclash.log` 的最大大小

#### 8.2.7 bypass_gateway_compatible — 旁路网关（旁路由）兼容 (Bypass Gateway Compatible)
- **UCI 选项**: `openclash.@openclash[0].bypass_gateway_compatible`
- **默认**: 0 (关闭)
- **说明**: 旁路由 (旁路网关) 模式下无法上网时尝试开启。如果设备没有 WLAN，建议禁用 LAN 接口的桥接选项

#### 8.2.8 disable_quic_go_gso — 禁用 quic-go GSO (Disable QUIC Go GSO)
- **UCI 选项**: `openclash.@openclash[0].disable_quic_go_gso`
- **默认**: 0 (关闭)
- **说明**: Linux 内核 6.6 以上版本遇到 QUIC UDP 问题时尝试开启。**Hysteria / Hysteria2 / TUIC 等基于 QUIC 协议的节点出现连接超时、断流、握手失败时，优先尝试开启此选项**
- **Mihomo 对应配置**: `disable-quic-go-gso` (全局 experimental 选项，写入 YAML 的 `experimental.disable-quic-go-gso: true`)

#### 8.2.9 small_flash_memory — 小闪存模式 (Small Flash Memory)
- **UCI 选项**: `openclash.@openclash[0].small_flash_memory`
- **默认**: 0 (关闭)
- **说明**: 将核心和 GEOIP 数据文件移到 `/tmp/etc/openclash`，节省闪存空间。路由重启后需重新下载

> **AI 行为指引 — QUIC 类节点（Hysteria / Hysteria2 / TUIC）故障排查**: 当用户报告 Hysteria、Hysteria2、TUIC 等基于 QUIC 协议的节点无法连接、频繁断流或握手超时时，AI 应先让用户生成调试日志查看核心日志中的 QUIC 相关错误。如日志含 `quic-go` / `GSO` / `timeout` 等关键字，**优先建议**用户在「插件设置→模式设置」中开启「禁用 quic-go GSO (Disable QUIC Go GSO)」选项并重启 OpenClash。这是 Linux 内核 ≥6.6 上最常见的 QUIC 兼容性问题。
> 
> **关于 `disable_udp_quic`（禁用 QUIC）**：此选项**不会**影响 Mihomo 内核自身的 Hysteria/Hysteria2/TUIC 等 QUIC 出站连接，无需因使用此类节点而关闭该选项。原因：所有模式（TUN/非TUN）下 QUIC REJECT 规则均在 filter INPUT 链 + IPv6 TUN 模式下额外在 FORWARD -o utun 链，Mihomo 内核自身出站 QUIC 走 OUTPUT 链，回复包的目标端口为临时端口（非 443），均不命中拦截规则。`disable_udp_quic` 的目的是让 LAN 客户端的 YouTube 等 QUIC 流量降级到 TCP 以便代理，与内核节点通信无关。
> 
> 若 GSO 选项开启后问题仍存在，建议查阅 [Mihomo Wiki Hysteria 配置](https://wiki.metacubex.one/config/proxies/hysteria/) 或 [Hysteria2 配置](https://wiki.metacubex.one/config/proxies/hysteria2/) 验证节点字段是否正确。

#### 8.2.10 运行模式切换按钮 (switch_mode)
- **模板**: `openclash/switch_mode`
- **功能**: 一键在 Redir-Host 和 Fake-IP 之间切换当前页面显示
- **触发**: `action_switch_mode` → 修改 UCI `operation_mode`

#### 8.2.11 运行模式实现详解

**启动流程中的关键变量传递** (来自 `init.d start_service()`):
1. `get_config()` 读取 UCI `en_mode`，解析出 `en_mode_tun`（TUN 标记）、`en_mode_fakeip`（Fake-IP 标记）、`en_mode_mix`（混合标记）
2. 将这些传递给 `yml_change.sh` 作为位置参数：
   - `$1` = DNS enhanced-mode 值（`fake-ip` 或 `redir-host`）
   - `$11` = en_mode_tun（0/1/2，决定是否启用 TUN）
   - `$12` = stack_type 或 `$30`（TUN 堆栈类型回退）

**yml_change.sh 中 `en_mode` 的 YAML 影响链**:
- **dns.enhanced-mode**: 根据 Fake-IP / Redir-Host 设置 → 影响 Mihomo 的 DNS 解析策略：
  - `fake-ip`: 所有 DNS 查询返回 198.18.x.x 假 IP，规则基于域名匹配，性能最优
  - `redir-host`: DNS 在客户端完成，规则基于真实 IP 匹配，适合 BT/PT
- **tun.enable**: `en_mode_tun != 0` 时设为 `true` → Mihomo 创建 `utun` 虚拟网卡接管流量
- **tun.stack**: `system`(系统协议栈)/`gvisor`(用户态协议栈)/`mixed`(TCP system + UDP gvisor)
  - `system`: 性能最好，走 Linux 内核 TUN 驱动
  - `gvisor`: 隔离性好，UDP NAT 支持更完善
  - `mixed`: TCP 用 system 栈 (REDIRECT)，UDP 用 gvisor 栈 (TUN)

**防火墙层面的影响** (`set_firewall()`):
- **Redir-Host (非 TUN)**: TCP 通过 REDIRECT 到 `proxy_port`(7892)，UDP 通过 TPROXY 到 `tproxy_port`(7895)，标记 fwmark 0x162
- **Fake-IP (非 TUN)**: 同上 + 额外匹配 `fakeip_range`(198.18.0.1/16) 的路由
- **TUN 模式**: 所有流量标记 0x162，路由到 `utun` 设备（策略路由），TUN 内部处理分流
- **混合模式 (Mix)**: TUN 设备处理 UDP（走 gvisor），TCP 走 REDIRECT（system 栈）

---

### 8.3 流量控制标签页 (traffic_control)

> **生效路径**: 绝大多数流量控制选项不修改 YAML，而是影响 `set_firewall()` 生成的 iptables/nftables 规则链。
>
> **AI 行为指引**: 当用户询问流量路由问题时（如"TUN 和 TPROXY 有什么区别"、"如何让某设备不走代理"、
> "旁路由/网关模式下如何配置"、"IPv6 流量如何控制"），AI 应结合本章节的防火墙规则详解
> 和 [Mihomo 监听器文档](https://wiki.metacubex.one/config/listeners/) 回答，说明不同模式
> 的工作原理（而非仅给出操作步骤），帮助用户理解后做出选择。
> 涉及防火墙实现细节时，查阅 [OpenClash 源码](https://github.com/vernesong/OpenClash/tree/dev) 中
> `init.d/openclash` 和 `yml_change.sh` 的相关逻辑。
> `set_firewall()` 通过 UCI `firewall.openclash` 注册为 `/var/etc/openclash.include`，由 OpenWrt firewall3/firewall4 框架加载。
> 支持 fw4 (nftables) 和 fw3 (iptables) 双后端自动检测。
> **注意**：如需按接口/用户/DSCP 等维度精细绕过，请使用「插件设置页面底部 → 来源流量访问控制」（`10-settings-geo-misc-src.md` §10.3）。黑白名单设备级绕过使用「插件设置 → 黑白名单」（`09-settings-dns-ac-ipv6.md` §9.2）。

#### 8.3.1 router_self_proxy — 路由本机代理 (Router-Self Proxy)
- **UCI 选项**: `openclash.@openclash[0].router_self_proxy`
- **默认**: 1 (开启)
- **说明**: 开启后，路由器本身发出的流量也会经过代理核心。仅在规则模式下生效。关闭后流媒体增强标签页所有功能将失效
- **实现细节**: 控制 OUTPUT 链规则是否生成（fw4 `openclash_output`/`openclash_mangle_output`，fw3 OUTPUT 规则），决定路由器自身出站流量是否重定向到 Mihomo。规则细节见 `06-firewall-options-dnsmasq.md` §6.2「各选项对防火墙规则的具体影响 → `router_self_proxy`」。（注意：非 TUN 模式下 Fake-IP 模式即使关闭本选项，仍会为 Fake-IP 流量创建 OUTPUT 链）

#### 8.3.2 disable_udp_quic — 禁用 QUIC (Disable QUIC)
- **UCI 选项**: `openclash.@openclash[0].disable_udp_quic`
- **默认**: 1 (开启)
- **效果**: 对 UDP 443 端口的流量执行 REJECT，阻止 YouTube 等使用 QUIC 协议传输 (降级到 TCP)
- **执行方式**: 通过 iptables/nftables 规则阻断 UDP 443，排除中国大陆 IP 段
- **实现细节**: `set_firewall()` 在 **filter INPUT 链 + FORWARD 链** 插入 QUIC REJECT 规则（fw4：`nft insert rule inet fw4 input position 0 udp dport 443 <匹配条件> counter reject`，fw3 等效）。匹配条件由 `china_ip_route` 决定方向：`china_ip_route=1`（绕过大陆）时为 `ip daddr != @china_ip_route`（REJECT 除国内外的 UDP 443），`china_ip_route=2`（绕过海外）时为 `ip daddr @china_ip_route`。TUN 模式额外在 `forward oifname utun` 插入同规则覆盖经 utun 转发的流量；IPv6 按 `china_ip6_route` 对应处理（`ip6 daddr [!=] @china_ip6_route`）。与 `china_ip_route_pass`/dnsmasq ipset 无直接关系。详见 `06-firewall-options-dnsmasq.md` §6.2「各选项对防火墙规则的具体影响 → `disable_udp_quic`」。

#### 8.3.3 skip_proxy_address — 绕过服务器地址 (Skip Proxy Address)
- **UCI 选项**: `openclash.@openclash[0].skip_proxy_address`
- **默认**: 0 (关闭)
- **说明**: 绕过配置中服务器地址的代理，防止重复代理 (代理嵌套)
- **实现细节**: 开启后看门狗脚本 `openclash_watchdog.sh` 中的 `skip_proxies_address()` 函数（每 30 个看门狗周期执行一次）解析 YAML 中所有代理节点（`proxies` 和 `proxy-providers`）的 `server` 地址，域名通过 `openclash_debug_dns.lua` 调用 Mihomo 内核 API（`/dns/query`）解析为 IP 后，加入已存在的 `localnetwork` nft set（或 ipset），复用链首 `ip daddr @localnetwork counter return` 规则跳过代理。见 `06-firewall-options-dnsmasq.md` §6.2「各选项对防火墙规则的具体影响 → `skip_proxy_address`」。

#### 8.3.4 common_ports — 仅允许常用端口流量 (Common Ports Proxy Mode)
- **UCI 选项**: `openclash.@openclash[0].common_ports`
- **默认**: 0 (禁用)
- **说明**: 仅让常用端口 (HTTP/HTTPS/邮件等) 的流量走代理，防止 BT/P2P 流量占用线路
- **预设值**: `21 22 23 53 80 123 143 194 443 465 587 853 993 995 998 2052 2053 2082 2083 2086 2095 2096 2197 5222 5223 5228 5229 5230 8080 8443 8880 8888 8889`
- **自定义格式**: 空格分隔的端口号，如 `443 80` 或范围 `20-443`
- **依赖**: 仅 Redir-Host 系列模式
- **实现细节**: 非 0 时在代理链插入 `th dport != @common_ports counter return`，仅代理常用端口、绕过 P2P/BT 等非标端口；禁用时不加端口限制，所有 TCP 都重定向。规则细节见 `06-firewall-options-dnsmasq.md` §6.2「各选项对防火墙规则的具体影响 → `common_ports`」。

#### 8.3.5 china_ip_route — 实验性：绕过指定区域 IP (China IP Route)
- **UCI 选项**: `openclash.@openclash[0].china_ip_route`
- **可选值**:
  - `0` — 关闭
  - `1` — 绕过中国大陆 IP (将国内 IP 直连，提升性能)
  - `2` — 绕过海外 IP
- **说明**: 强烈推荐启用「绕过中国大陆」。启用后，会在 `fake-ip-filter` 添加 `rule-set:oc-cn-domain` 规则集 (旧版本为 GeoSite 数据库中分类为 `CN` 的域名)，且解析 IP 位于大陆 IP 段范围内的流量将不进入内核，显著降低内核性能开销。旁路由模式下如果遇到大陆域名无法访问可尝试开启"旁路由兼容"选项
- **Mihomo 对应**: 通过 `dns.fake-ip-filter` 添加 `rule-set:oc-cn-domain` 规则集，使中国大陆域名返回真实 IP 而非 Fake-IP；同时自动注册对应的 `rule-providers` 条目指向 MetaCubeX geosite CN MRS 文件
- **实现细节（双重机制）**: 1) **YAML 层面**: `yml_change.sh` 修改 `dns.fake-ip-filter`——blacklist 模式（默认）追加 `rule-set:oc-cn-domain`，whitelist 模式移除 CN 相关过滤器，rule 模式前置 `RULE-SET,oc-cn-domain,real-ip`。效果：匹配的中国大陆域名返回真实 IP，绕过 Fake-IP 机制。2) **防火墙层面**: `set_firewall()` 使用 chnroute IP 列表构建 nftables set（`china_ip_route` 或者 `china_ip6_route`），在 redirect/TPROXY 链中匹配国内真实 IP 直连 return。两层面互为补充——YAML fake-ip-filter 确保大陆域名获得真实 IP，防火墙 nft set 匹配这些真实 IP 使其跳过代理。

#### 8.3.6 intranet_allowed — 仅允许内网 (Only Intranet Allowed)
- **UCI 选项**: `openclash.@openclash[0].intranet_allowed`
- **默认**: 1 (开启)
- **说明**: 开启后控制面板和连接代理端口仅能从内网访问，不暴露到公网
- **Mihomo 对应**: `allow-lan: true` + `bind-address: "*"`
- **实现细节**: 双重保护——1) YAML 层面：`yml_change.sh` 设置 `allow-lan: true` + `bind-address: "*"` 使内核监听所有接口（关闭时 `allow-lan: false`，仅监听 127.0.0.1）。2) 防火墙层面：创建 `openclash_wan_input` 链，REJECT 来自 WAN 口对全部服务端口的访问，关闭时删除该链。规则细节见 `06-firewall-options-dnsmasq.md` §6.2「各选项对防火墙规则的具体影响 → `intranet_allowed`」。

#### 8.3.7 intranet_allowed_wan_name — WAN 接口名称 (WAN Interface Name)
- **UCI 选项**: `openclash.@openclash[0].intranet_allowed_wan_name`
- **说明**: 指定哪个接口被识别为 WAN。用于仅允许内网功能区分内外网
- **依赖**: `intranet_allowed=1`

#### 8.3.8 lan_interface_name — LAN 接口名称 (LAN Interface Name)
- **UCI 选项**: `openclash.@openclash[0].lan_interface_name`
- **可选值**: 系统中所有网络接口名
- **默认**: 0 (禁用)
- **说明**: 指定 LAN 接口名称，用于通过 `ip address show <接口>` 获取路由器 LAN IP 地址（供控制面板地址显示、API 调用、调试日志等使用）。设为 0 则自动检测

#### 8.3.9 local_network_pass — 本地 IPv4 网络绕过列表 (Local Network Pass)
- **UCI 选项**: `openclash.@openclash[0].local_network_pass`
- **存储文件**: `/etc/openclash/custom/openclash_custom_localnetwork_ipv4.list`
- **说明**: 目标地址为列表中 IP 的流量不经过核心

#### 8.3.10 chnroute_pass — 绕过指定区域 IPv4 黑名单 (Chnroute Bypassed List)
- **UCI 选项**: `openclash.@openclash[0].chnroute_pass`
- **存储文件**: `/etc/openclash/custom/openclash_custom_chnroute_pass.list`
- **说明**: 列表中的域名/IP 不受中国 IP 绕行选项影响，依赖 Dnsmasq。**默认已预置** `services.googleapis.cn`、`googleapis.cn`、`xn--ngstr-lra8j.com` 以解决 Google Play 下载问题
- **依赖**: `enable_redirect_dns != 2`
- **注意**: chnroute_pass 仅在 DNS 解析层面将域名解析 IP 加入 `china_ip_route_pass` nft set 使其跳过绕行规则，但若上游 DNS 本身将这些域名解析到国内 IP，加入 set 后仍会被 `china_ip_route` 规则误判为国内 IP 而绕行。**仅靠 chnroute_pass 不足以解决 Google Play 下载问题**——必须同时从 DNS 解析（`nameserver-policy` 强制走境外 DNS）和规则匹配（自定义规则走代理）两方面入手，详见 `03-errors.md` §3.14 功能异常类

#### 8.3.11 UPNP 流量排除（无 UCI 选项，自动生效）
- **触发条件**: 系统已安装并运行 `upnpd`（`/etc/config/upnpd` 存在且 `upnp_lease_file` 指向有效租约文件）
- **说明**: 自动读取 upnpd 租约文件，为 UPnP 端口映射创建防火墙绕过规则，防止 BT/PT 下载、游戏主机等 UDP UPnP 流量被 TPROXY 错误代理
- **实现细节**: 防火墙初始化阶段 `set_firewall()` 创建 `openclash_upnp` 链并在 `openclash_mangle` 链中通过 `jump openclash_upnp`（规则位置在最终 TPROXY 之前）。`upnp_exclude()` 函数读取 upnpd 租约文件（格式 `UDP:<ext_port>:<int_ip>:<int_port>`），为每条租约在 `openclash_upnp` 链中添加 `ip saddr <int_ip> <proto> sport <int_port> counter return` 规则。看门狗 `openclash_watchdog.sh` 每 30 个周期（首周期立即执行，之后每 `UPNP_INTERVAL=30` 即约 30 分钟）执行 UPNP 规则同步：① **清理过期规则**——遍历 `openclash_upnp` 链现有规则，删除租约文件中已不存在的条目；② **添加新规则**——读取租约文件，为新增的 UPnP 映射补充 RETURN 规则。规则细节见 `06-firewall-options-dnsmasq.md` §6.2「各选项对防火墙规则的具体影响 → UPNP 流量排除」。

---
