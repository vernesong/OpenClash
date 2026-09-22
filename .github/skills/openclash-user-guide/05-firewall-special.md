## ICMP/Ping 处理与高级流量控制

> **用途**: ICMP/Ping 在各运行模式下的处理机制，以及按设备/协议/端口/DSCP 的高级流量控制（§5.1–5.2）。

### 5.1 ICMP/Ping 处理详解

> **AI 行为指引**: 当用户询问「为什么 ping 不走代理」、「ping 通但 TCP 不通」、「Fake-IP 模式下 ping 198.18.x.x 被拒绝」等问题时，AI 应结合本节解释 ICMP 在非 TUN 和 TUN 模式下的不同处理方式。

OpenClash 对 ICMP（ping）请求的处理**取决于运行模式**：

**1. 非 TUN 模式（Redir-Host / Fake-IP，`en_mode_tun` 为空）**:

ICMP echo-request 在 `openclash_mangle` 链中被**仅标记 fwmark（0x162）但不重定向**：

```bash
nft add rule inet fw4 openclash_mangle ip protocol icmp \
  icmp type echo-request mark set "$PROXY_FWMARK" counter accept comment "OpenClash ICMP Mark"
```

- **ICMP 不会被代理**：非 TUN 模式下只有 TCP（REDIRECT）和 UDP（TPROXY）被重定向到 Mihomo 内核，ICMP 仅被标记 fwmark 后直接放行（`accept`）。这意味着 ping 请求走的是系统原始路由表，不会经过代理节点。
- **fwmark 的作用**：标记 0x162 仅影响策略路由选择（如旁路由回流），不影响代理行为本身。
- **绕过检查仍然生效**：ICMP 规则之前的 localnetwork/WAN-AC/LAN-AC/china_ip_route 等 RETURN 规则同样适用于 ICMP——被匹配的 ICMP 包会跳过标记规则。
- **路由器自身 ICMP**：当 `router_self_proxy=1` 时，路由器发出的 ping 在 `openclash_mangle_output` 链中同样被标记。

**2. TUN 模式（`en_mode_tun=1`）**:

ICMP echo-request 在 `openclash_mangle` 链中被标记 fwmark，随后通过策略路由进入 TUN 虚拟网卡：

```bash
# Step 1: 标记 ICMP
nft add rule inet fw4 openclash_mangle ip protocol icmp \
  icmp type echo-request mark set "$PROXY_FWMARK" counter accept

# Step 2: 策略路由（系统层面）— 所有标记 0x162 的流量路由到 TUN
ip rule add fwmark 0x162 table 0x162
ip route add default dev utun table 0x162
```

- **ICMP 被代理**：TUN 模式下所有标记 fwmark 的流量（包括 ICMP）被策略路由导向 `utun` 虚拟网卡，由 Mihomo 内核的 TUN 协议栈处理。
- **Mihomo 内核配置**：TUN 模式下 Mihomo 支持两个 ICMP 相关选项：
  - `icmp-timeout`（默认自动）：ICMP 连接超时时间（秒）
  - `disable-icmp-forwarding`（默认 false）：设为 `true` 可禁用 TUN 的 ICMP 转发（ping 将不被代理）

**3. Fake-IP 非 TUN 模式的 Ping 阻断**:

**仅在 Fake-IP 非 TUN 模式下**（`en_mode=fake-ip`, `en_mode_tun` 为空），对 Fake-IP 地址段（默认 `198.18.0.0/16`）的 ping 会被防火墙**显式 REJECT**：

```bash
# INPUT 链 — 阻止路由器自身收到发往 Fake-IP 的 ping
nft insert rule inet fw4 input position 0 ip protocol icmp \
  icmp type echo-request ip daddr { 198.18.0.0/16 } counter reject

# FORWARD 链 — 阻止局域网设备间转发 Fake-IP 的 ping
nft insert rule inet fw4 forward position 0 ip protocol icmp \
  icmp type echo-request ip daddr { 198.18.0.0/16 } counter reject

# OUTPUT 链 — 阻止路由器发出对 Fake-IP 的 ping（排除 OpenClash 自身进程 skgid=65534）
nft insert rule inet fw4 output position 0 ip protocol icmp \
  icmp type echo-request ip daddr { 198.18.0.0/16 } \
  skgid != 65534 counter reject
```

这是因为在非 TUN 模式下，Fake-IP 地址没有对应的 TCP/UDP 重定向路径（TCP 走 REDIRECT、UDP 走 TPROXY，但 ICMP 都不到达内核），发往这些地址的 ping 无意义且会干扰网络诊断。OUTPUT 链排除 `skgid=65534` 是为了避免影响 OpenClash 自身进程的内部通信。

> **TUN 模式下的区别**：Fake-IP **TUN 模式不添加这些 REJECT 规则**。因为 ICMP 经策略路由进入 TUN 虚拟网卡后，由内核的 `skipPingForwardingByAddr()` 判断——若目标是 Fake-IP，内核返回伪造 echo-reply（~0ms 虚假延迟），不产生实际网络流量。

**4. IPv6 ICMP（ICMPv6）**:

仅在 IPv6 TUN/混合模式（`ipv6_mode=2` 或 `3`）下标记：

```bash
nft add rule inet fw4 openclash_mangle_v6 ip6 nexthdr icmpv6 \
  icmpv6 type echo-request mark set "$PROXY_FWMARK" counter accept
```

IPv6 非 TUN 模式下 ICMPv6 **不被标记也不被代理**。IPv6 Fake-IP 地址范围的 ping 在**非 TUN 的 IPv6 模式下**被 REJECT（返回 `icmpv6 admin-prohibited`），条件为 `$ipv6_mode -ne 2 -a $ipv6_mode -ne 3`。TUN/Mix 模式下的 IPv6 Fake-IP ping 同样由内核的 `skipPingForwardingByAddr()` 处理（伪造回复）。

**总结**（一句话结论：普通模式下 ping 不会进隧道、不被代理；TUN/混合模式下 ping 会进隧道，但 Fake-IP ping 到的是本地虚假延迟，不代表真能访问）:

| 运行模式 | ICMP 进入 TUN | ICMP fwmark | 实际处理 |
|----------|-------------|-------------|----------|
| Redir-Host (非TUN) | ❌ | ✅ 标记 0x162 | 仅标记后放行，不经内核处理 |
| Fake-IP (非TUN) | ❌ | ✅ 标记 0x162 | 防火墙 REJECT Fake-IP 范围的 ping |
| Redir-Host TUN | ✅ | ✅ 标记 0x162 | 真实 IP → DIRECT 直连延迟 |
| Fake-IP TUN | ✅ | ✅ 标记 0x162 | 真实 IP → DIRECT 直连；Fake-IP → 伪造回复（~0ms 虚假延迟） |
| Redir-Host Mix | ✅ | ✅ 标记 0x162 | 同 Redir-Host TUN：ICMP 标记后经策略路由进入 TUN，DIRECT 直连 |
| Fake-IP Mix | ✅ | ✅ 标记 0x162 | 同 Fake-IP TUN：真实 IP → DIRECT 直连；Fake-IP → 内核伪造回复 |

> **实用提示**：如果用户发现 ping 不通但网页正常，首先确认不是 Fake-IP **非 TUN** 模式下在 ping 被代理的域名（Fake-IP 返回 `198.18.x.x`，防火墙直接 REJECT）。Fake-IP TUN/Mix 模式下 ping Fake-IP 地址会返回虚假 ~0ms 延迟。非 Fake-IP 的真实 IP ping 在 TUN/Mix 模式下走 DIRECT 直连，延迟反映的是本地网络质量。

**内核侧 ICMP 处理机制**（`listener/sing_tun/prepare.go` — Mihomo TUN 监听器）:

当 ICMP echo-request 经策略路由进入 TUN 虚拟网卡后，Mihomo 内核按以下优先级处理：

1. **目标是 Fake-IP 地址**（`resolver.IsFakeIP(addr)`） → 返回 `nil, nil`，内核用**伪造的 echo-reply** 回复。上层看到 "ping 成功" 但实际未经过网络，延迟显示为虚假的 ~0ms
2. **目标是 TUN 接口自身 IP**（`inet4_address` / `inet6_address` 范围内） → 同上，伪造回复
3. **`disable-icmp-forwarding: true`** → 所有 ICMP 均伪造回复
4. **以上均不满足**（真实 IP 且未禁用转发） → 通过 `ping.ConnectDestination()` 以 **DIRECT 模式**发出真实 ICMP 包，等待真实 reply。延迟为本地网络到目标的实际 RTT
5. **ICMP 超时**: 默认 10 秒（`sing.go` 常量），可通过 `icmp-timeout` 自定义

> **关键结论**: TUN 模式下 ping 的处理分两种情况——目标是 Fake-IP → 虚假 0ms 延迟；目标是真实 IP → DIRECT 直连延迟。ping **始终不经过代理节点**，这与 TCP/UDP 流量（经代理转发）的行为不同。

---

### 5.2 高级流量控制 (`firewall_lan_ac_traffic`) — 按设备/协议/端口/DSCP 精确控制

> **UCI 配置路径**: `config firewall_lan_ac_traffic` 段，通过「插件设置 → 黑白名单 → 高级流量控制」配置。
> 每条规则作为一个独立的 UCI section，在 `set_firewall()` 中通过 `config_foreach firewall_lan_ac_traffic` 遍历插入到已有防火墙链的最前面（`position 0`），因此**优先级高于**所有其他 bypass/redirect 规则。

**UCI 配置字段**:

| 字段 | 类型 | 可选值 | 说明 |
|------|------|--------|------|
| `enabled` | bool | `0`/`1` | 是否启用此规则 |
| `src_ip` | string | IP/CIDR 或 `localnetwork` | 源 IP 地址（`localnetwork` 表示匹配所有本地网络设备） |
| `src_port` | string | 端口范围 (如 `0-65535`) | 源端口范围 |
| `proto` | string | `tcp`/`udp`/`both` | 匹配的协议 |
| `target` | string | `return`/`accept`/`drop` | 动作：`return`=跳过代理(默认)/`accept`=放行/`drop`=丢弃(等效return) |
| `dscp` | string | DSCP 值 (如 `46`) | DSCP 标记匹配（需 iptables DSCP 模块，fw4 无需额外模块） |
| `family` | string | `ipv4`/`ipv6`/`both` | IP 协议族 |
| `interface` | string | 接口名 (如 `br-lan`) | 入接口匹配 |
| `user` | string | UID | 按用户 ID 匹配（仅 OUTPUT 链） |
| `comment` | string | 描述文字 | 规则注释/标识 |

**规则插入位置** (fw4):

每条规则根据协议和模式被插入到以下链的最前面：

| 流量方向 | IPv4 TCP 链 | IPv4 UDP 链 | IPv6 TCP 链 | IPv6 UDP 链 |
|----------|------------|------------|------------|------------|
| **入站** (LAN→路由器) | `openclash` (非TUN) / `openclash_mangle` (TUN) | `openclash_mangle` | `openclash_v6` / `openclash_mangle_v6` | `openclash_mangle_v6` |
| **出站** (路由器自身) | `openclash_output` (非TUN) / `openclash_mangle_output` (TUN) | `openclash_mangle_output` | `openclash_output_v6` / `openclash_mangle_output_v6` | `openclash_mangle_output_v6` |
| **旁路由 SNAT** | `openclash_post` | `openclash_post` | `openclash_post_v6` | `openclash_post_v6` |

**规则格式示例** (fw4 nftables):

```bash
# 入站规则: 跳过代理
nft insert rule inet fw4 openclash position 0 tcp \
  sport 0-65535 meta nfproto {ipv4} ip daddr != {<fakeip_range>} \
  ip saddr {192.168.1.100} counter return comment "my_device_bypass"

# OUTPUT 规则: 含 user 匹配
nft insert rule inet fw4 openclash_output position 0 tcp \
  sport 0-65535 meta skuid 1000 ip daddr != {<fakeip_range>} \
  ip saddr {192.168.1.100} counter return comment "my_user_rule"
```

> **注意事项**: 
> - 所有规则自动排除 Fake-IP 地址范围（`ip daddr != {<fakeip_range>}`），确保 Fake-IP 流量不受影响。
> - `target=drop` 在防火墙规则中实际执行为 `return`（跳过代理），区别在于 `drop` 在策略路由/旁路由链中也执行 `return`。
> - `user` 字段仅对 OUTPUT 链生效（路由器自身出站流量），入站流量不支持 UID 匹配。
> - DSCP 匹配在 fw3 (iptables) 环境下需要 `iptables-mod-extra`（提供 DSCP 模块），如不可用会输出警告并跳过 DSCP 规则。

---
