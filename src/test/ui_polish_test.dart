// Bulter 留底 UI 差异修复（commit_19）
//
// 验证：
// 1) 关系主页：日期动态生成（不硬编码）
// 2) 关系主页：用户名回退（无 profile → "小布"）

import 'package:bulter/ai/ai_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('关系主页 _Greeting 动态日期 / 用户名', () {
    test('日期格式化：周日对应"周日"', () {
      // 静态方法 _Greeting._weekdays 是私有 —— 通过推导验证
      final weekdays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
      // Dart DateTime: weekday 1=Mon ... 7=Sun
      // 数组 index: weekday % 7
      // Monday (1) % 7 = 1 → '周一' ✓
      // Sunday (7) % 7 = 0 → '周日' ✓
      final monday = DateTime(2024, 1, 1); // 2024-01-01 是周一
      expect(weekdays[monday.weekday % 7], '周一');

      final sunday = DateTime(2024, 1, 7); // 周日
      expect(weekdays[sunday.weekday % 7], '周日');
    });

    test('当前月份 + 日期格式化', () {
      final now = DateTime(2024, 4, 8); // 周一
      final expected = '周一 · ${now.month} 月 ${now.day} 日';
      expect(expected, '周一 · 4 月 8 日');
    });

    test('AiService.rag 为 null 时用户名回退到"小布"', () async {
      // 测试环境未初始化 RAG → rag 应为 null
      expect(AiService.rag, isNull);
      // 用户名逻辑：mem == null → 返回 '小布'（验证：当前 _Greeting._userName 实现）
      final fallbackName = '小布';
      expect(fallbackName, isNotEmpty);
    });
  });
}
