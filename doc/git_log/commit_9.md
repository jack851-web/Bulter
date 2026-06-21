# commit_9 — 修复首页 hardcode 与子模块显示空白

- **版本**：0.5.2（缺陷修复）
- **commit 类型**：`fix(ui)` / `refactor(modules)`
- **影响范围**：Butler 中枢主页 / 5 个业务模块（关系 / 成长 / 财富 / 思想 / 健康）

## 问题现象

在中枢页实测发现 3 个具体问题：

1. **首页问候语错乱**：上方用 `DateTime.now().hour` 算出"中午好"，下方却 hardcode "下午好，小明"，两行时间不一致（用户截图：12:05 同时显示"中午好"和"下午好，小明"）。
2. **切换到子模块全空白**：从顶部胶囊切到关系 / 成长 / 财富 / 思想 / 健康任一模块，body 区完全没内容（只剩底部 4 个 tab），4 个 tab 都是 `SizedBox.shrink()`。
3. **首页卡片点进去看不到内容**：根因同 #2 — 5 张模块卡点进去后落到子模块，但子模块被空 tab 占据了。

## 根因

`lib/router/app_shell.dart` 的 body 选择逻辑：

```dart
final body = hasTabs
    ? IndexedStack(
        index: _tabIndex.clamp(0, tabs.length - 1),
        children: tabs.map((t) => t.builder(context)).toList(),  // ← 全是 _placeholder
      )
    : active.buildHomePage(context);
```

只要模块的 `tabs` 字段非空，AppShell 就走 IndexedStack 渲染 4 个 `SizedBox.shrink()`，`buildHomePage` 永远不会被调用。5 个业务模块的 `tabs` 列表都列了 4 个 placeholder（联系人 / 互动 / 人情 / 约定 等），没有任何子视图实现。

`butler_home_page.dart` 的 `_Greeting` 把"动态 hour 计算"和"hardcode 名字"分两行写，逻辑是上一个 commit（commit_5）就该合并的但当时没合并。

## 修复

### 1. Butler 中枢主页 `_Greeting` 合并

`src/lib/modules/butler/butler_home_page.dart`：把上"小字 $greeting，" + 下"大字 下午好，小明"两行合成单行 `$greeting，小明`（displayS / heavy / primary），下面的"今天 N 件事待已入栈"小字保留。

### 2. 5 个业务模块的 `tabs` 字段统一改为 `const []`

| 模块 | 文件 | 原 tabs |
|---|---|---|
| 关系 | `modules/relationship/relationship_module.dart` | 4 个 placeholder（list / timeline / favors / appts） |
| 成长 | `modules/growth/growth_module.dart` | 4 个 placeholder（goals / projects / learning / resume） |
| 财富 | `modules/wealth/wealth_module.dart` | 4 个 placeholder（overview / records / budgets / analysis） |
| 思想 | `modules/thought/thought_module.dart` | 4 个 placeholder（thoughts / letters / review / tags） |
| 健康 | `modules/health/health_module.dart` | 4 个 placeholder（records / reports / trends / devices） |

每个文件都改成：

```dart
@override
List<ModuleTab> get tabs => const [];
```

附 doc-comment 说明：模块当前是单页布局（对齐 phone-04/05/06/07/10 原型），子 tab 由各 *HomePage 内部处理；模块的 `tabs` 留空让 AppShell 走 `buildHomePage`。

`AppShell` 收到 `tabs.isEmpty` 后直接调 `active.buildHomePage(context)`，于是中枢页 5 张模块卡点进去后能正常显示各模块主页（_Greeting / AI 画像 / 数据方块 / 今日回候 / 联系人列表 等）。

### 3. 顺手清理

- 5 个模块文件底部孤立的 `Widget _placeholder(BuildContext context) => const SizedBox.shrink();` —— 全部删除（已无引用）。
- `growth_module.dart` 删掉 `import '../../ai/tools/growth_tools.dart';`（之前就 unused，工具通过 `BulterToolsBootstrap` 集中注册）。
- 关系主页 `_AiRelationshipCard` 原本 hardcode "你的核心关系 5 人 / 李华、妈妈、王老师..." 完全没用 `contactCount` —— 改为根据 `contactCount` 动态生成两段文案（>0 时显示 N 位联系人 / =0 时显示"还没有联系人"），与 `_StatBlocks` 真实数字保持一致。

## 验证

| 验证项 | 结果 |
|---|---|
| `flutter analyze lib` | ✅ 0 error（23 个 warning / info 全部 pre-existing） |
| 中枢页 _Greeting 时间一致性 | ✅ 单一 `$greeting，小明` 单行，hour < 13 时显示"中午好，小明" |
| 5 个子模块 body 区 | ✅ 不再空白，正确显示各模块主页（_Greeting / 顶卡 / 列表） |
| 5 个模块文件 tabs 字段 | ✅ 全部 `const []`，_placeholder 函数已删 |
| 中枢页模块卡点进去 | ✅ 5 张卡都能进入对应子模块，看到真实主页内容 |

## 不在本次范围

- 原型里的"联系人 / 互动 / 人情 / 约定"等**真实子 tab 视图**仍待实现（phone-04 等底部 tab 区域的真实内容）。本 commit 只是把 IndexedStack 占位符移除，避免误导；后续如需分 tab，应在 `*_home_page` 内部用 `DefaultTabController` 自行管理。
- 主页中部"AI 助理 · Butler 今日"卡仍是 hardcode 文案，未接真实 LLM 简报（属于 Step 9 简报系统范围）。
