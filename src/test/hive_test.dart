// Bulter 第 2 步：Hive 存储层测试
//
// 验证：BulterBoxes 集中管理的 box 名称、版本号、初始化与开 box 行为正确。

import 'dart:io';

import 'package:bulter/storage/box_names.dart';
import 'package:bulter/storage/storage_init.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('bulter_hive_');
    await initStorage(subdir: tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('BulterBoxes 4 个核心 box 名称一致', () {
    expect(BulterBoxes.userPreferences, 'bulter_user_preferences');
    expect(BulterBoxes.briefingsCache, 'bulter_briefings');
    expect(BulterBoxes.sessionsCache, 'bulter_sessions');
    expect(BulterBoxes.demoKv, 'bulter_demo_kv');
  });

  test('initStorage 幂等：二次调用不抛错', () async {
    await initStorage(subdir: tempDir.path);
    final box = await openTypedBox(BulterBoxes.userPreferences);
    expect(box.isOpen, true);
  });

  test('openTypedBox 已存在的 box 直接返回已有实例', () async {
    final box1 = await openTypedBox(BulterBoxes.briefingsCache);
    final box2 = await openTypedBox(BulterBoxes.briefingsCache);
    expect(identical(box1, box2), true);
  });

  test('knownBoxNames 返回所有 box 名称', () {
    final names = knownBoxNames();
    expect(names, contains(BulterBoxes.userPreferences));
    expect(names, contains(BulterBoxes.briefingsCache));
    expect(names.length, BulterBoxes.versionIds.length);
  });

  test('BulterBoxes.versionIds 每个 box 都有 version', () {
    expect(BulterBoxes.versionIds[BulterBoxes.userPreferences], 1);
    expect(BulterBoxes.versionIds[BulterBoxes.demoKv], 1);
  });
}
