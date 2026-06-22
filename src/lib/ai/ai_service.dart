import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'memory/long_term.dart';
import 'memory/memory_manager.dart';
import 'memory/short_term.dart';
import 'model_registry.dart';
import 'rag/context_injector.dart';
import 'rag/embedder.dart';
import 'rag/retriever.dart';
import 'tools/relationship_tools.dart';
import 'tools/wealth_tools.dart';
import 'tools/thought_tools.dart';
import 'tools/health_tools.dart';
import 'tools/growth_tools.dart';
import 'tools/tool_registry.dart';

/// 流式 chunk / 工具事件 回调。
typedef StreamCallback = void Function(ChatStreamEvent event);

class ChatStreamEvent {
  final String delta;
  final bool done;
  final Object? error;
  final int? statusCode;
  final List<PendingToolCall> toolCalls;
  final List<ToolRunResult> toolResults;

  /// 本轮 RAG 注入的记忆条数（> 0 时仅触发一次，UI 状态条用）。
  final int ragInjectedCount;

  /// 长记忆抽取结果（> 0 时仅触发一次，UI 状态条用）。
  final ExtractResult? extractResult;

  const ChatStreamEvent({
    this.delta = '',
    this.done = false,
    this.error,
    this.statusCode,
    this.toolCalls = const [],
    this.toolResults = const [],
    this.ragInjectedCount = 0,
    this.extractResult,
  });

  bool get isError => error != null;
  bool get hasToolCalls => toolCalls.isNotEmpty;
  bool get hasToolResults => toolResults.isNotEmpty;
}

/// LLM 一次响应中解析到的工具调用。
class PendingToolCall {
  final int index;
  final String id;
  final String name;
  final String argumentsJson;

  const PendingToolCall({
    required this.index,
    required this.id,
    required this.name,
    required this.argumentsJson,
  });

  Map<String, dynamic> parsedArgs() {
    try {
      return jsonDecode(argumentsJson) as Map<String, dynamic>;
    } catch (_) {
      return const {};
    }
  }
}

/// 工具执行结果（用于 UI 显示 + 回传给 LLM）。
class ToolRunResult {
  final String toolCallId;
  final String toolName;
  final ToolResult result;

  const ToolRunResult({
    required this.toolCallId,
    required this.toolName,
    required this.result,
  });
}

/// 单次 LLM 调用的可选项。
class ChatOptions {
  final double? temperature;
  final int? maxTokens;
  final bool stream;
  final Map<String, dynamic> extra;
  final Map<String, String> extraHeaders;
  final List<String> stop;

  /// 工具 JSON Schema 列表（OpenAI Function Calling 格式）。
  /// 传空 = 由 [toolRegistry] 自动提供。
  final List<Map<String, dynamic>> tools;

  /// 是否启用 ReAct 多轮：true 时遇到 tool_calls 自动执行并回传。
  final bool reactLoop;

  /// ReAct 最大轮数（防止死循环），默认 5。
  final int maxReactRounds;

  /// 自定义工具注册表（默认用全局 [ToolRegistry.instance]）。
  final ToolRegistry? toolRegistry;

  /// **Step 11**：额外 system prompt（拼接到 buildEnhancedSystemPrompt 之后）。
  /// 用于跨会话上下文注入（不污染 RAG 注入的 system prompt）。
  final String? extraSystemPrompt;

  const ChatOptions({
    this.temperature,
    this.maxTokens,
    this.stream = true,
    this.extra = const {},
    this.extraHeaders = const {},
    this.stop = const [],
    this.tools = const [],
    this.reactLoop = true,
    this.maxReactRounds = 5,
    this.toolRegistry,
    this.extraSystemPrompt,
  });
}

/// AI Service：流式 + ReAct 多轮 + 短记忆。
class AiService {
  AiService._();
  static final AiService instance = AiService._();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(minutes: 2),
      sendTimeout: const Duration(seconds: 15),
    ),
  );

  /// 数据库绑定（被 chat_page / app_bootstrap 调用）。
  /// 真实类型 [AppDatabase]，但本类不直接 import 以减少耦合。
  static dynamic _boundDb;
  static void bindDatabase(dynamic db) {
    _boundDb = db;
  }

  /// RAG / 长期记忆 绑定（被 app_bootstrap 调用）。
  static RagBundle? _rag;
  static RagBundle? get rag => _rag;
  static void bindRag(RagBundle bundle) {
    _rag = bundle;
  }

  /// 内部使用的 system 提示模板。
  static const String systemPromptTemplate =
      '你是 Bulter —— 一个本地优先、长期记忆的个人 AI 管家。'
      '回答要简洁、像朋友聊天，不浮夸、不滥用 Markdown。'
      '如果用户记了一笔账 / 一次互动 / 一条想法，简单确认即可。'
      '不知道的事情直接说不知道，不要编造。'
      '当用户希望"操作数据"时，优先调用合适的工具。'
      '当工具返回 status=pending_confirmation 时，把确认提示原样展示给用户，并等待用户确认。';

  String buildSystemPrompt(ShortTermMemory memory) => systemPromptTemplate;

  /// 构造增强后的 system prompt（含 RAG 注入）。每次调用前都重新生成。
  ///
  /// Step 7：优先走 `MemoryManager.buildSystemPrompt`，把"用户画像 + 工作记忆
  /// + RAG"一并注入。RAG 未绑定时退化为旧路径。
  Future<String> buildEnhancedSystemPrompt(ShortTermMemory memory) async {
    final manager = _rag?.memory;
    if (manager != null) {
      try {
        final prompt = await manager.buildSystemPrompt(memory);
        // 同步 lastInjectedCount（UI 用）
        _lastInjectedForUi = manager.injector.lastInjectedCount;
        return prompt;
      } catch (e, st) {
        debugPrint('AiService.buildEnhancedSystemPrompt (manager) 失败: $e\n$st');
        // 降级：走旧路径
      }
    }
    final base = buildSystemPrompt(memory);
    final injector = _rag?.injector;
    if (injector == null) return base;
    try {
      final p = await injector.build(baseSystemPrompt: base, memory: memory);
      _lastInjectedForUi = injector.lastInjectedCount;
      return p;
    } catch (e, st) {
      debugPrint('AiService.buildEnhancedSystemPrompt 失败: $e\n$st');
      return base;
    }
  }

  int _lastInjectedForUi = 0;
  int get lastInjectedCount => _lastInjectedForUi;

  /// 发起一次流式对话（含 ReAct 循环）。
  Future<void> streamCompletion({
    required ShortTermMemory memory,
    required StreamCallback callback,
    ChatOptions options = const ChatOptions(),
  }) async {
    final cfg = ModelRegistry.instance.active;
    if (cfg.apiKey.isEmpty) {
      callback(
        ChatStreamEvent(
          done: true,
          error: AiError(AiErrorKind.noApiKey, '尚未配置 API Key。请到 设置 → 模型 中填入。'),
        ),
      );
      return;
    }

    // 注入 RAG 上下文（每次都重建，确保最新）
    var systemPrompt = await buildEnhancedSystemPrompt(memory);
    // Step 11：附加跨会话上下文（如果有）
    final extra = options.extraSystemPrompt;
    if (extra != null && extra.isNotEmpty) {
      systemPrompt = '$systemPrompt\n\n$extra';
    }
    if (memory.messages.any((m) => m.role == ChatRole.system)) {
      // 替换已有 system 消息（保留 role / 时间戳）
      final idx = memory.messages.indexWhere((m) => m.role == ChatRole.system);
      if (idx >= 0) {
        final old = memory.messages[idx];
        memory.messages[idx] = ChatMessage(
          role: ChatRole.system,
          content: systemPrompt,
          createdAt: old.createdAt,
        );
      }
    } else {
      memory.addSystem(systemPrompt);
    }

    // 通知 UI：本次注入了多少条记忆（用于状态条）。传递一个非 done 的小事件。
    final injected = _rag?.injector?.lastInjectedCount ?? 0;
    if (injected > 0) {
      callback(
        ChatStreamEvent(
          delta: '',
          done: false,
          error: null,
          statusCode: null,
          toolCalls: const [],
          toolResults: const [],
          ragInjectedCount: injected,
        ),
      );
    }

    final registry = options.toolRegistry ?? ToolRegistry.instance;
    final useTools = options.tools.isNotEmpty || registry.getTools().isNotEmpty;
    final tools = options.tools.isNotEmpty
        ? options.tools
        : (useTools
              ? registry.getJsonSchemas()
              : const <Map<String, dynamic>>[]);

    int round = 0;
    while (round < options.maxReactRounds + 1) {
      round++;
      final body = <String, dynamic>{
        'model': cfg.model,
        'messages': memory.toLlmMessages(),
        'stream': options.stream,
        if (options.temperature != null) 'temperature': options.temperature,
        if (options.maxTokens != null) 'max_tokens': options.maxTokens,
        if (options.stop.isNotEmpty) 'stop': options.stop,
        if (tools.isNotEmpty) 'tools': tools,
        ...options.extra,
      };
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        ..._authHeader(cfg),
        ...options.extraHeaders,
      };
      final url = cfg.baseUrl.endsWith('/')
          ? '${cfg.baseUrl}${cfg.chatPath}'
          : '${cfg.baseUrl}/${cfg.chatPath}';

      String accumulated = '';
      final toolAccum = <int, _ToolAccum>{};
      try {
        final response = await _dio.post<ResponseBody>(
          url,
          data: body,
          options: Options(
            headers: headers,
            responseType: ResponseType.stream,
            validateStatus: (_) => true,
          ),
        );
        final code = response.statusCode ?? 0;
        if (code < 200 || code >= 300) {
          final raw = await _readAllUtf8(response.data);
          callback(
            ChatStreamEvent(
              done: true,
              statusCode: code,
              error: AiError.fromHttp(code, raw),
            ),
          );
          return;
        }
        final respBody = response.data;
        if (respBody == null) {
          callback(const ChatStreamEvent(done: true));
          return;
        }
        String pending = '';
        await for (final chunk in respBody.stream) {
          pending += utf8.decode(chunk, allowMalformed: true);
          var idx = pending.indexOf('\n\n');
          while (idx >= 0) {
            final event = pending.substring(0, idx);
            pending = pending.substring(idx + 2);
            _handleSseEvent(event, (delta) {
              if (delta.isNotEmpty) {
                accumulated += delta;
                memory.updateLastAssistantContent(delta);
                callback(ChatStreamEvent(delta: delta));
              }
            }, toolAccum);
            idx = pending.indexOf('\n\n');
          }
        }
        if (pending.trim().isNotEmpty) {
          _handleSseEvent(pending, (_) {}, toolAccum);
        }
      } on DioException catch (e) {
        callback(
          ChatStreamEvent(
            done: true,
            error: AiError(AiErrorKind.network, e.message ?? '网络异常，请检查连接后重试'),
          ),
        );
        return;
      } catch (e, st) {
        debugPrint('AiService.streamCompletion 未知异常: $e\n$st');
        callback(
          ChatStreamEvent(
            done: true,
            error: AiError(AiErrorKind.unknown, e.toString()),
          ),
        );
        return;
      }

      // 写 assistant 消息到记忆
      if (accumulated.isNotEmpty || toolAccum.isNotEmpty) {
        _appendAssistantWithTools(memory, accumulated, toolAccum);
      }

      // 没有 tool_calls → 正常结束
      if (toolAccum.isEmpty) {
        await _maybeExtractLongTerm(memory, callback);
        callback(ChatStreamEvent(done: true));
        return;
      }

      // 有 tool_calls → 通知 UI + 执行
      final calls = toolAccum.values.toList()
        ..sort((a, b) => a.index.compareTo(b.index));
      final pendingCalls = calls
          .map(
            (a) => PendingToolCall(
              index: a.index,
              id: a.id,
              name: a.name,
              argumentsJson: a.argsJson,
            ),
          )
          .toList();
      callback(ChatStreamEvent(toolCalls: pendingCalls));

      if (!options.reactLoop) {
        callback(ChatStreamEvent(done: true));
        return;
      }

      // 执行
      final results = <ToolRunResult>[];
      for (final c in pendingCalls) {
        final r = await registry.execute(c.name, c.parsedArgs());
        results.add(
          ToolRunResult(toolCallId: c.id, toolName: c.name, result: r),
        );
        _appendToolMessage(memory, c.id, r);
      }
      callback(ChatStreamEvent(toolResults: results));

      // 有 pending_confirmation：暂停，等用户确认
      if (results.any((r) => r.result.needsConfirmation)) {
        callback(ChatStreamEvent(done: true, toolResults: results));
        return;
      }

      if (round > options.maxReactRounds) {
        callback(
          ChatStreamEvent(
            done: true,
            error: AiError(
              AiErrorKind.unknown,
              'ReAct 循环超过最大轮数 (${options.maxReactRounds})',
            ),
          ),
        );
        return;
      }
    }
  }

  /// 用户在弹窗上点击确认 / 取消后，调用此方法：
  /// - 执行真正的删除 / 写入 tool 消息
  /// - 继续 streamCompletion 让 LLM 给出最终回复
  Future<void> resumeAfterConfirmation({
    required ShortTermMemory memory,
    required String toolCallId,
    required String toolName,
    required Map<String, dynamic> originalArgs,
    required bool confirmed,
    required ChatOptions options,
    required StreamCallback callback,
  }) async {
    ToolResult r;
    if (confirmed) {
      r = await _executeConfirmedDelete(toolName: toolName, args: originalArgs);
    } else {
      r = const ToolResult(status: 'cancelled', summary: '用户已取消该操作');
    }
    _appendToolMessage(memory, toolCallId, r);
    callback(
      ChatStreamEvent(
        toolResults: [
          ToolRunResult(toolCallId: toolCallId, toolName: toolName, result: r),
        ],
      ),
    );
    // 继续：但不再开启新工具
    await streamCompletion(
      memory: memory,
      callback: callback,
      options: ChatOptions(
        temperature: options.temperature,
        maxTokens: options.maxTokens,
        stream: options.stream,
        tools: const [],
        reactLoop: false,
        maxReactRounds: 0,
        toolRegistry: options.toolRegistry,
      ),
    );
  }

  /// 完成 delete_* 工具的真实执行。
  Future<ToolResult> _executeConfirmedDelete({
    required String toolName,
    required Map<String, dynamic> args,
  }) async {
    final db = _boundDb;
    if (db == null) return ToolResult.error('数据库未初始化');
    final id = args['id'] as int?;
    if (id == null) return ToolResult.error('缺少 id');
    switch (toolName) {
      case 'delete_contact':
        return RelationshipTools.confirmDeleteContact(db.relationshipDao, id);
      case 'delete_interaction':
        return RelationshipTools.confirmDeleteInteraction(
          db.relationshipDao,
          id,
        );
      case 'delete_favor':
        return RelationshipTools.confirmDeleteFavor(db.relationshipDao, id);
      case 'delete_thought':
        return ThoughtTools.confirmDeleteThought(db.thoughtDao, id);
      case 'delete_letter':
        return ThoughtTools.confirmDeleteLetter(db.thoughtDao, id);
      case 'delete_health_record':
        return HealthTools.confirmDeleteRecord(db.healthDao, id);
      case 'delete_goal':
        return GrowthTools.confirmDeleteGoal(db.growthDao, id);
      default:
        return ToolResult.error('未实现的二次确认工具：$toolName');
    }
  }

  Map<String, String> _authHeader(ModelConfig cfg) {
    switch (cfg.authScheme) {
      case AuthScheme.bearer:
        return {'Authorization': 'Bearer ${cfg.apiKey}'};
      case AuthScheme.xApiKey:
        return {'x-api-key': cfg.apiKey, 'anthropic-version': '2023-06-01'};
      case AuthScheme.googleQuery:
        return {'x-goog-api-key': cfg.apiKey};
    }
  }

  void _handleSseEvent(
    String event,
    void Function(String delta) onDelta,
    Map<int, _ToolAccum> toolAccum,
  ) {
    final dataLines = event
        .split('\n')
        .where((l) => l.startsWith('data:'))
        .map((l) => l.substring(5).trimLeft())
        .toList();
    if (dataLines.isEmpty) return;
    final raw = dataLines.join('\n').trim();
    if (raw.isEmpty || raw == '[DONE]') return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) return;
      final first = choices.first as Map<String, dynamic>;
      final delta = first['delta'] as Map<String, dynamic>?;
      final content = delta?['content'] as String?;
      if (content != null && content.isNotEmpty) {
        onDelta(content);
      }
      final tcs = delta?['tool_calls'] as List<dynamic>?;
      if (tcs != null) {
        for (final raw in tcs) {
          final tc = raw as Map<String, dynamic>;
          final idx = (tc['index'] as int?) ?? 0;
          final acc = toolAccum.putIfAbsent(idx, () => _ToolAccum(index: idx));
          if (tc['id'] is String) acc.id = tc['id'] as String;
          final fn = tc['function'] as Map<String, dynamic>?;
          if (fn != null) {
            if (fn['name'] is String) acc.name = (fn['name'] as String);
            if (fn['arguments'] is String) {
              acc.argsJson = (acc.argsJson) + (fn['arguments'] as String);
            }
          }
        }
      }
    } catch (_) {
      // 忽略解析失败
    }
  }

  /// 把 assistant 消息（含可选 tool_calls 编码）追加到 short_term。
  void _appendAssistantWithTools(
    ShortTermMemory memory,
    String content,
    Map<int, _ToolAccum> toolAccum,
  ) {
    String encoded = content;
    if (toolAccum.isNotEmpty) {
      final tcs = [
        for (final t in toolAccum.values)
          {
            'id': t.id,
            'type': 'function',
            'function': {'name': t.name, 'arguments': t.argsJson},
          },
      ];
      encoded = '$content\n[tool_calls]${jsonEncode(tcs)}';
    }
    memory.append(
      ChatMessage(
        role: ChatRole.assistant,
        content: encoded,
        createdAt: DateTime.now(),
      ),
    );
  }

  void _appendToolMessage(
    ShortTermMemory memory,
    String toolCallId,
    ToolResult result,
  ) {
    final body = jsonEncode({
      'status': result.status,
      'summary': result.summary,
      'data': result.data,
    });
    memory.append(
      ChatMessage(
        role: ChatRole.tool,
        content: '$toolCallId|$body',
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<String> _readAllUtf8(ResponseBody? body) async {
    if (body == null) return '';
    final buf = <int>[];
    await for (final c in body.stream) {
      buf.addAll(c);
    }
    return utf8.decode(buf, allowMalformed: true);
  }

  /// 单次非流式（Step 5 内部用，预留）。
  Future<String> completion({
    required ShortTermMemory memory,
    ChatOptions options = const ChatOptions(),
  }) async {
    final cfg = ModelRegistry.instance.active;
    if (cfg.apiKey.isEmpty) {
      throw AiError(AiErrorKind.noApiKey, '尚未配置 API Key');
    }
    if (!memory.messages.any((m) => m.role == ChatRole.system)) {
      memory.addSystem(buildSystemPrompt(memory));
    }
    final body = {
      'model': cfg.model,
      'messages': memory.toLlmMessages(),
      'stream': false,
      if (options.temperature != null) 'temperature': options.temperature,
      if (options.maxTokens != null) 'max_tokens': options.maxTokens,
      if (options.stop.isNotEmpty) 'stop': options.stop,
      ...options.extra,
    };
    final resp = await _dio.post<Map<String, dynamic>>(
      cfg.baseUrl.endsWith('/')
          ? '${cfg.baseUrl}${cfg.chatPath}'
          : '${cfg.baseUrl}/${cfg.chatPath}',
      data: body,
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          ..._authHeader(cfg),
          ...options.extraHeaders,
        },
        responseType: ResponseType.json,
      ),
    );
    final data = resp.data;
    if (data == null) throw AiError(AiErrorKind.unknown, '空响应');
    final choices = data['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw AiError(AiErrorKind.parse, '响应缺少 choices');
    }
    final first = choices.first as Map<String, dynamic>;
    final msg = first['message'] as Map<String, dynamic>?;
    return (msg?['content'] as String?) ?? '';
  }

  /// 长记忆抽取（Step 6）。
  ///
  /// - 增量计数（[LongTermMemory.shouldExtract]），到阈值才真正执行
  /// - 失败 / 不可用时**不**阻塞主流程
  Future<void> _maybeExtractLongTerm(
    ShortTermMemory memory,
    StreamCallback callback,
  ) async {
    final longTerm = _rag?.longTerm;
    if (longTerm == null) return;
    try {
      final result = await longTerm.maybeExtract(memory: memory);
      if (result.hasChanges) {
        callback(
          ChatStreamEvent(
            delta: '',
            done: false,
            error: null,
            statusCode: null,
            toolCalls: const [],
            toolResults: const [],
            extractResult: result,
          ),
        );
      }
    } catch (e, st) {
      debugPrint('AiService._maybeExtractLongTerm 失败: $e\n$st');
    }
  }
}

/// RAG / 长期记忆 总线：
/// - [injector] 把检索结果注入 system prompt
/// - [longTerm] 在每 N 轮对话后从历史里抽取事实写入向量库
/// - [memory] 4 层记忆统一管理器（Step 7：用户画像 + 工作记忆 + RAG + 短记忆）
class RagBundle {
  final ContextInjector injector;
  final LongTermMemory longTerm;
  final MemoryManager? memory;
  RagBundle({required this.injector, required this.longTerm, this.memory});
}

class _ToolAccum {
  final int index;
  String id = '';
  String name = '';
  String argsJson = '';
  _ToolAccum({required this.index});
}

class AiError implements Exception {
  final AiErrorKind kind;
  final String message;
  AiError(this.kind, this.message);

  factory AiError.fromHttp(int code, String body) {
    if (code == 401 || code == 403) {
      return AiError(AiErrorKind.auth, '鉴权失败（$code），请检查 API Key');
    }
    if (code == 429) {
      return AiError(AiErrorKind.rateLimit, '请求过于频繁（429），稍后再试');
    }
    if (code == 404) {
      return AiError(AiErrorKind.notFound, '模型不存在（404），请检查模型名');
    }
    if (code == 400) {
      return AiError(AiErrorKind.badRequest, '请求参数错误（400）');
    }
    if (code >= 500) {
      return AiError(AiErrorKind.server, '服务端异常（$code），稍后再试');
    }
    return AiError(AiErrorKind.unknown, 'HTTP $code');
  }

  @override
  String toString() => 'AiError($kind, $message)';
}

enum AiErrorKind {
  noApiKey,
  auth,
  rateLimit,
  badRequest,
  notFound,
  server,
  network,
  parse,
  unknown,
}
