#!/bin/sh
set -e

# 0. 检测软件包是否已安装
pkg_installed(){
    opkg status "$1" >/dev/null 2>&1
}

# 0.1 选择镜像源（非终端则默认 GitHub）
select_repo(){
    [ -t 0 ] || {
        REPO_URL="https://github.com/KuwiNet/KuCat.git"
        return
    }
    while :; do
        printf "请选择 KuCat 下载源：\n  1) GitHub (默认)\n  2) Gitee\n请输入序号(1/2)："
        read ans
        case "$ans" in
            2) REPO_URL="https://gitee.com/kuwinet/KuCat.git"; break ;;
            1|"") REPO_URL="https://github.com/KuwiNet/KuCat.git"; break ;;
            *) echo "输入无效，请重新选择！" ;;
        esac
    done
    echo "已选择镜像：$REPO_URL"
}
select_repo

# 1. 安装依赖（git、ca-bundle、rsync）
NEED_PKG=0
for p in git-http ca-bundle rsync; do
    pkg_installed "$p" || NEED_PKG=1
done
if [ $NEED_PKG -eq 1 ]; then
    echo "---- 安装依赖 ----"
    opkg update
    opkg install git-http ca-bundle rsync
    # 立即清除 opkg 临时缓存
    rm -rf /tmp/opkg-*
else
    echo "---- 依赖已满足，跳过安装 ----"
fi

# 2. 目录变量
STATIC=/www/luci-static/kucat
LUCI=/usr/lib/lua/luci/view/themes/kucat
TMP=/tmp/kucat-$$
EXCLUDE=$TMP.exclude

# 3. 准备排除列表
cat > "$EXCLUDE" <<'EOF'
/.git
/README.md
/install_kucat.sh
EOF

# 4. 克隆并拷贝文件（完全排除 .git 等）
echo "---- 获取 KuCat 最新文件 ----"
git clone --depth 1 "$REPO_URL" "$TMP"

# 静态资源
[ -d "$STATIC" ] && rm -rf "$STATIC"
mkdir -p "$STATIC"
rsync -a --exclude-from="$EXCLUDE" "$TMP/luci-theme-kucat/htdocs/luci-static/kucat/" "$STATIC/"

# Lua 视图
[ -d "$LUCI" ] && rm -rf "$LUCI"
mkdir -p "$LUCI"
rsync -a --exclude-from="$EXCLUDE" "$TMP/luci-theme-kucat/luasrc/view/themes/kucat/" "$LUCI/"

# 清理临时目录
rm -rf "$TMP" "$EXCLUDE"

# 5. 定时任务：每天 03:40 完整运行本脚本（非交互，强制 Gitee）
CRON_MARK='# KuCat-daily-install'
if grep -qF "$CRON_MARK" /etc/crontabs/root; then
    echo "---- 定时安装任务已存在，跳过 ----"
else
    echo "---- 写入每天 03:40 定时安装任务 ----"
    cat >> /etc/crontabs/root <<EOF
$CRON_MARK
40 3 * * * export REPO_URL=https://gitee.com/kuwinet/KuCat.git && /usr/bin/install_kucat.sh >/dev/null 2>&1
EOF
    /etc/init.d/cron enable
    /etc/init.d/cron restart
fi

# 6. 立即生效（兼容 nginx/uhttpd）
if [ -x /etc/init.d/uhttpd ]; then
    /etc/init.d/uhttpd restart
elif [ -x /etc/init.d/nginx ]; then
    /etc/init.d/nginx restart
else
    killall -HUP uhttpd 2>/dev/null || killall -HUP nginx 2>/dev/null || true
fi

echo "KuCat 主题安装完成！已设置每天 03:40 自动更新！"
