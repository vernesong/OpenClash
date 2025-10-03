#!/bin/bash
. /usr/share/openclash/log.sh
. /usr/share/openclash/openclash_curl.sh
. /usr/share/openclash/uci.sh

set_lock() {
   exec 878>"/tmp/lock/openclash_update.lock" 2>/dev/null
   flock -x 878 2>/dev/null
}

del_lock() {
   flock -u 878 2>/dev/null
   rm -rf "/tmp/lock/openclash_update.lock" 2>/dev/null
}

set_lock

if [ -n "$1" ] && [ "$1" != "one_key_update" ]; then
   [ ! -f "/tmp/openclash_last_version" ] && /usr/share/openclash/openclash_version.sh "$1" 2>/dev/null
elif [ -n "$2" ]; then
   [ ! -f "/tmp/openclash_last_version" ] && /usr/share/openclash/openclash_version.sh "$2" 2>/dev/null
else
   [ ! -f "/tmp/openclash_last_version" ] && /usr/share/openclash/openclash_version.sh 2>/dev/null
fi

if [ ! -f "/tmp/openclash_last_version" ]; then
   LOG_OUT "Error: Failed to get version information, please try again later..."
   SLOG_CLEAN
   del_lock
   exit 0
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

LAST_OPVER="/tmp/openclash_last_version"
LAST_VER=$(sed -n 1p "$LAST_OPVER" 2>/dev/null |sed "s/^v//g" |tr -d "\n")
if [ -x "/bin/opkg" ]; then
   OP_CV=$(rm -f /var/lock/opkg.lock && opkg status luci-app-openclash 2>/dev/null |grep 'Version' |awk -F 'Version: ' '{print $2}' 2>/dev/null)
elif [ -x "/usr/bin/apk" ]; then
   OP_CV=$(apk list luci-app-openclash 2>/dev/null|grep 'installed' | grep -oE '[0-9]+(\.[0-9]+)*' | head -1 2>/dev/null)
fi
OP_LV=$(sed -n 1p "$LAST_OPVER" 2>/dev/null |sed "s/^v//g" |tr -d "\n")
RELEASE_BRANCH=$(uci_get_config "release_branch" || echo "master")
github_address_mod=$(uci_get_config "github_address_mod" || echo 0)

#一键更新
if [ "$1" = "one_key_update" ]; then
   uci -q set openclash.config.enable=1
   uci -q commit openclash
   if [ "$github_address_mod" = "0" ] && [ -z "$2" ]; then
      LOG_OUT "Tip: If the download fails, try setting the CDN in Overwrite Settings - General Settings - Github Address Modify Options"
   fi
   if [ -n "$2" ]; then
      /usr/share/openclash/openclash_core.sh "Meta" "$1" "$2" >/dev/null 2>&1 &
      github_address_mod="$2"
   else
      /usr/share/openclash/openclash_core.sh "Meta" "$1" >/dev/null 2>&1 &
      github_address_mod=0
   fi
   
   wait
else
   if [ "$github_address_mod" = "0" ]; then
      LOG_OUT "Tip: If the download fails, try setting the CDN in Overwrite Settings - General Settings - Github Address Modify Options"
   fi
fi

if [ -n "$OP_CV" ] && [ -n "$OP_LV" ] && version_compare "$OP_CV" "$OP_LV" && [ -f "$LAST_OPVER" ]; then
   LOG_OUT "Tip: Start downloading【OpenClash - v$LAST_VER】..."
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

   retry_count=0
   max_retries=3

   while [ "$retry_count" -lt "$max_retries" ]; do
      retry_count=$((retry_count + 1))

      if [ "$pkg_update_success" = "false" ]; then
         download_result=0
      else
         rm -rf "$DOWNLOAD_PATH" >/dev/null 2>&1
         LOG_OUT "Tip:【$retry_count/$max_retries】【OpenClash - v$LAST_VER】Downloading..."
         SHOW_DOWNLOAD_PROGRESS=1 DOWNLOAD_FILE_CURL "$DOWNLOAD_URL" "$DOWNLOAD_PATH"
         download_result=$?
      fi
      
      if [ "$download_result" -eq 0 ]; then
         LOG_OUT "Tip:【$retry_count/$max_retries】【OpenClash - v$LAST_VER】Download successful, start pre update test..."
         
         pre_test_success=false
         pkg_update_success=true
         
         if [ -x "/bin/opkg" ]; then
            opkg update >/dev/null 2>&1
            if [ $? -ne 0 ]; then
               sleep 2
               pkg_update_success=false
               continue
            fi
            if [ -s "/tmp/openclash.ipk" ]; then
               if [ -n "$(opkg install /tmp/openclash.ipk --noaction 2>/dev/null |grep 'Upgrading luci-app-openclash on root' 2>/dev/null)" ]; then
                  pre_test_success=true
               fi
            fi
         elif [ -x "/usr/bin/apk" ]; then
            apk update >/dev/null 2>&1
            if [ $? -ne 0 ]; then
               sleep 2
               pkg_update_success=false
               continue
            fi
            if [ -s "/tmp/openclash.apk" ]; then
               apk add -s -q --force-overwrite --clean-protected --allow-untrusted /tmp/openclash.apk >/dev/null 2>&1
               if [ $? -eq 0 ]; then
                  pre_test_success=true
               fi
            fi
         fi
         
         if [ "$pre_test_success" = "true" ]; then
            LOG_OUT "Tip:【$retry_count/$max_retries】【OpenClash - v$LAST_VER】Pre update test passed, ready to update and please do not refresh the page and other operations..."
            break
         else
            if [ "$retry_count" -lt "$max_retries" ]; then
               LOG_OUT "Error:【$retry_count/$max_retries】【OpenClash - v$LAST_VER】Pre update test failed..."
               sleep 2
               continue
            else
               if [ -x "/bin/opkg" ]; then
                  LOG_OUT "Error:【OpenClash - v$LAST_VER】Pre update test failed after 3 attempts, the file is saved in /tmp/openclash.ipk, please try to update manually with【opkg install /tmp/openclash.ipk】"
               elif [ -x "/usr/bin/apk" ]; then
                  LOG_OUT "Error:【OpenClash - v$LAST_VER】Pre update test failed after 3 attempts, the file is saved in /tmp/openclash.apk, please try to update manually with【apk add -q --force-overwrite --clean-protected --allow-untrusted /tmp/openclash.apk】"
               fi
               if [ "$(uci_get_config "restart")" -eq 1 ]; then
                  uci -q set openclash.config.restart=0
                  uci -q commit openclash
                  /etc/init.d/openclash restart >/dev/null 2>&1 &
               else
                  SLOG_CLEAN
               fi
               del_lock
               exit 0
            fi
         fi
      else
         if [ "$retry_count" -lt "$max_retries" ]; then
            LOG_OUT "Error:【$retry_count/$max_retries】【OpenClash - v$LAST_VER】Download failed..."
            sleep 2
            continue
         else
            LOG_OUT "Error:【OpenClash - v$LAST_VER】Download Failed after 3 attempts, please check the network or try again later!"
            rm -rf /tmp/openclash.ipk >/dev/null 2>&1
            rm -rf /tmp/openclash.apk >/dev/null 2>&1
            if [ "$(uci_get_config "restart")" -eq 1 ]; then
               uci -q set openclash.config.restart=0
               uci -q commit openclash
               /etc/init.d/openclash restart >/dev/null 2>&1 &
            else
               SLOG_CLEAN
            fi
            del_lock
            exit 0
         fi
      fi
   done
   cat > /tmp/openclash_update.sh <<"EOF"
#!/bin/sh
START_LOG="/tmp/openclash_start.log"
LOG_FILE="/tmp/openclash.log"
LOGTIME=$(date "+%Y-%m-%d %H:%M:%S")

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

LOG_OUT()
{
   if [ -n "${1}" ]; then
      echo -e "${1}" > $START_LOG
      echo -e "${LOGTIME} ${1}" >> $LOG_FILE
   fi
}

SLOG_CLEAN()
{
   echo "" > $START_LOG
}

check_install_success()
{
   local target_version="$1"
   local current_version=""
   
   if [ -x "/bin/opkg" ]; then
      current_version=$(rm -f /var/lock/opkg.lock && opkg status luci-app-openclash 2>/dev/null |grep 'Version' |awk -F 'Version: ' '{print $2}' 2>/dev/null)
   elif [ -x "/usr/bin/apk" ]; then
      current_version=$(apk list luci-app-openclash 2>/dev/null|grep 'installed' | grep -oE '[0-9]+(\.[0-9]+)*' | head -1 2>/dev/null)
   fi
   
   if [ -n "$current_version" ] && [ "$current_version" = "$target_version" ]; then
      return 0
   else
      return 1
   fi
}

install_missing_packages() {
   local installed_before="$1"

   if [ -x "/bin/opkg" ]; then
      for pkg in $installed_before; do
         if ! opkg status "$pkg" >/dev/null 2>&1; then
            local retry_count=0
            local max_retries=3
            while [ $retry_count -lt $max_retries ]; do
               retry_count=$((retry_count + 1))
               opkg install "$pkg"
               if [ $? -eq 0 ]; then
                  break
               else
                  if [ $retry_count -lt $max_retries ]; then
                     sleep 2
                  fi
               fi
            done
         fi
      done
   elif [ -x "/usr/bin/apk" ]; then
      for pkg in $installed_before; do
         if ! apk info "$pkg" >/dev/null 2>&1; then
            local retry_count=0
            local max_retries=3
            while [ $retry_count -lt $max_retries ]; do
               retry_count=$((retry_count + 1))
               apk add "$pkg"
               if [ $? -eq 0 ]; then
                  break
               else
                  if [ $retry_count -lt $max_retries ]; then
                     sleep 2
                  fi
               fi
            done
         fi
      done
   fi
}

uci -q set openclash.config.enable=0
uci -q commit openclash

install_retry_count=0
max_install_retries=3
install_success=false

while [ $install_retry_count -lt $max_install_retries ]; do
   install_retry_count=$((install_retry_count + 1))
   LOG_OUT "Tip:【$install_retry_count/$max_install_retries】Installing the new version, please do not refresh the page or do other operations..."
   
   packages_to_check="luci-compat kmod-inet-diag kmod-nft-tproxy kmod-ipt-nat iptables-mod-tproxy iptables-mod-extra ipset"
   installed_before=""
   if [ -x "/bin/opkg" ]; then
      for pkg in $packages_to_check; do
         if opkg status "$pkg" >/dev/null 2>&1; then
            installed_before="$installed_before $pkg"
         fi
      done
      opkg install /tmp/openclash.ipk
   elif [ -x "/usr/bin/apk" ]; then
      for pkg in $packages_to_check; do
         if apk info "$pkg" >/dev/null 2>&1; then
            installed_before="$installed_before $pkg"
         fi
      done
      apk add -q --force-overwrite --clean-protected --allow-untrusted /tmp/openclash.apk
   fi
   
   sleep 2
   
   if check_install_success "$LAST_VER"; then
      install_success=true
      install_missing_packages "$installed_before"
      break
   else
      LOG_OUT "Error:【$install_retry_count/$max_install_retries】Installation failed..."
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
   LOG_OUT "Tip: OpenClash update successful, about to restart!"
   uci -q set openclash.config.enable=1
   uci -q commit openclash
   /etc/init.d/openclash restart 2>/dev/null
else
   if [ -x "/bin/opkg" ]; then
      LOG_OUT "Error: OpenClash update failed after 3 attempts, the file is saved in /tmp/openclash.ipk, please try to update manually with【opkg install /tmp/openclash.ipk】"
   elif [ -x "/usr/bin/apk" ]; then
      LOG_OUT "Error: OpenClash update failed after 3 attempts, the file is saved in /tmp/openclash.apk, please try to update manually with【apk add -q --force-overwrite --clean-protected --allow-untrusted /tmp/openclash.apk】"
   fi
   SLOG_CLEAN
fi

del_update_lock
EOF
   chmod 4755 /tmp/openclash_update.sh

   if [ ! -f "/tmp/openclash_update.sh" ] || [ ! -s "/tmp/openclash_update.sh" ] || [ ! -x "/tmp/openclash_update.sh" ]; then
      LOG_OUT "Error: Failed to create update script!"
      rm -rf /tmp/openclash_update.sh
      del_lock
      exit 1
   fi

   retry_count=0
   max_retries=3
   service_started=false

   while [ $retry_count -lt $max_retries ]; do
      retry_count=$((retry_count + 1))
      LOG_OUT "Tip:【$retry_count/$max_retries】Attempting to start update service..."
      
      ubus call service add '{"name":"openclash_update","instances":{"update":{"command":["/tmp/openclash_update.sh"],"stdout":true,"stderr":true,"env":{"LAST_VER":"'"$LAST_VER"'"}}}}' >/dev/null 2>&1
      
      sleep 3
      
      if ubus call service list '{"name":"openclash_update"}' 2>/dev/null | jsonfilter -e '@.openclash_update.instances.*.running' | grep -q 'true'; then
         service_started=true
         break
      else
         if [ $retry_count -lt $max_retries ]; then
            LOG_OUT "Error:【$retry_count/$max_retries】Service start failed, retrying in 2 seconds..."
            sleep 2
         fi
      fi
   done
   
   if [ "$service_started" = false ]; then
      LOG_OUT "Error: Failed to start update service after 3 attempts, please check and try again later..."
   fi

   (sleep 15; rm -f /tmp/openclash_update.sh) &
else
   if [ ! -f "$LAST_OPVER" ] || [ -z "$OP_CV" ] || [ -z "$OP_LV" ]; then
      LOG_OUT "Error: Failed to get version information, please try again later..."
   else
      LOG_OUT "Tip: OpenClash has not been updated, stop continuing!"
   fi
   if [ "$(uci_get_config "restart")" -eq 1 ]; then
      uci -q set openclash.config.restart=0
      uci -q commit openclash
      /etc/init.d/openclash restart >/dev/null 2>&1 &
   else
      SLOG_CLEAN
   fi
fi
del_lock
