#!/bin/bash
. /lib/functions.sh
. /usr/share/openclash/ruby.sh
. /usr/share/openclash/openclash_ps.sh
. /usr/share/openclash/log.sh
. /usr/share/openclash/openclash_curl.sh
. /usr/share/openclash/uci.sh

# One global lock: an update runs Ruby checks, core validation and the firewall/DNS
# fallback, concurrent runs would multiply peak memory.
set_lock() {
   mkdir -p /tmp/lock
   exec 889>"/tmp/lock/openclash_subs.lock" 2>/dev/null
   flock -x 889 2>/dev/null
}

del_lock() {
   flock -u 889 2>/dev/null
}

update_interval=0
[ "$2" = "loop" ] && update_interval="$3"
case "$update_interval" in
   ''|*[!0-9]*) update_interval=0 ;;
esac

subscribe_update_due()
{
   local now last
   now=$(date +%s)
   last=$(cat "$update_state" 2>/dev/null)
   case "$last" in
      ''|*[!0-9]*) last=0 ;;
   esac
   [ $((now - last)) -ge $((update_interval * 60)) ]
}
if [ "$update_interval" -gt 0 ] && [ -n "$1" ]; then
   update_state="/tmp/openclash_cfg_update_$(printf '%s' "$1" | md5sum | cut -c1-8)"
   subscribe_update_due || exit 0
   # loop jobs queue so a scheduled refresh is not dropped when another one runs
   set_lock
   # another job may have finished this subscription while this one was waiting
   if ! subscribe_update_due; then
      del_lock
      exit 0
   fi
else
   set_lock
fi

LOGTIME=$(echo $(date "+%Y-%m-%d %H:%M:%S"))
LOG_FILE="/tmp/openclash.log"
CRON_FILE="/etc/crontabs/root"
CONFIG_PATH=$(uci_get_config "config_path")
router_self_proxy=$(uci_get_config "router_self_proxy" || echo 1)
FW4=$(command -v fw4)
CLASH="/etc/openclash/clash"
CLASH_CONFIG="/etc/openclash"
restart=0
only_download=0
norestart=0
exit_code=0
[ "$2" = "norestart" ] && norestart=1

inc_job_counter

urlencode() {
   if [ "$#" -eq 1 ]; then
      echo "$(/usr/share/openclash/openclash_urlencode.lua "$1")"
   fi
}

kill_streaming_unlock() {
   streaming_unlock_pids=$(unify_ps_pids "openclash_streaming_unlock.lua")
   for streaming_unlock_pid in $streaming_unlock_pids; do
      kill -9 "$streaming_unlock_pid" >/dev/null 2>&1
   done >/dev/null 2>&1
}

config_test()
{
   if [ -f "$CLASH" ]; then
      LOG_OUT "Config File Download Successful, Test If There is Any Errors..."
      local test_status
      test_info=$("$CLASH" -t -d "$CLASH_CONFIG" -f "$CFG_FILE" -age-secret-key "$SECRET_KEY" 2>&1)
      test_status=$?
      local IFS=$'\n'
      for i in $test_info; do
         if [ -n "$(echo "$i" |grep "configuration file")" ]; then
            local info=$(echo "$i" |sed "s# ${CFG_FILE} #【${name}】#g")
            LOG_OUT "$info"
         else
            echo "$i" >> "$LOG_FILE"
         fi
      done
      if [ "$test_status" -ne 0 ] || [ -n "$(echo "$test_info" |grep "test failed")" ]; then
         LOG_ERROR "Subscription failed core validation; existing configuration was kept"
         return 1
      fi
   fi
   return 0
}

yaml_sub_validate()
{
   local status
   status=$(ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e 'puts YAML.subscription_status(ARGV[0])' "$CFG_FILE" 2>/dev/null)
   if [ $? -ne 0 ]; then
      status="UNAVAILABLE"
   fi
   case "$status" in
      OK) return 0 ;;
      EMPTY) LOG_ERROR "Subscription response is empty; existing configuration was kept" ;;
      INVALID) LOG_ERROR "Subscription is not a valid Clash configuration; existing configuration was kept" ;;
      NO_PROXIES) LOG_ERROR "Subscription has no proxies or proxy providers; existing configuration was kept" ;;
      *)
         # Ruby unavailable: install the download without custom overwrite instead of failing closed
         LOG_ERROR "Ruby Works Abnormally, Please Check The Ruby Library Depends!"
         only_download=1
         return 0 ;;
   esac
   return 1
}

config_download()
{
local DEFER_ETAG_SAVE=1
LOG_TIP "Config File【$name】Downloading User-Agent【$sub_ua】..."
if [ -n "$sub_headers" ]; then
   LOG_TIP "Config File【$name】Custom Headers【$(echo "$sub_headers" | tr '\n' ',' | sed 's/,$//')】..."
fi
if [ -n "$subscribe_url_param" ] && [ -n "$c_address" ]; then
   LOG_INFO "Config File【$name】Downloading URL【$c_address$subscribe_url_param】..."
   DOWNLOAD_URL="${c_address}${subscribe_url_param}"
fi
if [ -z "$DOWNLOAD_URL" ]; then
   LOG_INFO "Config File【$name】Downloading URL【$subscribe_url】..."
   DOWNLOAD_URL="${subscribe_url}"
fi
DOWNLOAD_PARAM="$sub_ua"
DOWNLOAD_FILE_CURL "$DOWNLOAD_URL" "$CFG_FILE" "$CONFIG_FILE" "$DOWNLOAD_PARAM" "$SECRET_KEY" "$sub_headers"
DOWNLOAD_RESULT=$?
}

config_cus_up()
{
   if [ -z "$subscribe_url_param" ]; then
      if [ -n "$key_match_param" ] || [ -n "$key_ex_match_param" ]; then
         LOG_OUT "Config File【$name】Start Picking Nodes..."
         ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e "
         begin
            threads = [];
            Value = YAML.load_file('$CFG_FILE');
            if Value.has_key?('proxies') and not Value['proxies'].to_a.empty? then
               Value['proxies'].reverse.each{
               |x|
                  if not '$key_match_param'.empty? then
                     threads << YAML::Inline.new {
                        if not /$key_match_param/i =~ x['name'] then
                           Value['proxies'].delete(x)
                           Value['proxy-groups'].each{
                              |g|
                              g['proxies'].reverse.each{
                                 |p|
                                 if p == x['name'] then
                                    g['proxies'].delete(p)
                                 end;
                              };
                           };
                        end;
                     };
                  end;
                  if not '$key_ex_match_param'.empty? then
                     threads << YAML::Inline.new {
                        if /$key_ex_match_param/i =~ x['name'] then
                           if Value['proxies'].include?(x) then
                              Value['proxies'].delete(x)
                              Value['proxy-groups'].each{
                                 |g|
                                 g['proxies'].reverse.each{
                                    |p|
                                    if p == x['name'] then
                                       g['proxies'].delete(p)
                                    end;
                                 };
                              };
                           end;
                        end;
                     };
                  end;
               };
            end;
            if Value.key?('proxy-providers') and not Value['proxy-providers'].nil? then
               Value['proxy-providers'].values.each do
                  |i|
                  threads << YAML::Inline.new {
                     if not '$key_match_param'.empty? then
                        i['filter'] = '(?i)$key_match_param';
                     end;
                     if not '$key_ex_match_param'.empty? then
                        i['exclude-filter'] = '(?i)$key_ex_match_param';
                     end;
                  };
               end;
            end;
            threads.each(&:join);
         rescue Exception => e
            YAML.LOG_ERROR('Filter Proxies Failed,【' + e.message + '】');
         ensure
            begin
               YAML.dump(Value, '$CFG_FILE');
            rescue Exception => e
               YAML.LOG_ERROR('Write file failed:【%s】' % [e.message])
            end
         end" 2>/dev/null >> $LOG_FILE
      fi
   fi
}

config_su_check()
{
   sed -i 's/!<str> /!!str /g' "$CFG_FILE" >/dev/null 2>&1
   if [ "$only_download" -eq 0 ]; then
      local before_cus_up
      before_cus_up=$(md5sum "$CFG_FILE" | cut -d' ' -f1)
      config_cus_up
      # Re-validate the customized file only when config_cus_up changed it
      if [ "$(md5sum "$CFG_FILE" | cut -d' ' -f1)" != "$before_cus_up" ] && ! yaml_sub_validate; then
         config_error
         return
      fi
   fi
   LOG_OUT "Config File Test Successful, Check If There is Any Update..."
   if [ -f "$CONFIG_FILE" ]; then
      cmp -s "$CONFIG_FILE" "$CFG_FILE"
      if [ "$?" -ne 0 ]; then
         LOG_OUT "Config File【$name】Are Updates, Start Replacing..."
      else
         LOG_OUT "Config File【$name】No Change, Do Nothing!"
         [ -n "$NEW_ETAG" ] && SAVE_ETAG_TO_CACHE "$DOWNLOAD_URL" "$NEW_ETAG" "$CONFIG_FILE"
         rm -rf "$CFG_FILE"
         return
      fi
   else
      LOG_OUT "Config File【$name】Download Successful, Start To Create..."
   fi
   # Same-directory temp keeps the replacement atomic and preserves the file mode
   local temporary="${CONFIG_FILE}.tmp.$$"
   if ! cp "$CFG_FILE" "$temporary" || ! mv -f "$temporary" "$CONFIG_FILE"; then
      rm -f "$temporary"
      LOG_ERROR "Unable to save subscription; existing configuration was kept"
      config_error
      return
   fi
   rm -f "$CFG_FILE"
   [ -n "$NEW_ETAG" ] && SAVE_ETAG_TO_CACHE "$DOWNLOAD_URL" "$NEW_ETAG" "$CONFIG_FILE"
   LOG_OUT "Config File【$name】Update Successful!"
   if [ -z "$CONFIG_PATH" ]; then
      uci -q set openclash.config.config_path="$CONFIG_FILE"
      uci commit openclash
   fi
   if [ "$CONFIG_FILE" == "$CONFIG_PATH" ] && [ "$norestart" -eq 0 ]; then
      restart=1
   fi
}

config_error()
{
   LOG_ERROR "【$name】Subscription update failed; existing configuration was kept"
   rm -rf "$CFG_FILE" 2>/dev/null
   exit_code=1
}

# procd.sh takes its own service lock when sourced, which breaks outside an init
# script, so the watchdog is signalled through ubus directly.
signal_watchdog()
{
   local signal
   signal=$(kill -l "$1" 2>/dev/null) || return 1
   ubus call service signal "{\"name\":\"openclash-watchdog\",\"signal\":$signal}" >/dev/null 2>&1
}

change_dns()
{
   if pidof clash >/dev/null; then
      /etc/init.d/openclash reload "restore" >/dev/null 2>&1
      signal_watchdog CONT
   fi
}

config_download_direct()
{
   if pidof clash >/dev/null && [ "$router_self_proxy" = 1 ]; then
      kill_streaming_unlock
      signal_watchdog STOP
      /etc/init.d/openclash reload "revert" >/dev/null 2>&1
      sleep 3

      config_download

      if [ "$DOWNLOAD_RESULT" -eq 0 ]; then
         if ! yaml_sub_validate || ! config_test; then
            change_dns
            config_error
         else
            change_dns
            config_su_check
         fi
      elif [ "$DOWNLOAD_RESULT" -eq 2 ]; then
         change_dns
         LOG_OUT "Config File【$name】No Change, Do Nothing!"
      else
         change_dns
         config_error
      fi
   else
      config_error
   fi
}

server_key_match()
{
   local key_match key_word

   if [ -n "$(echo "$1" |grep "^ \{0,\}$")" ] || [ -n "$(echo "$1" |grep "^\t\{0,\}$")" ]; then
      return
   fi

   if [ -n "$(echo "$1" |grep "&")" ]; then
      key_word=$(echo "$1" |sed 's/&/ /g')
      for k in $key_word
      do
         if [ -z "$k" ]; then
            continue
         fi
         k="(?=.*$k)"
         key_match="$key_match$k"
      done
      key_match="^($key_match).*"
   else
      if [ -n "$1" ]; then
         key_match="($1)"
      fi
   fi

   if [ "$2" = "keyword" ]; then
      if [ -z "$key_match_param" ]; then
         key_match_param="$key_match"
      else
         key_match_param="$key_match_param|$key_match"
      fi
   elif [ "$2" = "ex_keyword" ]; then
        if [ -z "$key_ex_match_param" ]; then
         key_ex_match_param="$key_match"
      else
         key_ex_match_param="$key_ex_match_param|$key_match"
      fi
   fi
}

convert_custom_param()
{
   if ! (echo "$1" | grep -qE "^\w+=.+$") then
      return
   fi
   local p_name="${1%%=*}" p_value="${1#*=}"
   if [ -z "$append_custom_params" ]; then
      append_custom_params="&${p_name}=$(urlencode "$p_value")"
   else
      append_custom_params="${append_custom_params}\`$(urlencode "$p_value")"
   fi
}

build_sub_headers()
{
   if [ -z "$sub_headers" ]; then
      sub_headers="$1"
   else
      sub_headers="$sub_headers
$1"
   fi
}

sub_info_get()
{
   local section="$1" subscribe_url template_path subscribe_url_param template_path_encode key_match_param key_ex_match_param c_address de_ex_keyword sub_ua sub_headers append_custom_params SECRET_KEY DOWNLOAD_URL DOWNLOAD_PARAM
   config_get "name" "$section" "name" "config"
   config_get "sub_convert" "$section" "sub_convert" "0"
   config_get "address" "$section" "address" ""
   config_get "keyword" "$section" "keyword" ""
   config_get "ex_keyword" "$section" "ex_keyword" ""
   config_get_bool "keyword_option" "$section" "keyword_option" "1"
   config_get "emoji" "$section" "emoji" ""
   config_get "udp" "$section" "udp" ""
   config_get "skip_cert_verify" "$section" "skip_cert_verify" ""
   config_get "sort" "$section" "sort" ""
   config_get "convert_address" "$section" "convert_address" "https://api.asailor.org/sub"
   config_get "template" "$section" "template" ""
   config_get "node_type" "$section" "node_type" ""
   config_get "rule_provider" "$section" "rule_provider" ""
   config_get "tfo" "$section" "tfo" ""
   config_get "tls13" "$section" "tls13" ""
   config_get "custom_template_url" "$section" "custom_template_url" ""
   config_get "de_ex_keyword" "$section" "de_ex_keyword" ""
   config_get "sub_ua" "$section" "sub_ua" "clash-verge/v2.4.5"
   config_list_foreach "$section" "sub_headers" build_sub_headers
   SECRET_KEY=$(uci_get_age_secret_keys "$name")

   CONFIG_FILE="/etc/openclash/config/$name.yaml"
   CFG_FILE="/tmp/$name.yaml"

   if [ -z "$address" ]; then
      return
   fi

   if [ "$udp" == "true" ]; then
      udp="&udp=true"
   else
      udp=""
   fi

   if [ "$rule_provider" == "true" ]; then
      rule_provider="&expand=false&classic=true"
   else
      rule_provider=""
   fi

   if [ "$tfo" == "true" ]; then
      tfo="&tfo=true"
   else
      tfo=""
   fi

   if [ "$tls13" == "true" ]; then
      tls13="&tls13=true"
   else
      tls13=""
   fi

   if [ -n "$2" ] && [ "$2" != "$CONFIG_FILE" ] && [ "$2" != "$name" ]; then
      return
   fi

   if [ "$keyword_option" -eq 1 ]; then
      if [ ! -z "$keyword" ] || [ ! -z "$ex_keyword" ]; then
         config_list_foreach "$section" "keyword" server_key_match "keyword"
         config_list_foreach "$section" "ex_keyword" server_key_match "ex_keyword"
      fi

      if [ -n "$de_ex_keyword" ]; then
         for i in $de_ex_keyword;
         do
            if [ -z "$key_ex_match_param" ]; then
               key_ex_match_param="($i)"
            else
               key_ex_match_param="$key_ex_match_param|($i)"
            fi
         done
      fi
   fi

   if [ "${sub_convert:-0}" -eq 0 ]; then
      subscribe_url=$address
   elif [ "${sub_convert:-0}" -eq 1 ] && [ -n "$template" ]; then
      while IFS= read -r line; do
         line=$(echo "$line" | tr -d '\r')
         subscribe_url=$([ -n "$subscribe_url" ] && echo "$subscribe_url|")$(urlencode "$line")
      done < <(echo "$address")
      if [ "$template" != "0" ]; then
         template_path=$(grep "^$template," /usr/share/openclash/res/sub_ini.list |awk -F ',' '{print $3}' 2>/dev/null)
      else
         template_path=$custom_template_url
      fi
      if [ -n "$template_path" ]; then
         config_list_foreach "$section" "custom_params" convert_custom_param
         template_path_encode=$(urlencode "$template_path")
         [ -n "$key_match_param" ] && key_match_param="$(urlencode "(?i)$key_match_param")"
         [ -n "$key_ex_match_param" ] && key_ex_match_param="$(urlencode "(?i)$key_ex_match_param")"
         subscribe_url_param="?target=clash&new_name=true&url=$subscribe_url&config=$template_path_encode&include=$key_match_param&exclude=$key_ex_match_param&emoji=$emoji&list=false&sort=$sort$udp&scv=$skip_cert_verify&append_type=$node_type&fdn=true$rule_provider$tfo$tls13$append_custom_params"
         c_address="$convert_address"
      else
         subscribe_url=$address
      fi
   else
      subscribe_url=$address
   fi

   LOG_OUT "Start Updating Config File【$name】..."

   config_download
   if [ "$DOWNLOAD_RESULT" -eq 0 ]; then
      if ! yaml_sub_validate || ! config_test; then
         LOG_ERROR "Config File【$name】Subscribed Failed, Trying to Download Without Agent..."
         config_download_direct
      else
         config_su_check
      fi
   elif [ "$DOWNLOAD_RESULT" -eq 2 ]; then
      LOG_OUT "Config File【$name】No Change, Do Nothing!"
   else
      LOG_ERROR "Config File【$name】Subscribed Failed, Trying to Download Without Agent..."
      config_download_direct
   fi
}

#分别获取订阅信息进行处理
config_load "openclash"
config_foreach sub_info_get "config_subscribe" "$1"
dec_job_counter_and_restart "$restart"
# the interval counts from the end of this update
[ "$update_interval" -gt 0 ] && [ -n "$1" ] && date +%s > "$update_state"
del_lock

# the caller (luci) judges the update result by this exit code
exit "$exit_code"
