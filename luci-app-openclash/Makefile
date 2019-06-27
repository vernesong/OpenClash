include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-openclash
PKG_VERSION:=0.30.2
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

define Package/$(PKG_NAME)/postinst
#!/bin/sh
if [ -f "/tmp/openclash.bak" ]; then
	mv "/tmp/openclash.bak" "/etc/config/openclash" 2>/dev/null
	mv "/tmp/openclash_custom_rules.list.bak" "/etc/config/openclash_custom_rules.list" 2>/dev/null
fi
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
	cp "/etc/config/openclash" "/tmp/openclash.bak" 2>/dev/null
	cp "/etc/config/openclash_custom_rules.list" "/tmp/openclash_custom_rules.list.bak" 2>/dev/null
	uci set openclash.config.enable=0 && uci commit openclash
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/*.*.lmo $(1)/usr/lib/lua/luci/i18n/
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
