#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INIT_SCRIPT="$REPO_ROOT/luci-app-openclash/root/etc/init.d/openclash"

require_pattern() {
  local pattern="$1"
  local message="$2"

  if ! PATTERN="$pattern" perl -0ne 'exit(/$ENV{PATTERN}/s ? 0 : 1)' "$INIT_SCRIPT"; then
    echo "$message" >&2
    exit 1
  fi
}

require_pattern 'set_lifecycle_lock\(\).*?openclash_lifecycle\.lock.*?flock -x 867' \
  "lifecycle lock setup is missing or does not use a stable flock file"

require_pattern 'del_lifecycle_lock\(\).*?flock -u 867' \
  "lifecycle lock release is missing"

if grep -F 'rm -rf "/tmp/lock/openclash_lifecycle.lock"' "$INIT_SCRIPT" >/dev/null 2>&1 ||
   grep -F "rm -rf '/tmp/lock/openclash_lifecycle.lock'" "$INIT_SCRIPT" >/dev/null 2>&1; then
  echo "lifecycle lock file should not be removed while other waiters may hold it" >&2
  exit 1
fi

require_pattern 'start_fail\(\).*?del_lifecycle_lock.*?stop' \
  "start_fail should release lifecycle lock before re-entering stop"

require_pattern 'start_service\(\).*?set_lifecycle_lock.*?procd_running "openclash".*?del_lifecycle_lock.*?exit 0.*?rm -rf /tmp/yaml_\*.*?del_lifecycle_lock' \
  "start_service should hold lifecycle lock through yaml cleanup and release it on already-running exit"

require_pattern 'stop_service\(\).*?set_lifecycle_lock.*?get_config.*?rm -rf /tmp/yaml_\*.*?del_lifecycle_lock' \
  "stop_service should hold lifecycle lock through yaml cleanup"

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/openclash-lifecycle-lock-test.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT

mkdir -p "$WORKDIR/bin" "$WORKDIR/tmp/lock" "$WORKDIR/flock-state"

cat >"$WORKDIR/bin/flock" <<'STUB'
#!/usr/bin/env sh
mode="$1"
case "$mode" in
  -x)
    while ! mkdir "${TEST_FLOCK_STATE:?}/held" 2>/dev/null; do
      sleep 0.05
    done
  ;;
  -u)
    rmdir "${TEST_FLOCK_STATE:?}/held" 2>/dev/null || true
  ;;
  *)
    echo "unexpected flock mode: $*" >&2
    exit 1
  ;;
esac
STUB
chmod +x "$WORKDIR/bin/flock"

awk '
  /^set_lifecycle_lock\(\)/ { print_block=1 }
  /^del_lifecycle_lock\(\)/ { print_block=1 }
  print_block { print }
  /^}/ && print_block { print_block=0 }
' "$INIT_SCRIPT" >"$WORKDIR/lifecycle.sh"
PERL_WORKDIR="$WORKDIR" perl -0pi -e 's#/tmp/lock#$ENV{PERL_WORKDIR}/tmp/lock#g' "$WORKDIR/lifecycle.sh"

cat >"$WORKDIR/lock_worker.sh" <<'STUB'
#!/usr/bin/env sh
. "$TEST_LIFECYCLE_FUNCS"

case "$1" in
  first)
    set_lifecycle_lock
    echo "first-held" >>"$TEST_LOCK_LOG"
    : >"$TEST_FIRST_HELD"
    while [ ! -f "$TEST_RELEASE_FIRST" ]; do
      sleep 0.05
    done
    del_lifecycle_lock
    echo "first-released" >>"$TEST_LOCK_LOG"
  ;;
  second)
    echo "second-waiting" >>"$TEST_LOCK_LOG"
    set_lifecycle_lock
    echo "second-held" >>"$TEST_LOCK_LOG"
    del_lifecycle_lock
  ;;
  *)
    exit 1
  ;;
esac
STUB
chmod +x "$WORKDIR/lock_worker.sh"

TEST_LOCK_LOG="$WORKDIR/lock.log"
TEST_FIRST_HELD="$WORKDIR/first-held"
TEST_RELEASE_FIRST="$WORKDIR/release-first"
: >"$TEST_LOCK_LOG"

env TEST_LIFECYCLE_FUNCS="$WORKDIR/lifecycle.sh" \
    TEST_FLOCK_STATE="$WORKDIR/flock-state" \
    TEST_LOCK_LOG="$TEST_LOCK_LOG" \
    TEST_FIRST_HELD="$TEST_FIRST_HELD" \
    TEST_RELEASE_FIRST="$TEST_RELEASE_FIRST" \
    PATH="$WORKDIR/bin:$PATH" \
    "$WORKDIR/lock_worker.sh" first &
first_pid=$!

while [ ! -f "$TEST_FIRST_HELD" ]; do
  sleep 0.05
done

env TEST_LIFECYCLE_FUNCS="$WORKDIR/lifecycle.sh" \
    TEST_FLOCK_STATE="$WORKDIR/flock-state" \
    TEST_LOCK_LOG="$TEST_LOCK_LOG" \
    TEST_FIRST_HELD="$TEST_FIRST_HELD" \
    TEST_RELEASE_FIRST="$TEST_RELEASE_FIRST" \
    PATH="$WORKDIR/bin:$PATH" \
    "$WORKDIR/lock_worker.sh" second &
second_pid=$!

sleep 0.2
if grep -q '^second-held$' "$TEST_LOCK_LOG"; then
  echo "second lifecycle holder entered before first released the lock" >&2
  exit 1
fi

: >"$TEST_RELEASE_FIRST"
wait "$first_pid"
wait "$second_pid"

grep -q '^first-released$' "$TEST_LOCK_LOG" || {
  echo "first lifecycle holder did not release the lock" >&2
  exit 1
}
grep -q '^second-held$' "$TEST_LOCK_LOG" || {
  echo "second lifecycle holder did not acquire the lock after release" >&2
  exit 1
}

echo "openclash_lifecycle_lock_test.sh: PASS"
