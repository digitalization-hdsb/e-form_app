import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

/// A wheel-style time picker bottom sheet, in the style used by most
/// modern travel/logistics apps (Uber, Grab, Airbnb) — swapped in for
/// Flutter's default [showTimePicker] dial dialog across the app.
Future<TimeOfDay?> showModernTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  String title = 'Select time',
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    backgroundColor: AppColors.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _ModernTimePickerSheet(initialTime: initialTime, title: title),
  );
}

class _ModernTimePickerSheet extends StatefulWidget {
  final TimeOfDay initialTime;
  final String title;

  const _ModernTimePickerSheet({required this.initialTime, required this.title});

  @override
  State<_ModernTimePickerSheet> createState() => _ModernTimePickerSheetState();
}

class _ModernTimePickerSheetState extends State<_ModernTimePickerSheet> {
  late int _hour12; // 1-12
  late int _minute; // 0-59
  late bool _isPm;

  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;
  late final FixedExtentScrollController _periodController;

  @override
  void initState() {
    super.initState();
    final h24 = widget.initialTime.hour;
    _isPm = h24 >= 12;
    _hour12 = h24 % 12 == 0 ? 12 : h24 % 12;
    _minute = widget.initialTime.minute;
    _hourController = FixedExtentScrollController(initialItem: _hour12 - 1);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
    _periodController = FixedExtentScrollController(initialItem: _isPm ? 1 : 0);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  TimeOfDay get _result {
    var h24 = _hour12 % 12;
    if (_isPm) h24 += 12;
    return TimeOfDay(hour: h24, minute: _minute);
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required String Function(int index) labelBuilder,
    required ValueChanged<int> onChanged,
  }) {
    return CupertinoPicker(
      scrollController: controller,
      itemExtent: 44,
      diameterRatio: 1.1,
      squeeze: 1.15,
      selectionOverlay: Container(
        decoration: BoxDecoration(
          border: Border.symmetric(horizontal: BorderSide(color: AppColors.primary.withValues(alpha: 0.35), width: 1.5)),
        ),
      ),
      onSelectedItemChanged: (i) {
        HapticFeedback.selectionClick();
        onChanged(i);
      },
      children: List.generate(
        itemCount,
        (i) => Center(
          child: Text(
            labelBuilder(i),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(height: 4, width: 44, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 18),
            Row(
              children: [
                Icon(Icons.access_time_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 190,
              child: Row(
                children: [
                  Expanded(
                    child: _wheel(
                      controller: _hourController,
                      itemCount: 12,
                      labelBuilder: (i) => (i + 1).toString().padLeft(2, '0'),
                      onChanged: (i) => setState(() => _hour12 = i + 1),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.mutedForeground)),
                  ),
                  Expanded(
                    child: _wheel(
                      controller: _minuteController,
                      itemCount: 60,
                      labelBuilder: (i) => i.toString().padLeft(2, '0'),
                      onChanged: (i) => setState(() => _minute = i),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _wheel(
                      controller: _periodController,
                      itemCount: 2,
                      labelBuilder: (i) => i == 0 ? 'AM' : 'PM',
                      onChanged: (i) => setState(() => _isPm = i == 1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _result),
                    child: const Text('Set Time'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
