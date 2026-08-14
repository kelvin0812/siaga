import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

/// Thin wrapper over the Section 5.3 REST API. Every method returns null
/// (never throws past this layer) on network failure — callers decide how
/// to degrade (Section 2: the app must stay useful with no connection).
class ApiClient {
  final String baseUrl;
  final http.Client _client;

  ApiClient({this.baseUrl = 'https://siaga-nine.vercel.app/api/v1', http.Client? client})
      : _client = client ?? http.Client();

  Future<List<SiagaNode>> getNodes() async {
    final res = await _client.get(Uri.parse('$baseUrl/nodes'));
    if (res.statusCode != 200) {
      throw ApiException('GET /nodes failed: ${res.statusCode}');
    }
    final list = jsonDecode(res.body) as List;
    return list.map((e) => SiagaNode.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<NodeReading>> getNodeHistory(int nodeId, {int hours = 24}) async {
    final res = await _client
        .get(Uri.parse('$baseUrl/nodes/$nodeId/history?hours=$hours'));
    if (res.statusCode != 200) {
      throw ApiException('GET /nodes/$nodeId/history failed: ${res.statusCode}');
    }
    final list = jsonDecode(res.body) as List;
    return list.map((e) => NodeReading.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Hazard>> getActiveHazards() async {
    final res = await _client.get(Uri.parse('$baseUrl/hazards/active'));
    if (res.statusCode != 200) {
      throw ApiException('GET /hazards/active failed: ${res.statusCode}');
    }
    final list = jsonDecode(res.body) as List;
    return list.map((e) => Hazard.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Submits a community hazard report. cell_id only, per Section 3.1/5.3
  /// — the caller must never pass raw coordinates here.
  Future<int> submitReport({
    required String cellId,
    required String category,
    String? note,
    String? photoUrl,
  }) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/reports'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'cell_id': cellId,
        'category': category,
        if (note != null && note.isNotEmpty) 'note': note,
        if (photoUrl != null) 'photo_url': photoUrl,
      }),
    );
    if (res.statusCode != 200) {
      throw ApiException('POST /reports failed: ${res.statusCode}');
    }
    return (jsonDecode(res.body) as Map<String, dynamic>)['id'] as int;
  }

  /// Delta is +1 on subscribe, -1 on unsubscribe. This is the endpoint
  /// that exists purely because FCM has no subscriber-count API — see
  /// docs/nexus-log.md.
  Future<void> pingSubscription(String cellId, int delta) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/subscriptions/ping'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'cell_id': cellId, 'delta': delta}),
    );
    if (res.statusCode != 204) {
      throw ApiException('POST /subscriptions/ping failed: ${res.statusCode}');
    }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => 'ApiException: $message';
}
