import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../widgets/active_threat_banner.dart';
import '../widgets/command_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/micro_metric_card.dart';
import '../widgets/risk_badge.dart';
import '../widgets/risk_gauge.dart';

/// Section 6.4: "Prominent four-level risk indicator for the user's own
/// cell." Redesigned as a command-center dashboard: a telemetry-dial gauge
/// for the at-a-glance read, a threat-level stepper, a grid of live
/// micro-metrics around it, and a pulsing "active threat" banner when a
/// hazard applies. On wide viewports (tablet/desktop — this screen also
/// serves the web preview build) the gauge and metrics sit side by side
/// instead of stacking into one narrow column with wasted margins.
class RiskScreen extends StatefulWidget {
  const RiskScreen({super.key});

  @override
  State<RiskScreen> createState() => _RiskScreenState();
}

class _RiskScreenState extends State<RiskScreen> {
  static const _wideBreakpoint = 720.0;

  int? _fetchedForNodeId;
  NodeReading? _liveReading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final cellId = appState.currentCellId;

    // Mentor feedback: the risk indicator should be tied to a specific
    // node, not only an automatic "nearest to my GPS" guess — resolved
    // via AppState.lockedNodeId, settable here (dropdown) or from the map
    // screen's "lock to this node" button; both write the same field.
    // Falls back to nearest-by-GPS when nothing is locked (unchanged
    // default), and auto-clears a lock whose node vanished from the last
    // /nodes fetch rather than showing stale data.
    final nearestByGps = _nearestNode(appState);
    if (!appState.demoMode && appState.lockedNodeId != null &&
        appState.nodes.every((n) => n.id != appState.lockedNodeId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) appState.setLockedNode(null);
      });
    }
    final focusedNode = appState.demoMode
        ? null
        : (appState.lockedNodeId != null
            ? appState.nodes.where((n) => n.id == appState.lockedNodeId).firstOrNull
            : null) ??
            nearestByGps;

    // Demo mode still drives the gauge from the demo hydrograph directly
    // (its own well-defined single-node flow via Settings' state buttons);
    // real mode now reads a node's own state/probability straight from the
    // backend rather than the more fragile GPS-cell/hazard-polygon match.
    final riskState = appState.demoMode ? appState.myRiskState : (focusedNode?.state ?? RiskState.normal);
    final hasKnownArea = appState.demoMode || focusedNode != null;

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
    final glowColor = hasKnownArea ? riskStateColor(riskState) : AppColors.accent;

    if (!appState.demoMode && focusedNode != null && focusedNode.id != _fetchedForNodeId) {
      _fetchedForNodeId = focusedNode.id;
      unawaited(_fetchLatestReading(appState.api, focusedNode.id));
    }

    final metrics = _MetricsPanel(
      appState: appState,
      nearest: focusedNode,
      liveReading: appState.demoMode ? null : _liveReading,
      l10n: l10n,
    );

    final gaugeColumn = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.myRiskTitle.toUpperCase(),
          style: AppFonts.heading(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 2.0),
        ),
        if (!appState.demoMode && appState.nodes.length > 1) ...[
          const SizedBox(height: 14),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${l10n.riskSelectorLabel}: ',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              _NodeSelector(
                nodes: appState.nodes,
                selectedNodeId: appState.lockedNodeId,
                onChanged: appState.setLockedNode,
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        if (!hasKnownArea)
          GlassCard(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const Icon(Icons.location_searching, color: AppColors.textSecondary, size: 32),
                const SizedBox(height: 12),
                Text(l10n.myRiskNoCell, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          )
        else
          RiskGauge(
            state: riskState,
            probability: appState.demoMode ? appState.nodes.firstOrNull?.riskProbability : focusedNode?.riskProbability,
            probabilityLabel: appState.demoMode ? 'Simulated severity' : 'Tier 2 probability',
          ),
        const SizedBox(height: 24),
        if (hasKnownArea) _ThreatStepper(current: riskState),
      ],
    );

    return CommandBackground(
      glow: glowColor,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _wideBreakpoint;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: gaugeColumn),
                            const SizedBox(width: 28),
                            Expanded(
                              flex: 6,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  metrics,
                                  const SizedBox(height: 16),
                                  _ThreatOrAllClear(hazard: relevantHazard, locale: locale),
                                  const SizedBox(height: 16),
                                  _Attribution(l10n: l10n, offline: appState.isOffline, showSourceLine: relevantHazard == null),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            gaugeColumn,
                            const SizedBox(height: 24),
                            metrics,
                            const SizedBox(height: 16),
                            _ThreatOrAllClear(hazard: relevantHazard, locale: locale),
                            const SizedBox(height: 16),
                            _Attribution(l10n: l10n, offline: appState.isOffline, showSourceLine: relevantHazard == null),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Nearest node by great-circle distance to the last known device
  /// position; falls back to the first node when position isn't known yet
  /// (still real telemetry, just not distance-ranked) or in demo mode
  /// (exactly one node exists).
  SiagaNode? _nearestNode(AppState appState) {
    if (appState.nodes.isEmpty) return null;
    final position = appState.locationService.lastKnownPosition;
    if (position == null) return appState.nodes.first;
    return appState.nodes.reduce((a, b) {
      final da = Geolocator.distanceBetween(position.latitude, position.longitude, a.lat, a.lon);
      final db = Geolocator.distanceBetween(position.latitude, position.longitude, b.lat, b.lon);
      return da <= db ? a : b;
    });
  }

  Future<void> _fetchLatestReading(ApiClient api, int nodeId) async {
    try {
      final history = await api.getNodeHistory(nodeId, hours: 1);
      if (history.isEmpty) return;
      final latest = history.reduce((a, b) => a.receivedAt.isAfter(b.receivedAt) ? a : b);
      if (mounted && _fetchedForNodeId == nodeId) setState(() => _liveReading = latest);
    } on ApiException {
      // Leave _liveReading as whatever it was — metrics degrade to "—"
      // rather than the screen crashing (Section 2: degrade visibly).
    }
  }
}

/// Dropdown letting the resident explicitly pick which node's risk level
/// to view — the same underlying selection as the map screen's "lock to
/// this node" button (AppState.lockedNodeId). Null stays "Auto," the
/// original nearest-by-GPS behaviour.
class _NodeSelector extends StatelessWidget {
  final List<SiagaNode> nodes;
  final int? selectedNodeId;
  final ValueChanged<int?> onChanged;

  const _NodeSelector({required this.nodes, required this.selectedNodeId, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.hairline),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: selectedNodeId != null && nodes.any((n) => n.id == selectedNodeId) ? selectedNodeId : null,
          isDense: true,
          icon: const Icon(Icons.expand_more, color: AppColors.textSecondary, size: 18),
          dropdownColor: AppColors.surfaceRaised,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.my_location, size: 14, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text(l10n.riskSelectorAuto),
                ],
              ),
            ),
            ...nodes.map(
              (n) => DropdownMenuItem<int?>(
                value: n.id,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, size: 13, color: riskStateColor(n.state)),
                    const SizedBox(width: 6),
                    Text(n.name, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// The four RiskStates laid out as a horizontal stepper — every level is
/// always visible, not just whichever one is active, so the resident can
/// see at a glance how close (or far) the current reading is from
/// escalating further.
class _ThreatStepper extends StatelessWidget {
  final RiskState current;
  const _ThreatStepper({required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: RiskState.values.map((state) {
        final isCurrent = state == current;
        final isPast = state.index < current.index;
        final color = riskStateColor(state);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: isCurrent || isPast ? color : Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: isCurrent ? appGlow(color, alpha: 0.5, blur: 12) : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  riskStateLabel(context, state),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                    color: isCurrent ? color : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// The instrument grid: rainfall gauge, water level, distance to the
/// nearest node, and time since its last transmission. Column count
/// adapts to available width via GridView so wide viewports fill out
/// instead of leaving margins empty.
class _MetricsPanel extends StatelessWidget {
  final AppState appState;
  final SiagaNode? nearest;
  final NodeReading? liveReading;
  final AppLocalizations l10n;

  const _MetricsPanel({required this.appState, required this.nearest, required this.liveReading, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final demo = appState.demoReading;
    final rainTips = appState.demoMode ? demo?.rainTips : liveReading?.rainTips;
    final heightM = appState.demoMode ? demo?.heightM : liveReading?.heightM;

    final position = appState.locationService.lastKnownPosition;
    final distanceM = (nearest != null && position != null)
        ? Geolocator.distanceBetween(position.latitude, position.longitude, nearest!.lat, nearest!.lon)
        : null;

    final items = [
      MicroMetricCard(
        icon: Icons.water_drop_outlined,
        label: 'Rain Gauge',
        value: rainTips != null ? '$rainTips' : '—',
        caption: 'tips since last tx',
        accent: AppColors.accent,
      ),
      MicroMetricCard(
        icon: Icons.waves,
        label: 'Water Level',
        value: heightM != null ? heightM.toStringAsFixed(2) : '—',
        caption: heightM != null ? 'm above datum' : null,
        accent: AppColors.watch,
      ),
      MicroMetricCard(
        icon: Icons.social_distance_outlined,
        label: 'Distance',
        value: distanceM != null ? _formatDistance(distanceM) : '—',
        caption: nearest != null ? nearest!.name : 'nearest node',
        accent: AppColors.accent,
      ),
      MicroMetricCard(
        icon: Icons.sync,
        label: 'Last Sync',
        value: nearest?.lastSeen != null ? _formatAgo(nearest!.lastSeen!) : '—',
        caption: nearest != null ? 'node #${nearest!.id}' : null,
        accent: AppColors.normal,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 480 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: columns == 4 ? 1.05 : 1.35,
          children: items,
        );
      },
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)}km';
    return '${meters.round()}m';
  }

  String _formatAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _ThreatOrAllClear extends StatelessWidget {
  final Hazard? hazard;
  final String locale;
  const _ThreatOrAllClear({required this.hazard, required this.locale});

  @override
  Widget build(BuildContext context) {
    if (hazard != null) {
      return ActiveThreatBanner(hazard: hazard!, message: hazard!.messageFor(locale));
    }
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: AppColors.normal, size: 18),
          const SizedBox(width: 10),
          Text(
            'NO ACTIVE THREATS',
            style: AppFonts.mono(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.normal, letterSpacing: 0.8),
          ),
        ],
      ),
    );
  }
}

class _Attribution extends StatelessWidget {
  final AppLocalizations l10n;
  final bool offline;
  // False when ActiveThreatBanner is already showing (mentor feedback:
  // its message already ends with this exact sourceAttribution string —
  // see fcm.py's templates / demo_controller.dart's _alertCopyFor — so
  // repeating it here in faint muted text right underneath was a
  // duplicate, not a second piece of information, and read as clutter).
  final bool showSourceLine;
  const _Attribution({required this.l10n, required this.offline, required this.showSourceLine});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showSourceLine)
          Text(
            l10n.sourceAttribution,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.45, fontWeight: FontWeight.w500),
          ),
        if (offline) ...[
          if (showSourceLine) const SizedBox(height: 12),
          _OfflinePill(text: l10n.offlineBanner),
        ],
      ],
    );
  }
}

class _OfflinePill extends StatelessWidget {
  final String text;
  const _OfflinePill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
