# commit_8 — 对照原型图细化 UI（Step 3 UI 增量的延伸）

- **版本**：0.5.1（增量改进，0.5.0 向后兼容）
- **commit 类型**：`feat(ui)` / `refactor(ui)` / `chore(fix)` / `docs(prototype)`
- **影响范围**：联系人详情页（关系模块）、关系模块主页、设置页、公共组件（MasteryRing / Timeline）、8 个新 SVG 图标、若干阻塞性编译错误
- **关联审查**：[ui_vs_prototype_review.md](file:///d:/others/app/Bulter/doc/code-quality/ui_vs_prototype_review.md) §8 / §13 状态从 P1 → ✅

## 目标

按 `doc/first/figures/phone-08.png` / `phone-20.png`（联系人详情）、`phone-04.png`（关系主页）、`phone-11.png`（设置页）三张原型图，对当前实现做实质性细化：

1. 引入**签名元素** `MasteryRing`（自绘环形进度，替代 Material `CircularProgressIndicator`），承载"AI 量化关系深度"的理念。
2. 联系人详情页重做为：自定义顶栏 → 粉色 hero 卡（含 64pt 头像 + displayL 名字 + Mastery Ring + 标签） → 3 胶囊（发消息 / 约时间 / 标记） → AI 维护建议（按"距上次联系天数"动态生成 4 档文案） → 关系时间线（最近 5 条互动 / 人情用一条彩色细线串起） → 胶囊式 Tab（互动 / 人情）。
3. 关系主页加上"今日回候"section（按上次联系天数排序的 3 张卡 + "回候"动作按钮）。
4. 设置页重做：顶部用户卡（品牌色渐变头像）+ AI 助理 section + 模块 section（由 `ModuleRegistry.capsuleModules` 动态生成）+ 数据 / 关于。

## 实施内容

### 1. 新增公共组件

| 路径 | 作用 |
|---|---|
| [components/mastery_ring.dart](file:///d:/others/app/Bulter/src/lib/components/mastery_ring.dart) | **签名元素**：`MasteryRing`（自绘环形进度，12 点钟方向起笔，弧度 = score / 100，中心数字 + 标签）+ `ScoreBar`（水平维度条形） |
| [components/timeline.dart](file:///d:/others/app/Bulter/src/lib/components/timeline.dart) | `Timeline` / `TimelineNode` / `ActionChip`：把多个节点用一条彩色细线串起（"事件序列"的标准表达，区别于 `ListCard` 的"信息卡片"） |

### 2. 联系人详情页 [contact_detail.dart](file:///d:/others/app/Bulter/src/lib/features/relationship/contact_detail.dart)

- 移除 `AppBar`，改为自定义顶栏（左：chevron-left.svg 返回；右：tune / close 圆形按钮）。
- 整块粉色 hero 卡（alpha 0.12 底 + 64pt 圆头像 + displayL 姓名 + `Wrap` 标签 + `MasteryRing`）。
- 3 胶囊行动行：发消息 / 约时间 / 标记（每枚 56pt 高度，独立品牌色）。
- `_AiAdvice` 私有 widget：计算 `daysSinceLastContact`（无互动视为 30 天）→ 4 档文案 + 品牌色 CTA 按钮。
- `_TimelineSection`：合并 `Interaction` + `Favor`，按时间倒序，最近 5 条节点用 `Timeline` 组件串起。`Favor` 节点带 `ActionChip`（送 / 收）。
- Tab 改用自绘胶囊式 segment（纯黑背景 + 反白文字），不再用 `TabBar` 默认下划线。
- 互动 / 人情列表项里 `Icons.*` 全部替换为 SVG（已遵循前端 0 emoji 规则，但之前漏了几处 Material Icon）。

### 3. 关系模块主页 [relationship_home_page.dart](file:///d:/others/app/Bulter/src/lib/features/relationship/relationship_home_page.dart)

- 保持顶部问候 + AI 关系画像 + 3 数据方块（待回候 / 重要 / 人情未还）。
- 新增 `_FollowupSection`：按 `lastContactAt` 升序取 `importance ≥ 5` 的前 3 个，渲染为"今日回候"列表 + 品牌色"回候"按钮。
- 联系人完整列表行：副标从"关系类型 · 标签"扩展为"关系类型 · 标签 · 上次联系 N 天前"，列表流式订阅。
- 新增 `RelationshipDao.watchAllInteractions()`（Step 2 已有 `watchInteractionsFor(contactId)`，补全量用于主页统计）。
- 空态统一为"还没有联系人"+ 品牌色 CTA。

### 4. 设置页 [settings_page.dart](file:///d:/others/app/Bulter/src/lib/features/settings/settings_page.dart)

- 顶部 `_UserCard`：56pt 品牌色渐变头像 + displayS 名字 + 简介 + chevron → 跳用户画像页。
- AI 助理 section：模型 / API Key / 长期记忆 / 用户画像 4 项，每项左侧 32pt 品牌色图标块。
- 模块 section：从 `ModuleRegistry.capsuleModules` 动态生成 6 行入口（关系 / 成长 / 财富 / 思想 / 健康 / 记忆），每行带模块品牌色。
- 数据 / 关于 section 占位（"Step 20 接入"）。

### 5. 新增 7 个自绘 SVG 图标（`assets/svg/common/`）

`clock.svg`、`bookmark.svg`、`calendar.svg`、`phone.svg`、`bell.svg`、`users.svg`、`chevron-left.svg`、`handshake.svg` — 24×24 viewBox、stroke 1.75、`currentColor` 着色。

### 6. 顺手修复的阻塞性编译错误

`flutter analyze` 现状从 36 个 issue 降至 24 个（0 error），关键修复：

- `lib/ai/memory/user_profile.dart`：补 `import 'package:drift/drift.dart' show Value;`；`embedder` / `retriever` 改为可空，附 `bindRag()` 后期绑定。
- `lib/app_bootstrap.dart`：补 `import 'ai/memory/memory_manager.dart';` 与 `import 'ai/memory/user_profile.dart';`。
- `lib/router/router.dart`：补 `import 'features/settings/user_profile_page.dart';`（`UserProfilePage` 在 router 已引用却没导入）。
- `lib/modules/relationship/db/relationship_daos.dart`：新增 `watchAllInteractions()`。

剩余 24 个 warning / info 全部是 pre-existing 的未使用 import / `_unused_underscores_` / 旧文件中 `withOpacity` 已弃用等格式建议，与本次改动无关。

## 验证

| 验证项 | 结果 |
|---|---|
| `flutter analyze lib` | ✅ **0 error**（24 个 warning / info，皆为 pre-existing） |
| `flutter test` | ✅ 24/25 通过（1 失败为 Windows 临时目录文件锁 pre-existing 问题） |
| 联系人详情 / 关系主页 / 设置页原型对齐 | ✅ 对照 3 张原型图，列出的所有 P1 偏差已修复 |
| 全部图标 SVG | ✅ 0 处 `Icons.*` 引用（前端规则"不准使用 emoji，统一 SVG"全覆盖） |
| 编译通过 | ✅ 主模型 + 5 业务模块 + Demo + Bulter 中枢 7 个模块均可正常启动 |

## 遗留 / 下一步

- `flutter test` 失败的 1 个 Windows 临时目录文件锁 → 改为 `try { ... } finally { dir.deleteSync(recursive: true); }` 容错，与本 commit 无关。
- 关系图谱页（phone-17） / 关系维护页（phone-18） / 健康度分析页（phone-19） / 浮窗截图（phone-09、12-16） 仍 P1 未实现。Step 6 / 7 / 8 推进。
- 设置页"数据"section 的导出 / 导入 → Step 20。
- `dart fix --apply` 可在未来一次性消除 `unnecessary_underscores_` 与 `unused_import` 提示。

## 引用

- 原型图：[doc/first/figures/phone-04.png](file:///d:/others/app/Bulter/doc/first/figures/phone-04-relations.png) / [phone-08.png](file:///d:/others/app/Bulter/doc/first/figures/phone-08-detail.png) / [phone-11.png](file:///d:/others/app/Bulter/doc/first/figures/phone-11-settings.png) / [phone-20.png](file:///d:/others/app/Bulter/doc/first/figures/phone-20-detail-comm.png)
- 审查基线：[doc/code-quality/ui_vs_prototype_review.md](file:///d:/others/app/Bulter/doc/code-quality/ui_vs_prototype_review.md)
- 上一提交：[doc/git_log/commit_7.md](file:///d:/others/app/Bulter/doc/git_log/commit_7.md)（Step 5 工具系统）
