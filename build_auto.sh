#!/bin/bash
set -e

# 配置参数
CSS_DIR="temp_css"
TEMP_DIR="temp_repack"
FINAL_IPK="bin/all-archs/luci-theme-kucat_2.6.15-r20250911_all.ipk"

# 创建必要目录
mkdir -p "$CSS_DIR" "$TEMP_DIR" bin/all-archs

# 下载CSS文件
echo "? 下载未压缩 CSS..."
curl -fsSL https://raw.githubusercontent.com/KuwiNet/KuCat/js/luci-theme-kucat/htdocs/luci-static/kucat/css/theme.css -o "$CSS_DIR/theme.css"
echo "   ✔ theme.css"
curl -fsSL https://raw.githubusercontent.com/KuwiNet/KuCat/js/luci-theme-kucat/htdocs/luci-static/kucat/css/style.css -o "$CSS_DIR/style.css"
echo "   ✔ style.css"

# 检查CSS文件是否存在
if [ ! -f "$CSS_DIR/theme.css" ] || [ ! -f "$CSS_DIR/style.css" ]; then
    echo "❌ 错误：找不到CSS文件 in $CSS_DIR"
    exit 1
fi

# IPK重打包函数
repack_all_ipk() {
    local src_ipk="$1"
    local dst_ipk="$2"
    local tmpdir=$(mktemp -d --tmpdir="$TEMP_DIR" 2>/dev/null || mktemp -d)

    echo "? 解包原始 IPK: $src_ipk"
    cd "$tmpdir"

    # 使用bsdtar或ar解包
    if command -v bsdtar >/dev/null; then
        echo "ℹ️ 使用bsdtar解包..."
        bsdtar -xf "$src_ipk" || { echo "❌ bsdtar解包失败"; exit 1; }
    else
        echo "ℹ️ 使用ar解包..."
        ar x "$src_ipk" || { echo "❌ ar解包失败"; exit 1; }
    fi

    # 解压内部文件
    tar -xzf data.tar.gz || { echo "❌ 解包data.tar.gz失败"; exit 1; }
    tar -xzf control.tar.gz || { echo "❌ 解包control.tar.gz失败"; exit 1; }

    # 替换CSS文件
    mkdir -p htdocs/luci-static/kucat/css
    cp "$CSS_DIR"/*.css htdocs/luci-static/kucat/css/
    echo "✅ 已替换CSS文件"

    # 重新打包为符合规范的IPK
    echo "2.0" > debian-binary
    gzip -9nc control.tar > control.tar.gz
    gzip -9nc data.tar > data.tar.gz
    
    # 使用ar创建标准格式的IPK
    ar cr "$dst_ipk" \
        debian-binary \
        control.tar.gz \
        data.tar.gz

    # 验证IPK格式
    if ! ar t "$dst_ipk" >/dev/null 2>&1; then
        echo "❌ 生成的IPK文件格式不正确" >&2
        exit 1
    fi

    cd - > /dev/null
    rm -rf "$tmpdir"
    echo "✅ 重新打包完成: $dst_ipk"
}

# 主流程
if [ -f "$1" ]; then
    repack_all_ipk "$1" "$FINAL_IPK"
else
    echo "❌ 错误：找不到原始IPK文件"
    exit 1
fi
