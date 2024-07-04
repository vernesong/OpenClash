#!/bin/sh
. /usr/share/openclash/log.sh

CLASH="/etc/openclash/clash"
CLASH_CONFIG="/etc/openclash"
LOG_FILE="/tmp/openclash.log"
PROXY_FWMARK="0x162"
PROXY_ROUTE_TABLE="0x162"
LOGTIME=$(echo $(date "+%Y-%m-%d %H:%M:%S"))
CONFIG_FILE="/etc/openclash/$(uci -q get openclash.config.config_path |awk -F '/' '{print $5}' 2>/dev/null)"
ipv6_enable=$(uci -q get openclash.config.ipv6_enable)
enable_redirect_dns=$(uci -q get openclash.config.enable_redirect_dns)
dns_port=$(uci -q get openclash.config.dns_port)
disable_masq_cache=$(uci -q get openclash.config.disable_masq_cache)
cfg_update_interval=$(uci -q get openclash.config.config_update_interval || echo 60)
log_size=$(uci -q get openclash.config.log_size || echo 1024)
core_type=$(uci -q get openclash.config.core_type)
router_self_proxy=$(uci -q get openclash.config.router_self_proxy || echo 1)
stream_domains_prefetch_interval=$(uci -q get openclash.config.stream_domains_prefetch_interval || echo 1440)
stream_auto_select_interval=$(uci -q get openclash.config.stream_auto_select_interval || echo 30)
NETFLIX_DOMAINS_LIST="/usr/share/openclash/res/Netflix_Domains.list"
NETFLIX_DOMAINS_CUSTOM_LIST="/etc/openclash/custom/openclash_custom_netflix_domains.list"
DISNEY_DOMAINS_LIST="/usr/share/openclash/res/Disney_Plus_Domains.list"
china_ip_route=$(uci -q get openclash.config.china_ip_route)
en_mode=$(uci -q get openclash.config.en_mode)
fakeip_range=$(uci -q get openclash.config.fakeip_range || echo "198.18.0.1/16")
ipv6_mode=$(uci -q get openclash.config.ipv6_mode || echo 0)
skip_proxy_address=$(uci -q get openclash.config.skip_proxy_address || echo 0)
CRASH_NUM=0
CFG_UPDATE_INT=1
SKIP_PROXY_ADDRESS=1
SKIP_PROXY_ADDRESS_INTERVAL=30
STREAM_DOMAINS_PREFETCH=1
STREAM_AUTO_SELECT=1
FW4=$(command -v fw4)


check_dnsmasq() {
   if [ -z "$(echo "$en_mode" |grep "redir-host")" ] && [ "$china_ip_route" -eq 1 ] && [ "$enable_redirect_dns" != "2" ]; then
      DNSPORT=$(uci -q get dhcp.@dnsmasq[0].port)
      if [ -z "$DNSPORT" ]; then
         DNSPORT=$(netstat -nlp |grep -E '127.0.0.1:.*dnsmasq' |awk -F '127.0.0.1:' '{print $2}' |awk '{print $1}' |head -1 || echo 53)
      fi
      if [ "$(nslookup www.baidu.com >/dev/null 2>&1 || echo $?)" = "1" ]; then
         if [ -n "$FW4" ]; then
            if [ -z "$(nft list chain inet fw4 nat_output |grep '12353')" ]; then
               LOG_OUT "Warning: Dnsmasq Work is Unnormal, Setting The Firewall DNS Hijacking Rules..."
               nft insert rule inet fw4 dstnat position 0 tcp dport 53 counter redirect to "$dns_port" comment \"OpenClash DNS Hijack\" 2>/dev/null
               nft insert rule inet fw4 dstnat position 0 udp dport 53 counter redirect to "$dns_port" comment \"OpenClash DNS Hijack\" 2>/dev/null
               nft 'add chain inet fw4 nat_output { type nat hook output priority -1; }' 2>/dev/null
               nft insert rule inet fw4 nat_output position 0 tcp dport 53 meta skuid != 65534 counter redirect to "$dns_port" comment \"OpenClash DNS Hijack\" 2>/dev/null
               nft insert rule inet fw4 nat_output position 0 udp dport 53 meta skuid != 65534 counter redirect to "$dns_port" comment \"OpenClash DNS Hijack\" 2>/dev/null
               nft insert rule inet fw4 nat_output position 0 tcp dport 12353 meta skuid != 65534 counter redirect to "$DNSPORT" comment \"OpenClash DNS Hijack\" 2>/dev/null
               nft insert rule inet fw4 nat_output position 0 udp dport 12353 meta skuid != 65534 counter redirect to "$DNSPORT" comment \"OpenClash DNS Hijack\" 2>/dev/null
               if [ "$ipv6_enable" -eq 1 ]; then
                  nft insert rule inet fw4 dstnat position 0 meta nfproto {ipv6} tcp dport 53 counter redirect to "$dns_port" comment \"OpenClash DNS Hijack\" 2>/dev/null
                  nft insert rule inet fw4 dstnat position 0 meta nfproto {ipv6} udp dport 53 counter redirect to "$dns_port" comment \"OpenClash DNS Hijack\" 2>/dev/null
                  nft 'add chain inet fw4 nat_output { type nat hook output priority -1; }' 2>/dev/null
                  nft add rule inet fw4 nat_output position 0 meta nfproto {ipv6} tcp dport 53 meta skuid != 65534 counter redirect to "$dns_port" comment \"OpenClash DNS Hijack\" 2>/dev/null
                  nft add rule inet fw4 nat_output position 0 meta nfproto {ipv6} udp dport 53 meta skuid != 65534 counter redirect to "$dns_port" comment \"OpenClash DNS Hijack\" 2>/dev/null
                  nft add rule inet fw4 nat_output position 0 meta nfproto {ipv6} tcp dport 12353 meta skuid != 65534 counter redirect to "$DNSPORT" comment \"OpenClash DNS Hijack\" 2>/dev/null
                  nft add rule inet fw4 nat_output position 0 meta nfproto {ipv6} udp dport 12353 meta skuid != 65534 counter redirect to "$DNSPORT" comment \"OpenClash DNS Hijack\" 2>/dev/null
               fi
            fi
         else
            if [ -z "$(iptables -t nat -nL OUTPUT --line-number |grep '12353')" ]; then
               LOG_OUT "Warning: Dnsmasq Work is Unnormal, Setting The Firewall DNS Hijacking Rules..."
               iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports "$dns_port" -m comment --comment "OpenClash DNS Hijack" 2>/dev/null
               iptables -t nat -I PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports "$dns_port" -m comment --comment "OpenClash DNS Hijack" 2>/dev/null
               iptables -t nat -I OUTPUT -p udp --dport 53 -m owner ! --uid-owner 65534 -j REDIRECT --to-ports "$dns_port" -m comment --comment "OpenClash DNS Hijack" 2>/dev/null
               iptables -t nat -I OUTPUT -p tcp --dport 53 -m owner ! --uid-owner 65534 -j REDIRECT --to-ports "$dns_port" -m comment --comment "OpenClash DNS Hijack" 2>/dev/null
               iptables -t nat -I OUTPUT -p udp --dport 12353 -m owner ! --uid-owner 65534 -j REDIRECT --to-ports "$DNSPORT" -m comment --comment "OpenClash DNS Hijack" 2>/dev/null
               iptables -t nat -I OUTPUT -p tcp --dport 12353 -m owner ! --uid-owner 65534 -j REDIRECT --to-ports "$DNSPORT" -m comment --comment "OpenClash DNS Hijack" 2>/dev/null
               if [ "$ipv6_enable" -eq 1 ]; then
                  ip6tables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports "$dns_port" -m comment --comment "OpenClash DNS Hijack" 2>/dev/null
                  ip6tables -t nat -I PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports "$dns_port" -m comment --comment "OpenClash DNS Hijack" 2>/dev/null
                  ip6tables -t nat -I OUTPUT -p udp --dport 53 -m owner ! --uid-owner 65534 -j REDIRECT --to-ports "$dns_port" -m comment --comment "OpenClash DNS Hijack" 2>/dev/null
                  ip6tables -t nat -I OUTPUT -p tcp --dport 53 -m owner ! --uid-owner 65534 -j REDIRECT --to-ports "$dns_port" -m comment --comment "OpenClash DNS Hijack" 2>/dev/null
                  ip6tables -t nat -I OUTPUT -p udp --dport 12353 -m owner ! --uid-owner 65534 -j REDIRECT --to-ports "$DNSPORT" -m comment --comment "OpenClash DNS Hijack" 2>/dev/null
                  ip6tables -t nat -I OUTPUT -p tcp --dport 12353 -m owner ! --uid-owner 65534 -j REDIRECT --to-ports "$DNSPORT" -m comment --comment "OpenClash DNS Hijack" 2>/dev/null
               fi
            fi
         fi
      fi
      if [ "$(nslookup www.baidu.com 127.0.0.1:12353 >/dev/null 2>&1 || echo $?)" != "1" ]; then
         if [ -n "$FW4" ]; then
            if [ -n "$(nft list chain inet fw4 nat_output |grep 'OpenClash DNS Hijack')" ]; then
               LOG_OUT "Tip: Dnsmasq Work is Normal, Restore The Firewall DNS Hijacking Rules..."
               for nft in "nat_output" "dstnat"; do
                  handles=$(nft -a list chain inet fw4 ${nft} |grep "OpenClash DNS Hijack" |awk -F '# handle ' '{print$2}')
                  for handle in $handles; do
                     nft delete rule inet fw4 ${nft} handle ${handle}
                  done
               done >/dev/null 2>&1
               local position=$(nft -a list chain inet fw4 dstnat |grep "OpenClash" |grep "DNS" |awk -F '# handle ' '{print$2}' |sort -rn |head -1)
               [ -z "$position" ] && position=0
               nft add rule inet fw4 dstnat position "$position" tcp dport 53 redirect to "$DNSPORT" comment \"OpenClash DNS Hijack\" 2>/dev/null
               nft add rule inet fw4 dstnat position "$position" udp dport 53 redirect to "$DNSPORT" comment \"OpenClash DNS Hijack\" 2>/dev/null
               if [ "$ipv6_enable" -eq 1 ]; then
                  nft add rule inet fw4 dstnat position "$position" meta nfproto {ipv6} tcp dport 53 counter redirect to "$DNSPORT" comment \"OpenClash DNS Hijack\" 2>/dev/null
                  nft add rule inet fw4 dstnat position "$position" meta nfproto {ipv6} udp dport 53 counter redirect to "$DNSPORT" comment \"OpenClash DNS Hijack\" 2>/dev/null
               fi
            fi
         else
            if [ -n "$(iptables -t nat -nL OUTPUT --line-number |grep 'OpenClash DNS Hijack')" ]; then
               LOG_OUT "Tip: Dnsmasq Work is Normal, Restore The Firewall DNS Hijacking Rules..."
               for ipt in "iptables -nvL OUTPUT -t nat" "iptables -nvL PREROUTING -t nat" "ip6tables -nvL PREROUTING -t nat" "ip6tables -nvL OUTPUT -t nat"; do
                  lines=$($ipt |sed 1,2d |sed -n "/OpenClash DNS Hijack/=" 2>/dev/null |sort -rn)
                  if [ -n "$lines" ]; then
                     for line in $lines; do
                        $(echo "$ipt" |awk -v OFS=" " '{print $1,$4,$5}' |sed 's/[ ]*$//g') -D $(echo "$ipt" |awk '{print $3}') $line
                     done
                  fi
               done >/dev/null 2>&1
               local position=$(iptables -nvL PREROUTING -t nat |sed 1,2d |grep "OpenClash" |sed -n "/DNS/=" 2>/dev/null |sort -rn |head -1)
               [ -z "$position" ] && position=0
               [ "$position" -ne 0 ] && let position++
               iptables -t nat -I PREROUTING "$position" -p udp --dport 53 -j REDIRECT --to-ports "$DNSPORT" -m comment --comment "OpenClash DNS Hijack" 2>/dev/null
               iptables -t nat -I PREROUTING "$position" -p tcp --dport 53 -j REDIRECT --to-ports "$DNSPORT" -m comment --comment "OpenClash DNS Hijack" 2>/dev/null
               if [ "$ipv6_enable" -eq 1 ]; then
                  position=$(ip6tables -nvL PREROUTING -t nat |sed 1,2d |grep "OpenClash" |sed -n "/DNS/=" 2>/dev/null |sort -rn |head -1)
                  [ -z "$position" ] && position=0
                  [ "$position" -ne 0 ] && let position++
                  ip6tables -t nat -I PREROUTING "$position" -p udp --dport 53 -j REDIRECT --to-ports "$DNSPORT" -m comment --comment "OpenClash DNS Hijack" 2>/dev/null
                  ip6tables -t nat -I PREROUTING "$position" -p tcp --dport 53 -j REDIRECT --to-ports "$DNSPORT" -m comment --comment "OpenClash DNS Hijack" 2>/dev/null
               fi
            fi
         fi
      fi
   fi
}

check_dnsmasq
SLOG_CLEAN
sleep 60

while :;
do
   cfg_update=$(uci -q get openclash.config.auto_update)
   cfg_update_mode=$(uci -q get openclash.config.config_auto_update_mode)
   cfg_update_interval_now=$(uci -q get openclash.config.config_update_interval || echo 60)
   stream_domains_prefetch=$(uci -q get openclash.config.stream_domains_prefetch || echo 0)
   stream_domains_prefetch_interval_now=$(uci -q get openclash.config.stream_domains_prefetch_interval || echo 1440)
   stream_auto_select=$(uci -q get openclash.config.stream_auto_select || echo 0)
   stream_auto_select_interval_now=$(uci -q get openclash.config.stream_auto_select_interval || echo 30)
   stream_auto_select_netflix=$(uci -q get openclash.config.stream_auto_select_netflix || echo 0)
   stream_auto_select_disney=$(uci -q get openclash.config.stream_auto_select_disney || echo 0)
   stream_auto_select_hbo_now=$(uci -q get openclash.config.stream_auto_select_hbo_now || echo 0)
   stream_auto_select_hbo_max=$(uci -q get openclash.config.stream_auto_select_hbo_max || echo 0)
   stream_auto_select_hbo_go_asia=$(uci -q get openclash.config.stream_auto_select_hbo_go_asia || echo 0)
   stream_auto_select_tvb_anywhere=$(uci -q get openclash.config.stream_auto_select_tvb_anywhere || echo 0)
   stream_auto_select_prime_video=$(uci -q get openclash.config.stream_auto_select_prime_video || echo 0)
   stream_auto_select_ytb=$(uci -q get openclash.config.stream_auto_select_ytb || echo 0)
   stream_auto_select_dazn=$(uci -q get openclash.config.stream_auto_select_dazn || echo 0)
   stream_auto_select_paramount_plus=$(uci -q get openclash.config.stream_auto_select_paramount_plus || echo 0)
   stream_auto_select_discovery_plus=$(uci -q get openclash.config.stream_auto_select_discovery_plus || echo 0)
   stream_auto_select_bilibili=$(uci -q get openclash.config.stream_auto_select_bilibili || echo 0)
   stream_auto_select_google_not_cn=$(uci -q get openclash.config.stream_auto_select_google_not_cn || echo 0)
   stream_auto_select_openai=$(uci -q get openclash.config.stream_auto_select_openai || echo 0)
   upnp_lease_file=$(uci -q get upnpd.config.upnp_lease_file)
   enable=$(uci -q get openclash.config.enable)

if [ "$enable" -eq 1 ]; then
	clash_pids=$(pidof clash |sed 's/$//g' |wc -l)
	if [ "$clash_pids" -gt 1 ]; then
         LOG_OUT "Watchdog: Multiple Clash Processes, Kill All..."
         clash_pids=$(pidof clash |sed 's/$//g')
         for clash_pid in $clash_pids; do
            kill -9 "$clash_pid" 2>/dev/null
         done >/dev/null 2>&1
         sleep 1
	fi 2>/dev/null
	if ! pidof clash >/dev/null; then
	   CRASH_NUM=$(expr "$CRASH_NUM" + 1)
	   if [ "$CRASH_NUM" -le 3 ]; then
         LOG_OUT "Watchdog: Clash Core Problem, Restart..."
         touch /tmp/openclash.log 2>/dev/null
         chmod o+w /etc/openclash/proxy_provider/* 2>/dev/null
         chmod o+w /etc/openclash/rule_provider/* 2>/dev/null
         chmod o+w /etc/openclash/history/* 2>/dev/null
         chmod o+w /tmp/openclash.log 2>/dev/null
         chmod o+w /etc/openclash/cache.db 2>/dev/null
         chown nobody:nogroup /etc/openclash/core/* 2>/dev/null
         capabilties="cap_sys_resource,cap_dac_override,cap_net_raw,cap_net_bind_service,cap_net_admin,cap_sys_ptrace"
         capsh --caps="${capabilties}+eip" -- -c "capsh --user=nobody --addamb='${capabilties}' -- -c 'nohup $CLASH -d $CLASH_CONFIG -f \"$CONFIG_FILE\" >> $LOG_FILE 2>&1 &'" >> $LOG_FILE 2>&1
	      sleep 3
	      if [ "$core_type" == "TUN" ] || [ "$core_type" == "Meta" ]; then
	         ip route replace default dev utun table "$PROXY_ROUTE_TABLE" 2>/dev/null
	         ip rule add fwmark "$PROXY_FWMARK" table "$PROXY_ROUTE_TABLE" 2>/dev/null
            if [ "$ipv6_mode" -eq 2 ] && [ "$ipv6_enable" -eq 1 ] && [ "$core_type" == "Meta" ]; then
               ip -6 rule del oif utun table 2022 >/dev/null 2>&1
               ip -6 route del default dev utun table 2022 >/dev/null 2>&1
               ip -6 route replace default dev utun table "$PROXY_ROUTE_TABLE" >/dev/null 2>&1
               ip -6 rule add fwmark "$PROXY_FWMARK" table "$PROXY_ROUTE_TABLE" >/dev/null 2>&1
            fi
	      fi
	      sleep 60
	      continue
	   else
	      LOG_OUT "Watchdog: Already Restart 3 Times With Clash Core Problem, Auto-Exit..."
	      /etc/init.d/openclash stop
	      exit 0
	   fi
	else
	   CRASH_NUM=0
  fi
fi

## Porxy history
   /usr/share/openclash/openclash_history_get.sh

## Log File Size Manage:
   LOGSIZE=`ls -l /tmp/openclash.log |awk '{print int($5/1024)}'`
   if [ "$LOGSIZE" -gt "$log_size" ]; then
   : > /tmp/openclash.log
   LOG_OUT "Watchdog: Log Size Limit, Clean Up All Log Records..."
   fi

## 端口转发重启
   last_line=$(iptables -t nat -nL PREROUTING --line-number |awk '{print $1}' 2>/dev/null |awk 'END {print}' |sed -n '$p')
   op_line=$(iptables -t nat -nL PREROUTING --line-number |grep "openclash " 2>/dev/null |awk '{print $1}' 2>/dev/null |head -1)
   if [ "$last_line" != "$op_line" ] && [ -n "$op_line" ]; then
      pre_lines=$(iptables -nvL PREROUTING -t nat |sed 1,2d |sed -n '/openclash /=' 2>/dev/null |sort -rn)
      for pre_line in $pre_lines; do
         iptables -t nat -D PREROUTING "$pre_line" >/dev/null 2>&1
      done >/dev/null 2>&1
      iptables -t nat -A PREROUTING -p tcp -j openclash
      LOG_OUT "Watchdog: Setting Firewall For Enabling Redirect..."
   fi

## 防止 DNSMASQ 加载配置时间过长导致 DNS 无法解析
   check_dnsmasq

## Localnetwork 刷新
   wan_ip4s=$(/usr/share/openclash/openclash_get_network.lua "wanip" 2>/dev/null)
   wan_ip6s=$(ifconfig | grep 'inet6 addr' | awk '{print $3}' 2>/dev/null)
   if [ -n "$FW4" ]; then
      if [ -n "$wan_ip4s" ]; then
         for wan_ip4 in $wan_ip4s; do
            nft add element inet fw4 localnetwork { "$wan_ip4" } 2>/dev/null
         done
      fi

      if [ "$ipv6_enable" -eq 1 ]; then
         if [ -n "$wan_ip6s" ]; then
            for wan_ip6 in $wan_ip6s; do
               nft add element inet fw4 localnetwork6 { "$wan_ip6" } 2>/dev/null
            done
         fi
      fi
   else
      if [ -n "$wan_ip4s" ]; then
         for wan_ip4 in $wan_ip4s; do
            ipset add localnetwork "$wan_ip4" 2>/dev/null
         done
      fi
      if [ "$ipv6_enable" -eq 1 ]; then
         if [ -n "$wan_ip6s" ]; then
            for wan_ip6 in $wan_ip6s; do
               ipset add localnetwork6 "$wan_ip6" 2>/dev/null
            done
         fi
      fi
   fi

## UPNP
   if [ -f "$upnp_lease_file" ]; then
      #del
      if [ -n "$FW4" ]; then
         for i in `$(nft list chain inet fw4 openclash_upnp |grep "return")`
         do
            upnp_ip=$(echo "$i" |awk -F 'ip saddr ' '{print $2}' |awk  '{print $1}')
            upnp_dp=$(echo "$i" |awk -F 'sport ' '{print $2}' |awk  '{print $1}')
            upnp_type=$(echo "$i" |awk -F 'sport ' '{print $1}' |awk  '{print $4}' |tr '[a-z]' '[A-Z]')
            if [ -n "$upnp_ip" ] && [ -n "$upnp_dp" ] && [ -n "$upnp_type" ]; then
               if [ -z "$(cat "$upnp_lease_file" |grep "$upnp_ip" |grep "$upnp_dp" |grep "$upnp_type")" ]; then
                  handle=$(nft -a list chain inet fw4 openclash_upnp |grep "$i" |awk -F '# handle ' '{print$2}')
                  nft delete rule inet fw4 openclash_upnp handle ${handle}
               fi
            fi
         done >/dev/null 2>&1
      else
         for i in `$(iptables -t mangle -nL openclash_upnp |grep "RETURN")`
         do
            upnp_ip=$(echo "$i" |awk '{print $4}')
            upnp_dp=$(echo "$i" |awk -F 'spt:' '{print $2}')
            upnp_type=$(echo "$i" |awk '{print $2}' |tr '[a-z]' '[A-Z]')
            if [ -n "$upnp_ip" ] && [ -n "$upnp_dp" ] && [ -n "$upnp_type" ]; then
               if [ -z "$(cat "$upnp_lease_file" |grep "$upnp_ip" |grep "$upnp_dp" |grep "$upnp_type")" ]; then
                  iptables -t mangle -D openclash_upnp -p "$upnp_type" -s "$upnp_ip" --sport "$upnp_dp" -j RETURN 2>/dev/null
               fi
            fi
         done >/dev/null 2>&1
      fi
      #add
      if [ -s "$upnp_lease_file" ] && [ -n "$(iptables --line-numbers -t nat -xnvL openclash_upnp 2>/dev/null)"] || [ -n "$(nft list chain inet fw4 openclash_upnp 2>/dev/null)"]; then
         cat "$upnp_lease_file" |while read -r line
         do
            if [ -n "$line" ]; then
               upnp_ip=$(echo "$line" |awk -F ':' '{print $3}')
               upnp_dp=$(echo "$line" |awk -F ':' '{print $4}')
               upnp_type=$(echo "$line" |awk -F ':' '{print $1}' |tr '[A-Z]' '[a-z]')
               if [ -n "$upnp_ip" ] && [ -n "$upnp_dp" ] && [ -n "$upnp_type" ]; then
                  if [ -n "$FW4" ]; then
                     if [ -z "$(nft list chain inet fw4 openclash_upnp |grep "$upnp_ip" |grep "$upnp_dp" |grep "$upnp_type")" ]; then
                        nft add rule inet fw4 openclash_upnp ip saddr { "$upnp_ip" } "$upnp_type" sport "$upnp_dp" counter return 2>/dev/null
                     fi
                  else
                     if [ -z "$(iptables -t mangle -nL openclash_upnp |grep "$upnp_ip" |grep "$upnp_dp" |grep "$upnp_type")" ]; then
                        iptables -t mangle -A openclash_upnp -p "$upnp_type" -s "$upnp_ip" --sport "$upnp_dp" -j RETURN 2>/dev/null
                     fi
                  fi
               fi
            fi
         done >/dev/null 2>&1
      fi
   fi

## Skip Proxies Address
   if [ "$skip_proxy_address" -eq 1 ]; then
      if [ "$SKIP_PROXY_ADDRESS" -eq 1 ] || [ "$(expr "$SKIP_PROXY_ADDRESS" % "$SKIP_PROXY_ADDRESS_INTERVAL")" -eq 0 ]; then
         ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e "
         begin
            Value = YAML.load_file('$CONFIG_FILE');
         rescue Exception => e
            puts '${LOGTIME} Error: Load File Failed,【' + e.message + '】';
         end;
         begin
         Thread.new{
            reg = /^((\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.){3}(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])(?::(?:[0-9]|[1-9][0-9]{1,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5]))?$/;
            reg6 = /^(?:(?:(?:[0-9A-Fa-f]{1,4}:){7}[0-9A-Fa-f]{1,4})|(([0-9A-Fa-f]{1,4}:){6}:[0-9A-Fa-f]{1,4})|(([0-9A-Fa-f]{1,4}:){5}:([0-9A-Fa-f]{1,4}:)?[0-9A-Fa-f]{1,4})|(([0-9A-Fa-f]{1,4}:){4}:([0-9A-Fa-f]{1,4}:){0,2}[0-9A-Fa-f]{1,4})|(([0-9A-Fa-f]{1,4}:){3}:([0-9A-Fa-f]{1,4}:){0,3}[0-9A-Fa-f]{1,4})|(([0-9A-Fa-f]{1,4}:){2}:([0-9A-Fa-f]{1,4}:){0,4}[0-9A-Fa-f]{1,4})|(([0-9A-Fa-f]{1,4}:){6}((\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b)\.){3}(\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b))|(([0-9A-Fa-f]{1,4}:){0,5}:((\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b)\.){3}(\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b))|(::([0-9A-Fa-f]{1,4}:){0,5}((\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b)\.){3}(\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b))|([0-9A-Fa-f]{1,4}::([0-9A-Fa-f]{1,4}:){0,5}[0-9A-Fa-f]{1,4})|(::([0-9A-Fa-f]{1,4}:){0,6}[0-9A-Fa-f]{1,4})|(([0-9A-Fa-f]{1,4}:){1,7}:))|\[(?:(?:(?:[0-9A-Fa-f]{1,4}:){7}[0-9A-Fa-f]{1,4})|(([0-9A-Fa-f]{1,4}:){6}:[0-9A-Fa-f]{1,4})|(([0-9A-Fa-f]{1,4}:){5}:([0-9A-Fa-f]{1,4}:)?[0-9A-Fa-f]{1,4})|(([0-9A-Fa-f]{1,4}:){4}:([0-9A-Fa-f]{1,4}:){0,2}[0-9A-Fa-f]{1,4})|(([0-9A-Fa-f]{1,4}:){3}:([0-9A-Fa-f]{1,4}:){0,3}[0-9A-Fa-f]{1,4})|(([0-9A-Fa-f]{1,4}:){2}:([0-9A-Fa-f]{1,4}:){0,4}[0-9A-Fa-f]{1,4})|(([0-9A-Fa-f]{1,4}:){6}((\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b)\.){3}(\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b))|(([0-9A-Fa-f]{1,4}:){0,5}:((\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b)\.){3}(\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b))|(::([0-9A-Fa-f]{1,4}:){0,5}((\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b)\.){3}(\b((25[0-5])|(1\d{2})|(2[0-4]\d)|(\d{1,2}))\b))|([0-9A-Fa-f]{1,4}::([0-9A-Fa-f]{1,4}:){0,5}[0-9A-Fa-f]{1,4})|(::([0-9A-Fa-f]{1,4}:){0,6}[0-9A-Fa-f]{1,4})|(([0-9A-Fa-f]{1,4}:){1,7}:))\](?::(?:[0-9]|[1-9][0-9]{1,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5]))?$/i;
            if Value.key?('proxies') or Value.key?('proxy-providers') then
               firewall_v = '$FW4';
               if firewall_v.empty? then
                  firewall_v = 'ipt'
               else
                  firewall_v = 'nft'
               end;
               ips = Array.new;
               servers = Array.new;
               if Value.key?('proxies') and not Value['proxies'].nil? then
                  Value['proxies'].each do
                     |i|
                     if i['server'] then
                        if not i['server'] =~ reg and not i['server'] =~ reg6 and not servers.include?(i['server']) then
                           servers = servers.push(i['server']).uniq
                           syscall = '/usr/share/openclash/openclash_debug_dns.lua 2>/dev/null \"' + i['server'] + '\" \"true\"'
                           if IO.popen(syscall).read.split(/\n+/) then
                              ips = ips | IO.popen(syscall).read.split(/\n+/)
                           end;
                        else
                           ips = ips.push(i['server']).uniq
                        end;
                     end;
                  end;
               end;
               if Value.key?('proxy-providers') and not Value['proxy-providers'].nil? then
                  Value['proxy-providers'].values.each do
                     |i,path|
                     if i['path'] and not i['path'].empty? then
                        if i['path'].split('/')[0] == '.' then
                           path = '/etc/openclash/'+i['path'].split('./')[1]
                        else
                           path = i['path']
                        end;
                        if File::exist?(path) then
                           if YAML.load_file(path).class == String then
                              puts '${LOGTIME} Warning: Unsupported format, Proxies Address Skip Function Ignore Proxy-providers File【' + path + '】';
                              next
                           end;
                           if YAML.load_file(path).key?('proxies') and not YAML.load_file(path)['proxies'].nil? then
                              YAML.load_file(path)['proxies'].each do
                                 |j|
                                 if j['server'] then
                                    if not j['server'] =~ reg and not j['server'] =~ reg6 and not servers.include?(j['server']) then
                                       servers = servers.push(j['server']).uniq
                                       syscall = '/usr/share/openclash/openclash_debug_dns.lua 2>/dev/null \"' + j['server'] + '\" \"true\"'
                                       if IO.popen(syscall).read.split(/\n+/) then
                                          ips = ips | IO.popen(syscall).read.split(/\n+/)
                                       end;
                                    else
                                       ips = ips.push(j['server']).uniq
                                    end;
                                 end;
                              end;
                           end;
                        end;
                     end;
                  end;
               end;
               #Add ip skip
               if ips and not ips.empty? then
                  ips.each do
                     |ip|
                     if ip and ip =~ reg then
                        if firewall_v == 'nft' then
                           syscall = 'nft add element inet fw4 localnetwork { \"' + ip + '\" } 2>/dev/null'
                           system(syscall)
                        else
                           syscall = 'ipset add localnetwork \"' + ip + '\" 2>/dev/null'
                           system(syscall)
                        end;
                     elsif ip and ip =~ reg6 then
                        if firewall_v == 'nft' then
                           syscall = 'nft add element inet fw4 localnetwork6 { \"' + ip + '\" } 2>/dev/null'
                           system(syscall)
                        else
                           syscall = 'ipset add localnetwork6 \"' + ip + '\" 2>/dev/null'
                           system(syscall)
                        end;
                     end;
                  end;
               end;
            end;
         }.join;
         rescue Exception => e
            puts '${LOGTIME} Error: Set Proxies Address Skip Failed,【' + e.message + '】';
         end" >> $LOG_FILE
         let SKIP_PROXY_ADDRESS++
      else
         let SKIP_PROXY_ADDRESS++
      fi
   fi

## DNS转发劫持
   if [ "$enable_redirect_dns" = "1" ]; then
      if [ -z "$(uci -q get dhcp.@dnsmasq[0].server |grep "$dns_port")" ] || [ ! -z "$(uci -q get dhcp.@dnsmasq[0].server |awk -F ' ' '{print $2}')" ]; then
         LOG_OUT "Watchdog: Force Reset DNS Hijack..."
         uci -q del dhcp.@dnsmasq[-1].server
         uci -q add_list dhcp.@dnsmasq[0].server=127.0.0.1#"$dns_port"
         uci -q delete dhcp.@dnsmasq[0].resolvfile
         uci -q set dhcp.@dnsmasq[0].noresolv=1
         [ "$disable_masq_cache" -eq 1 ] && {
         	uci -q set dhcp.@dnsmasq[0].cachesize=0
         }
         uci -q commit dhcp
         /etc/init.d/dnsmasq restart >/dev/null 2>&1
      fi
   fi

## 配置文件循环更新
   if [ "$cfg_update" -eq 1 ] && [ "$cfg_update_mode" -eq 1 ]; then
      [ "$cfg_update_interval" -ne "$cfg_update_interval_now" ] && CFG_UPDATE_INT=0 && cfg_update_interval="$cfg_update_interval_now"
      if [ "$CFG_UPDATE_INT" -ne 0 ]; then
         [ "$(expr "$CFG_UPDATE_INT" % "$cfg_update_interval_now")" -eq 0 ] && /usr/share/openclash/openclash.sh
      fi
      CFG_UPDATE_INT=$(expr "$CFG_UPDATE_INT" + 1)
   fi

##Dler Cloud Checkin
   /usr/share/openclash/openclash_dler_checkin.lua >/dev/null 2>&1

##STREAMING_UNLOCK_CHECK
   if [ "$stream_auto_select" -eq 1 ] && [ "$router_self_proxy" -eq 1 ]; then
      [ "$stream_auto_select_interval" -ne "$stream_auto_select_interval_now" ] && STREAM_AUTO_SELECT=1 && stream_auto_select_interval="$stream_auto_select_interval_now"
      if [ "$STREAM_AUTO_SELECT" -ne 0 ]; then
         if [ "$(expr "$STREAM_AUTO_SELECT" % "$stream_auto_select_interval_now")" -eq 0 ] || [ "$STREAM_AUTO_SELECT" -eq 1 ]; then
            if [ "$stream_auto_select_netflix" -eq 1 ]; then
               LOG_OUT "Tip: Start Auto Select Proxy For Netflix Unlock..."
               /usr/share/openclash/openclash_streaming_unlock.lua "Netflix" >> $LOG_FILE
            fi
            if [ "$stream_auto_select_disney" -eq 1 ]; then
               LOG_OUT "Tip: Start Auto Select Proxy For Disney Plus Unlock..."
               /usr/share/openclash/openclash_streaming_unlock.lua "Disney Plus" >> $LOG_FILE
            fi
            if [ "$stream_auto_select_google_not_cn" -eq 1 ]; then
               LOG_OUT "Tip: Start Auto Select Proxy For Google Not CN Unlock..."
               /usr/share/openclash/openclash_streaming_unlock.lua "Google" >> $LOG_FILE
            fi
            if [ "$stream_auto_select_ytb" -eq 1 ]; then
               LOG_OUT "Tip: Start Auto Select Proxy For YouTube Premium Unlock..."
               /usr/share/openclash/openclash_streaming_unlock.lua "YouTube Premium" >> $LOG_FILE
            fi
            if [ "$stream_auto_select_prime_video" -eq 1 ]; then
               LOG_OUT "Tip: Start Auto Select Proxy For Amazon Prime Video Unlock..."
               /usr/share/openclash/openclash_streaming_unlock.lua "Amazon Prime Video" >> $LOG_FILE
            fi
            if [ "$stream_auto_select_hbo_now" -eq 1 ]; then
               LOG_OUT "Tip: Start Auto Select Proxy For HBO Now Unlock..."
               /usr/share/openclash/openclash_streaming_unlock.lua "HBO Now" >> $LOG_FILE
            fi
            if [ "$stream_auto_select_hbo_max" -eq 1 ]; then
               LOG_OUT "Tip: Start Auto Select Proxy For HBO Max Unlock..."
               /usr/share/openclash/openclash_streaming_unlock.lua "HBO Max" >> $LOG_FILE
            fi
            if [ "$stream_auto_select_hbo_go_asia" -eq 1 ]; then
               LOG_OUT "Tip: Start Auto Select Proxy For HBO GO Asia Unlock..."
               /usr/share/openclash/openclash_streaming_unlock.lua "HBO GO Asia" >> $LOG_FILE
            fi
            if [ "$stream_auto_select_tvb_anywhere" -eq 1 ]; then
               LOG_OUT "Tip: Start Auto Select Proxy For TVB Anywhere+ Unlock..."
               /usr/share/openclash/openclash_streaming_unlock.lua "TVB Anywhere+" >> $LOG_FILE
            fi
            if [ "$stream_auto_select_dazn" -eq 1 ]; then
               LOG_OUT "Tip: Start Auto Select Proxy For DAZN Unlock..."
               /usr/share/openclash/openclash_streaming_unlock.lua "DAZN" >> $LOG_FILE
            fi
            if [ "$stream_auto_select_paramount_plus" -eq 1 ]; then
               LOG_OUT "Tip: Start Auto Select Proxy For Paramount Plus Unlock..."
               /usr/share/openclash/openclash_streaming_unlock.lua "Paramount Plus" >> $LOG_FILE
            fi
            if [ "$stream_auto_select_discovery_plus" -eq 1 ]; then
               LOG_OUT "Tip: Start Auto Select Proxy For Discovery Plus Unlock..."
               /usr/share/openclash/openclash_streaming_unlock.lua "Discovery Plus" >> $LOG_FILE
            fi
            if [ "$stream_auto_select_bilibili" -eq 1 ]; then
               LOG_OUT "Tip: Start Auto Select Proxy For Bilibili Unlock..."
               /usr/share/openclash/openclash_streaming_unlock.lua "Bilibili" >> $LOG_FILE
            fi
            if [ "$stream_auto_select_openai" -eq 1 ]; then
               LOG_OUT "Tip: Start Auto Select Proxy For OpenAI Unlock..."
               /usr/share/openclash/openclash_streaming_unlock.lua "OpenAI" >> $LOG_FILE
            fi
         fi
      fi
      STREAM_AUTO_SELECT=$(expr "$STREAM_AUTO_SELECT" + 1)
   elif [ "$router_self_proxy" != "1" ] && [ "$stream_auto_select" -eq 1 ]; then
      LOG_OUT "Error: Streaming Unlock Could not Work Because of Router-Self Proxy Disabled, Exiting..."
   fi

##STREAM_DNS_PREFETCH
   if [ "$stream_domains_prefetch" -eq 1 ] && [ "$router_self_proxy" -eq 1 ]; then
      [ "$stream_domains_prefetch_interval" -ne "$stream_domains_prefetch_interval_now" ] && STREAM_DOMAINS_PREFETCH=1 && stream_domains_prefetch_interval="$stream_domains_prefetch_interval_now"
      if [ "$STREAM_DOMAINS_PREFETCH" -ne 0 ]; then
         if [ "$(expr "$STREAM_DOMAINS_PREFETCH" % "$stream_domains_prefetch_interval_now")" -eq 0 ] || [ "$STREAM_DOMAINS_PREFETCH" -eq 1 ]; then
            LOG_OUT "Tip: Start Prefetch Netflix Domains..."
            cat "$NETFLIX_DOMAINS_LIST" |while read -r line
            do
               [ -n "$line" ] && nslookup $line
            done >/dev/null 2>&1
            cat "$NETFLIX_DOMAINS_CUSTOM_LIST" |while read -r line
            do
               [ -n "$line" ] && nslookup $line
            done >/dev/null 2>&1
            LOG_OUT "Tip: Netflix Domains Prefetch Finished!"
            LOG_OUT "Tip: Start Prefetch Disney Plus Domains..."
            cat "$DISNEY_DOMAINS_LIST" |while read -r line
            do
               [ -n "$line" ] && nslookup $line
            done >/dev/null 2>&1
            LOG_OUT "Tip: Disney Plus Domains Prefetch Finished!"
         fi
      fi
      STREAM_DOMAINS_PREFETCH=$(expr "$STREAM_DOMAINS_PREFETCH" + 1)
   elif [ "$router_self_proxy" != "1" ] && [ "$stream_domains_prefetch" -eq 1 ]; then
      LOG_OUT "Error: Streaming DNS Prefetch Could not Work Because of Router-Self Proxy Disabled, Exiting..."
   fi

   SLOG_CLEAN
   sleep 60
done 2>/dev/null
