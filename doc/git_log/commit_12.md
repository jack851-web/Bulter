# commit_12 — 多智能体调度（Step 8）

- **版本**：0.7.0（新增主模型 + 5 子模型调度，0.6.1 向后兼容）
- **commit 类型**：`feat(ai)` / `feat(orchestrator)` / `feat(tools)` / `feat(ui)` / `refactor(modules)`
- **影响范围**：SpecialistAgent 升级、Orchestrator、invoke_sub_agent 工具、对话页调度链路卡
- **关联计划**：[plan.md §第 8 步](file:///d:/others/app/Bulter/doc/first/plan.md) 6 项验收全部勾选

## 目标

把"主模型 + 5 个子模型"的多智能体架构从 Step 5 的 `SpecialistAgent` 占位升级为真实可调用实例：
- 子模型有隔离的 ToolRegistry（**物理上**没有写工具）
- 子模型有 system prompt 声明能力边界（防止幻觉越权）
- 主模型通过 `invoke_sub_agent(module_id, query)` 工具跨模块调度
- 8s 超时自动降级，对话页显示调度链路卡

## 实施内容

### 1. [modules/bulter_module.dart](file:///d:/others/app/Bulter/src/lib/modules/bulter_module.dart) — SpecialistAgent 升级

- 字段从 const 友好的占位改成 final：`moduleId / name / systemPrompt / toolRegistry / aiService / defaultTimeout`
- 加 [invoke](file:///d:/others/app/Bulter/src/lib/modules/bulter_module.dart) 方法：12 轮短上下文 → 隔离 ToolRegistry + RAG 自动注入 → `.timeout(8s)` → 降级文案
- 失败路径三重：超时 / 异常 / 空返回 → 统一返回 `ok: false` + 降级文本（不让主模型产生幻觉越权）
- 加 [SubAgentResult](file:///d:/others/app/Bulter/src/lib/modules/bulter_module.dart)：模块名 / ok / text / toolsUsed / elapsed / error，附 `toLlmContext()` / `toUiCard()` 两种渲染

### 2. [BulterModule](file:///d:/others/app/Bulter/src/lib/modules/bulter_module.dart) 接口扩展

- 加 `bool get hasSubAgent` 抽象 getter：业务模块 override `true` 声明自己有子 Agent，中枢 / Demo 模块默认 `false`
- 业务模块 override 变更：
  - 删除 `SpecialistAgent? get subAgent => const SpecialistAgent(...)`（旧的占位）
  - 改为 `SpecialistAgent? get subAgent => null` + `bool get hasSubAgent => true`
- 5 个模块 + 1 个中枢 + 1 个 Demo + 1 个 `_MissingModule` 全部需要 override 这两个 getter（编译时强制）

### 3. [ai/sub_agents/orchestrator.dart](file:///d:/others/app/Bulter/src/lib/ai/sub_agents/orchestrator.dart)

- `invokeSubAgent(moduleId, query, timeout)`：单个子模型调用，找不到 → 降级文案（不抛错）
- `invokeMultiple(moduleIds, query)`：**并行**调多个子模型，整体 `Future.wait().timeout(12s)`，任何超时 → 所有返回降级文案
- `renderForLlm(results)`：把多个 SubAgentResult 拼成"子模型答复：- [模块] 文本"的字符串（供主模型在跨模块叙事时引用）

### 4. [ai/sub_agents/sub_agent_registry.dart](file:///d:/others/app/Bulter/src/lib/ai/sub_agents/sub_agent_registry.dart) 重构

- 注册时**不再用占位**：`module.hasSubAgent` 为 true 才注册
- 构造隔离的 `ToolRegistry.fresh()` 并 `registerFromModules([module], includeWrite: false)` —— 写工具**物理上不存在**
- system prompt 模板：声明身份 + 能力边界（"只能读 $moduleId 数据，写工具未注册物理不可用"）+ 回复格式（200 字以内，不 markdown）
- 持有 `AiService.instance` 引用，让子模型复用主模型的 LLM 通道

### 5. [ai/tools/invoke_sub_agent_tool.dart](file:///d:/others/app/Bulter/src/lib/ai/tools/invoke_sub_agent_tool.dart)

- 工具 schema：`module_id` enum（5 选 1）+ `query` string（必填）
- executor 调 `Orchestrator.invokeSubAgent` → 返回 `ToolResult.ok(text, data: {module_id, module_name, ok, tools_used, elapsed_ms})`
- **降级不报错**：失败 → `status=ok` 但 data 里 `ok=false, error='timeout/...'` + 降级文案，让主模型能继续汇总

### 6. [ai/tools/bulter_tools_bootstrap.dart](file:///d:/others/app/Bulter/src/lib/ai/tools/bulter_tools_bootstrap.dart) 注册

- `BulterToolsBootstrap.registerAll` 在末尾追加 `InvokeSubAgentTool.registerAll(registry)`
- 主模型现在共有 32 个工具（31 业务 + 1 调度）

### 7. [features/chat/chat_page.dart](file:///d:/others/app/Bulter/src/lib/features/chat/chat_page.dart) 调度链路卡

- `_ToolResultCard` 检测到 `toolName == 'invoke_sub_agent'` 时跳到新 `_SubAgentResultCard`
- `_SubAgentResultCard`：粉色 / 警告色边框 + 胶囊"模块名" + "调度成功 / 降级"状态 + ms 耗时 + 子 Agent 摘要 + 工具调用过的胶囊标签
- 数据从 `ToolResult.data` 里读（`module_name / ok / tools_used / elapsed_ms`）

## 验证

| 验证项 | 结果 |
|---|---|
| `flutter analyze lib` | ✅ **0 error**（21 个 warning / info 全部 pre-existing 或新加 format hints） |
| `flutter test test/dao_crud_test.dart` | ✅ 10/10 通过 |
| `flutter test test/data_export_test.dart` | ✅ 3/3 通过 |
| plan.md §第 8 步 6 项验收 | ✅ 全部勾选 |
| 物理隔离 | ✅ SubAgentRegistry.register 走 `includeWrite: false`，写工具根本不进 isolated registry |
| 超时降级 | ✅ `Future.timeout(8s)` → `TimeoutException` → 降级文案 `"（$name 子模型调用超时，已降级。该模块暂时不可用）"` |
| 调度链路可视化 | ✅ 对话页 `_SubAgentResultCard` 显示模块名 / 状态 / ms / 摘要 / 工具 |

## 遗留 / 下一步

- **生产子模型分离**：当前所有 SpecialistAgent 复用主模型 `AiService.instance`（即主模型 + 5 个子 Agent 共用一个 LLM）。生产可改成"子 Agent 用 `DeepSeek-V3` 等更轻量模型"——只需在 SubAgentRegistry.register 时换 `AiService` 实例即可。
- **跨模块并发**：Orchestrator 已支持 `invokeMultiple`，但当前主模型工具是单调用语义（一次 `invoke_sub_agent` 调一个模块）。要触发并发，需主模型在同一轮生成多个 tool_call 并行触发。Step 8 后可在 system prompt 加 hint 引导 LLM 并行调用。
- **write 工具越权检测**：当前物理隔离已经够稳，但未来若增加 `briefing_publish` 等 system 工具给子 Agent，需在 SubAgentRegistry 维护白名单（不是黑名单）。
- **`hasSubAgent` 接口扩展**：8 个模块都加了 override，编译期强制；下一步如果加新模块记得同步 override。

## 引用

- 设计：[doc/first/01-architecture.md](file:///d:/others/app/Bulter/doc/first/01-architecture.md) §四（多智能体架构）
- 计划：[doc/first/plan.md](file:///d:/others/app/Bulter/doc/first/plan.md) §第 8 步
- 上次 commit：[doc/git_log/commit_11.md](file:///d:/others/app/Bulter/doc/git_log/commit_11.md)（Step 7 4 层记忆）
- 协议：[doc/first/03-tech.md](file:///d:/others/app/Bulter/doc/first/03-tech.md) §四（tool_calls）+ §八（4 层记忆）
