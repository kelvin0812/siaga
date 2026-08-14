import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';

/// Fetches and renders a node's water-level history (Section 6.4).
/// Extracted as a standalone widget (not a full screen) so it can be
/// embedded in the map's inline panel instead of requiring navigation
/// to a separate page — map and analysis stay visible together.
class NodeHistoryChart extends StatefulWidget {
  final int nodeId;
  const NodeHistoryChart({super.key, required this.nodeId});

  @override
  State<NodeHistoryChart> createState() => _NodeHistoryChartState();
}

class _NodeHistoryChartState extends State<NodeHistoryChart> {
  List<NodeReading>? _history;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant NodeHistoryChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nodeId != widget.nodeId) {
      _history = null;
      _loadFailed = false;
      _load();
    }
  }

  Future<void> _load() async {
    final api = context.read<AppState>().api;
    try {
      final history = await api.getNodeHistory(widget.nodeId, hours: 24);
      if (mounted) setState(() => _history = history);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loadFailed) {
      return Center(child: Text(l10n.offlineBanner));
    }
    final history = _history;
    if (history == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (history.isEmpty) {
      return Center(child: Text(l10n.nodeNoReadings));
    }

    final spots = <FlSpot>[
      for (var i = 0; i < history.length; i++) FlSpot(i.toDouble(), history[i].heightM),
    ];

    return LineChart(
      LineChartData(
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}
