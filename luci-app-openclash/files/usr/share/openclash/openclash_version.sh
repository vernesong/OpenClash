#!/bin/sh
CKTIME=$(date "+%Y%m%d")
LAST_OPVER="/tmp/openclash_last_version"
version_url="https://github.com/vernesong/OpenClash/raw/master/version"
if [ "$CKTIME" != "`grep 'ChekTime' $LAST_OPVER  2>/dev/null |awk -F ':' '{print $2}'`" ] || [ ! -f "$LAST_OPVER" ]; then
wget-ssl --no-check-certificate --timeout=3 --tries=2 "$version_url" -O $LAST_OPVER
if [ "$?" -eq "0" ] && [ "`ls -l $LAST_OPVER  2>/dev/null |awk '{print int($5/1024)}'`" -gt 3 ]; then
   if [ -f "$LAST_OPVER" ]; then
      if [ "$(sed -n 1p /etc/openclash/openclash_version 2>/dev/null)" = "$(sed -n 1p $LAST_OPVER 2>/dev/null)" ]; then
         echo "ChekTime:$CKTIME" >$LAST_OPVER
      else
         sed -i "/^data:image/i\ChekTime:${CKTIME}" "$LAST_OPVER" 2>/dev/null
      fi
   fi
else
   echo "ChekTime:$CKTIME" >$LAST_OPVER
fi
else
if [ "`ls -l $LAST_OPVER |awk '{print int($5/1024)}'`" -gt 3 ]; then
   if [ "$(sed -n 1p /etc/openclash/openclash_version)" = "$(sed -n 1p $LAST_OPVER)" ]; then
      echo "ChekTime:$CKTIME" >$LAST_OPVER
   else
      sed -i '/^ChekTime:/d' "$LAST_OPVER" 2>/dev/null
      sed -i "/^data/i\ChekTime:${CKTIME}" "$LAST_OPVER" 2>/dev/null
   fi
fi
fi