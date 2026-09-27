import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
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

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        enabled ? Icons.notifications_active : Icons.notifications_off_outlined,
        color: enabled ? AppColors.accent : AppColors.textMuted,
      ),
      title: Text(l10n.settingsNotificationsDescription, style: const TextStyle(color: AppColors.textPrimary)),
      subtitle: loading
          ? null
          : Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600)),
      trailing: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : enabled
              ? null
              : TextButton(onPressed: onEnable, child: Text(l10n.settingsNotificationsEnable)),
    );
  }
}
