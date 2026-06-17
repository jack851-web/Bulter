import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:bulter/db/app_database.dart';

import '../../theme/tokens.dart';
import '../form/choice_chips_field.dart';
import '../form/date_picker_field.dart';
import '../form/text_field_card.dart';

/// 写给自己的信 新增/编辑表单。
class LetterForm extends StatefulWidget {
  final Letter? initial;
  final String title;
  final void Function(LettersCompanion data) onSubmit;

  const LetterForm({
    super.key,
    required this.title,
    required this.onSubmit,
    this.initial,
  });

  @override
  State<LetterForm> createState() => _LetterFormState();
}

class _LetterFormState extends State<LetterForm> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  String _type = 'to_self';
  DateTime? _targetDate;

  static const _types = ['to_self', 'to_others', 'to_future'];
  static const _typeLabels = {
    'to_self': '写给自己',
    'to_others': '写给某人',
    'to_future': '写给未来的自己',
  };

  @override
  void initState() {
    super.initState();
    final l = widget.initial;
    if (l != null) {
      _title.text = l.title;
      _content.text = l.content;
      _type = l.type;
      _targetDate = l.targetDate;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _title.text.trim();
    if (t.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入信件标题')),
      );
      return;
    }
    final c = _content.text.trim();
    if (c.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入信件内容')),
      );
      return;
    }
    final data = LettersCompanion(
      id: widget.initial == null
          ? const Value.absent()
          : Value(widget.initial!.id),
      title: Value(t),
      content: Value(c),
      type: Value(_type),
      targetDate: Value(_targetDate),
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
              label: '写给…',
              value: _type,
              options: _types,
              labels: _typeLabels,
              onChanged: (v) => setState(() => _type = v),
            ),
            const SizedBox(height: BulterSpacing.l),
            TextFieldCard(
              label: '标题 *',
              controller: _title,
              hint: '如：给 5 年后的自己',
            ),
            const SizedBox(height: BulterSpacing.l),
            TextFieldCard(
              label: '正文 *',
              controller: _content,
              hint: '想说的话…',
              maxLines: 16,
              minLines: 8,
            ),
            const SizedBox(height: BulterSpacing.l),
            DatePickerField(
              label: '投递日期（可空）',
              value: _targetDate,
              onChanged: (v) => setState(() => _targetDate = v),
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
                  widget.initial == null ? '封存' : '更新',
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
