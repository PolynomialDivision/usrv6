include $(TOPDIR)/rules.mk

PKG_NAME:=usrv6
PKG_VERSION:=2020.11.24
PKG_RELEASE:=1

PKG_MAINTAINER:=Nick Hainke <vincent@systemli.org>

include $(INCLUDE_DIR)/package.mk

Build/Compile=

define Package/usrv6/Default
	SECTION:=net
	CATEGORY:=Network
	TITLE:=USRv6
	URL:=https://github.com/PolynomialDivision
	PKGARCH:=all
endef

define Package/usrv6
	$(call Package/usrv6/Default)
endef

define Package/usrv6s
	$(call Package/usrv6/Default)
	TITLE+= (server)
	DEPENDS:=+rpcd +ip-full +uhttpd +uhttpd-mod-ubus
endef

define Package/usrv6s/install
	$(INSTALL_DIR) $(1)/usr/share/usrv6/
	$(INSTALL_BIN) ./usrv6-server/lib/install_prefix.sh $(1)/usr/share/usrv6/install_prefix.sh
	$(INSTALL_BIN) ./usrv6-server/lib/delete_prefix.sh $(1)/usr/share/usrv6/delete_prefix.sh
	$(INSTALL_BIN) ./usrv6-server/lib/manage_prefixes.sh $(1)/usr/share/usrv6/manage_prefixes.sh
	$(INSTALL_BIN) ./usrv6-server/lib/install_usrv6_user.sh $(1)/usr/share/usrv6/install_usrv6_user.sh
	$(INSTALL_BIN) ./usrv6-server/lib/babel_server.sh $(1)/usr/share/usrv6/babel_server.sh

	$(INSTALL_DIR) $(1)/usr/libexec/rpcd/
	$(INSTALL_BIN) ./usrv6-server/usrv6s.sh $(1)/usr/libexec/rpcd/usrv6s

	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(CP) ./usrv6-server/config/usrv6s.json $(1)/usr/share/rpcd/acl.d/

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./usrv6-server/config/usrv6prefixes.config $(1)/etc/config/usrv6prefixes
endef

define Package/usrv6s/postinst
	#!/bin/sh
	if [ -z $${IPKG_INSTROOT} ] ; then
		. /usr/share/usrv6/install_usrv6_user.sh
	fi
endef

define Package/usrv6c
	$(call Package/usrv6/Default)
	TITLE+= (client)
	DEPENDS:=+coreutils-fold +owipcalc +curl +openssl-util
endef

define Package/usrv6c/install
	$(INSTALL_DIR) $(1)/usr/share/usrv6/
	$(INSTALL_BIN) ./usrv6-client/lib/configure_gateway.sh $(1)/usr/share/usrv6/configure_gateway.sh
	$(INSTALL_BIN) ./usrv6-client/lib/rpcd_ubus.sh $(1)/usr/share/usrv6/rpcd_ubus.sh
	$(INSTALL_BIN) ./usrv6-client/lib/babel.sh $(1)/usr/share/usrv6/babel.sh

	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./usrv6-client/usrv6c.sh $(1)/usr/bin/usrv6c

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./usrv6-client/config/usrv6c.config $(1)/etc/config/usrv6c

	$(INSTALL_DIR) $(1)/etc/tofucrt/
endef

define Package/usrv6s-udp
  $(call Package/usrv6/Default)
  TITLE+= (udp plugin for malicious gateway)
  DEPENDS:=+luasocket +libubus-lua +luci-lib-jsonc
endef

define Package/usrv6s-udp/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./usrv6-server/config/usrv6s-udp.config $(1)/etc/config/usrv6s-udp
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./usrv6-server/init.d/usrv6s-udp $(1)/etc/init.d/usrv6s-udp
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./usrv6-server/usrv6s-udp.lua $(1)/usr/bin/usrv6s-udp
endef

define Package/usrv6c-udp
  $(call Package/usrv6/Default)
  TITLE+= (udp plugin for malicious gateway)
  DEPENDS:=+luasocket +libubus-lua +luci-lib-jsonc
endef

define Package/usrv6c-udp/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./usrv6-client/usrv6c-udp.lua $(1)/usr/bin/usrv6c-udp
endef

define Package/prefix-switcher
	SECTION:=net
	CATEGORY:=Network
	TITLE:=Prefix Switcher
	URL:=https://github.com/PolynomialDivision
	PKGARCH:=all
	DEPENDS:=+usrv6c +babeld-utils +xdp-srv6-remover +xdp-srv6-adder +tc
endef

define Package/prefix-switcher/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./prefix-switcher/prefix-switcher.sh $(1)/usr/bin/prefix-switcher

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./prefix-switcher/config/prefix-switcher.config $(1)/etc/config/prefix-switcher
endef

$(eval $(call BuildPackage,usrv6))
$(eval $(call BuildPackage,usrv6s))
$(eval $(call BuildPackage,usrv6c))
$(eval $(call BuildPackage,usrv6s-udp))
$(eval $(call BuildPackage,usrv6c-udp))
$(eval $(call BuildPackage,prefix-switcher))
