include $(TOPDIR)/rules.mk

PKG_NAME:=luci-theme-kucat
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/luci-theme-kucat
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=Themes
  TITLE:=LuCI Theme - KuCat
  DEPENDS:=+luci-base  # 依赖 luci-base，需确保已安装
endef

define Package/luci-theme-kucat/description
  A custom LuCI theme for OpenWRT: KuCat
endef

define Build/Compile
  # 主题包通常无需编译，直接复制文件即可（根据实际需求调整）
endef

define Package/luci-theme-kucat/install
  # 安装主题文件到目标系统的 /usr/lib/lua/luci/view/themes/kucat/
  $(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/themes/kucat
  $(CP) ./files/* $(1)/usr/lib/lua/luci/view/themes/kucat/
endef

$(eval $(call BuildPackage,luci-theme-kucat))
