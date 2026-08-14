import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siaga_app/core/api_client.dart';
import 'package:siaga_app/core/app_state.dart';
import 'package:siaga_app/core/fcm_service.dart';
import 'package:siaga_app/core/h3_service.dart';
import 'package:siaga_app/core/location_service.dart';
import 'package:siaga_app/core/models.dart';
import 'package:siaga_app/core/offline_cache.dart';

Position _positionAt(double lat, double lon) => Position(
      latitude: lat,
      longitude: lon,
      timestamp: DateTime.now(),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

class FakeCellComputer implements CellComputer {
  final String cell;
  FakeCellComputer(this.cell);
  @override
  String cellForPoint(double lat, double lon) => cell;
}

Hazard hazard({required RiskState state, required List<String> cells}) => Hazard(
      id: 1,
      state: state,
      cells: cells,
      issuedAt: DateTime.now(),
      messageEn: 'en',
      messageMs: 'ms',
    );

SiagaNode demoNode(RiskState state) => SiagaNode(
      id: 999,
      name: 'Demo Node',
      lat: 4.85,
      lon: 100.74,
      state: state,
      lastSeen: DateTime.now(),
      batteryVolts: 3.8,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  AppState buildState(String cellId) {
    final locationService = LocationService(
      h3Service: FakeCellComputer(cellId),
      fcmService: FcmService(),
      prefs: prefs,
    );
    return AppState(
      api: ApiClient(),
      cache: OfflineCache(prefs),
      locationService: locationService,
    );
  }

  test('myRiskState is normal with no active hazards', () {
    final state = buildState('cellA');
    expect(state.myRiskState, RiskState.normal);
  });

  test('myRiskState is normal when no cell is known yet', () {
    final state = buildState('cellA');
    state.activeHazards = [hazard(state: RiskState.evacuate, cells: ['cellA'])];
    // no position has been reported yet, so currentCellId is still null
    expect(state.currentCellId, isNull);
    expect(state.myRiskState, RiskState.normal);
  });

  test('myRiskState reflects a hazard covering the current cell', () async {
    final state = buildState('cellA');
    await state.locationService.handlePosition(
      _positionAt(1.0, 2.0),
    );
    state.activeHazards = [hazard(state: RiskState.warning, cells: ['cellA'])];
    expect(state.myRiskState, RiskState.warning);
  });

  test('myRiskState ignores hazards that do not cover the current cell', () async {
    final state = buildState('cellA');
    await state.locationService.handlePosition(_positionAt(1.0, 2.0));
    state.activeHazards = [hazard(state: RiskState.evacuate, cells: ['cellB'])];
    expect(state.myRiskState, RiskState.normal);
  });

  test('myRiskState picks the highest severity among overlapping hazards', () async {
    final state = buildState('cellA');
    await state.locationService.handlePosition(_positionAt(1.0, 2.0));
    state.activeHazards = [
      hazard(state: RiskState.watch, cells: ['cellA']),
      hazard(state: RiskState.evacuate, cells: ['cellA']),
      hazard(state: RiskState.warning, cells: ['cellA']),
    ];
    expect(state.myRiskState, RiskState.evacuate);
  });

  test('demo mode reflects the demo node state directly with no GPS fix', () {
    final state = buildState('cellA');
    expect(state.currentCellId, isNull, reason: 'no position reported — no real cell known');
    state.demoMode = true;
    state.nodes = [demoNode(RiskState.evacuate)];
    // Without the demo-mode branch this would stay NORMAL forever, since
    // hazard-cell matching depends on a currentCellId that demo mode
    // (deliberately, for booth use with no GPS) never provides.
    expect(state.myRiskState, RiskState.evacuate);
  });

  test('demo mode is normal before the first demo tick populates a node', () {
    final state = buildState('cellA');
    state.demoMode = true;
    expect(state.nodes, isEmpty);
    expect(state.myRiskState, RiskState.normal);
  });

  test('non-demo mode is unaffected by a stale demo node left in state', () {
    final state = buildState('cellA');
    state.nodes = [demoNode(RiskState.evacuate)];
    state.demoMode = false;
    // real-mode logic must still key off hazard/cell matching, not nodes
    expect(state.myRiskState, RiskState.normal);
  });
}
