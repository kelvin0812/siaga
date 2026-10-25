import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/offline_cache.dart';
import '../core/rig_controller.dart' show kVenueLat, kVenueLon;
import '../core/population_service.dart';
import '../core/route_service.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../widgets/demo_readout.dart';
import '../widgets/rig_trend_card.dart';
import '../widgets/status_message.dart';
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

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  Position? _myPosition;
  int? _selectedNodeId;
  List<AssemblyPoint> _assemblyPoints = const [];
  bool _showEvacRoute = false;

  // The shortest walking route to an assembly point, planned by RouteService. It is planned again only when the
  // start area or the chosen destination changes. _chosen is an assembly point the person picked by hand.
  late final RouteService _routes;
  RoutePlan? _plan;
  bool _planning = false;
  String? _planKey;
  AssemblyPoint? _chosen;
  double _zoom = 13;
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  /// The marker the floating place card is about: "n:" and a node id, or "a:" and an assembly point id.
  String? _focusKey;

  // The population layer: an estimate of how many people live in each hexagon, drawn as high, medium and low areas.
  PopulationGrid? _population;
  List<Polygon> _popPolygons = const [];
  bool _showPopulation = false;

  /// Eases the camera towards a tapped marker, a little at a time, instead of jumping.
  late final AnimationController _fly;
  VoidCallback? _flyListener;

  /// Drives the motion along the route: arrows flowing towards the destination and a pulse travelling the line.
  late final AnimationController _flow;

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fly = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _flow = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));
    final appState = context.read<AppState>();
    final locationService = appState.locationService;
    _routes = RouteService(
      readCache: appState.cache.loadRouteCache,
      writeCache: (key, value) => unawaited(appState.cache.saveRouteCache(key, value)),
    );
    _myPosition = locationService.lastKnownPosition;
    locationService.positionUpdates.listen((position) {
      if (mounted) setState(() => _myPosition = position);
    });
    appState.cache.loadPopulation().then((grid) {
      if (mounted) {
        setState(() {
          _population = grid;
          _popPolygons = _populationPolygons(grid);
        });
      }
    }).catchError((Object _) {
      // The population layer is optional: without its data the map simply has no such layer.
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
    _flow.dispose();
    _fly.dispose();
    _sheetController.dispose();
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
              assemblyId: null,
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
              assemblyId: p.id,
            ),
          ),
    ];
    return results;
  }

  void _selectSearchResult(_SearchResult result) {
    _searchController.clear();
    _searchFocusNode.unfocus();
    final appState = context.read<AppState>();
    if (result.isNode) {
      final node = appState.nodes.where((n) => n.id == result.nodeId).firstOrNull;
      if (node != null) _focusNode(node);
    } else {
      final point = _assemblyPoints.where((p) => p.id == result.assemblyId).firstOrNull;
      if (point != null) _focusAssembly(point);
    }
  }

  void _focusNode(SiagaNode node) {
    setState(() {
      _focusKey = 'n:${node.id}';
      _selectedNodeId = null; // the card comes first; "Details and trends" opens the full panel
    });
    _flyTo(ll.LatLng(node.lat, node.lon));
  }

  void _focusAssembly(AssemblyPoint point) {
    setState(() {
      _focusKey = 'a:${point.id}';
      _selectedNodeId = null;
    });
    _flyTo(ll.LatLng(point.lat, point.lon));
  }

  /// Zooms in a little (to about street level, never closer than needed) and puts the point in the upper part of the
  /// map, clear of the place card that opens along the bottom.
  void _flyTo(ll.LatLng point) {
    final MapCamera cam;
    try {
      cam = _mapController.camera;
    } catch (_) {
      _mapController.move(point, 15.5);
      return;
    }
    final zoom = cam.zoom < 15 ? 15.5 : cam.zoom;
    final end = CameraFit.coordinates(
      coordinates: [point],
      // The card is about 430 px tall and sits above the nav bar, so the node goes in the clear space above the card
      // (and below the search bar), however tall the screen is.
      padding: EdgeInsets.fromLTRB(40, 70, 40, cam.nonRotatedSize.height - math.max(cam.nonRotatedSize.height - 92 - 430 - 30, 110.0)),
      minZoom: zoom,
      maxZoom: zoom,
    ).fit(cam);
    final from = cam.center;
    final fromZoom = cam.zoom;
    if (_flyListener != null) _fly.removeListener(_flyListener!);
    _flyListener = () {
      final t = Curves.easeInOutCubic.transform(_fly.value);
      _mapController.move(
        ll.LatLng(
          from.latitude + (end.center.latitude - from.latitude) * t,
          from.longitude + (end.center.longitude - from.longitude) * t,
        ),
        fromZoom + (end.zoom - fromZoom) * t,
      );
    };
    _fly.addListener(_flyListener!);
    _fly.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _zoom = end.zoom); // label placement depends on the final zoom
    });
  }

  /// Decides, for every marker, whether its label sits below, above, or is left out, so that no label covers another
  /// label or any marker. Markers are placed in order of importance: the one in focus, you, sensor nodes, the route's
  /// destination, then the other assembly points. A marker that is left without a label is still tappable.
  Map<String, _LabelSlot> _placeLabels(List<_Pin> pins, List<Rect> obstacles) {
    final MapCamera camera;
    try {
      camera = _mapController.camera;
    } catch (_) {
      return {for (final p in pins) p.id: p.wantLabel ? _LabelSlot.below : _LabelSlot.hidden};
    }
    final centers = {for (final p in pins) p.id: camera.latLngToScreenOffset(p.point)};
    final iconRects = [
      for (final p in pins) Rect.fromCenter(center: centers[p.id]!, width: p.iconSize + 6, height: p.iconSize + 6),
    ];
    final placed = <Rect>[];
    final out = <String, _LabelSlot>{};
    const labelH = 36.0;
    bool free(Rect r) => !iconRects.any((i) => i.overlaps(r)) && !obstacles.any((o) => o.overlaps(r)) && !placed.any((l) => l.overlaps(r.inflate(2)));
    final order = [...pins]..sort((a, b) => a.priority.compareTo(b.priority));
    for (final p in order) {
      if (!p.wantLabel) {
        out[p.id] = _LabelSlot.hidden;
        continue;
      }
      final c = centers[p.id]!;
      final below = Rect.fromLTWH(c.dx - p.labelW / 2, c.dy + p.iconSize / 2 + 4, p.labelW, labelH);
      final above = Rect.fromLTWH(c.dx - p.labelW / 2, c.dy - p.iconSize / 2 - 4 - labelH, p.labelW, labelH);
      if (free(below)) {
        placed.add(below);
        out[p.id] = _LabelSlot.below;
      } else if (free(above)) {
        placed.add(above);
        out[p.id] = _LabelSlot.above;
      } else {
        out[p.id] = _LabelSlot.hidden;
      }
    }
    return out;
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

  /// One polygon per populated hexagon, coloured by how crowded it is. Sparse areas are left clear so the layer stays
  /// readable: the colour carries the message, the map shows through.
  List<Polygon> _populationPolygons(PopulationGrid grid) {
    final polygons = <Polygon>[];
    for (final c in grid.cells) {
      final k = grid.classOf(c);
      if (k == DensityClass.sparse) continue;
      final base = _kDensityColors[k]!;
      polygons.add(Polygon(
        points: c.vertices,
        color: base.withValues(alpha: _kDensityFill[k]!),
        borderColor: base.withValues(alpha: 0.28),
        borderStrokeWidth: 0.5,
      ));
    }
    return polygons;
  }

  /// Rounds a head count with thousands separators: 7100 becomes "7,100".
  static String _thousands(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

  /// "About 7,100 people within 1 km" and how crowded the spot is, for a place card. Empty where the data has nothing.
  List<Widget> _populationLine(BuildContext context, ll.LatLng point) {
    final grid = _population;
    if (grid == null || !grid.covers(point)) return const [];
    final l10n = AppLocalizations.of(context)!;
    final people = PopulationGrid.roundForDisplay(grid.peopleWithin(point, 1.0));
    final cell = grid.cellAt(point);
    final k = cell == null ? null : grid.classOf(cell);
    final label = switch (k) {
      DensityClass.high => l10n.popDensityHigh,
      DensityClass.medium => l10n.popDensityMedium,
      DensityClass.low => l10n.popDensityLow,
      DensityClass.sparse => l10n.popDensitySparse,
      null => null,
    };
    return [
      const SizedBox(height: 8),
      Row(
        children: [
          const Icon(Icons.groups_2_outlined, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.popAround(_thousands(people), '1'),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
          ),
          if (label != null && k != null) _DensityChip(label: label, color: _kDensityColors[k] ?? AppColors.textSecondary),
        ],
      ),
    ];
  }

  /// Plans the route when the start area or the destination has changed. Called after a frame, never during build.
  void _ensureRoute(ll.LatLng origin) {
    if (_assemblyPoints.isEmpty) return;
    final start = RouteService.coarse(origin);
    final key = '${start.latitude},${start.longitude}|${_chosen?.id ?? 'shortest'}|${_assemblyPoints.length}';
    if (key == _planKey) return;
    _planKey = key;
    setState(() => _planning = true);
    _routes.shortest(origin, _assemblyPoints, only: _chosen).then((plan) {
      if (!mounted || _planKey != key) return;
      setState(() {
        _plan = plan;
        _planning = false;
      });
      // Bring the whole route into view, clear of the search bar above and the route card and nav bar below.
      if (plan != null) {
        double height = 600;
        try {
          height = _mapController.camera.nonRotatedSize.height;
        } catch (_) {}
        _mapController.fitCamera(CameraFit.coordinates(
          coordinates: [origin, ...plan.points],
          // Room for the search bar above and the route card with the nav bar below, scaled to the map's height.
          padding: EdgeInsets.fromLTRB(48, height * 0.25 < 150 ? height * 0.25 : 150, 48, height * 0.42 < 270 ? height * 0.42 : 270),
          maxZoom: 16,
        ));
      }
    });
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

  Widget _nodeCard(BuildContext context, AppState appState, SiagaNode node) {
    final l10n = AppLocalizations.of(context)!;
    final rig = appState.rigMode ? appState.rigReading : null;
    final color = riskStateColor(node.state);
    final sim = node.simulated;
    // What the node is saying, in the same words the My Risk screen uses. A demo node borrows the rig's state, so it
    // never says the rig's readings are old; it only notes that the rig is offline.
    final rigOffline = rig != null && rig.isStale;
    final message = statusMessageFor(l10n, state: node.state, lastReading: !sim && rigOffline ? rig.rowTime : null);
    return _PlaceCard(
      point: ll.LatLng(node.lat, node.lon),
      accent: color,
      kind: sim ? l10n.nodeKindDemo : l10n.nodeKindSensor,
      kindIcon: sim ? Icons.science_outlined : Icons.sensors,
      title: node.name,
      onClose: () => setState(() => _focusKey = null),
      body: [
        Wrap(
          spacing: 10,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            RiskBadge(state: node.state),
            if (rig != null && !sim)
              Text(
                rig.simulated ? l10n.rigStatusSimulated : (rig.isStale ? l10n.rigStatusOffline : l10n.rigStatusLive),
                style: TextStyle(
                  color: rig.simulated ? AppColors.accent : (rig.isStale ? const Color(0xFFE8833A) : AppColors.normal),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (node.lastSeen != null)
              Text(_agoLabel(node.lastSeen!), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
          ],
        ),
        const SizedBox(height: 10),
        // The message itself, readable here without leaving the map.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(message.icon, color: message.color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message.title, style: AppFonts.heading(fontSize: 16.5, fontWeight: FontWeight.w700, letterSpacing: 0)),
                  const SizedBox(height: 2),
                  Text(message.detail, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
        ..._populationLine(context, ll.LatLng(node.lat, node.lon)),
        if (sim) ...[
          const SizedBox(height: 8),
          Text(
            rigOffline ? '${l10n.nodeSimulatedNote} ${l10n.simRigOffline}' : l10n.nodeSimulatedNote,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4),
          ),
        ],
        if (rig != null && !sim) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              _ReadingTile(label: l10n.rigMetricLevel, value: rig.heightCm.toStringAsFixed(1), unit: 'cm', color: AppColors.watch),
              const SizedBox(width: 8),
              _ReadingTile(label: l10n.rigMetricFlow, value: rig.flow.toStringAsFixed(0), unit: '', color: AppColors.accent),
              const SizedBox(width: 8),
              _ReadingTile(label: l10n.rigMetricSoil, value: rig.soilRaw.toStringAsFixed(0), unit: '', color: const Color(0xFFA78BFA)),
              const SizedBox(width: 8),
              _ReadingTile(label: l10n.rigMetricTilt, value: rig.tiltDeg.toStringAsFixed(1), unit: '°', color: AppColors.normal),
            ],
          ),
        ],
      ],
      actions: [
        OutlinedButton.icon(
          onPressed: () {
            appState.setLockedNode(node.id);
            setState(() => _focusKey = null);
            appState.openTab(1);
          },
          icon: const Icon(Icons.shield_outlined, size: 18),
          label: Text(l10n.viewInRisk),
        ),
        if (!sim)
          FilledButton.icon(
            onPressed: () => setState(() {
              _selectedNodeId = node.id;
              _focusKey = null;
            }),
            icon: const Icon(Icons.show_chart, size: 18),
            label: Text(l10n.placeDetails),
          ),
      ],
    );
  }

  Widget _assemblyCard(BuildContext context, AssemblyPoint point, ll.LatLng? origin, RoutePlan? plan) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final here = plan != null && plan.assembly.id == point.id ? plan : null;
    String? routeLine;
    if (here != null) {
      routeLine = [
        _formatDistance(here.distanceM),
        here.byRoad ? (here.fromCache ? l10n.routeSaved : l10n.routeByRoad) : l10n.routeStraight,
        if (here.durationS != null) '${_formatDuration(here.durationS!)} ${l10n.routeWalk}',
      ].join(' · ');
    }
    return _PlaceCard(
      point: ll.LatLng(point.lat, point.lon),
      photo: point.photo,
      accent: _kAssemblyColor,
      kind: l10n.nodeKindAssembly,
      kindIcon: Icons.groups,
      title: point.nameFor(locale),
      onClose: () => setState(() => _focusKey = null),
      body: [
        if (origin != null)
          Text(
            '${_formatDistance(RouteService.straightMeters(origin, ll.LatLng(point.lat, point.lon)))} ${l10n.mapAway}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ..._populationLine(context, ll.LatLng(point.lat, point.lon)),
        if (routeLine != null) ...[
          const SizedBox(height: 4),
          Text(routeLine, style: const TextStyle(color: _kRouteColor, fontWeight: FontWeight.w700)),
        ],
      ],
      actions: [
        if (origin != null)
          FilledButton.icon(
            onPressed: () => setState(() {
              _chosen = point;
              _showEvacRoute = true;
              _focusKey = null; // the route card takes over, and the map shows the whole route
            }),
            icon: const Icon(Icons.directions_walk, size: 18),
            label: Text(l10n.routeHere),
          ),
        if (_chosen != null)
          OutlinedButton(onPressed: () => setState(() => _chosen = null), child: Text(l10n.routeNearest)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final nodes = appState.nodes;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;

    // With the live rig in use the map opens on the venue. Nodes saved from an earlier session (possibly a different
    // place) must not decide where it opens.
    final center = _myPosition != null
        ? ll.LatLng(_myPosition!.latitude, _myPosition!.longitude)
        : appState.rigMode
            ? const ll.LatLng(kVenueLat, kVenueLon)
            : nodes.isNotEmpty
            ? ll.LatLng(nodes.first.lat, nodes.first.lon)
            : const ll.LatLng(2.92791, 101.64179); // MMU Cyberjaya, where the competition demo runs

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
    final destination = routeActive ? (_plan?.assembly ?? nearestAssembly) : null;
    if (routeActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureRoute(origin);
      });
    }
    // The place card for the marker in focus. If that node or assembly point no longer exists, there is no card.
    final focusNode = _focusKey != null && _focusKey!.startsWith('n:')
        ? nodes.where((n) => 'n:${n.id}' == _focusKey).firstOrNull
        : null;
    final focusAssembly = _focusKey != null && _focusKey!.startsWith('a:')
        ? _assemblyPoints.where((a) => 'a:${a.id}' == _focusKey).firstOrNull
        : null;
    final hasCard = (focusNode != null || focusAssembly != null) && selectedNode == null;
    final showRouteCard = routeActive && selectedNode == null && !hasCard;

    // The route moves while it is shown, unless the device is set to reduce motion.
    final animateRoute = routeActive && _plan != null && !MediaQuery.of(context).disableAnimations;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (animateRoute && !_flow.isAnimating) _flow.repeat();
      if (!animateRoute && _flow.isAnimating) _flow.stop();
    });

    // Where each label goes, so labels never sit on top of other markers or labels.
    double labelWidth(String text) => (text.length * 6.4 + 24).clamp(84.0, 146.0);
    final pins = <_Pin>[
      for (final n in nodes)
        _Pin('n:${n.id}', ll.LatLng(n.lat, n.lon), 46, labelWidth(n.name), true, _focusKey == 'n:${n.id}' ? 0 : 2),
      for (final a in _assemblyPoints)
        _Pin(
          'a:${a.id}',
          ll.LatLng(a.lat, a.lon),
          40,
          labelWidth(a.nameFor(locale)),
          _zoom >= 14 || _focusKey == 'a:${a.id}' || (destination != null && a.id == destination.id),
          _focusKey == 'a:${a.id}' ? 0 : (destination != null && a.id == destination.id ? 3 : 4),
        ),
      if (_myPosition != null) _Pin('me', ll.LatLng(_myPosition!.latitude, _myPosition!.longitude), 30, 52, true, 1),
    ];
    // The overlays on the map, in the map's own coordinates: the search bar, the route button, the legend, the nav bar
    // and the route card. A label that would sit under one of them moves or is left out.
    var obstacles = <Rect>[];
    try {
      final size = _mapController.camera.nonRotatedSize;
      final w = size.width, h = size.height;
      obstacles = [
        Rect.fromLTRB(12, 12, w - 12, 64),
        if (origin != null && _assemblyPoints.isNotEmpty) Rect.fromLTRB(w - 227, 70, w - 12, 118),
        if (!hasCard) Rect.fromLTRB(12, h - (_showPopulation ? 270 : 228), _showPopulation ? 235 : 187, h - 104),
        Rect.fromLTRB(0, h - 92, w, h),
        if (showRouteCard) Rect.fromLTRB(2, h - 207, w - 2, h - 92),
      ];
    } catch (_) {}
    final slots = _placeLabels(pins, obstacles);

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
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 13,
                  onPositionChanged: (camera, _) {
                    if ((camera.zoom - _zoom).abs() >= 0.25) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _zoom = camera.zoom);
                      });
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.siaga.siaga_app',
                  ),
                  if (_showPopulation && _popPolygons.isNotEmpty) PolygonLayer(polygons: _popPolygons),
                  if (routeActive && _plan != null) _RouteLayer(points: _plan!.points, from: origin, flow: _flow),
                  MarkerLayer(
                    markers: [
                      ...nodes.map(
                        (node) => Marker(
                          point: ll.LatLng(node.lat, node.lon),
                          width: _kMarkerW,
                          height: _kMarkerH,
                          child: _NodeMarker(
                            node: node,
                            slot: slots['n:${node.id}'] ?? _LabelSlot.below,
                            focused: _focusKey == 'n:${node.id}',
                            onTap: () => _focusNode(node),
                          ),
                        ),
                      ),
                      if (destination != null)
                        Marker(
                          point: ll.LatLng(destination.lat, destination.lon),
                          width: 140,
                          height: 140,
                          child: const IgnorePointer(child: _PulseRing(color: _kSafeColor)),
                        ),
                      ..._assemblyPoints.map(
                        (point) => Marker(
                          point: ll.LatLng(point.lat, point.lon),
                          width: _kMarkerW,
                          height: _kMarkerH,
                          child: _AssemblyPointMarker(
                            point: point,
                            highlighted: destination != null && point.id == destination.id,
                            slot: slots['a:${point.id}'] ?? _LabelSlot.hidden,
                            focused: _focusKey == 'a:${point.id}',
                            onTap: () => _focusAssembly(point),
                          ),
                        ),
                      ),
                      if (_myPosition != null)
                        Marker(
                          point: ll.LatLng(_myPosition!.latitude, _myPosition!.longitude),
                          width: _kMarkerW,
                          height: _kMarkerH,
                          child: _MarkerBox(
                            iconSize: 54,
                            icon: _MyLocationMarker(onTap: () => _showMyLocationInfo(context)),
                            name: (slots['me'] ?? _LabelSlot.below) == _LabelSlot.hidden ? null : l10n.mapLegendYou,
                            labelAbove: slots['me'] == _LabelSlot.above,
                            accent: const Color(0xFF3D8BFF),
                          ),
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
        if (_population != null)
          Positioned(
            top: (appState.isOffline ? 44 : 12) + 68 + (origin != null && _assemblyPoints.isNotEmpty ? 50 : 0),
            right: 22,
            child: _PopulationToggle(
              active: _showPopulation,
              label: l10n.popToggle,
              onTap: () => setState(() => _showPopulation = !_showPopulation),
            ),
          ),
        if (!hasCard)
          Positioned(
            left: 22,
            bottom: showRouteCard ? 214 : 104,
            child: _showPopulation && _population != null ? _PopulationLegend(grid: _population!) : const _MapLegend(),
          ),
        if (hasCard)
          Positioned(
            left: 12,
            right: 12,
            bottom: 92,
            child: Center(
              child: focusNode != null
                  ? _nodeCard(context, appState, focusNode)
                  : _assemblyCard(context, focusAssembly!, origin, destination != null && _plan != null ? _plan : null),
            ),
          ),
        if (showRouteCard)
          Positioned(
            left: 12,
            right: 12,
            // Clears the floating nav dock (68px tall + its own 12px bottom margin, see main.dart's _FloatingNavBar).
            bottom: 92,
            child: _RouteSummary(
              plan: _plan,
              planning: _planning,
              exactPosition: _myPosition != null,
              chosen: _chosen != null,
              onBackToShortest: () => setState(() => _chosen = null),
            ),
          ),
        if (selectedNode != null)
          _NodeInfoPanel(
            node: selectedNode,
            demoReading: appState.demoMode ? appState.demoReading : null,
            rigReading: appState.rigMode ? appState.rigReading : null,
            trend: appState.rigMode ? appState.rigTrend : const [],
            controller: _sheetController,
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
  final String? assemblyId;
  const _SearchResult({
    required this.label,
    required this.point,
    required this.isNode,
    required this.nodeId,
    required this.assemblyId,
  });
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
            color: active ? _kRouteColor : Colors.black.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(999),
            boxShadow: active ? appGlow(_kRouteColor, alpha: 0.55, blur: 16) : const [BoxShadow(color: Colors.black45, blurRadius: 8)],
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

const _kAssemblyColor = Color(0xFF8B7CFF);

/// The population layer is one hue (pink to deep magenta) getting stronger with density, which keeps it apart from the
/// risk colours (green to red) and reads at a glance without a legend lookup.
const _kDensityColors = <DensityClass, Color>{
  DensityClass.low: Color(0xFFFF8FD0),
  DensityClass.medium: Color(0xFFE0309F),
  DensityClass.high: Color(0xFF8E0F52),
};
const _kDensityFill = <DensityClass, double>{
  DensityClass.low: 0.11,
  DensityClass.medium: 0.24,
  DensityClass.high: 0.46,
};

/// The evacuation route is drawn in an emergency red, and the place it leads to in a safe green.
const _kRouteColor = Color(0xFFFF3B30);
const _kSafeColor = Color(0xFF2EE59D);
const double _kMarkerW = 150;
const double _kMarkerH = 120;

String _formatDistance(double meters) => meters >= 1000 ? '${(meters / 1000).toStringAsFixed(1)} km' : '${meters.round()} m';

/// "12 s ago", "5 min ago", "3 h ago": how long since a node last reported.
String _agoLabel(DateTime time) {
  final d = DateTime.now().difference(time);
  if (d.inSeconds < 60) return '${d.inSeconds < 0 ? 0 : d.inSeconds} s ago';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 48) return '${d.inHours} h ago';
  return '${d.inDays} days ago';
}

String _formatDuration(double seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 90) return '$minutes min';
  return '${minutes ~/ 60} h ${minutes % 60} min';
}

/// Bottom card while the route is on: where it goes, how far by road and how long on foot, and whether it is a real
/// road route, a saved one, or only a straight line because nothing could be reached.
class _RouteSummary extends StatelessWidget {
  final RoutePlan? plan;
  final bool planning;
  final bool exactPosition;
  final bool chosen;
  final VoidCallback onBackToShortest;
  const _RouteSummary({
    required this.plan,
    required this.planning,
    required this.exactPosition,
    required this.chosen,
    required this.onBackToShortest,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final p = plan;
    final decoration = BoxDecoration(
      color: Colors.black.withValues(alpha: 0.80),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.hairline),
    );
    if (p == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: decoration,
        child: Row(
          children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5)),
            const SizedBox(width: 12),
            Expanded(child: Text(l10n.routeCalculating, style: const TextStyle(color: Colors.white))),
          ],
        ),
      );
    }
    final source = !p.byRoad
        ? l10n.routeStraight
        : [
            p.fromCache ? l10n.routeSaved : l10n.routeByRoad,
            if (p.durationS != null) '${_formatDuration(p.durationS!)} ${l10n.routeWalk}',
          ].join(' · ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: decoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_walk, color: _kRouteColor, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.routeShortest.toUpperCase(),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.6),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.assembly.nameFor(locale),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(_formatDistance(p.distanceM), style: AppFonts.mono(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 6),
          Text(source, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
          if (exactPosition) ...[
            const SizedBox(height: 2),
            Text(l10n.routeAreaNote, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
          if (chosen)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36), foregroundColor: AppColors.accent),
                onPressed: onBackToShortest,
                child: Text(l10n.routeNearest),
              ),
            ),
        ],
      ),
    );
  }
}

/// A map marker with a label under it saying what kind of thing it is and its name. The marker's own point is the
/// centre of the icon, so the label hangs below without moving where the marker sits on the map.
enum _LabelSlot { below, above, hidden }

/// What label placement needs to know about one marker.
class _Pin {
  final String id;
  final ll.LatLng point;
  final double iconSize;
  final double labelW;
  final bool wantLabel;
  final int priority;
  const _Pin(this.id, this.point, this.iconSize, this.labelW, this.wantLabel, this.priority);
}

class _MarkerBox extends StatelessWidget {
  final Widget icon;
  final double iconSize;
  final String? kind;
  final String? name;
  final bool labelAbove;
  final Color accent;
  const _MarkerBox({required this.icon, required this.iconSize, required this.accent, this.kind, this.name, this.labelAbove = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kMarkerW,
      height: _kMarkerH,
      child: Stack(
        alignment: Alignment.center,
        children: [
          icon,
          if (name != null)
            Positioned(
              top: labelAbove ? null : _kMarkerH / 2 + iconSize / 2 + 4,
              bottom: labelAbove ? _kMarkerH / 2 + iconSize / 2 + 4 : null,
              child: Container(
                constraints: const BoxConstraints(maxWidth: _kMarkerW - 4),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: accent.withValues(alpha: 0.55)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (kind != null)
                      Text(
                        kind!.toUpperCase(),
                        style: TextStyle(color: accent, fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                      ),
                    Text(
                      name!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AssemblyPointMarker extends StatelessWidget {
  final AssemblyPoint point;
  final bool highlighted;
  final _LabelSlot slot;
  final bool focused;
  final VoidCallback onTap;
  const _AssemblyPointMarker({
    required this.point,
    required this.highlighted,
    required this.slot,
    required this.focused,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final color = highlighted ? _kSafeColor : _kAssemblyColor;
    return _MarkerBox(
      iconSize: 38,
      accent: color,
      kind: slot == _LabelSlot.hidden ? null : l10n.nodeKindAssembly,
      name: slot == _LabelSlot.hidden ? null : point.nameFor(locale),
      labelAbove: slot == _LabelSlot.above,
      icon: GestureDetector(
        onTap: onTap,
        child: Tooltip(
          message: point.nameFor(locale),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: Colors.white, width: focused ? 3.5 : 2),
              boxShadow: highlighted || focused ? appGlow(color, alpha: 0.75, blur: 18) : const [BoxShadow(color: Colors.black38, blurRadius: 5)],
            ),
            child: const Icon(Icons.groups, color: Colors.white, size: 21),
          ),
        ),
      ),
    );
  }
}

/// What the three kinds of marker mean.
class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Widget row(Widget swatch, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              swatch,
              const SizedBox(width: 8),
              Text(text, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(Container(width: 15, height: 15, decoration: const BoxDecoration(color: AppColors.normal, shape: BoxShape.circle)), l10n.mapLegendNode),
          row(Container(width: 15, height: 15, decoration: BoxDecoration(border: Border.all(color: AppColors.normal, width: 2), shape: BoxShape.circle)), l10n.mapLegendDemo),
          row(Container(width: 15, height: 15, decoration: BoxDecoration(color: _kAssemblyColor, borderRadius: BorderRadius.circular(5))), l10n.mapLegendAssembly),
          row(Container(width: 15, height: 15, decoration: const BoxDecoration(color: Color(0xFF3D8BFF), shape: BoxShape.circle)), l10n.mapLegendYou),
        ],
      ),
    );
  }
}

/// The full details of a node. On a wide screen it is a tall panel fixed at the side of the map, with everything in
/// view and nothing to drag. On a phone it is a bottom sheet that opens most of the way up and can be dragged (with a
/// finger or the mouse) or tapped at the handle to open fully. Its content scrolls clear of the floating nav bar.
class _NodeInfoPanel extends StatelessWidget {
  final SiagaNode node;
  final DemoReading? demoReading;
  final RigReading? rigReading;
  final List<RigPoint> trend;
  final DraggableScrollableController controller;
  final VoidCallback onClose;
  final bool locked;
  final VoidCallback onToggleLock;

  static const _openSize = 0.64;
  static const _fullSize = 0.92;
  static const _sideBreakpoint = 760.0;

  const _NodeInfoPanel({
    required this.node,
    required this.demoReading,
    required this.rigReading,
    required this.trend,
    required this.controller,
    required this.onClose,
    required this.locked,
    required this.onToggleLock,
  });

  void _toggle() {
    if (!controller.isAttached) return;
    controller.animateTo(controller.size > 0.78 ? _openSize : _fullSize, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  BoxDecoration _decoration(BuildContext context, {required bool side}) => BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: side ? BorderRadius.circular(20) : const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: AppColors.hairline),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18)],
      );

  @override
  Widget build(BuildContext context) {
    final side = MediaQuery.of(context).size.width >= _sideBreakpoint;
    if (side) {
      // A tall box beside the map: below the search bar, above the nav bar, nothing to drag.
      return Positioned(
        top: 132,
        right: 22,
        bottom: 100,
        width: 420,
        child: Container(
          decoration: _decoration(context, side: true),
          clipBehavior: Clip.antiAlias,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            children: _items(context, side: true),
          ),
        ),
      );
    }
    return DraggableScrollableSheet(
      key: ValueKey(node.id),
      controller: controller,
      initialChildSize: _openSize,
      minChildSize: 0.16,
      maxChildSize: _fullSize,
      snap: true,
      snapSizes: const [_openSize, _fullSize],
      builder: (context, scrollController) {
        return Container(
          decoration: _decoration(context, side: false),
          // Flutter on the web does not let a mouse drag a scrollable by default, so allow it here.
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.stylus, PointerDeviceKind.trackpad},
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 140), // the last items stay reachable above the nav bar
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggle,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.30), borderRadius: BorderRadius.circular(3)),
                      ),
                    ),
                  ),
                ),
                ..._items(context, side: false),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _items(BuildContext context, {required bool side}) {
    final l10n = AppLocalizations.of(context)!;
    final rig = rigReading;
    final tiles = rig == null
        ? const <Widget>[]
        : [
            _ReadingTile(label: l10n.rigMetricLevel, value: rig.heightCm.toStringAsFixed(1), unit: 'cm', color: AppColors.watch),
            _ReadingTile(label: l10n.rigMetricFlow, value: rig.flow.toStringAsFixed(0), unit: '', color: AppColors.accent),
            _ReadingTile(label: l10n.rigMetricSoil, value: rig.soilRaw.toStringAsFixed(0), unit: '', color: const Color(0xFFA78BFA)),
            _ReadingTile(label: l10n.rigMetricTilt, value: rig.tiltDeg.toStringAsFixed(1), unit: '°', color: AppColors.normal),
          ];
    return [
      Row(
        children: [
          Expanded(child: Text(node.name, style: Theme.of(context).textTheme.titleLarge)),
          IconButton(icon: const Icon(Icons.close), onPressed: onClose),
        ],
      ),
      Wrap(
        spacing: 10,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.normal.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.normal.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sensors, size: 14, color: AppColors.normal),
                const SizedBox(width: 5),
                Text(
                  l10n.nodeKindSensor.toUpperCase(),
                  style: const TextStyle(color: AppColors.normal, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.7),
                ),
              ],
            ),
          ),
          RiskBadge(state: node.state),
          if (node.riskProbability != null)
            Text(
              '${(node.riskProbability! * 100).round()}%',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: riskStateColor(node.state)),
            ),
          if (rig != null)
            Text(
              rig.simulated ? l10n.rigStatusSimulated : (rig.isStale ? l10n.rigStatusOffline : l10n.rigStatusLive),
              style: TextStyle(
                color: rig.simulated ? AppColors.accent : (rig.isStale ? const Color(0xFFE8833A) : AppColors.normal),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (node.batteryVolts != null) Text('${l10n.nodeBattery}: ${node.batteryVolts!.toStringAsFixed(2)}V'),
        ],
      ),
      if (tiles.isNotEmpty) ...[
        const SizedBox(height: 14),
        // Two by two in the side panel, where four in a row would be too narrow; four in a row on a phone.
        if (side) ...[
          Row(children: [tiles[0], const SizedBox(width: 8), tiles[1]]),
          const SizedBox(height: 8),
          Row(children: [tiles[2], const SizedBox(width: 8), tiles[3]]),
        ] else
          Row(children: [for (var i = 0; i < tiles.length; i++) ...[if (i > 0) const SizedBox(width: 8), tiles[i]]]),
      ],
      if (node.lastSeen != null) ...[
        const SizedBox(height: 10),
        Text('${l10n.nodeLastSeen}: ${_agoLabel(node.lastSeen!)}', style: Theme.of(context).textTheme.bodySmall),
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
            Expanded(child: Text(l10n.mapLockedHint, style: const TextStyle(color: AppColors.textMuted, fontSize: 11))),
          ],
        ],
      ),
      const SizedBox(height: 4),
      Row(
        children: [
          const Icon(Icons.place_outlined, size: 14, color: Color(0xFF97A2B8)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '${l10n.nodeGpsLabel}: ${node.lat.toStringAsFixed(5)}, ${node.lon.toStringAsFixed(5)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      if (rig != null) ...[
        RigTrendCard(
          icon: Icons.waves,
          title: l10n.rigMetricLevel,
          help: l10n.trendLevelHelp,
          color: AppColors.watch,
          points: trend,
          valueOf: (p) => p.heightCm,
          latestText: '${rig.heightCm.toStringAsFixed(1)} cm',
          unit: 'cm',
          minSpan: 2,
        ),
        const SizedBox(height: 12),
        RigTrendCard(
          icon: Icons.shield_outlined,
          title: l10n.trendRisk,
          help: l10n.trendRiskHelp,
          color: riskStateColor(node.state),
          points: trend,
          valueOf: (p) => p.phase.toDouble(),
          latestText: riskStateLabel(context, RiskState.values[rig.phase - 1]),
          phaseAxis: true,
        ),
      ] else if (demoReading != null) ...[
        DemoReadout(reading: demoReading!),
      ] else ...[
        Text(l10n.nodeHistoryTitle, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(height: 220, child: NodeHistoryChart(nodeId: node.id)),
      ],
    ];
  }
}

class _ReadingTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  const _ReadingTile({required this.label, required this.value, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 8.5, fontWeight: FontWeight.w700, letterSpacing: 0.4, height: 1.2),
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  text: value,
                  style: AppFonts.mono(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.3),
                  children: [
                    if (unit.isNotEmpty)
                      TextSpan(
                        text: unit == '°' ? unit : ' $unit',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
  final _LabelSlot slot;
  final bool focused;
  final VoidCallback onTap;
  const _NodeMarker({required this.node, required this.slot, required this.focused, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = riskStateColor(node.state);
    return _MarkerBox(
      iconSize: 42,
      accent: color,
      kind: slot == _LabelSlot.hidden ? null : (node.simulated ? l10n.nodeKindDemo : l10n.nodeKindSensor),
      name: slot == _LabelSlot.hidden ? null : node.name,
      labelAbove: slot == _LabelSlot.above,
      icon: GestureDetector(
        onTap: onTap,
        child: Tooltip(
          message: node.name,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              // A simulated node is drawn lighter, so it reads as different from a real sensor at a glance.
              color: node.simulated ? color.withValues(alpha: 0.62) : color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: focused ? 4 : 2.5),
              boxShadow: appGlow(color, alpha: focused ? 0.8 : 0.5, blur: focused ? 20 : 14),
            ),
            child: Icon(Icons.sensors, color: node.state == RiskState.watch ? const Color(0xFF12202F) : Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

const _kSatelliteTiles = 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

/// The floating window for a tapped marker, in the style of a maps app's place card: a picture of the place at the top,
/// then its name, what it is, a few facts, and what you can do with it.
class _PlaceCard extends StatelessWidget {
  final ll.LatLng point;
  final String? photo;
  final Color accent;
  final String kind;
  final IconData kindIcon;
  final String title;
  final List<Widget> body;
  final List<Widget> actions;
  final VoidCallback onClose;
  const _PlaceCard({
    required this.point,
    required this.accent,
    required this.kind,
    required this.kindIcon,
    required this.title,
    required this.body,
    required this.actions,
    required this.onClose,
    this.photo,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.hairline),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 22, offset: Offset(0, 8))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 104,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _PlacePicture(point: point, photo: photo, accent: accent),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onClose,
                          child: const SizedBox(width: 44, height: 44, child: Icon(Icons.close, color: Colors.white)),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(kindIcon, size: 14, color: accent),
                            const SizedBox(width: 6),
                            Text(
                              kind.toUpperCase(),
                              style: TextStyle(color: accent, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.7),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    ...body,
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: actions),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The picture at the top of a place card. A photo bundled with the app wins; otherwise it is a satellite view of the
/// exact spot, so the person can see what the place looks like from above.
class _PlacePicture extends StatelessWidget {
  final ll.LatLng point;
  final String? photo;
  final Color accent;
  const _PlacePicture({required this.point, required this.photo, required this.accent});

  @override
  Widget build(BuildContext context) {
    final satellite = Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: FlutterMap(
            key: ValueKey('${point.latitude},${point.longitude}'),
            options: MapOptions(
              initialCenter: point,
              initialZoom: 17.6,
              backgroundColor: Colors.transparent,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
            ),
            children: [
              TileLayer(urlTemplate: _kSatelliteTiles, userAgentPackageName: 'com.siaga.siaga_app'),
              MarkerLayer(markers: [
                Marker(
                  point: point,
                  width: 26,
                  height: 26,
                  child: Container(
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
        const Positioned(
          right: 8,
          bottom: 6,
          child: Text('Imagery © Esri, Maxar', style: TextStyle(color: Colors.white70, fontSize: 8.5, shadows: [Shadow(blurRadius: 3)])),
        ),
      ],
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        // Shown while the picture loads, and when there is no connection.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent.withValues(alpha: 0.35), const Color(0xFF0E1A2D)],
            ),
          ),
          child: Center(child: Icon(Icons.image_outlined, color: Colors.white.withValues(alpha: 0.18), size: 40)),
        ),
        photo != null ? Image.asset(photo!, fit: BoxFit.cover, errorBuilder: (context, error, stack) => satellite) : satellite,
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0x66000000)],
              stops: [0.55, 1],
            ),
          ),
        ),
      ],
    );
  }
}

/// The evacuation route, drawn to be seen at a glance: a glowing red line with a white edge, white arrows flowing
/// towards the destination, and a bright pulse that travels the whole line. The line is drawn on a canvas of its own,
/// from the map's camera, so it follows every pan and zoom without a delay.
class _RouteLayer extends StatelessWidget {
  final List<ll.LatLng> points;
  final ll.LatLng? from;
  final Animation<double> flow;
  const _RouteLayer({required this.points, required this.from, required this.flow});

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: flow,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _RoutePainter(camera: camera, points: points, from: from, t: flow.value),
        ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  final MapCamera camera;
  final List<ll.LatLng> points;
  final ll.LatLng? from;
  final double t; // 0 to 1, repeating

  _RoutePainter({required this.camera, required this.points, required this.from, required this.t});

  Paint _stroke(Color color, double width, {double blur = 0}) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color
    ..maskFilter = blur > 0 ? MaskFilter.blur(BlurStyle.normal, blur) : null;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final offsets = [for (final p in points) camera.latLngToScreenOffset(p)];
    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (var i = 1; i < offsets.length; i++) {
      path.lineTo(offsets[i].dx, offsets[i].dy);
    }

    // A short dotted link from where the person is to where the route starts.
    if (from != null) {
      final a = camera.latLngToScreenOffset(from!);
      final link = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(offsets.first.dx, offsets.first.dy);
      for (final m in link.computeMetrics()) {
        for (var d = 0.0; d < m.length; d += 12) {
          canvas.drawPath(m.extractPath(d, math.min(d + 6, m.length)), _stroke(_kRouteColor, 4));
        }
      }
    }

    final pulse = (math.sin(t * 2 * math.pi * 3) + 1) / 2; // the glow breathes about once a second
    canvas.drawPath(path, _stroke(_kRouteColor.withValues(alpha: 0.28 + 0.22 * pulse), 20 + 7 * pulse, blur: 9));
    canvas.drawPath(path, _stroke(Colors.white, 11.5));
    canvas.drawPath(path, _stroke(_kRouteColor, 7.5));

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final total = metric.length;
    if (total < 20) return;

    // Arrows pointing the way, sliding along the line.
    var spacing = 40.0;
    if (total / spacing > 400) spacing = total / 400; // never an unreasonable number when the route is very long
    final arrow = Paint()..color = Colors.white;
    final shift = (t * 3 * spacing) % spacing;
    final bounds = (Offset.zero & size).inflate(40);
    for (var d = shift; d < total; d += spacing) {
      final tangent = metric.getTangentForOffset(d);
      if (tangent == null || !bounds.contains(tangent.position)) continue;
      canvas.save();
      canvas.translate(tangent.position.dx, tangent.position.dy);
      canvas.rotate(math.atan2(tangent.vector.dy, tangent.vector.dx));
      canvas.drawPath(
        Path()
          ..moveTo(5, 0)
          ..lineTo(-3.2, -4.2)
          ..lineTo(-0.6, 0)
          ..lineTo(-3.2, 4.2)
          ..close(),
        arrow,
      );
      canvas.restore();
    }

    // A bright pulse running from the start to the destination, over and over.
    final head = total * t;
    final tail = math.max(0.0, head - 90);
    canvas.drawPath(metric.extractPath(tail, head), _stroke(Colors.white.withValues(alpha: 0.9), 4.5, blur: 1.5));
    final tip = metric.getTangentForOffset(head)?.position;
    if (tip != null) {
      canvas.drawCircle(tip, 13, Paint()..color = _kRouteColor.withValues(alpha: 0.55)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawCircle(tip, 7.5, Paint()..color = Colors.white);
      canvas.drawCircle(tip, 4.5, Paint()..color = _kRouteColor);
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) => true;
}

/// Rings that grow and fade, drawn under the destination so the eye is drawn to where the route ends.
class _PulseRing extends StatefulWidget {
  final Color color;
  const _PulseRing({required this.color});

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        Widget ring(double phase) {
          final v = (_c.value + phase) % 1.0;
          final size = 46 + 84 * v;
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: widget.color.withValues(alpha: (1 - v) * 0.9), width: 3),
              color: widget.color.withValues(alpha: (1 - v) * 0.12),
            ),
          );
        }

        return Center(child: Stack(alignment: Alignment.center, children: [ring(0), ring(0.5)]));
      },
    );
  }
}

/// Switches the population layer on and off. It sits under the route button and takes the layer's own colour when on.
class _PopulationToggle extends StatelessWidget {
  final bool active;
  final String label;
  final VoidCallback onTap;
  const _PopulationToggle({required this.active, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: active ? _kDensityColors[DensityClass.medium] : Colors.black.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(999),
            boxShadow: active
                ? appGlow(_kDensityColors[DensityClass.medium]!, alpha: 0.5, blur: 14)
                : const [BoxShadow(color: Colors.black45, blurRadius: 8)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.groups_2_outlined, color: Colors.white, size: 17),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the three colours mean, with the people-per-square-kilometre range of each, and where the data is from.
class _PopulationLegend extends StatelessWidget {
  final PopulationGrid grid;
  const _PopulationLegend({required this.grid});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Widget row(DensityClass k, String name, String range) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: _kDensityColors[k]!.withValues(alpha: (_kDensityFill[k]! + 0.25).clamp(0.0, 1.0)),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: _kDensityColors[k]!, width: 1),
                ),
              ),
              const SizedBox(width: 9),
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text(range, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.popLegendTitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          row(DensityClass.high, l10n.popHigh, '4,000+'),
          row(DensityClass.medium, l10n.popMedium, '1,000 to 4,000'),
          row(DensityClass.low, l10n.popLow, '150 to 1,000'),
          const SizedBox(height: 4),
          Text(l10n.popSource, style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5)),
        ],
      ),
    );
  }
}

class _DensityChip extends StatelessWidget {
  final String label;
  final Color color;
  const _DensityChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.8)),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
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
