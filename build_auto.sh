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

# 增强的 IPK 文件验证
echo "? 验证 IPK 文件格式..."
if ! ar t "$IPK_REAL_SRC" >/dev/null 2>&1; then
  echo "⚠️ ar 工具验证失败，尝试使用 bsdtar..."
  if command -v bsdtar >/dev/null; then
    if ! bsdtar -tf "$IPK_REAL_SRC" >/dev/null; then
      echo "❌ IPK 文件确实已损坏或格式不正确"
      echo "文件信息: $(file "$IPK_REAL_SRC")"
      echo "文件大小: $(du -h "$IPK_REAL_SRC")"
      exit 1
    else
      echo "✅ bsdtar 验证通过"
    fi
  else
    echo "❌ 请安装 libarchive-tools: sudo apt-get install libarchive-tools"
    exit 1
  fi
else
  echo "✅ ar 验证通过"
fi

# -------------------------------
# Step 7: 下载未压缩 CSS (增强版)
# -------------------------------
echo "? 下载未压缩 CSS..."
REPO_BASE="https://raw.githubusercontent.com/KuwiNet/KuCat/js/luci-theme-kucat/htdocs/luci-static/kucat/css"

# 确保 CSS 目录存在且绝对路径
CSS_DIR="$(pwd)/temp_css"
mkdir -p "$CSS_DIR"

# 添加下载重试机制
for retry in {1..3}; do
  echo "  尝试 #$retry 下载 CSS 文件..."
  if curl -fsSL "$REPO_BASE/theme.css" -o "$CSS_DIR/theme.css" && 
     curl -fsSL "$REPO_BASE/style.css" -o "$CSS_DIR/style.css"; then
    echo "   ✔ 成功下载 CSS 文件"
    break
  fi
  
  if [ $retry -eq 3 ]; then
    echo "❌ CSS 下载失败，请检查网络连接或仓库地址"
    exit 1
  fi
  sleep 2
done

# 添加文件存在性验证
if [ ! -f "$CSS_DIR/theme.css" ] || [ ! -f "$CSS_DIR/style.css" ]; then
  echo "❌ CSS 文件验证失败，路径: $CSS_DIR"
  ls -la "$CSS_DIR" || true
  exit 1
fi

# -------------------------------
# Step 8: 重新打包 (增强版)
# -------------------------------
echo "? 重新打包..."
OUTPUT_DIR="$(pwd)/bin/all-archs"
mkdir -p "$OUTPUT_DIR"

# 使用绝对路径
INPUT_IPK="/home/runner/work/KuCat/KuCat/openwrt-sdk/bin/packages/x86_64/base/luci-theme-kucat_2.6.17_all.ipk"
OUTPUT_IPK="$OUTPUT_DIR/luci-theme-kucat_2.6.17-r20250911_all.ipk"

# 添加文件存在性验证
if [ ! -f "$INPUT_IPK" ]; then
  echo "❌ 错误：输入IPK文件不存在: $INPUT_IPK"
  exit 1
fi

# 优先尝试使用bsdtar
if command -v bsdtar >/dev/null 2>&1; then
  echo "ℹ️ 使用bsdtar重新打包..."
  bsdtar -czf "$OUTPUT_IPK" -C "$TEMP_DIR" .
else
  echo "⚠️ bsdtar不可用，尝试使用ar..."
  if ! command -v ar >/dev/null 2>&1; then
    echo "❌ 错误：找不到可用的打包工具(bsdtar/ar)"
    exit 1
  fi
  ar cr "$OUTPUT_IPK" $(find "$TEMP_DIR" -type f | sort)
fi

# 验证输出文件
if [ -f "$OUTPUT_IPK" ]; then
  echo "✅ 重新打包完成: $OUTPUT_IPK"
else
  echo "❌ 错误：重新打包失败"
  exit 1
fi
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
