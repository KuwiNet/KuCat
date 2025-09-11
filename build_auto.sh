#!/bin/bash
set -euo pipefail

echo "? 构建 LuCI 主题 Kucat (通用all架构版)"

# -------------------------------
# Step 1: 从Makefile提取版本和作者信息
# -------------------------------
if [ ! -f "luci-theme-kucat/Makefile" ]; then
  echo "❌ 错误：找不到 luci-theme-kucat/Makefile" >&2
  exit 1
fi

# 从Makefile读取版本号（保持单一来源）
PKG_VERSION=$(awk -F'[ =]+' '/^PKG_VERSION:/ {print $2; exit}' luci-theme-kucat/Makefile | xargs)
PKG_MAINTAINER=$(awk -F'[ =]+' '/^PKG_MAINTAINER:/ {print substr($0, index($0, $2))}' luci-theme-kucat/Makefile | xargs)

if [ -z "$PKG_VERSION" ]; then
  echo "❌ 错误：无法从Makefile提取 PKG_VERSION" >&2
  exit 1
fi

BUILD_DATE="r$(date +%Y%m%d)"
FULL_VERSION="${PKG_VERSION}-${BUILD_DATE}"

echo "? 版本: $PKG_VERSION"
echo "? 作者: $PKG_MAINTAINER"
echo "? 构建日期: $BUILD_DATE"
echo "✅ 完整版本: $FULL_VERSION"

# -------------------------------
# Step 2: 配置SDK路径
# -------------------------------
OPENWRT_VERSION="23.05.3"
SDK_URL="https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/targets/x86/64/openwrt-sdk-${OPENWRT_VERSION}-x86-64_gcc-12.3.0_musl.Linux-x86_64.tar.xz"
SDK_DIR="openwrt-sdk"
OUTPUT_DIR="$SDK_DIR/bin/packages/x86_64/luci"
BUILD_LOG="build_log.txt"

# -------------------------------
# Step 3: 下载并准备SDK
# -------------------------------
if [ ! -d "$SDK_DIR" ]; then
  echo "? 下载 OpenWrt SDK v${OPENWRT_VERSION}..."
  if ! wget -qO- "$SDK_URL" | tar -xJ; then
    echo "❌ 错误：下载或解压 SDK 失败" >&2
    exit 1
  fi
  mv openwrt-sdk-* "$SDK_DIR" || {
    echo "❌ 错误：重命名 SDK 目录失败" >&2
    exit 1
  }
fi

if [ ! -d "$SDK_DIR" ]; then
  echo "❌ 错误：SDK 目录缺失" >&2
  exit 1
fi

# -------------------------------
# Step 4: 复制主题并安装完整依赖
# -------------------------------
echo "? 复制主题到 SDK..."
rm -rf "$SDK_DIR/package/luci-theme-kucat" 2>/dev/null || true
cp -r luci-theme-kucat "$SDK_DIR/package/" || {
  echo "❌ 错误：复制主题文件失败" >&2
  exit 1
}

cd "$SDK_DIR" || {
  echo "❌ 错误：无法进入 SDK 目录" >&2
  exit 1
}

# 配置feeds确保依赖完整
echo "? 配置并更新 feeds..."
sed -i 's|^#\(src-git packages .*\)|\1|' feeds.conf.default
sed -i 's|^#\(src-git luci .*\)|\1|' feeds.conf.default
./scripts/feeds update -a || {
  echo "❌ 错误：更新 feeds 失败" >&2
  exit 1
}

# 安装核心依赖（解决lua.h等缺失问题）
echo "? 安装必要依赖..."
./scripts/feeds install -p packages lua liblua || true
./scripts/feeds install -p luci luci-base lucihttp rpcd ucode || true
make defconfig || {
  echo "❌ 错误：生成默认配置失败" >&2
  exit 1
}

cd - > /dev/null

# -------------------------------
# Step 5: 编译主题
# -------------------------------
echo "⚙️ 开始编译通用all架构包 (v${PKG_VERSION})..."
if ! make -C "$SDK_DIR" package/luci-theme-kucat/compile V=s > "$BUILD_LOG" 2>&1; then
  echo "❌ 编译失败，查看日志：" >&2
  tail -n 100 "$BUILD_LOG" >&2
  exit 1
fi

# -------------------------------
# Step 6: 验证并输出结果
# -------------------------------
IPK_GLOB="$OUTPUT_DIR/luci-theme-kucat_${PKG_VERSION}_all.ipk"
IPK_REAL_SRC=$(ls $IPK_GLOB 2>/dev/null | head -n1 | xargs realpath 2>/dev/null)

if [ ! -f "$IPK_REAL_SRC" ]; then
  echo "❌ 未找到IPK文件！期望路径：$IPK_GLOB" >&2
  ls -la "$OUTPUT_DIR" >&2 || true
  exit 1
fi

echo "✅ 找到通用IPK: $IPK_REAL_SRC"
echo "📊 文件大小: $(du -h "$IPK_REAL_SRC")"

# 验证IPK完整性
if ! ar t "$IPK_REAL_SRC" >/dev/null 2>&1 && ! bsdtar -tf "$IPK_REAL_SRC" >/dev/null; then
  echo "❌ IPK文件损坏" >&2
  exit 1
fi

echo -e "\n🎉 构建成功！版本: $FULL_VERSION"
ls -lh "$IPK_REAL_SRC"

# 导出环境变量供CI使用
echo "RELEASE_TAG=luci-theme-kucat-${FULL_VERSION}" >> $GITHUB_ENV
echo "IPK_PATH=$IPK_REAL_SRC" >> $GITHUB_ENV
echo "BUILD_LOG=$BUILD_LOG" >> $GITHUB_ENV

# 清理函数
cleanup() {
  echo -e "\n? 清理临时文件..."
}
trap cleanup EXIT
    
