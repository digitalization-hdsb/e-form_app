import 'package:flutter/material.dart';

import '../core/theme.dart';

/// A pulsing placeholder box — mirrors the website's `animate-pulse`
/// Skeleton component (components/ui/skeleton.tsx).
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const SkeletonBox({super.key, this.width, this.height = 16, this.borderRadius = const BorderRadius.all(Radius.circular(8))});

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  late final Animation<double> _opacity = Tween(begin: 0.45, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: AppColors.border, borderRadius: widget.borderRadius),
      ),
    );
  }
}

/// A handful of card-row placeholders — for screens that already render
/// their own header/filter chrome and just need the *list* area below it
/// to show a loading shape instead of a lone spinner.
class ListRowsSkeleton extends StatelessWidget {
  final int rows;
  final EdgeInsets padding;

  const ListRowsSkeleton({super.key, this.rows = 6, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      children: [
        for (var i = 0; i < rows; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          SkeletonBox(height: 72, borderRadius: BorderRadius.circular(14)),
        ],
      ],
    );
  }
}

/// Mirrors components/HRModuleSkeleton.tsx — a header placeholder, a row of
/// stat-card placeholders, and a card of list-row placeholders. Shown while
/// a dashboard's first page of data is loading, in place of a bare spinner
/// that gives no sense of the page's shape.
class DashboardSkeleton extends StatelessWidget {
  final int cards;
  final int rows;

  const DashboardSkeleton({super.key, this.cards = 3, this.rows = 5});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Row(
          children: [
            SkeletonBox(width: 40, height: 40, borderRadius: BorderRadius.circular(12)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonBox(width: 160, height: 16),
                  const SizedBox(height: 8),
                  SkeletonBox(width: MediaQuery.of(context).size.width * 0.5, height: 12),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            for (var i = 0; i < cards; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 78, borderRadius: BorderRadius.circular(14))),
            ],
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SkeletonBox(width: 120, height: 16),
                  const Spacer(),
                  SkeletonBox(width: 72, height: 30, borderRadius: BorderRadius.circular(999)),
                ],
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < rows; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                SkeletonBox(height: 52, borderRadius: BorderRadius.circular(10)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
