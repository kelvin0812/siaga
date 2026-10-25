import 'dart:convert';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'population_service.dart';

class AssemblyPoint {
  final String id;
  final String nameEn;
  final String nameMs;
  final double lat;
  final double lon;

  /// Optional picture bundled with the app (an asset path, set as "photo" in assets/assembly_points.json).
  final String? photo;

  const AssemblyPoint({
    required this.id,
    required this.nameEn,
    required this.nameMs,
    required this.lat,
    required this.lon,
    this.photo,
  });

  factory AssemblyPoint.fromJson(Map<String, dynamic> json) => AssemblyPoint(
        id: json['id'] as String,
        nameEn: json['nameEn'] as String,
        nameMs: json['nameMs'] as String,
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        photo: json['photo'] as String?,
      );

  String nameFor(String languageCode) => languageCode == 'ms' ? nameMs : nameEn;
}

const _kCachedNodesKey = 'siaga.cached_nodes';
const _kCachedHazardsKey = 'siaga.cached_hazards';

/// Section 6.4: the app must stay useful with no data connection. This
/// wraps two different kinds of "offline data":
///  - assembly points: bundled with the app (see assets/assembly_points.json
///    — there's no backend endpoint for this), so
///    they're always available, connection or not.
///  - nodes/hazards: normally fetched live; every successful fetch is
///    mirrored here so the last known state is still shown when a later
///    fetch fails.
class OfflineCache {
  final SharedPreferences _prefs;
  final AssetBundle _bundle;

  /// [bundle] is where the bundled assembly points are read from: the app's own assets, unless a test supplies one.
  OfflineCache(this._prefs, {AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  /// The bundled population estimate for the areas SIAGA is shown in. It is part of the app, so it works offline.
  ///
  /// The file is read and decoded here rather than with loadString, which hands anything over 50 KB to a separate
  /// isolate. At 123 KB the decode takes a few milliseconds, and doing it here keeps loading simple and testable.
  Future<PopulationGrid> loadPopulation() async {
    final data = await _bundle.load('assets/population_h3.json');
    return PopulationGrid.fromJsonString(utf8.decode(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes)));
  }

  Future<List<AssemblyPoint>> loadAssemblyPoints() async {
    final raw = await _bundle.loadString('assets/assembly_points.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return (json['assemblyPoints'] as List)
        .map((e) => AssemblyPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Evacuation routes already fetched, kept so the same route can still be shown with no connection.
  String? loadRouteCache(String key) => _prefs.getString('siaga.route.$key');
  Future<void> saveRouteCache(String key, String value) => _prefs.setString('siaga.route.$key', value);

  Future<void> saveNodes(List<SiagaNode> nodes) async {
    await _prefs.setString(
      _kCachedNodesKey,
      jsonEncode(nodes.map((n) => n.toJson()).toList()),
    );
  }

  List<SiagaNode> loadCachedNodes() {
    final raw = _prefs.getString(_kCachedNodesKey);
    if (raw == null) return const [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => SiagaNode.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveHazards(List<Hazard> hazards) async {
    await _prefs.setString(
      _kCachedHazardsKey,
      jsonEncode(hazards.map((h) => h.toJson()).toList()),
    );
  }

  List<Hazard> loadCachedHazards() {
    final raw = _prefs.getString(_kCachedHazardsKey);
    if (raw == null) return const [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Hazard.fromJson(e as Map<String, dynamic>)).toList();
  }
}
