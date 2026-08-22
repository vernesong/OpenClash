## 防火墙选项影响、fw3 等效链与 Dnsmasq 修改

> **用途**: 各选项对防火墙规则的影响速查表、fw3 等效链与 Dnsmasq 劫持实现（§6.1–6.3）。

> **AI 行为指引**: 当用户询问「改哪个 UCI 选项会生成什么防火墙规则」「fw3 与 fw4 后端差异」「DNS 劫持的 dnsmasq 实现」时，AI 应结合本文件（§6.2 选项→规则映射、§6.3 Dnsmasq）与 `04-firewall-chains.md`（§4.2 链结构）回答，说明选项如何影响 `set_firewall()` 生成的规则链，而非仅给出选项说明。涉及实现细节时查阅 [OpenClash 源码](https://github.com/vernesong/OpenClash/tree/dev) 中 `init.d/openclash` 的 `set_firewall()` 与 `change_dnsmasq()` 函数。

### 6.1 fw3 (iptables/ipset) 等效链

| iptables 链 | 表 | 等效 nftables 链 |
|-------------|-----|-----------------|
| `openclash` | `nat` | `inet fw4 openclash` (TCP) |
| `openclash` | `mangle` | `inet fw4 openclash_mangle` (UDP) |
| `openclash_output` | `nat` | `inet fw4 openclash_output` (TCP) |
| `openclash_output` | `mangle` | `inet fw4 openclash_mangle_output` (UDP) |
| `openclash_post` | `nat` | `inet fw4 openclash_post` |
| `openclash_wan_input` | `filter` | `inet fw4 openclash_wan_input` |
| `openclash_dns_redirect` | `nat` | `inet fw4 openclash_dns_redirect` |
| `openclash_upnp` | `mangle` | `inet fw4 openclash_upnp` |

**fw3 兼容性层** — 自动检测 iptables 是否支持 owner/gid 模块:
```bash
if iptables 不支持 owner 模块; then
    owner="-m mark --mark 0x1a0a"     # 回退: 按 fwmark 匹配
    noowner="-m mark ! --mark 0x1a0a"
else
    owner="-m owner --gid-owner 65534" # 标准: owner 模块
    noowner="-m owner ! --gid-owner 65534"
fi
```

**示例 fw3 REDIRECT (TCP)**:
```bash
iptables -t nat -N openclash
iptables -t nat -A openclash -m set --match-set localnetwork dst -j RETURN
iptables -t nat -A openclash -p tcp -d 198.18.0.0/16 -j REDIRECT --to-ports 7892
iptables -t nat -A openclash -p tcp -m set ! --match-set common_ports dst -j RETURN
iptables -t nat -A openclash -p tcp -j REDIRECT --to-ports 7892
iptables -t nat -A PREROUTING -p tcp -j openclash
```

**示例 fw3 TPROXY (UDP)**:
```bash
iptables -t mangle -N openclash
iptables -t mangle -A openclash -p udp -m set --match-set localnetwork dst -j RETURN
iptables -t mangle -A openclash -p udp -j TPROXY --on-port 7895 --tproxy-mark 0x162
iptables -t mangle -A PREROUTING -p udp -j openclash
```

---

### 6.2 各选项对防火墙规则的具体影响

| 选项 | 值 | 防火墙规则变化 |
|------|---|---------------|
| **`china_ip_route`** (实验性：绕过指定区域 IP / China IP Route) | `1` (绕过大陆) | 在代理规则前插入 `ip daddr @china_ip_route [ip daddr != @china_ip_route_pass] counter return` — 目标为国内 IP 的流量跳过代理（若 `enable_redirect_dns != 2` 则附加 chnroute_pass 排除） |
| | `2` (绕过海外) | 插入 `ip daddr != @china_ip_route [ip daddr != @china_ip_route_pass] counter return` — 目标非国内 IP 的流量跳过代理 |
| **`china_ip6_route`** (实验性：绕过指定区域 IPv6 / China IPv6 Route) | `1` (绕过大陆) | IPv6 等效规则：`ip6 daddr @china_ip6_route [ip6 daddr != @china_ip6_route_pass] counter return` |
| | `2` (绕过海外) | IPv6 等效规则：`ip6 daddr != @china_ip6_route [ip6 daddr != @china_ip6_route_pass] counter return` |
| **`disable_udp_quic`** (禁用 QUIC / Disable QUIC) | `1` | 全部模式在 INPUT/FORWARD 链插入 QUIC REJECT 规则 (`udp dport 443`，根据 `china_ip_route`/`china_ip6_route` 匹配或排除中国 IP)。TUN 模式额外在 `forward oifname utun` 插入同规则以覆盖经 utun 转发的流量。IPv6 同样处理。规则触发仅依赖 `disable_udp_quic`，与 `enable_udp_proxy`/`enable_v6_udp_proxy` 无关。Mihomo 内核自身 QUIC（如 Hysteria 节点、DNS h3）不受影响——内核出站走 OUTPUT 链，不在规则范围内 |
| **`lan_ac_mode`** (局域网访问控制模式 / LAN Access Control Mode) | `0` (黑名单) | 创建 `lan_ac_black_ips`/`lan_ac_black_macs`/`lan_ac_black_ipv6s` set，匹配到的 RETURN 跳过代理。DNS 劫持规则同步过滤黑名单设备 |
| | `1` (白名单) | 创建 `lan_ac_white_ips`/`lan_ac_white_macs`/`lan_ac_white_ipv6s` set，**不匹配**的 RETURN 跳过代理（反逻辑）。DNS 劫持规则仅对白名单设备生效 |
| **`common_ports`** (仅允许常用端口流量 / Common Ports Proxy Mode) | `非0` | 插入 `th dport != @common_ports counter return` — 仅代理指定端口，P2P/BT 端口被绕过。仅 redir-host 模式生效。预设常用端口: 21-23,53,80,123,143,194,443,465,587,853,993,995,998,2052-2053,2082-2083,2086,2095-2096,2197,5222-5223,5228-5230,8080,8443,8880,8888-8889 |
| **`router_self_proxy`** (路由本机代理 / Router-Self Proxy) | `1` | 创建 OUTPUT 链 (`openclash_output` + `openclash_mangle_output`)，路由器自身流量被重定向/标记。非 TUN 模式额外对 Fake-IP 模式始终创建 OUTPUT 链（即使用户关闭 router_self_proxy） |
| | `0` | 删除 OUTPUT 链，路由器自身流量走原始路由 |
| **`intranet_allowed`** (仅允许内网 / Only Intranet Allowed) | `1` | IPv4: 创建 `openclash_wan_input` 链，REJECT 来自 WAN 口对全部服务端口的访问。IPv6: 创建 `openclash_wan6_input` 链。服务端口: `$proxy_port`(7892)、`$tproxy_port`(7895)、`$cn_port`(9090)、`$http_port`(7890)、`$socks_port`(7891)、`$mixed_port`(7893)、`$dns_port`(7874) |
| **`bypass_gateway_compatible`** (旁路网关（旁路由）兼容 / Bypass Gateway Compatible) | `1` | IPv4: 创建 `openclash_post` 链 (srcnat jump)，对已标记流量执行 MASQUERADE SNAT。规则: skgid return → mark accept → localnetwork return → ct reply return → fib saddr 非 local masquerade。IPv6: 对应创建 `openclash_post_v6` 链 |
| **`skip_proxy_address`** (绕过服务器地址 / Skip Proxy Address) | `1` | 看门狗定时调用 `skip_proxies_address()` 通过内核 API 解析代理节点 `server` 地址并加入 `localnetwork` nft set，复用链首 RETURN 规则跳过代理，防止代理嵌套 |
| **`enable_redirect_dns`** (本地 DNS 劫持 / Redirect Local DNS Setting) | `1` | IPv4+IPv6 在 `dstnat` 插入 DNS 53 端口 REDIRECT 规则到 dnsmasq 端口。AC 黑白名单设备过滤。`router_self_proxy=1` 时添加 OUTPUT DNS 劫持 |
| | `2` | 创建 `openclash_dns_redirect` 链，IPv4+IPv6 DNS 流量直接 DNAT 到 `dns_port`(7874)。同样支持 AC 过滤和 OUTPUT 劫持 |
| **`local_network_pass`** (本地 IPv4 绕过地址 / Local IPv4 Network Bypassed List) | 已配置 | 创建 `localnetwork` nft set (默认: 0.0.0.0/8, 127.0.0.0/8, 10.0.0.0/8, 169.254.0.0/16, 192.168.0.0/16, 224.0.0.0/4, 240.0.0.0/4, 172.16.0.0/12, 100.64.0.0/10)，在所有链规则首位匹配 RETURN。自定义文件可覆盖默认值。WAN 接口 IP 自动加入 |
| **`chnroute_pass`** (绕过指定区域 IPv4 黑名单 / Chnroute Bypassed List) | 已配置 | 创建 `china_ip_route_pass` nft set / ipset，配合 dnsmasq 将指定域名解析的 IP 加入 set。防火墙规则中作为 `china_ip_route` 的排除条件（确保这些 IP 不被绕行规则跳过）。仅在 `enable_redirect_dns != 2` 时生效（依赖 dnsmasq） |
| **UPNP 流量排除**（无 UCI 选项，自动检测 `/etc/config/upnpd` 租约文件） | 系统已安装 upnpd | 创建 `openclash_upnp` 链，`upnp_exclude()` 遍历 upnpd 租约文件，按 `saddr + sport + protocol` 三元组为每个映射添加 RETURN 规则。看门狗自动同步变更 |
| **`ipv6_enable`** (IPv6 流量代理 / Proxy IPv6 Traffic) | `1` | 创建完整 IPv6 防火墙链：`openclash_v6`(TCP REDIRECT, ipv6_mode=1/3)、`openclash_mangle_v6`(UDP TPROXY/TUN fwmark)、`openclash_output_v6`/`openclash_mangle_output_v6`(路由自身)、`openclash_post_v6`(旁路由 SNAT)、`openclash_wan6_input`(仅内网防护) |
| **`local_network6_pass`** (本地 IPv6 绕过地址 / Local IPv6 Network Bypassed List) | 已配置 | 创建 IPv6 `localnetwork6` nft set (默认包含 ::/128, ::1/128, fe80::/10, ff00::/8 等)，IPv6 链中匹配本地 IPv6 段 RETURN。WAN IPv6 接口地址自动加入 |
| **ICMP/Ping 处理**（无 UCI 选项，由运行模式决定） | Redir-Host / Fake-IP（非 TUN） | ICMP echo-request 仅标记 fwmark `0x162` 后 accept，**不被代理**（只有 TCP/UDP 被重定向到内核）；Fake-IP 非 TUN 模式下对 `198.18.0.0/16` 的 ping 被防火墙 REJECT（INPUT/FORWARD/OUTPUT 三链阻断，OUTPUT 排除 skgid≠65534）。详见 `05-firewall-special.md` §5.1 |
| | TUN 模式 / Mix 模式 | ICMP 标记 fwmark 后经策略路由进入 TUN 虚拟网卡，由 TUN 内核处理（真实 IP → DIRECT 直连延迟，Fake-IP → 伪造回复 ~0ms）；可通过 Mihomo 的 `disable-icmp-forwarding` 禁用 |
| **`firewall_lan_ac_traffic`** (高级流量控制 / Advanced Traffic Control) | 已配置 (UCI section) | 通过 `lan_ac_traffic` UCI sections 按设备/协议/端口/DSCP 精确控制，每条规则插入到对应链的最前面 (position 0)，优先级高于所有其他规则。支持 `return`(跳过代理)/`accept`(放行)/`drop`。详见 `05-firewall-special.md` §5.2 |

---

### 6.3 Dnsmasq 修改详解 (`change_dnsmasq` / `revert_dnsmasq`)

**修改流程** (`change_dnsmasq()`, 仅在 `enable_redirect_dns=1` 时执行):

```bash
# 1. 备份原始配置到 openclash.config.*
save_dnsmasq_server() → uci add_list openclash.config.dnsmasq_server="<原始server>"
uci set openclash.config.dnsmasq_noresolv="$(uci get dhcp.@dnsmasq[0].noresolv)"
uci set openclash.config.dnsmasq_resolvfile="$(uci get dhcp.@dnsmasq[0].resolvfile)"
uci set openclash.config.dnsmasq_cachesize="$(uci get dhcp.@dnsmasq[0].cachesize)"

# 2. 重定向 DNS
uci del dhcp.@dnsmasq[-1].server
uci add_list dhcp.@dnsmasq[0].server="127.0.0.1#$dns_port"
uci delete dhcp.@dnsmasq[0].resolvfile
uci set dhcp.@dnsmasq[0].noresolv=1
uci set dhcp.@dnsmasq[0].localuse=1
uci set dhcp.@dnsmasq[0].cachesize=0

# 3. IPv6 DNS (ipv6_dns=1 时)
uci set dhcp.@dnsmasq[0].filter_aaaa=0  # 允许 AAAA 记录

# 4. chnroute_pass 处理 — 加载 ipset/nftset
load_ip_route_pass()
# 创建 china_ip_route_pass ipset/nftset
# 将 openclash_custom_chnroute_pass.list 中的域名加入 set
# 对 china_ip_route_pass UCI 列表中的域名加入 set

# 5. 自定义域名 DNS
/usr/share/openclash/openclash_custom_domain_dns.sh

# 6. 重启 dnsmasq
/etc/init.d/dnsmasq restart
```

**恢复流程** (`revert_dnsmasq()`):
```bash
# 1. 删除 OpenClash 注入的 server
uci del dhcp.@dnsmasq[-1].server

# 2. 恢复原始 server 列表
for server in $(uci get openclash.config.dnsmasq_server); do
    uci add_list dhcp.@dnsmasq[0].server="$server"
done

# 3. 恢复 resolvfile / noresolv / cachesize / filter_aaaa
uci set dhcp.@dnsmasq[0].noresolv="$saved_noresolv"
uci set dhcp.@dnsmasq[0].resolvfile="$saved_resolvfile"
uci set dhcp.@dnsmasq[0].cachesize="$saved_cachesize"

# 4. DNS 验证 — 测试修改后的 DNS 是否可用
if nslookup www.apple.com 127.0.0.1:<dnsmasq_port> 失败; then
    # 创建 fallback resolv.conf (114.114.114.114, 8.8.8.8)
fi
```

**chnroute_pass 的 dnsmasq 集成**:
- 创建 `china_ip_route_pass` ipset/nftset
- 将 chnroute_pass 域名加入 set: `ipset=/domain.com/china_ip_route_pass` 或 `nftset=/domain.com/4#inet#fw4#china_ip_route_pass`
- 效果: DNS 解析这些域名时加入 set 便于在匹配时绕过（而非被 chnroute 影响）

---
