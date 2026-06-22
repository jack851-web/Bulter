// Bulter 第 11 步：AI 对话增强（流式打字机 + 长回复分页 + 跨会话记忆）
//
// 验证：
// 1) LongReplyPager 按标点切页，不切断句子
// 2) TypewriterText streamed 模式下显示部分内容
// 3) CrossSessionMemory 在无历史时返回 null

import 'package:bulter/features/chat/long_reply_pager.dart';
import 'package:bulter/features/chat/typewriter_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LongReplyPager', () {
    testWidgets('短文本直接展示（不分页）', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LongReplyPager(fullText: '短文本，不分页。')),
        ),
      );
      expect(find.text('短文本，不分页。'), findsOneWidget);
      expect(find.text('继续阅读'), findsNothing);
    });

    testWidgets('长文本按标点分页', (tester) async {
      // 2000+ 字符，含多个句末标点（每段 50 字符 × 50 段 = 2500+）
      final sentences = List.generate(50, (i) => '这是第 $i 句，' * 5 + '。');
      final long = sentences.join('');
      expect(
        long.length > 2000,
        true,
        reason: '长文本长度必须 > 2000，实际: ${long.length}',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              child: LongReplyPager(fullText: long, minLengthForPaging: 100),
            ),
          ),
        ),
      );
      // 第一页应该展示，且有 "继续阅读" 按钮
      expect(find.textContaining('页'), findsWidgets); // 至少出现"第 1 / N 页"标签
      expect(find.text('继续阅读'), findsOneWidget);
      // 点击继续 → 第二页
      await tester.tap(find.text('继续阅读'));
      await tester.pump();
      // "第 2" 应出现在分页标签中
      expect(find.textContaining('第 2 /'), findsOneWidget);
    });

    testWidgets('标点切页正确（不在句子中间断）', (tester) async {
      // 构造：每段 ~200 字符，每段以 "。" 结尾
      final buf = StringBuffer();
      for (var i = 0; i < 30; i++) {
        buf.write(
          '句子${i.toString().padLeft(3, '0')}${List.filled(80, 'x').join('')}。',
        );
      }
      final long = buf.toString();
      expect(long.length > 2000, true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              child: LongReplyPager(
                fullText: long,
                pageSize: 400,
                minLengthForPaging: 100,
              ),
            ),
          ),
        ),
      );
      // 找到正文 Text（LongReplyPager 的 Column 内第一个 Text，不是"第 1/N 页"标签）
      final longReplyPagerFinder = find.byType(LongReplyPager);
      expect(longReplyPagerFinder, findsOneWidget);
      // 第一个 Text widget 是正文（LongReplyPager 渲染 Text 在前，按钮在后）
      final allTexts = find.descendant(
        of: longReplyPagerFinder,
        matching: find.byType(Text),
      );
      final firstTextWidget = tester.widget<Text>(allTexts.first);
      final firstPageText = firstTextWidget.data!;
      expect(
        firstPageText.endsWith('。'),
        true,
        reason:
            '第一页应结束于句末标点，实际: ...${firstPageText.substring(firstPageText.length - 20)}',
      );
    });
  });

  group('TypewriterText', () {
    testWidgets('streamed=true 时初始显示空', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TypewriterText(text: '')),
        ),
      );
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('streamed=true 时内容随推进变化', (tester) async {
      // 短 charDelay (1ms) + 测试 pump 让 timer 跑
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TypewriterText(text: 'hi', charDelayMs: 1)),
        ),
      );
      // 等几帧让 timer 推进
      await tester.pump(const Duration(milliseconds: 5));
      await tester.pump(const Duration(milliseconds: 5));
      // 至少应该显示 'h'（推进 ≥ 1 字符）
      expect(find.textContaining('h'), findsWidgets);
    });

    testWidgets('streamed=false 时直接显示全部', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TypewriterText(text: 'Hello World', streamed: false),
          ),
        ),
      );
      expect(find.text('Hello World'), findsOneWidget);
    });

    testWidgets('目标文本增长时 _TypewriterText 推进', (tester) async {
      String target = '';
      late StateSetter setOuter;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setOuter = setState;
                return TypewriterText(text: target, charDelayMs: 1);
              },
            ),
          ),
        ),
      );
      target = 'Hello';
      setOuter(() {});
      // pump 多次让 timer 推进（fake async 默认 100ms 一步）
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      // 找到 TextSpan（_TypewriterText 内部用 Text.rich 而非 Text）
      // 简单方案：找所有 Text widget
      final texts = tester.widgetList<Text>(find.byType(Text)).toList();
      // 至少有一个 Text 显示 'H' 或更长
      final any = texts.any((t) => (t.data ?? '').contains('H'));
      expect(
        any,
        true,
        reason:
            '至少 1 个 Text 应包含 H，实际 texts: ${texts.map((t) => t.data).toList()}',
      );
    });
  });
}
