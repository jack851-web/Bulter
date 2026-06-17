// Bulter 第 2 步：模块化注册测试
//
// 验证：所有内置模块 + Demo 都能通过模块化接口向 AppDatabase 注册表 / DAO。

import 'dart:io';

import 'package:bulter/app_bootstrap.dart';
import 'package:bulter/modules/bulter_module.dart';
import 'package:bulter/modules/registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bulter_registry_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('bootstrapApp 注册 7 个模块（含 Demo）', () async {
    await bootstrapApp(subdir: tempDir.path);
    final registry = ModuleRegistry.instance;
    expect(registry.capsuleModules.length, 7);

    for (final id in const [
      ModuleId.butler,
      ModuleId.relationship,
      ModuleId.growth,
      ModuleId.wealth,
      ModuleId.thought,
      ModuleId.health,
      ModuleId.demo,
    ]) {
      final mod = registry.get(id);
      expect(mod, isNotNull, reason: '模块 $id 缺失');
      expect(mod!.tableClasses, isNotEmpty, reason: '$id 未提供 tableClasses');
      expect(mod.daoClasses, isNotEmpty, reason: '$id 未提供 daoClasses');
    }
  });
}
