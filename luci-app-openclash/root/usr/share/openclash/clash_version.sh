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
if [ -n "$1" ]; then
   github_address_mod="$1"
fi

if [ "$github_address_mod" != "0" ]; then
   if [ "$github_address_mod" == "https://cdn.jsdelivr.net/" ] || [ "$github_address_mod" == "https://fastly.jsdelivr.net/" ] || [ "$github_address_mod" == "https://testingcf.jsdelivr.net/" ]; then
      DOWNLOAD_URL="${github_address_mod}gh/vernesong/OpenClash@core/${RELEASE_BRANCH}/core_version"
   else
      DOWNLOAD_URL="${github_address_mod}https://raw.githubusercontent.com/vernesong/OpenClash/core/${RELEASE_BRANCH}/core_version"
   fi
else
   DOWNLOAD_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/${RELEASE_BRANCH}/core_version"
fi

DOWNLOAD_FILE_CURL "$DOWNLOAD_URL" "$DOWNLOAD_FILE" "$DOWNLOAD_FILE"

#Clash Rust
if [ "$github_address_mod" != "0" ]; then
   RUST_LV=$(curl -sL --connect-timeout 5 -m 30 --retry 2 "${github_address_mod}https://raw.githubusercontent.com/Watfaq/clash-rs/master/clash-bin/Cargo.toml" |grep "^version =" |awk -F '"' '{print $2}' |head -1)
else
   RUST_LV=$(curl -sL --connect-timeout 5 -m 30 --retry 2 "https://raw.githubusercontent.com/Watfaq/clash-rs/master/clash-bin/Cargo.toml" |grep "^version =" |awk -F '"' '{print $2}' |head -1)
fi
if [ -n "$RUST_LV" ]; then
   sed -i "3i$RUST_LV" "$DOWNLOAD_FILE" 2>/dev/null || echo "$RUST_LV" >> "$DOWNLOAD_FILE"
fi

del_lock
