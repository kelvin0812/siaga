import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show CachingAssetBundle;
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

/// Hands the app the assembly points file from disk, with no real waiting, so the test's clock can move the screen on.
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
    appState.applyRigState(
      nodes: [
        SiagaNode(id: kRigNodeId, name: 'Bench rig (live)', lat: kVenueLat, lon: kVenueLon, state: RiskState.warning, lastSeen: DateTime.now(), batteryVolts: null),
      ],
      hazards: const [],
      reading: RigReading(
        phase: 3,
        confidence: 0.8,
        severity: 0.6,
        heightCm: 3,
        flow: 170,
        soilRaw: 450,
        tiltDeg: 0.3,
        rowTime: DateTime.now(),
        rowId: 1,
      ),
    );
  });

  Future<void> pumpMap(WidgetTester tester, {bool reduceMotion = false}) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final oldHandler = FlutterError.onError;
    // The test cannot download map tiles or route data; those failures are not what is being tested.
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
          home: const Scaffold(body: MapScreen()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  Finder routePainter() => find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_RoutePainter');

  testWidgets('turning the route on draws the animated route and its card, and turning it off removes them', (tester) async {
    await pumpMap(tester);
    expect(routePainter(), findsNothing);
    await tester.tap(find.text('View evacuation route'));
    // With no network the router cannot be reached, so the route falls back to a straight line and says so.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('Straight line, offline'), findsOneWidget);
    expect(routePainter(), findsOneWidget);

    // it keeps moving: the layer repaints as time passes without error
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
    expect(routePainter(), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('View evacuation route'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(routePainter(), findsNothing);
  });

  testWidgets('with reduced motion the route is still drawn, just without the animation running', (tester) async {
    await pumpMap(tester, reduceMotion: true);
    await tester.tap(find.text('View evacuation route'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(routePainter(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
