import 'package:flutter/foundation.dart';

import '../../modules/bulter_module.dart';

/// AI 工具注册表。
///
/// 通过 [register] 动态注册工具，AI Service 调用 [getJsonSchemas] 取得
/// 当前可用工具列表，调用 [execute] 执行具体工具。
///
/// 工具隔离在**注册层**完成：子 Agent 构造时不注入写工具，从根本上
/// 隔离权限，无需运行时字符串匹配。
class ToolRegistry {
  ToolRegistry._();

  /// 工厂构造器：用于子 Agent 创建独立的隔离注册表。
  factory ToolRegistry.fresh() => ToolRegistry._();

  static final ToolRegistry instance = ToolRegistry._();

  final Map<String, ToolDefinition> _definitions = {};
  final Map<String, ToolExecutor> _executors = {};

  void register({
    required ToolDefinition tool,
    required ToolExecutor executor,
  }) {
    if (_definitions.containsKey(tool.name)) {
      debugPrint('ToolRegistry: 工具 ${tool.name} 已存在，将被覆盖');
    }
    _definitions[tool.name] = tool;
    _executors[tool.name] = executor;
  }

  /// 收集模块列表中所有工具并注册。
  /// 主模型使用全量；子 Agent 只收集只读 + briefing_publish + rag_search。
  void registerFromModules(
    List<BulterModule> modules, {
    bool includeWrite = true,
  }) {
    for (final m in modules) {
      for (final t in m.tools) {
        if (!includeWrite && _isWriteTool(t.name)) continue;
        _definitions[t.name] = t;
        // Step 1 占位：未提供执行器时用空实现，后续步骤在 tools/ 中实现
        _executors.putIfAbsent(
          t.name,
          () =>
              (params) async => {
                'status': 'not_implemented',
                'tool': t.name,
                'params': params,
              },
        );
      }
    }
  }

  bool _isWriteTool(String name) {
    return name.startsWith('save_') ||
        name.startsWith('update_') ||
        name.startsWith('delete_') ||
        name == 'briefing_publish';
  }

  List<ToolDefinition> getTools() =>
      _definitions.values.toList(growable: false);

  /// 转 OpenAI Function Calling JSON Schema 格式（占位，Step 5 完善）
  List<Map<String, dynamic>> getJsonSchemas() {
    return _definitions.values
        .map(
          (t) => {
            'type': 'function',
            'function': {
              'name': t.name,
              'description': t.description,
              'parameters': {
                'type': 'object',
                'properties': <String, dynamic>{},
              },
            },
          },
        )
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> execute(
    String name,
    Map<String, dynamic> params,
  ) async {
    final exec = _executors[name];
    if (exec == null) {
      return {'status': 'error', 'message': '未注册工具：$name'};
    }
    try {
      return await exec(params);
    } catch (e, st) {
      debugPrint('ToolRegistry: 执行 $name 出错: $e\n$st');
      return {'status': 'error', 'message': e.toString()};
    }
  }

  void clear() {
    _definitions.clear();
    _executors.clear();
  }
}
