#!/bin/sh
set -e

file="luci-app-openclash/root/usr/share/openclash/yml_change.sh"
pattern="Value\['dns'\]\['respect-rules'\] = respect_rules"

if rg -n "$pattern" "$file" >/dev/null; then
  echo "FAIL: dns.respect-rules is still unconditionally overridden"
  exit 1
fi

echo "PASS: dns.respect-rules is not unconditionally overridden"
