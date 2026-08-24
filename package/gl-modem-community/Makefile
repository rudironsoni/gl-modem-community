include $(TOPDIR)/rules.mk

PKG_NAME:=gl-modem-community
# x-release-please-start-version
PKG_VERSION:=0.4.0
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
  # One architecture-independent package serves every supported router.
  # VOS 5G tooling (adb, uqmi, ...) is checked at runtime instead of being a
  # hard dependency so the package installs on firmwares that lack it.
  PKGARCH:=all
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
# Restart cellular manager if it exists (not all firmwares have it)
# Use explicit file check and suppress shell "not found" error
if [ -f "$$initd_root/gl_cellular_manager" ] && [ -x "$$initd_root/gl_cellular_manager" ]; then
	( "$$initd_root/gl_cellular_manager" restart ) >/dev/null 2>&1 || true
elif [ -f "$$initd_root/modem" ] && [ -x "$$initd_root/modem" ]; then
	( "$$initd_root/modem" restart ) >/dev/null 2>&1 || true
fi
if [ -f "$$initd_root/nginx" ] && [ -x "$$initd_root/nginx" ]; then
	( "$$initd_root/nginx" restart ) >/dev/null 2>&1 || true
fi
endef

define Package/gl-modem-community/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT:-}" ] && exit 0
initd_root=$${GL_MODEM_COMMUNITY_INITD_ROOT:-/etc/init.d}
"$$initd_root/gl_modem_community" stop
"$$initd_root/gl_modem_community" disable
# Restart cellular manager if it exists (not all firmwares have it)
if [ -f "$$initd_root/gl_cellular_manager" ] && [ -x "$$initd_root/gl_cellular_manager" ]; then
	( "$$initd_root/gl_cellular_manager" restart ) >/dev/null 2>&1 || true
elif [ -f "$$initd_root/modem" ] && [ -x "$$initd_root/modem" ]; then
	( "$$initd_root/modem" restart ) >/dev/null 2>&1 || true
fi
endef

define Package/gl-modem-community/postrm
#!/bin/sh
[ -n "$${IPKG_INSTROOT:-}" ] && exit 0
initd_root=$${GL_MODEM_COMMUNITY_INITD_ROOT:-/etc/init.d}
if [ -f "$$initd_root/nginx" ] && [ -x "$$initd_root/nginx" ]; then
	( "$$initd_root/nginx" restart ) >/dev/null 2>&1 || true
fi
endef

define Build/Compile
	$(TARGET_CC) $(TARGET_CFLAGS) -fPIC -shared \
		-o $(PKG_BUILD_DIR)/fm350-at-compat.so \
		$(PKG_BUILD_DIR)/fm350_at_compat.c
	$(TARGET_CC) $(TARGET_CFLAGS) -fPIC -shared \
		-o $(PKG_BUILD_DIR)/vos5g-at-compat.so \
		$(PKG_BUILD_DIR)/vos5g_at_compat.c
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
	$(INSTALL_BIN) ./files/usr/libexec/gl-modem-community/ensure-option-ids $(1)/usr/libexec/gl-modem-community/ensure-option-ids
	$(INSTALL_BIN) ./files/usr/libexec/gl-modem-community/fm350-at $(1)/usr/libexec/gl-modem-community/fm350-at
	$(INSTALL_BIN) ./files/usr/libexec/gl-modem-community/fm350-port $(1)/usr/libexec/gl-modem-community/fm350-port
	$(INSTALL_BIN) ./files/usr/libexec/gl-modem-community/fm350-fcc-unlock $(1)/usr/libexec/gl-modem-community/fm350-fcc-unlock
	$(INSTALL_BIN) ./files/usr/libexec/gl-modem-community/fm350-esim-sdk $(1)/usr/libexec/gl-modem-community/fm350-esim-sdk
	$(INSTALL_BIN) ./files/usr/libexec/gl-modem-community/tethering-overlay $(1)/usr/libexec/gl-modem-community/tethering-overlay
	$(INSTALL_BIN) ./files/usr/libexec/gl-modem-community/fm350-boot-restore $(1)/usr/libexec/gl-modem-community/fm350-boot-restore
	$(INSTALL_DIR) $(1)/usr/share/gl-modem-community/esim-http/sdk
	$(INSTALL_BIN) ./files/usr/share/gl-modem-community/esim-http/sdk/v1 $(1)/usr/share/gl-modem-community/esim-http/sdk/v1
	$(INSTALL_DIR) $(1)/usr/share/gl-modem-community/nginx
	$(INSTALL_DATA) ./files/usr/share/gl-modem-community/nginx/gl-modem-community-esim.conf $(1)/usr/share/gl-modem-community/nginx/gl-modem-community-esim.conf
	$(INSTALL_DIR) $(1)/usr/share/gl-modem-community/rpc-wrappers
	$(INSTALL_DATA) ./files/usr/share/gl-modem-community/rpc-wrappers/tethering.lua $(1)/usr/share/gl-modem-community/rpc-wrappers/tethering.lua
	$(INSTALL_DIR) $(1)/usr/share/gl-modem-community/menu.d
	$(INSTALL_DATA) ./files/usr/share/gl-modem-community/menu.d/esim.json $(1)/usr/share/gl-modem-community/menu.d/esim.json
	$(INSTALL_DIR) $(1)/www/views
	$(INSTALL_DATA) ./files/www/views/gl-sdk4-ui-esim.common.js $(1)/www/views/gl-sdk4-ui-esim.common.js
	$(INSTALL_DIR) $(1)/www/i18n
	$(INSTALL_DATA) ./files/www/i18n/gl-sdk4-ui-esim.en.json $(1)/www/i18n/gl-sdk4-ui-esim.en.json
	$(INSTALL_BIN) ./files/usr/libexec/gl-modem-community/vos5g-qmi $(1)/usr/libexec/gl-modem-community/vos5g-qmi
	$(INSTALL_BIN) ./files/usr/libexec/gl-modem-community/vos5g-qmi-rf-band $(1)/usr/libexec/gl-modem-community/vos5g-qmi-rf-band
	$(INSTALL_BIN) ./files/usr/libexec/gl-modem-community/vos5g-qmi-system-mode $(1)/usr/libexec/gl-modem-community/vos5g-qmi-system-mode
	$(INSTALL_BIN) ./files/usr/libexec/gl-modem-community/vos5g-band-monitor $(1)/usr/libexec/gl-modem-community/vos5g-band-monitor
	$(INSTALL_DIR) $(1)/usr/lib/gl-modem-community
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/fm350-at-compat.so $(1)/usr/lib/gl-modem-community/fm350-at-compat.so
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/vos5g-at-compat.so $(1)/usr/lib/gl-modem-community/vos5g-at-compat.so
	$(INSTALL_DIR) $(1)/usr/share/gl-modem-community/drivers.d
	$(INSTALL_DATA) ./files/usr/share/gl-modem-community/drivers.d/fm350.json $(1)/usr/share/gl-modem-community/drivers.d/fm350.json
	$(INSTALL_DATA) ./files/usr/share/gl-modem-community/drivers.d/vos5g.json $(1)/usr/share/gl-modem-community/drivers.d/vos5g.json
	$(INSTALL_DIR) $(1)/usr/share/gl-modem-community/rpc-drivers
	$(INSTALL_DATA) ./files/usr/share/gl-modem-community/rpc-drivers/fm350.lua $(1)/usr/share/gl-modem-community/rpc-drivers/fm350.lua
	$(INSTALL_DATA) ./files/usr/share/gl-modem-community/rpc-drivers/vos5g.lua $(1)/usr/share/gl-modem-community/rpc-drivers/vos5g.lua
endef

$(eval $(call BuildPackage,gl-modem-community))
