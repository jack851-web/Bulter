import 'package:flutter/material.dart';

import '../../components/empty_state.dart';
import '../../components/svg_icon.dart';
import '../../theme/tokens.dart';

/// 通用列表页骨架：标题栏 + 列表 + 空态 + 错误态。
///
/// 业务列表页直接传入 [Stream<List<T>>] 与 [itemBuilder]，自动处理：
/// - 加载中：显示居中 progress
/// - 错误：显示红色文案
/// - 空：显示 [EmptyState]
/// - 有数据：按 [itemBuilder] 渲染
class StreamListView<T> extends StatelessWidget {
  final Stream<List<T>> stream;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final String emptyTitle;
  final String? emptyHint;
  final String emptyIconName;
  final Color? brandColor;
  final Widget? header;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;

  const StreamListView({
    super.key,
    required this.stream,
    required this.itemBuilder,
    required this.emptyTitle,
    this.emptyHint,
    this.emptyIconName = 'common/inbox.svg',
    this.brandColor,
    this.header,
    this.padding = const EdgeInsets.fromLTRB(
      BulterSpacing.l,
      BulterSpacing.s,
      BulterSpacing.l,
      BulterSpacing.huge,
    ),
    this.physics = const BouncingScrollPhysics(),
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<T>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (snap.hasError) {
          return EmptyState(
            icon: const SvgIcon(
              'common/error.svg',
              size: 32,
              color: BulterColors.error,
            ),
            title: '加载失败',
            hint: snap.error.toString(),
          );
        }
        final items = snap.data ?? const <Never>[];
        if (items.isEmpty) {
          return Center(
            child: EmptyState(
              icon: SvgIcon(
                emptyIconName,
                size: 32,
                color: brandColor ?? BulterColors.textSecondary,
              ),
              title: emptyTitle,
              hint: emptyHint,
              action: brandColor == null
                  ? null
                  : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: BulterSpacing.l,
                        vertical: BulterSpacing.s,
                      ),
                      decoration: BoxDecoration(
                        color: brandColor!.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(BulterRadius.pill),
                      ),
                      child: Text(
                        '点击右下角 + 创建第一条',
                        style: TextStyle(
                          fontSize: BulterFontSize.footnote,
                          color: brandColor,
                          fontWeight: BulterFontWeight.semibold,
                        ),
                      ),
                    ),
            ),
          );
        }
        return ListView.separated(
          physics: physics,
          padding: padding,
          itemCount: items.length + (header == null ? 0 : 1),
          separatorBuilder: (_, _) => const SizedBox(height: BulterSpacing.m),
          itemBuilder: (context, i) {
            if (header != null && i == 0) return header!;
            final idx = header == null ? i : i - 1;
            return itemBuilder(context, items[idx], idx);
          },
        );
      },
    );
  }
}

/// 通用卡片：白底 + 圆角 + 轻分割线。
class ListCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? brandColor;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;

  const ListCard({
    super.key,
    required this.child,
    this.onTap,
    this.brandColor,
    this.padding = const EdgeInsets.all(BulterSpacing.l),
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BulterColors.surface,
      borderRadius: BorderRadius.circular(BulterRadius.l),
      child: InkWell(
        borderRadius: BorderRadius.circular(BulterRadius.l),
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BulterRadius.l),
            border: Border.all(color: BulterColors.divider, width: 0.6),
          ),
          child: Row(
            children: [
              if (brandColor != null) ...[
                Container(
                  width: 4,
                  height: 36,
                  decoration: BoxDecoration(
                    color: brandColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: BulterSpacing.m),
              ],
              Expanded(child: child),
              if (trailing != null) ...[
                const SizedBox(width: BulterSpacing.s),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
