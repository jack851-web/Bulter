import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:bulter/db/app_database.dart';

import '../../theme/tokens.dart';
import '../form/amount_input.dart';
import '../form/choice_chips_field.dart';
import '../form/date_picker_field.dart';
import '../form/text_field_card.dart';

/// 收支记录新增表单。
class TransactionForm extends StatefulWidget {
  final int? defaultAccountId;
  final Transaction? initial;
  final String title;
  final void Function(TransactionsCompanion data) onSubmit;

  const TransactionForm({
    super.key,
    required this.title,
    required this.onSubmit,
    this.defaultAccountId,
    this.initial,
  });

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final _desc = TextEditingController();
  int? _accountId;
  String _type = 'expense';
  String _category = 'food';
  int? _amountCents;
  DateTime _when = DateTime.now();
  String? _amountError;

  static const _types = ['expense', 'income', 'transfer'];
  static const _typeLabels = {
    'expense': '支出',
    'income': '收入',
    'transfer': '转账',
  };

  static const _categories = {
    'expense': ['food', 'transport', 'shopping', 'housing', 'medical', 'edu', 'entertain', 'other'],
    'income': ['salary', 'bonus', 'investment', 'gift', 'other'],
  };
  static const _catLabels = {
    'food': '餐饮',
    'transport': '交通',
    'shopping': '购物',
    'housing': '住房',
    'medical': '医疗',
    'edu': '学习',
    'entertain': '娱乐',
    'other': '其他',
    'salary': '工资',
    'bonus': '奖金',
    'investment': '投资',
    'gift': '礼金',
  };

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    if (t != null) {
      _accountId = t.accountId;
      _type = t.type;
      _category = t.category;
      _amountCents = t.amountCents.abs();
      _when = t.occurredAt;
      _desc.text = t.description ?? '';
    } else {
      _accountId = widget.defaultAccountId;
    }
  }

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  void _submit() {
    if (_accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在账户页创建一个账户')),
      );
      return;
    }
    if (_amountCents == null || _amountCents! <= 0) {
      setState(() => _amountError = '请填写金额');
      return;
    }
    final sign = _type == 'expense' ? -1 : 1;
    final data = TransactionsCompanion(
      id: widget.initial == null
          ? const Value.absent()
          : Value(widget.initial!.id),
      accountId: Value(_accountId!),
      amountCents: Value(_amountCents! * sign),
      type: Value(_type),
      category: Value(_category),
      occurredAt: Value(_when),
      description:
          Value(_desc.text.trim().isEmpty ? null : _desc.text.trim()),
    );
    widget.onSubmit(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BulterColors.canvas,
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: StreamBuilder<List<Account>>(
          stream: AppDatabase.I.wealthDao.watchAccounts(),
          builder: (context, snap) {
            final accounts = snap.data ?? const <Account>[];
            if (accounts.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(BulterSpacing.xxl),
                  child: Text(
                    '请先在"账户"页创建一个账户，再来记一笔',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: BulterFontSize.body,
                      color: BulterColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                ),
              );
            }
            _accountId ??= accounts.first.id;
            final cats = _categories[_type] ?? _categories['expense']!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                BulterSpacing.l,
                BulterSpacing.l,
                BulterSpacing.l,
                BulterSpacing.huge,
              ),
              children: [
                ChoiceChipsField(
                  label: '类型',
                  value: _type,
                  options: _types,
                  labels: _typeLabels,
                  onChanged: (v) {
                    setState(() {
                      _type = v;
                      final cs = _categories[v] ?? const [];
                      if (!cs.contains(_category)) {
                        _category = cs.isNotEmpty ? cs.first : 'other';
                      }
                    });
                  },
                ),
                const SizedBox(height: BulterSpacing.l),
                _AccountPicker(
                  accounts: accounts,
                  value: _accountId!,
                  onChanged: (v) => setState(() => _accountId = v),
                ),
                const SizedBox(height: BulterSpacing.l),
                AmountInput(
                  label: '金额 *',
                  cents: _amountCents,
                  errorText: _amountError,
                  onChanged: (v) {
                    setState(() {
                      _amountCents = v;
                      if (_amountError != null) _amountError = null;
                    });
                  },
                ),
                const SizedBox(height: BulterSpacing.l),
                ChoiceChipsField(
                  label: '分类',
                  value: _category,
                  options: cats,
                  labels: _catLabels,
                  onChanged: (v) => setState(() => _category = v),
                ),
                const SizedBox(height: BulterSpacing.l),
                DatePickerField(
                  label: '发生日期',
                  value: _when,
                  onChanged: (v) => setState(() => _when = v ?? DateTime.now()),
                ),
                const SizedBox(height: BulterSpacing.l),
                TextFieldCard(
                  label: '备注',
                  controller: _desc,
                  maxLines: 3,
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
            );
          },
        ),
      ),
    );
  }
}

class _AccountPicker extends StatelessWidget {
  final List<Account> accounts;
  final int value;
  final ValueChanged<int> onChanged;
  const _AccountPicker({
    required this.accounts,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '账户',
          style: TextStyle(
            fontSize: BulterFontSize.footnote,
            fontWeight: BulterFontWeight.semibold,
            color: BulterColors.textSecondary,
          ),
        ),
        const SizedBox(height: BulterSpacing.s),
        Wrap(
          spacing: BulterSpacing.s,
          runSpacing: BulterSpacing.s,
          children: [
            for (final a in accounts)
              InkWell(
                borderRadius: BorderRadius.circular(BulterRadius.pill),
                onTap: () => onChanged(a.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: BulterSpacing.l,
                    vertical: BulterSpacing.s + 2,
                  ),
                  decoration: BoxDecoration(
                    color: value == a.id
                        ? BulterColors.cta
                        : BulterColors.surface,
                    borderRadius: BorderRadius.circular(BulterRadius.pill),
                    border: Border.all(
                      color: value == a.id
                          ? BulterColors.cta
                          : BulterColors.divider,
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    a.name,
                    style: TextStyle(
                      color: value == a.id
                          ? BulterColors.ctaText
                          : BulterColors.textPrimary,
                      fontSize: BulterFontSize.body,
                      fontWeight: value == a.id
                          ? BulterFontWeight.semibold
                          : BulterFontWeight.medium,
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
