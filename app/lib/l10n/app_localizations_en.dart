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

  @override
  String get rigModeTitle => 'Live Rig (Phase Model)';

  @override
  String get rigModeDescription =>
      'Runs the whole app from the bench rig\'s real sensors. The phase model reads the water level, flow, soil and tilt, and shows Normal, Watch, Warning or Evacuate.';

  @override
  String get rigWaiting => 'Waiting for the rig\'s readings...';

  @override
  String get rigOffline => 'No recent data from the rig';

  @override
  String get rigPhaseLabel => 'Phase';

  @override
  String get rigReadoutTitle => 'Live rig readings';

  @override
  String get rigMetricLevel => 'Water level';

  @override
  String get rigMetricLevelCaption => 'Above normal river level';

  @override
  String get rigMetricFlow => 'Water flow';

  @override
  String get rigMetricFlowCaption => 'Sensor pulses every 3 s';

  @override
  String get rigUnitPulses => 'pulses';

  @override
  String get rigMetricSoil => 'Soil moisture';

  @override
  String get rigMetricSoilCaption => 'Soil sensor signal';

  @override
  String get rigMetricTilt => 'Slope tilt';

  @override
  String get rigMetricTiltCaption => 'Shift from resting position';

  @override
  String get rigLastKnown => 'Last known';

  @override
  String get rigStatusLive => 'Live';

  @override
  String get rigStatusOffline => 'Rig offline';

  @override
  String get rigLastData => 'last data';

  @override
  String get riskScoreLabel => 'Risk score';

  @override
  String get riskSummaryTitle => 'What this means';

  @override
  String get riskSummaryNormal =>
      'The water is at a normal level. No action is needed.';

  @override
  String get riskSummaryWatch =>
      'Conditions are changing. Stay alert and keep checking this screen.';

  @override
  String get riskSummaryWarning =>
      'Danger is building. Get ready to move to higher ground.';

  @override
  String get riskSummaryEvacuate =>
      'Dangerous conditions. Move to higher ground now.';

  @override
  String get riskSummaryOffline =>
      'The rig is not sending data, so there is no live assessment right now.';

  @override
  String get riskTrendsTitle => 'Trends';

  @override
  String get riskTrendsSubtitle =>
      'The last 10 minutes from the rig, updated live';

  @override
  String get trendRisk => 'Risk level';

  @override
  String get trendRiskHelp =>
      'The model\'s decision over time. Higher means more danger.';

  @override
  String get trendLevelHelp => 'Rising water is the strongest warning sign.';

  @override
  String get trendFlowHelp => 'A sudden surge means water is moving fast.';

  @override
  String get trendSoilHelp => 'Shows how much water the ground has taken in.';

  @override
  String get trendTiltHelp => 'Movement here can mean the slope is shifting.';

  @override
  String get trendNoData => 'Waiting for readings to draw this chart';

  @override
  String get trendNow => 'now';

  @override
  String get howTitle => 'How SIAGA decides';

  @override
  String get howStep1 =>
      'Sensors on the rig measure water level, flow, soil moisture and tilt every 3 seconds.';

  @override
  String get howStep2 =>
      'A machine-learning model, trained on this rig\'s own recorded runs, reads those four signals. Water level counts the most.';

  @override
  String get howStep3 =>
      'It picks one of four levels: Normal, Watch, Warning or Evacuate. The siren on the rig runs the same model, so it and this app follow the same readings.';

  @override
  String get mapLegendNode => 'Sensor node';

  @override
  String get mapLegendAssembly => 'Assembly point';

  @override
  String get mapLegendYou => 'You';

  @override
  String get routeShortest => 'Shortest route';

  @override
  String get routeByRoad => 'by road';

  @override
  String get routeStraight => 'Straight line, offline';

  @override
  String get routeSaved => 'Saved route';

  @override
  String get routeWalk => 'on foot';

  @override
  String get routeCalculating => 'Finding the shortest route...';

  @override
  String get routeAreaNote =>
      'The route starts from your area. Your exact position is never sent.';

  @override
  String get routeHere => 'Show route to this point';

  @override
  String get routeNearest => 'Back to the shortest route';

  @override
  String get nodeKindSensor => 'Sensor node';

  @override
  String get nodeKindAssembly => 'Assembly point';

  @override
  String get mapAway => 'away in a straight line';

  @override
  String get placeDetails => 'Details and trends';

  @override
  String get nodeKindDemo => 'Demo node';

  @override
  String get nodeSimulatedNote =>
      'Simulated for the demonstration. Its level follows the live rig.';

  @override
  String get mapLegendDemo => 'Demo node (simulated)';

  @override
  String get riskViewing => 'Data from';

  @override
  String get nodePickerTitle => 'Choose a node';

  @override
  String get nodePickerSearch => 'Search by name';

  @override
  String get nodeGroupSensor => 'Sensor nodes';

  @override
  String get nodeGroupDemo => 'Demo nodes (simulated)';

  @override
  String get nodeAutoPick => 'Nearest to me (automatic)';

  @override
  String get nodeNoMatch => 'No node matches that name.';

  @override
  String get simNoSensors =>
      'This is a demo node, so it has no sensors. Its level follows the live rig.';

  @override
  String get simShowRig => 'Show the live rig';

  @override
  String get statusNormalT => 'All clear for now';

  @override
  String get statusNormalD => 'The water is at its usual level.';

  @override
  String get statusWatchT => 'Keep an eye on it';

  @override
  String get statusWatchD =>
      'Readings are starting to change. Check back soon.';

  @override
  String get statusWarningT => 'Get ready to move';

  @override
  String get statusWarningD =>
      'Water is rising towards a dangerous level. Know your way to higher ground.';

  @override
  String get statusEvacT => 'Move to higher ground now';

  @override
  String get statusEvacD =>
      'Conditions are dangerous. Follow the route to the nearest assembly point.';

  @override
  String get statusOfflineT => 'No live readings';

  @override
  String get statusWaitingT => 'Waiting for the rig';

  @override
  String get statusWaitingD =>
      'Nothing has arrived yet. Check that the rig is switched on and online.';

  @override
  String get statusDemoT => 'Demo node';

  @override
  String get openMapBtn => 'Open the map';

  @override
  String get howTitle2 => 'How is this decided?';

  @override
  String get howBody =>
      'Four sensors on the rig feed a model trained on this rig\'s own test runs, and the water level counts the most. The siren on the rig runs the same model, so it shows the same level as this screen.';

  @override
  String get viewInRisk => 'Show in My Risk';

  @override
  String statusOfflineD(String ago) {
    return 'The last reading from the rig was $ago. SIAGA cannot say how things look right now.';
  }

  @override
  String get simRigOffline =>
      'The live rig is offline, so demo nodes rest at Normal.';

  @override
  String get popToggle => 'Population';

  @override
  String get popLegendTitle => 'People per km²';

  @override
  String get popHigh => 'High';

  @override
  String get popMedium => 'Medium';

  @override
  String get popLow => 'Low';

  @override
  String get popSource => 'Population estimate: Kontur, CC BY 4.0';

  @override
  String get popDensityHigh => 'High density';

  @override
  String get popDensityMedium => 'Medium density';

  @override
  String get popDensityLow => 'Low density';

  @override
  String get popDensitySparse => 'Sparsely populated';

  @override
  String popAround(String count, String km) {
    return 'About $count people within $km km';
  }

  @override
  String get settingsSectionDemo => 'Demonstration';

  @override
  String get settingsSectionDiagnostics => 'Diagnostics';

  @override
  String get settingsDiagnosticsHint =>
      'For the team: the rig\'s raw readings and a check of the model.';

  @override
  String get simulatePhaseTitle => 'Simulate a phase';

  @override
  String get simulatePhaseHint =>
      'Force the whole app to one phase to rehearse an alert. The map, My Risk and the alert all follow it.';

  @override
  String get simulateLive => 'Live';

  @override
  String simulatingNow(String phase) {
    return 'Simulating phase $phase. Real rig readings are paused.';
  }

  @override
  String get rigStatusSimulated => 'Simulated';

  @override
  String get settingsLanguageAuto => 'Auto';

  @override
  String get settingsAboutTagline =>
      'Early warning for flash floods and landslides.';

  @override
  String get settingsAboutCredits =>
      'Map data © OpenStreetMap contributors. Imagery © Esri. Population: Kontur (CC BY 4.0).';

  @override
  String get reportSubtitle =>
      'See something near a river, drain or slope? Tell the authorities in a few taps.';

  @override
  String get reportStepWhat => 'What did you see?';

  @override
  String get reportStepWhere => 'Where is it?';

  @override
  String get reportStepDetails => 'Anything to add?';

  @override
  String get reportPrivacy =>
      'Only the area code of this place is sent, never your exact position.';

  @override
  String get reportNotePlaceholder =>
      'e.g. water over the road near the bridge';

  @override
  String get reportCategoryLandslideShort => 'Landslide';

  @override
  String get merangName => 'Merang';

  @override
  String get merangTagline => 'Your river buddy. I explain what the app shows.';

  @override
  String get merangAsk => 'Ask Merang';

  @override
  String get merangAskHint => 'Why this level? What should I do?';

  @override
  String get merangHi => 'Hi, I am Merang!';

  @override
  String get merangDisclaimer =>
      'I only explain what the app already shows. I do not decide or send alerts. Check NADMA, MetMalaysia and JPS for official warnings.';

  @override
  String merangQWhy(String phase) {
    return 'Why is it $phase?';
  }

  @override
  String get merangQNext => 'What should I do?';

  @override
  String get merangQData => 'Where does this data come from?';

  @override
  String get merangQHow => 'How do you work?';

  @override
  String merangWhyLevel(String height) {
    return 'The water is $height cm above its normal level.';
  }

  @override
  String get merangWhyLevelNormal => 'The water is at its normal level.';

  @override
  String merangRiseFast(String rate) {
    return 'It is rising, about $rate cm every minute.';
  }

  @override
  String get merangRiseSlow => 'It is rising slowly.';

  @override
  String get merangRiseSteady => 'It is steady right now.';

  @override
  String merangFalling(String rate) {
    return 'It is going down, about $rate cm every minute.';
  }

  @override
  String get merangWhyBands =>
      'On our bench rig, Watch starts near 0.8 cm, Warning near 2.2 cm and Evacuate near 3.6 cm above normal.';

  @override
  String get merangWhyOthers =>
      'Flow, soil and tilt count too, but the water level matters most.';

  @override
  String merangWhyNoRig(String node, String phase) {
    return '$node is at $phase. I only have its summary here, not the raw sensor readings.';
  }

  @override
  String merangWhyStale(String ago) {
    return 'The rig has not sent anything for $ago, so there is no fresh reading. The app shows Normal rather than raising an alert from old data.';
  }

  @override
  String get merangWhySimulated =>
      'This level was set by hand in Settings for a demonstration. The numbers are typical values for that level, not live readings.';

  @override
  String get merangWhyDemoNode =>
      'This is a demo node. Its level follows the live rig.';

  @override
  String get merangNextNormal =>
      'Nothing to do right now. Keep notifications on, and check again if heavy rain starts.';

  @override
  String get merangNextWatch =>
      'Stay alert. Keep an eye on the app and the weather, and get your important things together.';

  @override
  String get merangNextWarning =>
      'Get ready to move. Know your route, charge your phone, and open the map to find the nearest assembly point.';

  @override
  String get merangNextEvacuate =>
      'Leave now. Follow the route to the nearest assembly point and listen to official instructions.';

  @override
  String get merangNextStale =>
      'The data is old, so do not rely on it. Check the official channels.';

  @override
  String get merangNextOfficial =>
      'Always confirm with NADMA, MetMalaysia or JPS. SIAGA helps you decide; it is not an official warning.';

  @override
  String get merangDataRig =>
      'These numbers come from our bench rig. Its sensors feed an ESP32, which saves each reading to our online table (Supabase). The app checks for new rows every 3 seconds.';

  @override
  String merangDataAgo(String ago) {
    return 'The last reading was $ago ago.';
  }

  @override
  String get merangDataSim =>
      'This node is simulated for the demo, so there is no sensor behind it.';

  @override
  String get merangDataOther =>
      'These readings come from our sensor nodes, through our backend.';

  @override
  String get merangHow =>
      'I am Merang. I read the same numbers you see and put them into plain words. I run on your phone, so I work offline and your location never leaves it. The sensors and the rules decide the alert, not me.';

  @override
  String get merangAiTag =>
      'Written by AI (Gemini). Check the official channels.';

  @override
  String get merangInputHint => 'Ask Merang about this reading…';

  @override
  String get merangSend => 'Send';

  @override
  String get merangHello =>
      'Hi, I am Merang! Tap a question below, or type your own.';

  @override
  String get merangNoAi =>
      'I cannot reach my AI brain right now, so I can only answer the questions below. Please tap one of them.';

  @override
  String get merangTypedNote =>
      'Typed questions are sent to Google Gemini to be answered. Please do not type personal details.';
}
