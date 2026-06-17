import 'package:hive_flutter/hive_flutter.dart';

import 'box_names.dart';

/// 初始化 Hive。必须在 runApp 前调用一次。
///
/// - [subdir] 可指定子目录（测试场景可传临时目录）。
/// - Box 在首次访问时按需打开；不预先 open，避免模块未注册时报错。
///
/// 测试 / 桌面环境没有 path_provider 时，可传 [subdir] 让 Hive 直接落到
/// 临时目录，避免 `getApplicationDocumentsDirectory` 抛 `MissingPluginException`。
Future<void> initStorage({String? subdir}) async {
  if (subdir != null) {
    Hive.init(subdir);
  } else {
    await Hive.initFlutter();
  }
}

/// 打开一个 KV Box。
///
/// Hive 2.2.x 没有 `versionId` / `migrate` 概念，因此 schema 升级时通过
/// 重命名 box 自身实现（保留旧 box 作 fallback，由调用方处理）。当前实现
/// 只负责幂等打开。
Future<Box<T>> openTypedBox<T>(String name) async {
  if (Hive.isBoxOpen(name)) {
    return Hive.box<T>(name);
  }
  return Hive.openBox<T>(name);
}

/// 已知的 Box 名称列表（用于启动时预热 / 调试输出）。
List<String> knownBoxNames() => BulterBoxes.versionIds.keys.toList();
