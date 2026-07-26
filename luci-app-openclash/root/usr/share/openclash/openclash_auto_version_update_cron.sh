#!/bin/sh

OPENCLASH_LIB_DIR="${OPENCLASH_LIB_DIR:-/usr/share/openclash}"
CRON_FILE="${OPENCLASH_CRON_FILE:-/etc/crontabs/root}"
CRON_MARKER="#openclash-auto-version-update"

. "${OPENCLASH_LIB_DIR}/uci.sh"

auto_version_enabled=$(uci_get_config "auto_version_update" || echo 0)
week_time=$(uci_get_config "auto_version_update_week_time" || echo 1)
day_time=$(uci_get_config "auto_version_update_day_time" || echo 0)
schedule_valid=1

case "$day_time" in
   '') day_time=0 ;;
   *[!0-9]*) schedule_valid=0 ;;
   *) [ "$day_time" -ge 0 ] 2>/dev/null && [ "$day_time" -le 23 ] 2>/dev/null || schedule_valid=0 ;;
esac

case "$week_time" in
   '') week_time=1 ;;
   '*'|0|1|2|3|4|5|6) ;;
   *) schedule_valid=0 ;;
esac

mkdir -p "$(dirname "$CRON_FILE")" || exit 1
touch "$CRON_FILE" || exit 1

cron_tmp="${CRON_FILE}.auto-version.$$"
sed "\|${CRON_MARKER}|d" "$CRON_FILE" > "$cron_tmp" || {
   rm -f "$cron_tmp"
   exit 1
}

if [ "$auto_version_enabled" = "1" ] && [ "$schedule_valid" = "1" ]; then
   if [ -s "$cron_tmp" ] && [ -n "$(tail -n 1 "$cron_tmp" 2>/dev/null)" ]; then
      echo >> "$cron_tmp"
   fi
   echo "0 ${day_time} * * ${week_time} /usr/share/openclash/openclash_auto_version_update.sh ${CRON_MARKER}" >> "$cron_tmp"
fi

chmod 600 "$cron_tmp" 2>/dev/null
mv -f "$cron_tmp" "$CRON_FILE" || exit 1

if [ "${OPENCLASH_SKIP_CRON_RELOAD:-0}" != "1" ]; then
   crontab "$CRON_FILE" >/dev/null 2>&1 || exit 1
   /etc/init.d/cron restart >/dev/null 2>&1 || exit 1
fi

exit 0
