## 防火墙选项影响、fw3 等效链与 Dnsmasq 修改

> **用途**: 各选项对防火墙规则的影响速查（§6.2）、fw3 等效链（§6.1）、Dnsmasq 劫持实现（§6.3）与重绑定保护（§6.4）。完整链结构与顺序见 `04-firewall-chains.md` §4.2。
> **实现**: `init.d/openclash` 的 `set_firewall()` 与 `change_dnsmasq()`。

### 6.1 fw3 (iptables/ipset) 等效链

| iptables 链 | 表 | 等效 nftables 链 |
|-------------|-----|-----------------|
| `openclash` | `nat` | `inet fw4 openclash`（TCP） |
| `openclash` | `mangle` | `inet fw4 openclash_mangle`（UDP） |
| `openclash_output` | `nat` | `inet fw4 openclash_output`（TCP） |
| `openclash_output` | `mangle` | `inet fw4 openclash_mangle_output`（UDP） |
| `openclash_post` | `nat` | `inet fw4 openclash_post` |
| `openclash_wan_input` | `filter` | `inet fw4 openclash_wan_input` |
| `openclash_dns_redirect` | `nat` | `inet fw4 openclash_dns_redirect` |
| `openclash_upnp` | `mangle` | `inet fw4 openclash_upnp` |

**fw3 兼容层**（自动检测 iptables 是否支持 owner 模块）：支持时用 `owner="-m owner --gid-owner 65534"` / `noowner="-m owner ! --gid-owner 65534"`；不支持时回退按 fwmark 匹配 `-m mark --mark 0x1a0a` / `-m mark ! --mark 0x1a0a`。

**fw3 典型规则（REDIRECT / TPROXY）**：

```bash
# TCP
iptables -t nat -N openclash
iptables -t nat -A openclash -m set --match-set localnetwork dst -j RETURN
iptables -t nat -A openclash -p tcp -d 198.18.0.0/16 -j REDIRECT --to-ports 7892
iptables -t nat -A openclash -p tcp -m set ! --match-set common_ports dst -j RETURN
iptables -t nat -A openclash -p tcp -j REDIRECT --to-ports 7892
iptables -t nat -A PREROUTING -p tcp -j openclash

# UDP
iptables -t mangle -N openclash
iptables -t mangle -A openclash -p udp -m set --match-set localnetwork dst -j RETURN
iptables -t mangle -A openclash -p udp -j TPROXY --on-port 7895 --tproxy-mark 0x162
iptables -t mangle -A PREROUTING -p udp -j openclash
```

### 6.2 各选项对防火墙规则的影响

| 选项 | 值 | 规则变化 |
|------|---|----------|
| `china_ip_route` | `0`（默认） | 不生成绕行规则 |
| | `1` 绕过大陆 | 代理规则前插 `ip daddr @china_ip_route [ip daddr != @china_ip_route_pass] counter return`（国内 IP 跳过代理；`enable_redirect_dns != 2` 时附 chnroute_pass 排除） |
| | `2` 绕过海外 | 同上但条件取反 `ip daddr != @china_ip_route` |
| `china_ip6_route` | `0` / `1` / `2` | IPv6 等效规则（`ip6 daddr`，同上三种） |
| `disable_udp_quic` | `1` | 所有模式在 INPUT/FORWARD 插 `udp dport 443` REJECT，按 `china_ip_route`/`china_ip6_route` 匹配或排除国内 IP；TUN 模式额外在 `forward oifname utun` 插同规则；IPv6 同样处理。仅依赖本选项，与 `enable_udp_proxy` 无关。**内核自身 QUIC（Hysteria、DNS h3 等）不受影响**（内核出站走 OUTPUT 链，且回复目标为临时端口） |
| `lan_ac_mode` | `0` 黑名单 | 建 `lan_ac_black_ips`/`_macs`/`_ipv6s` set，命中即 RETURN；DNS 劫持规则同步过滤黑名单设备 |
| | `1` 白名单 | 建 `lan_ac_white_*` set，**未命中**即 RETURN（反逻辑）；DNS 劫持仅对白名单设备生效 |
| `common_ports` | 非 0 | 插 `th dport != @common_ports counter return`，仅代理指定端口（P2P/BT 绕过）；仅 redir-host 生效。预设 21-23,53,80,123,143,194,443,465,587,853,993,995,998,2052-2053,2082-2083,2086,2095-2096,2197,5222-5223,5228-5230,8080,8443,8880,8888-8889 |
| `router_self_proxy` | `1` | 建 `openclash_output` + `openclash_mangle_output`，路由器自身流量被重定向/标记；非 TUN 的 Fake-IP 模式即使关闭也会为 Fake-IP 流量建 OUTPUT 链 |
| | `0` | 删除 OUTPUT 链，路由器自身流量走原始路由 |
| `intranet_allowed` | `1` | WAN 区存在时始终建 `openclash_wan_input` 并拒绝 `mark 0x162`；开启时追加 `ct status dnat th dport {...} reject` 与代理端口 dport reject。端口：`proxy_port` 7892、`tproxy_port` 7895、`cn_port` 9090、`http_port` 7890、`socks_port` 7891、`mixed_port` 7893、`dns_port` 7874 |
| | `0` | 仅保留 `mark 0x162` 拒绝（拦截 WAN 侧被 TPROXY 的流量），不再拒绝端口转发/DNAT 入站 |
| `bypass_gateway_compatible` | `1` | IPv4 建 `openclash_post`（从 `srcnat`/`POSTROUTING` jump），顺序：`skgid == 65534 return` → `mark 0x162 accept`（已标记的代理流量不 SNAT）→ `ip daddr @localnetwork return` → `ct direction reply return` → `fib saddr type != local masquerade`（只 SNAT 源地址非本机的转发流量）。IPv6 对应 `openclash_post_v6` |
| `skip_proxy_address` | `1` | 看门狗调 `skip_proxies_address()`，经内核 API 解析节点 `server` 后加入 `localnetwork` set，复用链首 RETURN 防代理嵌套 |
| `enable_redirect_dns` | `1` | IPv4+IPv6 在 `dstnat` 插 53 端口 REDIRECT 到 dnsmasq 端口（含 AC 黑白名单过滤）；`router_self_proxy=1` 时加 OUTPUT DNS 劫持（本机地址 + Tailscale 私网 `100.64.0.0/10`/`fd7a:115c:a1e0::/48`，私网规则对 dnsmasq 进程豁免）；INPUT 链首放行 Tailscale stub 回包 |
| | `2` | 建 `openclash_dns_redirect` 链，IPv4+IPv6 DNS 直接 DNAT 到 `dns_port`(7874)；同样支持 AC 过滤与 OUTPUT 劫持（不豁免 dnsmasq）；INPUT 同样放行 Tailscale stub 回包 |
| `local_network_pass` | 已配置 | 建 `localnetwork` set（默认 `0.0.0.0/8`、`127.0.0.0/8`、`10.0.0.0/8`、`169.254.0.0/16`、`192.168.0.0/16`、`224.0.0.0/4`、`240.0.0.0/4`、`172.16.0.0/12`、`100.64.0.0/10`），所有链首位 RETURN；自定义文件覆盖默认；WAN 接口 IP 自动加入 |
| `chnroute_pass` | 已配置 | 建 `china_ip_route_pass` set，供 dnsmasq 把指定域名的解析 IP 加入，作为 `china_ip_route` 的排除条件；仅 `enable_redirect_dns != 2` 生效（依赖 dnsmasq） |
| UPNP 流量排除 | 已装 upnpd | 建 `openclash_upnp` 链，`upnp_exclude()` 遍历租约按 `saddr + sport + protocol` 加 RETURN；看门狗自动同步 |
| `ipv6_enable` | `1` | 建完整 IPv6 链：`openclash_v6`（TCP REDIRECT，`ipv6_mode=1/3`）、`openclash_mangle_v6`（UDP TPROXY/TUN fwmark）、`openclash_output_v6`/`openclash_mangle_output_v6`、`openclash_post_v6`、`openclash_wan_input` |
| `local_network6_pass` | 已配置 | 建 IPv6 `localnetwork6` set（默认 `::/128`、`::1/128`、`fe80::/10`、`ff00::/8` 等），匹配本地 IPv6 段 RETURN；WAN IPv6 地址自动加入 |
| ICMP（无选项） | 非 TUN | echo-request 仅打 fwmark `0x162` 后 accept，**不被代理**；Fake-IP 非 TUN 下对 `198.18.0.0/16` 的 ping 在 INPUT/FORWARD/OUTPUT 三链 REJECT（OUTPUT 对 `skgid != 65534` 生效，OpenClash 自身 65534 除外），见 `05-firewall-special.md` §5.1 |
| | TUN / Mix | ICMP 打标记后经策略路由进 TUN（真实 IP → DIRECT 延迟，Fake-IP → 伪造回复 ~0ms）；可用 `disable-icmp-forwarding` 禁用 |
| `firewall_lan_ac_traffic` | 已配置 | `lan_ac_traffic` sections 按设备/协议/端口/DSCP 精确控制，每条插到对应链 position 0，支持 `return`/`accept`/`drop`，见 `05-firewall-special.md` §5.2 |

**旁路由的回程与「IP 动态伪装」**（`bypass_gateway_compatible` 默认 0）：

- 被代理流量由旁路由本机发起（源 = 旁路由在上游子网的地址），上游天然能回程，与 SNAT 无关
- 绕过代理的流量（`china_ip_route`、黑白名单、`common_ports`、非代理端口）RETURN 后按普通转发，**源 IP 仍是客户端地址**；上游不认该网段（客户端挂在旁路由自己的 LAN/WLAN）或有 ARP 绑定/客户端隔离/防二级路由时回包被丢弃 → 症状是**代理站点正常、国内直连站点一直转圈**
- 修法：① 模式设置 →「旁路网关兼容」= IPv4+IPv6 双栈开关，只 SNAT 源地址非本机的转发流量；② 防火墙区域的「IP 动态伪装」，`masq` 只覆盖 IPv4、`masq6` 只覆盖 IPv6（只修一侧时用②）
- 性能：SNAT 只在每条流首包生效，转发 + NAT ≈ 线路速率，不是瓶颈（对比见 `08-settings-mode-traffic.md` §8.2.13）；省开销应改代理模式或开 `gso`，不要关伪装
- 彻底不做 NAT：上游加静态路由（客户端网段 → 旁路由），或客户端与出口同子网（扁平组网）

**旁路由的 IPv6 同理**：

- IPv6 默认无 NAT：区域「IP 动态伪装」只覆盖 IPv4，IPv6 需 `firewall.@zone[].masq6='1'`；插件侧 `bypass_gateway_compatible=1` 建 `openclash_post_v6`（逻辑同 IPv4），默认 0，两种方式任选其一
- 是否需要 SNAT 看客户端前缀：来自上游可路由前缀（ISP 下发 /64，与主路由同 on-link）→ 不需 NAT66；来自旁路由私有前缀（ULA `fd**::/8` 或旁路由 DHCPv6）→ 必须 NAT66。判定：客户端 `ip -6 route get <国内 IPv6 目标>` 看 `src`
- **RA 卫生**：同一二层网段只应有一个 RA 源。旁路由应 `dhcp.lan.ra='relay'`、`dhcp.lan.dhcpv6='relay'`（或直接关闭），只保留主路由宣告 ISP 前缀；多 RA 源会导致「IPv6 时通时断 / 有时绕过代理」
- 辨识：IPv4 正常、部分国内双栈站点打不开或极慢，先查本节；要代理 IPv6 需 `ipv6_enable=1` + `china_ip6_route`（配 `chnr6_custom_url`）。客户端侧做法见 `09-settings-dns-ac-ipv6.md` §9.5.1

### 6.3 Dnsmasq 修改（`change_dnsmasq` / `revert_dnsmasq`）

仅在 `enable_redirect_dns=1` 时执行 `change_dnsmasq()`：

1. **备份原值**：`save_dnsmasq_server()` 把原 `server` 列表存入 `openclash.config.dnsmasq_server`；`noresolv` / `resolvfile` / `cachesize` 存入 `openclash.config.dnsmasq_*`
2. **重定向 DNS**：清空 `dhcp.@dnsmasq[-1].server` → 添加 `127.0.0.1#$dns_port` → 删 `resolvfile`，设 `noresolv=1`、`localuse=1`、`cachesize=0`
3. **IPv6 DNS**：`ipv6_dns=1` 时设 `filter_aaaa=0`（保留 AAAA）
4. **chnroute_pass**：`load_ip_route_pass()` 建 `china_ip_route_pass` set，把 `openclash_custom_chnroute_pass.list` 与 UCI `china_ip_route_pass` 的域名加入（`ipset=/domain/set` 或 `nftset=/domain/4#inet#fw4#china_ip_route_pass`），使这些域名的解析 IP 可跳过绕行规则
5. **自定义域名 DNS**：执行 `/usr/share/openclash/openclash_custom_domain_dns.sh`
6. **重启**：`/etc/init.d/dnsmasq restart`

`revert_dnsmasq()`：删注入的 server → 逐条恢复原 `server` 列表 → 还原 `noresolv`/`resolvfile`/`cachesize`（及 `filter_aaaa`）→ 用 `nslookup www.apple.com 127.0.0.1:<port>` 验证，失败则创建 fallback resolv.conf（114.114.114.114 / 8.8.8.8）。

### 6.4 Dnsmasq 重绑定保护（`rebind_protection`）

系统 dnsmasq 的开关（`dhcp.@dnsmasq[0]`），插件不读写。开启时丢弃上游应答中指向保留地址的记录；Mihomo 的 `hosts`（覆写设置 → DNS → Hosts）与 Fake-IP 的 IPv6 池恰好返回这类地址 ⇒ 相关域名客户端解析不到。

| UCI 选项 | 默认 | dnsmasq 参数 | 作用 |
|---|---|---|---|
| `rebind_protection` | `1` | `--stop-dns-rebind` | 丢弃上游应答中的保留地址 |
| `rebind_localhost` | 视固件为 `1` 或未设置（未设置 = `0`） | `--rebind-localhost-ok` | 额外放行 `127.0.0.1` / `::1` |
| `rebind_domain`（列表） | 空 | `--rebind-domain-ok=<域名>` | 白名单，整域放行 |

**被丢弃的地址范围**（dnsmasq 2.93）：

| 类别 | 地址 | 处理 |
|---|---|---|
| IPv4 私网/链路本地 | `10.0.0.0/8`、`172.16.0.0/12`、`192.168.0.0/16`、`169.254.0.0/16` | 丢弃 |
| IPv4 文档/测试网段 | `192.0.2.0/24`、`198.51.100.0/24`、`203.0.113.0/24`、`255.255.255.255` | 丢弃 |
| IPv6 ULA/链路本地/站点本地 | `fc00::/7`、`fe80::/10`、`fec0::/10` | 丢弃 |
| IPv4-mapped IPv6（内嵌私网） | `::ffff:192.168.1.1` | 丢弃 |
| 本机地址 | `127.0.0.1`、`::1` | `rebind_localhost=1` 放行，`0` 丢弃 |
| 其它 | `198.18.0.0/16`（Fake-IP 的 IPv4 池）、`0.0.0.0`、`192.0.0.1`、公网地址 | 放行 |

- **整条应答一起丢弃**：只要有一条地址落入上表（如同应答同时含公网与 `192.168.x.x`），整条不返回——客户端得到「无记录」而非 NXDOMAIN
- **对任意上游生效**：包括 `127.0.0.1#7874`（Mihomo）；仅 `enable_redirect_dns=2` 时客户端 DNS 不经 dnsmasq，不受影响
- **日志**：`logread | grep DNS-rebind` 命中 `possible DNS-rebind attack detected: <域名>`

**受影响场景**:

| 场景 | 现象 | 做法 |
|---|---|---|
| Hosts 把域名指向内网地址 | 该域名无地址，其余正常 | 域名加入白名单，或关重绑定保护 |
| Fake-IP + IPv6（`ipv6_dns=1`） | 只有 IPv4 地址、IPv6 访问失败 | Fake-IP 的 IPv6 池是 ULA（`fdfe:dcba:9876::/64` 一类）⇒ 同上，或按 `09-settings-dns-ac-ipv6.md` §9.5.1 关闭 IPv6 DNS |
| 内网自建 DNS / NAS / `.lan` 域名返回私网地址 | 仅这些域名失败 | 域名加入白名单 |
| 启动日志提示 `You May Need to Turn off The Rebinding Protection Option of Dnsmasq When Hosts Has Set a Reserved Address...` | Hosts 含保留地址 | 本节问题 |

**做法**（LuCI：网络 → DHCP/DNS → 常规设置 → 「重绑定保护」/「域名白名单」）：

```bash
# 白名单（保留防护）
uci add_list dhcp.@dnsmasq[0].rebind_domain='example.com'
uci commit dhcp && /etc/init.d/dnsmasq restart

# 关闭重绑定保护（失去该防护）
uci set dhcp.@dnsmasq[0].rebind_protection='0'
uci commit dhcp && /etc/init.d/dnsmasq restart
```

**自查**：客户端 `nslookup <域名>` 无返回，且设备 `logread` 命中该域名。
