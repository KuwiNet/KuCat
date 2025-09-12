#!/bin/bash
set -e

echo "📦 构建 LuCI 主题 Kucat"
############## 0. 工具检测 / 仅安装缺失包 ##############
install_if_missing() {
  dpkg -l "$1" 2>/dev/null | grep -q '^ii' || {
    echo "⬇️  安装缺失包：$1"
    sudo apt-get update -qq
    sudo apt-get install -y "$1"
  }
}

# 增加必要的网络和证书工具
for pkg in git ca-certificates make bash coreutils curl wget tar xz-utils gnutls-bin ca-certificates; do
  install_if_missing "$pkg"
done

# 刷新证书以避免TLS问题
echo "🔄 刷新系统证书..."
sudo update-ca-certificates --fresh >/dev/null 2>&1

############## 1. 克隆源码（若已存在则更新） ##############
REPO_URL="https://github.com/KuwiNet/luci-theme-kucat.git"
KUCAT_DIR="kucat"

# 保存当前工作目录（项目根目录）
PROJECT_ROOT=$(pwd)
# 创建releases目录（使用绝对路径）
RELEASES_DIR="$PROJECT_ROOT/$KUCAT_DIR/releases"
mkdir -p "$RELEASES_DIR"
echo "📂 发布目录设置为: $RELEASES_DIR"

if [ -d "$KUCAT_DIR/.git" ]; then
  echo "🔄 更新已有仓库"
  git -C "$KUCAT_DIR" pull --ff-only
else
  echo "⬇️  克隆仓库"
  git clone "$REPO_URL" "$KUCAT_DIR"
fi
cd "$KUCAT_DIR"

# 自动检测包含Makefile的正确目录
echo "🔍 查找主题源目录..."
SRC_DIR=$(find . -maxdepth 2 -type f -name "Makefile" | grep -m1 "luci-theme-kucat/Makefile" | xargs dirname)

if [ -z "$SRC_DIR" ] || [ ! -f "$SRC_DIR/Makefile" ]; then
  echo "❌ 错误：找不到包含Makefile的luci-theme-kucat目录" >&2
  echo "🔍 尝试手动指定目录结构..."
  
  # 尝试常见的目录结构
  possible_dirs=(
    "luci-theme-kucat"
    "src/luci-theme-kucat"
    "."
  )
  
  for dir in "${possible_dirs[@]}"; do
    if [ -f "$dir/Makefile" ]; then
      SRC_DIR="$dir"
      echo "✅ 找到可能的源目录: $SRC_DIR"
      break
    fi
  done
  
  if [ -z "$SRC_DIR" ] || [ ! -f "$SRC_DIR/Makefile" ]; then
    echo "❌ 无法找到有效的源目录，请检查仓库结构" >&2
    exit 1
  fi
fi

cd "$SRC_DIR"

# -------------------------------
# Step 1: 提取版本号
# -------------------------------
if [ ! -f "Makefile" ]; then
  echo "❌ 错误：在 $SRC_DIR 中找不到 Makefile" >&2
  exit 1
fi

PKG_VERSION=$(awk -F'[ =]+' '/^PKG_VERSION:/ {print $2; exit}' Makefile | xargs)
if [ -z "$PKG_VERSION" ]; then
  echo "❌ 错误：无法从 Makefile 提取 PKG_VERSION" >&2
  exit 1
fi

BUILD_DATE="r$(date +%Y%m%d)"
FULL_VERSION="${PKG_VERSION}-${BUILD_DATE}"

echo "🔖 版本: $PKG_VERSION"
echo "📅 构建日期: $BUILD_DATE"
echo "✅ 完整版本: $FULL_VERSION"

# -------------------------------
# Step 2: 配置路径（SDK放在kucat目录中）
# -------------------------------
SDK_URL="https://downloads.openwrt.org/releases/23.05.2/targets/x86/64/openwrt-sdk-23.05.2-x86-64_gcc-12.3.0_musl.Linux-x86_64.tar.xz"
SDK_DIR="../openwrt-sdk"  # SDK将位于kucat目录下，与主题源目录同级
# 直接使用SDK的输出目录作为最终输出目录
OUTPUT_DIR="$SDK_DIR/bin/packages/x86_64/base"

# -------------------------------
# Step 3: 下载 SDK（使用curl显示进度）
# -------------------------------
if [ ! -d "$SDK_DIR" ]; then
  echo "⬇️ 下载 OpenWrt SDK..."
  # 增加重试机制，最多3次尝试
  if ! curl -# -L --retry 3 --retry-delay 5 "$SDK_URL" | tar -xJ; then
    echo "❌ SDK下载失败，尝试使用wget重试..."
    wget --progress=bar:force --tries=3 --wait=5 -O- "$SDK_URL" | tar -xJ
  fi
  mv openwrt-sdk-* "$SDK_DIR" || true
fi

if [ ! -d "$SDK_DIR" ]; then
  echo "❌ 错误：SDK 目录缺失" >&2
  exit 1
fi

# -------------------------------
# Step 4: 复制主题 + 安装最小依赖
# -------------------------------
echo "📂 复制主题到 SDK..."
rm -rf "$SDK_DIR/package/luci-theme-kucat" 2>/dev/null || true
cp -r . "$SDK_DIR/package/luci-theme-kucat"

cd "$SDK_DIR"

echo "🔄 更新 feeds..."
# 增加网络稳定性配置，禁用压缩以避免TLS问题
export GIT_CONFIG_PARAMETERS="http.sslVerify=true http.postBuffer=1048576000 core.compression=0"

# 多次尝试更新feed，最多3次
update_feed() {
  local feed_name=$1
  local retries=3
  local count=0
  
  while [ $count -lt $retries ]; do
    count=$((count + 1))
    echo "📥 第 $count 次尝试更新 $feed_name feed..."
    
    if ./scripts/feeds update "$feed_name"; then
      return 0
    fi
    
    if [ $count -lt $retries ]; then
      echo "⚠️ 更新失败，$((retries - count)) 次重试机会..."
      sleep 5
    fi
  done
  
  return 1
}

# 先更新所有feed，再单独更新luci
if ! ./scripts/feeds update -i; then
  echo "⚠️ 整体feed更新失败，尝试单独更新luci..."
fi

if ! update_feed "luci"; then
  echo "❌ 多次尝试后仍无法更新luci feed，尝试手动克隆..."
  
  # 手动克隆luci仓库作为最后的备选方案
  LUCI_FEED_DIR="feeds/luci"
  LUCI_REPO="https://git.openwrt.org/project/luci.git"
  
  rm -rf "$LUCI_FEED_DIR"
  mkdir -p "$LUCI_FEED_DIR"
  
  if git clone "$LUCI_REPO" "$LUCI_FEED_DIR"; then
    echo "✅ 手动克隆luci仓库成功"
  else
    echo "❌ 手动克隆也失败，请检查网络连接" >&2
    exit 1
  fi
fi

echo "📦 安装最小依赖: luci-base"
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
# Step 6: 查找并验证编译生成的 IPK
# -------------------------------
# 匹配 SDK 编译输出的 IPK 路径
IPK_GLOB="$OUTPUT_DIR/luci-theme-kucat_${PKG_VERSION}_*.ipk"
IPK_REAL_SRC=$(ls $IPK_GLOB 2>/dev/null | head -n1 | xargs realpath 2>/dev/null)

if [ ! -f "$IPK_REAL_SRC" ]; then
  echo "❌ 错误：未找到编译生成的 .ipk 文件！期望路径格式：" >&2
  echo "    $IPK_GLOB" >&2
  # 辅助排查：列出所有可能的 IPK 文件
  echo "当前 SDK 输出目录下的 IPK 文件："
  find "$SDK_DIR/bin/packages" -type f -name "luci-theme-kucat_*.ipk" -ls 2>/dev/null || echo "无"
  exit 1
fi

echo "✅ 找到编译生成的 IPK: $IPK_REAL_SRC"

# 验证 IPK 文件格式有效性
echo "🔍 验证 IPK 文件格式..."
if ! ar t "$IPK_REAL_SRC" >/dev/null 2>&1; then
  echo "⚠️ ar 工具验证失败，尝试使用 bsdtar 二次验证..."
  if command -v bsdtar >/dev/null; then
    if ! bsdtar -tf "$IPK_REAL_SRC" >/dev/null; then
      echo "❌ IPK 文件损坏或格式不正确"
      echo "文件信息: $(file "$IPK_REAL_SRC")"
      echo "文件大小: $(du -h "$IPK_REAL_SRC")"
      exit 1
    else
      echo "✅ bsdtar 验证通过（IPK 格式有效）"
    fi
  else
    echo "❌ 请安装 libarchive-tools 以验证 IPK：sudo apt-get install libarchive-tools"
    exit 1
  fi
else
  echo "✅ ar 验证通过（IPK 格式有效）"
fi

# -------------------------------
# Step 7: 移动IPK到releases目录
# -------------------------------
# 获取IPK文件名
IPK_FILENAME=$(basename "$IPK_REAL_SRC")
# 目标路径（使用绝对路径）
DEST_PATH="$RELEASES_DIR/$IPK_FILENAME"

# 移动文件
echo "📤 移动 IPK 文件到 releases 目录..."
echo "   源: $IPK_REAL_SRC"
echo "   目标: $DEST_PATH"

# 确保目标目录存在
mkdir -p "$(dirname "$DEST_PATH")"

if mv "$IPK_REAL_SRC" "$DEST_PATH"; then
  echo "✅ IPK 文件已成功移动到: $DEST_PATH"
else
  echo "⚠️ IPK 文件移动失败，仍保留在原位置: $IPK_REAL_SRC"
  DEST_PATH="$IPK_REAL_SRC"  # 回退到原始路径
fi

# -------------------------------
# Step 8: 显示构建结果
# -------------------------------
echo -e "\n🎉 构建成功！最终文件信息："
ls -lh "$DEST_PATH"
echo "📁 输出路径：$DEST_PATH"

# -------------------------------
# 清理函数（可选）
# -------------------------------
cleanup() {
  echo -e "\n🧹 清理临时文件..."
  # 可选：清理SDK编译缓存
  # make -C "$SDK_DIR" package/luci-theme-kucat/clean >/dev/null 2>&1
  echo "✅ 清理完成"
}
trap cleanup EXIT
