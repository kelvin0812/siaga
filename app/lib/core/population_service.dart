import 'dart:convert';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// How crowded an area is, from people per square kilometre.
enum DensityClass { sparse, low, medium, high }

/// One hexagon of the population grid (an H3 cell at resolution 8, the same cells SIAGA uses to address alerts) with
/// an estimate of how many people live in it.
class PopulationCell {
  final String h3;
  final int people;
  final List<LatLng> vertices;
  final LatLng center;
  final double areaKm2;

  const PopulationCell._(this.h3, this.people, this.vertices, this.center, this.areaKm2);

  factory PopulationCell.fromJson(Map<String, dynamic> json) {
    final flat = (json['v'] as List).map((e) => (e as num).toDouble()).toList();
    final vertices = [for (var i = 0; i + 1 < flat.length; i += 2) LatLng(flat[i], flat[i + 1])];
    var lat = 0.0, lon = 0.0;
    for (final v in vertices) {
      lat += v.latitude;
      lon += v.longitude;
    }
    final center = LatLng(lat / vertices.length, lon / vertices.length);
    return PopulationCell._(json['h'] as String, (json['p'] as num).toInt(), vertices, center, _areaKm2(vertices, center.latitude));
  }

  double get density => areaKm2 > 0 ? people / areaKm2 : 0;

  /// Shoelace area on a flat projection around the cell; the cells are about a kilometre across, so this is accurate
  /// to well under a percent.
  static double _areaKm2(List<LatLng> v, double lat0) {
    final kx = 111.320 * math.cos(lat0 * math.pi / 180);
    const ky = 110.574;
    var sum = 0.0;
    for (var i = 0; i < v.length; i++) {
      final j = (i + 1) % v.length;
      sum += (v[i].longitude * kx) * (v[j].latitude * ky) - (v[j].longitude * kx) * (v[i].latitude * ky);
    }
    return sum.abs() / 2;
  }

  bool contains(LatLng p) {
    var inside = false;
    for (var i = 0, j = vertices.length - 1; i < vertices.length; j = i++) {
      final a = vertices[i], b = vertices[j];
      if ((a.latitude > p.latitude) != (b.latitude > p.latitude) &&
          p.longitude < (b.longitude - a.longitude) * (p.latitude - a.latitude) / (b.latitude - a.latitude) + a.longitude) {
        inside = !inside;
      }
    }
    return inside;
  }
}

/// Estimated population for the places SIAGA is shown in, kept on the phone so it works with no connection.
///
/// The data is Kontur Population (H3 resolution 8, modelled from satellite-derived building and settlement data,
/// CC BY 4.0). It is an estimate: good for telling a crowded area from an empty one and for ballpark counts, not for
/// head counts.
class PopulationGrid {
  /// People per square kilometre at which an area counts as low, medium and high. Below [lowFrom] an area is shown
  /// as sparse (forest, farmland, water) and left uncoloured.
  static const lowFrom = 150.0;
  static const mediumFrom = 1000.0;
  static const highFrom = 4000.0;

  final String source;
  final String license;
  final List<PopulationCell> cells;

  const PopulationGrid({required this.source, required this.license, required this.cells});

  factory PopulationGrid.fromJsonString(String text) {
    final json = jsonDecode(text) as Map<String, dynamic>;
    return PopulationGrid(
      source: json['source'] as String,
      license: json['license'] as String,
      cells: [for (final c in json['cells'] as List) PopulationCell.fromJson(c as Map<String, dynamic>)],
    );
  }

  static DensityClass classOfDensity(double perKm2) {
    if (perKm2 >= highFrom) return DensityClass.high;
    if (perKm2 >= mediumFrom) return DensityClass.medium;
    if (perKm2 >= lowFrom) return DensityClass.low;
    return DensityClass.sparse;
  }

  DensityClass classOf(PopulationCell c) => classOfDensity(c.density);

  static double _km(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(a.latitude * math.pi / 180) * math.cos(b.latitude * math.pi / 180) * math.pow(math.sin(dLon / 2), 2);
    return 2 * r * math.asin(math.min(1, math.sqrt(h)));
  }

  /// The hexagon a point is in, or null when the point is outside the area this grid covers.
  PopulationCell? cellAt(LatLng p) {
    for (final c in cells) {
      if (_km(p, c.center) < 1.3 && c.contains(p)) return c;
    }
    return null;
  }

  /// Whether the grid has anything near this point at all.
  bool covers(LatLng p) => cells.any((c) => _km(p, c.center) < 2.0);

  /// About how many people live within [radiusKm] of a point. A hexagon counts in full when it lies well inside the
  /// radius, not at all when it lies well outside, and in proportion in between (the cells are about a kilometre
  /// across), so the estimate changes smoothly as the radius or the point moves.
  int peopleWithin(LatLng center, double radiusKm) {
    const half = 0.5; // about half a cell's width, in km
    var total = 0.0;
    for (final c in cells) {
      final d = _km(center, c.center);
      final w = ((radiusKm + half - d) / (2 * half)).clamp(0.0, 1.0);
      if (w > 0) total += c.people * w;
    }
    return total.round();
  }

  /// A figure to show a person: rounded, because the estimate is not exact to the person.
  static int roundForDisplay(int people) {
    if (people >= 1000) return (people / 100).round() * 100;
    if (people >= 100) return (people / 10).round() * 10;
    return people;
  }
}
