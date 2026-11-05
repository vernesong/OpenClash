## 插件设置页面 (Plugin Settings / settings)

> **用途**: 插件设置页「模式设置」与「流量控制」标签页的选项、UCI 与实现（§8.1–8.4）。
> **LuCI 路径**: 服务 → OpenClash → 插件设置 → 模式设置 / 流量控制
> **UCI**: `openclash.@openclash[0].<option>`（匿名 section）

### 8.1 实现总览

```
UCI 写入 → start_service() → get_config() 读取所有 UCI 变量
     ├─ yml_change.sh        改运行 YAML（端口、模式、DNS、TUN、Sniffer、认证、Meta、GEO、Smart）
     ├─ yml_rules_change.sh  改运行 YAML（url-test 覆写、CDN 替换、规则注入、BT 直连）
     ├─ set_firewall()       iptables/nftables（透明代理、黑白名单、区域绕行、QUIC 阻断、UPNP 排除）
     └─ change_dnsmasq()     dnsmasq（DNS 劫持、自定义域名 DNS、chnroute 旁路）
```

`set_firewall()` 通过 UCI `firewall.openclash` 注册为 `/var/etc/openclash.include`，由 firewall3/4 加载，自动识别 fw4（nftables）与 fw3（iptables）。

#### 8.1.1 插件强制覆盖/禁用的设置（用户不可修改）

每次启动由 `yml_change.sh` **无条件硬编码**写入；可用覆写模块 `[YAML]` / `[Overwrite]` 段尝试覆盖，但插件不保证效果。

| 强制设置 | 值 | 说明 |
|----------|-----|------|
| `allow-lan` | `true` | 始终允许局域网使用代理端口 |
| `bind-address` | `*` | 始终监听所有接口 |
| `external-controller` | `0.0.0.0:<cn_port>` | API 监听所有接口（非仅 127.0.0.1） |
| `external-ui` | `/usr/share/openclash/ui` | Dashboard 路径不可改 |
| `dns.listen` | `0.0.0.0:<dns_port>` | DNS 监听所有接口 |
| `profile.store-selected` | `true` | 始终保存策略组选择 |
| `iptables` / `ebpf` / `auto-redir` | **删除** | 分别由插件防火墙接管 |
| `routing-mark` | `6666`（非自定义标记时） | 固定路由标记 |
| `external-controller-cors.allow-private-network` | `true`（有 CORS origin 时） | 允许私有网络访问 API |

**有条件默认值**（仅用户未配置时添加）：

| 设置 | 值 | 条件 |
|------|-----|------|
| `keep-alive-interval` / `keep-alive-idle` | `15` / `600` | 未设置时 |
| `ntp.enable` | `true` | 始终设置；server/port/interval/write-to-system 未设置时补 `time.apple.com` / `123` / `30`（分钟）/ `true` |
| `sniffer.sniff` | HTTP 80,8080-8880 / TLS 443,8443 / QUIC 443 | 端口不可改 |
| `sniffer.override-destination` | `false` | 用嗅探结果覆盖连接目标 |
| `sniffer.force-domain` | `+.netflix.com`、`+.nflxvideo.net`、`+.amazonaws.com`、`+.media.dssott.com` | 强制嗅探流媒体 |
| `sniffer.skip-domain` | `Mijia Cloud`、`dlg.io.mi.com`、`+.oray.com`、`+.sunlogin.net`、`+.push.apple.com` | 跳过智能家居/推送 |
| `sniffer.force-dns-mapping` | `true`（Redir-Host） | 强制 DNS 映射嗅探 |

**防火墙固定值**: `PROXY_FWMARK=0x162`（被代理流量标记）、`PROXY_ROUTE_TABLE=0x162`（策略路由表）、skgid `65534`（绕过代理的组 ID，直接写在 nft 规则里，无同名变量）。

**内核模块依赖**（缺失会启动报错）：

| 运行模式 | fw4 | fw3 |
|----------|-----|-----|
| Redir-Host / Fake-IP（非 TUN） | `kmod-nft-tproxy` | `kmod-ipt-tproxy` |
| TUN / 混合 | `kmod-tun` + `kmod-nft-tproxy` | `kmod-tun` + `kmod-ipt-tproxy` |

> 报 `nft_tproxy module not found` 装 `kmod-nft-tproxy`；报 `xt_TPROXY module not found` 装 `kmod-ipt-tproxy`；TUN 另需 `kmod-tun`。fw4 环境检查 `nft_tproxy` 而非 `xt_TPROXY`。

### 8.2 模式设置标签页 (op_mode)

| § | 项 (UCI key) | 默认 | 取值 | YAML | 说明 |
|---|---|---|---|---|---|
| 8.2.1 | 选择运行模式 `en_mode` | — | 见下表 | `dns.enhanced-mode` + `tun.enable` + `tun.stack` | 见下方模式表 |
| 8.2.2 | TUN 堆栈类型 `stack_type` | `mips` | `system` / `gvisor` / `mixed` / `mips` | `tun.stack` | 仅 TUN/混合显示；选型见 §8.2.12 |
| 8.2.3 | 代理模式 `proxy_mode` | `rule` | `rule` / `global` / `direct` | `mode` | 一键切全局/规则/直连 |
| 8.2.4 | UDP 流量转发 `enable_udp_proxy` | 1 | — | — | 仅非 TUN 显示；节点需支持 UDP。Fake-IP 下关闭后域名类 UDP 仍经内核 |
| 8.2.5 | 延迟启动 `delay_start` | 0 | 秒 | — | 开机后延迟再启动 |
| 8.2.6 | 日志大小 `log_size` | 1024 | KB | — | `/tmp/openclash.log` 上限 |
| 8.2.7 | 旁路网关兼容 `bypass_gateway_compatible` | 0 | — | — | 旁路由无法上网时尝试开启；无 WLAN 设备建议关闭 LAN 桥接 |
| 8.2.8 | 禁用 quic-go GSO `disable_quic_go_gso` | 0（Linux ≥6.6 固件由 uci-defaults 初始化为 1） | — | `experimental.quic-go-disable-gso` | **Hysteria / Hysteria2 / TUIC 连接超时、断流、握手失败优先开** |
| 8.2.9 | 小闪存模式 `small_flash_memory` | 0 | — | — | 内核与 GEOIP 移到 `/tmp/etc/openclash`，重启需重下 |
| 8.2.10 | 运行模式切换按钮 | — | — | — | 模板 `openclash/switch_mode`；`action_switch_mode` 改 UCI `operation_mode` |
| 8.2.16 | 禁用 TUN GSO `disable_tun_gso` | 0 | — | `tun.gso: false` | 仅 TUN 生效；个别固件内核 GSO 卸载有缺陷时开（速度骤降/连接异常），属性能取舍 |

**`en_mode` 六种取值**:

| 值 | 名称 | 说明 |
|----|------|------|
| `redir-host` | 兼容模式 | DNS 在客户端解析，按 IP 规则分流；适合 BT/PT |
| `redir-host-tun` | 兼容模式 TUN | 同上 + TUN 接管 |
| `redir-host-mix` | 兼容模式混合 | 同上 + TCP redirect / UDP TUN |
| `fake-ip` | Fake-IP | DNS 在核心解析返回 198.18.x.x，按域名匹配，**日常首选** |
| `fake-ip-tun` | Fake-IP TUN | 个别应用连不上（NAT 问题）时备选 |
| `fake-ip-mix` | Fake-IP 混合 | 需 `kmod-tun`；非直连游戏等对 NAT 类型有要求的场景 |

#### 8.2.11 运行模式实现

- `get_config()` 把 `en_mode` 解析为 `en_mode_tun` / `en_mode_fakeip` / `en_mode_mix`，并以位置参数传给 `yml_change.sh`：`$1` = enhanced-mode（`fake-ip`/`redir-host`）、`$11` = `en_mode_tun`、`$12`（或 `$30` 回退）= `stack_type`
- YAML：`dns.enhanced-mode` 按 Fake-IP/Redir-Host 写；`tun.enable` 在 `en_mode_tun != 0` 时为 `true`；`tun.stack` 取 `stack_type`
- 防火墙（`set_firewall()`）：非 TUN 时 TCP `REDIRECT` 到 `proxy_port`(7892)、UDP `TPROXY` 到 `tproxy_port`(7895)，标记 `0x162`（Fake-IP 另匹配 `fakeip_range` 路由）；TUN 时全部标记走策略路由进 `utun`；混合模式 UDP 由 TUN（gvisor）、TCP 走 REDIRECT（system）

#### 8.2.12 TUN 堆栈选型

| 栈 | 定义 | 结论 |
|----|------|------|
| `mips`（默认） | mihomo 自研纯 Go 用户态栈（mipstack） | **默认选它**：两种形态吞吐最高、短连接最快 |
| `system` | 内核协议栈 | 每字节 CPU 最低，但吞吐约为 `mips` 的一半 |
| `mixed` | TCP 走 system、UDP 走 gvisor | ≈ `system` |
| `gvisor` | 用户态 gVisor | **不建议**：除纯大流量上传外均不可靠（UDP 200 B 丢包约 55%） |

1. `gso` 保持开启（插件默认），全栈全形态正收益，是唯一有量级影响的数据面参数
2. 必须整机接管时才用 TUN：REDIRECT/TPROXY 的内核短路比 TUN 数据面便宜 1–2 个数量级（§8.2.13）
3. 并发 ≥40 连接时四栈同档回落到 32–57 MB/s（合批失效，§8.4.5）；连接数多时宜用 REDIRECT/TPROXY
4. 四种栈都能代理路由器自身流量：走插件默认的「标记 + 策略路由进 TUN」即可，无需其它开关

#### 8.2.13 转发模式（REDIRECT / TPROXY / TUN）

**现状**: 非 TUN 模式 TCP 用 `REDIRECT`（`redirect to $proxy_port`）、UDP 用 `TPROXY`（`mark set 0x162` + `tproxy ip to 127.0.0.1:$tproxy_port`），LAN 与路由器自身各一套链（`openclash_mangle*` / `openclash_output`）；TUN 模式流量进 `utun` 由所选栈处理。

1. **优先 REDIRECT/TPROXY**：批量吞吐与直连同级（内核 `splice` 零拷贝中继），每 256 MB 约 0.1 s core CPU（TUN 的 1/30–1/100）；短连接约为直连的 50%，仍高于 TUN
2. TPROXY-TCP 是「透明代理链路更干净」的功能取舍而非性能优化：REDIRECT 在 PREROUTING 把目标 DNAT 成本地地址，代理靠 `getsockopt(SO_ORIGINAL_DST)` 从 conntrack 反查原目标（查不到则静默断连）；TPROXY 不改写报文，目标来自报文本身（`listener/tproxy/tproxy.go` 读 `conn.LocalAddr()`）。两种方式都保留源 IP
3. 旁路由纯转发不是瓶颈：转发 + NAT 可达线路速率（`FLOWOFFLOAD` 开关无差异，且命中 mark/TPROXY 的报文本就不走 offload）；masquerade 可关但收益≈零
4. UDP 小包丢包由「每秒包数」决定，不随转发方式变化（`mips`/`system` 下 TPROXY 与 TUN 同档）

#### 8.2.14 默认值与 MIPS 来源

- mihomo 主配置 `tun:` 未写 `stack` 时默认 `mips`（`config/config.go` `DefaultRawConfig` → `Stack: C.TunMips`）；仅 `listeners:` 内联的 tun 项默认 `gvisor`（`listener/parse.go`），`TUNStack` 零值仍是 `gvisor`（`constant/tun.go`）
- OpenClash 默认 = `mips`（`settings.lua` 的 `stack_type` / `stack_type_v6`，`yml_change.sh` 取不到参数时同样回退 `mips`），且每次都显式写 `stack` 与 `gso: true` ⇒ 插件与内核默认一致
- 官方 wiki 的「建议 `mixed`，默认 `gvisor`」与内核/插件默认 `mips` 不一致，以本文档数据为准
- `mips` 基于 `github.com/metacubex/mipstack`（pure-Go、无需 cgo），先用于 ZeroTier/WireGuard 出站的 `ip-stack`，TUN 集成随 sing-tun v0.4.24 引入

#### 8.2.15 TUN 数据面参数（gso / mtu / congestion-controller / stack）

字段定义见 `listener/config/tun.go`，按是否影响吞吐分类：

| 类别 | 参数 | 说明 |
|------|------|------|
| 影响吞吐/CPU | `stack`、`gso`、`gso-max-size`、`mtu`、`congestion-controller`、`endpoint-independent-nat` | `congestion-controller` **仅 `mips` 生效**；`endpoint-independent-nat` 只改 UDP NAT 行为 |
| 只影响哪些流量进 TUN | `auto-route`、`auto-redirect`、`strict-route`、`route-address(-set)`、`route-exclude-address(-set)`、`include/exclude-interface`、`include/exclude-uid(-range)`、`include/exclude-mac-address`、`exclude-src/dst-port(-range)`、`iproute2-table-index`、`iproute2-rule-index`、`loopback-address` | 控制面，不改单连接开销 |
| 协议辅助/运维 | `dns-hijack`、`disable-icmp-forwarding`、`udp-timeout`/`icmp-timeout`、`file-descriptor`、`processors-per-channel`（gvisor 专用）、`recvmsgx`/`sendmsgx`（darwin 专用） | 测吞吐无意义 |

1. **`gso` 是唯一有量级影响的参数，插件默认开启**（`yml_change.sh` 重建 `tun` 段时写 `gso: true`）。全栈全形态正收益：下载/短连接明显提升、每 256 MB CPU 降 30–45%，上传 `gvisor` +637%、`mips` +45%（§8.4.2）。代价：仅 Linux 支持，GSO 超包在出口网卡按 MTU 分段；遇兼容问题用 §8.2.16 开关关闭。实现层（`sing-tun/tun_linux.go`）：关闭时不启用 `IFF_VNET_HDR`，开启时 `enableGSO()` 失败仅告警并退回普通模式（不阻断建 tun），UDP offload 失败仅关 UDP GRO——GSO 属设备层，与所选栈无关
2. **`mtu`、`gso-max-size`、`congestion-controller`、`processors-per-channel`、`endpoint-independent-nat` 无可测收益，保持默认**（§8.4.4）：`mtu: 9000` 不提速（改小反而 -6%），`gso-max-size` 默认 65536 已够；`congestion-controller` 各算法差异在 ±5%（保持 `cubic`，填非法值核心启动失败 `invalid TCP congestion control`）；`processors-per-channel` 对 gvisor 无改善
3. **栈选择见 §8.2.12**：默认 `mips` + `gso`；看重每字节 CPU 用 `system`；`gvisor` 仅纯大流量上传有优势
4. **满载延迟**：`mips` 约升 320–360%（~2 ms → ~8–12 ms/req）、`mixed` ~43 ms、`gvisor` ~105 ms 且伴随失败（§8.4.5）；低延迟优先走内核短路路径（REDIRECT/TPROXY）
5. **内核 sysctl 无需调优**：`rmem_max`/`wmem_max`/`tcp_rmem`/`tcp_wmem`（16 MB）、`tcp_congestion_control=bbr`、`default_qdisc=fq`、`netdev_max_backlog`/`netdev_budget`、`tcp_fastopen`/`tcp_max_syn_backlog`/`somaxconn` 全部一起改，差异仍 ≤5%（`bbr` 反而略差）——TUN/REDIRECT/TPROXY 三路径均已验证（§8.4.6）；UDP 缓冲默认值、`dev_weight`、TCP 连接周转参数同样无收益
6. `tun.gso` 与 `experimental.quic-go-disable-gso` 互不影响：前者作用于 tun 设备层；后者在核心启动前设环境变量 `QUIC_GO_DISABLE_GSO`（`hub/executor/executor.go`），作用于 QUIC 的 UDP socket。QUIC 报文也经 tun，故 `tun.gso` 对 UDP/QUIC 吞吐同样有正收益
7. **持续满载无衰减**：连续满载 10 分钟（单连接 2 GB 循环 + 4 连接循环）吞吐、CPU、RSS/fd 均平稳，无热降频

**覆盖默认值**: `tun` 段由 `yml_change.sh` 按模板重建（写 `enable`/`stack`/`device`/`dns-hijack`/`endpoint-independent-nat`/`auto-route`/`auto-detect-interface`/`auto-redirect`/`strict-route`/`disable-icmp-forwarding`/`gso`）。改其它参数用覆写模块 `[YAML]` 块（在 `yml_change.sh` 之后执行），保存后重启 OpenClash：

```yaml
tun:
  gso: false      # GSO 兼容性问题时关闭；插件默认开启（也可用 §8.2.16 开关）
```

### 8.3 流量控制标签页 (traffic_control)

> **生效路径**: 多数选项不改 YAML，而是影响 `set_firewall()` 生成的 iptables/nftables 规则链。
> **需要更细粒度绕过**: 按接口/用户/DSCP 用 `10-settings-geo-misc-src.md` §10.3；设备级黑白名单用 `09-settings-dns-ac-ipv6.md` §9.2。

| § | 项 (UCI key) | 默认 | 取值 / 文件 | 说明 |
|---|---|---|---|---|
| 8.3.1 | 路由本机代理 `router_self_proxy` | 1 | — | 路由器自身流量也走代理，仅规则模式生效；关闭后流媒体增强全部失效。控制 OUTPUT 链是否生成（非 TUN 的 Fake-IP 模式下即使关闭仍为 Fake-IP 流量建 OUTPUT 链） |
| 8.3.2 | 禁用 QUIC `disable_udp_quic` | 1 | — | 对 UDP 443 执行 REJECT 使 YouTube 等降级到 TCP；排除国内 IP 段（方向由 `china_ip_route` 决定）。**不影响内核自身 Hysteria/Hysteria2/TUIC 出站**（那些走 OUTPUT 链、回复目标为临时端口），它只针对 LAN 客户端的 QUIC |
| 8.3.3 | 绕过服务器地址 `skip_proxy_address` | 0 | — | 防代理嵌套：看门狗每 30 周期调 `skip_proxies_address()`，解析 `proxies`/`proxy-providers` 的 `server`（域名经 `/dns/query` 解析）后加入 `localnetwork` set，复用链首 `ip daddr @localnetwork counter return` |
| 8.3.4 | 仅允许常用端口 `common_ports` | 0 | 空格分隔端口/范围 | 仅常用端口走代理，防 BT/P2P 占线路；仅 Redir-Host 系列显示。预设含 21/22/23/53/80/123/143/194/443/465/587/853/993/995/998/2052/2053/2082/2083/2086/2095/2096/2197/5222/5223/5228-5230/8080/8443/8880/8888/8889；非 0 时插 `th dport != @common_ports counter return` |
| 8.3.5 | 绕过指定区域 IP `china_ip_route` | 0 | `0` 关 / `1` 绕过大陆 / `2` 绕过海外 | 强烈推荐绕过大陆：解析 IP 在国内段则不进内核，显著降开销。双重机制——YAML 侧按 §8.3.5.1 数据源改 `dns.fake-ip-filter`（让大陆域名返回真实 IP），防火墙侧建 `china_ip_route`/`china_ip6_route` set 匹配国内真实 IP 直连 |
| 8.3.6 | 仅允许内网 `intranet_allowed` | 1 | — | 控制面板与代理端口仅内网可访问。YAML 侧始终 `allow-lan: true` + `bind-address: "*"`（本项不控制 YAML）；防火墙侧始终建 `openclash_wan_input` 拒绝 `mark 0x162`，开启时追加拒绝 `ct status dnat` 与代理端口 dport 的入站 |
| 8.3.7 | WAN 接口名称 `intranet_allowed_wan_name` | — | 接口名 | 指定哪个接口算 WAN；依赖 §8.3.6 |
| 8.3.8 | LAN 接口名称 `lan_interface_name` | 0（自动检测） | 接口名 | 用于 `ip address show <接口>` 取路由器 LAN IP（面板地址、API、调试日志）；0=自动 |
| 8.3.9 | 本地 IPv4 网络绕过 `local_network_pass` | — | `openclash_custom_localnetwork_ipv4.list` | 目标为该列表 IP 的流量不进内核 |
| 8.3.10 | 绕过指定区域 IPv4 黑名单 `chnroute_pass` | — | `openclash_custom_chnroute_pass.list` | 列表内域名/IP 不受区域绕行影响，依赖 dnsmasq；要求 `enable_redirect_dns != 2` |
| 8.3.11 | UPNP 流量排除 | 自动 | — | 无 UCI 选项，见下 |

#### 8.3.5.1 china_ip_route_domain_source — 中国大陆域名数据源

| 项 | 说明 |
|---|---|
| UCI | `openclash.@openclash[0].china_ip_route_domain_source` |
| 取值 | `mrs`（默认，界面「MetaCubeX 规则 cn.mrs」）/ `geosite`（界面「GeoSite 规则 geosite:cn」） |
| 依赖 | 仅 Fake-IP 系列且 `china_ip_route`/`china_ip6_route` 启用时显示 |

- `mrs`：用 `MetaCubeX/meta-rules-dat` 的独立 `cn.mrs`，blacklist 模式追加 `rule-set:oc-cn-domain`，rule 模式追加 `RULE-SET,oc-cn-domain,real-ip`，并自动注册 `rule-providers.oc-cn-domain`
- `geosite`：用当前 `/etc/openclash/GeoSite.dat` 的 `cn` 分类，追加 `geosite:cn` 或 `GEOSITE,cn,real-ip`；不注册 rule-provider，跟随用户的 GeoSite 数据源与更新周期
- `whitelist` 模式下两种来源都不自动追加 CN 过滤器
- 关闭区域绕行后保存会保留数据源选择，重新开启继续使用
- **资源差异**：实测 `geosite:cn` 比 MRS 约多占 20 MiB 内存；MRS 本地文件缺失且下载失败时内核仍能启动（相关域名可能返 Fake-IP），GeoSite 无法加载或缺 `cn` 分类时配置校验与启动会失败

#### 8.3.10 补充：chnroute_pass 的 Fake-IP 处理与局限

- 区域绕行开启 + `en_mode=fake-ip` + `enable_redirect_dns != 2` 时，列表内域名会写入 `dns.fake-ip-filter`（blacklist 写 `+.域名`、rule 写 `DOMAIN-SUFFIX,域名,real-ip`、whitelist 则从现有 filter 中删除相关条目），不再依赖 `custom_fakeip_filter` 开关
- **仅靠 `chnroute_pass` 不足以解决 Google Play 下载问题**：它只把解析 IP 加入 `china_ip_route_pass` set 跳过绕行；若上游 DNS 把该域名解析到国内 IP，仍会被绕行规则命中。必须同时处理 DNS（`nameserver-policy` 强制走境外 DNS，见内置覆写模块 `Google_Play`）与规则匹配（自定义规则走代理），详见 `03-errors.md` §3.14

#### 8.3.11 UPNP 流量排除（自动生效）

- **触发**: 系统已装并运行 `upnpd`（`/etc/config/upnpd` 存在且 `upnp_lease_file` 指向有效租约文件）
- **作用**: 为 UPnP 端口映射建绕过规则，防止 BT/PT、游戏主机的 UDP 流量被 TPROXY 错误代理
- **实现**: `set_firewall()` 建 `openclash_upnp` 链并在 `openclash_mangle` 中 `jump openclash_upnp`（位于最终 TPROXY 之前）；`upnp_exclude()` 解析租约（`UDP:<ext_port>:<int_ip>:<int_port>`）后为每条加 `ip saddr <int_ip> <proto> sport <int_port> counter return`
- **同步**: 看门狗每 30 周期（首周期立即，之后约 30 分钟）清理过期规则并补充新增映射

### 8.4 性能实测数据

#### 8.4.1 测量条件

- **两种形态**：路由器自身（本机客户端 ↔ 本机源站，fake-ip 解析 → 输出标记 → 策略路由进 TUN 闭环）与 LAN 转发（veth 命名空间客户端 ↔ 源站）；并发档位另以 LAN 侧真实 PC 客户端验证（§8.4.5）。§8.4.3 的路径/UDP 对比在设备内部完成（不经物理链路）
- **场景**：批量 TCP 256 MB（下载单连接测 2 次、4 连接测 1 次；上传 `iperf3 -P4 -t 6`）；短连接 3000 次 × 32 KB（20 并发）；UDP 200 B @20 kpps、1400 B @7.5 kpps 各 5 s
- **CPU**: 核心进程 utime+stime（s/256MB）；`tun` 段与插件生成的标准配置一致
- 单位：吞吐 MB/s、短连接 rps、丢包 %；`gso` 对比为「关 → 开」并标注幅度

#### 8.4.2 TUN 四栈 × `gso`（主表）

> 单元格为 `gso` 关 → 开；括号为开启后变化幅度（单连接为两次测量区间）。

**路由器自身流量**

| 场景 | `system` | `mixed` | `mips` | `gvisor` |
|------|----------|---------|--------|----------|
| 下载×单连接（MB/s） | 69 → 109（+58%） | 68 → 111（+63%） | 98–104 → 164–168（+64%） | 28 → 28（持平） |
| 下载×单连接 CPU（s/256MB） | 4.3 → 2.6（-40%） | 4.4 → 2.6（-41%） | 5.2 → 3.0（-42%） | 12.6 → 12.9（+2%） |
| 下载×4 连接（MB/s） | 63 → 99（+57%） | 62 → 90（+45%） | 77 → 115（+49%） | 54 → 53（-2%） |
| 上传×4 连接（MB/s） | 78 → 108（+38%） | 64 → 112（+75%） | 128 → 185（+45%） | 35 → 258（+637%） |
| 短连接（rps） | 729 → 716（-2%） | 715 → 758（+6%） | 1051 → 1277（+22%） | 647 → 62（-90%）\* |
| UDP 200 B 丢包（%） | 0.4 → 0.5 | 0.1 → 0.0 | 0.6 → 0.4 | 54 → 54（持平） |

**LAN 转发流量**

| 场景 | `system` | `mixed` | `mips` | `gvisor` |
|------|----------|---------|--------|----------|
| 下载×单连接（MB/s） | 44–47 → 66–68（+47%） | 46–47 → 67–69（+46%） | 66–72 → 147–148（+112%） | 22 → 22（持平） |
| 下载×单连接 CPU（s/256MB） | 5.1 → 3.5（-31%） | 5.1 → 3.6（-29%） | 6.2 → 3.5（-44%） | 15.3 → 14.5（-5%） |
| 下载×4 连接（MB/s） | 43 → 60（+40%） | 45 → 61（+36%） | 57 → 98（+72%） | 50 → 49（-2%） |
| 上传×4 连接（MB/s） | 71 → 102（+44%） | 64 → 98（+53%） | 106 → 185（+75%） | 34 → 253（+644%） |
| 短连接（rps） | 656 → 635（-3%） | 647 → 597（-8%） | 872 → 1162（+33%） | 93 → 401（+331%）\* |
| UDP 200 B 丢包（%） | 0.3 → 0.1 | 0.3 → 0.3 | 1.6 → 1.5 | 55 → 52 |

> \* `gvisor` 短连接双峰波动（劣化档 30–90 rps 大量失败 / 正常档 150–650 rps 仍偶有失败），与 `gso`、客户端形态、平台无关，表中 62/93/401 均落在此区间。其余数据波动在 ±10% 内。UDP 1400 B @7.5 kpps：各栈 ≤0.9%（`gvisor` 0.8%）。

#### 8.4.3 转发路径对比

> 设备内部测试环境（客户端与源站均在设备内、经虚拟网卡，不经物理链路），`gso` 开启。真实 PC 客户端另有链路上限（1GbE ≈ 110 MB/s）。

| 路径 | 批量 TCP（单/4 连接） | 短连接（3000 × 32 KB，20 并发） | 每 256 MB core CPU |
|------|----------------------|--------------------------------|--------------------|
| 直连（基线） | 0.96–1.15 / 1.64 GB/s | 5114 rps | 0 |
| LAN → REDIRECT（TCP） | 0.97–1.13 / 1.55–1.63 GB/s | 2368–2636 rps | ~0.05–0.11 s |
| LAN → TPROXY（TCP） | 0.86–1.10 / 1.55–1.63 GB/s | 2428–2556 rps | ~0.04–0.20 s |
| LAN → TUN（四栈） | 单连接 22–148 MB/s；4 连接 49–98 MB/s（§8.4.2） | 635–1162 rps（gvisor 波动） | 2.6–14.5 s |

> REDIRECT/TPROXY 批量吞吐与直连同级（内核 `splice` 零拷贝），短连接约为直连 50%（每条多约 0.2 ms 建连开销）；TUN 逐包过用户态栈，吞吐低一个数量级、CPU 高 1–2 个数量级。REDIRECT 与 TPROXY（TCP）彼此持平，日常保持插件现状（TCP=REDIRECT、UDP=TPROXY）即可。

**高负载 UDP**（非 TUN 下 UDP 固定走 TPROXY，REDIRECT 只承载 TCP）：

| 场景 | TPROXY | TUN `mips` | TUN `system` | TUN `gvisor` |
|------|--------|-----------|--------------|--------------|
| UDP 200 B @20 kpps 丢包 | 0.3% | 0.5% | 0.2% | 54% |
| UDP 200 B @40 kpps 丢包 | 13.2% | 13.2% | 10.9% | 55% |
| UDP 1400 B @7.5 kpps 丢包 | 0.0% | 0.0% | 0.0% | 0.0% |
| QUIC（40 流 × 200 B × 500 pps）丢包 | 0.1% | 0.0% | 0.0% | 55% |
| flood 1400 B（尽力约 80 kpps）丢包 / 交付 | ~62% / ~43 MB/s | ~62% / ~44 MB/s | ~60% / ~45 MB/s | ~91% / ~11 MB/s |

> `mips`/`system` 上 TPROXY 与 TUN 的 UDP 丢包同级（小包丢包由包速率决定）；`gvisor` 任何路径都不可用。旁路由纯转发（不经代理）97–106 MB/s（≈线路速率），CPU 可忽略，`FLOWOFFLOAD` 无差异。

#### 8.4.4 TUN 数据面参数（单连接 256 MB，`mips` + `gso`）

| 参数 | 自身×下载 | LAN×下载 |
|------|-----------|----------|
| 默认（`mtu` 1500 / `gso-max-size` 默认 / `cubic`） | 165 / 166 | 161 |
| `mtu: 9000` | 161 / 165 | 159 |
| `mtu: 1280` | 155 / 157 | 151 |
| `gso-max-size: 16384` | 161 / 170 | 155 |
| `congestion-controller: bbr` | 156 / 165 | 159 |
| `endpoint-independent-nat: false` | 162 / 166 | 156 |

> 除 `mtu: 1280` 低约 6% 外差异均在 ±5% 波动内 ⇒ **全部保持默认**（见 §8.2.15）。

#### 8.4.5 持续满载、高并发与延迟

四栈对照（`gso` 开启，路由器自身形态）：

| 场景 | `mips` | `system` | `mixed` | `gvisor` |
|------|--------|----------|---------|----------|
| 满载 10 分钟：单连接 2 GB 循环（MB/s） | ~165–167 | — | 108–113 | 28.3–28.8 |
| 满载 10 分钟：4 连接 2 GB 循环（MB/s） | ~116–120 | — | 95–100 | 54.1–55.0 |
| 40 连接并发（512 MB，MB/s） | ~38–41 | ~46–49 | 46.6 | 56.5 |
| 100 连接并发（512 MB，MB/s） | ~32 | ~35–42 | 40.8 | 48.5 |
| 短连接（20 并发 32 KB）+ 后台 2 连接批量 | 526–714 rps / 83–109 MB/s | — | 183 rps / 60 MB/s | 60 rps / 33 MB/s |
| 延迟（32 KB ×200）：空载 → 满载 | ~2 ms → ~8–12 ms | — | ~2.1 ms → ~43 ms | ~3.3 ms → ~105 ms（含失败） |

> 四栈连续满载 10 分钟均无衰减、无热降频。并发 ≥40 时各栈同档回落（40–57 MB/s）；`gvisor` 的并发吞吐靠极低单连接吞吐（~1.4 MB/s）叠加，满载延迟与失败率最差（200 次失败 4 次）。

**吞吐随并发下降的原因**（`mips` + `gso`，512 MB 批量）：

| 并发连接数 | 2 | 4 | 8 | 16 | 40 | 100 |
|----------|---|---|---|----|----|-----|
| 吞吐（MB/s） | 143 | 119 | 102 | 81 | 50 | 40 |
| 核心写 tun 平均合批大小 | 24.3 KB | 13.1 KB | 7.8 KB | 4.2 KB | 2.1 KB | 1.7 KB |
| 每 256 MB CPU（s） | 3.9 | 4.7 | 5.4 | 7.1 | 11.6 | 14.1 |

- 吞吐随连接数**平滑**下降，40 连接连续 2 GB 全程稳定；核心向 tun 写出的包速率封顶约 **2.5 万包/秒**，吞吐 ≈ 包速率 × 合批尺寸，而合批尺寸近似 ∝ 1/连接数
- 每包/每批都经用户态处理，读写循环各一条且单线程 ⇒ 并发升高后合批失效，每字节 CPU 升至约 3 倍并伴随重传（最多 1.4 万段）；`system` 趋势相同（107 → 42 MB/s）
- 合批失效原因：sing-tun 单次写最多向栈取 64 包且 GRO 只在该批内合并（`sing-tun/stack_mipstack.go`、`tun_offload_linux.go`），栈输出为全局单队列（256 槽，`mipstack/stack.go`）⇒ 批内同连接连续包 ≈ 64/并发数
- **真实 PC 客户端验证**：40/100 连接 = 59 / 52 MB/s（`mips`）、`system` 40 连接 53 MB/s，合批 2.2–2.5 KB、包速率 ~2.5 万/秒；不经代理直连同路径 106 / 94 MB/s ⇒ 下降属 TUN 数据面特有，与客户端/链路无关

#### 8.4.6 内核 sysctl 调优

`rmem_max`/`wmem_max`/`tcp_rmem`/`tcp_wmem` 调至 16 MB、`tcp_congestion_control=bbr`、`default_qdisc=fq`、`netdev_max_backlog=5000`、`netdev_budget=600`、`tcp_fastopen=3`、`tcp_max_syn_backlog=8192`、`somaxconn=8192`（`mips` + `gso`）：

| 状态 | 自身×下载单连接 | 短连接 rps | LAN×下载单连接 |
|------|----------------|-----------|----------------|
| 默认 | 159 / 159 | 1288 | 141 |
| 全部调优 | 154 / 154 | 1286 | 143 |
| 调优后还原 | 159 / 158 | 1245 | 147 |

同样参数在 REDIRECT / TPROXY 路径（单连接 MB/s、短连接 rps）也无影响：

| 状态 | REDIRECT 单连接 | REDIRECT 短连接 | TPROXY 单连接 | TPROXY 短连接 |
|------|----------------|----------------|---------------|---------------|
| 默认 | 974 / 1033 | 2368 rps | 1096 / 860 | 2556 rps |
| 全部调优 | 970 / 1078 | 2509 rps | 921 / 804 | 2428 rps |
| 调优后还原 | 1052 / 1129 | 2504 rps | 958 / 1005 | 2443 rps |

TPROXY 的 UDP 场景（200 B @20/40 kpps、1400 B @7.5 kpps、QUIC-40、flood）受影响也在 3 个百分点内。

其余参数组单独调整同样无收益：UDP 缓冲默认值（`rmem_default`/`wmem_default` → 1 MB、`udp_rmem_min`/`udp_wmem_min` → 64 KB）、`dev_weight` → 512、TCP 连接周转与发送参数（`tcp_max_tw_buckets`、`tcp_max_orphans`、`tcp_fin_timeout`、`ip_local_port_range`、`tcp_syncookies`、`tcp_no_metrics_save`、`tcp_slow_start_after_idle`、`tcp_autocorking`、`optmem_max`）。

> 结论：**无需调优，保持系统默认**（`bbr` 反而略差）。瓶颈在核心的用户态读写循环与逐包处理（§8.4.5），与内核缓冲、软中断批处理权重、连接生命周期参数无关。`bbr` 模块本身可用（`reno cubic bbr`），`tcp_tw_reuse` 内核默认即为 2。
