#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

groups_set="$ROOT_DIR/luci-app-openclash/root/usr/share/openclash/yml_groups_set.sh"
rules_change="$ROOT_DIR/luci-app-openclash/root/usr/share/openclash/yml_rules_change.sh"
init_script="$ROOT_DIR/luci-app-openclash/root/etc/init.d/openclash"
groups_config="$ROOT_DIR/luci-app-openclash/luasrc/model/cbi/openclash/groups-config.lua"
overwrite_config="$ROOT_DIR/luci-app-openclash/luasrc/model/cbi/openclash/config-overwrite.lua"

assert_contains() {
   local file="$1"
   local pattern="$2"
   local message="$3"

   if ! grep -Fq "$pattern" "$file"; then
      echo "not ok - $message" >&2
      echo "missing pattern: $pattern" >&2
      echo "file: $file" >&2
      exit 1
   fi
}

assert_contains "$groups_set" 'config_get "strategy_smart" "$section" "strategy_smart" ""' "Smart strategy is read from group UCI"
assert_contains "$groups_set" '[ "$strategy_smart" = "sticky-sessions" ] && {' "Smart strategy output is gated to sticky-sessions"
assert_contains "$groups_set" 'echo "    strategy: $strategy_smart" >>$GROUP_FILE' "Smart strategy is written to generated YAML"

assert_contains "$groups_config" 's:option(ListValue, "strategy_smart", translate("Strategy Type"))' "LuCI exposes Smart strategy_smart"
assert_contains "$groups_config" 'Requires Smart core support for sticky-sessions strategy' "Smart group UI warns about core support"
assert_contains "$groups_config" 'o:depends("type", "smart")' "Smart strategy UI only depends on Smart groups"
assert_contains "$overwrite_config" 'Requires Smart core support for sticky-sessions strategy' "Global Smart strategy UI warns about core support"

assert_contains "$init_script" 'smart_strategy=$(uci_get_config "smart_strategy" || echo 0)' "Global Smart strategy is read from UCI"
assert_contains "$init_script" '"$auto_smart_switch" "$smart_collect" "$smart_collect_rate" "$smart_policy_priority" "$smart_enable_lgbm" "$smart_prefer_asn" "$smart_strategy"' "Global Smart strategy is passed to yml_rules_change"

assert_contains "$rules_change" "'\${14}' == 'sticky-sessions'" "Auto Smart strategy parameter is checked"
assert_contains "$rules_change" "group.delete('strategy')" "Auto Smart switch removes legacy strategy values"
assert_contains "$rules_change" "if '\${14}' == 'sticky-sessions' and group['type'] == 'smart' then" "Global Smart strategy is gated to Smart groups"
assert_contains "$rules_change" "group['strategy'] = '\${14}'" "Auto Smart strategy is written to Smart groups"
assert_contains "$rules_change" 'yml_other_set "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}" "${11}" "${12}" "${13}" "${14}"' "Auto Smart strategy argument is forwarded"

ruby -ryaml <<'RUBY'
def convert_groups(groups, auto_smart_switch, smart_strategy)
  groups = Marshal.load(Marshal.dump(groups))
  if auto_smart_switch == "1" || smart_strategy == "sticky-sessions"
    groups.each do |group|
      if auto_smart_switch == "1" && ["url-test", "load-balance"].include?(group["type"])
        group["type"] = "smart"
        group.delete("strategy")
      end
      if smart_strategy == "sticky-sessions" && group["type"] == "smart"
        group["strategy"] = smart_strategy
      end
    end
  end
  groups
end

source_groups = [
  {"name" => "Auto", "type" => "url-test"},
  {"name" => "Balance", "type" => "load-balance", "strategy" => "consistent-hashing"},
  {"name" => "Existing Smart", "type" => "smart"}
]

default_groups = convert_groups(source_groups, "1", "0")
raise "default smart_strategy should not write strategy" if default_groups.any? { |group| group["strategy"] == "sticky-sessions" }
converted_balance = default_groups.find { |group| group["name"] == "Balance" }
raise "auto smart switch should remove load-balance strategy" if converted_balance.key?("strategy")

sticky_existing_groups = convert_groups(source_groups, "0", "sticky-sessions")
existing = sticky_existing_groups.find { |group| group["name"] == "Existing Smart" }
raise "existing smart group should receive global sticky-sessions strategy" unless existing["strategy"] == "sticky-sessions"
non_smart = sticky_existing_groups.find { |group| group["name"] == "Auto" }
raise "global sticky-sessions strategy should not be written to non-Smart groups" if non_smart.key?("strategy")

sticky_groups = convert_groups(source_groups, "1", "sticky-sessions")
converted = sticky_groups.select { |group| ["Auto", "Balance"].include?(group["name"]) }
raise "converted groups should all be smart" unless converted.all? { |group| group["type"] == "smart" }
raise "converted groups should receive sticky-sessions" unless converted.all? { |group| group["strategy"] == "sticky-sessions" }
converted_balance = sticky_groups.find { |group| group["name"] == "Balance" }
raise "auto smart switch should replace load-balance strategy with sticky-sessions" unless converted_balance["strategy"] == "sticky-sessions"
existing = sticky_groups.find { |group| group["name"] == "Existing Smart" }
raise "existing smart group should receive global sticky-sessions strategy" unless existing["strategy"] == "sticky-sessions"

imported_uci = {}
yaml_group = {"name" => "Manual Smart", "type" => "smart", "strategy" => "sticky-sessions"}
if yaml_group.key?("strategy") && yaml_group["type"] == "smart"
  imported_uci["strategy_smart"] = yaml_group["strategy"].to_s
end
raise "Smart strategy should import as strategy_smart" unless imported_uci["strategy_smart"] == "sticky-sessions"

exported_group = {"name" => "Manual Smart", "type" => "smart"}
strategy_smart = imported_uci["strategy_smart"]
exported_group["strategy"] = strategy_smart if strategy_smart == "sticky-sessions"
raise "Smart strategy should export back to YAML" unless exported_group["strategy"] == "sticky-sessions"
RUBY

echo "ok - Smart sticky strategy wiring"
