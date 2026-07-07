---
name: openclash-user-guide
description: 'OpenClash 用户功能指南。用于回答用户关于 OpenClash 插件如何启用/关闭各项功能的问题，包括：运行模式切换、代理开关、DNS 设置、流量控制、访问控制黑白名单、IPv6 开关、规则/GEO 更新、自动重启、仪表盘设置、订阅管理、覆写设置等。每个选项均标注了对应的 UCI 配置项、修改的 Mihomo YAML 配置段、以及触发的脚本。Use when user asks how to enable, disable, configure, or troubleshoot any OpenClash feature on OpenWrt.'
instructions: |
  You are an OpenClash expert assistant. OpenClash is a LuCI plugin for OpenWrt that manages the Mihomo (Clash Meta) proxy kernel.

  When answering user questions about OpenClash:
  1. Always provide LuCI web UI navigation paths (e.g. 服务 → OpenClash → 插件设置 → 流量控制), not command-line unless explicitly requested.
  2. Explain underlying principles (firewall chains, YAML transformation logic) — not just steps.
  3. Check dependency integrity first when troubleshooting (see 完整依赖清单与故障排查 section).
  4. Never guess — if information is not covered in this document, actively query Mihomo Wiki (https://wiki.metacubex.one/config/), Meta-Docs (https://github.com/MetaCubeX/Meta-Docs), OpenClash source code (https://github.com/vernesong/OpenClash/tree/dev), Mihomo core source code (https://github.com/MetaCubeX/mihomo/tree/Alpha), or Smart core source code (https://github.com/vernesong/mihomo/tree/Alpha).
  5. Cite sources when information comes from external queries.

type: knowledge-base
tags: [openclash, openwrt, mihomo, clash, proxy, networking]
argument-hint: '询问 OpenClash 功能如何开启/关闭'
user-invocable: true
disable-model-invocation: false
---

# OpenClash 完整功能参考指南

## AI 行为总则

> **本文档是 AI 的知识库，而非给用户看的说明书。任何 AI 模型（Copilot / Claude / ChatGPT / Gemini / DeepSeek 等）在回答 OpenClash 相关问题时均应遵循以下原则。**

| 原则 | 说明 |
|------|------|
| **主动查证，不猜测** | 遇到本文档未覆盖的 Mihomo 配置字段或实现细节时，**禁止编造**。必须使用工具主动查询外部资源（Mihomo Wiki / Meta-Docs / Mihomo 核心源码 / OpenClash 源码 / Smart 核心源码），整理后告知用户。详见文档末尾「超出本文档范围的查询」节。 |
| **查源码，不只查文档** | 当用户询问"为什么某选项不生效"、"底层实现逻辑是什么"时，不能仅依赖 [Mihomo Wiki] 和 [Meta-Docs] 的配置文档。必须进一步查阅 [Mihomo 核心源码](https://github.com/MetaCubeX/mihomo/tree/Alpha)、[OpenClash 源码](https://github.com/vernesong/OpenClash/tree/dev) 和 [Smart 核心源码](https://github.com/vernesong/mihomo/tree/Alpha) 中的对应脚本/函数，理解实际执行逻辑。 |
| **给出 LuCI 操作路径** | 所有操作指导必须指向 LuCI Web 界面的具体操作路径（如「服务 → OpenClash → 插件设置 → 流量控制」），而非命令行。仅在用户明确要求命令行操作时才提供终端命令。 |
| **解释原理，不只给步骤** | 说明配置选项背后的工作原理（如防火墙规则链、YAML 转换逻辑），帮助用户理解后再操作，降低误操作风险。 |
| **先排查依赖** | 用户报告功能异常时，首先检查依赖包是否完整。本文档「完整依赖清单与故障排查」节提供了完整的依赖速查表。 |
| **引用来源** | 当信息来自外部查询（Mihomo Wiki、源码、Issues 等），在回复末尾注明来源，让用户知道信息的权威性。 |
| **先要日志，不盲猜** | 当用户问题描述不完整、缺少关键报错信息，或本文档无对应内容时，**不应猜测排查方向**。应首先要求用户提供调试日志，并给出日志生成指引：① **LuCI 页面操作**：「运行日志」页面点击「生成日志」按钮；② **SSH 命令操作**：`/usr/share/openclash/openclash_debug.sh` 生成日志文件（输出路径`/tmp/openclash_debug.log`）。拿到日志后再对照本文档「日志与错误信息速查」节或者文档、源码进行诊断。 |
| **查 Issues，不闭门造车** | 当用户遇到的功能问题在本文档中未覆盖，或报错信息在错误速查表中无匹配项时，**必须主动搜索 Issues** 查找是否存在相同或相似的问题：① 插件配置/订阅/防火墙/UI 相关问题 → 搜索 [OpenClash Issues](https://github.com/vernesong/OpenClash/issues)；② 内核级问题（代理协议/TUN/DNS 解析/规则引擎等 Mihomo 核心行为） → 搜索 [Mihomo Issues](https://github.com/MetaCubeX/mihomo/issues)。优先参考：**作者/维护者的回复**（OpenClash 标有 Owner 标签的 vernesong；Mihomo 标有 Contributor/Collaborator 标签的回复）——代表官方立场或已知 bug；**高赞反应（👍）的社区回复**——代表经过验证的有效方案；**同类问题中的诊断命令**（如 `nft list set`、`dig`、`uci show` 等）——可直接复用于用户的问题排查。搜索时使用用户报错中的关键错误信息或功能描述作为关键词。 |

**核心资源速查**:

| 资源 | URL | 用途 |
|------|-----|------|
| Mihomo Wiki | `https://wiki.metacubex.one/config/` | Mihomo YAML 配置字段文档 |
| Meta-Docs | `https://github.com/MetaCubeX/Meta-Docs` | Mihomo 配置字段权威参考 |
| OpenClash Issues | `https://github.com/vernesong/OpenClash/issues` | 搜索插件侧已知问题、社区方案、作者回复 |
| Mihomo Issues | `https://github.com/MetaCubeX/mihomo/issues` | 搜索内核侧已知问题（代理协议/TUN/DNS/规则引擎等） |
| Mihomo 核心源码 | `https://github.com/MetaCubeX/mihomo/tree/Alpha` | Mihomo 核心实现（代理协议/规则引擎/DNS/TUN 等 Go 源码） |
| OpenClash 源码 | `https://github.com/vernesong/OpenClash/tree/dev` | 插件实现逻辑（Shell/Ruby/Lua 脚本） |
| Smart 核心源码 | `https://github.com/vernesong/mihomo/tree/Alpha` | Smart 策略、LightGBM 模型实现 |

---

## 完整依赖清单与故障排查

> **AI 行为指引**: 当用户报告启动失败、功能异常、日志报错时，AI 应首先对照下表检查依赖完整性。
> 指导用户在 LuCI 的「运行日志」页面点击「生成日志」按钮，可自动生成完整的
> 依赖检查报告（含 `#===== 依赖检查 =====#` 段）。对于缺失的依赖，指导用户在
> LuCI 的「系统 → 软件包」中搜索安装，而非让用户执行命令行。
>
> **固件提醒**: 推荐使用 ImmortalWrt 或 OpenWrt 官方固件（需自行将 `dnsmasq` 替换为 `dnsmasq-full`）。不推荐使用第三方魔改/高大全固件、以及已停止维护的旧版固件。旁路由组网存在固有的网络层面缺陷，强烈建议采用主路由架构部署 OpenClash。

### 一、包依赖总览（来自 Makefile DEPENDS 和 init.d 运行时检查）

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

### 二、防火墙相关依赖（按 fw4/fw3 自动区分）

| 环境 | 依赖包 | 作用 | 缺失症状 | 安装命令 (LuCI) |
|------|--------|------|----------|-----------------|
| **fw4 (nftables)** | `kmod-nft-tproxy` | nftables TPROXY 透明代理（UDP） | UDP 无法代理、启动日志报 "nft_tproxy module not found" | 搜索 `kmod-nft-tproxy` |
| **fw3 (iptables)** | `kmod-ipt-tproxy` | iptables TPROXY 模块 | UDP 无法代理、日志报 "xt_TPROXY" | 搜索 `kmod-ipt-tproxy` |
| **fw3 (iptables)** | `iptables-mod-tproxy` | iptables TPROXY 用户态工具 | TPROXY 规则无法创建 | 搜索 `iptables-mod-tproxy` |
| **fw3 (iptables)** | `kmod-ipt-extra` | iptables 扩展匹配模块 | 高级规则匹配失败 | 搜索 `kmod-ipt-extra` |
| **fw3 (iptables)** | `iptables-mod-extra` | iptables extra 用户态工具 | 同上 | 搜索 `iptables-mod-extra` |
| **fw3 (iptables)** | `kmod-ipt-nat` | iptables NAT 内核模块 | REDIRECT/DNAT 规则失败 | 搜索 `kmod-ipt-nat` |
| **fw3 (iptables)** | `ipset` | IP 集合管理工具 | 中国 IP 绕行、黑白名单失效 | 搜索 `ipset` |

### 三、dnsmasq 特殊要求

| 要求 | 说明 |
|------|------|
| **必须使用 `dnsmasq-full`** | OpenWrt 自带的 `dnsmasq` 精简版缺少 ipset/nftset 支持，OpenClash 的 DNS 劫持和 chnroute 旁路依赖此功能 |
| **ipset 编译选项** | `dnsmasq --version` 输出需包含 `ipset`（fw3 环境必需） |
| **nftset 编译选项** | `dnsmasq --version` 输出需包含 `nftset`（fw4 环境，影响 chnroute_pass 的 nftset 集成） |

> **诊断方法**: 先在 LuCI 的「运行日志」页面生成调试日志，在日志的依赖检查段确认 dnsmasq 版本。如需手动确认，可在路由器终端执行 `dnsmasq --version | head -1`。
> 如果不是，在 LuCI 的「系统 → 软件包」中卸载 `dnsmasq` 然后安装 `dnsmasq-full`。

### 四、内核模块加载机制（`check_mod()` 函数）

`init.d/openclash` 的 `check_mod()` 函数以四级回退方式检查和加载内核模块：

1. **容器检测** — 检测 Docker/LXC/Podman 等容器环境，容器内直接返回成功（无法加载内核模块）
2. **内核编译检查** — 检查 `/proc/config.gz` 中是否有 `CONFIG_<MODULE>=y`（静态编译进内核，无需 modprobe）
3. **已加载检查** — `lsmod | grep` 检查模块是否已在内核中加载
4. **动态加载尝试** — `modprobe <module>` 尝试加载，全部失败则输出 `LOG_ERROR`

> **TUN 模块注意事项**: `check_mod "tun"` 仅在 **TUN 模式** 或 **IPv6 TUN 模式** 时才被调用。Redir-Host/Fake-IP（非 TUN）模式下不会检查 `kmod-tun`。

### 五、更新后自动修复依赖（`openclash_update.sh`）

插件更新后，`install_missing_packages()` 会遍历以下关键包列表，对缺失的包自动重装（支持 `opkg` 和 `apk` 双包管理器，最多重试 3 次）：

```
luci-compat kmod-inet-diag kmod-nft-tproxy kmod-ipt-nat iptables-mod-tproxy iptables-mod-extra ipset
```

### 六、常见依赖故障速查

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

> **通用依赖诊断方法**: 在 LuCI 的「运行日志」页面点击「生成日志」，然后在日志的 `#===== 依赖检查 =====#` 段查看所有依赖包的状态（已安装/未安装）。将此日志提供给技术支持时也包含完整的依赖信息。

---

## 系统架构速查

```
┌─────────────────────────────────────────────────────────────────┐
│  LuCI Web UI (Lua CBI)  — http://路由器LAN_IP/cgi-bin/luci      │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐                        │
│  │ settings │ │ overwrite│ │ subscribe│ ...                     │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘                        │
│       │  UCI 读写    │            │                              │
│       ▼             ▼            ▼                              │
│  /etc/config/openclash  — UCI 配置文件 (所有选项持久化在此)       │
│       │                                                         │
│       ▼ Shell Scripts ( /usr/share/openclash/ )                 │
│  ┌──────────────────────────────────────────────────────┐       │
│  │ openclash.sh        → 订阅下载/更新/节点过滤           │       │
│  │ openclash_core.sh   → 核心二进制更新                  │       │
│  │ openclash_update.sh → 插件 IPK 更新                   │       │
│  │ openclash_geo.sh    → GEO 数据库下载 (ipdb/dat/geosite/asn)  │
│  │ openclash_chnroute.sh → 大陆 IP 路由表更新             │       │
│  │ yml_change.sh       → Ruby 修改 YAML (端口/模式/DNS/TUN/认证) │
│  │ yml_rules_change.sh → Ruby 修改 YAML (规则/Provider/URL-Test) │
│  │ openclash_debug.sh  → 诊断日志收集                    │       │
│  │ openclash_watchdog.sh → 核心存活 + 流媒体解锁守护       │       │
│  └──────────────────────────────────────────────────────┘       │
│       │                                                         │
│       ▼ 生成 / 覆写                                              │
│  /etc/openclash/config/*.yaml  — 原始订阅配置                    │
│  /etc/openclash/*.yaml          — 经脚本处理后的运行配置          │
│  /etc/openclash/overwrite/     — 覆写模块文件                    │
│  /etc/openclash/custom/        — 用户自定义规则/DNS/防火墙脚本    │
│       │                                                         │
│       ▼                                                         │
│  /etc/openclash/clash  — symlink → /etc/openclash/core/clash_meta│
│  /etc/openclash/        — GEO 数据: Country.mmdb, GeoSite.dat 等 │
└─────────────────────────────────────────────────────────────────┘

API 入口: http://路由器LAN_IP:9090 (external-controller)
Dashboard: http://路由器LAN_IP:9090/ui/
```

**关键目录说明**:

| 路径 | 作用 |
|------|------|
| `/etc/config/openclash` | UCI 配置文件，所有 LuCI 选项持久化在此 |
| `/etc/openclash/` | OpenClash 工作目录（核心、GEO 数据、Chnroute 列表） |
| `/etc/openclash/config/` | 原始订阅配置存放目录（`.yaml` 文件，经 `yml_change.sh` 处理后生成 `/etc/openclash/<name>.yaml` 运行配置） |
| `/etc/openclash/overwrite/` | 覆写模块文件（INI 格式，定义自定义 YAML 覆盖） |
| `/etc/openclash/custom/` | 用户自定义文件（规则列表、DNS 策略、Hosts、防火墙脚本、Sniffer 配置等） |
| `/etc/openclash/core/` | 核心二进制存放目录（多版本共存，/etc/openclash/clash 是到 core/clash_meta 的 symlink） |
| `/etc/openclash/dashboard/` | Dashboard 静态文件（yacd/metacubexd/zashboard） |
| `/etc/openclash/Model.bin` | LightGBM 智能策略模型文件（注意：不是目录，是单个 .bin 文件） |
| `/usr/share/openclash/` | 插件脚本目录（Shell/Ruby/Lua 脚本） |
| `/tmp/openclash.log` | 运行日志 |
| `/tmp/openclash_start.log` | 启动日志 |
| `/tmp/etc/openclash/` | 小闪存模式下的工作目录（重启后清空） |
| `/var/etc/openclash.include` | 防火墙规则加载文件（由 firewall UCI 自动 include） |

- **UCI 配置根**: `openclash` (所有选项均在 `uci show openclash` 可见)
- **Mihomo 运行时 API**: `http://路由器LAN_IP:9090` — 部分动态选项通过 PATCH `/configs` 热生效。注意：API 地址是**路由器 LAN 口 IP**，不是 127.0.0.1（核心监听 `0.0.0.0`，但 LuCI 后端通过 `127.0.0.1` 直连核心 API）
- **核心启动脚本**: `/etc/init.d/openclash {start|stop|restart|reload|enable|disable}`
- **自定义文件目录**: `/etc/openclash/custom/` — 存放用户自定义规则/DNS/防火墙脚本

---

## 系统启动完整流程

> 理解此流程是理解所有选项实现逻辑的基础

```
/etc/init.d/openclash start_service()
│
├─ 第1步: 读取配置
│   ├─ overwrite_file()     → 遍历 config_overwrite 条目，生成 /tmp/yaml_overwrite.sh
│   ├─ get_config()         → 读取所有 UCI 选项为 Shell 变量
│   ├─ config_choose()      → 选择活动的 YAML 配置文件
│   └─ do_run_mode()        → 解析 en_mode → 拆分 en_mode_tun/en_mode_fakeip/en_mode_mix
│
├─ 第2步: 环境准备
│   ├─ do_run_file()        → 检查/下载核心二进制 (/etc/openclash/core/clash_meta)
│   ├─ 创建 symlink         → ln -s /etc/openclash/core/clash_meta /etc/openclash/clash
│   └─ 小闪存模式处理       → 将文件移到 /tmp/etc/openclash
│
├─ 第3步: 修改 YAML 配置（按顺序执行）
│   ├─ ① yml_change.sh     → Ruby 脚本，~48 个 UCI 参数
│   │   ├─ 设置端口 (proxy_port, tproxy_port, http_port, socks_port, mixed_port, dns_port)
│   │   ├─ 设置模式 (mode, log-level, dns.enhanced-mode)
│   │   ├─ 设置 TUN (tun.enable, tun.stack, tun.device, tun.dns-hijack)
│   │   ├─ 设置 DNS (dns.* 完整段: nameserver, fallback, fake-ip-range, respect-rules...)
│   │   ├─ 设置 Sniffer (sniffer.* 完整段)
│   │   ├─ 设置认证 (authentication: [user:pass])
│   │   ├─ 设置 Meta (tcp-concurrent, unified-delay, find-process-mode, geodata-loader...)
│   │   ├─ 设置 GEO (geox-url.*, geo-auto-update, geo-update-interval)
│   │   ├─ 设置 Smart/LGBM (模型 URL, 更新间隔)
│   │   ├─ 设置 Dashboard (external-controller, secret, external-ui)
│   │   └─ 设置 NTP (ntp.*), CORS, IPv6, routing-mark
│   │
│   ├─ ② yml_rules_change.sh → Ruby 脚本
│   │   ├─ enable_rule_proxy → 注入 BT/P2P 直连规则 + PROCESS-NAME 规则
│   │   ├─ tolerance/urltest_* → 覆写 url-test 策略组参数
│   │   ├─ github_address_mod → 替换 GitHub Raw URL 为 CDN
│   │   ├─ enable_custom_clash_rules → 从 *.list 文件注入自定义规则
│   │   └─ auto_smart_switch → 将 url-test/load-balance 组改为 smart 类型
│   │
│   └─ ③ /tmp/yaml_overwrite.sh  → 来自覆写模块 [Overwrite] 段的自定义脚本
│
├─ 第4步: 启动核心
│   └─ procd 启动 clash -d /etc/openclash -f <config.yaml>
│       ├─ respawn 配置: 重试 5 次, 间隔 3s, 超时 300s
│       └─ rlimit_nofile: 1048576 (最大文件描述符)
│
├─ 第5步: 异步等待核心就绪 (check_core_status "start" &)
│   ├─ 轮询 HTTP 200 from http://127.0.0.1:9090
│   └─ 就绪后执行:
│       ├─ set_firewall()    → 建立 iptables/nftables 透明代理规则
│       │   ├─ REDIRECT/T_PROXY 规则 (按 en_mode)
│       │   ├─ DNS 劫持规则 (按 enable_redirect_dns)
│       │   ├─ 访问控制规则 (按 lan_ac_mode + lists)
│       │   ├─ QUIC 阻断规则 (按 disable_udp_quic)
│       │   ├─ 中国 IP 绕行规则 (按 china_ip_route)
│       │   └─ IPv6 防火墙链 (按 ipv6_enable)
│       └─ change_dnsmasq()  → DNS 劫持 (dnsmasq → Clash DNS)
│
└─ 第6步: 定时任务 + 守护进程
    ├─ add_cron()            → 注册 cron 任务
    │   ├─ openclash.sh      → 定时更新订阅
    │   ├─ openclash_geo.sh  → 定时更新 GEO 数据
    │   ├─ openclash_chnroute.sh → 定时更新大陆路由
    │   └─ /etc/init.d/openclash restart → 定时自动重启
    └─ start_watchdog()      → 启动守护进程
        ├─ openclash_watchdog.sh        → 核心存活监控
        └─ openclash_streaming_unlock.lua → 流媒体解锁守护
```

**停止流程** (`stop_service()`):
1. 备份策略组状态历史 → 2. `revert_firewall()` 清除防火墙规则 → 3. kill clash + streaming unlock 进程 → 4. `revert_dnsmasq()` 恢复 DNS → 5. `del_cron()` 清除定时任务

**热生效 vs 需重启**:
| 操作 | 方式 | 延迟 |
|------|------|------|
| 切换代理模式 (rule/global/direct) | Mihomo API `PATCH /configs` (mode) | 即时 |
| 切换日志级别 | Mihomo API `PATCH /configs` (log-level) | 即时 |
| 切换 Sniffer/Rules | Mihomo API `PATCH /configs` | 即时 |
| 修改端口/TUN/DNS/覆写 | 需重启核心 (修改 YAML) | ~3-5s |
| 修改防火墙规则 | `/etc/init.d/openclash reload` | 即时 |
| 修改访问控制 | 需重启 (重建防火墙链) | ~5s |

---

## 防火墙与 DNS 规则详解（iptables + nftables 双后端）

> OpenClash 同时支持 **fw3 (iptables/ipset)** 和 **fw4 (nftables)** 两种防火墙后端，通过 `command -v fw4` 自动检测：
> - 存在 `fw4` → 使用 **nftables** (OpenWrt 22.03+)
> - 不存在 `fw4` → 使用 **iptables + ipset** (旧版 OpenWrt)
> 所有 `if [ -n "$FW4" ]` / `if [ -z "$FW4" ]` 分支互斥，两种后端的**规则逻辑完全相同**，仅语法不同。
>
> **AI 行为指引**: 当用户询问透明代理/防火墙相关问题时（如"为什么设备无法上网"、"旁路由模式下流量不走代理"、
> "如何验证防火墙规则是否生效"、"TUN 模式下某协议不通"），AI 应首先让用户在 LuCI 的「运行状态」页面
> 确认核心状态为「运行中」；然后建议用户在 LuCI 的「运行日志」页面生成调试日志
> （包含完整防火墙规则链）。如需实时排查，可在路由器终端执行 `nft list ruleset`（fw4）或
> `iptables -t nat -L -n`（fw3）查看实际规则。结合下表中的链结构和规则排序，对比用户的需求判断规则是否如预期生效。
> 如涉及底层实现细节，查阅 [OpenClash 源码](https://github.com/vernesong/OpenClash/tree/dev) 中
> `/etc/init.d/openclash` 的 `set_firewall()` 函数。
> 常见问题：规则排序错误（bypass 在 redirect 之后）、fwmark 未设置导致策略路由不生效、
> DNS 劫持端口与 dnsmasq 冲突。

### 模式解析表

| UCI `en_mode` | `en_mode_tun` | 数据面 | DNS 面 |
|---------------|---------------|--------|--------|
| `redir-host` | *(空)* | TCP REDIRECT + UDP TPROXY | `dns.enhanced-mode: redir-host` |
| `fake-ip` | *(空)* | TCP REDIRECT + UDP TPROXY | `dns.enhanced-mode: fake-ip` |
| `redir-host-tun` | `1` | TCP+UDP 全 TUN | `dns.enhanced-mode: redir-host` |
| `fake-ip-tun` | `1` | TCP+UDP 全 TUN | `dns.enhanced-mode: fake-ip` |
| `redir-host-mix` | `2` | TCP REDIRECT + UDP TUN | `dns.enhanced-mode: redir-host` |
| `fake-ip-mix` | `2` | TCP REDIRECT + UDP TUN | `dns.enhanced-mode: fake-ip` |

**全局常量**:
```bash
PROXY_FWMARK="0x162"       # 所有被代理流量的防火墙标记
PROXY_ROUTE_TABLE="0x162"  # 策略路由表 ID
SKIP_GROUP="65534"         # 绕过代理的组 ID (skgid)
```

---

### 一、fw4 (nftables) 链结构 — `inet fw4` 表

#### A. DNS 劫持链

**`enable_redirect_dns=1` (Dnsmasq 转发模式)**:
```bash
# PREROUTING: 劫持发往 53 端口的 DNS → 重定向到 dnsmasq 端口
nft insert rule inet fw4 dstnat position 0 \
  meta l4proto {tcp,udp} th dport 53 \
  counter redirect to <dnsmasq_port> comment "OpenClash DNS Hijack"

# OUTPUT (仅 router_self_proxy=1): 路由器自身 DNS
nft add chain inet fw4 nat_output { type nat hook output priority -1; }
nft insert rule inet fw4 nat_output position 0 \
  skgid != 65534 meta l4proto {tcp,udp} th dport 53 \
  ip daddr {127.0.0.1} counter redirect to <dnsmasq_port>
```

**`enable_redirect_dns=2` (防火墙重定向模式)**:
```bash
nft add chain inet fw4 openclash_dns_redirect
nft add rule inet fw4 openclash_dns_redirect \
  meta l4proto {tcp,udp} th dport 53 counter redirect to <dns_port>
nft insert rule inet fw4 dstnat position 0 \
  meta l4proto {tcp,udp} th dport 53 counter jump openclash_dns_redirect
```

#### B. 非 TUN 模式链 (`en_mode_tun` 为空或 `2`)

| 链名 | 钩子来源 | 协议 | 动作 |
|------|----------|------|------|
| `openclash` | `dstnat` jump | TCP | REDIRECT → `$proxy_port`(7892) |
| `openclash_mangle` | `mangle_prerouting` jump | UDP | TPROXY → `:$tproxy_port`(7895), mark `0x162` |
| `openclash_upnp` | `openclash_mangle` jump | UDP | UPNP 端口排除 (RETURN) |
| `openclash_output` | `nat_output` jump | TCP | 路由器自身 TCP REDIRECT |
| `openclash_mangle_output` | `mangle_output` jump | UDP | 路由器自身 UDP 标记 |

**`openclash` 链规则排序 (TCP REDIRECT)**:
```bash
# 1. 本地网络绕过
nft add rule inet fw4 openclash ip daddr @localnetwork counter return

# 2. 回复方向绕过
nft add rule inet fw4 openclash ct direction reply counter return

# 3. Fake-IP 范围 (仅 fake-ip 模式)
nft add rule inet fw4 openclash ip protocol tcp \
  ip daddr {198.18.0.0/16} counter redirect to $proxy_port

# 4. WAN 黑名单 IP (WAN-AC)
nft add rule inet fw4 openclash ip daddr @wan_ac_black_ips counter return
# 5. WAN 黑名单端口
nft add rule inet fw4 openclash th dport @wan_ac_black_ports counter return

# 6. LAN 黑名单 IP (LAN-AC, lan_ac_mode=0)
nft add rule inet fw4 openclash ip saddr @lan_ac_black_ips counter return
# 7. LAN 黑名单 MAC
nft add rule inet fw4 openclash ether saddr @lan_ac_black_macs counter return

# 8. 白名单检查 (lan_ac_mode=1)
#    非白名单 → RETURN: ether saddr != @lan_ac_white_macs \
#                         ip saddr != @lan_ac_white_ips counter return

# 9. 非标准端口绕过 (redir-host 模式, common_ports != 0)
nft add rule inet fw4 openclash th dport != @common_ports counter return

# 10. 中国 IP 绕行 (china_ip_route)
#   mode=1: ip daddr @china_ip_route counter return
#   mode=2: ip daddr != @china_ip_route counter return

# 11. 最终代理: 所有剩余 TCP → REDIRECT
nft add rule inet fw4 openclash ip protocol tcp counter redirect to $proxy_port
```

**`openclash_mangle` 链规则排序 (UDP TPROXY)**: 同上 #1-#10，最终规则：
```bash
# UPNP 排除
nft add rule inet fw4 openclash_mangle ip protocol udp counter jump openclash_upnp
# TPROXY 最终规则
nft add rule inet fw4 openclash_mangle meta l4proto {udp} \
  counter tproxy ip to 127.0.0.1:$tproxy_port meta mark set $PROXY_FWMARK accept
```

#### C. TUN 模式链 (`en_mode_tun=1`)

| 链名 | 钩子来源 | 协议 | 动作 |
|------|----------|------|------|
| `openclash_mangle` | `mangle_prerouting` jump | TCP+UDP | 设置 fwmark `0x162` |
| `openclash_mangle_output` | `mangle_output` jump | TCP+UDP | 路由器自身 fwmark |

**`openclash_mangle` 规则排序 (TUN 模式)**:
```bash
# 1. 跳过 TUN 接口自身流量
nft add rule inet fw4 openclash_mangle meta l4proto {tcp,udp} \
  iifname utun counter return

# 2-10. 同非 TUN 模式的 bypass 检查 (localnetwork/ct reply/WAN-AC/LAN-AC/common_ports/china_ip_route)

# 11. ICMP 代理
nft add rule inet fw4 openclash_mangle ip protocol icmp \
  icmp type echo-request counter meta mark set $PROXY_FWMARK

# 12. UPNP 排除 (UDP)
nft add rule inet fw4 openclash_mangle ip protocol udp counter jump openclash_upnp

# 13. 最终标记 — 全 TUN 模式标记 tcp+udp，混合模式仅标记 udp
nft add rule inet fw4 openclash_mangle meta l4proto {tcp,udp} \
  counter meta mark set $PROXY_FWMARK
```

**TUN 转发规则** (utun 允许通过):
```bash
nft insert rule inet fw4 forward position 0 oifname utun counter accept
nft insert rule inet fw4 forward position 0 iifname utun counter accept
nft insert rule inet fw4 input position 0 iifname utun counter accept
nft insert rule inet fw4 srcnat position 0 oifname utun counter return
```

#### D. IPv6 链 (独立于 IPv4)

| nftables 链 | 功能 |
|-------------|------|
| `openclash_v6` | IPv6 TCP REDIRECT |
| `openclash_mangle_v6` | IPv6 UDP TPROXY / TUN fwmark |
| `openclash_output_v6` | 路由器自身 IPv6 TCP |
| `openclash_mangle_output_v6` | 路由器自身 IPv6 fwmark |
| `openclash_post_v6` | 旁路由 SNAT/MASQUERADE |

IPv6 模式 (`ipv6_mode`): `0`=TProxy, `1`=Redirect, `2`=TUN, `3`=Mix

#### E. ICMP/Ping 处理详解

> **AI 行为指引**: 当用户询问「为什么 ping 不走代理」、「ping 通但 TCP 不通」、「Fake-IP 模式下 ping 198.18.x.x 被拒绝」等问题时，AI 应结合本节解释 ICMP 在非 TUN 和 TUN 模式下的不同处理方式。

OpenClash 对 ICMP（ping）请求的处理**取决于运行模式**：

**1. 非 TUN 模式（Redir-Host / Fake-IP，`en_mode_tun` 为空）**:

ICMP echo-request 在 `openclash_mangle` 链中被**仅标记 fwmark（0x162）但不重定向**：

```bash
nft add rule inet fw4 openclash_mangle ip protocol icmp \
  icmp type echo-request mark set "$PROXY_FWMARK" counter accept comment "OpenClash ICMP Mark"
```

- **ICMP 不会被代理**：非 TUN 模式下只有 TCP（REDIRECT）和 UDP（TPROXY）被重定向到 Mihomo 内核，ICMP 仅被标记 fwmark 后直接放行（`accept`）。这意味着 ping 请求走的是系统原始路由表，不会经过代理节点。
- **fwmark 的作用**：标记 0x162 仅影响策略路由选择（如旁路由回流），不影响代理行为本身。
- **绕过检查仍然生效**：ICMP 规则之前的 localnetwork/WAN-AC/LAN-AC/china_ip_route 等 RETURN 规则同样适用于 ICMP——被匹配的 ICMP 包会跳过标记规则。
- **路由器自身 ICMP**：当 `router_self_proxy=1` 时，路由器发出的 ping 在 `openclash_mangle_output` 链中同样被标记。

**2. TUN 模式（`en_mode_tun=1`）**:

ICMP echo-request 在 `openclash_mangle` 链中被标记 fwmark，随后通过策略路由进入 TUN 虚拟网卡：

```bash
# 步骤1: 标记 ICMP
nft add rule inet fw4 openclash_mangle ip protocol icmp \
  icmp type echo-request mark set "$PROXY_FWMARK" counter accept

# 步骤2: 策略路由（系统层面）— 所有标记 0x162 的流量路由到 TUN
ip rule add fwmark 0x162 table 0x162
ip route add default dev utun table 0x162
```

- **ICMP 被代理**：TUN 模式下所有标记 fwmark 的流量（包括 ICMP）被策略路由导向 `utun` 虚拟网卡，由 Mihomo 内核的 TUN 协议栈处理。
- **Mihomo 内核配置**：TUN 模式下 Mihomo 支持两个 ICMP 相关选项：
  - `icmp-timeout`（默认自动）：ICMP 连接超时时间（秒）
  - `disable-icmp-forwarding`（默认 false）：设为 `true` 可禁用 TUN 的 ICMP 转发（ping 将不被代理）

**3. Fake-IP 非 TUN 模式的 Ping 阻断**:

**仅在 Fake-IP 非 TUN 模式下**（`en_mode=fake-ip`, `en_mode_tun` 为空），对 Fake-IP 地址段（默认 `198.18.0.0/16`）的 ping 会被防火墙**显式 REJECT**：

```bash
# INPUT 链 — 阻止路由器自身收到发往 Fake-IP 的 ping
nft insert rule inet fw4 input position 0 ip protocol icmp \
  icmp type echo-request ip daddr { 198.18.0.0/16 } counter reject

# FORWARD 链 — 阻止局域网设备间转发 Fake-IP 的 ping
nft insert rule inet fw4 forward position 0 ip protocol icmp \
  icmp type echo-request ip daddr { 198.18.0.0/16 } counter reject

# OUTPUT 链 — 阻止路由器发出对 Fake-IP 的 ping（排除 OpenClash 自身进程 skgid=65534）
nft insert rule inet fw4 output position 0 ip protocol icmp \
  icmp type echo-request ip daddr { 198.18.0.0/16 } \
  skgid != 65534 counter reject
```

这是因为在非 TUN 模式下，Fake-IP 地址没有对应的 TCP/UDP 重定向路径（TCP 走 REDIRECT、UDP 走 TPROXY，但 ICMP 都不到达内核），发往这些地址的 ping 无意义且会干扰网络诊断。OUTPUT 链排除 `skgid=65534` 是为了避免影响 OpenClash 自身进程的内部通信。

> **TUN 模式下的区别**：Fake-IP **TUN 模式不添加这些 REJECT 规则**。因为 ICMP 经策略路由进入 TUN 虚拟网卡后，由内核的 `skipPingForwardingByAddr()` 判断——若目标是 Fake-IP，内核返回伪造 echo-reply（~0ms 虚假延迟），不产生实际网络流量。

**4. IPv6 ICMP（ICMPv6）**:

仅在 IPv6 TUN/混合模式（`ipv6_mode=2` 或 `3`）下标记：

```bash
nft add rule inet fw4 openclash_mangle_v6 ip6 nexthdr icmpv6 \
  icmpv6 type echo-request mark set "$PROXY_FWMARK" counter accept
```

IPv6 非 TUN 模式下 ICMPv6 **不被标记也不被代理**。IPv6 Fake-IP 地址范围的 ping 在**非 TUN 的 IPv6 模式下**被 REJECT（返回 `icmpv6 admin-prohibited`），条件为 `$ipv6_mode -ne 2 -a $ipv6_mode -ne 3`。TUN/Mix 模式下的 IPv6 Fake-IP ping 同样由内核的 `skipPingForwardingByAddr()` 处理（伪造回复）。

**总结**:

| 运行模式 | ICMP 进入 TUN | ICMP fwmark | 实际处理 |
|----------|-------------|-------------|----------|
| Redir-Host (非TUN) | ❌ | ✅ 标记 0x162 | 仅标记后放行，不经内核处理 |
| Fake-IP (非TUN) | ❌ | ✅ 标记 0x162 | 防火墙 REJECT Fake-IP 范围的 ping |
| Redir-Host TUN | ✅ | ✅ 标记 0x162 | 真实 IP → DIRECT 直连延迟 |
| Fake-IP TUN | ✅ | ✅ 标记 0x162 | 真实 IP → DIRECT 直连；Fake-IP → 伪造回复（~0ms 虚假延迟） |
| Redir-Host Mix | ✅ | ✅ 标记 0x162 | 同 Redir-Host TUN：ICMP 标记后经策略路由进入 TUN，DIRECT 直连 |
| Fake-IP Mix | ✅ | ✅ 标记 0x162 | 同 Fake-IP TUN：真实 IP → DIRECT 直连；Fake-IP → 内核伪造回复 |

> **实用提示**：如果用户发现 ping 不通但网页正常，首先确认不是 Fake-IP **非 TUN** 模式下在 ping 被代理的域名（Fake-IP 返回 `198.18.x.x`，防火墙直接 REJECT）。Fake-IP TUN/Mix 模式下 ping Fake-IP 地址会返回虚假 ~0ms 延迟。非 Fake-IP 的真实 IP ping 在 TUN/Mix 模式下走 DIRECT 直连，延迟反映的是本地网络质量。

**内核侧 ICMP 处理机制**（`listener/sing_tun/prepare.go` — Mihomo TUN 监听器）:

当 ICMP echo-request 经策略路由进入 TUN 虚拟网卡后，Mihomo 内核按以下优先级处理：

1. **目标是 Fake-IP 地址**（`resolver.IsFakeIP(addr)`） → 返回 `nil, nil`，内核用**伪造的 echo-reply** 回复。上层看到 "ping 成功" 但实际未经过网络，延迟显示为虚假的 ~0ms
2. **目标是 TUN 接口自身 IP**（`inet4_address` / `inet6_address` 范围内） → 同上，伪造回复
3. **`disable-icmp-forwarding: true`** → 所有 ICMP 均伪造回复
4. **以上均不满足**（真实 IP 且未禁用转发） → 通过 `ping.ConnectDestination()` 以 **DIRECT 模式**发出真实 ICMP 包，等待真实 reply。延迟为本地网络到目标的实际 RTT
5. **ICMP 超时**: 默认 10 秒（`sing.go` 常量），可通过 `icmp-timeout` 自定义

> **关键结论**: TUN 模式下 ping 的处理分两种情况——目标是 Fake-IP → 虚假 0ms 延迟；目标是真实 IP → DIRECT 直连延迟。ping **始终不经过代理节点**，这与 TCP/UDP 流量（经代理转发）的行为不同。

---

### 二、fw3 (iptables/ipset) 等效链

| iptables 链 | 表 | 等效 nftables 链 |
|-------------|-----|-----------------|
| `openclash` | `nat` | `inet fw4 openclash` (TCP) |
| `openclash` | `mangle` | `inet fw4 openclash_mangle` (UDP) |
| `openclash_output` | `nat` | `inet fw4 openclash_output` (TCP) |
| `openclash_output` | `mangle` | `inet fw4 openclash_mangle_output` (UDP) |
| `openclash_post` | `nat` | `inet fw4 openclash_post` |
| `openclash_wan_input` | `filter` | `inet fw4 openclash_wan_input` |
| `openclash_dns_redirect` | `nat` | `inet fw4 openclash_dns_redirect` |
| `openclash_upnp` | `mangle` | `inet fw4 openclash_upnp` |

**fw3 兼容性层** — 自动检测 iptables 是否支持 owner/gid 模块:
```bash
if iptables 不支持 owner 模块; then
    owner="-m mark --mark 0x1a0a"     # 回退: 按 fwmark 匹配
    noowner="-m mark ! --mark 0x1a0a"
else
    owner="-m owner --gid-owner 65534" # 标准: owner 模块
    noowner="-m owner ! --gid-owner 65534"
fi
```

**示例 fw3 REDIRECT (TCP)**:
```bash
iptables -t nat -N openclash
iptables -t nat -A openclash -m set --match-set localnetwork dst -j RETURN
iptables -t nat -A openclash -p tcp -d 198.18.0.0/16 -j REDIRECT --to-ports 7892
iptables -t nat -A openclash -p tcp -m set ! --match-set common_ports dst -j RETURN
iptables -t nat -A openclash -p tcp -j REDIRECT --to-ports 7892
iptables -t nat -A PREROUTING -p tcp -j openclash
```

**示例 fw3 TPROXY (UDP)**:
```bash
iptables -t mangle -N openclash
iptables -t mangle -A openclash -p udp -m set --match-set localnetwork dst -j RETURN
iptables -t mangle -A openclash -p udp -j TPROXY --on-port 7895 --tproxy-mark 0x162
iptables -t mangle -A PREROUTING -p udp -j openclash
```

---

### 三、各选项对防火墙规则的具体影响

| 选项 | 值 | 防火墙规则变化 |
|------|---|---------------|
| **`china_ip_route`** (实验性：绕过指定区域 IP / China IP Route) | `1` (绕过大陆) | 在代理规则前插入 `ip daddr @china_ip_route counter return` — 目标为国内 IP 的流量跳过代理 |
| | `2` (绕过海外) | 插入 `ip daddr != @china_ip_route counter return` — 目标非国内 IP 的流量跳过代理 |
| **`china_ip6_route`** (实验性：绕过指定区域 IPv6 / China IPv6 Route) | `1` (绕过大陆) | IPv6 等效规则：`ip6 daddr @china_ip6_route counter return` — 目标为国内 IPv6 的流量跳过代理 |
| | `2` (绕过海外) | IPv6 等效规则：`ip6 daddr != @china_ip6_route counter return` |
| **`disable_udp_quic`** (禁用 QUIC / Disable QUIC) | `1` | 全部模式在 filter INPUT 链插入 QUIC REJECT 规则 (`udp dport 443`，根据 `china_ip_route` 匹配或排除中国 IP)，同时拦截下游客户端和路由器自身的 QUIC。IPv6 TUN 模式额外在 `forward oifname utun` 插入同规则以覆盖经 utun 转发的 IPv6 流量。规则触发仅依赖 `disable_udp_quic`，与 `enable_udp_proxy`/`enable_v6_udp_proxy` 无关。Mihomo 内核自身 QUIC（如 Hysteria 节点、DNS h3）不受影响——内核出站走 OUTPUT 链，不在规则范围内。 |
| **`lan_ac_mode`** (局域网访问控制模式 / LAN Access Control Mode) | `0` (黑名单) | 创建 `lan_ac_black_ips`/`lan_ac_black_macs` set，匹配到的 RETURN 跳过代理 |
| | `1` (白名单) | 创建 `lan_ac_white_ips`/`lan_ac_white_macs` set，**不匹配**的 RETURN 跳过代理（反逻辑） |
| **`common_ports`** (仅允许常用端口流量 / Common Ports Proxy Mode) | `非0` | 插入 `th dport != @common_ports counter return` — 仅代理指定端口，P2P/BT 端口被绕过。仅 redir-host 模式生效 |
| **`router_self_proxy`** (路由本机代理 / Router-Self Proxy) | `1` | 创建 OUTPUT 链 (`openclash_output` + `openclash_mangle_output`)，路由器自身流量被重定向/标记 |
| | `0` | 删除 OUTPUT 链，路由器自身流量走原始路由 |
| **`intranet_allowed`** (仅允许内网 / Only Intranet Allowed) | `1` | 创建 `openclash_wan_input` 链，REJECT 来自 WAN 口对全部服务端口的访问：`$proxy_port`(7892)、`$tproxy_port`(7895)、`$cn_port`(9090)、`$http_port`(7890)、`$socks_port`(7891)、`$mixed_port`(7893)、`$dns_port`(7874) |
| **`bypass_gateway_compatible`** (旁路网关（旁路由）兼容 / Bypass Gateway Compatible) | `1` | 创建 `openclash_post` 链，对已标记流量执行 MASQUERADE SNAT，解决旁路由回流问题 |
| **`skip_proxy_address`** (绕过服务器地址 / Skip Proxy Address) | `1` | 看门狗定时调用 `skip_proxies_address()` 通过内核 API 解析代理节点 `server` 地址并加入 `localnetwork` nft set，复用链首 RETURN 规则跳过代理，防止代理嵌套 |
| **`enable_redirect_dns`** (本地 DNS 劫持 / Redirect Local DNS Setting) | `1` | 在 `dstnat` 插入 DNS 53 端口 REDIRECT 规则到 dnsmasq 端口 |
| | `2` | 创建 `openclash_dns_redirect` 链，DNS 流量直接 DNAT 到 `dns_port`(7874) |
| **`local_network_pass`** (本地 IPv4 绕过地址 / Local IPv4 Network Bypassed List) | 已配置 | 创建 `localnetwork` nft set，在 `openclash` 链规则 #1 中匹配本地 IP 段 RETURN 跳过代理 |
| **`chnroute_pass`** (绕过指定区域 IPv4 黑名单 / Chnroute Bypassed List) | 已配置 | 创建 `china_ip_route_pass` nft set，配合 dnsmasq 将指定域名解析的 IP 加入 set，防火墙规则中优先于 `china_ip_route` 匹配（确保这些 IP 不被绕行规则跳过） |
| **UPNP 流量排除**（无 UCI 选项，自动检测 `/etc/config/upnpd` 租约文件） | 系统已安装 upnpd | 创建 `openclash_upnp` 链，看门狗自动同步 upnpd 租约中的端口映射，匹配的 UDP 流量 RETURN 跳过代理，防止 BT/游戏等 UPnP 端口被错误代理 |
| **`ipv6_enable`** (IPv6 流量代理 / Proxy IPv6 Traffic) | `1` | 创建完整的 IPv6 防火墙链：`openclash_v6`(TCP REDIRECT)、`openclash_mangle_v6`(UDP TPROXY)、`openclash_output_v6`(路由自身)、`openclash_post_v6`(旁路由 SNAT) |
| **`local_network6_pass`** (本地 IPv6 绕过地址 / Local IPv6 Network Bypassed List) | 已配置 | 创建 IPv6 `localnetwork` nft set，IPv6 链中匹配本地 IPv6 段 RETURN |
| **ICMP/Ping 处理**（无 UCI 选项，由运行模式决定） | Redir-Host / Fake-IP（非 TUN） | ICMP echo-request 仅标记 fwmark `0x162` 后 accept，**不被代理**（只有 TCP/UDP 被重定向到内核）；Fake-IP 非 TUN 模式下对 `198.18.0.0/16` 的 ping 被防火墙 REJECT（INPUT/FORWARD/OUTPUT 三链阻断） |
| | TUN 模式 / Mix 模式 | ICMP 标记 fwmark 后经策略路由进入 TUN 虚拟网卡，由 TUN 内核处理（真实 IP → DIRECT 直连延迟，Fake-IP → 伪造回复 ~0ms）；可通过 Mihomo 的 `disable-icmp-forwarding` 禁用 |

---

### 四、Dnsmasq 修改详解 (`change_dnsmasq` / `revert_dnsmasq`)

**修改流程** (`change_dnsmasq()`, 仅在 `enable_redirect_dns=1` 时执行):

```bash
# 1. 备份原始配置到 openclash.config.*
save_dnsmasq_server() → uci add_list openclash.config.dnsmasq_server="<原始server>"
uci set openclash.config.dnsmasq_noresolv="$(uci get dhcp.@dnsmasq[0].noresolv)"
uci set openclash.config.dnsmasq_resolvfile="$(uci get dhcp.@dnsmasq[0].resolvfile)"
uci set openclash.config.dnsmasq_cachesize="$(uci get dhcp.@dnsmasq[0].cachesize)"

# 2. 重定向 DNS
uci del dhcp.@dnsmasq[-1].server
uci add_list dhcp.@dnsmasq[0].server="127.0.0.1#$dns_port"
uci delete dhcp.@dnsmasq[0].resolvfile
uci set dhcp.@dnsmasq[0].noresolv=1
uci set dhcp.@dnsmasq[0].localuse=1
uci set dhcp.@dnsmasq[0].cachesize=0

# 3. IPv6 DNS (ipv6_dns=1 时)
uci set dhcp.@dnsmasq[0].filter_aaaa=0  # 允许 AAAA 记录

# 4. chnroute_pass 处理 — 加载 ipset/nftset
load_ip_route_pass()
# 创建 china_ip_route_pass ipset/nftset
# 将 openclash_custom_chnroute_pass.list 中的域名加入 set
# 对 china_ip_route_pass UCI 列表中的域名加入 set

# 5. 自定义域名 DNS
/usr/share/openclash/openclash_custom_domain_dns.sh

# 6. 重启 dnsmasq
/etc/init.d/dnsmasq restart
```

**恢复流程** (`revert_dnsmasq()`):
```bash
# 1. 删除 OpenClash 注入的 server
uci del dhcp.@dnsmasq[-1].server

# 2. 恢复原始 server 列表
for server in $(uci get openclash.config.dnsmasq_server); do
    uci add_list dhcp.@dnsmasq[0].server="$server"
done

# 3. 恢复 resolvfile / noresolv / cachesize / filter_aaaa
uci set dhcp.@dnsmasq[0].noresolv="$saved_noresolv"
uci set dhcp.@dnsmasq[0].resolvfile="$saved_resolvfile"
uci set dhcp.@dnsmasq[0].cachesize="$saved_cachesize"

# 4. DNS 验证 — 测试修改后的 DNS 是否可用
if nslookup www.apple.com 127.0.0.1:<dnsmasq_port> 失败; then
    # 创建 fallback resolv.conf (114.114.114.114, 8.8.8.8)
fi
```

**chnroute_pass 的 dnsmasq 集成**:
- 创建 `china_ip_route_pass` ipset/nftset
- 将 chnroute_pass 域名加入 set: `ipset=/domain.com/china_ip_route_pass` 或 `nftset=/domain.com/4#inet#fw4#china_ip_route_pass`
- 效果: DNS 解析这些域名时加入 set 便于在匹配时绕过（而非被 chnroute 影响）

---

## 日志与错误信息速查

> **AI 行为指引**: 当用户提供日志报错信息时，AI 应首先在以下表格中查找匹配的错误关键字，
> 根据「原因」列判断问题根源，然后按「排查方法」列指导用户在 LuCI 中操作。
> **若表中未覆盖该错误**，应主动搜索 [OpenClash GitHub Issues](https://github.com/vernesong/OpenClash/issues) 查找是否存在相同或相似的问题，
> 优先参考高赞反应的社区回复和作者（vernesong）给出的解决方案。搜索时可使用错误关键字作为搜索词。
>
> **两类日志说明**:
> - **插件日志**（前九类）：由 OpenClash 的 Shell/Ruby/Lua 脚本产生，含 `[Info]`/`[Tip]`/`[Warning]`/`[Error]` 前缀，写入 `/tmp/openclash.log`。可在 LuCI「运行日志」页面查看。
> - **内核日志**（第十、十一类）：由 Mihomo 核心（Go 程序）产生，含 `level=debug/info/warning/error/fatal` 标记，同样写入 `/tmp/openclash.log`。`level=fatal` 会导致核心进程退出。可在 LuCI「运行日志」页面查看，或在「运行状态」页面看到 `OpenClash Start Failed` 提示。

### 一、内核启动与运行错误

| 错误关键字 | 问题位置 | 原因 | 排查方法 |
|-----------|---------|------|----------|
| `Ruby Works Abnormally, Please Check The Ruby Library Depends!` (Ruby 依赖异常) | 「运行状态」启动流程 | `ruby` 或 `ruby-yaml` 包未安装/损坏 | 「系统→软件包」安装 `ruby`、`ruby-yaml`、`ruby-psych` |
| `Unable To Parse Config File` (配置文件校验失败) | 「运行状态」启动流程 | YAML 配置文件语法错误或 age 解密失败 | 「配置管理」页面点击 Edit 检查 YAML 语法 |
| `Core Start Failed, Please Check The Log Infos!` (内核启动失败) | 「运行状态」启动流程 | 核心进程未能启动 | 「运行状态」查看核心版本是否正确；「运行日志」生成调试日志 |
| `Core Initial Configuration Timeout` (内核初始化超时) | 「运行状态」启动流程 | 核心 API 在 300 秒内未就绪 | 检查 `/tmp/openclash.log` 中核心日志；确认「覆写设置→常规」的 cn_port 未被占用 |
| `TUN Interface Start Failed` (TUN 接口启动失败) | 「运行状态」启动流程 | TUN 虚拟网卡创建失败 | 「系统→软件包」确认 `kmod-tun` 已安装 |
| `【{module}】module not found` (内核模块未找到) | 「运行状态」启动流程 | 内核模块未安装/未加载（tun/tproxy 等） | 「系统→软件包」安装对应的 kmod 包 |
| `LAN IP Address Get Error` (LAN IP 获取失败) | 「运行状态」启动流程 | LAN 接口 IP 无效或 `ip-full` 包缺失（旧内核 4.4.x 常见 br-lan 网桥无 IP） | 「插件设置→流量控制」选择正确的 LAN 接口名称（如 `br-lan`）；「系统→软件包」安装 `ip-full`；终端 `ip address show br-lan` 确认存在 IPv4 地址；尝试切换运行模式为混合模式 |
| `OpenClash Now Disabled, Need Start From Luci Page` (插件未启用) | 「运行状态」启动流程 | 插件被禁用（enable=0） | 「运行状态」页面点击启动开关 |

### 二、订阅与配置更新错误

| 错误关键字 | 问题位置 | 原因 | 排查方法 |
|-----------|---------|------|----------|
| `Config File Subscribed Failed` (订阅配置下载失败) | 「配置订阅」更新流程 | 订阅 URL 下载失败（curl 错误） | 「配置订阅」检查订阅 URL 是否正确；确认网络连通性 |
| `Config File Tested Faild` (配置文件测试失败) | 「配置订阅」更新流程 | 下载的 YAML 未通过 `clash -t` 验证 | 「配置管理」页面 Edit 检查 YAML 语法；查看 `/tmp/openclash.log` |
| `Updated Config Has No Proxy Field` (配置无节点字段) | 「配置订阅」更新流程 | 订阅配置中无 `proxies` 和 `proxy-providers` 字段 | 检查订阅源是否有效；可能订阅已过期 |
| `Filter Proxies Failed` (节点筛选失败) | 「配置订阅」更新流程 | 节点关键字过滤正则异常 | 「配置订阅」检查 keyword/ex_keyword 格式 |
| `Ruby Works Abnormally` (Ruby 异常) | 「配置订阅」更新流程 | Ruby 环境异常导致订阅处理失败 | 「系统→软件包」重装 `ruby`、`ruby-yaml` |
| `Config File Format Validation Failed` (配置文件格式校验失败) | 「运行状态」启动流程 | YAML 解析后文件为空/丢失 | 「配置管理」检查配置目录权限和磁盘空间 |

### 三、GEO 与规则更新错误

| 错误关键字 | 问题位置 | 原因 | 排查方法 |
|-----------|---------|------|----------|
| `Download Failed: HTML Response Detected` (下载失败：检测到 HTML 响应) | 「插件设置→GEO 数据库订阅」 | CDN 返回的是 HTML 错误页而非 GEO 文件 | 「覆写设置→常规」检查 Github 地址修改 CDN 选项 |
| `Download Failed: File Size Too Small` (下载失败：文件过小) | 「插件设置→GEO 数据库订阅」 | 下载文件 <1KB，内容不完整 | 「插件设置→GEO 数据库订阅」检查 GEO 自定义 URL 是否正确 |
| `Update Error, Please Try Again Later` (更新失败，请稍后再试) | 「插件设置→GEO 数据库订阅」 | 网络下载失败 | 「运行状态」检查网络连通性；若使用代理下载，添加直连规则 |
| `Control Panel Unzip Error!` (控制面板解压失败) | 「运行状态」仪表盘切换 | Dashboard 压缩包解压失败 | 「系统→软件包」确认 `unzip` 已安装 |
| `LightGBM Model Update Error` (LGBM 模型更新失败) | 「覆写设置→智能设置」 | LGBM 模型下载失败 | 「覆写设置→智能设置」检查模型 URL |

### 四、内核与插件版本更新错误

| 错误关键字 | 问题位置 | 原因 | 排查方法 |
|-----------|---------|------|----------|
| `Core Version Check Error` (内核版本检测失败) | 「版本更新」 | GitHub 不可达，无法获取最新版本信息 | 「运行状态」检查网络连通性；如在大陆，设置 CDN |
| `Core Update Failed` (内核更新失败，重试 3 次后) | 「版本更新」 | 核心下载/解压/替换失败 | 「版本更新」确认闪存空间和 CPU 架构选择；「系统 → 软件包」检查磁盘空间 |
| `No Compiled Version Selected` (未选择编译版本) | 「版本更新」 | CPU 架构未选择（core_version=0） | 「版本更新」标签页选择对应的 CPU 架构 |
| `Pre update test failed` (更新前测试失败，3 次后) | 「版本更新」 | 插件 IPK/APK 安装测试失败 | 手动在「系统→软件包」中更新或重装 luci-app-openclash |
| `OpenClash update failed` (OpenClash 更新失败) | 「版本更新」 | 插件安装彻底失败 | 包已保存在 `/tmp/`，手动使用 `opkg install` 或 `apk add` 安装 |
| `Failed to get version information` (获取版本信息失败) | 「版本更新」 | GitHub 版本检查失败 | 检查网络；「覆写设置→常规」设置 CDN |

### 五、防火墙与 DNS 错误

| 错误关键字 | 问题位置 | 原因 | 排查方法 |
|-----------|---------|------|----------|
| `Dnsmasq not Support nftset, Use ipset` (Dnsmasq 不支持 nftset) | 「运行状态」启动流程 | dnsmasq-full 未编译 nftset 支持 | 警告，非致命；如 chnroute 旁路异常则重装 dnsmasq-full |
| `iptables DSCP module not available` (iptables DSCP 模块不可用) | 「运行状态」启动流程 | iptables 缺少 DSCP 模块 | 警告，DSCP 规则被跳过；或改用核心侧 DSCP |
| `Can't Setting Only Intranet Allowed Function` (无法设置仅允许内网) | 「运行状态」启动流程 | 无法识别 WAN 接口 | 「插件设置→流量控制」检查 WAN 接口名称设置 |
| `Nameserver Option Must Be Setted, Stop Customing DNS Servers` (Nameserver 未设置) | 「覆写设置→DNS」 | 自定义 DNS 启用但未配置任何 nameserver | 「覆写设置→DNS」添加至少一个 DNS 服务器 |
| `Fallback-Filter Need fallback of DNS Been Setted` (Fallback-Filter 需要 Fallback DNS) | 「覆写设置→DNS」 | fallback-filter 需要先配置 fallback DNS | 「覆写设置→DNS」先添加 fallback 分组的 DNS 服务器 |
| `DNS Loop Check` (DNS 回环检查) | 「覆写设置→DNS」 | DNS 配置存在回环风险 | 「覆写设置→DNS」检查服务器列表，避免将 Clash DNS 端口设为其上游 |

### 六、覆写模块错误

| 错误关键字 | 问题位置 | 原因 | 排查方法 |
|-----------|---------|------|----------|
| `skip General key not allowed` (覆写 key 不允许) | 「覆写设置」覆写模块 | 覆写 [General] 中的 key 不在允许列表中 | 检查 key 拼写；参考覆写模块 10.2.1 节的允许 key 列表 |
| `skip invalid Overwrite command` (无效覆写命令) | 「覆写设置」覆写模块 | [Overwrite] 段命令不以 `ruby_` 开头 | 修正命令语法，使用 `ruby_method_name` 格式 |
| `Invalid YAML Override format` (无效 YAML 覆写格式) | 「覆写设置」覆写模块 | [YAML] 段不是有效的 Hash 结构 | 检查 YAML 缩进和格式 |
| `Parse YAML Override failed` (YAML 覆写解析失败) | 「覆写设置」覆写模块 | [YAML] 段 Ruby 解析异常 | 逐行检查 YAML 语法 |
| `Config File Overwrite Failed` (配置文件覆写失败) | 「覆写设置」覆写模块 | 覆写应用整体失败 | 检查所有覆写设置的语法 |
| `DOWNLOAD FILE failed` (文件下载失败) | 「覆写设置」覆写模块 | 覆写模块 DOWNLOAD_FILE 下载失败 | 检查下载 URL 和网络连通性 |

### 七、流媒体解锁错误

| 错误关键字 | 问题位置 | 原因 | 排查方法 |
|-----------|---------|------|----------|
| `Streaming Unlock Could not Work Because of Router-Self Proxy Disabled` (流媒体解锁失效：本机代理关闭) | 「运行状态」看门狗 | 路由器自代理关闭导致流媒体解锁无法工作 | 「插件设置→流量控制」开启本机代理 |
| `Something Wrong While Testing` (流媒体测试失败) | 「插件设置→流媒体增强」 | 流媒体测试脚本执行失败 | 「运行状态」确认核心运行中；「插件设置→流媒体增强」检查策略组配置 |

### 八、LuCI Web 界面错误

| 错误提示 | 问题位置 | 原因 | 排查方法 |
|----------|---------|------|----------|
| `Switch Faild` (切换失败) | 「运行状态」快捷设置 | API 不可达或核心未运行 | 「运行状态」确认核心状态；刷新页面后重试 |
| `Config file does not exist` (配置文件不存在) | 「配置管理」 | 配置文件路径无效 | 「配置管理」检查文件名；确认文件存在于配置列表中 |
| `File size exceeds 10MB limit` (文件超过 10MB 限制) | 「配置管理」上传 | 上传文件超过 10MB | 减小文件或拆分上传 |
| `Cannot delete the last remaining dashboard` (无法删除最后一个仪表盘) | 「运行状态」仪表盘切换 | 只剩一个仪表盘时不允许删除 | 「运行状态」先下载新的仪表盘再删除旧的 |
| `Failed to generate age key` (生成 Age 密钥失败) | 「配置订阅」Age 密钥 | 核心不支持 age keygen | 「版本更新」检查核心版本；手动生成 age 密钥 |
| `Failed to calculate public key` (计算公钥失败) | 「配置订阅」Age 密钥 | 密钥格式无效 | 验证 age 密钥格式（应以 `AGE-SECRET-KEY-` 开头） |
| `Bad address specified!` (地址无效) | 「运行状态」连接诊断 | 输入地址为空或无效 | 输入有效的主机名或 IP 地址 |
| `OpenClash Start Failed: {msg}` (OpenClash 启动失败) | 「运行状态」 | 核心日志中出现 fatal/error 级别日志 | 查看完整错误消息；「运行日志」生成调试日志 |
| `Access Denied` (无法访问) / `Access Timed Out` (连接超时) | 「运行状态」IP 检测 | 网络连接问题 | 检查路由器网络连接 |

### 九、YAML 配置处理错误

| 错误关键字 | 问题位置 | 原因 | 排查方法 |
|-----------|---------|------|----------|
| `Load File Failed` (加载文件失败) | 「配置管理」配置加载 | Ruby 无法加载配置文件 | 确认配置文件存在且权限正确 |
| `Set Custom DNS Failed` (自定义 DNS 设置失败) | 「覆写设置→DNS」 | DNS 覆写处理失败 | 检查「覆写设置→DNS」中的 DNS 服务器配置 |
| `Set Fake-IP-Filter Failed` (Fake-IP-Filter 设置失败) | 「覆写设置→DNS」 | Fake-IP 过滤器配置异常 | 「覆写设置→DNS」检查 Fake-IP-Filter 文件和模式 |
| `Set Hosts Rules Failed` (Hosts 规则设置失败) | 「覆写设置→DNS」 | 自定义 Hosts 格式错误 | 「覆写设置→DNS」检查 hosts 文件每行格式 |
| `Set Custom Rules Failed` (自定义规则设置失败) | 「覆写设置→规则」 | 自定义规则注入异常 | 「覆写设置→规则」检查规则文件语法 |
| `Skiped The Custom Rule Because Group & Proxy Not Found` (规则跳过：策略组/代理不存在) | 「覆写设置→规则」 | 规则引用了不存在的策略组/代理 | 「覆写设置→规则」检查规则中 MATCH/Proxy/策略组名称是否存在 |
| `Set BT/P2P DIRECT Rules Failed` (BT/P2P 直连规则设置失败) | 「覆写设置→规则」 | BT 直连规则注入失败 | 「覆写设置→规则」关闭再重新开启「仅代理命中规则流量 (Rule Match Proxy Mode)」选项 |
| `proxy-groups Get Failed` (策略组获取失败) | 「配置管理」策略组 | 配置中策略组解析异常 | 「配置管理」页面 Edit 检查 proxy-groups 段 |

### 十、Ruby YAML 模块错误

| 错误关键字 | 问题位置 | 原因 | 排查方法 |
|-----------|---------|------|----------|
| `Fix short-id values type failed` (short-id 类型修复失败) | 「配置管理」YAML 处理 | YAML 中 `short-id` 字段值类型修复时 Psych 解析异常 | 「配置管理」Edit 检查配置中 `short-id` 字段的值格式 |
| `YAML overwrite failed:【key: ...】` (YAML 覆写失败) | 「覆写设置」覆写模块 | 覆写模块 YAML 合并时发生异常 | 「覆写设置」检查 `[YAML]` 段的语法和操作符使用 |
| `YAML overwrite failed:【(match value) => ...】` (YAML 条件覆写匹配失败) | 「覆写设置」覆写模块 | 批量条件更新的 where 匹配逻辑异常 | 「覆写设置」检查 `key*` 操作符的 where 条件格式和正则 |
| `YAML overwrite failed:【(batch update) => ...】` (YAML 批量更新失败) | 「覆写设置」覆写模块 | 批量条件更新执行时异常 | 「覆写设置」检查 `key*` 操作符的 set 子句语法 |
| `Write file failed` (写文件失败) | 「配置管理」YAML 写入 | YAML 写入文件时 I/O 异常 | 检查磁盘空间和文件权限 |
| `Decrypt attempt failed` (解密尝试失败) | 「配置订阅」Age 解密 | Age 加密文件解密失败 | 「配置订阅」检查 age 密钥是否正确；验证加密文件完整性 |
| `Decrypted content empty or still encrypted` (解密后为空或仍加密) | 「配置订阅」Age 解密 | Age 解密后内容为空或仍为加密格式 | 「配置订阅」确认 age 密钥与加密时使用的密钥匹配 |
| `Encrypt attempt failed` (加密尝试失败) | 「配置订阅」Age 加密 | Age 加密写入时失败 | 「配置订阅」检查 age 公钥格式；验证核心年龄功能 |
| `Encrypted file: decryption failed` (加密文件解密失败) | 「配置订阅」Age 解密 | 所有 age 密钥尝试均解密失败 | 「配置订阅」检查所有订阅的 age 密钥；可能密钥不匹配 |

### 十一、Mihomo 内核配置解析错误（`level=fatal` / `level=error`）

> 以下为 Mihomo 内核在**加载/解析 YAML 配置文件**时产生的错误。`level=fatal` 会导致核心进程退出。
> 日志查看：LuCI「运行日志」页面或「运行状态」页面（若启动失败会显示 `OpenClash Start Failed`）。

`Parse config error` 的具体子类型及修复方法：

| 错误详情 | 配置段 | 修复方法 |
|---------|--------|----------|
| `proxy <N>: missing type` | `proxies` | 在「配置管理」Edit 中给第 N 个代理节点添加 `type:` 字段（如 `ss`, `vmess`, `trojan` 等） |
| `proxy <N>: unsupport proxy type: <type>` | `proxies` | 代理类型名称拼写错误或不支持，检查 `type:` 值是否在 Mihomo 支持列表中 |
| `proxy <name> is the duplicate name` | `proxies` | 两个代理节点同名，在「配置管理」Edit 中修改其中一个的名称 |
| `proxy group <N>: missing name` | `proxy-groups` | 第 N 个策略组缺少 `name:` 字段，Edit 中补充 |
| `<groupName>: unsupported type` | `proxy-groups` | 策略组 `type:` 值无效，改为 `select`, `url-test`, `fallback`, `load-balance` 或 `smart` |
| `loop is detected in ProxyGroup` | `proxy-groups` | 策略组之间存在循环引用（A 引用 B，B 又引用 A），打破循环链 |
| `<groupName>: use or proxies missing` | `proxy-groups` | 策略组没有配置 `proxies:` 或 `use:`，至少添加一个 |
| `'<name>' not found` | `proxy-groups` | 策略组引用了不存在的代理节点或 provider 名称，检查拼写 |
| `can not defined a provider called 'default'` | `proxy-providers` | provider 使用了保留名 `default`，改用其他名称 |
| `unsupport vehicle type: <type>` | `proxy-providers` / `rule-providers` | provider 的 `type:` 值无效，应为 `file`, `http` 或 `inline` |
| `file must have a payload field` | `rule-providers` | 规则集文件缺少 `payload:` 字段，检查文件内容格式 |
| `rules[<N>] [<line>] error: format invalid` | `rules` | 第 N 条规则格式错误，检查规则语法：`TYPE,payload,target,no-resolve` |
| `rules[<N>] [<line>] error: proxy [<name>] not found` | `rules` | 规则目标引用了不存在的策略组/代理名称 |
| `rules[<N>] [<line>] error: rule set [<name>] not found` | `rules` | 规则使用了 `RULE-SET,<name>` 但未在 `rule-providers` 中定义该名称 |
| `sub-rule error: circular references` | `sub-rules` | 子规则之间形成循环引用链，打破循环 |
| `decrypt config error` | 全局 | Age 加密的配置文件解密失败，在「配置订阅」中检查 age 密钥 |
| `configuration file ... is empty` | 全局 | 配置文件为空，在「配置管理」中检查配置是否正常下载 |
| `[Smart] Invalid policy-priority rule: must be in 'pattern:factor' format` | `smart` 策略组 | 「覆写设置→智能设置」中 `smart_policy_priority` 格式错误，改为 `名称:系数` |
| `DNS [addr] config with invalid ecs` | `dns` | DNS 服务器的 ECS 配置格式无效，「覆写设置→DNS」检查 DNS 服务器设置 |
| `[Smart] Model.bin invalid, remove and download` | Smart 模型 | 「覆写设置→智能设置」点击手动更新模型按钮重新下载 |
| `[CacheFile] remove invalid cache file error` | 运行缓存 | 「运行状态」停止 OpenClash，手动删除 `/etc/openclash/cache.db` 后重启 |

> **通用排查**: 在「配置管理」页面点击 **Download Run** 下载经脚本处理后的运行时配置，对比原始订阅检查 `yml_change.sh` 和覆写模块生成的 YAML 是否正确。

### 十二、DNS 泄露排查

> **核心验证方法**：在客户端执行 `nslookup www.google.com`，应返回：① DNS 服务器为 OpenWrt 路由器 IP；② 解析结果为 Fake-IP 范围地址（`198.18.x.x`）。若返回真实 IP 或上游 DNS 非路由器，说明 DNS 解析链路异常。正确链路应为：`设备 → Dnsmasq(53端口) → OpenClash(7874端口)`。

| 错误关键字 | 问题位置 | 原因 | 排查方法 | 来源 |
|-----------|---------|------|----------|------|
| DNS 泄露（ipleak / `ipleak.net` 检测到国内 DNS） | 「覆写设置→DNS」 | Redir-Host/Fake-IP 下 nameserver 和 fallback 并发请求，国内 DNS 结果可能被优先采纳 | ① Meta 内核建议**放弃 fallback**，仅用 `nameserver-policy` 做 DNS 分流（国内域名→国内 DNS，国外域名→国外 DNS）；② 境外 DNS 地址后加 `#PROXY` 强制走代理（如 `https://1.1.1.1/dns-query#PROXY`）；③ 删除原配置 YAML 的 `dns:` 段，仅通过「覆写设置→DNS」管理 DNS 配置避免冲突；④ 将 `proxy-server-nameserver` 设为国内 DNS 避免代理节点域名解析走境外 | [#3843](https://github.com/vernesong/OpenClash/issues/3843) |
| `nameserver-policy` 未生效，DNS 仍走 nameserver | 「覆写设置→DNS」 | OpenClash 的「覆写设置→DNS」选项会与订阅配置的 `dns:` 段合并，可能导致预期外的 DNS 行为 | ① 在「覆写设置→DNS」启用「自定义 DNS 设置 (Custom DNS Setting)」后重新配置所有 DNS 规则；② 在「运行日志」中开启 Debug 等级观察实际 DNS 查询路径；③ 确认 `default-nameserver` 组的 DNS 服务器开启了「节点域名解析」选项 | 同上 |
| DNS 泄露（开启 IPv6 后出现） | 「覆写设置→DNS」+「IPv6 设置」 | 运营商下发的 IPv6 DNS 绕过了 OpenClash 的 DNS 劫持，直接响应客户端请求（"抢答"） | ① 在 LuCI 的「网络→DHCP/DNS→高级设置」中取消 `过滤 IPv6 AAAA 记录`；② 在 LAN 接口 DHCP 服务器 IPv6 设置中**取消「本地 IPv6 DNS 服务器」**，强制设备使用路由器 IPv4 地址进行 DNS 解析；③ DHCPv6 服务设为已禁用，RA 设为服务器模式。原理：DNS 请求走 IPv4 通道，流量走 IPv6 通道——IPv4 DNS 同样可以查询 AAAA 记录返回 IPv6 地址 | — |
| 旁路由环境下 DNS 泄露 | 「运行状态」 | 旁路由设备未正确指定上游 DNS 为 OpenWrt IP（尤其是 IPv6 DNS 留空） | ① 旁路由设备必须**手动指定 IPv4 DNS 为 OpenWrt 路由器 IP**；② **IPv6 DNS 必须留空**；③ 若使用 DHCP 分配，确保 DHCP 服务器不下发 IPv6 DNS 地址 | — |

### 十三、版本更新与下载失败

| 错误关键字 | 问题位置 | 原因 | 排查方法 | 来源 |
|-----------|---------|------|----------|------|
| `/tmp/openclash_last_version` 下载失败 | 「运行日志」/ 启动流程 | ① curl SSL 证书验证失败（`BADCERT_CN_MISMATCH` / `self signed certificate`）；② GitHub Raw 域名被 DNS 污染或不可达；③ curl 超时（`Operation timed out`）；④ 缺少 `libmbedtls` 库 | ①「覆写设置→常规」设置 **Github 地址修改 (github_address_mod)** 为 CDN（推荐 `https://fastly.jsdelivr.net/` 或 `https://testingcf.jsdelivr.net/`）；②「系统→软件包」确认 `ca-bundle` 已安装；③ Fake-IP 模式在「覆写设置→DNS」的 fake-ip-filter 中排除 `raw.githubusercontent.com`；④ 修改 `/usr/share/openclash/openclash_core.sh` 中 curl 的超时参数 `-m 60` 改为 `-m 300`；⑤ 终端执行 `opkg install libmbedtls` 修复 curl 库依赖 | [#2791](https://github.com/vernesong/OpenClash/issues/2791) |
| **更新内核 (Update Core)** 点击后重启失败 | 「运行状态」页面 | v0.47.052 重启流程中 stop→start 间隔不足，旧核心进程未完全退出即启动新核心，触发「内核启动失败」 | ① 更新到 v0.47.054+（已在 Developer 分支修复）；② 临时解决：编辑 `/etc/init.d/openclash`，在 restart 函数的 stop 和 start 之间加 `sleep 5`；③ 如更新后仍失败，检查内存是否不足（小型设备建议增加 swap） | [#4969](https://github.com/vernesong/OpenClash/issues/4969) |
| 升级后依赖检查异常，无法启动 | 「运行日志」启动流程 | 更新后 `check_mod()` 或依赖检测逻辑误报 | ①「运行日志」生成调试日志检查依赖段；②「系统→软件包」确认 `kmod-nft-tproxy`/`kmod-ipt-tproxy` 已安装；③ 切换 Dev 分支获取最新修复；④ 重装 `luci-app-openclash` | [#4807](https://github.com/vernesong/OpenClash/issues/4807) |
| v0.47.052/055 无法开机自启 | 「运行状态」启动流程 | 启动时序竞争条件，procd respawn 在某些固件上触发过快 | ① 更新到最新 Dev 版本；②「插件设置→模式设置」设置 `delay_start` (启动延迟) 30-60 秒；③ 确保路由器有足够内存供启动时使用 | [#4973](https://github.com/vernesong/OpenClash/issues/4973) |

### 十四、功能异常类

| 错误关键字 | 问题位置 | 原因 | 排查方法 | 来源 |
|-----------|---------|------|----------|------|
| **向日葵/AnyDesk 等远程软件无法连接** | 局域网客户端 | 远程软件域名/QUIC 流量被代理或阻断 | ①「覆写设置→规则」添加直连规则：`DOMAIN-SUFFIX,oray.com,DIRECT`、`DOMAIN-SUFFIX,sunlogin.net,DIRECT` 等；② 确认 sniffer `skip-domain` 已包含 `oray.com` 和 `sunlogin.net`（默认已含）；③ 尝试关闭「插件设置→流量控制」的 `disable_udp_quic` (禁用 QUIC) | [#3229](https://github.com/vernesong/OpenClash/issues/3229) |
| **小米摄像机/智能家居外网无法访问** | 局域网 IoT 设备 | IoT 设备流量被代理导致 NAT 穿透失败 | ①「插件设置→黑白名单」添加摄像机 IP 到「不走代理的局域网设备 IP (LAN Bypassed Host List)」列表；② 确认 sniffer `skip-domain` 包含 `Mijia Cloud`（默认已含）；③「覆写设置→规则」添加 IoT 域名直连规则：`DOMAIN-SUFFIX,xiaomi.com,DIRECT` | [#2431](https://github.com/vernesong/OpenClash/issues/2431) |
| **绕过中国大陆IP (China IP Route) 功能突然失效** | 升级后 / 「运行状态」 | 版本升级后 `china_ip_route` 的 nftables/ipset 重建失败或 chnroute 列表未更新 | ①「插件设置→大陆白名单订阅」手动更新一次大陆 IP 列表；②「运行状态」页面 Area Bypass 先切到关闭再切回「绕过中国大陆 (Bypass Mainland China)」重新触发；③ 终端执行 `nft list set inet fw4 china_ip_route | head` 检查 nft set 是否存在且非空 | [#4031](https://github.com/vernesong/OpenClash/issues/4031) |
| **自定义防火墙规则（开发者选项）不生效** | 「插件设置→开发者设置」 | 编辑后未重启或脚本语法错误 | ① 修改 `openclash_custom_firewall_rules.sh` 后需**重启 OpenClash**（不是重载防火墙）；② 用 `bash -n` 检查脚本语法；③「运行日志」生成调试日志检查是否成功执行（日志中含自定义脚本内容） | [#4005](https://github.com/vernesong/OpenClash/issues/4005) |
| **DDNS 服务（如 DDNS-GO）工作异常** | 路由器 DDNS 插件 | DDNS 服务商 API 域名被错误分配 Fake-IP，导致 IP 检测失败 | ① 将 DDNS 服务商的 API 域名加入「覆写设置→DNS」的 Fake-IP-Filter 中（填入域名使其返回真实 IP）；② 常见需排除的域名如 `ddns.oray.com`、`api.cloudflare.com` 等，具体根据所用服务商填写 | — |
| **Cloudflare Tunnel (Cloudflared) 连接不稳定** | 路由器/内网设备 | Cloudflared 默认使用 QUIC 连接，而海外 QUIC 流量默认被 OpenClash 阻断 | ① 规则中已指定 Cloudflare Tunnel 相关域名直连；② 在 Cloudflared 启动参数中显式指定 `--protocol http2` 强制使用 HTTP/2（Docker 版：`command: [tunnel, --no-autoupdate, --protocol, http2, run, --token, ${CF_TOKEN}]`） | — |
| **BT/PT 下载流量进入内核** | 下载设备 | 下载设备流量未正确分流 | ① 若下载设备为独立设备（如 NAS），在「覆写设置→规则→自定义规则」中添加 `SRC-IP-CIDR,192.168.1.x/32,DIRECT`；② 若同时启用了 IPv6，还需添加 IPv6 后缀规则 `SRC-IP-SUFFIX,::a1b2:c3d4,DIRECT`（后缀由 EUI-64 生成，可在设备上查看）；③ 非独立设备可设置「非标端口」策略组直连来规避 80/443 以外的下载流量 | — |
| **直连网站/APP/小程序打不开** | 局域网客户端 | 小众域名未被 geosite:cn 收录，被误判为非直连走代理 | ① 临时方案：将「漏网之鱼」策略组设为直连；② 永久方案：在「覆写设置→规则→自定义规则」中为对应域名添加 `DOMAIN-SUFFIX,xxx.com,DIRECT` 规则；③ 观察 zashboard 中命中策略组确认分流是否正确 | — |
| **开启 IPv6 后某些直连访问卡顿** | 局域网客户端 | IPv6 DNS 抢答或运营商 IPv6 DNS 不稳定导致解析异常 | ① 禁用「覆写设置→DNS」的「追加上游 DNS」，改为在 NameServer 中手动添加 DoH 服务器（如 AliDNS）；② 确保 LAN 口未下发 IPv6 DNS 地址 | — |
| **非直连站点打不开且内核日志无记录** | 「运行状态」 | WAN 接口名称填写错误或 DNS 重定向未关闭 | ①「插件设置→流量控制」清空 WAN 接口名称；② 确认「网络→DHCP/DNS」中 DNS 重定向功能已关闭；③ 两者均正确时，检查 OpenWrt 中是否有其他劫持 53 端口或修改 Dnsmasq 的插件 | — |
| **Hysteria / Hysteria2 / TUIC 节点连接失败、断流、握手超时** | 内核日志 `level=error` | ① Linux 内核 ≥6.6 的 quic-go GSO 兼容性问题（最常见）；② Hysteria 协议对 `server`/`auth`/`tls`/`password` 字段配置敏感 | ① **优先尝试**：「插件设置→模式设置」开启**「禁用 quic-go GSO (Disable QUIC Go GSO)」**后重启 OpenClash；② 确认 YAML 中 `type: hysteria` 或 `type: hysteria2` 拼写正确、端口号正确；③ 检查节点的 `auth`/`password` 及 TLS 证书配置是否完整 | — |
| **开启「绕过中国大陆 IP」后 Google Play 商店无法下载/更新** | 客户端（Android 设备） | `services.googleapis.cn` 等 Google 域名被国内 DNS 解析到中国大陆 IP（`220.181.x.x`），被 `china_ip_route` 规则匹配后走直连；但 Google 中国服务器禁止境外 IP（代理节点）访问，导致死循环 | **从 DNS 和规则两方面同时入手**：<br><br>**① DNS 层面** — 在「覆写设置→DNS→自定义 DNS 设置」中配置 `nameserver-policy` 强制 Google 域名走境外 DNS 解析，写入 YAML 的 `dns.nameserver-policy` 段：<br>```yaml<br>dns:<br>  nameserver-policy:<br>    '+.services.googleapis.cn': 'https://dns.google/dns-query'<br>    '+.googleapis.cn': 'https://dns.google/dns-query'<br>    '+.xn--ngstr-lra8j.com': 'https://dns.google/dns-query'<br>```<br>也可用 `8.8.8.8` 或 `1.1.1.1` 替代 `https://dns.google/dns-query`。效果：域名解析到 Google 境外 IP（如 `142.250.x.x`），而非国内 `220.181.x.x`。<br><br>**② 规则层面** — 在「覆写设置→规则→自定义规则」中添加，写入 YAML 的 `rules` 段：<br>```yaml<br>rules:<br>  - DOMAIN-SUFFIX,services.googleapis.cn,Proxy<br>  - DOMAIN-SUFFIX,googleapis.cn,Proxy<br>  - DOMAIN-SUFFIX,xn--ngstr-lra8j.com,Proxy<br>```<br>其中 `Proxy` 替换为你的代理策略组名。更彻底的方式：`GEOSITE,google,Proxy` 将全部 Google 流量走代理。<br><br>**验证**：终端执行 `dig services.googleapis.cn @127.0.0.1 -p 7874` 应返回境外 IP；在 zashboard 连接日志中确认域名命中代理规则。 | [#5074](https://github.com/vernesong/OpenClash/issues/5074) |

### 十五、运行时状态异常

| 错误关键字 | 问题位置 | 原因 | 排查方法 | 来源 |
|-----------|---------|------|----------|------|
| **节点正常，突然无法访问外网** | 「运行状态」一切正常但客户端无网络 | DNS 劫持失效（dnsmasq 被其他插件修改）、防火墙规则乱序、TUN 路由表丢失 | ①「运行状态」确认核心和 DNS 端口正常；② 在「运行日志」中检查最近的错误；③「运行状态」点击「Reload Firewall (重置防火墙)」重建规则；④ 检查是否同时运行其他代理/DNS 插件（如 AdGuard Home、PassWall、SSR-Plus 等），OpenClash 不能与这些插件共存 | [#3516](https://github.com/vernesong/OpenClash/issues/3516) |
| **防火墙 DNS 劫持规则不停被还原** | 「运行日志」反复出现防火墙重载记录 | 看门狗检测到规则异常后自动重载，形成循环（v0.46.001-beta 已知问题） | ① 更新到最新版本（已在后续版本修复）；② 临时关闭看门狗自动修复（编辑 `openclash_watchdog.sh` 注释掉防火墙重载部分）；③ 检查是否有其他程序在修改防火墙规则（如 Docker、UPnP 服务） | [#3765](https://github.com/vernesong/OpenClash/issues/3765) |

### 十六、旁路由 / 特定设备异常

| 错误关键字 | 问题位置 | 原因 | 排查方法 | 来源 |
|-----------|---------|------|----------|------|
| 旁路由 R2S 等 ARM 设备 iPhone 待机耗电严重 | 局域网 | 代理模式下 ARP 代理或 TUN 模式的 keepalive 导致 iPhone 频繁被唤醒 | ① 尝试切换为 Fake-IP 模式；② 关闭「仅允许内网 (Only Intranet Allowed)」以外的 WAN 口访问；③ 主路由 DHCP 下发的网关和 DNS 指向旁路由 IP | [#2614](https://github.com/vernesong/OpenClash/issues/2614) |
| 在 Fake-IP 模式下无法使用 UU 加速器等游戏加速软件 | 「运行状态」 | 游戏加速器需要真实 DNS 解析来优化连接，Fake-IP 返回虚拟 IP 导致失效 | ① 在「覆写设置→DNS」的 fake-ip-filter 中添加加速器相关域名（如 `+.leigod.com`、`+.vivox.com`）；② 将加速器所在设备的 IP 加入「不走代理的局域网设备 IP (LAN Bypassed Host List)」 | [#1751](https://github.com/vernesong/OpenClash/issues/1751) |

---

# 第一部分：运行状态页面 (Overviews / client)

> LuCI 路径: `服务` → `OpenClash` → `运行状态`
> 数据来源: 前端 JS 同时请求多个后端端点：`/status` (运行状态、仪表盘设置)、`/toolbar_show` (流量统计)、`/update` (版本信息)、`/oc_settings` (快捷设置)、`/rule_mode` (代理模式)、`/config_file_list` (配置文件列表) 等。版本信息通过 `/update` 端点 (action_update) 返回，非 `/status` 端点。`/status` 仅返回运行状态布尔值、仪表盘可用性和 core_type，不包含版本号。

## 1.1 核心控制卡片

| 元素 | 功能 | 后端操作 |
|------|------|----------|
| **启动/停止开关** | 切换核心运行状态 | 调用 `action_oc_action` → `/etc/init.d/openclash start/stop` |
| **重启按钮** | 重启核心 | 调用 `/etc/init.d/openclash restart` |
| **覆写模块按钮** | 在运行状态页弹出覆写编辑器（与菜单「服务→OpenClash→覆写设置」独立） | 调用 `editOverwrite()` → 在运行状态页弹出覆写编辑模态框 |
| **插件/核心版本** | 显示当前版本号 | 核心版本: 执行 `/etc/openclash/core/clash_meta -v` 解析输出; 插件版本: 读取 opkg/apk 包数据库; 远程最新: 读取 `/tmp/clash_last_version`。前端通过 `/update` 端点 (action_update) 获取，非 `/status` 端点 |
| **主题切换** | Light(太阳)/Dark(月亮)/Auto(自动) 三档切换 | 前端 CSS 变量 + localStorage |
| **公告横幅** | 滚动显示项目公告 (24h 缓存) | `/announcement` 端点 |
| **社交链接** | Wiki / Tutorials / Star / Telegram / Sponsor / Mihomo 图标 | 外部链接 `window.open()` |
| **开发者头像** | 13 位贡献者头像网格 (悬停显示名称) | 来自 GitHub 头像 URL |

## 1.2 运行模式卡片 (Running Mode)

| 模式 | UCI `en_mode` 值 | 说明 |
|------|-----------------|------|
| **兼容 (Compat)** | `redir-host` | Redir-Host 模式，使用 iptables redirect 转发流量 |
| **TUN 模式** | `redir-host-tun` / `fake-ip-tun` | 使用 TUN 虚拟网卡接管所有流量 |
| **混合 (Mix)** | `redir-host-mix` / `fake-ip-mix` | TUN + Redirect 混合，TCP 走 system 栈、UDP 走 gvisor 栈 |

> 切换触发: `action_switch_run_mode` → 修改 UCI `en_mode`，若运行中则自动重启

## 1.3 代理模式卡片 (Proxy Mode)

| 模式 | Mihomo `mode` 值 | 效果 |
|------|-----------------|------|
| **策略代理 (Rule)** | `rule` | 按 YAML 中 `rules:` 规则集合分流 |
| **全局代理 (Global)** | `global` | 所有流量走 GLOBAL 策略组所选代理 |
| **全局直连 (Direct)** | `direct` | 所有流量直连，不经过任何代理 |

> 切换触发: `action_switch_rule_mode` → PATCH Mihomo API `/configs` 的 `mode` 字段，同时更新 UCI `proxy_mode`

## 1.4 快捷设置网格

| 设置项 | 功能 | UCI 选项 | 触发函数 |
|--------|------|----------|----------|
| **地区绕行 (Area Bypass)** | 切换中国 IP/海外绕行 | `china_ip_route` (0/1/2) | `action_switch_oc_setting` → 修改 UCI + 重启 |
| **域名嗅探 (Sniffer)** | 是否启用 Mihomo 域名嗅探 | `enable_meta_sniffer` | `action_switch_oc_setting` → 动态修改运行时 YAML `sniffer.enable` |
| **DNS 尊重规则 (DNS Proxy)** | DNS 查询是否遵守路由规则 | `enable_respect_rules` | `action_switch_oc_setting` → 动态修改 YAML `dns.respect-rules` |
| **流媒体解锁 (Stream Unlock)** | 一键启用流媒体解锁 | `stream_auto_select` | `action_switch_oc_setting` → 设置 `stream_auto_select=1` 及 Netflix/Disney/HBO 默认参数 |

## 1.5 配置文件卡片

| 操作 | 功能 | 后端路由 |
|------|------|----------|
| **配置文件选择器** | 下拉切换当前使用的 YAML 配置 | `action_switch_config` → 更新 `config_path` + 自动重启 |
| **切换 (Switch)** | 切换到选中的配置 | 同上 |
| **更新配置** | 重新下载订阅并更新 | `action_update_config` → 调用 `openclash.sh` |
| **编辑 (Edit)** | 在线编辑 YAML 配置文件 | 弹出 `config_edit` 模态框 (基于 CodeMirror，支持原始/运行时视图切换、合并视图对比、覆写卡片栏) |
| **编辑订阅** | 修改该配置的订阅参数 | 跳转到 `config-subscribe-edit` |
| **上传** | 上传新的 YAML 配置文件 | 弹出 `config_upload` 模态框 (支持文件上传 + 订阅链接两个标签页) |
| **刷新订阅按钮** | 手动刷新当前配置的订阅信息 | `/sub_info_get` 端点 |
| **指定 URL 按钮** | 设置订阅信息查询 URL | `/set_subinfo_url` 端点 |
| **订阅进度条** | 显示订阅流量使用情况 (已用/总量/百分比) | `/sub_info_get` 自动轮询 |

## 1.6 控制面板卡片

显示当前 Dashboard 访问地址及 Secret 密码。对应 UCI:
- `cn_port` — API 端口 (默认 9090)，对应 Mihomo `external-controller`
- `dashboard_password` — API 密钥，对应 Mihomo `secret`
- `dashboard_forward_domain` / `dashboard_forward_port` / `dashboard_forward_ssl` — 公网访问设置
- 提供 **复制 IP** 和 **复制密钥** 按钮

## 1.7 混合代理卡片

显示 SOCKS5/HTTP 代理地址，可复制或生成 PAC 文件：
- `mixed_port` (默认 7893), `http_port` (7890), `socks_port` (7891)
- 用户认证: `authentication` TypedSection 中的 `username`/`password`，对应 Mihomo `authentication` 配置
- 提供 **复制代理地址**、**复制认证信息**、**生成 PAC 配置** 按钮

## 1.8 仪表盘入口 (Control Panel)

4 种可选仪表盘：**Dashboard** (Yacd)、**Yacd**、**Metacubexd**、**Zashboard**
- 对应 Mihomo `external-ui` 配置
- 切换触发: `action_switch_dashboard` → `openclash_download_dashboard.sh`
- 默认仪表盘: UCI `default_dashboard`
- **前端访问地址**（`status.htm` JS 按 3 种场景构造）：
  - **本地访问**（浏览器 hostname 匹配 LAN IP）：`http://<lan_ip>:<cn_port>/ui/<dashboard>/`
  - **公网访问**（设置了 `dashboard_forward_domain` + `dashboard_forward_port`）：`http[s]://<domain>:<port>/ui/<dashboard>/`（协议由 `dashboard_forward_ssl` 决定）
  - **其他情况**：取当前页面协议 + `lan_ip` + `cn_port`
- 各仪表盘子路径：`/ui/dashboard/`、`/ui/yacd/`、`/ui/metacubexd/`、`/ui/zashboard/`

## 1.9 快捷操作按钮 (Quick Action)

| 操作 | 功能 | 后端 |
|------|------|------|
| **关闭链接 (Close Connect)** | 断开所有代理连接 | `openclash_history_get.sh 'close_all_conection'` |
| **重置防火墙 (Reload Firewall)** | 重新应用 iptables/nftables 规则 | `/etc/init.d/openclash reload 'manual'` |
| **清空 DNS 缓存** | 刷新 Fake-IP 和 DNS 缓存 | POST `/cache/fakeip/flush` + `/cache/dns/flush` |
| **检查更新 (Check Update)** | 同时更新插件 + 核心 + 订阅 + GEO | `openclash_update.sh 'one_key_update'` |

## 1.10 统计信息

页面底部显示 8 项实时统计指标，通过 WebSocket 和 XHR 轮询更新：

| 指标 | 说明 |
|------|------|
| 上行速率 | 当前上传速率 |
| 下行速率 | 当前下载速率 |
| 上行总量 | 累计上传流量 |
| 下行总量 | 累计下载流量 |
| 连接数 | 当前活动连接数 |
| 内存 | 核心内存占用 |
| CPU | 核心 CPU 占用 |
| 平均负载 | 系统平均负载 |

## 1.11 IP 检测页 (IP Address / 访问检查)

**IP 地址部分 (IP Address)**：
- 并行查询 4 个 IP 源：UpaiYun、IPIP.NET、IP.SB、IPIFY，每个显示 IP 地址 + 地理信息
- 隐私切换按钮（眼睛图标）：点击后用 `***.***.***.***` 隐藏所有 IP 显示（状态持久化到 localStorage）

**访问检测部分 (Access Check)**：
- 两种检测模式：路由器模式（后端 XHR 代理检测）和浏览器模式（前端 fetch 直接检测），通过模式切换图标切换
- 4 个网站可达性检测：**Baidu Search** (百度搜索)、**NetEase Music** (网易云音乐)、GitHub、YouTube，各显示 HTTP 状态码和加载延迟（ms）
- 刷新按钮：重新执行所有 IP 查询和 HTTP 检测

**轮询间隔**: HTTP 检测 5-20 秒，IP 检测 15-40 秒。

## 1.12 oixCloud 面板 (oixCloud)

仅在设置了 `oix_token` 时显示，展示 oixCloud 订阅服务信息：

- **Logo + 标语**（随机变化）
- **公告横幅**（60 秒后自动消失）
- **计划信息**：计划类型、到期时间、账户余额、推广余额、积分
- **流量统计**：今日已用、计划已用、剩余流量、总流量
- **签到按钮**：每日签到获取流量
- **底部链接**："Powered by oixcloud.com"

> 登录入口：在「插件设置 → oixCloud」标签页中通过 Login Account 按钮登录。

---

# 第二部分：插件设置页面 (Plugin Settings / settings)

> UCI Section: `openclash` (anonymous section)
> 所有选项通过 `uci set openclash.@openclash[0].<option>=<value>` 设置

## 实现总览

插件设置页的选项通过以下路径生效：

```
 UCI 写入 → init.d start_service() → get_config() 读取所有 UCI 变量
                                            │
                    ┌───────────────────────┼───────────────────────┐
                    ▼                       ▼                       ▼
            yml_change.sh           set_firewall()          change_dnsmasq()
         (修改 YAML 配置)         (iptables/nftables)      (DNS 劫持转发)
                    │                       │                       │
                    ▼                       ▼                       ▼
              Mihomo 核心              系统防火墙规则            Dnsmasq → Clash DNS
```

| 脚本 | 输入 | 输出 | 负责的设置 |
|------|------|------|-----------|
| `yml_change.sh` | ~48 个 UCI 参数 | 修改运行 YAML | 端口、模式、DNS、TUN、Sniffer、认证、Meta、GEO、Smart |
| `yml_rules_change.sh` | UCI 覆写 + 自定义规则 | 修改运行 YAML | URL-Test 覆写、GitHub CDN、自定义规则注入、BT 直连规则 |
| `set_firewall()` | 所有流量控制 UCI | iptables/nftables 规则 | 透明代理、黑白名单访问控制、中国 IP 绕行、QUIC 阻断、UPNP 排除 |
| `change_dnsmasq()` | DNS 相关 UCI | dnsmasq 配置修改 | DNS 劫持转发、自定义域名 DNS、chnroute 旁路 |

### 插件强制覆盖/禁用的设置（用户不可修改）

> **重要**：以下设置由 `yml_change.sh` 在每次启动时**无条件硬编码**写入 YAML，用户在 LuCI 中**无法修改或关闭**。但可以通过覆写模块的 `[YAML]` 段和 `[Overwrite]` 段尝试覆盖，插件不保证覆写后的效果及工作逻辑正常。

| 强制设置 | 硬编码值 | 说明 |
|----------|----------|------|
| `allow-lan` | `true` | 始终允许局域网设备使用代理端口 |
| `bind-address` | `*` | 始终监听所有网络接口 |
| `external-controller` | `0.0.0.0:<cn_port>` | API 始终监听所有接口 (非仅 127.0.0.1) |
| `external-ui` | `/usr/share/openclash/ui` | Dashboard 路径不可更改 |
| `dns.listen` | `0.0.0.0:<dns_port>` | DNS 始终监听所有接口 |
| `profile.store-selected` | `true` | 始终保存策略组选择状态 |
| `sniffer.sniff` | HTTP:80,8080-8880 / TLS:443,8443 / QUIC:443 | 嗅探端口不可修改 |
| `sniffer.override-destination` | `true` | 始终用嗅探结果覆盖连接目标 |
| `sniffer.force-domain` | `netflix, nflxvideo, amazonaws, media.dssott.com` | 强制嗅探的流媒体域名 |
| `sniffer.skip-domain` | `Mijia Cloud, dlg.io.mi.com, +.oray.com, +.sunlogin.net, +.push.apple.com` | 跳过嗅探的智能家居/推送域名 |
| `sniffer.force-dns-mapping` | `true` (Redir-Host 时) | Redir-Host 模式下强制 DNS 映射嗅探 |
| `iptables` | **删除** | 强制移除 iptables 相关配置 |
| `ebpf` | **删除** | 强制移除 eBPF 相关配置 |
| `auto-redir` | **删除** | 强制移除 auto-redir（由 OpenClash 防火墙管理） |
| `routing-mark` | `6666` (非自定义标记时) | 固定路由标记值 |
| `external-controller-cors.allow-private-network` | `true` (有 CORS origin 时) | 允许私有网络访问 API |

**有条件默认设置**（仅在用户未配置时自动添加）：

| 设置 | 默认值 | 条件 |
|------|--------|------|
| `keep-alive-interval` | `15` | 仅当配置中未设置 |
| `keep-alive-idle` | `600` | 仅当配置中未设置 |
| `ntp.enable` | `true` | 仅当配置中未设置 |
| `ntp.server` | `time.apple.com` | 仅当配置中未设置 |
| `ntp.port` | `123` | 仅当配置中未设置 |
| `ntp.interval` | `30` (分钟) | 仅当配置中未设置 |
| `ntp.write-to-system` | `true` | 仅当配置中未设置 |

**防火墙固定值**（硬编码在 `init.d/openclash` 中）：

| 常量 | 值 | 说明 |
|------|-----|------|
| `PROXY_FWMARK` | `0x162` | 所有被代理流量的防火墙标记，不可修改 |
| `PROXY_ROUTE_TABLE` | `0x162` | 策略路由表 ID，不可修改 |
| `SKIP_GROUP` | `65534` | 绕过代理的组 ID (skgid) |

**内核模块依赖**（缺少时会导致启动报错）：

| 运行模式 | fw4 (nftables) 需要的 kmod | fw3 (iptables) 需要的 kmod |
|----------|---------------------------|---------------------------|
| Redir-Host / Fake-IP (非TUN) | `kmod-nft-tproxy` | `kmod-ipt-tproxy` |
| TUN 模式 | `kmod-tun` + `kmod-nft-tproxy` | `kmod-tun` + `kmod-ipt-tproxy` |
| 混合模式 (Mix) | `kmod-tun` + `kmod-nft-tproxy` | `kmod-tun` + `kmod-ipt-tproxy` |

> **故障排查**：如果启动日志提示 "nft_tproxy module not found"，请在 LuCI 的「系统 → 软件包」中搜索安装 `kmod-nft-tproxy`；提示 "xt_TPROXY module not found"，安装 `kmod-ipt-tproxy`。TUN 模式还需 `kmod-tun`（同样在 LuCI 软件包页面安装）。注意 fw4 环境下应检查 `nft_tproxy` 而非 `xt_TPROXY`。

## 2.1 模式设置标签页 (op_mode)

### en_mode — 选择运行模式 (Select Mode)
- **UCI 选项**: `openclash.@openclash[0].en_mode`
- **可选值**:
  - `redir-host` — 兼容模式 (Redir-Host)
  - `redir-host-tun` — 兼容模式 (TUN)
  - `redir-host-mix` — 兼容模式 (混合)
  - `fake-ip` — Fake-IP 模式
  - `fake-ip-tun` — Fake-IP (TUN)
  - `fake-ip-mix` — Fake-IP (混合)
- **Mihomo 对应配置**: `dns.enhanced-mode` (fake-ip / redir-host)
- **Redir-Host 模式**: DNS 解析在客户端完成，核心根据 IP 规则分流。适合 BT/PT 下载
- **Fake-IP 模式**: DNS 解析在核心完成，返回虚假 IP (198.18.x.x)，性能更高。规则基于域名匹配。**推荐作为日常使用首选**：Fake-IP（增强）模式下 TCP/UDP 均走系统协议栈，性能最优；若出现 NAT 问题可切换为 Fake-IP（混合）模式；若固件含 Docker 则直接选用 Fake-IP（TUN）模式
- **TUN 模式**: 创建虚拟网卡，以网络层接管所有流量。对应 Mihomo `tun.enable=true`。需要 `kmod-tun` 内核模块
- **混合模式**: TCP 使用 system 栈 (redirect)，UDP 使用 gvisor 栈 (TUN)。对应 Mihomo `tun.stack=mixed`。适合非直连游戏等对 NAT 类型有要求的场景

### stack_type — TUN 堆栈类型 (Stack Type)
- **UCI 选项**: `openclash.@openclash[0].stack_type`
- **可选值**: `system` / `gvisor` / `mixed`
- **Mihomo 对应配置**: `tun.stack`
- **system**: 使用 Linux 系统协议栈，性能和稳定性最好
- **gvisor**: 用户空间网络协议栈，隔离性更好，避免内核态/用户态切换
- **mixed**: TCP 用 system、UDP 用 gvisor
- **依赖**: 仅在 TUN/混合模式下显示

### proxy_mode — 代理模式 (Proxy Mode)
- **UCI 选项**: `openclash.@openclash[0].proxy_mode`
- **可选值**: `rule` / `global` / `direct`
- **Mihomo 对应配置**: `mode`
- **默认**: `rule`
- 此选项等同一键切换全局/规则/直连模式

### enable_udp_proxy — UDP 流量转发 (Proxy UDP Traffics)
- **UCI 选项**: `openclash.@openclash[0].enable_udp_proxy`
- **默认**: 1 (开启)
- **说明**: 节点需支持 UDP 转发。Docker 环境可能导致 UDP 异常
- **依赖**: 仅 Redir-Host 模式显示
- **注意**: Fake-IP 模式即使关闭此选项，域名类 UDP 连接仍会经过核心

### delay_start — 延迟启动（秒） (Delay Start)
- **UCI 选项**: `openclash.@openclash[0].delay_start`
- **默认**: 0 (不延迟)
- **说明**: 开机后延迟指定秒数再启动 OpenClash

### log_size — 日志大小（KB） (Log Size)
- **UCI 选项**: `openclash.@openclash[0].log_size`
- **默认**: 1024 (1MB)
- **说明**: 核心日志文件 `/tmp/openclash.log` 的最大大小

### bypass_gateway_compatible — 旁路网关（旁路由）兼容 (Bypass Gateway Compatible)
- **UCI 选项**: `openclash.@openclash[0].bypass_gateway_compatible`
- **默认**: 0 (关闭)
- **说明**: 旁路由 (旁路网关) 模式下无法上网时尝试开启。如果设备没有 WLAN，建议禁用 LAN 接口的桥接选项

### disable_quic_go_gso — 禁用 quic-go GSO (Disable QUIC Go GSO)
- **UCI 选项**: `openclash.@openclash[0].disable_quic_go_gso`
- **默认**: 0 (关闭)
- **说明**: Linux 内核 6.6 以上版本遇到 QUIC UDP 问题时尝试开启。**Hysteria / Hysteria2 / TUIC 等基于 QUIC 协议的节点出现连接超时、断流、握手失败时，优先尝试开启此选项**
- **Mihomo 对应配置**: `disable-quic-go-gso` (全局 experimental 选项，写入 YAML 的 `experimental.disable-quic-go-gso: true`)

### small_flash_memory — 小闪存模式 (Small Flash Memory)
- **UCI 选项**: `openclash.@openclash[0].small_flash_memory`
- **默认**: 0 (关闭)
- **说明**: 将核心和 GEOIP 数据文件移到 `/tmp/etc/openclash`，节省闪存空间。路由重启后需重新下载

> **AI 行为指引 — QUIC 类节点（Hysteria / Hysteria2 / TUIC）故障排查**: 当用户报告 Hysteria、Hysteria2、TUIC 等基于 QUIC 协议的节点无法连接、频繁断流或握手超时时，AI 应**优先建议**用户在「插件设置→模式设置」中开启「禁用 quic-go GSO (Disable QUIC Go GSO)」选项并重启 OpenClash。这是 Linux 内核 ≥6.6 上最常见的 QUIC 兼容性问题。
> 
> **关于 `disable_udp_quic`（禁用 QUIC）**：此选项**不会**影响 Mihomo 内核自身的 Hysteria/Hysteria2/TUIC 等 QUIC 出站连接，无需因使用此类节点而关闭该选项。原因：所有模式（TUN/非TUN）下 QUIC REJECT 规则均在 filter INPUT 链 + IPv6 TUN 模式下额外在 FORWARD -o utun 链，Mihomo 内核自身出站 QUIC 走 OUTPUT 链，回复包的目标端口为临时端口（非 443），均不命中拦截规则。`disable_udp_quic` 的目的是让 LAN 客户端的 YouTube 等 QUIC 流量降级到 TCP 以便代理，与内核节点通信无关。
> 
> 若 GSO 选项开启后问题仍存在，建议查阅 [Mihomo Wiki Hysteria 配置](https://wiki.metacubex.one/config/proxies/hysteria/) 或 [Hysteria2 配置](https://wiki.metacubex.one/config/proxies/hysteria2/) 验证节点字段是否正确。

### 运行模式切换按钮 (switch_mode)
- **模板**: `openclash/switch_mode`
- **功能**: 一键在 Redir-Host 和 Fake-IP 之间切换当前页面显示
- **触发**: `action_switch_mode` → 修改 UCI `operation_mode`

### 运行模式实现详解

**启动流程中的关键变量传递** (来自 `init.d start_service()`):
1. `get_config()` 读取 UCI `en_mode`，解析出 `en_mode_tun`（TUN 标记）、`en_mode_fakeip`（Fake-IP 标记）、`en_mode_mix`（混合标记）
2. 将这些传递给 `yml_change.sh` 作为位置参数：
   - `$1` = DNS enhanced-mode 值（`fake-ip` 或 `redir-host`）
   - `$11` = en_mode_tun（0/1/2，决定是否启用 TUN）
   - `$12` = stack_type 或 `$30`（TUN 堆栈类型回退）

**yml_change.sh 中 `en_mode` 的 YAML 影响链**:
- **dns.enhanced-mode**: 根据 Fake-IP / Redir-Host 设置 → 影响 Mihomo 的 DNS 解析策略：
  - `fake-ip`: 所有 DNS 查询返回 198.18.x.x 假 IP，规则基于域名匹配，性能最优
  - `redir-host`: DNS 在客户端完成，规则基于真实 IP 匹配，适合 BT/PT
- **tun.enable**: `en_mode_tun != 0` 时设为 `true` → Mihomo 创建 `utun` 虚拟网卡接管流量
- **tun.stack**: `system`(系统协议栈)/`gvisor`(用户态协议栈)/`mixed`(TCP system + UDP gvisor)
  - `system`: 性能最好，走 Linux 内核 TUN 驱动
  - `gvisor`: 隔离性好，UDP NAT 支持更完善
  - `mixed`: TCP 用 system 栈 (REDIRECT)，UDP 用 gvisor 栈 (TUN)

**防火墙层面的影响** (`set_firewall()`):
- **Redir-Host (非 TUN)**: TCP 通过 REDIRECT 到 `proxy_port`(7892)，UDP 通过 TPROXY 到 `tproxy_port`(7895)，标记 fwmark 0x162
- **Fake-IP (非 TUN)**: 同上 + 额外匹配 `fakeip_range`(198.18.0.1/16) 的路由
- **TUN 模式**: 所有流量标记 0x162，路由到 `utun` 设备（策略路由），TUN 内部处理分流
- **混合模式 (Mix)**: TUN 设备处理 UDP（走 gvisor），TCP 走 REDIRECT（system 栈）

---

## 2.2 流量控制标签页 (traffic_control)

> **生效路径**: 绝大多数流量控制选项不修改 YAML，而是影响 `set_firewall()` 生成的 iptables/nftables 规则链。
>
> **AI 行为指引**: 当用户询问流量路由问题时（如"TUN 和 TPROXY 有什么区别"、"如何让某设备不走代理"、
> "旁路由/网关模式下如何配置"、"IPv6 流量如何控制"），AI 应结合本章节的防火墙规则详解
> 和 [Mihomo 监听器文档](https://wiki.metacubex.one/config/listeners/) 回答，说明不同模式
> 的工作原理（而非仅给出操作步骤），帮助用户理解后做出选择。
> 涉及防火墙实现细节时，查阅 [OpenClash 源码](https://github.com/vernesong/OpenClash/tree/dev) 中
> `init.d/openclash` 和 `yml_change.sh` 的相关逻辑。
> `set_firewall()` 通过 UCI `firewall.openclash` 注册为 `/var/etc/openclash.include`，由 OpenWrt firewall3/firewall4 框架加载。
> 支持 fw4 (nftables) 和 fw3 (iptables) 双后端自动检测。
> **注意**：如需按接口/用户/DSCP 等维度精细绕过，请使用「插件设置页面底部 → 来源流量访问控制 (2.10)」。黑白名单设备级绕过使用「插件设置 → 黑白名单 (2.4)」。

### router_self_proxy — 路由本机代理 (Router-Self Proxy)
- **UCI 选项**: `openclash.@openclash[0].router_self_proxy`
- **默认**: 1 (开启)
- **说明**: 开启后，路由器本身发出的流量也会经过代理核心。仅在规则模式下生效。关闭后流媒体增强标签页所有功能将失效
- **实现细节**: 控制 OUTPUT 链规则是否生成。开启时创建 `openclash_output` 链（fw4）或 OUTPUT 规则（fw3），将路由器自身出站流量重定向到 Clash。关闭时删除 OUTPUT 链规则，路由器自身流量走原始路由表。

### disable_udp_quic — 禁用 QUIC (Disable QUIC)
- **UCI 选项**: `openclash.@openclash[0].disable_udp_quic`
- **默认**: 1 (开启)
- **效果**: 对 UDP 443 端口的流量执行 REJECT，阻止 YouTube 等使用 QUIC 协议传输 (降级到 TCP)
- **执行方式**: 通过 iptables/nftables 规则阻断 UDP 443，排除中国大陆 IP 段
- **实现细节**: 在 `set_firewall()` 的 `openclash_mangle` 链中插入规则：`meta l4proto udp th dport 443 counter reject`。但绕过 `china_ip_route_pass` ipset 中的中国 IP（通过 `ip daddr @china_ip_route_pass counter return`）。同时配合 dnsmasq 的 ipset/nftset 标记确保国内 QUIC 不受影响。

### skip_proxy_address — 绕过服务器地址 (Skip Proxy Address)
- **UCI 选项**: `openclash.@openclash[0].skip_proxy_address`
- **默认**: 0 (关闭)
- **说明**: 绕过配置中服务器地址的代理，防止重复代理 (代理嵌套)
- **实现细节**: 开启后看门狗脚本 `openclash_watchdog.sh` 中的 `skip_proxies_address()` 函数（每 30 个看门狗周期执行一次）解析 YAML 中所有代理节点（`proxies` 和 `proxy-providers`）的 `server` 地址，域名通过 `openclash_debug_dns.lua` 调用 Mihomo 内核 API（`/dns/query`）解析为 IP 后，加入已存在的 `localnetwork` nft set（或 ipset）。由于 `openclash` 链首条规则为 `ip daddr @localnetwork counter return`，这些代理服务器 IP 自动被跳过代理，防止代理嵌套。

### common_ports — 仅允许常用端口流量 (Common Ports Proxy Mode)
- **UCI 选项**: `openclash.@openclash[0].common_ports`
- **默认**: 0 (禁用)
- **说明**: 仅对常用端口 (HTTP/HTTPS/邮件等) 进行代理，防止 BT/P2P 流量经过代理
- **预设值**: `21 22 23 53 80 123 143 194 443 465 587 853 993 995 998 2052 2053 2082 2083 2086 2095 2096 5222 5228 5229 5230 8080 8443 8880 8888 8889`
- **自定义格式**: 空格分隔的端口号，如 `443 80` 或范围 `20-443`
- **依赖**: 仅 Redir-Host 系列模式
- **实现细节**: 非 0 时在 `openclash` redirect 链的端口检查规则中使用自定义端口列表（而非默认的允许所有端口）。格式 `{tcp, udp} th dport {80, 443, ...} counter redirect to proxy_port`。禁用时规则不含端口限制，所有 TCP 都重定向。

### china_ip_route — 实验性：绕过指定区域 IP (China IP Route)
- **UCI 选项**: `openclash.@openclash[0].china_ip_route`
- **可选值**:
  - `0` — 关闭
  - `1` — 绕过中国大陆 IP (将国内 IP 直连，提升性能)
  - `2` — 绕过海外 IP
- **说明**: 强烈推荐启用「绕过中国大陆」。启用后，会在 `fake-ip-filter` 添加 `rule-set:oc-cn-domain` 规则集 (旧版本为 GeoSite 数据库中分类为 `CN` 的域名)，且解析 IP 位于大陆 IP 段范围内的流量将不进入内核，显著降低内核性能开销。旁路由模式下如果遇到大陆域名无法访问可尝试开启"旁路由兼容"选项
- **Mihomo 对应**: 通过 `dns.fake-ip-filter` 添加 `rule-set:oc-cn-domain` 规则集，使中国大陆域名返回真实 IP 而非 Fake-IP；同时自动注册对应的 `rule-providers` 条目指向 MetaCubeX geosite CN MRS 文件
- **实现细节（双重机制）**: 1) **YAML 层面**: `yml_change.sh` 修改 `dns.fake-ip-filter`——blacklist 模式（默认）追加 `rule-set:oc-cn-domain`，whitelist 模式移除 CN 相关过滤器，rule 模式前置 `RULE-SET,oc-cn-domain,real-ip`。效果：匹配的中国大陆域名返回真实 IP，绕过 Fake-IP 机制。2) **防火墙层面**: `set_firewall()` 使用 chnroute IP 列表构建 nftables set（`china_ip_route` 或者 `china_ip6_route`），在 redirect/TPROXY 链中匹配国内真实 IP 直连 return。两层面互为补充——YAML fake-ip-filter 确保大陆域名获得真实 IP，防火墙 nft set 匹配这些真实 IP 使其跳过代理。

### intranet_allowed — 仅允许内网 (Only Intranet Allowed)
- **UCI 选项**: `openclash.@openclash[0].intranet_allowed`
- **默认**: 1 (开启)
- **说明**: 开启后控制面板和连接代理端口仅能从内网访问，不暴露到公网
- **Mihomo 对应**: `allow-lan: true` + `bind-address: "*"`
- **实现细节**: 双重保护——1) YAML 层面：`yml_change.sh` 设置 `allow-lan: true` + `bind-address: "*"` 使内核监听所有接口。2) 防火墙层面：创建 `openclash_wan_input` 链，匹配来自 WAN 口（非 `@localnetwork` 源 IP）的流量，REJECT 全部 7 个服务端口（`$proxy_port`/`$tproxy_port`/`$cn_port`/`$http_port`/`$socks_port`/`$mixed_port`/`$dns_port`）。关闭时 `allow-lan: false`，内核仅监听 `127.0.0.1`，同时不创建 `openclash_wan_input` 链。

### intranet_allowed_wan_name — WAN 接口名称 (WAN Interface Name)
- **UCI 选项**: `openclash.@openclash[0].intranet_allowed_wan_name`
- **说明**: 指定哪个接口被识别为 WAN。用于仅允许内网功能区分内外网
- **依赖**: `intranet_allowed=1`

### lan_interface_name — LAN 接口名称 (LAN Interface Name)
- **UCI 选项**: `openclash.@openclash[0].lan_interface_name`
- **可选值**: 系统中所有网络接口名
- **默认**: 0 (禁用)
- **说明**: 指定 LAN 接口名称，用于通过 `ip address show <接口>` 获取路由器 LAN IP 地址（供控制面板地址显示、API 调用、调试日志等使用）。设为 0 则自动检测

### local_network_pass — 本地 IPv4 网络绕过列表 (Local Network Pass)
- **UCI 选项**: `openclash.@openclash[0].local_network_pass`
- **存储文件**: `/etc/openclash/custom/openclash_custom_localnetwork_ipv4.list`
- **说明**: 目标地址为列表中 IP 的流量不经过核心

### chnroute_pass — 绕过指定区域 IPv4 黑名单 (Chnroute Bypassed List)
- **UCI 选项**: `openclash.@openclash[0].chnroute_pass`
- **存储文件**: `/etc/openclash/custom/openclash_custom_chnroute_pass.list`
- **说明**: 列表中的域名/IP 不受中国 IP 绕行选项影响，依赖 Dnsmasq。**默认已预置** `services.googleapis.cn`、`googleapis.cn`、`xn--ngstr-lra8j.com` 以解决 Google Play 下载问题
- **依赖**: `enable_redirect_dns != 2`
- **注意**: chnroute_pass 仅在 DNS 解析层面将域名解析 IP 加入 `china_ip_route_pass` nft set 使其跳过绕行规则，但若上游 DNS 本身将这些域名解析到国内 IP，加入 set 后仍会被 `china_ip_route` 规则误判为国内 IP 而绕行。**仅靠 chnroute_pass 不足以解决 Google Play 下载问题**——必须同时从 DNS 解析（`nameserver-policy` 强制走境外 DNS）和规则匹配（自定义规则走代理）两方面入手，详见错误速查表 §十四

### UPNP 流量排除（无 UCI 选项，自动生效）
- **触发条件**: 系统已安装并运行 `upnpd`（`/etc/config/upnpd` 存在且 `upnp_lease_file` 指向有效租约文件）
- **说明**: 自动读取 upnpd 租约文件，为 UPnP 端口映射创建防火墙绕过规则，防止 BT/PT 下载、游戏主机等 UDP UPnP 流量被 TPROXY 错误代理
- **实现细节**: 防火墙初始化阶段 `set_firewall()` 创建 `openclash_upnp` 链并在 `openclash_mangle` 链中通过 `jump openclash_upnp`（规则位置在最终 TPROXY 之前）。`upnp_exclude()` 函数读取 upnpd 租约文件（格式 `UDP:<ext_port>:<int_ip>:<int_port>`），为每条租约在 `openclash_upnp` 链中添加 `ip saddr <int_ip> <proto> sport <int_port> counter return` 规则。看门狗 `openclash_watchdog.sh` 每 30 个周期（首周期立即执行，之后每 `UPNP_INTERVAL=30` 即约 30 分钟）执行 UPNP 规则同步：① **清理过期规则**——遍历 `openclash_upnp` 链现有规则，删除租约文件中已不存在的条目；② **添加新规则**——读取租约文件，为新增的 UPnP 映射补充 RETURN 规则。

---

## 2.3 DNS 设置标签页 (dns)

> **生效路径**: DNS 选项通过三条路径生效：
> 1. `yml_change.sh` 修改 YAML `dns:` 段 → Mihomo 内核使用
> 2. `change_dnsmasq()` 修改系统 dnsmasq → LAN 客户端 DNS 被劫持到 Clash
> 3. `openclash_custom_domain_dns.sh` 为自定义域名配置独立 DNS
>
> **AI 行为指引**: 当用户询问 DNS 劫持相关问题时（如"DNS 重定向模式选哪个"、"自定义上游 DNS 服务器怎么写"、
> "Fake-IP 和 Redir-Host 的 DNS 行为有何不同"、"如何让特定域名不走 Fake-IP"），AI 应结合本文档的
> 「防火墙与 DNS 规则详解」章节和 [Mihomo DNS 配置文档](https://wiki.metacubex.one/config/dns/)
> 解释底层原理，然后告知用户在 LuCI 中的操作路径。
> 涉及 dnsmasq 劫持实现时可查阅 [OpenClash 源码](https://github.com/vernesong/OpenClash/tree/dev) 中
> `init.d/openclash` 的 `change_dnsmasq()` 函数。对于 DNS 劫持失败的排查，首先让用户检查
> 「运行状态」页面查看 DNS 端口是否在监听。

### enable_redirect_dns — 本地 DNS 劫持 (Redirect Local DNS Setting)
- **UCI 选项**: `openclash.@openclash[0].enable_redirect_dns`
- **可选值**:
  - `0` — 禁用
  - `1` — Dnsmasq 转发 (将 LAN 的 DNS 请求转发给核心)
  - `2` — 防火墙重定向 (通过 iptables/nftables 劫持 53 端口)
- **默认**: 1
- **说明**:
  - **Dnsmasq 转发** (值1): 修改 `/tmp/etc/dnsmasq.conf.*`，将上游 DNS 指向核心 DNS 端口 (`dns_port=7874`)
  - **防火墙重定向** (值2): 通过 iptables/nftables 将发往 53 端口的 UDP/TCP 流量 DNAT 到核心 DNS 端口。Fake-IP 模式下使用 LAN 访问控制必须选此项
- **Mihomo 对应**: DNS 监听配置 `dns.listen: 0.0.0.0:7874`
- **实现详解**:
  - **值1 (Dnsmasq)**: `change_dnsmasq()` 函数先备份 dnsmasq 原有配置到 `openclash.config.*`，然后设置 `dhcp.@dnsmasq[0].server=127.0.0.1#<dns_port>`，`noresolv=1`，`cachesize=0`。效果：所有 LAN 客户端的 DNS 查询 → dnsmasq → 转发到 Clash DNS (7874) → Clash 根据 `enhanced-mode` 处理。
  - **值2 (防火墙)**: 创建 `openclash_dns_redirect` nftables 链，对目标端口 53 的 UDP/TCP 流量 DNAT 到 `dns_port`。同时保留 dnsmasq 处理本地 DNS 缓存。此模式允许 `lan_ac_*` 访问控制（需要 Fake-IP 模式）。
  - **恢复**: `revert_dnsmasq()` 还原所有原始 dnsmasq 配置（servers、noresolv、resolvfile、cachesize）。

### flush_dns_cache — 清空 DNS 缓存按钮 (Flush DNS Cache)
- **模板**: `openclash/flush_dns_cache`
- **功能**: 通过 POST `/cache/fakeip/flush` + `/cache/dns/flush` API 清空 Fake-IP 和 DNS 缓存

### dnsmasq_fix — Dnsmasq 修复按钮 (Dnsmasq Fix)
- **功能**: 停止 OpenClash 后 DNS 异常时使用。恢复 Dnsmasq 默认配置:
  1. 设置 `noresolv=0`, `localuse=1`
  2. 恢复 `resolvfile` 为有效的 DNS 配置文件
  3. 若无有效配置则创建 `/tmp/resolv.conf.d/resolv.conf.auto` (114.114.114.114, 8.8.8.8)
  4. 重启 dnsmasq

### enable_custom_domain_dns_server — 启用第二 DNS 服务器 (Enable Specify DNS Server)
- **UCI 选项**: `openclash.@openclash[0].enable_custom_domain_dns_server`
- **默认**: 0
- **说明**: 为自定义域名列表指定专用 DNS 服务器，完全独立于内核 DNS 查询

### custom_domain_dns_server — 指定服务器 (Specify DNS Server)
- **UCI 选项**: `openclash.@openclash[0].custom_domain_dns_server`
- **默认**: `114.114.114.114`
- **格式**: `IP地址` 或 `IP地址#端口` (如 `127.0.0.1#5300`)

### custom_domain_dns — 自定义域名列表 (Custom Domain DNS)
- **存储文件**: `/etc/openclash/custom/openclash_custom_domain_dns.list`
- **格式**: 每行一个域名
- **说明**: 列表中的域名不返回 Fake-IP，使用指定的上游 DNS 服务器解析

---

## 2.4 黑白名单标签页 (Black&White / lan_ac)

> **生效路径**: 访问控制完全在防火墙层面实现，不修改 YAML。
>
> **AI 行为指引**: 当用户询问访问控制问题时（如"如何让某个设备不走代理"、"如何让内网某设备全局代理"、
> "代理黑名单和白名单的区别"），AI 应结合本章节的防火墙规则详解
> （特别是「各选项对防火墙规则的具体影响」表格）告知用户各选项组合的效果。
> 涉及黑白名单匹配逻辑时，查阅 [OpenClash 源码](https://github.com/vernesong/OpenClash/tree/dev) 中
> `init.d/openclash` 的 `firewall_lan_ac_traffic()` 函数和 `set_firewall()` 中的 `ipset`/`nft set` 创建逻辑。
> 对于 IP 段/CIDR 的写法问题，解释 `192.168.1.0/24` 等标准 CIDR 格式。
> **注意**：如需按接口/用户/DSCP 等维度精细绕过，请使用「插件设置页面底部 → 来源流量访问控制 (2.10)」。
> **依赖**: `enable_redirect_dns=2`（防火墙重定向模式）仅在 **Fake-IP 模式**下强制要求——因为 Fake-IP 返回虚拟 IP，客户端不知道真实目标，
> 必须通过防火墙重定向 DNS 才能实现基于真实目标的访问控制。Redir-Host 模式下此依赖为可选（LuCI UI 中同样要求，但底层机制不同）。

### lan_ac_mode — 局域网访问控制模式 (LAN Access Control Mode)
- **UCI 选项**: `openclash.@openclash[0].lan_ac_mode`
- **可选值**: `0` (黑名单模式) / `1` (白名单模式)
- **默认**: 0
- **说明**:
  - **黑名单模式**: 列表中的设备/主机不走代理 (直连)
  - **白名单模式**: 只有列表中的设备/主机走代理
- **依赖**: `enable_redirect_dns=2` (仅防火墙重定向模式) + Redir-Host 系列模式
- **实现细节**: 系统使用 `ebtables` 或 `nft` 在二层网桥层面匹配 MAC 地址，使用 `nftables` 在三层匹配 IP。黑白名单决定规则的 return 行为取反（黑名单=匹配到return直连，白名单=不匹配则return直连）。

### lan_ac_black_ips — 不走代理的局域网设备 IP (LAN Bypassed Host List)
- **UCI 选项**: `openclash.@openclash[0].lan_ac_black_ips` (DynamicList)
- **格式**: IP 地址或 CIDR 网段
- **依赖**: `lan_ac_mode=0`
- **实现细节**: 生成 nftables set `openclash_lan_black_ip` / `openclash_lan_black_ip6`，在 `openclash` redirect 链中插入 `ip saddr @openclash_lan_black_ip counter return` 跳过规则。

### lan_ac_black_macs — 不走代理的局域网设备 Mac (LAN Bypassed Mac List)
- **UCI 选项**: `openclash.@openclash[0].lan_ac_black_macs` (DynamicList)
- **格式**: MAC 地址
- **实现细节**: 通过 `ebtables`（fw3）或 `nft add rule bridge`（fw4）在 br-lan 网桥上匹配源 MAC，匹配到的流量不进入 Clash 代理链。

### lan_ac_white_ips — 走代理的局域网设备 IP (LAN Proxied Host List)
- **UCI 选项**: `openclash.@openclash[0].lan_ac_white_ips`
- **依赖**: `lan_ac_mode=1`

### lan_ac_white_macs — 走代理的局域网设备 Mac (LAN Proxied Mac List)
- **UCI 选项**: `openclash.@openclash[0].lan_ac_white_macs`

### wan_ac_black_ips — 不走代理的 WAN IP (WAN Bypassed Host List)
- **UCI 选项**: `openclash.@openclash[0].wan_ac_black_ips`
- **说明**: Fake-IP 模式下仅支持纯 IP 请求，域名请求需先设置 Fake-IP-Filter

### wan_ac_black_ports — 不走代理的 WAN 端口 (WAN Bypassed Port List)
- **UCI 选项**: `openclash.@openclash[0].wan_ac_black_ports`
- **格式**: 端口号或端口范围

---

## 2.5 流媒体增强标签页 (stream_enhance)

> **生效路径**: `openclash_streaming_unlock.lua` 脚本在核心启动后被守护进程调用，
> 定期测试各流媒体服务的解锁情况，自动将策略组切换到支持该服务的节点。
>
> **AI 行为指引**: 当用户询问流媒体相关问题时（如"如何解锁 Netflix/Disney+"、"Bilibili 地区选项代表什么"、
> "如何添加新的流媒体服务"、"Group Filter 正则怎么写"），AI 应查阅 [Mihomo 规则文档](https://wiki.metacubex.one/config/rules/)
> 了解 GEOSITE/RULE-SET 等规则类型，并结合 OpenClash 的流媒体增强设置告知用户具体配置步骤。
> 涉及流媒体解锁检测逻辑时，查阅 [OpenClash 源码](https://github.com/vernesong/OpenClash/tree/dev) 中
> `openclash_streaming_unlock.lua` 脚本。
> 注意：`openclash_streaming_unlock.lua` 仅负责已配置服务的节点测试和自动切换，不负责 Smart 策略。

所有子选项依赖 `stream_auto_select=1`。每个流媒体服务有一组独立配置：

| 服务 | 启用 UCI | 默认 | 说明 |
|------|----------|------|------|
| Netflix | `stream_auto_select_netflix` | 0 | 启用后自动选择支持 Netflix 的节点 |
| Disney Plus | `stream_auto_select_disney_plus` | 0 | |
| HBO Max | `stream_auto_select_hbo_max` | 0 | |
| YouTube | `stream_auto_select_youtube` | 0 | |
| Prime Video | `stream_auto_select_prime_video` | 0 | |
| Paramount Plus | `stream_auto_select_paramount_plus` | 0 | |
| Discovery Plus | `stream_auto_select_discovery_plus` | 0 | |
| Bilibili | `stream_auto_select_bilibili` | 0 | 解锁地区选项：CN(仅大陆)/HK/MO/TW/TW(仅台湾) |
| Google Not CN | `stream_auto_select_google_not_cn` | 0 | 自动选择非中国 Google 节点 |
| OpenAI | `stream_auto_select_openai` | 0 | |
| Claude | `stream_auto_select_claude` | 0 | |
| Gemini | `stream_auto_select_gemini` | 0 | |

每个服务配置项：
- **策略组筛选 (Group Filter)**: `stream_auto_select_group_key_<service>` — 匹配策略组的正则表达式
- **解锁区域筛选 (Unlock Region Filter)**: `stream_auto_select_region_key_<service>` — 解锁地区国家缩写
- **解锁节点筛选 (Unlock Nodes Filter)**: `stream_auto_select_node_key_<service>` — 节点名称正则过滤
- **手动测试按钮**: 调用 `openclash_streaming_unlock.lua` 执行解锁测试
- **实现详解**: `openclash_streaming_unlock.lua` 是一个独立 Lua 脚本，被 `/etc/init.d/openclash` 以 `procd` 服务形式启动（与核心并列）。工作流程：
  1. 读取 YAML 中所有策略组和节点，构建节点-策略组映射
  2. 对每个启用的流媒体服务，尝试用各节点连接服务域名（如 `netflix.com`）
  3. 检查 HTTP 响应码或页面内容判断是否解锁（如 Netflix 返回 200 且不含地区限制页面则解锁）
  4. 找到能解锁的节点后，通过 Mihomo API `PUT /proxies/{group}` 自动切换策略组到该节点
  5. 定期重新测试（间隔可配置），节点失效时自动切换

---

## 2.6 外部控制标签页 (Dashboard Settings / dashboard)

> **生效路径**: 仪表盘选项写入 YAML 的 `external-controller`、`secret`、`external-ui` 等字段，
> 由 Mihomo 内核直接读取并提供 HTTP API。下载/切换通过 `openclash_download_dashboard.sh` 执行。

| 选项 | UCI Key | 默认 | 说明 |
|------|---------|------|------|
| 管理页面端口 (Dashboard Port) | `cn_port` | 9090 | 对应 Mihomo `external-controller: 0.0.0.0:9090` |
| 管理页面登录密钥 (Dashboard Secret) | `dashboard_password` | 空 | 对应 Mihomo `secret`，留空则不验证 |
| 管理页面公网域名 (Public Dashboard Address) | `dashboard_forward_domain` | 空 | 用于公网访问面板 |
| 管理页面映射端口 (Public Dashboard Port) | `dashboard_forward_port` | 空 | |
| 管理页面公网 SSL 访问 (Public Dashboard SSL enabled) | `dashboard_forward_ssl` | 0 | |

仪表盘版本管理通过 `action_switch_dashboard` → `openclash_download_dashboard.sh` 自动下载切换。
- **实现细节**: `yml_change.sh` 将 `cn_port`、`dashboard_password` 写入 YAML → Mihomo 内核启动 HTTP API。`openclash_download_dashboard.sh` 从 GitHub Releases 下载 Dashboard 静态文件 (yacd/metacubexd/zashboard)，解压到 `/usr/share/openclash/ui`。前端 `status.htm` 中的 JS 根据以下逻辑构造仪表盘 URL：1) 若当前浏览器 hostname 与路由器 LAN IP 相同 → `http://<lan_ip>:<cn_port>/ui/<dashboard>/`；2) 若设置了 `dashboard_forward_domain` + `dashboard_forward_port`（公网访问）→ 协议由 `dashboard_forward_ssl` 决定（0=http, 1=https），地址为 `<protocol>://<domain>:<port>/ui/<dashboard>/`；3) 其他情况 → 取当前页面协议 + LAN IP + cn_port。四个仪表盘的子路径分别为 `/ui/dashboard/`、`/ui/yacd/`、`/ui/metacubexd/`、`/ui/zashboard/`。

---

## 2.7 IPv6 设置标签页 (ipv6)

> **注意：** 不建议为路由器开启 IPv6 及相关服务。IPv6 方案仅适用于**主路由拨号环境**（需运营商支持 IPv6-PD 前缀下发），旁路由环境不适用
> **生效路径**: IPv6 选项通过 `yml_change.sh` 写入 YAML（`ipv6`、`dns.ipv6`、`dns.fake-ip-range6`），
> 同时 `set_firewall()` 生成独立的 IPv6 防火墙规则链（`openclash_v6`、`openclash_mangle_v6` 等）。
> IPv6 使用单独的 TProxy/Redirect/TUN 规则链，与 IPv4 互不影响。
>
> **IPv6 DNS 核心最佳实践**：DNS 解析请求（包括 AAAA 记录查询）可以通过 IPv4 链路发送，无需 IPv6 DNS 服务器。推荐策略：① LAN 接口 DHCP 服务器中**不分配 IPv6 DNS**，强制设备用路由器 IPv4 地址做 DNS 解析；② 取消 `过滤 IPv6 AAAA 记录`（Dnsmasq 高级设置）；③ 开启 OpenClash 的「允许 IPv6 类型 DNS 解析」选项。效果：DNS 走 IPv4 通道查询（经过 OpenClash 分流），流量走 IPv6 通道传输——既防止 IPv6 DNS 抢答导致的泄露，又保证 IPv6 站点可访问

| 选项 | UCI Key | 默认 | 说明 |
|------|---------|------|------|
| IPv6 代理 (Proxy IPv6 Traffic) | `ipv6_enable` | 0 | 开启 IPv6 流量代理。网关和 DNS 须为路由器 IP |
| IPv6 代理模式 (IPv6 Proxy Mode) | `ipv6_mode` | TProxy(0) | TProxy/Redirect/TUN/Mix |
| IPv6 堆栈类型 (Select Stack Type) | `stack_type_v6` | system | system/gvisor/mixed。仅 TUN/Mix 模式 |
| IPv6 UDP 代理 (Proxy UDP Traffics) | `enable_v6_udp_proxy` | 1 | 仅 TProxy/Redirect 模式 |
| 允许 IPv6 类型 DNS 解析 (IPv6 DNS Resolve) | `ipv6_dns` | 0 | 对应 Mihomo `dns.ipv6` — 控制 Clash DNS 是否返回 AAAA 记录 |
| IPv6 Fake-IP 范围 (Fake-IP Range) | `fakeip_range6` | 禁用 | 仅 Fake-IP 模式。对应 `dns.fake-ip-range6` |
| 实验性：绕过指定区域 IPv6 (China IPv6 Route) | `china_ip6_route` | 0 | 0=关闭, 1=绕过大陆, 2=绕过海外 |
| 本地 IPv6 绕过地址 (Local IPv6 Network Bypassed List) | `local_network6_pass` | — | 文件: `/etc/openclash/custom/openclash_custom_localnetwork_ipv6.list` |
| 绕过指定区域 IPv6 黑名单 (Chnroute6 Bypassed List) | `chnroute6_pass` | — | 文件: `/etc/openclash/custom/openclash_custom_chnroute6_pass.list`。将列表中域名/IP 加入 `china_ip6_route_pass` nft set，不受 IPv6 绕行选项影响。依赖: `ipv6_enable=1` + `enable_redirect_dns=1` |

---

#### 2.8 GEO 数据库订阅 / 大陆白名单订阅标签页

### GEO 数据库订阅 (GEO Update / geo_update)

| 数据类型 | 启用 UCI | 更新脚本 | 更新星期 UCI | 更新时间 UCI | 自定义 URL UCI |
|----------|----------|----------|-------------|-------------|---------------|
| 自动更新 GeoIP MMDB 数据库 (Auto Update GeoIP MMDB) | `geo_auto_update` | `openclash_geo.sh ipdb` | `geo_update_week_time` | `geo_update_day_time` | `geo_custom_url` |
| 自动更新 GeoIP Dat 数据库 (Auto Update GeoIP Dat) | `geoip_auto_update` | `openclash_geo.sh geoip` | `geoip_update_week_time` | `geoip_update_day_time` | `geoip_custom_url` |
| 自动更新 GeoSite 数据库 (Auto Update GeoSite) | `geosite_auto_update` | `openclash_geo.sh geosite` | `geosite_update_week_time` | `geosite_update_day_time` | `geosite_custom_url` |
| 自动更新 Geo ASN 数据库 (Auto Update Geo ASN) | `geoasn_auto_update` | `openclash_geo.sh geoasn` | `geoasn_update_week_time` | `geoasn_update_day_time` | `geoasn_custom_url` |

**共享配置项**：`*_update_week_time` (周几): `*`=每天, `1`=周一, `2`=周二, …, `0`=周日; `*_update_day_time` (小时): `0`-`23`; `*_custom_url` (自定义下载地址，留空使用默认)

**Mihomo 对应**: `geox-url` 中的各字段 + `geo-auto-update` + `geo-update-interval`
- **实现细节**: 
  - **Cron 触发**: `add_cron()` 在 `openclash_geo.sh` 中为每种 GEO 类型注册 cron 任务
  - **下载流程**: `openclash_geo.sh` 使用自定义 URL（`*_custom_url`）或默认地址下载，保存到 `/etc/openclash/` 目录
  - **Mihomo 使用**: MMDB 用于 `GEOIP` 规则匹配（IP→国家），Dat 用于 `GEOSITE` 规则匹配（域名→类别），ASN 用于 Smart 策略
  - **运行时热加载**: GEO 文件更新后 Mihomo 自动重新加载（`geo-auto-update: true` + `geo-update-interval`），无需重启

### 大陆白名单订阅 (Chnroute Update / chnr_update)

| 选项 | UCI Key | 默认 | 说明 |
|------|---------|------|------|
| 自动更新 (Auto Update) | `chnr_auto_update` | 0 | 启用定时更新大陆 IP 路由表 |
| 更新时间/每周 (Update Time (Every Week)) | `chnr_update_week_time` | `1`(周一) | `*`=每天, `1`=周一, …, `0`=周日 |
| 更新时间/每天 (Update time (every day)) | `chnr_update_day_time` | `0`(0:00) | `0`-`23`，每小时一个选项 |
| 大陆 IP 段更新 URL (Custom Chnroute Lists URL) | `chnr_custom_url` | `https://ispip.clang.cn/all_cn.txt` | 中国 IPv4 CIDR 列表下载地址 |
| 大陆 IPv6 段更新 URL (Custom Chnroute6 Lists URL) | `chnr6_custom_url` | `https://ispip.clang.cn/all_cn_ipv6.txt` | 中国 IPv6 CIDR 列表下载地址 |

**更新脚本**: `openclash_chnroute.sh`

---

## 2.9 其他标签页

### 定时重启 (Auto Restart / auto_restart)

此标签页用于设置 OpenClash 定时自动重启。

| 选项 | UCI Key | 类型 | 默认 | 说明 |
|------|---------|------|------|------|
| **定时重启 (Auto Restart)** | `auto_restart` | Flag | 0 | `0`=关闭, `1`=开启。开启后将在指定时间自动重启 OpenClash 服务 |
| **重启时间/每周 (Restart Time (Every Week))** | `auto_restart_week_time` | ListValue | `1`(周一) | `*`=每天 (Every Day), `1`=周一 (Every Monday), `2`=周二 (Every Tuesday), `3`=周三 (Every Wednesday), `4`=周四 (Every Thursday), `5`=周五 (Every Friday), `6`=周六 (Every Saturday), `0`=周日 (Every Sunday) |
| **重启时间/每天 (Restart time (every day))** | `auto_restart_day_time` | ListValue | `0`(0:00) | `0`-`23`，每小时一个选项 |

- **实现细节**: `add_cron()` 在 `/etc/crontabs/root` 中添加 `/etc/init.d/openclash restart` 的 cron 条目，按用户选择的时间和星期执行。

### 版本更新 (Version Update / version_update)

此标签页使用自定义模板，提供核心/插件版本选择和更新操作。

**页面要素（页面加载时通过 `/update_info` 和 `/get_last_version` API 动态填充）**:

| 要素 | 显示内容 | 说明 |
|------|---------|------|
| **处理器架构 (CPU Architecture)** | 当前设备 CPU 架构 | 自动检测，只读显示 |
| **上次检查更新时间 (Last Check Update)** | 上次检查更新的时间 | 自动显示 |
| **当前内核版本 ([Meta] Current Core)** | 当前 Meta 核心版本 | 执行 `clash_meta -v` 获取 |
| **最新内核版本 ([Meta] Latest Core)** | 远程最新 Meta 核心版本 | 每 300 秒通过 `/get_last_version` 轮询刷新 |
| **当前客户端版本 (Current Client)** | 当前插件版本 | 从 opkg/apk 数据库读取 |
| **最新客户端版本 (Latest Client)** | 远程最新插件版本 | 同上轮询 |

**版本选择（UCI 持久化）**:

| 选项 | UCI Key | 类型 | 默认 | 说明 |
|------|---------|------|------|------|
| **编译版本 (Compiled Version)** | `core_version` | Select | `0`(未设置 (Not Set)) | 选择与 CPU 匹配的编译版本：`linux-amd64-v1/v2/v3`(x86-64)、`linux-arm64`(armv8)、`linux-armv7`、`linux-mips64` 等 ~18 种架构 |
| **更新分支 (Release Branch)** | `release_branch` | Select | `master` | `master`(稳定版) / `dev`(开发版) |
| **Smart 内核 (Smart Core)** | `smart_enable` | Select | `0` | `0`=禁用(使用 Meta 内核) / `1`=启用(使用 Smart 内核) |

**操作按钮**（点击时先保存上述选择到 UCI，再触发对应脚本）:

| 按钮 | 触发脚本 | 功能 |
|------|----------|------|
| **更新内核 (Update Core)** → Check And Update (检查并更新) | `openclash_core.sh` | 检查并更新 Meta/Smart 核心到最新版 |
| **下载最新版本内核 (Download Latest Core)** | `openclash_core.sh` | 手动下载指定版本的核心（根据架构/分支/Smart选择） |
| **更新客户端 (Update Client)** → Check And Update (检查并更新) | `openclash_update.sh` | 检查并更新 luci-app-openclash 插件版本 |
| **下载最新版本客户端 (Download Latest Client)** | `openclash_update.sh` | 手动下载最新客户端 .ipk/.apk |
| **备份 (Backup)** | 前端打包下载 | 备份配置文件（可选择备份范围：完整/排除核心/仅核心/仅配置/仅规则提供者/仅代理提供者） |
| **还原默认 (Restore Default)** | 清除 UCI 配置 | 恢复 OpenClash 为默认出厂配置 |
| **删除内核 (Remove Core)** | 删除文件 | 删除所有核心二进制文件 |
| **检查更新 (Check Update)** | 在线检查 | 一键检查更新（走 CDN 加速） |

- **实现细节**: 所有更新按钮在触发对应脚本前，都会先通过 `/save_corever_branch` API 保存当前选择的架构、分支和 Smart 启用状态。核心更新通过 `openclash_core.sh` 从 GitHub Releases 下载对应架构的 `.tar.gz` 并替换 `/etc/openclash/core/clash_meta`。插件更新通过 `openclash_update.sh` 下载 .ipk/.apk 并通过 ubus 后台安装以避免 Web 界面断连。

### 开发者选项 (Developer Settings / developer)
- **自定义防火墙规则** (`firewall_custom`): 在 LuCI 的「开发者设置」标签页中直接编辑的文本框，内容保存到 `/etc/openclash/custom/openclash_custom_firewall_rules.sh`。该脚本**不需要定义任何函数**——它是一个命令式 Shell 脚本，在所有 OpenClash 内置防火墙规则添加完毕后被直接执行（`chmod +x` 后运行）。可以在脚本中直接写 `iptables -I ...` 或 `nft add rule ...` 命令来追加自定义防火墙规则。
- **实现细节**: `set_firewall()` 函数在所有内置的 REDIRECT/TPROXY/TUN/IPv6/访问控制规则建立完毕后，检查此文件是否存在，若存在则 `chmod +x` 并执行。由于它在所有内置规则之后运行，自定义规则可以引用 OpenClash 已创建的 nftables 链和 set。每次 OpenClash 启动或防火墙重载时都会重新执行此脚本。

### 内核测试 (Core Test / debug)

此标签页提供二种独立的诊断工具，位于「内核测试」标签页：

| 工具 | 功能 | 触发方式 | 后端路由 |
|------|------|---------|----------|
| **连接测试 (Connection Test)** | 测试指定域名是否可达 | 输入域名 + 点击「Click to Test」(点击测试) 按钮 | `/diag_connection` |
| **DNS 测试 (DNS Test)** | 测试 DNS 解析结果 | 输入域名 + 点击「Click to Test」(点击测试) 按钮 | `/diag_dns` |

**连接测试实现细节**: 前端先尝试 `Image` 加载 `https://{domain}/favicon.ico` 作为快速预检，若失败则回退到后端 `/diag_connection` 调用。

### oixCloud (oixcloud)
- 第三方云服务，需账号密码登录
- `oix_email` / `oix_passwd` → `oix_login` 获取 token
- `oix_checkin` — 自动签到 (需 token)
- 登录后自动获取 Oix 专属核心和订阅

---

## 2.10 来源流量访问控制 (Source Traffic Bypass / lan_ac_traffic)

> **页面位置**：插件设置页面底部（不属于任何标签页，以独立的 TypedSection 形式存在）
> **生效路径**：通过 `init.d/openclash` 的 `firewall_lan_ac_traffic()` 函数在代理链 **position 0** 插入规则，
> 优先级高于所有其他代理规则。配置通过 `config_foreach firewall_lan_ac_traffic "lan_ac_traffic"` 遍历执行。
>
> **AI 行为指引**：当用户询问「如何让某个接口（如 WireGuard/Docker 网桥）的流量完全绕过内核」、
> 「如何按用户 UID 绕过代理」、「如何精细控制特定来源流量」时，AI 应告知用户使用此功能，
> 并结合下方字段表和防火墙逻辑给出具体配置方案。涉及底层实现时查阅
> [OpenClash 源码](https://github.com/vernesong/OpenClash/tree/dev) 中
> `init.d/openclash` 的 `firewall_lan_ac_traffic()` 函数。

### lan_ac_traffic TypedSection

支持按七维度组合匹配流量，匹配后执行 target 动作：

| 字段 | UCI Key | 类型 | 说明 |
|------|---------|------|------|
| 备注 | `comment` | Value | 规则说明 |
| 启用 | `enabled` | Flag | 默认 1 |
| 内部地址 | `src_ip` | Value | IP/CIDR/`localnetwork`（匹配本地网络地址集 @localnetwork） |
| 内部端口 | `src_port` | Value | 端口或范围，如 `5000` 或 `1234-2345` |
| 协议 | `proto` | ListValue | `both`(默认)/`tcp`/`udp` |
| 地址族 | `family` | ListValue | `both`(默认)/`ipv4`/`ipv6` |
| 接口 | `interface` | ListValue | 网络接口名（如 `eth1`、`wg0`、`docker0`），匹配从该接口进入的流量 |
| 用户 | `user` | ListValue | Linux UID，匹配该用户进程发出的流量（仅 OUTPUT 链生效） |
| DSCP | `dscp` | Value | 0-63，匹配 IP 头 DSCP 标记值 |
| 目标 | `target` | ListValue | `RETURN`(默认，跳过代理走直连) / `ACCEPT`(放行) / `DROP`(静默丢弃) |

### 防火墙工作逻辑（基于 `init.d/openclash` → `firewall_lan_ac_traffic()` 源码）

**规则生成流程**：

```
config_foreach firewall_lan_ac_traffic "lan_ac_traffic"
  → 读取每个启用的 section 的 UCI 字段
  → 构建 nftables/iptables 匹配条件
  → 按运行模式 + 协议 + 地址族插入对应链的 position 0
```

**fw4 (nftables) 规则插入的目标链**（按运行模式区分）：

| 运行模式 | TCP 进入 | TCP 发出 | UDP 进入 | UDP 发出 | 旁路由 SNAT |
|----------|----------|----------|----------|----------|-------------|
| 非 TUN（redir-host/fake-ip） | `openclash` | `openclash_output` | `openclash_mangle` | `openclash_mangle_output` | `openclash_post` |
| TUN 模式 | `openclash_mangle` | `openclash_mangle_output` | `openclash_mangle` | `openclash_mangle_output` | `openclash_post` |
| IPv6（ipv6_enable=1） | `openclash_v6` | `openclash_output_v6` | `openclash_mangle_v6` | `openclash_mangle_output_v6` | `openclash_post_v6` |

**关键匹配逻辑**：

- **`src_ip=localnetwork`**：特殊值，nftables 端展开为 `ip saddr @localnetwork`（匹配整个本地网络地址集），iptables 端使用 `-m set --match-set localnetwork src`
- **接口匹配**：nftables 用 `iifname "接口名"`，iptables 用 `-i 接口名`
- **用户匹配**：nftables 用 `meta skuid UID`（仅 OUTPUT 链生效），iptables 用 `-m owner --uid-owner UID`
- **DSCP 匹配**：nftables 用 `ip dscp 值`，iptables 需 `dscp` 模块（不可用时跳过并输出警告：`iptables DSCP module not available`）
- **Fake-IP 排除**：所有规则自动排除 Fake-IP 地址段 `ip daddr != {198.18.0.0/16}`，避免影响 Fake-IP 内部映射
- **drop→return 转换**：当 `target=DROP` 时，nftables 实际动作为 `return`（因 mangle 链不支持 drop），iptables 保持 `DROP`

**常见场景示例**：

| 需求 | 规则配置 |
|------|----------|
| 某接口（如 WireGuard）流量不走代理 | `interface=wg0`, `target=RETURN` |
| Docker 网桥流量绕过内核 | `interface=docker0`, `target=RETURN` |
| 某设备所有流量不走代理 | `src_ip=192.168.1.100/32`, `target=RETURN` |
| 某端口范围的 TCP 流量不走代理（BT 端口） | `src_port=6881-6889`, `proto=tcp`, `target=RETURN` |
| 某用户进程流量完全丢弃 | `user=65534`, `target=DROP` |
| 本地网络所有 UDP 流量直连 | `src_ip=localnetwork`, `proto=udp`, `target=RETURN` |

---

# 第三部分：覆写设置页面 (Overwrite Settings / config-overwrite)

> UCI Section: `openclash.config_overwrite`
> 此页面用于覆写订阅配置中的特定字段，设置后通过 openclash.sh 脚本注入到生成的 YAML 中

## 实现总览

```
 UCI config_overwrite 写入
        │
        ▼
 yml_change.sh (优先级最高)         yml_rules_change.sh
 ├─ 端口、模式、DNS、TUN            ├─ tolerance / url-test 覆写
 ├─ Sniffer、认证、Meta             ├─ GitHub CDN 替换
 ├─ GEO、Smart、NTP                 ├─ enable_rule_proxy → BT/P2P 直连
 └─ 自定义 DNS servers              └─ 自定义规则注入
```

**关键机制**: `yml_change.sh` 以 YAML 深度合并 + 覆盖的方式修改配置，覆写优先级高于订阅原始值。
`yml_rules_change.sh` 使用 Ruby YAML 库操作策略组、规则、URL-Test 参数和规则提供者地址。
两个脚本在 `start_service()` 流程中先于核心启动执行。

## 3.1 常规设置标签页 (General Settings / settings)

### interface_name — 绑定网络接口 (Bind Network Interface)
- **UCI**: `openclash.@config_overwrite[0].interface_name`
- **默认**: 0 (禁用)
- **说明**: 绑定核心出站流量到指定网络接口
- **Mihomo 对应**: `interface-name`
- **实现细节**: `yml_change.sh` 将值写入 YAML `interface-name`。Mihomo 内核所有出站连接（代理节点连接、DNS 查询、GEO 下载）都通过此接口发送。用于多 WAN 环境指定出口。

### tolerance — URL-Test 策略组切换灵敏度 (URL-Test Group Tolerance)
- **UCI**: `openclash.@config_overwrite[0].tolerance`
- **默认**: 0 (禁用)
- **说明**: 当前代理与新最快代理的延迟差值大于此值时自动切换。0 表示关闭
- **Mihomo 对应**: proxy-groups 中 url-test 类型的 `tolerance` 字段
- **实现细节**: `yml_rules_change.sh` 遍历所有 `type: url-test` 的策略组，设置其 `tolerance` 值。Mihomo 内核定期测试组内所有节点延迟，当当前选中节点的延迟与新最快节点的延迟差 > tolerance 时自动切换。设为 0 则每次测试都切换到最快节点。

### urltest_address_mod — 测速（连通性）地址修改 (URL-Test Address Modify)
- **UCI**: `openclash.@config_overwrite[0].urltest_address_mod`
- **默认**: 0 (禁用)
- **预设**: `http://www.gstatic.com/generate_204` / `http://cp.cloudflare.com/` / `https://cp.cloudflare.com/` / `http://captive.apple.com/`
- **Mihomo 对应**: proxy-groups 中 url-test 类型的 `url` 字段
- **实现细节**: `yml_rules_change.sh` 替换所有 url-test 策略组的测试 URL。Mihomo 内核周期性向此 URL 发送 HTTP HEAD/GET 请求测量延迟，作为节点选择的依据。

### github_address_mod — Github 地址修改 (Github Address Modify)
- **UCI**: `openclash.@config_overwrite[0].github_address_mod`
- **说明**: 通过代理/CDN 加速 GitHub 文件下载。**强烈推荐在 OpenClash 启动前就设置好此项**，因为插件和内核更新、GEO 数据库下载、Dashboard 下载均依赖 GitHub 连通性。推荐优先尝试 `https://testingcf.jsdelivr.net/`（jsDelivr 的 Cloudflare CDN），如不可用再切换其他 CDN
- **预设**: 多个 jsdelivr CDN 地址（testingcf / fastly 等）
- **实现细节**: `yml_rules_change.sh` 用 Ruby 正则 `/raw\.githubusercontent\.com/` 匹配所有 rule-providers 和 proxy-providers 的 `url` 字段，将域名替换为 CDN 地址。解决中国大陆无法访问 GitHub 的问题。
- **已知限制**: `github_address_mod` 仅对 rule-providers 和 proxy-providers 的 URL 生效。`openclash_download_dashboard.sh`（Dashboard 下载）和 `openclash_geo.sh`（GEO 更新）**不使用此变量**，这些脚本的下载 URL 为硬编码的 GitHub 直连地址。如需对 Dashboard/GEO 下载使用 CDN，可通过覆写模块的 `[General]` 段设置 `DOWNLOAD_FILE` 或使用自定义规则使相关域名直连。

### log_level — 日志等级 (Log Level)
- **UCI**: `openclash.@config_overwrite[0].log_level`
- **可选值**: `0`(禁用) / `info` / `warning` / `error` / `debug` / `silent`
- **Mihomo 对应**: `log-level`
- 0 表示不覆写，使用订阅原有设置
- **实现细节**: `yml_change.sh` 将值写入 YAML `log-level`。Mihomo 内核根据级别过滤日志输出：`silent`(无输出) → `error`(仅错误) → `warning`(+警告) → `info`(+一般信息) → `debug`(+调试详情)。

### 端口设置
| 端口用途 | UCI Key | 默认 | Mihomo 对应 |
|----------|---------|------|-------------|
| **DNS 端口 (DNS Port)** | `dns_port` | 7874 | `dns.listen` |
| **流量转发端口 (Redir Port)** | `proxy_port` | 7892 | `listeners.redirect` (仅 TCP) |
| **TProxy 端口 (TProxy Port)** | `tproxy_port` | 7895 | `listeners.tproxy` (TCP+UDP) |
| **HTTP(S) 代理端口 (HTTP(S) Port)** | `http_port` | 7890 | `listeners.http` |
| **SOCKS5 代理端口 (SOCKS5 Port)** | `socks_port` | 7891 | `listeners.socks` |
| **HTTP(S)&SOCKS5 混合代理端口 (Mixed Port)** | `mixed_port` | 7893 | `listeners.mixed` (HTTP+SOCKS) |

- **端口实现细节**: `yml_change.sh` 将所有端口写入 YAML 对应字段。Mihomo 内核启动时在这些端口上创建监听器，接受来自 iptables/nftables 重定向的流量或客户端直连的代理请求。修改后需重启核心。

## 3.2 DNS 设置标签页 (DNS Settings / dns)

> **生效路径**: DNS 覆写通过 `yml_change.sh` 的 `yml_dns_custom()` 函数处理，
> 构建完整的 `dns:` YAML 段并合并到运行配置。
>
> **AI 行为指引**: 当用户询问 DNS 配置问题时（如"如何配置 DoH/DoT"、"nameserver-policy 怎么写"、"hosts 格式是什么"、
> "fallback-filter 各字段含义"等），AI 应查阅 [Mihomo DNS 配置文档](https://wiki.metacubex.one/config/dns/)
> 了解各字段的详细含义和用法，涉及 OpenClash 侧 DNS 覆写实现时查阅
> [OpenClash 源码](https://github.com/vernesong/OpenClash/tree/dev) 中 `yml_change.sh` 的 `yml_dns_custom()` 函数，
> 然后**结合 OpenClash 覆写模块的操作方式**告知用户如何配置，而非仅给出文档链接。

### enable_custom_dns — 自定义上游 DNS 服务器 (Custom DNS Setting)
- **UCI**: `openclash.@config_overwrite[0].enable_custom_dns`
- **默认**: 0
- **说明**: 开启后将通过 TypedSection `dns_servers` 中的配置覆写 YAML 的 `dns` 段
- **最佳实践**: 在 Fake-IP 模式下推荐以下配置策略：① Nameserver 仅负责直连类域名的解析（使用运营商 DNS 或国内 DoH 如 AliDNS/DNSPod）；② **取消所有 Fallback 服务器**——Fake-IP 模式下若无 Fallback，非直连域名的解析请求将交由远端（代理节点侧）完成，解析结果与实际出站链路一致，可获得更一致的 CDN 命中并防止 DNS 泄露；③ 若出站侧解析不可用（罕见），可启用 Fallback 作为兜底并同时开启「遵循规则」功能。**不建议套娃其他 DNS 插件**（如 MosDNS/SmartDNS/AdGuardHome），多插件叠加会引入缓存一致性问题、增加内网解析延迟，且破坏 Mihomo 向客户端传递的 TTL 值
- **实现细节**: 开启后 `yml_dns_custom()` 遍历所有 `dns_servers` 条目，按 group 分类（nameserver/fallback/default）构建 DNS 服务器列表，通过 Ruby YAML 合并写入 `dns.nameserver`、`dns.fallback`、`dns.default-nameserver`。

### enable_respect_rules — 遵守路由规则 (Enable Respect Rules)
- **UCI**: `openclash.@config_overwrite[0].enable_respect_rules`
- **默认**: 0
- **Mihomo 对应**: `dns.respect-rules`
- **说明**: DNS 连接是否遵守 YAML 中的路由规则
- **实现细节**: 写入 YAML `dns.respect-rules: true`。Mihomo 内核的 DNS 解析器发出的连接将经过 `rules` 规则引擎匹配——意味着 DNS 查询本身也会被代理（通过匹配的代理节点发出），防止 DNS 泄露。需要配合 `proxy-server-nameserver` 防止鸡生蛋问题。

### append_wan_dns — 附加上游 DNS (Append WAN DNS)
- **UCI**: `openclash.@config_overwrite[0].append_wan_dns`
- **默认**: 1
- **说明**: 将 WAN 口自动分配的运营商 DNS 和网关 IP 追加到 nameserver 列表。**主路由拨号环境推荐启用**：运营商 DNS 对直连类域名的解析延迟通常最低（1-2ms），CDN 命中更接近实际链路，省去手动配置的麻烦。若使用第三方加密 DNS（如 DoH/DoT），则需禁用此项并在 NameServer 中手动添加服务器
- **实现细节**: `sys_dns_append()` 调用 `openclash_get_network.lua` 获取 WAN 口的 DNS 和网关地址，追加到 `/tmp/yaml_config.namedns.yaml`，后续被合并到 YAML `dns.nameserver`。支持 dhcp:// 协议直接从 DHCP 接口获取 DNS。

### fakeip_range — Fake-IP 范围 (IPv4) (Fake-IP Range)
- **UCI**: `openclash.@config_overwrite[0].fakeip_range`
- **默认**: 0 (禁用)
- **预设**: `198.18.0.1/16` (标准 Fake-IP 段)
- **Mihomo 对应**: `dns.fake-ip-range`
- **仅**: Fake-IP 模式显示
- **实现细节**: 写入 YAML `dns.fake-ip-range`。Mihomo 在 Fake-IP 模式下，将 DNS 查询的域名映射到此 CIDR 段中的虚拟 IP。应用连接到虚拟 IP 时内核通过路由表将流量导向 Clash，Clash 根据映射表还原真实域名后进行规则匹配。

### store_fakeip — 持久化 Fake-IP (Store Fake-IP)
- **UCI**: `openclash.@config_overwrite[0].store_fakeip`
- **默认**: 1
- **Mihomo 对应**: `profile.store-fake-ip`
- **说明**: 缓存 Fake-IP DNS 解析记录到文件，启动后加速响应
- **实现细节**: 写入 YAML `profile.store-fake-ip: true`。Mihomo 将域名→Fake-IP 映射持久化到 `cache.db` 文件，重启后恢复映射，避免重启后所有域名需要重新解析。

### custom_fallback_filter — 自定义 Fallback-Filter (Custom Fallback Filter)
- **UCI**: `openclash.@config_overwrite[0].custom_fallback_filter`
- **默认**: 0
- **说明**: 配置 DNS 防污染回退过滤器
- **配置文件**: `/etc/openclash/custom/openclash_custom_fallback_filter.yaml`
- **Mihomo 对应**: `dns.fallback-filter` 段

> Fallback-Filter 格式示例:
> ```yaml
> geoip: true
> geoip-code: CN
> geosite:
>   - gfw
> domain:
>   - '+.google.com'
> ```

### custom_fakeip_filter — 自定义 Fake-IP-Filter (Custom Fake-IP Filter)
- **UCI**: `openclash.@config_overwrite[0].custom_fakeip_filter`
- **默认**: 0
- **仅**: Fake-IP 模式显示
- **Mihomo 对应**: `dns.fake-ip-filter`

### custom_fakeip_filter_mode — Fake-IP-Filter 模式 (Custom Fake-IP Filter Mode)
- **UCI**: `openclash.@config_overwrite[0].custom_fakeip_filter_mode`
- **可选**: `blacklist` / `whitelist` / `rule`
- **默认**: `blacklist`
- **说明**:
  - `blacklist`: 匹配成功的域名不返回 Fake-IP (黑名单)
  - `whitelist`: 只有匹配成功的域名返回 Fake-IP (白名单)
  - `rule`: 规则模式，支持 GEOSITE、RuleSet、DOMAIN* 等语法
- **Mihomo 对应**: `dns.fake-ip-filter-mode`

### 域名过滤文件 (custom_fake_filter)
- **文件**: `/etc/openclash/custom/openclash_custom_fake_filter.list`
- **格式**: 每行一个域名通配符，如 `*.lan`, `+.example.com`

### custom_name_policy — 自定义 Nameserver-Policy (Custom Name Policy)
- **UCI**: `openclash.@config_overwrite[0].custom_name_policy`
- **文件**: `/etc/openclash/custom/openclash_custom_domain_dns_policy.list`
- **Mihomo 对应**: `dns.nameserver-policy`
- **格式**: 每行 `域名=DNS服务器组` 或使用 geosite/rule-set

### custom_proxy_server_policy — 自定义 Proxy-Server-Nameserver-Policy (Custom Proxy Server Policy)
- **UCI**: `openclash.@config_overwrite[0].custom_proxy_server_policy`
- **文件**: `/etc/openclash/custom/openclash_custom_proxy_server_dns_policy.list`
- **Mihomo 对应**: `dns.proxy-server-nameserver-policy`
- **说明**: 仅用于解析代理节点域名的 DNS 策略

### custom_host — 自定义 Hosts (Custom Hosts)
- **UCI**: `openclash.@config_overwrite[0].custom_host`
- **文件**: `/etc/openclash/custom/openclash_custom_hosts.list`
- **Mihomo 对应**: `dns.hosts`

### DNS 服务器列表 (dns_servers TypedSection)

> **AI 行为指引**: 当用户询问 DNS 服务器类型（如"DoH 和 DoT 有什么区别"、"quic 类型怎么用"、
> "dns 服务器的 `#proxy` 和 `#RULES` 后缀是什么意思"）时，AI 应查阅
> [Mihomo DNS 类型文档](https://wiki.metacubex.one/config/dns/type/) 了解每种 DNS 协议的使用方法和参数，
> 涉及 OpenClash 侧实现时查阅 [OpenClash 源码](https://github.com/vernesong/OpenClash/tree/dev) 中
> `yml_change.sh` 的 DNS 相关逻辑，然后告知用户具体的配置写法。

用户可以添加多条 DNS 服务器记录，每条包含：

| 字段 | UCI Key | 说明 |
|------|---------|------|
| 启用 | `enabled` | Flag，默认 1 |
| 分组 | `group` | `nameserver`(默认DNS) / `fallback`(后备DNS) / `default`(默认DNS) |
| 地址 | `ip` | DNS 服务器 IP |
| 端口 | `port` | 端口号 |
| 类型 | `type` | `udp` / `tcp` / `tls` / `https` / `quic` |
| 禁用 IPv6 | `disable_ipv6` | 丢弃 AAAA 记录 |

**Mihomo YAML 格式示例**:
```yaml
dns:
  nameserver:
    - 223.5.5.5
    - tls://8.8.4.4
  fallback:
    - tls://1.1.1.1
```

## 3.3 Meta 设置标签页 (Meta Settings / meta)

> **生效路径**: Meta 选项通过 `yml_change.sh` 写入 YAML，所有选项在 Mihomo 启动时加载生效。
> 部分选项（sniffer）支持运行时通过 API 热修改。
>
> **AI 行为指引**: 当用户询问 Meta 相关问题（如"tcp-concurrent 和 unified-delay 有什么区别"、
> "find-process-mode 各模式的含义"、"sniffer 如何自定义"、"geodata-loader 选哪个"），
> AI 应查阅 [Mihomo 全局配置文档](https://wiki.metacubex.one/config/general/) 和
> [Mihomo Sniffer 文档](https://wiki.metacubex.one/config/sniff/) 了解各选项的详细含义，
> 涉及 OpenClash 侧 Meta 选项注入实现时查阅 [OpenClash 源码](https://github.com/vernesong/OpenClash/tree/dev) 中
> `yml_change.sh` 的 sniffer/Meta 相关段，然后结合 OpenClash 的覆写设置操作路径告知用户。

### enable_tcp_concurrent — 启用 TCP 并发 (Enable Tcp Concurrent)
- **UCI**: `openclash.@config_overwrite[0].enable_tcp_concurrent`
- **默认**: 0
- **Mihomo 对应**: `tcp-concurrent: true`
- **说明**: 同时使用 DNS 解析的所有 IP 地址发起连接，使用最先成功的连接
- **实现细节**: `yml_change.sh` 写入 YAML `tcp-concurrent: true`。Mihomo 对每个目标域名解析出所有 IP 后，同时向所有 IP 发起 TCP 连接，使用第一个 TCP 握手成功的连接，丢弃其余。可大幅降低首次连接延迟，但会增加并发连接数。

### enable_unified_delay — 启用统一延迟 (Enable Unified Delay)
- **UCI**: `openclash.@config_overwrite[0].enable_unified_delay`
- **默认**: 0
- **Mihomo 对应**: `unified-delay: true`
- **说明**: 消除连接握手等带来的不同类型节点延迟差异
- **实现细节**: 写入 YAML `unified-delay: true`。Mihomo 在 URL-Test 延迟测量时计算 RTT（Round-Trip Time），而非简单的 TCP 握手时间 + HTTP 响应时间。这样 Shadowsocks、Trojan、VMess 等不同协议的节点延迟可公平比较。

### find_process_mode — 启用进程规则 (Find Process Mode)
- **UCI**: `openclash.@config_overwrite[0].find_process_mode`
- **可选值**: `0`(禁用) / `off` / `always` / `strict`
- **默认**: 0
- **Mihomo 对应**: `find-process-mode`
- **说明**: 依赖 `kmod-inet-diag` 内核模块。路由器上推荐 `off` 以提升性能
- **实现细节**: 写入 YAML `find-process-mode`。控制 Mihomo 是否通过 Netlink INET_DIAG 匹配每个连接的发起进程名（用于 PROCESS-NAME 规则）。路由器上设为 `off` 可避免内核模块依赖和性能开销。

### enable_meta_sniffer — 启用流量（域名）探测 (Enable Sniffer)
- **UCI**: `openclash.@config_overwrite[0].enable_meta_sniffer`
- **默认**: 1
- **Mihomo 对应**: `sniffer.enable: true`
- **说明**: 防止域名代理和 DNS 劫持失败。通过嗅探 TLS/HTTP/QUIC 握手获取真实目标域名
- **实现细节**: `yml_change.sh` 写入完整的 `sniffer:` YAML 段：
  - `sniff.TLS.ports: [443, 8443]` — 解析 TLS ClientHello 中的 SNI 字段获取域名
  - `sniff.HTTP.ports: [80, 8080-8880]` — 解析 HTTP Host 头获取域名
  - `sniff.QUIC.ports: [443]` — 解析 QUIC Initial 包中的 SNI
  - `force-dns-mapping: true` (仅 Redir-Host) — 对 DNS 解析过的 IP 强制嗅探
  - `override-destination: true` — 用嗅探到的域名覆盖连接目标，确保规则基于域名匹配
  - 预置 `force-domain: [netflix, nflxvideo, amazonaws, media.dssott.com]` — 强制嗅探流媒体
  - 预置 `skip-domain: [Mijia Cloud, dlg.io.mi.com, oray.com, sunlogin.net, push.apple.com]` — 跳过智能家居/推送

### enable_meta_sniffer_pure_ip — 探测（嗅探）纯 IP 连接 (Forced Sniff Pure IP)
- **UCI**: `openclash.@config_overwrite[0].enable_meta_sniffer_pure_ip`
- **默认**: 1
- **Mihomo 对应**: `sniffer.parse-pure-ip: true`
- **说明**: 对所有未获取到域名的流量进行强制嗅探（如直接 IP 连接）

### enable_meta_sniffer_custom — 自定义流量探测（嗅探）设置 (Custom Sniffer Settings)
- **UCI**: `openclash.@config_overwrite[0].enable_meta_sniffer_custom`
- **默认**: 0
- **说明**: 启用后将使用下方文本框中的自定义 sniffer YAML 配置替代默认嗅探设置

### sniffer_custom — 自定义 Sniffer 文本框 (Sniffer Custom)
- **UCI**: `openclash.@config_overwrite[0].sniffer_custom`
- **存储**: `/etc/openclash/custom/openclash_custom_sniffer.yaml`
- **说明**: 多行 YAML 文本框，可自定义完整的 `sniffer:` 配置段。仅在 `enable_meta_sniffer_custom=1` 时生效

### geodata_loader — Geodata 数据加载方式 (Geodata Loader)
- **UCI**: `openclash.@config_overwrite[0].geodata_loader`
- **可选值**: `0`(禁用) / `memconservative` / `standard`
- **默认**: `memconservative`
- **Mihomo 对应**: `geodata-loader`
- **说明**: `memconservative` 专为小内存设备优化的加载器（逐段读取），`standard` 为标准加载器（一次性加载到内存，速度快但占内存）

### enable_geoip_dat — 启用 GeoIP Dat 版数据库 (Enable GeoIP Dat)
- **UCI**: `openclash.@config_overwrite[0].enable_geoip_dat`
- **默认**: 0
- **Mihomo 对应**: `geodata-mode: true`
- **说明**: 使用 Dat 格式替换 MMDB 格式 GeoIP 文件。Dat 文件较大需单独下载，可通过「GEO 数据库订阅」页面获取

### global_ua — 全局 User-Agent (Global UA)
- **UCI**: `openclash.@config_overwrite[0].global_ua`
- **默认**: 0 (禁用，使用系统默认 `clash.meta`)
- **Mihomo 对应**: `global-ua`
- **预设**: `clash-verge/v2.4.5` / `clash.meta/1.19.20` / `Clash`
- **说明**: 设置 Mihomo 下载外部资源（GEO 文件、规则集等）时使用的 User-Agent

> Sniffer YAML 格式示例:
> ```yaml
> sniffer:
>   enable: true
>   force-dns-mapping: true
>   parse-pure-ip: true
>   override-destination: false
>   sniff:
>     HTTP:
>       ports: [80, 8080-8880]
>     TLS:
>       ports: [443, 8443]
>     QUIC:
>       ports: [443, 8443]
>   force-domain:
>     - +.v2ex.com
>   skip-domain:
>     - Mijia Cloud
> ```

## 3.4 智能设置标签页 (Smart Settings / smart)

> **生效路径**: Smart 策略是智能代理选择引擎，基于 LightGBM 机器学习模型。
> `yml_change.sh` 将 Smart 训练数据收集配置写入 YAML（`profile.smart-collector-size`），
> `yml_rules_change.sh` 负责将 url-test/load-balance 策略组类型转换为 `type: smart` 并设置 Smart 相关参数（uselightgbm、collectdata、sample-rate、policy-priority、prefer-asn）。
> Smart 策略的运行时节点选择由 **Mihomo 内核 Smart 模块内部处理**，无需外部脚本干预。
>
> **AI 行为指引**: 当用户询问 Smart 策略相关问题时（如"Smart 和 url-test 有什么区别"、"如何训练 Smart 模型"、
> "prefer-asn 是什么"、"sample-rate 怎么设置"、"LGBM 模型如何自定义下载"），AI 应：
> 1. 首先查阅下方「智能设置标签页」中对应 UCI 选项的说明，给出 LuCI 操作路径（覆写设置 → Smart 设置）
> 2. Smart 策略组是 **Smart 核心源码独有的功能**（上游 Mihomo 核心无此特性），所有实现细节均应查阅
>    [Smart 核心源码](https://github.com/vernesong/mihomo/tree/Alpha)：
>    - 策略组节点选择逻辑 → `adapter/outboundgroup/smart.go`（`selectProxies()`、`Unwrap()`、`InitSmart()`）
>    - LightGBM 模型加载/推理/数据收集 → `component/smart/lightgbm/`（`lightgbm.go`、`collector.go`、`transform.go`）
>    - Smart 持久化存储与权重计算 → `component/smart/cachefile.go`、`component/smart/weight.go`
> 3. **Smart 节点选择逻辑简述**（`adapter/outboundgroup/smart.go` → `selectProxies()`）：
>    ① 获取目标 IP/域名的 ASN 信息 → ② 优先检查用户手动选择的节点 → ③ 查持久化缓存
>    （boltDB 存储的历史最优结果）→ ④ 查预取缓存（周期性后台预计算）→ ⑤ 实时调用
>    `store.GetBestProxyForTarget()` 综合历史延迟、抖动、丢包率及 LightGBM 模型预测权重
>    计算最优节点 → ⑥ `filterProxies()` 按权重排序过滤。后台定时任务持续维护排名
>    （`updateNodeRanking`）、预取（`runPrefetch`）、稳定性检查（`checkNodesStable`）、
>    被封节点恢复检测（`checkBlockedNodes`）、主机状态检查（`checkHostStatus`）。
> 4. **关于"如何训练 Smart 模型"**：用户如需自行训练模型（而非使用预训练模型），AI 应主动读取
>    [Smart 核心源码](https://github.com/vernesong/mihomo/tree/Alpha) 中 `component/smart/lightgbm/` 目录，
>    了解并告知用户以下信息：
>    - **数据来源**：`component/smart/lightgbm/collector.go` — 开启 `smart_collect` 后核心会在 `/etc/openclash/` 下生成 CSV 训练数据文件（含延迟、抖动、丢包率等特征；特征工程见 `transform.go`）
>    - **LightGBM 版本**：查阅 `go.mod` 中 `vernesong/leaves` 依赖确认支持的 LightGBM 版本
>    - **环境搭建**：在 PC/服务器上安装对应版本的 LightGBM Python 包，准备训练环境
>    - **训练脚本**：参考 `component/smart/lightgbm/` 中的特征处理与模型结构，为用户创建可运行的示例训练脚本（读取 CSV → 特征变换 → 训练 LightGBM → 导出 Model.bin）
>    - **模型部署**：训练完成后将 `Model.bin` 上传到可访问的 URL，通过 `lgbm_custom_url` 指定；或替换 `/etc/openclash/Model.bin`；模型加载与推理见 `lightgbm.go` 中的 `WeightModel`
>    - **日常使用**：大多数用户无需自行训练，开启 `lgbm_auto_update` 即可自动下载预训练模型
> **关键提醒**：Smart 策略使用 LightGBM 模型进行节点质量预测，需要在配置文件中将策略组类型设为 `smart`
> 才能启用（通过 `auto_smart_switch` 自动转换或手动修改 YAML）。Smart 核心在运行时根据模型预测结果
> 和实时延迟数据综合选择最优节点，无需外部脚本干预。

### auto_smart_switch — Smart 策略自动切换 (Smart Auto Switch)
- **UCI**: `openclash.@config_overwrite[0].auto_smart_switch`
- **默认**: 0
- **说明**: 自动将 url-test/load-balance 类型的策略组切换为 Smart 智能策略组
- **实现细节**: `yml_rules_change.sh` 遍历所有策略组，将 `type: url-test` 或 `type: load-balance` 替换为 `type: smart`。Smart 策略组综合延迟、丢包率、历史表现等多维指标选择最优节点。

### smart_policy_priority — 策略优先级 (Policy Priority)
- **UCI**: `openclash.@config_overwrite[0].smart_policy_priority`
- **格式**: `策略名:系数;策略名:系数`，如 `Premium:0.9;SG:1.3`
- **说明**: `<1` 降低优先级，`>1` 提高优先级，默认权重为 1。支持正则和字符串匹配策略组名称

### smart_prefer_asn — 优先 ASN 查询 (Smart Prefer ASN)
- **UCI**: `openclash.@config_overwrite[0].smart_prefer_asn`
- **默认**: 0
- **说明**: 强制查询并使用目标 ASN（自治系统号）信息，优先选择同一 ASN 的更稳定节点

### smart_enable_lgbm — 启用 LightGBM 模型 (Enable LightGBM Model)
- **UCI**: `openclash.@config_overwrite[0].smart_enable_lgbm`
- **默认**: 0
- **说明**: 使用 LightGBM 机器学习模型预测节点权重
- **实现细节**: `yml_change.sh` 配置 YAML 中的模型下载 URL 和更新间隔。`openclash_lgbm.sh` 定期下载训练好的 LightGBM 模型文件到 `/etc/openclash/Model.bin`（小闪存模式下为 `/tmp/etc/openclash/Model.bin`）。Mihomo Smart 模块加载模型后，根据节点历史延迟、抖动、丢包率等特征预测最优节点。

### smart_collect — 收集训练数据 (Collectdata)
- **UCI**: `openclash.@config_overwrite[0].smart_collect`
- **默认**: 0
- **说明**: 收集延迟/抖动等数据供 LightGBM 模型训练

### smart_collect_size — 数据收集文件大小 (Smart Collect Size)
- **UCI**: `openclash.@config_overwrite[0].smart_collect_size`
- **默认**: 100 (MB)
- **依赖**: `smart_collect=1`

### smart_collect_rate — 数据采样率 (Smart Collect Rate)
- **UCI**: `openclash.@config_overwrite[0].smart_collect_rate`
- **默认**: 1 (0-1)
- **依赖**: `smart_collect=1`

### lgbm_auto_update — 自动更新 LightGBM 模型 (LGBM Auto Update)
- **UCI**: `openclash.@config_overwrite[0].lgbm_auto_update`
- **默认**: 0

### lgbm_update_interval — 模型更新间隔 (LGBM Update Interval)
- **UCI**: `openclash.@config_overwrite[0].lgbm_update_interval`
- **默认**: 72 (小时)
- **依赖**: `lgbm_auto_update=1`

### lgbm_custom_url — 自定义模型下载地址 (LGBM Custom URL)
- **UCI**: `openclash.@config_overwrite[0].lgbm_custom_url`
- **默认**: `https://github.com/vernesong/mihomo/releases/download/LightGBM-Model/Model.bin`（轻量版）
- **可选**: 中量版 (`Model-middle.bin`)、重量版 (`Model-large.bin`) — 模型越大预测越准确但占用更多内存
- **依赖**: `lgbm_auto_update=1`

### 手动更新模型按钮
- **功能**: 点击触发 `openclash_lgbm.sh` 立即下载最新模型并显示当前模型文件时间戳

### 刷新 Smart 缓存按钮
- **功能**: 通过 Mihomo API `POST /cache/smart/flush` 清空 Smart 策略缓存，强制重新评估所有节点

---

## 3.5 规则设置标签页 (Rules Settings / rules)

> 此标签页用于管理自定义 Clash/Mihomo 路由规则。Mihomo 支持多种规则类型，
> 用户在 LuCI 文本框中编写规则时需遵循特定格式。

### enable_rule_proxy — 仅代理命中规则流量 (Rule Match Proxy Mode)
- **UCI**: `openclash.@config_overwrite[0].enable_rule_proxy`
- **默认**: 0
- **说明**: 开启后向配置追加 PROCESS-NAME 和 DST-PORT 规则，仅允许匹配规则的流量走代理，其余流量（如 BT/P2P）直连

### enable_custom_clash_rules — 自定义规则 (Custom Clash Rules)
- **UCI**: `openclash.@config_overwrite[0].enable_custom_clash_rules`
- **默认**: 0
- **说明**: 开启后将在运行配置的 `rules:` 段注入自定义规则文件中的内容

### custom_rules — 优先规则编辑框 (Custom Rules Priority)
- **UCI**: `openclash.@config_overwrite[0].custom_rules`
- **存储**: `/etc/openclash/custom/openclash_custom_rules.list`
- **格式**: 每行一条 Mihomo 规则，插入到规则列表顶部（优先匹配）
- **依赖**: `enable_custom_clash_rules=1`

### custom_rules_2 — 扩展规则编辑框 (Custom Rules Extended)
- **UCI**: `openclash.@config_overwrite[0].custom_rules_2`
- **存储**: `/etc/openclash/custom/openclash_custom_rules_2.list`
- **格式**: 每行一条 Mihomo 规则，插入到规则列表底部
- **依赖**: `enable_custom_clash_rules=1`

### 规则编写指南

> **当用户描述需求（如"我想让某个域名走代理"、"禁止某个 IP 走代理"）时，AI 应查阅 [Mihomo 路由规则文档](https://wiki.metacubex.one/config/rules/) 了解各规则类型的作用，涉及规则注入实现时查阅 [OpenClash 源码](https://github.com/vernesong/OpenClash/tree/dev) 中 `yml_rules_change.sh` 和 `custom_rules*.list` 的处理逻辑，然后告知用户具体的规则写法。**

**Mihomo 支持的规则类型速查**:

| 规则类型 | 格式 | 用途 | 示例 |
|---------|------|------|------|
| `DOMAIN` | `DOMAIN,域名,策略` | 精确匹配域名 | `DOMAIN,www.google.com,Proxy` |
| `DOMAIN-SUFFIX` | `DOMAIN-SUFFIX,域名后缀,策略` | 匹配域名后缀（含所有子域名） | `DOMAIN-SUFFIX,google.com,Proxy` |
| `DOMAIN-KEYWORD` | `DOMAIN-KEYWORD,关键词,策略` | 匹配域名含关键词 | `DOMAIN-KEYWORD,youtube,Proxy` |
| `DOMAIN-REGEX` | `DOMAIN-REGEX,正则,策略` | 域名正则匹配 | `DOMAIN-REGEX,^api\.example\.com$,Proxy` |
| `GEOSITE` | `GEOSITE,类别,策略` | 按 GeoSite 类别匹配域名 | `GEOSITE,netflix,NETFLIX` |
| `GEOIP` | `GEOIP,国家代码,策略` | 按 GeoIP 国家匹配 IP | `GEOIP,CN,DIRECT` |
| `IP-CIDR` | `IP-CIDR,IP/掩码,策略` | IP 段匹配 | `IP-CIDR,10.0.0.0/8,DIRECT` |
| `IP-CIDR6` | `IP-CIDR6,IPv6/掩码,策略` | IPv6 段匹配 | `IP-CIDR6,::1/128,DIRECT` |
| `IP-ASN` | `IP-ASN,ASN号,策略` | 自治系统号匹配 | `IP-ASN,13335,Proxy` |
| `RULE-SET` | `RULE-SET,规则集名,策略` | 引用 rule-provider 规则集 | `RULE-SET,reject,REJECT` |
| `PROCESS-NAME` | `PROCESS-NAME,进程名,策略` | 按进程名匹配 | `PROCESS-NAME,aria2c,DIRECT` |
| `DST-PORT` | `DST-PORT,端口,策略` | 目标端口匹配 | `DST-PORT,80,Proxy` |
| `SRC-PORT` | `SRC-PORT,端口,策略` | 源端口匹配 | `SRC-PORT,8080,DIRECT` |
| `SRC-IP-CIDR` | `SRC-IP-CIDR,IP/掩码,策略` | 源 IP 段匹配 | `SRC-IP-CIDR,192.168.1.0/24,DIRECT` |
| `MATCH` | `MATCH,策略` | 兜底匹配所有流量 | `MATCH,Proxy` |

**可用策略目标**: `DIRECT`(直连)、`Proxy`(走默认代理组)、`REJECT`(拒绝)、`REJECT-DROP`(静默丢弃)、`GLOBAL`(走全局组)、任意自定义策略组名称

**编写格式**: 不区分大小写，逗号分隔。每行一条规则。规则按顺序从上到下匹配，命中后不再继续。

**常见需求 → 规则示例**:

| 用户需求 | 规则写法 |
|---------|---------|
| Google 走代理 | `DOMAIN-SUFFIX,google.com,Proxy` |
| 国内域名直连 | `GEOSITE,cn,DIRECT` |
| Netflix 走专用策略组 | `GEOSITE,netflix,NETFLIX` |
| 禁止访问某域名 | `DOMAIN-SUFFIX,badsite.com,REJECT` |
| BT 下载直连 | `PROCESS-NAME,qbittorrent,DIRECT` |
| 特定 IP 段直连 | `IP-CIDR,192.168.0.0/16,DIRECT` |
| GitHub 直连加速 | `DOMAIN-SUFFIX,github.com,DIRECT` |
| 所有流量走代理 | `MATCH,Proxy` |
| 排除某设备走代理 | `SRC-IP-CIDR,192.168.1.100/32,DIRECT` |

> **进阶规则类型**（如 `AND`/`OR`/`NOT` 逻辑规则、`SUB-RULE` 子规则等）请查阅 [Mihomo 路由规则文档](https://wiki.metacubex.one/config/rules/)。

---

## 3.6 认证设置 (Authentication)

位于常规设置标签页中，为 SOCKS/HTTP/Mixed 代理添加用户认证：

| 字段 | UCI Key | 说明 |
|------|---------|------|
| 启用 | `enabled` | Flag, 默认 1 |
| 用户名 | `username` | 代理认证用户名 |
| 密码 | `password` | 代理认证密码 |

**Mihomo 对应**: `authentication` 列表，格式 `["user:pass"]`

---

# 第四部分：配置订阅页面 (Config Subscribe / config-subscribe)

> UCI Section: `openclash.config_subscribe` (多条)

> **AI 行为指引**: 当用户询问订阅相关问题（如"如何过滤节点"、"订阅转换怎么用"、"订阅 URL 格式不对怎么办"、
> "keyword 和 ex_keyword 的区别"、"Age 加密是什么"），AI 应查阅 [Mihomo 代理协议文档](https://wiki.metacubex.one/config/proxies/)
> 了解节点名称的命名规范和常见格式，涉及订阅处理实现细节时查阅
> [OpenClash 源码](https://github.com/vernesong/OpenClash/tree/dev) 中 `openclash.sh` 的
> `sub_info_get()`、`config_cus_up()`、`server_key_match()` 等函数，
> 然后告知用户具体的配置方法。对于订阅转换后端问题，
> 告知用户转换后端的地址格式和模板 URL 的作用。

## 实现总览

```
 Cron / Web UI「更新配置」
        │
        ▼
 openclash.sh (订阅更新主脚本)
        │
        ├─ config_download()     → curl 下载订阅 URL (支持代理/直连回退)
        ├─ sub_convert           → 可选: 发送到订阅转换后端
        ├─ config_cus_up()       → Ruby YAML 解析 + 节点关键字过滤/排除
        ├─ config_test()         → clash -t 验证 YAML 语法
        └─ config_su_check()     → 新旧对比，有更新则替换 + 标记重启
```

**核心流程** (`openclash.sh` 中的 `sub_info_get()`):
1. 遍历所有启用的 `config_subscribe` 条目
2. 对每条订阅构建下载 URL（添加 `custom_params`、设置 `sub_ua`）
3. 如果设置了 `sub_convert`，将 URL 发到转换后端获取处理后的配置
4. 如果设置了 `secret_key` (Age 加密)，先用 age 解密
5. 用 Ruby YAML 解析订阅配置 → 获取所有代理节点
6. 根据 `keyword` / `ex_keyword` 正则匹配过滤节点：
   - `&` = AND: 节点名必须同时包含所有关键字
   - `|` = OR: 节点名包含任一关键字即保留
7. 将过滤后的节点合并到当前配置的 `proxies` 和 `proxy-groups` 中
8. 写入 `/etc/openclash/config/<name>.yaml`，标记核心需重启

**关键字匹配实现** (`server_key_match()`):
将用户输入的关键字转换为 Ruby 正则表达式。`&` 分隔的转为正向预查链 `(?=.*kw1)(?=.*kw2)`，`|` 分隔的转为择一匹配 `(kw1|kw2)`。

### 自动更新 (Auto Update)

| 选项 | UCI Key | 说明 |
|------|---------|------|
| 自动更新 (Auto Update) | `auto_update` | Flag，默认 0 |
| 更新模式 | `config_auto_update_mode` | `0`=预约模式(指定周几几点), `1`=循环模式(每隔N分钟) |
| 更新日 (Update Time Every Week) | `config_update_week_time` | `*`=每天 (Every Day), `1`=周一, …, `0`=周日 |
| 更新时间 (Update time every day) | `auto_update_time` | 0-23 点 |
| 更新间隔/分钟 (Update Interval min) | `config_update_interval` | 仅循环模式，默认 60 |

### 每条订阅 (`config_subscribe` TypedSection)

| 字段 | 用途 |
|------|------|
| 订阅名称 (Config Alias) | `name` | 用于区分，请勿重名 |
| 订阅地址 (Subscribe Address) | `address` | 订阅 URL |
| **User-Agent** (UA) | `sub_ua` | 预设 clash-verge/clash.meta/clash |
| **在线订阅转换 (Subscribe Convert Online)** | `sub_convert` | 订阅转换后端地址 |
| **订阅转换模板 (Template Name)** | `sub_template` | 转换模板 URL |
| **筛选节点 (Keyword Match)** | `keyword` | 节点关键字匹配 (保留匹配的节点) |
| **排除节点 (Exclude Keyword Match)** | `ex_keyword` | 排除关键字 (排除匹配的节点) |
| **自定义参数 (Custom Params)** | `custom_params` | 自定义订阅 URL 参数 |
| **Age 加密密钥 (Secret Key)** | `secret_key` | Age 加密密钥 |

**关键字格式**: 使用 `&` 表示 AND (同时满足)，使用 `|` 表示 OR
- 例：`香港&01` → 节点名同时包含"香港"和"01"
- 例：`香港|台湾` → 节点名包含"香港"或"台湾"

---

# 第五部分：配置管理页面 (Config Manage / config)

> LuCI 路径: `服务` → `OpenClash` → `配置管理` (顺序第 80)
> UCI 映射: `openclash.config.config_path`

## 实现总览

配置管理页面是一个多功能综合页面，提供配置文件的上传、切换、编辑、重命名、删除以及提供商文件管理功能。

**核心功能区块**:

| 区块 | 功能 | 后端路由 |
|------|------|----------|
| 文件上传 (Upload) | 上传配置文件、代理/规则提供商、核心二进制、备份恢复 | `/upload_config` + `file_type` 参数区分 |
| **配置文件列表** | 查看/切换/编辑/重命名/复制/下载/删除配置 | `/switch_config`、`/config_file_list`、`/config_file_save` 等 |
| **提供商文件管理** | 跳转到代理提供商和规则提供商管理子页 | 跳转链接 |
| **配置文件编辑器** | 双栏 YAML 编辑器（左侧可编辑用户配置，右侧只读默认模板） | `/config_file_read` + `/config_file_save` |

## 5.1 文件上传

| 上传类型 | `file_type` 值 | 目标目录 | 说明 |
|----------|---------------|----------|------|
| 配置文件 (Config) | `config` | `/etc/openclash/config/` | `.yaml`/`.yml` 格式，上传后自动设为当前启用配置 |
| 代理集文件 (Proxy Provider File) | `proxy-provider` | `/etc/openclash/proxy_provider/` | 订阅中 `proxy-providers` 的节点文件 |
| 规则集文件 (Rule Provider File) | `rule-provider` | `/etc/openclash/rule_provider/` | 订阅中 `rule-providers` 的规则文件 |
| 内核文件 (Core File) | `clash_meta` | `/etc/openclash/core/` | 支持 `.tar.gz`/`.gz` 格式自动解压，`chmod 4755` |
| 备份恢复 | `backup-file` | 恢复到 `/etc/config/openclash` | 上传备份并恢复 UCI 配置 |

## 5.2 配置文件列表

| 操作 | 功能 | 说明 |
|------|------|------|
| **SwiTch** (切换) | 切换启用配置 | 修改 `config_path` UCI + commit，自动重启核心 |
| **Edit** (编辑) | 在线编辑配置 | 跳转到双栏 YAML 编辑器 |
| **Rename** (重命名) | 重命名 | 输入新名称，`mv` 重命名文件 |
| **Copy** (复制配置) | 复制配置 | 生成 `<文件名>(N).yaml` 副本 |
| **Download** (下载配置) | 下载配置文件 | HTTP 下载原始配置文件 |
| **Download Run** (下载运行配置) | 下载运行时配置 | 下载 `/etc/openclash/<name>`（经脚本处理后的实际运行配置） |
| **Remove** (移除) | 删除配置 | 删除 YAML 文件 + 历史缓存 `/etc/openclash/history/<name>.db` + 运行时配置，自动切换到其他配置 |

## 5.3 配置文件编辑器

双栏 YAML 编辑器：
- **左栏 (可编辑)**: 读写当前 `config_path` 指向的配置，保存时自动 `\r\n` → `\n` 转换
- **右栏 (只读)**: 展示运行时配置 `/etc/openclash/<name>` 或默认模板 `/usr/share/openclash/res/default.yaml`
- **操作按钮**: Commit (保存配置 (Commit Settings))、Create (新建配置)、Apply (应用配置 (Apply Settings))
- **快捷键**: F10 diff 控制、F11 全屏模式

## 5.4 提供商子页面

通过配置管理页面可跳转到以下子页面（独立 CBI 页面）：
- **servers** — 代理节点管理（编辑/新增/删除节点）
- **servers-config** — 节点配置编辑器
- **groups-config** — 策略组配置编辑器
- **proxy-provider-config** — 代理提供商配置
- **proxy-provider-file-manage** — 代理提供商文件管理
- **rule-providers-file-manage** — 规则提供商文件管理

---

# 第六部分：运行日志页面 (Server Logs / log)

> LuCI 路径: `服务` → `OpenClash` → `运行日志` (顺序第 90)
> UCI 映射: `openclash.openclash.clog`

## 实现总览

运行日志页面是一个双标签页的日志查看器。页面布局包含以下区域：

**标签页 1 — OpenClash Log** (默认激活)：展示 OpenClash 插件自身日志（Shell/Ruby/Lua 脚本输出），通过 XHR 轮询 (`/refresh_log`) 每秒刷新。

**标签页 2 — Core Log** (可切换)：展示 Mihomo 内核实时日志，通过 WebSocket 连接到内核 API (`/logs?token=...&level=...`)。该标签页内嵌 **5 个日志等级单选按钮**：

| 按钮 | 功能 | 后端操作 |
|------|------|----------|
| **Info** (信息) | 默认等级，显示一般信息及以上 | GET `/log_level` → 设置 WebSocket level |
| **Warning** (警告) | 只显示警告及以上 | GET `/switch_log` + WebSocket 重连 |
| **Error** (错误) | 只显示错误及以上 | 同上 |
| **Debug** (调试) | 显示所有调试信息 | 同上 |
| **Silent** (静默) | 静默模式，不显示内核日志 | 同上 |

**标签页 3 — Debug Log** (可切换)：展示插件的调试日志，内容由 `openclash_debug.sh` 生成，包含系统信息、依赖包检查、内核运行状态、插件设置、覆写模块设置、自定义规则文件内容、当前 Mihomo YAML 配置、自定义覆写/防火墙脚本内容、完整的 iptables-save dump、完整的 nftables 规则、ipset 状态、路由表、TUN 设备状态、端口占用、DNS 解析测试、网络连通性测试、最近运行日志、活动连接列表及隐私处理等。

**底部操作按钮栏**（两个标签页共用）：

| 按钮 | 功能 | 后端操作 |
|------|------|----------|
| **Stop Refresh** (停止刷新) | 暂停日志刷新（XHR 轮询 + WebSocket 均停止） | 停止 `poll_log()` 和 `coreLogWebSocketStop()` |
| **Start Refresh** (开始刷新) | 恢复日志刷新 | 重新启动轮询和 WebSocket |
| **Clean** (清理日志) | 清空日志文本框 | GET `/del_log` |
| **Download Log** (下载日志) | 下载完整日志文件（OC 日志 + Core 日志合并） | 调试日志会单独下载不会进行拼接 | 其他两个标签的内容前端进行拼接下载 |
| **Generate Logs** (生成调试日志) | 点击生成调试日志并展示 | 前端下载时不拼接 |

**OpenClash|Mihomo 日志来源**: OpenClash 日志由后端将 UCI `clog` 字段内容写入 CodeMirror 日志编辑器。内核日志通过 WebSocket 实时推送到前端 `textarea#core_log`。

**调试日志来源|实现细节**: `openclash_debug.sh` 使用文件锁防止并发，收集以下 20+ 个章节并输出到 `/tmp/openclash_debug.log`：
  1) 系统信息（固件版本、内核版本、CPU 架构）
  2) 依赖包检查（dnsmasq-full、bash、curl、ruby、ruby-yaml、kmod-tun、kmod-inet-diag、kmod-nft-tproxy 或 kmod-ipt-tproxy 等）
  3) 内核运行状态（PID、运行用户、Meta 内核版本 `clash_meta -v`）
  4) 插件设置（所有 UCI 运行模式/代理/DNS/IPv6 配置值）
  5) 覆写模块设置（`uci show openclash.@overwrite[0]`）
  6) 自定义规则文件内容
  7) 当前 Mihomo YAML 配置（过滤掉 proxies/proxy-providers/secret 保护隐私）
  8) 自定义覆写/防火墙脚本内容
  9) 完整的 iptables-save dump（nat/mangle/filter 表，含 IPv6）
  10) 完整的 nftables 规则（inet fw4 中所有链）
  11) ipset 状态
  12) 路由表（IPv4/IPv6 route、策略路由表 354、ip rule）
  13) TUN 设备状态
  14) 端口占用（netstat）
  15) DNS 解析测试（nslookup + Mihomo 内核 DNS 测试）
  16) 网络连通性测试（curl www.baidu.com + GitHub）
  17) 最近运行日志（临时切换日志级别到 debug 后采集 100 行）
  18) 活动连接列表（通过 Mihomo API 获取）
  19) 隐私处理（IPv4 最后一字节和 IPv6 后半部分模糊化）

**附加组件**: 页面同时加载 `openclash/toolbar_show`（**配置切换工具栏**：下拉选择当前配置文件 + Switch 按钮）和 `openclash/config_editor`（**页面内嵌 CodeMirror 编辑器**，预加载 CodeMirror CSS/JS 资源并通过全局 `merge_editor()` 函数对外开放合并视图功能，非日志渲染用途，仅作文件编辑功能复用）。

> **注意**: 如需修改 OpenClash 自身日志级别，请在「覆写设置 → 常规设置」中调整 `log_level`。内核日志标签页内可直接切换内核日志等级。

---

# 第七部分：常见需求 → 操作映射

> 当用户说"我想实现XX"时，AI 应推荐以下选项组合

| 用户需求 | 需启用/设置的选项 | 位置 |
|----------|-------------------|------|
| 所有设备都能翻墙 | `en_mode`=redir-host/fake-ip (默认已配好) | 插件设置→模式设置 |
| 某台设备不走代理 | `lan_ac_mode`=0 (黑名单模式 (Black List Mode)) + `lan_ac_black_ips` (不走代理的局域网设备 IP) 添加该设备IP | 插件设置→黑白名单 |
| 某个接口流量绕过内核 | 插件设置页面底部「来源流量访问控制」添加规则：`interface=接口名`, `target=RETURN` | 插件设置 |
| 仅某台设备走代理 | `lan_ac_mode`=1 (白名单模式 (White List Mode)) + `lan_ac_white_ips` (走代理的局域网设备 IP) 添加该设备IP | 插件设置→黑白名单 |
| 禁止 BT 下载走代理 | `common_ports` (仅允许常用端口流量) 设为预设常用端口 | 插件设置→流量控制 |
| 国内网站直连加速 | `china_ip_route`=1 (绕过中国大陆 (Bypass Mainland China)) | 插件设置→流量控制 |
| 看 Netflix/Disney+ | `stream_auto_select`=1 + 对应服务子选项 | 插件设置→流媒体增强 |
| 路由器自身走代理 | `router_self_proxy`=1 (本机代理) | 插件设置→流量控制 |
| 路由器自身不走代理 | `router_self_proxy`=0 (本机代理) | 插件设置→流量控制 |
| 禁止 YouTube 走 QUIC | `disable_udp_quic`=1 (禁用 QUIC，默认已开) | 插件设置→流量控制 |
| 外网访问 Dashboard | `dashboard_forward_domain` + `dashboard_forward_port` 配置 | 插件设置→外部控制 |
| 换一个 Dashboard | 在插件设置-外部控制页切换 | 插件设置→外部控制 |
| DNS 解析异常 | 先点"清空 DNS 缓存"，不行用"Dnsmasq 修复" | 插件设置→DNS |
| 停止后上不了网 | 点击"Dnsmasq 修复"按钮 | 插件设置→DNS |
| 开启 IPv6 | `ipv6_enable`=1 (不推荐) | 插件设置→IPv6 |
| 定时重启 | `auto_restart`=1 + 设置时间 | 插件设置→定时重启 |
| 定时更新订阅 | `auto_update`=1 + 设置时间和模式 | 配置订阅 |
| 定时更新 GEO | `geo_auto_update`=1 (等) + 设置时间 | 插件设置→GEO 数据库订阅 |
| 过滤订阅节点 | 编辑订阅 → keyword (筛选节点) / ex_keyword (排除节点) 设置 | 配置订阅 |
| 更改代理端口 | `http_port` / `socks_port` / `mixed_port` 修改 | 覆写设置→常规 |
| 覆写订阅 DNS | `enable_custom_dns`=1 (自定义 DNS 设置 (Custom DNS Setting)) + 添加 `dns_servers` | 覆写设置→DNS |
| 添加代理认证 | 添加 `authentication` 条目 (用户名/密码) | 覆写设置→常规 |
| 添加自定义规则 | `enable_custom_clash_rules`=1 (自定义规则 (Custom Clash Rules)) + 编辑规则文件 | 覆写设置→规则 |
| 加速 Github 下载 | `github_address_mod` 选 CDN 地址 | 覆写设置→常规 |
| 开启域名嗅探 | `enable_meta_sniffer`=1 (启用域名嗅探 (Enable Meta Sniffer)，默认已开) | 覆写设置→Meta |
| TCP 并发提速 | `enable_tcp_concurrent`=1 (启用 TCP 并发 (Enable TCP Concurrent)) | 覆写设置→Meta |
| 生成 PAC 文件 | 运行状态页 → 混合代理卡片 → **获取 PAC 配置** | 运行状态 |

---

## 后台命令速查

```bash
# 启动/停止/重启
/etc/init.d/openclash start|stop|restart

# 查看 UCI 配置
uci show openclash

# 修改 UCI 配置 (例: 切换代理模式为全局)
uci set openclash.@openclash[0].proxy_mode='global'
uci commit openclash

# 手动更新订阅
/usr/share/openclash/openclash.sh

# 更新 GEO 数据
/usr/share/openclash/openclash_geo.sh ipdb    # GeoIP MMDB
/usr/share/openclash/openclash_geo.sh geoip   # GeoIP Dat
/usr/share/openclash/openclash_geo.sh geosite # GeoSite
/usr/share/openclash/openclash_geo.sh geoasn  # GeoASN

# 更新大陆路由表
/usr/share/openclash/openclash_chnroute.sh

# 更新核心
/usr/share/openclash/openclash_core.sh

# 更新插件
/usr/share/openclash/openclash_update.sh

# 一键更新 (核心+订阅+GEO)
/usr/share/openclash/openclash_update.sh one_key_update

# 生成调试日志
/usr/share/openclash/openclash_debug.sh

# 查看运行日志
cat /tmp/openclash.log

# 查看启动日志
cat /tmp/openclash_start.log

# 测试配置文件语法
/etc/openclash/clash -t -d /etc/openclash -f /etc/openclash/config/xxx.yaml

# 清空 DNS 缓存 (通过 API)
curl -X POST http://127.0.0.1:9090/cache/fakeip/flush
curl -X POST http://127.0.0.1:9090/cache/dns/flush
```

---

## Mihomo Wiki 参考链接

- [全局配置 (General)](https://wiki.metacubex.one/config/general/) — mode, log-level, ipv6, tcp-concurrent 等
- [DNS 配置](https://wiki.metacubex.one/config/dns/) — enhanced-mode, nameserver, fallback, fake-ip-filter 等
- [TUN 配置](https://wiki.metacubex.one/config/inbound/tun/) — stack, auto-route, dns-hijack 等
- [域名嗅探 (Sniffer)](https://wiki.metacubex.one/config/sniff/) — sniffer 各项参数
- [完整配置示例](https://github.com/MetaCubeX/mihomo/blob/Meta/docs/config.yaml)

---

# 第八部分：LuCI API 端点参考 (后台直接调用)

> 用户登录路由器后，可通过 curl/XHR 直接调用以下端点实现自动化操作
> 所有端点基础路径: `http://路由器IP/cgi-bin/luci/admin/services/openclash`

## 8.1 状态查询类 (GET)

| 端点 | 返回 | 用途 |
|------|------|------|
| `/status` | JSON `{clash, daip, dase, cn_port, core_type, ...}` | 获取核心运行状态、Dashboard 地址、密钥 |
| `/op_mode` | JSON `{op_mode}` | 当前页面模式 (redir-host/fake-ip) |
| `/get_run_mode` | JSON `{en_mode}` | 当前运行模式 |
| `/rule_mode` | JSON `{proxy_mode}` | 当前代理模式 (rule/global/direct) |
| `/log_level` | JSON `{log_level}` | 当前日志级别 |
| `/toolbar_show` | JSON `{upload, download, connect, mem, cpu, load_avg}` | 实时流量统计 |
| `/oc_settings` | JSON `{meta_sniffer, respect_rules, oversea, stream_unlock}` | 快捷设置状态 |
| `/config_name` | JSON `{current, list[]}` | 配置文件列表及当前选中 |
| `/config_file_list` | JSON `{files[], current}` | 配置文件详细列表 (含修改时间) |
| `/update_info` | JSON `{corever, release_branch, smart_enable}` | 用户选择的核心版本号 (UCI `core_version`)、发行分支、Smart 启用状态。注意 `corever` 是用户在更新页面选择的版本配置，非当前运行版本 |
| `/update` | JSON `{coremodel, coremetacv, corelv, opcv, oplv, upchecktime}` | 完整版本信息：CPU 架构、当前核心版本（执行 `clash_meta -v` 解析）、远程最新核心版本、当前/最新插件版本、更新检查时间 |
| `/dashboard_type` | JSON `{dashboard_type, yacd_type, default_dashboard}` | 仪表盘类型和可用性 |
| `/proxy_info` | JSON `{mixed_port, auth_user, auth_pass}` | 混合代理地址和认证信息 |
| `/sub_info_get?filename=xxx` | JSON | 订阅流量/到期信息 |
| `/myip_check` | JSON `{upaiyun, ipip, ipsb, ipify}` | 并行查询当前出口 IP |
| `/startlog` | JSON `{startlog}` | 最后一行启动日志 |
| `/announcement` | JSON | 项目公告 (24h 缓存) |
| `/get_subscribe_data` | JSON | 所有订阅配置详情 |
| `/oix_info` | JSON | oixCloud 账户信息 |

## 8.2 操作修改类 (POST/GET)

| 端点 | 参数 | 效果 |
|------|------|------|
| `/action` | `{action: "start"\|"stop"\|"restart"}` | 启动/停止/重启核心 (POST) |
| `/switch_mode` | — | 切换页面模式 redir-host↔fake-ip |
| `/switch_run_mode` | `{mode: ""\|"-tun"\|"-mix"}` | 切换运行模式 (POST, 运行中自动重启) |
| `/switch_rule_mode` | `{mode: "rule"\|"global"\|"direct"}` | 切换代理模式 (POST, 热生效) |
| `/switch_config` | `{config: "文件名.yaml"}` | 切换当前配置文件 (POST, 自动重启) |
| `/switch_oc_setting` | `{setting, value}` | 快捷设置切换。setting=meta_sniffer/respect_rules/oversea/stream_unlock |
| `/switch_log` | `{level: "info"\|"debug"\|...}` | 修改日志级别 (POST, 热生效) |
| `/switch_dashboard` | `{name, type}` | 下载/切换仪表盘 |
| `/delete_dashboard` | `{name}` | 删除仪表盘 |
| `/default_dashboard` | `{name}` | 设为默认仪表盘 |
| `/coreupdate` | — | 更新核心二进制 (POST) |
| `/opupdate` | — | 更新插件本身 (POST) |
| `/one_key_update` | — | 一键更新 (POST) |
| `/update_config` | `{filename}` | 更新指定订阅配置 (POST) |
| `/flush_dns_cache` | — | 清空 DNS 缓存 (POST) |
| `/flush_smart_cache` | — | 清空 Smart 缓存 (POST) |
| `/close_all_connection` | — | 断开所有连接 (POST) |
| `/reload_firewall` | — | 重载防火墙规则 (POST) |
| `/restore` | — | 还原默认配置 (POST) |
| `/generate_pac` | — | 生成 PAC 文件 (POST) |
| `/save_corever_branch` | `{core_version, release_branch, smart_enable}` | 保存核心版本选择 (POST) |
| `/upload_config` | (multipart) | 上传配置文件 (POST) |
| `/config_file_save` | `{filename, content}` | 保存配置文件 (POST) |
| `/config_file_read` | `{filename}` | 读取配置文件内容 |
| `/add_subscription` | (表单数据) | 添加/编辑订阅 (POST) |
| `/generate_age_key` | — | 生成 Age 加密密钥对 (POST) |
| `/cal_age_public_key` | — | 计算 Age 公钥 (POST) |
| `/oix_login` | `{email, passwd}` | oixCloud 登录 (POST) |
| `/oix_logout` | — | oixCloud 登出 (POST) |
| `/oix_checkin` | — | oixCloud 签到 (POST) |

## 8.3 诊断类 (GET)

| 端点 | 参数 | 用途 |
|------|------|------|
| `/diag_connection` | `{addr}` | 连接诊断 (返回 text/plain) |
| `/diag_dns` | `{hostname}` | DNS 解析诊断 |
| `/gen_debug_logs` | — | 生成完整调试日志 |
| `/manual_stream_unlock_test` | `{type}` | 手动流媒体解锁测试 |
| `/refresh_log` | `{seek, include_core}` | 获取新日志行 |
| `/del_log` | — | 清空日志文件 |

## 8.4 Mihomo 原生 API (直连核心)

核心运行时可直调 (`http://127.0.0.1:9090`):

| 端点 | 方法 | 用途 |
|------|------|------|
| `/configs` | GET/PATCH/PUT | 读取/修改运行时配置 (热生效) |
| `/proxies` | GET | 获取所有代理节点 |
| `/proxies/{name}` | PUT | 切换策略组选择 |
| `/rules` | GET | 获取路由规则 |
| `/connections` | GET/DELETE | 查看/关闭连接 |
| `/cache/fakeip/flush` | POST | 清空 Fake-IP 缓存 |
| `/cache/dns/flush` | POST | 清空 DNS 解析缓存 |
| `/cache/smart/flush` | POST | 清空 Smart 策略缓存 |
| `/traffic` | GET | 实时流量数据 |
| `/logs` | WebSocket | 实时日志流 |
| `/version` | GET | 核心版本信息 |

---

# 第九部分：Shell 脚本功能映射

> 每个脚本被哪个 UI 操作触发、读取哪些 UCI、完成什么功能

## 9.1 主服务脚本 `/etc/init.d/openclash`

**触发方式**: `start|stop|restart|reload|enable|disable` 命令 / Web UI 启停按钮 / 开机自启

| 函数 | 功能 |
|------|------|
| `start_service` | 完整启动流程: 配置覆写→内核检查→YAML验证→yml修改→防火墙→DNS劫持→cron→看门狗 |
| `stop_service` | 停止流程: 备份历史→恢复防火墙→kill 进程→恢复DNS→清理cron |
| `reload_service` | 重载防火墙规则 (不重启核心) |
| `set_firewall` | 建立 iptables/nftables 规则 (REDIRECT/TPROXY/TUN/访问控制) |
| `revert_firewall` | 清除所有防火墙规则 |
| `change_dnsmasq` | DNS 劫持 (修改 dnsmasq 配置指向核心 DNS) |
| `revert_dnsmasq` | 恢复原始 dnsmasq 配置 |
| `add_cron` | 添加定时任务 (订阅更新/GEO更新/Chnroute更新/重启) |
| `del_cron` | 删除所有 OpenClash 定时任务 |
| `overwrite_file` | 执行覆写模块 (处理自定义覆写脚本) |
| `config_choose` | 自动选择配置文件 |
| `do_run_file` | 检查并下载缺失的核心/GEO/Chnroute 文件 |

## 9.2 订阅更新脚本 `openclash.sh`

**触发**: Web UI「更新配置」按钮 / Cron `/usr/share/openclash/openclash.sh`

| 函数 | 功能 |
|------|------|
| `sub_info_get` | 遍历所有订阅→解析设置→构建下载URL→关键字匹配正则 |
| `config_download` | curl 下载订阅配置 |
| `config_test` | `clash -t` 语法验证 |
| `config_cus_up` | Ruby YAML 解析→节点关键字过滤/排除 |
| `config_su_check` | 新旧配置对比→有更新则替换+标记重启 |
| `config_download_direct` | 代理下载失败时回退直连下载 |
| `server_key_match` | 构建节点匹配正则 (`&`=AND, `|`=OR) |

## 9.3 核心更新脚本 `openclash_core.sh`

**触发**: Web UI「更新内核」按钮

- 确定核心类型 (Meta/Smart/Oix)
- 调用 `clash_version.sh` 获取最新版本
- 下载核心二进制→解压→验证→替换
- 标记需重启

## 9.4 插件更新脚本 `openclash_update.sh`

**触发**: Web UI「更新插件」按钮 /「一键更新」

- 下载 luci-app-openclash IPK/APK
- 预安装测试通过后动态生成安装脚本
- 通过 ubus 服务方式后台安装 (避免 Web 断连)
- 一键更新模式: 先调用 `openclash_core.sh`

## 9.5 GEO 更新脚本 `openclash_geo.sh`

**触发**: Web UI「更新 GEO 数据库」按钮 / Cron

| 参数 | 下载目标 |
|------|----------|
| `ipdb` | Country.mmdb (GeoIP MMDB) |
| `geoip` | geoip.dat |
| `geosite` | geosite.dat |
| `geoasn` | GeoLite2-ASN.mmdb |
| `all` | 以上全部 |

## 9.6 大陆路由更新 `openclash_chnroute.sh`

**触发**: Web UI「更新大陆路由」按钮 / Cron

- 下载中国 IPv4/IPv6 CIDR 列表
- 转换为 nftables set 或 ipset 格式

## 9.7 其他脚本速查

| 脚本 | 触发来源 | 功能 |
|------|----------|------|
| `openclash_debug.sh` | Web UI「生成调试日志」 | 收集完整诊断信息 |
| `openclash_download_dashboard.sh` | Web UI 仪表盘切换 | 下载/切换 Dashboard |
| `openclash_debug_getcon.lua` | 连接诊断 | 获取当前活动连接 |
| `openclash_debug_dns.lua` | DNS 诊断 | 测试 DNS 解析 |
| `openclash_streaming_unlock.lua` | 流媒体测试/看门狗 | 自动选择解锁节点 |
| `openclash_history_get.sh` | 停止服务/看门狗/「关闭所有连接」 | 同步缓存/关闭连接 |
| `openclash_custom_domain_dns.sh` | init.d 启动流程 | 自定义域名 DNS 配置 |
| `yml_change.sh` | init.d 启动流程 | Ruby 修改 YAML (端口/模式/DNS/TUN/认证) |
| `yml_rules_change.sh` | init.d 启动流程 | Ruby 修改 YAML (规则/Provider CDN/URL-Test覆写) |
| `yml_groups_set.sh` | Web UI 保存策略组 | 策略组写入 YAML |
| `yml_proxys_set.sh` | Web UI 保存节点 | 节点/代理集写入 YAML |
| `openclash_sub_parser.lua` | 看门狗 | 解析 base64/vmess/ss 等订阅格式 |
| `openclash_watchdog.sh` | init.d 启动后 | 守护进程: 核心存活监控/流媒体解锁/订阅更新/UPNP + 每60秒检查防火墙规则完整性（规则乱序/TUN路由表丢失自动重载，每周期最多重载3次） |
| `openclash_lgbm.sh` | Web UI 模型更新 | LightGBM 模型下载 |

---

# 第十部分：覆写模块详解

> 覆写模块 (Overwrite Module) 是 OpenClash 的高级自定义功能
> 入口: 运行状态页顶部「覆写模块」按钮（弹出覆写编辑器，与启动/停止开关并列），或菜单 `服务→OpenClash→覆写设置`（独立 CBI 页面）
> UCI Section: `openclash.config_overwrite` (支持多条，按 order 排序)
> 覆写文件存储: `/etc/openclash/overwrite/<名称>` (本地) 或通过 HTTP 远程拉取

## 10.1 覆写模块是什么

> **AI 行为指引**: 当用户询问覆写模块相关问题（如"如何通过覆写添加配置"、"[YAML] 操作符怎么用"、
> "如何覆盖订阅中的 DNS 设置"、"覆写和 LuCI 设置哪个优先级高"），AI 应：
>
> 1. **【铁律】输出必须包含段头**——覆写文件**必须包含至少一个段头**（`[General]`、`[Overwrite]`、`[YAML]` 之一），否则整个文件被跳过、覆写不生效（详见 10.2 节「强制要求」及 `overwrite_file()` 函数按段头解析的逻辑）。
>    **AI 输出任何覆写配置示例时，必须在代码块内以段头作为第一行**，**绝对禁止**输出不含段头的裸 YAML/Shell/INI 内容。
>    即使用户只问「某个字段怎么写」，代码块也必须形如：
>    ```ini
>    [YAML]
>    <具体配置>
>    ```
>    而非仅 `<具体配置>`。若用户反馈覆写不生效，优先排查：①段头是否存在；② `config` 字段是否匹配当前配置文件。
>
> 2. **示例输出规范**：优先使用 `[YAML]` 段格式给出示例（语法清晰、不易出错）；仅当需要动态逻辑（条件判断、循环处理）时才推荐 `[Overwrite]` 段。
>    给出示例前应**先明确用户需求**（追加还是替换？键路径是什么？目标是数组还是哈希？匹配条件？），然后结合 [10.2.3 节操作符](#1023-yaml-段--原始-yaml-注入含操作符)（`!` 强制覆盖 / `+` 数组追加 / `-` 数组删除 / `*` 批量条件更新等）给出精准的、可直接使用的配置片段。禁止给出不含段头的泛泛描述。
>
> 3. **信息获取路径**：本章节未覆盖的细节按以下优先级查阅——
>    - 覆写文件格式/操作符/示例 → 本章节（10.2 格式说明、10.2.3 操作符、10.5 实战示例）
>    - Mihomo YAML 字段含义/用法 → [Mihomo 配置文档](https://wiki.metacubex.one/config/)
>    - 覆写执行机制/排序/脚本逻辑 → [OpenClash 源码](https://github.com/vernesong/OpenClash/tree/dev) 中 `init.d/openclash` 的 `overwrite_file()` 函数和 `/tmp/yaml_overwrite.sh` 生成逻辑
>
> 4. **覆写执行模型（理解即可，回答时按需引用）**：覆写分两阶段执行——
>    `[General]` 段在 `yml_change.sh` **之前**写入 UCI（可影响其行为）；
>    `[Overwrite]` 和 `[YAML]` 段在 `yml_change.sh` / `yml_rules_change.sh` **之后**执行，因此可覆盖这两个脚本的所有输出——包括硬编码项（如 `allow-lan`、`bind-address`、`sniffer.sniff` 等）。
>    LuCI「覆写设置」CBI 页面的选项同样会被 `[Overwrite]`/`[YAML]` 段覆盖。
>    **警告：覆盖硬编码项可能导致 OpenClash 工作异常**（如 `allow-lan: false` 会使局域网设备无法使用代理端口），提醒用户谨慎操作。

**核心机制**: OpenClash 的覆写模块分两个阶段执行（均在 `/etc/init.d/openclash start_service` 流程中）：

**第一阶段 — UCI 预处理**（`overwrite_file()` 函数，在 `yml_change.sh` 之前执行）：
1. 遍历 UCI 中所有 `config_overwrite` 条目（按 `order` 排序）
2. 检查覆写是否匹配当前配置文件（`config` 字段支持 `all` 或指定文件名）
3. 读取 `/etc/openclash/overwrite/<名称>` 文件内容
4. 解析 `[General]` 段 → 将键值对写入 UCI `openclash.@overwrite[0]`（如 `EN_MODE`、`DNS_PORT` 等），供后续 `yml_change.sh` 读取
5. 处理 `DOWNLOAD_FILE` 指令 → 下载外部文件
6. 生成 `/tmp/yaml_overwrite.sh` 脚本（包含 `[Overwrite]` 和 `[YAML]` 段的内容，暂不执行）

**第二阶段 — YAML 覆写**（`/tmp/yaml_overwrite.sh`，在 `yml_change.sh` 和 `yml_rules_change.sh` 之后执行）：
7. 执行 `[Overwrite]` 段的 Shell 命令（可使用 `ruby_*` 函数族修改 YAML）
8. 将 `[YAML]` 段的 YAML 内容深度合并到运行配置

> **执行顺序含义**：`[General]` 段在 `yml_change.sh` 之前生效（因为写入 UCI），因此可以影响 `yml_change.sh` 的行为；`[Overwrite]` 和 `[YAML]` 段在 `yml_change.sh` 和 `yml_rules_change.sh` 之后执行，因此**可以覆盖这两个脚本的所有输出**——包括「插件强制覆盖/禁用的设置」表格中的硬编码项（如 `allow-lan`、`bind-address`、`sniffer.sniff` 等）。⚠️ **覆盖这些硬编码项可能导致功能异常**，请谨慎使用。

**覆写模块能做什么**:
- 给订阅配置**追加/覆盖**任意 Mihomo YAML 字段（如 DNS、Sniffer、TUN、规则等）
- 设置环境变量供 `yml_change.sh` 等后续脚本使用
- 下载外部文件（通过 `DOWNLOAD_FILE` 指令）
- 对未提供 UI 选项的 Mihomo 高级功能进行配置

## 10.2 覆写文件的格式

覆写文件使用 **INI 风格的分段格式**，支持三个段：

```ini
[General]
# 键值对，将作为环境变量导出
# 支持的 key 列表见下方

[Overwrite]
# Shell 命令，可使用 ruby_* 函数族操作 YAML

[YAML]
# 原始 YAML 片段，将合并到运行配置
```

> **⚠️ 强制要求**：覆写文件**必须包含至少一个段头**（`[General]`、`[Overwrite]`、`[YAML]` 之一），否则所有内容将被忽略，覆写模块不会生效。这是因为 `overwrite_file()` 函数（`/etc/init.d/openclash`）按段头解析文件内容——所有标志位 `in_general`/`in_overwrite`/`in_yaml` 初始为 `0`，仅在遇到对应段头时才设为 `1`。段头之前、之后无段头的内容均被跳过。空行和以 `#`/`;` 开头的注释行会被安全忽略，不影响段头解析。

### 10.2.1 `[General]` 段 — 键值对/环境变量

每行格式: `KEY = VALUE`（大小写不敏感，会自动转大写）

**允许的所有 Key** (共 ~85 个，由 `overwrite_file()` 函数中的 `allowed_keys_types` 定义):

| 类别 | Key 示例 | 类型 | 说明 |
|------|----------|------|------|
| 端口 | `DNS_PORT`, `PROXY_PORT`, `TPROXY_PORT`, `HTTP_PORT`, `SOCKS_PORT`, `MIXED_PORT` | int | 覆写端口号 |
| 模式 | `EN_MODE`, `PROXY_MODE`, `STACK_TYPE` | string | 覆写运行/代理模式 |
| DNS | `ENABLE_CUSTOM_DNS`, `ENABLE_RESPECT_RULES`, `APPEND_WAN_DNS`, `APPEND_DEFAULT_DNS` | int_bool | DNS 覆写 |
| Fake-IP | `FAKEIP_RANGE`, `FAKEIP_RANGE6`, `STORE_FAKEIP`, `CUSTOM_FAKEIP_FILTER`, `CUSTOM_FAKEIP_FILTER_MODE` | string/int_bool | Fake-IP 相关 |
| Meta | `ENABLE_TCP_CONCURRENT`, `ENABLE_UNIFIED_DELAY`, `ENABLE_META_SNIFFER`, `ENABLE_META_SNIFFER_PURE_IP`, `ENABLE_GEOIP_DAT` | int_bool | Meta 内核 |
| 流量 | `ROUTER_SELF_PROXY`, `DISABLE_UDP_QUIC`, `SKIP_PROXY_ADDRESS`, `COMMON_PORTS`, `CHINA_IP_ROUTE` | int_bool/int/string | 流量控制 |
| IPv6 | `IPV6_ENABLE`, `IPV6_MODE`, `IPV6_DNS` | int_bool/int | IPv6 |
| GEO | `GEO_AUTO_UPDATE`, `GEOIP_AUTO_UPDATE`, `GEOSITE_AUTO_UPDATE`, `GEOASN_AUTO_UPDATE` | int_bool | GEO 更新 |
| 自定义 | `ENABLE_CUSTOM_CLASH_RULES`, `ENABLE_RULE_PROXY` | int_bool | 规则 |
| Smart | `AUTO_SMART_SWITCH`, `SMART_ENABLE_LGBM`, `SMART_POLICY_PRIORITY` | int_bool/string | Smart 策略 |
| 特殊 | `CONFIG_FILE` | string | 覆写 config_path（切换配置） |
| 特殊 | `AGE_SECRET_KEY`, `AGE_PUBLIC_KEY` | string | Age 加密密钥 |
| 特殊 | `SUB_INFO_URL` | string | 订阅信息 URL |
| 特殊 | `DOWNLOAD_FILE` | string | 下载外部文件（见单独说明） |
| 特殊 | `DA_PASSWORD` | string | Dashboard 密码 |
| 特殊 | `GLOBAL_UA` | string | 全局 User-Agent |
| 特殊 | `RESTART` | bool | 覆写变更后是否重启 |

**类型说明**: `int`=整数, `int_bool`=0/1, `bool`=true/false, `string`=任意字符串

> 这些环境变量在 `yml_change.sh`、`yml_rules_change.sh` 及自定义覆写脚本中可通过 `$KEY_NAME` 直接引用。

### 10.2.2 `[Overwrite]` 段 — Shell 脚本

此段内容直接作为 Shell 命令执行。可用的函数：
- `ruby_read <file> <key_path>` — 读取 YAML 值
- `ruby_cover <file> <key_path> <value>` — 覆盖 YAML 值
- `ruby_merge <file> <key_path> <value>` — 合并 YAML 哈希
- `ruby_delete <file> <key_path>` — 删除 YAML 键
- `ruby_arr_add_file <file> <key_path> <list_file>` — 从文件添加数组元素
- `ruby_uniq <file> <key_path>` — 数组去重
- `ruby_edit <file> <key_path> <value>` — 编辑数组元素
- `uci_get_config <key>` — 读取 UCI 配置（覆写优先）

### 10.2.3 `[YAML]` 段 — 原始 YAML 注入（含操作符）

`[YAML]` 段使用 Ruby 将内容**深度合并**到运行配置文件。支持多种**操作符后缀**实现精细控制：

**操作符速查表**：

| 操作符 | 写法 | 行为 |
|--------|------|------|
| **默认合并** | `key` 或 `<key>` | Hash 递归合并，标量直接覆盖，键不存在则添加 |
| **强制覆盖** | `key!` 或 `<key>!` | 强制替换整个值（不做递归合并） |
| **数组后置追加** | `key+` 或 `<key>+` | 将新元素追加到数组末尾 |
| **数组前置插入** | `+key` 或 `+<key>` | 将新元素插入到数组开头 |
| **数组差集删除** | `key-` 或 `<key>-` | 从数组中删除指定元素；非数组则删除整个键 |
| **批量条件更新** | `key*` 或 `<key>*` | 按 `where` 条件匹配，用 `set` 子句更新（见下） |

`<key>` 语法用于键名含特殊字符或与操作符冲突时。

#### 操作符详解与示例

**1. 默认合并 (`key` / `<key>`)**

Hash 值递归合并，键不存在则添加，标量直接覆盖。
```yaml
dns:
  enable: true           # 修改现有键
  cache-algorithm: lru   # 添加新键
mixed-port: 10802        # 直接覆盖标量
tun:
  enable: true           # 合并 Hash（仅改指定字段，其余保留）
  stack: gvisor
```

**2. 强制覆盖 (`key!` / `<key>!`)**

强制替换整个值，不做递归合并。
```yaml
dns:
  fake-ip-filter!:         # 替换整个 fake-ip-filter 数组
    - '*.lan'
    - 'new.domain.com'
rules!:                    # 强制覆盖整个 rules 数组
  - DOMAIN-SUFFIX,example.com,DIRECT
  - MATCH,PROXY
<dns>!:                    # <> 语法：强制覆盖整个 dns 配置
  enable: false
  nameserver:
    - '114.114.114.114'
```

**3. 数组后置追加 (`key+` / `<key>+`)**

将新元素追加到数组末尾。
```yaml
dns:
  nameserver+:
    - '1.1.1.1'
    - '8.8.8.8'
rules+:
  - DOMAIN-SUFFIX,example.com,REJECT
<nameserver>+:
  - '8.8.8.8'
```

**4. 数组前置插入 (`+key` / `+<key>`)**

将新元素插入到数组开头（优先匹配）。
```yaml
dns:
  +nameserver:
    - '223.5.5.5'
+rules:
  - DOMAIN-SUFFIX,priority.com,DIRECT
+<nameserver>:
  - '119.29.29.29'
```

**5. 数组删除/键删除 (`key-` / `<key>-`)**

从数组中移除指定元素；对非数组删除整个键。值为空(null/~)时删除整个键。
```yaml
dns:
  nameserver-:
    - '8.8.8.8'
    - '8.8.4.4'
rules-:
  - DOMAIN-SUFFIX,old.com,REJECT
  cache-algorithm-:         # 删除整个 cache-algorithm 键
```

**6. 批量条件更新 (`key*` / `<key>*`)**

按 `where` 条件匹配集合元素，用 `set` 子句更新指定字段。

**支持的集合类型**: Hash 值数组 (如 proxy-groups)、字符串数组 (如 rules)
**where 条件格式**: `字段名: 值`，支持正则 `/pattern/`

**set 子句支持的操作符**: 同顶层（默认覆盖、`!`、`+`、`-`）

```yaml
# === 对 proxy-groups (Hash 数组) ===

# 按 type 匹配，替换整个 proxies 列表
proxy-groups*:
  where:
    type: select
  set:
    proxies:
      - 'new-proxy1'
      - 'new-proxy2'

# 按 name 正则匹配，向 proxies 开头插入
proxy-groups*:
  where:
    name: '/^HK/'
  set:
    +proxies:
      - 'hk-new-proxy'

# 按 type 匹配，从 proxies 中移除指定节点
proxy-groups*:
  where:
    type: select
  set:
    proxies-:
      - 'old-proxy1'

# 使用数组包含条件（proxies 须包含指定元素）
proxy-groups*:
  where:
    type: select
    proxies:
      - 'old-proxy1'
  set:
    proxies:
      - 'new-proxy1'

# 修改 url-test 组的 interval
<proxy-groups>*:
  where:
    type: url-test
  set:
    interval: 300

# === 对 proxies (节点数组) ===

# 修改 socks5 节点端口
proxies*:
  where:
    type: socks5
  set:
    port: 1080

# === 对 rules (字符串数组) ===

# 替换匹配的规则
rules*:
  where:
    value: 'DOMAIN-SUFFIX,old.com,REJECT'
  set:
    value: 'DOMAIN-SUFFIX,new.com,DIRECT'

# 正则匹配删除规则（set value 为空/不写）
rules*:
  where:
    value: '/,REJECT$/'
  set:
    value:

# === 对 hosts (Hash 集合) ===

# 更新指定 hosts 键
hosts*:
  where:
    key: '*.mihomo.dev'
  set:
    '*.mihomo.dev': '::1'

# 删除指定 hosts 键
hosts*:
  where:
    key: '*.old.dev'
  set:
    key-:
```

**7. 组合操作**

同一块内可同时使用多个操作符：
```yaml
dns:
  nameserver-:         # 先删除
    - '8.8.8.8'
  +nameserver:         # 再前置插入
    - '223.5.5.5'
  nameserver+:         # 再后置追加
    - '1.0.0.1'
```

### 10.2.4 `DOWNLOAD_FILE` 特殊指令（`[General]` 段）

格式: `DOWNLOAD_FILE = url=..., path=..., cron=..., force=..., ua=..., restart=...`

用于在覆写模块中下载外部文件。字段说明：
- `url` — 下载地址 (必填)
- `path` — 保存路径 (必填)
- `cron` — cron 表达式，0 表示不添加定时任务
- `force` — `true` 强制重新下载
- `ua` — 自定义 User-Agent
- `restart` — `true` 下载后重启核心

## 10.3 覆写模块的两种获取方式

| 类型 | UCI `type` 值 | 说明 |
|------|--------------|------|
| **本地文件** | `file` | 读取 `/etc/openclash/overwrite/<名称>` |
| **远程模块** | `http` | 从 URL 下载到 `/etc/openclash/overwrite/<名称>`，支持 cron 定时更新 |

远程模块可设置 `update_days` 和 `update_hour` 实现定时自动拉取。

## 10.4 覆写与配置文件的匹配

每个覆写条目可指定目标配置文件（`config` 字段，ListValue）:
- `all` — 对所有配置文件生效
- `/etc/openclash/config/xxx.yaml` — 仅对该配置文件生效

## 10.5 实战示例

### 示例1: 强制启用 TUN 模式 + 设置 DNS
```ini
[General]
EN_MODE = fake-ip-tun
STACK_TYPE = mixed
```

### 示例2: 通过 [Overwrite] 段添加自定义代理组
```ini
[Overwrite]
ruby_merge "$CONFIG_FILE" "proxy-groups" '{"name":"手动切换","type":"select","proxies":["DIRECT","Proxy"]}'
```

### 示例3: 通过 [YAML] 段覆写完整 DNS 配置
```ini
[YAML]
dns:
  enable: true
  enhanced-mode: fake-ip
  nameserver:
    - https://doh.pub/dns-query
    - https://dns.alidns.com/dns-query
  fallback:
    - tls://8.8.4.4
    - tls://1.1.1.1
  fallback-filter:
    geoip: true
    geoip-code: CN
```

### 示例4: 通过 [YAML] 段覆写 Sniffer
```ini
[YAML]
sniffer:
  enable: true
  force-dns-mapping: true
  parse-pure-ip: true
  sniff:
    TLS:
      ports: [443, 8443]
    HTTP:
      ports: [80, 8080-8880]
```

### 示例5: 通过 [YAML] 段添加自定义规则
```ini
[YAML]
rules:
  - DOMAIN-SUFFIX,google.com,Proxy
  - DOMAIN-KEYWORD,youtube,Proxy
  - GEOSITE,netflix,NETFLIX
  - GEOIP,CN,DIRECT
  - MATCH,Proxy
```

### 示例6: 通过 [Overwrite] + ruby 函数动态修改
```ini
[Overwrite]
# 追加规则文件
ruby_arr_head_add_file "$CONFIG_FILE" "rules" "/etc/openclash/custom/openclash_custom_rules.list"
# 删除 proxy-providers 中特定的条目
ruby_delete "$CONFIG_FILE" "proxy-providers.低质量节点"
# 修改 DNS nameserver
ruby_cover "$CONFIG_FILE" "dns.nameserver" '[223.5.5.5, 119.29.29.29]'
```

### 示例7: 使用 CONFIG_FILE 切换配置 + 设置 Age 密钥
```ini
[General]
CONFIG_FILE = /etc/openclash/config/my_custom.yaml
AGE_SECRET_KEY = AGE-SECRET-KEY-xxxxxxxxx
```

### 示例8: 下载外部规则文件
```ini
[General]
DOWNLOAD_FILE = url=https://example.com/rules.yaml, path=/etc/openclash/rule_provider/custom_rules.yaml, ua=clash-verge/v2.4.5, cron=0 2 * * *
```

## 10.6 自定义覆写脚本（旧方式，兼容保留）

**文件**: `/etc/openclash/custom/openclash_custom_overwrite.sh`
**执行时机**: 在 `yml_change.sh` 和 `yml_rules_change.sh` 之间执行
**特点**: 可以使用项目提供的 `ruby_*` 函数族

```bash
#!/bin/bash
. /usr/share/openclash/ruby.sh

CFG_FILE=$(uci_get_config "config_path")
if [ -f "$CFG_FILE" ]; then
    ruby_arr_head_add_file "$CFG_FILE" "rules" "/etc/openclash/custom/openclash_custom_rules.list"
fi
```

## 10.7 UCI 覆写条目结构速查

每个 `config_overwrite` 条目的 UCI 字段：

| UCI Key | 类型 | 说明 |
|---------|------|------|
| `name` | string | 唯一标识（对应 `/etc/openclash/overwrite/<name>` 文件名） |
| `enabled` | bool | 是否启用 |
| `type` | string | `file` 或 `http` |
| `url` | string | HTTP 类型时的下载地址 |
| `config` | ListValue | 目标配置文件（`all` 或具体路径） |
| `param` | string | 额外键值对（`KEY1=VALUE1;KEY2=VALUE2` 格式） |
| `order` | int | 排序权重（越大越先执行） |
| `update_days` | string | HTTP 类型的 cron 天 (0-7, *) |
| `update_hour` | string | HTTP 类型的 cron 小时 (0-23, *) |

---

# 第十一部分：status.htm 前端 JS 交互速查

> 运行状态页面 (`/cgi-bin/luci/admin/services/openclash/client`) 的前端逻辑

| UI 元素 | JS 函数 | API 调用 |
|---------|---------|----------|
| 插件开关 | `togglePlugin(this)` | `/action` POST `{action: "start"/"stop"}` |
| 重启按钮 | `restartCore()` | `/action` POST |
| 覆写模块按钮 | `editOverwrite()` | 在运行状态页弹出覆写编辑模态框 |
| Compat/TUN/Mix 单选 | `switch_run_mode(val)` | `/switch_run_mode` POST |
| Rule/Global/Direct 单选 | `switch_rule_mode(val)` | `/switch_rule_mode` POST |
| Area Bypass 单选 | `switch_oc_setting_oversea(val)` | `/switch_oc_setting` POST `{setting: "oversea"}` |
| Sniffer 单选 | `switch_meta_sniffer(val)` | `/switch_oc_setting` POST `{setting: "meta_sniffer"}` |
| DNS Proxy 单选 | `switch_respect_rules(val)` | `/switch_oc_setting` POST `{setting: "respect_rules"}` |
| Stream Unlock 单选 | `switch_stream_unlock(val)` | `/switch_oc_setting` POST `{setting: "stream_unlock"}` |
| 切换配置 | `switchConfig()` | `/switch_config` POST |
| 更新配置 | `updateConfig()` | `/update_config` POST |
| 编辑配置 | `editConfig()` | 弹出 config_edit.htm 模态框 |
| 编辑订阅 | `editSubscribe()` | 跳转 config-subscribe-edit |
| 上传配置 | `uploadConfig()` | config_upload.htm 模态框 |
| 复制面板地址 | `copyAddress()` | 复制到剪贴板 |
| 复制密钥 | `copySecret()` | 复制到剪贴板 |
| 获取 PAC | `generatePacConfig()` | `/generate_pac` POST |
| 仪表盘按钮 | 新窗口打开 | `status.htm` JS 按本地/公网/默认 3 种场景构造 URL，4 个仪表盘各有独立子路径 |
| 关闭所有连接 | `closeAllConnections()` | `/close_all_connection` POST |
| 重载防火墙 | `reloadFirewall()` | `/reload_firewall` POST |
| 清空 DNS 缓存 | `flushDNSCache()` | `/flush_dns_cache` POST |
| 一键更新 | `oneKeyUpdate()` | `/one_key_update` POST |
| 统计轮询 | `StateManager` 自动轮询 | `/toolbar_show` + `/status` |

**初始加载**: 页面加载时同时请求 `/status`、`/toolbar_show`、`/config_file_list`、`/oc_settings`、`/dashboard_type`、`/rule_mode`、`/proxy_info`、`/myip_check`、`/announcement`

---

# 超出本文档范围的查询

> **强制规则：当用户询问本文档未覆盖的 Mihomo/OpenClash 配置或实现细节时，禁止自行猜测或编造回答。
> AI 必须主动查询外部资源获取准确信息后回复用户。**

本文档仅覆盖 OpenClash LuCI 插件 UI 中可直接配置的选项及其实现。当遇到本文档未覆盖的问题时，AI 必须**主动**使用以下资源查询答案，而非让用户自己去查阅文档：

**AI 必须主动查询的外部资源**：

| 优先级 | 资源 | 查询方式 | 适用场景 |
|--------|------|----------|----------|
| 1 | **Mihomo Wiki** `https://wiki.metacubex.one/config/` | 使用 `fetch_webpage` 抓取相关页面 | Mihomo YAML 配置字段的含义、可选值、用法 |
| 2 | **Meta-Docs 仓库** `github.com/MetaCubeX/Meta-Docs` | 使用 `github_text_search` 搜索 `docs/config/` 目录 | 需要精确的字段类型、默认值、完整配置示例 |
| 3 | **OpenClash Issues** `https://github.com/vernesong/OpenClash/issues` | 使用 `fetch_webpage` 打开 Issue 搜索页面或具体 Issue 页面 | 插件侧功能异常/报错（配置/订阅/防火墙/UI等），搜索已知问题和社区方案（优先作者 vernesong 回复和高赞回答） |
| 4 | **Mihomo Issues** `https://github.com/MetaCubeX/mihomo/issues` | 使用 `fetch_webpage` 打开 Issue 搜索页面或具体 Issue 页面 | 内核侧功能异常/报错（代理协议/TUN/DNS解析/规则引擎等），搜索已知问题和社区方案 |
| 5 | **OpenClash 源码** `github.com/vernesong/OpenClash/tree/dev` | 使用 `github_text_search` 搜索对应脚本/函数 | 需要了解插件侧的实现逻辑、UCI 到 YAML 的转换细节 |
| 6 | **Mihomo 核心源码** `github.com/MetaCubeX/mihomo/tree/Alpha` | 使用 `github_text_search` 搜索核心代码 | 代理协议实现、规则引擎、DNS 解析、TUN 栈等核心底层逻辑 |
| 7 | **Smart 核心源码** `github.com/vernesong/mihomo/tree/Alpha` | 使用 `github_text_search` 搜索核心代码 | Smart 策略、LightGBM 模型的底层实现 |

**具体触发条件**（满足任一即主动查询）：
- 用户询问的配置字段在本文档任何章节中均未出现
- 用户询问特定代理协议的详细参数（Hysteria2/TUIC/WireGuard/SSH/MASQUE 等的完整 TLS/传输层选项）
- 用户询问 `experimental`、`tunnel`、`sub-rule` 等插件 UI 中无直接对应选项的 Mihomo 顶级配置段
- 用户需要编写超出覆写模块 8.2 节示例范围的自定义脚本或 YAML 配置
- 用户询问 Mihomo 最新版本引入的新特性（本文档基于 Mihomo v1.19.x）
- 用户询问 OpenClash 插件本身的开发、编译、打包相关问题
- 用户询问本文档各选项中「实现细节」的更深层逻辑

**AI 工作流程**：
1. 确认问题超出本文档覆盖范围
2. 根据问题类型选择对应的外部资源
3. **优先搜索 Issues**：如果用户遇到的是功能异常/报错类问题（而非配置字段查询），应先搜索 Issues 查找类似问题。根据问题类型选择：插件侧（配置/订阅/防火墙/UI）→ [OpenClash Issues](https://github.com/vernesong/OpenClash/issues)；内核侧（代理协议/TUN/DNS/规则引擎）→ [Mihomo Issues](https://github.com/MetaCubeX/mihomo/issues)。读取 Issue 时重点关注：① 维护者的诊断命令和结论；② 👍 反应数高的社区回复；③ Issue 最终是否被关闭及关闭原因（`completed`=已修复，`not planned`=不在计划内）
4. **主动查询**：使用 `fetch_webpage` 抓取 Mihomo Wiki 页面，或使用 `github_text_search` 搜索 Meta-Docs/OpenClash/Mihomo 核心/Smart 核心源码
5. 将查询到的信息**翻译、整理**后告知用户，而非直接丢链接
6. 在回复末尾注明信息来源（如「以上信息来自 OpenClash Issues #xxx / Mihomo Wiki」），让用户知道信息的权威来源
