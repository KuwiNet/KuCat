#!/bin/sh
# 文件：/tmp/install-kucat-b.sh
# 用法：sh /tmp/install-kucat-b.sh

set -e

##############################
# 0. 装依赖（git 已装可跳过）
##############################
opkg update
opkg install git-git-http git-nossl ca-bundle

##############################
# 1. 目录变量
##############################
STATIC=/www/luci-static/kucat
LUCI=/usr/lib/lua/luci/view/themes/kucat

##############################
# 2. 克隆/更新静态资源
##############################
[ -d "$STATIC" ] && rm -rf "$STATIC"
git clone https://github.com/KuwiNet/KuCat.git /tmp/kucat
mv /tmp/kucat/luci-theme-kucat/htdocs/luci-static/kucat "$STATIC"
# 保留 .git 方便以后 pull
mv /tmp/kucat/.git "$STATIC/.git"
rm -rf /tmp/kucat

##############################
# 3. 克隆/更新 Lua 视图
##############################
[ -d "$LUCI" ] && rm -rf "$LUCI"
git clone https://github.com/KuwiNet/KuCat.git /tmp/kucat
mv /tmp/kucat/luci-theme-kucat/luasrc/view/themes/kucat "$LUCI"
# 保留 .git 方便以后 pull
mv /tmp/kucat/.git "$LUCI/.git"
rm -rf /tmp/kucat

##############################
# 4. 写自更新任务（方案 B）
##############################
cat > /etc/uci-defaults/99-kucat-auto <<'EOF'
#!/bin/sh
# 每天 04:30 同时更新两份主题
echo '30 4 * * * cd /www/luci-static/kucat && git pull --quiet >/dev/null 2>&1' >> /etc/crontabs/root
echo '30 4 * * * cd /usr/lib/lua/luci/view/themes/kucat && git pull --quiet >/dev/null 2>&1' >> /etc/crontabs/root
/etc/init.d/cron enable
/etc/init.d/cron restart
rm -f "$0"          # 只运行一次
EOF
chmod +x /etc/uci-defaults/99-kucat-auto

##############################
# 5. 立即生效
##############################
/etc/uci-defaults/99-kucat-auto

echo "KuCat 主题安装完成，且已设置每天 04:30 自动更新（含 Lua 视图）！"
