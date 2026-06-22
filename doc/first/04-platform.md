# Bulter 平台桥接（Platform Bridge）— Step 10 配套文档

> **范围**：本文档描述 Step 10（**浮窗输入路径**）所依赖的 **Android 原生层** + **Flutter 桥接层** 的完整技术方案。
>
> **iOS 范围**：**暂不实现**。iOS 系统限制（无 `AccessibilityService` 等价物、沙盒限制、ScreenCapture 需要 ReplayKit）让"任意 App 浮窗 + 截图"在 iOS 上不可行。iOS 用户可使用"手动添加"路径（Step 3）作为替代。
>
> **生效版本**：0.9.0+
>
> **核心架构**：**两个独立系统服务 + 1 个协调者**。悬浮球与截图解耦，前台服务只负责"通知保活"，AccessibilityService 负责"系统级截图"，Activity 协调两者 + 通信 Flutter。

---

## 一、组件总览

### 1.1 三组件架构

| 组件 | 角色 | 类型 |
|---|---|---|
| `MainActivity` | 浮窗管理 + 截图触发 + Dart 通信 | `FlutterActivity` |
| `FloatingBallService` | 前台服务，**空壳**——只 `startForeground` 维持通知保活 + 通过 `AppEventBus.requestShowFloatingBall()` 回调到 Activity 真正 `addView` | `Service`（foreground） |
| `ScreenshotAccessibilityService` | **系统级截图**（用 `AccessibilityService.takeScreenshot()` —— Android 11+，**不用** MediaProjection 避免弹授权框） | `AccessibilityService` |

### 1.2 三层职责

```
┌─────────────────────────────────────────────────────────────┐
│  Android 原生层 (Kotlin)                                     │
│  ─────────────────────                                       │
│  MainActivity ─── 浮窗管理 (WindowManager) ─── 截图触发      │
│       │                       │                       │      │
│       │                       │                       ↓      │
│       │                       │    ScreenshotAccessibilityService  │
│       │                       │    (AccessibilityService.takeScreenshot) │
│       │                       │                       │      │
│       │                       ↓                       │      │
│       │              FloatingBallService              │      │
│       │              (前台服务 · 空壳保活)            │      │
│       │                                                │      │
│       ↓                                                ↓      │
│  dartChannel.invokeMethod("onScreenshotReady", path)         │
└─────────────────┬───────────────────────────────────────────┘
                  │ MethodChannel "bulter/ball"
┌─────────────────▼───────────────────────────────────────────┐
│  Flutter 桥接层 (Dart)                                        │
│  ─────────────────────                                       │
│  • lib/platform/ball_event_handler.dart                      │
│    监听 onScreenshotReady → 复用 Step 8 V2 单次多任务 AI    │
│  • lib/ai/scene_inference.dart  多模态推理（复用）           │
│  • lib/ai/auto_sink.dart        自动入库到对应模块           │
└─────────────────────────────────────────────────────────────┘
```

---

## 二、系统浮窗（悬浮球 + 速度盘 + 建议卡）

### 2.1 权限与 WindowManager

#### AndroidManifest.xml 权限

```xml
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
<uses-permission android:name="android.permission.BIND_ACCESSIBILITY_SERVICE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

浮窗的"挂载点"使用 `WindowManager.addView()`：

- **窗口类型**：`TYPE_APPLICATION_OVERLAY`（Android 8.0+）/ `TYPE_PHONE`（兼容旧版）
- **标志**：`FLAG_NOT_FOCUSABLE | FLAG_NOT_TOUCH_MODAL` → 浮窗不抢焦点、不会阻塞外部点击
- **格式**：`PixelFormat.TRANSLUCENT`
- **位置**：`Gravity.TOP | Gravity.START`，初始 X=屏幕宽/2、Y=屏幕高/3

### 2.2 悬浮球的两种视觉状态

布局 `floating_ball.xml` 同一根 `FrameLayout` 内含两个子 View：

| 状态 | View | 尺寸 | 内容 |
|---|---|---|---|
| **状态 A（圆球）** | `ball_icon ImageView` | 48dp 圆形球 | 空闲 / 成功 / 失败（不同图标） |
| **状态 B（横条 loading）** | `ball_loading_bar LinearLayout` | 160dp × 40dp 横向胶囊 | 旋转图标 + 加载文字（处理中） |

由 `updateBallStatus()` + `_showCircleState()` / `_showLoadingBarState()` 切换。

### 2.3 触摸交互

`BallTouchListener` 采用 **静态内部类 + WeakReference** 防止内存泄漏（关键！）。功能：

| 手势 | 行为 | 实现 |
|---|---|---|
| **拖动** | 球跟随手指 | 每 16ms 节流调 `windowManager.updateViewLayout()`，限制 60fps |
| **短按** | 触发截图 | 松手距离 < touchSlop 时调 `triggerScreenshot()` |
| **长按**（500ms） | 唤出**最近联系人速度盘** | 调 `showRecentContactsSpeedDial()`（半圆卡片） |

### 2.4 前台服务保活

`FloatingBallService` 是个 **空壳**：

- 启动时 `startForeground(1, ...)` + 通知栏常驻通知
- 然后通过 `AppEventBus.requestShowFloatingBall()` 回调到 MainActivity 真正 `addView`
- **无 Activity 引用**，避免泄漏
- 被划掉卡片时 `onTaskRemoved()` → `stopSelf()`
- 无权限时 `START_NOT_STICKY` 避免"重启失败被杀"循环

### 2.5 建议卡浮窗

独立于悬浮球的 **第二个 WindowManager 窗口**：`showSuggestionOverlay()` 用一个独立的 `overlayManager`，渲染 `suggestion_overlay.xml`：

- **横向占满屏幕宽度**
- **倒计时进度条 + 自动消失**（默认可配秒数）
- **`pauseCountdown() / resumeCountdownInternal()`** 用户交互时暂停倒计时

### 2.6 最近联系人速度盘（长按）

- 长按悬浮球 500ms → 弹出半圆卡片浮窗
- 列出最近 5 个联系人（从 `RelationshipDao` 读，按 `lastInteractionAt` 倒序）
- 用户点击联系人 → 标记"当前选中的 contactId"
- 松手 → 截屏 → AI 处理时通过 `getCurrentContactId()` 异步问 Dart 端
- AI 把内容自动归属到该联系人

---

## 三、截图实现

### 3.1 核心 API：`AccessibilityService.takeScreenshot()`

**不**使用 MediaProjection（避免弹授权框），而用 Android 11 (API 30) 起 AccessibilityService 自带的 `takeScreenshot()`。

XML 标志（`accessibility_service_config.xml`）关键：

```xml
<accessibility-service
    android:accessibilityEventTypes="typeWindowStateChanged"
    android:canTakeScreenshot="true"          ← 必须
    android:canRetrieveWindowContent="true"
    android:settingsActivity="..." />
```

**`ScreenshotAccessibilityService.java` 中明确注释**：**不要在 `onServiceConnected` 调用 `setServiceInfo()`**，会清空 XML 标志。

### 3.2 截图数据流

`ScreenshotAccessibilityService.capture()` 流程：

```kotlin
fun capture(callback: CaptureCallback) {
    takeScreenshot(
        android.view.Display.DEFAULT_DISPLAY,
        mainThreadExecutor,
        object : TakeScreenshotCallback {
            override fun onSuccess(result: ScreenshotResult) {
                val hwBuffer = result.hardwareBuffer      // GPU 缓冲
                val bitmap = hardwareBufferToBitmap(hwBuffer)  // 复用 GPU
                savePng(bitmap)                           // 写 PNG
                hwBuffer.close()                          // 释放 GPU
                bitmap.recycle()
                callback.onSuccess(path)
            }
            override fun onError(errorCode: Int) {
                callback.onError(mapError(errorCode))
            }
        }
    )
}

fun hardwareBufferToBitmap(hwBuffer: HardwareBuffer): Bitmap {
    val raw = Bitmap.wrapHardwareBuffer(hwBuffer, ColorSpace.get(ColorSpace.Named.SRGB))
    val copy = raw.copy(Bitmap.Config.ARGB_8888, false)   // ARGB_8888 才能压缩
    raw.recycle()
    return copy
}
```

**关键技术点**：

- `hardwareBufferToBitmap()`：用 `Bitmap.wrapHardwareBuffer()` 复用 GPU 缓冲，再 `copy` 出可压缩的 ARGB_8888（**避免** CPU 侧 ImageReader 路径）
- `MainThreadExecutor`：把回调投递回主线程，配合 Handler 操作 UI
- `bitmap.recycle() + buffer.close()` 严格释放 GPU 内存

### 3.3 错误码映射

| 系统码 | 含义 | 处理 |
|---|---|---|
| `ERROR_TAKE_SCREENSHOT_INTERNAL_ERROR` | 系统内部错误 | Toast 失败 + 退回球态 |
| `ERROR_TAKE_SCREENSHOT_INTERVAL_TIME_SHORT` | 截图太频繁（系统限流） | Toast 提示 + 自动延长 3s 冷却 |
| `ERROR_TAKE_SCREENSHOT_NO_ACCESSIBILITY_ACCESS` | 无障碍未授权 | 引导用户到系统设置 |
| `ERROR_TAKE_SCREENSHOT_SECURE_WINDOW` | 当前是 `FLAG_SECURE` 窗口（如银行 App） | Toast "当前 App 禁止截图" |

### 3.4 触发链路

`MainActivity.triggerScreenshot()` → `captureScreenshotForBall()`：

```
[用户] 单击悬浮球
       ↓
[BallTouchListener] ACTION_UP 且 < touchSlop
       ↓
[triggerScreenshot()]
       ↓
[3 秒冷却检查] 太频繁 → Toast 拒绝 + return
       ↓
[前置校验] dartChannel.invokeMethod("getCurrentContactId") 异步问 Dart 端
       ↓
[状态机] 转 STATE_PROCESSING → 球变横条 loading
       ↓
[原子操作] screenshotBusy.compareAndSet(false, true) 防并发
       ↓
[ScreenshotAccessibilityService.capture()]
       ↓
[takeScreenshot()] → HardwareBuffer → PNG 写 /sdcard
       ↓
[callback.onSuccess(path)]
       ↓
[MainActivity] 球转 STATE_SUCCESS 短暂高亮 + 1.5s 复原
       ↓
[dartChannel.invokeMethod("onScreenshotReady", path)] 把 PNG 路径推给 Dart
       ↓
[Dart 端 ball_event_handler]
   - 调 V2 单次多任务 AI
   - 自动入库到对应模块
   - 弹建议卡浮窗
```

**反向推数据**（不是"Dart 调 Java 截完再返回"）—— 这消除了 Activity 后台时的跨层往返延迟。

---

## 四、设计亮点

| 点 | 做法 |
|---|---|
| **跨进程截图** | `AccessibilityService.takeScreenshot()`（无 MediaProjection 弹窗） |
| **GPU 复用** | `HardwareBuffer → Bitmap.wrapHardwareBuffer → copy(ARGB_8888)` |
| **内存安全** | `BallTouchListener` 静态内部类 + `WeakReference` |
| **节流** | 拖动 16ms / 截图 3s cooldown |
| **状态可视化** | 圆球 / 横条两态切换 + 加载文字 + 倒计时进度条 |
| **解耦** | 前台服务只负责"通知拉起" + EventBus，真正 addView 在 Activity |
| **协议版本** | `PROTOCOL_VERSION = 1` 双向协商，避免 Dart/Java 协议漂移 |

---

## 五、关键调用时序

```
[用户] 点悬浮球
       ↓
[BallTouchListener.onTouch] (单击)
       ↓
[triggerScreenshot()]
       ↓ (3s 冷却 + 联系人校验)
[captureScreenshotForBall()]
       ↓
[ScreenshotAccessibilityService.capture()]
       ↓
[takeScreenshot()] → HardwareBuffer → PNG 文件
       ↓
[callback.onSuccess(path)]
       ↓
[dartChannel.invokeMethod("onScreenshotReady", path)]
       ↓
[Dart 端 PlatformService]
   - 调 AI（V2 单次多任务）
   - 弹建议卡浮窗
```

---

## 六、数据流：单击 → 自动入库 → 建议卡

```
[用户] 单击悬浮球
       ↓
[Kotlin] takeScreenshot → PNG 路径
       ↓
[dartChannel] invokeMethod("onScreenshotReady", path)
       ↓
[Dart] lib/platform/ball_event_handler.dart
       ↓
[复用 Step 8 V2 单次多任务 AI] scene_inference + 子 Agent
       ↓
[SceneInference] { category, confidence, summary, actions }
       ↓
[auto_sink] 调对应模块子 Agent 写库
       ↓
[建议卡浮窗] 倒计时进度条 + "已记录到 X 模块"
       ↓
[结束 / 自动消失]
```

---

## 七、隐私与安全

### 7.1 截图永不离开设备

- **原图**：截到后立刻写入本地临时路径，AI 处理后立即删除
- **缩略图**：本地存储，仅在 AI 推理时临时上传多模态 API（base64）
- **无障碍数据**：仅监听事件流，**不读屏幕**

### 7.2 权限申请时机

| 权限 | 申请时机 | 用户可拒绝吗 |
|---|---|---|
| `SYSTEM_ALERT_WINDOW` | 首次"启用浮窗"时跳转系统设置 | ✅ |
| `BIND_ACCESSIBILITY_SERVICE` | 首次点击悬浮球时跳转系统设置 | ✅ |
| `RECORD_AUDIO` | （v1.1 语音输入）长按时由系统弹窗 | ✅ |

### 7.3 关闭路径

设置页提供：
- "停用浮窗" → `AppEventBus.requestStopFloatingBall()` → `stopService` + `removeView`
- "清空截图历史" → 删除本地 `screenshots` 表 + `screenshots/` 目录

---

## 八、测试矩阵

### 8.1 集成期（Android 真机）

| 测试 | 通过条件 |
|---|---|
| 悬浮球启停 | `closeOverlay()` 后球消失 |
| 跨 App 存在 | 切到微信 / Chrome / 设置，悬浮球仍在 |
| 单击截图 | 球变横条 loading → 截屏 → 弹建议卡浮窗 |
| 长按联系人速度盘 | 长按 500ms → 半圆卡片 → 选联系人 → 松手截屏 |
| 拖拽位置 | 拖到右下角，重启后位置保留 |
| 3s 冷却 | 频繁点击 → Toast 拒绝 |
| FLAG_SECURE 窗口 | 银行 App → Toast "当前 App 禁止截图" |
| 无障碍未授权 | Toast + 引导跳转系统设置 |

### 8.2 边界 case

| case | 期望 |
|---|---|
| 用户拒绝浮窗权限 | 顶部 toast "需要浮窗权限才能跨 App 输入"；引导跳转设置 |
| 用户拒绝无障碍权限 | Toast + 引导跳转系统设置 |
| 屏幕锁屏 / 来电中断 | 截图失败重试；球态自动复原 |
| 切到 Bulter 自己 | 悬浮球**自动隐藏**（避免遮挡自家 UI） |
| `setServiceInfo()` 被误调 | XML 标志被清空，截图失效 → Toast 引导用户重开无障碍 |

---

## 九、iOS 路径（暂不实现）

iOS 的限制：
1. **无 `AccessibilityService` 等价 API**：iOS 没有可跨 App 监听窗口 / 文本的服务
2. **无跨 App 浮窗**：iOS 13+ 浮窗必须用 `UIWindowScene` + 自家 App 内部
3. **`takeScreenshot` API 仅自家 App 范围**：不能截其他 App
4. **MediaProjection 仅 ReplayKit**：且需要 App 在前台录制

**结论**：iOS 用户**只能**用"手动添加"路径（Step 3）+ "通知栏 widget"（Step 11）+ Siri Shortcut（iOS 16+ App Intents）。

---

## 十、引用

- 上次 commit：[commit_14.md](file:///d:/others/app/Bulter/doc/git_log/commit_14.md)（Step 9 简报系统）
- 设计：[doc/first/01-architecture.md](file:///d:/others/app/Bulter/doc/first/01-architecture.md) §九（输入路径）
- 计划：[doc/first/plan.md](file:///d:/others/app/Bulter/doc/first/plan.md) §第 10 步
- 协议：[doc/first/03-tech.md](file:///d:/others/app/Bulter/doc/first/03-tech.md) §三（MethodChannel 桥接）
- Android 官方文档：
  - [AccessibilityService.takeScreenshot](https://developer.android.com/reference/android/accessibilityservice/AccessibilityService#takeScreenshot%28android.view.Display,%20java.util.concurrent.Executor,%20android.accessibilityservice.AccessibilityService.TakeScreenshotCallback%29)
  - [WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY](https://developer.android.com/reference/android/view/WindowManager.LayoutParams#TYPE_APPLICATION_OVERLAY)
  - [Bitmap.wrapHardwareBuffer](https://developer.android.com/reference/android/graphics/Bitmap#wrapHardwareBuffer%28android.hardware.HardwareBuffer,%20android.graphics.ColorSpace%29)
