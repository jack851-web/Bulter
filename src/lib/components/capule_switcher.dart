import 'package:flutter/material.dart';

import '../modules/bulter_module.dart';
import '../theme/tokens.dart';

/// 顶部胶囊切换器：Butler 中枢 ↔ 六大模块（原型：phone-03-dropdown.png）。
///
/// 数据源：通过 [modules] 构造参数注入（通常由 AppShell 从
/// [ModuleRegistry.capsuleModules] 取值传入），**不硬编码模块列表**。
///
/// 形态：单胶囊触发器 + 弹出式下拉菜单
///   - 触发器：当前激活模块的胶囊（含品牌色色块 + 模块名 + 下拉箭头）
///   - 弹出项：左侧品牌色色块 + 模块名 + 副标签 + 右侧 ✓（若激活）
class CapsuleSwitcher extends StatelessWidget {
  final List<BulterModule> modules;
  final String activeModuleId;
  final ValueChanged<BulterModule> onChanged;

  const CapsuleSwitcher({
    super.key,
    required this.modules,
    required this.activeModuleId,
    required this.onChanged,
  });

  BulterModule? get _active {
    for (final m in modules) {
      if (m.id == activeModuleId) return m;
    }
    return modules.isNotEmpty ? modules.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    if (active == null) return const SizedBox.shrink();
    return _CapsuleTrigger(module: active, onTap: () => _openMenu(context));
  }

  Future<void> _openMenu(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final triggerPos = box.localToGlobal(Offset.zero, ancestor: overlay);
    final triggerSize = box.size;
    final screenW = overlay.size.width;
    const panelWidth = 260.0;
    const panelMaxHeight = 360.0;
    // 面板水平居中
    var dx = (screenW - panelWidth) / 2;
    if (dx < BulterSpacing.l) dx = BulterSpacing.l;
    // 默认在触发器下方
    var dy = triggerPos.dy + triggerSize.height + 6;
    // 若下方空间不够则放到触发器上方
    final belowSpace = overlay.size.height - dy;
    if (belowSpace < panelMaxHeight) {
      dy = (triggerPos.dy - panelMaxHeight - 6).clamp(
        BulterSpacing.l,
        overlay.size.height - panelMaxHeight - BulterSpacing.l,
      );
    }
    final selected = await showMenu<BulterModule>(
      context: context,
      position: RelativeRect.fromLTRB(dx, dy, screenW - dx - panelWidth, 0),
      items: [
        for (final m in modules)
          _ModuleMenuItem(module: m, active: m.id == activeModuleId),
      ],
      color: BulterColors.canvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BulterRadius.xl),
        side: const BorderSide(color: BulterColors.divider, width: 0.5),
      ),
      elevation: 8,
    );
    if (selected != null) onChanged(selected);
  }
}

class _CapsuleTrigger extends StatelessWidget {
  final BulterModule module;
  final VoidCallback onTap;
  const _CapsuleTrigger({required this.module, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BulterSpacing.l),
      child: Material(
        color: BulterColors.surface,
        borderRadius: BorderRadius.circular(BulterRadius.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(BulterRadius.pill),
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: BulterSpacing.m),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(BulterRadius.pill),
              border: Border.all(color: BulterColors.divider, width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: module.brandColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: BulterSpacing.s),
                Text(
                  module.displayName,
                  style: const TextStyle(
                    color: BulterColors.textPrimary,
                    fontSize: BulterFontSize.body,
                    fontWeight: BulterFontWeight.semibold,
                  ),
                ),
                const SizedBox(width: BulterSpacing.s),
                const Icon(
                  Icons.expand_more_rounded,
                  color: BulterColors.textSecondary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 自定义 PopupMenuItem：用品牌色色块 + 模块名 + 副标签 + 右侧 ✓。
class _ModuleMenuItem extends PopupMenuEntry<BulterModule> {
  final BulterModule module;
  final bool active;
  const _ModuleMenuItem({required this.module, required this.active});

  @override
  double get height => 44;

  static String _subtitle(String id) {
    switch (id) {
      case ModuleId.butler:
        return '今日 · 中枢';
      case ModuleId.relationship:
        return '人脉 · 关怀';
      case ModuleId.growth:
        return '目标 · 学习';
      case ModuleId.wealth:
        return '账户 · 流水';
      case ModuleId.thought:
        return '想法 · 信件';
      case ModuleId.health:
        return '记录 · 体检';
      case ModuleId.memory:
        return 'RAG 语义记忆';
      default:
        return '';
    }
  }

  @override
  bool represents(BulterModule? value) => value?.id == module.id;

  @override
  _ModuleMenuItemState createState() => _ModuleMenuItemState();
}

class _ModuleMenuItemState extends State<_ModuleMenuItem> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.module;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(m),
        onHighlightChanged: (v) => setState(() => _down = v),
        onHover: (v) => setState(() => _hover = v),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: BulterSpacing.m),
          color: _down
              ? m.brandColor.withValues(alpha: 0.12)
              : (_hover ? BulterColors.surfaceMuted : Colors.transparent),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: m.brandColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(BulterRadius.s),
                ),
                child: Icon(_iconFor(m.id), size: 16, color: m.brandColor),
              ),
              const SizedBox(width: BulterSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      m.displayName,
                      style: TextStyle(
                        color: BulterColors.textPrimary,
                        fontSize: BulterFontSize.bodyLg,
                        fontWeight: widget.active
                            ? BulterFontWeight.semibold
                            : BulterFontWeight.medium,
                      ),
                    ),
                    Text(
                      _ModuleMenuItem._subtitle(m.id),
                      style: const TextStyle(
                        color: BulterColors.textTertiary,
                        fontSize: BulterFontSize.caption,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.active)
                Icon(Icons.check_rounded, size: 18, color: m.brandColor),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(String id) {
    switch (id) {
      case ModuleId.butler:
        return Icons.auto_awesome_rounded;
      case ModuleId.relationship:
        return Icons.favorite_rounded;
      case ModuleId.growth:
        return Icons.trending_up_rounded;
      case ModuleId.wealth:
        return Icons.account_balance_wallet_rounded;
      case ModuleId.thought:
        return Icons.menu_book_rounded;
      case ModuleId.health:
        return Icons.favorite_outline_rounded;
      case ModuleId.memory:
        return Icons.psychology_rounded;
      default:
        return Icons.circle_outlined;
    }
  }
}
