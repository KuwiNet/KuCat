#!/bin/bash

set -e

# 初始化变量
SDK_DIR="openwrt-sdk"
THEME_NAME="luci-theme-kucat"
THEME_VERSION="2.6.17"
BUILD_DIR="$SDK_DIR/build_dir/target-x86_64_musl/$THEME_NAME"
IPKG_DIR="$BUILD_DIR/ipkg-all/$THEME_NAME"
OUTPUT_DIR="$SDK_DIR/bin/packages/x86_64/base"

# 检查SDK目录结构
if [ ! -d "$SDK_DIR/scripts" ]; then
    echo "❌ SDK目录结构不完整，缺少scripts目录"
    exit 1
fi

# 创建必要目录
mkdir -p "$IPKG_DIR/CONTROL"
mkdir -p "$OUTPUT_DIR"
mkdir -p "bin/all-archs"

# 检查并复制主题文件
if [ -d "luci-theme-kucat/root" ]; then
    echo "ℹ️ 从源码目录复制主题文件..."
    cp -pR "luci-theme-kucat/root/"* "$IPKG_DIR/" || {
        echo "❌ 无法复制主题文件"
        exit 1
    }
else
    echo "❌ 源码目录中缺少root目录"
    exit 1
fi

# 清理版本控制文件
find "$IPKG_DIR" -name 'CVS' -o -name '.svn' -o -name '.#*' -o -name '*~' | xargs -r rm -rf

# 检查并执行strip操作
if [ -f "$SDK_DIR/scripts/rstrip.sh" ]; then
    export CROSS="x86_64-openwrt-linux-musl-"
    export NM="x86_64-openwrt-linux-musl-nm"
    export STRIP="$SDK_DIR/staging_dir/host/bin/sstrip -z"
    export STRIP_KMOD="$SDK_DIR/scripts/strip-kmod.sh"
    export PATCHELF="$SDK_DIR/staging_dir/host/bin/patchelf"
    "$SDK_DIR/scripts/rstrip.sh" "$IPKG_DIR"
else
    echo "⚠️ 缺少rstrip.sh，跳过strip操作"
fi

# 创建CONTROL文件
cat > "$IPKG_DIR/CONTROL/control" <<EOF
Package: $THEME_NAME
Version: $THEME_VERSION
Depends: luci
Section: luci
Architecture: all
Installed-Size: 1
Description: KuCat Theme for LuCI
EOF

# 构建IPK包
if [ -f "$SDK_DIR/scripts/ipkg-build" ]; then
    "$SDK_DIR/staging_dir/host/bin/fakeroot" \
    "$SDK_DIR/staging_dir/host/bin/bash" \
    "$SDK_DIR/scripts/ipkg-build" -m "" "$IPKG_DIR" "$OUTPUT_DIR"
else
    echo "❌ 缺少ipkg-build脚本"
    exit 1
fi

# 检查IPK文件
IPK_FILE=$(ls "$OUTPUT_DIR"/*.ipk 2>/dev/null | head -n 1)
if [ -z "$IPK_FILE" ]; then
    echo "❌ IPK文件生成失败"
    exit 1
fi

# 复制到all-archs目录
mkdir -p "bin/all-archs"
cp "$IPK_FILE" "bin/all-archs/"
echo "✅ IPK构建成功: $IPK_FILE"
