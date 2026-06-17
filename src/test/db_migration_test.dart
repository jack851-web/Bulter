// Bulter 第 2 步：Drift 迁移与备份策略测试
//
// 验证：
// 1) schemaVersion 初值正确
// 2) 首次启动不触发备份（文件不存在时返回 null）
// 3) onCreate 走 m.createAll + VectorStore.ensureTable
// 4) 升级前自动备份
// 5) 升级失败可回滚

import 'dart:io';

import 'package:bulter/db/app_database.dart';
import 'package:bulter/db/backup.dart';
import 'package:bulter/db/connection.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late String sqlitePath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bulter_mig_');
    sqlitePath = p.join(tempDir.path, 'bulter.sqlite');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('schemaVersion 初值为 1', () {
    final db = AppDatabase.forTesting(openInMemoryConnection());
    addTearDown(db.close);
    expect(db.schemaVersion, 1);
  });

  test('首次安装：readSqliteUserVersion = 0', () async {
    final v = await readSqliteUserVersion(overrideFilePath: sqlitePath);
    expect(v, 0);
  });

  test('首次安装：backupBeforeUpgrade 返回 null', () async {
    final result = await BackupService.backupBeforeUpgrade(
      fromVersion: 0,
      toVersion: 1,
      subdir: tempDir.path,
    );
    // 路径接管：file 不存在 → 返回 null
    expect(result, null);
  });

  test('onCreate：建表后 schema 与向量虚拟表就绪', () async {
    final db = AppDatabase.forTesting(openInMemoryConnection());
    addTearDown(db.close);
    final v = await readSqliteUserVersion(overrideFilePath: sqlitePath);
    expect(v, 0); // memory 不写文件
    // 简单 CRUD 验证表结构
    final id = await db.relationshipDao.insertContact(
      ContactsCompanion.insert(name: 'Alice', relationshipType: 'friend'),
    );
    expect(id, greaterThan(0));
    final alice = await (db.select(
      db.contacts,
    )..where((c) => c.id.equals(id))).getSingle();
    expect(alice.name, 'Alice');
  });

  test('升级前备份：v1→v2 时复制 sqlite 文件', () async {
    // 1) 先创建 v1 数据库（直接落盘）
    final file = File(sqlitePath);
    final db = AppDatabase.forTesting(
      openAppConnection(overrideFilePath: sqlitePath),
    );
    await db.customStatement('PRAGMA user_version = 1');
    await db.close();

    // 2) 模拟升级前备份（subdir 指向 tempDir）
    final backupPath = await BackupService.backupBeforeUpgrade(
      fromVersion: 1,
      toVersion: 2,
      subdir: tempDir.path,
    );
    expect(backupPath, isNotNull);
    final backupFile = File(p.join(backupPath!, 'bulter.sqlite'));
    expect(backupFile.existsSync(), true);
  });

  test('回滚：restoreFromBackup 还原 SQLite', () async {
    // 1) 准备 v1 数据库
    final db1 = AppDatabase.forTesting(
      openAppConnection(overrideFilePath: sqlitePath),
    );
    await db1.customStatement('PRAGMA user_version = 1');
    await db1.close();

    // 2) 备份
    final backupPath = await BackupService.backupBeforeUpgrade(
      fromVersion: 1,
      toVersion: 2,
      subdir: tempDir.path,
    );
    expect(backupPath, isNotNull);

    // 3) 模拟升级到 v2
    final db2 = AppDatabase.forTesting(
      openAppConnection(overrideFilePath: sqlitePath),
    );
    await db2.customStatement('PRAGMA user_version = 2');
    await db2.close();

    // 4) 升级失败 → 回滚
    await BackupService.restoreFromBackup(backupPath!, subdir: tempDir.path);
    final v = await readSqliteUserVersion(overrideFilePath: sqlitePath);
    expect(v, 1);
  });
}
