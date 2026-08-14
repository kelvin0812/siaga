import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'fcm_service.dart';
import 'h3_service.dart';

const _kCellPrefKey = 'siaga.current_cell_id';

enum LocationPermissionOutcome { granted, denied, deniedForever, serviceDisabled }

/// Owns the app's one and only path from device location to a subscribed
/// topic (build brief Section 3.1). Recomputes and resubscribes ONLY when
/// the resolution-8 cell actually changes — this is both the battery-
/// conservation requirement in Section 6.4 and, not incidentally, the
/// reason there's no continuous coordinate stream anywhere else in the
/// app to accidentally leak: this class holds the only Position values
/// that ever exist, and only a cell ID string escapes it.
class LocationService {
  final CellComputer _h3;
  final FcmService _fcm;
  final SharedPreferences _prefs;
  final ApiClient? _apiClient;

  String? _currentCellId;
  Position? _lastKnownPosition;
  StreamSubscription<Position>? _positionSubscription;
  final _cellController = StreamController<String>.broadcast();
  final _positionController = StreamController<Position>.broadcast();

  LocationService({
    required CellComputer h3Service,
    required FcmService fcmService,
    required SharedPreferences prefs,
    ApiClient? apiClient,
  })  : _h3 = h3Service,
        _fcm = fcmService,
        _prefs = prefs,
        _apiClient = apiClient {
    _currentCellId = _prefs.getString(_kCellPrefKey);
  }

  /// The last cell computed, persisted across app restarts so the risk
  /// indicator has something to show before the first GPS fix lands.
  String? get currentCellId => _currentCellId;

  /// Raw device position — kept only in this device's memory, for local
  /// display only (e.g. distance/bearing to the nearest assembly point
  /// on the EVACUATE screen). Never persisted, never passed to ApiClient
  /// or any network call: Section 3.1 forbids raw location leaving the
  /// handset, and this getter is the one place a caller could violate
  /// that if they weren't careful, so treat it as radioactive.
  Position? get lastKnownPosition => _lastKnownPosition;

  Stream<String> get cellChanges => _cellController.stream;

  /// Every position update, not just cell-boundary crossings — for the
  /// map's "my location" marker, which needs to track smoothly rather
  /// than jump only when the H3 cell changes. Still device-local only:
  /// nothing subscribed to this stream may forward a Position anywhere
  /// off-device (see the class doc comment).
  Stream<Position> get positionUpdates => _positionController.stream;

  Future<LocationPermissionOutcome> requestPermissionAndStart() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationPermissionOutcome.serviceDisabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return LocationPermissionOutcome.denied;
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationPermissionOutcome.deniedForever;
    }

    // Re-arm the subscription for whatever cell we last knew about
    // before waiting on a fresh GPS fix, so alerts keep flowing across
    // an app restart.
    if (_currentCellId != null) {
      await _fcm.subscribeToCell(_currentCellId!);
    }

    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(distanceFilter: 50),
    ).listen(_onPosition);

    return LocationPermissionOutcome.granted;
  }

  @visibleForTesting
  Future<void> handlePosition(Position position) => _onPosition(position);

  Future<void> _onPosition(Position position) async {
    _lastKnownPosition = position;
    _positionController.add(position);
    final newCellId = _h3.cellForPoint(position.latitude, position.longitude);
    if (newCellId == _currentCellId) {
      return; // still inside the same cell — nothing to do
    }
    final oldCellId = _currentCellId;
    _currentCellId = newCellId;
    await _prefs.setString(_kCellPrefKey, newCellId);
    _cellController.add(newCellId);

    if (oldCellId != null) {
      await _fcm.unsubscribeFromCell(oldCellId);
      await _apiClient?.pingSubscription(oldCellId, -1).catchError((_) {});
    }
    await _fcm.subscribeToCell(newCellId);
    await _apiClient?.pingSubscription(newCellId, 1).catchError((_) {});
  }

  void dispose() {
    _positionSubscription?.cancel();
    _cellController.close();
    _positionController.close();
  }
}
