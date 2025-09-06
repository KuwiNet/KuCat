# KuCat主题 （luci-theme-kucat）

  <p align="center">

## 原作者链接： https://github.com/sirpdboy/luci-theme-kucat  

## 这里只是在原主题前端基础上做一点修改
**仅修改图标和页脚。
## 用法：
### 一、直接安装
```
wget https://github.com/KuwiNet/KuCat/releases/download/v2.6.15/luci-theme-kucat_2.6.15-r20250822_all.ipk && opkg install luci-theme-kucat_2.6.15-r20250822_all.ipk
```
### 二、仅更新前端
1、安装KuCat主题:
```
opkg update
opkg install luci-theme-kucat
opkg install luci-app-advancedplus
```
2、[终端](http://zwrt/cgi-bin/luci/admin/services/ttyd/ttyd)运行：
```
wget --no-check-certificate -O /tmp/install-kucat.sh https://raw.githubusercontent.com/KuwiNet/KuCat/js/install-kucat.sh && chmod +x /tmp/install-kucat.sh && sh /tmp/install-kucat.sh
```
