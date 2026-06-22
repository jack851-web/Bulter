import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';

import '../db/app_database.dart';
import 'csv_models.dart';
import 'csv_validator.dart';

/// CSV 导入执行器（Step 12）。
///
/// **职责**：
/// - 接收校验通过的 [CsvRow] 列表
/// - 按 [CsvModule] 调对应 DAO 的 insert 方法
/// - 返回 [CsvImportReport]（成功数 / 失败数 / 错误列表）
///
/// **降级策略**：
/// - 单行失败不阻塞其他行（错误聚合到 report）
/// - 网络 / DB 异常 → 包成 [CsvRowError] 返回
class CsvImporter {
  CsvImporter._();

  /// 执行批量导入。
  static Future<CsvImportReport> importBatch({
    required CsvModule module,
    required List<CsvRow> rows,
    required List<CsvFieldMapping> mapping,
  }) async {
    final stopwatch = Stopwatch()..start();
    int success = 0;
    int skipped = 0;
    final errors = <CsvRowError>[];
    final db = AppDatabase.I;

    for (final row in rows) {
      try {
        final mappingWithModule = Map<String, CsvField?>.fromEntries(
          mapping.map((m) => MapEntry(m.columnName, m.field)),
        );
        final mapped = CsvRow(
          raw: row.raw,
          sourceLine: row.sourceLine,
          mapping: mappingWithModule,
        );
        switch (module) {
          case CsvModule.wealth:
            await _importWealthRow(db, mapped);
            break;
          case CsvModule.growth:
            await _importGrowthRow(db, mapped);
            break;
          case CsvModule.thought:
            await _importThoughtRow(db, mapped);
            break;
          case CsvModule.health:
            await _importHealthRow(db, mapped);
            break;
          case CsvModule.unknown:
            errors.add(CsvRowError(row.sourceLine, '未知模块'));
            continue;
        }
        success++;
      } catch (e) {
        debugPrint('CsvImporter: 第 ${row.sourceLine} 行失败 - $e');
        errors.add(CsvRowError(row.sourceLine, e.toString().split('\n').first));
      }
    }

    stopwatch.stop();
    return CsvImportReport(
      module: module,
      totalRows: rows.length,
      successCount: success,
      skippedCount: skipped,
      errors: errors,
      elapsed: stopwatch.elapsed,
    );
  }

  // —— 财富 ——
  static Future<void> _importWealthRow(AppDatabase db, CsvRow row) async {
    final dateStr = row.must(CsvField.date);
    final amountStr = row.must(CsvField.amount);
    final typeStr = row.get(CsvField.type);
    final category = row.get(CsvField.category) ?? '其他';
    final note = row.get(CsvField.note);
    final counterparty = row.get(CsvField.counterparty);

    final dt = CsvValidator.parseDate(dateStr);
    if (dt == null) throw '日期无法解析: "$dateStr"';

    final amount = CsvValidator.parseAmount(amountStr);
    if (amount == null) throw '金额无法解析: "$amountStr"';

    final type = _parseWealthType(typeStr, amount);
    final amountCents = (amount.abs() * 100).round();
    final signedAmount = type == 'income' ? amountCents : -amountCents;

    // 默认账户：取第一个现金账户；如果没有则创建一个
    final accountId = await _ensureDefaultAccount(db);

    final desc = [counterparty, note].whereType<String>().join(' / ');

    await db.wealthDao.insertTransaction(
      TransactionsCompanion.insert(
        accountId: accountId,
        amountCents: signedAmount,
        type: type,
        category: category,
        occurredAt: dt,
        description: Value(desc.isEmpty ? null : desc),
      ),
    );
  }

  // —— 成长 ——
  static Future<void> _importGrowthRow(AppDatabase db, CsvRow row) async {
    final title = row.must(CsvField.title);
    final dateStr = row.get(CsvField.date);
    final note = row.get(CsvField.note);
    final author = row.get(CsvField.author);
    final resourceType = row.get(CsvField.resourceType) ?? 'article';
    final ratingStr = row.get(CsvField.rating);

    final dt = dateStr != null ? CsvValidator.parseDate(dateStr) : null;
    final ratingInt = ratingStr != null
        ? int.tryParse(ratingStr.split('.').first)
        : null;

    await db.growthDao.insertLearning(
      LearningRecordsCompanion.insert(
        title: title,
        source: resourceType,
        author: Value(author),
        startedAt: Value(dt),
        rating: Value(ratingInt),
        notes: Value(note),
      ),
    );
  }

  // —— 思想 ——
  static Future<void> _importThoughtRow(AppDatabase db, CsvRow row) async {
    final title = row.must(CsvField.title);
    final author = row.get(CsvField.author);
    final dateStr = row.get(CsvField.date);
    final content = row.get(CsvField.content) ?? '';

    final dt = dateStr != null
        ? (CsvValidator.parseDate(dateStr) ?? DateTime.now())
        : DateTime.now();

    // Thoughts 表没有 title / author / rating 字段——合成 content + sourceRef
    final sourceRef = author != null && author.isNotEmpty
        ? '《$title》/ $author'
        : title;
    final finalContent = content.isNotEmpty ? content : '[读后感] $title';

    await db.thoughtDao.insertThought(
      ThoughtsCompanion.insert(
        content: finalContent,
        source: 'book',
        sourceRef: Value(sourceRef),
        recordedAt: dt,
      ),
    );
  }

  // —— 健康 ——
  static Future<void> _importHealthRow(AppDatabase db, CsvRow row) async {
    final name = row.must(CsvField.metricName);
    final valueStr = row.must(CsvField.metricValue);
    final unit = row.get(CsvField.metricUnit);
    final dateStr = row.get(CsvField.date);
    final note = row.get(CsvField.note);

    final dt = dateStr != null
        ? (CsvValidator.parseDate(dateStr) ?? DateTime.now())
        : DateTime.now();
    final value = CsvValidator.parseAmount(valueStr);
    if (value == null) throw '指标值无法解析: "$valueStr"';

    await db.healthDao.insertRecord(
      HealthRecordsCompanion.insert(
        type: name,
        valueText: Value(valueStr),
        valueNum: Value(value),
        unit: Value(unit),
        occurredAt: dt,
        notes: Value(note),
      ),
    );
  }

  // —— helpers ——
  static Future<int> _ensureDefaultAccount(AppDatabase db) async {
    final existing = await db.wealthDao.firstAccount();
    if (existing != null) return existing.id;
    final id = await db.wealthDao.insertAccount(
      AccountsCompanion.insert(
        name: '现金',
        type: 'cash',
        balanceCents: const Value(0),
      ),
    );
    return id;
  }

  static String _parseWealthType(String? raw, double amount) {
    if (raw == null || raw.isEmpty) {
      return amount >= 0 ? 'income' : 'expense';
    }
    final s = raw.trim().toLowerCase();
    if (s.contains('收') || s.contains('入') || s == '+' || s == 'income') {
      return 'income';
    }
    if (s.contains('支') || s.contains('出') || s == '-' || s == 'expense') {
      return 'expense';
    }
    if (s.contains('转') || s == 'transfer') {
      return 'transfer';
    }
    // 兜底：金额正负决定
    return amount >= 0 ? 'income' : 'expense';
  }
}
