import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ai/ai_service.dart';
import '../../components/bulter_scaffold.dart';
import '../../components/svg_icon.dart';
import '../../db/app_database.dart';
import '../../theme/tokens.dart';

/// 用户画像页（Step 7）：查看 / 手动编辑 AI 抽取的画像。
class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  UserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final manager = AiService.rag?.memory;
    if (manager == null) {
      setState(() {
        _loading = false;
        _profile = null;
      });
      return;
    }
    final p = await manager.userProfile.current();
    if (!mounted) return;
    setState(() {
      _profile = p;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_profile == null) return;
    final manager = AiService.rag?.memory;
    if (manager == null) return;
    final p = _profile!;
    await AppDatabase.I.aiDao.upsertProfile(UserProfilesCompanion(
      displayName: Value(p.displayName),
      occupation: Value(p.occupation),
      location: Value(p.location),
      preferencesJson: Value(p.preferencesJson),
      goalsJson: Value(p.goalsJson),
      importantPeopleJson: Value(p.importantPeopleJson),
      updatedAt: Value(DateTime.now()),
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('画像已保存'),
        backgroundColor: BulterColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BulterRadius.m),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BulterScaffold(
      title: '用户画像',
      actions: [
        IconButton(
          icon: const SvgIcon('common/info.svg', size: 20),
          onPressed: _showInfo,
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? const _Unavailable()
              : _ProfileForm(
                  profile: _profile!,
                  onChange: (p) => setState(() => _profile = p),
                  onSave: _save,
                ),
    );
  }

  void _showInfo() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BulterRadius.l),
        ),
        title: const Text('关于用户画像'),
        content: const Text(
          'Bulter 会从对话里自动提取关于你的稳定信息（称呼 / 职业 / 所在地 / 偏好 / 目标 / 重要他人），'
          '并拼成一段话注入给 AI，让 AI 知道你是谁。\n\n'
          '你可以在这里手动修改或补充；修改后会立即影响后续对话。',
          style: TextStyle(
            fontSize: BulterFontSize.body,
            color: BulterColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BulterSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SvgIcon(
              'common/info.svg',
              size: 48,
              color: BulterColors.textTertiary,
            ),
            SizedBox(height: BulterSpacing.l),
            Text(
              '记忆子系统未就绪',
              style: TextStyle(
                fontSize: BulterFontSize.titleS,
                fontWeight: BulterFontWeight.semibold,
                color: BulterColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileForm extends StatefulWidget {
  final UserProfile profile;
  final ValueChanged<UserProfile> onChange;
  final VoidCallback onSave;
  const _ProfileForm({
    required this.profile,
    required this.onChange,
    required this.onSave,
  });

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  late TextEditingController _name;
  late TextEditingController _occupation;
  late TextEditingController _location;
  late List<_KvItem> _preferences;
  late List<_TextItem> _goals;
  late List<_NamedItem> _people;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.displayName ?? '');
    _occupation = TextEditingController(text: widget.profile.occupation ?? '');
    _location = TextEditingController(text: widget.profile.location ?? '');
    _preferences = _decodeKv(widget.profile.preferencesJson);
    _goals = _decodeText(widget.profile.goalsJson);
    _people = _decodeNamed(widget.profile.importantPeopleJson);
  }

  @override
  void dispose() {
    _name.dispose();
    _occupation.dispose();
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(BulterSpacing.l),
      children: [
        _SectionTitle(icon: 'common/user.svg', label: '基础信息'),
        const SizedBox(height: BulterSpacing.s),
        _FieldCard(
          label: '称呼',
          hint: 'Bulter 怎么叫你',
          child: TextField(
            controller: _name,
            decoration: const InputDecoration(hintText: '如：小明'),
            onChanged: (v) => _sync(),
          ),
        ),
        const SizedBox(height: BulterSpacing.s),
        _FieldCard(
          label: '职业',
          hint: 'AI 会用它调整沟通语气',
          child: TextField(
            controller: _occupation,
            decoration: const InputDecoration(hintText: '如：产品经理'),
            onChanged: (v) => _sync(),
          ),
        ),
        const SizedBox(height: BulterSpacing.s),
        _FieldCard(
          label: '所在地',
          child: TextField(
            controller: _location,
            decoration: const InputDecoration(hintText: '如：上海'),
            onChanged: (v) => _sync(),
          ),
        ),
        const SizedBox(height: BulterSpacing.l),
        _SectionTitle(icon: 'common/heart.svg', label: '偏好'),
        const SizedBox(height: BulterSpacing.s),
        _KvListEditor(
          items: _preferences,
          onChange: (items) {
            setState(() => _preferences = items);
            _sync();
          },
          keyHint: '类别',
          valueHint: '内容',
        ),
        const SizedBox(height: BulterSpacing.l),
        _SectionTitle(icon: 'common/star.svg', label: '目标'),
        const SizedBox(height: BulterSpacing.s),
        _TextListEditor(
          items: _goals,
          onChange: (items) {
            setState(() => _goals = items);
            _sync();
          },
          hint: '如：半年内跑完一场马拉松',
        ),
        const SizedBox(height: BulterSpacing.l),
        _SectionTitle(icon: 'common/people.svg', label: '重要他人'),
        const SizedBox(height: BulterSpacing.s),
        _NamedListEditor(
          items: _people,
          onChange: (items) {
            setState(() => _people = items);
            _sync();
          },
        ),
        const SizedBox(height: BulterSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: widget.onSave,
            style: FilledButton.styleFrom(
              backgroundColor: BulterColors.textPrimary,
              foregroundColor: BulterColors.surface,
              padding: const EdgeInsets.symmetric(vertical: BulterSpacing.m),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(BulterRadius.m),
              ),
            ),
            child: const Text('保存'),
          ),
        ),
        const SizedBox(height: BulterSpacing.l),
        TextButton(
          onPressed: () {
            GoRouter.of(context).pushNamed('memory');
          },
          child: const Text('查看长期记忆'),
        ),
      ],
    );
  }

  void _sync() {
    widget.onChange(UserProfile(
      id: widget.profile.id,
      displayName: _name.text.trim().isEmpty ? null : _name.text.trim(),
      occupation: _occupation.text.trim().isEmpty ? null : _occupation.text.trim(),
      location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      preferencesJson: jsonEncode(
        _preferences
            .map((e) => {'key': e.key, 'value': e.value})
            .toList(),
      ),
      goalsJson: jsonEncode(
        _goals.map((e) => {'text': e.text}).toList(),
      ),
      importantPeopleJson: jsonEncode(
        _people
            .map((e) => {'name': e.name, 'relation': e.relation})
            .toList(),
      ),
      updatedAt: widget.profile.updatedAt,
    ));
  }
}

class _FieldCard extends StatelessWidget {
  final String label;
  final String? hint;
  final Widget child;
  const _FieldCard({required this.label, this.hint, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BulterSpacing.m),
      decoration: BoxDecoration(
        color: BulterColors.surface,
        borderRadius: BorderRadius.circular(BulterRadius.m),
        border: Border.all(color: BulterColors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: BulterFontSize.body,
              fontWeight: BulterFontWeight.semibold,
              color: BulterColors.textPrimary,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint!,
              style: const TextStyle(
                fontSize: BulterFontSize.footnote,
                color: BulterColors.textTertiary,
              ),
            ),
          ],
          const SizedBox(height: BulterSpacing.s),
          child,
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String icon;
  final String label;
  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SvgIcon(icon, size: 14, color: BulterColors.textSecondary),
        const SizedBox(width: BulterSpacing.s),
        Text(
          label,
          style: const TextStyle(
            fontSize: BulterFontSize.body,
            fontWeight: BulterFontWeight.semibold,
            color: BulterColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// —— 列表编辑器 —— //

class _KvItem {
  String key;
  String value;
  _KvItem(this.key, this.value);
}

class _KvListEditor extends StatelessWidget {
  final List<_KvItem> items;
  final ValueChanged<List<_KvItem>> onChange;
  final String keyHint;
  final String valueHint;
  const _KvListEditor({
    required this.items,
    required this.onChange,
    required this.keyHint,
    required this.valueHint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          _kvRow(i),
        const SizedBox(height: BulterSpacing.s),
        TextButton.icon(
          onPressed: () {
            items.add(_KvItem('', ''));
            onChange(List.from(items));
          },
          icon: const SvgIcon('common/plus.svg', size: 14),
          label: const Text('添加偏好'),
        ),
      ],
    );
  }

  Widget _kvRow(int i) {
    return Container(
      margin: const EdgeInsets.only(bottom: BulterSpacing.s),
      padding: const EdgeInsets.all(BulterSpacing.s),
      decoration: BoxDecoration(
        color: BulterColors.surface,
        borderRadius: BorderRadius.circular(BulterRadius.s),
        border: Border.all(color: BulterColors.divider, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(hintText: keyHint, isDense: true),
              onChanged: (v) => items[i].key = v,
            ),
          ),
          const SizedBox(width: BulterSpacing.s),
          Expanded(
            flex: 2,
            child: TextField(
              decoration: InputDecoration(hintText: valueHint, isDense: true),
              onChanged: (v) => items[i].value = v,
            ),
          ),
          IconButton(
            icon: const SvgIcon('common/close.svg', size: 14),
            onPressed: () {
              items.removeAt(i);
              onChange(List.from(items));
            },
          ),
        ],
      ),
    );
  }
}

class _TextItem {
  String text;
  _TextItem(this.text);
}

class _TextListEditor extends StatelessWidget {
  final List<_TextItem> items;
  final ValueChanged<List<_TextItem>> onChange;
  final String hint;
  const _TextListEditor({
    required this.items,
    required this.onChange,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) _row(i),
        const SizedBox(height: BulterSpacing.s),
        TextButton.icon(
          onPressed: () {
            items.add(_TextItem(''));
            onChange(List.from(items));
          },
          icon: const SvgIcon('common/plus.svg', size: 14),
          label: const Text('添加目标'),
        ),
      ],
    );
  }

  Widget _row(int i) {
    return Container(
      margin: const EdgeInsets.only(bottom: BulterSpacing.s),
      padding: const EdgeInsets.all(BulterSpacing.s),
      decoration: BoxDecoration(
        color: BulterColors.surface,
        borderRadius: BorderRadius.circular(BulterRadius.s),
        border: Border.all(color: BulterColors.divider, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(hintText: hint, isDense: true),
              onChanged: (v) => items[i].text = v,
            ),
          ),
          IconButton(
            icon: const SvgIcon('common/close.svg', size: 14),
            onPressed: () {
              items.removeAt(i);
              onChange(List.from(items));
            },
          ),
        ],
      ),
    );
  }
}

class _NamedItem {
  String name;
  String relation;
  _NamedItem(this.name, this.relation);
}

class _NamedListEditor extends StatelessWidget {
  final List<_NamedItem> items;
  final ValueChanged<List<_NamedItem>> onChange;
  const _NamedListEditor({required this.items, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) _row(i),
        const SizedBox(height: BulterSpacing.s),
        TextButton.icon(
          onPressed: () {
            items.add(_NamedItem('', ''));
            onChange(List.from(items));
          },
          icon: const SvgIcon('common/plus.svg', size: 14),
          label: const Text('添加'),
        ),
      ],
    );
  }

  Widget _row(int i) {
    return Container(
      margin: const EdgeInsets.only(bottom: BulterSpacing.s),
      padding: const EdgeInsets.all(BulterSpacing.s),
      decoration: BoxDecoration(
        color: BulterColors.surface,
        borderRadius: BorderRadius.circular(BulterRadius.s),
        border: Border.all(color: BulterColors.divider, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration:
                  const InputDecoration(hintText: '姓名', isDense: true),
              onChanged: (v) => items[i].name = v,
            ),
          ),
          const SizedBox(width: BulterSpacing.s),
          Expanded(
            child: TextField(
              decoration:
                  const InputDecoration(hintText: '关系', isDense: true),
              onChanged: (v) => items[i].relation = v,
            ),
          ),
          IconButton(
            icon: const SvgIcon('common/close.svg', size: 14),
            onPressed: () {
              items.removeAt(i);
              onChange(List.from(items));
            },
          ),
        ],
      ),
    );
  }
}

// —— JSON 解码 —— //

List<_KvItem> _decodeKv(String json) {
  try {
    final list = jsonDecode(json) as List;
    return list
        .whereType<Map>()
        .map((e) => _KvItem(
              e['key']?.toString() ?? '',
              e['value']?.toString() ?? '',
            ))
        .toList();
  } catch (_) {
    return [];
  }
}

List<_TextItem> _decodeText(String json) {
  try {
    final list = jsonDecode(json) as List;
    return list
        .whereType<Map>()
        .map((e) => _TextItem(e['text']?.toString() ?? ''))
        .toList();
  } catch (_) {
    return [];
  }
}

List<_NamedItem> _decodeNamed(String json) {
  try {
    final list = jsonDecode(json) as List;
    return list
        .whereType<Map>()
        .map((e) => _NamedItem(
              e['name']?.toString() ?? '',
              e['relation']?.toString() ?? '',
            ))
        .toList();
  } catch (_) {
    return [];
  }
}
