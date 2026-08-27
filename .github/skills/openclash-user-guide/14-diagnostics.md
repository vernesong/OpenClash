## 诊断命令与 CLI 参考

> **用途**: 诊断决策树、CLI 命令、Shell 脚本速查与 AI 自助 SSH 诊断/覆写修复（§14.1–14.8）。

> **小节索引**: §14.1 使用方法 · §14.2 诊断决策树（§14.2.1–14.2.6）· §14.3 通用命令 · §14.4 脚本速查 · §14.5 认证前置 · §14.6 AI 自主诊断 · §14.7 覆写修复 · §14.8 Wiki 链接

> **排障交互**: 当用户描述问题但缺少关键信息时，AI 应给出精确的 SSH 命令让用户在路由器上执行，
> 然后根据用户返回的输出结果进行诊断。
>
> **交互模式**: AI 给出命令 → 用户复制到路由器终端执行 → 用户粘贴输出 → AI 分析并决定下一步。
> 命令按安全等级标注：🟢 安全查询 / 🟡 有副作用 / 🔴 高风险。AI 应优先推荐 🟢 命令，
> 对 🟡/🔴 命令应附带风险说明。

### 14.1 使用方法

AI 会将以下格式的命令发给用户：

```bash
# 复制此命令到路由器终端执行
<命令>
```

用户执行后把输出粘贴回对话，AI 根据输出判断问题并给出下一步指令。

> **路由器终端接入方式**: SSH 登录 (`ssh root@<router_ip>`) 或 LuCI 自带的「系统→终端」页面。
> 如用户不确定如何登录，AI 应告知上述两种方式供选择。
>
> **命令执行位置**: §14.2–§14.4 列出的全部命令均在**路由器端**执行（SSH 登录后或 LuCI 终端内）；
> **不要**在本机（如 Windows PowerShell）直接运行 `nft`/`uci`/`opkg`/... —— 本机没有这些工具。
> AI 自助时按「逐条 `ssh ... '<cmd>'`」远程执行，见 §14.5。

### 14.2 诊断决策树

> AI 根据用户症状选择对应子节，按步骤顺序执行命令，每步根据输出决定下一步。

#### 14.2.1 无法访问外网

| 步骤 | 命令 | 安全 | 期望输出 | 异常处理 |
|------|------|------|----------|----------|
| 1. 核心运行 | `pidof clash` | 🟢 | 返回 PID | 无→跳 §14.2.6 |
| 2. 代理模式 | `curl -s http://127.0.0.1:9090/configs \| grep '"mode"'` | 🟢 | `"mode": "rule"` | `"direct"`→切换为 rule |
| 3. TCP 代理链 | `nft list chain inet fw4 openclash 2>/dev/null \| head -20` | 🟢 | 含 `redirect to 7892` | 链不存在→`/etc/init.d/openclash reload` |
| 4. 策略路由 | `ip rule show \| grep 0x162` | 🟢 | `fwmark 0x162 lookup 0x162` | TUN 模式必须；无→重启核心 |
| 5. 错误日志 | `tail -30 /tmp/openclash.log \| grep -E 'level=(error\|fatal)'` | 🟢 | 无输出 | 有→对照「日志与错误信息速查」 |

#### 14.2.2 DNS 解析异常

| 步骤 | 命令 | 安全 | 期望输出 | 异常处理 |
|------|------|------|----------|----------|
| 1. DNS 端口 | `netstat -tlnp \| grep 7874` | 🟢 | `0.0.0.0:7874` 在监听 | 无→核心未正常启动 DNS |
| 2. DNS 劫持 | `nft list chain inet fw4 dstnat 2>/dev/null \| grep 'OpenClash DNS'` | 🟢 | 含 `redirect` 规则 | 无→检查 `enable_redirect_dns` UCI |
| 3. dnsmasq 配置 | `uci show dhcp.@dnsmasq[0] \| grep -E 'server\|noresolv'` | 🟢 | `server=127.0.0.1#7874` | 非此→DNS 转发链路断开 |
| 4. 解析测试 | `nslookup www.google.com 127.0.0.1` | 🟢 | Fake-IP 模式返回 `198.18.x.x` | 返回真实IP→Fake-IP 未生效；无响应→服务异常 |
| 5. dnsmasq | `dnsmasq --version \| head -1` | 🟢 | 含 `full` 或 ipset/nftset | 精简版→换 `dnsmasq-full` |

#### 14.2.3 访问控制问题（某设备不走/走了代理）

| 步骤 | 命令 | 安全 | 期望输出 | 异常处理 |
|------|------|------|----------|----------|
| 1. AC 模式 | `uci get openclash.@openclash[0].lan_ac_mode` | 🟢 | `0`(黑名单) 或 `1`(白名单) | 确认与用户预期一致 |
| 2. 黑名单 set | `nft list set inet fw4 lan_ac_black_ips 2>/dev/null` | 🟢 | 含目标设备 IP | set 为空→未添加 |
| 3. 白名单 set | `nft list set inet fw4 lan_ac_white_ips 2>/dev/null` | 🟢 | 含目标设备 IP | 白名单模式非白名单设备全部 RETURN |
| 4. 规则确认 | `nft list chain inet fw4 openclash \| grep -E 'saddr\|ether saddr'` | 🟢 | AC 规则在代理规则之前 | 顺序异常→重载防火墙 |

#### 14.2.4 TUN 模式启动失败

| 步骤 | 命令 | 安全 | 期望输出 | 异常处理 |
|------|------|------|----------|----------|
| 1. 核心模块 | `lsmod \| grep tun` | 🟢 | `tun` 模块已加载 | 无→安装 `kmod-tun` |
| 2. TUN 设备 | `ip link show utun` | 🟢 | `utun: <POINTOPOINT>` | 不存在→检查启动日志 |
| 3. 策略路由 | `ip rule show \| grep 0x162` | 🟢 | `fwmark 0x162 lookup 0x162` | 无→TUN 模式必须 |
| 4. 路由表 | `ip route show table 0x162` | 🟢 | `default dev utun` | 空表→TUN 设备未关联路由 |
| 5. TUN 转发 | `nft list chain inet fw4 forward \| grep utun` | 🟢 | `oifname utun accept` | 无→重载防火墙 |

#### 14.2.5 节点连接问题

| 步骤 | 命令 | 安全 | 期望输出 | 异常处理 |
|------|------|------|----------|----------|
| 1. 节点状态 | `curl -s http://127.0.0.1:9090/proxies \| grep -E '"name"\|"history"' \| head -20` | 🟢 | 含延迟数据 | 全部超时→检查网络/节点可用性 |
| 2. 代理模式 | `curl -s http://127.0.0.1:9090/configs \| grep '"mode"'` | 🟢 | `rule` 或 `global` | `direct`→所有流量直连 |
| 3. 连接列表 | `curl -s http://127.0.0.1:9090/connections \| head -30` | 🟢 | 含 `chains` 代理链 | 无连接→确认有流量经过 |
| 4. QUIC(GSO) | `nft list chain inet fw4 input \| grep 'QUIC REJECT'` | 🟢 | 含 `udp dport 443 reject` | Hysteria 节点问题→先试 `disable_quic_go_gso` |
| 5. 错误日志 | `tail -30 /tmp/openclash.log \| grep -iE 'error\|timeout\|refused\|reset\|fatal'` | 🟢 | 无输出 | 有→对照「日志与错误信息速查」 |

#### 14.2.6 配置/启动失败

| 步骤 | 命令 | 安全 | 期望输出 | 异常处理 |
|------|------|------|----------|----------|
| 1. 启动日志 | `tail -30 /tmp/openclash_start.log` | 🟢 | 含 `Start Successful` | `Core Start Failed`→跳本节步骤 3（YAML 验证） |
| 2. UCI enable | `uci get openclash.@openclash[0].enable` | 🟢 | `1` | `0`→插件被禁用 |
| 3. YAML 验证 | `/etc/openclash/clash -t -d /etc/openclash -f $(uci get openclash.@openclash[0].config_path)` | 🟡 | `configuration is ok` | 报错→对照「日志与错误信息速查」 |
| 4. Ruby 检查 | `ruby -ryaml -e 'puts "ok"'` | 🟢 | `ok` | 报错→安装 `ruby` `ruby-yaml` `ruby-psych` |
| 5. 依赖检查 | `opkg list-installed \| grep -E 'ruby\|dnsmasq-full\|kmod-tun\|kmod-nft-tproxy\|curl\|ca-bundle\|ip-full\|unzip'` | 🟢 | 8 个包均已安装 | 缺失→安装对应包 |
| 6. 调试日志 | `/usr/share/openclash/openclash_debug.sh` | 🟡 | 生成 `/tmp/openclash_debug.log` | 日志含 `## 依赖检查` 章节 |

### 14.3 通用诊断命令

> 不限于特定症状的快速检查命令。

**🟢 安全查询（纯查询，零副作用）：**

| 命令 | 用途 |
|------|------|
| `pidof clash` | 核心是否运行 |
| `/etc/openclash/clash -v` | 核心版本 |
| `uci show openclash \| grep <key>` | 查特定 UCI 配置 |
| `tail -50 /tmp/openclash.log` | 运行日志 |
| `nft list chain inet fw4 openclash` | TCP 透明代理规则链 |
| `nft list chain inet fw4 openclash_mangle` | UDP TPROXY 规则链 |
| `nft list chain inet fw4 dstnat \| grep 'OpenClash DNS'` | DNS 劫持规则 |
| `nft list set inet fw4 china_ip_route \| head -5` | 大陆 IP set |
| `ip rule show \| grep 0x162` | 策略路由 |
| `lsmod \| grep -E 'tun\|nft_tproxy\|inet_diag'` | 内核模块 |
| `dnsmasq --version \| head -1` | dnsmasq 版本（需 full 版） |
| `netstat -tlnp \| grep -E '7874\|7892\|7895\|9090'` | 端口监听 |
| `df -h /etc/openclash` | 磁盘空间 |
| `free -m` | 内存使用 |

**🟡 有副作用（可逆或影响较小）：**

| 命令 | 用途 | 副作用 |
|------|------|--------|
| `/etc/init.d/openclash reload` | 重载防火墙 | 不影响已有连接 |
| `/usr/share/openclash/openclash_debug.sh` | 生成调试日志 | 写 `/tmp/openclash_debug.log` |
| `/usr/share/openclash/openclash_geo.sh <type>` | 更新 GEO | 替换文件；type=`ipdb\|geoip\|geosite\|geoasn\|all` |
| `/usr/share/openclash/openclash_chnroute.sh` | 更新大陆路由 | 替换 ipset/nft set |
| `/usr/share/openclash/openclash_history_get.sh close_all_conection` | 断开所有连接 | 中断活跃代理连接 |
| `curl -X POST http://127.0.0.1:9090/cache/fakeip/flush` | 清空 Fake-IP | DNS 重新解析 |
| `curl -X POST http://127.0.0.1:9090/cache/dns/flush` | 清空 DNS | DNS 重新解析 |
| `curl -X POST http://127.0.0.1:9090/cache/smart/flush` | 清空 Smart | 强制重评估节点 |
| `curl -X PATCH http://127.0.0.1:9090/configs -d '{"mode":"rule"}'` | 热切换代理模式 | 立即影响所有客户端 |

**🔴 高风险（不可逆或影响全网）：**

| 命令 | 用途 | 风险 |
|------|------|------|
| `/etc/init.d/openclash restart` | 重启核心 | 全网断流 3-5 秒 |
| `/etc/init.d/openclash stop` | 停止核心 | 全网断流 |
| `/usr/share/openclash/openclash.sh <name>` | 更新订阅 | 替换配置+自动重启 |
| `/usr/share/openclash/openclash_core.sh Meta` | 更新核心 | 下载+替换+重启 |
| `/usr/share/openclash/openclash_update.sh` | 更新插件 | 替换 IPK |
| `/usr/share/openclash/openclash_update.sh one_key_update` | 一键更新 | 核心+插件+订阅+GEO+重启 |
| `uci set openclash.@openclash[0].<key>=<value> && uci commit openclash` | 修改 UCI | 可能打断正常服务 |

> 完整 LuCI/Mihomo API 命令与返回值解读见 `15-api.md`（§15.1–15.2）。

### 14.4 Shell 脚本速查

> 所有脚本路径以 `/usr/share/openclash/` 为前缀，需在路由器终端执行。

#### 14.4.1 用户可直调的脚本

```bash
# --- 诊断 ---
# 生成完整调试日志（输出到 /tmp/openclash_debug.log，含依赖检查、防火墙规则、配置等 30 个章节）
/usr/share/openclash/openclash_debug.sh

# --- GEO 数据库更新 ---
# 更新 GeoIP MMDB 数据库
/usr/share/openclash/openclash_geo.sh ipdb
# 更新 GeoIP Dat 数据库
/usr/share/openclash/openclash_geo.sh geoip
# 更新 GeoSite 数据库
/usr/share/openclash/openclash_geo.sh geosite
# 更新 Geo ASN 数据库
/usr/share/openclash/openclash_geo.sh geoasn
# 更新全部 GEO 数据库
/usr/share/openclash/openclash_geo.sh all

# --- 大陆路由更新 ---
# 下载最新中国 IPv4/IPv6 CIDR 列表并转换为 nftables set / ipset
/usr/share/openclash/openclash_chnroute.sh

# --- 版本检查 ---
# 检查最新版本信息（结果写入 /tmp/clash_last_version）
/usr/share/openclash/openclash_version.sh
# 使用 CDN 加速检查
/usr/share/openclash/openclash_version.sh https://testingcf.jsdelivr.net/

# --- 仪表盘下载 ---
# 下载 Zashboard（推荐）
/usr/share/openclash/openclash_download_dashboard.sh Zashboard Official
# 下载 Metacubexd
/usr/share/openclash/openclash_download_dashboard.sh Metacubexd Official
# 下载 Yacd
/usr/share/openclash/openclash_download_dashboard.sh Yacd Official
# 下载 Yacd（Meta 分支）
/usr/share/openclash/openclash_download_dashboard.sh Yacd Meta

# --- LightGBM 模型 ---
# 手动下载最新 LightGBM 模型
/usr/share/openclash/openclash_lgbm.sh

# --- 连接管理 ---
# 关闭所有代理连接
/usr/share/openclash/openclash_history_get.sh close_all_conection

# --- 服务控制 ---
# 重载防火墙规则（不重启核心，不影响已有连接）
/etc/init.d/openclash reload

# --- 🔴 以下命令会触发重启或替换文件，需谨慎 ---

# 更新单个订阅配置（替换 <配置文件名>，不含路径和扩展名）
/usr/share/openclash/openclash.sh <配置文件名>

# 下载并替换 Meta 核心（使用默认 GitHub 地址）
/usr/share/openclash/openclash_core.sh Meta
# 下载并替换 Meta 核心（使用 CDN 加速）
/usr/share/openclash/openclash_core.sh Meta https://testingcf.jsdelivr.net/

# 更新 luci-app-openclash 插件
/usr/share/openclash/openclash_update.sh
# 一键更新（核心+插件+订阅+GEO，使用 CDN 加速）
/usr/share/openclash/openclash_update.sh one_key_update https://testingcf.jsdelivr.net/

# 重启核心（全网断流 3-5 秒）
/etc/init.d/openclash restart
# 停止核心（全网断流）
/etc/init.d/openclash stop
```

#### 14.4.2 内部脚本（被 init.d/看门狗调用，不建议用户直调）

| 脚本 | 调用者 | 功能 |
|------|--------|------|
| `yml_change.sh` | init.d | Ruby 修改 YAML（端口/模式/DNS/TUN/Sniffer/Meta） |
| `yml_rules_change.sh` | init.d | Ruby 修改 YAML（规则/Provider/URL-Test/Smart） |
| `openclash_watchdog.sh` | init.d | 核心存活+防火墙完整性检查 |
| `openclash_custom_domain_dns.sh` | init.d | 自定义域名 DNS |
| `openclash_debug_dns.lua` | Web UI | DNS 解析测试 |
| `openclash_debug_getcon.lua` | Web UI | 活动连接获取 |
| `openclash_streaming_unlock.lua` | 看门狗 | 流媒体解锁切换 |
| `openclash_sub_parser.lua` | 看门狗 | 订阅格式解析 |

---

### 14.5 认证前置（SSH 登录前置）

> **AI 行为指引**：本节是所有「AI 通过 SSH 操作 OpenWrt」场景的**统一认证与命令执行前置**——§14.6 自助诊断、§14.7 覆写模块写入、以及任何让 AI 登录 OpenWrt 的需求，都先读本节并按本节执行。其它小节需要 SSH 时直接引用本节，不重复描述。

**接入方式（OpenWrt 后台）**：
- SSH 登录：`ssh <用户>@<路由器IP>`（默认端口 22）；或 LuCI「系统 → 终端」页面。
- 用户需提供登录用户名、密码（如 `root` 及密码）；路由器 IP/端口可由用户提供或由 AI 询问确认。

**认证方式（优先公钥，避免交互阻塞）**：
- **优先 SSH 公钥认证**（避免交互式密码阻塞、避免密码落盘/进日志；参考 `term-cli`/`vibeshell` 的「凭据不暴露」思路）。在 AI 所在机器执行一次：
  1. `ssh-keygen -t ed25519 -N ''`（如尚无密钥）
  2. `ssh-copy-id -p <端口> root@<路由器IP>`；若 OpenWrt 用 dropbear，也可手动把公钥追加到 `/etc/dropbear/authorized_keys` 并 `chmod 600 /etc/dropbear/authorized_keys`
  3. 之后 AI 直接 `ssh -p <端口> root@<路由器IP>` 免密登录，无需处理密码提示。
- **仅密码认证时**：AI **不得**把密码写入任何文件、命令行或覆写内容；`ssh ...` 阻塞于 `password:` 时，提示用户在对应终端**手动输入密码**（参考 `term-cli` 的「人工接管密码/MFA」模型），AI 不代填、不回显。

**命令执行模型（AI 自助）**：
- 按「逐条 `ssh ... '<远程命令>'`、一次取回输出」执行；**每条命令都落在路由器端**，**不要**在本机（如 Windows PowerShell）直接运行 `nft`/`uci`/`opkg`/...（本机无这些工具）。
- **Windows/PowerShell 引号转义易错**：远程命令含 `$`、`;`、`&&`、花括号、`awk/sed`、嵌套引号或换行时，改用 stdin 或先写成临时脚本再上传执行，避免一行内联（参考 `ai_ssh_skill` 的 PowerShell 指引）。

**凭据红线**：密码/私钥仅用于本次 SSH 认证，不回显、不写入 `uci`、不进入覆写模块内容、不提交到任何仓库。

**授权前提**：用户提供凭据即视为同意 AI 登录并执行诊断；未提供凭据前 AI 一律不执行任何命令。

---

### 14.6 AI 自主 SSH 诊断与修复（需用户确认）

> **AI 行为指引**：当调试日志（`openclash_debug.sh`）不足以定位问题，且用户希望 AI 直接操作时，AI 可**自主登录 OpenWrt 后台（SSH），执行 `14-diagnostics.md`（§14.2-14.4）与 `15-api.md`（§15.1-15.2）中已列出的全部命令并分析输出**。用户只需提供登录凭据，其余连接、执行、分析、生成修复模块均由 AI 自主完成。

> **登录与认证**：先按 §14.5 认证前置执行（接入方式、公钥/密码认证、命令执行模型、凭据红线），再继续本节流程。

**命令范围（执行 `14-diagnostics.md` 与 `15-api.md` 全部已知命令）**：
- 🟢 **安全查询**：直接执行（§14.2 决策树、§14.3 查询命令、`15-api.md` §15.1/15.2 查询类 API、§14.4 只读脚本等）。
- 🟡 **有副作用**：直接执行，但向用户说明其影响。
- 🔴 **高风险操作必须事先获得用户确认**：包括 `/etc/init.d/openclash restart|stop`、更新订阅/内核/插件（`openclash.sh`/`openclash_core.sh`/`openclash_update.sh`）、`uci set/commit` 修改现有配置等。AI 必须先说明该命令的后果，**得到用户明确同意后才执行**；用户不同意则跳过。

**诊断流程（从自主生成调试日志开始，与总则排查优先级①一致）**：
1. AI 登录后**第一步先自主生成调试日志**：执行 `/usr/share/openclash/openclash_debug.sh`，读取 `/tmp/openclash_debug.log`（含依赖检查、配置、防火墙规则等 30 个章节）——由 AI 代替用户完成「先要日志」。
2. 日志不足以定位时，再按 §14.2-14.4 与 `15-api.md` §15.1-15.2 命令表逐条执行诊断（一次一命令，见行为准则 4）。

**行为准则（铁律）**：
1. **只执行已知命令**：命令必须出自 `14-diagnostics.md`（§14.2-14.4）与 `15-api.md`（§15.1-15.2）的命令表（或其直接查询变体）；不编造、不执行来源不明的命令。
2. **默认不改现有配置**：AI 自主行为不主动修改用户任何现有配置（修改现有配置属 🔴，必须经用户确认）；**新建**覆写模块（§14.7）属修复动作、不受此限，且 `enable` 恒为 0。
3. **常规修复走覆写模块**：凡需改插件设置/覆写 YAML 的修复，一律走 §14.7 新建覆写模块（AI 自主写入、用户启用），而非直接改配置。
4. **一次一命令**：单条执行 → 分析输出 → 决定下一步；输出不足时回到「先要日志」或询问用户，不要连发多条。
5. **分析并归因**：结合本指南（防火墙规则链、错误速查表、决策树）解读输出，定位根因后：覆写类修复 → §14.7；需重启/改 UCI → 先向用户确认。**修复若涉及写规则（`rules:`/`rule-providers:`），须参考 `11-overwrite-settings.md` §11.6「规则设置」与 meta-rules-dat 确认规范与分类名。**
6. **收尾**：诊断结束给出结论与建议，不残留后台进程、不静默改变系统状态。

---

### 14.7 用覆写模块修复配置（AI 自主生成并写入、用户启用）

> **AI 行为指引**：当问题根因需要「修改插件设置 / 覆写订阅配置文件」才能解决时，AI **不直接改动用户现有配置**，而是**参考「覆写模块详解」（`16/17-overwrite-module-*.md`）生成一个新建覆写模块并直接写入路由器**（`enable=0`），**仅保留「启用」给用户**。

**AI 自主生成并写入（SSH，经用户授权后）**：
1. 生成覆写内容：必须含段头（`[General]`/`[YAML]`/`[Overwrite]`），严格遵循覆写模块格式（段头、`config` 匹配、`16-overwrite-module-format.md` §16.2.3 操作符、§16.2.2 函数清单）。**若修复涉及规则/rule-providers（如 `[YAML]` 段注入 `rules:` 或 `RULE-SET` 引用），须对照 `11-overwrite-settings.md` §11.6「规则设置」的编写规范参考来源，并用 meta-rules-dat 确认 GEOSITE/GEOIP 分类名与 `.mrs` 规则集地址。**
   > **子文档读取**：本地 skill 环境用 `read_file` 读 `16-overwrite-module-format.md` / `17-overwrite-module-examples.md`；远程/CLI 环境取 raw URL：
   > `https://raw.githubusercontent.com/vernesong/OpenClash/dev/.github/skills/openclash-user-guide/16-overwrite-module-format.md`（及 `17-...`、`11-...`）。
2. 写入文件：
   ```sh
   mkdir -p /etc/openclash/overwrite
   cat > /etc/openclash/overwrite/<模块名> <<'EOF'
   [YAML]
   ...（覆写内容）
   EOF
   chmod 644 /etc/openclash/overwrite/<模块名>
   chown root:root /etc/openclash/overwrite/<模块名>
   ```
   > 注意：单引号 `<<'EOF'` 防止变量展开；若覆写内容本身包含 `EOF` 行，改用其它唯一分隔符（如 `<<'OPENCLASH_OVERWRITE_END'`）。<模块名> 用不含空格/特殊字符的 ASCII 名，与 `config_overwrite.name` 一致。
3. 注册 UCI（`config` 匹配当前配置文件，如 `all` 或 `/etc/openclash/config/xxx.yaml`）：
   ```sh
   # 先实算 order：取现有 config_overwrite 条目的最大 order 再 +1（勿用字面量占位符）
   max=$(uci -q show openclash 2>/dev/null | grep '=config_overwrite' | awk -F'[.=]' '{print $2}' | while read -r sid; do uci -q get "openclash.$sid.order" 2>/dev/null; done | sort -n | tail -1)
   order=$(( ${max:-0} + 1 ))

   uci add openclash config_overwrite
   uci set openclash.@config_overwrite[-1].name='<模块名>'
   uci set openclash.@config_overwrite[-1].type='file'
   uci add_list openclash.@config_overwrite[-1].config='all'   # 或具体配置文件路径；config 为 ListValue，用 add_list（仅单个值也可 set，但默认 list 语义更稳）
   uci set openclash.@config_overwrite[-1].enable='0'          # 必须保持 0，启用权留给用户
   uci set openclash.@config_overwrite[-1].order="$order"
   uci commit openclash
   ```
   （等价方式：带已认证会话 POST `/upload_overwrite`；SSH 直写更直接。）
4. **启用权留给用户**：AI **不**设置 `enable=1`、不代用户重启核心。完成后告知用户：请在「运行状态页 → 覆写模块」中找到该模块并**启用**（如需要重启核心，由用户自行操作）——启用前不会生效。

**铁律**：
1. **只新建，不改已有**：AI 只创建**新的**覆写模块；不修改用户已有模块、不改 `/etc/config/openclash` 其它段、不改订阅 YAML、不改 `yml_change.sh`。
2. **enable 恒为 0**：AI 写入的模块必须 `enable=0`；启用由用户决定。
3. **严格遵循 `16/17-overwrite-module-*.md`**：段头必须有；`config` 须匹配当前配置（为空则永不生效，见 `17-overwrite-module-examples.md` §17.5）；`[YAML]` 操作符 / `[Overwrite]` 函数对照 `16-overwrite-module-format.md` §16.2.3 / §16.2.2；**涉及规则时另对照 `11-overwrite-settings.md` §11.6「规则设置」与 meta-rules-dat**。
4. **范围边界**：覆写只能覆盖 YAML/UCI 层面；需重启核心、改防火墙、改 dnsmasq 等 → 给出 LuCI 操作路径，或经用户确认后执行 🔴 命令。
5. **风险提示**：若覆写会覆盖「插件强制覆盖/禁用的设置」中的硬编码项（如 `allow-lan`、`sniffer.sniff` 等），须明确提示后果（见 `16-overwrite-module-format.md` §16.1 警告），由用户决定是否启用。
6. **写入即告知**：AI 落盘并注册后，向用户报告已创建模块名、内容摘要与 `config` 匹配，并提醒「启用权在你」。

---

### 14.8 Mihomo Wiki 参考链接

- [全局配置 (General)](https://wiki.metacubex.one/config/general/)
- [DNS 配置](https://wiki.metacubex.one/config/dns/)
- [TUN 配置](https://wiki.metacubex.one/config/inbound/tun/)
- [域名嗅探 (Sniffer)](https://wiki.metacubex.one/config/sniff/)
- [路由规则](https://wiki.metacubex.one/config/rules/)
- [代理协议](https://wiki.metacubex.one/config/proxies/)
- [完整配置示例](https://github.com/MetaCubeX/mihomo/blob/Meta/docs/config.yaml)

---
