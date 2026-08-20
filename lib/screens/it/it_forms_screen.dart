import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../widgets/form_list_tile.dart';

class ItFormsScreen extends StatelessWidget {
  const ItFormsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Select a form to submit', style: TextStyle(color: AppColors.mutedForeground)),
        const SizedBox(height: 16),
        FormListTile(
          icon: Icons.videocam_outlined,
          iconBackgroundColor: AppColors.deptIt,
          title: 'CCTV Access Request',
          description: 'Request access to review CCTV footage',
          onTap: () => context.push('/it/cctv-access-request'),
        ),
        const SizedBox(height: 12),
        FormListTile(
          icon: Icons.support_agent_outlined,
          iconBackgroundColor: AppColors.deptIt,
          title: 'IT Help Desk Ticket',
          description: 'Submit an IT issue or service request',
          onTap: () => context.push('/it/help-desk'),
        ),
        const SizedBox(height: 12),
        FormListTile(
          icon: Icons.dns_outlined,
          iconBackgroundColor: AppColors.deptIt,
          title: 'IT Request Form (Admin)',
          description: 'Request computers, email, internet, printing, or SharePoint access',
          onTap: () => context.push('/it/request-admin'),
        ),
        const SizedBox(height: 12),
        FormListTile(
          icon: Icons.dns_outlined,
          iconBackgroundColor: AppColors.deptIt,
          title: 'IT Request Form (Application)',
          description: 'Request ERP access and application permissions',
          onTap: () => context.push('/it/request-application'),
        ),
      ],
    );
  }
}
