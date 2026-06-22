import 'package:drift/drift.dart' show Value;

import '../../../db/app_database.dart';
import '../db/relationship_tables.dart';

/// 约定服务（Step 13）。
///
/// **职责**：
/// - 创建约定（关联 contact / dueAt / priority）
/// - **到期提醒检测**：未来 24 小时内 → 返回待提醒列表
/// - 标记已提醒（避免重复推）
/// - 完成 / 取消约定
class PromiseService {
  PromiseService._();
  static final PromiseService instance = PromiseService._();

  /// 创建约定。
  Future<int> create({
    required AppDatabase db,
    required String title,
    DateTime? dueAt,
    int? contactId,
    String? description,
    String priority = 'normal',
  }) async {
    return db.relationshipDao.insertPromise(
      PromisesCompanion.insert(
        title: title,
        dueAt: dueAt ?? DateTime.now().add(const Duration(days: 1)),
        contactId: Value(contactId),
        description: Value(description),
        priority: Value(priority),
      ),
    );
  }

  /// 待提醒列表（未来 N 小时内到期 + 未提醒过）。
  ///
  /// **核心**：每次调用都**重新计算**——不依赖缓存（用户的时钟可能不准）。
  Future<List<Promise>> pendingReminders(
    AppDatabase db, {
    Duration window = const Duration(hours: 24),
  }) async {
    final dueSoon = await db.relationshipDao.promisesDueSoon(window: window);
    return dueSoon.where((p) => !p.reminded).toList();
  }

  /// 标记某约定已提醒。
  Future<void> markReminded(AppDatabase db, int id) async {
    await db.relationshipDao.markPromisedAsReminded(id);
  }

  /// 批量标记已提醒（推完一轮后调）。
  Future<void> markAllReminded(AppDatabase db) async {
    final pending = await pendingReminders(db);
    for (final p in pending) {
      await markReminded(db, p.id);
    }
  }

  /// 完成约定。
  Future<void> fulfill(AppDatabase db, int id) async {
    await db.relationshipDao.fulfillPromise(id);
  }

  /// 取消约定。
  Future<void> cancel(AppDatabase db, int id) async {
    await (db.update(db.promises)..where((p) => p.id.equals(id))).write(
      const PromisesCompanion(status: Value('cancelled')),
    );
  }
}
