import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db/app_database.dart';

/// 全量数据导出 / 导入（JSON）。
///
/// **兜底用途**：在 Drift 自动备份之外的"用户手动备份"通道。Step 2 阶段实现
/// 全部业务表的导出 / 导入；后续步骤如新增表，必须同步更新 [dumpTable] /
/// [loadTable] 列表。
class DataExportService {
  final AppDatabase db;
  DataExportService(this.db);

  /// 全部业务表（Drift Table 类名 → 实际 SQL 表名）。
  /// Drift 会把驼峰类名转成 snake_case 复数表名（如 `LearningRecords` → `learning_records`）。
  /// 导出文件里仍用 Drift 类名作为 key，保证跨版本可读；写入 SQL 时再换为实际表名。
  static const Map<String, String> _tableNames = {
    'Contacts': 'contacts',
    'Interactions': 'interactions',
    'Favors': 'favors',
    'Goals': 'goals',
    'Okrs': 'okrs',
    'LearningRecords': 'learning_records',
    'Projects': 'projects',
    'Accounts': 'accounts',
    'Transactions': 'transactions',
    'Budgets': 'budgets',
    'Thoughts': 'thoughts',
    'Letters': 'letters',
    'AnnualReviews': 'annual_reviews',
    'HealthRecords': 'health_records',
    'CheckupReports': 'checkup_reports',
    'HealthScores': 'health_scores',
    'Sessions': 'sessions',
    'Messages': 'messages',
    'Briefings': 'briefings',
    'Memories': 'memories',
    'UserProfiles': 'user_profiles',
    'DemoItems': 'demo_items',
  };

  static List<String> get _tableOrder => _tableNames.keys.toList();

  /// 导出到 [targetPath]（绝对路径），返回文件大小（bytes）。
  Future<int> exportTo(String targetPath) async {
    final dump = <String, dynamic>{
      'app': 'Bulter',
      'schemaVersion': db.schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': <String, List<Map<String, dynamic>>>{},
    };

    for (final table in _tableOrder) {
      dump['tables'][table] = await _dumpTable(table);
    }

    final file = File(targetPath);
    await file.parent.create(recursive: true);
    final json = const JsonEncoder.withIndent('  ').convert(dump);
    await file.writeAsString(json);
    return file.lengthSync();
  }

  /// 导出到默认位置 `<documents>/导出/bulter-{timestamp}.json`。
  Future<String> exportToDefault() async {
    final docs = await getApplicationDocumentsDirectory();
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    final path = p.join(docs.path, '导出', 'bulter_$ts.json');
    await exportTo(path);
    return path;
  }

  /// 从 [sourcePath] 导入。会清空对应表后批量插入，**当前数据会丢失**。
  Future<int> importFrom(String sourcePath) async {
    final file = File(sourcePath);
    if (!file.existsSync()) {
      throw FileSystemException('导入文件不存在', sourcePath);
    }
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final tables = (json['tables'] as Map?) ?? const {};

    var totalRows = 0;
    await db.transaction(() async {
      // 按 _tableOrder 反序删除（先清空带外键的子表）
      for (final className in _tableOrder.reversed) {
        final sqlName = _tableNames[className] ?? className;
        await db.customStatement('DELETE FROM $sqlName');
      }
      for (final className in _tableOrder) {
        final rows = (tables[className] as List?) ?? const [];
        if (rows.isEmpty) continue;
        totalRows += await _loadTable(
          className,
          rows.cast<Map<String, dynamic>>(),
        );
      }
    });
    return totalRows;
  }

  Future<List<Map<String, dynamic>>> _dumpTable(String className) async {
    final sqlName = _tableNames[className] ?? className;
    final rows = await db.customSelect('SELECT * FROM $sqlName').get();
    return rows.map((r) => r.data).toList(growable: false);
  }

  Future<int> _loadTable(
    String className,
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return 0;
    final sqlName = _tableNames[className] ?? className;
    final placeholders = List.filled(rows.first.keys.length, '?').join(', ');
    final columns = rows.first.keys.toList();
    final stmt =
        'INSERT INTO $sqlName (${columns.join(', ')}) VALUES ($placeholders)';
    for (final row in rows) {
      final variables = columns.map((c) {
        final v = row[c];
        if (v == null) return const Variable(null);
        if (v is int) return Variable.withInt(v);
        if (v is double) return Variable.withReal(v);
        if (v is BigInt) return Variable.withBigInt(v);
        if (v is bool) return Variable.withBool(v);
        if (v is DateTime) return Variable.withDateTime(v);
        return Variable.withString(v.toString());
      }).toList();
      await db.customInsert(stmt, variables: variables);
    }
    return rows.length;
  }
}
