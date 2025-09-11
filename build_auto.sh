#!/bin/bash
set -e

# 检查并设置SDK路径
SDK_DIR="openwrt-sdk"
if [ ! -d "$SDK_DIR" ]; then
    echo "❌ SDK目录不存在: $SDK_DIR"
    exit 1
fi

# 检查必要的SDK脚本
REQUIRED_SCRIPTS=(
    "scripts/rstrip.sh"
    "scripts/ipkg-build"
    "scripts/strip-kmod.sh"
)

for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ ! -f "$SDK_DIR/$script" ]; then
        echo "❌ 缺少必要的SDK脚本: $script"
        exit 1
    fi
done

# 设置环境变量
export PATH="$SDK_DIR/staging_dir/host/bin:$PATH"
export STAGING_DIR="$SDK_DIR/staging_dir"

# 创建构建目录
BUILD_DIR="$SDK_DIR/build_dir/target-x86_64_musl/luci-theme-kucat"
mkdir -p "$BUILD_DIR/ipkg-all/luci-theme-kucat"
mkdir -p "$BUILD_DIR/root"

# 复制主题文件
if [ -d "luci-theme-kucat/htdocs" ]; then
    cp -a luci-theme-kucat/htdocs/* "$BUILD_DIR/root/"
elif [ -d "luci-theme-kucat" ]; then
    cp -a luci-theme-kucat/* "$BUILD_DIR/root/"
else
    echo "❌ 找不到主题文件"
    exit 1
fi

# 清理CVS/SVN文件
find "$BUILD_DIR/ipkg-all/luci-theme-kucat" \
    -name 'CVS' -o -name '.svn' -o -name '.#*' -o -name '*~' | xargs -r rm -rf

# 执行rstrip
export CROSS="x86_64-openwrt-linux-musl-"
export NM="x86_64-openwrt-linux-musl-nm"
export STRIP="$SDK_DIR/staging_dir/host/bin/sstrip -z"
export STRIP_KMOD="$SDK_DIR/scripts/strip-kmod.sh"
export PATCHELF="$SDK_DIR/staging_dir/host/bin/patchelf"
"$SDK_DIR/scripts/rstrip.sh" "$BUILD_DIR/ipkg-all/luci-theme-kucat"

# 创建control文件
CONTROL_DIR="$BUILD_DIR/ipkg-all/luci-theme-kucat/CONTROL"
mkdir -p "$CONTROL_DIR"

cat > "$CONTROL_DIR/control" <<EOF
Package: luci-theme-kucat
Version: 2.6.17
Depends: libc, luci
Source: luci-theme-kucat
Section: luci
Maintainer: Your Name <your.email@example.com>
Architecture: all
Installed-Size: 1
Description: KuCat Theme for LuCI
EOF

# 创建脚本文件
cat > "$CONTROL_DIR/postinst" <<EOF
#!/bin/sh
[ "\${IPKG_NO_SCRIPT}" = "1" ] && exit 0
[ -s "\${IPKG_INSTROOT}/lib/functions.sh" ] || exit 0
. \${IPKG_INSTROOT}/lib/functions.sh
default_postinst \$0 \$@
EOF

cat > "$CONTROL_DIR/prerm" <<EOF
#!/bin/sh
[ -s "\${IPKG_INSTROOT}/lib/functions.sh" ] || exit 0
. \${IPKG_INSTROOT}/lib/functions.sh
default_prerm \$0 \$@
EOF

chmod 0755 "$CONTROL_DIR/postinst" "$CONTROL_DIR/prerm"

# 构建IPK
mkdir -p "$SDK_DIR/bin/packages/x86_64/base"
"$SDK_DIR/staging_dir/host/bin/fakeroot" \
    "$SDK_DIR/staging_dir/host/bin/bash" \
    "$SDK_DIR/scripts/ipkg-build" \
    -m "" \
    "$BUILD_DIR/ipkg-all/luci-theme-kucat" \
    "$SDK_DIR/bin/packages/x86_64/base"

# 复制IPK到输出目录
mkdir -p bin/all-archs
IPK_FILE=$(find "$SDK_DIR/bin/packages/x86_64/base" -name "*.ipk" | head -n 1)
if [ -n "$IPK_FILE" ]; then
    cp "$IPK_FILE" bin/all-archs/
    echo "✅ IPK构建完成: $(basename "$IPK_FILE")"
else
    echo "❌ 无法找到生成的IPK文件"
    exit 1
fi
