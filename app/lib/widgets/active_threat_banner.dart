import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/theme.dart';
import 'glass_card.dart';
import 'risk_badge.dart';

/// High-visibility banner for an active hazard — a glowing gradient-bordered
/// panel with a pulsing beacon dot, replacing the old plain message card.
/// Motion here is deliberate: this is the one element on the dashboard
/// that should visually interrupt, because it's the one that matters.
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

    return GlassCard(
      glowColor: color,
      borderGradient: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.15)],
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
