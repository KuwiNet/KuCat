#!/bin/bash
set -euo pipefail

echo "? 构建 LuCI 主题 Kucat (多架构支持版)"

# -------------------------------
# Step 1: 提取版本号（保持不变）
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
# Step 2: 根据目标架构选择 SDK（新增多架构支持）
# -------------------------------
# 默认架构为 x86_64，支持通过环境变量 TARGET_ARCH 切换
TARGET_ARCH="${TARGET_ARCH:-x86_64}"
OPENWRT_VERSION="23.05.2"

# 定义不同架构对应的 SDK 下载链接
case "$TARGET_ARCH" in
  x86_64)
    SDK_URL="https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/targets/x86/64/openwrt-sdk-${OPENWRT_VERSION}-x86-64_gcc-12.3.0_musl.Linux-x86_64.tar.xz"
    OUTPUT_DIR_SUFFIX="x86/64/base"
    ;;
  armvirt-64)
    SDK_URL="https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/targets/armvirt/64/openwrt-sdk-${OPENWRT_VERSION}-armvirt-64_gcc-12.3.0_musl.Linux-x86_64.tar.xz"
    OUTPUT_DIR_SUFFIX="armvirt/64/base"
    ;;
  *)
    echo "❌ 错误：不支持的架构 $TARGET_ARCH" >&2
    exit 1
    ;;
esac

SDK_DIR="openwrt-sdk-${TARGET_ARCH}"  # 不同架构使用不同SDK目录，避免冲突
OUTPUT_DIR="${SDK_DIR}/bin/packages/${OUTPUT_DIR_SUFFIX}"
BUILD_LOG="build_log-${TARGET_ARCH}.txt"  # 按架构区分日志

# -------------------------------
# 后续步骤（下载SDK、复制主题、编译等）保持不变，仅路径变量更新为上述定义
# -------------------------------

# Step 3: 下载 SDK（根据 SDK_DIR 区分不同架构）
if [ ! -d "$SDK_DIR" ]; then
  echo "? 下载 ${TARGET_ARCH} 架构的 OpenWrt SDK..."
  if ! wget -qO- "$SDK_URL" | tar -xJ; then
    echo "❌ 错误：下载或解压 SDK 失败" >&2
    exit 1
  fi
  # 解压后目录名可能含版本号，重命名为统一的 SDK_DIR
  mv openwrt-sdk-* "$SDK_DIR" || {
    echo "❌ 错误：重命名 SDK 目录失败" >&2
    exit 1
  }
fi

# 后续步骤（复制主题、更新feeds、编译等）与原脚本一致，仅使用新定义的变量
# ...（省略与原脚本相同的代码）

# 导出版本和路径信息（供 GitHub Actions 使用）
echo "RELEASE_TAG=luci-theme-kucat-${FULL_VERSION}" >> $GITHUB_ENV
echo "IPK_PATH=$IPK_REAL_SRC" >> $GITHUB_ENV
echo "BUILD_LOG=$BUILD_LOG" >> $GITHUB_ENV
