# OpenClash 自动版本更新设计

日期：2026-06-30

## 背景

OpenClash 已支持 OIXCLOUD 专用加解密核心（OIX 核心）。由于 OIX 核心更新频繁，现有“版本更新”页面里的手动检查更新无法满足日常维护需求。需要在保留现有手动行为的前提下，增加一个可定时执行的自动版本更新功能。

自动更新的范围等同于“版本更新”页面右下角“检查更新”的范围：更新客户端版本并更新内核版本。触发后无论当前是否为 OIX 核心都生效；有 OIX token 或当前 core_type 为 Oix 时沿用现有 OIX 核心路径，否则更新普通 Meta/Smart 内核。

## 目标

- 在“版本更新”子标签页新增自动更新开关和周期设置。
- 自动更新周期参考“定时重启”子标签页：每周选择与每天小时选择。
- 保持用户在版本更新页设置的 `编译版本`、`更新分支`、`Smart 内核` 选项不变，并在自动任务中读取这些已保存值。
- 自动任务按固定源顺序尝试原始地址和镜像站：`https://raw.githubusercontent.com/`、`https://fastly.jsdelivr.net/`、`https://testingcf.jsdelivr.net/`、`https://cdn.jsdelivr.net/`。
- 每个下载源尝试直连和临时代理两种网络路径，不改写用户全局 GitHub 镜像设置。
- 失败时保留现有已安装客户端和内核，日志能说明尝试过的源和网络路径。

## 非目标

- 不改变现有手动更新按钮、手动下载按钮、一键更新弹窗的行为。
- 不把自动任务选择到的镜像源写回 `github_address_mod`。
- 不在 OpenClash 中实现 OIX 加解密逻辑；OpenClash 只负责传递配置和更新核心。
- 不为自动更新增加分钟级或自定义 cron 表达式设置。

## 用户界面

在 `luci-app-openclash/luasrc/model/cbi/openclash/settings.lua` 的 `version_update` tab 中，保留现有 `openclash/update` 模板，并在同一子标签页新增：

- `auto_version_update`：Flag，界面标题显示为“自动版本更新”。
- `auto_version_update_week_time`：ListValue，界面标题显示为“更新时间（每周）”，选项与 `auto_restart_week_time` 一致：每天、周一到周日。
- `auto_version_update_day_time`：ListValue，界面标题显示为“更新时间（每天）”，选项为 `0:00` 到 `23:00`。

用户界面中新增功能的标题、说明和选项遵循现有 LuCI 多语言模式：`settings.lua` 使用英文 `msgid`，中文界面通过 `zh-cn` 翻译显示中文文案，已有其他语言包保持对应语言翻译。内部 UCI option 名称继续使用英文小写加下划线，保持与现有配置风格一致。自动任务日志提示使用中文，便于中文用户排查定时更新状态。

默认值：

- `auto_version_update = 0`
- `auto_version_update_week_time = 1`
- `auto_version_update_day_time = 0`

这三个字段只控制自动任务调度。现有由 `update.htm` 和 `save_corever_branch` 保存的 `core_version`、`release_branch`、`smart_enable` 仍作为客户端和内核更新的实际选择来源。

## 调度

在 `/etc/init.d/openclash` 的 `add_cron()` 中新增 cron 生成逻辑：

```sh
0 <auto_version_update_day_time> * * <auto_version_update_week_time> /usr/share/openclash/openclash_auto_update.sh #openclash-cron-task
```

它使用现有 `#openclash-cron-task` 标记，由 `del_cron()` 统一清理。保存配置或服务重启后，cron 会随其他 OpenClash 定时任务一起重建。

## 执行入口

新增 `/usr/share/openclash/openclash_auto_update.sh`。该脚本只负责自动化编排，危险操作继续交给现有脚本：

- 客户端更新：`/usr/share/openclash/openclash_update.sh one_key_update <cdn>`
- 内核更新：由 `openclash_update.sh one_key_update` 继续触发现有核心更新流程，必要时由 `openclash_core.sh` 处理 OIX/Meta/Smart 核心下载。

执行流程：

1. 获取独立 lock，避免自动任务并发。
2. 读取 UCI 中的 `core_version`、`release_branch`、`smart_enable`、`github_address_mod`、`router_self_proxy`、`mixed_port`、`http_port`。
3. 如果 `core_version` 为 `0` 或空，写日志并跳过本次自动更新。
4. 按源顺序构造 CDN 参数：
   - 原始地址传空值，保持现有脚本的 raw 行为。
   - `https://fastly.jsdelivr.net/`
   - `https://testingcf.jsdelivr.net/`
   - `https://cdn.jsdelivr.net/`
5. 每个源先直连尝试，再临时启用代理环境变量尝试。
6. 任一源加网络路径完成“无需更新”或“更新链路成功启动/完成”后停止后续尝试。
7. 所有路径失败时记录最终失败日志，不修改 UCI 中的下载源设置。

代理尝试只影响当前脚本进程，例如临时设置：

```sh
http_proxy=http://127.0.0.1:<port>
https_proxy=http://127.0.0.1:<port>
all_proxy=socks5h://127.0.0.1:<port>
```

端口优先使用 OpenClash 当前可用的本机代理端口。若未运行或端口不可用，代理尝试记录为跳过，不视为直连失败的覆盖原因。

## 下载源与 OIX 地址补强

现有 OIX 核心版本文件和核心包来自 GitHub Release：

- `https://github.com/vernesong/mihomo-oix/releases/download/Pre-Alpha/version.txt`
- `https://github.com/vernesong/mihomo-oix/releases/download/Pre-Alpha/mihomo-<arch>-<version>.gz`

自动任务需要让 OIX 下载也参与同一套源轮询：

- 原始地址使用 GitHub Release 原 URL。
- jsDelivr 系列使用 `gh/vernesong/mihomo-oix@Pre-Alpha/...` 形式拼接。
- 非 jsDelivr 自定义前缀仍按现有逻辑拼接完整 GitHub URL。

该补强应放在 `clash_version.sh` 和 `openclash_core.sh` 的 URL 生成处，保证手动和自动路径使用一致的地址转换规则。

## 成功与失败判定

自动脚本需要能区分三类结果：

- 成功：客户端和内核更新流程正常完成，或已启动安装服务并交给 procd 后台执行。
- 无需更新：版本检查成功，现有版本已是最新。
- 失败：版本信息获取失败、下载失败、预安装测试失败、核心校验失败或脚本异常退出。

为了可靠判断，`openclash_update.sh` 与 `openclash_core.sh` 可以补充明确退出码，但不改变现有用户可见行为：

- `0`：成功或无需更新。
- `1`：失败。
- `2`：后台安装服务已成功启动。

自动脚本基于退出码和必要的日志/临时文件判断是否继续尝试下一个源。现有 `gzip -t`、`tar` 解包、可执行校验、`opkg/apk` 预安装测试、lock 和 job counter 逻辑保持不变。

## 日志

自动任务使用现有 `LOG_TIP`、`LOG_WARN`、`LOG_ERROR` 输出到 OpenClash 日志。日志至少覆盖：

- 自动更新开始和结束。
- 当前尝试的源和网络路径。
- `core_version=0` 时跳过原因。
- 每次失败的原因摘要。
- 最终成功使用的源和网络路径，或所有路径失败。

日志不输出 OIX token、订阅 URL、私钥或代理认证信息。

## 测试计划

本地验证：

- `bash -n luci-app-openclash/root/usr/share/openclash/*.sh`
- 针对修改过的 init 脚本运行 `sh -n luci-app-openclash/root/etc/init.d/openclash`。

回归测试：

- 新增 `tests/openclash_auto_update_test.sh`，stub `uci_get_config`、更新脚本和下载路径。
- 覆盖 `core_version=0` 跳过。
- 覆盖源顺序：raw、fastly、testingcf、cdn。
- 覆盖每个源的直连优先、代理后备。
- 覆盖成功后停止后续源。
- 覆盖所有源失败后的日志与失败退出。

设备验证：

- 保存配置后检查 `/etc/crontabs/root` 中自动更新 cron 是否按设置生成。
- 手动执行 `/usr/share/openclash/openclash_auto_update.sh`，确认日志出现源和网络路径尝试记录。
- 在 OIX token 存在与不存在两种状态下分别确认核心类型路径正确。

## 风险与缓解

- 风险：自动更新与用户手动更新并发。
  - 缓解：新增自动任务 lock，并继续依赖现有更新脚本 lock。
- 风险：代理环境变量泄漏影响其他任务。
  - 缓解：仅在子进程或单次调用环境中设置，不导出到全局配置。
- 风险：错误镜像地址导致 OIX Release 下载失败。
  - 缓解：把 OIX URL 转换集中在版本检查和核心下载脚本中，并用测试覆盖。
- 风险：客户端安装由后台 procd 服务继续执行，自动脚本无法等待最终安装结果。
  - 缓解：把“安装服务成功启动”作为自动调度成功启动条件，最终安装结果继续由现有日志呈现。
