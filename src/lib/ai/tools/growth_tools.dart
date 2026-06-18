import 'package:drift/drift.dart';

import '../../../db/app_database.dart';
import '../../../modules/bulter_module.dart';
import '../../../modules/growth/db/growth_daos.dart';
import 'tool_registry.dart';

/// 成长模块 — 目标 / 学习 的只读 + 写工具。
class GrowthTools {
  GrowthTools._();

  static const String queryGoals = 'query_goals';
  static const String queryLearning = 'query_learning';
  static const String saveGoal = 'save_goal';
  static const String saveLearning = 'save_learning';
  static const String updateGoalProgress = 'update_goal_progress';
  static const String deleteGoal = 'delete_goal';

  static const ToolDefinition queryGoalsDef = ToolDefinition(
    name: queryGoals,
    description: '查询目标。',
    category: ToolCategory.read,
    parameters: {
      'type': 'object',
      'properties': {
        'status': {
          'type': 'string',
          'enum': ['active', 'completed', 'abandoned'],
          'description': '按状态过滤（默认 active）',
        },
      },
    },
  );

  static const ToolDefinition queryLearningDef = ToolDefinition(
    name: queryLearning,
    description: '查询学习记录。',
    category: ToolCategory.read,
    parameters: {
      'type': 'object',
      'properties': {
        'limit': {'type': 'integer', 'description': '返回前 N 条，默认 10'},
      },
    },
  );

  static const ToolDefinition saveGoalDef = ToolDefinition(
    name: saveGoal,
    description: '新建或更新一个目标。',
    category: ToolCategory.write,
    parameters: {
      'type': 'object',
      'properties': {
        'id': {'type': 'integer', 'description': '存在则更新，不传则新建'},
        'title': {'type': 'string', 'description': '标题（必填）'},
        'description': {'type': 'string', 'description': '描述'},
        'category': {
          'type': 'string',
          'enum': [
            'career',
            'skill',
            'health',
            'relationship',
            'finance',
            'other',
          ],
          'description': '分类',
        },
        'target_date': {'type': 'string', 'description': '目标日期，ISO 8601'},
        'progress': {'type': 'integer', 'description': '当前进度 0-100'},
      },
      'required': ['title', 'category'],
    },
  );

  static const ToolDefinition saveLearningDef = ToolDefinition(
    name: saveLearning,
    description: '记录一次学习。',
    category: ToolCategory.write,
    parameters: {
      'type': 'object',
      'properties': {
        'title': {'type': 'string', 'description': '学习内容（必填）'},
        'source': {
          'type': 'string',
          'enum': ['book', 'course', 'article', 'video', 'podcast'],
          'description': '来源（必填）',
        },
        'author': {'type': 'string', 'description': '作者 / 主讲人'},
        'rating': {'type': 'integer', 'description': '评分 1-5'},
        'notes': {'type': 'string', 'description': '笔记'},
      },
      'required': ['title', 'source'],
    },
  );

  static const ToolDefinition updateGoalProgressDef = ToolDefinition(
    name: updateGoalProgress,
    description: '更新目标的进度（0-100）。',
    category: ToolCategory.write,
    parameters: {
      'type': 'object',
      'properties': {
        'id': {'type': 'integer', 'description': '目标 ID（必填）'},
        'progress': {'type': 'integer', 'description': '新进度 0-100（必填）'},
      },
      'required': ['id', 'progress'],
    },
  );

  static const ToolDefinition deleteGoalDef = ToolDefinition(
    name: deleteGoal,
    description: '删除一个目标。会要求用户二次确认。',
    category: ToolCategory.confirmation,
    parameters: {
      'type': 'object',
      'properties': {
        'id': {'type': 'integer', 'description': '目标 ID（必填）'},
      },
      'required': ['id'],
    },
  );

  static void registerAll(ToolRegistry registry, AppDatabase db) {
    final dao = db.growthDao;
    registry.register(
      tool: queryGoalsDef,
      executor: (p) => _queryGoals(dao, p),
    );
    registry.register(
      tool: queryLearningDef,
      executor: (p) => _queryLearning(dao, p),
    );
    registry.register(tool: saveGoalDef, executor: (p) => _saveGoal(dao, p));
    registry.register(
      tool: saveLearningDef,
      executor: (p) => _saveLearning(dao, p),
    );
    registry.register(
      tool: updateGoalProgressDef,
      executor: (p) => _updateGoalProgress(dao, p),
    );
    registry.register(
      tool: deleteGoalDef,
      executor: (p) => _deleteGoal(dao, p),
    );
  }

  // ===== Executors =====

  static Future<ToolResult> _queryGoals(
    GrowthDao dao,
    Map<String, dynamic> p,
  ) async {
    final status = (p['status'] as String?) ?? 'active';
    // Step 5 简化：只支持 active，completed/abandoned 暂统一回 active 列表
    final list = await dao.watchActiveGoals().first;
    return ToolResult.ok(
      '共 ${list.length} 个目标',
      data: {
        'count': list.length,
        'status': status,
        'goals': [
          for (final g in list)
            {
              'id': g.id,
              'title': g.title,
              'category': g.category,
              'status': g.status,
              'progress': g.progress,
              'target_date': g.targetDate?.toIso8601String(),
            },
        ],
      },
    );
  }

  static Future<ToolResult> _queryLearning(
    GrowthDao dao,
    Map<String, dynamic> p,
  ) async {
    final limit = (p['limit'] as int?) ?? 10;
    final list = await dao.watchLearning().first;
    final sub = list.take(limit).toList();
    return ToolResult.ok(
      '共 ${sub.length} 条学习',
      data: {
        'count': sub.length,
        'learning': [
          for (final l in sub)
            {
              'id': l.id,
              'title': l.title,
              'source': l.source,
              'rating': l.rating,
              'author': l.author,
            },
        ],
      },
    );
  }

  static Future<ToolResult> _saveGoal(
    GrowthDao dao,
    Map<String, dynamic> p,
  ) async {
    final title = p['title'] as String?;
    final category = (p['category'] as String?) ?? 'other';
    if (title == null) return ToolResult.error('缺少必填参数 title');
    final id = p['id'] as int?;
    final target = p['target_date'] != null
        ? DateTime.tryParse(p['target_date'] as String)
        : null;
    final progress = (p['progress'] as int?) ?? 0;
    if (id == null) {
      final newId = await dao.insertGoal(
        GoalsCompanion(
          title: Value(title),
          description: Value(p['description'] as String?),
          category: Value(category),
          targetDate: target == null ? const Value.absent() : Value(target),
          progress: Value(progress),
        ),
      );
      return ToolResult.ok('已新建目标（id=$newId）', data: {'id': newId});
    } else {
      await dao.updateGoal(
        GoalsCompanion(
          id: Value(id),
          title: Value(title),
          description: Value(p['description'] as String?),
          category: Value(category),
          targetDate: target == null ? const Value.absent() : Value(target),
          progress: Value(progress),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return ToolResult.ok('已更新目标', data: {'id': id});
    }
  }

  static Future<ToolResult> _saveLearning(
    GrowthDao dao,
    Map<String, dynamic> p,
  ) async {
    final title = p['title'] as String?;
    final source = p['source'] as String?;
    if (title == null || source == null) {
      return ToolResult.error('缺少必填参数 title / source');
    }
    final id = await dao.insertLearning(
      LearningRecordsCompanion(
        title: Value(title),
        source: Value(source),
        author: Value(p['author'] as String?),
        rating: Value(p['rating'] as int?),
        notes: Value(p['notes'] as String?),
      ),
    );
    return ToolResult.ok('已记录学习（id=$id）', data: {'id': id});
  }

  static Future<ToolResult> _updateGoalProgress(
    GrowthDao dao,
    Map<String, dynamic> p,
  ) async {
    final id = p['id'] as int?;
    final progress = p['progress'] as int?;
    if (id == null || progress == null) {
      return ToolResult.error('缺少必填参数 id / progress');
    }
    final list = await dao.watchActiveGoals().first;
    final g = list.firstWhere(
      (e) => e.id == id,
      orElse: () => throw StateError('目标 id=$id 不存在'),
    );
    await dao.updateGoal(
      GoalsCompanion(
        id: Value(id),
        title: Value(g.title),
        description: Value(g.description),
        category: Value(g.category),
        targetDate: g.targetDate == null
            ? const Value.absent()
            : Value(g.targetDate!),
        status: Value(g.status),
        progress: Value(progress.clamp(0, 100)),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return ToolResult.ok('已更新进度到 $progress%', data: {'progress': progress});
  }

  static Future<ToolResult> _deleteGoal(
    GrowthDao dao,
    Map<String, dynamic> p,
  ) async {
    final id = p['id'] as int?;
    if (id == null) return ToolResult.error('缺少必填参数 id');
    return ToolResult.confirm(
      '确认删除这个目标吗？此操作不可恢复。',
      data: {'id': id, 'tool': deleteGoal},
    );
  }

  static Future<ToolResult> confirmDeleteGoal(GrowthDao dao, int id) async {
    final n = await dao.deleteGoal(id);
    return ToolResult.ok('已删除目标', data: {'deleted': n});
  }
}
