import 'package:drift/drift.dart';

import '../../../db/app_database.dart';
import '../../../modules/bulter_module.dart';
import '../../../modules/health/db/health_daos.dart';
import 'tool_registry.dart';

/// 健康模块 — 记录 / 体检报告 的只读 + 写工具。
class HealthTools {
  HealthTools._();

  static const String queryRecords = 'query_health_records';
  static const String queryReports = 'query_checkup_reports';
  static const String saveRecord = 'save_health_record';
  static const String deleteRecord = 'delete_health_record';

  static const ToolDefinition queryRecordsDef = ToolDefinition(
    name: queryRecords,
    description: '查询健康记录（体重 / 睡眠 / 运动 / 心情 / 症状）。',
    category: ToolCategory.read,
    parameters: {
      'type': 'object',
      'properties': {
        'type': {
          'type': 'string',
          'enum': ['weight', 'sleep', 'exercise', 'symptom', 'mood', 'other'],
          'description': '按类型过滤（可选）',
        },
        'limit': {'type': 'integer', 'description': '返回前 N 条，默认 20'},
      },
    },
  );

  static const ToolDefinition queryReportsDef = ToolDefinition(
    name: queryReports,
    description: '查询体检报告。',
    category: ToolCategory.read,
    parameters: {
      'type': 'object',
      'properties': {
        'limit': {'type': 'integer', 'description': '返回前 N 条，默认 10'},
      },
    },
  );

  static const ToolDefinition saveRecordDef = ToolDefinition(
    name: saveRecord,
    description: '记录一次健康数据。',
    category: ToolCategory.write,
    parameters: {
      'type': 'object',
      'properties': {
        'type': {
          'type': 'string',
          'enum': ['weight', 'sleep', 'exercise', 'symptom', 'mood', 'other'],
          'description': '类型（必填）',
        },
        'value_num': {'type': 'number', 'description': '数值（kg / h / km 等）'},
        'value_text': {'type': 'string', 'description': '文本值（如"睡了 7.5h"）'},
        'unit': {'type': 'string', 'description': '单位（kg / h 等）'},
        'occurred_at': {'type': 'string', 'description': '发生时间，ISO 8601'},
        'notes': {'type': 'string', 'description': '备注'},
      },
      'required': ['type'],
    },
  );

  static const ToolDefinition deleteRecordDef = ToolDefinition(
    name: deleteRecord,
    description: '删除一条健康记录。会要求用户二次确认。',
    category: ToolCategory.confirmation,
    parameters: {
      'type': 'object',
      'properties': {
        'id': {'type': 'integer', 'description': '记录 ID（必填）'},
      },
      'required': ['id'],
    },
  );

  static void registerAll(ToolRegistry registry, AppDatabase db) {
    final dao = db.healthDao;
    registry.register(
      tool: queryRecordsDef,
      executor: (p) => _queryRecords(dao, p),
    );
    registry.register(
      tool: queryReportsDef,
      executor: (p) => _queryReports(dao, p),
    );
    registry.register(
      tool: saveRecordDef,
      executor: (p) => _saveRecord(dao, p),
    );
    registry.register(
      tool: deleteRecordDef,
      executor: (p) => _deleteRecord(dao, p),
    );
  }

  // ===== Executors =====

  static Future<ToolResult> _queryRecords(
    HealthDao dao,
    Map<String, dynamic> p,
  ) async {
    final limit = (p['limit'] as int?) ?? 20;
    final all = await dao.watchRecentRecords(limit: 100).first;
    final type = p['type'] as String?;
    final filtered = (type == null ? all : all.where((r) => r.type == type))
        .take(limit)
        .toList();
    return ToolResult.ok(
      '共 ${filtered.length} 条记录',
      data: {
        'count': filtered.length,
        'records': [
          for (final r in filtered)
            {
              'id': r.id,
              'type': r.type,
              'value_num': r.valueNum,
              'value_text': r.valueText,
              'unit': r.unit,
              'occurred_at': r.occurredAt.toIso8601String(),
            },
        ],
      },
    );
  }

  static Future<ToolResult> _queryReports(
    HealthDao dao,
    Map<String, dynamic> p,
  ) async {
    final limit = (p['limit'] as int?) ?? 10;
    final list = await dao.watchReports().first;
    final sub = list.take(limit).toList();
    return ToolResult.ok(
      '共 ${sub.length} 份体检报告',
      data: {
        'count': sub.length,
        'reports': [
          for (final r in sub)
            {
              'id': r.id,
              'hospital': r.hospital,
              'exam_date': r.examDate.toIso8601String(),
              'summary': r.summary,
            },
        ],
      },
    );
  }

  static Future<ToolResult> _saveRecord(
    HealthDao dao,
    Map<String, dynamic> p,
  ) async {
    final type = p['type'] as String?;
    if (type == null) return ToolResult.error('缺少必填参数 type');
    final occurred = p['occurred_at'] != null
        ? DateTime.tryParse(p['occurred_at'] as String) ?? DateTime.now()
        : DateTime.now();
    final id = await dao.insertRecord(
      HealthRecordsCompanion(
        type: Value(type),
        valueText: Value(p['value_text'] as String?),
        valueNum: Value((p['value_num'] as num?)?.toDouble()),
        unit: Value(p['unit'] as String?),
        occurredAt: Value(occurred),
        notes: Value(p['notes'] as String?),
      ),
    );
    return ToolResult.ok('已记录 $type（id=$id）', data: {'id': id});
  }

  static Future<ToolResult> _deleteRecord(
    HealthDao dao,
    Map<String, dynamic> p,
  ) async {
    final id = p['id'] as int?;
    if (id == null) return ToolResult.error('缺少必填参数 id');
    return ToolResult.confirm(
      '确认删除这条健康记录吗？此操作不可恢复。',
      data: {'id': id, 'tool': deleteRecord},
    );
  }

  static Future<ToolResult> confirmDeleteRecord(HealthDao dao, int id) async {
    final n = await dao.deleteRecord(id);
    return ToolResult.ok('已删除记录', data: {'deleted': n});
  }
}
