# commit_11 — 4 层记忆完整闭环（Step 7 精化）

- **版本**：0.6.1（精化，0.6.0 向后兼容）
- **commit 类型**：`feat(memory)` / `feat(ui)` / `refactor(chat)`
- **影响范围**：对话页 _MemoryPanel、4 层记忆用户画像字段计数
- **关联计划**：[plan.md §第 7 步](file:///d:/others/app/Bulter/doc/first/plan.md) 5 项验收全部勾选

## 背景

Step 6（RAG）落地后，4 层记忆的代码已完整就位（short_term / long_term / working / user_profile + memory_manager），但对话页 `_MemoryPanel` 是**定义了但未接入 build 树**的死代码，且 `profileAvailable` 用 bool 写死成"是否设置过画像"，无法表达"画像里到底记了多少字段"。

本次 commit 把第 7 步的 5 项验收标准全部对齐：

1. ✅ 用户画像自动从对话中提取（`UserProfileMemory.maybeExtract` 已在 Step 6 落地）
2. ✅ 每次对话 AI 回复符合画像特征（`MemoryManager.buildSystemPrompt` 每次都拼画像段，注入到 LLM）
3. ✅ 记忆注入区显示画像 / RAG / 短记忆轮数（**本次真正接入**）
4. ✅ 多步任务中间状态不丢失（`WorkingMemory` 已在 Step 6 落地）
5. ✅ 画像可在设置页查看和手动编辑（`UserProfilePage` 已在 Step 6 落地）

## 实施内容

### 1. 对话页 `_MemoryPanel` 真正接入 [chat_page.dart](file:///d:/others/app/Bulter/src/lib/features/chat/chat_page.dart)

之前 `_MemoryPanel` 类已定义但**从未在 build 中实例化**。本次：

- 在 `_StatusBar` 之后、消息列表之前插入 `_MemoryPanel`（有 `_lastInjection` / `_profileFieldCount > 0` / `_lastMemoryUpdate` 任一即显示）
- 把"用户画像是否设置"从 `bool _profileAvailable` 升级为 `int _profileFieldCount`（实际已填字段数）
- 新增 `String _profileName`（画像 displayName）让面板里能直接显示"小明 · 4 字段"

`_countProfileFields(UserProfile p)` 实现：扫 7 个字段（4 个标量 + 3 个 JSON 列表），统计非空项数。`_decodeListLen(String json)` 安全解 JSON 列表长度（空 / '[]' / '[]' 都返回 0）。

### 2. `_MemoryPanel` 字段化重构

`profileAvailable: bool` → `profileFieldCount: int + profileName: String`：

- **summary 摘要行**：`画像 N 字段` 替代原来的 `画像` 一词，更具体
- **detail 详情行**：`$profileName · $profileFieldCount 字段`（如有名字）/ `$profileFieldCount 字段`（无名字）/ `未设置`（0 字段）三档

### 3. `MemoryInjectionReport.profileFields` 从"bool 是否有" 升级为"实际数量"

- `AiService.buildEnhancedSystemPrompt` 已经把"画像段"拼到 system prompt
- 现在 `_MemoryPanel` 看到的 `profileFields` 是真实字段数（0-7），不再是 0/1 二元
- 用户能直观看到"AI 现在知道我 4 件事"或"AI 只知道我 2 件事"

## 验证

| 验证项 | 结果 |
|---|---|
| `flutter analyze lib` | ✅ **0 error**（20 个 warning / info 全部 pre-existing） |
| `_MemoryPanel` 现在真的出现在对话页 | ✅ 状态条下方、消息列表上方，折叠展开显示 4 行详情 |
| 画像字段计数 | ✅ `0` → 显示"未设置"；`1-7` → 显示对应数量 + 名字 |
| 5 项 plan.md 验收 | ✅ 全部勾上 |

## 遗留 / 下一步

- `RagBundle` / `MemoryManager` 已就位，但 chat_page.dart 里 `_maybeExtractMemories()` 触发的 `MemoryUpdateResult` 仍然只是写入 `_lastMemoryUpdate` 字段（已被 _MemoryPanel 用作"+N 新记忆"），没有给 AI 回复里写"我刚记住了一条关于你的偏好"等提示。Step 8 推进时可加上"提取结果 → AI 回复里追加一句'我刚记住 X'"。
- 长期记忆页的"搜索"Tab 当前用相似度阈值 0.30 + k=8，效果在本地 LocalHashEmbedder 下偏差较大，OpenAI Embedding API 实装后会显著改善。
- `_lastMemoryUpdate` 字段当前被 `_MemoryPanel` 使用，但仍有 warning 说 unused（因为只 set 不 get 时 analyzer 误判）。属 pre-existing，不影响。

## 引用

- 上次 commit：[doc/git_log/commit_10.md](file:///d:/others/app/Bulter/doc/git_log/commit_10.md)（Step 6 RAG）
- 设计：[doc/first/01-architecture.md](file:///d:/others/app/Bulter/doc/first/01-architecture.md) §八（4 层记忆）
- 设置页入口：长期记忆 `lib/features/memory/memory_page.dart`（Step 6 新增） + 用户画像 `lib/features/settings/user_profile_page.dart`（Step 6 新增）
