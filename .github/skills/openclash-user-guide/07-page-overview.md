## 运行状态页面 (Overviews / client)

> **用途**: 运行状态页面各卡片/按钮的功能与后端操作，含模式切换、仪表盘、IP 检测与 oixCloud（§7.1–7.12）。

> **AI 行为指引**: 当用户询问「运行状态页的某个按钮/卡片是干什么的」「如何切换运行/代理模式」「仪表盘入口怎么访问」「IP 检测/oixCloud 怎么用」时，AI 应结合本文件各小节（§7.1–7.12）说明每个控件的后端操作与生效方式，并给出 LuCI 操作路径。涉及 API 端点细节时参考 `15-api.md`。

> LuCI 路径: `服务` → `OpenClash` → `运行状态`
> 数据来源: 前端 JS 同时请求多个后端端点：`/status` (运行状态、仪表盘设置)、`/toolbar_show` (流量统计)、`/update` (本机配置与已装版本)、`/last_version` (远程最新版本)、`/oc_settings` (快捷设置)、`/rule_mode` (代理模式)、`/config_file_list` (配置文件列表) 等。**版本信息拆分为两个端点**：`/update` (action_update) 返回本机配置（corever/release_branch/smart_enable 等）与已装版本（coremetacv/opcv），**不含远程最新**；远程最新版本 `corelv`/`oplv` 由独立 `/last_version` 端点 (action_last_version) 返回（status 页「新版本可用」红点据此显示），均非 `/status` 端点。`/status` (action_status) 聚合返回：运行状态（`clash`/`run_mode`/`rule_mode`/`meta_sniffer`/`respect_rules`/`oversea`/`stream_unlock`）、仪表盘信息（`cn_port`/`daip`/`dase`/`db_foward_port`/`db_foward_domain`/`db_forward_ssl`）、仪表盘可用性（`yacd`/`dashboard`/`metacubexd`/`zashboard`）、核心类型 `core_type`、代理信息（`mixed_port`/`auth_user`/`auth_pass`），**不含任何版本号**。

### 7.1 核心控制卡片

| 元素 | 功能 | 后端操作 |
|------|------|----------|
| **启动/停止开关** | 切换核心运行状态 | 调用 `action_oc_action` → `/etc/init.d/openclash start/stop` |
| **重启按钮** | 重启核心 | 调用 `/etc/init.d/openclash restart` |
| **覆写模块按钮** | 在运行状态页弹出覆写编辑器（与菜单「服务→OpenClash→覆写设置」独立） | 调用 `editOverwrite()` → 在运行状态页弹出覆写编辑模态框 |
| **插件/核心版本** | 显示当前版本号 + 更新红点 | 已装版本: 核心执行 `/etc/openclash/core/clash_meta -v` 解析输出、插件读取 opkg/apk 包数据库，经 `/update` 端点展示; 远程最新: Lua `fetch_version_history` 拉取并缓存（内核 `/tmp/clash_last_version` / 插件 `/tmp/openclash_last_version`，Lua 侧另有 `/tmp/openclash_version_history_<branch>.json` JSON 缓存），经独立 `/last_version` 端点 (action_last_version) 获取并据此显示「新版本可用」红点，均非 `/status` 端点 |
| **主题切换** | Light(太阳)/Dark(月亮)/Auto(自动) 三档切换 | 前端 CSS 变量 + localStorage |
| **公告横幅** | 滚动显示项目公告 (24h 缓存) | `/announcement` 端点 |
| **社交链接** | Wiki / Tutorials / Star / Telegram / Sponsor / Mihomo 图标 | 外部链接 `window.open()` |
| **开发者头像** | 12 位贡献者头像 + 末尾「More」占位（共 13 格，悬停显示名称） | 来自 GitHub 头像 URL |

### 7.2 运行模式卡片 (Running Mode)

| 模式 | UCI `en_mode` 值 | 说明 |
|------|-----------------|------|
| **兼容 (Compat)** | `redir-host` / `fake-ip` | 非 TUN 模式：TCP REDIRECT + UDP TPROXY |
| **TUN 模式** | `redir-host-tun` / `fake-ip-tun` | 使用 TUN 虚拟网卡接管所有流量 |
| **混合 (Mix)** | `redir-host-mix` / `fake-ip-mix` | TUN + Redirect 混合，TCP 走 system 栈、UDP 走 gvisor 栈 |

> 切换触发: `action_switch_run_mode` → 修改 UCI `en_mode`，若运行中则自动重启

### 7.3 代理模式卡片 (Proxy Mode)

| 模式 | Mihomo `mode` 值 | 效果 |
|------|-----------------|------|
| **策略代理 (Rule)** | `rule` | 按 YAML 中 `rules:` 规则集合分流 |
| **全局代理 (Global)** | `global` | 所有流量走 GLOBAL 策略组所选代理 |
| **全局直连 (Direct)** | `direct` | 所有流量直连，不经过任何代理 |

> 切换触发: `action_switch_rule_mode` → PATCH Mihomo API `/configs` 的 `mode` 字段，同时更新 UCI `proxy_mode`

### 7.4 快捷设置网格

| 设置项 | 功能 | UCI 选项 | 触发函数 |
|--------|------|----------|----------|
| **地区绕行 (Area Bypass)** | 切换中国 IP/海外绕行 | `china_ip_route` (0/1/2) | `action_switch_oc_setting` → 修改 UCI + 重启 |
| **域名嗅探 (Sniffer)** | 是否启用 Mihomo 域名嗅探 | `enable_meta_sniffer` | `action_switch_oc_setting` → 动态修改运行时 YAML `sniffer.enable` |
| **DNS 尊重规则 (DNS Proxy)** | DNS 查询是否遵守路由规则 | `enable_respect_rules` | `action_switch_oc_setting` → 动态修改 YAML `dns.respect-rules` |
| **流媒体解锁 (Stream Unlock)** | 一键启用流媒体解锁 | `stream_auto_select` | `action_switch_oc_setting` → 设置 `stream_auto_select=1` 及 Netflix/Disney/HBO 默认参数 |

### 7.5 配置文件卡片

| 操作 | 功能 | 后端路由 |
|------|------|----------|
| **配置文件选择器** | 下拉切换当前使用的 YAML 配置 | `action_switch_config` → 更新 `config_path` + 自动重启 |
| **切换 (Switch)** | 切换到选中的配置 | 同上 |
| **更新配置** | 重新下载订阅并更新 | `action_update_config` → 调用 `openclash.sh` |
| **编辑 (Edit)** | 在线编辑 YAML 配置文件 | 弹出 `config_edit` 模态框 (基于 CodeMirror，支持原始/运行时视图切换、合并视图对比、覆写模块列表栏) |
| **编辑订阅** | 修改该配置的订阅参数 | 跳转到 `config-subscribe-edit` |
| **上传** | 上传新的 YAML 配置文件 | 弹出 `config_upload` 模态框 (支持文件上传 + 订阅链接两个标签页) |
| **刷新订阅按钮** | 手动刷新当前配置的订阅信息 | `/sub_info_get` 端点 |
| **指定 URL 按钮** | 设置订阅信息查询 URL | `/set_subinfo_url` 端点 |
| **订阅进度条** | 显示订阅流量使用情况 (已用/总量/百分比) | `/sub_info_get` 自动轮询 |

### 7.6 控制面板卡片

显示当前 Dashboard 访问地址及 Secret 密码。对应 UCI:
- `cn_port` — API 端口 (默认 9090)，对应 Mihomo `external-controller`
- `dashboard_password` — API 密钥，对应 Mihomo `secret`
- `dashboard_forward_domain` / `dashboard_forward_port` / `dashboard_forward_ssl` — 公网访问设置（`dashboard_forward_domain` 可填域名或 IP/IPv6，端口可留空默认 443/80）
- `dashboard_custom_url` / `dashboard_custom_clash_compatible` — 自定义外部仪表盘地址（详见 `09-settings-dns-ac-ipv6.md` §9.4）
- 提供 **复制 IP** 和 **复制密钥** 按钮；若设置了 `dashboard_custom_url`，**复制地址**优先复制该自定义 URL

### 7.7 混合代理卡片

显示 SOCKS5/HTTP 代理地址，可复制或生成 PAC 文件：
- `mixed_port` (默认 7893), `http_port` (7890), `socks_port` (7891)
- 用户认证: `authentication` TypedSection 中的 `username`/`password`，对应 Mihomo `authentication` 配置
- 提供 **复制代理地址**、**复制认证信息**、**生成 PAC 配置** 按钮

### 7.8 仪表盘入口 (Control Panel)

4 种可选仪表盘：**Dashboard** (Yacd)、**Yacd**、**Metacubexd**、**Zashboard**
- 对应 Mihomo `external-ui` 配置
- 切换触发: `action_switch_dashboard` → `openclash_download_dashboard.sh`
- 默认仪表盘: UCI `default_dashboard`
- **前端访问地址**: 由 `status.htm` 调用 `common.js` 的 `ocGetDashboardBaseURL` 等函数，根据「浏览器 hostname 是否匹配 LAN IP」「是否配置公网地址 `dashboard_forward_domain`/`dashboard_forward_port`/`dashboard_forward_ssl`」等场景构造 `http[s]://<host>:<port>/ui/<dashboard>/`；公网地址支持域名/IP/IPv6 及内嵌端口。若配置了 `dashboard_custom_url`，额外显示 **External Dashboard** 按钮并优先用于复制地址。完整逻辑见 `09-settings-dns-ac-ipv6.md` §9.4 外部控制标签页 → 实现细节。
- 各仪表盘子路径：`/ui/dashboard/`、`/ui/yacd/`、`/ui/metacubexd/`、`/ui/zashboard/`

### 7.9 快捷操作按钮 (Quick Action)

| 操作 | 功能 | 后端 |
|------|------|------|
| **关闭链接 (Close Connect)** | 断开所有代理连接 | `openclash_history_get.sh 'close_all_conection'` |
| **重置防火墙 (Reload Firewall)** | 重新应用 iptables/nftables 规则 | `/etc/init.d/openclash reload 'manual'` |
| **清空 DNS 缓存** | 刷新 Fake-IP 和 DNS 缓存 | POST `/cache/fakeip/flush` + `/cache/dns/flush` |
| **检查更新 (Check Update)** | 检查并更新插件 + 内核（订阅靠「配置订阅」、GEO 靠 GEO 更新入口） | `openclash_update.sh 'one_key_update'` |

### 7.10 统计信息 / 访问控制

底部数据区有三个视图，由标题栏右侧的三个图标切换（`stats-view-toggle`），**默认是访问控制**；区域标题随视图显示「访问控制」或「运行数据」：

| 图标 | 视图 | 说明 |
|------|------|------|
| 用户 | 访问控制 | 列出局域网设备，逐台设置代理/直连（默认视图） |
| 宫格 | 卡片 | 8 项实时统计指标 |
| 曲线 | 图表 | 用 `chart.umd.min.js` 绘制单个指标的实时曲线 |

**访问控制视图**（后端 `clients_ac` / `clients_stats` / `clients_set` / `clients_meta` / `clients_dns_switch`，见 `15-api.md` §15.1.1）：

| 控件 | 作用 | 后端操作 |
|------|------|----------|
| 全部代理 / 全部直连 | 设置新设备的默认策略 | `lan_ac_mode` 置 0/1 并清空对应例外列表，随后重建防火墙规则 |
| 重新扫描 | 重新读取邻居表与 DHCP 租约 | `clients_ac` |
| 排序 | 按设备名 / 分流 / 连接数 / 上行 / 下行排序，或恢复默认顺序 | 前端本地排序 |
| 设备行：代理 / 直连 | 把设备加入当前默认策略的例外列表（IP + MAC） | `clients_set` + `openclash_client_ac.sh` 热更新 ipset/nft 集合，不重建防火墙；仅对新连接生效 |
| 设备行：连接 / 上传 / 下行 | 该设备的连接数与实时速率（内核 conntrack 记账，含直连流量） | `clients_stats` 输出 conntrack 原文，浏览器解析与聚合 |
| 设备名（点击） | 自定义名称与图标 | `clients_meta`（保存到 `/etc/openclash/history/clients.json`） |
| 离线标签 | 邻居表中无法确认的设备显示为离线 | 后台 ping 结果写回内核邻居表，随下一次轮询读取 |

> 设备加入网络后自动出现；速率每 2 秒刷新，无流量时降为 5 秒。逐设备统计依赖 `nf_conntrack_acct=1`（`start_run_core()` 写入）。
>
> 内核未启动时上述分流仍可编辑：写入的是 `lan_ac_*` UCI 列表，下次启动由 `start_run_core()` 生成集合并生效。

**卡片视图的 8 项指标**（通过 WebSocket 与 XHR 轮询更新，数据源见 `15-api.md` §15.1.1）：

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

### 7.11 IP 检测页 (IP Address / 访问检查)

**IP 地址部分 (IP Address)**：
- 并行查询 4 个 IP 源：PConline（whois.pconline.com.cn）、IPIP.NET、IP.SB、IPIFY，每个显示 IP 地址 + 地理信息
- 隐私切换按钮（眼睛图标）：点击后用 `***.***.***.***` 隐藏所有 IP 显示（状态持久化到 localStorage）

**访问检测部分 (Access Check)**：
- 两种检测模式：路由器模式（后端 XHR 代理检测）和浏览器模式（前端 fetch 直接检测），通过模式切换图标切换
- 4 个网站可达性检测：**Baidu Search** (百度搜索)、**NetEase Music** (网易云音乐)、GitHub、YouTube，各显示 HTTP 状态码和加载延迟（ms）
- 刷新按钮：重新执行所有 IP 查询和 HTTP 检测

**轮询间隔**: HTTP 检测 5-20 秒，IP 检测 15-40 秒。

### 7.12 oixCloud 面板 (oixCloud)

仅在设置了 `oix_token` 且 `oix_show_info_page` 为 `1` 时显示，展示 oixCloud 订阅服务信息：

- **Logo + 标语**（随机变化）
- **公告横幅**（60 秒后自动消失）
- **计划信息**：计划类型、到期时间、账户余额、推广余额、积分
- **流量统计**：今日已用、计划已用、剩余流量、总流量
- **签到按钮**：每日签到获取流量
- **底部链接**：「Powered by oixcloud.com」

> 登录入口：在「插件设置 → oixCloud」标签页中通过 Login Account 按钮登录。

---
