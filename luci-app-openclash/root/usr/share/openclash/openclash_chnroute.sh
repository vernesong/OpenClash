#!/bin/sh
. /usr/share/openclash/openclash_ps.sh
. /usr/share/openclash/log.sh
. /usr/share/openclash/openclash_curl.sh
. /usr/share/openclash/uci.sh

set_lock() {
   exec 879>"/tmp/lock/openclash_chn.lock" 2>/dev/null
   flock -x 879 2>/dev/null
}

del_lock() {
   flock -u 879 2>/dev/null
}

set_lock || exit 1
inc_job_counter

FW4=$(command -v fw4)
china_ip_route=$(uci_get_config "china_ip_route")
china_ip6_route=$(uci_get_config "china_ip6_route")
CHNR_CUSTOM_URL=$(uci_get_config "chnr_custom_url")
CHNR6_CUSTOM_URL=$(uci_get_config "chnr6_custom_url")
disable_udp_quic=$(uci_get_config "disable_udp_quic")
small_flash_memory=$(uci_get_config "small_flash_memory")
restart=0
result=0
DEFER_ETAG_SAVE=1

if [ "$small_flash_memory" != "1" ]; then
   chnr_path="/etc/openclash/china_ip_route.ipset"
   chnr6_path="/etc/openclash/china_ip6_route.ipset"
   mkdir -p /etc/openclash
else
   chnr_path="/tmp/etc/openclash/china_ip_route.ipset"
   chnr6_path="/tmp/etc/openclash/china_ip6_route.ipset"
   mkdir -p /tmp/etc/openclash
fi

update_chnroute() {
   local set_name="$1" family="$2" url="$3" target="$4" enabled="$5" label="$6"
   local raw="/tmp/${set_name}.txt" rules="/tmp/${set_name}.list" SKIP_ETAG=0
   if [ -n "$FW4" ]; then
      grep -q "^define ${set_name} =" "$target" 2>/dev/null || SKIP_ETAG=1
   else
      grep -q "^create ${set_name} " "$target" 2>/dev/null || SKIP_ETAG=1
   fi
   LOG_OUT "Start Downloading The $label Cidr List..."
   DOWNLOAD_FILE_CURL "$url" "$raw" "$target"
   case $? in
      2) LOG_OUT "Updated $label Cidr List No Change, Do Nothing..."; return 0 ;;
      0) ;;
      *) LOG_OUT "$label Cidr List Update Error, Please Try Again Later..."; return 1 ;;
   esac
   if ! awk -v name="$set_name" -v family="$family" -v nft="$FW4" '
      function valid_v6(ip, halves, fields, n, i, j, k, count) {
         n=split(ip, halves, /::/)
         if (n>2) return 0
         for (i=1; i<=n; i++) {
            if (!length(halves[i])) continue
            k=split(halves[i], fields, /:/)
            for (j=1; j<=k; j++) if (fields[j] !~ /^[0-9a-fA-F]+$/ || length(fields[j])>4) return 0
            count+=k
         }
         return n==2 ? count<8 : count==8
      }
      BEGIN {
         if (nft) print "define " name " = {"
         else print "create " name " hash:net family " family " hashsize 1024 maxelem 1000000"
      }
      { sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+#.*/, ""); sub(/[[:space:]]+$/, "") }
      /^#/ || !length { next }
      {
         if (split($0, parts, "/") != 2 || parts[2] !~ /^[0-9]+$/) exit 1
         if (family == "inet") {
            if (split(parts[1], octets, /\./) != 4 || parts[2]+0 > 32) exit 1
            for (i=1; i<=4; i++) if (octets[i] !~ /^[0-9]+$/ || octets[i]+0 > 255) exit 1
         } else if (!valid_v6(parts[1]) || parts[2]+0 > 128) exit 1
         count++
         if (nft) print "    " $0 ","
         else print "add " name " " $0
      }
      END {
         if (!count) exit 1
         if (nft) {
            print "}"
            type = family == "inet" ? "ipv4_addr" : "ipv6_addr"
            print "add set inet fw4 " name " { type " type "; flags interval; auto-merge; }"
            print "add element inet fw4 " name " $" name
         }
      }
   ' "$raw" >"$rules"; then
      LOG_OUT "$label Cidr List Download Failed: Content Invalid, Abort Update..."
      return 1
   fi
   install_downloaded_resource "$rules" "$target"
   case $? in
      0)
         if [ "${enabled:-0}" != 0 ] || [ "$disable_udp_quic" = 1 ]; then restart=1; fi
         LOG_OUT "$label Cidr List Update Successful!"
         ;;
      2) LOG_OUT "Updated $label Cidr List No Change, Do Nothing..." ;;
      *) LOG_OUT "$label Cidr List Update Error, Please Try Again Later..."; return 1 ;;
   esac
}

update_chnroute china_ip_route inet "${CHNR_CUSTOM_URL:-https://ispip.clang.cn/all_cn.txt}" "$chnr_path" "$china_ip_route" Chnroute || result=1
update_chnroute china_ip6_route inet6 "${CHNR6_CUSTOM_URL:-https://ispip.clang.cn/all_cn_ipv6.txt}" "$chnr6_path" "$china_ip6_route" Chnroute6 || result=1
rm -f /tmp/china_ip_route.txt /tmp/china_ip_route.list /tmp/china_ip6_route.txt /tmp/china_ip6_route.list

dec_job_counter_and_restart "$restart"
del_lock
exit "$result"
