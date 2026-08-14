import 'package:h3_flutter/h3_flutter.dart';

/// Fixed resolution the handset computes locally (build brief Section 3.1).
/// Must match backend/app/geofence.py's H3_RESOLUTION exactly, or the
/// app's topic subscriptions won't line up with what the backend publishes.
const int kH3Resolution = 8;

/// Narrow interface LocationService depends on, so its boundary-crossing
/// logic can be unit tested with a fake — h3_flutter's native binding
/// can't load under `flutter test` (no bundled host-platform binary; it's
/// built from source as part of a full app build), so H3Service itself
/// isn't unit-testable in this environment, but everything built on top
/// of it still should be.
abstract class CellComputer {
  String cellForPoint(double lat, double lon);
}

/// Wraps h3_flutter's native binding. This is the single point of contact
/// with the H3 library — the ONLY thing that ever leaves this class (and
/// this device) is a cell ID string. Raw coordinates never cross into
/// ApiClient or any network call; see location_service.dart for the
/// caller that enforces that boundary.
class H3Service implements CellComputer {
  final H3 _h3 = const H3Factory().load();

  /// Computes the resolution-8 cell for a point, as the same lowercase
  /// hex string format the backend uses (e.g. "8865050927fffff").
  @override
  String cellForPoint(double lat, double lon) {
    final index = _h3.geoToCell(GeoCoord(lat: lat, lon: lon), kH3Resolution);
    return index.toRadixString(16);
  }
}
