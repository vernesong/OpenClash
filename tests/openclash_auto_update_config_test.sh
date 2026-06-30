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
   return 0
}

must_have_translation() {
   local file="$1"
   local msgid="$2"
   local msgstr="$3"
   must_contain "$file" "msgid \"$msgid\""
   must_contain "$file" "msgstr \"$msgstr\""
}

must_contain "$CONFIG" "option auto_version_update '0'"
must_contain "$CONFIG" "option auto_version_update_week_time '1'"
must_contain "$CONFIG" "option auto_version_update_day_time '0'"

must_contain "$SETTINGS" "auto_version_update"
must_contain "$SETTINGS" "Automatic Version Update"
must_contain "$SETTINGS" "Automatically check and update OpenClash client and core versions"
must_contain "$SETTINGS" "Update Time (Every Week)"
must_contain "$SETTINGS" "Update time (every day)"
must_not_contain "$SETTINGS" "自动版本更新"

must_contain "$INIT" "openclash_auto_update.sh"
must_contain "$INIT" "auto_version_update_week_time"
must_contain "$INIT" "auto_version_update_day_time"

# UI source strings follow the existing LuCI pattern: English msgid keys with
# locale-specific msgstr values. Chinese UI displays Chinese through zh-cn.
must_have_translation "$ZH_PO" "Automatic Version Update" "自动版本更新"
must_have_translation "$ZH_PO" "Automatically check and update OpenClash client and core versions" "自动检查并更新 OpenClash 客户端和内核版本"
must_have_translation "$ZH_PO" "Update Time (Every Week)" "更新时间(每周)"
must_have_translation "$ZH_PO" "Update time (every day)" "更新时间(每天)"
must_have_translation "$ZH_PO" "Every Day" "每天"
must_have_translation "$ZH_PO" "Every Monday" "每周一"
must_have_translation "$ZH_PO" "Every Tuesday" "每周二"
must_have_translation "$ZH_PO" "Every Wednesday" "每周三"
must_have_translation "$ZH_PO" "Every Thursday" "每周四"
must_have_translation "$ZH_PO" "Every Friday" "每周五"
must_have_translation "$ZH_PO" "Every Saturday" "每周六"
must_have_translation "$ZH_PO" "Every Sunday" "每周日"

must_have_translation "$ES_PO" "Automatic Version Update" "Actualización automática de versión"
must_have_translation "$ES_PO" "Automatically check and update OpenClash client and core versions" "Comprobar y actualizar automáticamente las versiones del cliente y del núcleo de OpenClash"
must_have_translation "$ES_PO" "Update Time (Every Week)" "Hora de actualización (cada semana)"
must_have_translation "$ES_PO" "Update time (every day)" "Hora de actualización (cada día)"
must_have_translation "$ES_PO" "Every Day" "Cada día"
must_have_translation "$ES_PO" "Every Monday" "Cada lunes"
must_have_translation "$ES_PO" "Every Tuesday" "Cada martes"
must_have_translation "$ES_PO" "Every Wednesday" "Cada miércoles"
must_have_translation "$ES_PO" "Every Thursday" "Cada jueves"
must_have_translation "$ES_PO" "Every Friday" "Cada viernes"
must_have_translation "$ES_PO" "Every Saturday" "Cada sábado"
must_have_translation "$ES_PO" "Every Sunday" "Cada domingo"

echo "openclash_auto_update_config_test.sh: PASS"
