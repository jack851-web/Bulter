# Bulter 代码审查报告（UI / 跳转 / 交互）

- **审查范围**：`src/lib/` 下 36 个 Dart 文件
  - `features/`（16 个 page / form / wizard）
  - `modules/`（6 个 module + 6 个 home_page）
  - `router/`（2 个）
  - `components/`（5 个）
- **审查方法**：grep 模式扫描 + 逐文件精读（form / page 入口 / 跳转调用）
- **审查日期**：commit `4f3b4d9`（Step 13 + 留底 UI 修复后）
- **审查版本**：v0.9.4
- **审查类型**：UI 界面 / 页面跳转 / 界面交互

---

## 🚨 问题汇总（按严重程度）

| 级别 | 数量 | 严重程度 |
|---|---|---|
| **CRITICAL** | 1 | 功能完全失效 |
| **HIGH** | 4 | 明显 UI 缺陷，用户感知强 |
| **MEDIUM** | 4 | 用户可见问题但可绕过 |
| **LOW** | 4 | 小问题或风格不一致 |
| **总计** | **13** | |

---

## 🔴 CRITICAL（1 项）

### C1. [chat_page.dart:378](file:///d:/others/app/Bulter/src/lib/features/chat/chat_page.dart) `pushNamed` 用错跳转 API

**问题**：chat 页面"前往设置"按钮点了没反应。

```dart
void _openModelConfig() {
  Navigator.of(context).pushNamed('/settings/model');  // ❌ 用错 API
}
```

**根因**：路由系统用的是 **go_router**（见 [router.dart:14](file:///d:/others/app/Bulter/src/lib/router/router.dart)），不是 MaterialApp named route。
- `Navigator.pushNamed()` 走 `MaterialApp.routes`（空表）
- `context.pushNamed()` / `GoRouter.of(context).pushNamed()` 走 go_router（`/settings/model` 已注册，[router.dart:21-26](file:///d:/others/app/Bulter/src/lib/router/router.dart)）

**影响**：
- 用户打开 chat → 没配 API Key → 看到"点击前往设置"→ 点击 → **毫无反应**
- 用户困惑；API Key 配置成为"必须手动摸索"的死路

**复现**：
1. 删除 API Key（设置 → 模型 → 清除）
2. 进入 chat（按 FAB）
3. 点击黄色"前往设置" banner

**修复**：
```dart
void _openModelConfig() {
  context.pushNamed('settings.model');  // ✅ GoRouter 扩展
}
```
或者 `GoRouter.of(context).pushNamed('settings.model')`。

---

## 🟠 HIGH（4 项）

### H1. 3 个 home_page **嵌套 Scaffold**（最严重 UI 缺陷）

**问题**：`health_home_page.dart` / `wealth_home_page.dart` / `thought_home_page.dart` 都在内部用了 `Scaffold` + 自带 `FloatingActionButton`，但 `AppShell` 已经提供 Scaffold + FAB。

**涉及文件**：
- [health_home_page.dart:64, 233](file:///d:/others/app/Bulter/src/lib/features/health/health_home_page.dart) — `_RecordsTab` 和 `_ReportsTab` 各自一个 Scaffold
- [wealth_home_page.dart:27, 50](file:///d:/others/app/Bulter/src/lib/features/wealth/wealth_home_page.dart) — 主 Scaffold + 自带 FAB
- [thought_home_page.dart:18, 39](file:///d:/others/app/Bulter/src/lib/features/thought/thought_home_page.dart) — 主 Scaffold + 自带 FAB

**根因**：
- [app_shell.dart:175](file:///d:/others/app/Bulter/src/lib/router/app_shell.dart) — 外层 `Scaffold` + 底部 Tab Bar FAB (`AiChatFab`)
- health/wealth/thought 在 [app_shell.dart:218](file:///d:/others/app/Bulter/src/lib/router/app_shell.dart) `Expanded(child: body)` 里 → 又开了一个 Scaffold + FAB

**影响**（任一项出现）：
1. **双 SnackBar**：数据库错误时弹两次（用户以为系统 bug）
2. **双 FAB**：底部 Tab 的 AI FAB + HomePage 自己的"记一笔"FAB 重叠
3. **MediaQuery padding 错乱**：状态栏高度被双 SafeArea 处理 → 内容下移
4. **嵌套 ScaffoldMessenger**：某些动画撕裂

**复现**：
1. 进入任意模块（关系/财富/思想/健康）
2. 观察右下角：底部 Tab 有"💬" FAB + HomePage 有"记一笔" FAB
3. 触发 SnackBar（如表单提交错误） → 弹两次

**修复**：
- 把 `Scaffold` 改成 `Material` / `Container`
- 把 FAB 移除（或把 AppShell 的 AI FAB 改成模块感知）
- 简单方案：HomePage 的 FAB 调 `Scaffold.of(context)` 注册到外层 Scaffold（不行，会跨 ancestor）→ **必须**删除 HomePage 自己的 Scaffold/FAB

### H2. [growth_home_page.dart:96](file:///d:/others/app/Bulter/src/lib/features/growth/growth_home_page.dart) `第 ${weekday} 周` 逻辑错误

**问题**：
```dart
Text('第 ${DateTime.now().weekday} 周')
```
显示 "第 1 周"~"第 7 周"。但 `DateTime.weekday` 是**星期几**（1=Mon, 7=Sun），不是**本月的第几周**。

**复现**：
- 任意周三打开成长主页 → 显示"第 3 周"
- 用户认知："本月第 3 周？" ❌ 实际是星期三

**修复**：
```dart
// 正确：本月第几周（基于 1 号是周几 + 当前日期）
int weekOfMonth(DateTime d) {
  final firstDay = DateTime(d.year, d.month, 1);
  final offset = firstDay.weekday;  // 1 号是周几
  return ((d.day + offset - 2) ~/ 7) + 1;
}
// 然后：Text('第 ${weekOfMonth(DateTime.now())} 周')
```

### H3. [settings_page.dart:195](file:///d:/others/app/Bulter/src/lib/features/settings/settings_page.dart) 用户卡硬编码 "小明"

**问题**：用户卡片显示名字"小明"、简介"AI 助理 / 经营咖啡馆 / 上海"，**与关系主页**（已动态取 UserProfile.displayName）**不一致**。

**根因**：SettingsPage 是 0.5.0 版本（Step 5），后来关系主页加了 `_userName()` 但 settings_page 没同步。

**修复**：
```dart
// 把 _UserCard 改为 StatefulWidget + FutureBuilder，与关系主页对齐
FutureBuilder<String>(
  future: AiService.rag?.memory?.userProfile.current().then((p) =>
    (p.displayName ?? '').isEmpty ? '小明' : p.displayName!),
  builder: (ctx, snap) => Text(snap.data ?? '小明', ...),
)
```

### H4. 同上：简介硬编码

`settings_page.dart:196` `'AI 助理 / 经营咖啡馆 / 上海'` 同样应从 `UserProfile.bio` 读取。

---

## 🟡 MEDIUM（4 项）

### M1. 所有 form 提交 callback **无 try/catch**

**问题**：所有 `*_home_page.dart` 的 `openAdd*` / 编辑 callback 都是：

```dart
onSubmit: (data) async {
  await AppDatabase.I.xxxDao.insertXxx(data);  // 可能抛异常
  if (context.mounted) Navigator.of(context).pop();
}
```

**涉及**（16 处）：
- relationship_home_page.dart:55
- health_home_page.dart:18, 110
- wealth_home_page.dart:68, 82, 353
- thought_home_page.dart:55, 212, 364
- growth_home_page.dart:45, 59, 263, 319
- contact_detail.dart:98, 113, 128

**影响**：数据库异常（如外键失败 / 字段长度超限）→ 未处理 → form 卡死 + console 报错。

**修复模板**：
```dart
onSubmit: (data) async {
  try {
    await AppDatabase.I.xxxDao.insertXxx(data);
    if (context.mounted) Navigator.of(context).pop();
  } catch (e, st) {
    debugPrint('Form submit failed: $e\n$st');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('提交失败：$e')),
      );
    }
  }
}
```

**更优**：在 form 内部 `_submit()` 包 try/catch → 用 `setState(() => _error = '...')` 显示红色 banner。

### M2. 占位文案暴露给用户

| 位置 | 暴露文案 | 影响 |
|---|---|---|
| [settings_page.dart:91](file:///d:/others/app/Bulter/src/lib/features/settings/settings_page.dart) | `'Step 20 接入'` | 用户："Step 20 是什么？还没做完？" |
| [settings_page.dart:96](file:///d:/others/app/Bulter/src/lib/features/settings/settings_page.dart) | `'Step 20 接入'` | 同上 |
| [health_home_page.dart:261](file:///d:/others/app/Bulter/src/lib/features/health/health_home_page.dart) | `'（暂未启用，敬请期待）'` | 用户：未完成功能明示 |
| [app_shell.dart:650](file:///d:/others/app/Bulter/src/lib/router/app_shell.dart) | `'导出功能 Step 18 接入（数据迁移）'` | 用户：内部版本号泄露 |

**修复**：统一为友好文案：
```dart
subtitle: '即将推出'
// 或
subtitle: '开发中'
```

### M3. settings_page 模型 / API Key 行重复

[settings_page.dart:49-58](file:///d:/others/app/Bulter/src/lib/features/settings/settings_page.dart)：
- "模型" 行 onTap → ModelConfigPage
- "API Key" 行 onTap → **也** → ModelConfigPage

**问题**：用户预期"API Key"行有专门的输入框，实际跳到同一页（ModelConfigPage 里也含 API Key 输入）。

**修复**：
- 方案 A：保留两行（一行显示模型名 + 一行显示 API Key 状态），都跳到 ModelConfigPage → 但加 divider 区分
- 方案 B：合并为一行 "模型与 API Key" subtitle 显示完整状态

### M4. thought_home_page 嵌套 StreamBuilder 性能

[thought_home_page.dart:86-110](file:///d:/others/app/Bulter/src/lib/features/thought/thought_home_page.dart)：`_AiSummaryCard` 嵌套两层 StreamBuilder（thoughts → letters），每次 thoughts 更新重建整个 card。

**修复**：用 `Stream.combineLatest2` 或单独的 service 层聚合。

---

## 🟢 LOW（4 项）

| # | 问题 | 文件 |
|---|---|---|
| L1 | "设置"按钮"模型"行缺 `subtitle` 显示模型厂商细节（只有 `modelStatus`） | [settings_page.dart:51](file:///d:/others/app/Bulter/src/lib/features/settings/settings_page.dart) |
| L2 | contact_detail.dart:280 `Navigator.maybePop()` 在 onTap 异步外调，可优化为 `mounted` 检查 | [contact_detail.dart:280](file:///d:/others/app/Bulter/src/lib/features/relationship/contact_detail.dart) |
| L3 | thought_home_page.dart:18-19 自己 Scaffold + FAB 双 FAB（H1 的子集） | [thought_home_page.dart](file:///d:/others/app/Bulter/src/lib/features/thought/thought_home_page.dart) |
| L4 | relationship_home_page.dart:57 form 提交后只 pop，没刷新 list（但 StreamBuilder 自动刷新，OK） | [relationship_home_page.dart:57](file:///d:/others/app/Bulter/src/lib/features/relationship/relationship_home_page.dart) |

---

## ✅ 验证

| 验证项 | 结果 |
|---|---|
| `flutter analyze lib` | ✅ **0 error** |
| `flutter test`（全部） | ✅ **68/68** |

---

## 🎯 修复优先级建议

| 优先级 | 任务 | 工作量 | 影响 |
|---|---|---|---|
| **P0 立即** | 修 C1（chat 跳转失效） | 5 分钟 | 阻塞功能 |
| **P1 本周** | 修 H1（嵌套 Scaffold） | 2 小时 | 全局 UI 缺陷 |
| **P1 本周** | 修 H2（weekday 逻辑） | 5 分钟 | 显示错误 |
| **P2 下周** | 修 H3 + H4（用户名/简介硬编码） | 1 小时 | 用户体验 |
| **P2 下周** | 修 M2（占位文案） | 30 分钟 | 暴露内部版本 |
| **P3 后续** | 修 M1（try/catch） | 3 小时 | 错误恢复（可一次性 PR） |
| **P3 后续** | 修 M3 / M4 / L* | 各 30 分钟 | 视觉一致性 |

**总工作量估算**：P0-P2 约 4 小时；P3 约 4 小时。

---

## 📝 设计观察（不属于 bug）

### 路由架构
- **GoRouter + Navigator 混用**：当前有 5 处跳转，**4 处**用 `context.pushNamed()`（go_router），**1 处**用 `Navigator.pushNamed()`（chat_page，**错了**）
- **未来**：建议在 `lib/router/nav.dart` 封装统一跳转函数 `AppNav.openModelConfig(context)` 等，避免 API 混用

### Form 提交流程
- 16 个 form callback 全部重复相同模式（try/catch + mounted 检查 + pop）
- **未来**：可统一 `FormHelper.submit<T>(context, dao, buildCompanion, onSuccess)` 收口

### AppShell 嵌套策略
- 当前设计：AppShell 提供 Scaffold + Tab Bar + FAB；模块主页**应**只放内容
- **当前现状**：3 个 home_page 违反该约定（自带 Scaffold/FAB）
- **修复方向**：删除 HomePage 内的 Scaffold/FAB，让 AppShell 的 FAB **根据模块上下文**切换为模块的 quickAdd

---

## 🔗 相关引用

- 路由：[lib/router/router.dart](file:///d:/others/app/Bulter/src/lib/router/router.dart) / [lib/router/app_shell.dart](file:///d:/others/app/Bulter/src/lib/router/app_shell.dart)
- AppShell：[lib/router/app_shell.dart:175-225](file:///d:/others/app/Bulter/src/lib/router/app_shell.dart)
- 通用 Scaffold：[lib/components/bulter_scaffold.dart](file:///d:/others/app/Bulter/src/lib/components/bulter_scaffold.dart)
- 设计文档：[doc/first/01-architecture.md §5.2](file:///d:/others/app/Bulter/doc/first/01-architecture.md)（主页布局）
- 上次审查：[doc/code-quality/code_review_report_1.md](file:///d:/others/app/Bulter/doc/code-quality/code_review_report_1.md)
