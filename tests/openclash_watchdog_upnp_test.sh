#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/luci-app-openclash/root/usr/share/openclash/openclash_watchdog.sh"

if grep -F 'for i in `$(' "$SCRIPT" >/dev/null 2>&1; then
  echo "UPNP delete loop still executes listed rules as commands" >&2
  exit 1
fi

if grep -F 'iptables --line-numbers -t nat -xnvL openclash_upnp' "$SCRIPT" >/dev/null 2>&1; then
  echo "UPNP add guard still checks nat instead of mangle" >&2
  exit 1
fi

if ! grep -F 'iptables --line-numbers -t mangle -xnvL openclash_upnp' "$SCRIPT" >/dev/null 2>&1; then
  echo "UPNP add guard does not check the mangle openclash_upnp chain" >&2
  exit 1
fi

if grep -F '2>/dev/null)"]' "$SCRIPT" >/dev/null 2>&1; then
  echo "UPNP add guard still has a missing test bracket space" >&2
  exit 1
fi

echo "openclash_watchdog_upnp_test.sh: PASS"
