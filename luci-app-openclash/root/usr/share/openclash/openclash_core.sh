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
UPDATE_SUCCESS=0
github_address_mod=$(uci_get_config "github_address_mod" || echo 0)
DIRECT_CORE_URL=""
if [ -n "$2" ] && echo "$2" | grep -qE '^https?://'; then
   DIRECT_CORE_URL="$2"
fi
if [ "$github_address_mod" = "0" ] && [ -z "$DIRECT_CORE_URL" ] && [ -z "$(echo $2 2>/dev/null |grep -E 'http|one_key_update')" ] && [ -z "$(echo $3 2>/dev/null |grep 'http')" ]; then
   LOG_TIP "If the download fails, try setting the CDN in Overwrite Settings - General Settings - GitHub Address Proxy Options"
fi
if [ -z "$DIRECT_CORE_URL" ]; then
   if [ -n "$3" ] && [ "$2" = "one_key_update" ]; then
      github_address_mod="$3"
   fi
   if [ -n "$2" ] && [ "$2" = "one_key_update" ] && [ -z "$3" ]; then
      github_address_mod=0
   fi
   if [ -n "$2" ] && [ "$2" != "one_key_update" ]; then
      github_address_mod="$2"
   fi
   if echo "$github_address_mod" | grep -q "raw\.githubusercontent\.com"; then
      github_address_mod=0
   fi
fi
CORE_TYPE="$1"
C_CORE_TYPE=$(uci_get_config "core_type")
SMART_ENABLE=$(uci_get_config "smart_enable" || echo 0)
OIX_TOKEN=$(uci_get_config "oix_token")
[ "$SMART_ENABLE" -eq 1 ] && CORE_TYPE="Smart"
[ -n "$OIX_TOKEN" ] && CORE_TYPE="Oix"
[ -z "$CORE_TYPE" ] && CORE_TYPE="Meta"
small_flash_memory=$(uci_get_config "small_flash_memory")
CPU_MODEL=$(uci_get_config "core_version")
RELEASE_BRANCH=$(uci_get_config "release_branch" || echo "master")

if [ -z "$DIRECT_CORE_URL" ]; then
   lua /usr/share/openclash/openclash_version.lua "$github_address_mod" 2>/dev/null
   if [ "$CORE_TYPE" = "Oix" ]; then
      CORE_LV=$(jsonfilter -i /tmp/openclash_version_history.json -e "@.oix.ver" 2>/dev/null)
   elif [ "$CORE_TYPE" = "Smart" ]; then
      CORE_LV=$(jsonfilter -i /tmp/openclash_version_history.json -e "@.${RELEASE_BRANCH}.latest.core_smart" 2>/dev/null)
   else
      CORE_LV=$(jsonfilter -i /tmp/openclash_version_history.json -e "@.${RELEASE_BRANCH}.latest.core_meta" 2>/dev/null)
   fi
   if [ -z "$CORE_LV" ]; then
      LOG_ERROR "【"$CORE_TYPE"】Core Version Check Error, Please Try Again Later..."
      del_lock
      exit 0
   fi
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
elif [ "$CORE_TYPE" = "Smart" ]; then
   CORE_URL_PATH="$RELEASE_BRANCH/smart"
   DOWNLOAD_FILE="/tmp/clash_meta.tar.gz"
else
   CORE_URL_PATH="$RELEASE_BRANCH/meta"
   DOWNLOAD_FILE="/tmp/clash_meta.tar.gz"
fi

[ "$C_CORE_TYPE" != "$CORE_TYPE" ] || [ -z "$C_CORE_TYPE" ] && restart=1

if [ -n "$DIRECT_CORE_URL" ] || [ "$CORE_CV" != "$CORE_LV" ] || [ -z "$CORE_CV" ]; then
   if [ "$CPU_MODEL" != 0 ]; then
      LOG_TIP "【"$CORE_TYPE"】Core Downloading, Please Try to Download and Upload Manually If Fails"
      # If $2 is a full download URL, use it directly
      if [ -n "$2" ] && echo "$2" | grep -qE '^https?://'; then
         DOWNLOAD_URL="$2"
      elif [ "$CORE_TYPE" = "Oix" ]; then
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
            gzip_test_err=$(gzip -t "$DOWNLOAD_FILE" 2>&1)

            if [ "$?" -eq 0 ]; then
               LOG_TIP "【"$CORE_TYPE"】Core Download Successful, Start Update..."
               extract_success=true
               extract_err=""
               [ -s "$DOWNLOAD_FILE" ] && {
                  if [ "$CORE_TYPE" = "Oix" ]; then
                     extract_err=$(gzip -dc "$DOWNLOAD_FILE" > "$TMP_FILE" 2>&1) || extract_success=false
                  else
                     extract_err=$(tar zxvfo "$DOWNLOAD_FILE" -C /tmp 2>&1) || extract_success=false
                     [ "$extract_success" = "true" ] && { extract_err=$(mv /tmp/clash "$TMP_FILE" 2>&1) || extract_success=false; }
                  fi
                  rm -rf "$DOWNLOAD_FILE" >/dev/null 2>&1
                  [ "$extract_success" = "true" ] && { extract_err=$(chmod 4755 "$TMP_FILE" 2>&1) || extract_success=false; }
                  [ "$extract_success" = "true" ] && { extract_err=$("$TMP_FILE" -v 2>&1) || extract_success=false; }
               }

               if [ "$extract_success" != "true" ]; then
                  if [ "$retry_count" -lt "$max_retries" ]; then
                     LOG_ERROR "【$retry_count/$max_retries】【"$CORE_TYPE"】Core Update Failed:【$(echo "$extract_err" | tr '\n' ' ' | head -c 300)】..."
                     rm -rf "$TMP_FILE" >/dev/null 2>&1
                     sleep 2
                     continue
                  else
                     LOG_ERROR "【"$CORE_TYPE"】Core Update Failed:【$(echo "$extract_err" | tr '\n' ' ' | head -c 300)】..."
                     rm -rf "$TMP_FILE" >/dev/null 2>&1
                     break
                  fi
               fi

               mv_err=$(mv -f "$TMP_FILE" "$TARGET_CORE_PATH" 2>&1)

               if [ "$?" == "0" ]; then
                  LOG_TIP "【"$CORE_TYPE"】Core Update Successful"
                  UPDATE_SUCCESS=1
                  restart=1
                  break
               else
                  if [ "$retry_count" -lt "$max_retries" ]; then
                     LOG_ERROR "【$retry_count/$max_retries】【"$CORE_TYPE"】Core Move Failed:【$(echo "$mv_err" | tr '\n' ' ' | head -c 300)】"
                     sleep 2
                     continue
                  else
                     LOG_ERROR "【"$CORE_TYPE"】Core Move Failed:【$(echo "$mv_err" | tr '\n' ' ' | head -c 300)】"
                     break
                  fi
               fi
            else
               if [ "$retry_count" -lt "$max_retries" ]; then
                  LOG_ERROR "【$retry_count/$max_retries】【"$CORE_TYPE"】Core Verification Failed:【$(echo "$gzip_test_err" | tr '\n' ' ' | head -c 300)】"
                  sleep 2
                  continue
               else
                  LOG_ERROR "【"$CORE_TYPE"】Core Verification Failed:【$(echo "$gzip_test_err" | tr '\n' ' ' | head -c 300)】"
                  break
               fi
            fi
         elif [ "$DOWNLOAD_RESULT" -eq 2 ]; then
            LOG_TIP "【"$CORE_TYPE"】Core Has Not Been Updated, Stop Continuing Operation"
         else
            if [ "$retry_count" -lt "$max_retries" ]; then
               LOG_ERROR "【$retry_count/$max_retries】【"$CORE_TYPE"】Core Download Failed, Please Check The Network or Try Again Later..."
               sleep 2
               continue
            else
               LOG_ERROR "【"$CORE_TYPE"】Core Download Failed, Please Check The Network or Try Again Later"
               break
            fi
         fi
      done
   else
      LOG_WARN "No Compiled Version Selected, Please Select In Update Page And Try Again!"
   fi
else
   LOG_TIP "【"$CORE_TYPE"】Core Has Not Been Updated, Stop Continuing Operation"
fi

rm -rf "$TMP_FILE" >/dev/null 2>&1
[ "$UPDATE_SUCCESS" = "1" ] && restart=1 || restart=0
dec_job_counter_and_restart "$restart"
del_lock
