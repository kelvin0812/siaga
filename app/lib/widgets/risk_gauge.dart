import 'dart:math';

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import 'risk_badge.dart';

/// Telemetry-dial gauge replacing the old flat "Warning" pill. A ring of
/// fine tick marks (the "instrument" texture) sits under four coloured
/// segments — one per RiskState in severity order; segments up to and
/// including the current state are lit, the rest sit dim. WARNING/EVACUATE
/// additionally get a pulsing radar halo — motion is reserved for the
/// states that actually warrant urgency, so a NORMAL reading stays
/// visually calm. The centre readout is monospace on purpose: it's meant
/// to look like an instrument reading, not a headline.
class RiskGauge extends StatefulWidget {
  final RiskState state;
  const RiskGauge({super.key, required this.state});

  @override
  State<RiskGauge> createState() => _RiskGaugeState();
}

class _RiskGaugeState extends State<RiskGauge> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  IconData get _icon => switch (widget.state) {
        RiskState.normal => Icons.check_circle_outline,
        RiskState.watch => Icons.visibility_outlined,
        RiskState.warning => Icons.warning_amber_rounded,
        RiskState.evacuate => Icons.crisis_alert,
      };

  @override
  Widget build(BuildContext context) {
    final color = riskStateColor(widget.state);
    final label = riskStateLabel(context, widget.state);
    final l10n = AppLocalizations.of(context)!;
    final urgent = widget.state == RiskState.warning || widget.state == RiskState.evacuate;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = _pulse.value;
        return SizedBox(
          width: 280,
          height: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (urgent)
                Opacity(
                  opacity: (1 - t) * 0.45,
                  child: Container(
                    width: 220 + t * 60,
                    height: 220 + t * 60,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.25)),
                  ),
                ),
              // The dial's own "lit instrument face" — a soft radial wash
              // in the current state colour, sitting between the tick
              // ring and the centre readout. Reads as backlit glass
              // rather than a flat disc.
              Container(
                width: 224,
                height: 224,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [color.withValues(alpha: 0.10), Colors.transparent],
                    stops: const [0.0, 0.85],
                  ),
                ),
              ),
              CustomPaint(
                size: const Size(280, 280),
                painter: _GaugePainter(state: widget.state, pulse: urgent ? t : 0.0),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_icon, color: color, size: 34),
                  const SizedBox(height: 10),
                  Text(label.toUpperCase(), style: AppFonts.heading(fontSize: 25, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.6)),
                  const SizedBox(height: 6),
                  Text(
                    'LVL ${widget.state.index + 1}/4',
                    style: AppFonts.mono(fontSize: 12, color: AppColors.textMuted, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.myRiskTitle.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final RiskState state;
  final double pulse;
  _GaugePainter({required this.state, required this.pulse});

  static const _startAngle = pi * 0.8;
  static const _totalSweep = pi * 1.4;
  static const _gap = 0.06;
  static const _strokeWidth = 14.0;
  static const _tickCount = 48;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final dialRadius = size.width / 2 - 2;
    final ringRadius = size.width / 2 - _strokeWidth - 10;
    final segSweep = _totalSweep / 4 - _gap;
    final currentIndex = state.index;

    // Instrument tick ring — purely textural, sits outside the coloured
    // segments so the gauge reads as a measuring device, not just a bar.
    final tickPaint = Paint()..strokeWidth = 1.4;
    for (var i = 0; i <= _tickCount; i++) {
      final angle = _startAngle + (_totalSweep * i / _tickCount);
      final major = i % 4 == 0;
      final outer = Offset(center.dx + cos(angle) * dialRadius, center.dy + sin(angle) * dialRadius);
      final inner = Offset(
        center.dx + cos(angle) * (dialRadius - (major ? 10 : 5)),
        center.dy + sin(angle) * (dialRadius - (major ? 10 : 5)),
      );
      tickPaint.color = Colors.white.withValues(alpha: major ? 0.22 : 0.09);
      canvas.drawLine(inner, outer, tickPaint);
    }

    for (var i = 0; i < RiskState.values.length; i++) {
      final segStart = _startAngle + i * (_totalSweep / 4);
      final segColor = riskStateColor(RiskState.values[i]);
      final active = i <= currentIndex;

      final track = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = active ? segColor : Colors.white.withValues(alpha: 0.08);
      canvas.drawArc(Rect.fromCircle(center: center, radius: ringRadius), segStart, segSweep, false, track);

      if (i == currentIndex) {
        final glow = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth + pulse * 8
          ..strokeCap = StrokeCap.round
          ..color = segColor.withValues(alpha: 0.55 - pulse * 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
        canvas.drawArc(Rect.fromCircle(center: center, radius: ringRadius), segStart, segSweep, false, glow);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.state != state || oldDelegate.pulse != pulse;
}
