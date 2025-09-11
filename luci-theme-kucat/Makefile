# 引入 OpenWRT 基础编译规则（必须放在开头，SDK 识别包的关键）
include $(TOPDIR)/rules.mk

# LuCI 主题元信息（适配 LuCI 编译系统）
LUCI_TITLE:=LuCI Theme - KuCat
LUCI_DESCRIPTION:=Modern & Clean Theme for OpenWRT LuCI (v2.6.8)
LUCI_DEPENDS:=+luci-base  # 仅依赖核心组件，避免冗余依赖
LUCI_PKGARCH:=all         # 通用架构，支持所有 OpenWRT 设备

# 包核心信息（统一维护版本和作者）
PKG_NAME:=luci-theme-kucat  # 包名必须与目录名完全一致
PKG_VERSION:=2.6.8          # 版本号（核心标识）
PKG_RELEASE:=1              # 发布版本（迭代用）
PKG_LICENSE:=Apache-2.0     # 开源许可证（可根据实际调整）
PKG_MAINTAINER:=KuwiNet     # 作者信息

# 引入 LuCI 专用编译规则（提供 compile/install 等目标，解决 No rule 错误）
include $(TOPDIR)/feeds/luci/luci.mk

# 安装逻辑（确保主题文件部署到 OpenWRT 标准路径）
define Package/luci-theme-kucat/install
	# 1. 创建主题所需目录（严格匹配 LuCI 路径规范）
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/themes/kucat  # 模板文件目录
	$(INSTALL_DIR) $(1)/www/luci-static/kucat/{css,js,fonts,img}  # 静态资源目录
	$(INSTALL_DIR) $(1)/etc/uci-defaults  # 主题初始化脚本目录

	# 2. 复制模板文件（.htm 等 LuCI 页面模板）
	$(CP) $(PKG_BUILD_DIR)/view/themes/kucat/* $(1)/usr/lib/lua/luci/view/themes/kucat/

	# 3. 复制静态资源（CSS/JS/字体/图片，确保主题样式生效）
	$(CP) $(PKG_BUILD_DIR)/www/luci-static/kucat/css/* $(1)/www/luci-static/kucat/css/
	$(CP) $(PKG_BUILD_DIR)/www/luci-static/kucat/js/* $(1)/www/luci-static/kucat/js/
	$(CP) $(PKG_BUILD_DIR)/www/luci-static/kucat/fonts/* $(1)/www/luci-static/kucat/fonts/
	$(CP) $(PKG_BUILD_DIR)/www/luci-static/kucat/img/* $(1)/www/luci-static/kucat/img/

	# 4. 复制初始化脚本（自动注册主题到 LuCI，无需手动配置）
	$(CP) $(PKG_BUILD_DIR)/root/etc/uci-defaults/30_luci-kucat $(1)/etc/uci-defaults/
endef

# 构建前预处理（可选，确保源码目录结构正确）
define Build/Prepare
	# 创建构建目录（避免源码目录污染）
	mkdir -p $(PKG_BUILD_DIR)
	# 复制项目源码到构建目录（适配 SDK 编译流程）
	$(CP) ./view $(PKG_BUILD_DIR)/
	$(CP) ./www $(PKG_BUILD_DIR)/
	$(CP) ./root $(PKG_BUILD_DIR)/
endef
