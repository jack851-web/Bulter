# Bulter

> 个人 / 家庭的中枢型 AI 助理 App。
> Flutter 跨端（iOS / Android / Web）+ 多智能体架构（1 主模型 Orchestrator + N 子模型 Specialist），模块化、插件化，数据本地优先。

---

## 项目介绍

Bulter 是一款"以用户本人为根"的中枢型应用：用一个主模型协调六大业务模块（**关系 / 成长 / 财富 / 思想 / 健康**）和**记忆系统**，通过**浮窗截图、AI 对话、手动录入**三条输入路径，把零散的人、事、账、读后感、健康数据沉淀为可被 AI 检索、推理、串联的长期资产。

### 设计目标

- **数据主权**：所有用户数据本地存储，AI 仅作为调度者与推理者；不依赖任何云端数据库。
- **模块化**：新增业务模块 = 新建目录 + 注册一行，**不修改主框架**。
- **多智能体**：主模型做编排，子模型各管一摊，写工具按模块隔离。
- **可恢复**：数据库带 schemaVersion 与迁移框架，升级前自动备份，绝不丢数据。

### 路线图

详细 20 步实施计划见 [doc/first/plan.md](file:///d:/others/app/Bulter/doc/first/plan.md)。当前进度见 `doc/git_log/`。

| 版本   | 范围           | 状态        |
|--------|----------------|-------------|
| 0.1.0  | 项目骨架 + 设计系统（Step 1）| ✅ 已完成   |
| 0.2.0  | 本地数据存储层（Step 2）| ✅ 已完成   |
| 0.2.1  | 自建 sqlite-vec FFI 插件（修复 Android 构建）| ✅ 已完成   |
| 0.3.0  | 六大业务模块基础 CRUD UI（Step 3）| ✅ 已完成   |
| 0.3.1  | 各模块主页 UI 与产品原型对齐（Step 3 增量）| ✅ 已完成   |
| 0.4.0  | AI 调用基础（单 LLM 流式对话，Step 4）+ 全部图标改 SVG | ✅ 已完成   |
| ...    | 见 plan.md     |             |
| 1.0.0  | 首个全功能发布 |             |

---

## 技术栈

| 类别       | 技术                                                                 |
|------------|----------------------------------------------------------------------|
| 跨端框架   | Flutter 3.24+ / Dart 3.5+                                            |
| 状态管理   | Riverpod 2.5+                                                        |
| 路由       | go_router 14+（StatefulShellRoute 索引化模块）                       |
| 数据模型   | freezed + json_serializable                                          |
| 本地数据库 | Drift（SQLite ORM）+ sqlite3                                         |
| KV 存储    | Hive                                                                 |
| 向量检索   | sqlite-vec（RAG 语义记忆）                                            |
| 网络       | dio                                                                  |
| 设计资源   | flutter_svg、google_fonts                                            |
| 工具/图标  | Material Icons（默认）+ cupertino_icons                               |

架构原则详见 [doc/first/03-tech.md](file:///d:/others/app/Bulter/doc/first/03-tech.md) 与 [doc/first/01-architecture.md](file:///d:/others/app/Bulter/doc/first/01-architecture.md)。

---

## 启动方式

### 环境要求

- Flutter SDK ≥ 3.24
- Dart SDK ≥ 3.5
- Android Studio / Xcode（按目标平台）
- Git ≥ 2.30

### 拉取与运行

```bash
# 1. 克隆仓库
git clone <repo-url> bulter
cd bulter

# 2. 拉取依赖（项目根目录内的 src/ 是 Flutter 工程）
cd src
flutter pub get

# 3. 静态检查
flutter analyze

# 4. 跑测试
flutter test

# 5. 启动（按目标平台任选其一）
flutter run                  # 默认设备
flutter run -d chrome        # Web
flutter run -d <device-id>   # 列出设备：flutter devices
```

### 验证模块化

启动后应能：

- 顶部胶囊切换器在 **Bulter / 关系 / 成长 / 财富 / 思想 / 健康 / Demo** 7 个入口之间切换。
- 底部 Tab 在每个模块主页内可切换。
- 右下角 AI FAB 可点击进入对话页。
- 画布底色 `#FAF6EE`，主按钮为纯黑。

> Demo 模块是 Step 1 留下的"模块化验证位"，可作为新增模块的参考模板。

### 当前进度（Step 2 完成后）

- **数据层**：Drift（22 张业务表 + 7 个 DAO）/ Hive（4 个 KV Box）/ sqlite-vec（RAG 语义记忆）三套存储统一通过 `BulterModule.tableClasses` / `daoClasses` 动态注册，**新增模块不改主框架**。
- **数据安全**：`BackupService` 升级前自动备份、失败回滚、7 天过期清理；`DataExportService` 提供 JSON 导出 / 导入兜底。
- **测试覆盖**：6 个测试文件、**26 个 case 全绿**，覆盖模块注册 / Hive 初始化 / Drift 迁移 / 备份回滚 / DAO CRUD + Stream / 导出导入 round-trip。
- **降级策略**：sqlite-vec 在桌面 / 测试环境不可用时静默降级，不阻断主流程。

详细审查与遗留问题见 [doc/code-quality/code_review_report.md](file:///d:/others/app/Bulter/doc/code-quality/code_review_report.md)。

---

## 目录结构

```
Bulter/
├── README.md                       ← 本文件
├── .gitignore
├── .trae/                          ← IDE 工作区配置
├── doc/
│   ├── first/                      ← 早期设计文档
│   │   ├── 01-architecture.md      ← 架构总览
│   │   ├── 02-requirements.md      ← 需求规格
│   │   ├── 03-tech.md              ← 技术选型
│   │   ├── plan.md                 ← 20 步实施计划
│   │   └── figures/                ← 产品原型图
│   ├── code-quality/               ← 代码审查报告
│   │   └── code_review_report.md
│   └── git_log/                    ← 版本迭代日志（每次提交一份）
│       └── commit_n.md
└── src/                            ← Flutter 工程
    ├── android/                    ← Android 平台壳
    ├── ios/                        ← iOS 平台壳
    ├── web/                        ← Web 平台壳
    ├── plugins/                    ← 本地 FFI 插件（不依赖外部 pub 包）
    │   └── bulter_sqlite_vec/      ← vendored sqlite-vec v0.1.7-alpha.3
    │       ├── src/                ← sqlite-vec.c / sqlite-vec.h / sqlite3ext.h / sqlite3.h
    │       └── android/ ios/ linux/ macos/ windows/
    ├── test/                       ← 单元 & Widget 测试
    ├── analysis_options.yaml
    ├── pubspec.yaml                ← 依赖与资源声明
    └── lib/
        ├── main.dart               ← 应用入口
        ├── app_bootstrap.dart      ← 启动时注册模块 / 工具 / 子 Agent
        ├── theme/
        │   └── tokens.dart         ← 设计 Token（颜色 / 间距 / 圆角 / 字号）
        ├── router/
        │   ├── router.dart         ← go_router 配置
        │   └── app_shell.dart      ← 主壳（capsule + body + bottom tab + FAB）
        ├── components/             ← 通用 UI 组件
        │   ├── capule_switcher.dart
        │   ├── bottom_tab.dart
        │   ├── fab_chat.dart
        │   ├── bulter_scaffold.dart
        │   ├── ai_insight_card.dart
        │   ├── module_card.dart
        │   └── empty_state.dart
        ├── features/               ← 横跨多模块的通用 feature
        │   ├── chat/chat_page.dart
        │   └── settings/settings_page.dart
        ├── modules/                ← 业务模块（每个模块自包含子目录）
        │   ├── bulter_module.dart  ← 抽象接口
        │   ├── registry.dart       ← ModuleRegistry 单例
        │   ├── module_placeholder_page.dart
        │   ├── butler/             ← Bulter 中枢模块
        │   ├── relationship/       ← 关系模块
        │   ├── growth/             ← 成长模块
        │   ├── wealth/             ← 财富模块
        │   ├── thought/            ← 思想模块
        │   ├── health/             ← 健康模块
        │   └── demo/               ← 验证用假模块
        ├── ai/
        │   ├── tools/
        │   │   └── tool_registry.dart      ← AI 工具注册表
        │   └── sub_agents/
        │       └── sub_agent_registry.dart ← 子模型注册表
        ├── events/
        │   └── event_bus.dart      ← 跨模块事件总线
        ├── db/                     ← Drift 数据库（Step 2 引入）
        │   ├── app_database.dart   ← @DriftDatabase 总入口
        │   ├── app_database.g.dart ← 生成代码
        │   ├── connection.dart     ← 打开连接 + sqlite-vec 扩展注册
        │   ├── backup.dart         ← 升级前备份 + 失败回滚 + 过期清理
        │   └── vector_store.dart   ← vec0 虚拟表（DDL / 插入 / 检索）
        ├── storage/                ← Hive Box（Step 2 引入）
        │   ├── box_names.dart      ← Box 名称 + versionId 集中管理
        │   └── storage_init.dart   ← initStorage(subdir) 入口
        ├── security/               ← 数据安全（Step 2 引入）
        │   └── data_export.dart    ← JSON 导出 / 导入兜底
        ├── models/                 ← （后续步骤）freezed 数据模型
        ├── providers/              ← （后续步骤）Riverpod Provider
        └── orchestrator/           ← （后续步骤）主模型编排器
```

---

## 贡献与版本管理

- **版本号**：遵循 [SemVer 2.0.0](https://semver.org/lang/zh-CN/)。当前位于 `0.x.y` 阶段（开发期，API 随时变更），首个稳定版为 `1.0.0`。
- **Commit 规范**：[Conventional Commits 1.0](https://www.conventionalcommits.org/zh-hans/)。
  - `feat(scope)` 新增功能
  - `fix(scope)` 缺陷修复
  - `refactor(scope)` 重构（无行为变化）
  - `docs(scope)` 文档
  - `chore(scope)` 构建/工具/杂项
- **每次提交必须在 `doc/git_log/commit_n.md` 留痕**（n 为本次提交序号），记录变更内容、影响范围、验证方式。

详细的命名与提交模板见 [doc/first/plan.md](file:///d:/others/app/Bulter/doc/first/plan.md) §"使用方式"。

---

## 许可

待定。
