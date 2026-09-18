<div align="center">

<img src="https://raw.githubusercontent.com/vernesong/OpenClash/dev/img/logo.png" alt="OpenClash" width="160" />

# OpenClash

一个可运行在 OpenWrt 上的 [Mihomo (Clash Meta)](https://github.com/MetaCubeX/mihomo) 客户端

[![License](https://img.shields.io/github/license/vernesong/OpenClash?style=flat-square&color=brightgreen)](LICENSE)
[![Release](https://img.shields.io/github/v/release/vernesong/OpenClash?style=flat-square)](https://github.com/vernesong/OpenClash/releases)
[![Downloads](https://img.shields.io/github/downloads/vernesong/OpenClash/total?style=flat-square)](https://github.com/vernesong/OpenClash/releases)
[![OpenWrt](https://img.shields.io/badge/OpenWrt-18.06%2B-00B5E2?style=flat-square&logo=openwrt&logoColor=white)](https://openwrt.org/)
[![Telegram](https://img.shields.io/badge/Telegram-OpenClash%20Group-2CA5E0?style=flat-square&logo=telegram&logoColor=white)](https://t.me/openclash_group)

</div>

## 简介

OpenClash 是一个面向 OpenWrt 的 LuCI 插件，用于管理 [Mihomo](https://github.com/MetaCubeX/mihomo)（原 Clash Meta）内核，兼容 Shadowsocks、ShadowsocksR、VMess、VLESS、Trojan、Snell、TUIC、Hysteria 等主流协议，通过灵活的规则配置实现按需分流与透明代理。

## 功能特性

| 模块 | 说明 |
|------|------|
| 内核 | 内置 Mihomo（Meta）与 Smart 智能内核，支持在线更新与切换 |
| 运行模式 | redir-host / fake-ip 与混合模式、TUN 模式，兼容 iptables 与 nftables |
| 订阅管理 | 多订阅并存，支持 Subconverter 在线转换、自定义 User-Agent 与请求头 |
| 配置管理 | 多配置文件一键切换、在线编辑、备份/恢复、Age 加密 |
| 访问控制 | 黑白名单、自定义防火墙规则 |
| 流媒体 | Netflix / Disney+ / HBO 等自动选线 |
| 覆写设置 | 模块化覆写 YAML，方便配置文件定制 |

## 目录

- [简介](#简介)
- [功能特性](#功能特性)
- [快速开始](#快速开始)
- [使用手册](#使用手册)
- [下载](#下载)
- [依赖](#依赖)
- [源码编译](#源码编译)
- [致谢](#致谢)
- [请作者喝杯咖啡](#请作者喝杯咖啡)
- [许可证](#许可证)

## 快速开始

### 网页安装

1. 从 [Release 页面](https://github.com/vernesong/OpenClash/releases) 下载对应架构的安装包（`*.ipk` 或 `*.apk`）；
2. 登录 OpenWrt 的 LuCI 后台，前往 **系统 → 软件包** 上传并安装；
3. 刷新或者重新登录页面，在 **服务 → OpenClash** 中导入订阅或上传配置文件并启动。

### 命令行安装

安装依赖并下载最新版（iptables 防火墙）：

```shell
# opkg 系统（ipk）
opkg update
opkg install bash iptables dnsmasq-full curl ca-bundle ipset ip-full iptables-mod-tproxy iptables-mod-extra ruby ruby-yaml kmod-tun kmod-inet-diag unzip luci-compat luci luci-base
curl -L --retry 2 https://api.github.com/repos/vernesong/OpenClash/releases/latest -o /tmp/openclash_version
[ -f "/tmp/openclash_version" ] && download_url=$(cat /tmp/openclash_version | jsonfilter -e '@.assets[*].browser_download_url' | grep '\.ipk$') && curl -L --retry 2 "$download_url" -o /tmp/openclash.ipk || echo "OpenClash last version get failed"
[ -f "/tmp/openclash.ipk" ] && opkg install /tmp/openclash.ipk || echo "OpenClash download failed"

# apk 系统（apk）
apk update
apk add bash iptables dnsmasq-full curl ca-bundle ipset ip-full iptables-mod-tproxy iptables-mod-extra ruby ruby-yaml kmod-tun kmod-inet-diag unzip luci-compat luci luci-base
curl -L --retry 2 https://api.github.com/repos/vernesong/OpenClash/releases/latest -o /tmp/openclash_version
[ -f "/tmp/openclash_version" ] && download_url=$(cat /tmp/openclash_version | jsonfilter -e '@.assets[*].browser_download_url' | grep '\.apk$') && curl -L --retry 2 "$download_url" -o /tmp/openclash.apk || echo "OpenClash last version get failed"
[ -f "/tmp/openclash.apk" ] && apk add -q --force-overwrite --clean-protected --allow-untrusted /tmp/openclash.apk || echo "OpenClash download failed"
```

安装依赖并下载最新版（nftables 防火墙，Firewall4）：

```shell
# opkg 系统（ipk）
opkg update
opkg install bash dnsmasq-full curl ca-bundle ip-full ruby ruby-yaml kmod-tun kmod-inet-diag unzip kmod-nft-tproxy luci-compat luci luci-base
curl -L --retry 2 https://api.github.com/repos/vernesong/OpenClash/releases/latest -o /tmp/openclash_version
[ -f "/tmp/openclash_version" ] && download_url=$(cat /tmp/openclash_version | jsonfilter -e '@.assets[*].browser_download_url' | grep '\.ipk$') && curl -L --retry 2 "$download_url" -o /tmp/openclash.ipk || echo "OpenClash last version get failed"
[ -f "/tmp/openclash.ipk" ] && opkg install /tmp/openclash.ipk || echo "OpenClash download failed"

# apk 系统（apk）
apk update
apk add bash dnsmasq-full curl ca-bundle ip-full ruby ruby-yaml kmod-tun kmod-inet-diag unzip kmod-nft-tproxy luci-compat luci luci-base
curl -L --retry 2 https://api.github.com/repos/vernesong/OpenClash/releases/latest -o /tmp/openclash_version
[ -f "/tmp/openclash_version" ] && download_url=$(cat /tmp/openclash_version | jsonfilter -e '@.assets[*].browser_download_url' | grep '\.apk$') && curl -L --retry 2 "$download_url" -o /tmp/openclash.apk || echo "OpenClash last version get failed"
[ -f "/tmp/openclash.apk" ] && apk add -q --force-overwrite --clean-protected --allow-untrusted /tmp/openclash.apk || echo "OpenClash download failed"
```

> 首次使用需要下载内核，请提前确认网络环境

## 使用手册

- [Wiki](https://github.com/vernesong/OpenClash/blob/dev/.github/skills/openclash-user-guide/SKILL.md)

## 下载

最新版本请前往 [Releases](https://github.com/vernesong/OpenClash/releases/latest) 页面，按需选择对应的安装包：

| 安装包 | 说明 |
|--------|------|
| `luci-app-openclash_*.ipk` | opkg 安装包 |
| `luci-app-openclash-*.apk` | apk 安装包 |

> 历史版本请前往 [全部 Releases](https://github.com/vernesong/OpenClash/releases) 查看。

## 依赖

| 类别 | 依赖 |
|------|------|
| 基础 | luci、luci-base、luci-compat（Luci ≥ 19.07） |
| 运行时 | bash、curl、ca-bundle、ruby、ruby-yaml |
| 网络 | dnsmasq-full、ipset、ip-full、unzip |
| 防火墙（iptables） | iptables、kmod-ipt-nat、iptables-mod-tproxy、iptables-mod-extra |
| 防火墙（nftables） | kmod-nft-tproxy（Firewall4） |
| 可选 | kmod-tun（TUN 模式）、ip6tables-mod-nat（IPv6）、kmod-inet-diag（PROCESS-NAME） |

## 源码编译

从 OpenWrt 的 [SDK](https://archive.openwrt.org/chaos_calmer/15.05.1/ar71xx/generic/OpenWrt-SDK-15.05.1-ar71xx-generic_gcc-4.8-linaro_uClibc-0.9.33.2.Linux-x86_64.tar.bz2) 编译：

```bash
# 解压下载好的 SDK
curl -SLk --connect-timeout 30 --retry 2 "https://archive.openwrt.org/chaos_calmer/15.05.1/ar71xx/generic/OpenWrt-SDK-15.05.1-ar71xx-generic_gcc-4.8-linaro_uClibc-0.9.33.2.Linux-x86_64.tar.bz2" -o "/tmp/SDK.tar.bz2"
cd /tmp
tar xjf SDK.tar.bz2
cd OpenWrt-SDK-15.05.1-*

# Clone 项目
mkdir package/luci-app-openclash
cd package/luci-app-openclash
git init
git remote add -f origin https://github.com/vernesong/OpenClash.git
git config core.sparsecheckout true
echo "luci-app-openclash" >> .git/info/sparse-checkout
git pull --depth 1 origin master
git branch --set-upstream-to=origin/master master

# 编译 po2lmo (如果有 po2lmo 可跳过)
pushd luci-app-openclash/tools/po2lmo
make && sudo make install
popd

# 编译最新 CodeMirror 6 (插件内置，可跳过)
pushd luci-app-openclash/tools/codemirror
npm install
npx esbuild entry.js --bundle --format=iife --global-name=CM6 --minify --target=es2019 --outfile=../../root/www/luci-static/resources/openclash/js/cm6.min.js --legal-comments=none --loader:.css=text
rm -rf node_modules
popd

# 开始编译

# 先回退到 SDK 主目录
cd ../..
make package/luci-app-openclash/luci-app-openclash/compile V=99

# IPK 文件位置
./bin/ar71xx/packages/base/luci-app-openclash_*-beta_all.ipk
```

```bash
# 同步源码
cd package/luci-app-openclash/luci-app-openclash
git pull

# 您也可以直接拷贝 `luci-app-openclash` 文件夹至其他 `OpenWrt` 项目的 `Package` 目录下随固件编译

make menuconfig
# 选择要编译的包 LuCI -> Applications -> luci-app-openclash

```

## 致谢

OpenClash 的构建离不开以下开源项目与数据服务：

| 类别 | 项目 | 作者 / 组织 | 说明 |
|------|------|-------------|------|
| 内核 | [Mihomo](https://github.com/MetaCubeX/mihomo) | [MetaCubeX](https://github.com/MetaCubeX) | 代理内核（Clash Meta） |
| 代码基础 | [Luci For Clash](https://github.com/frainzy1477/luci-app-clash) | [frainzy1477](https://github.com/frainzy1477) | 本项目代码基于此 |
| 控制面板 | [metacubexd](https://github.com/MetaCubeX/metacubexd) | [MetaCubeX](https://github.com/MetaCubeX) | 默认内置面板 |
| 控制面板 | [zashboard](https://github.com/Zephyruso/zashboard) | [Zephyruso](https://github.com/Zephyruso) | 内置面板 |
| 控制面板 | [Yacd-meta](https://github.com/MetaCubeX/Yacd-meta) | [MetaCubeX](https://github.com/MetaCubeX) | 内置面板，基于 [yacd](https://github.com/haishanh/yacd) |
| 控制面板 | [Razord-meta](https://github.com/MetaCubeX/Razord-meta) | [MetaCubeX](https://github.com/MetaCubeX) | 内置面板（Dashboard） |
| 订阅转换 | [subconverter](https://github.com/tindy2013/subconverter) | [tindy2013](https://github.com/tindy2013) | 在线订阅转换 |
| GEO / IP 数据 | [v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat) | [Loyalsoldier](https://github.com/Loyalsoldier) | GeoIP / GeoSite 数据 |
| GEO / IP 数据 | [meta-rules-dat](https://github.com/MetaCubeX/meta-rules-dat) | [MetaCubeX](https://github.com/MetaCubeX) | GeoSite 规则数据 |
| GEO / IP 数据 | [mmdb_china_ip_list](https://github.com/alecthw/mmdb_china_ip_list) | [alecthw](https://github.com/alecthw) | 中国 IP 列表 MMDB |
| GEO / IP 数据 | [china-operator-ip](https://github.com/gaoyifan/china-operator-ip) | [gaoyifan](https://github.com/gaoyifan) | 运营商 IP 列表 |
| 规则模板 | [ACL4SSR](https://github.com/ACL4SSR/ACL4SSR) | [ACL4SSR](https://github.com/ACL4SSR) | 订阅转换规则模板 |
| 规则模板 | [Custom_OpenClash_Rules](https://github.com/Aethersailor/Custom_OpenClash_Rules) | [Aethersailor](https://github.com/Aethersailor) | 订阅转换规则模板 |
| 流媒体检测 | [RegionRestrictionCheck](https://github.com/lmc999/RegionRestrictionCheck) | [lmc999](https://github.com/lmc999) | 流媒体解锁检测 |
| IP 检查 | [ip.skk.moe](https://ip.skk.moe/) | [SukkaW](https://ip.skk.moe/) | 公网 IP 检测 |
| 编辑器 | [CodeMirror](https://codemirror.net/) | [Marijn Haverbeke](https://github.com/marijnh) | 内置编辑器 |

## 请作者喝杯咖啡

* PayPal

<p align="left">
    <a href='https://ko-fi.com/H2H41G5LS' target='_blank'><img height='36' style='border:0px;height:36px;' src='https://storage.ko-fi.com/cdn/kofi6.png?v=6' border='0' alt='Buy Me a Coffee at ko-fi.com' /></a>
</p>

* USDT-BSC

<p align="left">
    <img width="300" src="https://github.com/vernesong/OpenClash/raw/master/img/USDT-Wallet.png">
</p>

## 许可证

本项目基于 [MIT License](LICENSE) 开源。