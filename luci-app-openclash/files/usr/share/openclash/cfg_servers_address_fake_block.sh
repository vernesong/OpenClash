#!/bin/sh

#禁止多个实例
exec 9>"/tmp/${0##*/}.lock"
flock -x -n 9 || exit 0

en_mode=$(uci get openclash.config.en_mode 2>/dev/null)
if pidof clash >/dev/null && [ "$en_mode" = "fake-ip" ]; then
   rm -rf /tmp/dnsmasq.d/dnsmasq_openclash.conf >/dev/null 2>&1
   /usr/share/openclash/openclash_fake_block.sh 9>&-
   mkdir -p /tmp/dnsmasq.d
   ln -s /etc/openclash/dnsmasq_fake_block.conf /tmp/dnsmasq.d/dnsmasq_openclash.conf >/dev/null 2>&1
   /etc/init.d/dnsmasq restart >/dev/null 2>&1 9>&-
fi

flock -u 9
