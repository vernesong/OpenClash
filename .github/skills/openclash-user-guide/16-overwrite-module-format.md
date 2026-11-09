## 覆写模块详解

> **用途**: 覆写模块的入口与操作、INI 三段格式、`[YAML]` 操作符、`DOWNLOAD_FILE` 与 `#!` 元信息（§16.1–16.2）。示例与 UCI 结构见 `17-overwrite-module-examples.md`。
> **UCI**: `openclash.config_overwrite`（多条，按 order 排序）
> **存储**: `/etc/openclash/overwrite/<名称>`（本地）或 HTTP 远程拉取；内置固定文件 `/etc/openclash/custom/openclash_custom_overwrite.sh`

### 16.1 覆写模块是什么

> **操作优先铁律**: 用户问「怎么用/怎么创建/怎么编辑/怎么生效」时，按 §16.1.1 的 ①→⑤ 讲，**先操作后格式**；不要一上来抛操作符，也不要先讲菜单「覆写设置」CBI 页或 `yml_change.sh` 内部逻辑。

- **入口**: 运行状态页顶部 **Overwrite Module** 按钮（`id="edit_overwrite"`，与启动/停止并列，调 `editOverwrite()`）→ 弹出覆写编辑器（警告横幅 + 左侧模块列表 + 右侧 CodeMirror）
- **次要入口**: 菜单 `服务→OpenClash→覆写设置`（这是内置覆写选项的 CBI 页，与模块文件编辑是两个入口，见 `11-overwrite-settings.md`）
- **能做什么**: 给订阅配置追加/覆盖任意 Mihomo YAML 字段（DNS、Sniffer、TUN、规则等）、设置环境变量供后续脚本使用、下载外部文件、配置界面里没有的高级功能
- **执行模型**（两阶段，均在 `start_service` 内）:
  - **第一阶段** `overwrite_file()`（`yml_change.sh` 之前）：遍历 `config_overwrite` → 检查 `config` 是否匹配当前配置 → 读文件 → 解析 `[General]` 写 UCI → 处理 `DOWNLOAD_FILE` → 生成清单 `/tmp/yaml_openclash_overwrite_lines`（`M` 模块块 / `Y` 其 `[YAML]` 块路径 / `L` `[Overwrite]` 行）
  - **第二阶段** `YAML.overwrite_run()`（单 Ruby 进程，在 `yml_change.sh` / `yml_rules_change.sh` 之后）：逐模块先合并 `[YAML]` 再执行 `[Overwrite]` 的 `ruby_*` 调用，全部完成后统一 dump 一次
- **顺序含义**: `[General]` 在 `yml_change.sh` 之前生效（影响其行为）；`[Overwrite]`/`[YAML]` 在其之后执行，**可覆盖两个脚本的全部输出**，包括「插件强制覆盖/禁用的设置」里的硬编码项（`allow-lan`、`bind-address`、`sniffer.sniff` 等）。LuCI「覆写设置」页的选项同样会被覆盖
- **生效时机**: 编辑器 Save 只落盘 ⇒ 改内容、切开关、新建模块后**都必须重启插件**（`/etc/init.d/openclash reload` 只重载防火墙，不会重跑）
- **警告**: 覆盖硬编码项可能导致异常（如 `allow-lan: false` 会让局域网无法使用代理端口），改前提示用户

#### 16.1.1 操作路径详解

| 步骤 | 操作 |
|------|------|
| ① 入口 | 运行状态页顶部 **Overwrite Module** 按钮（`editOverwrite()` → `ConfigEditor.showOverwrite()`，复用配置编辑器模态框，标题变 Overwrite Edit） |
| ② 窗口 | 顶部覆写警告横幅（"You are editing the overwrite script..."）+ 左侧模块列表栏（标题 + 数量徽标 + 收起按钮 / 条目列表 / 底部「+ 添加新模块」）+ 右侧 CodeMirror 主编辑器；列表栏可收起为 46px 图标条（状态记 localStorage），窄屏首次默认收起；每项两行：文件名 + 启用开关 / 内联标签 + 类型 + 刷新·复制·编辑·删除按钮 |
| ③ 新建 | 底部「+ 添加新模块」→ 两步向导：**① 选择来源**（本地模块：上传区选中 txt/conf 后**停留本步**，点「下一步」才进第二步并读取文件头；**不选文件直接点「下一步」= 创建空白模块**，按名称/描述生成带 `#!NAME`/`#!DESC` 与三段格式说明注释的骨架，创建后直接打开编辑器手写；订阅链接只放 URL 输入框，点「下一步」才下载读取文件头）→ **② 填写模块信息**（名称必填、描述→`desc`、匹配配置、更新时间→`update_days`/`update_hour`、环境变量→`param`）。上传与下载都有百分比进度条；下载失败停在第一步，改链接或再点「下一步」即清除（链接未改时二次点击 = 跳过读取直接继续） |
| ④ 编辑 | 选条目 → 按 INI 三段格式编辑 → Save（POST `/config_file_save`，后端只允许写 `/etc/openclash/overwrite/<名称>`、`custom/openclash_custom_overwrite.sh`、`/etc/openclash/config/*.ya?ml`）。**改完重启插件才生效** |
| ⑤ 原理 | 见上方执行模型；列表按 order **升序**自上而下，内核按 order **降序**执行 ⇒ **越靠上的模块越晚合并、优先级越高** |

**新建模块的要点**:

- **`config`（匹配配置文件）**: 只能填 `all` 或**完整路径**（如 `/etc/openclash/config/config.yaml`）；只写文件名不会被匹配，模块永不生效
- **`order`**: 表单里没有该字段，自动取「现有最大 order + 1」（排最后）
- **`type`**: 订阅来源固定 `http`，本地来源 `file`
- **默认关闭**: 新建模块注册时 `enable=0`（与内置 `default`/`Google_Play` 一致），需手动开开关并重启
- **复制模块**: 每个模块条目第三个按钮（复制图标）→ POST `/duplicate_overwrite_module`，按 `<名称>_copy`（重复复制递增 `_copy2`…）复制文件正文，并继承 `config`（无匹配时回落 `all`）、`param`、`desc`；副本固定 `type=file`（脱离订阅 URL）、`enable=0`、`order=最大+1`，`official` 不继承 ⇒ 内置模块的副本可直接编辑/删除；复制完成后自动切换到副本并载入编辑器
- **`#!` 元信息回填**: 文件带 `#!` 标识时（§16.2.5）自动填表单，**只填留空或自动填入的字段，不覆盖手动输入**
- **内置模块六个**: `default`、`Google_Play`、`Tailscale`、`WiFi_Calling`、`BT_PT_Download`（随包安装）、`openclash_custom_overwrite.sh`（在 `custom/` 且不可改名）；这六项第二行带内联蓝底标签「内建 / Built-in」。`openclash_custom_overwrite.sh` **恒为第一个条目且不可拖动**
- **开关与拖拽只改 UCI，不重新下载正文**；只有「刷新」、改订阅 URL、新建订阅模块才拉远程内容（避免手工编辑被覆盖）。下载失败不写 UCI、不清空原文件；新建订阅模块下载失败则不注册
- **游离文件**（无 UCI 段的文件）排最后，第二行带「未配置 / Unset」标签、无开关、不可拖动，需先用齿轮配置匹配并保存

### 16.2 覆写文件的格式

INI 风格分段，支持三段：

```ini
[General]
# 键值对，作为环境变量导出

[Overwrite]
# ruby_* 函数调用，操作 YAML

[YAML]
# 原始 YAML 片段，合并到运行配置
```

> **⚠️ 强制要求**: 文件**必须包含至少一个段头**，否则内容全部忽略。`overwrite_file()` 按段头解析——`in_general`/`in_overwrite`/`in_yaml` 初始为 `0`，只有遇到对应段头才置 `1`；段头前与无段头的内容都被跳过。空行与 `#`/`;` 开头的注释行安全忽略。
> **AI 输出任何覆写示例时，代码块第一行必须是段头**，禁止输出不含段头的裸 YAML/Shell/INI。

#### 16.2.1 `[General]` 段 — 键值对/环境变量

每行 `KEY = VALUE`（大小写不敏感，自动转大写）。允许的 Key 共 109 个（`allowed_keys_types`），按类分组：

| 类别 | Key | 类型 |
|------|-----|------|
| 端口 | `DNS_PORT`、`PROXY_PORT`、`TPROXY_PORT`、`HTTP_PORT`、`SOCKS_PORT`、`MIXED_PORT` | int |
| 模式 | `EN_MODE`、`PROXY_MODE`、`STACK_TYPE` | string |
| DNS | `ENABLE_CUSTOM_DNS`、`ENABLE_RESPECT_RULES`、`APPEND_WAN_DNS`、`APPEND_DEFAULT_DNS` | int_bool |
| Fake-IP | `FAKEIP_RANGE`、`FAKEIP_RANGE6`、`STORE_FAKEIP`、`CUSTOM_FAKEIP_FILTER`、`CUSTOM_FAKEIP_FILTER_MODE` | string/int_bool |
| Meta | `ENABLE_TCP_CONCURRENT`、`ENABLE_UNIFIED_DELAY`、`ENABLE_META_SNIFFER`、`ENABLE_META_SNIFFER_PURE_IP`、`ENABLE_GEOIP_DAT` | int_bool |
| 流量 | `ROUTER_SELF_PROXY`、`DISABLE_UDP_QUIC`、`SKIP_PROXY_ADDRESS`、`COMMON_PORTS`、`CHINA_IP_ROUTE`、`CHINA_IP_ROUTE_DOMAIN_SOURCE` | int_bool/int/string |
| 访问控制 | `LAN_AC_MODE`、`LAN_AC_BLACK_IPS`、`LAN_AC_BLACK_MACS`、`LAN_AC_WHITE_IPS`、`LAN_AC_WHITE_MACS`、`WAN_AC_BLACK_IPS`、`WAN_AC_BLACK_PORTS` | int_bool/string |
| IPv6 | `IPV6_ENABLE`、`IPV6_MODE`、`IPV6_DNS` | int_bool/int |
| GEO | `GEO_AUTO_UPDATE`、`GEOIP_AUTO_UPDATE`、`GEOSITE_AUTO_UPDATE`、`GEOASN_AUTO_UPDATE` | int_bool |
| 规则 | `ENABLE_CUSTOM_CLASH_RULES`、`ENABLE_RULE_PROXY` | int_bool |
| Smart | `AUTO_SMART_SWITCH`、`SMART_ENABLE_LGBM`、`SMART_POLICY_PRIORITY` | int_bool/string |
| 特殊 | `CONFIG_FILE` | 切换 `config_path`（仅 `/etc/openclash/` 下普通文件） |
| 特殊 | `AGE_SECRET_KEY`、`AGE_PUBLIC_KEY` | Age 密钥 |
| 特殊 | `SUB_INFO_URL` | 订阅信息 URL |
| 特殊 | `SYSTEM_HOST` | 写入系统 `/etc/hosts`，逗号分隔（`1.2.3.4 a.com,5.6.7.8 b.com`），有值即生效，与界面列表合并 |
| 特殊 | `DOWNLOAD_FILE` | 下载外部文件（§16.2.4） |
| 特殊 | `DASHBOARD_PASSWORD`、`GLOBAL_UA`、`RESTART` | 密码 / UA / 覆写后是否重启 |

类型：`int` 整数、`int_bool` 0/1、`bool` true/false、`string` 任意字符串。完整 Key 与对应 UCI 见 `17-overwrite-module-examples.md` §17.5.2。

- **`[General]` 是唯一能改「插件设置」（UCI 层）的途径**：重启时写入 UCI（`openclash.@overwrite[0]`）供 `yml_change.sh`/`yml_rules_change.sh` 读取；`[YAML]`/`[Overwrite]` 只能改运行 YAML。凡修复涉及插件设置（模式/端口/DNS/Fake-IP/Meta/流量/IPv6/GEO/Smart 等）都要用 `[General]` 段，示例见 `17-overwrite-module-examples.md` §17.3（`EN_MODE = fake-ip-tun`）
- **访问控制类取并集**: `LAN_AC_*`/`WAN_AC_*` 写进模块是**追加**而非替换（`ac_combined_values()` 对 `openclash.config.<key>` 与 `openclash.@overwrite[0].<key>` 取并集，逗号或空格分隔均可）。`LAN_AC_*` 只作用于转发流量，路由器自身出站需 `WAN_AC_BLACK_PORTS`（output 链也生成）或 `ROUTER_SELF_PROXY`
- **`CONFIG_FILE` 路径限制**: 只接受 `/etc/openclash/` 下的普通文件；含 `..`、以 `/` 结尾、文件名以 `.` 开头或落在该目录外都会被跳过，记录 `skip config file outside /etc/openclash` / `skip config file with unsafe path` / `skip hidden config file`。合法示例 `/etc/openclash/config/Custom_Clash.yaml`
- **值支持变量展开**: `$NAME` / `${NAME}` / `${NAME:-默认值}`（`NAME` 匹配 `[A-Za-z_][A-Za-z0-9_]*`；`:-` 在未设置或为空时取默认，默认值内可再引用变量）；其余 `$` 写法（`$1`、`$(cmd)`）原样保留、不执行命令替换。变量来源见 `17-overwrite-module-examples.md` §17.5.1

这些变量在 `yml_change.sh`、`yml_rules_change.sh` 与自定义覆写脚本里用 `$KEY_NAME` 引用。

#### 16.2.2 `[Overwrite]` 段 — Ruby 函数调用

每行一次 `ruby_*` 调用，首个参数都是目标 YAML 路径（始终是当前运行配置），由 `YAML.overwrite_run()` 以 root 统一执行。

| 函数 | 作用 |
|------|------|
| `ruby_read <file> <key_path>` | 读 YAML 值 |
| `ruby_read_hash <var> <key_path>` | 读 Ruby 变量中的哈希值 |
| `ruby_read_hash_arr <file> <key_path> <sub_path>` | 遍历哈希数组读每个元素的子值 |
| `ruby_edit <file> <key_path> <value>` | 修改键值 |
| `ruby_cover <file> <key_path> <src_file> <sub_path>` | 覆盖：来源文件存在则取其同名键值，否则删除该键 |
| `ruby_merge <file> <key_path> <src_file> [<sub_path>]` | 从文件合并哈希 |
| `ruby_merge_hash <file> <key_path> <hash>` | 合并指定哈希到键路径 |
| `ruby_uniq <file> <key_path>` | 数组去重 |
| `ruby_arr_add_file <file> <key_path> <idx> <list_file> <sub_path>` | 从文件把元素插入指定下标 |
| `ruby_arr_head_add_file <file> <key_path> <list_file> <sub_path>` | 从文件把元素插入数组开头 |
| `ruby_arr_insert <file> <key_path> <idx> <value>` | 指定下标插入单元素 |
| `ruby_arr_insert_hash <file> <key_path> <idx> <hash>` | 指定下标插入哈希 |
| `ruby_arr_insert_arr <file> <key_path> <idx> <array>` | 指定下标插入数组 |
| `ruby_arr_edit <file> <key_path> <sub_key> <match_value> <new_sub_key> <new_value>` | 按字段匹配编辑数组元素；末两参留空 = 按值替换 |
| `ruby_map_edit <file> <key_path> <map_key> <sub_path> <value>` | 编辑哈希内嵌套哈希字段 |
| `ruby_delete <file> <key_path> [<key>]` | 删除键/数组元素（省略 key 时删键路径本身） |
| `uci_get_config <key>` | 读 UCI（覆写优先） |

**行级解析与安全**（`overwrite_parse_line()` + AST 白名单）:

1. 整行必须是**单个白名单 `ruby_*` 调用**，且**每个参数整体加引号**
2. **双引号参数**: `$NAME`/`${NAME}` 展开为环境变量（含 `$CONFIG_FILE`，执行器自动指向当前运行配置），**其余字符一律字面量**——`\`、`;`、反引号、`$( )` 都不触发 shell 展开（**不再需要转义**）；`$1`、`$$`、`$(` 等非变量名形式原样保留
3. **单引号参数**: 完全不展开，原样传给 Ruby
4. **代码参数过 AST 白名单（fail-closed）**: 只放行 `Value` 读写与常见 String/Array/Hash 方法、`lambda`、条件/循环/插值等；`system`/`send`/`File.`/`ENV`/反引号/`%x` 一律拒绝；纯值参数与引号内选项字不受影响
5. 违反语法或未过白名单 → 跳过并记录 `skip invalid Overwrite command【Ruby Script => 模块名: 行】`

⇒ 正则可直接写 `\.`（旧写法 `[.]` 仍有效）；值里有字面 `$` 建议用单引号参数（示例见 `17-overwrite-module-examples.md` §17.3.6）。
自定义覆写脚本（§17.4）的调用由 `ruby_record()` 以 NUL 分隔定长记录写入 `/tmp/yaml_openclash_custom_calls`，脚本跑完由 `overwrite_run_custom()` 执行；未过白名单记 `skip unsafe Overwrite command`。

#### 16.2.3 `[YAML]` 段 — 原始 YAML 注入（含操作符）

`[YAML]` 内容按 Ruby 深度合并进运行配置，支持操作符后缀：

| 操作符 | 写法 | 行为 |
|--------|------|------|
| 默认合并 | `key` / `<key>` | Hash 递归合并，标量覆盖，键不存在则新增；**数组整体替换**（追加/插入须用 `key+` / `+key`） |
| 强制覆盖 | `key!` / `<key>!` | 强制替换整个值，不递归 |
| 数组后置追加 | `key+` / `<key>+` | 追加到数组末尾 |
| 数组前置插入 | `+key` / `+<key>` | 插入数组开头 |
| 数组差集删除 | `key-` / `<key>-` | 从数组删除指定元素；非数组则删整个键 |
| 批量条件更新 | `key*` / `<key>*` | 按 `where` 匹配、用 `set` 更新 |

`<key>` 语法用于键名含特殊字符或与操作符冲突时。

**要点**: 默认合并只改你写的项（但**数组整体替换**——写 `proxy-groups:` 会丢掉全部已有组，追加请用 `proxy-groups+:`）；`key!` 把整块换成你写的。

**环境变量展开**: `${NAME}` / `$NAME` / `${NAME:-默认值}` 展开为环境变量（用于 `[General]` 的 Key、订阅 `param` 等）；`$1`、`$(cmd)`、反引号等原样保留且**不执行命令替换**，`$$` 两个 `$` 都保留（密码 `P@$$w0rd` 不会被吃掉）⇒ 正则 `$` 行尾锚、`(?=…)`、反斜杠都可安全书写。

**示例**:

```yaml
# 默认合并
dns:
  enable: true
  cache-algorithm: lru
mixed-port: 10802
tun:
  enable: true
  stack: mips

# 强制覆盖
dns:
  fake-ip-filter!:
    - '*.lan'
rules!:
  - DOMAIN-SUFFIX,example.com,DIRECT
  - MATCH,PROXY

# 数组追加 / 前置插入
dns:
  nameserver+:
    - '1.1.1.1'
  +nameserver:
    - '223.5.5.5'
+rules:
  - DOMAIN-SUFFIX,priority.com,DIRECT

# 删除
dns:
  nameserver-:
    - '8.8.8.8'
    - '8.8.4.4'
  cache-algorithm-:       # 删除整个键
```

**批量条件更新（`key*`）**: 支持 Hash 值数组（如 `proxy-groups`）与字符串数组（如 `rules`）；`where` 格式 `字段名: 值`（支持正则 `/pattern/`，数组可给列表表示"包含"）；`set` 支持与顶层相同的操作符。

```yaml
# proxy-groups：按 type 匹配，替换整个 proxies
proxy-groups*:
  where:
    type: select
  set:
    proxies: ['new-proxy1', 'new-proxy2']

# name 正则匹配，向 proxies 开头插入
proxy-groups*:
  where:
    name: '/^HK/'
  set:
    +proxies: ['hk-new-proxy']

# 从 proxies 移除指定节点
proxy-groups*:
  where:
    type: select
  set:
    proxies-: ['old-proxy1']

# 改 url-test 组的 interval（<key> 语法）
<proxy-groups>*:
  where:
    type: url-test
  set:
    interval: 300

# rules：正则匹配删除
rules*:
  where:
    value: '/,REJECT$/'
  set:
    value:

# hosts：更新 / 删除键
hosts*:
  where:
    key: '*.mihomo.dev'
  set:
    '*.mihomo.dev': '::1'
```

**组合操作**（同一块内可叠加，按书写顺序生效）:

```yaml
dns:
  nameserver-:
    - '8.8.8.8'
  +nameserver:
    - '223.5.5.5'
  nameserver+:
    - '1.0.0.1'
```

#### 16.2.4 `DOWNLOAD_FILE` 指令（`[General]` 段）

格式 `DOWNLOAD_FILE = url=..., path=..., cron=..., force=..., ua=..., restart=...`

| 字段 | 说明 |
|------|------|
| `url` | 下载地址（必填） |
| `path` | 保存路径（必填） |
| `cron` | cron 表达式，`0` = 不加定时任务 |
| `force` | `true` 强制重新下载 |
| `ua` | 自定义 User-Agent |
| `restart` | `true` 下载后重启核心 |

- **路径限制**: `path` 必须在 `/etc/openclash/` 或 `/tmp/` 下且不含 `..`，否则跳过并记 `skip download file outside /etc/openclash or /tmp` / `skip download file with unsafe path`
- **变量展开**: 各字段支持 `$NAME` / `${NAME}` / `${NAME:-默认值}`，如 `url=https://example.com/cfg/${EN_KEY2:-Custom_Clash}.yaml`

#### 16.2.5 模块元信息标识（`#!` 指令）

文件任意位置的 **`#!KEY = VALUE`** 注释行声明元信息（等号可写冒号；同一 KEY 取最上方一条）。运行期整行按注释跳过（各段内 `#`/`;` 开头的行都忽略，含 `[YAML]` 段），只有「添加新模块」窗口读取回填表单。

| 标识 | 回填目标 | 取值格式 |
|------|----------|----------|
| `NAME` | 模块名称 | 合法文件名（字母数字 `._-`，不以 `.` 开头，非 `openclash_custom_overwrite.sh`，≤128 字符）；优先于上传文件名 |
| `DESC` | 模块描述（UCI `desc`） | 单行，超长截断 200 字符；仅界面展示（列表/状态页悬停、编辑窗口可改）；UCI 为空时回退文件内值 |
| `CONFIG` | 匹配配置文件（`config`） | `all` 或逗号分隔的文件名/完整路径；文件名自动补全为 `/etc/openclash/config/<名称>` |
| `CRON` | 更新时间（`update_days`/`update_hour`，仅订阅模块） | `off`；`<星期> <小时>`（`3 4`=周三 4 点、`* 4`=每天 4 点）；或 5/6 段 cron（分钟须 `0`/`00`、日/月为 `*`、星期 0-6 / 7=周日 / SUN…SAT，6 段首段秒须为 0）；其它形态（非零分钟、多时段、区间、多星期）忽略 |
| `ENV` | 环境变量（`param`） | `KEY[=默认值]` 分号分隔（`EN_KEY1;EN_KEY2=foo`）；`KEY` 匹配 `[A-Za-z_][A-Za-z0-9_]*`；多行累加、重复键取最先出现者 |

- **读取时机**: 本地模块选中文件后读头部 ≤256 KB；订阅模块点「下一步」经 `overwrite_module_preview` 下载（上限 512 KB、读头部 128 KB）
- **回填规则**: 只填留空或自动填入的字段，环境变量按「缺则新增行、空值补默认值」合并；非法值（非法名称、无法表达的 CRON、非法 ENV 键）忽略；读取成功或无标识时不提示
- **失败处理**: 下载失败停在第一步、不回填，状态栏与进度条显示「下载失败」

```ini
#!NAME = WiFi_Calling
#!DESC = 运营商 ePDG 的 IKE/NAT-T 流量走指定 UDP 代理组
#!CONFIG = all
#!CRON = 0 4 * * 3
#!ENV = WIFI_CALLING_PROXY;STACK_TYPE=mips

[General]
ENABLE_UDP_PROXY = 1
STACK_TYPE = mips
```

> 内置模块头部已声明可参考：`WiFi_Calling`（`NAME`/`DESC`/`ENV`）、`Google_Play`/`Tailscale`（`NAME`/`DESC`）、`default`（格式说明）。注释里的示例别写成行首 `#!KEY=VALUE`，否则会被当真实标识读取。
