import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siaga_app/core/api_client.dart';
import 'package:siaga_app/core/app_state.dart';
import 'package:siaga_app/core/bench_sensor_service.dart';
import 'package:siaga_app/core/fcm_service.dart';
import 'package:siaga_app/core/h3_service.dart';
import 'package:siaga_app/core/locale_provider.dart';
import 'package:siaga_app/core/location_service.dart';
import 'package:siaga_app/core/offline_cache.dart';
import 'package:siaga_app/core/rig_controller.dart';
import 'package:siaga_app/core/theme.dart';
import 'package:siaga_app/demo/demo_controller.dart';
import 'package:siaga_app/l10n/app_localizations.dart';
import 'package:siaga_app/screens/report_screen.dart';
import 'package:siaga_app/screens/settings_screen.dart';

class _FakeCells implements CellComputer {
  @override
  String cellForPoint(double lat, double lon) => 'cellA';
}

/// A rig that has sent nothing, so the phase buttons are the only thing driving the app.
class _SilentRig implements BenchSensorService {
  @override
  Future<List<BenchSensorReading>> history({int count = 150}) async => [];
  @override
  Future<List<BenchSensorReading>> since(int afterId, {int limit = 200}) async => [];
  @override
  Future<List<BenchSensorReading>> latest({int limit = 20}) async => [];
}

void main() {
  late AppState appState;
  late RigController rig;
  late LocaleProvider locale;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    appState = AppState(
      api: ApiClient(),
      cache: OfflineCache(prefs),
      locationService: LocationService(h3Service: _FakeCells(), fcmService: FcmService(), prefs: prefs),
    );
    rig = RigController(
      appState: appState,
      service: _SilentRig(),
      loadModelJson: () async => File('assets/phase_model.json').readAsStringSync(),
    );
    locale = LocaleProvider(prefs);
  });

  Future<void> pump(WidgetTester tester, Widget screen, {Size size = const Size(420, 1700)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: appState),
          ChangeNotifierProvider<LocaleProvider>.value(value: locale),
          Provider<FcmService>.value(value: FcmService()),
          Provider<RigController>.value(value: rig),
          Provider<DemoController>.value(value: DemoController(appState: appState)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: SiagaTheme.dark(),
          home: Scaffold(body: screen),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('settings', () {
    testWidgets('the phase buttons only appear while the live rig is on', (tester) async {
      await pump(tester, const SettingsScreen());
      expect(find.text('Simulate a phase'), findsNothing);
      appState.setRigMode(true);
      await tester.pump();
      expect(find.text('Simulate a phase'), findsOneWidget);
      for (final n in ['1', '2', '3', '4']) {
        expect(find.text(n), findsOneWidget);
      }
      expect(find.text('Live'), findsOneWidget);
    });

    testWidgets('tapping a phase forces it across the app, and Live gives the rig back', (tester) async {
      appState.setRigMode(true);
      await rig.start();
      await pump(tester, const SettingsScreen());

      await tester.tap(find.text('3'));
      await tester.pump();
      expect(appState.rigReading!.phase, 3);
      expect(appState.rigReading!.simulated, isTrue);
      expect(appState.nodes.first.state.name, 'warning');
      expect(find.textContaining('Simulating phase 3'), findsOneWidget);

      await tester.tap(find.text('4'));
      await tester.pump();
      expect(appState.rigReading!.phase, 4);
      expect(appState.activeHazards, isNotEmpty);

      await tester.tap(find.text('Live'));
      await tester.pump();
      expect(rig.overridePhase, isNull);
      expect(appState.rigReading, isNull); // the silent rig has nothing to show
      expect(find.textContaining('Simulating phase'), findsNothing);
      rig.stop();
    });

    testWidgets('the language switch changes the locale override', (tester) async {
      await pump(tester, const SettingsScreen());
      expect(locale.overrideLocale, isNull);
      await tester.tap(find.text('Bahasa Malaysia'));
      await tester.pump();
      expect(locale.overrideLocale?.languageCode, 'ms');
      await tester.tap(find.text('Auto'));
      await tester.pump();
      expect(locale.overrideLocale, isNull);
    });

    testWidgets('the technical panels start folded and open on tap', (tester) async {
      await pump(tester, const SettingsScreen());
      expect(find.text('Bench Sensor Rig (Live)'), findsOneWidget);
      expect(find.text('Run evaluation'), findsNothing);
      await tester.tap(find.text('Risk Model Evaluation (Bench Data)'));
      await tester.pumpAndSettle();
      expect(find.text('Run evaluation'), findsOneWidget);
    });

    testWidgets('fits a small phone without overflowing', (tester) async {
      appState.setRigMode(true);
      await rig.start();
      await pump(tester, const SettingsScreen(), size: const Size(320, 1700));
      await tester.tap(find.text('2'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      rig.stop();
    });
  });

  group('report', () {
    testWidgets('reads as three steps with the three hazard kinds always visible', (tester) async {
      await pump(tester, const ReportScreen());
      expect(find.text('What did you see?'), findsOneWidget);
      expect(find.text('Where is it?'), findsOneWidget);
      expect(find.text('Anything to add?'), findsOneWidget);
      for (final t in ['Flooding', 'Landslide', 'Other']) {
        expect(find.text(t), findsOneWidget);
      }
      expect(find.textContaining('never your exact position'), findsOneWidget);
      expect(find.text('Submit report'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits a small phone without overflowing', (tester) async {
      await pump(tester, const ReportScreen(), size: const Size(320, 1100));
      await tester.tap(find.text('Landslide'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
