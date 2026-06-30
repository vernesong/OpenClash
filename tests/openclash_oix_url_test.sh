#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLASH_VERSION="$REPO_ROOT/luci-app-openclash/root/usr/share/openclash/clash_version.sh"
OPENCLASH_CORE="$REPO_ROOT/luci-app-openclash/root/usr/share/openclash/openclash_core.sh"

fail() {
   echo "FAIL: $*" >&2
   exit 1
}

assert_eq() {
   local expected="$1"
   local actual="$2"
   local message="$3"
   [ "$expected" = "$actual" ] || fail "$message
expected: $expected
actual:   $actual"
}

raw_version="https://github.com/vernesong/mihomo-oix/releases/download/Pre-Alpha/version.txt"
raw_core="https://github.com/vernesong/mihomo-oix/releases/download/Pre-Alpha/mihomo-linux-arm64-2026.06.30.gz"

assert_eq "$raw_version" \
   "$(OPENCLASH_TEST_ONLY=1 bash "$CLASH_VERSION" build_oix_version_url "")" \
   "empty CDN should use raw OIX version URL"

assert_eq "$raw_version" \
   "$(OPENCLASH_TEST_ONLY=1 bash "$CLASH_VERSION" build_oix_version_url "0")" \
   "CDN value 0 should use raw OIX version URL"

assert_eq "https://fastly.jsdelivr.net/gh/vernesong/mihomo-oix@Pre-Alpha/version.txt" \
   "$(OPENCLASH_TEST_ONLY=1 bash "$CLASH_VERSION" build_oix_version_url "https://fastly.jsdelivr.net/")" \
   "fastly jsDelivr OIX version URL mismatch"

assert_eq "https://testingcf.jsdelivr.net/gh/vernesong/mihomo-oix@Pre-Alpha/version.txt" \
   "$(OPENCLASH_TEST_ONLY=1 bash "$CLASH_VERSION" build_oix_version_url "https://testingcf.jsdelivr.net/")" \
   "testingcf jsDelivr OIX version URL mismatch"

assert_eq "https://cdn.jsdelivr.net/gh/vernesong/mihomo-oix@Pre-Alpha/version.txt" \
   "$(OPENCLASH_TEST_ONLY=1 bash "$CLASH_VERSION" build_oix_version_url "https://cdn.jsdelivr.net/")" \
   "cdn jsDelivr OIX version URL mismatch"

assert_eq "https://ghfast.top/${raw_version}" \
   "$(OPENCLASH_TEST_ONLY=1 bash "$CLASH_VERSION" build_oix_version_url "https://ghfast.top/")" \
   "custom OIX version URL mismatch"

assert_eq "$raw_core" \
   "$(OPENCLASH_TEST_ONLY=1 bash "$OPENCLASH_CORE" build_oix_core_url "" "linux-arm64" "2026.06.30")" \
   "empty CDN should use raw OIX core URL"

assert_eq "https://fastly.jsdelivr.net/gh/vernesong/mihomo-oix@Pre-Alpha/mihomo-linux-arm64-2026.06.30.gz" \
   "$(OPENCLASH_TEST_ONLY=1 bash "$OPENCLASH_CORE" build_oix_core_url "https://fastly.jsdelivr.net/" "linux-arm64" "2026.06.30")" \
   "fastly jsDelivr OIX core URL mismatch"

assert_eq "https://testingcf.jsdelivr.net/gh/vernesong/mihomo-oix@Pre-Alpha/mihomo-linux-arm64-2026.06.30.gz" \
   "$(OPENCLASH_TEST_ONLY=1 bash "$OPENCLASH_CORE" build_oix_core_url "https://testingcf.jsdelivr.net/" "linux-arm64" "2026.06.30")" \
   "testingcf jsDelivr OIX core URL mismatch"

assert_eq "https://cdn.jsdelivr.net/gh/vernesong/mihomo-oix@Pre-Alpha/mihomo-linux-arm64-2026.06.30.gz" \
   "$(OPENCLASH_TEST_ONLY=1 bash "$OPENCLASH_CORE" build_oix_core_url "https://cdn.jsdelivr.net/" "linux-arm64" "2026.06.30")" \
   "cdn jsDelivr OIX core URL mismatch"

assert_eq "https://ghfast.top/${raw_core}" \
   "$(OPENCLASH_TEST_ONLY=1 bash "$OPENCLASH_CORE" build_oix_core_url "https://ghfast.top/" "linux-arm64" "2026.06.30")" \
   "custom OIX core URL mismatch"

echo "openclash_oix_url_test.sh: PASS"
