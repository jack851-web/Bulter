import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:bulter/db/app_database.dart';

import '../../theme/tokens.dart';
import '../form/choice_chips_field.dart';
import '../form/date_picker_field.dart';
import '../form/text_field_card.dart';

/// 互动记录新增/编辑表单。
class InteractionForm extends StatefulWidget {
  final int contactId;
  final Interaction? initial;
  final String title;
  final void Function(InteractionsCompanion data) onSubmit;

  const InteractionForm({
    super.key,
    required this.contactId,
    required this.title,
    required this.onSubmit,
    this.initial,
  });

  @override
  State<InteractionForm> createState() => _InteractionFormState();
}

class _InteractionFormState extends State<InteractionForm> {
  final _summary = TextEditingController();
  String _type = 'message';
  DateTime _when = DateTime.now();
  int? _mood;

  static const _types = ['message', 'call', 'meeting', 'meal', 'other'];
  static const _labels = {
    'message': '消息',
    'call': '通话',
    'meeting': '见面',
    'meal': '饭局',
    'other': '其他',
  };

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _summary.text = i.summary;
      _type = i.type;
      _when = i.happenedAt;
      _mood = i.mood;
    }
  }

  @override
  void dispose() {
    _summary.dispose();
    super.dispose();
  }

  void _submit() {
    final s = _summary.text.trim();
    if (s.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写互动摘要')),
      );
      return;
    }
    final data = InteractionsCompanion(
      id: widget.initial == null
          ? const Value.absent()
          : Value(widget.initial!.id),
      contactId: Value(widget.contactId),
      type: Value(_type),
      summary: Value(s),
      happenedAt: Value(_when),
      mood: Value(_mood),
    );
    widget.onSubmit(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BulterColors.canvas,
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            BulterSpacing.l,
            BulterSpacing.l,
            BulterSpacing.l,
            BulterSpacing.huge,
          ),
          children: [
            ChoiceChipsField(
              label: '互动方式',
              value: _type,
              options: _types,
              labels: _labels,
              onChanged: (v) => setState(() => _type = v),
            ),
            const SizedBox(height: BulterSpacing.l),
            DatePickerField(
              label: '时间',
              value: _when,
              includeTime: true,
              onChanged: (v) => setState(() => _when = v ?? DateTime.now()),
            ),
            const SizedBox(height: BulterSpacing.l),
            TextFieldCard(
              label: '内容摘要 *',
              controller: _summary,
              hint: '聊到的话题 / 待跟进事项 / 心情…',
              maxLines: 5,
              minLines: 3,
            ),
            const SizedBox(height: BulterSpacing.l),
            _MoodSelector(
              value: _mood,
              onChanged: (v) => setState(() => _mood = v),
            ),
            const SizedBox(height: BulterSpacing.xxl),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BulterColors.cta,
                  foregroundColor: BulterColors.ctaText,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(BulterRadius.m),
                  ),
                ),
                child: Text(
                  widget.initial == null ? '保存互动' : '更新互动',
                  style: const TextStyle(
                    fontSize: BulterFontSize.bodyLg,
                    fontWeight: BulterFontWeight.semibold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodSelector extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;
  const _MoodSelector({required this.value, required this.onChanged});

  static const _options = [1, 2, 3, 4, 5];
  static const _emojis = ['😞', '😕', '😐', '🙂', '😄'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '这次交流的心情',
          style: TextStyle(
            fontSize: BulterFontSize.footnote,
            fontWeight: BulterFontWeight.semibold,
            color: BulterColors.textSecondary,
          ),
        ),
        const SizedBox(height: BulterSpacing.s),
        Row(
          children: [
            for (var i = 0; i < _options.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: BulterSpacing.s),
                child: InkResponse(
                  onTap: () => onChanged(value == _options[i]
                      ? null
                      : _options[i]),
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: value == _options[i]
                          ? BulterColors.relationship.withValues(alpha: 0.15)
                          : BulterColors.surface,
                      borderRadius:
                          BorderRadius.circular(BulterRadius.l),
                      border: Border.all(
                        color: value == _options[i]
                            ? BulterColors.relationship
                            : BulterColors.divider,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _emojis[i],
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
