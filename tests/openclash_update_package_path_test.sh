#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/luci-app-openclash/root/usr/share/openclash/openclash_update.sh"

if grep -nF 'DOWNLOAD_PATH="/tmp/openclash.ipk"' "$SCRIPT" >/dev/null 2>&1 ||
  grep -nF 'DOWNLOAD_PATH="/tmp/openclash.apk"' "$SCRIPT" >/dev/null 2>&1; then
  echo "update download path still uses fixed /tmp/openclash package name" >&2
  exit 1
fi

if grep -nF 'opkg install /tmp/openclash.ipk' "$SCRIPT" >/dev/null 2>&1 ||
  grep -nF 'apk add -q --force-overwrite --clean-protected --allow-untrusted /tmp/openclash.apk' "$SCRIPT" >/dev/null 2>&1; then
  echo "background installer still reads the fixed /tmp/openclash package path" >&2
  exit 1
fi

if ! grep -F 'PACKAGE_FILE="__OPENCLASH_PACKAGE_FILE__"' "$SCRIPT" >/dev/null 2>&1; then
  echo "background installer does not receive the staged package path" >&2
  exit 1
fi

if grep -nF '/tmp/openclash_update.sh' "$SCRIPT" >/dev/null 2>&1; then
  echo "background installer script still uses fixed /tmp/openclash_update.sh path" >&2
  exit 1
fi

if ! grep -F 'UPDATE_SCRIPT="/tmp/openclash_update_$$.sh"' "$SCRIPT" >/dev/null 2>&1; then
  echo "update helper script is not staged per run" >&2
  exit 1
fi

echo "openclash_update_package_path_test.sh: PASS"
