#!/bin/bash
. /usr/share/openclash/openclash_ps.sh
. /usr/share/openclash/log.sh
. /usr/share/openclash/openclash_curl.sh
. /usr/share/openclash/uci.sh

set_lock() {
   exec 873>"/tmp/lock/openclash_geoip.lock" 2>/dev/null
   flock -x 873 2>/dev/null
}

del_lock() {
   flock -u 873 2>/dev/null
   rm -rf "/tmp/lock/openclash_geoip.lock" 2>/dev/null
}

set_lock
inc_job_counter

small_flash_memory=$(uci_get_config "small_flash_memory")
GEOIP_CUSTOM_URL=$(uci_get_config "geoip_custom_url")
github_address_mod=$(uci_get_config "github_address_mod" || echo 0)
restart=0

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
      if [ "$github_address_mod" == "https://cdn.jsdelivr.net/" ] || [ "$github_address_mod" == "https://fastly.jsdelivr.net/" ] || [ "$github_address_mod" == "https://testingcf.jsdelivr.net/" ]; then
         DOWNLOAD_URL="${github_address_mod}gh/Loyalsoldier/v2ray-rules-dat@release/geoip.dat"
      else
         DOWNLOAD_URL="${github_address_mod}https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
      fi
   else
      DOWNLOAD_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
   fi
else
   DOWNLOAD_URL=$GEOIP_CUSTOM_URL
fi
DOWNLOAD_FILE_CURL "$DOWNLOAD_URL" "/tmp/GeoIP.dat" "$geoip_path"
DOWNLOAD_RESULT=$?
if [ "$DOWNLOAD_RESULT" -eq 0 ] && [ -s "/tmp/GeoIP.dat" ]; then
   # Guard against HTML error pages (e.g. Cloudflare returning 200 for rate-limit page)
   if head -c 512 "/tmp/GeoIP.dat" | grep -qiE "<!doctype|<html|<head|<body"; then
      LOG_OUT "GeoIP Dat Download Failed: HTML Response Detected, Abort Update..."
      rm -rf /tmp/GeoIP.dat
   # Validate minimum file size to guard against truncated/corrupt downloads
   elif [ $(stat -c%s "/tmp/GeoIP.dat" 2>/dev/null || echo 0) -lt 1048576 ]; then
      LOG_OUT "GeoIP Dat Download Failed: File Size Too Small, Abort Update..."
      rm -rf /tmp/GeoIP.dat
   else
      LOG_OUT "GeoIP Dat Download Success, Check Updated..."
      cmp -s /tmp/GeoIP.dat "$geoip_path"
      if [ "$?" -ne "0" ]; then
         LOG_OUT "GeoIP Dat Has Been Updated, Starting To Replace The Old Version..."
         rm -rf "/etc/openclash/geoip.dat"
         mv /tmp/GeoIP.dat "$geoip_path" >/dev/null 2>&1
         LOG_OUT "GeoIP Dat Update Successful!"
         restart=1
      else
         LOG_OUT "Updated GeoIP Dat No Change, Do Nothing..."
      fi
   fi
elif [ "$DOWNLOAD_RESULT" -eq 2 ]; then
   LOG_OUT "Updated GeoIP Dat No Change, Do Nothing..."
else
   LOG_OUT "GeoIP Dat Update Error, Please Try Again Later..."
fi

rm -rf /tmp/GeoIP.dat >/dev/null 2>&1

SLOG_CLEAN
dec_job_counter_and_restart "$restart"
del_lock