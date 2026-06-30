#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$REPO_ROOT/luci-app-openclash/root/etc/config/openclash"
SETTINGS="$REPO_ROOT/luci-app-openclash/luasrc/model/cbi/openclash/settings.lua"
INIT="$REPO_ROOT/luci-app-openclash/root/etc/init.d/openclash"
ZH_PO="$REPO_ROOT/luci-app-openclash/po/zh-cn/openclash.zh-cn.po"
ES_PO="$REPO_ROOT/luci-app-openclash/po/es/openclash.es.po"

fail() {
   echo "FAIL: $*" >&2
   exit 1
}

must_contain() {
   local file="$1"
   local text="$2"
   grep -F "$text" "$file" >/dev/null 2>&1 || fail "Expected '$text' in $file"
}

must_not_contain() {
   local file="$1"
   local text="$2"
   grep -F "$text" "$file" >/dev/null 2>&1 && fail "Did not expect '$text' in $file"
}

must_have_translation() {
   local file="$1"
   local text="$2"
   must_contain "$file" "msgid \"$text\""
   must_contain "$file" "msgstr \"$text\""
}

must_contain "$CONFIG" "option auto_version_update '0'"
must_contain "$CONFIG" "option auto_version_update_week_time '1'"
must_contain "$CONFIG" "option auto_version_update_day_time '0'"

must_contain "$SETTINGS" "auto_version_update"
must_contain "$SETTINGS" "自动版本更新"
must_contain "$SETTINGS" "自动检查并更新 OpenClash 客户端和内核版本"
must_contain "$SETTINGS" "更新时间（每周）"
must_contain "$SETTINGS" "更新时间（每天）"
must_not_contain "$SETTINGS" "Auto Version Update"

must_contain "$INIT" "openclash_auto_update.sh"
must_contain "$INIT" "auto_version_update_week_time"
must_contain "$INIT" "auto_version_update_day_time"

# New UI labels intentionally use Chinese source keys and identical Chinese
# translations in every catalog so this feature displays Chinese in all locales.
for text in \
   "自动版本更新" \
   "自动检查并更新 OpenClash 客户端和内核版本" \
   "更新时间（每周）" \
   "更新时间（每天）" \
   "每天" \
   "每周一" \
   "每周二" \
   "每周三" \
   "每周四" \
   "每周五" \
   "每周六" \
   "每周日"; do
   must_have_translation "$ZH_PO" "$text"
   must_have_translation "$ES_PO" "$text"
done

echo "openclash_auto_update_config_test.sh: PASS"
