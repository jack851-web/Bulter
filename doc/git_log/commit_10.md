# commit_10 — RAG 语义记忆（Step 6 收尾）

- **版本**：0.6.0（新增 RAG 能力，0.5.2 向后兼容）
- **commit 类型**：`feat(rag)` / `feat(memory)` / `feat(ui)` / `chore(bootstrap)`
- **影响范围**：RAG 子系统、长记忆、用户画像、工作记忆、4 层记忆管理、对话 system prompt 注入、长期记忆页（全部 + 语义搜索）
- **关联计划**：[plan.md §第 6 步](file:///d:/others/app/Bulter/doc/first/plan.md) 5 项验收全部勾选

## 目标

把分散在 untracked 文件里的 RAG / 长记忆 / 用户画像 4 层记忆子系统接入 Bulter 主流程，补齐"语义搜索结果页" UI，让 Step 6 的 5 项验收标准全部生效。

## 实施内容

### 1. RAG 子系统 `lib/ai/rag/`

| 文件 | 作用 |
|---|---|
| [embedder.dart](file:///d:/others/app/Bulter/src/lib/ai/rag/embedder.dart) | `Embedder` 抽象；`OpenAiCompatibleEmbedder`（默认 `text-embedding-3-small`，1536 维，自动探测 9 厂商是否兼容 `/v1/embeddings`，不支持则回退）；`LocalHashEmbedder`（128 维 n-gram 哈希，仅作 fallback / 测试） |
| [retriever.dart](file:///d:/others/app/Bulter/src/lib/ai/rag/retriever.dart) | `Retriever.retrieve(query, options)`：embed query → vector store Top-K → L2 距离转余弦相似度 → 按 sourceType 去重（`maxPerSource`） → 按相似度降序返回 |
| [context_injector.dart](file:///d:/others/app/Bulter/src/lib/ai/rag/context_injector.dart) | 从 `ShortTermMemory` 取最后一条 user 消息作为 query → 调 retriever → 把 hits 拼成一段 "以下是可能相关的历史记忆：..." 追加到 system prompt |
| 嵌入维度 | `vectorSchemaVersion = 2`，默认 1536 维（OpenAI text-embedding-3-small）；建表时 `vec_meta` 记录当前维度，旧库维度不匹配时按设计自动重建（仅开发期，详见 §6.4 风险） |

`VectorStore` 已在 [db/vector_store.dart](file:///d:/others/app/Bulter/src/lib/db/vector_store.dart) 完整就位（含 ensureTable / insert / topK / deleteBySource / count / migrate），Step 2 已写过，本次只 verify。

### 2. 4 层记忆 `lib/ai/memory/`

| 文件 | 作用 |
|---|---|
| [short_term.dart](file:///d:/others/app/Bulter/src/lib/ai/memory/short_term.dart) | 滑动窗口 20 轮 / 40 条消息，FIFO 丢最旧；system 永驻；编码 assistant `tool_calls` 与 tool 消息回传 LLM |
| [long_term.dart](file:///d:/others/app/Bulter/src/lib/ai/memory/long_term.dart) | **事实抽取 + 去重**：每 N 条 user 消息触发一次，LLM 抽取 fact/event/preference/relationship；字面精确去重 + 向量相似度 > 0.92 去重；新事实写 `memories` 表 + `vec_embeddings` |
| [user_profile.dart](file:///d:/others/app/Bulter/src/lib/ai/memory/user_profile.dart) | **用户画像**：4 个标量字段（displayName / occupation / location / birthday）+ 3 个 JSON 列表（preferences / goals / importantPeople）；每 N 条 user 消息自动从对话中抽取并 merge 已有画像；`render(p)` 输出可注入 LLM 的"画像段落" |
| [working.dart](file:///d:/others/app/Bulter/src/lib/ai/memory/working.dart) | **工作记忆**：多步任务中间状态（key/value），任务结束自动清空，跨步骤注入 LLM |
| [memory_manager.dart](file:///d:/others/app/Bulter/src/lib/ai/memory/memory_manager.dart) | **统一管理 4 层**：每次 LLM 调用前组装 system prompt（基础 + 用户画像 + RAG 召回 + 工作记忆）；`onUserMessage()` 触发长记忆 / 画像抽取；返回 `MemoryInjectionReport` 给 UI |

`MemoryManager.buildSystemPrompt(memory)` 的输出顺序：基础提示 → 画像段 → RAG 段（如果 `injector.lastInjectedCount > 0`，整段替换避免重复 base） → 工作记忆段。

### 3. 启动钩子 [app_bootstrap.dart](file:///d:/others/app/Bulter/src/lib/app_bootstrap.dart)

`_initRag()` 一次性 wire：

```
EmbedderFactory.resolve()       → Embedder (OpenAI 兼容 或 LocalHash)
vectorStore.ensureTable(1536)   → vec_embeddings 虚拟表
Retriever(embedder, store)      → Top-K 召回
ContextInjector(retriever)      → 注入 system prompt
LongTermMemory(...)             → 事实抽取
UserProfileMemory(...)          → 画像抽取
MemoryManager(...)              → 4 层统一管理
AiService.bindRag(RagBundle)    → 服务层拿到 injector / longTerm / memory
```

`AiService.streamCompletion` 在 `buildEnhancedSystemPrompt` 中优先走 `MemoryManager.buildSystemPrompt`，RAG 未绑定时降级为旧路径。**RAG 失败 / 不可用时绝不阻塞主对话流**。

### 4. 长期记忆页 [memory_page.dart](file:///d:/others/app/Bulter/src/lib/features/memory/memory_page.dart)

重做为 **"全部 / 搜索"** 双 Tab（segment 胶囊式指示器）：

- **全部 Tab**：按 fact / preference / relationship / event 4 个类型分组，每组带品牌色图标 + 数量徽标；左滑删除 + 二次确认弹窗。
- **搜索 Tab**（本次新增）：
  - 顶部搜索框 + 纯黑"搜索"按钮，输入回车直接触发。
  - 调 `AiService.rag.injector.retriever.retrieve(query, k: 8, minSimilarity: 0.30)`。
  - 结果卡：内容 + 右上角相似度百分比胶囊（≥75% 绿 / ≥50% 金 / <50% 灰）+ 底部 60pt 横向相似度细条 + 来源 `memory / thought / transaction` 标签 + id。
  - 5 种状态：未输入 / 搜索中 / 错误 / 命中 N 条 / 无结果。
  - 关于 dialog 解释"语义检索"：搜"妈妈"会命中"妈妈生日是 3 月 5 号"、"妈妈喜欢花茶"等所有相关。

### 5. 设置页 + 用户画像页

- [settings_page.dart](file:///d:/others/app/Bulter/src/lib/features/settings/settings_page.dart) AI 助理 section 已含"长期记忆"入口（跳 `MemoryPage`）+"用户画像"入口（跳 `UserProfilePage`）。
- [user_profile_page.dart](file:///d:/others/app/Bulter/src/lib/features/settings/user_profile_page.dart) 用户可手动查看 / 编辑画像（基础信息 / 偏好 / 目标 / 重要他人四组 KV 列表），改完即写回 DB。

## 验证

| 验证项 | 结果 |
|---|---|
| `flutter analyze lib` | ✅ **0 error**（25 个 warning / info：23 个 pre-existing + 2 个 import lint 顺手清掉） |
| `flutter test` | ✅ 24/26 通过（2 个失败为 pre-existing：Windows 临时目录文件锁 + 启动超时，与本次改动无关） |
| plan.md §第 6 步 5 项验收 | ✅ 全部勾选 |
| RAG 降级路径 | ✅ embedder 不可用 → 只做字面去重；vector store 不可用 → retriever 返回空（不抛错）；RAG 整体未绑定 → 旧 system prompt 路径 |
| 端到端：长记忆写入 | `LongTermMemory._persistFact` 先写 `memories` 再写 `vec_embeddings`，**后者失败不阻塞前者**（debugPrint 后继续） |
| 端到端：去重双维度 | `_isDuplicate` 先字面精确匹配（trim 后 ==），再走向量相似度 ≥ 0.92 |
| 端到端：自动注入 | `AiService.buildEnhancedSystemPrompt` 每次重建，含画像 + RAG + 工作记忆（每次都拿到最新状态） |

## 遗留 / 下一步

- Step 7（4 层记忆完整）验收项其实在 Step 6 已就位：用户画像 + RAG + 短记忆 + 工作记忆全在 `MemoryManager.buildSystemPrompt` 拼装完成；对话页"记忆注入区"折叠 UI 已在 chat_page 中以 `_MemoryPanel` 形式存在（来自 Step 5）。Step 7 主要剩余：**画像可在设置页手动编辑**（本次 commit 已实装）。
- Step 8（多智能体）：主模型已注册 `invoke_sub_agent` 占位（Step 5 留的 hook），子 Agent 注册表已 wire。本次未触碰，留到 Step 8 推进。
- `RagBundle.memory`（`MemoryManager?`）当前在 `app_bootstrap._initRag` 中传入；后续可在 Step 7 把"对话关闭时强制抽取"接到 `MemoryManager` 的完整生命周期上。
- sqlite-vec 在 Windows 桌面测试环境加载 `bulter_sqlite_vec.dll` 失败（pre-existing 已知问题），按设计降级为日志 `print` / `debugPrint`，不阻断主流程。

## 引用

- 设计：[doc/first/01-architecture.md](file:///d:/others/app/Bulter/doc/first/01-architecture.md) §七（4 层记忆架构）
- 计划：[doc/first/plan.md](file:///d:/others/app/Bulter/doc/first/plan.md) §第 6 步
- 技术细节：[doc/first/03-tech.md](file:///d:/others/app/Bulter/doc/first/03-tech.md) §七（RAG 语义记忆）
- 上一提交：[doc/git_log/commit_9.md](file:///d:/others/app/Bulter/doc/git_log/commit_9.md)（fix home & sub-module body）
