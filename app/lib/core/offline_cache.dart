import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class AssemblyPoint {
  final String id;
  final String nameEn;
  final String nameMs;
  final double lat;
  final double lon;

  const AssemblyPoint({
    required this.id,
    required this.nameEn,
    required this.nameMs,
    required this.lat,
    required this.lon,
  });

  factory AssemblyPoint.fromJson(Map<String, dynamic> json) => AssemblyPoint(
        id: json['id'] as String,
        nameEn: json['nameEn'] as String,
        nameMs: json['nameMs'] as String,
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
      );

  String nameFor(String languageCode) => languageCode == 'ms' ? nameMs : nameEn;
}

const _kCachedNodesKey = 'siaga.cached_nodes';
const _kCachedHazardsKey = 'siaga.cached_hazards';

/// Section 6.4: the app must stay useful with no data connection. This
/// wraps two different kinds of "offline data":
///  - assembly points: bundled with the app (see assets/assembly_points.json
///    — there's no backend endpoint for this, see docs/nexus-log.md), so
///    they're always available, connection or not.
///  - nodes/hazards: normally fetched live; every successful fetch is
///    mirrored here so the last known state is still shown when a later
///    fetch fails.
class OfflineCache {
  final SharedPreferences _prefs;
  OfflineCache(this._prefs);

  Future<List<AssemblyPoint>> loadAssemblyPoints() async {
    final raw = await rootBundle.loadString('assets/assembly_points.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return (json['assemblyPoints'] as List)
        .map((e) => AssemblyPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

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
