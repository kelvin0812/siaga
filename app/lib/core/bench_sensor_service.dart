import 'dart:convert';
import 'package:http/http.dart' as http;

/// Reads live readings straight from Supabase's `sensor_table` -- the
/// bench-test rig (ESP32 + Pico + soil/ultrasonic/IMU, see docs/nexus-log.md)
/// that's separate from the real SIAGA node pipeline. Deliberately its own
/// small client rather than going through ApiClient/the FastAPI backend:
/// this table isn't part of the Section 5.3 REST surface, has no
/// node/guardrail/state-machine processing behind it, and reading it
/// directly (like photo_upload_service.dart's upload path) keeps that
/// boundary honest instead of pretending it's real node telemetry.
///
/// Read-only: the anon key here is scoped by sensor_table's RLS policies
/// to INSERT (the rig's own uploads) and SELECT, never UPDATE/DELETE.
class BenchSensorReading {
  final int id;
  final int? soil;
  final double? dist;
  final int? flow;
  final double? accelX;
  final double? accelY;
  final double? accelZ;
  final double? gyroX;
  final double? gyroY;
  final double? gyroZ;
  final DateTime createdAt;

  const BenchSensorReading({
    required this.id,
    required this.soil,
    required this.dist,
    required this.flow,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.createdAt,
  });

  factory BenchSensorReading.fromJson(Map<String, dynamic> json) {
    num? asNum(dynamic v) => v as num?;
    return BenchSensorReading(
      id: json['id'] as int,
      soil: asNum(json['soil'])?.toInt(),
      dist: asNum(json['dist'])?.toDouble(),
      flow: asNum(json['flow'])?.toInt(),
      accelX: asNum(json['accel_x'])?.toDouble(),
      accelY: asNum(json['accel_y'])?.toDouble(),
      accelZ: asNum(json['accel_z'])?.toDouble(),
      gyroX: asNum(json['gyro_x'])?.toDouble(),
      gyroY: asNum(json['gyro_y'])?.toDouble(),
      gyroZ: asNum(json['gyro_z'])?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class BenchSensorService {
  static const _baseUrl = 'https://oqsdoubmzzkfgcvvsbfb.supabase.co';
  static const _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9xc2RvdWJtenprZmdjdnZzYmZiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY2MzQxNTksImV4cCI6MjEwMjIxMDE1OX0.QizwV00qxMexZNUKVQ7V7LOCBBBNe3CfdzvBVohjOb8';

  final http.Client _client;
  BenchSensorService({http.Client? client}) : _client = client ?? http.Client();

  /// Most recent [limit] readings, newest first.
  Future<List<BenchSensorReading>> latest({int limit = 20}) async {
    final uri = Uri.parse(
      '$_baseUrl/rest/v1/sensor_table?select=*&order=created_at.desc&limit=$limit',
    );
    final res = await _client.get(uri, headers: {
      'apikey': _anonKey,
      'Authorization': 'Bearer $_anonKey',
    });
    if (res.statusCode != 200) {
      throw BenchSensorException('GET sensor_table failed: ${res.statusCode}');
    }
    final list = jsonDecode(res.body) as List;
    return list.map((e) => BenchSensorReading.fromJson(e as Map<String, dynamic>)).toList();
  }
}

class BenchSensorException implements Exception {
  final String message;
  BenchSensorException(this.message);
  @override
  String toString() => 'BenchSensorException: $message';
}
