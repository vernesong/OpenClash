#!/bin/sh
. /usr/share/openclash/openclash_ps.sh
. /usr/share/openclash/log.sh

   set_lock() {
      exec 880>"/tmp/lock/openclash_ipdb.lock" 2>/dev/null
      flock -x 880 2>/dev/null
   }

   del_lock() {
      flock -u 880 2>/dev/null
      rm -rf "/tmp/lock/openclash_ipdb.lock"
   }

   small_flash_memory=$(uci get openclash.config.small_flash_memory 2>/dev/null)
   GEOIP_CUSTOM_URL=$(uci get openclash.config.geo_custom_url 2>/dev/null)
   github_address_mod=$(uci -q get openclash.config.github_address_mod || echo 0)
   set_lock
   
   if [ "$small_flash_memory" != "1" ]; then
   	  geoip_path="/etc/openclash/Country.mmdb"
   	  mkdir -p /etc/openclash
   else
   	  geoip_path="/tmp/etc/openclash/Country.mmdb"
   	  mkdir -p /tmp/etc/openclash
   fi
   LOG_OUT "Start Downloading Geoip Database..."
   if [ -z "$GEOIP_CUSTOM_URL" ]; then
      if [ "$github_address_mod" != "0" ]; then
         if [ "$github_address_mod" == "https://cdn.jsdelivr.net/" ]; then
            curl -sL --connect-timeout 5 -m 30 --speed-time 15 --speed-limit 1 --retry 2 https://cdn.jsdelivr.net/gh/alecthw/mmdb_china_ip_list@release/lite/Country.mmdb -o /tmp/Country.mmdb >/dev/null 2>&1
         elif [ "$github_address_mod" == "https://fastly.jsdelivr.net/" ]; then
            curl -sL --connect-timeout 5 -m 30 --speed-time 15 --speed-limit 1 --retry 2 https://fastly.jsdelivr.net/gh/alecthw/mmdb_china_ip_list@release/lite/Country.mmdb -o /tmp/Country.mmdb >/dev/null 2>&1
         elif [ "$github_address_mod" == "https://raw.fastgit.org/" ]; then
            curl -sL --connect-timeout 5 -m 30 --speed-time 15 --speed-limit 1 --retry 2 https://raw.fastgit.org/alecthw/mmdb_china_ip_list/release/lite/Country.mmdb -o /tmp/Country.mmdb >/dev/null 2>&1
         else
            curl -sL --connect-timeout 5 -m 30 --speed-time 15 --speed-limit 1 --retry 2 "$github_address_mod"https://raw.githubusercontent.com/alecthw/mmdb_china_ip_list/release/lite/Country.mmdb -o /tmp/Country.mmdb >/dev/null 2>&1
         fi
      else
         curl -sL --connect-timeout 5 -m 30 --speed-time 15 --speed-limit 1 --retry 2 https://raw.githubusercontent.com/alecthw/mmdb_china_ip_list/release/lite/Country.mmdb -o /tmp/Country.mmdb >/dev/null 2>&1
      fi
   else
      curl -sL --connect-timeout 5 -m 30 --speed-time 15 --speed-limit 1 --retry 2 "$GEOIP_CUSTOM_URL" -o /tmp/Country.mmdb >/dev/null 2>&1
   fi
   if [ "$?" -eq "0" ] && [ -s "/tmp/Country.mmdb" ]; then
      LOG_OUT "Geoip Database Download Success, Check Updated..."
      cmp -s /tmp/Country.mmdb "$geoip_path"
      if [ "$?" -ne "0" ]; then
         LOG_OUT "Geoip Database Has Been Updated, Starting To Replace The Old Version..."
         mv /tmp/Country.mmdb "$geoip_path" >/dev/null 2>&1
         LOG_OUT "Geoip Database Update Successful!"
         sleep 3
         [ "$(unify_ps_prevent)" -eq 0 ] && /etc/init.d/openclash restart >/dev/null 2>&1 &
      else
         LOG_OUT "Updated Geoip Database No Change, Do Nothing..."
         sleep 3
      fi
   else
      LOG_OUT "Geoip Database Update Error, Please Try Again Later..."
      sleep 3
   fi
   rm -rf /tmp/Country.mmdb >/dev/null 2>&1
   SLOG_CLEAN
   del_lock
