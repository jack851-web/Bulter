# Bulter 项目进度计划

> 本文档把 Bulter 拆解为 20 个可顺序执行的步骤。每一步包含：**目标 / 范围 / 完成标准（验收效果）**。
> AI 读完后可直接按步骤号执行；测试人员可对照"完成标准"逐条验收。
> 步骤之间有依赖关系，原则上按顺序进行；标注 [可并行] 的可与上一步并行。

---

## 使用方式

- 对 AI 说：「现在做第 N 步」→ AI 读取本文件，按第 N 步的"范围"执行，按"完成标准"自检。
- 测试人员：在第 N 步完成后，对照"完成标准"逐条验证，全部通过即该步合格。
- 每步完成后建议提交一次 git commit，commit message 格式：`step N: <步骤名>`。

---

## 通用要求（贯穿所有步骤，每步都要遵守）

以下两条是 Bulter 的核心架构约束，**每一个步骤在实现时都必须满足**，测试人员可在任意步骤抽查。

### 一、模块化与可扩展性

Bulter 必须做成"插件式"架构，后期新增任何东西都不需要改动核心代码：

1. **业务模块可插拔**：每个业务模块（关系/成长/财富/思想/健康/记忆）实现统一的 `BulterModule` 接口（注册 id、品牌色、入口路由、子 agent、工具集、DAO、简报生成器）。新增一个模块 = 新建一个目录 + 在注册表加一行，**不修改主框架任何文件**。
2. **AI 工具可插拔**：工具通过 `ToolRegistry.register()` 动态注册，新增工具只需写一个 Tool 定义 + Executor 并注册，**不改动 orchestrator / sub_agent 主流程**。
3. **子模型可插拔**：子模型通过 `SubAgentRegistry` 注册，新增模块子模型 = 新建一个 `SpecialistAgent` + 注册，主模型通过 `invoke_sub_agent(module_id)` 自动能调到。
4. **输入路径可插拔**：三条输入路径（浮窗/对话/手动）是独立 feature，新增第四条路径（如语音助手、邮件转发）不改其他路径。
5. **跨模块事件可插拔**：EventBus 事件用发布订阅，新增事件类型只需定义事件 + 订阅，不改发布方。

**验证原则**：任何一次"加新功能"，如果需要修改 `orchestrator.dart` / `router` 主表 / `main.dart` 以外的核心文件，就说明模块化没做好，要重构。

### 二、数据安全与版本兼容（最高优先级）

用户的人生数据是不可再生的，**软件更新绝不允许丢数据**。严格做到：

1. **数据库带版本号 + 迁移脚本**：Drift 的 `schemaVersion` + `MigrationStrategy`。每次表结构变更，schemaVersion +1，写对应 `onCreate` / `onUpgrade` 迁移逻辑。**旧数据必须原样保留并迁移到新结构**，绝不 drop 重建。
2. **迁移必须向前兼容**：新增字段给默认值；删字段先停用不真删，跨一个大版本再清理；改字段类型写数据转换逻辑。
3. **Hive Box 带 versionId**：每个 Box 注册时指定 `versionId`，升级时通过 `Box.migrate()` 处理结构变化，不丢已有 KV。
4. **升级前自动备份**：每次 App 检测到 schemaVersion 变化时，先把整个 SQLite 文件和 Hive 目录复制到 `备份/升级前_v{旧版本}_{时间戳}/`，迁移成功后保留 7 天再清理。迁移失败自动回滚到备份并提示用户。
5. **向量库独立版本管理**：sqlite-vec 虚拟表单独维护版本，Embedding 模型升级（如 BGE-M3 换 text-embedding-3-small）时支持"旧向量保留 + 新向量增量重算"，不一刀切清空。
6. **导出/导入兜底**：设置页提供"导出全部数据为 JSON/SQLite 文件"和"从文件导入"，用户可在升级前手动备份。这是迁移自动备份之外的最后一道防线。
7. **不可变数据模型用 freezed + versioned**：核心数据模型带 `schemaVersion` 字段，反序列化时按版本做兼容转换。

**验证原则**：任何一次涉及数据库/Hive 的改动，必须能在"装旧版→录数据→装新版"流程下验证旧数据完整保留且可正常读写。测试方法见第 2 步和第 20 步。

---

## 第 1 步：项目骨架与设计系统

**目标**：搭好可运行的 Flutter 空壳，建立设计 Token 与路由骨架。

**范围**：
1. `flutter create` 初始化项目，配置 `pubspec.yaml`（Flutter 3.24+ / Dart 3.5+）
2. 引入依赖：riverpod、go_router、freezed、drift、hive、sqlite-vec、dio、flutter_svg、google_fonts
3. 按 `03-tech.md` §十八 建立完整 `lib/` 目录结构（空文件占位即可）
4. 实现 `lib/theme/tokens.dart`：画布 #FAF6EE、CTA 纯黑、6 模块品牌色、间距/圆角/字体 token
5. 实现 `lib/router/` 路由骨架：胶囊切换器 + 底部 Tab + AI 常驻 FAB 的壳（页面用占位 Scaffold）
6. `main.dart` 入口 + ProviderScope + 主题加载
7. **模块化骨架（核心）**：
   - 定义 `BulterModule` 抽象接口（id / brandColor / entryRoute / subAgent / tools / dao / briefingGenerator），所有业务模块必须实现
   - 定义 `ModuleRegistry`：启动时遍历注册所有模块，路由表/胶囊切换器/底部 Tab 由注册表动态生成（**不硬编码模块列表**）
   - 定义 `ToolRegistry`、`SubAgentRegistry`、`EventBus` 的空壳接口（后续步骤填充）
   - 预留 `lib/modules/` 目录，每个模块一个子目录，内含该模块全部代码（feature + dao + tools + sub_agent 自包含）

**完成标准**：
- [ ] `flutter run` 能启动，无报错
- [ ] 顶部胶囊切换器可在 Butler / 关系 / 成长 / 财富 / 思想 / 健康 之间切换
- [ ] 底部 Tab 可切换（占位内容即可）
- [ ] 右下角 FAB 可点击（占位即可）
- [ ] 画布底色为 #FAF6EE，主按钮为纯黑
- [ ] 6 模块品牌色在 tokens.dart 中定义并可引用
- [ ] 目录结构与 `03-tech.md` §十八 一致
- [ ] **模块化验证**：在 `lib/modules/` 下新建一个假模块（如 `demo`），只需实现 `BulterModule` 接口 + 在 `ModuleRegistry` 加一行注册，胶囊切换器自动出现"Demo"入口，**无需修改 router/主框架任何文件**
- [ ] `BulterModule` / `ModuleRegistry` / `ToolRegistry` / `SubAgentRegistry` / `EventBus` 接口已定义且有占位实现

---

## 第 2 步：本地数据存储层

**目标**：建好全部数据库表与 DAO，为后续功能提供数据底座。

**范围**：
1. `lib/db/` Drift 数据库主类 + 连接配置，**必须带 `schemaVersion` 字段，初始版本 = 1**
2. `lib/db/tables/` 全部表定义（参考 `03-tech.md` §二 核心表清单）：
   - 关系：contacts / interactions / favors
   - 成长：goals / okrs / learning_records / projects
   - 财富：accounts / transactions / budgets
   - 思想：thoughts / letters / annual_reviews
   - 健康：health_records / checkup_reports / health_scores
   - AI：messages / sessions / briefings / memories / user_profile
3. `lib/db/dao/` 各模块 DAO（CRUD 方法），每个 DAO 归属对应模块目录（模块自包含）
4. `lib/db/tables/embeddings.dart`：sqlite-vec 向量虚拟表，**单独 schemaVersion**
5. `lib/storage/` Hive Box 配置（用户偏好、缓存、简报），**每个 Box 注册时指定 `versionId`**
6. **数据迁移框架（核心，必须在本步完成）**：
   - `lib/db/migration.dart`：实现 `MigrationStrategy`，含 `onCreate`（新建）和 `onUpgrade`（按 schemaVersion 逐步迁移）
   - `lib/db/backup.dart`：升级前自动备份（复制 SQLite 文件 + Hive 目录到 `备份/升级前_v{旧版本}_{时间戳}/`），迁移成功保留 7 天，失败自动回滚
   - `lib/security/data_export.dart`：全量数据导出为 JSON + SQLite 文件 / 从文件导入（兜底）
7. **模块化数据**：每个模块的表定义和 DAO 放在 `lib/modules/{模块名}/db/` 下，主数据库通过 `ModuleRegistry` 收集各模块的表定义合并建库，新增模块的表自动加入

**完成标准**：
- [ ] App 启动时自动建库，无报错，schemaVersion = 1
- [ ] 每张表可通过对应 DAO 完成 insert / update / delete / query
- [ ] Drift Stream 查询能响应式通知 UI（写入后监听方收到更新）
- [ ] Hive Box 可读写 KV，versionId 已配置
- [ ] sqlite-vec 虚拟表可插入并检索向量（写测试用例验证）
- [ ] **数据迁移验证（必测）**：写一个集成测试 —— 建库 v1 → 插入 10 条各表数据 → 模拟升级到 v2（加一个字段）→ 启动 → 旧 10 条数据完整保留且新字段有默认值，**零数据丢失**
- [ ] **备份验证**：模拟升级时，`备份/升级前_v1_{时间戳}/` 目录生成，内含 SQLite 文件 + Hive 目录副本
- [ ] **回滚验证**：模拟迁移失败 → 自动从备份恢复 → App 正常启动且数据完整
- [ ] **导出/导入验证**：导出全部数据为 JSON 文件 → 清空数据库 → 从 JSON 导入 → 数据完整恢复
- [ ] **模块化数据验证**：新增一个假模块，在 `lib/modules/demo/db/` 下定义一张 `demo_items` 表并实现 DAO + 在 ModuleRegistry 注册 → 启动后该表自动建出，无需改动主数据库文件

---

## 第 3 步：六大模块基础 CRUD UI [可并行于第 2 步后段]

**目标**：关系/成长/财富/思想/健康 五大业务模块的列表、详情、表单页可用，覆盖手动录入路径 C。

**范围**：
1. `lib/features/relationship/`：联系人列表 + 详情 + 新增/编辑表单
2. `lib/features/growth/`：目标列表 + 详情 + 表单
3. `lib/features/wealth/`：余额总览 + 收支记录列表 + 录入表单
4. `lib/features/thought/`：读后感列表 + 详情 + 表单
5. `lib/features/health/`：健康记录列表 + 录入表单
6. `lib/features/form/`：通用表单组件（日期选择器、标签输入、金额输入等）
7. 各模块空状态、加载状态、错误状态

**完成标准**：
- [x] 每个模块都能：新建 → 列表显示 → 点击进详情 → 编辑 → 删除
- [x] 删除操作有二次确认弹窗
- [x] 列表为空时显示空状态插画 + 引导文案
- [x] 表单字段校验（必填、金额为数字、日期合法）
- [x] 各模块品牌色正确应用于卡片/icon
- [x] 数据写入后列表立即刷新（Drift Stream）

**Step 3 实施记录**：
- 共享表单组件：`lib/features/form/` 下 9 个组件 — `text_field_card.dart`、`chips_input.dart`、`date_picker_field.dart`、`amount_input.dart`、`rating_input.dart`、`integer_input.dart`、`choice_chips_field.dart`、`confirm_dialog.dart`、`stream_list_view.dart`。
- 关系模块：
  - 列表/详情 `relationship_home_page.dart`、`contact_detail.dart`（联系人头像 + Tab 切换"互动 / 人情"）。
  - 表单 `contact_form.dart`（基础信息 + 关系类型 + 标签 + 重要度）、`interaction_form.dart`（互动类型 + 时间 + 摘要 + 心情）、`favor_form.dart`（人情方向 + 描述 + 金额）。
- 成长模块 `growth_home_page.dart` + Tab 切换"目标 / 学习"；表单 `goal_form.dart`（标题 + 分类 + 状态 + 目标日期 + 进度滑块）、`learning_form.dart`（来源 + 评分 + 笔记）。
- 财富模块 `wealth_home_page.dart` 顶部余额总览 + Tab 切换"账户 / 流水"；表单 `account_form.dart`（账户名 + 类型 + 币种 + 余额 + 备注）、`transaction_form.dart`（类型 + 账户 + 金额 + 分类 + 日期 + 备注）。
- 思想模块 `thought_home_page.dart` + Tab 切换"想法 / 信件"；表单 `thought_form.dart`（来源 + 内容 + 标签 + 心情 + 日期）、`letter_form.dart`（写给谁 + 标题 + 正文 + 投递日期）。
- 健康模块 `health_home_page.dart` + Tab 切换"记录 / 体检报告"；表单 `health_form.dart`（类别 + 时间 + 强度 / 时长 / 数值 + 备注，类别自动切换字段）。
- 5 个模块 `*_module.dart` 的 `buildHomePage` 改为直接返回新 `*_home_page.dart`；各模块 `*Dao` 增补 `updateXxx` / `watchXxx` 方法。
- 验证：`flutter analyze` 0 error（仅 1 warning + 5 info 级别提示），`flutter test` 26 用例全部通过。

**Step 3 · UI 原型对齐（增量）**：

对照 `doc/first/figures/phone-*.png` 共 20 张产品原型图，对中枢主页、AI 对话页、关系 / 成长 / 财富 / 思想模块主页以及顶部胶囊切换器做了视觉与交互的全面对齐，已纳入 `doc/code-quality/ui_vs_prototype_review.md` 的 P0/P1 修复清单。

- **Butler 中枢主页** `lib/modules/butler/butler_home_page.dart`：由"1 张洞察大卡 + 2×2 网格"重构为"顶部问候 + 橙色 Butler 洞察大卡 + 5 张全宽模块快览卡纵向堆叠"，每张模块卡以品牌色 alpha 0.10 底色 + 模块名胶囊 + AI 总结 / 关键数据 + 1-2 个事实胶囊。
- **AI 对话页** `lib/features/chat/chat_page.dart`：按原型重排消息流（AI 左侧浅色泡 / 用户右侧纯黑泡）、顶部状态条"在线 · N 件事已被追踪"、消息中插入"CTA 胶囊 / 统计卡 / 概览卡"机制（Step 4 AI 工具返回时填充）、底部"单行输入 + 圆形黑色发送"。
- **关系模块主页** `lib/features/relationship/relationship_home_page.dart`：新增顶部问候、AI 洞察卡（粉色 alpha 0.10 底）+ 3 个数据方块（待联系 / 重要 / 人情未还）+ 联系人紧凑列表，联系人为空时显示统一空状态卡。
- **成长模块主页** `lib/features/growth/growth_home_page.dart`：移除原"目标 / 学习"Tab 切换，改为"本月周报"深绿大卡（标题 + 进度条）+ 紧凑目标 / 学习列表（彩色方形 icon + 标题 + 副标题 + 进度）。
- **财富模块主页** `lib/features/wealth/wealth_home_page.dart`：按原型重排为"顶部大字总余额 + 总负债 + N 个账户合计 · 今日变化"→ 双按钮（纯黑"存入" + 白底"分一份"）→ 账户 / 预算区账户卡 → 最近流水 2 行，底部 FAB"记一笔"补全路径。
- **思想模块主页** `lib/features/thought/thought_home_page.dart`：移除原"想法 / 信件"Tab 切换，改为紫色"AI 总结 · 本周"顶卡（动态显示想法数 / 待拆信件数 / 当前阅读高亮）+ "想法 · 本周"与"信件 · 待拆"两段紧凑列表（圆形彩色 icon + 标题 + 副标题 + 右上时间）。
- **顶部胶囊切换器** `lib/components/capule_switcher.dart`：由横向滚动胶囊改为"单胶囊触发器 + 弹出式下拉菜单"，触发器含品牌色色块 + 模块名 + 展开箭头；弹出项宽 260pt 居中、含品牌色色块 + 模块名 + 副标签 + 右侧 ✓（若激活）；数据源仍走 `ModuleRegistry.capsuleModules`，未硬编码。
- 验证：`flutter analyze` 0 error（仅 1 warning + 7 info，皆为非阻塞的格式建议 / 旧文件中已存在的未引用方法），`flutter test` 26/26 通过。

**Step 4 实施记录**：

对照 `doc/first/plan.md` §第 4 步完成 AI 调用基础（单 LLM 流式对话），并按"前端 UI 不准使用 emoji"规则将所有 Material Icons 替换为自绘 SVG。

- **AI 服务层** `lib/ai/`：
  - `ai_service.dart`：封装 `streamCompletion`（SSE 流式 + `done` 终止事件 + 错误分类 `AiErrorKind`：`noApiKey / auth / rateLimit / notFound / server / network / parse`），并预留 `completion`（非流式）和 `tool_calls` 累积接口（Step 5 用）。
  - `model_registry.dart`：9 厂商元信息（MiniMax / OpenAI / Anthropic / Google Gemini / Qwen / GLM / Moonshot / DeepSeek / Baidu）+ 每厂商 2-4 个可选模型，默认 MiniMax-M3；API Key / 当前选择持久化到 `bulter_user_preferences` Hive Box。
  - `memory/short_term.dart`：滑动窗口 20 轮（40 条消息），按 FIFO 丢弃最旧，保留 system 消息；对外 `toLlmMessages()` 转 OpenAI Chat Completions 格式。
  - `app_bootstrap.dart`：启动时 `ModelRegistry.instance.load()` 读取用户配置。
- **模型配置 UI** `lib/features/settings/`：
  - 新增 `model_config_page.dart`：当前激活卡片 + 厂商横向 chips + 模型下拉 + API Key 密码输入（带"显示 / 隐藏"切换）+ 保存 / 清除按钮 + 已配置 / 未配置状态徽标。
  - `settings_page.dart`：AI 区两个入口（模型 / API Key）点击进入 `ModelConfigPage`；图标全部 SVG。
- **AI 对话页** `lib/features/chat/chat_page.dart`：接入 `AiService.streamCompletion`，流式打字机效果 + 错误占位（红底 + 错误消息）+ 三点动画"输入中"+ 未配置 API Key 时显示顶部引导条；底部输入框在发送中禁用并切换为灰色 CTA。
- **路由** `lib/router/router.dart`：新增 `/settings/model` 覆盖在 Shell 之上。
- **SVG 图标库**：
  - 新增 `lib/components/svg_icon.dart`：`SvgIcon(name, size, color)` + `SvgIconButton` 圆形容器封装，全部基于 `flutter_svg`。
  - `assets/svg/{common, modules, chat, settings}/` 共 30+ 个手绘 24x24 stroke 风格图标（close / chevron-right / chevron-down / expand-more / check / arrow-up / arrow-forward / arrow-downward / plus / arrow-outward / sparkles / menu / download / upload / info / error / tune / receipt / circle / butler / relationship / growth / wealth / thought / health / memory / chat-bubble / chat-bubble-outline / send / robot / user / key / model / timeline / report / trending-up / chip / chart / globe / briefcase / mail / briefcase-filled）。
  - `pubspec.yaml` 追加 5 个 `assets/svg/*` 路径。
- **Material Icon 清理**：
  - `capule_switcher.dart`（展开箭头 / ✓ / 7 个模块 icon）
  - `app_shell.dart`（关闭 + 设置 + 7 个 Tab icon）
  - `butler_home_page.dart`（5 张模块卡的 icon + chevron）
  - `fab_chat.dart`（AI FAB icon）
  - `empty_state.dart` 接受 `Widget icon` 而非 `IconData`
  - `ai_insight_card.dart`（闪光 icon）
  - `stream_list_view.dart`（空状态 / 错误 icon，参数 `emptyIconName`）
  - `bottom_tab.dart`（`TabItem.iconName`）
  - `bulter_module.dart`（`ModuleTab.iconName`）
  - 5 个业务模块 + demo 模块的 tabs / buildHomePage 全部改用 `iconName`
- **验证**：`flutter analyze` 0 error（12 条 info / warning：均为非阻塞，2 个 `unused_*` 来自旧文件 amount_input / growth 的 _openAddGoal 等，本次未触碰）；`flutter test` 24/26 通过（2 个失败为 Windows 临时目录文件锁导致的 `module_registry_test` / `data_export_test` 清理异常，与本次改动无关）。

---

## 第 4 步：AI 调用基础（单 LLM 对话）

**目标**：实现可用的 AI 对话，流式输出，含短记忆，先不接工具。

**范围**：
1. `lib/ai/ai_service.dart`：封装 `streamCompletion`，处理 SSE + `tool_calls` 分片累积（工具部分先留接口）
2. `lib/ai/model_registry.dart`：9 厂商配置，默认 MiniMax M3
3. `lib/features/chat/`：对话页 UI（消息气泡、打字机效果、输入框、发送）
4. `lib/ai/memory/short_term.dart`：会话级短记忆（滑动窗口 20 轮）
5. 模型配置页（用户可填 API Key、切换模型）

**完成标准**：
- [ ] 在设置页填入 API Key 后，AI 对话能正常流式输出
- [ ] 首字响应 < 1s（网络正常时）
- [ ] 对话历史在同一会话内保持上下文（AI 能记住前文）
- [ ] 新建对话会清空上下文
- [ ] 切换模型后立即生效
- [ ] API Key 错误 / 网络断开时显示友好错误提示，不崩溃

---

## 第 5 步：工具系统（Tool Use）

**目标**：AI 能通过 Function Calling 读写本地数据，ReAct 多轮调用闭环。

**范围**：
1. `lib/ai/tools/tool_registry.dart`：工具注册表
2. `lib/ai/tools/read_*.dart`：各模块只读工具（query_records、rag_search 留接口）
3. `lib/ai/tools/write_*.dart`：各模块写工具（save_/update_/delete_）
4. `lib/ai/tools/` 工具定义（JSON Schema）+ 执行器（调 DAO）
5. ReAct 循环：LLM 返回 tool_calls → 执行 → tool 消息回传 → LLM 继续，直到无 tool_calls
6. 写操作（尤其 delete_*）触发 `pending_confirmation` 二次确认 UI
7. 对话页展示工具调用过程（可折叠的"AI 正在查询…"卡片）

**完成标准**：
- [ ] 对 AI 说"帮我记一下，今天和小王吃了顿饭花 200"→ AI 调用 save_transaction 写入，并回复确认
- [ ] 对 AI 说"我有哪些联系人"→ AI 调用 query_records 查询并回复列表
- [ ] 对 AI 说"删除联系人小王"→ 弹出二次确认，确认后才删除
- [ ] 一个意图可触发多轮工具调用（如"上个月吃饭花了多少"→ 先查类别再查金额）
- [ ] 对话页能看到工具调用过程（工具名 + 参数 + 结果摘要）
- [ ] AI 调用不存在的工具或参数错误时不崩溃，给出提示

---

## 第 6 步：RAG 语义记忆

**目标**：长记忆可向量检索，对话时自动注入相关上下文。

**范围**：
1. `lib/ai/rag/embedder.dart`：调用 Embedding API（BGE-M3 / OpenAI text-embedding-3-small）
2. `lib/ai/rag/vector_store.dart`：sqlite-vec 存取
3. `lib/ai/rag/retriever.dart`：Top-K 召回 + Rerank
4. `lib/ai/rag/context_injector.dart`：对话前自动检索并注入
5. `lib/ai/memory/long_term.dart`：长记忆提取（对话关闭时 / 每 N 条消息，LLM 提取事实写入向量库，去重合并）
6. 语义搜索结果页（展示相似度 + 来源）

**完成标准**：
- [ ] 对话中提到的关键信息（如"我妈妈生日是 3 月 5 号"）会被提取为长记忆
- [ ] 之后问"我妈生日什么时候"→ RAG 能召回并正确回答，即便不在当前会话历史里
- [ ] 语义搜索页输入关键词，返回相关记忆片段 + 相似度分数 + 来源时间
- [ ] 相同事实重复写入时去重，不产生冗余向量
- [ ] Embedding 失败时不阻塞对话，降级为无 RAG 回答

---

## 第 7 步：记忆系统完整（4 层 + 用户画像）

**目标**：四层记忆完整运作，用户画像稳定维护并始终注入。

**范围**：
1. `lib/ai/memory/working.dart`：工作记忆（多步任务中间状态）
2. `lib/ai/memory/user_profile.dart`：用户画像表读写 + 自动提取（姓名/职业/偏好/目标/重要他人）
3. `lib/ai/memory/memory_manager.dart`：统一管理四层，每次 LLM 调用前组装上下文（画像 + RAG + 短记忆 + 工作记忆）
4. 对话页"记忆注入区"可折叠组件，展示本次注入了哪些记忆

**完成标准**：
- [ ] 用户画像可自动从对话中提取（如多次提到职业 → 画像更新为该职业）
- [ ] 每次对话 AI 回复符合画像特征（如知道用户姓名、职业）
- [ ] 记忆注入区显示：用户画像摘要 + RAG 召回片段数 + 短记忆轮数
- [ ] 多步任务（如"帮我把上周所有账单按类别汇总"）中间状态不丢失
- [ ] 画像可在设置页查看和手动编辑

---

## 第 8 步：多智能体（主模型 + 子模型）

**目标**：跨模块问题由主模型调度子模型协作回答。

**范围**：
1. `lib/ai/orchestrator.dart`：主模型调度逻辑（简单问题直接答，跨模块调子模型）
2. `lib/ai/sub_agents/`：5 个模块子模型，注册层隔离（只注入本模块只读工具 + RAG + briefing_publish）
3. `lib/ai/tools/invoke_sub_agent.dart`：主模型调用子模型的工具
4. 子模型返回自然语言结果，主模型汇总生成跨模块叙事
5. 对话页展示调度链路（主模型 → 哪个子模型 → 结果）

**完成标准**：
- [ ] 简单单模块问题（"我最近花了多少钱"）主模型直接答，不调子模型
- [ ] 跨模块问题（"我健康和财务最近有什么值得关注的"）主模型并行调健康+财富子模型，汇总回答
- [ ] 子模型只能读本模块数据（构造时不注入其他模块工具）
- [ ] 子模型无法执行写操作（写工具未注册）
- [ ] 子模型超时 8s 自动降级，主模型回复"该模块暂不可用"
- [ ] 对话页能看到调度链路（哪个子模型被调用、返回了什么）

---

## 第 9 步：简报系统（首页被动浏览）

**目标**：首页打开就能看各模块近期摘要，定时自动刷新。

**范围**：
1. `lib/models/briefing.dart`：ModuleBriefing freezed 模型
2. `lib/ai/briefing/briefing_store.dart`：Hive 读写（覆盖写入，generated_at + TTL）
3. `lib/ai/briefing/briefing_generator.dart`：调子模型生成简报
4. `lib/ai/scheduler.dart`：定时任务（每日 23:00 / 每周日 / 每月最后一天 / 每年 12/31），用 workmanager
5. Butler 中枢主页 5 卡 Bento：1 AI 洞察大卡 + 4 模块快览卡，填充真实简报
6. 简报新鲜度展示（"更新于 X 小时前"，过期标记）

**完成标准**：
- [ ] 手动触发简报生成后，首页 4 张模块卡显示 push_headline + summary
- [ ] AI 洞察大卡展示主模型汇总的跨模块叙事
- [ ] 简报卡片显示"更新于 X 小时前"，超过 TTL 标记为过期
- [ ] 定时任务到点自动生成（可通过手动改系统时间验证）
- [ ] 简报生成失败不影响 Agent 对话
- [ ] 简报 JSON ≤2KB

---

## 第 10 步：浮窗截图输入路径

**目标**：通过无障碍模式长期悬浮图标，点击图标，AI 推理场景并归类。

**范围**：
1. `platform/floating_window.dart` + `screenshot.dart`：Android 原生浮窗 + 截图桥接
2. `lib/overlay/overlay_service.dart` / `overlay_widget.dart`：Flutter Overlay UI
3. `lib/ai/scene_inference.dart`：截图 → MiniMax M3 多模态推理场景（聊天/账单/文章/体检报告等）
4. 推理结果归类到对应模块，用户确认/修改弹窗
5. 多张截图批量处理
6. 截图场景为聊天时提供回复建议，或是判断聊天中产生了约定，加入关系，并且能够根据聊天框上的名称识别到对应联系人更新对应联系人的相关内容，如"我妈妈生日是 3 月 5 号" → 更新用户画像"妈妈生日"，也比如如果发现名称中的联系人没有创建，则选择创建该人。

**完成标准**：
- [ ] 在任意 App 长按可呼出 Bulter 浮窗
- [ ] 截图后 AI 在 3s 内给出场景判断（如"这像是一笔支付宝转账"）
- [ ] 推理结果可归类到对应模块，用户可确认或手动改模块
- [ ] 确认后数据写入对应模块（如账单截图 → 财富记录）
- [ ] 支持一次选多张截图批量处理
- [ ] 聊天截图场景提供 2-3 条回复建议
- [ ] 截图推理后原图自动删除，仅留缩略图

---

## 第 11 步：AI 对话增强

**目标**：对话路径补全语音、多截图、回复建议、记忆注入区。

**范围**：
1. 长按语音输入（speech_to_text）
2. 对话中可附加多张截图（走多模态）
3. 回复建议卡片（快捷回复）
4. 新对话记忆注入区折叠组件（接第 7 步）

**完成标准**：
- [ ] 长按输入框可语音输入，识别后填入输入框
- [ ] 对话可附加多张截图，AI 能综合理解
- [ ] AI 回复下方提供 2-3 条快捷回复建议，点击即发送
- [ ] 新对话展开记忆注入区可看到注入了哪些记忆

---

## 第 12 步：CSV 批量导入

**目标**：财富账单、成长学习记录可 CSV 批量导入。

**范围**：
1. `file_picker + csv` 依赖
2. CSV 导入向导：选文件 → 字段映射 → 预览 → 校验 → 导入
3. 支持支付宝/微信账单导出格式
4. 导入结果报告（成功 N 条、失败 N 条及原因）

**完成标准**：
- [ ] 选 CSV 文件后自动识别列，可手动映射到模块字段
- [ ] 预览前 10 条数据，可校验异常（金额非数字、日期格式错）
- [ ] 导入后列表刷新显示新数据
- [ ] 导入失败行有明确错误原因
- [ ] 支持支付宝/微信标准导出格式开箱即用

---

## 第 13 步：模块增强功能

**目标**：各模块完整功能补齐（非基础 CRUD 部分）。

**范围**：
1. **关系**：聊天记录导入（截图识别→结构化）、智能回复建议、约定管理（到期提醒）、人情往来记录、关系图谱
2. **成长**：项目看板（待办/进行中/已完成）、OKR 管理、简历版本化、人脉分析
3. **财富**：月度账单页（分类汇总+趋势）、预算管理（超支提醒）、自然语言查询
4. **思想**：给未来的信（定时解锁）、年度回顾（自动汇总）、双向链接笔记（`[[ ]]`）
5. **健康**：体检报告解析（截图→结构化指标）、健康指标卡（异常高亮）、综合健康分、设备同步（Apple Health/小米）

**完成标准**：
- [ ] 关系图谱在 Web 端可视化（节点=人，边=关系）
- [ ] 约定到期前 1 天推送提醒
- [ ] 财富预算超支时首页提示
- [ ] 自然语言查"上个月吃饭花了多少"能正确返回金额
- [ ] 给未来的信在解锁日期前不可阅读，到期自动解锁
- [ ] 年度回顾能汇总全年思想模块内容
- [ ] 双向链接 `[[笔记名]]` 能跳转
- [ ] 体检报告截图能识别出血脂/血糖等指标并高亮异常项
- [ ] 综合健康分按多维度加权计算
- [ ] 设备同步能拉取 Apple Health / 小米运动数据

---

## 第 14 步：跨模块联动

**目标**：7 类事件通过 EventBus 流转，模块间能相互触发。

**范围**：
1. `lib/events/event_bus.dart` + `events.dart`：事件定义
2. `lib/events/handlers/`：各事件处理器
3. 7 类事件：
   - 联系人添加 → 财富分账 / 思想共读
   - 账单超支 → 成长目标影响
   - 体检异常 → 思想记录感受 / 财富保险建议
   - 目标达成 → 关系通知 / 健康奖励
   - 读后感完成 → 成长学习记录
   - 约定达成 → 财富人情账
   - 年度回顾 → 全模块吸收器
4. Riverpod Listener 监听事件更新 UI

**完成标准**：
- [ ] 新增联系人时，财富模块出现"添加分账"入口
- [ ] 财富超支时，成长模块目标卡显示影响提示
- [ ] 体检异常时，思想模块提示"记录感受"、财富模块提示"保险建议"
- [ ] 目标达成时，关系模块可通知重要他人
- [ ] 年度回顾触发时，自动汇总全模块数据生成回顾

---

## 第 15 步：反馈学习

**目标**：采集用户反馈，调整推荐权重。

**范围**：
1. `lib/ai/feedback/collector.dart`：6 类反馈信号采集（点赞/点踩/采纳/忽略/修改/分享）
2. `lib/ai/feedback/learning_engine.dart`：5 条学习规则（调整推荐权重、TTL、简报优先级等）
3. 学习记录页：展示学习效果
4. 效果边界约束（防止过度学习）

**完成标准**：
- [ ] AI 回复下方有点赞/点踩按钮
- [ ] 推荐内容可标记采纳/忽略
- [ ] 反馈信号被记录到数据库
- [ ] 多次点踩某类推荐后，该类推荐权重下降
- [ ] 学习记录页可查看已应用的规则
- [ ] 学习不会无限放大某权重（有边界约束）

---

## 第 16 步：错误处理与监控

**目标**：AI 错误分类处理 + 熔断 + 监控指标。

**范围**：
1. `lib/ai/error_handler.dart`：4 类错误处理（A 未响应 / B 幻觉越权 / C 调用错误 / D 格式错误）
2. `lib/ai/circuit_breaker.dart`：熔断器（3 次失败冷却 10min，半开探测）
3. `lib/ai/monitor.dart`：错误率 / 延迟 / Token 成本 / 简报生成成功率

**完成标准**：
- [ ] 模型超时/网络错误：重试 1 次（backoff 2s）→ 降级提示
- [ ] AI 幻觉调用不存在的工具：拒绝 + 重试 1 次
- [ ] 工具参数 Schema 错误：不重试，报错修复提示
- [ ] 返回 JSON 格式错误：容错提取 → 重试 1 次
- [ ] 子模型连续失败 3 次后熔断 10min，期间主模型回复"该模块暂不可用"
- [ ] 监控页可查看错误率、平均延迟、Token 成本、简报成功率

---

## 第 17 步：安全与隐私

**目标**：敏感数据加密，AI 调用脱敏，权限管理。

**范围**：
1. `lib/security/secure_storage.dart`：flutter_secure_storage 存 API Key / 用户画像
2. `lib/security/desensitizer.dart`：AI 调用前脱敏（手机号/身份证/金额）
3. `lib/security/permissions.dart`：权限管理
4. SQLCipher 可选加密 SQLite
5. 截图推理后自动删除原图

**完成标准**：
- [ ] API Key 存储在 secure storage，不在普通 SharedPreferences
- [ ] 对话中提到手机号/身份证，发送给 AI 前被脱敏（如 138****1234）
- [ ] 截图推理完成后原图从磁盘删除，仅留缩略图
- [ ] 写操作（删除）必须二次确认
- [ ] 权限请求有明确文案说明用途

---

## 第 18 步：Web 端

**目标**：同一套代码编译 Web，响应式布局 + 关系图谱 + 数据看板 + 自然语言查询。

**范围**：
1. `lib/web/` 响应式布局（LayoutBuilder 桌面/平板/手机）
2. AI 对话 Web 版
3. 数据查看（只读）
4. 关系图谱可视化（graphview）
5. 数据看板大屏
6. 自然语言查询界面

**完成标准**：
- [ ] `flutter build web` 可成功编译
- [ ] 桌面/平板/手机三种宽度下布局合理
- [ ] Web 端可进行 AI 对话
- [ ] Web 端可查看各模块数据（只读）
- [ ] 关系图谱在 Web 端可视化，可拖拽节点
- [ ] 数据看板大屏展示关键指标
- [ ] 自然语言查询界面可输入问题并返回结果

---

## 第 19 步：启动引导与设置

**目标**：首次启动引导 + 完整设置页。

**范围**：
1. 启动引导 5 屏 Onboarding（产品介绍 + 权限请求 + 模型配置）
2. 设置页：账号 / 模型配置 / 数据导出 / 关于
3. 模型配置页（接第 4 步，完善 UI）
4. 模块切换器待处理计数（红点）

**完成标准**：
- [ ] 首次启动显示 5 屏引导，可跳过
- [ ] 引导中可完成 API Key 配置
- [ ] 设置页可切换模型、导出数据、查看关于
- [ ] 模块有未读/待处理时，胶囊切换器显示红点计数

---

## 第 20 步：非功能验收与优化

**目标**：非功能需求全量验收 + 性能优化。

**范围**：
1. 本地优先验证（断网下基础 CRUD 可用）
2. 离线可用验证
3. 流式响应性能（首字 < 1s）
4. 端到端加密同步（可选云同步）
5. 成本监控（对照 `03-tech.md` §十三 估算）
6. 性能监控（错误率/延迟/Token 用量）
7. 全量回归测试
8. **数据安全回归（必测）**：模拟一次"装旧版→录全量数据→装新版→验证零丢失"的完整升级流程
9. **模块化回归（必测）**：验证新增模块/工具/子模型/事件均不改主框架

**完成标准**：
- [ ] 断网状态下，手动录入、列表查看、详情编辑均可用
- [ ] AI 对话首字响应 < 1s（网络正常）
- [ ] 启用云同步后，多设备数据一致（端到端加密）
- [ ] 月度 Token 成本在监控页可查，符合估算区间
- [ ] 错误率 < 5%
- [ ] 全部前 19 步完成标准重新通过验收
- [ ] **数据安全回归**：装当前发布版 → 录入各模块各 20 条以上真实数据（含记忆/向量/简报）→ 安装新版本（schemaVersion 升级）→ 启动后全部数据完整可读可写，备份目录生成，**零数据丢失**
- [ ] **模块化回归**：新增一个假业务模块 + 一个假 AI 工具 + 一个假子模型 + 一个假事件，全部通过注册接入且可用，**git diff 主框架文件为空**（只动了 `lib/modules/` 和注册表）

---

## 附录：步骤依赖关系

```
1 骨架 → 2 存储 → 3 CRUD UI ──┐
                              ├→ 4 AI对话 → 5 工具 → 6 RAG → 7 记忆 → 8 多智能体 → 9 简报
                              │                                          ↓
                              └→ 10 浮窗截图（依赖 4）                   13 模块增强（依赖 8）
                                                                         ↓
                              11 对话增强（依赖 4,7）                    14 跨模块联动（依赖 13）
                                                                         ↓
                              12 CSV 导入（依赖 2）                      15 反馈学习（依赖 8）
                                                                         ↓
                                                                         16 错误监控（依赖 8）
                                                                         ↓
                                                                         17 安全（贯穿）
                                                                         ↓
                                                                         18 Web（依赖 13）
                                                                         ↓
                                                                         19 引导设置（依赖 4）
                                                                         ↓
                                                                         20 非功能验收（依赖全部）
```

**可并行步骤**：
- 第 2 步存储层 与 第 3 步 CRUD UI（UI 先用 mock 数据，存储好后切换）
- 第 10/11/12 步 可在多智能体（第 8 步）完成后并行
- 第 17 步安全可在任意阶段穿插，最后统一验收
