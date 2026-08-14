import 'package:flutter/material.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';

/// Live simulated sensor values for the demo node — the raw numbers
/// behind the risk badge, so a demo shows actual readings changing
/// (water level rising, soil saturating) rather than just a colour flip.
/// No "pressure" field: the real wire frame (Section 5.1) never carries
/// one either, so this stays honest about what real hardware reports.
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
              icon: Icons.water,
              label: l10n.demoWaterLevel,
              value: '${reading.heightM.toStringAsFixed(2)} m',
            ),
            _Reading(
              icon: Icons.grass,
              label: l10n.demoSoilMoisture,
              value: '${reading.soilPct}%',
            ),
            _Reading(
              icon: Icons.rotate_right,
              label: l10n.demoTilt,
              value: '${reading.tiltX}, ${reading.tiltY}',
            ),
            _Reading(
              icon: Icons.thermostat,
              label: l10n.demoTemperature,
              value: '${reading.tempC.toStringAsFixed(1)}°C',
            ),
            _Reading(
              icon: Icons.water_drop_outlined,
              label: l10n.demoHumidity,
              value: '${reading.rhPct.toStringAsFixed(0)}%',
            ),
            _Reading(
              icon: Icons.battery_std,
              label: l10n.nodeBattery,
              value: '${reading.batteryVolts.toStringAsFixed(2)}V',
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
