#!/bin/sh
# ETag Cache Management Library

ETAG_CACHE="/etc/openclash/history/etag"

# 根据 path 读取时间戳
GET_ETAG_TIMESTAMP_BY_PATH() {
    local path=$1
    [ ! -f "$ETAG_CACHE" ] && return 1

    local path_hash=$(echo -n "$path" | md5sum)
    path_hash=${path_hash%% *}

    awk -v key="[$path_hash]" '
        index($0, key) == 1 { found=1; next }
        /^\[/ { found=0 }
        found && /^time=/ { value=$0; sub(/^time=/, "", value); gsub(/^"|"$/, "", value); print value; exit }
    ' "$ETAG_CACHE"
}

# 根据 path 读取 ETag
GET_ETAG_BY_PATH() {
    local path=$1
    [ ! -f "$ETAG_CACHE" ] && return 1

    local path_hash=$(echo -n "$path" | md5sum)
    path_hash=${path_hash%% *}

    awk -v key="[$path_hash]" '
        index($0, key) == 1 { found=1; next }
        /^\[/ { found=0 }
        found && /^etag=/ { value=$0; sub(/^etag=/, "", value); gsub(/^"|"$/, "", value); print value; exit }
    ' "$ETAG_CACHE"
}

# 保存或更新 ETag
SAVE_ETAG_TO_CACHE() {
    local url="\"$1\""
    local etag="\"$2\""
    local path="\"$3\""
    local time="\"$(date '+%Y-%m-%d %H:%M:%S')\""
    local path_hash=$(echo -n "$3" | md5sum)
    local lock_dir="${ETAG_CACHE}.lock"
    local temp_file="${ETAG_CACHE}.tmp.$$"
    local tries=0
    local lock_age=0
    local lock_time

    path_hash=${path_hash%% *}

    mkdir -p "$(dirname "$ETAG_CACHE")"

    until mkdir "$lock_dir" 2>/dev/null; do
        lock_time=$(date -r "$lock_dir" +%s 2>/dev/null)
        [ -n "$lock_time" ] || lock_time=$(date +%s)
        lock_age=$(( $(date +%s) - lock_time ))
        if [ "$lock_age" -ge 15 ]; then
            rm -rf "$lock_dir"
            continue
        fi
        tries=$((tries + 1))
        [ "$tries" -ge 60 ] && return 1
        sleep 1
    done

    [ ! -s "$ETAG_CACHE" ] && echo "# ETag Cache File" > "$ETAG_CACHE"

    if new_url="$url" new_etag="$etag" new_path="$path" new_time="$time" awk -v key="[$path_hash]" '
        function flush(  i, line) {
            if (!found) return
            for (i = 2; i <= bufn; i++) {
                line = bufline[i]
                if (line ~ /^url=/) url_seen = 1
                else if (line ~ /^path=/) path_seen = 1
                else if (line ~ /^etag=/) etag_seen = 1
                else if (line ~ /^time=/) time_seen = 1
            }
            print bufline[1]
            if (url_seen && path_seen && etag_seen && time_seen) {
                for (i = 2; i <= bufn; i++) {
                    line = bufline[i]
                    if (line ~ /^url=/) print "url=" new_url
                    else if (line ~ /^path=/) print "path=" new_path
                    else if (line ~ /^etag=/) print "etag=" new_etag
                    else if (line ~ /^time=/) print "time=" new_time
                    else if (line ~ /^[[:space:]]*$/) continue
                    else print line
                }
            } else {
                print "url=" new_url
                print "path=" new_path
                print "etag=" new_etag
                print "time=" new_time
            }
            found = 0
            url_seen = 0
            path_seen = 0
            etag_seen = 0
            time_seen = 0
        }
        BEGIN {
            new_url = ENVIRON["new_url"]
            new_etag = ENVIRON["new_etag"]
            new_path = ENVIRON["new_path"]
            new_time = ENVIRON["new_time"]
        }
        index($0, key) == 1 {
            flush()
            matched = 1
            found = 1
            bufn = 0
            bufline[++bufn] = $0
            next
        }
        /^\[/ {
            flush()
            print
            next
        }
        found {
            bufline[++bufn] = $0
            next
        }
        NF == 0 { next }
        { print }
        END {
            flush()
            if (!matched) {
                print key
                print "url=" new_url
                print "path=" new_path
                print "etag=" new_etag
                print "time=" new_time
            }
        }
    ' "$ETAG_CACHE" > "$temp_file"; then
        if mv -f "$temp_file" "$ETAG_CACHE"; then
            rm -rf "$lock_dir"
            return 0
        fi
    fi

    rm -f "$temp_file"
    rm -rf "$lock_dir"
    return 1
}

# 列出所有缓存
LIST_ETAG_CACHE() {
    [ ! -f "$ETAG_CACHE" ] && return 1
    cat "$ETAG_CACHE"
}