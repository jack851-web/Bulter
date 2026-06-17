# Commit 1 — 初始化项目骨架与设计系统

## 基本信息

| 字段       | 值                                          |
|------------|---------------------------------------------|
| 版本号     | **0.1.0**（SemVer，开发期首发）              |
| 步骤       | Step 1 / 20（见 [plan.md](../../doc/first/plan.md)） |
| Commit 类型 | `feat(scaffold)`                           |
| 模块范围   | `core`（项目级）                            |
| 风险等级   | 🟢 低（新增文件，无破坏性变更）              |

## Commit Message

```
feat(scaffold): initialize project skeleton and design system (step 1)

建立可运行的 Flutter 空壳与设计 Token 体系，定义模块化抽象接口，
实现 capsule 切换 + 底部 Tab + AI FAB 主壳路由。后续 Step 2 起
可在此骨架上逐步填充数据层、AI、浮窗等能力。

完成 plan.md Step 1 全部 9 条验收标准。
```

## 变更内容

### 新增

| 路径                                       | 作用                                                                  |
|--------------------------------------------|-----------------------------------------------------------------------|
| `src/pubspec.yaml`                         | Flutter 3.24+ 依赖声明（riverpod / go_router / freezed / drift / hive / dio / sqlite-vec 等）|
| `src/analysis_options.yaml`                | Dart 静态分析规则                                                     |
| `src/lib/main.dart`                        | App 入口：`ProviderScope` + 主题加载 + GoRouter 挂载                  |
| `src/lib/app_bootstrap.dart`               | 启动时注册 7 个模块、刷新 `ToolRegistry` 与 `SubAgentRegistry`         |
| `src/lib/theme/tokens.dart`                | 设计 Token：画布 #FAF6EE、CTA 纯黑、6 模块品牌色、间距/圆角/字号      |
| `src/lib/router/router.dart`               | go_router + StatefulShellRoute，按 `ModuleRegistry.capsuleModules` 动态生成分支 |
| `src/lib/router/app_shell.dart`            | 主壳组件（capsule + 内容 + 底部 Tab + AI FAB）                        |
| `src/lib/components/*.dart`                | 通用 UI 组件：`capule_switcher` / `bottom_tab` / `fab_chat` / `bulter_scaffold` / `ai_insight_card` / `module_card` / `empty_state` |
| `src/lib/features/chat/chat_page.dart`     | AI 对话占位页                                                         |
| `src/lib/features/settings/settings_page.dart` | 设置占位页                                                          |
| `src/lib/modules/bulter_module.dart`       | 模块化抽象接口（id / brandColor / entryRoute / subAgent / tools / briefingGenerator）|
| `src/lib/modules/registry.dart`            | `ModuleRegistry` 单例，运行时注册 / 列举模块                          |
| `src/lib/modules/{butler,relationship,growth,wealth,thought,health,demo}/` | 7 个模块各自实现 `BulterModule` 接口                 |
| `src/lib/ai/tools/tool_registry.dart`      | AI 工具注册表（主模型 = 全量 + 写；子模型 = 只读隔离实例）             |
| `src/lib/ai/sub_agents/sub_agent_registry.dart` | 子模型注册表，按模块构造隔离 `ToolRegistry`                        |
| `src/lib/events/event_bus.dart`            | 跨模块事件总线（同步 `publish` + `publishAsync`）                     |
| `src/test/widget_test.dart`                | 验证 `bootstrapApp` 注册 7 个模块成功                                 |
| `src/android/` / `src/ios/` / `src/web/`   | `flutter create` 生成的多平台壳                                       |
| `doc/first/`                               | 设计文档：架构、需求、技术、20 步计划、产品原型图                     |
| `doc/code-quality/code_review_report.md`   | Step 1 收尾的代码审查报告（2 严重 + 9 一般 + 7 优化 = 18 项）         |
| `README.md`                                | 项目说明：介绍 / 技术栈 / 启动方式 / 目录结构 / 贡献规范              |
| `.gitignore`                               | 忽略 `dart_tool` / `build` / `pub-cache` / `.trae` 等                 |

### 修改

- `README.md`：从单行 `# Bulter` 替换为完整项目说明。
- `.gitignore`：在 Flutter 默认模板基础上忽略 `.trae/`（IDE 工作区配置非源码）。

## 范围与影响

- **不涉及**已有公共 API 的破坏性变更（仓库此前仅有 "first commit"，无业务代码）。
- **首次引入**模块化架构约定：`BulterModule` 抽象接口、`ModuleRegistry` 动态注册。
- **首次引入**设计 Token 体系：后续 UI 变更须以 Token 为准，不允许硬编码颜色/间距。
- **首次引入**子模型工具隔离：`ToolRegistry.fresh()` 为子模型构造独立实例，过滤写工具。

## 验收 / 验证方式

| 验收项                                                                | 结果 |
|-----------------------------------------------------------------------|------|
| `flutter analyze`                                                     | ✅ No issues found |
| `flutter test`                                                        | ✅ All tests passed |
| 启动后顶部 capsule 在 7 个模块间切换                                   | ✅   |
| 底部 Tab 切换 / FAB 点击                                              | ✅   |
| 画布 #FAF6EE + 主按钮纯黑                                             | ✅   |
| 6 模块品牌色 + Demo 验证模块均出现在 capsule                           | ✅   |
| `BulterModule` / `ModuleRegistry` / `ToolRegistry` / `SubAgentRegistry` / `EventBus` 接口与占位实现齐备 | ✅ |
| 新增模块 = 新建目录 + `registerAll` 加一行注册，**不动 router/主框架** | ✅（已用 Demo 模块验证） |

## 已知遗留

不在 Step 1 范围内、按 plan.md 顺延到后续步骤：

- 6 个业务模块的 `onRegister()` / `onDispose()` 均为空实现。
- 各模块 `tabs.builder` 暂为 `const SizedBox.shrink()`，Step 3 起填充真实 CRUD 页。
- `BulterModule` 接口未声明 `dao` 字段（plan.md 范围第 7 条要求），Step 2 接入 Drift 时补齐。
- `pubspec.yaml` 提前引入了 `drift` / `hive` / `sqlite_vec` / `dio` / `flutter_svg` / `google_fonts` 等 Step 1 未使用的依赖，编译时间略长，将在 Step 2/4/5 收尾时按需瘦身。
- 代码审查报告中的 16 项一般/优化问题未在本步处理（按团队约定由对应 Step 闭环）。

## 后续动作

- `0.2.0` → Step 2「本地数据存储层」（Drift + Hive + 迁移框架 + 自动备份）。
- 详见 [doc/first/plan.md](../../doc/first/plan.md) §"第 2 步"。
