## 配置订阅页面 (Config Subscribe / config-subscribe)

> **用途**: 配置订阅（自动更新、每条订阅的 keyword/Age 等）与配置管理页面（上传/切换/编辑，§12.1–12.8）。

> UCI Section: `openclash.config_subscribe` (多条)

> **AI 行为指引**: 当用户询问订阅相关问题（如"如何过滤节点"、"订阅转换怎么用"、"订阅 URL 格式不对怎么办"、
> "keyword 和 ex_keyword 的区别"、"Age 加密是什么"），AI 应查阅 [Mihomo 代理协议文档](https://wiki.metacubex.one/config/proxies/)
> 了解节点名称的命名规范和常见格式，涉及订阅处理实现细节时查阅
> [OpenClash 源码](https://github.com/vernesong/OpenClash/tree/dev) 中 `openclash.sh` 的
> `sub_info_get()`、`config_cus_up()`、`server_key_match()` 等函数，
> 然后告知用户具体的配置方法。对于订阅转换后端问题，
> 告知用户转换后端的地址格式和模板 URL 的作用。

### 12.1 实现总览

```
 Cron / Web UI「更新配置」
        │
        ▼
 openclash.sh (订阅更新主脚本)
        │
        ├─ config_download()     → curl 下载订阅 URL (支持代理/直连回退)
        ├─ sub_convert           → 可选: 发送到订阅转换后端
        ├─ config_cus_up()       → Ruby YAML 解析 + 节点关键字过滤/排除
        ├─ config_test()         → clash -t 验证 YAML 语法
        └─ config_su_check()     → 新旧对比，有更新则替换 + 标记重启
```

**核心流程** (`openclash.sh` 中的 `sub_info_get()`):
1. 遍历所有启用的 `config_subscribe` 条目
2. 对每条订阅构建下载 URL（添加 `custom_params`、设置 `sub_ua`）
3. 如果设置了 `sub_convert`，将 URL 发到转换后端获取处理后的配置
4. 如果设置了 `secret_key` (Age 加密)，先用 age 解密
5. 用 Ruby YAML 解析订阅配置 → 获取所有代理节点
6. 根据 `keyword` / `ex_keyword` 正则匹配过滤节点：
   - `&` = AND: 节点名必须同时包含所有关键字
   - `|` = OR: 节点名包含任一关键字即保留
7. 将过滤后的节点合并到当前配置的 `proxies` 和 `proxy-groups` 中
8. 写入 `/etc/openclash/config/<name>.yaml`，标记核心需重启

**关键字匹配实现** (`server_key_match()`):
将用户输入的关键字转换为 Ruby 正则表达式。`&` 分隔的转为正向预查链 `(?=.*kw1)(?=.*kw2)`，`|` 分隔的转为择一匹配 `(kw1|kw2)`。

### 12.2 自动更新 (Auto Update)

| 选项 | UCI Key | 说明 |
|------|---------|------|
| 自动更新 (Auto Update) | `auto_update` | Flag，默认 0 |
| 更新模式 | `config_auto_update_mode` | `0`=预约模式(指定周几几点), `1`=循环模式(每隔N分钟) |
| 更新日 (Update Time Every Week) | `config_update_week_time` | `*`=每天 (Every Day), `1`=周一, …, `0`=周日 |
| 更新时间 (Update time every day) | `auto_update_time` | 0-23 点 |
| 更新间隔/分钟 (Update Interval min) | `config_update_interval` | 仅循环模式，默认 60 |

### 12.3 每条订阅 (`config_subscribe` TypedSection)

| 字段 | 用途 |
|------|------|
| 订阅名称 (Config Alias) | `name` | 用于区分，请勿重名 |
| 订阅地址 (Subscribe Address) | `address` | 订阅 URL |
| **User-Agent** (UA) | `sub_ua` | 预设 clash-verge/clash.meta/clash |
| **在线订阅转换 (Subscribe Convert Online)** | `sub_convert` | 订阅转换后端地址 |
| **订阅转换模板 (Template Name)** | `sub_template` | 转换模板 URL |
| **筛选节点 (Keyword Match)** | `keyword` | 节点关键字匹配 (保留匹配的节点) |
| **排除节点 (Exclude Keyword Match)** | `ex_keyword` | 排除关键字 (排除匹配的节点) |
| **自定义参数 (Custom Params)** | `custom_params` | 自定义订阅 URL 参数 |
| **Age 加密密钥 (Secret Key)** | `secret_key` | Age 加密密钥 |

**关键字格式**: 使用 `&` 表示 AND (同时满足)，使用 `|` 表示 OR
- 例：`香港&01` → 节点名同时包含"香港"和"01"
- 例：`香港|台湾` → 节点名包含"香港"或"台湾"

---

## 配置管理页面 (Config Manage / config)

> LuCI 路径: `服务` → `OpenClash` → `配置管理` (顺序第 80)
> UCI 映射: `openclash.config.config_path`

### 12.4 实现总览

配置管理页面是一个多功能综合页面，提供配置文件的上传、切换、编辑、重命名、删除以及提供商文件管理功能。

**核心功能区块**:

| 区块 | 功能 | 后端路由 |
|------|------|----------|
| 文件上传 (Upload) | 上传配置文件、代理/规则提供商、核心二进制、备份恢复 | `/upload_config` + `file_type` 参数区分 |
| **配置文件列表** | 查看/切换/编辑/重命名/复制/下载/删除配置 | `/switch_config`、`/config_file_list`、`/config_file_save` 等 |
| **提供商文件管理** | 跳转到代理提供商和规则提供商管理子页 | 跳转链接 |
| **配置文件编辑器** | 双栏 YAML 编辑器（左侧可编辑用户配置，右侧只读默认模板） | `/config_file_read` + `/config_file_save` |

### 12.5 文件上传

| 上传类型 | `file_type` 值 | 目标目录 | 说明 |
|----------|---------------|----------|------|
| 配置文件 (Config) | `config` | `/etc/openclash/config/` | `.yaml`/`.yml` 格式，上传后自动设为当前启用配置 |
| 代理集文件 (Proxy Provider File) | `proxy-provider` | `/etc/openclash/proxy_provider/` | 订阅中 `proxy-providers` 的节点文件 |
| 规则集文件 (Rule Provider File) | `rule-provider` | `/etc/openclash/rule_provider/` | 订阅中 `rule-providers` 的规则文件 |
| 内核文件 (Core File) | `clash_meta` | `/etc/openclash/core/` | 支持 `.tar.gz`/`.gz` 格式自动解压，`chmod 4755` |
| 备份恢复 | `backup-file` | 恢复到 `/etc/config/openclash` | 上传备份并恢复 UCI 配置 |

### 12.6 配置文件列表

| 操作 | 功能 | 说明 |
|------|------|------|
| **SwiTch** (切换) | 切换启用配置 | 修改 `config_path` UCI + commit，自动重启核心 |
| **Edit** (编辑) | 在线编辑配置 | 跳转到双栏 YAML 编辑器 |
| **Rename** (重命名) | 重命名 | 输入新名称，`mv` 重命名文件 |
| **Copy** (复制配置) | 复制配置 | 生成 `<文件名>(N).yaml` 副本 |
| **Download** (下载配置) | 下载配置文件 | HTTP 下载原始配置文件 |
| **Download Run** (下载运行配置) | 下载运行时配置 | 下载 `/etc/openclash/<name>.yaml`（经脚本处理后的实际运行配置） |
| **Remove** (移除) | 删除配置 | 删除 YAML 文件 + 历史缓存 `/etc/openclash/history/<name>.db` + 运行时配置，自动切换到其他配置 |

### 12.7 配置文件编辑器

双栏 YAML 编辑器：
- **左栏 (可编辑)**: 读写当前 `config_path` 指向的配置，保存时自动 `\r\n` → `\n` 转换
- **右栏 (只读)**: 展示运行时配置 `/etc/openclash/<name>` 或默认模板 `/usr/share/openclash/res/default.yaml`
- **操作按钮**: Commit (保存配置 (Commit Settings))、Create (新建配置)、Apply (应用配置 (Apply Settings))
- **快捷键**: F10 diff 控制、F11 全屏模式

### 12.8 提供商子页面

通过配置管理页面可跳转到以下子页面（独立 CBI 页面）：
- **servers** — 代理节点管理（编辑/新增/删除节点）
- **servers-config** — 节点配置编辑器
- **groups-config** — 策略组配置编辑器
- **proxy-provider-config** — 代理提供商配置
- **proxy-provider-file-manage** — 代理提供商文件管理
- **rule-providers-file-manage** — 规则提供商文件管理

---
