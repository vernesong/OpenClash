#!/bin/bash
. /usr/share/openclash/log.sh
. /usr/share/openclash/openclash_etag.sh

DOWNLOAD_FILE_CURL() {
    [ -z "$1" ] || [ -z "$2" ] && return 1
    DOWNLOAD_URL=$1
    DOWNLOAD_PATH=$2
    FILE_PATH=$3
    DOWNLOAD_UA=$4
    [ -z "$DOWNLOAD_UA" ] && DOWNLOAD_UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"

    CURL_OUTPUT=$(curl -sLI --connect-timeout 5 -m 10 --speed-time 5 --speed-limit 1 --retry 2 \
        -H "User-Agent: ${DOWNLOAD_UA}" "$DOWNLOAD_URL" 2>&1)

    NEW_ETAG=$(echo "$CURL_OUTPUT" | grep -i "^etag:" | cut -d' ' -f2- | tr -d '\r\n' | sed 's/^"//;s/"$//')
    HTTP_CODE=$(echo "$CURL_OUTPUT" | grep -i "^HTTP" | tail -1 | cut -d' ' -f2)
    CACHED_ETAG=$(GET_ETAG_BY_PATH "$FILE_PATH")

    if [ "$HTTP_CODE" = "200" ] && [ -n "$NEW_ETAG" ] && [ "$NEW_ETAG" = "$CACHED_ETAG" ] && [ -e "$FILE_PATH" ]; then
        FILE_MTIME=$(date -r "$FILE_PATH" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
        LAST_UPDATE=$(GET_ETAG_TIMESTAMP_BY_PATH "$FILE_PATH")
        if [ -n "$LAST_UPDATE" ] && [ -n "$FILE_MTIME" ] && [ "$LAST_UPDATE" = "$FILE_MTIME" ]; then
            return 2
        fi
    fi

    if [ "$SHOW_DOWNLOAD_PROGRESS" = "1" ] || [ "$SHOW_DOWNLOAD_PROGRESS" = "true" ]; then
        TEMP_LOG="/tmp/curl_log_$$"

        LOG_OUT "Downloading:【$(basename "$DOWNLOAD_PATH") - 0%】"

        (
            curl -# -L --connect-timeout 10 --speed-time 20 --speed-limit 1 --retry 2 \
                -H "User-Agent: ${DOWNLOAD_UA}" \
                "$DOWNLOAD_URL" -o "$DOWNLOAD_PATH" 2>"$TEMP_LOG"
            echo $? > "${TEMP_LOG}.exit"
        ) &

        CURL_PID=$!
        LAST_PROGRESS=-1

        while kill -0 $CURL_PID 2>/dev/null; do
            if [ -f "$TEMP_LOG" ]; then
                PROGRESS_LINE=$(tr '\r' '\n' < "$TEMP_LOG" | grep '%' | tail -n 1)
                if [ -n "$PROGRESS_LINE" ]; then
                    PROGRESS=$(echo "$PROGRESS_LINE" | grep -oE '[0-9]{1,3}(\.[0-9]+)?' | tail -n 1 | cut -d. -f1)
                fi

                if [ -n "$PROGRESS" ] && [ "$PROGRESS" -ne "$LAST_PROGRESS" ]; then
                    if [ "$PROGRESS" -gt "$LAST_PROGRESS" ]; then
                        LOG_OUT "Downloading:【$(basename "$DOWNLOAD_PATH") - ${PROGRESS}%】"
                        LAST_PROGRESS="$PROGRESS"
                    fi
                fi
            fi
            sleep 1
        done

        wait $CURL_PID
        EXIR_CODE=$(cat "${TEMP_LOG}.exit" 2>/dev/null || echo "1")

        if [ "$EXIR_CODE" -eq 0 ] && [ "$LAST_PROGRESS" -ne 100 ]; then
            LOG_OUT "Downloading:【$(basename "$DOWNLOAD_PATH") - 100%】"
        fi

        if [ "$EXIR_CODE" -ne 0 ]; then
            OUTPUT=$(tr '\r' '\n' < "$TEMP_LOG" | grep -a 'curl:' | tail -n 1 | sed 's/.*curl:/curl:/')
        fi

        rm -f "$TEMP_LOG" "${TEMP_LOG}.exit"

        if [ "$EXIR_CODE" -ne 0 ]; then
            LOG_OUT "【$DOWNLOAD_PATH】Download Failed:【$OUTPUT】"
            rm -rf "$DOWNLOAD_PATH"
            SLOG_CLEAN
            return 1
        fi
    else
        CURL_OUTPUT=$(curl -w "\n%{http_code}" -SsL --connect-timeout 30 --speed-time 30 --speed-limit 1 --retry 2 -H "User-Agent: ${DOWNLOAD_UA}" "$DOWNLOAD_URL" -o "$DOWNLOAD_PATH" 2>&1)
        EXIR_CODE=$?
        HTTP_CODE=$(echo "$CURL_OUTPUT" | tail -n1)

        if [ "$EXIR_CODE" -ne 0 ] || [ "$HTTP_CODE" -ne 200 ]; then
            OUTPUT=$(echo "$CURL_OUTPUT" | sed '$d' | grep -a 'curl:' | tail -n 1)
            LOG_OUT "【$DOWNLOAD_PATH】Download Failed:【$OUTPUT】"
            rm -rf "$DOWNLOAD_PATH"
            SLOG_CLEAN
            return 1
        fi
    fi

    if [ -n "$NEW_ETAG" ] && [ "$HTTP_CODE" = "200" ]; then
        SAVE_ETAG_TO_CACHE "$DOWNLOAD_URL" "$NEW_ETAG" "$FILE_PATH"
    fi

    return 0
}