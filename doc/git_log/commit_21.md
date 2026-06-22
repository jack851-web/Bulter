# commit_21 — Step 13b Web 端数据可视化（关系图谱 / 月度账单图表 / 健康趋势图）

- **版本**：0.9.6
- **commit 类型**：`feat(visualizations)`
- **影响范围**：Dart 7 新文件（3 服务 + 4 widget）+ 测试 1 新文件（11 测试）
- **关联文档**：[doc/first/plan.md §第 13 步](file:///d:/others/app/Bulter/doc/first/plan.md) + [§第 18 步](file:///d:/others/app/Bulter/doc/first/plan.md)

## 目标

Web 端数据可视化（同一套代码编译移动端 + Web）：

| 图 | 范围 |
|---|---|
| **关系图谱** | 节点=人，颜色=距上次联系天数，大小=活跃度，边=互动/人情 |
| **月度账单** | 横向柱图（本月分类）+ 折线图（近 6 月趋势） |
| **预算占用** | 进度条（spent/limit，超支红色） |
| **健康趋势** | 多 series 折线（体重 + 睡眠，支持正常范围阴影） |

## 实施内容

### A. 数据服务（3 新文件）

#### 1. 🆕 [lib/modules/relationship/services/graph_service.dart](file:///d:/others/app/Bulter/src/lib/modules/relationship/services/graph_service.dart)

**关系图谱数据层**：
- `build(db)` → `RelationshipGraph { nodes, edges, generatedAt }`
- `GraphNode`：contactId / label / sublabel / importance / lastContactAt / interactionCount / favorCount
- `GraphNode.daysSinceLastContact`：null → -1
- `GraphNode.radiusFactor`：1.0 + 互动 + 重要度 加权
- `GraphEdge`：fromId / toId / weight（自环表示活跃度）
- 数据范围：最近 180 天互动 + 所有 open 人情

#### 2. 🆕 [lib/modules/wealth/services/chart_service.dart](file:///d:/others/app/Bulter/src/lib/modules/wealth/services/chart_service.dart)

**财富图表数据层**：
- `categoryBarsForMonth(year, month, topN)` → `List<CategoryBar>`（复用 [MonthlyReportService](file:///d:/others/app/Bulter/src/lib/modules/wealth/services/monthly_report_service.dart)）
- `trend(months: 6)` → `List<TrendPoint>` (year, month, incomeCents, expenseCents, label)
- `budgetUsage()` → `List<BudgetUsage>` (spent/limit/ratio + isOverBudget)
- `CategoryBar.colorName`：8 色调色板（红橙黄绿青蓝紫灰）

#### 3. 🆕 [lib/modules/health/services/health_trend_service.dart](file:///d:/others/app/Bulter/src/lib/modules/health/services/health_trend_service.dart)

**健康趋势数据层**：
- `series(metricType, window)` → `TrendSeries` (label, unit, points)
- `multiSeries(metricTypes)` → `List<TrendSeries>`
- `TrendSeries.max / min / avg / latest / span` 统计
- 自动过滤 `valueNum == null`

### B. UI Widget（4 新文件，纯 CustomPainter）

#### 1. 🆕 [lib/features/visualizations/relationship_graph_view.dart](file:///d:/others/app/Bulter/src/lib/features/visualizations/relationship_graph_view.dart)

**关系图谱视图**（圆周布局）：
- 中心：1 个最重要的 contact（"你"主题）
- 圆周：其余 contact 按 importance 顺序
- **节点颜色**：绿（≤7d）/ 黄（8-30d）/ 红（>30d）/ 灰（从未联系）
- **节点大小**：radiusFactor
- 点击节点 → `onNodeTap(GraphNode)` 回调
- **响应式**：LayoutBuilder 自适应容器宽度（Web 大屏友好）

#### 2. 🆕 [lib/features/visualizations/category_bars_chart.dart](file:///d:/others/app/Bulter/src/lib/features/visualizations/category_bars_chart.dart)

**横向柱图**：
- 左：分类 label（56pt 固定）
- 中：进度条（按 ratio）
- 右：金额 + 百分比
- 8 色调色板循环

#### 3. 🆕 [lib/features/visualizations/trend_line_chart.dart](file:///d:/others/app/Bulter/src/lib/features/visualizations/trend_line_chart.dart)

**通用折线图**：
- Y 轴：4 条网格线 + label
- X 轴：等间距时间点 label
- 多 series 用不同颜色叠加
- **正常范围阴影**（[normalRange]）：health 指标可在 normalLow-High 之间画绿色阴影
- 数据点：圆 + 白色描边

#### 4. 🆕 [lib/features/visualizations/budget_usage_view.dart](file:///d:/others/app/Bulter/src/lib/features/visualizations/budget_usage_view.dart)

**预算进度条**：
- 颜色：绿（≤80%）/ 黄（80-100%）/ 红（>100%）
- 超支时显示 ⚠️ 警示图标

### C. 集成页面

#### 🆕 [lib/features/visualizations/visualization_page.dart](file:///d:/others/app/Bulter/src/lib/features/visualizations/visualization_page.dart)

`VisualizationPage` 单页 5 段：
1. 关系图谱
2. 本月分类柱图
3. 近 6 月趋势线
4. 预算占用
5. 健康趋势（多 series）

顶部 AppBar + 刷新按钮。

## 验证

| 验证项 | 结果 |
|---|---|
| `flutter analyze lib` | ✅ **0 error** |
| `flutter test test/step13b_visualization_test.dart` | ✅ **11/11** |
| `flutter test`（全部） | ✅ **86/86** |

## 关键设计决策

### D1：纯 CustomPainter vs 第三方图表库

**对比**：

| 选项 | 优点 | 缺点 |
|---|---|---|
| **CustomPainter** | 0 依赖，体积可控，完全可控样式 | 工作量大（手写 Y 轴、网格、label）|
| fl_chart / syncfusion | 功能丰富（动画 / 交互 / 缩放）| 多 200-500KB 体积 |

**选 CustomPainter**：
- 3 个图规模小（< 200 行/图）
- Bulter 风格（Cal.com + Clay）需要细粒度控制
- 0 体积增长
- 测试友好（Painter 是纯函数）

### D2：图谱 = 圆周 + 自环（简化版）

**当前**：
- 节点：contact
- 边：自环（from = to = contact）= 该 contact 的活跃度（互动 + 人情×3）

**未做**：
- 真正多对多边（"两人共同参与的活动"）
- 力导向布局（fruchterman-reingold）
- 群组概念

**理由**：当前 schema（Interactions 单 contact_id）不支持多对多边；圆周布局已能可视化"谁更核心 / 谁更久未联系"。**未来扩展**：加 `group_id` 字段 + 力导向 layout。

### D3：normalRange 阴影（健康图）

健康图用绿色阴影标注"正常范围"：
- 体重：45-80kg
- 睡眠：7-9h

**用户价值**：一眼看到"体重偏高"（点出绿区上沿）。

**实现**：`TrendLineChart.normalRange: [low, high]` → 自动按比例画阴影。

### D4：响应式（Web 端大屏）

**当前**：单列 ListView（移动端友好）

**未来**：
- 宽度 ≥ 900px 时切双列（图表并排）
- 宽度 ≥ 1280px 时切三列（数据看板大屏）
- 用 `LayoutBuilder` + `Wrap` 实现

**未做原因**：本次优先核心数据 + 渲染，响应式分屏留作 polish。

## 引用

- 上次 commit：[commit_20.md](file:///d:/others/app/Bulter/doc/git_log/commit_20.md)（P0-P2 系统审查修复）
- 上上 commit：[commit_18.md](file:///d:/others/app/Bulter/doc/git_log/commit_18.md)（Step 13 业务层）
- 设计：[doc/first/01-architecture.md §5.2](file:///d:/others/app/Bulter/doc/first/01-architecture.md)（主页布局）
- 计划：[doc/first/plan.md §第 13 步](file:///d:/others/app/Bulter/doc/first/plan.md)（数据层 OK，Web 可视化待 13b）+ [§第 18 步](file:///d:/others/app/Bulter/doc/first/plan.md)（Web 端）
- 复用：[MonthlyReportService](file:///d:/others/app/Bulter/src/lib/modules/wealth/services/monthly_report_service.dart)（Step 13 已实现，本步复用 trend/category 聚合）
