# KuCat主题 （luci-theme-kucat）

  <p align="center">

## 原作者链接： https://github.com/sirpdboy/luci-theme-kucat  

## 这里只是在原主题前端基础上做一点修改
**仅修改图标和页脚。
## 用法：
### 1.先安装KuCat主题:
```
opkg update
opkg install luci-theme-kucat
opkg install luci-app-advancedplus
```
### 2.再在[终端](http://zwrt/cgi-bin/luci/admin/services/ttyd/ttyd)运行：
```
Github:
wget --no-check-certificate -O /tmp/install-kucat.sh https://raw.githubusercontent.com/KuwiNet/KuCat/js/install-kucat.sh && chmod +x /tmp/install-kucat.sh && sh /tmp/install-kucat.sh
```
Gitee:
```
wget --no-check-certificate -O /tmp/install-kucat.sh https://gitee.com/kuwinet/KuCat/raw/js/install-kucat.sh && chmod +x /tmp/install-kucat.sh && sh /tmp/install-kucat.sh
```
## 构建
```
curl -LO https://raw.githubusercontent.com/KuwiNet/KuCat/js/build_auto.sh && chmod +x build_auto.sh && ./build_auto.sh
```
