#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/openclash-version-state-test.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT

mkdir -p "$WORKDIR/usr/share/openclash" "$WORKDIR/tmp/lock" "$WORKDIR/lib"

cat >"$WORKDIR/usr/share/openclash/openclash_curl.sh" <<'STUB'
DOWNLOAD_FILE_CURL() {
   if [ -n "${OPENCLASH_TEST_CURL_COUNT_FILE:-}" ]; then
      count="$(cat "$OPENCLASH_TEST_CURL_COUNT_FILE" 2>/dev/null || echo 0)"
      echo $((count + 1)) >"$OPENCLASH_TEST_CURL_COUNT_FILE"
   fi

   case "${OPENCLASH_TEST_DOWNLOAD_RESULT:-0}" in
      0)
         if [ "${OPENCLASH_TEST_VERSION_KIND:-core}" = "package" ]; then
            printf 'v9.99.9\nhttps://example.invalid/pkg\n' >"$2"
         else
            printf 'new-core\nnew-smart\n' >"$2"
         fi
         return 0
      ;;
      2)
         return 2
      ;;
      *)
         return 1
      ;;
   esac
}
STUB

cat >"$WORKDIR/usr/share/openclash/uci.sh" <<'STUB'
uci_get_config() {
   return 1
}
STUB

cat >"$WORKDIR/usr/share/openclash/log.sh" <<'STUB'
LOG_ERROR() {
   printf '%s\n' "$*" >>"${OPENCLASH_TEST_LOG:-/dev/null}"
}
LOG_TIP() {
   printf '%s\n' "$*" >>"${OPENCLASH_TEST_LOG:-/dev/null}"
}
SLOG_CLEAN() {
   :
}
STUB

cat >"$WORKDIR/usr/share/openclash/openclash_ps.sh" <<'STUB'
inc_job_counter() {
   printf 'inc\n' >>"${OPENCLASH_TEST_JOBS:-/dev/null}"
}
dec_job_counter_and_restart() {
   printf 'dec:%s\n' "$1" >>"${OPENCLASH_TEST_JOBS:-/dev/null}"
}
STUB

touch "$WORKDIR/lib/functions.sh"

copy_script() {
   local src="$1"
   local dst="$2"

   cp "$REPO_ROOT/$src" "$dst"
   perl -0pi -e "s#/usr/share/openclash/#$WORKDIR/usr/share/openclash/#g; s#/lib/functions\\.sh#$WORKDIR/lib/functions.sh#g; s#/tmp/lock/#$WORKDIR/tmp/lock/#g; s#/tmp/clash_last_version#$WORKDIR/tmp/clash_last_version#g; s#/tmp/openclash_last_version#$WORKDIR/tmp/openclash_last_version#g" "$dst"
   chmod +x "$dst"
}

copy_script "luci-app-openclash/root/usr/share/openclash/clash_version.sh" "$WORKDIR/clash_version.sh"
copy_script "luci-app-openclash/root/usr/share/openclash/openclash_version.sh" "$WORKDIR/openclash_version.sh"
cp "$WORKDIR/clash_version.sh" "$WORKDIR/usr/share/openclash/clash_version.sh"
cp "$WORKDIR/openclash_version.sh" "$WORKDIR/usr/share/openclash/openclash_version.sh"
copy_script "luci-app-openclash/root/usr/share/openclash/openclash_core.sh" "$WORKDIR/openclash_core.sh"
copy_script "luci-app-openclash/root/usr/share/openclash/openclash_update.sh" "$WORKDIR/openclash_update.sh"

printf 'stale-core\n' >"$WORKDIR/tmp/clash_last_version"
if OPENCLASH_TEST_DOWNLOAD_RESULT=1 "$WORKDIR/clash_version.sh"; then
   echo "expected failed core version check to return non-zero" >&2
   exit 1
fi
[ ! -e "$WORKDIR/tmp/clash_last_version" ] || {
   echo "failed core version check should not leave stale version state" >&2
   exit 1
}

OPENCLASH_TEST_DOWNLOAD_RESULT=0 "$WORKDIR/clash_version.sh"
[ "$(sed -n 1p "$WORKDIR/tmp/clash_last_version")" = "new-core" ] || {
   echo "successful core version check did not publish new state" >&2
   exit 1
}

printf 'cached-core\n' >"$WORKDIR/tmp/clash_last_version"
OPENCLASH_TEST_DOWNLOAD_RESULT=2 "$WORKDIR/clash_version.sh"
[ "$(sed -n 1p "$WORKDIR/tmp/clash_last_version")" = "cached-core" ] || {
   echo "304 core version check should keep cached state" >&2
   exit 1
}
rm -f "$WORKDIR/tmp/clash_last_version"
if OPENCLASH_TEST_DOWNLOAD_RESULT=2 "$WORKDIR/clash_version.sh"; then
   echo "304 core version check without cached state should fail closed" >&2
   exit 1
fi

printf 'v1.2.3\nhttps://stale.invalid/pkg\n' >"$WORKDIR/tmp/openclash_last_version"
if OPENCLASH_TEST_VERSION_KIND=package OPENCLASH_TEST_DOWNLOAD_RESULT=1 "$WORKDIR/openclash_version.sh"; then
   echo "expected failed package version check to return non-zero" >&2
   exit 1
fi
[ ! -e "$WORKDIR/tmp/openclash_last_version" ] || {
   echo "failed package version check should not leave stale version state" >&2
   exit 1
}

OPENCLASH_TEST_VERSION_KIND=package OPENCLASH_TEST_DOWNLOAD_RESULT=0 "$WORKDIR/openclash_version.sh"
[ "$(sed -n 1p "$WORKDIR/tmp/openclash_last_version")" = "v9.99.9" ] || {
   echo "successful package version check did not publish new state" >&2
   exit 1
}

printf 'v7.7.7\nhttps://cached.invalid/pkg\n' >"$WORKDIR/tmp/openclash_last_version"
OPENCLASH_TEST_VERSION_KIND=package OPENCLASH_TEST_DOWNLOAD_RESULT=2 "$WORKDIR/openclash_version.sh"
[ "$(sed -n 1p "$WORKDIR/tmp/openclash_last_version")" = "v7.7.7" ] || {
   echo "304 package version check should keep cached state" >&2
   exit 1
}
rm -f "$WORKDIR/tmp/openclash_last_version"
if OPENCLASH_TEST_VERSION_KIND=package OPENCLASH_TEST_DOWNLOAD_RESULT=2 "$WORKDIR/openclash_version.sh"; then
   echo "304 package version check without cached state should fail closed" >&2
   exit 1
fi

rg -Fq 'VERSION_CHECK_RESULT=$?' "$REPO_ROOT/luci-app-openclash/root/usr/share/openclash/openclash_core.sh"
rg -Fq 'VERSION_CHECK_RESULT=$?' "$REPO_ROOT/luci-app-openclash/root/usr/share/openclash/openclash_update.sh"

printf 'v1.2.3\nhttps://stale.invalid/pkg\n' >"$WORKDIR/tmp/openclash_last_version"
echo 0 >"$WORKDIR/update-count"
OPENCLASH_TEST_VERSION_KIND=package \
OPENCLASH_TEST_DOWNLOAD_RESULT=1 \
OPENCLASH_TEST_CURL_COUNT_FILE="$WORKDIR/update-count" \
OPENCLASH_TEST_LOG="$WORKDIR/update.log" \
   "$WORKDIR/openclash_update.sh"
[ "$(cat "$WORKDIR/update-count")" = "1" ] || {
   echo "package update caller should stop after failed version refresh" >&2
   exit 1
}
grep -q "Failed to get version information" "$WORKDIR/update.log" || {
   echo "package update caller did not report failed version refresh" >&2
   exit 1
}

printf 'stale-core\n' >"$WORKDIR/tmp/clash_last_version"
echo 0 >"$WORKDIR/core-count"
OPENCLASH_TEST_DOWNLOAD_RESULT=1 \
OPENCLASH_TEST_CURL_COUNT_FILE="$WORKDIR/core-count" \
OPENCLASH_TEST_LOG="$WORKDIR/core.log" \
OPENCLASH_TEST_JOBS="$WORKDIR/core-jobs.log" \
   "$WORKDIR/openclash_core.sh" Meta
[ "$(cat "$WORKDIR/core-count")" = "1" ] || {
   echo "core update caller should stop after failed version refresh" >&2
   exit 1
}
grep -q '^dec:0$' "$WORKDIR/core-jobs.log" || {
   echo "core update caller did not decrement job counter after failed version refresh" >&2
   exit 1
}
grep -q "Core Version Check Error" "$WORKDIR/core.log" || {
   echo "core update caller did not report failed version refresh" >&2
   exit 1
}

echo "openclash_version_state tests passed"
