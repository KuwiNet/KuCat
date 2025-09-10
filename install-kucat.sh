#!/bin/sh
set -e

######## 工具函数 ########
pkg_installed(){
    opkg status "$1" >/dev/null 2>&1
}
cmd_exists(){
    command -v "$1" >/dev/null 2>&1
}
_green()  { printf '\033[32m%b\033[0m\n' "$*"; }
_yellow() { printf '\033[33m%b\033[0m\n' "$*"; }

######## 选择镜像 ########
select_repo(){
    [ -t 0 ] || { REPO_URL="https://github.com/KuwiNet/KuCat.git"; return; }
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

######## 确保 cron 已安装并启用 ########
ensure_cron(){
    if ! cmd_exists crond; then
        echo "---- 安装并启用 cron ----"
        opkg update >/dev/null
        opkg install cronie >/dev/null 2>&1 || opkg install busybox-cron >/dev/null 2>&1
        /etc/init.d/cron enable
        /etc/init.d/cron start >/dev/null 2>&1
    fi
    mkdir -p /etc/crontabs
    touch /etc/crontabs/root
}

######## 主流程 ########
select_repo
ensure_cron

## 1. 依赖：仅当命令/文件缺失才安装
need=0
cmd_exists git     || need=1
cmd_exists rsync   || need=1
[ -f /usr/libexec/git-core/git-remote-https ] || need=1
pkg_installed ca-bundle || need=1

if [ "$need" -eq 0 ]; then
    echo "---- 依赖已满足，跳过安装 ----"
else
    echo "---- 依赖缺失，正在安装 ----"
    opkg update >/dev/null
    opkg install git git-http ca-bundle rsync >/dev/null
    rm -rf /tmp/opkg-*
fi

## 2. 目录变量
STATIC=/www/luci-static/kucat
LUCI=/usr/lib/lua/luci/view/themes/kucat
TMP=/tmp/kucat-$$
EXCLUDE=$TMP.exclude

## 3. 生成排除列表（临时文件，用完即删）
cat > "$EXCLUDE" <<'EOF'
/.git
/README.md
/install_kucat.sh
EOF

## 4. 克隆并同步
echo "---- 获取 KuCat 最新文件 ----"
[ -d "$TMP" ] && rm -rf "$TMP"
git clone --depth 1 "$REPO_URL" "$TMP"

[ -d "$STATIC" ] && rm -rf "$STATIC"
mkdir -p "$STATIC"
rsync -a --exclude-from="$EXCLUDE" "$TMP/luci-theme-kucat/htdocs/luci-static/kucat/" "$STATIC/"

[ -d "$LUCI" ] && rm -rf "$LUCI"
mkdir -p "$LUCI"
rsync -a --exclude-from="$EXCLUDE" "$TMP/luci-theme-kucat/luasrc/view/themes/kucat/" "$LUCI/"

## 5. 清理临时文件
rm -rf "$TMP" "$EXCLUDE"

## 6. 写入定时更新任务（非交互强制 Gitee）
CRON_MARK='# KuCat-daily-install'
if grep -qF "$CRON_MARK" /etc/crontabs/root; then
    echo "---- 定时安装任务已存在，跳过 ----"
else
    _yellow "---- 写入每天 03:40 定时安装任务 ----"
    printf '%s\n' "$CRON_MARK" \
           "40 3 * * * export REPO_URL=https://gitee.com/kuwinet/KuCat.git && /usr/bin/install_kucat.sh >/dev/null 2>&1" \
           >> /etc/crontabs/root
    /etc/init.d/cron restart >/dev/null 2>&1
fi

## 7. 立即重载 Web 服务器
if [ -x /etc/init.d/uhttpd ]; then
    /etc/init.d/uhttpd restart >/dev/null 2>&1
elif [ -x /etc/init.d/nginx ]; then
    /etc/init.d/nginx restart >/dev/null 2>&1
else
    killall -HUP uhttpd 2>/dev/null || killall -HUP nginx 2>/dev/null || true
fi

_green "KuCat 主题安装完成！已设置每天 03:40 自动更新！"
