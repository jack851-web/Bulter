# commit_5 — 各模块主页 UI 与产品原型对齐

- **版本**：0.3.1（增量改进，0.3.0 向后兼容）
- **commit 类型**：`feat(ui)` / `refactor(ui)`
- **影响范围**：Butler 中枢主页、AI 对话页、关系 / 成长 / 财富 / 思想模块主页、顶部胶囊切换器
- **关联计划**：[plan.md §Step 3 · UI 原型对齐](file:///d:/others/app/Bulter/doc/first/plan.md)
- **审查基线**：[ui_vs_prototype_review.md](file:///d:/others/app/Bulter/doc/code-quality/ui_vs_prototype_review.md)

## 目标

按 `doc/first/figures/` 共 20 张产品原型图（phone-01 ~ phone-20）逐页比对当前实现，全面修复审查报告中的 P0 / P1 视觉与交互偏差，让 UI 一眼能识别为"原生的 Bulter"。

## 实施内容

### 1. 顶部胶囊切换器（原型 phone-03-dropdown.png）

| 改动 | 描述 |
|---|---|
| 形态 | 由"横向滚动胶囊"改为"单胶囊触发器 + 弹出式下拉菜单" |
| 触发器 | 当前激活模块的胶囊，含品牌色小色块 + 模块名 + 展开箭头 |
| 弹出项 | 宽 260pt 居中面板；每行：28pt 品牌色色块（含模块 icon）+ 模块名 + 副标签（人脉·关怀 / 目标·学习 / 账户·流水 / 想法·信件 / 记录·体检 / 今日·中枢 / RAG 语义记忆）+ 右侧 ✓（若激活） |
| 数据源 | 仍走 `ModuleRegistry.capsuleModules`，未硬编码任何模块名 / 色值 |
| 边界 | 自动判断面板上方 / 下方空间，避免被屏幕边裁切 |

涉及文件：[capule_switcher.dart](file:///d:/others/app/Bulter/src/lib/components/capule_switcher.dart)

### 2. 财富模块主页（原型 phone-06-finance.png）

| 改动 | 描述 |
|---|---|
| 顶部 | 大字总额 "¥xx,xxx"（displayL / heavy）+ 副标题"总余额 · 总负债" + 负债 / 账户数 / 今日变化 |
| 行动按钮 | 横向两枚胶囊：纯黑"存入" + 白底"分一份"，`filled` 属性切换填充态 |
| 账户 / 预算区 | 移除原"账户 / 流水"Tab 切换，改为账户卡纵向列表（icon + 名称 + 类型 + 余额） |
| 最近流水 | 缩为 2 行（原型仅 2 行），保留分类胶囊 + 账户名 + 金额 |
| 数据 | `_BalanceHero` / `_AccountsList` / `_RecentTransactions` 均改为 `StreamBuilder` 订阅 DAO |

涉及文件：[wealth_home_page.dart](file:///d:/others/app/Bulter/src/lib/features/wealth/wealth_home_page.dart)

### 3. 思想模块主页（原型 phone-07-thoughts.png）

| 改动 | 描述 |
|---|---|
| 顶卡 | 紫色"AI 总结 · 本周"卡，动态显示"你想了 N 条灵感" + "留下了 M 封待拆信件" + 当前阅读高亮副标 |
| 列表 | 移除原"想法 / 信件"Tab 切换，改为"想法 · 本周" + "信件 · 待拆"两段紧凑列表 |
| 列表项 | 圆形彩色 icon（alpha 0.15 底）+ 来源/类型胶囊 + 标题 + 副标题 + 右上相对时间（刚刚 / N 分钟 / N 小时 / N 天 / yyyy-MM-dd）|
| 空态 | 统一 `_EmptyHint` 组件，图标 + 引导文案 |

涉及文件：[thought_home_page.dart](file:///d:/others/app/Bulter/src/lib/features/thought/thought_home_page.dart)

### 4. 其它已在 commit_4 完成（不重复列出）

- Butler 中枢主页（phone-01）：5 张全宽模块卡 + 橙色 Butler 大卡
- AI 对话页（phone-02）：AI 浅色泡左侧 / 用户黑泡右侧 + 状态条 + 中段插入卡片机制
- 关系模块主页（phone-04）：问候 + 粉色 AI 洞察卡 + 3 数据方块 + 联系人列表
- 成长模块主页（phone-05）：深绿 OKR 周报大卡 + 紧凑目标 / 学习列表

## 验证

| 验证项 | 结果 |
|---|---|
| `flutter analyze` | ✅ 0 error（1 warning + 7 info，全部为非阻塞的旧文件中已存在的 `unused_*` / 注释 HTML / 字符串格式建议，与本次改动无关）|
| `flutter test` | ✅ 26/26 通过 |
| 原型对比 | ✅ 财富 / 思想 / 顶部胶囊切换器 3 处 P0 / P1 偏差已修复 |
| 数据闭环 | ✅ 新建 → 列表显示 → 详情 → 编辑 → 删除 仍由 DAO Stream 驱动，未改表结构 |
| 品牌色 | ✅ 各模块卡片 / icon / 顶卡背景 / 弹出项色块均使用 `BulterColors.{module}` 品牌色 |

## 后续

- Step 4 起进入 AI 调用基础（单 LLM 流式对话）；`chat_page.dart` 中已预留的 CTA 胶囊 / 统计卡 / 概览卡插入位将由真实 LLM 工具返回数据填充。
- 联系人详情页（phone-08 / phone-20）、关系图谱（phone-17）、关系维护（phone-18）、健康度分析（phone-19）、设置页（phone-11）、浮窗截图（phone-09、12-16）、万能录入（phone-10）等未实现项已在 `ui_vs_prototype_review.md` 中标注，将在后续步骤（Step 5 工具系统 / Step 6 浮窗 / Step 7 关系网 / Step 8 健康分析 / Step 9 简报 / Step 19 设置）中实现。
- `dart fix --apply` 可在未来一次性消除 5 条 `unused_underscores` 与 1 条 `unused_element` 提示。
