#!/bin/bash
. /usr/share/openclash/openclash_ps.sh
. /usr/share/openclash/log.sh
. /usr/share/openclash/openclash_curl.sh
. /usr/share/openclash/uci.sh

set_lock() {
   exec 874>"/tmp/lock/openclash_geoasn.lock" 2>/dev/null
   flock -x 874 2>/dev/null
}

del_lock() {
   flock -u 874 2>/dev/null
   rm -rf "/tmp/lock/openclash_geoasn.lock" 2>/dev/null
}

set_lock
inc_job_counter

small_flash_memory=$(uci_get_config "small_flash_memory")
GEOASN_CUSTOM_URL=$(uci_get_config "geoasn_custom_url")
github_address_mod=$(uci_get_config "github_address_mod" || echo 0)
restart=0

if [ "$small_flash_memory" != "1" ]; then
   geoasn_path="/etc/openclash/ASN.mmdb"
   mkdir -p /etc/openclash
else
   geoasn_path="/tmp/etc/openclash/ASN.mmdb"
   mkdir -p /tmp/etc/openclash
fi
LOG_OUT "Start Downloading Geo ASN Database..."
if [ -z "$GEOASN_CUSTOM_URL" ]; then
   if [ "$github_address_mod" != "0" ]; then
      if [ "$github_address_mod" == "https://cdn.jsdelivr.net/" ] || [ "$github_address_mod" == "https://fastly.jsdelivr.net/" ] || [ "$github_address_mod" == "https://testingcf.jsdelivr.net/" ]; then
         DOWNLOAD_URL="${github_address_mod}gh/xishang0128/geoip@release/GeoLite2-ASN.mmdb"
      else
         DOWNLOAD_URL="${github_address_mod}https://github.com/xishang0128/geoip/releases/latest/download/GeoLite2-ASN.mmdb"
      fi
   else
      DOWNLOAD_URL="https://github.com/xishang0128/geoip/releases/latest/download/GeoLite2-ASN.mmdb"
   fi
else
   DOWNLOAD_URL=$GEOASN_CUSTOM_URL
fi
DOWNLOAD_FILE_CURL "$DOWNLOAD_URL" "/tmp/GeoLite2-ASN.mmdb"
if [ "$?" -eq 0 ] && [ -s "/tmp/GeoLite2-ASN.mmdb" ]; then
   LOG_OUT "Geo ASN Database Download Success, Check Updated..."
   cmp -s /tmp/GeoLite2-ASN.mmdb "$geoasn_path"
   if [ "$?" -ne "0" ]; then
      LOG_OUT "Geo ASN Database Has Been Updated, Starting To Replace The Old Version..."
      rm -rf "/etc/openclash/GeoLite2-ASN.mmdb"
      mv /tmp/GeoLite2-ASN.mmdb "$geoasn_path" >/dev/null 2>&1
      LOG_OUT "Geo ASN Database Update Successful!"
      restart=1
   else
      LOG_OUT "Updated Geo ASN Database No Change, Do Nothing..."
   fi
else
   LOG_OUT "Geo ASN Database Update Error, Please Try Again Later..."
fi

rm -rf /tmp/GeoLite2-ASN.mmdb >/dev/null 2>&1

SLOG_CLEAN
dec_job_counter_and_restart "$restart"
del_lock