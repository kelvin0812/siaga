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
}
