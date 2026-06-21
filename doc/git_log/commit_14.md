# commit_14 — 简报系统（Step 9）

- **版本**：0.8.0（首页接入真实 AI 简报，0.7.1 向后兼容）
- **commit 类型**：`feat(ai)` / `feat(briefing)` / `feat(ui)` / `feat(storage)`
- **影响范围**：5 个新文件 + 1 个改造文件
- **关联计划**：[plan.md §第 9 步](file:///d:/others/app/Bulter/doc/first/plan.md) 6 项验收全部勾选

## 目标

把首页从"硬编码 mock 文案"升级为"真实 AI 生成的简报驱动"：

1. **5 个模块**有独立简报（关系/成长/财富/思想/健康），调对应子 Agent 生成
2. **中枢简报**聚合 5 个子模块的"待决定"汇总
3. **三层存储**：内存 `ValueNotifier`（UI 零延迟）+ Drift `briefings` 表（持久化）+ Hive `bulter_briefings` Box（冷启动加速）
4. **新鲜度**：每条简报有 TTL（默认 86400s），UI 显示"X 分钟前"或"过期"
5. **降级路径**：子模型失败 → fallback "（暂无简报）"，UI 永不崩

## 实施内容

### 1. [briefing_models.dart](file:///d:/others/app/Bulter/src/lib/ai/briefing/briefing_models.dart) — 数据模型

- `BriefingPeriod` enum: `daily / weekly / monthly / yearly / ondemand`，含 `label` + `storageKey`（持久化）
- `BriefingChip` class: `label / value`（关系模块用："待联系 2 位"）
- `ModuleBriefing` class:
  - `headline` (≤18字) + `summary` (≤40字) + `chips` (最多 3 个)
  - `isStale()` 内置 TTL 判断
  - `freshnessLabel()` 人类可读："刚刚 / X 分钟前 / X 小时前 / X 天前 / 很久前"
  - `toJson() / fromJson()` 可序列化
  - `fallback()` 工厂：子模型失败时用，保证 UI 永远有内容

### 2. [hive_boxes.dart](file:///d:/others/app/Bulter/src/lib/ai/briefing/hive_boxes.dart) — Hive 辅助

打开 `bulter_briefings` Box（key = moduleId, value = JSON 字符串），单例模式。

### 3. [briefing_store.dart](file:///d:/others/app/Bulter/src/lib/ai/briefing/briefing_store.dart) — 三层存储

```
内存 ValueNotifier<ModuleBriefing?>  ← UI 订阅（ValueListenableBuilder）
       ↓
Drift briefings 表                  ← 持久化（重启不丢）
       ↓
Hive bulter_briefings Box           ← 冷启动加速（避免 SQL 查询）
```

- `watchBriefing(moduleId)` → `ValueListenable<ModuleBriefing?>`，UI 订阅零延迟
- `save(b)` → 三层同步写（fail-soft：Hive 失败不阻塞 Drift 成功）
- `init()` → 打开 Hive Box + 从 Drift 加载缓存到内存（应用启动时调）
- `refresh()` → 手动重新从 Drift 加载（开发者工具 / 测试用）

### 4. [briefing_generator.dart](file:///d:/others/app/Bulter/src/lib/ai/briefing/briefing_generator.dart) — 简报生成

复用 Step 8 的 `Orchestrator.invokeSubAgent` 调子 Agent：

- `generate(moduleId)` → 调子模型 + 解析 JSON → `ModuleBriefing`
- `generateAll()` → 并行调 5 个业务模块
- `generateButler()` → 中枢：先 `generateAll()` 拿 5 个子模块，再**用主模型生成器在 Dart 层聚合**（headline = "今天 X 件待决定"，summary = 3 条最有信号子模块摘要，chips = 前 3 个最紧急 chip）

**JSON 容错策略**：
- 标准 JSON `{"headline":..., "summary":..., "chips":[...]}`
- 含 `` ```json `` 围栏 → 剥离
- 含 `{ ... }` 块 → 抽出
- 任意失败 → `ModuleBriefing.fallback(moduleId)`（不抛错）

**失败降级**：子模型超时 / LLM 错误 / 解析失败 → `ModuleBriefing.fallback(moduleId, headline: _fallbackHeadline(moduleId))`，UI 永远有内容。

### 5. [briefing_scheduler.dart](file:///d:/others/app/Bulter/src/lib/ai/briefing/briefing_scheduler.dart) — 调度器

**不依赖 workmanager**（避免新增原生依赖）：

- `start()` → 启动 `Timer.periodic(1分钟)` 心跳 + 启动后立即 `_tick()` 一次
- `_tick()` → 检查每个模块简报，`null / isStale()` → 异步 `refreshNow()`
- `refreshNow(moduleId)` → 用户点 "刷新" 时手动触发（带 `_inflight` 防并发）
- `refreshAll()` → 5 个模块并行 + 中枢串行聚合

### 6. [butler_home_page.dart](file:///d:/others/app/Bulter/src/lib/modules/butler/butler_home_page.dart) — 中枢主页改造

| 元素 | 改造前 | 改造后 |
|---|---|---|
| `_Greeting` 副标题 | 硬编码 "今天 3 件事待已入栈" | `ValueListenableBuilder` 订阅 butler briefing 的 `summary` |
| `_ButlerInsight` 大卡 | 硬编码 "Butler · 今日 / 今天有 3 件事无法被你决定" | 订阅 butler briefing 的 `headline / summary / chips`，顶部显示"更新于 X 分钟前"或"过期" |
| 5 张模块卡 | 硬编码 `_ModuleCard(headline, subtitle, chips)` | `_BriefingModuleCard` 订阅各模块 briefing，有则用、否则用 fallback 静态文案 + "过期"标记 |

### 7. [app_bootstrap.dart](file:///d:/others/app/Bulter/src/lib/app_bootstrap.dart) — 启动流程接入

```dart
// 5. 简报系统初始化（Step 9）
await BriefingStore.instance.init();  // 打开 Hive + 从 Drift 加载
BriefingScheduler.instance.start();   // 1 分钟心跳
```

启动后用户立刻能看到：
- 老用户的缓存简报（从 Drift）
- 新用户的"正在汇总今日简报…"占位（Scheduler 立即触发一次）

## 验证

| 验证项 | 结果 |
|---|---|
| `flutter analyze lib` | ✅ **0 error**（26 个 warning / info 全部 pre-existing `unused_import` 或 `withOpacity`） |
| `flutter test test/dao_crud_test.dart` | ✅ **10/10** 通过 |
| `flutter test test/data_export_test.dart` | ✅ **3/3** 通过 |
| plan.md §第 9 步 6 项验收 | ✅ 全部勾选 |
| 中枢主页订阅 BriefingStore | ✅ `_Greeting` + `_ButlerInsight` + 5 张 `_BriefingModuleCard` 全部 `ValueListenableBuilder` 订阅 |
| 子模型失败降级 | ✅ `ModuleBriefing.fallback(moduleId)` + `_fallbackHeadline` 兜底 |
| 三层存储一致性 | ✅ save() 同时写内存 / Drift / Hive；init() 从 Drift 加载 + 从 Hive 冷启动 |
| 1 分钟心跳 | ✅ `_timer = Timer.periodic(Duration(minutes: 1), _tick)` |

## 关键设计决策

### D1：不依赖 workmanager

考虑过 Android `WorkManager` + iOS `BGAppRefreshTask`，但代价：
- 增加原生依赖（platform channel 复杂度）
- 增加 CI / 构建时间
- 用户看到 App 后台暂停更省电

Flutter Timer 在前台运行 OK，后台被 OS 暂停**符合预期**（用户看不到就不消耗资源）。
1 分钟粒度也够细——首页打开时 `app_bootstrap` 立即 `_tick()` 一次。

### D2：中枢简报不在子模型中聚合

考虑过让中枢简报用主模型（Orchestrator 不调子 Agent）来"读 5 个模块的 briefing → 生成跨模块叙事"。
但当前 LLM 一次 context 长度有限（DeepSeek 16k context 内），传 5 个完整 briefing JSON + 中枢 system prompt 也够。
当前实现用 Dart 层逻辑（headline = 计数，summary = 前 3 条，chips = 前 3 个），简单可靠。

**后续优化**：如果将来中枢要"基于 RAG 检索 + 5 个 briefing → 自然语言叙事"，再让中枢调主模型。当前够用。

### D3：Hive Box 只用 key-value 字符串

不存复杂对象（避免 `TypeAdapter` 升级复杂度）。
冷启动时 Hive 已经有了"昨天的简报"，Drift 已经有完整历史，UI 同时订阅两层不重复。

### D4：简报卡片标题不依赖 LLM 总结

每张 `_BriefingModuleCard` 仍有 `fallbackHeadline`（硬编码文案）。
原因：用户第一次打开 App 时（无 LLM 调用历史、无数据），fallback 立即渲染；等子模型异步生成完，再切换到 LLM 生成的真实简报。**零白屏**。

## 遗留 / 下一步

- **简报历史 / 归档**：当前只保留每个模块最新一条简报。下一步可以在中枢主页加 "查看历史" 入口，调 `dbInst.aiDao.watchBriefingsFor(moduleId)` 显示时间倒序列表。
- **briefing_generator 直接调主模型生成中枢简报**：当前用 Dart 层聚合；下一步可以让中枢 briefing 调主模型（复用 Step 8 的 `Orchestrator` 但跳个子 Agent 模式）生成自然语言汇总。
- **简报推送通知**：当前只在 App 内显示；下一步可以接 local_notifications 在 23:00 推送"今日简报已生成"。
- **briefing TTL 策略**：当前 86400s（1 天）。下一步可以让 weekly / monthly 用更长 TTL（604800 / 2592000）。

## 引用

- 上次 commit：[commit_13.md](file:///d:/others/app/Bulter/doc/git_log/commit_13.md)（Step 8.1 顶栏 UI 修正）
- 设计：[doc/first/01-architecture.md](file:///d:/others/app/Bulter/doc/first/01-architecture.md) §六（简报系统）
- 计划：[doc/first/plan.md](file:///d:/others/app/Bulter/doc/first/plan.md) §第 9 步
- 协议：[doc/first/03-tech.md](file:///d:/others/app/Bulter/doc/first/03-tech.md) §六（数据流）+ §八（4 层记忆）
