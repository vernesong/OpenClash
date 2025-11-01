#!/bin/sh
. /usr/share/openclash/ruby.sh
. /usr/share/openclash/log.sh
. /usr/share/openclash/uci.sh
. /lib/functions.sh

LOG_FILE="/tmp/openclash.log"
CONFIG_FILE="$5"

custom_fakeip_filter=$(uci_get_config "custom_fakeip_filter" || echo 0)
custom_name_policy=$(uci_get_config "custom_name_policy" || echo 0)
custom_host=$(uci_get_config "custom_host" || echo 0)
enable_custom_dns=$(uci_get_config "enable_custom_dns" || echo 0)
append_wan_dns=$(uci_get_config "append_wan_dns" || echo 0)
custom_fallback_filter=$(uci_get_config "custom_fallback_filter" || echo 0)
china_ip_route=$(uci_get_config "china_ip_route" || echo 0)
china_ip6_route=$(uci_get_config "china_ip6_route" || echo 0)
enable_redirect_dns=$(uci_get_config "enable_redirect_dns" || echo 1)

[ "$china_ip_route" -ne 0 ] && [ "$china_ip_route" -ne 1 ] && [ "$china_ip_route" -ne 2 ] && china_ip_route=0
[ "$china_ip6_route" -ne 0 ] && [ "$china_ip6_route" -ne 1 ] && [ "$china_ip6_route" -ne 2 ] && china_ip6_route=0

en_mode_tun=${11:-0}
if [ -z "${12}" ]; then
   stack_type=${31:-"system"}
else
   stack_type=${12}
fi

if [ "$1" = "fake-ip" ] && [ "$enable_redirect_dns" != "2" ]; then
   TMP_FILTER_FILE="/tmp/yaml_openclash_fake_filter_include"
   > "$TMP_FILTER_FILE"

   process_pass_list() {
      [ ! -f "$1" ] && return
      awk '
         !/^$/ && !/^#/ {
            if ($0 ~ /^\+?\./ || $0 ~ /^\*\./) {
               print $0
            } else {
               print "+."$0
            }
         }
      ' "$1" >> "$TMP_FILTER_FILE" 2>/dev/null
   }

   if [ "$china_ip_route" != "0" ]; then
      process_pass_list "/etc/openclash/custom/openclash_custom_chnroute_pass.list"
   fi
   if [ "$china_ip6_route" != "0" ]; then
      process_pass_list "/etc/openclash/custom/openclash_custom_chnroute6_pass.list"
   fi
fi

# 获取认证信息
yml_auth_get()
{
   local section="$1"
   local enabled username password
   config_get_bool "enabled" "$section" "enabled" "1"
   config_get "username" "$section" "username" ""
   config_get "password" "$section" "password" ""

   if [ "$enabled" = "0" ]; then
      return
   fi

   if [ -z "$username" ] || [ -z "$password" ]; then
      return
   else
      LOG_OUT "Tip: You have seted the authentication of SOCKS5/HTTP(S) proxy with【$username:$password】..."
      echo "  - $username:$password" >>/tmp/yaml_openclash_auth
   fi
}

# 添加自定义DNS设置
yml_dns_custom()
{
   if [ "$1" = 1 ] || [ "$3" = 1 ]; then
      sys_dns_append "$3" "$4"
      config_foreach yml_dns_get "dns_servers" "$2"
   fi
}

# 获取DHCP或接口的DNS并追加
sys_dns_append()
{
   if [ "$1" = 1 ]; then
      wan_dns=$(/usr/share/openclash/openclash_get_network.lua "dns")
      wan6_dns=$(/usr/share/openclash/openclash_get_network.lua "dns6")
      wan_gate=$(/usr/share/openclash/openclash_get_network.lua "gateway")
      wan6_gate=$(/usr/share/openclash/openclash_get_network.lua "gateway6")
      dhcp_iface=$(/usr/share/openclash/openclash_get_network.lua "dhcp")
      pppoe_iface=$(/usr/share/openclash/openclash_get_network.lua "pppoe")
      if [ -z "$dhcp_iface" ] && [ -z "$pppoe_iface" ]; then
         if [ -n "$wan_dns" ]; then
            for i in $wan_dns; do
               echo "    - \"$i\"" >>/tmp/yaml_config.namedns.yaml
            done
         fi
         if [ -n "$wan6_dns" ] && [ "$2" = 1 ]; then
            for i in $wan6_dns; do
               echo "    - \"[${i}]:53\"" >>/tmp/yaml_config.namedns.yaml
            done
         fi
         if [ -n "$wan_gate" ]; then
            for i in $wan_gate; do
                echo "    - \"$i\"" >>/tmp/yaml_config.namedns.yaml
            done
         fi
         if [ -n "$wan6_gate" ] && [ "$2" = 1 ]; then
            for i in $wan6_gate; do
               echo "    - \"[${i}]:53\"" >>/tmp/yaml_config.namedns.yaml
            done
         fi
      else
         if [ -n "$dhcp_iface" ]; then
            for i in $dhcp_iface; do
               echo "    - dhcp://\"$i\"" >>/tmp/yaml_config.namedns.yaml
            done
            if [ -n "$wan_gate" ]; then
               for i in $wan_gate; do
                   echo "    - \"$i\"" >>/tmp/yaml_config.namedns.yaml
               done
            fi
            if [ -n "$wan6_gate" ] && [ "$2" = 1 ]; then
               for i in $wan6_gate; do
                  echo "    - \"[${i}]:53\"" >>/tmp/yaml_config.namedns.yaml
               done
            fi
         fi
         if [ -n "$pppoe_iface" ]; then
            if [ -n "$wan_dns" ]; then
                   for i in $wan_dns; do
                      echo "    - \"$i\"" >>/tmp/yaml_config.namedns.yaml
                   done
               fi
               if [ -n "$wan6_dns" ] && [ "$2" = 1 ]; then
                  for i in $wan6_dns; do
                     echo "    - \"[${i}]:53\"" >>/tmp/yaml_config.namedns.yaml
                  done
               fi
         fi
      fi
      if [ -f "/tmp/yaml_config.namedns.yaml" ] && [ -z "$(grep "^ \{0,\}nameserver:$" /tmp/yaml_config.namedns.yaml 2>/dev/null)" ]; then
         sed -i '1i\  nameserver:'  "/tmp/yaml_config.namedns.yaml"
      fi
   fi
}

PROXY_GROUPS=$(ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e "
   begin
      Value = YAML.load_file('$CONFIG_FILE')
      if Value.key?('proxy-groups') && Value['proxy-groups'].is_a?(Array)
         Value['proxy-groups'].each { |x| puts x['name'] if x.key?('name') }
      end
   rescue Exception => e
      YAML.LOG('Error: proxy-groups Get Failed,【%s】' % [e.message])
   end
" 2>/dev/null)

yml_dns_get()
{
   local section="$1" regex='^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$'
   local enabled port type ip group dns_type dns_address interface specific_group node_resolve http3 ecs_subnet ecs_override
   
   config_get_bool "enabled" "$section" "enabled" "1"
   [ "$enabled" = "0" ] && return

   config_get "ip" "$section" "ip" ""
   [ -z "$ip" ] && return
   
   config_get "port" "$section" "port" ""
   config_get "type" "$section" "type" ""
   config_get "group" "$section" "group" ""
   config_get "interface" "$section" "interface" ""
   config_get "specific_group" "$section" "specific_group" ""
   config_get_bool "node_resolve" "$section" "node_resolve" "0"
   config_get_bool "direct_nameserver" "$section" "direct_nameserver" "0"
   config_get_bool "http3" "$section" "http3" "0"
   config_get_bool "skip_cert_verify" "$section" "skip_cert_verify" "0"
   config_get_bool "ecs_override" "$section" "ecs_override" "0"
   config_get "ecs_subnet" "$section" "ecs_subnet" ""
   config_get "disable_ipv4" "$section" "disable_ipv4" "0"
   config_get "disable_ipv6" "$section" "disable_ipv6" "0"

   if [[ "$ip" =~ "$regex" ]] || [ -n "$(echo "${ip}" | grep -Eo "${regex}")" ]; then
      ip="[${ip}]"
   fi

   case "$type" in
      "tcp") dns_type="tcp://" ;;
      "tls") dns_type="tls://" ;;
      "udp") dns_type="" ;;
      "https") dns_type="https://" ;;
      "quic") dns_type="quic://" ;;
      *) dns_type="" ;;
   esac

   if [ -n "$port" ]; then
      if [ "${ip%%/*}" != "${ip#*/}" ]; then
         dns_address="${ip%%/*}:$port/${ip#*/}"
      else
         dns_address="$ip:$port"
      fi
   else
      dns_address="$ip"
   fi

   if [ "$specific_group" != "Disable" ] && [ -n "$specific_group" ]; then
      group_check=$(echo "$PROXY_GROUPS" | grep -F -w -m 1 "$specific_group")
      [ -n "$group_check" ] && specific_group_param="$group_check" || specific_group_param=""
   else
      specific_group_param=""
   fi

   [ "$interface" != "Disable" ] && [ -n "$interface" ] && interface_param="$interface" || interface_param=""
   [ "$http3" = "1" ] && http3_param="h3=true" || http3_param=""
   [ "$skip_cert_verify" = "1" ] && skip_cert_verify_param="skip-cert-verify=true" || skip_cert_verify_param=""
   [ -n "$ecs_subnet" ] && ecs_subnet_param="ecs=$ecs_subnet" || ecs_subnet_param=""
   [ "$ecs_override" = "1" ] && [ -n "$ecs_subnet_param" ] && ecs_override_param="ecs-override=true" || ecs_override_param=""
   [ "$disable_ipv4" = "1" ] && disable_ipv4_param="disable-ipv4=true" || disable_ipv4_param=""
   [ "$disable_ipv6" = "1" ] && disable_ipv6_param="disable-ipv6=true" || disable_ipv6_param=""

   params=""
   append_param() {
      if [ -n "$1" ]; then
         [ -z "$params" ] && params="#" || params="$params&"
         params="$params$1"
      fi
   }
   
   append_param "$specific_group_param"
   append_param "$interface_param"
   append_param "$http3_param"
   append_param "$skip_cert_verify_param"
   append_param "$ecs_subnet_param"
   append_param "$ecs_override_param"
   append_param "$disable_ipv4_param"
   append_param "$disable_ipv6_param"

   full_dns_address="$dns_type$dns_address$params"

   if [ "$node_resolve" = "1" ]; then
      if ! grep -q "^ \{0,\}proxy-server-nameserver:$" /tmp/yaml_config.proxynamedns.yaml 2>/dev/null; then
         echo "  proxy-server-nameserver:" >/tmp/yaml_config.proxynamedns.yaml
      fi
      echo "    - \"$full_dns_address\"" >>/tmp/yaml_config.proxynamedns.yaml
   fi

   if [ "$direct_nameserver" = "1" ]; then
      if ! grep -q "^ \{0,\}direct-nameserver:$" /tmp/yaml_config.directnamedns.yaml 2>/dev/null; then
         echo "  direct-nameserver:" >/tmp/yaml_config.directnamedns.yaml
      fi
      echo "    - \"$full_dns_address\"" >>/tmp/yaml_config.directnamedns.yaml
   fi

   case "$group" in
      "nameserver")
         if ! grep -q "^ \{0,\}nameserver:$" /tmp/yaml_config.namedns.yaml 2>/dev/null; then
            echo "  nameserver:" >/tmp/yaml_config.namedns.yaml
         fi
         echo "    - \"$full_dns_address\"" >>/tmp/yaml_config.namedns.yaml
         ;;
      "fallback")
         if ! grep -q "^ \{0,\}fallback:$" /tmp/yaml_config.falldns.yaml 2>/dev/null; then
            echo "  fallback:" >/tmp/yaml_config.falldns.yaml
         fi
         echo "    - \"$full_dns_address\"" >>/tmp/yaml_config.falldns.yaml
         ;;
      "default")
         if ! grep -q "^ \{0,\}default-nameserver:$" /tmp/yaml_config.defaultdns.yaml 2>/dev/null; then
            echo "  default-nameserver:" >/tmp/yaml_config.defaultdns.yaml
         fi
         echo "    - \"$full_dns_address\"" >>/tmp/yaml_config.defaultdns.yaml
         ;;
   esac
}

config_load "openclash"
config_foreach yml_auth_get "authentication"
yml_dns_custom "$enable_custom_dns" "$5" "$append_wan_dns" "${16}"

ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e "

def safe_load_yaml(file_path)
   return nil unless File.exist?(file_path)
   YAML.load_file(file_path)
rescue
   nil
end

def merge_list_from_file(dns_hash, key, file_path)
   return unless File.exist?(file_path)
   lines = File.readlines(file_path).map { |l| l.gsub(/#.*$/, '').strip }.reject(&:empty?)
   return if lines.empty?
   (dns_hash[key] ||= []).concat(lines).uniq!
end


begin
   config_file = '$5'
   Value = YAML.load_file(config_file)
rescue Exception => e
   YAML.LOG('Error: Load File Failed,【%s】' % [e.message])
   exit
end

fake_ip_mode = '$1'
secret = '$2'
controller_port = '$3'
redir_port = '$4'
enable_ipv6 = '$6' == '1'
http_port = '$7'
socks_port = '$8'
log_level = '$9'
mode = '${10}'
en_mode_tun = '$en_mode_tun'
stack_type = '$stack_type'
dns_listen_port = '${13}'
mixed_port = '${14}'
tproxy_port = '${15}'
dns_ipv6 = '${16}' == '1'
store_fake_ip = '${17}' == '1'
enable_sniffer = '${18}' == '1'
geodata_mode = '${19}' == '1'
geodata_loader = '${20}'
append_sniffer_config = '${21}' == '1'
interface_name = '${22}'
tcp_concurrent = '${23}' == '1'
add_default_from_dns = '${25}' == '1'
sniffer_parse_pure_ip = '${26}' == '1'
find_process_mode = '${27}'
fake_ip_range = '${28}'
global_client_fingerprint = '${29}'
tun_device_setting = '${30}'
unified_delay = '${32}' == '1'
respect_rules = '${33}' == '1'
fake_ip_filter_mode = '${34}'
routing_mark_setting = '${35}'
quic_gso = '${36}' == '1'
cors_origin = '${37}'
geo_custom_url = '${38}'
geoip_custom_url = '${39}'
geosite_custom_url = '${40}'
geoasn_custom_url = '${41}'
lgbm_auto_update = '${42}' == '1'
lgbm_custom_url = '${43}'
lgbm_update_interval = '${44}'
smart_collect = '${45}' == '1'
smart_collect_size = '${46}'
fake_ip_range6 = '${47}'

enable_custom_dns = '$enable_custom_dns' == '1'
append_wan_dns = '$append_wan_dns' == '1'
custom_fakeip_filter = '$custom_fakeip_filter' == '1'
china_ip_route = '$china_ip_route' != '0'
china_ip6_route = '$china_ip6_route' != '0'
custom_name_policy = '$custom_name_policy' == '1'
custom_host = '$custom_host' == '1'
enable_redirect_dns = '$enable_redirect_dns'

Value['dns'] ||= {}
threads = []

threads << Thread.new do
   begin
      Value['redir-port'] = redir_port.to_i
      Value['tproxy-port'] = tproxy_port.to_i
      Value['port'] = http_port.to_i
      Value['socks-port'] = socks_port.to_i
      Value['mixed-port'] = mixed_port.to_i
      Value['mode'] = mode
      Value['log-level'] = log_level if log_level != '0'
      Value['allow-lan'] = true
      Value['external-controller'] = '0.0.0.0:' + controller_port
      Value['secret'] = secret
      Value['bind-address'] = '*'
      Value['external-ui'] = '/usr/share/openclash/ui'
      Value['external-ui-name'] = 'metacubexd'
      Value.delete('external-ui-url')
      if !Value.key?('keep-alive-interval') && !Value.key?('keep-alive-idle')
         Value['keep-alive-interval'] = 15
         Value['keep-alive-idle'] = 600
      end
      Value['ipv6'] = enable_ipv6
      Value['interface-name'] = interface_name if interface_name != '0'
      Value['geodata-mode'] = true if geodata_mode
      Value['geodata-loader'] = geodata_loader if geodata_loader != '0'
      Value['tcp-concurrent'] = true if tcp_concurrent
      Value['unified-delay'] = true if unified_delay
      Value['find-process-mode'] = find_process_mode if find_process_mode != '0'
      Value['global-client-fingerprint'] = global_client_fingerprint if global_client_fingerprint != '0'
      
      (Value['experimental'] ||= {})['quic-go-disable-gso'] = true if quic_gso
      if cors_origin != '0'
         (Value['external-controller-cors'] ||= {})['allow-origins'] = [cors_origin]
         Value['external-controller-cors']['allow-private-network'] = true
      end

      Value['lgbm-auto-update'] = true if lgbm_auto_update
      if lgbm_auto_update
         Value['lgbm-url'] = lgbm_custom_url.strip
         Value['lgbm-update-interval'] = lgbm_update_interval.to_i
      end

      if smart_collect
        (Value['profile'] ||= {})['smart-collector-size'] = smart_collect_size.to_f
      end

      Value['geox-url'] ||= {}
      if geo_custom_url != '0'
         Value['geox-url']['mmdb'] = geo_custom_url
      end
      if geoip_custom_url != '0'
         Value['geox-url']['geoip'] = geoip_custom_url
      end
      if geosite_custom_url != '0'
         Value['geox-url']['geosite'] = geosite_custom_url
      end
      if geoasn_custom_url != '0'
         Value['geox-url']['asn'] = geoasn_custom_url
      end

      Value['dns']['enable'] = true
      Value['dns']['ipv6'] = dns_ipv6
      Value['ipv6'] = true if dns_ipv6

      if fake_ip_mode == 'redir-host'
         Value['dns']['enhanced-mode'] = 'redir-host'
         Value['dns'].delete('fake-ip-range')
      else
         Value['dns']['enhanced-mode'] = 'fake-ip'
         Value['dns']['fake-ip-range'] = fake_ip_range
         if Value['dns']['ipv6']
            Value['dns']['fake-ip-range6'] = fake_ip_range6
         end
      end
      Value['dns']['listen'] = '0.0.0.0:' + dns_listen_port
      Value['dns']['respect-rules'] = true if respect_rules

      if enable_sniffer
         sniffer_config = {
            'enable' => true, 'override-destination' => true,
            'sniff' => {'QUIC' => {'ports' => [443]}, 'TLS' => {'ports' => [443, 8443]}, 'HTTP' => {'ports' => [80, '8080-8880'], 'override-destination' => true}},
            'force-domain' => ['+.netflix.com', '+.nflxvideo.net', '+.amazonaws.com', '+.media.dssott.com'],
            'skip-domain' => ['+.apple.com', 'Mijia Cloud', 'dlg.io.mi.com', '+.oray.com', '+.sunlogin.net', '+.push.apple.com']
         }
         sniffer_config['force-dns-mapping'] = true if fake_ip_mode == 'redir-host'
         sniffer_config['parse-pure-ip'] = true if sniffer_parse_pure_ip
         Value['sniffer'] = sniffer_config
         if append_sniffer_config && (custom_sniffer = safe_load_yaml('/etc/openclash/custom/openclash_custom_sniffer.yaml'))
            Value['sniffer'].merge!(custom_sniffer['sniffer']) if custom_sniffer && custom_sniffer['sniffer']
         end
      end

      if en_mode_tun != '0' || ['2', '3'].include?(tun_device_setting)
         Value['tun'] = {
            'enable' => true, 'stack' => stack_type, 'device' => 'utun',
            'dns-hijack' => ['127.0.0.1:53'], 'endpoint-independent-nat' => true,
            'auto-route' => false, 'auto-detect-interface' => false,
            'auto-redirect' => false, 'strict-route' => false
         }
         Value['tun'].delete('iproute2-table-index')
      else
         Value.delete('tun')
      end

      Value.delete('iptables')
      (Value['profile'] ||= {})['store-selected'] = true
      Value['profile']['store-fake-ip'] = true if store_fake_ip
      Value.delete('ebpf')

      if routing_mark_setting == '0'
         Value['routing-mark'] = 6666
      else
         Value.delete('routing-mark')
      end
      Value.delete('auto-redir')

   rescue Exception => e
      YAML.LOG('Error: Set General Failed,【%s】' % [e.message])
   end
end

threads << Thread.new do
   begin
      if enable_custom_dns || append_wan_dns
         if (namedns_config = safe_load_yaml('/tmp/yaml_config.namedns.yaml')) && namedns_config['nameserver']
            if enable_custom_dns
               Value['dns']['nameserver'] = namedns_config['nameserver'].uniq
            elsif append_wan_dns
               (Value['dns']['nameserver'] ||= []).concat(namedns_config['nameserver']).uniq!
            end

            if enable_custom_dns && (falldns_config = safe_load_yaml('/tmp/yaml_config.falldns.yaml')) && falldns_config['fallback']
               Value['dns']['fallback'] = falldns_config['fallback'].uniq
            end
         elsif enable_custom_dns
            YAML.LOG('Error: Nameserver Option Must Be Setted, Stop Customing DNS Servers')
         end
      end
   rescue Exception => e
      YAML.LOG('Error: Set Custom DNS Failed,【%s】' % [e.message])
   end

   begin
      if enable_custom_dns
         if (defaultdns_config = safe_load_yaml('/tmp/yaml_config.defaultdns.yaml')) && defaultdns_config['default-nameserver']
            (Value['dns']['default-nameserver'] ||= []).concat(defaultdns_config['default-nameserver']).uniq!
         end
      end
      if add_default_from_dns
         reg = /^dhcp:\/\/|^system($|:\/\/)|([0-9a-zA-Z-]{1,}\.)+([a-zA-Z]{2,})/
         servers_to_check = Value.dig('dns', 'nameserver').to_a | Value.dig('dns', 'fallback').to_a
         non_domain_servers = servers_to_check.reject { |s| s.match?(reg) }
         if non_domain_servers.any?
            (Value['dns']['default-nameserver'] ||= []).concat(non_domain_servers).uniq!
         end
      end
   rescue Exception => e
      YAML.LOG('Error: Set default-nameserver Failed,【%s】' % [e.message])
   end

   begin
      if '$custom_fallback_filter' == '1'
         if !Value.dig('dns', 'fallback')
            YAML.LOG('Error: Fallback-Filter Need fallback of DNS Been Setted, Ignore...')
         elsif (filter_config = safe_load_yaml('/etc/openclash/custom/openclash_custom_fallback_filter.yaml'))
            Value['dns']['fallback-filter'] = filter_config['fallback-filter']
         else
            YAML.LOG('Error: Unable To Parse Custom Fallback-Filter File, Ignore...')
         end
      end
   rescue Exception => e
      YAML.LOG('Error: Set fallback-filter Failed,【%s】' % [e.message])
   end
end

threads << Thread.new do
   begin
      if enable_custom_dns
         if (proxydns = safe_load_yaml('/tmp/yaml_config.proxynamedns.yaml')) && proxydns['proxy-server-nameserver']
            (Value['dns']['proxy-server-nameserver'] ||= []).concat(proxydns['proxy-server-nameserver']).uniq!
         end
      end
   rescue Exception => e
      YAML.LOG('Error: Set proxy-server-nameserver Failed,【%s】' % [e.message])
   end

   begin
      if enable_custom_dns
         if (directdns = safe_load_yaml('/tmp/yaml_config.directnamedns.yaml')) && directdns['direct-nameserver']
            (Value['dns']['direct-nameserver'] ||= []).concat(directdns['direct-nameserver']).uniq!
         end
      end
   rescue Exception => e
      YAML.LOG('Error: Set direct-nameserver Failed,【%s】' % [e.message])
   end
end

# nameserver-policy
threads << Thread.new do
   begin
      if custom_name_policy
         if (policy = safe_load_yaml('/etc/openclash/custom/openclash_custom_domain_dns_policy.list'))
            (Value['dns']['nameserver-policy'] ||= {}).merge!(policy)
         end
      end
   rescue Exception => e
      YAML.LOG('Error: Set Nameserver-Policy Failed,【%s】' % [e.message])
   end
end

# Fake-IP Filter
threads << Thread.new do
   begin
      if custom_fakeip_filter
         Value['dns']['fake-ip-filter-mode'] = fake_ip_filter_mode
         if fake_ip_mode == 'fake-ip'
            merge_list_from_file(Value['dns'], 'fake-ip-filter', '/etc/openclash/custom/openclash_custom_fake_filter.list')
            merge_list_from_file(Value['dns'], 'fake-ip-filter', '/tmp/yaml_openclash_fake_filter_include')
         end
      end
      if fake_ip_mode == 'fake-ip' && (china_ip_route || china_ip6_route)
         filter_mode = Value.dig('dns', 'fake-ip-filter-mode')
         filters = Value.dig('dns', 'fake-ip-filter') || []
         if filter_mode == 'blacklist' || filter_mode.nil?
            unless filters.include?('geosite:cn')
               (Value['dns']['fake-ip-filter'] ||= []) << 'geosite:cn'
               YAML.LOG('Tip: Because Need Ensure Bypassing IP Option Work, Added The Fake-IP-Filter Rule【geosite:cn】...')
            end
         else
            deleted_filters = filters.select { |f| f =~ /(geosite:?).*(@cn|:cn|,cn|:china)/ }
            if deleted_filters.any?
               Value['dns']['fake-ip-filter'] -= deleted_filters
               deleted_filters.each do |f|
                  YAML.LOG('Tip: Because Need Ensure Bypassing IP Option Work, Deleted The Fake-IP-Filter Rule【%s】...' % [f])
               end
            end
         end
      end
   rescue Exception => e
      YAML.LOG('Error: Set Fake-IP-Filter Failed,【%s】' % [e.message])
   end
end

# Custom Hosts
threads << Thread.new do
   begin
      if custom_host
         if (hosts_content = safe_load_yaml('/etc/openclash/custom/openclash_custom_hosts.list')) && !hosts_content.empty?
            Value['dns']['use-hosts'] = true
            if hosts_content.is_a?(Hash) && hosts_content.key?('hosts')
               (Value['hosts'] ||= {}).merge!(hosts_content['hosts'])
            else
               (Value['hosts'] ||= {}).merge!(hosts_content)
            end
            YAML.LOG('Warning: You May Need to Turn off The Rebinding Protection Option of Dnsmasq When Hosts Has Set a Reserved Address...')
         end
      end
   rescue Exception => e
      YAML.LOG('Error: Set Hosts Rules Failed,【%s】' % [e.message])
   end
end

# Authentication
threads << Thread.new do
   begin
      if (auth_config = safe_load_yaml('/tmp/yaml_openclash_auth'))
         Value['authentication'] = auth_config
      end
   rescue Exception => e
      YAML.LOG('Error: Set authentication Failed,【%s】' % [e.message])
   end
end

threads.each(&:join)

begin
   threads.clear

   # DNS Loop Check
   if enable_redirect_dns != '2'
      dns_options = ['nameserver', 'fallback', 'default-nameserver', 'proxy-server-nameserver', 'nameserver-policy', 'direct-nameserver']
      dns_options.each do |option|
         threads << Thread.new(option) do |opt|
            begin
               next unless Value['dns'].key?(opt) && !Value['dns'][opt].nil?
                  if opt != 'nameserver-policy'
                     original_size = Value['dns'][opt].size
                     Value['dns'][opt].reject! { |v| v.to_s.match?(/^system($|:\/\/)/) }
                     if Value['dns'][opt].size < original_size
                        YAML.LOG('Tip: Option【%s】is Setted【system】as DNS Server Which May Cause DNS Loop, Already Remove It...' % [opt])
                     end
                  else
                     Value['dns'][opt].each do |k, v|
                        if v.is_a?(Array)
                           original_size = v.size
                           v.reject! { |z| z.to_s.match?(/^system($|:\/\/)/) }
                           if v.empty?
                              Value['dns'][opt].delete(k)
                              YAML.LOG('Tip: Option【%s - %s】is Setted【system】as DNS Server Which May Cause DNS Loop, Already Remove It...' % [opt, k])
                           elsif v.size < original_size
                              YAML.LOG('Tip: Option【%s - %s】is Setted【system】as DNS Server Which May Cause DNS Loop, Already Remove It...' % [opt, k])
                           end
                        elsif v.to_s.match?(/^system($|:\/\/)/)
                           Value['dns'][opt].delete(k)
                           YAML.LOG('Tip: Option【%s - %s】is Setted【%s】as DNS Server Which May Cause DNS Loop, Already Remove It...' % [opt, k, v.to_s])
                        end
                     end
                  end
            rescue Exception => e
               YAML.LOG('Error: DNS Loop Check,【%s】' % [e.message])
            end
         end
      end
      threads.each(&:join)
   end

   if Value.dig('dns', 'nameserver').to_a.empty?
      YAML.LOG('Tip: Detected That The nameserver DNS Option Has No Server Set, Starting To Complete...')
      Value['dns']['nameserver'] = ['114.114.114.114', '119.29.29.29', '8.8.8.8', '1.1.1.1']
      Value['dns']['fallback'] ||= ['https://dns.cloudflare.com/dns-query', 'https://dns.google/dns-query']
   end

   if Value['dns'].key?('default-nameserver') && Value['dns']['default-nameserver'].to_a.empty?
      YAML.LOG('Tip: Detected That The default-nameserver DNS Option Has No Server Set, Starting To Complete...')
      Value['dns']['default-nameserver'] = ['114.114.114.114', '119.29.29.29', '8.8.8.8', '1.1.1.1']
   end

   # proxy-server-nameserver
   local_exclude = (%x{ls -l /sys/class/net/ |awk '{print \$9}'  2>&1}.each_line.map(&:strip) + ['h3=', 'skip-cert-verify=', 'ecs=', 'ecs-override='] + ['utun', 'tailscale0', 'docker0', 'tun163', 'br-lan', 'mihomo']).uniq.join('|')
   proxied_server_reg = /^[^#&]+#(?:(?:#{local_exclude})[^&]*&)*(?:(?!(?:#{local_exclude}))[^&]+)/
   default_proxy_servers = ['114.114.114.114', '119.29.29.29', '8.8.8.8', '1.1.1.1']

   if Value.dig('dns', 'proxy-server-nameserver').to_a.empty?
      all_ns_proxied = Value.dig('dns', 'nameserver').to_a.all? { |x| x.match?(proxied_server_reg) }
      if respect_rules || Value.dig('dns', 'respect-rules').to_s == 'true' || all_ns_proxied
         Value['dns']['proxy-server-nameserver'] = default_proxy_servers
         if all_ns_proxied
            YAML.LOG('Tip: Nameserver Option Maybe All Setted The Proxy Option, Auto Set Proxy-server-nameserver Option to【114.114.114.114, 119.29.29.29, 8.8.8.8, 1.1.1.1】For Avoiding Proxies Server Resolve Loop...')
         else
            YAML.LOG('Tip: Respect-rules Option Need Proxy-server-nameserver Option Must Be Setted, Auto Set to【114.114.114.114, 119.29.29.29, 8.8.8.8, 1.1.1.1】')
         end
      end
   else
      all_psn_proxied = Value.dig('dns', 'proxy-server-nameserver').to_a.all? { |x| x.match?(proxied_server_reg) }
      if all_psn_proxied
         (Value['dns']['proxy-server-nameserver'] ||= []).concat(default_proxy_servers).uniq!
         YAML.LOG('Tip: Proxy-server-nameserver Option Maybe All Setted The Proxy Option, Auto Set Proxy-server-nameserver Option to【114.114.114.114, 119.29.29.29, 8.8.8.8, 1.1.1.1】For Avoiding Proxies Server Resolve Loop...')
      end
   end

rescue Exception => e
   YAML.LOG('Error: Config File Overwrite Failed,【%s】' % [e.message])
ensure
   File.open(config_file, 'w') { |f| YAML.dump(Value, f) }
end
" 2>/dev/null >> $LOG_FILE