import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:bulter/db/app_database.dart';

import '../../theme/tokens.dart';
import '../form/choice_chips_field.dart';
import '../form/chips_input.dart' as chips;
import '../form/date_picker_field.dart';
import '../form/integer_input.dart';
import '../form/text_field_card.dart';

/// 想法 / 读后感新增/编辑表单。
class ThoughtForm extends StatefulWidget {
  final Thought? initial;
  final String title;
  final void Function(ThoughtsCompanion data) onSubmit;

  const ThoughtForm({
    super.key,
    required this.title,
    required this.onSubmit,
    this.initial,
  });

  @override
  State<ThoughtForm> createState() => _ThoughtFormState();
}

class _ThoughtFormState extends State<ThoughtForm> {
  final _content = TextEditingController();
  final _sourceRef = TextEditingController();
  String _source = 'book';
  DateTime _when = DateTime.now();
  List<String> _tags = const [];
  int? _mood;
  String? _contentError;

  static const _sources = ['book', 'article', 'movie', 'conversation', 'other'];
  static const _sourceLabels = {
    'book': '书',
    'article': '文章',
    'movie': '电影',
    'conversation': '对话',
    'other': '其他',
  };

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    if (t != null) {
      _content.text = t.content;
      _sourceRef.text = t.sourceRef ?? '';
      _source = t.source;
      _when = t.recordedAt;
      _tags = chips.jsonToTags(t.tagsJson);
      _mood = t.mood;
    }
  }

  @override
  void dispose() {
    _content.dispose();
    _sourceRef.dispose();
    super.dispose();
  }

  void _submit() {
    final c = _content.text.trim();
    if (c.isEmpty) {
      setState(() => _contentError = '写点什么吧');
      return;
    }
    final data = ThoughtsCompanion(
      id: widget.initial == null
          ? const Value.absent()
          : Value(widget.initial!.id),
      content: Value(c),
      source: Value(_source),
      sourceRef: Value(
        _sourceRef.text.trim().isEmpty ? null : _sourceRef.text.trim(),
      ),
      tagsJson: Value(chips.tagsToJson(_tags)),
      mood: Value(_mood),
      recordedAt: Value(_when),
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
              label: '来源',
              value: _source,
              options: _sources,
              labels: _sourceLabels,
              onChanged: (v) => setState(() => _source = v),
            ),
            const SizedBox(height: BulterSpacing.l),
            TextFieldCard(label: '书名 / 文章标题（可选）', controller: _sourceRef),
            const SizedBox(height: BulterSpacing.l),
            TextFieldCard(
              label: '想法 *',
              controller: _content,
              hint: '那段让你停下来、反复想的话',
              maxLines: 8,
              minLines: 4,
              errorText: _contentError,
              onChanged: (_) {
                if (_contentError != null) setState(() => _contentError = null);
              },
            ),
            const SizedBox(height: BulterSpacing.l),
            chips.ChipsInput(
              label: '标签',
              hint: '回车添加',
              initial: _tags,
              onChanged: (v) => _tags = v,
            ),
            const SizedBox(height: BulterSpacing.l),
            IntegerInput(
              label: '心情（1-5，可选）',
              value: _mood,
              min: 1,
              max: 5,
              onChanged: (v) => setState(() => _mood = v),
            ),
            const SizedBox(height: BulterSpacing.l),
            DatePickerField(
              label: '记录日期',
              value: _when,
              onChanged: (v) => setState(() => _when = v ?? DateTime.now()),
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
