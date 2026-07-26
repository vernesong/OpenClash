#!/bin/bash

OPENCLASH_LIB_DIR="${OPENCLASH_LIB_DIR:-/usr/share/openclash}"
OPENCLASH_LOCK_DIR="${OPENCLASH_LOCK_DIR:-/tmp/lock}"
AUTO_MODE="${OPENCLASH_AUTO_VERSION_UPDATE:-0}"
OPKG_BIN="${OPENCLASH_OPKG_BIN:-/bin/opkg}"
APK_BIN="${OPENCLASH_APK_BIN:-/usr/bin/apk}"
VERSION_LOCK="${OPENCLASH_LOCK_DIR}/openclash_version.lock"
VERSION_LOCKED=0

. "${OPENCLASH_LIB_DIR}/openclash_curl.sh"
. "${OPENCLASH_LIB_DIR}/uci.sh"

set_lock() {
   mkdir -p "$OPENCLASH_LOCK_DIR" 2>/dev/null || return 1
   exec 869>"$VERSION_LOCK" 2>/dev/null || return 1
   if [ "$AUTO_MODE" = "1" ]; then
      flock -n 869 2>/dev/null || return 1
   else
      flock -x 869 2>/dev/null || return 1
   fi
   VERSION_LOCKED=1
}

del_lock() {
   [ "$VERSION_LOCKED" = "1" ] || return 0
   flock -u 869 2>/dev/null
   VERSION_LOCKED=0
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

if ! set_lock; then
   exit 75
fi
trap del_lock EXIT
trap 'del_lock; trap - EXIT; exit 130' INT
trap 'del_lock; trap - EXIT; exit 143' TERM

DOWNLOAD_FILE="/tmp/openclash_last_version"
RELEASE_BRANCH=$(uci_get_config "release_branch" || echo "master")
if [ -x "$OPKG_BIN" ]; then
   OP_CV=$("$OPKG_BIN" status luci-app-openclash 2>/dev/null | awk -F 'Version: ' '/^Version: / {print $2; exit}')
elif [ -x "$APK_BIN" ]; then
   OP_CV=$("$APK_BIN" list luci-app-openclash 2>/dev/null | grep 'installed' | grep -oE '[0-9]+(\.[0-9]+)*' | head -1)
fi

github_address_mod=$(uci_get_config "github_address_mod" || echo 0)
[ -n "$1" ] && github_address_mod="$1"

if [ "$github_address_mod" != "0" ]; then
   case "$github_address_mod" in
      https://cdn.jsdelivr.net/|https://fastly.jsdelivr.net/|https://testingcf.jsdelivr.net/)
         DOWNLOAD_URL="${github_address_mod}gh/vernesong/OpenClash@package/${RELEASE_BRANCH}/version"
      ;;
      *)
         DOWNLOAD_URL="${github_address_mod}https://raw.githubusercontent.com/vernesong/OpenClash/package/${RELEASE_BRANCH}/version"
      ;;
   esac
else
   DOWNLOAD_URL="https://raw.githubusercontent.com/vernesong/OpenClash/package/${RELEASE_BRANCH}/version"
fi

DOWNLOAD_FILE_CURL "$DOWNLOAD_URL" "$DOWNLOAD_FILE" "$DOWNLOAD_FILE"
download_status=$?

if [ "$download_status" -ne 0 ] && {
   [ "$download_status" -ne 2 ] || [ ! -s "$DOWNLOAD_FILE" ]
}; then
   rm -f "$DOWNLOAD_FILE" >/dev/null 2>&1
   exit 1
fi

OP_LV=$(sed -n '1p' "$DOWNLOAD_FILE" 2>/dev/null | sed 's/^v//' | tr -d '\n')
case "$OP_LV" in
   ''|*[!0-9.]*)
      rm -f "$DOWNLOAD_FILE" >/dev/null 2>&1
      exit 1
   ;;
esac

if [ -n "$OP_CV" ] && version_compare "$OP_CV" "$OP_LV"; then
   sed -i '/^https:/,$d' "$DOWNLOAD_FILE"
fi

exit 0
