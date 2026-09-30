import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/theme.dart';
import 'risk_badge.dart';

/// High-visibility banner for an active hazard. Used to be a full GlassCard
/// with a glowing gradient border + boxShadow halo — team feedback was that
/// the saturated colour wash was too loud, more distracting than legible.
/// Flat dark card + a single coloured left accent bar reads as "this is an
/// alert" without dominating the screen; the pulsing beacon dot still
/// carries the "something is happening" motion cue on its own.
class ActiveThreatBanner extends StatefulWidget {
  final Hazard hazard;
  final String message;

  const ActiveThreatBanner({super.key, required this.hazard, required this.message});

  @override
  State<ActiveThreatBanner> createState() => _ActiveThreatBannerState();
}

class _ActiveThreatBannerState extends State<ActiveThreatBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _beacon = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _beacon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = riskStateColor(widget.hazard.state);
    final label = riskStateLabel(context, widget.hazard.state);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        // A single flat-coloured left accent edge instead of a glowing
        // gradient border wrapping the whole card.
        border: Border(
          top: const BorderSide(color: AppColors.hairline),
          right: const BorderSide(color: AppColors.hairline),
          bottom: const BorderSide(color: AppColors.hairline),
          left: BorderSide(color: color, width: 3),
        ),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.16), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _beacon,
                builder: (context, _) {
                  final t = _beacon.value;
                  return SizedBox(
                    width: 20,
                    height: 20,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: (1 - t) * 0.7,
                          child: Container(
                            width: 10 + t * 14,
                            height: 10 + t * 14,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.6)),
                          ),
                        ),
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),
              Text(
                'ACTIVE THREAT · ${label.toUpperCase()}',
                style: AppFonts.mono(fontSize: 12, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.message,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.45, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
