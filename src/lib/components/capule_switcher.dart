import 'package:flutter/material.dart';

import '../modules/bulter_module.dart';
import '../theme/tokens.dart';

/// 顶部胶囊切换器：Butler 中枢 ↔ 六大模块。
///
/// 数据源：通过 [modules] 构造参数注入（通常由 AppShell 从
/// [ModuleRegistry.capsuleModules] 取值传入），**不硬编码模块列表**。
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: BulterSpacing.l),
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final m in modules) ...[
            _Capsule(
              module: m,
              active: m.id == activeModuleId,
              onTap: () => onChanged(m),
            ),
            const SizedBox(width: BulterSpacing.s),
          ],
        ],
      ),
    );
  }
}

class _Capsule extends StatelessWidget {
  final BulterModule module;
  final bool active;
  final VoidCallback onTap;
  const _Capsule({
    required this.module,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active ? BulterColors.cta : BulterColors.surface;
    final fg = active ? BulterColors.ctaText : BulterColors.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(BulterRadius.pill),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(
            horizontal: BulterSpacing.l,
            vertical: BulterSpacing.s + 2,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(BulterRadius.pill),
            border: Border.all(
              color: active ? BulterColors.cta : BulterColors.divider,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (active)
                Padding(
                  padding: const EdgeInsets.only(right: BulterSpacing.xs + 2),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: module.brandColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              Text(
                module.displayName,
                style: TextStyle(
                  color: fg,
                  fontSize: BulterFontSize.body,
                  fontWeight: active
                      ? BulterFontWeight.semibold
                      : BulterFontWeight.medium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
