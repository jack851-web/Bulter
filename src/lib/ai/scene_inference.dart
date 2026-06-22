import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'model_registry.dart';
import 'tools/tool_registry.dart';

/// 场景推理（Step 10）—— **主模型多模态 + tool_calls**。
///
/// **架构原则**（[doc/first/02-requirements.md §九](file:///d:/others/app/Bulter/doc/first/02-requirements.md)）：
/// - 截图归类**完全由主模型（多模态 LLM）完成**
/// - 主模型看图 → 选工具 → **直接调工具**写入数据库（关系/财富/思想/健康）
/// - **不调子模型**——子模型仅作为子模块内部信息处理者（供应简报）
///
/// **降级策略**：
/// 1. **首选**：调主模型多模态 → 解析 `tool_calls` → 执行 ToolRegistry 工具
/// 2. **降级**：主模型返回非 JSON / tool_calls 为空 → 返回 [SceneInference.failure]
/// 3. **降级**：主模型 API Key 未配置 → 立即返回失败（**不**降级到启发式）
///
/// **不抛错**：所有路径返回 [SceneInference] 实例。
class SceneInferencer {
  SceneInferencer._();
  static final SceneInferencer instance = SceneInferencer._();

  /// 调主模型多模态看截图 + 选工具 + 调工具。
  ///
  /// - [thumbPath]：截图本地路径（**完整图**，不是缩略图；Kotlin 端已经只保存了
  ///   ≤ 原图，缩略图由 Dart 端按需生成）
  /// - [timeout]：默认 8 秒（主模型推理 + 工具执行总时间）
  Future<SceneInference> inferFromScreenshot(
    String thumbPath, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final cfg = ModelRegistry.instance.active;
    if (cfg.apiKey.isEmpty) {
      return SceneInference.failure(
        error: 'no_api_key',
        summary: '尚未配置 API Key。请到 设置 → 模型 中填入。',
      );
    }
    final file = File(thumbPath);
    if (!file.existsSync()) {
      return SceneInference.failure(
        error: 'file_not_found',
        summary: '截图文件不存在',
      );
    }

    try {
      final imageBase64 = base64Encode(await file.readAsBytes());
      final endpoint = '${cfg.baseUrl}/${cfg.chatPath}'.replaceAll('//', '/');
      final url = cfg.baseUrl.endsWith('/')
          ? '${cfg.baseUrl}${cfg.chatPath}'
          : endpoint;

      final body = <String, dynamic>{
        'model': cfg.model,
        'messages': [
          {'role': 'system', 'content': _systemPrompt()},
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': _userPrompt()},
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$imageBase64'},
              },
            ],
          },
        ],
        'tools': ToolRegistry.instance.getJsonSchemas(),
        'tool_choice': 'auto',
        'temperature': 0.2,
        'max_tokens': 600,
      };

      final response = await Dio().post<Map<String, dynamic>>(
        url,
        data: body,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${cfg.apiKey}',
          },
          responseType: ResponseType.json,
          receiveTimeout: timeout,
          sendTimeout: timeout,
        ),
      );

      if (response.statusCode == null || response.statusCode! >= 300) {
        return SceneInference.failure(
          error: 'http_${response.statusCode ?? "unknown"}',
          summary: '主模型调用失败',
        );
      }
      final json = response.data;
      if (json == null) {
        return SceneInference.failure(error: 'empty_body', summary: '主模型返回空');
      }
      return _parseAndExecute(json);
    } on DioException catch (e) {
      debugPrint('SceneInferencer: Dio 异常 - ${e.type} ${e.message}');
      return SceneInference.failure(
        error: 'dio_${e.type.name}',
        summary: '主模型网络异常',
      );
    } catch (e, st) {
      debugPrint('SceneInferencer: 异常 - $e\n$st');
      return SceneInference.failure(
        error: e.runtimeType.toString(),
        summary: '未知异常',
      );
    }
  }

  /// 解析主模型响应 → 执行 tool_calls。
  Future<SceneInference> _parseAndExecute(Map<String, dynamic> response) async {
    final choice = (response['choices'] as List?)?.firstOrNull as Map?;
    if (choice == null) {
      return SceneInference.failure(
        error: 'no_choice',
        summary: '主模型返回无 choices',
      );
    }
    final message = (choice as Map)['message'] as Map?;
    if (message == null) {
      return SceneInference.failure(
        error: 'no_message',
        summary: '主模型返回无 message',
      );
    }

    final toolCallsRaw = message['tool_calls'] as List?;
    final contentText = (message['content'] as String?) ?? '';

    // 1) 解析 tool_calls
    final parsed = <_ParsedToolCall>[];
    if (toolCallsRaw != null) {
      for (final raw in toolCallsRaw) {
        try {
          final m = raw as Map;
          final fn = m['function'] as Map?;
          if (fn == null) continue;
          final name = fn['name'] as String?;
          if (name == null) continue;
          final argsStr = (fn['arguments'] as String?) ?? '{}';
          Map<String, dynamic> args;
          try {
            args = (jsonDecode(argsStr) as Map).cast<String, dynamic>();
          } catch (_) {
            args = <String, dynamic>{};
          }
          parsed.add(_ParsedToolCall(name: name, arguments: args));
        } catch (e) {
          debugPrint('SceneInferencer: 解析 tool_call 失败 - $e');
        }
      }
    }

    // 2) 顺序执行工具
    final executed = <ToolExecutionResult>[];
    if (parsed.isEmpty) {
      // 没选工具 → fallback 到主模型文本摘要
      return SceneInference.noTools(summary: contentText.trim());
    }
    for (final tc in parsed) {
      final result = await ToolRegistry.instance.execute(tc.name, tc.arguments);
      executed.add(
        ToolExecutionResult(
          toolName: tc.name,
          ok: result.status == 'ok',
          summary: result.summary,
          data: result.data,
        ),
      );
    }

    // 3) 拼装最终结果
    final ok = executed.any((e) => e.ok);
    final moduleLabel = _summarizeModules(executed);
    return SceneInference(
      ok: ok,
      toolCalls: executed,
      summary: contentText.trim().isNotEmpty
          ? contentText.trim()
          : (ok ? '已记录到 $moduleLabel' : '未识别可用工具'),
      moduleLabel: moduleLabel,
    );
  }

  String _systemPrompt() =>
      '你是 Bulter 的视觉助理。看到截图后判断场景，并直接调用对应的工具把信息记录下来。\n'
      '\n'
      '工具列表已通过 `tools` 参数提供（relationship.add_contact / '
      'relationship.add_interaction / wealth.add_transaction / thought.save / '
      'health.add_record 等）。请根据截图内容**选择 1-3 个最合适的工具**并调用。\n'
      '\n'
      '**优先级**：\n'
      '1. 聊天截图（含联系人名）→ relationship.add_contact + relationship.add_interaction\n'
      '2. 账单截图（含金额）→ wealth.add_transaction\n'
      '3. 文章 / 笔记截图 → thought.save\n'
      '4. 健康数据截图 → health.add_record\n'
      '5. 没有合适工具 → 直接用自然语言回答用户看到了什么\n'
      '\n'
      '**输出**：直接返回 tool_calls（不要解释）';

  String _userPrompt() => '请分析这张截图并按需调用工具。如果没有任何合适的工具，告诉我你看到了什么。';

  /// 从执行结果里提取模块名（用于"已记录到 X 模块"通知）。
  String _summarizeModules(List<ToolExecutionResult> results) {
    final modules = <String>{};
    for (final r in results.where((e) => e.ok)) {
      final m = _moduleOfTool(r.toolName);
      if (m != null) modules.add(m);
    }
    if (modules.isEmpty) return 'Bulter';
    if (modules.length == 1) return modules.first;
    return modules.join(' / ');
  }

  String? _moduleOfTool(String toolName) {
    if (toolName.startsWith('relationship.')) return '关系';
    if (toolName.startsWith('wealth.')) return '财富';
    if (toolName.startsWith('growth.')) return '成长';
    if (toolName.startsWith('thought.')) return '思想';
    if (toolName.startsWith('health.')) return '健康';
    return null;
  }
}

class _ParsedToolCall {
  final String name;
  final Map<String, dynamic> arguments;
  _ParsedToolCall({required this.name, required this.arguments});
}

/// 单个工具执行结果（给 UI / log 用）。
class ToolExecutionResult {
  final String toolName;
  final bool ok;
  final String summary;
  final Map<String, dynamic> data;
  const ToolExecutionResult({
    required this.toolName,
    required this.ok,
    required this.summary,
    required this.data,
  });
}

/// 场景推理最终结果。
class SceneInference {
  final bool ok;
  final List<ToolExecutionResult> toolCalls;
  final String summary;
  final String? moduleLabel;
  final String? error;

  const SceneInference({
    required this.ok,
    required this.toolCalls,
    required this.summary,
    this.moduleLabel,
    this.error,
  });

  factory SceneInference.failure({
    required String error,
    required String summary,
  }) => SceneInference(
    ok: false,
    toolCalls: const [],
    summary: summary,
    error: error,
  );

  factory SceneInference.noTools({required String summary}) => SceneInference(
    ok: false,
    toolCalls: const [],
    summary: summary,
    error: 'no_tools_called',
  );

  /// 至少有一个工具执行成功。
  bool get hasSuccess => toolCalls.any((t) => t.ok);
}
