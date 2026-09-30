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
          padding: const EdgeInsets.all(20),
          children: [
            Text(l10n.settingsTitle, style: AppFonts.heading(fontSize: 26)),
            const SizedBox(height: 20),
            _SectionLabel(l10n.settingsNotifications),
            const SizedBox(height: 8),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: _NotificationTile(
                status: _notificationStatus,
                onEnable: _enableNotifications,
              ),
            ),
            const SizedBox(height: 24),
            _SectionLabel(l10n.settingsLanguage),
            const SizedBox(height: 8),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                children: [
                  RadioListTile<Locale?>(
                    title: Text(l10n.settingsLanguageSystem, style: const TextStyle(color: AppColors.textPrimary)),
                    value: null,
                    // ignore: deprecated_member_use
                    groupValue: localeProvider.overrideLocale,
                    // ignore: deprecated_member_use
                    onChanged: (v) => localeProvider.setOverride(v),
                  ),
                  RadioListTile<Locale?>(
                    title: Text(l10n.settingsLanguageEnglish, style: const TextStyle(color: AppColors.textPrimary)),
                    value: const Locale('en'),
                    // ignore: deprecated_member_use
                    groupValue: localeProvider.overrideLocale,
                    // ignore: deprecated_member_use
                    onChanged: (v) => localeProvider.setOverride(v),
                  ),
                  RadioListTile<Locale?>(
                    title: Text(l10n.settingsLanguageMalay, style: const TextStyle(color: AppColors.textPrimary)),
                    value: const Locale('ms'),
                    // ignore: deprecated_member_use
                    groupValue: localeProvider.overrideLocale,
                    // ignore: deprecated_member_use
                    onChanged: (v) => localeProvider.setOverride(v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SectionLabel(l10n.settingsDemoMode),
            const SizedBox(height: 8),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: Text(l10n.settingsDemoMode, style: const TextStyle(color: AppColors.textPrimary)),
                    subtitle: Text(
                      l10n.settingsDemoModeDescription,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                    value: appState.demoMode,
                    onChanged: (v) {
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
                  if (appState.demoMode) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.settingsDemoTriggerLabel,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
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
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SectionLabel(l10n.benchSensorTitle),
            const SizedBox(height: 8),
            GlassCard(child: const _BenchSensorPanel()),
            const SizedBox(height: 24),
            _SectionLabel(l10n.benchEvalTitle),
            const SizedBox(height: 8),
            GlassCard(child: const _BenchEvalPanel()),
            const SizedBox(height: 24),
            _SectionLabel(l10n.settingsAbout),
            const SizedBox(height: 8),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: const Icon(Icons.info_outline, color: AppColors.textSecondary),
                title: Text(l10n.settingsAboutVersion, style: const TextStyle(color: AppColors.textPrimary)),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.benchSensorDescription, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.4)),
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
              style: TextStyle(color: _errored ? AppColors.evacuate : AppColors.textMuted, fontSize: 11.5),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.benchEvalDescription, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.4)),
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
            Text(l10n.benchEvalErrorMsg, style: const TextStyle(color: AppColors.evacuate, fontSize: 12.5)),
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
                      child: Text(l10n.benchEvalStubWarning, style: const TextStyle(color: AppColors.watch, fontSize: 11.5, height: 1.35)),
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
            Text(l10n.benchEvalReadingUsedLabel, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              _result!.readingUsed.entries.map((e) => '${e.key}=${e.value}').join('  ·  '),
              style: AppFonts.mono(fontSize: 11.5, color: AppColors.textSecondary),
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
