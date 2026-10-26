import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import 'risk_badge.dart';

/// A news-style strip under the title bar. When some place is at Warning or Evacuate it names those places, scrolling
/// slowly. Otherwise it is a calm one-line "nothing at high risk" (or, when the rig has gone quiet, an honest "offline":
/// it never says all is well on old data). Tap it to open the map. With "reduce motion" on, it stands still.
class LiveBanner extends StatefulWidget {
  final List<SiagaNode> nodes;
  final VoidCallback? onTap;

  /// The live rig is not sending, so a quiet strip must not read as "all clear".
  final bool rigOffline;
  const LiveBanner({super.key, required this.nodes, this.onTap, this.rigOffline = false});

  /// The places worth a headline: Warning and Evacuate, the most serious first.
  static List<SiagaNode> atRisk(List<SiagaNode> nodes) {
    final risky = nodes.where((n) => n.state.index >= RiskState.warning.index).toList();
    risky.sort((a, b) => b.state.index.compareTo(a.state.index));
    return risky;
  }

  @override
  State<LiveBanner> createState() => _LiveBannerState();
}

class _LiveBannerState extends State<LiveBanner> with SingleTickerProviderStateMixin {
  static const _pixelsPerSecond = 46.0;
  static const _tagRed = Color(0xFFD6373F);
  final _scroll = ScrollController();
  late final Ticker _ticker = createTicker((elapsed) {
    if (_scroll.hasClients) _scroll.jumpTo(elapsed.inMicroseconds / 1e6 * _pixelsPerSecond);
  });

  @override
  void dispose() {
    _ticker.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// The calm line: nothing is at Warning or Evacuate (or the rig is offline, which is said plainly, not as "all clear").
  Widget _quiet(BuildContext context, AppLocalizations l10n) {
    final offline = widget.rigOffline;
    final tint = offline ? const Color(0xFFE8833A) : AppColors.normal;
    final text = offline ? l10n.liveQuietOffline : l10n.liveQuiet;
    final tag = offline ? l10n.liveOffline : l10n.liveTag;
    return Semantics(
      container: true,
      liveRegion: true,
      button: widget.onTap != null,
      label: '$tag. $text',
      child: Material(
        color: Color.alphaBlend(tint.withValues(alpha: 0.12), AppColors.surface),
        child: InkWell(
          onTap: widget.onTap,
          child: SizedBox(
            height: 34,
            child: Row(
              children: [
                Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  color: offline ? const Color(0xFF7A4A22) : const Color(0xFF1F7A55),
                  child: ExcludeSemantics(child: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 1))),
                ),
                Expanded(
                  child: ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final risky = LiveBanner.atRisk(widget.nodes);
    final calm = MediaQuery.of(context).disableAnimations;
    if (risky.isEmpty || calm) {
      if (_ticker.isActive) _ticker.stop();
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
    final l10n = AppLocalizations.of(context)!;
    if (risky.isEmpty) return _quiet(context, l10n);

    final worst = riskStateColor(risky.first.state);
    final spoken = risky.map((n) => '${riskStateLabel(context, n.state)}: ${n.name}').join('. ');
    return Semantics(
      container: true,
      liveRegion: true,
      button: widget.onTap != null,
      label: '${l10n.liveTag}. $spoken',
      child: Material(
        color: Color.alphaBlend(worst.withValues(alpha: 0.22), AppColors.surface),
        child: InkWell(
          onTap: widget.onTap,
          child: SizedBox(
            height: 38,
            child: Row(
              children: [
                Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  color: _tagRed,
                  child: ExcludeSemantics(child: Text(l10n.liveTag, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 1))),
                ),
                Expanded(
                  child: ExcludeSemantics(
                    child: ClipRect(
                      child: ListView.builder(
                        controller: _scroll,
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (context, i) => _Headline(node: risky[i % risky.length]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  final SiagaNode node;
  const _Headline({required this.node});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 22),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: riskStateColor(node.state), borderRadius: BorderRadius.circular(5)),
            child: Text(riskStateLabel(context, node.state), style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          Text(node.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(width: 22),
          Container(width: 1, height: 14, color: Colors.white24),
        ],
      ),
    );
  }
}
