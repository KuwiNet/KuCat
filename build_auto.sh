#!/bin/bash
set -e

echo "? 构建 LuCI 主题 Kucat (all 架构专用版)"

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

echo "? 版本: $PKG_VERSION"
echo "? 构建日期: $BUILD_DATE"
echo "✅ 完整版本: $FULL_VERSION"

# -------------------------------
# Step 2: 配置路径
# -------------------------------
SDK_URL="https://downloads.openwrt.org/releases/23.05.2/targets/x86/64/openwrt-sdk-23.05.2-x86-64_gcc-12.3.0_musl.Linux-x86_64.tar.xz"
SDK_DIR="openwrt-sdk"
OUTPUT_DIR="bin/all-archs"
CSS_DIR="temp_css"
TEMP_DIR="temp_repack"

mkdir -p "$OUTPUT_DIR" "$CSS_DIR" "$TEMP_DIR"

# -------------------------------
# Step 3: 下载 SDK
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
# Step 4: 复制主题 + 安装最小依赖
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
# Step 5: 编译主题
# -------------------------------
echo "⚙️ 开始编译..."
make -C "$SDK_DIR" package/luci-theme-kucat/compile V=s

# -------------------------------
# Step 6: 查找 .ipk 并解析真实路径
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

# 验证原始 IPK 格式
if ! ar t "$IPK_REAL_SRC" >/dev/null 2>&1; then
  echo "❌ 原始 IPK 文件格式错误" >&2
  exit 1
fi

# -------------------------------
# Step 7: 下载未压缩 CSS
# -------------------------------
echo "? 下载未压缩 CSS..."
REPO_BASE="https://raw.githubusercontent.com/KuwiNet/KuCat/js/luci-theme-kucat/htdocs/luci-static/kucat/css"

mkdir -p "$CSS_DIR"
curl -fsSL "$REPO_BASE/theme.css" -o "$CSS_DIR/theme.css" && echo "   ✔ theme.css"
curl -fsSL "$REPO_BASE/style.css" -o "$CSS_DIR/style.css" && echo "   ✔ style.css"

if [ ! -f "$CSS_DIR/theme.css" ] || [ ! -f "$CSS_DIR/style.css" ]; then
  echo "❌ CSS 下载失败" >&2
  exit 1
fi

# -------------------------------
# Step 8: 改进的重打包函数
# -------------------------------
repack_all_ipk() {
  local src_ipk="$1"
  local dst_ipk="$2"
  local tmpdir=$(mktemp -d --tmpdir="$TEMP_DIR" 2>/dev/null || mktemp -d)

  echo "? 解包原始 IPK: $src_ipk"
  cd "$tmpdir"

  # 尝试使用 ar 解包，失败则使用 bsdtar
  if ! ar x "$src_ipk"; then
    echo "ℹ️ 使用 bsdtar 解包..."
    if ! bsdtar -xf "$src_ipk"; then
      echo "❌ 解包失败：文件格式错误或损坏" >&2
      exit 1
    fi
  fi

  # 解压内部文件
  tar -xzf data.tar.gz || { echo "❌ 解包 data.tar.gz 失败" >&2; exit 1; }
  tar -xzf control.tar.gz || { echo "❌ 解包 control.tar.gz 失败" >&2; exit 1; }

  # 替换 CSS 文件
  mkdir -p htdocs/luci-static/kucat/css
  cp "$CSS_DIR"/*.css htdocs/luci-static/kucat/css/
  echo "✅ 已替换 CSS 文件"

  # 重新打包为符合规范的 IPK
  echo "2.0" > debian-binary
  gzip -9nc control.tar > control.tar.gz
  gzip -9nc data.tar > data.tar.gz
  
  # 使用 ar 创建标准格式的 IPK
  ar cr "$dst_ipk" \
    debian-binary \
    control.tar.gz \
    data.tar.gz

  cd - > /dev/null
  rm -rf "$tmpdir"
  echo "✅ 重新打包完成: $dst_ipk"
}

# -------------------------------
# Step 9: 执行重打包
# -------------------------------
FINAL_IPK="$OUTPUT_DIR/luci-theme-kucat_${FULL_VERSION}_all.ipk"
repack_all_ipk "$IPK_REAL_SRC" "$FINAL_IPK"

# -------------------------------
# Step 10: 验证生成的 IPK
# -------------------------------
echo "? 验证生成的 IPK 文件格式..."
if ! ar t "$FINAL_IPK" >/dev/null 2>&1; then
  echo "❌ 生成的 IPK 文件格式不正确" >&2
  exit 1
fi

# -------------------------------
# Step 11: 显示结果
# -------------------------------
echo "? 构建成功！最终文件："
ls -lh "$FINAL_IPK"

# 导出版本号（用于 GitHub Release）
echo "RELEASE_TAG=luci-theme-kucat-${FULL_VERSION}" >> $GITHUB_ENV
