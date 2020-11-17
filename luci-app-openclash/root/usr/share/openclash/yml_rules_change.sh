#!/bin/sh
. /lib/functions.sh
. /usr/share/openclash/ruby.sh

SCRIPT_FILE="/tmp/yaml_script.yaml"
APPEND_RULE_FILE="/tmp/yaml_append_rule.yaml"
OTHER_RULE_FILE="/tmp/yaml_other_rule.yaml"

/usr/share/openclash/yml_groups_name_get.sh

yml_other_set()
{
	 CONFIG_HASH=$4
	 if [ "$3" = 1 ]; then
   	  if [ -n "$(ruby_read "$CONFIG_HASH" "['rules']")" ]; then
   	  	 if [ -n "$(ruby_read "YAML.load_file('/etc/openclash/custom/openclash_custom_rules.list')" ".to_yaml")" ]; then
            CONFIG_HASH=$(ruby_arr_add_file "$CONFIG_HASH" "['rules']" "0" "/etc/openclash/custom/openclash_custom_rules.list")
         fi
         if [ -n "$(ruby_read "YAML.load_file('/etc/openclash/custom/openclash_custom_rules_2.list')" ".to_yaml")" ]; then
            ruby_add_index=$(ruby_read "$CONFIG_HASH" "['rules'].index(Value['rules'].grep(/(GEOIP|MATCH|FINAL)/).first)")
            [ -z "$ruby_add_index" ] && ruby_add_index="-1"
            CONFIG_HASH=$(ruby_arr_add_file "$CONFIG_HASH" "['rules']" "$ruby_add_index" "/etc/openclash/custom/openclash_custom_rules_2.list")
         fi
      else
         CONFIG_HASH=$(ruby_cover "$CONFIG_HASH" "['rules']" "/etc/openclash/custom/openclash_custom_rules.list")
         CONFIG_HASH=$(ruby_cover "$CONFIG_HASH" "['rules']" "/etc/openclash/custom/openclash_custom_rules_2.list")
      fi
   fi

   if [ "$7" = 1 ] && [ -n "$(ruby_read "$CONFIG_HASH" "['rules']")" ]; then
      cat >> "$APPEND_RULE_FILE" <<-EOF
- DOMAIN-KEYWORD,tracker,DIRECT
- DOMAIN-KEYWORD,announce.php?passkey=,DIRECT
- DOMAIN-KEYWORD,torrent,DIRECT
- DOMAIN-KEYWORD,peer_id=,DIRECT
- DOMAIN-KEYWORD,info_hash,DIRECT
- DOMAIN-KEYWORD,get_peers,DIRECT
- DOMAIN-KEYWORD,find_node,DIRECT
- DOMAIN-KEYWORD,BitTorrent,DIRECT
- DOMAIN-KEYWORD,announce_peer,DIRECT
EOF
      ruby_add_index=$(ruby_read "$CONFIG_HASH" "['rules'].index(Value['rules'].grep(/(GEOIP|MATCH|FINAL)/).first)")
      [ -z "$ruby_add_index" ] && ruby_add_index="-1"
      CONFIG_HASH=$(ruby_arr_add_file "$CONFIG_HASH" "['rules']" "$ruby_add_index" "$APPEND_RULE_FILE")
      CONFIG_HASH=$(ruby_edit "$CONFIG_HASH" "['rules'].to_a.collect!{|x|x.to_s.gsub(/(^MATCH.*|^FINAL.*)/, 'MATCH,DIRECT')}")
   fi

	 if [ -n "$(ruby_read "$CONFIG_HASH" "['rules']")" ]; then
      if [ -z "$(ruby_read "$CONFIG_HASH" "['rules'].grep(/(?=.*198.18)(?=.*REJECT)/)")" ]; then
         ruby_add_index=$(ruby_read "$CONFIG_HASH" "['rules'].index(Value['rules'].grep(/(GEOIP|MATCH|FINAL)/).first)")
         [ -z "$ruby_add_index" ] && ruby_add_index="-1"
         CONFIG_HASH=$(ruby_arr_insert "$CONFIG_HASH" "['rules']" "$ruby_add_index" "IP-CIDR,198.18.0.1/16,REJECT,no-resolve")
      fi
   fi

   ruby -ryaml -E UTF-8 -e "Value = $CONFIG_HASH; File.open('$8','w') {|f| YAML.dump(Value, f)}" 2>/dev/null

}

if [ "$2" != 0 ]; then
   #判断策略组是否存在
   GlobalTV=$(uci get openclash.config.GlobalTV 2>/dev/null)
   AsianTV=$(uci get openclash.config.AsianTV 2>/dev/null)
   Proxy=$(uci get openclash.config.Proxy 2>/dev/null)
   Youtube=$(uci get openclash.config.Youtube 2>/dev/null)
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
         yml_other_set "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$10"
         exit 0
	    fi
   elif [ "$2" = "ConnersHua" ]; then
       if [ -z "$(grep "$GlobalTV" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$AsianTV" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$Proxy" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$Others" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$Domestic" /tmp/Proxy_Group)" ]; then
         echo "${1} Warning: Because of The Different Porxy-Group's Name, Stop Setting The Other Rules!" >>/tmp/openclash.log
         yml_other_set "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$10"
         exit 0
       fi
   elif [ "$2" = "lhie1" ]; then
       if [ -z "$(grep "$GlobalTV" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$AsianTV" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$Proxy" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$Youtube" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$Apple" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$Netflix" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$Spotify" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$Steam" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$AdBlock" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$Speedtest" /tmp/Proxy_Group)" ]\
   || [ -z "$(grep "$Telegram" /tmp/Proxy_Group)" ]\
   || [ -z "$(grep "$Microsoft" /tmp/Proxy_Group)" ]\
   || [ -z "$(grep "$PayPal" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$Others" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep "$Domestic" /tmp/Proxy_Group)" ]; then
         echo "${1} Warning: Because of The Different Porxy-Group's Name, Stop Setting The Other Rules!" >>/tmp/openclash.log
         yml_other_set "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$10"
         exit 0
       fi
   fi
   if [ "$Proxy" = "读取错误，配置文件异常！" ]; then
      echo "${1} Warning: Can not Get The Porxy-Group's Name, Stop Setting The Other Rules!" >>/tmp/openclash.log
      yml_other_set "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$10"
      exit 0
   else
       #删除原有的部分，防止冲突
       CONFIG_HASH=$4
       if [ -n "$(ruby_read "$CONFIG_HASH" "['script']")" ]; then
          CONFIG_HASH=$(ruby_edit "$CONFIG_HASH" "['script'].clear")
       fi
       if [ -n "$(ruby_read "$CONFIG_HASH" "['rules']")" ]; then
          CONFIG_HASH=$(ruby_edit "$CONFIG_HASH" "['rules'].clear")
       fi
       if [ "$2" = "lhie1" ]; then
       	    cp /usr/share/openclash/res/lhie1.yaml "$9"
       	    sed -n '/^ \{0,\}script:/,$p' "$9" > "$OTHER_RULE_FILE" 2>/dev/null
       	    sed -i '/^ \{0,\}script:/,$d' "$9" 2>/dev/null
       	    if [ -n "$(ruby_read "YAML.load_file('$9')" "['proxy-providers']")" ]; then
               if [ -z "$(ruby_read "$CONFIG_HASH" "['proxy-providers']")" ]; then
                  CONFIG_HASH=$(ruby_cover "$CONFIG_HASH" "['proxy-providers']" "$9" "['proxy-providers']")
               else
                  CONFIG_HASH=$(ruby_merge "$CONFIG_HASH" "['proxy-providers']" "$9" "['proxy-providers']")
               fi
            fi
       	    CONFIG_HASH=$(ruby -ryaml -E UTF-8 -e "Value = $CONFIG_HASH;
       	    Value_1 = YAML.load_file('$OTHER_RULE_FILE');
       	    Value['script']=Value_1['script'];
       	    Value['rules']=Value_1['rules'];
       	    Value['rules'].to_a.collect!{|x|
       	    x.to_s.gsub(/,GlobalTV$/, ',$GlobalTV#d')
       	    .gsub(/,AsianTV$/, ',$AsianTV#d')
       	    .gsub(/,Proxy$/, ',$Proxy#d')
       	    .gsub(/,YouTube$/, ',$Youtube#d')
       	    .gsub(/,Apple$/, ',$Apple#d')
       	    .gsub(/,Netflix$/, ',$Netflix#d')
       	    .gsub(/,Spotify$/, ',$Spotify#d')
       	    .gsub(/,Steam$/, ',$Steam#d')
       	    .gsub(/,AdBlock$/, ',$AdBlock#d')
       	    .gsub(/,Speedtest$/, ',$Speedtest#d')
       	    .gsub(/,Telegram$/, ',$Telegram#d')
       	    .gsub(/,Microsoft$/, ',$Microsoft#d')
       	    .to_s.gsub(/,PayPal$/, ',$PayPal#d')
       	    .gsub(/,Domestic$/, ',$Domestic#d')
       	    .gsub(/,Others$/, ',$Others#d')
       	    .gsub(/#d/, '')
       	    };
       	    Value['script']['code'].gsub!(/: \"GlobalTV\"/,': \"$GlobalTV#d\"')
       	    .gsub!(/: \"AsianTV\"/,': \"$AsianTV#d\"')
       	    .gsub!(/: \"Proxy\"/,': \"$Proxy#d\"')
       	    .gsub!(/: \"YouTube\"/,': \"$Youtube#d\"')
       	    .gsub!(/: \"Apple\"/,': \"$Apple#d\"')
       	    .gsub!(/: \"Netflix\"/,': \"$Netflix#d\"')
       	    .gsub!(/: \"Spotify\"/,': \"$Spotify#d\"')
       	    .gsub!(/: \"Steam\"/,': \"$Steam#d\"')
       	    .gsub!(/: \"AdBlock\"/,': \"$AdBlock#d\"')
       	    .gsub!(/: \"Speedtest\"/,': \"$Speedtest#d\"')
       	    .gsub!(/: \"Telegram\"/,': \"$Telegram#d\"')
       	    .gsub!(/: \"Microsoft\"/,': \"$Microsoft#d\"')
       	    .gsub!(/: \"PayPal\"/,': \"$PayPal#d\"')
       	    .gsub!(/: \"Domestic\"/,': \"$Domestic#d\"')
       	    .gsub!(/return \"Domestic\"$/, 'return \"$Domestic#d\"')
       	    .gsub!(/return \"Others\"$/, 'return \"$Others#d\"')
       	    .gsub!(/#d/, '');
       	    puts Value" 2>/dev/null || echo $CONFIG_HASH)
       elif [ "$2" = "ConnersHua" ]; then
            cp /usr/share/openclash/res/ConnersHua.yaml "$9"
            sed -n '/^rules:/,$p' "$9" > "$OTHER_RULE_FILE" 2>/dev/null
            sed -i '/^rules:/,$d' "$9" 2>/dev/null
            if [ -n "$(ruby_read "YAML.load_file('$9')" "['proxy-providers']")" ]; then
               if [ -z "$(ruby_read "$CONFIG_HASH" "['proxy-providers']")" ]; then
                  CONFIG_HASH=$(ruby_cover "$CONFIG_HASH" "['proxy-providers']" "$9" "['proxy-providers']")
               else
                  CONFIG_HASH=$(ruby_merge "$CONFIG_HASH" "['proxy-providers']" "$9" "['proxy-providers']")
               fi
            fi
            CONFIG_HASH=$(ruby -ryaml -E UTF-8 -e "Value = $CONFIG_HASH;
       	    Value_1 = YAML.load_file('$OTHER_RULE_FILE');
       	    Value['rules']=Value_1['rules'];
       	    Value['rules'].to_a.collect!{|x|
       	    x.to_s.gsub(/,Streaming$/, ',$GlobalTV#d')
       	    .gsub(/,StreamingSE$/, ',$AsianTV#d')
       	    .gsub(/(,PROXY$|,IP-Blackhole$)/, ',$Proxy#d')
       	    .gsub(/,China,DIRECT$/, ',China,$Domestic#d')
       	    .gsub(/,ChinaIP,DIRECT$/, ',ChinaIP,$Domestic#d')
       	    .gsub(/,CN,DIRECT$/, ',CN,$Domestic#d')
       	    .gsub(/,MATCH$/, ',$Others#d')
       	    .gsub(/#d/, '')
       	    };
       	    puts Value" 2>/dev/null || echo $CONFIG_HASH)
       else
            CONFIG_HASH=$(ruby -ryaml -E UTF-8 -e "Value = $CONFIG_HASH;
       	    Value_1 = YAML.load_file('/usr/share/openclash/res/ConnersHua_return.yaml');
       	    Value['rules']=Value_1['rules'];
       	    Value['rules'].to_a.collect!{|x|
       	    x.to_s.gsub(/,PROXY$/, ',$Proxy#d')
       	    .gsub(/MATCH,DIRECT$/, 'MATCH,$Others#d')
       	    .gsub(/#d/, '')
       	    };
       	    puts Value" 2>/dev/null || echo $CONFIG_HASH)
       fi
   fi
fi

yml_other_set "$1" "$2" "$3" "$CONFIG_HASH" "$5" "$6" "$7" "$10"