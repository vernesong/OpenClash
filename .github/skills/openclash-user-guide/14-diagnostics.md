## 诊断命令与 CLI 参考

> **用途**: 诊断决策树、CLI 命令、脚本速查与 AI 自助 SSH 诊断/覆写修复（§14.1–14.8）。
> **交互模式**: AI 给命令 → 用户粘到路由器终端执行 → 回贴输出 → AI 分析下一步。命令按安全等级标注：🟢 安全查询 / 🟡 有副作用 / 🔴 高风险，优先给 🟢，🟡🔴 需附风险说明。
> **执行位置**: §14.2–14.4 的全部命令都在**路由器端**执行（SSH 或 LuCI「系统→终端」）；本机没有 `nft`/`uci`/`opkg`。AI 自助时逐条 `ssh ... '<cmd>'`，见 §14.5。

### 14.1 使用方法

发给用户的格式：

```bash
# 复制此命令到路由器终端执行
<命令>
```

接入方式：`ssh root@<router_ip>`，或 LuCI「系统 → 终端」。

### 14.2 诊断决策树

> 按症状选子节，逐步执行，每步按输出决定下一步。

#### 14.2.1 无法访问外网

| 步骤 | 命令 | 安全 | 期望 | 异常处理 |
|------|------|------|------|----------|
| 1 核心运行 | `pidof clash` | 🟢 | 返回 PID | 无 → §14.2.6 |
| 2 代理模式 | `curl -s http://127.0.0.1:9090/configs \| grep '"mode"'` | 🟢 | `"mode": "rule"` | `direct` → 切回 rule |
| 3 TCP 链 | `nft list chain inet fw4 openclash 2>/dev/null \| head -20` | 🟢 | 含 `redirect to 7892` | 链不存在 → `/etc/init.d/openclash reload` |
| 4 策略路由 | `ip rule show \| grep 0x162` | 🟢 | `fwmark 0x162 lookup 0x162` | TUN 必须；无 → 重启核心 |
| 5 错误日志 | `tail -30 /tmp/openclash.log \| grep -E 'level=(error\|fatal)'` | 🟢 | 无输出 | 有 → 对照 `03-errors.md` |

#### 14.2.2 DNS 解析异常

| 步骤 | 命令 | 安全 | 期望 | 异常处理 |
|------|------|------|------|----------|
| 1 DNS 端口 | `netstat -tlnp \| grep 7874` | 🟢 | `0.0.0.0:7874` 监听 | 无 → 核心 DNS 未正常启动 |
| 2 DNS 劫持 | `nft list chain inet fw4 dstnat 2>/dev/null \| grep 'OpenClash DNS'` | 🟢 | 含 `redirect` | 无 → 检查 `enable_redirect_dns` |
| 3 dnsmasq | `uci show dhcp.@dnsmasq[0] \| grep -E 'server\|noresolv'` | 🟢 | `server=127.0.0.1#7874` | 非此 → 转发链路断开 |
| 4 解析测试 | `nslookup www.google.com 127.0.0.1` | 🟢 | Fake-IP 下返回 `198.18.x.x` | 返回真实 IP → Fake-IP 未生效；无响应 → 服务异常 |
| 5 dnsmasq 版本 | `dnsmasq --version \| head -1` | 🟢 | 含 `full` 或 ipset/nftset | 精简版 → 换 `dnsmasq-full` |

#### 14.2.3 访问控制问题

| 步骤 | 命令 | 安全 | 期望 | 异常处理 |
|------|------|------|------|----------|
| 1 AC 模式 | `uci get openclash.@openclash[0].lan_ac_mode` | 🟢 | `0` 黑名单 / `1` 白名单 | 确认与预期一致 |
| 2 黑名单 set | `nft list set inet fw4 lan_ac_black_ips 2>/dev/null` | 🟢 | 含目标 IP | 空 → 未添加 |
| 3 白名单 set | `nft list set inet fw4 lan_ac_white_ips 2>/dev/null` | 🟢 | 含目标 IP | 白名单下非白名单设备全部 RETURN |
| 4 规则顺序 | `nft list chain inet fw4 openclash \| grep -E 'saddr\|ether saddr'` | 🟢 | AC 规则在代理规则之前 | 顺序异常 → 重载防火墙 |

> DNS 路径：`enable_redirect_dns=2` 自动满足；`=0` 时切换分流会提示（代理侧始终提示，直连侧仅 Fake-IP 提示）。各模式影响与锁定规则见 `09-settings-dns-ac-ipv6.md` §9.2。

#### 14.2.4 TUN 模式启动失败

| 步骤 | 命令 | 安全 | 期望 | 异常处理 |
|------|------|------|------|----------|
| 1 内核模块 | `lsmod \| grep tun` | 🟢 | `tun` 已加载 | 无 → 装 `kmod-tun` |
| 2 TUN 设备 | `ip link show utun` | 🟢 | `utun: <POINTOPOINT>` | 不存在 → 查启动日志 |
| 3 策略路由 | `ip rule show \| grep 0x162` | 🟢 | `fwmark 0x162 lookup 0x162` | 无 → TUN 必须 |
| 4 路由表 | `ip route show table 0x162` | 🟢 | `default dev utun` | 空 → TUN 未关联路由 |
| 5 TUN 转发 | `nft list chain inet fw4 forward \| grep utun` | 🟢 | `oifname utun accept` | 无 → 重载防火墙 |

#### 14.2.5 节点连接问题

| 步骤 | 命令 | 安全 | 期望 | 异常处理 |
|------|------|------|------|----------|
| 1 节点状态 | `curl -s http://127.0.0.1:9090/proxies \| grep -E '"name"\|"history"' \| head -20` | 🟢 | 含延迟数据 | 全超时 → 查网络/节点 |
| 2 代理模式 | `curl -s http://127.0.0.1:9090/configs \| grep '"mode"'` | 🟢 | `rule` 或 `global` | `direct` → 全直连 |
| 3 连接列表 | `curl -s http://127.0.0.1:9090/connections \| head -30` | 🟢 | 含 `chains` | 无连接 → 确认有流量经过 |
| 4 QUIC 阻断 | `nft list chain inet fw4 input \| grep 'QUIC REJECT'` | 🟢 | 含 `udp dport 443 reject` | Hysteria 问题 → 先试 `disable_quic_go_gso` |
| 5 错误日志 | `tail -30 /tmp/openclash.log \| grep -iE 'error\|timeout\|refused\|reset\|fatal'` | 🟢 | 无输出 | 有 → 对照 `03-errors.md` |

#### 14.2.6 配置 / 启动失败

| 步骤 | 命令 | 安全 | 期望 | 异常处理 |
|------|------|------|------|----------|
| 1 启动日志 | `tail -30 /tmp/openclash_start.log` | 🟢 | 含 `Start Successful` | `Core Start Failed` → 步骤 3 |
| 2 UCI enable | `uci get openclash.@openclash[0].enable` | 🟢 | `1` | `0` → 插件被禁用 |
| 3 YAML 验证 | `/etc/openclash/clash -t -d /etc/openclash -f $(uci get openclash.@openclash[0].config_path)` | 🟡 | `configuration is ok` | 报错 → 对照 `03-errors.md` |
| 4 Ruby | `ruby -ryaml -e 'puts "ok"'` | 🟢 | `ok` | 报错 → 装 `ruby` `ruby-yaml` `ruby-psych` |
| 5 依赖 | `opkg list-installed \| grep -E 'ruby\|dnsmasq-full\|kmod-tun\|kmod-nft-tproxy\|curl\|ca-bundle\|ip-full\|unzip'` | 🟢 | 8 个包都在 | 缺 → 安装 |
| 6 调试日志 | `/usr/share/openclash/openclash_debug.sh` | 🟡 | 生成 `/tmp/openclash_debug.log` | 含 `## 依赖检查` 章节 |

#### 14.2.7 TFO（TCP Fast Open）未生效 / 异常

> **机理**: 内核判定 TFO 异常（连续 3 次超时或异常乱序 FIN/RST，多由中间盒引起）会**全局暂停主动 TFO**，停用时长 = `tcp_fastopen_blackhole_timeout_sec` × 2^min(触发次数-1, 6)（最大 64 倍）；期间新连接照常建立，只是不带 SYN 数据与 cookie。默认值按版本：≤5.13 为 `3600`（一次触发可停用数十小时），≥5.14 为 `0`（上游因误触发频繁而禁用）。OpenClash 在 `start_run_core()` 统一写 `0`。

| 步骤 | 命令 | 安全 | 期望 | 异常处理 |
|------|------|------|------|----------|
| 1 基础开关 | `cat /proc/sys/net/ipv4/tcp_fastopen` | 🟢 | 带客户端位（`1`/`3` 等奇数） | `0`/`2` → 客户端 TFO 未启用 |
| 2 黑洞超时 | `cat /proc/sys/net/ipv4/tcp_fastopen_blackhole_timeout_sec` | 🟢 | `0` | 非 0：旧内核默认 3600 会让 TFO 停用数十小时；下次核心启动会写回 0 |
| 3 触发计数 | `awk 'NR%2==1{for(i=1;i<=NF;i++)h[i]=$i} NR%2==0{for(i=1;i<=NF;i++) if(h[i]~/FastOpen/) printf "%s=%s ",h[i],$i; print ""}' /proc/net/netstat` | 🟢 | 关注 `TCPFastOpenBlackhole`（触发次数）与 `TCPFastOpenActive`（数据入 SYN 的连接数） | `Active` 不增而 `Blackhole` 持续增 → TFO 被停用或线路不友好（值为 0 时 Blackhole 不再增长，只看 Active） |
| 4 关闭 `tfo` 观察 | 对该节点去掉 `tfo: true` | 🟢 | 表现一致或更稳 | 明显更稳 → 线路对 TFO 不友好，保持关闭 |

### 14.3 通用诊断命令

**🟢 安全查询**:

| 命令 | 用途 |
|------|------|
| `pidof clash` | 核心是否运行 |
| `/etc/openclash/clash -v` | 核心版本 |
| `uci show openclash \| grep <key>` | 查特定 UCI 配置 |
| `tail -50 /tmp/openclash.log` | 运行日志 |
| `nft list chain inet fw4 openclash` | TCP 透明代理链 |
| `nft list chain inet fw4 openclash_mangle` | UDP TPROXY 链 |
| `nft list chain inet fw4 dstnat \| grep 'OpenClash DNS'` | DNS 劫持规则 |
| `nft list set inet fw4 china_ip_route \| head -5` | 大陆 IP set |
| `ip rule show \| grep 0x162` | 策略路由 |
| `lsmod \| grep -E 'tun\|nft_tproxy\|inet_diag'` | 内核模块 |
| `dnsmasq --version \| head -1` | dnsmasq 版本（需 full） |
| `netstat -tlnp \| grep -E '7874\|7892\|7895\|9090'` | 端口监听 |
| `df -h /etc/openclash` / `free -m` | 磁盘 / 内存 |

**🟡 有副作用**:

| 命令 | 用途 | 副作用 |
|------|------|--------|
| `/etc/init.d/openclash reload` | 重载防火墙 | 不影响已有连接 |
| `/usr/share/openclash/openclash_debug.sh` | 生成调试日志 | 写 `/tmp/openclash_debug.log` |
| `/usr/share/openclash/openclash_geo.sh <type>` | 更新 GEO（`ipdb\|geoip\|geosite\|geoasn\|all`） | 替换文件 |
| `/usr/share/openclash/openclash_chnroute.sh` | 更新大陆路由 | 替换 set |
| `openclash_history_get.sh close_all_conection` | 断开所有连接 | 中断活跃连接 |
| `POST /cache/{fakeip,dns}/flush` | 清 Fake-IP / DNS 缓存 | DNS 重新解析 |
| `POST /cache/smart/flush` | 清 Smart 缓存 | 强制重评估节点 |
| `PATCH /configs -d '{"mode":"rule"}'` | 热切代理模式 | 立即影响所有客户端 |

**🔴 高风险**:

| 命令 | 风险 |
|------|------|
| `/etc/init.d/openclash restart` | 全网断流 3–5 秒 |
| `/etc/init.d/openclash stop` | 全网断流 |
| `openclash.sh <name>` | 更新订阅：替换配置 + 自动重启 |
| `openclash_core.sh Meta` | 更新核心：下载 + 替换 + 重启 |
| `openclash_update.sh [one_key_update]` | 更新插件 / 一键更新（含重启） |
| `uci set ... && uci commit openclash` | 可能打断正常服务 |

> 完整 LuCI / Mihomo API 命令与返回值见 `15-api.md`。

### 14.4 Shell 脚本速查

> 路径前缀 `/usr/share/openclash/`，路由器端执行。

#### 14.4.1 用户可直调

| 脚本 / 命令 | 用途 | 安全 |
|-------------|------|------|
| `openclash_debug.sh` | 生成完整调试日志（30 章节） | 🟡 |
| `openclash_geo.sh ipdb\|geoip\|geosite\|geoasn\|all` | 更新对应 GEO 数据 | 🟡 |
| `openclash_chnroute.sh` | 下载中国 IPv4/IPv6 CIDR 并转为 set | 🟡 |
| `openclash_version.sh [cdn]` | 检查最新版本（写 `/tmp/clash_last_version`），可传 CDN | 🟢 |
| `openclash_download_dashboard.sh <名称> <来源>` | 下载仪表盘：`Zashboard Official` / `Metacubexd Official` / `Yacd Official` / `Yacd Meta` | 🟡 |
| `openclash_lgbm.sh` | 手动下载最新 LGBM 模型 | 🟡 |
| `openclash_history_get.sh close_all_conection` | 关闭所有代理连接 | 🟡 |
| `/etc/init.d/openclash reload` | 重载防火墙（不重启核心） | 🟡 |
| `openclash.sh <配置名>` | 更新单个订阅（替换 + 自动重启） | 🔴 |
| `openclash_core.sh Meta [cdn]` | 下载并替换 Meta 核心 | 🔴 |
| `openclash_update.sh [one_key_update] [cdn]` | 更新插件 / 一键更新 | 🔴 |
| `/etc/init.d/openclash restart\|stop` | 重启 / 停止核心 | 🔴 |

#### 14.4.2 内部脚本（不建议直调）

| 脚本 | 调用者 | 功能 |
|------|--------|------|
| `yml_change.sh` | init.d | Ruby 改 YAML（端口/模式/DNS/TUN/Sniffer/Meta） |
| `yml_rules_change.sh` | init.d | Ruby 改 YAML（规则/Provider/URL-Test/Smart） |
| `openclash_watchdog.sh` | init.d（独立 procd 服务 `openclash-watchdog`） | 核心存活 + 防火墙完整性检查 |
| `openclash_custom_domain_dns.sh` | init.d | 自定义域名 DNS |
| `openclash_debug_dns.lua` / `openclash_debug_getcon.lua` | Web UI | DNS 解析测试 / 活动连接获取 |
| `openclash_streaming_unlock.lua` | 看门狗 | 流媒体解锁切换 |
| `openclash_sub_parser.lua` | 看门狗 | 订阅格式解析 |

### 14.5 认证前置（SSH）

> 所有「AI 通过 SSH 操作 OpenWrt」的场景都先按本节执行；§14.6、§14.7 直接引用本节。

- **接入**: `ssh <用户>@<路由器IP>`（默认 22），或 LuCI「系统 → 终端」。用户提供用户名、密码（如 `root`）与 IP/端口
- **优先公钥**（避免交互阻塞、避免密码落盘）：AI 侧执行 `ssh-keygen -t ed25519 -N ''`（如无密钥）→ `ssh-copy-id -p <端口> root@<IP>`；dropbear 可手动把公钥追加到 `/etc/dropbear/authorized_keys` 并 `chmod 600` → 之后免密登录
- **仅密码时**: AI **不得**把密码写入文件/命令行/覆写内容；`ssh ...` 阻塞于 `password:` 时让用户**手动输入**，AI 不代填不回显
- **执行模型**: 逐条 `ssh ... '<远程命令>'` 一次取回输出；命令落在路由器端。Windows/PowerShell 下含 `$`/`;`/`&&`/花括号/`awk/sed`/嵌套引号或换行的命令改用 stdin 或临时脚本，不要一行内联
- **凭据红线**: 密码/私钥仅用于本次认证，不回显、不写入 `uci`、不进覆写内容、不提交仓库
- **授权前提**: 用户提供凭据即视为同意；未提供前不执行任何命令

### 14.6 AI 自主 SSH 诊断（需用户确认）

> 调试日志不足以定位、且用户希望 AI 直接操作时，AI 可自主登录执行 §14.2–14.4 与 `15-api.md` §15.1–15.2 中**已列出**的命令并分析。

- **安全分级执行**: 🟢 直接执行；🟡 直接执行但说明影响；🔴（`restart`/`stop`、更新订阅/内核/插件、`uci set/commit` 改现有配置）**必须先说明后果并获用户明确同意**，不同意则跳过
- **流程**: ① 登录后先自主跑 `openclash_debug.sh` 并读 `/tmp/openclash_debug.log`；② 日志不足再按命令表逐条诊断

**铁律**:

1. **只执行已知命令** —— 必须出自 §14.2–14.4 与 `15-api.md` §15.1–15.2（或其直接查询变体），不编造
2. **默认不改现有配置** —— 修改现有配置属 🔴 需确认；**新建**覆写模块（§14.7）属修复动作，`enable` 恒 0
3. **常规修复走覆写模块** —— 需要改插件设置/覆写 YAML 时必须走 §14.7，而非直接改配置
4. **一次一命令** —— 执行 → 分析 → 决定下一步；输出不足就回到日志或询问用户
5. **分析并归因** —— 结合链结构、错误速查与决策树定位根因；覆写类修复走 §14.7，需重启/改 UCI 先确认
6. **收尾** —— 给结论与建议，不残留后台进程、不静默改变系统状态

### 14.7 用覆写模块修复（AI 写入、用户启用）

> 需要「改插件设置 / 覆写订阅配置」才能解决时，AI **不动用户现有配置**，而是按 `16/17-overwrite-module-*.md` 生成**新模块**写入路由器（`enable=0`），只把「启用」留给用户。

1. **生成内容**: 必须含段头（`[General]`/`[YAML]`/`[Overwrite]`），遵循 `16-overwrite-module-format.md` §16.2.3 操作符与 §16.2.2 函数清单；涉及规则/rule-providers 时另对照 `11-overwrite-settings.md` §11.6 并用 meta-rules-dat 确认 GEOSITE/GEOIP 分类名与 `.mrs` 地址
   > 子文档读取：本地用 `read_file`；远程取 raw URL `https://raw.githubusercontent.com/vernesong/OpenClash/dev/.github/skills/openclash-user-guide/<文件名>`
2. **写入文件**:

   ```sh
   mkdir -p /etc/openclash/overwrite
   cat > /etc/openclash/overwrite/<模块名> <<'EOF'
   [YAML]
   ...（覆写内容）
   EOF
   chmod 644 /etc/openclash/overwrite/<模块名>
   chown root:root /etc/openclash/overwrite/<模块名>
   ```

   单引号 `<<'EOF'` 防变量展开；内容含 `EOF` 行时换唯一分隔符（如 `OPENCLASH_OVERWRITE_END`）；模块名用无空格 ASCII 名，与 `config_overwrite.name` 一致

3. **注册 UCI**（`config` 匹配当前配置，如 `all` 或具体路径）:

   ```sh
   max=$(uci -q show openclash 2>/dev/null | grep '=config_overwrite' | awk -F'[.=]' '{print $2}' | while read -r sid; do uci -q get "openclash.$sid.order" 2>/dev/null; done | sort -n | tail -1)
   order=$(( ${max:-0} + 1 ))

   uci add openclash config_overwrite
   uci set openclash.@config_overwrite[-1].name='<模块名>'
   uci set openclash.@config_overwrite[-1].type='file'
   uci add_list openclash.@config_overwrite[-1].config='all'
   uci set openclash.@config_overwrite[-1].enable='0'
   uci set openclash.@config_overwrite[-1].order="$order"
   uci commit openclash
   ```

   `config` 是 ListValue 用 `add_list`；`order` 必须实算（取现有最大值 +1），不要用字面量

4. **启用权留给用户**: AI 不设 `enable=1`、不代重启；完成后告知用户到「运行状态页 → 覆写模块」启用，启用前不生效

**铁律**:

1. **只新建不改已有** —— 不动用户已有模块、`/etc/config/openclash` 其它段、订阅 YAML、`yml_change.sh`
2. **`enable` 恒为 0**
3. **严格遵循 16/17** —— 段头必须有；`config` 须匹配当前配置（为空则永不生效，见 `17-overwrite-module-examples.md` §17.5）；规则类另对照 `11-overwrite-settings.md` §11.6
4. **范围边界** —— 覆写只覆盖 YAML/UCI 层；需重启核心、改防火墙、改 dnsmasq 的给出 LuCI 路径，或经确认后执行 🔴
5. **风险提示** —— 覆写会覆盖「插件强制覆盖/禁用」的硬编码项（`allow-lan`、`sniffer.sniff` 等）时必须提示后果（`16-overwrite-module-format.md` §16.1）
6. **写入即告知** —— 报告模块名、内容摘要与 `config` 匹配，并提醒「启用权在你」

### 14.8 Mihomo Wiki 参考链接

[全局配置](https://wiki.metacubex.one/config/general/) · [DNS](https://wiki.metacubex.one/config/dns/) · [TUN](https://wiki.metacubex.one/config/inbound/tun/) · [Sniffer](https://wiki.metacubex.one/config/sniff/) · [路由规则](https://wiki.metacubex.one/config/rules/) · [代理协议](https://wiki.metacubex.one/config/proxies/) · [完整配置示例](https://github.com/MetaCubeX/mihomo/blob/Meta/docs/config.yaml)
