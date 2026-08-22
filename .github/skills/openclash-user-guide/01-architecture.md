## 系统架构速查

> **用途**: OpenClash 系统架构速查与启动/停止完整流程，是理解所有选项实现逻辑的基础。

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
| `/usr/share/openclash/ui/` | Dashboard 静态文件（dashboard/yacd/metacubexd/zashboard 四个子目录） |
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
├─ 前置检查: enable != 1 → 退出；procd 已运行 → 退出
│
├─ Step 1: 读取配置 (Get The Configuration)
│   ├─ check_run_quick()   → 判断是否快速启动模式 (QUICK_START，跳过 YAML 修改)
│   ├─ overwrite_file()    → 遍历 config_overwrite 条目，生成 /tmp/yaml_overwrite.sh
│   ├─ get_config()        → 读取所有 UCI 选项为 Shell 变量
│   ├─ config_choose()     → 选择活动的 YAML 配置文件 (RAW/TMP/CONFIG)
│   └─ do_run_mode()       → 解析 en_mode → 拆分 en_mode_tun/en_mode_fakeip/en_mode_mix
│
├─ Step 2: 环境准备 (Check The Components)
│   └─ do_run_file()       → 核心类型判断(Oix/Smart/Meta) + 缺失自动下载 + 文件准备
│       ├─ GEO 文件规范化  → geosite.dat→GeoSite.dat / geoip.dat→GeoIP.dat
│       ├─ 小闪存模式处理  → 文件在 /tmp/etc/openclash 与 /etc/openclash 间搬移
│       ├─ 创建 symlink    → ln -s <core> /etc/openclash/clash
│       ├─ 核心缺失/类型不符 → 自动调用 openclash_core.sh 下载
│       └─ Chnroute 缺失   → 自动调用 openclash_chnroute.sh 下载
│
├─ Step 3: 修改 YAML 配置 (Modify The Config File，非 QUICK_START 时执行)
│   ├─ config_check()      → 配置/格式检查
│   ├─ ① yml_change.sh    → Ruby 脚本，~48 个 UCI 参数
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
│   ├─ ② yml_rules_change.sh → Ruby 脚本 (14 个参数)
│   │   ├─ enable_rule_proxy → 注入 BT/P2P 直连规则 + PROCESS-NAME 规则
│   │   ├─ tolerance/urltest_* → 覆写 url-test 策略组参数
│   │   ├─ enable_custom_clash_rules → 从 *.list 文件注入自定义规则
│   │   ├─ auto_smart_switch → 将 url-test/load-balance 组改为 smart 类型
│   │   └─ smart_collect/smart_policy_priority/smart_enable_lgbm/smart_prefer_asn/smart_tolerance → Smart 策略组
│   │
│   ├─ ③ /tmp/yaml_overwrite.sh → 覆写模块 [Overwrite]/[YAML] 段（overwrite_file() 生成）
│   ├─ ④ /etc/openclash/custom/openclash_custom_overwrite.sh → 固定自定义覆写脚本
│   └─ ⑤ Provider 路径修复 (ruby) → proxy-providers/rule-providers 的 path 统一为 ./proxy_provider/<name>
│   （QUICK_START 时跳过整个 Step 3）
│
├─ Step 4: 启动核心 (Start Running The Clash Core)
│   └─ start_run_core()    → mv 运行配置 + procd 启动 clash -d /etc/openclash -f <config.yaml>
│       ├─ procd env      → SAFE_PATHS / CLASH_AGE_SECRET_KEY / OIX_TOKEN / OIX_PARAMS
│       ├─ respawn 配置   → procd respawn 300 5 3 (threshold 300s / timeout 5s / retry 3 次)
│       └─ rlimit         → nofile=1000000 / nproc / as / memlock=unlimited
│
├─ Step 5: 核心状态检查 + 防火墙规则 (check_core_status "start" &)
│   ├─ 等待核心进程       → 最多 10s
│   ├─ TUN 模式:         → check_mod tun + 等待 utun 接口(≤300s，失败重启≤3 次) + 策略路由(fwmark 0x162→table 0x162, pref 1888)
│   ├─ 非 TUN 模式:      → 轮询 http://<lan_ip>:<cn_port>/group 返回 200 (≤300s)
│   └─ 核心就绪后 (start):
│       ├─ change_dnsmasq() → DNS 劫持 (dnsmasq → Clash DNS，防止核心 DNS 查询失败)
│       └─ set_firewall()   → 建立 iptables/nftables 透明代理规则
│           ├─ REDIRECT/TPROXY 规则 (按 en_mode)
│           ├─ DNS 劫持规则 (按 enable_redirect_dns)
│           ├─ 访问控制规则 (按 lan_ac_mode + lists)
│           ├─ QUIC 阻断规则 (按 disable_udp_quic)
│           ├─ 中国 IP 绕行规则 (按 china_ip_route)
│           └─ IPv6 防火墙链 (按 ipv6_enable)
│
└─ Step 6: 定时任务 + 守护进程 (Add Cron Rules, Start Daemons)
    ├─ add_cron()         → 注册 cron 任务
    │   ├─ openclash.sh   → 定时更新订阅
    │   ├─ openclash_geo.sh → 定时更新 GEO 数据 (ipdb/geosite/geoip/geoasn)
    │   ├─ openclash_chnroute.sh → 定时更新大陆路由
    │   ├─ /etc/init.d/openclash restart → 定时自动重启
    │   └─ add_overwrite_cron → 覆写模块下载任务
    ├─ start_watchdog()   → procd 启动 openclash_watchdog.sh (核心存活监控 + 流媒体解锁)
    ├─ IPv6 DHCP 警告检查 → 非 TUN 且 dhcpv6 未禁用时告警
    └─ 清理              → rm -rf /tmp/yaml_*
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
