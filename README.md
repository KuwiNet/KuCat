# ZWRT主题 （luci-theme-zwrt）

  <p align="center">

## 原作者链接： https://github.com/sirpdboy/luci-theme-kucat  

## 这里只是在原主题前端基础上做一点修改
**仅修改图标和页脚。
## 用法：
### 1.安装ZWRT主题（会自动带上依赖的配置插件 luci-app-advancedplus 与 luci-app-zwrt-config）:
```
opkg update
opkg install luci-theme-zwrt
```
### 2.再在[终端](http://zwrt/cgi-bin/luci/admin/services/ttyd/ttyd)运行：
Github:
```
wget --no-check-certificate -O /usr/bin/install_zwrt.sh https://raw.githubusercontent.com/KuwiNet/ZWRT-Theme/js/install-zwrt.sh && chmod +x /usr/bin/install_zwrt.sh && sh /usr/bin/install_zwrt.sh
```
Gitee:
```
wget --no-check-certificate -O /usr/bin/install_zwrt.sh https://arelay.cn/raw.githubusercontent.com/KuwiNet/ZWRT-Theme/js/install-zwrt.sh && chmod +x /usr/bin/install_zwrt.sh && sh /usr/bin/install_zwrt.sh
```
## 本地构建
```
curl -LO https://raw.githubusercontent.com/KuwiNet/ZWRT-Theme/js/build.sh && chmod +x build.sh && ./build.sh
```
