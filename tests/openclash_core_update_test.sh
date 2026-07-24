#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_ROOT/luci-app-openclash/root/usr/share/openclash/openclash_core.sh"
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

assert_empty() {
   local file="$1"
   [ ! -s "$file" ] || fail "Expected $file to be empty"
}

inode_of() {
   stat -f '%i' "$1" 2>/dev/null || stat -c '%i' "$1"
}

setup_case() {
   TEST_TMP="$(mktemp -d)"
   TEST_TMP_DIRS+=("$TEST_TMP")
   export TEST_TMP
   export TEST_LOG_FILE="$TEST_TMP/openclash.log"
   export TEST_DOWNLOAD_CALLS="$TEST_TMP/download.calls"
   export TEST_VERSION_CALLS="$TEST_TMP/version.calls"
   export TEST_JOB_CALLS="$TEST_TMP/job.calls"
   export OPENCLASH_LIB_DIR="$TEST_TMP/lib"
   export OPENCLASH_LOCK_DIR="$TEST_TMP/lock"
   export OPENCLASH_RUN_ROOT="$TEST_TMP/run"
   export OPENCLASH_CLASH_VERSION_SH="$TEST_TMP/clash_version.sh"
   export OPENCLASH_CORE_VERSION_FILE="$TEST_TMP/state/clash_last_version"
   export OPENCLASH_CORE_TARGET_PATH="$TEST_TMP/core dir/clash_meta"
   export OPENCLASH_CORE_RESULT_FILE="$TEST_TMP/state/core.result"
   export OPENCLASH_AUTO_VERSION_UPDATE=1
   export TEST_META_VERSION=meta-new
   export TEST_SMART_VERSION=smart-new
   export TEST_CORE_TYPE=Meta
   export TEST_SMART_ENABLE=0
   export TEST_OIX_TOKEN=
   export TEST_CORE_PLATFORM=linux-amd64
   export TEST_RELEASE_BRANCH=master
   export TEST_SMALL_FLASH_MEMORY=0
   export TEST_GITHUB_ADDRESS_MOD=0
   export TEST_FLOCK_BUSY=0
   export TEST_DOWNLOAD_RC=0
   export TEST_ARCHIVE_SOURCE=
   mkdir -p \
      "$OPENCLASH_LIB_DIR" \
      "$OPENCLASH_LOCK_DIR" \
      "$OPENCLASH_RUN_ROOT" \
      "$(dirname "$OPENCLASH_CORE_VERSION_FILE")" \
      "$(dirname "$OPENCLASH_CORE_TARGET_PATH")" \
      "$TEST_TMP/bin"
   : > "$TEST_LOG_FILE"
   : > "$TEST_DOWNLOAD_CALLS"
   : > "$TEST_VERSION_CALLS"
   : > "$TEST_JOB_CALLS"

   cat > "$OPENCLASH_LIB_DIR/log.sh" <<'STUB'
LOG_TIP() { echo "TIP:$*" >> "$TEST_LOG_FILE"; }
LOG_WARN() { echo "WARN:$*" >> "$TEST_LOG_FILE"; }
LOG_ERROR() { echo "ERROR:$*" >> "$TEST_LOG_FILE"; }
SLOG_CLEAN() { echo "CLEAN" >> "$TEST_LOG_FILE"; }
STUB

   cat > "$OPENCLASH_LIB_DIR/uci.sh" <<'STUB'
uci_get_config() {
   case "$1" in
      github_address_mod) printf '%s\n' "${TEST_GITHUB_ADDRESS_MOD:-0}" ;;
      core_type) printf '%s\n' "${TEST_CORE_TYPE:-Meta}" ;;
      smart_enable) printf '%s\n' "${TEST_SMART_ENABLE:-0}" ;;
      oix_token) printf '%s\n' "${TEST_OIX_TOKEN:-}" ;;
      small_flash_memory) printf '%s\n' "${TEST_SMALL_FLASH_MEMORY:-0}" ;;
      core_version) printf '%s\n' "${TEST_CORE_PLATFORM:-0}" ;;
      release_branch) printf '%s\n' "${TEST_RELEASE_BRANCH:-master}" ;;
      *) return 1 ;;
   esac
}
STUB

   cat > "$OPENCLASH_LIB_DIR/openclash_curl.sh" <<'STUB'
DOWNLOAD_FILE_CURL() {
   printf 'download|url=%s|output=%s|target=%s\n' "$1" "$2" "$3" >> "$TEST_DOWNLOAD_CALLS"
   [ "${TEST_DOWNLOAD_RC:-0}" -eq 0 ] || return "$TEST_DOWNLOAD_RC"
   cp "$TEST_ARCHIVE_SOURCE" "$2"
}
STUB

   cat > "$OPENCLASH_LIB_DIR/openclash_ps.sh" <<'STUB'
inc_job_counter() {
   printf '%s\n' 'inc' >> "$TEST_JOB_CALLS"
}
dec_job_counter_and_restart() {
   printf 'dec:%s\n' "${1:-}" >> "$TEST_JOB_CALLS"
}
STUB

   cat > "$OPENCLASH_CLASH_VERSION_SH" <<'STUB'
#!/usr/bin/env bash
set -u
printf 'version|source=%s|file=%s|auto=%s\n' \
   "${1:-0}" "$OPENCLASH_CORE_VERSION_FILE" "${OPENCLASH_AUTO_VERSION_UPDATE:-}" \
   >> "$TEST_VERSION_CALLS"
mkdir -p "$(dirname "$OPENCLASH_CORE_VERSION_FILE")"
printf '%s\n%s\n' "$TEST_META_VERSION" "$TEST_SMART_VERSION" > "$OPENCLASH_CORE_VERSION_FILE"
exit 0
STUB

   cat > "$TEST_TMP/bin/flock" <<'STUB'
#!/bin/sh
if [ "${1:-}" = "-n" ] && [ "${TEST_FLOCK_BUSY:-0}" = "1" ]; then
   exit 1
fi
exit 0
STUB

   chmod +x "$OPENCLASH_CLASH_VERSION_SH" "$TEST_TMP/bin/flock"
   export PATH="$TEST_TMP/bin:$PATH"
}

teardown_case() {
   rm -rf "$TEST_TMP"
   unset TEST_TMP TEST_LOG_FILE TEST_DOWNLOAD_CALLS TEST_VERSION_CALLS TEST_JOB_CALLS
   unset OPENCLASH_LIB_DIR OPENCLASH_LOCK_DIR OPENCLASH_RUN_ROOT
   unset OPENCLASH_CLASH_VERSION_SH OPENCLASH_CORE_VERSION_FILE
   unset OPENCLASH_CORE_TARGET_PATH OPENCLASH_CORE_RESULT_FILE
   unset OPENCLASH_AUTO_VERSION_UPDATE TEST_META_VERSION TEST_SMART_VERSION
   unset TEST_CORE_TYPE TEST_SMART_ENABLE TEST_OIX_TOKEN TEST_CORE_PLATFORM
   unset TEST_RELEASE_BRANCH TEST_SMALL_FLASH_MEMORY TEST_GITHUB_ADDRESS_MOD
   unset TEST_FLOCK_BUSY TEST_DOWNLOAD_RC TEST_ARCHIVE_SOURCE
}

make_core_executable() {
   local output_path="$1"
   local family="$2"
   local version="$3"
   mkdir -p "$(dirname "$output_path")"
   printf '%s\n' \
      '#!/bin/sh' \
      "printf '%s\\n' 'Mihomo ${family} ${version}'" \
      > "$output_path"
   chmod +x "$output_path"
}

make_meta_archive() {
   local version="$1"
   local family="${2:-Meta}"
   local build_dir="$TEST_TMP/archive-build-${family}-${version}"
   local archive_path="$TEST_TMP/${family}-${version}.tar.gz"
   mkdir -p "$build_dir"
   make_core_executable "$build_dir/clash" "$family" "$version"
   tar -czf "$archive_path" -C "$build_dir" clash
   export TEST_ARCHIVE_SOURCE="$archive_path"
}

make_oix_archive() {
   local version="$1"
   local core_path="$TEST_TMP/oix-${version}"
   local archive_path="$TEST_TMP/oix-${version}.gz"
   make_core_executable "$core_path" Oix "$version"
   gzip -c "$core_path" > "$archive_path"
   export TEST_ARCHIVE_SOURCE="$archive_path"
}

run_core_update() {
   bash "$SCRIPT" Meta auto_version_update 0
}

assert_no_staging_leftovers() {
   local leftovers
   leftovers="$(find "$(dirname "$OPENCLASH_CORE_TARGET_PATH")" "$OPENCLASH_RUN_ROOT" \
      -name '*.new.*' -o -name 'openclash-core.*' 2>/dev/null || true)"
   [ -z "$leftovers" ] || fail "Core update left staging files behind:
$leftovers"
}

test_meta_success_reads_version_and_atomically_replaces_core() {
   setup_case
   make_core_executable "$OPENCLASH_CORE_TARGET_PATH" Meta meta-old
   old_inode="$(inode_of "$OPENCLASH_CORE_TARGET_PATH")"
   make_meta_archive meta-new

   run_core_update

   new_inode="$(inode_of "$OPENCLASH_CORE_TARGET_PATH")"
   assert_eq "updated:meta-new" "$(cat "$OPENCLASH_CORE_RESULT_FILE")" "Meta update should publish the selected version"
   assert_eq "meta-new" "$("$OPENCLASH_CORE_TARGET_PATH" -v | awk '{print $3}')" "Installed Meta core should report the downloaded version"
   [ "$old_inode" != "$new_inode" ] || fail "Successful core update should replace the target inode atomically"
   assert_contains "master/meta/clash-linux-amd64.tar.gz" "$TEST_DOWNLOAD_CALLS"
   assert_contains "target=$OPENCLASH_CORE_TARGET_PATH" "$TEST_DOWNLOAD_CALLS"
   assert_empty "$TEST_JOB_CALLS"
   assert_no_staging_leftovers
   teardown_case
}

test_corrupt_archive_returns_76_and_preserves_old_core() {
   setup_case
   make_core_executable "$OPENCLASH_CORE_TARGET_PATH" Meta meta-old
   old_inode="$(inode_of "$OPENCLASH_CORE_TARGET_PATH")"
   old_checksum="$(cksum "$OPENCLASH_CORE_TARGET_PATH")"
   corrupt_archive="$TEST_TMP/corrupt.tar.gz"
   printf '%s\n' 'not a gzip archive' > "$corrupt_archive"
   export TEST_ARCHIVE_SOURCE="$corrupt_archive"

   set +e
   run_core_update
   status=$?
   set -e

   assert_eq 76 "$status" "Corrupt archive should be retryable in automatic mode"
   assert_eq "retry:archive" "$(cat "$OPENCLASH_CORE_RESULT_FILE")" "Corrupt archive should publish its retry reason"
   assert_eq "$old_inode" "$(inode_of "$OPENCLASH_CORE_TARGET_PATH")" "Corrupt archive must not replace the old core"
   assert_eq "$old_checksum" "$(cksum "$OPENCLASH_CORE_TARGET_PATH")" "Corrupt archive must not alter the old core"
   assert_eq "meta-old" "$("$OPENCLASH_CORE_TARGET_PATH" -v | awk '{print $3}')" "Old core should remain executable after archive failure"
   assert_eq 1 "$(grep -c '^download|' "$TEST_DOWNLOAD_CALLS")" "Automatic mode should make one bounded download attempt"
   assert_no_staging_leftovers
   teardown_case
}

test_core_lock_busy_returns_75_without_version_check_or_download() {
   setup_case
   make_core_executable "$OPENCLASH_CORE_TARGET_PATH" Meta meta-old
   old_checksum="$(cksum "$OPENCLASH_CORE_TARGET_PATH")"
   export TEST_FLOCK_BUSY=1

   set +e
   run_core_update
   status=$?
   set -e

   assert_eq 75 "$status" "Busy core lock should return the dedicated busy status"
   assert_eq "busy" "$(cat "$OPENCLASH_CORE_RESULT_FILE")" "Busy core lock should publish a busy result"
   assert_empty "$TEST_VERSION_CALLS"
   assert_empty "$TEST_DOWNLOAD_CALLS"
   assert_eq "$old_checksum" "$(cksum "$OPENCLASH_CORE_TARGET_PATH")" "Busy update must not alter the installed core"
   teardown_case
}

test_smart_uses_second_version_line() {
   setup_case
   export TEST_SMART_ENABLE=1
   export TEST_META_VERSION=meta-other
   export TEST_SMART_VERSION=smart-new
   make_core_executable "$OPENCLASH_CORE_TARGET_PATH" Smart smart-old
   make_meta_archive smart-new Smart

   run_core_update

   assert_eq "updated:smart-new" "$(cat "$OPENCLASH_CORE_RESULT_FILE")" "Smart update should select the second version-file line"
   assert_eq "smart-new" "$("$OPENCLASH_CORE_TARGET_PATH" -v | awk '{print $3}')" "Installed Smart core should report the second-line version"
   assert_contains "master/smart/clash-linux-amd64.tar.gz" "$TEST_DOWNLOAD_CALLS"
   assert_no_staging_leftovers
   teardown_case
}

test_oix_uses_gzip_payload_path() {
   setup_case
   export TEST_CORE_TYPE=Oix
   export TEST_META_VERSION=oix-new
   make_core_executable "$OPENCLASH_CORE_TARGET_PATH" Oix oix-old
   make_oix_archive oix-new

   run_core_update

   assert_eq "updated:oix-new" "$(cat "$OPENCLASH_CORE_RESULT_FILE")" "OIX update should publish the first-line version"
   assert_eq "oix-new" "$("$OPENCLASH_CORE_TARGET_PATH" -v | awk '{print $3}')" "Installed OIX core should come from the gzip payload"
   assert_contains "mihomo-linux-amd64-oix-new.gz?tag=Pre-Alpha" "$TEST_DOWNLOAD_CALLS"
   assert_no_staging_leftovers
   teardown_case
}

test_meta_success_reads_version_and_atomically_replaces_core
test_corrupt_archive_returns_76_and_preserves_old_core
test_core_lock_busy_returns_75_without_version_check_or_download
test_smart_uses_second_version_line
test_oix_uses_gzip_payload_path

echo "openclash_core_update_test.sh: PASS"
