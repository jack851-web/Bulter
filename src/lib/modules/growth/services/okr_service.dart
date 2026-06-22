import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../../db/app_database.dart';
import '../db/growth_tables.dart';

/// OKR 服务（Step 13）。
///
/// **职责**：
/// - **拆解** OKR 的 keyResultsJson → List\<KeyResult\>
/// - **计算进度**：基于各 KR 完成度的平均（0-100）
/// - **新增 / 更新 / 完成 KR**
/// - **季度周期**管理（Q1-Q4 / year）
///
/// **KR 数据模型**：
/// ```json
/// [
///   {"id": 1, "title": "完成 X 课程", "progress": 75, "completed": false},
///   ...
/// ]
/// ```
class OkrService {
  OkrService._();
  static final OkrService instance = OkrService._();

  /// 拆解 KR JSON → List\<KeyResult\>（自动跳过格式错误的 KR）。
  List<KeyResult> parseKRs(String json) {
    if (json.isEmpty) return const [];
    try {
      final raw = jsonDecode(json);
      if (raw is! List) return const [];
      return [
        for (final e in raw.whereType<Map<String, dynamic>>())
          KeyResult(
            id: (e['id'] as num?)?.toInt() ?? 0,
            title: (e['title'] as String?) ?? '',
            progress: ((e['progress'] as num?)?.toInt() ?? 0).clamp(0, 100),
            completed: (e['completed'] as bool?) ?? false,
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// 计算 OKR 进度（KR 平均进度，0-100）。
  int calcProgress(List<KeyResult> krs) {
    if (krs.isEmpty) return 0;
    final sum = krs.fold<int>(0, (a, b) => a + b.progress);
    return (sum / krs.length).round().clamp(0, 100);
  }

  /// 更新单条 KR 进度。
  ///
  /// - [newProgress]：0-100
  /// - 自动判定 completed（progress >= 100）
  /// - 自动重算 OKR 整体进度并写入 DB
  Future<void> updateKrProgress({
    required AppDatabase db,
    required int okrId,
    required int krId,
    required int newProgress,
  }) async {
    final okr = await (db.select(db.okrs)..where((o) => o.id.equals(okrId)))
        .getSingleOrNull();
    if (okr == null) return;
    final krs = parseKRs(okr.keyResultsJson);
    final updated = [
      for (final kr in krs)
        if (kr.id == krId)
          kr.copyWith(
            progress: newProgress.clamp(0, 100),
            completed: newProgress >= 100,
          )
        else
          kr,
    ];
    final newProgressPct = calcProgress(updated);
    await (db.update(db.okrs)..where((o) => o.id.equals(okrId))).write(
      OkrsCompanion(
        keyResultsJson: Value(jsonEncode(updated.map((kr) => kr.toJson()).toList())),
        progress: Value(newProgressPct),
      ),
    );
  }

  /// 新增 KR 到 OKR。
  Future<void> addKr({
    required AppDatabase db,
    required int okrId,
    required String title,
  }) async {
    final okr = await (db.select(db.okrs)..where((o) => o.id.equals(okrId)))
        .getSingleOrNull();
    if (okr == null) return;
    final krs = parseKRs(okr.keyResultsJson);
    final maxId = krs.isEmpty
        ? 0
        : krs.map((kr) => kr.id).reduce((a, b) => a > b ? a : b);
    final updated = [
      ...krs,
      KeyResult(id: maxId + 1, title: title, progress: 0),
    ];
    await (db.update(db.okrs)..where((o) => o.id.equals(okrId))).write(
      OkrsCompanion(
        keyResultsJson: Value(jsonEncode(updated.map((kr) => kr.toJson()).toList())),
        progress: Value(calcProgress(updated)),
      ),
    );
  }

  /// 删除 KR。
  Future<void> removeKr({
    required AppDatabase db,
    required int okrId,
    required int krId,
  }) async {
    final okr = await (db.select(db.okrs)..where((o) => o.id.equals(okrId)))
        .getSingleOrNull();
    if (okr == null) return;
    final krs = parseKRs(okr.keyResultsJson).where((kr) => kr.id != krId).toList();
    await (db.update(db.okrs)..where((o) => o.id.equals(okrId))).write(
      OkrsCompanion(
        keyResultsJson: Value(jsonEncode(krs.map((kr) => kr.toJson()).toList())),
        progress: Value(calcProgress(krs)),
      ),
    );
  }

  /// 取当前季度的 OKR 列表（用于首页"本季度目标"）。
  Future<List<Okr>> quarterOkrs(AppDatabase db, {String? quarter}) async {
    final q = quarter ?? currentQuarter();
    return (db.select(db.okrs)..where((o) => o.period.equals(q))).get();
  }

  /// 计算当前季度（Q1/Q2/Q3/Q4）。
  String currentQuarter([DateTime? now]) {
    final n = now ?? DateTime.now();
    final m = n.month;
    return 'Q${((m - 1) ~/ 3) + 1}';
  }
}

/// 单条 Key Result。
class KeyResult {
  final int id;
  final String title;
  final int progress; // 0-100
  final bool completed;

  const KeyResult({
    required this.id,
    required this.title,
    required this.progress,
    this.completed = false,
  });

  KeyResult copyWith({int? id, String? title, int? progress, bool? completed}) =>
      KeyResult(
        id: id ?? this.id,
        title: title ?? this.title,
        progress: progress ?? this.progress,
        completed: completed ?? this.completed,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'progress': progress,
        'completed': completed,
      };
}
