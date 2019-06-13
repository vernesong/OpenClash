#!/bin/sh

status=`ps|grep -c openclash_watchdog.sh`
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
   sleep 60
done 2>/dev/null
