## 功能行为：ICMP、高级流量控制、Tailscale 与特殊场景

> **用途**: ICMP/Ping 的处理机制、高级流量控制、Tailscale/overlay 联动，以及 mwan3 多 WAN 分流与 Docker 网桥（§5.1–5.5）；链结构与规则顺序见 `04-firewall-chains.md`。

> **小节索引**: §5.1 ICMP/Ping 处理 · §5.2 高级流量控制（`firewall_lan_ac_traffic`）· §5.3 Tailscale（MagicDNS/`ts.net`/accept-dns）· §5.4 与 mwan3 共存 · §5.5 Docker 网桥与 UDP TPROXY

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

**一句话说明**：普通模式下 ping 不会进隧道、不被代理；TUN/混合模式下 ping 会进隧道，但 Fake-IP ping 到的是本地虚假延迟，不代表真能访问：

| 运行模式 | ICMP 进入 TUN | ICMP fwmark | 实际处理 |
|----------|-------------|-------------|----------|
| Redir-Host (非TUN) | ❌ | ✅ 标记 0x162 | 仅标记后放行，不经内核处理 |
| Fake-IP (非TUN) | ❌ | ✅ 标记 0x162 | 防火墙 REJECT Fake-IP 范围的 ping |
| Redir-Host TUN | ✅ | ✅ 标记 0x162 | 真实 IP → DIRECT 直连延迟 |
| Fake-IP TUN | ✅ | ✅ 标记 0x162 | 真实 IP → DIRECT 直连；Fake-IP → 伪造回复（~0ms 虚假延迟） |
| Redir-Host Mix | ✅ | ✅ 标记 0x162 | 同 Redir-Host TUN：ICMP 标记后经策略路由进入 TUN，DIRECT 直连 |
| Fake-IP Mix | ✅ | ✅ 标记 0x162 | 同 Fake-IP TUN：真实 IP → DIRECT 直连；Fake-IP → 内核伪造回复 |

> **实用提示**：如果用户发现 ping 不通但网页正常，首先确认不是 Fake-IP **非 TUN** 模式下在 ping 被代理的域名（Fake-IP 返回 `198.18.x.x`，防火墙直接 REJECT）。Fake-IP TUN/Mix 模式下 ping Fake-IP 地址会返回虚假 ~0ms 延迟。非 Fake-IP 的真实 IP ping 在 TUN/Mix 模式下走 DIRECT 直连，延迟反映的是本地网络质量。

**内核侧 ICMP 处理机制**（`github.com/metacubex/mihomo/listener/sing_tun/prepare.go` — Mihomo TUN 监听器）:

当 ICMP echo-request 经策略路由进入 TUN 虚拟网卡后，Mihomo 内核按以下优先级处理：

1. **目标是 Fake-IP 地址**（`resolver.IsFakeIP(addr)`） → 返回 `nil, nil`，内核用**伪造的 echo-reply** 回复。上层看到「ping 成功」但实际未经过网络，延迟显示为虚假的 ~0ms
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
> - `target=drop`：nat 链（`openclash`/`openclash_output`/`openclash_post`）中实际执行为 `return`（跳过代理、不丢包）；mangle 链（`openclash_mangle` 等）中为真正的 `drop`（丢弃报文）。
> - `user` 字段仅对 OUTPUT 链生效（路由器自身出站流量），入站流量不支持 UID 匹配；`iptables_compat`（无 owner match）时整条规则跳过并告警。
> - DSCP 匹配在 fw3 (iptables) 环境下需要 `iptables-mod-extra`（提供 DSCP 模块），如不可用会输出警告并跳过 DSCP 规则。

---

### 5.3 Tailscale（MagicDNS / `ts.net` / accept-dns）

> 关联：`04-firewall-chains.md` §4.2.1、`06-firewall-options-dnsmasq.md` §6.2、`16-overwrite-module-format.md` §16。
> 下文「stub」指 Tailscale DNS：v4 `100.100.100.100:53`，v6 `fd7a:115c:a1e0::53`。

#### 5.3.1 地址与行为

| 项 | 值 |
|---|---|
| MagicDNS | `<host>.ts.net`，由 tailscaled 的 tsdns 权威应答 |
| `accept-dns=on` | tailscaled 覆写 `/etc/resolv.conf`：`nameserver 100.100.100.100`、`nameserver fd7a:115c:a1e0::53`、`search <tailnet>.ts.net lan` |
| tailscaled 身份 | root（uid/gid 0），不享受 mihomo 的 `skgid 65534` 豁免 |
| `tailscale0` 区域 | tailscale 包默认加入 **lan** 区（`firewall.@zone[0].network='lan tailscale LAN6'`） |
| 出口节点 | 需 advertise `0.0.0.0/0`、`::/0` |

- 两种「100.100.100.100」要分清：`resolv.conf` 的 `nameserver` 是 tailscaled 管理的系统解析器；dnsmasq 的 `server=/ts.net/100.100.100.100` 是转发规则（GL.iNet 固件自动写入）。

#### 5.3.2 本机 DNS 规则

生效条件：`router_self_proxy=1` 且 `enable_redirect_dns=1|2`。实现：`add_router_dns_hijack_nft()` / `add_router_dns_hijack_iptables()`。

| 注释 | 匹配 | 动作 / 作用 |
|---|---|---|
| `OpenClash Router DNS Hijack` | 目标 `fib daddr type local`，:53 | REDIRECT → `DNSPORT`(mode1) / `dns_port`(mode2) |
| 同上 | 目标 `100.64.0.0/10`（v6 `fd7a:115c:a1e0::/48`），:53 | 同上 |
| 同上（mihomo 豁免） | `meta skgid != 65534`；fw3 `! --gid-owner 65534`；`iptables_compat` 用 `! --mark 0x1a0a` | 防 core 自环 |
| 同上，mode 1 加 dnsmasq 豁免（local 与私网两条都加） | `meta skuid != <dnsmasq uid>`；fw3 `-m owner ! --uid-owner <uid>`（uid 0 不豁免） | 防 dnsmasq 转发查询被劫持回自己 |
| `OpenClash Tailscale Stub Accept` | `-i lo -s <stub> -p udp`/`tcp --sport 53`，插在 `input` 首 | 放行 stub 反向 NAT 回包 |

- 每次启动先删自身旧规则再插入，`revert_firewall()` 按注释清理，restart 幂等（每族 udp+tcp 各 2 条）。
- INPUT 放行原因：`ts-input` 含 `! -i tailscale0 -s 100.64.0.0/10 -j DROP`，会丢掉回包 → v4 冷解析卡 5s（v6 无此 DROP）。
- uid 豁免会被跳过的情况：`iptables_compat`（无 owner match）、dnsmasq 以 root 运行。此时 mode 1 自环仍存在，改用 mode 2。

`nat_output` 劫持规则的通用形态见 `04-firewall-chains.md` §4.2.1；Tailscale 专属的是 INPUT 回包放行：

```bash
# nft (fw4)；v6 把 ip/100.100.100.100 换成 ip6/fd7a:115c:a1e0::53
nft insert rule inet fw4 input position 0 iifname "lo" \
  ip saddr 100.100.100.100 udp sport 53 counter accept comment "OpenClash Tailscale Stub Accept"
nft insert rule inet fw4 input position 0 iifname "lo" \
  ip saddr 100.100.100.100 tcp sport 53 counter accept comment "OpenClash Tailscale Stub Accept"

# iptables (fw3)；v6 用 ip6tables + -s fd7a:115c:a1e0::53
while iptables -t filter -C INPUT -i lo -s 100.100.100.100 -p udp --sport 53 \
  -j ACCEPT -m comment --comment "OpenClash Tailscale Stub Accept" 2>/dev/null; do
  iptables -t filter -D INPUT -i lo -s 100.100.100.100 -p udp --sport 53 \
    -j ACCEPT -m comment --comment "OpenClash Tailscale Stub Accept"
done
iptables -t filter -I INPUT 1 -i lo -s 100.100.100.100 -p udp --sport 53 \
  -j ACCEPT -m comment --comment "OpenClash Tailscale Stub Accept"
```

#### 5.3.3 `ts.net` 解析路径与内置覆写模块

| 场景 | core 收到 `ts.net` 查询 | 需要的配置 |
|---|---|---|
| mode 1 + dnsmasq `server=/ts.net/<stub>` + uid 豁免生效 | 否 | 无 |
| mode 2 | 是 | 启用内置 `Tailscale` 覆写模块 |
| mode 1，但 dnsmasq 无 `server=/ts.net/...` | 是 | 同上 |
| 客户端直接查 core DNS（DoH、面板、curl） | 是 | 同上 |

- 模块：`root/etc/openclash/overwrite/Tailscale`，`config_overwrite` 的 `name Tailscale`，默认 `enable 0`，`order 3`；内容 `dns.nameserver-policy+` → `'+.ts.net': ['100.100.100.100#DIRECT']`。
- `#DIRECT`：`respect-rules: true` 时避免 core→stub 的查询被代理规则接管。
- 答案类型：模块路径 fake-ip；uid 豁免路径真实 `100.x`。要统一为真实 IP 时给 core 加 `fake-ip-filter: ['ts.net']`。

#### 5.3.4 localnetwork / localnetwork6

- 默认 `localnetwork` 含 `100.64.0.0/10`、`localnetwork6` 含 `fd7a:115c:a1e0::/48`，只作**目的地址**豁免（`ip daddr @localnetwork return`），不按源地址豁免；tailnet 客户端访问公网仍会被代理。
- `lan_ac_*` 是独立集合，默认不含 tailnet 网段；把 `100.64.0.0/10` 加入黑名单会让 tailnet 客户端跳过代理。

#### 5.3.5 外部设备用本机代理 / 出口节点

代理（`port` 7890、`socks-port` 7891、`mixed-port` 7893）：

1. 开 `allow-lan`，`bind-address: "*"`（否则只监听 `127.0.0.1`）。
2. 客户端填 `http://<tailnet ip>:7890` 或 `socks5h://<tailnet ip>:7891`，并填 `authentication` 账号密码（无认证：HTTP `407`、SOCKS5 拒绝用户）。
3. 防火墙无需改动：`tailscale0` 在 lan 区按 LAN INPUT 放行；`intranet_allowed` 只限 WAN 区。

实测（oc125 `100.113.118.42` → oc140 `100.120.79.48`）：带认证三个端口均 `204`，无认证被拒，代理出口 IP ≠ 直连出口 IP，连接面板 `chains: Speedtest → Proxy → Smart → 节点`。

出口节点：

1. 本机 advertise `0.0.0.0/0`、`::/0`；客户端 `tailscale up --exit-node=<本机 tailnet IP> --exit-node-allow-lan-access`。
2. 依赖 `ip_forward=1`、`ts-forward`（来自 tailscale0 打标 `0x40000` 并 ACCEPT）、`ts-postrouting`（MASQUERADE）；OpenClash 的 PREROUTING 对所有非 WAN 接口生效。
3. 注意 `lan_ac_mode=1` 白名单会跳过 tailnet 源；`bypass_gateway_compatible=1` 的 SNAT 排除 mark `0x162`。
4. 验证：`tailscale status` 显示 `offers exit node`、客户端 `curl ifconfig.me` 为路由器出口 IP、面板看到源 `100.x` 的连接。

#### 5.3.6 与其他 overlay 软件的关系（ZeroTier / EasyTier 等）

- 本机规则只匹配两类目标：**路由器自身地址** :53 与 `100.64.0.0/10`（v6 `fd7a:115c:a1e0::/48`）。ZeroTier 等把 DNS 指向路由器自身地址（zt 接口 IP、LAN IP）时，mode 1 下已由 dnsmasq uid 豁免覆盖，无需额外规则；指向私网内其他主机且不在上述网段时规则不匹配，也不受影响。
- 需要额外处理的只有**自己往 INPUT/FORWARD 塞 DROP** 的软件（已知：Tailscale `ts-input` 的 `! -i tailscale0 -s 100.64.0.0/10 -j DROP`）；ZeroTier 不加此类规则。遇到时补一条 `-i lo -s <该 DNS IP> -p udp`/`tcp --sport 53 -j ACCEPT`（注释含 `OpenClash`，停止时由 `revert_firewall` 清理），v4/v6 分开。
- 内核内置出站都是用户态：`tailscale` / `easytier` 有进程内 DNS（`ts://<出站名>`、`et://<出站名>`），`zerotier` 无内置 DNS（照常走 nameserver）；三者都不建网络接口、不发主机 DNS socket，不受本节规则影响。
- 既有约束：`localnetwork` 含 `100.64/10` 且按目的地址豁免 → redir-host 模式下 LAN 客户端访问真实 `100.x` 不进 core；ZeroTier 网段若落在 `localnetwork`（如 `10/8`）同理。

#### 5.3.7 安全要点

- INPUT 放行范围最小：`lo` + 精确 stub 源 + `sport 53`；`route_localnet=0` 时外部无法伪造该源。
- uid 豁免只影响 dnsmasq 自身出站私网 DNS，uid 0 不豁免。
- 代理端口暴露源于 `allow-lan` + lan 区含 `tailscale0`（既有行为）：保持 `authentication`，用 Tailscale ACL 限制来源。
- 出口节点会扩大信任边界，用 ACL 限制可使用成员。

#### 5.3.8 排查

| 现象 | 检查 |
|---|---|
| v4 冷解析 5s / stub 超时 | `iptables -S INPUT | grep 'Tailscale Stub Accept'` 是否在 `-j ts-input` 之前 |
| `ts.net` NXDOMAIN | 模块是否 enable；mode 1 下 dnsmasq 有 `server=/ts.net/...`；`grep -A2 ts.net /etc/openclash/config.yaml` |
| dnsmasq 并发堆积 / `ts.net` 卡死 | 私网规则是否带 uid 豁免；是否 `iptables_compat` |
| 代理 `407` / SOCKS 拒绝 | 客户端未填 `authentication` |
| tailnet 客户端连不上代理端口 | `tailscale0` 是否在 lan 区、INPUT 规则、Tailscale ACL |
| 出口节点不生效 | `ip_forward`、`ts-forward`/`ts-postrouting`、`lan_ac_mode`、连接面板来源 |

#### 5.3.9 相关文件

- `root/etc/init.d/openclash`：`add_router_dns_hijack_nft()` / `add_router_dns_hijack_iptables()`
- `root/etc/openclash/overwrite/Tailscale`；`root/etc/config/openclash`（`config_overwrite` 的 Tailscale 条目）
- 相关选项：`router_self_proxy`、`enable_redirect_dns`、`intranet_allowed`、`bypass_gateway_compatible`、`lan_ac_mode`、`enable_custom_domain_dns_server`

### 5.4 与 mwan3 共存（多 WAN 分流）

> 关联：`04-firewall-chains.md` §4.3（策略路由辅助规则）。

代理标记规则由 init.d 固定为 `pref 999`（fake-ip6 的 `iif lo` 为 `pref 998`），不要改回默认值或 1888。

**各模式覆盖**

| 模式 | mihomo 出站能否被 mwan3 分流 |
|---|---|
| `fake-ip` / `redir-host` × 非 TUN / TUN / Mix | 能。出站是 OUTPUT，走 mwan3 的 `mangle OUTPUT → mwan3_hook` |
| IPv6（`ipv6_mode` 0/1/2/3） | 能。需在 mwan3 里也配置 v6 接口/成员 |
| `iptables_compat`（fw3 且无 `xt_owner`） | **不能**。mihomo 被写入 `routing-mark: 6666`，`0x1a0a & 0x3f00 ≠ 0` → mwan3 跳过分类，且无匹配的 `ip rule` → 走 main 表 |

**mwan3 侧需要的设置**

1. 至少两个接口，各自有独立网关（`config interface` + `option interface <netifd 接口名>`），并开启 tracking（`track_ip`）。
2. 每个 WAN 一个 `config member`；`weight` 决定分流比例（模板里 `wan_m1_w3` 权重 3，新加的 weight 1 就是 3:1）。
3. `config policy` 引用这些 member，`config rule` 的 `dest_ip 0.0.0.0/0` 指向该 policy（默认已有 `default_rule_v4`）。
4. 要真正均衡，rule 的 `sticky` 必须为 `0`：`sticky 1` 按**源 IP** 粘滞，而 mihomo 出站源是路由器本身 → 会全部固定在一个 WAN。
5. 不要把代理节点 IP 放进 mwan3 的 connected / custom 集合，否则被判为直连、走 main 表。

**生效范围**

- 分流只发生在「mihomo 出站」这一层：客户端 → OpenClash 的流在本地终结，mwan3 按客户端源 IP/入接口的策略对它无效；按客户端分流请用 OpenClash 的策略组。
- 被 `return` 掉、不进内核的转发流量（绕过大陆、黑名单等）仍由 mwan3 正常分流。

**故障对照**

| 现象 | 原因 |
|---|---|
| 开 mwan3 后 UDP/QUIC 不通，TCP/DNS 正常；`openclash_mangle` 的 tproxy 计数在涨但 mihomo 无 `[UDP]` 日志 | mwan3 的 `fwmark 0x100/0x3f00 lookup N`（`pref 2001+`）会命中 OpenClash 的 `0x162`（`0x162 & 0x3f00 = 0x100`）；不写 `pref` 时本规则落在 32765，被抢走 |
| mwan3 执行 stop/restart 后问题复现 | `mwan3_delete_iface_rules` 会删掉 `1000 < pref < 4000` 的规则（条件 `pref % 1000 == iface id`），1888 正好在区间内 |

### 5.5 Docker 网桥与 UDP TPROXY

IPv4：`docker0` 存在、`en_mode_tun` 为空且 `enable_udp_proxy=1` 时，先设 `nf_call_iptables=1`，成功后才把全局 `bridge-nf-call-iptables` 设为 `0`。IPv6：`ipv6_enable=1`、`enable_v6_udp_proxy=1` 且 `ipv6_mode=0/1` 时，同样处理 `nf_call_ip6tables` 与 `bridge-nf-call-ip6tables`。

只处理 `docker0`；全局值影响所有网桥。停止 OpenClash 或切换模式不会恢复这些值。

> 让某个接口（如 `docker0`）的流量完全绕过内核，用「来源流量控制」规则：见 `10-settings-geo-misc-src.md` §10.3。


