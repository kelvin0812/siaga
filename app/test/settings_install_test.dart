import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siaga_app/core/api_client.dart';
import 'package:siaga_app/core/app_state.dart';
import 'package:siaga_app/core/bench_sensor_service.dart';
import 'package:siaga_app/core/fcm_service.dart';
import 'package:siaga_app/core/h3_service.dart';
import 'package:siaga_app/core/install_service.dart';
import 'package:siaga_app/core/locale_provider.dart';
import 'package:siaga_app/core/location_service.dart';
import 'package:siaga_app/core/offline_cache.dart';
import 'package:siaga_app/core/rig_controller.dart';
import 'package:siaga_app/core/theme.dart';
import 'package:siaga_app/demo/demo_controller.dart';
import 'package:siaga_app/l10n/app_localizations.dart';
import 'package:siaga_app/screens/settings_screen.dart';

class _Cells implements CellComputer {
  @override
  String cellForPoint(double lat, double lon) => 'cellA';
}

/// A stand-in for the browser's install support.
class _FakeInstall extends InstallService {
  _FakeInstall({this.isSupported = true, this.isInstalled = false, this.promptReady = false, this.ios = false});
  final bool isSupported;
  bool isInstalled;
  bool promptReady;
  final bool ios;
  int prompts = 0;
  @override
  bool get supported => isSupported;
  @override
  bool get installed => isInstalled;
  @override
  bool get canPrompt => promptReady;
  @override
  bool get isIos => ios;
  @override
  Future<void> prompt() async {
    prompts++;
    isInstalled = true;
    notifyListeners();
  }
}

/// A rig that answers with one reading, however old.
class _OneReading implements BenchSensorService {
  _OneReading(this.age);
  final Duration age;
  @override
  Future<List<BenchSensorReading>> latest({int limit = 20}) async => [
        BenchSensorReading(
          id: 1,
          soil: 3,
          dist: 24.8,
          flow: 0,
          accelX: 9.74,
          accelY: -0.01,
          accelZ: 1.28,
          gyroX: 0.12,
          gyroY: -0.06,
          gyroZ: 0.03,
          createdAt: DateTime.now().toUtc().subtract(age),
        ),
      ];
  @override
  Future<List<BenchSensorReading>> history({int count = 150}) async => [];
  @override
  Future<List<BenchSensorReading>> since(int afterId, {int limit = 200}) async => [];
}

void main() {
  late AppState appState;
  late LocaleProvider locale;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    appState = AppState(
      api: ApiClient(),
      cache: OfflineCache(prefs),
      locationService: LocationService(h3Service: _Cells(), fcmService: FcmService(), prefs: prefs),
    );
    locale = LocaleProvider(prefs);
  });

  Future<void> show(WidgetTester tester, {InstallService? install, BenchSensorService? bench}) async {
    tester.view.physicalSize = const Size(420, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: appState),
          ChangeNotifierProvider<LocaleProvider>.value(value: locale),
          Provider<FcmService>.value(value: FcmService()),
          Provider<RigController>.value(value: RigController(appState: appState, service: _OneReading(Duration.zero), loadModelJson: () async => '{}')),
          Provider<DemoController>.value(value: DemoController(appState: appState)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: SiagaTheme.dark(),
          home: Scaffold(body: SettingsScreen(installService: install ?? _FakeInstall(isSupported: false), benchService: bench ?? _OneReading(Duration.zero))),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('install', () {
    testWidgets('there is nothing to install off the web, so no card', (tester) async {
      await show(tester);
      expect(find.text('Install app'), findsNothing);
    });

    testWidgets('where the browser can prompt, the button opens its install dialog', (tester) async {
      final install = _FakeInstall(promptReady: true);
      await show(tester, install: install);
      expect(find.text('Install SIAGA'), findsOneWidget);
      await tester.tap(find.text('Install app'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(install.prompts, 1);
      expect(find.text('SIAGA is installed on this device.'), findsOneWidget); // and it switches to "installed"
      expect(find.text('Install app'), findsNothing);
    });

    testWidgets('where it cannot, the same button shows the steps (Chrome menu)', (tester) async {
      final install = _FakeInstall();
      await show(tester, install: install);
      await tester.tap(find.text('Install app'));
      await tester.pumpAndSettle();
      expect(install.prompts, 0);
      expect(find.text('Add SIAGA to your home screen'), findsOneWidget);
      expect(find.text('Open this page in Chrome.'), findsOneWidget);
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(find.text('Add SIAGA to your home screen'), findsNothing);
    });

    testWidgets('on an iPhone the steps are Share, then Add to Home Screen', (tester) async {
      await show(tester, install: _FakeInstall(ios: true));
      await tester.tap(find.text('Install app'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Share button'), findsOneWidget);
      expect(find.textContaining('Add to Home Screen'), findsWidgets);
    });

    testWidgets('already installed: no button, just a quiet line', (tester) async {
      await show(tester, install: _FakeInstall(isInstalled: true));
      expect(find.text('SIAGA is installed on this device.'), findsOneWidget);
      expect(find.text('Install app'), findsNothing);
    });
  });

  group('rig readout', () {
    Future<void> open(WidgetTester tester, Duration age) async {
      await show(tester, bench: _OneReading(age));
      await tester.scrollUntilVisible(find.text('Rig sensor readings'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Rig sensor readings'));
      await tester.pumpAndSettle();
    }

    testWidgets('named tiles with units, and the three axes side by side', (tester) async {
      await open(tester, Duration.zero);
      expect(find.text('Soil moisture'), findsWidgets);
      expect(find.text('Distance to water'), findsOneWidget);
      expect(find.text('24.8'), findsOneWidget);
      expect(find.text('cm'), findsOneWidget);
      expect(find.text('Water flow'), findsWidgets);
      expect(find.text('Acceleration'), findsOneWidget);
      expect(find.text('9.74'), findsOneWidget);
      expect(find.text('-0.01'), findsOneWidget);
      expect(find.text('1.28'), findsOneWidget);
      expect(find.text('Rotation'), findsOneWidget);
      expect(find.text('0.12'), findsOneWidget);
      expect(find.text('Receiving live data'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an old reading says how old, not "live"', (tester) async {
      await open(tester, const Duration(hours: 39));
      expect(find.text('Last reading 39h ago'), findsOneWidget);
      expect(find.text('Receiving live data'), findsNothing);
    });

    testWidgets('the model evaluation panel is gone', (tester) async {
      await show(tester);
      expect(find.textContaining('Risk Model Evaluation'), findsNothing);
      expect(find.text('Run evaluation'), findsNothing);
    });
  });
}
