include $(TOPDIR)/rules.mk

# 主题基本信息配置
LUCI_TITLE:=luci-theme-kucat
LUCI_DESCRIPTION:=A modern and clean theme for LuCI, based on Argon and OpenTopd
LUCI_DEPENDS:=+luci-base +luci-lib-nixio
LUCI_PKGARCH:=all

# 包信息配置
PKG_NAME:=luci-theme-kucat
PKG_VERSION:=2.6.8
PKG_RELEASE:=2
PKG_LICENSE:=Apache-2.0
PKG_MAINTAINER:=The KuwiNet Team <mail@kuwi.net>

# 引入LuCI包编译规则
include $(TOPDIR)/feeds/luci/luci.mk

# 安装文件的核心逻辑
define Package/luci-theme-kucat/install
	# 创建必要的目录结构
	$(INSTALL_DIR) $(1)/www/luci-static/kucat
	$(INSTALL_DIR) $(1)/www/luci-static/kucat/css
	$(INSTALL_DIR) $(1)/www/luci-static/kucat/fonts
	$(INSTALL_DIR) $(1)/www/luci-static/kucat/js
	$(INSTALL_DIR) $(1)/www/luci-static/kucat/img
	$(INSTALL_DIR) $(1)/etc/uci-defaults

	# 复制主题核心文件（保留原始内容，不做压缩）
	$(CP) $(PKG_BUILD_DIR)/htdocs/luci-static/kucat/css/* $(1)/www/luci-static/kucat/css/
	$(CP) $(PKG_BUILD_DIR)/htdocs/luci-static/kucat/fonts/* $(1)/www/luci-static/kucat/fonts/
	$(CP) $(PKG_BUILD_DIR)/htdocs/luci-static/kucat/js/* $(1)/www/luci-static/kucat/js/
	$(CP) $(PKG_BUILD_DIR)/htdocs/luci-static/kucat/img/* $(1)/www/luci-static/kucat/img/
	$(CP) $(PKG_BUILD_DIR)/htdocs/luci-static/kucat/favicon.ico $(1)/www/luci-static/kucat/

	# 安装主题配置脚本（设置默认主题）
	$(CP) $(PKG_BUILD_DIR)/root/etc/uci-defaults/99_luci-theme-kucat $(1)/etc/uci-defaults/
endef
