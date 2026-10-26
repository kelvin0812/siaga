import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import 'risk_badge.dart';

/// A news-style pill under the title bar, as wide as the map below it, with words that keep rolling. When some place is
/// at Warning or Evacuate it names those places; otherwise it says nothing is at high risk, or (when the rig has gone
/// quiet) that there is no live reading, because it never says all is well on old data. Tap the words to open the map;
/// tap the arrow to fold it down to just its tag, and again to open it. A new place at Warning or Evacuate opens it
/// again by itself. With "reduce motion" on, the words stand still.
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
  static const _pixelsPerSecond = 42.0;
  static const _tagRed = Color(0xFFD6373F);
  static const _offlineOrange = Color(0xFFE8833A);
  final _scroll = ScrollController();
  late final Ticker _ticker = createTicker((elapsed) {
    if (_scroll.hasClients) _scroll.jumpTo(elapsed.inMicroseconds / 1e6 * _pixelsPerSecond);
  });
  bool _folded = false;
  int _seenRisky = 0;

  @override
  void dispose() {
    _ticker.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final risky = LiveBanner.atRisk(widget.nodes);
    // Folding away is for calm moments: when more places reach Warning or Evacuate than before, it opens by itself.
    if (risky.length > _seenRisky) _folded = false;
    _seenRisky = risky.length;

    final offline = widget.rigOffline && risky.isEmpty;
    final urgent = risky.isNotEmpty;
    final Color tagColor = urgent ? _tagRed : (offline ? const Color(0xFF7A4A22) : const Color(0xFF1F7A55));
    final Color tint = urgent ? riskStateColor(risky.first.state) : (offline ? _offlineOrange : AppColors.normal);
    final tag = urgent ? l10n.liveTag : (offline ? l10n.liveOffline : l10n.liveTag);
    final words = urgent
        ? risky.map((n) => '${riskStateLabel(context, n.state)}: ${n.name}').join('. ')
        : (offline ? l10n.liveQuietOffline : l10n.liveQuiet);

    final calm = MediaQuery.of(context).disableAnimations;
    final rolls = !_folded && !calm;
    if (rolls && !_ticker.isActive) {
      _ticker.start();
    } else if (!rolls && _ticker.isActive) {
      _ticker.stop();
    }

    final tagChip = Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(color: tagColor, borderRadius: BorderRadius.circular(999)),
      child: ExcludeSemantics(
        child: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
      ),
    );

    // its own node for screen readers, so its name is not read as part of the strip's line
    Widget toggle() => Semantics(
          container: true,
          button: true,
          label: _folded ? l10n.liveOpen : l10n.liveFold,
          child: Tooltip(
            message: _folded ? l10n.liveOpen : l10n.liveFold,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => setState(() => _folded = !_folded),
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(_folded ? Icons.chevron_right : Icons.expand_less, size: 20, color: AppColors.textSecondary),
              ),
            ),
          ),
        );

    final Widget bar;
    if (_folded) {
      // Just the tag and the arrow, tucked to the left.
      bar = Align(
        alignment: Alignment.centerLeft,
        child: Container(
          height: 34,
          padding: const EdgeInsets.only(left: 3, right: 2),
          decoration: _pill(tint),
          child: Row(mainAxisSize: MainAxisSize.min, children: [SizedBox(height: 28, child: tagChip), toggle()]),
        ),
      );
    } else {
      bar = Container(
        height: 34,
        padding: const EdgeInsets.only(left: 3),
        decoration: _pill(tint),
        child: Row(
          children: [
            SizedBox(height: 28, child: tagChip),
            // A loudspeaker, so the strip reads as an announcement. Decorative: the words carry the meaning.
            ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Icon(Icons.campaign, size: 22, color: urgent ? const Color(0xFFFF6B6B) : tint),
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTap,
                child: ExcludeSemantics(
                  child: ClipRect(
                    child: calm
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(words, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600)),
                            ),
                          )
                        : ListView.builder(
                            controller: _scroll,
                            scrollDirection: Axis.horizontal,
                            physics: const NeverScrollableScrollPhysics(),
                            // The same words come round again and again, with a gap between, so there is always something moving.
                            itemBuilder: (context, i) => _Rolling(text: words, accent: urgent ? tint : null),
                          ),
                  ),
                ),
              ),
            ),
            toggle(),
          ],
        ),
      );
    }

    return Semantics(
      container: true,
      liveRegion: true,
      label: '$tag. $words',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
        child: bar,
      ),
    );
  }

  BoxDecoration _pill(Color tint) => BoxDecoration(
        color: Color.alphaBlend(tint.withValues(alpha: 0.16), AppColors.surface),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: 0.35)),
      );
}

class _Rolling extends StatelessWidget {
  final String text;
  final Color? accent;
  const _Rolling({required this.text, this.accent});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 26),
          if (accent != null) ...[
            Container(width: 7, height: 7, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
            const SizedBox(width: 8),
          ],
          Text(text, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
