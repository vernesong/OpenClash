#!/bin/sh
. /usr/share/openclash/ruby.sh
. /usr/share/openclash/log.sh
. /lib/functions.sh

# This script is called by /etc/init.d/openclash
# Add your custom overwrite scripts here, they will take effect after the OpenClash own scripts

LOG_TIP "Start Running Custom Overwrite Scripts..."
LOGTIME=$(echo $(date "+%Y-%m-%d %H:%M:%S"))
LOG_FILE="/tmp/openclash.log"
#Config Path
CONFIG_FILE="$1"

    #Arguments are parsed literally, \ ; and $( ) need no escaping; code arguments must pass the
    #AST whitelist (system/send/File./ENV, backticks and %x are rejected), quoted data and
    #plain values are not affected; use a single quoted argument for a literal dollar sign
    #Simple Demo:
    #Key Overwrite Demo
    #1--config path
    #2--key name
    #3--value
    #ruby_edit "$CONFIG_FILE" "['redir-port']" "7892"
    #ruby_edit "$CONFIG_FILE" "['secret']" "'123456'"
    #ruby_edit "$CONFIG_FILE" "['dns']['enable']" "true"
    #ruby_edit "$CONFIG_FILE" "['dns']['proxy-server-nameserver']" "['https://doh.pub/dns-query','https://223.5.5.5:443/dns-query']"

    #Hash Overwrite Demo
    #1--config path
    #2--key name
    #3--hash type value
    #ruby_edit "$CONFIG_FILE" "['dns']['nameserver-policy']" "{'+.msftconnecttest.com'=>'114.114.114.114', '+.msftncsi.com'=>'114.114.114.114', 'geosite:gfw'=>['https://dns.cloudflare.com/dns-query', 'https://dns.google/dns-query#ecs=1.1.1.1/24&ecs-override=true'], 'geosite:cn'=>['114.114.114.114'], 'geosite:geolocation-!cn'=>['https://dns.cloudflare.com/dns-query', 'https://dns.google/dns-query#ecs=1.1.1.1/24&ecs-override=true']}"
    #ruby_edit "$CONFIG_FILE" "['sniffer']" "{'enable'=>true, 'parse-pure-ip'=>true, 'force-domain'=>['+.netflix.com', '+.nflxvideo.net', '+.amazonaws.com', '+.media.dssott.com'], 'skip-domain'=>['+.apple.com', 'Mijia Cloud', 'dlg.io.mi.com', '+.oray.com', '+.sunlogin.net'], 'sniff'=>{'TLS'=>nil, 'HTTP'=>{'ports'=>[80, '8080-8880'], 'override-destination'=>true}}}"

    #Map Edit Demo
    #1--config path
    #2--map name
    #3--key name
    #4--sub key name
    #5--value
    #ruby_map_edit "$CONFIG_FILE" "['proxy-providers']" "HK" "['url']" "http://test.com"

    #Hash Merge Demo
    #1--config path
    #2--key name
    #3--hash
    #ruby_merge_hash "$CONFIG_FILE" "['proxy-providers']" "'TW'=>{'type'=>'http', 'path'=>'./proxy_provider/TW.yaml', 'url'=>'https://gist.githubusercontent.com/raw/tw_clash', 'interval'=>3600, 'health-check'=>{'enable'=>true, 'url'=>'http://cp.cloudflare.com/generate_204', 'interval'=>300}}"
    #ruby_merge_hash "$CONFIG_FILE" "['rule-providers']" "'Reject'=>{'type'=>'http', 'behavior'=>'classical', 'url'=>'https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/refs/heads/master/Clash/Apple.list', 'path'=>'./rule_provider/Apple.list', 'interval'=>86400}"

    #Array Edit Demo
    #1--config path
    #2--key name
    #3--match key name
    #4--match key value
    #5--target key name
    #6--target key value
    #ruby_arr_edit "$CONFIG_FILE" "['proxy-groups']" "['name']" "Proxy" "['type']" "smart"
    #ruby_arr_edit "$CONFIG_FILE" "['dns']['nameserver']" "" "114.114.114.114" "" "119.29.29.29"

    #Array Insert Value Demo:
    #1--config path
    #2--key name
    #3--position(start from 0, end with -1)
    #4--value
    #ruby_arr_insert "$CONFIG_FILE" "['dns']['nameserver']" "0" "114.114.114.114"

    #Array Insert Hash Demo:
    #1--config path
    #2--key name
    #3--position(start from 0, end with -1)
    #4--hash
    #ruby_arr_insert_hash "$CONFIG_FILE" "['proxy-groups']" "0" "{'name'=>'Disney', 'type'=>'select', 'disable-udp'=>false, 'use'=>['TW', 'SG', 'HK']}"
    #ruby_arr_insert_hash "$CONFIG_FILE" "['proxies']" "0" "{'name'=>'HKG 01', 'type'=>'ss', 'server'=>'cc.hd.abc', 'port'=>'12345', 'cipher'=>'aes-128-gcm', 'password'=>'123456', 'udp'=>true, 'plugin'=>'obfs', 'plugin-opts'=>{'mode'=>'http', 'host'=>'microsoft.com'}}"
    #ruby_arr_insert_hash "$CONFIG_FILE" "['listeners']" "0" "{'name'=>'name', 'type'=>'shadowsocks', 'port'=>'12345', 'listen'=>'0.0.0.0', 'rule'=>'sub-rule-1', 'proxy'=>'proxy'}"

    #Array Insert Other Array Demo:
    #1--config path
    #2--key name
    #3--position(start from 0, end with -1)
    #4--array
    #ruby_arr_insert_arr "$CONFIG_FILE" "['dns']['proxy-server-nameserver']" "0" "['https://doh.pub/dns-query','https://223.5.5.5:443/dns-query']"

    #Array Insert From Yaml File Demo:
    #1--config path
    #2--key name
    #3--position(start from 0, end with -1)
    #4--value file path
    #5--value key name in #4 file
    #ruby_arr_add_file "$CONFIG_FILE" "['dns']['fallback-filter']['ipcidr']" "0" "/etc/openclash/custom/openclash_custom_fallback_filter.yaml" "['fallback-filter']['ipcidr']"

    #Delete Array Value Demo:
    #1--config path
    #2--key name
    #3--value
    #ruby_delete "$CONFIG_FILE" "['dns']['nameserver']" "114.114.114.114"

    #Array Head Insert From Yaml File Demo:
    #1--config path
    #2--key name
    #3--value file path
    #4--value path in #3 file
    #ruby_arr_head_add_file "$CONFIG_FILE" "['rules']" "/etc/openclash/custom/openclash_custom_rules.list" "['rules']"

    #Cover Value From Yaml File Demo(the key is removed when #3 file is missing):
    #1--config path
    #2--key name
    #3--value file path
    #4--value key name in #3 file
    #ruby_cover "$CONFIG_FILE" "['dns']['nameserver']" "/etc/openclash/custom/openclash_custom_dns.yaml" "nameserver"

    #Hash Merge From Yaml File Demo:
    #1--config path
    #2--key name
    #3--value file path
    #4--hash path in #3 file
    #ruby_merge "$CONFIG_FILE" "['dns']" "/etc/openclash/custom/openclash_custom_dns.yaml" "['dns']"

    #Array Unique Demo:
    #1--config path
    #2--key name
    #ruby_uniq "$CONFIG_FILE" "['dns']['nameserver']"

    #Unicode Demo(Chinese and emoji are supported in key names and values):
    #ruby_edit "$CONFIG_FILE" "['secret']" "'中文😀密钥'"
    #ruby_edit "$CONFIG_FILE" "['hosts']['例子.local']" "'1.2.3.4'"

    #Delete Key Demo:
    #1--config path
    #2--key name(empty means the top level)
    #3--key name
    #ruby_delete "$CONFIG_FILE" "['dns']" "nameserver"
    #ruby_delete "$CONFIG_FILE" "" "dns"

    #Ruby Script Demo:
    #ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e "
    #   begin
    #      Value = YAML.load_file('$CONFIG_FILE');
    #   rescue Exception => e
    #      puts '${LOGTIME} [error] Load File Failed,【' + e.message + '】';
    #   end;

        #General
    #   begin
    #   Thread.new{
    #      Value['redir-port']=7892;
    #      Value['tproxy-port']=7895;
    #      Value['port']=7890;
    #      Value['socks-port']=7891;
    #      Value['mixed-port']=7893;
    #   }.join;

    #   rescue Exception => e
    #      puts '${LOGTIME} [error] Set General Failed,【' + e.message + '】';
    #   ensure
    #      YAML.dump(Value, '$CONFIG_FILE');
    #   end" 2>/dev/null >> $LOG_FILE

exit 0