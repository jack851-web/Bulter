import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';

import '../../ai/scene_inference.dart';
import '../../db/app_database.dart';
import 'db/screenshot_tables.dart';

/// 自动入库（Step 10）—— **主模型多模态 → 直接调工具**。
///
/// **架构**（[doc/first/02-requirements.md §九.1](file:///d:/others/app/Bulter/doc/first/02-requirements.md)）：
/// - 截图**不**走子模型
/// - 主模型多模态 LLM 看图 → 选工具 → **直接调 `ToolRegistry`** 写入数据库
/// - 这里只负责**截图历史记录**（screenshots 表）和**用户归类决策**
///
/// **与 [SceneInferencer] 的关系**：
/// - `SceneInferencer.inferFromScreenshot()` 完成"看图 + 调工具"
/// - `AutoSinkSink.record()` 负责把"截图事件 + 工具执行结果"写入 screenshots 表
class AutoSinkSink {
  AutoSinkSink._();

  /// 处理一张截图：调主模型 + 记录历史。
  ///
  /// 工具执行**已经在** [SceneInferencer] 内部完成；
  /// 这里只是**保存截图记录**到数据库（screenshots 表）。
  static Future<AutoSinkResult> autoSinkFromScreenshotPath(String path) async {
    try {
      final inference = await SceneInferencer.instance.inferFromScreenshot(path);
      final screenshotId = await _record(path, inference);
      return AutoSinkResult(
        success: inference.ok,
        lowConfidence: !inference.ok && inference.error == null,
        moduleLabel: inference.moduleLabel ?? 'Bulter',
        screenshotId: screenshotId,
        inference: inference,
        error: inference.error,
      );
    } catch (e) {
      debugPrint('AutoSinkSink: 异常 - $e');
      return AutoSinkResult(success: false, error: e.toString());
    }
  }

  static Future<int> _record(String path, SceneInference inference) async {
    final db = AppDatabase.I;
    return db.screenshotDao.insertScreenshot(
      ScreenshotsCompanion.insert(
        thumbPath: path,
        packageName: const Value(null),
        windowTitle: const Value(null),
        textPreview: const Value(null),
        inferredCategory: Value(inference.error ?? _categoryFromTools(inference)),
        inferredConfidence: Value(inference.ok ? 0.9 : 0.0),
        inferredSummary: Value(inference.summary),
        inferredJson: Value(_serializeInference(inference)),
        userCategory: Value(_categoryFromTools(inference)),
        userActionsJson: Value(
          inference.toolCalls
              .map((t) => '${t.ok ? "ok" : "err"}:${t.toolName}')
              .join(','),
        ),
        reviewedAt: Value(DateTime.now().millisecondsSinceEpoch),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        autoSinkStatus: Value(_statusFromResult(inference)),
      ),
    );
  }

  static String _categoryFromTools(SceneInference inference) {
    for (final t in inference.toolCalls.where((e) => e.ok)) {
      if (t.toolName.startsWith('relationship.')) return 'relationship';
      if (t.toolName.startsWith('wealth.')) return 'wealth';
      if (t.toolName.startsWith('growth.')) return 'growth';
      if (t.toolName.startsWith('thought.')) return 'thought';
      if (t.toolName.startsWith('health.')) return 'health';
    }
    return 'other';
  }

  static String _statusFromResult(SceneInference inference) {
    if (inference.error != null) return inference.error!;
    if (inference.ok) return 'success';
    return 'no_tools_called';
  }

  static String _serializeInference(SceneInference inference) {
    final lines = <String>[];
    for (final t in inference.toolCalls) {
      lines.add(
          '${t.ok ? "✓" : "✗"} ${t.toolName}: ${t.summary}');
    }
    return lines.join('\n');
  }
}

/// 自动入库结果（给 BallEventHandler 用）。
class AutoSinkResult {
  final bool success;
  final bool lowConfidence;
  final String? moduleLabel;
  final int? screenshotId;
  final SceneInference? inference;
  final String? error;

  const AutoSinkResult({
    required this.success,
    this.lowConfidence = false,
    this.moduleLabel,
    this.screenshotId,
    this.inference,
    this.error,
  });
}
