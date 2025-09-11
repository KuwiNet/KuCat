#!/bin/bash
set -e

echo "🚀 构建 LuCI 主题 Kucat (all 架构专用版)"

# -------------------------------
# Step 1: 提取版本号
# -------------------------------
PKG_VERSION=$(awk -F'[ =]+' '/^PKG_VERSION:/ {print $2; exit}' luci-theme-kucat/Makefile | xargs)
BUILD_DATE="r$(date +%Y%m%d)"
FULL_VERSION="${PKG_VERSION}-${BUILD_DATE}"

echo "📦 版本: $PKG_VERSION"
echo "📅 构建日期: $BUILD_DATE"
echo "✅ 完整版本: $FULL_VERSION"

# -------------------------------
# Step 2: 配置路径
# -------------------------------
SDK_URL="https://downloads.openwrt.org/releases/23.05.2/targets/x86/64/openwrt-sdk-23.05.2-x86-64_gcc-12.3.0_musl.Linux-x86_64.tar.xz"
SDK_DIR="openwrt-sdk"
OUTPUT_DIR="bin/all-archs"
CSS_DIR="temp_css"

mkdir -p "$OUTPUT_DIR" "$CSS_DIR"

# -------------------------------
# Step 3: 下载 SDK（若未存在）
# -------------------------------
if [ ! -d "$SDK_DIR" ]; then
  echo "📥 下载 OpenWrt SDK..."
  wget -qO- "$SDK_URL" | tar -xJ
  mv openwrt-sdk-* "$SDK_DIR" || true
fi

# -------------------------------
# Step 4: 复制主题并编译
# -------------------------------
echo "📁 复制主题到 SDK..."
cp -r luci-theme-kucat "$SDK_DIR/package/"

cd "$SDK_DIR"

echo "🔄 更新 feeds..."
./scripts/feeds update -a
./scripts/feeds install -a

echo "⚙️ 编译中..."
make defconfig
make package/luci-theme-kucat/compile V=s

# -------------------------------
# Step 5: 查找生成的 .ipk
# -------------------------------
IPK_SRC=$(find bin/packages -name "luci-theme-kucat_${PKG_VERSION}*.ipk" | head -n1)
if [ -z "$IPK_SRC" ]; then
  echo "❌ 错误：未生成 .ipk 文件！" >&2
  exit 1
fi
echo "✅ 找到 IPK: $IPK_SRC"

# -------------------------------
# Step 6: 下载未压缩 CSS
# -------------------------------
echo "🎨 下载未压缩 CSS..."
REPO_BASE="https://raw.githubusercontent.com/KuwiNet/KuCat/js/luci-theme-kucat/htdocs/luci-static/kucat/css"
curl -fsSL "$REPO_BASE/theme.css" -o "../$CSS_DIR/theme.css"
curl -fsSL "$REPO_BASE/style.css" -o "../$CSS_DIR/style.css"

# -------------------------------
# Step 7: 重打包为 all 架构
# -------------------------------
repack_all_ipk() {
  local src_ipk="$1"
  local dst_ipk="$2"
  local tmpdir=$(mktemp -d)

  cd "$tmpdir"
  ar x "$src_ipk"
  tar -xzf data.tar.gz
  tar -xzf control.tar.gz

  # 替换 CSS
  mkdir -p htdocs/luci-static/kucat/css
  cp "../$CSS_DIR"/*.css htdocs/luci-static/kucat/css/

  # 重新打包
  tar -czf data.tar.gz htdocs --owner=0 --group=0
  ar r "$dst_ipk" debian-binary control.tar.gz data.tar.gz

  cd - > /dev/null
  rm -rf "$tmpdir"
  echo "✅ 已生成: $dst_ipk"
}

FINAL_IPK="$OUTPUT_DIR/luci-theme-kucat_${FULL_VERSION}_all.ipk"
repack_all_ipk "$IPK_SRC" "$FINAL_IPK"

# -------------------------------
# Step 8: 完成
# -------------------------------
echo "🎉 构建完成！输出文件："
ls -lh "$OUTPUT_DIR/"

echo "💡 此 all 版本适用于所有 OpenWrt 设备。"
