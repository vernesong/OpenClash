#
# Copyright (C) 2017 Steven Hessing
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=libyaml-cpp
PKG_VERSION:=0.6.3-98acc5a
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/jbeder/yaml-cpp.git
PKG_SOURCE_VERSION:=98acc5a8874faab28b82c28936f4b400b389f5d6
PKG_MIRROR_HASH:=b7d767a18bbc83a2deea953d9fff949e95a8badaeada43b5a68573212940d32d
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-$(PKG_SOURCE_VERSION).tar.gz

PKG_MAINTAINER:= Steven Hessing <steven.hessing@gmail.com>
PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE
PKG_CPE_ID:=cpe:/a:yaml-cpp_project:yaml-cpp

CMAKE_INSTALL:=1
PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

define Package/libyaml-cpp
  SECTION:=development
  CATEGORY:=Libraries
  TITLE:=libyaml-cpp
  URL:=https://github.com/jbeder/yaml-cpp
  DEPENDS:=+libstdcpp
  ABI_VERSION:=0.6
endef

define Package/libyaml-cpp/description
  yaml-cpp is a YAML parser and emitter in C++ matching the YAML 1.2 spec.
endef

CMAKE_OPTIONS += \
	-DYAML_BUILD_SHARED_LIBS=ON \
	-DYAML_CPP_BUILD_TESTS=OFF \
	-DYAML_CPP_BUILD_TOOLS=OFF

define Package/libyaml-cpp/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DATA) $(PKG_INSTALL_DIR)/usr/lib/libyaml-cpp.so.$(ABI_VERSION) $(1)/usr/lib/
endef

$(eval $(call BuildPackage,libyaml-cpp))
