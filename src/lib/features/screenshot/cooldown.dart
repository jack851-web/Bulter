/// 3s 截图冷却控制（Step 10）。
///
/// **Dart 端冷却保护**——Kotlin `BulterPlatformPlugin` 也有 3s 冷却，
/// 但万一 Kotlin 端被绕过（直接调 MethodChannel），Dart 端再挡一层。
///
/// **设计**：滑动窗口式冷却（不是"上一次时间 + 比较"），
/// 防止并发请求都通过检查。
class Cooldown {
  final Duration window;
  DateTime? _lastAcquired;

  Cooldown({required this.window});

  /// 尝试获取一次"截图许可"。
  /// - 窗口外（距离上次 ≥ window）→ 返回 true，更新时间戳
  /// - 窗口内（距离上次 < window）→ 返回 false，**不**更新时间戳
  bool tryAcquire() {
    final now = DateTime.now();
    final last = _lastAcquired;
    if (last == null || now.difference(last) >= window) {
      _lastAcquired = now;
      return true;
    }
    return false;
  }

  /// 剩余冷却时间（用于 UI 显示"X 秒后可再试"）。
  Duration remaining() {
    final last = _lastAcquired;
    if (last == null) return Duration.zero;
    final elapsed = DateTime.now().difference(last);
    final r = window - elapsed;
    return r.isNegative ? Duration.zero : r;
  }

  /// 重置（手动取消冷却）。
  void reset() {
    _lastAcquired = null;
  }
}
