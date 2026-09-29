import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/offline_cache.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';

/// Section 6.4: "full-screen high-priority presentation for EVACUATE" —
/// the closest a Flutter app foreground route can get to a native alarm
/// takeover. Pushed with a full-screen dialog route so it covers
/// everything, including the bottom nav, and can't be dismissed by the
/// back gesture alone (must tap acknowledge). Solid evacuate-red rather
/// than the rest of the app's dark glass theme is deliberate here — this
/// is the one screen where maximum contrast and zero ambiguity matter
/// more than visual consistency.
class EvacuateScreen extends StatefulWidget {
  final String messageEn;
  final String messageMs;

  const EvacuateScreen({super.key, required this.messageEn, required this.messageMs});

  @override
  State<EvacuateScreen> createState() => _EvacuateScreenState();
}

class _EvacuateScreenState extends State<EvacuateScreen> with SingleTickerProviderStateMixin {
  List<AssemblyPoint> _assemblyPoints = const [];
  bool _showRoute = false;

  late final AnimationController _beacon = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _loadAssemblyPoints();
  }

  @override
  void dispose() {
    _beacon.dispose();
    super.dispose();
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
        backgroundColor: const Color(0xFF3A0A0A),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.4),
              radius: 1.3,
              colors: [Color(0xFFB01F1F), Color(0xFF3A0A0A)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  AnimatedBuilder(
                    animation: _beacon,
                    builder: (context, _) {
                      final t = _beacon.value;
                      return SizedBox(
                        width: 110,
                        height: 110,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Opacity(
                              opacity: (1 - t) * 0.6,
                              child: Container(
                                width: 80 + t * 30,
                                height: 80 + t * 30,
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24),
                              ),
                            ),
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.12),
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 52),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.evacuateHeadline,
                    textAlign: TextAlign.center,
                    style: AppFonts.heading(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.2),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    message.isNotEmpty ? message : l10n.evacuateBody,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  if (_showRoute) _RouteInfo(assemblyPoints: _assemblyPoints),
                  const SizedBox(height: 16),
                  if (!_showRoute)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white, width: 1.4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        ),
                        onPressed: () => setState(() => _showRoute = true),
                        icon: const Icon(Icons.directions_run, size: 20),
                        label: Text(l10n.evacuateViewRoute, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFB01F1F),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.evacuateAcknowledge),
                    ),
                  ),
                ],
              ),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.assemblyPointsTitle.toUpperCase(),
                  style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                ),
                const SizedBox(height: 3),
                Text(
                  nearest.nameFor(locale),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ],
            ),
          ),
          if (nearestDistanceM != null)
            Text(
              '${(nearestDistanceM / 1000).toStringAsFixed(1)} km',
              style: AppFonts.mono(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
            ),
        ],
      ),
    );
  }
}
