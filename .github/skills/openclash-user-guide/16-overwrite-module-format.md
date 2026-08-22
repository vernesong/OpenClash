## 覆写模块详解

> **用途**: 覆写模块的入口与操作路径、INI 三段格式、[YAML] 操作符与 DOWNLOAD_FILE（§16.1–16.2）。

> **小节索引**: §16.1 覆写模块是什么（§16.1.1 操作路径）· §16.2 覆写文件格式（§16.2.1 [General] / §16.2.2 [Overwrite] / §16.2.3 [YAML] / §16.2.4 DOWNLOAD_FILE）

> 覆写模块 (Overwrite Module) 是 OpenClash 的高级自定义功能
> **主入口（用户询问"怎么用"时优先讲这个）**: 运行状态页顶部**「覆写模块」按钮**（`id="edit_overwrite"`，与启动/停止开关并列，调用 `editOverwrite()`）——点击弹出覆写编辑器窗口，创建/编辑/删除/启停覆写模块都在这一个窗口内完成。
> 次要入口: 菜单 `服务→OpenClash→覆写设置`（独立 CBI 页面，配置的是内置覆写选项，与「覆写模块」文件编辑是不同入口，见 `11-overwrite-settings.md`）
> UCI Section: `openclash.config_overwrite` (支持多条，按 order 排序)
> 覆写文件存储: `/etc/openclash/overwrite/<名称>` (本地) 或通过 HTTP 远程拉取；内置固定文件 `/etc/openclash/custom/openclash_custom_overwrite.sh`

### 16.1 覆写模块是什么

> **AI 行为指引**: 当用户询问覆写模块相关问题（如"覆写模块怎么用"、"如何通过覆写添加配置"、"[YAML] 操作符怎么用"、
> "如何覆盖订阅中的 DNS 设置"、"覆写和 LuCI 设置哪个优先级高"），AI 应：
>
> 0. **【铁律·操作优先】凡涉及「覆写模块怎么用 / 怎么创建 / 怎么编辑 / 怎么生效」，必须先按操作路径讲解，再谈格式细节**。固定顺序：**覆写模块按钮 → 窗口弹出 → 创建 → 编辑语法格式 → 原理**（详见 §16.1.1 节）：
>    ① 运行状态页顶部「覆写模块」按钮（`editOverwrite()`）——不是菜单「覆写设置」CBI 页，也不是改启动脚本；
>    ② 点击弹出覆写编辑器窗口（覆写警告横幅 + 模块卡片栏 + CodeMirror 主编辑器）；
>    ③ 卡片栏「+」新建覆写模块（File / Subscribe 两种方式），另有内置固定 `openclash_custom_overwrite.sh`；
>    ④ 选卡片 → 主编辑器按 INI 三段格式编辑 → Save 落盘 `/etc/openclash/overwrite/<名称>`；
>    ⑤ 一句话讲清原理：`overwrite_file()` 在重启时解析，`[General]` 提前写 UCI，`[YAML]`/`[Overwrite]` 在 `yml_change.sh` 之后合并生效。
>    **禁止**在用户尚未弄清入口时直接抛格式/操作符，或优先讲插件菜单「覆写设置」CBI 页与 `yml_change.sh` 内部逻辑。
>
> 1. **【铁律】输出必须包含段头**——覆写文件**必须包含至少一个段头**（`[General]`、`[Overwrite]`、`[YAML]` 之一），否则整个文件被跳过、覆写不生效（详见 §16.2 节「强制要求」及 `overwrite_file()` 函数按段头解析的逻辑）。
>    **AI 输出任何覆写配置示例时，必须在代码块内以段头作为第一行**，**绝对禁止**输出不含段头的裸 YAML/Shell/INI 内容。
>    即使用户只问「某个字段怎么写」，代码块也必须形如：
>    ```ini
>    [YAML]
>    <具体配置>
>    ```
>    而非仅 `<具体配置>`。若用户反馈覆写不生效，优先排查：①段头是否存在；② `config` 字段是否匹配当前配置文件。
>
> 2. **示例输出规范**：优先使用 `[YAML]` 段格式给出示例（语法清晰、不易出错）；仅当需要动态逻辑（条件判断、循环处理）时才推荐 `[Overwrite]` 段。
>    给出示例前应**先明确用户需求**（追加还是替换？键路径是什么？目标是数组还是哈希？匹配条件？），然后结合 [§16.2.3 节操作符]（`!` 强制覆盖 / `+` 数组追加 / `-` 数组删除 / `*` 批量条件更新等）给出精准的、可直接使用的配置片段。禁止给出不含段头的泛泛描述。
>
> 3. **信息获取路径**：本章节未覆盖的细节按以下优先级查阅——
>    - 覆写文件格式/操作符/示例 → 本章节（§16.2 格式说明、§16.2.3 操作符、`17-overwrite-module-examples.md` §17.3 实战示例）
>    - Mihomo YAML 字段含义/用法 → [Mihomo 配置文档](https://wiki.metacubex.one/config/)
>    - 覆写执行机制/排序/脚本逻辑 → [OpenClash 源码](https://github.com/vernesong/OpenClash/tree/dev) 中 `init.d/openclash` 的 `overwrite_file()` 函数和 `/tmp/yaml_overwrite.sh` 生成逻辑
>
> 4. **覆写执行模型（理解即可，回答时按需引用）**：覆写分两阶段执行——
>    `[General]` 段在 `yml_change.sh` **之前**写入 UCI（可影响其行为）；
>    `[Overwrite]` 和 `[YAML]` 段在 `yml_change.sh` / `yml_rules_change.sh` **之后**执行，因此可覆盖这两个脚本的所有输出——包括硬编码项（如 `allow-lan`、`bind-address`、`sniffer.sniff` 等）。
>    LuCI「覆写设置」CBI 页面的选项同样会被 `[Overwrite]`/`[YAML]` 段覆盖。
>    **警告：覆盖硬编码项可能导致 OpenClash 工作异常**（如 `allow-lan: false` 会使局域网设备无法使用代理端口），提醒用户谨慎操作。

#### 16.1.1 操作路径详解

> **AI 行为指引**: 本节是「覆写模块怎么用」的标准回答骨架。用户问操作方式时按 ①→⑤ 逐条讲；用户只问某一环（如"怎么新建"）时讲对应一环并带上前置入口。

**① 覆写模块按钮（入口）**
- 位置：**运行状态页顶部**，与「启动/停止」「重启」按钮并列的 **Overwrite Module** 图标按钮（`id="edit_overwrite"`，`title="Overwrite Module"`）。
- 触发：`editOverwrite()` → `ConfigEditor.showOverwrite()`（`config_edit.htm`），复用配置编辑器模态框。与菜单「服务→OpenClash→覆写设置」CBI 页面是**两个独立入口**。

**② 窗口弹出**
- 点击后弹出覆写编辑器窗口（覆盖层 `overlay`，`isOverwrite=true`），标题变为「Overwrite Edit」。
- 顶部显示**覆写警告横幅**（`overwrite-banner`）：*"You are editing the overwrite script, please note that some settings may cause the abnormal, be careful with the modification!"*
- 窗口结构：顶部**覆写模块卡片栏**（`overwrite-card-bar`，每个模块一张卡片 + 一个「+」新建卡片）+ 下方 **CodeMirror 主编辑器**（编辑当前选中文件的正文）。
- 模式切换标签页（原始/运行时）、布局按钮在覆写模式被隐藏。

**③ 创建（新建覆写模块）**
- 卡片栏最左侧「**+**」卡片 → 弹出 **Add Overwrite Module** 窗口（`showAddOverwritemodel()`）。
- 两个标签页：
  - **File**：直接新建本地覆写文件——填「文件名 / 匹配配置文件（config：`all` 或指定文件名）/ 顺序（order）」→ Add。
  - **Subscribe**：订阅型覆写——`type=http` 时填订阅 URL（可加 `param` 参数行），插件拉取远程覆写内容。
- 内置一张始终存在的 **`openclash_custom_overwrite.sh`** 卡片（文件名固定，不可改名，存于 `/etc/openclash/custom/`）。
- 新建后卡片支持：启用/停用开关、刷新（Subscribe 远程拉取）、齿轮（编辑参数）、删除（`delete_overwrite_file`）、拖拽排序（调整 order）。

**④ 编辑（语法格式与保存）**
- 点选卡片（或齿轮）→ 在主编辑器打开该覆写文件，按 **INI 三段格式**编辑：`[General]`（键值对/环境变量）、`[Overwrite]`（Shell 命令，可用 `ruby_*` 函数族）、`[YAML]`（原始 YAML + 操作符）。**必须包含至少一个段头**，否则不生效。详细格式/操作符见 §16.2。
- 点 Save → POST `/config_file_save`（`config_file` + `content`），后端仅允许写入 `/etc/openclash/overwrite/<名称>` 或 `/etc/openclash/custom/openclash_custom_overwrite.sh`（其它路径拒绝）。

**⑤ 原理（生效机制）**
- 覆写文件落盘 `/etc/openclash/overwrite/<名称>`，并注册到 UCI `openclash.config_overwrite`（按 order 排序、config 匹配当前配置）。
- 重启 OpenClash 时 `overwrite_file()`（`init.d/openclash`）按段头解析：`[General]` 提前写入 UCI（影响 `yml_change.sh` 行为）；`[Overwrite]`/`[YAML]` 生成 `/tmp/yaml_overwrite.sh`，在 `yml_change.sh`/`yml_rules_change.sh` **之后**执行 → 深度合并/覆盖订阅与 LuCI 输出（含硬编码项，覆盖需谨慎）。

> **注意**：以上是「覆写模块」（文件式自定义）的操作方式。菜单「覆写设置」CBI 页（`11-overwrite-settings.md`）配置的是内置覆写选项（DNS/规则/Smart 等 UCI 选项）；`yml_change.sh` 的覆写逻辑是实现细节——两者仅在用户追问时补充，不作为「怎么用」的主线。

**核心机制**: OpenClash 的覆写模块分两个阶段执行（均在 `/etc/init.d/openclash start_service` 流程中）：

**第一阶段 — UCI 预处理**（`overwrite_file()` 函数，在 `yml_change.sh` 之前执行）：
1. 遍历 UCI 中所有 `config_overwrite` 条目（按 `order` 排序）
2. 检查覆写是否匹配当前配置文件（`config` 字段支持 `all` 或指定文件名）
3. 读取 `/etc/openclash/overwrite/<名称>` 文件内容
4. 解析 `[General]` 段 → 将键值对写入 UCI `openclash.@overwrite[0]`（如 `EN_MODE`、`DNS_PORT` 等），供后续 `yml_change.sh` 读取
5. 处理 `DOWNLOAD_FILE` 指令 → 下载外部文件
6. 生成 `/tmp/yaml_overwrite.sh` 脚本（包含 `[Overwrite]` 和 `[YAML]` 段的内容，暂不执行）

**第二阶段 — YAML 覆写**（`/tmp/yaml_overwrite.sh`，在 `yml_change.sh` 和 `yml_rules_change.sh` 之后执行）：
7. 执行 `[Overwrite]` 段的 Shell 命令（可使用 `ruby_*` 函数族修改 YAML）
8. 将 `[YAML]` 段的 YAML 内容深度合并到运行配置

> **执行顺序含义**：`[General]` 段在 `yml_change.sh` 之前生效（因为写入 UCI），因此可以影响 `yml_change.sh` 的行为；`[Overwrite]` 和 `[YAML]` 段在 `yml_change.sh` 和 `yml_rules_change.sh` 之后执行，因此**可以覆盖这两个脚本的所有输出**——包括「插件强制覆盖/禁用的设置」表格中的硬编码项（如 `allow-lan`、`bind-address`、`sniffer.sniff` 等）。⚠️ **覆盖这些硬编码项可能导致功能异常**，请谨慎使用。

**覆写模块能做什么**:
- 给订阅配置**追加/覆盖**任意 Mihomo YAML 字段（如 DNS、Sniffer、TUN、规则等）
- 设置环境变量供 `yml_change.sh` 等后续脚本使用
- 下载外部文件（通过 `DOWNLOAD_FILE` 指令）
- 对未提供 UI 选项的 Mihomo 高级功能进行配置

### 16.2 覆写文件的格式

覆写文件使用 **INI 风格的分段格式**，支持三个段：

```ini
[General]
# 键值对，将作为环境变量导出
# 支持的 key 列表见下方

[Overwrite]
# Shell 命令，可使用 ruby_* 函数族操作 YAML

[YAML]
# 原始 YAML 片段，将合并到运行配置
```

> **⚠️ 强制要求**：覆写文件**必须包含至少一个段头**（`[General]`、`[Overwrite]`、`[YAML]` 之一），否则所有内容将被忽略，覆写模块不会生效。这是因为 `overwrite_file()` 函数（`/etc/init.d/openclash`）按段头解析文件内容——所有标志位 `in_general`/`in_overwrite`/`in_yaml` 初始为 `0`，仅在遇到对应段头时才设为 `1`。段头之前、之后无段头的内容均被跳过。空行和以 `#`/`;` 开头的注释行会被安全忽略，不影响段头解析。

#### 16.2.1 `[General]` 段 — 键值对/环境变量

每行格式: `KEY = VALUE`（大小写不敏感，会自动转大写）

**允许的所有 Key** (共 ~85 个，由 `overwrite_file()` 函数中的 `allowed_keys_types` 定义):

| 类别 | Key 示例 | 类型 | 说明 |
|------|----------|------|------|
| 端口 | `DNS_PORT`, `PROXY_PORT`, `TPROXY_PORT`, `HTTP_PORT`, `SOCKS_PORT`, `MIXED_PORT` | int | 覆写端口号 |
| 模式 | `EN_MODE`, `PROXY_MODE`, `STACK_TYPE` | string | 覆写运行/代理模式 |
| DNS | `ENABLE_CUSTOM_DNS`, `ENABLE_RESPECT_RULES`, `APPEND_WAN_DNS`, `APPEND_DEFAULT_DNS` | int_bool | DNS 覆写 |
| Fake-IP | `FAKEIP_RANGE`, `FAKEIP_RANGE6`, `STORE_FAKEIP`, `CUSTOM_FAKEIP_FILTER`, `CUSTOM_FAKEIP_FILTER_MODE` | string/int_bool | Fake-IP 相关 |
| Meta | `ENABLE_TCP_CONCURRENT`, `ENABLE_UNIFIED_DELAY`, `ENABLE_META_SNIFFER`, `ENABLE_META_SNIFFER_PURE_IP`, `ENABLE_GEOIP_DAT` | int_bool | Meta 内核 |
| 流量 | `ROUTER_SELF_PROXY`, `DISABLE_UDP_QUIC`, `SKIP_PROXY_ADDRESS`, `COMMON_PORTS`, `CHINA_IP_ROUTE` | int_bool/int/string | 流量控制 |
| IPv6 | `IPV6_ENABLE`, `IPV6_MODE`, `IPV6_DNS` | int_bool/int | IPv6 |
| GEO | `GEO_AUTO_UPDATE`, `GEOIP_AUTO_UPDATE`, `GEOSITE_AUTO_UPDATE`, `GEOASN_AUTO_UPDATE` | int_bool | GEO 更新 |
| 自定义 | `ENABLE_CUSTOM_CLASH_RULES`, `ENABLE_RULE_PROXY` | int_bool | 规则 |
| Smart | `AUTO_SMART_SWITCH`, `SMART_ENABLE_LGBM`, `SMART_POLICY_PRIORITY` | int_bool/string | Smart 策略 |
| 特殊 | `CONFIG_FILE` | string | 覆写 config_path（切换配置） |
| 特殊 | `AGE_SECRET_KEY`, `AGE_PUBLIC_KEY` | string | Age 加密密钥 |
| 特殊 | `SUB_INFO_URL` | string | 订阅信息 URL |
| 特殊 | `DOWNLOAD_FILE` | string | 下载外部文件（见单独说明） |
| 特殊 | `DA_PASSWORD` | string | Dashboard 密码 |
| 特殊 | `GLOBAL_UA` | string | 全局 User-Agent |
| 特殊 | `RESTART` | bool | 覆写变更后是否重启 |

**类型说明**: `int`=整数, `int_bool`=0/1, `bool`=true/false, `string`=任意字符串

> 这些环境变量在 `yml_change.sh`、`yml_rules_change.sh` 及自定义覆写脚本中可通过 `$KEY_NAME` 直接引用。
> 本表按类别分组概览；**完整 Key 列表与对应 UCI** 见 `17-overwrite-module-examples.md` §17.5.2 速查表。

> **⚠️ [General] 段 = 插件设置的修改来源**：`[General]` 是覆写模块中**唯一能修改「插件设置」（UCI 层选项）的途径**——重启时 `overwrite_file()` 将键值对写入 UCI（`openclash.@overwrite[0]`），供 `yml_change.sh`/`yml_rules_change.sh` 读取生效；`[YAML]`/`[Overwrite]` 段只能修改运行 YAML。凡修复涉及插件设置（运行/代理模式、端口、DNS、Fake-IP、Meta、流量控制、IPv6、GEO、Smart 等本表所列类别，对应 LuCI「覆写设置」CBI 页选项，见 `11-overwrite-settings.md`）时，必须在 `[General]` 段以 `KEY = VALUE` 覆写，而非用 `[YAML]`。示例见 `17-overwrite-module-examples.md` §17.3（`EN_MODE = fake-ip-tun`）。

#### 16.2.2 `[Overwrite]` 段 — Shell 脚本

此段内容直接作为 Shell 命令执行。可用的函数（定义于 `ruby.sh`，均以目标 YAML 文件作为首个参数）：
- `ruby_read <file> <key_path>` — 读取 YAML 值
- `ruby_read_hash <var> <key_path>` — 读取 Ruby 变量中的哈希值
- `ruby_read_hash_arr <file> <key_path> <sub_path>` — 遍历哈希数组并读取每个元素的子值
- `ruby_edit <file> <key_path> <value>` — 修改 YAML 键值
- `ruby_cover <file> <key_path> <value>` — 覆盖 YAML 键值（第 3 参为已存在文件时改为从该文件取值）
- `ruby_merge <file> <key_path> <src_file>` — 从文件合并 YAML 哈希
- `ruby_merge_hash <file> <key_path> <hash>` — 合并指定哈希到键路径
- `ruby_uniq <file> <key_path>` — 数组去重
- `ruby_arr_add_file <file> <key_path> <idx> <list_file> <sub_path>` — 从文件将数组元素插入到指定下标
- `ruby_arr_head_add_file <file> <key_path> <list_file> <sub_path>` — 从文件将数组元素插入到数组开头
- `ruby_arr_insert <file> <key_path> <idx> <value>` — 在数组指定下标插入单个元素
- `ruby_arr_insert_hash <file> <key_path> <idx> <hash>` — 在数组指定下标插入哈希
- `ruby_arr_insert_arr <file> <key_path> <idx> <array>` — 在数组指定下标插入一个数组
- `ruby_arr_edit <file> <key_path> <match> <new_value>` — 按值/字段匹配编辑数组元素
- `ruby_map_edit <file> <key_path> <map_key> <sub_path> <value>` — 编辑哈希内嵌套哈希的字段
- `ruby_delete <file> <key_path> [<key>]` — 删除键/数组元素（省略键时删除键路径本身）
- `uci_get_config <key>` — 读取 UCI 配置（覆写优先）

#### 16.2.3 `[YAML]` 段 — 原始 YAML 注入（含操作符）

`[YAML]` 段使用 Ruby 将内容**深度合并**到运行配置文件。支持多种**操作符后缀**实现精细控制：

**操作符速查表**：

| 操作符 | 写法 | 行为 |
|--------|------|------|
| **默认合并** | `key` 或 `<key>` | Hash 递归合并，标量直接覆盖，键不存在则添加 |
| **强制覆盖** | `key!` 或 `<key>!` | 强制替换整个值（不做递归合并） |
| **数组后置追加** | `key+` 或 `<key>+` | 将新元素追加到数组末尾 |
| **数组前置插入** | `+key` 或 `+<key>` | 将新元素插入到数组开头 |
| **数组差集删除** | `key-` 或 `<key>-` | 从数组中删除指定元素；非数组则删除整个键 |
| **批量条件更新** | `key*` 或 `<key>*` | 按 `where` 条件匹配，用 `set` 子句更新（见下） |

`<key>` 语法用于键名含特殊字符或与操作符冲突时。

##### 操作符详解与示例

**1. 默认合并 (`key` / `<key>`)**

Hash 值递归合并，键不存在则添加，标量直接覆盖。
```yaml
dns:
  enable: true           # 修改现有键
  cache-algorithm: lru   # 添加新键
mixed-port: 10802        # 直接覆盖标量
tun:
  enable: true           # 合并 Hash（仅改指定字段，其余保留）
  stack: gvisor
```

**2. 强制覆盖 (`key!` / `<key>!`)**

强制替换整个值，不做递归合并。
```yaml
dns:
  fake-ip-filter!:         # 替换整个 fake-ip-filter 数组
    - '*.lan'
    - 'new.domain.com'
rules!:                    # 强制覆盖整个 rules 数组
  - DOMAIN-SUFFIX,example.com,DIRECT
  - MATCH,PROXY
<dns>!:                    # <> 语法：强制覆盖整个 dns 配置
  enable: false
  nameserver:
    - '114.114.114.114'
```

**3. 数组后置追加 (`key+` / `<key>+`)**

将新元素追加到数组末尾。
```yaml
dns:
  nameserver+:
    - '1.1.1.1'
    - '8.8.8.8'
rules+:
  - DOMAIN-SUFFIX,example.com,REJECT
<nameserver>+:
  - '8.8.8.8'
```

**4. 数组前置插入 (`+key` / `+<key>`)**

将新元素插入到数组开头（优先匹配）。
```yaml
dns:
  +nameserver:
    - '223.5.5.5'
+rules:
  - DOMAIN-SUFFIX,priority.com,DIRECT
+<nameserver>:
  - '119.29.29.29'
```

**5. 数组删除/键删除 (`key-` / `<key>-`)**

从数组中移除指定元素；对非数组删除整个键。值为空(null/~)时删除整个键。
```yaml
dns:
  nameserver-:
    - '8.8.8.8'
    - '8.8.4.4'
rules-:
  - DOMAIN-SUFFIX,old.com,REJECT
  cache-algorithm-:         # 删除整个 cache-algorithm 键
```

**6. 批量条件更新 (`key*` / `<key>*`)**

按 `where` 条件匹配集合元素，用 `set` 子句更新指定字段。

**支持的集合类型**: Hash 值数组 (如 proxy-groups)、字符串数组 (如 rules)
**where 条件格式**: `字段名: 值`，支持正则 `/pattern/`

**set 子句支持的操作符**: 同顶层（默认覆盖、`!`、`+`、`-`）

```yaml
# === 对 proxy-groups (Hash 数组) ===

# 按 type 匹配，替换整个 proxies 列表
proxy-groups*:
  where:
    type: select
  set:
    proxies:
      - 'new-proxy1'
      - 'new-proxy2'

# 按 name 正则匹配，向 proxies 开头插入
proxy-groups*:
  where:
    name: '/^HK/'
  set:
    +proxies:
      - 'hk-new-proxy'

# 按 type 匹配，从 proxies 中移除指定节点
proxy-groups*:
  where:
    type: select
  set:
    proxies-:
      - 'old-proxy1'

# 使用数组包含条件（proxies 须包含指定元素）
proxy-groups*:
  where:
    type: select
    proxies:
      - 'old-proxy1'
  set:
    proxies:
      - 'new-proxy1'

# 修改 url-test 组的 interval
<proxy-groups>*:
  where:
    type: url-test
  set:
    interval: 300

# === 对 proxies (节点数组) ===

# 修改 socks5 节点端口
proxies*:
  where:
    type: socks5
  set:
    port: 1080

# === 对 rules (字符串数组) ===

# 替换匹配的规则
rules*:
  where:
    value: 'DOMAIN-SUFFIX,old.com,REJECT'
  set:
    value: 'DOMAIN-SUFFIX,new.com,DIRECT'

# 正则匹配删除规则（set value 为空/不写）
rules*:
  where:
    value: '/,REJECT$/'
  set:
    value:

# === 对 hosts (Hash 集合) ===

# 更新指定 hosts 键
hosts*:
  where:
    key: '*.mihomo.dev'
  set:
    '*.mihomo.dev': '::1'

# 删除指定 hosts 键
hosts*:
  where:
    key: '*.old.dev'
  set:
    key-:
```

**7. 组合操作**

同一块内可同时使用多个操作符：
```yaml
dns:
  nameserver-:         # 先删除
    - '8.8.8.8'
  +nameserver:         # 再前置插入
    - '223.5.5.5'
  nameserver+:         # 再后置追加
    - '1.0.0.1'
```

#### 16.2.4 `DOWNLOAD_FILE` 特殊指令（`[General]` 段）

格式: `DOWNLOAD_FILE = url=..., path=..., cron=..., force=..., ua=..., restart=...`

用于在覆写模块中下载外部文件。字段说明：
- `url` — 下载地址 (必填)
- `path` — 保存路径 (必填)
- `cron` — cron 表达式，0 表示不添加定时任务
- `force` — `true` 强制重新下载
- `ua` — 自定义 User-Agent
- `restart` — `true` 下载后重启核心
