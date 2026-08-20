import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../widgets/form_list_tile.dart';

class HrFormsScreen extends StatelessWidget {
  const HrFormsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Select a form to submit', style: TextStyle(color: AppColors.mutedForeground)),
          const SizedBox(height: 16),
          FormListTile(
            icon: Icons.directions_car_filled_outlined,
            iconBackgroundColor: AppColors.deptHr,
            title: 'Company Car Request',
            description: 'Request a company vehicle for business travel',
            onTap: () => context.push('/hr/car-rental'),
          ),
          const SizedBox(height: 12),
          FormListTile(
            icon: Icons.calendar_today_outlined,
            iconBackgroundColor: AppColors.deptHr,
            title: 'Gate Pass',
            description: 'Apply for a pass to exit the company premises',
            onTap: () => context.push('/hr/leave'),
          ),
          const SizedBox(height: 12),
          FormListTile(
            icon: Icons.inventory_2_outlined,
            iconBackgroundColor: AppColors.deptHr,
            title: 'PPE | Uniform | Office Supply',
            description: 'Request personal protective equipment, uniforms, or office supply',
            onTap: () => context.push('/hr/ppe-request'),
          ),
        ],
    );
  }
}
