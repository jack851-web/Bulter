// Bulter 第 2 步：数据导出 / 导入测试
//
// 验证：DataExportService 能在内存库上往返数据。

import 'package:bulter/db/app_database.dart';
import 'package:bulter/db/connection.dart';
import 'package:bulter/security/data_export.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

void main() {
  late AppDatabase src;
  late AppDatabase dst;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bulter_export_');
    src = AppDatabase.forTesting(openInMemoryConnection());
    dst = AppDatabase.forTesting(openInMemoryConnection());

    // 准备测试数据
    await src.relationshipDao.insertContact(
      ContactsCompanion.insert(
        name: 'Alice',
        relationshipType: 'friend',
        importance: const Value(5),
      ),
    );
    await src.wealthDao.insertAccount(
      AccountsCompanion.insert(name: 'Wallet', type: 'cash'),
    );
    await src.thoughtDao.insertThought(
      ThoughtsCompanion.insert(
        content: 'body',
        source: 'book',
        recordedAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await src.close();
    await dst.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('exportTo + importFrom 往返后行数一致', () async {
    final exporter = DataExportService(src);
    final path = p.join(tempDir.path, 'export.json');
    final bytes = await exporter.exportTo(path);
    expect(bytes, greaterThan(0));

    final importer = DataExportService(dst);
    final rows = await importer.importFrom(path);
    expect(rows, greaterThan(0));

    // 验证导入后数据一致
    final contacts = await dst.select(dst.contacts).get();
    expect(contacts.length, 1);
    expect(contacts.first.name, 'Alice');
  });

  test('importFrom 在空库上安全执行（仅空表）', () async {
    final exporter = DataExportService(src);
    final path = p.join(tempDir.path, 'export2.json');
    await exporter.exportTo(path);

    final dst2 = AppDatabase.forTesting(openInMemoryConnection());
    addTearDown(dst2.close);
    final importer = DataExportService(dst2);
    final rows = await importer.importFrom(path);
    expect(rows, greaterThan(0));
  });

  test('importFrom 文件不存在抛出 FileSystemException', () async {
    final importer = DataExportService(dst);
    expect(
      () => importer.importFrom(p.join(tempDir.path, 'nope.json')),
      throwsA(isA<FileSystemException>()),
    );
  });
}
