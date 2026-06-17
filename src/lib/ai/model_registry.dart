import 'package:collection/collection.dart';
import 'package:hive/hive.dart';

import '../storage/box_names.dart';
import '../storage/storage_init.dart';

/// 单个 LLM 厂商 + 模型的运行时配置。
///
/// 字段设计同时兼容 OpenAI Chat Completions 与 Claude / Gemini 等
/// 厂商自家格式；流式统一走 OpenAI 风格的 SSE `data: {json}\n\n`。
///
/// `extraHeaders` / `extraBody` 用于透传非标字段（如 Anthropic `x-api-key`
/// + `anthropic-version`、Gemini `x-goog-api-key` 等）。
class ModelConfig {
  /// 厂商 ID（如 `minimax` / `openai` / `anthropic` / `google` / `qwen` /
  /// `glm` / `moonshot` / `deepseek` / `baidu`）。
  final String vendorId;

  /// 厂商中文展示名
  final String vendorLabel;

  /// 模型名（如 `MiniMax-M3`、`gpt-4o-mini`、`claude-3-5-sonnet`）。
  final String model;

  /// 该模型的中文展示名（设置页用）
  final String modelLabel;

  /// API Base URL（OpenAI 兼容时填 `/v1`，自定义时填完整 URL）
  final String baseUrl;

  /// 流式对话 endpoint（OpenAI 兼容即 `chat/completions`，其它厂商自家格式）
  final String chatPath;

  /// 鉴权方式
  final AuthScheme authScheme;

  /// 鉴权头名（Bearer 时默认 `Authorization`，custom 时填具体头名）
  final String authHeader;

  /// API Key（用户配置；为空字符串 = 尚未配置）
  final String apiKey;

  /// 最大上下文（tokens）
  final int contextWindow;

  /// 是否支持 tool_calls（Step 5 用）
  final bool supportsTools;

  /// 厂商固定透传头（如 `anthropic-version`）
  final Map<String, String> extraHeaders;

  /// 厂商固定透传 body 字段（如 `thinking: {type: disabled}`）
  final Map<String, dynamic> extraBody;

  const ModelConfig({
    required this.vendorId,
    required this.vendorLabel,
    required this.model,
    required this.modelLabel,
    required this.baseUrl,
    this.chatPath = 'chat/completions',
    this.authScheme = AuthScheme.bearer,
    this.authHeader = 'Authorization',
    this.apiKey = '',
    this.contextWindow = 128000,
    this.supportsTools = true,
    this.extraHeaders = const {},
    this.extraBody = const {},
  });

  ModelConfig copyWith({String? apiKey, String? model, int? contextWindow}) {
    return ModelConfig(
      vendorId: vendorId,
      vendorLabel: vendorLabel,
      model: model ?? this.model,
      modelLabel: modelLabel,
      baseUrl: baseUrl,
      chatPath: chatPath,
      authScheme: authScheme,
      authHeader: authHeader,
      apiKey: apiKey ?? this.apiKey,
      contextWindow: contextWindow ?? this.contextWindow,
      supportsTools: supportsTools,
      extraHeaders: extraHeaders,
      extraBody: extraBody,
    );
  }
}

enum AuthScheme { bearer, xApiKey, googleQuery }

/// 全局模型注册表。
///
/// 启动时按 `vendors` + `models` 初始化 9 个厂商的全部可选模型；
/// 用户当前选择（vendorId / model + apiKey）存 Hive，启动时读出。
class ModelRegistry {
  ModelRegistry._();
  static final ModelRegistry instance = ModelRegistry._();

  /// 9 个厂商的元信息（vendor 级别的 baseUrl / 鉴权方式 / 默认模型）。
  final List<VendorDef> _vendors = const [
    _VendorDef(
      id: 'minimax',
      label: 'MiniMax',
      baseUrl: 'https://api.MiniMax.com/v1',
      authScheme: AuthScheme.bearer,
      defaultModel: 'MiniMax-M3',
    ),
    _VendorDef(
      id: 'openai',
      label: 'OpenAI',
      baseUrl: 'https://api.openai.com/v1',
      authScheme: AuthScheme.bearer,
      defaultModel: 'gpt-4o-mini',
    ),
    _VendorDef(
      id: 'anthropic',
      label: 'Anthropic',
      baseUrl: 'https://api.anthropic.com/v1',
      authScheme: AuthScheme.xApiKey,
      defaultModel: 'claude-3-5-sonnet-latest',
    ),
    _VendorDef(
      id: 'google',
      label: 'Google Gemini',
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
      authScheme: AuthScheme.googleQuery,
      defaultModel: 'gemini-1.5-flash',
    ),
    _VendorDef(
      id: 'qwen',
      label: '阿里通义千问',
      baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      authScheme: AuthScheme.bearer,
      defaultModel: 'qwen-plus',
    ),
    _VendorDef(
      id: 'glm',
      label: '智谱 GLM',
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      authScheme: AuthScheme.bearer,
      defaultModel: 'glm-4-plus',
    ),
    _VendorDef(
      id: 'moonshot',
      label: '月之暗面 Kimi',
      baseUrl: 'https://api.moonshot.cn/v1',
      authScheme: AuthScheme.bearer,
      defaultModel: 'moonshot-v1-128k',
    ),
    _VendorDef(
      id: 'deepseek',
      label: 'DeepSeek',
      baseUrl: 'https://api.deepseek.com/v1',
      authScheme: AuthScheme.bearer,
      defaultModel: 'deepseek-chat',
    ),
    _VendorDef(
      id: 'baidu',
      label: '百度千帆',
      baseUrl: 'https://qianfan.baidubce.com/v2',
      authScheme: AuthScheme.bearer,
      defaultModel: 'ernie-4.0-8k',
    ),
  ];

  /// 每个厂商的可选模型列表（不区分"标配"与"长上下文"，统一列在 settings 里）。
  final Map<String, List<String>> _models = const {
    'minimax': ['MiniMax-M3', 'MiniMax-M2'],
    'openai': ['gpt-4o-mini', 'gpt-4o', 'gpt-4-turbo', 'o1-mini'],
    'anthropic': [
      'claude-3-5-sonnet-latest',
      'claude-3-5-haiku-latest',
      'claude-3-opus-latest',
    ],
    'google': ['gemini-1.5-flash', 'gemini-1.5-pro', 'gemini-2.0-flash-exp'],
    'qwen': ['qwen-turbo', 'qwen-plus', 'qwen-max', 'qwen-long'],
    'glm': ['glm-4-flash', 'glm-4-plus', 'glm-4-air', 'glm-4-long'],
    'moonshot': ['moonshot-v1-8k', 'moonshot-v1-32k', 'moonshot-v1-128k'],
    'deepseek': ['deepseek-chat', 'deepseek-reasoner'],
    'baidu': ['ernie-4.0-8k', 'ernie-3.5-8k', 'ernie-speed-8k'],
  };

  /// 用户当前选中 / 已配置的模型。
  ModelConfig? _active;

  /// 各 vendorId -> API Key 的额外缓存（user 可能在多个厂商间切换）
  final Map<String, String> _apiKeys = {};

  /// 默认 vendor / model
  static const String defaultVendorId = 'minimax';
  static const String defaultModel = 'MiniMax-M3';

  /// 启动时从 Hive 读取用户当前选择 + 各 vendor apiKey。
  Future<void> load() async {
    final box = await openTypedBox(BulterBoxes.userPreferences);
    final activeVendor =
        box.get('activeVendor', defaultValue: defaultVendorId) as String;
    final activeModel =
        box.get('activeModel', defaultValue: defaultModel) as String;
    for (final v in _vendors) {
      final k = box.get('apiKey.${v.id}', defaultValue: '') as String;
      if (k.isNotEmpty) _apiKeys[v.id] = k;
    }
    _active = _buildConfig(
      vendorId: activeVendor,
      model: activeModel,
      apiKey: _apiKeys[activeVendor] ?? '',
    );
  }

  /// 当前激活的模型配置。
  ModelConfig get active {
    final a = _active;
    if (a != null) return a;
    // load 尚未调用时的兜底
    return _buildConfig(
      vendorId: defaultVendorId,
      model: defaultModel,
      apiKey: '',
    );
  }

  bool get hasApiKey => active.apiKey.isNotEmpty;

  /// 全部厂商
  List<VendorDef> get vendors => List.unmodifiable(_vendors);

  /// 给定厂商的模型列表
  List<String> modelsOf(String vendorId) =>
      List.unmodifiable(_models[vendorId] ?? const []);

  /// 切换厂商（保留新厂商下已配置的 apiKey）
  Future<void> switchVendor(String vendorId) async {
    final model =
        _vendors.firstWhereOrNull((v) => v.id == vendorId)?.defaultModel ??
        defaultModel;
    await switchTo(vendorId: vendorId, model: model);
  }

  /// 切换当前厂商下的具体模型
  Future<void> switchTo({
    required String vendorId,
    required String model,
  }) async {
    _active = _buildConfig(
      vendorId: vendorId,
      model: model,
      apiKey: _apiKeys[vendorId] ?? '',
    );
    final box = Hive.box(BulterBoxes.userPreferences);
    await box.put('activeVendor', vendorId);
    await box.put('activeModel', model);
  }

  /// 保存某厂商的 API Key（同时自动切到该厂商 / 默认模型）
  Future<void> saveApiKey({
    required String vendorId,
    required String apiKey,
  }) async {
    _apiKeys[vendorId] = apiKey;
    final box = Hive.box(BulterBoxes.userPreferences);
    await box.put('apiKey.$vendorId', apiKey);
    // 首次填 API Key 时同步激活
    if (_active == null || _active!.vendorId != vendorId) {
      await switchVendor(vendorId);
    } else {
      _active = _active!.copyWith(apiKey: apiKey);
    }
  }

  /// 清空某厂商 API Key
  Future<void> clearApiKey(String vendorId) async {
    _apiKeys.remove(vendorId);
    final box = Hive.box(BulterBoxes.userPreferences);
    await box.delete('apiKey.$vendorId');
    if (_active?.vendorId == vendorId) {
      _active = _active!.copyWith(apiKey: '');
    }
  }

  ModelConfig _buildConfig({
    required String vendorId,
    required String model,
    required String apiKey,
  }) {
    final v = _vendors.firstWhere(
      (e) => e.id == vendorId,
      orElse: () => _vendors.first,
    );
    return ModelConfig(
      vendorId: v.id,
      vendorLabel: v.label,
      model: model,
      modelLabel: model,
      baseUrl: v.baseUrl,
      authScheme: v.authScheme,
      apiKey: apiKey,
    );
  }
}

class _VendorDef {
  final String id;
  final String label;
  final String baseUrl;
  final AuthScheme authScheme;
  final String defaultModel;
  const _VendorDef({
    required this.id,
    required this.label,
    required this.baseUrl,
    required this.authScheme,
    required this.defaultModel,
  });
}

/// 公开的厂商定义（用于向 UI 暴露元信息）。
typedef VendorDef = _VendorDef;
