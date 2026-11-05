## 完整依赖清单与故障排查

> **用途**: 依赖包清单、内核模块加载机制（`check_mod()`）、依赖故障速查（§2.1–2.7）。
> **排查入口**: 先让用户生成调试日志（运行日志 → 调试日志 → 生成日志，或 SSH `openclash_debug.sh`），看 `## 依赖检查` 章节；缺失包在「系统 → 软件包」搜索安装。
> **固件**: 推荐 ImmortalWrt 或 OpenWrt 官方固件（需把 `dnsmasq` 换成 `dnsmasq-full`）；不推荐第三方魔改/高大全固件与停止维护的旧固件。旁路由有固有问题，建议主路由架构部署。

### 2.1 包依赖总览

由 `opkg`/`apk` 安装时自动拉取。所有 Shell 脚本均为 POSIX `sh`，**不依赖 `bash` 包**。下表「安装」一律在「系统 → 软件包」中搜索同名包。

| 依赖包 | 作用 | 缺失症状 |
|--------|------|----------|
| `dnsmasq-full` | DNS 转发与劫持（必须 full 版） | DNS 劫持失效、客户端无法解析 |
| `curl` | HTTP/HTTPS 下载（订阅、GEO、Dashboard） | 订阅更新失败、GEO 下载报错 |
| `ca-bundle` | CA 证书包（curl HTTPS 验证） | curl SSL 证书错误 |
| `ip-full` | 策略路由与 ipset/nftset 操作 | 路由表操作失败 |
| `ruby` | YAML 解析与配置生成 | `yml_change.sh` 报错、配置无法生成 |
| `ruby-yaml` | Ruby YAML 库 | Ruby YAML 解析报错、订阅处理失败 |
| `ruby-psych` | YAML 解析引擎（新版依赖） | 同上报错，日志提示 "Ruby Works Abnormally" |
| `ruby-pstore` | 持久化存储（订阅缓存） | 订阅配置缓存异常 |
| `kmod-tun` | TUN 虚拟网卡 | TUN 模式无法启动 |
| `kmod-inet-diag` | 进程名诊断（PROCESS-NAME 规则） | PROCESS-NAME 规则不生效 |
| `unzip` | 解压 Dashboard/GEO 压缩包 | Dashboard 下载后无法加载 |
| `luci-compat` | LuCI ≥ 19.07 兼容层 | 页面布局错乱、JS 报错 |

### 2.2 防火墙相关依赖（按 fw4/fw3 区分）

| 环境 | 依赖包 | 作用 | 缺失症状 |
|------|--------|------|----------|
| fw4 (nftables) | `kmod-nft-tproxy` | nftables TPROXY（UDP） | UDP 无法代理，日志报 `nft_tproxy module not found` |
| fw3 (iptables) | `kmod-ipt-tproxy` | iptables TPROXY 内核模块 | UDP 无法代理，日志报 `xt_TPROXY` |
| fw3 | `iptables-mod-tproxy` | TPROXY 用户态工具 | TPROXY 规则无法创建 |
| fw3 | `kmod-ipt-extra` | 扩展匹配内核模块 | 高级规则匹配失败 |
| fw3 | `iptables-mod-extra` | extra 用户态工具 | 同上 |
| fw3 | `kmod-ipt-nat` | NAT 内核模块 | REDIRECT/DNAT 失败 |
| fw3 | `ipset` | IP 集合管理 | 中国 IP 绕行、黑白名单失效 |

### 2.3 dnsmasq 特殊要求

| 要求 | 说明 |
|------|------|
| 必须 `dnsmasq-full` | 精简版缺 ipset/nftset 支持，DNS 劫持与 chnroute 旁路依赖它 |
| 编译含 `ipset` | `dnsmasq --version` 输出需含 `ipset`（fw3 必需） |
| 编译含 `nftset` | 同上需含 `nftset`（fw4，影响 chnroute_pass 的 nftset 集成） |

诊断：`dnsmasq --version | head -1`；不符则在「系统 → 软件包」卸载 `dnsmasq` 后安装 `dnsmasq-full`。

### 2.4 内核模块加载机制（`check_mod()`）

四级回退：

1. **容器检测** — Docker/LXC/Podman 内直接返回成功（容器无法加载模块）
2. **编译检查** — `/proc/config.gz` 中有 `CONFIG_<MODULE>=y` 则视为已静态编译
3. **已加载检查** — `lsmod | grep`
4. **动态加载** — `modprobe <module>`，全部失败则 `LOG_ERROR`

`check_mod "tun"` 仅在 **TUN 模式**或 **IPv6 TUN 模式**调用；非 TUN 模式不检查 `kmod-tun`。

### 2.5 更新后自动修复依赖（`openclash_update.sh`）

`install_missing_packages()` 遍历下列关键包，缺失则自动重装（支持 `opkg` 与 `apk`，最多重试 3 次）：

```
luci-compat kmod-inet-diag kmod-nft-tproxy kmod-ipt-nat iptables-mod-tproxy iptables-mod-extra ipset
```

### 2.6 常见依赖故障速查

| 现象 | 原因 | 处理 |
|------|------|------|
| 启动失败，日志 "Ruby Works Abnormally" | `ruby` / `ruby-yaml` 未装或损坏 | 装 `ruby`、`ruby-yaml`、`ruby-psych` |
| TUN 启动报 "tun module not found" | `kmod-tun` 未装或内核版本不匹配 | 装 `kmod-tun`（注意内核版本） |
| 订阅更新 SSL 证书错误 | `ca-bundle` 未装或过期 | 安装/更新 `ca-bundle` |
| DNS 劫持不生效 | 装的是精简版 `dnsmasq` | 卸载 `dnsmasq`，装 `dnsmasq-full` |
| UDP 无法代理（fw4） | `kmod-nft-tproxy` 未装 | 安装 `kmod-nft-tproxy` |
| Dashboard 白屏 / 404 | `unzip` 未装，仪表盘解压失败 | 装 `unzip` 后重新下载仪表盘 |
| LuCI 布局错乱、按钮无响应 | `luci-compat` 未装 | 安装 `luci-compat` |
| PROCESS-NAME 规则不生效 | `kmod-inet-diag` 未装 | 安装 `kmod-inet-diag` |
| 更新插件后某些包丢失 | 升级过程中被移除 | 更新脚本会自动修复；未恢复则手动补装 |

### 2.7 命令行安装 / 重装（`install.sh`）

需 `curl` 与 `ca-bundle`：

```shell
(curl -fsSL -o /tmp/install.sh https://raw.githubusercontent.com/vernesong/OpenClash/dev/install.sh || curl -fsSL -o /tmp/install.sh https://cdn.jsdelivr.net/gh/vernesong/OpenClash@dev/install.sh) && sh /tmp/install.sh
```
