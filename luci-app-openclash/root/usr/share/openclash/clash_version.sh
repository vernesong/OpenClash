#!/bin/bash
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
   OIX_VERSION_URL="https://github.com/vernesong/mihomo-oix/releases/download/Pre-Alpha/version.txt"
   if [ "$github_address_mod" != "0" ] && [ "$github_address_mod" != "https://cdn.jsdelivr.net/" ] && [ "$github_address_mod" != "https://fastly.jsdelivr.net/" ] && [ "$github_address_mod" != "https://testingcf.jsdelivr.net/" ]; then
      DOWNLOAD_URL="${github_address_mod}${OIX_VERSION_URL}"
   else
      DOWNLOAD_URL="$OIX_VERSION_URL"
   fi
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
