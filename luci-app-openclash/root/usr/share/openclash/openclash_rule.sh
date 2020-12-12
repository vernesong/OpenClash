#!/bin/sh
. /usr/share/openclash/openclash_ps.sh
. /lib/functions.sh
. /usr/share/openclash/ruby.sh

   status=$(unify_ps_status "openclash_rule.sh")
   [ "$status" -gt 3 ] && exit 0
   
   START_LOG="/tmp/openclash_start.log"
   LOGTIME=$(date "+%Y-%m-%d %H:%M:%S")
   LOG_FILE="/tmp/openclash.log"
   echo "开始获取使用中的第三方规则名称..." >$START_LOG
   RUlE_SOURCE=$(uci get openclash.config.rule_source 2>/dev/null)
   OTHER_RULE_FILE="/tmp/other_rule.yaml"

   echo "开始下载使用中的第三方规则..." >$START_LOG
      if [ "$RUlE_SOURCE" = "lhie1" ]; then
      	 if pidof clash >/dev/null; then
            curl -sL --connect-timeout 10 --retry 2 https://raw.githubusercontent.com/lhie1/Rules/master/Clash/Rule.yaml -o /tmp/rules.yaml >/dev/null 2>&1
      	 fi
      	 if [ "$?" -ne "0" ] || ! pidof clash >/dev/null; then
            curl -sL --connect-timeout 10 --retry 2 https://cdn.jsdelivr.net/gh/lhie1/Rules@master/Clash/Rule.yaml -o /tmp/rules.yaml >/dev/null 2>&1
         fi
         sed -i '1i rules:' /tmp/rules.yaml
      elif [ "$RUlE_SOURCE" = "ConnersHua" ]; then
      	 if pidof clash >/dev/null; then
            curl -sL --connect-timeout 10 --retry 2 https://raw.githubusercontent.com/DivineEngine/Profiles/master/Clash/Outbound.yaml -o /tmp/rules.yaml >/dev/null 2>&1
      	 fi
      	 if [ "$?" -ne "0" ] || ! pidof clash >/dev/null; then
            curl -sL --connect-timeout 10 --retry 2 https://cdn.jsdelivr.net/gh/DivineEngine/Profiles@master/Clash/Outbound.yaml -o /tmp/rules.yaml >/dev/null 2>&1
         fi
         sed -i "s/# - RULE-SET,ChinaIP,DIRECT/- RULE-SET,ChinaIP,DIRECT/g" /tmp/rules.yaml 2>/dev/null
         sed -i "s/- GEOIP,/#- GEOIP,/g" /tmp/rules.yaml 2>/dev/null
      elif [ "$RUlE_SOURCE" = "ConnersHua_return" ]; then
      	 if pidof clash >/dev/null; then
            curl -sL --connect-timeout 10 --retry 2 https://raw.githubusercontent.com/DivineEngine/Profiles/master/Clash/Inbound.yaml -o /tmp/rules.yaml >/dev/null 2>&1
      	 fi
      	 if [ "$?" -ne "0" ] || ! pidof clash >/dev/null; then
            curl -sL --connect-timeout 10 --retry 2 https://cdn.jsdelivr.net/gh/DivineEngine/Profiles@master/Clash/Inbound.yaml -o /tmp/rules.yaml >/dev/null 2>&1
         fi
      fi
   if [ "$?" -eq "0" ] && [ "$RUlE_SOURCE" != 0 ] && [ -s "/tmp/rules.yaml" ]; then
      echo "下载成功，开始预处理规则文件..." >$START_LOG
      ruby -ryaml -E UTF-8 -e "
      begin
      YAML.load_file('/tmp/rules.yaml');
      rescue Exception => e
      puts '${LOGTIME} Error: Unable To Parse Updated ${RUlE_SOURCE} Rules File ' + e.message
      system 'rm -rf /tmp/rules.yaml 2>/dev/null'
      end
      " 2>/dev/null >> $LOG_FILE
      if [ $? -ne 0 ]; then
         echo "${LOGTIME} Error: Ruby Works Abnormally, Please Check The Ruby Library Depends!" >> $LOG_FILE
         echo "Ruby依赖异常，无法校验配置文件，请确认ruby依赖工作正常后重试！" > $START_LOG
         sleep 3
         exit 0
      elif [ ! -f "/tmp/rules.yaml" ]; then
         echo "$RUlE_SOURCE 规则文件格式校验失败，请稍后再试..." > $START_LOG
         sleep 3
         exit 0
      elif ! "$(ruby_read "/tmp/rules.yaml" ".key?('rules')")" ; then
         echo "${LOGTIME} Error: Updated Others Rules 【$RUlE_SOURCE】 Has No Rules Field, Update Exit..." >> $LOG_FILE
         echo "$RUlE_SOURCE 规则文件规则部分校验失败，请稍后再试..." > $START_LOG
         sleep 3
         exit 0
      fi
      #取出规则部分
      ruby_read "/tmp/rules.yaml" ".select {|x| 'rule-providers' == x or 'script' == x or 'rules' == x }.to_yaml" > "$OTHER_RULE_FILE"
      #合并
      cat "$OTHER_RULE_FILE" > "/tmp/rules.yaml" 2>/dev/null
      rm -rf /tmp/other_rule* 2>/dev/null
      
      echo "检查下载的规则文件是否有更新..." >$START_LOG
      cmp -s /usr/share/openclash/res/"$RUlE_SOURCE".yaml /tmp/rules.yaml
      if [ "$?" -ne "0" ]; then
         echo "检测到下载的规则文件有更新，开始替换..." >$START_LOG
         mv /tmp/rules.yaml /usr/share/openclash/res/"$RUlE_SOURCE".yaml >/dev/null 2>&1
         echo "替换成功，重新加载 OpenClash 应用新规则..." >$START_LOG
         echo "${LOGTIME} Other Rules 【$RUlE_SOURCE】 Update Successful" >>$LOG_FILE
         [ "$(unify_ps_prevent)" -eq 0 ] && /etc/init.d/openclash restart >/dev/null 2>&1 &
      else
         echo "检测到下载的规则文件没有更新，停止继续操作..." >$START_LOG
         rm -rf /tmp/rules.yaml >/dev/null 2>&1
         echo "${LOGTIME} Updated Other Rules 【$RUlE_SOURCE】 No Change, Do Nothing" >>$LOG_FILE
         sleep 5
      fi
   elif [ "$RUlE_SOURCE" = 0 ]; then
      echo "未启用第三方规则，更新程序终止！" >$START_LOG
      rm -rf /tmp/rules.yaml >/dev/null 2>&1
      echo "${LOGTIME} Other Rules Not Enable, Update Stop" >>$LOG_FILE
      sleep 5
   else
      echo "第三方规则下载失败，请检查网络或稍后再试！" >$START_LOG
      rm -rf /tmp/rules.yaml >/dev/null 2>&1
      echo "${LOGTIME} Other Rules 【$RUlE_SOURCE】 Update Error" >>$LOG_FILE
      sleep 5
   fi
   echo "" >$START_LOG
