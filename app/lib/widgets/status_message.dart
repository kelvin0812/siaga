import 'package:flutter/material.dart';

import '../core/models.dart';
import '../l10n/app_localizations.dart';
import 'risk_badge.dart';

/// The plain-language line for a node's situation: a short title and one sentence of detail, with the colour and icon
/// that go with it. It is the same words wherever it appears (the My Risk screen and the map's place card), so a node
/// never says one thing in one place and something else in another.
class StatusMessage {
  final String title;
  final String detail;
  final Color color;
  final IconData icon;
  const StatusMessage({required this.title, required this.detail, required this.color, required this.icon});
}

/// "13h ago", "5m ago", "42s ago".
String formatAgoShort(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 60) return '${diff.inSeconds < 0 ? 0 : diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

/// [lastReading] is set when the rig has gone quiet: the message then says its data is old and does not describe the
/// level. [noSensors] is for the My Risk screen showing a demo node, which has no readings of its own. [waiting] is
/// for the time before the rig has sent anything.
StatusMessage statusMessageFor(
  AppLocalizations l10n, {
  required RiskState state,
  bool noSensors = false,
  bool waiting = false,
  DateTime? lastReading,
}) {
  if (noSensors) {
    return StatusMessage(title: l10n.statusDemoT, detail: l10n.simNoSensors, color: const Color(0xFF97A2B8), icon: Icons.science_outlined);
  }
  if (waiting) {
    return StatusMessage(title: l10n.statusWaitingT, detail: l10n.statusWaitingD, color: const Color(0xFF97A2B8), icon: Icons.hourglass_empty);
  }
  if (lastReading != null) {
    return StatusMessage(
      title: l10n.statusOfflineT,
      detail: l10n.statusOfflineD(formatAgoShort(lastReading)),
      color: const Color(0xFFE8833A),
      icon: Icons.cloud_off,
    );
  }
  final color = riskStateColor(state);
  return switch (state) {
    RiskState.normal => StatusMessage(title: l10n.statusNormalT, detail: l10n.statusNormalD, color: color, icon: Icons.check_circle_outline),
    RiskState.watch => StatusMessage(title: l10n.statusWatchT, detail: l10n.statusWatchD, color: color, icon: Icons.visibility_outlined),
    RiskState.warning => StatusMessage(title: l10n.statusWarningT, detail: l10n.statusWarningD, color: color, icon: Icons.warning_amber_rounded),
    RiskState.evacuate => StatusMessage(title: l10n.statusEvacT, detail: l10n.statusEvacD, color: color, icon: Icons.crisis_alert),
  };
}
