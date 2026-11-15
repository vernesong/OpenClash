## 防火墙与 DNS 规则详解（iptables + nftables 双后端）

> **用途**: 透明代理防火墙链结构（fw4/fw3）、模式解析与规则排序（§4.1–4.4）。ICMP、Tailscale、mwan3、Docker 等行为见 `05-firewall-special.md`。
> **后端**: `command -v fw4` 自动检测——有 `fw4` 用 nftables（OpenWrt 22.03+），否则 iptables + ipset。两种后端**规则逻辑完全相同**，仅语法不同。
> **排查**: 先让用户生成调试日志（含完整链）；不够再 `nft list ruleset`（fw4）或 `iptables -t nat -L -n`（fw3）。常见问题是规则排序（bypass 落到 redirect 之后）、fwmark 缺失导致策略路由不生效、DNS 劫持端口与 dnsmasq 冲突。
> **实现**: `/etc/init.d/openclash` 的 `set_firewall()`。

### 4.1 模式解析表

| UCI `en_mode` | `en_mode_tun` | 数据面 | DNS 面 |
|---------------|---------------|--------|--------|
| `redir-host` | 空 | TCP REDIRECT + UDP TPROXY | `dns.enhanced-mode: redir-host` |
| `fake-ip` | 空 | TCP REDIRECT + UDP TPROXY | `dns.enhanced-mode: fake-ip` |
| `redir-host-tun` | `1` | TCP+UDP 全 TUN | redir-host |
| `fake-ip-tun` | `1` | TCP+UDP 全 TUN | fake-ip |
| `redir-host-mix` | `2` | TCP REDIRECT + UDP TUN | redir-host |
| `fake-ip-mix` | `2` | TCP REDIRECT + UDP TUN | fake-ip |

**全局常量**（同 `08-settings-mode-traffic.md` §8.1.1 的「防火墙固定值」）：`PROXY_FWMARK=0x162`（被代理流量标记）、`PROXY_ROUTE_TABLE=0x162`（策略路由表）、`skgid=65534`（绕过代理组 ID，**内联字面量，无同名变量**）。

### 4.2 fw4 (nftables) 链结构 — `inet fw4` 表

#### 4.2.1 DNS 劫持链

> 劫持规则限定 `meta nfproto {ipv4}`；IPv6 用 `ip6 nexthdr` + `ip6 daddr fd7a:115c:a1e0::/48` 独立处理。`fw4_has_dns_hijack_rule()` 会在插入前检查 dstnat 是否已有 OpenClash DNS Hijack 规则避免重复。路由器自身的劫持用 `nat_output` 链（注释 `OpenClash Router DNS Hijack`），仅在 `router_self_proxy=1` 且 `enable_redirect_dns=1|2` 时创建。

| 模式 | 劫持方式 | 特殊处理 |
|------|----------|----------|
| `1` dnsmasq 转发 | `dstnat position 0`：`th dport 53` → `redirect to <dnsmasq_port>`，注释 `OpenClash DNS Hijack` | 私网 OUTPUT 规则带**转发进程 uid 豁免**（`meta skuid != <daemon_uid>`），避免 dnsmasq 把转发查询劫回自己；支持 chnroute_pass 的 dnsmasq set 集成 |
| `2` 防火墙重定向 | 建 `openclash_dns_redirect` 链（先 `add chain` + `flush chain`），规则 `th dport 53 → redirect to <dns_port>`；`dstnat position 0` 跳 `jump openclash_dns_redirect` | 不豁免转发进程（目标是 core，无自转发问题）；绕过 dnsmasq，性能更高但失去 chnroute_pass 的 dnsmasq 集成 |

两种模式都按 AC 黑白名单过滤（`lan_ac_mode=0` 排除黑名单、`=1` 仅白名单），并支持 OUTPUT 侧两条目标：本机地址:53（`fib daddr type local`）与私网段（`100.64.0.0/10` / `fd7a:115c:a1e0::/48`）。需要时向 `input` 链首插回包放行（注释 `OpenClash <daemon> Accept`，见 `05-firewall-special.md` §5.3.2）。

```bash
# 模式 1（黑名单模式；白名单模式换成 @lan_ac_white_ips / @lan_ac_white_macs 且去掉 !=）
nft insert rule inet fw4 dstnat position 0 \
  meta nfproto {ipv4} meta l4proto {tcp,udp} th dport 53 \
  ip saddr != @lan_ac_black_ips ether saddr != @lan_ac_black_macs \
  counter redirect to <dnsmasq_port> comment "OpenClash DNS Hijack"
```

选项与完整实现见 `09-settings-dns-ac-ipv6.md` §9.1.1。

#### 4.2.2 非 TUN 模式链（`en_mode_tun` 为空或 `2`）

| 链名 | 钩子来源 | 协议 | 动作 | 触发条件 |
|------|----------|------|------|----------|
| `openclash` | `dstnat` jump | TCP | REDIRECT → `$proxy_port`(7892) | 始终 |
| `openclash_mangle` | `mangle_prerouting` jump | UDP | TPROXY → `:$tproxy_port`(7895)，mark `0x162` | `enable_udp_proxy=1` 或 Fake-IP |
| `openclash_upnp` | `openclash_mangle` jump | UDP | UPnP 端口排除（RETURN） | 自动检测 upnpd |
| `openclash_output` | `nat_output` jump | TCP | 路由器自身 TCP REDIRECT | `router_self_proxy=1` 或 Fake-IP |
| `openclash_mangle_output` | `mangle_output` jump | UDP | 路由器自身 UDP 标记 | `router_self_proxy=1` + `enable_udp_proxy=1`（或 Fake-IP） |

**`openclash` 链规则顺序**（按 `set_firewall()` 实际执行序）:

| # | 规则 | 条件 / 说明 |
|---|------|------------|
| 1 | `ip daddr @localnetwork counter return` | 本地网络绕过 |
| 2 | `ct direction reply counter return` | 回复方向绕过 |
| 3 | 白名单未命中 return | `lan_ac_mode=1`；IP+MAC 列表都存在时合成一条 `ether saddr != @white_macs ip saddr != @white_ips`，只有一个列表时用单条 |
| 4 | 黑名单命中 return | `lan_ac_mode=0`（`ip saddr @black_ips` / `ether saddr @black_macs` 各一条） |
| 5 | `ip daddr {<fakeip_range>} counter redirect to $proxy_port` | 仅 fake-ip 模式 |
| 6 | `ip daddr @wan_ac_black_ips counter return` | WAN-AC |
| 7 | `th dport @wan_ac_black_ports counter return` | WAN 端口黑名单 |
| 8 | `th dport != @common_ports counter return` | 仅 redir-host 且 `common_ports != 0` |
| 9 | 中国 IP 绕行 return | `china_ip_route=1` 用 `ip daddr @china_ip_route`、`=2` 用 `ip daddr != @china_ip_route`；`china_ip_route_pass` 条件仅在 `enable_redirect_dns != 2` 时附加 |
| 10 | `ip protocol tcp counter redirect to $proxy_port` | 最终代理 |

**`openclash_mangle` 链规则顺序**（仅在 `enable_udp_proxy=1` 或 Fake-IP 时创建）: ① `ip daddr @localnetwork return` → ② `ct direction reply return` → ③ Fake-IP 段 `tproxy ip to 127.0.0.1:$tproxy_port mark set $PROXY_FWMARK counter accept`（仅 fake-ip）→ ④ WAN/LAN AC bypass（同 TCP 顺序）→ ⑤ `common_ports` 绕过（仅 redir-host）→ ⑥ `china_ip_route` 绕行 → ⑦ `jump openclash_upnp` → ⑧ 最终 `tproxy ip to 127.0.0.1:$tproxy_port mark set $PROXY_FWMARK counter accept`。`tproxy` 放在 `mark set` 之前：挂不上套接字时不再打标，报文按正常路由直连（fail-open），见 `05-firewall-special.md` §5.5。

跳转与放行：

```bash
# wan_guard = iifname != { "<WAN 接口>" }，WAN 入口不进劫持链
nft add rule inet fw4 dstnat meta nfproto {ipv4} $wan_guard ip protocol tcp counter jump openclash
nft add rule inet fw4 mangle_prerouting meta nfproto {ipv4} $wan_guard ip protocol udp counter jump openclash_mangle

# 分区放行：替代全局 DNAT Accept，插在各可代理区域的 input 链首
nft insert rule inet fw4 input_<zone> position 0 ct status dnat meta l4proto {tcp,udp} \
  th dport {<proxy_ports>,<DNSPORT>,53} counter accept comment "OpenClash Proxy Accept"
nft insert rule inet fw4 input_<zone> position 0 meta mark $PROXY_FWMARK counter accept \
  comment "OpenClash Proxy Accept"
```

- `enable_udp_proxy != 1` 但 `en_mode=fake-ip` 时仍建简化 `openclash_mangle`，只处理 Fake-IP UDP（无 common_ports / china_ip_route / UPNP 检查）
- UDP TPROXY 启用时会建策略路由：`ip rule add fwmark $PROXY_FWMARK table $PROXY_ROUTE_TABLE pref 999` + `ip route add local 0.0.0.0/0 dev lo table $PROXY_ROUTE_TABLE`

#### 4.2.3 TUN 模式链（`en_mode_tun=1` 或 `2`）

> 全 TUN（`en_mode_tun=1`）标记 tcp+udp；混合（`=2`）只标记 udp，TCP 仍走 REDIRECT。IPv4 由 `meta nfproto {ipv4}` 限定，IPv6 独立链。

| 链名 | 钩子来源 | 协议 | 动作 | 触发条件 |
|------|----------|------|------|----------|
| `openclash_mangle` | `mangle_prerouting` jump | TCP+UDP | 设 fwmark `0x162` | 始终 |
| `openclash_mangle_output` | `mangle_output` jump | TCP+UDP | 路由器自身 fwmark | `router_self_proxy=1` 或 Fake-IP |
| `openclash_upnp` | `openclash_mangle` jump | UDP | UPnP 端口排除 | 自动检测 upnpd |

**`openclash_mangle` 规则顺序**（TUN）:

| # | 规则 | 说明 |
|---|------|------|
| 1 | `iifname utun counter return` | 跳过 TUN 接口自身流量，防回环 |
| 2 | `ip daddr @localnetwork counter return` | 本地网络绕过 |
| 3 | `ct direction reply counter return` | 回复方向绕过 |
| 4 | LAN 白名单未命中 return | 同非 TUN |
| 5 | LAN 黑名单命中 return | 同非 TUN |
| 6 | Fake-IP 段 `mark set $PROXY_FWMARK counter` | 全 TUN 标记 tcp+udp，混合仅 udp |
| 7 | WAN 黑名单 IP / 端口 return | |
| 8 | `common_ports` 绕过 | 仅 redir-host |
| 9 | 中国 IP 绕行 return（含 `china_ip_route_pass`） | |
| 10 | ICMP echo-request `mark set $PROXY_FWMARK counter accept` | 注释 `OpenClash ICMP Mark` |
| 11 | `jump openclash_upnp`（UDP） | |
| 12 | 最终标记：全 TUN `mark set $PROXY_FWMARK counter`；混合 `meta l4proto {udp} mark set $PROXY_FWMARK counter` | |

跳转：`nft add rule inet fw4 mangle_prerouting meta nfproto {ipv4} $wan_guard counter jump openclash_mangle`。

**TUN 转发放行**（注释 `OpenClash TUN Forward` / `TUN Input` / `TUN Postrouting`）:

```bash
nft insert rule inet fw4 forward position 0 meta nfproto {ipv4} oifname utun counter accept
nft insert rule inet fw4 forward position 0 meta nfproto {ipv4} iifname utun counter accept
nft insert rule inet fw4 input   position 0 meta nfproto {ipv4} iifname utun counter accept
nft insert rule inet fw4 srcnat  position 0 meta nfproto {ipv4} oifname utun counter return
```

**TUN 的 QUIC 阻断**（`disable_udp_quic=1`）: 除 `input` 链外，额外在 `forward` 链加 `oifname utun udp dport 443 ip daddr != @china_ip_route counter reject comment "OpenClash QUIC REJECT"`，覆盖经 utun 转发的流量。

#### 4.2.4 IPv6 链（独立于 IPv4，仅 `ipv6_enable=1`）

| `ipv6_mode` | TCP | UDP | 策略路由 |
|-------------|-----|-----|----------|
| `0` TProxy | TPROXY → `:$tproxy_port` | TPROXY → `:$tproxy_port` | `ip -6 rule/route` |
| `1` Redirect | REDIRECT → `$proxy_port` | TPROXY（需 `enable_v6_udp_proxy=1`） | `ip -6 rule/route` |
| `2` TUN | fwmark → utun | fwmark → utun | 无（TUN 处理） |
| `3` Mix | REDIRECT → `$proxy_port` | fwmark → utun | 无（TUN 处理 UDP） |

| nftables 链 | 功能 | 触发条件 |
|-------------|------|----------|
| `openclash_v6` | IPv6 TCP REDIRECT | `ipv6_mode=1` 或 `3` |
| `openclash_mangle_v6` | IPv6 TPROXY / TUN fwmark | `enable_v6_udp_proxy=1` 或 `ipv6_mode != 1` |
| `openclash_output_v6` | 路由器自身 IPv6 TCP | `router_self_proxy=1` +（`ipv6_mode=1` 或 `3`） |
| `openclash_mangle_output_v6` | 路由器自身 IPv6 fwmark | `router_self_proxy=1` |
| `openclash_post_v6` | 旁路由 SNAT/MASQUERADE | `bypass_gateway_compatible=1` |
| `openclash_wan_input` | WAN 区入口防护（v4/v6 共用） | WAN 区链存在即建 |

**`openclash_mangle_v6` 规则顺序**: ① `ip6 daddr @localnetwork6 return` → ② `ct direction reply return` → ③ LAN AC（`lan_ac_black_ipv6s` / `lan_ac_white_ipv6s`，逻辑同 IPv4）→ ④ Fake-IP 段标记（按 `ipv6_mode` 选 TProxy 或 fwmark）→ ⑤ WAN AC / `common_ports` / `china_ip6_route` 绕行 → ⑥ ICMPv6 echo-request 标记（仅 `ipv6_mode=2/3`，注释 `OpenClash ICMPv6 Redirect`）→ ⑦ 最终代理规则（按 `ipv6_mode` 组合 TPROXY 或 fwmark）。TPROXY 规则同样是 `tproxy` 在前、`mark set` 在后（挂不上即直连，见 `05-firewall-special.md` §5.5）。

```bash
nft add rule inet fw4 mangle_prerouting meta nfproto {ipv6} counter jump openclash_mangle_v6
```

**IPv6 TUN 转发放行**（仅 `ipv6_mode=2/3`）: `forward oifname utun accept`、`forward iifname utun accept`、`input iifname utun accept`、`srcnat oifname utun return`（均 `meta nfproto {ipv6}`）。

**IPv6 DNS 劫持**（与 IPv4 对称，用 `ip6 nexthdr {tcp,udp}` + `th dport 53`）: 模式 1 → `dstnat position 0` 重定向到 `<dnsmasq_port>`；模式 2 → `openclash_dns_redirect` 链内重定向到 `<dns_port>`。

**IPv6 QUIC 阻断**: `input`（及 TUN/Mix 的 `forward oifname utun`）链插 `udp dport 443 ip6 daddr != @china_ip6_route counter reject`，方向随 `china_ip6_route` 变化。

**`localnetwork6` 默认元素**: `::/128`、`::1/128`、`::ffff:0:0/96`、`::ffff:0:0:0/96`、`64:ff9b::/96`、`100::/64`、`2001::/32`、`2001:20::/28`、`2001:db8::/32`、`2002::/16`、`fe80::/10`、`ff00::/8`。

### 4.3 策略路由辅助规则

除 `ip rule add fwmark $PROXY_FWMARK table $PROXY_ROUTE_TABLE` 外，`proxy_throw_route_add()` 与 `check_core_status()` 还补两类辅助路由：

| 场景 | 命令 | 作用 |
|------|------|------|
| 源地址校验（TUN 与非 TUN 的 TPROXY） | `ip route replace throw <cidr> table 0x162`，cidr 取自 `openclash_custom_localnetwork_ipv4.list`（文件缺失时用内置 9 段：`0.0.0.0/8`、`10/8`、`100.64/10`、`127/8`、`169.254/16`、`172.16/12`、`192.168/16`、`224/4`、`240/4`；与 fake-ip 前缀重叠的跳过）。`proxy_throw_route_del()` 用 `ip route flush table 0x162 type throw` 全清，不依赖当前列表 | `src_valid_mark=1`（Tailscale 等会设）时 `fib_validate_source()` 带 mark 查源，命中代理表唯一路由 `local default dev lo` → 判 martian 源并**静默丢包**（无日志无计数）；throw 让它回落 main 表。 |
| 路由器自身 fake-ip6（`ipv6_mode=2/3` 且 `router_self_proxy=1` 或 fake-ip 未走防火墙 DNS） | `ip -6 rule add iif lo to <fakeip_range6> lookup 0x162 pref 998` | 本机发出的 fake-ip6 目标在 output 打标前先进代理表，转发流量仍走 main |
| 与 mwan3 等共存 | `ip rule add fwmark 0x162 table 0x162 pref 999` | 取值原因见 `05-firewall-special.md` §5.4 |

> 症状对照：TUN 下「能连但部分目标不通、日志无异常」→ 先查 `net.ipv4.conf.all.src_valid_mark`；TPROXY 模式（`fake-ip`/`redir-host`，非 `*-mix`）下「内网 UDP 全部无回应、TCP 正常」（游戏机 NAT 类型为 F、mangle 链 TPROXY 计数增长但核心日志无 `[UDP]` 记录）→ 查表 `0x162` 的 throw 是否覆盖客户端网段；「远端私网段配了代理规则却整段走 WAN」→ 查该段是否仍被本地网络绕过列表包含；「路由器自身访问 fake-ip6 失败但内网客户端正常」→ 查第二条规则。三者都在 `revert_firewall()` 中回滚。

### 4.4 WAN 入口防护与分区放行

劫持链（`dstnat → openclash`、`mangle_prerouting → openclash_mangle`、DNS 劫持）只对非 WAN 入口生效；放行与拒绝都落在**区域自己的 input 链**，不用全局 `input` 链 accept：

| 位置 | 规则 | 作用 |
|------|------|------|
| 各可代理区域 `input_<zone>` / `zone_<zone>_input` 链首 | `ct status dnat ... th dport {<proxy_ports>,<DNSPORT>,53} accept` + `meta mark 0x162 accept` | 替代旧的全局 Redirect/TPROXY Accept（#5164） |
| WAN 区 `input_wan` / `zone_wan_input` 链首 | `jump openclash_wan_input` | 不论 WAN 区策略如何都先判 |
| `openclash_wan_input` 链 | `mark 0x162 reject`；`intranet_allowed=1` 时再加 `ct status dnat th dport {...} reject` 与代理端口 reject | 拦住 WAN 侧代理/被劫持流量；关闭时不影响用户端口转发 |
| TUN/混合模式的 `mangle_prerouting` 跳转 | `iifname != { <WAN 接口> }` | TUN 流量不进 INPUT，只能在此排除 WAN 入口 |

WAN 接口列表取自 `intranet_allowed_wan_name`（手动）或 fw4/fw3 的 WAN 区链跳转；同时属于其它区域的接口不会被排除（避免单网卡旁路由被误伤）。停止/重载时 `revert_firewall()` 清理区域链里的 OpenClash 规则。
