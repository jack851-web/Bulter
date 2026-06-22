# Bulter 平台桥接（Platform Bridge）— Step 10 配套文档

> **范围**：本文档描述 Step 10（**浮窗输入路径**）所依赖的 **Android 原生层** + **Flutter 桥接层** + **应用层** 的完整技术方案。
>
> **iOS 范围**：**暂不实现**。iOS 系统限制（无 `AccessibilityService` 等价物、沙盒限制、ScreenCapture 需要 ReplayKit）让"任意 App 浮窗 + 截图"在 iOS 上不可行。iOS 用户可使用"手动添加"路径（Step 3）作为替代。
>
> **生效版本**：0.9.0+
>
> **核心原则**：**用 Flutter 写**。原生代码（Kotlin）仅作为 Flutter packages 的底层依赖，**不直接手写**。

---

## 一、产品定位

### 1.1 浮窗交互规范

| 用户动作 | 系统反馈 | Bulter 行为 |
|---|---|---|
| **单击浮窗** | 截图当前屏幕 → toast "正在识别…" → AI 自动完成任务 | 截屏 → MiniMax M3 多模态推理 → 自动归类到对应模块 → **自动写库**（无需用户确认）→ 顶部短暂通知"已记录到 X 模块" |
| **长按浮窗**（≥ 500ms） | 浮窗展开语音输入面板 → 麦克风按钮 + 实时波形 | 启动语音识别 → 用户说话 → 文字实时上屏 → 松手自动发给 AI 对话页 → 直接获得 AI 回答 |
| **拖拽浮窗** | 浮窗跟随手指移动 | 移动到屏幕任意位置（默认贴右 / 左边缘） → 松手吸附 |
| **三指下滑 / 双击**（v1.1 可选） | 浮窗半透明闪烁 | 隐藏浮窗 1 小时（临时不被打扰） |

### 1.2 关键设计原则

#### 原则 1：单击截图 → **自动完成**（不弹确认页）

用户在别的 App 里已经被打断了一次。再弹个 Bulter 确认页是**二次打断**，违背"被动浏览"原则。

**正确做法**：
- 单击 → 截图 → AI 推理（3s） → 自动写库 → 顶部轻通知"已记录到 X 模块"（1.5s 自动消失）
- 失败 / 置信度 < 0.5 → 自动降级到对话页让用户修正（"我看到一张截图但不确定是什么…"）

#### 原则 2：长按语音输入 → **直接对话**

语音是更快的"被动输入"。用户长按浮窗 → 说话 → 松手 → 直接进入 AI 对话页（**不经过"按回车"**）。

#### 原则 3：浮窗**不主动打扰**

- 浮窗默认 56×56dp 小圆按钮，半透明（30% 不透明度）
- 5 秒内无操作 → 完全透明（仅占位不显示）
- 长按 / 拖拽时高亮 + 90% 不透明度

#### 原则 4：截图**永不离开设备**

- 原图：截到后立刻删除
- 缩略图：本地存储，仅在 AI 推理时临时上传（base64 + 多模态 API）
- 无障碍文本预览：本地缓存，**不主动发给云端**

### 1.3 三层职责

```
┌─────────────────────────────────────────────────────────────┐
│  Flutter 应用层 (Dart)                                       │
│  ────────────────────                                        │
│  • lib/overlay/overlay_entry.dart  浮窗入口 / 生命周期管理   │
│  • lib/overlay/overlay_widget.dart 浮窗 UI（圆按钮 + 状态）  │
│  • lib/ai/scene_inference.dart     复用 Step 8 多模态推理    │
│  • lib/ai/voice_input.dart         语音 → 文字              │
│  • lib/features/screenshot/...      自动入库 + 顶部轻通知   │
└─────────────────┬───────────────────────────────────────────┘
                  │ Flutter packages（已封装原生代码）
┌─────────────────▼───────────────────────────────────────────┐
│  Flutter packages 层                                         │
│  ────────────────────                                        │
│  • flutter_overlay_window   跨 App 浮窗（已封装 Android 原生）│
│  • screen_capturer          系统截图（已封装 MediaProjection）│
│  • speech_to_text           语音识别（已封装 SpeechRecognizer）│
│  • flutter_local_notifications  顶部通知                    │
└─────────────────┬───────────────────────────────────────────┘
                  │ pub.dev 维护（**用户不写 Kotlin**）
┌─────────────────▼───────────────────────────────────────────┐
│  Android 原生层 (Kotlin, 由 packages 提供)                    │
│  ────────────────────                                        │
│  • WindowManager 浮窗 + MediaProjection + SpeechRecognizer   │
│  • 用户安装的 package 自带，无需手写 Kotlin                   │
└─────────────────────────────────────────────────────────────┘
```

**关键**：**用户不需要打开 Android Studio**。所有 Kotlin 由 pub.dev 上维护的 package 提供。开发流程：

```bash
flutter pub add flutter_overlay_window screen_capturer speech_to_text
flutter pub get
flutter run         # 或 flutter build apk
```

`flutter run` 自动编译 Kotlin 部分（Gradle 在后台跑），用户**完全不需要看到 Kotlin**。

---

## 二、依赖的 Flutter packages

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
// image.path = /data/user/0/<pkg>/cache/<uuid>.png
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

顶部轻通知（截屏完成后显示"已记录到 X 模块"）。

```dart
await flutterLocalNotificationsPlugin.show(
  0, 'Bulter', '已记录到 关系模块',
  NotificationDetails(android: AndroidNotificationDetails(...)),
);
```

---

## 三、应用层架构

### 3.1 模块文件

```
lib/
├── overlay/
│   ├── overlay_entry.dart       # 浮窗生命周期管理
│   ├── overlay_widget.dart      # 浮窗 UI（圆按钮）
│   └── overlay_actions.dart     # 单击/长按事件处理
├── ai/
│   ├── scene_inference.dart     # 复用 Step 8 多模态
│   └── voice_input.dart         # 语音 → 文字
├── features/
│   ├── screenshot/
│   │   ├── auto_sink.dart       # 场景归类后自动调子 Agent 写库
│   │   └── notification.dart    # 顶部轻通知
│   └── chat/
│       └── chat_page.dart       # 复用 Step 7 AI 对话
```

### 3.2 数据流：单击截图 → 自动入库

```
[用户] 单击浮窗
       ↓
[overlay] 回调到主 App
       ↓
[screen_capturer] capture() → 系统弹窗授权
       ↓
[image saved to /cache/<uuid>.png]
       ↓
[删除原图] File.delete()
       ↓
[生成缩略图 256x宽] → /screenshots/<uuid>_thumb.jpg
       ↓
[scene_inference] infer(thumbPath + context) → SceneInference
       ↓
[如果 confidence >= 0.5]
       ↓
[auto_sink] 调对应模块的子 Agent 写库
       ↓
[flutter_local_notifications] 顶部通知"已记录到 X 模块"（1.5s 消失）
       ↓
[结束]
       ↓
[如果 confidence < 0.5 或失败]
       ↓
[push ChatPage] 预填 "我看到一张截图但不确定是什么…" + 缩略图附件
```

### 3.3 数据流：长按语音输入

```
[用户] 长按浮窗 ≥ 500ms
       ↓
[overlay] 回调到主 App
       ↓
[speech_to_text] initialize() + listen()
       ↓
[overlay UI 展开语音面板]
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

### 3.4 自动入库的实现（auto_sink.dart）

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

---

## 四、Schema 迁移

### 4.1 复用 Step 9 的 `screenshots` 表

Step 10 复用 Step 9 加的 `screenshots` 表，无需新增表。

```sql
CREATE TABLE screenshots (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  thumb_path TEXT NOT NULL,
  package_name TEXT,
  window_title TEXT,
  text_preview TEXT,
  inferred_category TEXT,
  inferred_confidence REAL,
  inferred_summary TEXT,
  inferred_json TEXT,
  user_category TEXT,
  user_actions_json TEXT,
  reviewed_at INTEGER,           -- 自动入库后填
  created_at INTEGER NOT NULL
);
```

**Step 10 调整**：
- `user_category` 字段含义从"用户手动改的归类" → "自动入库的目标归类"
- `reviewed_at` 自动入库后立即填（不需要用户 review）
- 增加 `auto_sink_status` 字段（'success' / 'low_confidence' / 'unknown_category' / 'subagent_failed'）

### 4.2 迁移

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

## 五、隐私与安全

### 5.1 不上传原图

| 数据 | 流向 |
|---|---|
| 截图原图 | 截到后**立即删除**（`File.delete()`），从不离开设备 |
| 缩略图（256×宽） | 本地存储；AI 推理时临时 base64 上传多模态 API |
| 无障碍文本预览 | 本地缓存；**不**主动发给云端 |
| 语音音频 | Google Speech-to-Text 转文字后丢弃音频流 |

### 5.2 权限申请时机

| 权限 | 申请时机 | 用户可拒绝吗 |
|---|---|---|
| `SYSTEM_ALERT_WINDOW` | 首次"启用浮窗"时跳转系统设置 | ✅ |
| `RECORD_AUDIO` | 首次长按浮窗时由系统弹窗 | ✅ |
| `MediaProjection`（截图） | 每次截图前由 Android 系统弹窗 | ✅ |

### 5.3 关闭路径

设置页提供：
- "停用浮窗" → 调 `FlutterOverlayWindow.closeOverlay()`
- "清空截图历史" → 删除本地 `screenshots` 表 + `screenshots/` 目录

---

## 六、测试矩阵

### 6.1 开发期（Dart 单测）

| 测试 | 工具 |
|---|---|
| `scene_inference` JSON 解析容错 | `flutter test` |
| `auto_sink` 置信度阈值 | `flutter test` + mock |
| `voice_input` 文字分段 | `flutter test` |

### 6.2 集成期（Android 真机）

| 测试 | 通过条件 |
|---|---|
| 浮窗启停 | `closeOverlay()` 后浮窗消失 |
| 跨 App 存在 | 切到微信 / Chrome / 设置，浮窗仍在 |
| 单击截图 | 系统弹授权 → 截屏 → 顶部通知"已记录到 X 模块" |
| 长按语音 | 长按 500ms → 展开面板 → 录音 → 松手跳对话页 |
| 拖拽位置 | 拖到右下角，重启后位置保留 |
| 多次单击 | 每次截图都生成新缩略图 + 自动入库 |
| 切到 Bulter 自己 | 浮窗**自动隐藏**（避免遮挡自家 UI） |

### 6.3 边界 case

| case | 期望 |
|---|---|
| 用户拒绝浮窗权限 | 顶部 toast "需要浮窗权限才能跨 App 输入"；引导跳转设置 |
| 用户拒绝麦克风权限 | 长按 → 提示"需要麦克风权限才能语音输入"；降级到文字 |
| 用户拒绝 MediaProjection | 截图 → 通知"截图失败，请重试"；不弹确认页 |
| 屏幕锁屏 / 来电中断 | 语音识别自动停止；截图失败重试 |
| AI 推理超时 | 自动降级到对话页 + 缩略图附件 |

---

## 七、为什么不用手写 Kotlin

用户开发机**没有 Android Studio**。如果手写 Kotlin：
1. 缺少 IDE 智能提示
2. 编译/调试慢（Gradle 增量编译 vs Flutter Hot Reload 秒级）
3. 业务代码跨 Dart ↔ Kotlin 切换心智负担

**用 Flutter packages 的优势**：
1. **业务代码 100% Dart**（与 Bulter 其它 Step 一致）
2. **Hot Reload 调试体验**（Kotlin 改动要重新 Gradle 编译）
3. **包维护** = 跨 Android 版本兼容性 + 安全更新（pub.dev 社区维护）
4. **未来跨平台** 容易（如果以后 macOS / iOS 有类似 API，可换 pub 上的对应 package）

**代价**：
- 部分包可能不如原生直接调用灵活（例如截屏只能触发系统授权一次）
- 多一层间接（性能损耗极小，不影响 UX）

**结论**：**优先用 Flutter packages**，**不**手写 Kotlin。**仅在** Flutter 包无法覆盖的场景（如自定义无障碍服务）才考虑走 MethodChannel 自定义。

---

## 八、iOS 路径（暂不实现）

iOS 的限制：
1. **无 `AccessibilityService` 等价 API**：iOS 没有可跨 App 监听窗口 / 文本的服务
2. **无跨 App 浮窗**：iOS 13+ 浮窗必须用 `UIWindowScene` + 自家 App 内部
3. **MediaProjection 仅 ReplayKit**：且需要 App 在前台录制，不能后台
4. **沙盒限制**：即使做 Share Extension，也只能在用户主动分享时触发

**结论**：iOS 用户**只能**用"手动添加"路径（Step 3）+ "通知栏 widget"（Step 11）+ Siri Shortcut（iOS 16+ App Intents）。

iOS 替代方案（未来可做）：
- **Share Extension**：用户在微信聊天里点分享 → 选 Bulter → 文本传进 Flutter → 走 `scene_inference`
- **App Intents (iOS 16+)**：Siri Shortcut 调 Bulter 添加

---

## 九、交互决策附录

### 9.1 为什么单击"自动完成"而不是"先确认"？

| 方案 | 优点 | 缺点 |
|---|---|---|
| **方案 A（自动完成）** ✅ | 用户**不被二次打断**；UX 流畅；AI 置信度高时准确 | 偶尔 AI 误判需要手动修正 |
| 方案 B（弹确认页） | 100% 准确；用户可控 | 二次打断；UX 卡顿；违背"被动浏览" |

**决策**：方案 A。
- Step 9 简报系统已经展示了 AI 摘要能力，多模态推理（MiniMax M3）准确率 > 90%
- 置信度 < 0.5 降级到对话页（用户可修正）
- 顶部轻通知（1.5s）让用户知道发生了什么

### 9.2 为什么长按"语音输入"而不是"语音笔记"？

语音输入是**对话的快捷方式**（不是"新建一条记录"）。用户长按 → 说话 → 直接进入 AI 对话，得到的是**回答**，不是"被记录的一行字"。

这符合 Bulter 的核心定位：**AI 助理**，不是**日记 App**。

### 9.3 浮窗大小 / 位置 / 透明度规范

| 属性 | 默认值 | 可调 |
|---|---|---|
| 大小 | 56×56dp | 长按可调（v1.1） |
| 位置 | 屏幕右下角，margin 24dp | 拖拽 |
| 不透明度（静止） | 30% | — |
| 不透明度（长按 / 拖拽） | 90% | — |
| 吸附 | 右 / 左边缘 | — |

---

## 十、引用

- 上次 commit：[commit_14.md](file:///d:/others/app/Bulter/doc/git_log/commit_14.md)（Step 9 简报系统）
- 设计：[doc/first/01-architecture.md](file:///d:/others/app/Bulter/doc/first/01-architecture.md) §九（输入路径）
- 计划：[doc/first/plan.md](file:///d:/others/app/Bulter/doc/first/plan.md) §第 10 步
- 协议：[doc/first/03-tech.md](file:///d:/others/app/Bulter/doc/first/03-tech.md) §三（MethodChannel 桥接）
- Flutter packages：
  - [flutter_overlay_window](https://pub.dev/packages/flutter_overlay_window)
  - [screen_capturer](https://pub.dev/packages/screen_capturer)
  - [speech_to_text](https://pub.dev/packages/speech_to_text)
  - [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)
