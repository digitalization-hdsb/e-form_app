import 'package:flutter/material.dart';

import '../core/theme.dart';

/// One tab's definition: the value it selects, its label, and an optional
/// count shown as a small badge next to the label.
class TabBarItem<T> {
  final T value;
  final String label;
  final int? count;
  const TabBarItem({required this.value, required this.label, this.count});
}

/// A minimal underline-indicator tab bar — label + count badge per tab, an
/// animated colored bar under the selected one, no boxed/pill background.
/// Used for the "Action Required / In Progress / History" category
/// switchers across the HOS/HOD/admin dashboards, replacing the earlier
/// SegmentedButton row for a cleaner, more standard app-tab look.
class UnderlineTabBar<T> extends StatelessWidget {
  final List<TabBarItem<T>> tabs;
  final T selected;
  final ValueChanged<T> onChanged;

  const UnderlineTabBar({super.key, required this.tabs, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [for (final tab in tabs) Expanded(child: _TabItem(tab: tab, selected: tab.value == selected, onTap: () => onChanged(tab.value)))],
      ),
    );
  }
}

class _TabItem<T> extends StatelessWidget {
  final TabBarItem<T> tab;
  final bool selected;
  final VoidCallback onTap;

  const _TabItem({required this.tab, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.mutedForeground;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      tab.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, fontWeight: selected ? FontWeight.bold : FontWeight.w600, color: color),
                    ),
                  ),
                  if (tab.count != null) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : AppColors.mutedForeground.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${tab.count}',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: selected ? AppColors.onPrimary : AppColors.mutedForeground),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              height: 3,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
