import 'dart:math';

/// Dart port of shared/simulator.py's HydrographGenerator (Section 3.5 /
/// 6.4's demo mode: "drive the UI from the synthetic generator, for the
/// booth"). Same physical shape — smoothstep rise to peak, exponential
/// recession — kept in sync deliberately with the Python version so a
/// booth demo run "looks like" what the backend pipeline was tested
/// against. This produces UI-facing values directly (height, soil %,
/// etc.), not a 12-byte frame — the demo drives AppState, not a wire
/// protocol, so there's no frame codec step here.
class HydrographConfig {
  final double baselineDepthMm;
  final double peakDepthMm;
  final double riseStartS;
  final double timeToPeakS;
  final double recessionTauS;
  final double totalDurationS;
  final double sampleIntervalS;

  const HydrographConfig({
    this.baselineDepthMm = 200,
    this.peakDepthMm = 2600,
    this.riseStartS = 0,
    this.timeToPeakS = 3600,
    this.recessionTauS = 5400,
    this.totalDurationS = 3 * 3600,
    this.sampleIntervalS = 60,
  });
}

class SimulatedPoint {
  final double tS;
  final double depthMm;
  final int soilPct;
  final int tiltX;
  final int tiltY;

  const SimulatedPoint({
    required this.tS,
    required this.depthMm,
    required this.soilPct,
    required this.tiltX,
    required this.tiltY,
  });
}

double _smoothstep(double x) {
  x = x.clamp(0.0, 1.0);
  return x * x * (3.0 - 2.0 * x);
}

double _depthShape(double t, HydrographConfig cfg) {
  final tPeak = cfg.riseStartS + cfg.timeToPeakS;
  if (t <= cfg.riseStartS) return 0.0;
  if (t <= tPeak) return _smoothstep((t - cfg.riseStartS) / cfg.timeToPeakS);
  return exp(-(t - tPeak) / cfg.recessionTauS);
}

/// Generates the full point sequence for one hydrograph run. Kept as a
/// plain list rather than a lazy iterator/stream — a demo run is short
/// (a few hundred points at most) and the caller (DemoController) needs
/// to step through it under its own timer anyway.
List<SimulatedPoint> generateHydrograph(HydrographConfig cfg) {
  final points = <SimulatedPoint>[];
  var t = 0.0;
  var cumulativeRainProxy = 0.0;
  const soilBaselinePct = 35.0;
  const soilGainPerShapeUnit = 50.0; // simplified vs. the Python version's rain-driven model

  while (t <= cfg.totalDurationS) {
    final shape = _depthShape(t, cfg);
    final depthMm = cfg.baselineDepthMm + (cfg.peakDepthMm - cfg.baselineDepthMm) * shape;

    cumulativeRainProxy += shape * (cfg.sampleIntervalS / 3600.0);
    final soilPct = min(100.0, soilBaselinePct + soilGainPerShapeUnit * cumulativeRainProxy);
    final tiltDrift = (soilPct - soilBaselinePct) * 0.08;

    points.add(
      SimulatedPoint(
        tS: t,
        depthMm: depthMm,
        soilPct: soilPct.round().clamp(0, 100),
        tiltX: tiltDrift.round().clamp(-128, 127),
        tiltY: (tiltDrift * 0.4).round().clamp(-128, 127),
      ),
    );
    t += cfg.sampleIntervalS;
  }
  return points;
}
