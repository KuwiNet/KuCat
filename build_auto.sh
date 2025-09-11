#!/bin/bash
set -e

echo "🚀 Starting LuCI Theme Kucat Build Process..."

# -------------------------------
# Step 1: 获取版本号
# -------------------------------
get_version() {
  local makefile="luci-theme-kucat/Makefile"
  if [ ! -f "$makefile" ]; then
    echo "❌ Error: $makefile not found!" >&2
    exit 1
  fi
  awk -F'[ =]+' '/^PKG_VERSION:/ {print $2; exit}' "$makefile" | xargs
}

PKG_VERSION=$(get_version)
BUILD_DATE="r$(date +%Y%m%d)"
FULL_VERSION="${PKG_VERSION}-${BUILD_DATE}"
echo "📦 PKG_VERSION: $PKG_VERSION"
echo "📅 Build Date:  $BUILD_DATE"
echo "✅ Full Version: $FULL_VERSION"

# -------------------------------
# Step 2: 配置 SDK 和目录
# -------------------------------
SDK_URL="https://downloads.openwrt.org/releases/23.05.2/targets/x86/64/openwrt-sdk-23.05.2-x86-64_gcc-12.3.0_musl.Linux-x86_64.tar.xz"
SDK_DIR="openwrt-sdk-x86_64"
OUTPUT_DIR="bin/all-archs"
CSS_DIR="temp_css"
TEMP_DIR="temp_ipk"

mkdir -p "$OUTPUT_DIR" "$CSS_DIR" "$TEMP_DIR"

# -------------------------------
# Step 3: 下载并解压 SDK
# -------------------------------
if [ ! -d "$SDK_DIR" ]; then
  echo "📥 Downloading OpenWrt SDK..."
  wget -qO- "$SDK_URL" | tar -xJ
  mv openwrt-sdk-*-* "$SDK_DIR" || true
  if [ ! -d "$SDK_DIR" ]; then
    echo "❌ Failed to extract SDK" >&2
    exit 1
  fi
fi

# -------------------------------
# Step 4: 复制主题并准备编译
# -------------------------------
echo "📁 Copying luci-theme-kucat into SDK..."
cp -r luci-theme-kucat "$SDK_DIR/package/"

cd "$SDK_DIR"

# 更新 feeds
echo "🔄 Updating feeds..."
./scripts/feeds update -a
./scripts/feeds install -a

# 构建
echo "⚙️ Compiling luci-theme-kucat..."
make defconfig
make package/luci-theme-kucat/compile V=s

# 返回根目录
cd ..

# -------------------------------
# Step 5: 查找生成的 .ipk
# -------------------------------
IPK_SRC=$(find "$SDK_DIR/bin/packages" -path '*/luci-theme-kucat_${PKG_VERSION}*.ipk' | head -n1)
if [ -z "$IPK_SRC" ]; then
  echo "❌ Error: No .ipk file generated in bin/packages/" >&2
  find "$SDK_DIR/bin/packages" -name "*.ipk" || true
  exit 1
fi
echo "✅ Found compiled IPK: $IPK_SRC"

# -------------------------------
# Step 6: 下载未压缩的 CSS 文件
# -------------------------------
echo "🎨 Downloading unminified CSS files..."
REPO_BASE="https://raw.githubusercontent.com/KuwiNet/KuCat/js/luci-theme-kucat/htdocs/luci-static/kucat/css"

curl -fsSL "$REPO_BASE/theme.css" -o "$CSS_DIR/theme.css"
curl -fsSL "$REPO_BASE/style.css" -o "$CSS_DIR/style.css"

echo "📄 Downloaded CSS files:"
ls -lh "$CSS_DIR/"

# -------------------------------
# Step 7: 解包 -> 替换 CSS -> 重新打包
# -------------------------------
repack_ipk() {
  local src_ipk="$1"
  local output_ipk="$2"

  echo "🔧 Repacking: $src_ipk -> $output_ipk"

  # 创建临时目录
  local tmpdir=$(mktemp -d -p "$TEMP_DIR" 2>/dev/null || mktemp -d)
  cd "$tmpdir"

  # 解包 .ipk (ar 格式)
  ar x "$src_ipk"
  tar -xzf data.tar.gz
  tar -xzf control.tar.gz

  # 替换 CSS
  mkdir -p htdocs/luci-static/kucat/css
  cp "$CSS_DIR"/*.css htdocs/luci-static/kucat/css/

  # 重新打包 data.tar.gz
  tar -czf data.tar.gz htdocs --owner=0 --group=0

  # 重新打包 .ipk
  ar r "$output_ipk" debian-binary control.tar.gz data.tar.gz

  cd - > /dev/null
  rm -rf "$tmpdir"
  echo "✅ Repacked: $output_ipk"
}

# 执行重打包
FINAL_IPK="$OUTPUT_DIR/luci-theme-kucat_${FULL_VERSION}_x86_64.ipk"
repack_ipk "$IPK_SRC" "$FINAL_IPK"

# 可选：创建通用 all 包
cp "$FINAL_IPK" "$OUTPUT_DIR/luci-theme-kucat_${FULL_VERSION}_all.ipk" 2>/dev/null || true

# -------------------------------
# Step 8: 显示结果
# -------------------------------
echo "🎉 Build Complete! Artifacts:"
ls -lh "$OUTPUT_DIR/"

echo "💡 You can now upload these files or create a release."
