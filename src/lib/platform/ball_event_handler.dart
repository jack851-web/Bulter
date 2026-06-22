import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../ai/scene_inference.dart';
import '../features/screenshot/auto_sink.dart';
import '../features/screenshot/cooldown.dart';
import '../features/screenshot/notification.dart';

/// Bulter 浮窗事件处理器（Step 10）。
///
/// 监听 Kotlin `BulterPlatformPlugin` 通过 MethodChannel `bulter/ball` 推过来的事件：
/// - `onScreenshotReady(path)` — 截图完成，Dart 端调 AI + 自动入库
/// - `onScreenshotError(code)` — 截图失败（错误码映射）
/// - `onLongPressStart` / `onLongPressEnd` — 长按开始/结束（**Bulter 原方案**：语音输入面板）
/// - `onToast(msg)` — 顶部 toast 提示
///
/// **不**用 Flutter package（`flutter_overlay_window` / `screen_capturer`）——
/// 完全走 Kotlin 原生层（参考另一项目的截图实现）。
class BallEventHandler {
  BallEventHandler._();
  static final BallEventHandler instance = BallEventHandler._();

  static const MethodChannel _channel = MethodChannel('bulter/ball');
  static const int PROTOCOL_VERSION = 1;

  bool _initialized = false;

  /// Dart 侧截图冷却（防 Dart 端被绕过；Kotlin 端也有 3s 冷却）。
  final Cooldown screenshotCooldown = Cooldown(window: const Duration(seconds: 3));

  /// 当前长按状态（用于语音面板 UI）。
  bool _longPressActive = false;
  bool get isLongPressActive => _longPressActive;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler(_handle);
    // 协议版本协商（与 Kotlin PROTOCOL_VERSION = 1 一致）
    try {
      final v = await _channel.invokeMethod<int>('negotiateProtocol');
      if (v != PROTOCOL_VERSION) {
        debugPrint(
            'BallEventHandler: 协议版本不匹配 ($v vs $PROTOCOL_VERSION)，继续运行但可能不稳定');
      } else {
        debugPrint('BallEventHandler: 协议版本协商成功 (v$v)');
      }
    } catch (e) {
      // 桌面 / iOS / 插件未注册——不抛错
      debugPrint('BallEventHandler: 协议协商失败（无插件） - $e');
    }
  }

  Future<dynamic> _handle(MethodCall call) async {
    switch (call.method) {
      case 'onScreenshotReady':
        final path = call.arguments as String? ?? '';
        await _onScreenshotReady(path);
        return null;
      case 'onScreenshotError':
        final code = call.arguments as String? ?? 'UNKNOWN';
        _onScreenshotError(code);
        return null;
      case 'onLongPressStart':
        _longPressActive = true;
        // 通知注册了 listener 的 widget（如语音面板）
        _longPressController.add(true);
        return null;
      case 'onLongPressEnd':
        _longPressActive = false;
        _longPressController.add(false);
        return null;
      case 'onToast':
        final msg = call.arguments as String? ?? '';
        BulterNotification.showToast(msg);
        return null;
      default:
        debugPrint('BallEventHandler: 未知方法 ${call.method}');
        return null;
    }
  }

  /// 启动浮窗服务（Kotlin FloatingBallService）。
  Future<bool> startFloating() async {
    try {
      await _channel.invokeMethod('startFloatingService');
      return true;
    } catch (e) {
      debugPrint('BallEventHandler: startFloating 失败 - $e');
      return false;
    }
  }

  /// 停止浮窗服务。
  Future<bool> stopFloating() async {
    try {
      await _channel.invokeMethod('stopFloatingService');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 长按事件流（语音面板订阅）。
  final StreamController<bool> _longPressController =
      StreamController<bool>.broadcast();
  Stream<bool> get onLongPressChange => _longPressController.stream;

  Future<void> _onScreenshotReady(String path) async {
    if (path.isEmpty) {
      _onScreenshotError('EMPTY_PATH');
      return;
    }
    // Dart 端冷却保护（即使 Kotlin 端绕过了）
    if (!screenshotCooldown.tryAcquire()) {
      BulterNotification.showToast('截图太频繁，请稍后再试');
      return;
    }
    debugPrint('BallEventHandler: 截图完成 - $path');
    BulterNotification.showToast('正在识别...');
    try {
      final result =
          await AutoSinkSink.autoSinkFromScreenshotPath(path);
      if (result.success) {
        BulterNotification.showToast('已记录到 ${result.moduleLabel}');
      } else if (result.lowConfidence) {
        BulterNotification.showToast('置信度低，请手动确认');
        // 可以弹一个"查看截图"按钮让用户跳到对话页
      } else {
        BulterNotification.showToast('识别失败：${result.error ?? "未知"}');
      }
    } catch (e) {
      debugPrint('BallEventHandler: autoSink 异常 - $e');
      BulterNotification.showToast('处理失败：$e');
    }
  }

  void _onScreenshotError(String code) {
    debugPrint('BallEventHandler: 截图错误 - $code');
    final msg = switch (code) {
      'INTERNAL_ERROR' => '截图失败（系统错误）',
      'INTERVAL_TIME_SHORT' => '截图太频繁（系统限流）',
      'NO_ACCESSIBILITY_ACCESS' => '请先在系统设置中开启 Bulter 无障碍服务',
      'SECURE_WINDOW' => '当前 App 禁止截图',
      _ => '截图失败：$code',
    };
    BulterNotification.showToast(msg);
  }
}
