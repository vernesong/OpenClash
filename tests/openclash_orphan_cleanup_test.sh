#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INIT_SCRIPT="$ROOT_DIR/luci-app-openclash/root/etc/init.d/openclash"

helper="$(
  awk '
    /^cleanup_residual_core_processes\(\)$/ { capture = 1 }
    capture { print }
    capture && /^}$/ { exit }
  ' "$INIT_SCRIPT"
)"

if [[ -z "$helper" ]]; then
  echo "cleanup_residual_core_processes() not found" >&2
  exit 1
fi

eval "$helper"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

CLASH="/etc/openclash/clash"
scenario=""

reset_case() {
  scenario="$1"
  printf '0\n' >"$tmp_dir/calls"
  : >"$tmp_dir/kills"
}

unify_ps_pids() {
  local count
  count="$(cat "$tmp_dir/calls")"
  count=$((count + 1))
  printf '%s\n' "$count" >"$tmp_dir/calls"

  case "$scenario:$count" in
    graceful:1|graceful:2)
      printf '101 102\n'
      ;;
    stubborn:*)
      printf '201\n'
      ;;
  esac
}

kill() {
  printf '%s\n' "$*" >>"$tmp_dir/kills"
}

sleep() {
  :
}

reset_case empty
cleanup_residual_core_processes
[[ ! -s "$tmp_dir/kills" ]]

reset_case graceful
cleanup_residual_core_processes
grep -qx -- '-15 101' "$tmp_dir/kills"
grep -qx -- '-15 102' "$tmp_dir/kills"
if grep -q -- '^-9 ' "$tmp_dir/kills"; then
  echo "graceful exit unexpectedly used SIGKILL" >&2
  exit 1
fi

reset_case stubborn
cleanup_residual_core_processes
grep -qx -- '-15 201' "$tmp_dir/kills"
grep -qx -- '-9 201' "$tmp_dir/kills"

echo "openclash orphan cleanup tests passed"
