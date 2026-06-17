import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:bulter/db/app_database.dart';

import '../../theme/tokens.dart';
import '../form/amount_input.dart';
import '../form/choice_chips_field.dart';
import '../form/date_picker_field.dart';
import '../form/text_field_card.dart';

/// 人情债新增/编辑表单。
class FavorForm extends StatefulWidget {
  final int contactId;
  final Favor? initial;
  final String title;
  final void Function(FavorsCompanion data) onSubmit;

  const FavorForm({
    super.key,
    required this.contactId,
    required this.title,
    required this.onSubmit,
    this.initial,
  });

  @override
  State<FavorForm> createState() => _FavorFormState();
}

class _FavorFormState extends State<FavorForm> {
  final _desc = TextEditingController();
  String _direction = 'i_owe';
  int? _amountCents;
  DateTime _when = DateTime.now();

  static const _dirs = ['i_owe', 'they_owe', 'gift_given', 'gift_received'];
  static const _dirLabels = {
    'i_owe': '我欠对方',
    'they_owe': '对方欠我',
    'gift_given': '我送出的',
    'gift_received': '我收到的',
  };

  @override
  void initState() {
    super.initState();
    final f = widget.initial;
    if (f != null) {
      _desc.text = f.description;
      _direction = f.direction;
      _amountCents = f.amountCents == 0 ? null : f.amountCents;
      _when = f.happenedAt;
    }
  }

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  void _submit() {
    final d = _desc.text.trim();
    if (d.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请描述这笔人情')),
      );
      return;
    }
    final data = FavorsCompanion(
      id: widget.initial == null
          ? const Value.absent()
          : Value(widget.initial!.id),
      contactId: Value(widget.contactId),
      direction: Value(_direction),
      description: Value(d),
      amountCents: Value(_amountCents ?? 0),
      status: Value(widget.initial?.status ?? 'open'),
      happenedAt: Value(_when),
      closedAt: Value(widget.initial?.closedAt),
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
              label: '类型',
              value: _direction,
              options: _dirs,
              labels: _dirLabels,
              onChanged: (v) => setState(() => _direction = v),
            ),
            const SizedBox(height: BulterSpacing.l),
            DatePickerField(
              label: '发生时间',
              value: _when,
              includeTime: false,
              onChanged: (v) => setState(() => _when = v ?? DateTime.now()),
            ),
            const SizedBox(height: BulterSpacing.l),
            TextFieldCard(
              label: '描述 *',
              controller: _desc,
              hint: '如：2024 春节红包 / 婚礼礼金 / 帮忙搬家…',
              maxLines: 3,
              minLines: 2,
            ),
            const SizedBox(height: BulterSpacing.l),
            AmountInput(
              label: '金额（可选）',
              cents: _amountCents,
              onChanged: (v) => setState(() => _amountCents = v),
              hint: '不填则不计金额',
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
                  widget.initial == null ? '保存' : '更新',
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
