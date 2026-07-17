#!/bin/bash
. /lib/functions.sh
. /usr/share/openclash/log.sh
. /usr/share/openclash/uci.sh
. /usr/share/openclash/openclash_curl.sh
. /usr/share/openclash/openclash_ps.sh

set_lock() {
   exec 872>"/tmp/lock/openclash_core.lock" 2>/dev/null
   flock -x 872 2>/dev/null
}

del_lock() {
   flock -u 872 2>/dev/null
   rm -rf "/tmp/lock/openclash_core.lock" 2>/dev/null
}

set_lock
inc_job_counter

restart=0
github_address_mod=$(uci_get_config "github_address_mod" || echo 0)
if [ "$github_address_mod" = "0" ] && [ -z "$(echo $2 2>/dev/null |grep -E 'http|one_key_update')" ] && [ -z "$(echo $3 2>/dev/null |grep 'http')" ]; then
   LOG_TIP "If the download fails, try setting the CDN in Overwrite Settings - General Settings - Github Address Modify Options"
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
OIX_TOKEN=$(uci_get_config "oix_token")
[ "$SMART_ENABLE" -eq 1 ] && CORE_TYPE="Smart"
[ "$CORE_TYPE" = "Oix" ] || [ -n "$OIX_TOKEN" ] && CORE_TYPE="Oix"
[ -z "$CORE_TYPE" ] && CORE_TYPE="Meta"
small_flash_memory=$(uci_get_config "small_flash_memory")
CPU_MODEL=$(uci_get_config "core_version")
RELEASE_BRANCH=$(uci_get_config "release_branch" || echo "master")

if [ "$github_address_mod" != "0" ]; then
   /usr/share/openclash/clash_version.sh "$github_address_mod" 2>/dev/null
else
   /usr/share/openclash/clash_version.sh 2>/dev/null
fi
if [ ! -f "/tmp/clash_last_version" ]; then
   LOG_ERROR "【"$CORE_TYPE"】Core Version Check Error, Please Try Again Later..."
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

TARGET_CORE_PATH="$meta_core_path"
CORE_CV=$($TARGET_CORE_PATH -v 2>/dev/null |awk -F ' ' '{print $3}' |head -1)
TMP_FILE="${TARGET_CORE_PATH}.new.$$"

if [ "$CORE_TYPE" = "Oix" ]; then
   CORE_URL_PATH=""
   DOWNLOAD_FILE="/tmp/clash_meta.gz"
   CORE_LV=$(sed -n 1p /tmp/clash_last_version 2>/dev/null)
elif [ "$CORE_TYPE" = "Smart" ]; then
   CORE_URL_PATH="$RELEASE_BRANCH/smart"
   DOWNLOAD_FILE="/tmp/clash_meta.tar.gz"
   CORE_LV=$(sed -n 2p /tmp/clash_last_version 2>/dev/null)
else
   CORE_URL_PATH="$RELEASE_BRANCH/meta"
   DOWNLOAD_FILE="/tmp/clash_meta.tar.gz"
   CORE_LV=$(sed -n 1p /tmp/clash_last_version 2>/dev/null)
fi

[ "$C_CORE_TYPE" != "$CORE_TYPE" ] || [ -z "$C_CORE_TYPE" ] && restart=1

if [ "$CORE_CV" != "$CORE_LV" ] || [ -z "$CORE_CV" ]; then
   if [ "$CPU_MODEL" != 0 ]; then
      LOG_TIP "【$CORE_TYPE】Core Downloading, Please Try to Download and Upload Manually If Fails"
      if [ "$CORE_TYPE" = "Oix" ]; then
         OIX_CORE_URL="https://github.com/vernesong/mihomo-oix/releases/download/Pre-Alpha/mihomo-${CPU_MODEL}-${CORE_LV}.gz"
         OIX_CORE_P_URL="https://dl.dler.io/mihomo-oix/mihomo-${CPU_MODEL}-${CORE_LV}.gz?tag=Pre-Alpha"
         if [ "$github_address_mod" != "0" ] && [ "$github_address_mod" != "https://cdn.jsdelivr.net/" ] && [ "$github_address_mod" != "https://fastly.jsdelivr.net/" ] && [ "$github_address_mod" != "https://testingcf.jsdelivr.net/" ]; then
            DOWNLOAD_URL="${github_address_mod}${OIX_CORE_URL}"
         else
            DOWNLOAD_URL="$OIX_CORE_P_URL"
         fi
      else
         if [ "$github_address_mod" != "0" ]; then
            if [ "$github_address_mod" == "https://cdn.jsdelivr.net/" ] || [ "$github_address_mod" == "https://fastly.jsdelivr.net/" ] || [ "$github_address_mod" == "https://testingcf.jsdelivr.net/" ]; then
               DOWNLOAD_URL="${github_address_mod}gh/vernesong/OpenClash@core/${CORE_URL_PATH}/clash-${CPU_MODEL}.tar.gz"
            else
               DOWNLOAD_URL="${github_address_mod}https://raw.githubusercontent.com/vernesong/OpenClash/core/${CORE_URL_PATH}/clash-${CPU_MODEL}.tar.gz"
            fi
         else
            DOWNLOAD_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/${CORE_URL_PATH}/clash-${CPU_MODEL}.tar.gz"
         fi
      fi

      retry_count=0
      max_retries=3

      while [ "$retry_count" -lt "$max_retries" ]; do
         retry_count=$((retry_count + 1))

         rm -rf "$DOWNLOAD_FILE" "$TMP_FILE" >/dev/null 2>&1

         SHOW_DOWNLOAD_PROGRESS=1 DOWNLOAD_FILE_CURL "$DOWNLOAD_URL" "$DOWNLOAD_FILE" "$TARGET_CORE_PATH"
         DOWNLOAD_RESULT=$?

         if [ "$DOWNLOAD_RESULT" -eq 0 ]; then
            gzip -t "$DOWNLOAD_FILE" >/dev/null 2>&1

            if [ "$?" -eq 0 ]; then
               LOG_TIP "【"$CORE_TYPE"】Core Download Successful, Start Update..."
               extract_success=true
               [ -s "$DOWNLOAD_FILE" ] && {
                  if [ "$CORE_TYPE" = "Oix" ]; then
                     gzip -dc "$DOWNLOAD_FILE" > "$TMP_FILE" 2>/dev/null || extract_success=false
                  else
                     tar zxvfo "$DOWNLOAD_FILE" -C /tmp >/dev/null 2>&1 || extract_success=false
                     mv /tmp/clash "$TMP_FILE" >/dev/null 2>&1 || extract_success=false
                  fi
                  rm -rf "$DOWNLOAD_FILE" >/dev/null 2>&1
                  chmod 4755 "$TMP_FILE" >/dev/null 2>&1 || extract_success=false
                  "$TMP_FILE" -v >/dev/null 2>&1 || extract_success=false
               }

               if [ "$extract_success" != "true" ]; then
                  if [ "$retry_count" -lt "$max_retries" ]; then
                     LOG_ERROR "【$retry_count/$max_retries】【"$CORE_TYPE"】Core Update Failed..."
                     rm -rf "$TMP_FILE" >/dev/null 2>&1
                     sleep 2
                     continue
                  else
                     LOG_ERROR "【"$CORE_TYPE"】Core Update Failed, Please Make Sure Enough Flash Memory Space or Selected Correct Core Platform And Try Again!"
                     rm -rf "$TMP_FILE" >/dev/null 2>&1
                     SLOG_CLEAN
                     del_lock
                     exit 0
                  fi
               fi

               mv -f "$TMP_FILE" "$TARGET_CORE_PATH" >/dev/null 2>&1

               if [ "$?" == "0" ]; then
                  LOG_TIP "【"$CORE_TYPE"】Core Update Successful!"
                  SLOG_CLEAN
                  restart=1
                  break
               else
                  if [ "$retry_count" -lt "$max_retries" ]; then
                     LOG_ERROR "【$retry_count/$max_retries】【"$CORE_TYPE"】Core Update Failed..."
                     sleep 2
                     continue
                  else
                     LOG_ERROR "【"$CORE_TYPE"】Core Update Failed, Please Make Sure Enough Flash Memory Space And Try Again!"
                     SLOG_CLEAN
                     break
                  fi
               fi
            else
               if [ "$retry_count" -lt "$max_retries" ]; then
                  LOG_ERROR "【$retry_count/$max_retries】【"$CORE_TYPE"】Core Update Failed..."
                  sleep 2
                  continue
               else
                  LOG_ERROR "【"$CORE_TYPE"】Core Update Failed, Please Check The Network or Try Again Later!"
                  SLOG_CLEAN
                  break
               fi
            fi
         elif [ "$DOWNLOAD_RESULT" -eq 2 ]; then
            LOG_TIP "【"$CORE_TYPE"】Core Has Not Been Updated, Stop Continuing Operation!"
            SLOG_CLEAN
         else
            if [ "$retry_count" -lt "$max_retries" ]; then
               LOG_ERROR "【$retry_count/$max_retries】【"$CORE_TYPE"】Core Download Failed..."
               sleep 2
               continue
            else
               LOG_ERROR "【"$CORE_TYPE"】Core Download Failed, Please Check The Network or Try Again Later!"
               SLOG_CLEAN
               break
            fi
         fi
      done
   else
      LOG_WARN "No Compiled Version Selected, Please Select In Update Page And Try Again!"
      SLOG_CLEAN
   fi
else
   LOG_TIP "【"$CORE_TYPE"】Core Has Not Been Updated, Stop Continuing Operation!"
   SLOG_CLEAN
fi

rm -rf "$TMP_FILE" >/dev/null 2>&1
dec_job_counter_and_restart "$restart"
del_lock
