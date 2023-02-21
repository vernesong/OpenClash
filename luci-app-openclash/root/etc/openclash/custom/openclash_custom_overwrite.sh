#!/bin/sh
. /usr/share/openclash/ruby.sh
. /usr/share/openclash/log.sh
. /lib/functions.sh

# This script is called by /etc/init.d/openclash
# Add your custom overwrite scripts here, they will be take effict after the OpenClash own srcipts

LOG_OUT "Tip: Start Running Custom Overwrite Scripts..."
LOGTIME=$(echo $(date "+%Y-%m-%d %H:%M:%S"))
LOG_FILE="/tmp/openclash.log"
CONFIG_FILE="$1" #config path

#ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e "
#   begin
#      Value = YAML.load_file('$CONFIG_FILE');
#   rescue Exception => e
#      puts '${LOGTIME} Error: Load File Failed,【' + e.message + '】';
#   end;

    #General
#   begin
#   Thread.new{
#      Value['redir-port']=7892;
#      Value['tproxy-port']=7895;
#      Value['port']=7890;
#      Value['socks-port']=7891;
#      Value['mixed-port']=7893;
#   }.join;
#   rescue Exception => e
#      puts '${LOGTIME} Error: Set General Failed,【' + e.message + '】';
#   ensure
#      File.open('$CONFIG_FILE','w') {|f| YAML.dump(Value, f)};
#   end" 2>/dev/null >> $LOG_FILE

exit 0