## 配置订阅与配置管理

> **用途**: 配置订阅（自动更新、keyword/Age 等）与配置管理（上传/切换/编辑）页面（§12.1–12.8）。
> **UCI**: 订阅 `openclash.config_subscribe`（多条）；当前配置 `openclash.config.config_path`
> **LuCI 路径**: 服务 → OpenClash → 配置订阅 / 配置管理

### 12.1 订阅更新实现总览

```
Cron 或「更新配置」→ openclash.sh
  ├─ config_download()   curl 下载订阅（支持代理/直连回退）
  ├─ sub_convert         可选：发往订阅转换后端
  ├─ config_cus_up()     Ruby YAML 解析 + keyword/ex_keyword 过滤
  ├─ config_test()       clash -t 校验 YAML
  └─ config_su_check()   新旧对比，有变化则替换并标记重启
```

`sub_info_get()` 流程：遍历所有 `config_subscribe` → 构建下载 URL（追加 `custom_params`、设置 `sub_ua`）→ 有 `sub_convert` 则发往转换后端 → 有 `secret_key` 则先 Age 解密 → Ruby 解析出节点 → 按 `keyword`/`ex_keyword` 过滤 → 合并进当前配置的 `proxies`/`proxy-groups` → 写入 `/etc/openclash/config/<name>.yaml` 并标记重启。

**关键字匹配**（`server_key_match()`）：`&` 转正向预查链 `(?=.*kw1)(?=.*kw2)`（AND），`|` 转择一 `(kw1|kw2)`（OR）。

### 12.2 自动更新（每条订阅单独设置）

| 选项 | UCI Key | 默认 | 说明 |
|------|---------|------|------|
| 自动更新 | `auto_update` | 0 | Flag |
| 更新模式 | `config_auto_update_mode` | — | `0` 预约模式（指定周几几点）/ `1` 循环模式（每隔 N 分钟） |
| 更新日 | `config_update_week_time` | — | `*`=每天、`1` 周一 … `0` 周日 |
| 更新时间 | `auto_update_time` | — | 0–23 点 |
| 更新间隔（分钟） | `config_update_interval` | 60 | 仅循环模式，1–525600 |

- **调度**: `add_cron()` 为每条有地址且 `auto_update=1` 的条目生成独立 cron 行（`/usr/share/openclash/openclash.sh '<name>'`），服务启动或 `/etc/init.d/openclash reload cron` 时重建
- **迁移回退**: 旧全局 `openclash.config.auto_update` 等键在条目未写自己的值时生效，编辑保存后写入条目；条目显式 `auto_update=0` 可覆盖全局
- **循环模式表达式**: 整除 60 的间隔用 `*/N * * * *`；整小时用 `0 * * * *` / `0 0-23/H * * *`；整除 1440 的跨小时间隔（45/90 等）用多条 `分钟 起始-23/步长 * * *`；其它任意分钟值由 cron 每分钟调 `openclash.sh '<name>' loop <interval>`，按 `/tmp/openclash_cfg_update_<md5>` 时间戳守卫（刷新完成时写入，间隔从上一次完成算起；未到期退出，到期后等全局锁再查一次时间戳避免重复）
- **串行化**: 所有订阅刷新共用 `openclash.sh` 全局锁排队执行（Ruby 解析、内核校验与防火墙/DNS 回退峰值内存高，且共享任务计数与重启逻辑）

### 12.3 每条订阅 (config_subscribe TypedSection)

| 字段 | UCI Key | 用途 |
|------|---------|------|
| 订阅名称 | `name` | 用于区分，勿重名 |
| 订阅地址 | `address` | 订阅 URL |
| 自动更新 | `auto_update` / `config_auto_update_mode` / `config_update_week_time` / `auto_update_time` / `config_update_interval` | 见 §12.2 |
| User-Agent | `sub_ua` | 预设 clash-verge / clash.meta / clash |
| 在线订阅转换 | `sub_convert` | 转换后端地址 |
| 订阅转换模板 | `sub_template` | 模板 URL |
| 筛选节点 | `keyword` | 保留匹配的节点 |
| 排除节点 | `ex_keyword` | 排除匹配的节点 |
| 自定义参数 | `custom_params` | 追加到订阅 URL |
| Age 加密密钥 | `secret_key` | Age 解密密钥；设置后先用 age 解密 |

- **关键字格式**: `香港&01` = 名称同时含「香港」和「01」；`香港|台湾` = 含任一即保留
- **跳过证书校验**（`skip-cert-verify`）：仅 `sub_convert` 启用时显示，默认 `true`；配置上传弹窗中的同名选项默认也勾选

### 12.4 配置管理页面 (Config Manage / config)

| 区块 | 功能 | 后端路由 |
|------|------|----------|
| 文件上传 | 配置文件、代理/规则提供商、内核二进制、备份恢复 | `/upload_config`（靠 `file_type` 区分） |
| 配置文件列表 | 查看/切换/编辑/重命名/复制/下载/删除 | `/switch_config`、`/config_file_list`、`/config_file_save` 等 |
| 提供商文件管理 | 跳转代理/规则提供商管理子页 | 跳转链接 |
| 配置文件编辑器 | 双栏 YAML（左可编辑、右只读） | `/config_file_read` + `/config_file_save` |

### 12.5 文件上传

| 上传类型 | `file_type` | 目标目录 | 说明 |
|----------|-------------|----------|------|
| 配置文件 | `config` | `/etc/openclash/config/` | `.yaml`/`.yml`，上传后自动设为当前配置 |
| 代理集文件 | `proxy-provider` | `/etc/openclash/proxy_provider/` | `proxy-providers` 的节点文件 |
| 规则集文件 | `rule-provider` | `/etc/openclash/rule_provider/` | `rule-providers` 的规则文件 |
| 内核文件 | `clash_meta` | `/etc/openclash/core/` | 支持 `.tar.gz`/`.gz` 自动解压，`chmod 4755` |
| 备份恢复 | `backup-file` | 恢复到 `/etc/config/openclash` | 上传备份并还原 UCI |

### 12.6 配置文件列表

| 操作 | 说明 |
|------|------|
| SwiTch（切换） | 改 `config_path` UCI + commit，自动重启核心 |
| Edit（编辑） | 跳转双栏 YAML 编辑器 |
| Rename（重命名） | 输入新名称后 `mv` |
| Copy（复制） | 生成 `<文件名>(N).yaml` |
| Download（下载配置） | 下载原始配置文件 |
| Download Run（下载运行配置） | 下载 `/etc/openclash/<name>.yaml`（经脚本处理后的实际运行配置） |
| Remove（移除） | 删 YAML + 历史缓存 `/etc/openclash/history/<name>.db` + 运行时配置，并自动切换到其它配置 |

### 12.7 配置文件编辑器

| 项 | 说明 |
|----|------|
| 左栏（可编辑） | 读写 `config_path` 指向的配置；保存时自动 `\r\n` → `\n` |
| 右栏（只读） | 显示运行时配置 `/etc/openclash/<name>` 或默认模板 `/usr/share/openclash/res/default.yaml` |
| 按钮 | Commit（保存配置）、Create（新建配置）、Apply（应用配置） |
| 快捷键 | F10 切换 diff、F11 全屏 |

### 12.8 提供商子页面

`servers`（代理节点管理）、`servers-config`（节点配置）、`groups-config`（策略组配置）、`proxy-provider-config`（代理提供商）、`proxy-provider-file-manage`（代理集文件）、`rule-providers-file-manage`（规则集文件）。
