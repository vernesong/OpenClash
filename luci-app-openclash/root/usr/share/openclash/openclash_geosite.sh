#!/bin/bash
. /usr/share/openclash/openclash_ps.sh
. /usr/share/openclash/log.sh
. /usr/share/openclash/openclash_curl.sh
. /usr/share/openclash/uci.sh

set_lock() {
   exec 874>"/tmp/lock/openclash_geosite.lock" 2>/dev/null
   flock -x 874 2>/dev/null
}

del_lock() {
   flock -u 874 2>/dev/null
   rm -rf "/tmp/lock/openclash_geosite.lock" 2>/dev/null
}

set_lock
inc_job_counter

small_flash_memory=$(uci_get_config "small_flash_memory")
GEOSITE_CUSTOM_URL=$(uci_get_config "geosite_custom_url")
github_address_mod=$(uci_get_config "github_address_mod" || echo 0)
restart=0

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
      if [ "$github_address_mod" == "https://cdn.jsdelivr.net/" ] || [ "$github_address_mod" == "https://fastly.jsdelivr.net/" ] || [ "$github_address_mod" == "https://testingcf.jsdelivr.net/" ]; then
         DOWNLOAD_URL="${github_address_mod}gh/Loyalsoldier/v2ray-rules-dat@release/geosite.dat"
      else
         DOWNLOAD_URL="${github_address_mod}https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
      fi
   else
      DOWNLOAD_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
   fi
else
   DOWNLOAD_URL=$GEOSITE_CUSTOM_URL
fi
DOWNLOAD_FILE_CURL "$DOWNLOAD_URL" "/tmp/GeoSite.dat" "$geosite_path"
DOWNLOAD_RESULT=$?
if [ "$DOWNLOAD_RESULT" -eq 0 ] && [ -s "/tmp/GeoSite.dat" ]; then
   # Guard against HTML error pages (e.g. Cloudflare returning 200 for rate-limit page)
   if head -c 512 "/tmp/GeoSite.dat" | grep -qiE "<!doctype|<html|<head|<body"; then
      LOG_OUT "GeoSite Database Download Failed: HTML Response Detected, Abort Update..."
      rm -rf /tmp/GeoSite.dat
   # Validate minimum file size to guard against truncated/corrupt downloads
   elif [ $(stat -c%s "/tmp/GeoSite.dat" 2>/dev/null || echo 0) -lt 1048576 ]; then
      LOG_OUT "GeoSite Database Download Failed: File Size Too Small, Abort Update..."
      rm -rf /tmp/GeoSite.dat
   else
      LOG_OUT "GeoSite Database Download Success, Check Updated..."
      cmp -s /tmp/GeoSite.dat "$geosite_path"
      if [ "$?" -ne "0" ]; then
         LOG_OUT "GeoSite Database Has Been Updated, Starting To Replace The Old Version..."
         rm -rf "/etc/openclash/geosite.dat"
         mv /tmp/GeoSite.dat "$geosite_path" >/dev/null 2>&1
         LOG_OUT "GeoSite Database Update Successful!"
         restart=1
      else
         LOG_OUT "Updated GeoSite Database No Change, Do Nothing..."
      fi
   fi
elif [ "$DOWNLOAD_RESULT" -eq 2 ]; then
   LOG_OUT "Updated GeoSite Database No Change, Do Nothing..."
else
   LOG_OUT "GeoSite Database Update Error, Please Try Again Later..."
fi

rm -rf /tmp/GeoSite.dat >/dev/null 2>&1

SLOG_CLEAN
dec_job_counter_and_restart "$restart"
del_lock