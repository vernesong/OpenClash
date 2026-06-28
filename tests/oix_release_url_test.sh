#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLASH_VERSION="$REPO_ROOT/luci-app-openclash/root/usr/share/openclash/clash_version.sh"
OPENCLASH_CORE="$REPO_ROOT/luci-app-openclash/root/usr/share/openclash/openclash_core.sh"

assert_contains() {
  local file="$1"
  local expected="$2"
  if ! grep -Fq -- "$expected" "$file"; then
    printf 'Expected %s to contain: %s\n' "$file" "$expected" >&2
    return 1
  fi
}

assert_not_contains() {
  local file="$1"
  local unexpected="$2"
  if grep -Fq -- "$unexpected" "$file"; then
    printf 'Expected %s not to contain: %s\n' "$file" "$unexpected" >&2
    return 1
  fi
}

assert_contains "$CLASH_VERSION" "github.com/vernesong/mihomo-oix/releases/download/Pre-Alpha/version.txt"
assert_contains "$OPENCLASH_CORE" "github.com/vernesong/mihomo-oix/releases/download/Pre-Alpha/mihomo-\${CPU_MODEL}-\${CORE_LV}.gz"
assert_not_contains "$CLASH_VERSION" "dl.dler.io/mihomo-oix"
assert_not_contains "$OPENCLASH_CORE" "dl.dler.io/mihomo-oix"

printf 'oix release URL tests passed\n'
