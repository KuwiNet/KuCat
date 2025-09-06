#!/bin/sh
set -e

# 0. 依赖（仅 git-http 已含 https 支持）
opkg update
opkg install git-http ca-bundle

# 1. 目录变量
STATIC=/www/luci-static/kucat
LUCI=/usr/lib/lua/luci/view/themes/kucat

# 2. 静态资源
[ -d "$STATIC" ] && rm -rf "$STATIC"
git clone https://github.com/KuwiNet/KuCat.git /tmp/kucat
mv /tmp/kucat/luci-theme-kucat/htdocs/luci-static/kucat "$STATIC"
mv /tmp/kucat/.git "$STATIC/.git"
rm -rf /tmp/kucat

# 3. Lua 视图
[ -d "$LUCI" ] && rm -rf "$LUCI"
git clone https://github.com/KuwiNet/KuCat.git /tmp/kucat
mv /tmp/kucat/luci-theme-kucat/luasrc/view/themes/kucat "$LUCI"
mv /tmp/kucat/.git "$LUCI/.git"
rm -rf /tmp/kucat

# 4. 自更新任务
cat > /etc/uci-defaults/99-kucat-auto <<'EOS'
#!/bin/sh
echo '30 4 * * * cd /www/luci-static/kucat && git pull --quiet' >> /etc/crontabs/root
echo '30 4 * * * cd /usr/lib/lua/luci/view/themes/kucat && git pull --quiet' >> /etc/crontabs/root
/etc/init.d/cron enable
/etc/init.d/cron restart
rm -f "$0"
EOS
chmod +x /etc/uci-defaults/99-kucat-auto

# 5. 立即生效
/etc/uci-defaults/99-kucat-auto
echo "KuCat 主题安装完成，已含 Lua 视图，每天 04:30 自动更新！"
