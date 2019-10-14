#!/bin/bash
status=$(ps|grep -c /usr/share/openclash/openclash.sh)
[ "$status" -gt "3" ] && exit 0

START_LOG="/tmp/openclash_start.log"
LOGTIME=$(date "+%Y-%m-%d %H:%M:%S")
CONFIG_FILE="/etc/openclash/config.yaml"
LOG_FILE="/tmp/openclash.log"
BACKPACK_FILE="/etc/openclash/config.bak"
URL_TYPE=$(uci get openclash.config.config_update_url_type 2>/dev/null)
subscribe_url=$(uci get openclash.config.subscribe_url 2>/dev/null)
en_mode=$(uci get openclash.config.en_mode 2>/dev/null)
servers_update=$(uci get openclash.config.servers_update 2>/dev/null)
servers_update_keyword=$(uci get openclash.config.servers_update_keyword 2>/dev/null)
dns_port=$(uci get openclash.config.dns_port 2>/dev/null)
enable_redirect_dns=$(uci get openclash.config.enable_redirect_dns 2>/dev/null)
disable_masq_cache=$(uci get openclash.config.disable_masq_cache 2>/dev/null)
      
config_download()
{
if [ "$URL_TYPE" == "v2rayn" ]; then
   echo "开始下载V2rayN配置文件..." >$START_LOG
   subscribe_url=`echo $subscribe_url |sed 's/{/%7B/g;s/}/%7D/g;s/:/%3A/g;s/\"/%22/g;s/,/%2C/g;s/?/%3F/g;s/=/%3D/g;s/&/%26/g;s/\//%2F/g'`
   wget-ssl --no-check-certificate --quiet --timeout=10 --tries=2 https://tgbot.lbyczf.com/v2rayn2clash?url="$subscribe_url" -O /tmp/config.yaml
elif [ "$URL_TYPE" == "surge" ]; then
   echo "开始下载Surge配置文件..." >$START_LOG
   subscribe_url=`echo $subscribe_url |sed 's/{/%7B/g;s/}/%7D/g;s/:/%3A/g;s/\"/%22/g;s/,/%2C/g;s/?/%3F/g;s/=/%3D/g;s/&/%26/g;s/\//%2F/g'`
   wget-ssl --no-check-certificate --quiet --timeout=10 --tries=2 https://tgbot.lbyczf.com/surge2clash?url="$subscribe_url" -O /tmp/config.yaml
else
   echo "开始下载Clash配置文件..." >$START_LOG
   wget-ssl --no-check-certificate --quiet --timeout=10 --tries=2 "$subscribe_url" -O /tmp/config.yaml
fi
}

config_cus_up()
{
	if [ "$servers_update" -eq "1" ] || [ ! -z "$servers_update_keyword" ]; then
	   echo "配置文件替换成功，开始挑选节点..." >$START_LOG
	   echo "${LOGTIME} Config Update Successful" >>$LOG_FILE
	   uci set openclash.config.servers_if_update=1
	   uci commit openclash
	   /usr/share/openclash/yml_groups_get.sh
	   uci set openclash.config.servers_if_update=1
	   uci commit openclash
	   /usr/share/openclash/yml_groups_set.sh
	else
	   echo "配置文件替换成功，开始启动 OpenClash ..." >$START_LOG
     echo "${LOGTIME} Config Update Successful" >>$LOG_FILE
     /etc/init.d/openclash restart 2>/dev/null
  fi
}

config_su_check()
{
   echo "配置文件下载成功，检查是否有更新..." >$START_LOG
   if [ -f "$CONFIG_FILE" ]; then
      cmp -s "$BACKPACK_FILE" /tmp/config.yaml
         if [ "$?" -ne "0" ]; then
            echo "配置文件有更新，开始替换..." >$START_LOG
            mv /tmp/config.yaml "$CONFIG_FILE" 2>/dev/null
            cp "$CONFIG_FILE" "$BACKPACK_FILE"
            config_cus_up
         else
            echo "配置文件没有任何更新，停止继续操作..." >$START_LOG
            rm -rf /tmp/config.yaml
            change_dns
            echo "${LOGTIME} Updated Config No Change, Do Nothing" >>$LOG_FILE
            sleep 5
            echo "" >$START_LOG
         fi
   else
      echo "配置文件下载成功，本地没有配置文件，开始创建 ..." >$START_LOG
      mv /tmp/config.yaml "$CONFIG_FILE" 2>/dev/null
      cp "$CONFIG_FILE" "$BACKPACK_FILE"
      config_cus_up
   fi
}

config_error()
{
   echo "配置文件下载失败，请检查网络或稍后再试！" >$START_LOG
   echo "${LOGTIME} Config Update Error" >>$LOG_FILE
   rm -rf /tmp/config.yaml 2>/dev/null
   sleep 5
   echo "" >$START_LOG
}

change_dns()
{
   if pidof clash >/dev/null; then
      if [ "$enable_redirect_dns" -ne "0" ]; then
         uci del dhcp.@dnsmasq[-1].server >/dev/null 2>&1
         uci add_list dhcp.@dnsmasq[0].server=127.0.0.1#"$dns_port"
         uci delete dhcp.@dnsmasq[0].resolvfile
         uci set dhcp.@dnsmasq[0].noresolv=1
         [ "$disable_masq_cache" -eq "1" ] && {
            uci set dhcp.@dnsmasq[0].cachesize=0
         }
         uci commit dhcp
         /etc/init.d/dnsmasq restart >/dev/null 2>&1
      fi
      nohup /usr/share/openclash/openclash_watchdog.sh &
   fi
}

config_download

if [ "$?" -eq "0" ] && [ "$(ls -l /tmp/config.yaml |awk '{print int($5/1024)}')" -ne 0 ]; then
   config_su_check
else
   if pidof clash >/dev/null; then
      echo "配置文件下载失败，尝试不使用代理下载配置文件..." >$START_LOG
      
      watchdog_pids=$(ps |grep openclash_watchdog.sh |grep -v grep |awk '{print $1}' 2>/dev/null)
      for watchdog_pid in $watchdog_pids; do
         kill -9 "$watchdog_pid" >/dev/null 2>&1
      done

      uci del_list dhcp.@dnsmasq[0].server=127.0.0.1#"$dns_port" >/dev/null 2>&1
      uci set dhcp.@dnsmasq[0].resolvfile=/tmp/resolv.conf.auto
      uci set dhcp.@dnsmasq[0].noresolv=0
      uci delete dhcp.@dnsmasq[0].cachesize
      uci commit dhcp
      /etc/init.d/dnsmasq restart >/dev/null 2>&1
      sleep 3
      
      config_download
      
      if [ "$?" -eq "0" ] && [ "$(ls -l /tmp/config.yaml |awk '{print int($5/1024)}')" -ne 0 ]; then
         config_su_check
      else
         change_dns
         config_error
      fi
   else
      config_error
   fi
fi
