import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/models.dart';
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

  @override
  void initState() {
    super.initState();
    final locationService = context.read<AppState>().locationService;
    _myPosition = locationService.lastKnownPosition;
    locationService.positionUpdates.listen((position) {
      if (mounted) setState(() => _myPosition = position);
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
                const Icon(Icons.my_location, color: Color(0xFF1565C0)),
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
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

    return Stack(
      children: [
        Column(
          children: [
            if (appState.isOffline) const _OfflineBanner(),
            Expanded(
              child: FlutterMap(
                options: MapOptions(initialCenter: center, initialZoom: 13),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.siaga.siaga_app',
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
          ],
        ),
        if (selectedNode != null)
          _NodeInfoPanel(
            node: selectedNode,
            demoReading: appState.demoMode ? appState.demoReading : null,
            onClose: () => setState(() => _selectedNodeId = null),
          ),
      ],
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

  const _NodeInfoPanel({required this.node, required this.demoReading, required this.onClose});

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
                    color: Colors.grey.shade400,
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
                      color: const Color(0xFF1565C0).withValues(alpha: 0.35),
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
              color: const Color(0xFF1565C0),
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
      color: Colors.grey.shade800,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        l10n.offlineBanner,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
