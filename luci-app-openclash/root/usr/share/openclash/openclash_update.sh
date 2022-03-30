#!/bin/sh
. /usr/share/openclash/log.sh

set_lock() {
   exec 878>"/tmp/lock/openclash_update.lock" 2>/dev/null
   flock -x 878 2>/dev/null
}

del_lock() {
   flock -u 878 2>/dev/null
   rm -rf "/tmp/lock/openclash_update.lock"
}

#一键更新
if [ "$1" = "one_key_update" ]; then
   uci -q set openclash.config.enable=1
   uci -q commit openclash
   /usr/share/openclash/openclash_core.sh "$1" >/dev/null 2>&1 &
   /usr/share/openclash/openclash_core.sh "TUN" "$1" >/dev/null 2>&1 &
   wait
fi

LAST_OPVER="/tmp/openclash_last_version"
LAST_VER=$(sed -n 1p "$LAST_OPVER" 2>/dev/null |sed "s/^v//g" |tr -d "\n")
OP_CV=$(sed -n 1p /usr/share/openclash/res/openclash_version 2>/dev/null |awk -F '-' '{print $1}' |awk -F 'v' '{print $2}' |awk -F '.' '{print $2$3}' 2>/dev/null)
OP_LV=$(sed -n 1p $LAST_OPVER 2>/dev/null |awk -F '-' '{print $1}' |awk -F 'v' '{print $2}' |awk -F '.' '{print $2$3}' 2>/dev/null)
RELEASE_BRANCH=$(uci -q get openclash.config.release_branch || echo "master")
github_address_mod=$(uci -q get openclash.config.github_address_mod || echo 0)
set_lock

if [ "$(expr "$OP_LV" \> "$OP_CV")" -eq 1 ] && [ -f "$LAST_OPVER" ]; then
   LOG_OUT "Start Downloading【OpenClash - v$LAST_VER】..."
   if [ "$github_address_mod" != "0" ]; then
      if [ "$github_address_mod" == "https://cdn.jsdelivr.net/" ]; then
         curl -sL -m 30 --speed-time 15 --speed-limit 1 https://cdn.jsdelivr.net/gh/vernesong/OpenClash@"$RELEASE_BRANCH"/luci-app-openclash_"$LAST_VER"_all.ipk -o /tmp/openclash.ipk >/dev/null 2>&1
      else
         curl -sL -m 30 --speed-time 15 --speed-limit 1 "$github_address_mod"https://raw.githubusercontent.com/vernesong/OpenClash/"$RELEASE_BRANCH"/luci-app-openclash_"$LAST_VER"_all.ipk -o /tmp/openclash.ipk >/dev/null 2>&1
      fi
   else
      curl -sL -m 30 --speed-time 15 --speed-limit 1 https://raw.githubusercontent.com/vernesong/OpenClash/"$RELEASE_BRANCH"/luci-app-openclash_"$LAST_VER"_all.ipk -o /tmp/openclash.ipk >/dev/null 2>&1
   fi
   if [ "$?" != "0" ]; then
      curl -sL -m 30 --speed-time 15 --speed-limit 1 --retry 2 https://mirrors.tuna.tsinghua.edu.cn/osdn/storage/g/o/op/openclash/"$RELEASE_BRANCH"/luci-app-openclash_"$LAST_VER"_all.ipk -o /tmp/openclash.ipk >/dev/null 2>&1
   fi
   if [ "$?" == "0" ] && [ -s "/tmp/openclash.ipk" ]; then
      LOG_OUT "【OpenClash - v$LAST_VER】Download Successful, Start Pre Update Test..."
      opkg install /tmp/openclash.ipk --noaction >>$LOG_FILE
      if [ "$?" != "0" ]; then
         LOG_OUT "【OpenClash - v$LAST_VER】Pre Update Test Failed, The File is Saved in /tmp/opencrash.ipk, Please Try to Update Manually!"
         if [ "$(uci -q get openclash.config.config_reload)" -eq 0 ]; then
      	    /etc/init.d/openclash restart >/dev/null 2>&1 &
         else
            sleep 3
            SLOG_CLEAN
         fi
         del_lock
         exit 0
      fi
      LOG_OUT "【OpenClash - v$LAST_VER】Pre Update Test Passed, Ready to Update and Please Do not Refresh The Page and Other Operations..."
      cat > /tmp/openclash_update.sh <<"EOF"
#!/bin/sh
START_LOG="/tmp/openclash_start.log"
LOG_FILE="/tmp/openclash.log"
LOGTIME=$(date "+%Y-%m-%d %H:%M:%S")
		
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

LOG_OUT "Uninstalling The Old Version, Please Do not Refresh The Page or Do Other Operations..."
uci -q set openclash.config.enable=0
uci -q commit openclash
opkg remove --force-depends --force-remove luci-app-openclash
LOG_OUT "Installing The New Version, Please Do Not Refresh The Page or Do Other Operations..."
opkg install /tmp/openclash.ipk
if [ "$?" == "0" ]; then
   rm -rf /tmp/openclash.ipk >/dev/null 2>&1
   LOG_OUT "OpenClash Update Successful, About To Restart!"
   sleep 3
   uci -q set openclash.config.enable=1
   uci -q commit openclash
   /etc/init.d/openclash restart 2>/dev/null
else
   LOG_OUT "OpenClash Update Failed, The File is Saved in /tmp/openclash.ipk, Please Try to Update Manually!"
   sleep 3
   SLOG_CLEAN
fi
EOF
   chmod 4755 /tmp/openclash_update.sh
   nohup /tmp/openclash_update.sh &
   wait
   rm -rf /tmp/openclash_update.sh
   else
      LOG_OUT "【OpenClash - v$LAST_VER】Download Failed, Please Check The Network or Try Again Later!"
      rm -rf /tmp/openclash.ipk >/dev/null 2>&1
      if [ "$(uci -q get openclash.config.config_reload)" -eq 0 ]; then
      	 /etc/init.d/openclash restart >/dev/null 2>&1 &
      else
         sleep 3
         SLOG_CLEAN
      fi
   fi
else
   if [ ! -f "$LAST_OPVER" ]; then
      LOG_OUT "Failed to Get Version Information, Please Try Again Later..."
   else
      LOG_OUT "OpenClash Has not Been Updated, Stop Continuing!"
   fi
   if [ "$(uci -q get openclash.config.config_reload)" -eq 0 ]; then
      /etc/init.d/openclash restart >/dev/null 2>&1 &
   else
      sleep 3
      SLOG_CLEAN
   fi
fi
del_lock