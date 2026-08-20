import 'package:flutter/material.dart';

/// A circular progress ring with a live "NN%" readout in the center —
/// swapped in for a plain spinner on the Sign In / Create Account buttons.
/// There's no real progress to report for a login request, so the ring
/// ramps toward ~92% on its own and only completes to 100% once [completed]
/// flips true, giving a believable "working on it… done" feel instead of an
/// indefinite spin.
class PercentLoadingIndicator extends StatefulWidget {
  final bool completed;
  final double size;
  final Color color;
  final Color trackColor;

  const PercentLoadingIndicator({
    super.key,
    required this.completed,
    required this.color,
    required this.trackColor,
    this.size = 28,
  });

  @override
  State<PercentLoadingIndicator> createState() => _PercentLoadingIndicatorState();
}

class _PercentLoadingIndicatorState extends State<PercentLoadingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
    _controller.animateTo(0.92, curve: Curves.easeOutCubic);
    if (widget.completed) _controller.animateTo(1.0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(covariant PercentLoadingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.completed && !oldWidget.completed) {
      _controller.animateTo(1.0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final percent = (_controller.value * 100).round();
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: _controller.value,
                strokeWidth: widget.size / 9,
                strokeCap: StrokeCap.round,
                color: widget.color,
                backgroundColor: widget.trackColor,
              ),
              Text(
                '$percent%',
                style: TextStyle(fontSize: widget.size * 0.3, fontWeight: FontWeight.bold, color: widget.color),
              ),
            ],
          ),
        );
      },
    );
  }
}
