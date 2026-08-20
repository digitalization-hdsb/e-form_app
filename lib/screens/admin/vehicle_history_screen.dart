import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../providers/cars_provider.dart';

class _HistoryEntry {
  final Map<String, dynamic> raw;
  final String model;
  final String plateNumber;
  const _HistoryEntry(this.raw, this.model, this.plateNumber);

  String? get employeeName => raw['employeeName'] as String?;
  String? get submissionRefNo => raw['submissionRefNo'] as String?;
  String? get checkedOutAt => raw['checkedOutAt'] as String?;
  String? get checkedInAt => raw['checkedInAt'] as String?;
  String? get mileageOut => raw['mileageOut']?.toString();
  String? get mileageIn => raw['mileageIn']?.toString();
  String? get fuelLevelOut => raw['fuelLevelOut'] as String?;
  String? get fuelLevelIn => raw['fuelLevelIn'] as String?;
  String? get remarksOut => (raw['remarksOut'] as String?)?.trim().isEmpty == true ? null : raw['remarksOut'] as String?;
  String? get remarksIn {
    final v = (raw['remarksIn'] ?? raw['remarks']) as String?;
    return (v == null || v.trim().isEmpty) ? null : v;
  }

  bool get petrolCardOut => raw['petrolCardOut'] == true;
  String? get petrolCardSerialOut => raw['petrolCardSerialOut'] as String?;
  Map<String, dynamic>? get photosOut => (raw['photosOut'] as Map?)?.cast<String, dynamic>();
  Map<String, dynamic>? get photosIn => (raw['photosIn'] as Map?)?.cast<String, dynamic>();

  String get distance {
    final out = double.tryParse(mileageOut ?? '');
    final incoming = double.tryParse(mileageIn ?? '');
    if (out != null && incoming != null && incoming >= out) return '${(incoming - out).toStringAsFixed(0)} km';
    return '—';
  }
}

/// Mirrors the BookingHistoryModal in pages/CarManagement.tsx — every
/// completed checkout/check-in across the whole fleet, newest first, with
/// out/in photos viewable fullscreen.
class VehicleHistoryScreen extends ConsumerStatefulWidget {
  const VehicleHistoryScreen({super.key});

  @override
  ConsumerState<VehicleHistoryScreen> createState() => _VehicleHistoryScreenState();
}

class _VehicleHistoryScreenState extends ConsumerState<VehicleHistoryScreen> {
  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    final cars = ref.watch(carsProvider).cars;
    final entries = <_HistoryEntry>[
      for (final car in cars)
        for (final h in car.history) _HistoryEntry((h as Map).cast<String, dynamic>(), car.model, car.plateNumber),
    ]..sort((a, b) {
        final da = DateTime.tryParse(a.checkedInAt ?? a.checkedOutAt ?? '') ?? DateTime(0);
        final db = DateTime.tryParse(b.checkedInAt ?? b.checkedOutAt ?? '') ?? DateTime(0);
        return db.compareTo(da);
      });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Vehicle Usage History')),
      body: entries.isEmpty
          ? Center(child: Text('No booking history found.', style: TextStyle(color: AppColors.mutedForeground)))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _HistoryCard(
                entry: entries[i],
                expanded: _expandedIndex == i,
                onToggle: () => setState(() => _expandedIndex = _expandedIndex == i ? null : i),
              ),
            ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final _HistoryEntry entry;
  final bool expanded;
  final VoidCallback onToggle;

  const _HistoryCard({required this.entry, required this.expanded, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border), boxShadow: AppColors.cardShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.employeeName ?? 'Unknown employee', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('${entry.model} · ${entry.plateNumber}', style: TextStyle(fontSize: 11.5, color: AppColors.mutedForeground)),
                    if (entry.submissionRefNo != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(entry.submissionRefNo!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
                child: Text(entry.distance, style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _dateTimeCol('OUT', entry.checkedOutAt, AppColors.gold)),
              Expanded(child: _dateTimeCol('IN', entry.checkedInAt, AppColors.success)),
            ],
          ),
          const SizedBox(height: 10),
          _detailRow('Mileage', '${entry.mileageOut ?? '—'} → ${entry.mileageIn ?? '—'} km'),
          _detailRow('Fuel', '${entry.fuelLevelOut ?? '—'} → ${entry.fuelLevelIn ?? '—'}'),
          _detailRow('Petrol Card', entry.petrolCardOut ? (entry.petrolCardSerialOut ?? 'Issued') : 'Not issued'),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onToggle,
              icon: Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 16),
              label: Text(expanded ? 'Hide details' : 'View details', style: const TextStyle(fontSize: 12.5)),
            ),
          ),
          if (expanded) ...[
            if (entry.remarksOut != null || entry.remarksIn != null) ...[
              Text('REMARKS', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.mutedForeground, letterSpacing: 0.3)),
              const SizedBox(height: 4),
              if (entry.remarksOut != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: 'Out: ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.gold)),
                    TextSpan(text: entry.remarksOut, style: TextStyle(color: AppColors.foreground)),
                  ]), style: const TextStyle(fontSize: 12.5)),
                ),
              if (entry.remarksIn != null)
                Text.rich(TextSpan(children: [
                  TextSpan(text: 'In: ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
                  TextSpan(text: entry.remarksIn, style: TextStyle(color: AppColors.foreground)),
                ]), style: const TextStyle(fontSize: 12.5)),
              const SizedBox(height: 10),
            ],
            _photoGroup(context, 'Photos Out', entry.photosOut, AppColors.gold),
            _photoGroup(context, 'Photos In', entry.photosIn, AppColors.success),
          ],
        ],
      ),
    );
  }

  Widget _dateTimeCol(String label, String? value, Color color) {
    final date = value != null ? DateTime.tryParse(value) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(date != null ? DateFormat('d MMM yyyy, h:mm a').format(date) : '—', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: TextStyle(fontSize: 11.5, color: AppColors.mutedForeground))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _photoGroup(BuildContext context, String label, Map<String, dynamic>? photos, Color tone) {
    final photoEntries = (photos ?? {}).entries.where((e) => e.value != null && e.value.toString().isNotEmpty).toList();
    if (photoEntries.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: tone, letterSpacing: 0.3)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in photoEntries)
                InkWell(
                  onTap: () => _openFullscreen(context, e.value.toString()),
                  borderRadius: BorderRadius.circular(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(e.value.toString(), width: 56, height: 56, fit: BoxFit.cover),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _openFullscreen(BuildContext context, String url) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, __, ___) => _FullscreenImage(url: url),
    ));
  }
}

class _FullscreenImage extends StatelessWidget {
  final String url;
  const _FullscreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Center(child: InteractiveViewer(child: Image.network(url))),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
