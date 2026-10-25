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

  /// No description provided for @nodeNoReadings.
  ///
  /// In en, this message translates to:
  /// **'No readings yet'**
  String get nodeNoReadings;

  /// No description provided for @nodeGpsLabel.
  ///
  /// In en, this message translates to:
  /// **'GPS location'**
  String get nodeGpsLabel;

  /// No description provided for @demoReadoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Live sensor readout (demo)'**
  String get demoReadoutTitle;

  /// No description provided for @demoWaterLevel.
  ///
  /// In en, this message translates to:
  /// **'Water depth'**
  String get demoWaterLevel;

  /// No description provided for @demoWaterPressure.
  ///
  /// In en, this message translates to:
  /// **'Water pressure'**
  String get demoWaterPressure;

  /// No description provided for @demoSoilMoisture.
  ///
  /// In en, this message translates to:
  /// **'Soil moisture'**
  String get demoSoilMoisture;

  /// No description provided for @demoSoilInertia.
  ///
  /// In en, this message translates to:
  /// **'Soil inertia (IMU)'**
  String get demoSoilInertia;

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

  /// No description provided for @settingsDemoTriggerLabel.
  ///
  /// In en, this message translates to:
  /// **'Jump to state'**
  String get settingsDemoTriggerLabel;

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

  /// No description provided for @myLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'My location'**
  String get myLocationTitle;

  /// No description provided for @myLocationRiskLabel.
  ///
  /// In en, this message translates to:
  /// **'Risk in your area'**
  String get myLocationRiskLabel;

  /// No description provided for @myLocationCellLabel.
  ///
  /// In en, this message translates to:
  /// **'Area code'**
  String get myLocationCellLabel;

  /// No description provided for @myLocationUpdatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Last updated'**
  String get myLocationUpdatedLabel;

  /// No description provided for @myLocationPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'This is shown only to you — your exact location is never sent anywhere.'**
  String get myLocationPrivacyNote;

  /// No description provided for @myLocationTapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to see your area\'s status'**
  String get myLocationTapHint;

  /// No description provided for @reportCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get reportCategoryLabel;

  /// No description provided for @reportWhereLabel.
  ///
  /// In en, this message translates to:
  /// **'Where did you notice this? (optional)'**
  String get reportWhereLabel;

  /// No description provided for @reportWherePrefix.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get reportWherePrefix;

  /// No description provided for @reportWhereHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. near the bridge, behind the market'**
  String get reportWhereHint;

  /// No description provided for @reportSectionDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get reportSectionDetails;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsNotificationsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get settingsNotificationsEnabled;

  /// No description provided for @settingsNotificationsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get settingsNotificationsDisabled;

  /// No description provided for @settingsNotificationsUnknown.
  ///
  /// In en, this message translates to:
  /// **'Not requested yet'**
  String get settingsNotificationsUnknown;

  /// No description provided for @settingsNotificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Flood and landslide alerts for your area.'**
  String get settingsNotificationsDescription;

  /// No description provided for @settingsNotificationsEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get settingsNotificationsEnable;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsAboutVersion.
  ///
  /// In en, this message translates to:
  /// **'SIAGA v1.0.0'**
  String get settingsAboutVersion;

  /// No description provided for @mapSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search nodes or assembly points'**
  String get mapSearchHint;

  /// No description provided for @mapSearchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get mapSearchNoResults;

  /// No description provided for @mapLockNode.
  ///
  /// In en, this message translates to:
  /// **'Lock as my area'**
  String get mapLockNode;

  /// No description provided for @mapUnlockNode.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get mapUnlockNode;

  /// No description provided for @mapLockedHint.
  ///
  /// In en, this message translates to:
  /// **'My Risk will follow this node'**
  String get mapLockedHint;

  /// No description provided for @riskSelectorLabel.
  ///
  /// In en, this message translates to:
  /// **'Showing'**
  String get riskSelectorLabel;

  /// No description provided for @riskSelectorAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto (nearest to me)'**
  String get riskSelectorAuto;

  /// No description provided for @reportLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get reportLocationLabel;

  /// No description provided for @reportLocationCurrent.
  ///
  /// In en, this message translates to:
  /// **'My current location'**
  String get reportLocationCurrent;

  /// No description provided for @reportPhotoRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get reportPhotoRemove;

  /// No description provided for @reportPhotoUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading photo…'**
  String get reportPhotoUploading;

  /// No description provided for @reportPhotoUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Photo upload failed. Try again or remove the photo.'**
  String get reportPhotoUploadFailed;

  /// No description provided for @benchSensorTitle.
  ///
  /// In en, this message translates to:
  /// **'Bench Sensor Rig (Live)'**
  String get benchSensorTitle;

  /// No description provided for @benchSensorDescription.
  ///
  /// In en, this message translates to:
  /// **'Live readings from the ESP32/Pico test rig via Supabase — separate from the monitored river nodes above.'**
  String get benchSensorDescription;

  /// No description provided for @benchSensorWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a reading...'**
  String get benchSensorWaiting;

  /// No description provided for @benchSensorError.
  ///
  /// In en, this message translates to:
  /// **'Could not reach Supabase.'**
  String get benchSensorError;

  /// No description provided for @benchSensorUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get benchSensorUpdated;

  /// No description provided for @benchEvalTitle.
  ///
  /// In en, this message translates to:
  /// **'Risk Model Evaluation (Bench Data)'**
  String get benchEvalTitle;

  /// No description provided for @benchEvalDescription.
  ///
  /// In en, this message translates to:
  /// **'Runs the bench rig\'s real sensor readings through the actual trained model. Fill in what the rig can\'t sense, then run it — this is live inference against the real model, not a retrain.'**
  String get benchEvalDescription;

  /// No description provided for @benchEvalRainLabel.
  ///
  /// In en, this message translates to:
  /// **'Simulated rainfall, last hour (mm)'**
  String get benchEvalRainLabel;

  /// No description provided for @benchEvalHeightLabel.
  ///
  /// In en, this message translates to:
  /// **'Override water level'**
  String get benchEvalHeightLabel;

  /// No description provided for @benchEvalSoilLabel.
  ///
  /// In en, this message translates to:
  /// **'Override soil moisture'**
  String get benchEvalSoilLabel;

  /// No description provided for @benchEvalRunButton.
  ///
  /// In en, this message translates to:
  /// **'Run evaluation'**
  String get benchEvalRunButton;

  /// No description provided for @benchEvalRunning.
  ///
  /// In en, this message translates to:
  /// **'Running…'**
  String get benchEvalRunning;

  /// No description provided for @benchEvalErrorMsg.
  ///
  /// In en, this message translates to:
  /// **'Could not run evaluation. Check your connection and try again.'**
  String get benchEvalErrorMsg;

  /// No description provided for @benchEvalResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get benchEvalResultTitle;

  /// No description provided for @benchEvalProbabilityLabel.
  ///
  /// In en, this message translates to:
  /// **'Tier 2 probability'**
  String get benchEvalProbabilityLabel;

  /// No description provided for @benchEvalCorroborationLabel.
  ///
  /// In en, this message translates to:
  /// **'Corroborating channels'**
  String get benchEvalCorroborationLabel;

  /// No description provided for @benchEvalReadingUsedLabel.
  ///
  /// In en, this message translates to:
  /// **'Reading fed to the model'**
  String get benchEvalReadingUsedLabel;

  /// No description provided for @benchEvalStubWarning.
  ///
  /// In en, this message translates to:
  /// **'This ran on the heuristic placeholder, not the real trained model — the backend\'s server couldn\'t load it this time. The number above is illustrative only.'**
  String get benchEvalStubWarning;

  /// No description provided for @rigModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Live Rig (Phase Model)'**
  String get rigModeTitle;

  /// No description provided for @rigModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Runs the whole app from the bench rig\'s real sensors. The phase model reads the water level, flow, soil and tilt, and shows Normal, Watch, Warning or Evacuate.'**
  String get rigModeDescription;

  /// No description provided for @rigWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the rig\'s readings...'**
  String get rigWaiting;

  /// No description provided for @rigOffline.
  ///
  /// In en, this message translates to:
  /// **'No recent data from the rig'**
  String get rigOffline;

  /// No description provided for @rigPhaseLabel.
  ///
  /// In en, this message translates to:
  /// **'Phase'**
  String get rigPhaseLabel;

  /// No description provided for @rigReadoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Live rig readings'**
  String get rigReadoutTitle;

  /// No description provided for @rigMetricLevel.
  ///
  /// In en, this message translates to:
  /// **'Water level'**
  String get rigMetricLevel;

  /// No description provided for @rigMetricLevelCaption.
  ///
  /// In en, this message translates to:
  /// **'Above normal river level'**
  String get rigMetricLevelCaption;

  /// No description provided for @rigMetricFlow.
  ///
  /// In en, this message translates to:
  /// **'Water flow'**
  String get rigMetricFlow;

  /// No description provided for @rigMetricFlowCaption.
  ///
  /// In en, this message translates to:
  /// **'Sensor pulses every 3 s'**
  String get rigMetricFlowCaption;

  /// No description provided for @rigUnitPulses.
  ///
  /// In en, this message translates to:
  /// **'pulses'**
  String get rigUnitPulses;

  /// No description provided for @rigMetricSoil.
  ///
  /// In en, this message translates to:
  /// **'Soil moisture'**
  String get rigMetricSoil;

  /// No description provided for @rigMetricSoilCaption.
  ///
  /// In en, this message translates to:
  /// **'Soil sensor signal'**
  String get rigMetricSoilCaption;

  /// No description provided for @rigMetricTilt.
  ///
  /// In en, this message translates to:
  /// **'Slope tilt'**
  String get rigMetricTilt;

  /// No description provided for @rigMetricTiltCaption.
  ///
  /// In en, this message translates to:
  /// **'Shift from resting position'**
  String get rigMetricTiltCaption;

  /// No description provided for @rigLastKnown.
  ///
  /// In en, this message translates to:
  /// **'Last known'**
  String get rigLastKnown;

  /// No description provided for @rigStatusLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get rigStatusLive;

  /// No description provided for @rigStatusOffline.
  ///
  /// In en, this message translates to:
  /// **'Rig offline'**
  String get rigStatusOffline;

  /// No description provided for @rigLastData.
  ///
  /// In en, this message translates to:
  /// **'last data'**
  String get rigLastData;

  /// No description provided for @riskScoreLabel.
  ///
  /// In en, this message translates to:
  /// **'Risk score'**
  String get riskScoreLabel;

  /// No description provided for @riskSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'What this means'**
  String get riskSummaryTitle;

  /// No description provided for @riskSummaryNormal.
  ///
  /// In en, this message translates to:
  /// **'The water is at a normal level. No action is needed.'**
  String get riskSummaryNormal;

  /// No description provided for @riskSummaryWatch.
  ///
  /// In en, this message translates to:
  /// **'Conditions are changing. Stay alert and keep checking this screen.'**
  String get riskSummaryWatch;

  /// No description provided for @riskSummaryWarning.
  ///
  /// In en, this message translates to:
  /// **'Danger is building. Get ready to move to higher ground.'**
  String get riskSummaryWarning;

  /// No description provided for @riskSummaryEvacuate.
  ///
  /// In en, this message translates to:
  /// **'Dangerous conditions. Move to higher ground now.'**
  String get riskSummaryEvacuate;

  /// No description provided for @riskSummaryOffline.
  ///
  /// In en, this message translates to:
  /// **'The rig is not sending data, so there is no live assessment right now.'**
  String get riskSummaryOffline;

  /// No description provided for @riskTrendsTitle.
  ///
  /// In en, this message translates to:
  /// **'Trends'**
  String get riskTrendsTitle;

  /// No description provided for @riskTrendsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The last 10 minutes from the rig, updated live'**
  String get riskTrendsSubtitle;

  /// No description provided for @trendRisk.
  ///
  /// In en, this message translates to:
  /// **'Risk level'**
  String get trendRisk;

  /// No description provided for @trendRiskHelp.
  ///
  /// In en, this message translates to:
  /// **'The model\'s decision over time. Higher means more danger.'**
  String get trendRiskHelp;

  /// No description provided for @trendLevelHelp.
  ///
  /// In en, this message translates to:
  /// **'Rising water is the strongest warning sign.'**
  String get trendLevelHelp;

  /// No description provided for @trendFlowHelp.
  ///
  /// In en, this message translates to:
  /// **'A sudden surge means water is moving fast.'**
  String get trendFlowHelp;

  /// No description provided for @trendSoilHelp.
  ///
  /// In en, this message translates to:
  /// **'Shows how much water the ground has taken in.'**
  String get trendSoilHelp;

  /// No description provided for @trendTiltHelp.
  ///
  /// In en, this message translates to:
  /// **'Movement here can mean the slope is shifting.'**
  String get trendTiltHelp;

  /// No description provided for @trendNoData.
  ///
  /// In en, this message translates to:
  /// **'Waiting for readings to draw this chart'**
  String get trendNoData;

  /// No description provided for @trendNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get trendNow;

  /// No description provided for @howTitle.
  ///
  /// In en, this message translates to:
  /// **'How SIAGA decides'**
  String get howTitle;

  /// No description provided for @howStep1.
  ///
  /// In en, this message translates to:
  /// **'Sensors on the rig measure water level, flow, soil moisture and tilt every 3 seconds.'**
  String get howStep1;

  /// No description provided for @howStep2.
  ///
  /// In en, this message translates to:
  /// **'A machine-learning model, trained on this rig\'s own recorded runs, reads those four signals. Water level counts the most.'**
  String get howStep2;

  /// No description provided for @howStep3.
  ///
  /// In en, this message translates to:
  /// **'It picks one of four levels: Normal, Watch, Warning or Evacuate. The siren on the rig runs the same model, so it and this app follow the same readings.'**
  String get howStep3;

  /// No description provided for @mapLegendNode.
  ///
  /// In en, this message translates to:
  /// **'Sensor node'**
  String get mapLegendNode;

  /// No description provided for @mapLegendAssembly.
  ///
  /// In en, this message translates to:
  /// **'Assembly point'**
  String get mapLegendAssembly;

  /// No description provided for @mapLegendYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get mapLegendYou;

  /// No description provided for @routeShortest.
  ///
  /// In en, this message translates to:
  /// **'Shortest route'**
  String get routeShortest;

  /// No description provided for @routeByRoad.
  ///
  /// In en, this message translates to:
  /// **'by road'**
  String get routeByRoad;

  /// No description provided for @routeStraight.
  ///
  /// In en, this message translates to:
  /// **'Straight line, offline'**
  String get routeStraight;

  /// No description provided for @routeSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved route'**
  String get routeSaved;

  /// No description provided for @routeWalk.
  ///
  /// In en, this message translates to:
  /// **'on foot'**
  String get routeWalk;

  /// No description provided for @routeCalculating.
  ///
  /// In en, this message translates to:
  /// **'Finding the shortest route...'**
  String get routeCalculating;

  /// No description provided for @routeAreaNote.
  ///
  /// In en, this message translates to:
  /// **'The route starts from your area. Your exact position is never sent.'**
  String get routeAreaNote;

  /// No description provided for @routeHere.
  ///
  /// In en, this message translates to:
  /// **'Show route to this point'**
  String get routeHere;

  /// No description provided for @routeNearest.
  ///
  /// In en, this message translates to:
  /// **'Back to the shortest route'**
  String get routeNearest;

  /// No description provided for @nodeKindSensor.
  ///
  /// In en, this message translates to:
  /// **'Sensor node'**
  String get nodeKindSensor;

  /// No description provided for @nodeKindAssembly.
  ///
  /// In en, this message translates to:
  /// **'Assembly point'**
  String get nodeKindAssembly;

  /// No description provided for @mapAway.
  ///
  /// In en, this message translates to:
  /// **'away in a straight line'**
  String get mapAway;

  /// No description provided for @placeDetails.
  ///
  /// In en, this message translates to:
  /// **'Details and trends'**
  String get placeDetails;

  /// No description provided for @nodeKindDemo.
  ///
  /// In en, this message translates to:
  /// **'Demo node'**
  String get nodeKindDemo;

  /// No description provided for @nodeSimulatedNote.
  ///
  /// In en, this message translates to:
  /// **'Simulated for the demonstration. Its level follows the live rig, so you can watch an alert spread across the area.'**
  String get nodeSimulatedNote;

  /// No description provided for @mapLegendDemo.
  ///
  /// In en, this message translates to:
  /// **'Demo node (simulated)'**
  String get mapLegendDemo;
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
