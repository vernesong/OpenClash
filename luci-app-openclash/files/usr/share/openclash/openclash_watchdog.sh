#!/bin/sh

status=$(ps|grep -c openclash_watchdog.sh)
[ "$status" -gt "3" ] && echo "another clash_watchdog.sh is running,exit "
[ "$status" -gt "3" ] && exit 0

while :;
do
   enable=$(uci get openclash.config.enable)
if [ "$enable" -eq 1 ]; then
	if ! pidof clash >/dev/null; then
     LOGTIME=$(date "+%Y-%m-%d %H:%M:%S")
	   echo "${LOGTIME} Watchdog: OpenClash Problem, Restart " >>/tmp/openclash.log
	   /etc/init.d/openclash restart
  fi
fi
## Log File Size Manage:
    LOGTIME=$(date "+%Y-%m-%d %H:%M:%S")
    LOGSIZE=`ls -l /tmp/openclash.log |awk '{print int($5/1024)}'`
    if [ "$LOGSIZE" -gt 90 ]; then 
       echo "[$LOGTIME] Watchdog: Size Limit, Clean Up All Log Records." > /tmp/openclash.log
    fi
    
## 端口转发重启
   zone_line=`iptables -t nat -nL PREROUTING --line-number |grep "zone" 2>/dev/null |awk '{print $1}' 2>/dev/null |awk 'END {print}'`
   op_line=`iptables -t nat -nL PREROUTING --line-number |grep "openclash" 2>/dev/null |awk '{print $1}' 2>/dev/null |awk 'END {print}'`
   if [ "$zone_line" -gt "$op_line" ]; then
#ipv4
      iptables -t nat -F openclash >/dev/null 2>&1

      nat_clashs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/openclash/=' | sort -r)
      for nat_clash in $nat_clashs; do
         iptables -t nat -D PREROUTING "$nat_clash" >/dev/null 2>&1
      done
      iptables -t nat -X openclash >/dev/null 2>&1
      out_line=`iptables -t nat -nL OUTPUT --line-number |grep "198.18.0.0/16" 2>/dev/null |awk '{print $1}' 2>/dev/null |awk 'END {print}'`
      iptables -t nat -D OUTPUT "$out_line"
    
#ipv6
      ip6tables -t nat -F openclash >/dev/null 2>&1

      nat6_clashs=$(ip6tables -nvL PREROUTING -t nat 2>/dev/null | sed 1,2d | sed -n '/openclash/=' | sort -r)
      for nat6_clash in $nat6_clashs; do
         ip6tables -t nat -D PREROUTING "$nat6_clash" >/dev/null 2>&1
      done
      ip6tables -t nat -X openclash >/dev/null 2>&1
      
      new_pre_line=`expr "$zone_line" + 1 2>/dev/null`
      sed -i "/^ \{0,\}iptables -t nat -A PREROUTING -p tcp -j openclash/c\iptables -t nat -I PREROUTING ${new_pre_line} -p tcp -j openclash" /var/etc/openclash.include
      /etc/init.d/firewall restart >/dev/null 2>&1
      /etc/init.d/miniupnpd restart >/dev/null 2>&1
      echo "[$LOGTIME] Watchdog: Restart Firewall For Enable Redirect." > /tmp/openclash.log
   fi
   sleep 60
done 2>/dev/null
