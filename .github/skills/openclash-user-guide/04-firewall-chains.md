## 防火墙与 DNS 规则详解（iptables + nftables 双后端）

> **用途**: 透明代理防火墙链结构（fw4/fw3）、模式解析与规则排序，理解流量如何被代理/绕过。

> **小节索引**: §4.1 模式解析表 · §4.2 fw4 链结构（§4.2.1 DNS 劫持 / §4.2.2 非 TUN / §4.2.3 TUN / §4.2.4 IPv6）

> OpenClash 同时支持 **fw3 (iptables/ipset)** 和 **fw4 (nftables)** 两种防火墙后端，通过 `command -v fw4` 自动检测：
> - 存在 `fw4` → 使用 **nftables** (OpenWrt 22.03+)
> - 不存在 `fw4` → 使用 **iptables + ipset** (旧版 OpenWrt)
> 所有 `if [ -n "$FW4" ]` / `if [ -z "$FW4" ]` 分支互斥，两种后端的**规则逻辑完全相同**，仅语法不同。
>
> **AI 行为指引**: 当用户询问透明代理/防火墙相关问题时（如"为什么设备无法上网"、"旁路由模式下流量不走代理"、
> "如何验证防火墙规则是否生效"、"TUN 模式下某协议不通"），AI 应**先让用户生成调试日志**
> （含完整防火墙规则链）。日志不足时再指导用户在路由器终端执行 `nft list ruleset`（fw4）或
> `iptables -t nat -L -n`（fw3）查看实际规则。结合下表中的链结构和规则排序，对比用户的需求判断规则是否如预期生效。
> 如涉及底层实现细节，查阅 [OpenClash 源码](https://github.com/vernesong/OpenClash/tree/dev) 中
> `/etc/init.d/openclash` 的 `set_firewall()` 函数。
> 常见问题：规则排序错误（bypass 在 redirect 之后）、fwmark 未设置导致策略路由不生效、
> DNS 劫持端口与 dnsmasq 冲突。

### 4.1 模式解析表

| UCI `en_mode` | `en_mode_tun` | 数据面 | DNS 面 |
|---------------|---------------|--------|--------|
| `redir-host` | *(空)* | TCP REDIRECT + UDP TPROXY | `dns.enhanced-mode: redir-host` |
| `fake-ip` | *(空)* | TCP REDIRECT + UDP TPROXY | `dns.enhanced-mode: fake-ip` |
| `redir-host-tun` | `1` | TCP+UDP 全 TUN | `dns.enhanced-mode: redir-host` |
| `fake-ip-tun` | `1` | TCP+UDP 全 TUN | `dns.enhanced-mode: fake-ip` |
| `redir-host-mix` | `2` | TCP REDIRECT + UDP TUN | `dns.enhanced-mode: redir-host` |
| `fake-ip-mix` | `2` | TCP REDIRECT + UDP TUN | `dns.enhanced-mode: fake-ip` |

**全局常量**: 与「`08-settings-mode-traffic.md` §8.1.1 插件强制覆盖/禁用的设置 → 防火墙固定值」表一致——`PROXY_FWMARK=0x162`（被代理流量防火墙标记）、`PROXY_ROUTE_TABLE=0x162`（策略路由表 ID）、`SKIP_GROUP=65534`（绕过代理组 ID，skgid）。

---

### 4.2 fw4 (nftables) 链结构 — `inet fw4` 表

#### 4.2.1 DNS 劫持链

> DNS 劫持规则使用 `meta nfproto {ipv4}` 限制仅匹配 IPv4 流量；IPv6 DNS 劫持在 IPv6 段独立处理。
> `fw4_has_dns_hijack_rule()` 函数在插入前检查 dstnat 链是否已有 OpenClash DNS Hijack 规则，避免重复。

**`enable_redirect_dns=1` (Dnsmasq 转发模式)** — DNS 53 端口 → dnsmasq 端口:

```bash
# === IPv4 PREROUTING: 劫持发往 53 端口的 DNS → 重定向到 dnsmasq 端口 ===
# 黑名单模式 (lan_ac_mode=0): 排除 LAN 黑名单设备 + MAC 黑名单
nft insert rule inet fw4 dstnat position 0 \
  meta nfproto {ipv4} meta l4proto {tcp,udp} th dport 53 \
  ip saddr != @lan_ac_black_ips ether saddr != @lan_ac_black_macs \
  counter redirect to <dnsmasq_port> comment "OpenClash DNS Hijack"

# 白名单模式 (lan_ac_mode=1): 仅白名单 IP/MAC 走劫持
nft insert rule inet fw4 dstnat position 0 \
  meta nfproto {ipv4} meta l4proto {tcp,udp} th dport 53 \
  ip saddr @lan_ac_white_ips counter redirect to <dnsmasq_port> comment "OpenClash DNS Hijack"
nft insert rule inet fw4 dstnat position 0 \
  meta nfproto {ipv4} meta l4proto {tcp,udp} th dport 53 \
  ether saddr @lan_ac_white_macs counter redirect to <dnsmasq_port> comment "OpenClash DNS Hijack"

# === OUTPUT (仅 router_self_proxy=1): 路由器自身 DNS ===
nft add chain inet fw4 nat_output { type nat hook output priority -1; }
nft insert rule inet fw4 nat_output position 0 \
  skgid != 65534 meta nfproto {ipv4} meta l4proto {tcp,udp} th dport 53 \
  ip daddr {127.0.0.1} counter redirect to <dnsmasq_port> comment "OpenClash DNS Hijack"
```

**`enable_redirect_dns=2` (防火墙重定向模式)** — DNS 53 端口 → Mihomo DNS 端口 (7874):

```bash
nft add chain inet fw4 openclash_dns_redirect
nft flush chain inet fw4 openclash_dns_redirect

# 黑名单模式: 排除黑名单设备
nft add rule inet fw4 openclash_dns_redirect \
  meta nfproto {ipv4} meta l4proto {tcp,udp} th dport 53 \
  ip saddr != @lan_ac_black_ips ether saddr != @lan_ac_black_macs \
  counter redirect to <dns_port> comment "OpenClash DNS Hijack"

# 白名单模式: 仅白名单设备走劫持
nft add rule inet fw4 openclash_dns_redirect \
  meta nfproto {ipv4} meta l4proto {tcp,udp} th dport 53 \
  ip saddr @lan_ac_white_ips counter redirect to <dns_port> comment "OpenClash DNS Hijack"
nft add rule inet fw4 openclash_dns_redirect \
  meta nfproto {ipv4} meta l4proto {tcp,udp} th dport 53 \
  ether saddr @lan_ac_white_macs counter redirect to <dns_port> comment "OpenClash DNS Hijack"

nft insert rule inet fw4 dstnat position 0 \
  meta nfproto {ipv4} meta l4proto {tcp,udp} th dport 53 counter jump openclash_dns_redirect

# === OUTPUT (仅 router_self_proxy=1): 路由器自身 DNS 直接到 dns_port ===
nft add chain inet fw4 nat_output { type nat hook output priority -1; }
nft insert rule inet fw4 nat_output position 0 \
  meta nfproto {ipv4} meta l4proto {tcp,udp} th dport 53 \
  ip daddr {127.0.0.1} meta skgid != 65534 counter redirect to <dns_port> comment "OpenClash DNS Hijack"
```

> **DNS 劫持模式对比**: 模式 1 (Dnsmasq) 将 DNS 先转到 dnsmasq 再转发到 Mihomo DNS，支持 chnroute_pass 的 dnsmasq ipset/nftset 集成；模式 2 (防火墙) 直接将 DNS 流量 DNAT 到 Mihomo DNS 端口，绕过 dnsmasq，性能更高但失去 chnroute_pass 的 dnsmasq 集成。两种模式均可配合 AC 黑白名单进行设备级 DNS 劫持控制。选项的 UCI 配置与完整实现见 `09-settings-dns-ac-ipv6.md` §9.1.1。

#### 4.2.2 非 TUN 模式链 (`en_mode_tun` 为空或 `2`)

| 链名 | 钩子来源 | 协议 | 动作 | 触发条件 |
|------|----------|------|------|----------|
| `openclash` | `dstnat` jump | TCP | REDIRECT → `$proxy_port`(7892) | 始终 |
| `openclash_mangle` | `mangle_prerouting` jump | UDP | TPROXY → `:$tproxy_port`(7895), mark `0x162` | `enable_udp_proxy=1` 或 Fake-IP 模式 |
| `openclash_upnp` | `openclash_mangle` jump | UDP | UPNP 端口排除 (RETURN) | 自动检测 upnpd |
| `openclash_output` | `nat_output` jump | TCP | 路由器自身 TCP REDIRECT | `router_self_proxy=1` 或 Fake-IP 模式 |
| `openclash_mangle_output` | `mangle_output` jump | UDP | 路由器自身 UDP 标记 | `router_self_proxy=1`+`enable_udp_proxy=1` 或 Fake-IP |

**`openclash` 链规则排序 (TCP REDIRECT)**（fw4，按 `set_firewall()` 实际执行顺序）:

```bash
# 1. 本地网络绕过
nft add rule inet fw4 openclash ip daddr @localnetwork counter return

# 2. 回复方向绕过
nft add rule inet fw4 openclash ct direction reply counter return

# 3. LAN 白名单非匹配 RETURN (lan_ac_mode=1, 同时有 IP+MAC 白名单时两者均不匹配才 RETURN)
nft add rule inet fw4 openclash ether saddr != @lan_ac_white_macs \
  ip saddr != @lan_ac_white_ips counter return
# 3b. 单独白名单 RETURN (仅有 IP 或仅有 MAC 白名单时独立判断)
nft add rule inet fw4 openclash ether saddr != @lan_ac_white_macs counter return
nft add rule inet fw4 openclash ip saddr != @lan_ac_white_ips counter return

# 4. LAN 黑名单匹配 RETURN
nft add rule inet fw4 openclash ip saddr @lan_ac_black_ips counter return
nft add rule inet fw4 openclash ether saddr @lan_ac_black_macs counter return

# 5. Fake-IP 范围 REDIRECT (仅 fake-ip 模式)
nft add rule inet fw4 openclash ip protocol tcp \
  ip daddr {<fakeip_range>} counter redirect to $proxy_port

# 6. WAN 黑名单 IP (WAN-AC)
nft add rule inet fw4 openclash ip daddr @wan_ac_black_ips counter return
# 7. WAN 黑名单端口
nft add rule inet fw4 openclash th dport @wan_ac_black_ports counter return

# 8. 非标准端口绕过 (仅 redir-host 模式, common_ports != 0)
nft add rule inet fw4 openclash th dport != @common_ports counter return

# 9. 中国 IP 绕行 (china_ip_route)
#   mode=1: ip daddr @china_ip_route [ip daddr != @china_ip_route_pass] counter return
#   mode=2: ip daddr != @china_ip_route [ip daddr != @china_ip_route_pass] counter return
#   (china_ip_route_pass 仅在 enable_redirect_dns != 2 时附加)

# 10. 最终代理: 所有剩余 TCP → REDIRECT
nft add rule inet fw4 openclash ip protocol tcp counter redirect to $proxy_port

# === 跳转规则 ===
nft add rule inet fw4 dstnat meta nfproto {ipv4} ip protocol tcp counter jump openclash

# === DNAT Accept (当 zone input 策略为 REJECT 时需要) ===
nft insert rule inet fw4 input position 0 ct status dnat accept comment "OpenClash Redirect Accept"
```

**`openclash_mangle` 链规则排序 (UDP TPROXY)** — 仅在 `enable_udp_proxy=1` 或 Fake-IP 模式时创建:

```bash
# 1. 本地网络绕过
nft add rule inet fw4 openclash_mangle ip daddr @localnetwork counter return
# 2. 回复方向绕过
nft add rule inet fw4 openclash_mangle ct direction reply counter return

# 3. Fake-IP UDP TPROXY (仅 fake-ip 模式)
nft add rule inet fw4 openclash_mangle meta l4proto {udp} \
  ip daddr {<fakeip_range>} mark set $PROXY_FWMARK \
  tproxy ip to 127.0.0.1:$tproxy_port counter accept

# 4. WAN/LAN AC bypass (同 TCP 链顺序)
# 5. common_ports 绕过 (仅 redir-host 模式)
# 6. china_ip_route 绕行

# 7. UPNP 排除
nft add rule inet fw4 openclash_mangle ip protocol udp counter jump openclash_upnp

# 8. TPROXY 最终规则
nft add rule inet fw4 openclash_mangle meta l4proto {udp} \
  mark set $PROXY_FWMARK tproxy ip to 127.0.0.1:$tproxy_port counter accept

# === 跳转规则 ===
nft add rule inet fw4 mangle_prerouting meta nfproto {ipv4} ip protocol udp counter jump openclash_mangle

# === TPROXY Accept (当 zone input 策略为 REJECT 时需要) ===
nft insert rule inet fw4 input position 0 meta mark $PROXY_FWMARK accept comment "OpenClash TPROXY Accept"
```

> **注意**: 当 `enable_udp_proxy != 1` 但 `en_mode = fake-ip` 时，仍会创建简化的 `openclash_mangle` 链仅处理 Fake-IP UDP 流量（无 common_ports/china_ip_route/UPNP 检查）。`ip rule add fwmark $PROXY_FWMARK table $PROXY_ROUTE_TABLE` + `ip route add local 0.0.0.0/0 dev lo table $PROXY_ROUTE_TABLE` 在 UDP TPROXY 启用时创建策略路由。

#### 4.2.3 TUN 模式链 (`en_mode_tun=1` 或 `2`)

> TUN 模式使用 `meta nfproto {ipv4}` 限制仅处理 IPv4 流量，IPv6 由独立链处理。
> 全 TUN 模式 (`en_mode_tun=1`) 标记 tcp+udp；混合模式 (`en_mode_tun=2`) 仅标记 udp（TCP 仍走 REDIRECT）。

| 链名 | 钩子来源 | 协议 | 动作 | 触发条件 |
|------|----------|------|------|----------|
| `openclash_mangle` | `mangle_prerouting` jump | TCP+UDP | 设置 fwmark `0x162` | 始终 |
| `openclash_mangle_output` | `mangle_output` jump | TCP+UDP | 路由器自身 fwmark | `router_self_proxy=1` 或 Fake-IP |
| `openclash_upnp` | `openclash_mangle` jump | UDP | UPNP 端口排除 (RETURN) | 自动检测 |

**`openclash_mangle` 规则排序 (TUN 模式)**（fw4，按 `set_firewall()` 实际执行顺序）:

```bash
# 1. 跳过 TUN 接口自身流量 (防止回环)
nft add rule inet fw4 openclash_mangle meta l4proto {tcp,udp} \
  iifname utun counter return

# 2. 本地网络绕过
nft add rule inet fw4 openclash_mangle ip daddr @localnetwork counter return
# 3. 回复方向绕过
nft add rule inet fw4 openclash_mangle ct direction reply counter return

# 4. LAN 白名单非匹配 RETURN
nft add rule inet fw4 openclash_mangle ether saddr != @lan_ac_white_macs \
  ip saddr != @lan_ac_white_ips counter return

# 5. LAN 黑名单匹配 RETURN
nft add rule inet fw4 openclash_mangle ip saddr @lan_ac_black_ips counter return
nft add rule inet fw4 openclash_mangle ether saddr @lan_ac_black_macs counter return

# 6. Fake-IP TUN 标记 (全TUN标记tcp+udp, 混合仅标记udp)
nft add rule inet fw4 openclash_mangle \
  meta l4proto {tcp,udp} ip daddr {<fakeip_range>} mark set $PROXY_FWMARK counter

# 7. WAN 黑名单 IP/端口
nft add rule inet fw4 openclash_mangle ip daddr @wan_ac_black_ips counter return
nft add rule inet fw4 openclash_mangle th dport @wan_ac_black_ports counter return

# 8. 非标准端口绕过 (仅 redir-host 模式)
nft add rule inet fw4 openclash_mangle th dport != @common_ports counter return

# 9. 中国 IP 绕行 (含 china_ip_route_pass 集成)
#   mode=1: ip daddr @china_ip_route [ip daddr != @china_ip_route_pass] counter return
#   mode=2: ip daddr != @china_ip_route [ip daddr != @china_ip_route_pass] counter return

# 10. ICMP 标记 (meta nfproto {ipv4})
nft add rule inet fw4 openclash_mangle meta nfproto {ipv4} \
  ip protocol icmp icmp type echo-request mark set $PROXY_FWMARK counter accept \
  comment "OpenClash ICMP Mark"

# 11. UPNP 排除 (UDP)
nft add rule inet fw4 openclash_mangle ip protocol udp counter jump openclash_upnp

# 12. 最终标记 — 全 TUN 模式标记所有剩余流量，混合模式仅标记 udp
#     全TUN: mark set $PROXY_FWMARK counter
#     混合:  meta l4proto {udp} mark set $PROXY_FWMARK counter
nft add rule inet fw4 openclash_mangle mark set $PROXY_FWMARK counter

# === 跳转规则 (meta nfproto {ipv4}) ===
nft add rule inet fw4 mangle_prerouting meta nfproto {ipv4} counter jump openclash_mangle
```

**TUN 转发规则** (utun 允许通过，同样使用 `meta nfproto {ipv4}`):

```bash
nft insert rule inet fw4 forward position 0 meta nfproto {ipv4} oifname utun counter accept \
  comment "OpenClash TUN Forward"
nft insert rule inet fw4 forward position 0 meta nfproto {ipv4} iifname utun counter accept \
  comment "OpenClash TUN Forward"
nft insert rule inet fw4 input position 0 meta nfproto {ipv4} iifname utun counter accept \
  comment "OpenClash TUN Input"
nft insert rule inet fw4 srcnat position 0 meta nfproto {ipv4} oifname utun counter return \
  comment "OpenClash TUN Postrouting"
```

**TUN 模式 QUIC 阻断** (仅 `disable_udp_quic=1`):

```bash
# TUN 模式 extras: forward 链额外匹配 oifname utun 覆盖经 TUN 转发的流量
nft insert rule inet fw4 forward position 0 oifname utun udp dport 443 \
  ip daddr != @china_ip_route counter reject comment "OpenClash QUIC REJECT"
# 标准: input 链 REJECT (同非TUN)
nft insert rule inet fw4 input position 0 udp dport 443 \
  ip daddr != @china_ip_route counter reject comment "OpenClash QUIC REJECT"
```

#### 4.2.4 IPv6 链 (独立于 IPv4)

> IPv6 防火墙链仅在 `ipv6_enable=1` 时创建。`ipv6_mode` 决定数据面处理方式。
> IPv6 DNS 劫持使用 `meta nfproto {ipv6}` + `ip6 nexthdr {tcp,udp}`，与 IPv4 规则结构对称。

**IPv6 模式详解**:

| `ipv6_mode` | TCP 处理 | UDP 处理 | 策略路由 |
|-------------|---------|---------|----------|
| `0` (TProxy) | TPROXY → `:$tproxy_port` | TPROXY → `:$tproxy_port` | `ip -6 rule/route` |
| `1` (Redirect) | REDIRECT → `$proxy_port` | TPROXY → `:$tproxy_port` (需 `enable_v6_udp_proxy=1`) | `ip -6 rule/route` |
| `2` (TUN) | fwmark → utun | fwmark → utun | 无 (TUN 处理) |
| `3` (Mix) | REDIRECT → `$proxy_port` | fwmark → utun | 无 (TUN 处理 UDP) |

**IPv6 链总览**:

| nftables 链 | 功能 | 触发条件 |
|-------------|------|----------|
| `openclash_v6` | IPv6 TCP REDIRECT | `ipv6_mode=1` 或 `3` |
| `openclash_mangle_v6` | IPv6 TPROXY / TUN fwmark | `enable_v6_udp_proxy=1` 或 `ipv6_mode≠1` |
| `openclash_output_v6` | 路由器自身 IPv6 TCP | `router_self_proxy=1` + (`ipv6_mode=1` 或 `3`) |
| `openclash_mangle_output_v6` | 路由器自身 IPv6 fwmark | `router_self_proxy=1` |
| `openclash_post_v6` | 旁路由 SNAT/MASQUERADE | `bypass_gateway_compatible=1` |
| `openclash_wan6_input` | 仅内网 IPv6 WAN 防护 | `intranet_allowed=1` |

**IPv6 链规则结构** (以 `openclash_mangle_v6` 为例，包含 TProxy/TUN/Mix 所有模式的综合处理):

```bash
# 1. IPv6 本地网络绕过 (localnetwork6: ::/128, ::1/128, fe80::/10, ff00::/8 等)
nft add rule inet fw4 openclash_mangle_v6 ip6 daddr @localnetwork6 counter return

# 2. 回复方向绕过
nft add rule inet fw4 openclash_mangle_v6 ct direction reply counter return

# 3. LAN AC 规则 (黑白名单，同 IPv4 逻辑，使用 lan_ac_black_ipv6s/lan_ac_white_ipv6s)
# 4. Fake-IP 范围标记 (根据 ipv6_mode 不同: TProxy 或 fwmark)

# 5. WAN AC / common_ports / china_ip6_route 绕行

# 6. ICMPv6 标记 (仅 ipv6_mode=2 或 3，即 TUN/Mix 模式)
nft add rule inet fw4 openclash_mangle_v6 meta nfproto {ipv6} \
  ip6 nexthdr icmpv6 icmpv6 type echo-request mark set $PROXY_FWMARK counter accept \
  comment "OpenClash ICMPv6 Redirect"

# 7. 最终代理规则 (根据 ipv6_mode 不同组合 TCP/UDP TPROXY 或 fwmark)

# === 跳转规则 ===
nft add rule inet fw4 mangle_prerouting meta nfproto {ipv6} counter jump openclash_mangle_v6
```

**IPv6 TUN 转发规则** (仅 `ipv6_mode=2` 或 `3`):

```bash
nft insert rule inet fw4 forward position 0 meta nfproto {ipv6} oifname utun counter accept
nft insert rule inet fw4 forward position 0 meta nfproto {ipv6} iifname utun counter accept
nft insert rule inet fw4 input position 0 meta nfproto {ipv6} iifname utun counter accept
nft insert rule inet fw4 srcnat position 0 meta nfproto {ipv6} oifname utun counter return
```

**IPv6 DNS 劫持** (与 IPv4 对称，使用 `ip6 nexthdr` 和 `ip6 saddr`):

```bash
# enable_redirect_dns=1 (Dnsmasq 模式): 劫持 IPv6 DNS 到 dnsmasq 端口
nft insert rule inet fw4 dstnat position 0 \
  meta nfproto {ipv6} ip6 nexthdr {tcp,udp} th dport 53 \
  counter redirect to <dnsmasq_port> comment "OpenClash DNS Hijack"

# enable_redirect_dns=2 (防火墙模式): 劫持 IPv6 DNS 到 Mihomo DNS 端口
nft add rule inet fw4 openclash_dns_redirect \
  meta nfproto {ipv6} ip6 nexthdr {tcp,udp} th dport 53 \
  counter redirect to <dns_port> comment "OpenClash DNS Hijack"
```

**IPv6 QUIC 阻断** (仅 `disable_udp_quic=1`):

```bash
# 根据 china_ip6_route 选择绕行方向
# TUN/Mix 模式 extra: forward + oifname utun
nft insert rule inet fw4 input position 0 udp dport 443 \
  ip6 daddr != @china_ip6_route counter reject comment "OpenClash QUIC REJECT"
nft insert rule inet fw4 forward position 0 [oifname utun] udp dport 443 \
  ip6 daddr != @china_ip6_route counter reject comment "OpenClash QUIC REJECT"
```

**IPv6 `localnetwork6` 默认元素**:
```
::/128, ::1/128, ::ffff:0:0/96, ::ffff:0:0:0/96, 64:ff9b::/96,
100::/64, 2001::/32, 2001:20::/28, 2001:db8::/32, 2002::/16,
fe80::/10, ff00::/8
```
