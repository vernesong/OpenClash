#!/bin/bash
. /usr/share/openclash/log.sh
. /usr/share/openclash/uci.sh
. /usr/share/openclash/openclash_curl.sh
. /usr/share/openclash/openclash_ps.sh

set_lock() {
   exec 878>"/tmp/lock/openclash_update.lock" 2>/dev/null
   flock -x 878 2>/dev/null
}

del_lock() {
   flock -u 878 2>/dev/null
   rm -rf "/tmp/lock/openclash_update.lock" 2>/dev/null
}

early_exit() {
   dec_job_counter_and_restart "0"
   del_lock
   exit "${1:-0}"
}

set_lock
inc_job_counter

if [ -n "$1" ] && [ "$1" != "one_key_update" ] && [ "$1" != "plugin_update" ]; then
   /usr/share/openclash/openclash_version.sh "$1" 2>/dev/null
elif [ -n "$2" ]; then
   /usr/share/openclash/openclash_version.sh "$2" 2>/dev/null
else
   /usr/share/openclash/openclash_version.sh 2>/dev/null
fi

if [ ! -f "/tmp/openclash_last_version" ]; then
   LOG_ERROR "Failed to get version information, please try again later..."
   early_exit
fi

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

run_with_timeout() {
   local timeout_sec="$1"
   shift
   "$@" &
   local _pid=$!
   (
      sleep "$timeout_sec"
      kill $_pid 2>/dev/null
      sleep 1
      kill -9 $_pid 2>/dev/null
   ) &
   local _watchdog=$!
   wait $_pid 2>/dev/null
   local _ret=$?
   kill $_watchdog 2>/dev/null
   wait $_watchdog 2>/dev/null
   return $_ret
}

LAST_OPVER="/tmp/openclash_last_version"
LAST_VER=$(sed -n 1p "$LAST_OPVER" 2>/dev/null |sed "s/^v//g" |tr -d "\n")
if [ -x "/bin/opkg" ]; then
   OP_CV=$(rm -f /var/lock/opkg.lock && opkg status luci-app-openclash 2>/dev/null |grep 'Version' |awk -F 'Version: ' '{print $2}' 2>/dev/null)
elif [ -x "/usr/bin/apk" ]; then
   OP_CV=$(rm -f /lib/apk/db/lock && apk list luci-app-openclash 2>/dev/null|grep "installed" | grep -oE '[0-9]+(\.[0-9]+)*' | head -1 2>/dev/null)
fi
OP_LV=$(sed -n 1p "$LAST_OPVER" 2>/dev/null |sed "s/^v//g" |tr -d "\n")
RELEASE_BRANCH=$(uci_get_config "release_branch" || echo "master")
github_address_mod=$(uci_get_config "github_address_mod" || echo 0)

#一键更新
if [ "$1" = "one_key_update" ]; then
   if [ -n "$2" ]; then
      /usr/share/openclash/openclash_core.sh "Meta" "$1" "$2" >/dev/null 2>&1
   else
      /usr/share/openclash/openclash_core.sh "Meta" "$1" >/dev/null 2>&1
   fi
   if [ -z "$3" ] || ! echo "$3" | grep -qE '^https?://'; then
      if [ "$github_address_mod" = "0" ] && [ -z "$2" ]; then
         LOG_TIP "If the download fails, try setting the CDN in Overwrite Settings - General Settings - Github Address Modify Options"
      fi
      if [ -n "$2" ]; then
         github_address_mod="$2"
      else
         github_address_mod=0
      fi
      if echo "$github_address_mod" | grep -q "raw\.githubusercontent\.com"; then
         github_address_mod=0
      fi
   fi
elif [ "$1" = "plugin_update" ]; then
   if [ -z "$3" ] || ! echo "$3" | grep -qE '^https?://'; then
      if [ "$github_address_mod" = "0" ] && [ -z "$2" ]; then
         LOG_TIP "If the download fails, try setting the CDN in Overwrite Settings - General Settings - Github Address Modify Options"
      fi
      if [ -n "$2" ]; then
         github_address_mod="$2"
      fi
      if echo "$github_address_mod" | grep -q "raw\.githubusercontent\.com"; then
         github_address_mod=0
      fi
   fi
else
   if [ "$github_address_mod" = "0" ]; then
      LOG_TIP "If the download fails, try setting the CDN in Overwrite Settings - General Settings - Github Address Modify Options"
   fi
fi

if [ -n "$3" ] && echo "$3" | grep -qE '^https?://'; then
   # Direct download URL (historical version / downgrade) — skip version compare
   if [ -x "/bin/opkg" ]; then
      DOWNLOAD_URL="$3"
      DOWNLOAD_PATH="/tmp/openclash.ipk"
   elif [ -x "/usr/bin/apk" ]; then
      DOWNLOAD_URL="$3"
      DOWNLOAD_PATH="/tmp/openclash.apk"
   fi
   LAST_VER=$(echo "$DOWNLOAD_URL" | grep -oE 'luci-app-openclash[_-][0-9]+(\.[0-9]+)*' | head -1 | sed 's/^luci-app-openclash[_-]//')
   LOG_TIP "Start downloading【OpenClash - v$LAST_VER】..."
elif [ -n "$OP_CV" ] && [ -n "$OP_LV" ] && version_compare "$OP_CV" "$OP_LV" && [ -f "$LAST_OPVER" ]; then
   LOG_TIP "Start downloading【OpenClash - v$LAST_VER】..."
   if [ "$github_address_mod" != "0" ]; then
      if [ "$github_address_mod" == "https://cdn.jsdelivr.net/" ] || [ "$github_address_mod" == "https://fastly.jsdelivr.net/" ] || [ "$github_address_mod" == "https://testingcf.jsdelivr.net/" ]; then
         if [ -x "/bin/opkg" ]; then
            DOWNLOAD_URL="${github_address_mod}gh/vernesong/OpenClash@package/${RELEASE_BRANCH}/luci-app-openclash_${LAST_VER}_all.ipk"
            DOWNLOAD_PATH="/tmp/openclash.ipk"
         elif [ -x "/usr/bin/apk" ]; then
            DOWNLOAD_URL="${github_address_mod}gh/vernesong/OpenClash@package/${RELEASE_BRANCH}/luci-app-openclash-${LAST_VER}.apk"
            DOWNLOAD_PATH="/tmp/openclash.apk"
         fi
      else
         if [ -x "/bin/opkg" ]; then
            DOWNLOAD_URL="${github_address_mod}https://raw.githubusercontent.com/vernesong/OpenClash/package/${RELEASE_BRANCH}/luci-app-openclash_${LAST_VER}_all.ipk"
            DOWNLOAD_PATH="/tmp/openclash.ipk"
         elif [ -x "/usr/bin/apk" ]; then
            DOWNLOAD_URL="${github_address_mod}https://raw.githubusercontent.com/vernesong/OpenClash/package/${RELEASE_BRANCH}/luci-app-openclash-${LAST_VER}.apk"
            DOWNLOAD_PATH="/tmp/openclash.apk"
         fi
      fi
   else
      if [ -x "/bin/opkg" ]; then
         DOWNLOAD_URL="https://raw.githubusercontent.com/vernesong/OpenClash/package/${RELEASE_BRANCH}/luci-app-openclash_${LAST_VER}_all.ipk"
         DOWNLOAD_PATH="/tmp/openclash.ipk"
      elif [ -x "/usr/bin/apk" ]; then
         DOWNLOAD_URL="https://raw.githubusercontent.com/vernesong/OpenClash/package/${RELEASE_BRANCH}/luci-app-openclash-${LAST_VER}.apk"
         DOWNLOAD_PATH="/tmp/openclash.apk"
      fi
   fi
else
   if [ ! -f "$LAST_OPVER" ] || [ -z "$OP_CV" ] || [ -z "$OP_LV" ]; then
      LOG_ERROR "Failed to get version information, please try again later..."
   else
      LOG_TIP "OpenClash has not been updated, stop continuing!"
   fi
   early_exit
fi

if [ -n "$DOWNLOAD_URL" ]; then

   retry_count=0
   max_retries=3

   while [ "$retry_count" -lt "$max_retries" ]; do
      retry_count=$((retry_count + 1))

      if [ "$pkg_update_success" = "false" ]; then
         DOWNLOAD_RESULT=0
      else
         rm -rf "$DOWNLOAD_PATH" >/dev/null 2>&1
         LOG_TIP "【$retry_count/$max_retries】【OpenClash - v$LAST_VER】Downloading..."
         SHOW_DOWNLOAD_PROGRESS=1 DOWNLOAD_FILE_CURL "$DOWNLOAD_URL" "$DOWNLOAD_PATH" "$DOWNLOAD_PATH"
         DOWNLOAD_RESULT=$?
      fi

      if [ "$DOWNLOAD_RESULT" -ne 1 ]; then
         LOG_TIP "【$retry_count/$max_retries】【OpenClash - v$LAST_VER】Download successful, start pre update test..."

         pre_test_success=false

         if [ -x "/bin/opkg" ]; then
            update_retry=0
            max_update_retry=2
            while [ $update_retry -lt $max_update_retry ]; do
               update_retry=$((update_retry + 1))
               opkg_update_err=$(run_with_timeout 30 opkg update 2>&1)
               opkg_ret=$?
               rm -f /var/lock/opkg.lock
               if [ $opkg_ret -eq 0 ]; then
                  break
               fi
               if [ $update_retry -lt $max_update_retry ]; then
                  LOG_ERROR "【$update_retry/$max_update_retry】【OpenClash - v$LAST_VER】opkg update failed or timed out:【$(echo "$opkg_update_err" | tr '\n' ' ' | head -c 300)】, retrying..."
                  sleep 2
               else
                  LOG_ERROR "【$update_retry/$max_update_retry】【OpenClash - v$LAST_VER】opkg update failed:【$(echo "$opkg_update_err" | tr '\n' ' ' | head -c 300)】, trying pre update test..."
               fi
            done
            if [ -s "/tmp/openclash.ipk" ]; then
               opkg_test_err=$(opkg --force-downgrade install /tmp/openclash.ipk --noaction 2>&1)
               if [ -n "$(echo "$opkg_test_err" | grep -E '(Upgrading|Downgrading) luci-app-openclash on root')" ]; then
                  pre_test_success=true
               else
                  LOG_ERROR "【$retry_count/$max_retries】【OpenClash - v$LAST_VER】Pre update test failed:【$(echo "$opkg_test_err" | tr '\n' ' ' | head -c 500)】..."
               fi
            fi
         elif [ -x "/usr/bin/apk" ]; then
            update_retry=0
            max_update_retry=2
            while [ $update_retry -lt $max_update_retry ]; do
               update_retry=$((update_retry + 1))
               apk_update_err=$(run_with_timeout 30 apk update 2>&1)
               apk_ret=$?
               rm -f /lib/apk/db/lock
               if [ $apk_ret -eq 0 ]; then
                  break
               fi
               if [ $update_retry -lt $max_update_retry ]; then
                  LOG_ERROR "【$update_retry/$max_update_retry】【OpenClash - v$LAST_VER】apk update failed or timed out:【$(echo "$apk_update_err" | tr '\n' ' ' | head -c 300)】, retrying..."
                  sleep 2
               else
                  LOG_ERROR "【$update_retry/$max_update_retry】【OpenClash - v$LAST_VER】apk update failed:【$(echo "$apk_update_err" | tr '\n' ' ' | head -c 300)】, trying pre update test..."
               fi
            done
            if [ -s "/tmp/openclash.apk" ]; then
               apk_test_err=$(apk add -s -q --force-overwrite --clean-protected --allow-untrusted /tmp/openclash.apk 2>&1)
               if [ $? -eq 0 ]; then
                  pre_test_success=true
               else
                  LOG_ERROR "【$retry_count/$max_retries】【OpenClash - v$LAST_VER】Pre update test failed:【$(echo "$apk_test_err" | tr '\n' ' ' | head -c 500)】..."
               fi
            fi
         fi

         if [ "$pre_test_success" = "true" ]; then
            LOG_TIP "【$retry_count/$max_retries】【OpenClash - v$LAST_VER】Pre update test passed, ready to update and please do not refresh the page and other operations..."
            break
         else
            if [ "$retry_count" -lt "$max_retries" ]; then
               LOG_ERROR "【$retry_count/$max_retries】【OpenClash - v$LAST_VER】Pre update test failed..."
               sleep 2
               continue
            else
               if [ -x "/bin/opkg" ]; then
                  LOG_ERROR "【OpenClash - v$LAST_VER】Pre update test failed after 3 attempts, the file is saved in /tmp/openclash.ipk, please try to update manually with【opkg --force-downgrade install /tmp/openclash.ipk】"
               elif [ -x "/usr/bin/apk" ]; then
                  LOG_ERROR "【OpenClash - v$LAST_VER】Pre update test failed after 3 attempts, the file is saved in /tmp/openclash.apk, please try to update manually with【apk add -q --force-overwrite --clean-protected --allow-untrusted /tmp/openclash.apk】"
               fi
               early_exit
            fi
         fi
      else
         if [ "$retry_count" -lt "$max_retries" ]; then
            LOG_ERROR "【$retry_count/$max_retries】【OpenClash - v$LAST_VER】Download failed..."
            sleep 2
            continue
         else
            LOG_ERROR "【OpenClash - v$LAST_VER】Download Failed after 3 attempts, please check the network or try again later!"
            rm -rf /tmp/openclash.ipk >/dev/null 2>&1
            rm -rf /tmp/openclash.apk >/dev/null 2>&1
            early_exit
         fi
      fi
   done
   cat > /tmp/openclash_update.sh <<"EOF"
#!/bin/sh
. /usr/share/openclash/log.sh
. /usr/share/openclash/openclash_ps.sh

UPDATE_LOCK="/tmp/lock/openclash_update_install.lock"
mkdir -p /tmp/lock

set_update_lock() {
   exec 879>"$UPDATE_LOCK" 2>/dev/null
   flock -n 879 2>/dev/null
}

del_update_lock() {
   flock -u 879 2>/dev/null
   rm -rf "$UPDATE_LOCK" 2>/dev/null
}

if ! set_update_lock; then
   echo "Update process is already running, exiting..."
   exit 1
fi

trap 'del_update_lock; exit' INT TERM EXIT

check_install_success()
{
   local target_version="$1"
   local current_version=""

   if [ -x "/bin/opkg" ]; then
      current_version=$(rm -f /var/lock/opkg.lock && opkg status luci-app-openclash 2>/dev/null |grep 'Version' |awk -F 'Version: ' '{print $2}' 2>/dev/null)
   elif [ -x "/usr/bin/apk" ]; then
      current_version=$(apk list luci-app-openclash 2>/dev/null |grep "installed" | grep -oE '[0-9]+(\.[0-9]+)*' | head -1 2>/dev/null)
   fi

   if [ -n "$current_version" ] && [ "$current_version" = "$target_version" ]; then
      return 0
   else
      return 1
   fi
}

install_missing_packages() {
   local installed_before="$1"

   if [ -n "$installed_before" ]; then
      for pkg in $installed_before; do
         local retry_count=0
         local max_retries=3
         if [ -x "/bin/opkg" ]; then
            if opkg status "$pkg" >/dev/null 2>&1; then
               continue
            fi
         elif [ -x "/usr/bin/apk" ]; then
            if apk list "$pkg" |grep "installed" >/dev/null 2>&1; then
               continue
            fi
         fi

         LOG_TIP "【$pkg】depended package reinstalling..."

         while [ $retry_count -lt $max_retries ]; do
            retry_count=$((retry_count + 1))
            if [ -x "/bin/opkg" ]; then
               pkg_err=$(opkg install "$pkg" 2>&1)
            elif [ -x "/usr/bin/apk" ]; then
               pkg_err=$(apk add "$pkg" 2>&1)
            fi
            if [ $? -eq 0 ]; then
               break
            else
               if [ $retry_count -lt $max_retries ]; then
                  sleep 2
               else
                  LOG_ERROR "【$pkg】failed to install:【$(echo "$pkg_err" | tr '\n' ' ' | head -c 300)】, please try to install it manually..."
               fi
            fi
         done
      done
   fi
}

install_retry_count=0
max_install_retries=3
install_success=false

while [ $install_retry_count -lt $max_install_retries ]; do
   install_retry_count=$((install_retry_count + 1))
   LOG_TIP "【$install_retry_count/$max_install_retries】Installing the new version, please do not refresh the page or do other operations..."

   packages_to_check="luci-compat kmod-inet-diag kmod-nft-tproxy kmod-ipt-nat iptables-mod-tproxy iptables-mod-extra ipset"
   installed_before=""
   if [ -x "/bin/opkg" ]; then
      for pkg in $packages_to_check; do
         if opkg status "$pkg" >/dev/null 2>&1; then
            installed_before="$installed_before $pkg"
         fi
      done
      opkg --force-downgrade install /tmp/openclash.ipk >/dev/null 2>&1
      install_err=$(cat /tmp/openclash_install.log 2>/dev/null)
   elif [ -x "/usr/bin/apk" ]; then
      for pkg in $packages_to_check; do
         if apk list "$pkg" |grep "installed" >/dev/null 2>&1; then
            installed_before="$installed_before $pkg"
         fi
      done
      apk add -q --force-overwrite --clean-protected --allow-untrusted /tmp/openclash.apk >/tmp/openclash_install.log 2>&1
      install_err=$(cat /tmp/openclash_install.log 2>/dev/null)
   fi

   sleep 2

   if check_install_success "$LAST_VER"; then
      install_success=true
      install_missing_packages "$installed_before"
      break
   else
      LOG_ERROR "【$install_retry_count/$max_install_retries】Installation failed:【$(echo "$install_err" | tr '\n' ' ' | head -c 500)】..."
      if [ $install_retry_count -lt $max_install_retries ]; then
         sleep 3
      fi
   fi
done

if [ "$install_success" = true ]; then
   if [ -x "/bin/opkg" ]; then
      rm -rf /tmp/openclash.ipk >/dev/null 2>&1
   elif [ -x "/usr/bin/apk" ]; then
      rm -rf /tmp/openclash.apk >/dev/null 2>&1
   fi
else
   if [ -x "/bin/opkg" ]; then
      LOG_ERROR "OpenClash update failed after 3 attempts, the file is saved in /tmp/openclash.ipk, please try to update manually with【opkg --force-downgrade install /tmp/openclash.ipk】【$(echo "$install_err" | tr '\n' ' ' | head -c 500)】"
   elif [ -x "/usr/bin/apk" ]; then
      LOG_ERROR "OpenClash update failed after 3 attempts, the file is saved in /tmp/openclash.apk, please try to update manually with【apk add -q --force-overwrite --clean-protected --allow-untrusted /tmp/openclash.apk】【$(echo "$install_err" | tr '\n' ' ' | head -c 500)】"
   fi
fi
dec_job_counter_and_restart "0"
del_update_lock
EOF
   chmod 4755 /tmp/openclash_update.sh

   if [ ! -f "/tmp/openclash_update.sh" ] || [ ! -s "/tmp/openclash_update.sh" ] || [ ! -x "/tmp/openclash_update.sh" ]; then
      LOG_ERROR "Failed to create update script!"
      rm -rf /tmp/openclash_update.sh
      early_exit 1
   fi

   retry_count=0
   max_retries=3
   service_started=false

   while [ $retry_count -lt $max_retries ]; do
      retry_count=$((retry_count + 1))
      LOG_TIP "【$retry_count/$max_retries】Attempting to start update service..."

      ubus call service add '{"name":"openclash_update","instances":{"update":{"command":["/tmp/openclash_update.sh"],"stdout":true,"stderr":true,"env":{"LAST_VER":"'"$LAST_VER"'"}}}}' >/dev/null 2>&1

      sleep 3

      if ubus call service list '{"name":"openclash_update"}' 2>/dev/null | jsonfilter -e '@.openclash_update.instances.*.running' | grep -q 'true'; then
         service_started=true
         break
      else
         if [ $retry_count -lt $max_retries ]; then
            LOG_ERROR "【$retry_count/$max_retries】Service start failed, retrying in 2 seconds..."
            sleep 2
         fi
      fi
   done

   if [ "$service_started" = false ]; then
      LOG_ERROR "Failed to start update service after 3 attempts, please check and try again later..."
   fi

   (sleep 15; rm -f /tmp/openclash_update.sh) &
fi

del_lock
