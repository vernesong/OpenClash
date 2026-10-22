#!/bin/sh

set -u

C_INFO=""
C_DIM=""
C_TREE=""
C_STAGE=""
C_OK=""
C_WARN=""
C_ERROR=""
C_RESET=""
if [ -z "${NO_COLOR:-}" ] && { [ -n "${CLICOLOR_FORCE:-}" ] || [ -t 1 ]; }; then
	C_INFO=$(printf '\033[32m')
	C_DIM=$(printf '\033[2m')
	C_TREE=$(printf '\033[36m')
	C_STAGE=$(printf '\033[1;36m')
	C_OK=$(printf '\033[1;32m')
	C_WARN=$(printf '\033[33m')
	C_ERROR=$(printf '\033[1;31m')
	C_RESET=$(printf '\033[0m')
fi

REPO_OWNER="vernesong"
REPO_NAME="OpenClash"
REPO_RAW="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}"
REPO_CDN_PATH="gh/${REPO_OWNER}/${REPO_NAME}"

JSDELIVR_MIRRORS="https://cdn.jsdelivr.net https://fastly.jsdelivr.net https://testingcf.jsdelivr.net"
# Built-in copy of luci-app-openclash/root/usr/share/openclash/res/cdn.list
BUILTIN_MIRRORS="https://github.chenc.dev/ https://xsadwsd.kdns.fr/ https://cdn.akaere.online/ https://githubproxy.gohj99.site/ https://gh-proxy.com/ https://gh.acmsz.top/ https://git.yylx.win/ https://gh.b52m.cn/ https://ghm.078465.xyz/ https://gh.sixyin.com/ https://ghproxy.felicity.land/ https://cfgh.ikgy.top/ https://github.tbap.top/ https://gh.jjj.gv.uy/"

BRANCH=""
CORE_KIND=""
ARCH_OVERRIDE=""
FORCE=0
PKG_TYPE=""
FIREWALL=""
SERVICE_WAS_RUNNING=0
CORE_ARCH_RESOLVED=""
DOWNLOAD_SOURCE=""
DOWNLOAD_SIZE_KB=0
PROBE_BEST_KB=0
PLUGIN_KB=0
CORE_KB=0
CURL_PID=""
TMP_DIR="/tmp/openclash_install.$$"
URLS_FILE="${TMP_DIR}/urls"
CHECKSUMS_PLUGIN="${TMP_DIR}/checksums_plugin.txt"
CHECKSUMS_CORE="${TMP_DIR}/checksums_core.txt"
RESOLV_CONF="/etc/resolv.conf"
RESOLV_BACKUP="${TMP_DIR}/resolv.conf.bak"
INSTALL_DNS="223.5.5.5 119.29.29.29 1.1.1.1"
RESOLV_MANAGED=0
RESOLV_EXISTED=0
RESOLV_WRITTEN=""
BASE_DEPS="bash ip-full ruby ruby-yaml unzip kmod-tun ruby-psych ruby-pstore"
FIREWALL_DEPS=""
PKG_INDEX_UPDATED=0
STAGE=0
STAGE_TOTAL=0

usage() {
	cat <<'EOF'
OpenClash installer for OpenWrt

Usage: sh install.sh [options]

Options:
  -b, --branch <master|dev>  release branch to install (default: dev)
  -c, --core <meta|smart|none>
                             core to install (default: meta)
  -a, --arch <linux-*>       override the detected core architecture
  -f, --force                reinstall even if already up to date
  -h, --help                 show this help
EOF
}

log_line() {
	local tag="$1" color="$2"
	shift 2
	printf '  %s[%s]%s %s%s%s %s\n' "$C_DIM" "$(date +%H:%M:%S)" "$C_RESET" "$color" "$tag" "$C_RESET" "$*"
}

info() {
	log_line "[INFO]" "$C_INFO" "$*"
}

warn() {
	log_line "[WARN]" "$C_WARN" "$*" >&2
}

error() {
	log_line "[ERROR]" "$C_ERROR" "$*" >&2
}

section() {
	printf '\n%s==> %s%s\n' "$C_STAGE" "$*" "$C_RESET"
}

stage() {
	STAGE=$((STAGE + 1))
	printf '\n%s==> [%d/%d] %s%s\n' "$C_STAGE" "$STAGE" "$STAGE_TOTAL" "$*" "$C_RESET"
}

done_text() {
	printf '\n%s==> %s%s\n' "$C_OK" "$*" "$C_RESET"
}

die() {
	error "$*"
	exit 1
}

fmt_size() {
	awk -v kb="$1" 'BEGIN { if (kb >= 1048576) printf "%.1f GB", kb / 1048576; else if (kb >= 1024) printf "%.1f MB", kb / 1024; else printf "%d KB", kb }'
}

fmt_speed() {
	awk -v kb="$1" 'BEGIN { if (kb >= 1024) printf "%.1f MB/s", kb / 1024; else printf "%d KB/s", kb }'
}

url_host() {
	printf '%s' "$1" | sed 's#^[a-zA-Z]*://##; s#/.*##'
}

pause_exit() {
	local saved
	[ -t 0 ] || return 0
	printf '\n  [INFO] press any key to exit'
	saved=$(stty -g 2>/dev/null)
	stty -echo -icanon min 1 time 0 2>/dev/null
	dd bs=1 count=1 >/dev/null 2>&1 || read -r _
	[ -n "$saved" ] && stty "$saved" 2>/dev/null
	printf '\n'
}

run_with_timeout() {
	local timeout_sec="$1"
	shift
	"$@" &
	local pid=$!
	(
		sleep "$timeout_sec"
		kill "$pid" 2>/dev/null
		sleep 1
		kill -9 "$pid" 2>/dev/null
	) >/dev/null 2>&1 &
	local watchdog=$!
	wait "$pid" 2>/dev/null
	local ret=$?
	kill "$watchdog" 2>/dev/null
	wait "$watchdog" 2>/dev/null
	return "$ret"
}

pkg_is_installed() {
	if [ "$PKG_TYPE" = "apk" ]; then
		apk list "$1" 2>/dev/null | grep '\[installed\]' | grep -q "^$1-[0-9]"
	else
		opkg status "$1" 2>/dev/null | grep -q '^Status: .* installed$'
	fi
}

pkg_is_available() {
	if [ "$PKG_TYPE" = "apk" ]; then
		apk list "$1" 2>/dev/null | grep -q "^$1-[0-9]"
	else
		opkg info "$1" 2>/dev/null | grep -q "^Package: $1$"
	fi
}

pkg_install() {
	if [ "$PKG_TYPE" = "apk" ]; then
		apk add -q "$@" >/dev/null 2>&1
	else
		opkg install "$@" >/dev/null 2>&1
	fi
}

pkg_update() {
	local i=1 err rc
	while [ "$i" -le 3 ]; do
		if [ "$PKG_TYPE" = "apk" ]; then
			err=$(run_with_timeout 180 apk update 2>&1)
			rc=$?
			rm -f /lib/apk/db/lock 2>/dev/null
		else
			err=$(run_with_timeout 180 opkg update 2>&1)
			rc=$?
			rm -f /var/lock/opkg.lock 2>/dev/null
		fi
		if [ "$rc" -eq 0 ]; then
			PKG_INDEX_UPDATED=1
			return 0
		fi
		i=$((i + 1))
		if [ "$i" -le 3 ]; then
			warn "package index update failed, retrying (${i}/3)"
			sleep 2
		fi
	done
	[ -n "$err" ] || err="no output (timed out or network unavailable)"
	warn "package index update failed: $(printf '%s' "$err" | tr '\n' ' ' | head -c 300)"
	return 1
}

free_space_kb() {
	local kb
	kb=$(df -Pk "$1" 2>/dev/null | tail -n 1 | awk '{ print $4 }')
	case "$kb" in
		''|*[!0-9]*) return 1 ;;
	esac
	printf '%s\n' "$kb"
}

require_space() {
	local path="$1" need_kb="$2" label="$3" avail answer
	avail=$(free_space_kb "$path") || {
		warn "unable to read free space on ${path}, skipping the ${label} check"
		return 0
	}
	if [ "$avail" -ge "$need_kb" ]; then
		info "free space on ${path}: $(fmt_size "$avail") (need $(fmt_size "$need_kb"))"
		return 0
	fi
	warn "insufficient space on ${path} for ${label}: $(fmt_size "$avail") free, $(fmt_size "$need_kb") needed"
	if [ -t 0 ]; then
		printf 'Continue anyway? [Y/n] ' >&2
		IFS= read -r answer || answer=""
		case "$answer" in
			n|N|no|NO) error "aborted by user"; return 1 ;;
		esac
		info "continuing as requested"
		return 0
	fi
	warn "continuing without confirmation (non-interactive)"
	return 0
}

package_install_kb() {
	local file="$1" payload_kb=""
	if [ "$PKG_TYPE" = "opkg" ]; then
		payload_kb=$(tar -xOf "$file" data.tar.gz 2>/dev/null | gzip -dc 2>/dev/null | tar -tv 2>/dev/null | awk '{ size += $3 } END { if (size > 0) print int(size / 1024) }')
		if [ -z "$payload_kb" ]; then
			payload_kb=$(tar -xOf "$file" ./data.tar.gz 2>/dev/null | gzip -dc 2>/dev/null | tar -tv 2>/dev/null | awk '{ size += $3 } END { if (size > 0) print int(size / 1024) }')
		fi
	fi
	case "$payload_kb" in
		''|*[!0-9]*) payload_kb=$(($(wc -c < "$file") / 1024 * 3)) ;;
	esac
	printf '%s\n' "$payload_kb"
}

has_network_dns() {
	command -v nslookup >/dev/null 2>&1 || return 0
	nslookup captive.apple.com >/dev/null 2>&1
}

ensure_install_dns() {
	local ip
	has_network_dns && return 0
	mkdir -p "$TMP_DIR" 2>/dev/null
	RESOLV_EXISTED=0
	if [ -f "$RESOLV_CONF" ]; then
		if cat "$RESOLV_CONF" > "$RESOLV_BACKUP" 2>/dev/null; then
			RESOLV_EXISTED=1
		else
			return 0
		fi
	fi
	{
		[ -s "$RESOLV_BACKUP" ] && grep -vE '^[[:space:]]*nameserver[[:space:]]' "$RESOLV_BACKUP"
		for ip in $INSTALL_DNS; do
			printf 'nameserver %s\n' "$ip"
		done
	} > "$RESOLV_CONF" 2>/dev/null || return 0
	RESOLV_MANAGED=1
	RESOLV_WRITTEN=$(cat "$RESOLV_CONF" 2>/dev/null)
	info "DNS lookup failed, temporarily using upstream DNS ${INSTALL_DNS}"
}

restore_install_dns() {
	local current running=1
	[ "$RESOLV_MANAGED" = "1" ] || return 0
	RESOLV_MANAGED=0
	current=$(cat "$RESOLV_CONF" 2>/dev/null)
	[ "$current" = "$RESOLV_WRITTEN" ] || return 0
	if ! pkg_is_installed dnsmasq && ! pkg_is_installed dnsmasq-full; then
		warn "no DNS server package is installed, keeping the temporary upstream DNS in ${RESOLV_CONF}"
		return 0
	fi
	if command -v pidof >/dev/null 2>&1; then
		pidof dnsmasq >/dev/null 2>&1 || running=0
	elif command -v pgrep >/dev/null 2>&1; then
		pgrep -f '[d]nsmasq' >/dev/null 2>&1 || running=0
	fi
	if [ "$running" = "0" ]; then
		warn "dnsmasq is not running, keeping the temporary upstream DNS in ${RESOLV_CONF}"
		return 0
	fi
	if command -v nslookup >/dev/null 2>&1 && ! nslookup captive.apple.com 127.0.0.1 >/dev/null 2>&1; then
		warn "dnsmasq is not serving DNS, keeping the temporary upstream DNS in ${RESOLV_CONF}"
		return 0
	fi
	if [ "$RESOLV_EXISTED" = "1" ]; then
		cp -f "$RESOLV_BACKUP" "$RESOLV_CONF" 2>/dev/null
	else
		rm -f "$RESOLV_CONF" 2>/dev/null
	fi
}

ensure_dnsmasq_full() {
	local cache="${TMP_DIR}/pkg-cache" backup="${TMP_DIR}/dnsmasq-backup" installed="" attempt=1
	pkg_is_installed dnsmasq-full && return 0
	warn "OpenClash requires dnsmasq-full, replacing dnsmasq"
	ensure_install_dns
	if pkg_is_installed dnsmasq; then
		mkdir -p "$backup" 2>/dev/null
		# cache dnsmasq before it is removed, the rollback may run while DNS is broken
		if [ "$PKG_TYPE" = "apk" ]; then
			apk fetch --output "$backup" dnsmasq >/dev/null 2>&1
		else
			(cd "$backup" && opkg download dnsmasq >/dev/null 2>&1)
		fi
		installed=$(ls -A "$backup" 2>/dev/null)
		if [ -n "$installed" ]; then
			info "cached dnsmasq for rollback"
		else
			warn "unable to cache dnsmasq, the rollback will need the network"
		fi
	fi
	while [ "$attempt" -le 3 ]; do
		info "installing dnsmasq-full (${attempt}/3)"
		if [ "$PKG_TYPE" = "apk" ]; then
			# apk purges the conflicting dnsmasq before the transaction downloads finish,
			# so cache every package before the transaction starts.
			apk --cache-predownload add dnsmasq-full >/dev/null 2>&1
		else
			mkdir -p "$cache" 2>/dev/null
			if opkg --cache "$cache" --download-only install dnsmasq-full >/dev/null 2>&1; then
				pkg_is_installed dnsmasq && opkg remove --force-depends dnsmasq >/dev/null 2>&1
				opkg --cache "$cache" install dnsmasq-full >/dev/null 2>&1
			fi
		fi
		if pkg_is_installed dnsmasq-full; then
			rm -rf "$cache" "$backup" 2>/dev/null
			info "installed dnsmasq-full"
			return 0
		fi
		warn "failed to install dnsmasq-full (attempt ${attempt}/3)"
		attempt=$((attempt + 1))
		[ "$attempt" -le 3 ] && sleep 2
	done
	rm -rf "$cache" 2>/dev/null
	warn "failed to install dnsmasq-full, restoring dnsmasq"
	if [ -n "$installed" ]; then
		if [ "$PKG_TYPE" = "apk" ]; then
			apk add -q --force-overwrite --allow-untrusted "$backup"/*.apk >/dev/null 2>&1
		else
			opkg install --force-depends "$backup"/*.ipk >/dev/null 2>&1
		fi
	fi
	pkg_is_installed dnsmasq || pkg_install dnsmasq
	rm -rf "$backup" 2>/dev/null
	return 1
}

install_pkg_with_retry() {
	local pkg="$1" attempt=1
	pkg_is_installed "$pkg" && return 0
	while [ "$attempt" -le 3 ]; do
		info "installing dependency ${pkg} (${attempt}/3)"
		if pkg_install "$pkg" && pkg_is_installed "$pkg"; then
			info "installed dependency ${pkg}"
			return 0
		fi
		warn "failed to install ${pkg}"
		attempt=$((attempt + 1))
		[ "$attempt" -le 3 ] && sleep 2
	done
	return 1
}

deps_ready() {
	local pkg
	pkg_is_installed dnsmasq-full || return 1
	for pkg in $BASE_DEPS $FIREWALL_DEPS; do
		pkg_is_installed "$pkg" || return 1
	done
	if ! pkg_is_installed luci-compat && pkg_is_available luci-compat; then
		return 1
	fi
	return 0
}

install_extra_deps() {
	local pkgs="${BASE_DEPS} ${FIREWALL_DEPS}"
	local conditional="luci-compat"
	local optional="kmod-inet-diag"
	local pkg
	for pkg in $pkgs; do
		if ! install_pkg_with_retry "$pkg"; then
			error "failed to install dependency: ${pkg}"
			return 1
		fi
	done
	for pkg in $conditional; do
		pkg_is_installed "$pkg" && continue
		if ! pkg_is_available "$pkg"; then
			info "dependency not provided by this release: ${pkg}"
			continue
		fi
		if ! install_pkg_with_retry "$pkg"; then
			error "failed to install dependency: ${pkg}"
			return 1
		fi
	done
	# kmod-inet-diag is not available on every target
	for pkg in $optional; do
		pkg_is_installed "$pkg" && continue
		if ! pkg_is_available "$pkg"; then
			info "optional dependency not available: ${pkg}"
			continue
		fi
		info "installing optional dependency: ${pkg}"
		if pkg_install "$pkg"; then
			info "installed optional dependency: ${pkg}"
		else
			warn "failed to install optional dependency: ${pkg}"
		fi
	done
}

# jsdelivr serves gh/<owner>/<repo>@<ref>/<path>; other proxies take the raw URL as a suffix
cdn_url() {
	local base="$1" path="$2"
	case "$base" in
		*jsdelivr.net|*jsdelivr.net/)
			printf '%s/%s@%s\n' "${base%/}" "$REPO_CDN_PATH" "$path"
			;;
		*/)
			printf '%s%s/%s\n' "$base" "$REPO_RAW" "$path"
			;;
		*)
			printf '%s/%s/%s\n' "$base" "$REPO_RAW" "$path"
			;;
	esac
}

build_urls() {
	local path="$1" m
	{
		printf '%s\n' "${REPO_RAW}/${path}"
		for m in $JSDELIVR_MIRRORS $BUILTIN_MIRRORS; do
			cdn_url "$m" "$path"
		done
	} > "$URLS_FILE"
}

fetch_text() {
	local path="$1" dest="$2" max_time="$3" url rc
	build_urls "$path"
	while IFS= read -r url; do
		[ -n "$url" ] || continue
		rm -f "$dest"
		curl -fsSL --connect-timeout 5 -m "$max_time" --retry 1 -o "$dest" "$url" 2>/dev/null
		rc=$?
		if [ "$rc" -eq 0 ] && [ -s "$dest" ]; then
			return 0
		fi
		warn "fetch failed (curl exit ${rc}), trying the next mirror"
	done < "$URLS_FILE"
	rm -f "$dest"
	return 1
}

probe_mirrors() {
	local dir="${TMP_DIR}/probe.$$" picks="${URLS_FILE}.picks" ranked="${URLS_FILE}.ranked"
	local alive_file="${URLS_FILE}.alive" rest_file="${URLS_FILE}.rest" sorted
	local url out code size speed n=0 probed=0 alive=0 top top_speed top_url top_host top_kb
	rm -rf "$dir"
	rm -f "$picks" "$ranked" "$alive_file" "$rest_file"
	mkdir -p "$dir" || return 0
	info "probing mirror speed"
	# the leading entries say nothing about the rest of the list, so pick a random sample
	awk -v seed="${RANDOM:-$$}" 'BEGIN { srand(seed) } { a[NR] = $0 } END { n = NR; for (i = n; i > 1; i--) { j = int(rand() * i) + 1; t = a[i]; a[i] = a[j]; a[j] = t } for (i = 1; i <= n && i <= 5; i++) print a[i] }' "$URLS_FILE" > "$picks" 2>/dev/null
	while IFS= read -r url; do
		[ -n "$url" ] || continue
		n=$((n + 1))
		(
			out=$(curl -sL -r 0-262143 -o /dev/null --connect-timeout 4 -m 6 -w '%{http_code} %{size_download} %{speed_download}' "$url" 2>/dev/null)
			printf '%s\n' "$out" > "$dir/$n"
		) &
	done < "$picks"
	wait
	n=0
	while IFS= read -r url; do
		[ -n "$url" ] || continue
		n=$((n + 1))
		probed=$((probed + 1))
		code="" size=0 speed=0
		[ -f "$dir/$n" ] && read -r code size speed < "$dir/$n"
		case "$code" in 200|206) ;; *) size=0 ;; esac
		case "$size" in ''|*[!0-9]*) size=0 ;; esac
		case "$speed" in ''|*[!0-9.]*) speed=0 ;; esac
		# skip answers that are too short to measure, such as error pages
		[ "$size" -ge 32768 ] && printf '%s %s\n' "$speed" "$url" >> "$alive_file"
	done < "$picks"
	rm -rf "$dir"
	rm -f "$picks"
	if [ -s "$alive_file" ]; then
		sorted=$(sort -rn "$alive_file" 2>/dev/null)
		printf '%s\n' "$sorted" | sed 's/^[^ ]* //' > "$ranked"
		alive=$(wc -l < "$ranked")
		alive=${alive##* }
		top=$(printf '%s\n' "$sorted" | head -n 1)
		top_speed=${top%% *}
		top_url=${top#* }
		top_host=$(url_host "$top_url")
		top_kb=$(awk -v s="$top_speed" 'BEGIN { printf "%d", s / 1024 }')
		while IFS= read -r url; do
			[ -n "$url" ] || continue
			grep -Fxq "$url" "$ranked" || printf '%s\n' "$url" >> "$rest_file"
		done < "$URLS_FILE"
		cat "$ranked" "$rest_file" > "${URLS_FILE}.new"
		mv "${URLS_FILE}.new" "$URLS_FILE"
		PROBE_BEST_KB=$top_kb
		info "mirror probe: ${alive}/${probed} usable, fastest ${top_host} ($(fmt_speed "$top_kb"))"
	else
		PROBE_BEST_KB=0
		warn "mirror probe: no mirror delivered any data, keeping the default order"
	fi
	rm -f "$ranked" "$alive_file" "$rest_file"
}

download_path() {
	local path="$1" dest="$2" label="$3" max_time="$4" checksums="$5" filename="$6"
	local url rc expected actual size header total pct speed_kb last_size waited ticks=0 switches=0 avg_kb idx=0 url_total slow=0
	build_urls "$path"
	probe_mirrors
	url_total=$(wc -l < "$URLS_FILE")
	while IFS= read -r url; do
		[ -n "$url" ] || continue
		idx=$((idx + 1))
		info "downloading ${label} from $(url_host "$url")"
		rm -f "$dest"
		header="${dest}.headers"
		rm -f "$header"
		last_size=0
		waited=0
		ticks=0
		slow=0
		curl -fL -sS --connect-timeout 10 -m "$max_time" --speed-time 30 --speed-limit 1024 --retry 1 --retry-delay 2 -D "$header" -o "$dest" "$url" &
		CURL_PID=$!
		while kill -0 "$CURL_PID" 2>/dev/null; do
			sleep 2
			size=0
			[ -f "$dest" ] && size=$(wc -c < "$dest" 2>/dev/null)
			case "$size" in ''|*[!0-9]*) size=0 ;; esac
			if [ "$size" -eq 0 ]; then
				waited=$((waited + 2))
				if [ $((waited % 10)) -eq 0 ]; then
					info "${label}: waiting for the server (${waited}s)"
				fi
				continue
			fi
			ticks=$((ticks + 1))
			total=0
			[ -f "$header" ] && total=$(tr -d '\r' < "$header" 2>/dev/null | awk 'tolower($1) == "content-length:" { v = $2 } END { print v }')
			case "$total" in ''|*[!0-9]*) total=0 ;; esac
			speed_kb=$(((size - last_size) / 2048))
			[ "$speed_kb" -lt 0 ] && speed_kb=0
			if [ "$total" -gt 0 ]; then
				pct=$((size * 100 / total))
				[ "$pct" -gt 100 ] && pct=100
				info "${label}: ${pct}% ($(fmt_size $((size / 1024)))/$(fmt_size $((total / 1024))), $(fmt_speed "$speed_kb"))"
			else
				info "${label}: $(fmt_size $((size / 1024))) ($(fmt_speed "$speed_kb"))"
			fi
			last_size=$size
			# the sampled probe speed can be optimistic, so drop this mirror when the real speed lags far behind
			if [ "$switches" -lt 2 ] && [ "$idx" -lt "$url_total" ] && [ "$ticks" -ge 10 ]; then
				avg_kb=$((size / 1024 / (ticks * 2)))
				if [ "$PROBE_BEST_KB" -gt 0 ] && [ "$avg_kb" -lt 64 ] && [ $((avg_kb * 4)) -lt "$PROBE_BEST_KB" ]; then
					info "${label}: slow mirror, switching to the next one"
					kill "$CURL_PID" 2>/dev/null
					switches=$((switches + 1))
					slow=1
					break
				fi
			fi
		done
		wait "$CURL_PID"
		rc=$?
		CURL_PID=""
		rm -f "$header"
		if [ "$rc" -ne 0 ] || [ ! -s "$dest" ]; then
			if [ "$slow" = "1" ]; then
				warn "this mirror is too slow, trying the next one"
			else
				warn "download failed (curl exit ${rc})"
			fi
			rm -f "$dest"
			continue
		fi
		if [ -n "$checksums" ] && [ -s "$checksums" ] && command -v sha256sum >/dev/null 2>&1; then
			expected=$(awk -v f="./${filename}" '$2 == f { print $1; exit }' "$checksums" 2>/dev/null)
			if [ -n "$expected" ]; then
				actual=$(sha256sum "$dest" | awk '{ print $1 }')
				if [ "$actual" != "$expected" ]; then
					warn "checksum mismatch: ${url}"
					rm -f "$dest"
					continue
				fi
				info "checksum verified: ${filename}"
			fi
		fi
		DOWNLOAD_SOURCE="$url"
		size=$(wc -c < "$dest")
		DOWNLOAD_SIZE_KB=$((size / 1024))
		return 0
	done < "$URLS_FILE"
	rm -f "$dest"
	return 1
}

fetch_checksums() {
	local path="$1" dest="$2"
	info "downloading checksums"
	if fetch_text "$path" "$dest" 20; then
		return 0
	fi
	warn "checksums unavailable, skipping verification"
	rm -f "$dest"
	return 1
}

first_line() {
	head -n 1 "$1" 2>/dev/null | tr -d '\r' | tr -d ' '
}

get_plugin_version() {
	local f="${TMP_DIR}/version" ver
	fetch_text "package/${BRANCH}/version" "$f" 20 || return 1
	ver=$(first_line "$f")
	ver=${ver#v}
	case "$ver" in
		''|*[!0-9.]*) return 1 ;;
	esac
	printf '%s\n' "$ver"
}

get_core_version() {
	local f="${TMP_DIR}/core_version" ver
	fetch_text "core/${BRANCH}/core_version" "$f" 20 || return 1
	if [ "$CORE_KIND" = "smart" ]; then
		ver=$(sed -n '2p' "$f" 2>/dev/null | tr -d '\r' | tr -d ' ')
	else
		ver=$(first_line "$f")
	fi
	[ -n "$ver" ] || return 1
	printf '%s\n' "$ver"
}

installed_plugin_version() {
	if [ "$PKG_TYPE" = "apk" ]; then
		apk list luci-app-openclash 2>/dev/null | grep '\[installed\]' | grep -oE '[0-9]+(\.[0-9]+)+' | head -n 1
	else
		rm -f /var/lock/opkg.lock 2>/dev/null
		opkg status luci-app-openclash 2>/dev/null | grep 'Version' | awk -F 'Version: ' '{ print $2 }' | head -n 1 | sed 's/-r[0-9]*$//'
	fi
}

version_gt() {
	local left="$1" right="$2"
	if echo "1.0.0" | sort -V >/dev/null 2>&1; then
		[ "$(printf '%s\n%s\n' "$left" "$right" | sort -V | tail -n 1)" = "$left" ] && [ "$left" != "$right" ]
		return $?
	fi
	local lnum rnum
	lnum=$(printf '%s' "$left" | awk -F '.' '{ print $2$3 }')
	rnum=$(printf '%s' "$right" | awk -F '.' '{ print $2$3 }')
	[ -n "$lnum" ] && [ -n "$rnum" ] && [ "$lnum" -gt "$rnum" ] 2>/dev/null
}

installed_core_version() {
	[ -x "$1" ] || return 1
	"$1" -v 2>/dev/null | head -n 1 | awk '{ print $3 }'
}

detect_core_arch() {
	local arch=""
	[ -f /etc/openwrt_release ] && . /etc/openwrt_release
	case "${DISTRIB_ARCH:-}" in
		aarch64_*) arch="linux-arm64" ;;
		armeb_*) arch="" ;;
		arm_cortex-a5|arm_cortex-a5[!0-9]*|arm_cortex-a7|arm_cortex-a7[!0-9]*|arm_cortex-a8*|arm_cortex-a9*|arm_cortex-a12*|arm_cortex-a15*|arm_cortex-a17*) arch="linux-armv7" ;;
		arm_arm1176jzf-s*|arm_arm1136*|arm_mpcore*) arch="linux-armv6" ;;
		arm*) arch="linux-armv5" ;;
		i386_*) arch="linux-386" ;;
		mips64el_*) arch="linux-mips64le" ;;
		mips64_*) arch="linux-mips64" ;;
		mips_*) arch="linux-mips-softfloat" ;;
		mipsel_*) arch="linux-mipsle-softfloat" ;;
		riscv64*) arch="linux-riscv64" ;;
		loongarch64*|loongarch_*) arch="linux-loong64-abi2" ;;
		x86_64) arch="linux-amd64-v1" ;;
	esac
	printf '%s\n' "$arch"
}

resolve_core_arch() {
	local arch="$ARCH_OVERRIDE" uci_arch=""
	if [ -z "$arch" ] && command -v uci >/dev/null 2>&1; then
		uci_arch=$(uci -q get openclash.config.core_version 2>/dev/null)
		case "$uci_arch" in
			''|0|*[!a-zA-Z0-9._-]*) uci_arch="" ;;
		esac
		arch="$uci_arch"
	fi
	[ -n "$arch" ] || arch=$(detect_core_arch)
	[ -n "$arch" ] || die "unable to detect the core architecture, please specify it with --arch"
	printf '%s\n' "$arch"
}

resolve_core_path() {
	local small=""
	if command -v uci >/dev/null 2>&1; then
		small=$(uci -q get openclash.config.small_flash_memory 2>/dev/null)
	fi
	if [ "$small" = "1" ]; then
		printf '%s\n' "/tmp/etc/openclash/core/clash_meta"
	else
		printf '%s\n' "/etc/openclash/core/clash_meta"
	fi
}

service_running() {
	if command -v ubus >/dev/null 2>&1 && command -v jsonfilter >/dev/null 2>&1; then
		ubus call service list '{"name":"openclash"}' 2>/dev/null | jsonfilter -e '@.openclash.instances.*.running' 2>/dev/null | grep -q 'true'
		return $?
	fi
	pgrep -f 'openclash/core/clash_meta' >/dev/null 2>&1
}

stop_service() {
	[ -x /etc/init.d/openclash ] || return 0
	service_running || return 0
	SERVICE_WAS_RUNNING=1
	info "stopping OpenClash"
	/etc/init.d/openclash stop >/dev/null 2>&1
	local i=1
	while [ "$i" -le 30 ]; do
		service_running || return 0
		if [ $((i % 5)) -eq 0 ]; then
			info "waiting for OpenClash to stop (${i}s)"
		fi
		sleep 1
		i=$((i + 1))
	done
	warn "OpenClash did not stop within 30 seconds"
}

restart_service() {
	[ -x /etc/init.d/openclash ] || return 0
	local enable=""
	if command -v uci >/dev/null 2>&1; then
		enable=$(uci -q get openclash.config.enable 2>/dev/null)
	fi
	if [ "$SERVICE_WAS_RUNNING" = "1" ] || [ "$enable" = "1" ] || service_running; then
		info "restarting OpenClash"
		/etc/init.d/openclash restart >/dev/null 2>&1
		info "OpenClash restarted"
	fi
}

apply_settings() {
	[ -f /etc/config/openclash ] || return 0
	command -v uci >/dev/null 2>&1 || return 0
	uci -q set openclash.config.release_branch="$BRANCH"
	if [ "$CORE_KIND" = "smart" ]; then
		uci -q set openclash.config.smart_enable="1"
	elif [ "$CORE_KIND" = "meta" ]; then
		uci -q set openclash.config.smart_enable="0"
	fi
	if [ -n "$CORE_ARCH_RESOLVED" ]; then
		uci -q set openclash.config.core_version="$CORE_ARCH_RESOLVED"
	fi
	uci -q commit openclash 2>/dev/null
}

clear_luci_cache() {
	rm -rf /tmp/luci-modulecache /var/luci-modulecache 2>/dev/null
	rm -rf /tmp/luci-indexcache /tmp/luci-indexcache.* 2>/dev/null
	rm -rf /var/luci-indexcache /var/luci-indexcache.* 2>/dev/null
}

pre_test_plugin() {
	local file="$1" out rc
	if [ "$PKG_TYPE" = "apk" ]; then
		if [ "$FORCE" = "1" ]; then
			out=$(apk add -s -q --force-overwrite --clean-protected --allow-untrusted --force-reinstall "$file" 2>&1)
		else
			out=$(apk add -s -q --force-overwrite --clean-protected --allow-untrusted "$file" 2>&1)
		fi
		rc=$?
	else
		rm -f /var/lock/opkg.lock 2>/dev/null
		if [ "$FORCE" = "1" ]; then
			out=$(opkg --force-downgrade --force-reinstall install "$file" --noaction 2>&1)
		else
			out=$(opkg --force-downgrade install "$file" --noaction 2>&1)
		fi
		rc=$?
		printf '%s' "$out" | grep -qE '(Installing|Upgrading|Downgrading|Reinstalling) luci-app-openclash( \([^)]*\))? (to|on) root' || rc=1
	fi
	if [ "$rc" -eq 0 ]; then
		return 0
	fi
	warn "pre update test failed: $(printf '%s' "$out" | tr '\n' ' ' | head -c 300)"
	return 1
}

install_plugin() {
	local ver="$1" file path log rc installed attempt=1 install_kb
	if [ "$PKG_TYPE" = "apk" ]; then
		file="${TMP_DIR}/luci-app-openclash-${ver}.apk"
		path="package/${BRANCH}/luci-app-openclash-${ver}.apk"
	else
		file="${TMP_DIR}/luci-app-openclash_${ver}_all.ipk"
		path="package/${BRANCH}/luci-app-openclash_${ver}_all.ipk"
	fi

	info "downloading OpenClash v${ver}"
	if ! download_path "$path" "$file" "OpenClash v${ver}" 900 "$CHECKSUMS_PLUGIN" "${file##*/}"; then
		error "failed to download OpenClash v${ver}"
		return 1
	fi
	info "checking the package"
	if [ "$PKG_TYPE" = "opkg" ] && ! gzip -t "$file" 2>/dev/null; then
		error "downloaded package is corrupted"
		return 1
	fi
	info "downloaded OpenClash v${ver} ($(fmt_size "$DOWNLOAD_SIZE_KB"))"
	[ "$PKG_TYPE" = "opkg" ] && info "reading the package size"
	install_kb=$(package_install_kb "$file")
	PLUGIN_KB=$install_kb
	info "plugin takes about $(fmt_size "$install_kb") on disk"
	require_space "/" "$((install_kb + 8192))" "plugin installation" || return 1

	stop_service
	log="${TMP_DIR}/install.log"
	while [ "$attempt" -le 3 ]; do
		if pre_test_plugin "$file"; then
			info "installing OpenClash v${ver} (${attempt}/3)"
			if [ "$PKG_TYPE" = "apk" ]; then
				if [ "$FORCE" = "1" ]; then
					apk add -q --force-overwrite --clean-protected --allow-untrusted --force-reinstall "$file" >"$log" 2>&1
				else
					apk add -q --force-overwrite --clean-protected --allow-untrusted "$file" >"$log" 2>&1
				fi
			else
				rm -f /var/lock/opkg.lock 2>/dev/null
				if [ "$FORCE" = "1" ]; then
					opkg --force-downgrade --force-reinstall install "$file" >"$log" 2>&1
				else
					opkg --force-downgrade install "$file" >"$log" 2>&1
				fi
			fi
			rc=$?
			installed=$(installed_plugin_version)
			if [ "$installed" = "$ver" ]; then
				info "OpenClash v${ver} installed"
				rm -f "$file"
				return 0
			fi
			warn "install failed (exit ${rc})"
			[ -s "$log" ] && sed -n '1,20p' "$log" >&2
		fi
		attempt=$((attempt + 1))
		[ "$attempt" -le 3 ] && sleep 2
	done

	error "OpenClash installation failed"
	if [ "$PKG_TYPE" = "apk" ]; then
		cp -f "$file" /tmp/openclash.apk 2>/dev/null
		error "package kept at /tmp/openclash.apk"
		error "manual install: apk add --force-overwrite --clean-protected --allow-untrusted /tmp/openclash.apk"
	else
		cp -f "$file" /tmp/openclash.ipk 2>/dev/null
		error "package kept at /tmp/openclash.ipk"
		error "manual install: opkg --force-downgrade install /tmp/openclash.ipk"
	fi
	return 1
}

install_core() {
	local target="$1" ver="$2" arch="$3"
	local file="${TMP_DIR}/clash_core.tar.gz" dir="${TMP_DIR}/core"
	local path="core/${BRANCH}/${CORE_KIND}/clash-${arch}.tar.gz" bin tar_kb bin_kb

	info "downloading ${CORE_KIND} core ${ver} (${arch})"
	if ! download_path "$path" "$file" "${CORE_KIND} core ${ver}" 1800 "$CHECKSUMS_CORE" "clash-${arch}.tar.gz"; then
		error "failed to download the ${CORE_KIND} core"
		return 1
	fi
	info "checking the archive"
	if ! gzip -t "$file" 2>/dev/null; then
		error "downloaded core archive is corrupted"
		return 1
	fi
	info "downloaded ${CORE_KIND} core ${ver} ($(fmt_size "$DOWNLOAD_SIZE_KB"))"
	info "extracting the core"
	tar_kb=$((DOWNLOAD_SIZE_KB))
	require_space "/tmp" "$((tar_kb * 2 + 4096))" "core extraction" || return 1

	rm -rf "$dir"
	mkdir -p "$dir" || return 1
	if ! tar -xzf "$file" -C "$dir" 2>/dev/null; then
		error "failed to extract the core archive"
		return 1
	fi
	bin="${dir}/clash"
	if [ ! -f "$bin" ]; then
		error "core archive does not contain the clash binary"
		return 1
	fi
	rm -f "$file"
	chmod 4755 "$bin" 2>/dev/null
	if ! "$bin" -v >/dev/null 2>&1; then
		error "core self-test failed, the binary does not run on this device"
		return 1
	fi
	mkdir -p "${target%/*}" || return 1
	bin_kb=$(( $(wc -c < "$bin") / 1024 ))
	CORE_KB=$bin_kb
	require_space "${target%/*}" "$((bin_kb + 4096))" "core installation" || return 1
	if ! mv -f "$bin" "$target"; then
		error "failed to install the core to ${target}"
		return 1
	fi
	chmod 4755 "$target" 2>/dev/null
	info "${CORE_KIND} core installed: $("$target" -v 2>/dev/null | head -n 1)"
}

init_settings() {
	if [ -f /etc/config/openclash ] && command -v uci >/dev/null 2>&1; then
		if [ -z "$BRANCH" ]; then
			BRANCH=$(uci -q get openclash.config.release_branch 2>/dev/null)
		fi
		if [ -z "$CORE_KIND" ]; then
			if [ -n "$(uci -q get openclash.config.oix_token 2>/dev/null)" ]; then
				CORE_KIND="none"
				info "Oix mode detected, skipping the core installation (use -c meta|smart to override)"
			elif [ "$(uci -q get openclash.config.smart_enable 2>/dev/null)" = "1" ]; then
				CORE_KIND="smart"
			else
				CORE_KIND="meta"
			fi
		fi
	fi
	[ -n "$BRANCH" ] || BRANCH="dev"
	[ -n "$CORE_KIND" ] || CORE_KIND="meta"
	case "$BRANCH" in
		master|dev) ;;
		*) die "unsupported branch: ${BRANCH} (use master or dev)" ;;
	esac
	case "$CORE_KIND" in
		meta|smart|none) ;;
		*) die "unsupported core: ${CORE_KIND} (use meta, smart or none)" ;;
	esac
	if [ -n "$ARCH_OVERRIDE" ]; then
		case "$ARCH_OVERRIDE" in
			*[!a-zA-Z0-9._-]*) die "invalid arch: ${ARCH_OVERRIDE}" ;;
		esac
	fi
}

main() {
	printf '\n %s╭─%s %sOpenClash Installer for OpenWrt%s\n' "$C_TREE" "$C_RESET" "$C_STAGE" "$C_RESET"
	printf ' %s│%s  %splugin%s  luci-app-openclash (opkg / apk)\n' "$C_TREE" "$C_RESET" "$C_INFO" "$C_RESET"
	printf ' %s│%s  %score%s    mihomo meta or smart\n' "$C_TREE" "$C_RESET" "$C_INFO" "$C_RESET"
	printf ' %s╰─%s %susage%s   sh install.sh [-b master|dev] [-c meta|smart|none] [-a arch] [-f] [-h]\n' "$C_TREE" "$C_RESET" "$C_INFO" "$C_RESET"

	[ "$(id -u)" = "0" ] || die "this script must be run as root"
	[ -f /etc/openwrt_release ] || warn "this script is designed for OpenWrt"

	if command -v apk >/dev/null 2>&1; then
		PKG_TYPE="apk"
	elif command -v opkg >/dev/null 2>&1; then
		PKG_TYPE="opkg"
	else
		die "neither apk nor opkg was found"
	fi
	if command -v fw4 >/dev/null 2>&1; then
		FIREWALL="nftables"
	else
		FIREWALL="iptables"
	fi
	if [ "$FIREWALL" = "nftables" ]; then
		FIREWALL_DEPS="kmod-nft-tproxy"
	else
		FIREWALL_DEPS="ipset iptables iptables-mod-tproxy iptables-mod-extra kmod-ipt-nat"
	fi
	init_settings
	mkdir -p "$TMP_DIR" || die "failed to create ${TMP_DIR}"
	trap 'ensure_install_dns; restore_install_dns; rm -rf "$TMP_DIR"; pause_exit' 0
	trap 'restore_install_dns; rm -rf "$TMP_DIR"; [ -n "${CURL_PID:-}" ] && kill "$CURL_PID" 2>/dev/null; exit 1' 1 2 15

	if ! command -v curl >/dev/null 2>&1 || [ ! -s /etc/ssl/certs/ca-certificates.crt ]; then
		section "preparing curl and ca-bundle"
		warn "curl or ca-bundle is missing"
		ensure_install_dns
		info "updating package index"
		if ! pkg_update; then
			error "failed to update the package index"
			error "install curl and ca-bundle manually, then rerun this script"
			exit 1
		fi
		if ! pkg_install curl ca-bundle; then
			error "failed to install curl or ca-bundle"
			error "install curl and ca-bundle manually, then rerun this script"
			exit 1
		fi
		command -v curl >/dev/null 2>&1 || die "curl is still missing after installation"
		[ -s /etc/ssl/certs/ca-certificates.crt ] || warn "ca-bundle may be missing, HTTPS downloads can fail"
	fi

	ensure_install_dns
	section "checking the system"
	info "branch: ${BRANCH}, core: ${CORE_KIND}, package manager: ${PKG_TYPE}, firewall: ${FIREWALL}"

	local latest_plugin installed_plugin need_plugin=0 need_deps=0
	local core_latest="" core_arch="" core_path="" core_installed="" need_core=0

	info "checking the latest plugin version"
	latest_plugin=$(get_plugin_version) || die "failed to get the latest plugin version"
	installed_plugin=$(installed_plugin_version)
	info "plugin: installed ${installed_plugin:-none}, latest ${latest_plugin}"
	if [ "$FORCE" = "1" ] || [ -z "$installed_plugin" ]; then
		need_plugin=1
	elif version_gt "$latest_plugin" "$installed_plugin"; then
		need_plugin=1
	elif [ "$installed_plugin" != "$latest_plugin" ]; then
		info "installed plugin is newer than the ${BRANCH} build, use --force to reinstall"
	fi

	if [ "$CORE_KIND" != "none" ]; then
		info "checking the latest ${CORE_KIND} core version"
		core_latest=$(get_core_version) || die "failed to get the latest ${CORE_KIND} core version"
		core_arch=$(resolve_core_arch) || exit 1
		CORE_ARCH_RESOLVED="$core_arch"
		core_path=$(resolve_core_path)
		core_installed=$(installed_core_version "$core_path")
		info "${CORE_KIND} core: installed ${core_installed:-none}, latest ${core_latest} (${core_arch})"
		if [ "$FORCE" = "1" ] || [ "$core_installed" != "$core_latest" ]; then
			need_core=1
		fi
	fi

	deps_ready || need_deps=1
	if [ "$need_plugin" = "0" ]; then
		info "plugin is up to date"
	fi
	if [ "$CORE_KIND" != "none" ] && [ "$need_core" = "0" ]; then
		info "${CORE_KIND} core is up to date"
	fi
	if [ "$need_deps" = "1" ]; then
		info "runtime dependencies are missing"
	fi
	if [ "$need_plugin" = "0" ] && { [ "$CORE_KIND" = "none" ] || [ "$need_core" = "0" ]; } && [ "$need_deps" = "0" ]; then
		if [ -f /etc/config/openclash ]; then
			apply_settings
		fi
		done_text "everything is up to date"
		return 0
	fi

	STAGE_TOTAL=1
	if [ "$need_plugin" = "1" ] || [ "$need_deps" = "1" ]; then
		STAGE_TOTAL=$((STAGE_TOTAL + 1))
	fi
	if [ "$need_plugin" = "1" ]; then
		STAGE_TOTAL=$((STAGE_TOTAL + 1))
	fi
	if [ "$need_core" = "1" ]; then
		STAGE_TOTAL=$((STAGE_TOTAL + 1))
	fi

	if [ "$need_plugin" = "1" ] || [ "$need_deps" = "1" ]; then
		stage "install the dependencies"
		ensure_install_dns
		if [ "$PKG_INDEX_UPDATED" != "1" ]; then
			info "updating package index"
			if ! pkg_update; then
				error "failed to update the package index"
				exit 1
			fi
		fi
		if ! ensure_dnsmasq_full; then
			error "failed to install dnsmasq-full"
			restart_service
			exit 1
		fi
		ensure_install_dns
		if ! install_extra_deps; then
			error "failed to install the required dependencies"
			restart_service
			exit 1
		fi
		info "dependencies are ready"
	fi

	if [ "$need_plugin" = "1" ]; then
		stage "install OpenClash ${latest_plugin}"
		fetch_checksums "package/${BRANCH}/checksums.txt" "$CHECKSUMS_PLUGIN" || true
		if ! install_plugin "$latest_plugin"; then
			restart_service
			exit 1
		fi
	fi

	if [ "$need_core" = "1" ]; then
		stage "install the ${CORE_KIND} core"
		core_path=$(resolve_core_path)
		core_arch=$(resolve_core_arch) || exit 1
		fetch_checksums "core/${BRANCH}/${CORE_KIND}/checksums.txt" "$CHECKSUMS_CORE" || true
		local core_attempt=1
		while [ "$core_attempt" -le 3 ]; do
			install_core "$core_path" "$core_latest" "$core_arch" && break
			warn "core installation failed, retrying (${core_attempt}/3)"
			core_attempt=$((core_attempt + 1))
			[ "$core_attempt" -le 3 ] && sleep 2
		done
		if [ "$core_attempt" -gt 3 ]; then
			error "core installation failed, check free space or enable Small Flash Memory, then retry"
			restart_service
			exit 1
		fi
	fi

	stage "finish"
	if [ -f /etc/config/openclash ]; then
		apply_settings
	fi
	clear_luci_cache
	restart_service
	if [ "$PLUGIN_KB" -gt 0 ]; then
		info "plugin size: $(fmt_size "$PLUGIN_KB")"
	fi
	if [ "$CORE_KB" -gt 0 ]; then
		info "core size: $(fmt_size "$CORE_KB")"
	fi
	if [ "$PLUGIN_KB" -gt 0 ] && [ "$CORE_KB" -gt 0 ]; then
		info "OpenClash size: $(fmt_size $((PLUGIN_KB + CORE_KB)))"
	fi
	info "usage notes:"
	info " - enable OpenClash in LuCI > Services > OpenClash before the first run"
	info " - the first start will downloads GeoIP/GeoSite/rule data, allow space in /etc/openclash"
	info " - TUN mode needs kmod-tun (already installed) and a service restart to take effect"
	info " - re-login to LuCI if the menu still shows the previous version"
	done_text "OpenClash ${latest_plugin} is ready"
}

while [ $# -gt 0 ]; do
	case "$1" in
		-b|--branch)
			[ $# -ge 2 ] || die "$1 requires a value"
			BRANCH="$2"
			shift 2
			;;
		-c|--core)
			[ $# -ge 2 ] || die "$1 requires a value"
			CORE_KIND="$2"
			shift 2
			;;
		-a|--arch)
			[ $# -ge 2 ] || die "$1 requires a value"
			ARCH_OVERRIDE="$2"
			shift 2
			;;
		-f|--force)
			FORCE=1
			shift
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			usage
			die "unknown option: $1"
			;;
	esac
done

main
