import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/locale_provider.dart';
import '../demo/demo_controller.dart';
import '../l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
          Text(l10n.settingsLanguage, style: Theme.of(context).textTheme.titleSmall),
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
        ],
      ),
    );
  }
}
