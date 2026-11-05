## 系统架构速查

> **用途**: 整体架构、关键目录、启动/停止流程与「热生效 vs 需重启」对照，是理解各选项实现的基础。

```
LuCI Web UI (Lua CBI)  →  /etc/config/openclash（UCI，所有选项持久化）
                              │
                              ▼  /usr/share/openclash/ 下的脚本
  openclash.sh          订阅下载/更新/节点过滤
  openclash_core.sh     核心二进制更新
  openclash_update.sh   插件 ipk/apk 更新
  openclash_geo.sh      GEO 下载（ipdb/dat/geosite/asn）
  openclash_chnroute.sh 大陆路由表更新
  yml_change.sh         Ruby 改 YAML（端口/模式/DNS/TUN/认证/Meta/Smart）
  yml_rules_change.sh   Ruby 改 YAML（规则/Provider/URL-Test/Smart 组）
  openclash_debug.sh    诊断日志（30 章节）
  openclash_watchdog.sh 核心存活 + 流媒体解锁守护
                              │
                              ▼  产物
  /etc/openclash/config/*.yaml  原始订阅配置
  /etc/openclash/*.yaml         处理后的运行配置
  /etc/openclash/overwrite/     覆写模块
  /etc/openclash/custom/        用户自定义规则/DNS/防火墙脚本
  /etc/openclash/clash          symlink → core/clash_meta

API: http://<LAN_IP>:9090 （external-controller）    Dashboard: http://<LAN_IP>:9090/ui/
```

| 路径 | 作用 |
|------|------|
| `/etc/config/openclash` | UCI 配置（`uci show openclash` 可见全部） |
| `/etc/openclash/` | 工作目录（核心、GEO、Chnroute） |
| `/etc/openclash/config/` | 原始订阅配置；经 `yml_change.sh` 处理后在 `/etc/openclash/<name>.yaml` 生成运行配置 |
| `/etc/openclash/overwrite/` | 覆写模块（INI 格式自定义 YAML 覆盖） |
| `/etc/openclash/custom/` | 自定义规则列表、DNS 策略、Hosts、防火墙脚本、Sniffer 配置 |
| `/etc/openclash/core/` | 核心二进制（多版本共存） |
| `/usr/share/openclash/ui/` | Dashboard 静态文件（dashboard / yacd / metacubexd / zashboard） |
| `/etc/openclash/Model.bin` | LightGBM 模型（单个文件，非目录） |
| `/usr/share/openclash/` | 插件脚本（Shell/Ruby/Lua） |
| `/tmp/openclash.log` / `/tmp/openclash_start.log` | 运行日志 / 启动日志 |
| `/tmp/etc/openclash/` | 小闪存模式工作目录（重启清空） |
| `/var/etc/openclash.include` | 防火墙规则加载文件（firewall UCI 自动 include） |

- **核心 API**: `http://<LAN_IP>:9090`，部分动态选项经 `PATCH /configs` 热生效；地址是路由器 LAN IP（核心监听 `0.0.0.0`），但 LuCI 后端走 `127.0.0.1` 直连
- **服务控制**: `/etc/init.d/openclash {start|stop|restart|reload|enable|disable}`

## 启动流程（`start_service()`）

前置：`enable != 1` 或 procd 已在运行则退出。

| Step | 阶段 | 关键动作 |
|------|------|----------|
| 1 | 读取配置 | `check_run_quick()` 判断 QUICK_START（为真则跳过 Step 3 的 YAML 修改）；`overwrite_file()` 遍历 `config_overwrite` 生成清单 `/tmp/yaml_openclash_overwrite_lines`；`get_config()` 把 UCI 读成 Shell 变量；`config_choose()` 选活动配置（RAW/TMP/CONFIG）；`do_run_mode()` 把 `en_mode` 拆为 `en_mode_tun`/`en_mode_fakeip`/`en_mode_mix` |
| 2 | 环境准备 | `do_run_file()`：判断核心类型（Oix/Smart/Meta）并自动下载缺失核心；GEO 文件规范化（`geosite.dat`→`GeoSite.dat`、`geoip.dat`→`GeoIP.dat`）；小闪存模式在 `/tmp/etc/openclash` 与 `/etc/openclash` 间搬移；建 `clash` symlink；缺核心调 `openclash_core.sh`、缺 Chnroute 调 `openclash_chnroute.sh` |
| 3 | 改 YAML（QUICK_START 时整段跳过） | `config_check()` → ① `yml_change.sh`（~48 参数：端口/模式/TUN/DNS/Sniffer/认证/Meta/GEO/Smart/Dashboard/NTP/CORS/IPv6/routing-mark）→ ② `yml_rules_change.sh`（14 参数：BT 直连规则、url-test 覆写、自定义规则注入、smart 组转换）→ ③ `YAML.overwrite_run()` 执行覆写模块（先 `[YAML]` 后 `[Overwrite]`）→ ④ `custom/openclash_custom_overwrite.sh` → ⑤ 修正 provider path 为 `./proxy_provider/<name>` |
| 4 | 启动内核 | `start_run_core()`：mv 运行配置 + procd 启动 `clash -d /etc/openclash -f <config.yaml>`；注入 env `SAFE_PATHS` / `CLASH_AGE_SECRET_KEY` / `OIX_TOKEN`；respawn `300 5 3`；rlimit `nofile=1000000`、`nproc`、`as`、`memlock=unlimited` |
| 5 | 状态检查 + 防火墙 | 等核心进程 ≤10 s；TUN 模式 `check_mod tun` + 等 `utun` 接口（≤300 s，失败重启 ≤3 次）+ 策略路由（fwmark `0x162` → table `0x162`，pref 999）；非 TUN 轮询 `/group` 返回 200（≤300 s）；就绪后 `change_dnsmasq()` 做 DNS 劫持、`set_firewall()` 建 REDIRECT/TPROXY、DNS 劫持、访问控制、QUIC 阻断、中国 IP 绕行与 IPv6 链 |
| 6 | 定时任务 + 守护 | `add_cron()`：每条订阅独立 cron（`openclash.sh '<name>'`，非整分间隔走 `loop <interval>` 时间戳守卫）、GEO、chnroute、定时重启、覆写模块下载；`service_started()` 注册独立 procd 服务 `openclash-watchdog`（核心存活 + 流媒体解锁）；非 TUN 且 dhcpv6 未禁用时告警；清理 `/tmp/yaml_*` |

## 停止流程（`stop_service()`）

1. 备份策略组状态历史
2. `revert_firewall()` 清防火墙规则
3. kill `clash` 与 streaming unlock 进程，发 TERM 结束看门狗
4. `revert_dnsmasq()` 恢复 DNS
5. `del_cron()` 清除定时任务

## 热生效 vs 需重启

| 操作 | 方式 | 延迟 |
|------|------|------|
| 切换代理模式（rule/global/direct） | API `PATCH /configs`（mode） | 即时 |
| 切换日志级别 | API `PATCH /configs`（log-level） | 即时 |
| 切换 Sniffer / Rules | API `PATCH /configs` | 即时 |
| 改端口 / TUN / DNS / 覆写 | 重启核心（重写 YAML） | ~3–5 s |
| 改防火墙规则 | `/etc/init.d/openclash reload` | 即时 |
| 改访问控制 | 重启（重建防火墙链） | ~5 s |
