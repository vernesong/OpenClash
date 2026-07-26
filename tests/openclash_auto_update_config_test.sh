#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$REPO_ROOT/luci-app-openclash/root/etc/config/openclash"
SETTINGS="$REPO_ROOT/luci-app-openclash/luasrc/model/cbi/openclash/settings.lua"
INIT="$REPO_ROOT/luci-app-openclash/root/etc/init.d/openclash"
CRON_SCRIPT="$REPO_ROOT/luci-app-openclash/root/usr/share/openclash/openclash_auto_version_update_cron.sh"
ZH_PO="$REPO_ROOT/luci-app-openclash/po/zh-cn/openclash.zh-cn.po"
ES_PO="$REPO_ROOT/luci-app-openclash/po/es/openclash.es.po"
TEST_TMP_DIRS=()

cleanup_tmp_dirs() {
   [ "${#TEST_TMP_DIRS[@]}" -gt 0 ] || return 0
   rm -rf "${TEST_TMP_DIRS[@]}"
}

trap cleanup_tmp_dirs EXIT

fail() {
   echo "FAIL: $*" >&2
   exit 1
}

assert_eq() {
   local expected="$1"
   local actual="$2"
   local message="$3"
   [ "$expected" = "$actual" ] || fail "$message
expected:
$expected
actual:
$actual"
}

must_contain() {
   local file="$1"
   local text="$2"
   grep -F "$text" "$file" >/dev/null 2>&1 || fail "Expected '$text' in $file"
}

must_not_contain() {
   local file="$1"
   local text="$2"
   if grep -F "$text" "$file" >/dev/null 2>&1; then
      fail "Did not expect '$text' in $file"
   fi
}

must_have_translation() {
   local file="$1"
   local msgid="$2"
   local msgstr="$3"
   must_contain "$file" "msgid \"$msgid\""
   must_contain "$file" "msgstr \"$msgstr\""
}

setup_cron_case() {
   TEST_TMP="$(mktemp -d)"
   TEST_TMP_DIRS+=("$TEST_TMP")
   export TEST_TMP
   export OPENCLASH_LIB_DIR="$TEST_TMP/lib"
   export OPENCLASH_CRON_FILE="$TEST_TMP/crontabs/root"
   export OPENCLASH_SKIP_CRON_RELOAD=1
   mkdir -p "$OPENCLASH_LIB_DIR" "$(dirname "$OPENCLASH_CRON_FILE")"

   cat > "$OPENCLASH_LIB_DIR/uci.sh" <<'STUB'
uci_get_config() {
   case "$1" in
      auto_version_update)
         [ "${TEST_AUTO_VERSION_UPDATE+x}" = x ] || return 1
         printf '%s\n' "$TEST_AUTO_VERSION_UPDATE"
      ;;
      auto_version_update_week_time)
         [ "${TEST_WEEK_TIME+x}" = x ] || return 1
         printf '%s\n' "$TEST_WEEK_TIME"
      ;;
      auto_version_update_day_time)
         [ "${TEST_DAY_TIME+x}" = x ] || return 1
         printf '%s\n' "$TEST_DAY_TIME"
      ;;
      *) return 1 ;;
   esac
}
STUB
}

teardown_cron_case() {
   rm -rf "$TEST_TMP"
   unset TEST_TMP OPENCLASH_LIB_DIR OPENCLASH_CRON_FILE
   unset OPENCLASH_SKIP_CRON_RELOAD TEST_AUTO_VERSION_UPDATE
   unset TEST_WEEK_TIME TEST_DAY_TIME
}

run_cron_sync() {
   sh "$CRON_SCRIPT"
}

assert_marker_count() {
   local expected="$1"
   local actual
   actual="$(grep -c '#openclash-auto-version-update' "$OPENCLASH_CRON_FILE" 2>/dev/null || true)"
   assert_eq "$expected" "$actual" "Unexpected auto-version cron entry count"
}

test_cron_enabled_uses_defaults_and_preserves_other_lines() {
   setup_cron_case
   export TEST_AUTO_VERSION_UPDATE=1
   printf '%s\n' \
      '17 3 * * * /usr/bin/other-job #keep-me' \
      '45 9 * * 5 /old/path #openclash-auto-version-update' \
      > "$OPENCLASH_CRON_FILE"

   run_cron_sync

   must_contain "$OPENCLASH_CRON_FILE" '17 3 * * * /usr/bin/other-job #keep-me'
   must_contain "$OPENCLASH_CRON_FILE" '0 0 * * 1 /usr/share/openclash/openclash_auto_version_update.sh #openclash-auto-version-update'
   must_not_contain "$OPENCLASH_CRON_FILE" '/old/path'
   assert_marker_count 1
   teardown_cron_case
}

test_cron_invalid_values_fail_closed() {
   setup_cron_case
   export TEST_AUTO_VERSION_UPDATE=1
   export TEST_WEEK_TIME='8'
   export TEST_DAY_TIME='24;touch /tmp/not-allowed'
   printf '%s\n' '17 3 * * * /usr/bin/other-job #keep-me' > "$OPENCLASH_CRON_FILE"

   run_cron_sync

   must_contain "$OPENCLASH_CRON_FILE" '17 3 * * * /usr/bin/other-job #keep-me'
   must_not_contain "$OPENCLASH_CRON_FILE" 'not-allowed'
   assert_marker_count 0
   teardown_cron_case
}

test_cron_accepts_every_day_and_last_hour() {
   setup_cron_case
   export TEST_AUTO_VERSION_UPDATE=1
   export TEST_WEEK_TIME='*'
   export TEST_DAY_TIME='23'

   run_cron_sync

   must_contain "$OPENCLASH_CRON_FILE" '0 23 * * * /usr/share/openclash/openclash_auto_version_update.sh #openclash-auto-version-update'
   teardown_cron_case
}

test_cron_sync_is_idempotent() {
   setup_cron_case
   export TEST_AUTO_VERSION_UPDATE=1
   export TEST_WEEK_TIME=6
   export TEST_DAY_TIME=4

   run_cron_sync
   first="$(cat "$OPENCLASH_CRON_FILE")"
   run_cron_sync
   second="$(cat "$OPENCLASH_CRON_FILE")"

   assert_eq "$first" "$second" "Repeated cron sync should not change the file"
   assert_marker_count 1
   teardown_cron_case
}

test_cron_disabled_removes_stale_entry_only() {
   setup_cron_case
   export TEST_AUTO_VERSION_UPDATE=0
   printf '%s\n' \
      '17 3 * * * /usr/bin/other-job #keep-me' \
      '0 1 * * 2 /usr/share/openclash/openclash_auto_version_update.sh #openclash-auto-version-update' \
      > "$OPENCLASH_CRON_FILE"

   run_cron_sync

   must_contain "$OPENCLASH_CRON_FILE" '17 3 * * * /usr/bin/other-job #keep-me'
   assert_marker_count 0
   teardown_cron_case
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

must_contain "$INIT" "openclash_auto_version_update_cron.sh"
must_contain "$INIT" "refresh_auto_version_update_cron"

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

test_cron_enabled_uses_defaults_and_preserves_other_lines
test_cron_invalid_values_fail_closed
test_cron_accepts_every_day_and_last_hour
test_cron_sync_is_idempotent
test_cron_disabled_removes_stale_entry_only

echo "openclash_auto_update_config_test.sh: PASS"
