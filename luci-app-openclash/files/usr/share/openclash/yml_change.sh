#!/bin/sh

    if [ -z "$7" ]; then
       if [ "$2" -ne 0 ]; then
          sed -i "/^dns:/a\  enhanced-mode: ${2}" "$8"
       else
          sed -i "/^dns:/a\  enhanced-mode: redir-host" "$8"
       fi
    elif [ "$7" != "$2" ] && [ "$2" != "0" ]; then
       sed -i "/^ \{0,\}enhanced-mode:/c\  enhanced-mode: ${2}" "$8"
    else
       sed -i "/^ \{0,\}enhanced-mode:/c\  enhanced-mode: ${7}" "$8"
    fi
    if [ "$2" = "fake-ip" ]; then
       if [ ! -z "`grep "^ \{0,\}fake-ip-range:" "$8"`" ]; then
          sed -i "/^ \{0,\}fake-ip-range:/c\  fake-ip-range: 198.18.0.1/16" "$8"
       else
          sed -i "/enhanced-mode:/a\  fake-ip-range: 198.18.0.1/16" "$8"
       fi
    else
       sed -i '/^ \{0,\}fake-ip-range:/d' "$8"  2>/dev/null
    fi
    sed -i '/^##Custom DNS##$/d' "$8" 2>/dev/null


    if [ -z "`grep '^redir-port: $6' "$8"`" ]; then
       if [ ! -z "`grep "^redir-port:" "$8"`" ]; then
          sed -i "/^redir-port:/c\redir-port: ${6}" "$8"
       else
          sed -i "3i\redir-port: ${6}" "$8"
       fi
    fi
    
    if [ -z "`grep '^port: $10' "$8"`" ]; then
       if [ ! -z "`grep "^port:" "$8"`" ]; then
          sed -i "/^port:/c\port: ${10}" "$8"
       else
          sed -i "3i\port: ${10}" "$8"
       fi
    fi
    
    if [ -z "`grep '^socks-port: $11' "$8"`" ]; then
       if [ ! -z "`grep "^socks-port:" "$8"`" ]; then
          sed -i "/^socks-port:/c\socks-port: ${11}" "$8"
       else
          sed -i "3i\socks-port: ${11}" "$8"
       fi
    fi
    
    if [ -z "`grep '^external-controller: 0.0.0.0:$5' "$8"`" ]; then
       if [ ! -z "`grep "^external-controller:" "$8"`" ]; then
          sed -i "/^external-controller:/c\external-controller: 0.0.0.0:${5}" "$8"
       else
          sed -i "3i\external-controller: 0.0.0.0:${5}" "$8"
       fi
    fi
    
    if [ -z "`grep '^secret: $4' "$8"`" ]; then
       if [ ! -z "`grep "^secret:" "$8"`" ]; then
          sed -i "/^secret:/c\secret: '${4}'" "$8"
       else
          sed -i "3i\secret: '${4}'" "$8"
       fi
    fi

    if [ -z "`grep "^   enable: true" "$8"`" ]; then
       if [ ! -z "`grep "^ \{0,\}enable:" "$8"`" ]; then
          sed -i "/^ \{0,\}enable:/c\  enable: true" "$8"
       else
          sed -i "/^dns:/a\  enable: true" "$8"
       fi
    fi
    
    if [ -z "`grep "^allow-lan: true" "$8"`" ]; then
       if [ ! -z "`grep "^allow-lan:" "$8"`" ]; then
          sed -i "/^allow-lan:/c\allow-lan: true" "$8"
       else
          sed -i "3i\allow-lan: true" "$8"
       fi
    fi
    
    if [ -z "`grep '^external-ui: "/usr/share/openclash/dashboard"' "$8"`" ]; then
       if [ ! -z "`grep "^external-ui:" "$8"`" ]; then
          sed -i '/^external-ui:/c\external-ui: "/usr/share/openclash/dashboard"' "$8"
       else
          sed -i '3i\external-ui: "/usr/share/openclash/dashboard"' "$8"
       fi
    fi

    if [ "$9" -eq 1 ]; then
       if [ -z "`grep "  ipv6: true" "$8"`" ]; then
          if [ ! -z "`grep "^ \{0,\}ipv6:" "$8"`" ]; then
             sed -i "/^ \{0,\}ipv6:/c\  ipv6: true" "$8"
          else
             sed -i "/^ \{0,\}enable: true/i\  ipv6: true" "$8"
          fi
       fi
    else
       if [ -z "`grep "  ipv6: falsev" "$8"`" ]; then
          if [ ! -z "`grep "^ \{0,\}ipv6:" "$8"`" ]; then
             sed -i "/^ \{0,\}ipv6:/c\  ipv6: false" "$8"
          else
             sed -i "/^ \{0,\}enable: true/i\  ipv6: false" "$8"
          fi
       fi
    fi
