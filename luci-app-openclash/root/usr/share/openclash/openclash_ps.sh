#!/bin/sh
. $IPKG_INSTROOT/usr/share/openclash/uci.sh

JOB_COUNTER_FILE="/tmp/openclash_jobs"

replace_openclash_file() {
   local source="$2" target="$3" staged
   [ ! -d "$target" ] || return 1
   staged=$(mktemp "${target%/*}/.openclash-file.XXXXXX") || return 1
   if [ "$1" = cp ]; then
      cp -p "$source" "$staged"
   else
      mv -f "$source" "$staged"
   fi && mv -f "$staged" "$target" && return 0
   rm -f "$staged"
   return 1
}

unify_ps_status() {
   if [ "$(ps --version 2>&1 |grep -c procps-ng)" -eq 1 ]; then
      echo "$(ps -efw |grep -v grep |grep -c "$1")"
   else
      echo "$(ps -w |grep -v grep |grep -c "$1")"
   fi
}

unify_ps_pids() {
   if [ "$(ps --version 2>&1 |grep -c procps-ng)" -eq 1 ]; then
      echo "$(ps -efw |grep "$1" |grep -v grep |awk '{print $2}' 2>/dev/null)"
   else
      echo "$(ps -w |grep "$1" |grep -v grep |awk '{print $1}' 2>/dev/null)"
   fi
}

unify_ps_prevent() {
   if [ "$(ps --version 2>&1 |grep -c procps-ng)" -eq 1 ]; then
      echo "$(ps -efw |grep -v grep |grep -c "/etc/init.d/openclash")"
   else
      echo "$(ps -w |grep -v grep |grep -c "/etc/init.d/openclash")"
   fi
}

unify_ps_cfgname() {
   if [ "$(ps --version 2>&1 |grep -c procps-ng)" -eq 1 ]; then
      echo "$(ps -efw |grep /etc/openclash/clash 2>/dev/null |grep -v grep |awk -F '-f ' '{print $2}' 2>/dev/null)"
   else
      echo "$(ps -w |grep /etc/openclash/clash 2>/dev/null |grep -v grep |awk -F '-f ' '{print $2}' 2>/dev/null)"
   fi
}

inc_job_counter() {
   exec 999>"/tmp/lock/openclash_jobs.lock"
   flock -x 999
   local cnt=0
   local restart=0
   [ -f "$JOB_COUNTER_FILE" ] && cnt=$(cat "$JOB_COUNTER_FILE" | awk '{print $1}') && restart=$(cat "$JOB_COUNTER_FILE" | awk '{print $2}')
   cnt=$((cnt+1))
   echo "$cnt $restart" > "$JOB_COUNTER_FILE"
   flock -u 999
}

openclash_install_apk() (
	file=$1
	case "$file" in /*) ;; *) file="$PWD/$file" ;; esac
	force=$2
	cache=$(mktemp -d /tmp/.openclash-apk.XXXXXX) || exit 1
	trap 'rm -rf "$cache"' EXIT
	trap 'exit 1' HUP INT TERM
	cd "$cache" || exit 1
	# apk continues unpacking on a pre-upgrade error. Check the candidate's backup before entering the transaction.
	apk verify --no-network --allow-untrusted "$file" || exit 1
	if apk info --no-network --exists luci-app-openclash >/dev/null 2>&1 || [ -f /etc/config/openclash ] || [ -d /etc/openclash ]; then
		apk adbdump --format json "$file" >"$cache/package.json" || exit 1
		[ "$(jsonfilter -i "$cache/package.json" -e '@.info.name')" = luci-app-openclash ] || exit 1
		if jsonfilter -i "$cache/package.json" -e '@.scripts["pre-upgrade"]' >"$cache/pre-upgrade"; then
			if grep -Eq '^[[:space:]]*# openclash-package-preflight-v1$' "$cache/pre-upgrade"; then
				sh "$cache/pre-upgrade" openclash-preflight check "$cache/backup" || exit 1
			fi
		else
			scripts=$(jsonfilter -i "$cache/package.json" -e '@.scripts') || exit 1
			case "$scripts" in *'"pre-upgrade":'*) exit 1 ;; esac
		fi
	fi
	if [ "$force" != 1 ]; then
		apk add -q --force-overwrite --clean-protected --allow-untrusted "$file"
		exit $?
	fi
	key=$(apk adbdump "$file" | awk '
		/^  name: / {name=$2}
		/^  version: / {version=$2}
		/^  hashes: / {
			if (name=="luci-app-openclash" && version ~ /^[0-9][A-Za-z0-9._+-]*$/ && $2 ~ /^[0-9a-f]+$/ && length($2)>=8)
				print name "-" version "." substr($2,1,8) ".apk"
			exit
		}')
	[ -n "$key" ] && ln -s "$file" "$cache/$key" || exit 1
	apk --cache-dir "$cache" --repositories-file /dev/null --no-network --allow-untrusted fix --reinstall --force-overwrite --clean-protected luci-app-openclash >"$cache/result" 2>&1
	status=$?
	cat "$cache/result"
	if grep -Fq '[APK unavailable, skipped]' "$cache/result"; then
		apk add -q --force-overwrite --clean-protected --allow-untrusted "$file"
	else
		exit "$status"
	fi
)

openclash_package_restore_pending() {
   [ -d /tmp/openclash-package-backup ] || [ -f /tmp/openclash.bak ] || [ -f /etc/uci-defaults/luci-openclash ]
}

dec_job_counter_and_restart() {
   local restart_flag="$1"
   local suppress_restart="${2:-0}"
   exec 999>"/tmp/lock/openclash_jobs.lock"
   flock -x 999
   local cnt=0
   local restart=0
   [ -f "$JOB_COUNTER_FILE" ] && cnt=$(cat "$JOB_COUNTER_FILE" | awk '{print $1}') && restart=$(cat "$JOB_COUNTER_FILE" | awk '{print $2}')
   cnt=$((cnt-1))
   [ $cnt -lt 0 ] && cnt=0

   if [ "$restart_flag" -eq 1 ]; then
      restart=1
   fi

   echo "$cnt $restart" > "$JOB_COUNTER_FILE"

   if [ "$suppress_restart" != "1" ] && [ $cnt -eq 0 ] && [ "$restart" -eq 1 ] && ! openclash_package_restore_pending && [ "$(unify_ps_prevent)" -eq 0 ]; then
      /etc/init.d/openclash restart >/dev/null 2>&1 &
      rm -rf "$JOB_COUNTER_FILE" >/dev/null 2>&1
   fi

   flock -u 999
}
