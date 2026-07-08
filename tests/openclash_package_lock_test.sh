#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MATCH_FILE="${TMPDIR:-/tmp}/openclash-package-lock-rm.$$"
trap 'rm -f "$MATCH_FILE"' EXIT

if grep -RInE 'rm -.*(/var/lock/opkg\.lock|/lib/apk/db/lock)' \
  "$REPO_ROOT/luci-app-openclash" >"$MATCH_FILE"; then
  echo "OpenClash scripts must not remove system package manager locks:" >&2
  cat "$MATCH_FILE" >&2
  exit 1
fi

echo "openclash_package_lock_test.sh: PASS"
