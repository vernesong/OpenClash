## 日志与错误信息速查

> **用途**: 16 类日志错误关键字与排查方法（§3.1–3.16），按关键字匹配。
> **用法**: 先在表中按关键字定位「原因」，再按「排查方法」操作；表中未覆盖时搜 [OpenClash Issues](https://github.com/vernesong/OpenClash/issues)，优先看作者 vernesong 与高赞回复。
> **两类日志**: **插件日志**（§3.1–3.10、§3.12–3.14）由 Shell/Ruby/Lua 脚本产生，带 `[Info]`/`[Tip]`/`[Warning]`/`[Error]` 前缀；**内核日志**（§3.11）由 Mihomo（Go）产生，带 `level=debug/info/warning/error/fatal`，`level=fatal` 会导致进程退出。两者都写入 `/tmp/openclash.log`，在「运行日志」页查看。

### 3.1 内核启动与运行错误

| 错误关键字 | 问题位置 | 原因 | 排查方法 |
|-----------|---------|------|----------|
| `Ruby Works Abnormally, Please Check The Ruby Library Depends!` | 启动流程 | `ruby` 或 `ruby-yaml` 未装/损坏 | 装 `ruby`、`ruby-yaml`、`ruby-psych` |
| `Unable To Parse Config File` | 启动流程 | YAML 语法错误或 age 解密失败 | 配置管理 → Edit 检查语法 |
| `Core Start Failed, Please Check The Log Infos!` | 启动流程 | 核心进程未启动 | 查核心版本是否正确；生成调试日志 |
| `Core Initial Configuration Timeout` | 启动流程 | 非 TUN：300 s 内 `http://<lan_ip>:<cn_port>/group` 未返回 200；TUN：utun 路由等 3 轮（每轮 300 s） | 查 `/tmp/openclash.log` 核心日志；确认 `cn_port` 未被占用 |
| `TUN Interface Start Failed` | 启动流程 | TUN 网卡创建失败 | 确认已装 `kmod-tun` |
| `【{module}】module not found` | 启动流程 | 内核模块未装/未加载（tun、tproxy 等） | 安装对应 kmod 包 |
| `LAN IP Address Get Error` | 启动流程 | LAN IP 无效或缺 `ip-full`（旧内核 4.4.x 常见 br-lan 无 IP） | 模式设置→流量控制选对 LAN 接口（如 `br-lan`）；装 `ip-full`；`ip address show br-lan` 确认有 IPv4；可试切换混合模式 |
| `OpenClash Now Disabled, Need Start From Luci Page` | 启动流程 | 插件被禁用（`enable=0`） | 运行状态页点启动开关 |

### 3.2 订阅与配置更新错误

| 错误关键字 | 问题位置 | 原因 | 排查方法 |
|-----------|---------|------|----------|
| `Config File【<名>】Subscribed Failed, Trying to Download Without Agent...` | 配置订阅 | 订阅 URL 下载失败（curl 错误） | 检查订阅 URL 与网络连通性 |
| `Config File Tested Failed, Please Check The Log Infos!` | 配置订阅 | 下载的 YAML 未通过 `clash -t` | Edit 检查语法；查 `/tmp/openclash.log` |
| `Updated Config【<名>】Has No Proxy Field, Update Exit...` | 配置订阅 | 配置无 `proxies`/`proxy-providers` | 检查订阅源是否有效/过期 |
| `Filter Proxies Failed` | 配置订阅 | 关键字过滤正则异常 | 检查 `keyword`/`ex_keyword` 格式 |
| `Ruby Works Abnormally` | 配置订阅 | Ruby 环境异常 | 重装 `ruby`、`ruby-yaml` |
| 订阅转换后内核拿不到节点 | 配置订阅 + 运行状态 | 在线转换（`sub_convert`）时上游 HTTPS 证书校验失败 | 启用该订阅的 **skip-cert-verify** 后重新更新；仍无效则检查转换后端地址与模板 URL |
| `Config File Format Validation Failed` | 启动流程 | YAML 解析后文件为空/丢失 | 检查配置目录权限与磁盘空间 |

### 3.3 GEO 与规则更新错误

| 错误关键字 | 问题位置 | 原因 | 排查方法 |
|-----------|---------|------|----------|
| `Download Failed: HTML Response Detected` | GEO 数据库订阅 | CDN 返回 HTML 错误页 | 覆写设置→常规 检查 Github CDN 选项 |
| `Download Failed: Database Content Invalid` | GEO 数据库订阅 | 内容缺少预期关键字（限流或错误页） | 同上；或检查 GEO 自定义 URL |
| `Chnroute Cidr List Download Failed: Content Invalid` | 大陆白名单订阅 | 内容无合法 CIDR 行 | 检查 `chnr_custom_url`；换 CDN 后重试 |
| `Chnroute6 Cidr List Download Failed: Content Invalid` | 大陆白名单订阅 | 同上（IPv6） | 检查 `chnr6_custom_url`；换 CDN 后重试 |
| `Update Error, Please Try Again Later` | GEO 数据库订阅 | 网络下载失败 | 检查连通性；走代理下载时加直连规则 |
| `Control Panel【<名 - <类型>】Unzip Error!` | 仪表盘切换 | Dashboard 包解压失败 | 确认已装 `unzip` |
| `LightGBM Model Update Error` | 覆写设置→智能设置 | 模型下载失败 | 检查模型 URL |

### 3.4 内核与插件版本更新错误

| 错误关键字 | 问题位置 | 原因 | 排查方法 |
|-----------|---------|------|----------|
| `Core Version Check Error` | 版本更新 | GitHub 不可达 | 检查网络；大陆环境配 CDN |
| `Core Update Failed`（重试 3 次后） | 版本更新 | 下载/解压/替换失败 | 确认闪存空间与 CPU 架构选择；查磁盘空间 |
| `No Compiled Version Selected` | 版本更新 | 未选 CPU 架构（`core_version=0`） | 在版本更新页选对应架构 |
| `Pre update test failed`（3 次后） | 版本更新 | 插件包安装测试失败 | 在「系统→软件包」手动更新/重装 `luci-app-openclash` |
| `OpenClash update failed` | 版本更新 | 安装彻底失败 | 包在 `/tmp/`，手动 `opkg install` / `apk add` |
| `Failed to get version information` | 版本更新 | 版本检查失败 | 检查网络；覆写设置→常规 设 CDN |
| `Checksum Verification Failed` | 版本更新 | 未通过 sha256 校验 | 改用官方地址/CDN 后重试 |
| `Checksum Verification Successful for【...】` | 版本更新 | 与 `checksums.txt` 一致 | 正常信息，无需处理 |
| `Checksum file unavailable or entry not found, skip verification for【...】` | 版本更新 | 取不到 `checksums.txt` 或无对应条目 | **警告非致命**，本次跳过；确认 CDN 能访问同目录 `checksums.txt` |
| `Checksum mismatch for【...】` | 版本更新 | 文件损坏/被改或 CDN 缓存旧文件 | 换 CDN / 清缓存后重试 |
| `Unable to compute checksum, skip verification for【...】` | 版本更新 | 系统无 `sha256sum` | **警告非致命**，本次跳过 |

校验实现：`DOWNLOAD_FILE_CURL` 按下载链接推出同 ref 同目录的 `checksums.txt`（CI 生成，见 `compile_meta_core.yml` / `compile_new_ipk.yml`）比对哈希，通过才替换；代码在 `openclash_curl.sh` 的 `verify_sha256_checksum()`。

### 3.5 防火墙与 DNS 错误

| 错误关键字 | 问题位置 | 原因 | 排查方法 |
|-----------|---------|------|----------|
| `Dnsmasq not Support nftset, Use ipset` | 启动流程 | dnsmasq-full 未编译 nftset | 警告非致命；chnroute 旁路异常时重装 dnsmasq-full |
| `iptables DSCP module not available` | 启动流程 | iptables 缺 DSCP 模块 | 警告，DSCP 规则被跳过；或改用核心侧 DSCP |
| `Can't Setting Only Intranet Allowed Function` | 启动流程 | 无法识别 WAN 接口 | 流量控制 → 检查 WAN 接口名称 |
| `Nameserver Option Must Be Setted, Stop Customing DNS Servers` | 覆写设置→DNS | 启用自定义 DNS 但无 nameserver | 至少添加一个 DNS 服务器 |
| `Fallback-Filter Need fallback of DNS Been Setted` | 覆写设置→DNS | 未配 fallback DNS | 先添加 fallback 分组的服务器 |
| `DNS Loop Check` | 覆写设置→DNS | 存在回环风险 | 不要把关 Mihomo DNS 端口本身设为其上游 |
| 浏览器提示「证书不安全 / 证书不对」，查看证书是路由器自身（uhttpd 自签） | 防火墙（nft TPROXY） | 网桥入口启用了 `br_netfilter`（`net.bridge.bridge-nf-call-iptables` / `-ip6tables=1`），报文被提前交给 IP 层，`tproxy` 挂上的套接字随后丢失，报文按原端口落到路由器监听（如 `[::]:443`） | 见 `05-firewall-special.md` §5.5：插件启动时已默认置 `0`，若诊断日志第 17 章显示仍为 `1`，说明启动后被 Docker/QSDK/`sysctl.d` 改回，先 `openclash restart` 再用 `grep -rIn 'bridge-nf-call' /etc/sysctl.d/` 定位；需要保留网桥层 iptables 的网桥（`docker0` 等）单独 `ip link set dev <br> type bridge nf_call_iptables 1` |
| 同一机型 TCP 能通、部分 UDP/QUIC 不通（IPv4 无证书提示） | 防火墙（nft TPROXY） | 同上；IPv4 报文在 TCP/UDP 入栈阶段被丢弃，表现为超时而非证书错误 | 同上；`nft list chain inet fw4 openclash_mangle{,_v6} \| grep -i tproxy` 看规则计数（计数增长但 mihomo 无连接 = 假成功） |

### 3.6 覆写模块错误

| 错误关键字 | 问题位置 | 原因 | 排查方法 |
|-----------|---------|------|----------|
| `skip General key not allowed` | 覆写模块 | `[General]` 的 key 不在允许列表 | 查拼写；允许列表见 `16-overwrite-module-format.md` §16.2.1 |
| `skip config file outside /etc/openclash` / `skip config file with unsafe path` / `skip hidden config file` | 覆写模块 | `CONFIG_FILE` 不在 `/etc/openclash/` 下、含 `..`、以 `/` 结尾或以 `.` 开头 | 改用 `/etc/openclash/` 下的普通配置路径 |
| `skip invalid Overwrite command` | 覆写模块 | `[Overwrite]` 行不是白名单 `ruby_*` 单次调用 + 整体加引号，或代码未通过 AST 白名单（`system`/`send`/`File.`/`ENV`、反引号、`%x` 一律拒绝；`\`、`;`、`$( )` 按字面量处理） | 按 `16-overwrite-module-format.md` §16.2.2 改用白名单方法/常量；正则可直接写 `\.`，字面 `$` 用单引号；示例见 `17-overwrite-module-examples.md` §17.3.6 |
| `skip unsafe Overwrite command` | 覆写模块 / 自定义覆写脚本 | 自定义脚本的 `ruby_*` 调用（NUL 记录）在 `YAML.overwrite_run_custom()` 时未过白名单 | 限制写法同 `[Overwrite]` 段 |
| `Invalid YAML Override format` | 覆写模块 | `[YAML]` 段不是有效 Hash | 检查缩进与格式 |
| `Parse YAML Override failed` | 覆写模块 | `[YAML]` 段 Ruby 解析异常 | 逐行检查 YAML 语法 |
| `Config File Overwrite Failed` | 覆写模块 | 覆写整体失败 | 检查所有覆写设置语法 |
| `DOWNLOAD FILE failed` | 覆写模块 | `DOWNLOAD_FILE` 下载失败 | 检查 URL 与连通性 |
| `skip download file outside /etc/openclash or /tmp` / `skip download file with unsafe path` | 覆写模块 | `DOWNLOAD_FILE` 的 `path` 不在 `/etc/openclash/` 或 `/tmp/` 下，或含 `..` | 改到 `/etc/openclash/` 或 `/tmp/` 下并去掉 `..` |

### 3.7 流媒体解锁错误

| 错误关键字 | 问题位置 | 原因 | 排查方法 |
|-----------|---------|------|----------|
| `Streaming Unlock Could not Work Because of Router-Self Proxy Disabled` | 看门狗 | 本机代理关闭 | 流量控制 → 开启本机代理 |
| `Something Wrong While Testing` | 流媒体增强 | 测试脚本执行失败 | 确认核心运行中；检查策略组配置 |

### 3.8 LuCI Web 界面错误

| 错误提示 | 问题位置 | 原因 | 排查方法 |
|----------|---------|------|----------|
| `Switch Failed` | 运行状态快捷设置 | 切换接口失败（API 不可达或核心未运行） | 确认核心状态；刷新重试 |
| `Config file does not exist` | 配置管理 | 文件路径无效 | 检查文件名与是否存在 |
| `Cannot delete the last remaining dashboard` | 仪表盘切换 | 只剩一个仪表盘 | 先下载新仪表盘再删旧的 |
| `Failed to generate age key` | 配置订阅 Age 密钥 | 核心不支持 age keygen | 检查核心版本；手动生成 |
| `Failed to calculate public key` | 配置订阅 Age 密钥 | 密钥格式无效 | 应以 `AGE-SECRET-KEY-` 开头 |
| `Bad address specified!` | 连接诊断 | 地址为空或无效 | 输入有效主机名或 IP |
| `OpenClash Start Failed: {msg}` | 运行状态 | 核心日志出现 fatal/error | 看完整错误；生成调试日志 |
| `Access Denied` / `Access Timed Out` | IP 检测 | 网络连接问题 | 检查路由器网络 |

### 3.9 YAML 配置处理错误

| 错误关键字 | 问题位置 | 原因 | 排查方法 |
|-----------|---------|------|----------|
| `Load File Failed` | 配置加载 | Ruby 无法加载文件 | 确认文件存在且权限正确 |
| `Set Custom DNS Failed` | 覆写设置→DNS | DNS 覆写失败 | 检查 DNS 服务器配置 |
| `Set Fake-IP-Filter Failed` | 覆写设置→DNS | Fake-IP 过滤器异常 | 检查过滤器文件与模式 |
| `Set Hosts Rules Failed` | 覆写设置→DNS | Hosts 格式错误 | 检查每行格式 |
| `Set Custom Rules Failed` | 覆写设置→规则 | 规则注入异常 | 检查规则文件语法 |
| `Skiped The Custom Rule Because Group & Proxy Not Found` | 覆写设置→规则 | 引用了不存在的策略组/代理 | 检查 MATCH/Proxy/组名是否存在 |
| `Set BT/P2P DIRECT Rules Failed` | 覆写设置→规则 | BT 直连规则注入失败 | 关闭再开启「仅代理命中规则流量」 |
| `proxy-groups Get Failed` | 策略组 | 策略组解析异常 | Edit 检查 `proxy-groups` 段 |

### 3.10 Ruby YAML 模块错误

| 错误关键字 | 问题位置 | 原因 | 排查方法 |
|-----------|---------|------|----------|
| `Fix short-id values type failed` | YAML 处理 | `short-id` 值类型修复时 Psych 异常 | 检查 `short-id` 值格式 |
| `YAML overwrite failed:【key: ...】` | 覆写模块 | 合并时异常 | 检查 `[YAML]` 语法与操作符 |
| `YAML overwrite failed:【(match value) => ...】` | 覆写模块 | where 匹配逻辑异常 | 检查 `key*` 操作符的 where 条件与正则 |
| `YAML overwrite failed:【(batch update) => ...】` | 覆写模块 | 批量更新执行异常 | 检查 `key*` 的 set 子句 |
| `Write file failed` | YAML 写入 | 写文件 I/O 异常 | 检查磁盘空间与权限 |
| `Decrypt attempt failed` | Age 解密 | 解密失败 | 检查密钥与加密文件完整性 |
| `Decrypted content empty or still encrypted` | Age 解密 | 内容为空或仍是密文 | 确认密钥与加密时一致 |
| `Encrypt attempt failed` | Age 加密 | 加密写入失败 | 检查公钥格式 |
| `Encrypted file: decryption failed` | Age 解密 | 所有密钥尝试均失败 | 检查各订阅的 age 密钥 |

### 3.11 Mihomo 内核配置解析错误（`level=fatal` / `level=error`）

| 错误详情 | 配置段 | 修复方法 |
|---------|--------|----------|
| `proxy <N>: missing type` | `proxies` | 给第 N 个节点补 `type:`（如 `ss`/`vmess`/`trojan`） |
| `proxy <N>: unsupport proxy type: <type>` | `proxies` | `type:` 拼写错误或不支持 |
| `proxy <name> is the duplicate name` | `proxies` | 节点同名，改其中一个 |
| `proxy group <N>: missing name` | `proxy-groups` | 第 N 组缺 `name:` |
| `<groupName>: unsupported type` | `proxy-groups` | `type:` 改为 `select`/`url-test`/`fallback`/`load-balance`/`smart` |
| `loop is detected in ProxyGroup` | `proxy-groups` | 组之间循环引用，打破循环 |
| `<groupName>: use or proxies missing` | `proxy-groups` | 至少配一个 `proxies:` 或 `use:` |
| `'<name>' not found` | `proxy-groups` | 引用了不存在的节点/provider，查拼写 |
| `can not defined a provider called 'default'` | `proxy-providers` | `default` 是保留名，改名 |
| `unsupport vehicle type: <type>` | providers | `type:` 应为 `file`/`http`/`inline` |
| `file must have a payload field` | `rule-providers` | 规则集文件缺 `payload:` |
| `rules[<N>] [<line>] error: format invalid` | `rules` | 检查 `TYPE,payload,target,no-resolve` 语法 |
| `rules[<N>] [<line>] error: proxy [<name>] not found` | `rules` | 规则目标引用了不存在的组/节点 |
| `rules[<N>] [<line>] error: rule set [<name>] not found` | `rules` | `RULE-SET,<name>` 未在 `rule-providers` 定义 |
| `sub-rule error: circular references` | `sub-rules` | 子规则循环引用 |
| `decrypt config error` | 全局 | Age 解密失败，检查配置订阅中的密钥 |
| `configuration file ... is empty` | 全局 | 配置文件为空，检查下载是否正常 |
| `[Smart] Invalid policy-priority rule: must be in 'pattern:factor' format` | smart 组 | `smart_policy_priority` 改为 `名称:系数` |
| `DNS [addr] config with invalid ecs` | `dns` | 检查 DNS 服务器的 ECS 配置 |
| `[Smart] Model.bin invalid, remove and download` | Smart 模型 | 点手动更新模型重新下载 |
| `[CacheFile] remove invalid cache file error` | 运行缓存 | 停止 OpenClash，删 `/etc/openclash/cache.db` 后重启 |

> **通用排查**: 用「配置管理 → Download Run」下载运行时配置，与原始订阅对比，检查 `yml_change.sh` 与覆写模块生成的 YAML。

### 3.12 DNS 泄露排查

> **验证方法**: 客户端 `nslookup www.google.com` 应返回 ① DNS 服务器为路由器 IP；② 解析结果为 Fake-IP 段（`198.18.x.x`）。返回真实 IP 或上游非路由器即为异常。正确链路：`设备 → dnsmasq(53) → OpenClash(7874)`。

| 问题 | 问题位置 | 原因 | 排查方法 | 来源 |
|-----------|---------|------|----------|------|
| DNS 泄露（ipleak 检测到国内 DNS） | 覆写设置→DNS | Redir-Host/Fake-IP 下 nameserver 与 fallback 并发请求，国内结果可能被优先采纳 | ① 建议**放弃 fallback**，只用 `nameserver-policy` 分流；② 境外 DNS 加 `#RULES`（如 `https://1.1.1.1/dns-query#RULES`）或写已存在的组名 `#<组名>`（后缀语法见 `11-overwrite-settings.md` §11.3.13）；③ 删掉原配置的 `dns:` 段，只由覆写统一管理；④ `proxy-server-nameserver` 设为国内 DNS | [#3843](https://github.com/vernesong/OpenClash/issues/3843) |
| `nameserver-policy` 未生效 | 覆写设置→DNS | 覆写与订阅的 `dns:` 段合并导致意外行为 | ① 启用「自定义 DNS 设置」后重配全部 DNS；② 开 Debug 级日志观察实际查询路径；③ 确认 `default-nameserver` 组开了「节点域名解析」 | 同上 |
| DNS 泄露（开 IPv6 后出现） | 覆写设置→DNS + IPv6 设置 | 运营商 IPv6 DNS 绕过劫持直接「抢答」 | ① 取消 dnsmasq 的「过滤 IPv6 AAAA 记录」；② LAN DHCP **不下发 IPv6 DNS**，强制用路由器 IPv4 解析；③ DHCPv6 禁用、RA 设为服务器模式。原理：DNS 走 IPv4、流量走 IPv6，IPv4 DNS 同样能查 AAAA | — |
| 旁路由环境 DNS 泄露 | 运行状态 | 旁路由未把上游 DNS 指向 OpenWrt（尤其 IPv6 DNS 留空） | ① 手动指定 IPv4 DNS 为 OpenWrt IP；② IPv6 DNS 必须留空；③ DHCP 不下发 IPv6 DNS | — |

### 3.13 版本更新与下载失败

| 问题 | 问题位置 | 原因 | 排查方法 | 来源 |
|-----------|---------|------|----------|------|
| `/tmp/openclash_last_version` 下载失败 | 运行日志 / 启动流程 | ① curl SSL 证书验证失败；② GitHub Raw 被 DNS 污染/不可达；③ 超时；④ 缺 `libmbedtls` | ① 覆写设置→常规 设 `github_address_mod` CDN（`https://fastly.jsdelivr.net/` 或 `https://testingcf.jsdelivr.net/`）；② 确认 `ca-bundle`；③ Fake-IP 下在 fake-ip-filter 排除 `raw.githubusercontent.com`；④ 把 `openclash_core.sh` 的 `-m 60` 改 `-m 300`；⑤ `opkg install libmbedtls` | [#2791](https://github.com/vernesong/OpenClash/issues/2791) |
| 更新内核后重启失败 | 运行状态 | v0.47.052 的 stop→start 间隔不足，旧核心未退干净 | ① 升到 v0.47.054+（Dev 已修）；② 临时在 restart 的 stop/start 之间加 `sleep 5`；③ 检查内存是否不足（小设备加 swap） | [#4969](https://github.com/vernesong/OpenClash/issues/4969) |
| 升级后依赖检查异常、无法启动 | 启动流程 | `check_mod()` 或依赖检测误报 | ① 生成调试日志看依赖段；② 确认 `kmod-nft-tproxy`/`kmod-ipt-tproxy`；③ 切 Dev 分支拿修复；④ 重装插件 | [#4807](https://github.com/vernesong/OpenClash/issues/4807) |
| v0.47.052/055 无法开机自启 | 启动流程 | 启动时序竞争，procd respawn 过快 | ① 升到最新 Dev；② 模式设置中设 `delay_start` 30–60 秒；③ 确认内存充足 | [#4973](https://github.com/vernesong/OpenClash/issues/4973) |

### 3.14 功能异常类

| 问题 | 问题位置 | 原因 | 排查方法 | 来源 |
|-----------|---------|------|----------|------|
| 向日葵 / AnyDesk 等远程软件连不上 | 局域网客户端 | 远程软件域名或 QUIC 流量被代理/阻断 | ① 规则加 `DOMAIN-SUFFIX,oray.com,DIRECT`、`DOMAIN-SUFFIX,sunlogin.net,DIRECT`；② 确认 sniffer `skip-domain` 含 `oray.com`/`sunlogin.net`（默认已含）；③ 试着关闭 `disable_udp_quic` | [#3229](https://github.com/vernesong/OpenClash/issues/3229) |
| 小米摄像机 / 智能家居外网不可达 | 局域网 IoT | IoT 流量被代理导致 NAT 穿透失败 | ① 把设备 IP 加入「不走代理的局域网设备 IP」；② 确认 sniffer `skip-domain` 含 `Mijia Cloud`（默认已含）；③ 规则加 `DOMAIN-SUFFIX,xiaomi.com,DIRECT` | [#2431](https://github.com/vernesong/OpenClash/issues/2431) |
| 绕过中国大陆 IP 突然失效 | 升级后 / 运行状态 | 升级后 set 重建失败或列表未更新 | ① 手动更新大陆 IP 列表；② Area Bypass 先关再开；③ `nft list set inet fw4 china_ip_route \| head` 看 set 是否非空 | [#4031](https://github.com/vernesong/OpenClash/issues/4031) |
| 自定义防火墙规则不生效 | 开发者选项 | 未重启或脚本语法错误 | ① 必须**重启 OpenClash**（不是重载防火墙）；② `sh -n` 检查语法；③ 调试日志确认是否执行 | [#4005](https://github.com/vernesong/OpenClash/issues/4005) |
| DDNS 服务（DDNS-GO 等）异常 | 路由器 DDNS 插件 | 服务商 API 域名被分配 Fake-IP | 把 API 域名（如 `ddns.oray.com`、`api.cloudflare.com`）加入 Fake-IP-Filter | — |
| Cloudflare Tunnel 连接不稳 | 路由器/内网 | Cloudflared 默认走 QUIC，海外 QUIC 默认被阻断 | ① 规则中让 CF Tunnel 域名直连；② 启动参数显式 `--protocol http2` | — |
| BT/PT 流量进内核 | 下载设备 | 未正确分流 | ① 独立设备（NAS）加 `SRC-IP-CIDR,192.168.1.x/32,DIRECT`；② 有 IPv6 时再加 `SRC-IP-SUFFIX,::a1b2:c3d4,DIRECT`（EUI-64，可在设备查看）；③ 非独立设备用「非标端口」策略组直连 | — |
| 直连网站/APP/小程序打不开 | 局域网客户端 | 小众域名未被 `geosite:cn` 收录 | ① 临时把「漏网之鱼」设直连；② 永久加 `DOMAIN-SUFFIX,xxx.com,DIRECT`；③ 在 zashboard 看命中策略组 | — |
| 开 IPv6 后直连访问卡顿 | 局域网客户端 | IPv6 DNS 抢答或运营商 DNS 不稳 | ① 关「附加上游 DNS」，改用 DoH（如 AliDNS）；② 确保 LAN 不下发 IPv6 DNS | — |
| 非直连站点打不开且内核无日志 | 运行状态 | WAN 接口名填错或 DNS 重定向未关 | ① 清空 WAN 接口名称；② 关闭「网络→DHCP/DNS」的 DNS 重定向；③ 检查是否有其它插件劫持 53 端口 | — |
| Hysteria / Hysteria2 / TUIC 连不上、断流、握手超时 | 内核 `level=error` | ① Linux ≥6.6 的 quic-go GSO 兼容性问题（最常见）；② `server`/`auth`/`tls`/`password` 配置敏感 | ① **优先**开「禁用 quic-go GSO」后重启；② 确认 `type:` 拼写与端口；③ 检查 `auth`/`password` 与 TLS 证书 | — |
| 开「绕过中国大陆 IP」后 Google Play 无法下载 | Android 客户端 | `services.googleapis.cn` 等被国内 DNS 解析到大陆 IP，命中 `china_ip_route` 走直连，而 Google 中国服务器拒绝境外（代理）IP | 需同时处理 DNS 与规则，见下方「Google Play 下载失败」 | [#5074](https://github.com/vernesong/OpenClash/issues/5074) |

**Google Play 下载失败的处理**（`Proxy` 换成你的代理组名）：

1. **DNS 层面** —— 让 Google 域名走境外 DNS。插件内置覆写模块 `Google_Play` 已预置（默认未启用，在「覆写模块」窗口启用）；自行配置则写入 `dns.nameserver-policy`：

```yaml
dns:
  nameserver-policy:
    '+.services.googleapis.cn': ['https://8.8.8.8/dns-query', 'https://dns.google/dns-query#RULES']
    '+.googleapis.cn': ['https://8.8.8.8/dns-query', 'https://dns.google/dns-query#RULES']
    '+.xn--ngstr-lra8j.com': ['https://8.8.8.8/dns-query', 'https://dns.google/dns-query#RULES']
```

2. **规则层面** —— 在「覆写设置→规则→自定义规则」加（写入 `rules:`）：

```yaml
- DOMAIN-SUFFIX,services.googleapis.cn,Proxy
- DOMAIN-SUFFIX,googleapis.cn,Proxy
- DOMAIN-SUFFIX,xn--ngstr-lra8j.com,Proxy
```

更彻底：`GEOSITE,google,Proxy`。

3. **验证**：`dig services.googleapis.cn @127.0.0.1 -p 7874` 应返回境外 IP；zashboard 连接日志确认命中代理规则。

### 3.15 运行时状态异常

| 问题 | 问题位置 | 原因 | 排查方法 | 来源 |
|-----------|---------|------|----------|------|
| 节点正常但突然无法访问外网 | 运行状态正常但客户端无网 | DNS 劫持失效（dnsmasq 被改）、防火墙规则乱序、TUN 路由丢失 | ① 确认核心与 DNS 端口正常；② 查最近错误；③ 点「Reload Firewall」重建规则；④ 检查是否与 AdGuard Home / PassWall / SSR-Plus 等共存（不兼容） | [#3516](https://github.com/vernesong/OpenClash/issues/3516) |
| 防火墙 DNS 劫持规则反复被还原 | 运行日志反复出现重载 | 看门狗检测异常后自动重载形成循环（v0.46.001-beta 已知） | ① 升级到修复版本；② 临时注释看门狗的防火墙重载；③ 检查 Docker/UPnP 等是否在改防火墙 | [#3765](https://github.com/vernesong/OpenClash/issues/3765) |

### 3.16 旁路由 / 特定设备异常

| 问题 | 问题位置 | 原因 | 排查方法 | 来源 |
|-----------|---------|------|----------|------|
| 旁路由 R2S 等 ARM 设备 iPhone 待机耗电 | 局域网 | ARP 代理或 TUN keepalive 导致 iPhone 频繁唤醒 | ① 切 Fake-IP 模式；② 收紧 WAN 口访问；③ 主路由 DHCP 的网关与 DNS 指向旁路由 | [#2614](https://github.com/vernesong/OpenClash/issues/2614) |
| Fake-IP 下 UU 加速器等游戏加速器不可用 | 运行状态 | 加速器需要真实 DNS 解析，Fake-IP 返回虚拟 IP | ① fake-ip-filter 加加速器域名（`+.leigod.com`、`+.vivox.com`）；② 把该设备 IP 加入「不走代理的局域网设备 IP」 | [#1751](https://github.com/vernesong/OpenClash/issues/1751) |
| TUN 模式速度骤降 / 连接异常（个别固件） | TUN（含混合） | 个别固件内核的 TUN GSO 卸载实现有缺陷 | ① 开「禁用 TUN GSO」并重启，对比速度；② 明显恢复则保持关闭（GSO 是性能参数，关闭属正常取舍） | — |
