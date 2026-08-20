import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../widgets/form_list_tile.dart';

class SafetyFormsScreen extends StatelessWidget {
  const SafetyFormsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Select a form to submit', style: TextStyle(color: AppColors.mutedForeground)),
        const SizedBox(height: 16),
        FormListTile(
          icon: Icons.science_outlined,
          iconBackgroundColor: AppColors.deptSafety,
          title: 'Mixing & Chemical',
          description: 'Log daily mixing tank and chemical dosage readings',
          onTap: () => context.push('/safety/mixing'),
        ),
        const SizedBox(height: 12),
        FormListTile(
          icon: Icons.water_drop_outlined,
          iconBackgroundColor: AppColors.deptSafety,
          title: 'Final Discharge',
          description: 'Log daily final discharge water quality readings',
          onTap: () => context.push('/safety/discharge'),
        ),
        const SizedBox(height: 12),
        FormListTile(
          icon: Icons.scale_outlined,
          iconBackgroundColor: AppColors.deptSafety,
          title: 'Waste Inventory',
          description: 'Record scheduled waste weigh-ins for sell or disposal',
          onTap: () => context.push('/safety/waste-inventory'),
        ),
      ],
    );
  }
}
