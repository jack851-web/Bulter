import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Chip 多标签输入：底部展示已添加的 chip + 文本框输入 + 回车添加。
///
/// 适合"联系人标签 / 思想标签"等场景。空状态有引导文案。
class ChipsInput extends StatefulWidget {
  final String label;
  final String? hint;
  final List<String> initial;
  final ValueChanged<List<String>> onChanged;
  final int maxChips;

  const ChipsInput({
    super.key,
    required this.label,
    required this.onChanged,
    this.hint,
    this.initial = const [],
    this.maxChips = 20,
  });

  @override
  State<ChipsInput> createState() => _ChipsInputState();
}

class _ChipsInputState extends State<ChipsInput> {
  late List<String> _chips;
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _chips = List.of(widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return;
    if (_chips.length >= widget.maxChips) return;
    if (_chips.contains(v)) {
      _controller.clear();
      return;
    }
    setState(() {
      _chips.add(v);
      _controller.clear();
    });
    widget.onChanged(List.of(_chips));
  }

  void _remove(String v) {
    setState(() => _chips.remove(v));
    widget.onChanged(List.of(_chips));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: BulterFontSize.footnote,
            fontWeight: BulterFontWeight.semibold,
            color: BulterColors.textSecondary,
          ),
        ),
        const SizedBox(height: BulterSpacing.xs + 2),
        if (_chips.isNotEmpty)
          Wrap(
            spacing: BulterSpacing.s,
            runSpacing: BulterSpacing.s,
            children: [
              for (final c in _chips)
                Chip(
                  label: Text(c),
                  onDeleted: () => _remove(c),
                  backgroundColor: BulterColors.surface,
                  side: const BorderSide(color: BulterColors.divider, width: 0.6),
                  labelStyle: const TextStyle(
                    fontSize: BulterFontSize.body,
                    color: BulterColors.textPrimary,
                  ),
                  deleteIconColor: BulterColors.textSecondary,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
        if (_chips.isNotEmpty) const SizedBox(height: BulterSpacing.s),
        TextField(
          controller: _controller,
          focusNode: _focus,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) {
            _add(v);
            _focus.requestFocus();
          },
          style: const TextStyle(
            fontSize: BulterFontSize.bodyLg,
            color: BulterColors.textPrimary,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: BulterColors.surface,
            hintText: widget.hint ?? '输入后回车',
            hintStyle: const TextStyle(
              color: BulterColors.textTertiary,
              fontSize: BulterFontSize.bodyLg,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: BulterSpacing.l,
              vertical: BulterSpacing.m + 2,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BulterRadius.m),
              borderSide: const BorderSide(
                color: BulterColors.divider,
                width: 0.8,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BulterRadius.m),
              borderSide: const BorderSide(
                color: BulterColors.cta,
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 把 List<String> 与 JSON 字符串（DAO tagsJson 字段）相互转换。
String tagsToJson(List<String> tags) =>
    tags.map((e) => '"${e.replaceAll('"', r'\"')}"').join(',');

List<String> jsonToTags(String? raw) {
  if (raw == null || raw.isEmpty || raw == '[]') return const [];
  try {
    final s = raw.trim();
    if (!s.startsWith('[') || !s.endsWith(']')) return const [];
    final body = s.substring(1, s.length - 1);
    if (body.isEmpty) return const [];
    final result = <String>[];
    final buf = StringBuffer();
    bool inStr = false;
    for (var i = 0; i < body.length; i++) {
      final ch = body[i];
      if (ch == '"' && (i == 0 || body[i - 1] != r'\')) {
        inStr = !inStr;
        continue;
      }
      if (ch == ',' && !inStr) {
        result.add(buf.toString());
        buf.clear();
        continue;
      }
      buf.write(ch);
    }
    if (buf.isNotEmpty) result.add(buf.toString());
    return result;
  } on Object {
    return const [];
  }
}
