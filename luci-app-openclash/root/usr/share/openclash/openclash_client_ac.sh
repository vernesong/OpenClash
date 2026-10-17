#!/bin/sh
# OpenClash client access control helper: set hot updates and neighbour probing
# usage: openclash_client_ac.sh <black|white> <add|del|flush> [ip] [mac]
#        openclash_client_ac.sh probe <dev> <ip> <mac> [<dev> <ip> <mac> ...]
# exit: 0 ok, 1 invalid args, 3 sets missing (caller falls back to a firewall reload)

# the ping result is written back into the kernel neighbour state, which the page reads
if [ "$1" = "probe" ]; then
   shift
   while [ $# -ge 3 ]; do
      AC_DEV="$1"
      AC_IP="$2"
      AC_MAC="$3"
      shift 3
      case "$AC_IP" in *[!0-9.]*|"") continue ;; esac
      case "$AC_DEV" in *[!0-9A-Za-z_.-]*|"") continue ;; esac
      case "$AC_MAC" in *[!0-9a-f:]*|"") continue ;; esac
      (
         if ping -c 2 -W 1 "$AC_IP" >/dev/null 2>&1; then
            ip neigh replace "$AC_IP" dev "$AC_DEV" lladdr "$AC_MAC" nud reachable 2>/dev/null
         else
            ip neigh replace "$AC_IP" dev "$AC_DEV" lladdr "$AC_MAC" nud failed 2>/dev/null
         fi
      ) &
   done
   exit 0
fi

. /lib/functions.sh

AC_COLOR="$1"
AC_ACTION="$2"
AC_IP="$3"
AC_MAC="$4"

case "$AC_COLOR" in
   black|white) ;;
   *) echo "invalid color"; exit 1 ;;
esac

case "$AC_ACTION" in
   add|del)
      [ -z "$AC_IP" ] && [ -z "$AC_MAC" ] && { echo "nothing to do"; exit 1; }
      ;;
   flush) ;;
   *) echo "invalid action"; exit 1 ;;
esac

[ -n "$AC_MAC" ] && AC_MAC=$(echo "$AC_MAC" |tr 'A-Z' 'a-z')

if [ "$AC_ACTION" = "flush" ]; then
   if [ -n "$(command -v fw4)" ]; then
      nft flush set inet fw4 "lan_ac_${AC_COLOR}_ips" 2>/dev/null
      nft flush set inet fw4 "lan_ac_${AC_COLOR}_ipv6s" 2>/dev/null
      nft flush set inet fw4 "lan_ac_${AC_COLOR}_macs" 2>/dev/null
   else
      ipset -! flush "lan_ac_${AC_COLOR}_ips" 2>/dev/null
      ipset -! flush "lan_ac_${AC_COLOR}_ipv6s" 2>/dev/null
      ipset -! flush "lan_ac_${AC_COLOR}_macs" 2>/dev/null
   fi
   echo "OK"
   exit 0
fi

AC_MISSING=0

if [ -n "$(command -v fw4)" ]; then
   if [ -n "$AC_IP" ]; then
      if [ -z "$(nft list set inet fw4 "lan_ac_${AC_COLOR}_ips" 2>/dev/null)" ]; then
         AC_MISSING=1
      elif [ "$AC_ACTION" = "add" ]; then
         nft add element inet fw4 "lan_ac_${AC_COLOR}_ips" { "$AC_IP" } 2>/dev/null
      else
         nft delete element inet fw4 "lan_ac_${AC_COLOR}_ips" { "$AC_IP" } 2>/dev/null
      fi
   fi
   if [ -n "$AC_MAC" ]; then
      if [ -z "$(nft list set inet fw4 "lan_ac_${AC_COLOR}_macs" 2>/dev/null)" ]; then
         AC_MISSING=1
      elif [ "$AC_ACTION" = "add" ]; then
         nft add element inet fw4 "lan_ac_${AC_COLOR}_macs" { "$AC_MAC" } 2>/dev/null
      else
         nft delete element inet fw4 "lan_ac_${AC_COLOR}_macs" { "$AC_MAC" } 2>/dev/null
      fi
   fi
else
   if [ -n "$AC_IP" ]; then
      if [ -z "$(ipset list -n 2>/dev/null |grep -x "lan_ac_${AC_COLOR}_ips")" ]; then
         AC_MISSING=1
      elif [ "$AC_ACTION" = "add" ]; then
         ipset -! add "lan_ac_${AC_COLOR}_ips" "$AC_IP" 2>/dev/null
      else
         ipset -! del "lan_ac_${AC_COLOR}_ips" "$AC_IP" 2>/dev/null
      fi
   fi
   if [ -n "$AC_MAC" ]; then
      if [ -z "$(ipset list -n 2>/dev/null |grep -x "lan_ac_${AC_COLOR}_macs")" ]; then
         AC_MISSING=1
      elif [ "$AC_ACTION" = "add" ]; then
         ipset -! add "lan_ac_${AC_COLOR}_macs" "$AC_MAC" 2>/dev/null
      else
         ipset -! del "lan_ac_${AC_COLOR}_macs" "$AC_MAC" 2>/dev/null
      fi
   fi
fi

if [ "$AC_MISSING" = "1" ]; then
   echo "MISSING"
   exit 3
fi

echo "OK"
exit 0
