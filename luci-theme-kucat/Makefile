# 引入 OpenWrt 基础编译规则（必须放在开头）
include $(TOPDIR)/rules.mk

# LuCI 主题核心元信息（适配 LuCI 框架识别）
LUCI_TITLE:=LuCI Theme - KuCat  # 主题名称（显示在 LuCI 包管理中）
LUCI_DESCRIPTION:=Modern & Clean Theme for LuCI, Based on Argon/OpenTopd  # 主题描述
LUCI_DEPENDS:=+luci-base +luci-lib-jsonc  # 最小依赖（LuCI 基础组件，确保编译不缺依赖）
LUCI_PKGARCH:=all  # 主题与架构无关，固定为 all（适配所有设备）

# 包基本信息（符合 OpenWrt 包规范）
PKG_NAME:=luci-theme-kucat  # 包名（必须与目录名一致）
PKG_VERSION:=2.6.8  # 版本号（可按需升级）
PKG_RELEASE:=1  # 发布版本（每次修改可+1）
PKG_LICENSE:=Apache-2.0  # 许可证（与主题头部注释一致）
PKG_MAINTAINER:=KuwiNet Team <dev@kuwinet.com>  # 维护者信息（可替换为实际信息）

# 引入 LuCI 编译核心规则（关键：提供 compile/install 目标，解决 No rule 错误）
include $(TOPDIR)/feeds/luci/luci.mk

# 主题文件安装逻辑（确保所有资源完整复制，不压缩/修改）
define Package/luci-theme-kucat/install
	# 1. 创建目标目录（确保子目录结构与主题资源匹配）
	$(INSTALL_DIR) $(1)/www/luci-static/kucat/{css,fonts,js,img}  # 静态资源目录
	$(INSTALL_DIR) $(1)/etc/uci-defaults  # 主题配置脚本目录

	# 2. 复制 CSS/字体/JS/图片等静态资源（保留原始内容，含注释和 @font-face）
	$(CP) $(PKG_BUILD_DIR)/htdocs/luci-static/kucat/css/* $(1)/www/luci-static/kucat/css/
	$(CP) $(PKG_BUILD_DIR)/htdocs/luci-static/kucat/fonts/* $(1)/www/luci-static/kucat/fonts/
	$(CP) $(PKG_BUILD_DIR)/htdocs/luci-static/kucat/js/* $(1)/www/luci-static/kucat/js/
	$(CP) $(PKG_BUILD_DIR)/htdocs/luci-static/kucat/img/* $(1)/www/luci-static/kucat/img/
	$(CP) $(PKG_BUILD_DIR)/htdocs/luci-static/kucat/favicon.ico $(1)/www/luci-static/kucat/  # 图标（如有）

	# 3. 复制主题配置脚本（修复后的 30_luci-kucat，确保主题注册生效）
	$(CP) $(PKG_BUILD_DIR)/root/etc/uci-defaults/30_luci-kucat $(1)/etc/uci-defaults/
endef

# 禁止自定义 Build/Compile 阶段（使用 LuCI 默认规则，避免覆盖编译逻辑）
# 无需添加任何 Build/Compile 块，防止干扰默认编译流程
