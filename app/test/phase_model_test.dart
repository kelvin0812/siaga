import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:siaga_app/core/phase_model.dart';

/// Replays real rig rows through the Dart model and checks every number against what the Python predictor
/// (backend/app/phase_model.py) gave for the same rows. Regenerate the fixture with
/// `python -m ml.rig.export_app` whenever the model is retrained.
void main() {
  final model = PhaseModel.fromJsonString(File('assets/phase_model.json').readAsStringSync());
  final fixture = jsonDecode(File('test/fixtures/phase_fixture.json').readAsStringSync()) as Map<String, dynamic>;

  List<double> nums(dynamic l) => (l as List).map((e) => (e as num).toDouble()).toList();

  test('Dart model reproduces the Python predictor on real rig rows', () {
    var compared = 0;
    for (final c in fixture['cases'] as List) {
      final rows = c['rows'] as List;
      final expected = c['expected'] as List;
      final predictor = model.newPredictor();
      for (var i = 0; i < rows.length; i++) {
        final r = rows[i] as Map<String, dynamic>;
        final got = predictor.update(
          tSeconds: (r['t'] as num).toDouble(),
          dist: (r['dist'] as num).toDouble(),
          flow: (r['flow'] as num).toDouble(),
          soil: (r['soil'] as num).toDouble(),
          accel: nums(r['accel']),
          gyro: nums(r['gyro']),
        );
        final want = expected[i] as Map<String, dynamic>?;
        if (want == null) {
          expect(got, isNull, reason: 'row $i should still be warming up or be a dropout');
          continue;
        }
        expect(got, isNotNull, reason: 'row $i');
        expect(got!.phase, want['phase'], reason: 'smoothed phase, row $i');
        expect(got.rawPhase, want['raw'], reason: 'raw phase, row $i');
        final probs = nums(want['probs']);
        for (var k = 0; k < 4; k++) {
          expect(got.probabilities[k], closeTo(probs[k], 1e-9), reason: 'probability $k, row $i');
        }
        final f = want['features'] as Map<String, dynamic>;
        expect(got.features.heightCm, closeTo((f['height_cm'] as num).toDouble(), 1e-9));
        expect(got.features.rateCmMin, closeTo((f['rate_cm_min'] as num).toDouble(), 1e-9));
        expect(got.features.flowMed, closeTo((f['flow_med'] as num).toDouble(), 1e-9));
        expect(got.features.soilMed, closeTo((f['soil_med'] as num).toDouble(), 1e-9));
        expect(got.features.tiltDeg, closeTo((f['tilt_deg'] as num).toDouble(), 1e-9));
        expect(got.features.gyroPeak, closeTo((f['gyro_peak'] as num).toDouble(), 1e-9));
        compared++;
      }
    }
    expect(compared, greaterThan(400));
  });

  test('a distance of 0 (no echo) is skipped, not treated as a very high water level', () {
    final p = model.newPredictor();
    final r = p.update(tSeconds: 0, dist: 0, flow: 190, soil: 450, accel: [9.78, -0.5, 0.8], gyro: [0.13, -0.06, 0.01]);
    expect(r, isNull);
  });

  test('quiet rig reads Normal and high water reads Evacuate', () {
    final p = model.newPredictor();
    PhaseResult? r;
    for (var i = 0; i < 60; i++) {
      r = p.update(tSeconds: i * 3.0, dist: 30.9, flow: 190, soil: 454, accel: [9.78, -0.535, 0.84], gyro: [0.13, -0.06, 0.01]);
    }
    expect(r!.phase, 1);
    for (var i = 0; i < 60; i++) {
      r = p.update(tSeconds: 180 + i * 3.0, dist: 26.4, flow: 232, soil: 517, accel: [9.78, -0.535, 0.84], gyro: [0.13, -0.06, 0.01]);
    }
    expect(r!.phase, 4);
    expect(r.severity, greaterThan(0.5)); // clearly towards the Evacuate end of the 0 to 1 gauge
  });

  test('a different mounting height only needs a new baseline distance', () {
    final p = model.newPredictor(baselineDistCm: 40.0);
    PhaseResult? r;
    for (var i = 0; i < 60; i++) {
      r = p.update(tSeconds: i * 3.0, dist: 40.0, flow: 190, soil: 454, accel: [9.78, -0.535, 0.84], gyro: [0.13, -0.06, 0.01]);
    }
    expect(r!.phase, 1);
  });
}
