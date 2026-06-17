import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 升级前自动备份。
///
/// 策略：把当前 SQLite 文件 + 整个 Hive 目录复制到
/// `<base>/备份/升级前_v{oldVersion}_{timestamp}/`，迁移成功后保留 7 天，
/// 迁移失败时调用 [restoreFromBackup] 自动回滚。
class BackupService {
  static const String backupRoot = '备份';
  static const Duration retention = Duration(days: 7);

  /// 计算当前数据库 / Hive 所在根目录。测试场景可传 [subdir] 落到临时目录。
  static Future<String> _resolveBase({String? subdir}) async {
    if (subdir != null) return subdir;
    final docs = await getApplicationDocumentsDirectory();
    return docs.path;
  }

  /// 升级前备份。返回备份目录路径。
  ///
  /// 若目标 SQLite 文件不存在（首次安装），直接返回 `null`，不创建空备份。
  static Future<String?> backupBeforeUpgrade({
    required int fromVersion,
    required int toVersion,
    String? subdir,
  }) async {
    final base = await _resolveBase(subdir: subdir);
    final sqlite = File(p.join(base, 'bulter.sqlite'));
    if (!sqlite.existsSync()) return null;

    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupDir = Directory(
      p.join(base, backupRoot, '升级前_v$fromVersion→v$toVersion _$ts'),
    );
    await backupDir.create(recursive: true);

    // 1. 复制 SQLite
    await sqlite.copy(p.join(backupDir.path, 'bulter.sqlite'));

    // 2. 复制 Hive 目录（如存在）
    final hiveDir = Directory(p.join(base, 'hive'));
    if (hiveDir.existsSync()) {
      await _copyDir(hiveDir, Directory(p.join(backupDir.path, 'hive')));
    }

    return backupDir.path;
  }

  /// 失败回滚：用备份目录覆盖当前 SQLite + Hive。
  static Future<void> restoreFromBackup(
    String backupDirPath, {
    String? subdir,
  }) async {
    final backupDir = Directory(backupDirPath);
    if (!backupDir.existsSync()) {
      throw StateError('备份目录不存在：$backupDirPath');
    }
    final base = await _resolveBase(subdir: subdir);
    final sqliteBackup = File(p.join(backupDir.path, 'bulter.sqlite'));
    if (sqliteBackup.existsSync()) {
      await sqliteBackup.copy(p.join(base, 'bulter.sqlite'));
    }
    final hiveBackup = Directory(p.join(backupDir.path, 'hive'));
    if (hiveBackup.existsSync()) {
      final hiveTarget = Directory(p.join(base, 'hive'));
      if (hiveTarget.existsSync()) {
        await hiveTarget.delete(recursive: true);
      }
      await _copyDir(hiveBackup, hiveTarget);
    }
  }

  /// 清理超过 [retention] 的旧备份。
  static Future<int> cleanExpired({String? subdir}) async {
    final base = await _resolveBase(subdir: subdir);
    final root = Directory(p.join(base, backupRoot));
    if (!root.existsSync()) return 0;
    final cutoff = DateTime.now().subtract(retention);
    var removed = 0;
    for (final entry in root.listSync()) {
      if (entry is! Directory) continue;
      final stat = entry.statSync();
      if (stat.modified.isBefore(cutoff)) {
        await entry.delete(recursive: true);
        removed++;
      }
    }
    return removed;
  }

  static Future<void> _copyDir(Directory src, Directory dst) async {
    await dst.create(recursive: true);
    await for (final entity in src.list()) {
      final name = p.basename(entity.path);
      if (entity is File) {
        await entity.copy(p.join(dst.path, name));
      } else if (entity is Directory) {
        await _copyDir(entity, Directory(p.join(dst.path, name)));
      }
    }
  }
}
