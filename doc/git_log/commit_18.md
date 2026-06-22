# commit_18 — Step 13 模块增强（OKR / 月度账单 / 给未来的信 / 综合健康分 / 约定管理）

- **版本**：0.9.3
- **commit 类型**：`feat(modules)` + `feat(db)` + `fix(csv)`
- **影响范围**：Dart 7 新文件 + DAO 2 改造 + 表 1 新增 + 测试 1 新文件
- **关联文档**：[doc/first/plan.md §第 13 步](file:///d:/others/app/Bulter/doc/first/plan.md) 业务层全部完成

## 目标

5 个业务模块补齐核心业务逻辑：

| 模块 | 范围 |
|---|---|
| **成长** | OKR 管理（KR 拆解 + 进度计算 + 季度） |
| **财富** | 月度账单（聚合 + 与上月对比 + 预算超支检测） |
| **思想** | 给未来的信（日期锁定 + 自动解锁）+ 年度回顾（按年汇总 + 关键词提取） |
| **健康** | 综合健康分（多指标 profile + 加权汇总 + 异常高亮） |
| **关系** | 约定管理（Promises 表 + 到期提醒检测） |

## 实施内容

### A. 数据库扩展（schemaVersion 3 → 4）

#### 🆕 [lib/modules/relationship/db/relationship_tables.dart](file:///d:/others/app/Bulter/src/lib/modules/relationship/db/relationship_tables.dart) 改造

加 `Promises` 表（约定）：
- `contactId`（FK，nullable）
- `title` / `description` / `dueAt`
- `priority`（low / normal / high）
- `status`（pending / fulfilled / broken / cancelled）
- `reminded`（避免重复推送）

#### 🔧 [lib/db/app_database.dart](file:///d:/others/app/Bulter/src/lib/db/app_database.dart) 改造

- `schemaVersion`: 3 → 4
- `onUpgrade(from < 4)` → `createTable(promises)`

### B. 业务服务（7 新文件）

#### 1. 🆕 [lib/modules/growth/services/okr_service.dart](file:///d:/others/app/Bulter/src/lib/modules/growth/services/okr_service.dart)

**OKR 管理**：
- `parseKRs(json)` → List\<KeyResult\>（JSON → 结构化）
- `calcProgress(krs)` → 平均进度（0-100）
- `updateKrProgress(...)` → 单条 KR 更新 + 自动重算 OKR 整体
- `addKr(...)` / `removeKr(...)` → KR CRUD
- `quarterOkrs(...)` / `currentQuarter()` → 季度管理

#### 2. 🆕 [lib/modules/wealth/services/monthly_report_service.dart](file:///d:/others/app/Bulter/src/lib/modules/wealth/services/monthly_report_service.dart)

**月度账单**：
- `generate(year, month)` → `MonthlyReport`（收入 / 支出 / 净额 / 分类分布 / 与上月对比 / 预算超支）
- `recentMonths(months: 6)` → 趋势图数据
- `MonthlyReport.expenseChangePct` → 与上月百分比
- `BudgetAlert.overRatio` → 超支比例

#### 3. 🆕 [lib/modules/thought/services/letter_service.dart](file:///d:/others/app/Bulter/src/lib/modules/thought/services/letter_service.dart)

**给未来的信**：
- `writeLetter(...)` → 创建（含 targetDate）
- `listLetters(...)` → **核心**：每次重新计算锁定状态；到期自动标 `openedAt`
- `forceUnlock(...)` → 强制解锁
- `LockedLetter.daysUntilUnlock` → 倒计时

#### 4. 🆕 [lib/modules/thought/services/annual_review_service.dart](file:///d:/others/app/Bulter/src/lib/modules/thought/services/annual_review_service.dart)

**年度回顾**：
- `generate(year)` → `AnnualReviewSummary`（总数 / 按 source / 按月分布 / 关键词）
- `persist(...)` → upsert 到 `AnnualReviews` 表
- `_tokenize(s)` → 中英文分词（regex）
- `_stopWords` → 中文 + 英文停用词

#### 5. 🆕 [lib/modules/health/services/metric_normalizer.dart](file:///d:/others/app/Bulter/src/lib/modules/health/services/metric_normalizer.dart)

**指标归一化器**：
- 5 种内置 profile：weight / BMI / sleep_hours / steps / resting_heart_rate
- `assess(record)` → 单条评分（score / severity）
- `aggregateBatch(records)` → 加权汇总到综合分
- `MetricAssessment.isAbnormal` → 异常判断
- `HealthAggregate.dimensionScores` → 维度拆分

#### 6. 🆕 [lib/modules/health/services/health_score_service.dart](file:///d:/others/app/Bulter/src/lib/modules/health/services/health_score_service.dart)

**综合健康分**：
- `computeAndSave(...)` → 取最近 30 天 → 评分 → 保存到 `HealthScores` 表
- `HealthScore.grade` → A/B/C/D/E 等级

#### 7. 🆕 [lib/modules/relationship/services/promise_service.dart](file:///d:/others/app/Bulter/src/lib/modules/relationship/services/promise_service.dart)

**约定管理**：
- `create(...)` → 创建（含 dueAt / contactId / priority）
- `pendingReminders(...)` → 未来 24 小时待提醒
- `markReminded(...)` / `markAllReminded(...)` → 避免重复推
- `fulfill(...)` / `cancel(...)` → 状态流转

### C. DAO 改造

#### 🔧 [lib/modules/relationship/db/relationship_daos.dart](file:///d:/others/app/Bulter/src/lib/modules/relationship/db/relationship_daos.dart)

- `@DriftAccessor(tables: [Contacts, Interactions, Favors, Promises])` — 加 Promises
- 加 5 个 Promise 方法：`insertPromise` / `updatePromise` / `deletePromise` / `watchPendingPromises` / `promisesDueSoon` / `markPromisedAsReminded` / `fulfillPromise`

### D. CSV pre-existing bug 修复

#### 🔧 [lib/features/csv_import/csv_import_wizard.dart](file:///d:/others/app/Bulter/src/lib/features/csv_import/csv_import_wizard.dart)

- `FilePicker.platform.pickFiles(...)` → `FilePicker.pickFiles(...)`（file_picker 11.x API 变更）
- `BulterColors.accent` → `BulterColors.butler`（不存在 accent 字段）

### E. 测试

#### 🆕 [test/step13_module_enhance_test.dart](file:///d:/others/app/Bulter/src/test/step13_module_enhance_test.dart)

**14 个测试**：
- OkrService（parseKRs / calcProgress / currentQuarter / KeyResult.copyWith）
- MetricNormalizer（正常 / 超出 / 警告 / 未知 / aggregate 加权 / 异常计数）
- AnnualReviewService（空年份）

## 验证

| 验证项 | 结果 |
|---|---|
| `flutter analyze lib` | ✅ **0 error** |
| `flutter test test/step13_module_enhance_test.dart` | ✅ **14/14** 通过 |
| `flutter test`（全部） | ✅ **65/65** 通过 |
| schemaVersion 升级（3→4） | ✅ `onUpgrade(from<4)` 建 promises 表 |

## 关键设计决策

### D1：业务服务 vs DAO

- **DAO** 只负责表 CRUD（无业务逻辑）
- **Service** 负责业务逻辑（KR 计算 / 月度聚合 / 锁定判断 / 评分）

**为什么不放 DAO**：测试友好（service 是纯函数 + db 参数，可 mock db）；复用友好（service 可被多个调用方共享）。

### D2：信件锁定 = 每次重新计算

信件 `targetDate` 是数据，**不**缓存锁定状态。每次 `listLetters` 都遍历 + 比较当前时间：
- 未到 → 返回 locked + 倒计时
- 已到 + 首次打开 → 写 `openedAt`

**优点**：用户时钟不准也能正确解锁；无需定时任务。

### D3：综合健康分 = 加权 + 多 profile

每个 metric_name 映射到一个 [MetricProfile]（normalLow / normalHigh / penaltyPerUnit）。**单条评分** → **维度平均** → **维度间平均**。

**优点**：扩展性好（加新指标 = 加新 profile）；不依赖 LLM（纯规则）。

### D4：约定提醒 = 轮询检测 + `reminded` 防重

`pendingReminders()` 每次返回未来 24 小时 **未提醒** 的约定。推送后调 `markAllReminded()` 标记。

**为什么不用 cron / 推送服务**：避免引入原生依赖；用户打开 App 时自动检测；`reminded` 字段防重推。

## 引用

- 上次 commit：[commit_17.md](file:///d:/others/app/Bulter/doc/git_log/commit_17.md)（Step 12 CSV 导入）
- 设计：[doc/first/01-architecture.md](file:///d:/others/app/Bulter/doc/first/01-architecture.md) §七（模块业务层）
- 计划：[doc/first/plan.md](file:///d:/others/app/Bulter/doc/first/plan.md) §第 13 步
