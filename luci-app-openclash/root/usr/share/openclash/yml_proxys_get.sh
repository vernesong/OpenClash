#!/bin/bash
. /lib/functions.sh
. /usr/share/openclash/log.sh

set_lock() {
   exec 875>"/tmp/lock/openclash_proxies_get.lock" 2>/dev/null
   flock -x 875 2>/dev/null
}

del_lock() {
   flock -u 875 2>/dev/null
   rm -rf "/tmp/lock/openclash_proxies_get.lock"
}

CONFIG_FILE=$(uci -q get openclash.config.config_path)
CONFIG_NAME=$(echo "$CONFIG_FILE" |awk -F '/' '{print $5}' 2>/dev/null)
UPDATE_CONFIG_FILE=$(uci -q get openclash.config.config_update_path)
UPDATE_CONFIG_NAME=$(echo "$UPDATE_CONFIG_FILE" |awk -F '/' '{print $5}' 2>/dev/null)
LOG_FILE="/tmp/openclash.log"
set_lock

if [ ! -z "$UPDATE_CONFIG_FILE" ]; then
   CONFIG_FILE="$UPDATE_CONFIG_FILE"
   CONFIG_NAME="$UPDATE_CONFIG_NAME"
fi

if [ -z "$CONFIG_FILE" ]; then
   for file_name in /etc/openclash/config/*
   do
      if [ -f "$file_name" ]; then
         CONFIG_FILE=$file_name
         CONFIG_NAME=$(echo "$CONFIG_FILE" |awk -F '/' '{print $5}' 2>/dev/null)
         break
      fi
   done
fi

if [ -z "$CONFIG_NAME" ]; then
   CONFIG_FILE="/etc/openclash/config/config.yaml"
   CONFIG_NAME="config.yaml"
fi

BACKUP_FILE="/etc/openclash/backup/$(echo "$CONFIG_FILE" |awk -F '/' '{print $5}' 2>/dev/null)"

if [ ! -s "$CONFIG_FILE" ] && [ ! -s "$BACKUP_FILE" ]; then
   del_lock
   exit 0
elif [ ! -s "$CONFIG_FILE" ] && [ -s "$BACKUP_FILE" ]; then
   mv "$BACKUP_FILE" "$CONFIG_FILE"
fi

CFG_FILE="/etc/config/openclash"
match_servers="/tmp/match_servers.list"
match_provider="/tmp/match_provider.list"
servers_update=$(uci -q get openclash.config.servers_update)
servers_if_update=$(uci -q get openclash.config.servers_if_update)

cfg_new_servers_groups_check()
{
   
   if [ -z "$1" ]; then
      return
   fi
   
   config_foreach cfg_group_name "groups" "$1"
}

cfg_group_name()
{
   local section="$1"
   local name config
   config_get "name" "$section" "name" ""
   config_get "config" "$section" "config" ""

   if [ -z "$config" ]; then
      return
   fi
   
   if [ "$config" != "$CONFIG_NAME" ] && [ "$config" != "all" ]; then
      return
   fi

   if [ -z "$name" ]; then
	    return
   fi

   if [ "$name" = "$2" ]; then
      config_group_exist=$(( $config_group_exist + 1 ))
   fi
}

#判断当前配置文件策略组信息是否包含指定策略组
config_group_exist=0
if [ -z "$(uci -q get openclash.config.new_servers_group)" ]; then
   config_group_exist=2
elif [ "$(uci -q get openclash.config.new_servers_group)" = "all" ]; then
   config_group_exist=1
else
   config_load "openclash"
   config_list_foreach "config" "new_servers_group" cfg_new_servers_groups_check

   if [ "$config_group_exist" -ne 0 ]; then
      config_group_exist=1
   else
      config_group_exist=0
   fi
fi

yml_provider_name_get()
{
   local section="$1"
   local name config
   config_get "name" "$section" "name" ""
   config_get "config" "$section" "config" ""
   if [ -n "$name" ] && [ "$config" = "$CONFIG_NAME" ]; then
      echo "$provider_nums.$name" >>"$match_provider"
   fi
   provider_nums=$(( $provider_nums + 1 ))
}

yml_servers_name_get()
{
	local section="$1"
   local name config
   config_get "name" "$section" "name" ""
   config_get "config" "$section" "config" ""
   if [ -n "$name" ] && [ "$config" = "$CONFIG_NAME" ]; then
      echo "$server_num.$name" >>"$match_servers"
   fi
   server_num=$(( $server_num + 1 ))
}

LOG_OUT "Start Getting【$CONFIG_NAME】Proxy-providers Setting..."

echo "" >"$match_provider"
provider_nums=0
config_load "openclash"
config_foreach yml_provider_name_get "proxy-provider"
	   
LOG_OUT "Start Getting【$CONFIG_NAME】Proxies Setting..."

echo "" >"$match_servers"
server_num=0
config_load "openclash"
config_foreach yml_servers_name_get "servers"

#获取代理集信息
ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e "
   begin
      Value = YAML.load_file('$CONFIG_FILE');
   rescue Exception => e
      YAML.LOG('Error: Load File Failed,【' + e.message + '】');
   end;

   threads = [];
   threads_prv = [];
   threads_pr = [];

   if not Value.key?('proxy-providers') or Value['proxy-providers'].nil? then
      Value['proxy-providers'] = {};
   end;

   if not Value.key?('proxies') or Value['proxies'].nil? then
      Value['proxies'] = [];
   end;

   Value['proxy-providers'].each do |x,y|
      threads_pr << Thread.new {
         begin
            YAML.LOG('Start Getting【${CONFIG_NAME} - ' + y['type'].to_s + ' - ' + x.to_s + '】Proxy-provider Setting...');
            #代理集存在时获取代理集编号
            cmd = 'grep -E \'\.' + x + '$\' ${match_provider} 2>/dev/null|awk -F \".\" \'{print \$1}\'';
            provider_nums=%x(#{cmd}).chomp;
            if not provider_nums.empty? then
               cmd = 'sed -i \"/^' + provider_nums + '\./c\\#match#\" $match_provider 2>/dev/null';
               system(cmd);
               uci_set='uci -q set openclash.@proxy-provider[' + provider_nums + '].';
               uci_get='uci -q get openclash.@proxy-provider[' + provider_nums + '].';
               uci_add='uci -q add_list openclash.@proxy-provider[' + provider_nums + '].';
               uci_del='uci -q delete openclash.@proxy-provider[' + provider_nums + '].';
               cmd = uci_get + 'manual';
               if not %x(#{cmd}).chomp then
                  cmd = uci_set + 'manual=0';
                  system(cmd);
               end;
               cmd = uci_set + 'type=\"' + y['type'].to_s + '\"';
               system(cmd);
            else
               #代理集不存在时添加新代理集
               uci_name_tmp=%x{uci -q add openclash proxy-provider 2>&1}.chomp;
               uci_set='uci -q set openclash.' + uci_name_tmp + '.';
               uci_add='uci -q add_list openclash.' + uci_name_tmp + '.';
               uci_del='uci -q delete openclash.' + uci_name_tmp + '.';
               
               if '$config_group_exist' == 0 and '$servers_if_update' == '1' and '$servers_update' == 1 then
                  cmd = uci_set + 'enabled=0';
                  system(cmd);
               else
                  cmd = uci_set + 'enabled=1';
                  system(cmd);
               end;
               cmd = uci_set + 'manual=0';
               system(cmd);
               cmd = uci_set + 'config=\"$CONFIG_NAME\"';
               system(cmd);
               cmd = uci_set + 'name=\"' + x.to_s + '\"';
               system(cmd);
               cmd = uci_set + 'type=\"' + y['type'].to_s + '\"';
               system(cmd);
            end;
            
            threads_prv << Thread.new{
               #path
               if y.key?('path') then
                  if y['type'] == 'http' then
                     provider_path = uci_set + 'path=\"./proxy_provider/' + x + '.yaml\"'
                  else
                     provider_path = uci_set + 'path=\"' + y['path'].to_s + '\"'
                  end
                  system(provider_path)
               end
            };
            
            threads_prv << Thread.new{
               #gen_url
               if y.key?('url') then
                  provider_gen_url = uci_set + 'provider_url=\"' + y['url'].to_s + '\"'
                  system(provider_gen_url)
               end
            };
            
            threads_prv << Thread.new{
               #gen_interval
               if y.key?('interval') then
                  provider_gen_interval = uci_set + 'provider_interval=\"' + y['interval'].to_s + '\"'
                  system(provider_gen_interval)
               end
            };
            
            threads_prv << Thread.new{
               #filter
               if y.key?('filter') then
                  provider_gen_filter = uci_set + 'provider_filter=\"' + y['filter'].to_s + '\"'
                  system(provider_gen_filter)
               end
            };
            
            threads_prv << Thread.new{
               #che_enable
               if y.key?('health-check') then
                  if y['health-check'].key?('enable') then
                     provider_che_enable = uci_set + 'health_check=\"' + y['health-check']['enable'].to_s + '\"'
                     system(provider_che_enable)
                  end
               end
            };
            
            threads_prv << Thread.new{
               #che_url
               if y.key?('health-check') then
                  if y['health-check'].key?('url') then
                     provider_che_url = uci_set + 'health_check_url=\"' + y['health-check']['url'].to_s + '\"'
                     system(provider_che_url)
                  end
               end
            };
            
            threads_prv << Thread.new{
               #che_interval
               if y.key?('health-check') then
                  if y['health-check'].key?('interval') then
                     provider_che_interval = uci_set + 'health_check_interval=\"' + y['health-check']['interval'].to_s + '\"'
                     system(provider_che_interval)
                  end
               end
            };

            threads_prv << Thread.new{
               #加入策略组
               if '$servers_if_update' == '1' and '$config_group_exist' == '1' and '$servers_update' == '1' and provider_nums.empty? then
                  #新代理集且设置默认策略组时加入指定策略组
                  new_provider_groups = %x{uci get openclash.config.new_servers_group}.chomp.split(\"'\").map { |x| x.strip }.reject { |x| x.empty? };
                  new_provider_groups.each do |x|
                     uci = uci_add + 'groups=\"' + x + '\"'
                     system(uci)
                  end
               elsif '$servers_if_update' != '1' then
                  threads_agr = [];
                  cmd = uci_del + 'groups >/dev/null 2>&1';
                  system(cmd);
                  Value['proxy-groups'].each{
                  |z|
                     threads_agr << Thread.new {
                        if z.key?('use') then
                           z['use'].each{
                           |v|
                           if v == x then
                              uci = uci_add + 'groups=\"^' + z['name'] + '$\"'
                              system(uci)
                              break
                           end
                           }
                        end
                     };
                  };
                  threads_agr.each(&:join)
               end;
            };
            threads_prv.each(&:join)
         rescue Exception => e
            YAML.LOG('Error: Resolve Proxy-providers Failed,【${CONFIG_NAME} - ' + x + ': ' + e.message + '】');
         end;
      };
   end;
   
   Value['proxies'].each do |x|
      threads_pr << Thread.new {
         begin
            YAML.LOG('Start Getting【${CONFIG_NAME} - ' + x['type'].to_s + ' - ' + x['name'].to_s + '】Proxy Setting...');
            #节点存在时获取节点编号
            cmd = 'grep -E \'\.' + x['name'].to_s + '$\' ${match_servers} 2>/dev/null|awk -F \".\" \'{print \$1}\'';
            server_num=%x(#{cmd}).chomp;
            if not server_num.empty? then
               #更新已有节点
               cmd = 'sed -i \"/^' + server_num + '\./c\\#match#\" $match_servers 2>/dev/null';
               system(cmd);
               uci_set='uci -q set openclash.@servers[' + server_num + '].';
               uci_get='uci -q get openclash.@servers[' + server_num + '].';
               uci_add='uci -q add_list openclash.@servers[' + server_num + '].';
               uci_del='uci -q delete openclash.@servers[' + server_num + '].';
               cmd = uci_get + 'manual';
               if not %x(#{cmd}).chomp then
                  cmd = uci_set + 'manual=0';
                  system(cmd);
               end;
            else
               #添加新节点
               uci_name_tmp=%x{uci -q add openclash servers 2>&1}.chomp;
               uci_set='uci -q set openclash.' + uci_name_tmp + '.';
               uci_add='uci -q add_list openclash.' + uci_name_tmp + '.';
               uci_del='uci -q delete openclash.' + uci_name_tmp + '.';
               if '$config_group_exist' == 0 and '$servers_if_update' == '1' and '$servers_update' == 1 then
                  cmd = uci_set + 'enabled=0';
                  system(cmd);
               else
                  cmd = uci_set + 'enabled=1';
                  system(cmd);
               end;
               cmd = uci_set + 'manual=0';
               system(cmd);
               cmd = uci_set + 'config=\"$CONFIG_NAME\"';
               system(cmd);
               if x.key?('name') and not x['name'].nil? then
                  cmd = uci_set + 'name=\"' + x['name'].to_s + '\"';
                  system(cmd);
               else
                  next;
               end;
            end;

            #type
            if x.key?('type') and not x['type'].nil? then
               type = uci_set + 'type=\"' + x['type'].to_s + '\"';
               system(type)
            else
               next;
            end

            threads << Thread.new{
               #server
               if x.key?('server') then
                  server = uci_set + 'server=\"' + x['server'].to_s + '\"'
                  system(server)
               end
            };

            threads << Thread.new{
               #port
               if x.key?('port') then
                  port = uci_set + 'port=\"' + x['port'].to_s + '\"'
                  system(port)
               end
            };

            threads << Thread.new{
               #udp
               if x.key?('udp') then
                  udp = uci_set + 'udp=\"' + x['udp'].to_s + '\"'
                  system(udp)
               end
            };
            
            threads << Thread.new{
               #interface-name
               if x.key?('interface-name') then
                  interface_name = uci_set + 'interface_name=\"' + x['interface-name'].to_s + '\"'
                  system(interface_name)
               end
            };
            
            threads << Thread.new{
               #routing-mark
               if x.key?('routing-mark') then
                  routing_mark = uci_set + 'routing_mark=\"' + x['routing-mark'].to_s + '\"'
                  system(routing_mark)
               end;
            };

            threads << Thread.new{
               #ip_version
               if x.key?('ip-version') then
                  ip_version = uci_set + 'ip_version=\"' + x['ip-version'].to_s + '\"'
                  system(ip_version)
               end
            };

            threads << Thread.new{
               #TFO
               if x.key?('tfo') then
                  tfo = uci_set + 'tfo=\"' + x['tfo'].to_s + '\"'
                  system(tfo)
               end
            };
            
            threads << Thread.new{
               #Multiplex
               if x.key?('smux') then
                  if x['smux'].key?('enabled') then
                     smux = uci_set + 'multiplex=\"' + x['smux']['enabled'].to_s + '\"'
                     system(smux)
                  end;
                  #multiplex_protocol
                  if x['smux'].key?('protocol') then
                     multiplex_protocol = uci_set + 'multiplex_protocol=\"' + x['smux']['protocol'].to_s + '\"'
                     system(multiplex_protocol)
                  end;
                  #multiplex_max_connections
                  if x['smux'].key?('max-connections') then
                     multiplex_max_connections = uci_set + 'multiplex_max_connections=\"' + x['smux']['max-connections'].to_s + '\"'
                     system(multiplex_max_connections)
                  end;
                  #multiplex_min_streams
                  if x['smux'].key?('min-streams') then
                     multiplex_min_streams = uci_set + 'multiplex_min_streams=\"' + x['smux']['min-streams'].to_s + '\"'
                     system(multiplex_min_streams)
                  end;
                  #multiplex_max_streams
                  if x['smux'].key?('max-streams') then
                     multiplex_max_streams = uci_set + 'multiplex_max_streams=\"' + x['smux']['max-streams'].to_s + '\"'
                     system(multiplex_max_streams)
                  end;
                  #multiplex_padding
                  if x['smux'].key?('padding') then
                     multiplex_padding = uci_set + 'multiplex_padding=\"' + x['smux']['padding'].to_s + '\"'
                     system(multiplex_padding)
                  end;
                  #multiplex_statistic
                  if x['smux'].key?('statistic') then
                     multiplex_statistic = uci_set + 'multiplex_statistic=\"' + x['smux']['statistic'].to_s + '\"'
                     system(multiplex_statistic)
                  end;
                  #multiplex_only_tcp
                  if x['smux'].key?('only-tcp') then
                     multiplex_only_tcp = uci_set + 'multiplex_only_tcp=\"' + x['smux']['only-tcp'].to_s + '\"'
                     system(multiplex_only_tcp)
                  end;
               end;
            };

            if x['type'] == 'ss' then
               threads << Thread.new{
                  #cipher
                  if x.key?('cipher') then
                     cipher = uci_set + 'cipher=\"' + x['cipher'].to_s + '\"'
                     system(cipher)
                  end
               };

               threads << Thread.new{
                  #udp-over-tcp
                  if x.key?('udp-over-tcp') then
                     udp_over_tcp = uci_set + 'udp_over_tcp=\"' + x['udp-over-tcp'].to_s + '\"'
                     system(udp_over_tcp)
                  end
               };

               threads << Thread.new{
                  #plugin-opts
                  if x.key?('plugin-opts') then
                     #mode
                     if x['plugin-opts'].key?('mode') then
                        mode = uci_set + 'obfs=\"' + x['plugin-opts']['mode'].to_s + '\"'
                        system(mode)
                     else
                        mode = uci_set + 'obfs=none'
                        system(mode)
                     end
                     #host:
                     if x['plugin-opts'].key?('host') then
                        host = uci_set + 'host=\"' + x['plugin-opts']['host'].to_s + '\"'
                        system(host)
                     end
                     #fingerprint
                     if x['plugin-opts'].key?('fingerprint') then
                        fingerprint = uci_set + 'fingerprint=\"' + x['plugin-opts']['fingerprint'].to_s + '\"'
                        system(fingerprint)
                     end
                     if x['plugin'].to_s == 'v2ray-plugin' then
                        #path
                        if x['plugin-opts'].key?('path') then
                           path = uci_set + 'path=\"' + x['plugin-opts']['path'].to_s + '\"'
                           system(path)
                        end
                        #mux
                        if x['plugin-opts'].key?('mux') then
                           mux = uci_set + 'mux=\"' + x['plugin-opts']['mux'].to_s + '\"'
                           system(mux)
                        end
                        #headers
                        if x['plugin-opts'].key?('headers') then
                           if x['plugin-opts']['headers'].key?('custom') then
                              custom = uci_set + 'custom=\"' + x['plugin-opts']['headers']['custom'].to_s + '\"'
                              system(custom)
                           end
                        end
                        #tls
                        if x['plugin-opts'].key?('tls') then
                           tls = uci_set + 'tls=\"' + x['plugin-opts']['tls'].to_s + '\"'
                           system(tls)
                        end
                        #skip-cert-verify
                        if x['plugin-opts'].key?('skip-cert-verify') then
                           skip_cert_verify = uci_set + 'skip_cert_verify=\"' + x['plugin-opts']['skip-cert-verify'].to_s + '\"'
                           system(skip_cert_verify)
                        end
                     end;
                     if x['plugin'].to_s == 'shadow-tls' then
                        mode = uci_set + 'obfs=\"' + x['plugin'].to_s + '\"'
                        system(mode)
                        #password
                        if x['plugin-opts'].key?('password') then
                           obfs_password = uci_set + 'obfs_password=\"' + x['plugin-opts']['password'].to_s + '\"'
                           system(obfs_password)
                        end
                     end;
                     if x['plugin'].to_s == 'restls' then
                        mode = uci_set + 'obfs=\"' + x['plugin'].to_s + '\"'
                        system(mode)
                        #password
                        if x['plugin-opts'].key?('password') then
                           obfs_password = uci_set + 'obfs_password=\"' + x['plugin-opts']['password'].to_s + '\"'
                           system(obfs_password)
                        end
                        #version-hint
                        if x['plugin-opts'].key?('version-hint') then
                           obfs_version_hint = uci_set + 'obfs_version_hint=\"' + x['plugin-opts']['version-hint'].to_s + '\"'
                           system(obfs_version_hint)
                        end
                        #restls-script
                        if x['plugin-opts'].key?('restls-script') then
                           obfs_restls_script = uci_set + 'obfs_restls_script=\"' + x['plugin-opts']['restls-script'].to_s + '\"'
                           system(obfs_restls_script)
                        end
                     end;
                  end
               };
            end;

            if x['type'] == 'ssr' then
               threads << Thread.new{
               #cipher
               if x.key?('cipher') then
                  if x['cipher'].to_s == 'none' then
                     cipher = uci_set + 'cipher_ssr=dummy'
                  else
                     cipher = uci_set + 'cipher_ssr=\"' + x['cipher'].to_s + '\"'
                  end
                  system(cipher)
               end
               };
               
               threads << Thread.new{
               #obfs
               if x.key?('obfs') then
                  obfs = uci_set + 'obfs_ssr=\"' + x['obfs'].to_s + '\"'
                  system(obfs)
               end
               };
               
               threads << Thread.new{
               #protocol
               if x.key?('protocol') then
                  protocol = uci_set + 'protocol=\"' + x['protocol'].to_s + '\"'
                  system(protocol)
               end
               };
               
               threads << Thread.new{
               #obfs-param
               if x.key?('obfs-param') then
                  obfs_param = uci_set + 'obfs_param=\"' + x['obfs-param'].to_s + '\"'
                  system(obfs_param)
               end
               };
               
               threads << Thread.new{
               #protocol-param
               if x.key?('protocol-param') then
                  protocol_param = uci_set + 'protocol_param=\"' + x['protocol-param'].to_s + '\"'
                  system(protocol_param)
               end
               };
            end;
            if x['type'] == 'vmess' then
               threads << Thread.new{
               #uuid
               if x.key?('uuid') then
                  uuid = uci_set + 'uuid=\"' + x['uuid'].to_s + '\"'
                  system(uuid)
               end
               };
               
               threads << Thread.new{
               #alterId
               if x.key?('alterId') then
                  alterId = uci_set + 'alterId=\"' + x['alterId'].to_s + '\"'
                  system(alterId)
               end
               };
               
               threads << Thread.new{
               #cipher
               if x.key?('cipher') then
                  cipher = uci_set + 'securitys=\"' + x['cipher'].to_s + '\"'
                  system(cipher)
               end
               };
               
               threads << Thread.new{
               #xudp
               if x.key?('xudp') then
                  xudp = uci_set + 'xudp=\"' + x['xudp'].to_s + '\"'
                  system(xudp)
               end
               };

               threads << Thread.new{
               #packet_encoding
               if x.key?('packet-encoding') then
                  packet_encoding = uci_set + 'packet_encoding=\"' + x['packet-encoding'].to_s + '\"'
                  system(packet_encoding)
               end
               };

               threads << Thread.new{
               #GlobalPadding
               if x.key?('global-padding') then
                  global_padding = uci_set + 'global_padding=\"' + x['global-padding'].to_s + '\"'
                  system(global_padding)
               end
               };

               threads << Thread.new{
               #authenticated_length
               if x.key?('authenticated-length') then
                  authenticated_length = uci_set + 'authenticated_length=\"' + x['authenticated-length'].to_s + '\"'
                  system(authenticated_length)
               end
               };
               
               threads << Thread.new{
               #tls
               if x.key?('tls') then
                  tls = uci_set + 'tls=\"' + x['tls'].to_s + '\"'
                  system(tls)
               end
               };
               
               threads << Thread.new{
               #skip-cert-verify
               if x.key?('skip-cert-verify') then
                  skip_cert_verify = uci_set + 'skip_cert_verify=\"' + x['skip-cert-verify'].to_s + '\"'
                  system(skip_cert_verify)
               end
               };
               
               threads << Thread.new{
               #servername
               if x.key?('servername') then
                  servername = uci_set + 'servername=\"' + x['servername'].to_s + '\"'
                  system(servername)
               end
               };

               threads << Thread.new{
               #fingerprint
               if x.key?('fingerprint') then
                  fingerprint = uci_set + 'fingerprint=\"' + x['fingerprint'].to_s + '\"'
                  system(fingerprint)
               end
               };

               threads << Thread.new{
               #client_fingerprint
               if x.key?('client-fingerprint') then
                  client_fingerprint = uci_set + 'client_fingerprint=\"' + x['client-fingerprint'].to_s + '\"'
                  system(client_fingerprint)
               end
               };
               
               threads << Thread.new{
               #network:
               if x.key?('network') then
                  if x['network'].to_s == 'ws'
                     cmd = uci_set + 'obfs_vmess=websocket'
                     system(cmd)
                     #ws-path:
                     if x.key?('ws-path') then
                        path = uci_set + 'ws_opts_path=\"' + x['ws-path'].to_s + '\"'
                        system(path)
                     end
                     #Host:
                     if x.key?('ws-headers') then
                        cmd = uci_del + 'ws_opts_headers >/dev/null 2>&1'
                        system(cmd)
                        x['ws-headers'].keys.each{
                        |v|
                           custom = uci_add + 'ws_opts_headers=\"' + v.to_s + ': '+ x['ws-headers'][v].to_s + '\"'
                           system(custom)
                        }
                     end
                     #ws-opts-path:
                     if x.key?('ws-opts') then
                        if x['ws-opts'].key?('path') then
                           ws_opts_path = uci_set + 'ws_opts_path=\"' + x['ws-opts']['path'].to_s + '\"'
                           system(ws_opts_path)
                        end
                        #ws-opts-headers:
                        if x['ws-opts'].key?('headers') then
                           cmd = uci_del + 'ws_opts_headers >/dev/null 2>&1'
                           system(cmd)
                           x['ws-opts']['headers'].keys.each{
                           |v|
                              ws_opts_headers = uci_add + 'ws_opts_headers=\"' + v.to_s + ': '+ x['ws-opts']['headers'][v].to_s + '\"'
                              system(ws_opts_headers)
                           }
                        end
                        #max-early-data:
                        if x['ws-opts'].key?('max-early-data') then
                           max_early_data = uci_set + 'max_early_data=\"' + x['ws-opts']['max-early-data'].to_s + '\"'
                           system(max_early_data)
                        end
                        #early-data-header-name:
                        if x['ws-opts'].key?('early-data-header-name') then
                           early_data_header_name = uci_set + 'early_data_header_name=\"' + x['ws-opts']['early-data-header-name'].to_s + '\"'
                           system(early_data_header_name)
                        end
                     end
                  elsif x['network'].to_s == 'http'
                     cmd = uci_set + 'obfs_vmess=http'
                     system(cmd)
                     if x.key?('http-opts') then
                        if x['http-opts'].key?('path') then
                           cmd = uci_del + 'http_path >/dev/null 2>&1'
                           system(cmd)
                           x['http-opts']['path'].each{
                           |x|
                           http_path = uci_add + 'http_path=\"' + x.to_s + '\"'
                           system(http_path)
                           }
                        end
                        if x['http-opts'].key?('headers') then
                           if x['http-opts']['headers'].key?('Connection') then
                              if x['http-opts']['headers']['Connection'].include?('keep-alive') then
                                 keep_alive = uci_set + 'keep_alive=true'
                              else
                                 keep_alive = uci_set + 'keep_alive=false'
                              end
                              system(keep_alive)
                           end
                        end
                     end
                  elsif x['network'].to_s == 'h2'
                     cmd = uci_set + 'obfs_vmess=h2'
                     system(cmd)
                     if x.key?('h2-opts') then
                        if x['h2-opts'].key?('host') then
                           cmd = uci_del + 'h2_host >/dev/null 2>&1'
                           system(cmd)
                           x['h2-opts']['host'].each{
                           |x|
                           h2_host = uci_add + 'h2_host=\"' + x.to_s + '\"'
                           system(h2_host)
                           }
                        end
                        if x['h2-opts'].key?('path') then
                           h2_path = uci_set + 'h2_path=\"' + x['h2-opts']['path'].to_s + '\"'
                           system(h2_path)
                        end
                     end
                  elsif x['network'].to_s == 'grpc'
                     #grpc-service-name
                     cmd = uci_set + 'obfs_vmess=grpc'
                     system(cmd)
                     if x.key?('grpc-opts') then
                        if x['grpc-opts'].key?('grpc-service-name') then
                           grpc_service_name = uci_set + 'grpc_service_name=\"' + x['grpc-opts']['grpc-service-name'].to_s + '\"'
                           system(grpc_service_name)
                        end
                     end
                  else
                     cmd = uci_set + 'obfs_vmess=none'
                     system(cmd)
                  end
               end
               };
            end;

            #Tuic
            if x['type'] == 'tuic' then
               threads << Thread.new{
               #tc_ip
               if x.key?('ip') then
                  tc_ip = uci_set + 'tc_ip=\"' + x['ip'].to_s + '\"'
                  system(tc_ip)
               end
               };

               threads << Thread.new{
               #tc_token
               if x.key?('token') then
                  tc_token = uci_set + 'tc_token=\"' + x['token'].to_s + '\"'
                  system(tc_token)
               end
               };

               threads << Thread.new{
               #heartbeat_interval
               if x.key?('heartbeat-interval') then
                  heartbeat_interval = uci_set + 'heartbeat_interval=\"' + x['heartbeat-interval'].to_s + '\"'
                  system(heartbeat_interval)
               end
               };

               threads << Thread.new{
               #tc_alpn
               if x.key?('alpn') then
                  cmd = uci_del + 'tc_alpn >/dev/null 2>&1'
                  system(cmd)
                  x['alpn'].each{
                  |x|
                     tc_alpn = uci_add + 'tc_alpn=\"' + x.to_s + '\"'
                     system(tc_alpn)
                  }
               end;
               };

               threads << Thread.new{
               #disable_sni
               if x.key?('disable-sni') then
                  disable_sni = uci_set + 'disable_sni=\"' + x['disable-sni'].to_s + '\"'
                  system(disable_sni)
               end
               };

               threads << Thread.new{
               #reduce_rtt
               if x.key?('reduce-rtt') then
                  reduce_rtt = uci_set + 'reduce_rtt=\"' + x['reduce-rtt'].to_s + '\"'
                  system(reduce_rtt)
               end
               };

               threads << Thread.new{
               #fast_open
               if x.key?('fast-open') then
                  fast_open = uci_set + 'fast_open=\"' + x['fast-open'].to_s + '\"'
                  system(fast_open)
               end
               };

               threads << Thread.new{
               #request_timeout
               if x.key?('request-timeout') then
                  request_timeout = uci_set + 'request_timeout=\"' + x['request-timeout'].to_s + '\"'
                  system(request_timeout)
               end
               };

               threads << Thread.new{
               #udp_relay_mode
               if x.key?('udp-relay-mode') then
                  udp_relay_mode = uci_set + 'udp_relay_mode=\"' + x['udp-relay-mode'].to_s + '\"'
                  system(udp_relay_mode)
               end
               };

               threads << Thread.new{
               #congestion_controller
               if x.key?('congestion-controller') then
                  congestion_controller = uci_set + 'congestion_controller=\"' + x['congestion-controller'].to_s + '\"'
                  system(congestion_controller)
               end
               };

               threads << Thread.new{
               #max_udp_relay_packet_size
               if x.key?('max-udp-relay-packet-size') then
                  max_udp_relay_packet_size = uci_set + 'max_udp_relay_packet_size=\"' + x['max-udp-relay-packet-size'].to_s + '\"'
                  system(max_udp_relay_packet_size)
               end
               };

               threads << Thread.new{
               #max-open-streams
               if x.key?('max-open-streams') then
                  max_open_streams = uci_set + 'max_open_streams=\"' + x['max-open-streams'].to_s + '\"'
                  system(max_open_streams)
               end
               };
            end;

            #WireGuard
            if x['type'] == 'wireguard' then
               threads << Thread.new{
               #wg_ip
               if x.key?('ip') then
                  wg_ip = uci_set + 'wg_ip=\"' + x['ip'].to_s + '\"'
                  system(wg_ip)
               end
               };

               threads << Thread.new{
               #wg_ipv6
               if x.key?('ipv6') then
                  wg_ipv6 = uci_set + 'wg_ipv6=\"' + x['ipv6'].to_s + '\"'
                  system(wg_ipv6)
               end
               };

               threads << Thread.new{
               #private_key
               if x.key?('private-key') then
                  private_key = uci_set + 'private_key=\"' + x['private-key'].to_s + '\"'
                  system(private_key)
               end
               };

               threads << Thread.new{
               #public_key
               if x.key?('public-key') then
                  public_key = uci_set + 'public_key=\"' + x['public-key'].to_s + '\"'
                  system(public_key)
               end
               };

               threads << Thread.new{
               #preshared_key
               if x.key?('preshared-key') then
                  preshared_key = uci_set + 'preshared_key=\"' + x['preshared-key'].to_s + '\"'
                  system(preshared_key)
               end
               };

               threads << Thread.new{
               #wg_mtu
               if x.key?('mtu') then
                  wg_mtu = uci_set + 'wg_mtu=\"' + x['mtu'].to_s + '\"'
                  system(wg_mtu)
               end
               };

               threads << Thread.new{
               #wg_dns
               if x.key?('dns') then
                  cmd =  uci_del + 'wg_dns >/dev/null 2>&1'
                  system(cmd)
                  x['dns'].each{
                  |x|
                     wg_dns = uci_add + 'wg_dns=\"' + x.to_s + '\"'
                     system(wg_dns)
                  }
               end;
               };
            end;

            if x['type'] == 'hysteria' then
               #hysteria
               threads << Thread.new{
               #hysteria_protocol
               if x.key?('protocol') then
                  hysteria_protocol = uci_set + 'hysteria_protocol=\"' + x['protocol'].to_s + '\"'
                  system(hysteria_protocol)
               end
               };
            end;

            if x['type'] == 'hysteria2' then
               #hysteria2
               threads << Thread.new{
               #hysteria2_protocol
               if x.key?('protocol') then
                  hysteria2_protocol = uci_set + 'hysteria2_protocol=\"' + x['protocol'].to_s + '\"'
                  system(hysteria2_protocol)
               end
               };
            end;

            if x['type'] == 'hysteria' or x['type'] == 'hysteria2' then
               #hysteria  hysteria2
               threads << Thread.new{
               #hysteria_up
               if x.key?('up') then
                  hysteria_up = uci_set + 'hysteria_up=\"' + x['up'].to_s + '\"'
                  system(hysteria_up)
               end
               };

               #hysteria  hysteria2
               threads << Thread.new{
               #hysteria_down
               if x.key?('down') then
                  hysteria_down = uci_set + 'hysteria_down=\"' + x['down'].to_s + '\"'
                  system(hysteria_down)
               end
               };

               #hysteria  hysteria2
               threads << Thread.new{
               #skip-cert-verify
               if x.key?('skip-cert-verify') then
                  skip_cert_verify = uci_set + 'skip_cert_verify=\"' + x['skip-cert-verify'].to_s + '\"'
                  system(skip_cert_verify)
               end
               };

               #hysteria  hysteria2
               threads << Thread.new{
               #sni
               if x.key?('sni') then
                  sni = uci_set + 'sni=\"' + x['sni'].to_s + '\"'
                  system(sni)
               end
               };

               #hysteria  hysteria2
               threads << Thread.new{
               #alpn
               if x.key?('alpn') then
                  cmd = uci_del + 'hysteria_alpn >/dev/null 2>&1'
                  system(cmd)
                  if x['alpn'].class.to_s != 'Array' then
                     alpn = uci_add + 'hysteria_alpn=\"' + x['alpn'].to_s + '\"'
                     system(alpn)
                  else
                     x['alpn'].each{
                     |x|
                        alpn = uci_add + 'hysteria_alpn=\"' + x.to_s + '\"'
                        system(alpn)
                     }
                  end
               end;
               };

               #hysteria
               threads << Thread.new{
               #recv_window_conn
               if x.key?('recv-window-conn') then
                  recv_window_conn = uci_set + 'recv_window_conn=\"' + x['recv-window-conn'].to_s + '\"'
                  system(recv_window_conn)
               end
               };

               #hysteria
               threads << Thread.new{
               #recv_window
               if x.key?('recv-window') then
                  recv_window = uci_set + 'recv_window=\"' + x['recv-window'].to_s + '\"'
                  system(recv_window)
               end
               };

               #hysteria  hysteria2
               threads << Thread.new{
               #hysteria_obfs
               if x.key?('obfs') then
                  hysteria_obfs = uci_set + 'hysteria_obfs=\"' + x['obfs'].to_s + '\"'
                  system(hysteria_obfs)
               end
               };

               #hysteria  hysteria2
               threads << Thread.new{
               #hysteria_obfs_password
               if x.key?('obfs-password') then
                  hysteria_obfs_password = uci_set + 'hysteria_obfs_password=\"' + x['obfs-password'].to_s + '\"'
                  system(hysteria_obfs_password)
               end
               };

               #hysteria
               threads << Thread.new{
               #hysteria_auth
               if x.key?('auth') then
                  hysteria_auth = uci_set + 'hysteria_auth=\"' + x['auth'].to_s + '\"'
                  system(hysteria_auth)
               end
               };

               #hysteria
               threads << Thread.new{
               #hysteria_auth_str
               if x.key?('auth-str') then
                  hysteria_auth_str = uci_set + 'hysteria_auth_str=\"' + x['auth-str'].to_s + '\"'
                  system(hysteria_auth_str)
               end
               };

               #hysteria  hysteria2
               threads << Thread.new{
               #hysteria_ca
               if x.key?('ca') then
                  hysteria_ca = uci_set + 'hysteria_ca=\"' + x['ca'].to_s + '\"'
                  system(hysteria_ca)
               end
               };

               #hysteria  hysteria2
               threads << Thread.new{
               #hysteria_ca_str
               if x.key?('ca-str') then
                  hysteria_ca_str = uci_set + 'hysteria_ca_str=\"' + x['ca-str'].to_s + '\"'
                  system(hysteria_ca_str)
               end
               };

               #hysteria
               threads << Thread.new{
               #disable_mtu_discovery
               if x.key?('disable-mtu-discovery') then
                  disable_mtu_discovery = uci_set + 'disable_mtu_discovery=\"' + x['disable-mtu-discovery'].to_s + '\"'
                  system(disable_mtu_discovery)
               end
               };

               #hysteria
               threads << Thread.new{
               #fast_open
               if x.key?('fast-open') then
                  fast_open = uci_set + 'fast_open=\"' + x['fast-open'].to_s + '\"'
                  system(fast_open)
               end
               };

               #hysteria  hysteria2
               threads << Thread.new{
               #fingerprint
               if x.key?('fingerprint') then
                  fingerprint = uci_set + 'fingerprint=\"' + x['fingerprint'].to_s + '\"'
                  system(fingerprint)
               end
               };

               #hysteria  hysteria2
               threads << Thread.new{
               #ports
               if x.key?('ports') then
                  ports = uci_set + 'ports=\"' + x['ports'].to_s + '\"'
                  system(ports)
               end
               };

               #hysteria  hysteria2
               threads << Thread.new{
               #hop-interval
               if x.key?('hop-interval') then
                  hop_interval = uci_set + 'hop_interval=\"' + x['hop-interval'].to_s + '\"'
                  system(hop_interval)
               end
               };
            end;

            if x['type'] == 'vless' then
               threads << Thread.new{
               #uuid
               if x.key?('uuid') then
                  uuid = uci_set + 'uuid=\"' + x['uuid'].to_s + '\"'
                  system(uuid)
               end
               };
               
               threads << Thread.new{
               #tls
               if x.key?('tls') then
                  tls = uci_set + 'tls=\"' + x['tls'].to_s + '\"'
                  system(tls)
               end
               };
               
               threads << Thread.new{
               #skip-cert-verify
               if x.key?('skip-cert-verify') then
                  skip_cert_verify = uci_set + 'skip_cert_verify=\"' + x['skip-cert-verify'].to_s + '\"'
                  system(skip_cert_verify)
               end
               };
               
               threads << Thread.new{
               #servername
               if x.key?('servername') then
                  servername = uci_set + 'servername=\"' + x['servername'].to_s + '\"'
                  system(servername)
               end
               };
               
               threads << Thread.new{
               #flow
               if x.key?('flow') then
                  flow = uci_set + 'vless_flow=\"' + x['flow'].to_s + '\"'
                  system(flow)
               end
               };
               
               threads << Thread.new{
               #network:
               if x.key?('network') then
                  if x['network'].to_s == 'ws'
                     cmd = uci_set + 'obfs_vless=ws'
                     system(cmd)
                     #ws-opts-path:
                     if x.key?('ws-opts') then
                        if x['ws-opts'].key?('path') then
                           ws_opts_path = uci_set + 'ws_opts_path=\"' + x['ws-opts']['path'].to_s + '\"'
                           system(ws_opts_path)
                        end
                        #ws-opts-headers:
                        if x['ws-opts'].key?('headers') then
                           cmd = uci_del + 'ws_opts_headers >/dev/null 2>&1'
                           system(cmd)
                           x['ws-opts']['headers'].keys.each{
                           |v|
                              ws_opts_headers = uci_add + 'ws_opts_headers=\"' + v.to_s + ': '+ x['ws-opts']['headers'][v].to_s + '\"'
                              system(ws_opts_headers)
                           }
                        end
                     end
                  elsif x['network'].to_s == 'grpc'
                     #grpc-service-name
                     cmd = uci_set + 'obfs_vless=grpc'
                     system(cmd)
                     if x.key?('grpc-opts') then
                        if x['grpc-opts'].key?('grpc-service-name') then
                           grpc_service_name = uci_set + 'grpc_service_name=\"' + x['grpc-opts']['grpc-service-name'].to_s + '\"'
                           system(grpc_service_name)
                        end
                     end
                     if x.key?('reality-opts') then
                        if x['reality-opts'].key?('public-key') then
                           reality_public_key = uci_set + 'reality_public_key=\"' + x['reality-opts']['public-key'].to_s + '\"'
                           system(reality_public_key)
                        end
                        if x['reality-opts'].key?('short-id') then
                           reality_short_id = uci_set + 'reality_short_id=\"' + x['reality-opts']['short-id'].to_s + '\"'
                           system(reality_short_id)
                        end
                     end
                  elsif x['network'].to_s == 'tcp'
                     cmd = uci_set + 'obfs_vless=tcp'
                     system(cmd)
                     if x.key?('reality-opts') then
                        if x['reality-opts'].key?('public-key') then
                           reality_public_key = uci_set + 'reality_public_key=\"' + x['reality-opts']['public-key'].to_s + '\"'
                           system(reality_public_key)
                        end
                        if x['reality-opts'].key?('short-id') then
                           reality_short_id = uci_set + 'reality_short_id=\"' + x['reality-opts']['short-id'].to_s + '\"'
                           system(reality_short_id)
                        end
                     end
                  end
               end
               };

               threads << Thread.new{
               #xudp
               if x.key?('xudp') then
                  xudp = uci_set + 'xudp=\"' + x['xudp'].to_s + '\"'
                  system(xudp)
               end
               };

               threads << Thread.new{
               #packet-addr
               if x.key?('packet-addr') then
                  packet_addr = uci_set + 'packet_addr=\"' + x['packet-addr'].to_s + '\"'
                  system(packet_addr)
               end
               };

               threads << Thread.new{
               #packet_encoding
               if x.key?('packet-encoding') then
                  packet_encoding = uci_set + 'packet_encoding=\"' + x['packet-encoding'].to_s + '\"'
                  system(packet_encoding)
               end
               };

               threads << Thread.new{
               #fingerprint
               if x.key?('fingerprint') then
                  fingerprint = uci_set + 'fingerprint=\"' + x['fingerprint'].to_s + '\"'
                  system(fingerprint)
               end
               };

               threads << Thread.new{
               #client_fingerprint
               if x.key?('client-fingerprint') then
                  client_fingerprint = uci_set + 'client_fingerprint=\"' + x['client-fingerprint'].to_s + '\"'
                  system(client_fingerprint)
               end
               };
            end;

            if x['type'] == 'snell' then
               threads << Thread.new{
               if x.key?('obfs-opts') then
                  if x['obfs-opts'].key?('mode') then
                     mode = uci_set + 'obfs_snell=\"' + x['obfs-opts']['mode'].to_s + '\"'
                     system(mode)
                  else
                     cmd = uci_set + 'obfs_snell=none'
                     system(cmd)
                  end
                  if x['obfs-opts'].key?('host') then
                     host = uci_set + 'host=\"' + x['obfs-opts']['host'].to_s + '\"'
                     system(host)
                  end
               end
               };
               
               threads << Thread.new{
               if x.key?('psk') then
                  psk = uci_set + 'psk=\"' + x['psk'].to_s + '\"'
                  system(psk)
               end
               };
               
               threads << Thread.new{
               if x.key?('version') then
                  snell_version = uci_set + 'snell_version=\"' + x['version'].to_s + '\"'
                  system(snell_version)
               end
               };
            end;

            if x['type'] == 'socks5' or x['type'] == 'http' then
               threads << Thread.new{
               if x.key?('username') then
                  username = uci_set + 'auth_name=\"' + x['username'].to_s + '\"'
                  system(username)
               end
               };
               
               threads << Thread.new{
               if x.key?('password') then
                  password = uci_set + 'auth_pass=\"' + x['password'].to_s + '\"'
                  system(password)
               end
               };
               
               threads << Thread.new{
               #tls
               if x.key?('tls') then
                  tls = uci_set + 'tls=\"' + x['tls'].to_s + '\"'
                  system(tls)
               end
               };
               
               threads << Thread.new{
               #skip-cert-verify
               if x.key?('skip-cert-verify') then
                  skip_cert_verify = uci_set + 'skip_cert_verify=\"' + x['skip-cert-verify'].to_s + '\"'
                  system(skip_cert_verify)
               end
               };

               threads << Thread.new{
               #http-headers:
               if x.key?('headers') then
                  cmd = uci_del + 'http_headers >/dev/null 2>&1'
                  system(cmd)
                  x['headers'].keys.each{
                  |v|
                     http_headers = uci_add + 'http_headers=\"' + v.to_s + ': '+ x['headers'][v].to_s + '\"'
                     system(http_headers)
                  }
               end
               };

               threads << Thread.new{
               #fingerprint
               if x.key?('fingerprint') then
                  fingerprint = uci_set + 'fingerprint=\"' + x['fingerprint'].to_s + '\"'
                  system(fingerprint)
               end
               };
            else
               threads << Thread.new{
               if x.key?('password') then
                  password = uci_set + 'password=\"' + x['password'].to_s + '\"'
                  system(password)
               end
               };
            end;
            if x['type'] == 'http' or x['type'] == 'trojan' then
               threads << Thread.new{
               if x.key?('sni') then
                  sni = uci_set + 'sni=\"' + x['sni'].to_s + '\"'
                  system(sni)
               end
               };
            end;
            if x['type'] == 'trojan' then
               threads << Thread.new{
               #alpn
               if x.key?('alpn') then
                  alpn = uci_del + 'alpn >/dev/null 2>&1'
                  system(alpn)
               x['alpn'].each{
               |x|
                  alpn = uci_add + 'alpn=\"' + x.to_s + '\"'
                  system(alpn)
               }
               end
               };
               
               threads << Thread.new{
               #grpc-service-name
               if x.key?('grpc-opts') then
                  cmd = uci_set + 'obfs_trojan=grpc'
                  system(cmd)
                  if x['grpc-opts'].key?('grpc-service-name') then
                     grpc_service_name = uci_set + 'grpc_service_name=\"' + x['grpc-opts']['grpc-service-name'].to_s + '\"'
                     system(grpc_service_name)
                  end
               end
               };
               
               threads << Thread.new{
               if x.key?('ws-opts') then
                  cmd = uci_set + 'obfs_trojan=ws'
                  system(cmd)
                  #trojan_ws_path
                  if x['ws-opts'].key?('path') then
                     trojan_ws_path = uci_set + 'trojan_ws_path=\"' + x['ws-opts']['path'].to_s + '\"'
                     system(trojan_ws_path)
                  end
                  #trojan_ws_headers
                  if x['ws-opts'].key?('headers') then
                     cmd = uci_del + 'trojan_ws_headers >/dev/null 2>&1'
                     system(cmd)
                     x['ws-opts']['headers'].keys.each{
                     |v|
                        trojan_ws_headers = uci_add + 'trojan_ws_headers=\"' + v.to_s + ': '+ x['ws-opts']['headers'][v].to_s + '\"'
                        system(trojan_ws_headers)
                     }
                  end
               end
               };
               
               threads << Thread.new{
               #skip-cert-verify
               if x.key?('skip-cert-verify') then
                  skip_cert_verify = uci_set + 'skip_cert_verify=\"' + x['skip-cert-verify'].to_s + '\"'
                  system(skip_cert_verify)
               end
               };

               threads << Thread.new{
               #fingerprint
               if x.key?('fingerprint') then
                  fingerprint = uci_set + 'fingerprint=\"' + x['fingerprint'].to_s + '\"'
                  system(fingerprint)
               end
               };

               threads << Thread.new{
               #client_fingerprint
               if x.key?('client-fingerprint') then
                  client_fingerprint = uci_set + 'client_fingerprint=\"' + x['client-fingerprint'].to_s + '\"'
                  system(client_fingerprint)
               end
               };
            end;

            #加入策略组
            threads << Thread.new{
               #加入策略组
               if '$servers_if_update' == '1' and '$config_group_exist' == '1' and '$servers_update' == '1' and server_num.empty? then
                  #新代理集且设置默认策略组时加入指定策略组
                  new_provider_groups = %x{uci get openclash.config.new_servers_group}.chomp.split(\"'\").map { |x| x.strip }.reject { |x| x.empty? };
                  new_provider_groups.each do |x|
                     uci = uci_add + 'groups=\"' + x + '\"'
                     system(uci)
                  end
               elsif '$servers_if_update' != '1' then
                  threads_gr = [];
                  cmd = uci_del + 'groups >/dev/null 2>&1';
                  system(cmd);
                  Value['proxy-groups'].each{
                  |z|
                     threads_gr << Thread.new{
                        if z.key?('proxies') then
                           z['proxies'].each{
                           |v|
                           if v == x['name'] then
                              uci_proxy = uci_add + 'groups=^\"' + z['name'] + '$\"'
                              system(uci_proxy)
                              break
                           end
                           }
                        end;
                     };
                  };
                  #relay
                  cmd = uci_del + 'relay_groups >/dev/null 2>&1';
                  system(cmd);
                  Value['proxy-groups'].each{
                  |z|
                     threads_gr << Thread.new{
                        if z['type'] == 'relay' and z.key?('proxies') then
                           z['proxies'].each{
                           |u|
                           if u == x['name'] then
                              uci_relay = uci_add + 'relay_groups=\"' + z['name'] + '#relay#' + z['proxies'].index(x['name']) + '\"'
                              system(uci_relay)
                              break
                           end
                           }
                        end;
                     };
                  };
                  threads_gr.each(&:join);
               end;
            };
            threads.each(&:join);
         rescue Exception => e
            YAML.LOG('Error: Resolve Proxies Failed,【${CONFIG_NAME} - '+ x['type'] + ' - ' + x['name'] + ': ' + e.message + '】');
         end;
      };
   end;
   threads_pr.each(&:join);
   system('uci -q commit openclash');
" 2>/dev/null >> $LOG_FILE

#删除订阅中已不存在的代理集
if [ "$servers_if_update" = "1" ]; then
   LOG_OUT "Deleting【$CONFIG_NAME】Proxy-providers That no Longer Exists in Subscription"
   sed -i '/#match#/d' "$match_provider" 2>/dev/null
   cat $match_provider 2>/dev/null|awk -F '.' '{print $1}' |sort -rn |while read line
   do
   if [ -z "$line" ]; then
         continue
      fi
      if [ "$(uci get openclash.@proxy-provider["$line"].manual)" = "0" ] && [ "$(uci get openclash.@proxy-provider["$line"].config)" = "$CONFIG_NAME" ]; then
         uci delete openclash.@proxy-provider["$line"] 2>/dev/null
      fi
   done
fi

#删除订阅中已不存在的节点
if [ "$servers_if_update" = "1" ]; then
     LOG_OUT "Deleting【$CONFIG_NAME】Proxies That no Longer Exists in Subscription"
     sed -i '/#match#/d' "$match_servers" 2>/dev/null
     cat $match_servers |awk -F '.' '{print $1}' |sort -rn |while read -r line
     do
        if [ -z "$line" ]; then
           continue
        fi
        if [ "$(uci -q get openclash.@servers["$line"].manual)" = "0" ] && [ "$(uci -q get openclash.@servers["$line"].config)" = "$CONFIG_NAME" ]; then
           uci -q delete openclash.@servers["$line"]
        fi
     done 2>/dev/null
fi

uci -q set openclash.config.servers_if_update=0
uci -q commit openclash
LOG_OUT "Config File【$CONFIG_NAME】Read Successful!"
SLOG_CLEAN
rm -rf /tmp/match_servers.list 2>/dev/null
rm -rf /tmp/match_provider.list 2>/dev/null
del_lock
