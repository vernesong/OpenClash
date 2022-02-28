#!/bin/sh
. /lib/functions.sh
. /usr/share/openclash/ruby.sh
. /usr/share/openclash/log.sh

LOGTIME=$(echo $(date "+%Y-%m-%d %H:%M:%S"))
LOG_FILE="/tmp/openclash.log"

yml_other_set()
{
   ruby -ryaml -E UTF-8 -e "
   begin
   Value = YAML.load_file('$3');
   rescue Exception => e
   puts '${LOGTIME} Error: Load File Error,【' + e.message + '】'
   end
   begin
   if $2 == 1 then
   #script
      for i in ['/etc/openclash/custom/openclash_custom_rules.list','/etc/openclash/custom/openclash_custom_rules_2.list'] do
         if File::exist?(i) then
            Value_1 = YAML.load_file(i)
            if Value_1 != false then
               if Value_1.class.to_s == 'Hash' then
                  if Value_1['script'] and Value_1['script'].class.to_s != 'Array' then
                     if Value.key?('script') and not Value_1['script'].to_a.empty? then
                        if Value['script'].key?('code') and Value_1['script'].key?('code') then
                           if not Value['script']['code'].include?('def main(ctx, metadata):') then
                              Value['script']['code'] = Value_1['script']['code']
                           else
                              if i == '/etc/openclash/custom/openclash_custom_rules.list' then
                                 if not Value_1['script']['code'].include?('def main(ctx, metadata):') then
                                    Value['script']['code'].gsub!('def main(ctx, metadata):', \"def main(ctx, metadata):\n\" + Value_1['script']['code'])
                                 else
                                    Value['script']['code'].gsub!('def main(ctx, metadata):', Value_1['script']['code'])
                                 end
                              else
                                 insert_index = Value['script']['code'].index(/ctx.geoip/)
                                 insert_index ||= Value['script']['code'].rindex(/return/)
                                 insert_index ||= -1
                                 if insert_index != -1 then
                                    insert_index  = Value['script']['code'].rindex(\"\n\", insert_index) + 1
                                 end
                                 if not Value_1['script']['code'].include?('def main(ctx, metadata):') then
                                    Value['script']['code'].insert(insert_index, Value_1['script']['code'])
                                 else
                                    Value['script']['code'].insert(insert_index, Value_1['script']['code'].gsub('def main(ctx, metadata):', ''))
                                 end
                              end
                           end
                        elsif Value_1['script'].key?('code') then
                           Value['script']['code'] = Value_1['script']['code']
                        end
                        if Value['script'].key?('shortcuts') and Value_1['script'].key?('shortcuts')
                           Value['script']['shortcuts'].merge!(Value_1['script']['shortcuts']).uniq
                        elsif Value_1['script'].key?('shortcuts') then
                           Value['script']['shortcuts'] = Value_1['script']['shortcuts']
                        end
                     else
                        Value['script'] = Value_1['script']
                     end
                  end
               end
            end
         end
      end;
   #rules
      if Value.has_key?('rules') and not Value['rules'].to_a.empty? then
         if File::exist?('/etc/openclash/custom/openclash_custom_rules.list') then
            Value_1 = YAML.load_file('/etc/openclash/custom/openclash_custom_rules.list')
            if Value_1 != false then
               if Value_1.class.to_s == 'Hash' then
                  if not Value_1['rules'].to_a.empty? and Value_1['rules'].class.to_s == 'Array' then
                     Value_2 = Value_1['rules'].to_a.reverse!
                  end
               elsif Value_1.class.to_s == 'Array'
                  Value_2 = Value_1.reverse!
               end
               if defined? Value_2 then
                  Value_2.each{|x| Value['rules'].insert(0,x)}
                  Value['rules'] = Value['rules'].uniq
               end
            end
         end
         if File::exist?('/etc/openclash/custom/openclash_custom_rules_2.list') then
            Value_3 = YAML.load_file('/etc/openclash/custom/openclash_custom_rules_2.list')
            if Value_3 != false then
               ruby_add_index = Value['rules'].index(Value['rules'].grep(/(GEOIP|MATCH|FINAL)/).first)
               ruby_add_index ||= -1
               if Value_3.class.to_s == 'Hash' then
                  if not Value_3['rules'].to_a.empty? and Value_3['rules'].class.to_s == 'Array' then
                     Value_4 = Value_3['rules'].to_a.reverse!
                  end
               elsif Value_3.class.to_s == 'Array'
                  Value_4 = Value_3.reverse!
               end
               if defined? Value_4 then
                  if ruby_add_index == -1 then
                     Value_4 = Value_4.reverse!
                  end
                  Value_4.each{|x| Value['rules'].insert(ruby_add_index,x)}
                  Value['rules'] = Value['rules'].uniq
               end
            end
         end
      else
         if File::exist?('/etc/openclash/custom/openclash_custom_rules.list') then
            Value_1 = YAML.load_file('/etc/openclash/custom/openclash_custom_rules.list')
            if Value_1 != false then
               if Value_1.class.to_s == 'Hash' then
                 if not Value_1['rules'].to_a.empty? and Value_1['rules'].class.to_s == 'Array' then
                    Value['rules'] = Value_1['rules']
                    Value['rules'] = Value['rules'].uniq
                 end
               elsif Value_1.class.to_s == 'Array'
                  Value['rules'] = Value_1
                  Value['rules'] = Value['rules'].uniq
               end
            end
         end
         if File::exist?('/etc/openclash/custom/openclash_custom_rules_2.list') then
            Value_2 = YAML.load_file('/etc/openclash/custom/openclash_custom_rules_2.list')
            if Value_2 != false then
               if Value['rules'].to_a.empty? then
                  if Value_2.class.to_s == 'Hash' then
                    if not Value_2['rules'].to_a.empty? and Value_2['rules'].class.to_s == 'Array' then
                       Value['rules'] = Value_2['rules']
                       Value['rules'] = Value['rules'].uniq
                    end
                  elsif Value_2.class.to_s == 'Array' 
                     Value['rules'] = Value_2
                     Value['rules'] = Value['rules'].uniq
                  end
               else
                  ruby_add_index = Value['rules'].index(Value['rules'].grep(/(GEOIP|MATCH|FINAL)/).first)
                  ruby_add_index ||= -1
                  if Value_2.class.to_s == 'Hash' then
                    if not Value_2['rules'].to_a.empty? and Value_2['rules'].class.to_s == 'Array' then
                       Value_3 = Value_2['rules'].to_a.reverse!
                    end
                  elsif Value_2.class.to_s == 'Array'
                     Value_3 = Value_2.reverse!
                  end
                  if defined? Value_3 then
                     if ruby_add_index == -1 then
                        Value_3 = Value_3.reverse!
                     end
                     Value_3.each{|x| Value['rules'].insert(ruby_add_index,x)}
                     Value['rules'] = Value['rules'].uniq
                  end
               end
            end
         end
      end
   end;
   rescue Exception => e
   puts '${LOGTIME} Error: Set Custom Rules Error,【' + e.message + '】'
   end
   
   begin
      if Value.has_key?('rules') and not Value['rules'].to_a.empty? then
         if Value['rules'].to_a.grep(/(?=.*198.18.0)(?=.*REJECT)/).empty? then
            Value['rules']=Value['rules'].to_a.insert(0,'IP-CIDR,198.18.0.1/16,REJECT,no-resolve')
         end
      else
         Value['rules']=%w(IP-CIDR,198.18.0.1/16,REJECT,no-resolve)
      end;
   rescue Exception => e
      puts '${LOGTIME} Error: Set 198.18.0.1/16 REJECT Rule Error,【' + e.message + '】'
   end
      
   begin
   if $4 == 1 then
      Value['rules']=Value['rules'].to_a.insert(1,
      'DOMAIN-SUFFIX,awesome-hd.me,DIRECT',
      'DOMAIN-SUFFIX,broadcasthe.net,DIRECT',
      'DOMAIN-SUFFIX,chdbits.co,DIRECT',
      'DOMAIN-SUFFIX,classix-unlimited.co.uk,DIRECT',
      'DOMAIN-SUFFIX,empornium.me,DIRECT',
      'DOMAIN-SUFFIX,gazellegames.net,DIRECT',
      'DOMAIN-SUFFIX,hdchina.org,DIRECT',
      'DOMAIN-SUFFIX,hdsky.me,DIRECT',
      'DOMAIN-SUFFIX,icetorrent.org,DIRECT',
      'DOMAIN-SUFFIX,jpopsuki.eu,DIRECT',
      'DOMAIN-SUFFIX,keepfrds.com,DIRECT',
      'DOMAIN-SUFFIX,madsrevolution.net,DIRECT',
      'DOMAIN-SUFFIX,m-team.cc,DIRECT',
      'DOMAIN-SUFFIX,nanyangpt.com,DIRECT',
      'DOMAIN-SUFFIX,ncore.cc,DIRECT',
      'DOMAIN-SUFFIX,open.cd,DIRECT',
      'DOMAIN-SUFFIX,ourbits.club,DIRECT',
      'DOMAIN-SUFFIX,passthepopcorn.me,DIRECT',
      'DOMAIN-SUFFIX,privatehd.to,DIRECT',
      'DOMAIN-SUFFIX,redacted.ch,DIRECT',
      'DOMAIN-SUFFIX,springsunday.net,DIRECT',
      'DOMAIN-SUFFIX,tjupt.org,DIRECT',
      'DOMAIN-SUFFIX,totheglory.im,DIRECT',
      'DOMAIN-KEYWORD,announce,DIRECT',
      'DOMAIN-KEYWORD,torrent,DIRECT',
      'DOMAIN-KEYWORD,tracker,DIRECT'
      )
      match_group=Value['rules'].grep(/(MATCH|FINAL)/)[0]
      if not match_group.nil? then
         common_port_group=match_group.split(',')[2] or common_port_group=match_group.split(',')[1]
         if not common_port_group.nil? then
            ruby_add_index = Value['rules'].index(Value['rules'].grep(/(MATCH|FINAL)/).first)
            ruby_add_index ||= -1
            Value['rules']=Value['rules'].to_a.insert(ruby_add_index,
            'DST-PORT,80,' + common_port_group,
            'DST-PORT,443,' + common_port_group,
            'DST-PORT,22,' + common_port_group
            )
         end
      end
      Value['rules'].to_a.collect!{|x|x.to_s.gsub(/(^MATCH.*|^FINAL.*)/, 'MATCH,DIRECT')}
   end;
   rescue Exception => e
      puts '${LOGTIME} Error: Set BT/P2P DIRECT Rules Error,【' + e.message + '】'
   ensure
   File.open('$3','w') {|f| YAML.dump(Value, f)}
   end" 2>/dev/null >> $LOG_FILE
}

yml_other_rules_get()
{
   local section="$1"
   local enabled config
   config_get_bool "enabled" "$section" "enabled" "1"
   config_get "config" "$section" "config" ""
   
   if [ "$enabled" = "0" ] || [ "$config" != "$2" ]; then
      return
   fi
   
   if [ -n "$rule_name" ]; then
      LOG_OUT "Warrning: Multiple Other-Rules-Configurations Enabled, Ignore..."
      return
   fi
   
   config_get "rule_name" "$section" "rule_name" ""
   config_get "GlobalTV" "$section" "GlobalTV" ""
   config_get "AsianTV" "$section" "AsianTV" ""
   config_get "Proxy" "$section" "Proxy" ""
   config_get "Youtube" "$section" "Youtube" ""
   config_get "Bilibili" "$section" "Bilibili" ""
   config_get "Bahamut" "$section" "Bahamut" ""
   config_get "HBOMax" "$section" "HBOMax" "$GlobalTV"
   config_get "HBOGo" "$section" "HBOGo" "$GlobalTV"
   config_get "Pornhub" "$section" "Pornhub" ""
   config_get "Apple" "$section" "Apple" ""
   config_get "Scholar" "$section" "Scholar" ""
   config_get "Netflix" "$section" "Netflix" ""
   config_get "Disney" "$section" "Disney" ""
   config_get "Spotify" "$section" "Spotify" ""
   config_get "Steam" "$section" "Steam" ""
   config_get "AdBlock" "$section" "AdBlock" ""
   config_get "Netease_Music" "$section" "Netease_Music" ""
   config_get "Speedtest" "$section" "Speedtest" ""
   config_get "Telegram" "$section" "Telegram" ""
   config_get "Microsoft" "$section" "Microsoft" ""
   config_get "PayPal" "$section" "PayPal" ""
   config_get "Domestic" "$section" "Domestic" ""
   config_get "Others" "$section" "Others" ""
   config_get "GoogleFCM" "$section" "GoogleFCM" "DIRECT"
}

if [ "$1" != "0" ]; then
   /usr/share/openclash/yml_groups_name_get.sh
   if [ $? -ne 0 ]; then
      LOG_OUT "Error: Unable To Parse Config File, Please Check And Try Again!"
      exit 0
   fi
   config_load "openclash"
   config_foreach yml_other_rules_get "other_rules" "$5"
   if [ -z "$rule_name" ]; then
      yml_other_set "$1" "$2" "$3" "$4"
      exit 0
   #判断策略组是否存在
   elif [ "$rule_name" = "ConnersHua_return" ]; then
	    if [ -z "$(grep -F "$Proxy" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep -F "$Others" /tmp/Proxy_Group)" ];then
         LOG_OUT "Warning: Because of The Different Porxy-Group's Name, Stop Setting The Other Rules!"
         yml_other_set "$1" "$2" "$3" "$4"
         exit 0
	    fi
   elif [ "$rule_name" = "ConnersHua" ]; then
       if [ -z "$(grep "$GlobalTV" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep -F "$AsianTV" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep -F "$Proxy" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep -F "$Others" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep -F "$Domestic" /tmp/Proxy_Group)" ]; then
         LOG_OUT "Warning: Because of The Different Porxy-Group's Name, Stop Setting The Other Rules!"
         yml_other_set "$1" "$2" "$3" "$4"
         exit 0
       fi
   elif [ "$rule_name" = "lhie1" ]; then
       if [ -z "$(grep -F "$GlobalTV" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep -F "$AsianTV" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep -F "$Proxy" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep -F "$Youtube" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep -F "$Bilibili" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep -F "$Bahamut" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep -F "$HBOMax" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep -F "$HBOGo" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep -F "$Pornhub" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep -F "$Apple" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep -F "$Scholar" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep -F "$Netflix" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep -F "$Disney" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep -F "$Spotify" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep -F "$Steam" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep -F "$AdBlock" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep -F "$Speedtest" /tmp/Proxy_Group)" ]\
   || [ -z "$(grep -F "$Telegram" /tmp/Proxy_Group)" ]\
   || [ -z "$(grep -F "$Microsoft" /tmp/Proxy_Group)" ]\
   || [ -z "$(grep -F "$PayPal" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep -F "$Others" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep -F "$GoogleFCM" /tmp/Proxy_Group)" ]\
	 || [ -z "$(grep -F "$Domestic" /tmp/Proxy_Group)" ]; then
         LOG_OUT "Warning: Because of The Different Porxy-Group's Name, Stop Setting The Other Rules!"
         yml_other_set "$1" "$2" "$3" "$4"
         exit 0
       fi
   fi
   if [ -z "$Proxy" ]; then
      LOG_OUT "Error: Missing Porxy-Group's Name, Stop Setting The Other Rules!"
      yml_other_set "$1" "$2" "$3" "$4"
      exit 0
   else
       #删除原有的部分，防止冲突
       if [ -n "$(ruby_read "$3" "['script']")" ]; then
          ruby_edit "$3" ".delete('script')"
       fi
       if [ -n "$(ruby_read "$3" "['rules']")" ]; then
          ruby_edit "$3" ".delete('rules')"
       fi
       if [ "$rule_name" = "lhie1" ]; then
       	    ruby -ryaml -E UTF-8 -e "
       	    begin
       	    Value = YAML.load_file('$3');
       	    Value_1 = YAML.load_file('/usr/share/openclash/res/lhie1.yaml');
       	    if Value_1.has_key?('rule-providers') and not Value_1['rule-providers'].to_a.empty? then
       	       if Value.has_key?('rule-providers') and not Value['rule-providers'].to_a.empty? then
                  Value['rule-providers'].merge!(Value_1['rule-providers'])
       	       else
                  Value['rule-providers']=Value_1['rule-providers']
       	       end
       	    end;
       	    Value['script']=Value_1['script'];
       	    Value['rules']=Value_1['rules'];
       	    Value['rules'].to_a.collect!{|x|
       	    x.to_s.gsub(/,Bilibili,Asian TV$/, ',Bilibili,$Bilibili#d')
       	    .gsub(/,Bahamut,Global TV$/, ',Bahamut,$Bahamut#d')
       	    .gsub(/,HBO Max,Global TV$/, ',HBO Max,$HBOMax#d')
       	    .gsub(/,HBO Go,Global TV$/, ',HBO Go,$HBOGo#d')
       	    .gsub(/,Pornhub,Global TV$/, ',Pornhub,$Pornhub#d')
       	    .gsub(/,Global TV$/, ',$GlobalTV#d')
       	    .gsub(/,Asian TV$/, ',$AsianTV#d')
       	    .gsub(/,Proxy$/, ',$Proxy#d')
       	    .gsub(/,YouTube$/, ',$Youtube#d')
       	    .gsub(/,Apple$/, ',$Apple#d')
       	    .gsub(/,Scholar$/, ',$Scholar#d')
       	    .gsub(/,Netflix$/, ',$Netflix#d')
       	    .gsub(/,Disney$/, ',$Disney#d')
       	    .gsub(/,Spotify$/, ',$Spotify#d')
       	    .gsub(/,Steam$/, ',$Steam#d')
       	    .gsub(/,AdBlock$/, ',$AdBlock#d')
       	    .gsub(/,Speedtest$/, ',$Speedtest#d')
       	    .gsub(/,Telegram$/, ',$Telegram#d')
       	    .gsub(/,Microsoft$/, ',$Microsoft#d')
       	    .to_s.gsub(/,PayPal$/, ',$PayPal#d')
       	    .gsub(/,Domestic$/, ',$Domestic#d')
       	    .gsub(/,Others$/, ',$Others#d')
       	    .gsub(/,Google FCM$/, ',$GoogleFCM#d')
       	    .gsub(/#d/, '')
       	    };
       	    Value['script']['code'].to_s.gsub!(/\"Bilibili\": \"Asian TV\"/,'\"Bilibili\": \"$Bilibili#d\"')
       	    .gsub!(/\"Bahamut\": \"Global TV\"/,'\"Bahamut\": \"$Bahamut#d\"')
       	    .gsub!(/\"HBO Max\": \"Global TV\"/,'\"HBO Max\": \"$HBOMax#d\"')
       	    .gsub!(/\"HBO Go\": \"Global TV\"/,'\"HBO Go\": \"$HBOGo#d\"')
       	    .gsub!(/\"Pornhub\": \"Global TV\"/,'\"Pornhub\": \"$Pornhub#d\"')
       	    .gsub!(/: \"Global TV\"/,': \"$GlobalTV#d\"')
       	    .gsub!(/: \"Asian TV\"/,': \"$AsianTV#d\"')
       	    .gsub!(/: \"Proxy\"/,': \"$Proxy#d\"')
       	    .gsub!(/: \"YouTube\"/,': \"$Youtube#d\"')
       	    .gsub!(/: \"Apple\"/,': \"$Apple#d\"')
       	    .gsub!(/: \"Scholar\"/,': \"$Scholar#d\"')
       	    .gsub!(/: \"Netflix\"/,': \"$Netflix#d\"')
       	    .gsub!(/: \"Disney\"/,': \"$Disney#d\"')
       	    .gsub!(/: \"Spotify\"/,': \"$Spotify#d\"')
       	    .gsub!(/: \"Steam\"/,': \"$Steam#d\"')
       	    .gsub!(/: \"AdBlock\"/,': \"$AdBlock#d\"')
       	    .gsub!(/: \"Speedtest\"/,': \"$Speedtest#d\"')
       	    .gsub!(/: \"Telegram\"/,': \"$Telegram#d\"')
       	    .gsub!(/: \"Microsoft\"/,': \"$Microsoft#d\"')
       	    .gsub!(/: \"PayPal\"/,': \"$PayPal#d\"')
       	    .gsub!(/: \"Domestic\"/,': \"$Domestic#d\"')
       	    .gsub!(/: \"Google FCM\"/,': \"$GoogleFCM#d\"')
       	    .gsub!(/return \"Domestic\"$/, 'return \"$Domestic#d\"')
       	    .gsub!(/return \"Others\"$/, 'return \"$Others#d\"')
       	    .gsub!(/#d/, '');
       	    File.open('$3','w') {|f| YAML.dump(Value, f)};
       	    rescue Exception => e
       	    puts '${LOGTIME} Error: Set lhie1 Rules Error,【' + e.message + '】'
       	    end" 2>/dev/null >> $LOG_FILE
       elif [ "$rule_name" = "ConnersHua" ]; then
            ruby -ryaml -E UTF-8 -e "
            begin
       	    Value = YAML.load_file('$3');
            Value_1 = YAML.load_file('/usr/share/openclash/res/ConnersHua.yaml');
       	    if Value_1.has_key?('rule-providers') and not Value_1['rule-providers'].to_a.empty? then
       	       if Value.has_key?('rule-providers') and not Value['rule-providers'].to_a.empty? then
                  Value['rule-providers'].merge!(Value_1['rule-providers'])
       	       else
                  Value['rule-providers']=Value_1['rule-providers']
       	       end
       	    end;
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
       	    File.open('$3','w') {|f| YAML.dump(Value, f)};
       	    rescue Exception => e
       	    puts '${LOGTIME} Error: Set ConnersHua Rules Error,【' + e.message + '】'
       	    end" 2>/dev/null >> $LOG_FILE
       else
            ruby -ryaml -E UTF-8 -e "
            begin
       	    Value = YAML.load_file('$3');
       	    Value_1 = YAML.load_file('/usr/share/openclash/res/ConnersHua_return.yaml');
       	    Value['rules']=Value_1['rules'];
       	    Value['rules'].to_a.collect!{|x|
       	    x.to_s.gsub(/,PROXY$/, ',$Proxy#d')
       	    .gsub(/MATCH,DIRECT$/, 'MATCH,$Others#d')
       	    .gsub(/#d/, '')
       	    };
       	    File.open('$3','w') {|f| YAML.dump(Value, f)};
       	    rescue Exception => e
       	    puts '${LOGTIME} Error: Set ConnersHua Return Rules Error,【' + e.message + '】'
       	    end" 2>/dev/null >> $LOG_FILE
       fi
   fi
fi

yml_other_set "$1" "$2" "$3" "$4"
