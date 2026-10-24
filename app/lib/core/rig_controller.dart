import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;
import '../demo/demo_controller.dart' show alertCopyFor;
import 'app_state.dart';
import 'bench_sensor_service.dart';
import 'models.dart';
import 'phase_model.dart';

/// Live rig mode: reads the bench rig's real sensor rows from Supabase, runs the phase model on them in the
/// app, and pushes the result into AppState so the existing screens (risk level, map, evacuation alert) show it.
///
/// It starts by replaying the most recent rows to fill the model's windows, then polls for new ones. If the rig
/// stops sending, the last phase stays on screen but is marked stale (RigReading.isStale), so old data is never
/// passed off as current.
class RigController {
  final AppState appState;
  final BenchSensorService service;
  final Future<String> Function() loadModelJson;
  final Duration pollInterval;
  final int nodeId;
  final String nodeName;
  final double nodeLat;
  final double nodeLon;

  RigController({
    required this.appState,
    BenchSensorService? service,
    Future<String> Function()? loadModelJson,
    this.pollInterval = const Duration(seconds: 3),
    this.nodeId = 998,
    this.nodeName = 'Bench rig (live)',
    // Same river fix the demo node uses, so the rig appears on the map with the other nodes.
    this.nodeLat = 4.8189,
    this.nodeLon = 100.7289,
  })  : service = service ?? BenchSensorService(),
        loadModelJson = loadModelJson ?? (() => rootBundle.loadString('assets/phase_model.json'));

  PhaseModel? _model;
  PhasePredictor? _predictor;
  Timer? _timer;
  bool _running = false;
  bool _busy = false;
  int _lastId = 0;
  PhaseResult? _last;
  BenchSensorReading? _lastRow;

  static const _pageSize = 200;

  bool get isRunning => _running;

  Future<void> start() async {
    stop();
    _running = true;
    _model ??= PhaseModel.fromJsonString(await loadModelJson());
    if (!_running) return; // switched off while the model was loading
    _predictor = _model!.newPredictor();
    _lastId = 0;
    _last = null;
    _lastRow = null;
    try {
      for (final row in await service.history()) {
        _feed(row);
      }
    } catch (_) {
      // Offline or Supabase unreachable: the screens show "waiting" and the next poll tries again.
    }
    if (!_running) return;
    _publish();
    _timer = Timer.periodic(pollInterval, (_) => poll());
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Fetch anything new and update the screens. Public so tests can drive it without a timer.
  Future<void> poll() async {
    if (_busy || !_running) return;
    _busy = true;
    try {
      // Fetch in pages until caught up, so a long gap (phone asleep, Wi-Fi drop) is replayed at once.
      for (var page = 0; page < 20; page++) {
        final rows = await service.since(_lastId, limit: _pageSize);
        for (final row in rows) {
          _feed(row);
        }
        if (rows.length < _pageSize) break;
      }
    } catch (_) {
      // keep the last state; it goes stale on its own if the rig or network stays away
    } finally {
      _busy = false;
    }
    if (_running) _publish();
  }

  void _feed(BenchSensorReading row) {
    if (row.id > _lastId) _lastId = row.id;
    final predictor = _predictor;
    if (predictor == null ||
        row.dist == null ||
        row.flow == null ||
        row.soil == null ||
        row.accelX == null ||
        row.accelY == null ||
        row.accelZ == null ||
        row.gyroX == null ||
        row.gyroY == null ||
        row.gyroZ == null) {
      return;
    }
    final result = predictor.update(
      tSeconds: row.createdAt.millisecondsSinceEpoch / 1000.0,
      dist: row.dist!,
      flow: row.flow!.toDouble(),
      soil: row.soil!.toDouble(),
      accel: [row.accelX!, row.accelY!, row.accelZ!],
      gyro: [row.gyroX!, row.gyroY!, row.gyroZ!],
    );
    if (result != null) {
      _last = result;
      _lastRow = row;
    }
  }

  void _publish() {
    final result = _last;
    final row = _lastRow;
    if (result == null || row == null) {
      appState.applyRigState(nodes: const [], hazards: const [], reading: null);
      return;
    }
    // If the rig has gone quiet, what we have is old. Showing an old EVACUATE as a live emergency would be a
    // false alarm, and showing it as safe would be false comfort, so no alert is raised and the state falls
    // back to Normal with no severity figure. The last phase stays visible, marked as last known, in
    // RigReading.
    final stale = DateTime.now().difference(row.createdAt) > const Duration(seconds: 30);
    final state = stale ? RiskState.normal : RiskState.values[result.phase - 1];
    final node = SiagaNode(
      id: nodeId,
      name: nodeName,
      lat: nodeLat,
      lon: nodeLon,
      state: state,
      lastSeen: row.createdAt,
      batteryVolts: null,
      riskProbability: stale ? null : result.severity,
    );
    final hazards = <Hazard>[];
    if (state.isAlertable) {
      final cellId = appState.currentCellId;
      final copy = alertCopyFor(state);
      hazards.add(Hazard(
        id: 1,
        state: state,
        cells: cellId != null ? [cellId] : [],
        issuedAt: DateTime.now(),
        messageEn: copy.$1,
        messageMs: copy.$2,
      ));
    }
    appState.applyRigState(
      nodes: [node],
      hazards: hazards,
      reading: RigReading(
        phase: result.phase,
        confidence: result.confidence,
        severity: result.severity,
        heightCm: result.features.heightCm,
        flow: result.features.flowMed,
        soilRaw: result.features.soilMed,
        tiltDeg: result.features.tiltDeg,
        rowTime: row.createdAt,
        rowId: row.id,
      ),
    );
  }
}
