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
  RiskState get myRiskState {
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
      unawaited(refresh());
    }
    notifyListeners();
  }

  /// Demo mode (Section 6.4) pushes state directly rather than going
  /// through refresh()'s network path.
  void applyDemoState({required List<SiagaNode> nodes, required List<Hazard> hazards}) {
    this.nodes = nodes;
    activeHazards = hazards;
    isOffline = false;
    notifyListeners();
  }
}
