import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/bench_sensor_service.dart';
import '../core/fcm_service.dart';
import '../core/install_service.dart';
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
  /// Only for tests: a stand-in for the browser's install support.
  final InstallService? installService;

  /// Only for tests: a stand-in for the rig's online table.
  final BenchSensorService? benchService;
  const SettingsScreen({super.key, this.installService, this.benchService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  NotificationPermissionStatus? _notificationStatus;
  late final InstallService _install = widget.installService ?? createInstallService();

  @override
  void initState() {
    super.initState();
    _refreshNotificationStatus();
  }

  @override
  void dispose() {
    if (widget.installService == null) _install.dispose();
    super.dispose();
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
                if (_install.supported)
                  _Group(
                    label: l10n.installTitle,
                    child: GlassCard(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: _InstallCard(service: _install),
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
                      _Collapsible(title: l10n.benchSensorTitle, icon: Icons.sensors, child: _BenchSensorPanel(service: widget.benchService)),
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
/// Put SIAGA on the home screen: one button. Where the browser can show its own install dialog, that is what opens;
/// otherwise (iPhone Safari, an in-app browser) the same button shows the steps.
class _InstallCard extends StatelessWidget {
  final InstallService service;
  const _InstallCard({required this.service});

  void _showSteps(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final steps = service.isIos ? [l10n.installIos1, l10n.installIos2, l10n.installIos3] : [l10n.installOther1, l10n.installOther2, l10n.installOther3];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.installHowTitle, style: AppFonts.heading(fontSize: 20)),
              const SizedBox(height: 16),
              for (var i = 0; i < steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accent.withValues(alpha: 0.2), border: Border.all(color: AppColors.accent.withValues(alpha: 0.6))),
                        child: Text('${i + 1}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Padding(padding: const EdgeInsets.only(top: 2), child: Text(steps[i], style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.4)))),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.of(sheet).pop(), child: Text(l10n.installGotIt))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        if (service.installed) {
          return Row(
            children: [
              const Icon(Icons.check_circle_outline, color: AppColors.normal, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(l10n.installDone, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15))),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.installBody, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14.5, height: 1.45)),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => service.canPrompt ? service.prompt() : _showSteps(context),
              icon: const Icon(Icons.install_mobile, size: 20),
              label: Text(l10n.installButton),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }
}

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
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
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
  final BenchSensorService? service;
  const _BenchSensorPanel({this.service});

  @override
  State<_BenchSensorPanel> createState() => _BenchSensorPanelState();
}

class _BenchSensorPanelState extends State<_BenchSensorPanel> {
  late final BenchSensorService _service = widget.service ?? BenchSensorService();
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
    final r = _latest;
    final live = r != null && DateTime.now().toUtc().difference(r.createdAt.toUtc()) < const Duration(seconds: 30);
    final statusColor = r == null ? AppColors.textMuted : (live ? AppColors.normal : const Color(0xFFE8833A));
    String fmt(double? v, [int digits = 2]) => v?.toStringAsFixed(digits) ?? '\u2014';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.benchSensorDescription, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.45)),
          const SizedBox(height: 14),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
          else if (r == null)
            Text(
              _errored ? l10n.benchSensorError : l10n.benchSensorWaiting,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            )
          else ...[
            Row(
              children: [
                Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    live ? l10n.benchStatusLive : l10n.benchStatusAgo(_formatAgo(r.createdAt)),
                    style: TextStyle(color: statusColor, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (_errored) ...[
              const SizedBox(height: 4),
              Text(l10n.benchSensorError, style: const TextStyle(color: AppColors.evacuate, fontSize: 13)),
            ],
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _BenchTile(icon: Icons.grass, label: l10n.benchTileSoil, value: r.soil?.toString() ?? '\u2014')),
                const SizedBox(width: 10),
                Expanded(child: _BenchTile(icon: Icons.straighten, label: l10n.benchTileDistance, value: fmt(r.dist, 1), unit: 'cm')),
                const SizedBox(width: 10),
                Expanded(child: _BenchTile(icon: Icons.water_drop_outlined, label: l10n.benchTileFlow, value: r.flow?.toString() ?? '\u2014', unit: l10n.rigUnitPulses)),
              ],
            ),
            const SizedBox(height: 10),
            _BenchAxes(icon: Icons.open_with, label: l10n.benchTileAccel, unit: 'm/s\u00b2', x: fmt(r.accelX), y: fmt(r.accelY), z: fmt(r.accelZ)),
            const SizedBox(height: 10),
            _BenchAxes(icon: Icons.rotate_right, label: l10n.benchTileGyro, unit: 'rad/s', x: fmt(r.gyroX), y: fmt(r.gyroY), z: fmt(r.gyroZ)),
          ],
        ],
      ),
    );
  }
}

/// One reading: what it is, the number, and its unit.
class _BenchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  const _BenchTile({required this.icon, required this.label, required this.value, this.unit = ''});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: _tileDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(height: 8),
          Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.25, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AppFonts.mono(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          ),
          Text(unit.isEmpty ? '\u00a0' : unit, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
        ],
      ),
    );
  }
}

/// A reading with three axes (acceleration, rotation), side by side.
class _BenchAxes extends StatelessWidget {
  final IconData icon;
  final String label;
  final String unit;
  final String x, y, z;
  const _BenchAxes({required this.icon, required this.label, required this.unit, required this.x, required this.y, required this.z});

  @override
  Widget build(BuildContext context) {
    Widget axis(String name, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: AppFonts.mono(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              ),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: _tileDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600))),
              Text(unit, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [axis('x', x), axis('y', y), axis('z', z)]),
        ],
      ),
    );
  }
}

final _tileDecoration = BoxDecoration(
  color: AppColors.surfaceRaised,
  borderRadius: BorderRadius.circular(AppRadius.md),
  border: Border.all(color: AppColors.hairline),
);

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
