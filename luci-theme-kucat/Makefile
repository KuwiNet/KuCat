#
# Copyright (C) 2019-2025 The Sirpdboy Team <herboy2008@gmail.com>    
#
# This is free software, licensed under the Apache License, Version 2.0 .
#

include $(TOPDIR)/rules.mk
THEME_NAME:=kucat
THEME_TITLE:=Kucat Theme
PKG_NAME:=luci-theme-$(THEME_NAME)
LUCI_TITLE:=Kucat Theme by KuwiNet
LUCI_DEPENDS:=
PKG_VERSION:=2.6.18

# 关键修改：禁用 CSS 压缩工具对 style.css 的处理
define Build/Prepare
	$(call Build/Prepare/Default)
	# 备份原始 style.css 到临时文件
	cp $(PKG_BUILD_DIR)/htdocs/luci-static/kucat/css/style.css $(PKG_BUILD_DIR)/htdocs/luci-static/kucat/css/style.css.orig
endef

define Build/Compile
	$(call Build/Compile/Default)
	# 用备份的原始文件覆盖可能被压缩的文件
	if [ -f $(PKG_BUILD_DIR)/htdocs/luci-static/kucat/css/style.css.orig ]; then \
		cp $(PKG_BUILD_DIR)/htdocs/luci-static/kucat/css/style.css.orig $(PKG_BUILD_DIR)/htdocs/luci-static/kucat/css/style.css; \
	fi
endef

# 确保打包时使用未压缩的文件
define Package/luci-theme-$(THEME_NAME)/install
	$(call Package/luci/install/templates,$(1))
	# 手动复制文件，跳过压缩步骤
	cp -r $(PKG_BUILD_DIR)/htdocs $(1)/www/
	cp -r $(PKG_BUILD_DIR)/ luasrc $(1)/
endef

define Package/luci-theme-$(THEME_NAME)/conffiles
/www/luci-static/resources/background/
/www/luci-static/kucat/img/
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
