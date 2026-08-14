import 'dart:async';
import 'package:flutter/material.dart';
import 'api_client.dart';
import 'models.dart';
import 'offline_cache.dart';
import 'location_service.dart';

/// App-wide state: the node/hazard data every screen reads, plus the
/// derived "risk level for my cell" the Section 6.4 indicator needs.
/// Falls back to cached data on any fetch failure (Section 2: degrade
/// visibly, never crash, when connectivity drops).
class AppState extends ChangeNotifier {
  final ApiClient api;
  final OfflineCache cache;
  final LocationService locationService;

  List<SiagaNode> nodes = [];
  List<Hazard> activeHazards = [];
  bool isOffline = false;
  bool demoMode = false;
  DemoReading? demoReading;

  AppState({
    required this.api,
    required this.cache,
    required this.locationService,
  }) {
    nodes = cache.loadCachedNodes();
    activeHazards = cache.loadCachedHazards();
    locationService.cellChanges.listen((_) => notifyListeners());
  }

  String? get currentCellId => locationService.currentCellId;

  /// The highest-severity active hazard whose cell list includes the
  /// user's current cell — NORMAL if none do, matching how the backend's
  /// state machine treats "nothing corroborated" (state_machine.py).
  ///
  /// In demo mode this instead reflects the demo node's state directly.
  /// The demo is meant to work at a booth with no real GPS fix — tying it
  /// to a real currentCellId meant demo hazards had an empty cells list
  /// whenever location permission wasn't granted, so this indicator
  /// silently never left NORMAL during a demo. There's exactly one demo
  /// node, standing in for "your area," so using its state directly is
  /// the correct fix, not a workaround.
  RiskState get myRiskState {
    if (demoMode) {
      return nodes.isEmpty ? RiskState.normal : nodes.first.state;
    }
    final cellId = currentCellId;
    if (cellId == null) return RiskState.normal;
    var highest = RiskState.normal;
    for (final hazard in activeHazards) {
      if (hazard.cells.contains(cellId) && hazard.state.index > highest.index) {
        highest = hazard.state;
      }
    }
    return highest;
  }

  Future<void> refresh() async {
    if (demoMode) return; // demo mode drives nodes/hazards itself
    try {
      final fetchedNodes = await api.getNodes();
      final fetchedHazards = await api.getActiveHazards();
      nodes = fetchedNodes;
      activeHazards = fetchedHazards;
      isOffline = false;
      await cache.saveNodes(nodes);
      await cache.saveHazards(activeHazards);
    } catch (_) {
      isOffline = true;
      // keep showing whatever's already in nodes/activeHazards (cached
      // or previously fetched) rather than clearing to empty
    }
    notifyListeners();
  }

  void setDemoMode(bool value) {
    demoMode = value;
    if (!value) {
      demoReading = null;
      unawaited(refresh());
    }
    notifyListeners();
  }

  /// Demo mode (Section 6.4) pushes state directly rather than going
  /// through refresh()'s network path.
  void applyDemoState({
    required List<SiagaNode> nodes,
    required List<Hazard> hazards,
    DemoReading? reading,
  }) {
    this.nodes = nodes;
    activeHazards = hazards;
    demoReading = reading;
    isOffline = false;
    notifyListeners();
  }
}
