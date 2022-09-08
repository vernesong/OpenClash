#!/bin/sh
. /usr/share/openclash/log.sh

CLASH="/etc/openclash/clash"
CLASH_CONFIG="/etc/openclash"
LOG_FILE="/tmp/openclash.log"
PROXY_FWMARK="0x162"
PROXY_ROUTE_TABLE="0x162"
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
_koolshare=$(cat /usr/lib/os-release 2>/dev/null |grep OPENWRT_RELEASE 2>/dev/null |grep -i koolshare 2>/dev/null)
CRASH_NUM=0
CFG_UPDATE_INT=1
STREAM_DOMAINS_PREFETCH=1
STREAM_AUTO_SELECT=1
FW4="$(command -v fw4)"
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
   
   enable=$(uci -q get openclash.config.enable)

if [ "$enable" -eq 1 ]; then
	clash_pids=$(pidof clash |sed 's/$//g' |wc -l)
	if [ "$clash_pids" -gt 1 ]; then
         LOG_OUT "Watchdog: Multiple Clash Processes, Kill All..."
         for clash_pid in $clash_pids; do
            kill -9 "$clash_pid" 2>/dev/null
         done >/dev/null 2>&1
         sleep 1
	fi 2>/dev/null
	if ! pidof clash >/dev/null; then
	   CRASH_NUM=$(expr "$CRASH_NUM" + 1)
	   if [ "$CRASH_NUM" -le 3 ]; then
            RAW_CONFIG_FILE=$(uci -q get openclash.config.config_path)
            CONFIG_FILE="/etc/openclash/$(uci -q get openclash.config.config_path |awk -F '/' '{print $5}' 2>/dev/null)"
            LOG_OUT "Watchdog: Clash Core Problem, Restart..."
            if [ -z "$_koolshare" ]; then
               touch /tmp/openclash.log 2>/dev/null
               chmod o+w /etc/openclash/proxy_provider/* 2>/dev/null
               chmod o+w /etc/openclash/rule_provider/* 2>/dev/null
               chmod o+w /etc/openclash/history/* 2>/dev/null
               chmod o+w /tmp/openclash.log 2>/dev/null
               chmod o+w /etc/openclash/cache.db 2>/dev/null
               chown nobody:nogroup /etc/openclash/core/* 2>/dev/null
               capabilties="cap_sys_resource,cap_dac_override,cap_net_raw,cap_net_bind_service,cap_net_admin,cap_sys_ptrace"
               capsh --caps="${capabilties}+eip" -- -c "capsh --user=nobody --addamb='${capabilties}' -- -c 'nohup $CLASH -d $CLASH_CONFIG -f \"$CONFIG_FILE\" >> $LOG_FILE 2>&1 &'" >> $LOG_FILE 2>&1
         else
               nohup $CLASH -d $CLASH_CONFIG -f "$CONFIG_FILE" >> $LOG_FILE 2>&1 &
         fi
	      sleep 3
	      if [ "$core_type" == "TUN" ] || [ "$core_type" == "Meta" ]; then
	         ip route replace default dev utun table "$PROXY_ROUTE_TABLE" 2>/dev/null
	         ip rule add fwmark "$PROXY_FWMARK" table "$PROXY_ROUTE_TABLE" 2>/dev/null
            ifconfig utun mtu 65535 >/dev/null 2>&1
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

## Localnetwork 刷新
   lan_ip_cidrs=$(ip route | grep "/" | awk '{print $1}' | grep -vE "^198.18" 2>/dev/null)
   lan_ip6_cidrs=$(ip -6 route | grep "/" | awk '{print $1}' | grep -vE "^unreachable" 2>/dev/null)
   wan_ip4s=$(ifconfig | grep 'inet addr' | awk '{print $2}' | cut -d: -f2 | grep -vE "(^198.18|^192.168|^127.0)" 2>/dev/null)
   if [ -n "$FW4" ]; then
      if [ -n "$lan_ip_cidrs" ]; then
         for lan_ip_cidr in $lan_ip_cidrs; do
            nft add element inet fw4 localnetwork { "$lan_ip_cidr" } 2>/dev/null
         done
      fi

      if [ -n "$wan_ip4s" ]; then
         for wan_ip4 in $wan_ip4s; do
            nft add element inet fw4 localnetwork { "$wan_ip4" } 2>/dev/null
         done
      fi

      if [ "$ipv6_enable" -eq 1 ]; then
         if [ -n "$lan_ip6_cidrs" ]; then
            for lan_ip6_cidr in $lan_ip6_cidrs; do
               nft add element inet fw4 localnetwork6 { "$lan_ip6_cidr" } 2>/dev/null
            done
         fi

         if [ -n "$wan_ip6s" ]; then
            for wan_ip6 in $wan_ip6s; do
               nft add element inet fw4 localnetwork6 { "$wan_ip6" } 2>/dev/null
            done
         fi
      fi
   else
      if [ -n "$lan_ip_cidrs" ]; then
         for lan_ip_cidr in $lan_ip_cidrs; do
            ipset add localnetwork "$lan_ip_cidr" 2>/dev/null
         done
      fi

      if [ -n "$wan_ip4s" ]; then
         for wan_ip4 in $wan_ip4s; do
            ipset add localnetwork "$wan_ip4" 2>/dev/null
         done
      fi
      if [ "$ipv6_enable" -eq 1 ]; then
         if [ -n "$lan_ip6_cidrs" ]; then
            for lan_ip6_cidr in $lan_ip6_cidrs; do
               ipset add localnetwork6 "$lan_ip6_cidr" 2>/dev/null
            done
         fi

         if [ -n "$wan_ip6s" ]; then
            for wan_ip6 in $wan_ip6s; do
               ipset add localnetwork6 "$wan_ip6" 2>/dev/null
            done
         fi
      fi
   fi

## DNS转发劫持
   if [ "$enable_redirect_dns" -ne 0 ]; then
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
            if [ "$stream_auto_select_google_not_cn" -eq 1 ]; then
               LOG_OUT "Tip: Start Auto Select Proxy For Google Not CN Unlock..."
               /usr/share/openclash/openclash_streaming_unlock.lua "Google" >> $LOG_FILE
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
