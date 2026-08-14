import 'package:flutter/material.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';

/// Colour-coding used everywhere a RiskState is shown (map markers, node
/// list, the "My Risk" indicator) — kept in one place so they can't drift
/// apart between screens.
Color riskStateColor(RiskState state) {
  switch (state) {
    case RiskState.normal:
      return const Color(0xFF2E7D32); // green
    case RiskState.watch:
      return const Color(0xFFF9A825); // yellow
    case RiskState.warning:
      return const Color(0xFFEF6C00); // orange
    case RiskState.evacuate:
      return const Color(0xFFC62828); // red
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
        color: color,
        borderRadius: BorderRadius.circular(large ? 16 : 8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: large ? 22 : 13,
        ),
      ),
    );
  }
}
