#!/bin/sh
CLASH="/etc/openclash/clash"
CLASH_CONFIG="/etc/openclash"
LOG_FILE="/tmp/openclash.log"
enable_redirect_dns=$(uci get openclash.config.enable_redirect_dns 2>/dev/null)
dns_port=$(uci get openclash.config.dns_port 2>/dev/null)
disable_masq_cache=$(uci get openclash.config.disable_masq_cache 2>/dev/null)

while :;
do
   LOGTIME=$(date "+%Y-%m-%d %H:%M:%S")
   enable=$(uci get openclash.config.enable)
   
if [ "$enable" -eq 1 ]; then
	if ! pidof clash >/dev/null; then
	   echo "${LOGTIME} Watchdog: Clash Core Problem, Restart." >>$LOG_FILE
	   nohup $CLASH -d "$CLASH_CONFIG" >> $LOG_FILE 2>&1 &
  fi
fi

## Log File Size Manage:
    LOGSIZE=`ls -l /tmp/openclash.log |awk '{print int($5/1024)}'`
    if [ "$LOGSIZE" -gt 90 ]; then 
       echo "$LOGTIME Watchdog: Size Limit, Clean Up All Log Records." >$LOG_FILE
    fi
    
## 端口转发重启
   last_line=$(iptables -t nat -nL PREROUTING --line-number |awk '{print $1}' 2>/dev/null |awk 'END {print}' |sed -n '$p')
   op_line=$(iptables -t nat -nL PREROUTING --line-number |grep "openclash" 2>/dev/null |awk '{print $1}' 2>/dev/null |head -1)
   if [ "$last_line" -ne "$op_line" ]; then
      iptables -t nat -D PREROUTING -i br-lan -p tcp -j openclash
      iptables -t nat -A PREROUTING -i br-lan -p tcp -j openclash
      echo "$LOGTIME Watchdog: Reset Firewall For Enabling Redirect." >>$LOG_FILE
   fi
   
## DNS转发劫持
   if [ "$enable_redirect_dns" != "0" ]; then
      if [ -z "$(uci get dhcp.@dnsmasq[0].server 2>/dev/null |grep "$dns_port")" ] || [ ! -z "$(uci get dhcp.@dnsmasq[0].server 2>/dev/null |awk -F ' ' '{print $2}')" ]; then
         echo "$LOGTIME Watchdog: Force Reset DNS Hijack." >>$LOG_FILE
         uci del dhcp.@dnsmasq[-1].server >/dev/null 2>&1
         uci add_list dhcp.@dnsmasq[0].server=127.0.0.1#"$dns_port"
         uci delete dhcp.@dnsmasq[0].resolvfile
         uci set dhcp.@dnsmasq[0].noresolv=1
         [ "$disable_masq_cache" -eq "1" ] && {
         	uci set dhcp.@dnsmasq[0].cachesize=0
         }
         uci commit dhcp
         /etc/init.d/dnsmasq restart >/dev/null 2>&1
      fi
   fi

   sleep 60
done 2>/dev/null
