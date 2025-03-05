#!/bin/bash
. /usr/share/openclash/log.sh

DOWNLOAD_FILE_CURL() {
	[ -z "$1" ] || [ -z "$2" ] && return 1
	DOWNLOAD_URL=$1
	DOWNLOAD_PATH=$2
	DOWNLOAD_UA=$3
	[ -z "$DOWNLOAD_UA" ] && DOWNLOAD_UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
	OUTPUT=$(curl -w "%{http_code}" -SsL --connect-timeout 30 -m 60 --speed-time 30 --speed-limit 1 --retry 2 -H "User-Agent: ${DOWNLOAD_UA}" "$DOWNLOAD_URL" -o "$DOWNLOAD_PATH" 2>&1)
	EXIR_CODE=${PIPESTATUS[0]}
	HTTP_CODE=$(echo "$OUTPUT" | tail -n1)
	OUTPUT=$(echo "$OUTPUT" | sed '$d' | sed ':a;N;$!ba; s/\n/ /g')
	if [ "$EXIR_CODE" -ne 0 ] || [ "$HTTP_CODE" -ne 200 ]; then
		LOG_OUT "【$DOWNLOAD_PATH】Download Failed:【$OUTPUT】"
		rm -rf $DOWNLOAD_PATH
		SLOG_CLEAN
		return 1
	else
		return 0
	fi
}
