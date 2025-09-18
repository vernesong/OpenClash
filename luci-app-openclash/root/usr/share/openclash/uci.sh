#!/bin/sh

uci_get_config() {
    local key="$1"
    local val
    val=$(uci -q get openclash.@overwrite[0]."$key" 2>/dev/null)
    if [ -n "$val" ]; then
        echo "$val"
    else
        uci -q get openclash.config."$key"
    fi
}