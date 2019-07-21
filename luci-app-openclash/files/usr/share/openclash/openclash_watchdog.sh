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
   sleep 60
done 2>/dev/null
