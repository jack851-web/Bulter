import 'package:drift/drift.dart';

import '../../../db/app_database.dart';
import '../db/thought_tables.dart';

/// 给未来的信服务（Step 13）。
///
/// **职责**：
/// - 信件**日期锁定**——`targetDate` 未到时不可阅读（返回红条 + 倒计时）
/// - **到期自动解锁**（每次读取时检查；也可定时任务触发）
/// - 支持 type = to_self / to_others / to_future
class LetterService {
  LetterService._();
  static final LetterService instance = LetterService._();

  /// 创建信件。
  ///
  /// [targetDate] 之前不可阅读（locked=true）。`null` = 永不锁定。
  Future<int> writeLetter({
    required AppDatabase db,
    required String title,
    required String content,
    required String type, // to_self / to_others / to_future
    DateTime? targetDate,
  }) async {
    return db.thoughtDao.insertLetter(
      LettersCompanion.insert(
        title: title,
        content: content,
        type: type,
        targetDate: Value(targetDate),
      ),
    );
  }

  /// 取所有信件（含锁定信息）。
  ///
  /// **核心设计**：每次查询都**重新计算**锁定状态，**不**依赖缓存：
  /// - targetDate 未到 → 返回 `Letter.locked=true` + `daysUntilUnlock` 倒计时
  /// - targetDate 已到 且 openedAt == null → 自动标 openedAt = now
  Future<List<LockedLetter>> listLetters(AppDatabase db) async {
    final raw =
        await (db.select(db.letters)..orderBy([
              (l) => OrderingTerm(
                expression: l.targetDate,
                mode: OrderingMode.asc,
              ),
            ]))
            .get();
    final now = DateTime.now();
    final result = <LockedLetter>[];
    for (final l in raw) {
      final target = l.targetDate;
      if (target != null && target.isAfter(now)) {
        // 未到解锁日期
        result.add(
          LockedLetter(
            letter: l,
            isLocked: true,
            daysUntilUnlock: target.difference(now).inDays + 1,
          ),
        );
        continue;
      }
      // 到期 & 第一次打开 → 写入 openedAt
      if (l.openedAt == null) {
        await (db.update(db.letters)..where((u) => u.id.equals(l.id))).write(
          LettersCompanion(openedAt: Value(now)),
        );
      }
      result.add(LockedLetter(letter: l, isLocked: false));
    }
    return result;
  }

  /// 强制解锁（用户主动"现在就开"）。
  Future<void> forceUnlock(AppDatabase db, int id) async {
    await (db.update(db.letters)..where((u) => u.id.equals(id))).write(
      LettersCompanion(openedAt: Value(DateTime.now())),
    );
  }
}

/// 信件 + 锁定状态。
class LockedLetter {
  final Letter letter;
  final bool isLocked;
  final int daysUntilUnlock; // 仅 locked=true 时有意义

  const LockedLetter({
    required this.letter,
    required this.isLocked,
    this.daysUntilUnlock = 0,
  });
}
