## LuCI 与 Mihomo HTTP API

> **用途**: LuCI HTTP API 与 Mihomo 原生 API 的 curl 命令及返回值解读（§15.1–15.2）。

> **AI 行为指引**: 当用户需要「用命令查询/修改 OpenClash 状态」「通过 HTTP API 操作核心」「编写自动化脚本调用」时，AI 应结合本文件给出可直接执行的 curl 命令。排障场景优先用 `14-diagnostics.md` §14.3 的安全查询命令；LuCI 后端接口（§15.1）与 Mihomo 原生 API（§15.2）的适用场景不同，按需选择。

> **小节索引**: §15.1 LuCI HTTP API（§15.1.1 状态查询 / §15.1.2 操作 / §15.1.3 诊断）· §15.2 Mihomo 原生 API

### 15.1 LuCI HTTP API

> 以下命令在路由器终端直接执行（本地 `127.0.0.1`，无需认证）。
> 返回 JSON 格式，可追加 `| jsonfilter -e '@.key'` 提取特定字段（OpenWrt 内置工具）。

#### 15.1.1 状态查询

```bash
# 运行状态总览（核心状态、Dashboard地址、端口、核心类型）
curl -s http://127.0.0.1/cgi-bin/luci/admin/services/openclash/status

# 当前代理模式 (rule/global/direct)
curl -s http://127.0.0.1/cgi-bin/luci/admin/services/openclash/rule_mode

# 当前运行模式 (redir-host/fake-ip/redir-host-tun 等)
curl -s http://127.0.0.1/cgi-bin/luci/admin/services/openclash/get_run_mode

# 实时流量统计（上下行速率、连接数、CPU、内存）
curl -s http://127.0.0.1/cgi-bin/luci/admin/services/openclash/toolbar_show

# 本机配置与已装版本（编译版本 corever、发布分支 release_branch、Smart 状态 smart_enable、oix/pkg_type、CPU 架构 coremodel、已安装插件/内核版本 opcv/coremetacv；不含远程最新）
curl -s http://127.0.0.1/cgi-bin/luci/admin/services/openclash/update

# 远程最新版本（corelv 远程最新核心 / oplv 远程最新插件，首次请求会同步拉取缓存）
curl -s http://127.0.0.1/cgi-bin/luci/admin/services/openclash/last_version

# 配置文件列表及当前使用的配置
curl -s http://127.0.0.1/cgi-bin/luci/admin/services/openclash/config_name

# 混合代理端口和认证信息
curl -s http://127.0.0.1/cgi-bin/luci/admin/services/openclash/proxy_info

# 订阅流量/到期信息（替换 <配置名>）
curl -s 'http://127.0.0.1/cgi-bin/luci/admin/services/openclash/sub_info_get?filename=<配置名>'

# 快捷设置状态（sniffer/respected_rules/china_ip_route/stream_unlock）
curl -s http://127.0.0.1/cgi-bin/luci/admin/services/openclash/oc_settings

# 最后一行启动日志
curl -s http://127.0.0.1/cgi-bin/luci/admin/services/openclash/startlog

# 核心文件是否存在
curl -s http://127.0.0.1/cgi-bin/luci/admin/services/openclash/check_core

# 多源出口 IP 查询（PConline/IPIP/IP.SB/IPIFY 并行）
curl -s http://127.0.0.1/cgi-bin/luci/admin/services/openclash/myip_check

# 网站可达性检测（替换域名，返回延迟 ms）
curl -s 'http://127.0.0.1/cgi-bin/luci/admin/services/openclash/website_check?domain=www.google.com'
```

**关键返回值解读：**

`/status` 返回的 JSON：
| 字段 | 含义 | 正常值 | 异常含义 |
|------|------|--------|----------|
| `clash` | UCI enable 开关 | `true` | `false` → 插件被禁用，需在「运行状态」页开启 |
| `run_mode` | 当前 en_mode | `redir-host`/`fake-ip`/`redir-host-tun`/`fake-ip-tun`/`redir-host-mix`/`fake-ip-mix` | — |
| `rule_mode` | 代理模式 | `rule` | `direct` → 所有流量直连；`global` → 所有流量走 GLOBAL 组 |
| `meta_sniffer` | 域名嗅探 | `"1"` | `"0"` → 嗅探关闭，域名规则可能失效 |
| `oversea` | 区域绕行 | `"1"`(大陆)/`"2"`(海外)/`"0"`(关闭) | `"0"` → 未启用 IP 绕行 |
| `cn_port` | API 端口 | `"9090"` | 非 9090 → 用户修改过端口 |
| `core_type` | 核心类型 | `"Meta"` | `"Smart"`→Smart 内核；`"Oix"`→oixCloud 内核 |

`/toolbar_show` 返回的 JSON：
| 字段 | 含义 | 异常判断 |
|------|------|----------|
| `connections` | 活跃连接数 | `"0"` → 无流量经过核心，可能规则全 RETURN |
| `up` / `down` | 实时速率 | 持续为 `"0 B/S"` → 无数据流动 |
| `mem` | 核心内存占用 | 持续增长 → 可能存在内存泄漏 |
| `cpu` | 核心 CPU 占用 | 持续 > 80% → 节点过多或规则复杂 |

`/update` 返回的 JSON：
| 字段 | 来源 | 含义 |
|------|------|------|
| `coremodel` | opkg/apk `libc` 架构 | CPU 架构（只读展示） |
| `corever` | UCI `core_version` | 编译版本选择，`"0"`=未设置 |
| `release_branch` | UCI `release_branch` | 发布分支（master/dev） |
| `smart_enable` | UCI `smart_enable` | Smart 内核启用状态 |
| `oix_core` | UCI `oix_token` | 是否 oixCloud 内核 |
| `pkg_type` | opkg/apk | 包管理器类型 |
| `coremetacv` | `clash_meta -v` 解析 | 当前核心版本（已装），`"0"`=核心文件不存在 |
| `opcv` | opkg/apk 包数据库 | 当前插件版本（已装），`"0"`=未安装 |
| `github_address_mod` | UCI `config.github_address_mod` | GitHub CDN 地址（`"0"`=未设置） |
| `cdn_list` | 读 `/usr/share/openclash/res/cdn.list` | CDN 地址列表（供前端探测） |

`/last_version` 返回的 JSON（远程最新版本，status 页「新版本可用」红点判断依据）：
| 字段 | 来源 | 含义 |
|------|------|------|
| `corelv` | Lua `fetch_version_history` 缓存 | 远程最新核心版本，`"loading..."`=尚未获取 |
| `oplv` | Lua `fetch_version_history` 缓存 | 远程最新插件版本 |

`/check_core` 返回 `{"core_status":"1"}`（核心文件存在）或 `{"core_status":"0"}`（不存在，需下载）。

`/sub_info_get` 返回的 JSON (`providers[]`)：
| 字段 | 含义 | 异常判断 |
|------|------|----------|
| `http_code` | HTTP 状态码 | 非 `"200"` → 订阅源不可达 |
| `surplus` | 剩余流量 | `"null"` → 订阅不支持流量查询；接近 `"0 KB"` → 即将用尽 |
| `day_left` | 剩余天数 | `0` → 已过期；`"null"` → 无法获取；`"∞"` → 长期有效 |
| `percent` | 剩余百分比 | < 10% → 即将用尽 |

`/website_check` 返回 `{"success":true/false, "response_time":<ms>, "error":"..."}`。`success=false` 且 `error="No response"` 表示完全不通。

#### 15.1.2 操作

```bash
# --- 服务控制 ---
# 启动
curl -s -X POST -d 'action=start' http://127.0.0.1/cgi-bin/luci/admin/services/openclash/action
# 停止
curl -s -X POST -d 'action=stop' http://127.0.0.1/cgi-bin/luci/admin/services/openclash/action
# 重启
curl -s -X POST -d 'action=restart' http://127.0.0.1/cgi-bin/luci/admin/services/openclash/action

# --- 热切换（无需重启核心） ---
# 切换代理模式为 rule
curl -s -X POST -d 'rule_mode=rule' http://127.0.0.1/cgi-bin/luci/admin/services/openclash/switch_rule_mode
# 切换代理模式为 global
curl -s -X POST -d 'rule_mode=global' http://127.0.0.1/cgi-bin/luci/admin/services/openclash/switch_rule_mode
# 切换代理模式为 direct
curl -s -X POST -d 'rule_mode=direct' http://127.0.0.1/cgi-bin/luci/admin/services/openclash/switch_rule_mode

# 切换日志级别
curl -s -X POST -d 'log_level=debug' http://127.0.0.1/cgi-bin/luci/admin/services/openclash/switch_log
curl -s -X POST -d 'log_level=info' http://127.0.0.1/cgi-bin/luci/admin/services/openclash/switch_log
curl -s -X POST -d 'log_level=warning' http://127.0.0.1/cgi-bin/luci/admin/services/openclash/switch_log

# --- 缓存操作 ---
# 清空 DNS+Fake-IP 缓存
curl -s -X POST http://127.0.0.1/cgi-bin/luci/admin/services/openclash/flush_dns_cache
# 清空 Smart 缓存
curl -s -X POST http://127.0.0.1/cgi-bin/luci/admin/services/openclash/flush_smart_cache

# --- 防火墙与连接 ---
# 重载防火墙规则
curl -s -X POST http://127.0.0.1/cgi-bin/luci/admin/services/openclash/reload_firewall
# 断开所有代理连接
curl -s -X POST http://127.0.0.1/cgi-bin/luci/admin/services/openclash/close_all_connection

# --- 快捷设置切换 ---
# 启用域名嗅探
curl -s -X POST -d 'setting=meta_sniffer&value=1' http://127.0.0.1/cgi-bin/luci/admin/services/openclash/switch_oc_setting
# 启用 DNS 尊重规则
curl -s -X POST -d 'setting=respect_rules&value=1' http://127.0.0.1/cgi-bin/luci/admin/services/openclash/switch_oc_setting
# 切换区域绕行：0=关闭 1=绕过大陆 2=绕过海外
curl -s -X POST -d 'setting=oversea&value=1' http://127.0.0.1/cgi-bin/luci/admin/services/openclash/switch_oc_setting
# 启用流媒体解锁
curl -s -X POST -d 'setting=stream_unlock&value=1' http://127.0.0.1/cgi-bin/luci/admin/services/openclash/switch_oc_setting

# --- 配置与订阅 ---
# 切换配置文件（替换 <文件名.yaml>，会自动重启核心）
curl -s -X POST -d 'config_file=<文件名.yaml>' http://127.0.0.1/cgi-bin/luci/admin/services/openclash/switch_config
# 更新指定订阅配置（替换 <配置名>）
curl -s -X POST -d 'filename=<配置名>' http://127.0.0.1/cgi-bin/luci/admin/services/openclash/update_config

# --- 更新操作 ---
# 更新核心（按 uci 配置构建下载 URL，无完整 URL）
curl -s -X POST -d 'core_type=Meta' http://127.0.0.1/cgi-bin/luci/admin/services/openclash/coreupdate
# 更新插件（无参=只升级插件）
curl -s -X POST http://127.0.0.1/cgi-bin/luci/admin/services/openclash/opupdate
# 一键更新（核心+插件+订阅+GEO）
curl -s -X POST http://127.0.0.1/cgi-bin/luci/admin/services/openclash/one_key_update

# --- 生成 PAC 文件 ---
curl -s -X POST http://127.0.0.1/cgi-bin/luci/admin/services/openclash/generate_pac
```

#### 15.1.3 诊断

```bash
# 连接诊断（测试指定域名/IP 可达性）
curl -s 'http://127.0.0.1/cgi-bin/luci/admin/services/openclash/diag_connection?addr=www.google.com'

# DNS 诊断（测试指定域名的 DNS 解析链路）
curl -s 'http://127.0.0.1/cgi-bin/luci/admin/services/openclash/diag_dns?addr=www.google.com'

# 生成并返回完整调试日志（等同于 openclash_debug.sh）
curl -s http://127.0.0.1/cgi-bin/luci/admin/services/openclash/gen_debug_logs

# 返回已有的调试日志（不重新生成）
curl -s http://127.0.0.1/cgi-bin/luci/admin/services/openclash/get_debug_logs

# 手动流媒体解锁测试（替换 <服务名>，如 netflix/disney/hbo_max 等）
curl -s 'http://127.0.0.1/cgi-bin/luci/admin/services/openclash/manual_stream_unlock_test?type=<服务名>'
```

### 15.2 Mihomo 原生 API

> 以下命令在路由器终端直接执行，核心必须运行中。
> 如设置了 `dashboard_password`，所有命令需追加 `-H "Authorization: Bearer <password>"`。

```bash
# --- 读取运行时配置 ---
# 查看完整运行时 YAML 配置
curl -s http://127.0.0.1:9090/configs

# 仅查看代理模式
curl -s http://127.0.0.1:9090/configs | grep '"mode"'

# --- 热修改配置（无需重启核心） ---
# 切换代理模式为 rule
curl -s -X PATCH -H 'Content-Type: application/json' \
  -d '{"mode":"rule"}' http://127.0.0.1:9090/configs
# 切换代理模式为 global
curl -s -X PATCH -H 'Content-Type: application/json' \
  -d '{"mode":"global"}' http://127.0.0.1:9090/configs
# 切换日志级别为 debug
curl -s -X PATCH -H 'Content-Type: application/json' \
  -d '{"log-level":"debug"}' http://127.0.0.1:9090/configs

# 热重载配置文件（替换路径）
curl -s -X PUT -H 'Content-Type: application/json' \
  -d '{"path":"/etc/openclash/<配置文件名>.yaml"}' \
  'http://127.0.0.1:9090/configs?force=true'

# --- 代理节点查询与切换 ---
# 查看所有代理节点及延迟
curl -s http://127.0.0.1:9090/proxies

# 切换策略组到指定节点（替换 <策略组名> 和 <节点名>）
curl -s -X PUT -H 'Content-Type: application/json' \
  -d '{"name":"<节点名>"}' http://127.0.0.1:9090/proxies/<策略组名>

# --- 连接管理 ---
# 查看活跃连接列表
curl -s http://127.0.0.1:9090/connections

# 关闭所有连接
curl -s -X DELETE http://127.0.0.1:9090/connections

# 关闭指定连接（替换 <连接ID>，ID 从 /connections 返回中获取）
curl -s -X DELETE http://127.0.0.1:9090/connections/<连接ID>

# --- 缓存操作 ---
# 清空 Fake-IP 缓存
curl -s -X POST http://127.0.0.1:9090/cache/fakeip/flush
# 清空 DNS 缓存
curl -s -X POST http://127.0.0.1:9090/cache/dns/flush
# 清空 Smart 缓存
curl -s -X POST http://127.0.0.1:9090/cache/smart/flush

# --- 其他 ---
# 实时流量数据
curl -s http://127.0.0.1:9090/traffic
# 核心版本
curl -s http://127.0.0.1:9090/version
```

**关键返回值解读：**

`/configs` (GET) 返回完整运行时 YAML 的 JSON 表示：
| 关注字段 | 诊断用途 |
|----------|----------|
| `.mode` | `rule`/`global`/`direct` — 代理模式 |
| `.dns.enhanced-mode` | `fake-ip`/`redir-host` — DNS 模式 |
| `.dns.nameserver` | 上游 DNS 列表 |
| `.tun.enable` | TUN 是否启用 |
| `.sniffer.enable` | 域名嗅探是否开启 |
| `.log-level` | 当前日志级别 |

`/proxies` (GET) 返回所有代理节点：
| 字段 | 含义 |
|------|------|
| `.proxies.<组名>.type` | 策略组类型 (select/url-test/fallback/load-balance/smart) |
| `.proxies.<组名>.now` | 当前选中的节点名 |
| `.proxies.<节点名>.history[]` | 最近延迟记录 (`{"delay":<ms>,"time":"..."}`)，`delay=0` 表示超时 |
| `.proxies.<节点名>.alive` | 节点是否存活 |

> 诊断提示：若某节点 `history` 全部 `delay=0` → 节点不可达；若某策略组 `now` 为空或指向异常节点 → 手动切换失败或无可用节点。

`/connections` (GET) 返回活跃连接：
| 字段 | 含义 |
|------|------|
| `.connections[].chains[]` | 代理链（如 `["Proxy","ss_node"]`），最后一个为出口节点 |
| `.connections[].rule` | 匹配的规则类型 (如 `DOMAIN-SUFFIX,google.com`) |
| `.connections[]. metadata.host` | 目标域名 |
| `.uploadTotal` / `.downloadTotal` | 累计上下行流量（字节） |

> 诊断提示：若连接列表为空但有网络活动 → 流量未进入核心（防火墙规则问题）；若 `chains` 全部为 `["DIRECT"]` → 规则匹配为直连。
