import 'package:flutter/material.dart';
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
import 'package:siaga_app/screens/risk_screen.dart';

class _FakeCells implements CellComputer {
  @override
  String cellForPoint(double lat, double lon) => 'cellA';
}

SiagaNode _node(int id, String name, RiskState state, {bool simulated = false}) => SiagaNode(
      id: id,
      name: name,
      lat: 2.9279,
      lon: 101.6418,
      state: state,
      lastSeen: null,
      batteryVolts: null,
      simulated: simulated,
    );

RigReading _reading(int phase, {Duration age = Duration.zero}) => RigReading(
      phase: phase,
      confidence: 0.9,
      severity: 0.3,
      heightCm: 1.2,
      flow: 170,
      soilRaw: 450,
      tiltDeg: 0.3,
      rowTime: DateTime.now().subtract(age),
      rowId: 1,
    );

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
  });

  Future<void> show(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: appState,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: SiagaTheme.dark(),
          home: const Scaffold(body: RiskScreen()),
        ),
      ),
    );
    await tester.pump();
  }

  void rigState({int phase = 1, Duration age = Duration.zero, RiskState? demoState}) {
    appState.setRigMode(true);
    appState.applyRigState(
      nodes: [
        _node(kRigNodeId, 'Bench rig (live)', RiskState.values[phase - 1]),
        _node(991, 'Lake bank (demo)', demoState ?? RiskState.watch, simulated: true),
      ],
      hazards: const [],
      reading: _reading(phase, age: age),
    );
  }

  testWidgets('says which node the data comes from, and starts on the live rig', (tester) async {
    rigState();
    await show(tester);
    expect(find.text('Data from'), findsOneWidget);
    expect(find.text('Bench rig (live)'), findsOneWidget);
    expect(find.text('WATER LEVEL'), findsOneWidget); // the live rig's sensor tiles are showing
    expect(tester.takeException(), isNull);
  });

  testWidgets('any node can be chosen from a searchable list, and a demo node is marked as a demo', (tester) async {
    rigState();
    await show(tester);
    await tester.tap(find.text('Bench rig (live)'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a node'), findsOneWidget);
    expect(find.text('Sensor nodes (1)'), findsOneWidget);
    expect(find.text('Demo nodes (simulated) (1)'), findsOneWidget);

    // searching narrows the list
    final inList = find.byType(BottomSheet);
    await tester.enterText(find.byType(TextField), 'lake');
    await tester.pumpAndSettle();
    expect(find.descendant(of: inList, matching: find.text('Lake bank (demo)')), findsOneWidget);
    expect(find.descendant(of: inList, matching: find.text('Bench rig (live)')), findsNothing);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No node matches that name.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lake bank (demo)'));
    await tester.pumpAndSettle();
    expect(appState.lockedNodeId, 991);
    expect(find.text('Choose a node'), findsNothing); // the list closed
    // a demo node has no sensors, so no tiles are drawn for it and the panel says so
    expect(find.text('WATER LEVEL'), findsNothing);
    expect(find.text('Demo node'), findsWidgets);
    expect(find.textContaining('has no sensors'), findsOneWidget);

    // and a button leads back to the live rig
    await tester.tap(find.text('Show the live rig'));
    await tester.pumpAndSettle();
    expect(appState.lockedNodeId, isNull);
    expect(find.text('WATER LEVEL'), findsOneWidget);
  });

  testWidgets('the status panel gives one plain line per level, and a way to the map when it matters', (tester) async {
    rigState(phase: 1);
    await show(tester);
    expect(find.text('All clear for now'), findsOneWidget);
    expect(find.text('Open the map'), findsNothing);

    rigState(phase: 3);
    await tester.pump();
    expect(find.text('Get ready to move'), findsOneWidget);
    await tester.tap(find.text('Open the map'));
    expect(appState.pendingTab, 0); // asks the home screen to show the map

    rigState(phase: 4);
    await tester.pump();
    expect(find.text('Move to higher ground now'), findsOneWidget);
  });

  testWidgets('old data is called old, not shown as a live assessment', (tester) async {
    rigState(phase: 3, age: const Duration(hours: 13));
    await show(tester);
    expect(find.text('No live readings'), findsOneWidget);
    expect(find.textContaining('13h ago'), findsWidgets);
    expect(find.text('Get ready to move'), findsNothing);
    expect(find.text('Open the map'), findsNothing);
  });

  testWidgets('the explanation is folded away until asked for', (tester) async {
    rigState();
    await show(tester);
    expect(find.text('How is this decided?'), findsOneWidget);
    expect(find.textContaining('Four sensors on the rig'), findsNothing);
    await tester.scrollUntilVisible(find.text('How is this decided?'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('How is this decided?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Four sensors on the rig'), findsOneWidget);
  });
}
