#!/bin/sh
   RULE_FILE_NAME="$1"
   RULE_FILE_ENNAME=$(grep -F $RULE_FILE_NAME /etc/openclash/game_rules.list |awk -F ',' '{print $3}' 2>/dev/null)
   if [ ! -z "$RULE_FILE_ENNAME" ]; then
      DOWNLOAD_PATH=$(grep -F $RULE_FILE_NAME /etc/openclash/game_rules.list |awk -F ',' '{print $2}' 2>/dev/null)
   else
      DOWNLOAD_PATH=$RULE_FILE_NAME
   fi
   RULE_FILE_DIR="/etc/openclash/game_rules/$RULE_FILE_NAME"
   TMP_RULE_DIR="/tmp/$RULE_FILE_NAME"
   START_LOG="/tmp/openclash_start.log"
   LOGTIME=$(date "+%Y-%m-%d %H:%M:%S")
   LOG_FILE="/tmp/openclash.log"
   echo "开始下载【$RULE_FILE_NAME】规则..." >$START_LOG
   curl -sL --connect-timeout 10 --retry 2 https://raw.githubusercontent.com/FQrabbit/SSTap-Rule/master/rules/"$DOWNLOAD_PATH" -o "$TMP_RULE_DIR" >/dev/null 2>&1
   if [ "$?" -eq "0" ] && [ "$(ls -l $TMP_RULE_DIR |awk '{print $5}')" -ne 0 ]; then
      echo "【$RULE_FILE_NAME】规则下载成功，检查规则版本是否更新..." >$START_LOG
      cmp -s $TMP_RULE_DIR $RULE_FILE_DIR
         if [ "$?" -ne "0" ]; then
            echo "规则版本有更新，开始替换旧规则版本..." >$START_LOG\
            && mv $TMP_RULE_DIR $RULE_FILE_DIR >/dev/null 2>&1\
            && echo "删除下载缓存..." >$START_LOG\
            && rm -rf $TMP_RULE_DIR >/dev/null 2>&1
            echo "【$RULE_FILE_NAME】规则更新成功！" >$START_LOG
            echo "${LOGTIME} Rule File【$RULE_FILE_NAME】 Download Successful" >>$LOG_FILE
            sleep 3
            echo "" >$START_LOG
         else
            echo "【$RULE_FILE_NAME】规则版本没有更新，停止继续操作..." >$START_LOG
            echo "${LOGTIME} Updated Rule File【$RULE_FILE_NAME】 No Change, Do Nothing" >>$LOG_FILE
            rm -rf $TMP_RULE_DIR >/dev/null 2>&1
            sleep 3
            echo "" >$START_LOG
         fi
   else
      echo "【$RULE_FILE_NAME】规则下载失败，请检查网络或稍后再试！" >$START_LOG
      rm -rf $TMP_RULE_DIR >/dev/null 2>&1
      echo "${LOGTIME} Rule File【$RULE_FILE_NAME】 Download Error" >>$LOG_FILE
      sleep 3
      echo "" >$START_LOG
   fi