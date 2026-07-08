#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INIT_SCRIPT="$REPO_ROOT/luci-app-openclash/root/etc/init.d/openclash"

if ! grep -F 'START_ID_FILE="/tmp/openclash_start_id"' "$INIT_SCRIPT" >/dev/null 2>&1; then
  echo "init script does not define a start generation file" >&2
  exit 1
fi

if ! grep -F 'OPENCLASH_START_ID="$$-$(date +%s)"' "$INIT_SCRIPT" >/dev/null 2>&1; then
  echo "start_service does not create a per-start generation id" >&2
  exit 1
fi

if ! grep -F 'check_core_status "start" "$OPENCLASH_START_ID" &' "$INIT_SCRIPT" >/dev/null 2>&1; then
  echo "background core status check does not receive the start generation id" >&2
  exit 1
fi

if ! grep -F 'Skip Stale Core Status Failure' "$INIT_SCRIPT" >/dev/null 2>&1; then
  echo "start_fail does not skip stale background status checks" >&2
  exit 1
fi

if ! grep -F 'rm -f "$START_ID_FILE"' "$INIT_SCRIPT" >/dev/null 2>&1; then
  echo "stop_service does not clear the start generation id" >&2
  exit 1
fi

echo "openclash_start_generation_test.sh: PASS"
