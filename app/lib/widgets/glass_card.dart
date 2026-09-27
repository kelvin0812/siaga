import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Frosted-glass container — a blurred, translucent panel with either a
/// plain hairline border or, when [borderGradient] is given, a 1px glowing
/// gradient ring (drawn by padding a gradient-filled outer box down to a
/// 1px edge around the actual glass content). Used everywhere a card needs
/// to feel like it's floating over the command-center background rather
/// than sitting flush against it.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? glowColor;
  final List<Color>? borderGradient;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = AppRadius.lg,
    this.glowColor,
    this.borderGradient,
  });

  @override
  Widget build(BuildContext context) {
    final glass = ClipRRect(
      borderRadius: BorderRadius.circular(borderGradient == null ? radius : radius - 1),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderGradient == null ? radius : radius - 1),
            border: borderGradient == null ? Border.all(color: AppColors.hairline) : null,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.07),
                Colors.white.withValues(alpha: 0.02),
              ],
            ),
          ),
          child: child,
        ),
      ),
    );

    return Container(
      padding: borderGradient == null ? null : const EdgeInsets.all(1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: borderGradient == null
            ? null
            : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: borderGradient!),
        boxShadow: glowColor != null ? appGlow(glowColor!, alpha: 0.22, blur: 32) : null,
      ),
      child: glass,
    );
  }
}
