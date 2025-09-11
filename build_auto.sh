#!/bin/bash
set -e

echo "📦 构建 LuCI 主题 Kucat (all 架构专用版)"

# -------------------------------
# Step 1: 提取版本号
# -------------------------------
if [ ! -f "luci-theme-kucat/Makefile" ]; then
  echo "❌ 错误：找不到 luci-theme-kucat/Makefile" >&2
  exit 1
fi

PKG_VERSION=$(awk -F'[ =]+' '/^PKG_VERSION:/ {print $2; exit}' luci-theme-kucat/Makefile | xargs)
if [ -z "$PKG_VERSION" ]; then
  echo "❌ 错误：无法提取 PKG_VERSION" >&2
  exit 1
fi

BUILD_DATE="r$(date +%Y%m%d)"
FULL_VERSION="${PKG_VERSION}-${BUILD_DATE}"

echo "🔖 版本: $PKG_VERSION"
echo "📅 构建日期: $BUILD_DATE"
echo "✅ 完整版本: $FULL_VERSION"

# -------------------------------
# Step 2: 配置路径
# -------------------------------
SDK_URL="https://downloads.openwrt.org/releases/23.05.2/targets/x86/64/openwrt-sdk-23.05.2-x86-64_gcc-12.3.0_musl.Linux-x86_64.tar.xz"
SDK_DIR="openwrt-sdk"
# 直接使用SDK的输出目录作为最终输出目录
OUTPUT_DIR="$SDK_DIR/bin/packages/x86_64/base"

# -------------------------------
# Step 3: 下载 SDK
# -------------------------------
if [ ! -d "$SDK_DIR" ]; then
  echo "⬇️ 下载 OpenWrt SDK..."
  wget -qO- "$SDK_URL" | tar -xJ
  mv openwrt-sdk-* "$SDK_DIR" || true
fi

if [ ! -d "$SDK_DIR" ]; then
  echo "❌ 错误：SDK 目录缺失" >&2
  exit 1
fi

# -------------------------------
# Step 4: 复制主题 + 安装最小依赖
# -------------------------------
echo "📂 复制主题到 SDK..."
rm -rf "$SDK_DIR/package/luci-theme-kucat" 2>/dev/null || true
cp -r luci-theme-kucat "$SDK_DIR/package/"

cd "$SDK_DIR"

echo "🔄 更新 feeds..."
./scripts/feeds update -i
./scripts/feeds update luci

echo "📦 安装最小依赖: luci-base"
./scripts/feeds install -p luci luci-base

make defconfig

cd - > /dev/null

echo "✅ 最小依赖安装完成"

# -------------------------------
# Step 5: 编译主题
# -------------------------------
echo "⚙️ 开始编译..."
make -C "$SDK_DIR" package/luci-theme-kucat/compile V=s

# -------------------------------
# Step 6: 查找并验证编译生成的 IPK
# -------------------------------
# 匹配 SDK 编译输出的 IPK 路径
IPK_GLOB="$OUTPUT_DIR/luci-theme-kucat_${PKG_VERSION}_*.ipk"
IPK_REAL_SRC=$(ls $IPK_GLOB 2>/dev/null | head -n1 | xargs realpath 2>/dev/null)

if [ ! -f "$IPK_REAL_SRC" ]; then
  echo "❌ 错误：未找到编译生成的 .ipk 文件！期望路径格式：" >&2
  echo "    $IPK_GLOB" >&2
  # 辅助排查：列出所有可能的 IPK 文件
  echo "当前 SDK 输出目录下的 IPK 文件："
  find "$SDK_DIR/bin/packages" -type f -name "luci-theme-kucat_*.ipk" -ls 2>/dev/null || echo "无"
  exit 1
fi

echo "✅ 找到编译生成的 IPK: $IPK_REAL_SRC"

# 验证 IPK 文件格式有效性
echo "🔍 验证 IPK 文件格式..."
if ! ar t "$IPK_REAL_SRC" >/dev/null 2>&1; then
  echo "⚠️ ar 工具验证失败，尝试使用 bsdtar 二次验证..."
  if command -v bsdtar >/dev/null; then
    if ! bsdtar -tf "$IPK_REAL_SRC" >/dev/null; then
      echo "❌ IPK 文件损坏或格式不正确"
      echo "文件信息: $(file "$IPK_REAL_SRC")"
      echo "文件大小: $(du -h "$IPK_REAL_SRC")"
      exit 1
    else
      echo "✅ bsdtar 验证通过（IPK 格式有效）"
    fi
  else
    echo "❌ 请安装 libarchive-tools 以验证 IPK：sudo apt-get install libarchive-tools"
    exit 1
  fi
else
  echo "✅ ar 验证通过（IPK 格式有效）"
fi

# -------------------------------
# Step 7: 显示构建结果
# -------------------------------
echo -e "\n🎉 构建成功！最终文件信息："
ls -lh "$IPK_REAL_SRC"
echo "📁 输出路径：$IPK_REAL_SRC"

# 导出版本号到 GitHub 环境变量
echo "RELEASE_TAG=luci-theme-kucat-${FULL_VERSION}" >> $GITHUB_ENV
echo "IPK_PATH=$IPK_REAL_SRC" >> $GITHUB_ENV  # 导出IPK路径方便后续处理

# -------------------------------
# 清理函数（可选）
# -------------------------------
cleanup() {
  echo -e "\n🧹 清理临时文件..."
  # 可选：清理SDK编译缓存
  # make -C "$SDK_DIR" package/luci-theme-kucat/clean >/dev/null 2>&1
  echo "✅ 清理完成"
}
trap cleanup EXIT
