## LuCI 与 Mihomo HTTP API

> **用途**: LuCI 后端接口（§15.1）与 Mihomo 原生 API（§15.2）的端点、参数与返回值解读。
> **执行环境**: 路由器终端，`127.0.0.1` 本地访问无需认证；排障优先用 `14-diagnostics.md` §14.3 的安全查询命令。
> **通用**: 返回 JSON，可用 `| jsonfilter -e '@.key'` 提取字段（OpenWrt 内置）。

### 15.1 LuCI HTTP API

前缀统一为 `http://127.0.0.1/cgi-bin/luci/admin/services/openclash`。

#### 15.1.1 状态查询（GET）

| 端点 | 用途 |
|------|------|
| `/status` | 运行状态总览（核心状态、Dashboard 地址、端口、核心类型） |
| `/rule_mode` | 当前代理模式（rule/global/direct） |
| `/get_run_mode` | 当前运行模式（redir-host / fake-ip / *-tun 等） |
| `/toolbar_show` | 实时流量原始数据（连接数、累计流量、内存、CPU ticks） |
| `/update` | 本机配置与已装版本（`corever`/`release_branch`/`smart_enable`/`oix`/`pkg_type`/`coremodel`/`opcv`/`coremetacv`），**不含远程最新** |
| `/last_version` | 远程最新版本（`corelv`/`oplv`，首次请求会同步拉缓存） |
| `/config_name` | 配置列表与当前使用项 |
| `/proxy_info` | 混合代理端口与认证信息 |
| `/sub_info_get?filename=<配置名>` | 订阅流量/到期信息 |
| `/oc_settings` | 快捷设置状态（sniffer / respected_rules / china_ip_route / stream_unlock） |
| `/startlog` | 最后一行启动日志 |
| `/check_core` | 核心文件是否存在 |
| `/myip_check` | 多源出口 IP（PConline / IPIP / IP.SB / IPIFY 并行） |
| `/clients_ac` | 局域网设备列表（在线状态、分流方向、自定义名称图标） |
| `/clients_stats` | 逐设备流量原始数据（`/proc/net/nf_conntrack` 原文，浏览器解析聚合） |
| `/clients_set?action=proxy\|direct&scope=item\|all[&ip=..][&mac=..]` | 设置设备分流（`scope=item` 时 ip/mac 至少给一个） |
| `/clients_meta?mac=..&name=..&icon=..` | 保存设备名称与图标（留空恢复自动识别） |
| `/clients_dns_switch` | Fake-IP 下把 DNS 劫持切成防火墙转发（同步重建规则） |
| `/website_check?domain=..` | 网站可达性检测（返回延迟 ms） |

```bash
curl -s http://127.0.0.1/cgi-bin/luci/admin/services/openclash/status
curl -s 'http://127.0.0.1/cgi-bin/luci/admin/services/openclash/clients_set?action=direct&scope=item&ip=192.168.1.10&mac=aa:bb:cc:dd:ee:ff'
```

**`/status` 返回字段**:

| 字段 | 含义 | 正常 / 异常 |
|------|------|-------------|
| `clash` | UCI enable 开关 | `true`；`false` = 插件被禁用 |
| `run_mode` | 当前 `en_mode` | 六种取值之一 |
| `rule_mode` | 代理模式 | `rule`；`direct` = 全直连；`global` = 全走 GLOBAL 组 |
| `meta_sniffer` | 域名嗅探 | `"1"`；`"0"` = 关闭，域名规则可能失效 |
| `oversea` | 区域绕行 | `"1"` 大陆 / `"2"` 海外 / `"0"` 关闭 |
| `cn_port` | API 端口 | `"9090"` |
| `core_type` | 核心类型 | `"Meta"` / `"Smart"` / `"Oix"` |
| `daip` | 局域网 IP | 前端构造仪表盘 URL 的基准 host |
| `dase` | `dashboard_password` | 仪表盘 secret |
| `db_foward_domain` / `db_foward_port` / `db_forward_ssl` | 公网访问设置 | 前端构造公网仪表盘 URL |
| `dashboard_custom_url` / `dashboard_custom_clash_compatible` | 自定义外部仪表盘 | 非空时前端显示 External Dashboard 按钮 |

**`/toolbar_show`**（前端再格式化；浏览器能直连核心 WebSocket 时仅作回退）：`connections`（0 = 无流量过核心，可能规则全 RETURN）、`up_total`/`down_total`（字节，两次采样算速率）、`mem`（字节，持续增长可能泄漏）、`cpu_ticks`/`cpu_count`（USER_HZ=100，算出占用率；>80% 说明节点过多或规则复杂）。

**`/update`**: `coremodel`（opkg/apk libc 架构）、`corever`（UCI `core_version`，`"0"` 未设置）、`release_branch`、`smart_enable`、`oix_core`（UCI `oix_token`）、`pkg_type`、`coremetacv`（`clash_meta -v`，`"0"` 不存在）、`opcv`（`"0"` 未安装）、`github_address_mod`、`cdn_list`（读 `res/share/openclash/res/cdn.list`，由 `openclash_version.lua` 自动更新，超 7 天且可连通时拉新）。

**`/last_version`**: `corelv` / `oplv`（`"loading..."` = 尚未获取）。
**`/check_core`**: `{"core_status":"1"}` 存在 / `"0"` 不存在。
**`/sub_info_get`**: `http_code`（非 `"200"` = 源不可达）、`surplus`（`"null"` = 不支持查询）、`day_left`（`0` = 过期、`"∞"` = 长期）、`percent`（<10% 即将用尽）。
**`/website_check`**: `{"success":true|false,"response_time":<ms>,"error":"..."}`；`error="No response"` = 完全不通。

#### 15.1.2 操作

| 端点 | 方法 / 参数 | 用途 |
|------|-------------|------|
| `/action` | POST `action=start\|stop\|restart` | 服务控制 |
| `/switch_rule_mode` | POST `rule_mode=rule\|global\|direct` | 热切换代理模式 |
| `/switch_log` | POST `log_level=debug\|info\|warning` | 热切换日志级别 |
| `/flush_dns_cache` | POST | 清 DNS + Fake-IP 缓存 |
| `/flush_smart_cache` | POST | 清 Smart 缓存 |
| `/reload_firewall` | POST | 重载防火墙规则 |
| `/close_all_connection` | POST | 断开所有代理连接 |
| `/switch_oc_setting` | POST `setting=meta_sniffer\|respect_rules\|oversea\|stream_unlock` + `value=` | 快捷设置（`oversea`：0 关 / 1 大陆 / 2 海外） |
| `/switch_config` | POST `config_file=<文件名.yaml>` | 切换配置（自动重启核心） |
| `/update_config` | POST `filename=<配置名>` | 更新指定订阅 |
| `/coreupdate` | POST `core_type=Meta` | 更新核心（按 UCI 构建下载 URL） |
| `/opupdate` | POST（无参） | 只升级插件 |
| `/one_key_update` | POST | 一键更新（核心 + 插件 + 订阅 + GEO） |
| `/generate_pac` | POST | 生成 PAC 文件 |

```bash
curl -s -X POST -d 'action=restart' http://127.0.0.1/cgi-bin/luci/admin/services/openclash/action
curl -s -X POST -d 'rule_mode=direct' http://127.0.0.1/cgi-bin/luci/admin/services/openclash/switch_rule_mode
curl -s -X POST -d 'setting=oversea&value=1' http://127.0.0.1/cgi-bin/luci/admin/services/openclash/switch_oc_setting
```

> `coreupdate` / `opupdate` / `one_key_update` 下载后会用同目录 `checksums.txt` 校验（`openclash_curl.sh` 的 `verify_sha256_checksum()`），失败则中止并报 `Checksum Verification Failed`（见 `03-errors.md` §3.4）。

#### 15.1.3 诊断

| 端点 | 用途 |
|------|------|
| `/diag_connection?addr=..` | 连接诊断（域名/IP 可达性） |
| `/diag_dns?addr=..` | DNS 解析链路诊断 |
| `/gen_debug_logs` | 生成并返回完整调试日志（等同 `openclash_debug.sh`） |
| `/get_debug_logs` | 返回已有调试日志（不重新生成） |
| `/manual_stream_unlock_test?type=<服务名>` | 手动流媒体解锁测试（netflix / disney / hbo_max 等） |

### 15.2 Mihomo 原生 API

> 核心必须运行中；设置 `dashboard_password` 时所有请求加 `-H "Authorization: Bearer <password>"`。

| 端点 | 方法 / 参数 | 用途 |
|------|-------------|------|
| `/configs` | GET | 完整运行时配置 |
| `/configs` | PATCH `{"mode":"rule"}` / `{"log-level":"debug"}` | 热改配置 |
| `/configs?force=true` | PUT `{"path":"/etc/openclash/<配置>.yaml"}` | 热重载配置文件 |
| `/proxies` | GET | 所有节点及延迟 |
| `/proxies/<组名>` | PUT `{"name":"<节点名>"}` | 切换策略组 |
| `/connections` | GET | 活跃连接列表 |
| `/connections` | DELETE | 关闭全部连接 |
| `/connections/<连接ID>` | DELETE | 关闭指定连接 |
| `/cache/fakeip/flush` · `/cache/dns/flush` · `/cache/smart/flush` | POST | 清 Fake-IP / DNS / Smart 缓存 |
| `/traffic` | GET | 实时流量 |
| `/version` | GET | 核心版本 |

```bash
curl -s http://127.0.0.1:9090/configs | jsonfilter -e '@.dns.enhanced-mode'
curl -s -X PATCH -H 'Content-Type: application/json' -d '{"mode":"global"}' http://127.0.0.1:9090/configs
curl -s -X PUT -H 'Content-Type: application/json' -d '{"name":"<节点名>"}' http://127.0.0.1:9090/proxies/<策略组名>
```

**`/configs` 关注字段**: `.mode`、`.dns.enhanced-mode`、`.dns.nameserver`、`.tun.enable`、`.sniffer.enable`、`.log-level`。

**`/proxies`**: `.proxies.<组名>.type`（select/url-test/fallback/load-balance/smart）、`.now`（当前节点）、`.history[]`（`{"delay":<ms>,"time":"..."}`，`delay=0` = 超时）、`.alive`。
> `history` 全 `delay=0` → 节点不可达；`now` 为空或异常 → 手动切换失败或无可用节点。

**`/connections`**: `.connections[].chains[]`（最后一个为出口节点）、`.rule`（命中的规则）、`.metadata.host`（目标域名）、`.uploadTotal` / `.downloadTotal`。
> 列表为空但有网络活动 → 流量未进核心（防火墙问题）；`chains` 全为 `["DIRECT"]` → 全直连。
