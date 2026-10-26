import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/focus_node.dart';
import '../core/models.dart';
import '../core/rig_controller.dart' show kRigNodeId;
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../widgets/active_threat_banner.dart';
import '../widgets/command_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/risk_badge.dart';
import '../widgets/status_message.dart';
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
    final nodes = appState.nodes;

    // Which node this screen shows: the one picked from the list (or from the map), else the live rig in a demo, else
    // the node nearest to the phone. A pick that no longer exists falls back to that default.
    final picked = appState.lockedNodeId == null ? null : nodes.where((n) => n.id == appState.lockedNodeId).firstOrNull;
    if (!appState.demoMode && appState.lockedNodeId != null && picked == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) appState.setLockedNode(null);
      });
    }
    final waitingForRig = appState.rigMode && appState.rigReading == null && picked == null;
    final focusedNode = focusedNodeFor(appState);
    final isRigNode = appState.rigMode && focusedNode != null && focusedNode.id == kRigNodeId;
    final simulated = focusedNode?.simulated ?? false;
    final rig = isRigNode ? appState.rigReading : null;
    final riskState = focusedNode?.state ?? RiskState.normal;
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

    final score = focusedNode?.riskProbability;
    final scoreLabel = isRigNode
        ? (rig?.isStale ?? false ? l10n.rigStatusOffline : l10n.riskScoreLabel)
        : appState.demoMode
            ? 'Simulated severity'
            : 'Tier 2 probability';

    // The first screenful: which node this is, where it stands, then every real sensor with its number and its last
    // 10 minutes.
    // Old data is not "Normal": it is "no live data", and the page says so before it says anything else.
    final stale = isRigNode && rig != null && rig.isStale && !rig.simulated;
    final top = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (nodes.isNotEmpty) ...[
          _NodeBar(
            node: focusedNode,
            automatic: !appState.demoMode && picked == null,
            l10n: l10n,
            onTap: () => _pickNode(context, appState, focusedNode),
          ),
          const SizedBox(height: 12),
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
        else if (stale)
          _StaleHero(state: riskState, rig: rig, l10n: l10n)
        else
          _LevelHero(
            state: riskState,
            score: score,
            scoreLabel: scoreLabel,
            rig: rig,
            showStatus: isRigNode,
            l10n: l10n,
          ),
        if (isRigNode || !appState.rigMode || waitingForRig) ...[
          const SizedBox(height: 20),
          _SectionTitle(title: l10n.riskTrendsTitle, subtitle: stale ? l10n.riskTrendsStale : l10n.riskTrendsSubtitle),
          const SizedBox(height: 12),
          Opacity(opacity: stale ? 0.6 : 1, child: _SensorGrid(appState: appState, l10n: l10n)),
        ],
      ],
    );

    return CommandBackground(
      glow: glowColor,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 110), // clear of the floating nav bar
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  top,
                  if (isRigNode) ...[
                    const SizedBox(height: 12),
                    _RiskHistory(appState: appState, l10n: l10n),
                  ],
                  if (appState.rigMode || hasKnownArea) ...[
                    const SizedBox(height: 16),
                    _StatusPanel(
                      state: riskState,
                      simulated: simulated,
                      waiting: waitingForRig,
                      lastReading: rig != null && rig.isStale ? rig.rowTime : null,
                      onOpenMap: riskState.index >= RiskState.warning.index && !simulated && !(rig?.isStale ?? false)
                          ? () => appState.openTab(0)
                          : null,
                      onShowRig: simulated ? () => appState.setLockedNode(null) : null,
                      l10n: l10n,
                    ),
                  ],
                  if (relevantHazard != null && !appState.rigMode) ...[
                    const SizedBox(height: 16),
                    ActiveThreatBanner(hazard: relevantHazard, message: relevantHazard.messageFor(locale)),
                  ],
                  if (appState.rigMode) ...[
                    const SizedBox(height: 12),
                    _AboutReading(l10n: l10n),
                  ],
                  if (appState.isOffline) ...[
                    const SizedBox(height: 16),
                    Center(child: _OfflinePill(text: l10n.offlineBanner)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickNode(BuildContext context, AppState appState, SiagaNode? current) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (sheetContext) => _NodePicker(
        nodes: appState.nodes,
        selectedId: current?.id,
        allowAutomatic: !appState.demoMode,
        automaticSelected: !appState.demoMode && appState.lockedNodeId == null,
        onPick: (id) {
          appState.setLockedNode(id);
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }

  /// Nearest node by great-circle distance to the last known device
  /// position; falls back to the first node when position isn't known yet
  /// (still real telemetry, just not distance-ranked) or in demo mode
  /// (exactly one node exists).
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

String _formatAgo(DateTime time) => formatAgoShort(time);

const _kStaleColor = Color(0xFFE8833A);

/// What My Risk shows instead of the level when the rig has gone quiet. The green "NORMAL" is a claim about the river,
/// and old data cannot back it up, so the word is neutral, the last known level is small and dimmed, and the status line
/// says how old the data is. (The app still never raises an alert from old data.)
class _StaleHero extends StatelessWidget {
  final RiskState state;
  final RigReading rig;
  final AppLocalizations l10n;
  const _StaleHero({required this.state, required this.rig, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      radius: AppRadius.lg,
      glowColor: _kStaleColor,
      glowAlpha: 0.10,
      glowBlur: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: 0,
                        strokeWidth: 5,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        valueColor: const AlwaysStoppedAnimation(AppColors.textMuted),
                      ),
                    ),
                    const Icon(Icons.sensors_off, color: AppColors.textMuted, size: 26),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.riskNoLive,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.heading(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.4),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.riskLastKnown(riskStateLabel(context, state)),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Opacity(opacity: 0.35, child: _ThreatStepper(current: state)),
          const SizedBox(height: 12),
          // One quiet line says the rig is offline and for how long (orange, like the status on every other page).
          _LiveStatus(reading: rig, l10n: l10n),
        ],
      ),
    );
  }
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
    final forced = r != null && r.simulated; // a phase forced from Settings: say so, never pass it off as the rig
    final color = r == null ? AppColors.textSecondary : (forced ? AppColors.accent : (live ? AppColors.normal : const Color(0xFFE8833A)));
    final text = r == null
        ? l10n.rigWaiting
        : forced
            ? '${l10n.rigStatusSimulated}  ·  ${l10n.simulatingNow('${r.phase}')}'
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

/// Which node the screen is showing, as a bar you tap to choose another. It sits above everything so the source of
/// every number below it is never in doubt.
class _NodeBar extends StatelessWidget {
  final SiagaNode? node;
  final bool automatic;
  final AppLocalizations l10n;
  final VoidCallback onTap;
  const _NodeBar({required this.node, required this.automatic, required this.l10n, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final n = node;
    final color = n == null ? AppColors.textSecondary : riskStateColor(n.state);
    final kind = n == null ? '' : (n.simulated ? l10n.nodeKindDemo : l10n.nodeKindSensor);
    return GlassCard(
      padding: EdgeInsets.zero,
      radius: AppRadius.md,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.16),
                    border: Border.all(color: color.withValues(alpha: 0.7)),
                  ),
                  child: Icon(n?.simulated == true ? Icons.science_outlined : Icons.sensors, color: color, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.riskViewing, style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                      Text(
                        n?.name ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15.5, fontWeight: FontWeight.w700),
                      ),
                      if (n != null)
                        Text(
                          '$kind  ·  ${n.lat.toStringAsFixed(4)}, ${n.lon.toStringAsFixed(4)}${automatic ? '  ·  ${l10n.riskSelectorAuto}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.unfold_more, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The list of every node, to pick the one the screen should show. Searchable, because an authority may be looking
/// across many nodes. Real sensors come first, then the simulated demo nodes, each group with the most severe first.
class _NodePicker extends StatefulWidget {
  final List<SiagaNode> nodes;
  final int? selectedId;
  final bool allowAutomatic;
  final bool automaticSelected;
  final ValueChanged<int?> onPick;
  const _NodePicker({
    required this.nodes,
    required this.selectedId,
    required this.allowAutomatic,
    required this.automaticSelected,
    required this.onPick,
  });

  @override
  State<_NodePicker> createState() => _NodePickerState();
}

class _NodePickerState extends State<_NodePicker> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  int _bySeverity(SiagaNode a, SiagaNode b) {
    final c = b.state.index.compareTo(a.state.index);
    return c != 0 ? c : a.name.compareTo(b.name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final q = _query.text.trim().toLowerCase();
    final matches = widget.nodes.where((n) => q.isEmpty || n.name.toLowerCase().contains(q)).toList();
    final real = matches.where((n) => !n.simulated).toList()..sort(_bySeverity);
    final demo = matches.where((n) => n.simulated).toList()..sort(_bySeverity);

    Widget group(String title) => Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
          child: Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w700)),
        );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(l10n.nodePickerTitle, style: Theme.of(context).textTheme.titleLarge),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l10n.nodePickerSearch,
                    isDense: true,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  children: [
                    if (widget.allowAutomatic && q.isEmpty)
                      _PickerRow(
                        icon: Icons.my_location,
                        color: AppColors.accent,
                        title: l10n.nodeAutoPick,
                        subtitle: null,
                        trailing: null,
                        selected: widget.automaticSelected,
                        onTap: () => widget.onPick(null),
                      ),
                    if (real.isNotEmpty) ...[
                      group('${l10n.nodeGroupSensor} (${real.length})'),
                      for (final n in real) _row(context, n),
                    ],
                    if (demo.isNotEmpty) ...[
                      group('${l10n.nodeGroupDemo} (${demo.length})'),
                      for (final n in demo) _row(context, n),
                    ],
                    if (matches.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(l10n.nodeNoMatch, style: const TextStyle(color: AppColors.textSecondary)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, SiagaNode n) {
    final l10n = AppLocalizations.of(context)!;
    final color = riskStateColor(n.state);
    final kind = n.simulated ? l10n.nodeKindDemo : l10n.nodeKindSensor;
    return _PickerRow(
      icon: n.simulated ? Icons.science_outlined : Icons.sensors,
      color: color,
      title: n.name,
      subtitle: n.lastSeen != null ? '$kind  ·  ${_formatAgo(n.lastSeen!)}' : kind,
      trailing: riskStateLabel(context, n.state),
      selected: widget.automaticSelected ? false : n.id == widget.selectedId,
      onTap: () => widget.onPick(n.id),
    );
  }
}

class _PickerRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final String? trailing;
  final bool selected;
  final VoidCallback onTap;
  const _PickerRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            color: selected ? color.withValues(alpha: 0.12) : null,
            border: selected ? Border.all(color: color.withValues(alpha: 0.6)) : null,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.16),
                  border: Border.all(color: color.withValues(alpha: 0.7)),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                    if (subtitle != null)
                      Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              if (trailing != null) Text(trailing!, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w700)),
              if (selected) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_circle, color: color, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// What the current level means in plain words, with the one thing worth doing about it. A single card replaces the
/// separate "what this means", "no active threats" and numbered-steps cards.
class _StatusPanel extends StatelessWidget {
  final RiskState state;
  final bool simulated;
  final bool waiting;
  final DateTime? lastReading;
  final VoidCallback? onOpenMap;
  final VoidCallback? onShowRig;
  final AppLocalizations l10n;
  const _StatusPanel({
    required this.state,
    required this.simulated,
    required this.waiting,
    required this.lastReading,
    required this.onOpenMap,
    required this.onShowRig,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final message = statusMessageFor(
      l10n,
      state: state,
      noSensors: simulated,
      waiting: waiting,
      lastReading: lastReading,
    );
    final title = message.title;
    final detail = message.detail;
    final color = message.color;
    final icon = message.icon;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      radius: AppRadius.md,
      glowColor: color,
      glowAlpha: 0.12,
      glowBlur: 20,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.15)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppFonts.heading(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: 0)),
                const SizedBox(height: 4),
                Text(detail, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14.5, height: 1.45)),
                if (onOpenMap != null || onShowRig != null) ...[
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    onPressed: onOpenMap ?? onShowRig,
                    icon: Icon(onOpenMap != null ? Icons.map_outlined : Icons.sensors, size: 18),
                    label: Text(onOpenMap != null ? l10n.openMapBtn : l10n.simShowRig),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// How the level is decided, tucked away until someone wants it.
class _AboutReading extends StatelessWidget {
  final AppLocalizations l10n;
  const _AboutReading({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      radius: AppRadius.md,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          iconColor: AppColors.textSecondary,
          collapsedIconColor: AppColors.textSecondary,
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text(l10n.howTitle2, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w600)),
          children: [Text(l10n.howBody, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5))],
        ),
      ),
    );
  }
}
