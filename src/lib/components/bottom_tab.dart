import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 底部 Tab。Step 1 用占位列表。
class BulterBottomTab extends StatelessWidget {
  final List<TabItem> tabs;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  const BulterBottomTab({
    super.key,
    required this.tabs,
    required this.activeIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: BulterColors.surface,
        border: Border(
          top: BorderSide(color: BulterColors.divider, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: _TabButton(
                    item: tabs[i],
                    active: i == activeIndex,
                    onTap: () => onChanged(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class TabItem {
  final String id;
  final String label;
  final IconData icon;
  const TabItem({required this.id, required this.label, required this.icon});
}

class _TabButton extends StatelessWidget {
  final TabItem item;
  final bool active;
  final VoidCallback onTap;
  const _TabButton({
    required this.item,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? BulterColors.cta : BulterColors.textTertiary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: TextStyle(
                fontSize: BulterFontSize.caption,
                color: color,
                fontWeight: active ? BulterFontWeight.semibold : BulterFontWeight.medium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
