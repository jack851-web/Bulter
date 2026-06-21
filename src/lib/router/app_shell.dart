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
import '../features/settings/settings_page.dart';

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
            // 顶部：胶囊切换器 + 右侧操作
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
                  Padding(
                    padding: const EdgeInsets.only(right: BulterSpacing.l),
                    child: SvgIconButton(
                      iconName: 'common/tune.svg',
                      onTap: _openSettings,
                      size: 36,
                      iconSize: 18,
                    ),
                  ),
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
