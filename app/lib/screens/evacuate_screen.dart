import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/offline_cache.dart';
import '../l10n/app_localizations.dart';

/// Section 6.4: "full-screen high-priority presentation for EVACUATE" —
/// the closest a Flutter app foreground route can get to a native alarm
/// takeover. Pushed with a full-screen dialog route so it covers
/// everything, including the bottom nav, and can't be dismissed by the
/// back gesture alone (must tap acknowledge).
class EvacuateScreen extends StatefulWidget {
  final String messageEn;
  final String messageMs;

  const EvacuateScreen({super.key, required this.messageEn, required this.messageMs});

  @override
  State<EvacuateScreen> createState() => _EvacuateScreenState();
}

class _EvacuateScreenState extends State<EvacuateScreen> {
  List<AssemblyPoint> _assemblyPoints = const [];
  bool _showRoute = false;

  @override
  void initState() {
    super.initState();
    _loadAssemblyPoints();
  }

  Future<void> _loadAssemblyPoints() async {
    final cache = context.read<AppState>().cache;
    final points = await cache.loadAssemblyPoints();
    if (mounted) setState(() => _assemblyPoints = points);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final message = locale == 'ms' ? widget.messageMs : widget.messageEn;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFC62828),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 32),
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 80),
                const SizedBox(height: 16),
                Text(
                  l10n.evacuateHeadline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message.isNotEmpty ? message : l10n.evacuateBody,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                const Spacer(),
                if (_showRoute) _RouteInfo(assemblyPoints: _assemblyPoints),
                const SizedBox(height: 16),
                if (!_showRoute)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    onPressed: () => setState(() => _showRoute = true),
                    child: Text(l10n.evacuateViewRoute),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFC62828),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.evacuateAcknowledge),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Distance/bearing to the nearest bundled assembly point — a
/// deliberately simplified stand-in for real turn-by-turn routing, which
/// no routing API is specified for anywhere in the brief (Section 6.4
/// says "cache evacuation routes" but Section 5.3 has no endpoint for
/// them — see docs/nexus-log.md). Good enough to point someone in the
/// right direction; not a substitute for official guidance, which the
/// alert copy itself says explicitly.
class _RouteInfo extends StatelessWidget {
  final List<AssemblyPoint> assemblyPoints;
  const _RouteInfo({required this.assemblyPoints});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final position = context.read<AppState>().locationService.lastKnownPosition;

    if (assemblyPoints.isEmpty) {
      return const SizedBox.shrink();
    }

    AssemblyPoint nearest = assemblyPoints.first;
    double? nearestDistanceM;
    if (position != null) {
      for (final point in assemblyPoints) {
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          point.lat,
          point.lon,
        );
        if (nearestDistanceM == null || distance < nearestDistanceM) {
          nearestDistanceM = distance;
          nearest = point;
        }
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.assemblyPointsTitle,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(nearest.nameFor(locale), style: const TextStyle(color: Colors.white)),
          if (nearestDistanceM != null)
            Text(
              '${(nearestDistanceM / 1000).toStringAsFixed(1)} km',
              style: const TextStyle(color: Colors.white70),
            ),
        ],
      ),
    );
  }
}
