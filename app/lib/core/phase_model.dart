import 'dart:convert';
import 'dart:math' as math;

/// Runs the trained phase model on the phone: no server, so it works offline, on the web build and in the APK.
///
/// This is a Dart twin of backend/app/phase_model.py (live features) plus a small tree walker for the two
/// LightGBM models, exported by ml/rig/export_app.py into assets/phase_model.json. A test replays real rig
/// rows and checks every number against what the Python version gives, so the two cannot drift apart.
///
/// How the phase is decided: one model sees only the water level, another sees flow, soil and tilt, and the
/// two are blended with the water level weighted most. The phase shown is the most common answer of the last
/// few readings, so one noisy reading cannot flip it.

class _Tree {
  final List<int> f;
  final List<double> t;
  final List<int> l;
  final List<int> r;
  final List<double> v;
  _Tree(this.f, this.t, this.l, this.r, this.v);

  factory _Tree.fromJson(Map<String, dynamic> j) => _Tree(
        (j['f'] as List).cast<int>(),
        (j['t'] as List).map((e) => (e as num).toDouble()).toList(),
        (j['l'] as List).cast<int>(),
        (j['r'] as List).cast<int>(),
        (j['v'] as List).map((e) => (e as num).toDouble()).toList(),
      );

  /// Walk down the tree. A negative child is a leaf, with leaf index ~child.
  double eval(List<double> x) {
    if (f.isEmpty) return v[0];
    var n = 0;
    while (true) {
      final next = x[f[n]] <= t[n] ? l[n] : r[n];
      if (next < 0) return v[~next];
      n = next;
    }
  }
}

class _Forest {
  final int numClass;
  final List<_Tree> trees;
  _Forest(this.numClass, this.trees);

  factory _Forest.fromJson(Map<String, dynamic> j) => _Forest(
        j['num_class'] as int,
        (j['trees'] as List).map((e) => _Tree.fromJson(e as Map<String, dynamic>)).toList(),
      );

  /// Class probabilities: trees are interleaved by class, and the summed scores go through a softmax.
  List<double> predict(List<double> x) {
    final raw = List<double>.filled(numClass, 0);
    for (var i = 0; i < trees.length; i++) {
      raw[i % numClass] += trees[i].eval(x);
    }
    final m = raw.reduce(math.max);
    final e = raw.map((s) => math.exp(s - m)).toList();
    final sum = e.reduce((a, b) => a + b);
    return e.map((v) => v / sum).toList();
  }
}

class PhaseFeatures {
  final double heightCm;
  final double rateCmMin;
  final double flowMed;
  final double soilMed;
  final double tiltDeg;
  final double gyroPeak;
  const PhaseFeatures({
    required this.heightCm,
    required this.rateCmMin,
    required this.flowMed,
    required this.soilMed,
    required this.tiltDeg,
    required this.gyroPeak,
  });
}

class PhaseResult {
  /// 1 (Normal) to 4 (Evacuate), smoothed over the last readings.
  final int phase;

  /// The phase this single reading alone points to.
  final int rawPhase;
  final List<double> probabilities;
  final PhaseFeatures features;

  const PhaseResult({
    required this.phase,
    required this.rawPhase,
    required this.probabilities,
    required this.features,
  });

  /// 0.0 (certainly Normal) to 1.0 (certainly Evacuate): the expected phase, used for the severity gauge.
  double get severity {
    var s = 0.0;
    for (var i = 0; i < probabilities.length; i++) {
      s += probabilities[i] * i;
    }
    return s / (probabilities.length - 1);
  }

  /// Probability the blended model gives to the phase being shown.
  double get confidence => probabilities[phase - 1];
}

double _median(List<double> xs) {
  final s = List<double>.from(xs)..sort();
  final n = s.length;
  return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
}

/// The same trailing-window features as ml/rig/features.py, computed one reading at a time.
class PhaseStream {
  final double baselineDistCm;
  final List<double> restAccel;
  final List<double> gyroBias;

  final List<double> _dists = [];
  final List<double> _flows = [];
  final List<double> _soils = [];
  final List<double?> _levels = [];
  final List<double> _times = [];
  final List<double> _tilts = [];
  final List<double> _gyros = [];

  PhaseStream({required this.baselineDistCm, required this.restAccel, required this.gyroBias});

  static List<T> _tail<T>(List<T> xs, int n) => xs.length <= n ? xs : xs.sublist(xs.length - n);

  /// Returns null while the windows are still filling, and for a distance of 0 (the sensor heard no echo).
  PhaseFeatures? update({
    required double tSeconds,
    required double dist,
    required double flow,
    required double soil,
    required List<double> accel,
    required List<double> gyro,
  }) {
    if (dist <= 0) return null;
    _times.add(tSeconds);
    _dists.add(dist);
    _flows.add(flow);
    _soils.add(soil);
    final level = _dists.length >= 5 ? _median(_tail(_dists, 10)) : null;
    _levels.add(level);

    final restNorm = math.sqrt(restAccel.fold(0.0, (a, v) => a + v * v));
    final aNorm = math.sqrt(accel.fold(0.0, (a, v) => a + v * v));
    var dot = 0.0;
    for (var i = 0; i < 3; i++) {
      dot += accel[i] * restAccel[i];
    }
    final cos = (dot / (aNorm * restNorm)).clamp(-1.0, 1.0);
    _tilts.add(math.acos(cos) * 180 / math.pi);
    var g2 = 0.0;
    for (var i = 0; i < 3; i++) {
      final d = gyro[i] - gyroBias[i];
      g2 += d * d;
    }
    _gyros.add(math.sqrt(g2));

    double? rate;
    if (level != null && _levels.length > 20 && _levels[_levels.length - 21] != null) {
      final minutes = (tSeconds - _times[_times.length - 21]) / 60.0;
      rate = -(level - _levels[_levels.length - 21]!) / minutes;
    }
    final flowMed = _flows.length >= 5 ? _median(_tail(_flows, 10)) : null;
    final soilMed = _soils.length >= 5 ? _median(_tail(_soils, 10)) : null;
    final tilt = _tilts.length >= 3 ? _median(_tail(_tilts, 5)) : null;
    final gyroPeak = _gyros.length >= 3 ? _tail(_gyros, 10).reduce(math.max) : null;

    // Only the last ~21 readings are ever looked at, so a long session does not grow forever.
    for (final series in [_dists, _flows, _soils, _times, _tilts, _gyros]) {
      if (series.length > 40) series.removeRange(0, series.length - 40);
    }
    if (_levels.length > 40) _levels.removeRange(0, _levels.length - 40);

    if (level == null || rate == null || flowMed == null || soilMed == null || tilt == null || gyroPeak == null) {
      return null;
    }
    return PhaseFeatures(
      heightCm: baselineDistCm - level,
      rateCmMin: rate,
      flowMed: flowMed,
      soilMed: soilMed,
      tiltDeg: tilt,
      gyroPeak: gyroPeak,
    );
  }
}

class PhaseModel {
  final _Forest _level;
  final _Forest _others;
  final double levelWeight;
  final int smoothing;
  final double baselineDistCm;
  final List<double> restAccel;
  final List<double> gyroBias;

  PhaseModel._(this._level, this._others, this.levelWeight, this.smoothing, this.baselineDistCm, this.restAccel, this.gyroBias);

  /// [json] is the text of assets/phase_model.json.
  factory PhaseModel.fromJsonString(String json) {
    final j = jsonDecode(json) as Map<String, dynamic>;
    final cal = j['calibration'] as Map<String, dynamic>;
    List<double> nums(dynamic l) => (l as List).map((e) => (e as num).toDouble()).toList();
    return PhaseModel._(
      _Forest.fromJson(j['level'] as Map<String, dynamic>),
      _Forest.fromJson(j['others'] as Map<String, dynamic>),
      (j['level_weight'] as num).toDouble(),
      j['smoothing_readings'] as int,
      (cal['baseline_dist_cm'] as num).toDouble(),
      nums(cal['rest_accel']),
      nums(cal['gyro_bias']),
    );
  }

  /// A fresh predictor with its own history. Pass [baselineDistCm] if the sensor sits at a different height
  /// than when the model was trained: the distance read at the rig's normal water level.
  PhasePredictor newPredictor({double? baselineDistCm}) => PhasePredictor._(
        this,
        PhaseStream(baselineDistCm: baselineDistCm ?? this.baselineDistCm, restAccel: restAccel, gyroBias: gyroBias),
      );
}

class PhasePredictor {
  final PhaseModel _model;
  final PhaseStream _stream;
  final List<int> _recent = [];

  PhasePredictor._(this._model, this._stream);

  PhaseResult? update({
    required double tSeconds,
    required double dist,
    required double flow,
    required double soil,
    required List<double> accel,
    required List<double> gyro,
  }) {
    final f = _stream.update(tSeconds: tSeconds, dist: dist, flow: flow, soil: soil, accel: accel, gyro: gyro);
    if (f == null) return null;
    final pl = _model._level.predict([f.heightCm, f.rateCmMin]);
    final po = _model._others.predict([f.flowMed, f.soilMed, f.tiltDeg, f.gyroPeak]);
    final w = _model.levelWeight;
    final prob = List<double>.generate(4, (i) => w * pl[i] + (1 - w) * po[i]);
    var raw = 0;
    for (var i = 1; i < 4; i++) {
      if (prob[i] > prob[raw]) raw = i;
    }
    _recent.add(raw);
    if (_recent.length > 40) _recent.removeRange(0, _recent.length - 40);
    final window = _recent.length <= _model.smoothing ? _recent : _recent.sublist(_recent.length - _model.smoothing);
    var best = 0;
    var bestCount = -1;
    for (var p = 0; p < 4; p++) {
      final c = window.where((e) => e == p).length;
      if (c > bestCount) {
        best = p;
        bestCount = c; // ties go to the lower phase because it is only replaced by a strictly higher count
      }
    }
    return PhaseResult(phase: best + 1, rawPhase: raw + 1, probabilities: prob, features: f);
  }
}
