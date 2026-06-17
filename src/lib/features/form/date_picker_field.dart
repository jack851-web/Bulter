import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 日期/时间选择字段：点击唤起原生 [showDatePicker] / [showTimePicker]。
///
/// 兼容 null：清空按钮会传 null。展示格式 `yyyy-MM-dd HH:mm`（可自定义）。
class DatePickerField extends StatelessWidget {
  final String? label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool includeTime;
  final String? hint;

  const DatePickerField({
    super.key,
    this.label,
    this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.includeTime = false,
    this.hint,
  });

  String _two(int n) => n.toString().padLeft(2, '0');

  String _format(DateTime v) {
    final date =
        '${v.year.toString().padLeft(4, '0')}-${_two(v.month)}-${_two(v.day)}';
    if (!includeTime) return date;
    return '$date ${_two(v.hour)}:${_two(v.minute)}';
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final initial = value ?? now;
    final first = firstDate ?? DateTime(now.year - 50);
    final last = lastDate ?? DateTime(now.year + 10);
    final picked = await showDatePicker(
      context: context,
      initialDate: (initial.isAfter(first) && initial.isBefore(last))
          ? initial
          : now,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null) return;
    if (!includeTime) {
      onChanged(picked);
      return;
    }
    if (!context.mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    onChanged(
      DateTime(
        picked.year,
        picked.month,
        picked.day,
        t?.hour ?? initial.hour,
        t?.minute ?? initial.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              fontSize: BulterFontSize.footnote,
              fontWeight: BulterFontWeight.semibold,
              color: BulterColors.textSecondary,
            ),
          ),
          const SizedBox(height: BulterSpacing.xs + 2),
        ],
        InkWell(
          borderRadius: BorderRadius.circular(BulterRadius.m),
          onTap: () => _pick(context),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: BulterSpacing.l,
              vertical: BulterSpacing.m + 4,
            ),
            decoration: BoxDecoration(
              color: BulterColors.surface,
              borderRadius: BorderRadius.circular(BulterRadius.m),
              border: Border.all(color: BulterColors.divider, width: 0.8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.event_outlined,
                  size: 18,
                  color: BulterColors.textSecondary,
                ),
                const SizedBox(width: BulterSpacing.m),
                Expanded(
                  child: Text(
                    value == null
                        ? (hint ?? '选择日期${includeTime ? '与时间' : ''}')
                        : _format(value!),
                    style: TextStyle(
                      fontSize: BulterFontSize.bodyLg,
                      color: value == null
                          ? BulterColors.textTertiary
                          : BulterColors.textPrimary,
                    ),
                  ),
                ),
                if (value != null)
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: BulterColors.textSecondary,
                    ),
                    onPressed: () => onChanged(null),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
