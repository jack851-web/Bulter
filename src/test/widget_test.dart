// Bulter 第 1 步：项目骨架烟测
//
// 验证：
// 1) bootstrap 注册不报错
// 2) ModuleRegistry 包含 6 个内置模块 + Demo
// 3) Demo 模块也注册成功（模块化插拔）

import 'dart:io';

import 'package:bulter/ai/briefing/briefing_scheduler.dart';
import 'package:bulter/app_bootstrap.dart';
import 'package:bulter/db/app_database.dart';
import 'package:bulter/modules/bulter_module.dart';
import 'package:bulter/modules/registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    // testWidgets 之前先初始化 binding（避免 await Hive/initFlutter 等 platform channel 卡住）
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('bulter_widget_');
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
    // 删除临时目录（多次重试，吞 PathAccessException）
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

  testWidgets('Step 1: bootstrap registers all modules', (tester) async {
    // 测试环境跳过 BriefingScheduler（避免 Timer.periodic 阻止 test 退出）
    // 用 tester.runAsync 包裹真实异步操作（不被 fake async 拦截）
    await tester.runAsync(() async {
      await bootstrapApp(subdir: tempDir.path, enableScheduler: false);
    });
    final registry = ModuleRegistry.instance;
    expect(registry.isInitialized, true);
    expect(registry.get(ModuleId.butler), isNotNull);
    expect(registry.get(ModuleId.relationship), isNotNull);
    expect(registry.get(ModuleId.growth), isNotNull);
    expect(registry.get(ModuleId.wealth), isNotNull);
    expect(registry.get(ModuleId.thought), isNotNull);
    expect(registry.get(ModuleId.health), isNotNull);
    // 模块化验证：Demo 模块自动注册成功
    expect(registry.get(ModuleId.demo), isNotNull);
    expect(registry.capsuleModules.length, 7);
  });
}
