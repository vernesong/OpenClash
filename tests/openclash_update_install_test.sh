#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_ROOT/luci-app-openclash/root/usr/share/openclash/openclash_update_install.sh"
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

setup_case() {
   TEST_TMP="$(mktemp -d)"
   TEST_TMP_DIRS+=("$TEST_TMP")
   export TEST_TMP
   export TEST_LOG_FILE="$TEST_TMP/openclash.log"
   export TEST_OPKG_CALLS="$TEST_TMP/opkg.calls"
   export TEST_OPKG_STATE="$TEST_TMP/installed.version"
   export OPENCLASH_LIB_DIR="$TEST_TMP/lib"
   export OPENCLASH_INSTALL_LOCK="$TEST_TMP/lock/openclash_update_install.lock"
   export OPENCLASH_OPKG_BIN="$TEST_TMP/bin/opkg"
   export OPENCLASH_APK_BIN="$TEST_TMP/bin/missing-apk"
   export TEST_INSTALL_RC=0
   export TEST_VERSION_AFTER=0.47.200
   export TEST_FLOCK_BUSY=0
   mkdir -p "$OPENCLASH_LIB_DIR" "$TEST_TMP/bin" "$TEST_TMP/lock"
   : > "$TEST_LOG_FILE"
   : > "$TEST_OPKG_CALLS"
   printf '%s\n' '0.47.100' > "$TEST_OPKG_STATE"

   cat > "$OPENCLASH_LIB_DIR/log.sh" <<'STUB'
LOG_TIP() { echo "TIP:$*" >> "$TEST_LOG_FILE"; }
LOG_WARN() { echo "WARN:$*" >> "$TEST_LOG_FILE"; }
LOG_ERROR() { echo "ERROR:$*" >> "$TEST_LOG_FILE"; }
SLOG_CLEAN() { echo "CLEAN" >> "$TEST_LOG_FILE"; }
STUB

   cat > "$OPENCLASH_LIB_DIR/openclash_ps.sh" <<'STUB'
dec_job_counter_and_restart() {
   printf 'restart:%s\n' "${1:-}" >> "$TEST_LOG_FILE"
}
STUB

   cat > "$TEST_TMP/bin/flock" <<'STUB'
#!/bin/sh
if [ "${1:-}" = "-n" ] && [ "${TEST_FLOCK_BUSY:-0}" = "1" ]; then
   exit 1
fi
exit 0
STUB

   cat > "$OPENCLASH_OPKG_BIN" <<'STUB'
#!/bin/sh
command_name="$1"
printf '%s' "$1" >> "$TEST_OPKG_CALLS"
shift
for arg in "$@"; do
   printf '|%s' "$arg" >> "$TEST_OPKG_CALLS"
done
printf '\n' >> "$TEST_OPKG_CALLS"

case "$command_name" in
   status)
      if [ "${1:-}" = "luci-app-openclash" ]; then
         printf 'Package: luci-app-openclash\n'
         printf 'Version: %s\n' "$(cat "$TEST_OPKG_STATE")"
         exit 0
      fi
      exit 1
   ;;
   install)
      if [ "${TEST_INSTALL_RC:-0}" -eq 0 ]; then
         printf '%s\n' "${TEST_VERSION_AFTER:-}" > "$TEST_OPKG_STATE"
      fi
      exit "${TEST_INSTALL_RC:-0}"
   ;;
esac

exit 1
STUB

   chmod +x "$TEST_TMP/bin/flock" "$OPENCLASH_OPKG_BIN"
   export PATH="$TEST_TMP/bin:$PATH"
}

teardown_case() {
   rm -rf "$TEST_TMP"
   unset TEST_TMP TEST_LOG_FILE TEST_OPKG_CALLS TEST_OPKG_STATE
   unset OPENCLASH_LIB_DIR OPENCLASH_INSTALL_LOCK
   unset OPENCLASH_OPKG_BIN OPENCLASH_APK_BIN
   unset TEST_INSTALL_RC TEST_VERSION_AFTER TEST_FLOCK_BUSY
}

make_package() {
   local package_path="$1"
   mkdir -p "$(dirname "$package_path")"
   printf '%s\n' 'fake package payload' > "$package_path"
}

run_installer() {
   local package_path="$1"
   local target_version="$2"
   local result_file="$3"
   sh "$SCRIPT" "$package_path" "$target_version" "$result_file" 1 0 \
      "$TEST_TMP/openclash-upgrade.guard" "$$"
}

test_success_requires_matching_version_readback() {
   setup_case
   package_path="$TEST_TMP/run/openclash.ipk"
   result_file="$TEST_TMP/run/package.result"
   make_package "$package_path"
   export TEST_VERSION_AFTER=0.47.200

   run_installer "$package_path" 0.47.200 "$result_file"

   assert_eq "updated:0.47.200" "$(cat "$result_file")" "Successful install should publish the verified installed version"
   [ ! -e "$package_path" ] || fail "Verified package should be removed after a successful install"
   assert_contains "install|$package_path" "$TEST_OPKG_CALLS"
   teardown_case
}

test_zero_exit_with_version_mismatch_is_failure() {
   setup_case
   package_path="$TEST_TMP/run/openclash.ipk"
   result_file="$TEST_TMP/run/package.result"
   make_package "$package_path"
   export TEST_INSTALL_RC=0
   export TEST_VERSION_AFTER=0.47.199

   if run_installer "$package_path" 0.47.200 "$result_file"; then
      fail "Package-manager success without target-version readback must fail"
   fi

   assert_eq "failed:install" "$(cat "$result_file")" "Version mismatch should publish a terminal failure"
   [ -s "$package_path" ] || fail "Failed package should be retained for diagnosis"
   teardown_case
}

test_lock_busy_returns_75_without_installing() {
   setup_case
   package_path="$TEST_TMP/run/openclash.ipk"
   result_file="$TEST_TMP/run/package.result"
   make_package "$package_path"
   export TEST_FLOCK_BUSY=1

   set +e
   run_installer "$package_path" 0.47.200 "$result_file"
   status=$?
   set -e

   assert_eq 75 "$status" "Busy install lock should use the non-retryable busy status"
   assert_eq "busy" "$(cat "$result_file")" "Busy install lock should publish a busy result"
   assert_not_contains "install|" "$TEST_OPKG_CALLS"
   [ -s "$package_path" ] || fail "Busy path must not consume the package"
   teardown_case
}

test_invalid_arguments_return_transferred_job_counter() {
   setup_case
   result_file="$TEST_TMP/run/package.result"
   mkdir -p "$(dirname "$result_file")"

   if sh "$SCRIPT" "$TEST_TMP/missing.ipk" 0.47.200 "$result_file" 0 1 "" ""; then
      fail "Invalid worker arguments must fail"
   fi

   assert_eq "failed:invalid-arguments" "$(cat "$result_file")" "Invalid arguments should publish a terminal result"
   assert_eq 1 "$(grep -c '^restart:0$' "$TEST_LOG_FILE" 2>/dev/null || true)" "Claimed job counter must be returned exactly once"
   assert_not_contains "install|" "$TEST_OPKG_CALLS"
   teardown_case
}

test_package_and_result_paths_are_isolated_per_run() {
   setup_case
   package_one="$TEST_TMP/run one/openclash one.ipk"
   result_one="$TEST_TMP/run one/package.result"
   package_two="$TEST_TMP/run two/openclash two.ipk"
   result_two="$TEST_TMP/run two/package.result"
   make_package "$package_one"
   make_package "$package_two"

   export TEST_VERSION_AFTER=0.47.201
   run_installer "$package_one" 0.47.201 "$result_one"
   export TEST_VERSION_AFTER=0.47.202
   run_installer "$package_two" 0.47.202 "$result_two"

   assert_eq "updated:0.47.201" "$(cat "$result_one")" "First run result should remain scoped to its result path"
   assert_eq "updated:0.47.202" "$(cat "$result_two")" "Second run result should remain scoped to its result path"
   assert_contains "install|$package_one" "$TEST_OPKG_CALLS"
   assert_contains "install|$package_two" "$TEST_OPKG_CALLS"
   [ ! -e "$package_one" ] || fail "First package should be consumed only by its own run"
   [ ! -e "$package_two" ] || fail "Second package should be consumed only by its own run"
   teardown_case
}

test_success_requires_matching_version_readback
test_zero_exit_with_version_mismatch_is_failure
test_lock_busy_returns_75_without_installing
test_invalid_arguments_return_transferred_job_counter
test_package_and_result_paths_are_isolated_per_run

echo "openclash_update_install_test.sh: PASS"
