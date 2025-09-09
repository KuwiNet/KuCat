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

# 5. 定时任务（同样排除 .git 等）
CRON_MARK='# KuCat-auto-update'
if grep -qF "$CRON_MARK" /etc/crontabs/root; then
    echo "---- 自动更新任务已存在，跳过 ----"
else
    echo "---- 写入自动更新任务 ----"
    cat >> /etc/crontabs/root <<EOF
$CRON_MARK
30 4 * * * TMP=/tmp/kucat-\$\$; git clone --depth 1 $REPO_URL \$TMP >/dev/null 2>&1 && \\
  rsync -a --exclude='/.git' --exclude='/README.md' --exclude='/install_KuCat.sh' \\
        \$TMP/luci-theme-kucat/htdocs/luci-static/kucat/ $STATIC/ && \\
  rsync -a --exclude='/.git' --exclude='/README.md' --exclude='/install_KuCat.sh' \\
        \$TMP/luci-theme-kucat/luasrc/view/themes/kucat/ $LUCI/ && \\
  rm -rf \$TMP
EOF
    /etc/init.d/cron enable
    /etc/init.d/cron restart
fi

# 6. 立即生效
/etc/init.d/uhttpd restart

echo "KuCat 主题安装/更新完成！并设置每天 04:30 自动更新！"
