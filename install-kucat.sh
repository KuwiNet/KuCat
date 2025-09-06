#!/bin/sh
set -e

#############################
# 0. 函数：检测包是否已装
#############################
pkg_installed(){
    opkg list-installed | grep -q "^$1 "
}

#############################
# 1. 依赖（可选）
#############################
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

#############################
# 2. 目录变量
#############################
STATIC=/www/luci-static/kucat
LUCI=/usr/lib/lua/luci/view/themes/kucat

#############################
# 3. 克隆/更新静态资源
#############################
[ -d "$STATIC" ] && rm -rf "$STATIC"
git clone https://github.com/KuwiNet/KuCat.git /tmp/kucat
mv /tmp/kucat/luci-theme-kucat/htdocs/luci-static/kucat "$STATIC"
mv /tmp/kucat/.git "$STATIC/.git"
rm -rf /tmp/kucat

#############################
# 4. 克隆/更新 Lua 视图
#############################
[ -d "$LUCI" ] && rm -rf "$LUCI"
git clone https://github.com/KuwiNet/KuCat.git /tmp/kucat
mv /tmp/kucat/luci-theme-kucat/luasrc/view/themes/kucat "$LUCI"
mv /tmp/kucat/.git "$LUCI/.git"
rm -rf /tmp/kucat

#############################
# 5. 更新任务（可选）
#############################
CRON_MARK='# KuCat-auto-update'
if grep -qF "$CRON_MARK" /etc/crontabs/root; then
    echo "---- 自动更新任务已存在，跳过 ----"
else
    echo "---- 写入自动更新任务 ----"
    cat >> /etc/crontabs/root <<EOF
$CRON_MARK
30 4 * * * cd /www/luci-static/kucat && git pull --quiet >/dev/null 2>&1
30 4 * * * cd /usr/lib/lua/luci/view/themes/kucat && git pull --quiet >/dev/null 2>&1
EOF
    /etc/init.d/cron enable
    /etc/init.d/cron restart
fi

echo "KuCat 主题安装/更新完成！并设置每天 04:30 自动更新！"
