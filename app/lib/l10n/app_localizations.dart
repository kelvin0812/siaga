import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ms.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ms'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'SIAGA'**
  String get appTitle;

  /// No description provided for @navMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get navMap;

  /// No description provided for @navMyRisk.
  ///
  /// In en, this message translates to:
  /// **'My Risk'**
  String get navMyRisk;

  /// No description provided for @navReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get navReport;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @riskNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get riskNormal;

  /// No description provided for @riskWatch.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get riskWatch;

  /// No description provided for @riskWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get riskWarning;

  /// No description provided for @riskEvacuate.
  ///
  /// In en, this message translates to:
  /// **'Evacuate'**
  String get riskEvacuate;

  /// No description provided for @myRiskTitle.
  ///
  /// In en, this message translates to:
  /// **'Risk level for your area'**
  String get myRiskTitle;

  /// No description provided for @myRiskNoCell.
  ///
  /// In en, this message translates to:
  /// **'Waiting for location...'**
  String get myRiskNoCell;

  /// No description provided for @sourceAttribution.
  ///
  /// In en, this message translates to:
  /// **'SIAGA advisory (decision support only) — confirm with NADMA / MetMalaysia / JPS.'**
  String get sourceAttribution;

  /// No description provided for @nodeHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Water level history'**
  String get nodeHistoryTitle;

  /// No description provided for @nodeBattery.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get nodeBattery;

  /// No description provided for @nodeLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen'**
  String get nodeLastSeen;

  /// No description provided for @nodeStateLabel.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get nodeStateLabel;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'No connection — showing last known data'**
  String get offlineBanner;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report a hazard'**
  String get reportTitle;

  /// No description provided for @reportCategoryFlooding.
  ///
  /// In en, this message translates to:
  /// **'Flooding'**
  String get reportCategoryFlooding;

  /// No description provided for @reportCategoryLandslide.
  ///
  /// In en, this message translates to:
  /// **'Landslide / slope movement'**
  String get reportCategoryLandslide;

  /// No description provided for @reportCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reportCategoryOther;

  /// No description provided for @reportNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get reportNoteLabel;

  /// No description provided for @reportAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo (optional)'**
  String get reportAddPhoto;

  /// No description provided for @reportSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get reportSubmit;

  /// No description provided for @reportSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Report submitted. Thank you.'**
  String get reportSubmitted;

  /// No description provided for @reportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not submit report. Try again when you have a connection.'**
  String get reportFailed;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow device language'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageMalay.
  ///
  /// In en, this message translates to:
  /// **'Bahasa Malaysia'**
  String get settingsLanguageMalay;

  /// No description provided for @settingsDemoMode.
  ///
  /// In en, this message translates to:
  /// **'Demo mode'**
  String get settingsDemoMode;

  /// No description provided for @settingsDemoModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Drive the app from a simulated rising flood, for demonstration without live hardware.'**
  String get settingsDemoModeDescription;

  /// No description provided for @evacuateHeadline.
  ///
  /// In en, this message translates to:
  /// **'EVACUATE NOW'**
  String get evacuateHeadline;

  /// No description provided for @evacuateBody.
  ///
  /// In en, this message translates to:
  /// **'Leave the area immediately and follow official guidance.'**
  String get evacuateBody;

  /// No description provided for @evacuateAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'I understand'**
  String get evacuateAcknowledge;

  /// No description provided for @evacuateViewRoute.
  ///
  /// In en, this message translates to:
  /// **'View evacuation route'**
  String get evacuateViewRoute;

  /// No description provided for @assemblyPointsTitle.
  ///
  /// In en, this message translates to:
  /// **'Assembly points'**
  String get assemblyPointsTitle;

  /// No description provided for @permissionLocationRationale.
  ///
  /// In en, this message translates to:
  /// **'SIAGA needs your location to determine which area to alert you about. Your exact location never leaves this device.'**
  String get permissionLocationRationale;

  /// No description provided for @permissionNotificationRationale.
  ///
  /// In en, this message translates to:
  /// **'SIAGA needs notification permission to deliver flood and landslide alerts.'**
  String get permissionNotificationRationale;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ms'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ms':
      return AppLocalizationsMs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
