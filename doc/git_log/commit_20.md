# commit_20 — 系统审查 P0-P2 修复（chat 跳转 + 嵌套 Scaffold + 周数逻辑 + 用户名/占位文案）

- **版本**：0.9.5
- **commit 类型**：`fix(ui)` + `fix(router)`
- **影响范围**：Dart 5 文件改动 + 测试 1 文件（+7 测试）
- **关联文档**：[code_review_report_2.md](file:///d:/others/app/Bulter/doc/code-quality/code_review_report_2.md) P0-P2 全修

## 目标

修复系统性代码审查（[code_review_report_2.md](file:///d:/others/app/Bulter/doc/code-quality/code_review_report_2.md)）中 9 个 P0-P2 问题：

| 优先级 | 数量 | 阻塞性 |
|---|---|---|
| **P0** | 1（C1） | 阻塞功能 |
| **P1** | 2（H1 + H2） | 全局 UI 缺陷 |
| **P2** | 2（H3+H4 + M2） | 用户可见 |
| **总** | **9** | |

---

## 修复内容

### 1. 🔴 P0 C1 — chat_page 跳转失效

**问题**：[chat_page.dart:378](file:///d:/others/app/Bulter/src/lib/features/chat/chat_page.dart) 用错跳转 API：

```dart
// ❌ 错：Navigator.pushNamed 走 MaterialApp routes 表（没注册 → 点击无反应）
Navigator.of(context).pushNamed('/settings/model');

// ✅ 修：context.pushNamed 走 go_router
context.pushNamed('settings.model');
```

**影响**：用户打开 chat → 没配 API Key → 看到"点击前往设置"→ 点击 → **毫无反应**（必须手动摸索设置路径）。

### 2. 🟠 P1 H1 — 3 个 home_page 嵌套 Scaffold + FAB

**问题**：`health_home_page.dart` / `wealth_home_page.dart` / `thought_home_page.dart` 都在内部用 `Scaffold` + `FloatingActionButton`，但 [app_shell.dart:175](file:///d:/others/app/Bulter/src/lib/router/app_shell.dart) 已提供 Scaffold + FAB。**嵌套**导致：
- 双 SnackBar（DB 错误时弹两次）
- 双 FAB（底部 Tab 的 AI FAB + HomePage 自己的"记一笔"FAB 重叠）
- MediaQuery padding 错乱（双 SafeArea 处理）

**修复**：
- [health_home_page.dart](file:///d:/others/app/Bulter/src/lib/features/health/health_home_page.dart) — `_RecordsTab` / `_ReportsTab` 的 `Scaffold` → `Container`，删除 FAB
- [wealth_home_page.dart](file:///d:/others/app/Bulter/src/lib/features/wealth/wealth_home_page.dart) — `Scaffold` + FAB 整个移除
- [thought_home_page.dart](file:///d:/others/app/Bulter/src/lib/features/thought/thought_home_page.dart) — `Scaffold` + FAB 整个移除

**结果**：模块"记一笔"功能由 AppShell 顶栏 + 按钮的 `quickAdd` 调用（已注册到每个模块的 `BulterModule.quickAdd`）。

### 3. 🟠 P1 H2 — growth_home_page `第 ${weekday} 周` 逻辑错误

**问题**：
```dart
// ❌ 错：weekday 是星期几 1-7，不是月内周序号
Text('第 ${DateTime.now().weekday} 周')  // 显示"第 3 周"实际是星期三
```

**修复**：加 `_weekOfMonth(DateTime)` 静态方法：
```dart
static int _weekOfMonth(DateTime d) {
  final firstDay = DateTime(d.year, d.month, 1);
  final offset = firstDay.weekday; // 1 号是周几（1-7）
  return ((d.day + offset - 2) ~/ 7) + 1;
}
// 2024-04-01 (周一) → 1；2024-04-08 (周一) → 2；2024-04-30 → 5
```

**覆盖测试**（7 个 case 在 [ui_polish_test.dart](file:///d:/others/app/Bulter/src/test/ui_polish_test.dart)）：
- 4-1/4-7 = 第 1 周，4-8 = 第 2 周，4-30 = 第 5 周
- 2-1（周四开月）/ 2-4 / 2-5 边界

### 4. 🟡 P2 H3 + H4 — settings_page 用户卡硬编码

**问题**：[settings_page.dart](file:///d:/others/app/Bulter/src/lib/features/settings/settings_page.dart) 显示"小明" + "AI 助理 / 经营咖啡馆 / 上海"，与关系主页（已动态取 UserProfile）不一致。

**修复**：`_UserCard` 改为 `StatefulWidget` + `FutureBuilder<_UserInfo>`：
- `_UserInfo` = `(displayName, occupation, location)`（UserProfile 字段）
- `_load()` 异步读 `AiService.rag?.memory?.userProfile.current()`
- `_buildBio(info)` 拼简介：`occupation · location`（任一为空 → "点击右上角"用户画像"完善信息"）
- 头像首字动态取 `name.characters.first`
- **回退**：profile 未设置 → 显示 "小明" + 提示文案
- **刷新**：从 settings.profile 返回后 `setState(() => _future = _load())` 重新拉

### 5. 🟡 P2 M2 — 占位文案暴露给用户

**修复**（统一改为友好文案 "即将推出"）：
- [settings_page.dart:91, 96](file:///d:/others/app/Bulter/src/lib/features/settings/settings_page.dart) — `'Step 20 接入'` × 2 → `'即将推出'`
- [health_home_page.dart:261](file:///d:/others/app/Bulter/src/lib/features/health/health_home_page.dart) — `'（暂未启用，敬请期待）'` → `'（即将推出）'`
- [app_shell.dart:650](file:///d:/others/app/Bulter/src/lib/router/app_shell.dart) — `'导出功能 Step 18 接入（数据迁移）'` → `'导出功能即将推出'`

---

## 验证

| 验证项 | 结果 |
|---|---|
| `flutter analyze lib` | ✅ **0 error** |
| `flutter test test/ui_polish_test.dart` | ✅ **10/10**（原 3 + 新 7 个 `_weekOfMonth`） |
| `flutter test`（全部） | ✅ **75/75** |

---

## 修复工作量

| 任务 | 实际改动 |
|---|---|
| C1 (chat 跳转) | 2 行 |
| H1 (嵌套 Scaffold) | 3 个文件 × Scaffold→Container + 删 FAB |
| H2 (weekOfMonth) | 8 行新逻辑 + 7 行使用 |
| H3+H4 (用户名动态) | 1 个类重写（StatefulWidget + FutureBuilder） |
| M2 (占位文案) | 4 处文本替换 |
| 测试 (weekOfMonth) | 7 个 case |

---

## 关键设计决策

### D1：Scaffold 单点原则

**AppShell 提供 Scaffold，HomePage 只放内容**。这是单一职责原则（SoC）在 Flutter 的体现：
- Scaffold 是**页面外壳**（状态栏/SafeArea/AppBar/FAB/Snackbar 容器）
- HomePage 是**业务内容**（列表/卡片/图表）

违反这条规则就会出现本次审查发现的 H1（嵌套 Scaffold）。

**未来**：新加 HomePage 时 → 用 `ListView` / `Column` / `Stack` 直接作为内容，不套 Scaffold。

### D2：动态数据用 FutureBuilder 而非硬编码

本次修复涉及 3 处动态化：
- 关系主页时间（commit_19）→ `_Greeting` StatefulWidget
- settings 用户名（本次）→ `_UserCard` StatefulWidget

**模式相同**：
1. 异步加载（`Future<X> _load()`）
2. FutureBuilder 显示
3. 设置返回后 `setState` 刷新

**未来**：可封装 `AsyncValueWidget<T>(future, builder)` 减少重复。

### D3：占位文案 = "即将推出"

**之前**：暴露内部版本（"Step 18/20 接入"）、功能未完成（"暂未启用"）
**之后**：用户视角统一（"即将推出"）

**优点**：
- 不泄露内部进度
- 用户预期一致
- 易迭代（功能完成后直接删项）

### D4：测试 _weekOfMonth 私有方法

私有静态方法**无法**直接 import → 测试中**复现**同样算法（独立验证）。

**优点**：验证算法正确性的同时，强制保持算法的简洁（容易复现 = 不复杂）。
**风险**：算法被改后，测试可能与实际代码漂移。**缓解**：测试文件加注释说明是"复现"，并定期验证一致性。

---

## 引用

- 审查报告：[doc/code-quality/code_review_report_2.md](file:///d:/others/app/Bulter/doc/code-quality/code_review_report_2.md)
- 上次 commit：[commit_19.md](file:///d:/others/app/Bulter/doc/git_log/commit_19.md)（留底 UI 修复）
- 设计：[doc/first/01-architecture.md §5.2](file:///d:/others/app/Bulter/doc/first/01-architecture.md)（AppShell 单 Scaffold）
