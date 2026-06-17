import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 通用确认弹窗（用于删除等危险操作）。
///
/// 返回 true 表示用户点了"确认"。
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmText = '确认',
  String cancelText = '取消',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: BulterColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BulterRadius.l),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: BulterFontSize.titleS,
            fontWeight: BulterFontWeight.semibold,
            color: BulterColors.textPrimary,
          ),
        ),
        content: message == null
            ? null
            : Text(
                message,
                style: const TextStyle(
                  fontSize: BulterFontSize.body,
                  color: BulterColors.textSecondary,
                  height: 1.5,
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              cancelText,
              style: const TextStyle(
                color: BulterColors.textSecondary,
                fontSize: BulterFontSize.body,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              confirmText,
              style: TextStyle(
                color: destructive ? BulterColors.error : BulterColors.cta,
                fontSize: BulterFontSize.body,
                fontWeight: BulterFontWeight.semibold,
              ),
            ),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
