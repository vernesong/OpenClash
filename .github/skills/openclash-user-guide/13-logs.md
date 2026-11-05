## 运行日志页面 (Server Logs / log)

> **用途**: 运行日志页（Plugin / Core / Debug 三个标签页）与 `openclash_debug.sh` 的 30 章节调试日志（§13.1–13.6）。
> **LuCI 路径**: 服务 → OpenClash → 运行日志
> **内容来源**: 页面经 `/refresh_log` 读取 `/tmp/openclash.log`；UCI 键 `openclash.config.clog` 仅保存文本内容
> **排查流程**: 见 `14-diagnostics.md` §14.2 决策树

### 13.1 实现总览

三标签页日志查看器（Plugin Logs / Core Logs / Debug Logs）。

### 13.2 三个标签页

> 注意区分：标签页 2 的「Debug」是**内核日志等级按钮**；标签页 3「Debug Logs」是 `openclash_debug.sh` 生成的 30 章节调试日志（§13.5），两者不是一回事。

| 标签页 | 内容 | 拉取方式 |
|--------|------|----------|
| 1 Plugin Logs（默认） | 插件自身日志（Shell/Ruby/Lua 输出） | XHR 轮询 `/refresh_log`，每秒 |
| 2 Core Logs | Mihomo 实时内核日志 | WebSocket `/logs?token=...&level=...` |
| 3 Debug Logs | `openclash_debug.sh` 的调试日志（`## 章节名` 分 30 章） | 生成后展示 |

标签页 2 内嵌 5 个内核日志等级按钮：

| 按钮 | 作用 | 后端 |
|------|------|------|
| Info | 一般信息及以上（默认） | GET `/log_level` 设置 WebSocket level |
| Warning / Error / Debug / Silent | 对应级别过滤（Silent = 不显示） | GET `/switch_log` + WebSocket 重连 |

### 13.3 底部按钮栏（Plugin / Core 共用）

| 按钮 | 作用 | 后端 |
|------|------|------|
| Stop Refresh | 暂停刷新（轮询与 WebSocket 均停） | 停止 `poll_log()` 与 `coreLogWebSocketStop()` |
| Start Refresh | 恢复刷新 | 重启轮询与 WebSocket |
| Clean | 清空日志文本框 | GET `/del_log` |
| Download Log | 下载当前标签日志（Plugin/Core 由前端拼接 OC 日志 + Core 日志） | 调试日志单独下载、不拼接 |
| Generate Logs | 生成调试日志并展示 | 同上 |

### 13.4 日志来源

OpenClash 日志由后端把 UCI `clog` 内容写入 CodeMirror 日志编辑器；内核日志经 WebSocket 实时推送至 `textarea#core_log`。

### 13.5 调试日志的 30 个章节（`openclash_debug.sh`）

输出 `/tmp/openclash_debug.log`，Markdown 格式（每章 `## 章节名`，章内为表格 / bash 代码块 / 引用），用文件锁防并发生成。

| # | 章节 | # | 章节 | # | 章节 |
|---|------|---|------|---|------|
| 1 | 系统信息 | 11 | 自定义规则 二（扩展匹配） | 21 | 端口占用状态 |
| 2 | 依赖检查 | 12 | 配置文件 | 22 | 网络接口状态 |
| 3 | 内核检查 | 13 | 自定义覆写设置 | 23 | 测试本机 DNS 查询（www.baidu.com） |
| 4 | GEO 数据文件 | 14 | 自定义防火墙设置 | 24 | 测试内核 DNS 查询（www.instagram.com） |
| 5 | 模型、缓存文件状态 | 15 | NFTABLES 防火墙设置 | 25 | DNS 解析文件 |
| 6 | 冲突插件检测 | 16 | IPTABLES 防火墙设置 | 26 | 测试本机网络连接（www.baidu.com） |
| 7 | 插件设置 | 17 | NFT Sets 状态 | 27 | 测试本机网络下载（raw.githubusercontent.com） |
| 8 | Cron 定时任务 | 18 | IPSET 状态 | 28 | Mihomo API 健康检查 |
| 9 | 覆写模块设置 | 19 | 路由表状态 | 29 | 最近运行日志（切 Debug 模式） |
| 10 | 自定义规则 一（优先匹配） | 20 | Tun 设备状态 | 30 | 活动连接信息 |

> 隐私脱敏（IPv4 末字节 / IPv6 后半 / Downloading URL）在脚本末尾用 `sed -i` 统一处理，**不是独立章节**。检索时用 `## 依赖检查` 之类的章节标题定位。

### 13.6 附加组件

页面同时加载 `openclash/toolbar_show`（配置切换工具栏：下拉选当前配置 + Switch 按钮）与 `openclash/config_editor`（内嵌 CodeMirror 编辑器，预加载 CM 资源并暴露全局 `merge_editor()`，仅作文件编辑复用，不用于日志渲染）。

> 修改插件自身日志级别用「覆写设置 → 常规设置 → `log_level`」；内核日志等级在 Core Logs 标签页直接切换。
