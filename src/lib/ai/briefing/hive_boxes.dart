import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../storage/box_names.dart';

/// 简报系统用的 Hive Box 辅助。
///
/// 单独抽出来避免在 [BriefingStore] 里堆 Hive API；其他模块照这个模式扩展。
class HiveBoxes {
  HiveBoxes._();

  static Box<String>? _briefings;

  /// 打开简报缓存 Box（key = moduleId, value = JSON 字符串）。
  static Future<void> openBriefingsBox() async {
    if (_briefings != null && _briefings!.isOpen) return;
    try {
      _briefings = await Hive.openBox<String>(
        BulterBoxes.briefingsCache,
      );
      debugPrint('HiveBoxes: ${BulterBoxes.briefingsCache} 已打开');
    } catch (e) {
      debugPrint('HiveBoxes: 打开 ${BulterBoxes.briefingsCache} 失败 - $e');
      _briefings = null;
    }
  }

  static Box<String>? get briefingsBox => _briefings;
}
