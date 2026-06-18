import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../db/app_database.dart';
import '../../../modules/bulter_module.dart';
import '../../../modules/thought/db/thought_daos.dart';
import 'tool_registry.dart';

/// 思想模块 — 想法 / 信件 的只读 + 写工具。
class ThoughtTools {
  ThoughtTools._();

  static const String queryThoughts = 'query_thoughts';
  static const String queryLetters = 'query_letters';
  static const String saveThought = 'save_thought';
  static const String saveLetter = 'save_letter';
  static const String deleteThought = 'delete_thought';
  static const String deleteLetter = 'delete_letter';

  static const ToolDefinition queryThoughtsDef = ToolDefinition(
    name: queryThoughts,
    description: '查询想法 / 读后感。',
    category: ToolCategory.read,
    parameters: {
      'type': 'object',
      'properties': {
        'limit': {'type': 'integer', 'description': '返回前 N 条，默认 10'},
        'tag': {'type': 'string', 'description': '按标签过滤（可选）'},
      },
    },
  );

  static const ToolDefinition queryLettersDef = ToolDefinition(
    name: queryLetters,
    description: '查询信件。',
    category: ToolCategory.read,
    parameters: {
      'type': 'object',
      'properties': {
        'status': {
          'type': 'string',
          'enum': ['opened', 'unopened', 'all'],
          'description': '按开 / 未开过滤（默认 unopened）',
        },
      },
    },
  );

  static const ToolDefinition saveThoughtDef = ToolDefinition(
    name: saveThought,
    description: '记录一条想法 / 读后感。',
    category: ToolCategory.write,
    parameters: {
      'type': 'object',
      'properties': {
        'content': {'type': 'string', 'description': '内容（必填）'},
        'source': {
          'type': 'string',
          'enum': ['book', 'article', 'movie', 'conversation', 'other'],
          'description': '来源（必填）',
        },
        'source_ref': {'type': 'string', 'description': '来源引用（如书名）'},
        'tags': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': '标签列表',
        },
        'mood': {'type': 'integer', 'description': '心情 1-5'},
        'recorded_at': {'type': 'string', 'description': '记录时间，ISO 8601'},
      },
      'required': ['content', 'source'],
    },
  );

  static const ToolDefinition saveLetterDef = ToolDefinition(
    name: saveLetter,
    description: '写一封信（给未来的自己 / 他人 / 未来日期拆封）。',
    category: ToolCategory.write,
    parameters: {
      'type': 'object',
      'properties': {
        'title': {'type': 'string', 'description': '标题（必填）'},
        'content': {'type': 'string', 'description': '正文（必填）'},
        'type': {
          'type': 'string',
          'enum': ['to_self', 'to_others', 'to_future'],
          'description': '类型（必填）',
        },
        'target_date': {'type': 'string', 'description': '目标拆封日期，ISO 8601（可选）'},
      },
      'required': ['title', 'content', 'type'],
    },
  );

  static const ToolDefinition deleteThoughtDef = ToolDefinition(
    name: deleteThought,
    description: '删除一条想法。会要求用户二次确认。',
    category: ToolCategory.confirmation,
    parameters: {
      'type': 'object',
      'properties': {
        'id': {'type': 'integer', 'description': '想法 ID（必填）'},
      },
      'required': ['id'],
    },
  );

  static const ToolDefinition deleteLetterDef = ToolDefinition(
    name: deleteLetter,
    description: '删除一封信。会要求用户二次确认。',
    category: ToolCategory.confirmation,
    parameters: {
      'type': 'object',
      'properties': {
        'id': {'type': 'integer', 'description': '信件 ID（必填）'},
      },
      'required': ['id'],
    },
  );

  static void registerAll(ToolRegistry registry, AppDatabase db) {
    final dao = db.thoughtDao;
    registry.register(
      tool: queryThoughtsDef,
      executor: (p) => _queryThoughts(dao, p),
    );
    registry.register(
      tool: queryLettersDef,
      executor: (p) => _queryLetters(dao, p),
    );
    registry.register(
      tool: saveThoughtDef,
      executor: (p) => _saveThought(dao, p),
    );
    registry.register(
      tool: saveLetterDef,
      executor: (p) => _saveLetter(dao, p),
    );
    registry.register(
      tool: deleteThoughtDef,
      executor: (p) => _deleteThought(dao, p),
    );
    registry.register(
      tool: deleteLetterDef,
      executor: (p) => _deleteLetter(dao, p),
    );
  }

  // ===== Executors =====

  static Future<ToolResult> _queryThoughts(
    ThoughtDao dao,
    Map<String, dynamic> p,
  ) async {
    final limit = (p['limit'] as int?) ?? 10;
    final list = await dao.watchRecentThoughts(limit: 100).first;
    final tag = p['tag'] as String?;
    final filtered = tag == null
        ? list.take(limit).toList()
        : list
              .where((t) => _parseTagsJson(t.tagsJson).contains(tag))
              .take(limit)
              .toList();
    return ToolResult.ok(
      '共 ${filtered.length} 条想法',
      data: {
        'count': filtered.length,
        'thoughts': [
          for (final t in filtered)
            {
              'id': t.id,
              'content': t.content,
              'source': t.source,
              'source_ref': t.sourceRef,
              'tags': _parseTagsJson(t.tagsJson),
              'mood': t.mood,
              'recorded_at': t.recordedAt.toIso8601String(),
            },
        ],
      },
    );
  }

  static Future<ToolResult> _queryLetters(
    ThoughtDao dao,
    Map<String, dynamic> p,
  ) async {
    final status = (p['status'] as String?) ?? 'unopened';
    if (status == 'unopened') {
      final list = await dao.watchUnopenedLetters().first;
      return ToolResult.ok(
        '共 ${list.length} 封待拆信件',
        data: {
          'count': list.length,
          'letters': [
            for (final l in list)
              {
                'id': l.id,
                'title': l.title,
                'type': l.type,
                'target_date': l.targetDate?.toIso8601String(),
              },
          ],
        },
      );
    }
    return ToolResult.ok('暂不支持该过滤', data: {'letters': []});
  }

  static Future<ToolResult> _saveThought(
    ThoughtDao dao,
    Map<String, dynamic> p,
  ) async {
    final content = p['content'] as String?;
    final source = p['source'] as String?;
    if (content == null || source == null) {
      return ToolResult.error('缺少必填参数 content / source');
    }
    final tags = (p['tags'] as List?)?.cast<String>() ?? const <String>[];
    final id = await dao.insertThought(
      ThoughtsCompanion(
        content: Value(content),
        source: Value(source),
        sourceRef: Value(p['source_ref'] as String?),
        tagsJson: Value(jsonEncode(tags)),
        mood: Value(p['mood'] as int?),
        recordedAt: Value(
          p['recorded_at'] != null
              ? (DateTime.tryParse(p['recorded_at'] as String) ??
                    DateTime.now())
              : DateTime.now(),
        ),
      ),
    );
    return ToolResult.ok('已记录想法（id=$id）', data: {'id': id});
  }

  static Future<ToolResult> _saveLetter(
    ThoughtDao dao,
    Map<String, dynamic> p,
  ) async {
    final title = p['title'] as String?;
    final content = p['content'] as String?;
    final type = p['type'] as String?;
    if (title == null || content == null || type == null) {
      return ToolResult.error('缺少必填参数 title / content / type');
    }
    final id = await dao.insertLetter(
      LettersCompanion(
        title: Value(title),
        content: Value(content),
        type: Value(type),
        targetDate: p['target_date'] != null
            ? Value(
                DateTime.tryParse(p['target_date'] as String) ?? DateTime.now(),
              )
            : const Value.absent(),
      ),
    );
    return ToolResult.ok('已写下信件「$title」（id=$id）', data: {'id': id});
  }

  static Future<ToolResult> _deleteThought(
    ThoughtDao dao,
    Map<String, dynamic> p,
  ) async {
    final id = p['id'] as int?;
    if (id == null) return ToolResult.error('缺少必填参数 id');
    return ToolResult.confirm(
      '确认删除这条想法吗？此操作不可恢复。',
      data: {'id': id, 'tool': deleteThought},
    );
  }

  static Future<ToolResult> _deleteLetter(
    ThoughtDao dao,
    Map<String, dynamic> p,
  ) async {
    final id = p['id'] as int?;
    if (id == null) return ToolResult.error('缺少必填参数 id');
    return ToolResult.confirm(
      '确认删除这封信吗？此操作不可恢复。',
      data: {'id': id, 'tool': deleteLetter},
    );
  }

  static Future<ToolResult> confirmDeleteThought(ThoughtDao dao, int id) async {
    final n = await dao.deleteThought(id);
    return ToolResult.ok('已删除想法', data: {'deleted': n});
  }

  static Future<ToolResult> confirmDeleteLetter(ThoughtDao dao, int id) async {
    final n = await dao.deleteLetter(id);
    return ToolResult.ok('已删除信件', data: {'deleted': n});
  }

  static List<String> _parseTagsJson(String json) {
    try {
      return (jsonDecode(json) as List).cast<String>();
    } catch (_) {
      return const [];
    }
  }
}
