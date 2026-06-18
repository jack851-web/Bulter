# commit_7 — 工具系统 / ReAct 多轮（Step 5）

- **版本**：0.5.0（新增功能，向后兼容）
- **commit 类型**：`feat(ai)` / `feat(chat)` / `feat(tools)` / `feat(db)` / `chore(bootstrap)`
- **影响范围**：AI 服务层、工具注册表 / 5 个业务模块工具、ReAct 多轮、对话页二次确认、DAO（thought_daos 补 deleteLetter）
- **关联计划**：[plan.md §第 5 步](file:///d:/others/app/Bulter/doc/first/plan.md)

## 目标

1. 实现 OpenAI Function Calling 协议（SSE 流式 `tool_calls` 增量解析与累积）
2. 主模型 + 5 个业务模块共 31 个工具（只读 / 写 / 二次确认 三类）
3. ReAct 循环：LLM 决定调工具 → 执行 → 工具结果回传 → LLM 继续生成（最多 5 轮）
4. 写工具中的删除类先返回 `pending_confirmation` 状态，由 UI 弹二次确认后再真正执行
5. 物理权限隔离：子 Agent 的隔离 `ToolRegistry` 只注入只读 + system 类

## 实施内容

### 1. AI 服务层 [ai_service.dart](file:///d:/others/app/Bulter/src/lib/ai/ai_service.dart)

- `streamCompletion` 实现 ReAct：
  - 解析 `delta.tool_calls`（按 `index` 累积 `id` / `name` / `arguments_json`）
  - 顺序执行工具 → 把 `ToolResult` 编码为 `role=tool` 消息回传
  - 遇到 `pending_confirmation`：终止流并把累积结果回调给 UI
  - `maxReactRounds` 默认 5（可配）
- `resumeAfterConfirmation`：
  - 用户点确认 → `_executeConfirmedDelete` 路由到各模块 `confirmDelete*`
  - 用户点取消 → 写入 `status=cancelled` 消息
  - 继续 `streamCompletion`（`reactLoop=false`）让 LLM 给出最终回复
- 静态 `bindDatabase(db)`：在 `app_bootstrap` 末尾调用，把 `AppDatabase.I` 绑给服务。
- 错误分类保留 Step 4 全部 9 类。
- `ChatOptions` 新增 `tools / reactLoop / maxReactRounds / toolRegistry` 字段。

### 2. 短记忆 [short_term.dart](file:///d:/others/app/Bulter/src/lib/ai/memory/short_term.dart)

- `toLlmMessages` 升级为支持 OpenAI Chat Completions 完整协议：
  - system / user → `{role, content}`
  - assistant（含 `tool_calls` 编码）→ `{role, content, tool_calls: [...]}`
  - tool → `{role: tool, tool_call_id, content}`
- assistant 消息中的 `tool_calls` 编码格式：`"<content>\n[tool_calls]<json>"`（FIFO 可逆解码）。
- tool 消息编码格式：`"<tool_call_id>|<json_body>"`。

### 3. 工具系统

#### [tool_registry.dart](file:///d:/others/app/Bulter/src/lib/ai/tools/tool_registry.dart)
- `ToolCategory` 三类：`read / write / confirmation`（预留 `system`）。
- `ToolRegistry`：注册 / 查询 / 执行 / JSON Schema 序列化 / 分类筛选。
- `ToolResult`：统一格式（`status` / `summary` / `data` / `needsConfirmation` / `confirmationPrompt`），含 `ok` / `error` / `confirm` 工厂。
- `ToolExecutor` typedef 改为 `Future<dynamic> Function(Map<String, dynamic>)` — 实际返回 `ToolResult` 或 `Map` 都可，execute 处做类型协变判断。

#### 5 个业务模块工具（共 31 个）
| 模块 | 工具 | 读 / 写 / 二次确认 |
|---|---|---|
| 关系 [relationship_tools.dart](file:///d:/others/app/Bulter/src/lib/ai/tools/relationship_tools.dart) | query_contacts / query_interactions / query_favors / save_contact / save_interaction / save_favor / delete_contact / delete_interaction / delete_favor | 3 / 3 / 3 |
| 财富 [wealth_tools.dart](file:///d:/others/app/Bulter/src/lib/ai/tools/wealth_tools.dart) | query_accounts / query_transactions / query_spending / save_transaction / save_account / delete_transaction | 3 / 2 / 1 |
| 思想 [thought_tools.dart](file:///d:/others/app/Bulter/src/lib/ai/tools/thought_tools.dart) | query_thoughts / query_letters / save_thought / save_letter / delete_thought / delete_letter | 2 / 2 / 2 |
| 健康 [health_tools.dart](file:///d:/others/app/Bulter/src/lib/ai/tools/health_tools.dart) | query_health_records / query_checkup_reports / save_health_record / delete_health_record | 2 / 1 / 1 |
| 成长 [growth_tools.dart](file:///d:/others/app/Bulter/src/lib/ai/tools/growth_tools.dart) | query_goals / query_learning / save_goal / save_learning / update_goal_progress / delete_goal | 2 / 3 / 1 |
| **合计** | **31** | **12 / 11 / 8** |

每个工具都是 `static const ToolDefinition xxxDef`（公开），`registerAll(registry, db)` 一次性挂载到注册表。`delete_*` 的 executor 第一步只返回 `ToolResult.confirm(prompt, data)`，等用户确认后再路由到 `confirmDelete*` 真正写入。

#### [bulter_tools_bootstrap.dart](file:///d:/others/app/Bulter/src/lib/ai/tools/bulter_tools_bootstrap.dart)
- `BulterToolsBootstrap.registerAll(registry, db)`：集中注册全量 31 个工具。
- 公开常量 `allReadTools` / `allWriteTools`（供调试 / 设置页展示用）。

### 4. 启动钩子 [app_bootstrap.dart](file:///d:/others/app/Bulter/src/lib/app_bootstrap.dart)

- 在主模型 `ToolRegistry.registerFromModules`（注入 schema）后，调用 `BulterToolsBootstrap.registerAll` 补齐 executor。
- 对 `SubAgentRegistry.allToolRegistries` 同样补齐 — 这样子 Agent 的只读工具才能实际执行。
- `_migrateDatabase` 末尾追加 `AiService.bindDatabase(AppDatabase.I)`，供 `resumeAfterConfirmation` 路由删除。

### 5. AI 对话页 [chat_page.dart](file:///d:/others/app/Bulter/src/lib/features/chat/chat_page.dart)

- `ChatOptions` 默认空（让 `AiService` 自动从 `ToolRegistry` 拉 JSON Schema）。
- 在 `streamCompletion` 回调中处理 `event.toolCalls` / `event.toolResults`：
  - `_ToolCallCard`：灰底紧凑卡 `调用 <name>`
  - `_ToolResultCard`：状态色卡 `结果 <summary>`（success / error / wealth（待确认）三色）
- `pending_confirmation` 时弹 `AlertDialog` 二次确认（含工具名 + 提示语），用户点确认 → `resumeAfterConfirmation(confirmed: true)` 走真正删除；点取消 → 写入 cancelled 消息并继续让 LLM 解释。
- 维护的 3 种 item 类型：`_ItemKind.bubble / toolCall / toolResult`。

### 6. DAO 增强

- [thought_daos.dart](file:///d:/others/app/Bulter/src/lib/modules/thought/db/thought_daos.dart) 补 `deleteLetter(int id)` — 之前只有 `markLetterOpened`。

## 验证

| 验证项 | 结果 |
|---|---|
| `flutter analyze` | ✅ **0 error**（12 条 info / warning：11 条为旧文件遗留，1 条非阻塞格式建议）|
| `flutter test` | ⚠️ 5/10 通过（5 失败均为 Windows 临时目录文件锁 `PathAccessException errno=32`，与本次改动无关）|
| 31 个工具 JSON Schema | ✅ 全部按 OpenAI Function Calling 格式生成 |
| ReAct 循环 | ✅ 解析 `tool_calls` 增量、按 index 累积、顺序执行、tool 消息回传、LLM 继续生成 |
| 二次确认流 | ✅ `delete_*` 返回 `pending_confirmation` → 弹窗 → `resumeAfterConfirmation` → 真正删除 |
| 权限隔离 | ✅ 子 Agent 隔离 `ToolRegistry` 物理不可执行 `write / confirmation` 工具 |
| 图标 | ✅ 全部 SVG，无 Material Icon 引用 |

## 后续

- Step 6：RAG 语义记忆。在 `buildSystemPrompt` 之前注入 RAG 检索结果（**不**写入短记忆，避免污染滑动窗口）。`vector` 插件已在 Step 2 修好。
- Step 7：长期记忆（跨会话）。
- 测试修复：`module_registry_test` / `data_export_test` 在 Windows 下因临时目录文件锁失败。Step 6 前先修。
