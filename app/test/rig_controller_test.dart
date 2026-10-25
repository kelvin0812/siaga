import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siaga_app/core/api_client.dart';
import 'package:siaga_app/core/app_state.dart';
import 'package:siaga_app/core/bench_sensor_service.dart';
import 'package:siaga_app/core/fcm_service.dart';
import 'package:siaga_app/core/h3_service.dart';
import 'package:siaga_app/core/location_service.dart';
import 'package:siaga_app/core/models.dart';
import 'package:siaga_app/core/offline_cache.dart';
import 'package:siaga_app/core/rig_controller.dart';

class _FakeCells implements CellComputer {
  @override
  String cellForPoint(double lat, double lon) => 'cellA';
}

/// Serves rig rows from a list, the way Supabase's sensor_table would, without any network.
class _FakeService implements BenchSensorService {
  final List<BenchSensorReading> rows;
  int served = 0; // how many rows have "arrived" so far
  _FakeService(this.rows);

  @override
  Future<List<BenchSensorReading>> history({int count = 150}) async {
    final slice = rows.sublist(0, served);
    return slice.length <= count ? slice : slice.sublist(slice.length - count);
  }

  @override
  Future<List<BenchSensorReading>> since(int afterId, {int limit = 200}) async =>
      rows.sublist(0, served).where((r) => r.id > afterId).take(limit).toList();

  @override
  Future<List<BenchSensorReading>> latest({int limit = 20}) async => rows.sublist(0, served).reversed.take(limit).toList();
}

BenchSensorReading _row(int id, Map<String, dynamic> r, DateTime t0) => BenchSensorReading(
      id: id,
      soil: (r['soil'] as num).toInt(),
      dist: (r['dist'] as num).toDouble(),
      flow: (r['flow'] as num).toInt(),
      accelX: ((r['accel'] as List)[0] as num).toDouble(),
      accelY: ((r['accel'] as List)[1] as num).toDouble(),
      accelZ: ((r['accel'] as List)[2] as num).toDouble(),
      gyroX: ((r['gyro'] as List)[0] as num).toDouble(),
      gyroY: ((r['gyro'] as List)[1] as num).toDouble(),
      gyroZ: ((r['gyro'] as List)[2] as num).toDouble(),
      createdAt: t0.add(Duration(milliseconds: ((r['t'] as num) * 1000).round())),
    );

/// The fixture's real rig rows, spaced as recorded, with the last one stamped at [end].
List<BenchSensorReading> _rowsEndingAt(List<Map<String, dynamic>> src, DateTime end) {
  final lastT = (src.last['t'] as num).toDouble();
  final t0 = end.subtract(Duration(milliseconds: (lastT * 1000).round()));
  return [for (var i = 0; i < src.length; i++) _row(i + 1, src[i], t0)];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppState appState;
  late List<BenchSensorReading> rows;
  late List<Map<String, dynamic>> sourceRows;
  final modelJson = File('assets/phase_model.json').readAsStringSync();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    appState = AppState(
      api: ApiClient(),
      cache: OfflineCache(prefs),
      locationService: LocationService(h3Service: _FakeCells(), fcmService: FcmService(), prefs: prefs),
    );
    final fixture = jsonDecode(File('test/fixtures/phase_fixture.json').readAsStringSync()) as Map<String, dynamic>;
    final caseRows = (fixture['cases'][0]['rows'] as List).cast<Map<String, dynamic>>();
    sourceRows = caseRows;
    rows = _rowsEndingAt(sourceRows, DateTime.now());
  });

  RigController controllerFor(_FakeService service) =>
      RigController(appState: appState, service: service, loadModelJson: () async => modelJson);

  test('live mode turns real rig rows into a phase and drives the app state', () async {
    // The fixture starts at row 480 of the recording; Phase 1 runs to row 547, so the first 60 rows are Phase 1.
    final service = _FakeService(rows)..served = 60;
    final controller = controllerFor(service);
    appState.setRigMode(true);
    await controller.start();

    expect(appState.rigMode, isTrue);
    // The live rig comes first, followed by the simulated demo nodes around it.
    expect(appState.nodes, hasLength(1 + kCyberjayaDemoNodes.length));
    expect(appState.nodes.first.simulated, isFalse);
    expect(appState.nodes.skip(1).every((n) => n.simulated), isTrue);
    expect(appState.nodes.first.state, RiskState.normal);
    expect(appState.rigReading, isNotNull);
    expect(appState.rigReading!.phase, 1);

    // The rig keeps sending: the later rows are the Phase 2 stretch, and a poll picks them up.
    service.served = rows.length;
    await controller.poll();
    controller.stop();
    expect(appState.rigReading!.phase, greaterThanOrEqualTo(2));
    expect(appState.nodes.first.state.index, greaterThanOrEqualTo(RiskState.watch.index));
    expect(appState.nodes.first.riskProbability, inInclusiveRange(0.0, 1.0));
  });

  test('an alertable phase creates an advisory with the official-channel wording', () async {
    final service = _FakeService(rows)..served = rows.length; // fresh: the last row is stamped now
    final controller = controllerFor(service);
    appState.setRigMode(true);
    await controller.start();
    controller.stop();
    expect(appState.rigReading!.isStale, isFalse);
    expect(appState.rigReading!.phase, greaterThanOrEqualTo(2));
    final state = appState.nodes.first.state;
    if (state.isAlertable) {
      expect(appState.activeHazards, isNotEmpty);
      expect(appState.activeHazards.first.messageEn, contains('NADMA'));
    } else {
      expect(appState.activeHazards, isEmpty);
    }
  });

  test('old data raises no alert and is shown as last known, not as a live emergency', () async {
    final service = _FakeService(_rowsEndingAt(sourceRows, DateTime.now().subtract(const Duration(hours: 1))));
    service.served = service.rows.length;
    final controller = controllerFor(service);
    appState.setRigMode(true);
    await controller.start();
    controller.stop();
    expect(appState.rigReading!.isStale, isTrue);
    expect(appState.rigReading!.phase, greaterThanOrEqualTo(2)); // the last known phase is still kept
    expect(appState.nodes.first.state, RiskState.normal);       // but it is not shown as a live state
    expect(appState.nodes.first.riskProbability, isNull);
    expect(appState.activeHazards, isEmpty);                     // and no advisory is raised
  });

  test('with no rows yet the app shows waiting, not a made-up phase', () async {
    final service = _FakeService(rows)..served = 0;
    final controller = controllerFor(service);
    appState.setRigMode(true);
    await controller.start();
    controller.stop();
    expect(appState.rigReading, isNull);
    // No made-up reading, so no rig node. The demo nodes are still on the map, all Normal and all marked simulated.
    expect(appState.nodes, hasLength(kCyberjayaDemoNodes.length));
    expect(appState.nodes.every((n) => n.simulated && n.state == RiskState.normal), isTrue);
  });

  test('the demo nodes follow the live rig, each in its own way, and are never presented as real', () async {
    final service = _FakeService(rows)..served = rows.length; // fresh rows, ending at a raised phase
    final controller = controllerFor(service);
    appState.setRigMode(true);
    await controller.start();
    controller.stop();

    final rig = appState.nodes.first;
    expect(rig.state.index, greaterThanOrEqualTo(RiskState.watch.index));
    final lake = appState.nodes.firstWhere((n) => n.id == 991);
    final drain = appState.nodes.firstWhere((n) => n.id == 992);
    final embankment = appState.nodes.firstWhere((n) => n.id == 993);
    expect(lake.state, rig.state); // the same as the rig
    expect(drain.state.index, rig.state.index - 1); // one level behind
    expect(embankment.state.index, rig.state.index >= RiskState.warning.index ? 1 : 0); // only reacts when severe
    for (final n in [lake, drain, embankment]) {
      expect(n.simulated, isTrue);
      expect(n.lastSeen, isNull); // no real reading ever reached it
      expect(n.riskProbability, isNull);
    }
  });

  test('when the rig goes quiet the demo nodes go back to Normal too', () async {
    final service = _FakeService(_rowsEndingAt(sourceRows, DateTime.now().subtract(const Duration(hours: 1))));
    service.served = service.rows.length;
    final controller = controllerFor(service);
    appState.setRigMode(true);
    await controller.start();
    controller.stop();
    expect(appState.nodes.every((n) => n.state == RiskState.normal), isTrue);
  });

  test('the live rig is placed at MMU Cyberjaya', () {
    final controller = controllerFor(_FakeService(rows));
    expect(controller.nodeLat, closeTo(2.9279, 0.001));
    expect(controller.nodeLon, closeTo(101.6418, 0.001));
    for (final d in kCyberjayaDemoNodes) {
      expect(d.lat, inInclusiveRange(2.90, 2.95)); // all within Cyberjaya
      expect(d.lon, inInclusiveRange(101.62, 101.67));
    }
  });

  test('the charts get the recent readings, oldest first, capped at the last 10 minutes', () async {
    final service = _FakeService(rows)..served = rows.length;
    final controller = controllerFor(service);
    appState.setRigMode(true);
    await controller.start();
    controller.stop();

    final trend = appState.rigTrend;
    expect(trend, isNotEmpty);
    expect(trend.length, lessThanOrEqualTo(RigController.trendLength));
    for (var i = 1; i < trend.length; i++) {
      expect(trend[i].time.isBefore(trend[i - 1].time), isFalse);
    }
    for (final p in trend) {
      expect(p.phase, inInclusiveRange(1, 4));
    }
    // The newest point is the reading the tiles show.
    expect(trend.last.heightCm, appState.rigReading!.heightCm);
    expect(trend.last.phase, appState.rigReading!.phase);
  });

  test('rows from before a long gap are left out, so old data cannot stretch the charts', () async {
    // The rig recorded an hour of readings two hours ago, was off, and is sending again now.
    final earlier = _rowsEndingAt(sourceRows, DateTime.now().subtract(const Duration(hours: 2)));
    final now = _rowsEndingAt(sourceRows, DateTime.now());
    final later = [
      for (var i = 0; i < now.length; i++)
        BenchSensorReading(
          id: earlier.length + i + 1,
          soil: now[i].soil,
          dist: now[i].dist,
          flow: now[i].flow,
          accelX: now[i].accelX,
          accelY: now[i].accelY,
          accelZ: now[i].accelZ,
          gyroX: now[i].gyroX,
          gyroY: now[i].gyroY,
          gyroZ: now[i].gyroZ,
          createdAt: now[i].createdAt,
        ),
    ];
    final service = _FakeService([...earlier, ...later])..served = earlier.length + later.length;
    final controller = controllerFor(service);
    appState.setRigMode(true);
    await controller.start();
    controller.stop();

    final trend = appState.rigTrend;
    expect(trend, isNotEmpty);
    final span = trend.last.time.difference(trend.first.time);
    expect(span, lessThanOrEqualTo(RigController.trendWindow));
    expect(DateTime.now().difference(trend.first.time), lessThan(const Duration(hours: 1)));
  });

  test('the chart history is cleared when live mode is switched off', () async {
    final service = _FakeService(rows)..served = rows.length;
    final controller = controllerFor(service);
    appState.setRigMode(true);
    await controller.start();
    controller.stop();
    expect(appState.rigTrend, isNotEmpty);
    appState.setRigMode(false);
    expect(appState.rigTrend, isEmpty);
  });

  test('turning live mode off returns the app to normal data', () async {
    final service = _FakeService(rows)..served = 120;
    final controller = controllerFor(service);
    appState.setRigMode(true);
    await controller.start();
    controller.stop();
    appState.setRigMode(false);
    expect(appState.rigMode, isFalse);
    expect(appState.demoMode, isFalse);
    expect(appState.rigReading, isNull);
  });
}
