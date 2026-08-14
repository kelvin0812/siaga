import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLanguageOverrideKey = 'siaga.language_override';

/// Section 6.4: BM/EN selected from device locale, with a manual override.
/// null means "follow device locale."
class LocaleProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  Locale? _override;

  LocaleProvider(this._prefs) {
    final saved = _prefs.getString(_kLanguageOverrideKey);
    if (saved != null) {
      _override = Locale(saved);
    }
  }

  Locale? get overrideLocale => _override;

  Future<void> setOverride(Locale? locale) async {
    _override = locale;
    if (locale == null) {
      await _prefs.remove(_kLanguageOverrideKey);
    } else {
      await _prefs.setString(_kLanguageOverrideKey, locale.languageCode);
    }
    notifyListeners();
  }
}
