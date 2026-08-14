import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siaga_app/core/api_client.dart';
import 'package:siaga_app/core/app_state.dart';
import 'package:siaga_app/core/fcm_service.dart';
import 'package:siaga_app/core/h3_service.dart';
import 'package:siaga_app/core/locale_provider.dart';
import 'package:siaga_app/core/location_service.dart';
import 'package:siaga_app/core/offline_cache.dart';
import 'package:siaga_app/demo/demo_controller.dart';
import 'package:siaga_app/main.dart';

class FakeCellComputer implements CellComputer {
  @override
  String cellForPoint(double lat, double lon) => 'cellA';
}

/// A LocationService whose permission flow hangs forever — this
/// reproduces exactly what a browser's geolocation prompt does with no
/// one present to click it, or what a native permission dialog does if
/// the user just never responds. Used to prove data loading doesn't wait
/// on it (main.dart's _startup regression, see docs/nexus-log.md).
class HangingLocationService extends LocationService {
  HangingLocationService({required super.h3Service, required super.fcmService, required super.prefs});

  @override
  Future<LocationPermissionOutcome> requestPermissionAndStart() => Completer<LocationPermissionOutcome>().future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'node/hazard data loads even when location permission never resolves',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/nodes')) {
          return http.Response(
            jsonEncode([
              {
                'id': 1,
                'name': 'Test Node',
                'lat': 4.85,
                'lon': 100.74,
                'state': 'NORMAL',
                'last_seen': null,
                'battery': null,
              },
            ]),
            200,
          );
        }
        if (request.url.path.endsWith('/hazards/active')) {
          return http.Response(jsonEncode([]), 200);
        }
        return http.Response('not found', 404);
      });

      final apiClient = ApiClient(client: mockClient);
      final locationService = HangingLocationService(
        h3Service: FakeCellComputer(),
        fcmService: FcmService(),
        prefs: prefs,
      );
      final appState = AppState(
        api: apiClient,
        cache: OfflineCache(prefs),
        locationService: locationService,
      );
      final demoController = DemoController(appState: appState);
      final fcmService = FcmService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: appState),
            ChangeNotifierProvider(create: (_) => LocaleProvider(prefs)),
            Provider.value(value: demoController),
            Provider.value(value: fcmService),
          ],
          child: SiagaApp(fcmService: fcmService),
        ),
      );

      // Let post-frame callbacks (which call _startup) and the mocked
      // HTTP round-trip settle. pumpAndSettle would hang forever here
      // precisely because HangingLocationService's future never
      // completes — that's the scenario under test, not a flake to
      // avoid, so pump a bounded duration instead.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(appState.nodes, isNotEmpty);
      expect(appState.nodes.first.name, 'Test Node');
      expect(appState.isOffline, isFalse);

      // The app itself must have rendered past startup, not be stuck on
      // an error or blank screen.
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
