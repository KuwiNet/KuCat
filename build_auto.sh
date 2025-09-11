#!/bin/bash
set -e

echo "? 构建 LuCI 主题 Kucat (all 架构专用版)"

# -------------------------------
# Step 1: 环境检查
# -------------------------------
echo "? 当前工作目录: $(pwd)"
echo "? 目录结构:"
ls -la

# -------------------------------
# Step 2: 提取版本号
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

echo "? 版本: $PKG_VERSION"
echo "? 构建日期: $BUILD_DATE"
echo "✅ 完整版本: $FULL_VERSION"

# -------------------------------
# Step 3: 配置路径（使用绝对路径）
# -------------------------------
WORKSPACE=$(pwd)
SDK_URL="https://downloads.openwrt.org/releases/23.05.2/targets/x86/64/openwrt-sdk-23.05.2-x86-64_gcc-12.3.0_musl.Linux-x86_64.tar.xz"
SDK_DIR="$WORKSPACE/openwrt-sdk"
OUTPUT_DIR="$WORKSPACE/bin/all-archs"
CSS_DIR="$WORKSPACE/temp_css"
TEMP_DIR="$WORKSPACE/temp_repack"

mkdir -p "$OUTPUT_DIR" "$CSS_DIR" "$TEMP_DIR"

# -------------------------------
# Step 4: 下载 SDK
# -------------------------------
if [ ! -d "$SDK_DIR" ]; then
  echo "? 下载 OpenWrt SDK..."
  wget -qO- "$SDK_URL" | tar -xJ
  mv openwrt-sdk-* "$SDK_DIR" || true
fi

if [ ! -d "$SDK_DIR" ]; then
  echo "❌ 错误：SDK 目录缺失" >&2
  exit 1
fi

# -------------------------------
# Step 5: 复制主题 + 安装最小依赖
# -------------------------------
echo "? 复制主题到 SDK..."
rm -rf "$SDK_DIR/package/luci-theme-kucat" 2>/dev/null || true
cp -r luci-theme-kucat "$SDK_DIR/package/"

cd "$SDK_DIR"

echo "? 更新 feeds..."
./scripts/feeds update -i
./scripts/feeds update luci

echo "? 安装最小依赖: luci-base"
./scripts/feeds install -p luci luci-base

make defconfig

cd - > /dev/null

echo "✅ 最小依赖安装完成"

# -------------------------------
# Step 6: 编译主题
# -------------------------------
echo "⚙️ 开始编译..."
make -C "$SDK_DIR" package/luci-theme-kucat/compile V=s

# -------------------------------
# Step 7: 查找 .ipk 并解析真实路径
# -------------------------------
IPK_GLOB="$SDK_DIR/bin/packages/x86_64/base/luci-theme-kucat_${PKG_VERSION}_*.ipk"
IPK_REL_SRC=$(ls $IPK_GLOB 2>/dev/null | head -n1)

if [ ! -f "$IPK_REL_SRC" ]; then
  echo "❌ 错误：未找到 .ipk 文件！期望：" >&2
  echo "    $IPK_GLOB" >&2
  find "$SDK_DIR/bin/packages" -type f -name "*.ipk" -ls 2>/dev/null || echo "无"
  exit 1
fi

IPK_REAL_SRC=$(realpath "$IPK_REL_SRC")
echo "✅ 找到 IPK (真实路径): $IPK_REAL_SRC"

# 调试信息
echo "? 文件详情:"
ls -la "$IPK_REAL_SRC"
if command -v file >/dev/null; then
  file "$IPK_REAL_SRC"
fi

# -------------------------------
# Step 8: 下载未压缩 CSS（增强版）
# -------------------------------
echo "? 下载未压缩 CSS..."
REPO_BASE="https://raw.githubusercontent.com/KuwiNet/KuCat/js/luci-theme-kucat/htdocs/luci-static/kucat/css"

# 清空并重建CSS目录
rm -rf "$CSS_DIR" 2>/dev/null || true
mkdir -p "$CSS_DIR"

curl -fsSL "$REPO_BASE/theme.css" -o "$CSS_DIR/theme.css" && echo "   ✔ theme.css"
curl -fsSL "$REPO_BASE/style.css" -o "$CSS_DIR/style.css" && echo "   ✔ style.css"

# 严格验证下载结果
if [ ! -f "$CSS_DIR/theme.css" ] || [ ! -f "$CSS_DIR/style.css" ]; then
  echo "❌ CSS 下载失败，当前目录: $(pwd)" >&2
  echo "❌ CSS 目录内容:" >&2
  ls -la "$CSS_DIR" >&2 || true
  exit 1
fi

echo "? 验证下载的CSS文件:"
ls -la "$CSS_DIR"
md5sum "$CSS_DIR"/*.css || true

# -------------------------------
# Step 9: 重打包函数（修复版）
# -------------------------------
repack_all_ipk() {
  local src_ipk="$1"
  local dst_ipk="$2"
  local tmpdir=$(mktemp -d --tmpdir="$TEMP_DIR" 2>/dev/null || mktemp -d)

  echo "? 解包原始 IPK: $src_ipk"
  echo "? 临时目录: $tmpdir"
  cd "$tmpdir"

  # 优先使用bsdtar解包
  if command -v bsdtar >/dev/null; then
    echo "ℹ️ 使用bsdtar解包..."
    bsdtar -xf "$src_ipk" || { echo "❌ bsdtar解包失败"; exit 1; }
  else
    echo "ℹ️ 使用ar解包..."
    ar x "$src_ipk" || { echo "❌ ar x 失败：文件格式错误或损坏"; exit 1; }
  fi

  tar -xzf data.tar.gz || { echo "❌ 解包 data.tar.gz 失败"; exit 1; }
  tar -xzf control.tar.gz || { echo "❌ 解包 control.tar.gz 失败"; exit 1; }

  # 修复CSS复制（使用绝对路径）
  echo "? 正在复制CSS文件..."
  echo "? 源CSS目录: $CSS_DIR"
  echo "? 目标CSS目录: $tmpdir/htdocs/luci-static/kucat/css"
  
  mkdir -p "$tmpdir/htdocs/luci-static/kucat/css"
  cp "$CSS_DIR/theme.css" "$CSS_DIR/style.css" "$tmpdir/htdocs/luci-static/kucat/css/"
  
  echo "✅ 已替换 CSS 文件"

  # 重新打包
  tar -czf data.tar.gz htdocs --owner=0 --group=0
  ar r "$dst_ipk" debian-binary control.tar.gz data.tar.gz

  cd - > /dev/null
  rm -rf "$tmpdir"
  echo "✅ 重新打包完成: $dst_ipk"
}

# -------------------------------
# Step 10: 执行重打包
# -------------------------------
FINAL_IPK="$OUTPUT_DIR/luci-theme-kucat_${FULL_VERSION}_all.ipk"
repack_all_ipk "$IPK_REAL_SRC" "$FINAL_IPK"

# -------------------------------
# Step 11: 显示结果
# -------------------------------
echo "? 构建成功！最终文件："
ls -lh "$FINAL_IPK"

# 导出版本号（用于 GitHub Release）
echo "RELEASE_TAG=luci-theme-kucat-${FULL_VERSION}" >> $GITHUB_ENV
