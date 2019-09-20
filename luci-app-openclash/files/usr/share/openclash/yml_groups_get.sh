#!/bin/sh
status=$(ps|grep -c /usr/share/openclash/yml_groups_get.sh)
[ "$status" -gt "3" ] && exit 0

if [ ! -f "/etc/openclash/config.yml" ] && [ ! -f "/etc/openclash/config.yaml" ]; then
  exit 0
elif [ ! -f "/etc/openclash/config.yaml" ] && [ "$(ls -l /etc/openclash/config.yml 2>/dev/null |awk '{print int($5/1024)}')" -gt 0 ]; then
   mv "/etc/openclash/config.yml" "/etc/openclash/config.yaml"
fi

awk '/Proxy Group:/,/Rule:/{print}' /etc/openclash/config.yaml 2>/dev/null >/tmp/yaml_group.yaml 2>&1
awk '/Proxy Group:/,/Rule:/{print}' /etc/openclash/config.yaml 2>/dev/null |egrep '^ {0,}-' |grep name: |awk -F 'name: ' '{print $2}' |sed 's/,.*//' |sed 's/\"//g' >/tmp/Proxy_Group 2>&1
echo "DIRECT" >>/tmp/Proxy_Group
echo "REJECT" >>/tmp/Proxy_Group
count=1
file_count=1
match_group_file="/tmp/Proxy_Group"
group_file="/tmp/yaml_group.yaml"
line=$(sed -n '/name:/=' $group_file)
num=$(grep -c "name:" $group_file)
   
for n in $line
do
   single_group="/tmp/group_$file_count.yaml"
   
   [ "$count" -eq 1 ] && {
      startLine="$n"
  }

   count=$(expr "$count" + 1)
   if [ "$count" -gt "$num" ]; then
      endLine=$(sed -n '$=' $group_file)
   else
      endLine=$(expr $(echo "$line" | sed -n "${count}p") - 1)
   fi
  
   sed -n "${startLine},${endLine}p" $group_file >$single_group
   startLine=$(expr "$endLine" + 1)
   
   #type
   group_type=$(grep "type:" $single_group |awk -F 'type:' '{print $2}' |sed 's/,.*//' |sed 's/\"//g' |sed 's/^ \{0,\}//g')
   #name
   group_name=$(grep "name:" $single_group |awk -F 'name:' '{print $2}' |sed 's/,.*//' |sed 's/\"//g' |sed 's/^ \{0,\}//g')
   #test_url
   group_test_url=$(grep "url:" $single_group |awk -F 'url:' '{print $2}' |sed 's/,.*//' |sed 's/\"//g' |sed 's/^ \{0,\}//g' |sed 's/ \{0,\}\}$//g' 2>/dev/null)
   #test_interval
   group_test_interval=$(grep "interval:" $single_group |awk -F 'interval:' '{print $2}' |sed 's/,.*//' |sed 's/\"//g' |sed 's/^ \{0,\}//g' |sed 's/ \{0,\}\}$//g' 2>/dev/null)

   
   
   name=openclash
   uci_name_tmp=$(uci add $name groups)
   uci_set="uci -q set $name.$uci_name_tmp."
   uci_add="uci -q add_list $name.$uci_name_tmp."
   ${uci_set}name="$group_name"
   ${uci_set}old_name="$group_name"
   ${uci_set}old_name_cfg="$group_name"
   ${uci_set}type="$group_type"
   ${uci_set}test_url="$group_test_url"
   ${uci_set}test_interval="$group_test_interval"
   
   #other_group
   cat $single_group |while read line
   do 
      if [ -z "$(echo "$line" |grep "^ \{0,\}-")" ]; then
        continue
      fi
      
      group_name1=$(echo "$line" |grep "^ \{0,\}-" 2>/dev/null |awk -F '^ \{0,\}- ' '{print $2}' 2>/dev/null |grep -v "name:" 2>/dev/null |sed 's/\"//g')
      group_name2=$(echo "$line" |awk -F 'proxies:  [' '{print $2}' 2>/dev/null |sed 's/], .*//' 2>/dev/null  |sed 's/^ \{0,\}//' 2>/dev/null  |sed 's/\{0,\} $//' 2>/dev/null |sed 's/", /#,#/g' 2>/dev/null |sed 's/",\t/#,#/g' 2>/dev/null |sed 's/\"//g')

      if [ -z "$group_name1" ] && [ -z "$group_name2" ]; then
         continue
      elif [ ! -z "$group_name1" ] && [ -z "$group_name2" ]; then
         if [ ! -z "$(grep "$group_name1" $match_group_file)" ] && [ "$group_name1" != "$group_name" ]; then
            ${uci_add}other_group="$group_name1"
         fi
      elif [ -z "$group_name1" ] && [ ! -z "$group_name2" ]; then
         group_num=$(expr $(echo "$group_name2" |grep -c "#,#") + 1)
         if [ "$group_num" -le 1 ]; then
            if [ ! -z "$(grep "$group_name2" $match_group_file)" ] && [ "$group_name2" != "$group_name" ]; then
               ${uci_add}other_group="$group_name2"
            fi
         else
            group_nums=1
            while [[ "$group_nums" -le "$group_num" ]]
            do
               if [ ! -z "$(grep "$group_name2" $match_group_file)" ] && [ "$group_name2" != "$group_name" ]; then
                  ${uci_add}other_group=$(echo "$group_name2" |awk -F '#,#' '{print $group_nums}')
               fi
               group_nums=$(expr "$group_nums" + 1)
            done
         fi
      fi
      
   done
   
   file_count=$(expr "$file_count" + 1)
    
done

uci commit openclash
/usr/share/openclash/yml_proxys_get.sh