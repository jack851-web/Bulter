import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:bulter/db/app_database.dart';

import '../../theme/tokens.dart';
import '../form/choice_chips_field.dart';
import '../form/chips_input.dart' as chips;
import '../form/date_picker_field.dart';
import '../form/integer_input.dart';
import '../form/text_field_card.dart';

/// 联系人新建 / 编辑表单。
///
/// 编辑模式：传入 `initial`；否则为空表单。
/// 提交时通过 [onSubmit] 返回 `(ContactsCompanion, List<String>)`。
class ContactForm extends StatefulWidget {
  final Contact? initial;
  final String title;
  final void Function(ContactsCompanion data) onSubmit;

  const ContactForm({
    super.key,
    required this.title,
    required this.onSubmit,
    this.initial,
  });

  @override
  State<ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<ContactForm> {
  final _name = TextEditingController();
  final _nick = TextEditingController();
  final _notes = TextEditingController();
  String _relType = 'friend';
  List<String> _tags = const [];
  DateTime? _birthday;
  int? _importance;
  String? _nameError;

  static const _relOptions = [
    'friend',
    'family',
    'colleague',
    'mentor',
    'other',
  ];
  static const _relLabels = {
    'friend': '朋友',
    'family': '家人',
    'colleague': '同事',
    'mentor': '师长',
    'other': '其他',
  };

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    if (c != null) {
      _name.text = c.name;
      _nick.text = c.nickname ?? '';
      _notes.text = c.notes ?? '';
      _relType = c.relationshipType;
      _tags = chips.jsonToTags(c.tagsJson);
      _birthday = c.birthday;
      _importance = c.importance;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _nick.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = '请输入姓名');
      return;
    }
    final data = ContactsCompanion(
      id: widget.initial == null
          ? const Value.absent()
          : Value(widget.initial!.id),
      name: Value(name),
      nickname: Value(_nick.text.trim().isEmpty ? null : _nick.text.trim()),
      relationshipType: Value(_relType),
      tagsJson: Value(chips.tagsToJson(_tags)),
      notes: Value(_notes.text.trim().isEmpty ? null : _notes.text.trim()),
      birthday: Value(_birthday),
      importance: Value(_importance ?? 5),
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
              label: '姓名 *',
              controller: _name,
              hint: '如：王老师',
              autofocus: widget.initial == null,
              errorText: _nameError,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
            const SizedBox(height: BulterSpacing.l),
            TextFieldCard(label: '昵称', controller: _nick, hint: '可选'),
            const SizedBox(height: BulterSpacing.l),
            ChoiceChipsField(
              label: '关系类型',
              value: _relType,
              options: _relOptions,
              labels: _relLabels,
              onChanged: (v) => setState(() => _relType = v),
            ),
            const SizedBox(height: BulterSpacing.l),
            DatePickerField(
              label: '生日',
              value: _birthday,
              onChanged: (v) => setState(() => _birthday = v),
              hint: '点击选择',
            ),
            const SizedBox(height: BulterSpacing.l),
            IntegerInput(
              label: '重要度（0-10）',
              value: _importance,
              min: 0,
              max: 10,
              hint: '默认 5',
              onChanged: (v) => setState(() => _importance = v),
            ),
            const SizedBox(height: BulterSpacing.l),
            chips.ChipsInput(
              label: '标签',
              hint: '如：篮球 / 同行 / 小学同学',
              initial: _tags,
              onChanged: (v) => _tags = v,
            ),
            const SizedBox(height: BulterSpacing.l),
            TextFieldCard(
              label: '备注',
              controller: _notes,
              hint: '想记住的细节：性格、关系背景、上次聊到的话题…',
              maxLines: 4,
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
                  widget.initial == null ? '保存联系人' : '更新联系人',
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
