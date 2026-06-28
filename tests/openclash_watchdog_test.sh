#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WATCHDOG="$REPO_ROOT/luci-app-openclash/root/usr/share/openclash/openclash_watchdog.sh"

extract_skip_proxy_ruby() {
  awk '
    /ruby -ryaml -rYAML -I "\/usr\/share\/openclash" -E UTF-8 -e "/ {
      in_ruby = 1
      sub(/^.*-e "/, "")
      print
      next
    }
    in_ruby && /^end" 2>\/dev\/null >> \$LOG_FILE/ {
      sub(/" 2>\/dev\/null >> \$LOG_FILE$/, "")
      print
      in_ruby = 0
      next
    }
    in_ruby { print }
  ' "$WATCHDOG"
}

prepare_fake_yaml() {
  local fake_dir="$1"
  cat > "$fake_dir/openclash_test_yaml.rb" <<'RUBY'
require 'yaml'

module YAML
  class << self
    alias_method :openclash_original_load_file, :load_file unless method_defined?(:openclash_original_load_file)
  end

  def self.load_file(filename, *args, **kwargs)
    provider_path = File.join(ENV.fetch('OC_CLASH_DIR'), 'proxy_provider', ENV.fetch('OC_PROVIDER_NAME'))

    if filename == ENV.fetch('OC_CONFIG_FILE')
      return {
        'proxy-providers' => {
          ENV.fetch('OC_PROVIDER_NAME') => {
            'type' => 'http',
            'path' => './proxy_provider/' + ENV.fetch('OC_PROVIDER_NAME')
          }
        }
      }
    end

    if filename == provider_path
      if ENV.fetch('OC_PROVIDER_MODE') == 'auto_decrypt'
        return { 'proxies' => [{ 'server' => '203.0.113.7' }] }
      end

      raise 'Encrypted file: decryption failed for ' + filename
    end

    openclash_original_load_file(filename, *args, **kwargs)
  end

  def self.LOG_WARN(info)
    File.open(ENV.fetch('OC_LOG_FILE'), 'a') { |f| f.puts('WARN ' + info) }
  end

  def self.LOG_ERROR(info)
    File.open(ENV.fetch('OC_LOG_FILE'), 'a') { |f| f.puts('ERROR ' + info) }
  end

  def self.LOG_TIP(info)
    File.open(ENV.fetch('OC_LOG_FILE'), 'a') { |f| f.puts('TIP ' + info) }
  end
end

module Kernel
  def system(cmd)
    File.open(ENV.fetch('OC_SYSTEM_LOG'), 'a') { |f| f.puts(cmd) }
    true
  end
end
RUBY

  cat > "$fake_dir/curl" <<'SH'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$OC_CURL_LOG"
case "$*" in
  *"/providers/proxies/oixCloud/servers"*)
    printf '{"servers":["198.51.100.9","node.example.com"]}'
    ;;
  *)
    printf '{}'
    ;;
esac
SH
  chmod +x "$fake_dir/curl"
}

run_skip_proxy_ruby() {
  local tmp_dir="$1" provider_name="$2" provider_mode="$3" core_type="$4"
  local clash_dir="$tmp_dir/openclash"
  local provider_dir="$clash_dir/proxy_provider"
  local fake_dir="$tmp_dir/fake_ruby"
  local ruby_file="$tmp_dir/skip_proxy.rb"

  mkdir -p "$provider_dir" "$fake_dir"
  : > "$tmp_dir/openclash.log"
  : > "$tmp_dir/system.log"
  : > "$tmp_dir/curl.log"
  : > "$tmp_dir/runtime.yaml"

  cat > "$provider_dir/$provider_name" <<'EOF_PROVIDER'
-----BEGIN AGE ENCRYPTED FILE-----
test encrypted payload
-----END AGE ENCRYPTED FILE-----
EOF_PROVIDER

  prepare_fake_yaml "$fake_dir"
  extract_skip_proxy_ruby \
    | sed \
      -e 's#\\"#"#g' \
      -e "s#'\\\$CONFIG_FILE'#ENV['OC_CONFIG_FILE']#g" \
      -e "s#'\\\$FW4'#ENV['OC_FW4']#g" \
      -e "s#'\\\$core_type'#ENV['OC_CORE_TYPE']#g" \
      -e "s#'\\\$da_password'#ENV['OC_DASHBOARD_PASSWORD']#g" \
      -e "s#'\\\$cn_port'#ENV['OC_CN_PORT']#g" \
      -e "s#'/etc/openclash/'#ENV['OC_CLASH_DIR'] + '/'#g" \
    > "$ruby_file"

  PATH="$fake_dir:$PATH" \
  OC_CONFIG_FILE="$tmp_dir/runtime.yaml" \
  OC_CLASH_DIR="$clash_dir" \
  OC_PROVIDER_NAME="$provider_name" \
  OC_PROVIDER_MODE="$provider_mode" \
  OC_CORE_TYPE="$core_type" \
  OPENCLASH_CORE_TYPE="$core_type" \
  OC_FW4="" \
  OC_DASHBOARD_PASSWORD="dashboard-secret" \
  OC_CN_PORT="9090" \
  OPENCLASH_DASHBOARD_PASSWORD="dashboard-secret" \
  OPENCLASH_CN_PORT="9090" \
  OC_LOG_FILE="$tmp_dir/openclash.log" \
  OC_SYSTEM_LOG="$tmp_dir/system.log" \
  OC_CURL_LOG="$tmp_dir/curl.log" \
    ruby -ryaml -e "load '$fake_dir/openclash_test_yaml.rb'; load '$ruby_file'"
}

assert_contains() {
  local file="$1" pattern="$2" message="$3"
  if ! grep -Fq "$pattern" "$file"; then
    echo "FAIL: $message" >&2
    echo "--- $file ---" >&2
    cat "$file" >&2
    exit 1
  fi
}

assert_not_contains() {
  local file="$1" pattern="$2" message="$3"
  if grep -Fq "$pattern" "$file"; then
    echo "FAIL: $message" >&2
    echo "--- $file ---" >&2
    cat "$file" >&2
    exit 1
  fi
}

tmp_auto="$(mktemp -d)"
tmp_oix=""
trap 'rm -rf "$tmp_auto" "$tmp_oix"' EXIT
run_skip_proxy_ruby "$tmp_auto" "secureProvider" "auto_decrypt" "Meta"
assert_contains "$tmp_auto/system.log" 'ipset add localnetwork "203.0.113.7"' \
  "encrypted providers that YAML.load_file can decrypt should still feed skip_proxy_address"
assert_not_contains "$tmp_auto/openclash.log" "File is AGE encrypted but no secret key provided" \
  "watchdog should not reject encrypted providers before YAML.load_file auto key lookup"

tmp_oix="$(mktemp -d)"
run_skip_proxy_ruby "$tmp_oix" "oixCloud" "decrypt_fail" "Oix"
assert_contains "$tmp_oix/curl.log" "/providers/proxies/oixCloud/servers" \
  "OIX provider servers should be requested from the OIX core API"
assert_contains "$tmp_oix/system.log" 'ipset add localnetwork "198.51.100.9"' \
  "OIX provider servers returned by the core API should feed skip_proxy_address"
assert_not_contains "$tmp_oix/openclash.log" "Set Proxies Address Skip Failed" \
  "OIX managed encrypted providers should not be reported as OpenClash skip_proxy_address failures"

echo "openclash_watchdog tests passed"
