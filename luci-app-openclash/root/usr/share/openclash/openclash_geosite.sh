#!/bin/sh
. /usr/share/openclash/openclash_ps.sh
. /usr/share/openclash/log.sh

   set_lock() {
      exec 874>"/tmp/lock/openclash_geosite.lock" 2>/dev/null
      flock -x 874 2>/dev/null
   }

   del_lock() {
      flock -u 874 2>/dev/null
      rm -rf "/tmp/lock/openclash_geosite.lock"
   }

   small_flash_memory=$(uci get openclash.config.small_flash_memory 2>/dev/null)
   GEOSITE_CUSTOM_URL=$(uci get openclash.config.geosite_custom_url 2>/dev/null)
   github_address_mod=$(uci -q get openclash.config.github_address_mod || echo 0)
   set_lock
   
   if [ "$small_flash_memory" != "1" ]; then
   	  geosite_path="/etc/openclash/GeoSite.dat"
   	  mkdir -p /etc/openclash
   else
   	  geosite_path="/tmp/etc/openclash/GeoSite.dat"
   	  mkdir -p /tmp/etc/openclash
   fi
   LOG_OUT "Start Downloading GeoSite Database..."
   if [ -z "$GEOSITE_CUSTOM_URL" ]; then
      if [ "$github_address_mod" != "0" ]; then
         if [ "$github_address_mod" == "https://cdn.jsdelivr.net/" ]; then
            curl -sL --connect-timeout 5 -m 30 --speed-time 15 --speed-limit 1 --retry 2 https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geosite.dat -o /tmp/GeoSite.dat >/dev/null 2>&1
         else
            curl -sL --connect-timeout 5 -m 30 --speed-time 15 --speed-limit 1 --retry 2 "$github_address_mod"https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat -o /tmp/GeoSite.dat >/dev/null 2>&1
         fi
      else
         curl -sL --connect-timeout 5 -m 30 --speed-time 15 --speed-limit 1 --retry 2 https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat -o /tmp/GeoSite.dat >/dev/null 2>&1
      fi
   else
      curl -sL --connect-timeout 5 -m 30 --speed-time 15 --speed-limit 1 --retry 2 "$GEOSITE_CUSTOM_URL" -o /tmp/GeoSite.dat >/dev/null 2>&1
   fi
   if [ "$?" -eq "0" ] && [ -s "/tmp/GeoSite.dat" ]; then
      LOG_OUT "GeoSite Database Download Success, Check Updated..."
      cmp -s /tmp/GeoSite.dat "$geosite_path"
      if [ "$?" -ne "0" ]; then
         LOG_OUT "GeoSite Database Has Been Updated, Starting To Replace The Old Version..."
         mv /tmp/GeoSite.dat "$geosite_path" >/dev/null 2>&1
         LOG_OUT "GeoSite Database Update Successful!"
         sleep 3
         [ "$(unify_ps_prevent)" -eq 0 ] && /etc/init.d/openclash restart >/dev/null 2>&1 &
      else
         LOG_OUT "Updated GeoSite Database No Change, Do Nothing..."
         sleep 3
      fi
   else
      LOG_OUT "GeoSite Database Update Error, Please Try Again Later..."
      sleep 3
   fi
   rm -rf /tmp/GeoSite.dat >/dev/null 2>&1
   SLOG_CLEAN
   del_lock