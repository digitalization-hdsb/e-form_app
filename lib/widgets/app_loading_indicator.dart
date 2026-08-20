import 'package:flutter/material.dart';

import '../core/theme.dart';

/// A branded circular loading ring — a thicker, rounded-cap arc over a
/// faint track in the app's primary color, used wherever the plain default
/// `CircularProgressIndicator` would look like an afterthought (the sign-in
/// button, full-screen "please wait" states).
class AppLoadingIndicator extends StatelessWidget {
  final double size;
  final Color? color;
  final double? strokeWidth;

  const AppLoadingIndicator({super.key, this.size = 22, this.color, this.strokeWidth});

  @override
  Widget build(BuildContext context) {
    final ringColor = color ?? AppColors.primary;
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth ?? (size / 8),
        strokeCap: StrokeCap.round,
        color: ringColor,
        backgroundColor: ringColor.withValues(alpha: 0.15),
      ),
    );
  }
}
