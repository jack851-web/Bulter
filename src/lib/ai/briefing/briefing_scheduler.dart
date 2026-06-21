import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../modules/registry.dart';
import 'briefing_generator.dart';
import 'briefing_store.dart';

/// 简报调度器（Step 9）。
///
/// **触发点**：
/// 1. **App 启动**：[bootstrap] 启动后 `start()` 立即生成所有缺失 / 过期的简报
/// 2. **定时心跳**：每 1 分钟检查一次；任何模块简报 `isStale()` → 自动重生成
/// 3. **手动**：[refreshNow(moduleId)] 触发单模块立即重生成（用户点卡上的"刷新"）
/// 4. **生命周期**：AppLifecycleState.resumed → 触发一次全量检查（兜底）
///
/// **为什么不依赖 workmanager**：
/// - 避免引入 Android / iOS 原生依赖，Flutter 跨端更稳
/// - 应用后台时定时器会被 OS 暂停，**符合预期**（用户看不到就不要消耗资源）
/// - 应用前台时 1 分钟粒度足够细（首页打开马上刷一次；之后每分钟兜底）
class BriefingScheduler {
  BriefingScheduler._();
  static final BriefingScheduler instance = BriefingScheduler._();

  Timer? _timer;
  bool _running = false;
  final Set<String> _inflight = {}; // 防止并发同一模块

  /// 启动调度器（App 启动时调用一次）。
  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _tick());
    // 启动后立即跑一次（不阻塞 UI）
    scheduleMicrotask(_tick);
    debugPrint('BriefingScheduler: 已启动（1 分钟心跳）');
  }

  /// 停止调度器（应用销毁 / 测试）。
  void stop() {
    _timer?.cancel();
    _timer = null;
    debugPrint('BriefingScheduler: 已停止');
  }

  /// 手动触发某模块刷新（用户点 "刷新"）。
  Future<void> refreshNow(String moduleId) async {
    if (_inflight.contains(moduleId)) return;
    _inflight.add(moduleId);
    try {
      final b = await BriefingGenerator.instance.generate(moduleId);
      await BriefingStore.instance.save(b);
    } finally {
      _inflight.remove(moduleId);
    }
  }

  /// 手动触发全量刷新（中枢点 "重新生成今日简报"）。
  Future<void> refreshAll() async {
    if (_running) return;
    _running = true;
    try {
      final tasks = <Future<void>>[];
      // 5 个业务模块并行
      for (final m in ModuleRegistry.instance.all) {
        if (!m.hasSubAgent) continue;
        tasks.add(refreshNow(m.id));
      }
      // 中枢在业务模块完成后串行生成
      await Future.wait(tasks);
      final butlerBriefing =
          await BriefingGenerator.instance.generateButler();
      await BriefingStore.instance.save(butlerBriefing);
    } finally {
      _running = false;
    }
  }

  /// 1 分钟心跳：检查所有模块简报，stale → 重生成。
  Future<void> _tick() async {
    if (_running) return;
    _running = true;
    try {
      final now = DateTime.now();
      for (final m in ModuleRegistry.instance.all) {
        if (!m.hasSubAgent) continue;
        final latest = BriefingStore.instance.latest(m.id);
        if (latest == null || latest.isStale(now)) {
          // fire-and-forget（不阻塞心跳）
          // ignore: discarded_futures
          refreshNow(m.id);
        }
      }
    } finally {
      _running = false;
    }
  }
}
