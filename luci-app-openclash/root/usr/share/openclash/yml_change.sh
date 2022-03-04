#!/bin/sh
. /usr/share/openclash/ruby.sh

LOG_FILE="/tmp/openclash.log"
LOGTIME=$(echo $(date "+%Y-%m-%d %H:%M:%S"))
dns_advanced_setting=$(uci -q get openclash.config.dns_advanced_setting)

if [ -n "$(ruby_read "$5" "['tun']")" ]; then
   uci set openclash.config.config_reload=0
else
   if [ -n "${11}" ]; then
      uci set openclash.config.config_reload=0
   fi
fi

if [ -z "${11}" ]; then
   en_mode_tun=0
else
   en_mode_tun=${11}
fi

if [ -z "${12}" ]; then
   stack_type=system
else
   stack_type=${12}
fi

if [ "$(ruby_read "$5" "['external-controller']")" != "$controller_address:$3" ]; then
   uci set openclash.config.config_reload=0
fi
    
if [ "$(ruby_read "$5" "['secret']")" != "$2" ]; then
   uci set openclash.config.config_reload=0
fi
uci commit openclash

ruby -ryaml -E UTF-8 -e "
begin
   Value = YAML.load_file('$5');
rescue Exception => e
   puts '${LOGTIME} Error: Load File Error,【' + e.message + '】'
end
begin
   Value['redir-port']=$4;
   Value['tproxy-port']=${15};
   Value['port']=$7;
   Value['socks-port']=$8;
   Value['mixed-port']=${14};
   Value['mode']='${10}';
   Value['log-level']='$9';
   Value['allow-lan']=true;
   Value['external-controller']='0.0.0.0:$3';
   Value['secret']='$2';
   Value['bind-address']='*';
   Value['external-ui']='/usr/share/openclash/dashboard';
if not Value.key?('dns') then
   Value_1={'dns'=>{'enable'=>true}}
   Value['dns']=Value_1['dns']
else
   Value['dns']['enable']=true
end;
if $6 == 1 then
   Value['ipv6']=true
else
   Value['ipv6']=false
end;
if ${16} == 1 then
   Value['dns']['ipv6']=true
else
   Value['dns']['ipv6']=false
end;
if ${19} != 1 then
   Value['dns']['enhanced-mode']='$1';
else
   Value['dns']['enhanced-mode']='fake-ip';
end;
if '$1' == 'fake-ip' or ${19} == 1 then
   Value['dns']['fake-ip-range']='198.18.0.1/16'
else
   Value['dns'].delete('fake-ip-range')
end;
Value['dns']['listen']='0.0.0.0:${13}'
Value_2={'tun'=>{'enable'=>true}};
if $en_mode_tun != 0 then
   Value['tun']=Value_2['tun']
   Value['tun']['stack']='$stack_type'
   Value_2={'dns-hijack'=>['tcp://8.8.8.8:53','tcp://8.8.4.4:53']}
   Value['tun'].merge!(Value_2)
else
   if Value.key?('tun') then
      Value.delete('tun')
   end
end;
if not Value.key?('profile') then
   Value_3={'profile'=>{'store-selected'=>true}}
   Value['profile']=Value_3['profile']
else
   Value['profile']['store-selected']=true
end;
if ${17} != 1 then
   Value['profile']['store-fake-ip']=false
else
   Value['profile']['store-fake-ip']=true
end;
rescue Exception => e
puts '${LOGTIME} Error: Set General Error,【' + e.message + '】'
end
begin
#添加自定义Hosts设置
if File::exist?('/etc/openclash/custom/openclash_custom_hosts.list') then
   Value_3 = YAML.load_file('/etc/openclash/custom/openclash_custom_hosts.list')
   if Value_3 != false then
      Value['dns']['use-hosts']=true
      if Value.has_key?('hosts') and not Value['hosts'].to_a.empty? then
         Value['hosts'].merge!(Value_3)
         Value['hosts'].uniq
      else
         Value['hosts']=Value_3
      end
   end
end
rescue Exception => e
puts '${LOGTIME} Error: Set Hosts Rules Error,【' + e.message + '】'
end
begin
#fake-ip-filter
if '$1' == 'fake-ip' then
   if File::exist?('/tmp/openclash_fake_filter.list') then
     Value_4 = YAML.load_file('/tmp/openclash_fake_filter.list')
     if Value_4 != false then
        if Value['dns'].has_key?('fake-ip-filter') and not Value['dns']['fake-ip-filter'].to_a.empty? then
           Value_5 = Value_4['fake-ip-filter'].reverse!
           Value_5.each{|x| Value['dns']['fake-ip-filter'].insert(-1,x)}
        else
           Value['dns']['fake-ip-filter']=Value_4['fake-ip-filter']
        end
        Value['dns']['fake-ip-filter']=Value['dns']['fake-ip-filter'].uniq
     end
   end
   if ${18} == 1 then
      if Value['dns'].has_key?('fake-ip-filter') and not Value['dns']['fake-ip-filter'].to_a.empty? then
         Value['dns']['fake-ip-filter'].insert(-1,'+.nflxvideo.net')
         Value['dns']['fake-ip-filter'].insert(-1,'+.media.dssott.com')
         Value['dns']['fake-ip-filter']=Value['dns']['fake-ip-filter'].uniq
      else
         Value['dns'].merge!({'fake-ip-filter'=>['+.nflxvideo.net', '+.media.dssott.com']})
      end
   end
elsif ${19} == 1 then
   if Value['dns'].has_key?('fake-ip-filter') and not Value['dns']['fake-ip-filter'].to_a.empty? then
      Value['dns']['fake-ip-filter'].insert(-1,'+.*')
      Value['dns']['fake-ip-filter']=Value['dns']['fake-ip-filter'].uniq
   else
      Value['dns'].merge!({'fake-ip-filter'=>['+.*']})
   end
end;
rescue Exception => e
puts '${LOGTIME} Error: Set Fake-IP-Filter Error,【' + e.message + '】'
end
begin
#nameserver-policy
if '$dns_advanced_setting' == '1' then
   if File::exist?('/etc/openclash/custom/openclash_custom_domain_dns_policy.list') then
     Value_6 = YAML.load_file('/etc/openclash/custom/openclash_custom_domain_dns_policy.list')
     if Value_6 != false then
        if Value['dns'].has_key?('nameserver-policy') and not Value['dns']['nameserver-policy'].to_a.empty? then
           Value['dns']['nameserver-policy'].merge!(Value_6)
           Value['dns']['nameserver-policy'].uniq
        else
           Value['dns']['nameserver-policy']=Value_6
        end
     end
  end
end;
rescue Exception => e
puts '${LOGTIME} Error: Set Nameserver-Policy Error,【' + e.message + '】'
ensure
File.open('$5','w') {|f| YAML.dump(Value, f)}
end" 2>/dev/null >> $LOG_FILE
