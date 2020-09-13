include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-openclash
LUCI_TITLE:=LuCI support for clash
LUCI_DEPENDS:=+iptables +dnsmasq-full +coreutils +coreutils-nohup +bash +curl +jsonfilter +ca-certificates +ipset +ip-full +iptables-mod-tproxy
LUCI_PKGARCH:=all
PKG_VERSION:=0.40.3
PKG_RELEASE:=beta
PKG_MAINTAINER:=vernesong <https://github.com/vernesong/OpenClash>

define Package/$(PKG_NAME)/conffiles
/etc/config/openclash
/etc/openclash/
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
	uci set openclash.config.enable=0 >/dev/null 2>&1
	uci commit openclash >/dev/null 2>&1
	/etc/init.d/openclash stop
endef

define Package/$(PKG_NAME)/postrm
#!/bin/sh
if [ -f "/tmp/openclash_update.sh" ]; then
	rm -rf /etc/openclash/config >/dev/null 2>&1
	rm -rf /etc/openclash/backup >/dev/null 2>&1
	rm -rf /etc/openclash/proxy_provider >/dev/null 2>&1
	rm -rf /etc/openclash/rule_provider >/dev/null 2>&1
	rm -rf /etc/openclash/game_rules >/dev/null 2>&1
	rm -rf /etc/openclash/history >/dev/null 2>&1
fi
	rm -rf /tmp/openclash.log >/dev/null 2>&1
	rm -rf /tmp/openclash_start.log >/dev/null 2>&1
	rm -rf /tmp/Proxy_Group >/dev/null 2>&1
	rm -rf /tmp/rules_name >/dev/null 2>&1
	rm -rf /tmp/openclash_last_version >/dev/null 2>&1
	rm -rf /tmp/clash_last_version >/dev/null 2>&1
	rm -rf /etc/openclash/dnsmasq_fake_block.conf >/dev/null 2>&1
	rm -rf /etc/openclash/clash >/dev/null 2>&1
	uci delete firewall.openclash >/dev/null 2>&1
	uci commit firewall >/dev/null 2>&1
	uci delete ucitrack.@openclash[-1] >/dev/null 2>&1
	uci commit ucitrack >/dev/null 2>&1
	rm -rf /tmp/luci*
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
