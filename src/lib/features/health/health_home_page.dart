import 'package:bulter/db/app_database.dart';
import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../form/stream_list_view.dart';
import 'health_form.dart';

/// 健康模块主页：Tab 切换「日常记录 / 体检报告」。
class HealthHomePage extends StatelessWidget {
  const HealthHomePage();

  /// 顶栏快速添加按钮回调（公开给 AppShell 用）。
  static void openAddRecord(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HealthForm(
          title: '新增健康记录',
          onSubmit: (data) async {
            await AppDatabase.I.healthDao.insertRecord(data);
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: BulterColors.canvas,
            child: TabBar(
              labelColor: BulterColors.cta,
              unselectedLabelColor: BulterColors.textSecondary,
              indicatorColor: BulterColors.health,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(
                fontSize: BulterFontSize.bodyLg,
                fontWeight: BulterFontWeight.semibold,
              ),
              tabs: const [
                Tab(text: '记录'),
                Tab(text: '体检报告'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(children: [_RecordsTab(), _ReportsTab()]),
          ),
        ],
      ),
    );
  }
}

class _RecordsTab extends StatelessWidget {
  const _RecordsTab();

  @override
  Widget build(BuildContext context) {
    // 注：AppShell 已提供 Scaffold + FAB（AI 入口 + 模块 quickAdd），
    // 这里只放列表内容；记一笔功能通过 AppShell 顶栏 + 按钮调用 openAddRecord。
    return Container(
      color: BulterColors.canvas,
      child: StreamListView<HealthRecord>(
        stream: AppDatabase.I.healthDao.watchRecentRecords(),
        brandColor: BulterColors.health,
        emptyTitle: '还没有健康记录',
        emptyHint: '追踪心情、睡眠、运动，看见身体的变化',
        emptyIconName: 'modules/health.svg',
        itemBuilder: (context, r, idx) => _RecordRow(record: r),
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  final HealthRecord record;
  const _RecordRow({required this.record});

  static const _typeLabels = {
    'mood': ('心情', Icons.mood_outlined),
    'sleep': ('睡眠', Icons.bedtime_outlined),
    'exercise': ('运动', Icons.directions_run_rounded),
    'weight': ('体重', Icons.monitor_weight_outlined),
    'symptom': ('症状', Icons.healing_outlined),
    'other': ('其他', Icons.note_alt_outlined),
  };

  @override
  Widget build(BuildContext context) {
    final t = _typeLabels[record.type] ?? _typeLabels['other']!;
    final detail = _buildDetail(record);
    return ListCard(
      brandColor: BulterColors.health,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => HealthForm(
            title: '编辑记录',
            initial: record,
            onSubmit: (data) async {
              await AppDatabase.I.healthDao.updateRecord(data);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ),
      ),
      trailing: IconButton(
        icon: const Icon(
          Icons.delete_outline_rounded,
          color: BulterColors.error,
        ),
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('删除记录'),
              content: const Text('确认删除该条记录？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text(
                    '删除',
                    style: TextStyle(color: BulterColors.error),
                  ),
                ),
              ],
            ),
          );
          if (ok == true) {
            await AppDatabase.I.healthDao.deleteRecord(record.id);
          }
        },
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: BulterColors.health.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(BulterRadius.m),
            ),
            child: Icon(t.$2, color: BulterColors.health, size: 22),
          ),
          const SizedBox(width: BulterSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.$1,
                  style: const TextStyle(
                    fontSize: BulterFontSize.bodyLg,
                    fontWeight: BulterFontWeight.semibold,
                    color: BulterColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: BulterFontSize.footnote,
                    color: BulterColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (record.valueNum != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: BulterSpacing.s,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: BulterColors.health.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(BulterRadius.pill),
              ),
              child: Text(
                _badge(record),
                style: const TextStyle(
                  fontSize: BulterFontSize.caption,
                  color: BulterColors.health,
                  fontWeight: BulterFontWeight.semibold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _badge(HealthRecord r) {
    final v = r.valueNum!;
    final unit = r.unit ?? '';
    if (v == v.roundToDouble()) {
      return '${v.toInt()}$unit';
    }
    return '${v.toStringAsFixed(1)}$unit';
  }

  String _buildDetail(HealthRecord r) {
    final date =
        '${r.occurredAt.year}-${r.occurredAt.month.toString().padLeft(2, '0')}-${r.occurredAt.day.toString().padLeft(2, '0')}';
    final parts = <String>[date];
    if ((r.valueText ?? '').isNotEmpty) parts.add(r.valueText!);
    if ((r.notes ?? '').isNotEmpty) parts.add(r.notes!);
    return parts.join(' · ');
  }
}

class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context) {
    // 注：AppShell 已提供 Scaffold，这里只放内容。
    return Container(
      color: BulterColors.canvas,
      child: StreamBuilder<List<CheckupReport>>(
        stream: AppDatabase.I.healthDao.watchReports(),
        builder: (context, snap) {
          final reports = snap.data ?? const <CheckupReport>[];
          if (reports.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(BulterSpacing.xxl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.medical_information_outlined,
                      size: 48,
                      color: BulterColors.textTertiary,
                    ),
                    SizedBox(height: BulterSpacing.l),
                    Text(
                      '还没有体检报告',
                      style: TextStyle(
                        fontSize: BulterFontSize.titleS,
                        color: BulterColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: BulterSpacing.s),
                    Text(
                      '从浮窗截图或 AI 对话导入体检报告\n（即将推出）',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: BulterFontSize.footnote,
                        color: BulterColors.textTertiary,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(BulterSpacing.l),
            itemCount: reports.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: BulterSpacing.m),
            itemBuilder: (context, i) {
              final r = reports[i];
              return ListCard(
                brandColor: BulterColors.health,
                child: Row(
                  children: [
                    const Icon(
                      Icons.assignment_outlined,
                      color: BulterColors.health,
                    ),
                    const SizedBox(width: BulterSpacing.m),
                    Expanded(
                      child: Text(
                        r.hospital,
                        style: const TextStyle(
                          fontSize: BulterFontSize.bodyLg,
                          fontWeight: BulterFontWeight.semibold,
                          color: BulterColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      r.examDate.toString().substring(0, 10),
                      style: const TextStyle(
                        fontSize: BulterFontSize.footnote,
                        color: BulterColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
