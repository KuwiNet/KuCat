#!/bin/bash

set -e

# 初始化变量
SDK_DIR="openwrt-sdk"
THEME_NAME="luci-theme-kucat"
THEME_VERSION="2.6.17"
BUILD_DIR="$SDK_DIR/build_dir/target-x86_64_musl/$THEME_NAME"
IPKG_DIR="$BUILD_DIR/ipkg-all/$THEME_NAME"
OUTPUT_DIR="$SDK_DIR/bin/packages/x86_64/base"

# 创建必要目录
mkdir -p "$IPKG_DIR/CONTROL"
mkdir -p "$OUTPUT_DIR"

# 复制主题文件
cp -pR "$SDK_DIR/build_dir/target-x86_64_musl/$THEME_NAME/root/*" "$IPKG_DIR/"

# 清理版本控制文件
find "$IPKG_DIR" -name 'CVS' -o -name '.svn' -o -name '.#*' -o -name '*~' | xargs -r rm -rf

# 执行strip操作
export CROSS="x86_64-openwrt-linux-musl-"
export NM="x86_64-openwrt-linux-musl-nm"
export STRIP="$SDK_DIR/staging_dir/host/bin/sstrip -z"
export STRIP_KMOD="$SDK_DIR/scripts/strip-kmod.sh"
export PATCHELF="$SDK_DIR/staging_dir/host/bin/patchelf"
"$SDK_DIR/scripts/rstrip.sh" "$IPKG_DIR"

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

# 创建postinst和prerm脚本
cat > "$IPKG_DIR/CONTROL/postinst" <<EOF
#!/bin/sh
[ "\${IPKG_NO_SCRIPT}" = "1" ] && exit 0
[ -s "\${IPKG_INSTROOT}/lib/functions.sh" ] || exit 0
. \${IPKG_INSTROOT}/lib/functions.sh
default_postinst \$0 \$@
EOF

cat > "$IPKG_DIR/CONTROL/prerm" <<EOF
#!/bin/sh
[ -s "\${IPKG_INSTROOT}/lib/functions.sh" ] || exit 0
. \${IPKG_INSTROOT}/lib/functions.sh
default_prerm \$0 \$@
EOF

chmod 0755 "$IPKG_DIR/CONTROL/postinst" "$IPKG_DIR/CONTROL/prerm"

# 构建IPK包
"$SDK_DIR/staging_dir/host/bin/fakeroot" \
"$SDK_DIR/staging_dir/host/bin/bash" \
"$SDK_DIR/scripts/ipkg-build" -m "" "$IPKG_DIR" "$OUTPUT_DIR"

# 验证IPK文件
IPK_FILE=$(ls "$OUTPUT_DIR"/*.ipk | head -n 1)
if [ ! -f "$IPK_FILE" ]; then
    echo "❌ IPK file not found"
    exit 1
fi

echo "✅ IPK built successfully: $IPK_FILE"

# 创建all-archs目录并复制IPK文件
mkdir -p "bin/all-archs"
cp "$IPK_FILE" "bin/all-archs/"
