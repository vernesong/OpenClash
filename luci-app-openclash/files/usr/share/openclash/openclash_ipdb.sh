#!/bin/sh
   START_LOG="/tmp/openclash_start.log"
   LOGTIME=$(date "+%Y-%m-%d %H:%M:%S")
   echo "开始下载 GEOIP 数据库..." >$START_LOG
   wget-ssl --no-check-certificate https://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.tar.gz -O /tmp/ipdb.tar.gz
   if [ "$?" -eq "0" ]; then
      echo "GEOIP 数据库下载成功，检查数据库版本是否更新..." >$START_LOG
      tar zxvf /tmp/ipdb.tar.gz -C /tmp >/dev/null 2>&1\
      && rm -rf /tmp/ipdb.tar.gz >/dev/null 2>&1
      cmp -s /tmp/GeoLite2-Country_*/GeoLite2-Country.mmdb /etc/openclash/Country.mmdb
         if [ "$?" -ne "0" ]; then
            echo "数据库版本有更新，开始替换数据库版本..." >$START_LOG
            /etc/init.d/openclash stop\
            && mv /tmp/GeoLite2-Country_*/GeoLite2-Country.mmdb /etc/openclash/Country.mmdb >/dev/null 2>&1\
            && /etc/init.d/openclash start\
            && echo "删除下载缓存..." >$START_LOG\
            && rm -rf /tmp/GeoLite2-Country_* >/dev/null 2>&1
            echo "GEOIP 数据库更新成功！" >$START_LOG
            echo "${LOGTIME} GEOIP Database Update Successful" >>/tmp/openclash.log
            sleep 10
            echo "" >$START_LOG
         else
            echo "数据库版本没有更新，停止继续操作..." >$START_LOG
            echo "${LOGTIME} Updated GEOIP Database No Change, Do Nothing" >>/tmp/openclash.log
            rm -rf /tmp/GeoLite2-Country_* >/dev/null 2>&1
            sleep 5
            echo "" >$START_LOG
         fi
   else
      echo "GEOIP 数据库下载失败，请检查网络或稍后再试！" >$START_LOG
      rm -rf /tmp/ipdb.tar.gz >/dev/null 2>&1
      echo "${LOGTIME} GEOIP Database Update Error" >>/tmp/openclash.log
      sleep 10
      echo "" >$START_LOG
   fi