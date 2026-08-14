import 'dart:async';
import '../core/app_state.dart';
import '../core/models.dart';
import 'hydrograph_generator.dart';

/// Drives AppState from the synthetic hydrograph for the booth (Section
/// 6.4). Deliberately does NOT reimplement the backend's state machine
/// (state_machine.py) — dwell/hysteresis logic lives there and stays
/// there; this maps depth directly to a risk state via fixed thresholds,
/// which is honest about being a demo illustration, not a second
/// implementation of the real guardrail that could drift from it.
class DemoController {
  final AppState appState;
  final HydrographConfig config;
  final int demoNodeId;
  final String demoNodeName;
  final double demoNodeLat;
  final double demoNodeLon;

  Timer? _timer;
  int _index = 0;
  late final List<SimulatedPoint> _points;

  DemoController({
    required this.appState,
    this.config = const HydrographConfig(),
    this.demoNodeId = 999,
    this.demoNodeName = 'Demo Node',
    this.demoNodeLat = 4.8500,
    this.demoNodeLon = 100.7400,
  }) {
    _points = generateHydrograph(config);
  }

  bool get isRunning => _timer != null;

  /// speed=60 plays a 3h hydrograph in 3 minutes, matching
  /// shared/simulator.py's replay_realtime convention.
  void start({double speed = 60.0}) {
    stop();
    _index = 0;
    final intervalMs = (config.sampleIntervalS * 1000 / speed).round().clamp(200, 60000);
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (_) => _tick());
    _tick();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Instantly jumps to a representative point for the requested state,
  /// for live demos where waiting through the full hydrograph isn't
  /// practical (e.g. showing EVACUATE on demand in front of judges).
  /// Stops automatic playback — a manual jump is a deliberate override,
  /// not something the timer should immediately overwrite. Picks a real
  /// generated point that lands in that state rather than fabricating
  /// separate sensor values, so the readout stays internally consistent
  /// with the same hydrograph the automatic run uses.
  void jumpTo(RiskState target) {
    stop();
    final idx = _points.indexWhere((p) => _stateForDepth(p.depthMm) == target);
    if (idx == -1) return; // shouldn't happen with the default config's full rise+recession
    _index = idx + 1;
    _applyPoint(_points[idx]);
  }

  void _tick() {
    if (_index >= _points.length) {
      stop();
      return;
    }
    final point = _points[_index];
    _index++;
    _applyPoint(point);
  }

  void _applyPoint(SimulatedPoint point) {
    final state = _stateForDepth(point.depthMm);
    final node = SiagaNode(
      id: demoNodeId,
      name: demoNodeName,
      lat: demoNodeLat,
      lon: demoNodeLon,
      state: state,
      lastSeen: DateTime.now(),
      batteryVolts: point.vbatVolts,
    );

    final hazards = <Hazard>[];
    if (state.isAlertable) {
      final cellId = appState.currentCellId;
      final copy = _alertCopyFor(state);
      hazards.add(
        Hazard(
          id: 1,
          state: state,
          cells: cellId != null ? [cellId] : [],
          issuedAt: DateTime.now(),
          messageEn: copy.$1,
          messageMs: copy.$2,
        ),
      );
    }

    final reading = DemoReading(
      heightM: point.depthMm / 1000.0,
      soilPct: point.soilPct,
      tiltX: point.tiltX,
      tiltY: point.tiltY,
      tempC: point.tempC,
      rhPct: point.rhPct,
      batteryVolts: point.vbatVolts,
      rainTips: point.rainTips,
    );

    appState.applyDemoState(nodes: [node], hazards: hazards, reading: reading);
  }

  RiskState _stateForDepth(double depthMm) {
    final ratio =
        (depthMm - config.baselineDepthMm) / (config.peakDepthMm - config.baselineDepthMm);
    if (ratio >= 0.85) return RiskState.evacuate;
    if (ratio >= 0.55) return RiskState.warning;
    if (ratio >= 0.25) return RiskState.watch;
    return RiskState.normal;
  }

  /// Mirrors backend/app/fcm.py's alert templates, kept in sync by hand
  /// — the demo has no network path to the real backend to fetch these.
  (String, String) _alertCopyFor(RiskState state) {
    const attributionEn =
        'SIAGA advisory (decision support only) — confirm with NADMA / MetMalaysia / JPS.';
    const attributionMs =
        'Nasihat SIAGA (sokongan keputusan sahaja) — sahkan dengan NADMA / MetMalaysia / JPS.';
    if (state == RiskState.evacuate) {
      return (
        'EVACUATE NOW. Leave the area immediately and follow official guidance. $attributionEn',
        'BERPINDAH SEKARANG. Tinggalkan kawasan ini dengan segera dan ikut arahan rasmi. $attributionMs',
      );
    }
    return (
      'Flood/landslide risk rising in your area. Prepare to evacuate and review your route. $attributionEn',
      'Risiko banjir/tanah runtuh meningkat di kawasan anda. Bersedia untuk berpindah dan semak laluan anda. $attributionMs',
    );
  }
}
