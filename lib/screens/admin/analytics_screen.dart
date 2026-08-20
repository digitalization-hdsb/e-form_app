import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/submission.dart';
import '../../providers/submissions_provider.dart';
import '../../providers/users_provider.dart';

const _adminRoles = {'super_admin', 'safety_admin', 'finance_admin', 'it_admin', 'hr_admin', 'security_guard'};

/// Excluded from every submissions count on this page, mirroring
/// AnalyticsDashboard.tsx's `excludedForms`.
const _excludedFormTypes = {'inventory_addition', 'ppe_request', 'waste_inventory', 'mixing_chemical_stages', 'final_discharge', 'daily_operation_monitoring'};

const _trendFormTypeOptions = {
  'all': 'All form types',
  'leave': 'Gate Pass',
  'claim': 'Petty Cash',
  'car_rental': 'Car Booking',
  'it_help_desk': 'IT Help Desk',
  'it_facilities_requisition': 'IT Facilities',
  'it_admin_request': 'IT Admin',
  'it_application_request': 'IT Application',
  'cctv_access_request': 'CCTV Access',
};

/// Bar-chart category → (label, color), mirroring AnalyticsDashboard.tsx's
/// "Submissions by Form Type" chart. Anything not excluded and not in this
/// map falls into "Other".
const _barCategories = <String, ({String label, Color color})>{
  'leave': (label: 'Gate Pass', color: Color(0xFF3B82F6)),
  'claim': (label: 'Petty Cash', color: Color(0xFFF59E0B)),
  'car_rental': (label: 'Car Booking', color: Color(0xFF6366F1)),
  'it_help_desk': (label: 'IT Help Desk', color: Color(0xFF14B8A6)),
  'it_facilities_requisition': (label: 'IT Facilities', color: Color(0xFFF43F5E)),
  'it_admin_request': (label: 'IT Admin', color: Color(0xFF8B5CF6)),
  'it_application_request': (label: 'IT Application', color: Color(0xFF06B6D4)),
  'cctv_access_request': (label: 'CCTV Access', color: Color(0xFF84CC16)),
};
const _otherColor = Color(0xFF94A3B8);

/// Mirrors pages/AnalyticsDashboard.tsx in full: stat cards, a filterable
/// monthly submission trend line, a user status donut, and a submissions-
/// by-form-type bar chart.
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String _trendFormType = 'all';
  int _trendMonths = 6;

  @override
  Widget build(BuildContext context) {
    final usersState = ref.watch(usersProvider);
    final submissionsState = ref.watch(submissionsProvider);

    final allUsers = usersState.allUsers;
    final active = allUsers.where((u) => u.status == 'active').toList();
    final inactive = allUsers.length - active.length;
    final activeHos = active.where((u) => u.hasRole('hos')).length;
    final activeHod = active.where((u) => u.hasRole('hod')).length;
    final admins = active.where((u) => _adminRoles.contains(u.role) || u.secondaryRoles.any(_adminRoles.contains)).length;

    final submissions = submissionsState.submissions.where((s) => !_excludedFormTypes.contains(s.formType)).toList();
    final gatePass = submissions.where((s) => s.formType == 'leave').length;
    final pettyCash = submissions.where((s) => s.formType == 'claim').length;
    final carBooking = submissions.where((s) => s.formType == 'car_rental').length;
    final itForms = submissions.where((s) => const {'it_help_desk', 'it_facilities_requisition', 'it_admin_request', 'it_application_request', 'cctv_access_request'}.contains(s.formType)).length;

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([ref.read(submissionsProvider.notifier).refresh(), ref.read(usersProvider.notifier).refresh()]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader(Icons.people_outline, 'User Directory', 'Account status and role coverage.'),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.4,
            children: [
              _statTile('Total Accounts', '${allUsers.length}'),
              _statTile('Active Users', '${active.length}'),
              _statTile('Inactive Users', '$inactive'),
              _statTile('Active HOS', '$activeHos'),
              _statTile('Active HOD', '$activeHod'),
              _statTile('Administrators', '$admins'),
            ],
          ),
          const SizedBox(height: 20),
          _submissionTrendCard(submissions),
          const SizedBox(height: 20),
          _userStatusCard(active.length, inactive),
          const SizedBox(height: 24),
          _sectionHeader(Icons.description_outlined, 'Submissions', 'Form activity across HR, Finance, and Vehicle requests.'),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.4,
            children: [
              _statTile('Total Submissions', '${submissions.length}'),
              _statTile('Gate Pass', '$gatePass'),
              _statTile('Petty Cash', '$pettyCash'),
              _statTile('Car Booking', '$carBooking'),
              _statTile('IT Forms', '$itForms'),
            ],
          ),
          const SizedBox(height: 20),
          _submissionsByFormTypeCard(submissions),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(subtitle, style: TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statTile(String label, String value, {int? delta}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border), boxShadow: AppColors.cardShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 10.5, color: AppColors.mutedForeground, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
              if (delta != null) ...[
                const SizedBox(width: 6),
                Text(
                  '${delta >= 0 ? '+' : ''}$delta',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: delta >= 0 ? AppColors.success : AppColors.destructive),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardShell({required String title, required IconData icon, Widget? trailing, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border), boxShadow: AppColors.cardShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5))),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _submissionTrendCard(List<Submission> submissions) {
    final now = DateTime.now();
    final months = List.generate(_trendMonths, (i) => DateTime(now.year, now.month - (_trendMonths - 1 - i)));
    final counts = months.map((m) {
      return submissions.where((s) {
        if (_trendFormType != 'all' && s.formType != _trendFormType) return false;
        final d = DateTime.tryParse(s.submittedAt);
        return d != null && d.year == m.year && d.month == m.month;
      }).length;
    }).toList();

    final current = counts.isNotEmpty ? counts.last : 0;
    final previous = counts.length >= 2 ? counts[counts.length - 2] : 0;
    final delta = current - previous;
    final percent = previous == 0 ? (current > 0 ? 100.0 : 0.0) : (delta / previous * 100);
    final maxY = (counts.isEmpty ? 1 : counts.reduce((a, b) => a > b ? a : b)).toDouble();

    return _cardShell(
      title: 'Submission Trend',
      icon: Icons.trending_up,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Monthly form submissions over the last $_trendMonths months.', style: TextStyle(fontSize: 11.5, color: AppColors.mutedForeground)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  borderRadius: BorderRadius.circular(14),
                  dropdownColor: AppColors.card,
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.mutedForeground),
                  initialValue: _trendFormType,
                  isDense: true,
                  isExpanded: true,
                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                  items: _trendFormTypeOptions.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (v) => setState(() => _trendFormType = v ?? 'all'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 92,
                child: DropdownButtonFormField<int>(
                  borderRadius: BorderRadius.circular(14),
                  dropdownColor: AppColors.card,
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.mutedForeground),
                  initialValue: _trendMonths,
                  isDense: true,
                  isExpanded: true,
                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                  items: const [
                    DropdownMenuItem(value: 3, child: Text('3 mo', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 6, child: Text('6 mo', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 12, child: Text('12 mo', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (v) => setState(() => _trendMonths = v ?? 6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY <= 0 ? 4 : maxY * 1.2,
                gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: (maxY <= 0 ? 4 : maxY * 1.2) / 4, getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) => value == value.roundToDouble() ? Text('${value.toInt()}', style: TextStyle(fontSize: 9.5, color: AppColors.mutedForeground)) : const SizedBox(),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= months.length) return const SizedBox();
                        return Padding(padding: const EdgeInsets.only(top: 4), child: Text(DateFormat('MMM').format(months[i]), style: TextStyle(fontSize: 9.5, color: AppColors.mutedForeground)));
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots
                        .map((s) => LineTooltipItem('${DateFormat('MMM yyyy').format(months[s.x.toInt()])}\n${s.y.toInt()} submissions', const TextStyle(color: Colors.white, fontSize: 11)))
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [for (var i = 0; i < counts.length; i++) FlSpot(i.toDouble(), counts[i].toDouble())],
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.08)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CURRENT MONTH', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.mutedForeground, letterSpacing: 0.3)),
                      Text('$current submissions', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Icon(delta > 0 ? Icons.trending_up : (delta < 0 ? Icons.trending_down : Icons.trending_flat), size: 16, color: delta > 0 ? AppColors.success : (delta < 0 ? AppColors.destructive : AppColors.mutedForeground)),
                    const SizedBox(width: 4),
                    Text(
                      '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: delta > 0 ? AppColors.success : (delta < 0 ? AppColors.destructive : AppColors.mutedForeground)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _userStatusCard(int activeCount, int inactiveCount) {
    final total = activeCount + inactiveCount;
    return _cardShell(
      title: 'User Status',
      icon: Icons.pie_chart_outline,
      child: total == 0
          ? Padding(padding: const EdgeInsets.symmetric(vertical: 30), child: Center(child: Text('No user data available.', style: TextStyle(color: AppColors.mutedForeground))))
          : Row(
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 4,
                          centerSpaceRadius: 42,
                          sections: [
                            if (activeCount > 0) PieChartSectionData(value: activeCount.toDouble(), color: const Color(0xFF10B981), radius: 26, showTitle: false),
                            if (inactiveCount > 0) PieChartSectionData(value: inactiveCount.toDouble(), color: const Color(0xFF3B82F6), radius: 26, showTitle: false),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$total', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('TOTAL USERS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.mutedForeground, letterSpacing: 0.3)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _legendRow('Active', const Color(0xFF10B981), activeCount, total),
                      const SizedBox(height: 10),
                      _legendRow('Inactive', const Color(0xFF3B82F6), inactiveCount, total),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _legendRow(String label, Color color, int count, int total) {
    final pct = total > 0 ? (count / total * 100) : 0;
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
        Text('$count', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Text('(${pct.toStringAsFixed(0)}%)', style: TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
      ],
    );
  }

  Widget _submissionsByFormTypeCard(List<Submission> submissions) {
    final counts = <String, int>{};
    var other = 0;
    for (final s in submissions) {
      if (_barCategories.containsKey(s.formType)) {
        counts[s.formType] = (counts[s.formType] ?? 0) + 1;
      } else {
        other++;
      }
    }

    final bars = <({String key, String label, Color color, int value})>[
      for (final entry in _barCategories.entries) (key: entry.key, label: entry.value.label, color: entry.value.color, value: counts[entry.key] ?? 0),
      (key: 'other', label: 'Other', color: _otherColor, value: other),
    ];

    final maxY = bars.map((b) => b.value).fold<int>(0, (a, b) => a > b ? a : b).toDouble();

    return _cardShell(
      title: 'Submissions by Form Type',
      icon: Icons.bar_chart,
      child: submissions.isEmpty
          ? Padding(padding: const EdgeInsets.symmetric(vertical: 30), child: Center(child: Text('No submissions recorded yet.', style: TextStyle(color: AppColors.mutedForeground))))
          : SizedBox(
              height: 260,
              child: BarChart(
                BarChartData(
                  maxY: maxY <= 0 ? 4 : maxY * 1.25,
                  gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: (maxY <= 0 ? 4 : maxY * 1.25) / 4, getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 1)),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem('${bars[group.x].label}\n${rod.toY.toInt()} submissions', const TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        getTitlesWidget: (value, meta) => value == value.roundToDouble() ? Text('${value.toInt()}', style: TextStyle(fontSize: 9.5, color: AppColors.mutedForeground)) : const SizedBox(),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= bars.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Transform.rotate(
                              angle: -0.6,
                              child: Text(bars[i].label, style: TextStyle(fontSize: 9, color: AppColors.mutedForeground), overflow: TextOverflow.ellipsis),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < bars.length; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(toY: bars[i].value.toDouble(), color: bars[i].color, width: 20, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                      ]),
                  ],
                ),
              ),
            ),
    );
  }
}
