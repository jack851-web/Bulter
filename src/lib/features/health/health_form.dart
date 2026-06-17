import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:bulter/db/app_database.dart';

import '../../theme/tokens.dart';
import '../form/choice_chips_field.dart';
import '../form/date_picker_field.dart';
import '../form/misc_inputs.dart';
import '../form/text_field_card.dart';

/// 健康记录新增/编辑表单。
///
/// 表结构使用 valueNum + unit 表达数值与单位；
/// 强度通过 valueNum 表达（可空），时长也通过 valueNum 表达（单位: 分钟）。
class HealthForm extends StatefulWidget {
  final HealthRecord? initial;
  final String title;
  final void Function(HealthRecordsCompanion data) onSubmit;

  const HealthForm({
    super.key,
    required this.title,
    required this.onSubmit,
    this.initial,
  });

  @override
  State<HealthForm> createState() => _HealthFormState();
}

class _HealthFormState extends State<HealthForm> {
  final _valueText = TextEditingController();
  final _note = TextEditingController();
  String _type = 'mood';
  DateTime _when = DateTime.now();
  int? _intensity; // 1-10
  int? _durationMin;

  static const _types = [
    'mood',
    'sleep',
    'exercise',
    'weight',
    'symptom',
    'other',
  ];
  static const _typeLabels = {
    'mood': '心情',
    'sleep': '睡眠',
    'exercise': '运动',
    'weight': '体重',
    'symptom': '症状',
    'other': '其他',
  };

  static const _unitForType = {
    'mood': '1-10',
    'sleep': '小时',
    'exercise': '分钟',
    'weight': 'kg',
    'symptom': '1-10',
    'other': '',
  };

  @override
  void initState() {
    super.initState();
    final h = widget.initial;
    if (h != null) {
      _type = h.type;
      _when = h.occurredAt;
      _note.text = h.notes ?? '';
      _valueText.text = h.valueText ?? '';
      if (h.valueNum != null) {
        if (h.type == 'mood' || h.type == 'symptom') {
          _intensity = h.valueNum!.round();
        } else if (h.type == 'exercise') {
          _durationMin = h.valueNum!.round();
        }
      }
    }
  }

  @override
  void dispose() {
    _valueText.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    double? valueNum;
    if (_type == 'mood' || _type == 'symptom') {
      valueNum = _intensity?.toDouble();
    } else if (_type == 'exercise') {
      valueNum = _durationMin?.toDouble();
    } else if (_valueText.text.trim().isNotEmpty) {
      valueNum = double.tryParse(_valueText.text.trim());
    }
    final data = HealthRecordsCompanion(
      id: widget.initial == null
          ? const Value.absent()
          : Value(widget.initial!.id),
      type: Value(_type),
      valueText: Value(
        _valueText.text.trim().isEmpty ? null : _valueText.text.trim(),
      ),
      valueNum: Value(valueNum),
      unit: Value(
        _unitForType[_type]?.isNotEmpty == true ? _unitForType[_type] : null,
      ),
      occurredAt: Value(_when),
      notes: Value(_note.text.trim().isEmpty ? null : _note.text.trim()),
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
              label: '类别',
              value: _type,
              options: _types,
              labels: _typeLabels,
              onChanged: (v) => setState(() => _type = v),
            ),
            const SizedBox(height: BulterSpacing.l),
            DatePickerField(
              label: '时间',
              value: _when,
              includeTime: false,
              onChanged: (v) => setState(() => _when = v ?? DateTime.now()),
            ),
            const SizedBox(height: BulterSpacing.l),
            if (_type == 'mood' || _type == 'symptom')
              ProgressSliderField(
                label: '评分（${_unitForType[_type] ?? ''}）',
                value: _intensity ?? 5,
                formatter: (v) => '$v / 10',
                onChanged: (v) => setState(() => _intensity = v),
              )
            else if (_type == 'exercise')
              IntegerInput(
                label: '时长（分钟）',
                value: _durationMin,
                onChanged: (v) => setState(() => _durationMin = v),
              )
            else if (_type == 'sleep')
              TextFieldCard(
                label: '睡眠时长（小时）',
                hint: '如 7.5',
                controller: _valueText,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              )
            else if (_type == 'weight')
              TextFieldCard(
                label: '体重（kg）',
                hint: '如 65.5',
                controller: _valueText,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              )
            else
              TextFieldCard(
                label: '数值',
                controller: _valueText,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            const SizedBox(height: BulterSpacing.l),
            TextFieldCard(
              label: '备注',
              controller: _note,
              maxLines: 4,
              minLines: 2,
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
