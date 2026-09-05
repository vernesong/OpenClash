#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CURL_SCRIPT="$REPO_ROOT/luci-app-openclash/root/usr/share/openclash/openclash_curl.sh"
TEST_TMP="$(mktemp -d)"
CURL_UNDER_TEST="$TEST_TMP/openclash_curl.sh"
CURL_ARGS_FILE="$TEST_TMP/curl.args"
CURL_CONFIG_FILE="$TEST_TMP/curl.config"
CURL_ENV_FILE="$TEST_TMP/curl.env"
CURL_CALLS_FILE="$TEST_TMP/curl.calls"
LOG_FILE="$TEST_TMP/openclash.log"

cleanup() {
  rm -rf -- "$TEST_TMP"
}
trap cleanup EXIT

sed \
  -e '\|^\. /usr/share/openclash/log\.sh$|d' \
  -e '\|^\. /usr/share/openclash/openclash_etag\.sh$|d' \
  "$CURL_SCRIPT" > "$CURL_UNDER_TEST"

GET_ETAG_BY_PATH() {
  return 0
}

GET_ETAG_TIMESTAMP_BY_PATH() {
  return 0
}

SAVE_ETAG_TO_CACHE() {
  return 0
}

LOG_OUT() {
  printf '%s\n' "$*" >> "$LOG_FILE"
}

SLOG_CLEAN() {
  return 0
}

curl() {
  local header_file=""
  local output_file=""
  local read_config=0
  local argument

  printf 'call\n' >> "$CURL_CALLS_FILE"
  printf '%s\n' "$@" > "$CURL_ARGS_FILE"
  env > "$CURL_ENV_FILE"
  for argument in "$@"; do
    if [[ "$argument" == "--config" ]]; then
      read_config=1
      break
    fi
  done
  if [[ "$read_config" == "1" ]]; then
    cat > "$CURL_CONFIG_FILE"
  else
    : > "$CURL_CONFIG_FILE"
  fi

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -D)
        header_file="$2"
        shift 2
        ;;
      -o)
        output_file="$2"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done

  if [[ "${CURL_BEHAVIOR:-success}" == "failure" ]]; then
    printf 'HTTP/1.1 502 Bad Gateway\r\n' > "$header_file"
    printf 'partial-data' > "$output_file"
    printf '\n502'
  else
    printf 'HTTP/1.1 200 OK\r\n' > "$header_file"
    printf 'model-data' > "$output_file"
    printf '\n200'
  fi
}

source "$CURL_UNDER_TEST"
SHOW_DOWNLOAD_PROGRESS=0
CURL_BEHAVIOR=success

DOWNLOAD_CURL_CONFIG_VALUE_SAFE "plain-value"
if DOWNLOAD_CURL_CONFIG_VALUE_SAFE $'line\nbreak' ||
   DOWNLOAD_CURL_CONFIG_VALUE_SAFE $'carriage\rreturn'; then
  printf 'FAIL: curl config value accepted CR or LF\n' >&2
  exit 1
fi

proxy_url="http://127.0.0.1:7893"
proxy_user="Clash"
proxy_password='p@ss:word\quote"'
download_path="$TEST_TMP/Model.bin"
model_path="$TEST_TMP/current.bin"

set +e
DOWNLOAD_FILE_CURL \
  "https://github.com/vernesong/mihomo/releases/download/LightGBM-Model/Model.bin" \
  "$download_path" "$model_path" "" "" "" \
  "$proxy_url" "$proxy_user" "$proxy_password"
download_status=$?
set -e

[[ "$download_status" == "0" ]]
[[ "$(cat "$download_path")" == "model-data" ]]
grep -Fx -- "--proxy" "$CURL_ARGS_FILE" >/dev/null
grep -Fx -- "$proxy_url" "$CURL_ARGS_FILE" >/dev/null
grep -Fx -- "--config" "$CURL_ARGS_FILE" >/dev/null
if grep -F -- "$proxy_user" "$CURL_ARGS_FILE" >/dev/null ||
   grep -F -- "$proxy_password" "$CURL_ARGS_FILE" >/dev/null; then
  printf 'FAIL: proxy credentials leaked into curl argv\n' >&2
  exit 1
fi
if grep -F -- "$proxy_password" "$CURL_ENV_FILE" >/dev/null; then
  printf 'FAIL: proxy password leaked into curl environment\n' >&2
  exit 1
fi
expected_config='proxy-user = "Clash:p@ss:word\\quote\""'
grep -Fx -- "$expected_config" "$CURL_CONFIG_FILE" >/dev/null
if grep -F -- "$proxy_password" "$LOG_FILE" >/dev/null 2>&1; then
  printf 'FAIL: proxy password leaked into logs\n' >&2
  exit 1
fi

SHOW_DOWNLOAD_PROGRESS=1
: > "$CURL_CALLS_FILE"
rm -f "$download_path"
set +e
DOWNLOAD_FILE_CURL \
  "https://github.com/vernesong/mihomo/releases/download/LightGBM-Model/Model.bin" \
  "$download_path" "$model_path" "" "" "" \
  "$proxy_url" "$proxy_user" "$proxy_password" >/dev/null
download_status=$?
set -e

[[ "$download_status" == "0" ]]
[[ "$(cat "$download_path")" == "model-data" ]]
[[ "$(wc -l < "$CURL_CALLS_FILE" | tr -d ' ')" == "1" ]]
grep -Fx -- "--proxy" "$CURL_ARGS_FILE" >/dev/null
grep -Fx -- "$proxy_url" "$CURL_ARGS_FILE" >/dev/null
grep -Fx -- "--config" "$CURL_ARGS_FILE" >/dev/null
if grep -F -- "$proxy_user" "$CURL_ARGS_FILE" >/dev/null ||
   grep -F -- "$proxy_password" "$CURL_ARGS_FILE" >/dev/null ||
   grep -F -- "$proxy_password" "$CURL_ENV_FILE" >/dev/null ||
   grep -F -- "$proxy_password" "$LOG_FILE" >/dev/null 2>&1; then
  printf 'FAIL: progress download leaked proxy credentials\n' >&2
  exit 1
fi

SHOW_DOWNLOAD_PROGRESS=0
set +e
DOWNLOAD_FILE_CURL \
  "https://github.com/vernesong/mihomo/releases/download/LightGBM-Model/Model.bin" \
  "$download_path" "$model_path" "" "" "" "$proxy_url"
download_status=$?
set -e

[[ "$download_status" == "0" ]]
grep -Fx -- "--proxy" "$CURL_ARGS_FILE" >/dev/null
if grep -Fx -- "--config" "$CURL_ARGS_FILE" >/dev/null; then
  printf 'FAIL: unauthenticated proxy unexpectedly used a curl config\n' >&2
  exit 1
fi

injected_marker="injected-review"
injected_password=$'secret\nuser-agent = injected-review\n#'
: > "$CURL_CALLS_FILE"
rm -f "$download_path"
printf 'old-model' > "$model_path"
set +e
DOWNLOAD_FILE_CURL \
  "https://github.com/vernesong/mihomo/releases/download/LightGBM-Model/Model.bin" \
  "$download_path" "$model_path" "" "" "" \
  "$proxy_url" "$proxy_user" "$injected_password"
download_status=$?
set -e

[[ "$download_status" == "1" ]]
[[ "$(cat "$model_path")" == "old-model" ]]
[[ ! -e "$download_path" ]]
[[ ! -s "$CURL_CALLS_FILE" ]]
if grep -F -- "$injected_marker" \
  "$CURL_ARGS_FILE" "$CURL_CONFIG_FILE" "$CURL_ENV_FILE" "$LOG_FILE" >/dev/null 2>&1; then
  printf 'FAIL: control characters changed curl configuration or leaked\n' >&2
  exit 1
fi

CURL_BEHAVIOR=failure
: > "$CURL_CALLS_FILE"
rm -f "$download_path"
printf 'old-model' > "$model_path"
set +e
DOWNLOAD_FILE_CURL \
  "https://github.com/vernesong/mihomo/releases/download/LightGBM-Model/Model.bin" \
  "$download_path" "$model_path" "" "" "" "$proxy_url"
download_status=$?
set -e

[[ "$download_status" == "1" ]]
[[ "$(cat "$model_path")" == "old-model" ]]
[[ ! -e "$download_path" ]]
[[ "$(wc -l < "$CURL_CALLS_FILE" | tr -d ' ')" == "3" ]]

printf 'openclash_curl proxy tests passed\n'
