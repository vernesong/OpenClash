#!/bin/bash

OPENCLASH_LIB_DIR="${OPENCLASH_LIB_DIR:-/usr/share/openclash}"
OPENCLASH_LOCK_DIR="${OPENCLASH_LOCK_DIR:-/tmp/lock}"
OPENCLASH_RUN_ROOT="${OPENCLASH_RUN_ROOT:-/tmp}"
OPENCLASH_INSTALLER_SH="${OPENCLASH_INSTALLER_SH:-${OPENCLASH_LIB_DIR}/openclash_update_install.sh}"
OPKG_BIN="${OPENCLASH_OPKG_BIN:-/bin/opkg}"
APK_BIN="${OPENCLASH_APK_BIN:-/usr/bin/apk}"
AUTO_MODE="${OPENCLASH_AUTO_VERSION_UPDATE:-0}"
PACKAGE_ONLY="${OPENCLASH_PACKAGE_ONLY:-0}"
PACKAGE_RESULT_FILE="${OPENCLASH_PACKAGE_RESULT_FILE:-}"
UPDATE_LOCK="${OPENCLASH_LOCK_DIR}/openclash_update.lock"
INSTALL_LOCK="${OPENCLASH_LOCK_DIR}/openclash_update_install.lock"
UPDATE_LOCKED=0
UPDATE_CLEANED=0
JOB_COUNTED=0
RUN_DIR=""

. "${OPENCLASH_LIB_DIR}/log.sh"
. "${OPENCLASH_LIB_DIR}/uci.sh"
. "${OPENCLASH_LIB_DIR}/openclash_curl.sh"
. "${OPENCLASH_LIB_DIR}/openclash_ps.sh"

write_package_result() {
   local value="$1"
   local result_tmp
   [ -n "$PACKAGE_RESULT_FILE" ] || return 0
   result_tmp="${PACKAGE_RESULT_FILE}.tmp.$$"
   printf '%s\n' "$value" > "$result_tmp" && mv -f "$result_tmp" "$PACKAGE_RESULT_FILE"
}

set_lock() {
   mkdir -p "$OPENCLASH_LOCK_DIR" 2>/dev/null || return 1
   exec 878>"$UPDATE_LOCK" 2>/dev/null || return 1
   if [ "$AUTO_MODE" = "1" ]; then
      flock -n 878 2>/dev/null || return 1
   else
      flock -x 878 2>/dev/null || return 1
   fi
   UPDATE_LOCKED=1
}

del_lock() {
   [ "$UPDATE_LOCKED" = "1" ] || return 0
   flock -u 878 2>/dev/null
   UPDATE_LOCKED=0
}

install_worker_busy() {
   exec 877>"$INSTALL_LOCK" 2>/dev/null || return 0
   if flock -n 877 2>/dev/null; then
      flock -u 877 2>/dev/null
      return 1
   fi
   return 0
}

cleanup_openclash_update() {
   [ "$UPDATE_CLEANED" = "0" ] || return 0
   UPDATE_CLEANED=1
   if [ "$JOB_COUNTED" = "1" ]; then
      dec_job_counter_and_restart "0"
      JOB_COUNTED=0
   fi
   del_lock
}

finish_openclash_update() {
   local status="$1"
   SLOG_CLEAN
   cleanup_openclash_update
   trap - EXIT INT TERM
   exit "$status"
}

fail_update() {
   local status="$1"
   local result="$2"
   local message="$3"
   write_package_result "$result"
   [ -n "$message" ] && LOG_ERROR "$message"
   finish_openclash_update "$status"
}

version_compare() {
   local current_ver="$1"
   local latest_ver="$2"

   if echo "1.0.0" | sort -V >/dev/null 2>&1; then
      [ "$(printf '%s\n%s\n' "$current_ver" "$latest_ver" | sort -V | head -n1)" = "$current_ver" ] &&
         [ "$current_ver" != "$latest_ver" ]
      return $?
   fi

   local cv_num lv_num
   cv_num=$(echo "$current_ver" | awk -F '.' '{print $2$3}' 2>/dev/null)
   lv_num=$(echo "$latest_ver" | awk -F '.' '{print $2$3}' 2>/dev/null)
   [ -n "$cv_num" ] && [ -n "$lv_num" ] && [ "$(expr "$lv_num" \> "$cv_num")" -eq 1 ]
}

run_with_timeout() {
   local timeout_sec="$1"
   shift
   "$@" &
   local command_pid=$!
   (
      sleep "$timeout_sec"
      kill "$command_pid" 2>/dev/null
      sleep 1
      kill -9 "$command_pid" 2>/dev/null
   ) &
   local watchdog_pid=$!
   wait "$command_pid" 2>/dev/null
   local status=$?
   kill "$watchdog_pid" 2>/dev/null
   wait "$watchdog_pid" 2>/dev/null
   return "$status"
}

get_installed_version() {
   if [ -x "$OPKG_BIN" ]; then
      "$OPKG_BIN" status luci-app-openclash 2>/dev/null | awk -F 'Version: ' '/^Version: / {print $2; exit}'
   elif [ -x "$APK_BIN" ]; then
      "$APK_BIN" list luci-app-openclash 2>/dev/null | grep "installed" | grep -oE '[0-9]+(\.[0-9]+)*' | head -1
   fi
}

package_manager_busy_output() {
   grep -Eiq 'could not lock|unable to lock|resource busy|temporarily unavailable|database is locked' "$1" 2>/dev/null
}

package_artifact_invalid_output() {
   grep -Eiq 'invalid.*(package|archive)|corrupt|bad package|not a valid|failed to parse|malformed' "$1" 2>/dev/null
}

trap cleanup_openclash_update EXIT
trap 'fail_update 130 "failed:interrupted" ""' INT
trap 'fail_update 143 "failed:interrupted" ""' TERM

if ! set_lock; then
   write_package_result "busy"
   exit 75
fi

if install_worker_busy; then
   write_package_result "busy"
   finish_openclash_update 75
fi

if [ "$AUTO_MODE" != "1" ]; then
   for stale_run_dir in "${OPENCLASH_RUN_ROOT}"/openclash-update.*; do
      [ -d "$stale_run_dir" ] || continue
      rm -rf "$stale_run_dir" >/dev/null 2>&1
   done
   ubus call service delete '{"name":"openclash_update"}' >/dev/null 2>&1
fi

if [ "$AUTO_MODE" != "1" ]; then
   inc_job_counter
   JOB_COUNTED=1
fi

version_source=""
if [ -n "$1" ] && [ "$1" != "one_key_update" ]; then
   version_source="$1"
elif [ -n "$2" ]; then
   version_source="$2"
fi

if [ -n "$version_source" ]; then
   OPENCLASH_LIB_DIR="$OPENCLASH_LIB_DIR" \
   OPENCLASH_LOCK_DIR="$OPENCLASH_LOCK_DIR" \
   OPENCLASH_OPKG_BIN="$OPKG_BIN" \
   OPENCLASH_APK_BIN="$APK_BIN" \
   OPENCLASH_AUTO_VERSION_UPDATE="$AUTO_MODE" \
      bash "${OPENCLASH_LIB_DIR}/openclash_version.sh" "$version_source" 2>/dev/null
else
   OPENCLASH_LIB_DIR="$OPENCLASH_LIB_DIR" \
   OPENCLASH_LOCK_DIR="$OPENCLASH_LOCK_DIR" \
   OPENCLASH_OPKG_BIN="$OPKG_BIN" \
   OPENCLASH_APK_BIN="$APK_BIN" \
   OPENCLASH_AUTO_VERSION_UPDATE="$AUTO_MODE" \
      bash "${OPENCLASH_LIB_DIR}/openclash_version.sh" 2>/dev/null
fi
version_status=$?

case "$version_status" in
   0) ;;
   75) fail_update 75 "busy" "OpenClash version check is busy; automatic update skipped." ;;
   *) fail_update 76 "retry:version" "Failed to get version information, please try again later." ;;
esac

LAST_OPVER="/tmp/openclash_last_version"
LAST_VER=$(sed -n '1p' "$LAST_OPVER" 2>/dev/null | sed 's/^v//' | tr -d '\n')
OP_CV=$(get_installed_version)
OP_LV="$LAST_VER"
RELEASE_BRANCH=$(uci_get_config "release_branch" || echo "master")
github_address_mod=$(uci_get_config "github_address_mod" || echo 0)
[ -n "$version_source" ] && github_address_mod="$version_source"

if [ -z "$OP_CV" ] || [ -z "$OP_LV" ] || [ ! -f "$LAST_OPVER" ]; then
   fail_update 76 "retry:version" "Failed to get installed or latest OpenClash version."
fi

# Keep the existing manual one-key action. The scheduled path calls this script
# in package-only mode and handles the core as a separately verified stage.
if [ "$1" = "one_key_update" ] && [ "$PACKAGE_ONLY" != "1" ]; then
   if [ "$github_address_mod" = "0" ] || [ -z "$github_address_mod" ]; then
      bash "${OPENCLASH_LIB_DIR}/openclash_core.sh" "Meta" "one_key_update" >/dev/null 2>&1
      github_address_mod=0
   else
      bash "${OPENCLASH_LIB_DIR}/openclash_core.sh" "Meta" "one_key_update" "$github_address_mod" >/dev/null 2>&1
   fi
elif [ "$github_address_mod" = "0" ] && [ "$AUTO_MODE" != "1" ]; then
   LOG_TIP "If the download fails, try setting the CDN in Overwrite Settings - General Settings - Github Address Modify Options"
fi

if ! version_compare "$OP_CV" "$OP_LV"; then
   write_package_result "current"
   LOG_TIP "OpenClash has not been updated, stop continuing!"
   finish_openclash_update 0
fi

if [ -x "$OPKG_BIN" ]; then
   package_extension="ipk"
   package_name="luci-app-openclash_${LAST_VER}_all.ipk"
elif [ -x "$APK_BIN" ]; then
   package_extension="apk"
   package_name="luci-app-openclash-${LAST_VER}.apk"
else
   fail_update 1 "failed:package-manager" "No supported package manager was found."
fi

umask 077
if [ -n "${OPENCLASH_AUTO_RUN_DIR:-}" ]; then
   RUN_DIR="$OPENCLASH_AUTO_RUN_DIR"
   mkdir -p "$RUN_DIR" || fail_update 1 "failed:staging" "Failed to create update staging directory."
else
   RUN_DIR=$(mktemp -d "${OPENCLASH_RUN_ROOT}/openclash-update.XXXXXX") ||
      fail_update 1 "failed:staging" "Failed to create update staging directory."
fi
chmod 700 "$RUN_DIR" 2>/dev/null

DOWNLOAD_PATH="${RUN_DIR}/openclash.${package_extension}"
if [ "$github_address_mod" != "0" ] && [ -n "$github_address_mod" ]; then
   case "$github_address_mod" in
      https://cdn.jsdelivr.net/|https://fastly.jsdelivr.net/|https://testingcf.jsdelivr.net/)
         DOWNLOAD_URL="${github_address_mod}gh/vernesong/OpenClash@package/${RELEASE_BRANCH}/${package_name}"
      ;;
      *)
         DOWNLOAD_URL="${github_address_mod}https://raw.githubusercontent.com/vernesong/OpenClash/package/${RELEASE_BRANCH}/${package_name}"
      ;;
   esac
else
   DOWNLOAD_URL="https://raw.githubusercontent.com/vernesong/OpenClash/package/${RELEASE_BRANCH}/${package_name}"
fi

LOG_TIP "OpenClash client update:【${OP_CV} -> ${LAST_VER}】"
LOG_TIP "Start downloading【OpenClash - v$LAST_VER】..."
download_try=0
max_download_tries=3
[ "$AUTO_MODE" = "1" ] && max_download_tries=1

while [ "$download_try" -lt "$max_download_tries" ]; do
   download_try=$((download_try + 1))
   rm -f "$DOWNLOAD_PATH" >/dev/null 2>&1
   LOG_TIP "【$download_try/$max_download_tries】【OpenClash - v$LAST_VER】Downloading..."
   SHOW_DOWNLOAD_PROGRESS=1 DOWNLOAD_FILE_CURL "$DOWNLOAD_URL" "$DOWNLOAD_PATH" "$DOWNLOAD_PATH"
   download_status=$?
   [ "$download_status" -eq 0 ] && [ -s "$DOWNLOAD_PATH" ] && break
   [ "$download_try" -lt "$max_download_tries" ] && sleep 2
done

if [ ! -s "$DOWNLOAD_PATH" ]; then
   fail_update 76 "retry:download" "OpenClash package download failed."
fi

PRETEST_LOG="${RUN_DIR}/pretest.log"
pretest_status=1

if [ "$AUTO_MODE" != "1" ]; then
   if [ -x "$OPKG_BIN" ]; then
      run_with_timeout 30 "$OPKG_BIN" update >/dev/null 2>&1
   else
      run_with_timeout 30 "$APK_BIN" update >/dev/null 2>&1
   fi
fi

if [ -x "$OPKG_BIN" ]; then
   "$OPKG_BIN" --noaction install "$DOWNLOAD_PATH" >"$PRETEST_LOG" 2>&1
   pretest_status=$?
else
   "$APK_BIN" add -s -q --force-overwrite --clean-protected --allow-untrusted "$DOWNLOAD_PATH" >"$PRETEST_LOG" 2>&1
   pretest_status=$?
fi

if [ "$pretest_status" -ne 0 ]; then
   if package_manager_busy_output "$PRETEST_LOG"; then
      fail_update 75 "busy" "Package manager is busy; automatic update skipped."
   fi
   if [ "$AUTO_MODE" = "1" ] && package_artifact_invalid_output "$PRETEST_LOG"; then
      fail_update 76 "retry:artifact" "Downloaded OpenClash package is invalid; trying another source."
   fi
   fail_update 1 "failed:pretest" "OpenClash package pre-update test failed; downloaded package retained at ${DOWNLOAD_PATH}."
fi

WORKER_PATH="${RUN_DIR}/openclash_update_install.sh"
INSTALL_RESULT_FILE="${PACKAGE_RESULT_FILE:-${RUN_DIR}/package.result}"
[ -n "$PACKAGE_RESULT_FILE" ] || PACKAGE_RESULT_FILE="$INSTALL_RESULT_FILE"
cp -f "$OPENCLASH_INSTALLER_SH" "$WORKER_PATH" 2>/dev/null || {
   fail_update 1 "failed:worker" "Failed to prepare OpenClash install worker."
}
chmod 700 "$WORKER_PATH" 2>/dev/null || {
   fail_update 1 "failed:worker" "Failed to prepare OpenClash install worker."
}
write_package_result "queued"

if [ "$AUTO_MODE" = "1" ]; then
   OPENCLASH_LIB_DIR="$OPENCLASH_LIB_DIR" \
   OPENCLASH_INSTALL_LOCK="$INSTALL_LOCK" \
   OPENCLASH_OPKG_BIN="$OPKG_BIN" \
   OPENCLASH_APK_BIN="$APK_BIN" \
      "$WORKER_PATH" \
      "$DOWNLOAD_PATH" \
      "$LAST_VER" \
      "$INSTALL_RESULT_FILE" \
      "1" \
      "0" \
      "${OPENCLASH_UPGRADE_GUARD_FILE:-}" \
      "${OPENCLASH_UPGRADE_GUARD_PID:-}"
   install_status=$?
   install_result=$(sed -n '1p' "$INSTALL_RESULT_FILE" 2>/dev/null)

   case "$install_result" in
      updated:"$LAST_VER")
         [ "$install_status" -eq 0 ] ||
            fail_update 1 "failed:install-status" "OpenClash install worker returned an inconsistent status."
         finish_openclash_update 0
      ;;
      busy)
         finish_openclash_update 75
      ;;
      *)
         fail_update 1 "${install_result:-failed:install}" "OpenClash package installation failed."
      ;;
   esac
fi

service_name="openclash_update"
service_json='{"name":"'"$service_name"'","instances":{"update":{"command":["'"$WORKER_PATH"'","'"$DOWNLOAD_PATH"'","'"$LAST_VER"'","'"$INSTALL_RESULT_FILE"'","0","1","",""],"stdout":true,"stderr":true,"env":{"OPENCLASH_OPKG_BIN":"'"$OPKG_BIN"'","OPENCLASH_APK_BIN":"'"$APK_BIN"'"}}}}'

if ubus call service add "$service_json" >/dev/null 2>&1; then
   handoff_try=0
   while [ "$handoff_try" -lt 10 ]; do
      handoff_try=$((handoff_try + 1))
      install_result=$(sed -n '1p' "$INSTALL_RESULT_FILE" 2>/dev/null)
      [ "$install_result" != "queued" ] && [ -n "$install_result" ] && {
         JOB_COUNTED=0
         del_lock
         trap - EXIT INT TERM
         exit 2
      }
      sleep 1
   done

   ubus call service delete '{"name":"openclash_update"}' >/dev/null 2>&1
   sleep 1
   install_result=$(sed -n '1p' "$INSTALL_RESULT_FILE" 2>/dev/null)
   if [ "$install_result" != "queued" ] && [ -n "$install_result" ]; then
      JOB_COUNTED=0
   fi
   fail_update 1 "failed:worker-start-timeout" "OpenClash install worker did not start in time."
fi

fail_update 1 "failed:worker-start" "Failed to start OpenClash install worker."
