include $(TOPDIR)/rules.mk
THEME_NAME:=zwrt
THEME_TITLE:=ZWRT Theme
PKG_NAME:=luci-theme-$(THEME_NAME)
LUCI_TITLE:=ZWRT Theme by kuwi.net
LUCI_DEPENDS:=+wget +curl +jsonfilter +luci-app-zwrt
PKG_VERSION:=3.5.5

define Package/luci-theme-$(THEME_NAME)/conffiles
/www/luci-static/resources/background/
endef

include $(TOPDIR)/feeds/luci/luci.mk

define Build/Compile
	$(call Build/Compile/Default)
endef

# call BuildPackage - OpenWrt buildroot signature
