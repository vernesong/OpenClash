#!/bin/sh
CKTIME=$(date "+%Y-%m-%d-%H")
LAST_OPVER="/tmp/openclash_last_version"
RELEASE_BRANCH=$(uci -q get openclash.config.release_branch || echo "master")
OP_CV=$(sed -n 1p /usr/share/openclash/res/openclash_version 2>/dev/null |awk -F '-' '{print $1}' |awk -F 'v' '{print $2}' |awk -F '.' '{print $2$3}' 2>/dev/null)
OP_LV=$(sed -n 1p $LAST_OPVER 2>/dev/null |awk -F '-' '{print $1}' |awk -F 'v' '{print $2}' |awk -F '.' '{print $2$3}' 2>/dev/null)
github_address_mod=$(uci -q get openclash.config.github_address_mod || echo 0)

if [ "$CKTIME" != "$(grep "CheckTime" $LAST_OPVER 2>/dev/null |awk -F ':' '{print $2}')" ]; then
	 if [ "$github_address_mod" != "0" ]; then
      if [ "$github_address_mod" == "https://cdn.jsdelivr.net/" ]; then
         curl -sL -m 3 --retry 2 https://cdn.jsdelivr.net/gh/vernesong/OpenClash@"$RELEASE_BRANCH"/version -o $LAST_OPVER >/dev/null 2>&1
      else
         curl -sL -m 3 --retry 2 "$github_address_mod"https://raw.githubusercontent.com/vernesong/OpenClash/"$RELEASE_BRANCH"/version -o $LAST_OPVER >/dev/null 2>&1
      fi
   else
      curl -sL -m 3 --retry 2 https://raw.githubusercontent.com/vernesong/OpenClash/"$RELEASE_BRANCH"/version -o $LAST_OPVER >/dev/null 2>&1
   fi
   
   if [ "$?" -eq "0" ] && [ -s "$LAST_OPVER" ]; then
   	  OP_LV=$(sed -n 1p $LAST_OPVER 2>/dev/null |awk -F '-' '{print $1}' |awk -F 'v' '{print $2}' |awk -F '.' '{print $2$3}' 2>/dev/null)
      if [ "$(expr "$OP_CV" \>= "$OP_LV")" -eq 1 ]; then
         sed -i "/^https:/i\CheckTime:${CKTIME}" "$LAST_OPVER" 2>/dev/null
         sed -i '/^https:/,$d' $LAST_OPVER
      elif [ "$(expr "$OP_LV" \> "$OP_CV")" -eq 1 ] && [ -n "$OP_LV" ]; then
         sed -i "/^https:/i\CheckTime:${CKTIME}" "$LAST_OPVER" 2>/dev/null
         return 2
      fi
   else
      rm -rf "$LAST_OPVER"
   fi
elif [ "$(expr "$OP_CV" \>= "$OP_LV")" -eq 1 ]; then
   sed -i '/^CheckTime:/,$d' $LAST_OPVER
   echo "CheckTime:$CKTIME" >> $LAST_OPVER
elif [ "$(expr "$OP_LV" \> "$OP_CV")" -eq 1 ] && [ -n "$OP_LV" ]; then
   return 2
fi 2>/dev/null
