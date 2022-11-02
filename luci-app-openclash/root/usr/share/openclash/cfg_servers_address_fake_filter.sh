#!/bin/sh

START_LOG="/tmp/openclash_start.log"
en_mode=$(uci -q get openclash.config.en_mode)

if pidof clash >/dev/null && [ -z "$(echo "$en_mode" |grep "redir-host")" ]; then
   rm -rf /tmp/dnsmasq.d/dnsmasq_openclash.conf >/dev/null 2>&1
   /usr/share/openclash/openclash_server_fake_filter.sh
   if [ -s "/tmp/dnsmasq.d/dnsmasq_openclash.conf" ]; then
      /etc/init.d/dnsmasq restart >/dev/null 2>&1
   fi
   echo "" >$START_LOG
fi
