import 'package:flutter/material.dart';

import '../core/theme.dart';

/// The immersive backdrop behind every dashboard screen: a deep vertical
/// gradient, a faint dot grid (the "topographic survey" texture), and two
/// soft off-canvas glow blobs. Replacing a flat solid background with this
/// is most of what separates "dark mode" from "command center" — it gives
/// every glass panel placed on top of it something to actually float over.
class CommandBackground extends StatelessWidget {
  final Widget child;
  final Color glow;

  const CommandBackground({super.key, required this.child, this.glow = AppColors.accent});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.bgTop, AppColors.bgBottom],
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(painter: _DotGridPainter()),
        ),
        Positioned(top: -90, right: -70, child: _Blob(color: glow, size: 260)),
        Positioned(bottom: -120, left: -90, child: _Blob(color: AppColors.accent, size: 320)),
        child,
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withValues(alpha: 0.18), Colors.transparent]),
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  static const _spacing = 26.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.035);
    for (var y = 0.0; y < size.height; y += _spacing) {
      for (var x = 0.0; x < size.width; x += _spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) => false;
}
