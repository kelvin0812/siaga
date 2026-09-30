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
  String get nodeNoReadings => 'No readings yet';

  @override
  String get nodeGpsLabel => 'GPS location';

  @override
  String get demoReadoutTitle => 'Live sensor readout (demo)';

  @override
  String get demoWaterLevel => 'Water depth';

  @override
  String get demoWaterPressure => 'Water pressure';

  @override
  String get demoSoilMoisture => 'Soil moisture';

  @override
  String get demoSoilInertia => 'Soil inertia (IMU)';

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
  String get settingsDemoTriggerLabel => 'Jump to state';

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

  @override
  String get mapSearchHint => 'Search nodes or assembly points';

  @override
  String get mapSearchNoResults => 'No matches';

  @override
  String get mapLockNode => 'Lock as my area';

  @override
  String get mapUnlockNode => 'Unlock';

  @override
  String get mapLockedHint => 'My Risk will follow this node';

  @override
  String get riskSelectorLabel => 'Showing';

  @override
  String get riskSelectorAuto => 'Auto (nearest to me)';

  @override
  String get reportLocationLabel => 'Location';

  @override
  String get reportLocationCurrent => 'My current location';

  @override
  String get reportPhotoRemove => 'Remove photo';

  @override
  String get reportPhotoUploading => 'Uploading photo…';

  @override
  String get reportPhotoUploadFailed =>
      'Photo upload failed. Try again or remove the photo.';

  @override
  String get benchSensorTitle => 'Bench Sensor Rig (Live)';

  @override
  String get benchSensorDescription =>
      'Live readings from the ESP32/Pico test rig via Supabase — separate from the monitored river nodes above.';

  @override
  String get benchSensorWaiting => 'Waiting for a reading...';

  @override
  String get benchSensorError => 'Could not reach Supabase.';

  @override
  String get benchSensorUpdated => 'Updated';

  @override
  String get benchEvalTitle => 'Risk Model Evaluation (Bench Data)';

  @override
  String get benchEvalDescription =>
      'Runs the bench rig\'s real sensor readings through the actual trained model. Fill in what the rig can\'t sense, then run it — this is live inference against the real model, not a retrain.';

  @override
  String get benchEvalRainLabel => 'Simulated rainfall, last hour (mm)';

  @override
  String get benchEvalHeightLabel => 'Override water level';

  @override
  String get benchEvalSoilLabel => 'Override soil moisture';

  @override
  String get benchEvalRunButton => 'Run evaluation';

  @override
  String get benchEvalRunning => 'Running…';

  @override
  String get benchEvalErrorMsg =>
      'Could not run evaluation. Check your connection and try again.';

  @override
  String get benchEvalResultTitle => 'Result';

  @override
  String get benchEvalProbabilityLabel => 'Tier 2 probability';

  @override
  String get benchEvalCorroborationLabel => 'Corroborating channels';

  @override
  String get benchEvalReadingUsedLabel => 'Reading fed to the model';

  @override
  String get benchEvalStubWarning =>
      'This ran on the heuristic placeholder, not the real trained model — the backend\'s server couldn\'t load it this time. The number above is illustrative only.';
}
