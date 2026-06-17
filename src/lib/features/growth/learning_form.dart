import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:bulter/db/app_database.dart';

import '../../theme/tokens.dart';
import '../form/choice_chips_field.dart';
import '../form/date_picker_field.dart';
import '../form/misc_inputs.dart';
import '../form/text_field_card.dart';

/// 学习记录新增/编辑表单。
class LearningForm extends StatefulWidget {
  final LearningRecord? initial;
  final String title;
  final void Function(LearningRecordsCompanion data) onSubmit;

  const LearningForm({
    super.key,
    required this.title,
    required this.onSubmit,
    this.initial,
  });

  @override
  State<LearningForm> createState() => _LearningFormState();
}

class _LearningFormState extends State<LearningForm> {
  final _title = TextEditingController();
  final _author = TextEditingController();
  final _notes = TextEditingController();
  String _source = 'book';
  DateTime? _startedAt;
  DateTime? _finishedAt;
  int? _rating;
  String? _titleError;

  static const _sources = ['book', 'course', 'article', 'video', 'podcast'];
  static const _sourceLabels = {
    'book': '书',
    'course': '课程',
    'article': '文章',
    'video': '视频',
    'podcast': '播客',
  };

  @override
  void initState() {
    super.initState();
    final l = widget.initial;
    if (l != null) {
      _title.text = l.title;
      _author.text = l.author ?? '';
      _notes.text = l.notes ?? '';
      _source = l.source;
      _startedAt = l.startedAt;
      _finishedAt = l.finishedAt;
      _rating = l.rating;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _title.text.trim();
    if (t.isEmpty) {
      setState(() => _titleError = '请填写标题');
      return;
    }
    final data = LearningRecordsCompanion(
      id: widget.initial == null
          ? const Value.absent()
          : Value(widget.initial!.id),
      title: Value(t),
      source: Value(_source),
      author: Value(_author.text.trim().isEmpty ? null : _author.text.trim()),
      startedAt: Value(_startedAt),
      finishedAt: Value(_finishedAt),
      rating: Value(_rating),
      notes: Value(_notes.text.trim().isEmpty ? null : _notes.text.trim()),
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
              label: '标题 *',
              controller: _title,
              autofocus: widget.initial == null,
              errorText: _titleError,
              onChanged: (_) {
                if (_titleError != null) setState(() => _titleError = null);
              },
            ),
            const SizedBox(height: BulterSpacing.l),
            TextFieldCard(
              label: '作者 / 主讲',
              controller: _author,
            ),
            const SizedBox(height: BulterSpacing.l),
            ChoiceChipsField(
              label: '来源',
              value: _source,
              options: _sources,
              labels: _sourceLabels,
              onChanged: (v) => setState(() => _source = v),
            ),
            const SizedBox(height: BulterSpacing.l),
            DatePickerField(
              label: '开始日期',
              value: _startedAt,
              onChanged: (v) => setState(() => _startedAt = v),
            ),
            const SizedBox(height: BulterSpacing.l),
            DatePickerField(
              label: '完成日期',
              value: _finishedAt,
              onChanged: (v) => setState(() => _finishedAt = v),
            ),
            const SizedBox(height: BulterSpacing.l),
            ProgressSliderField(
              label: '我的评分',
              value: _rating ?? 0,
              min: 0,
              max: 5,
              formatter: (v) => '$v / 5',
              onChanged: (v) =>
                  setState(() => _rating = v == 0 ? null : v),
            ),
            const SizedBox(height: BulterSpacing.l),
            TextFieldCard(
              label: '笔记 / 感想',
              controller: _notes,
              maxLines: 6,
              minLines: 3,
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
