import 'package:flutter/material.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';

/// The live rig's four sensors as the phase model sees them, shown in the map's node panel.
class RigReadout extends StatelessWidget {
  final RigReading reading;
  const RigReadout({super.key, required this.reading});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.rigReadoutTitle, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _Reading(icon: Icons.waves, label: l10n.rigMetricLevel, value: '${reading.heightCm.toStringAsFixed(1)} cm'),
            _Reading(icon: Icons.water_drop_outlined, label: l10n.rigMetricFlow, value: reading.flow.toStringAsFixed(0)),
            _Reading(icon: Icons.grass, label: l10n.rigMetricSoil, value: reading.soilRaw.toStringAsFixed(0)),
            _Reading(icon: Icons.rotate_right, label: l10n.rigMetricTilt, value: '${reading.tiltDeg.toStringAsFixed(1)}°'),
          ],
        ),
        if (reading.isStale) ...[
          const SizedBox(height: 8),
          Text(l10n.rigOffline, style: const TextStyle(color: Color(0xFFE8833A), fontSize: 13)),
        ],
      ],
    );
  }
}

class _Reading extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Reading({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text('$label: ', style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
