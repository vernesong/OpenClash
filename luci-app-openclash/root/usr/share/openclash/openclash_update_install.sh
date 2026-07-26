#!/bin/sh

OPENCLASH_LIB_DIR="${OPENCLASH_LIB_DIR:-/usr/share/openclash}"
OPKG_BIN="${OPENCLASH_OPKG_BIN:-/bin/opkg}"
APK_BIN="${OPENCLASH_APK_BIN:-/usr/bin/apk}"
. "${OPENCLASH_LIB_DIR}/log.sh"
. "${OPENCLASH_LIB_DIR}/openclash_ps.sh"

PACKAGE_PATH="$1"
TARGET_VERSION="$2"
RESULT_FILE="$3"
AUTO_MODE="${4:-0}"
JOB_COUNTED="${5:-0}"
UPGRADE_GUARD_FILE="${6:-}"
UPGRADE_GUARD_PID="${7:-}"
UPDATE_LOCK="${OPENCLASH_INSTALL_LOCK:-/tmp/lock/openclash_update_install.lock}"
INSTALL_LOCKED=0
INSTALL_FINISHED=0

write_result() {
   local value="$1"
   [ -n "$RESULT_FILE" ] || return 1
   local result_tmp="${RESULT_FILE}.tmp.$$"
   printf '%s\n' "$value" > "$result_tmp" && mv -f "$result_tmp" "$RESULT_FILE"
}

set_update_lock() {
   mkdir -p "$(dirname "$UPDATE_LOCK")" 2>/dev/null || return 1
   exec 879>"$UPDATE_LOCK" 2>/dev/null || return 1
   flock -n 879 2>/dev/null || return 1
   INSTALL_LOCKED=1
}

del_update_lock() {
   [ "$INSTALL_LOCKED" = "1" ] || return 0
   flock -u 879 2>/dev/null
   INSTALL_LOCKED=0
}

release_job_counter() {
   [ "$JOB_COUNTED" = "1" ] || return 0
   dec_job_counter_and_restart "0"
   JOB_COUNTED=0
}

finish_install() {
   local status="$1"
   INSTALL_FINISHED=1
   release_job_counter
   SLOG_CLEAN
   del_update_lock
   trap - EXIT INT TERM
   exit "$status"
}

interrupt_install() {
   write_result "failed:interrupted"
   finish_install "$1"
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

install_missing_packages() {
   local installed_before="$1"
   local pkg retry_count max_retries

   [ -n "$installed_before" ] || return 0
   for pkg in $installed_before; do
      if [ -x "$OPKG_BIN" ]; then
         "$OPKG_BIN" status "$pkg" >/dev/null 2>&1 && continue
      elif [ -x "$APK_BIN" ]; then
         "$APK_BIN" list "$pkg" 2>/dev/null | grep "installed" >/dev/null 2>&1 && continue
      fi

      LOG_TIP "【$pkg】depended package reinstalling..."
      retry_count=0
      max_retries=3
      [ "$AUTO_MODE" = "1" ] && max_retries=1
      while [ "$retry_count" -lt "$max_retries" ]; do
         retry_count=$((retry_count + 1))
         if [ -x "$OPKG_BIN" ]; then
            "$OPKG_BIN" install "$pkg" && break
         else
            "$APK_BIN" add "$pkg" && break
         fi
         [ "$retry_count" -lt "$max_retries" ] && sleep 2
      done
   done
}

trap 'interrupt_install 130' INT
trap 'interrupt_install 143' TERM
trap '[ "$INSTALL_FINISHED" = "1" ] || { write_result "failed:aborted"; release_job_counter; del_update_lock; }' EXIT

if [ -z "$PACKAGE_PATH" ] || [ -z "$TARGET_VERSION" ] || [ -z "$RESULT_FILE" ] || [ ! -s "$PACKAGE_PATH" ]; then
   [ -n "$RESULT_FILE" ] && write_result "failed:invalid-arguments"
   finish_install 1
fi

if ! set_update_lock; then
   write_result "busy"
   finish_install 75
fi

write_result "installing"

packages_to_check="luci-compat kmod-inet-diag kmod-nft-tproxy kmod-ipt-nat iptables-mod-tproxy iptables-mod-extra ipset"
installed_before=""
for pkg in $packages_to_check; do
   if [ -x "$OPKG_BIN" ]; then
      "$OPKG_BIN" status "$pkg" >/dev/null 2>&1 && installed_before="$installed_before $pkg"
   elif [ -x "$APK_BIN" ]; then
      "$APK_BIN" list "$pkg" 2>/dev/null | grep "installed" >/dev/null 2>&1 && installed_before="$installed_before $pkg"
   fi
done

if [ "$AUTO_MODE" = "1" ]; then
   case "$UPGRADE_GUARD_PID" in
      ''|*[!0-9]*)
         write_result "failed:guard"
         finish_install 1
      ;;
   esac
   [ -n "$UPGRADE_GUARD_FILE" ] || {
      write_result "failed:guard"
      finish_install 1
   }

   umask 077
   guard_tmp="${UPGRADE_GUARD_FILE}.tmp.$$"
   if ! printf '%s\n' "$UPGRADE_GUARD_PID" > "$guard_tmp" ||
      ! chmod 600 "$guard_tmp" 2>/dev/null ||
      ! mv -f "$guard_tmp" "$UPGRADE_GUARD_FILE"; then
      rm -f "$guard_tmp" >/dev/null 2>&1
      write_result "failed:guard"
      finish_install 1
   fi
fi

install_retry_count=0
max_install_retries=3
[ "$AUTO_MODE" = "1" ] && max_install_retries=1

while [ "$install_retry_count" -lt "$max_install_retries" ]; do
   install_retry_count=$((install_retry_count + 1))
   LOG_TIP "【$install_retry_count/$max_install_retries】Installing the new version, please do not refresh the page or do other operations..."
   install_log="${RESULT_FILE}.install.log"

   if [ -x "$OPKG_BIN" ]; then
      "$OPKG_BIN" install "$PACKAGE_PATH" >"$install_log" 2>&1
      install_status=$?
   elif [ -x "$APK_BIN" ]; then
      "$APK_BIN" add -q --force-overwrite --clean-protected --allow-untrusted "$PACKAGE_PATH" >"$install_log" 2>&1
      install_status=$?
   else
      install_status=127
   fi
   [ -s "$install_log" ] && cat "$install_log"

   if [ "$install_status" -ne 0 ] && package_manager_busy_output "$install_log"; then
      rm -f "$install_log" >/dev/null 2>&1
      write_result "busy"
      finish_install 75
   fi

   current_version=$(get_installed_version)
   if [ "$install_status" -eq 0 ] && [ "$current_version" = "$TARGET_VERSION" ]; then
      rm -f "$install_log" >/dev/null 2>&1
      install_missing_packages "$installed_before"
      write_result "updated:${current_version}"
      rm -f "$PACKAGE_PATH" >/dev/null 2>&1
      finish_install 0
   fi

   LOG_ERROR "【$install_retry_count/$max_install_retries】Installation failed..."
   rm -f "$install_log" >/dev/null 2>&1
   [ "$install_retry_count" -lt "$max_install_retries" ] && sleep 3
done

write_result "failed:install"
LOG_ERROR "OpenClash update failed; downloaded package retained at ${PACKAGE_PATH}."
finish_install 1
