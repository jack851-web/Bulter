import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../model_registry.dart';

/// Embedding 抽象接口。
///
/// 任何"把一段文本转成 Float32List 向量"的实现都遵循这一接口。
/// Step 6 默认实现：OpenAI 兼容 [POST /v1/embeddings]，fallback 为 [LocalHashEmbedder]。
abstract class Embedder {
  String get name;
  int get dimensions;

  /// 把一批文本 embed 成 Float32List。失败抛 [EmbedderException]。
  Future<List<Float32List>> embedBatch(List<String> texts);
}

/// Embedder 异常（区分网络 / 鉴权 / 解析）。失败时主流程**应**降级为无 RAG，
/// 而不是直接抛错给用户。
class EmbedderException implements Exception {
  final String message;
  final Object? cause;
  EmbedderException(this.message, [this.cause]);
  @override
  String toString() => 'EmbedderException: $message';
}

/// OpenAI 兼容的 Embedding 实现。
///
/// - 默认模型：`text-embedding-3-small`（1536 维）
/// - 自动读取 [ModelRegistry] 的当前 active 配置（与 chat 共用 vendor / apiKey）
/// - Anthropic / Gemini 等无官方 embedding endpoint 的厂商 → fallback
class OpenAiCompatibleEmbedder implements Embedder {
  @override
  final String name;
  @override
  final int dimensions;
  final ModelConfig _cfg;
  final Dio _dio;

  OpenAiCompatibleEmbedder._(this._cfg, this.name, this.dimensions)
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

  /// 从当前 [ModelRegistry] 构造。
  ///
  /// 当 active 厂商无标准 embedding endpoint（Anthropic / Gemini）时返回 null，
  /// 调用方应 fallback 到 [LocalHashEmbedder]。
  static OpenAiCompatibleEmbedder? tryFromRegistry() {
    final cfg = ModelRegistry.instance.active;
    if (cfg.apiKey.isEmpty) return null;
    // 仅 OpenAI / OpenAI 兼容厂商的 chat API 通常兼容 /v1/embeddings
    const supported = {
      'minimax',
      'openai',
      'qwen',
      'glm',
      'moonshot',
      'deepseek',
      'baidu',
    };
    if (!supported.contains(cfg.vendorId)) return null;
    return OpenAiCompatibleEmbedder._(
      cfg,
      'text-embedding-3-small',
      1536,
    );
  }

  Map<String, String> _headers() {
    switch (_cfg.authScheme) {
      case AuthScheme.bearer:
        return {'Authorization': 'Bearer ${_cfg.apiKey}'};
      case AuthScheme.xApiKey:
        return {'x-api-key': _cfg.apiKey, 'anthropic-version': '2023-06-01'};
      case AuthScheme.googleQuery:
        return {'x-goog-api-key': _cfg.apiKey};
    }
  }

  @override
  Future<List<Float32List>> embedBatch(List<String> texts) async {
    if (texts.isEmpty) return const [];
    try {
      final url = _cfg.baseUrl.endsWith('/')
          ? '${_cfg.baseUrl}embeddings'
          : '${_cfg.baseUrl}/embeddings';
      final resp = await _dio.post<Map<String, dynamic>>(
        url,
        data: {'input': texts, 'model': name},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            ..._headers(),
          },
          responseType: ResponseType.json,
        ),
      );
      final data = resp.data;
      if (data == null) {
        throw EmbedderException('空响应');
      }
      final list = (data['data'] as List<dynamic>?) ?? const [];
      final out = <Float32List>[];
      for (final entry in list) {
        final m = entry as Map<String, dynamic>;
        final emb = (m['embedding'] as List<dynamic>?) ?? const [];
        final floats = Float32List(emb.length);
        for (var i = 0; i < emb.length; i++) {
          floats[i] = (emb[i] as num).toDouble();
        }
        out.add(floats);
      }
      return out;
    } on DioException catch (e) {
      throw EmbedderException(
        e.response?.statusCode == 401
            ? '鉴权失败（401），请检查 API Key'
            : e.message ?? '网络异常',
        e,
      );
    } catch (e) {
      throw EmbedderException('解析失败：$e', e);
    }
  }
}

/// 本地哈希 Embedder（fallback / 测试用）。
///
/// 维度固定 [LocalHashEmbedder.dimensions]（= 128）。**不**保证语义质量，
/// 仅为"在没有外部 Embedding 服务时让 RAG 不完全失效"。
class LocalHashEmbedder implements Embedder {
  @override
  String get name => 'local-hash';
  @override
  int get dimensions => 128;

  @override
  Future<List<Float32List>> embedBatch(List<String> texts) async {
    return texts.map(_hashEmbed).toList(growable: false);
  }

  Float32List _hashEmbed(String text) {
    // 把文本切成 3-gram，每 gram 哈希到 0..127 的桶，TF（出现次数）作为值；
    // 最终 L2 归一化。余弦相似度 ≈ 共同 n-gram 比例。
    final v = Float32List(dimensions);
    final lower = text.toLowerCase();
    for (var i = 0; i + 3 <= lower.length; i++) {
      final gram = lower.substring(i, i + 3);
      final h = _hash3(gram) % dimensions;
      v[h] += 1.0;
    }
    var norm = 0.0;
    for (final x in v) {
      norm += x * x;
    }
    norm = math.sqrt(norm);
    if (norm > 0) {
      for (var i = 0; i < v.length; i++) {
        v[i] /= norm;
      }
    }
    return v;
  }

  int _hash3(String s) {
    int h = 0;
    for (final c in s.codeUnits) {
      h = (h * 131 + c) & 0x7fffffff;
    }
    return h;
  }
}

/// Embedder 工厂：根据用户配置 / API Key 状态选择最合适的实现。
class EmbedderFactory {
  EmbedderFactory._();

  /// 智能选择。
  ///
  /// 1) 优先 OpenAI 兼容（如用户已配 OpenAI / Qwen / DeepSeek 等）
  /// 2) 否则 LocalHash（仅做"凑合"语义检索，不会崩溃）
  static Embedder resolve() {
    try {
      final e = OpenAiCompatibleEmbedder.tryFromRegistry();
      if (e != null) return e;
    } catch (e, st) {
      debugPrint('EmbedderFactory: OpenAI 不可用，fallback 到 LocalHash: $e\n$st');
    }
    return LocalHashEmbedder();
  }
}
