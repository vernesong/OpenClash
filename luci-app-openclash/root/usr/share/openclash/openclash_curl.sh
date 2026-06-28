#!/bin/bash
. /usr/share/openclash/log.sh
. /usr/share/openclash/openclash_etag.sh

DOWNLOAD_FILE_CURL() {
    [ -z "$1" ] || [ -z "$2" ] && return 1
    DOWNLOAD_URL=$1
    DOWNLOAD_PATH=$2
    FILE_PATH=$3
    DOWNLOAD_UA=$4
    SECRET_KEY=$5
    [ -z "$DOWNLOAD_UA" ] && DOWNLOAD_UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
    HEADER_TMP="/tmp/openclash_curl_header_$$"
    DOWNLOAD_TMP="${DOWNLOAD_PATH}.download.$$"
    CACHED_ETAG=$(GET_ETAG_BY_PATH "$FILE_PATH")
    ETAG_HEADER=""

    if [ -n "$CACHED_ETAG" ] && [ -e "$FILE_PATH" ]; then
        FILE_MTIME=$(date -r "$FILE_PATH" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
        LAST_UPDATE=$(GET_ETAG_TIMESTAMP_BY_PATH "$FILE_PATH")
        if [ -n "$LAST_UPDATE" ] && [ -n "$FILE_MTIME" ] && [ "$LAST_UPDATE" = "$FILE_MTIME" ]; then
            ETAG_HEADER="If-None-Match: \"${CACHED_ETAG}\""
        fi
    fi

    rm -f "$HEADER_TMP" "$DOWNLOAD_TMP"

    if [ "$SHOW_DOWNLOAD_PROGRESS" = "1" ] || [ "$SHOW_DOWNLOAD_PROGRESS" = "true" ]; then
        TEMP_LOG="/tmp/curl_log_$$"

        LOG_OUT "Downloading:【$(basename "$DOWNLOAD_PATH") - 0%】"

        (
            if [ -n "$SECRET_KEY" ] && [ -n "$ETAG_HEADER" ]; then
                curl -# -L --connect-timeout 30 -m 180 --speed-time 30 --speed-limit 1 --retry 2 \
                    -D "$HEADER_TMP" \
                    -H "User-Agent: ${DOWNLOAD_UA}" \
                    -H "X-Age-Public-Key: ${SECRET_KEY}" \
                    -H "$ETAG_HEADER" \
                    "$DOWNLOAD_URL" -o "$DOWNLOAD_TMP" 2>"$TEMP_LOG"
            elif [ -n "$SECRET_KEY" ]; then
                curl -# -L --connect-timeout 30 -m 180 --speed-time 30 --speed-limit 1 --retry 2 \
                    -D "$HEADER_TMP" \
                    -H "User-Agent: ${DOWNLOAD_UA}" \
                    -H "X-Age-Public-Key: ${SECRET_KEY}" \
                    "$DOWNLOAD_URL" -o "$DOWNLOAD_TMP" 2>"$TEMP_LOG"
            elif [ -n "$ETAG_HEADER" ]; then
                curl -# -L --connect-timeout 30 -m 180 --speed-time 30 --speed-limit 1 --retry 2 \
                    -D "$HEADER_TMP" \
                    -H "User-Agent: ${DOWNLOAD_UA}" \
                    -H "$ETAG_HEADER" \
                    "$DOWNLOAD_URL" -o "$DOWNLOAD_TMP" 2>"$TEMP_LOG"
            else
                curl -# -L --connect-timeout 30 -m 180 --speed-time 30 --speed-limit 1 --retry 2 \
                    -D "$HEADER_TMP" \
                    -H "User-Agent: ${DOWNLOAD_UA}" \
                    "$DOWNLOAD_URL" -o "$DOWNLOAD_TMP" 2>"$TEMP_LOG"
            fi
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
        HTTP_CODE=$(grep -i "^HTTP" "$HEADER_TMP" 2>/dev/null | tail -1 | cut -d' ' -f2)

        if [ "$EXIR_CODE" -eq 0 ] && [ "$LAST_PROGRESS" -ne 100 ]; then
            LOG_OUT "Downloading:【$(basename "$DOWNLOAD_PATH") - 100%】"
        fi

        if [ "$EXIR_CODE" -ne 0 ]; then
            OUTPUT=$(tr '\r' '\n' < "$TEMP_LOG" | grep -a 'curl:' | tail -n 1 | sed 's/.*curl:/curl:/')
        fi

        rm -f "$TEMP_LOG" "${TEMP_LOG}.exit"

        if [ "$EXIR_CODE" -eq 0 ] && [ "$HTTP_CODE" = "304" ] && [ -e "$FILE_PATH" ]; then
            rm -f "$HEADER_TMP" "$DOWNLOAD_TMP"
            return 2
        fi

        if [ "$EXIR_CODE" -ne 0 ] || [ "$HTTP_CODE" != "200" ]; then
            LOG_OUT "【$DOWNLOAD_PATH】Download Failed:【$OUTPUT】"
            rm -f "$HEADER_TMP" "$DOWNLOAD_TMP"
            SLOG_CLEAN
            return 1
        fi
    else
        DOWNLOAD_TRY=0
        MAX_DOWNLOAD_RETRIES=3
        while [ "$DOWNLOAD_TRY" -lt "$MAX_DOWNLOAD_RETRIES" ]; do
            DOWNLOAD_TRY=$((DOWNLOAD_TRY + 1))
            rm -f "$HEADER_TMP" "$DOWNLOAD_TMP"
            if [ -n "$SECRET_KEY" ] && [ -n "$ETAG_HEADER" ]; then
                CURL_OUTPUT=$(curl -w "\n%{http_code}" -SsL --connect-timeout 30 -m 180 --speed-time 30 --speed-limit 1 --retry 2 \
                    -D "$HEADER_TMP" \
                    -H "User-Agent: ${DOWNLOAD_UA}" \
                    -H "X-Age-Public-Key: ${SECRET_KEY}" \
                    -H "$ETAG_HEADER" \
                    "$DOWNLOAD_URL" -o "$DOWNLOAD_TMP" 2>&1)
            elif [ -n "$SECRET_KEY" ]; then
                CURL_OUTPUT=$(curl -w "\n%{http_code}" -SsL --connect-timeout 30 -m 180 --speed-time 30 --speed-limit 1 --retry 2 \
                    -D "$HEADER_TMP" \
                    -H "User-Agent: ${DOWNLOAD_UA}" \
                    -H "X-Age-Public-Key: ${SECRET_KEY}" \
                    "$DOWNLOAD_URL" -o "$DOWNLOAD_TMP" 2>&1)
            elif [ -n "$ETAG_HEADER" ]; then
                CURL_OUTPUT=$(curl -w "\n%{http_code}" -SsL --connect-timeout 30 -m 180 --speed-time 30 --speed-limit 1 --retry 2 \
                    -D "$HEADER_TMP" \
                    -H "User-Agent: ${DOWNLOAD_UA}" \
                    -H "$ETAG_HEADER" \
                    "$DOWNLOAD_URL" -o "$DOWNLOAD_TMP" 2>&1)
            else
                CURL_OUTPUT=$(curl -w "\n%{http_code}" -SsL --connect-timeout 30 -m 180 --speed-time 30 --speed-limit 1 --retry 2 \
                    -D "$HEADER_TMP" \
                    -H "User-Agent: ${DOWNLOAD_UA}" "$DOWNLOAD_URL" -o "$DOWNLOAD_TMP" 2>&1)
            fi
            EXIR_CODE=$?
            HTTP_CODE=$(echo "$CURL_OUTPUT" | tail -n1)
            if { [ "$EXIR_CODE" -eq 0 ] && [ "$HTTP_CODE" = "200" ]; } || { [ "$EXIR_CODE" -eq 0 ] && [ "$HTTP_CODE" = "304" ] && [ -e "$FILE_PATH" ]; }; then
                break
            fi
            [ "$DOWNLOAD_TRY" -lt "$MAX_DOWNLOAD_RETRIES" ] && sleep 1
        done

        if [ "$EXIR_CODE" -eq 0 ] && [ "$HTTP_CODE" = "304" ] && [ -e "$FILE_PATH" ]; then
            rm -f "$HEADER_TMP" "$DOWNLOAD_TMP"
            return 2
        fi

        if [ "$EXIR_CODE" -ne 0 ] || [ "$HTTP_CODE" != "200" ]; then
            OUTPUT=$(echo "$CURL_OUTPUT" | sed '$d' | grep -a 'curl:' | tail -n 1)
            LOG_OUT "【$DOWNLOAD_PATH】Download Failed:【$OUTPUT】"
            rm -f "$HEADER_TMP" "$DOWNLOAD_TMP"
            SLOG_CLEAN
            return 1
        fi
    fi

    if ! mv -f "$DOWNLOAD_TMP" "$DOWNLOAD_PATH"; then
        LOG_OUT "【$DOWNLOAD_PATH】Download Failed:【Unable to save download file】"
        rm -f "$HEADER_TMP" "$DOWNLOAD_TMP"
        SLOG_CLEAN
        return 1
    fi
    NEW_ETAG=$(grep -i "^etag:" "$HEADER_TMP" 2>/dev/null | tail -1 | cut -d' ' -f2- | tr -d '\r\n' | sed 's/^"//;s/"$//')

    if [ -n "$NEW_ETAG" ] && [ "$HTTP_CODE" = "200" ]; then
        SAVE_ETAG_TO_CACHE "$DOWNLOAD_URL" "$NEW_ETAG" "$FILE_PATH"
    fi

    rm -f "$HEADER_TMP" "$DOWNLOAD_TMP"

    return 0
}
