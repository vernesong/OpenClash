#!/bin/sh

status=$(ps |grep "openclash_watchdog" |grep -v grep |awk '{print $1}' |awk 'END{print NR}')
[ "$status" -gt "2" ] && echo "another OpenClash_watchdog.sh is running, exit"
[ "$status" -gt "2" ] && exit 0

while :;
do
   LOGTIME=$(date "+%Y-%m-%d %H:%M:%S")
   enable=$(uci get openclash.config.enable)
if [ "$enable" -eq 1 ]; then
	if ! pidof clash >/dev/null; then
	   echo "${LOGTIME} Watchdog: OpenClash Problem, Restart " >>/tmp/openclash.log
	   nohup /etc/init.d/openclash restart &
	   exit 0
  fi
fi
## Log File Size Manage:
    
    LOGSIZE=`ls -l /tmp/openclash.log |awk '{print int($5/1024)}'`
    if [ "$LOGSIZE" -gt 90 ]; then 
       echo "[$LOGTIME] Watchdog: Size Limit, Clean Up All Log Records." > /tmp/openclash.log
    fi
    
## 端口转发重启
   zone_line=`iptables -t nat -nL PREROUTING --line-number |grep "zone" 2>/dev/null |awk '{print $1}' 2>/dev/null |awk 'END {print}'`
   op_line=`iptables -t nat -nL PREROUTING --line-number |grep "openclash" 2>/dev/null |awk '{print $1}' 2>/dev/null |head -1`
   if [ "$zone_line" -gt "$op_line" ]; then
      nohup /etc/init.d/openclash restart &
      echo "[$LOGTIME] Watchdog: Restart For Enable Firewall Redirect." > /tmp/openclash.log
      exit 0
   fi
   sleep 60
done 2>/dev/null
