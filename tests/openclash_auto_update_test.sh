#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_ROOT/luci-app-openclash/root/usr/share/openclash/openclash_auto_update.sh"
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

reset_case_env() {
   unset TEST_CORE_VERSION TEST_RELEASE_BRANCH TEST_SMART_ENABLE
   unset TEST_GITHUB_ADDRESS_MOD TEST_ROUTER_SELF_PROXY
   unset TEST_MIXED_PORT TEST_HTTP_PORT TEST_SOCKS_PORT
   unset TEST_SUCCESS_AT TEST_SUCCESS_CODE OPENCLASH_TEST_CLASH_RUNNING
}

run_auto_update() {
   (
      unset http_proxy https_proxy all_proxy
      unset HTTP_PROXY HTTPS_PROXY ALL_PROXY
      bash "$SCRIPT"
   )
}

setup_case() {
   TEST_TMP="$(mktemp -d)"
   TEST_TMP_DIRS+=("$TEST_TMP")
   export TEST_TMP
   export TEST_LOG_FILE="$TEST_TMP/openclash.log"
   export TEST_CALLS_FILE="$TEST_TMP/update.calls"
   export OPENCLASH_LIB_DIR="$TEST_TMP/lib"
   export OPENCLASH_UPDATE_SH="$TEST_TMP/openclash_update.sh"
   export OPENCLASH_LOCK_DIR="$TEST_TMP/lock"
   export OPENCLASH_TEST_CLASH_RUNNING="${OPENCLASH_TEST_CLASH_RUNNING:-1}"
   mkdir -p "$OPENCLASH_LIB_DIR" "$OPENCLASH_LOCK_DIR"

   cat > "$OPENCLASH_LIB_DIR/log.sh" <<'STUB'
LOG_TIP() { echo "TIP:$*" >> "$TEST_LOG_FILE"; }
LOG_WARN() { echo "WARN:$*" >> "$TEST_LOG_FILE"; }
LOG_ERROR() { echo "ERROR:$*" >> "$TEST_LOG_FILE"; }
SLOG_CLEAN() { echo "CLEAN" >> "$TEST_LOG_FILE"; }
STUB

   cat > "$OPENCLASH_LIB_DIR/uci.sh" <<'STUB'
uci_get_config() {
   case "$1" in
      core_version) echo "${TEST_CORE_VERSION:-linux-arm64}" ;;
      release_branch) echo "${TEST_RELEASE_BRANCH:-master}" ;;
      smart_enable) echo "${TEST_SMART_ENABLE:-0}" ;;
      github_address_mod) echo "${TEST_GITHUB_ADDRESS_MOD:-0}" ;;
      router_self_proxy) echo "${TEST_ROUTER_SELF_PROXY:-1}" ;;
      mixed_port) echo "${TEST_MIXED_PORT:-7893}" ;;
      http_port) echo "${TEST_HTTP_PORT:-7890}" ;;
      socks_port) echo "${TEST_SOCKS_PORT:-7891}" ;;
      *) return 1 ;;
   esac
}
STUB

   cat > "$OPENCLASH_LIB_DIR/openclash_ps.sh" <<'STUB'
unify_ps_status() {
   if [ "${OPENCLASH_TEST_CLASH_RUNNING:-1}" = "1" ]; then
      echo 0
   else
      echo 1
   fi
}
unify_ps_pids() {
   if [ "${OPENCLASH_TEST_CLASH_RUNNING:-1}" = "1" ]; then
      echo "1234"
   else
      echo ""
   fi
}
STUB

   cat > "$OPENCLASH_UPDATE_SH" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
cdn="${2:-}"
case "$cdn" in
   "") source_label="raw" ;;
   "https://fastly.jsdelivr.net/") source_label="fastly" ;;
   "https://testingcf.jsdelivr.net/") source_label="testingcf" ;;
   "https://cdn.jsdelivr.net/") source_label="cdn" ;;
   *) source_label="$cdn" ;;
esac
if [ -n "${http_proxy:-}" ] || [ -n "${https_proxy:-}" ] || [ -n "${all_proxy:-}" ]; then
   mode_label="proxy"
else
   mode_label="direct"
fi
echo "${source_label}:${mode_label}" >> "$TEST_CALLS_FILE"
if [ "${TEST_SUCCESS_AT:-}" = "${source_label}:${mode_label}" ]; then
   exit "${TEST_SUCCESS_CODE:-0}"
fi
exit 1
STUB
   chmod +x "$OPENCLASH_UPDATE_SH"
}

teardown_case() {
   rm -rf "$TEST_TMP"
   reset_case_env
}

test_skip_without_core_version() {
   setup_case
   export TEST_CORE_VERSION=0
   run_auto_update
   [ ! -s "$TEST_CALLS_FILE" ] || fail "update script should not be called when core_version=0"
   assert_contains "自动版本更新跳过：未选择编译版本" "$TEST_LOG_FILE"
   teardown_case
}

test_source_and_proxy_order_when_all_fail() {
   setup_case
   if run_auto_update; then
      fail "expected auto update to fail when every source fails"
   fi
   expected='raw:direct
raw:proxy
fastly:direct
fastly:proxy
testingcf:direct
testingcf:proxy
cdn:direct
cdn:proxy'
   actual="$(cat "$TEST_CALLS_FILE")"
   assert_eq "$expected" "$actual" "source/proxy order mismatch"
   assert_contains "自动版本更新失败：所有下载源和网络路径均尝试失败" "$TEST_LOG_FILE"
   teardown_case
}

test_stop_after_success() {
   setup_case
   export TEST_SUCCESS_AT="fastly:proxy"
   run_auto_update
   expected='raw:direct
raw:proxy
fastly:direct
fastly:proxy'
   actual="$(cat "$TEST_CALLS_FILE")"
   assert_eq "$expected" "$actual" "auto update should stop after first successful path"
   assert_contains "自动版本更新成功：fastly.jsdelivr.net（代理）" "$TEST_LOG_FILE"
   teardown_case
}

test_proxy_skipped_when_core_not_running() {
   export OPENCLASH_TEST_CLASH_RUNNING=0
   setup_case
   if run_auto_update; then
      fail "expected failure when direct attempts fail and proxy is unavailable"
   fi
   expected='raw:direct
fastly:direct
testingcf:direct
cdn:direct'
   actual="$(cat "$TEST_CALLS_FILE")"
   assert_eq "$expected" "$actual" "proxy attempts should be skipped when core is not running"
   assert_contains "代理路径不可用，跳过代理尝试" "$TEST_LOG_FILE"
   teardown_case
}

test_skip_without_core_version
test_source_and_proxy_order_when_all_fail
test_stop_after_success
test_proxy_skipped_when_core_not_running

echo "openclash_auto_update_test.sh: PASS"
