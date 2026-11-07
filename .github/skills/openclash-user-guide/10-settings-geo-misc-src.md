## 插件设置：GEO、其他与来源流量控制

> **用途**: 插件设置页的 GEO/大陆白名单订阅、其他（定时重启、版本更新、开发者、内核测试、oixCloud）与来源流量访问控制（§10.1–10.3）。
> **LuCI 路径**: 服务 → OpenClash → 插件设置 → 对应标签页（§10.3 在页面底部，独立表单）

### 10.1 GEO 数据库订阅 / 大陆白名单订阅

#### 10.1.1 GEO 数据库订阅 (GEO Update / geo_update)

| 数据类型 | 启用 UCI | 星期 UCI | 小时 UCI | 自定义 URL UCI | 更新脚本 |
|----------|----------|----------|----------|----------------|----------|
| GeoIP MMDB | `geo_auto_update` | `geo_update_week_time` | `geo_update_day_time` | `geo_custom_url` | `openclash_geo.sh ipdb` |
| GeoIP Dat | `geoip_auto_update` | `geoip_update_week_time` | `geoip_update_day_time` | `geoip_custom_url` | `openclash_geo.sh geoip` |
| GeoSite | `geosite_auto_update` | `geosite_update_week_time` | `geosite_update_day_time` | `geosite_custom_url` | `openclash_geo.sh geosite` |
| Geo ASN | `geoasn_auto_update` | `geoasn_update_week_time` | `geoasn_update_day_time` | `geoasn_custom_url` | `openclash_geo.sh geoasn` |

- 星期：`*`=每天、`1`=周一 … `0`=周日；小时：`0`-`23`；`*_custom_url` 留空用默认地址
- **YAML**: `geox-url` 各字段 + `geo-auto-update` + `geo-update-interval`
- **实现**: cron 任务由 `add_cron()` 注册；下载文件存 `/etc/openclash/`；MMDB 供 `GEOIP` 规则（IP→国家）、Dat 供 `GEOSITE`（域名→类别）、ASN 供 Smart 策略
- **更新后重启**: 更新成功时置 `restart=1`，由 `dec_job_counter_and_restart` 触发 `/etc/init.d/openclash restart`（`yml_change.sh` 不写 `geo-auto-update`，默认 YAML 为 `false`）

#### 10.1.2 大陆白名单订阅 (Chnroute Update / chnr_update)

| 选项 | UCI Key | 默认 | 说明 |
|------|---------|------|------|
| 自动更新 | `chnr_auto_update` | 0 | 定时更新大陆 IP 路由表（脚本 `openclash_chnroute.sh`） |
| 更新时间/每周 | `chnr_update_week_time` | `1`（周一） | `*`=每天、`1`-`6`=周一至周六、`0`=周日 |
| 更新时间/每天 | `chnr_update_day_time` | `0` | `0`-`23`，每小时一项 |
| 大陆 IPv4 更新 URL | `chnr_custom_url` | `https://ispip.clang.cn/all_cn.txt` | 中国 IPv4 CIDR 列表 |
| 大陆 IPv6 更新 URL | `chnr6_custom_url` | `https://ispip.clang.cn/all_cn_ipv6.txt` | 中国 IPv6 CIDR 列表 |

### 10.2 其他标签页

#### 10.2.1 定时重启 (Auto Restart / auto_restart)

| 选项 | UCI Key | 类型 | 默认 | 说明 |
|------|---------|------|------|------|
| 定时重启 | `auto_restart` | Flag | 0 | 开启后按设定时间自动重启 OpenClash |
| 重启时间/每周 | `auto_restart_week_time` | ListValue | `1`（周一） | `*`=每天、`1`-`6`=周一至周六、`0`=周日 |
| 重启时间/每天 | `auto_restart_day_time` | ListValue | `0` | `0`-`23`，每小时一项 |

实现：`add_cron()` 往 `/etc/crontabs/root` 写 `/etc/init.d/openclash restart` 条目。

#### 10.2.2 版本更新 (Version Update / version_update)

内嵌「检查更新」面板，页面加载时由 `/update`（本机配置与已装版本）、`/version_history`（版本历史）、`/addr_info`（CDN 列表）填充。远程最新版本（status 页红点用）走独立 `/last_version`，本面板不用。

**顶部配置区**（修改即通过 `/save_corever_branch` 存 UCI）：

| 选项 | UCI Key | 类型 | 默认 | 说明 |
|------|---------|------|------|------|
| 处理器架构 | — | 只读 | — | 后端 `coremodel`：优先 `/etc/openwrt_release` 的 `DISTRIB_ARCH`，opkg/apk 包数据库 libc 架构兜底 |
| 编译版本 | `core_version` | Select | `uci-defaults` 按 `DISTRIB_ARCH` 自动填（如 x86_64 → `linux-amd64-v1`） | `linux-amd64-v1/v2/v3`、`linux-arm64`、`linux-armv7`、`linux-mips64` 等约 18 种。**为空时无法下载内核**，点击提示 "No Compiled Version Selected" |
| 更新分支 | `release_branch` | Select | `master` | `master`（稳定）/ `dev`（开发），决定插件与内核下载分支 |
| Smart 内核 | `smart_enable` | Select | `0` | `0`=Meta 内核 / `1`=Smart 内核，决定下载的 `meta`/`smart` 子路径 |

**版本卡片**:

| 要素 | 数据来源 |
|------|----------|
| Installed（插件） | opkg/apk 包数据库（`opcv`），只读 |
| Select Version（插件） | `/version_history` 的 package 分支 CI commit，值为 sha，`Latest`=最新 |
| Installed（内核） | `clash_meta -v`（`coremetacv`），只读 |
| Select Version（内核） | `/version_history` 的 core 分支 CI commit，`Latest`=最新 |

**hint 提示区**: 默认随机提示轮换；操作出错显示错误；点击更新后显示流式日志（剥离时间戳，按 `[Info]`/`[Warning]`/`[Error]` 着色，固定高度滚动）。

**CDN 地址列表**（Address / Latency / Plugin / Core）:
- 预设：`raw.githubusercontent.com`（RAW 直连）、`fastly.jsdelivr.net`、`testingcf.jsdelivr.net`、`cdn.jsdelivr.net`；底部「Custom Your CDN URL」可加自定义 CDN（如 `https://ghfast.top/`），只拉取新增 CDN
- Latency 显示延迟并按快/中/慢着色；延迟超时、无法访问或该 CDN 无对应版本时，整行只显示一条错误（`Access Timed Out` / `Access Denied`，横跨 Latency/Plugin/Core 三列）
- 点版本号链接 = 只装该组件（插件 → `one_key_update?update_type=plugin`，内核 → `core_download`）；点下载图标 = 直接下 `.ipk`/`.apk` 或 `.tar.gz`；点行其它区域 = 一键更新插件 + 内核

**底部操作区**:

| 操作 | 说明 |
|------|------|
| 备份 (Backup File) | 先选范围：完整 / 排除内核 / 仅内核 / 仅配置 / 仅规则提供者 / 仅代理提供者，再下载 |
| 还原默认 (Restore Default) | 恢复出厂配置（确认后跳回设置页） |
| 删除内核 (Remove Core) | 删除所有核心二进制（危险操作） |

**下载与校验**:
- 内核：`core_download` 调 `openclash_core.sh`，前端传完整 `download_url`；文件 `clash-{arch}.tar.gz`（arch 即 `core_version`，已含 `linux-` 前缀）；oix 内核为 `mihomo-{arch}-{version}.gz`
- 插件：`openclash_update.sh`，`luci-app-openclash_{ver}_all.ipk`（opkg）或 `luci-app-openclash-{ver}.apk`（apk）；通过 ubus 后台安装避免界面断连
- **URL 结构**（`package`/`core` 是仓库**分支**）：Latest 用 `package/{branch}/...ipk`、`core/{branch}/{meta|smart}/clash-{arch}.tar.gz`；历史版本用 `{sha}/{branch}/...`；jsdelivr 前缀为 `gh/vernesong/OpenClash@{ref}/...`，自定义 CDN 直接拼 raw URL
- **下载失败不重启 OpenClash**（仅内核真正更新成功才置重启标志）
- **sha256 校验**: 下载后用发布目录 `checksums.txt` 比对（`openclash_curl.sh` 的 `verify_sha256_checksum()`），失败中止并报 `Checksum Verification Failed`（见 `03-errors.md` §3.4）

#### 10.2.3 开发者选项 (Developer Settings / developer)

- **自定义防火墙规则** `firewall_custom`：文本框内容存到 `/etc/openclash/custom/openclash_custom_firewall_rules.sh`
- 该脚本**无需定义函数**，是命令式 Shell：`set_firewall()` 在内置 REDIRECT/TPROXY/TUN/IPv6/访问控制规则全部建立后 `chmod +x` 并直接执行，可直接写 `iptables -I ...` 或 `nft add rule ...`，能引用已创建的链与 set
- 每次 OpenClash 启动或防火墙重载都会重新执行

#### 10.2.4 内核测试 (Core Test / debug)

| 工具 | 功能 | 触发 | 后端路由 |
|------|------|------|----------|
| 连接测试 (Connection Test) | 测试域名是否可达 | 输入域名点「Click to Test」 | `/diag_connection` |
| DNS 测试 (DNS Test) | 测试 DNS 解析结果 | 输入域名点「Click to Test」 | `/diag_dns` |

连接测试前端先试 `Image` 加载 `https://{domain}/favicon.ico` 预检，失败再回退 `/diag_connection`。

#### 10.2.5 oixCloud (oixcloud)

| 项 | 说明 |
|---|---|
| 登录 | `oix_email` / `oix_passwd` → `oix_login` 取 token；第三方云服务，需账号 |
| 自动签到 | `oix_checkin`（需 token） |
| 专属资源 | 登录后获取 Oix 专属内核与订阅 |
| 节点筛选 | 有套餐时显示（`oix_info` 的 `plan_rank` > 0），新标签页打开内核给出的网站页面；按线路/地区/名称包含或排除选节点，保存于账号（所有 OpenClash 共用），未设置时为智能优选；下次订阅更新生效，重启 OpenClash 可立即拉取 |

### 10.3 来源流量访问控制 (Source Traffic Bypass / lan_ac_traffic)

> **位置**: 插件设置页底部，独立 TypedSection（不属于任何标签页）
> **生效路径**: `firewall_lan_ac_traffic()` 在代理链 **position 0** 插入规则，优先级高于其它代理规则；由 `config_foreach firewall_lan_ac_traffic "lan_ac_traffic"` 遍历
> **与覆写模块**: §9.2 的黑白名单与 `lan_ac_mode` 可从覆写模块 `[General]` 段设置（见 `16-overwrite-module-format.md` §16.2.1），模块值与界面配置**取并集**（`ac_combined_values()` 合并，逗号或空格分隔均可）
> **覆盖范围**: 这些名单只生成 `openclash` / `openclash_mangle`（转发流量）链，**不含** `openclash_output` / `openclash_mangle_output`——路由器自身流量不受影响；要让路由器自身（DDNS/STUN/证书校验）绕过代理，用 `WAN_AC_BLACK_PORTS`（output 链也生成）或 `ROUTER_SELF_PROXY=0`

#### 10.3.1 lan_ac_traffic TypedSection

| 字段 | UCI Key | 类型 | 说明 |
|------|---------|------|------|
| 备注 | `comment` | Value | 规则说明 |
| 启用 | `enabled` | Flag | 默认 1 |
| 内部地址 | `src_ip` | Value | IP / CIDR / `localnetwork`（匹配 `@localnetwork` 地址集） |
| 内部端口 | `src_port` | Value | 端口或范围，如 `5000`、`1234-2345` |
| 协议 | `proto` | ListValue | `both`（默认）/ `tcp` / `udp` |
| 地址族 | `family` | ListValue | `both`（默认）/ `ipv4` / `ipv6` |
| 接口 | `interface` | ListValue | 接口名（`eth1`、`wg0`、`docker0`），匹配从该接口进入的流量 |
| 用户 | `user` | ListValue | Linux UID，仅 OUTPUT 链生效 |
| DSCP | `dscp` | Value | 0-63，匹配 IP 头 DSCP |
| 目标 | `target` | ListValue | `RETURN`（默认，跳过代理直连）/ `ACCEPT`（放行）/ `DROP`（静默丢弃） |

#### 10.3.2 防火墙工作逻辑

`config_foreach` 遍历启用的 section → 读取 UCI 字段 → 构建 nftables/iptables 匹配条件 → 按运行模式 + 协议 + 地址族插入对应链 position 0。

**目标链**:

| 运行模式 | TCP 进入 | TCP 发出 | UDP 进入 | UDP 发出 | 旁路由 SNAT |
|----------|----------|----------|----------|----------|-------------|
| 非 TUN（redir-host / fake-ip） | `openclash` | `openclash_output` | `openclash_mangle` | `openclash_mangle_output` | `openclash_post` |
| TUN | `openclash_mangle` | `openclash_mangle_output` | `openclash_mangle` | `openclash_mangle_output` | `openclash_post` |
| IPv6（`ipv6_enable=1`） | `openclash_v6` | `openclash_output_v6` | `openclash_mangle_v6` | `openclash_mangle_output_v6` | `openclash_post_v6` |

**匹配差异**:

| 条件 | nftables | iptables |
|------|----------|----------|
| `src_ip=localnetwork` | `ip saddr @localnetwork` | `-m set --match-set localnetwork src` |
| 接口 | `iifname "接口名"` | `-i 接口名` |
| 用户 | `meta skuid UID`（仅 OUTPUT） | `-m owner --uid-owner UID` |
| DSCP | `ip dscp 值` | `dscp` 模块，不可用时跳过并警告 `iptables DSCP module not available` |

- **Fake-IP 排除**: 所有规则自动加 `ip daddr != {198.18.0.0/16}`，避免影响 Fake-IP 内部映射
- **drop→return**: `target=drop` 在 nat 链（`openclash` / `openclash_output` / `openclash_post`）实际为 `return`（跳过代理），mangle 链保持真 `drop`；两种后端一致

**常见场景**:

| 需求 | 配置 |
|------|------|
| 某接口（WireGuard）不走代理 | `interface=wg0`, `target=RETURN` |
| Docker 网桥绕过内核 | `interface=docker0`, `target=RETURN` |
| 某设备全部直连 | `src_ip=192.168.1.100/32`, `target=RETURN` |
| BT 端口段 TCP 直连 | `src_port=6881-6889`, `proto=tcp`, `target=RETURN` |
| 某用户进程丢弃 | `user=65534`, `target=DROP` |
| 本地网络 UDP 直连 | `src_ip=localnetwork`, `proto=udp`, `target=RETURN` |
