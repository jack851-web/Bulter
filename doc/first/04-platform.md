# Bulter 平台桥接（Platform Bridge）— Step 10 配套文档

> **范围**：本文档描述 Step 10（**浮窗输入路径**）所依赖的 **Android 原生层** + **Flutter 桥接层** + **应用层** 的完整技术方案。
>
> **iOS 范围**：**暂不实现**。iOS 系统限制（无 `AccessibilityService` 等价物、沙盒限制、ScreenCapture 需要 ReplayKit）让"任意 App 浮窗 + 截图"在 iOS 上不可行。iOS 用户可使用"手动添加"路径（Step 3）作为替代。
>
> **生效版本**：0.9.0+
>
> **核心架构**：
> - **浮窗交互**：Bulter 原方案（单击截图 / 长按语音 / 拖拽）
> - **截图实现**：**完全参考**另一 Android 项目（`AccessibilityService.takeScreenshot()` + 三组件 + GPU 复用 + 错误码）

---

## 一、产品定位

### 1.1 浮窗交互规范（**Bulter 原方案**）

| 用户动作 | 系统反馈 | Bulter 行为 |
|---|---|---|
| **单击悬浮球** | 球变 loading 态 → 截图 → Dart 推 AI | 多模态 AI 推理 → 自动归类（chat/bill/article/report/other）→ 自动入库 → 顶部短暂通知"已记录到 X 模块" |
| **长按**（≥ 500ms） | 浮窗展开语音输入面板 → 麦克风按钮 + 实时波形 | `speech_to_text` 录音 → 文字实时上屏 → 松手自动 push AI 对话页 + 预填 query |
| **拖拽** | 球跟随手指移动（16ms 节流 60fps） | 移动到屏幕任意位置 → 松手吸附 |
| **截图冷却** | 3s 内重复点击 → Toast 拒绝 | 防频繁触发 + 避免系统限流 |
| **三指下滑 / 双击**（v1.1 可选） | 浮窗半透明闪烁 | 隐藏浮窗 1 小时（临时不被打扰） |

**为什么"单击自动完成"而不是"先确认"**：
- 用户已经在别的 App 里被打断了，再弹个 Bulter 确认页是**二次打断**，违背"被动浏览"原则
- 单击后的 AI 推理在 3s 内完成 + 自动入库 + 顶部轻通知"已记录"——失败回退到对话页让用户修正

**关键设计原则**：
1. **单击截图 → 自动完成**（不弹确认页）
2. **长按语音输入 → 直接对话**（不是"新建一条记录"，而是 AI 对话的快捷方式）
3. **浮窗不主动打扰**（30% 透明度 / 5s 无操作完全透明）
4. **截图永不离开设备**（原图截完即删）

### 1.2 三层职责

```
┌─────────────────────────────────────────────────────────────┐
│  Android 原生层 (Java/Kotlin) —— 截图完全参考另一项目     │
│  ─────────────────────                                       │
│  MainActivity ─── 浮窗管理 + Dart 通信                     │
│       │            (FlutterActivity)                         │
│       ↓                                                       │
│  FloatingBallService (前台服务 · 空壳保活)                  │
│       │                                                       │
│       ↓                                                       │
│  ScreenshotAccessibilityService                              │
│       └── AccessibilityService.takeScreenshot()              │
│            (Android 11+, 无 MediaProjection 弹窗)            │
│       ↓                                                       │
│  HardwareBuffer → Bitmap.wrapHardwareBuffer → copy(ARGB_8888)│
│       ↓                                                       │
│  dartChannel.invokeMethod("onScreenshotReady", path)         │
└─────────────────┬───────────────────────────────────────────┘
                  │ MethodChannel "bulter/ball"
┌─────────────────▼───────────────────────────────────────────┐
│  Flutter 应用层 (Dart)                                       │
│  ─────────────────────                                       │
│  • lib/platform/ball_event_handler.dart 监听 onScreenshot   │
│  • lib/ai/scene_inference.dart   复用 Step 8 多模态推理      │
│  • lib/ai/voice_input.dart       语音 → 文字（speech_to_text）│
│  • lib/features/screenshot/auto_sink.dart  自动入库         │
│  • lib/features/screenshot/notification.dart 顶部通知      │
│  • 复用 Step 7 chat_page  长按松手跳对话页（预填 query）    │
└─────────────────────────────────────────────────────────────┘
```

---

## 二、系统浮窗（**Bulter 原方案**——单击截图 / 长按语音 / 拖拽）

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
| **短按** | 触发截图（**Bulter 行为**） | 松手距离 < touchSlop 时调 `triggerScreenshot()` |
| **长按**（500ms） | 展开**语音输入面板**（**Bulter 行为**） | 调 `showVoiceInputPanel()` |

### 2.4 前台服务保活

`FloatingBallService` 是个 **空壳**：

- 启动时 `startForeground(1, ...)` + 通知栏常驻通知
- 然后通过 `AppEventBus.requestShowFloatingBall()` 回调到 MainActivity 真正 `addView`
- **无 Activity 引用**，避免泄漏
- 被划掉卡片时 `onTaskRemoved()` → `stopSelf()`
- 无权限时 `START_NOT_STICKY` 避免"重启失败被杀"循环

### 2.5 语音输入面板（**Bulter 原方案**）

长按悬浮球 500ms → 弹出语音输入面板（**Bulter 不使用**最近联系人速度盘）：

- 麦克风按钮（红色高亮）
- 实时波形（用 `audioplayers` + level monitoring）
- 文字实时上屏
- 松手 → `speech.stop()` → push AI 对话页 + 预填 query

### 2.6 浮窗 UI 状态机（**Bulter 原方案**）

| 状态 | 视觉 | 触发 |
|---|---|---|
| `idle`（30% 透明） | 圆形 + Bulter logo | 默认 |
| `hovered`（90% 透明） | 圆形 + 阴影 | 触摸按下 |
| `dragging`（90% 透明） | 圆形 + 位置跟随 | 拖动 |
| `loading`（旋转图标 + 文字） | 圆球变 160dp×40dp 横条 | 单击触发截图后 |
| `success`（绿色 1.5s） | 圆形 + ✓ | AI 入库成功 |
| `error`（红色 1.5s） | 圆形 + ✗ | AI 入库失败 |

---

## 三、截图实现（**完全参考另一 Android 项目**）

> **来源**：以下截图实现**完全照搬**另一 Android 项目（[android-overlay-screenshot](https://github.com/example/android-overlay-screenshot) 类项目的设计）。**包括三组件架构、API 选择、GPU 复用、错误码映射、`setServiceInfo()` 禁忌等所有细节**。

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

### 3.2 三组件架构（**完全照搬**）

| 组件 | 角色 | 类型 |
|---|---|---|
| `MainActivity` | 浮窗管理 + 截图触发 + Dart 通信 | `FlutterActivity` |
| `FloatingBallService` | 前台服务，**空壳**——只 `startForeground` 维持通知保活 + 通过 `AppEventBus.requestShowFloatingBall()` 回调到 Activity 真正 `addView` | `Service`（foreground） |
| `ScreenshotAccessibilityService` | **系统级截图**（用 `AccessibilityService.takeScreenshot()`） | `AccessibilityService` |

### 3.3 截图数据流

`ScreenshotAccessibilityService.capture()` 流程：

```kotlin
fun capture(callback: CaptureCallback) {
    takeScreenshot(
        android.view.Display.DEFAULT_DISPLAY,
        mainThreadExecutor,                       // 把回调投递回主线程
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
                callback.onError(mapError(errorCode))     // 错误码映射
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

### 3.4 错误码映射

| 系统码 | 含义 | 处理 |
|---|---|---|
| `ERROR_TAKE_SCREENSHOT_INTERNAL_ERROR` | 系统内部错误 | Toast 失败 + 退回球态 |
| `ERROR_TAKE_SCREENSHOT_INTERVAL_TIME_SHORT` | 截图太频繁（系统限流） | Toast 提示 + 自动延长 3s 冷却 |
| `ERROR_TAKE_SCREENSHOT_NO_ACCESSIBILITY_ACCESS` | 无障碍未授权 | 引导用户到系统设置 |
| `ERROR_TAKE_SCREENSHOT_SECURE_WINDOW` | 当前是 `FLAG_SECURE` 窗口（如银行 App） | Toast "当前 App 禁止截图" |

### 3.5 触发链路

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
[状态机] 转 STATE_PROCESSING → 球变 160dp×40dp 横条 loading
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
   - 调多模态 AI 自动归类
   - 自动入库到对应模块
   - 顶部通知"已记录到 X 模块"
```

**反向推数据**（不是"Dart 调 Java 截完再返回"）—— 这消除了 Activity 后台时的跨层往返延迟。

### 3.6 为什么不用 MediaProjection？

| API | 优劣 | Bulter 选择 |
|---|---|---|
| `AccessibilityService.takeScreenshot()` | ✅ 不弹授权框 / ❌ 仅 Android 11+ / ❌ 需要用户开无障碍 | ✅ **采用**（**参考项目选型**） |
| `MediaProjection` | ❌ 每次弹授权框 / ✅ 跨 Android 版本 | ❌ 不用（UX 差） |

---

## 四、调用时序（**完全照搬参考项目**）

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
[Dart 端 ball_event_handler]
   - 调 AI 自动归类
   - 自动入库
   - 顶部通知
```

---

## 五、借鉴的技术细节（其他）

### 5.1 触摸监听：静态内部类 + WeakReference（**照搬**）

```kotlin
class BallTouchListener(activity: MainActivity) : View.OnTouchListener {
    private val ref = WeakReference(activity)        // ← 防内存泄漏
    // 拖动：16ms 节流 windowManager.updateViewLayout
    // 短按：松手距离 < touchSlop → triggerScreenshot()
    // 长按 500ms：→ showVoiceInputPanel()  // Bulter: 语音输入面板
}
```

### 5.2 前台服务解耦（**照搬**）

```kotlin
class FloatingBallService : Service() {
    override fun onStartCommand(intent: Intent?): Int {
        startForeground(1, buildNotification())  // 通知保活
        AppEventBus.requestShowFloatingBall()    // 回调到 Activity
        return START_NOT_STICKY                  // 避免"重启失败被杀"循环
    }
}
```

### 5.3 协议版本协商（**照搬**）

`PROTOCOL_VERSION = 1` 双向协商，避免 Dart / Kotlin 协议漂移。

```kotlin
// Kotlin 启动时
override fun onMethodCall(call: MethodCall, result: Result) {
    if (call.method == "negotiateProtocol") {
        result.success(PROTOCOL_VERSION)
        return
    }
    if (call.argument<Int>("protocolVersion") != PROTOCOL_VERSION) {
        result.error("PROTOCOL_MISMATCH", "expected $PROTOCOL_VERSION", null)
        return
    }
    // ...
}
```

```dart
// Dart 启动时
final v = await _channel.invokeMethod<int>('negotiateProtocol');
if (v != PROTOCOL_VERSION) {
    throw StateError('Protocol mismatch: $v vs $PROTOCOL_VERSION');
}
```

### 5.4 Bulter 不照搬的部分

| 项 | 参考项目 | Bulter | 原因 |
|---|---|---|---|
| **长按功能** | 唤出最近联系人速度盘 | **展开语音输入面板** | Bulter 强调"AI 对话"，不强调"快速归属" |
| **场景推理流程** | V2 单次多任务 AI + 弹建议卡 | **复用 Step 8 多模态 + 自动入库** | Bulter 已有 Step 8 子 Agent 框架 |
| **建议卡浮窗** | 独立 WindowManager 倒计时进度条 | **顶部轻通知**（flutter_local_notifications） | 简化：避免第二个浮窗复杂度 |
| **API 选型** | 仅 `AccessibilityService.takeScreenshot()` | **优先 `MediaProjection`**，降级 `AccessibilityService.takeScreenshot()` | Bulter 兼容 Android 8+（MediaProjection），参考项目仅 11+ |

---

## 六、Dart 应用层

### 6.1 模块文件

```
lib/
├── platform/
│   └── ball_event_handler.dart   # 监听 onScreenshotReady → 调 AI
├── overlay/
│   ├── overlay_entry.dart         # 浮窗入口（仅 Dart 侧业务逻辑）
│   ├── overlay_widget.dart        # 浮窗 UI 状态机
│   ├── overlay_actions.dart       # 单击/长按/拖拽事件处理
│   └── voice_panel.dart           # 长按展开的语音输入面板
├── ai/
│   ├── scene_inference.dart       # 复用 Step 8 多模态推理
│   └── voice_input.dart           # speech_to_text 封装
└── features/
    ├── screenshot/
    │   ├── auto_sink.dart         # 场景归类后自动调子 Agent 写库
    │   ├── notification.dart      # 顶部轻通知（flutter_local_notifications）
    │   └── cooldown.dart          # 3s 冷却控制
    └── chat/
        └── chat_page.dart         # 复用 Step 7 AI 对话
```

### 6.2 单击截图数据流（**Bulter 原方案**）

```
[用户] 单击悬浮球
       ↓
[BallTouchListener.onTouch] 触发 triggerScreenshot()
       ↓
[检查 3s 冷却] 太频繁 → Toast 拒绝 + return
       ↓
[Kotlin] ScreenshotAccessibilityService.takeScreenshot()
       ↓
[image saved to /sdcard/<uuid>.png]
       ↓
[dartChannel.invokeMethod("onScreenshotReady", path)]
       ↓
[Dart 端 ball_event_handler]
       ↓
[生成缩略图 256x宽] → /screenshots/<uuid>_thumb.jpg
       ↓
[删除原图] File.delete()  // 隐私
       ↓
[scene_inference] infer(thumbPath) → SceneInference
       ↓
[如果 confidence >= 0.5]
       ↓
[auto_sink] 调对应模块的子 Agent 写库
       ↓
[flutter_local_notifications] 顶部通知"已记录到 X 模块"（1.5s 消失）
       ↓
[球恢复 idle 态]
       ↓
[如果 confidence < 0.5 或失败]
       ↓
[push ChatPage] 预填 "我看到一张截图但不确定是什么…" + 缩略图附件
```

### 6.3 长按语音输入数据流（**Bulter 原方案**）

```
[用户] 长按悬浮球 ≥ 500ms
       ↓
[Kotlin] BallTouchListener.onLongPress
       ↓
[speech_to_text] initialize() + listen()
       ↓
[浮窗 UI 展开语音面板]
   - 麦克风按钮（红色高亮）
   - 实时波形
   - 文字实时上屏
       ↓
[用户说话]
       ↓
[用户松手] → speech.stop()
       ↓
[拿到 finalText]
       ↓
[push ChatPage] 预填 finalText
       ↓
[AI 对话正常流程]
```

### 6.4 场景推理 + 自动入库实现（**主模型多模态**）

> ⚠️ **重要架构**：场景推理 + 写库**由主模型多模态 LLM 完成**，**不是子模型**。
>
> - **主模型（多模态 LLM）**：看截图 → 识别场景 → **直接调对应工具**写入数据库
> - **子模型（文本 LLM）**：仅作为子模块里的信息处理者（如供应简报），**不负责截图归类**
> - **主模型可主动调子模型**：子模型简报不够明确时，主模型**主动重新调**子模型（带更具体的 query）
>
> **为什么不用子模型做截图归类**：
> - 子模型只接受**文本**输入，无法看图
> - 主模型支持多模态（`image_url` message），能直接理解截图内容
> - 工具调用（tool_calls）天然适合"看图 → 选工具 → 调工具"流程
>
> **主模型主动调子模型的场景**（截图归类不直接涉及，但其他场景有）：
> - 主模型生成跨模块叙事时，子模型提供的简报**不够明确** → 主模型**主动重调**子模型
> - 例如：wealth 子模型简报只说"有一笔支出"，主模型不满意 → 重调"请确认类别和时间"

#### 实现思路

```dart
Future<SceneInference> inferScreenshot({
  required String thumbPath,
}) async {
  // 1) 准备多模态 messages
  final imageBase64 = await _readThumbAsBase64(thumbPath);
  final messages = [
    {
      'role': 'system',
      'content': '你是 Bulter 的视觉助理。看到截图后判断场景，并直接调用对应的工具把信息记录下来。\n'
          '工具包括：\n'
          '- relationship.add_contact: 添加联系人\n'
          '- relationship.add_interaction: 记录互动\n'
          '- wealth.add_transaction: 记一笔账单\n'
          '- thought.save: 存为想法\n'
          '- health.add_record: 记一次健康数据\n'
          '如果没有合适的工具，回复自然语言建议。',
    },
    {
      'role': 'user',
      'content': [
        {'type': 'text', 'text': '请分析这张截图并按需调用工具。'},
        {
          'type': 'image_url',
          'image_url': {'url': 'data:image/jpeg;base64,$imageBase64'},
        },
      ],
    },
  ];

  // 2) 调主模型（多模态 chat completions）
  final cfg = ModelRegistry.instance.active;
  final response = await _httpPost(
    '${cfg.baseUrl}/${cfg.chatPath}',
    {
      'model': cfg.model,
      'messages': messages,
      'tools': ToolRegistry.instance.getJsonSchemas(),
    },
    cfg.apiKey,
  );

  // 3) 解析 tool_calls 并执行
  final toolCalls = _extractToolCalls(response);
  final executed = <ToolCallResult>[];
  for (final tc in toolCalls) {
    try {
      final tool = ToolRegistry.instance.getByName(tc.name);
      final result = await tool.invoke(tc.arguments);
      executed.add(ToolCallResult(name: tc.name, ok: true, result: result));
    } catch (e) {
      executed.add(ToolCallResult(name: tc.name, ok: false, error: e.toString()));
    }
  }

  return SceneInference(
    toolCalls: executed,
    summary: _extractContent(response),
  );
}
```

#### 数据流

```
[截图] → Kotlin takeScreenshot() → Dart 收到 path
       ↓
[scene_inference] 读 thumb → base64 编码
       ↓
[主模型多模态 LLM] 看图 + 选工具
       ↓
[response.tool_calls]
       ↓
[ToolRegistry] 顺序执行工具
  ├── relationship.add_contact  → 联系人入库
  ├── wealth.add_transaction   → 账单入库
  ├── thought.save             → 想法入库
  └── health.add_record        → 健康入库
       ↓
[顶部通知] "已记录到 X 模块"
```

#### 不弹 review 页的理由

- 主模型选工具时已经"理解了"截图内容，置信度由 LLM 内化
- 用户已经在别的 App 里被打断过一次，**再弹确认页是二次打断**（Bulter 核心原则）
- 失败时（如 LLM 返回非 JSON / 工具调用失败）→ 自动降级到对话页让用户修正

---

## 七、Schema 迁移

### 7.1 复用 Step 9 的 `screenshots` 表

Step 10 复用 Step 9 加的 `screenshots` 表，无需新增表。

```sql
CREATE TABLE screenshots (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  thumb_path TEXT NOT NULL,
  inferred_category TEXT,
  inferred_confidence REAL,
  inferred_summary TEXT,
  user_category TEXT,                -- 自动入库的目标归类
  user_actions_json TEXT,
  reviewed_at INTEGER,                -- 自动入库后立即填
  created_at INTEGER NOT NULL
);
```

### 7.2 迁移

`schemaVersion`: 2 → 3

```dart
onUpgrade: (m, from, to) async {
  if (from < 2) await m.createTable(screenshots);  // Step 9
  if (from < 3) {
    await m.addColumn(screenshots, screenshots.autoSinkStatus);  // Step 10
  }
}
```

---

## 八、隐私与安全

### 8.1 不上传原图

| 数据 | 流向 |
|---|---|
| 截图原图 | 截到后**立即删除**（`File.delete()`），从不离开设备 |
| 缩略图（256×宽） | 本地存储；AI 推理时临时 base64 上传多模态 API |
| 无障碍数据 | 仅监听事件流，**不读屏幕** |

### 8.2 权限申请时机

| 权限 | 申请时机 | 用户可拒绝吗 |
|---|---|---|
| `SYSTEM_ALERT_WINDOW` | 首次"启用浮窗"时跳转系统设置 | ✅ |
| `BIND_ACCESSIBILITY_SERVICE` | 首次点击悬浮球时跳转系统设置 | ✅ |
| `RECORD_AUDIO` | 首次长按浮窗时由系统弹窗 | ✅ |

### 8.3 关闭路径

设置页提供：
- "停用浮窗" → `AppEventBus.requestStopFloatingBall()` → `stopService` + `removeView`
- "清空截图历史" → 删除本地 `screenshots` 表 + `screenshots/` 目录

---

## 九、测试矩阵

### 9.1 集成期（Android 真机）

| 测试 | 通过条件 |
|---|---|
| 浮窗启停 | `closeOverlay()` 后球消失 |
| 跨 App 存在 | 切到微信 / Chrome / 设置，浮窗仍在 |
| 单击截图 | 球变横条 loading → 截屏 → 顶部通知"已记录到 X 模块" |
| 长按语音 | 长按 500ms → 展开面板 → 录音 → 松手跳对话页（query 预填） |
| 拖拽位置 | 拖到右下角，重启后位置保留 |
| 3s 冷却 | 频繁点击 → Toast 拒绝 |
| FLAG_SECURE 窗口 | 银行 App → Toast "当前 App 禁止截图" |
| 无障碍未授权 | Toast + 引导跳转系统设置 |

### 9.2 边界 case

| case | 期望 |
|---|---|
| 用户拒绝浮窗权限 | 顶部 toast "需要浮窗权限才能跨 App 输入"；引导跳转设置 |
| 用户拒绝麦克风权限 | 长按 → 提示"需要麦克风权限才能语音输入"；降级到文字 |
| 屏幕锁屏 / 来电中断 | 语音识别自动停止；截图失败重试 |
| AI 推理超时 | 自动降级到对话页 + 缩略图附件 |
| 切到 Bulter 自己 | 浮窗**自动隐藏**（避免遮挡自家 UI） |
| `setServiceInfo()` 被误调 | XML 标志被清空，截图失效 → Toast 引导用户重开无障碍 |

---

## 十、iOS 路径（暂不实现）

iOS 的限制：
1. **无 `AccessibilityService` 等价 API**：iOS 没有可跨 App 监听窗口 / 文本的服务
2. **无跨 App 浮窗**：iOS 13+ 浮窗必须用 `UIWindowScene` + 自家 App 内部
3. **`takeScreenshot` API 仅自家 App 范围**：不能截其他 App
4. **MediaProjection 仅 ReplayKit**：且需要 App 在前台录制

**结论**：iOS 用户**只能**用"手动添加"路径（Step 3）+ "通知栏 widget"（Step 11）+ Siri Shortcut（iOS 16+ App Intents）。

---

## 十一、引用

- 上次 commit：[commit_14.md](file:///d:/others/app/Bulter/doc/git_log/commit_14.md)（Step 9 简报系统）
- 设计：[doc/first/01-architecture.md](file:///d:/others/app/Bulter/doc/first/01-architecture.md) §九（输入路径）
- 计划：[doc/first/plan.md](file:///d:/others/app/Bulter/doc/first/plan.md) §第 10 步
- 协议：[doc/first/03-tech.md](file:///d:/others/app/Bulter/doc/first/03-tech.md) §三（MethodChannel 桥接）
- 截图参考实现：[android-overlay-screenshot 类项目](https://github.com/example/android-overlay-screenshot)（设计思路参考）
- Android 官方文档：
  - [AccessibilityService.takeScreenshot](https://developer.android.com/reference/android/accessibilityservice/AccessibilityService#takeScreenshot%28android.view.Display,%20java.util.concurrent.Executor,%20android.accessibilityservice.AccessibilityService.TakeScreenshotCallback%29)
  - [WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY](https://developer.android.com/reference/android/view/WindowManager.LayoutParams#TYPE_APPLICATION_OVERLAY)
  - [Bitmap.wrapHardwareBuffer](https://developer.android.com/reference/android/graphics/Bitmap#wrapHardwareBuffer%28android.hardware.HardwareBuffer,%20android.graphics.ColorSpace%29)
- Flutter packages（**Bulter 原方案**）：
  - [speech_to_text](https://pub.dev/packages/speech_to_text)
  - [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)
