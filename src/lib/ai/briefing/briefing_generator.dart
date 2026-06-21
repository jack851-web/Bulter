import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../modules/bulter_module.dart';
import '../../modules/registry.dart';
import '../briefing/briefing_models.dart';
import '../briefing/briefing_store.dart';
import '../memory/short_term.dart';
import '../model_registry.dart';
import '../sub_agents/orchestrator.dart';
import '../sub_agents/sub_agent_registry.dart';

/// 简报生成器（Step 9）。
///
/// **设计**：
/// - 单条生成：[generate(moduleId)] → 调对应模块的子 Agent（Step 8）拉数据 +
///   LLM 总结 → 解析 JSON → `ModuleBriefing`
/// - 批量生成：[generateAll()] → 并行触发所有模块简报
/// - **失败兜底**：子模型超时 / 解析失败 / LLM 失败 → fallback `ModuleBriefing`
///   保证中枢主页永远有内容可渲染
///
/// **为什么用子 Agent 而不是主模型直接调工具**：
/// 子 Agent 已经有"读本模块 + 拼 system prompt"的完整封装（Step 8），
/// 直接复用 [Orchestrator.invokeSubAgent] 一行调用即可完成，无需重复实现。
class BriefingGenerator {
  BriefingGenerator._();
  static final BriefingGenerator instance = BriefingGenerator._();

  final Orchestrator _orchestrator = Orchestrator(
    registry: SubAgentRegistry.instance,
    defaultPerCallTimeout: const Duration(seconds: 12),
    defaultBatchTimeout: const Duration(seconds: 20),
  );

  /// 调子 Agent 生成某模块的简报。
  ///
  /// 返回 `ModuleBriefing`（成功）或 fallback（失败）。
  /// **不抛错**，所有异常内部 catch。
  Future<ModuleBriefing> generate(
    String moduleId, {
    BriefingPeriod period = BriefingPeriod.daily,
    Duration? timeout,
  }) async {
    final query = _composeQuery(moduleId, period);
    try {
      final result = await _orchestrator.invokeSubAgent(
        moduleId,
        query,
        timeout: timeout,
      );
      if (!result.ok) {
        debugPrint('BriefingGenerator: $moduleId 子模型失败 - ${result.error}');
        return ModuleBriefing.fallback(
          moduleId,
          headline: _fallbackHeadline(moduleId),
          summary: '（$moduleId 子模型暂不可用，下次重试）',
        );
      }
      final parsed = _parseJson(result.text, moduleId);
      if (parsed == null) {
        debugPrint('BriefingGenerator: $moduleId 解析失败 - ${result.text}');
        return ModuleBriefing.fallback(
          moduleId,
          headline: _fallbackHeadline(moduleId),
          summary: result.text.isEmpty
              ? '（子模型未返回内容）'
              : result.text.length > 80
                  ? '${result.text.substring(0, 80)}…'
                  : result.text,
        );
      }
      return parsed.copyWith(generatedAt: DateTime.now());
    } catch (e) {
      debugPrint('BriefingGenerator: $moduleId 异常 - $e');
      return ModuleBriefing.fallback(moduleId);
    }
  }

  /// 并行生成所有模块的简报（含中枢）。
  ///
  /// 中枢特殊：先并行调 5 个业务模块，再串行调主模型汇总。
  Future<List<ModuleBriefing>> generateAll() async {
    final modules = ModuleRegistry.instance.all
        .where((m) => m.hasSubAgent)
        .toList(growable: false);
    if (modules.isEmpty) return const [];
    final results = await Future.wait(
      modules.map((m) => generate(m.id)),
    );
    return results;
  }

  /// 中枢主简报（调主模型聚合 5 个子模块答复）。
  Future<ModuleBriefing> generateButler() async {
    final moduleBriefings = await generateAll();
    if (moduleBriefings.isEmpty) {
      return ModuleBriefing.fallback(
        ModuleId.butler,
        headline: '今天没有需要决定的事',
        summary: '各模块都很安静，享受这份平静',
      );
    }
    final summary = _renderCrossModuleSummary(moduleBriefings);
    final headline = _renderButlerHeadline(moduleBriefings);
    return ModuleBriefing(
      moduleId: ModuleId.butler,
      period: BriefingPeriod.daily,
      headline: headline,
      summary: summary,
      chips: _renderButlerChips(moduleBriefings),
      generatedAt: DateTime.now(),
      ttlSeconds: 43200, // 12h（中枢简报更频繁刷新）
    );
  }

  /// 拼发给子模型的 query（自然语言 + JSON 输出要求）。
  String _composeQuery(String moduleId, BriefingPeriod period) {
    return '请基于"$moduleId"模块的最新数据，生成${period.label}首页简报。\n'
        '\n'
        '严格按以下 JSON 输出（不要 markdown 围栏、不要任何解释文字）：\n'
        '{'
        '"headline": "<=18 字的标题，含关键数字或人名>",'
        '"summary": "<=40 字的中文叙事，1-2 句>",'
        '"chips": [{"label": "<=6 字", "value": "<=6 字"}],  // 最多 3 个 chip"'
        '}';
  }

  /// 解析子模型返回的文本 → ModuleBriefing。
  ///
  /// 容错策略：
  /// - 标准 JSON 直接 parse
  /// - 含 markdown ```json 围栏 → 剥离
  /// - 含 ```json ... ``` 块 → 抽出中间 JSON
  /// - 任意解析失败 → 返回 null（外层 fallback）
  ModuleBriefing? _parseJson(String text, String moduleId) {
    var raw = text.trim();
    if (raw.isEmpty) return null;

    // 剥离 markdown 围栏
    final fence = RegExp(r'```(?:json)?\s*\n?(.*?)\n?```', dotAll: true);
    final m = fence.firstMatch(raw);
    if (m != null) raw = m.group(1)!.trim();

    // 抽第一个 { ... } 块
    final firstBrace = raw.indexOf('{');
    final lastBrace = raw.lastIndexOf('}');
    if (firstBrace < 0 || lastBrace <= firstBrace) return null;
    final jsonStr = raw.substring(firstBrace, lastBrace + 1);

    try {
      final j = jsonDecode(jsonStr) as Map<String, dynamic>;
      final chips = (j['chips'] as List?) ?? const [];
      return ModuleBriefing(
        moduleId: moduleId,
        period: BriefingPeriod.daily,
        headline: (j['headline'] as String?)?.trim() ?? '（暂无标题）',
        summary: (j['summary'] as String?)?.trim() ?? '',
        chips: chips
            .whereType<Map>()
            .take(3)
            .map((c) => BriefingChip(
                  label: (c['label'] as String?)?.trim() ?? '',
                  value: (c['value'] as String?)?.trim() ?? '',
                ))
            .where((c) => c.label.isNotEmpty && c.value.isNotEmpty)
            .toList(growable: false),
        generatedAt: DateTime.now(),
        ttlSeconds: 86400,
      );
    } catch (e) {
      debugPrint('BriefingGenerator: JSON parse failed - $e\nraw: $jsonStr');
      return null;
    }
  }

  /// 模块 fallback 标题（解析失败时显示，UI 还能识别模块）。
  String _fallbackHeadline(String moduleId) {
    switch (moduleId) {
      case ModuleId.relationship:
        return '关系网需要你关注';
      case ModuleId.growth:
        return '目标在等你推进';
      case ModuleId.wealth:
        return '账单需要你核对';
      case ModuleId.thought:
        return '想法还没整理';
      case ModuleId.health:
        return '身体信号未追踪';
      default:
        return '（暂无简报）';
    }
  }

  /// 中枢 head 标题：突出"待你决定" / "待办" 数量。
  String _renderButlerHeadline(List<ModuleBriefing> bs) {
    final counts = <String, int>{};
    for (final b in bs) {
      // 收集 chip 中的数字
      for (final c in b.chips) {
        final n = _extractNumber(c.value);
        if (n > 0) counts['${b.moduleId}:${c.label}'] = n;
      }
    }
    if (counts.isEmpty) {
      return '今天有 0 件无法决定';
    }
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    return '今天有 $total 件需要你决定';
  }

  /// 中枢 summary：聚合 5 模块前 1-2 条最有信号的简报。
  String _renderCrossModuleSummary(List<ModuleBriefing> bs) {
    final lines = <String>[];
    for (final b in bs) {
      if (b.summary.isEmpty) continue;
      lines.add('• ${b.summary}');
      if (lines.length >= 3) break;
    }
    if (lines.isEmpty) return '各模块暂时都很安静';
    return lines.join('\n');
  }

  /// 中枢 chips：聚合最多 3 个最紧急的 chip。
  List<BriefingChip> _renderButlerChips(List<ModuleBriefing> bs) {
    final chips = <BriefingChip>[];
    for (final b in bs) {
      for (final c in b.chips) {
        chips.add(BriefingChip(
          label: c.label,
          value: '${b.moduleId.substring(0, 1).toUpperCase()}·${c.value}',
        ));
        if (chips.length >= 3) return chips;
      }
    }
    return chips;
  }

  int _extractNumber(String s) {
    final m = RegExp(r'\d+').firstMatch(s);
    return m == null ? 0 : int.parse(m.group(0)!);
  }
}
