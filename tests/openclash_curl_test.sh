#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_UNDER_TEST="$REPO_ROOT/luci-app-openclash/root/usr/share/openclash/openclash_curl.sh"
WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/openclash-curl-test.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT

mkdir -p "$WORKDIR/usr/share/openclash" "$WORKDIR/bin" "$WORKDIR/tmp"

cat >"$WORKDIR/usr/share/openclash/log.sh" <<'STUB'
LOG_OUT() {
  printf '%s\n' "$*" >>"${TEST_LOG:?}"
}
SLOG_CLEAN() {
  :
}
STUB

cat >"$WORKDIR/usr/share/openclash/openclash_etag.sh" <<'STUB'
GET_ETAG_BY_PATH() {
  return 1
}
GET_ETAG_TIMESTAMP_BY_PATH() {
  return 1
}
SAVE_ETAG_TO_CACHE() {
  :
}
STUB

cp "$SCRIPT_UNDER_TEST" "$WORKDIR/openclash_curl.sh"
perl -0pi -e "s#/usr/share/openclash/#$WORKDIR/usr/share/openclash/#g" "$WORKDIR/openclash_curl.sh"

cat >"$WORKDIR/bin/curl" <<'STUB'
#!/usr/bin/env sh
status="${TEST_HTTP_STATUS:-404}"
header_file=""
output_file=""
want_write_out=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    -D)
      header_file="$2"
      shift 2
      ;;
    -o)
      output_file="$2"
      shift 2
      ;;
    -w)
      want_write_out=1
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

[ -n "$header_file" ] && printf 'HTTP/2 %s\n' "$status" >"$header_file"
[ -n "$output_file" ] && printf 'not found\n' >"$output_file"
[ "$want_write_out" -eq 1 ] && printf '\n%s\n' "$status"
exit 0
STUB
chmod +x "$WORKDIR/bin/curl"

assert_log_contains() {
  local expected="$1"
  if ! grep -F "$expected" "$TEST_LOG" >/dev/null 2>&1; then
    echo "expected log to contain: $expected" >&2
    echo "actual log:" >&2
    sed -n '1,120p' "$TEST_LOG" >&2 || true
    exit 1
  fi
}

run_download() {
  local progress="$1"
  TEST_LOG="$WORKDIR/curl-${progress}.log"
  export TEST_LOG TEST_HTTP_STATUS=404
  : >"$TEST_LOG"

  set +e
  PATH="$WORKDIR/bin:$PATH" SHOW_DOWNLOAD_PROGRESS="$progress" bash -c \
    ". '$WORKDIR/openclash_curl.sh'; DOWNLOAD_FILE_CURL 'https://example.invalid/file' '$WORKDIR/tmp/file.bin' '$WORKDIR/tmp/file.bin'"
  local status=$?
  set -e

  if [ "$status" -eq 0 ]; then
    echo "expected HTTP 404 download to fail" >&2
    exit 1
  fi
  assert_log_contains "HTTP status 404"
}

run_download 0
run_download 1

echo "openclash_curl_test.sh: PASS"
