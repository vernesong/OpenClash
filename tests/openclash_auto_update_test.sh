#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_ROOT/luci-app-openclash/root/usr/share/openclash/openclash_auto_version_update.sh"
TEST_TMP_DIRS=()

cleanup_tmp_dirs() {
   [ "${#TEST_TMP_DIRS[@]}" -gt 0 ] || return 0
   rm -rf "${TEST_TMP_DIRS[@]}"
}

trap cleanup_tmp_dirs EXIT

fail() {
   echo "FAIL: $*" >&2
   exit 1
}

assert_eq() {
   local expected="$1"
   local actual="$2"
   local message="$3"
   [ "$expected" = "$actual" ] || fail "$message
expected:
$expected
actual:
$actual"
}

assert_contains() {
   local needle="$1"
   local file="$2"
   grep -F "$needle" "$file" >/dev/null 2>&1 || fail "Expected '$needle' in $file"
}

assert_not_contains() {
   local needle="$1"
   local file="$2"
   if grep -F "$needle" "$file" >/dev/null 2>&1; then
      fail "Did not expect '$needle' in $file"
   fi
}

assert_call_count() {
   local expected="$1"
   local pattern="$2"
   local file="$3"
   local actual
   actual="$(grep -c "^${pattern}$" "$file" 2>/dev/null || true)"
   assert_eq "$expected" "$actual" "Unexpected call count for '$pattern'"
}

setup_case() {
   TEST_TMP="$(mktemp -d)"
   TEST_TMP_DIRS+=("$TEST_TMP")
   export TEST_TMP
   export TEST_LOG_FILE="$TEST_TMP/openclash.log"
   export TEST_COMPONENT_CALLS="$TEST_TMP/component.calls"
   export TEST_INIT_CALLS="$TEST_TMP/init.calls"
   export OPENCLASH_LIB_DIR="$TEST_TMP/lib"
   export OPENCLASH_UPDATE_SH="$TEST_TMP/openclash_update.sh"
   export OPENCLASH_CORE_SH="$TEST_TMP/openclash_core.sh"
   export OPENCLASH_INIT_SCRIPT="$TEST_TMP/openclash.init"
   export OPENCLASH_LOCK_DIR="$TEST_TMP/lock"
   export OPENCLASH_RUN_ROOT="$TEST_TMP/run"
   export OPENCLASH_UPGRADE_GUARD_FILE="$TEST_TMP/openclash-upgrade.guard"
   export OPENCLASH_TEST_CLASH_RUNNING=1
   export TEST_AUTO_VERSION_UPDATE=1
   export TEST_CORE_VERSION=linux-arm64
   export TEST_ROUTER_SELF_PROXY=0
   export TEST_PACKAGE_RESULT=current
   export TEST_PACKAGE_RC=0
   export TEST_CORE_RESULT=current
   export TEST_CORE_RC=0
   export TEST_FLOCK_BUSY=0
   export TEST_INIT_FAIL_ACTION=
   mkdir -p "$OPENCLASH_LIB_DIR" "$OPENCLASH_LOCK_DIR" "$OPENCLASH_RUN_ROOT" "$TEST_TMP/bin"
   : > "$TEST_LOG_FILE"
   : > "$TEST_COMPONENT_CALLS"
   : > "$TEST_INIT_CALLS"

   cat > "$OPENCLASH_LIB_DIR/log.sh" <<'STUB'
LOG_TIP() { echo "TIP:$*" >> "$TEST_LOG_FILE"; }
LOG_WARN() { echo "WARN:$*" >> "$TEST_LOG_FILE"; }
LOG_ERROR() { echo "ERROR:$*" >> "$TEST_LOG_FILE"; }
SLOG_CLEAN() { echo "CLEAN" >> "$TEST_LOG_FILE"; }
STUB

   cat > "$OPENCLASH_LIB_DIR/uci.sh" <<'STUB'
uci_get_config() {
   case "$1" in
      auto_version_update) printf '%s\n' "${TEST_AUTO_VERSION_UPDATE:-0}" ;;
      core_version) printf '%s\n' "${TEST_CORE_VERSION:-0}" ;;
      router_self_proxy) printf '%s\n' "${TEST_ROUTER_SELF_PROXY:-0}" ;;
      http_port) printf '%s\n' "7890" ;;
      socks_port) printf '%s\n' "7891" ;;
      *) return 1 ;;
   esac
}
STUB

   cat > "$TEST_TMP/bin/flock" <<'STUB'
#!/bin/sh
if [ "${1:-}" = "-n" ] && [ "${TEST_FLOCK_BUSY:-0}" = "1" ]; then
   exit 1
fi
exit 0
STUB

   cat > "$OPENCLASH_UPDATE_SH" <<'STUB'
#!/usr/bin/env bash
set -u
printf 'package|cdn=%s|auto=%s|package_only=%s\n' \
   "${1:-}" "${OPENCLASH_AUTO_VERSION_UPDATE:-}" "${OPENCLASH_PACKAGE_ONLY:-}" \
   >> "$TEST_COMPONENT_CALLS"
printf '%s\n' "${TEST_PACKAGE_RESULT:-current}" > "$OPENCLASH_PACKAGE_RESULT_FILE"
exit "${TEST_PACKAGE_RC:-0}"
STUB

   cat > "$OPENCLASH_CORE_SH" <<'STUB'
#!/usr/bin/env bash
set -u
printf 'core|type=%s|mode=%s|cdn=%s|auto=%s\n' \
   "${1:-}" "${2:-}" "${3:-}" "${OPENCLASH_AUTO_VERSION_UPDATE:-}" \
   >> "$TEST_COMPONENT_CALLS"
printf '%s\n' "${TEST_CORE_RESULT:-current}" > "$OPENCLASH_CORE_RESULT_FILE"
exit "${TEST_CORE_RC:-0}"
STUB

cat > "$OPENCLASH_INIT_SCRIPT" <<'STUB'
#!/bin/sh
printf '%s\n' "${1:-}" >> "$TEST_INIT_CALLS"
[ "${1:-}" = "${TEST_INIT_FAIL_ACTION:-}" ] && exit 1
exit 0
STUB

   chmod +x \
      "$TEST_TMP/bin/flock" \
      "$OPENCLASH_UPDATE_SH" \
      "$OPENCLASH_CORE_SH" \
      "$OPENCLASH_INIT_SCRIPT"
   export PATH="$TEST_TMP/bin:$PATH"
}

teardown_case() {
   rm -rf "$TEST_TMP"
   unset TEST_TMP TEST_LOG_FILE TEST_COMPONENT_CALLS TEST_INIT_CALLS
   unset OPENCLASH_LIB_DIR OPENCLASH_UPDATE_SH OPENCLASH_CORE_SH
   unset OPENCLASH_INIT_SCRIPT OPENCLASH_LOCK_DIR OPENCLASH_RUN_ROOT
   unset OPENCLASH_UPGRADE_GUARD_FILE OPENCLASH_TEST_CLASH_RUNNING
   unset TEST_AUTO_VERSION_UPDATE TEST_CORE_VERSION TEST_ROUTER_SELF_PROXY
   unset TEST_PACKAGE_RESULT TEST_PACKAGE_RC TEST_CORE_RESULT TEST_CORE_RC
   unset TEST_FLOCK_BUSY TEST_INIT_FAIL_ACTION
}

run_auto_version_update() {
   (
      unset http_proxy https_proxy all_proxy
      unset HTTP_PROXY HTTPS_PROXY ALL_PROXY
      bash "$SCRIPT"
   )
}

test_disabled_stale_cron_run_calls_nothing() {
   setup_case
   export TEST_AUTO_VERSION_UPDATE=0

   run_auto_version_update

   [ ! -s "$TEST_COMPONENT_CALLS" ] || fail "Disabled scheduled invocation must not call package or core updater"
   [ ! -s "$TEST_INIT_CALLS" ] || fail "Disabled scheduled invocation must not change runtime state"
   assert_contains "功能已关闭" "$TEST_LOG_FILE"
   teardown_case
}

test_package_and_core_are_separate_steps() {
   setup_case

   run_auto_version_update

   expected='core|type=Meta|mode=auto_version_update|cdn=0|auto=1
package|cdn=0|auto=1|package_only=1'
   actual="$(cat "$TEST_COMPONENT_CALLS")"
   assert_eq "$expected" "$actual" "Package and core should each run once with their scoped auto-update flags"
   assert_contains "自动版本更新客户端：当前已是最新版本" "$TEST_LOG_FILE"
   assert_contains "自动版本更新内核：当前已是最新版本" "$TEST_LOG_FILE"
   teardown_case
}

test_package_terminal_failure_is_not_success() {
   setup_case
   export TEST_PACKAGE_RESULT=failed:install
   export TEST_PACKAGE_RC=1

   if run_auto_version_update; then
      fail "Terminal package failure must make the scheduled run fail"
   fi

   assert_contains "自动版本更新客户端失败：failed:install" "$TEST_LOG_FILE"
   assert_contains "自动版本更新完成，但部分项目更新失败" "$TEST_LOG_FILE"
   assert_contains "core|type=Meta|mode=auto_version_update|cdn=0|auto=1" "$TEST_COMPONENT_CALLS"
   teardown_case
}

test_core_failure_keeps_successful_package_result() {
   setup_case
   export TEST_PACKAGE_RESULT=updated:0.47.200
   export TEST_CORE_RESULT=failed:install
   export TEST_CORE_RC=1

   if run_auto_version_update; then
      fail "Core terminal failure must make the aggregate scheduled run fail"
   fi

   assert_contains "自动版本更新客户端成功" "$TEST_LOG_FILE"
   assert_contains "自动版本更新内核失败：failed:install" "$TEST_LOG_FILE"
   assert_contains "自动版本更新完成，但部分项目更新失败" "$TEST_LOG_FILE"
   assert_call_count 1 "package|cdn=0|auto=1|package_only=1" "$TEST_COMPONENT_CALLS"
   assert_call_count 1 "core|type=Meta|mode=auto_version_update|cdn=0|auto=1" "$TEST_COMPONENT_CALLS"
   teardown_case
}

test_running_service_is_restored_at_most_once() {
   setup_case
   export TEST_PACKAGE_RESULT=updated:0.47.200
   export TEST_CORE_RESULT=updated:2026.07.24
   export OPENCLASH_TEST_CLASH_RUNNING=1

   run_auto_version_update

   assert_call_count 1 "restart" "$TEST_INIT_CALLS"
   assert_call_count 1 "refresh_auto_version_update_cron" "$TEST_INIT_CALLS"
   assert_call_count 0 "start" "$TEST_INIT_CALLS"
   teardown_case
}

test_stopped_service_is_not_started() {
   setup_case
   export TEST_PACKAGE_RESULT=updated:0.47.200
   export OPENCLASH_TEST_CLASH_RUNNING=0

   run_auto_version_update

   assert_call_count 0 "start" "$TEST_INIT_CALLS"
   assert_call_count 0 "restart" "$TEST_INIT_CALLS"
   assert_call_count 1 "refresh_auto_version_update_cron" "$TEST_INIT_CALLS"
   teardown_case
}

test_restore_failure_makes_run_fail() {
   setup_case
   export TEST_CORE_RESULT=updated:2026.07.24
   export TEST_INIT_FAIL_ACTION=restart

   if run_auto_version_update; then
      fail "Runtime restoration failure must make an otherwise successful run fail"
   fi

   assert_call_count 1 "restart" "$TEST_INIT_CALLS"
   assert_contains "运行状态恢复失败" "$TEST_LOG_FILE"
   teardown_case
}

test_component_busy_skips_quickly() {
   setup_case
   export TEST_CORE_RESULT=busy
   export TEST_CORE_RC=75

   run_auto_version_update

   assert_call_count 1 "core|type=Meta|mode=auto_version_update|cdn=0|auto=1" "$TEST_COMPONENT_CALLS"
   assert_not_contains "package|" "$TEST_COMPONENT_CALLS"
   assert_contains "内核更新任务正忙" "$TEST_LOG_FILE"
   teardown_case
}

test_later_busy_does_not_hide_earlier_failure() {
   setup_case
   export TEST_CORE_RESULT=failed:install
   export TEST_CORE_RC=1
   export TEST_PACKAGE_RESULT=busy
   export TEST_PACKAGE_RC=75

   if run_auto_version_update; then
      fail "A later busy package result must not hide an earlier core failure"
   fi

   assert_call_count 1 "core|type=Meta|mode=auto_version_update|cdn=0|auto=1" "$TEST_COMPONENT_CALLS"
   assert_call_count 1 "package|cdn=0|auto=1|package_only=1" "$TEST_COMPONENT_CALLS"
   assert_contains "自动版本更新内核失败：failed:install" "$TEST_LOG_FILE"
   assert_contains "客户端更新任务正忙" "$TEST_LOG_FILE"
   teardown_case
}

test_outer_lock_busy_calls_nothing() {
   setup_case
   export TEST_FLOCK_BUSY=1

   run_auto_version_update

   [ ! -s "$TEST_COMPONENT_CALLS" ] || fail "Outer lock contention must skip before calling update scripts"
   assert_contains "已有自动版本更新任务正在运行" "$TEST_LOG_FILE"
   teardown_case
}

test_disabled_stale_cron_run_calls_nothing
test_package_and_core_are_separate_steps
test_package_terminal_failure_is_not_success
test_core_failure_keeps_successful_package_result
test_running_service_is_restored_at_most_once
test_stopped_service_is_not_started
test_restore_failure_makes_run_fail
test_component_busy_skips_quickly
test_later_busy_does_not_hide_earlier_failure
test_outer_lock_busy_calls_nothing

echo "openclash_auto_update_test.sh: PASS"
