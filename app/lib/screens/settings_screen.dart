import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/fcm_service.dart';
import '../core/locale_provider.dart';
import '../core/models.dart';
import '../demo/demo_controller.dart';
import '../l10n/app_localizations.dart';
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

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.settingsTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _SectionLabel(l10n.settingsNotifications),
          _NotificationTile(
            status: _notificationStatus,
            onEnable: _enableNotifications,
          ),
          const Divider(height: 32),
          _SectionLabel(l10n.settingsLanguage),
          RadioListTile<Locale?>(
            title: Text(l10n.settingsLanguageSystem),
            value: null,
            // ignore: deprecated_member_use
            groupValue: localeProvider.overrideLocale,
            // ignore: deprecated_member_use
            onChanged: (v) => localeProvider.setOverride(v),
            contentPadding: EdgeInsets.zero,
          ),
          RadioListTile<Locale?>(
            title: Text(l10n.settingsLanguageEnglish),
            value: const Locale('en'),
            // ignore: deprecated_member_use
            groupValue: localeProvider.overrideLocale,
            // ignore: deprecated_member_use
            onChanged: (v) => localeProvider.setOverride(v),
            contentPadding: EdgeInsets.zero,
          ),
          RadioListTile<Locale?>(
            title: Text(l10n.settingsLanguageMalay),
            value: const Locale('ms'),
            // ignore: deprecated_member_use
            groupValue: localeProvider.overrideLocale,
            // ignore: deprecated_member_use
            onChanged: (v) => localeProvider.setOverride(v),
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(height: 32),
          SwitchListTile(
            title: Text(l10n.settingsDemoMode),
            subtitle: Text(l10n.settingsDemoModeDescription),
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
            Text(l10n.settingsDemoTriggerLabel, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: RiskState.values.map((state) {
                return OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: riskStateColor(state),
                    side: BorderSide(color: riskStateColor(state)),
                  ),
                  onPressed: () => context.read<DemoController>().jumpTo(state),
                  child: Text(riskStateLabel(context, state)),
                );
              }).toList(),
            ),
          ],
          const Divider(height: 32),
          _SectionLabel(l10n.settingsAbout),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.settingsAboutVersion),
            contentPadding: EdgeInsets.zero,
          ),
        ],
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
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
        statusColor = Colors.green;
      case NotificationPermissionStatus.denied:
        statusLabel = l10n.settingsNotificationsDisabled;
        statusColor = Colors.red;
      case NotificationPermissionStatus.notDetermined:
      case NotificationPermissionStatus.unavailable:
      case null:
        statusLabel = l10n.settingsNotificationsUnknown;
        statusColor = Colors.grey;
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        enabled ? Icons.notifications_active : Icons.notifications_off_outlined,
        color: enabled ? const Color(0xFF1565C0) : Colors.grey,
      ),
      title: Text(l10n.settingsNotificationsDescription),
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
