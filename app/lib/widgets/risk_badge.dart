import 'package:flutter/material.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';

/// Colour-coding used everywhere a RiskState is shown (map markers, node
/// list, the "My Risk" indicator) — kept in one place so they can't drift
/// apart between screens. Brighter than stock Material tones on purpose:
/// these sit against the app's near-black background (see AppColors in
/// core/theme.dart), and the old muted "material light" set read as
/// muddy there.
Color riskStateColor(RiskState state) {
  switch (state) {
    case RiskState.normal:
      return const Color(0xFF34D399); // emerald
    case RiskState.watch:
      return const Color(0xFFFBBF24); // amber
    case RiskState.warning:
      return const Color(0xFFFB923C); // orange
    case RiskState.evacuate:
      return const Color(0xFFF43F5E); // rose
  }
}

String riskStateLabel(BuildContext context, RiskState state) {
  final l10n = AppLocalizations.of(context)!;
  switch (state) {
    case RiskState.normal:
      return l10n.riskNormal;
    case RiskState.watch:
      return l10n.riskWatch;
    case RiskState.warning:
      return l10n.riskWarning;
    case RiskState.evacuate:
      return l10n.riskEvacuate;
  }
}

class RiskBadge extends StatelessWidget {
  final RiskState state;
  final bool large;

  const RiskBadge({super.key, required this.state, this.large = false});

  @override
  Widget build(BuildContext context) {
    final color = riskStateColor(state);
    final label = riskStateLabel(context, state);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 20 : 10,
        vertical: large ? 10 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(large ? 16 : 999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: large ? 10 : 7,
            height: large ? 10 : 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: large ? 10 : 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: large ? 20 : 13,
            ),
          ),
        ],
      ),
    );
  }
}
