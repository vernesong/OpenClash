#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MATCH_FILE="${TMPDIR:-/tmp}/openclash-flock-lock-rm.$$"
trap 'rm -f "$MATCH_FILE"' EXIT

if grep -RInE 'rm -.*(/tmp/lock/openclash|[$]UPDATE_LOCK)' \
  "$REPO_ROOT/luci-app-openclash/root/usr/share/openclash" \
  "$REPO_ROOT/luci-app-openclash/root/etc/init.d/openclash" >"$MATCH_FILE"; then
  echo "OpenClash flock lock files must not be removed after unlock:" >&2
  cat "$MATCH_FILE" >&2
  exit 1
fi

echo "openclash_flock_lockfile_test.sh: PASS"
