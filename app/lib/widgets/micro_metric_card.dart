import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'glass_card.dart';

/// A single "instrument tile" for the My Risk dashboard grid — an icon
/// label, a monospace reading, and an optional caption. The reading is
/// always real telemetry (a node's last sensor value or its lastSeen
/// timestamp) — never fabricated, matching how the rest of this app
/// treats sensor honesty (see DemoReading's doc comment).
///
/// Only [value] is set in monospace. [label] and [caption] are UI text —
/// a unit description ("tips since last tx") or a node's name — not
/// telemetry themselves, so they stay in the app's one sans family
/// (AppFonts governs the split; see its doc comment).
class MicroMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  final Color accent;

  const MicroMetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
    this.accent = AppColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      radius: AppRadius.md,
      glowColor: accent,
      glowAlpha: 0.12,
      glowBlur: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppFonts.mono(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          if (caption != null) ...[
            const SizedBox(height: 3),
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.w400),
            ),
          ],
        ],
      ),
    );
  }
}
