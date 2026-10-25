import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:siaga_app/core/population_service.dart';

/// A regular hexagon (about 0.6 km from centre to corner, so about 0.94 km2) around a point, in the file's format.
Map<String, dynamic> _hex(String id, double lat, double lon, int people) {
  final v = <double>[];
  for (var i = 0; i < 6; i++) {
    final a = math.pi / 3 * i;
    v.add(lat + 0.6 / 110.574 * math.sin(a));
    v.add(lon + 0.6 / (111.32 * math.cos(lat * math.pi / 180)) * math.cos(a));
  }
  return {'h': id, 'p': people, 'v': v};
}

PopulationGrid _grid(List<Map<String, dynamic>> cells) =>
    PopulationGrid.fromJsonString(jsonEncode({'source': 'test', 'license': 'test', 'resolution': 8, 'cells': cells}));

void main() {
  test('density is sorted into sparse, low, medium and high at the stated limits', () {
    expect(PopulationGrid.classOfDensity(0), DensityClass.sparse);
    expect(PopulationGrid.classOfDensity(149.9), DensityClass.sparse);
    expect(PopulationGrid.classOfDensity(150), DensityClass.low);
    expect(PopulationGrid.classOfDensity(999.9), DensityClass.low);
    expect(PopulationGrid.classOfDensity(1000), DensityClass.medium);
    expect(PopulationGrid.classOfDensity(3999.9), DensityClass.medium);
    expect(PopulationGrid.classOfDensity(4000), DensityClass.high);
    expect(PopulationGrid.classOfDensity(20000), DensityClass.high);
  });

  test('a cell\'s area and class come from its own shape and head count', () {
    final g = _grid([_hex('a', 3.0, 101.6, 50), _hex('b', 3.0, 101.7, 500), _hex('c', 3.0, 101.8, 2500), _hex('d', 3.0, 101.9, 9000)]);
    expect(g.cells.first.areaKm2, closeTo(0.935, 0.02));
    expect(g.cells.map(g.classOf).toList(), [DensityClass.sparse, DensityClass.low, DensityClass.medium, DensityClass.high]);
  });

  test('a point is found in the hexagon it sits in, and nowhere outside the covered area', () {
    final g = _grid([_hex('a', 3.0, 101.6, 1000), _hex('b', 3.0, 101.62, 4000)]);
    expect(g.cellAt(const LatLng(3.0, 101.6))!.h3, 'a');
    expect(g.cellAt(const LatLng(3.0, 101.621))!.h3, 'b');
    expect(g.cellAt(const LatLng(3.5, 101.6)), isNull);
    expect(g.covers(const LatLng(3.0, 101.6)), isTrue);
    expect(g.covers(const LatLng(5.0, 101.6)), isFalse);
  });

  test('the estimate within a distance grows with the distance and never exceeds the total', () {
    final g = _grid([
      _hex('a', 3.0, 101.60, 1000),
      _hex('b', 3.0, 101.61, 2000), // about 1.1 km east
      _hex('c', 3.0, 101.65, 4000), // about 5.5 km east
    ]);
    const here = LatLng(3.0, 101.60);
    final small = g.peopleWithin(here, 0.2);
    final one = g.peopleWithin(here, 1.0);
    final big = g.peopleWithin(here, 10);
    expect(small, lessThan(one));
    expect(one, lessThan(big));
    expect(big, 7000); // everything is inside 10 km
    expect(g.peopleWithin(here, 1.0), greaterThan(1000)); // its own cell, plus part of the neighbour
    expect(g.peopleWithin(here, 1.0), lessThan(3000)); // but not the far one
    expect(g.peopleWithin(const LatLng(9, 9), 5), 0);
  });

  test('figures shown to people are rounded, since the estimate is not exact', () {
    expect(PopulationGrid.roundForDisplay(7146), 7100);
    expect(PopulationGrid.roundForDisplay(1049), 1000);
    expect(PopulationGrid.roundForDisplay(386), 390);
    expect(PopulationGrid.roundForDisplay(42), 42);
  });

  group('the bundled data', () {
    late PopulationGrid grid;
    setUpAll(() => grid = PopulationGrid.fromJsonString(File('assets/population_h3.json').readAsStringSync()));

    test('is well formed: whole hexagons of a sensible size, with a source and a licence', () {
      expect(grid.cells.length, greaterThan(800));
      expect(grid.source, contains('Kontur'));
      expect(grid.license, contains('CC BY 4.0'));
      for (final c in grid.cells) {
        expect(c.vertices.length, 6);
        expect(c.areaKm2, inInclusiveRange(0.4, 1.3));
        expect(c.people, greaterThanOrEqualTo(0));
      }
      expect(grid.cells.map((c) => c.h3).toSet().length, grid.cells.length); // no cell twice
    });

    test('shows low, medium and high areas', () {
      final counts = {for (final k in DensityClass.values) k: grid.cells.where((c) => grid.classOf(c) == k).length};
      for (final k in DensityClass.values) {
        expect(counts[k], greaterThan(10), reason: '$k');
      }
    });

    test('covers the competition venue and gives it a believable estimate', () {
      const venue = LatLng(2.92791, 101.64179); // MMU Cyberjaya
      expect(grid.covers(venue), isTrue);
      final cell = grid.cellAt(venue)!;
      expect(grid.classOf(cell), anyOf(DensityClass.medium, DensityClass.high)); // a campus and housing, not forest
      final near = grid.peopleWithin(venue, 1.0);
      expect(near, inInclusiveRange(3000, 15000));
      expect(grid.peopleWithin(venue, 2.0), greaterThan(near));
    });

    test('also covers Taiping, where the earlier demo ran', () {
      expect(grid.covers(const LatLng(4.8189, 100.7289)), isTrue);
    });
  });
}
