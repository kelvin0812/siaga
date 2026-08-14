import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siaga_app/core/fcm_service.dart';
import 'package:siaga_app/core/h3_service.dart';
import 'package:siaga_app/core/location_service.dart';

/// Deterministic stand-in for H3Service — h3_flutter's native binding
/// can't load under `flutter test` on this machine (see h3_service.dart),
/// so the actual H3 math is untested here; what's tested is that
/// LocationService reacts to cell *changes* correctly regardless of how
/// the cell ID was computed.
class FakeCellComputer implements CellComputer {
  final Map<String, String> latLonToCell;
  FakeCellComputer(this.latLonToCell);

  @override
  String cellForPoint(double lat, double lon) {
    final key = '$lat,$lon';
    return latLonToCell[key] ?? 'unmapped';
  }
}

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('first position sets the current cell and emits it', () async {
    final h3 = FakeCellComputer({'1.0,2.0': 'cellA'});
    final service = LocationService(
      h3Service: h3,
      fcmService: FcmService(), // uninitialized -> safe no-op
      prefs: prefs,
    );

    expect(service.currentCellId, isNull);

    final emitted = <String>[];
    service.cellChanges.listen(emitted.add);
    await service.handlePosition(_positionAt(1.0, 2.0));
    await Future.delayed(Duration.zero);

    expect(service.currentCellId, 'cellA');
    expect(emitted, ['cellA']);
  });

  test('staying within the same cell does not emit again', () async {
    final h3 = FakeCellComputer({
      '1.0,2.0': 'cellA',
      '1.0001,2.0001': 'cellA', // tiny movement, still same H3 cell
    });
    final service = LocationService(
      h3Service: h3,
      fcmService: FcmService(),
      prefs: prefs,
    );

    final emitted = <String>[];
    service.cellChanges.listen(emitted.add);
    await service.handlePosition(_positionAt(1.0, 2.0));
    await service.handlePosition(_positionAt(1.0001, 2.0001));
    await Future.delayed(Duration.zero);

    expect(emitted, ['cellA'], reason: 'second position must not re-emit');
  });

  test('crossing a cell boundary emits the new cell and persists it', () async {
    final h3 = FakeCellComputer({
      '1.0,2.0': 'cellA',
      '5.0,6.0': 'cellB',
    });
    final service = LocationService(
      h3Service: h3,
      fcmService: FcmService(),
      prefs: prefs,
    );

    final emitted = <String>[];
    service.cellChanges.listen(emitted.add);
    await service.handlePosition(_positionAt(1.0, 2.0));
    await service.handlePosition(_positionAt(5.0, 6.0));
    await Future.delayed(Duration.zero);

    expect(emitted, ['cellA', 'cellB']);
    expect(service.currentCellId, 'cellB');
    expect(prefs.getString('siaga.current_cell_id'), 'cellB');
  });

  test('persisted cell from a previous session survives construction', () async {
    SharedPreferences.setMockInitialValues({'siaga.current_cell_id': 'cellFromLastSession'});
    final restoredPrefs = await SharedPreferences.getInstance();
    final service = LocationService(
      h3Service: FakeCellComputer({}),
      fcmService: FcmService(),
      prefs: restoredPrefs,
    );

    expect(service.currentCellId, 'cellFromLastSession');
  });
}
