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
RUST_ENABLE=$(uci_get_config "rust_enable" || echo 0)
[ "$SMART_ENABLE" -eq 1 ] && CORE_TYPE="Smart"
[ "$RUST_ENABLE" -eq 1 ] && CORE_TYPE="Rust"
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
   rust_core_path="/etc/openclash/core/clash_rs"
   mkdir -p /etc/openclash/core
else
   meta_core_path="/tmp/etc/openclash/core/clash_meta"
   rust_core_path="/tmp/etc/openclash/core/clash_rs"
   mkdir -p /tmp/etc/openclash/core
fi

if [ "$CORE_TYPE" = "Rust" ]; then
   CORE_CV=$($rust_core_path -v 2>/dev/null |awk -F ' ' '{print $3}' |head -1)
   DOWNLOAD_FILE="/tmp/clash_rs"
   TMP_FILE="/tmp/clash_rs_tmp"
   TARGET_CORE_PATH="$rust_core_path"
   CORE_LV=$(sed -n 3p /tmp/clash_last_version 2>/dev/null)
elif [ "$CORE_TYPE" = "Smart" ]; then
   CORE_CV=$($meta_core_path -v 2>/dev/null |awk -F ' ' '{print $3}' |head -1)
   DOWNLOAD_FILE="/tmp/clash_meta.tar.gz"
   TMP_FILE="/tmp/clash_meta"
   TARGET_CORE_PATH="$meta_core_path"
   CORE_URL_PATH="$RELEASE_BRANCH/smart"
   CORE_LV=$(sed -n 2p /tmp/clash_last_version 2>/dev/null)
else
   CORE_CV=$($meta_core_path -v 2>/dev/null |awk -F ' ' '{print $3}' |head -1)
   DOWNLOAD_FILE="/tmp/clash_meta.tar.gz"
   TMP_FILE="/tmp/clash_meta"
   TARGET_CORE_PATH="$meta_core_path"
   CORE_URL_PATH="$RELEASE_BRANCH/meta"
   CORE_LV=$(sed -n 1p /tmp/clash_last_version 2>/dev/null)
fi

[ "$C_CORE_TYPE" = "$CORE_TYPE" ] || [ -z "$C_CORE_TYPE" ] && restart=1

if [ "$CORE_CV" != "$CORE_LV" ] || [ -z "$CORE_CV" ]; then
   if [ "$CPU_MODEL" != 0 ]; then
      LOG_TIP "【$CORE_TYPE】Core Downloading, Please Try to Download and Upload Manually If Fails"
      if [ "$CORE_TYPE" = "Rust" ]; then
         case "$CPU_MODEL" in
            "linux-amd64-v1" | "linux-amd64-v2" | "linux-amd64-v3")
               RUST_ARCH="x86_64-unknown-linux-musl"
               ;;
            "linux-arm64")
               RUST_ARCH="aarch64-unknown-linux-musl"
               ;;
            "linux-armv7")
               RUST_ARCH="armv7-unknown-linux-musleabihf"
               ;;
            "linux-386")
               RUST_ARCH="i686-unknown-linux-musl"
               ;;
            "linux-mipsle-softfloat" | "linux-mipsle-hardfloat")
               RUST_ARCH="mipsel-unknown-linux-musl"
               ;;
            "linux-mips-softfloat" | "linux-mips-hardfloat")
               RUST_ARCH="mips-unknown-linux-musl"
               ;;
            "linux-riscv64")
               RUST_ARCH="riscv64gc-unknown-linux-gnu"
               ;;
            *)
               LOG_ERROR "【$CORE_TYPE】Core Download Failed, Unsupported Architecture: $CPU_MODEL"
               SLOG_CLEAN
               del_lock
               exit 0
               ;;
         esac
         if [ "$github_address_mod" != "0" ]; then
            DOWNLOAD_URL="${github_address_mod}https://github.com/Watfaq/clash-rs/releases/download/${CORE_LV}/clash-rs-${RUST_ARCH}"
         else
            DOWNLOAD_URL="https://github.com/Watfaq/clash-rs/releases/download/${CORE_LV}/clash-rs-${RUST_ARCH}"
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
            if [ "$CORE_TYPE" != "Rust" ]; then
               gzip -t "$DOWNLOAD_FILE" >/dev/null 2>&1
               if [ "$?" -eq 0 ]; then
                  LOG_TIP "【"$CORE_TYPE"】Core Download Successful, Start Update..."
                  extract_success=true
                  [ -s "$DOWNLOAD_FILE" ] && {
                     tar zxvfo "$DOWNLOAD_FILE" -C /tmp >/dev/null 2>&1 || extract_success=false
                     mv /tmp/clash "$TMP_FILE" >/dev/null 2>&1 || extract_success=false
                     rm -rf "$DOWNLOAD_FILE" >/dev/null 2>&1
                     chmod 4755 "$TMP_FILE" >/dev/null 2>&1 || extract_success=false
                     "$TMP_FILE" -v >/dev/null 2>&1 || extract_success=false
                  }
               else
                  extract_success=false
               fi
            else
               LOG_TIP "【"$CORE_TYPE"】Core Download Successful, Start Update..."
               extract_success=true
               [ -s "$DOWNLOAD_FILE" ] && {
                  mv "$DOWNLOAD_FILE" "$TMP_FILE" >/dev/null 2>&1 || extract_success=false
                  chmod 4755 "$TMP_FILE" >/dev/null 2>&1 || extract_success=false
                  "$TMP_FILE" -v >/dev/null 2>&1 || extract_success=false
               }
            fi

            if [ "$extract_success" = "true" ]; then


               mv "$TMP_FILE" "$TARGET_CORE_PATH" >/dev/null 2>&1

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
