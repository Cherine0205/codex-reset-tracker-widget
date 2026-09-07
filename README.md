# Codex Reset for macOS

原生 SwiftUI 应用 + WidgetKit 桌面/通知中心小组件，直接读取 [codex-reset.com](https://codex-reset.com) 的公开接口。

## 功能

- **公告动态**：Tibo 的最新消息，保留网站提供的分类和原文链接。
- **历史重置**：展示重置记录，区分站点已核验的归档和待核验动态。
- **概率预测**：展示站点计算的未来 24 / 48 小时重置概率与低置信度提示。
- **个人周用量**：手动填写已用百分比、下次重置时间；通过 App Group 与小组件共享。到期后提示重新核对，不自动假定额度恢复。
- 小尺寸展示预测，中尺寸增加个人用量，大尺寸再显示公告和历史摘要。点击打开主应用。

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

## 数据与刷新

| 内容 | 读取位置 |
| --- | --- |
| 公告 | `GET https://codex-reset.com/api/feed` |
| 历史 | `GET https://codex-reset.com/api/timeline` |
| 预测 | `GET https://codex-reset.com/api/forecast?tz=<本机时区>` |
| 个人记录 | 本机 App Group 中的 `personal.json` |

应用打开期间每 5 分钟刷新，可用 ⌘R 手动刷新。小组件申请每 15 分钟刷新，实际时间由 macOS 调度，不能保证准点。请求失败时保留最近可用内容并显示过期/失败状态，三个接口独立失败不会清空其他数据。

应用只向站点发送公开接口 GET 请求，不读取 ChatGPT 登录凭证，不上报个人用量，不调用站点的个人重置上报接口。请求会像普通网站访问一样向站点暴露 IP 和时区。个人记录不会自动同步网站浏览器里的 localStorage。

这是第三方站点的数据展示工具，与 OpenAI 和源站没有隶属关系。预测属于源站的实验模型，并非重置承诺。站点接口未提供本项目可依赖的版本/可用性保证，接口变化可能需要更新解析代码。公告文本版权归原作者所有，保留来源链接。

## 检查

```bash
swift test
LIVE_API_TEST=1 swift test --filter testLiveEndpointsWhenRequested
./script/build_and_run.sh --build
```

核心测试覆盖 API 时间格式、缓存过期、个人记录到期逻辑、来源链接限制。实时接口测试默认跳过，通过环境变量显式启用。

## 代码布局

- `Shared/`：数据模型、HTTP 客户端、App Group 存储
- `App/`：应用入口和状态
- `Views/`：预测、公告、历史、个人用量界面
- `Widget/`：WidgetKit 时间线和三种尺寸
- `Config/`：签名配置、Info.plist 和 entitlements
- `Tests/`：核心逻辑及可选实时接口检查
