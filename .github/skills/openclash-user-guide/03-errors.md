## 日志与错误信息速查

> **用途**: 16 类日志错误关键字与对应排查方法，用户报错时按关键字匹配（§3.1–3.16）。

> **AI 行为指引**: 当用户提供日志报错信息时，AI 应首先在以下表格中查找匹配的错误关键字，
> 根据「原因」列判断问题根源，然后按「排查方法」列指导用户在 LuCI 中操作。
> **若表中未覆盖该错误**，应主动搜索 [OpenClash GitHub Issues](https://github.com/vernesong/OpenClash/issues) 查找是否存在相同或相似的问题，
> 优先参考高赞反应的社区回复和作者（vernesong）给出的解决方案。搜索时可使用错误关键字作为搜索词。
>
> **两类日志说明**:
> - **插件日志**（前九类）：由 OpenClash 的 Shell/Ruby/Lua 脚本产生，含 `[Info]`/`[Tip]`/`[Warning]`/`[Error]` 前缀，写入 `/tmp/openclash.log`。可在 LuCI「运行日志」页面查看。
> - **内核日志**（第十、十一类）：由 Mihomo 核心（Go 程序）产生，含 `level=debug/info/warning/error/fatal` 标记，同样写入 `/tmp/openclash.log`。`level=fatal` 会导致核心进程退出。可在 LuCI「运行日志」页面查看，或在「运行状态」页面看到 `OpenClash Start Failed` 提示。

### 3.1 内核启动与运行错误

| 错误关键字 | 问题位置 | 原因 | 排查方法 |
|-----------|---------|------|----------|
| `Ruby Works Abnormally, Please Check The Ruby Library Depends!` (Ruby 依赖异常) | 「运行状态」启动流程 | `ruby` 或 `ruby-yaml` 包未安装/损坏 | 「系统→软件包」安装 `ruby`、`ruby-yaml`、`ruby-psych` |
| `Unable To Parse Config File` (配置文件校验失败) | 「运行状态」启动流程 | YAML 配置文件语法错误或 age 解密失败 | 「配置管理」页面点击 Edit 检查 YAML 语法 |
| `Core Start Failed, Please Check The Log Infos!` (内核启动失败) | 「运行状态」启动流程 | 核心进程未能启动 | 「运行状态」查看核心版本是否正确；「运行日志」生成调试日志 |
| `Core Initial Configuration Timeout` (内核初始化超时) | 「运行状态」启动流程 | 核心 API 在 300 秒内未就绪 | 检查 `/tmp/openclash.log` 中核心日志；确认「覆写设置→常规」的 cn_port 未被占用 |
| `TUN Interface Start Failed` (TUN 接口启动失败) | 「运行状态」启动流程 | TUN 虚拟网卡创建失败 | 「系统→软件包」确认 `kmod-tun` 已安装 |
| `【{module}】module not found` (内核模块未找到) | 「运行状态」启动流程 | 内核模块未安装/未加载（tun/tproxy 等） | 「系统→软件包」安装对应的 kmod 包 |
| `LAN IP Address Get Error` (LAN IP 获取失败) | 「运行状态」启动流程 | LAN 接口 IP 无效或 `ip-full` 包缺失（旧内核 4.4.x 常见 br-lan 网桥无 IP） | 「插件设置→流量控制」选择正确的 LAN 接口名称（如 `br-lan`）；「系统→软件包」安装 `ip-full`；终端 `ip address show br-lan` 确认存在 IPv4 地址；尝试切换运行模式为混合模式 |
| `OpenClash Now Disabled, Need Start From Luci Page` (插件未启用) | 「运行状态」启动流程 | 插件被禁用（enable=0） | 「运行状态」页面点击启动开关 |

### 3.2 订阅与配置更新错误

| 错误关键字 | 问题位置 | 原因 | 排查方法 |
|-----------|---------|------|----------|
| `Config File Subscribed Failed` (订阅配置下载失败) | 「配置订阅」更新流程 | 订阅 URL 下载失败（curl 错误） | 「配置订阅」检查订阅 URL 是否正确；确认网络连通性 |
| `Config File Tested Faild` (配置文件测试失败) | 「配置订阅」更新流程 | 下载的 YAML 未通过 `clash -t` 验证 | 「配置管理」页面 Edit 检查 YAML 语法；查看 `/tmp/openclash.log` |
| `Updated Config Has No Proxy Field` (配置无节点字段) | 「配置订阅」更新流程 | 订阅配置中无 `proxies` 和 `proxy-providers` 字段 | 检查订阅源是否有效；可能订阅已过期 |
| `Filter Proxies Failed` (节点筛选失败) | 「配置订阅」更新流程 | 节点关键字过滤正则异常 | 「配置订阅」检查 keyword/ex_keyword 格式 |
| `Ruby Works Abnormally` (Ruby 异常) | 「配置订阅」更新流程 | Ruby 环境异常导致订阅处理失败 | 「系统→软件包」重装 `ruby`、`ruby-yaml` |
| `Config File Format Validation Failed` (配置文件格式校验失败) | 「运行状态」启动流程 | YAML 解析后文件为空/丢失 | 「配置管理」检查配置目录权限和磁盘空间 |

### 3.3 GEO 与规则更新错误

| 错误关键字 | 问题位置 | 原因 | 排查方法 |
|-----------|---------|------|----------|
| `Download Failed: HTML Response Detected` (下载失败：检测到 HTML 响应) | 「插件设置→GEO 数据库订阅」 | CDN 返回的是 HTML 错误页而非 GEO 文件 | 「覆写设置→常规」检查 Github 地址修改 CDN 选项 |
| `Download Failed: File Size Too Small` (下载失败：文件过小) | 「插件设置→GEO 数据库订阅」 | 下载文件 <1KB，内容不完整 | 「插件设置→GEO 数据库订阅」检查 GEO 自定义 URL 是否正确 |
| `Update Error, Please Try Again Later` (更新失败，请稍后再试) | 「插件设置→GEO 数据库订阅」 | 网络下载失败 | 「运行状态」检查网络连通性；若使用代理下载，添加直连规则 |
| `Control Panel Unzip Error!` (控制面板解压失败) | 「运行状态」仪表盘切换 | Dashboard 压缩包解压失败 | 「系统→软件包」确认 `unzip` 已安装 |
| `LightGBM Model Update Error` (LGBM 模型更新失败) | 「覆写设置→智能设置」 | LGBM 模型下载失败 | 「覆写设置→智能设置」检查模型 URL |

### 3.4 内核与插件版本更新错误

| 错误关键字 | 问题位置 | 原因 | 排查方法 |
|-----------|---------|------|----------|
| `Core Version Check Error` (内核版本检测失败) | 「版本更新」 | GitHub 不可达，无法获取最新版本信息 | 「运行状态」检查网络连通性；如在大陆，设置 CDN |
| `Core Update Failed` (内核更新失败，重试 3 次后) | 「版本更新」 | 核心下载/解压/替换失败 | 「版本更新」确认闪存空间和 CPU 架构选择；「系统 → 软件包」检查磁盘空间 |
| `No Compiled Version Selected` (未选择编译版本) | 「版本更新」 | CPU 架构未选择（core_version=0） | 「版本更新」标签页选择对应的 CPU 架构 |
| `Pre update test failed` (更新前测试失败，3 次后) | 「版本更新」 | 插件 IPK/APK 安装测试失败 | 手动在「系统→软件包」中更新或重装 luci-app-openclash |
| `OpenClash update failed` (OpenClash 更新失败) | 「版本更新」 | 插件安装彻底失败 | 包已保存在 `/tmp/`，手动使用 `opkg install` 或 `apk add` 安装 |
| `Failed to get version information` (获取版本信息失败) | 「版本更新」 | GitHub 版本检查失败 | 检查网络；「覆写设置→常规」设置 CDN |

### 3.5 防火墙与 DNS 错误

| 错误关键字 | 问题位置 | 原因 | 排查方法 |
|-----------|---------|------|----------|
| `Dnsmasq not Support nftset, Use ipset` (Dnsmasq 不支持 nftset) | 「运行状态」启动流程 | dnsmasq-full 未编译 nftset 支持 | 警告，非致命；如 chnroute 旁路异常则重装 dnsmasq-full |
| `iptables DSCP module not available` (iptables DSCP 模块不可用) | 「运行状态」启动流程 | iptables 缺少 DSCP 模块 | 警告，DSCP 规则被跳过；或改用核心侧 DSCP |
| `Can't Setting Only Intranet Allowed Function` (无法设置仅允许内网) | 「运行状态」启动流程 | 无法识别 WAN 接口 | 「插件设置→流量控制」检查 WAN 接口名称设置 |
| `Nameserver Option Must Be Setted, Stop Customing DNS Servers` (Nameserver 未设置) | 「覆写设置→DNS」 | 自定义 DNS 启用但未配置任何 nameserver | 「覆写设置→DNS」添加至少一个 DNS 服务器 |
| `Fallback-Filter Need fallback of DNS Been Setted` (Fallback-Filter 需要 Fallback DNS) | 「覆写设置→DNS」 | fallback-filter 需要先配置 fallback DNS | 「覆写设置→DNS」先添加 fallback 分组的 DNS 服务器 |
| `DNS Loop Check` (DNS 回环检查) | 「覆写设置→DNS」 | DNS 配置存在回环风险 | 「覆写设置→DNS」检查服务器列表，避免将 Clash DNS 端口设为其上游 |

### 3.6 覆写模块错误

| 错误关键字 | 问题位置 | 原因 | 排查方法 |
|-----------|---------|------|----------|
| `skip General key not allowed` (覆写 key 不允许) | 「覆写设置」覆写模块 | 覆写 [General] 中的 key 不在允许列表中 | 检查 key 拼写；参考覆写模块 `16-overwrite-module-format.md` §16.2.1 节的允许 key 列表 |
| `skip invalid Overwrite command` (无效覆写命令) | 「覆写设置」覆写模块 | [Overwrite] 段命令不以 `ruby_` 开头 | 修正命令语法，使用 `ruby_method_name` 格式 |
| `Invalid YAML Override format` (无效 YAML 覆写格式) | 「覆写设置」覆写模块 | [YAML] 段不是有效的 Hash 结构 | 检查 YAML 缩进和格式 |
| `Parse YAML Override failed` (YAML 覆写解析失败) | 「覆写设置」覆写模块 | [YAML] 段 Ruby 解析异常 | 逐行检查 YAML 语法 |
| `Config File Overwrite Failed` (配置文件覆写失败) | 「覆写设置」覆写模块 | 覆写应用整体失败 | 检查所有覆写设置的语法 |
| `DOWNLOAD FILE failed` (文件下载失败) | 「覆写设置」覆写模块 | 覆写模块 DOWNLOAD_FILE 下载失败 | 检查下载 URL 和网络连通性 |

### 3.7 流媒体解锁错误

| 错误关键字 | 问题位置 | 原因 | 排查方法 |
|-----------|---------|------|----------|
| `Streaming Unlock Could not Work Because of Router-Self Proxy Disabled` (流媒体解锁失效：本机代理关闭) | 「运行状态」看门狗 | 路由器自代理关闭导致流媒体解锁无法工作 | 「插件设置→流量控制」开启本机代理 |
| `Something Wrong While Testing` (流媒体测试失败) | 「插件设置→流媒体增强」 | 流媒体测试脚本执行失败 | 「运行状态」确认核心运行中；「插件设置→流媒体增强」检查策略组配置 |

### 3.8 LuCI Web 界面错误

| 错误提示 | 问题位置 | 原因 | 排查方法 |
|----------|---------|------|----------|
| `Switch Faild` (切换失败) | 「运行状态」快捷设置 | API 不可达或核心未运行 | 「运行状态」确认核心状态；刷新页面后重试 |
| `Config file does not exist` (配置文件不存在) | 「配置管理」 | 配置文件路径无效 | 「配置管理」检查文件名；确认文件存在于配置列表中 |
| `File size exceeds 10MB limit` (文件超过 10MB 限制) | 「配置管理」上传 | 上传文件超过 10MB | 减小文件或拆分上传 |
| `Cannot delete the last remaining dashboard` (无法删除最后一个仪表盘) | 「运行状态」仪表盘切换 | 只剩一个仪表盘时不允许删除 | 「运行状态」先下载新的仪表盘再删除旧的 |
| `Failed to generate age key` (生成 Age 密钥失败) | 「配置订阅」Age 密钥 | 核心不支持 age keygen | 「版本更新」检查核心版本；手动生成 age 密钥 |
| `Failed to calculate public key` (计算公钥失败) | 「配置订阅」Age 密钥 | 密钥格式无效 | 验证 age 密钥格式（应以 `AGE-SECRET-KEY-` 开头） |
| `Bad address specified!` (地址无效) | 「运行状态」连接诊断 | 输入地址为空或无效 | 输入有效的主机名或 IP 地址 |
| `OpenClash Start Failed: {msg}` (OpenClash 启动失败) | 「运行状态」 | 核心日志中出现 fatal/error 级别日志 | 查看完整错误消息；「运行日志」生成调试日志 |
| `Access Denied` (无法访问) / `Access Timed Out` (连接超时) | 「运行状态」IP 检测 | 网络连接问题 | 检查路由器网络连接 |

### 3.9 YAML 配置处理错误

| 错误关键字 | 问题位置 | 原因 | 排查方法 |
|-----------|---------|------|----------|
| `Load File Failed` (加载文件失败) | 「配置管理」配置加载 | Ruby 无法加载配置文件 | 确认配置文件存在且权限正确 |
| `Set Custom DNS Failed` (自定义 DNS 设置失败) | 「覆写设置→DNS」 | DNS 覆写处理失败 | 检查「覆写设置→DNS」中的 DNS 服务器配置 |
| `Set Fake-IP-Filter Failed` (Fake-IP-Filter 设置失败) | 「覆写设置→DNS」 | Fake-IP 过滤器配置异常 | 「覆写设置→DNS」检查 Fake-IP-Filter 文件和模式 |
| `Set Hosts Rules Failed` (Hosts 规则设置失败) | 「覆写设置→DNS」 | 自定义 Hosts 格式错误 | 「覆写设置→DNS」检查 hosts 文件每行格式 |
| `Set Custom Rules Failed` (自定义规则设置失败) | 「覆写设置→规则」 | 自定义规则注入异常 | 「覆写设置→规则」检查规则文件语法 |
| `Skiped The Custom Rule Because Group & Proxy Not Found` (规则跳过：策略组/代理不存在) | 「覆写设置→规则」 | 规则引用了不存在的策略组/代理 | 「覆写设置→规则」检查规则中 MATCH/Proxy/策略组名称是否存在 |
| `Set BT/P2P DIRECT Rules Failed` (BT/P2P 直连规则设置失败) | 「覆写设置→规则」 | BT 直连规则注入失败 | 「覆写设置→规则」关闭再重新开启「仅代理命中规则流量 (Rule Match Proxy Mode)」选项 |
| `proxy-groups Get Failed` (策略组获取失败) | 「配置管理」策略组 | 配置中策略组解析异常 | 「配置管理」页面 Edit 检查 proxy-groups 段 |

### 3.10 Ruby YAML 模块错误

| 错误关键字 | 问题位置 | 原因 | 排查方法 |
|-----------|---------|------|----------|
| `Fix short-id values type failed` (short-id 类型修复失败) | 「配置管理」YAML 处理 | YAML 中 `short-id` 字段值类型修复时 Psych 解析异常 | 「配置管理」Edit 检查配置中 `short-id` 字段的值格式 |
| `YAML overwrite failed:【key: ...】` (YAML 覆写失败) | 「覆写设置」覆写模块 | 覆写模块 YAML 合并时发生异常 | 「覆写设置」检查 `[YAML]` 段的语法和操作符使用 |
| `YAML overwrite failed:【(match value) => ...】` (YAML 条件覆写匹配失败) | 「覆写设置」覆写模块 | 批量条件更新的 where 匹配逻辑异常 | 「覆写设置」检查 `key*` 操作符的 where 条件格式和正则 |
| `YAML overwrite failed:【(batch update) => ...】` (YAML 批量更新失败) | 「覆写设置」覆写模块 | 批量条件更新执行时异常 | 「覆写设置」检查 `key*` 操作符的 set 子句语法 |
| `Write file failed` (写文件失败) | 「配置管理」YAML 写入 | YAML 写入文件时 I/O 异常 | 检查磁盘空间和文件权限 |
| `Decrypt attempt failed` (解密尝试失败) | 「配置订阅」Age 解密 | Age 加密文件解密失败 | 「配置订阅」检查 age 密钥是否正确；验证加密文件完整性 |
| `Decrypted content empty or still encrypted` (解密后为空或仍加密) | 「配置订阅」Age 解密 | Age 解密后内容为空或仍为加密格式 | 「配置订阅」确认 age 密钥与加密时使用的密钥匹配 |
| `Encrypt attempt failed` (加密尝试失败) | 「配置订阅」Age 加密 | Age 加密写入时失败 | 「配置订阅」检查 age 公钥格式；验证核心年龄功能 |
| `Encrypted file: decryption failed` (加密文件解密失败) | 「配置订阅」Age 解密 | 所有 age 密钥尝试均解密失败 | 「配置订阅」检查所有订阅的 age 密钥；可能密钥不匹配 |

### 3.11 Mihomo 内核配置解析错误（`level=fatal` / `level=error`）

> 以下为 Mihomo 内核在**加载/解析 YAML 配置文件**时产生的错误。`level=fatal` 会导致核心进程退出。
> 日志查看：LuCI「运行日志」页面或「运行状态」页面（若启动失败会显示 `OpenClash Start Failed`）。

`Parse config error` 的具体子类型及修复方法：

| 错误详情 | 配置段 | 修复方法 |
|---------|--------|----------|
| `proxy <N>: missing type` | `proxies` | 在「配置管理」Edit 中给第 N 个代理节点添加 `type:` 字段（如 `ss`, `vmess`, `trojan` 等） |
| `proxy <N>: unsupport proxy type: <type>` | `proxies` | 代理类型名称拼写错误或不支持，检查 `type:` 值是否在 Mihomo 支持列表中 |
| `proxy <name> is the duplicate name` | `proxies` | 两个代理节点同名，在「配置管理」Edit 中修改其中一个的名称 |
| `proxy group <N>: missing name` | `proxy-groups` | 第 N 个策略组缺少 `name:` 字段，Edit 中补充 |
| `<groupName>: unsupported type` | `proxy-groups` | 策略组 `type:` 值无效，改为 `select`, `url-test`, `fallback`, `load-balance` 或 `smart` |
| `loop is detected in ProxyGroup` | `proxy-groups` | 策略组之间存在循环引用（A 引用 B，B 又引用 A），打破循环链 |
| `<groupName>: use or proxies missing` | `proxy-groups` | 策略组没有配置 `proxies:` 或 `use:`，至少添加一个 |
| `'<name>' not found` | `proxy-groups` | 策略组引用了不存在的代理节点或 provider 名称，检查拼写 |
| `can not defined a provider called 'default'` | `proxy-providers` | provider 使用了保留名 `default`，改用其他名称 |
| `unsupport vehicle type: <type>` | `proxy-providers` / `rule-providers` | provider 的 `type:` 值无效，应为 `file`, `http` 或 `inline` |
| `file must have a payload field` | `rule-providers` | 规则集文件缺少 `payload:` 字段，检查文件内容格式 |
| `rules[<N>] [<line>] error: format invalid` | `rules` | 第 N 条规则格式错误，检查规则语法：`TYPE,payload,target,no-resolve` |
| `rules[<N>] [<line>] error: proxy [<name>] not found` | `rules` | 规则目标引用了不存在的策略组/代理名称 |
| `rules[<N>] [<line>] error: rule set [<name>] not found` | `rules` | 规则使用了 `RULE-SET,<name>` 但未在 `rule-providers` 中定义该名称 |
| `sub-rule error: circular references` | `sub-rules` | 子规则之间形成循环引用链，打破循环 |
| `decrypt config error` | 全局 | Age 加密的配置文件解密失败，在「配置订阅」中检查 age 密钥 |
| `configuration file ... is empty` | 全局 | 配置文件为空，在「配置管理」中检查配置是否正常下载 |
| `[Smart] Invalid policy-priority rule: must be in 'pattern:factor' format` | `smart` 策略组 | 「覆写设置→智能设置」中 `smart_policy_priority` 格式错误，改为 `名称:系数` |
| `DNS [addr] config with invalid ecs` | `dns` | DNS 服务器的 ECS 配置格式无效，「覆写设置→DNS」检查 DNS 服务器设置 |
| `[Smart] Model.bin invalid, remove and download` | Smart 模型 | 「覆写设置→智能设置」点击手动更新模型按钮重新下载 |
| `[CacheFile] remove invalid cache file error` | 运行缓存 | 「运行状态」停止 OpenClash，手动删除 `/etc/openclash/cache.db` 后重启 |

> **通用排查**: 在「配置管理」页面点击 **Download Run** 下载经脚本处理后的运行时配置，对比原始订阅检查 `yml_change.sh` 和覆写模块生成的 YAML 是否正确。

### 3.12 DNS 泄露排查

> **核心验证方法**：在客户端执行 `nslookup www.google.com`，应返回：① DNS 服务器为 OpenWrt 路由器 IP；② 解析结果为 Fake-IP 范围地址（`198.18.x.x`）。若返回真实 IP 或上游 DNS 非路由器，说明 DNS 解析链路异常。正确链路应为：`设备 → Dnsmasq(53端口) → OpenClash(7874端口)`。

| 错误关键字 | 问题位置 | 原因 | 排查方法 | 来源 |
|-----------|---------|------|----------|------|
| DNS 泄露（ipleak / `ipleak.net` 检测到国内 DNS） | 「覆写设置→DNS」 | Redir-Host/Fake-IP 下 nameserver 和 fallback 并发请求，国内 DNS 结果可能被优先采纳 | ① Meta 内核建议**放弃 fallback**，仅用 `nameserver-policy` 做 DNS 分流（国内域名→国内 DNS，国外域名→国外 DNS）；② 境外 DNS 地址后加 `#PROXY` 强制走代理（如 `https://1.1.1.1/dns-query#PROXY`）；③ 删除原配置 YAML 的 `dns:` 段，仅通过「覆写设置→DNS」管理 DNS 配置避免冲突；④ 将 `proxy-server-nameserver` 设为国内 DNS 避免代理节点域名解析走境外 | [#3843](https://github.com/vernesong/OpenClash/issues/3843) |
| `nameserver-policy` 未生效，DNS 仍走 nameserver | 「覆写设置→DNS」 | OpenClash 的「覆写设置→DNS」选项会与订阅配置的 `dns:` 段合并，可能导致预期外的 DNS 行为 | ① 在「覆写设置→DNS」启用「自定义 DNS 设置 (Custom DNS Setting)」后重新配置所有 DNS 规则；② 在「运行日志」中开启 Debug 等级观察实际 DNS 查询路径；③ 确认 `default-nameserver` 组的 DNS 服务器开启了「节点域名解析」选项 | 同上 |
| DNS 泄露（开启 IPv6 后出现） | 「覆写设置→DNS」+「IPv6 设置」 | 运营商下发的 IPv6 DNS 绕过了 OpenClash 的 DNS 劫持，直接响应客户端请求（"抢答"） | ① 在 LuCI 的「网络→DHCP/DNS→高级设置」中取消 `过滤 IPv6 AAAA 记录`；② 在 LAN 接口 DHCP 服务器 IPv6 设置中**取消「本地 IPv6 DNS 服务器」**，强制设备使用路由器 IPv4 地址进行 DNS 解析；③ DHCPv6 服务设为已禁用，RA 设为服务器模式。原理：DNS 请求走 IPv4 通道，流量走 IPv6 通道——IPv4 DNS 同样可以查询 AAAA 记录返回 IPv6 地址 | — |
| 旁路由环境下 DNS 泄露 | 「运行状态」 | 旁路由设备未正确指定上游 DNS 为 OpenWrt IP（尤其是 IPv6 DNS 留空） | ① 旁路由设备必须**手动指定 IPv4 DNS 为 OpenWrt 路由器 IP**；② **IPv6 DNS 必须留空**；③ 若使用 DHCP 分配，确保 DHCP 服务器不下发 IPv6 DNS 地址 | — |

### 3.13 版本更新与下载失败

| 错误关键字 | 问题位置 | 原因 | 排查方法 | 来源 |
|-----------|---------|------|----------|------|
| `/tmp/openclash_last_version` 下载失败 | 「运行日志」/ 启动流程 | ① curl SSL 证书验证失败（`BADCERT_CN_MISMATCH` / `self signed certificate`）；② GitHub Raw 域名被 DNS 污染或不可达；③ curl 超时（`Operation timed out`）；④ 缺少 `libmbedtls` 库 | ①「覆写设置→常规」设置 **Github 地址修改 (github_address_mod)** 为 CDN（推荐 `https://fastly.jsdelivr.net/` 或 `https://testingcf.jsdelivr.net/`）；②「系统→软件包」确认 `ca-bundle` 已安装；③ Fake-IP 模式在「覆写设置→DNS」的 fake-ip-filter 中排除 `raw.githubusercontent.com`；④ 修改 `/usr/share/openclash/openclash_core.sh` 中 curl 的超时参数 `-m 60` 改为 `-m 300`；⑤ 终端执行 `opkg install libmbedtls` 修复 curl 库依赖 | [#2791](https://github.com/vernesong/OpenClash/issues/2791) |
| **更新内核 (Update Core)** 点击后重启失败 | 「运行状态」页面 | v0.47.052 重启流程中 stop→start 间隔不足，旧核心进程未完全退出即启动新核心，触发「内核启动失败」 | ① 更新到 v0.47.054+（已在 Developer 分支修复）；② 临时解决：编辑 `/etc/init.d/openclash`，在 restart 函数的 stop 和 start 之间加 `sleep 5`；③ 如更新后仍失败，检查内存是否不足（小型设备建议增加 swap） | [#4969](https://github.com/vernesong/OpenClash/issues/4969) |
| 升级后依赖检查异常，无法启动 | 「运行日志」启动流程 | 更新后 `check_mod()` 或依赖检测逻辑误报 | ①「运行日志」生成调试日志检查依赖段；②「系统→软件包」确认 `kmod-nft-tproxy`/`kmod-ipt-tproxy` 已安装；③ 切换 Dev 分支获取最新修复；④ 重装 `luci-app-openclash` | [#4807](https://github.com/vernesong/OpenClash/issues/4807) |
| v0.47.052/055 无法开机自启 | 「运行状态」启动流程 | 启动时序竞争条件，procd respawn 在某些固件上触发过快 | ① 更新到最新 Dev 版本；②「插件设置→模式设置」设置 `delay_start` (启动延迟) 30-60 秒；③ 确保路由器有足够内存供启动时使用 | [#4973](https://github.com/vernesong/OpenClash/issues/4973) |

### 3.14 功能异常类

| 错误关键字 | 问题位置 | 原因 | 排查方法 | 来源 |
|-----------|---------|------|----------|------|
| **向日葵/AnyDesk 等远程软件无法连接** | 局域网客户端 | 远程软件域名/QUIC 流量被代理或阻断 | ①「覆写设置→规则」添加直连规则：`DOMAIN-SUFFIX,oray.com,DIRECT`、`DOMAIN-SUFFIX,sunlogin.net,DIRECT` 等；② 确认 sniffer `skip-domain` 已包含 `oray.com` 和 `sunlogin.net`（默认已含）；③ 尝试关闭「插件设置→流量控制」的 `disable_udp_quic` (禁用 QUIC) | [#3229](https://github.com/vernesong/OpenClash/issues/3229) |
| **小米摄像机/智能家居外网无法访问** | 局域网 IoT 设备 | IoT 设备流量被代理导致 NAT 穿透失败 | ①「插件设置→黑白名单」添加摄像机 IP 到「不走代理的局域网设备 IP (LAN Bypassed Host List)」列表；② 确认 sniffer `skip-domain` 包含 `Mijia Cloud`（默认已含）；③「覆写设置→规则」添加 IoT 域名直连规则：`DOMAIN-SUFFIX,xiaomi.com,DIRECT` | [#2431](https://github.com/vernesong/OpenClash/issues/2431) |
| **绕过中国大陆IP (China IP Route) 功能突然失效** | 升级后 / 「运行状态」 | 版本升级后 `china_ip_route` 的 nftables/ipset 重建失败或 chnroute 列表未更新 | ①「插件设置→大陆白名单订阅」手动更新一次大陆 IP 列表；②「运行状态」页面 Area Bypass 先切到关闭再切回「绕过中国大陆 (Bypass Mainland China)」重新触发；③ 终端执行 `nft list set inet fw4 china_ip_route | head` 检查 nft set 是否存在且非空 | [#4031](https://github.com/vernesong/OpenClash/issues/4031) |
| **自定义防火墙规则（开发者选项）不生效** | 「插件设置→开发者设置」 | 编辑后未重启或脚本语法错误 | ① 修改 `openclash_custom_firewall_rules.sh` 后需**重启 OpenClash**（不是重载防火墙）；② 用 `bash -n` 检查脚本语法；③「运行日志」生成调试日志检查是否成功执行（日志中含自定义脚本内容） | [#4005](https://github.com/vernesong/OpenClash/issues/4005) |
| **DDNS 服务（如 DDNS-GO）工作异常** | 路由器 DDNS 插件 | DDNS 服务商 API 域名被错误分配 Fake-IP，导致 IP 检测失败 | ① 将 DDNS 服务商的 API 域名加入「覆写设置→DNS」的 Fake-IP-Filter 中（填入域名使其返回真实 IP）；② 常见需排除的域名如 `ddns.oray.com`、`api.cloudflare.com` 等，具体根据所用服务商填写 | — |
| **Cloudflare Tunnel (Cloudflared) 连接不稳定** | 路由器/内网设备 | Cloudflared 默认使用 QUIC 连接，而海外 QUIC 流量默认被 OpenClash 阻断 | ① 规则中已指定 Cloudflare Tunnel 相关域名直连；② 在 Cloudflared 启动参数中显式指定 `--protocol http2` 强制使用 HTTP/2（Docker 版：`command: [tunnel, --no-autoupdate, --protocol, http2, run, --token, ${CF_TOKEN}]`） | — |
| **BT/PT 下载流量进入内核** | 下载设备 | 下载设备流量未正确分流 | ① 若下载设备为独立设备（如 NAS），在「覆写设置→规则→自定义规则」中添加 `SRC-IP-CIDR,192.168.1.x/32,DIRECT`；② 若同时启用了 IPv6，还需添加 IPv6 后缀规则 `SRC-IP-SUFFIX,::a1b2:c3d4,DIRECT`（后缀由 EUI-64 生成，可在设备上查看）；③ 非独立设备可设置「非标端口」策略组直连来规避 80/443 以外的下载流量 | — |
| **直连网站/APP/小程序打不开** | 局域网客户端 | 小众域名未被 geosite:cn 收录，被误判为非直连走代理 | ① 临时方案：将「漏网之鱼」策略组设为直连；② 永久方案：在「覆写设置→规则→自定义规则」中为对应域名添加 `DOMAIN-SUFFIX,xxx.com,DIRECT` 规则；③ 观察 zashboard 中命中策略组确认分流是否正确 | — |
| **开启 IPv6 后某些直连访问卡顿** | 局域网客户端 | IPv6 DNS 抢答或运营商 IPv6 DNS 不稳定导致解析异常 | ① 禁用「覆写设置→DNS」的「追加上游 DNS」，改为在 NameServer 中手动添加 DoH 服务器（如 AliDNS）；② 确保 LAN 口未下发 IPv6 DNS 地址 | — |
| **非直连站点打不开且内核日志无记录** | 「运行状态」 | WAN 接口名称填写错误或 DNS 重定向未关闭 | ①「插件设置→流量控制」清空 WAN 接口名称；② 确认「网络→DHCP/DNS」中 DNS 重定向功能已关闭；③ 两者均正确时，检查 OpenWrt 中是否有其他劫持 53 端口或修改 Dnsmasq 的插件 | — |
| **Hysteria / Hysteria2 / TUIC 节点连接失败、断流、握手超时** | 内核日志 `level=error` | ① Linux 内核 ≥6.6 的 quic-go GSO 兼容性问题（最常见）；② Hysteria 协议对 `server`/`auth`/`tls`/`password` 字段配置敏感 | ① **优先尝试**：「插件设置→模式设置」开启**「禁用 quic-go GSO (Disable QUIC Go GSO)」**后重启 OpenClash；② 确认 YAML 中 `type: hysteria` 或 `type: hysteria2` 拼写正确、端口号正确；③ 检查节点的 `auth`/`password` 及 TLS 证书配置是否完整 | — |
| **开启「绕过中国大陆 IP」后 Google Play 商店无法下载/更新** | 客户端（Android 设备） | `services.googleapis.cn` 等 Google 域名被国内 DNS 解析到中国大陆 IP（`220.181.x.x`），被 `china_ip_route` 规则匹配后走直连；但 Google 中国服务器禁止境外 IP（代理节点）访问，导致死循环 | **从 DNS 和规则两方面同时入手**：<br><br>**① DNS 层面** — 在「覆写设置→DNS→自定义 DNS 设置」中配置 `nameserver-policy` 强制 Google 域名走境外 DNS 解析，写入 YAML 的 `dns.nameserver-policy` 段：<br>```yaml<br>dns:<br>  nameserver-policy:<br>    '+.services.googleapis.cn': 'https://dns.google/dns-query'<br>    '+.googleapis.cn': 'https://dns.google/dns-query'<br>    '+.xn--ngstr-lra8j.com': 'https://dns.google/dns-query'<br>```<br>也可用 `8.8.8.8` 或 `1.1.1.1` 替代 `https://dns.google/dns-query`。效果：域名解析到 Google 境外 IP（如 `142.250.x.x`），而非国内 `220.181.x.x`。<br><br>**② 规则层面** — 在「覆写设置→规则→自定义规则」中添加，写入 YAML 的 `rules` 段：<br>```yaml<br>rules:<br>  - DOMAIN-SUFFIX,services.googleapis.cn,Proxy<br>  - DOMAIN-SUFFIX,googleapis.cn,Proxy<br>  - DOMAIN-SUFFIX,xn--ngstr-lra8j.com,Proxy<br>```<br>其中 `Proxy` 替换为你的代理策略组名。更彻底的方式：`GEOSITE,google,Proxy` 将全部 Google 流量走代理。<br><br>**验证**：终端执行 `dig services.googleapis.cn @127.0.0.1 -p 7874` 应返回境外 IP；在 zashboard 连接日志中确认域名命中代理规则。 | [#5074](https://github.com/vernesong/OpenClash/issues/5074) |

### 3.15 运行时状态异常

| 错误关键字 | 问题位置 | 原因 | 排查方法 | 来源 |
|-----------|---------|------|----------|------|
| **节点正常，突然无法访问外网** | 「运行状态」一切正常但客户端无网络 | DNS 劫持失效（dnsmasq 被其他插件修改）、防火墙规则乱序、TUN 路由表丢失 | ①「运行状态」确认核心和 DNS 端口正常；② 在「运行日志」中检查最近的错误；③「运行状态」点击「Reload Firewall (重置防火墙)」重建规则；④ 检查是否同时运行其他代理/DNS 插件（如 AdGuard Home、PassWall、SSR-Plus 等），OpenClash 不能与这些插件共存 | [#3516](https://github.com/vernesong/OpenClash/issues/3516) |
| **防火墙 DNS 劫持规则不停被还原** | 「运行日志」反复出现防火墙重载记录 | 看门狗检测到规则异常后自动重载，形成循环（v0.46.001-beta 已知问题） | ① 更新到最新版本（已在后续版本修复）；② 临时关闭看门狗自动修复（编辑 `openclash_watchdog.sh` 注释掉防火墙重载部分）；③ 检查是否有其他程序在修改防火墙规则（如 Docker、UPnP 服务） | [#3765](https://github.com/vernesong/OpenClash/issues/3765) |

### 3.16 旁路由 / 特定设备异常

| 错误关键字 | 问题位置 | 原因 | 排查方法 | 来源 |
|-----------|---------|------|----------|------|
| 旁路由 R2S 等 ARM 设备 iPhone 待机耗电严重 | 局域网 | 代理模式下 ARP 代理或 TUN 模式的 keepalive 导致 iPhone 频繁被唤醒 | ① 尝试切换为 Fake-IP 模式；② 关闭「仅允许内网 (Only Intranet Allowed)」以外的 WAN 口访问；③ 主路由 DHCP 下发的网关和 DNS 指向旁路由 IP | [#2614](https://github.com/vernesong/OpenClash/issues/2614) |
| 在 Fake-IP 模式下无法使用 UU 加速器等游戏加速软件 | 「运行状态」 | 游戏加速器需要真实 DNS 解析来优化连接，Fake-IP 返回虚拟 IP 导致失效 | ① 在「覆写设置→DNS」的 fake-ip-filter 中添加加速器相关域名（如 `+.leigod.com`、`+.vivox.com`）；② 将加速器所在设备的 IP 加入「不走代理的局域网设备 IP (LAN Bypassed Host List)」 | [#1751](https://github.com/vernesong/OpenClash/issues/1751) |

---
