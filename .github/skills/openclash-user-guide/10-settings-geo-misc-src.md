## 插件设置：GEO、其他与来源流量控制

> **用途**: 插件设置页的 GEO 订阅、其他（定时重启/版本更新/开发者/oixCloud）与来源流量控制（§10.1–10.3）。

### 10.1 GEO 数据库订阅 / 大陆白名单订阅标签页

#### 10.1.1 GEO 数据库订阅 (GEO Update / geo_update)

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

#### 10.1.2 大陆白名单订阅 (Chnroute Update / chnr_update)

| 选项 | UCI Key | 默认 | 说明 |
|------|---------|------|------|
| 自动更新 (Auto Update) | `chnr_auto_update` | 0 | 启用定时更新大陆 IP 路由表 |
| 更新时间/每周 (Update Time (Every Week)) | `chnr_update_week_time` | `1`(周一) | `*`=每天, `1`=周一, …, `0`=周日 |
| 更新时间/每天 (Update time (every day)) | `chnr_update_day_time` | `0`(0:00) | `0`-`23`，每小时一个选项 |
| 大陆 IP 段更新 URL (Custom Chnroute Lists URL) | `chnr_custom_url` | `https://ispip.clang.cn/all_cn.txt` | 中国 IPv4 CIDR 列表下载地址 |
| 大陆 IPv6 段更新 URL (Custom Chnroute6 Lists URL) | `chnr6_custom_url` | `https://ispip.clang.cn/all_cn_ipv6.txt` | 中国 IPv6 CIDR 列表下载地址 |

**更新脚本**: `openclash_chnroute.sh`

---

### 10.2 其他标签页

#### 10.2.1 定时重启 (Auto Restart / auto_restart)

此标签页用于设置 OpenClash 定时自动重启。

| 选项 | UCI Key | 类型 | 默认 | 说明 |
|------|---------|------|------|------|
| **定时重启 (Auto Restart)** | `auto_restart` | Flag | 0 | `0`=关闭, `1`=开启。开启后将在指定时间自动重启 OpenClash 服务 |
| **重启时间/每周 (Restart Time (Every Week))** | `auto_restart_week_time` | ListValue | `1`(周一) | `*`=每天 (Every Day), `1`=周一 (Every Monday), `2`=周二 (Every Tuesday), `3`=周三 (Every Wednesday), `4`=周四 (Every Thursday), `5`=周五 (Every Friday), `6`=周六 (Every Saturday), `0`=周日 (Every Sunday) |
| **重启时间/每天 (Restart time (every day))** | `auto_restart_day_time` | ListValue | `0`(0:00) | `0`-`23`，每小时一个选项 |

- **实现细节**: `add_cron()` 在 `/etc/crontabs/root` 中添加 `/etc/init.d/openclash restart` 的 cron 条目，按用户选择的时间和星期执行。

#### 10.2.2 版本更新 (Version Update / version_update)

此标签页内嵌「检查更新」面板（update 模板的 version_tab 模式），以 **CDN 地址列表** 为核心，提供核心/插件版本选择、下载和更新操作。页面加载时通过 `/update`（action_update，本机配置与已装版本）、`/version_history`（版本历史）、`/addr_info`（CDN 地址列表）API 动态填充。远程最新版本（corelv/oplv，status 页红点用）由独立 `/last_version` 端点提供，本面板不使用。

**顶部配置区（4 列，修改后自动保存）**:

| 选项 | UCI Key | 类型 | 默认 | 说明 |
|------|---------|------|------|------|
| **处理器架构 (CPU Arch)** | —（只读展示） | 文本 | — | 当前设备 CPU 架构，来自后端 `coremodel`（优先读 `/etc/openwrt_release` 的 DISTRIB_ARCH，opkg/apk 包数据库 libc 架构兜底），仅展示不可选 |
| **编译版本 (Compiled Version)** | `core_version` | Select | `0`(未设置) | 选择与 CPU 匹配的编译版本：`linux-amd64-v1/v2/v3`(x86-64)、`linux-arm64`(armv8)、`linux-armv7`、`linux-mips64` 等 ~18 种架构。**未选择（0/空）时内核无法下载**，点击会提示 "No Compiled Version Selected" |
| **更新分支 (Release Branch)** | `release_branch` | Select | `master` | `master`(稳定版) / `dev`(开发版)，决定插件/内核的下载分支 |
| **Smart 内核 (Smart Core)** | `smart_enable` | Select | `0` | `0`=禁用(使用 Meta 内核) / `1`=启用(使用 Smart 内核)，决定内核下载的 meta/smart 子路径 |

**版本卡片（Installed / Select Version）**:

| 要素 | 显示内容 | 说明 |
|------|---------|------|
| **Installed（插件）** | 已安装插件版本 | 只读，从 opkg/apk 包数据库读取（`opcv`） |
| **Select Version（插件）** | 插件版本下拉 | 来自 `/version_history`（package 分支的 CI commit），选项值为对应 commit 的 sha，`Latest`=最新版 |
| **Installed（内核）** | 已安装内核版本 | 只读，执行 `clash_meta -v` 获取（`coremetacv`） |
| **Select Version（内核）** | 内核版本下拉 | 来自 `/version_history`（core 分支的 CI commit），`Latest`=最新版 |

**hint 提示区**：默认显示随机提示（自动轮换）/ 操作错误提示 / 更新过程中的**流式日志**——点击更新后直接在提示区显示 `startlog` 日志（剥离时间戳，`[Info]`/`[Warning]`/`[Error]` 着色，固定高度滚动）。

**CDN 地址列表**（Address / Latency / Plugin / Core 四列）:

- 预设 CDN：`raw.githubusercontent.com`（RAW 直连）、`fastly.jsdelivr.net`、`testingcf.jsdelivr.net`、`cdn.jsdelivr.net`；也可在底部「Custom Your CDN URL」添加自定义 CDN（如 `https://ghfast.top/`，添加后只拉取新增 CDN）
- 每行 Latency 列显示测速延迟（`xxx ms`，按快/中/慢着色）或「Access Timed Out / Access Denied」；Plugin/Core 列显示该 CDN 获取到的插件/内核版本号
- **点击版本号链接** = 只安装该组件（插件→`one_key_update?update_type=plugin`，内核→`core_download`）；**点击右侧下载图标按钮** = 直接下载对应 .ipk/.apk 或 .tar.gz
- **点击行其他区域** = 一键更新插件 + 内核，根据两个 Select Version 下拉决定更新到历史版本还是 Latest
- 更新后面板保持打开，日志在 hint 区流式显示

**底部操作区**:

| 操作 | 功能 |
|------|------|
| **备份 (Backup File)** | 先选备份范围下拉（Backup File 完整 / Backup Exclude Cores 排除内核 / Backup Core 仅内核 / Backup Config 仅配置 / Backup Rule Provider 仅规则提供者 / Backup Proxy Provider 仅代理提供者），再点按钮下载备份 |
| **还原默认 (Restore Default)** | 恢复 OpenClash 为默认出厂配置（确认后跳回设置页） |
| **删除内核 (Remove Core)** | 删除所有核心二进制文件（红色危险按钮） |

- **实现细节**: 
  - 所有配置修改（编译版本/分支/Smart）通过 `/save_corever_branch` API 即时保存到 UCI。
  - 内核下载：`core_download` 路由调用 `openclash_core.sh`，前端始终传入完整下载 URL（`download_url`）。文件名 `clash-{arch}.tar.gz`（arch 即 `core_version`，已带 `linux-` 前缀）；oix 内核为 `mihomo-{arch}-{version}.gz`（走 github release / dl.dler.io）。
  - 插件下载：`openclash_update.sh`，文件名 `luci-app-openclash_{ver}_all.ipk`（opkg）或 `luci-app-openclash-{ver}.apk`（apk）。
  - **下载 URL 结构**：`package`/`core` 是仓库**分支**（非目录）。Latest（无历史 sha）：`package/{branch}/luci-app-openclash_{ver}_all.ipk`、`core/{branch}/{meta|smart}/clash-{arch}.tar.gz`（把分支名作为 ref 段）；选择历史版本（带 sha，为对应分支的 CI commit）：`{sha}/{branch}/luci-app-openclash_{ver}_all.ipk`、`{sha}/{branch}/{meta|smart}/clash-{arch}.tar.gz`。jsdelivr CDN 前缀为 `gh/vernesong/OpenClash@{ref}/...`，自定义 CDN 前缀直接拼接 raw URL。
  - **下载失败不会触发 OpenClash 重启**（`openclash_core.sh` 仅在内核真正更新成功后才置重启标志）。
  - 插件更新通过 ubus 后台安装以避免 Web 界面断连。

#### 10.2.3 开发者选项 (Developer Settings / developer)
- **自定义防火墙规则** (`firewall_custom`): 在 LuCI 的「开发者设置」标签页中直接编辑的文本框，内容保存到 `/etc/openclash/custom/openclash_custom_firewall_rules.sh`。该脚本**不需要定义任何函数**——它是一个命令式 Shell 脚本，在所有 OpenClash 内置防火墙规则添加完毕后被直接执行（`chmod +x` 后运行）。可以在脚本中直接写 `iptables -I ...` 或 `nft add rule ...` 命令来追加自定义防火墙规则。
- **实现细节**: `set_firewall()` 函数在所有内置的 REDIRECT/TPROXY/TUN/IPv6/访问控制规则建立完毕后，检查此文件是否存在，若存在则 `chmod +x` 并执行。由于它在所有内置规则之后运行，自定义规则可以引用 OpenClash 已创建的 nftables 链和 set。每次 OpenClash 启动或防火墙重载时都会重新执行此脚本。

#### 10.2.4 内核测试 (Core Test / debug)

此标签页提供二种独立的诊断工具，位于「内核测试」标签页：

| 工具 | 功能 | 触发方式 | 后端路由 |
|------|------|---------|----------|
| **连接测试 (Connection Test)** | 测试指定域名是否可达 | 输入域名 + 点击「Click to Test」(点击测试) 按钮 | `/diag_connection` |
| **DNS 测试 (DNS Test)** | 测试 DNS 解析结果 | 输入域名 + 点击「Click to Test」(点击测试) 按钮 | `/diag_dns` |

**连接测试实现细节**: 前端先尝试 `Image` 加载 `https://{domain}/favicon.ico` 作为快速预检，若失败则回退到后端 `/diag_connection` 调用。

#### 10.2.5 oixCloud (oixcloud)
- 第三方云服务，需账号密码登录
- `oix_email` / `oix_passwd` → `oix_login` 获取 token
- `oix_checkin` — 自动签到 (需 token)
- 登录后自动获取 Oix 专属核心和订阅

---

### 10.3 来源流量访问控制 (Source Traffic Bypass / lan_ac_traffic)

> **页面位置**：插件设置页面底部（不属于任何标签页，以独立的 TypedSection 形式存在）
> **生效路径**：通过 `init.d/openclash` 的 `firewall_lan_ac_traffic()` 函数在代理链 **position 0** 插入规则，
> 优先级高于所有其他代理规则。配置通过 `config_foreach firewall_lan_ac_traffic "lan_ac_traffic"` 遍历执行。
>
> **AI 行为指引**：当用户询问「如何让某个接口（如 WireGuard/Docker 网桥）的流量完全绕过内核」、
> 「如何按用户 UID 绕过代理」、「如何精细控制特定来源流量」时，AI 应告知用户使用此功能，
> 并结合下方字段表和防火墙逻辑给出具体配置方案。涉及底层实现时查阅
> [OpenClash 源码](https://github.com/vernesong/OpenClash/tree/dev) 中
> `init.d/openclash` 的 `firewall_lan_ac_traffic()` 函数。

#### 10.3.1 lan_ac_traffic TypedSection

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

#### 10.3.2 防火墙工作逻辑（基于 `init.d/openclash` → `firewall_lan_ac_traffic()` 源码）

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
