import 'package:drift/drift.dart';

import '../../../db/app_database.dart';
import '../../../modules/bulter_module.dart';
import '../../../modules/wealth/db/wealth_daos.dart';
import 'tool_registry.dart';

/// 财富模块 — 账户 / 交易 / 预算 的只读 + 写工具。
class WealthTools {
  WealthTools._();

  static const String queryAccounts = 'query_accounts';
  static const String queryTransactions = 'query_transactions';
  static const String querySpending = 'query_spending';
  static const String saveTransaction = 'save_transaction';
  static const String saveAccount = 'save_account';
  static const String deleteTransaction = 'delete_transaction';

  static const ToolDefinition queryAccountsDef = ToolDefinition(
    name: queryAccounts,
    description: '查询所有账户（现金 / 银行 / 信用卡 / 投资）。',
    category: ToolCategory.read,
    parameters: {
      'type': 'object',
      'properties': {
        'type': {
          'type': 'string',
          'enum': ['cash', 'bank', 'credit', 'investment', 'other'],
          'description': '按类型筛选（可选）',
        },
      },
    },
  );

  static const ToolDefinition queryTransactionsDef = ToolDefinition(
    name: queryTransactions,
    description: '查询最近的交易记录。可按账户 / 时间过滤。',
    category: ToolCategory.read,
    parameters: {
      'type': 'object',
      'properties': {
        'account_id': {'type': 'integer', 'description': '按账户 ID 过滤（可选）'},
        'limit': {'type': 'integer', 'description': '返回前 N 条，默认 20'},
        'since': {'type': 'string', 'description': '起始时间，ISO 8601（可选）'},
      },
    },
  );

  static const ToolDefinition querySpendingDef = ToolDefinition(
    name: querySpending,
    description: '统计某段时间的支出总额（按分类）。amount 单位：分。',
    category: ToolCategory.read,
    parameters: {
      'type': 'object',
      'properties': {
        'since': {'type': 'string', 'description': '起始时间，ISO 8601。默认本月 1 号'},
        'category': {'type': 'string', 'description': '按分类精确过滤（可选）'},
      },
    },
  );

  static const ToolDefinition saveTransactionDef = ToolDefinition(
    name: saveTransaction,
    description: '记录一笔收入或支出。amount_cents 为正数收入，负数支出。',
    category: ToolCategory.write,
    parameters: {
      'type': 'object',
      'properties': {
        'account_id': {'type': 'integer', 'description': '账户 ID（必填）'},
        'amount_cents': {
          'type': 'integer',
          'description': '金额（单位：分）。收入为正，支出为负（必填）',
        },
        'type': {
          'type': 'string',
          'enum': ['income', 'expense', 'transfer'],
          'description': '交易类型',
        },
        'category': {
          'type': 'string',
          'description': '分类（必填）：餐饮 / 交通 / 工资 ...',
        },
        'occurred_at': {'type': 'string', 'description': '发生时间，ISO 8601。默认当前'},
        'description': {'type': 'string', 'description': '备注'},
      },
      'required': ['account_id', 'amount_cents', 'type', 'category'],
    },
  );

  static const ToolDefinition saveAccountDef = ToolDefinition(
    name: saveAccount,
    description: '新建或更新账户。',
    category: ToolCategory.write,
    parameters: {
      'type': 'object',
      'properties': {
        'id': {'type': 'integer', 'description': '存在则更新，不传则新建'},
        'name': {'type': 'string', 'description': '账户名（必填）'},
        'type': {
          'type': 'string',
          'enum': ['cash', 'bank', 'credit', 'investment', 'other'],
          'description': '账户类型',
        },
        'balance_cents': {'type': 'integer', 'description': '余额（分），默认 0'},
        'currency': {'type': 'string', 'description': '币种，默认 CNY'},
        'notes': {'type': 'string', 'description': '备注'},
      },
      'required': ['name', 'type'],
    },
  );

  static const ToolDefinition deleteTransactionDef = ToolDefinition(
    name: deleteTransaction,
    description: '删除一笔交易。会要求用户二次确认。',
    category: ToolCategory.confirmation,
    parameters: {
      'type': 'object',
      'properties': {
        'id': {'type': 'integer', 'description': '交易 ID（必填）'},
      },
      'required': ['id'],
    },
  );

  static void registerAll(ToolRegistry registry, AppDatabase db) {
    final dao = db.wealthDao;
    registry.register(
      tool: queryAccountsDef,
      executor: (p) => _queryAccounts(dao, p),
    );
    registry.register(
      tool: queryTransactionsDef,
      executor: (p) => _queryTransactions(dao, p),
    );
    registry.register(
      tool: querySpendingDef,
      executor: (p) => _querySpending(dao, p),
    );
    registry.register(
      tool: saveTransactionDef,
      executor: (p) => _saveTransaction(dao, p),
    );
    registry.register(
      tool: saveAccountDef,
      executor: (p) => _saveAccount(dao, p),
    );
    registry.register(
      tool: deleteTransactionDef,
      executor: (p) => _deleteTransaction(dao, p),
    );
  }

  // ===== Executors =====

  static Future<ToolResult> _queryAccounts(
    WealthDao dao,
    Map<String, dynamic> p,
  ) async {
    final list = await dao.watchAccounts().first;
    final type = p['type'] as String?;
    final filtered = type == null
        ? list
        : list.where((a) => a.type == type).toList();
    return ToolResult.ok(
      '共 ${filtered.length} 个账户',
      data: {
        'count': filtered.length,
        'accounts': [
          for (final a in filtered)
            {
              'id': a.id,
              'name': a.name,
              'type': a.type,
              'balance_cents': a.balanceCents,
              'currency': a.currency,
            },
        ],
      },
    );
  }

  static Future<ToolResult> _queryTransactions(
    WealthDao dao,
    Map<String, dynamic> p,
  ) async {
    final limit = (p['limit'] as int?) ?? 20;
    final all = await dao.watchRecentTransactions(limit: limit).first;
    Iterable<Transaction> filtered = all;
    final accountId = p['account_id'] as int?;
    if (accountId != null) {
      filtered = filtered.where((t) => t.accountId == accountId);
    }
    final list = filtered.toList();
    return ToolResult.ok(
      '共 ${list.length} 笔交易',
      data: {
        'count': list.length,
        'transactions': [
          for (final t in list)
            {
              'id': t.id,
              'account_id': t.accountId,
              'amount_cents': t.amountCents,
              'type': t.type,
              'category': t.category,
              'occurred_at': t.occurredAt.toIso8601String(),
              'description': t.description,
            },
        ],
      },
    );
  }

  static Future<ToolResult> _querySpending(
    WealthDao dao,
    Map<String, dynamic> p,
  ) async {
    DateTime since;
    if (p['since'] != null) {
      since = DateTime.tryParse(p['since'] as String) ?? _monthStart();
    } else {
      since = _monthStart();
    }
    final cents = await dao.sumExpenseCents(
      since: since,
      category: p['category'] as String?,
    );
    return ToolResult.ok(
      '支出合计 ¥${(cents / 100).toStringAsFixed(2)}',
      data: {'since': since.toIso8601String(), 'total_cents': cents},
    );
  }

  static DateTime _monthStart() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, 1);
  }

  static Future<ToolResult> _saveTransaction(
    WealthDao dao,
    Map<String, dynamic> p,
  ) async {
    final accountId = p['account_id'] as int?;
    final amount = p['amount_cents'] as int?;
    final type = (p['type'] as String?) ?? 'expense';
    final category = p['category'] as String?;
    if (accountId == null || amount == null || category == null) {
      return ToolResult.error('缺少必填参数 account_id / amount_cents / category');
    }
    final occurred = p['occurred_at'] != null
        ? DateTime.tryParse(p['occurred_at'] as String) ?? DateTime.now()
        : DateTime.now();
    final id = await dao.insertTransaction(
      TransactionsCompanion(
        accountId: Value(accountId),
        amountCents: Value(amount),
        type: Value(type),
        category: Value(category),
        occurredAt: Value(occurred),
        description: Value(p['description'] as String?),
      ),
    );
    return ToolResult.ok(
      '已记一笔${type == "expense" ? "支出" : "收入"} ¥${(amount.abs() / 100).toStringAsFixed(2)}',
      data: {'id': id},
    );
  }

  static Future<ToolResult> _saveAccount(
    WealthDao dao,
    Map<String, dynamic> p,
  ) async {
    final name = p['name'] as String?;
    final type = (p['type'] as String?) ?? 'other';
    if (name == null) return ToolResult.error('缺少必填参数 name');
    final id = p['id'] as int?;
    final balance = (p['balance_cents'] as int?) ?? 0;
    final currency = (p['currency'] as String?) ?? 'CNY';
    if (id == null) {
      final newId = await dao.insertAccount(
        AccountsCompanion(
          name: Value(name),
          type: Value(type),
          balanceCents: Value(balance),
          currency: Value(currency),
          notes: Value(p['notes'] as String?),
        ),
      );
      return ToolResult.ok('已新建账户 $name（id=$newId）', data: {'id': newId});
    } else {
      await dao.updateAccount(
        AccountsCompanion(
          id: Value(id),
          name: Value(name),
          type: Value(type),
          balanceCents: Value(balance),
          currency: Value(currency),
          notes: Value(p['notes'] as String?),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return ToolResult.ok('已更新账户 $name', data: {'id': id});
    }
  }

  static Future<ToolResult> _deleteTransaction(
    WealthDao dao,
    Map<String, dynamic> p,
  ) async {
    final id = p['id'] as int?;
    if (id == null) return ToolResult.error('缺少必填参数 id');
    return ToolResult.confirm(
      '确认删除这笔交易吗？此操作不可恢复。',
      data: {'id': id, 'tool': deleteTransaction},
    );
  }
}
