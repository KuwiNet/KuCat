include $(TOPDIR)/rules.mk

# 主题核心信息（版本和作者在此维护）
LUCI_TITLE:=LuCI Theme - KuCat
LUCI_DESCRIPTION:=Modern & Clean Theme for LuCI, Based on Argon
LUCI_DEPENDS:=+luci-base +luci-lib-jsonc
LUCI_PKGARCH:=all  # 通用架构

# 版本和作者信息（统一维护点）
PKG_NAME:=luci-theme-kucat
PKG_VERSION:=2.6.8
PKG_RELEASE:=1
PKG_LICENSE:=Apache-2.0
PKG_MAINTAINER:=KuwiNet <contact@kuwinet.com>  # 作者信息

include $(TOPDIR)/feeds/luci/luci.mk

# 安装主题文件
define Package/luci-theme-kucat/install
	# 创建主题目录
	$(INSTALL_DIR) $(1)/www/luci-static/kucat/{css,fonts,js,img}
	$(INSTALL_DIR) $(1)/etc/uci-defaults

	# 复制静态资源
	$(CP) $(PKG_BUILD_DIR)/htdocs/luci-static/kucat/css/* $(1)/www/luci-static/kucat/css/
	$(CP) $(PKG_BUILD_DIR)/htdocs/luci-static/kucat/fonts/* $(1)/www/luci-static/kucat/fonts/
	$(CP) $(PKG_BUILD_DIR)/htdocs/luci-static/kucat/js/* $(1)/www/luci-static/kucat/js/
	$(CP) $(PKG_BUILD_DIR)/htdocs/luci-static/kucat/img/* $(1)/www/luci-static/kucat/img/
	$(CP) $(PKG_BUILD_DIR)/htdocs/luci-static/kucat/favicon.ico $(1)/www/luci-static/kucat/

	# 复制配置脚本
	$(CP) $(PKG_BUILD_DIR)/root/etc/uci-defaults/30_luci-kucat $(1)/etc/uci-defaults/
endef
