# Codex Reset for macOS

原生 SwiftUI 应用 + WidgetKit 桌面/通知中心小组件，直接读取 [codex-reset.com](https://codex-reset.com) 的公开接口。

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## 功能

- **公告动态**：Tibo 的最新消息，保留网站提供的分类和原文链接。
- **历史重置**：展示重置记录，区分站点已核验的归档和待核验动态。
- **概率预测**：展示站点计算的未来 24 / 48 小时重置概率与低置信度提示。
- **个人周用量**：只读连接本机 Codex 的用量记录，提取已用百分比、重置时间和记录时间；也可手动填写。通过 App Group 与小组件共享，到期后等待新记录，不自动假定额度恢复。
- **大号**：个人用量、重置倒计时和重置券横向排列，预测合并为一行，下方显示 2 条重点公告和 1 条核验记录。
- **超大号**：顶栏横向排列全部指标，下方双栏各显示 3 条重点公告和 3 条核验记录。点击打开主应用。
- 原生侧栏分为概览、公告、重置历史；概览筛选重置/用量相关动态，公告页可切换全部/重点，历史页可切换已核验/全部。浅色与深色跟随系统。
- 重置券独立一栏展示可用数量与最近到期日期，完整到期时间可悬停查看；未知数据展示“未同步”，同步失败或超过 15 分钟展示“待更新”。

## 界面预览

以下是布局渲染预览，使用示例个人用量，不是实际账号截图。桌面上的材质、边缘和着色由 WidgetKit 管理。

![大号浅色](docs/widget-large-light.png)
![超大号深色](docs/widget-extra-large-dark.png)

## 构建和运行

需要 macOS 14+、Xcode 15+ 和本机可用的 Apple Development 签名证书。

1. 打开 `CodexReset.xcodeproj`。
2. 新建 `Config/Local.xcconfig`（已被 Git 忽略），填写自己的 Team ID：

   ```xcconfig
   DEVELOPMENT_TEAM = YOUR_TEAM_ID
   ```

3. 选择 **CodexReset** scheme，运行，或执行：

   ```bash
   ./script/build_and_run.sh --verify
   ```

App 和 Widget 共用 `$(DEVELOPMENT_TEAM).com.cherine.codex-reset` App Group。签名团队必须一致。分发版本需自行完成相应签名与公证；本仓库不包含证书或凭证。

运行主应用后，右键桌面 → **编辑小组件** → 搜索 **Codex Reset**，选择所需尺寸。若列表尚未出现，先将已构建的 App 拖入“应用程序”并打开一次。

本地开发请使用 `script/build_and_run.sh` 更新。脚本在构建成功后同时重启主应用和本项目的小组件扩展，避免 WidgetKit 继续运行旧二进制而显示旧版界面；不会重启通知中心或其他应用的小组件。

## 数据与刷新

| 内容 | 读取位置 |
| --- | --- |
| 公告 | `GET https://codex-reset.com/api/feed` |
| 历史 | `GET https://codex-reset.com/api/timeline` |
| 预测 | `GET https://codex-reset.com/api/forecast?tz=<本机时区>` |
| 个人用量 | 优先读取本机 Codex 官方接口返回的账号周额度；没有账号快照时回退到授权的 sessions 日志，或手动填写 |

应用打开期间每 5 分钟刷新，可用 ⌘R 手动刷新。小组件申请每 15 分钟刷新，实际时间由 macOS 调度，不能保证准点。请求失败时保留最近可用内容并显示过期/失败状态，三个接口独立失败不会清空其他数据。

大号和超大号右上角均有刷新按钮，唤起并复用主应用窗口，通过 `codexreset://refresh` 触发一次账号和站点数据同步。主应用等待新账号结果再更新共享缓存和小组件；失败或 30 秒超时会在个人用量卡显示错误，不把旧记录的时间改成当前时间。

### 连接本机 Codex

点击 **连接本机 Codex…**，在系统文件夹选择器中按 **⌘⇧G**，输入 `~/.codex/sessions`，选择“连接”。应用保存只读的 security-scoped bookmark，重新启动后继续读取；点击“断开”可清除连接和当前用量记录，恢复手动模式。自定义 `CODEX_HOME` 时选择对应目录下的 `sessions`。

安装下述同步任务后，优先读取 **Codex 官方 `account/rateLimits/read` 返回的账号额度**，不再依赖最近一次对话生成的日志。仅使用 `codex` 额度桶，并按 `windowDurationMins == 10080` 查找周窗口，不混入 Spark。未产生账号快照时，仍可读取最近 14 天日志作为回退，界面会标明“Codex 本地记录”。

应用打开期间每 5 分钟将最新账号快照同步给小组件，手动刷新会额外触发一次账号读取。记录超过 30 分钟时显示“待更新”。只有日志回退模式依赖 Codex 产生新的会话记录。

### 账号用量与重置券同步

需要本机已登录的 Codex 和 Python 3。周用量、重置时间和重置券明细均通过 `codex app-server` 的只读 `account/rateLimits/read` 获取；优先使用桌面应用内置的新版 Codex，旧 CLI 可能只返回券数量而没有到期时间。不会调用兑换接口。

```bash
python3 script/install_credit_sync.py
# 自定义会话目录：增加 --sessions /path/to/CODEX_HOME/sessions
# 自定义构建路径：增加 --app /path/to/CodexReset.app
```

先构建应用再安装同步任务。安装器将独立脚本复制到 `~/Library/Application Support/CodexReset/`，注册 `com.cherine.codex-reset.credit-sync` LaunchAgent，登录时及每 300 秒运行，并监听 App Group 中的 `sync-request.json` 写入事件以响应手动刷新。**安装过旧版任务的用户也需重新运行安装器**，使实时用量读取和按需触发生效。任务只保存用量、重置时间、券数量、到期时间和同步状态，不保存账号 ID、券 ID、凭证或对话内容。

由于 macOS 限制普通后台脚本访问 App Group，任务将结果写入所选 sessions 目录下的 `codex-reset-credits.json`。主应用使用已有的 sessions 只读授权接收这份小文件，再写入小组件共享缓存。保持主应用运行可持续同步；关闭时点击小组件刷新会唤起主应用，完成同一流程。组件最终显示更新仍由 WidgetKit 调度。

可通过 `launchctl bootout gui/$(id -u)/com.cherine.codex-reset.credit-sync` 停止当前任务；移除 `~/Library/LaunchAgents/com.cherine.codex-reset.credit-sync.plist` 可取消后续登录启动。任务只读取账号，券过期后在界面本地扣除；已用券以接下来成功读取的账号结果为准。

应用向第三方站点发送公开接口 GET 请求，不读取 ChatGPT 登录凭证，不向该站点上传会话、个人用量、重置券或重置时间，不调用站点的个人重置上报接口。可选的重置券任务使用 Codex 自己的登录状态读取 OpenAI 账号额度。扫描期间会在内存读取文件尾部，仅解码用量事件并保存额度字段。第三方站点请求会像普通网站访问一样暴露 IP 和时区。个人记录不会自动同步网站浏览器里的 localStorage。

这是第三方站点的数据展示工具，与 OpenAI 和源站没有隶属关系。预测属于源站的实验模型，并非重置承诺。站点接口未提供本项目可依赖的版本/可用性保证，接口变化可能需要更新解析代码。公告文本版权归原作者所有，保留来源链接。

## 检查

```bash
swift test
LIVE_API_TEST=1 swift test --filter testLiveEndpointsWhenRequested
LIVE_CODEX_TEST=1 swift test --filter CodexUsageTests
python3 script/test_sync_reset_credits.py
./script/build_and_run.sh --build
```

核心测试覆盖 API 时间格式、缓存过期、请求失败保留缓存、个人记录到期逻辑、来源链接限制、Codex 周窗口选择、额度桶隔离和最新记录选择。真实接口与本机 Codex 检查默认跳过，通过环境变量显式启用。

## 代码布局

- `Shared/`：数据模型、HTTP 客户端、App Group 存储
- `App/`：应用入口和状态
- `Views/`：预测、公告、历史、个人用量界面
- `Widget/`：WidgetKit 时间线与大号、超大号布局
- `Config/`：签名配置、Info.plist 和 entitlements
- `Tests/`：核心逻辑及可选实时接口检查

## 开源许可

项目代码采用 [MIT License](LICENSE)，欢迎通过 Issue 和 Pull Request 参与。公告文本、第三方名称及预览中的来源内容仍归各自权利人所有，不因本项目开源而变更许可。预览中的个人用量和重置券为示例数据。
