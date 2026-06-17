import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:bulter/db/app_database.dart';

import '../../theme/tokens.dart';
import '../form/choice_chips_field.dart';
import '../form/date_picker_field.dart';
import '../form/misc_inputs.dart';
import '../form/text_field_card.dart';

/// 目标新增/编辑表单。
class GoalForm extends StatefulWidget {
  final Goal? initial;
  final String title;
  final void Function(GoalsCompanion data) onSubmit;

  const GoalForm({
    super.key,
    required this.title,
    required this.onSubmit,
    this.initial,
  });

  @override
  State<GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<GoalForm> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String _category = 'career';
  String _status = 'active';
  DateTime? _targetDate;
  int _progress = 0;
  String? _titleError;

  static const _cats = ['career', 'skill', 'health', 'relationship', 'finance', 'other'];
  static const _catLabels = {
    'career': '事业',
    'skill': '技能',
    'health': '健康',
    'relationship': '关系',
    'finance': '财务',
    'other': '其他',
  };

  @override
  void initState() {
    super.initState();
    final g = widget.initial;
    if (g != null) {
      _title.text = g.title;
      _desc.text = g.description ?? '';
      _category = g.category;
      _status = g.status;
      _targetDate = g.targetDate;
      _progress = g.progress;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _title.text.trim();
    if (t.isEmpty) {
      setState(() => _titleError = '请输入目标');
      return;
    }
    final data = GoalsCompanion(
      id: widget.initial == null
          ? const Value.absent()
          : Value(widget.initial!.id),
      title: Value(t),
      description:
          Value(_desc.text.trim().isEmpty ? null : _desc.text.trim()),
      category: Value(_category),
      status: Value(_status),
      targetDate: Value(_targetDate),
      progress: Value(_progress),
      updatedAt: Value(DateTime.now()),
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
            TextFieldCard(
              label: '目标 *',
              controller: _title,
              hint: '如：年内完成第一本书',
              autofocus: widget.initial == null,
              errorText: _titleError,
              onChanged: (_) {
                if (_titleError != null) setState(() => _titleError = null);
              },
            ),
            const SizedBox(height: BulterSpacing.l),
            TextFieldCard(
              label: '描述',
              controller: _desc,
              hint: '为什么重要？要做到什么程度？',
              maxLines: 4,
              minLines: 2,
            ),
            const SizedBox(height: BulterSpacing.l),
            ChoiceChipsField(
              label: '分类',
              value: _category,
              options: _cats,
              labels: _catLabels,
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: BulterSpacing.l),
            if (widget.initial != null)
              ChoiceChipsField(
                label: '状态',
                value: _status,
                options: const ['active', 'completed', 'abandoned'],
                labels: const {
                  'active': '进行中',
                  'completed': '已完成',
                  'abandoned': '已搁置',
                },
                onChanged: (v) => setState(() => _status = v),
              ),
            if (widget.initial != null) const SizedBox(height: BulterSpacing.l),
            DatePickerField(
              label: '目标日期',
              value: _targetDate,
              onChanged: (v) => setState(() => _targetDate = v),
              hint: '点击选择',
            ),
            const SizedBox(height: BulterSpacing.l),
            ProgressSliderField(
              label: '当前进度',
              value: _progress,
              onChanged: (v) => setState(() => _progress = v),
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
                  widget.initial == null ? '创建目标' : '更新目标',
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
