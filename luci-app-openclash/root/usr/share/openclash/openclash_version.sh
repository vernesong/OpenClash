#!/bin/bash
. /usr/share/openclash/openclash_curl.sh
. /usr/share/openclash/uci.sh

set_lock() {
   exec 869>"/tmp/lock/openclash_version.lock" 2>/dev/null
   flock -x 869 2>/dev/null
}

del_lock() {
   flock -u 869 2>/dev/null
   rm -rf "/tmp/lock/openclash_version.lock" 2>/dev/null
}

set_lock

version_compare() {
    local current_ver="$1"
    local latest_ver="$2"
    
    if echo "1.0.0" | sort -V >/dev/null 2>&1; then
        if [ "$(printf '%s\n%s\n' "$current_ver" "$latest_ver" | sort -V | head -n1)" = "$current_ver" ] && [ "$current_ver" != "$latest_ver" ]; then
            return 0
        fi
    else
        local cv_num=$(echo "$current_ver" | awk -F '.' '{print $2$3}' 2>/dev/null)
        local lv_num=$(echo "$latest_ver" | awk -F '.' '{print $2$3}' 2>/dev/null)
        if [ -n "$cv_num" ] && [ -n "$lv_num" ] && [ "$(expr "$lv_num" \> "$cv_num")" -eq 1 ]; then
            return 0
        fi
    fi
    return 1
}

TIME=$(date "+%Y-%m-%d-%H")
CHTIME=$(date "+%Y-%m-%d-%H" -r "/tmp/openclash_last_version" 2>/dev/null)
DOWNLOAD_FILE="/tmp/openclash_last_version"
RELEASE_BRANCH=$(uci_get_config "release_branch" || echo "master")
if [ -x "/bin/opkg" ]; then
   OP_CV=$(rm -f /var/lock/opkg.lock && opkg status luci-app-openclash 2>/dev/null |grep 'Version' |awk -F 'Version: ' '{print $2}' 2>/dev/null)
elif [ -x "/usr/bin/apk" ]; then
   OP_CV=$(apk list luci-app-openclash 2>/dev/null|grep 'installed' | grep -oE '[0-9]+(\.[0-9]+)*' | head -1 2>/dev/null)
fi
OP_LV=$(sed -n 1p "$DOWNLOAD_FILE" 2>/dev/null |sed "s/^v//g" |tr -d "\n")
github_address_mod=$(uci_get_config "github_address_mod" || echo 0)
if [ -n "$1" ]; then
   github_address_mod="$1"
fi

if [ "$TIME" != "$CHTIME" ]; then
	if [ "$github_address_mod" != "0" ]; then
      if [ "$github_address_mod" == "https://cdn.jsdelivr.net/" ] || [ "$github_address_mod" == "https://fastly.jsdelivr.net/" ] || [ "$github_address_mod" == "https://testingcf.jsdelivr.net/" ]; then
         DOWNLOAD_URL="${github_address_mod}gh/vernesong/OpenClash@package/${RELEASE_BRANCH}/version"
      else
         DOWNLOAD_URL="${github_address_mod}https://raw.githubusercontent.com/vernesong/OpenClash/package/${RELEASE_BRANCH}/version"
      fi
   else
      DOWNLOAD_URL="https://raw.githubusercontent.com/vernesong/OpenClash/package/${RELEASE_BRANCH}/version"
   fi

   DOWNLOAD_FILE_CURL "$DOWNLOAD_URL" "$DOWNLOAD_FILE"

   if [ "$?" -eq 0 ]; then
   	OP_LV=$(sed -n 1p $DOWNLOAD_FILE 2>/dev/null |awk -F 'v' '{print $2}' |awk -F '.' '{print $2$3}' 2>/dev/null)
      if [ -n "$OP_CV" ] && [ -n "$OP_LV" ] && version_compare "$OP_CV" "$OP_LV" && [ -f "$DOWNLOAD_FILE" ]; then
         sed -i '/^https:/,$d' $DOWNLOAD_FILE
      fi
   fi
fi
del_lock