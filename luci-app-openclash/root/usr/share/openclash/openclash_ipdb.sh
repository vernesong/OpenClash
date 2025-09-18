#!/bin/bash
. /usr/share/openclash/openclash_ps.sh
. /usr/share/openclash/log.sh
. /usr/share/openclash/openclash_curl.sh
. /usr/share/openclash/uci.sh

set_lock() {
   exec 880>"/tmp/lock/openclash_ipdb.lock" 2>/dev/null
   flock -x 880 2>/dev/null
}

del_lock() {
   flock -u 880 2>/dev/null
   rm -rf "/tmp/lock/openclash_ipdb.lock" 2>/dev/null
}

set_lock
inc_job_counter

small_flash_memory=$(uci_get_config "small_flash_memory")
GEOIP_CUSTOM_URL=$(uci_get_config "geo_custom_url")
github_address_mod=$(uci_get_config "github_address_mod" || echo 0)
restart=0

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
      if [ "$github_address_mod" == "https://cdn.jsdelivr.net/" ] || [ "$github_address_mod" == "https://fastly.jsdelivr.net/" ] || [ "$github_address_mod" == "https://testingcf.jsdelivr.net/" ]; then
         DOWNLOAD_URL="${github_address_mod}gh/alecthw/mmdb_china_ip_list@release/lite/Country.mmdb"
      else
         DOWNLOAD_URL="${github_address_mod}https://raw.githubusercontent.com/alecthw/mmdb_china_ip_list/release/lite/Country.mmdb"
      fi
   else
      DOWNLOAD_URL="https://raw.githubusercontent.com/alecthw/mmdb_china_ip_list/release/lite/Country.mmdb"
   fi
else
   DOWNLOAD_URL=$GEOIP_CUSTOM_URL
fi
DOWNLOAD_FILE_CURL "$DOWNLOAD_URL" "/tmp/Country.mmdb"
if [ "$?" -eq 0 ] && [ -s "/tmp/Country.mmdb" ]; then
   LOG_OUT "Geoip Database Download Success, Check Updated..."
   cmp -s /tmp/Country.mmdb "$geoip_path"
   if [ "$?" -ne 0 ]; then
      LOG_OUT "Geoip Database Has Been Updated, Starting To Replace The Old Version..."
      mv /tmp/Country.mmdb "$geoip_path" >/dev/null 2>&1
      LOG_OUT "Geoip Database Update Successful!"
      restart=1
   else
      LOG_OUT "Updated Geoip Database No Change, Do Nothing..."
   fi
else
   LOG_OUT "Geoip Database Update Error, Please Try Again Later..."
fi

rm -rf /tmp/Country.mmdb >/dev/null 2>&1

SLOG_CLEAN
dec_job_counter_and_restart "$restart"
del_lock