#!/bin/bash
set -e

############## 0. 工具检测 / 仅安装缺失包 ##############
install_if_missing() {
  dpkg -l "$1" 2>/dev/null | grep -q '^ii' || {
    echo "⬇️  安装缺失包：$1"
    sudo apt-get update -qq
    sudo apt-get install -y "$1"
  }
}

for pkg in git ca-certificates make bash coreutils wget tar xz-utils; do
  install_if_missing "$pkg"
done

############## 1. 克隆源码（若已存在则更新） ##############
REPO_URL="https://github.com/KuwiNet/luci-theme-kucat.git"
KUCAT_DIR="kucat"

if [ -d "$KUCAT_DIR/.git" ]; then
  echo "🔄 更新已有仓库"
  git -C "$KUCAT_DIR" pull --ff-only
else
  echo "⬇️  克隆仓库"
  git clone "$REPO_URL" "$KUCAT_DIR"
fi
cd "$KUCAT_DIR"

SRC_DIR="luci-theme-kucat"
cd "$SRC_DIR"

############## 2. 提取版本 ##############
[ ! -f "Makefile" ] && { echo "❌ 缺少 Makefile" >&2; exit 1; }
PKG_VERSION=$(awk -F'[ =]+' '/^PKG_VERSION:/ {print $2; exit}' Makefile | xargs)
BUILD_DATE="r$(date +%Y%m%d)"
FULL_VERSION="${PKG_VERSION}-${BUILD_DATE}"
echo "✅ 版本 ${FULL_VERSION}"

############## 3. SDK 下载##############
# 更新为最新的SDK版本链接（可根据需要修改）
SDK_URL="https://downloads.openwrt.org/releases/23.05.3/targets/x86/64/openwrt-sdk-23.05.3-x86-64_gcc-12.3.0_musl.Linux-x86_64.tar.xz"
SDK_DIR="openwrt-sdk"
OUTPUT_DIR="$SDK_DIR/bin/packages/x86_64/base"

# 彻底清理并重新下载SDK
echo "🧹 清理旧的SDK目录"
rm -rf "$SDK_DIR"
rm -f openwrt-sdk-*.tar.xz

echo "⬇️ 下载 OpenWrt SDK..."
if ! wget --show-progress -q "$SDK_URL" -O "openwrt-sdk.tar.xz"; then
  echo "❌ 下载SDK失败，请检查网络或URL是否正确" >&2
  exit 1
fi

echo "📦 解压SDK..."
if ! tar -xJf "openwrt-sdk.tar.xz"; then
  echo "❌ 解压SDK失败" >&2
  exit 1
fi

# 查找解压后的目录并正确重命名
SDK_TMP_DIR=$(find . -maxdepth 1 -type d -name "openwrt-sdk-*" | head -n 1)
if [ -z "$SDK_TMP_DIR" ]; then
  echo "❌ 未找到解压后的SDK目录" >&2
  exit 1
fi

mv "$SDK_TMP_DIR" "$SDK_DIR"
rm -f "openwrt-sdk.tar.xz"

if [ ! -d "$SDK_DIR/scripts" ]; then
  echo "❌ 错误：SDK 目录不完整，缺少scripts文件夹" >&2
  exit 1
fi

############## 4. 复制主题并编译 ##############
echo "📂 复制主题 → SDK"
cd ..
mkdir -p "$SDK_DIR/package"
rm -rf "$SDK_DIR/package/luci-theme-kucat"
cp -r luci-theme-kucat "$SDK_DIR/package/"

############## 5. feeds 处理 ##############
echo "🔄 更新 feeds..."
cd "$SDK_DIR" || { echo "❌ 无法进入 SDK 目录 $SDK_DIR"; exit 1; }

# 检查feeds脚本是否存在
if [ ! -f "./scripts/feeds" ]; then
  echo "❌ 找不到feeds脚本，SDK可能损坏" >&2
  exit 1
fi

# 确保脚本有执行权限
chmod +x ./scripts/feeds

./scripts/feeds update -i
./scripts/feeds install -a -p luci
./scripts/feeds install -p luci luci-base
make defconfig
cd - >/dev/null

echo "⚙️  编译中..."
make -C "$SDK_DIR" package/luci-theme-kucat/compile V=s -j"$(nproc)"

############## 6. 取出 IPK 到 kucat 目录 ##############
IPK_GLOB="$OUTPUT_DIR/luci-theme-kucat_${PKG_VERSION}_*.ipk"
IPK_SRC=$(ls $IPK_GLOB 2>/dev/null | head -n1)
[ -z "$IPK_SRC" ] && { echo "❌ 未找到 IPK"; exit 1; }

# 当前在 kucat/luci-theme-kucat/，退到 kucat/ 根目录再放文件
FINAL_IPK="${PWD}/../luci-theme-kucat_${FULL_VERSION}_all.ipk"
cp -f "$IPK_SRC" "$FINAL_IPK"

############## 7. 结果 ##############
echo "🎉 构建完成！"
ls -lh "$FINAL_IPK"
echo "📁 输出：$FINAL_IPK"
