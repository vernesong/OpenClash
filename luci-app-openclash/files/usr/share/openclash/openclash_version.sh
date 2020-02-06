#!/bin/sh
CKTIME=$(date "+%Y-%m-%d-%H")
LAST_OPVER="/tmp/openclash_last_version"
version_url="https://raw.githubusercontent.com/vernesong/OpenClash/master/version"
if [ "$CKTIME" != "$(grep "CheckTime" $LAST_OPVER 2>/dev/null |awk -F ':' '{print $2}')" ]; then
   curl -sL -m 10 --retry 2 "$version_url" -o $LAST_OPVER >/dev/null 2>&1
   if [ "$?" -eq "0" ] && [ "$(ls -l $LAST_OPVER 2>/dev/null |awk '{print int($5)}')" -gt 0 ]; then
      if [ "$(sed -n 1p /etc/openclash/openclash_version 2>/dev/null)" = "$(sed -n 1p $LAST_OPVER 2>/dev/null)" ]; then
         sed -i "/^https:/i\CheckTime:${CKTIME}" "$LAST_OPVER" 2>/dev/null
         sed -i '/^https:/,$d' $LAST_OPVER
      else
         sed -i "/^https:/i\CheckTime:${CKTIME}" "$LAST_OPVER" 2>/dev/null
      fi
   else
      rm -rf "$LAST_OPVER"
   fi
elif [ "$(sed -n 1p /etc/openclash/openclash_version 2>/dev/null)" = "$(sed -n 1p $LAST_OPVER 2>/dev/null)" ]; then
   sed -i '/^CheckTime:/,$d' $LAST_OPVER
   echo "CheckTime:$CKTIME" >>$LAST_OPVER
fi