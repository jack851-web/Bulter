# commit_6 — AI 调用基础（单 LLM 流式对话，Step 4）

- **版本**：0.4.0（新增功能，向后兼容）
- **commit 类型**：`feat(ai)` / `feat(ui)` / `refactor(ui)` / `chore(assets)`
- **影响范围**：AI 服务层、模型注册表、短记忆、模型配置页、AI 对话页、SVG 图标系统、5 个业务模块 + Demo 的 Tab / icon
- **关联计划**：[plan.md §第 4 步](file:///d:/others/app/Bulter/doc/first/plan.md)
- **设计规则**：依据用户最新规则，**前端所有图标统一自绘 SVG，不再使用 Material Icons**。

## 目标

1. 接入真实 LLM 流式对话（SSE、9 厂商可切换、API Key 持久化）
2. 实现滑动窗口短记忆（20 轮）
3. 提供模型配置 UI（当前激活 / 厂商 chips / 模型下拉 / API Key 密码输入）
4. 重构 AI 对话页：流式打字机 + 错误占位 + 三点动画 + 未配置引导
5. **全前端禁止 Material Icons**，统一为自绘 SVG 图标系统

## 实施内容

### 1. AI 服务层 `lib/ai/`

| 文件 | 作用 |
|---|---|
| `ai_service.dart` | `streamCompletion`（SSE 流式 + `done` 终止 + 错误分类）+ `completion`（非流式，Step 5 tool 用）+ 内部 `_handleSseEvent` 解析 `data: {json}\n\n` 分块 |
| `model_registry.dart` | 9 厂商元信息 + 每厂商 2-4 个可选模型；`AuthScheme`（bearer / x-api-key / googleQuery）；`load()` 启动时从 Hive 读当前选择 + 各 vendor 的 apiKey |
| `memory/short_term.dart` | 滑动窗口 20 轮（40 条消息），FIFO 丢最旧，system 消息永驻；`toLlmMessages()` 转 OpenAI Chat Completions wire 格式 |
| `app_bootstrap.dart` | 启动时 `await ModelRegistry.instance.load()` |

**错误分类**（`AiErrorKind`）：
- `noApiKey` — 未配置 Key
- `auth` — 401 / 403
- `rateLimit` — 429
- `notFound` — 404（模型名错）
- `server` — 5xx
- `network` — 超时 / 断网
- `parse` — 响应解析失败
- `badRequest` / `unknown`

### 2. 模型配置页 `lib/features/settings/`

- [model_config_page.dart](file:///d:/others/app/Bulter/src/lib/features/settings/model_config_page.dart)：4 个区块：当前激活卡（含已配置 / 未配置徽标）→ 厂商横向 chips → 模型下拉 → API Key 密码输入（带显示 / 隐藏切换）→ 保存 / 清除按钮 + 提示语。
- [settings_page.dart](file:///d:/others/app/Bulter/src/lib/features/settings/settings_page.dart)：AI 区两项"模型" / "API Key"均跳转到 `ModelConfigPage`；动态展示当前激活 + API Key 状态。

### 3. AI 对话页 [chat_page.dart](file:///d:/others/app/Bulter/src/lib/features/chat/chat_page.dart)

- 顶部状态条：在线点 + `在线 · N 件事已被追踪` / `未配置 API Key · 点击设置`，右侧圆形设置按钮跳模型配置。
- 消息流：用户右侧纯黑泡 / AI 左侧浅色泡（错时红底）；流式更新时 AI 泡显示三点动画。
- 错误：流式回调收到 `error` 时把内容置为错误消息（不崩溃）。
- 底部输入框：发送中按钮置灰禁用。
- 路由：`/settings/model` 通过 `go_router` 覆盖在 Shell 之上（见 [router.dart](file:///d:/others/app/Bulter/src/lib/router/router.dart)）。

### 4. SVG 图标系统

- [svg_icon.dart](file:///d:/others/app/Bulter/src/lib/components/svg_icon.dart)：`SvgIcon(name, size, color)` + `SvgIconButton`（圆形容器 + 内部 SVG）。
- `assets/svg/{common, modules, chat, settings}/` 共 **40+ 个**手绘 24x24 viewBox stroke 风格图标（与 Material Icons 等价覆盖）：
  - common：close / chevron-right / chevron-down / expand-more / check / arrow-up / arrow-forward / arrow-downward / plus / arrow-outward / sparkles / menu / download / upload / info / error / tune / receipt / circle / inbox
  - modules：butler / relationship / growth / wealth / thought / health / memory / timeline / report / trending-up / chip / chart / globe / briefcase / mail / briefcase-filled
  - chat：chat-bubble / chat-bubble-outline / send / robot / user
  - settings：key / model
- `pubspec.yaml` 追加 5 个 `assets/svg/*` 路径。
- `EmptyState.icon` 从 `IconData` 改为 `Widget`；`StreamListView.emptyIcon` 改为 `String emptyIconName`；`TabItem.icon` 改为 `String iconName`；`ModuleTab.icon` 改为 `String iconName`；`ModulePlaceholderPage.icon` 改为 `Widget icon`。
- 全部 7 个模块（Butler 中枢 / 5 业务 + Demo）的 Tabs / `_ModuleCard.icon` / `_MissingModule` 全部切换为 SVG。

## 验证

| 验证项 | 结果 |
|---|---|
| `flutter analyze` | ✅ **0 error**（12 条 info / warning：均为非阻塞的旧文件提示 / 格式建议）|
| `flutter test` | ⚠️ 24/26 通过（2 失败均为 Windows 临时目录文件锁 `PathAccessException errno=32`，与本次改动无关，将在 Step 5 前修）|
| AI 对话流式输出 | ✅ 真实 LLM（SSE）增量回写到 UI |
| 短记忆 | ✅ 20 轮滑动窗口；超过自动 FIFO 丢弃最旧 |
| 模型切换 | ✅ 厂商 chips + 模型下拉 + API Key 立即生效 |
| 错误分类 | ✅ 无 Key / 401 / 429 / 404 / 网络异常分别给出可读提示 |
| 全部图标 | ✅ 0 处 `Icons.` 引用（grep 验证）|

## 后续

- Step 5：工具系统（Tool Use）。`ai_service.dart` 已留 `tool_calls` 累积接口位置；`tool_registry.dart` 已支持只读 / 写两类工具物理隔离。
- Step 6：RAG 语义记忆。在 `systemPrompt` 之前注入 RAG 检索结果（**不**写入短记忆，避免污染滑动窗口）。
- 测试修复：`module_registry_test` / `data_export_test` 在 Windows 下因临时目录文件锁失败。Step 5 前先修这两个测试（改为 `try { ... } finally { dir.deleteSync(recursive: true); }` 容错）。
