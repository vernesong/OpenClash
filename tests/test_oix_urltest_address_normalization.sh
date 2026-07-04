#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
target="$repo_root/luci-app-openclash/root/usr/share/openclash/yml_rules_change.sh"

fn=$(awk '/^normalize_urltest_address_mod\(\)/,/^}/' "$target")

if [ -z "$fn" ]; then
  echo "normalize_urltest_address_mod not found" >&2
  exit 1
fi

eval "$fn"

assert_eq() {
  expected="$1"
  actual="$2"
  label="$3"
  if [ "$actual" != "$expected" ]; then
    echo "$label: expected $expected, got $actual" >&2
    exit 1
  fi
}

safe_url="https://cp.cloudflare.com/generate_204"

assert_eq "$safe_url" "$(normalize_urltest_address_mod "Oix" "http://captive.apple.com/generate_204")" "Oix captive.apple"
assert_eq "$safe_url" "$(normalize_urltest_address_mod "Oix" "http://www.gstatic.com/generate_204")" "Oix http gstatic"
assert_eq "$safe_url" "$(normalize_urltest_address_mod "Oix" "http://cp.cloudflare.com/generate_204")" "Oix http cloudflare"
assert_eq "https://www.gstatic.com/generate_204" "$(normalize_urltest_address_mod "Oix" "https://www.gstatic.com/generate_204")" "Oix custom https"
assert_eq "http://captive.apple.com/generate_204" "$(normalize_urltest_address_mod "Meta" "http://captive.apple.com/generate_204")" "Meta unchanged"
