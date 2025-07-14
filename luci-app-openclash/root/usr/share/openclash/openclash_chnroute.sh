#!/bin/bash
. /usr/share/openclash/openclash_ps.sh
. /usr/share/openclash/log.sh
. /usr/share/openclash/openclash_curl.sh

set_lock() {
   exec 879>"/tmp/lock/openclash_chn.lock" 2>/dev/null
   flock -x 879 2>/dev/null
}

del_lock() {
   flock -u 879 2>/dev/null
   rm -rf "/tmp/lock/openclash_chn.lock" 2>/dev/null
}

set_lock

JOB_COUNTER_FILE="/tmp/openclash_jobs"

inc_job_counter() {
   flock -x 999
   local cnt=0
   [ -f "$JOB_COUNTER_FILE" ] && cnt=$(cat "$JOB_COUNTER_FILE")
   cnt=$((cnt+1))
   echo "$cnt" > "$JOB_COUNTER_FILE"
   flock -u 999
}
exec 999>"/tmp/lock/openclash_jobs.lock"
inc_job_counter

FW4=$(command -v fw4)
china_ip_route=$(uci -q get openclash.config.china_ip_route)
china_ip6_route=$(uci -q get openclash.config.china_ip6_route)
CHNR_CUSTOM_URL=$(uci -q get openclash.config.chnr_custom_url)
CHNR6_CUSTOM_URL=$(uci -q get openclash.config.chnr6_custom_url)
CNDOMAIN_CUSTOM_URL=$(uci -q get openclash.config.cndomain_custom_url)
disable_udp_quic=$(uci -q get openclash.config.disable_udp_quic)
small_flash_memory=$(uci -q get openclash.config.small_flash_memory)
en_mode=$(uci -q get openclash.config.en_mode)
restart=0

if [ "$small_flash_memory" != "1" ]; then
   chnr_path="/etc/openclash/china_ip_route.ipset"
   chnr6_path="/etc/openclash/china_ip6_route.ipset"
   mkdir -p /etc/openclash
else
   chnr_path="/tmp/etc/openclash/china_ip_route.ipset"
   chnr6_path="/tmp/etc/openclash/china_ip6_route.ipset"
   mkdir -p /tmp/etc/openclash
fi

LOG_OUT "Start Downloading The Chnroute Cidr List..."
if [ -z "$CHNR_CUSTOM_URL" ]; then
   DOWNLOAD_FILE_CURL "https://ispip.clang.cn/all_cn.txt" "/tmp/china_ip_route.txt"
else
   DOWNLOAD_FILE_CURL "$CHNR_CUSTOM_URL" "/tmp/china_ip_route.txt"
fi

if [ "$?" -eq 0 ]; then
   LOG_OUT "Chnroute Cidr List Download Success, Check Updated..."
   #预处理
   if [ -n "$FW4" ]; then
      echo "define china_ip_route = {" >/tmp/china_ip_route.list
      awk '!/^$/&&!/^#/{printf("    %s,'" "'\n",$0)}' /tmp/china_ip_route.txt >>/tmp/china_ip_route.list
      echo "}" >>/tmp/china_ip_route.list
      echo "add set inet fw4 china_ip_route { type ipv4_addr; flags interval; auto-merge; }" >>/tmp/china_ip_route.list
      echo 'add element inet fw4 china_ip_route $china_ip_route' >>/tmp/china_ip_route.list
   else
      echo "create china_ip_route hash:net family inet hashsize 1024 maxelem 1000000" >/tmp/china_ip_route.list
      awk '!/^$/&&!/^#/{printf("add china_ip_route %s'" "'\n",$0)}' /tmp/china_ip_route.txt >>/tmp/china_ip_route.list
   fi
   cmp -s /tmp/china_ip_route.list "$chnr_path"
   if [ "$?" -ne 0 ]; then
      LOG_OUT "Chnroute Cidr List Has Been Updated, Starting To Replace The Old Version..."
      mv /tmp/china_ip_route.list "$chnr_path" >/dev/null 2>&1
      if [ "$china_ip_route" -ne 0 ] || [ "$disable_udp_quic" -eq 1 ]; then
         restart=1
      fi
      LOG_OUT "Chnroute Cidr List Update Successful!"
   else
      LOG_OUT "Updated Chnroute Cidr List No Change, Do Nothing..."
   fi
else
   LOG_OUT "Chnroute Cidr List Update Error, Please Try Again Later..."
fi

#ipv6
LOG_OUT "Start Downloading The Chnroute6 Cidr List..."
if [ -z "$CHNR6_CUSTOM_URL" ]; then
   DOWNLOAD_FILE_CURL "https://ispip.clang.cn/all_cn_ipv6.txt" "/tmp/china_ip6_route.txt"
else
   DOWNLOAD_FILE_CURL "$CHNR6_CUSTOM_URL" "/tmp/china_ip6_route.txt"
fi
if [ "$?" -eq 0 ]; then
   LOG_OUT "Chnroute6 Cidr List Download Success, Check Updated..."
   #预处理
   if [ -n "$FW4" ]; then
      echo "define china_ip6_route = {" >/tmp/china_ip6_route.list
      awk '!/^$/&&!/^#/{printf("    %s,'" "'\n",$0)}' /tmp/china_ip6_route.txt >>/tmp/china_ip6_route.list
      echo "}" >>/tmp/china_ip6_route.list
      echo "add set inet fw4 china_ip6_route { type ipv6_addr; flags interval; auto-merge; }" >>/tmp/china_ip6_route.list
      echo 'add element inet fw4 china_ip6_route $china_ip6_route' >>/tmp/china_ip6_route.list
   else
      echo "create china_ip6_route hash:net family inet6 hashsize 1024 maxelem 1000000" >/tmp/china_ip6_route.list
      awk '!/^$/&&!/^#/{printf("add china_ip6_route %s'" "'\n",$0)}' /tmp/china_ip6_route.txt >>/tmp/china_ip6_route.list
   fi
   cmp -s /tmp/china_ip6_route.list "$chnr6_path"
   if [ "$?" -ne 0 ]; then
      LOG_OUT "Chnroute6 Cidr List Has Been Updated, Starting To Replace The Old Version..."
      mv /tmp/china_ip6_route.list "$chnr6_path" >/dev/null 2>&1
      if [ "$china_ip6_route" -ne 0 ] || [ "$disable_udp_quic" -eq 1 ]; then
         restart=1
      fi
      LOG_OUT "Chnroute6 Cidr List Update Successful!"
   else
      LOG_OUT "Updated Chnroute6 Cidr List No Change, Do Nothing..."
   fi
else
   LOG_OUT "Chnroute6 Cidr List Update Error, Please Try Again Later..."
fi

dec_job_counter_and_restart() {
   flock -x 999
   local cnt=0
   [ -f "$JOB_COUNTER_FILE" ] && cnt=$(cat "$JOB_COUNTER_FILE")
   cnt=$((cnt-1))
   [ $cnt -lt 0 ] && cnt=0
   echo "$cnt" > "$JOB_COUNTER_FILE"
   if [ $cnt -eq 0 ]; then
      if [ "$restart" -eq 1 ] && [ "$(unify_ps_prevent)" -eq 0 ]; then
         /etc/init.d/openclash restart >/dev/null 2>&1 &
      elif [ "$restart" -eq 0 ] && [ "$(unify_ps_prevent)" -eq 0 ] && [ "$(uci -q get openclash.config.restart)" -eq 1 ]; then
         /etc/init.d/openclash restart >/dev/null 2>&1 &
         uci -q set openclash.config.restart=0
         uci -q commit openclash
      elif [ "$restart" -eq 1 ]; then
         uci -q set openclash.config.restart=1
         uci -q commit openclash
      fi
      rm -rf "$JOB_COUNTER_FILE" >/dev/null 2>&1
   fi
   flock -u 999
}

rm -rf /tmp/china_ip*_route* >/dev/null 2>&1
SLOG_CLEAN
dec_job_counter_and_restart
del_lock