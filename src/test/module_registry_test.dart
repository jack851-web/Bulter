// Bulter 第 2 步：模块化注册测试
//
// 验证：所有内置模块 + Demo 都能通过模块化接口向 AppDatabase 注册表 / DAO。

import 'dart:io';

import 'package:bulter/ai/briefing/briefing_scheduler.dart';
import 'package:bulter/app_bootstrap.dart';
import 'package:bulter/db/app_database.dart';
import 'package:bulter/modules/bulter_module.dart';
import 'package:bulter/modules/registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bulter_registry_');
  });

  tearDown(() async {
    // 显式关闭数据库 + 调度器（避免 Windows 下文件句柄未释放导致删除失败）
    try {
      AppDatabase.I.close();
    } catch (_) {}
    try {
      BriefingScheduler.instance.stop();
    } catch (_) {}
    await Hive.close();
    if (tempDir.existsSync()) {
      for (var i = 0; i < 3; i++) {
        try {
          await tempDir.delete(recursive: true);
          break;
        } catch (_) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    }
  });

  test('bootstrapApp 注册 7 个模块（含 Demo）', () async {
    // 测试环境跳过 BriefingScheduler（避免 Timer.periodic 阻止 test 退出）
    await bootstrapApp(subdir: tempDir.path, enableScheduler: false);
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
