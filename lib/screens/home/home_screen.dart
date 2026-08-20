import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/announcements_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/submissions_provider.dart';
import '../../providers/users_provider.dart';
import '../../widgets/neural_network_background.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final mySubmissions = ref.watch(mySubmissionsProvider(user?.id));

    final total = mySubmissions.length;
    final accepted = mySubmissions.where((s) => ['approved', 'completed', 'paid'].contains(s.status)).length;
    final rejected = mySubmissions.where((s) => s.status == 'rejected').length;

    final hasSafetyAccess = user?.role == 'safety_admin' || user?.role == 'super_admin' || (user?.secondaryRoles.contains('safety_admin') ?? false);
    final activeAnnouncement = ref.watch(announcementsProvider).active;

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(submissionsProvider.notifier).refresh();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (activeAnnouncement != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0x1A3B82F6), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.campaign_outlined, color: Color(0xFF1D4ED8), size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(activeAnnouncement.content, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            _ProfileDashboardCard(
              name: user?.name ?? 'User',
              employeeId: user?.employeeId ?? 'N/A',
              department: user?.department ?? 'N/A',
              role: user?.role ?? 'employee',
              avatarUrl: user?.avatar ?? '',
              total: total,
              accepted: accepted,
              rejected: rejected,
            ),
            const SizedBox(height: 24),
            const Text('Submit a New Form', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('Select a department to view available forms.', style: TextStyle(color: AppColors.mutedForeground)),
            const SizedBox(height: 16),
            if (hasSafetyAccess) ...[
              _DeptCard(
                title: 'Safety Department',
                description: 'Water treatment logs, Final Discharge, and waste inventory records.',
                icon: Icons.shield_outlined,
                color: AppColors.deptSafety,
                onTap: () => context.go('/safety'),
              ),
              const SizedBox(height: 14),
            ],
            _DeptCard(
              title: 'Human Resource Department',
              description: 'Car Booking requests, Gate Pass, PPE Items and more.',
              icon: Icons.groups_outlined,
              color: AppColors.deptHr,
              onTap: () => context.go('/hr'),
            ),
            const SizedBox(height: 14),
            _DeptCard(
              title: 'Finance Department',
              description: 'Submit Petty Cash claims and reimbursements.',
              icon: Icons.attach_money,
              color: AppColors.deptFinance,
              onTap: () => context.go('/finance'),
            ),
            const SizedBox(height: 14),
            _DeptCard(
              title: 'IT Department',
              description: 'CCTV access requests and other IT service forms.',
              icon: Icons.dns_outlined,
              color: AppColors.deptIt,
              onTap: () => context.go('/it'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mirrors the website's HomePage.tsx profile card: identity block (avatar
/// with a role badge overlapping its bottom edge) and the Total/Accepted/
/// Rejected mini-dashboard living together in one card, rather than as two
/// separate stacked cards.
class _ProfileDashboardCard extends StatelessWidget {
  final String name;
  final String employeeId;
  final String department;
  final String role;
  final String avatarUrl;
  final int total;
  final int accepted;
  final int rejected;

  const _ProfileDashboardCard({
    required this.name,
    required this.employeeId,
    required this.department,
    required this.role,
    required this.total,
    required this.accepted,
    required this.rejected,
    this.avatarUrl = '',
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: NeuralNetworkBackground()),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl.isNotEmpty
                              ? null
                              : Text(
                                  name.isNotEmpty ? name.trim().split(RegExp(r'\s+')).take(2).map((p) => p[0]).join().toUpperCase() : '?',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                        ),
                        Transform.translate(
                          offset: const Offset(0, -9),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: AppColors.border),
                              boxShadow: AppColors.cardShadow,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shield_outlined, size: 10, color: AppColors.primary),
                                const SizedBox(width: 3),
                                Text(
                                  (roleLabels[role] ?? role.replaceAll('_', ' ')).toUpperCase(),
                                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 0.3),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Welcome back,', style: TextStyle(color: AppColors.mutedForeground, fontSize: 13)),
                          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text('Staff ID: $employeeId · $department', style: TextStyle(color: AppColors.mutedForeground, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _stat(context, 'TOTAL', total, AppColors.primary),
                    _statDivider(),
                    _stat(context, 'ACCEPTED', accepted, AppColors.success),
                    _statDivider(),
                    _stat(context, 'REJECTED', rejected, AppColors.destructive),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statDivider() => Container(width: 1, height: 30, color: AppColors.border);

  Widget _stat(BuildContext context, String label, int value, Color color) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.push('/submissions'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                Text('$value', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(fontSize: 10, color: AppColors.mutedForeground, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeptCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DeptCard({required this.title, required this.description, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 2),
        boxShadow: AppColors.cardShadow,
      ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(description, style: TextStyle(color: AppColors.mutedForeground, fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('View Forms', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 14, color: AppColors.accent),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
