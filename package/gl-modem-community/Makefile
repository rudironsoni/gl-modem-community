include $(TOPDIR)/rules.mk

PKG_NAME:=gl-modem-community
# x-release-please-start-version
PKG_VERSION:=0.2.0
# x-release-please-end
PKG_RELEASE:=1
PKG_LICENSE:=GPL-3.0-only
PKG_MAINTAINER:=Rudimar Ronsoni <rudironsoni@users.noreply.github.com>

include $(INCLUDE_DIR)/package.mk

define Package/gl-modem-community
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=WWAN
  TITLE:=Community modem drivers for GL.iNet firmware
  # Runtime-only dependencies. EXTRA_DEPENDS keeps this architecture-independent
  # package from rebuilding the SDK's complete kernel package set.
  EXTRA_DEPENDS:=comgt (>=0), flock (>=0), jq (>=0), kmod-usb-acm (>=0), kmod-usb-serial-option (>=0), kmod-usb-net-rndis (>=0)
endef

define Package/gl-modem-community/description
Adds community modem definitions and netifd drivers while preserving GL.iNet's
stock JSON-RPC, ubus, web UI, mobile app, and vendor-modem fallback paths.
endef

define Package/gl-modem-community/conffiles
/etc/config/gl_modem_community
endef

define Package/gl-modem-community/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT:-}" ] && exit 0
initd_root=$${GL_MODEM_COMMUNITY_INITD_ROOT:-/etc/init.d}
"$$initd_root/gl_modem_community" enable
"$$initd_root/gl_modem_community" restart
if [ -x "$$initd_root/gl_cellular_manager" ]; then
	"$$initd_root/gl_cellular_manager" restart
elif [ -x "$$initd_root/modem" ]; then
	"$$initd_root/modem" restart
fi
endef

define Package/gl-modem-community/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT:-}" ] && exit 0
initd_root=$${GL_MODEM_COMMUNITY_INITD_ROOT:-/etc/init.d}
"$$initd_root/gl_modem_community" stop
"$$initd_root/gl_modem_community" disable
if [ -x "$$initd_root/gl_cellular_manager" ]; then
	"$$initd_root/gl_cellular_manager" restart
elif [ -x "$$initd_root/modem" ]; then
	"$$initd_root/modem" restart
fi
endef

define Build/Compile
	$(TARGET_CC) $(TARGET_CFLAGS) -fPIC -shared \
		-o $(PKG_BUILD_DIR)/fm350-at-compat.so \
		$(PKG_BUILD_DIR)/fm350_at_compat.c
endef

define Package/gl-modem-community/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/gl_modem_community $(1)/etc/config/gl_modem_community
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/gl_modem_community $(1)/etc/init.d/gl_modem_community
	$(INSTALL_DIR) $(1)/etc/gcom
	$(INSTALL_DATA) ./files/etc/gcom/fm350-auth.gcom $(1)/etc/gcom/fm350-auth.gcom
	$(INSTALL_DATA) ./files/etc/gcom/fm350-connect.gcom $(1)/etc/gcom/fm350-connect.gcom
	$(INSTALL_DATA) ./files/etc/gcom/fm350-disconnect.gcom $(1)/etc/gcom/fm350-disconnect.gcom
	$(INSTALL_DATA) ./files/etc/gcom/fm350-query.gcom $(1)/etc/gcom/fm350-query.gcom
	$(INSTALL_DATA) ./files/etc/gcom/fm350-probe.gcom $(1)/etc/gcom/fm350-probe.gcom
	$(INSTALL_DATA) ./files/etc/gcom/fm350-at.gcom $(1)/etc/gcom/fm350-at.gcom
	$(INSTALL_DIR) $(1)/etc/hotplug.d/usb
	$(INSTALL_BIN) ./files/etc/hotplug.d/usb/99-gl-modem-community $(1)/etc/hotplug.d/usb/99-gl-modem-community
	$(INSTALL_DIR) $(1)/lib/netifd/proto
	$(INSTALL_BIN) ./files/lib/netifd/proto/xmm.sh $(1)/lib/netifd/proto/xmm.sh
	$(INSTALL_DIR) $(1)/usr/lib/oui-httpd/rpc
	$(INSTALL_DATA) ./files/usr/lib/oui-httpd/rpc/modem $(1)/usr/lib/oui-httpd/rpc/modem
	$(INSTALL_DIR) $(1)/usr/libexec/gl-modem-community
	$(INSTALL_BIN) ./files/usr/libexec/gl-modem-community/merge-models $(1)/usr/libexec/gl-modem-community/merge-models
	$(INSTALL_BIN) ./files/usr/libexec/gl-modem-community/modem_AT-wrapper $(1)/usr/libexec/gl-modem-community/modem_AT-wrapper
	$(INSTALL_BIN) ./files/usr/libexec/gl-modem-community/fm350-network-repair $(1)/usr/libexec/gl-modem-community/fm350-network-repair
	$(INSTALL_BIN) ./files/usr/libexec/gl-modem-community/runtime-stack $(1)/usr/libexec/gl-modem-community/runtime-stack
	$(INSTALL_BIN) ./files/usr/libexec/gl-modem-community/legacy-bus $(1)/usr/libexec/gl-modem-community/legacy-bus
	$(INSTALL_BIN) ./files/usr/libexec/gl-modem-community/fm350-at $(1)/usr/libexec/gl-modem-community/fm350-at
	$(INSTALL_DIR) $(1)/usr/lib/gl-modem-community
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/fm350-at-compat.so $(1)/usr/lib/gl-modem-community/fm350-at-compat.so
	$(INSTALL_DIR) $(1)/usr/share/gl-modem-community/drivers.d
	$(INSTALL_DATA) ./files/usr/share/gl-modem-community/drivers.d/fm350.json $(1)/usr/share/gl-modem-community/drivers.d/fm350.json
	$(INSTALL_DIR) $(1)/usr/share/gl-modem-community/rpc-drivers
	$(INSTALL_DATA) ./files/usr/share/gl-modem-community/rpc-drivers/fm350.lua $(1)/usr/share/gl-modem-community/rpc-drivers/fm350.lua
endef

$(eval $(call BuildPackage,gl-modem-community))
