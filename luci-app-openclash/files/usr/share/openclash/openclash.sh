#!/bin/sh
START_LOG="/tmp/openclash_start.log"
LOGTIME=$(date "+%Y-%m-%d %H:%M:%S")
echo "开始下载配置文件..." >$START_LOG
subscribe_url=$(uci get openclash.config.subscribe_url 2>/dev/null)
wget-ssl --no-check-certificate "$subscribe_url" -O /tmp/config.yml 
if [ "$?" -eq "0" ]; then
   echo "配置文件下载成功，检查是否有更新..." >$START_LOG
   if [ -f /etc/openclash/config.yml ]; then
      cmp -s /etc/openclash/config.bak /tmp/config.yml
         if [ "$?" -ne "0" ]; then
            echo "配置文件有更新，开始替换..." >$START_LOG
            mv /tmp/config.yml /etc/openclash/config.yml 2>/dev/null\
            && cp /etc/openclash/config.yml /etc/openclash/config.bak\
            && echo "配置文件替换成功，开始启动 OpenClash ..." >$START_LOG\
            && /etc/init.d/openclash restart 2>/dev/null
            echo "${LOGTIME} Config Update Successful" >>/tmp/openclash.log
         else
            echo "配置文件没有任何更新，停止继续操作..." >$START_LOG
            rm -rf /tmp/config.yml
            echo "${LOGTIME} Updated Config No Change, Do Nothing" >>/tmp/openclash.log
            sleep 5
            echo "" >$START_LOG
         fi
   else
      echo "配置文件下载成功，本地没有配置文件，开始创建 ..." >$START_LOG
      mv /tmp/config.yml /etc/openclash/config.yml 2>/dev/null\
      && cp /etc/openclash/config.yml /etc/openclash/config.bak\
      && echo "配置文件创建成功，开始启动 OpenClash ..." >$START_LOG\
      && /etc/init.d/openclash restart 2>/dev/null
      echo "${LOGTIME} Config Update Successful" >>/tmp/openclash.log
   fi
else
   echo "配置文件下载失败，请检查网络或稍后再试！" >$START_LOG
   echo "${LOGTIME} Config Update Error" >>/tmp/openclash.log
   rm -rf /tmp/config.yml 2>/dev/null
   sleep 10
   echo "" >$START_LOG
fi
