#!/bin/sh
. /lib/functions.sh
. /usr/share/openclash/ruby.sh
. /usr/share/openclash/log.sh
. /usr/share/openclash/uci.sh

LOG_FILE="/tmp/openclash.log"
github_address_mod=$(uci_get_config "github_address_mod" || echo 0)
urltest_address_mod=$(uci_get_config "urltest_address_mod" || echo 0)
tolerance=$(uci_get_config "tolerance" || echo 0)
urltest_interval_mod=$(uci_get_config "urltest_interval_mod" || echo 0)

yml_other_set()
{
   ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e "
   begin
      Value = YAML.load_file('$2');
   rescue Exception => e
      YAML.LOG_ERROR('Load File Failed,【' + e.message + '】');
   end;

   begin
      thread_pool = [];
      # GEOIP replace
      geoip_pattern = /^GEOIP,([A-Za-z]{2}),([^,]+)(,.*)?/;
      match_pattern = /(^MATCH.*|^FINAL.*)/;
      thread_pool << Thread.new{
         #BT/P2P DIRECT Rules
         begin
            if $3 == 1 then
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

               Value['rules'].to_a.collect!{|x|
                  x.to_s.gsub(geoip_pattern, 'GEOIP,\1,DIRECT\3').gsub(match_pattern, 'MATCH,DIRECT')
               };
            end;
         rescue Exception => e
            YAML.LOG_ERROR('Set BT/P2P DIRECT Rules Failed,【' + e.message + '】');
         end;

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

         #Custom Rules
         begin
            if $1 == 1 then
               custom_files = [
                  { file: '/etc/openclash/custom/openclash_custom_rules.list', position: 'top' },
                  { file: '/etc/openclash/custom/openclash_custom_rules_2.list', position: 'bottom' }
               ];

                  # 在开始对 custom_files 进行插入之前，记录当前 rules 中 GEOIP、MATCH、DST-PORT,80 的原始规则文本（锚点）
                  anchors_orig = {}
                  if Value.has_key?('rules') and not Value['rules'].to_a.empty? then
                     anchors_orig[:dst80_rule] = Value['rules'].grep(/DST-PORT,80/).last
                     anchors_orig[:match_rule] = Value['rules'].grep(match_pattern).first
                     anchors_orig[:geo_rule] = Value['rules'].grep(geoip_pattern).first
                  else
                     anchors_orig[:dst80_rule] = nil
                     anchors_orig[:match_rule] = nil
                     anchors_orig[:geo_rule] = nil
                  end;

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

                     rule_providers_array = case custom_data.class.to_s
                        when 'Hash'
                           custom_data['rule-providers'].to_a if custom_data['rule-providers'].class.to_s == 'Hash'
                        else
                           []
                     end;

                     next unless rules_array;

                     ipv4_regex = /^(\d{1,3}\.){3}\d{1,3}$/;
                     ipv6_regex = /^(([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]+|::(ffff(:0{1,4})?:)?((25[0-5]|(2[0-4]|1?[0-9])?[0-9])\.){3}(25[0-5]|(2[0-4]|1?[0-9])?[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1?[0-9])?[0-9])\.){3}(25[0-5]|(2[0-4]|1?[0-9])?[0-9]))$/;
                     cidr_regex = /\/\d+$/;
                     rule_suffix_regex = /^no-resolve$|^src$/;

                     ip_rule_types = ['IP-CIDR', 'IP-CIDR6', 'SRC-IP-CIDR', 'SRC-IP-CIDR6', 'IP-SUFFIX', 'SRC-IP-SUFFIX'];
                     transformed_rules = rules_array.map{|x|
                        parts = x.split(',');
                        if parts.length >= 2 && ip_rule_types.include?(parts[0].strip.upcase) then
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
                           YAML.LOG_WARN('Skiped The Custom Rule Because Group & Proxy Not Found:【' + x + '】');
                           false;
                        end;
                     };

                     if Value.has_key?('rules') and not Value['rules'].to_a.empty? then
                        if file_info[:position] == 'top' then
                           valid_rules.reverse.each{|x| Value['rules'].insert(0,x)};
                        else
                           ruby_add_index = nil;
                           if anchors_orig[:dst80_rule]
                              ruby_add_index = Value['rules'].rindex(anchors_orig[:dst80_rule])
                           end;
                           if ruby_add_index.nil? and anchors_orig[:match_rule]
                              ruby_add_index = Value['rules'].rindex(anchors_orig[:match_rule])
                           end;
                           if ruby_add_index.nil? and anchors_orig[:geo_rule]
                              ruby_add_index = Value['rules'].rindex(anchors_orig[:geo_rule])
                           end;
                           ruby_add_index ||= -1;

                           insert_rules = ruby_add_index == -1 ? valid_rules : valid_rules.reverse;
                           insert_rules.each{|x| Value['rules'].insert(ruby_add_index,x)};
                        end;
                        Value['rules'] = Value['rules'].uniq;
                     else
                        Value['rules'] = valid_rules.uniq;
                     end;

                     if rule_providers_array and not rule_providers_array.empty? then
                        Value['rule-providers'] ||= {};
                        Value['rule-providers'] = Value['rule-providers'].merge!(custom_data['rule-providers']);
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
            YAML.LOG_ERROR('Set Custom Rules Failed,【' + e.message + '】');
         end;

         #Router Self Proxy Rule
         begin
            if $4 == 0 and $6 != 2 and '$7' == 'fake-ip' then
               router_rule = 'SRC-IP-CIDR,$5/32,DIRECT';
               if Value.has_key?('rules') and not Value['rules'].to_a.empty? then
                  if Value['rules'].to_a.grep(/(?=.*SRC-IP-CIDR,'$5')/).empty? and not '$5'.empty? then
                     Value['rules']=Value['rules'].to_a.insert(0, router_rule);
                  end;
               else
                  Value['rules']=[router_rule];
               end;
            elsif Value.has_key?('rules') and not Value['rules'].to_a.empty? then
               Value['rules'].delete('SRC-IP-CIDR,$5/32,DIRECT');
            end;
         rescue Exception => e
            YAML.LOG_ERROR('Set Router Self Proxy Rule Failed,【' + e.message + '】');
         end;
      };

      thread_pool << Thread.new{
         threads = [];

         #provider CDN
         begin
            provider_configs = {'proxy-providers' => 'proxy_provider', 'rule-providers' => 'rule_provider'};
            provider_configs.each do |provider_type, path_prefix|
               if Value.key?(provider_type) && Value[provider_type].is_a?(Hash) then
                  Value[provider_type].each{|name, config|
                     threads << Thread.new {
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
            YAML.LOG_ERROR('Edit Provider CDN Failed,【' + e.message + '】');
         end;

         # tolerance
         begin
            if '$tolerance' != '0' and Value.key?('proxy-groups') and Value['proxy-groups'].is_a?(Array) then
               Value['proxy-groups'].each{|group|
                  threads << Thread.new {
                     if group['type'] == 'url-test' then
                        group['tolerance'] = ${tolerance};
                     end;
                  };
               };
            end;
         rescue Exception => e
            YAML.LOG_ERROR('Edit URL-Test Group Tolerance Option Failed,【' + e.message + '】');
         end;

         # URL-Test interval
         begin
            if '$urltest_interval_mod' != '0' then
               if Value.key?('proxy-groups') and Value['proxy-groups'].is_a?(Array) then
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
            YAML.LOG_ERROR('Edit URL-Test Interval Failed,【' + e.message + '】');
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
               if Value.key?('proxy-groups') and Value['proxy-groups'].is_a?(Array) then
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
            YAML.LOG_ERROR('Edit URL-Test URL Failed,【' + e.message + '】');
         end;

         # smart auto switch
         begin
            if ('${8}' == '1' or '${9}' == '1' or '${11}' != '0' or '${12}' != '0' or '${12}' == '1' or '${13}' == '1' or '${14}' != '0') and Value.key?('proxy-groups') and Value['proxy-groups'].is_a?(Array) then
               Value['proxy-groups'].each{|group|
                  threads << Thread.new {
                     if '${8}' == '1' and ['url-test', 'load-balance'].include?(group['type']) then
                        group['type'] = 'smart';
                     end;
                     if group['type'] == 'smart' then
                        if '${9}' == '1' then
                           group['collectdata'] = true;
                           group['sample-rate'] = '${10}'.to_f;
                        end;
                        if '${11}' != '0'then
                           group['policy-priority'] = '${11}';
                        end;
                        if '${12}' == '1' then
                           group['uselightgbm'] = true;
                        end;
                        if '${13}' == '1' then
                           group['prefer-asn'] = true;
                        end;
                        if '${14}' != '0' then
                           group['tolerance'] = '${14}'.to_i;
                        end;
                     end;
                  };
               };
            end;
         rescue Exception => e
            YAML.LOG_ERROR('Setting Smart Auto Switch Failed,【' + e.message + '】');
         end;

         threads.each(&:join);
      };

      thread_pool.each(&:join);

   rescue Exception => e
      YAML.LOG_ERROR('Config File Overwrite Failed,【%s】' % [e.message])
   ensure
      begin
         File.open('$2','w') {|f| YAML.dump(Value, f)};
      rescue Exception => e
         YAML.LOG_ERROR('Write file failed:【%s】' % [e.message])
      end
   end" 2>/dev/null >> $LOG_FILE
}

yml_other_set "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}" "${11}" "${12}" "${13}" "${14}"