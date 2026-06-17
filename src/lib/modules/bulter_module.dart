import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 模块 ID。约定全小写，URL / 事件 / Hive Box 命名都用这个。
class ModuleId {
  ModuleId._();
  static const String butler = 'butler';
  static const String relationship = 'relationship';
  static const String growth = 'growth';
  static const String wealth = 'wealth';
  static const String thought = 'thought';
  static const String health = 'health';
  static const String memory = 'memory';
  static const String demo = 'demo';
}

/// 子 Agent 标识（占位；后续步骤填充实际调用）
class SpecialistAgent {
  final String moduleId;
  final String name;
  const SpecialistAgent({required this.moduleId, required this.name});
}

/// 工具定义（占位，Step 5 实现 JSON Schema 与执行器）
class ToolDefinition {
  final String name;
  final String description;
  const ToolDefinition({required this.name, required this.description});
}

/// 工具执行器（占位）
typedef ToolExecutor =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> params);

/// 简报生成器（占位；Step 9 实现）
typedef BriefingGenerator = Future<String> Function();

/// 业务模块统一接口。
///
/// 任何新增模块（关系/成长/财富/思想/健康/记忆/自定义 demo 模块）都必须
/// 实现该接口，并通过 [ModuleRegistry] 注册。新增模块**不需要**修改 router
/// / orchestrator / EventBus 主流程。
abstract class BulterModule {
  /// 唯一 ID（参见 [ModuleId] 常量约定）
  String get id;

  /// 展示名（中文）
  String get displayName;

  /// 品牌色（用于卡片/icon/胶囊切换器高亮）
  Color get brandColor;

  /// lucide 图标名（用于跨模块一致图标；Step 1 阶段可使用 Material Icons fallback）
  String get iconName;

  /// 入口路由 path（go_router）
  String get entryRoute;

  /// 主页 Scaffold（模块内默认视图）。Step 1 用占位，Step 3 起接真实 CRUD。
  Widget buildHomePage(BuildContext context);

  /// 模块内子 Tab 列表（占位；Step 3 后接真实 tabs）。
  /// 返回空列表则不显示底部 Tab。
  List<ModuleTab> get tabs;

  /// 该模块需要注册的子 Agent
  SpecialistAgent? get subAgent;

  /// 该模块提供的只读/写工具 id 列表（供 ToolRegistry 注册）
  List<ToolDefinition> get tools;

  /// 该模块提供的简报生成器
  BriefingGenerator? get briefingGenerator;

  /// 注册时回调（用于挂载 EventBus 监听、打开 Hive Box 等）
  Future<void> onRegister();

  /// 卸载时回调
  Future<void> onDispose();
}

/// 模块内 Tab 描述
class ModuleTab {
  final String id;
  final String label;
  final IconData icon;
  final WidgetBuilder builder;

  const ModuleTab({
    required this.id,
    required this.label,
    required this.icon,
    required this.builder,
  });
}

/// 颜色助手：按 id 返回默认品牌色（仅在模块未实现 brandColor 时兜底）
Color defaultBrandColor(String id) {
  switch (id) {
    case ModuleId.butler:
      return BulterColors.butler;
    case ModuleId.relationship:
      return BulterColors.relationship;
    case ModuleId.growth:
      return BulterColors.growth;
    case ModuleId.wealth:
      return BulterColors.wealth;
    case ModuleId.thought:
      return BulterColors.thought;
    case ModuleId.health:
      return BulterColors.health;
    case ModuleId.memory:
      return BulterColors.memory;
    case ModuleId.demo:
      return BulterColors.info;
    default:
      return BulterColors.butler;
  }
}
