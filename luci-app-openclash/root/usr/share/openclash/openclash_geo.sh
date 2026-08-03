#!/bin/bash
. /usr/share/openclash/openclash_ps.sh
. /usr/share/openclash/log.sh
. /usr/share/openclash/openclash_curl.sh
. /usr/share/openclash/uci.sh

set_lock() {
   exec 888>"/tmp/lock/openclash_update_databases.lock" 2>/dev/null
   flock -x 888 2>/dev/null
}

del_lock() {
   flock -u 888 2>/dev/null
   rm -rf "/tmp/lock/openclash_update_databases.lock" 2>/dev/null
}

set_lock
inc_job_counter

small_flash_memory=$(uci_get_config "small_flash_memory")
github_address_mod=$(uci_get_config "github_address_mod" || echo 0)
restart=0

update_one() {
   local type="$1"
   local custom_key="$2"
   local tmpfile="$3"
   local path="$4"
   local name="$5"
   local min_size=10240
   local download_url=""

   local custom_url=$(uci_get_config "$custom_key")

   if [ "$small_flash_memory" != "1" ]; then
      mkdir -p /etc/openclash
   else
      mkdir -p /tmp/etc/openclash
   fi

   case "$type" in
      geoip)
         if [ -z "$custom_url" ]; then
            if [ "$github_address_mod" != "0" ]; then
               if [ "$github_address_mod" == "https://cdn.jsdelivr.net/" ] || [ "$github_address_mod" == "https://fastly.jsdelivr.net/" ] || [ "$github_address_mod" == "https://testingcf.jsdelivr.net/" ]; then
                  download_url="${github_address_mod}gh/Loyalsoldier/v2ray-rules-dat@release/geoip.dat"
               else
                  download_url="${github_address_mod}https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
               fi
            else
               download_url="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
            fi
         else
            download_url="$custom_url"
         fi
         ;;
      geosite)
         if [ -z "$custom_url" ]; then
            if [ "$github_address_mod" != "0" ]; then
               if [ "$github_address_mod" == "https://cdn.jsdelivr.net/" ] || [ "$github_address_mod" == "https://fastly.jsdelivr.net/" ] || [ "$github_address_mod" == "https://testingcf.jsdelivr.net/" ]; then
                  download_url="${github_address_mod}gh/Loyalsoldier/v2ray-rules-dat@release/geosite.dat"
               else
                  download_url="${github_address_mod}https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
               fi
            else
               download_url="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
            fi
         else
            download_url="$custom_url"
         fi
         ;;
      geoasn)
         if [ -z "$custom_url" ]; then
            if [ "$github_address_mod" != "0" ]; then
               if [ "$github_address_mod" == "https://cdn.jsdelivr.net/" ] || [ "$github_address_mod" == "https://fastly.jsdelivr.net/" ] || [ "$github_address_mod" == "https://testingcf.jsdelivr.net/" ]; then
                  download_url="${github_address_mod}gh/xishang0128/geoip@release/GeoLite2-ASN.mmdb"
               else
                  download_url="${github_address_mod}https://github.com/xishang0128/geoip/releases/latest/download/GeoLite2-ASN.mmdb"
               fi
            else
               download_url="https://github.com/xishang0128/geoip/releases/latest/download/GeoLite2-ASN.mmdb"
            fi
         else
            download_url="$custom_url"
         fi
         ;;
      ipdb)
         if [ -z "$custom_url" ]; then
            if [ "$github_address_mod" != "0" ]; then
               if [ "$github_address_mod" == "https://cdn.jsdelivr.net/" ] || [ "$github_address_mod" == "https://fastly.jsdelivr.net/" ] || [ "$github_address_mod" == "https://testingcf.jsdelivr.net/" ]; then
                  download_url="${github_address_mod}gh/alecthw/mmdb_china_ip_list@release/lite/Country.mmdb"
               else
                  download_url="${github_address_mod}https://raw.githubusercontent.com/alecthw/mmdb_china_ip_list/release/lite/Country.mmdb"
               fi
            else
               download_url="https://raw.githubusercontent.com/alecthw/mmdb_china_ip_list/release/lite/Country.mmdb"
            fi
         else
            download_url="$custom_url"
         fi
         ;;
      *)
         return 1
         ;;
   esac

   LOG_OUT "【$name】Start Downloading Database..."

   DOWNLOAD_FILE_CURL "$download_url" "/tmp/$tmpfile" "$path"
   DOWNLOAD_RESULT=$?
   if [ "$DOWNLOAD_RESULT" -eq 0 ] && [ -s "/tmp/$tmpfile" ]; then
      if head -c 512 "/tmp/$tmpfile" | grep -qiE "<!doctype|<html|<head|<body"; then
         LOG_OUT "【$name】Download Failed: HTML Response Detected, Abort Update..."
         rm -rf "/tmp/$tmpfile"
      elif [ $(du -b "/tmp/$tmpfile" 2>/dev/null | awk '{print $1}' || echo "$min_size") -lt "$min_size" ]; then
         LOG_OUT "【$name】Download Failed: File Size Too Small, Abort Update..."
         rm -rf "/tmp/$tmpfile"
      else
         LOG_OUT "【$name】Download Success, Check Updated..."
         cmp -s "/tmp/$tmpfile" "$path"
         if [ "$?" -ne 0 ]; then
            LOG_OUT "【$name】Has Been Updated, Starting To Replace The Old Version..."
            case "$type" in
               geoip)
                  rm -rf "/etc/openclash/geoip.dat"
                  ;;
               geosite)
                  rm -rf "/etc/openclash/geosite.dat"
                  ;;
               geoasn)
                  rm -rf "/etc/openclash/GeoLite2-ASN.mmdb"
                  ;;
            esac
            mv "/tmp/$tmpfile" "$path" >/dev/null 2>&1
            LOG_OUT "【$name】Update Successful!"
            restart=1
         else
            LOG_OUT "【$name】No Change, Do Nothing..."
         fi
      fi
   elif [ "$DOWNLOAD_RESULT" -eq 2 ]; then
        LOG_OUT "【$name】No Change, Do Nothing..."
   else
        LOG_OUT "【$name】Update Error, Please Try Again Later..."
   fi

   rm -rf "/tmp/$tmpfile" >/dev/null 2>&1
}

case "$1" in
   all)
      update_one geoip "geoip_custom_url" "GeoIP.dat" "/etc/openclash/GeoIP.dat" "GeoIP.dat"
      update_one geosite "geosite_custom_url" "GeoSite.dat" "/etc/openclash/GeoSite.dat" "GeoSite.dat"
      update_one geoasn "geoasn_custom_url" "GeoLite2-ASN.mmdb" "/etc/openclash/ASN.mmdb" "ASN.mmdb"
      update_one ipdb "geo_custom_url" "Country.mmdb" "/etc/openclash/Country.mmdb" "Country.mmdb"
      ;;
   geoip)
      update_one geoip "geoip_custom_url" "GeoIP.dat" "/etc/openclash/GeoIP.dat" "GeoIP.dat"
      ;;
   geosite)
      update_one geosite "geosite_custom_url" "GeoSite.dat" "/etc/openclash/GeoSite.dat" "GeoSite.dat"
      ;;
   geoasn)
      update_one geoasn "geoasn_custom_url" "GeoLite2-ASN.mmdb" "/etc/openclash/ASN.mmdb" "ASN.mmdb"
      ;;
   ipdb)
      update_one ipdb "geo_custom_url" "Country.mmdb" "/etc/openclash/Country.mmdb" "Country.mmdb"
      ;;
   *)
      echo "Usage: $0 {all|geoip|geosite|geoasn|ipdb}"
      del_lock
      dec_job_counter_and_restart "$restart"
      exit 1
      ;;
esac

dec_job_counter_and_restart "$restart"
del_lock
