import 'package:flutter/material.dart';

import '../core/theme.dart';

/// A numbered section card matching the website's `card-elevated` sections
/// (e.g. "01 Requester Details", "02 Journey Details").
class FormSectionCard extends StatelessWidget {
  final String number;
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  const FormSectionCard({
    super.key,
    required this.number,
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      boxShadow: AppColors.cardShadow,
    ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 28,
                width: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(number, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ),
              const SizedBox(width: 10),
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Read-only "Name / Position / Staff ID / Department" block, prefilled
/// from the signed-in profile — matches the website's disabled detail rows.
class PrefilledDetailsBox extends StatelessWidget {
  final Map<String, String> rows;

  const PrefilledDetailsBox({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    final entries = rows.entries.toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          for (int i = 0; i < entries.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                border: i < entries.length - 1 ? Border(bottom: BorderSide(color: AppColors.border)) : null,
              ),
              child: Row(
                children: [
                  SizedBox(width: 110, child: Text(entries[i].key, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground))),
                  Expanded(
                    child: Text(
                      entries[i].value.isEmpty ? '—' : entries[i].value,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
