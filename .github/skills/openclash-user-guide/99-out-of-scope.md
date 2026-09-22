## 超出本文档范围的查询

> **用途**: 本文档未覆盖问题的外部资源查询流程（禁止猜测，须主动查证后再回复）。

> **强制规则：当用户询问本文档未覆盖的 Mihomo/OpenClash 配置或实现细节时，禁止自行猜测或编造回答。
> AI 必须主动查询外部资源获取准确信息后回复用户。**

本文档仅覆盖 OpenClash LuCI 插件 UI 中可直接配置的选项及其实现。当遇到本文档未覆盖的问题时，AI 必须**主动**使用以下资源查询答案，而非让用户自己去查阅文档：

**AI 必须主动查询的外部资源**：

| 优先级 | 资源 | 查询方式 | 适用场景 |
|--------|------|----------|----------|
| 1 | **Mihomo Wiki** `https://wiki.metacubex.one/config/` | 使用 `fetch_webpage` 抓取相关页面 | Mihomo YAML 配置字段的含义、可选值、用法 |
| 2 | **Meta-Docs 仓库** `github.com/MetaCubeX/Meta-Docs` | 使用 `github_text_search` 搜索 `docs/config/` 目录 | 需要精确的字段类型、默认值、完整配置示例 |
| 3 | **OpenClash Issues** `https://github.com/vernesong/OpenClash/issues` | 使用 `fetch_webpage` 打开 Issue 搜索页面或具体 Issue 页面 | 插件侧功能异常/报错（配置/订阅/防火墙/UI等），搜索已知问题和社区方案（优先作者 vernesong 回复和高赞回答） |
| 4 | **Mihomo Issues** `https://github.com/MetaCubeX/mihomo/issues` | 使用 `fetch_webpage` 打开 Issue 搜索页面或具体 Issue 页面 | 内核侧功能异常/报错（代理协议/TUN/DNS解析/规则引擎等），搜索已知问题和社区方案 |
| 5 | **OpenClash 源码** `github.com/vernesong/OpenClash/tree/dev` | 使用 `github_text_search` 搜索对应脚本/函数 | 需要了解插件侧的实现逻辑、UCI 到 YAML 的转换细节 |
| 6 | **Mihomo 核心源码** `github.com/MetaCubeX/mihomo/tree/Alpha` | 使用 `github_text_search` 搜索核心代码 | 代理协议实现、规则引擎、DNS 解析、TUN 栈等核心底层逻辑 |
| 7 | **Smart 核心源码** `github.com/vernesong/mihomo/tree/Alpha` | 使用 `github_text_search` 搜索核心代码 | Smart 策略、LightGBM 模型的底层实现 |

**具体触发条件**（满足任一即主动查询）：
- 用户询问的配置字段在本文档任何章节中均未出现
- 用户询问特定代理协议的详细参数（Hysteria2/TUIC/WireGuard/SSH/MASQUE 等的完整 TLS/传输层选项）
- 用户询问 `experimental`、`tunnel`、`sub-rule` 等插件 UI 中无直接对应选项的 Mihomo 顶级配置段
- 用户需要编写超出覆写模块 `16-overwrite-module-format.md` §16.2 节示例范围的自定义脚本或 YAML 配置
- 用户询问 Mihomo 最新版本引入的新特性（本文档基于 Mihomo v1.19.x）
- 用户询问 OpenClash 插件本身的开发、编译、打包相关问题
- 用户询问本文档各选项中「实现细节」的更深层逻辑

**AI 工作流程**：
1. 确认问题超出本文档覆盖范围
2. 根据问题类型选择对应的外部资源
3. **优先搜索 Issues**：如果用户遇到的是功能异常/报错类问题（而非配置字段查询），应先搜索 Issues 查找类似问题。根据问题类型选择：插件侧（配置/订阅/防火墙/UI）→ [OpenClash Issues](https://github.com/vernesong/OpenClash/issues)；内核侧（代理协议/TUN/DNS/规则引擎）→ [Mihomo Issues](https://github.com/MetaCubeX/mihomo/issues)。读取 Issue 时重点关注：① 维护者的诊断命令和结论；② 👍 反应数高的社区回复；③ Issue 最终是否被关闭及关闭原因（`completed`=已修复，`not planned`=不在计划内）
4. **主动查询**：使用 `fetch_webpage` 抓取 Mihomo Wiki 页面，或使用 `github_text_search` 搜索 Meta-Docs/OpenClash/Mihomo 核心/Smart 核心源码
5. 将查询到的信息**翻译、整理**后告知用户，而非直接丢链接
6. 在回复末尾注明信息来源（如「以上信息来自 OpenClash Issues #xxx / Mihomo Wiki」），让用户知道信息的权威来源
