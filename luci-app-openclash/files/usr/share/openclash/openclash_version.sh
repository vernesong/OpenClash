#!/bin/sh
START_LOG="/tmp/openclash_start.log"
version_url="https://github.com/vernesong/OpenClash/raw/master/version"
echo "开始获取最新版本..." >$START_LOG
wget-ssl --no-check-certificate --timeout=3 --tries=2 "$version_url" -O /tmp/openclash_last_version
if [ "$?" -eq "0" ] && [ "`ls -l /tmp/openclash_last_version |awk '{print int($5/1024)}'`" -ne 0 ]; then
   echo "版本获取成功..." >$START_LOG
   if [ -f "/etc/openclash/openclash_version" ]; then
      echo "对比版本信息..." >$START_LOG
      if [ "$(sed -n 1p /etc/openclash/openclash_version)" = "$(sed -n 1p /tmp/openclash_last_version)" ]; then
         echo "" >/tmp/openclash_last_version
         echo "本地 OpenClash 已为最新版本！" >$START_LOG
         sleep 10
      else
         echo "检测到版本更新，点击上方图标前往下载！" >$START_LOG
         sleep 10
      fi
   fi
   echo "" >$START_LOG
else
   echo "" >/tmp/openclash_last_version
   echo "版本获取失败，请稍后再试！" >$START_LOG
   sleep 10
   echo "" >$START_LOG
fi