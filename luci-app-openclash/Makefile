include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-openclash
PKG_VERSION:=0.47.168
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
	DEPENDS:=+dnsmasq-full +bash +curl +ca-bundle +ip-full \
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
	if [ -z "$$$$CORE_ARCH" ]; then \
		echo "ERROR: no Meta core available for $(ARCH_PACKAGES)" >&2; exit 1; \
	fi; \
	mkdir -p $(PKG_BUILD_DIR)/root/etc/openclash/core && \
	curl -fSL --connect-timeout 30 --retry 3 \
		-o $(PKG_BUILD_DIR)/clash_meta.tar.gz \
		"https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-$$$$CORE_ARCH.tar.gz" && \
	tar -xzf $(PKG_BUILD_DIR)/clash_meta.tar.gz -C $(PKG_BUILD_DIR) clash && \
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/clash $(PKG_BUILD_DIR)/root/etc/openclash/core/clash_meta
endef
endif

define Package/$(PKG_NAME)/conffiles
endef

define Package/$(PKG_NAME)/preinst
#!/bin/sh
	if [ -f "/etc/config/openclash" ] && [ ! -f "/tmp/openclash.bak" ]; then
		cp -f "/etc/config/openclash" "/tmp/openclash.bak" >/dev/null 2>&1
		cp -rf "/etc/openclash" "/tmp/openclash" >/dev/null 2>&1
		cp -rf "/usr/share/openclash/ui" "/tmp/openclash_ui" >/dev/null 2>&1
		cp -rf "/www/luci-static/resources/openclash/pac" "/tmp/pac" >/dev/null 2>&1
	fi
	exit 0
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
	exit 0
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
	[ -n "$(pidof clash)" ] && /etc/init.d/openclash stop 2>/dev/null
	if [ -f "/etc/config/openclash" ] && [ ! -f "/tmp/openclash.bak" ]; then
		cp -f "/etc/config/openclash" "/tmp/openclash.bak" >/dev/null 2>&1
		cp -rf "/etc/openclash" "/tmp/openclash" >/dev/null 2>&1
		cp -rf "/usr/share/openclash/ui" "/tmp/openclash_ui" >/dev/null 2>&1
		cp -rf "/www/luci-static/resources/openclash/pac" "/tmp/pac" >/dev/null 2>&1
	fi
	exit 0
endef

define Package/$(PKG_NAME)/postrm
#!/bin/sh
	DEFAULT_DNSMASQ_CFGID="$$(uci -q show "dhcp.@dnsmasq[0]" | awk 'NR==1 {split($0, conf, /[.=]/); print conf[2]}' 2>/dev/null)"
	if [ -f "/tmp/etc/dnsmasq.conf.$DEFAULT_DNSMASQ_CFGID" ]; then
	   DNSMASQ_CONF_DIR="$$(awk -F '=' '/^conf-dir=/ {print $2}' "/tmp/etc/dnsmasq.conf.$DEFAULT_DNSMASQ_CFGID" 2>/dev/null)"
	else
	   DNSMASQ_CONF_DIR="/tmp/dnsmasq.d"
	fi
	DNSMASQ_CONF_DIR=$${DNSMASQ_CONF_DIR%*/}
	rm -rf /etc/openclash >/dev/null 2>&1
	rm -rf /etc/config/openclash >/dev/null 2>&1
	rm -rf /tmp/openclash.log >/dev/null 2>&1
	rm -rf /tmp/openclash_start.log >/dev/null 2>&1
	rm -rf /tmp/openclash.change >/dev/null 2>&1
	rm -rf /usr/share/openclash >/dev/null 2>&1
	rm -rf /tmp/openclash_version_history.json >/dev/null 2>&1
	rm -rf /tmp/openclash_cdn_info.json >/dev/null 2>&1
	rm -rf ${DNSMASQ_CONF_DIR}/dnsmasq_openclash_custom_domain.conf >/dev/null 2>&1
	rm -rf ${DNSMASQ_CONF_DIR}/dnsmasq_openclash_chnroute_pass.conf >/dev/null 2>&1
	rm -rf ${DNSMASQ_CONF_DIR}/dnsmasq_openclash_chnroute6_pass.conf >/dev/null 2>&1
	rm -rf /tmp/etc/openclash >/dev/null 2>&1
	rm -rf /tmp/openclash_announcement >/dev/null 2>&1
	rm -rf /www/luci-static/resources/openclash >/dev/null 2>&1
	rm -rf /tmp/oix* >/dev/null 2>&1
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
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
