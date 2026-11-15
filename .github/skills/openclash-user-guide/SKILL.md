---
name: openclash-user-guide
description: 'OpenClash（OpenWrt 上的 Mihomo (Clash Meta) 客户端插件）用户功能指南：说明运行模式、代理开关、DNS、流量控制、访问控制、IPv6、规则/GEO 更新、自动重启、仪表盘、订阅与覆写模块、连接异常排查等功能的配置方式，并标注每项对应的 UCI 配置项、所改的 Mihomo YAML 配置段与触发脚本；适用于启用、配置或排查 OpenClash 各项功能的问题。'
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
  2. When users report any issue (cannot access internet, DNS failure, startup failure, etc.), FIRST ask them to generate a debug log — either via LuCI (运行日志 → 调试日志 → 生成日志) or SSH (`/usr/share/openclash/openclash_debug.sh`). The debug log contains dependency checks, config, firewall rules, and system info in one step.
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

> 本文件是知识库入口，详细内容按主题拆分在同目录 `NN-*.md`。**回答前先查「文档路由表」**，只读命中问题的 1–2 个子文档，避免上下文过长。

## AI 行为总则

**排查优先级**（从快到慢）:

1. **先要日志** —— 让用户生成调试日志（LuCI「运行日志 → 调试日志 → 生成日志」，或 SSH `/usr/share/openclash/openclash_debug.sh` → `/tmp/openclash_debug.log`；含依赖检查、配置、防火墙规则、br_netfilter/TPROXY 状态、系统信息等 31 章节）
2. **日志不足时给命令** —— 按 `14-diagnostics.md` §14.2 决策树给精确 CLI 命令（🟢 安全查询优先，🟡/🔴 附风险说明）
3. **定位根因后给路径/模块** —— 给 LuCI 操作路径，或按 `16-overwrite-module-format.md` §16.1 铁律给可直接新建的覆写模块
4. **仍未解决查外部** —— Issues / 源码 / Mihomo Wiki
5. **可选：AI 自助诊断修复** —— 用户授权并提供凭据后，AI 生成日志 → SSH 诊断 → 分析根因 → 写覆写模块（`enable=0`，启用权留给用户），见 `14-diagnostics.md` §14.5–14.7

| 原则 | 说明 |
|------|------|
| **需求模糊先澄清** | 未说明功能项、运行模式、期望效果、已试操作或网络环境时，先用简短问题澄清，**禁止按猜测作答或直接给配置** |
| **主动查证不猜测** | 文档未覆盖的字段或实现细节禁止编造，必须查 Mihomo Wiki / Meta-Docs / 三个源码仓库后回答，见 `99-out-of-scope.md` |
| **查源码，不只查文档** | 问「为什么某选项不生效」「底层逻辑」时须查 [Mihomo 核心源码](https://github.com/MetaCubeX/mihomo/tree/Alpha)、[OpenClash 源码](https://github.com/vernesong/OpenClash/tree/dev)、[Smart 核心源码](https://github.com/vernesong/mihomo/tree/Alpha) 中的实际执行逻辑 |
| **配置给路径** | 开关/参数调整直接给 LuCI 路径；仅用户要求 CLI 或 LuCI 不可用时才给命令 |
| **解释原理，不只给步骤** | 说明选项背后的机制（防火墙链、YAML 转换逻辑），降低误操作风险 |
| **查 Issues** | 文档未覆盖或 `03-errors.md` 无匹配时搜 Issues：插件侧 → OpenClash Issues，内核侧 → Mihomo Issues；优先看维护者（vernesong、Mihomo Contributor）与高赞答复 |
| **引用来源** | 信息来自本文档时注明章节（如 `14-diagnostics.md` §14.2），来自外部时注明链接 |

**核心资源**:

| 资源 | URL | 用途 |
|------|-----|------|
| Mihomo Wiki | `https://wiki.metacubex.one/config/` | YAML 字段文档 |
| Meta-Docs | `https://github.com/MetaCubeX/Meta-Docs` | 字段权威参考 |
| OpenClash Issues | `https://github.com/vernesong/OpenClash/issues` | 插件侧已知问题、作者回复 |
| Mihomo Issues | `https://github.com/MetaCubeX/mihomo/issues` | 内核侧已知问题 |
| Mihomo 核心源码 | `https://github.com/MetaCubeX/mihomo/tree/Alpha` | 协议/规则/DNS/TUN 实现 |
| OpenClash 源码 | `https://github.com/vernesong/OpenClash/tree/dev` | 插件 Shell/Ruby/Lua 逻辑 |
| meta-rules-dat | `https://github.com/MetaCubeX/meta-rules-dat` | GeoSite/GeoIP 分类。master = 构建脚本与 README；meta 分支 = `.mrs` 产物（`geo/geosite/`、`geo/geoip/`），写规则前先确认分类名，`.mrs` 可直接作 rule-providers 的 `url` |
| Smart 核心源码 | `https://github.com/vernesong/mihomo/tree/Alpha` | Smart 策略、LightGBM 模型 |

## 文档路由表

> **调取方式**: 本地 skill / Copilot 用 `read_file` 读 `openclash-user-guide/NN-xxx.md`（仓库内即 `.github/skills/openclash-user-guide/`）；在线 AI 用 WebFetch 抓 raw URL `https://raw.githubusercontent.com/vernesong/OpenClash/dev/.github/skills/openclash-user-guide/NN-xxx.md`（把 `raw.githubusercontent.com/…/dev/` 换成 `github.com/…/blob/dev/` 即 GitHub 页面链接）。抓不到时请用户粘贴该子文档内容。

| 问题类型 | 子文档 | 关键小节 |
|----------|--------|----------|
| 整体原理 / 启动流程 | `01-architecture.md` | 架构分层、UCI 配置根、启动链路、热生效 vs 重启 |
| 启动失败 / 依赖缺失 / 重装 | `02-dependencies.md` | §2.1–2.7 依赖清单、`check_mod()`、故障速查、`install.sh` |
| 用户报错 / 日志异常 | `03-errors.md` | §3.1–3.16 错误关键字 → 原因 → 排查 |
| 透明代理 / 防火墙链原理 | `04-firewall-chains.md` | §4.1 模式解析、§4.2 fw4 链结构、§4.3 策略路由辅助规则、§4.4 WAN 入口防护 |
| ICMP / Tailscale / `ts.net` / ZeroTier / mwan3 / Docker / 证书不对 | `05-firewall-special.md` | §5.1 ICMP、§5.2 高级流量控制、§5.3 Tailscale、§5.4 mwan3、§5.5 br_netfilter 与 TPROXY（证书错误/超时、Docker 网桥） |
| 选项→规则映射 / fw3 / DNS 劫持实现 / 解析不到地址 | `06-firewall-options-dnsmasq.md` | §6.1 fw3 等效链、§6.2 选项对规则的影响、§6.3 dnsmasq 改写、§6.4 重绑定保护 |
| 运行状态页功能 | `07-page-overview.md` | §7.1–7.12 核心控制、模式切换、仪表盘、IP 检测、oixCloud |
| 插件设置·模式 / 流量 | `08-settings-mode-traffic.md` | §8.1 总览（§8.1.1 强制写入项）、§8.2 运行模式（§8.2.12 四栈选型、§8.2.13 转发模式、§8.2.14 默认值与 MIPS 来源、§8.2.15 TUN 参数）、§8.3 流量控制、§8.4 性能实测 |
| 插件设置·DNS / 黑白名单 / 流媒体 / IPv6 | `09-settings-dns-ac-ipv6.md` | §9.1 DNS、§9.2 黑白名单（含 Fake-IP 分流依赖）、§9.3 流媒体、§9.4 外部控制、§9.5 IPv6（「插件设置→DNS」读本文件） |
| 插件设置·GEO / 其他 / 来源流量 | `10-settings-geo-misc-src.md` | §10.1 GEO、§10.2 其他杂项、§10.3 来源流量控制 |
| 覆写设置页(CBI)·常规/DNS/Meta/Smart/规则/认证 | `11-overwrite-settings.md` | §11.2 常规、§11.3 DNS、§11.4 Meta、§11.5 Smart、§11.6 规则、§11.7 认证（「覆写设置→DNS」读 §11.3） |
| 订阅 / 配置管理 | `12-subscribe-config.md` | §12.1–12.3 订阅更新、§12.4–12.8 配置管理 |
| 运行日志 / 调试日志 | `13-logs.md` | §13.1 总览、§13.2 三标签页、§13.5 31 章节清单 |
| CLI 诊断 / AI 自助修复 | `14-diagnostics.md` | §14.2 决策树（含 §14.2.7 TFO）、§14.3 命令、§14.4 脚本、§14.5 认证前置、§14.6 自助诊断、§14.7 覆写修复 |
| LuCI / Mihomo HTTP API | `15-api.md` | §15.1 LuCI API、§15.2 Mihomo API |
| 覆写模块格式 / 操作符 | `16-overwrite-module-format.md` | §16.1 是什么、§16.2 格式（§16.2.1 General、§16.2.2 Overwrite、§16.2.3 YAML 操作符、§16.2.5 `#!`） |
| 覆写模块示例 / UCI 结构 | `17-overwrite-module-examples.md` | §17.3 示例、§17.5 UCI 结构 |
| 未覆盖的查询 | `99-out-of-scope.md` | 外部资源优先级与查询流程 |

## 不同 agent 如何加载子文档

> 先按路由表定位，只加载命中的 1–2 个子文档。`allowed-tools`（frontmatter，实验性）只影响部分 agent 的工具预授权，不影响读文件能力。

| 类别 | 代表 agent | 加载方式 |
|------|-----------|----------|
| 本地/CLI（技能目录） | Claude Code / Cursor / Windsurf / Roo / Continue / Kiro / Trae / OpenHands | 自动发现技能 → 读 `SKILL.md` → 按需读 `NN-*.md`；路径 `~/.claude/skills/openclash-user-guide/`，插件为 `~/.claude/plugins/<owner>/<name>/skills/…`，仓库内为 `.github/skills/openclash-user-guide/` |
| 本地/CLI（规则文件） | Codex CLI / OpenCode / Gemini CLI | 读 `AGENTS.md`/`CLAUDE.md` 或 `.codex`/`.opencode` 规则定位；无自动发现时**显式让 AI 读 `SKILL.md`** |
| VS Code Copilot | GitHub Copilot | 自动发现 `.github/skills/<name>/SKILL.md`，用 `read_file` 读子文档 |
| 网页/在线 | ChatGPT / Claude 网页版等 | WebFetch 抓 raw URL；抓不到则请用户**粘贴命中的那个子文档**（不要让其贴入全部），再按 § 号定位 |

## 维护指南

- **编号**: 文件前缀 `NN-` 唯一递增、同源主题物理相邻；文件内 `###` = `NN.M`、`####` = `NN.M.K`，按出现顺序连续无断号
- **新增文件**: 编号接续；命名 `NN-主题-子主题.md`；同步更新本文件路由表
- **引用格式**: 一律 `` `文件名` §章节号 ``；**禁止**裸章节号、`第X部分`、中文序号
- **易漏的旧引用形态**: 括号编号 `(2.10)`、箭头 `→ 7.2.6`、中文序号 `§十四`、无文件名的章节名；改动后须全局扫描
- **风格**: 说明书式——统一「项 / UCI / 默认 / 取值 / YAML / 说明」表格，少用长段落，同一事实只写一次
- **分割大文件**: 超过 ~250 行时按 `###` 小节拆分，保持同源相邻
