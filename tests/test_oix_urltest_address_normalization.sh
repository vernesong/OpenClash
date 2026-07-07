#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
target="$repo_root/luci-app-openclash/root/usr/share/openclash/yml_rules_change.sh"
init_target="$repo_root/luci-app-openclash/root/etc/init.d/openclash"

fn=$(awk '/^normalize_urltest_address_mod\(\)/,/^}/' "$target")

if [ -z "$fn" ]; then
  echo "normalize_urltest_address_mod not found" >&2
  exit 1
fi

eval "$fn"

runtime_fn=$(awk '/^normalize_oix_runtime_urltest_addresses\(\)/,/^}/' "$init_target")

if [ -z "$runtime_fn" ]; then
  echo "normalize_oix_runtime_urltest_addresses not found" >&2
  exit 1
fi

runtime_fn=$(printf '%s\n' "$runtime_fn" | sed "s#ruby -ryaml -rYAML -I \"/usr/share/openclash\" -E UTF-8#ruby -ryaml -E UTF-8#g")
eval "$runtime_fn"

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

write_runtime_fixture() {
  file="$1"
  cat >"$file" <<'YAML'
proxy-providers:
  oix-provider:
    type: http
    health-check:
      enable: true
      url: http://captive.apple.com/generate_204
  custom-provider:
    type: http
    health-check:
      enable: true
      url: http://example.com/health
proxy-groups:
  - name: auto
    type: url-test
    url: http://cp.cloudflare.com/generate_204
  - name: custom
    type: fallback
    url: http://example.com/probe
YAML
}

assert_yaml_value() {
  file="$1"
  expression="$2"
  expected="$3"
  label="$4"
  actual=$(ruby -ryaml -e "data = YAML.load_file('$file'); puts $expression")
  assert_eq "$expected" "$actual" "$label"
}

runtime_tmp=$(mktemp -d "${TMPDIR:-/tmp}/openclash-oix-urltest.XXXXXX")
trap 'rm -rf "$runtime_tmp"' EXIT

oix_config="$runtime_tmp/oix.yaml"
write_runtime_fixture "$oix_config"
core_type=Oix TMP_CONFIG_FILE="$oix_config" LOG_FILE="$runtime_tmp/openclash.log" normalize_oix_runtime_urltest_addresses
assert_yaml_value "$oix_config" "data['proxy-providers']['oix-provider']['health-check']['url']" "$safe_url" "runtime Oix provider URL"
assert_yaml_value "$oix_config" "data['proxy-groups'][0]['url']" "$safe_url" "runtime Oix group URL"
assert_yaml_value "$oix_config" "data['proxy-providers']['custom-provider']['health-check']['url']" "http://example.com/health" "runtime Oix custom provider URL"
assert_yaml_value "$oix_config" "data['proxy-groups'][1]['url']" "http://example.com/probe" "runtime Oix custom group URL"

meta_config="$runtime_tmp/meta.yaml"
write_runtime_fixture "$meta_config"
core_type=Meta TMP_CONFIG_FILE="$meta_config" LOG_FILE="$runtime_tmp/openclash.log" normalize_oix_runtime_urltest_addresses
assert_yaml_value "$meta_config" "data['proxy-providers']['oix-provider']['health-check']['url']" "http://captive.apple.com/generate_204" "runtime Meta provider unchanged"
assert_yaml_value "$meta_config" "data['proxy-groups'][0]['url']" "http://cp.cloudflare.com/generate_204" "runtime Meta group unchanged"

echo "test_oix_urltest_address_normalization.sh: PASS"
