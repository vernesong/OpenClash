#!/bin/sh
   START_LOG="/tmp/openclash_start.log"
   LOGTIME=$(date "+%Y-%m-%d %H:%M:%S")
   echo "开始获取使用中的第三方规则名称..." >$START_LOG
   rule_source=$(uci get openclash.config.rule_source 2>/dev/null)
   echo "开始下载使用中的第三方规则..." >$START_LOG
      if [ "$rule_source" = "lhie1" ]; then
         wget-ssl --no-check-certificate https://raw.githubusercontent.com/lhie1/Rules/master/Clash/Rule.yml -O /tmp/rules.yml
      elif [ "$rule_source" = "ConnersHua" ]; then
         wget-ssl --no-check-certificate https://raw.githubusercontent.com/ConnersHua/Profiles/master/Clash/Global.yml -O /tmp/rules.yml
         sed -i -n '/^Rule:$/,$p' /tmp/rules.yml
      elif [ "$rule_source" = "ConnersHua_return" ]; then
         wget-ssl --no-check-certificate https://raw.githubusercontent.com/ConnersHua/Profiles/master/Clash/China.yml -O /tmp/rules.yml
         sed -i -n '/^Rule:$/,$p' /tmp/rules.yml
      fi
   if [ "$?" -eq "0" ] && [ "$rule_source" != 0 ]; then
      echo "下载成功，开始预处理规则文件..." >$START_LOG
      sed -i "/^Rule:$/a\##source:${rule_source}" /tmp/rules.yml >/dev/null 2>&1
      echo "检查下载的规则文件是否有更新..." >$START_LOG
      cmp -s /etc/openclash/"$rule_source".yml /tmp/rules.yml
      if [ "$?" -ne "0" ]; then
         echo "检测到下载的规则文件有更新，开始替换..." >$START_LOG
         mv /tmp/rules.yml /etc/openclash/"$rule_source".yml >/dev/null 2>&1
         sed -i '/^Rule:$/a\##updated' /etc/openclash/"$rule_source".yml >/dev/null 2>&1
         echo "替换成功，重新加载 OpenClash 应用新规则..." >$START_LOG
         /etc/init.d/openclash reload 2>/dev/null
         echo "${LOGTIME} Other Rules Update Successful" >>/tmp/openclash.log
      else
         echo "检测到下载的规则文件没有更新，停止继续操作..." >$START_LOG
         rm -rf /tmp/rules.yml >/dev/null 2>&1
         echo "${LOGTIME} Updated Other Rules No Change, Do Nothing" >>/tmp/openclash.log
         sleep 10
         echo "" >$START_LOG
      fi
   else
      echo "第三方规则下载失败，请检查网络或稍后再试！" >$START_LOG
      rm -rf /tmp/rules.yml >/dev/null 2>&1
      echo "${LOGTIME} Other Rules Update Error" >>/tmp/openclash.log
      sleep 10
      echo "" >$START_LOG
   fi