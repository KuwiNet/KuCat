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

# 关键修改：自定义安装规则，跳过style.css压缩
define Package/luci-theme-$(THEME_NAME)/install
	# 安装其他文件（沿用默认压缩规则）
	$(call Package/luci/install,$(1))
	
	# 强制覆盖已安装的压缩版style.css，使用原始文件
	# 确保路径与实际项目中style.css的位置一致
	cp $(PKG_BUILD_DIR)/htdocs/luci-static/kucat/css/style.css \
	   $(1)/www/luci-static/kucat/css/style.css
endef

define Package/luci-theme-$(THEME_NAME)/conffiles
/www/luci-static/resources/background/
/www/luci-static/kucat/img/
endef

include $(TOPDIR)/feeds/luci/luci.mk

# 禁用LuCI默认的资源压缩钩子
define Build/Compile
	$(call Build/Compile/Default)
endef

# call BuildPackage - OpenWrt buildroot signature
