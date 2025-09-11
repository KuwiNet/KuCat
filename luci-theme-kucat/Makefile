include $(TOPDIR)/rules.mk

# LuCI主题元信息（必须正确填写）
LUCI_TITLE:=LuCI Theme KuCat
LUCI_DESCRIPTION:=Modern theme for LuCI based on KuCat design
LUCI_DEPENDS:=+luci-base +luci-lib-jsonc
LUCI_PKGARCH:=all

# 包基本信息
PKG_NAME:=luci-theme-kucat
PKG_VERSION:=2.6.8
PKG_RELEASE:=1
PKG_LICENSE:=Apache-2.0
PKG_MAINTAINER:=KuwiNet Team <dev@kuwi.net>

# 引入LuCI包编译核心规则（关键修复点）
include $(TOPDIR)/feeds/luci/luci.mk

# 安装规则（确保文件正确部署）
define Package/luci-theme-kucat/install
	# 创建目标目录结构
	$(INSTALL_DIR) $(1)/www/luci-static/kucat/{css,fonts,js,img}
	$(INSTALL_DIR) $(1)/etc/uci-defaults

	# 复制静态资源（保留原始文件）
	$(CP) $(PKG_BUILD_DIR)/htdocs/luci-static/kucat/css/* $(1)/www/luci-static/kucat/css/
	$(CP) $(PKG_BUILD_DIR)/htdocs/luci-static/kucat/fonts/* $(1)/www/luci-static/kucat/fonts/
	$(CP) $(PKG_BUILD_DIR)/htdocs/luci-static/kucat/js/* $(1)/www/luci-static/kucat/js/
	$(CP) $(PKG_BUILD_DIR)/htdocs/luci-static/kucat/img/* $(1)/www/luci-static/kucat/img/
	$(CP) $(PKG_BUILD_DIR)/htdocs/luci-static/kucat/favicon.ico $(1)/www/luci-static/kucat/

	# 复制主题配置脚本
	$(CP) $(PKG_BUILD_DIR)/root/etc/uci-defaults/99_luci-theme-kucat $(1)/etc/uci-defaults/
endef

# 确保没有自定义编译步骤覆盖默认规则
# 不要添加Build/Compile部分，使用luci.mk提供的默认编译规则
    
