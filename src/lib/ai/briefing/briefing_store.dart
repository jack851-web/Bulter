import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';

import '../../db/app_database.dart';
import '../../modules/bulter_module.dart';
import '../../modules/registry.dart';
import '../../storage/box_names.dart';
import 'briefing_models.dart';
import 'hive_boxes.dart';

/// 简报存储层（Step 9）。
///
/// **三层存储**：
/// 1. **内存 `ValueNotifier<ModuleBriefing?>`** — UI 订阅，零延迟
/// 2. **Drift `briefings` 表** — 持久化（应用关闭 / 重启仍能加载）
/// 3. **Hive `bulter_briefings` Box** — 冷启动首屏加速（避免 SQL 查询）
///
/// **订阅模型**：UI 用 [watchBriefing] 监听 `ValueNotifier`；任何 [save] 调用
/// 自动通知所有订阅者。
class BriefingStore {
  BriefingStore._();
  static final BriefingStore instance = BriefingStore._();

  final Map<String, ValueNotifier<ModuleBriefing?>> _notifiers = {};
  bool _initialized = false;

  /// 内存缓存（避免每次 UI rebuild 都读 DB）。
  final Map<String, ModuleBriefing> _cache = {};

  /// 初始化：打开 Hive Box + 从 Drift 加载最新简报到内存。
  Future<void> init({AppDatabase? db}) async {
    if (_initialized) return;
    _initialized = true;
    await HiveBoxes.openBriefingsBox();
    // 同步从 Drift 加载（保证 restart 后 UI 立即有数据）
    await _reloadFromDrift(db: db);
  }

  /// 监听某模块的最新简报。
  ///
  /// 返回 `ValueListenable<ModuleBriefing?>`，UI 用 `ValueListenableBuilder` 即可。
  ValueListenable<ModuleBriefing?> watchBriefing(String moduleId) {
    return _notifiers.putIfAbsent(
      moduleId,
      () => ValueNotifier<ModuleBriefing?>(_cache[moduleId]),
    );
  }

  /// 同步取最新（不订阅）。
  ModuleBriefing? latest(String moduleId) => _cache[moduleId];

  /// 取所有已缓存的简报（中枢主页用）。
  Map<String, ModuleBriefing> snapshot() => Map.unmodifiable(_cache);

  /// 保存一条简报（覆盖语义）：
  /// 1. 写内存 notifier
  /// 2. 写 Drift 表
  /// 3. 写 Hive Box（key = moduleId）
  Future<void> save(ModuleBriefing b, {AppDatabase? db}) async {
    final dbInst = db ?? AppDatabase.I;
    _cache[b.moduleId] = b;
    final notifier = _notifiers[b.moduleId];
    if (notifier != null) notifier.value = b;
    // Drift：写完整 row，schemaVersion 已支持
    await dbInst.aiDao.insertBriefing(
      BriefingsCompanion.insert(
        moduleId: b.moduleId,
        period: b.period.storageKey,
        headline: b.headline,
        summary: b.summary,
        jsonData: Value(jsonEncode(b.toJson())),
        ttlSeconds: const Value<int>.absent(),
      ),
    );
    // Hive：冷启动加速
    final box = HiveBoxes.briefingsBox;
    await box?.put(b.moduleId, jsonEncode(b.toJson()));
  }

  /// 手动重新从 Drift 加载（开发者工具 / 测试用）。
  Future<void> refresh({AppDatabase? db}) async {
    await _reloadFromDrift(db: db);
  }

  Future<void> _reloadFromDrift({AppDatabase? db}) async {
    final dbInst = db ?? AppDatabase.I;
    final moduleIds = ModuleRegistry.instance.all.map((m) => m.id).toList();
    for (final id in moduleIds) {
      final row = await dbInst.aiDao.latestBriefingFor(id);
      if (row == null) continue;
      try {
        final json = jsonDecode(row.jsonData) as Map<String, dynamic>;
        final b = ModuleBriefing.fromJson({...json, 'moduleId': id});
        _cache[id] = b;
        final n = _notifiers[id];
        if (n != null) n.value = b;
      } catch (e) {
        debugPrint('BriefingStore: 解析 $id 简报失败 - $e');
      }
    }
  }

  /// 清空所有（开发用）。
  Future<void> clear() async {
    _cache.clear();
    for (final n in _notifiers.values) {
      n.value = null;
    }
    final box = HiveBoxes.briefingsBox;
    await box?.clear();
  }
}
