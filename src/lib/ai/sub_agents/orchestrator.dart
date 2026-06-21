import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../modules/bulter_module.dart';
import 'sub_agent_registry.dart';

/// 主模型调度器（Step 8）。
///
/// 职责：
/// 1. 单个 [invokeSubAgent]：主模型在 `invoke_sub_agent` 工具里调用 → 返回自然语言结果
/// 2. 批量 [invokeMultiple]：并行调多个子模型，主模型用于跨模块叙事
/// 3. **始终成功**：子模型失败 / 超时 → 降级文案，不会让主模型对话崩溃
///
/// 设计原则：
/// - **物理隔离写权限**：[SpecialistAgent] 构造时拿到的 [ToolRegistry] 已通过
///   `SubAgentRegistry.register(includeWrite: false)` 过滤，根本拿不到写工具。
/// - **不修改主模型 stream 流**：子模型调用是**同步阻塞等待**的一次性任务，不与
///   主模型的流式输出交错。主模型通过 `invoke_sub_agent` 工具拿到最终文本即可。
/// - **降级而非抛出**：单个失败 → 局部降级文案；整体失败 → 返回所有降级拼成的字符串。
class Orchestrator {
  final SubAgentRegistry registry;

  /// 单次调用的默认超时（与 SpecialistAgent 默认对齐）。
  final Duration defaultPerCallTimeout;

  /// 整体批量调用的最大墙钟（防止永远等下去）。
  final Duration defaultBatchTimeout;

  Orchestrator({
    required this.registry,
    this.defaultPerCallTimeout = const Duration(seconds: 8),
    this.defaultBatchTimeout = const Duration(seconds: 12),
  });

  /// 调一个子模型。
  ///
  /// 找不到模块 / Agent 未注册 → 返回降级文案而不抛错。
  Future<SubAgentResult> invokeSubAgent(
    String moduleId,
    String query, {
    Duration? timeout,
  }) async {
    final agent = registry.get(moduleId);
    if (agent == null) {
      debugPrint('Orchestrator: 未知模块 "$moduleId"');
      return SubAgentResult(
        moduleId: moduleId,
        moduleName: moduleId,
        ok: false,
        text: '（未注册的模块 $moduleId，无法调度）',
        toolsUsed: const [],
        elapsed: Duration.zero,
        error: 'module_not_registered',
      );
    }
    return agent.invoke(query, timeout: timeout);
  }

  /// 并行调多个子模型，**整体**不超 [defaultBatchTimeout]。
  ///
  /// 返回值按入参 [moduleIds] 顺序对齐；任意一个失败 → 对应位置是降级文案（`ok: false`）。
  Future<List<SubAgentResult>> invokeMultiple(
    List<String> moduleIds,
    String query, {
    Duration? perCallTimeout,
    Duration? batchTimeout,
  }) async {
    if (moduleIds.isEmpty) return const [];
    final batch = batchTimeout ?? defaultBatchTimeout;
    final per = perCallTimeout ?? defaultPerCallTimeout;

    final futures = moduleIds.map(
      (id) => invokeSubAgent(id, query, timeout: per),
    );

    try {
      return await Future.wait(futures).timeout(batch);
    } on TimeoutException {
      debugPrint(
        'Orchestrator: 批量调用整体超时（${batch.inMilliseconds}ms）',
      );
      return moduleIds.map((id) {
        final agent = registry.get(id);
        return SubAgentResult(
          moduleId: id,
          moduleName: agent?.name ?? id,
          ok: false,
          text: '（${agent?.name ?? id} 子模型调用超时）',
          toolsUsed: const [],
          elapsed: batch,
          error: 'batch_timeout',
        );
      }).toList();
    }
  }

  /// 把多个结果拼成一段"子模型答复合集"，给主模型在 prompt 里参考。
  String renderForLlm(List<SubAgentResult> results) {
    if (results.isEmpty) return '';
    final buf = StringBuffer('子模型答复：\n');
    for (final r in results) {
      buf.writeln('- ${r.toLlmContext()}');
    }
    return buf.toString();
  }
}
