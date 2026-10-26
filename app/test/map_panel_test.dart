import 'package:flutter/material.dart';
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
      cache: OfflineCache(prefs),
      locationService: LocationService(h3Service: _FakeCells(), fcmService: FcmService(), prefs: prefs),
    );
    appState.setRigMode(true);
    final now = DateTime.now();
    appState.applyRigState(
      nodes: [
        SiagaNode(
          id: kRigNodeId,
          name: 'Bench rig (live)',
          lat: kVenueLat,
          lon: kVenueLon,
          state: RiskState.watch,
          lastSeen: now,
          batteryVolts: null,
        ),
      ],
      hazards: const [],
      reading: RigReading(
        phase: 2,
        confidence: 0.8,
        severity: 0.3,
        heightCm: 1.5,
        flow: 170,
        soilRaw: 450,
        tiltDeg: 0.3,
        rowTime: now,
        rowId: 1,
      ),
      trend: [
        for (var i = 0; i < 30; i++)
          RigPoint(
            time: now.subtract(Duration(seconds: (30 - i) * 3)),
            heightCm: 1 + i * 0.02,
            flow: 170,
            soilRaw: 450,
            tiltDeg: 0.3,
            phase: 2,
          ),
      ],
    );
  });

  Future<void> openDetails(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final oldHandler = FlutterError.onError;
    // The test cannot download map tiles or satellite pictures; those failures are not what is being tested.
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('HTTP') || text.contains('Failed host lookup') || text.contains('ClientException')) return;
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
    // Tap the node the way a finger would: its marker carries a tooltip with the node's name.
    final tap = find.ancestor(of: find.byTooltip('Bench rig (live)'), matching: find.byType(GestureDetector)).first;
    tester.widget<GestureDetector>(tap).onTap!();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.tap(find.text('Details and trends'));
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('on a wide screen the node details are a tall fixed panel at the side, with nothing to drag', (tester) async {
    await openDetails(tester, const Size(1280, 860));
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    // everything is in view without dragging: the four readings and the trend chart
    expect(find.text('Water level'), findsWidgets);
    expect(find.text('Slope tilt'), findsWidgets);
    expect(find.textContaining('GPS location'), findsOneWidget);
    // the panel is a tall rectangle on the right
    final panel = find.ancestor(of: find.textContaining('GPS location'), matching: find.byType(Container)).last;
    final rect = tester.getRect(panel);
    expect(rect.width, 420);
    expect(rect.height, greaterThan(rect.width)); // vertical, not a wide strip
    expect(rect.right, closeTo(1280 - 30, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('on a phone the node details are a bottom sheet that opens most of the way up', (tester) async {
    await openDetails(tester, const Size(400, 860));
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    final sheet = tester.getRect(find.byType(DraggableScrollableSheet));
    final panel = tester.getRect(find.ancestor(of: find.textContaining('GPS location'), matching: find.byType(Container)).last);
    expect(panel.height, greaterThan(sheet.height * 0.55)); // opens well past the old 42%
    expect(tester.takeException(), isNull);
  });

  testWidgets('turning the map does not tilt the markers or their name tags', (tester) async {
    await openDetails(tester, const Size(400, 860));
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap).first);
    map.mapController!.rotate(45);
    await tester.pump(const Duration(milliseconds: 300));
    final marker = tester.renderObject(find.byTooltip('Bench rig (live)').first);
    final m = marker.getTransformTo(null).storage;
    // on screen the marker is upright: no rotation left in its transform (it would be about 0.71 if it turned with the map)
    expect(m[1].abs(), lessThan(0.01));
    expect(m[0], closeTo(1, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a compass appears only while the map is turned, and tapping it brings north back up', (tester) async {
    await openDetails(tester, const Size(400, 860));
    expect(find.byTooltip('Face north'), findsNothing); // north is up: nothing to correct
    final controller = tester.widget<FlutterMap>(find.byType(FlutterMap).first).mapController!;
    controller.rotate(70);
    await tester.pump(const Duration(milliseconds: 300)); // the map turns, and the screen is told after that frame
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byTooltip('Face north'), findsOneWidget);
    await tester.tap(find.byTooltip('Face north'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150)); // the swing takes about 0.4 s
    }
    expect(controller.camera.rotation, closeTo(0, 0.01));
    expect(find.byTooltip('Face north'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
