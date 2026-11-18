include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-openclash
PKG_VERSION:=0.48.016
PKG_MAINTAINER:=vernesong <https://github.com/vernesong/OpenClash>

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)
PKG_CONFIG_DEPENDS:=CONFIG_LUCI_APP_OPENCLASH_INCLUDE_CORE

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/config
	config PACKAGE_kmod-inet-diag
	default y if PACKAGE_$(PKG_NAME)

	config PACKAGE_luci-compat
	default y if PACKAGE_$(PKG_NAME)

	config PACKAGE_kmod-nft-tproxy
	default y if PACKAGE_firewall4

	config PACKAGE_kmod-ipt-nat
	default y if ! PACKAGE_firewall4

	config PACKAGE_iptables-mod-tproxy
	default y if ! PACKAGE_firewall4

	config PACKAGE_iptables-mod-extra
	default y if ! PACKAGE_firewall4

	config PACKAGE_dnsmasq_full_ipset
	default y if ! PACKAGE_firewall4

	config PACKAGE_dnsmasq_full_nftset
	default y if PACKAGE_firewall4

	config PACKAGE_ipset
	default y if ! PACKAGE_firewall4

	config LUCI_APP_OPENCLASH_INCLUDE_CORE
	bool "Include Meta core in package"
	depends on PACKAGE_$(PKG_NAME)
	default n
	help
	  Download the Meta (mihomo) core for the target architecture
	  at build time and install it as /etc/openclash/core/clash_meta,
	  so it is available right after flashing. Requires network
	  access during build. The package becomes architecture-specific.
endef

define Package/$(PKG_NAME)
	CATEGORY:=LuCI
	SUBMENU:=3. Applications
	TITLE:=LuCI support for clash
	PKGARCH:=$(if $(CONFIG_LUCI_APP_OPENCLASH_INCLUDE_CORE),$(ARCH_PACKAGES),all)
	DEPENDS:=+dnsmasq-full +curl +ca-bundle +ip-full \
	+ruby +ruby-yaml +kmod-tun +unzip
	MAINTAINER:=vernesong
endef

define Package/$(PKG_NAME)/description
	A LuCI support for clash
endef

define Build/Prepare
	$(CP) $(CURDIR)/root $(PKG_BUILD_DIR)
	$(CP) $(CURDIR)/luasrc $(PKG_BUILD_DIR)
	# Replace the @OPENCLASH_VERSION@ token with the package version (browser asset cache keys).
	sed -i 's|@OPENCLASH_VERSION@|$(PKG_VERSION)|g' $(PKG_BUILD_DIR)/luasrc/openclash.lua $(PKG_BUILD_DIR)/luasrc/view/openclash/*.htm
	$(foreach po,$(wildcard ${CURDIR}/po/zh-cn/*.po), \
		po2lmo $(po) $(PKG_BUILD_DIR)/$(patsubst %.po,%.lmo,$(notdir $(po)));)
	chmod 0755 $(PKG_BUILD_DIR)/root/etc/init.d/openclash
	chmod -R 0755 $(PKG_BUILD_DIR)/root/usr/share/openclash/
	exit 0
endef

define Build/Configure
endef

define Build/Compile
endef

ifeq ($(CONFIG_LUCI_APP_OPENCLASH_INCLUDE_CORE),y)
# Keep in sync with the "Set Core Model" mapping in root/etc/uci-defaults/luci-openclash
define Build/Compile
	case "$(ARCH_PACKAGES)" in \
		aarch64_*) CORE_ARCH="linux-arm64" ;; \
		armeb_*) CORE_ARCH="" ;; \
		arm_cortex-a5|arm_cortex-a5[^0-9]*|arm_cortex-a7|arm_cortex-a7[^0-9]*|arm_cortex-a8*|arm_cortex-a9*|arm_cortex-a12*|arm_cortex-a15*|arm_cortex-a17*) CORE_ARCH="linux-armv7" ;; \
		arm_arm1176jzf-s*|arm_arm1136*|arm_mpcore*) CORE_ARCH="linux-armv6" ;; \
		arm*) CORE_ARCH="linux-armv5" ;; \
		i386_*) CORE_ARCH="linux-386" ;; \
		mips64el_*) CORE_ARCH="linux-mips64le" ;; \
		mips64_*) CORE_ARCH="linux-mips64" ;; \
		mips_*) CORE_ARCH="linux-mips-softfloat" ;; \
		mipsel_*) CORE_ARCH="linux-mipsle-softfloat" ;; \
		riscv64*) CORE_ARCH="linux-riscv64" ;; \
		loongarch64*|loongarch_*) CORE_ARCH="linux-loong64-abi2" ;; \
		x86_64) CORE_ARCH="linux-amd64-v1" ;; \
		*) CORE_ARCH="" ;; \
	esac; \
	if [ -z "$$CORE_ARCH" ]; then \
		echo "ERROR: no Meta core available for $(ARCH_PACKAGES)" >&2; exit 1; \
	fi; \
	mkdir -p $(PKG_BUILD_DIR)/root/etc/openclash/core && \
	curl -fSL --connect-timeout 30 --retry 3 \
		-o $(PKG_BUILD_DIR)/clash_meta.tar.gz \
		"https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-$$CORE_ARCH.tar.gz" && \
	tar -xzf $(PKG_BUILD_DIR)/clash_meta.tar.gz -C $(PKG_BUILD_DIR) clash && \
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/clash $(PKG_BUILD_DIR)/root/etc/openclash/core/clash_meta
	rm -f $(PKG_BUILD_DIR)/clash_meta.tar.gz $(PKG_BUILD_DIR)/clash
endef
endif

define Package/$(PKG_NAME)/conffiles
endef

define OpenClash/backup
	if { [ "$$apk_install" = 1 ] || [ -n "$$2" ] || [ -f /etc/config/openclash ] || [ -d /etc/openclash ] || [ -f /tmp/openclash.bak ]; } && [ ! -f "$$backup_dir/ready" ] && [ ! -f "$$backup_dir/openclash.bak" ]; then
		(
			umask 077
			[ ! -e "$$backup_dir" ] && [ ! -L "$$backup_dir" ] || exit 1
			stage=$$(mktemp -d /tmp/.openclash-backup.XXXXXX) || exit 1
			trap 'rm -rf "$$stage"' EXIT
			trap 'exit 1' HUP INT TERM
			if [ -f /etc/config/openclash ]; then cp -p /etc/config/openclash "$$stage/openclash.bak" || exit 1; fi
			mkdir "$$stage/openclash" || exit 1
			if [ -d /etc/openclash ]; then cp -a /etc/openclash/. "$$stage/openclash/" || exit 1; fi
			if [ -n "$(filter y,$(CONFIG_USE_APK))" ]; then
				openclash_apk_assets backup "$$stage" || exit 1
			else
				if [ -d /usr/share/openclash/ui ]; then cp -a /usr/share/openclash/ui "$$stage/openclash_ui" || exit 1; fi
				if [ -d /www/luci-static/resources/openclash/pac ]; then cp -a /www/luci-static/resources/openclash/pac "$$stage/pac" || exit 1; fi
			fi
			if [ "$$keep_stopped" = 1 ]; then touch "$$stage/keep-stopped" || exit 1; fi
			touch "$$stage/ready" && mv "$$stage" "$$backup_dir"
		) || { echo "OpenClash: backup failed before package replacement" >&2; exit 1; }
	fi
endef

OpenClash/apk_assets = $(if $(filter y,$(CONFIG_USE_APK)),$(file <$(CURDIR)/files/apk-assets.sh))

define Package/$(PKG_NAME)/preinst
#!/bin/sh
$(OpenClash/apk_assets)
	[ -z "$$IPKG_INSTROOT" ] || exit 0
	keep_stopped=0
	apk_install=0
	backup_dir=/tmp/openclash-package-backup
	# openclash-package-preflight-v1
	case "$$1" in
	upgrade) keep_stopped=$${OPENCLASH_KEEP_STOPPED:-0} ;;
	openclash-preflight)
		openclash_apk_assets restore || exit 1
		[ ! -f /tmp/openclash-package-backup/ready ] && [ ! -f /tmp/openclash-package-backup/openclash.bak ] || exit 0
		keep_stopped=1
		backup_dir=$$3
		[ -n "$$backup_dir" ] || exit 1
		;;
	[0-9]*)
		apk_install=1
		openclash_apk_assets restore || exit 1
		if [ -f "$$backup_dir/ready" ] && [ -d "$$backup_dir/apk-mounts" ]; then
			openclash_apk_assets restore-backup "$$backup_dir" retry || exit 1
		fi
		if [ -n "$$2" ] && [ -x /etc/init.d/openclash ] && ! /etc/init.d/openclash running >/dev/null 2>&1; then keep_stopped=1; fi
		# Only the apk process launched in our private working directory can hand over its backup.
		work=$$(readlink "/proc/$$PPID/cwd")
		case "$$work" in
		/tmp/.openclash-apk.??????)
			if [ ! -e /tmp/openclash-package-backup ] && [ ! -L /tmp/openclash-package-backup ] && [ ! -L "$$work" ] &&
				LC_ALL=C ls -nd "$$work" | awk '$$1=="drwx------" && $$3=="0" { valid=1 } END { exit !valid }' && [ -f "$$work/backup/ready" ]; then
				if [ "$$keep_stopped" != 1 ]; then rm -f "$$work/backup/keep-stopped" || exit 1; fi
				mv -T "$$work/backup" /tmp/openclash-package-backup || exit 1
			fi
			;;
		esac
		;;
	esac
	(
		$(OpenClash/backup)
	) || {
		if [ "$$apk_install" = 1 ]; then openclash_apk_assets hold || echo "OpenClash: apk may replace assets that could not be preserved" >&2; fi
		if [ "$$1" = upgrade ] && [ -z "$${OPENCLASH_KEEP_STOPPED:-}" ]; then
			echo "OpenClash: if the service was running before this opkg upgrade, start it with /etc/init.d/openclash start" >&2
		fi
		exit 1
	}
	case "$$1" in
	[0-9]*) if [ -n "$$2" ] && [ -x /etc/init.d/openclash ] && /etc/init.d/openclash running >/dev/null 2>&1; then /etc/init.d/openclash stop || exit 1; fi ;;
	esac
	exit 0
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
$(OpenClash/apk_assets)
	[ "$$IPKG_NO_SCRIPT" != 1 ] || exit 0
	if [ -n "$$IPKG_INSTROOT" ]; then
		sh "$$IPKG_INSTROOT/etc/rc.common" "$$IPKG_INSTROOT/etc/init.d/openclash" enable
		exit $$?
	fi
	# apk also runs its post script when the preceding package script failed.
	case "$$1" in [0-9]*) apk_install=1; openclash_apk_assets restore || exit 1 ;; *) apk_install=0 ;; esac
	if { [ "$$apk_install" = 1 ] || [ -n "$$2" ]; } && [ ! -f /tmp/openclash-package-backup/ready ] && [ ! -f /tmp/openclash-package-backup/openclash.bak ]; then
		echo "OpenClash: package backup is incomplete, deferring configuration and service startup" >&2
		exit 1
	fi
	keep_stopped=0
	[ ! -f /tmp/openclash-package-backup/keep-stopped ] || keep_stopped=1
	defaults=/etc/uci-defaults/luci-openclash
	if [ -f "$$defaults" ]; then
		(cd /etc/uci-defaults && OPENCLASH_PACKAGE_CONFIGURE=1 . "$$defaults") && rm -f "$$defaults" || exit 1
	elif [ -d /tmp/openclash-package-backup ] || [ -f /tmp/openclash.bak ]; then
		echo "OpenClash package restore is pending but its defaults script is missing" >&2
		exit 1
	fi
	rm -f /tmp/luci-indexcache
	if [ "$$PKG_UPGRADE" != 1 ] && [ -z "$$2" ]; then /etc/init.d/openclash enable || exit 1; fi
	[ "$$keep_stopped" = 1 ] || /etc/init.d/openclash start
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
	if [ -n "$$IPKG_INSTROOT" ]; then
		sh "$$IPKG_INSTROOT/etc/rc.common" "$$IPKG_INSTROOT/etc/init.d/openclash" disable
		exit $$?
	fi
	$(if $(filter y,$(CONFIG_USE_APK)),. /usr/share/openclash/apk-assets.sh || exit 1)
	was_running=0
	apk_install=0
	backup_dir=/tmp/openclash-package-backup
	keep_stopped=0
	if [ -x /etc/init.d/openclash ] && /etc/init.d/openclash running >/dev/null 2>&1; then
		/etc/init.d/openclash stop >/dev/null 2>&1 || exit 1
		was_running=1
	elif [ "$$PKG_UPGRADE" = 1 ] || [ "$${OPENCLASH_KEEP_STOPPED:-}" = 1 ]; then
		keep_stopped=$${OPENCLASH_KEEP_STOPPED:-1}
	fi
	[ ! -f /usr/share/openclash/ruby.sh ] || (. /usr/share/openclash/ruby.sh; cleanup_yaml_temps)
	(
		$(OpenClash/backup)
	) || {
		[ "$$was_running" != 1 ] || /etc/init.d/openclash start
		exit 1
	}
	if [ "$$PKG_UPGRADE" != 1 ] && [ -x /etc/init.d/openclash ]; then /etc/init.d/openclash disable || exit 1; fi
	exit 0
endef

define Package/$(PKG_NAME)/postrm
#!/bin/sh
	[ -z "$$IPKG_INSTROOT" ] || exit 0
	DEFAULT_DNSMASQ_CFGID="$$(uci -q show "dhcp.@dnsmasq[0]" | awk 'NR==1 {split($$0, conf, /[.=]/); print conf[2]}' 2>/dev/null)"
	if [ -f "/tmp/etc/dnsmasq.conf.$$DEFAULT_DNSMASQ_CFGID" ]; then
	   DNSMASQ_CONF_DIR="$$(awk -F '=' '/^conf-dir=/ {print $$2; exit}' "/tmp/etc/dnsmasq.conf.$$DEFAULT_DNSMASQ_CFGID" 2>/dev/null)"
	else
	   DNSMASQ_CONF_DIR="/tmp/dnsmasq.d"
	fi
	DNSMASQ_CONF_DIR=$${DNSMASQ_CONF_DIR%/}
	DNSMASQ_CONF_DIR=$${DNSMASQ_CONF_DIR:-/tmp/dnsmasq.d}
	rm -rf /etc/openclash >/dev/null 2>&1
	rm -rf /etc/config/openclash >/dev/null 2>&1
	rm -rf /tmp/openclash.log >/dev/null 2>&1
	rm -rf /tmp/openclash_start.log >/dev/null 2>&1
	rm -rf /tmp/openclash.change >/dev/null 2>&1
	rm -rf /usr/share/openclash >/dev/null 2>&1
	rm -rf /tmp/openclash_version_history.json >/dev/null 2>&1
	rm -rf /tmp/openclash_cdn_info.json >/dev/null 2>&1
	rm -rf /tmp/openclash_tpl_cache >/dev/null 2>&1
	rm -f "$${DNSMASQ_CONF_DIR}/dnsmasq_openclash_custom_domain.conf" >/dev/null 2>&1
	rm -f "$${DNSMASQ_CONF_DIR}/dnsmasq_openclash_chnroute_pass.conf" >/dev/null 2>&1
	rm -f "$${DNSMASQ_CONF_DIR}/dnsmasq_openclash_chnroute6_pass.conf" >/dev/null 2>&1
	rm -rf /tmp/etc/openclash >/dev/null 2>&1
	rm -rf /tmp/openclash_announcement >/dev/null 2>&1
	rm -f /tmp/openclash_clients.json >/dev/null 2>&1
	rm -rf /www/luci-static/resources/openclash >/dev/null 2>&1
	rm -f /tmp/oix_checkin /tmp/oix_core_install_tried /tmp/oix_google_login /tmp/oix_info >/dev/null 2>&1
	rm -rf /tmp/openclash_cfg_update_* >/dev/null 2>&1
	rm -rf /tmp/openclash_jobs >/dev/null 2>&1
	rm -f /tmp/openclash_overwrite_cron /tmp/openclash_overwrite_cron.?????? >/dev/null 2>&1
	sed -i 's/\(HTTP_MAX_CONTENT[[:space:]]*=[[:space:]]*\)[0-9][0-9]*\([[:space:]]*\*[[:space:]]*[0-9][0-9]*\)*/\11024*100/' /usr/lib/lua/luci/http.lua >/dev/null 2>&1
	sed -i 's/\(HTTP_MAX_CONTENT[[:space:]]*=[[:space:]]*\)[0-9][0-9]*\([[:space:]]*\*[[:space:]]*[0-9][0-9]*\)*/\11024*100/' /usr/share/ucode/luci/http.uc >/dev/null 2>&1
	rm -f /etc/nginx/conf.d/openclash.conf >/dev/null 2>&1
	rm -f /etc/nginx/conf.d/openclash.locations >/dev/null 2>&1
	[ -x /etc/init.d/nginx ] && /etc/init.d/nginx reload >/dev/null 2>&1
	uci -q delete firewall.openclash
	uci -q commit firewall
	[ -f "/etc/config/ucitrack" ] && {
	uci -q delete ucitrack.@openclash[-1]
	uci -q commit ucitrack
	}
	rm -rf /tmp/luci-indexcache /tmp/luci-indexcache.* /var/luci-indexcache /var/luci-indexcache.* >/dev/null 2>&1
	rm -rf /tmp/luci-modulecache /var/luci-modulecache >/dev/null 2>&1
	exit 0
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/*.*.lmo $(1)/usr/lib/lua/luci/i18n/
	$(CP) $(PKG_BUILD_DIR)/root/* $(1)/
	$(CP) $(PKG_BUILD_DIR)/luasrc/* $(1)/usr/lib/lua/luci/
	$(if $(filter y,$(CONFIG_USE_APK)),$(INSTALL_DATA) $(CURDIR)/files/apk-assets.sh $(1)/usr/share/openclash/apk-assets.sh)
	$(if $(filter y,$(CONFIG_USE_APK)),$(INSTALL_DIR) $(1)/etc/apk/protected_paths.d && $(INSTALL_DATA) $(CURDIR)/files/apk-protected.list $(1)/etc/apk/protected_paths.d/openclash.list)
endef

# The SDK's default hooks start or stop init scripts even after a failed package hook.
# Keep the packaged init script and first-boot defaults, and let our hooks control their order.
ifneq ($(CONFIG_USE_APK),y)
$(PKG_NAME)_COMMANDS += cp $(CURDIR)/files/ipk-hook.sh prerm && cp prerm postinst && chmod 0755 prerm postinst || exit 1;
endif

$(eval $(call BuildPackage,$(PKG_NAME)))

ifeq ($(CONFIG_USE_APK),y)
APK_SCRIPTS_$(PKG_NAME) := $(subst /pre-deinstall",/prerm-pkg",$(subst /post-install",/postinst-pkg",$(subst /post-upgrade",/postinst-pkg",$(APK_SCRIPTS_$(PKG_NAME)))))
endif
