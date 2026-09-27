import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'glass_card.dart';

/// A single "instrument tile" for the My Risk dashboard grid — an icon, a
/// monospace value (this is a *reading*, not a headline), a label, and
/// optional trailing context (unit or freshness). Values here are always
/// sourced from real telemetry (a node's last reading or its lastSeen
/// timestamp) — never fabricated, matching how the rest of this app
/// treats sensor honesty (see DemoReading's doc comment).
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
      padding: const EdgeInsets.all(14),
      radius: AppRadius.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
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
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: AppFonts.mono(fontSize: 19, fontWeight: FontWeight.w700)),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(caption!, style: AppFonts.mono(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
          ],
        ],
      ),
    );
  }
}
