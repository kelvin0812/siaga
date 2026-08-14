/// Domain models mirroring the backend REST API (build brief Section 5.3).
/// Field names and shapes intentionally match backend/app/api.py's Pydantic
/// response models so decoding stays a straight 1:1 mapping.
library;

/// Four-level risk state (Section 5.4). Ordered by severity so `>`/`<`
/// comparisons on the enum index work the same way the backend's
/// RiskState IntEnum does.
enum RiskState {
  normal,
  watch,
  warning,
  evacuate;

  static RiskState fromApi(String value) {
    switch (value) {
      case 'NORMAL':
        return RiskState.normal;
      case 'WATCH':
        return RiskState.watch;
      case 'WARNING':
        return RiskState.warning;
      case 'EVACUATE':
        return RiskState.evacuate;
      default:
        throw ArgumentError('unknown risk state: $value');
    }
  }

  String toApi() => name.toUpperCase();

  bool get isAlertable => this == RiskState.warning || this == RiskState.evacuate;
}

class SiagaNode {
  final int id;
  final String name;
  final double lat;
  final double lon;
  final RiskState state;
  final DateTime? lastSeen;
  final double? batteryVolts;

  const SiagaNode({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.state,
    required this.lastSeen,
    required this.batteryVolts,
  });

  factory SiagaNode.fromJson(Map<String, dynamic> json) => SiagaNode(
        id: json['id'] as int,
        name: json['name'] as String,
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        state: RiskState.fromApi(json['state'] as String),
        lastSeen: json['last_seen'] == null
            ? null
            : DateTime.parse(json['last_seen'] as String),
        batteryVolts: (json['battery'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': lat,
        'lon': lon,
        'state': state.toApi(),
        'last_seen': lastSeen?.toIso8601String(),
        'battery': batteryVolts,
      };
}

class NodeReading {
  final DateTime receivedAt;
  final double heightM;
  final int levelMm;
  final int tiltX;
  final int tiltY;
  final int soilPct;
  final int rainTips;
  final int tempC;
  final int rhPct;
  final double batteryVolts;
  final int flags;

  const NodeReading({
    required this.receivedAt,
    required this.heightM,
    required this.levelMm,
    required this.tiltX,
    required this.tiltY,
    required this.soilPct,
    required this.rainTips,
    required this.tempC,
    required this.rhPct,
    required this.batteryVolts,
    required this.flags,
  });

  factory NodeReading.fromJson(Map<String, dynamic> json) => NodeReading(
        receivedAt: DateTime.parse(json['received_at'] as String),
        heightM: (json['height_m'] as num).toDouble(),
        levelMm: json['level_mm'] as int,
        tiltX: json['tilt_x'] as int,
        tiltY: json['tilt_y'] as int,
        soilPct: json['soil_pct'] as int,
        rainTips: json['rain_tips'] as int,
        tempC: json['temp_c'] as int,
        rhPct: json['rh_pct'] as int,
        batteryVolts: (json['battery'] as num).toDouble(),
        flags: json['flags'] as int,
      );
}

class Hazard {
  final int id;
  final RiskState state;
  final List<String> cells;
  final DateTime issuedAt;
  final String messageEn;
  final String messageMs;

  const Hazard({
    required this.id,
    required this.state,
    required this.cells,
    required this.issuedAt,
    required this.messageEn,
    required this.messageMs,
  });

  factory Hazard.fromJson(Map<String, dynamic> json) => Hazard(
        id: json['id'] as int,
        state: RiskState.fromApi(json['state'] as String),
        cells: (json['cells'] as List).cast<String>(),
        issuedAt: DateTime.parse(json['issued_at'] as String),
        messageEn: json['message_en'] as String,
        messageMs: json['message_ms'] as String,
      );

  /// Picks the message for the given app locale, falling back to English
  /// for anything that isn't Bahasa Malaysia (Section 6.4: BM + English
  /// at minimum).
  String messageFor(String languageCode) =>
      languageCode == 'ms' ? messageMs : messageEn;

  Map<String, dynamic> toJson() => {
        'id': id,
        'state': state.toApi(),
        'cells': cells,
        'issued_at': issuedAt.toIso8601String(),
        'message_en': messageEn,
        'message_ms': messageMs,
      };
}

/// Live simulated sensor values for demo mode's readout (Section 6.4's
/// demo mode, made concrete with actual numbers rather than just a risk
/// badge). Fields mirror what the real node transmits (Section 5.1) —
/// deliberately no "pressure" field, since the wire frame doesn't carry
/// one either (BME280 can sense it, but only temp_c and rh_pct are ever
/// transmitted), so this stays honest about what the real hardware
/// actually reports.
class DemoReading {
  final double heightM;
  final int soilPct;
  final int tiltX;
  final int tiltY;
  final double tempC;
  final double rhPct;
  final double batteryVolts;
  final int rainTips;

  const DemoReading({
    required this.heightM,
    required this.soilPct,
    required this.tiltX,
    required this.tiltY,
    required this.tempC,
    required this.rhPct,
    required this.batteryVolts,
    required this.rainTips,
  });
}
