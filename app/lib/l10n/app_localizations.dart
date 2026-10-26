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
  /// **'Simulated for the demonstration. Its level follows the live rig.'**
  String get nodeSimulatedNote;

  /// No description provided for @mapLegendDemo.
  ///
  /// In en, this message translates to:
  /// **'Demo node (simulated)'**
  String get mapLegendDemo;

  /// No description provided for @riskViewing.
  ///
  /// In en, this message translates to:
  /// **'Data from'**
  String get riskViewing;

  /// No description provided for @nodePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a node'**
  String get nodePickerTitle;

  /// No description provided for @nodePickerSearch.
  ///
  /// In en, this message translates to:
  /// **'Search by name'**
  String get nodePickerSearch;

  /// No description provided for @nodeGroupSensor.
  ///
  /// In en, this message translates to:
  /// **'Sensor nodes'**
  String get nodeGroupSensor;

  /// No description provided for @nodeGroupDemo.
  ///
  /// In en, this message translates to:
  /// **'Demo nodes (simulated)'**
  String get nodeGroupDemo;

  /// No description provided for @nodeAutoPick.
  ///
  /// In en, this message translates to:
  /// **'Nearest to me (automatic)'**
  String get nodeAutoPick;

  /// No description provided for @nodeNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No node matches that name.'**
  String get nodeNoMatch;

  /// No description provided for @simNoSensors.
  ///
  /// In en, this message translates to:
  /// **'This is a demo node, so it has no sensors. Its level follows the live rig.'**
  String get simNoSensors;

  /// No description provided for @simShowRig.
  ///
  /// In en, this message translates to:
  /// **'Show the live rig'**
  String get simShowRig;

  /// No description provided for @statusNormalT.
  ///
  /// In en, this message translates to:
  /// **'All clear for now'**
  String get statusNormalT;

  /// No description provided for @statusNormalD.
  ///
  /// In en, this message translates to:
  /// **'The water is at its usual level.'**
  String get statusNormalD;

  /// No description provided for @statusWatchT.
  ///
  /// In en, this message translates to:
  /// **'Keep an eye on it'**
  String get statusWatchT;

  /// No description provided for @statusWatchD.
  ///
  /// In en, this message translates to:
  /// **'Readings are starting to change. Check back soon.'**
  String get statusWatchD;

  /// No description provided for @statusWarningT.
  ///
  /// In en, this message translates to:
  /// **'Get ready to move'**
  String get statusWarningT;

  /// No description provided for @statusWarningD.
  ///
  /// In en, this message translates to:
  /// **'Water is rising towards a dangerous level. Know your way to higher ground.'**
  String get statusWarningD;

  /// No description provided for @statusEvacT.
  ///
  /// In en, this message translates to:
  /// **'Move to higher ground now'**
  String get statusEvacT;

  /// No description provided for @statusEvacD.
  ///
  /// In en, this message translates to:
  /// **'Conditions are dangerous. Follow the route to the nearest assembly point.'**
  String get statusEvacD;

  /// No description provided for @statusOfflineT.
  ///
  /// In en, this message translates to:
  /// **'No live readings'**
  String get statusOfflineT;

  /// No description provided for @statusWaitingT.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the rig'**
  String get statusWaitingT;

  /// No description provided for @statusWaitingD.
  ///
  /// In en, this message translates to:
  /// **'Nothing has arrived yet. Check that the rig is switched on and online.'**
  String get statusWaitingD;

  /// No description provided for @statusDemoT.
  ///
  /// In en, this message translates to:
  /// **'Demo node'**
  String get statusDemoT;

  /// No description provided for @openMapBtn.
  ///
  /// In en, this message translates to:
  /// **'Open the map'**
  String get openMapBtn;

  /// No description provided for @howTitle2.
  ///
  /// In en, this message translates to:
  /// **'How is this decided?'**
  String get howTitle2;

  /// No description provided for @howBody.
  ///
  /// In en, this message translates to:
  /// **'Four sensors on the rig feed a model trained on this rig\'s own test runs, and the water level counts the most. The siren on the rig runs the same model, so it shows the same level as this screen.'**
  String get howBody;

  /// No description provided for @viewInRisk.
  ///
  /// In en, this message translates to:
  /// **'Show in My Risk'**
  String get viewInRisk;

  /// No description provided for @statusOfflineD.
  ///
  /// In en, this message translates to:
  /// **'The last reading from the rig was {ago}. SIAGA cannot say how things look right now.'**
  String statusOfflineD(String ago);

  /// No description provided for @simRigOffline.
  ///
  /// In en, this message translates to:
  /// **'The live rig is offline, so demo nodes rest at Normal.'**
  String get simRigOffline;

  /// No description provided for @popToggle.
  ///
  /// In en, this message translates to:
  /// **'Population'**
  String get popToggle;

  /// No description provided for @popLegendTitle.
  ///
  /// In en, this message translates to:
  /// **'People per km²'**
  String get popLegendTitle;

  /// No description provided for @popHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get popHigh;

  /// No description provided for @popMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get popMedium;

  /// No description provided for @popLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get popLow;

  /// No description provided for @popSource.
  ///
  /// In en, this message translates to:
  /// **'Population estimate: Kontur, CC BY 4.0'**
  String get popSource;

  /// No description provided for @popDensityHigh.
  ///
  /// In en, this message translates to:
  /// **'High density'**
  String get popDensityHigh;

  /// No description provided for @popDensityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium density'**
  String get popDensityMedium;

  /// No description provided for @popDensityLow.
  ///
  /// In en, this message translates to:
  /// **'Low density'**
  String get popDensityLow;

  /// No description provided for @popDensitySparse.
  ///
  /// In en, this message translates to:
  /// **'Sparsely populated'**
  String get popDensitySparse;

  /// No description provided for @popAround.
  ///
  /// In en, this message translates to:
  /// **'About {count} people within {km} km'**
  String popAround(String count, String km);

  /// No description provided for @settingsSectionDemo.
  ///
  /// In en, this message translates to:
  /// **'Demonstration'**
  String get settingsSectionDemo;

  /// No description provided for @settingsSectionDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get settingsSectionDiagnostics;

  /// No description provided for @settingsDiagnosticsHint.
  ///
  /// In en, this message translates to:
  /// **'For the team: the rig\'s raw readings and a check of the model.'**
  String get settingsDiagnosticsHint;

  /// No description provided for @simulatePhaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Simulate a phase'**
  String get simulatePhaseTitle;

  /// No description provided for @simulatePhaseHint.
  ///
  /// In en, this message translates to:
  /// **'Force the whole app to one phase to rehearse an alert. The map, My Risk and the alert all follow it.'**
  String get simulatePhaseHint;

  /// No description provided for @simulateLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get simulateLive;

  /// No description provided for @simulatingNow.
  ///
  /// In en, this message translates to:
  /// **'Simulating phase {phase}. Real rig readings are paused.'**
  String simulatingNow(String phase);

  /// No description provided for @rigStatusSimulated.
  ///
  /// In en, this message translates to:
  /// **'Simulated'**
  String get rigStatusSimulated;

  /// No description provided for @settingsLanguageAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get settingsLanguageAuto;

  /// No description provided for @settingsAboutTagline.
  ///
  /// In en, this message translates to:
  /// **'Early warning for flash floods and landslides.'**
  String get settingsAboutTagline;

  /// No description provided for @settingsAboutCredits.
  ///
  /// In en, this message translates to:
  /// **'Map data © OpenStreetMap contributors. Imagery © Esri. Population: Kontur (CC BY 4.0).'**
  String get settingsAboutCredits;

  /// No description provided for @reportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See something near a river, drain or slope? Tell the authorities in a few taps.'**
  String get reportSubtitle;

  /// No description provided for @reportStepWhat.
  ///
  /// In en, this message translates to:
  /// **'What did you see?'**
  String get reportStepWhat;

  /// No description provided for @reportStepWhere.
  ///
  /// In en, this message translates to:
  /// **'Where is it?'**
  String get reportStepWhere;

  /// No description provided for @reportStepDetails.
  ///
  /// In en, this message translates to:
  /// **'Anything to add?'**
  String get reportStepDetails;

  /// No description provided for @reportPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Only the area code of this place is sent, never your exact position.'**
  String get reportPrivacy;

  /// No description provided for @reportNotePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. water over the road near the bridge'**
  String get reportNotePlaceholder;

  /// No description provided for @reportCategoryLandslideShort.
  ///
  /// In en, this message translates to:
  /// **'Landslide'**
  String get reportCategoryLandslideShort;

  /// No description provided for @merangName.
  ///
  /// In en, this message translates to:
  /// **'Merang'**
  String get merangName;

  /// No description provided for @merangTagline.
  ///
  /// In en, this message translates to:
  /// **'Your river buddy. I explain what the app shows.'**
  String get merangTagline;

  /// No description provided for @merangAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask Merang'**
  String get merangAsk;

  /// No description provided for @merangAskHint.
  ///
  /// In en, this message translates to:
  /// **'Why this level? What should I do?'**
  String get merangAskHint;

  /// No description provided for @merangHi.
  ///
  /// In en, this message translates to:
  /// **'Hi, I am Merang!'**
  String get merangHi;

  /// No description provided for @merangDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'I only explain what the app already shows. I do not decide or send alerts. Check NADMA, MetMalaysia and JPS for official warnings.'**
  String get merangDisclaimer;

  /// No description provided for @merangQWhy.
  ///
  /// In en, this message translates to:
  /// **'Why is it {phase}?'**
  String merangQWhy(String phase);

  /// No description provided for @merangQNext.
  ///
  /// In en, this message translates to:
  /// **'What should I do?'**
  String get merangQNext;

  /// No description provided for @merangQData.
  ///
  /// In en, this message translates to:
  /// **'Where does this data come from?'**
  String get merangQData;

  /// No description provided for @merangQHow.
  ///
  /// In en, this message translates to:
  /// **'How do you work?'**
  String get merangQHow;

  /// No description provided for @merangWhyLevel.
  ///
  /// In en, this message translates to:
  /// **'The water is {height} cm above its normal level.'**
  String merangWhyLevel(String height);

  /// No description provided for @merangWhyLevelNormal.
  ///
  /// In en, this message translates to:
  /// **'The water is at its normal level.'**
  String get merangWhyLevelNormal;

  /// No description provided for @merangRiseFast.
  ///
  /// In en, this message translates to:
  /// **'It is rising, about {rate} cm every minute.'**
  String merangRiseFast(String rate);

  /// No description provided for @merangRiseSlow.
  ///
  /// In en, this message translates to:
  /// **'It is rising slowly.'**
  String get merangRiseSlow;

  /// No description provided for @merangRiseSteady.
  ///
  /// In en, this message translates to:
  /// **'It is steady right now.'**
  String get merangRiseSteady;

  /// No description provided for @merangFalling.
  ///
  /// In en, this message translates to:
  /// **'It is going down, about {rate} cm every minute.'**
  String merangFalling(String rate);

  /// No description provided for @merangWhyBands.
  ///
  /// In en, this message translates to:
  /// **'On our bench rig, Watch starts near 0.8 cm, Warning near 2.2 cm and Evacuate near 3.6 cm above normal.'**
  String get merangWhyBands;

  /// No description provided for @merangWhyOthers.
  ///
  /// In en, this message translates to:
  /// **'Flow, soil and tilt count too, but the water level matters most.'**
  String get merangWhyOthers;

  /// No description provided for @merangWhyNoRig.
  ///
  /// In en, this message translates to:
  /// **'{node} is at {phase}. I only have its summary here, not the raw sensor readings.'**
  String merangWhyNoRig(String node, String phase);

  /// No description provided for @merangWhyStale.
  ///
  /// In en, this message translates to:
  /// **'The rig has not sent anything for {ago}, so there is no fresh reading. The app shows Normal rather than raising an alert from old data.'**
  String merangWhyStale(String ago);

  /// No description provided for @merangWhySimulated.
  ///
  /// In en, this message translates to:
  /// **'This level was set by hand in Settings for a demonstration. The numbers are typical values for that level, not live readings.'**
  String get merangWhySimulated;

  /// No description provided for @merangWhyDemoNode.
  ///
  /// In en, this message translates to:
  /// **'This is a demo node. Its level follows the live rig.'**
  String get merangWhyDemoNode;

  /// No description provided for @merangNextNormal.
  ///
  /// In en, this message translates to:
  /// **'Nothing to do right now. Keep notifications on, and check again if heavy rain starts.'**
  String get merangNextNormal;

  /// No description provided for @merangNextWatch.
  ///
  /// In en, this message translates to:
  /// **'Stay alert. Keep an eye on the app and the weather, and get your important things together.'**
  String get merangNextWatch;

  /// No description provided for @merangNextWarning.
  ///
  /// In en, this message translates to:
  /// **'Get ready to move. Know your route, charge your phone, and open the map to find the nearest assembly point.'**
  String get merangNextWarning;

  /// No description provided for @merangNextEvacuate.
  ///
  /// In en, this message translates to:
  /// **'Leave now. Follow the route to the nearest assembly point and listen to official instructions.'**
  String get merangNextEvacuate;

  /// No description provided for @merangNextStale.
  ///
  /// In en, this message translates to:
  /// **'The data is old, so do not rely on it. Check the official channels.'**
  String get merangNextStale;

  /// No description provided for @merangNextOfficial.
  ///
  /// In en, this message translates to:
  /// **'Always confirm with NADMA, MetMalaysia or JPS. SIAGA helps you decide; it is not an official warning.'**
  String get merangNextOfficial;

  /// No description provided for @merangDataRig.
  ///
  /// In en, this message translates to:
  /// **'These numbers come from our bench rig. Its sensors feed an ESP32, which saves each reading to our online table (Supabase). The app checks for new rows every 3 seconds.'**
  String get merangDataRig;

  /// No description provided for @merangDataAgo.
  ///
  /// In en, this message translates to:
  /// **'The last reading was {ago} ago.'**
  String merangDataAgo(String ago);

  /// No description provided for @merangDataSim.
  ///
  /// In en, this message translates to:
  /// **'This node is simulated for the demo, so there is no sensor behind it.'**
  String get merangDataSim;

  /// No description provided for @merangDataOther.
  ///
  /// In en, this message translates to:
  /// **'These readings come from our sensor nodes, through our backend.'**
  String get merangDataOther;

  /// No description provided for @merangHow.
  ///
  /// In en, this message translates to:
  /// **'I am Merang. I read the same numbers you see and put them into plain words. I run on your phone, so I work offline and your location never leaves it. The sensors and the rules decide the alert, not me.'**
  String get merangHow;

  /// No description provided for @merangAiTag.
  ///
  /// In en, this message translates to:
  /// **'Written by AI (Gemini). Check the official channels.'**
  String get merangAiTag;

  /// No description provided for @merangInputHint.
  ///
  /// In en, this message translates to:
  /// **'Ask Merang about this reading…'**
  String get merangInputHint;

  /// No description provided for @merangSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get merangSend;

  /// No description provided for @merangHello.
  ///
  /// In en, this message translates to:
  /// **'Hi, I am Merang! Tap a question below, or type your own.'**
  String get merangHello;

  /// No description provided for @merangNoAi.
  ///
  /// In en, this message translates to:
  /// **'I cannot reach my AI brain right now, so I can only answer the questions below. Please tap one of them.'**
  String get merangNoAi;

  /// No description provided for @merangTypedNote.
  ///
  /// In en, this message translates to:
  /// **'Typed questions are sent to Google Gemini to be answered. Please do not type personal details.'**
  String get merangTypedNote;

  /// No description provided for @merangQTips.
  ///
  /// In en, this message translates to:
  /// **'Survival tips'**
  String get merangQTips;

  /// No description provided for @merangQWhere.
  ///
  /// In en, this message translates to:
  /// **'Where do I go?'**
  String get merangQWhere;

  /// No description provided for @merangQBring.
  ///
  /// In en, this message translates to:
  /// **'What should I bring?'**
  String get merangQBring;

  /// No description provided for @merangQStuck.
  ///
  /// In en, this message translates to:
  /// **'What if I can’t leave?'**
  String get merangQStuck;

  /// No description provided for @merangTips1.
  ///
  /// In en, this message translates to:
  /// **'Learn your way to higher ground before the water rises. Open the Map tab and find your nearest assembly point.'**
  String get merangTips1;

  /// No description provided for @merangTips2.
  ///
  /// In en, this message translates to:
  /// **'Never walk, swim or drive through floodwater. Even 15 cm of moving water can knock you off your feet.'**
  String get merangTips2;

  /// No description provided for @merangTips3.
  ///
  /// In en, this message translates to:
  /// **'Stay away from riverbanks, drains and steep slopes. After heavy rain, new cracks, leaning trees or muddy water running off a slope can mean a landslide.'**
  String get merangTips3;

  /// No description provided for @merangTips4.
  ///
  /// In en, this message translates to:
  /// **'If water enters your home, switch off the electricity at the main switch and do not touch wet electrical items. Keep your phone charged and your notifications on.'**
  String get merangTips4;

  /// No description provided for @merangWhere1.
  ///
  /// In en, this message translates to:
  /// **'Go to the nearest assembly point. Open the Map tab and tap View evacuation route to see the shortest way and the time on foot.'**
  String get merangWhere1;

  /// No description provided for @merangWhere2.
  ///
  /// In en, this message translates to:
  /// **'The route starts from your area, never your exact position. With no signal you still get a straight line, or the route you saved earlier.'**
  String get merangWhere2;

  /// No description provided for @merangBring1.
  ///
  /// In en, this message translates to:
  /// **'Only what you can grab in a minute: your phone and charger, ID, any medicine, some water and a torch.'**
  String get merangBring1;

  /// No description provided for @merangBring2.
  ///
  /// In en, this message translates to:
  /// **'Put documents in a waterproof bag if you have one. Go together with family and neighbours, and do not go back for belongings.'**
  String get merangBring2;

  /// No description provided for @merangStuck1.
  ///
  /// In en, this message translates to:
  /// **'Do not walk, swim or drive through floodwater. Move to the highest floor of a strong building, away from rivers, drains and slopes.'**
  String get merangStuck1;

  /// No description provided for @merangStuck2.
  ///
  /// In en, this message translates to:
  /// **'Call 999 and tell them where you are. Keep your phone charged and wait for help.'**
  String get merangStuck2;

  /// No description provided for @mapFaceNorth.
  ///
  /// In en, this message translates to:
  /// **'Face north'**
  String get mapFaceNorth;

  /// No description provided for @riskNoLive.
  ///
  /// In en, this message translates to:
  /// **'No live data'**
  String get riskNoLive;

  /// No description provided for @riskLastKnown.
  ///
  /// In en, this message translates to:
  /// **'Last known: {level}'**
  String riskLastKnown(String level);

  /// No description provided for @riskTrendsStale.
  ///
  /// In en, this message translates to:
  /// **'The last readings before the rig went quiet'**
  String get riskTrendsStale;

  /// No description provided for @mapKey.
  ///
  /// In en, this message translates to:
  /// **'Map key'**
  String get mapKey;

  /// No description provided for @liveTag.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get liveTag;

  /// No description provided for @riskLastHeard.
  ///
  /// In en, this message translates to:
  /// **'Last heard from the rig {ago}'**
  String riskLastHeard(String ago);

  /// No description provided for @riskLevelOf.
  ///
  /// In en, this message translates to:
  /// **'Level {n} of 4'**
  String riskLevelOf(String n);

  /// No description provided for @liveQuiet.
  ///
  /// In en, this message translates to:
  /// **'No place is at high risk right now'**
  String get liveQuiet;

  /// No description provided for @liveQuietOffline.
  ///
  /// In en, this message translates to:
  /// **'The rig is offline, so there is no live reading'**
  String get liveQuietOffline;

  /// No description provided for @liveOffline.
  ///
  /// In en, this message translates to:
  /// **'OFFLINE'**
  String get liveOffline;
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
