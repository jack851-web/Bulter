# commit_16 — Step 11 AI 对话增强（流式打字机 + 长回复分页 + 跨会话记忆）

- **版本**：0.9.1
- **commit 类型**：`feat(ai)` + `feat(chat)` + `fix(test)`
- **影响范围**：Dart 3 新文件 + 3 改造 + 测试 1 新文件 + 测试 2 修复
- **关联文档**：[doc/first/plan.md §第 11 步](file:///d:/others/app/Bulter/doc/first/plan.md) 全部勾选

## 目标

把 AI 对话体验从"一次性整段出现"升级为：

1. **流式打字机**：AI 回复**逐字显示**（30ms / 字）+ 闪烁光标
2. **长回复分页**：> 2000 字符自动按标点切页（每页 800 字符 + "继续阅读" 按钮）
3. **跨会话记忆**：新会话自动加载最近 3 个 session 的最后 5 条消息作为补充上下文

## 实施内容

### A. Dart 3 个新组件

#### 1. 🆕 [lib/features/chat/typewriter_text.dart](file:///d:/others/app/Bulter/src/lib/features/chat/typewriter_text.dart)

**流式打字机组件**：
- `streamed=true`：目标文本实时变化，组件按字符逐步显示（默认 30ms / 字）
- `streamed=false`：直接显示完整文本（无打字机效果）
- 打字机模式下显示 `_BlinkingCaret`（▍）闪烁光标
- 完成后切回正常 Text（保留性能）

#### 2. 🆕 [lib/features/chat/long_reply_pager.dart](file:///d:/others/app/Bulter/src/lib/features/chat/long_reply_pager.dart)

**长回复分页组件**：
- 短于阈值（默认 2000 字符）→ 直接展示全文
- 长于阈值 → 按 pageSize（默认 800）切页，**切页位置找最近的句末标点**（"。" / "！" / "？" / "\n\n"）
- 底部"上一页 / 继续阅读"按钮 + 进度条
- 总页数显示（如"第 2 / 4 页"）

#### 3. 🆕 [lib/ai/memory/cross_session.dart](file:///d:/others/app/Bulter/src/lib/ai/memory/cross_session.dart)

**跨会话记忆加载器**：
- `loadContext(excludeSessionId, recentSessions=3, messagesPerSession=5)` → 拼接字符串
- 格式：`[Cross-session context from earlier conversation]` + session 标题 + 时间 + User/Assistant 对话
- 单条消息截断 200 字符，总字符上限 2000
- 单例模式：`CrossSessionMemory.instance`
- `enabled` 可在设置里关闭

### B. 集成（3 改造）

#### 1. 🔧 [lib/features/chat/chat_page.dart](file:///d:/others/app/Bulter/src/lib/features/chat/chat_page.dart)

- `_AssistantBubble._renderContent()`：
  - 流式模式（`streaming=true`）→ `TypewriterText` 逐字
  - 完成态 + 短文本（< 2000）→ `TypewriterText` streamed=false
  - 完成态 + 长文本（≥ 2000）→ `LongReplyPager` 自动分页
- `_send()` 里调 `CrossSessionMemory.instance.loadContext()`，结果传入 `ChatOptions.extraSystemPrompt`
- `_MemoryPanel` 增加 `crossSessionChars` 显示（状态条）

#### 2. 🔧 [lib/ai/ai_service.dart](file:///d:/others/app/Bulter/src/lib/ai/ai_service.dart)

- `ChatOptions` 加 `extraSystemPrompt` 字段（拼接到 `buildEnhancedSystemPrompt` 之后）
- `streamCompletion` 里：`systemPrompt += '\n\n${extraSystemPrompt}'`（**不**污染 RAG 注入的 system prompt）

#### 3. 🔧 [lib/ai/memory/memory_manager.dart](file:///d:/others/app/Bulter/src/lib/ai/memory/memory_manager.dart)

- `MemoryInjectionReport` 加 `crossSessionChars` 字段（默认 0，向后兼容）

### C. Pre-existing 测试修复

#### 1. 🔧 [lib/app_bootstrap.dart](file:///d:/others/app/Bulter/src/lib/app_bootstrap.dart)

- `bootstrapApp` 加 `enableScheduler` 参数（默认 true）
- 测试场景传 `false` 跳过 `BriefingScheduler.start()`（**避免** `Timer.periodic` 阻止 `flutter test` 退出 10 分钟）

#### 2. 🔧 [test/widget_test.dart](file:///d:/others/app/Bulter/src/test/widget_test.dart) + [test/module_registry_test.dart](file:///d:/others/app/Bulter/src/test/module_registry_test.dart)

- `setUp` 加 `TestWidgetsFlutterBinding.ensureInitialized()`
- `tearDown` 显式关闭 `AppDatabase` + `BriefingScheduler` + `Hive`，删除 temp dir 重试 3 次（**解决** Windows `PathAccessException`）
- `widget_test` 用 `tester.runAsync` 包裹 `bootstrapApp`（避免 fake async 拦截真实 platform channel）

## 验证

| 验证项 | 结果 |
|---|---|
| `flutter analyze lib` | ✅ **0 error** |
| `flutter test test/step11_chat_enhance_test.dart` | ✅ **7/7** 通过 |
| `flutter test test/db_migration_test.dart` | ✅ **6/6** 通过 |
| `flutter test test/dao_crud_test.dart` | ✅ **10/10** 通过 |
| `flutter test test/data_export_test.dart` | ✅ **3/3** 通过 |
| `flutter test`（全部） | ✅ **33/33** 通过 |
| plan.md §第 11 步 7 项验收 | ✅ 全部勾选 |
| **pre-existing module_registry_test** | ✅ 从 PathAccessException → 通过 |
| **pre-existing widget_test** | ✅ 从 10 分钟超时 → 通过 |

## 关键设计决策

### D1：打字机 vs 流式 push

- **流式 push**（之前）：LLM 推 chunk → 立刻 setState 全显示 → 用户看到"整段跳变"
- **打字机**（现在）：LLM 推 chunk → 累积到目标文本 → `_TypewriterText` 按 30ms / 字显示 → 用户看到"逐字显现"

**为什么用打字机**：
- LLM 流式 chunk 通常是 5-50 字符一推（不是逐字），直接 setState 会卡 UI
- 打字机给用户**阅读节奏**，更接近"人在说话"
- 打字机模式仅在"目标文本变长"时触发 timer，完成后切回普通 Text

### D2：长回复分页阈值 2000

- < 2000 字符 → 直接展示（手机 1-2 屏可看完，无需分页）
- ≥ 2000 字符 → 分页（每页 800 字符，约 5-7 段）
- **切页位置在标点**——不在句子中间断（避免"今天我吃" + "了早饭" 这种割裂体验）

### D3：跨会话上下文

- **不调 LLM**——纯 Drift SQL 查询（Session + Message 表）+ 文本拼接
- **总字符上限 2000**——避免 prompt 爆炸
- **作为 ChatOptions.extraSystemPrompt** 传入，**不**污染 `buildEnhancedSystemPrompt`（RAG 注入路径）
- 单条消息截断 200 字符（避免工具调用 JSON 挤爆上下文）

### D4：测试环境跳过 BriefingScheduler

- `BriefingScheduler.start()` 启动 `Timer.periodic(1min)`，永不结束
- `flutter test` 默认 10 分钟超时
- **修复**：`bootstrapApp(enableScheduler: false)` 在测试场景显式跳过
- tearDown 显式 `AppDatabase.close() + BriefingScheduler.stop() + Hive.close()`，确保文件句柄释放

## 引用

- 上次 commit：[commit_15.md](file:///d:/others/app/Bulter/doc/git_log/commit_15.md)（Step 10 浮窗输入）
- 设计：[doc/first/01-architecture.md](file:///d:/others/app/Bulter/doc/first/01-architecture.md) §七（AI 对话）
- 计划：[doc/first/plan.md](file:///d:/others/app/Bulter/doc/first/plan.md) §第 11 步
- 协议：[doc/first/03-tech.md](file:///d:/others/app/Bulter/doc/first/03-tech.md) §四（流式输出）
