#!/bin/bash
. /lib/functions.sh
. /usr/share/openclash/log.sh
. /usr/share/openclash/uci.sh

set_lock() {
   exec 887>"/tmp/lock/openclash_groups_set.lock" 2>/dev/null
   flock -x 887 2>/dev/null
}

del_lock() {
   flock -u 887 2>/dev/null
   rm -rf "/tmp/lock/openclash_groups_set.lock"
}

set_lock
GROUP_FILE="/tmp/yaml_groups.yaml"
CFG_FILE="/etc/config/openclash"
CONFIG_FILE=$(uci_get_config "config_path")
CONFIG_NAME=$(echo "$CONFIG_FILE" |awk -F '/' '{print $5}' 2>/dev/null)
UPDATE_CONFIG_FILE=$1
UPDATE_CONFIG_NAME=$(echo "$UPDATE_CONFIG_FILE" |awk -F '/' '{print $5}' 2>/dev/null)

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

# Keep the ruby heap small, the group matching loop reads the whole package into memory
RUBY_GC_HEAP_GROWTH_FACTOR=1.1
RUBY_GC_HEAP_GROWTH_MAX_SLOTS=200000
RUBY_GC_MALLOC_LIMIT_MAX=67108864
export RUBY_GC_HEAP_GROWTH_FACTOR RUBY_GC_HEAP_GROWTH_MAX_SLOTS RUBY_GC_MALLOC_LIMIT_MAX

ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e "
   require 'uci';
   begin
      UCI.write_groups('$GROUP_FILE', '${CONFIG_NAME}');
   rescue ::Exception => e
      YAML.LOG_ERROR('Resolve Groups Failed,【${CONFIG_NAME} - ' + e.message + '】');
   end;
" 2>/dev/null >> $LOG_FILE

sed -i "s/#delete_//g" "$CONFIG_FILE" 2>/dev/null

/usr/share/openclash/yml_proxys_set.sh "$CONFIG_FILE" >/dev/null 2>&1
del_lock

