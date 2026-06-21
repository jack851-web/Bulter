import 'package:flutter/material.dart';

import '../components/bottom_tab.dart';
import '../components/bulter_scaffold.dart';
import '../components/capule_switcher.dart';
import '../components/fab_chat.dart';
import '../components/svg_icon.dart';
import '../modules/bulter_module.dart';
import '../modules/registry.dart';
import '../theme/tokens.dart';
import '../features/chat/chat_page.dart';
import '../features/growth/growth_home_page.dart';
import '../features/health/health_home_page.dart';
import '../features/memory/memory_page.dart';
import '../features/relationship/relationship_home_page.dart';
import '../features/settings/model_config_page.dart';
import '../features/settings/settings_page.dart';
import '../features/settings/user_profile_page.dart';
import '../features/thought/thought_home_page.dart';
import '../features/wealth/wealth_home_page.dart';

/// 应用主壳：顶部 capsule + 内容 + 底部 Tab + AI FAB。
///
/// **受控组件**：模块切换由父级（`_ShellHost`，即 `StatefulShellRoute`）通过
/// [activeIndex] / [onIndexChange] 驱动，本组件不维护"当前模块"状态。
/// 数据源：[ModuleRegistry.capsuleModules]，**不硬编码模块列表**。
class AppShell extends StatefulWidget {
  final List<BulterModule> modules;
  final int activeIndex;
  final ValueChanged<int> onIndexChange;

  const AppShell({
    super.key,
    required this.modules,
    required this.activeIndex,
    required this.onIndexChange,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tabIndex = 0;
  bool _chatOpen = false;
  bool _settingsOpen = false;

  BulterModule get _activeModule {
    final i = widget.activeIndex;
    if (i < 0 || i >= widget.modules.length) {
      return widget.modules.isNotEmpty
          ? widget.modules.first
          : _MissingModule.instance;
    }
    return widget.modules[i];
  }

  void _switchModule(BulterModule m) {
    final i = widget.modules.indexWhere((e) => e.id == m.id);
    if (i < 0 || i == widget.activeIndex) return;
    setState(() => _tabIndex = 0);
    widget.onIndexChange(i);
  }

  void _openChat() => setState(() => _chatOpen = true);
  void _closeChat() => setState(() => _chatOpen = false);
  void _openSettings() => setState(() => _settingsOpen = true);
  void _closeSettings() => setState(() => _settingsOpen = false);

  /// 顶部 + 按钮：上下文感知的快速添加。
  ///
  /// - 关系模块 → 加联系人
  /// - 成长模块 → 加 OKR
  /// - 财富模块 → 加账单
  /// - 思想模块 → 加想法
  /// - 健康模块 → 加记录
  /// - 中枢 / 其他 → 弹出全局 quick add 菜单
  void _quickAdd() {
    final m = _activeModule;
    final action = m.quickAdd;
    if (action != null) {
      action(context);
      return;
    }
    _openGlobalQuickAdd();
  }

  void _openGlobalQuickAdd() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: BulterColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(BulterRadius.xl),
        ),
      ),
      builder: (_) => const _GlobalQuickAddSheet(),
    );
  }

  /// 顶栏 ⋯ 按钮：更多菜单。
  ///
  /// 当前提供：
  /// - 导出全部数据
  /// - 重新扫描 / 重置布局（占位）
  /// - 帮助
  void _openMoreMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: BulterColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(BulterRadius.xl),
        ),
      ),
      builder: (_) => const _MoreMenuSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_chatOpen) {
      return BulterScaffold(
        title: 'AI 对话',
        actions: [
          IconButton(
            onPressed: _closeChat,
            icon: const SvgIcon('common/close.svg', size: 20),
          ),
        ],
        child: const ChatPage(),
      );
    }
    if (_settingsOpen) {
      return Stack(
        children: [
          const SettingsPage(),
          Positioned(
            top: BulterSpacing.l,
            right: BulterSpacing.l,
            child: SafeArea(
              child: Material(
                color: BulterColors.surface,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _closeSettings,
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: BulterColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final active = _activeModule;
    final tabs = active.tabs;
    final hasTabs = tabs.isNotEmpty;
    final body = hasTabs
        ? IndexedStack(
            index: _tabIndex.clamp(0, tabs.length - 1),
            children: tabs.map((t) => t.builder(context)).toList(),
          )
        : active.buildHomePage(context);

    return Scaffold(
      backgroundColor: BulterColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 顶部：胶囊切换器 + 右侧 3 个圆形动作 [+  tune  ⋯]
            Padding(
              padding: const EdgeInsets.only(
                top: BulterSpacing.s,
                bottom: BulterSpacing.s,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: CapsuleSwitcher(
                      modules: widget.modules,
                      activeModuleId: active.id,
                      onChanged: _switchModule,
                    ),
                  ),
                  const SizedBox(width: BulterSpacing.s),
                  _CircleActionButton(
                    iconName: 'common/plus.svg',
                    onTap: _quickAdd,
                    semanticLabel: '快速添加',
                  ),
                  const SizedBox(width: BulterSpacing.s),
                  _CircleActionButton(
                    iconName: 'common/tune.svg',
                    onTap: _openSettings,
                    semanticLabel: '设置',
                  ),
                  const SizedBox(width: BulterSpacing.s),
                  _CircleActionButton(
                    iconName: 'common/ellipsis-horizontal.svg',
                    onTap: _openMoreMenu,
                    semanticLabel: '更多',
                  ),
                  const SizedBox(width: BulterSpacing.l),
                ],
              ),
            ),
            // 内容
            Expanded(child: body),
            // 底部 Tab + FAB
            if (hasTabs)
              _buildBottomArea(tabs, _tabIndex, (i) {
                setState(() => _tabIndex = i);
              }, _openChat),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomArea(
    List<ModuleTab> tabs,
    int activeIndex,
    ValueChanged<int> onTab,
    VoidCallback onFab,
  ) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        BulterBottomTab(
          tabs: [
            for (final t in tabs)
              TabItem(id: t.id, label: t.label, iconName: t.iconName),
          ],
          activeIndex: activeIndex,
          onChanged: onTab,
        ),
        Positioned(top: -28, child: AiChatFab(onTap: onFab)),
      ],
    );
  }
}

/// `_MissingModule`：activeIndex 越界时的兜底，避免空指针。
/// 该模块不进入注册表，仅用于 AppShell 内部防御。
class _MissingModule implements BulterModule {
  static final _MissingModule instance = _MissingModule._();
  _MissingModule._();

  @override
  String get id => ModuleId.butler;
  @override
  String get displayName => 'Bulter';
  @override
  Color get brandColor => BulterColors.butler;
  @override
  String get iconName => 'sparkles';
  @override
  String get entryRoute => '/butler';
  @override
  Widget buildHomePage(BuildContext context) => const SizedBox.shrink();
  @override
  List<ModuleTab> get tabs => const [];
  @override
  bool get hasSubAgent => false;
  @override
  SpecialistAgent? get subAgent => null;
  @override
  void Function(BuildContext)? get quickAdd => null;
  @override
  List<ToolDefinition> get tools => const [];
  @override
  BriefingGenerator? get briefingGenerator => null;
  @override
  Future<void> onRegister() async {}
  @override
  Future<void> onDispose() async {}
  @override
  List<Type> get tableClasses => const [];
  @override
  List<Type> get daoClasses => const [];
}

/// 顶栏右侧圆形动作按钮（+/tune/⋯）。
///
/// 规格：36×36 白底浅描边圆，按下 0.92 缩放 + 0.06 透明度反馈。
class _CircleActionButton extends StatelessWidget {
  final String iconName;
  final VoidCallback onTap;
  final String semanticLabel;

  const _CircleActionButton({
    required this.iconName,
    required this.onTap,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: BulterColors.surface,
        shape: const CircleBorder(
          side: BorderSide(color: BulterColors.divider, width: 0.5),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: SvgIcon(
                iconName,
                size: 18,
                color: BulterColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 全局 quick add 菜单（中枢等无 quickAdd 模块的降级方案）。
class _GlobalQuickAddSheet extends StatelessWidget {
  const _GlobalQuickAddSheet();

  @override
  Widget build(BuildContext context) {
    final items = <_QuickAddItem>[
      _QuickAddItem(
        '关系',
        '新增联系人',
        'modules/relationship.svg',
        BulterColors.relationship,
        () => RelationshipHomePage.openAddContact(context),
      ),
      _QuickAddItem(
        '财富',
        '记一笔',
        'modules/wealth.svg',
        BulterColors.wealth,
        () => WealthHomePage.openAddTransaction(context),
      ),
      _QuickAddItem(
        '成长',
        '新增目标',
        'modules/growth.svg',
        BulterColors.growth,
        () => GrowthHomePage.openAddGoal(context),
      ),
      _QuickAddItem(
        '思想',
        '记一条想法',
        'modules/thought.svg',
        BulterColors.thought,
        () => ThoughtHomePage.openAddThought(context),
      ),
      _QuickAddItem(
        '健康',
        '新增健康记录',
        'modules/health.svg',
        BulterColors.health,
        () => HealthHomePage.openAddRecord(context),
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          BulterSpacing.l,
          BulterSpacing.s,
          BulterSpacing.l,
          BulterSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部拖把柄
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: BulterColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: BulterSpacing.l),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: BulterSpacing.s),
              child: Text(
                '快速添加',
                style: TextStyle(
                  fontSize: BulterFontSize.titleL,
                  fontWeight: BulterFontWeight.bold,
                  color: BulterColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: BulterSpacing.s),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: BulterSpacing.s),
              child: Text(
                '选一个要添加的内容类型',
                style: TextStyle(
                  fontSize: BulterFontSize.footnote,
                  color: BulterColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: BulterSpacing.m),
            for (final it in items) ...[
              _QuickAddRow(item: it),
              const SizedBox(height: BulterSpacing.s),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickAddItem {
  final String moduleName;
  final String label;
  final String iconName;
  final Color color;
  final VoidCallback onTap;
  _QuickAddItem(
    this.moduleName,
    this.label,
    this.iconName,
    this.color,
    this.onTap,
  );
}

class _QuickAddRow extends StatelessWidget {
  final _QuickAddItem item;
  const _QuickAddRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BulterColors.surface,
      borderRadius: BorderRadius.circular(BulterRadius.l),
      child: InkWell(
        borderRadius: BorderRadius.circular(BulterRadius.l),
        onTap: () {
          Navigator.of(context).pop();
          item.onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BulterSpacing.m,
            vertical: BulterSpacing.m,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(BulterRadius.m),
                ),
                child: SvgIcon(item.iconName, size: 18, color: item.color),
              ),
              const SizedBox(width: BulterSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: const TextStyle(
                        fontSize: BulterFontSize.body,
                        fontWeight: BulterFontWeight.semibold,
                        color: BulterColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '进入 ${item.moduleName} 模块',
                      style: const TextStyle(
                        fontSize: BulterFontSize.caption,
                        color: BulterColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SvgIcon(
                'common/chevron-right.svg',
                size: 16,
                color: BulterColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 顶栏 ⋯ 按钮弹出的"更多菜单"。
class _MoreMenuSheet extends StatelessWidget {
  const _MoreMenuSheet();

  @override
  Widget build(BuildContext context) {
    final items = <_MoreItem>[
      _MoreItem(
        iconName: 'common/download.svg',
        title: '导出全部数据',
        subtitle: '把数据库导出为 JSON',
        onTap: () {
          Navigator.of(context).pop();
          _exportData(context);
        },
      ),
      _MoreItem(
        iconName: 'common/sparkles.svg',
        title: 'AI 助理配置',
        subtitle: '模型 / API Key / 温度',
        onTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: ModelConfigPage()),
            ),
          );
        },
      ),
      _MoreItem(
        iconName: 'common/user.svg',
        title: '用户画像',
        subtitle: '查看 / 编辑 AI 对你的理解',
        onTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: UserProfilePage()),
            ),
          );
        },
      ),
      _MoreItem(
        iconName: 'common/inbox.svg',
        title: '长期记忆',
        subtitle: 'RAG 召回 / 字面检索',
        onTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: MemoryPage()),
            ),
          );
        },
      ),
      _MoreItem(
        iconName: 'common/info.svg',
        title: '关于 Bulter',
        subtitle: '0.7.0 · 个人 AI 管家',
        onTap: () {
          Navigator.of(context).pop();
          showAboutDialog(
            context: context,
            applicationName: 'Bulter',
            applicationVersion: '0.7.0',
            applicationIcon: const SvgIcon(
              'modules/butler.svg',
              size: 32,
              color: BulterColors.butler,
            ),
            children: const [
              SizedBox(height: BulterSpacing.s),
              Text('个人 AI 管家，把分散的人生数据收敛为可被 AI 串联的资产。'),
            ],
          );
        },
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          BulterSpacing.l,
          BulterSpacing.s,
          BulterSpacing.l,
          BulterSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: BulterColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: BulterSpacing.l),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: BulterSpacing.s),
              child: Text(
                '更多',
                style: TextStyle(
                  fontSize: BulterFontSize.titleL,
                  fontWeight: BulterFontWeight.bold,
                  color: BulterColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: BulterSpacing.m),
            for (final it in items) ...[
              _MoreRow(item: it),
              const SizedBox(height: BulterSpacing.s),
            ],
          ],
        ),
      ),
    );
  }

  void _exportData(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('导出功能 Step 18 接入（数据迁移）'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class _MoreItem {
  final String iconName;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  _MoreItem({
    required this.iconName,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

class _MoreRow extends StatelessWidget {
  final _MoreItem item;
  const _MoreRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BulterColors.surface,
      borderRadius: BorderRadius.circular(BulterRadius.l),
      child: InkWell(
        borderRadius: BorderRadius.circular(BulterRadius.l),
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BulterSpacing.m,
            vertical: BulterSpacing.m,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: BulterColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(BulterRadius.m),
                ),
                child: SvgIcon(
                  item.iconName,
                  size: 18,
                  color: BulterColors.textPrimary,
                ),
              ),
              const SizedBox(width: BulterSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: BulterFontSize.body,
                        fontWeight: BulterFontWeight.semibold,
                        color: BulterColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: const TextStyle(
                        fontSize: BulterFontSize.caption,
                        color: BulterColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SvgIcon(
                'common/chevron-right.svg',
                size: 16,
                color: BulterColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
