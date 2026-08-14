import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siaga_app/core/api_client.dart';
import 'package:siaga_app/core/app_state.dart';
import 'package:siaga_app/core/fcm_service.dart';
import 'package:siaga_app/core/h3_service.dart';
import 'package:siaga_app/core/location_service.dart';
import 'package:siaga_app/core/models.dart';
import 'package:siaga_app/core/offline_cache.dart';
import 'package:siaga_app/demo/demo_controller.dart';
import 'package:siaga_app/demo/hydrograph_generator.dart';

class FakeCellComputer implements CellComputer {
  @override
  String cellForPoint(double lat, double lon) => 'cellA';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppState appState;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    appState = AppState(
      api: ApiClient(),
      cache: OfflineCache(prefs),
      locationService: LocationService(
        h3Service: FakeCellComputer(),
        fcmService: FcmService(),
        prefs: prefs,
      ),
    );
  });

  test('generateHydrograph rises then recedes, matching the Python shape', () {
    const cfg = HydrographConfig(timeToPeakS: 600, recessionTauS: 900, totalDurationS: 3600);
    final points = generateHydrograph(cfg);
    expect(points, isNotEmpty);

    final depths = points.map((p) => p.depthMm).toList();
    final peakIndex = depths.indexOf(depths.reduce((a, b) => a > b ? a : b));

    for (var i = 1; i <= peakIndex; i++) {
      expect(depths[i], greaterThanOrEqualTo(depths[i - 1] - 1e-9));
    }
    for (var i = peakIndex + 1; i < depths.length; i++) {
      expect(depths[i], lessThanOrEqualTo(depths[i - 1] + 1e-9));
    }
  });

  test('demo run starts at NORMAL and reaches an alertable state', () {
    fakeAsync((async) {
      const cfg = HydrographConfig(timeToPeakS: 300, recessionTauS: 600, totalDurationS: 1800, sampleIntervalS: 60);
      final controller = DemoController(appState: appState, config: cfg);

      expect(appState.nodes, isEmpty);
      // start() ticks once synchronously (t=0, ratio=0) before arming the
      // periodic timer, so the first state is available immediately —
      // no fake-time elapse needed to observe it.
      controller.start(speed: 10000);
      expect(appState.nodes, isNotEmpty);
      expect(appState.nodes.first.state, RiskState.normal);

      // intervalMs is clamped to a 200ms floor regardless of how high
      // `speed` is (see DemoController.start), so don't assume `speed`
      // maps linearly onto elapsed wall time — just elapse generously
      // enough to consume the whole 30-point run (30 * 200ms = 6s).
      // AppState only ever holds the *current* node state, not a
      // history, and this is a rise-then-recession hydrograph — the
      // state passes through WARNING/EVACUATE and comes back down to
      // NORMAL by the end of the run, so checking only the final state
      // would miss it. Poll in small steps and OR the results.
      var reachedAlertable = false;
      for (var i = 0; i < 20; i++) {
        async.elapse(const Duration(milliseconds: 500));
        reachedAlertable |= appState.nodes.any((n) => n.state.isAlertable);
      }
      expect(reachedAlertable, isTrue, reason: 'demo hydrograph never reached WARNING/EVACUATE');
      expect(appState.nodes.first.state, RiskState.normal,
          reason: 'hydrograph should have receded back to NORMAL by the end of the run');

      controller.stop();
      expect(controller.isRunning, isFalse);
    });
  });

  test('stop() halts further ticks', () {
    fakeAsync((async) {
      const cfg = HydrographConfig(timeToPeakS: 300, recessionTauS: 600, totalDurationS: 1800, sampleIntervalS: 60);
      final controller = DemoController(appState: appState, config: cfg);
      controller.start(speed: 10000);
      async.elapse(const Duration(seconds: 1));

      controller.stop();
      final nodesAfterStop = appState.nodes;
      async.elapse(const Duration(minutes: 5));

      expect(appState.nodes, equals(nodesAfterStop));
    });
  });
}
