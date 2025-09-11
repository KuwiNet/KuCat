#!/bin/bash
set -e

echo "🚀 Starting build process..."

# -------------------------------
# Step 1: 获取版本号
# -------------------------------
get_pkg_version() {
  local makefile="luci-theme-kucat/Makefile"
  if [ ! -f "$makefile" ]; then
    echo "❌ Error: $makefile not found!" >&2
    exit 1
  fi
  # 支持 PKG_VERSION:= 或 PKG_VERSION =
  awk -F'[ =]+' '/^PKG_VERSION:/ {print $2; exit}' "$makefile" | xargs
}

PKG_VERSION=$(get_pkg_version)
BUILD_DATE="r$(date +%Y%m%d)"
FULL_VERSION="${PKG_VERSION}-${BUILD_DATE}"
echo "📦 PKG_VERSION: $PKG_VERSION"
echo "📅 Build Date:  $BUILD_DATE"
echo "✅ Full Version: $FULL_VERSION"

# -------------------------------
# Step 2: 模拟编译（实际应替换为 SDK 构建）
# -------------------------------
# 🔁 实际使用时，请替换为真实的 SDK 编译命令
# 示例：
# cd sdk-x86_64 && make package/luci-theme-kucat/compile V=s && cd ..

# 这里我们模拟生成 .ipk 文件（仅用于演示）
# 你可以删除这部分，换成真实构建逻辑

mkdir -p sdk-x86_64/bin/packages/all/luci
mkdir -p sdk-rockchip/bin/packages/aarch64_cortex-a53/base
mkdir -p sdk-mediatek/bin/packages/aarch64_cortex-a53/base

# 创建空的 .ipk 文件作为占位符（真实情况是编译生成）
touch "sdk-x86_64/bin/packages/all/luci/luci-theme-kucat_${FULL_VERSION}_all.ipk"
touch "sdk-rockchip/bin/packages/aarch64_cortex-a53/base/luci-theme-kucat_${FULL_VERSION}_all.ipk"
touch "sdk-mediatek/bin/packages/aarch64_cortex-a53/base/luci-theme-kucat_${FULL_VERSION}_all.ipk"

echo "✅ Simulated build completed (replace with real SDK build)"

# -------------------------------
# Step 3: 下载未压缩的 CSS 文件
# -------------------------------
echo "🎨 Downloading unminified CSS files..."
mkdir -p temp_css
REPO_BASE="https://raw.githubusercontent.com/KuwiNet/KuCat/js/luci-theme-kucat/htdocs/luci-static/kucat/css"
curl -fsSL "$REPO_BASE/theme.css" -o temp_css/theme.css
curl -fsSL "$REPO_BASE/style.css" -o temp_css/style.css

# -------------------------------
# Step 4: 替换 .ipk 中的 CSS 文件（解包 → 替换 → 重新打包）
# -------------------------------
REPACK_IPK() {
  local src_ipk="$1"
  local arch="$2"
  local output_dir="bin/all-archs"

  if [ ! -f "$src_ipk" ]; then
    echo "⚠️  Skipping: $src_ipk not found"
    return 0
  fi

  echo "🔧 Repacking for $arch: $src_ipk"

  # 创建临时目录
  local tmpdir=$(mktemp -d)
  cd "$tmpdir"

  # 解包 .ipk
  ar x "$src_ipk"
  tar -xzf data.tar.gz
  tar -xzf control.tar.gz

  # 替换 CSS
  mkdir -p htdocs/luci-static/kucat/css
  cp ../../temp_css/*.css htdocs/luci-static/kucat/css/

  # 重新打包 data.tar.gz
  tar -czf data.tar.gz htdocs --owner=0 --group=0

  # 重新打包 .ipk
  mkdir -p "$output_dir"
  ar r "$output_dir/luci-theme-kucat_${FULL_VERSION}_${arch}.ipk" debian-binary control.tar.gz data.tar.gz

  cd - > /dev/null
  rm -rf "$tmpdir"
  echo "✅ Built: $output_dir/luci-theme-kucat_${FULL_VERSION}_${arch}.ipk"
}

# 执行重打包
REPACK_IPK "sdk-x86_64/bin/packages/all/luci/luci-theme-kucat_${FULL_VERSION}_all.ipk" "x86_64"
REPACK_IPK "sdk-rockchip/bin/packages/aarch64_cortex-a53/base/luci-theme-kucat_${FULL_VERSION}_all.ipk" "rockchip"
REPACK_IPK "sdk-mediatek/bin/packages/aarch64_cortex-a53/base/luci-theme-kucat_${FULL_VERSION}_all.ipk" "mediatek"

# 可选：生成一个通用 all 架构包
cp "bin/all-archs/luci-theme-kucat_${FULL_VERSION}_x86_64.ipk" "bin/all-archs/luci-theme-kucat_${FULL_VERSION}_all.ipk" 2>/dev/null || true

# -------------------------------
# Step 5: 显示结果
# -------------------------------
echo "🎉 Build complete! Generated IPKs:"
ls -lh bin/all-archs/*.ipk
