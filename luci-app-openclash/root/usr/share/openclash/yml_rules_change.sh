#!/bin/sh
. /lib/functions.sh
. /usr/share/openclash/ruby.sh
. /usr/share/openclash/log.sh
. /usr/share/openclash/uci.sh

LOG_FILE="/tmp/openclash.log"
RULE_PROVIDER_FILE="/tmp/yaml_rule_provider.yaml"
GAME_RULE_FILE="/tmp/yaml_game_rule.yaml"
github_address_mod=$(uci_get_config "github_address_mod" || echo 0)
urltest_address_mod=$(uci_get_config "urltest_address_mod" || echo 0)
tolerance=$(uci_get_config "tolerance" || echo 0)
urltest_interval_mod=$(uci_get_config "urltest_interval_mod" || echo 0)
CONFIG_NAME="$5"
rule_name=""
SKIP_CUSTOM_OTHER_RULES=0

cache_file_content() {
    local file="$1"
    local cache_var="$2"
    if [ -f "$file" ] && [ -z "$(eval echo \$$cache_var)" ]; then
        eval "$cache_var=\"\$(cat '$file')\""
    fi
}

check_duplicate_url() {
    [ -n "$1" ] && [ -n "${RULE_PROVIDER_CACHE}" ] && echo "${RULE_PROVIDER_CACHE}" | grep -q "$1"
}

check_duplicate_path() {
    [ -n "$1" ] && [ -n "${RULE_PROVIDER_CACHE}" ] && echo "${RULE_PROVIDER_CACHE}" | grep -q "$1"
}

# Custom rule-provider
yml_set_custom_rule_provider()
{
   local section="$1"
   local enabled name config type behavior path url interval group position other_parameters format
   config_get_bool "enabled" "$section" "enabled" "1"
   
   [ "$enabled" = "0" ] && return
   
   config_get "name" "$section" "name" ""
   config_get "config" "$section" "config" ""
   config_get "type" "$section" "type" ""
   config_get "behavior" "$section" "behavior" ""
   config_get "path" "$section" "path" ""
   config_get "url" "$section" "url" ""
   config_get "interval" "$section" "interval" ""
   config_get "group" "$section" "group" ""
   config_get "position" "$section" "position" ""
   config_get "format" "$section" "format" ""
   config_get "other_parameters" "$section" "other_parameters" ""

   cache_file_content "$RULE_PROVIDER_FILE" "RULE_PROVIDER_CACHE"

   if check_duplicate_url "$url" || [ -n "$config" ] && [ "$config" != "$CONFIG_NAME" ] && [ "$config" != "all" ]; then
      return
   fi
   
   if [ -z "$name" ] || [ -z "$type" ] || [ -z "$behavior" ] || { [ "$type" = "http" ] && [ -z "$url" ]; }; then
      return
   fi

   [ -z "$format" ] && format="yaml"

   if [ "$type" = "http" ] && [ -z "$(echo "$path" | grep "./rule_provider/")" ]; then
      case "$format" in
         "text") path="./rule_provider/$name" ;;
         "mrs") path="./rule_provider/$name.mrs" ;;
         *) path="./rule_provider/$name.yaml" ;;
      esac
   elif [ -z "$path" ] && [ "$type" != "inline" ]; then
      return
   fi

   check_duplicate_path "$path" && return

   [ -z "$interval" ] && [ "$type" = "http" ] && interval=86400

   {
      echo "  $name:"
      echo "    type: $type"
      echo "    behavior: $behavior"
      [ -n "$path" ] && echo "    path: $path"
      [ -n "$format" ] && echo "    format: $format"
      if [ "$type" = "http" ]; then
         echo "    url: $url"
         echo "    interval: $interval"
      fi
      [ -n "$other_parameters" ] && echo -e "$other_parameters"
   } >> "$RULE_PROVIDER_FILE"

   yml_rule_set_add "$name" "$group" "$position"
}

yml_rule_set_add()
{
   [ -z "$3" ] && return

   local target_file rule_content
   if [ "$3" = "1" ]; then
      target_file="/tmp/yaml_rule_set_bottom_custom.yaml"
   else
      target_file="/tmp/yaml_rule_set_top_custom.yaml"
   fi
   
   rule_content="- RULE-SET,${1},${2}"
   
   if [ ! -f "$target_file" ] || [ -z "$(grep "^ \{0,\}rules:$" "$target_file" 2>/dev/null)" ]; then
      echo "rules:" > "$target_file"
   fi
   echo "$rule_content" >> "$target_file"
}

yml_gen_rule_provider_file()
{
   [ -z "$1" ] && return
   
   if [ -z "$RULE_PROVIDERS_LIST_CACHE" ]; then
      RULE_PROVIDERS_LIST_CACHE=$(cat /usr/share/openclash/res/rule_providers.list 2>/dev/null)
   fi
   
   local rule_line=$(echo "$RULE_PROVIDERS_LIST_CACHE" | grep "^$1,")
   [ -z "$rule_line" ] && return
   
   RULE_PROVIDER_FILE_NAME=$(echo "$rule_line" | awk -F ',' '{print ($6 != "") ? $6 : $5}')
   RULE_PROVIDER_FILE_BEHAVIOR=$(echo "$rule_line" | awk -F ',' '{print $3}')
   RULE_PROVIDER_FILE_PATH="/etc/openclash/rule_provider/$RULE_PROVIDER_FILE_NAME"
   RULE_PROVIDER_FILE_URL_PATH=$(echo "$rule_line" | awk -F ',' '{print $4$5}')
   
   if [ "$github_address_mod" -eq 0 ]; then
      RULE_PROVIDER_FILE_URL="https://raw.githubusercontent.com/${RULE_PROVIDER_FILE_URL_PATH}"
   else
      case "$github_address_mod" in
         "https://cdn.jsdelivr.net/"|"https://fastly.jsdelivr.net/"|"https://testingcf.jsdelivr.net/")
            local repo_part=$(echo "$RULE_PROVIDER_FILE_URL_PATH" | awk -F '/master' '{print $1}')
            local path_part=$(echo "$RULE_PROVIDER_FILE_URL_PATH" | awk -F 'master' '{print $2}')
            RULE_PROVIDER_FILE_URL="${github_address_mod}gh/${repo_part}@master${path_part}"
            ;;
         *)
            RULE_PROVIDER_FILE_URL="${github_address_mod}https://raw.githubusercontent.com/${RULE_PROVIDER_FILE_URL_PATH}"
            ;;
      esac
   fi
   
   cache_file_content "$RULE_PROVIDER_FILE" "RULE_PROVIDER_CACHE"
   check_duplicate_url "$RULE_PROVIDER_FILE_URL" && return

   [ -z "$RULE_PROVIDER_FILE_NAME" ] || [ -z "$RULE_PROVIDER_FILE_BEHAVIOR" ] || [ -z "$RULE_PROVIDER_FILE_URL" ] && return

   {
      echo "  $1:"
      echo "    type: http"
      echo "    behavior: $RULE_PROVIDER_FILE_BEHAVIOR"
      echo "    path: $RULE_PROVIDER_FILE_PATH"
      echo "    url: $RULE_PROVIDER_FILE_URL"
      echo "    interval: ${3:-86400}"
   } >> "$RULE_PROVIDER_FILE"
   
   yml_rule_set_add "$1" "$2" "$4"
}

yml_get_rule_provider()
{
   local section="$1"
   local enabled group config interval position
   config_get_bool "enabled" "$section" "enabled" "1"
   
   [ "$enabled" = "0" ] && return
   
   config_get "group" "$section" "group" ""
   config_get "config" "$section" "config" ""
   config_get "interval" "$section" "interval" ""
   config_get "position" "$section" "position" ""

   if [ -n "$config" ] && [ "$config" != "$CONFIG_NAME" ] && [ "$config" != "all" ] || [ -z "$group" ]; then
      return
   fi
   
   config_list_foreach "$section" "rule_name" yml_gen_rule_provider_file "$group" "$interval" "$position"
}

get_rule_file()
{
   [ -z "$1" ] && return
   
   if [ -z "$GAME_RULES_LIST_CACHE" ]; then
      GAME_RULES_LIST_CACHE=$(cat /usr/share/openclash/res/game_rules.list 2>/dev/null)
   fi
   
   local game_line=$(echo "$GAME_RULES_LIST_CACHE" | grep "^$1,")
   [ -z "$game_line" ] && return
   
   GAME_RULE_FILE_NAME=$(echo "$game_line" | awk -F ',' '{print ($3 != "") ? $3 : $2}')
   GAME_RULE_PATH="./game_rules/$GAME_RULE_FILE_NAME"

   yml_rule_set_add "$1" "$2" "1"

   {
      echo "  $1:"
      echo "    type: file"
      echo "    behavior: ipcidr"
      echo "    path: '${GAME_RULE_PATH}'"
   } >> "$RULE_PROVIDER_FILE"
}

yml_game_rule_get()
{
   local section="$1"
   local enabled group config
   config_get_bool "enabled" "$section" "enabled" "1"
   
   [ "$enabled" = "0" ] && return
   
   config_get "group" "$section" "group" ""
   config_get "config" "$section" "config" ""

   if [ -n "$config" ] && [ "$config" != "$CONFIG_NAME" ] && [ "$config" != "all" ] || [ -z "$group" ]; then
      return
   fi
   
   config_list_foreach "$section" "rule_name" get_rule_file "$group"
}

yml_rule_group_get()
{
   local section="$1"
   local enabled group config
   config_get_bool "enabled" "$section" "enabled" "1"
   
   [ "$enabled" = "0" ] && return
   
   config_get "group" "$section" "group" ""
   config_get "config" "$section" "config" ""

   if [ -n "$config" ] && [ "$config" != "$CONFIG_NAME" ] && [ "$config" != "all" ] || \
      [ -z "$group" ] || [ "$group" = "DIRECT" ] || [ "$group" = "REJECT" ] || \
      [ "$group" = "REJECT-DROP" ] || [ "$group" = "PASS" ] || [ "$group" = "COMPATIBLE" ] || [ "$group" = "GLOBAL" ]; then
      return
   fi

   group_check=$(ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e "
   begin
      Value = YAML.load_file('$2');
      Value['proxy-groups'].each{
         |x|
         if x['name'] == '$group' then
            if (x.key?('use') and not x['use'].to_a.empty?) or (x.key?('proxies') and not x['proxies'].to_a.empty?) then
               puts 'return';
               break;
            end;
         end;
      };
   end;" 2>/dev/null)

   if [ "$group_check" != "return" ]; then
      /usr/share/openclash/yml_groups_set.sh >/dev/null 2>&1 "$group"
   fi
}

yml_other_set()
{
   config_load "openclash"
   config_foreach yml_get_rule_provider "rule_provider_config"
   config_foreach yml_set_custom_rule_provider "rule_providers"
   config_foreach yml_game_rule_get "game_config"
   config_foreach yml_rule_group_get "rule_provider_config" "$3"
   config_foreach yml_rule_group_get "rule_providers" "$3"
   config_foreach yml_rule_group_get "game_config" "$3"
   
   ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e "
   begin
      Value = YAML.load_file('$3');
   rescue Exception => e
      YAML.LOG('Error: Load File Failed,【' + e.message + '】');
   end;

   begin
      if '$rule_name' == 'lhie1' and $SKIP_CUSTOM_OTHER_RULES == 0 then
         Value_1 = YAML.load_file('/usr/share/openclash/res/lhie1.yaml');
         if Value.has_key?('script') then
            Value.delete('script')
         end;
         if Value.has_key?('rules') then
            Value.delete('rules')
         end;
         if Value_1.has_key?('rule-providers') and not Value_1['rule-providers'].to_a.empty? then
            if Value.has_key?('rule-providers') and not Value['rule-providers'].to_a.empty? then
               Value['rule-providers'].merge!(Value_1['rule-providers'])
            else
               Value['rule-providers']=Value_1['rule-providers']
            end
         end;
         Value['rules']=Value_1['rules'];

         rule_replacements = {
            ',[\s]?Bilibili,[\s]?CN Mainland TV$' => ',Bilibili,$Bilibili#delete_',
            ',[\s]?Bahamut,[\s]?Asian TV$' => ',Bahamut,$Bahamut#delete_',
            ',[\s]?Max,[\s]?Max$' => ',Max,$HBOMax#delete_',
            ',[\s]?Discovery Plus,[\s]?Global TV$' => ',Discovery Plus,$Discovery#delete_',
            ',[\s]?DAZN,[\s]?Global TV$' => ',DAZN,$DAZN#delete_',
            ',[\s]?Pornhub,[\s]?Global TV$' => ',Pornhub,$Pornhub#delete_',
            ',[\s]?Global TV$' => ',$GlobalTV#delete_',
            ',[\s]?Asian TV$' => ',$AsianTV#delete_',
            ',[\s]?CN Mainland TV$' => ',$MainlandTV#delete_',
            ',[\s]?Proxy$' => ',$Proxy#delete_',
            ',[\s]?YouTube$' => ',$Youtube#delete_',
            ',[\s]?Apple$' => ',$Apple#delete_',
            ',[\s]?Apple TV$' => ',$AppleTV#delete_',
            ',[\s]?Scholar$' => ',$Scholar#delete_',
            ',[\s]?Netflix$' => ',$Netflix#delete_',
            ',[\s]?Disney Plus$' => ',$Disney#delete_',
            ',[\s]?Spotify$' => ',$Spotify#delete_',
            ',[\s]?AI Suite$' => ',$AI_Suite#delete_',
            ',[\s]?Steam$' => ',$Steam#delete_',
            ',[\s]?TikTok$' => ',$TikTok#delete_',
            ',[\s]?miHoYo$' => ',$miHoYo#delete_',
            ',[\s]?AdBlock$' => ',$AdBlock#delete_',
            ',[\s]?HTTPDNS$' => ',$HTTPDNS#delete_',
            ',[\s]?Speedtest$' => ',$Speedtest#delete_',
            ',[\s]?Telegram$' => ',$Telegram#delete_',
            ',[\s]?Crypto$' => ',$Crypto#delete_',
            ',[\s]?Discord$' => ',$Discord#delete_',
            ',[\s]?Microsoft$' => ',$Microsoft#delete_',
            ',[\s]?PayPal$' => ',$PayPal#delete_',
            ',[\s]?Domestic$' => ',$Domestic#delete_',
            ',[\s]?Others$' => ',$Others#delete_',
            ',[\s]?Google FCM$' => ',$GoogleFCM#delete_'
         };
         
         Value['rules'].to_a.collect!{|x|
            result = x.to_s;
            rule_replacements.each{|pattern, replacement|
               result = result.gsub(/#{pattern}/, replacement);
            };
            result.gsub(/#delete_/, '');
         };
      end;
   rescue Exception => e
      YAML.LOG('Error: Set lhie1 Rules Failed,【' + e.message + '】');
   end;

   thread_pool = [];
   
   thread_pool << Thread.new{
      #BT/P2P DIRECT Rules
      begin
         if $4 == 1 then
            if system('strings /etc/openclash/GeoSite.dat /etc/openclash/GeoSite.dat |grep -i category-public-tracker >/dev/null 2>&1') then
               bt_rules = ['GEOSITE,category-public-tracker,DIRECT'];
            else
               bt_rules = [
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
                  'DOMAIN-SUFFIX,smtp,DIRECT',
                  'DOMAIN-KEYWORD,announce,DIRECT',
                  'DOMAIN-KEYWORD,torrent,DIRECT',
                  'DOMAIN-KEYWORD,tracker,DIRECT'
               ];
            end;

            Value['rules'] = bt_rules + Value['rules'].to_a;
            
            match_group=Value['rules'].grep(/(MATCH|FINAL)/)[0];
            if not match_group.nil? then
               common_port_group = (match_group.split(',')[-1] =~ /^no-resolve$|^src$/) ? match_group.split(',')[-2] : match_group.split(',')[-1];
               if not common_port_group.nil? then
                  ruby_add_index = Value['rules'].index(Value['rules'].grep(/(MATCH|FINAL)/).first);
                  ruby_add_index ||= -1;

                  process_rules = [
                     'PROCESS-NAME,aria2c,DIRECT',
                     'PROCESS-NAME,BitComet,DIRECT',
                     'PROCESS-NAME,fdm,DIRECT',
                     'PROCESS-NAME,NetTransport,DIRECT',
                     'PROCESS-NAME,qbittorrent,DIRECT',
                     'PROCESS-NAME,Thunder,DIRECT',
                     'PROCESS-NAME,transmission-daemon,DIRECT',
                     'PROCESS-NAME,transmission-qt,DIRECT',
                     'PROCESS-NAME,uTorrent,DIRECT',
                     'PROCESS-NAME,WebTorrent,DIRECT',
                     'PROCESS-NAME,Folx,DIRECT',
                     'PROCESS-NAME,Transmission,DIRECT',
                     'PROCESS-NAME,WebTorrent Helper,DIRECT',
                     'PROCESS-NAME,v2ray,DIRECT',
                     'PROCESS-NAME,ss-local,DIRECT',
                     'PROCESS-NAME,ssr-local,DIRECT',
                     'PROCESS-NAME,ss-redir,DIRECT',
                     'PROCESS-NAME,ssr-redir,DIRECT',
                     'PROCESS-NAME,ss-server,DIRECT',
                     'PROCESS-NAME,trojan-go,DIRECT',
                     'PROCESS-NAME,xray,DIRECT',
                     'PROCESS-NAME,hysteria,DIRECT',
                     'PROCESS-NAME,singbox,DIRECT',
                     'PROCESS-NAME,UUBooster,DIRECT',
                     'PROCESS-NAME,uugamebooster,DIRECT',
                     'DST-PORT,80,' + common_port_group,
                     'DST-PORT,443,' + common_port_group
                  ];
                  
                  process_rules.reverse.each{|rule| Value['rules'].insert(ruby_add_index, rule)};
               end;
            end;
            
            # GEOIP replace
            geoip_pattern = /GEOIP,([A-Z]{2}),([^,]+)(,.*)?/;
            match_pattern = /(^MATCH.*|^FINAL.*)/;

            Value['rules'].to_a.collect!{|x|
               x.to_s.gsub(geoip_pattern, 'GEOIP,\1,DIRECT\3').gsub(match_pattern, 'MATCH,DIRECT')
            };
         end;
      rescue Exception => e
         YAML.LOG('Error: Set BT/P2P DIRECT Rules Failed,【' + e.message + '】');
      end;
   };

   thread_pool << Thread.new{
      #Custom Rule Provider
      begin
         if File::exist?('$RULE_PROVIDER_FILE') then
            Value_1 = YAML.load_file('$RULE_PROVIDER_FILE');
            if Value.has_key?('rule-providers') and not Value['rule-providers'].to_a.empty? then
               Value['rule-providers'].merge!(Value_1);
            else
               Value['rule-providers']=Value_1;
            end;
         end;
      rescue Exception => e
         YAML.LOG('Error: Custom Rule Provider Merge Failed,【' + e.message + '】');
      end;

      #Game Proxy
      begin
         yaml_files = {
            '/tmp/yaml_groups.yaml' => 'proxy-groups',
            '/tmp/yaml_servers.yaml' => 'proxies', 
            '/tmp/yaml_provider.yaml' => 'proxy-providers'
         };
         
         yaml_files.each{|file, key|
            if File::exist?(file) then
               file_data = YAML.load_file(file);
               case key
               when 'proxy-groups'
                  if Value.has_key?(key) and not Value[key].to_a.empty? then
                     Value[key] = Value[key] + file_data;
                     Value[key].uniq;
                  else
                     Value[key] = file_data;
                  end;
               when 'proxies'
                  if Value.has_key?(key) and not Value[key].to_a.empty? then
                     Value[key] = Value[key] + file_data[key];
                     Value[key].uniq;
                  else
                     Value[key] = file_data[key];
                  end;
               when 'proxy-providers'
                  if Value.has_key?(key) and not Value[key].to_a.empty? then
                     Value[key].merge!(file_data[key]);
                     Value[key].uniq;
                  else
                     Value[key] = file_data[key];
                  end;
               end;
            end;
         };
      rescue Exception => e
         YAML.LOG('Error: Game Proxy Merge Failed,【' + e.message + '】');
      end;
   };

   thread_pool.each(&:join);
   
   begin
      CUSTOM_RULE = File::exist?('/etc/openclash/custom/openclash_custom_rules.list') ? YAML.load_file('/etc/openclash/custom/openclash_custom_rules.list') : {};
      CUSTOM_RULE_2 = File::exist?('/etc/openclash/custom/openclash_custom_rules_2.list') ? YAML.load_file('/etc/openclash/custom/openclash_custom_rules_2.list') : {};
      
      CONFIG_GROUP = (['DIRECT', 'REJECT', 'GLOBAL', 'REJECT-DROP', 'PASS', 'COMPATIBLE'] +
      (Value['proxy-groups']&.map { |x| x['name'] } || []) +
      (Value['proxies']&.map { |x| x['name'] } || []) +
      (Value['sub-rules']&.keys || []) +
      (CUSTOM_RULE.is_a?(Hash) ? CUSTOM_RULE['sub-rules']&.keys || [] : []) +
      (CUSTOM_RULE_2.is_a?(Hash) ? CUSTOM_RULE_2['sub-rules']&.keys || [] : [])).uniq;
   rescue Exception => e
      CONFIG_GROUP = ['DIRECT', 'REJECT', 'GLOBAL', 'REJECT-DROP', 'PASS', 'COMPATIBLE'];
   end;
   
   rule_thread_pool = [];
   
   rule_thread_pool << Thread.new{
      #Custom Rule Set
      begin
         rule_files = [
            { file: '/tmp/yaml_rule_set_top_custom.yaml', position: 'top' },
            { file: '/tmp/yaml_rule_set_bottom_custom.yaml', position: 'bottom' }
         ];
         
         rule_files.each{|rule_file_info|
            if File::exist?(rule_file_info[:file]) then
               custom_rules = YAML.load_file(rule_file_info[:file])['rules'].uniq;
               
               valid_rules = custom_rules.select{|x|
                  RULE_GROUP = ((x.split(',')[-1] =~ /^no-resolve$|^src$/) ? x.split(',')[-2] : x.split(',')[-1]).strip;
                  if CONFIG_GROUP.include?(RULE_GROUP) then
                     true;
                  else
                     YAML.LOG('Warning: Skiped The Custom Rule Because Group & Proxy Not Found:【' + x + '】');
                     false;
                  end;
               };
               
               if Value.has_key?('rules') and not Value['rules'].to_a.empty? then
                  if rule_file_info[:position] == 'top' then
                     valid_rules.reverse.each{|x| Value['rules'].insert(0,x)};
                  else
                     if $4 != 1 then
                        ruby_add_index = Value['rules'].index(Value['rules'].grep(/(GEOIP|MATCH|FINAL)/).first);
                     else
                        if Value['rules'].grep(/GEOIP/)[0].nil? or Value['rules'].grep(/GEOIP/)[0].empty? then
                           ruby_add_index = Value['rules'].index(Value['rules'].grep(/DST-PORT,80/).last);
                           ruby_add_index ||= Value['rules'].index(Value['rules'].grep(/(MATCH|FINAL)/).first);
                        else
                           ruby_add_index = Value['rules'].index(Value['rules'].grep(/GEOIP/).first);
                        end;
                     end;
                     ruby_add_index ||= -1;
                     
                     if ruby_add_index != -1 then
                        valid_rules.reverse.each{|x| Value['rules'].insert(ruby_add_index,x)};
                     else
                        valid_rules.each{|x| Value['rules'].insert(ruby_add_index,x)};
                     end;
                  end;
               else
                  Value['rules'] = rule_file_info[:position] == 'top' ? valid_rules : (Value['rules'].to_a | valid_rules);
               end;
            end;
         };
      rescue Exception => e
         YAML.LOG('Error: Rule Set Add Failed,【' + e.message + '】');
      end;

      #Custom Rules
      begin
         if $2 == 1 then
            custom_files = [
               { file: '/etc/openclash/custom/openclash_custom_rules.list', position: 'top' },
               { file: '/etc/openclash/custom/openclash_custom_rules_2.list', position: 'bottom' }
            ];
            
            custom_files.each{|file_info|
               if File::exist?(file_info[:file]) then
                  custom_data = YAML.load_file(file_info[:file]);
                  next if custom_data == false;
                  
                  rules_array = case custom_data.class.to_s
                     when 'Hash'
                        custom_data['rules'].to_a if custom_data['rules'].class.to_s == 'Array'
                     when 'Array'
                        custom_data
                     else
                        []
                  end;
                  
                  next unless rules_array;
                  
                  ipv4_regex = /^(\d{1,3}\.){3}\d{1,3}$/;
                  ipv6_regex = /^(([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]+|::(ffff(:0{1,4})?:)?((25[0-5]|(2[0-4]|1?[0-9])?[0-9])\.){3}(25[0-5]|(2[0-4]|1?[0-9])?[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1?[0-9])?[0-9])\.){3}(25[0-5]|(2[0-4]|1?[0-9])?[0-9]))$/;
                  cidr_regex = /\/\d+$/;
                  rule_suffix_regex = /^no-resolve$|^src$/;
                  
                  transformed_rules = rules_array.map{|x|
                     parts = x.split(',');
                     if parts.length >= 2 then
                        ip_part = parts[1].strip;
                        if ip_part !~ cidr_regex then
                           # IPv4
                           if ip_part =~ ipv4_regex then
                              octets = ip_part.split('.');
                              valid_ipv4 = octets.all? { |octet| octet.to_i >= 0 && octet.to_i <= 255 };
                              if valid_ipv4 then
                                 parts[1] = ip_part + '/32';
                                 x = parts.join(',');
                              end;
                           # IPv6
                           elsif ip_part =~ ipv6_regex then
                              parts[1] = ip_part + '/128';
                              x = parts.join(',');
                           end;
                        end;
                     end;
                     x;
                  };
                  
                  valid_rules = transformed_rules.select{|x|
                     RULE_GROUP = ((x.split(',')[-1] =~ rule_suffix_regex) ? x.split(',')[-2] : x.split(',')[-1]).strip;
                     if CONFIG_GROUP.include?(RULE_GROUP) then
                        true;
                     else
                        YAML.LOG('Warning: Skiped The Custom Rule Because Group & Proxy Not Found:【' + x + '】');
                        false;
                     end;
                  };
                  
                  if Value.has_key?('rules') and not Value['rules'].to_a.empty? then
                     if file_info[:position] == 'top' then
                        valid_rules.reverse.each{|x| Value['rules'].insert(0,x)};
                     else
                        if Value['rules'].grep(/GEOIP/)[0].nil? or Value['rules'].grep(/GEOIP/)[0].empty? then
                           ruby_add_index = Value['rules'].index(Value['rules'].grep(/DST-PORT,80/).last);
                           ruby_add_index ||= Value['rules'].index(Value['rules'].grep(/(MATCH|FINAL)/).first);
                        else
                           ruby_add_index = Value['rules'].index(Value['rules'].grep(/GEOIP/).first);
                        end;
                        ruby_add_index ||= -1;
                        
                        insert_rules = ruby_add_index == -1 ? valid_rules : valid_rules.reverse;
                        insert_rules.each{|x| Value['rules'].insert(ruby_add_index,x)};
                     end;
                     Value['rules'] = Value['rules'].uniq;
                  else
                     Value['rules'] = valid_rules.uniq;
                  end;
               end;
            };
            
            # SUB-RULE
            ['sub-rules'].each{|key|
               custom_files.each{|file_info|
                  if File::exist?(file_info[:file]) then
                     custom_data = YAML.load_file(file_info[:file]);
                     if custom_data != false and custom_data.class.to_s == 'Hash' then
                        if not custom_data[key].to_a.empty? and custom_data[key].class.to_s == 'Hash' then
                           if Value.has_key?(key) and not Value[key].to_a.empty? then
                              Value[key] = Value[key].merge!(custom_data[key]);
                           else
                              Value[key] = custom_data[key];
                           end;
                        end;
                     end;
                  end;
               };
            };
         end;
      rescue Exception => e
         YAML.LOG('Error: Set Custom Rules Failed,【' + e.message + '】');
      end;

      #Router Self Proxy Rule
      begin
         if $6 == 0 and $8 != 2 and '$9' == 'fake-ip' then
            router_rule = 'SRC-IP-CIDR,$7/32,DIRECT';
            if Value.has_key?('rules') and not Value['rules'].to_a.empty? then
               if Value['rules'].to_a.grep(/(?=.*SRC-IP-CIDR,'$7')/).empty? and not '$7'.empty? then
                  Value['rules']=Value['rules'].to_a.insert(0, router_rule);
               end;
            else
               Value['rules']=[router_rule];
            end;
         elsif Value.has_key?('rules') and not Value['rules'].to_a.empty? then
            Value['rules'].delete('SRC-IP-CIDR,$7/32,DIRECT');
         end;
      rescue Exception => e
         YAML.LOG('Error: Set Router Self Proxy Rule Failed,【' + e.message + '】');
      end;
   };

   rule_thread_pool.each(&:join);
   
   provider_thread = Thread.new{
      threads = [];
      
      #provider path
      begin
         provider_configs = {'proxy-providers' => 'proxy_provider', 'rule-providers' => 'rule_provider'};
         provider_configs.each do |provider_type, path_prefix|
            if Value.key?(provider_type) then
               Value[provider_type].each{|name, config|
                  threads << Thread.new {
                     if config['path'] and not config['path'] =~ /.\/#{path_prefix}\/*/ and not config['path'] =~ /.\/game_rules\/*/ then
                        config['path'] = './'+path_prefix+'/'+File.basename(config['path']);
                     elsif not config['path'] and config['type'] == 'http' then
                        config['path'] = './'+path_prefix+'/'+name;
                     end;
                     
                     # CDN
                     if '$github_address_mod' != '0' and config['url'] then
                        if config['url'] =~ /^https:\/\/raw.githubusercontent.com/ then
                           if '$github_address_mod' == 'https://cdn.jsdelivr.net/' or 
                              '$github_address_mod' == 'https://fastly.jsdelivr.net/' or 
                              '$github_address_mod' == 'https://testingcf.jsdelivr.net/' then
                              url_parts = config['url'].split('/');
                              if url_parts.length >= 5 then
                                 config['url'] = '$github_address_mod' + 'gh/' + url_parts[3] + '/' + 
                                                url_parts[4] + '@' + config['url'].split(url_parts[2] + 
                                                '/' + url_parts[3] + '/' + url_parts[4] + '/')[1];
                              end;
                           else
                              config['url'] = '$github_address_mod' + config['url'];
                           end;
                        elsif config['url'] =~ /^https:\/\/(raw.|gist.)(githubusercontent.com|github.com)/ then
                           config['url'] = '$github_address_mod' + config['url'];
                        end;
                     end;
                  };
               };
            end;
         end;
      rescue Exception => e
         YAML.LOG('Error: Edit Provider Path Failed,【' + e.message + '】');
      end;

      # tolerance
      begin
         if '$tolerance' != '0' and Value.key?('proxy-groups') then
            Value['proxy-groups'].each{|group|
               threads << Thread.new {
                  if group['type'] == 'url-test' then
                     group['tolerance'] = ${tolerance};
                  end;
               };
            };
         end;
      rescue Exception => e
         YAML.LOG('Error: Edit URL-Test Group Tolerance Option Failed,【' + e.message + '】');
      end;

      # URL-Test interval
      begin
         if '$urltest_interval_mod' != '0' then
            if Value.key?('proxy-groups') then
               Value['proxy-groups'].each{|group|
                  threads << Thread.new {
                     if ['url-test', 'fallback', 'load-balance', 'smart'].include?(group['type']) then
                        group['interval'] = ${urltest_interval_mod};
                     end;
                  };
               };
            end;
            if Value.key?('proxy-providers') then
               Value['proxy-providers'].each{|name, provider|
                  threads << Thread.new {
                     if provider['health-check'] and provider['health-check']['enable'] then
                        provider['health-check']['interval'] = ${urltest_interval_mod};
                     end;
                  };
               };
            end;
         end;
      rescue Exception => e
         YAML.LOG('Error: Edit URL-Test Interval Failed,【' + e.message + '】');
      end;

      # health-check url
      begin
         if '$urltest_address_mod' != '0' then
            if Value.key?('proxy-providers') then
               Value['proxy-providers'].each{|name, provider|
                  threads << Thread.new {
                     if provider['health-check'] and provider['health-check']['enable'] then
                        provider['health-check']['url'] = '$urltest_address_mod';
                     end;
                  };
               };
            end;
            if Value.key?('proxy-groups') then
               Value['proxy-groups'].each{|group|
                  threads << Thread.new {
                     if ['url-test', 'fallback', 'load-balance', 'smart'].include?(group['type']) then
                        group['url'] = '$urltest_address_mod';
                     end;
                  };
               };
            end;
         end;
      rescue Exception => e
         YAML.LOG('Error: Edit URL-Test URL Failed,【' + e.message + '】');
      end;

      # smart auto switch
      begin
         if ('${10}' == '1' or '${11}' == '1' or '${13}' != '0' or '${14}' != '0' or '${15}' == '1') and Value.key?('proxy-groups') then
            Value['proxy-groups'].each{|group|
               threads << Thread.new {
                  if '${10}' == '1' and ['url-test', 'load-balance'].include?(group['type']) then
                     group['type'] = 'smart';
                     group['uselightgbm'] = true if '${15}' == '1';
                     group['strategy'] = '${13}' if '${13}' != '0';
                     group['collectdata'] = true if '${11}' == '1';
                     group['sample-rate'] = '${12}'.to_f if '${11}' == '1';
                  end;
                  if '${11}' == '1' and group['type'] == 'smart' then
                     group['collectdata'] = true;
                     group['sample-rate'] = '${12}'.to_f;
                  end;
                  if '${13}' != '0' and group['type'] == 'smart' then
                     group['strategy'] = '${13}';
                  end;
                  if '${14}' != '0' and group['type'] == 'smart' then
                     group['policy-priority'] = '${14}';
                  end;
                  if '${15}' == '1' and group['type'] == 'smart' then
                     group['uselightgbm'] = true;
                  end;
                  if '${16}' == '1' and group['type'] == 'smart' then
                     group['prefer-asn'] = true;
                  end;
               };
            };
         end;
      rescue Exception => e
         YAML.LOG('Error: Setting Smart Auto Switch Failed,【' + e.message + '】');
      end;

      threads.each(&:join);
   };
   
   provider_thread.join;
   
   begin
      File.open('$3','w') {|f| YAML.dump(Value, f)};
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
      LOG_OUT "Warning: Multiple Other-Rules-Configurations Enabled, Ignore..."
      return
   fi
   
   local vars="rule_name GlobalTV AsianTV MainlandTV Proxy Youtube Bilibili Bahamut HBOMax Pornhub Apple Scholar Netflix Disney Spotify Steam TikTok AdBlock HTTPDNS Netease_Music Speedtest Telegram Crypto Discord Microsoft PayPal Domestic Others GoogleFCM Discovery DAZN AI_Suite AppleTV miHoYo position format other_parameters"
   
   for var in $vars; do
      case "$var" in
         "MainlandTV") config_get "$var" "$section" "$var" "DIRECT" ;;
         "HBOMax") config_get "$var" "$section" "$var" "$GlobalTV" ;;
         "TikTok") config_get "$var" "$section" "$var" "$GlobalTV" ;;
         "HTTPDNS") config_get "$var" "$section" "$var" "REJECT" ;;
         "Crypto") config_get "$var" "$section" "$var" "$Proxy" ;;
         "Discord") config_get "$var" "$section" "$var" "$Proxy" ;;
         "GoogleFCM") config_get "$var" "$section" "$var" "DIRECT" ;;
         "Discovery") config_get "$var" "$section" "$var" "$GlobalTV" ;;
         "DAZN") config_get "$var" "$section" "$var" "$GlobalTV" ;;
         "AI_Suite") config_get "$var" "$section" "$var" "$Proxy" ;;
         "AppleTV") config_get "$var" "$section" "$var" "$GlobalTV" ;;
         "miHoYo") config_get "$var" "$section" "$var" "$Domestic" ;;
         *) config_get "$var" "$section" "$var" "" ;;
      esac
   done
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
      SKIP_CUSTOM_OTHER_RULES=1
      yml_other_set "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}" "${11}" "${12}" "${13}" "${14}" "${15}" "${16}"
      exit 0

   elif [ "$rule_name" = "lhie1" ]; then

       if [ -z "$PROXY_GROUP_CACHE" ]; then
          PROXY_GROUP_CACHE=$(cat /tmp/Proxy_Group 2>/dev/null)
       fi
       
       required_groups="$GlobalTV $AsianTV $MainlandTV $Proxy $Youtube $Bilibili $Bahamut $HBOMax $Pornhub $Apple $AppleTV $Scholar $Netflix $Disney $Discovery $DAZN $AI_Suite $Spotify $Steam $TikTok $miHoYo $AdBlock $HTTPDNS $Speedtest $Telegram $Crypto $Discord $Microsoft $PayPal $Others $GoogleFCM $Domestic"
       
       for group in $required_groups; do
          if [ -n "$group" ] && [ -z "$(echo "$PROXY_GROUP_CACHE" | grep -F "$group")" ]; then
             LOG_OUT "Warning: Because of The Different Porxy-Group's Name, Stop Setting The Other Rules!"
             SKIP_CUSTOM_OTHER_RULES=1
             yml_other_set "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}" "${11}" "${12}" "${13}" "${14}" "${15}" "${16}"
             exit 0
          fi
       done
   fi
   if [ -z "$Proxy" ]; then
      LOG_OUT "Error: Missing Porxy-Group's Name, Stop Setting The Other Rules!"
      SKIP_CUSTOM_OTHER_RULES=1
      yml_other_set "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}" "${11}" "${12}" "${13}" "${14}" "${15}" "${16}"
      exit 0
   fi
fi

yml_other_set "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}" "${11}" "${12}" "${13}" "${14}" "${15}" "${16}"