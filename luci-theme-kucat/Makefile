include $(TOPDIR)/rules.mk
THEME_NAME:=kucat
THEME_TITLE:=Kucat Theme
PKG_NAME:=luci-theme-$(THEME_NAME)
LUCI_TITLE:=Kucat Theme by KuwiNet(kuwi.net)
PKG_VERSION:=2.7.2

define Package/luci-theme-$(THEME_NAME)/conffiles
/www/luci-static/resources/background/
/www/luci-static/kucat/img/
/www/luci-static/kucat/css/
endef

include $(TOPDIR)/feeds/luci/luci.mk

# 禁用LuCI默认的资源压缩钩子
define Build/Compile
	$(call Build/Compile/Default)
endef

# call BuildPackage - OpenWrt buildroot signature
