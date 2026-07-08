#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INIT_SCRIPT="$REPO_ROOT/luci-app-openclash/root/etc/init.d/openclash"
WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/openclash-fw4-dns-test.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT

fn=$(awk '/^fw4_has_dns_hijack_rule\(\)/,/^}/' "$INIT_SCRIPT")
if [ -z "$fn" ]; then
  echo "fw4_has_dns_hijack_rule not found" >&2
  exit 1
fi
eval "$fn"

cat >"$WORKDIR/nft" <<'STUB'
#!/usr/bin/env sh
if [ "$*" = "list chain inet fw4 dstnat" ]; then
  cat "${TEST_NFT_DSTNAT:?}"
elif [ "$*" = "list chain inet fw4 nat_output" ]; then
  cat "${TEST_NFT_NAT_OUTPUT:?}"
fi
STUB
chmod +x "$WORKDIR/nft"

assert_status() {
  expected="$1"
  shift
  set +e
  PATH="$WORKDIR:$PATH" "$@"
  actual=$?
  set -e
  if [ "$actual" -ne "$expected" ]; then
    echo "expected status $expected, got $actual: $*" >&2
    exit 1
  fi
}

TEST_NFT_DSTNAT="$WORKDIR/dstnat.txt"
TEST_NFT_NAT_OUTPUT="$WORKDIR/nat_output.txt"
export TEST_NFT_DSTNAT TEST_NFT_NAT_OUTPUT

cat >"$TEST_NFT_DSTNAT" <<'EOF'
meta l4proto { tcp, udp } th dport 53 counter redirect to :53 comment "OpenClash DNS Hijack"
EOF
cat >"$TEST_NFT_NAT_OUTPUT" <<'EOF'
meta l4proto { tcp, udp } th dport 53 ip daddr 127.0.0.1 counter redirect to :53 comment "OpenClash DNS Hijack"
EOF

assert_status 0 fw4_has_dns_hijack_rule dstnat ipv4
assert_status 1 fw4_has_dns_hijack_rule dstnat ipv6
assert_status 0 fw4_has_dns_hijack_rule nat_output ipv4
assert_status 1 fw4_has_dns_hijack_rule nat_output ipv6

cat >"$TEST_NFT_DSTNAT" <<'EOF'
meta nfproto ipv6 ip6 nexthdr { tcp, udp } th dport 53 counter redirect to :53 comment "OpenClash DNS Hijack"
EOF
cat >"$TEST_NFT_NAT_OUTPUT" <<'EOF'
skgid != 65534 meta nfproto ipv6 ip6 nexthdr { tcp, udp } th dport 53 ip6 daddr ::/0 counter redirect to :53 comment "OpenClash DNS Hijack"
EOF

assert_status 1 fw4_has_dns_hijack_rule dstnat ipv4
assert_status 0 fw4_has_dns_hijack_rule dstnat ipv6
assert_status 1 fw4_has_dns_hijack_rule nat_output ipv4
assert_status 0 fw4_has_dns_hijack_rule nat_output ipv6

assert_nat_output_insert_guarded() {
  family="$1"
  insert_text="$2"

  awk -v family="$family" -v insert_text="$insert_text" '
    $0 ~ "fw4_has_dns_hijack_rule nat_output " family {
      guard_window = 5
    }
    $0 ~ "nft insert rule inet fw4 nat_output" && index($0, insert_text) && $0 ~ "OpenClash DNS Hijack" {
      seen++
      if (guard_window <= 0) {
        print "nat_output DNS insert is not guarded for " family ": " $0 > "/dev/stderr"
        bad = 1
      }
    }
    {
      if (guard_window > 0) {
        guard_window--
      }
    }
    END {
      if (seen != 2) {
        print "expected two guarded nat_output DNS inserts for " family ", got " seen > "/dev/stderr"
        exit 1
      }
      if (bad) {
        exit 1
      }
    }
  ' "$INIT_SCRIPT"
}

assert_nat_output_insert_guarded ipv4 'ip daddr {127.0.0.1}'
assert_nat_output_insert_guarded ipv6 'ip6 daddr {::/0}'

echo "fw4_dns_hijack_guard_test.sh: PASS"
