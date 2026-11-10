## 功能行为：ICMP、高级流量控制、Tailscale 与特殊场景

> **用途**: ICMP 处理、高级流量控制、Tailscale/overlay 联动、mwan3 多 WAN 与 Docker 网桥（§5.1–5.5）。链结构与顺序见 `04-firewall-chains.md`。

### 5.1 ICMP / Ping 处理

| 运行模式 | ICMP 进 TUN | fwmark | 实际处理 |
|----------|-------------|--------|----------|
| Redir-Host（非 TUN） | ❌ | ✅ `0x162` | 仅标记后 `accept`，走系统原始路由，**不被代理** |
| Fake-IP（非 TUN） | ❌ | ✅ `0x162` | 额外 REJECT 发往 Fake-IP 段（`198.18.0.0/16`）的 ping |
| Redir-Host TUN | ✅ | ✅ `0x162` | 真实 IP → DIRECT 直连延迟 |
| Fake-IP TUN | ✅ | ✅ `0x162` | 真实 IP → DIRECT；Fake-IP → 内核伪造回复（~0ms） |
| Redir-Host Mix | ✅ | ✅ `0x162` | 同 Redir-Host TUN |
| Fake-IP Mix | ✅ | ✅ `0x162` | 同 Fake-IP TUN |

- **非 TUN**：ICMP echo-request 在 `openclash_mangle` 只打 fwmark 后 `accept`（`mark set 0x162 counter accept comment "OpenClash ICMP Mark"`）；标记只影响策略路由（如旁路由回流），不改变是否代理。此前的 localnetwork / WAN-AC / LAN-AC / `china_ip_route` 等 RETURN 规则同样作用于 ICMP；`router_self_proxy=1` 时路由器自身 ping 在 `openclash_mangle_output` 也被标记
- **TUN**：打标记后经策略路由（`ip rule add fwmark 0x162 table 0x162` + `ip route add default dev utun table 0x162`）进 `utun` 由内核处理；相关配置 `icmp-timeout`（默认 10 s，`sing.go` 常量）与 `disable-icmp-forwarding`（默认 false，设 true 则全部伪造回复）
- **Fake-IP 非 TUN 的 REJECT**：三链各 `insert position 0` 一条 `icmp type echo-request ip daddr { 198.18.0.0/16 } counter reject`（`input` / `forward` / `output`，其中 `output` 加 `skgid != 65534` 排除 OpenClash 自身）。原因是非 TUN 下 Fake-IP 只有 TCP/UDP 重定向路径，ping 这些地址无意义且干扰诊断
- **Fake-IP TUN 不加 REJECT**：ICMP 进 TUN 后由内核 `skipPingForwardingByAddr()` 判为 Fake-IP，返回伪造 echo-reply
- **ICMPv6**：仅 IPv6 TUN/混合（`ipv6_mode=2/3`）标记（`ip6 nexthdr icmpv6 icmpv6 type echo-request mark set 0x162 counter accept`）；非 TUN 不标记也不代理；IPv6 Fake-IP 段的 ping 在 `ipv6_mode -ne 2 -a -ne 3` 时被 REJECT（`icmpv6 admin-prohibited`），TUN/Mix 同样伪造回复

**内核侧处理优先级**（`listener/sing_tun/prepare.go`）：

| 顺序 | 条件 | 处理 |
|---|---|---|
| 1 | 目标是 Fake-IP（`resolver.IsFakeIP`） | 返回 `nil, nil` → 伪造 echo-reply（虚假 ~0ms） |
| 2 | 目标是 TUN 接口自身 IP（`inet4/6_address`） | 同上伪造回复 |
| 3 | `disable-icmp-forwarding: true` | 全部伪造回复 |
| 4 | 真实 IP 且未禁用转发 | `ping.ConnectDestination()` 以 **DIRECT** 发真实 ICMP，延迟为真实 RTT |
| 5 | 超时 | 默认 10 s，可用 `icmp-timeout` 改 |

> 要点：TUN 下 ping 分两种——Fake-IP 得虚假 0ms、真实 IP 走 DIRECT 直连延迟；**ping 始终不经代理节点**（与 TCP/UDP 不同）。用户「ping 不通但网页正常」时，先确认是不是在 Fake-IP 非 TUN 下 ping 被代理的域名。

### 5.2 高级流量控制 (`firewall_lan_ac_traffic`)

> **配置路径**: 插件设置 → 黑白名单 → 高级流量控制
> **生效**: 每个 UCI section 由 `config_foreach firewall_lan_ac_traffic` 遍历，插到已有链 **position 0**，优先级高于所有其它 bypass/redirect 规则。

| 字段 | 类型 | 可选值 | 说明 |
|------|------|--------|------|
| `enabled` | bool | `0`/`1` | 是否启用 |
| `src_ip` | string | IP/CIDR 或 `localnetwork` | 源地址（`localnetwork` = 匹配所有本地网络设备） |
| `src_port` | string | 端口或范围 | 源端口 |
| `proto` | string | `tcp`/`udp`/`both` | 协议 |
| `target` | string | `return`/`accept`/`drop` | `return`=跳过代理（默认）/ `accept`=放行 / `drop`=丢弃 |
| `dscp` | string | 如 `46` | DSCP 匹配（fw3 需 DSCP 模块，fw4 无需） |
| `family` | string | `ipv4`/`ipv6`/`both` | 地址族 |
| `interface` | string | 如 `br-lan` | 入接口 |
| `user` | string | UID | 按用户匹配，仅 OUTPUT 链 |
| `comment` | string | — | 规则注释 |

**插入位置（fw4）**:

| 流量方向 | IPv4 TCP | IPv4 UDP | IPv6 TCP | IPv6 UDP |
|----------|----------|----------|----------|----------|
| 入站（LAN→路由器） | `openclash`（非TUN）/ `openclash_mangle`（TUN） | `openclash_mangle` | `openclash_v6` / `openclash_mangle_v6` | `openclash_mangle_v6` |
| 出站（路由器自身） | `openclash_output` / `openclash_mangle_output` | `openclash_mangle_output` | `openclash_output_v6` / `openclash_mangle_output_v6` | `openclash_mangle_output_v6` |
| 旁路由 SNAT | `openclash_post` | `openclash_post` | `openclash_post_v6` | `openclash_post_v6` |

**规则形态**（fw4）：

```bash
nft insert rule inet fw4 openclash position 0 tcp \
  sport 0-65535 meta nfproto {ipv4} ip daddr != {<fakeip_range>} \
  ip saddr {192.168.1.100} counter return comment "my_device_bypass"
```

- 所有规则自动加 `ip daddr != {<fakeip_range>}`，Fake-IP 流量不受影响
- `target=drop`：nat 链（`openclash`/`openclash_output`/`openclash_post`）实际为 `return`；mangle 链为真 `drop`
- `user` 仅对 OUTPUT 链生效；`iptables_compat`（无 owner match）时整条跳过并告警
- fw3 DSCP 需 `iptables-mod-extra`，不可用时告警并跳过

### 5.3 Tailscale（MagicDNS / `ts.net` / accept-dns）

> 关联：`04-firewall-chains.md` §4.2.1、`06-firewall-options-dnsmasq.md` §6.2、`16-overwrite-module-format.md` §16。
> 「stub」= Tailscale DNS：v4 `100.100.100.100:53`、v6 `fd7a:115c:a1e0::53`。

#### 5.3.1 地址与行为

| 项 | 值 |
|---|---|
| MagicDNS | `<host>.ts.net`，由 tailscaled 的 tsdns 权威应答 |
| `accept-dns=on` | tailscaled 覆写 `/etc/resolv.conf`：`nameserver 100.100.100.100`、`nameserver fd7a:115c:a1e0::53`、`search <tailnet>.ts.net lan` |
| tailscaled 身份 | root（uid/gid 0），不享受 mihomo 的 `skgid 65534` 豁免 |
| `tailscale0` 区域 | tailscale 包默认加入 **lan** 区（`firewall.@zone[0].network='lan tailscale LAN6'`） |
| 出口节点 | 需 advertise `0.0.0.0/0`、`::/0` |

两种「100.100.100.100」要分清：`resolv.conf` 的 `nameserver` 是 tailscaled 管理的系统解析器；dnsmasq 的 `server=/ts.net/100.100.100.100` 是转发规则（GL.iNet 固件自动写入）。

#### 5.3.2 本机 DNS 规则

生效条件：`router_self_proxy=1` 且 `enable_redirect_dns=1|2`；实现 `add_router_dns_hijack_nft()` / `add_router_dns_hijack_iptables()`。

| 注释 | 匹配 | 动作 / 作用 |
|---|---|---|
| `OpenClash Router DNS Hijack` | 目标 `fib daddr type local`，:53 | REDIRECT → `DNSPORT`(mode1) / `dns_port`(mode2) |
| 同上 | 目标 `100.64.0.0/10`（v6 `fd7a:115c:a1e0::/48`），:53 | 同上 |
| 同上（mihomo 豁免） | `meta skgid != 65534`；fw3 `! --gid-owner 65534`；`iptables_compat` 用 `! --mark 0x1a0a` | 防 core 自环 |
| 同上，mode 1 加 dnsmasq 豁免（local 与私网两条都加） | `meta skuid != <dnsmasq uid>`；fw3 `-m owner ! --uid-owner <uid>`（uid 0 不豁免） | 防 dnsmasq 转发查询被劫持回自己 |
| `OpenClash Tailscale Stub Accept` | `-i lo -s <stub> -p udp/tcp --sport 53`，插在 `input` 首 | 放行 stub 反向 NAT 回包 |

- 每次启动先删自身旧规则再插入，`revert_firewall()` 按注释清理，restart 幂等（每族 udp+tcp 各 2 条）
- INPUT 放行的原因：`ts-input` 含 `! -i tailscale0 -s 100.64.0.0/10 -j DROP` 会丢掉回包 → v4 冷解析卡 5 s（v6 无此 DROP）
- uid 豁免失效场景：`iptables_compat`（无 owner match）、dnsmasq 以 root 运行 ⇒ mode 1 自环仍在，改用 mode 2

```bash
# nft (fw4)；v6 换成 ip6 / fd7a:115c:a1e0::53
nft insert rule inet fw4 input position 0 iifname "lo" \
  ip saddr 100.100.100.100 udp sport 53 counter accept comment "OpenClash Tailscale Stub Accept"
nft insert rule inet fw4 input position 0 iifname "lo" \
  ip saddr 100.100.100.100 tcp sport 53 counter accept comment "OpenClash Tailscale Stub Accept"

# iptables (fw3)；先循环 -D 删除旧规则，再 -I INPUT 1
iptables -t filter -I INPUT 1 -i lo -s 100.100.100.100 -p udp --sport 53 \
  -j ACCEPT -m comment --comment "OpenClash Tailscale Stub Accept"
```

#### 5.3.3 `ts.net` 解析路径与内置覆写模块

| 场景 | core 收到 `ts.net` 查询 | 需要的配置 |
|---|---|---|
| mode 1 + dnsmasq `server=/ts.net/<stub>` + uid 豁免生效 | 否 | 无 |
| mode 2 | 是 | 启用内置 `Tailscale` 覆写模块 |
| mode 1 但 dnsmasq 无 `server=/ts.net/...` | 是 | 同上 |
| 客户端直接查 core DNS（DoH、面板、curl） | 是 | 同上 |

- 模块：`root/etc/openclash/overwrite/Tailscale`（`config_overwrite` 中 `name Tailscale`、`enable 0`、`order 3`），内容 `dns.nameserver-policy+` → `'+.ts.net': ['100.100.100.100#DIRECT']`
- `#DIRECT`：`respect-rules: true` 时避免 core→stub 的查询被代理规则接管
- 答案类型：模块路径返回 fake-ip；uid 豁免路径返回真实 `100.x`。要统一为真实 IP 就给 core 加 `fake-ip-filter: ['ts.net']`

#### 5.3.4 localnetwork / localnetwork6

- 默认 `localnetwork` 含 `100.64.0.0/10`、`localnetwork6` 含 `fd7a:115c:a1e0::/48`，只作**目的地址**豁免（`ip daddr @localnetwork return`），不按源地址豁免；tailnet 客户端访问公网仍走代理
- `lan_ac_*` 是独立集合，默认不含 tailnet 网段；把 `100.64.0.0/10` 加入黑名单可让 tailnet 客户端跳过代理

#### 5.3.5 外部设备用本机代理 / 出口节点

**代理端口**（`http_port` 7890、`socks_port` 7891、`mixed_port` 7893）：

1. 开 `allow-lan` + `bind-address: "*"`（否则只监听 `127.0.0.1`）
2. 客户端填 `http://<tailnet ip>:7890` 或 `socks5h://<tailnet ip>:7891`，并配 `authentication`（无认证：HTTP `407`、SOCKS5 拒绝用户）
3. 防火墙无需改动：`tailscale0` 在 lan 区按 LAN INPUT 放行，`intranet_allowed` 只限 WAN 区
4. 实测（oc125 `100.113.118.42` → oc140 `100.120.79.48`）：带认证三端口均 `204`、无认证被拒、出口 IP ≠ 直连、面板显示 `chains: Speedtest → Proxy → Smart → 节点`

**出口节点**：

1. 本机 advertise `0.0.0.0/0`、`::/0`；客户端 `tailscale up --exit-node=<本机 tailnet IP> --exit-node-allow-lan-access`
2. 依赖 `ip_forward=1`、`ts-forward`（tailscale0 打标 `0x40000` 并 ACCEPT）、`ts-postrouting`（MASQUERADE）；OpenClash 的 PREROUTING 对所有非 WAN 接口生效
3. `lan_ac_mode=1` 白名单会跳过 tailnet 源；`bypass_gateway_compatible=1` 的 SNAT 排除 mark `0x162`
4. 验证：`tailscale status` 显示 `offers exit node`、客户端 `curl ifconfig.me` 为路由器出口 IP、面板见到源 `100.x` 的连接

#### 5.3.6 与其他 overlay（ZeroTier / EasyTier 等）

- 本机规则只匹配两类目标：路由器自身地址 :53 与 `100.64.0.0/10`（v6 `fd7a:115c:a1e0::/48`）。ZeroTier 等把 DNS 指向路由器自身地址（zt 接口 IP、LAN IP）时，mode 1 下已被 dnsmasq uid 豁免覆盖；指向私网其他主机时规则不匹配
- 只有**自己往 INPUT/FORWARD 塞 DROP** 的软件需要补规则（已知 Tailscale `ts-input`）；ZeroTier 不加此类规则。需要时补 `-i lo -s <该 DNS IP> -p udp/tcp --sport 53 -j ACCEPT`（注释含 `OpenClash`，停止时由 `revert_firewall` 清理），v4/v6 分开
- 内核内置出站都是用户态：`tailscale` / `easytier` 有进程内 DNS（`ts://<出站名>`、`et://<出站名>`），`zerotier` 无内置 DNS；三者都不建网络接口、不发主机 DNS socket，不受本节影响
- 既有约束：`localnetwork` 含 `100.64/10` 且按目的地址豁免 ⇒ redir-host 下 LAN 客户端访问真实 `100.x` 不进 core；ZeroTier 网段落在 `localnetwork`（如 `10/8`）同理

#### 5.3.7 安全要点

- INPUT 放行范围最小：`lo` + 精确 stub 源 + `sport 53`；`route_localnet=0` 时外部无法伪造该源
- uid 豁免只影响 dnsmasq 自身出站私网 DNS，uid 0 不豁免
- 代理端口暴露源于 `allow-lan` + lan 区含 `tailscale0`（既有行为）：保持 `authentication`，用 Tailscale ACL 限制来源
- 出口节点会扩大信任边界，用 ACL 限制成员

#### 5.3.8 排查

| 现象 | 检查 |
|---|---|
| v4 冷解析 5s / stub 超时 | `iptables -S INPUT \| grep 'Tailscale Stub Accept'` 是否在 `-j ts-input` 之前 |
| `ts.net` NXDOMAIN | 模块是否 enable；mode 1 下 dnsmasq 是否有 `server=/ts.net/...`；`grep -A2 ts.net /etc/openclash/config.yaml` |
| dnsmasq 并发堆积 / `ts.net` 卡死 | 私网规则是否带 uid 豁免；是否 `iptables_compat` |
| 代理 `407` / SOCKS 拒绝 | 客户端未填 `authentication` |
| tailnet 客户端连不上代理端口 | `tailscale0` 是否在 lan 区、INPUT 规则、Tailscale ACL |
| 出口节点不生效 | `ip_forward`、`ts-forward`/`ts-postrouting`、`lan_ac_mode`、连接面板来源 |

#### 5.3.9 相关文件

`root/etc/init.d/openclash`（`add_router_dns_hijack_nft()` / `add_router_dns_hijack_iptables()`）、`root/etc/openclash/overwrite/Tailscale`、`root/etc/config/openclash`（`config_overwrite` 的 Tailscale 条目）。
相关选项：`router_self_proxy`、`enable_redirect_dns`、`intranet_allowed`、`bypass_gateway_compatible`、`lan_ac_mode`、`enable_custom_domain_dns_server`。

### 5.4 与 mwan3 共存（多 WAN 分流）

> 关联：`04-firewall-chains.md` §4.3。代理标记规则的 `pref` 由 init.d 固定为 **999**（fake-ip6 的 `iif lo` 为 998），不要改回默认值或 1888。

| 模式 | mihomo 出站能否被 mwan3 分流 |
|---|---|
| `fake-ip` / `redir-host` × 非 TUN / TUN / Mix | 能（出站是 OUTPUT，走 mwan3 的 `mangle OUTPUT → mwan3_hook`） |
| IPv6（`ipv6_mode` 0/1/2/3） | 能（需在 mwan3 配置 v6 接口/成员） |
| `iptables_compat`（fw3 且无 `xt_owner`） | **不能**：mihomo 被写 `routing-mark: 6666`，`0x1a0a & 0x3f00 ≠ 0` → mwan3 跳过分类且无匹配 `ip rule`，走 main 表 |

**mwan3 侧设置**:

1. 至少两个接口，各有独立网关（`config interface` + `option interface <netifd 接口名>`）并开启 tracking（`track_ip`）
2. 每个 WAN 一个 `config member`；`weight` 决定比例（模板 `wan_m1_w3` 权重 3，新增 weight 1 即 3:1）
3. `config policy` 引用这些 member，`config rule` 的 `dest_ip 0.0.0.0/0` 指向该 policy（默认已有 `default_rule_v4`）
4. 要真正均衡，rule 的 `sticky` 必须为 `0`：`sticky 1` 按源 IP 粘滞，而 mihomo 出站源是路由器本身 → 全部固定在一个 WAN
5. 不要把代理节点 IP 放进 mwan3 的 connected / custom 集合，否则被判直连走 main 表

**生效范围**: 分流只发生在 mihomo 出站层——客户端→OpenClash 的流在本地终结，mwan3 按客户端源 IP/入接口的策略对它无效（要按客户端分流用 OpenClash 策略组）；被 `return` 不进内核的转发流量仍由 mwan3 正常分流。

**故障对照**:

| 现象 | 原因 |
|---|---|
| 开 mwan3 后 UDP/QUIC 不通、TCP/DNS 正常；`openclash_mangle` 的 tproxy 计数在涨但 mihomo 无 `[UDP]` 日志 | mwan3 的 `fwmark 0x100/0x3f00 lookup N`（`pref 2001+`）命中 OpenClash 的 `0x162`（`0x162 & 0x3f00 = 0x100`）；不写 `pref` 时本规则落在 32765，被抢走 |
| mwan3 stop/restart 后复现 | `mwan3_delete_iface_rules` 会删 `1000 < pref < 4000` 的规则（条件 `pref % 1000 == iface id`），1888 正在区间内 |

### 5.5 Docker 网桥与 UDP TPROXY

- **IPv4**: `docker0` 存在、`en_mode_tun` 为空且 `enable_udp_proxy=1` 时，先设 `nf_call_iptables=1`，成功后才把全局 `bridge-nf-call-iptables` 置 `0`
- **IPv6**: `ipv6_enable=1`、`enable_v6_udp_proxy=1` 且 `ipv6_mode=0/1` 时，同样处理 `nf_call_ip6tables` 与 `bridge-nf-call-ip6tables`
- 只处理 `docker0`，但全局值影响所有网桥；停止 OpenClash 或切换模式**不会**恢复这些值

> 让某个接口（如 `docker0`）流量完全绕过内核，用「来源流量控制」规则：`10-settings-geo-misc-src.md` §10.3。
