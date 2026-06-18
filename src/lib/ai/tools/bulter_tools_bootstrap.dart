import 'package:flutter/foundation.dart';

import '../../db/app_database.dart';
import '../../modules/bulter_module.dart';
import 'growth_tools.dart';
import 'health_tools.dart';
import 'relationship_tools.dart';
import 'thought_tools.dart';
import 'tool_registry.dart';
import 'wealth_tools.dart';

/// 集中注册所有业务模块的工具。
///
/// 主模型注册全量；子 Agent 物理隔离（在 [SubAgentRegistry] 的
/// `ToolRegistry.fresh()` 中只收集只读 / 系统类）。
class BulterToolsBootstrap {
  BulterToolsBootstrap._();

  /// 注册所有业务模块的全部工具（含写）。
  static void registerAll(ToolRegistry registry, AppDatabase db) {
    RelationshipTools.registerAll(registry, db);
    WealthTools.registerAll(registry, db);
    ThoughtTools.registerAll(registry, db);
    HealthTools.registerAll(registry, db);
    GrowthTools.registerAll(registry, db);
    debugPrint('BulterToolsBootstrap: 已注册 ${registry.getTools().length} 个工具');
  }

  /// 列出全部工具定义（UI 调试 / 设置页展示用）。
  static const List<ToolDefinition> allReadTools = [
    RelationshipTools.queryContactsDef,
    RelationshipTools.queryInteractionsDef,
    RelationshipTools.queryFavorsDef,
    WealthTools.queryAccountsDef,
    WealthTools.queryTransactionsDef,
    WealthTools.querySpendingDef,
    ThoughtTools.queryThoughtsDef,
    ThoughtTools.queryLettersDef,
    HealthTools.queryRecordsDef,
    HealthTools.queryReportsDef,
    GrowthTools.queryGoalsDef,
    GrowthTools.queryLearningDef,
  ];

  static const List<ToolDefinition> allWriteTools = [
    RelationshipTools.saveContactDef,
    RelationshipTools.saveInteractionDef,
    RelationshipTools.saveFavorDef,
    RelationshipTools.deleteContactDef,
    RelationshipTools.deleteInteractionDef,
    RelationshipTools.deleteFavorDef,
    WealthTools.saveTransactionDef,
    WealthTools.saveAccountDef,
    WealthTools.deleteTransactionDef,
    ThoughtTools.saveThoughtDef,
    ThoughtTools.saveLetterDef,
    ThoughtTools.deleteThoughtDef,
    ThoughtTools.deleteLetterDef,
    HealthTools.saveRecordDef,
    HealthTools.deleteRecordDef,
    GrowthTools.saveGoalDef,
    GrowthTools.saveLearningDef,
    GrowthTools.updateGoalProgressDef,
    GrowthTools.deleteGoalDef,
  ];
}
