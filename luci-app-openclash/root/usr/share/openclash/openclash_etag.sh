#!/bin/sh
# ETag Cache Management Library

ETAG_CACHE="/etc/openclash/history/etag"

# 根据 path 读取时间戳
GET_ETAG_TIMESTAMP_BY_PATH() {
    local path=$1
    [ ! -f "$ETAG_CACHE" ] && return 1

    local path_hash=$(echo -n "$path" | md5sum | cut -d' ' -f1)

    awk -v hash="$path_hash" '
        $0 ~ "^\\[" hash "\\]" { found=1; next }
        /^\[/ { found=0 }
        found && /^time=/ { print $0; exit }
    ' "$ETAG_CACHE" | cut -d'=' -f2- | sed 's/^"//;s/"$//'
}

# 根据 path 读取 ETag
GET_ETAG_BY_PATH() {
    local path=$1
    [ ! -f "$ETAG_CACHE" ] && return 1

    local path_hash=$(echo -n "$path" | md5sum | cut -d' ' -f1)

    awk -v hash="$path_hash" '
        $0 ~ "^\\[" hash "\\]" { found=1; next }
        /^\[/ { found=0 }
        found && /^etag=/ { print $0; exit }
    ' "$ETAG_CACHE" | cut -d'=' -f2- | sed 's/^"//;s/"$//'
}

# 保存或更新 ETag
SAVE_ETAG_TO_CACHE() {
    local url="\"$1\""
    local etag="\"$2\""
    local path="\"$3\""
    local time="\"$(date '+%Y-%m-%d %H:%M:%S')\""
    local path_hash=$(echo -n "$3" | md5sum | cut -d' ' -f1)

    mkdir -p "$(dirname "$ETAG_CACHE")"

    [ ! -f "$ETAG_CACHE" ] && echo "# ETag Cache File" > "$ETAG_CACHE"

    if grep -q "^\[$path_hash\]" "$ETAG_CACHE"; then
        local temp_file="${ETAG_CACHE}.tmp"
        awk -v hash="$path_hash" \
            -v new_url="$url" \
            -v new_etag="$etag" \
            -v new_path="$path" \
            -v new_time="$time" '
            $0 ~ "^\\[" hash "\\]" {
                print;
                found=1;
                next
            }
            /^\[/ { found=0 }
            found && /^url=/ {
                print "url=" new_url;
                next
            }
            found && /^path=/ {
                print "path=" new_path;
                next
            }
            found && /^etag=/ {
                print "etag=" new_etag;
                next
            }
            found && /^time=/ {
                print "time=" new_time;
                next
            }
            { print }
        ' "$ETAG_CACHE" > "$temp_file" && mv "$temp_file" "$ETAG_CACHE"
    else
        cat >> "$ETAG_CACHE" << EOF

[$path_hash]
url=$url
path=$path
etag=$etag
time=$time
EOF
    fi
}

# 列出所有缓存
LIST_ETAG_CACHE() {
    [ ! -f "$ETAG_CACHE" ] && return 1
    cat "$ETAG_CACHE"
}