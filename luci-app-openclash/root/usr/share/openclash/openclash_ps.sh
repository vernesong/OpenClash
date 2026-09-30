#!/bin/sh
. $IPKG_INSTROOT/usr/share/openclash/uci.sh

JOB_COUNTER_FILE="/tmp/openclash_jobs"

unify_ps_status() {
	if [ "$(ps --version 2>&1 |grep -c procps-ng)" -eq 1 ]; then
		echo "$(ps -efw |grep -v grep |grep -c "$1")"
	else
		echo "$(ps -w |grep -v grep |grep -c "$1")"
	fi
}

unify_ps_pids() {
	if [ "$(ps --version 2>&1 |grep -c procps-ng)" -eq 1 ]; then
		echo "$(ps -efw |grep "$1" |grep -v grep |awk '{print $2}' 2>/dev/null)"
	else
		echo "$(ps -w |grep "$1" |grep -v grep |awk '{print $1}' 2>/dev/null)"
	fi
}

unify_ps_prevent() {
	if [ "$(ps --version 2>&1 |grep -c procps-ng)" -eq 1 ]; then
		echo "$(ps -efw |grep -v grep |grep -c "/etc/init.d/openclash")"
	else
		echo "$(ps -w |grep -v grep |grep -c "/etc/init.d/openclash")"
	fi
}

unify_ps_cfgname() {
	if [ "$(ps --version 2>&1 |grep -c procps-ng)" -eq 1 ]; then
		echo "$(ps -efw |grep /etc/openclash/clash 2>/dev/null |grep -v grep |awk -F '-f ' '{print $2}' 2>/dev/null)"
	else
		echo "$(ps -w |grep /etc/openclash/clash 2>/dev/null |grep -v grep |awk -F '-f ' '{print $2}' 2>/dev/null)"
	fi
}

inc_job_counter() {
   exec 999>"/tmp/lock/openclash_jobs.lock"
   flock -x 999
   local cnt=0
   local restart=0
   [ -f "$JOB_COUNTER_FILE" ] && cnt=$(cat "$JOB_COUNTER_FILE" | awk '{print $1}') && restart=$(cat "$JOB_COUNTER_FILE" | awk '{print $2}')
   cnt=$((cnt+1))
   echo "$cnt $restart" > "$JOB_COUNTER_FILE"
   flock -u 999
}

dec_job_counter_and_restart() {
   local restart_flag="$1"
   exec 999>"/tmp/lock/openclash_jobs.lock"
   flock -x 999
   local cnt=0
   local restart=0
   [ -f "$JOB_COUNTER_FILE" ] && cnt=$(cat "$JOB_COUNTER_FILE" | awk '{print $1}') && restart=$(cat "$JOB_COUNTER_FILE" | awk '{print $2}')
   cnt=$((cnt-1))
   [ $cnt -lt 0 ] && cnt=0

   if [ "$restart_flag" -eq 1 ]; then
      restart=1
   fi

   echo "$cnt $restart" > "$JOB_COUNTER_FILE"

   if [ $cnt -eq 0 ] && [ "$restart" -eq 1 ] && [ "$(unify_ps_prevent)" -eq 0 ]; then
      /etc/init.d/openclash restart >/dev/null 2>&1 &
      rm -rf "$JOB_COUNTER_FILE" >/dev/null 2>&1
   fi

   flock -u 999
}
