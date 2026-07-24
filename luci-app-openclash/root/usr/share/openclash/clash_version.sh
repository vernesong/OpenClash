#!/bin/bash

OPENCLASH_LIB_DIR="${OPENCLASH_LIB_DIR:-/usr/share/openclash}"
OPENCLASH_LOCK_DIR="${OPENCLASH_LOCK_DIR:-/tmp/lock}"
AUTO_MODE="${OPENCLASH_AUTO_VERSION_UPDATE:-0}"
VERSION_LOCK="${OPENCLASH_LOCK_DIR}/openclash_clash_version.lock"
VERSION_LOCKED=0

. "${OPENCLASH_LIB_DIR}/openclash_curl.sh"
. "${OPENCLASH_LIB_DIR}/uci.sh"

set_lock() {
   mkdir -p "$OPENCLASH_LOCK_DIR" 2>/dev/null || return 1
   exec 884>"$VERSION_LOCK" 2>/dev/null || return 1
   if [ "$AUTO_MODE" = "1" ]; then
      flock -n 884 2>/dev/null || return 1
   else
      flock -x 884 2>/dev/null || return 1
   fi
   VERSION_LOCKED=1
}

del_lock() {
   [ "$VERSION_LOCKED" = "1" ] || return 0
   flock -u 884 2>/dev/null
   VERSION_LOCKED=0
}

if ! set_lock; then
   exit 75
fi
trap del_lock EXIT
trap 'del_lock; trap - EXIT; exit 130' INT
trap 'del_lock; trap - EXIT; exit 143' TERM

DOWNLOAD_FILE="${OPENCLASH_CORE_VERSION_FILE:-/tmp/clash_last_version}"
RELEASE_BRANCH=$(uci_get_config "release_branch" || echo "master")
github_address_mod=$(uci_get_config "github_address_mod" || echo 0)
CORE_TYPE=$(uci_get_config "core_type")
OIX_TOKEN=$(uci_get_config "oix_token")
[ -n "$1" ] && github_address_mod="$1"

if [ "$CORE_TYPE" = "Oix" ] || [ -n "$OIX_TOKEN" ]; then
   OIX_VERSION_URL="https://github.com/vernesong/mihomo-oix/releases/download/Pre-Alpha/version.txt"
   OIX_VERSION_P_URL="https://dl.dler.io/mihomo-oix/version.txt?tag=Pre-Alpha"
   if [ "$github_address_mod" != "0" ] &&
      [ "$github_address_mod" != "https://cdn.jsdelivr.net/" ] &&
      [ "$github_address_mod" != "https://fastly.jsdelivr.net/" ] &&
      [ "$github_address_mod" != "https://testingcf.jsdelivr.net/" ]; then
      DOWNLOAD_URL="${github_address_mod}${OIX_VERSION_URL}"
   else
      DOWNLOAD_URL="$OIX_VERSION_P_URL"
   fi
else
   if [ "$github_address_mod" != "0" ]; then
      case "$github_address_mod" in
         https://cdn.jsdelivr.net/|https://fastly.jsdelivr.net/|https://testingcf.jsdelivr.net/)
            DOWNLOAD_URL="${github_address_mod}gh/vernesong/OpenClash@core/${RELEASE_BRANCH}/core_version"
         ;;
         *)
            DOWNLOAD_URL="${github_address_mod}https://raw.githubusercontent.com/vernesong/OpenClash/core/${RELEASE_BRANCH}/core_version"
         ;;
      esac
   else
      DOWNLOAD_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/${RELEASE_BRANCH}/core_version"
   fi
fi

DOWNLOAD_FILE_CURL "$DOWNLOAD_URL" "$DOWNLOAD_FILE" "$DOWNLOAD_FILE"
download_status=$?

if [ "$download_status" -ne 0 ] && {
   [ "$download_status" -ne 2 ] || [ ! -s "$DOWNLOAD_FILE" ]
}; then
   rm -f "$DOWNLOAD_FILE" >/dev/null 2>&1
   exit 1
fi

if [ ! -s "$DOWNLOAD_FILE" ] || [ -z "$(sed -n '1p' "$DOWNLOAD_FILE" 2>/dev/null)" ]; then
   rm -f "$DOWNLOAD_FILE" >/dev/null 2>&1
   exit 1
fi

exit 0
