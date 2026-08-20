import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../widgets/form_list_tile.dart';

class FinanceFormsScreen extends StatelessWidget {
  const FinanceFormsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Select a form to submit', style: TextStyle(color: AppColors.mutedForeground)),
        const SizedBox(height: 16),
        FormListTile(
          icon: Icons.attach_money,
          iconBackgroundColor: AppColors.deptFinance,
          title: 'Petty Cash Claim',
          description: 'Submit petty cash claims for reimbursement',
          onTap: () => context.push('/finance/claim'),
        ),
        const SizedBox(height: 12),
        FormListTile(
          icon: Icons.upload_file_outlined,
          iconBackgroundColor: AppColors.deptHr,
          title: 'Upload Receipt',
          description: 'Attach a receipt to a previously submitted Petty Cash Claim.',
          onTap: () => context.push('/finance/receipt-upload'),
        ),
      ],
    );
  }
}
