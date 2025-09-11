#!/bin/bash
set -e

echo "🚀 构建 LuCI 主题 Kucat (all 架构专用版)"

# -------------------------------
# Step 1: 提取版本号
# -------------------------------
if [ ! -f "luci-theme-kucat/Makefile" ]; then
  echo "❌ 错误：找不到 luci-theme-kucat/Makefile" >&2
  exit 1
fi

PKG_VERSION=$(awk -F'[ =]+' '/^PKG_VERSION:/ {print $2; exit}' luci-theme-kucat/Makefile | xargs)
if [ -z "$PKG_VERSION" ]; then
  echo "❌ 错误：无法从 Makefile 中提取 PKG_VERSION" >&2
  exit 1
fi

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
TEMP_DIR="temp_repack"

mkdir -p "$OUTPUT_DIR" "$CSS_DIR" "$TEMP_DIR"

# -------------------------------
# Step 3: 下载 SDK（若未存在）
# -------------------------------
if [ ! -d "$SDK_DIR" ]; then
  echo "📥 下载 OpenWrt SDK..."
  wget -qO- "$SDK_URL" | tar -xJ
  mv openwrt-sdk-* "$SDK_DIR" || true
fi

if [ ! -d "$SDK_DIR" ]; then
  echo "❌ 错误：SDK 目录创建失败" >&2
  exit 1
fi

# -------------------------------
# Step 4: 复制主题并编译（使用 make -C，不 cd）
# -------------------------------
echo "📁 复制主题到 SDK..."
rm -rf "$SDK_DIR/package/luci-theme-kucat" 2>/dev/null || true
cp -r luci-theme-kucat "$SDK_DIR/package/"

echo "🔄 更新 feeds..."
make -C "$SDK_DIR" defconfig

echo "⚙️ 编译中..."
make -C "$SDK_DIR" package/luci-theme-kucat/compile V=s

# -------------------------------
# Step 5: 查找生成的 .ipk 文件（使用绝对路径）
# -------------------------------
IPK_GLOB="$SDK_DIR/bin/packages/x86_64/base/luci-theme-kucat_${PKG_VERSION}_*.ipk"
IPK_ABS_SRC=$(ls $IPK_GLOB 2>/dev/null | head -n1)

if [ ! -f "$IPK_ABS_SRC" ]; then
  echo "❌ 错误：未找到 .ipk 文件！期望路径：" >&2
  echo "    $IPK_GLOB" >&2
  echo "🔍 实际存在的文件：" >&2
  find "$SDK_DIR/bin/packages" -type f -name "*.ipk" -ls 2>/dev/null || echo "无"
  exit 1
fi

echo "✅ 找到 IPK (绝对路径): $IPK_ABS_SRC"

# -------------------------------
# Step 6: 下载未压缩 CSS
# -------------------------------
echo "🎨 下载未压缩 CSS..."
REPO_BASE="https://raw.githubusercontent.com/KuwiNet/KuCat/js/luci-theme-kucat/htdocs/luci-static/kucat/css"

curl -fsSL "$REPO_BASE/theme.css" -o "$CSS_DIR/theme.css" && echo "   ✔ theme.css"
curl -fsSL "$REPO_BASE/style.css" -o "$CSS_DIR/style.css" && echo "   ✔ style.css"

if [ ! -f "$CSS_DIR/theme.css" ] || [ ! -f "$CSS_DIR/style.css" ]; then
  echo "❌ CSS 下载失败！请检查网络或 URL" >&2
  exit 1
fi

# -------------------------------
# Step 7: 重打包函数
# -------------------------------
repack_all_ipk() {
  local src_ipk="$1"
  local dst_ipk="$2"
  local tmpdir=$(mktemp -d --tmpdir="$TEMP_DIR" 2>/dev/null || mktemp -d)

  echo "🔧 解包原始 IPK: $src_ipk"
  cd "$tmpdir"

  # 解包 ar 归档
  ar x "$src_ipk" || { echo "❌ ar x 失败"; exit 1; }
  tar -xzf data.tar.gz || { echo "❌ 解包 data.tar.gz 失败"; exit 1; }
  tar -xzf control.tar.gz || { echo "❌ 解包 control.tar.gz 失败"; exit 1; }

  # 替换 CSS 文件
  mkdir -p htdocs/luci-static/kucat/css
  cp "$CSS_DIR"/*.css htdocs/luci-static/kucat/css/
  echo "✅ 已替换 CSS 文件"

  # 重新打包 data.tar.gz
  tar -czf data.tar.gz htdocs --owner=0 --group=0

  # 重新打包 .ipk
  ar r "$dst_ipk" debian-binary control.tar.gz data.tar.gz

  cd - > /dev/null
  rm -rf "$tmpdir"
  echo "✅ 重新打包完成: $dst_ipk"
}

# -------------------------------
# Step 8: 执行重打包
# -------------------------------
FINAL_IPK="$OUTPUT_DIR/luci-theme-kucat_${FULL_VERSION}_all.ipk"
repack_all_ipk "$IPK_ABS_SRC" "$FINAL_IPK"

# -------------------------------
# Step 9: 显示输出
# -------------------------------
echo "🎉 构建成功！最终文件："
ls -lh "$FINAL_IPK"

echo "💡 此 all 版本适用于所有 OpenWrt 设备。"
