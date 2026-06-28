#!/usr/bin/env bash
set -eo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

SCRIPT_UNDER_TEST="$TMP_DIR/openclash_curl.sh"
STUB_DIR="$TMP_DIR/stubs"
BIN_DIR="$TMP_DIR/bin"
mkdir -p "$STUB_DIR" "$BIN_DIR"

awk -v stub_dir="$STUB_DIR" '
  $0 == ". /usr/share/openclash/log.sh" {
    print ". \"" stub_dir "/log.sh\""
    next
  }
  $0 == ". /usr/share/openclash/openclash_etag.sh" {
    print ". \"" stub_dir "/openclash_etag.sh\""
    next
  }
  { print }
' "$REPO_ROOT/luci-app-openclash/root/usr/share/openclash/openclash_curl.sh" > "$SCRIPT_UNDER_TEST"

cat > "$STUB_DIR/log.sh" <<'STUB'
LOG_OUT() { printf '%s\n' "$1" >> "$TEST_LOG"; }
SLOG_CLEAN() { :; }
STUB

cat > "$STUB_DIR/openclash_etag.sh" <<'STUB'
GET_ETAG_BY_PATH() {
  [ -n "${TEST_CACHED_ETAG:-}" ] && printf '%s\n' "$TEST_CACHED_ETAG"
}

GET_ETAG_TIMESTAMP_BY_PATH() {
  [ -n "${TEST_CACHED_TIME:-}" ] && printf '%s\n' "$TEST_CACHED_TIME"
}

SAVE_ETAG_TO_CACHE() {
  printf '%s|%s|%s\n' "$1" "$2" "$3" >> "$TEST_ETAG_SAVE_LOG"
}
STUB

cat > "$BIN_DIR/curl" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$TEST_CURL_CALLS"

is_head=0
header_file=""
output_file=""
write_http=0
if_none_match=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    -*I*)
      is_head=1
      ;;
    -D)
      shift
      header_file="$1"
      ;;
    -o)
      shift
      output_file="$1"
      ;;
    -w)
      shift
      write_http=1
      ;;
    -H)
      shift
      case "$1" in
        If-None-Match:*) if_none_match=1 ;;
      esac
      ;;
  esac
  shift || true
done

if [ "$is_head" -eq 1 ]; then
  touch "$TEST_HEAD_SEEN"
  printf 'HTTP/2 200\r\netag: "etag-new"\r\ncontent-length: 7\r\n\r\n'
  exit 0
fi

if [ -f "$TEST_HEAD_SEEN" ]; then
  printf 'curl: (35) TLS connect error: error:00000000:lib(0)::reason(0)\n' >&2
  [ "$write_http" -eq 1 ] && printf '\n000'
  exit 35
fi

if [ "${TEST_FAIL_FIRST_GET:-0}" = "1" ] && [ ! -f "$TEST_FIRST_GET_FAILED" ]; then
  touch "$TEST_FIRST_GET_FAILED"
  printf 'curl: (35) TLS connect error: error:00000000:lib(0)::reason(0)\n' >&2
  [ "$write_http" -eq 1 ] && printf '\n000'
  exit 35
fi

if [ "$if_none_match" -eq 1 ]; then
  [ -n "$header_file" ] && printf 'HTTP/2 304\r\netag: "etag-old"\r\n\r\n' > "$header_file"
  [ "$write_http" -eq 1 ] && printf '\n304'
  exit 0
fi

[ -n "$header_file" ] && printf 'HTTP/2 200\r\netag: "etag-new"\r\ncontent-length: 7\r\n\r\n' > "$header_file"
[ -n "$output_file" ] && printf 'payload' > "$output_file"
[ "$write_http" -eq 1 ] && printf '\n200'
exit 0
STUB
chmod +x "$BIN_DIR/curl"

cat > "$BIN_DIR/date" <<'STUB'
#!/usr/bin/env bash
if [ "${1:-}" = "-r" ]; then
  printf '%s\n' "${TEST_FILE_MTIME:-2026-01-01 00:00:00}"
else
  /bin/date "$@"
fi
STUB
chmod +x "$BIN_DIR/date"

run_case() {
  local name="$1"
  shift
  local case_dir="$TMP_DIR/$name"
  mkdir -p "$case_dir"
  export TEST_LOG="$case_dir/log"
  export TEST_CURL_CALLS="$case_dir/curl_calls"
  export TEST_ETAG_SAVE_LOG="$case_dir/etag_save"
  export TEST_HEAD_SEEN="$case_dir/head_seen"
  export TEST_FIRST_GET_FAILED="$case_dir/first_get_failed"
  export PATH="$BIN_DIR:$PATH"
  : > "$TEST_LOG"
  : > "$TEST_CURL_CALLS"
  : > "$TEST_ETAG_SAVE_LOG"
  rm -f "$TEST_HEAD_SEEN"
  rm -f "$TEST_FIRST_GET_FAILED"
  "$@"
}

assert_file_contains() {
  local file="$1"
  local expected="$2"
  if ! grep -Fq -- "$expected" "$file"; then
    printf 'Expected %s to contain: %s\n' "$file" "$expected" >&2
    printf 'Actual:\n' >&2
    cat "$file" >&2
    return 1
  fi
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local message="$3"
  if [ "$actual" != "$expected" ]; then
    printf '%s: expected %s, got %s\n' "$message" "$expected" "$actual" >&2
    return 1
  fi
}

assert_file_missing() {
  local file="$1"
  if [ -e "$file" ]; then
    printf 'Expected %s to be absent\n' "$file" >&2
    return 1
  fi
}

test_download_uses_single_get_with_headers() {
  local output="$TMP_DIR/downloaded"
  rm -f "$output"
  unset TEST_CACHED_ETAG TEST_CACHED_TIME
  # shellcheck disable=SC1090
  . "$SCRIPT_UNDER_TEST"

  set +e
  DOWNLOAD_FILE_CURL "https://example.com/file" "$output" "$output"
  local rc=$?
  set -e

  assert_eq "$rc" "0" "download rc"
  assert_eq "$(cat "$output" 2>/dev/null)" "payload" "downloaded payload"
  assert_eq "$(wc -l < "$TEST_CURL_CALLS" | tr -d ' ')" "1" "curl call count"
  if grep -Eq '(^| )-[^ ]*I' "$TEST_CURL_CALLS"; then
    printf 'DOWNLOAD_FILE_CURL must not issue a separate HEAD request\n' >&2
    cat "$TEST_CURL_CALLS" >&2
    return 1
  fi
  assert_file_contains "$TEST_CURL_CALLS" "-D"
  assert_file_contains "$TEST_ETAG_SAVE_LOG" "https://example.com/file|etag-new|$output"
}

test_conditional_get_returns_not_modified() {
  local output="$TMP_DIR/cached"
  printf 'cached' > "$output"
  export TEST_CACHED_ETAG="etag-old"
  export TEST_CACHED_TIME="2026-01-01 00:00:00"
  export TEST_FILE_MTIME="2026-01-01 00:00:00"
  # shellcheck disable=SC1090
  . "$SCRIPT_UNDER_TEST"

  set +e
  DOWNLOAD_FILE_CURL "https://example.com/file" "$output.tmp" "$output"
  local rc=$?
  set -e

  assert_eq "$rc" "2" "not modified rc"
  assert_eq "$(cat "$output")" "cached" "cached payload"
  assert_file_missing "$output.tmp"
  assert_eq "$(wc -l < "$TEST_CURL_CALLS" | tr -d ' ')" "1" "curl call count"
  assert_file_contains "$TEST_CURL_CALLS" "If-None-Match: \"etag-old\""
}

test_download_retries_tls_connect_error() {
  local output="$TMP_DIR/retried"
  rm -f "$output"
  unset TEST_CACHED_ETAG TEST_CACHED_TIME TEST_FILE_MTIME
  export TEST_FAIL_FIRST_GET=1
  # shellcheck disable=SC1090
  . "$SCRIPT_UNDER_TEST"

  set +e
  DOWNLOAD_FILE_CURL "https://example.com/file" "$output" "$output"
  local rc=$?
  set -e
  unset TEST_FAIL_FIRST_GET

  assert_eq "$rc" "0" "download rc"
  assert_eq "$(cat "$output" 2>/dev/null)" "payload" "downloaded payload"
  assert_eq "$(wc -l < "$TEST_CURL_CALLS" | tr -d ' ')" "2" "curl call count"
}

run_case "single_get" test_download_uses_single_get_with_headers
run_case "not_modified" test_conditional_get_returns_not_modified
run_case "retry_tls" test_download_retries_tls_connect_error

printf 'openclash_curl tests passed\n'
