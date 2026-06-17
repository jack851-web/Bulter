// Bulter 第 1 步：项目骨架烟测
//
// 验证：
// 1) bootstrap 注册不报错
// 2) ModuleRegistry 包含 6 个内置模块 + Demo
// 3) Demo 模块也注册成功（模块化插拔）

import 'package:bulter/app_bootstrap.dart';
import 'package:bulter/modules/bulter_module.dart';
import 'package:bulter/modules/registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Step 1: bootstrap registers all modules', (tester) async {
    await bootstrapApp();
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
