#!/bin/bash

lgbm_valid_proxy_port() {
   case "$1" in
      ''|*[!0-9]*) return 1 ;;
   esac
   [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

lgbm_auth_get() {
   local section="$1"
   local enabled username password

   [ -z "$LGBM_PROXY_USERNAME" ] || return 0
   config_get_bool enabled "$section" enabled 1
   config_get username "$section" username ""
   config_get password "$section" password ""
   if [ "$enabled" != "0" ] && [ -n "$username" ] && [ -n "$password" ]; then
      LGBM_PROXY_USERNAME="$username"
      LGBM_PROXY_PASSWORD="$password"
   fi
}

lgbm_load_proxy_auth() {
   LGBM_PROXY_USERNAME=""
   LGBM_PROXY_PASSWORD=""
   config_load openclash >/dev/null 2>&1 || return 0
   config_foreach lgbm_auth_get authentication
}

lgbm_proxy_url() {
   local router_self_proxy mixed_port

   router_self_proxy=$(uci_get_config "router_self_proxy" || echo 1)
   [ "$router_self_proxy" = "1" ] || return 1
   pidof clash >/dev/null 2>&1 || return 1

   mixed_port=$(uci_get_config "mixed_port")
   lgbm_valid_proxy_port "$mixed_port" || return 1
   printf 'http://127.0.0.1:%s' "$mixed_port"
}

download_lgbm_model() {
   local download_url="$1"
   local download_path="$2"
   local model_path="$3"
   local download_result proxy_url

   DOWNLOAD_FILE_CURL "$download_url" "$download_path" "$model_path"
   download_result=$?
   [ "$download_result" -eq 1 ] || return "$download_result"
   case "$download_url" in
      https://github.com/*) ;;
      *) return "$download_result" ;;
   esac

   proxy_url=$(lgbm_proxy_url) || return "$download_result"
   lgbm_load_proxy_auth
   LOG_OUT "Direct LightGBM Model Download Failed, Retrying Through OpenClash Proxy..."
   DOWNLOAD_FILE_CURL "$download_url" "$download_path" "$model_path" "" "" "" \
      "$proxy_url" "$LGBM_PROXY_USERNAME" "$LGBM_PROXY_PASSWORD"
}

if [ "${OPENCLASH_TEST_ONLY:-0}" = "1" ]; then
   return 0 2>/dev/null || exit 0
fi

. /lib/functions.sh
. /usr/share/openclash/openclash_ps.sh
. /usr/share/openclash/log.sh
. /usr/share/openclash/openclash_curl.sh
. /usr/share/openclash/uci.sh

set_lock() {
   exec 868>"/tmp/lock/openclash_lgbm.lock" 2>/dev/null
   flock -x 868 2>/dev/null
}

del_lock() {
   flock -u 868 2>/dev/null
   rm -rf "/tmp/lock/openclash_lgbm.lock" 2>/dev/null
}

set_lock
inc_job_counter

small_flash_memory=$(uci_get_config "small_flash_memory")
LGBM_CUSTOM_URL=$(uci_get_config "lgbm_custom_url")
restart=0

if [ "$small_flash_memory" != "1" ]; then
   lgbm_path="/etc/openclash/Model.bin"
   mkdir -p /etc/openclash
else
   lgbm_path="/tmp/etc/openclash/Model.bin"
   mkdir -p /tmp/etc/openclash
fi
LOG_OUT "Start Downloading LightGBM Model..."
if [ -z "$LGBM_CUSTOM_URL" ]; then
   DOWNLOAD_URL="https://github.com/vernesong/mihomo/releases/download/LightGBM-Model/Model.bin"
else
   DOWNLOAD_URL=$LGBM_CUSTOM_URL
fi
download_lgbm_model "$DOWNLOAD_URL" "/tmp/Model.bin" "$lgbm_path"
DOWNLOAD_RESULT=$?
if [ "$DOWNLOAD_RESULT" -eq 0 ] && [ -s "/tmp/Model.bin" ]; then
   LOG_OUT "LightGBM Model Download Success, Check Updated..."
   cmp -s /tmp/Model.bin "$lgbm_path"
   if [ "$?" -ne "0" ]; then
      LOG_OUT "LightGBM Model Has Been Updated, Starting To Replace The Old Version..."
      rm -rf "/etc/openclash/Model.bin"
      mv /tmp/Model.bin "$lgbm_path" >/dev/null 2>&1
      LOG_OUT "LightGBM Model Update Successful!"
      restart=1
   else
      LOG_OUT "Updated LightGBM Model No Change, Do Nothing..."
   fi
elif [ "$DOWNLOAD_RESULT" -eq 2 ]; then
   LOG_OUT "Updated LightGBM Model No Change, Do Nothing..."
else
   LOG_OUT "LightGBM Model Update Error, Please Try Again Later..."
fi

rm -rf /tmp/Model.bin >/dev/null 2>&1

dec_job_counter_and_restart "$restart"
del_lock
