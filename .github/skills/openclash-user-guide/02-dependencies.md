## 完整依赖清单与故障排查

> **用途**: 依赖包清单、内核模块加载机制（`check_mod()`）与依赖故障排查速查（§2.1–2.6）。

> **AI 行为指引**: 当用户报告启动失败、功能异常时，AI 应**先让用户生成调试日志**（LuCI「运行日志」→「生成日志」或 SSH `openclash_debug.sh`），然后对照日志中的 `## 依赖检查` 章节检查依赖完整性。对于缺失的依赖，指导用户在 LuCI 的「系统 → 软件包」中搜索安装。
>
> **固件提醒**: 推荐使用 ImmortalWrt 或 OpenWrt 官方固件（需自行将 `dnsmasq` 替换为 `dnsmasq-full`）。不推荐使用第三方魔改/高大全固件、以及已停止维护的旧版固件。旁路由组网存在固有的网络层面缺陷，强烈建议采用主路由架构部署 OpenClash。

### 2.1 包依赖总览（来自 Makefile DEPENDS 和 init.d 运行时检查）

OpenClash 依赖以下软件包，由 `opkg`/`apk` 在安装时自动拉取。若手动卸载了其中某个包，会导致对应功能异常。

| 依赖包 | 作用 | 缺失症状 | 安装命令 (LuCI) |
|--------|------|----------|-----------------|
| `dnsmasq-full` | DNS 转发与劫持（必须用 full 版，非精简版） | DNS 劫持失效、客户端无法解析域名 | 「系统→软件包」搜索 `dnsmasq-full` |
| `bash` | 所有 Shell 脚本的解释器 | 启动脚本执行失败 | 搜索 `bash` |
| `curl` | HTTP/HTTPS 下载（订阅、GEO、Dashboard） | 订阅更新失败、GEO 下载报错 | 搜索 `curl` |
| `ca-bundle` | CA 证书包（curl HTTPS 验证） | curl SSL 证书错误 | 搜索 `ca-bundle` |
| `ip-full` | 策略路由和 ipset/nftset 操作 | 路由表操作失败 | 搜索 `ip-full` |
| `ruby` | YAML 解析与配置生成 | `yml_change.sh` 报错、配置无法生成 | 搜索 `ruby` |
| `ruby-yaml` | Ruby YAML 库 | Ruby YAML 解析报错、订阅处理失败 | 搜索 `ruby-yaml` |
| `ruby-psych` | Ruby YAML 解析引擎（新版依赖） | 同上，日志提示 "Ruby Works Abnormally" | 搜索 `ruby-psych` |
| `ruby-pstore` | Ruby 持久化存储（订阅缓存） | 订阅配置缓存异常 | 搜索 `ruby-pstore` |
| `kmod-tun` | TUN 虚拟网卡内核模块 | TUN 模式无法启动 | 搜索 `kmod-tun` |
| `kmod-inet-diag` | 进程名诊断（PROCESS-NAME 规则） | PROCESS-NAME 规则不生效 | 搜索 `kmod-inet-diag` |
| `unzip` | 解压 Dashboard/GEO 等压缩包 | Dashboard 下载后无法加载 | 搜索 `unzip` |
| `luci-compat` | LuCI >= 19.07 兼容层（新版 LuCI 必装） | LuCI 页面布局错乱、JS 报错 | 搜索 `luci-compat` |

### 2.2 防火墙相关依赖（按 fw4/fw3 自动区分）

| 环境 | 依赖包 | 作用 | 缺失症状 | 安装命令 (LuCI) |
|------|--------|------|----------|-----------------|
| **fw4 (nftables)** | `kmod-nft-tproxy` | nftables TPROXY 透明代理（UDP） | UDP 无法代理、启动日志报 "nft_tproxy module not found" | 搜索 `kmod-nft-tproxy` |
| **fw3 (iptables)** | `kmod-ipt-tproxy` | iptables TPROXY 模块 | UDP 无法代理、日志报 "xt_TPROXY" | 搜索 `kmod-ipt-tproxy` |
| **fw3 (iptables)** | `iptables-mod-tproxy` | iptables TPROXY 用户态工具 | TPROXY 规则无法创建 | 搜索 `iptables-mod-tproxy` |
| **fw3 (iptables)** | `kmod-ipt-extra` | iptables 扩展匹配模块 | 高级规则匹配失败 | 搜索 `kmod-ipt-extra` |
| **fw3 (iptables)** | `iptables-mod-extra` | iptables extra 用户态工具 | 同上 | 搜索 `iptables-mod-extra` |
| **fw3 (iptables)** | `kmod-ipt-nat` | iptables NAT 内核模块 | REDIRECT/DNAT 规则失败 | 搜索 `kmod-ipt-nat` |
| **fw3 (iptables)** | `ipset` | IP 集合管理工具 | 中国 IP 绕行、黑白名单失效 | 搜索 `ipset` |

### 2.3 dnsmasq 特殊要求

| 要求 | 说明 |
|------|------|
| **必须使用 `dnsmasq-full`** | OpenWrt 自带的 `dnsmasq` 精简版缺少 ipset/nftset 支持，OpenClash 的 DNS 劫持和 chnroute 旁路依赖此功能 |
| **ipset 编译选项** | `dnsmasq --version` 输出需包含 `ipset`（fw3 环境必需） |
| **nftset 编译选项** | `dnsmasq --version` 输出需包含 `nftset`（fw4 环境，影响 chnroute_pass 的 nftset 集成） |

> **诊断方法**: 先在 LuCI 的「运行日志」页面生成调试日志，在日志的依赖检查段确认 dnsmasq 版本。如需手动确认，可在路由器终端执行 `dnsmasq --version | head -1`。
> 如果不是，在 LuCI 的「系统 → 软件包」中卸载 `dnsmasq` 然后安装 `dnsmasq-full`。

### 2.4 内核模块加载机制（`check_mod()` 函数）

`init.d/openclash` 的 `check_mod()` 函数以四级回退方式检查和加载内核模块：

1. **容器检测** — 检测 Docker/LXC/Podman 等容器环境，容器内直接返回成功（无法加载内核模块）
2. **内核编译检查** — 检查 `/proc/config.gz` 中是否有 `CONFIG_<MODULE>=y`（静态编译进内核，无需 modprobe）
3. **已加载检查** — `lsmod | grep` 检查模块是否已在内核中加载
4. **动态加载尝试** — `modprobe <module>` 尝试加载，全部失败则输出 `LOG_ERROR`

> **TUN 模块注意事项**: `check_mod "tun"` 仅在 **TUN 模式** 或 **IPv6 TUN 模式** 时才被调用。Redir-Host/Fake-IP（非 TUN）模式下不会检查 `kmod-tun`。

### 2.5 更新后自动修复依赖（`openclash_update.sh`）

插件更新后，`install_missing_packages()` 会遍历以下关键包列表，对缺失的包自动重装（支持 `opkg` 和 `apk` 双包管理器，最多重试 3 次）：

```
luci-compat kmod-inet-diag kmod-nft-tproxy kmod-ipt-nat iptables-mod-tproxy iptables-mod-extra ipset
```

### 2.6 常见依赖故障速查

| 故障现象 | 可能原因 | LuCI 排查路径 |
|----------|----------|--------------|
| 启动失败，日志显示 "Ruby Works Abnormally" | `ruby` 或 `ruby-yaml` 未安装/损坏 | 「系统→软件包」确认 `ruby`、`ruby-yaml`、`ruby-psych` 已安装 |
| TUN 模式启动报错 "tun module not found" | `kmod-tun` 未安装或内核版本不匹配 | 「系统→软件包」安装 `kmod-tun`，注意内核版本匹配 |
| 订阅更新报 SSL 证书错误 | `ca-bundle` 未安装或过期 | 「系统→软件包」安装/更新 `ca-bundle` |
| DNS 劫持不生效 | 安装了精简版 `dnsmasq` 而非 `dnsmasq-full` | 「系统→软件包」卸载 `dnsmasq`，安装 `dnsmasq-full` |
| UDP 流量无法代理（fw4） | `kmod-nft-tproxy` 未安装 | 「系统→软件包」安装 `kmod-nft-tproxy` |
| Dashboard 页面白屏/404 | `unzip` 未安装导致仪表盘解压失败 | 「系统→软件包」安装 `unzip`，然后重新下载仪表盘 |
| LuCI 页面布局错乱、按钮无响应 | `luci-compat` 未安装 | 「系统→软件包」安装 `luci-compat` |
| 进程名规则 (PROCESS-NAME) 不生效 | `kmod-inet-diag` 未安装 | 「系统→软件包」安装 `kmod-inet-diag` |
| 更新插件后某些包丢失 | 更新过程中包被意外移除 | 更新脚本会自动修复，如仍未恢复，手动安装缺失包 |

> **通用依赖诊断方法**: 在 LuCI 的「运行日志」页面点击「生成日志」，然后在日志的 `## 依赖检查` 章节查看所有依赖包的状态（已安装/未安装）。将此日志提供给技术支持时也包含完整的依赖信息。

---
