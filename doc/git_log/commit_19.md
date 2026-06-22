# commit_19 — 留底 UI 差异修复（关系主页时间 / 用户名 / 中枢 4 卡布局）

- **版本**：0.9.4
- **commit 类型**：`fix(ui)` + `feat(ui)`
- **影响范围**：Dart 2 文件 + 测试 1 新文件（3 测试）
- **关联文档**：[doc/first/01-architecture.md §5.2](file:///d:/others/app/Bulter/doc/first/01-architecture.md) 主页布局

## 目标

修 3 个留底 UI 差异：

1. **关系主页顶部时间硬编码**（`周一 · 4 月 8 日` → 动态生成）
2. **关系主页用户名硬编码**（`小布` → 从 UserProfile 异步取）
3. **中枢主页卡片数 vs 文档不符**（当前 5 张 → 文档要求 4 张）

## 实施内容

### A. 关系主页（`lib/features/relationship/relationship_home_page.dart`）

#### 修复 1：动态日期
- **原**：硬编码 `'周一 · 4 月 8 日'`
- **新**：
  - 静态 `_weekdays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']`
  - `DateTime.now().weekday % 7` 索引
  - 格式：`'周X · M 月 D 日'`（每次刷新实时生成）

#### 修复 2：动态用户名
- **原**：硬编码 `'小布'`
- **新**：
  - `_userName()` 静态方法 → 调 `AiService.rag?.memory?.userProfile.current().displayName`
  - 用 `FutureBuilder<String>` 异步展示
  - **回退链**：profile 没设 → `'小布'` → 永远不空

### B. 中枢主页（`lib/modules/butler/butler_home_page.dart`）

#### 修复 3：5 卡 → 4 卡
- **原**：`[关系, 成长, 财富, 思想, 健康]` 5 张模块快览卡
- **新**：`[关系, 财富, 思想, 健康]` 4 张（按 [01-architecture.md §5.2](file:///d:/others/app/Bulter/doc/first/01-architecture.md)）
- **理由**：成长模块（OKR / 学习 / 项目）信息密度低、被动浏览价值小，合并到上方 AI 洞察大卡更合理（洞察卡天然跨模块叙事）
- **代码注释**：保留成长卡的位置说明（"成长已被合并到洞察大卡"）

## 验证

| 验证项 | 结果 |
|---|---|
| `flutter analyze lib` | ✅ **0 error** |
| `flutter test test/ui_polish_test.dart` | ✅ **3/3** |
| `flutter test`（全部） | ✅ **68/68** |

## 关键设计决策

### D1：FutureBuilder vs StreamBuilder（用户名）

- **选 FutureBuilder**：用户名在 `UserProfiles` 表里是**单值**（每用户一份），不需要 stream 监听变化
- 优点：实现简单，无需订阅生命周期
- 缺点：用户改名后，关系主页要刷新页面才更新（关系主页每次进入是新建的，OK）

### D2：移除成长卡 vs 保留

- **用户体感**：5 张卡在手机上视觉拥挤；4 张更接近 Cal.com Bento 布局
- **功能定位**：成长是高 active 模块（用户主动用 OKR / 录入学习），不需要被动曝光
- **决策**：严格按文档 4 张。成长入口已在顶部 Tab Bar 的"成长"tab 暴露

### D3：未来如果用户要求 5 张

只需把成长卡**插回**关系 + 财富之间（不需重新设计）：
- 复制原 `_BriefingModuleCard(... moduleId: ModuleId.growth ...)` 整段
- `_openGrowth` 跳转保留即可

## 引用

- 上次 commit：[commit_18.md](file:///d:/others/app/Bulter/doc/git_log/commit_18.md)（Step 13 模块增强）
- 设计：[doc/first/01-architecture.md](file:///d:/others/app/Bulter/doc/first/01-architecture.md) §5.2（中枢主页 4 卡 Bento 布局）
- 设计：[doc/first/01-architecture.md](file:///d:/others/app/Bulter/doc/first/01-architecture.md) §七（设计语言：Cal.com + Clay.com）
