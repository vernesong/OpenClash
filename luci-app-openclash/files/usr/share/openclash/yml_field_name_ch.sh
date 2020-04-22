#!/bin/sh

YML_FILE="$1"

   #proxy-providers
	 [ -z "$(grep "^proxy-provider:" "$YML_FILE")" ] && {
      sed -i "s/^ \{1,\}proxy-provider:/proxy-provider:/g" "$YML_FILE" 2>/dev/null
   }
   [ -z "$(grep "^proxy-provider:" "$YML_FILE")" ] && {
      sed -i "s/^ \{0,\}proxy-providers:/proxy-provider:/g" "$YML_FILE" 2>/dev/null
   }
   #proxy-groups
   [ -z "$(grep "^Proxy Group:" "$YML_FILE")" ] && {
      sed -i "s/^ \{0,\}\'Proxy Group\':/Proxy Group:/g" "$YML_FILE" 2>/dev/null
      sed -i 's/^ \{0,\}\"Proxy Group\":/Proxy Group:/g' "$YML_FILE" 2>/dev/null
      sed -i "s/^ \{1,\}Proxy Group:/Proxy Group:/g" "$YML_FILE" 2>/dev/null
   }
   [ -z "$(grep "^Proxy Group:" "$YML_FILE")" ] && {
      sed -i "s/^ \{0,\}proxy-groups:/Proxy Group:/g" "$YML_FILE" 2>/dev/null
   }
   
   #proxies
   [ -z "$(grep "^Proxy:" "$YML_FILE")" ] && {
      sed -i "s/^ \{1,\}Proxy:/Proxy:/g" "$YML_FILE" 2>/dev/null
   }
   [ -z "$(grep "^Proxy:" "$YML_FILE")" ] && {
      sed -i "s/^proxies:/Proxy:/g" "$YML_FILE" 2>/dev/null
   }
   [ -z "$(grep "^Proxy:" "$YML_FILE")" ] && {
   	  group_len=$(sed -n '/^Proxy Group:/=' "$YML_FILE" 2>/dev/null)
   	  proxies_len=$(sed -n '/proxies:/=' "$YML_FILE" 2>/dev/null |sed -n 1p)
      if [ "$proxies_len" -lt "$group_len" ]; then
         sed -i "${proxies_len}s/proxies:/Proxy:/" "$YML_FILE" 2>/dev/null
      fi 2>/dev/null
   }
   
   #rules
   [ -z "$(grep "^Rule:" "$YML_FILE")" ] && {
      sed -i "s/^ \{1,\}Rule:/Rule:/g" "$YML_FILE" 2>/dev/null
   }
   [ -z "$(grep "^Rule:" "$YML_FILE")" ] && {
      sed -i "s/^ \{0,\}rules:/Rule:/g" "$YML_FILE" 2>/dev/null
   }