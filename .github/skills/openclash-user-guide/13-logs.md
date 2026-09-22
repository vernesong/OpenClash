## 运行日志页面 (Server Logs / log)

> **用途**: 运行日志页面（Plugin/Core/Debug 标签页）与 `openclash_debug.sh` 30 章节调试日志（§13.1–13.6）。

> **AI 行为指引**: 当用户询问「如何查看日志」「如何生成调试日志」「日志里某段内容代表什么」时，AI 应引导用户在「服务 → OpenClash → 运行日志」页操作，并结合本文件说明 Plugin/Core/Debug 三个标签页的区别与 §13.5 debug 30 章节的定位方法（用 `## 章节名` 定位）。排障流程见 `14-diagnostics.md` §14.2 决策树。

> LuCI 路径: `服务` → `OpenClash` → `运行日志` (顺序第 90)
> UCI 映射: `openclash.config.clog`（日志内容实际由 `/refresh_log` 读取 `/tmp/openclash.log` 而来）

### 13.1 实现总览

运行日志页面是一个双标签页的日志查看器。页面布局包含以下区域：

### 13.2 标签页（Plugin / Core / Debug）

> 注意区分：标签页 2 里的「Debug」只是**内核日志等级按钮**；标签页 3「Debug Logs」是 `openclash_debug.sh` 生成的 **30 章节调试日志**（见 §13.5），两者不是一回事。

**标签页 1 — Plugin Logs** (默认激活)：展示 OpenClash 插件自身日志（Shell/Ruby/Lua 脚本输出），通过 XHR 轮询 (`/refresh_log`) 每秒刷新。

**标签页 2 — Core Logs** (可切换)：展示 Mihomo 内核实时日志，通过 WebSocket 连接到内核 API (`/logs?token=...&level=...`)。该标签页内嵌 **5 个日志等级单选按钮**：

| 按钮 | 功能 | 后端操作 |
|------|------|----------|
| **Info** (信息) | 默认等级，显示一般信息及以上 | GET `/log_level` → 设置 WebSocket level |
| **Warning** (警告) | 只显示警告及以上 | GET `/switch_log` + WebSocket 重连 |
| **Error** (错误) | 只显示错误及以上 | 同上 |
| **Debug** (调试) | 显示所有调试信息 | 同上 |
| **Silent** (静默) | 静默模式，不显示内核日志 | 同上 |

**标签页 3 — Debug Logs** (可切换)：展示插件的调试日志，内容由 `openclash_debug.sh` 生成，以 Markdown `## 章节名` 分 **30 个章节**输出，涵盖系统信息、依赖检查、内核检查、GEO 数据、插件/覆写设置、自定义规则与自定义脚本、防火墙规则（nftables/iptables）、路由、TUN、端口、网络接口、DNS 与网络连通性测试、Mihomo API 健康检查、最近运行日志、活动连接等。完整章节清单见 §13.5。

### 13.3 底部操作按钮栏（Plugin/Core 标签页共用）

| 按钮 | 功能 | 后端操作 |
|------|------|----------|
| **Stop Refresh** (停止刷新) | 暂停日志刷新（XHR 轮询 + WebSocket 均停止） | 停止 `poll_log()` 和 `coreLogWebSocketStop()` |
| **Start Refresh** (开始刷新) | 恢复日志刷新 | 重新启动轮询和 WebSocket |
| **Clean** (清理日志) | 清空日志文本框 | GET `/del_log` |
| **Download Log** (下载日志) | 下载完整日志文件（OC 日志 + Core 日志合并） | 调试日志会单独下载不会进行拼接 | 其他两个标签的内容前端进行拼接下载 |
| **Generate Logs** (生成调试日志) | 点击生成调试日志并展示 | 前端下载时不拼接 |

### 13.4 日志来源

**OpenClash|Mihomo 日志来源**: OpenClash 日志由后端将 UCI `clog` 字段内容写入 CodeMirror 日志编辑器。内核日志通过 WebSocket 实时推送到前端 `textarea#core_log`。

### 13.5 调试日志来源（`openclash_debug.sh` 30 个章节）

> 调试日志以 **Markdown 格式**输出到 `/tmp/openclash_debug.log`：每个章节以 `## 章节名` 标题分隔（章节内为表格 / bash 代码块 / 引用段落），使用文件锁防止并发生成。`openclash_debug.sh` 当前收集以下 **30 个章节**：

  1) 系统信息
  2) 依赖检查
  3) 内核检查
  4) GEO 数据文件
  5) 模型、缓存文件状态
  6) 冲突插件检测
  7) 插件设置
  8) Cron 定时任务
  9) 覆写模块设置
  10) 自定义规则 一 （优先匹配）
  11) 自定义规则 二 （扩展匹配）
  12) 配置文件
  13) 自定义覆写设置
  14) 自定义防火墙设置
  15) NFTABLES 防火墙设置
  16) IPTABLES 防火墙设置
  17) NFT Sets 状态
  18) IPSET状态
  19) 路由表状态
  20) Tun设备状态
  21) 端口占用状态
  22) 网络接口状态
  23) 测试本机DNS查询(www.baidu.com)
  24) 测试内核DNS查询(www.instagram.com)
  25) DNS 解析文件
  26) 测试本机网络连接(www.baidu.com)
  27) 测试本机网络下载(raw.githubusercontent.com)
  28) Mihomo API 健康检查
  29) 最近运行日志 (切换为Debug模式)
  30) 活动连接信息

> **注意**: 隐私脱敏（IPv4 最后一字节 / IPv6 后半部分 / Downloading URL）在 `openclash_debug.sh` 末尾通过 `sed -i` 整体处理，**不是独立章节**。检索调试日志时用 `## 依赖检查` 等章节标题定位。

### 13.6 附加组件

页面同时加载 `openclash/toolbar_show`（**配置切换工具栏**：下拉选择当前配置文件 + Switch 按钮）和 `openclash/config_editor`（**页面内嵌 CodeMirror 编辑器**，预加载 CodeMirror CSS/JS 资源并通过全局 `merge_editor()` 函数对外开放合并视图功能，非日志渲染用途，仅作文件编辑功能复用）。

> **注意**: 如需修改 OpenClash 自身日志级别，请在「覆写设置 → 常规设置」中调整 `log_level`。内核日志标签页内可直接切换内核日志等级。

---
