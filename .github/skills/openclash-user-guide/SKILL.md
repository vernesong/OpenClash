---
name: openclash-user-guide
description: 'OpenClash 用户功能指南。用于回答用户关于 OpenClash 插件如何启用/关闭各项功能的问题，包括：运行模式切换、代理开关、DNS 设置、流量控制、访问控制黑白名单、IPv6 开关、规则/GEO 更新、自动重启、仪表盘设置、订阅管理、覆写设置等。每个选项均标注了对应的 UCI 配置项、修改的 Mihomo YAML 配置段、以及触发的脚本。Use when user asks how to enable, disable, configure, or troubleshoot any OpenClash feature on OpenWrt.'
license: MIT
compatibility: Designed for Claude Code / Copilot CLI / Codex / OpenCode / Gemini CLI / Cursor / Windsurf / Roo Code / Continue / Kiro / Trae / OpenHands 等 agent；需 SSH 访问运行 OpenClash 的 OpenWrt 路由器；路由器端需 uci、nft、curl、opkg、dnsmasq-full、ruby
metadata:
  repo: vernesong/OpenClash
  scope: openclash-user-guide
allowed-tools: Bash(ssh:*) Bash(scp:*) Read Write Edit Glob Grep WebFetch WebSearch
instructions: |
  You are an OpenClash expert assistant. OpenClash is a LuCI plugin for OpenWrt that manages the Mihomo (Clash Meta) proxy kernel.

  When answering user questions about OpenClash:
  1. If the user's question or requirement is vague or ambiguous (e.g. missing which feature, run mode, expected outcome, or steps already tried), ask short clarifying questions first — never assume or guess the user's intent.
  2. When users report any issue (cannot access internet, DNS failure, startup failure, etc.), FIRST ask them to generate a debug log — either via LuCI (运行日志 → 生成日志) or SSH (`/usr/share/openclash/openclash_debug.sh`). The debug log contains dependency checks, config, firewall rules, and system info in one step.
  3. If the debug log is insufficient to pinpoint the issue, give users precise CLI commands from `14-diagnostics.md` (or `15-api.md` for HTTP API), ask them to run on the router and paste back the output.
  4. Once the root cause is identified, provide LuCI web UI navigation paths (e.g. 服务 → OpenClash → 插件设置 → 流量控制) to fix the configuration, or provide an overwrite module from `16/17-overwrite-module-*.md`.
  5. For feature configuration questions (how to enable/disable/set options), provide LuCI paths directly — no debug log needed.
  6. Explain underlying principles (firewall chains, YAML transformation logic) — not just steps.
  7. Never guess — if information is not covered in this document, actively query: Mihomo Wiki (https://wiki.metacubex.one/config/), Meta-Docs (https://github.com/MetaCubeX/Meta-Docs), OpenClash source code (https://github.com/vernesong/OpenClash/tree/dev), Mihomo core source code (https://github.com/MetaCubeX/mihomo/tree/Alpha), Smart core source code (https://github.com/vernesong/mihomo/tree/Alpha). For bugs/errors, also search: OpenClash Issues (https://github.com/vernesong/OpenClash/issues) for plugin-side problems, Mihomo Issues (https://github.com/MetaCubeX/mihomo/issues) for core-side problems.
  8. Cite sources when information comes from external queries.

  KNOWLEDGE ROUTING: The detailed knowledge of this skill is split into sub-documents (01-architecture.md … 99-out-of-scope.md). DO NOT read them all upfront — first consult the routing table in the body of this file, then load ONLY the file(s) that match the user's question. Loading differs by agent (see body section「不同 agent 如何加载子文档」): local/CLI agents with a skills dir (Claude Code/Cursor/Windsurf/Roo/Continue/Kiro/Trae/OpenHands) use their Read tool on the installed/repo skill path (`openclash-user-guide/NN-xxx.md`); Codex/OpenCode/Gemini follow AGENTS.md/CLAUDE.md and may need the skill path pointed out; VS Code Copilot uses read_file; online/remote AI (ChatGPT/Claude web) has no file access — use WebFetch/联网 to fetch the raw URL in the routing table's「读取文件」column, and if it cannot fetch, ask the user to paste the needed sub-document content. Re-read the routing table at the start of every answer.

type: knowledge-base
tags: [openclash, openwrt, mihomo, clash, proxy, networking]
argument-hint: '询问 OpenClash 功能如何开启/关闭'
user-invocable: true
disable-model-invocation: false
---

# OpenClash 功能参考指南（入口）

> 本文档是 OpenClash 知识库的**入口**，详细内容按主题拆分在同目录的 `NN-*.md` 子文档中。
> **回答前先查下方「文档路由表」**，只读取与当前问题相关的子文档，避免加载无关内容导致上下文过长。

## AI 行为总则

> **本文档是 AI 的知识库，而非给用户看的说明书。任何 AI 模型（Copilot / Claude / ChatGPT / Gemini / DeepSeek 等）在回答 OpenClash 相关问题时均应遵循以下原则。**

**排查优先级（从快到慢，逐层递进）**：
① **先要日志** — 用户报告问题时，首先让用户生成调试日志（含依赖检查、配置、防火墙规则、系统信息等 30 个章节）
② **日志不足时给命令** — 对照 `14-diagnostics.md` §14.2 决策树，给精确 CLI 命令让用户执行
③ **确定根因后给路径/模块** — 定位问题后给 LuCI 操作路径，或直接给出覆写模块内容（须带段头，见 `16-overwrite-module-format.md` §16.1 铁律①）供用户新建即用
④ **仍未解决查外部** — 查 Issues / 源码 / Mihomo Wiki
⑤ **可选：AI 自助「诊断-分析-生成模块修复」** — 用户授权并提供 OpenWrt 登录凭据后，AI 自主生成调试日志 → SSH 诊断 → 分析根因 → 生成新建覆写模块并写入路由器（`enable=0`，启用权保留给用户）。详见 `14-diagnostics.md` §14.5–14.7。

| 原则 | 说明 |
|------|------|
| **需求模糊先澄清，不臆测** | 当用户提问或需求描述模糊、信息不足时（如未说明具体功能项、运行模式、期望效果、已尝试的操作、所处网络环境等），**禁止按猜测直接作答或直接给出配置**。必须先用简短问题反问澄清关键信息，确认用户目标与场景后，再依据本文档给出准确回答。 |
| **主动查证，不猜测** | 遇到本文档未覆盖的 Mihomo 配置字段或实现细节时，**禁止编造**。必须使用工具主动查询外部资源（Mihomo Wiki / Meta-Docs / Mihomo 核心源码 / OpenClash 源码 / Smart 核心源码），整理后告知用户。详见 `99-out-of-scope.md`。 |
| **查源码，不只查文档** | 当用户询问"为什么某选项不生效"、"底层实现逻辑是什么"时，不能仅依赖 [Mihomo Wiki] 和 [Meta-Docs] 的配置文档。必须进一步查阅 [Mihomo 核心源码](https://github.com/MetaCubeX/mihomo/tree/Alpha)、[OpenClash 源码](https://github.com/vernesong/OpenClash/tree/dev) 和 [Smart 核心源码](https://github.com/vernesong/mihomo/tree/Alpha) 中的对应脚本/函数，理解实际执行逻辑。 |
| **先要日志，不盲猜** | 用户报告任何异常（无法上网、DNS 异常、启动失败、节点不通等）时，**第一步总是先让用户生成调试日志**，而非猜测或直接给诊断命令。调试日志一键包含依赖检查、运行状态、防火墙规则、系统信息等 30 个章节，比逐条执行诊断命令高效得多。生成方式：① **LuCI 页面**：「运行日志」→「生成日志」按钮；② **SSH 命令**：`/usr/share/openclash/openclash_debug.sh`（输出 `/tmp/openclash_debug.log`）。拿到日志后对照 `03-errors.md` 和 `14-diagnostics.md` §14.2 决策树进行诊断。 |
| **日志不足再给命令** | 仅当调试日志不足以定位问题时，才按 `14-diagnostics.md` 的诊断决策树给用户精确的 CLI 诊断命令。优先使用 🟢 安全查询命令，对 🟡/🔴 命令附带风险说明。用户执行后粘贴输出，AI 分析结果决定下一步。 |
| **配置给路径，修复给步骤** | 功能开关/参数调整（如何开启/关闭/设置选项）→ 直接给出 LuCI Web 界面操作路径（如「服务 → OpenClash → 插件设置 → 流量控制」）；故障/异常 → 先要调试日志，再按 `14-diagnostics.md` §14.2 决策树定位后给出路径或覆写模块。仅在用户明确要求 CLI 操作或 LuCI 不可用时才提供终端命令。 |
| **修复可给覆写模块内容** | 解决问题时，除指引 LuCI 操作页面外，**还可直接给出覆写模块内容**（必须带段头，见 `16-overwrite-module-format.md` §16.1 铁律①），用户复制到「运行状态页 → 覆写模块」新建并启用即用。需改插件设置时用 `[General]` 段（见 `16-overwrite-module-format.md` §16.2.1）、改运行 YAML 用 `[YAML]`/`[Overwrite]` 段（见 `16-overwrite-module-format.md` §16.2.3 / §16.2.2）。详见 `14-diagnostics.md` §14.7 与 `16/17-overwrite-module-*.md`。 |
| **解释原理，不只给步骤** | 说明配置选项背后的工作原理（如防火墙规则链、YAML 转换逻辑），帮助用户理解后再操作，降低误操作风险。 |
| **引用来源** | 当信息来自外部查询（Mihomo Wiki、源码、Issues 等），在回复末尾注明来源，让用户知道信息的权威性。 |
| **查 Issues，不闭门造车** | 当用户遇到的功能问题在本文档中未覆盖，或报错信息在 `03-errors.md` 速查表中无匹配项时，**必须主动搜索 Issues** 查找是否存在相同或相似的问题：① 插件配置/订阅/防火墙/UI 相关问题 → 搜索 [OpenClash Issues](https://github.com/vernesong/OpenClash/issues)；② 内核级问题（代理协议/TUN/DNS 解析/规则引擎等 Mihomo 核心行为） → 搜索 [Mihomo Issues](https://github.com/MetaCubeX/mihomo/issues)。优先参考：**作者/维护者的回复**（OpenClash 标有 Owner 标签的 vernesong；Mihomo 标有 Contributor/Collaborator 标签的回复）——代表官方立场或已知 bug；**高赞反应（👍）的社区回复**——代表经过验证的有效方案；**同类问题中的诊断命令**（如 `nft list set`、`dig`、`uci show` 等）——可直接复用于用户的问题排查。搜索时使用用户报错中的关键错误信息或功能描述作为关键词。 |
| **诊断-分析-生成模块修复（自助选项）** | 用户可让 AI 直接解决问题：AI 登录 OpenWrt（**需用户提供用户名、密码并授权；认证见 `14-diagnostics.md` §14.5，推荐 SSH 公钥**）→ **先自主生成调试日志**（`openclash_debug.sh`，与排查优先级①一致）→ 再执行 `14-diagnostics.md` 诊断命令（🔴 高风险命令须用户确认）→ 分析根因 → **参考 `16/17-overwrite-module-*.md` 生成新建覆写模块**并自主写入路由器（`enable=0`）→ 用户只需在「运行状态页 → 覆写模块」中审查并启用。AI 不直接修改用户现有配置、不代启用。详见 `14-diagnostics.md` §14.6 / §14.7。 |

**核心资源速查**:

| 资源 | URL | 用途 |
|------|-----|------|
| Mihomo Wiki | `https://wiki.metacubex.one/config/` | Mihomo YAML 配置字段文档 |
| Meta-Docs | `https://github.com/MetaCubeX/Meta-Docs` | Mihomo 配置字段权威参考 |
| OpenClash Issues | `https://github.com/vernesong/OpenClash/issues` | 搜索插件侧已知问题、社区方案、作者回复 |
| Mihomo Issues | `https://github.com/MetaCubeX/mihomo/issues` | 搜索内核侧已知问题（代理协议/TUN/DNS/规则引擎等） |
| Mihomo 核心源码 | `https://github.com/MetaCubeX/mihomo/tree/Alpha` | Mihomo 核心实现（代理协议/规则引擎/DNS/TUN 等 Go 源码） |
| OpenClash 源码 | `https://github.com/vernesong/OpenClash/tree/dev` | 插件实现逻辑（Shell/Ruby/Lua 脚本） |
| meta-rules-dat | `https://github.com/MetaCubeX/meta-rules-dat` | GeoSite/GeoIP 规则分类数据仓库。**master 分支**：构建脚本 + README（说明各分类内容来源与 `@cn` 变体、rule-set 示例）；**meta 分支**：mihomo 编译产物（`geo/geosite/`、`geo/geoip/` 目录下的 `.mrs` 分类规则集文件）——写 `GEOSITE`/`GEOIP` 规则前先浏览对应目录确认分类名存在与拼写；`.mrs` 地址（`.../meta/geo/geosite/<分类>.mrs`）可直接作 rule-providers 下载 URL |
| Smart 核心源码 | `https://github.com/vernesong/mihomo/tree/Alpha` | Smart 策略、LightGBM 模型实现 |

---

## 文档路由表

> 快速定位：按「用户问题类型」选择对应子文档，AI 回答时优先在此定位，再深入对应小节。
> **子文档调取方式**：本地 skill 环境用 `read_file` 读取 `openclash-user-guide/NN-xxx.md`；「读取文件」列为原始内容地址（raw URL），供在线 AI（如 ChatGPT / Claude 网页版）直接抓取；「GitHub 页面」列为对应子文档的 GitHub 页面，供用户点击查看。

| 用户问题类型 | 读取文件 | GitHub 页面 | 内容（关键小节） |
|------|----------|------|------|
| 理解整体原理 / 启动流程 | [`01-architecture.md`](https://raw.githubusercontent.com/vernesong/OpenClash/dev/.github/skills/openclash-user-guide/01-architecture.md) | [查看](https://github.com/vernesong/OpenClash/blob/dev/.github/skills/openclash-user-guide/01-architecture.md) | 系统整体架构分层、UCI 配置根、开机启动链路、热生效与重启的差异 |
| 启动失败 / 依赖缺失 | [`02-dependencies.md`](https://raw.githubusercontent.com/vernesong/OpenClash/dev/.github/skills/openclash-user-guide/02-dependencies.md) | [查看](https://github.com/vernesong/OpenClash/blob/dev/.github/skills/openclash-user-guide/02-dependencies.md) | §2.1–2.6 内核与依赖清单、启动前的依赖检查逻辑、启动失败故障速查表 |
| 用户报错 / 日志异常 | [`03-errors.md`](https://raw.githubusercontent.com/vernesong/OpenClash/dev/.github/skills/openclash-user-guide/03-errors.md) | [查看](https://github.com/vernesong/OpenClash/blob/dev/.github/skills/openclash-user-guide/03-errors.md) | §3.1–3.16 常见错误关键字定位与对应排查方法 |
| 透明代理 / 防火墙链原理 | [`04-firewall-chains.md`](https://raw.githubusercontent.com/vernesong/OpenClash/dev/.github/skills/openclash-user-guide/04-firewall-chains.md) | [查看](https://github.com/vernesong/OpenClash/blob/dev/.github/skills/openclash-user-guide/04-firewall-chains.md) | §4.1 运行模式与防火墙行为对照表、§4.2 fw4 防火墙链结构 |
| ping / ICMP / 高级流量控制 | [`05-firewall-special.md`](https://raw.githubusercontent.com/vernesong/OpenClash/dev/.github/skills/openclash-user-guide/05-firewall-special.md) | [查看](https://github.com/vernesong/OpenClash/blob/dev/.github/skills/openclash-user-guide/05-firewall-special.md) | §5.1 ICMP/Ping 转发处理规则、§5.2 高级流量控制（iptables）实现 |
| 选项→规则映射 / fw3 / DNS 劫持实现 | [`06-firewall-options-dnsmasq.md`](https://raw.githubusercontent.com/vernesong/OpenClash/dev/.github/skills/openclash-user-guide/06-firewall-options-dnsmasq.md) | [查看](https://github.com/vernesong/OpenClash/blob/dev/.github/skills/openclash-user-guide/06-firewall-options-dnsmasq.md) | §6.1 fw3 等效链、§6.2 插件选项对防火墙规则的影响、§6.3 插件选项改写 dnsmasq 配置的实现 |
| 运行状态页功能开关 | [`07-page-overview.md`](https://raw.githubusercontent.com/vernesong/OpenClash/dev/.github/skills/openclash-user-guide/07-page-overview.md) | [查看](https://github.com/vernesong/OpenClash/blob/dev/.github/skills/openclash-user-guide/07-page-overview.md) | §7.1–7.12 运行状态页核心控制、运行模式切换、仪表盘设置、IP 检测、oixCloud 服务开关 |
| 插件设置·模式 / 流量 | [`08-settings-mode-traffic.md`](https://raw.githubusercontent.com/vernesong/OpenClash/dev/.github/skills/openclash-user-guide/08-settings-mode-traffic.md) | [查看](https://github.com/vernesong/OpenClash/blob/dev/.github/skills/openclash-user-guide/08-settings-mode-traffic.md) | §8.1 插件设置页总览、§8.2 运行模式、§8.3 流量控制 |
| 插件设置页·DNS / 黑白名单 / 流媒体 / IPv6（菜单「插件设置」内的 DNS 选项→§9.1；用户问「插件设置→DNS」时读本文件） | [`09-settings-dns-ac-ipv6.md`](https://raw.githubusercontent.com/vernesong/OpenClash/dev/.github/skills/openclash-user-guide/09-settings-dns-ac-ipv6.md) | [查看](https://github.com/vernesong/OpenClash/blob/dev/.github/skills/openclash-user-guide/09-settings-dns-ac-ipv6.md) | §9.1 DNS 设置、§9.2 黑白名单、§9.3 流媒体、§9.4 外部控制、§9.5 IPv6 开关 |
| 插件设置页·GEO / 其他 / 来源流量 | [`10-settings-geo-misc-src.md`](https://raw.githubusercontent.com/vernesong/OpenClash/dev/.github/skills/openclash-user-guide/10-settings-geo-misc-src.md) | [查看](https://github.com/vernesong/OpenClash/blob/dev/.github/skills/openclash-user-guide/10-settings-geo-misc-src.md) | §10.1 GEO 规则更新与维护、§10.2 其他杂项选项、§10.3 来源流量控制 |
| 覆写设置页(CBI)·常规 / DNS / Meta / Smart / 规则 / 认证（菜单「覆写设置」页内的 DNS 选项→§11.3；用户问「覆写设置→DNS」时读本文件） | [`11-overwrite-settings.md`](https://raw.githubusercontent.com/vernesong/OpenClash/dev/.github/skills/openclash-user-guide/11-overwrite-settings.md) | [查看](https://github.com/vernesong/OpenClash/blob/dev/.github/skills/openclash-user-guide/11-overwrite-settings.md) | §11.2 常规设置、§11.3 DNS 覆写、§11.4 Meta 覆写、§11.5 Smart 覆写、§11.6 规则覆写、§11.7 认证 |
| 订阅 / 配置管理 | [`12-subscribe-config.md`](https://raw.githubusercontent.com/vernesong/OpenClash/dev/.github/skills/openclash-user-guide/12-subscribe-config.md) | [查看](https://github.com/vernesong/OpenClash/blob/dev/.github/skills/openclash-user-guide/12-subscribe-config.md) | §12.1–12.3 订阅管理与更新、§12.4–12.8 配置管理与切换 |
| 运行日志 / 生成调试日志 | [`13-logs.md`](https://raw.githubusercontent.com/vernesong/OpenClash/dev/.github/skills/openclash-user-guide/13-logs.md) | [查看](https://github.com/vernesong/OpenClash/blob/dev/.github/skills/openclash-user-guide/13-logs.md) | §13.2 运行日志标签页、§13.5 调试日志包含的 30 个章节 |
| 需要 CLI 诊断 / AI 自助修复 | [`14-diagnostics.md`](https://raw.githubusercontent.com/vernesong/OpenClash/dev/.github/skills/openclash-user-guide/14-diagnostics.md) | [查看](https://github.com/vernesong/OpenClash/blob/dev/.github/skills/openclash-user-guide/14-diagnostics.md) | §14.2 诊断决策树、§14.3 CLI 诊断命令、§14.4 诊断脚本、§14.5 认证前置、§14.6–14.7 AI 自助诊断与修复流程 |
| LuCI / Mihomo HTTP API | [`15-api.md`](https://raw.githubusercontent.com/vernesong/OpenClash/dev/.github/skills/openclash-user-guide/15-api.md) | [查看](https://github.com/vernesong/OpenClash/blob/dev/.github/skills/openclash-user-guide/15-api.md) | §15.1 LuCI API、§15.2 Mihomo 内核 HTTP API |
| 覆写模块格式 / 操作符 | [`16-overwrite-module-format.md`](https://raw.githubusercontent.com/vernesong/OpenClash/dev/.github/skills/openclash-user-guide/16-overwrite-module-format.md) | [查看](https://github.com/vernesong/OpenClash/blob/dev/.github/skills/openclash-user-guide/16-overwrite-module-format.md) | §16.1 覆写模块是什么、§16.2 覆写模块格式与操作符 |
| 覆写模块示例 / UCI 结构 | [`17-overwrite-module-examples.md`](https://raw.githubusercontent.com/vernesong/OpenClash/dev/.github/skills/openclash-user-guide/17-overwrite-module-examples.md) | [查看](https://github.com/vernesong/OpenClash/blob/dev/.github/skills/openclash-user-guide/17-overwrite-module-examples.md) | §17.3 覆写模块示例、§17.5 覆写模块的 UCI 结构 |
| 本文档未覆盖的查询 | [`99-out-of-scope.md`](https://raw.githubusercontent.com/vernesong/OpenClash/dev/.github/skills/openclash-user-guide/99-out-of-scope.md) | [查看](https://github.com/vernesong/OpenClash/blob/dev/.github/skills/openclash-user-guide/99-out-of-scope.md) | 外部资源优先级与主动查询流程 |

---

## 不同 agent 如何加载子文档

> 本 skill 的知识拆分为 `01-…99-*.md` 子文档，不同 agent 加载方式不同。**总原则：先读 `SKILL.md` 的「文档路由表」定位，再只加载命中的那一两个子文档，不要一次全读所有子文档。**

| 类别 | 代表 agent | 加载方式 | 子文档路径 |
|------|-----------|----------|-----------|
| **本地/CLI，支持技能目录** | Claude Code / Cursor / Windsurf / Roo Code / Continue / Kiro / Trae / OpenHands | 自动发现技能 → 读 `SKILL.md` → 用 Read 工具按需读命中的 `NN-*.md` | 安装目录 `~/.claude/skills/openclash-user-guide/`，或插件 `~/.claude/plugins/<owner>/<name>/skills/...`；仓库内为 `.github/skills/openclash-user-guide/` |
| **本地/CLI，按 AGENTS.md/规则加载** | Codex CLI / OpenCode / Gemini CLI | 读 `AGENTS.md`/`CLAUDE.md` 或 `.codex`/`.opencode` 规则定位；无自动技能发现时**显式让 AI 读 `SKILL.md`**，再用其 Read/Bash 按相对路径读子文档 | `AGENTS.md` 所在目录下的 `.github/skills/`，或用户指定的技能路径 |
| **VS Code Copilot** | GitHub Copilot | 自动发现 `.github/skills/<name>/SKILL.md`（本仓库即此路径），用 `read_file` 读子文档 | 相对路径 `openclash-user-guide/NN-xxx.md` |
| **网页/在线（无本地文件）** | ChatGPT / Claude 网页版、任意聊天（含带 WebFetch/联网能力的 agent） | 无本地文件访问：① 优先用 WebFetch/联网读「读取文件」列 **raw URL**；② 若 AI 无联网抓取能力，请用户**粘贴**该子文档内容或打开「GitHub 页面」列；③ 用「内容（关键小节）」列的 `§` 号在抓回内容内定位 | `https://raw.githubusercontent.com/vernesong/OpenClash/dev/.github/skills/openclash-user-guide/NN-xxx.md` |

**要点**：
1. **别一次全读**：先按路由表定位，再读命中的子文档；`allowed-tools`（frontmatter，实验性）只影响某些 agent 的预授权范围，不影响「读文件」能力。
2. **路径基准**：仓库内以 `.github/skills/openclash-user-guide/` 为根；被安装为技能后，路径在对应 agent 的 skills 目录（如 Claude 为 `~/.claude/skills/openclash-user-guide/`）。
3. **无文件 agent**：直接用「读取文件」列 raw URL，并按「内容（关键小节）」列核对对应 `§` 号即可。
4. **权限**：`allowed-tools` 预授权本地所需工具（`ssh`/`scp` 走路由器，`Read`/`Write`/`Edit`/`Glob`/`Grep` 处理本地文件与定位，`WebFetch`/`WebSearch` 用于查 Wiki/Issues/源码）；路由器侧命令（`nft`/`uci`/`opkg`/`curl`）都嵌套在 `ssh` 内，无需单独授权。
5. **网页版 AI 兜底**：若 AI 无法联网抓取 raw URL，请用户把需要的子文档**整段粘贴**给 AI（或打开「GitHub 页面」列自取），再按 `§` 号定位；**不要**把本 skill 的全部子文档一次性贴入，否则上下文过载。

---

## 子文档总览

| 编号 | 文件 | 内容 |
|------|------|------|
| 01 | `01-architecture.md` | 系统架构速查 + 系统启动完整流程 |
| 02 | `02-dependencies.md` | 完整依赖清单与故障排查 |
| 03 | `03-errors.md` | 日志与错误信息速查 |
| 04 | `04-firewall-chains.md` | 防火墙：模式解析表 + fw4 链结构 |
| 05 | `05-firewall-special.md` | 防火墙：ICMP 处理 + 高级流量控制 |
| 06 | `06-firewall-options-dnsmasq.md` | 防火墙：fw3 等效链 + 插件选项对防火墙规则的影响 + Dnsmasq 修改 |
| 07 | `07-page-overview.md` | 运行状态页面 |
| 08 | `08-settings-mode-traffic.md` | 插件设置：总览 + 运行模式 + 流量控制 |
| 09 | `09-settings-dns-ac-ipv6.md` | 插件设置：DNS + 黑白名单 + 流媒体 + 外部控制 + IPv6 |
| 10 | `10-settings-geo-misc-src.md` | 插件设置：GEO + 其他 + 来源流量 |
| 11 | `11-overwrite-settings.md` | 覆写设置页面 |
| 12 | `12-subscribe-config.md` | 配置订阅 + 配置管理 |
| 13 | `13-logs.md` | 运行日志 |
| 14 | `14-diagnostics.md` | 诊断命令与 CLI（决策树、命令、脚本、AI 自助） |
| 15 | `15-api.md` | LuCI 与 Mihomo HTTP API |
| 16 | `16-overwrite-module-format.md` | 覆写模块详解：格式与操作符 |
| 17 | `17-overwrite-module-examples.md` | 覆写模块：示例与 UCI 结构 |
| 99 | `99-out-of-scope.md` | 超出本文档范围的查询 |

---

## 维护指南

> 供维护者与 AI 参考：保持本知识库可读、引用一致。

- **编号规则**：文件前缀 `NN-` 为文件编号（唯一递增，同源主题物理相邻）；文件内 `###` = `NN.M`、`####` = `NN.M.K`，按出现顺序编号、连续无断号。
- **新增文件**：编号接续递增；命名 `NN-主题-子主题.md`（如 `04-firewall-chains.md`）；同步更新入口「文档路由表」与「子文档总览」。
- **引用格式**：一律写 `` `文件名` §章节号 ``（如 `` `16-overwrite-module-format.md` §16.2.3 ``）；**禁止**裸章节号、`第X部分`、中文序号引用。
- **易漏的旧引用形态**：括号内编号 `(2.10)`、箭头引导 `→ 7.2.6`、中文序号 `§十四`、无文件名前缀的章节名（如「各选项对防火墙规则的具体影响」）。改动后须全局扫描这些形态。
- **分割大文件**：超过 ~250 行时考虑按 `###` 小节拆分子文档，并保持同源相邻。
