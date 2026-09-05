#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LGBM_SCRIPT="$REPO_ROOT/luci-app-openclash/root/usr/share/openclash/openclash_lgbm.sh"

OPENCLASH_TEST_ONLY=1 source "$LGBM_SCRIPT"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local message="$3"

  if [[ "$actual" != "$expected" ]]; then
    fail "$message (expected: $expected, actual: $actual)"
  fi
}

reset_stubs() {
  ROUTER_SELF_PROXY=1
  MIXED_PORT=7893
  CORE_RUNNING=1
  AUTH_ENABLED=()
  AUTH_USERNAME=()
  AUTH_PASSWORD=()
  DOWNLOAD_RESULTS=(0)
  DOWNLOAD_CALLS=0
  DOWNLOAD_PROXY_ARGS=()
  LOG_MESSAGES=()
  TEST_DOWNLOAD_URL="https://github.com/vernesong/mihomo/releases/download/LightGBM-Model/Model.bin"
}

uci_get_config() {
  case "$1" in
    router_self_proxy) printf '%s' "$ROUTER_SELF_PROXY" ;;
    mixed_port) printf '%s' "$MIXED_PORT" ;;
    *) return 1 ;;
  esac
}

config_load() {
  [[ "$1" == "openclash" ]]
}

config_foreach() {
  local callback="$1"
  local type="$2"
  local index

  [[ "$type" == "authentication" ]] || return 0
  for ((index = 0; index < ${#AUTH_ENABLED[@]}; index++)); do
    "$callback" "$index"
  done
}

config_get_bool() {
  local variable="$1"
  local section="$2"
  local default_value="$4"
  printf -v "$variable" '%s' "${AUTH_ENABLED[$section]:-$default_value}"
}

config_get() {
  local variable="$1"
  local section="$2"
  local option="$3"
  local default_value="$4"
  local value="$default_value"

  case "$option" in
    username) value="${AUTH_USERNAME[$section]:-$default_value}" ;;
    password) value="${AUTH_PASSWORD[$section]:-$default_value}" ;;
  esac
  printf -v "$variable" '%s' "$value"
}

pidof() {
  [[ "$1" == "clash" && "$CORE_RUNNING" == "1" ]]
}

LOG_OUT() {
  LOG_MESSAGES+=("$*")
}

DOWNLOAD_FILE_CURL() {
  local result="${DOWNLOAD_RESULTS[$DOWNLOAD_CALLS]:-1}"

  DOWNLOAD_PROXY_ARGS+=("${7-unset}|${8-unset}|${9-unset}")
  DOWNLOAD_CALLS=$((DOWNLOAD_CALLS + 1))
  return "$result"
}

run_download() {
  set +e
  download_lgbm_model "$TEST_DOWNLOAD_URL" "/tmp/Model.bin" "/etc/openclash/Model.bin"
  DOWNLOAD_STATUS=$?
  set -e
}

reset_stubs
assert_eq "http://127.0.0.1:7893" "$(lgbm_proxy_url)" "enabled router proxy should use mixed port"

reset_stubs
ROUTER_SELF_PROXY=0
if lgbm_proxy_url >/dev/null; then
  fail "disabled router-self proxy must not return a fallback URL"
fi

reset_stubs
CORE_RUNNING=0
if lgbm_proxy_url >/dev/null; then
  fail "stopped core must not return a fallback URL"
fi

for invalid_port in "" "0" "65536" "not-a-port"; do
  reset_stubs
  MIXED_PORT="$invalid_port"
  if lgbm_proxy_url >/dev/null; then
    fail "invalid proxy port '$invalid_port' must be rejected"
  fi
done

reset_stubs
DOWNLOAD_RESULTS=(0)
run_download
assert_eq "0" "$DOWNLOAD_STATUS" "direct success should be returned"
assert_eq "1" "$DOWNLOAD_CALLS" "direct success should not retry"
assert_eq "unset|unset|unset" "${DOWNLOAD_PROXY_ARGS[0]}" "direct attempt must not force a proxy"
assert_eq "0" "${#LOG_MESSAGES[@]}" "direct success should not log a retry"

reset_stubs
DOWNLOAD_RESULTS=(2)
run_download
assert_eq "2" "$DOWNLOAD_STATUS" "HTTP 304 should be returned"
assert_eq "1" "$DOWNLOAD_CALLS" "HTTP 304 should not retry"

reset_stubs
DOWNLOAD_RESULTS=(1 0)
run_download
assert_eq "0" "$DOWNLOAD_STATUS" "proxy success should recover a direct failure"
assert_eq "2" "$DOWNLOAD_CALLS" "direct failure should retry exactly once"
assert_eq "unset|unset|unset" "${DOWNLOAD_PROXY_ARGS[0]}" "first attempt must remain direct"
assert_eq "http://127.0.0.1:7893||" "${DOWNLOAD_PROXY_ARGS[1]}" "retry must use the current mixed proxy"
assert_eq "1" "${#LOG_MESSAGES[@]}" "proxy retry should be visible in the log"

reset_stubs
AUTH_ENABLED=(0 1)
AUTH_USERNAME=("disabled" "Clash")
AUTH_PASSWORD=("disabled" 'p@ss:word\quote"')
DOWNLOAD_RESULTS=(1 0)
run_download
assert_eq "0" "$DOWNLOAD_STATUS" "authenticated proxy should recover a direct failure"
assert_eq 'http://127.0.0.1:7893|Clash|p@ss:word\quote"' "${DOWNLOAD_PROXY_ARGS[1]}" "retry should use the first complete enabled authentication"

reset_stubs
TEST_DOWNLOAD_URL="https://example.test/Model.bin"
DOWNLOAD_RESULTS=(1 0)
run_download
assert_eq "1" "$DOWNLOAD_STATUS" "non-GitHub custom URL should preserve direct failure"
assert_eq "1" "$DOWNLOAD_CALLS" "non-GitHub custom URL should not self-proxy"

reset_stubs
ROUTER_SELF_PROXY=0
DOWNLOAD_RESULTS=(1 0)
run_download
assert_eq "1" "$DOWNLOAD_STATUS" "disabled router-self proxy should preserve direct failure"
assert_eq "1" "$DOWNLOAD_CALLS" "disabled router-self proxy should not retry"

reset_stubs
CORE_RUNNING=0
DOWNLOAD_RESULTS=(1 0)
run_download
assert_eq "1" "$DOWNLOAD_STATUS" "stopped core should preserve direct failure"
assert_eq "1" "$DOWNLOAD_CALLS" "stopped core should not retry"

reset_stubs
DOWNLOAD_RESULTS=(1 1)
run_download
assert_eq "1" "$DOWNLOAD_STATUS" "proxy failure should remain a failure"
assert_eq "2" "$DOWNLOAD_CALLS" "proxy failure should stop after one fallback attempt"

printf 'openclash_lgbm tests passed\n'
