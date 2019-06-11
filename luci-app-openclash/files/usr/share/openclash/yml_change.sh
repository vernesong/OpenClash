#!/bin/sh

    if [ -z "$7" ]; then
       sed -i "/^dns:$/a\  enhanced-mode: ${2}" "$8"
    elif [ "$7" != "$2" ] && [ "$2" != "0" ]; then
       sed -i "s/${7}$/${2}/" "$8"
    fi
    if [ "$2" = "fake-ip" ]; then
       if [ ! -z "`grep "fake-ip-range:" "$8"`" ]; then
          sed -i "/fake-ip-range:/c\  fake-ip-range: 198.18.0.1/16" "$8"
       else
          sed -i "/enhanced-mode:/a\  fake-ip-range: 198.18.0.1/16" "$8"
       fi
    else
       sed -i '/fake-ip-range:/d' "$8"  2>/dev/null
    fi
    sed -i '/^##Custom DNS##$/d' "$8" 2>/dev/null

    if [ ! -z "`grep "^redir-port:" "$8"`" ]; then
       sed -i "/^redir-port:/c\redir-port: ${6}" "$8"
    else
       sed -i "3i\redir-port: ${6}" "$8"
    fi
    if [ ! -z "`grep "^external-controller:" "$8"`" ]; then
       sed -i "/^external-controller:/c\external-controller: 0.0.0.0:${5}" "$8"
    else
       sed -i "3i\external-controller: 0.0.0.0:${5}" "$8"
    fi
    if [ ! -z "`grep "^secret:" "$8"`" ]; then
       sed -i "/^secret:/c\secret: '${4}'" "$8"
    else
       sed -i "3i\secret: '${4}'" "$8"
    fi
    if [ ! -z "`grep "^  enable:" "$8"`" ]; then
       sed -i "/^  enable:/c\  enable: true" "$8"
    else
       sed -i "/^dns:/a\  enable: true" "$8"
    fi
    if [ ! -z "`grep "^allow-lan:" "$8"`" ]; then
       sed -i "/^allow-lan:/c\allow-lan: true" "$8"
    else
       sed -i "3i\allow-lan: true" "$8"
    fi
    if [ ! -z "`grep "^external-ui:" "$8"`" ]; then
       sed -i '/^external-ui:/c\external-ui: "/usr/share/openclash/dashboard"' "$8"
    else
       sed -i '3i\external-ui: "/usr/share/openclash/dashboard"' "$8"
    fi
