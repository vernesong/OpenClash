#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/luci-app-openclash/root/usr/share/openclash/openclash_core.sh"

if grep -F 'TMP_FILE="/tmp/clash_meta"' "$SCRIPT" >/dev/null 2>&1; then
  echo "core staging still uses /tmp/clash_meta" >&2
  exit 1
fi

if ! grep -F 'TMP_FILE="${TARGET_CORE_PATH}.new.$$"' "$SCRIPT" >/dev/null 2>&1; then
  echo "core staging is not created next to target core" >&2
  exit 1
fi

if ! grep -F 'mv -f "$TMP_FILE" "$TARGET_CORE_PATH"' "$SCRIPT" >/dev/null 2>&1; then
  echo "core replacement does not use final same-directory mv" >&2
  exit 1
fi

echo "openclash_core_atomic_test.sh: PASS"
