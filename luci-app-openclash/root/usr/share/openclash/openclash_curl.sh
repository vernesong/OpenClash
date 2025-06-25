#!/bin/bash
. /usr/share/openclash/log.sh

DOWNLOAD_FILE_CURL() {
    [ -z "$1" ] || [ -z "$2" ] && return 1
    DOWNLOAD_URL=$1
    DOWNLOAD_PATH=$2
    DOWNLOAD_UA=$3
    [ -z "$DOWNLOAD_UA" ] && DOWNLOAD_UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
    
    if [ "$SHOW_DOWNLOAD_PROGRESS" = "1" ] || [ "$SHOW_DOWNLOAD_PROGRESS" = "true" ]; then
        TEMP_LOG="/tmp/curl_progress_$$"
        
        LOG_OUT "Downloading:【$(basename "$DOWNLOAD_PATH") - 0%】"
        
        (
            curl --progress-bar -L --connect-timeout 30 -m 60 --speed-time 30 --speed-limit 1 --retry 2 \
                -H "User-Agent: ${DOWNLOAD_UA}" \
                --write-out "CURL_STATUS: %{http_code} %{size_download} %{size_total}\n" \
                "$DOWNLOAD_URL" -o "$DOWNLOAD_PATH" 2>"$TEMP_LOG"
            echo $? > "${TEMP_LOG}.exit"
        ) &
        
        CURL_PID=$!
        LAST_PROGRESS=-1
        
        while kill -0 $CURL_PID 2>/dev/null; do
            if [ -f "$TEMP_LOG" ]; then
                PROGRESS=$(tail -n5 "$TEMP_LOG" 2>/dev/null | grep -oE '([0-9]{1,3})%' | tail -n1 | grep -oE '[0-9]+')
                
                if [ -z "$PROGRESS" ]; then
                    SIZE_INFO=$(tail -n5 "$TEMP_LOG" 2>/dev/null | grep "CURL_STATUS:" | tail -n1)
                    if [ -n "$SIZE_INFO" ]; then
                        DOWNLOADED=$(echo "$SIZE_INFO" | awk '{print $3}')
                        TOTAL=$(echo "$SIZE_INFO" | awk '{print $4}')
                        if [ -n "$DOWNLOADED" ] && [ -n "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
                            PROGRESS=$((DOWNLOADED * 100 / TOTAL))
                        fi
                    fi
                fi
                
                if [ -n "$PROGRESS" ] && [ "$PROGRESS" -ne "$LAST_PROGRESS" ]; then
                    PROGRESS_DIFF=$((PROGRESS - LAST_PROGRESS))
                    if [ "$PROGRESS_DIFF" -ge 5 ] || [ "$PROGRESS" -eq 100 ] || [ "$LAST_PROGRESS" -eq -1 ]; then
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
        
        OUTPUT=$(cat "$TEMP_LOG" 2>/dev/null | sed '$d' | sed ':a;N;$!ba; s/\n/ /g')
        
        rm -f "$TEMP_LOG" "${TEMP_LOG}.exit"
        
        if [ "$EXIR_CODE" -ne 0 ]; then
            LOG_OUT "【$DOWNLOAD_PATH】Download Failed:【$OUTPUT】"
            rm -rf $DOWNLOAD_PATH
            SLOG_CLEAN
            return 1
        else
            return 0
        fi
    else
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
    fi
}