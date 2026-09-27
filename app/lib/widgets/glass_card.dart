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
  final double glowAlpha;
  final double glowBlur;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = AppRadius.lg,
    this.glowColor,
    this.borderGradient,
    this.glowAlpha = 0.22,
    this.glowBlur = 32,
  });

  @override
  Widget build(BuildContext context) {
    // The glass wash itself picks up a whisper of the card's own glow
    // colour in its top-left corner (falling back to plain white when
    // there isn't one) rather than staying neutral grey — this is what
    // ties "this card glows red" through to "this card's glass is warm"
    // instead of the glow being a shadow bolted on top of an unrelated
    // panel. Kept under 10% alpha so it reads as tinted glass, not a
    // colour fill.
    final washTint = glowColor ?? Colors.white;
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
                washTint.withValues(alpha: glowColor != null ? 0.09 : 0.07),
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
        boxShadow: glowColor != null ? appGlow(glowColor!, alpha: glowAlpha, blur: glowBlur) : null,
      ),
      child: glass,
    );
  }
}
