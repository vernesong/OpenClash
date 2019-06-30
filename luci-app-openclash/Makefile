include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-openclash
PKG_VERSION:=0.31.0
PKG_RELEASE:=0
PKG_MAINTAINER:=frainzy1477&vernesong <https://github.com/vernesong/OpenClash>

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	CATEGORY:=Utilities
	SUBMENU:=Luci
	TITLE:=LuCI support for clash
	PKGARCH:=all
	DEPENDS:=+coreutils-nohup +bash +wget
endef

define Package/$(PKG_NAME)/description
    A LuCI support for clash
endef

define Package/$(PKG_NAME)/postinst
endef

define Build/Prepare
	$(foreach po,$(wildcard ${CURDIR}/i18n/zh-cn/*.po), \
		po2lmo $(po) $(PKG_BUILD_DIR)/$(patsubst %.po,%.lmo,$(notdir $(po)));)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/preinst
#!/bin/sh
if [ -f "/etc/config/openclash" ]; then
	uci set openclash.config.enable=0 && uci commit openclash
	cp "/etc/config/openclash" "/tmp/openclash.bak" 2>/dev/null
	cp "/etc/config/openclash_custom_rules.list" "/tmp/openclash_custom_rules.list.bak" 2>/dev/null
fi
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
rm -rf /tmp/luci*
if [ -f "/tmp/openclash.bak" ]; then
	mv "/tmp/openclash.bak" "/etc/config/openclash" 2>/dev/null
	mv "/tmp/openclash_custom_rules.list.bak" "/etc/config/openclash_custom_rules.list" 2>/dev/null
fi
if [ -f "/tmp/config.yaml" ]; then
	mv "/tmp/config.yaml" "/etc/openclash/config.yaml" 2>/dev/null
fi
if [ -f "/tmp/config.yml" ]; then
	mv "/tmp/config.yml" "/etc/openclash/config.yaml" 2>/dev/null
fi
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
	uci set openclash.config.enable=0 && uci commit openclash
	cp "/etc/config/openclash" "/tmp/openclash.bak" 2>/dev/null
	cp "/etc/config/openclash_custom_rules.list" "/tmp/openclash_custom_rules.list.bak" 2>/dev/null
endef

define Package/$(PKG_NAME)/postrm
#!/bin/sh
if [ -f "/etc/openclash/config.bak" ]; then
	mv "/etc/openclash/config.bak" "/tmp/config.yaml"
fi
if [ -f "/etc/openclash/clash" ]; then
	rm -rf /etc/openclash/config.* 2>/dev/null
else
	rm -rf /etc/openclash 2>/dev/null
fi
	rm -rf /tmp/openclash.log 2>/dev/null
	rm -rf /tmp/openclash_start.log 2>/dev/null
	rm -rf /tmp/Proxy_Group 2>/dev/null
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/*.*.lmo $(1)/usr/lib/lua/luci/i18n/
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
