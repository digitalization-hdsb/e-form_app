import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  ({Color bg, Color fg, String label}) _style() {
    switch (status) {
      case 'approved':
      case 'completed':
        return (bg: const Color(0xFF57D51B), fg: Colors.white, label: status == 'completed' ? 'COMPLETED' : 'APPROVED');
      case 'rejected':
        return (bg: const Color(0xFFD32F2F), fg: Colors.white, label: 'REJECTED');
      case 'voided':
        return (bg: const Color(0x2664748B), fg: const Color(0xFF475569), label: 'VOIDED');
      case 'paid':
        return (bg: const Color(0x263B82F6), fg: const Color(0xFF1D4ED8), label: 'PAID');
      default:
        final label = status.replaceAll('_', ' ').toUpperCase();
        return (bg: const Color(0x26F59E0B), fg: const Color(0xFFB45309), label: label);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(999)),
      child: Text(s.label, style: TextStyle(color: s.fg, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.4)),
    );
  }
}
