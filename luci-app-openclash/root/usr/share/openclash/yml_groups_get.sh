#!/bin/bash
. /lib/functions.sh
. /usr/share/openclash/log.sh
. /usr/share/openclash/uci.sh

set_lock() {
   exec 876>"/tmp/lock/openclash_groups_get.lock" 2>/dev/null
   flock -x 876 2>/dev/null
}

del_lock() {
   flock -u 876 2>/dev/null
}

CONFIG_FILE=$(uci_get_config "config_path")
CONFIG_NAME=$(echo "$CONFIG_FILE" |awk -F '/' '{print $5}' 2>/dev/null)
UPDATE_CONFIG_FILE=$1
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

if [ ! -s "$CONFIG_FILE" ]; then
   del_lock
   exit 0
fi

LOG_OUT "Start Getting【$CONFIG_NAME】Groups Setting..."
LOG_OUT "Deleting Old Configuration..."

del_options()
{
   local section="$1"
   local config
   config_get "config" "$section" "config" ""

   if [ "$config" = "$CONFIG_NAME" ]; then
      uci -q delete openclash."$section"
   fi
}

config_load "openclash"
config_foreach del_options "groups" 
config_foreach del_options "servers"
config_foreach del_options "proxy-provider"
uci -q commit openclash

ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e "
   begin
      Value = YAML.load_file('$CONFIG_FILE');
   rescue Exception => e
      YAML.LOG_ERROR('Load File Failed,【' + e.message + '】');
   end;

   threads_g = [];
   threadsp = [];
   threads_uci = [];
   uci_commands = [];
   uci_name_tmp = [];
   max_threads = 30
   queue = SizedQueue.new(max_threads)

   if not Value.key?('proxy-groups') or Value['proxy-groups'].nil? then
      proxy-groups = [];
   end;

   CONFIG_GROUP = (['DIRECT', 'REJECT', 'GLOBAL', 'REJECT-DROP', 'PASS', 'COMPATIBLE'] + (Value['proxy-groups']&.map { |x| x['name'] } || [])).uniq;
   Value['proxy-groups'].each_with_index do |x, index|
      uci_name_tmp << %x{uci -q add openclash groups 2>&1}.chomp
      queue.push(nil)
      threadsp << Thread.new {
      begin
         next unless x['name'] && x['type'];
         uci_set='set openclash.' + uci_name_tmp[index] + '.'
         uci_add='add_list openclash.' + uci_name_tmp[index] + '.'

         YAML.LOG('Start Getting【${CONFIG_NAME} - ' + x['type'].to_s + ' - ' + x['name'].to_s + '】Group Setting...');

         threads_g << Thread.new {
            #name
            if x.key?('name') then
               uci_commands << uci_set + 'name=\"' + x['name'].to_s + '\"'
            end;
         };

         threads_g << Thread.new {
            #type
            if x.key?('type') then
               uci_commands << uci_set + 'type=\"' + x['type'].to_s + '\"'
            end;
         };

         threads_g << Thread.new {
            #enabled
            uci_commands << uci_set + 'enabled=\"1\"'
            #config
            uci_commands << uci_set + 'config=\"' + '${CONFIG_NAME}' + '\"'
            #old_name
            uci_commands << uci_set + 'old_name=\"' + x['name'] + '\"'
         };

         threads_g << Thread.new {
            #strategy
            if x.key?('strategy') and x['type'] == 'load-balance' then
               uci_commands << uci_set + 'strategy=\"' + x['strategy'].to_s + '\"'
            end;
         };

         threads_g << Thread.new {
            #strategy-smart
            if x.key?('strategy') and x['type'] == 'smart' then
               uci_commands << uci_set + 'strategy_smart=\"' + x['strategy'].to_s + '\"'
            end;
         };

         threads_g << Thread.new {
            #uselightgbm
            if x.key?('uselightgbm') and x['type'] == 'smart' then
               uci_commands << uci_set + 'uselightgbm=\"' + x['uselightgbm'].to_s + '\"'
            end;
         };

         threads_g << Thread.new {
            #collectdata
            if x.key?('collectdata') and x['type'] == 'smart' then
               uci_commands << uci_set + 'collectdata=\"' + x['collectdata'].to_s + '\"'
            end;
         };

         threads_g << Thread.new {
            #policy_priority
            if x.key?('policy-priority') and x['type'] == 'smart' then
               uci_commands << uci_set + 'policy_priority=\"' + x['policy-priority'].to_s + '\"'
            end;
         };

         threads_g << Thread.new {
            #disable-udp
            if x.key?('disable-udp') then
               uci_commands << uci_set + 'disable_udp=\"' + x['disable-udp'].to_s + '\"'
            end;
         };

         threads_g << Thread.new {
            if x['type'] == 'url-test' or x['type'] == 'fallback' or x['type'] == 'load-balance' or x['type'] == 'smart' then
               #test_url
               if x.key?('url') then
                  uci_commands << uci_set + 'test_url=\"' + x['url'].to_s + '\"'
               end;

               #test_interval
               if x.key?('interval') then
                  uci_commands << uci_set + 'test_interval=\"' + x['interval'].to_s + '\"'
               end;

               #test_tolerance
               if x['type'] == 'url-test' then
                  if x.key?('tolerance') then
                     uci_commands << uci_set + 'tolerance=\"' + x['tolerance'].to_s + '\"'
                  end;
               end;
            end;
         };

         threads_g << Thread.new {
            #Policy Filter
            if x.key?('filter') then
               uci_commands << uci_set + 'policy_filter=\"' + x['filter'].to_s + '\"'
            end
         };

         threads_g << Thread.new {
            #interface-name
            if x.key?('interface-name') then
               uci_commands << uci_set + 'interface_name=\"' + x['interface-name'].to_s + '\"'
            end
          };

          threads_g << Thread.new {
            #routing-mark
            if x.key?('routing-mark') then
               uci_commands << uci_set + 'routing_mark=\"' + x['routing-mark'].to_s + '\"'
            end
          };

         threads_g << Thread.new {
            #other_group
            if x.key?('proxies') then 
               x['proxies'].each{
               |y|
                  if CONFIG_GROUP.include?(y) then
                     uci_commands << uci_add + 'other_group=\"^' + y.to_s + '$\"'
                  end
               }
            end
         };

         threads_g << Thread.new {
            #icon
            if x.key?('icon') then
               uci_commands << uci_set + 'icon=\"' + x['icon'].to_s + '\"'
            end
          };
         threads_g.each(&:join);
      rescue Exception => e
         YAML.LOG_ERROR('Resolve Groups Failed,【${CONFIG_NAME} - ' + x['type'] + ' - ' + x['name'] + ': ' + e.message + '】');
      ensure
         queue.pop
      end;
      };
   end;
   threadsp.each(&:join);
   batch_size = 30;
   (0...uci_commands.length).step(batch_size) do |i|
      threads_uci << Thread.new{
         IO.popen('uci -q batch', 'w') do |pipe|
            uci_commands[i, batch_size].each { |cmd| pipe.puts(cmd) }
         end
      };
   end;
   threads_uci.each(&:join);
   uci_name_tmp.each do |x|
      if x =~ /uci -q delete/ then
         system(x);
      end;
   end;
   system('uci -q commit openclash');
   system('rm -rf /tmp/yaml_other_group.yaml 2>/dev/null');
" 2>/dev/null >> $LOG_FILE

/usr/share/openclash/yml_proxys_get.sh "$CONFIG_FILE" >/dev/null 2>&1
del_lock
