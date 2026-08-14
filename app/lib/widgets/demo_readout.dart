import 'package:flutter/material.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';

/// Live simulated sensor values for the demo node, scoped to exactly the
/// sensors the team actually has: capacitive soil moisture, gravity
/// analog water pressure, radar water depth, and the MPU6050 IMU (tilt /
/// "soil inertia"). Water pressure is derived from depth via hydrostatic
/// physics (DemoReading.pressureKpa) rather than independently modeled —
/// see the class doc comment on why that's still honest and where it
/// diverges from the real wire frame.
class DemoReadout extends StatelessWidget {
  final DemoReading reading;
  const DemoReadout({super.key, required this.reading});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.demoReadoutTitle, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _Reading(
              icon: Icons.grass,
              label: l10n.demoSoilMoisture,
              value: '${reading.soilPct}%',
            ),
            _Reading(
              icon: Icons.compress,
              label: l10n.demoWaterPressure,
              value: '${reading.pressureKpa.toStringAsFixed(1)} kPa',
            ),
            _Reading(
              icon: Icons.water,
              label: l10n.demoWaterLevel,
              value: '${reading.heightM.toStringAsFixed(2)} m',
            ),
            _Reading(
              icon: Icons.rotate_right,
              label: l10n.demoSoilInertia,
              value:
                  '${reading.tiltXDeg.toStringAsFixed(1)}°, ${reading.tiltYDeg.toStringAsFixed(1)}°',
            ),
          ],
        ),
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
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
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
