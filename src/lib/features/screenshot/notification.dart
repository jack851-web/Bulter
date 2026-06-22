import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 顶部轻通知（Step 10）。
///
/// **简化方案**（不用 `flutter_local_notifications` package）：
/// - 通过 `OverlayEntry` 在 app root 顶部弹出 1.5s 自动消失的胶囊通知
/// - 自带队列机制（同一时间最多 1 个）
/// - 失败 / 错误用 BulterColors.warning / danger 配色
///
/// 后续可替换为 `flutter_local_notifications` package 以支持**系统级**通知。
class BulterNotification {
  BulterNotification._();

  static OverlayEntry? _currentEntry;
  static final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  /// 全局注册 navigatorKey（在 MaterialApp 里用）。
  static GlobalKey<NavigatorState> get navKey => _navKey;

  static void showToast(
    String message, {
    BulterNotificationKind kind = BulterNotificationKind.info,
  }) {
    final overlay = _navKey.currentState?.overlay;
    if (overlay == null) {
      // 无 navigator（如测试环境），降级为 print
      debugPrint('BulterNotification: $message');
      return;
    }
    // 移除旧通知（防止堆叠）
    _currentEntry?.remove();
    _currentEntry = null;

    final entry = OverlayEntry(
      builder: (_) => _NotificationToast(message: message, kind: kind),
    );
    _currentEntry = entry;
    overlay.insert(entry);
    // 1.5s 自动消失
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (_currentEntry == entry) {
        entry.remove();
        _currentEntry = null;
      }
    });
  }
}

enum BulterNotificationKind { info, success, warning, error }

class _NotificationToast extends StatefulWidget {
  final String message;
  final BulterNotificationKind kind;
  const _NotificationToast({required this.message, required this.kind});

  @override
  State<_NotificationToast> createState() => _NotificationToastState();
}

class _NotificationToastState extends State<_NotificationToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(_opacity);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _bgColor() {
    switch (widget.kind) {
      case BulterNotificationKind.success:
        return BulterColors.success;
      case BulterNotificationKind.warning:
        return BulterColors.warning;
      case BulterNotificationKind.error:
        return BulterColors.error;
      case BulterNotificationKind.info:
        return BulterColors.textPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: BulterSpacing.l,
      right: BulterSpacing.l,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _slide,
          child: FadeTransition(
            opacity: _opacity,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: BulterSpacing.m,
                vertical: BulterSpacing.s,
              ),
              decoration: BoxDecoration(
                color: _bgColor(),
                borderRadius: BorderRadius.circular(BulterRadius.m),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SvgIconProxy(),
                  const SizedBox(width: BulterSpacing.s),
                  Flexible(
                    child: Text(
                      widget.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: BulterFontSize.body,
                        fontWeight: BulterFontWeight.semibold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 临时图标代理（不依赖具体 svg 资源）。
class SvgIconProxy extends StatelessWidget {
  const SvgIconProxy();
  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.info_outline, color: Colors.white, size: 18);
  }
}
