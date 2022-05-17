#!/bin/bash
. /lib/functions.sh
. /usr/share/openclash/log.sh

SER_FAKE_FILTER_FILE="/tmp/dnsmasq.d/dnsmasq_openclash.conf"
en_mode=$(uci get openclash.config.en_mode 2>/dev/null)

cfg_server_address()
{
	local section="$1"
   config_get "server" "$section" "server" ""
   
   IFIP=$(echo "$server" |grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" 2>/dev/null)
   IFIP6=$(echo "$server" |grep -E "^([\da-fA-F]{1,4}:){7}[\da-fA-F]{1,4}|:((:[\da−fA−F]1,4)1,6|:)|:((:[\da−fA−F]1,4)1,6|:)|^[\da-fA-F]{1,4}:((:[\da-fA-F]{1,4}){1,5}|:)|([\da−fA−F]1,4:)2((:[\da−fA−F]1,4)1,4|:)|([\da−fA−F]1,4:)2((:[\da−fA−F]1,4)1,4|:)|^([\da-fA-F]{1,4}:){3}((:[\da-fA-F]{1,4}){1,3}|:)|([\da−fA−F]1,4:)4((:[\da−fA−F]1,4)1,2|:)|([\da−fA−F]1,4:)4((:[\da−fA−F]1,4)1,2|:)|^([\da-fA-F]{1,4}:){5}:([\da-fA-F]{1,4})?|([\da−fA−F]1,4:)6:|([\da−fA−F]1,4:)6:" 2>/dev/null)
   if [ -z "$IFIP" ] && [ -z "$IFIP6" ] && [ -n "$server" ] && [ -z "$(grep "/$server/" "$SER_FAKE_FILTER_FILE" 2>/dev/null)" ]; then
      echo "server=/$server/$custom_domain_dns_server" >> "$SER_FAKE_FILTER_FILE"
   else
      return
   fi
}

#Fake下正确检测节点延迟及获取真实地址
if [ -z "$(echo "$en_mode" |grep "redir-host")" ]; then
   rm -rf "$SER_FAKE_FILTER_FILE" 2>/dev/null
   mkdir -p /tmp/dnsmasq.d
   custom_domain_dns_server=$(uci get openclash.config.custom_domain_dns_server 2>/dev/null)
      [ -z "$custom_domain_dns_server" ] && {
         custom_domain_dns_server="114.114.114.114"
      }
   config_load "openclash"
   config_foreach cfg_server_address "servers"
fi