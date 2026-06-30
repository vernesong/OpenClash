#!/bin/bash

OPENCLASH_LIB_DIR="${OPENCLASH_LIB_DIR:-/usr/share/openclash}"
OPENCLASH_UPDATE_SH="${OPENCLASH_UPDATE_SH:-${OPENCLASH_LIB_DIR}/openclash_update.sh}"
OPENCLASH_LOCK_DIR="${OPENCLASH_LOCK_DIR:-/tmp/lock}"

. "${OPENCLASH_LIB_DIR}/log.sh"
. "${OPENCLASH_LIB_DIR}/uci.sh"

AUTO_UPDATE_LOCK="${OPENCLASH_LOCK_DIR}/openclash_auto_update.lock"
AUTO_UPDATE_LOCKED=0
AUTO_UPDATE_CLEANED=0

set_lock() {
   mkdir -p "$OPENCLASH_LOCK_DIR"
   if command -v flock >/dev/null 2>&1; then
      exec 871>"$AUTO_UPDATE_LOCK" 2>/dev/null || return 1
      flock -n 871 2>/dev/null || return 1
   else
      mkdir "$AUTO_UPDATE_LOCK" 2>/dev/null || return 1
   fi
   AUTO_UPDATE_LOCKED=1
   return 0
}

del_lock() {
   if command -v flock >/dev/null 2>&1; then
      flock -u 871 2>/dev/null
   fi
   rm -rf "$AUTO_UPDATE_LOCK" 2>/dev/null
}

cleanup_auto_update() {
   [ "$AUTO_UPDATE_CLEANED" = "0" ] || return 0
   AUTO_UPDATE_CLEANED=1
   if [ "$AUTO_UPDATE_LOCKED" = "1" ]; then
      del_lock
      AUTO_UPDATE_LOCKED=0
   fi
}

finish_auto_update() {
   local status="$1"
   SLOG_CLEAN
   cleanup_auto_update
   trap - EXIT INT TERM
   exit "$status"
}

trap cleanup_auto_update EXIT
trap 'finish_auto_update 130' INT
trap 'finish_auto_update 143' TERM

is_clash_running() {
   if [ -n "${OPENCLASH_TEST_CLASH_RUNNING:-}" ]; then
      [ "$OPENCLASH_TEST_CLASH_RUNNING" = "1" ]
      return $?
   fi
   pidof clash >/dev/null 2>&1
}

proxy_available() {
   local router_self_proxy
   router_self_proxy=$(uci_get_config "router_self_proxy" || echo 1)
   [ "$router_self_proxy" = "1" ] || return 1
   is_clash_running || return 1
   return 0
}

run_update_once() {
   local cdn_url="$1"
   local network_mode="$2"
   local http_port socks_port

   if [ "$network_mode" = "proxy" ]; then
      http_port=$(uci_get_config "http_port" || echo 7890)
      socks_port=$(uci_get_config "socks_port" || echo 7891)
      if [ -n "$cdn_url" ]; then
         env OPENCLASH_AUTO_UPDATE=1 \
            http_proxy="http://127.0.0.1:${http_port}" \
            https_proxy="http://127.0.0.1:${http_port}" \
            all_proxy="socks5h://127.0.0.1:${socks_port}" \
            HTTP_PROXY="http://127.0.0.1:${http_port}" \
            HTTPS_PROXY="http://127.0.0.1:${http_port}" \
            ALL_PROXY="socks5h://127.0.0.1:${socks_port}" \
            bash "$OPENCLASH_UPDATE_SH" one_key_update "$cdn_url"
      else
         env OPENCLASH_AUTO_UPDATE=1 \
            http_proxy="http://127.0.0.1:${http_port}" \
            https_proxy="http://127.0.0.1:${http_port}" \
            all_proxy="socks5h://127.0.0.1:${socks_port}" \
            HTTP_PROXY="http://127.0.0.1:${http_port}" \
            HTTPS_PROXY="http://127.0.0.1:${http_port}" \
            ALL_PROXY="socks5h://127.0.0.1:${socks_port}" \
            bash "$OPENCLASH_UPDATE_SH" one_key_update
      fi
   else
      if [ -n "$cdn_url" ]; then
         (
            unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
            export OPENCLASH_AUTO_UPDATE=1
            bash "$OPENCLASH_UPDATE_SH" one_key_update "$cdn_url"
         )
      else
         (
            unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
            export OPENCLASH_AUTO_UPDATE=1
            bash "$OPENCLASH_UPDATE_SH" one_key_update
         )
      fi
   fi
}

try_update_path() {
   local source_label="$1"
   local cdn_url="$2"
   local network_mode="$3"
   local network_label="$4"
   local result

   LOG_TIP "自动版本更新尝试：${source_label}（${network_label}）"
   run_update_once "$cdn_url" "$network_mode"
   result=$?

   case "$result" in
      0|2)
         # Auto mode relies on openclash_update.sh returning reliable status codes.
         LOG_TIP "自动版本更新成功：${source_label}（${network_label}）"
         return 0
      ;;
      *)
         LOG_ERROR "自动版本更新失败：${source_label}（${network_label}），返回码：${result}"
         return 1
      ;;
   esac
}

if ! set_lock; then
   LOG_WARN "自动版本更新跳过：已有自动更新任务正在运行。"
   exit 0
fi

core_version=$(uci_get_config "core_version" || echo 0)
if [ -z "$core_version" ] || [ "$core_version" = "0" ]; then
   LOG_WARN "自动版本更新跳过：未选择编译版本。"
   finish_auto_update 0
fi

LOG_TIP "自动版本更新开始..."

source_labels=("原始地址" "fastly.jsdelivr.net" "testingcf.jsdelivr.net" "cdn.jsdelivr.net")
source_urls=("" "https://fastly.jsdelivr.net/" "https://testingcf.jsdelivr.net/" "https://cdn.jsdelivr.net/")

for index in "${!source_labels[@]}"; do
   if try_update_path "${source_labels[$index]}" "${source_urls[$index]}" "direct" "直连"; then
      finish_auto_update 0
   fi

   if proxy_available; then
      if try_update_path "${source_labels[$index]}" "${source_urls[$index]}" "proxy" "代理"; then
         finish_auto_update 0
      fi
   else
      LOG_WARN "自动版本更新：代理路径不可用，跳过代理尝试。"
   fi
done

LOG_ERROR "自动版本更新失败：所有下载源和网络路径均尝试失败。"
finish_auto_update 1
