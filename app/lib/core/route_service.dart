import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'offline_cache.dart' show AssemblyPoint;

/// A walking route to one assembly point.
class RoutePlan {
  final AssemblyPoint assembly;

  /// The path, from where the routing started to the assembly point.
  final List<LatLng> points;
  final double distanceM;
  final double? durationS;

  /// False when no routing service could be reached: the path is then a straight line.
  final bool byRoad;

  /// True when the road route came from the copy saved on this phone, not a fresh request.
  final bool fromCache;

  const RoutePlan({
    required this.assembly,
    required this.points,
    required this.distanceM,
    required this.durationS,
    required this.byRoad,
    this.fromCache = false,
  });

  RoutePlan asCached() =>
      RoutePlan(assembly: assembly, points: points, distanceM: distanceM, durationS: durationS, byRoad: byRoad, fromCache: true);

  Map<String, dynamic> toJson() => {
        'id': assembly.id,
        'distance': distanceM,
        'duration': durationS,
        'points': [for (final p in points) [p.latitude, p.longitude]],
      };
}

/// Finds the shortest walking route from the person's area to an assembly point.
///
/// Privacy: the person's exact position never leaves the phone (build brief section 3.1), so it is NEVER sent to
/// the routing service. The request starts from a coarse point instead, the position rounded to a grid about 550 m
/// wide, which is about the size of the area cell the app already uses for alerts. Only that coarse start and the
/// assembly point (public data) are sent. The map draws a short connector from the true position to the start of
/// the route, locally.
///
/// Of the few nearest assembly points (by straight line) it asks the router for each and keeps the one with the
/// shortest road distance. With no connection it uses a route saved earlier, and failing that a straight line,
/// and says so.
class RouteService {
  /// The OpenStreetMap community's walking router: real footpaths and walking speed.
  static const baseUrl = 'https://routing.openstreetmap.de/routed-foot/route/v1/driving';
  static const gridDegrees = 0.005;

  final http.Client _client;
  final Duration timeout;
  final String? Function(String key)? readCache;
  final void Function(String key, String value)? writeCache;

  RouteService({http.Client? client, this.timeout = const Duration(seconds: 8), this.readCache, this.writeCache})
      : _client = client ?? http.Client();

  /// The point actually used to start the route: the given position rounded to the grid.
  static LatLng coarse(LatLng p) => LatLng(
        double.parse(((p.latitude / gridDegrees).round() * gridDegrees).toStringAsFixed(4)),
        double.parse(((p.longitude / gridDegrees).round() * gridDegrees).toStringAsFixed(4)),
      );

  static double straightMeters(LatLng a, LatLng b) => const Distance()(a, b);

  /// [only] asks for the route to one chosen assembly point instead of searching for the shortest.
  Future<RoutePlan?> shortest(LatLng origin, List<AssemblyPoint> points, {int candidates = 3, AssemblyPoint? only}) async {
    if (points.isEmpty) return null;
    final start = coarse(origin);
    final byStraight = [...points]
      ..sort((a, b) => straightMeters(start, LatLng(a.lat, a.lon)).compareTo(straightMeters(start, LatLng(b.lat, b.lon))));
    final tryThese = only != null ? [only] : byStraight.take(candidates).toList();

    final found = await Future.wait(tryThese.map((p) => _road(start, p)));
    final roads = found.whereType<RoutePlan>().toList()..sort((a, b) => a.distanceM.compareTo(b.distanceM));
    if (roads.isNotEmpty) return roads.first;

    final target = tryThese.first;
    final end = LatLng(target.lat, target.lon);
    return RoutePlan(
        assembly: target, points: [start, end], distanceM: straightMeters(start, end), durationS: null, byRoad: false);
  }

  String _key(LatLng start, AssemblyPoint p) => 'evac:${start.latitude.toStringAsFixed(3)},${start.longitude.toStringAsFixed(3)}:${p.id}';

  Future<RoutePlan?> _road(LatLng start, AssemblyPoint p) async {
    final fresh = await _fetch(start, p);
    if (fresh != null) {
      writeCache?.call(_key(start, p), jsonEncode(fresh.toJson()));
      return fresh;
    }
    return _saved(start, p);
  }

  Future<RoutePlan?> _fetch(LatLng start, AssemblyPoint p) async {
    final uri = Uri.parse('$baseUrl/${start.longitude},${start.latitude};${p.lon},${p.lat}?overview=full&geometries=geojson');
    try {
      final res = await _client.get(uri).timeout(timeout);
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['code'] != 'Ok') return null;
      final route = (body['routes'] as List).first as Map<String, dynamic>;
      final coords = ((route['geometry'] as Map<String, dynamic>)['coordinates'] as List)
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      if (coords.length < 2) return null;
      return RoutePlan(
        assembly: p,
        points: coords,
        distanceM: (route['distance'] as num).toDouble(),
        durationS: (route['duration'] as num?)?.toDouble(),
        byRoad: true,
      );
    } catch (_) {
      return null; // offline, slow, or an answer we do not understand: the caller falls back
    }
  }

  RoutePlan? _saved(LatLng start, AssemblyPoint p) {
    final raw = readCache?.call(_key(start, p));
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final pts = [for (final c in j['points'] as List) LatLng((c[0] as num).toDouble(), (c[1] as num).toDouble())];
      if (pts.length < 2) return null;
      return RoutePlan(
        assembly: p,
        points: pts,
        distanceM: (j['distance'] as num).toDouble(),
        durationS: (j['duration'] as num?)?.toDouble(),
        byRoad: true,
        fromCache: true,
      );
    } catch (_) {
      return null;
    }
  }
}
