#!/bin/bash

OPENCLASH_LIB_DIR="${OPENCLASH_LIB_DIR:-/usr/share/openclash}"
OPENCLASH_UPDATE_SH="${OPENCLASH_UPDATE_SH:-${OPENCLASH_LIB_DIR}/openclash_update.sh}"
OPENCLASH_CORE_SH="${OPENCLASH_CORE_SH:-${OPENCLASH_LIB_DIR}/openclash_core.sh}"
OPENCLASH_INIT_SCRIPT="${OPENCLASH_INIT_SCRIPT:-/etc/init.d/openclash}"
OPENCLASH_LOCK_DIR="${OPENCLASH_LOCK_DIR:-/tmp/lock}"
OPENCLASH_RUN_ROOT="${OPENCLASH_RUN_ROOT:-/tmp}"
OPENCLASH_UPGRADE_GUARD_FILE="${OPENCLASH_UPGRADE_GUARD_FILE:-/tmp/openclash_auto_version_update.guard}"

. "${OPENCLASH_LIB_DIR}/log.sh"
. "${OPENCLASH_LIB_DIR}/uci.sh"

AUTO_VERSION_LOCK="${OPENCLASH_LOCK_DIR}/openclash_auto_version_update.lock"
AUTO_VERSION_LOCKED=0
AUTO_VERSION_CLEANED=0
AUTO_VERSION_RUN_DIR=""
AUTO_VERSION_WAS_RUNNING=0
AUTO_VERSION_STATE_CAPTURED=0
AUTO_VERSION_UPDATED=0
AUTO_VERSION_RESTORE_FAILED=0

set_lock() {
   mkdir -p "$OPENCLASH_LOCK_DIR" || return 1
   if command -v flock >/dev/null 2>&1; then
      exec 871>"$AUTO_VERSION_LOCK" 2>/dev/null || return 1
      flock -n 871 2>/dev/null || return 1
   else
      AUTO_VERSION_LOCK="${AUTO_VERSION_LOCK}.d"
      mkdir "$AUTO_VERSION_LOCK" 2>/dev/null || return 1
   fi
   AUTO_VERSION_LOCKED=1
   return 0
}

del_lock() {
   if command -v flock >/dev/null 2>&1; then
      flock -u 871 2>/dev/null
   else
      rmdir "$AUTO_VERSION_LOCK" 2>/dev/null
   fi
}

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
   is_clash_running
}

sync_auto_version_cron() {
   [ -x "$OPENCLASH_INIT_SCRIPT" ] || return 0
   "$OPENCLASH_INIT_SCRIPT" refresh_auto_version_update_cron >/dev/null 2>&1
}

restore_runtime_state() {
   local service_action=""

   [ "$AUTO_VERSION_STATE_CAPTURED" = "1" ] || return 0

   rm -f "$OPENCLASH_UPGRADE_GUARD_FILE" 2>/dev/null

   if [ "$AUTO_VERSION_WAS_RUNNING" = "1" ]; then
      if [ "$AUTO_VERSION_UPDATED" = "1" ]; then
         service_action="restart"
      elif ! is_clash_running; then
         service_action="start"
      fi
   elif is_clash_running; then
      service_action="stop"
   fi

   if [ -n "$service_action" ]; then
      if ! "$OPENCLASH_INIT_SCRIPT" "$service_action" >/dev/null 2>&1; then
         LOG_ERROR "自动版本更新完成，但 OpenClash 运行状态恢复失败。"
         AUTO_VERSION_RESTORE_FAILED=1
      elif [ -z "${OPENCLASH_TEST_CLASH_RUNNING:-}" ]; then
         if [ "$AUTO_VERSION_WAS_RUNNING" = "1" ] && ! is_clash_running; then
            LOG_ERROR "自动版本更新完成，但 OpenClash 未能恢复运行。"
            AUTO_VERSION_RESTORE_FAILED=1
         elif [ "$AUTO_VERSION_WAS_RUNNING" = "0" ] && is_clash_running; then
            LOG_ERROR "自动版本更新完成，但 OpenClash 未能恢复停止状态。"
            AUTO_VERSION_RESTORE_FAILED=1
         fi
      fi
   fi

   if ! sync_auto_version_cron; then
      LOG_ERROR "自动版本更新完成，但定时任务恢复失败。"
      AUTO_VERSION_RESTORE_FAILED=1
   fi
}

cleanup_auto_version_update() {
   [ "$AUTO_VERSION_CLEANED" = "0" ] || return 0
   AUTO_VERSION_CLEANED=1

   restore_runtime_state

   if [ -n "$AUTO_VERSION_RUN_DIR" ] && [ -d "$AUTO_VERSION_RUN_DIR" ]; then
      case "$AUTO_VERSION_RUN_DIR" in
         "$OPENCLASH_RUN_ROOT"/openclash-auto-version.*)
            rm -rf "$AUTO_VERSION_RUN_DIR" 2>/dev/null
         ;;
      esac
   fi

   if [ "$AUTO_VERSION_LOCKED" = "1" ]; then
      del_lock
      AUTO_VERSION_LOCKED=0
   fi
}

finish_auto_version_update() {
   local status="$1"
   SLOG_CLEAN
   cleanup_auto_version_update
   if [ "$status" -eq 0 ] && [ "$AUTO_VERSION_RESTORE_FAILED" = "1" ]; then
      status=1
   fi
   trap - EXIT INT TERM
   exit "$status"
}

read_result() {
   local result_file="$1"
   sed -n '1p' "$result_file" 2>/dev/null
}

result_is_success() {
   case "$1" in
      current|updated:*) return 0 ;;
      *) return 1 ;;
   esac
}

result_is_updated() {
   case "$1" in
      updated:*) return 0 ;;
      *) return 1 ;;
   esac
}

run_with_network_mode() {
   local network_mode="$1"
   shift
   local http_port socks_port

   if [ "$network_mode" = "proxy" ]; then
      http_port=$(uci_get_config "http_port" || echo 7890)
      socks_port=$(uci_get_config "socks_port" || echo 7891)
      env \
         http_proxy="http://127.0.0.1:${http_port}" \
         https_proxy="http://127.0.0.1:${http_port}" \
         all_proxy="socks5h://127.0.0.1:${socks_port}" \
         HTTP_PROXY="http://127.0.0.1:${http_port}" \
         HTTPS_PROXY="http://127.0.0.1:${http_port}" \
         ALL_PROXY="socks5h://127.0.0.1:${socks_port}" \
         "$@"
   else
      (
         unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
         "$@"
      )
   fi
}

run_component_once() {
   local component="$1"
   local cdn_url="$2"
   local network_mode="$3"
   local result_file="$4"
   local command_path

   if [ "$component" = "package" ]; then
      command_path="$OPENCLASH_UPDATE_SH"
      OPENCLASH_LIB_DIR="$OPENCLASH_LIB_DIR" \
      OPENCLASH_LOCK_DIR="$OPENCLASH_LOCK_DIR" \
      OPENCLASH_RUN_ROOT="$OPENCLASH_RUN_ROOT" \
      OPENCLASH_AUTO_VERSION_UPDATE=1 \
      OPENCLASH_PACKAGE_ONLY=1 \
      OPENCLASH_AUTO_RUN_DIR="$AUTO_VERSION_RUN_DIR" \
      OPENCLASH_PACKAGE_RESULT_FILE="$result_file" \
      OPENCLASH_UPGRADE_GUARD_FILE="$OPENCLASH_UPGRADE_GUARD_FILE" \
      OPENCLASH_UPGRADE_GUARD_PID="$$" \
      OPENCLASH_DOWNLOAD_ATTEMPTS=1 \
      OPENCLASH_CURL_RETRIES=0 \
      OPENCLASH_CURL_CONNECT_TIMEOUT=15 \
      OPENCLASH_CURL_MAX_TIME=120 \
         run_with_network_mode "$network_mode" bash "$command_path" "$cdn_url"
   else
      command_path="$OPENCLASH_CORE_SH"
      OPENCLASH_LIB_DIR="$OPENCLASH_LIB_DIR" \
      OPENCLASH_LOCK_DIR="$OPENCLASH_LOCK_DIR" \
      OPENCLASH_RUN_ROOT="$OPENCLASH_RUN_ROOT" \
      OPENCLASH_AUTO_VERSION_UPDATE=1 \
      OPENCLASH_CORE_RESULT_FILE="$result_file" \
      OPENCLASH_AUTO_RUN_DIR="$AUTO_VERSION_RUN_DIR" \
      OPENCLASH_DOWNLOAD_ATTEMPTS=1 \
      OPENCLASH_CURL_RETRIES=0 \
      OPENCLASH_CURL_CONNECT_TIMEOUT=15 \
      OPENCLASH_CURL_MAX_TIME=120 \
         run_with_network_mode "$network_mode" bash "$command_path" "Meta" "auto_version_update" "$cdn_url"
   fi
}

update_component() {
   local component="$1"
   local display_name="$2"
   local result_file="$3"
   local index network_mode source_label cdn_url network_label status result
   local retryable_failures=0
   local source_labels=("原始地址" "fastly.jsdelivr.net" "testingcf.jsdelivr.net" "cdn.jsdelivr.net")
   local source_urls=("0" "https://fastly.jsdelivr.net/" "https://testingcf.jsdelivr.net/" "https://cdn.jsdelivr.net/")

   for index in "${!source_labels[@]}"; do
      source_label="${source_labels[$index]}"
      cdn_url="${source_urls[$index]}"

      for network_mode in direct proxy; do
         if [ "$network_mode" = "proxy" ]; then
            if ! proxy_available; then
               LOG_WARN "自动版本更新：代理路径不可用，跳过代理尝试。"
               continue
            fi
            network_label="代理"
         else
            network_label="直连"
         fi

         rm -f "$result_file" 2>/dev/null
         LOG_TIP "自动版本更新尝试${display_name}：${source_label}（${network_label}）"
         run_component_once "$component" "$cdn_url" "$network_mode" "$result_file"
         status=$?
         result=$(read_result "$result_file")

         if [ "$status" -eq 0 ] && result_is_success "$result"; then
            if result_is_updated "$result"; then
               AUTO_VERSION_UPDATED=1
               LOG_TIP "自动版本更新${display_name}成功：${source_label}（${network_label}）"
            else
               LOG_TIP "自动版本更新${display_name}：当前已是最新版本。"
            fi
            return 0
         fi

         case "$status" in
            75)
               LOG_WARN "自动版本更新跳过：${display_name}更新任务正忙。"
               return 75
            ;;
            76)
               retryable_failures=$((retryable_failures + 1))
               LOG_WARN "自动版本更新${display_name}下载失败，继续尝试下一个网络路径。"
            ;;
            *)
               [ -z "$result" ] && result="failed:unknown"
               LOG_ERROR "自动版本更新${display_name}失败：${result}"
               return 1
            ;;
         esac
      done
   done

   if [ "$retryable_failures" -gt 0 ]; then
      LOG_ERROR "自动版本更新${display_name}失败：所有下载源和网络路径均不可用。"
   else
      LOG_ERROR "自动版本更新${display_name}失败：没有可用的下载路径。"
   fi
   return 1
}

trap cleanup_auto_version_update EXIT
trap 'finish_auto_version_update 130' INT
trap 'finish_auto_version_update 143' TERM

auto_version_enabled=$(uci_get_config "auto_version_update" || echo 0)
if [ "$auto_version_enabled" != "1" ]; then
   LOG_WARN "自动版本更新跳过：功能已关闭。"
   exit 0
fi

if ! set_lock; then
   LOG_WARN "自动版本更新跳过：已有自动版本更新任务正在运行。"
   exit 0
fi

umask 077
AUTO_VERSION_RUN_DIR=$(mktemp -d "${OPENCLASH_RUN_ROOT}/openclash-auto-version.XXXXXX") || {
   LOG_ERROR "自动版本更新失败：无法创建临时目录。"
   finish_auto_version_update 1
}
chmod 700 "$AUTO_VERSION_RUN_DIR" 2>/dev/null

if is_clash_running; then
   AUTO_VERSION_WAS_RUNNING=1
fi
AUTO_VERSION_STATE_CAPTURED=1

LOG_TIP "自动版本更新开始..."

core_status=0
core_version=$(uci_get_config "core_version" || echo 0)
if [ -z "$core_version" ] || [ "$core_version" = "0" ]; then
   LOG_WARN "自动版本更新跳过内核：未选择编译版本。"
else
   update_component "core" "内核" "$AUTO_VERSION_RUN_DIR/core.result" || core_status=$?
fi

if [ "$core_status" -eq 75 ]; then
   finish_auto_version_update 0
fi

package_status=0
update_component "package" "客户端" "$AUTO_VERSION_RUN_DIR/package.result" || package_status=$?

if [ "$package_status" -eq 75 ]; then
   if [ "$core_status" -eq 0 ]; then
      finish_auto_version_update 0
   fi
   finish_auto_version_update 1
fi

if [ "$package_status" -eq 0 ] && [ "$core_status" -eq 0 ]; then
   LOG_TIP "自动版本更新完成。"
   finish_auto_version_update 0
fi

LOG_ERROR "自动版本更新完成，但部分项目更新失败。"
finish_auto_version_update 1
