#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INIT_SCRIPT="$REPO_ROOT/luci-app-openclash/root/etc/init.d/openclash"
WATCHDOG="$REPO_ROOT/luci-app-openclash/root/usr/share/openclash/openclash_watchdog.sh"

if sed -n '/start_service()/,/OpenClash Start Running/p' "$INIT_SCRIPT" | grep -F 'if procd_running "openclash" >/dev/null; then' >/dev/null 2>&1; then
  echo "start_service still treats any openclash instance as the core process" >&2
  exit 1
fi

if ! sed -n '/start_service()/,/OpenClash Start Running/p' "$INIT_SCRIPT" | grep -F 'procd_running "openclash" "openclash"' >/dev/null 2>&1; then
  echo "start_service does not check the openclash core instance explicitly" >&2
  exit 1
fi

if grep -F '@.openclash.instances.*.running' "$WATCHDOG" >/dev/null 2>&1; then
  echo "watchdog still treats any openclash instance as the core process" >&2
  exit 1
fi

if ! grep -F '@.openclash.instances.openclash.running' "$WATCHDOG" >/dev/null 2>&1; then
  echo "watchdog does not check the openclash core instance explicitly" >&2
  exit 1
fi

echo "openclash_core_instance_state_test.sh: PASS"
