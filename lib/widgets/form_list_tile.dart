import 'package:flutter/material.dart';

import '../core/theme.dart';

class FormListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? iconBackgroundColor;

  const FormListTile({super.key, required this.icon, required this.title, required this.description, this.onTap, this.iconColor, this.iconBackgroundColor});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border, width: 2),
          boxShadow: AppColors.cardShadow,
        ),
          child: Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(color: iconBackgroundColor ?? AppColors.primary, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: iconColor ?? Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(description, style: TextStyle(color: AppColors.mutedForeground, fontSize: 12.5)),
                  ],
                ),
              ),
              if (!disabled) Icon(Icons.chevron_right, color: AppColors.mutedForeground),
            ],
          ),
        ),
      ),
    );
  }
}
