#!/bin/bash
set -euo pipefail

echo "? 构建 LuCI 主题 Kucat (通用all架构版)"

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
# Step 2: 配置通用SDK路径（任意架构均可，因主题与架构无关）
# -------------------------------
# 选择x86_64 SDK即可，因主题为all架构，编译结果适用于所有设备
SDK_URL="https://downloads.openwrt.org/releases/23.05.2/targets/x86/64/openwrt-sdk-23.05.2-x86-64_gcc-12.3.0_musl.Linux-x86_64.tar.xz"
SDK_DIR="openwrt-sdk"
OUTPUT_DIR="$SDK_DIR/bin/packages/x86_64/base"
BUILD_LOG="build_log.txt"

# -------------------------------
# Step 3: 下载SDK（如未存在）
# -------------------------------
if [ ! -d "$SDK_DIR" ]; then
  echo "? 下载 OpenWrt SDK..."
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
# Step 4: 复制主题并安装依赖
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

echo "? 更新 feeds..."
./scripts/feeds update -i || {
  echo "❌ 错误：更新 feeds 失败" >&2
  exit 1
}
./scripts/feeds update luci || {
  echo "❌ 错误：更新 luci feeds 失败" >&2
  exit 1
}

echo "? 安装最小依赖: luci-base"
./scripts/feeds install -p luci luci-base || {
  echo "❌ 错误：安装 luci-base 失败" >&2
  exit 1
}

make defconfig || {
  echo "❌ 错误：生成默认配置失败" >&2
  exit 1
}

cd - > /dev/null

echo "✅ 最小依赖安装完成"

# -------------------------------
# Step 5: 编译主题（all架构）
# -------------------------------
echo "⚙️ 开始编译通用all架构包..."
if ! make -C "$SDK_DIR" package/luci-theme-kucat/compile V=s > "$BUILD_LOG" 2>&1; then
  echo "❌ 错误：编译过程失败，查看日志：" >&2
  tail -n 100 "$BUILD_LOG" >&2
  exit 1
fi

# -------------------------------
# Step 6: 查找并验证IPK
# -------------------------------
# 因PKGARCH=all，IPK文件名应包含"all"
IPK_GLOB="$OUTPUT_DIR/luci-theme-kucat_${PKG_VERSION}_all.ipk"
IPK_REAL_SRC=$(ls $IPK_GLOB 2>/dev/null | head -n1 | xargs realpath 2>/dev/null)

if [ ! -f "$IPK_REAL_SRC" ]; then
  echo "❌ 错误：未找到通用all架构IPK！期望路径：" >&2
  echo "    $IPK_GLOB" >&2
  echo "当前输出目录内容：" >&2
  ls -la "$OUTPUT_DIR" >&2 || true
  exit 1
fi

echo "✅ 找到通用all架构IPK: $IPK_REAL_SRC"
echo "📊 文件大小: $(du -h "$IPK_REAL_SRC")"

# 验证IPK格式
echo "? 验证IPK文件格式..."
if ! ar t "$IPK_REAL_SRC" >/dev/null 2>&1; then
  echo "⚠️ 尝试使用bsdtar验证..."
  if ! bsdtar -tf "$IPK_REAL_SRC" >/dev/null; then
    echo "❌ IPK文件损坏" >&2
    exit 1
  fi
fi
echo "✅ IPK格式验证通过"

# -------------------------------
# Step 7: 输出结果
# -------------------------------
echo -e "\n🎉 通用all架构包构建成功！"
ls -lh "$IPK_REAL_SRC"
echo "📁 输出路径：$IPK_REAL_SRC"

# 导出版本和路径信息
echo "RELEASE_TAG=luci-theme-kucat-${FULL_VERSION}" >> $GITHUB_ENV
echo "IPK_PATH=$IPK_REAL_SRC" >> $GITHUB_ENV
echo "BUILD_LOG=$BUILD_LOG" >> $GITHUB_ENV

# 清理函数
cleanup() {
  echo -e "\n? 清理临时文件..."
}
trap cleanup EXIT
    
