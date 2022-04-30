#!/bin/sh
. /usr/share/openclash/openclash_ps.sh
. /usr/share/openclash/log.sh

   set_lock() {
      exec 873>"/tmp/lock/openclash_geoip.lock" 2>/dev/null
      flock -x 873 2>/dev/null
   }

   del_lock() {
      flock -u 873 2>/dev/null
      rm -rf "/tmp/lock/openclash_geoip.lock"
   }

   small_flash_memory=$(uci get openclash.config.small_flash_memory 2>/dev/null)
   GEOIP_CUSTOM_URL=$(uci get openclash.config.geoip_custom_url 2>/dev/null)
   github_address_mod=$(uci -q get openclash.config.github_address_mod || echo 0)
   set_lock
   
   if [ "$small_flash_memory" != "1" ]; then
   	  geoip_path="/etc/openclash/GeoIP.dat"
   	  mkdir -p /etc/openclash
   else
   	  geoip_path="/tmp/etc/openclash/GeoIP.dat"
   	  mkdir -p /tmp/etc/openclash
   fi
   LOG_OUT "Start Downloading GeoIP Dat..."
   if [ -z "$GEOIP_CUSTOM_URL" ]; then
      if [ "$github_address_mod" != "0" ]; then
         if [ "$github_address_mod" == "https://cdn.jsdelivr.net/" ]; then
            curl -sL --connect-timeout 5 -m 30 --speed-time 15 --speed-limit 1 --retry 2 "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geoip.dat" -o /tmp/GeoIP.dat >/dev/null 2>&1
         else
            curl -sL --connect-timeout 5 -m 30 --speed-time 15 --speed-limit 1 --retry 2 "$github_address_mod"https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat -o /tmp/GeoIP.dat >/dev/null 2>&1
         fi
      else
         curl -sL --connect-timeout 5 -m 30 --speed-time 15 --speed-limit 1 --retry 2 "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat" -o /tmp/GeoIP.dat >/dev/null 2>&1
      fi
      if [ "$?" -ne "0" ]; then
         curl -sL --connect-timeout 5 -m 30 --speed-time 15 --speed-limit 1 --retry 2 "https://mirrors.tuna.tsinghua.edu.cn/osdn/storage/g/v/v2/v2raya/dists/v2ray-rules-dat/geoip.dat" -o /tmp/GeoIP.dat >/dev/null 2>&1
      fi
   else
      curl -sL --connect-timeout 5 -m 30 --speed-time 15 --speed-limit 1 --retry 2 "$GEOIP_CUSTOM_URL" -o /tmp/GeoIP.dat >/dev/null 2>&1
   fi
   if [ "$?" -eq "0" ] && [ -s "/tmp/GeoIP.dat" ]; then
      LOG_OUT "GeoIP Dat Download Success, Check Updated..."
      cmp -s /tmp/GeoIP.dat "$geoip_path"
      if [ "$?" -ne "0" ]; then
         LOG_OUT "GeoIP Dat Has Been Updated, Starting To Replace The Old Version..."
         mv /tmp/GeoIP.dat "$geoip_path" >/dev/null 2>&1
         LOG_OUT "GeoIP Dat Update Successful!"
         sleep 3
         [ "$(unify_ps_prevent)" -eq 0 ] && /etc/init.d/openclash restart >/dev/null 2>&1 &
      else
         LOG_OUT "Updated GeoIP Dat No Change, Do Nothing..."
         sleep 3
      fi
   else
      LOG_OUT "GeoIP Dat Update Error, Please Try Again Later..."
      sleep 3
   fi
   rm -rf /tmp/GeoIP.dat >/dev/null 2>&1
   SLOG_CLEAN
   del_lock