import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show CachingAssetBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siaga_app/core/api_client.dart';
import 'package:siaga_app/core/app_state.dart';
import 'package:siaga_app/core/fcm_service.dart';
import 'package:siaga_app/core/h3_service.dart';
import 'package:siaga_app/core/location_service.dart';
import 'package:siaga_app/core/models.dart';
import 'package:siaga_app/core/offline_cache.dart';
import 'package:siaga_app/core/rig_controller.dart';
import 'package:siaga_app/core/theme.dart';
import 'package:siaga_app/l10n/app_localizations.dart';
import 'package:siaga_app/screens/map_screen.dart';

/// Hands the app its bundled files from disk, with no real waiting, so the test's clock can move the screen on.
class _FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(utf8.encode(File(key).readAsStringSync()));
    return ByteData.sublistView(bytes);
  }
}

class _FakeCells implements CellComputer {
  @override
  String cellForPoint(double lat, double lon) => 'cellA';
}

void main() {
  late AppState appState;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    appState = AppState(
      api: ApiClient(),
      cache: OfflineCache(prefs, bundle: _FileBundle()),
      locationService: LocationService(h3Service: _FakeCells(), fcmService: FcmService(), prefs: prefs),
    );
    appState.setRigMode(true);
    final now = DateTime.now();
    appState.applyRigState(
      nodes: [
        SiagaNode(id: kRigNodeId, name: 'Bench rig (live)', lat: kVenueLat, lon: kVenueLon, state: RiskState.warning, lastSeen: now, batteryVolts: null),
        SiagaNode(
          id: 991,
          name: 'Lake bank (demo)',
          lat: 2.93775,
          lon: 101.64303,
          state: RiskState.watch,
          lastSeen: null,
          batteryVolts: null,
          simulated: true,
        ),
      ],
      hazards: const [],
      reading: RigReading(phase: 3, confidence: 0.8, severity: 0.6, heightCm: 3, flow: 170, soilRaw: 450, tiltDeg: 0.3, rowTime: now, rowId: 1),
    );
  });

  Future<void> pumpMap(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final oldHandler = FlutterError.onError;
    // The test cannot download map tiles or pictures; those failures are not what is being tested.
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('HTTP') || text.contains('Failed host lookup') || text.contains('ClientException') || text.contains('MissingPluginException')) return;
      oldHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = oldHandler);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: appState,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: SiagaTheme.dark(),
          home: const Scaffold(body: MapScreen()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> tapMarker(WidgetTester tester, String name) async {
    final tap = find.ancestor(of: find.byTooltip(name), matching: find.byType(GestureDetector)).first;
    tester.widget<GestureDetector>(tap).onTap!();
    await tester.pump(const Duration(milliseconds: 800));
  }

  testWidgets('the population layer is off until asked for, then shows what the colours mean', (tester) async {
    await pumpMap(tester);
    expect(find.byType(PolygonLayer), findsNothing);
    expect(find.text('People per km²'), findsNothing);

    await tester.tap(find.byTooltip('Population'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PolygonLayer), findsOneWidget);
    expect(find.text('People per km²'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Low'), findsOneWidget);
    expect(find.textContaining('Kontur'), findsOneWidget); // the data's source is credited on screen
    expect(find.text('Sensor node'), findsNothing); // the marker legend gives way, to keep the screen clean

    await tester.tap(find.byTooltip('Population'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PolygonLayer), findsNothing);
    expect(find.text('Sensor node'), findsNothing); // the key is folded away until asked for
    await tester.tap(find.byTooltip('Map key'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sensor node'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a node\'s card reads out its message and how many people live around it', (tester) async {
    await pumpMap(tester);
    await tapMarker(tester, 'Bench rig (live)');
    // the same words the My Risk screen uses for a Warning, readable without leaving the map
    expect(find.text('Get ready to move'), findsOneWidget);
    expect(find.textContaining('Water is rising'), findsOneWidget);
    // and the estimate for around the node, with how crowded it is
    expect(find.textContaining('people within 1 km'), findsOneWidget);
    expect(find.textContaining('density'), findsOneWidget);
    // while the shortcut to My Risk is still there
    expect(find.text('Show in My Risk'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a demo node shows its own message, says it is simulated, and still links to My Risk', (tester) async {
    await pumpMap(tester);
    await tapMarker(tester, 'Lake bank (demo)');
    expect(find.text('Keep an eye on it'), findsOneWidget); // its Watch level
    expect(find.textContaining('Simulated for the demonstration'), findsOneWidget);
    expect(find.text('Demo node'), findsWidgets);
    expect(find.textContaining('people within 1 km'), findsOneWidget);
    expect(find.text('Show in My Risk'), findsOneWidget);
    await tester.tap(find.text('Show in My Risk'));
    await tester.pump();
    expect(appState.lockedNodeId, 991);
    expect(appState.pendingTab, 1);
  });

  testWidgets('an assembly point\'s card also says how many people live around it', (tester) async {
    await pumpMap(tester);
    // MMU Stadium is one of the assembly points the demo is set up with
    await tapMarker(tester, 'MMU Stadium, Cyberjaya');
    expect(find.textContaining('people within 1 km'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
