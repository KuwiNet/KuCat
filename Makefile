include $(TOPDIR)/rules.mk
THEME_NAME:=kucat
THEME_TITLE:=Kucat Theme
PKG_NAME:=luci-theme-$(THEME_NAME)
LUCI_TITLE:=Kucat Theme by KuwiNet(kuwi.net)
LUCI_DEPENDS:=+wget +curl +jsonfilter +luci-app-advancedplus +luci-app-kucat-config
PKG_VERSION:=3.5.0

define Package/luci-theme-$(THEME_NAME)/conffiles
/www/luci-static/resources/background/
endef

include $(TOPDIR)/feeds/luci/luci.mk

define Build/Compile
	$(call Build/Compile/Default)
endef

# call BuildPackage - OpenWrt buildroot signature
