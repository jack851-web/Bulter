import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/tokens.dart';

/// SVG 图标统一封装。
///
/// 用法：
/// ```dart
/// const SvgIcon('common/close.svg', size: 18, color: BulterColors.textPrimary)
/// ```
///
/// 资源路径以 `assets/svg/` 为根。例如 `SvgIcon('common/close.svg')` 实际加载
/// `assets/svg/common/close.svg`。
///
/// 设计原则：
/// - 全部图标 24x24 viewBox，stroke 风格 1.75px，currentColor 着色。
/// - 颜色通过 `color` 覆盖；不传时按主题（默认 textPrimary）。
/// - 失败兜底为空 SizedBox，不抛异常。
class SvgIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;
  final double strokeWidth;

  const SvgIcon(
    this.name, {
    super.key,
    this.size = 20,
    this.color,
    this.strokeWidth = 1.75,
  });

  /// 内部加 asset/ 前缀，外部只传 `common/close.svg` 这样的相对路径。
  String get _assetPath {
    if (name.startsWith('assets/')) return name;
    return 'assets/svg/$name';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        _assetPath,
        width: size,
        height: size,
        colorFilter: color == null
            ? null
            : ColorFilter.mode(color!, BlendMode.srcIn),
        placeholderBuilder: (_) => SizedBox(width: size, height: size),
      ),
    );
  }
}

/// 圆形按钮容器：内含一个 SvgIcon。常用于顶栏 / 弹窗的关闭 / 设置按钮。
class SvgIconButton extends StatelessWidget {
  final String iconName;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color? background;
  final Color? color;
  final double elevation;

  const SvgIconButton({
    super.key,
    required this.iconName,
    required this.onTap,
    this.size = 36,
    this.iconSize = 18,
    this.background,
    this.color,
    this.elevation = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background ?? BulterColors.surface,
      shape: const CircleBorder(),
      elevation: elevation,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: SvgIcon(
              iconName,
              size: iconSize,
              color: color ?? BulterColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
