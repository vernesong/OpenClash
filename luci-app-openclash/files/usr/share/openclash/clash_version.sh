#!/bin/sh
CKTIME=$(date "+%Y-%m-%d-%H")
LAST_OPVER="/tmp/clash_last_version"
LAST_VER=$(sed -n 1p "$LAST_OPVER" 2>/dev/null |awk -F '-' '{print $1$2}' |sed -i "s/v//" |sed -i "s/.//")
CLASH_VERF=$(echo "/etc/openclash/clash -v 2>/dev/null" && awk -F ' ' '{print $2}')
CLASH_VER=$(echo "$CLASH_VERF" 2>/dev/null |awk -F ' ' '{print $2}' |awk -F '-' '{print $1$2}' |sed -i "s/v//" |sed -i "s/.//")
version_url="https://raw.githubusercontent.com/vernesong/OpenClash/master/core_version"
if [ "$CKTIME" != "$(grep "CheckTime" $LAST_OPVER 2>/dev/null |awk -F ':' '{print $2}')" ]; then
   curl -sL --connect-timeout 10 --retry 2 "$version_url" -o $LAST_OPVER >/dev/null 2>&1
   if [ "$?" -eq "0" ] && [ -s "$LAST_OPVER" ]; then
      echo "CheckTime:$CKTIME" >>$LAST_OPVER
   else
      rm -rf $LAST_OPVER
   fi
fi
if [ "$LAST_VER" -gt "$CLASH_VER" ]; then
   return 2
fi