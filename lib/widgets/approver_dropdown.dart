import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/app_user.dart';

/// Mirrors the website's HOS/HOD/Manco/Head-of-Purchasing/Head-of-Finance
/// selects: populated from the `users` directory filtered by role, with an
/// optional "N/A" entry when that approval stage can be skipped.
class ApproverDropdown extends StatelessWidget {
  final String label;
  final List<DirectoryUser> options;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool includeNotApplicable;
  final bool isLoading;
  final bool useUserIdAsValue;

  const ApproverDropdown({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.includeNotApplicable = false,
    this.isLoading = false,
    this.useUserIdAsValue = false,
  });

  @override
  Widget build(BuildContext context) {
    final items = <DropdownMenuItem<String>>[
      if (includeNotApplicable) const DropdownMenuItem(value: 'N/A', child: Text('N/A')),
      ...options.map((u) => DropdownMenuItem(value: useUserIdAsValue ? u.id : u.name, child: Text(u.name, overflow: TextOverflow.ellipsis))),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          borderRadius: BorderRadius.circular(14),
          dropdownColor: AppColors.card,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.mutedForeground),
          initialValue: items.any((i) => i.value == value) ? value : null,
          isExpanded: true,
          hint: Text(isLoading ? 'Loading users...' : 'Choose $label'),
          items: items,
          onChanged: (isLoading || options.isEmpty && !includeNotApplicable) ? null : onChanged,
        ),
        if (!isLoading && options.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('No approvers configured for this role yet.', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ),
      ],
    );
  }
}
