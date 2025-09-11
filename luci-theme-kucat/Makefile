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
PKG_VERSION:=2.6.18

# 新增：排除 style.css 压缩
define Build/Compile
	# 调用默认编译规则
	$(call Build/Compile/Default)
	
	# 还原被压缩的 style.css（如果存在）
	if [ -f $(PKG_BUILD_DIR)/htdocs/luci-static/kucat/css/style.css ]; then \
		cp $(PKG_BUILD_DIR)/htdocs/luci-static/kucat/css/style.css $(PKG_BUILD_DIR)/htdocs/luci-static/kucat/css/style.css.orig; \
		mv $(PKG_BUILD_DIR)/htdocs/luci-static/kucat/css/style.css.orig $(PKG_BUILD_DIR)/htdocs/luci-static/kucat/css/style.css; \
	fi
endef

define Package/luci-theme-$(THEME_NAME)/conffiles
/www/luci-static/resources/background/
/www/luci-static/kucat/img/
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
