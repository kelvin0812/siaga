import 'package:geolocator/geolocator.dart';
import 'app_state.dart';
import 'models.dart';

/// The node the app is "about" right now: the one picked from the list or the map, else (in a demo) the first one, else the node nearest to the phone. A pick that no longer
/// exists falls back to the default. My Risk and Merang both use this, so they always talk about the same node.
SiagaNode? focusedNodeFor(AppState app) {
  final nodes = app.nodes;
  final picked = app.lockedNodeId == null ? null : nodes.where((n) => n.id == app.lockedNodeId).firstOrNull;
  if (app.demoMode) {
    final waitingForRig = app.rigMode && app.rigReading == null && picked == null;
    return waitingForRig ? null : (picked ?? nodes.firstOrNull);
  }
  return picked ?? _nearestNode(app);
}

SiagaNode? _nearestNode(AppState app) {
  if (app.nodes.isEmpty) return null;
  final position = app.locationService.lastKnownPosition;
  if (position == null) return app.nodes.first;
  return app.nodes.reduce((a, b) {
    final da = Geolocator.distanceBetween(position.latitude, position.longitude, a.lat, a.lon);
    final db = Geolocator.distanceBetween(position.latitude, position.longitude, b.lat, b.lon);
    return da <= db ? a : b;
  });
}
