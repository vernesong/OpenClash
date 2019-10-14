#!/bin/bash /etc/rc.common
status=$(ps|grep -c /usr/share/openclash/yml_proxys_get.sh)
[ "$status" -gt "3" ] && exit 0

START_LOG="/tmp/openclash_start.log"

if [ ! -f "/etc/openclash/config.yml" ] && [ ! -f "/etc/openclash/config.yaml" ]; then
  exit 0
elif [ ! -f "/etc/openclash/config.yaml" ] && [ "$(ls -l /etc/openclash/config.yml 2>/dev/null |awk '{print int($5/1024)}')" -gt 0 ]; then
   mv "/etc/openclash/config.yml" "/etc/openclash/config.yaml"
fi

echo "开始更新服务器节点配置..." >$START_LOG
awk '/^ {0,}Proxy:/,/^ {0,}Proxy Group:/{print}' /etc/openclash/config.yaml 2>/dev/null |sed 's/\"//g' 2>/dev/null |sed "s/\'//g" 2>/dev/null |sed 's/\t/ /g' 2>/dev/null >/tmp/yaml_proxy.yaml 2>&1

CONFIG_FILE="/etc/openclash/config.yaml"
CFG_FILE="/etc/config/openclash"
server_file="/tmp/yaml_proxy.yaml"
single_server="/tmp/servers.yaml"
match_servers="/tmp/match_servers.list"
group_num=$(grep -c "name:" /tmp/yaml_group.yaml)
servers_update=$(uci get openclash.config.servers_update 2>/dev/null)
servers_update_keyword=$(uci get openclash.config.servers_update_keyword 2>/dev/null)
servers_if_update=$(uci get openclash.config.servers_if_update 2>/dev/null)
new_servers_group=$(uci get openclash.config.new_servers_group 2>/dev/null)

count=1
line=$(sed -n '/^ \{0,\}-/=' $server_file)
num=$(grep -c "^ \{0,\}-" $server_file)

cfg_get()
{
	echo "$(grep "$1" "$2" 2>/dev/null |awk -v tag=$1 'BEGIN{FS=tag} {print $2}' 2>/dev/null |sed 's/,.*//' 2>/dev/null |sed 's/^ \{0,\}//g' 2>/dev/null |sed 's/ \{0,\}$//g' 2>/dev/null |sed 's/ \{0,\}\}\{0,\}$//g' 2>/dev/null)"
}

yml_servers_name_get()
{
	 local section="$1"
   config_get "name" "$section" "name" ""
   echo "$server_num"."$name" >>"$match_servers"
   server_num=$(( $server_num + 1 ))
}

server_key_match()
{
	if [ "$match" = "true" ] || [ ! -z "$(echo "$1" |grep "^ \{0,\}$")" ] || [ ! -z "$(echo "$1" |grep "^\t\{0,\}$")" ]; then
	   return
	fi
	
	if [ ! -z "$(echo "$1" |grep "&")" ]; then
	   key_word=$(echo "$1" |sed 's/&/ /g')
	   match=0
	   matchs=0
	   for k in $key_word
	   do
	      if [ -z "$k" ]; then
	         continue
	      fi
	      
	      if [ ! -z "$(echo "$2" |grep -i "$k")" ]; then
	         match=$(( $match + 1 ))
	      fi
	      matchs=$(( $matchs + 1 ))
	   done
	   if [ "$match" = "$matchs" ]; then
	   	  match="true"
	   else
	      match="false"
	   fi
	else
	   if [ ! -z "$(echo "$2" |grep -i "$1")" ]; then
	      match="true"
	   fi
	fi
}

cfg_new_servers_groups_get()
{
	 if [ -z "$1" ]; then
      return
   fi
   
   ${uci_add}groups="${1}"
}

if [ "$servers_update" -eq "1" ] && [ "$servers_if_update" = "1" ]; then
	echo "" >"$match_servers"
	server_num=0
	config_load "openclash"
  config_foreach yml_servers_name_get "servers"
fi

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
   
   #name
   server_name="$(cfg_get "name:" "$single_server")"

   #节点存在时获取节点编号
   if [ "$servers_if_update" = "1" ]; then
      server_num=$(grep -Fw "$server_name" "$match_servers" |awk -F '.' '{print $1}')
      if [ "$servers_update" -eq "1" ] && [ ! -z "$server_num" ]; then
         sed -i "/^${server_num}\./c\#match#" "$match_servers" 2>/dev/null
      elif [ ! -z "$servers_update_keyword" ]; then #匹配关键字订阅节点
         match="false"
         config_load "openclash"
         config_list_foreach "config" "servers_update_keyword" server_key_match "$server_name" 
         if [ "$match" = "false" ]; then
            echo "跳过【$server_name】服务器节点..." >$START_LOG
            continue
         fi
      fi
   fi
   #type
   server_type="$(cfg_get "type:" "$single_server")"
   #server
   server="$(cfg_get "server:" "$single_server")"
   #port
   port="$(cfg_get "port:" "$single_server")"
   #cipher
   cipher="$(cfg_get "cipher:" "$single_server")"
   #password
   password="$(cfg_get "password:" "$single_server")"
   #udp
   udp="$(cfg_get "udp:" "$single_server")"
   #plugin:
   plugin="$(cfg_get "plugin:" "$single_server")"
   #plugin-opts:
   plugin_opts="$(cfg_get "plugin-opts:" "$single_server")"
   #obfs:
   obfs="$(cfg_get "obfs:" "$single_server")"
   #psk:
   psk="$(cfg_get "psk:" "$single_server")"
   #obfs-host:
   obfs_host="$(cfg_get "obfs-host:" "$single_server")"
   #mode:
   mode="$(cfg_get "mode:" "$single_server")"
   #tls:
   tls="$(cfg_get "tls:" "$single_server")"
   #skip-cert-verify:
   verify="$(cfg_get "skip-cert-verify:" "$single_server")"
   #mux:
   mux="$(cfg_get "mux:" "$single_server")"
   #host:
   host="$(cfg_get "host:" "$single_server")"
   #Host:
   Host="$(cfg_get "Host:" "$single_server")"
   #path:
   path="$(cfg_get "path:" "$single_server")"
   #ws-path:
   ws_path="$(cfg_get "ws-path:" "$single_server")"
   #headers_custom:
   headers="$(cfg_get "custom:" "$single_server")"
   #uuid:
   uuid="$(cfg_get "uuid:" "$single_server")"
   #alterId:
   alterId="$(cfg_get "alterId:" "$single_server")"
   #network
   network="$(cfg_get "network:" "$single_server")"
   #username
   username="$(cfg_get "username:" "$single_server")"
   
   echo "正在读取【$server_type】-【$server_name】服务器节点配置..." >$START_LOG
   
   if [ "$servers_update" -eq "1" ] && [ ! -z "$server_num" ]; then
#更新已有节点
      uci_set="uci -q set openclash.@servers["$server_num"]."
      
      ${uci_set}manual="0"
      ${uci_set}type="$server_type" 2>/dev/null
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
      ${uci_set}obfs_snell="$mode"
      [ -z "$obfs" ] && ${uci_set}obfs="$mode"
      [ -z "$obfs" ] && [ -z "$mode" ] && ${uci_set}obfs="none"
      [ -z "$mode" ] && ${uci_set}obfs_snell="none"
      [ -z "$mode" ] && [ ! -z "$network" ] && ${uci_set}obfs_vmess="websocket"
      [ -z "$mode" ] && [ -z "$network" ] && ${uci_set}obfs_vmess="none"
      [ -z "$obfs_host" ] && ${uci_set}host="$host"
      ${uci_set}psk="$psk"
      ${uci_set}tls="$tls"
      ${uci_set}skip_cert_verify="$verify"
      ${uci_set}path="$path"
      [ -z "$path" ] && ${uci_set}path="$ws_path"
      ${uci_set}mux="$mux"
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
   else
#添加新节点
      name=openclash
      uci_name_tmp=$(uci add $name servers)

      uci_set="uci -q set $name.$uci_name_tmp."
      uci_add="uci -q add_list $name.$uci_name_tmp."

      if [ -z "$new_servers_group" ] && [ "$servers_if_update" = "1" ] && [ "$servers_update" -eq "1" ]; then
         ${uci_set}enabled="0"
      else
         ${uci_set}enabled="1"
      fi
      if [ "$servers_if_update" = "1" ]; then
         ${uci_set}manual="0"
      else
         ${uci_set}manual="1"
      fi
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
      ${uci_set}obfs_snell="$mode"
      [ -z "$obfs" ] && ${uci_set}obfs="$mode"
      [ -z "$obfs" ] && [ -z "$mode" ] && ${uci_set}obfs="none"
      [ -z "$mode" ] && ${uci_set}obfs_snell="none"
      [ -z "$mode" ] && [ ! -z "$network" ] && ${uci_set}obfs_vmess="websocket"
      [ -z "$mode" ] && [ -z "$network" ] && ${uci_set}obfs_vmess="none"
      [ -z "$obfs_host" ] && ${uci_set}host="$host"
      ${uci_set}psk="$psk"
      ${uci_set}tls="$tls"
      ${uci_set}skip_cert_verify="$verify"
      ${uci_set}path="$path"
      [ -z "$path" ] && ${uci_set}path="$ws_path"
      ${uci_set}mux="$mux"
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

#加入策略组
     if [ "$servers_if_update" = "1" ] && [ "$servers_update" -eq "1" ]  && [ ! -z "$new_servers_group" ] && [ ! -z "$(grep "config groups" "$CFG_FILE")" ]; then
#新节点且设置默认策略组时加入指定策略组
        config_load "openclash"
        config_list_foreach "config" "new_servers_group" cfg_new_servers_groups_get
     else
	      for ((i=1;i<=$group_num;i++))
	      do
	         single_group="/tmp/group_$i.yaml"
           if [ ! -z "$(grep -F "$server_name" "$single_group")" ]; then
              group_name=$(grep "name:" $single_group 2>/dev/null |awk -F 'name:' '{print $2}' 2>/dev/null |sed 's/,.*//' 2>/dev/null |sed 's/^ \{0,\}//g' 2>/dev/null |sed 's/ \{0,\}$//g' 2>/dev/null)
              ${uci_add}groups="$group_name"
           fi
	      done
     fi
   fi
   uci commit openclash
done

#删除订阅中已不存在的节点
if [ "$servers_update" -eq "1" ] && [ "$servers_if_update" = "1" ]; then
     echo "删除订阅中已不存在的节点..." >$START_LOG
     sed -i '/#match#/d' "$match_servers" 2>/dev/null
     cat $match_servers |awk -F '.' '{print $1}' |sort -rn |while read line
     do
        if [ -z "$line" ]; then
           continue
        fi
        if [ "$(uci get openclash.@servers["$line"].manual)" = "0" ]; then
           uci delete openclash.@servers["$line"] 2>/dev/null
        fi
     done
fi

uci set openclash.config.servers_if_update=0
uci commit openclash
/usr/share/openclash/cfg_servers_address_fake_block.sh
echo "配置文件读取完成！" >$START_LOG
sleep 3
echo "" >$START_LOG
rm -rf /tmp/servers.yaml 2>/dev/null
rm -rf /tmp/yaml_proxy.yaml 2>/dev/null
rm -rf /tmp/group_*.yaml 2>/dev/null
rm -rf /tmp/yaml_group.yaml 2>/dev/null
rm -rf /tmp/match_servers.list 2>/dev/null