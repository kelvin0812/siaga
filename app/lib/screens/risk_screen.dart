import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../widgets/active_threat_banner.dart';
import '../widgets/command_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/risk_badge.dart';
import '../widgets/rig_trend_card.dart';

/// Section 6.4: "Prominent four-level risk indicator for the user's own
/// cell." Redesigned as a command-center dashboard: a telemetry-dial gauge
/// for the at-a-glance read, a threat-level stepper, a grid of live
/// micro-metrics around it, and a pulsing "active threat" banner when a
/// hazard applies. One column at every width, in reading order: the threat
/// level first, then the live readings, then the trends behind them. On wide
/// viewports (this screen also serves the web build) the column stays a
/// readable width and only the trend charts split into two columns.
class RiskScreen extends StatefulWidget {
  const RiskScreen({super.key});

  @override
  State<RiskScreen> createState() => _RiskScreenState();
}

class _RiskScreenState extends State<RiskScreen> {
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
    // Demo mode has exactly one node (the simulated one) -- feed it to the
    // metrics panel as `nearest` too, rather than leaving it null, so the
    // Distance/Last Sync cards have something to show instead of "—"
    // during a demo. (Real-mode locking/nearest-by-GPS logic below is
    // unrelated and unaffected by this.)
    final focusedNode = appState.demoMode
        ? appState.nodes.firstOrNull
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

    final score = appState.demoMode ? appState.nodes.firstOrNull?.riskProbability : focusedNode?.riskProbability;
    final scoreLabel = appState.rigMode
        ? (appState.rigReading?.isStale ?? false ? l10n.rigStatusOffline : l10n.riskScoreLabel)
        : appState.demoMode
            ? 'Simulated severity'
            : 'Tier 2 probability';

    // The first screenful: where the area stands, then every real sensor with its number and its last 10 minutes.
    final top = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!appState.demoMode && appState.nodes.length > 1) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
          const SizedBox(height: 14),
        ],
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
          _LevelHero(
            state: riskState,
            score: score,
            scoreLabel: scoreLabel,
            rig: appState.rigMode ? appState.rigReading : null,
            showStatus: appState.rigMode,
            l10n: l10n,
          ),
        const SizedBox(height: 20),
        _SectionTitle(title: l10n.riskTrendsTitle, subtitle: l10n.riskTrendsSubtitle),
        const SizedBox(height: 12),
        _SensorGrid(appState: appState, l10n: l10n),
      ],
    );

    final attribution = _Attribution(l10n: l10n, offline: appState.isOffline, showSourceLine: relevantHazard == null);

    return CommandBackground(
      glow: glowColor,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 110), // clear of the floating nav bar
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      top,
                      if (appState.rigMode) ...[
                        const SizedBox(height: 12),
                        _RiskHistory(appState: appState, l10n: l10n),
                        const SizedBox(height: 16),
                        _SummaryCard(state: riskState, stale: appState.rigReading?.isStale ?? true, l10n: l10n),
                      ],
                      const SizedBox(height: 16),
                      _ThreatOrAllClear(hazard: relevantHazard, locale: locale),
                      if (appState.rigMode) ...[
                        const SizedBox(height: 24),
                        _HowItWorks(l10n: l10n),
                      ],
                      const SizedBox(height: 16),
                      attribution,
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

/// The four real sensors as tiles: the number big, what it means in a few words, and its last 10 minutes right
/// under it, so the live data is the first thing seen. Four across on a wide screen, two on a phone.
class _SensorGrid extends StatelessWidget {
  final AppState appState;
  final AppLocalizations l10n;
  const _SensorGrid({required this.appState, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final points = appState.rigMode ? appState.rigTrend : const <RigPoint>[];
    final r = appState.rigMode ? appState.rigReading : null;
    final tiles = <Widget>[
      RigTrendCard(
        dense: true,
        icon: Icons.waves,
        title: l10n.rigMetricLevel,
        help: l10n.trendLevelHelp,
        caption: l10n.rigMetricLevelCaption,
        color: AppColors.watch,
        points: points,
        valueOf: (p) => p.heightCm,
        latestText: r == null ? '—' : r.heightCm.toStringAsFixed(1),
        unit: 'cm',
        minSpan: 2,
      ),
      RigTrendCard(
        dense: true,
        icon: Icons.water_drop_outlined,
        title: l10n.rigMetricFlow,
        help: l10n.trendFlowHelp,
        caption: l10n.rigMetricFlowCaption,
        color: AppColors.accent,
        points: points,
        valueOf: (p) => p.flow,
        latestText: r == null ? '—' : r.flow.toStringAsFixed(0),
        unit: l10n.rigUnitPulses,
        decimals: 0,
        minSpan: 4,
      ),
      RigTrendCard(
        dense: true,
        icon: Icons.grass,
        title: l10n.rigMetricSoil,
        help: l10n.trendSoilHelp,
        caption: l10n.rigMetricSoilCaption,
        color: const Color(0xFFA78BFA),
        points: points,
        valueOf: (p) => p.soilRaw,
        latestText: r == null ? '—' : r.soilRaw.toStringAsFixed(0),
        unit: '',
        decimals: 0,
        minSpan: 40,
      ),
      RigTrendCard(
        dense: true,
        icon: Icons.rotate_right,
        title: l10n.rigMetricTilt,
        help: l10n.trendTiltHelp,
        caption: l10n.rigMetricTiltCaption,
        color: AppColors.normal,
        points: points,
        valueOf: (p) => p.tiltDeg,
        latestText: r == null ? '—' : r.tiltDeg.toStringAsFixed(1),
        unit: '°',
        minSpan: 4,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 840 ? 4 : 2;
        final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final tile in tiles) SizedBox(width: width, child: tile)],
        );
      },
    );
  }
}

/// The model's decision over the same 10 minutes, as steps from Normal to Evacuate.
class _RiskHistory extends StatelessWidget {
  final AppState appState;
  final AppLocalizations l10n;
  const _RiskHistory({required this.appState, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final r = appState.rigReading;
    final state = r == null ? RiskState.normal : RiskState.values[r.phase - 1];
    return RigTrendCard(
      icon: Icons.shield_outlined,
      title: l10n.trendRisk,
      help: l10n.trendRiskHelp,
      color: riskStateColor(state),
      points: appState.rigTrend,
      valueOf: (p) => p.phase.toDouble(),
      latestText: r == null ? '—' : riskStateLabel(context, state),
      phaseAxis: true,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: AppFonts.heading(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 2.0),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ],
    );
  }
}

/// Where the area stands, in one strip: a ring for the risk score, the level in large type, the four-step scale and
/// whether the rig is live. It replaces the large dial so the sensor tiles can sit on the first screen.
class _LevelHero extends StatelessWidget {
  final RiskState state;
  final double? score;
  final String scoreLabel;
  final RigReading? rig;
  final bool showStatus;
  final AppLocalizations l10n;
  const _LevelHero({
    required this.state,
    required this.score,
    required this.scoreLabel,
    required this.rig,
    required this.showStatus,
    required this.l10n,
  });

  IconData get _icon => switch (state) {
        RiskState.normal => Icons.check_circle_outline,
        RiskState.watch => Icons.visibility_outlined,
        RiskState.warning => Icons.warning_amber_rounded,
        RiskState.evacuate => Icons.crisis_alert,
      };

  @override
  Widget build(BuildContext context) {
    final color = riskStateColor(state);
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      radius: AppRadius.lg,
      glowColor: color,
      glowAlpha: 0.20,
      glowBlur: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 84,
                height: 84,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: (score ?? 0).clamp(0.0, 1.0),
                        strokeWidth: 7,
                        strokeCap: StrokeCap.round,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                    Icon(_icon, color: color, size: 34),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.myRiskTitle.toUpperCase(),
                      style: AppFonts.heading(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 1.8),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      riskStateLabel(context, state).toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.heading(fontSize: 32, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.4),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 14,
                      children: [
                        Text('LVL ${state.index + 1}/4', style: AppFonts.mono(fontSize: 12, color: AppColors.textSecondary)),
                        if (score != null)
                          Text(
                            '${scoreLabel.toUpperCase()} ${(score! * 100).round()}%',
                            style: AppFonts.mono(fontSize: 12, color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ThreatStepper(current: state),
          if (showStatus) ...[
            const SizedBox(height: 12),
            _LiveStatus(reading: rig, l10n: l10n),
          ],
        ],
      ),
    );
  }
}

String _formatAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

/// A small status line over the tiles: a green dot while the rig is sending, an orange one when it has gone quiet,
/// so nobody mistakes old numbers for live ones.
class _LiveStatus extends StatelessWidget {
  final RigReading? reading;
  final AppLocalizations l10n;
  const _LiveStatus({required this.reading, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final r = reading;
    final live = r != null && !r.isStale;
    final color = r == null ? AppColors.textSecondary : (live ? AppColors.normal : const Color(0xFFE8833A));
    final text = r == null
        ? l10n.rigWaiting
        : live
            ? '${l10n.rigStatusLive}  ·  ${l10n.benchSensorUpdated} ${_formatAgo(r.rowTime)}'
            : '${l10n.rigStatusOffline}  ·  ${l10n.rigLastData} ${_formatAgo(r.rowTime)}';
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: live ? appGlow(color, alpha: 0.6, blur: 8) : null),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// One plain sentence on what the current level means for a resident, so the colours do not need explaining.
class _SummaryCard extends StatelessWidget {
  final RiskState state;
  final bool stale;
  final AppLocalizations l10n;
  const _SummaryCard({required this.state, required this.stale, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final color = stale ? AppColors.textSecondary : riskStateColor(state);
    final text = stale
        ? l10n.riskSummaryOffline
        : switch (state) {
            RiskState.normal => l10n.riskSummaryNormal,
            RiskState.watch => l10n.riskSummaryWatch,
            RiskState.warning => l10n.riskSummaryWarning,
            RiskState.evacuate => l10n.riskSummaryEvacuate,
          };
    return GlassCard(
      padding: const EdgeInsets.all(18),
      radius: AppRadius.md,
      glowColor: color,
      glowAlpha: 0.12,
      glowBlur: 20,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.riskSummaryTitle.toUpperCase(),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                ),
                const SizedBox(height: 6),
                Text(text, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.4, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Three short steps on how a reading becomes a warning, for anyone seeing SIAGA for the first time.
class _HowItWorks extends StatelessWidget {
  final AppLocalizations l10n;
  const _HowItWorks({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final steps = [l10n.howStep1, l10n.howStep2, l10n.howStep3];
    return GlassCard(
      padding: const EdgeInsets.all(20),
      radius: AppRadius.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.howTitle.toUpperCase(),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accent.withValues(alpha: 0.18)),
                    child: Text('${i + 1}', style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(steps[i], style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.45))),
                ],
              ),
            ),
        ],
      ),
    );
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
