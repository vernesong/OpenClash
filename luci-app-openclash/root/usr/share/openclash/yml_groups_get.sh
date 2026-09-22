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
   rm -rf "/tmp/lock/openclash_groups_get.lock"
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

# The proxy-groups block is imported by uci.rb, its field table is the one the set
# direction reads back.
ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e "
   require 'uci';
   failed = UCI.import_groups('$CONFIG_FILE', '$CONFIG_NAME');
   if not failed.empty? then
      YAML.LOG_ERROR('Write Uci Config Failed,【' + failed.map{ |t, e| t.to_s + ' => ' + e.to_s }.join('; ') + '】');
   end;
" >> $LOG_FILE 2>&1

/usr/share/openclash/yml_proxys_get.sh "$CONFIG_FILE" >/dev/null 2>&1
del_lock
