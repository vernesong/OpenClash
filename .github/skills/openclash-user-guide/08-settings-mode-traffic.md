## 插件设置页面 (Plugin Settings / settings)

> **用途**: 插件设置页的模式与流量控制标签页各选项（UCI 与实现，§8.1–8.3）。

> **小节索引**: §8.1 实现总览（§8.1.1 强制覆盖/禁用）· §8.2 模式设置（en_mode / stack_type / proxy_mode / …，§8.2.12 四栈选型、§8.2.13 转发模式、§8.2.14 默认值与 MIPS 来源、§8.2.15 TUN 数据面参数结论与选型）· §8.3 流量控制（router_self_proxy / disable_udp_quic / china_ip_route / …）· §8.4 性能实测数据（§8.4.1 测量条件、§8.4.2 四栈 × gso 主表、§8.4.3 转发路径、§8.4.4 TUN 参数、§8.4.5 持续负载与延迟、§8.4.6 内核 sysctl）

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
| `sniffer.force-domain` | `+.netflix.com, +.nflxvideo.net, +.amazonaws.com, +.media.dssott.com` | 强制嗅探的流媒体域名 |
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
| *(内联字面量 skgid)* | `65534` | 绕过代理的组 ID；直接写在 nft 规则里（`init.d/openclash` 中**没有**同名变量） |

**内核模块依赖**（缺少时会导致启动报错）：

| 运行模式 | fw4 (nftables) 需要的 kmod | fw3 (iptables) 需要的 kmod |
|----------|---------------------------|---------------------------|
| Redir-Host / Fake-IP (非TUN) | `kmod-nft-tproxy` | `kmod-ipt-tproxy` |
| TUN 模式 | `kmod-tun` + `kmod-nft-tproxy` | `kmod-tun` + `kmod-ipt-tproxy` |
| 混合模式 (Mix) | `kmod-tun` + `kmod-nft-tproxy` | `kmod-tun` + `kmod-ipt-tproxy` |

> **故障排查**：如果启动日志提示 `nft_tproxy module not found`，请在 LuCI 的「系统 → 软件包」中搜索安装 `kmod-nft-tproxy`；提示 `xt_TPROXY module not found`，安装 `kmod-ipt-tproxy`。TUN 模式还需 `kmod-tun`（同样在 LuCI 软件包页面安装）。注意 fw4 环境下应检查 `nft_tproxy` 而非 `xt_TPROXY`。

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

#### 8.2.2 stack_type — TUN 堆栈类型 (Select Stack Type)
- **UCI 选项**: `openclash.@openclash[0].stack_type`
- **可选值**: `system` / `gvisor` / `mixed` / `mips`
- **Mihomo 对应配置**: `tun.stack`
- **system**: 内核协议栈，每字节 CPU 最低；吞吐约为 `mips` 的一半
- **gvisor**: 隔离性最好，但除纯大流量上传外均不可靠（单连接吞吐低、短连接不稳、UDP 200 B 丢包约 55%）
- **mixed**: TCP 走 system、UDP 走 gvisor；UDP 丢包与 `system` 同档
- **mips**（插件默认）: 轻量用户态协议栈（mipstack，纯 Go、无 cgo），两种形态吞吐最高、短连接最快
- **依赖**: 仅在 TUN/混合模式下显示
- **四栈性能数据与选型**: 选型见 §8.2.12、完整数据见 §8.4.2；转发模式见 §8.2.13；默认值与 MIPS 来源见 §8.2.14；TUN 数据面参数（`gso` 等）结论见 §8.2.15

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
- **依赖**: 仅非 TUN 模式（`fake-ip` / `redir-host`）显示
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
- **默认**: 0 (关闭)；但 `uci-defaults/luci-openclash` 在 Linux 内核 > 6.6 的固件上初始化为 1
- **说明**: Linux 内核 6.6 以上版本遇到 QUIC UDP 问题时尝试开启。**Hysteria / Hysteria2 / TUIC 等基于 QUIC 协议的节点出现连接超时、断流、握手失败时，优先尝试开启此选项**
- **Mihomo 对应配置**: `experimental.quic-go-disable-gso: true`（注意键名顺序是 `quic-go-disable-gso`）

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
- **tun.stack**: 由 `stack_type` 写入（`system` / `gvisor` / `mixed` / `mips`，插件默认 `mips`）；各栈含义与选型见 §8.2.2、§8.2.12

**防火墙层面的影响** (`set_firewall()`):
- **Redir-Host (非 TUN)**: TCP 通过 REDIRECT 到 `proxy_port`(7892)，UDP 通过 TPROXY 到 `tproxy_port`(7895)，标记 fwmark 0x162
- **Fake-IP (非 TUN)**: 同上 + 额外匹配 `fakeip_range`(198.18.0.1/16) 的路由
- **TUN 模式**: 所有流量标记 0x162，路由到 `utun` 设备（策略路由），TUN 内部处理分流
- **混合模式 (Mix)**: TUN 设备处理 UDP（走 gvisor），TCP 走 REDIRECT（system 栈）

#### 8.2.12 TUN 堆栈选型

**各栈定义**
- `system`：系统协议栈（内核）
- `gvisor`：用户态 gVisor 栈，隔离性最好
- `mixed`：TCP 走 `system`、UDP 走 `gVisor`（源码：`Mixed` 内嵌 `*System`，仅给 UDP 注册 gVisor handler/forwarder）
- `mips`（插件默认）：mihomo 自研纯 Go 用户态栈（mipstack）

**选型结论**（性能数据见 §8.4.2）
1. **默认 `mips`**（插件默认，见 §8.2.14）：两种形态吞吐最高、短连接最快。
2. **`gso` 保持开启（插件默认）**：全栈全形态正收益，是唯一有量级影响的数据面参数。
3. **看重每字节 CPU 选 `system`**（吞吐约为 `mips` 的一半）；`mixed` ≈ `system`；`gvisor` 不建议使用（除纯大流量上传外均不可靠）。
4. **必须整机接管时才用 TUN**：REDIRECT / TPROXY 的内核短路比 TUN 数据面便宜 1–2 个数量级（见 §8.2.13）。
5. **高并发会明显降速**：40/100 连接时四栈同档回落到 32–57 MB/s（合批失效，见 §8.4.5）；连接数多的场景宜用 REDIRECT/TPROXY（见 §8.4.3）。

> 四种栈均可代理路由器自身流量：经插件默认的「标记 + 策略路由进 TUN」即可（见 §8.2.11），无需其它开关。

#### 8.2.13 转发模式（tun / redirect / tproxy）与建议

**OpenClash 现状**（`init.d` 的 `set_firewall`）
- 非 TUN 模式：**TCP 用 REDIRECT**（`redirect to $proxy_port`），**UDP 用 TPROXY**（`mark set 0x162` + `tproxy ip to 127.0.0.1:$tproxy_port`），LAN 与「路由器自身」各一套链（`openclash_mangle*` / `openclash_output`）
- TUN 模式：流量进 `utun`，由所选栈处理

**建议**（对比数据见 §8.4.3）
1. **优先 REDIRECT/TPROXY**：批量吞吐与直连同级（内核 `splice` 零拷贝中继），每 256 MB core CPU 约 0.1 s、只有 TUN 数据面的约 1/30–1/100；短连接约为直连的 50%，高于 TUN。TUN 仅用于必须整机接管（如 Docker、无法下发透明代理规则的场景）。
2. **保持现状（TCP=REDIRECT、UDP=TPROXY）**：两者 TCP 批量吞吐与 CPU 同级，而 REDIRECT 不需要额外的 `ip rule`/local 路由表，且对路由器自身流量同样生效。
3. TPROXY-TCP 的意义在于**透明代理链路更干净**，属功能取舍而非性能优化：REDIRECT 在 PREROUTING 把目标 DNAT 成本地地址，代理只能靠 `getsockopt(SO_ORIGINAL_DST)` 从 conntrack 反查客户端原本要去的目标（查不到就静默断连）；TPROXY 不改写报文，目标直接来自报文本身（`github.com/metacubex/mihomo/listener/tproxy/tproxy.go` 读 `conn.LocalAddr()`）。**源 IP 两种方式都会保留**。
4. **旁路由纯转发（不经代理）不是瓶颈**：转发 + NAT 可达线路速率，CPU 开销可忽略（`FLOWOFFLOAD` 把已建立连接交给 flowtable，开关无差异，且不影响被代理流量——命中 mark/TPROXY 的报文本就不走 offload）。旁路由的 masquerade 可关（主路由能回程即可）但收益≈零。
5. **UDP 小包路径**：丢包基本由「每秒包数」而非转发方式决定（`mips`/`system` 下 TPROXY 与 TUN 同档）；flood 场景交付 TUN ≈ TPROXY（约 43–45 MB/s），`gvisor` 只有约 1/4（见 §8.4.3）。

#### 8.2.14 默认值与 MIPS 来源

- **mihomo 内核**：主配置 `tun:` 段未写 `stack` 时默认 = `mips`（`config/config.go` 的 `DefaultRawConfig` 写 `Stack: C.TunMips`，上游提交「change default IP stack mode to mips」）。仅 `listeners:` 内联的 tun 项默认 `gvisor`（`listener/parse.go`）；`TUNStack` 类型零值仍是 `gvisor`（`constant/tun.go`，内部实现细节）。
- **OpenClash 插件默认 = `mips`**（`settings.lua` 的 `stack_type` / `stack_type_v6` 默认值，`yml_change.sh` 取不到参数时同样回退为 `mips`），且 `yml_change.sh` 每次都会把 `stack` 与 `gso: true` 显式写入配置 ⇒ **插件与内核默认值一致**。
- 官方 wiki（TUN → stack）写「如无使用问题，建议使用 `mixed` 栈，默认 `gvisor`」，与内核、插件默认 `mips` 不一致，以本文档数据为准。
- `mips` 基于 `github.com/metacubex/mipstack`（README 自述：pure-Go、无需 cgo）；在 mihomo 中先用于 ZeroTier 与 WireGuard 出站的 `ip-stack`，TUN 集成较晚（随 sing-tun v0.4.24 引入）。

#### 8.2.15 TUN 数据面参数（gso / mtu / congestion-controller / stack）

**参数分类**（字段定义：`github.com/metacubex/mihomo/listener/config/tun.go`）

| 类别 | 参数 | 说明 |
|------|------|------|
| **影响数据面吞吐/CPU** | `stack`、`gso`、`gso-max-size`、`mtu`、`congestion-controller`、`endpoint-independent-nat` | `congestion-controller` **仅 `mips` 生效**；`endpoint-independent-nat` 只改 UDP NAT 行为 |
| 只影响路由/抓取范围（控制面） | `auto-route`、`auto-redirect`、`strict-route`、`route-address(-set)`、`route-exclude-address(-set)`、`include/exclude-interface`、`include/exclude-uid(-range)`、`include/exclude-mac-address`、`exclude-src/dst-port(-range)`、`iproute2-table-index`、`iproute2-rule-index`、`loopback-address` | 改的是**哪些流量进 TUN**，不改变单连接处理开销 |
| 协议辅助 / 运维 | `dns-hijack`（DNS）、`disable-icmp-forwarding`（ICMP）、`udp-timeout`/`icmp-timeout`（会话存活时长）、`file-descriptor`（fd 上限）、`processors-per-channel`（gvisor 专用）、`recvmsgx`/`sendmsgx`（darwin 专用） | 拿去测「吞吐」没有意义 |

**参数结论与建议**（适用于路由器自身流量、LAN 转发两种形态）

1. **`gso` 是唯一有量级影响的参数，插件默认开启**（`yml_change.sh` 重建 `tun` 段时写入 `gso: true`）。
   - 全栈全形态正收益：下载/短连接 `system`/`mixed`/`mips` 明显提升、每 256 MB CPU 降 30～45%；上传 `gvisor` +637%、`mips` +45%。完整量化见 §8.4.2。
   - 代价：仅 Linux 支持；GSO 超包在出口网卡按 MTU 分段（对端 MTU 较小时多一层分片）。遇到兼容性问题时可按文末方法关闭。
   - 实现位置：`github.com/metacubex/sing-tun/tun_linux.go`（`enableGSO()`；UDP offload 失败会被忽略，TCP offload 失败则建 tun 失败）——GSO 属设备层，与所选栈无关。
2. **`mtu`、`gso-max-size`、`congestion-controller`、`processors-per-channel`、`endpoint-independent-nat` 无可测收益，保持默认**（对比数据见 §8.4.4）。
   - `mtu: 9000` 不是提速手段（GSO 超包在出口网卡仍需按 MTU 分段；改小 `mtu` 反而约 -6%）；`gso-max-size` 默认 65536 已足够。
   - `congestion-controller` 仅 `mips` 消费（唯一使用点 `github.com/metacubex/sing-tun/stack_mipstack.go`，`gvisor`/`system`/`mixed` 忽略该字段）：`cubic`/`reno`/`bbr`/`bbr3` 差异在 ±5% 波动范围内，保持 `cubic`；填非法值会使核心启动失败（`invalid TCP congestion control`）。
   - `endpoint-independent-nat` 只改 UDP NAT 行为；`processors-per-channel` 对 `gvisor` 无改善。
3. **栈选择见 §8.2.12（数据见 §8.4.2）**：默认 `mips` + `gso`（两种形态吞吐最高、短连接最快）；看重每字节 CPU 选 `system`；`gvisor` 仅在纯大流量上传时有优势；四种栈代理路由器自身流量经插件默认的标记 + 策略路由即可（无需 `auto-redirect`）。
4. **延迟**：满载时小请求延迟 `mips` 升高约 320–360%（~2 ms → ~8–12 ms/req）、`mixed` 约 43 ms、`gvisor` 约 105 ms 且伴随失败（32 KB ×200；见 §8.4.5）；低延迟优先选内核短路路径（REDIRECT/TPROXY，见 §8.2.13）。
5. **内核 sysctl 无需调优**：`rmem_max`/`wmem_max`/`tcp_rmem`/`tcp_wmem`（调至 16 MB）、`tcp_congestion_control=bbr`、`default_qdisc=fq`、`netdev_max_backlog`/`netdev_budget`、`tcp_fastopen`/`tcp_max_syn_backlog`/`somaxconn` 等即使全部一起修改，差异仍 ≤5%（`bbr` 反而略差）——TUN、REDIRECT、TPROXY 三种路径均已验证（见 §8.4.6）。
6. `tun.gso` 与 `experimental.quic-go-disable-gso`（插件「禁用 quic-go GSO」开关）互不影响：前者作用于 tun 设备层；后者在核心启动前设置环境变量 `QUIC_GO_DISABLE_GSO`（`github.com/metacubex/mihomo/hub/executor/executor.go`），作用于 QUIC 的 UDP socket。内核并未默认禁用 GSO：`setsockopt(UDP_SEGMENT)`/`UDP_GRO` 均可用。QUIC 报文同样经过 tun，故 `tun.gso` 对 UDP/QUIC 吞吐同样有正收益。
7. **持续满载无衰减**：连续满载 10 分钟（四栈均验证：单连接 2 GB 循环 + 4 连接循环）吞吐、每 256 MB CPU、RSS/fd 均平稳，无热降频——可长期满速（见 §8.4.5）。

**如何覆盖默认值**：`tun` 段由 `yml_change.sh` 按模板重建（写入 `enable`/`stack`/`device`/`dns-hijack`/`endpoint-independent-nat`/`auto-route`/`auto-detect-interface`/`auto-redirect`/`strict-route`/`disable-icmp-forwarding`/`gso`）；需要不同取值时用**覆写模块的 `[YAML]` 块**（在 `yml_change.sh` 之后执行，可覆盖最终配置），保存后**重启 OpenClash**（覆写模块仅在 start/restart 生效）：

```yaml
tun:
  gso: false      # 遇到 GSO 兼容性问题时关闭；插件默认开启
```

### 8.3 流量控制标签页 (traffic_control)

> **生效路径**: 绝大多数流量控制选项不修改 YAML，而是影响 `set_firewall()` 生成的 iptables/nftables 规则链。
>
> **AI 行为指引**: 当用户询问流量路由问题时（如「TUN 和 TPROXY 有什么区别」「如何让某设备不走代理」、
> 「旁路由/网关模式下如何配置」「IPv6 流量如何控制」），AI 应结合本章节的防火墙规则详解
> 和 [Mihomo 监听器文档](https://wiki.metacubex.one/config/inbound/) 回答，说明不同模式
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
- **默认**: 0 (关闭)
- **可选值**:
  - `0` — 关闭
  - `1` — 绕过中国大陆 IP (将国内 IP 直连，提升性能)
  - `2` — 绕过海外 IP
- **说明**: 强烈推荐启用「绕过中国大陆」。启用后，默认在 `fake-ip-filter` 添加 `rule-set:oc-cn-domain`，也可选择使用当前 GeoSite 数据库中的 `cn` 分类；解析 IP 位于大陆 IP 段范围内的流量将不进入内核，显著降低内核性能开销。旁路由模式下如果遇到大陆域名无法访问可尝试开启「旁路由兼容」选项
- **Mihomo 对应**: 根据 `china_ip_route_domain_source`，通过 `dns.fake-ip-filter` 添加 MRS Rule-Set 或 GeoSite CN 规则，使中国大陆域名返回真实 IP 而非 Fake-IP；选择 MRS 时同时自动注册对应的 `rule-providers` 条目
- **实现细节（双重机制）**: 1) **YAML 层面**: `yml_change.sh` 根据域名数据源和 `fake-ip-filter-mode` 修改 `dns.fake-ip-filter`；默认 MRS 使用 `rule-set:oc-cn-domain`，GeoSite 使用 `geosite:cn`，rule 模式则使用对应的大写规则语法，whitelist 模式不追加并移除已有 CN 相关过滤器。2) **防火墙层面**: `set_firewall()` 使用 chnroute IP 列表构建 nftables set（`china_ip_route` 或者 `china_ip6_route`），在 redirect/TPROXY 链中匹配国内真实 IP 直连 return。两层面互为补充——YAML fake-ip-filter 确保大陆域名获得真实 IP，防火墙 nft set 匹配这些真实 IP 使其跳过代理。

#### 8.3.5.1 china_ip_route_domain_source — 中国大陆域名数据源 (China IP Route Domain Source)
- **UCI 选项**: `openclash.@openclash[0].china_ip_route_domain_source`
- **可选值**: `mrs`（默认）/ `geosite`
- **界面名称**: `mrs` 显示为「MetaCubeX 规则 cn.mrs（默认）」；`geosite` 显示为「GeoSite 规则 geosite:cn」
- **选择保留**: 关闭区域 IP 绕行后保存设置，会保留已保存的数据源选择；重新开启时继续使用该选择。
- **依赖**: 仅 Fake-IP 系列模式，并在 `china_ip_route` 或 `china_ip6_route` 启用时显示
- **说明**: `mrs` 使用 `MetaCubeX/meta-rules-dat` 提供的独立 `cn.mrs` 规则集，blacklist 模式追加 `rule-set:oc-cn-domain`，rule 模式追加 `RULE-SET,oc-cn-domain,real-ip`；`geosite` 使用当前 `/etc/openclash/GeoSite.dat` 中的 `cn` 分类，分别追加 `geosite:cn` 或 `GEOSITE,cn,real-ip`。whitelist 模式下两种来源都不自动追加 CN 过滤器。选择 `geosite` 时不会自动注册 `rule-providers.oc-cn-domain`，并会跟随用户配置的 GeoSite 数据源与更新周期。
- **资源与故障差异**: MRS 是默认值，使用独立 CN 规则集；GeoSite 从当前数据库读取 `cn` 分类。实测 `geosite:cn` 比 MRS 约多占用 20 MiB 内存（差值因内核和规则库而异）。MRS 本地文件缺失或损坏且下载失败时，Mihomo 仍可启动，但依赖该规则集的域名可能返回 Fake-IP，影响区域绕行；所需的 GeoSite 数据无法加载或缺少 `cn` 分类时，Mihomo 配置校验和启动会失败。

#### 8.3.6 intranet_allowed — 仅允许内网 (Only Intranet Allowed)
- **UCI 选项**: `openclash.@openclash[0].intranet_allowed`
- **默认**: 1 (开启)
- **说明**: 开启后控制面板和连接代理端口仅能从内网访问，不暴露到公网
- **Mihomo 对应**: `allow-lan: true` + `bind-address: "*"`
- **实现细节**: 双重保护——1) YAML 层面：`yml_change.sh` **无条件**设置 `allow-lan: true` + `bind-address: "*"` 使内核监听所有接口（该选项本身不控制 YAML）。2) 防火墙层面：创建 `openclash_wan_input` 链，REJECT 来自 WAN 口对全部服务端口的访问，关闭时删除该链。规则细节见 `06-firewall-options-dnsmasq.md` §6.2「各选项对防火墙规则的具体影响 → `intranet_allowed`」。

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
- **说明**: 列表中的域名/IP 不受中国 IP 绕行选项影响，依赖 Dnsmasq
- **依赖**: `enable_redirect_dns != 2`
- **Fake-IP 模式下的额外处理**: 「绕过指定区域」开启（`china_ip_route` 或 `china_ip6_route` 非 0）且 `en_mode=fake-ip` + `enable_redirect_dns != 2` 时，列表中的域名会被写入 `dns.fake-ip-filter`（黑名单模式写入 `+.域名`，规则模式写入 `DOMAIN-SUFFIX,域名,real-ip`，白名单模式则查找现有 `fake-ip-filter` 并删除包含这些域名的条目），不再依赖 `custom_fakeip_filter` 开关
- **注意**: chnroute_pass 仅在 DNS 解析层面将域名解析 IP 加入 `china_ip_route_pass` nft set 使其跳过绕行规则，但若上游 DNS 本身将这些域名解析到国内 IP，加入 set 后仍会被 `china_ip_route` 规则误判为国内 IP 而绕行。**仅靠 chnroute_pass 不足以解决 Google Play 下载问题**——必须同时从 DNS 解析（`nameserver-policy` 强制走境外 DNS，见内置覆写模块 `Google_Play`）和规则匹配（自定义规则走代理）两方面入手，详见 `03-errors.md` §3.14 功能异常类

#### 8.3.11 UPNP 流量排除（无 UCI 选项，自动生效）
- **触发条件**: 系统已安装并运行 `upnpd`（`/etc/config/upnpd` 存在且 `upnp_lease_file` 指向有效租约文件）
- **说明**: 自动读取 upnpd 租约文件，为 UPnP 端口映射创建防火墙绕过规则，防止 BT/PT 下载、游戏主机等 UDP UPnP 流量被 TPROXY 错误代理
- **实现细节**: 防火墙初始化阶段 `set_firewall()` 创建 `openclash_upnp` 链并在 `openclash_mangle` 链中通过 `jump openclash_upnp`（规则位置在最终 TPROXY 之前）。`upnp_exclude()` 函数读取 upnpd 租约文件（格式 `UDP:<ext_port>:<int_ip>:<int_port>`），为每条租约在 `openclash_upnp` 链中添加 `ip saddr <int_ip> <proto> sport <int_port> counter return` 规则。看门狗 `openclash_watchdog.sh` 每 30 个周期（首周期立即执行，之后每 `UPNP_INTERVAL=30` 即约 30 分钟）执行 UPNP 规则同步：① **清理过期规则**——遍历 `openclash_upnp` 链现有规则，删除租约文件中已不存在的条目；② **添加新规则**——读取租约文件，为新增的 UPnP 映射补充 RETURN 规则。规则细节见 `06-firewall-options-dnsmasq.md` §6.2「各选项对防火墙规则的具体影响 → UPNP 流量排除」。

---

### 8.4 性能实测数据

> 本章所有性能数字的完整明细。

#### 8.4.1 测量条件

- **两种形态**：**路由器自身**（本机客户端 ↔ 本机源站；域名经核心 fake-ip 解析 → 输出标记 → 策略路由进 TUN 闭环）与 **LAN 转发**（veth 命名空间客户端 ↔ 源站，同路径进 TUN）；并发档位另以 LAN 侧真实客户端（PC）交叉验证（见 §8.4.5）。§8.4.3 的转发路径与 UDP 对比也在设备内部完成（不经物理链路）。
- **场景**：批量 TCP 256 MB（下载＝服务端→客户端：单连接测 2 次、4 连接并发测 1 次；上传＝`iperf3 -P4 -t 6`，4 连接并发）；短连接 3000 次 × 32 KB（20 并发）；UDP 200 B @20 kpps、1400 B @7.5 kpps 各 5 s。
- **CPU**：核心进程 utime+stime（s/256MB）；`tun` 段与插件生成的标准配置一致。
- 数值单位：吞吐 MB/s、短连接 rps、丢包 %；单连接为两次测量（区间/并列）；`gso` 对比见 §8.4.2（表中为「关 → 开」的数值与变化幅度）。

#### 8.4.2 TUN 四栈 × `gso` 对比（主表）

> 单元格为 `gso` 关 → 开 的数值；括号内为开启后的变化幅度（按两组数据均值计算；单连接为两次测量的区间）。

**路由器自身流量**

| 场景 | `system` | `mixed` | `mips` | `gvisor` |
|------|----------|---------|--------|----------|
| 下载×单连接（MB/s） | 69 → 109（+58%） | 68 → 111（+63%） | 98–104 → 164–168（+64%） | 28 → 28（持平） |
| 下载×单连接 CPU（s/256MB） | 4.3 → 2.6（-40%） | 4.4 → 2.6（-41%） | 5.2 → 3.0（-42%） | 12.6 → 12.9（+2%） |
| 下载×4 连接（MB/s） | 63 → 99（+57%） | 62 → 90（+45%） | 77 → 115（+49%） | 54 → 53（-2%） |
| 上传×4 连接（MB/s） | 78 → 108（+38%） | 64 → 112（+75%） | 128 → 185（+45%） | 35 → 258（+637%） |
| 短连接（rps） | 729 → 716（-2%） | 715 → 758（+6%） | 1051 → 1277（+22%） | 647 → 62（-90%）\* |
| UDP 200 B 丢包（%） | 0.4 → 0.5（+0.1 个百分点） | 0.1 → 0.0（-0.1 个百分点） | 0.6 → 0.4（-0.2 个百分点） | 54 → 54（持平） |

**LAN 转发流量**

| 场景 | `system` | `mixed` | `mips` | `gvisor` |
|------|----------|---------|--------|----------|
| 下载×单连接（MB/s） | 44–47 → 66–68（+47%） | 46–47 → 67–69（+46%） | 66–72 → 147–148（+112%） | 22 → 22（持平） |
| 下载×单连接 CPU（s/256MB） | 5.1 → 3.5（-31%） | 5.1 → 3.6（-29%） | 6.2 → 3.5（-44%） | 15.3 → 14.5（-5%） |
| 下载×4 连接（MB/s） | 43 → 60（+40%） | 45 → 61（+36%） | 57 → 98（+72%） | 50 → 49（-2%） |
| 上传×4 连接（MB/s） | 71 → 102（+44%） | 64 → 98（+53%） | 106 → 185（+75%） | 34 → 253（+644%） |
| 短连接（rps） | 656 → 635（-3%） | 647 → 597（-8%） | 872 → 1162（+33%） | 93 → 401（+331%）\* |
| UDP 200 B 丢包（%） | 0.3 → 0.1（-0.2 个百分点） | 0.3 → 0.3（持平） | 1.6 → 1.5（-0.1 个百分点） | 55 → 52（-3 个百分点） |

> - \*：`gvisor` 短连接呈**双峰**波动——间歇处于劣化档（约 30–90 rps、大量请求失败）或正常档（150–650 rps、仍偶有失败），与 `gso`、客户端形态、平台均无关（表中 62/93/401 均为该区间的真实取值）。其余数据波动在 ±10% 内。
> - UDP 1400 B @7.5 kpps 丢包：各栈均 ≤0.9%（`gvisor` 0.8%）。

#### 8.4.3 转发路径对比

> 本轮对比使用**设备内部测试环境**（客户端与源站均位于设备内部、经虚拟网卡互通，不经物理链路），`gso` 开启。真实 PC 客户端另有链路上限（1GbE ≈ 110 MB/s、WiFi 更低）——此前表中 30–35 MB/s 的数字即受当时 PC 客户端链路限制。

| 路径 | 批量 TCP（单连接 / 4 连接） | 短连接（3000 次 × 32 KB，20 并发） | 每 256 MB core CPU |
|------|---------------------------|-----------------------------------|--------------------|
| 直连（不经代理，基线） | 0.96–1.15 / 1.64 GB/s | 5114 rps | 0 |
| LAN 客户端 → REDIRECT（TCP） | 0.97–1.13 / 1.55–1.63 GB/s | 2368–2636 rps | ~0.05–0.11 s |
| LAN 客户端 → TPROXY（TCP） | 0.86–1.10 / 1.55–1.63 GB/s | 2428–2556 rps | ~0.04–0.20 s |
| LAN 客户端 → TUN（四种栈） | 单连接 22–148 MB/s；4 连接 49–98 MB/s（见 §8.4.2） | 635–1162 rps（`gvisor` 波动） | 2.6–14.5 s |

> - **REDIRECT / TPROXY 的批量吞吐与直连同级**（中继走内核 `splice` 零拷贝，mihomo TCP↔TCP 转发；每 256 MB 只消耗约 0.1 s core CPU）；短连接约为直连的 50%（每条连接多约 0.2 ms 的核心建连开销）。TUN 数据面逐包过用户态栈，吞吐低一个数量级、CPU 高 1–2 个数量级。
> - REDIRECT 与 TPROXY（TCP）彼此持平；TPROXY 多需要一套 `ip rule` + 本地路由表，日常保持插件现状（TCP=REDIRECT、UDP=TPROXY）即可。

**高负载 UDP 对比**（同一测试环境；UDP 在非 TUN 模式下固定走 TPROXY，REDIRECT 只承载 TCP）

| 场景 | TPROXY | TUN `mips` | TUN `system` | TUN `gvisor` |
|------|--------|-----------|--------------|--------------|
| UDP 200 B @20 kpps：丢包 | 0.3% | 0.5% | 0.2% | 54% |
| UDP 200 B @40 kpps：丢包 | 13.2% | 13.2% | 10.9% | 55% |
| UDP 1400 B @7.5 kpps：丢包 | 0.0% | 0.0% | 0.0% | 0.0% |
| QUIC 形态（40 流 × 200 B × 500 pps）：丢包 | 0.1% | 0.0% | 0.0% | 55% |
| flood 1400 B（客户端尽力约 80 kpps）：丢包 / 交付 | ~62% / ~43 MB/s | ~62% / ~44 MB/s | ~60% / ~45 MB/s | ~91% / ~11 MB/s |

> - **`mips` / `system` 上 TPROXY 与 TUN 的 UDP 丢包同级**：小包丢包由「每秒包数」决定，不随转发方式变化；`gvisor` 无论走哪种路径都不可用（55% 以上丢包）。flood 场景交付 TUN ≈ TPROXY（~43–45 MB/s，受客户端发送能力限制），`gvisor` 仅约 1/4。
> - **旁路由纯转发（不经代理）**：转发 + NAT 达 97–106 MB/s（≈线路速率），CPU 开销可忽略；`FLOWOFFLOAD` 开关无差异。

#### 8.4.4 TUN 数据面参数（单连接对照）

`mips` + `gso`，单连接 256 MB 批量，其余参数保持默认：

| 参数 | 自身×下载单连接 | LAN×下载单连接 |
|------|------------|-----------|
| 默认（`mtu` 1500 / `gso-max-size` 默认 / `cubic`） | 165 / 166 | 161 |
| `mtu: 9000` | 161 / 165 | 159 |
| `mtu: 1280` | 155 / 157 | 151 |
| `gso-max-size: 16384` | 161 / 170 | 155 |
| `congestion-controller: bbr` | 156 / 165 | 159 |
| `endpoint-independent-nat: false` | 162 / 166 | 156 |

> 除 `mtu: 1280` 低约 6%（分段数随 MTU 变小而增多）外，其余差异均在 ±5% 的波动范围内：`mtu: 9000`、`gso-max-size` 放大、`bbr` 均无收益；`endpoint-independent-nat` 只影响 UDP NAT 行为，对 TCP 单连接无副作用 ⇒ **全部保持默认**（见 §8.2.15）。

#### 8.4.5 持续满载、高并发与延迟

四栈对照（`gso` 开启，路由器自身形态；`mips` 为原表数据，其余为本轮补测）：

| 场景 | `mips` | `system` | `mixed` | `gvisor` |
|------|--------|----------|---------|----------|
| 持续满载 10 分钟：单连接 2 GB 循环（MB/s） | ~165–167 | — | 108–113 | 28.3–28.8 |
| 持续满载 10 分钟：4 连接 2 GB 循环（MB/s） | ~116–120 | — | 95–100 | 54.1–55.0 |
| 40 连接并发（512 MB，MB/s） | ~38–41 | ~46–49 | 46.6 | 56.5 |
| 100 连接并发（512 MB，MB/s） | ~32 | ~35–42 | 40.8 | 48.5 |
| 混合：短连接（20 并发、32 KB）+ 后台 2 连接批量 | 526–714 rps / 83–109 MB/s | — | 183 rps / 60 MB/s | 60 rps / 33 MB/s |
| 延迟（32 KB 请求 ×200）：空载 → 满载 | ~2 ms → ~8–12 ms | — | ~2.1 ms → ~43 ms | ~3.3 ms → ~105 ms（含失败） |

> 四栈连续满载 10 分钟均无衰减（`mixed` 单连接循环 32+ 轮、`gvisor` 4 连接循环 16 轮全程平稳，无热降频）。并发 ≥40 连接时各栈同档回落（40–57 MB/s，原因见下）；`gvisor` 的并发吞吐靠极低的单连接吞吐（~1.4 MB/s）叠加而来，且满载延迟与失败率最差。满载延迟从好到差：`mips`（升高约 320–360%）＜ `mixed`（~43 ms）＜ `gvisor`（~105 ms，200 次中失败 4 次）。

**吞吐随并发数下降的原因**（`mips` + `gso`，512 MB 批量；含无代理直连参照）

| 并发连接数 | 2 | 4 | 8 | 16 | 40 | 100 |
|----------|---|---|---|----|----|-----|
| 吞吐（MB/s） | 143 | 119 | 102 | 81 | 50 | 40 |
| 核心写 tun 的平均合批大小 | 24.3 KB | 13.1 KB | 7.8 KB | 4.2 KB | 2.1 KB | 1.7 KB |
| 每 256 MB CPU（s） | 3.9 | 4.7 | 5.4 | 7.1 | 11.6 | 14.1 |

- 吞吐随连接数**平滑**下降；40 连接连续传输 2 GB 期间全程稳定，无随时间衰减。核心向 tun 写出的包速率封顶约 **2.5 万包/秒**，吞吐 ≈ 包速率上限 × 合批尺寸——**直接原因是单次写入的合批尺寸随并发数变小**（近似 ∝ 1/连接数）。
- 两种栈的每个包/每批都要经用户态处理（`system`：用户态地址改写 + 内核 TCP；`mips`：全用户态 TCP），读/写循环各只有一条运行在单线程上 ⇒ 并发升高后合批失效，逐批处理能力成为瓶颈；每字节 CPU 升至约 3 倍，并伴随重传（最多 1.4 万段）；`system` 趋势相同（107 降至 42 MB/s，-61%）。合批为何失效：sing-tun 单次写调用最多向栈取 64 个包、且 GRO 只在该批内合并（`github.com/metacubex/sing-tun/stack_mipstack.go`、`github.com/metacubex/sing-tun/tun_offload_linux.go`），而栈输出为全局单队列（256 槽，`github.com/metacubex/mipstack/stack.go`）⇒ 批内同连接连续包 ≈ 64/并发数。
- 交叉验证（LAN 侧真实客户端）：以 PC 作为客户端验证同一路径——40/100 连接 = 59 / 52 MB/s（`mips`）、`system` 40 连接 53 MB/s，合批 2.2–2.5 KB、包速率 ~2.5 万/秒，与表中规律一致；不经代理直连时同路径 40/100 连接达 106 / 94 MB/s ⇒ 该下降属 TUN 数据面特有（逐包用户态 + 合批失效），与客户端、链路无关。

#### 8.4.6 内核 sysctl 调优

`net.core.rmem_max`/`wmem_max` 调至 16 MB、`tcp_rmem`/`tcp_wmem` 调至 16 MB、`tcp_congestion_control=bbr`、`default_qdisc=fq`、`netdev_max_backlog=5000`、`netdev_budget=600`、`tcp_fastopen=3`、`tcp_max_syn_backlog=8192`、`somaxconn=8192`（`mips` + `gso`）：

| 阶段 | 自身×下载单连接 | 短连接 rps | LAN×下载单连接 |
|------|------------|-----------|-----------|
| 默认 | 159 / 159 | 1288 | 141 |
| 全部调优 | 154 / 154 | 1286 | 143 |
| 调优后还原 | 159 / 158 | 1245 | 147 |

同样参数在 **REDIRECT / TPROXY 路径**（同一测试环境；单连接 MB/s、短连接 rps）上也无影响：

| 阶段 | REDIRECT 单连接（两次） | REDIRECT 短连接 | TPROXY 单连接（两次） | TPROXY 短连接 |
|------|------------|-----------|-----------|-----------|
| 默认 | 974 / 1033 | 2368 rps | 1096 / 860 | 2556 rps |
| 全部调优 | 970 / 1078 | 2509 rps | 921 / 804 | 2428 rps |
| 调优后还原 | 1052 / 1129 | 2504 rps | 958 / 1005 | 2443 rps |

TPROXY 的 UDP 场景（200 B @20/40 kpps、1400 B @7.5 kpps、QUIC-40、flood）在三相位间的丢包差异也都在 3 个百分点以内。

> 调整上述全部参数对三种路径（TUN / REDIRECT / TPROXY）的吞吐、短连接、UDP 丢包影响都在 ±5% 波动范围内（`bbr` 反而略差）⇒ **无需调优，保持系统默认**（`bbr` 模块本身可用：`reno cubic bbr`）。

---
