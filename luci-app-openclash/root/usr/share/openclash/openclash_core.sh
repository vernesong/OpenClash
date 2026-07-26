#!/bin/bash

OPENCLASH_LIB_DIR="${OPENCLASH_LIB_DIR:-/usr/share/openclash}"
OPENCLASH_LOCK_DIR="${OPENCLASH_LOCK_DIR:-/tmp/lock}"
OPENCLASH_RUN_ROOT="${OPENCLASH_RUN_ROOT:-/tmp}"
CLASH_VERSION_SH="${OPENCLASH_CLASH_VERSION_SH:-${OPENCLASH_LIB_DIR}/clash_version.sh}"
CORE_VERSION_FILE="${OPENCLASH_CORE_VERSION_FILE:-/tmp/clash_last_version}"
AUTO_MODE="${OPENCLASH_AUTO_VERSION_UPDATE:-0}"
CORE_RESULT_FILE="${OPENCLASH_CORE_RESULT_FILE:-}"
CORE_LOCK="${OPENCLASH_LOCK_DIR}/openclash_core.lock"
CORE_LOCKED=0
CORE_CLEANED=0
JOB_COUNTED=0
RESTART_REQUIRED=0
CORE_RUN_DIR=""
TMP_FILE=""

. "${OPENCLASH_LIB_DIR}/log.sh"
. "${OPENCLASH_LIB_DIR}/uci.sh"
. "${OPENCLASH_LIB_DIR}/openclash_curl.sh"
. "${OPENCLASH_LIB_DIR}/openclash_ps.sh"

write_core_result() {
   local value="$1"
   local result_tmp
   [ -n "$CORE_RESULT_FILE" ] || return 0
   result_tmp="${CORE_RESULT_FILE}.tmp.$$"
   printf '%s\n' "$value" > "$result_tmp" && mv -f "$result_tmp" "$CORE_RESULT_FILE"
}

set_lock() {
   mkdir -p "$OPENCLASH_LOCK_DIR" 2>/dev/null || return 1
   exec 872>"$CORE_LOCK" 2>/dev/null || return 1
   if [ "$AUTO_MODE" = "1" ]; then
      flock -n 872 2>/dev/null || return 1
   else
      flock -x 872 2>/dev/null || return 1
   fi
   CORE_LOCKED=1
}

del_lock() {
   [ "$CORE_LOCKED" = "1" ] || return 0
   flock -u 872 2>/dev/null
   CORE_LOCKED=0
}

cleanup_core_update() {
   [ "$CORE_CLEANED" = "0" ] || return 0
   CORE_CLEANED=1

   [ -n "$TMP_FILE" ] && rm -f "$TMP_FILE" >/dev/null 2>&1
   if [ -n "$CORE_RUN_DIR" ] && [ -d "$CORE_RUN_DIR" ]; then
      case "$CORE_RUN_DIR" in
         "$OPENCLASH_RUN_ROOT"/openclash-core.*|*/openclash-auto-version.*/core.*)
            rm -rf "$CORE_RUN_DIR" >/dev/null 2>&1
         ;;
      esac
   fi

   if [ "$JOB_COUNTED" = "1" ]; then
      dec_job_counter_and_restart "$RESTART_REQUIRED"
      JOB_COUNTED=0
   fi
   del_lock
}

finish_core_update() {
   local status="$1"
   SLOG_CLEAN
   cleanup_core_update
   trap - EXIT INT TERM
   exit "$status"
}

fail_core_update() {
   local status="$1"
   local result="$2"
   local message="$3"
   write_core_result "$result"
   [ -n "$message" ] && LOG_ERROR "$message"
   finish_core_update "$status"
}

trap cleanup_core_update EXIT
trap 'fail_core_update 130 "failed:interrupted" ""' INT
trap 'fail_core_update 143 "failed:interrupted" ""' TERM

if ! set_lock; then
   write_core_result "busy"
   exit 75
fi

if [ "$AUTO_MODE" != "1" ]; then
   inc_job_counter
   JOB_COUNTED=1
fi

github_address_mod=$(uci_get_config "github_address_mod" || echo 0)
if [ "$2" = "one_key_update" ] || [ "$2" = "auto_version_update" ]; then
   if [ -n "$3" ]; then
      github_address_mod="$3"
   else
      github_address_mod=0
   fi
elif [ -n "$2" ]; then
   github_address_mod="$2"
fi

CORE_TYPE="$1"
C_CORE_TYPE=$(uci_get_config "core_type")
SMART_ENABLE=$(uci_get_config "smart_enable" || echo 0)
OIX_TOKEN=$(uci_get_config "oix_token")
[ "$SMART_ENABLE" = "1" ] && CORE_TYPE="Smart"
if [ "$C_CORE_TYPE" = "Oix" ] || [ -n "$OIX_TOKEN" ]; then
   CORE_TYPE="Oix"
fi
[ -z "$CORE_TYPE" ] && CORE_TYPE="Meta"

small_flash_memory=$(uci_get_config "small_flash_memory" || echo 0)
CPU_MODEL=$(uci_get_config "core_version" || echo 0)
RELEASE_BRANCH=$(uci_get_config "release_branch" || echo "master")

if [ "$github_address_mod" = "0" ] && [ "$AUTO_MODE" != "1" ] &&
   [ "$2" != "one_key_update" ]; then
   LOG_TIP "If the download fails, try setting the CDN in Overwrite Settings - General Settings - Github Address Modify Options"
fi

if [ "$github_address_mod" != "0" ]; then
   OPENCLASH_LIB_DIR="$OPENCLASH_LIB_DIR" \
   OPENCLASH_LOCK_DIR="$OPENCLASH_LOCK_DIR" \
   OPENCLASH_CORE_VERSION_FILE="$CORE_VERSION_FILE" \
   OPENCLASH_AUTO_VERSION_UPDATE="$AUTO_MODE" \
      bash "$CLASH_VERSION_SH" "$github_address_mod" 2>/dev/null
else
   OPENCLASH_LIB_DIR="$OPENCLASH_LIB_DIR" \
   OPENCLASH_LOCK_DIR="$OPENCLASH_LOCK_DIR" \
   OPENCLASH_CORE_VERSION_FILE="$CORE_VERSION_FILE" \
   OPENCLASH_AUTO_VERSION_UPDATE="$AUTO_MODE" \
      bash "$CLASH_VERSION_SH" 2>/dev/null
fi
version_status=$?

case "$version_status" in
   0) ;;
   75) fail_core_update 75 "busy" "Core version check is busy; automatic update skipped." ;;
   *) fail_core_update 76 "retry:version" "【${CORE_TYPE}】Core Version Check Error, Please Try Again Later..." ;;
esac

if [ -n "${OPENCLASH_CORE_TARGET_PATH:-}" ]; then
   TARGET_CORE_PATH="$OPENCLASH_CORE_TARGET_PATH"
elif [ "$small_flash_memory" != "1" ]; then
   TARGET_CORE_PATH="/etc/openclash/core/clash_meta"
else
   TARGET_CORE_PATH="/tmp/etc/openclash/core/clash_meta"
fi
mkdir -p "$(dirname "$TARGET_CORE_PATH")" ||
   fail_core_update 1 "failed:staging" "【${CORE_TYPE}】Failed to create core directory."

CORE_CV=$("$TARGET_CORE_PATH" -v 2>/dev/null | awk -F ' ' '{print $3}' | head -1)
TMP_FILE="${TARGET_CORE_PATH}.new.$$"

if [ "$CORE_TYPE" = "Oix" ]; then
   CORE_URL_PATH=""
   archive_name="clash_meta.gz"
   CORE_LV=$(sed -n '1p' "$CORE_VERSION_FILE" 2>/dev/null)
elif [ "$CORE_TYPE" = "Smart" ]; then
   CORE_URL_PATH="${RELEASE_BRANCH}/smart"
   archive_name="clash_meta.tar.gz"
   CORE_LV=$(sed -n '2p' "$CORE_VERSION_FILE" 2>/dev/null)
else
   CORE_URL_PATH="${RELEASE_BRANCH}/meta"
   archive_name="clash_meta.tar.gz"
   CORE_LV=$(sed -n '1p' "$CORE_VERSION_FILE" 2>/dev/null)
fi

if [ -z "$CORE_LV" ]; then
   fail_core_update 76 "retry:version" "【${CORE_TYPE}】Core version information is empty."
fi

if [ "$CORE_CV" = "$CORE_LV" ]; then
   write_core_result "current"
   LOG_TIP "【${CORE_TYPE}】Core Has Not Been Updated, Stop Continuing Operation!"
   finish_core_update 0
fi

if [ -z "$CPU_MODEL" ] || [ "$CPU_MODEL" = "0" ]; then
   fail_core_update 1 "failed:platform" "No Compiled Version Selected, Please Select In Update Page And Try Again!"
fi

umask 077
if [ -n "${OPENCLASH_AUTO_RUN_DIR:-}" ]; then
   CORE_RUN_DIR=$(mktemp -d "${OPENCLASH_AUTO_RUN_DIR}/core.XXXXXX") ||
      fail_core_update 1 "failed:staging" "【${CORE_TYPE}】Failed to create core staging directory."
else
   CORE_RUN_DIR=$(mktemp -d "${OPENCLASH_RUN_ROOT}/openclash-core.XXXXXX") ||
      fail_core_update 1 "failed:staging" "【${CORE_TYPE}】Failed to create core staging directory."
fi
chmod 700 "$CORE_RUN_DIR" 2>/dev/null
DOWNLOAD_FILE="${CORE_RUN_DIR}/${archive_name}"
EXTRACT_DIR="${CORE_RUN_DIR}/extract"

if [ "$CORE_TYPE" = "Oix" ]; then
   OIX_CORE_URL="https://github.com/vernesong/mihomo-oix/releases/download/Pre-Alpha/mihomo-${CPU_MODEL}-${CORE_LV}.gz"
   OIX_CORE_P_URL="https://dl.dler.io/mihomo-oix/mihomo-${CPU_MODEL}-${CORE_LV}.gz?tag=Pre-Alpha"
   if [ "$github_address_mod" != "0" ] &&
      [ "$github_address_mod" != "https://cdn.jsdelivr.net/" ] &&
      [ "$github_address_mod" != "https://fastly.jsdelivr.net/" ] &&
      [ "$github_address_mod" != "https://testingcf.jsdelivr.net/" ]; then
      DOWNLOAD_URL="${github_address_mod}${OIX_CORE_URL}"
   else
      DOWNLOAD_URL="$OIX_CORE_P_URL"
   fi
elif [ "$github_address_mod" != "0" ]; then
   case "$github_address_mod" in
      https://cdn.jsdelivr.net/|https://fastly.jsdelivr.net/|https://testingcf.jsdelivr.net/)
         DOWNLOAD_URL="${github_address_mod}gh/vernesong/OpenClash@core/${CORE_URL_PATH}/clash-${CPU_MODEL}.tar.gz"
      ;;
      *)
         DOWNLOAD_URL="${github_address_mod}https://raw.githubusercontent.com/vernesong/OpenClash/core/${CORE_URL_PATH}/clash-${CPU_MODEL}.tar.gz"
      ;;
   esac
else
   DOWNLOAD_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/${CORE_URL_PATH}/clash-${CPU_MODEL}.tar.gz"
fi

LOG_TIP "【${CORE_TYPE}】Core Downloading, Please Try to Download and Upload Manually If Fails"
LOG_TIP "【${CORE_TYPE}】Core update:【${CORE_CV:-not installed} -> ${CORE_LV}】"
download_try=0
max_download_tries=3
[ "$AUTO_MODE" = "1" ] && max_download_tries=1

while [ "$download_try" -lt "$max_download_tries" ]; do
   download_try=$((download_try + 1))
   rm -f "$DOWNLOAD_FILE" "$TMP_FILE" >/dev/null 2>&1

   SHOW_DOWNLOAD_PROGRESS=1 DOWNLOAD_FILE_CURL "$DOWNLOAD_URL" "$DOWNLOAD_FILE" "$TARGET_CORE_PATH"
   download_status=$?

   if [ "$download_status" -eq 2 ]; then
      write_core_result "current"
      LOG_TIP "【${CORE_TYPE}】Core Has Not Been Updated, Stop Continuing Operation!"
      finish_core_update 0
   fi

   if [ "$download_status" -ne 0 ] || [ ! -s "$DOWNLOAD_FILE" ]; then
      [ "$download_try" -lt "$max_download_tries" ] && sleep 2
      continue
   fi

   if ! gzip -t "$DOWNLOAD_FILE" >/dev/null 2>&1; then
      if [ "$AUTO_MODE" = "1" ]; then
         fail_core_update 76 "retry:archive" "【${CORE_TYPE}】Core archive validation failed; trying another source."
      fi
      fail_core_update 1 "failed:archive" "【${CORE_TYPE}】Core archive validation failed."
   fi

   if [ "$CORE_TYPE" = "Oix" ]; then
      gzip -dc "$DOWNLOAD_FILE" > "$TMP_FILE" 2>/dev/null
      extract_status=$?
   else
      mkdir -p "$EXTRACT_DIR"
      tar -xzf "$DOWNLOAD_FILE" -C "$EXTRACT_DIR" >/dev/null 2>&1
      extract_status=$?
      if [ "$extract_status" -eq 0 ] && [ -s "${EXTRACT_DIR}/clash" ]; then
         mv -f "${EXTRACT_DIR}/clash" "$TMP_FILE" >/dev/null 2>&1
         extract_status=$?
      else
         extract_status=1
      fi
   fi

   if [ "$extract_status" -ne 0 ] || [ ! -s "$TMP_FILE" ]; then
      if [ "$AUTO_MODE" = "1" ]; then
         fail_core_update 76 "retry:extract" "【${CORE_TYPE}】Core extraction failed; trying another source."
      fi
      fail_core_update 1 "failed:extract" "【${CORE_TYPE}】Core extraction failed."
   fi

   chmod 4755 "$TMP_FILE" >/dev/null 2>&1 &&
      "$TMP_FILE" -v >/dev/null 2>&1
   validation_status=$?
   if [ "$validation_status" -ne 0 ]; then
      fail_core_update 1 "failed:validation" "【${CORE_TYPE}】Downloaded core failed validation."
   fi

   if mv -f "$TMP_FILE" "$TARGET_CORE_PATH" >/dev/null 2>&1; then
      TMP_FILE=""
      RESTART_REQUIRED=1
      write_core_result "updated:${CORE_LV}"
      LOG_TIP "【${CORE_TYPE}】Core Update Successful!"
      finish_core_update 0
   fi

   fail_core_update 1 "failed:replace" "【${CORE_TYPE}】Core atomic replacement failed."
done

fail_core_update 76 "retry:download" "【${CORE_TYPE}】Core Download Failed, Please Check The Network or Try Again Later!"
