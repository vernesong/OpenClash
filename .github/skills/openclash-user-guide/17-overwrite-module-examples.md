## 覆写模块示例与 UCI 结构

> **用途**: 覆写模块实战示例、获取/匹配方式与 UCI 覆写条目结构、[General] Key 速查（§17.1–17.5）。

> **AI 行为指引**: 当用户询问「覆写模块怎么写/怎么用」「给个示例」时，AI 应先确认用户需求（追加还是替换？改插件设置还是运行 YAML？），再按本文件 §17.3 示例给出带段头的可运行配置。格式与操作符细节见 `16-overwrite-module-format.md` §16.2；`[General]` 允许的 Key 见 §16.2.1 与 §17.5.2。

> **小节索引**: §17.1 获取方式 · §17.2 匹配规则 · §17.3 实战示例（§17.3.1–17.3.8）· §17.4 自定义脚本 · §17.5 UCI 结构（§17.5.1 字段详解 / §17.5.2 Key 速查）

### 17.1 覆写模块的两种获取方式

| 类型 | UCI `type` 值 | 说明 |
|------|--------------|------|
| **本地文件** | `file` | 读取 `/etc/openclash/overwrite/<名称>` |
| **远程模块** | `http` | 从 URL 下载到 `/etc/openclash/overwrite/<名称>`，支持 cron 定时更新 |

远程模块可设置 `update_days` 和 `update_hour` 实现定时自动拉取。

### 17.2 覆写与配置文件的匹配

每个覆写条目可指定目标配置文件（`config` 字段，ListValue）:
- `all` — 对所有配置文件生效
- `/etc/openclash/config/xxx.yaml` — 仅对该配置文件生效

### 17.3 实战示例

#### 17.3.1 强制启用 TUN 模式 + 设置 DNS
```ini
[General]
EN_MODE = fake-ip-tun
STACK_TYPE = mixed
```

#### 17.3.2 通过 [Overwrite] 段添加自定义代理组
```ini
[Overwrite]
ruby_merge "$CONFIG_FILE" "proxy-groups" '{"name":"手动切换","type":"select","proxies":["DIRECT","Proxy"]}'
```

#### 17.3.3 通过 [YAML] 段覆写完整 DNS 配置（默认合并 `key`）
> 操作符：**默认合并**（`key`）——`dns:` 哈希递归合并，`enable`/`enhanced-mode`/`nameserver`/`fallback`/`fallback-filter` 均为键级覆盖或新增，未列出的 `dns` 子键保留。
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

#### 17.3.4 通过 [YAML] 段覆写 Sniffer（默认合并 `key`）
> 操作符：**默认合并**（`key`）——`sniffer:` 哈希递归合并，仅覆盖所列字段（`enable`/`force-dns-mapping`/`parse-pure-ip`/`sniff`），其余键保留。
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

#### 17.3.5 通过 [YAML] 段追加自定义规则（数组后置追加 `key+`）
> 操作符：**数组后置追加**（`rules+`）——将下列规则追加到现有 `rules:` 数组末尾。注意：若改用默认合并（`rules:`）会**整体替换**整个规则数组，而非追加。
```ini
[YAML]
rules+:
  - DOMAIN-SUFFIX,google.com,Proxy
  - DOMAIN-KEYWORD,youtube,Proxy
  - GEOSITE,netflix,NETFLIX
  - GEOIP,CN,DIRECT
  - MATCH,Proxy
```

#### 17.3.6 通过 [Overwrite] + ruby 函数动态修改（Shell 函数族，非 [YAML] 操作符）
```ini
[Overwrite]
# 追加规则文件
ruby_arr_head_add_file "$CONFIG_FILE" "rules" "/etc/openclash/custom/openclash_custom_rules.list"
# 删除 proxy-providers 中特定的条目
ruby_delete "$CONFIG_FILE" "proxy-providers.低质量节点"
# 修改 DNS nameserver
ruby_cover "$CONFIG_FILE" "dns.nameserver" '[223.5.5.5, 119.29.29.29]'
```

#### 17.3.7 使用 CONFIG_FILE 切换配置 + 设置 Age 密钥
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

### 17.4 自定义覆写脚本（旧方式，兼容保留）

**文件**: `/etc/openclash/custom/openclash_custom_overwrite.sh`
**执行时机**: 在 `yml_change.sh` 和 `yml_rules_change.sh` 之间执行
**特点**: 可以使用项目提供的 `ruby_*` 函数族

```bash
#!/bin/bash
. /usr/share/openclash/ruby.sh

CFG_FILE=$(uci_get_config "config_path")
if [ -f "$CFG_FILE" ]; then
    ruby_arr_head_add_file "$CFG_FILE" "rules" "/etc/openclash/custom/openclash_custom_rules.list"
fi
```

### 17.5 UCI 覆写条目结构速查

每个 `config_overwrite` 条目（对应 `/etc/config/openclash` 中 `config config_overwrite` 段）的 UCI 字段：

| UCI Key | 类型 | 默认 | 说明 |
|---------|------|------|------|
| `name` | string | *(必填)* | 唯一标识，对应 `/etc/openclash/overwrite/<name>` 覆写文件名 |
| `enable` | bool | `0` | `1`=启用该覆写条目 |
| `type` | string | `file` | `file`=本地文件；`http`=远程下载（需配置 `url`/`update_days`/`update_hour`） |
| `url` | string | *(空)* | `type=http` 时的下载地址 |
| `config` | ListValue | *(空)* | 目标配置文件列表。`all`=应用到所有配置；或指定具体路径如 `/etc/openclash/config/xx.yaml`。**为空则永不匹配，覆写不生效** |
| `param` | string | *(空)* | 传给覆写文件的额外键值对，格式 `KEY1=VALUE1;KEY2=VALUE2` |
| `order` | int | `0` | 排序权重。**值越大越先执行**，新条目自动取 `max_order+1` |
| `update_days` | string | *(空)* | `type=http` 时 cron 星期 (0-7, `*`=每天, `off`=不自动更新) |
| `update_hour` | string | *(空)* | `type=http` 时 cron 小时 (0-23, `off`=不自动更新) |

#### 17.5.1 字段详解

**`config` (目标配置)**: 
- 覆写条目**必须**通过此字段匹配当前运行的配置文件才会执行。匹配逻辑（`overwrite_config_match_check()`）：
  - `config` 列表包含 `all` → 匹配所有配置
  - `config` 列表包含当前 `config_path` UCI 值 → 匹配
  - `config` 为空 → **永不匹配，覆写不生效**（常见配置错误）
- 支持同时匹配多个配置文件。

**`type` + `url` + `update_*` (远程覆写)**:
- `type=http` 时，`init.d` 的 `add_overwrite_cron()` 注册 cron 任务定时从 `url` 下载覆写文件到 `/etc/openclash/overwrite/<name>`
- 若覆写文件的 `[General]` 段包含 `RESTART:true`，下载后自动重启核心
- `update_days`/`update_hour` 任一为空或为 `off` → 不注册 cron（仅手动触发下载）
- `type=file` 时不需要 `url`/`update_*` 字段

**`param` (额外参数)**:
- 格式 `KEY1=VALUE1;KEY2=VALUE2`，分号分隔
- 值通过环境变量 `$KEY1`、`$KEY2` 传入 `/tmp/yaml_overwrite.sh`，可在 `[Overwrite]` 段的 Shell 脚本中直接引用

**`order` (执行顺序)**:
- 多条覆写按 `sort -nr`（数值降序）排列执行
- 新上传的覆写条目自动获得 `max_order + 1`

#### 17.5.2 `[General]` 段允许的 Key 速查

> 覆写文件的 `[General]` 段中可设置以下 key（大小写不敏感），写入 UCI `openclash.@overwrite[0]`。
> 来源：`init.d/openclash` → `overwrite_file()` → `allowed_keys_types` 列表。

| Key | 类型 | 对应 UCI | 说明 |
|-----|------|----------|------|
| `EN_MODE` | string | `en_mode` | 运行模式 |
| `PROXY_MODE` | string | `proxy_mode` | 代理模式 |
| `DNS_PORT` | int | `dns_port` | DNS 端口 |
| `PROXY_PORT` | int | `proxy_port` | 流量转发端口 |
| `TPROXY_PORT` | int | `tproxy_port` | TProxy 端口 |
| `HTTP_PORT` | int | `http_port` | HTTP 代理端口 |
| `SOCKS_PORT` | int | `socks_port` | SOCKS5 端口 |
| `MIXED_PORT` | int | `mixed_port` | 混合代理端口 |
| `CN_PORT` | int | `cn_port` | API 端口 |
| `DA_PASSWORD` | string | `dashboard_password` | Dashboard 密钥 |
| `TOLERANCE` | int | `tolerance` | URL-Test 容差 |
| `URLTEST_ADDRESS_MOD` | string | `urltest_address_mod` | 测速地址 |
| `URLTEST_INTERVAL_MOD` | int | `urltest_interval_mod` | 测速间隔 |
| `GITHUB_ADDRESS_MOD` | string | `github_address_mod` | GitHub CDN 地址 |
| `ENABLE_REDIRECT_DNS` | int_bool | `enable_redirect_dns` | DNS 劫持模式 |
| `ENABLE_CUSTOM_DNS` | int_bool | `enable_custom_dns` | 自定义 DNS |
| `ENABLE_RESPECT_RULES` | int_bool | `enable_respect_rules` | DNS 尊重规则 |
| `ENABLE_META_SNIFFER` | int_bool | `enable_meta_sniffer` | 域名嗅探 |
| `ENABLE_META_SNIFFER_PURE_IP` | int_bool | `enable_meta_sniffer_pure_ip` | 纯 IP 嗅探 |
| `ENABLE_META_SNIFFER_CUSTOM` | int_bool | `enable_meta_sniffer_custom` | 自定义嗅探 |
| `ENABLE_TCP_CONCURRENT` | int_bool | `enable_tcp_concurrent` | TCP 并发 |
| `ENABLE_UNIFIED_DELAY` | int_bool | `enable_unified_delay` | 统一延迟 |
| `ENABLE_UDP_PROXY` | int_bool | `enable_udp_proxy` | UDP 代理 |
| `ENABLE_V6_UDP_PROXY` | int_bool | `enable_v6_udp_proxy` | IPv6 UDP 代理 |
| `DISABLE_UDP_QUIC` | int_bool | `disable_udp_quic` | 禁用 QUIC |
| `DISABLE_QUIC_GO_GSO` | int_bool | `disable_quic_go_gso` | 禁用 quic-go GSO |
| `FIND_PROCESS_MODE` | string | `find_process_mode` | 进程匹配模式 |
| `GEODATA_LOADER` | string | `geodata_loader` | GEO 加载方式 |
| `ENABLE_GEOIP_DAT` | int_bool | `enable_geoip_dat` | 启用 GeoIP Dat |
| `GLOBAL_UA` | string | `global_ua` | 全局 User-Agent |
| `INTERFACE_NAME` | string | `interface_name` | 绑定网络接口 |
| `STACK_TYPE` | string | `stack_type` | TUN 堆栈类型 |
| `DELAY_START` | int | `delay_start` | 延迟启动（秒） |
| `ROUTER_SELF_PROXY` | int_bool | `router_self_proxy` | 本机代理 |
| `CHINA_IP_ROUTE` | int | `china_ip_route` | 区域绕行 |
| `CHINA_IP6_ROUTE` | int | `china_ip6_route` | IPv6 区域绕行 |
| `COMMON_PORTS` | string | `common_ports` | 常用端口 |
| `INTRANET_ALLOWED` | int_bool | `intranet_allowed` | 仅内网 |
| `SMALL_FLASH_MEMORY` | int_bool | `small_flash_memory` | 小闪存模式 |
| `STORE_FAKEIP` | int_bool | `store_fakeip` | 持久化 Fake-IP |
| `BYPASS_GATEWAY_COMPATIBLE` | int_bool | `bypass_gateway_compatible` | 旁路由兼容 |
| `SKIP_PROXY_ADDRESS` | int_bool | `skip_proxy_address` | 绕过服务器地址 |
| `IPV6_ENABLE` | int_bool | `ipv6_enable` | IPv6 代理 |
| `IPV6_MODE` | int | `ipv6_mode` | IPv6 代理模式 |
| `IPV6_DNS` | int_bool | `ipv6_dns` | IPv6 DNS 解析 |
| `FAKEIP_RANGE` | string | `fakeip_range` | Fake-IP 范围 |
| `FAKEIP_RANGE6` | string | `fakeip_range6` | IPv6 Fake-IP 范围 |
| `CUSTOM_FALLBACK_FILTER` | int_bool | `custom_fallback_filter` | Fallback-Filter |
| `CUSTOM_FAKEIP_FILTER` | int_bool | `custom_fakeip_filter` | Fake-IP-Filter |
| `CUSTOM_FAKEIP_FILTER_MODE` | string | `custom_fakeip_filter_mode` | Filter 模式 |
| `CUSTOM_HOST` | int_bool | `custom_host` | 自定义 Hosts |
| `CUSTOM_NAME_POLICY` | int_bool | `custom_name_policy` | Nameserver-Policy |
| `APPEND_WAN_DNS` | int_bool | `append_wan_dns` | 追加 WAN DNS |
| `APPEND_DEFAULT_DNS` | int_bool | — | 追加默认 DNS |
| `AGE_SECRET_KEY` | string | — | Age 加密私钥 |
| `AGE_PUBLIC_KEY` | string | — | Age 加密公钥 |
| `CONFIG_FILE` | string | — | 覆写指定配置文件路径 |
| `SUB_INFO_URL` | string | — | 订阅信息查询 URL |
| `DOWNLOAD_FILE` | string | — | 下载外部文件（格式见 `16-overwrite-module-format.md` §16.2.4） |
| `RESTART` | bool | — | `true`=覆写后重启核心（仅 `type=http` cron 更新时） |
| `LAN_INTERFACE_NAME` | string | `lan_interface_name` | LAN 接口名称 |
| `INTRANET_ALLOWED_WAN_NAME` | string | `intranet_allowed_wan_name` | WAN 接口名称 |
| `CORE_TYPE` | string | `core_type` | 核心类型 |
| `OIX_TOKEN` | string | `oix_token` | oixCloud Token |
| `OIX_PARAMS` | string | `oix_params` | oixCloud 参数 |
| **GEO 订阅类** | | | |
| `GEO_AUTO_UPDATE` | int_bool | `geo_auto_update` | 自动更新 GeoIP MMDB |
| `GEO_CUSTOM_URL` | string | `geo_custom_url` | MMDB 自定义 URL |
| `GEO_UPDATE_DAY_TIME` | string | `geo_update_day_time` | MMDB 更新时间 |
| `GEO_UPDATE_WEEK_TIME` | int | `geo_update_week_time` | MMDB 更新星期 |
| `GEOIP_AUTO_UPDATE` | int_bool | `geoip_auto_update` | 自动更新 GeoIP Dat |
| `GEOIP_CUSTOM_URL` | string | `geoip_custom_url` | Dat 自定义 URL |
| `GEOIP_UPDATE_DAY_TIME` | int | `geoip_update_day_time` | Dat 更新时间 |
| `GEOIP_UPDATE_WEEK_TIME` | int | `geoip_update_week_time` | Dat 更新星期 |
| `GEOSITE_AUTO_UPDATE` | int_bool | `geosite_auto_update` | 自动更新 GeoSite |
| `GEOSITE_CUSTOM_URL` | string | `geosite_custom_url` | GeoSite 自定义 URL |
| `GEOSITE_UPDATE_DAY_TIME` | string | `geosite_update_day_time` | GeoSite 更新时间 |
| `GEOSITE_UPDATE_WEEK_TIME` | int | `geosite_update_week_time` | GeoSite 更新星期 |
| `GEOASN_AUTO_UPDATE` | int_bool | `geoasn_auto_update` | 自动更新 GeoASN |
| `GEOASN_CUSTOM_URL` | string | `geoasn_custom_url` | ASN 自定义 URL |
| `GEOASN_UPDATE_DAY_TIME` | string | `geoasn_update_day_time` | ASN 更新时间 |
| `GEOASN_UPDATE_WEEK_TIME` | int | `geoasn_update_week_time` | ASN 更新星期 |
| **大陆路由类** | | | |
| `CHNR_AUTO_UPDATE` | int_bool | `chnr_auto_update` | 大陆路由自动更新 |
| `CHNR_CUSTOM_URL` | string | `chnr_custom_url` | 大陆 IPv4 URL |
| `CHNR6_CUSTOM_URL` | string | `chnr6_custom_url` | 大陆 IPv6 URL |
| `CHNR_UPDATE_DAY_TIME` | string | `chnr_update_day_time` | 路由更新时间 |
| `CHNR_UPDATE_WEEK_TIME` | string | `chnr_update_week_time` | 路由更新星期 |
| `CHINA_IP_ROUTE_PASS` | string | — | 大陆路由绕过列表 |
| `CHINA_IP6_ROUTE_PASS` | string | — | 大陆 IPv6 路由绕过列表 |
| **Smart 类** | | | |
| `AUTO_SMART_SWITCH` | int_bool | `auto_smart_switch` | Smart 自动切换 |
| `SMART_ENABLE_LGBM` | int_bool | `smart_enable_lgbm` | 启用 LightGBM |
| `SMART_POLICY_PRIORITY` | string | `smart_policy_priority` | 策略优先级 |
| `SMART_PREFER_ASN` | int_bool | `smart_prefer_asn` | 优先 ASN |
| `SMART_TOLERANCE` | int | `smart_tolerance` | Smart 容差 |
| `SMART_COLLECT` | int_bool | `smart_collect` | 收集训练数据 |
| `SMART_COLLECT_RATE` | string | `smart_collect_rate` | 数据采样率 |
| `SMART_COLLECT_SIZE` | int | `smart_collect_size` | 数据文件大小 |
| `LGBM_AUTO_UPDATE` | int_bool | `lgbm_auto_update` | LGBM 自动更新 |
| `LGBM_CUSTOM_URL` | string | `lgbm_custom_url` | LGBM 自定义 URL |
| `LGBM_UPDATE_INTERVAL` | int | `lgbm_update_interval` | LGBM 更新间隔 |
| **规则类** | | | |
| `ENABLE_CUSTOM_CLASH_RULES` | int_bool | `enable_custom_clash_rules` | 自定义规则 |
| `ENABLE_RULE_PROXY` | int_bool | `enable_rule_proxy` | 仅代理命中规则 |

> **类型说明**: `int_bool`=值为 `0` 或 `1`；`bool`=值为 `true` 或 `false`；`int`=纯整数；`string`=任意字符串。
> 所有 key **大小写不敏感**，写入 UCI 时自动转换为小写。不在上表中的 key 会被 `check_type()` 校验拦截并输出 `skip General key not allowed` 警告。
> 按类别分组概览见 `16-overwrite-module-format.md` §16.2.1；本表为完整速查（含对应 UCI）。

---
