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
   op_line=`iptables -t nat -nL PREROUTING --line-number |grep "openclash" 2>/dev/null |awk '{print $1}' 2>/dev/null |head -1`
   if [ "$zone_line" -gt "$op_line" ]; then
      /etc/init.d/firewall restart >/dev/null 2>&1
      /etc/init.d/miniupnpd restart >/dev/null 2>&1
      echo "[$LOGTIME] Watchdog: Restart Firewall For Enable Redirect." > /tmp/openclash.log
   fi
   sleep 60
done 2>/dev/null
