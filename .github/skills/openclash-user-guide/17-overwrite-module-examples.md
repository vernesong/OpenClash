## 覆写模块示例与 UCI 结构

> **用途**: 实战示例、获取/匹配方式、UCI 条目结构与 `[General]` Key 速查（§17.1–17.5）。格式定义见 `16-overwrite-module-format.md`。
> **用法**: 用户要示例时先确认需求（追加还是替换？改插件设置还是运行 YAML？），再按 §17.3 给出带段头的可运行配置。格式与操作符细节见 `16-overwrite-module-format.md` §16.2。

### 17.1 两种获取方式

| 类型 | UCI `type` | 说明 |
|------|-----------|------|
| 本地模块 | `file` | 读 `/etc/openclash/overwrite/<名称>` |
| 远程模块 | `http` | 从 URL 下载到同路径，可配 `update_days`/`update_hour` 定时拉取 |

- 模块文件内的 `#!NAME`/`#!DESC`/`#!CONFIG`/`#!CRON`/`#!ENV` 注释声明元信息，添加时自动回填表单（格式见 `16-overwrite-module-format.md` §16.2.5，示例见 §17.3.9）
- **内置订阅型模块五个**（`type=http`、`update_days=off`、`config=all`、`enable=0`）：`default`（order 1）、`Google_Play`（2）、`Tailscale`（3）、`WiFi_Calling`（4）、`BT_PT_Download`（5）
  - `WiFi_Calling`：代理运营商 ePDG 的 IKE/NAT-T 流量；启用前须把 `WIFI_CALLING_PROXY` 设为现有 UDP 代理目标（留空不会跳过规则）
  - `BT_PT_Download`：切 `redir-host`、仅代理常用端口，tracker 直连并兜底 `MATCH,DIRECT`

### 17.2 与配置文件的匹配

`config` 字段（ListValue）：`all` = 所有配置；`/etc/openclash/config/xxx.yaml` = 仅该配置。

### 17.3 实战示例

#### 17.3.1 强制启用 TUN 模式 + 指定堆栈

```ini
[General]
EN_MODE = fake-ip-tun
STACK_TYPE = mips
```

#### 17.3.2 用 `[Overwrite]` 添加自定义代理组

```ini
[Overwrite]
# 参数：文件、键路径、插入下标、Ruby 哈希字面量（用 => 而非 JSON 的 :）
ruby_arr_insert_hash "$CONFIG_FILE" "['proxy-groups']" "0" "{'name'=>'手动切换', 'type'=>'select', 'proxies'=>['DIRECT', 'Proxy']}"
```

#### 17.3.3 覆写完整 DNS 配置（默认合并）

```ini
[YAML]
dns:
  enable: true
  enhanced-mode: fake-ip
  nameserver:
    - https://doh.pub/dns-query
    - https://dns.alidns.com/dns-query
  fallback:
    - tls://8.8.4.4
    - tls://1.1.1.1
  fallback-filter:
    geoip: true
    geoip-code: CN
```

`dns:` 按 Hash 递归合并——`enable`/`enhanced-mode`/`nameserver`/`fallback`/`fallback-filter` 逐项覆盖或新增，未列出的 `dns` 子键保留。

#### 17.3.4 覆写 Sniffer（默认合并）

```ini
[YAML]
sniffer:
  enable: true
  force-dns-mapping: true
  parse-pure-ip: true
  sniff:
    TLS:
      ports: [443, 8443]
    HTTP:
      ports: [80, 8080-8880]
```

只覆盖列出的字段，其余 `sniffer` 子键保留。

#### 17.3.5 追加自定义规则（数组后置追加）

```ini
[YAML]
rules+:
  - DOMAIN-SUFFIX,google.com,Proxy
  - DOMAIN-KEYWORD,youtube,Proxy
  - GEOSITE,netflix,NETFLIX
  - GEOIP,CN,DIRECT
  - MATCH,Proxy
```

必须用 `rules+`；写成 `rules:` 会**整体替换**整个规则数组。操作符全表见 `16-overwrite-module-format.md` §16.2.3（含 `key!` 强制覆盖、`+key` 前置插入、`key-` 删除、`key*` 批量条件更新）。

#### 17.3.6 用 `[Overwrite]` + ruby 函数动态修改

```ini
[Overwrite]
# 把规则文件条目插到 rules 开头
ruby_arr_head_add_file "$CONFIG_FILE" "['rules']" "/etc/openclash/custom/openclash_custom_rules.list" "['rules']"
# 删除 proxy-providers 下指定条目
ruby_delete "$CONFIG_FILE" "['proxy-providers']" "provider1"
# 用外部文件的 nameserver 列表替换 dns.nameserver
ruby_cover "$CONFIG_FILE" "['dns']['nameserver']" "/etc/openclash/custom/openclash_custom_dns.yaml" "nameserver"
ruby_merge_hash "$CONFIG_FILE" "['tun']" "'stack' => 'mips'"
```

写法限制：每行**单个白名单 `ruby_*` 调用 + 参数整体加引号**；`\`、`;`、`$( )`、引号内反引号一律按字面量处理（无需转义）；**代码参数过 AST 白名单**，未列入的调用（`system`/`send`/`File.`/`ENV`/反引号）被拒并记 `skip invalid Overwrite command`（详见 `16-overwrite-module-format.md` §16.2.2）。正则可直接写 `\.`（`[.]` 仍有效）；字面 `$` 用单引号参数：

```ini
[Overwrite]
ruby_map_edit "$CONFIG_FILE" "['proxy-providers']" "provider1" "['filter']" '^abc\.com$x'
```

#### 17.3.7 用 `CONFIG_FILE` 切换配置 + 设置 Age 密钥

```ini
[General]
CONFIG_FILE = /etc/openclash/config/my_custom.yaml
AGE_SECRET_KEY = AGE-SECRET-KEY-xxxxxxxxx
```

#### 17.3.8 下载外部规则文件

```ini
[General]
DOWNLOAD_FILE = url=https://example.com/rules.yaml, path=/etc/openclash/rule_provider/custom_rules.yaml, ua=clash-verge/v2.4.5, cron=0 2 * * *
```

#### 17.3.9 模块元信息标识（添加时自动回填）

```ini
#!NAME = My_Module
#!DESC = 一句话说明这个模块做什么，会显示在模块提示里
#!CONFIG = all
#!CRON = 0 4 * * 3
#!ENV = PROXY_GROUP=Smart;SUB_INFO_URL

[YAML]
rules+:
  - DOMAIN-SUFFIX,example.com,${PROXY_GROUP}
```

`#!` 行对执行无影响，只在「添加新模块」时回填（取值规则见 `16-overwrite-module-format.md` §16.2.5）。

#### 17.3.10 内置 DDNS 模块（探测/服务商 API 直连 + STUN 端口绕过）

> 仓库内置 `overwrite/DDNS`。IP 探测经代理出口会拿到代理 IP（DDNS 写错地址）；STUN 需要路由器自身的 UDP 映射（走代理则拿不到）。`DDNS_DOMAIN` 留空时 fake-ip-filter 用占位域名，不影响解析；完整域名清单以模块文件为准。

```ini
[General]
WAN_AC_BLACK_PORTS=3478,5349

[YAML]
+rules:
  - DOMAIN,myip.ipip.net,DIRECT
  - DOMAIN,4.ipw.cn,DIRECT
dns:
  fake-ip-filter+:
    - "+.${DDNS_DOMAIN:-example.invalid}"
```

### 17.4 自定义覆写脚本（兼容保留）

**文件**: `/etc/openclash/custom/openclash_custom_overwrite.sh`
**时机**: 在 `yml_change.sh` 与 `yml_rules_change.sh` 之间执行
**写法限制**: 同 `[Overwrite]` 段（§17.3.6 与 `16-overwrite-module-format.md` §16.2.2）——`\`、`;`、反引号、`$( )` 按字面量处理，不能出现 `eval`/`exec`/`Kernel` 等进程或反射 token；`ruby_*` 调用先由 `ruby_record()` 记录，脚本结束后由 `YAML.overwrite_run_custom()` 统一执行，命中 token 记 `skip unsafe Overwrite command`。

```bash
#!/bin/sh
. /usr/share/openclash/ruby.sh

CFG_FILE=$(uci_get_config "config_path")
if [ -f "$CFG_FILE" ]; then
    ruby_arr_head_add_file "$CFG_FILE" "['rules']" "/etc/openclash/custom/openclash_custom_rules.list" "['rules']"
fi
```

### 17.5 UCI 覆写条目结构速查

| UCI Key | 类型 | 默认 | 说明 |
|---------|------|------|------|
| `name` | string | 必填 | 唯一标识，对应 `/etc/openclash/overwrite/<name>` |
| `enable` | bool | `0` | `1` = 启用 |
| `type` | string | `file` | `file` 本地 / `http` 远程（需 `url`/`update_*`） |
| `url` | string | 空 | `type=http` 的下载地址 |
| `config` | ListValue | 空 | 目标配置列表：`all` 或具体路径。**为空则永不匹配** |
| `param` | string | 空 | 额外键值对，`KEY1=VALUE1;KEY2=VALUE2` |
| `desc` | string | 空 | 模块描述，仅界面展示；可由 `#!DESC` 回填，空时回退文件内值 |
| `order` | int | `0` | 排序权重，**值越大越先执行**，新条目取 `max_order+1` |
| `update_days` | string | 空 | `type=http` 时的 cron 星期（0-7、`*`、`off`） |
| `update_hour` | string | 空 | `type=http` 时的 cron 小时（0-23、`off`） |

#### 17.5.1 字段详解

- **`config`**: 由 `overwrite_config_match_check()` 判定——含 `all` 匹配全部；含当前 `config_path` 匹配；**为空则永不匹配**（最常见配置错误）。必须是 **UCI 列表**（LuCI 用 `set_list` 写入）。可同时匹配多个配置
- **`type`+`url`+`update_*`**: `type=http` 时 `add_overwrite_cron()` 注册定时下载到 `/etc/openclash/overwrite/<name>`；模块 `[General]` 含 `RESTART:true` 时下载后自动重启核心；`update_days`/`update_hour` 任一为空或 `off` 则不注册 cron（仅手动触发）；`type=file` 不需要这些字段
- **`param`**: 格式 `KEY1=VALUE1;KEY2=VALUE2`，分号分隔；导出为环境变量 `$KEY1`、`$KEY2`，可在 `[Overwrite]` 的双引号参数（单引号内原样保留）、`[General]` 值、`DOWNLOAD_FILE` 字段、`[YAML]` 行中用 `$KEY`/`${KEY}`/`${KEY:-默认值}`；添加模块时可由 `#!ENV` 自动生成（缺则新增、空值补默认）
- **`order`**: 多条按 `sort -nr`（数值降序）执行；新条目自动 `max_order + 1`

#### 17.5.2 `[General]` 允许的 Key 速查

> Key 大小写不敏感，写入 UCI `openclash.@overwrite[0]`。**下表 Key 名小写即对应 UCI 选项名**（如 `DNS_PORT` → `dns_port`）。来源：`overwrite_file()` 的 `allowed_keys_types`。不在表中的 key 会被 `check_type()` 拦截并输出 `skip General key not allowed`。

| 类别 | Key | 类型 |
|------|-----|------|
| 模式 / 字符串型 | `EN_MODE`、`PROXY_MODE`、`STACK_TYPE`、`FIND_PROCESS_MODE`、`GEODATA_LOADER`、`GLOBAL_UA`、`INTERFACE_NAME`、`LAN_INTERFACE_NAME`、`INTRANET_ALLOWED_WAN_NAME`、`CORE_TYPE`、`OIX_TOKEN`、`URLTEST_ADDRESS_MOD`、`GITHUB_ADDRESS_MOD`、`SMART_POLICY_PRIORITY`、`SMART_COLLECT_RATE`、`FAKEIP_RANGE`、`FAKEIP_RANGE6`、`COMMON_PORTS`、`CUSTOM_FAKEIP_FILTER_MODE`、`CHINA_IP_ROUTE_DOMAIN_SOURCE`、`DASHBOARD_PASSWORD` | string |
| 端口 / 整型 | `DNS_PORT`、`PROXY_PORT`、`TPROXY_PORT`、`HTTP_PORT`、`SOCKS_PORT`、`MIXED_PORT`、`CN_PORT`、`TOLERANCE`、`URLTEST_INTERVAL_MOD`、`DELAY_START`、`CHINA_IP_ROUTE`、`CHINA_IP6_ROUTE`、`IPV6_MODE`、`SMART_TOLERANCE`、`SMART_COLLECT_SIZE`、`LGBM_UPDATE_INTERVAL`、`GEO_UPDATE_WEEK_TIME`、`GEOIP_UPDATE_WEEK_TIME`、`GEOSITE_UPDATE_WEEK_TIME`、`GEOASN_UPDATE_WEEK_TIME` | int |
| 运行开关 | `ENABLE_REDIRECT_DNS`、`ENABLE_CUSTOM_DNS`、`ENABLE_RESPECT_RULES`、`ENABLE_UDP_PROXY`、`ENABLE_V6_UDP_PROXY`、`DISABLE_UDP_QUIC`、`DISABLE_QUIC_GO_GSO`、`ENABLE_TCP_CONCURRENT`、`ENABLE_UNIFIED_DELAY`、`ENABLE_GEOIP_DAT`、`ROUTER_SELF_PROXY`、`INTRANET_ALLOWED`、`SMALL_FLASH_MEMORY`、`BYPASS_GATEWAY_COMPATIBLE`、`SKIP_PROXY_ADDRESS`、`STORE_FAKEIP`、`IPV6_ENABLE`、`IPV6_DNS`、`APPEND_WAN_DNS`、`APPEND_DEFAULT_DNS`、`CUSTOM_FALLBACK_FILTER`、`CUSTOM_FAKEIP_FILTER`、`CUSTOM_HOST`、`CUSTOM_NAME_POLICY`、`ENABLE_CUSTOM_CLASH_RULES`、`ENABLE_RULE_PROXY` | int_bool |
| 嗅探 | `ENABLE_META_SNIFFER`、`ENABLE_META_SNIFFER_PURE_IP`、`ENABLE_META_SNIFFER_CUSTOM` | int_bool |
| 访问控制 | `LAN_AC_MODE`、`INTRANET_ALLOWED`（int_bool）；`LAN_AC_BLACK_IPS`、`LAN_AC_BLACK_MACS`、`LAN_AC_WHITE_IPS`、`LAN_AC_WHITE_MACS`、`WAN_AC_BLACK_IPS`、`WAN_AC_BLACK_PORTS`（string，逗号分隔） | 见左 |
| GEO 订阅 | `GEO_AUTO_UPDATE`、`GEOIP_AUTO_UPDATE`、`GEOSITE_AUTO_UPDATE`、`GEOASN_AUTO_UPDATE`（int_bool）；`GEO_CUSTOM_URL`、`GEOIP_CUSTOM_URL`、`GEOSITE_CUSTOM_URL`、`GEOASN_CUSTOM_URL`、`GEO_UPDATE_DAY_TIME`、`GEOIP_UPDATE_DAY_TIME`、`GEOSITE_UPDATE_DAY_TIME`、`GEOASN_UPDATE_DAY_TIME` | 见左 |
| 大陆路由 | `CHNR_AUTO_UPDATE`（int_bool）；`CHNR_CUSTOM_URL`、`CHNR6_CUSTOM_URL`、`CHNR_UPDATE_DAY_TIME`、`CHNR_UPDATE_WEEK_TIME`、`CHINA_IP_ROUTE_PASS`、`CHINA_IP6_ROUTE_PASS` | 见左 |
| Smart / LGBM | `AUTO_SMART_SWITCH`、`SMART_ENABLE_LGBM`、`SMART_PREFER_ASN`、`SMART_COLLECT`、`LGBM_AUTO_UPDATE`（int_bool）；`LGBM_CUSTOM_URL` | 见左 |
| 无对应 UCI | `SYSTEM_HOST`（系统 hosts 条目，逗号分隔如 `1.2.3.4 a.com,5.6.7.8 b.com`，有值即启用，与界面列表合并）、`AGE_SECRET_KEY`、`AGE_PUBLIC_KEY`、`CONFIG_FILE`（仅 `/etc/openclash/` 下普通文件）、`SUB_INFO_URL`、`DOWNLOAD_FILE`（§16.2.4）、`RESTART`（bool，`true` = 覆写后重启，仅 `type=http` cron 更新时） | — |

类型：`int_bool` = 0/1；`int` = 纯整数；`string` = 任意字符串；`bool` = true/false。

> `WAN_AC_BLACK_PORTS` 在 output 链也生效，常用于 STUN/TURN（`3478,5349`）；`LAN_AC_*` 只作用于转发流量。按类别概览见 `16-overwrite-module-format.md` §16.2.1。
