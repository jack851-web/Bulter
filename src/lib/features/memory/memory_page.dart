import 'package:flutter/material.dart';

import '../../ai/ai_service.dart';
import '../../ai/rag/retriever.dart';
import '../../components/bulter_scaffold.dart';
import '../../components/svg_icon.dart';
import '../../db/app_database.dart';
import '../../theme/tokens.dart';

/// 长期记忆页（Step 6：浏览 + 语义搜索）。
///
/// **结构**：
///   - 顶部"全部 / 搜索"segment 切换
///   - 全部 Tab：按 fact / preference / relationship / event 分组浏览，支持左滑删除
///   - 搜索 Tab：输入关键词 → RAG 语义检索 → 展示相似度分数 + 来源时间 + 类型
class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key});

  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: BulterScaffold(
        title: '记忆',
        actions: [
          IconButton(
            icon: const SvgIcon('common/info.svg', size: 20),
            onPressed: () => _showInfo(context),
          ),
        ],
        child: Column(
          children: [
            const _SegmentBar(),
            const Expanded(
              child: TabBarView(
                children: [_AllMemoriesTab(), _SemanticSearchTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BulterRadius.l),
        ),
        title: const Text('关于长期记忆'),
        content: const Text(
          'Bulter 会从对话中自动提取值得长期记住的事实。'
          '记忆类型包括：\n'
          '· 事实：客观信息（生日、健康状况等）\n'
          '· 偏好：用户喜欢或不喜欢的事物\n'
          '· 关系：重要的人际关系\n'
          '· 事件：重要的人生节点\n\n'
          '"搜索"Tab 用语义检索：输入关键词（如"妈妈"），会召回所有相关记忆，'
          '即使原文没有这些字（如"母亲生日"也能命中"妈妈生日是 3 月 5 号"）。',
          style: TextStyle(
            fontSize: BulterFontSize.body,
            color: BulterColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Segment 切换（"全部" / "搜索"）
// ============================================================

class _SegmentBar extends StatelessWidget {
  const _SegmentBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        BulterSpacing.l,
        0,
        BulterSpacing.l,
        BulterSpacing.s,
      ),
      decoration: BoxDecoration(
        color: BulterColors.surfaceMuted,
        borderRadius: BorderRadius.circular(BulterRadius.pill),
      ),
      child: TabBar(
        labelColor: BulterColors.ctaText,
        unselectedLabelColor: BulterColors.textSecondary,
        indicator: BoxDecoration(
          color: BulterColors.cta,
          borderRadius: BorderRadius.circular(BulterRadius.pill),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerHeight: 0,
        labelStyle: const TextStyle(
          fontSize: BulterFontSize.body,
          fontWeight: BulterFontWeight.semibold,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: BulterFontSize.body,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: '全部'),
          Tab(text: '搜索'),
        ],
      ),
    );
  }
}

// ============================================================
// Tab 1：全部（按类型分组浏览）
// ============================================================

class _AllMemoriesTab extends StatelessWidget {
  const _AllMemoriesTab();

  @override
  Widget build(BuildContext context) {
    final db = AppDatabase.I;
    return StreamBuilder<List<Memory>>(
      stream: db.aiDao.watchMemories(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final memories = snap.data ?? [];
        if (memories.isEmpty) {
          return _EmptyBrowse();
        }
        return _MemoryList(memories: memories);
      },
    );
  }
}

class _EmptyBrowse extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BulterSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SvgIcon(
              'common/inbox.svg',
              size: 56,
              color: BulterColors.textTertiary,
            ),
            SizedBox(height: BulterSpacing.l),
            Text(
              '暂无记忆',
              style: TextStyle(
                fontSize: BulterFontSize.titleS,
                fontWeight: BulterFontWeight.semibold,
                color: BulterColors.textPrimary,
              ),
            ),
            SizedBox(height: BulterSpacing.s),
            Text(
              '与 Bulter 对话后，\n它会自动记住重要的信息',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: BulterFontSize.body,
                color: BulterColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryList extends StatelessWidget {
  final List<Memory> memories;
  const _MemoryList({required this.memories});

  @override
  Widget build(BuildContext context) {
    // 按类型分组
    final grouped = <String, List<Memory>>{};
    for (final m in memories) {
      grouped.putIfAbsent(m.type, () => []).add(m);
    }
    const typeOrder = ['fact', 'preference', 'relationship', 'event'];
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        final ai = typeOrder.indexOf(a);
        final bi = typeOrder.indexOf(b);
        return ai.compareTo(bi);
      });

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: BulterSpacing.s),
      itemCount: sortedKeys.length,
      itemBuilder: (context, i) {
        final type = sortedKeys[i];
        final items = grouped[type]!;
        return _TypeSection(type: type, memories: items);
      },
    );
  }
}

class _TypeSection extends StatelessWidget {
  final String type;
  final List<Memory> memories;
  const _TypeSection({required this.type, required this.memories});

  @override
  Widget build(BuildContext context) {
    final label = _typeLabel(type);
    final color = _typeColor(type);
    final icon = _typeIcon(type);
    return Padding(
      padding: const EdgeInsets.only(bottom: BulterSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: BulterSpacing.xs),
            child: Row(
              children: [
                SvgIcon(icon, size: 14, color: color),
                const SizedBox(width: BulterSpacing.xs),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: BulterFontSize.footnote,
                    fontWeight: BulterFontWeight.semibold,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: BulterSpacing.s),
                Text(
                  '${memories.length} 条',
                  style: const TextStyle(
                    fontSize: BulterFontSize.footnote,
                    color: BulterColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: BulterSpacing.s),
          Container(
            decoration: BoxDecoration(
              color: BulterColors.surface,
              borderRadius: BorderRadius.circular(BulterRadius.l),
              border: Border.all(color: BulterColors.divider, width: 0.5),
            ),
            child: Column(
              children: [
                for (var i = 0; i < memories.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 0.5, indent: BulterSpacing.l),
                  _MemoryTile(memory: memories[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryTile extends StatelessWidget {
  final Memory memory;
  const _MemoryTile({required this.memory});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(memory.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: BulterSpacing.l),
        color: BulterColors.error.withValues(alpha: 0.1),
        child: const SvgIcon(
          'common/error.svg',
          size: 20,
          color: BulterColors.error,
        ),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => _deleteMemory(context),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BulterSpacing.l,
            vertical: BulterSpacing.m,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  memory.content,
                  style: const TextStyle(
                    fontSize: BulterFontSize.body,
                    color: BulterColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: BulterSpacing.s),
              Text(
                _formatDate(memory.createdAt),
                style: const TextStyle(
                  fontSize: BulterFontSize.footnote,
                  color: BulterColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BulterRadius.l),
        ),
        title: const Text('删除记忆'),
        content: Text(
          '确定要删除这条记忆吗？\n\n"${memory.content}"',
          style: const TextStyle(
            fontSize: BulterFontSize.body,
            color: BulterColors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: BulterColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteMemory(BuildContext context) async {
    try {
      await AppDatabase.I.aiDao.deleteMemory(memory.id);
    } catch (e, st) {
      debugPrint('MemoryPage: 删除失败: $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('删除失败'),
            backgroundColor: BulterColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BulterRadius.m),
            ),
          ),
        );
      }
    }
  }
}

// ============================================================
// Tab 2：语义搜索（输入关键词 → RAG 召回）
// ============================================================

class _SemanticSearchTab extends StatefulWidget {
  const _SemanticSearchTab();

  @override
  State<_SemanticSearchTab> createState() => _SemanticSearchTabState();
}

class _SemanticSearchTabState extends State<_SemanticSearchTab> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  List<RetrievalHit> _hits = [];
  bool _searching = false;
  String? _error;
  String? _lastQuery;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    final retriever = AiService.rag?.injector.retriever;
    if (retriever == null) {
      setState(() {
        _error = '记忆子系统未就绪，请稍后重试';
        _hits = [];
        _lastQuery = query;
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
      _lastQuery = query;
    });
    try {
      final hits = await retriever.retrieve(
        query,
        options: const RetrievalOptions(
          k: 8,
          minSimilarity: 0.30,
          dedupeBySource: false,
        ),
      );
      if (!mounted) return;
      setState(() {
        _hits = hits;
        _searching = false;
      });
    } catch (e, st) {
      debugPrint('MemoryPage 语义搜索失败: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = '搜索失败：${e.toString().split('\n').first}';
        _searching = false;
      });
    }
  }

  void _clear() {
    _controller.clear();
    setState(() {
      _hits = [];
      _error = null;
      _lastQuery = null;
    });
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final hasRag = AiService.rag != null;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            BulterSpacing.l,
            BulterSpacing.s,
            BulterSpacing.l,
            BulterSpacing.m,
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: BulterColors.surface,
                    borderRadius: BorderRadius.circular(BulterRadius.l),
                    border: Border.all(color: BulterColors.divider, width: 0.6),
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: BulterSpacing.m,
                        ),
                        child: SvgIcon(
                          'common/circle.svg',
                          size: 16,
                          color: BulterColors.textTertiary,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focus,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _runSearch(),
                          decoration: InputDecoration(
                            hintText: '输入关键词，如"妈妈"、"Kotlin"',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            hintStyle: const TextStyle(
                              color: BulterColors.textTertiary,
                              fontSize: BulterFontSize.body,
                            ),
                          ),
                        ),
                      ),
                      if (_controller.text.isNotEmpty)
                        IconButton(
                          icon: const SvgIcon(
                            'common/close.svg',
                            size: 14,
                            color: BulterColors.textSecondary,
                          ),
                          onPressed: _clear,
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: BulterSpacing.s),
              Material(
                color: BulterColors.cta,
                borderRadius: BorderRadius.circular(BulterRadius.l),
                child: InkWell(
                  borderRadius: BorderRadius.circular(BulterRadius.l),
                  onTap: _searching ? null : _runSearch,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: BulterSpacing.l,
                      vertical: 12,
                    ),
                    child: _searching
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: BulterColors.ctaText,
                            ),
                          )
                        : const Text(
                            '搜索',
                            style: TextStyle(
                              color: BulterColors.ctaText,
                              fontSize: BulterFontSize.body,
                              fontWeight: BulterFontWeight.semibold,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildResults(hasRag)),
      ],
    );
  }

  Widget _buildResults(bool hasRag) {
    if (!hasRag) {
      return _SearchHint(
        icon: 'common/info.svg',
        title: '记忆子系统未就绪',
        body: 'RAG / 长记忆未绑定，搜索功能暂不可用。\n请检查 app_bootstrap 启动流程。',
      );
    }
    if (_error != null) {
      return _SearchHint(
        icon: 'common/error.svg',
        title: '搜索失败',
        body: _error!,
      );
    }
    if (_lastQuery == null) {
      return _SearchHint(
        icon: 'common/circle.svg',
        title: '用自然语言搜索',
        body:
            '输入任意关键词或句子，Bulter 会按语义相似度召回。\n例如：搜索"妈妈" → 命中"妈妈生日是 3 月 5 号"、"妈妈喜欢花茶"。',
      );
    }
    if (_searching) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_hits.isEmpty) {
      return _SearchHint(
        icon: 'common/circle.svg',
        title: '没有相关记忆',
        body: '"$_lastQuery" 暂时没有命中任何长记忆。\n试试更口语化的描述，或先和 Bulter 多聊聊。',
      );
    }
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        BulterSpacing.l,
        0,
        BulterSpacing.l,
        BulterSpacing.huge,
      ),
      itemCount: _hits.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: BulterSpacing.s),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: BulterSpacing.s),
            child: Text(
              '"$_lastQuery" · 命中 ${_hits.length} 条',
              style: const TextStyle(
                fontSize: BulterFontSize.footnote,
                color: BulterColors.textTertiary,
              ),
            ),
          );
        }
        final h = _hits[i - 1];
        return _SearchHitCard(hit: h);
      },
    );
  }
}

class _SearchHitCard extends StatelessWidget {
  final RetrievalHit hit;
  const _SearchHitCard({required this.hit});

  @override
  Widget build(BuildContext context) {
    final simPct = (hit.similarity * 100).toStringAsFixed(0);
    final simColor = _simColor(hit.similarity);
    return Container(
      padding: const EdgeInsets.all(BulterSpacing.m),
      decoration: BoxDecoration(
        color: BulterColors.surface,
        borderRadius: BorderRadius.circular(BulterRadius.l),
        border: Border.all(color: BulterColors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  hit.raw.chunkText,
                  style: const TextStyle(
                    fontSize: BulterFontSize.body,
                    color: BulterColors.textPrimary,
                    height: 1.45,
                    fontWeight: BulterFontWeight.medium,
                  ),
                ),
              ),
              const SizedBox(width: BulterSpacing.s),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: BulterSpacing.s,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: simColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(BulterRadius.pill),
                ),
                child: Text(
                  '$simPct%',
                  style: TextStyle(
                    fontSize: BulterFontSize.caption,
                    color: simColor,
                    fontWeight: BulterFontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: BulterSpacing.s),
          Row(
            children: [
              SvgIcon(
                _sourceIcon(hit.source),
                size: 12,
                color: BulterColors.textTertiary,
              ),
              const SizedBox(width: 4),
              Text(
                '${_sourceLabel(hit.source)} #${hit.sourceId}',
                style: const TextStyle(
                  fontSize: BulterFontSize.caption,
                  color: BulterColors.textTertiary,
                ),
              ),
              const Spacer(),
              Container(
                height: 4,
                width: 60,
                decoration: BoxDecoration(
                  color: BulterColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  widthFactor: hit.similarity,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      color: simColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _simColor(double sim) {
    if (sim >= 0.75) return BulterColors.success;
    if (sim >= 0.50) return BulterColors.wealth;
    return BulterColors.textTertiary;
  }

  String _sourceLabel(String source) => switch (source) {
    'memory' => '长记忆',
    'thought' => '想法',
    'transaction' => '账单',
    _ => source,
  };

  String _sourceIcon(String source) => switch (source) {
    'memory' => 'common/circle.svg',
    'thought' => 'modules/thought.svg',
    'transaction' => 'modules/wealth.svg',
    _ => 'common/circle.svg',
  };
}

class _SearchHint extends StatelessWidget {
  final String icon;
  final String title;
  final String body;
  const _SearchHint({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BulterSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgIcon(icon, size: 48, color: BulterColors.textTertiary),
            const SizedBox(height: BulterSpacing.l),
            Text(
              title,
              style: const TextStyle(
                fontSize: BulterFontSize.titleS,
                fontWeight: BulterFontWeight.semibold,
                color: BulterColors.textPrimary,
              ),
            ),
            const SizedBox(height: BulterSpacing.s),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: BulterFontSize.body,
                color: BulterColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 共享工具
// ============================================================

String _typeLabel(String type) {
  switch (type) {
    case 'fact':
      return '事实';
    case 'preference':
      return '偏好';
    case 'relationship':
      return '关系';
    case 'event':
      return '事件';
    default:
      return type;
  }
}

Color _typeColor(String type) {
  switch (type) {
    case 'fact':
      return BulterColors.cta;
    case 'preference':
      return BulterColors.wealth;
    case 'relationship':
      return BulterColors.health;
    case 'event':
      return BulterColors.growth;
    default:
      return BulterColors.textSecondary;
  }
}

String _typeIcon(String type) {
  switch (type) {
    case 'fact':
      return 'common/circle.svg';
    case 'preference':
      return 'common/heart.svg';
    case 'relationship':
      return 'common/people.svg';
    case 'event':
      return 'common/star.svg';
    default:
      return 'common/circle.svg';
  }
}

String _formatDate(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inDays == 0) return '今天';
  if (diff.inDays == 1) return '昨天';
  if (diff.inDays < 7) return '${diff.inDays}天前';
  return '${dt.month}/${dt.day}';
}
