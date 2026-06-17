import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 通用页面骨架：顶部 safe area + 标题 + 内容
class BulterScaffold extends StatelessWidget {
  final String? title;
  final Widget child;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final EdgeInsetsGeometry contentPadding;

  const BulterScaffold({
    super.key,
    required this.child,
    this.title,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.actions,
    this.backgroundColor,
    this.contentPadding =
        const EdgeInsets.symmetric(horizontal: BulterSpacing.l),
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? BulterColors.canvas,
      appBar: title == null
          ? null
          : AppBar(
              title: Text(title!),
              actions: actions,
            ),
      body: SafeArea(
        child: Padding(padding: contentPadding, child: child),
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
