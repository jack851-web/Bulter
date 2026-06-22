# Bulter 平台桥接（Platform Bridge）— Step 10 配套文档

> **范围**：本文档描述 Step 10（**浮窗输入路径**）所依赖的 **Android 原生层** + **Flutter 桥接层** + **应用层** 的完整技术方案。
>
> **iOS 范围**：**暂不实现**。iOS 系统限制（无 `AccessibilityService` 等价物、沙盒限制、ScreenCapture 需要 ReplayKit）让"任意 App 浮窗 + 截图"在 iOS 上不可行。iOS 用户可使用"手动添加"路径（Step 3）作为替代。
>
> **生效版本**：0.9.0+
>
> **核心原则**：**优先用 Flutter packages**（`flutter_overlay_window` / `screen_capturer` / `speech_to_text` / `flutter_local_notifications`）覆盖功能；**仅在** Flutter 包无法满足时才写 Kotlin 原生层。所有 Android 系统 API 调用都通过 pub.dev 维护的 package 间接调用，开发流程**不需要 Android Studio**——`flutter build apk` 自动编译 Kotlin 部分。

---

## 一、产品定位

### 1.1 浮窗交互规范（**Bulter 原方案**）

| 用户动作 | 系统反馈 | Bulter 行为 |
|---|---|---|
| **单击悬浮球** | 球变 loading 态 → 截屏 → Dart 推 AI | 多模态 AI 推理 → 自动归类（chat/bill/article/report/other）→ 自动入库 → 顶部短暂通知"已记录到 X 模块" |
| **长按**（≥ 500ms） | 浮窗展开语音输入面板 → 麦克风按钮 + 实时波形 | `speech_to_text` 录音 → 文字实时上屏 → 松手自动 push AI 对话页 + 预填 query |
| **拖拽** | 球跟随手指移动（16ms 节流 60fps） | 移动到屏幕任意位置 → 松手吸附 |
| **截图冷却** | 3s 内重复点击 → Toast 拒绝 | 防频繁触发 + 避免系统限流（借鉴技术实践） |
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
│  Flutter 应用层 (Dart)                                       │
│  ────────────────────                                        │
│  • lib/overlay/overlay_entry.dart  浮窗入口 / 生命周期管理   │
│  • lib/overlay/overlay_widget.dart 浮窗 UI（圆按钮 + 状态）  │
│  • lib/ai/scene_inference.dart     复用 Step 8 多模态推理    │
│  • lib/ai/voice_input.dart         语音 → 文字              │
│  • lib/features/screenshot/auto_sink.dart  自动入库         │
│  • lib/features/screenshot/notification.dart 顶部通知      │
└─────────────────┬───────────────────────────────────────────┘
                  │ Flutter packages（pub.dev 维护，含原生代码）
┌─────────────────▼───────────────────────────────────────────┐
│  Flutter packages 层                                         │
│  ────────────────────                                        │
│  • flutter_overlay_window   跨 App 浮窗（WindowManager）    │
│  • screen_capturer          系统截图（MediaProjection）     │
│  • speech_to_text           语音识别（SpeechRecognizer）    │
│  • flutter_local_notifications  顶部通知                    │
└─────────────────┬───────────────────────────────────────────┘
                  │ Android 系统 API（**用户不写 Kotlin**）
┌─────────────────▼───────────────────────────────────────────┐
│  Android 原生层 (Kotlin, 由 packages 提供)                    │
│  ────────────────────                                        │
│  • WindowManager 浮窗 + MediaProjection + SpeechRecognizer   │
│  • 用户安装的 package 自带，无需手写 Kotlin                   │
└─────────────────────────────────────────────────────────────┘
```

**开发流程**（用户**不需要** Android Studio）：

```bash
flutter pub add flutter_overlay_window screen_capturer speech_to_text flutter_local_notifications
flutter pub get
flutter run    # 或 flutter build apk
```

---

## 二、Flutter packages 选型

### 2.1 [flutter_overlay_window](https://pub.dev/packages/flutter_overlay_window)

跨 App 显示浮窗。

| API | 用途 |
|---|---|
| `FlutterOverlayWindow.showOverlay(width, height, enableDrag)` | 弹出浮窗 |
| `FlutterOverlayWindow.isPermissionGranted()` | 检查 `SYSTEM_ALERT_WINDOW` |
| `FlutterOverlayWindow.requestPermission()` | 跳转系统设置 |
| `FlutterOverlayWindow.closeOverlay()` | 关闭 |
| `FlutterOverlayWindow.shareData(data)` | 主 App → 浮窗 发消息 |
| `FlutterOverlayWindow.overlayListener` | 浮窗 → 主 App 事件流（用户单击 / 长按 / 拖拽） |

**自带 Kotlin**（无需手写）：
- `OverlayService`（前台服务）
- `AccessibilityListener`（可选，用于跨 App 事件监听）
- `MainActivity2`（透明 Activity，启动浮窗）

### 2.2 [screen_capturer](https://pub.dev/packages/screen_capturer) 或 `screenshot_callback`

截当前屏幕。

```dart
final capturer = ScreenCapturer();
final image = await capturer.capture();  // 触发 MediaProjection 系统授权弹窗
File(image.path).delete();  // 原图截完即删（隐私）
```

### 2.3 [speech_to_text](https://pub.dev/packages/speech_to_text)

```dart
final speech = SpeechToText();
await speech.initialize();
await speech.listen(onResult: (r) => setState(() => text = r.recognizedWords));
await speech.stop();
```

### 2.4 [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)

```dart
await flutterLocalNotificationsPlugin.show(
  0, 'Bulter', '已记录到 关系模块',
  NotificationDetails(android: AndroidNotificationDetails(...)),
);
```

---

## 三、借鉴的 Android 技术模式（来自另一项目实践参考）

> **来源说明**：以下技术细节（GPU 缓冲复用、3s 冷却、错误码映射、解耦架构）来自另一个 Android 项目的实现思路。**Bulter 不直接照搬**——只把**通用且不冲突**的部分借鉴过来。

### 3.1 截图：优先 `MediaProjection`，降级 `AccessibilityService.takeScreenshot()`

| 路径 | 优劣 | Bulter 选择 |
|---|---|---|
| **`MediaProjection`**（via `screen_capturer`） | 跨 Android 版本兼容 / 每次需用户授权 | ✅ **首选** |
| **`AccessibilityService.takeScreenshot()`**（API 30+） | 不弹授权框 / 仅 Android 11+ / 需要用户开无障碍 | 降级路径（仅在 MediaProjection 失效时用） |

**借鉴的技术细节**（用 `MediaProjection` 时也适用）：

- `HardwareBuffer → Bitmap.wrapHardwareBuffer → copy(ARGB_8888)` 复用 GPU 缓冲，**避免** CPU 侧 ImageReader 路径
- `MainThreadExecutor` 把回调投递回主线程
- `bitmap.recycle() + buffer.close()` 严格释放

### 3.2 浮窗挂载：WindowManager.addView

```kotlin
val params = WindowManager.LayoutParams(
    width, height,
    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,  // Android 8+
    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
        or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
    PixelFormat.TRANSLUCENT
)
windowManager.addView(ballView, params)
```

- **窗口类型**：`TYPE_APPLICATION_OVERLAY`（Android 8+）/ `TYPE_PHONE`（兼容旧版）
- **标志**：`FLAG_NOT_FOCUSABLE | FLAG_NOT_TOUCH_MODAL` → 浮窗不抢焦点、不阻塞外部点击
- **格式**：`PixelFormat.TRANSLUCENT`

### 3.3 触摸监听：静态内部类 + WeakReference

```kotlin
class BallTouchListener(activity: MainActivity) : View.OnTouchListener {
    private val ref = WeakReference(activity)
    // 拖动：16ms 节流 windowManager.updateViewLayout
    // 短按：松手距离 < touchSlop → triggerScreenshot()
    // 长按 500ms：→ showVoiceInputPanel()
}
```

**防内存泄漏**——触摸监听器**不直接持有** Activity 引用。

### 3.4 前台服务解耦

借鉴的"前台服务空壳"模式（flutter_overlay_window 自带类似实现）：

```kotlin
class BulterFloatingService : Service() {
    override fun onStartCommand(intent: Intent?): Int {
        startForeground(1, buildNotification())  // 通知保活
        // 真正 addView 由 flutter_overlay_window 处理（不需要 Activity 引用）
        return START_NOT_STICKY  // 避免"重启失败被杀"循环
    }
}
```

**Bulter 简化**：直接用 `flutter_overlay_window` 自带的 `OverlayService`，**不**自己写前台服务。

### 3.5 截图冷却 + 错误码映射

| 错误码 | 含义 | Bulter 处理 |
|---|---|---|
| `ERROR_TAKE_SCREENSHOT_INTERNAL_ERROR` | 系统内部错误 | Toast 失败 + 球态复原 |
| `ERROR_TAKE_SCREENSHOT_INTERVAL_TIME_SHORT` | 截图太频繁（系统限流） | 自动延长 3s 冷却 |
| `ERROR_TAKE_SCREENSHOT_NO_ACCESSIBILITY_ACCESS` | 无障碍未授权 | 引导用户到系统设置 |
| `ERROR_TAKE_SCREENSHOT_SECURE_WINDOW` | 当前是 `FLAG_SECURE` 窗口（如银行 App） | Toast "当前 App 禁止截图" |

**3s 冷却**：每次截图记录时间戳，下次截图前检查 3s 内是否已截过；超频繁则直接 Toast 拒绝。

### 3.6 协议版本协商

`PROTOCOL_VERSION = 1` 双向协商，避免 Dart / Kotlin 协议漂移。

```kotlin
// Kotlin 启动时
override fun onMethodCall(call: MethodCall, result: Result) {
    if (call.method == "negotiateProtocol") {
        result.success(PROTOCOL_VERSION)
        return
    }
    // 检查协议版本
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

---

## 四、应用层架构（Dart）

### 4.1 模块文件

```
lib/
├── overlay/
│   ├── overlay_entry.dart       # 浮窗生命周期管理（启动/关闭/权限检查）
│   ├── overlay_widget.dart      # 浮窗 UI（圆按钮 + 状态机）
│   ├── overlay_actions.dart     # 单击/长按事件处理
│   └── voice_panel.dart         # 长按展开的语音输入面板
├── ai/
│   ├── scene_inference.dart     # 复用 Step 8 多模态推理
│   └── voice_input.dart         # 语音 → 文字（speech_to_text 封装）
├── features/
│   ├── screenshot/
│   │   ├── auto_sink.dart       # 场景归类后自动调子 Agent 写库
│   │   ├── notification.dart    # 顶部轻通知（flutter_local_notifications 封装）
│   │   └── cooldown.dart        # 3s 冷却控制
│   └── chat/
│       └── chat_page.dart       # 复用 Step 7 AI 对话（语音松手跳转 + 预填 query）
```

### 4.2 单击截图数据流

```
[用户] 单击悬浮球
       ↓
[Flutter OverlayWindow overlayListener] 收到 'tap' 事件
       ↓
[检查 3s 冷却] 太频繁 → Toast 拒绝 + return
       ↓
[球变 loading 态]
       ↓
[screen_capturer] capture() → 系统弹窗授权（首次）
       ↓
[image saved to /cache/<uuid>.png]
       ↓
[删除原图] File.delete()
       ↓
[生成缩略图 256x宽] → /screenshots/<uuid>_thumb.jpg
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

### 4.3 长按语音输入数据流

```
[用户] 长按悬浮球 ≥ 500ms
       ↓
[OverlayWindow overlayListener] 收到 'longPress' 事件
       ↓
[speech_to_text] initialize() + listen()
       ↓
[浮窗 UI 展开语音面板]
   - 麦克风按钮（红色高亮）
   - 实时波形（用 audioplayers + level monitoring）
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

### 4.4 自动入库实现（auto_sink.dart）

**核心思路**：复用 Step 8 的 `Orchestrator.invokeSubAgent(moduleId, query)`，让子 Agent 用工具完成"实际写库"。

```dart
Future<AutoSinkResult> autoSinkScreenshot({
  required String thumbPath,
  required SceneInference inference,
}) async {
  // 1) 置信度太低 → 降级
  if (inference.confidence < 0.5) {
    return AutoSinkResult.lowConfidence(inference);
  }
  // 2) other 类无意义 → 降级
  if (inference.category == SceneCategory.other) {
    return AutoSinkResult.unknownCategory(inference);
  }
  // 3) 调子 Agent 写库
  final query = '基于以下截图场景摘要，自动执行建议动作：${inference.summary}\n'
      'actions: ${inference.actions.map((a) => a.type.name).join(', ')}';
  final result = await Orchestrator.instance.invokeSubAgent(
    _moduleFor(inference.category),
    query,
    timeout: Duration(seconds: 8),
  );
  return AutoSinkResult.success(result);
}
```

**调子 Agent 而不是直接写库的好处**：
- 子 Agent 已有完整的"读本模块 + system prompt"封装（Step 8）
- 一行调用即可完成实际写库（无需重新实现"添加联系人 / 添加账单 / 等"逻辑）
- 子 Agent 有超时降级保护

### 4.5 浮窗 UI 状态机

| 状态 | 视觉 | 触发 |
|---|---|---|
| `idle`（30% 透明） | 圆形 + Bulter logo | 默认 |
| `hovered`（90% 透明） | 圆形 + 阴影 | 触摸按下 |
| `dragging`（90% 透明） | 圆形 + 位置跟随 | 拖动 |
| `loading`（旋转图标 + 文字） | 圆形 + spinner | 单击触发截图后 |
| `success`（绿色 1.5s） | 圆形 + ✓ | AI 入库成功 |
| `error`（红色 1.5s） | 圆形 + ✗ | AI 入库失败 |

---

## 五、Schema 迁移

### 5.1 复用 Step 9 的 `screenshots` 表

Step 10 复用 Step 9 加的 `screenshots` 表，无需新增表。

```sql
CREATE TABLE screenshots (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  thumb_path TEXT NOT NULL,
  inferred_category TEXT,
  inferred_confidence REAL,
  inferred_summary TEXT,
  user_category TEXT,                -- 自动入库的目标归类（Step 10 调整）
  user_actions_json TEXT,
  reviewed_at INTEGER,                -- 自动入库后立即填（不需要用户 review）
  created_at INTEGER NOT NULL
);
```

### 5.2 迁移

`schemaVersion`: 2 → 3（仅加字段，**不**破坏旧数据）

```dart
onUpgrade: (m, from, to) async {
  if (from < 2) await m.createTable(screenshots);  // Step 9
  if (from < 3) {
    await m.addColumn(screenshots, screenshots.autoSinkStatus);  // Step 10
  }
}
```

---

## 六、隐私与安全

### 6.1 不上传原图

| 数据 | 流向 |
|---|---|
| 截图原图 | 截到后**立即删除**（`File.delete()`），从不离开设备 |
| 缩略图（256×宽） | 本地存储；AI 推理时临时 base64 上传多模态 API |
| 语音音频 | Google Speech-to-Text 转文字后丢弃音频流 |

### 6.2 权限申请时机

| 权限 | 申请时机 | 用户可拒绝吗 |
|---|---|---|
| `SYSTEM_ALERT_WINDOW` | 首次"启用浮窗"时跳转系统设置 | ✅ |
| `RECORD_AUDIO` | 首次长按浮窗时由系统弹窗 | ✅ |
| `MediaProjection`（截图） | 每次截图前由 Android 系统弹窗 | ✅ |

### 6.3 关闭路径

设置页提供：
- "停用浮窗" → 调 `FlutterOverlayWindow.closeOverlay()`
- "清空截图历史" → 删除本地 `screenshots` 表 + `screenshots/` 目录

---

## 七、测试矩阵

### 7.1 开发期（Dart 单测）

| 测试 | 工具 |
|---|---|
| `scene_inference` JSON 解析容错 | `flutter test` |
| `auto_sink` 置信度阈值 | `flutter test` + mock |
| `voice_input` 文字分段 | `flutter test` |
| `cooldown` 3s 时间窗 | `flutter test` |

### 7.2 集成期（Android 真机）

| 测试 | 通过条件 |
|---|---|
| 浮窗启停 | `closeOverlay()` 后球消失 |
| 跨 App 存在 | 切到微信 / Chrome / 设置，浮窗仍在 |
| 单击截图 | 球变 loading → 截屏 → 顶部通知"已记录到 X 模块" |
| 长按语音 | 长按 500ms → 展开面板 → 录音 → 松手跳对话页（query 预填） |
| 拖拽位置 | 拖到右下角，重启后位置保留 |
| 3s 冷却 | 频繁点击 → Toast 拒绝 |
| FLAG_SECURE 窗口 | 银行 App → Toast "当前 App 禁止截图" |
| MediaProjection 授权失败 | 球转 error 态 + Toast "截图失败" |

### 7.3 边界 case

| case | 期望 |
|---|---|
| 用户拒绝浮窗权限 | 顶部 toast "需要浮窗权限才能跨 App 输入"；引导跳转设置 |
| 用户拒绝麦克风权限 | 长按 → 提示"需要麦克风权限才能语音输入"；降级到文字 |
| 用户拒绝 MediaProjection | 截图 → 通知"截图失败，请重试"；不弹确认页 |
| 屏幕锁屏 / 来电中断 | 语音识别自动停止；截图失败重试 |
| AI 推理超时 | 自动降级到对话页 + 缩略图附件 |
| 切到 Bulter 自己 | 浮窗**自动隐藏**（避免遮挡自家 UI） |

---

## 八、iOS 路径（暂不实现）

iOS 的限制：
1. **无 `AccessibilityService` 等价 API**：iOS 没有可跨 App 监听窗口 / 文本的服务
2. **无跨 App 浮窗**：iOS 13+ 浮窗必须用 `UIWindowScene` + 自家 App 内部
3. **MediaProjection 仅 ReplayKit**：且需要 App 在前台录制，不能后台
4. **沙盒限制**：即使做 Share Extension，也只能在用户主动分享时触发

**结论**：iOS 用户**只能**用"手动添加"路径（Step 3）+ "通知栏 widget"（Step 11）+ Siri Shortcut（iOS 16+ App Intents）。

---

## 九、引用

- 上次 commit：[commit_14.md](file:///d:/others/app/Bulter/doc/git_log/commit_14.md)（Step 9 简报系统）
- 设计：[doc/first/01-architecture.md](file:///d:/others/app/Bulter/doc/first/01-architecture.md) §九（输入路径）
- 计划：[doc/first/plan.md](file:///d:/others/app/Bulter/doc/first/plan.md) §第 10 步
- 协议：[doc/first/03-tech.md](file:///d:/others/app/Bulter/doc/first/03-tech.md) §三（MethodChannel 桥接）
- Flutter packages：
  - [flutter_overlay_window](https://pub.dev/packages/flutter_overlay_window)
  - [screen_capturer](https://pub.dev/packages/screen_capturer)
  - [speech_to_text](https://pub.dev/packages/speech_to_text)
  - [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)
- Android 官方文档：
  - [AccessibilityService.takeScreenshot](https://developer.android.com/reference/android/accessibilityservice/AccessibilityService#takeScreenshot%28android.view.Display,%20java.util.concurrent.Executor,%20android.accessibilityservice.AccessibilityService.TakeScreenshotCallback%29)
  - [WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY](https://developer.android.com/reference/android/view/WindowManager.LayoutParams#TYPE_APPLICATION_OVERLAY)
  - [Bitmap.wrapHardwareBuffer](https://developer.android.com/reference/android/graphics/Bitmap#wrapHardwareBuffer%28android.hardware.HardwareBuffer,%20android.graphics.ColorSpace%29)
