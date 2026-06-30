#!/bin/bash
github_cdn_is_jsdelivr() {
   case "$1" in
      "https://cdn.jsdelivr.net/"|"https://fastly.jsdelivr.net/"|"https://testingcf.jsdelivr.net/")
         return 0
      ;;
   esac
   return 1
}

build_oix_version_url() {
   local github_address_mod="$1"
   local raw_url="https://github.com/vernesong/mihomo-oix/releases/download/Pre-Alpha/version.txt"

   if [ -z "$github_address_mod" ] || [ "$github_address_mod" = "0" ]; then
      echo "$raw_url"
   elif github_cdn_is_jsdelivr "$github_address_mod"; then
      # jsDelivr /gh paths do not serve GitHub Release assets.
      echo "$raw_url"
   else
      echo "${github_address_mod}${raw_url}"
   fi
}

if [ "${OPENCLASH_TEST_ONLY:-}" = "1" ]; then
   "$@"
   exit $?
fi

. /usr/share/openclash/openclash_curl.sh
. /usr/share/openclash/uci.sh

set_lock() {
   exec 884>"/tmp/lock/openclash_clash_version.lock" 2>/dev/null
   flock -x 884 2>/dev/null
}

del_lock() {
   flock -u 884 2>/dev/null
   rm -rf "/tmp/lock/openclash_clash_version.lock" 2>/dev/null
}

set_lock

DOWNLOAD_FILE="/tmp/clash_last_version"
RELEASE_BRANCH=$(uci_get_config "release_branch" || echo "master")
github_address_mod=$(uci_get_config "github_address_mod" || echo 0)
CORE_TYPE=$(uci_get_config "core_type")
OIX_TOKEN=$(uci_get_config "oix_token")

if [ -n "$1" ]; then
   github_address_mod="$1"
fi

if [ "$CORE_TYPE" = "Oix" ] || [ -n "$OIX_TOKEN" ]; then
   DOWNLOAD_URL=$(build_oix_version_url "$github_address_mod")
else
   if [ "$github_address_mod" != "0" ]; then
      if [ "$github_address_mod" == "https://cdn.jsdelivr.net/" ] || [ "$github_address_mod" == "https://fastly.jsdelivr.net/" ] || [ "$github_address_mod" == "https://testingcf.jsdelivr.net/" ]; then
         DOWNLOAD_URL="${github_address_mod}gh/vernesong/OpenClash@core/${RELEASE_BRANCH}/core_version"
      else
         DOWNLOAD_URL="${github_address_mod}https://raw.githubusercontent.com/vernesong/OpenClash/core/${RELEASE_BRANCH}/core_version"
      fi
   else
      DOWNLOAD_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/${RELEASE_BRANCH}/core_version"
   fi
fi

DOWNLOAD_FILE_CURL "$DOWNLOAD_URL" "$DOWNLOAD_FILE" "$DOWNLOAD_FILE"
del_lock
