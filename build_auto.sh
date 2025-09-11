#!/bin/bash
set -euo pipefail  # 更严格的错误检查

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
OUTPUT_DIR="$SDK_DIR/bin/packages/x86_64/base"

# 新增：记录日志文件路径
BUILD_LOG="build_log.txt"

# -------------------------------
# Step 3: 下载 SDK
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
# Step 4: 复制主题 + 安装最小依赖
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
# Step 5: 编译主题（带详细日志）
# -------------------------------
echo "⚙️ 开始编译..."
if ! make -C "$SDK_DIR" package/luci-theme-kucat/compile V=s > "$BUILD_LOG" 2>&1; then
  echo "❌ 错误：编译过程失败，查看日志：" >&2
  tail -n 100 "$BUILD_LOG" >&2  # 显示最后100行日志
  exit 1
fi

# -------------------------------
# Step 6: 查找并验证编译生成的 IPK
# -------------------------------
IPK_GLOB="$OUTPUT_DIR/luci-theme-kucat_${PKG_VERSION}_*.ipk"
IPK_REAL_SRC=$(ls $IPK_GLOB 2>/dev/null | head -n1 | xargs realpath 2>/dev/null)

if [ ! -f "$IPK_REAL_SRC" ]; then
  echo "❌ 错误：未找到编译生成的 .ipk 文件！期望路径格式：" >&2
  echo "    $IPK_GLOB" >&2
  echo "当前 SDK 输出目录内容：" >&2
  ls -la "$OUTPUT_DIR" >&2 || true
  exit 1
fi

# 检查文件大小
IPK_SIZE=$(du -k "$IPK_REAL_SRC" | cut -f1)
if [ "$IPK_SIZE" -lt 10000 ]; then  # 小于10KB则视为异常
  echo "⚠️ 警告：IPK 文件大小异常（$IPK_SIZE KB），可能不完整" >&2
  # 不直接退出，继续验证流程以便收集更多信息
fi

echo "✅ 找到编译生成的 IPK: $IPK_REAL_SRC"
echo "📊 IPK 文件大小: $(du -h "$IPK_REAL_SRC")"

# 验证 IPK 文件格式有效性
echo "? 验证 IPK 文件格式..."
if ! ar t "$IPK_REAL_SRC" >/dev/null 2>&1; then
  echo "⚠️ ar 工具验证失败，尝试使用 bsdtar 二次验证..."
  if command -v bsdtar >/dev/null; then
    if ! bsdtar -tf "$IPK_REAL_SRC" >/dev/null; then
      echo "❌ IPK 文件损坏或格式不正确" >&2
      echo "文件内容分析：" >&2
      file "$IPK_REAL_SRC" >&2
      exit 1
    else
      echo "✅ bsdtar 验证通过（IPK 格式有效）"
    fi
  else
    echo "❌ 请安装 libarchive-tools 以验证 IPK：sudo apt-get install libarchive-tools" >&2
    exit 1
  fi
else
  echo "✅ ar 验证通过（IPK 格式有效）"
fi

# -------------------------------
# Step 7: 显示构建结果
# -------------------------------
echo -e "\n🎉 构建成功！最终文件信息："
ls -lh "$IPK_REAL_SRC"
echo "📁 输出路径：$IPK_REAL_SRC"

# 导出版本号到 GitHub 环境变量
echo "RELEASE_TAG=luci-theme-kucat-${FULL_VERSION}" >> $GITHUB_ENV
echo "IPK_PATH=$IPK_REAL_SRC" >> $GITHUB_ENV
echo "BUILD_LOG=$BUILD_LOG" >> $GITHUB_ENV  # 导出日志路径

# -------------------------------
# 清理函数（可选）
# -------------------------------
cleanup() {
  echo -e "\n? 清理临时文件..."
  # 可选：清理SDK编译缓存
  # make -C "$SDK_DIR" package/luci-theme-kucat/clean >/dev/null 2>&1
  echo "✅ 清理完成"
}
trap cleanup EXIT
