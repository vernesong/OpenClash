#!/bin/sh

check_def=0
/usr/share/openclash/yml_groups_name_get.sh

if [ "$2" != 0 ]; then
   #判断策略组是否存在
   GlobalTV=$(uci get openclash.config.GlobalTV 2>/dev/null)
   AsianTV=$(uci get openclash.config.AsianTV 2>/dev/null)
   Proxy=$(uci get openclash.config.Proxy 2>/dev/null)
   Apple=$(uci get openclash.config.Apple 2>/dev/null)
   Netflix=$(uci get openclash.config.Netflix 2>/dev/null)
   Spotify=$(uci get openclash.config.Spotify 2>/dev/null)
   Steam=$(uci get openclash.config.Steam 2>/dev/null)
   AdBlock=$(uci get openclash.config.AdBlock 2>/dev/null)
   Netease_Music=$(uci get openclash.config.Netease_Music 2>/dev/null)
   Speedtest=$(uci get openclash.config.Speedtest 2>/dev/null)
   Telegram=$(uci get openclash.config.Telegram 2>/dev/null)
   Microsoft=$(uci get openclash.config.Microsoft 2>/dev/null)
   PayPal=$(uci get openclash.config.PayPal 2>/dev/null)
   Domestic=$(uci get openclash.config.Domestic 2>/dev/null)
   Others=$(uci get openclash.config.Others 2>/dev/null)
   if [ "$2" = "ConnersHua_return" ]; then
	    if [ -z "$(grep "$Proxy" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$Others" /tmp/Proxy_Group)" ];then
         echo "${1} Warning: Because of The Different Porxy-Group's Name, Stop Setting The Other Rules!" >>/tmp/openclash.log
         exit 0
	    fi
   elif [ "$2" = "ConnersHua" ]; then
       if [ -z "$(grep "$GlobalTV" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$AsianTV" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$Proxy" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$Apple" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$AdBlock" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$Others" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$Domestic" /tmp/Proxy_Group)" ]; then
         echo "${1} Warning: Because of The Different Porxy-Group's Name, Stop Setting The Other Rules!" >>/tmp/openclash.log
         exit 0
       fi
   elif [ "$2" = "lhie1" ]; then
       if [ -z "$(grep "$GlobalTV" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$AsianTV" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$Proxy" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$Apple" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$Netflix" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$Spotify" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$Steam" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$AdBlock" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$Netease_Music" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$Speedtest" /tmp/Proxy_Group)" ]\
   || [ -z "$(grep "$Telegram" /tmp/Proxy_Group)" ]\
   || [ -z "$(grep "$Microsoft" /tmp/Proxy_Group)" ]\
   || [ -z "$(grep "$PayPal" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$Others" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$Domestic" /tmp/Proxy_Group)" ]; then
         echo "${1} Warning: Because of The Different Porxy-Group's Name, Stop Setting The Other Rules!" >>/tmp/openclash.log
         exit 0
       fi
   fi
   if [ "$Proxy" = "读取错误，配置文件异常！" ]; then
      echo "${1} Warning: Can not Get The Porxy-Group's Name, Stop Setting The Other Rules!" >>/tmp/openclash.log
      exit 0
   else
    rulesource=$(grep '##source:' "$4" |awk -F ':' '{print $2}')
    [ "$rulesource" != "$2" ] && {
       check_def=1
    	}
    
    [ "$check_def" -ne 1 ] && {
    	grep "^##updated$" /etc/openclash/"$2".yaml 1>/dev/null
    	[ "$?" -eq "0" ] && {
    	sed -i '/^##updated$/d' /etc/openclash/"$2".yaml
        check_def=1
        }
    }

    [ "$check_def" -ne 1 ] && {
    GlobalTV_YAML=$(grep '##GlobalTV:' "$4" |awk -F ':' '{print $2}')
    AsianTV_YAML=$(grep '##AsianTV:' "$4" |awk -F ':' '{print $2}')
    Proxy_YAML=$(grep '##Proxy:' "$4" |awk -F ':' '{print $2}')
    Apple_YAML=$(grep '##Apple:' "$4" |awk -F ':' '{print $2}')
    Netflix_YAML=$(grep '##Netflix:' "$4" |awk -F ':' '{print $2}')
    Spotify_YAML=$(grep '##Spotify:' "$4" |awk -F ':' '{print $2}')
    Steam_YAML=$(grep '##Steam:' "$4" |awk -F ':' '{print $2}')
    AdBlock_YAML=$(grep '##AdBlock:' "$4" |awk -F ':' '{print $2}')
    Others_YAML=$(grep '##Others:' "$4" |awk -F ':' '{print $2}')
    Domestic_YAML=$(grep '##Domestic:' "$4" |awk -F ':' '{print $2}')
    Netease_Music_YAML=$(grep '##Netease_Music:' "$4" |awk -F ':' '{print $2}')
    Speedtest_YAML=$(grep '##Speedtest:' "$4" |awk -F ':' '{print $2}')
    Telegram_YAML=$(grep '##Telegram:' "$4" |awk -F ':' '{print $2}')
    PayPal_YAML=$(grep '##PayPal:' "$4" |awk -F ':' '{print $2}')
    Microsoft_YAML=$(grep '##Microsoft:' "$4" |awk -F ':' '{print $2}')

    if [ "$2" = "ConnersHua_return" ]; then
	     if [ "$Proxy" != "$Proxy_YAML" ]\
	 || [ "$Others" != "$Others_YAML" ];then
         check_def=1
	     fi
    elif [ "$2" = "ConnersHua" ]; then
       if [ "$GlobalTV" != "$GlobalTV_YAML" ]\
	 || [ "$AsianTV" != "$AsianTV_YAML" ]\
	 || [ "$Proxy" != "$Proxy_YAML" ]\
	 || [ "$Apple" != "$Apple_YAML" ]\
	 || [ "$AdBlock" != "$AdBlock_YAML" ]\
	 || [ "$Others" != "$Others_YAML" ]\
	 || [ "$Domestic" != "$Domestic_YAML" ]; then
         check_def=1
       fi
    elif [ "$2" = "lhie1" ]; then
       if [ "$GlobalTV" != "$GlobalTV_YAML" ]\
	 || [ "$AsianTV" != "$AsianTV_YAML" ]\
	 || [ "$Proxy" != "$Proxy_YAML" ]\
	 || [ "$Apple" != "$Apple_YAML" ]\
	 || [ "$Netflix" != "$Netflix_YAML" ]\
	 || [ "$Spotify" != "$Spotify_YAML" ]\
	 || [ "$Steam" != "$Steam_YAML" ]\
	 || [ "$AdBlock" != "$AdBlock_YAML" ]\
	 || [ "$Netease_Music" != "$Netease_Music_YAML" ]\
	 || [ "$Speedtest" != "$Speedtest_YAML" ]\
   || [ "$Telegram" != "$Telegram_YAML" ]\
   || [ "$Microsoft" != "$Microsoft_YAML" ]\
   || [ "$PayPal" != "$PayPal_YAML" ]\
	 || [ "$Others" != "$Others_YAML" ]\
	 || [ "$Domestic" != "$Domestic_YAML" ]; then
         check_def=1
       fi
    fi
    }

    if [ "$check_def" -eq 1 ]; then
       if [ "$2" = "lhie1" ]; then
            sed -i '/^Rule:/,$d' "$4"
            cat /etc/openclash/lhie1.yaml >> "$4"
            sed -i -e "s/,GlobalTV$/,${GlobalTV}#d/g" -e "/Rule:/a\##GlobalTV:${GlobalTV}"\
            -e "s/,AsianTV$/,${AsianTV}#d/g" -e "/Rule:/a\##AsianTV:${AsianTV}"\
            -e "s/,Proxy$/,${Proxy}#d/g" -e "/Rule:/a\##Proxy:${Proxy}"\
            -e "s/,Apple$/,${Apple}#d/g"\
            -e "s/,Apple,no-resolve$/,${Apple},no-resolve#d/g" -e "/Rule:/a\##Apple:${Apple}"\
            -e "s/,Netflix$/,${Netflix}#d/g" -e "/Rule:/a\##Netflix:${Netflix}"\
            -e "s/,Spotify$/,${Spotify}#d/g" -e "/Rule:/a\##Spotify:${Spotify}"\
            -e "s/,Steam$/,${Steam}#d/g" -e "/Rule:/a\##Steam:${Steam}"\
            -e "s/,AdBlock$/,${AdBlock}#d/g" -e "/Rule:/a\##AdBlock:${AdBlock}"\
            -e "s/,Netease Music$/,${Netease_Music}#d/g" -e "/Rule:/a\##Netease_Music:${Netease_Music}"\
            -e "s/,Speedtest$/,${Speedtest}#d/g" -e "/Rule:/a\##Speedtest:${Speedtest}"\
            -e "s/,Telegram$/,${Telegram}#d/g" -e "/Rule:/a\##Telegram:${Telegram}"\
            -e "s/,Microsoft$/,${Microsoft}#d/g" -e "/Rule:/a\##Microsoft:${Microsoft}"\
            -e "s/,PayPal$/,${PayPal}#d/g" -e "/Rule:/a\##PayPal:${PayPal}"\
            -e "s/,Domestic$/,${Domestic}#d/g" -e "/Rule:/a\##Domestic:${Domestic}"\
            -e "s/,Others$/,${Others}#d/g" -e "/Rule:/a\##Others:${Others}"\
            -e "s/#d//g" "$4"
       elif [ "$2" = "ConnersHua" ]; then
            sed -i '/^Rule:/,$d' "$4"
            cat /etc/openclash/ConnersHua.yaml >> "$4"
            sed -i -e "s/,GlobalMedia$/,${GlobalTV}#d/g"\
            -e "s/,GlobalMedia,no-resolve$/,${GlobalTV},no-resolve#d/g" -e "/Rule:/a\##GlobalTV:${GlobalTV}"\
            -e "s/,HKMTMedia$/,${AsianTV}#d/g" -e "/Rule:/a\##AsianTV:${AsianTV}"\
            -e "s/,PROXY$/,${Proxy}#d/g"\
            -e "s/,PROXY,no-resolve$/,${Proxy},no-resolve#d/g" -e "/Rule:/a\##Proxy:${Proxy}"\
            -e "s/,Apple$/,${Apple}#d/g" -e "/Rule:/a\##Apple:${Apple}"\
            -e "s/,Hijacking,no-resolve$/,${AdBlock},no-resolve#d/g"\
            -e "s/,Hijacking$/,${AdBlock}#d/g" -e "/Rule:/a\##AdBlock:${AdBlock}"\
            -e "s/,DIRECT$/,${Domestic}#d/g" -e "/Rule:/a\##Domestic:${Domestic}"\
            -e "s/,Final$/,${Others}#d/g" -e "/Rule:/a\##Others:${Others}"\
            -e "s/#d//g" "$4"
       else
            sed -i '/^Rule:/,$d' "$4"
            cat /etc/openclash/ConnersHua_return.yaml >> "$4"
            sed -i -e "s/,PROXY$/,${Proxy}#d/g" -e "/Rule:/a\##Proxy:${Proxy}"\
            -e "s/,DIRECT$/,${Others}#d/g" -e "/Rule:/a\##Others:${Others}"\
            -e "s/#d//g" "$4"
       fi
    fi
   fi
elif [ "$2" = 0 ]; then
   [ -f "$8" ] && {
      grep '##source:' "$4" 1>/dev/null
      if [ "$?" -eq "0" ]; then
         cp "$8" /etc/openclash/configrules.bak
         sed -i -n '/^Rule:/,$p' /etc/openclash/configrules.bak
         sed -i '/^Rule:/,$d' "$4"
         cat /etc/openclash/configrules.bak >> "$4"
         rm -rf /etc/openclash/configrules.bak
      fi
    	}
fi

      sed -i "s/'//g" "$4" 2>/dev/null
      sed -i '/^##Custom Rules##/,/^##Custom Rules End##/d' "$4" 2>/dev/null
      sed -i '/^##Custom Rules##/d' "$4" 2>/dev/null
      sed -i '/^##Custom Rules End##/d' "$4" 2>/dev/null
      sed -i '/^##Custom Rules 2##/,/^##Custom Rules 2 End##/d' "$4" 2>/dev/null
      sed -i '/^##Custom Rules 2##/d' "$4" 2>/dev/null
      sed -i '/^##Custom Rules 2 End##/d' "$4" 2>/dev/null
      sed -i '/- DOMAIN-KEYWORD,tracker,DIRECT/d' "$4" 2>/dev/null
      sed -i '/- DOMAIN-KEYWORD,announce,DIRECT/d' "$4" 2>/dev/null
      sed -i '/- DOMAIN-KEYWORD,torrent,DIRECT/d' "$4" 2>/dev/null
      
      if [ -z "$(grep '^ \{0,\}- IP-CIDR,198.18.0.1/16,REJECT,no-resolve' "$4")" ] && [ "$6" = "fake-ip" ]; then
         if [ ! -z "$(grep "^ \{0,\}- IP-CIDR,198.18.0.1/16" "$4")" ]; then
            sed -i "/^ \{0,\}- IP-CIDR,198.18.0.1\/16/c\- IP-CIDR,198.18.0.1\/16,REJECT,no-resolve" "$4" 2>/dev/null
         else
            sed -i '1,/^ \{0,\}- GEOIP/{/^ \{0,\}- GEOIP/s/^ \{0,\}- GEOIP/- IP-CIDR,198.18.0.1\/16,REJECT,no-resolve\n&/}' "$4" 2>/dev/null\
            || sed -i '1,/^ \{0,\}- MATCH/{/^ \{0,\}- MATCH/s/^ \{0,\}- MATCH/- IP-CIDR,198.18.0.1\/16,REJECT,no-resolve\n&/}' "$4" 2>/dev/null\
            || sed -i '1,/^ \{0,\}- FINAL/{/^ \{0,\}- FINAL/s/^ \{0,\}- FINAL/- IP-CIDR,198.18.0.1\/16,REJECT,no-resolve\n&/}' "$4" 2>/dev/null
         fi
      fi
      
      if [ "$7" = 1 ]; then
         sed -i '1,/^ \{0,\}- GEOIP/{/^ \{0,\}- GEOIP/s/^ \{0,\}- GEOIP/- DOMAIN-KEYWORD,tracker,DIRECT\n&/}' "$4" 2>/dev/null\
         || sed -i '1,/^ \{0,\}- MATCH/{/^ \{0,\}- MATCH/s/^ \{0,\}- MATCH/- DOMAIN-KEYWORD,tracker,DIRECT\n&/}' "$4" 2>/dev/null\
         || sed -i '1,/^ \{0,\}- FINAL/{/^ \{0,\}- FINAL/s/^ \{0,\}- FINAL/- DOMAIN-KEYWORD,tracker,DIRECT\n&/}' "$4" 2>/dev/null\
         || echo "- DOMAIN-KEYWORD,tracker,DIRECT" >> "$4" 2>/dev/null
         sed -i "/- DOMAIN-KEYWORD,tracker,DIRECT/a\- DOMAIN-KEYWORD,announce,DIRECT" "$4" 2>/dev/null
         sed -i "/- DOMAIN-KEYWORD,tracker,DIRECT/a\- DOMAIN-KEYWORD,torrent,DIRECT" "$4" 2>/dev/null
         if [ -z "$(grep "###- MATCH," "$4")" ] && [ -z "$(grep "###- FINAL," "$4")" ]; then
            sed -i 's/- MATCH,/###&/' "$4" 2>/dev/null
            sed -i 's/- FINAL,/###&/' "$4" 2>/dev/null
            echo "- MATCH,DIRECT" >> "$4" 2>/dev/null
         fi
      else
         if [ ! -z "$(grep "###- MATCH," "$4")" ] || [ ! -z "$(grep "###- FINAL," "$4")" ]; then
            sed -i '/^- MATCH,DIRECT/d' "$4" 2>/dev/null
            sed -i "s/###- MATCH,/- MATCH,/" "$4" 2>/dev/null
            sed -i "s/###- FINAL,/- FINAL,/" "$4" 2>/dev/null
         fi
      fi
      
      if [ "$3" = 1 ]; then
         sed -i '/^Rule:/a\##Custom Rules End##' "$4" 2>/dev/null
         sed -i '/^Rule:/a\##Custom Rules##' "$4" 2>/dev/null
         sed -i '/^##Custom Rules##/r/etc/openclash/custom/openclash_custom_rules.list' "$4" 2>/dev/null
         sed -i '/^ \{0,\}- MATCH,/i\##Custom Rules 2##' "$4" 2>/dev/null\
         || sed -i '/^ \{0,\}- FINAL,/i\##Custom Rules 2##' "$4" 2>/dev/null\
         || echo "##Custom Rules 2##" >> "$4" 2>/dev/null
         sed -i '/^##Custom Rules 2##/a\##Custom Rules 2 End##' "$4" 2>/dev/null
         sed -i '/^##Custom Rules 2##/r/etc/openclash/custom/openclash_custom_rules_2.list' "$4" 2>/dev/null
      fi
      
      if [ "$5" = 1 ] || [ "$3" = 1 ] || [ "$7" = 1 ] || [ -z "$(grep '- IP-CIDR,198.18.0.1/16,REJECT,no-resolve' "$4")" ]; then
         sed -i "s/^ \{0,\}-/-/" "$4" 2>/dev/null #修改参数空格
         sed -i "s/^\t\{0,\}-/-/" "$4" 2>/dev/null #修改参数tab
      fi