import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:bulter/db/app_database.dart';

import '../../theme/tokens.dart';
import '../form/amount_input.dart';
import '../form/choice_chips_field.dart';
import '../form/text_field_card.dart';

/// 账户新增表单。
class AccountForm extends StatefulWidget {
  final Account? initial;
  final String title;
  final void Function(AccountsCompanion data) onSubmit;

  const AccountForm({
    super.key,
    required this.title,
    required this.onSubmit,
    this.initial,
  });

  @override
  State<AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<AccountForm> {
  final _name = TextEditingController();
  final _notes = TextEditingController();
  String _type = 'cash';
  int _balanceCents = 0;
  String _currency = 'CNY';
  String? _nameError;

  static const _types = ['cash', 'bank', 'credit', 'investment', 'other'];
  static const _typeLabels = {
    'cash': '现金',
    'bank': '银行卡',
    'credit': '信用卡',
    'investment': '投资',
    'other': '其他',
  };

  static const _currencies = ['CNY', 'USD', 'EUR', 'JPY'];
  static const _currencyLabels = {
    'CNY': '人民币 ¥',
    'USD': '美元 \$',
    'EUR': '欧元 €',
    'JPY': '日元 ¥',
  };

  @override
  void initState() {
    super.initState();
    final a = widget.initial;
    if (a != null) {
      _name.text = a.name;
      _notes.text = a.notes ?? '';
      _type = a.type;
      _balanceCents = a.balanceCents;
      _currency = a.currency;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    final n = _name.text.trim();
    if (n.isEmpty) {
      setState(() => _nameError = '请输入账户名');
      return;
    }
    final data = AccountsCompanion(
      id: widget.initial == null
          ? const Value.absent()
          : Value(widget.initial!.id),
      name: Value(n),
      type: Value(_type),
      balanceCents: Value(_balanceCents),
      currency: Value(_currency),
      notes: Value(_notes.text.trim().isEmpty ? null : _notes.text.trim()),
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
              label: '账户名 *',
              controller: _name,
              hint: '如：招商银行卡 / 微信零钱',
              autofocus: widget.initial == null,
              errorText: _nameError,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
            const SizedBox(height: BulterSpacing.l),
            ChoiceChipsField(
              label: '类型',
              value: _type,
              options: _types,
              labels: _typeLabels,
              onChanged: (v) => setState(() => _type = v),
            ),
            const SizedBox(height: BulterSpacing.l),
            ChoiceChipsField(
              label: '币种',
              value: _currency,
              options: _currencies,
              labels: _currencyLabels,
              onChanged: (v) => setState(() => _currency = v),
            ),
            const SizedBox(height: BulterSpacing.l),
            AmountInput(
              label: '当前余额',
              cents: _balanceCents,
              currency: _currency,
              onChanged: (v) => setState(() => _balanceCents = v ?? 0),
            ),
            const SizedBox(height: BulterSpacing.l),
            TextFieldCard(
              label: '备注',
              controller: _notes,
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
                  widget.initial == null ? '创建账户' : '更新账户',
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
