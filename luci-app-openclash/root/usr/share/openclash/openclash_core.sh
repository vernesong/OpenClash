#!/bin/bash
. /lib/functions.sh
. /usr/share/openclash/openclash_ps.sh
. /usr/share/openclash/log.sh
. /usr/share/openclash/openclash_curl.sh
. /usr/share/openclash/uci.sh

set_lock() {
   exec 872>"/tmp/lock/openclash_core.lock" 2>/dev/null
   flock -x 872 2>/dev/null
}

del_lock() {
   flock -u 872 2>/dev/null
   rm -rf "/tmp/lock/openclash_core.lock" 2>/dev/null
}

set_lock

github_address_mod=$(uci_get_config "github_address_mod" || echo 0)
if [ "$github_address_mod" = "0" ] && [ -z "$(echo $2 2>/dev/null |grep -E 'http|one_key_update')" ] && [ -z "$(echo $3 2>/dev/null |grep 'http')" ]; then
   LOG_OUT "Tip: If the download fails, try setting the CDN in Overwrite Settings - General Settings - Github Address Modify Options"
fi
if [ -n "$3" ] && [ "$2" = "one_key_update" ]; then
   github_address_mod="$3"
fi
if [ -n "$2" ] && [ "$2" = "one_key_update" ] && [ -z "$3" ]; then
   github_address_mod=0
fi
if [ -n "$2" ] && [ "$2" != "one_key_update" ]; then
   github_address_mod="$2"
fi
CORE_TYPE="$1"
C_CORE_TYPE=$(uci_get_config "core_type")
SMART_ENABLE=$(uci_get_config "smart_enable" || echo 0)
[ "$SMART_ENABLE" -eq 1 ] && CORE_TYPE="Smart"
[ -z "$CORE_TYPE" ] && CORE_TYPE="Meta"
small_flash_memory=$(uci_get_config "small_flash_memory")
CPU_MODEL=$(uci_get_config "core_version")
RELEASE_BRANCH=$(uci_get_config "release_branch" || echo "master")

if [ "$github_address_mod" != "0" ]; then
   [ ! -f "/tmp/clash_last_version" ] && /usr/share/openclash/clash_version.sh "$github_address_mod" 2>/dev/null
else
   [ ! -f "/tmp/clash_last_version" ] && /usr/share/openclash/clash_version.sh 2>/dev/null
fi
if [ ! -f "/tmp/clash_last_version" ]; then
   LOG_OUT "Error: 【"$CORE_TYPE"】Core Version Check Error, Please Try Again Later..."
   SLOG_CLEAN
   del_lock
   exit 0
fi

if [ "$small_flash_memory" != "1" ]; then
   meta_core_path="/etc/openclash/core/clash_meta"
   mkdir -p /etc/openclash/core
else
   meta_core_path="/tmp/etc/openclash/core/clash_meta"
   mkdir -p /tmp/etc/openclash/core
fi

CORE_CV=$($meta_core_path -v 2>/dev/null |awk -F ' ' '{print $3}' |head -1)
DOWNLOAD_FILE="/tmp/clash_meta.tar.gz"
TMP_FILE="/tmp/clash_meta"
TARGET_CORE_PATH="$meta_core_path"

if [ "$CORE_TYPE" = "Smart" ]; then
   CORE_URL_PATH="$RELEASE_BRANCH/smart"
   CORE_LV=$(sed -n 2p /tmp/clash_last_version 2>/dev/null)
else
   CORE_URL_PATH="$RELEASE_BRANCH/meta"
   CORE_LV=$(sed -n 1p /tmp/clash_last_version 2>/dev/null)
fi

[ "$C_CORE_TYPE" = "$CORE_TYPE" ] || [ -z "$C_CORE_TYPE" ] && if_restart=1

if [ "$CORE_CV" != "$CORE_LV" ] || [ -z "$CORE_CV" ]; then
   if [ "$CPU_MODEL" != 0 ]; then
      LOG_OUT "Tip:【$CORE_TYPE】Core Downloading, Please Try to Download and Upload Manually If Fails"
      if [ "$github_address_mod" != "0" ]; then
         if [ "$github_address_mod" == "https://cdn.jsdelivr.net/" ] || [ "$github_address_mod" == "https://fastly.jsdelivr.net/" ] || [ "$github_address_mod" == "https://testingcf.jsdelivr.net/" ]; then
            DOWNLOAD_URL="${github_address_mod}gh/vernesong/OpenClash@core/${CORE_URL_PATH}/clash-${CPU_MODEL}.tar.gz"
         else
            DOWNLOAD_URL="${github_address_mod}https://raw.githubusercontent.com/vernesong/OpenClash/core/${CORE_URL_PATH}/clash-${CPU_MODEL}.tar.gz"
         fi
      else
         DOWNLOAD_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/${CORE_URL_PATH}/clash-${CPU_MODEL}.tar.gz"
      fi

      retry_count=0
      max_retries=3

      while [ "$retry_count" -lt "$max_retries" ]; do
         retry_count=$((retry_count + 1))

         rm -rf "$DOWNLOAD_FILE" "$TMP_FILE" >/dev/null 2>&1
         
         SHOW_DOWNLOAD_PROGRESS=1 DOWNLOAD_FILE_CURL "$DOWNLOAD_URL" "$DOWNLOAD_FILE"
         download_result=$?
         
         if [ "$download_result" -eq 0 ]; then
            gzip -t "$DOWNLOAD_FILE" >/dev/null 2>&1

            if [ "$?" -eq 0 ]; then
               LOG_OUT "Tip:【"$CORE_TYPE"】Core Download Successful, Start Update..."
               extract_success=true
               [ -s "$DOWNLOAD_FILE" ] && {
                  tar zxvfo "$DOWNLOAD_FILE" -C /tmp >/dev/null 2>&1 || extract_success=false
                  mv /tmp/clash "$TMP_FILE" >/dev/null 2>&1 || extract_success=false
                  rm -rf "$DOWNLOAD_FILE" >/dev/null 2>&1
                  chmod 4755 "$TMP_FILE" >/dev/null 2>&1 || extract_success=false
                  "$TMP_FILE" -v >/dev/null 2>&1 || extract_success=false
               }
                  
               if [ "$extract_success" != "true" ]; then
                  if [ "$retry_count" -lt "$max_retries" ]; then
                     LOG_OUT "Error:【$retry_count/$max_retries】【"$CORE_TYPE"】Core Update Failed..."
                     rm -rf "$TMP_FILE" >/dev/null 2>&1
                     sleep 2
                     continue
                  else
                     LOG_OUT "Error:【"$CORE_TYPE"】Core Update Failed, Please Make Sure Enough Flash Memory Space or Selected Correct Core Platform And Try Again!"
                     rm -rf "$TMP_FILE" >/dev/null 2>&1
                     SLOG_CLEAN
                     del_lock
                     exit 0
                  fi
               fi

               mv "$TMP_FILE" "$TARGET_CORE_PATH" >/dev/null 2>&1

               if [ "$?" == "0" ]; then
                  LOG_OUT "Tip:【"$CORE_TYPE"】Core Update Successful!"
                  if [ "$if_restart" -eq 1 ]; then
                     uci -q set openclash.config.restart=1
                     uci -q commit openclash
                     if ([ -z "$2" ] || ([ -n "$2" ] && [ "$2" != "one_key_update" ])) && [ "$(unify_ps_prevent)" -eq 0 ]; then
                        uci -q set openclash.config.restart=0
                        uci -q commit openclash
                        /etc/init.d/openclash restart >/dev/null 2>&1 &
                     fi
                  else
                     SLOG_CLEAN
                  fi
                  break
               else
                  if [ "$retry_count" -lt "$max_retries" ]; then
                     LOG_OUT "Error:【$retry_count/$max_retries】【"$CORE_TYPE"】Core Update Failed..."
                     sleep 2
                     continue
                  else
                     LOG_OUT "Error:【"$CORE_TYPE"】Core Update Failed, Please Make Sure Enough Flash Memory Space And Try Again!"
                     SLOG_CLEAN
                     break
                  fi
               fi
            else
               if [ "$retry_count" -lt "$max_retries" ]; then
                  LOG_OUT "Error:【$retry_count/$max_retries】【"$CORE_TYPE"】Core Update Failed..."
                  sleep 2
                  continue
               else
                  LOG_OUT "Error:【"$CORE_TYPE"】Core Update Failed, Please Check The Network or Try Again Later!"
                  SLOG_CLEAN
                  break
               fi
            fi
         else
            if [ "$retry_count" -lt "$max_retries" ]; then
               LOG_OUT "Error:【$retry_count/$max_retries】【"$CORE_TYPE"】Core Download Failed..."
               sleep 2
               continue
            else
               LOG_OUT "Error:【"$CORE_TYPE"】Core Download Failed, Please Check The Network or Try Again Later!"
               SLOG_CLEAN
               break
            fi
         fi
      done
   else
      LOG_OUT "Warning: No Compiled Version Selected, Please Select In Update Page And Try Again!"
      SLOG_CLEAN
   fi
else
   LOG_OUT "Tip:【"$CORE_TYPE"】Core Has Not Been Updated, Stop Continuing Operation!"
   SLOG_CLEAN
fi

rm -rf "$TMP_FILE" >/dev/null 2>&1
del_lock
