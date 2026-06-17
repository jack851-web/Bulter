import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'memory/short_term.dart';
import 'model_registry.dart';

/// 流式 chunk 回调。
///
/// [delta] 为本次服务端增量文本；[done] 表示本次流结束（正常或异常）；
/// [error] 非空表示发生错误（网络 / 鉴权 / 速率等）。
typedef StreamCallback = void Function(ChatStreamEvent event);

class ChatStreamEvent {
  final String delta;
  final bool done;
  final Object? error;
  final int? statusCode;

  const ChatStreamEvent({
    this.delta = '',
    this.done = false,
    this.error,
    this.statusCode,
  });

  bool get isError => error != null;
}

/// 单次 LLM 调用的可选项。
class ChatOptions {
  /// 温度（0-2）。null 时由模型默认。
  final double? temperature;

  /// 最大输出 tokens。null 时由模型默认。
  final int? maxTokens;

  /// 是否流式（Step 4 默认 true；Step 5 tool 链路可临时关）
  final bool stream;

  /// 透传给 body 的额外字段
  final Map<String, dynamic> extra;

  /// 透传给 header 的额外字段
  final Map<String, String> extraHeaders;

  /// 停止词
  final List<String> stop;

  const ChatOptions({
    this.temperature,
    this.maxTokens,
    this.stream = true,
    this.extra = const {},
    this.extraHeaders = const {},
    this.stop = const [],
  });
}

/// AI Service：流式调用 + 短记忆。
///
/// Step 4 范围：
/// - 单 LLM 对话（OpenAI Chat Completions 兼容协议）
/// - SSE 流式增量推送
/// - 短记忆（[ShortTermMemory]）拼接到请求
/// - 友好错误分类（无 key / 鉴权失败 / 速率 / 网络 / 模型不存在 / 解析）
///
/// Step 5 范围（接口已留位，不实现）：
/// - tool_calls 累积 + ReAct 循环
/// - 主模型调度子 Agent
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

  /// 内部使用的 system 提示模板。
  static const String systemPromptTemplate =
      '你是 Bulter —— 一个本地优先、长期记忆的个人 AI 管家。'
      '回答要简洁、像朋友聊天，不浮夸、不滥用 Markdown。'
      '如果用户记了一笔账 / 一次互动 / 一条想法，简单确认即可。'
      '不知道的事情直接说不知道，不要编造。';

  /// 给定 memory 拼装 system 提示（Step 7 之后会注入 RAG 片段）。
  String buildSystemPrompt(ShortTermMemory memory) {
    return systemPromptTemplate;
  }

  /// 发起一次流式对话。
  ///
  /// 流程：
  /// 1) 校验 model + apiKey
  /// 2) 拼装 messages（含 system）
  /// 3) POST `{baseUrl}/{chatPath}` with `stream: true`
  /// 4) 解析 SSE `data: {json}`，回调 [callback]
  /// 5) 流结束回调 `done: true` 或 `error: <分类>`
  Future<void> streamCompletion({
    required ShortTermMemory memory,
    required StreamCallback callback,
    ChatOptions options = const ChatOptions(),
  }) async {
    final cfg = ModelRegistry.instance.active;

    // 1) 前置校验
    if (cfg.apiKey.isEmpty) {
      callback(
        ChatStreamEvent(
          done: true,
          error: AiError(AiErrorKind.noApiKey, '尚未配置 API Key。请到 设置 → 模型 中填入。'),
        ),
      );
      return;
    }

    // 2) system 注入
    if (!memory.messages.any((m) => m.role == ChatRole.system)) {
      memory.addSystem(buildSystemPrompt(memory));
    }

    final messages = memory.toLlmMessages();
    final body = <String, dynamic>{
      'model': cfg.model,
      'messages': messages,
      'stream': options.stream,
      if (options.temperature != null) 'temperature': options.temperature,
      if (options.maxTokens != null) 'max_tokens': options.maxTokens,
      if (options.stop.isNotEmpty) 'stop': options.stop,
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
        // 尝试读出错 body 提取 message
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

      // 3) SSE 解析：按 \n\n 分块，逐行解析 `data: ` 行
      String pending = '';
      await for (final chunk in respBody.stream) {
        pending += utf8.decode(chunk, allowMalformed: true);
        var idx = pending.indexOf('\n\n');
        while (idx >= 0) {
          final event = pending.substring(0, idx);
          pending = pending.substring(idx + 2);
          _handleSseEvent(event, callback);
          idx = pending.indexOf('\n\n');
        }
      }
      // 收尾：残余 chunk（不带 \n\n 结尾）
      if (pending.trim().isNotEmpty) {
        _handleSseEvent(pending, callback);
      }

      callback(const ChatStreamEvent(done: true));
    } on DioException catch (e) {
      callback(
        ChatStreamEvent(
          done: true,
          error: AiError(AiErrorKind.network, e.message ?? '网络异常，请检查连接后重试'),
        ),
      );
    } catch (e, st) {
      debugPrint('AiService.streamCompletion 未知异常: $e\n$st');
      callback(
        ChatStreamEvent(
          done: true,
          error: AiError(AiErrorKind.unknown, e.toString()),
        ),
      );
    }
  }

  /// 单次非流式调用（Step 5 内部用，预留）。
  Future<String> completion({
    required ShortTermMemory memory,
    ChatOptions options = const ChatOptions(stream: false),
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
    if (data == null) {
      throw AiError(AiErrorKind.unknown, '空响应');
    }
    final choices = data['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw AiError(AiErrorKind.parse, '响应缺少 choices');
    }
    final first = choices.first as Map<String, dynamic>;
    final msg = first['message'] as Map<String, dynamic>?;
    return (msg?['content'] as String?) ?? '';
  }

  Map<String, String> _authHeader(ModelConfig cfg) {
    switch (cfg.authScheme) {
      case AuthScheme.bearer:
        return {'Authorization': 'Bearer ${cfg.apiKey}'};
      case AuthScheme.xApiKey:
        return {'x-api-key': cfg.apiKey, 'anthropic-version': '2023-06-01'};
      case AuthScheme.googleQuery:
        // Gemini 的 key 走 query 串；baseUrl 已经预留 ?key=$API_KEY 的位置由调用方拼
        return {'x-goog-api-key': cfg.apiKey};
    }
  }

  void _handleSseEvent(String event, StreamCallback callback) {
    // 跳过 event: / id: / retry: 等非 data 行
    final dataLines = event
        .split('\n')
        .where((l) => l.startsWith('data:'))
        .map((l) => l.substring(5).trimLeft())
        .toList();
    if (dataLines.isEmpty) return;
    final raw = dataLines.join('\n').trim();
    if (raw.isEmpty) return;
    if (raw == '[DONE]') {
      callback(const ChatStreamEvent(done: true));
      return;
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) return;
      final first = choices.first as Map<String, dynamic>;
      final delta = first['delta'] as Map<String, dynamic>?;
      final content = delta?['content'] as String? ?? '';
      if (content.isNotEmpty) {
        callback(ChatStreamEvent(delta: content));
      }
      // Step 5 占位：tool_calls 累积
      // final toolCalls = delta?['tool_calls'] as List<dynamic>?;
    } catch (_) {
      // 忽略单条解析失败（部分厂商会塞心跳行）
    }
  }

  Future<String> _readAllUtf8(ResponseBody? body) async {
    if (body == null) return '';
    final buf = <int>[];
    await for (final c in body.stream) {
      buf.addAll(c);
    }
    return utf8.decode(buf, allowMalformed: true);
  }
}

/// AI 错误分类。
enum AiErrorKind {
  noApiKey, // 没填 API Key
  auth, // 401 / 403
  rateLimit, // 429
  badRequest, // 400
  notFound, // 404（模型名错）
  server, // 5xx
  network, // 网络 / 超时
  parse, // 解析
  unknown,
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
