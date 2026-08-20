import 'package:flutter/material.dart';

import '../core/theme.dart';

/// A faint circuit/neural-network line-and-node pattern, mirroring the
/// decorative SVG background behind the profile card on the website's
/// HomePage.tsx. Positions are normalized (0-1) so the painter scales to
/// whatever size the card is given.
class NeuralNetworkBackground extends StatelessWidget {
  const NeuralNetworkBackground({super.key});

  static const List<Offset> _nodes = [
    Offset(0.06, 0.14), Offset(0.14, 0.32), Offset(0.24, 0.20), Offset(0.16, 0.52),
    Offset(0.30, 0.60), Offset(0.20, 0.78), Offset(0.36, 0.86), Offset(0.44, 0.68),
    Offset(0.52, 0.90), Offset(0.60, 0.30), Offset(0.68, 0.10), Offset(0.74, 0.48),
    Offset(0.62, 0.60), Offset(0.80, 0.72), Offset(0.88, 0.34), Offset(0.94, 0.58),
    Offset(0.90, 0.86), Offset(0.98, 0.16),
  ];

  static const List<List<int>> _edges = [
    [0, 1], [1, 2], [1, 3], [2, 9], [3, 4], [3, 5], [4, 7], [5, 6], [6, 7], [7, 8],
    [9, 10], [9, 11], [9, 12], [10, 14], [11, 12], [11, 13], [12, 8], [13, 14],
    [13, 16], [14, 15], [14, 17], [15, 16], [15, 17],
  ];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ShaderMask(
        shaderCallback: (rect) => RadialGradient(
          center: const Alignment(0.65, -0.4),
          radius: 1.15,
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.0)],
          stops: const [0.0, 1.0],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: CustomPaint(painter: _NetworkPainter(), size: Size.infinite),
      ),
    );
  }
}

class _NetworkPainter extends CustomPainter {
  // Mirrors the website's own light/dark split for these dots — Tailwind's
  // `fill-cyan-600 dark:fill-cyan-300` — rather than one fixed cyan, which
  // read as saturated confetti against a white card.
  static const _nodeColorLight = Color(0xFF0891B2);
  static const _nodeColorDark = Color(0xFF67E8F9);

  @override
  void paint(Canvas canvas, Size size) {
    final isDark = AppColors.isDark;
    final nodeColor = isDark ? _nodeColorDark : _nodeColorLight;

    final linePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.13)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (final edge in NeuralNetworkBackground._edges) {
      final a = NeuralNetworkBackground._nodes[edge[0]].scale(size.width, size.height);
      final b = NeuralNetworkBackground._nodes[edge[1]].scale(size.width, size.height);
      canvas.drawLine(a, b, linePaint);
    }

    final nodePaint = Paint()..color = nodeColor.withValues(alpha: isDark ? 1 : 0.8);
    final glowPaint = Paint()
      ..color = nodeColor.withValues(alpha: isDark ? 0.5 : 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    for (var i = 0; i < NeuralNetworkBackground._nodes.length; i++) {
      final p = NeuralNetworkBackground._nodes[i].scale(size.width, size.height);
      final r = 1.4 + (i % 3) * 0.5;
      canvas.drawCircle(p, r, i.isEven ? glowPaint : nodePaint);
      canvas.drawCircle(p, r * 0.6, nodePaint..color = nodeColor.withValues(alpha: isDark ? 0.7 : 0.55));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
