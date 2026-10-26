import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;
import '../demo/demo_controller.dart' show alertCopyFor;
import 'app_state.dart';
import 'bench_sensor_service.dart';
import 'models.dart';
import 'phase_model.dart';

/// Where the competition demo runs: the MMU Cyberjaya campus. The live rig sits here, and the map opens here.
const kVenueLat = 2.92791;
const kVenueLon = 101.64179;

/// The id of the live rig's node. The simulated demo nodes have other ids.
const kRigNodeId = 998;

/// A simulated neighbour of the live rig, so a demonstration shows a whole monitored area and an alert spreading
/// through it. Its level follows the rig's with its own lag or sensitivity ([phaseFor] maps the rig's phase, 1 to
/// 4, to this node's). It is never presented as real: SiagaNode.simulated is set and the app labels it a demo node.
class DemoNodeSpec {
  final int id;
  final String name;
  final double lat;
  final double lon;
  final int Function(int rigPhase) phaseFor;
  const DemoNodeSpec(this.id, this.name, this.lat, this.lon, this.phaseFor);
}

int _sameAsRig(int p) => p;
int _oneBehind(int p) => p > 1 ? p - 1 : 1;
int _onlyWhenSevere(int p) => p >= 3 ? 2 : 1;

/// Demonstration nodes around MMU Cyberjaya, where the competition demo is run. The places are real, the sensors are
/// not.
const kCyberjayaDemoNodes = <DemoNodeSpec>[
  DemoNodeSpec(991, 'Lake bank (demo)', 2.93775, 101.64303, _sameAsRig),
  DemoNodeSpec(992, 'Campus drain (demo)', 2.92680, 101.64050, _oneBehind),
  DemoNodeSpec(993, 'Road embankment (demo)', 2.92150, 101.64720, _onlyWhenSevere),
];

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
  final List<DemoNodeSpec> demoNodes;

  RigController({
    required this.appState,
    BenchSensorService? service,
    Future<String> Function()? loadModelJson,
    this.pollInterval = const Duration(seconds: 5), // the rig sends a reading about every 5 seconds
    this.nodeId = kRigNodeId,
    this.nodeName = 'Bench rig (live)',
    // MMU Cyberjaya, where the competition demo runs.
    this.demoNodes = kCyberjayaDemoNodes,
    this.nodeLat = kVenueLat,
    this.nodeLon = kVenueLon,
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

  /// The charts show the last 10 minutes, measured back from the newest reading. This is a time window, not a row
  /// count: after the rig has been off for hours, older rows must not stretch the chart. [trendLength] only
  /// bounds the memory used (10 minutes at 5 s apart is 120 readings).
  static const trendWindow = Duration(minutes: 10);
  static const trendLength = 250;
  final List<RigPoint> _trend = [];

  int? _override;
  final List<RigPoint> _simTrend = [];

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
    _trend.clear();
    try {
      // A little more than the chart keeps, because the first readings only warm the model's windows up.
      for (final row in await service.history(count: trendLength + 30)) {
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
    _override = null; // a forced phase never outlives the live rig mode
    _simTrend.clear();
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
      _trend.add(RigPoint(
        time: row.createdAt,
        heightCm: result.features.heightCm,
        flow: result.features.flowMed,
        soilRaw: result.features.soilMed,
        tiltDeg: result.features.tiltDeg,
        phase: result.phase,
      ));
      final oldest = row.createdAt.subtract(trendWindow);
      _trend.removeWhere((p) => p.time.isBefore(oldest));
      if (_trend.length > trendLength) _trend.removeRange(0, _trend.length - trendLength);
    }
  }

  /// The simulated neighbours. With no live phase (no data yet, or the rig gone quiet) they all read Normal.
  List<SiagaNode> _demoNodeList(int? rigPhase) => [
        for (final d in demoNodes)
          SiagaNode(
            id: d.id,
            name: d.name,
            lat: d.lat,
            lon: d.lon,
            state: rigPhase == null ? RiskState.normal : RiskState.values[d.phaseFor(rigPhase) - 1],
            lastSeen: null,
            batteryVolts: null,
            simulated: true,
          ),
      ];

  /// Forces the whole app to show one phase (1 Normal to 4 Evacuate), whatever the rig reads, so an alert can be
  /// rehearsed on demand at the booth. Null goes back to the rig's real readings. The readings shown while forced
  /// are typical values for that phase and are marked simulated everywhere they appear.
  void setOverride(int? phase) {
    assert(phase == null || (phase >= 1 && phase <= 4));
    _override = phase;
    _simTrend.clear();
    if (phase != null) {
      // Two points, so the charts have a line to draw from the first moment.
      final now = DateTime.now();
      _simTrend.add(_simPoint(phase, now.subtract(pollInterval)));
      _simTrend.add(_simPoint(phase, now));
    }
    if (_running) _publish();
  }

  /// The forced phase, or null when the app follows the rig.
  int? get overridePhase => _override;

  // Typical sensor values for each phase, by the model's own height bands (0.76, 2.18 and 3.63 cm).
  static const _simHeight = [0.2, 1.5, 2.9, 4.5];
  static const _simFlow = [0.0, 60.0, 140.0, 220.0];
  static const _simSoil = [600.0, 520.0, 450.0, 380.0]; // a lower raw value is wetter soil
  static const _simTilt = [0.2, 0.6, 1.2, 2.2];
  static const _simSeverity = [0.1, 0.4, 0.7, 0.95];

  RigPoint _simPoint(int phase, DateTime time) => RigPoint(
        time: time,
        heightCm: _simHeight[phase - 1],
        flow: _simFlow[phase - 1],
        soilRaw: _simSoil[phase - 1],
        tiltDeg: _simTilt[phase - 1],
        phase: phase,
      );

  void _publish() {
    final forced = _override;
    if (forced != null) {
      _publishForced(forced);
      return;
    }
    final result = _last;
    final row = _lastRow;
    if (result == null || row == null) {
      appState.applyRigState(nodes: _demoNodeList(null), hazards: const [], reading: null);
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
    appState.applyRigState(
      nodes: [node, ..._demoNodeList(stale ? null : result.phase)],
      hazards: _hazardsFor(state),
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
      trend: List.unmodifiable(_trend),
    );
  }

  List<Hazard> _hazardsFor(RiskState state) {
    if (!state.isAlertable) return const [];
    final cellId = appState.currentCellId;
    final copy = alertCopyFor(state);
    return [
      Hazard(
        id: 1,
        state: state,
        cells: cellId != null ? [cellId] : [],
        issuedAt: DateTime.now(),
        messageEn: copy.$1,
        messageMs: copy.$2,
      ),
    ];
  }

  /// What the app shows while a phase is forced: the rig's node and its demo neighbours at that phase, a fresh
  /// reading (so nothing reads as offline), and a chart that keeps drawing the phase's typical values.
  void _publishForced(int phase) {
    final now = DateTime.now();
    _simTrend.add(_simPoint(phase, now));
    _simTrend.removeWhere((p) => p.time.isBefore(now.subtract(trendWindow)));
    if (_simTrend.length > trendLength) _simTrend.removeRange(0, _simTrend.length - trendLength);
    final state = RiskState.values[phase - 1];
    appState.applyRigState(
      nodes: [
        SiagaNode(
          id: nodeId,
          name: nodeName,
          lat: nodeLat,
          lon: nodeLon,
          state: state,
          lastSeen: now,
          batteryVolts: null,
          riskProbability: _simSeverity[phase - 1],
        ),
        ..._demoNodeList(phase),
      ],
      hazards: _hazardsFor(state),
      reading: RigReading(
        phase: phase,
        confidence: 1,
        severity: _simSeverity[phase - 1],
        heightCm: _simHeight[phase - 1],
        flow: _simFlow[phase - 1],
        soilRaw: _simSoil[phase - 1],
        tiltDeg: _simTilt[phase - 1],
        rowTime: now,
        rowId: -1,
        simulated: true,
      ),
      trend: List.unmodifiable(_simTrend),
    );
  }
}
