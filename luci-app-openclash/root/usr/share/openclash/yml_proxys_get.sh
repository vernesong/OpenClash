#!/bin/bash
. /lib/functions.sh
. /usr/share/openclash/log.sh
. /usr/share/openclash/uci.sh

CONFIG_FILE=$(uci_get_config "config_path")
CONFIG_NAME=$(echo "$CONFIG_FILE" |awk -F '/' '{print $5}' 2>/dev/null)
UPDATE_CONFIG_FILE=$1
UPDATE_CONFIG_NAME=$(echo "$UPDATE_CONFIG_FILE" |awk -F '/' '{print $5}' 2>/dev/null)
LOG_FILE="/tmp/openclash.log"

set_lock() {
   exec 875>"/tmp/lock/openclash_proxies_get.lock" 2>/dev/null
   flock -x 875 2>/dev/null
}

del_lock() {
   flock -u 875 2>/dev/null
   rm -rf "/tmp/lock/openclash_proxies_get.lock"
}

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

# The proxies and proxy-providers sections are imported by uci.rb, its field tables are
# the same ones the set direction uses.
ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e "
   require 'uci';
   failed = UCI.import_config('$CONFIG_FILE', '$CONFIG_NAME');
   if not failed.empty? then
      YAML.LOG_ERROR('Write Uci Config Failed,【' + failed.map{ |t, e| t.to_s + ' => ' + e.to_s }.join('; ') + '】');
   end;
" >> $LOG_FILE 2>&1

LOG_OUT "Config File【$CONFIG_NAME】Read Successful!"
del_lock
