import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../db/app_database.dart';
import '../../../modules/bulter_module.dart';
import '../../../modules/relationship/db/relationship_daos.dart';
import 'tool_registry.dart';

/// 关系模块 — 联系人 CRUD + 互动 / 人情 只读 + 写入。
class RelationshipTools {
  RelationshipTools._();

  static const String queryContacts = 'query_contacts';
  static const String queryInteractions = 'query_interactions';
  static const String queryFavors = 'query_favors';
  static const String saveContact = 'save_contact';
  static const String saveInteraction = 'save_interaction';
  static const String saveFavor = 'save_favor';
  static const String deleteContact = 'delete_contact';
  static const String deleteInteraction = 'delete_interaction';
  static const String deleteFavor = 'delete_favor';

  // 公开的 ToolDefinition 常量（供模块注册与 bootstrap 引用）
  static const ToolDefinition queryContactsDef = ToolDefinition(
    name: queryContacts,
    description: '查询联系人列表。可按姓名 / 关系类型 / 标签筛选。',
    category: ToolCategory.read,
    parameters: {
      'type': 'object',
      'properties': {
        'name': {'type': 'string', 'description': '按姓名模糊匹配（可选）'},
        'relationship_type': {
          'type': 'string',
          'enum': ['friend', 'family', 'colleague', 'mentor', 'other'],
          'description': '按关系类型精确筛选（可选）',
        },
        'limit': {'type': 'integer', 'description': '返回前 N 条，默认 20'},
      },
    },
  );

  static const ToolDefinition queryInteractionsDef = ToolDefinition(
    name: queryInteractions,
    description: '查询某联系人最近的互动记录（通话 / 消息 / 见面）。',
    category: ToolCategory.read,
    parameters: {
      'type': 'object',
      'properties': {
        'contact_id': {'type': 'integer', 'description': '联系人 ID（必填）'},
        'limit': {'type': 'integer', 'description': '返回前 N 条，默认 10'},
      },
      'required': ['contact_id'],
    },
  );

  static const ToolDefinition queryFavorsDef = ToolDefinition(
    name: queryFavors,
    description: '查询人情债。可按 contact_id 过滤。',
    category: ToolCategory.read,
    parameters: {
      'type': 'object',
      'properties': {
        'contact_id': {'type': 'integer', 'description': '按联系人 ID 过滤（可选）'},
        'status': {
          'type': 'string',
          'enum': ['open', 'closed'],
          'description': '按状态过滤（可选，默认 open）',
        },
      },
    },
  );

  static const ToolDefinition saveContactDef = ToolDefinition(
    name: saveContact,
    description: '新增或更新一个联系人。name 必填；其它字段可选。',
    category: ToolCategory.write,
    parameters: {
      'type': 'object',
      'properties': {
        'id': {'type': 'integer', 'description': '存在则更新，不传则新增'},
        'name': {'type': 'string', 'description': '联系人姓名（必填）'},
        'nickname': {'type': 'string', 'description': '昵称（可选）'},
        'relationship_type': {
          'type': 'string',
          'enum': ['friend', 'family', 'colleague', 'mentor', 'other'],
          'description': '关系类型',
        },
        'importance': {'type': 'integer', 'description': '重要度 0-10，默认 5'},
        'notes': {'type': 'string', 'description': '备注'},
        'tags': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': '标签列表',
        },
        'birthday': {'type': 'string', 'description': '生日，ISO 8601 yyyy-MM-dd'},
      },
      'required': ['name', 'relationship_type'],
    },
  );

  static const ToolDefinition saveInteractionDef = ToolDefinition(
    name: saveInteraction,
    description: '记录一次与联系人的互动。',
    category: ToolCategory.write,
    parameters: {
      'type': 'object',
      'properties': {
        'contact_id': {'type': 'integer', 'description': '联系人 ID（必填）'},
        'happened_at': {
          'type': 'string',
          'description': '互动时间，ISO 8601。默认当前时间',
        },
        'type': {
          'type': 'string',
          'enum': ['message', 'call', 'meeting', 'meal', 'other'],
          'description': '互动类型',
        },
        'summary': {'type': 'string', 'description': '一句话摘要（必填）'},
        'mood': {'type': 'integer', 'description': '心情 1-5，可选'},
      },
      'required': ['contact_id', 'type', 'summary'],
    },
  );

  static const ToolDefinition saveFavorDef = ToolDefinition(
    name: saveFavor,
    description: '记录一笔人情债。',
    category: ToolCategory.write,
    parameters: {
      'type': 'object',
      'properties': {
        'contact_id': {'type': 'integer', 'description': '联系人 ID（必填）'},
        'direction': {
          'type': 'string',
          'enum': ['i_owe', 'they_owe', 'gift_given', 'gift_received'],
          'description': '方向',
        },
        'description': {'type': 'string', 'description': '描述（必填）'},
        'amount_cents': {'type': 'integer', 'description': '金额（单位：分）'},
        'happened_at': {'type': 'string', 'description': '发生时间，ISO 8601'},
      },
      'required': ['contact_id', 'direction', 'description'],
    },
  );

  static const ToolDefinition deleteContactDef = ToolDefinition(
    name: deleteContact,
    description: '删除一个联系人（级联删除其互动 / 人情）。该操作不可逆，会要求用户二次确认。',
    category: ToolCategory.confirmation,
    parameters: {
      'type': 'object',
      'properties': {
        'id': {'type': 'integer', 'description': '联系人 ID（必填）'},
      },
      'required': ['id'],
    },
  );

  static const ToolDefinition deleteInteractionDef = ToolDefinition(
    name: deleteInteraction,
    description: '删除一条互动记录。会要求用户二次确认。',
    category: ToolCategory.confirmation,
    parameters: {
      'type': 'object',
      'properties': {
        'id': {'type': 'integer', 'description': '互动 ID（必填）'},
      },
      'required': ['id'],
    },
  );

  static const ToolDefinition deleteFavorDef = ToolDefinition(
    name: deleteFavor,
    description: '删除一条人情记录。会要求用户二次确认。',
    category: ToolCategory.confirmation,
    parameters: {
      'type': 'object',
      'properties': {
        'id': {'type': 'integer', 'description': '人情 ID（必填）'},
      },
      'required': ['id'],
    },
  );

  /// 把全部工具注册到 [registry]。
  static void registerAll(ToolRegistry registry, AppDatabase db) {
    final dao = db.relationshipDao;
    registry.register(
      tool: queryContactsDef,
      executor: (p) => _queryContacts(dao, p),
    );
    registry.register(
      tool: queryInteractionsDef,
      executor: (p) => _queryInteractions(dao, p),
    );
    registry.register(
      tool: queryFavorsDef,
      executor: (p) => _queryFavors(dao, p),
    );
    registry.register(
      tool: saveContactDef,
      executor: (p) => _saveContact(dao, p),
    );
    registry.register(
      tool: saveInteractionDef,
      executor: (p) => _saveInteraction(dao, p),
    );
    registry.register(tool: saveFavorDef, executor: (p) => _saveFavor(dao, p));
    registry.register(
      tool: deleteContactDef,
      executor: (p) => _deleteContact(dao, p),
    );
    registry.register(
      tool: deleteInteractionDef,
      executor: (p) => _deleteInteraction(dao, p),
    );
    registry.register(
      tool: deleteFavorDef,
      executor: (p) => _deleteFavor(dao, p),
    );
  }

  // ===== Executors =====

  static Future<ToolResult> _queryContacts(
    RelationshipDao dao,
    Map<String, dynamic> p,
  ) async {
    final all = await dao.watchContacts().first;
    Iterable<Contact> filtered = all;
    final name = (p['name'] as String?)?.toLowerCase();
    if (name != null && name.isNotEmpty) {
      filtered = filtered.where((c) => c.name.toLowerCase().contains(name));
    }
    final relType = p['relationship_type'] as String?;
    if (relType != null) {
      filtered = filtered.where((c) => c.relationshipType == relType);
    }
    final limit = (p['limit'] as int?) ?? 20;
    final list = filtered.take(limit).toList();
    return ToolResult.ok(
      '共找到 ${list.length} 个联系人',
      data: {
        'count': list.length,
        'contacts': [
          for (final c in list)
            {
              'id': c.id,
              'name': c.name,
              'nickname': c.nickname,
              'relationship_type': c.relationshipType,
              'importance': c.importance,
              'last_contact_at': c.lastContactAt?.toIso8601String(),
              'tags': _parseTagsJson(c.tagsJson),
            },
        ],
      },
    );
  }

  static Future<ToolResult> _queryInteractions(
    RelationshipDao dao,
    Map<String, dynamic> p,
  ) async {
    final cid = p['contact_id'] as int?;
    if (cid == null) {
      return ToolResult.error('缺少必填参数 contact_id');
    }
    final limit = (p['limit'] as int?) ?? 10;
    final list = await dao
        .watchInteractionsFor(cid)
        .first
        .then((l) => l.take(limit).toList());
    return ToolResult.ok(
      '共找到 ${list.length} 条互动',
      data: {
        'count': list.length,
        'interactions': [
          for (final i in list)
            {
              'id': i.id,
              'contact_id': i.contactId,
              'happened_at': i.happenedAt.toIso8601String(),
              'type': i.type,
              'summary': i.summary,
              'mood': i.mood,
            },
        ],
      },
    );
  }

  static Future<ToolResult> _queryFavors(
    RelationshipDao dao,
    Map<String, dynamic> p,
  ) async {
    final status = (p['status'] as String?) ?? 'open';
    final contactId = p['contact_id'] as int?;
    final all = await dao.watchOpenFavors().first;
    Iterable<Favor> filtered = all;
    if (status == 'closed') {
      // 未实现 closed 列表，回退到 open
    }
    if (contactId != null) {
      filtered = filtered.where((f) => f.contactId == contactId);
    }
    final list = filtered.toList();
    return ToolResult.ok(
      '共找到 ${list.length} 笔人情',
      data: {
        'count': list.length,
        'favors': [
          for (final f in list)
            {
              'id': f.id,
              'contact_id': f.contactId,
              'direction': f.direction,
              'description': f.description,
              'amount_cents': f.amountCents,
              'status': f.status,
            },
        ],
      },
    );
  }

  static Future<ToolResult> _saveContact(
    RelationshipDao dao,
    Map<String, dynamic> p,
  ) async {
    final name = p['name'] as String?;
    if (name == null || name.isEmpty) {
      return ToolResult.error('缺少必填参数 name');
    }
    final relType = (p['relationship_type'] as String?) ?? 'other';
    final id = p['id'] as int?;
    final tags = (p['tags'] as List?)?.cast<String>() ?? const <String>[];
    final companion = ContactsCompanion(
      id: id == null ? const Value.absent() : Value(id),
      name: Value(name),
      nickname: Value(p['nickname'] as String?),
      relationshipType: Value(relType),
      importance: Value((p['importance'] as int?) ?? 5),
      notes: Value(p['notes'] as String?),
      tagsJson: Value(jsonEncode(tags)),
      birthday: p['birthday'] != null
          ? Value(DateTime.tryParse(p['birthday'] as String) ?? DateTime.now())
          : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    );
    if (id == null) {
      final newId = await dao.insertContact(companion);
      return ToolResult.ok('已新建联系人 $name（id=$newId）', data: {'id': newId});
    } else {
      await dao.updateContact(companion);
      return ToolResult.ok('已更新联系人 $name（id=$id）', data: {'id': id});
    }
  }

  static Future<ToolResult> _saveInteraction(
    RelationshipDao dao,
    Map<String, dynamic> p,
  ) async {
    final cid = p['contact_id'] as int?;
    final summary = p['summary'] as String?;
    final type = (p['type'] as String?) ?? 'message';
    if (cid == null || summary == null) {
      return ToolResult.error('缺少必填参数 contact_id / summary');
    }
    final happened = p['happened_at'] != null
        ? DateTime.tryParse(p['happened_at'] as String) ?? DateTime.now()
        : DateTime.now();
    final id = await dao.insertInteraction(
      InteractionsCompanion(
        contactId: Value(cid),
        happenedAt: Value(happened),
        type: Value(type),
        summary: Value(summary),
        mood: Value(p['mood'] as int?),
      ),
    );
    return ToolResult.ok('已记录互动（id=$id）', data: {'id': id});
  }

  static Future<ToolResult> _saveFavor(
    RelationshipDao dao,
    Map<String, dynamic> p,
  ) async {
    final cid = p['contact_id'] as int?;
    final desc = p['description'] as String?;
    final dir = (p['direction'] as String?) ?? 'gift_given';
    if (cid == null || desc == null) {
      return ToolResult.error('缺少必填参数 contact_id / description');
    }
    final happened = p['happened_at'] != null
        ? DateTime.tryParse(p['happened_at'] as String) ?? DateTime.now()
        : DateTime.now();
    final id = await dao.insertFavor(
      FavorsCompanion(
        contactId: Value(cid),
        direction: Value(dir),
        description: Value(desc),
        amountCents: Value((p['amount_cents'] as int?) ?? 0),
        happenedAt: Value(happened),
      ),
    );
    return ToolResult.ok('已记录人情（id=$id）', data: {'id': id});
  }

  static Future<ToolResult> _deleteContact(
    RelationshipDao dao,
    Map<String, dynamic> p,
  ) async {
    final id = p['id'] as int?;
    if (id == null) return ToolResult.error('缺少必填参数 id');
    final c = await dao.getContact(id);
    if (c == null) return ToolResult.error('未找到联系人 id=$id');
    return ToolResult.confirm(
      '确认删除联系人「${c.name}」吗？此操作会级联删除其全部互动和人情记录，且不可恢复。',
      data: {'id': id, 'name': c.name, 'tool': deleteContact},
    );
  }

  static Future<ToolResult> _deleteInteraction(
    RelationshipDao dao,
    Map<String, dynamic> p,
  ) async {
    final id = p['id'] as int?;
    if (id == null) return ToolResult.error('缺少必填参数 id');
    return ToolResult.confirm(
      '确认删除这条互动记录吗？此操作不可恢复。',
      data: {'id': id, 'tool': deleteInteraction},
    );
  }

  static Future<ToolResult> _deleteFavor(
    RelationshipDao dao,
    Map<String, dynamic> p,
  ) async {
    final id = p['id'] as int?;
    if (id == null) return ToolResult.error('缺少必填参数 id');
    return ToolResult.confirm(
      '确认删除这笔人情记录吗？此操作不可恢复。',
      data: {'id': id, 'tool': deleteFavor},
    );
  }

  /// 确认后真正删除（被 chat_page 调用）。
  static Future<ToolResult> confirmDeleteContact(
    RelationshipDao dao,
    int id,
  ) async {
    final c = await dao.getContact(id);
    if (c == null) return ToolResult.error('联系人已不存在');
    final n = await dao.deleteContact(id);
    return ToolResult.ok('已删除联系人 ${c.name}', data: {'deleted': n});
  }

  static Future<ToolResult> confirmDeleteInteraction(
    RelationshipDao dao,
    int id,
  ) async {
    final n = await dao.deleteInteraction(id);
    return ToolResult.ok('已删除互动', data: {'deleted': n});
  }

  static Future<ToolResult> confirmDeleteFavor(
    RelationshipDao dao,
    int id,
  ) async {
    final n = await dao.deleteFavor(id);
    return ToolResult.ok('已删除人情', data: {'deleted': n});
  }

  static List<String> _parseTagsJson(String json) {
    try {
      return (jsonDecode(json) as List).cast<String>();
    } catch (_) {
      return const [];
    }
  }
}
