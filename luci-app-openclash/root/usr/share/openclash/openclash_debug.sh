#!/bin/bash
. /lib/functions.sh
. /usr/share/openclash/ruby.sh
. /usr/share/openclash/uci.sh

set_lock() {
   exec 885>"/tmp/lock/openclash_debug.lock" 2>/dev/null
   flock -x 885 2>/dev/null
}

del_lock() {
   flock -u 885 2>/dev/null
   rm -rf "/tmp/lock/openclash_debug.lock" 2>/dev/null
}

ipk_v()
{
   if [ -x "/bin/opkg" ]; then
      echo $(rm -f /var/lock/opkg.lock && opkg status "$1" 2>/dev/null |grep 'Version' |awk -F ': ' '{print $2}' 2>/dev/null)
   elif [ -x "/usr/bin/apk" ]; then
      echo $(rm -f /lib/apk/db/lock && apk list "$1" 2>/dev/null |grep 'installed' | grep -oE '\d+(\.\d+)*' | head -1)
   fi
}

set_lock

DEBUG_LOG="/tmp/openclash_debug.log"
LOGTIME=$(echo $(date "+%Y-%m-%d %H:%M:%S"))
log_level=$(uci_get_config "log_level")
enable_custom_dns=$(uci_get_config "enable_custom_dns")
enable_custom_clash_rules=$(uci_get_config "enable_custom_clash_rules") 
ipv6_enable=$(uci_get_config "ipv6_enable")
ipv6_dns=$(uci_get_config "ipv6_dns")
enable_redirect_dns=$(uci_get_config "enable_redirect_dns")
disable_masq_cache=$(uci_get_config "disable_masq_cache")
proxy_mode=$(uci_get_config "proxy_mode")
intranet_allowed=$(uci_get_config "intranet_allowed")
enable_udp_proxy=$(uci_get_config "enable_udp_proxy")
enable_rule_proxy=$(uci_get_config "enable_rule_proxy")
en_mode=$(uci_get_config "en_mode")
RAW_CONFIG_FILE=$(uci_get_config "config_path")
CONFIG_FILE="/etc/openclash/$(uci_get_config "config_path" |awk -F '/' '{print $5}' 2>/dev/null)"
core_model=$(uci_get_config "core_version")
if [ -x "/bin/opkg" ]; then
   cpu_model=$(rm -f /var/lock/opkg.lock && opkg status libc 2>/dev/null |grep 'Architecture' |awk -F ': ' '{print $2}' 2>/dev/null)
elif [ -x "/usr/bin/apk" ]; then
   cpu_model=$(rm -f /lib/apk/db/lock && apk list libc 2>/dev/null|awk '{print $2}')
fi
core_meta_version=$(/etc/openclash/core/clash_meta -v 2>/dev/null |awk -F ' ' '{print $3}' |head -1 2>/dev/null)
op_version=$(ipk_v "luci-app-openclash")
china_ip_route=$(uci_get_config "china_ip_route")
common_ports=$(uci_get_config "common_ports")
router_self_proxy=$(uci_get_config "router_self_proxy")
core_type=$(uci_get_config "core_type" || echo "Dev")
da_password=$(uci_get_config "dashboard_password")
cn_port=$(uci_get_config "cn_port")
stack_type=$(uci_get_config "stack_type")
delay_start=$(uci_get_config "delay_start")
log_size=$(uci_get_config "log_size")
bypass_gateway_compatible=$(uci_get_config "bypass_gateway_compatible")
disable_quic_go_gso=$(uci_get_config "disable_quic_go_gso")
small_flash_memory=$(uci_get_config "small_flash_memory")
enable_meta_sniffer=$(uci_get_config "enable_meta_sniffer")
enable_respect_rules=$(uci_get_config "enable_respect_rules")
skip_proxy_address=$(uci_get_config "skip_proxy_address")
disable_udp_quic=$(uci_get_config "disable_udp_quic")
lan_ac_mode=$(uci_get_config "lan_ac_mode")
ipv6_mode=$(uci_get_config "ipv6_mode")
china_ip6_route=$(uci_get_config "china_ip6_route")
lan_interface_name=$(uci_get_config "lan_interface_name" || echo "0")
if [ "$lan_interface_name" = "0" ]; then
   lan_ip=$(uci -q get network.lan.ipaddr |awk -F '/' '{print $1}' 2>/dev/null || ip address show $(uci -q -p /tmp/state get network.lan.ifname || uci -q -p /tmp/state get network.lan.device) | grep -w "inet"  2>/dev/null |grep -Eo 'inet [0-9\.]+' | awk '{print $2}' |head -1 || ip addr show 2>/dev/null | grep -w 'inet' | grep 'global' | grep 'brd' | grep -Eo 'inet [0-9\.]+' | awk '{print $2}' | head -n 1)
else
   lan_ip=$(ip address show $lan_interface_name | grep -w "inet"  2>/dev/null |grep -Eo 'inet [0-9\.]+' | awk '{print $2}' |head -1)
fi
dnsmasq_default_resolvfile=$(uci_get_config "default_resolvfile")

if [ -z "$RAW_CONFIG_FILE" ] || [ ! -f "$RAW_CONFIG_FILE" ]; then
   for file_name in /etc/openclash/config/*
   do
      if [ -f "$file_name" ]; then
         RAW_CONFIG_FILE=$file_name
         CONFIG_NAME=$(echo "$RAW_CONFIG_FILE" |awk -F '/' '{print $5}' 2>/dev/null)
         CONFIG_FILE="/etc/openclash/$CONFIG_NAME"
         break
      fi
   done
fi

ts_cf()
{
	if [ "$1" = "0" ] || [ -z "$1" ]; then
	   echo "停用"
	else
	   echo "启用"
   fi
}

ts_re()
{
	if [ -z "$1" ]; then
	   echo "未安装"
	else
	   echo "已安装 ($1)"
  fi
}

dns_re()
{
   if [ "$1" = "1" ]; then
	   echo "Dnsmasq 转发"
   elif [ "$1" = "2" ]; then
	   echo "Firewall 转发"
   else
      echo "停用"
   fi
}

ipv6_mode_name()
{
   case "$1" in
      0) echo "TProxy 模式" ;;
      1) echo "Redirect 模式" ;;
      2) echo "TUN 模式" ;;
      3) echo "Mix 混合模式" ;;
      *) echo "未知" ;;
   esac
}

cat > "$DEBUG_LOG" <<-EOF
# OpenClash 调试日志

> 生成时间: $LOGTIME
> 插件版本: ${op_version:-未知}
> 隐私提示: 上传此日志前请注意检查、屏蔽公网IP、节点、密码等相关敏感信息

## 系统信息

| 项目 | 值 |
|------|----|
| 主机型号 | $(cat /tmp/sysinfo/model 2>/dev/null) |
| 固件版本 | $(cat /usr/lib/os-release 2>/dev/null |grep OPENWRT_RELEASE 2>/dev/null |awk -F '"' '{print $2}' 2>/dev/null) |
| LuCI版本 | $(ipk_v "luci") |
| 内核版本 | $(uname -r 2>/dev/null) |
| 处理器架构 | $cpu_model |
| 系统运行时间 | $(uptime 2>/dev/null) |
| IPV6-DHCP | $(uci -q get dhcp.lan.dhcpv6 || echo "未配置") |
| DNS劫持 | $(dns_re "$enable_redirect_dns") |

### 磁盘与内存

\`\`\`bash
# df -h / /tmp /etc/openclash
$(df -h / /tmp /etc/openclash 2>/dev/null)
\`\`\`

\`\`\`bash
# free -m
$(free -m 2>/dev/null)
\`\`\`

\`\`\`bash
# cat /proc/meminfo | grep -E '^(MemTotal|MemAvailable|SwapTotal|SwapFree)'
$(cat /proc/meminfo 2>/dev/null | grep -E '^(MemTotal|MemAvailable|SwapTotal|SwapFree)')
\`\`\`

### Dnsmasq 配置

\`\`\`bash
# uci show dhcp.@dnsmasq[0]
$(uci show dhcp.@dnsmasq[0] 2>/dev/null)
\`\`\`
EOF

cat >> "$DEBUG_LOG" <<-EOF

## 依赖检查

| 依赖 | 状态 |
|------|------|
| dnsmasq-full | $(ts_re "$(ipk_v "dnsmasq-full")") |
| dnsmasq-full(ipset) | $(ts_re "$(dnsmasq --version |grep -v no-ipset |grep ipset)") |
| dnsmasq-full(nftset) | $(ts_re "$(dnsmasq --version |grep nftset)") |
| bash | $(ts_re "$(ipk_v "bash")") |
| curl | $(ts_re "$(ipk_v "curl")") |
| ca-bundle | $(ts_re "$(ipk_v "ca-bundle")") |
| ipset | $(ts_re "$(ipk_v "ipset")") |
| ip-full | $(ts_re "$(ipk_v "ip-full")") |
| ruby | $(ts_re "$(ipk_v "ruby")") |
| ruby-yaml | $(ts_re "$(ipk_v "ruby-yaml")") |
| ruby-psych | $(ts_re "$(ipk_v "ruby-psych")") |
| ruby-pstore | $(ts_re "$(ipk_v "ruby-pstore")") |
| ruby功能测试 | $(ruby -e "require 'yaml'; YAML.load('test: ok'); puts '正常'" 2>/dev/null || echo "异常") |
| kmod-tun(TUN模式) | $(ts_re "$(ipk_v "kmod-tun")") |
| luci-compat | $(ts_re "$(ipk_v "luci-compat")") |
| kmod-inet-diag | $(ts_re "$(ipk_v "kmod-inet-diag")") |
| unzip | $(ts_re "$(ipk_v "unzip")") |
EOF
if [ -n "$(command -v fw4)" ]; then
cat >> "$DEBUG_LOG" <<-EOF
| kmod-nft-tproxy | $(ts_re "$(ipk_v kmod-nft-tproxy)") |
EOF
else
cat >> "$DEBUG_LOG" <<-EOF
| iptables-mod-tproxy | $(ts_re "$(ipk_v "iptables-mod-tproxy")") |
| kmod-ipt-tproxy | $(ts_re "$(ipk_v "kmod-ipt-tproxy")") |
| iptables-mod-extra | $(ts_re "$(ipk_v "iptables-mod-extra")") |
| kmod-ipt-extra | $(ts_re "$(ipk_v "kmod-ipt-extra")") |
| kmod-ipt-nat | $(ts_re "$(ipk_v "kmod-ipt-nat")") |
EOF
fi

cat >> "$DEBUG_LOG" <<-EOF

### 内核模块加载状态

\`\`\`bash
# lsmod | grep -E 'tun|tproxy|inet_diag'
$(lsmod | grep -E 'tun|tproxy|inet_diag' 2>/dev/null || echo "无相关模块")
\`\`\`
EOF

#core
cat >> "$DEBUG_LOG" <<-EOF

## 内核检查

| 项目 | 值 |
|------|----|
EOF
if pidof clash >/dev/null; then
cat >> "$DEBUG_LOG" <<-EOF
| 运行状态 | 运行中 |
| 运行内核 | $core_type |
| 进程pid | $(pidof clash) |
| 运行用户 | $(ps |grep "/etc/openclash/clash" |grep -v grep |awk '{print $2}' 2>/dev/null) |
EOF
else
cat >> "$DEBUG_LOG" <<-EOF
| 运行状态 | 未运行 |
EOF
fi
if [ "$core_model" = "0" ]; then
   core_model="未选择架构"
fi
cat >> "$DEBUG_LOG" <<-EOF
| 已选择的架构 | $core_model |
| Meta 内核版本 | $core_meta_version |
EOF

if [ ! -f "/etc/openclash/core/clash_meta" ]; then
cat >> "$DEBUG_LOG" <<-EOF
| Meta 内核文件 | 不存在 |
EOF
else
cat >> "$DEBUG_LOG" <<-EOF
| Meta 内核文件 | 存在 |
EOF
fi
if [ ! -x "/etc/openclash/core/clash_meta" ]; then
cat >> "$DEBUG_LOG" <<-EOF
| Meta 内核运行权限 | 否 |
EOF
else
cat >> "$DEBUG_LOG" <<-EOF
| Meta 内核运行权限 | 正常 |
EOF
fi

cat >> "$DEBUG_LOG" <<-EOF

## GEO 数据文件

\`\`\`bash
# ls -lh /etc/openclash/Country.mmdb /etc/openclash/GeoIP.dat /etc/openclash/GeoSite.dat /etc/openclash/ASN.mmdb
$(ls -lh /etc/openclash/Country.mmdb /etc/openclash/GeoIP.dat /etc/openclash/GeoSite.dat /etc/openclash/ASN.mmdb 2>/dev/null)
\`\`\`

## 模型、缓存文件状态

| 文件 | 状态 |
|------|------|
| Model.bin | $(ls -lh /etc/openclash/Model.bin 2>/dev/null || echo "不存在") |
| cache.db | $(ls -lh /etc/openclash/cache.db 2>/dev/null || echo "不存在") |

## 冲突插件检测

\`\`\`bash
# ps | grep -E 'passwall|ssr-plus|bypass|helloworld'
$(ps | grep -E 'passwall|ssr-plus|bypass|helloworld' | grep -v grep 2>/dev/null || echo "未检测到冲突插件")
\`\`\`
EOF

cat >> "$DEBUG_LOG" <<-EOF

## 插件设置

| 设置项 | 值 |
|--------|----|
| 当前配置文件 | $RAW_CONFIG_FILE |
| 启动配置文件 | $CONFIG_FILE |
| 运行模式 | $en_mode |
| 默认代理模式 | $proxy_mode |
| UDP流量转发 | $(ts_cf "$enable_udp_proxy") |
| 自定义DNS | $(ts_cf "$enable_custom_dns") |
| IPV6代理 | $(ts_cf "$ipv6_enable") |
| IPV6-DNS解析 | $(ts_cf "$ipv6_dns") |
| 禁用Dnsmasq缓存 | $(ts_cf "$disable_masq_cache") |
| 自定义规则 | $(ts_cf "$enable_custom_clash_rules") |
| 仅允许内网 | $(ts_cf "$intranet_allowed") |
| 仅代理命中规则流量 | $(ts_cf "$enable_rule_proxy") |
| 仅允许常用端口流量 | $(ts_cf "$common_ports") |
| 绕过中国大陆IP | $(ts_cf "$china_ip_route") |
| 路由本机代理 | $(ts_cf "$router_self_proxy") |
| TUN堆栈类型 | ${stack_type:-system} |
| 启动延迟 | ${delay_start:-0}秒 |
| 日志大小 | ${log_size:-1024}KB |
| 旁路由兼容 | $(ts_cf "$bypass_gateway_compatible") |
| 禁用quic-go GSO | $(ts_cf "$disable_quic_go_gso") |
| 小闪存模式 | $(ts_cf "$small_flash_memory") |
| 域名嗅探 | $(ts_cf "$enable_meta_sniffer") |
| DNS代理 | $(ts_cf "$enable_respect_rules") |
| 绕过服务器地址 | $(ts_cf "$skip_proxy_address") |
| 禁用QUIC | $(ts_cf "$disable_udp_quic") |
| 访问控制模式 | $([ "$lan_ac_mode" = "1" ] && echo "White" || echo "Black") |
| IPv6模式 | $(ipv6_mode_name "$ipv6_mode") |
| 绕过IPv6区域 | $(ts_cf "$china_ip6_route") |

EOF

cat >> "$DEBUG_LOG" <<-EOF

## Cron 定时任务

\`\`\`bash
# crontab -l | grep -i openclash
$(crontab -l 2>/dev/null | grep -i openclash || echo "无 OpenClash 相关 cron 任务")
\`\`\`

## 覆写模块设置

\`\`\`bash
# uci show openclash.@overwrite[0]
$(uci -q show openclash.@overwrite[0])
\`\`\`

EOF

if [ "$enable_custom_clash_rules" -eq 1 ]; then
cat >> "$DEBUG_LOG" <<-EOF

## 自定义规则 一 （优先匹配）

\`\`\`bash
# cat /etc/openclash/custom/openclash_custom_rules.list
EOF
cat /etc/openclash/custom/openclash_custom_rules.list >> "$DEBUG_LOG"
echo "" >> "$DEBUG_LOG"
cat >> "$DEBUG_LOG" <<-EOF
\`\`\`

## 自定义规则 二 （扩展匹配）

\`\`\`bash
# cat /etc/openclash/custom/openclash_custom_rules_2.list
EOF
cat /etc/openclash/custom/openclash_custom_rules_2.list >> "$DEBUG_LOG"
echo "" >> "$DEBUG_LOG"
cat >> "$DEBUG_LOG" <<-EOF
\`\`\`
EOF
fi

cat >> "$DEBUG_LOG" <<-EOF

## 配置文件

\`\`\`yaml
# ruby_read [config] (filtered: without proxies/proxy-providers)
EOF
if [ -f "$CONFIG_FILE" ]; then
   ruby_read "$CONFIG_FILE" ".select {|x| 'proxies' != x and 'proxy-providers' != x }.to_yaml" 2>/dev/null >> "$DEBUG_LOG"
else
   ruby_read "$RAW_CONFIG_FILE" ".select {|x| 'proxies' != x and 'proxy-providers' != x }.to_yaml" 2>/dev/null >> "$DEBUG_LOG"
fi
echo "" >> "$DEBUG_LOG"
cat >> "$DEBUG_LOG" <<-EOF
\`\`\`
EOF

sed -i '/^ \{0,\}secret:/d' "$DEBUG_LOG" 2>/dev/null

#custom overwrite
cat >> "$DEBUG_LOG" <<-EOF

## 自定义覆写设置

\`\`\`bash
# cat /etc/openclash/custom/openclash_custom_overwrite.sh
EOF
cat /etc/openclash/custom/openclash_custom_overwrite.sh >> "$DEBUG_LOG" 2>/dev/null
echo "" >> "$DEBUG_LOG"
cat >> "$DEBUG_LOG" <<-EOF
\`\`\`
EOF

#firewall
cat >> "$DEBUG_LOG" <<-EOF

## 自定义防火墙设置

\`\`\`bash
# cat /etc/openclash/custom/openclash_custom_firewall_rules.sh
EOF
cat /etc/openclash/custom/openclash_custom_firewall_rules.sh >> "$DEBUG_LOG" 2>/dev/null
echo "" >> "$DEBUG_LOG"
cat >> "$DEBUG_LOG" <<-EOF
\`\`\`
EOF

if [ -n "$(command -v fw4)" ]; then
cat >> "$DEBUG_LOG" <<-EOF

## NFTABLES 防火墙设置

\`\`\`bash
# nft list chain inet fw4 (all chains)
EOF
   for nft in "input" "forward" "dstnat" "srcnat" "nat_output" "mangle_prerouting" "mangle_output"; do
      nft list chain inet fw4 "$nft" >> "$DEBUG_LOG" 2>/dev/null && echo "" >> "$DEBUG_LOG"
   done >/dev/null 2>&1
   for nft in "openclash" "openclash_mangle" "openclash_mangle_output" "openclash_output" "openclash_post" "openclash_wan_input" "openclash_dns_hijack" "openclash_dns_redirect" "openclash_v6" "openclash_mangle_v6" "openclash_mangle_output_v6" "openclash_output_v6" "openclash_post_v6" "openclash_wan6_input"; do
      nft list chain inet fw4 "$nft" >> "$DEBUG_LOG" 2>/dev/null && echo "" >> "$DEBUG_LOG"
   done >/dev/null 2>&1
echo "" >> "$DEBUG_LOG"
cat >> "$DEBUG_LOG" <<-EOF
\`\`\`
EOF
else
cat >> "$DEBUG_LOG" <<-EOF

## IPTABLES 防火墙设置

### IPv4 NAT chain

\`\`\`bash
# iptables-save -t nat
EOF
iptables-save -t nat >> "$DEBUG_LOG" 2>/dev/null
echo "" >> "$DEBUG_LOG"
cat >> "$DEBUG_LOG" <<-EOF
\`\`\`

### IPv4 Mangle chain

\`\`\`bash
# iptables-save -t mangle
EOF
iptables-save -t mangle >> "$DEBUG_LOG" 2>/dev/null
echo "" >> "$DEBUG_LOG"
cat >> "$DEBUG_LOG" <<-EOF
\`\`\`

### IPv4 Filter chain

\`\`\`bash
# iptables-save -t filter
EOF
iptables-save -t filter >> "$DEBUG_LOG" 2>/dev/null
echo "" >> "$DEBUG_LOG"
cat >> "$DEBUG_LOG" <<-EOF
\`\`\`

### IPv6 NAT chain

\`\`\`bash
# ip6tables-save -t nat
EOF
ip6tables-save -t nat >> "$DEBUG_LOG" 2>/dev/null
echo "" >> "$DEBUG_LOG"
cat >> "$DEBUG_LOG" <<-EOF
\`\`\`

### IPv6 Mangle chain

\`\`\`bash
# ip6tables-save -t mangle
EOF
ip6tables-save -t mangle >> "$DEBUG_LOG" 2>/dev/null
echo "" >> "$DEBUG_LOG"
cat >> "$DEBUG_LOG" <<-EOF
\`\`\`

### IPv6 Filter chain

\`\`\`bash
# ip6tables-save -t filter
EOF
ip6tables-save -t filter >> "$DEBUG_LOG" 2>/dev/null
echo "" >> "$DEBUG_LOG"
cat >> "$DEBUG_LOG" <<-EOF
\`\`\`
EOF
fi

if [ -n "$(command -v fw4)" ]; then
cat >> "$DEBUG_LOG" <<-EOF

## NFT Sets 状态

\`\`\`bash
# nft list sets inet fw4
EOF
nft list sets inet fw4 2>/dev/null | sed -n '/^table inet fw4 {/,/^}/p' | awk '
/elements = \{/ { in_el=1; el=0; trunc=0; indent=""; elem_indent=$0; sub(/[^[:space:]].*/, "", elem_indent); print; if (/[[:space:]]+\}[[:space:]]*$/) in_el=0; next }
in_el && /\}/ { in_el=0; if (trunc) { print indent "..."; print elem_indent "}" } else print; next }
in_el {
    if (!indent) { match($0, /^[[:space:]]*/); indent = substr($0, 1, RLENGTH) }
    n = split($0, a, ","); el += n
    if (el > 10 && !trunc) { trunc=1; next }
    if (trunc) next
    print
}
!in_el {
    print
    if (/^[[:space:]]+\}$/) print ""
}
' >> "$DEBUG_LOG"
echo "" >> "$DEBUG_LOG"
cat >> "$DEBUG_LOG" <<-EOF
\`\`\`
EOF
else
cat >> "$DEBUG_LOG" <<-EOF

## IPSET状态

\`\`\`bash
# ipset list
EOF
for set in $(ipset list -n 2>/dev/null); do
   ipset list "$set" 2>/dev/null | awk -v max=10 '
   /^Members:/ { in_members=1; count=0; print; next }
   in_members {
       if (/^[[:space:]]*[^[:space:]]/) {
           count++
           if (count <= max) { print; next }
           else if (count == max+1) { print "..."; next }
           else { next }
       }
   }
   { print }
   '
   echo ""
done >> "$DEBUG_LOG" 2>/dev/null
echo "" >> "$DEBUG_LOG"
cat >> "$DEBUG_LOG" <<-EOF
\`\`\`
EOF
fi

cat >> "$DEBUG_LOG" <<-EOF

## 路由表状态

EOF
echo "### IPv4" >> "$DEBUG_LOG"
echo "" >> "$DEBUG_LOG"
echo "\`\`\`bash" >> "$DEBUG_LOG"
echo "# route -n" >> "$DEBUG_LOG"
route -n >> "$DEBUG_LOG" 2>/dev/null
echo "\`\`\`" >> "$DEBUG_LOG"
echo "" >> "$DEBUG_LOG"
echo "\`\`\`bash" >> "$DEBUG_LOG"
echo "# ip route list" >> "$DEBUG_LOG"
ip route list >> "$DEBUG_LOG" 2>/dev/null
echo "\`\`\`" >> "$DEBUG_LOG"
echo "" >> "$DEBUG_LOG"
echo "\`\`\`bash" >> "$DEBUG_LOG"
echo "# ip route list table 354" >> "$DEBUG_LOG"
ip route list table 354 >> "$DEBUG_LOG" 2>/dev/null
echo "\`\`\`" >> "$DEBUG_LOG"
echo "" >> "$DEBUG_LOG"
echo "\`\`\`bash" >> "$DEBUG_LOG"
echo "# ip rule show" >> "$DEBUG_LOG"
ip rule show >> "$DEBUG_LOG" 2>/dev/null
echo "\`\`\`" >> "$DEBUG_LOG"
echo "" >> "$DEBUG_LOG"
echo "### IPv6" >> "$DEBUG_LOG"
echo "" >> "$DEBUG_LOG"
echo "\`\`\`bash" >> "$DEBUG_LOG"
echo "# route -A inet6" >> "$DEBUG_LOG"
route -A inet6 >> "$DEBUG_LOG" 2>/dev/null
echo "\`\`\`" >> "$DEBUG_LOG"
echo "" >> "$DEBUG_LOG"
echo "\`\`\`bash" >> "$DEBUG_LOG"
echo "# ip -6 route list" >> "$DEBUG_LOG"
ip -6 route list >> "$DEBUG_LOG" 2>/dev/null
echo "\`\`\`" >> "$DEBUG_LOG"
echo "" >> "$DEBUG_LOG"
echo "\`\`\`bash" >> "$DEBUG_LOG"
echo "# ip -6 route list table 354" >> "$DEBUG_LOG"
ip -6 route list table 354 >> "$DEBUG_LOG" 2>/dev/null
echo "\`\`\`" >> "$DEBUG_LOG"
echo "" >> "$DEBUG_LOG"
echo "\`\`\`bash" >> "$DEBUG_LOG"
echo "# ip -6 rule show" >> "$DEBUG_LOG"
ip -6 rule show >> "$DEBUG_LOG" 2>/dev/null
echo "\`\`\`" >> "$DEBUG_LOG"

if [ "$en_mode" != "fake-ip" ] && [ "$en_mode" != "redir-host" ]; then
cat >> "$DEBUG_LOG" <<-EOF

## Tun设备状态

\`\`\`bash
# ip tuntap list
EOF
ip tuntap list >> "$DEBUG_LOG" 2>/dev/null
echo "" >> "$DEBUG_LOG"
cat >> "$DEBUG_LOG" <<-EOF
\`\`\`
EOF
fi

cat >> "$DEBUG_LOG" <<-EOF

## 端口占用状态

\`\`\`bash
# netstat -nlp | grep clash
EOF
netstat -nlp |grep clash >> "$DEBUG_LOG" 2>/dev/null
echo "" >> "$DEBUG_LOG"
cat >> "$DEBUG_LOG" <<-EOF
\`\`\`

## 网络接口状态

\`\`\`bash
# ip link show && ip addr show | grep -E 'inet |utun'
EOF
ip link show >> "$DEBUG_LOG" 2>/dev/null
ip addr show | grep -E 'inet |utun' >> "$DEBUG_LOG" 2>/dev/null
echo "" >> "$DEBUG_LOG"
cat >> "$DEBUG_LOG" <<-EOF
\`\`\`
EOF

cat >> "$DEBUG_LOG" <<-EOF

## 测试本机DNS查询(www.baidu.com)

\`\`\`bash
# nslookup www.baidu.com
EOF
nslookup www.baidu.com >> "$DEBUG_LOG" 2>/dev/null
echo "" >> "$DEBUG_LOG"
cat >> "$DEBUG_LOG" <<-EOF
\`\`\`

## 测试内核DNS查询(www.instagram.com)

\`\`\`bash
# openclash_debug_dns.lua www.instagram.com
EOF
/usr/share/openclash/openclash_debug_dns.lua "www.instagram.com" >> "$DEBUG_LOG" 2>/dev/null
echo "" >> "$DEBUG_LOG"
cat >> "$DEBUG_LOG" <<-EOF
\`\`\`
EOF

cat >> "$DEBUG_LOG" <<-EOF

## DNS 解析文件

### **Dnsmasq 当前默认 resolv 文件**

\`\`\`bash
EOF
echo $dnsmasq_default_resolvfile >> "$DEBUG_LOG"
echo "" >> "$DEBUG_LOG"
cat >> "$DEBUG_LOG" <<-EOF
\`\`\`
EOF

if [ -s "/tmp/resolv.conf.auto" ]; then
cat >> "$DEBUG_LOG" <<-EOF

### /tmp/resolv.conf.auto

\`\`\`bash
# cat /tmp/resolv.conf.auto
EOF
cat /tmp/resolv.conf.auto >> "$DEBUG_LOG"
echo "" >> "$DEBUG_LOG"
cat >> "$DEBUG_LOG" <<-EOF
\`\`\`
EOF
fi

if [ -s "/tmp/resolv.conf.d/resolv.conf.auto" ]; then
cat >> "$DEBUG_LOG" <<-EOF

### /tmp/resolv.conf.d/resolv.conf.auto

\`\`\`bash
# cat /tmp/resolv.conf.d/resolv.conf.auto
EOF
cat /tmp/resolv.conf.d/resolv.conf.auto >> "$DEBUG_LOG"
echo "" >> "$DEBUG_LOG"
cat >> "$DEBUG_LOG" <<-EOF
\`\`\`
EOF
fi

cat >> "$DEBUG_LOG" <<-EOF

## 测试本机网络连接(www.baidu.com)

\`\`\`bash
# curl -SsI -m 5 www.baidu.com
EOF
curl -SsI -m 5 www.baidu.com >> "$DEBUG_LOG" 2>/dev/null
echo "" >> "$DEBUG_LOG"
cat >> "$DEBUG_LOG" <<-EOF
\`\`\`
EOF

LICENSE_URL="https://raw.githubusercontent.com/vernesong/OpenClash/refs/heads/master/LICENSE"
cat >> "$DEBUG_LOG" <<-EOF

## 测试本机网络下载([raw.githubusercontent.com]($LICENSE_URL))

\`\`\`bash
# curl -SsIL -m 3 --retry 2 $LICENSE_URL
EOF
curl -SsIL -m 3 --retry 2 "$LICENSE_URL" >> "$DEBUG_LOG" 2>/dev/null
echo "" >> "$DEBUG_LOG"
cat >> "$DEBUG_LOG" <<-EOF
\`\`\`
EOF

if pidof clash >/dev/null; then
cat >> "$DEBUG_LOG" <<-EOF

## Mihomo API 健康检查

\`\`\`json
# curl -Ss -m 3 -H "Authorization: Bearer [password]" http://127.0.0.1:[cn_port]/version
EOF
curl -Ss -m 3 -H "Authorization: Bearer ${da_password}" http://127.0.0.1:${cn_port}/version >> "$DEBUG_LOG" 2>/dev/null
echo "" >> "$DEBUG_LOG"
cat >> "$DEBUG_LOG" <<-EOF
\`\`\`
EOF
fi

cat >> "$DEBUG_LOG" <<-EOF

## 最近运行日志 (切换为Debug模式)

\`\`\`bash
# tail -n 100 /tmp/openclash.log
EOF

if pidof clash >/dev/null && [ "$log_level" != "debug" ]; then
   curl -SsL -m 3 --retry 2 -H "Content-Type: application/json" -H "Authorization: Bearer ${da_password}" -XPATCH http://${lan_ip}:${cn_port}/configs -d '{"log-level": "debug"}' >/dev/null
   sleep 10
fi

tail -n 100 "/tmp/openclash.log" >> "$DEBUG_LOG" 2>/dev/null
echo "" >> "$DEBUG_LOG"
cat >> "$DEBUG_LOG" <<-EOF
\`\`\`

EOF
if pidof clash >/dev/null && [ "$log_level" != "debug" ]; then
   curl -SsL -m 3 --retry 2 -H "Content-Type: application/json" -H "Authorization: Bearer ${da_password}" -XPATCH http://${lan_ip}:${cn_port}/configs -d '{"log-level": "'"$log_level"'"}' >/dev/null
fi

cat >> "$DEBUG_LOG" <<-EOF

## 活动连接信息

\`\`\`bash
# openclash_debug_getcon.lua
EOF
/usr/share/openclash/openclash_debug_getcon.lua
echo "" >> "$DEBUG_LOG"
cat >> "$DEBUG_LOG" <<-EOF
\`\`\`
EOF

sed -i -E 's/(([0-9]{1,3}\.){2})[0-9]{1,3}\.[0-9]{1,3}/\1*\.*/g' "$DEBUG_LOG" 2>/dev/null

sed -i -E 's/(:[0-9a-fA-F]{1,4}){3}/:*:*:*/' "$DEBUG_LOG" 2>/dev/null

sed -i 's/Downloading URL【[^】]*】/Downloading URL【*】/g' "$DEBUG_LOG" 2>/dev/null

del_lock