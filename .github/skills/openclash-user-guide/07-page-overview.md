## 运行状态页面 (Overviews / client)

> **用途**: 运行状态页各卡片/按钮的功能与后端操作（§7.1–7.12）。
> **LuCI 路径**: 服务 → OpenClash → 运行状态
> **端点细节**: 见 `15-api.md`

前端并行请求多个端点：

| 端点 | 返回 |
|------|------|
| `/status`（action_status） | 运行状态（`clash`/`run_mode`/`rule_mode`/`meta_sniffer`/`respect_rules`/`oversea`/`stream_unlock`）、仪表盘信息（`cn_port`/`daip`/`dase`/`db_foward_port`/`db_foward_domain`/`db_forward_ssl`）、仪表盘可用性（`yacd`/`dashboard`/`metacubexd`/`zashboard`）、`core_type`、代理信息（`mixed_port`/`auth_user`/`auth_pass`）。**不含版本号** |
| `/update`（action_update） | 本机配置（`corever`/`release_branch`/`smart_enable`）与已装版本（`coremetacv`/`opcv`）。**不含远程最新** |
| `/last_version`（action_last_version） | 远程最新 `corelv`/`oplv`（「新版本可用」红点依据） |
| `/toolbar_show` / `/oc_settings` / `/rule_mode` / `/config_file_list` | 流量统计 / 快捷设置 / 代理模式 / 配置列表 |

### 7.1 核心控制卡片

| 元素 | 功能 | 后端 |
|------|------|------|
| 启动/停止开关 | 切换核心运行状态 | `action_oc_action` → `/etc/init.d/openclash start\|stop` |
| 重启按钮 | 重启核心 | `/etc/init.d/openclash restart` |
| 覆写模块按钮 | 页内弹出覆写编辑器（与菜单「覆写设置」页独立） | `editOverwrite()` 模态框 |
| 插件/核心版本 | 显示版本号 + 更新红点 | 已装：核心 `clash_meta -v`、插件读 opkg/apk 数据库，经 `/update`；远程最新：Lua `fetch_version_history` 缓存（`/tmp/clash_last_version`、`/tmp/openclash_last_version`、`/tmp/openclash_version_history_<branch>.json`），经 `/last_version` |
| 主题切换 | Light / Dark / Auto | 前端 CSS 变量 + localStorage |
| 公告横幅 | 滚动显示公告（24h 缓存） | `/announcement` |
| 社交链接 | Wiki / Tutorials / Star / Telegram / Sponsor / Mihomo | `window.open()` |
| 开发者头像 | 12 位贡献者 + 「More」占位（共 13 格，悬停显示名称） | GitHub 头像 URL |

### 7.2 运行模式卡片 (Running Mode)

| 模式 | UCI `en_mode` | 说明 |
|------|---------------|------|
| 兼容 (Compat) | `redir-host` / `fake-ip` | 非 TUN：TCP REDIRECT + UDP TPROXY |
| TUN | `redir-host-tun` / `fake-ip-tun` | TUN 虚拟网卡接管所有流量 |
| 混合 (Mix) | `redir-host-mix` / `fake-ip-mix` | TCP 走 system 栈、UDP 走 gvisor 栈 |

切换触发：`action_switch_run_mode` → 改 UCI `en_mode`，运行中会自动重启。

### 7.3 代理模式卡片 (Proxy Mode)

| 模式 | Mihomo `mode` | 效果 |
|------|---------------|------|
| 策略代理 (Rule) | `rule` | 按 YAML `rules:` 分流 |
| 全局代理 (Global) | `global` | 全部流量走 GLOBAL 组所选代理 |
| 全局直连 (Direct) | `direct` | 全部直连 |

切换触发：`action_switch_rule_mode` → `PATCH /configs` 的 `mode`，同时更新 UCI `proxy_mode`。

### 7.4 快捷设置网格

| 设置项 | UCI | 触发 |
|--------|-----|------|
| 地区绕行 (Area Bypass) | `china_ip_route`（0/1/2） | `action_switch_oc_setting` → 改 UCI + 重启 |
| 域名嗅探 (Sniffer) | `enable_meta_sniffer` | 同上 → 动态改运行 YAML `sniffer.enable` |
| DNS 尊重规则 (DNS Proxy) | `enable_respect_rules` | 同上 → 动态改 YAML `dns.respect-rules` |
| 流媒体解锁 (Stream Unlock) | `stream_auto_select` | 同上 → 置 1 并写 Netflix/Disney/HBO 默认参数 |

### 7.5 配置文件卡片

| 操作 | 功能 | 后端 |
|------|------|------|
| 配置文件选择器 / 切换 | 下拉切换当前 YAML | `action_switch_config` → 更新 `config_path` + 自动重启 |
| 更新配置 | 重新下载订阅 | `action_update_config` → `openclash.sh` |
| 编辑 | 在线编辑 YAML | `config_edit` 模态框（CodeMirror，支持原始/运行时切换、合并视图、覆写模块列表栏） |
| 编辑订阅 | 改该配置的订阅参数 | 跳转 `config-subscribe-edit` |
| 上传 | 上传 YAML | `config_upload` 模态框（文件上传 + 订阅链接两个标签） |
| 刷新订阅按钮 | 手动刷新订阅信息 | `/sub_info_get` |
| 指定 URL 按钮 | 设置订阅信息查询 URL | `/set_subinfo_url` |
| 订阅进度条 | 订阅流量使用情况 | `/sub_info_get` 轮询 |

### 7.6 控制面板卡片

显示 Dashboard 地址与 Secret：`cn_port`（默认 9090，对应 `external-controller`）、`dashboard_password`（`secret`）、`dashboard_forward_domain`/`_port`/`_ssl`（公网访问，域名或 IP/IPv6，端口留空默认 443/80）、`dashboard_custom_url`/`_clash_compatible`（自定义外部仪表盘，见 `09-settings-dns-ac-ipv6.md` §9.4）。

提供 **复制 IP**、**复制密钥** 按钮；配了 `dashboard_custom_url` 时 **复制地址** 优先用它。

### 7.7 混合代理卡片

显示 SOCKS5/HTTP 代理地址，可复制或生成 PAC：`mixed_port`（7893）、`http_port`（7890）、`socks_port`（7891）；认证取 `authentication` TypedSection 的 `username`/`password`。

按钮：复制代理地址、复制认证信息、生成 PAC 配置。

### 7.8 仪表盘入口 (Control Panel)

4 种可选：Dashboard (Yacd) / Yacd / Metacubexd / Zashboard，对应 Mihomo `external-ui`；默认项由 UCI `default_dashboard` 指定；切换触发 `action_switch_dashboard` → `openclash_download_dashboard.sh`。

- 访问地址由 `status.htm` 调 `common.js` 的 `ocGetDashboardBaseURL` 等构造：优先浏览器 hostname 匹配 LAN IP，否则用公网地址（`dashboard_forward_*`），最后回退 LAN IP + `cn_port`，形如 `http[s]://<host>:<port>/ui/<dashboard>/`
- 配了 `dashboard_custom_url` 时额外显示 **External Dashboard** 按钮，并优先用于复制地址（完整逻辑见 `09-settings-dns-ac-ipv6.md` §9.4）
- 子路径：`/ui/dashboard/`、`/ui/yacd/`、`/ui/metacubexd/`、`/ui/zashboard/`

### 7.9 快捷操作按钮 (Quick Action)

| 操作 | 功能 | 后端 |
|------|------|------|
| 关闭链接 (Close Connect) | 断开所有代理连接 | `openclash_history_get.sh 'close_all_conection'` |
| 重置防火墙 (Reload Firewall) | 重新应用 iptables/nftables | `/etc/init.d/openclash reload 'manual'` |
| 清空 DNS 缓存 | 清 Fake-IP 与 DNS 缓存 | `POST /cache/fakeip/flush` + `/cache/dns/flush` |
| 检查更新 (Check Update) | 检查并更新插件 + 内核（订阅走「配置订阅」，GEO 走 GEO 更新入口） | `openclash_update.sh 'one_key_update'` |

### 7.10 统计信息 / 访问控制

底部三视图由标题栏右侧图标切换（`stats-view-toggle`），**默认访问控制**：

| 图标 | 视图 | 说明 |
|------|------|------|
| 用户 | 访问控制 | 列出局域网设备，逐台设置代理/直连（默认） |
| 宫格 | 卡片 | 8 项实时统计 |
| 曲线 | 图表 | `chart.umd.min.js` 绘制单指标实时曲线 |

**访问控制视图**（后端见 `15-api.md` §15.1.1）：

| 控件 | 作用 | 后端 |
|------|------|------|
| 全部代理 / 全部直连 | 设置新设备默认策略 | `lan_ac_mode` 置 0/1 并清空对应例外列表，重建防火墙规则 |
| 重新扫描 | 重读邻居表与 DHCP 租约 | `clients_ac` |
| 排序 | 设备名/分流/连接数/上行/下行，或恢复默认 | 前端本地排序 |
| 设备行：代理 / 直连 | 把设备（IP + MAC）加入当前默认策略的例外列表 | `clients_set` + `openclash_client_ac.sh` 热更新集合，不重建防火墙，仅对新连接生效 |
| 设备行：连接 / 上传 / 下行 | 设备连接数与实时速率（含直连流量） | `clients_stats` 输出 conntrack 原文，浏览器解析聚合 |
| 设备名（点击） | 自定义名称与图标 | `clients_meta`（存 `/etc/openclash/history/clients.json`） |
| 离线标签 | 邻居表无法确认的设备 | 后台 ping 结果写回邻居表，下次轮询读取 |

- 设备接入后自动出现；速率 2 秒刷新，无流量时降到 5 秒；逐设备统计依赖 `nf_conntrack_acct=1`（`start_run_core()` 写入）
- 内核未启动时仍可编辑分流（写 `lan_ac_*` UCI 列表，下次启动由 `start_run_core()` 生成集合并生效）
- `enable_redirect_dns=0` 时 Fake-IP 与 Redir-Host 都能分流，DNS 路径由用户自备；切换设备后卡片顶部短暂提示（代理侧始终提示，直连侧仅 Fake-IP 提示）。Fake-IP + dnsmasq 转发（`1`）时开关被锁定，提示条「切换」会改为防火墙转发（重启 dnsmasq，不重启内核）。详见 `09-settings-dns-ac-ipv6.md` §9.2

**卡片视图 8 项指标**（数据源见 `15-api.md` §15.1.1）：上行速率、下行速率、上行总量、下行总量、连接数、核心内存、核心 CPU、系统平均负载。

### 7.11 IP 检测页 (IP Address / 访问检查)

**IP 地址**: 并行查 4 个源（PConline `whois.pconline.com.cn`、IPIP.NET、IP.SB、IPIFY），各显示 IP + 地理信息；眼睛图标用 `***.***.***.***` 隐藏全部（持久化到 localStorage）。

**访问检测**: 路由器模式（后端 XHR 代理）与浏览器模式（前端 fetch）切换；检测 Baidu / 网易云音乐 / GitHub / YouTube，显示 HTTP 状态码与延迟（ms）；刷新按钮重跑全部。

轮询间隔：HTTP 检测 5–20 s，IP 检测 15–40 s。

### 7.12 oixCloud 面板 (oixCloud)

仅在设置 `oix_token` 且 `oix_show_info_page=1` 时显示：Logo + 随机标语、公告横幅（60 s 后消失）、计划信息（类型/到期/余额/推广余额/积分）、流量统计（今日已用/计划已用/剩余/总量）、签到按钮、底部「Powered by oixcloud.com」。

> 登录入口在「插件设置 → oixCloud」标签页的 Login Account 按钮。
