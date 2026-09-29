import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/offline_cache.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../widgets/demo_readout.dart';
import '../widgets/node_history_chart.dart';
import '../widgets/risk_badge.dart';

/// Section 6.4: live map of nodes with state colour-coding and node
/// detail. Tapping a node opens a draggable panel over the map (not a
/// separate page via Navigator) so the map and the analysis stay visible
/// together — drag the handle to expand/minimize it, same idea as a
/// typical maps app's place card. Also shows the user's own device
/// location as a distinct marker (Position values come from
/// LocationService.positionUpdates and are rendered locally only — never
/// forwarded anywhere; Section 3.1 still applies to this screen).
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  Position? _myPosition;
  int? _selectedNodeId;
  List<AssemblyPoint> _assemblyPoints = const [];
  bool _showEvacRoute = false;

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    final locationService = appState.locationService;
    _myPosition = locationService.lastKnownPosition;
    locationService.positionUpdates.listen((position) {
      if (mounted) setState(() => _myPosition = position);
    });
    appState.cache.loadAssemblyPoints().then((points) {
      if (mounted) setState(() => _assemblyPoints = points);
    });
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Nodes and assembly points that match the search box, as a single
  /// ranked list — mentor feedback asked for one place to find "a nearby
  /// node or assembly point" rather than two separate searches.
  List<_SearchResult> _searchResults() {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final appState = context.read<AppState>();
    final results = <_SearchResult>[
      ...appState.nodes.where((n) => n.name.toLowerCase().contains(q)).map(
            (n) => _SearchResult(
              label: n.name,
              point: ll.LatLng(n.lat, n.lon),
              isNode: true,
              nodeId: n.id,
            ),
          ),
      ..._assemblyPoints
          .where((p) => p.nameEn.toLowerCase().contains(q) || p.nameMs.toLowerCase().contains(q))
          .map(
            (p) => _SearchResult(
              label: p.nameFor(Localizations.localeOf(context).languageCode),
              point: ll.LatLng(p.lat, p.lon),
              isNode: false,
              nodeId: null,
            ),
          ),
    ];
    return results;
  }

  void _selectSearchResult(_SearchResult result) {
    _mapController.move(result.point, 15);
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() => _selectedNodeId = result.nodeId);
  }

  /// Where to route FROM: the device's own position when known, else — in
  /// demo mode, where there's no real GPS fix to rely on — the simulated
  /// node's own location, since that's the point the demo is illustrating
  /// as "at risk." Returns null (no route to draw) rather than guessing
  /// when neither is available.
  ll.LatLng? _evacuationOrigin(AppState appState) {
    if (_myPosition != null) return ll.LatLng(_myPosition!.latitude, _myPosition!.longitude);
    if (appState.demoMode && appState.nodes.isNotEmpty) {
      final node = appState.nodes.first;
      return ll.LatLng(node.lat, node.lon);
    }
    return null;
  }

  AssemblyPoint? _nearestAssemblyPoint(ll.LatLng from) {
    if (_assemblyPoints.isEmpty) return null;
    AssemblyPoint nearest = _assemblyPoints.first;
    var bestDistance = double.infinity;
    for (final point in _assemblyPoints) {
      final distance = Geolocator.distanceBetween(from.latitude, from.longitude, point.lat, point.lon);
      if (distance < bestDistance) {
        bestDistance = distance;
        nearest = point;
      }
    }
    return nearest;
  }

  void _showMyLocationInfo(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.read<AppState>();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.my_location, color: Color(0xFF3D8BFF)),
                const SizedBox(width: 8),
                Text(l10n.myLocationTitle, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(
              label: l10n.myLocationRiskLabel,
              valueWidget: RiskBadge(state: appState.myRiskState),
            ),
            if (appState.currentCellId != null)
              _InfoRow(label: l10n.myLocationCellLabel, value: appState.currentCellId!),
            if (_myPosition != null)
              _InfoRow(
                label: l10n.myLocationUpdatedLabel,
                value: TimeOfDay.fromDateTime(_myPosition!.timestamp).format(context),
              ),
            const SizedBox(height: 12),
            Text(
              l10n.myLocationPrivacyNote,
              style: const TextStyle(color: Color(0xFF97A2B8), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final nodes = appState.nodes;

    final center = _myPosition != null
        ? ll.LatLng(_myPosition!.latitude, _myPosition!.longitude)
        : nodes.isNotEmpty
            ? ll.LatLng(nodes.first.lat, nodes.first.lon)
            : const ll.LatLng(4.85, 100.74); // Taiping, Perak — demo default

    final selectedNode =
        _selectedNodeId == null ? null : nodes.where((n) => n.id == _selectedNodeId).firstOrNull;
    // If the selected node vanished (e.g. demo mode turned off), close
    // the panel instead of showing stale/empty content.
    if (_selectedNodeId != null && selectedNode == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedNodeId = null);
      });
    }

    final origin = _evacuationOrigin(appState);
    final nearestAssembly = origin != null ? _nearestAssemblyPoint(origin) : null;
    final routeActive = _showEvacRoute && origin != null && nearestAssembly != null;

    final searchResults = _searchResults();

    return Stack(
      children: [
        Column(
          children: [
            if (appState.isOffline) const _OfflineBanner(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.hairline, width: 1.5),
                  ),
                  child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(initialCenter: center, initialZoom: 13),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.siaga.siaga_app',
                  ),
                  if (routeActive)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [origin, ll.LatLng(nearestAssembly.lat, nearestAssembly.lon)],
                          color: AppColors.accent,
                          strokeWidth: 4,
                          pattern: const StrokePattern.dotted(),
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      ...nodes.map(
                        (node) => Marker(
                          point: ll.LatLng(node.lat, node.lon),
                          width: 40,
                          height: 40,
                          child: _NodeMarker(
                            node: node,
                            onTap: () => setState(() => _selectedNodeId = node.id),
                          ),
                        ),
                      ),
                      ..._assemblyPoints.map(
                        (point) => Marker(
                          point: ll.LatLng(point.lat, point.lon),
                          width: 34,
                          height: 34,
                          child: _AssemblyPointMarker(
                            point: point,
                            highlighted: routeActive && point.id == nearestAssembly.id,
                          ),
                        ),
                      ),
                      if (_myPosition != null)
                        Marker(
                          point: ll.LatLng(_myPosition!.latitude, _myPosition!.longitude),
                          width: 54,
                          height: 54,
                          child: _MyLocationMarker(onTap: () => _showMyLocationInfo(context)),
                        ),
                    ],
                  ),
                ],
                  ),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          top: (appState.isOffline ? 44 : 12) + 10,
          left: 22,
          right: 22,
          child: _MapSearchBar(
            controller: _searchController,
            focusNode: _searchFocusNode,
            results: searchResults,
            onResultTap: _selectSearchResult,
          ),
        ),
        if (origin != null && _assemblyPoints.isNotEmpty)
          Positioned(
            top: (appState.isOffline ? 44 : 12) + 68,
            right: 22,
            child: _EvacRouteToggle(
              active: _showEvacRoute,
              onTap: () => setState(() => _showEvacRoute = !_showEvacRoute),
            ),
          ),
        if (routeActive)
          Positioned(
            left: 12,
            right: 12,
            // Clears the floating nav dock (68px tall + its own 12px
            // bottom margin, see main.dart's _FloatingNavBar) rather than
            // sitting directly above the screen edge, where it would end
            // up underneath the dock instead of visible above it.
            bottom: 92,
            child: _EvacRouteSummary(assemblyPoint: nearestAssembly, distanceM: Geolocator.distanceBetween(
              origin.latitude, origin.longitude, nearestAssembly.lat, nearestAssembly.lon,
            )),
          ),
        if (selectedNode != null)
          _NodeInfoPanel(
            node: selectedNode,
            demoReading: appState.demoMode ? appState.demoReading : null,
            onClose: () => setState(() => _selectedNodeId = null),
            locked: appState.lockedNodeId == selectedNode.id,
            onToggleLock: () => appState.setLockedNode(
              appState.lockedNodeId == selectedNode.id ? null : selectedNode.id,
            ),
          ),
      ],
    );
  }
}

class _SearchResult {
  final String label;
  final ll.LatLng point;
  final bool isNode;
  final int? nodeId;
  const _SearchResult({required this.label, required this.point, required this.isNode, required this.nodeId});
}

/// Floating search field over the map (mentor feedback: let a resident find
/// a nearby node or assembly point without hunting across the map by eye).
/// Results render as a dropdown directly beneath the field; tapping one
/// pans the map there and, for a node, opens its info panel.
class _MapSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<_SearchResult> results;
  final ValueChanged<_SearchResult> onResultTap;

  const _MapSearchBar({
    required this.controller,
    required this.focusNode,
    required this.results,
    required this.onResultTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Gated on text alone, not focus: focus is lost on pointer-DOWN when a
    // result is tapped, which — if this were gated on hasFocus — removes
    // the list from the tree before the tap's onTap ever fires, so the tap
    // silently does nothing. Clearing the controller in _selectSearchResult
    // is what actually dismisses the list after a real selection.
    final showDropdown = controller.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.hairline),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              hintText: l10n.mapSearchHint,
              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
                      onPressed: () => controller.clear(),
                    ),
            ),
          ),
        ),
        if (showDropdown) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.hairline),
              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
            ),
            child: results.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(l10n.mapSearchNoResults, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.hairline),
                    itemBuilder: (context, i) {
                      final r = results[i];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          r.isNode ? Icons.sensors : Icons.shield_outlined,
                          color: r.isNode ? AppColors.accent : AppColors.normal,
                          size: 18,
                        ),
                        title: Text(r.label, style: const TextStyle(color: Colors.white, fontSize: 13)),
                        onTap: () => onResultTap(r),
                      );
                    },
                  ),
          ),
        ],
      ],
    );
  }
}

/// Floating pill toggle for the evacuation-route overlay — deliberately
/// off by default so the map isn't cluttered with a route line when
/// nothing is wrong; Section 6.4 asks for cached routes to be available,
/// not necessarily always drawn.
class _EvacRouteToggle extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _EvacRouteToggle({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.accent : Colors.black.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(999),
            boxShadow: active ? appGlow(AppColors.accent, alpha: 0.4, blur: 14) : const [BoxShadow(color: Colors.black45, blurRadius: 8)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(active ? Icons.directions_run : Icons.directions_outlined, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                l10n.evacuateViewRoute,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom summary strip shown while the route overlay is active — the
/// straight-line distance/direction to the nearest assembly point. Not
/// turn-by-turn navigation (no routing API is in scope — see
/// EvacuateScreen's _RouteInfo docstring), but enough to point someone
/// the right way and let them pre-plan before a real evacuation.
class _EvacRouteSummary extends StatelessWidget {
  final AssemblyPoint assemblyPoint;
  final double distanceM;
  const _EvacRouteSummary({required this.assemblyPoint, required this.distanceM});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final distanceLabel = distanceM >= 1000 ? '${(distanceM / 1000).toStringAsFixed(1)} km' : '${distanceM.round()} m';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: AppColors.accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.assemblyPointsTitle.toUpperCase(),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.6),
                ),
                const SizedBox(height: 2),
                Text(assemblyPoint.nameFor(locale), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Text(distanceLabel, style: AppFonts.mono(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }
}

class _AssemblyPointMarker extends StatelessWidget {
  final AssemblyPoint point;
  final bool highlighted;
  const _AssemblyPointMarker({required this.point, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final color = highlighted ? AppColors.accent : AppColors.normal;
    return Tooltip(
      message: point.nameFor(locale),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: highlighted ? appGlow(color, alpha: 0.6, blur: 12) : const [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
        child: const Icon(Icons.shield, color: Colors.white, size: 16),
      ),
    );
  }
}

/// Draggable bottom panel: starts small ("minimized"), can be dragged up
/// to "maximize" for the chart, closes via the X button. Sits in the same
/// Stack as the map rather than replacing it.
class _NodeInfoPanel extends StatelessWidget {
  final SiagaNode node;
  final DemoReading? demoReading;
  final VoidCallback onClose;
  final bool locked;
  final VoidCallback onToggleLock;

  const _NodeInfoPanel({
    required this.node,
    required this.demoReading,
    required this.onClose,
    required this.locked,
    required this.onToggleLock,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DraggableScrollableSheet(
      key: ValueKey(node.id),
      initialChildSize: 0.22,
      minChildSize: 0.12,
      maxChildSize: 0.7,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(node.name, style: Theme.of(context).textTheme.titleLarge),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: onClose),
                ],
              ),
              Row(
                children: [
                  RiskBadge(state: node.state),
                  if (node.riskProbability != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${(node.riskProbability! * 100).round()}%',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700, color: riskStateColor(node.state)),
                    ),
                  ],
                  const SizedBox(width: 12),
                  if (node.batteryVolts != null)
                    Text('${l10n.nodeBattery}: ${node.batteryVolts!.toStringAsFixed(2)}V'),
                ],
              ),
              if (node.lastSeen != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${l10n.nodeLastSeen}: ${node.lastSeen}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: onToggleLock,
                    icon: Icon(locked ? Icons.lock : Icons.lock_open_outlined, size: 16),
                    label: Text(locked ? l10n.mapUnlockNode : l10n.mapLockNode),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: locked ? AppColors.accent : AppColors.textSecondary,
                      backgroundColor: locked ? AppColors.accent.withValues(alpha: 0.14) : null,
                      side: BorderSide(color: locked ? AppColors.accent : AppColors.hairline),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                    ),
                  ),
                  if (locked) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.mapLockedHint,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.place_outlined, size: 14, color: const Color(0xFF97A2B8)),
                  const SizedBox(width: 4),
                  Text(
                    '${l10n.nodeGpsLabel}: ${node.lat.toStringAsFixed(5)}, ${node.lon.toStringAsFixed(5)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (demoReading != null) ...[
                DemoReadout(reading: demoReading!),
              ] else ...[
                Text(l10n.nodeHistoryTitle, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SizedBox(height: 220, child: NodeHistoryChart(nodeId: node.id)),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Deliberately more prominent than a node marker (larger, pulsing halo,
/// distinct blue) — this is "where you are," the one marker on the map
/// that always matters most to the person looking at it.
class _MyLocationMarker extends StatefulWidget {
  final VoidCallback onTap;
  const _MyLocationMarker({required this.onTap});

  @override
  State<_MyLocationMarker> createState() => _MyLocationMarkerState();
}

class _MyLocationMarkerState extends State<_MyLocationMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: widget.onTap,
      child: Tooltip(
        message: l10n.myLocationTapHint,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final pulse = _controller.value;
            return Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: (1 - pulse).clamp(0.0, 1.0),
                  child: Container(
                    width: 24 + pulse * 30,
                    height: 24 + pulse * 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3D8BFF).withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                child!,
              ],
            );
          },
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF3D8BFF),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;
  const _InfoRow({required this.label, this.value, this.valueWidget});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          valueWidget ?? Text(value ?? '', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _NodeMarker extends StatelessWidget {
  final SiagaNode node;
  final VoidCallback onTap;
  const _NodeMarker({required this.node, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: node.name,
        child: Container(
          decoration: BoxDecoration(
            color: riskStateColor(node.state),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
          child: const Icon(Icons.sensors, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      color: const Color(0xFF1A2338),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        l10n.offlineBanner,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
