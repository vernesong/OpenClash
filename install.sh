#!/bin/sh

set -u

REPO_OWNER="vernesong"
REPO_NAME="OpenClash"
REPO_RAW="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}"
REPO_CDN_PATH="gh/${REPO_OWNER}/${REPO_NAME}"
CDN_LIST_PATH="dev/luci-app-openclash/root/usr/share/openclash/res/cdn.list"

JSDELIVR_MIRRORS="https://cdn.jsdelivr.net https://fastly.jsdelivr.net https://testingcf.jsdelivr.net"
FALLBACK_MIRRORS="https://github.chenc.dev/ https://xsadwsd.kdns.fr/ https://cdn.akaere.online/ https://githubproxy.gohj99.site/ https://gh-proxy.com/ https://gh.acmsz.top/ https://git.yylx.win/ https://gh.b52m.cn/ https://ghm.078465.xyz/ https://gh.sixyin.com/ https://ghproxy.felicity.land/ https://cfgh.ikgy.top/ https://github.tbap.top/ https://gh.jjj.gv.uy/"

BRANCH=""
CORE_KIND=""
ARCH_OVERRIDE=""
FORCE=0
MIRRORS=""
PKG_TYPE=""
FIREWALL=""
SERVICE_WAS_RUNNING=0
CORE_ARCH_RESOLVED=""
DOWNLOAD_SOURCE=""
DOWNLOAD_SIZE_KB=0
CURL_PID=""
TMP_DIR="/tmp/openclash_install.$$"
URLS_FILE="${TMP_DIR}/urls"
CHECKSUMS_PLUGIN="${TMP_DIR}/checksums_plugin.txt"
CHECKSUMS_CORE="${TMP_DIR}/checksums_core.txt"

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

info() {
	printf '[INFO] %s\n' "$*"
}

warn() {
	printf '[WARN] %s\n' "$*" >&2
}

error() {
	printf '[ERROR] %s\n' "$*" >&2
}

die() {
	error "$*"
	exit 1
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
	) &
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
			err=$(run_with_timeout 60 apk update 2>&1)
			rc=$?
			rm -f /lib/apk/db/lock 2>/dev/null
		else
			err=$(run_with_timeout 60 opkg update 2>&1)
			rc=$?
			rm -f /var/lock/opkg.lock 2>/dev/null
		fi
		[ "$rc" -eq 0 ] && return 0
		i=$((i + 1))
		[ "$i" -le 3 ] && sleep 2
	done
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
		info "free space on ${path}: ${avail} KB (${label} needs ${need_kb} KB)"
		return 0
	fi
	warn "insufficient space on ${path} for ${label}: ${avail} KB available, ${need_kb} KB required"
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
	printf '%s\n' "$((payload_kb + 8192))"
}

ensure_dnsmasq_full() {
	pkg_is_installed dnsmasq-full && return 0
	if pkg_is_installed dnsmasq; then
		warn "OpenClash requires dnsmasq-full, replacing dnsmasq..."
		if [ "$PKG_TYPE" = "apk" ]; then
			apk del dnsmasq >/dev/null 2>&1
		else
			opkg remove --force-depends dnsmasq >/dev/null 2>&1
		fi
	fi
	if pkg_install dnsmasq-full; then
		info "installed dnsmasq-full"
	else
		warn "failed to install dnsmasq-full, DNS hijack may not work"
	fi
}

install_extra_deps() {
	local pkgs="luci-compat kmod-inet-diag ruby-psych ruby-pstore"
	local pkg
	if [ "$FIREWALL" = "nftables" ]; then
		pkgs="${pkgs} kmod-nft-tproxy"
	else
		pkgs="${pkgs} ipset iptables iptables-mod-tproxy iptables-mod-extra kmod-ipt-nat"
	fi
	for pkg in $pkgs; do
		pkg_is_installed "$pkg" && continue
		if pkg_install "$pkg"; then
			info "installed dependency: ${pkg}"
		else
			warn "failed to install dependency: ${pkg}"
		fi
	done
}

load_mirrors() {
	local tmp="${TMP_DIR}/cdn.list" url list=""
	mkdir -p "$TMP_DIR"
	for url in \
		"${REPO_RAW}/${CDN_LIST_PATH}" \
		"https://cdn.jsdelivr.net/${REPO_CDN_PATH}@dev/luci-app-openclash/root/usr/share/openclash/res/cdn.list"
	do
		rm -f "$tmp"
		if curl -fsSL --connect-timeout 5 -m 15 -o "$tmp" "$url" 2>/dev/null && [ -s "$tmp" ]; then
			break
		fi
	done
	if [ -s "$tmp" ]; then
		list=$(grep -E '^https?://' "$tmp" 2>/dev/null | tr -d '\r' | tr '\n' ' ')
	fi
	rm -f "$tmp"
	[ -n "$list" ] || list="$FALLBACK_MIRRORS"
	MIRRORS="$list"
}

build_urls() {
	local path="$1" m
	{
		printf '%s\n' "${REPO_RAW}/${path}"
		for m in $JSDELIVR_MIRRORS; do
			printf '%s\n' "${m}/${REPO_CDN_PATH}@${path}"
		done
		for m in $MIRRORS; do
			case "$m" in
				*/) printf '%s\n' "${m}${REPO_RAW}/${path}" ;;
				*) printf '%s\n' "${m}/${REPO_RAW}/${path}" ;;
			esac
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
	done < "$URLS_FILE"
	rm -f "$dest"
	return 1
}

download_path() {
	local path="$1" dest="$2" label="$3" max_time="$4" checksums="$5" filename="$6"
	local url rc expected actual size header total pct speed_kb last_size
	build_urls "$path"
	while IFS= read -r url; do
		[ -n "$url" ] || continue
		info "downloading ${label}: ${url}"
		rm -f "$dest"
		header="${dest}.headers"
		rm -f "$header"
		last_size=0
		curl -fL -sS --connect-timeout 10 -m "$max_time" --speed-time 30 --speed-limit 1024 --retry 1 --retry-delay 2 -D "$header" -o "$dest" "$url" &
		CURL_PID=$!
		while kill -0 "$CURL_PID" 2>/dev/null; do
			sleep 2
			size=0
			[ -f "$dest" ] && size=$(wc -c < "$dest" 2>/dev/null)
			case "$size" in ''|*[!0-9]*) size=0 ;; esac
			total=0
			[ -f "$header" ] && total=$(tr -d '\r' < "$header" 2>/dev/null | awk 'tolower($1) == "content-length:" { v = $2 } END { print v }')
			case "$total" in ''|*[!0-9]*) total=0 ;; esac
			if [ "$size" -gt 0 ]; then
				speed_kb=$(((size - last_size) / 2048))
				[ "$speed_kb" -lt 0 ] && speed_kb=0
				if [ "$total" -gt 0 ]; then
					pct=$((size * 100 / total))
					[ "$pct" -gt 100 ] && pct=100
					info "${label}: ${pct}% ($((size / 1024))/$((total / 1024)) KB, ${speed_kb} KB/s)"
				else
					info "${label}: $((size / 1024)) KB (${speed_kb} KB/s)"
				fi
				last_size=$size
			fi
		done
		wait "$CURL_PID"
		rc=$?
		CURL_PID=""
		rm -f "$header"
		if [ "$rc" -ne 0 ] || [ ! -s "$dest" ]; then
			warn "download failed (curl exit ${rc})"
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
	info "stopping OpenClash..."
	/etc/init.d/openclash stop >/dev/null 2>&1
	local i=1
	while [ "$i" -le 30 ]; do
		service_running || return 0
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
		info "restarting OpenClash..."
		/etc/init.d/openclash restart >/dev/null 2>&1
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
		out=$(apk add -s -q --force-overwrite --clean-protected --allow-untrusted "$file" 2>&1)
		rc=$?
	else
		rm -f /var/lock/opkg.lock 2>/dev/null
		out=$(opkg --force-downgrade install "$file" --noaction 2>&1)
		rc=$?
		printf '%s' "$out" | grep -qE '(Upgrading|Downgrading) luci-app-openclash on root' || rc=1
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

	info "downloading OpenClash v${ver}..."
	if ! download_path "$path" "$file" "OpenClash v${ver}" 900 "$CHECKSUMS_PLUGIN" "${file##*/}"; then
		error "failed to download OpenClash v${ver}"
		return 1
	fi
	if [ "$PKG_TYPE" = "opkg" ] && ! gzip -t "$file" 2>/dev/null; then
		error "downloaded package is corrupted"
		return 1
	fi
	info "downloaded OpenClash v${ver} from ${DOWNLOAD_SOURCE} (${DOWNLOAD_SIZE_KB} KB)"
	install_kb=$(package_install_kb "$file")
	info "estimated installed size: ${install_kb} KB"
	require_space "/" "$install_kb" "plugin installation" || return 1

	stop_service
	log="${TMP_DIR}/install.log"
	while [ "$attempt" -le 3 ]; do
		if pre_test_plugin "$file"; then
			if [ "$PKG_TYPE" = "apk" ]; then
				apk add -q --force-overwrite --clean-protected --allow-untrusted "$file" >"$log" 2>&1
			else
				rm -f /var/lock/opkg.lock 2>/dev/null
				opkg --force-downgrade install "$file" >"$log" 2>&1
			fi
			rc=$?
			installed=$(installed_plugin_version)
			if [ "$installed" = "$ver" ]; then
				info "OpenClash v${ver} installed"
				rm -f "$file"
				return 0
			fi
			warn "installation attempt ${attempt}/3 failed (exit ${rc})"
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

	info "downloading ${CORE_KIND} core ${ver} (${arch})..."
	if ! download_path "$path" "$file" "${CORE_KIND} core ${ver}" 1800 "$CHECKSUMS_CORE" "clash-${arch}.tar.gz"; then
		error "failed to download the ${CORE_KIND} core"
		return 1
	fi
	if ! gzip -t "$file" 2>/dev/null; then
		error "downloaded core archive is corrupted"
		return 1
	fi
	info "downloaded ${CORE_KIND} core ${ver} from ${DOWNLOAD_SOURCE} (${DOWNLOAD_SIZE_KB} KB)"
	tar_kb=$((DOWNLOAD_SIZE_KB))
	require_space "/tmp" "$((tar_kb + 4096))" "core extraction" || return 1

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
	command -v curl >/dev/null 2>&1 || die "curl is required, install it with '${PKG_TYPE} update && ${PKG_TYPE} install curl ca-bundle'"
	[ -s /etc/ssl/certs/ca-certificates.crt ] || warn "ca-bundle may be missing, HTTPS downloads can fail"

	init_settings
	mkdir -p "$TMP_DIR" || die "failed to create ${TMP_DIR}"
	trap 'rm -rf "$TMP_DIR"' 0
	trap 'rm -rf "$TMP_DIR"; [ -n "${CURL_PID:-}" ] && kill "$CURL_PID" 2>/dev/null; exit 1' 1 2 15

	load_mirrors
	info "branch: ${BRANCH}, core: ${CORE_KIND}, package manager: ${PKG_TYPE}, firewall: ${FIREWALL}"

	local latest_plugin installed_plugin need_plugin=0
	local core_latest="" core_arch="" core_path="" core_installed="" need_core=0

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

	if [ "$need_plugin" = "0" ]; then
		info "OpenClash is already up to date"
	fi
	if [ "$CORE_KIND" != "none" ] && [ "$need_core" = "0" ]; then
		info "${CORE_KIND} core is already up to date"
	fi
	if [ "$need_plugin" = "0" ] && { [ "$CORE_KIND" = "none" ] || [ "$need_core" = "0" ]; }; then
		if [ -f /etc/config/openclash ]; then
			apply_settings
		fi
		return 0
	fi

	if [ "$need_plugin" = "1" ]; then
		info "updating package index..."
		pkg_update
		ensure_dnsmasq_full
		install_extra_deps
		fetch_checksums "package/${BRANCH}/checksums.txt" "$CHECKSUMS_PLUGIN" || true
		if ! install_plugin "$latest_plugin"; then
			restart_service
			exit 1
		fi
	fi

	if [ -f /etc/config/openclash ]; then
		apply_settings
	fi
	clear_luci_cache

	if [ "$need_core" = "1" ]; then
		core_path=$(resolve_core_path)
		core_arch=$(resolve_core_arch) || exit 1
		fetch_checksums "core/${BRANCH}/${CORE_KIND}/checksums.txt" "$CHECKSUMS_CORE" || true
		if ! install_core "$core_path" "$core_latest" "$core_arch"; then
			error "core installation failed, check free space or enable Small Flash Memory, then retry"
			restart_service
			exit 1
		fi
	fi

	restart_service
	info "done"
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
