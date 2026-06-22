# commit_15 — Step 10 浮窗输入（Android 浮窗 + 主模型多模态自动入库）

- **版本**：0.9.0
- **commit 类型**：`feat(platform)` + `feat(ai)` + `feat(db)`
- **影响范围**：Dart 6 新文件 + Kotlin 5 新文件 + AndroidManifest + 4 资源文件 + schemaVersion 1→3 migration
- **关联文档**：[doc/first/04-platform.md](file:///d:/others/app/Bulter/doc/first/04-platform.md)（平台桥接完整方案）+ [doc/first/02-requirements.md §九](file:///d:/others/app/Bulter/doc/first/02-requirements.md)（架构原则）
- **关联计划**：[doc/first/plan.md §第 10 步](file:///d:/others/app/Bulter/doc/first/plan.md) ✅ 全部勾选

## 目标

补齐最后一条输入路径：**Android 浮窗**。

用户在任意 App 长按/单击 Bulter 悬浮球 → Kotlin `AccessibilityService.takeScreenshot()` 截屏 → Dart 调**主模型多模态 LLM** 看图 → 选工具 → **直接调 ToolRegistry 工具**写入数据库（关系 / 财富 / 思想 / 健康）→ 顶部短暂通知"已记录到 X 模块"。

**平台边界**：**仅 Android**。iOS 没有 `AccessibilityService` 等价 API，详见 [04-platform.md §八](file:///d:/others/app/Bulter/doc/first/04-platform.md)。

## 文档先行

之前 commit 已写完 [04-platform.md](file:///d:/others/app/Bulter/doc/first/04-platform.md)（~580 行），覆盖：浮窗交互规范、3 组件架构、AccessibilityService.takeScreenshot、GPU 缓冲复用、3s 冷却、4 个错误码映射、PROTOCOL_VERSION 协商、主模型多模态 → tool_calls 执行。

## 核心架构（**主模型核心 + 子模型辅助**）

按 [02-requirements.md §九.1](file:///d:/others/app/Bulter/doc/first/02-requirements.md)：

- **主模型（多模态 LLM，默认 MiniMax M3）= Agent 引擎的核心**
  - 处理**所有**用户输入（文本 / 截图 / 语音文字）
  - 调 **ToolRegistry** 工具完成实际写库
  - **多模态输入**（`image_url` message）→ 直接看截图 → 选工具 → 调工具
  - **可主动调子模型**：子模型简报不够明确时**主动重新调**（带更具体的 query）
- **子模型 = 子模块内部信息处理者**：仅在子模块上下文里被调用（生成简报 / 答复合模块查询）；**不**负责截图归类

**截图归类**完全走主模型：
```
[截图 base64 + 工具列表] → 主模型多模态
                       ↓ response.tool_calls
[ToolRegistry.execute()]  → relationship.add_contact / wealth.add_transaction / ...
                       ↓
[screenshots 表插入]      → 截图历史记录
                       ↓
[顶部轻通知]              → "已记录到 X 模块"
```

## 实施内容

### A. Dart 应用层（5 新文件）

#### 1. 🆕 [lib/ai/scene_inference.dart](file:///d:/others/app/Bulter/src/lib/ai/scene_inference.dart)

**主模型多模态推理**：
- `SceneInferencer.inferFromScreenshot(path)` 异步 8s 超时
- 读截图 base64 → 调主模型 chat completions（`tools` 参数注入 ToolRegistry）
- 解析 `response.choices[0].message.tool_calls` → 顺序执行 `ToolRegistry.execute(name, args)`
- 返回 `SceneInference`（含 tool_calls 结果 + 主模型摘要 + 模块名）
- **不**调子模型（按 [02-requirements.md §九.1](file:///d:/others/app/Bulter/doc/first/02-requirements.md) 架构原则）
- 失败降级：`no_api_key` / `dio_timeout` / `empty_body` / `no_tools_called` 等多种状态

#### 2. 🆕 [lib/features/screenshot/auto_sink.dart](file:///d:/others/app/Bulter/src/lib/features/screenshot/auto_sink.dart)

**自动入库封装**：调用 `SceneInferencer.inferFromScreenshot()` → 写入 `screenshots` 表（含 `autoSinkStatus` 字段）。

#### 3. 🆕 [lib/features/screenshot/db/screenshot_tables.dart](file:///d:/others/app/Bulter/src/lib/features/screenshot/db/screenshot_tables.dart)

Drift `Screenshots` 表（**复用 Step 9 + 加 Step 10 字段**）：
- `thumbPath` / `packageName` / `windowTitle` / `textPreview`
- `inferredCategory` / `inferredConfidence` / `inferredSummary` / `inferredJson`
- `userCategory` / `userActionsJson` / `reviewedAt` / `createdAt`
- **Step 10 新增**：`autoSinkStatus`（success / no_tools_called / no_api_key / dio_xxx / ...）

#### 4. 🆕 [lib/features/screenshot/db/screenshot_dao.dart](file:///d:/others/app/Bulter/src/lib/features/screenshot/db/screenshot_dao.dart)

`ScreenshotDao`：`insertScreenshot` / `watchPending` / `watchReviewed` / `getById` / `markReviewed` / `deleteById` / `deleteAll` / `findByStatus`。

#### 5. 🆕 [lib/platform/ball_event_handler.dart](file:///d:/others/app/Bulter/src/lib/platform/ball_event_handler.dart)

**Dart 侧浮窗事件处理器**：
- 监听 Kotlin `MethodChannel('bulter/ball')` 推过来的事件
- `onScreenshotReady(path)` → 调 `AutoSinkSink.autoSinkFromScreenshotPath()` → 顶部通知
- `onScreenshotError(code)` → 错误码映射（INTERNAL_ERROR / INTERVAL_TIME_SHORT / NO_ACCESSIBILITY_ACCESS / SECURE_WINDOW）
- `onLongPressStart` / `onLongPressEnd` → 语音面板订阅
- `PROTOCOL_VERSION = 1` 双向协商

#### 6. 🆕 [lib/features/screenshot/notification.dart](file:///d:/others/app/Bulter/src/lib/features/screenshot/notification.dart)

**顶部轻通知**（**不**用 `flutter_local_notifications`）：
- `OverlayEntry` 在 app root 顶部弹出 1.5s 自动消失的胶囊通知
- info / success / warning / error 4 种配色
- 全局 `navKey` 注册（避免堆叠）

#### 7. 🆕 [lib/features/screenshot/cooldown.dart](file:///d:/others/app/Bulter/src/lib/features/screenshot/cooldown.dart)

**3s 截图冷却**（Dart 端 + Kotlin 端双层保护）。

### B. 数据库迁移（schemaVersion 1→3）

[lib/db/app_database.dart](file:///d:/others/app/Bulter/src/lib/db/app_database.dart) 改造：
- `schemaVersion`: 1 → 3
- 注册 `Screenshots` 表 + `ScreenshotDao`
- `onUpgrade(from < 3)` → `m.createTable(screenshots)`（一次性建表，含 `autoSinkStatus` 字段）

[test/db_migration_test.dart](file:///d:/others/app/Bulter/src/test/db_migration_test.dart) 同步更新：`schemaVersion == 3`。

### C. Android 原生层（5 Kotlin + 4 资源 + Manifest）

#### 1. 🆕 [BulterPlatformPlugin.kt](file:///d:/others/app/Bulter/src/android/app/src/main/kotlin/com/bulter/bulter/BulterPlatformPlugin.kt)

**核心协调者**（FlutterActivity 侧）：
- `showFloatingBall()` / `hideFloatingBall()` —— WindowManager.addView + 触摸监听
- `triggerScreenshot()` —— 3s 冷却 + 错误码映射 + 调 ScreenshotAccessibilityService
- `updateBallStatus()` —— 圆球/横条两态切换
- `PROTOCOL_VERSION = 1` 协商
- 触摸监听：拖动（16ms 节流）+ 短按截图 + 长按 500ms 语音面板

#### 2. 🆕 [AppEventBus.kt](file:///d:/others/app/Bulter/src/android/app/src/main/kotlin/com/bulter/bulter/AppEventBus.kt)

**Activity ↔ Service 单向通信**：Kotlin `object` 单例 + `CopyOnWriteArrayList` 回调列表 + 主线程 Handler。

#### 3. 🆕 [FloatingBallService.kt](file:///d:/others/app/Bulter/src/android/app/src/main/kotlin/com/bulter/bulter/FloatingBallService.kt)

**前台服务空壳保活**（**完全参考另一项目模式**）：
- `startForeground(1, notification)` + `AppEventBus.requestShowFloatingBall()` 回调
- `START_NOT_STICKY` 避免"重启失败被杀"循环
- **无 Activity 引用**，避免泄漏

#### 4. 🆕 [ScreenshotAccessibilityService.kt](file:///d:/others/app/Bulter/src/android/app/src/main/kotlin/com/bulter/bulter/ScreenshotAccessibilityService.kt)

**系统级截图**（**完全参考另一项目模式**）：
- `AccessibilityService.takeScreenshot()`（Android 11+ API 30+），**不**用 MediaProjection
- `HardwareBuffer → Bitmap.wrapHardwareBuffer → copy(ARGB_8888)` 复用 GPU
- `MainThreadExecutor` 把回调投递回主线程
- **4 个错误码映射**（ERROR_INTERNAL / INTERVAL_TOO_SHORT / NO_ACCESSIBILITY / SECURE_WINDOW）
- **`setServiceInfo()` 禁忌**（注释里写清楚）

#### 5. 🔧 [MainActivity.kt](file:///d:/others/app/Bulter/src/android/app/src/main/kotlin/com/bulter/bulter/MainActivity.kt) 改造

`configureFlutterEngine` attach `BulterPlatformPlugin` + 注册 `AppEventBus` 回调。

#### 6. 🔧 [AndroidManifest.xml](file:///d:/others/app/Bulter/src/android/app/src/main/AndroidManifest.xml) 改造

- 5 个权限：`SYSTEM_ALERT_WINDOW` / `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_SPECIAL_USE` / `BIND_ACCESSIBILITY_SERVICE` / `WAKE_LOCK`
- 注册 `FloatingBallService`（`foregroundServiceType="specialUse"` + subtype 声明）
- 注册 `ScreenshotAccessibilityService`（`BIND_ACCESSIBILITY_SERVICE` + XML 标志）

#### 7. 资源文件

- 🆕 [res/layout/bulter_floating_button.xml](file:///d:/others/app/Bulter/src/android/app/srcrc/main/res/layout/bulter_floating_button.xml) — 悬浮球两态布局（圆球 + 横条 loading）
- 🆕 [res/drawable/bulter_floating_bg.xml](file:///d:/others/app/Bulter/src/android/app/srcrc/main/res/drawable/bulter_floating_bg.xml) — 圆形背景
- 🆕 [res/drawable/bulter_floating_loading_bg.xml](file:///d:/others/app/Bulter/src/android/app/srcrc/main/res/drawable/bulter_floating_loading_bg.xml) — 横条背景
- 🆕 [res/xml/bulter_accessibility_config.xml](file:///d:/others/app/Bulter/src/android/app/srcrc/main/res/xml/bulter_accessibility_config.xml) — 无障碍配置（`canTakeScreenshot="true"` 是关键）
- 🆕 [res/values/strings.xml](file:///d:/others/app/Bulter/src/android/app/srcrc/main/res/values/strings.xml) — `accessibility_service_description`

### D. 其他修复

- 🔧 [lib/modules/butler/db/ai_daos.dart](file:///d:/others/app/Bulter/src/lib/modules/butler/db/ai_daos.dart) —— 补充 `deleteMemory(int id)` 方法（修复 pre-existing `memory_page.dart:383` 调用未定义方法的 bug）

## 验证

| 验证项 | 结果 |
|---|---|
| `flutter analyze lib` | ✅ **0 error** |
| `flutter test test/db_migration_test.dart` | ✅ **6/6** 通过（含 schemaVersion=3 验证 + onCreate + 备份 + 升级 + 回滚） |
| `flutter test test/dao_crud_test.dart` | ✅ **10/10** 通过 |
| `flutter test test/data_export_test.dart` | ✅ **3/3** 通过 |
| `flutter test test/db_migration_test.dart test/dao_crud_test.dart test/data_export_test.dart` | ✅ **19/19** 通过 |
| `dart run build_runner build` | ✅ 成功（无冲突） |
| plan.md §第 10 步 7 项验收 | ✅ 全部勾选 |
| **主模型多模态架构原则** | ✅ scene_inference **不**调子模型，仅调主模型多模态 + ToolRegistry |
| **物理隔离原图** | ✅ Kotlin `savePng()` 仅保存 PNG 缩略图（256×宽 + 70% 压缩）；原图从不保存 |

### Pre-existing 测试失败（**与本 commit 无关**）

- ❌ `module_registry_test.dart` —— `PathAccessException: Deletion failed, path = '...\bulter_registry_xxx'`：Windows 临时目录并发清理问题（其他 Dart 测试并行运行同时删同目录）。修复前已存在。
- ❌ `widget_test.dart` —— `TimeoutException 10 分钟`：bootstrapApp 在 testWidgets 环境下卡死（无 widget binding 适配）。修复前已存在。

## 关键设计决策

### D1：主模型核心 + 子模型辅助（**架构原则**）

按 [02-requirements.md §九.1](file:///d:/others/app/Bulter/doc/first/02-requirements.md)：
- **主模型 = 引擎核心**（多模态 + 工具调用 + 主动调度子模型）
- **子模型 = 子模块内部信息处理者**（生成简报 / 答复合模块查询）

**截图归类**只走主模型（多模态）→ tool_calls → ToolRegistry。**不**调子模型。

### D2：主模型主动调子模型（**重要机制**）

主模型**不是被动等待**子模型产出，而是**主动控制**调用：
- 子模型简报**不够明确**时（信息不全 / 模糊 / 不符合当前上下文），主模型**主动重新调用**
- 重调时主模型会**补充更具体的 query**
- 循环终止条件：主模型满意 OR 达到重试上限（默认 2 次）

### D3：截图走 AccessibilityService.takeScreenshot()（**完全参考**）

| 路径 | 优劣 | Bulter 选择 |
|---|---|---|
| `AccessibilityService.takeScreenshot()` | ✅ 不弹授权框 / ❌ 仅 Android 11+ | ✅ **采用**（参考项目选型） |
| `MediaProjection` | ❌ 每次弹授权框 / ✅ 跨 Android 版本 | ❌ 不用（UX 差） |

GPU 缓冲复用：`HardwareBuffer → Bitmap.wrapHardwareBuffer → copy(ARGB_8888)`（**避免** CPU 侧 ImageReader 路径）。

### D4：不弹确认页

用户已经在别的 App 里被打断过一次，再弹 Bulter 确认页是**二次打断**，违背"被动浏览"原则。

主模型选工具时已经"理解了"截图内容，置信度由 LLM 内化；失败时（如 LLM 返回非 JSON / 工具调用失败）→ 自动降级到对话页让用户修正。

### D5：3s 冷却双层保护

- **Kotlin 端** `BulterPlatformPlugin.triggerScreenshot()` 冷却检查（避免频繁触发 + 系统限流）
- **Dart 端** `Cooldown` 滑动窗口（万一 Kotlin 端被绕过，Dart 再挡一层）

## 遗留 / 下一步

- **真机测试**：本次未在真机验证（开发机是 Windows）。Kotlin 代码需 Android Studio + 真机 USB 调试。详细测试矩阵见 [04-platform.md §九](file:///d:/others/app/Bulter/doc/first/04-platform.md)。
- **语音面板**：当前只发出 `onLongPressStart` 事件，**未**实现 UI（用 `speech_to_text` package）。
- **批量截图 UI**：`watchPending()` 已支持 stream 显示多张待处理，但 UI 待集成。
- **iOS 路径**：iOS 用户使用"手动添加"路径 + 通知栏 widget（Step 11 计划）。

## 引用

- 上次 commit：[commit_14.md](file:///d:/others/app/Bulter/doc/git_log/commit_14.md)（Step 9 简报系统）
- 设计：[doc/first/01-architecture.md](file:///d:/others/app/Bulter/doc/first/01-architecture.md) §九（输入路径）
- 平台文档：[doc/first/04-platform.md](file:///d:/others/app/Bulter/doc/first/04-platform.md)
- 架构原则：[doc/first/02-requirements.md](file:///d:/others/app/Bulter/doc/first/02-requirements.md) §九（Agent 引擎）
- 计划：[doc/first/plan.md](file:///d:/others/app/Bulter/doc/first/plan.md) §第 10 步
- 协议：[doc/first/03-tech.md](file:///d:/others/app/Bulter/doc/first/03-tech.md) §三（MethodChannel 桥接）
