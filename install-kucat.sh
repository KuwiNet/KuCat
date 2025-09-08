#!/bin/sh
set -e

##############################
# 0. 函数：检测包是否已装
##############################
pkg_installed(){
    opkg list-installed | grep -q "^$1 "
}

##############################
# 0.1 选择镜像源（新增）
##############################
select_repo(){
    # 如果 stdin 不是终端，则默认 GitHub，避免 CI 卡住
    [ -t 0 ] || {
        REPO_URL="https://github.com/KuwiNet/KuCat.git"
        return
    }

    while :; do
        printf "请选择 KuCat 下载源：\n  1) GitHub (默认)\n  2) Gitee\n请输入序号(1/2)："
        read ans
        case "$ans" in
            2) REPO_URL="https://raw.gitmirror.com/kuwinet/KuCat.git"; break ;;
            1|"") REPO_URL="https://github.com/KuwiNet/KuCat.git"; break ;;
            *) echo "输入无效，请重新选择！" ;;
        esac
    done
    echo "已选择镜像：$REPO_URL"
}
select_repo        # 调用一次，后面统一用 $REPO_URL

##############################
# 1. 依赖（可选）
##############################
NEED_PKG=0
for p in git-http ca-bundle; do
    pkg_installed $p || NEED_PKG=1
done
if [ $NEED_PKG -eq 1 ]; then
    echo "---- 安装依赖 ----"
    opkg update
    opkg install git-http ca-bundle
else
    echo "---- 依赖已满足，跳过安装 ----"
fi

##############################
# 2. 目录变量
##############################
STATIC=/www/luci-static/kucat
LUCI=/usr/lib/lua/luci/view/themes/kucat

##############################
# 3. 克隆/更新静态资源
##############################
[ -d "$STATIC" ] && rm -rf "$STATIC"
git clone "$REPO_URL" /tmp/kucat
mv /tmp/kucat/luci-theme-kucat/htdocs/luci-static/kucat "$STATIC"
mv /tmp/kucat/.git "$STATIC/.git"
rm -rf /tmp/kucat

##############################
# 4. 克隆/更新 Lua 视图
##############################
[ -d "$LUCI" ] && rm -rf "$LUCI"
git clone "$REPO_URL" /tmp/kucat
mv /tmp/kucat/luci-theme-kucat/luasrc/view/themes/kucat "$LUCI"
mv /tmp/kucat/.git "$LUCI/.git"
rm -rf /tmp/kucat

##############################
# 5. 更新任务（可选）
##############################
CRON_MARK='# KuCat-auto-update'
if grep -qF "$CRON_MARK" /etc/crontabs/root; then
    echo "---- 自动更新任务已存在，跳过 ----"
else
    echo "---- 写入自动更新任务 ----"
    # 注意：crontab 里也要用同一个镜像
    cat >> /etc/crontabs/root <<EOF
$CRON_MARK
30 4 * * * cd /www/luci-static/kucat && git pull --quiet >/dev/null 2>&1
30 4 * * * cd /usr/lib/lua/luci/view/themes/kucat && git pull --quiet >/dev/null 2>&1
EOF
    /etc/init.d/cron enable
    /etc/init.d/cron restart
fi

echo "KuCat 主题安装/更新完成！并设置每天 04:30 自动更新！"
