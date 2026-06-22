import 'package:flutter/material.dart';

/// 长回复分页组件（Step 11）。
///
/// **自动分页**：
/// - 输入完整文本 → 自动按 [pageSize] 字符切页
/// - 切页位置算标点（"。" / "！" / "？" / "\n\n"）—— 不切断句子
/// - 底部"继续"按钮 + 进度条
///
/// **为什么不一次性渲染**：
/// - 单条回复 > 2000 字符会卡 UI（重建成本 + 内存）
/// - 长文本在手机上一屏看不完，分页让用户有节奏感
class LongReplyPager extends StatefulWidget {
  final String fullText;
  final TextStyle? style;
  final int pageSize;

  /// 短于此长度不分页（直接展示全文）。
  final int minLengthForPaging;

  const LongReplyPager({
    super.key,
    required this.fullText,
    this.style,
    this.pageSize = 800,
    this.minLengthForPaging = 2000,
  });

  @override
  State<LongReplyPager> createState() => _LongReplyPagerState();
}

class _LongReplyPagerState extends State<LongReplyPager> {
  late List<String> _pages;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _pages = _split(widget.fullText, widget.pageSize);
    _current = 0;
  }

  @override
  void didUpdateWidget(covariant LongReplyPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fullText != widget.fullText ||
        oldWidget.pageSize != widget.pageSize) {
      _pages = _split(widget.fullText, widget.pageSize);
      _current = 0;
    }
  }

  /// 短于阈值 → 返回 1 页（整篇）
  /// 否则按 pageSize 切，找最近的标点
  static List<String> _split(String text, int pageSize) {
    if (text.length <= pageSize) return [text];
    final pages = <String>[];
    int start = 0;
    while (start < text.length) {
      int end = (start + pageSize).clamp(0, text.length);
      if (end >= text.length) {
        pages.add(text.substring(start));
        break;
      }
      // 在 [start+pageSize/2, end] 区间内找最近的句末标点
      final cutAt = _findBoundary(text, start + pageSize ~/ 2, end);
      pages.add(text.substring(start, cutAt));
      start = cutAt;
    }
    return pages;
  }

  static int _findBoundary(String text, int from, int to) {
    final punctuations = ['。', '！', '？', '\n\n', '.\n', '!', '?'];
    int best = to;
    int bestDist = text.length;
    for (final p in punctuations) {
      int idx = text.indexOf(p, from);
      while (idx > 0 && idx < to) {
        final dist = (to - idx).abs();
        if (dist < bestDist) {
          bestDist = dist;
          best = idx + p.length;
        }
        idx = text.indexOf(p, idx + 1);
      }
    }
    return best;
  }

  void _next() {
    if (_current < _pages.length - 1) {
      setState(() => _current++);
    }
  }

  void _prev() {
    if (_current > 0) {
      setState(() => _current--);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 短文本 → 直接展示全文（无分页 UI）
    if (widget.fullText.length < widget.minLengthForPaging) {
      return Text(widget.fullText, style: widget.style);
    }
    final isLast = _current >= _pages.length - 1;
    final isFirst = _current == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_pages[_current], style: widget.style),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '第 ${_current + 1} / ${_pages.length} 页',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const Spacer(),
            if (!isFirst)
              TextButton(
                onPressed: _prev,
                child: const Text('上一页'),
              ),
            if (!isLast)
              FilledButton(
                onPressed: _next,
                child: const Text('继续阅读'),
              ),
            if (isLast)
              Text(
                '（已读完）',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        // 进度条
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: (_current + 1) / _pages.length,
          minHeight: 2,
          backgroundColor: Colors.grey.shade300,
        ),
      ],
    );
  }
}
