#!/bin/bash
status=$(ps|grep -c /usr/share/openclash/yml_proxys_get.sh)
[ "$status" -gt "3" ] && exit 0

if [ ! -f "/etc/openclash/config.yml" ] && [ ! -f "/etc/openclash/config.yaml" ]; then
  exit 0
elif [ ! -f "/etc/openclash/config.yaml" ] && [ "$(ls -l /etc/openclash/config.yml 2>/dev/null |awk '{print int($5/1024)}')" -gt 0 ]; then
   mv "/etc/openclash/config.yml" "/etc/openclash/config.yaml"
fi

awk '/^ {0,}Proxy:/,/^ {0,}Proxy Group:/{print}' /etc/openclash/config.yaml 2>/dev/null >/tmp/yaml_proxy.yaml 2>&1

server_file="/tmp/yaml_proxy.yaml"
single_server="/tmp/servers.yaml"
group_num=$(grep -c "name:" /tmp/yaml_group.yaml)
count=1
line=$(sed -n '/^ \{0,\}-/=' $server_file)
num=$(grep -c "^ \{0,\}-" $server_file)


for n in $line
do

   [ "$count" -eq 1 ] && {
      startLine="$n"
  }

   count=$(expr "$count" + 1)
   if [ "$count" -gt "$num" ]; then
      endLine=$(sed -n '$=' $server_file)
   else
      endLine=$(expr $(echo "$line" | sed -n "${count}p") - 1)
   fi
  
   sed -n "${startLine},${endLine}p" $server_file >$single_server
   startLine=$(expr "$endLine" + 1)
   
   #type
   server_type=$(grep "type:" $single_server |awk -F 'type:' '{print $2}' |sed 's/,.*//' |sed 's/\"//g' |sed 's/^ \{0,\}//g')
   #name
   server_name=$(grep "name:" $single_server |awk -F 'name:' '{print $2}' |sed 's/,.*//' |sed 's/\"//g' |sed 's/^ \{0,\}//g')
   #server
   server=$(grep "server:" $single_server |awk -F 'server:' '{print $2}' |sed 's/,.*//' |sed 's/\"//g' |sed 's/^ \{0,\}//g')
   #port
   port=$(grep "port:" $single_server |awk -F 'port:' '{print $2}' |sed 's/,.*//' |sed 's/\"//g' |sed 's/^ \{0,\}//g')
   #cipher
   cipher=$(grep "cipher:" $single_server |awk -F 'cipher:' '{print $2}' |sed 's/,.*//' |sed 's/\"//g' |sed 's/^ \{0,\}//g' |sed 's/ \{0,\}\}$//g' 2>/dev/null)
   #password
   password=$(grep "password:" $single_server |awk -F 'password:' '{print $2}' |sed 's/,.*//' |sed 's/\"//g' |sed 's/^ \{0,\}//g' |sed 's/ \{0,\}\}$//g' 2>/dev/null)
   #udp
   udp=$(grep "udp:" $single_server |awk -F 'udp:' '{print $2}' |sed 's/,.*//' |sed 's/\"//g' |sed 's/^ \{0,\}//g' |sed 's/ \{0,\}\}$//g' 2>/dev/null)
   #plugin:
   plugin=$(grep "plugin:" $single_server |awk -F 'plugin:' '{print $2}' |sed 's/,.*//' |sed 's/\"//g' |sed 's/^ \{0,\}//g')
   #plugin-opts:
   plugin_opts=$(grep "plugin-opts:" $single_server |awk -F 'plugin-opts:' '{print $2}' |sed 's/,.*//' |sed 's/\"//g' |sed 's/^ \{0,\}//g')
   #obfs:
   obfs=$(grep "obfs:" $single_server |awk -F 'obfs:' '{print $2}' |sed 's/,.*//' |sed 's/\"//g' |sed 's/^ \{0,\}//g')
   #obfs-host:
   obfs_host=$(grep "obfs-host:" $single_server |awk -F 'obfs-host:' '{print $2}' |sed 's/,.*//' |sed 's/\"//g' |sed 's/^ \{0,\}//g')
   #mode:
   mode=$(grep "mode:" $single_server |awk -F 'mode:' '{print $2}' |sed 's/,.*//' |sed 's/\"//g' |sed 's/^ \{0,\}//g')
   #tls:
   tls=$(grep "tls:" $single_server |awk -F 'tls:' '{print $2}' |sed 's/,.*//' |sed 's/\"//g' |sed 's/^ \{0,\}//g' |sed 's/ \{0,\}\}$//g' 2>/dev/null)
   #skip-cert-verify:
   verify=$(grep "skip-cert-verify:" $single_server |awk -F 'skip-cert-verify:' '{print $2}' |sed 's/,.*//' |sed 's/\"//g' |sed 's/^ \{0,\}//g' |sed 's/ \{0,\}\}$//g' 2>/dev/null)
   #host:
   host=$(grep "host:" $single_server |awk -F 'host:' '{print $2}' |sed 's/,.*//' |sed 's/\"//g' |sed 's/^ \{0,\}//g')
   #Host:
   Host=$(grep "Host:" $single_server |awk -F 'Host:' '{print $2}' |sed 's/}.*//' |sed 's/,.*//' |sed 's/\"//g' |sed 's/^ \{0,\}//g' |sed 's/ \{0,\}$//g')
   #path:
   path=$(grep "path:" $single_server |awk -F 'path:' '{print $2}' |sed 's/,.*//' |sed 's/\"//g' |sed 's/^ \{0,\}//g')
   #ws-path:
   ws_path=$(grep "ws-path:" $single_server |awk -F 'ws-path:' '{print $2}' |sed 's/,.*//' |sed 's/\"//g' |sed 's/^ \{0,\}//g' |sed 's/ \{0,\}\}$//g' 2>/dev/null)
   #headers_custom:
   headers=$(grep "custom:" $single_server |awk -F 'custom:' '{print $2}' |sed 's/,.*//' |sed 's/\"//g' |sed 's/^ \{0,\}//g' |sed 's/ \{0,\}\}$//g' 2>/dev/null)
   #uuid:
   uuid=$(grep "uuid:" $single_server |awk -F 'uuid:' '{print $2}' |sed 's/,.*//' |sed 's/\"//g' |sed 's/^ \{0,\}//g')
   #alterId:
   alterId=$(grep "alterId:" $single_server |awk -F 'alterId:' '{print $2}' |sed 's/,.*//' |sed 's/\"//g' |sed 's/^ \{0,\}//g')
   #network
   network=$(grep "network:" $single_server |awk -F 'network:' '{print $2}' |sed 's/,.*//' |sed 's/\"//g' |sed 's/^ \{0,\}//g' |sed 's/ \{0,\}\}$//g' 2>/dev/null)
   #username
   username=$(grep "username:" $single_server |awk -F 'username:' '{print $2}' |sed 's/,.*//' |sed 's/\"//g' |sed 's/^ \{0,\}//g')
   
   name=openclash
   uci_name_tmp=$(uci add $name servers)

    uci_set="uci -q set $name.$uci_name_tmp."
    uci_add="uci -q add_list $name.$uci_name_tmp."
    
    ${uci_set}name="$server_name"
    ${uci_set}type="$server_type"
    ${uci_set}server="$server"
    ${uci_set}port="$port"
    if [ "$server_type" = "vmess" ]; then
       ${uci_set}securitys="$cipher"
    else
       ${uci_set}cipher="$cipher"
    fi
    ${uci_set}udp="$udp"
    ${uci_set}obfs="$obfs"
    ${uci_set}host="$obfs_host"
    [ -z "$obfs" ] && ${uci_set}obfs="$mode"
    [ -z "$mode" ] && [ ! -z "$network" ] && ${uci_set}obfs_vmess="websocket"
    [ -z "$obfs_host" ] && ${uci_set}host="$host"
    ${uci_set}tls="$tls"
    ${uci_set}skip_cert_verify="$verify"
    ${uci_set}path="$path"
    [ -z "$path" ] && ${uci_set}path="$ws_path"
    ${uci_set}custom="$headers"
    [ -z "$headers" ] && ${uci_set}custom="$Host"
    
	if [ "$server_type" = "vmess" ]; then
    #v2ray
    ${uci_set}alterId="$alterId"
    ${uci_set}uuid="$uuid"
	fi
	
	if [ "$server_type" = "socks5" ] || [ "$server_type" = "http" ]; then
     ${uci_set}auth_name="$username"
     ${uci_set}auth_pass="$password"
  else
     ${uci_set}password="$password"
	fi
	
	server_name_change=$(echo "$server_name" |sed 's/\\/#d#/g' 2>/dev/null |sed 's/ /#spas#/g' |sed 's/\t/#tab#/g' 2>/dev/null) #替换斜杠和空格
	for ((i=1;i<=$group_num;i++)) #循环加入策略组
	do
	   single_group="/tmp/group_$i.yaml"
	   sed -i -e 's/\\/#d#/g' -e 's/ /#spas#/g' -e 's/\t/#tab#/g' "$single_group" 2>/dev/null #替换斜杠和空格
     if [ ! -z "$(grep "$server_name_change" "$single_group")" ]; then
        group_name=$(grep "name:" $single_group |sed 's/#d#/\\/g' |sed 's/#spas#/ /g' |sed 's/#tab#/	/g' |awk -F 'name: ' '{print $2}' |sed 's/,.*//' 2>/dev/null |sed 's/\"//g' 2>/dev/null)
        ${uci_add}groups="$group_name"
     fi
	done

done

uci commit openclash
rm -rf /tmp/servers.yaml 2>/dev/null
rm -rf /tmp/yaml_proxy.yaml 2>/dev/null
rm -rf /tmp/group_*.yaml 2>/dev/null
rm -rf /tmp/yaml_group.yaml 2>/dev/null