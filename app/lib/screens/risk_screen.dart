import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import '../widgets/risk_badge.dart';

/// Section 6.4: "Prominent four-level risk indicator for the user's own
/// cell." This is the screen a resident glances at to answer "am I okay
/// right now" without reading a map.
class RiskScreen extends StatelessWidget {
  const RiskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final cellId = appState.currentCellId;
    final riskState = appState.myRiskState;
    // Demo mode has no real GPS-derived cell to key off (see
    // AppState.myRiskState) — treat it as "known" here too, otherwise
    // the badge stays hidden behind myRiskNoCell throughout a demo.
    final hasKnownArea = appState.demoMode || cellId != null;

    final relevantHazard = appState.demoMode
        ? appState.activeHazards.fold<Hazard?>(null, (best, h) {
            if (best == null || h.state.index > best.state.index) return h;
            return best;
          })
        : appState.activeHazards
            .where((h) => cellId != null && h.cells.contains(cellId))
            .fold<Hazard?>(null, (best, h) {
            if (best == null || h.state.index > best.state.index) return h;
            return best;
          });

    final locale = Localizations.localeOf(context).languageCode;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(l10n.myRiskTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              if (!hasKnownArea)
                Text(l10n.myRiskNoCell)
              else
                RiskBadge(state: riskState, large: true),
              const SizedBox(height: 24),
              if (relevantHazard != null) ...[
                Text(
                  relevantHazard.messageFor(locale),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
              ],
              Text(
                l10n.sourceAttribution,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (appState.isOffline) ...[
                const SizedBox(height: 16),
                Text(l10n.offlineBanner, style: const TextStyle(color: Colors.grey)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
