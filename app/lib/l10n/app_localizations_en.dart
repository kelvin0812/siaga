// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'SIAGA';

  @override
  String get navMap => 'Map';

  @override
  String get navMyRisk => 'My Risk';

  @override
  String get navReport => 'Report';

  @override
  String get navSettings => 'Settings';

  @override
  String get riskNormal => 'Normal';

  @override
  String get riskWatch => 'Watch';

  @override
  String get riskWarning => 'Warning';

  @override
  String get riskEvacuate => 'Evacuate';

  @override
  String get myRiskTitle => 'Risk level for your area';

  @override
  String get myRiskNoCell => 'Waiting for location...';

  @override
  String get sourceAttribution =>
      'SIAGA advisory (decision support only) — confirm with NADMA / MetMalaysia / JPS.';

  @override
  String get nodeHistoryTitle => 'Water level history';

  @override
  String get nodeBattery => 'Battery';

  @override
  String get nodeLastSeen => 'Last seen';

  @override
  String get nodeStateLabel => 'State';

  @override
  String get offlineBanner => 'No connection — showing last known data';

  @override
  String get reportTitle => 'Report a hazard';

  @override
  String get reportCategoryFlooding => 'Flooding';

  @override
  String get reportCategoryLandslide => 'Landslide / slope movement';

  @override
  String get reportCategoryOther => 'Other';

  @override
  String get reportNoteLabel => 'Notes (optional)';

  @override
  String get reportAddPhoto => 'Add photo (optional)';

  @override
  String get reportSubmit => 'Submit report';

  @override
  String get reportSubmitted => 'Report submitted. Thank you.';

  @override
  String get reportFailed =>
      'Could not submit report. Try again when you have a connection.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'Follow device language';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageMalay => 'Bahasa Malaysia';

  @override
  String get settingsDemoMode => 'Demo mode';

  @override
  String get settingsDemoModeDescription =>
      'Drive the app from a simulated rising flood, for demonstration without live hardware.';

  @override
  String get evacuateHeadline => 'EVACUATE NOW';

  @override
  String get evacuateBody =>
      'Leave the area immediately and follow official guidance.';

  @override
  String get evacuateAcknowledge => 'I understand';

  @override
  String get evacuateViewRoute => 'View evacuation route';

  @override
  String get assemblyPointsTitle => 'Assembly points';

  @override
  String get permissionLocationRationale =>
      'SIAGA needs your location to determine which area to alert you about. Your exact location never leaves this device.';

  @override
  String get permissionNotificationRationale =>
      'SIAGA needs notification permission to deliver flood and landslide alerts.';

  @override
  String get myLocationTitle => 'My location';

  @override
  String get myLocationRiskLabel => 'Risk in your area';

  @override
  String get myLocationCellLabel => 'Area code';

  @override
  String get myLocationUpdatedLabel => 'Last updated';

  @override
  String get myLocationPrivacyNote =>
      'This is shown only to you — your exact location is never sent anywhere.';

  @override
  String get myLocationTapHint => 'Tap to see your area\'s status';

  @override
  String get reportCategoryLabel => 'Category';

  @override
  String get reportWhereLabel => 'Where did you notice this? (optional)';

  @override
  String get reportWherePrefix => 'Location';

  @override
  String get reportWhereHint => 'e.g. near the bridge, behind the market';

  @override
  String get reportSectionDetails => 'Details';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsNotificationsEnabled => 'Enabled';

  @override
  String get settingsNotificationsDisabled => 'Disabled';

  @override
  String get settingsNotificationsUnknown => 'Not requested yet';

  @override
  String get settingsNotificationsDescription =>
      'Flood and landslide alerts for your area.';

  @override
  String get settingsNotificationsEnable => 'Enable';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsAboutVersion => 'SIAGA v1.0.0';
}
