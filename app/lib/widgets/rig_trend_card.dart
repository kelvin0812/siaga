import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import 'glass_card.dart';
import 'risk_badge.dart';

/// One trend chart on the My Risk screen: a title and plain-language hint, the latest value, and the last few
/// minutes of one rig signal as a line. Everything drawn is a real reading, nothing is smoothed or invented.
///
/// With [phaseAxis] the chart shows the model's four-level decision as steps, labelled Normal to Evacuate,
/// instead of a numeric axis.
class RigTrendCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String help;
  final Color color;
  final List<RigPoint> points;
  final double Function(RigPoint) valueOf;

  /// The latest value as text, with its unit, shown at the top right.
  final String latestText;

  /// The unit added to values in the tooltip.
  final String unit;

  /// Decimals on the axis and in the tooltip.
  final int decimals;

  /// The smallest vertical span the chart will zoom into, so a flat line does not look like a big swing.
  final double minSpan;
  final bool phaseAxis;

  const RigTrendCard({
    super.key,
    required this.icon,
    required this.title,
    required this.help,
    required this.color,
    required this.points,
    required this.valueOf,
    required this.latestText,
    this.unit = '',
    this.decimals = 1,
    this.minSpan = 1,
    this.phaseAxis = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      radius: AppRadius.md,
      glowColor: color,
      glowAlpha: 0.10,
      glowBlur: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Text(latestText, style: AppFonts.mono(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 4),
          Text(help, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.35)),
          const SizedBox(height: 14),
          SizedBox(
            height: 140,
            child: points.length < 2
                ? Center(child: Text(l10n.trendNoData, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)))
                : _chart(context, l10n),
          ),
        ],
      ),
    );
  }

  Widget _chart(BuildContext context, AppLocalizations l10n) {
    final last = points.last.time;
    // x is minutes before the newest reading, so the right edge is always "now".
    double xOf(RigPoint p) => -last.difference(p.time).inMilliseconds / 60000.0;
    final spots = [for (final p in points) FlSpot(xOf(p), valueOf(p))];
    final minX = spots.first.x;
    final span = (-minX).clamp(0.5, 1000.0);

    double minY, maxY;
    if (phaseAxis) {
      minY = 0.5;
      maxY = 4.5;
    } else {
      var lo = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
      var hi = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
      if (hi - lo < minSpan) {
        final mid = (hi + lo) / 2;
        lo = mid - minSpan / 2;
        hi = mid + minSpan / 2;
      }
      final pad = (hi - lo) * 0.12;
      minY = lo - pad;
      maxY = hi + pad;
    }

    final lineColor = phaseAxis ? riskStateColor(RiskState.values[valueOf(points.last).round().clamp(1, 4) - 1]) : color;
    const labelStyle = TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w500);

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: 0,
        minY: minY,
        maxY: maxY,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: phaseAxis ? 1 : null,
          getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withValues(alpha: 0.06), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: phaseAxis ? 66 : 38,
              interval: phaseAxis ? 1 : null,
              getTitlesWidget: (value, meta) {
                if (phaseAxis) {
                  final n = value.round();
                  if ((value - n).abs() > 0.01 || n < 1 || n > 4) return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(riskStateLabel(context, RiskState.values[n - 1]), style: labelStyle.copyWith(color: riskStateColor(RiskState.values[n - 1]))),
                  );
                }
                if (value == meta.min || value == meta.max) return const SizedBox.shrink();
                return SideTitleWidget(meta: meta, child: Text(value.toStringAsFixed(decimals), style: labelStyle));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: span / 2,
              getTitlesWidget: (value, meta) {
                // Short stretches read better in seconds ("90 s") than as "1 min, 0 min".
                final text = value.abs() < 0.01
                    ? l10n.trendNow
                    : span >= 3
                        ? '${(-value).round()} min'
                        : '${(-value * 60).round()} s';
                return SideTitleWidget(meta: meta, child: Text(text, style: labelStyle));
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.surfaceRaised,
            getTooltipItems: (touched) => [
              for (final t in touched)
                LineTooltipItem(
                  phaseAxis
                      ? riskStateLabel(context, RiskState.values[t.y.round().clamp(1, 4) - 1])
                      : '${t.y.toStringAsFixed(decimals)}${unit.isEmpty ? '' : ' $unit'}',
                  AppFonts.mono(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: !phaseAxis,
            isStepLineChart: phaseAxis,
            curveSmoothness: 0.15,
            preventCurveOverShooting: true,
            color: lineColor,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, barData) => spot == barData.spots.last,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(radius: 4, color: lineColor, strokeWidth: 2, strokeColor: AppColors.surface),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [lineColor.withValues(alpha: 0.28), lineColor.withValues(alpha: 0.0)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
