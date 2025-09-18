#!/bin/sh
. /usr/share/openclash/ruby.sh
. /usr/share/openclash/uci.sh

CFG_FILE=$(uci_get_config "config_path")
UPDATE_CONFIG_FILE=$(uci_get_config "config_update_path")

if [ ! -z "$UPDATE_CONFIG_FILE" ]; then
   CFG_FILE="$UPDATE_CONFIG_FILE"
fi

if [ -z "$CFG_FILE" ]; then
   for file_name in /etc/openclash/config/*
   do
      if [ -f "$file_name" ]; then
         CFG_FILE=$file_name
         break
      fi
   done
fi

if [ -f "$CFG_FILE" ]; then
   rm -rf "/tmp/Proxy_Group" 2>/dev/null
   ruby_read_hash_arr "$CFG_FILE" "['proxy-groups']" "['name']" >/tmp/Proxy_Group 2>&1

   if [ -f "/tmp/Proxy_Group" ]; then
      echo 'DIRECT' >>/tmp/Proxy_Group
      echo 'REJECT' >>/tmp/Proxy_Group
      echo 'REJECT-DROP' >>/tmp/Proxy_Group
      echo 'PASS' >>/tmp/Proxy_Group
      echo 'GLOBAL' >>/tmp/Proxy_Group
   else
      return 1
   fi
else
   return 1
fi