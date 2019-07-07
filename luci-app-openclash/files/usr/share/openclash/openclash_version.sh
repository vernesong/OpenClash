#!/bin/sh
CKTIME=$(date "+%Y%m%d")
LAST_OPVER="/tmp/openclash_last_version"
version_url="https://github.com/vernesong/OpenClash/raw/master/version"
if [ "$CKTIME" != "$(grep "CheckTime" $LAST_OPVER 2>/dev/null |awk -F ':' '{print $2}')" ]; then
   wget-ssl --no-check-certificate --quiet --timeout=3 --tries=2 "$version_url" -O $LAST_OPVER
   if [ "$?" -eq "0" ] && [ "$(ls -l $LAST_OPVER 2>/dev/null |awk '{print int($5)}')" -gt 0 ]; then
      if [ "$(sed -n 1p /etc/openclash/openclash_version 2>/dev/null)" = "$(sed -n 1p $LAST_OPVER 2>/dev/null)" ]; then
         echo "CheckTime:$CKTIME" >$LAST_OPVER
      else
         sed -i "/^https:/i\CheckTime:${CKTIME}" "$LAST_OPVER" 2>/dev/null
      fi
   fi
elif [ "$(sed -n 1p /etc/openclash/openclash_version 2>/dev/null)" = "$(sed -n 1p $LAST_OPVER 2>/dev/null)" ]; then
   echo "CheckTime:$CKTIME" >$LAST_OPVER
fi