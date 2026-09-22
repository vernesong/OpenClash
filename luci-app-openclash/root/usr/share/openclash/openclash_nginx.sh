#!/bin/sh
# Same-origin reverse proxy for the mihomo control API (https://<luci host>/oc-api/, see
# ocGetDashboardApiOrigin in common.js), an https page cannot open ws://. -n skips the
# reload for callers that reload nginx themselves.

[ -d /etc/nginx/conf.d ] || exit 0

PORT=$(uci -q get openclash.config.cn_port)
[ -n "$PORT" ] || PORT=9090
FILE=/etc/nginx/conf.d/openclash.locations

NEW=$(cat <<EOF
location /oc-api/ {
        proxy_pass http://127.0.0.1:${PORT}/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_buffering off;
}
EOF
)

if [ -f "$FILE" ] && [ "$(cat "$FILE")" = "$NEW" ]; then
	exit 0
fi

printf '%s\n' "$NEW" > "$FILE"

[ "$1" = "-n" ] || /etc/init.d/nginx reload >/dev/null 2>&1
exit 0
