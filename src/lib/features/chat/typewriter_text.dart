import 'dart:async';

import 'package:flutter/material.dart';

/// 流式打字机组件（Step 11）。
///
/// **两种模式**：
/// - **流式**（streamed=true）：目标文本实时变化（每次 setState 触发），组件按字符逐步显示。
///   - 用于：AI 实时 streaming（每个 chunk 到来时显示新字符）。
/// - **完成态**（streamed=false）：目标文本不再变化，直接显示完整文本，无打字机效果。
///
/// **设计**：
/// - 每次 widget 重建时，比较 `text` 与已显示字符 → 增量追加
/// - 每 [charDelay] 显示一个字符（默认 30ms）
/// - 打字机模式下隐藏光标（更真实）
/// - 完成后**切回正常 Text**（保留性能，避免大文本持续 setState）
class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final int charDelayMs;
  final bool streamed;

  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
    this.charDelayMs = 30,
    this.streamed = true,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  Timer? _timer;
  String _shown = '';
  int _targetIndex = 0;

  @override
  void initState() {
    super.initState();
    _syncWithTarget();
  }

  @override
  void didUpdateWidget(covariant TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _syncWithTarget();
    }
  }

  void _syncWithTarget() {
    if (!widget.streamed) {
      _timer?.cancel();
      _shown = widget.text;
      _targetIndex = widget.text.length;
      return;
    }
    // 如果新文本是旧文本的扩展（典型 streaming 模式）
    if (widget.text.startsWith(_shown)) {
      _targetIndex = widget.text.length;
      _ensureTimer();
      return;
    }
    // 否则（非典型情况，例如 reset）—— 立即跳到目标
    _shown = widget.text;
    _targetIndex = widget.text.length;
    _timer?.cancel();
    setState(() {});
  }

  void _ensureTimer() {
    _timer ??= Timer.periodic(
      Duration(milliseconds: widget.charDelayMs),
      (_) => _tick(),
    );
  }

  void _tick() {
    if (!mounted) {
      _timer?.cancel();
      return;
    }
    if (_targetIndex <= _shown.length) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    // 一次推进 1 个字符（中文 / emoji 算 1 个 visible char）
    final next = _advance(_shown, widget.text, _targetIndex);
    setState(() => _shown = next);
  }

  /// 把 `_current` 推进 1 个 Rune（Grapheme cluster）。
  String _advance(String current, String target, int targetIdx) {
    if (current.length >= targetIdx) return current;
    // 用字符迭代器拿下一个 rune
    final iter = current.runes.iterator;
    int lastEnd = 0;
    while (iter.moveNext()) {
      lastEnd = current.indexOf(String.fromCharCode(iter.current), lastEnd) + 1;
      if (lastEnd >= targetIdx) break;
    }
    // 取 1 个新字符
    if (lastEnd >= target.length) return target;
    // 简化：直接取下一个 char code（中文 / emoji 都是 surrogate pair 但 Dart string.length 按 UTF-16 code unit）
    final nextChar = target.substring(lastEnd, _nextBoundary(target, lastEnd));
    return current + nextChar;
  }

  int _nextBoundary(String s, int from) {
    if (from >= s.length) return s.length;
    int i = from + 1;
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      // 低代理 → 继续推进
      if (c >= 0xDC00 && c <= 0xDFFF) {
        i++;
        continue;
      }
      break;
    }
    return i;
  }

  bool get _isTyping => widget.streamed && _shown.length < widget.text.length;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isTyping) {
      // 打字机模式：显示已推进部分 + 闪烁光标
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(text: _shown, style: widget.style),
            const WidgetSpan(child: _BlinkingCaret()),
          ],
        ),
        textAlign: widget.textAlign,
      );
    }
    // 完成态：直接显示全部
    return Text(widget.text, style: widget.style, textAlign: widget.textAlign);
  }
}

/// 闪烁的"_"光标（打字机效果）。
class _BlinkingCaret extends StatefulWidget {
  const _BlinkingCaret();

  @override
  State<_BlinkingCaret> createState() => _BlinkingCaretState();
}

class _BlinkingCaretState extends State<_BlinkingCaret>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: const Text(
        '▍',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}
