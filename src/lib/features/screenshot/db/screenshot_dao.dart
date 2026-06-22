import 'package:drift/drift.dart';

import '../../../db/app_database.dart';
import 'screenshot_tables.dart';

part 'screenshot_dao.g.dart';

/// 截图 DAO（Step 9 + Step 10）。
@DriftAccessor(tables: [Screenshots])
class ScreenshotDao extends DatabaseAccessor<AppDatabase>
    with _$ScreenshotDaoMixin {
  ScreenshotDao(super.db);

  /// 插入一条新截图记录（立即可查，返回 id）。
  Future<int> insertScreenshot(ScreenshotsCompanion s) =>
      into(screenshots).insert(s);

  /// 待处理截图（未确认，reviewedAt IS NULL）。
  Stream<List<Screenshot>> watchPending() {
    return (select(screenshots)
          ..where((s) => s.reviewedAt.isNull())
          ..orderBy([
            (s) =>
                OrderingTerm(expression: s.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// 已处理截图（按确认时间倒序）。
  Stream<List<Screenshot>> watchReviewed({int limit = 50}) {
    return (select(screenshots)
          ..where((s) => s.reviewedAt.isNotNull())
          ..orderBy([
            (s) =>
                OrderingTerm(expression: s.reviewedAt, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .watch();
  }

  /// 单条查询。
  Future<Screenshot?> getById(int id) =>
      (select(screenshots)..where((s) => s.id.equals(id))).getSingleOrNull();

  /// 更新用户归类 + 动作（确认后）。
  Future<int> markReviewed(
    int id, {
    required String userCategory,
    required String userActionsJson,
  }) {
    return (update(screenshots)..where((s) => s.id.equals(id))).write(
      ScreenshotsCompanion(
        userCategory: Value(userCategory),
        userActionsJson: Value(userActionsJson),
        reviewedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// 删除（设置页"清空截图历史"）。
  Future<int> deleteById(int id) =>
      (delete(screenshots)..where((s) => s.id.equals(id))).go();

  Future<int> deleteAll() => delete(screenshots).go();

  /// Step 10：按 autoSinkStatus 统计（如 success / no_api_key）。
  Future<List<Screenshot>> findByStatus(String status, {int limit = 20}) {
    return (select(screenshots)
          ..where((s) => s.autoSinkStatus.equals(status))
          ..orderBy([
            (s) =>
                OrderingTerm(expression: s.createdAt, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .get();
  }
}
