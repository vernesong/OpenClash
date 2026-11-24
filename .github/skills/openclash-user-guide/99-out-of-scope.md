## 超出本文档范围的查询

> **强制规则**: 用户问及本文档未覆盖的 Mihomo/OpenClash 配置或实现细节时，**禁止猜测或编造**，必须主动查询外部资源后回复。
> 本文档只覆盖 OpenClash LuCI 界面中可直接配置的选项及其实现。

**外部资源**（按优先级）：

| 优先级 | 资源 | 查询方式 | 适用场景 |
|--------|------|----------|----------|
| 1 | [Mihomo Wiki](https://wiki.metacubex.one/config/) | `fetch_webpage` | YAML 字段含义、可选值、用法 |
| 2 | [Meta-Docs](https://github.com/MetaCubeX/Meta-Docs) | `github_text_search` 搜 `docs/config/` | 精确字段类型、默认值、完整示例 |
| 3 | [OpenClash Issues](https://github.com/vernesong/OpenClash/issues) | `fetch_webpage` | 插件侧异常（配置/订阅/防火墙/UI） |
| 4 | [Mihomo Issues](https://github.com/MetaCubeX/mihomo/issues) | `fetch_webpage` | 内核侧异常（协议/TUN/DNS/规则引擎） |
| 5 | [OpenClash 源码](https://github.com/vernesong/OpenClash/tree/dev) | `github_text_search` | 插件实现逻辑、UCI→YAML 转换 |
| 6 | [Mihomo 核心源码](https://github.com/MetaCubeX/mihomo/tree/Alpha) | `github_text_search` | 协议实现、规则引擎、DNS、TUN 栈 |
| 7 | [Smart 核心源码](https://github.com/vernesong/mihomo/tree/Alpha) | `github_text_search` | Smart 策略、LightGBM 模型 |

**触发条件**（满足任一即主动查询）：

- 字段在本文档任何章节都未出现
- 特定代理协议的详细参数（Hysteria2/TUIC/WireGuard/SSH/MASQUE 等的完整 TLS/传输层选项）
- `experimental`、`tunnel`、`sub-rule` 等界面无对应选项的顶级配置段
- 需要写超出 `16-overwrite-module-format.md` §16.2 示例范围的自定义脚本或 YAML
- Mihomo 新版本特性（本文档基于 Mihomo v1.19.x）
- OpenClash 插件自身的开发、编译、打包问题
- 本文档各选项「实现细节」的更深层逻辑

**流程**：

1. 确认问题超出覆盖范围
2. 按类型选资源；**异常/报错优先搜 Issues**（插件侧 → OpenClash Issues，内核侧 → Mihomo Issues）。读 Issue 时重点看：① 维护者的诊断命令与结论；② 👍 高的社区回复；③ 关闭原因（`completed` = 已修复，`not planned` = 不在计划）
3. 抓取 Wiki 页面或搜索源码
4. 把查到的信息**翻译整理**后告诉用户，不要只丢链接
5. 结尾注明来源（如「以上信息来自 OpenClash Issues #xxx / Mihomo Wiki」）
