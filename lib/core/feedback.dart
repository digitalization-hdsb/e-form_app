import 'package:flutter/material.dart';

import 'theme.dart';

/// Attached to `MaterialApp.router` in main.dart. Toasts are shown through
/// this key rather than `ScaffoldMessenger.of(context)` because several
/// call sites (e.g. "Gate Pass submitted successfully!") show the SnackBar
/// and immediately call `context.go(...)` in the same breath — routing
/// through the one root messenger, instead of a route-scoped lookup, is
/// what keeps the toast alive across that navigation.
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Shared, modern SnackBar styling for the whole app — a floating rounded
/// card with a status icon, replacing the old plain-text/flat-red snackbars
/// that every form screen used to hand-roll individually.
void _showAppSnackBar(
  BuildContext context, {
  required String message,
  required Color background,
  required IconData icon,
  Duration duration = const Duration(seconds: 3),
}) {
  final messenger = rootScaffoldMessengerKey.currentState ?? ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: background,
        elevation: 6,
        duration: duration,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
}

/// A bright-green success toast — used for "form submitted", "record
/// saved", and other completed-action confirmations.
void showSuccessSnackBar(BuildContext context, String message) {
  _showAppSnackBar(context, message: message, background: AppColors.successBright, icon: Icons.check_circle_rounded);
}

/// A clear, professional error toast — used for validation failures and
/// backend errors alike.
void showErrorSnackBar(BuildContext context, String message) {
  _showAppSnackBar(
    context,
    message: message,
    background: AppColors.destructive,
    icon: Icons.error_rounded,
    duration: const Duration(seconds: 4),
  );
}
