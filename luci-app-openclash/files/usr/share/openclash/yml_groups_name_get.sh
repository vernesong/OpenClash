#!/bin/sh
CFG_FILE="/etc/openclash/config.yaml"

if [ -f "$CFG_FILE" ]; then
   #检查关键字避免后续操作出错
	 [ ! -z "$(grep "^ \{0,\}'Proxy':" "$CFG_FILE")" ] || [ ! -z "$(grep '^ \{0,\}"Proxy":' "$CFG_FILE")" ] && {
	    sed -i "/^ \{0,\}\'Proxy\':/c\Proxy:" "$CFG_FILE"
	    sed -i '/^ \{0,\}\"Proxy\":/c\Proxy:' "$CFG_FILE"
	 }
	 
	 [ ! -z "$(grep "^ \{0,\}'Proxy Group':" "$CFG_FILE")" ] || [ ! -z "$(grep '^ \{0,\}"Proxy Group":' "$CFG_FILE")" ] && {
	    sed -i "/^ \{0,\}\'Proxy Group\':/c\Proxy Group:" "$CFG_FILE"
	    sed -i '/^ \{0,\}\"Proxy Group\":/c\Proxy Group:' "$CFG_FILE"
	 }
	 
	 [ ! -z "$(grep "^ \{0,\}'Rule':" "$CFG_FILE")" ] || [ ! -z "$(grep '^ \{0,\}"Rule":' "$CFG_FILE")" ] && {
	    sed -i "/^ \{0,\}\'Rule\':/c\Rule:" "$CFG_FILE"
	    sed -i '/^ \{0,\}\"Rule\":/c\Rule:' "$CFG_FILE"
	 }
	 
	 [ ! -z "$(grep "^ \{0,\}'dns':" "$CFG_FILE")" ] || [ ! -z "$(grep '^ \{0,\}"dns":' "$CFG_FILE")" ] && {
	    sed -i "/^ \{0,\}\'dns\':/c\dns:" "$CFG_FILE"
	    sed -i '/^ \{0,\}\"dns\":/c\dns:' "$CFG_FILE"
	 }
	 
   awk '/Proxy Group:/,/Rule:/{print}' /etc/openclash/config.yaml 2>/dev/null |sed "s/\'//g" 2>/dev/null |sed 's/\"//g' 2>/dev/null |sed 's/\t/ /g' 2>/dev/null |grep name: |awk -F 'name:' '{print $2}' |sed 's/,.*//' |sed 's/^ \{0,\}//' 2>/dev/null |sed 's/ \{0,\}$//' 2>/dev/null |sed 's/ \{0,\}\}\{0,\}$//g' 2>/dev/null >/tmp/Proxy_Group 2>&1
   if [ "$?" -eq "0" ]; then
      echo 'DIRECT' >>/tmp/Proxy_Group
      echo 'REJECT' >>/tmp/Proxy_Group
   else
      echo '读取错误，配置文件异常！' >/tmp/Proxy_Group
   fi
else
   echo '读取错误，配置文件异常！' >/tmp/Proxy_Group
fi