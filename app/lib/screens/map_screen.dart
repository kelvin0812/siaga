import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import '../widgets/risk_badge.dart';
import 'node_detail_screen.dart';

/// Section 6.4: live map of nodes with state colour-coding and a
/// tap-through to per-node history charts.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final nodes = appState.nodes;

    final center = nodes.isNotEmpty
        ? ll.LatLng(nodes.first.lat, nodes.first.lon)
        : const ll.LatLng(4.85, 100.74); // Taiping, Perak — demo default

    return Column(
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
                markers: nodes
                    .map(
                      (node) => Marker(
                        point: ll.LatLng(node.lat, node.lon),
                        width: 40,
                        height: 40,
                        child: _NodeMarker(node: node),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NodeMarker extends StatelessWidget {
  final SiagaNode node;
  const _NodeMarker({required this.node});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => NodeDetailScreen(nodeId: node.id)),
      ),
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
