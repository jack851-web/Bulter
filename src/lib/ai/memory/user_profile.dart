import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';

import '../../db/app_database.dart';
import '../ai_service.dart';
import '../rag/embedder.dart';
import '../rag/retriever.dart';
import 'short_term.dart';

/// 用户画像（结构化 + 自然语言摘要）。
///
/// 4 个核心字段（来自 user_profiles 表）：
/// - displayName：用户称呼
/// - occupation：职业
/// - location：所在地
/// - preferencesJson / goalsJson / importantPeopleJson：结构化 JSON
///
/// 抽取流程：
/// 1. 调 LLM 从最近 K 条消息里提取结构化画像字段
/// 2. 与现有画像 merge（**不**覆盖已有非空字段，除非新值明确）
/// 3. 写回 DB + 同步生成"自然语言摘要"用于注入 system prompt
class UserProfileMemory {
  final AppDatabase db;
  Embedder? embedder;
  Retriever? retriever;
  final AiService aiService;

  /// 抽取 system prompt。
  static const String extractSystemPrompt =
      '你是 Bulter 的用户画像提取助手。'
      '你的任务是从用户最近一段对话里，提取出关于"用户本人"的稳定信息。'
      '\n\n'
      '**只**关注用户自己（**不**提取联系人、**不**提取临时性信息）：\n'
      '1. displayName：用户希望被怎么称呼（仅在用户明确说"叫我 X / 我叫 X"时提取）\n'
      '2. occupation：职业（"我是 X" / "我做 X 工作"）\n'
      '3. location：所在地（"我在 X" / "我住在 X"）\n'
      '4. preferences：偏好（喜欢/不喜欢/习惯）→ [{"key": "food", "value": "喜欢川菜"}]\n'
      '5. goals：目标（长期/中期）→ [{"text": "半年内跑完一场马拉松", "priority": "high"}]\n'
      '6. importantPeople：重要他人 → [{"name": "小王", "relation": "闺蜜"}]\n'
      '\n'
      '**输出格式**（合法 JSON，不要 markdown 围栏，不要任何解释）：\n'
      '{\n'
      '  "displayName": "...",\n'
      '  "occupation": "...",\n'
      '  "location": "...",\n'
      '  "preferences": [...],\n'
      '  "goals": [...],\n'
      '  "importantPeople": [...]\n'
      '}\n'
      '如果某字段没有新信息，**填 null** 或 **空数组**，**不要编造**。';

  UserProfileMemory({
    required this.db,
    required this.aiService,
    this.embedder,
    this.retriever,
  });

  /// 读取当前画像（如不存在则返回空画像）。
  Future<UserProfile> current() async {
    final row = await db.aiDao.getProfile();
    return row ?? _emptyProfile();
  }

  /// 把画像渲染为可注入 LLM 的"画像段落"。
  static String render(UserProfile p) {
    final parts = <String>[];
    if (_isNotBlank(p.displayName)) parts.add('称呼：${p.displayName}');
    if (_isNotBlank(p.occupation)) parts.add('职业：${p.occupation}');
    if (_isNotBlank(p.location)) parts.add('所在地：${p.location}');
    final prefs = _decodeListOfMaps(p.preferencesJson);
    if (prefs.isNotEmpty) {
      parts.add(
        '偏好：${prefs.map((m) => "${m['key']}=${m['value']}").join('；')}',
      );
    }
    final goals = _decodeListOfMaps(p.goalsJson);
    if (goals.isNotEmpty) {
      parts.add('目标：${goals.map((m) => m['text']).join('；')}');
    }
    final people = _decodeListOfMaps(p.importantPeopleJson);
    if (people.isNotEmpty) {
      parts.add(
        '重要他人：${people.map((m) => "${m['name']}(${m['relation'] ?? '?'})").join('、')}',
      );
    }
    if (parts.isEmpty) return '';
    return '【用户画像】\n${parts.join('\n')}';
  }

  /// 从对话里抽取并 merge 画像。返回抽取结果摘要。
  Future<ProfileExtractResult> maybeExtract({
    required String recentTranscript,
  }) async {
    if (recentTranscript.trim().isEmpty) {
      return const ProfileExtractResult.empty();
    }
    try {
      final promptMem = ShortTermMemory()..addSystem(extractSystemPrompt);
      promptMem.append(
        ChatMessage(
          role: ChatRole.user,
          content: '请从下面的对话里提取用户画像：\n\n$recentTranscript',
          createdAt: DateTime.now(),
        ),
      );
      final raw = await aiService.completion(memory: promptMem);
      final extracted = _parse(raw);
      if (extracted == null) {
        return const ProfileExtractResult.empty();
      }
      // 与现有画像 merge 并写回
      final current = await this.current();
      final merged = _merge(current, extracted);
      await db.aiDao.upsertProfile(UserProfilesCompanion(
        displayName: Value(merged.displayName),
        occupation: Value(merged.occupation),
        location: Value(merged.location),
        preferencesJson: Value(merged.preferencesJson),
        goalsJson: Value(merged.goalsJson),
        importantPeopleJson: Value(merged.importantPeopleJson),
        updatedAt: Value(DateTime.now()),
      ));
      return ProfileExtractResult(
        updated: _countUpdates(current, merged),
      );
    } catch (e, st) {
      debugPrint('UserProfileMemory.maybeExtract 失败: $e\n$st');
      return const ProfileExtractResult.empty();
    }
  }

  // —— merge 逻辑 —— //
  UserProfile _merge(UserProfile current, _Extracted ex) {
    return UserProfile(
      id: current.id,
      // 标量字段：仅在当前为空 / 新值非空时更新
      displayName: _pickScalar(current.displayName, ex.displayName),
      occupation: _pickScalar(current.occupation, ex.occupation),
      location: _pickScalar(current.location, ex.location),
      // 列表字段：合并 + 去重
      preferencesJson: _mergeJsonList(
        current.preferencesJson,
        ex.preferences,
        key: 'key',
      ),
      goalsJson: _mergeJsonList(
        current.goalsJson,
        ex.goals,
        key: 'text',
      ),
      importantPeopleJson: _mergeJsonList(
        current.importantPeopleJson,
        ex.importantPeople,
        key: 'name',
      ),
      updatedAt: DateTime.now(),
    );
  }

  static String? _pickScalar(String? current, String? incoming) {
    if (_isNotBlank(incoming)) return incoming!.trim();
    return current;
  }

  static String _mergeJsonList(
    String currentJson,
    List<Map<String, dynamic>> incoming, {
    required String key,
  }) {
    final list = _decodeListOfMaps(currentJson);
    final seen = <String>{};
    for (final m in list) {
      final k = m[key]?.toString();
      if (k != null && k.isNotEmpty) seen.add(k);
    }
    for (final m in incoming) {
      final k = m[key]?.toString();
      if (k == null || k.isEmpty) continue;
      if (seen.contains(k)) continue;
      list.add(Map<String, dynamic>.from(m));
      seen.add(k);
    }
    return jsonEncode(list);
  }

  static int _countUpdates(UserProfile before, UserProfile after) {
    var n = 0;
    if (before.displayName != after.displayName) n++;
    if (before.occupation != after.occupation) n++;
    if (before.location != after.location) n++;
    if (before.preferencesJson != after.preferencesJson) n++;
    if (before.goalsJson != after.goalsJson) n++;
    if (before.importantPeopleJson != after.importantPeopleJson) n++;
    return n;
  }

  // —— 解析 LLM 输出 —— //
  _Extracted? _parse(String raw) {
    try {
      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}');
      if (start < 0 || end <= start) return null;
      final jsonStr = raw.substring(start, end + 1);
      final m = jsonDecode(jsonStr) as Map<String, dynamic>;
      return _Extracted(
        displayName: m['displayName'] as String?,
        occupation: m['occupation'] as String?,
        location: m['location'] as String?,
        preferences: _asMapList(m['preferences']),
        goals: _asMapList(m['goals']),
        importantPeople: _asMapList(m['importantPeople']),
      );
    } catch (e, st) {
      debugPrint('UserProfileMemory._parse 失败: $e\n$st');
      return null;
    }
  }

  static List<Map<String, dynamic>> _asMapList(dynamic v) {
    if (v is! List) return const [];
    return v
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> _decodeListOfMaps(String json) {
    try {
      final v = jsonDecode(json);
      return _asMapList(v);
    } catch (_) {
      return const [];
    }
  }

  static bool _isNotBlank(String? s) => s != null && s.trim().isNotEmpty;

  UserProfile _emptyProfile() => UserProfile(
    id: 1,
    displayName: null,
    occupation: null,
    location: null,
    preferencesJson: '[]',
    goalsJson: '[]',
    importantPeopleJson: '[]',
    updatedAt: DateTime.now(),
  );
}

class _Extracted {
  final String? displayName;
  final String? occupation;
  final String? location;
  final List<Map<String, dynamic>> preferences;
  final List<Map<String, dynamic>> goals;
  final List<Map<String, dynamic>> importantPeople;
  const _Extracted({
    required this.displayName,
    required this.occupation,
    required this.location,
    required this.preferences,
    required this.goals,
    required this.importantPeople,
  });
}

/// 抽取结果（用于 UI 状态条 / 调试）。
class ProfileExtractResult {
  final int updated;
  const ProfileExtractResult({required this.updated});
  const ProfileExtractResult.empty() : updated = 0;
  bool get hasChanges => updated > 0;
}
