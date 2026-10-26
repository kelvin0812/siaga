import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
import '../core/app_state.dart';
import '../core/bench_sensor_service.dart';
import '../core/fcm_service.dart';
import '../core/locale_provider.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../demo/demo_controller.dart';
import '../core/rig_controller.dart';
import '../l10n/app_localizations.dart';
import '../widgets/command_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/risk_badge.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  NotificationPermissionStatus? _notificationStatus;

  @override
  void initState() {
    super.initState();
    _refreshNotificationStatus();
  }

  Future<void> _refreshNotificationStatus() async {
    final status = await context.read<FcmService>().checkPermissionStatus();
    if (mounted) setState(() => _notificationStatus = status);
  }

  Future<void> _enableNotifications() async {
    await context.read<FcmService>().requestPermission();
    await _refreshNotificationStatus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeProvider = context.watch<LocaleProvider>();
    final appState = context.watch<AppState>();

    return CommandBackground(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 110), // clear of the floating nav bar
              children: [
                Text(l10n.settingsTitle, style: AppFonts.heading(fontSize: 26)),
                const SizedBox(height: 22),
                _Group(
                  label: l10n.settingsNotifications,
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: _NotificationTile(status: _notificationStatus, onEnable: _enableNotifications),
                  ),
                ),
                _Group(
                  label: l10n.settingsLanguage,
                  child: GlassCard(
                    padding: const EdgeInsets.all(12),
                    child: _LanguagePicker(provider: localeProvider, l10n: l10n),
                  ),
                ),
                _Group(
                  label: l10n.settingsSectionDemo,
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _RigModeCard(appState: appState),
                        const Divider(height: 24),
                        _SyntheticDemo(appState: appState),
                      ],
                    ),
                  ),
                ),
                _Group(
                  label: l10n.settingsSectionDiagnostics,
                  hint: l10n.settingsDiagnosticsHint,
                  child: Column(
                    children: [
                      _Collapsible(title: l10n.benchSensorTitle, icon: Icons.sensors, child: const _BenchSensorPanel()),
                      const SizedBox(height: 12),
                      _Collapsible(title: l10n.benchEvalTitle, icon: Icons.analytics_outlined, child: const _BenchEvalPanel()),
                    ],
                  ),
                ),
                _Group(
                  label: l10n.settingsAbout,
                  last: true,
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                              ),
                              child: const Icon(Icons.shield_outlined, color: AppColors.accent, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l10n.settingsAboutVersion, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                                  const SizedBox(height: 2),
                                  Text(l10n.settingsAboutTagline, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(l10n.settingsAboutCredits, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.4)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A titled block of the settings page; every group has the same label style and the same gap below it.
class _Group extends StatelessWidget {
  final String label;
  final String? hint;
  final Widget child;
  final bool last;
  const _Group({required this.label, required this.child, this.hint, this.last = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel(label),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(hint!, style: const TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.35)),
            ),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// A card that opens on tap, so the technical panels stay out of the way until someone wants them.
class _Collapsible extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _Collapsible({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          iconColor: AppColors.textSecondary,
          collapsedIconColor: AppColors.textSecondary,
          leading: Icon(icon, color: AppColors.textSecondary, size: 20),
          title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14.5)),
          children: [child],
        ),
      ),
    );
  }
}

/// System, English or Bahasa Malaysia, as one three-way switch instead of three radio rows.
class _LanguagePicker extends StatelessWidget {
  final LocaleProvider provider;
  final AppLocalizations l10n;
  const _LanguagePicker({required this.provider, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final current = provider.overrideLocale?.languageCode ?? 'auto';
    Widget label(String text) => FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1, softWrap: false));
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(value: 'auto', icon: const Icon(Icons.smartphone, size: 16), label: label(l10n.settingsLanguageAuto)),
          ButtonSegment(value: 'en', label: label(l10n.settingsLanguageEnglish)),
          ButtonSegment(value: 'ms', label: label(l10n.settingsLanguageMalay)),
        ],
        selected: {current},
        onSelectionChanged: (s) {
          final v = s.first;
          provider.setOverride(v == 'auto' ? null : Locale(v));
        },
        style: SegmentedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.textSecondary,
          selectedBackgroundColor: AppColors.accent.withValues(alpha: 0.18),
          selectedForegroundColor: AppColors.accent,
          side: const BorderSide(color: AppColors.hairline),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        ),
      ),
    );
  }
}

/// The older demonstration that needs no hardware: the app plays a made-up rising flood.
class _SyntheticDemo extends StatelessWidget {
  final AppState appState;
  const _SyntheticDemo({required this.appState});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final on = appState.demoMode && !appState.rigMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: Text(l10n.settingsDemoMode, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(l10n.settingsDemoModeDescription, style: const TextStyle(color: AppColors.textMuted, height: 1.35)),
          ),
          value: on,
          onChanged: (v) {
            context.read<RigController>().stop();
            appState.setDemoMode(v);
            final demo = context.read<DemoController>();
            if (v) {
              demo.start();
            } else {
              demo.stop();
            }
          },
          contentPadding: EdgeInsets.zero,
        ),
        if (on) ...[
          const SizedBox(height: 8),
          Text(l10n.settingsDemoTriggerLabel, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: RiskState.values.map((state) {
              final color = riskStateColor(state);
              final isLive = state == appState.myRiskState;
              final button = OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  backgroundColor: color.withValues(alpha: isLive ? 0.16 : 0.08),
                  side: isLive ? BorderSide.none : BorderSide(color: color.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                onPressed: () => context.read<DemoController>().jumpTo(state),
                child: Text(riskStateLabel(context, state).toUpperCase(), style: AppFonts.mono(fontSize: 12, color: color)),
              );
              if (!isLive) return button;
              return Container(
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.3)]),
                  boxShadow: appGlow(color, alpha: 0.4, blur: 12),
                ),
                child: button,
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}


class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

/// Live-polls Supabase's sensor_table (the ESP32/Pico bench rig, see
/// bench_sensor_service.dart) every few seconds while this screen is
/// visible, and shows the newest row. Deliberately its own small
/// StatefulWidget rather than routed through AppState -- this is bench
/// test data with no relation to the real node/guardrail pipeline, so it
/// shouldn't share state with anything that drives an actual risk
/// reading.
class _BenchSensorPanel extends StatefulWidget {
  const _BenchSensorPanel();

  @override
  State<_BenchSensorPanel> createState() => _BenchSensorPanelState();
}

class _BenchSensorPanelState extends State<_BenchSensorPanel> {
  final _service = BenchSensorService();
  Timer? _timer;
  BenchSensorReading? _latest;
  bool _loading = true;
  bool _errored = false;

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final rows = await _service.latest(limit: 1);
      if (!mounted) return;
      setState(() {
        _latest = rows.isNotEmpty ? rows.first : _latest;
        _loading = false;
        _errored = false;
      });
    } on BenchSensorException {
      if (!mounted) return;
      // Keep showing the last good reading rather than blanking the panel
      // on one dropped request (Section 2: degrade visibly, don't flicker
      // between data and nothing on every transient network hiccup).
      setState(() {
        _loading = false;
        _errored = _latest == null;
      });
    }
  }

  String _formatAgo(DateTime time) {
    final diff = DateTime.now().toUtc().difference(time.toUtc());
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.benchSensorDescription, style: const TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.4)),
          const SizedBox(height: 14),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
          else if (_latest == null)
            Text(
              _errored ? l10n.benchSensorError : l10n.benchSensorWaiting,
              style: const TextStyle(color: AppColors.textSecondary),
            )
          else ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _BenchStat(label: 'Soil', value: _latest!.soil?.toString() ?? '—'),
                _BenchStat(label: 'Distance', value: _latest!.dist != null ? '${_latest!.dist!.toStringAsFixed(1)} cm' : '—'),
                _BenchStat(label: 'Flow', value: _latest!.flow?.toString() ?? '—'),
                _BenchStat(
                  label: 'Accel (x,y,z)',
                  value: [_latest!.accelX, _latest!.accelY, _latest!.accelZ]
                      .map((v) => v?.toStringAsFixed(2) ?? '—')
                      .join(', '),
                ),
                _BenchStat(
                  label: 'Gyro (x,y,z)',
                  value: [_latest!.gyroX, _latest!.gyroY, _latest!.gyroZ]
                      .map((v) => v?.toStringAsFixed(2) ?? '—')
                      .join(', '),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${l10n.benchSensorUpdated} ${_formatAgo(_latest!.createdAt)}${_errored ? ' — ${l10n.benchSensorError}' : ''}',
              style: TextStyle(color: _errored ? AppColors.evacuate : AppColors.textMuted, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _BenchStat extends StatelessWidget {
  final String label;
  final String value;
  const _BenchStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
          const SizedBox(height: 3),
          Text(value, style: AppFonts.mono(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

/// Lets a resident run the bench rig's latest real reading through the
/// ACTUAL trained Tier 2 model (backend POST /bench/evaluate — see
/// bench_eval.py), filling in only the signals the rig genuinely can't
/// sense (rainfall) or hasn't been calibrated for (water level, soil).
/// Deliberately a manual "Run" button rather than live-updating on every
/// slider drag -- this hits a real model inference on the backend each
/// time, not a free client-side computation.
class _BenchEvalPanel extends StatefulWidget {
  const _BenchEvalPanel();

  @override
  State<_BenchEvalPanel> createState() => _BenchEvalPanelState();
}

class _BenchEvalPanelState extends State<_BenchEvalPanel> {
  double _rainMm = 0;
  bool _overrideHeight = false;
  double _heightM = 1.2;
  bool _overrideSoil = false;
  double _soilPct = 40;

  bool _running = false;
  BenchEvalResult? _result;
  bool _errored = false;

  Future<void> _run() async {
    final appState = context.read<AppState>();
    setState(() {
      _running = true;
      _errored = false;
    });
    try {
      final result = await appState.api.evaluateBench(
        rainMm1h: _rainMm,
        heightMOverride: _overrideHeight ? _heightM : null,
        soilPctOverride: _overrideSoil ? _soilPct : null,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _running = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _errored = true;
        _running = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.benchEvalDescription, style: const TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.4)),
          const SizedBox(height: 16),

          Text('${l10n.benchEvalRainLabel}: ${_rainMm.round()} mm', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          Slider(
            value: _rainMm,
            min: 0,
            max: 100,
            divisions: 20,
            activeColor: AppColors.accent,
            onChanged: (v) => setState(() => _rainMm = v),
          ),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(l10n.benchEvalHeightLabel, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            value: _overrideHeight,
            onChanged: (v) => setState(() => _overrideHeight = v),
          ),
          if (_overrideHeight) ...[
            Text('${_heightM.toStringAsFixed(1)} m', style: AppFonts.mono(fontSize: 13, color: AppColors.textPrimary)),
            Slider(
              value: _heightM,
              min: 0,
              max: 5,
              divisions: 50,
              activeColor: AppColors.watch,
              onChanged: (v) => setState(() => _heightM = v),
            ),
          ],

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(l10n.benchEvalSoilLabel, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            value: _overrideSoil,
            onChanged: (v) => setState(() => _overrideSoil = v),
          ),
          if (_overrideSoil) ...[
            Text('${_soilPct.round()}%', style: AppFonts.mono(fontSize: 13, color: AppColors.textPrimary)),
            Slider(
              value: _soilPct,
              min: 0,
              max: 100,
              divisions: 20,
              activeColor: AppColors.warning,
              onChanged: (v) => setState(() => _soilPct = v),
            ),
          ],

          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _running ? null : _run,
              child: Text(_running ? l10n.benchEvalRunning : l10n.benchEvalRunButton),
            ),
          ),

          if (_errored) ...[
            const SizedBox(height: 12),
            Text(l10n.benchEvalErrorMsg, style: const TextStyle(color: AppColors.evacuate, fontSize: 14)),
          ],

          if (_result != null) ...[
            const SizedBox(height: 16),
            const Divider(color: AppColors.hairline),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(l10n.benchEvalResultTitle.toUpperCase(), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                const Spacer(),
                RiskBadge(state: _result!.state),
              ],
            ),
            if (!_result!.isRealModel) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.watch.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.watch.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.watch, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(l10n.benchEvalStubWarning, style: const TextStyle(color: AppColors.watch, fontSize: 12.5, height: 1.35)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _BenchStat(label: l10n.benchEvalProbabilityLabel, value: '${(_result!.tier2Probability * 100).toStringAsFixed(1)}%'),
                _BenchStat(label: l10n.benchEvalCorroborationLabel, value: '${_result!.corroboratingChannels}'),
                _BenchStat(label: 'Physical breach', value: _result!.physicalBreach ? 'YES' : 'no'),
              ],
            ),
            const SizedBox(height: 10),
            Text(l10n.benchEvalReadingUsedLabel, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              _result!.readingUsed.entries.map((e) => '${e.key}=${e.value}').join('  ·  '),
              style: AppFonts.mono(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationPermissionStatus? status;
  final VoidCallback onEnable;

  const _NotificationTile({required this.status, required this.onEnable});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final loading = status == null;
    final enabled = status == NotificationPermissionStatus.authorized;

    String statusLabel;
    Color statusColor;
    switch (status) {
      case NotificationPermissionStatus.authorized:
        statusLabel = l10n.settingsNotificationsEnabled;
        statusColor = AppColors.normal;
      case NotificationPermissionStatus.denied:
        statusLabel = l10n.settingsNotificationsDisabled;
        statusColor = AppColors.evacuate;
      case NotificationPermissionStatus.notDetermined:
      case NotificationPermissionStatus.unavailable:
      case null:
        statusLabel = l10n.settingsNotificationsUnknown;
        statusColor = AppColors.textMuted;
    }

    // Matches Settings' Demo mode row: a draggable Switch, not a plain
    // "Enable" text link — mentor feedback was that the old link read as
    // a throwaway hint rather than a real control. There's no OS API to
    // revoke notification permission from inside the app, so dragging the
    // switch off is a no-op; it only ever drives the same onEnable()
    // permission request the old button did, and the switch's own value
    // stays tied to the actual OS-reported status either way.
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(
        enabled ? Icons.notifications_active : Icons.notifications_off_outlined,
        color: enabled ? AppColors.accent : AppColors.textMuted,
      ),
      title: Text(l10n.settingsNotificationsDescription, style: const TextStyle(color: AppColors.textPrimary)),
      subtitle: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600)),
      value: enabled,
      onChanged: loading ? null : (v) { if (v && !enabled) onEnable(); },
    );
  }
}



/// Live rig mode: switch the whole app over to the bench rig's real sensors, read by the phase model. While it is
/// on, the phase buttons below can force any of the four phases to rehearse an alert.
class _RigModeCard extends StatelessWidget {
  final AppState appState;
  const _RigModeCard({required this.appState});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rig = appState.rigReading;
    final state = rig == null ? null : RiskState.values[rig.phase - 1];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: Text(l10n.rigModeTitle, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(l10n.rigModeDescription, style: const TextStyle(color: AppColors.textMuted, height: 1.35)),
          ),
          value: appState.rigMode,
          onChanged: (v) {
            final rigController = context.read<RigController>();
            if (v) {
              context.read<DemoController>().stop();
              appState.setRigMode(true);
              rigController.start();
            } else {
              rigController.stop();
              appState.setRigMode(false);
            }
          },
          contentPadding: EdgeInsets.zero,
        ),
        if (appState.rigMode) ...[
          const SizedBox(height: 4),
          if (rig == null || state == null)
            Text(l10n.rigWaiting, style: const TextStyle(color: AppColors.textMuted))
          else
            _RigStatusLine(rig: rig, state: state),
          const SizedBox(height: 18),
          const _PhaseSimulator(),
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}

/// One line saying what the rig reads now: its phase, how sure the model is, and how fresh the reading is.
class _RigStatusLine extends StatelessWidget {
  final RigReading rig;
  final RiskState state;
  const _RigStatusLine({required this.rig, required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = rig.simulated
        ? AppColors.accent
        : rig.isStale
            ? const Color(0xFFE8833A)
            : AppColors.normal;
    final status = rig.simulated
        ? l10n.rigStatusSimulated
        : rig.isStale
            ? l10n.rigOffline
            : '${l10n.benchSensorUpdated} ${_ago(rig.age)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '${rig.isStale && !rig.simulated ? '${l10n.rigLastKnown} ' : ''}${l10n.rigPhaseLabel} ${rig.phase}  ',
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: riskStateLabel(context, state).toUpperCase(),
                  style: TextStyle(color: riskStateColor(state), fontWeight: FontWeight.w800),
                ),
              ]),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Text(status, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  static String _ago(Duration d) {
    if (d.inSeconds < 90) return '${d.inSeconds}s ago';
    if (d.inMinutes < 90) return '${d.inMinutes} min ago';
    if (d.inHours < 48) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }
}

/// Five buttons: Live (follow the rig) and phases 1 to 4. A forced phase drives the map, My Risk, the demo nodes
/// and the alert exactly as a real reading would, so a whole alert can be shown without waiting for the water.
class _PhaseSimulator extends StatelessWidget {
  const _PhaseSimulator();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rig = context.select<AppState, RigReading?>((s) => s.rigReading);
    final forced = rig != null && rig.simulated ? rig.phase : null;
    final controller = context.read<RigController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.simulatePhaseTitle, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14.5)),
        const SizedBox(height: 4),
        Text(l10n.simulatePhaseHint, style: const TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.35)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PhaseButton(
                top: const Icon(Icons.sensors, size: 20),
                label: l10n.simulateLive,
                color: AppColors.accent,
                selected: forced == null,
                onTap: () => controller.setOverride(null),
              ),
            ),
            for (final state in RiskState.values) ...[
              const SizedBox(width: 6),
              Expanded(
                child: _PhaseButton(
                  top: Text('${state.index + 1}', style: AppFonts.mono(fontSize: 18, fontWeight: FontWeight.w800, color: riskStateColor(state))),
                  label: riskStateLabel(context, state),
                  color: riskStateColor(state),
                  selected: forced == state.index + 1,
                  onTap: () => controller.setOverride(state.index + 1),
                ),
              ),
            ],
          ],
        ),
        if (forced != null) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.science_outlined, size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.simulatingNow('$forced'),
                  style: const TextStyle(color: AppColors.accent, fontSize: 14, fontWeight: FontWeight.w600, height: 1.35),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PhaseButton extends StatelessWidget {
  final Widget top;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _PhaseButton({required this.top, required this.label, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: selected ? 0.18 : 0.05),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: color.withValues(alpha: selected ? 0.9 : 0.3), width: selected ? 1.5 : 1),
            boxShadow: selected ? appGlow(color, alpha: 0.35, blur: 14) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconTheme(data: IconThemeData(color: color), child: top),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, maxLines: 1, style: TextStyle(color: selected ? color : AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
