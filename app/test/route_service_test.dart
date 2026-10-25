import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:siaga_app/core/offline_cache.dart';
import 'package:siaga_app/core/route_service.dart';

AssemblyPoint _point(String id, double lat, double lon) =>
    AssemblyPoint(id: id, nameEn: 'Point $id', nameMs: 'Titik $id', lat: lat, lon: lon);

/// A router answer shaped like the real service's: GeoJSON coordinates are [longitude, latitude].
http.Response _ok(double meters, {double seconds = 600}) => http.Response(
      jsonEncode({
        'code': 'Ok',
        'routes': [
          {
            'distance': meters,
            'duration': seconds,
            'geometry': {
              'coordinates': [
                [100.73, 4.82],
                [100.735, 4.83],
                [100.74, 4.85],
              ],
            },
          },
        ],
      }),
      200,
    );

void main() {
  final origin = const LatLng(4.81893, 100.72891); // a person's exact position
  final near = _point('near', 4.82, 100.73);
  final mid = _point('mid', 4.84, 100.74);
  final far = _point('far', 4.90, 100.80);
  final farther = _point('farther', 5.00, 100.90);

  test('the request starts from a coarse point, never the exact position', () async {
    final urls = <String>[];
    final service = RouteService(client: MockClient((req) async {
      urls.add(req.url.toString());
      return _ok(1000);
    }));
    await service.shortest(origin, [near]);
    expect(urls, hasLength(1));
    expect(urls.single, isNot(contains('100.72891')));
    expect(urls.single, isNot(contains('4.81893')));
    expect(urls.single, contains('100.73,4.82;')); // the rounded start
    expect(RouteService.coarse(origin), const LatLng(4.82, 100.73));
  });

  test('of the nearest assembly points it keeps the one with the shortest road distance', () async {
    // "near" is closest in a straight line, but the road to it is long (a bridge is out).
    final service = RouteService(client: MockClient((req) async {
      final to = req.url.path.split(';').last;
      if (to.startsWith('100.73,4.82')) return _ok(5200); // near
      if (to.startsWith('100.74,4.84')) return _ok(1800); // mid
      return _ok(9000);
    }));
    final plan = await service.shortest(origin, [far, near, mid]);
    expect(plan!.assembly.id, 'mid');
    expect(plan.distanceM, 1800);
    expect(plan.byRoad, isTrue);
    expect(plan.points.length, greaterThan(2));
  });

  test('only the three nearest points are asked, not all of them', () async {
    var requests = 0;
    final service = RouteService(client: MockClient((req) async {
      requests++;
      return _ok(1000);
    }));
    await service.shortest(origin, [far, farther, near, mid]);
    expect(requests, 3);
  });

  test('a chosen assembly point is routed to directly', () async {
    final urls = <String>[];
    final service = RouteService(client: MockClient((req) async {
      urls.add(req.url.toString());
      return _ok(4000);
    }));
    final plan = await service.shortest(origin, [near, mid, far], only: far);
    expect(urls, hasLength(1));
    expect(plan!.assembly.id, 'far');
  });

  test('with no connection it uses a straight line and says it is not a road route', () async {
    final service = RouteService(client: MockClient((req) async => throw http.ClientException('offline')));
    final plan = await service.shortest(origin, [far, mid]);
    expect(plan!.byRoad, isFalse);
    expect(plan.assembly.id, 'mid'); // the nearest in a straight line
    expect(plan.durationS, isNull);
    expect(plan.points, hasLength(2));
    expect(plan.distanceM, greaterThan(0));
  });

  test('a router error or a no-route answer also falls back', () async {
    for (final res in [
      http.Response('server error', 500),
      http.Response(jsonEncode({'code': 'NoRoute'}), 200),
      http.Response('not json', 200),
      http.Response(jsonEncode({'code': 'Ok', 'routes': []}), 200),
    ]) {
      final plan = await RouteService(client: MockClient((req) async => res)).shortest(origin, [near]);
      expect(plan!.byRoad, isFalse, reason: res.body);
    }
  });

  test('a route saved earlier is used when the network is down', () async {
    final saved = <String, String>{};
    final online = RouteService(
      client: MockClient((req) async => _ok(2500)),
      readCache: (k) => saved[k],
      writeCache: (k, v) => saved[k] = v,
    );
    final first = await online.shortest(origin, [near]);
    expect(first!.fromCache, isFalse);
    expect(saved, isNotEmpty);

    final offline = RouteService(
      client: MockClient((req) async => throw http.ClientException('offline')),
      readCache: (k) => saved[k],
      writeCache: (k, v) => saved[k] = v,
    );
    final again = await offline.shortest(origin, [near]);
    expect(again!.byRoad, isTrue);
    expect(again.fromCache, isTrue);
    expect(again.distanceM, 2500);
    expect(again.points.length, first.points.length);
  });

  test('no assembly points means no plan', () async {
    expect(await RouteService(client: MockClient((req) async => _ok(1))).shortest(origin, const []), isNull);
  });
}
