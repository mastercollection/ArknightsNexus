import 'package:flutter/material.dart';

import 'rd_tokens.dart';

/// Rotates [child] continuously (sync in progress).
class RdSpin extends StatefulWidget {
  const RdSpin({required this.child, super.key});

  final Widget child;

  @override
  State<RdSpin> createState() => _RdSpinState();
}

class _RdSpinState extends State<RdSpin> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(turns: _controller, child: widget.child);
  }
}

/// UnoCSS `animate-pulse` applied to a whole subtree (opacity 1 -> .5).
class RdPulse extends StatefulWidget {
  const RdPulse({required this.child, super.key});

  final Widget child;

  @override
  State<RdPulse> createState() => _RdPulseState();
}

class _RdPulseState extends State<RdPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  late final Animation<double> _opacity =
      Tween<double>(begin: 1, end: 0.5).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Cubic(0.4, 0, 0.6, 1),
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}

/// Static skeleton block; the pulsing comes from an enclosing [RdPulse].
class RdSkeleton extends StatelessWidget {
  const RdSkeleton({
    this.width,
    this.height = 14,
    this.widthFactor,
    this.radius = RdRadii.pill,
    this.color = RdColors.white8,
    super.key,
  });

  final double? width;
  final double height;

  /// Percentage width (`w-[70%]`), left-aligned.
  final double? widthFactor;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    if (widthFactor == null) {
      return box;
    }
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: box,
    );
  }
}
