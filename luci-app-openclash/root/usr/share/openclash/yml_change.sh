#!/bin/sh
. /usr/share/openclash/ruby.sh

LOG_FILE="/tmp/openclash.log"
START_LOG="/tmp/openclash_start.log"

if [ "$14" != "1" ]; then
   controller_address="0.0.0.0"
   bind_address="*"
elif [ "$18" != "Tun" ] && [ "$14" = "1" ]; then
   controller_address=$11
   bind_address=$11
elif [ "$18" = "Tun" ] && [ "$14" = "1" ]; then
   echo "Warning: Stop Set The Bind Address Option In TUN Mode, Because The Router Will Not Be Able To Connect To The Internet" >> $LOG_FILE
   echo "警告: 在TUN内核下启用仅允许内网会导致路由器无法联网，已忽略此项修改！" >$START_LOG
   controller_address="0.0.0.0"
   bind_address="*"
   sleep 3
fi

if [ -n "$(ruby_read "$7" "['tun']")" ]; then
   if [ -n "$(ruby_read "$7" "['tun']['device-url']")" ]; then
      if [ "$15" -eq 1 ] || [ "$15" -eq 3 ]; then
         uci set openclash.config.config_reload=0
      fi
   else
      uci set openclash.config.config_reload=0
   fi
else
   if [ -n "$15" ]; then
      uci set openclash.config.config_reload=0
   fi
fi

if [ "$(ruby_read "$7" "['external-controller']")" != "$controller_address:$5" ]; then
   uci set openclash.config.config_reload=0
fi
    
if [ "$(ruby_read "$7" "['secret']")" != "$4" ]; then
   uci set openclash.config.config_reload=0
fi
uci commit openclash

CONFIG_HASH=$(ruby -ryaml -E UTF-8 -e "Value = $7;
Value['dns']['enhanced-mode']='$2';
if '$2' == 'fake-ip' then
   Value['dns']['fake-ip-range']='198.18.0.1/16'
else
   Value['dns'].delete('fake-ip-range')
end;
Value['redir-port']=$6;
Value['port']=$9;
Value['socks-port']=$10;
Value['mode']='$13';
Value['log-level']='$12';
Value['allow-lan']=true;
Value['bind-address']='$bind_address';
Value['secret']='$4';
Value['external-controller']='$controller_address:$5';
Value['dns']['enable']=true;
if $8 != 1 then
   Value['dns']['listen']='127.0.0.1:$17'
else
   Value['dns']['listen']='0.0.0.0:$17'
end;
Value['external-ui']='/usr/share/openclash/dashboard';
if $8 == 1 then
   Value['dns']['ipv6']=true
   Value['ipv6']=true
else
   Value['dns']['ipv6']=false
   Value['ipv6']=false
end;
Value_1={'tun'=>{'enable'=>true}};
if $15 == 1 or $15 == 3 then
   Value['tun']=Value_1['tun']
   unless '$16'.empty? then
      Value['tun']['stack']='$16'
   else
      Value['tun']['stack']='system'
   end
   Value_2={'dns-hijack'=>['tcp://8.8.8.8:53','tcp://8.8.4.4:53']};
   Value['tun'].merge!(Value_2)
elsif $15 == 2
   Value['tun']=Value_1['tun']
   Value['tun']['device-url']='dev://clash0'
   Value['tun']['dns-listen']='0.0.0.0:53'
end;
puts Value")

#添加自定义Hosts设置
	  #hash
    if [ "$2" = "redir-host" ] && [ -n "$(ruby_read "YAML.load_file('/etc/openclash/custom/openclash_custom_hosts.list')" ".to_yaml")" ]; then
	     CONFIG_HASH=$(ruby_edit "$CONFIG_HASH" "['dns']['use-hosts']=true")
	     if [ -n "$(ruby_read "$CONFIG_HASH" "['hosts']")" ];then
	        CONFIG_HASH=$(ruby_merge "$CONFIG_HASH" "['hosts']" "/etc/openclash/custom/openclash_custom_hosts.list")
	     else
	        CONFIG_HASH=$(ruby_cover "$CONFIG_HASH" "['hosts']" "/etc/openclash/custom/openclash_custom_hosts.list")
	     fi
	  fi

#fake-ip-filter
	  if [ "$2" = "fake-ip" ]; then
      if [ ! -f "/tmp/openclash_fake_filter.list" ] || [ ! -z "$(grep "config servers" /etc/config/openclash 2>/dev/null)" ]; then
         /usr/share/openclash/openclash_fake_filter.sh
      fi
      if [ -s "/tmp/openclash_servers_fake_filter.conf" ]; then
         mkdir -p /tmp/dnsmasq.d
         ln -s /tmp/openclash_servers_fake_filter.conf /tmp/dnsmasq.d/dnsmasq_openclash.conf
      fi
      if [ -n "$(ruby_read "YAML.load_file('/tmp/openclash_fake_filter.list')" ".to_yaml")" ]; then
         if [ -n "$(ruby_read "$CONFIG_HASH" "['dns']['fake-ip-filter']")" ];then
            CONFIG_HASH=$(ruby_arr_add_file "$CONFIG_HASH" "['dns']['fake-ip-filter']" "-1" "/tmp/openclash_fake_filter.list" "['fake-ip-filter']")
         else
            CONFIG_HASH=$(ruby_cover "$CONFIG_HASH" "['dns']['fake-ip-filter']" "/tmp/openclash_fake_filter.list" "['fake-ip-filter']")
         fi
      fi
   fi
   
  ruby -ryaml -E UTF-8 -e "Value = $CONFIG_HASH; File.open('$19','w') {|f| YAML.dump(Value, f)}" 2>/dev/null