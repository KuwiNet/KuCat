#!/bin/bash
set -euo pipefail  # 严格错误检查，避免静默失败

# 脚本标题
echo -e "=== KuCat Theme 自动编译脚本（v2.6.8）===\n"

# -------------------------------
# Step 1: 从 Makefile 提取版本和作者（统一来源，避免硬编码）
# -------------------------------
MAKEFILE_PATH="luci-theme-kucat/Makefile"
if [ ! -f "$MAKEFILE_PATH" ]; then
  echo "❌ 错误：找不到主题 Makefile（路径：$MAKEFILE_PATH）" >&2
  exit 1
fi

# 提取版本号（从 Makefile 读取，确保一致性）
PKG_VERSION=$(awk -F'[ =]+' '/^PKG_VERSION:/ {print $2; exit}' "$MAKEFILE_PATH" | xargs)
# 提取作者信息
PKG_MAINTAINER=$(awk -F': ' '/^PKG_MAINTAINER:/ {print $2; exit}' "$MAKEFILE_PATH" | xargs)
# 生成完整版本（版本号+构建日期）
BUILD_DATE="r$(date +%Y%m%d)"
FULL_VERSION="${PKG_VERSION}-${BUILD_DATE}"

# 打印基础信息
echo "📌 版本信息：$FULL_VERSION"
echo "📌 作者信息：$PKG_MAINTAINER"
echo "📌 构建时间：$(date +'%Y-%m-%d %H:%M:%S')"

# -------------------------------
# Step 2: 配置 SDK 信息（固定 x86_64 SDK，生成 all 架构包）
# -------------------------------
OPENWRT_VERSION="23.05.3"  # 稳定版 SDK，兼容性最佳
SDK_URL="https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/targets/x86/64/openwrt-sdk-${OPENWRT_VERSION}-x86-64_gcc-12.3.0_musl.Linux-x86_64.tar.xz"
SDK_DIR="openwrt-sdk"       # SDK 工作目录
OUTPUT_DIR="${SDK_DIR}/bin/packages/x86_64/luci"  # 主题包输出目录（LuCI 专属）
BUILD_LOG="build_kucat_${FULL_VERSION}.log"  # 编译日志（带版本标识）

# -------------------------------
# Step 3: 下载并初始化 SDK（确保依赖源正确）
# -------------------------------
if [ ! -d "$SDK_DIR" ]; then
  echo -e "\n🔻 正在下载 OpenWRT SDK v${OPENWRT_VERSION}..."
  # 下载 SDK（显示进度，失败则退出）
  if ! wget -q --show-progress "$SDK_URL" -O "sdk_${OPENWRT_VERSION}.tar.xz"; then
    echo "❌ 错误：SDK 下载失败（URL：$SDK_URL）" >&2
    exit 1
  fi
  # 解压 SDK（确保完整性）
  if ! tar xJf "sdk_${OPENWRT_VERSION}.tar.xz"; then
    echo "❌ 错误：SDK 解压失败" >&2
    exit 1
  fi
  # 重命名 SDK 目录（统一路径）
  mv openwrt-sdk-*/ "$SDK_DIR" || {
    echo "❌ 错误：SDK 目录重命名失败" >&2
    exit 1
  }
  # 删除压缩包（释放空间）
  rm -f "sdk_${OPENWRT_VERSION}.tar.xz"
fi

# 进入 SDK 目录（后续操作均在 SDK 内）
cd "$SDK_DIR" || {
  echo "❌ 错误：无法进入 SDK 目录（路径：$SDK_DIR）" >&2
  exit 1
}

# 修复 SDK feeds 配置（确保 LuCI 和 packages 源有效）
echo -e "\n🔻 正在配置 SDK 依赖源..."
# 1. 启用 packages 源（提供 lua、liblua 等基础依赖）
sed -i "s|^#\(src-git packages .*\)|\1|" feeds.conf.default
# 2. 绑定 LuCI 分支与 SDK 版本一致（避免版本不兼容）
sed -i "s|^src-git luci .*|src-git luci https://git.openwrt.org/project/luci.git;branch=openwrt-${OPENWRT_VERSION}|" feeds.conf.default

# 更新并安装所有依赖（解决 lua.h、rpcd 等缺失问题）
echo -e "\n🔻 正在更新并安装依赖包..."
if ! ./scripts/feeds update -a > "$BUILD_LOG" 2>&1; then
  echo "❌ 错误：feeds 更新失败，查看日志：$BUILD_LOG" >&2
  exit 1
fi
if ! ./scripts/feeds install -a >> "$BUILD_LOG" 2>&1; then
  echo "❌ 错误：feeds 安装失败，查看日志：$BUILD_LOG" >&2
  exit 1
fi

# -------------------------------
# Step 4: 复制主题包到 SDK（确保路径正确）
# -------------------------------
THEME_SDK_PATH="${SDK_DIR}/package/luci-theme-kucat"
echo -e "\n🔻 正在复制 KuCat 主题到 SDK..."
# 删除旧主题包（避免残留文件干扰）
rm -rf "$THEME_SDK_PATH" 2>/dev/null || true
# 从项目根目录复制最新主题（../ 表示 SDK 上级目录，即项目根目录）
if ! cp -r ../luci-theme-kucat "$THEME_SDK_PATH"; then
  echo "❌ 错误：主题复制失败（源路径：../luci-theme-kucat，目标路径：$THEME_SDK_PATH）" >&2
  exit 1
fi

# 验证主题包是否有效（关键检查：Makefile 必须存在）
if [ ! -f "${THEME_SDK_PATH}/Makefile" ]; then
  echo "❌ 错误：SDK 中主题包缺少 Makefile（路径：${THEME_SDK_PATH}/Makefile）" >&2
  exit 1
fi
echo "✅ 主题包复制完成（路径：$THEME_SDK_PATH）"

# -------------------------------
# Step 5: 编译主题包（生成 all 架构 IPK）
# -------------------------------
echo -e "\n🔻 正在编译主题包（版本：$FULL_VERSION）..."
# 清理之前的编译缓存（避免旧配置干扰）
make package/luci-theme-kucat/clean V=s >> "$BUILD_LOG" 2>&1 || {
  echo "❌ 错误：编译缓存清理失败，查看日志：$BUILD_LOG" >&2
  exit 1
}
# 编译主题包（多线程加速，详细日志输出）
if ! make package/luci-theme-kucat/compile V=s -j$(nproc) >> "$BUILD_LOG" 2>&1; then
  echo "❌ 错误：主题编译失败，查看日志（最后 100 行）：" >&2
  tail -n 100 "$BUILD_LOG" >&2
  exit 1
fi

# -------------------------------
# Step 6: 验证并导出编译结果
# -------------------------------
echo -e "\n🔻 正在验证编译结果..."
# 查找 all 架构 IPK（匹配 Makefile 中 PKG_ARCH=all）
IPK_FILE=$(ls "${OUTPUT_DIR}/luci-theme-kucat_${PKG_VERSION}_all.ipk" 2>/dev/null | head -n1)
if [ -z "$IPK_FILE" ]; then
  echo "❌ 错误：未找到 all 架构 IPK，当前输出目录内容：" >&2
  ls -la "$OUTPUT_DIR" >&2
  exit 1
fi

# 验证 IPK 文件完整性（检查格式是否正确）
if ! ar t "$IPK_FILE" >/dev/null 2>&1; then
  echo "⚠️ 警告：ar 工具验证 IPK 失败，尝试 bsdtar 验证..."
  if ! bsdtar -tf "$IPK_FILE" >/dev/null 2>&1; then
    echo "❌ 错误：IPK 文件损坏或格式错误（路径：$IPK_FILE）" >&2
    exit 1
  fi
fi

# -------------------------------
# Step 7: 输出结果并导环境变量（供 CI 使用）
# -------------------------------
echo -e "\n🎉 编译成功！"
echo "======================================"
echo "📦 最终 IPK 文件：$IPK_FILE"
echo "📊 文件大小：$(du -h "$IPK_FILE")"
echo "📅 构建时间：$(date +'%Y-%m-%d %H:%M:%S')"
echo "📝 编译日志：$(realpath "$BUILD_LOG")"
echo "======================================"

# 导出版本和路径信息（供 GitHub Actions 使用）
if [ -n "${GITHUB_ENV:-}" ]; then
  echo "RELEASE_TAG=$FULL_VERSION" >> "$GITHUB_ENV"
  echo "IPK_PATH=$(realpath "$IPK_FILE")" >> "$GITHUB_ENV"
  echo "BUILD_LOG=$(realpath "$BUILD_LOG")" >> "$GITHUB_ENV"
fi

# 返回项目根目录
cd - > /dev/null
