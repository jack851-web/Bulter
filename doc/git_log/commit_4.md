# commit_4 — 六大业务模块基础 CRUD UI（Step 3）

- **版本**：0.3.0（新增功能，向后兼容）
- **commit 类型**：`feat(features)` / `feat(form)` / `feat(db)`
- **影响范围**：关系 / 成长 / 财富 / 思想 / 健康 五大业务模块 + 共享表单组件库
- **关联计划**：[plan.md §第 3 步](file:///d:/others/app/Bulter/doc/first/plan.md)

## 目标

为关系 / 成长 / 财富 / 思想 / 健康 五大业务模块打通「手动录入」路径 C：列表 → 详情 → 新增 / 编辑 / 删除，整套 UI 与数据流闭环。

## 实施内容

### 1. 共享表单组件 `lib/features/form/`

抽出 9 个可复用 widget，让所有模块的表单样式统一、交互一致：

| 文件 | 作用 |
|---|---|
| `text_field_card.dart` | 卡片样式的标准文本输入（标签 / 占位 / 错误）|
| `chips_input.dart` | 多标签输入 + 与 JSON 互转工具 |
| `date_picker_field.dart` | 日期（可选含时间）选择器 |
| `amount_input.dart` | 金额输入，内部以"分"存储 + 千分位格式化；新增 `errorText` |
| `rating_input.dart` | 1-5 星评分 |
| `integer_input.dart` | 整数输入，可配 min/max |
| `choice_chips_field.dart` | 单选胶囊选择器 |
| `confirm_dialog.dart` | 通用确认弹窗 |
| `stream_list_view.dart` | 基于 Drift Stream 的列表骨架（加载 / 空 / 错误状态）+ `ListCard` 行容器 |

### 2. 五大业务模块

| 模块 | 主页 | 表单 |
|---|---|---|
| 关系 | `relationship_home_page.dart`（概览 + 联系人列表）| `contact_form.dart` / `interaction_form.dart` / `favor_form.dart` + 详情页 `contact_detail.dart`（Tab 切换"互动 / 人情"）|
| 成长 | `growth_home_page.dart`（Tab 切换"目标 / 学习"）| `goal_form.dart` / `learning_form.dart` |
| 财富 | `wealth_home_page.dart`（顶部余额总览 + Tab 切换"账户 / 流水"）| `account_form.dart` / `transaction_form.dart` |
| 思想 | `thought_home_page.dart`（Tab 切换"想法 / 信件"）| `thought_form.dart` / `letter_form.dart` |
| 健康 | `health_home_page.dart`（Tab 切换"记录 / 体检报告"）| `health_form.dart`（类别自动切换强度 / 时长 / 数值字段）|

### 3. 模块入口改造

- `relationship_module.dart` / `growth_module.dart` / `wealth_module.dart` / `thought_module.dart` / `health_module.dart` 的 `buildHomePage` 全部改为直接返回对应 `*_home_page.dart`。
- 移除对旧 `ModulePlaceholderPage` 的依赖（占位特性清单仅作内部信息保留在 plan.md 中）。

### 4. DAO 增补

各模块 DAO 增补 update / 列表 watch 方法，**保持原有表结构与字段不变**：

- `RelationshipDao`：`updateContact`、`watchContact(id)`
- `GrowthDao`：`updateGoal`、`updateLearning`、`deleteLearning`
- `WealthDao`：`updateAccount`
- `ThoughtDao`：`updateThought`、`updateLetter`
- `HealthDao`：`updateRecord`

## 验证

| 验证项 | 结果 |
|---|---|
| `flutter analyze` | ✅ 0 error（1 warning + 5 info，皆为非阻塞的格式建议）|
| `flutter test` | ✅ 26/26 通过 |
| 数据闭环 | ✅ 新建 → 列表显示 → 详情 → 编辑 → 删除（Drift Stream 实时刷新）|
| 删除二次确认 | ✅ 5 模块均使用统一 `AlertDialog` |
| 空状态插画 + 引导文案 | ✅ 5 模块首页空状态均带图标 + 提示语 |
| 品牌色 | ✅ 各模块卡片 / FAB / Tab Indicator 全部使用 `BulterColors.{module}` 品牌色 |

## 后续

- Step 4 起进入 AI 调用基础（单 LLM 流式对话）。
- 浮窗截图 + AI 对话两条输入路径（路径 A / B）将在 Step 5（工具系统）后接入。
- `dart fix --apply` 可在未来一次性消除 `unused_underscores` 等 5 条 info 级别提示。
