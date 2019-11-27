#!/bin/sh /etc/rc.common
status=$(ps|grep -c /usr/share/openclash/yml_groups_set.sh)
[ "$status" -gt "3" ] && exit 0

START_LOG="/tmp/openclash_start.log"
GROUP_FILE="/tmp/yaml_groups.yaml"
CONFIG_FILE="/etc/openclash/config.yaml"
CFG_FILE="/etc/config/openclash"

#加入节点
yml_servers_add()
{
	
	local section="$1"
	config_get_bool "enabled" "$section" "enabled" "1"
	if [ "$enabled" = "0" ]; then
      return
  else
	   config_get "name" "$section" "name" ""
	   config_list_foreach "$section" "groups" set_groups "$name" "$2"
	fi
	
}

set_groups()
{
  if [ -z "$1" ]; then
     return
  fi

	if [ "$1" = "$3" ]; then
	   echo "  - \"${2}\"" >>$GROUP_FILE
	fi

}

set_other_groups()
{
   if [ -z "$1" ]; then
      return
   fi
   
   echo "  - ${1}" >>$GROUP_FILE

}


#创建策略组
yml_groups_set()
{

   local section="$1"
   config_get "type" "$section" "type" ""
   config_get "name" "$section" "name" ""
   config_get "old_name" "$section" "old_name" ""
   config_get "test_url" "$section" "test_url" ""
   config_get "test_interval" "$section" "test_interval" ""

   if [ -z "$type" ]; then
      return
   fi
   
   if [ -z "$name" ]; then
      return
   fi
   
   if [ -z "$test_url" ] || [ -z "$test_interval" ] && [ "$type" != "select" ]; then
      return
   fi
   
   echo "正在写入【$type】-【$name】策略组到配置文件..." >$START_LOG
   
   echo "- name: $name" >>$GROUP_FILE
   echo "  type: $type" >>$GROUP_FILE
   echo "  proxies:" >>$GROUP_FILE
   
   #名字变化时处理规则部分
   if [ "$name" != "$old_name" ] && [ ! -z "$old_name" ]; then
      sed -i "s/,${old_name}/,${name}#d/g" $CONFIG_FILE 2>/dev/null
      sed -i "s/:${old_name}$/:${name}#d/g" $CONFIG_FILE 2>/dev/null #修改第三方规则分组对应标签
      sed -i "s/\'${old_name}\'/\'${name}\'/g" $CFG_FILE 2>/dev/null
      config_load "openclash"
   fi
   
   config_list_foreach "$section" "other_group" set_other_groups #加入其他策略组
   config_foreach yml_servers_add "servers" "$name" #加入服务器节点
   
   [ ! -z "$test_url" ] && {
   	echo "  url: $test_url" >>$GROUP_FILE
   }
   [ ! -z "$test_interval" ] && {
   echo "  interval: \"$test_interval\"" >>$GROUP_FILE
   }
}

create_config=$(uci get openclash.config.create_config 2>/dev/null)
servers_if_update=$(uci get openclash.config.servers_if_update 2>/dev/null)
if [ "$create_config" = "0" ] || [ "$servers_if_update" = "1" ]; then
   /usr/share/openclash/yml_groups_name_get.sh
   if [ -z "$(grep "^ \{0,\}Proxy:" /etc/openclash/config.yaml)" ] || [ -z "$(grep "^ \{0,\}Rule:" /etc/openclash/config.yaml)" ]; then
      echo "配置文件信息读取失败，无法进行修改，请选择一键创建配置文件..." >$START_LOG
      uci commit openclash
      sleep 5
      echo "" >$START_LOG
      exit 0
   else
      echo "开始写入配置文件策略组信息..." >$START_LOG
      config_load "openclash"
      config_foreach yml_groups_set "groups"
      sed -i "s/#d//g" $CONFIG_FILE 2>/dev/null
      echo "Rule:" >>$GROUP_FILE
      echo "配置文件策略组写入完成！" >$START_LOG
   fi
fi
/usr/share/openclash/yml_proxys_set.sh >/dev/null 2>&1