import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import '../widgets/risk_badge.dart';

/// Section 6.4: tap-through per-node history chart, reached from the map.
class NodeDetailScreen extends StatefulWidget {
  final int nodeId;
  const NodeDetailScreen({super.key, required this.nodeId});

  @override
  State<NodeDetailScreen> createState() => _NodeDetailScreenState();
}

class _NodeDetailScreenState extends State<NodeDetailScreen> {
  List<NodeReading>? _history;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
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
    final appState = context.watch<AppState>();
    final node = appState.nodes.where((n) => n.id == widget.nodeId).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(node?.name ?? 'Node ${widget.nodeId}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (node != null) ...[
              Row(
                children: [
                  RiskBadge(state: node.state),
                  const SizedBox(width: 12),
                  if (node.batteryVolts != null)
                    Text('${l10n.nodeBattery}: ${node.batteryVolts!.toStringAsFixed(2)}V'),
                ],
              ),
              const SizedBox(height: 4),
              if (node.lastSeen != null)
                Text(
                  '${l10n.nodeLastSeen}: ${node.lastSeen}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 16),
            ],
            Text(l10n.nodeHistoryTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(child: _buildChart()),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    if (_loadFailed) {
      return Center(child: Text(AppLocalizations.of(context)!.offlineBanner));
    }
    final history = _history;
    if (history == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (history.isEmpty) {
      return const Center(child: Text('No readings yet'));
    }

    final spots = <FlSpot>[
      for (var i = 0; i < history.length; i++)
        FlSpot(i.toDouble(), history[i].heightM),
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
