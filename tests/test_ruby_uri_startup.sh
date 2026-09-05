#!/usr/bin/env bash
# Run config_check and start_fail without sourcing the router init script.
# TEST_SHELL may point to another shell executable, such as BusyBox ash.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
INIT="$ROOT/luci-app-openclash/root/etc/init.d/openclash"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    [ ! -f "${LOG_FILE:-}" ] || cat "$LOG_FILE" >&2
    [ ! -f "${TRACE_FILE:-}" ] || cat "$TRACE_FILE" >&2
    exit 1
}

for name in config_check start_fail; do
    awk -v name="$name" -v helper="$ROOT/luci-app-openclash/root/usr/share/openclash/YAML.rb" '
        $0 == name "()" { copying = 1 }
        # An absolute helper path avoids shadowing stdlib yaml.rb on macOS.
        copying { sub(/-rYAML/, "-r\"" helper "\""); print }
        copying && /^}$/ { exit }
    ' "$INIT" >> "$WORK/functions.sh"
    grep -q "^$name()" "$WORK/functions.sh" || fail "cannot extract $name"
done

cat > "$WORK/run.sh" <<'SH'
LOG_ERROR() { printf '%s\n' "$*" >> "$LOG_FILE"; }
uci() { printf 'uci %s\n' "$*" >> "$TRACE_FILE"; }
stop() { printf 'stop\n' >> "$TRACE_FILE"; }
. "$FUNCTIONS_FILE"
config_check
printf 'continued\n' >> "$TRACE_FILE"
SH

mkdir "$WORK/missing"
printf '%s\n' 'raise LoadError, "cannot load such file -- uri"' > "$WORK/missing/uri.rb"
printf 'mixed-port: 7890\n' > "$WORK/valid.yaml"
printf 'dns: [\n' > "$WORK/invalid.yaml"

run_case() {
    local name=$1 input=$2 extra_lib=${3:-}
    export RAW_CONFIG_FILE="$WORK/$input.yaml"
    export TMP_CONFIG_FILE="$WORK/$name.copy.yaml"
    export LOG_FILE="$WORK/$name.log" TRACE_FILE="$WORK/$name.trace"
    export FUNCTIONS_FILE="$WORK/functions.sh"
    : > "$LOG_FILE"
    : > "$TRACE_FILE"
    # Keep host RubyGems from loading uri before the startup check.
    RUBYOPT=--disable-gems RUBYLIB="$extra_lib" \
        "${TEST_SHELL:-/bin/sh}" "$WORK/run.sh" || fail "$name harness failed"
}

assert_stopped() {
    # start_fail exits with status 0, so inspect its effects and continuation.
    grep -Fxq 'uci -q set openclash.config.enable=0' "$TRACE_FILE" || fail 'start_fail did not disable OpenClash'
    grep -Fxq 'uci -q commit openclash' "$TRACE_FILE" || fail 'start_fail did not commit'
    grep -Fxq 'stop' "$TRACE_FILE" || fail 'stop was not called'
    ! grep -Fxq 'continued' "$TRACE_FILE" || fail 'startup continued after failure'
}

run_case valid valid
grep -Fxq 'continued' "$TRACE_FILE" || fail 'valid config was rejected'
[ "$(cat "$TRACE_FILE")" = continued ] || fail 'valid config stopped startup'
cmp -s "$RAW_CONFIG_FILE" "$TMP_CONFIG_FILE" || fail 'valid config copy changed'
[ ! -s "$LOG_FILE" ] || fail 'valid config produced errors'
printf 'PASS: valid config\n'

run_case invalid invalid
assert_stopped
grep -Fq 'Unable To Parse Config File' "$LOG_FILE" || fail 'YAML parser error is missing'
grep -Fq 'Config File Format Validation Failed' "$LOG_FILE" || fail 'invalid YAML was not rejected'
[ ! -e "$TMP_CONFIG_FILE" ] || fail 'invalid config copy was kept'
printf 'PASS: invalid YAML\n'

run_case missing_uri valid "$WORK/missing"
! grep -Fxq 'continued' "$TRACE_FILE" || fail 'missing uri allowed startup to continue'
assert_stopped
grep -Fq 'cannot load such file -- uri' "$LOG_FILE" || fail 'LoadError detail is missing'
grep -Fq 'Ruby Works Abnormally' "$LOG_FILE" || fail 'dependency error is missing'
printf 'PASS: missing uri stops startup and logs the cause\n'

awk '
    /^[[:space:]]*DEPENDS[[:space:]]*[:+?]?=/ { in_depends = 1 }
    in_depends && /(^|[[:space:]])\+ruby-uri([[:space:]\\]|$)/ { found = 1 }
    in_depends && !/\\$/ { in_depends = 0 }
    END { exit !found }
' "$ROOT/luci-app-openclash/Makefile" || fail 'package dependency ruby-uri is missing'
printf 'PASS: ruby-uri package dependency\n'
