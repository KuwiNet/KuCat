#!/bin/bash
set -euo pipefail

echo "? 构建 LuCI 主题 Kucat (all 架构专用版)"

# -------------------------------
# 初始化检查
# -------------------------------
REQUIRED_CMDS=(wget curl tar ar gzip awk date mkdir cp)
for cmd in "${REQUIRED_CMDS[@]}"; do
  if ! command -v "$cmd" >/dev/null; then
    echo "❌ 必需命令缺失: $cmd" >&2
    exit 1
  fi
done

# -------------------------------
# Step 1: 提取版本号 (增强版)
# -------------------------------
if [ ! -f "luci-theme-kucat/Makefile" ]; then
  echo "❌ 错误：找不到 luci-theme-kucat/Makefile" >&2
  exit 1
fi

PKG_VERSION=$(
  awk -F'[ =]+' '/^PKG_VERSION:/ {
    gsub(/[^0-9.]/, "", $2); 
    print $2; exit
  }' luci-theme-kucat/Makefile
)

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
# Step 2: 配置路径 (添加存在性检查)
# -------------------------------
SDK_URL="https://downloads.openwrt.org/releases/23.05.2/targets/x86/64/openwrt-sdk-23.05.2-x86-64_gcc-12.3.0_musl.Linux-x86_64.tar.xz"
SDK_DIR="openwrt-sdk"
OUTPUT_DIR="bin/all-archs"
CSS_DIR="temp_css"
TEMP_DIR="temp_repack"

mkdir -p "$OUTPUT_DIR" || { echo "❌ 无法创建输出目录"; exit 1; }
mkdir -p "$CSS_DIR" "$TEMP_DIR" || { echo "❌ 无法创建临时目录"; exit 1; }

# -------------------------------
# Step 3: 下载 SDK
# -------------------------------
if [ ! -d "$SDK_DIR" ]; then
  echo "? 下载 OpenWrt SDK..."
  if ! wget -qO- "$SDK_URL" | tar -xJ; then
    echo "❌ SDK 下载或解压失败" >&2
    exit 1
  fi
  mv openwrt-sdk-* "$SDK_DIR" 2>/dev/null || true
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
cp -r luci-theme-kucat "$SDK_DIR/package/" || { echo "❌ 主题复制失败"; exit 1; }

cd "$SDK_DIR"

echo "? 更新 feeds..."
./scripts/feeds update -i || { echo "❌ feeds 更新失败"; exit 1; }
./scripts/feeds update luci || { echo "❌ luci feed 更新失败"; exit 1; }

echo "? 安装最小依赖: luci-base"
./scripts/feeds install -p luci luci-base || { echo "❌ 依赖安装失败"; exit 1; }

make defconfig || { echo "❌ 配置失败"; exit 1; }

cd - > /dev/null

echo "✅ 最小依赖安装完成"

# -------------------------------
# Step 5: 编译主题
# -------------------------------
echo "⚙️ 开始编译..."
make -C "$SDK_DIR" package/luci-theme-kucat/compile V=s || { echo "❌ 编译失败"; exit 1; }

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
# Step 7: 下载未压缩 CSS (容错改进版)
# -------------------------------
echo "? 下载未压缩 CSS..."
REPO_BASE="https://raw.githubusercontent.com/KuwiNet/KuCat/js/luci-theme-kucat/htdocs/luci-static/kucat/css"

CSS_FILES=(theme.css style.css)
for css in "${CSS_FILES[@]}"; do
  if ! curl -fsSL "$REPO_BASE/$css" -o "$CSS_DIR/$css"; then
    echo "⚠️ 警告: 无法下载 $css，尝试使用本地版本" >&2
    [ -f "luci-theme-kucat/htdocs/luci-static/kucat/css/$css" ] && \
      cp "luci-theme-kucat/htdocs/luci-static/kucat/css/$css" "$CSS_DIR/"
  fi
  [ -f "$CSS_DIR/$css" ] && echo "   ✔ $css" || echo "   ❌ $css"
done

if [ ! -f "$CSS_DIR/theme.css" ] || [ ! -f "$CSS_DIR/style.css" ]; then
  echo "❌ CSS 文件缺失" >&2
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
  cd "$tmpdir" || exit 1

  # 尝试使用bsdtar解包
  if command -v bsdtar >/dev/null; then
    echo "ℹ️ 使用bsdtar解包..."
    bsdtar -xf "$src_ipk" || { echo "❌ bsdtar解包失败"; exit 1; }
  else
    # 回退到ar解包
    ar x "$src_ipk" || { echo "❌ ar解包失败"; exit 1; }
  fi

  # 解压内部文件
  tar -xzf data.tar.gz || { echo "❌ 解包data.tar.gz失败"; exit 1; }
  tar -xzf control.tar.gz || { echo "❌ 解包control.tar.gz失败"; exit 1; }

  # 替换CSS文件
  mkdir -p htdocs/luci-static/kucat/css
  cp "$CSS_DIR"/*.css htdocs/luci-static/kucat/css/
  echo "✅ 已替换CSS文件"

  # 重新打包为符合规范的IPK
  echo "2.0" > debian-binary
  gzip -9nc control.tar > control.tar.gz || exit 1
  gzip -9nc data.tar > data.tar.gz || exit 1
  
  # 使用ar创建标准格式的IPK
  ar cr "$dst_ipk" \
    debian-binary \
    control.tar.gz \
    data.tar.gz 2>/dev/null || {
      echo "❌ ar打包失败" >&2
      exit 1
    }

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

# -------------------------------
# 清理函数
# -------------------------------
cleanup() {
  echo "? 清理临时文件..."
  rm -rf "$CSS_DIR" "$TEMP_DIR" 2>/dev/null
}
trap cleanup EXIT
