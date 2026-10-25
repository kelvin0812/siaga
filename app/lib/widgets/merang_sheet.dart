import 'package:flutter/material.dart';
import '../core/explainer_service.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import 'risk_badge.dart';

/// Merang, the otter. Its face follows the situation, so a glance tells you the mood of the river.
enum MerangMood { calm, watch, alert, sleepy }

MerangMood merangMoodFor(ExplainFacts f) {
  if (f.stale) return MerangMood.sleepy;
  return switch (f.state) {
    RiskState.normal => MerangMood.calm,
    RiskState.watch => MerangMood.watch,
    RiskState.warning || RiskState.evacuate => MerangMood.alert,
  };
}

class MerangAvatar extends StatelessWidget {
  final MerangMood mood;
  final double size;
  const MerangAvatar({super.key, required this.mood, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/mascot/otter_${mood.name}.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    );
  }
}

/// Merang, always one tap away: a round otter button fixed at the bottom right, above the nav bar, on every page.
/// Its face and the colour of its ring follow the situation, and the ring pulses when the level is Warning or higher.
class MerangButton extends StatefulWidget {
  final ExplainFacts facts;
  final AsyncExplainer explainer;
  const MerangButton({super.key, required this.facts, this.explainer = const LocalAsyncExplainer()});

  @override
  State<MerangButton> createState() => _MerangButtonState();
}

class _MerangButtonState extends State<MerangButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  bool get _urgent => !widget.facts.stale && widget.facts.state.index >= RiskState.warning.index;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final calm = MediaQuery.of(context).disableAnimations; // respects "reduce motion"
    if (_urgent && !calm) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else if (_pulse.isAnimating) {
      _pulse.stop();
    }
    final ring = widget.facts.stale ? AppColors.textMuted : riskStateColor(widget.facts.state);
    return Semantics(
      button: true,
      label: l10n.merangAsk,
      child: Tooltip(
        message: l10n.merangAsk,
        child: SizedBox(
          width: 76,
          height: 76,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_urgent && !calm)
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) => Container(
                    width: 64 + 12 * _pulse.value,
                    height: 64 + 12 * _pulse.value,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ring.withValues(alpha: 0.6 * (1 - _pulse.value)), width: 3)),
                  ),
                ),
              Material(
                color: AppColors.surface,
                shape: CircleBorder(side: BorderSide(color: ring, width: 3)),
                elevation: 6,
                shadowColor: ring,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => showMerang(context, widget.facts, explainer: widget.explainer),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: Padding(padding: const EdgeInsets.all(5), child: MerangAvatar(mood: merangMoodFor(widget.facts), size: 54)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showMerang(BuildContext context, ExplainFacts facts, {AsyncExplainer explainer = const LocalAsyncExplainer(), Duration typingDelay = const Duration(milliseconds: 380)}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.86,
      child: MerangSheet(facts: facts, explainer: explainer, typingDelay: typingDelay),
    ),
  );
}

class _Msg {
  final bool fromMerang;
  final String text;
  final bool byAi;
  const _Msg(this.fromMerang, this.text, {this.byAi = false});
}

class MerangSheet extends StatefulWidget {
  final ExplainFacts facts;
  final AsyncExplainer explainer;
  final Duration typingDelay;
  const MerangSheet({super.key, required this.facts, this.explainer = const LocalAsyncExplainer(), this.typingDelay = const Duration(milliseconds: 380)});

  @override
  State<MerangSheet> createState() => _MerangSheetState();
}

class _MerangSheetState extends State<MerangSheet> {
  final _messages = <_Msg>[];
  final _scroll = ScrollController();
  bool _typing = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Open with the question people most want answered, so the sheet is useful the moment it appears.
    final l10n = AppLocalizations.of(context)!;
    final phase = riskStateLabel(context, widget.facts.state);
    _messages.add(_Msg(false, l10n.merangQWhy(phase)));
    _typing = true;
    _respond(MerangQuestion.why, l10n, phase);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String _label(MerangQuestion q, AppLocalizations l10n, String phase) => switch (q) {
        MerangQuestion.why => l10n.merangQWhy(phase),
        MerangQuestion.next => l10n.merangQNext,
        MerangQuestion.data => l10n.merangQData,
        MerangQuestion.how => l10n.merangQHow,
      };

  Future<void> _ask(MerangQuestion q) async {
    if (_typing) return;
    final l10n = AppLocalizations.of(context)!;
    final phase = riskStateLabel(context, widget.facts.state);
    setState(() {
      _messages.add(_Msg(false, _label(q, l10n, phase)));
      _typing = true;
    });
    _toEnd();
    await _respond(q, l10n, phase);
  }

  /// Asks the explainer (which may be a model on the network) and shows the answer after at least a short "typing" pause.
  Future<void> _respond(MerangQuestion q, AppLocalizations l10n, String phase) async {
    final both = await Future.wait<Object?>([widget.explainer.ask(q, widget.facts, l10n, phase), Future<void>.delayed(widget.typingDelay)]);
    final answer = both.first as ExplainAnswer;
    if (!mounted) return;
    setState(() {
      _messages.add(_Msg(true, answer.paragraphs.join('\n\n'), byAi: answer.byAi));
      _typing = false;
    });
    _toEnd();
  }

  void _toEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mood = merangMoodFor(widget.facts);
    final phase = riskStateLabel(context, widget.facts.state);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        border: Border(top: BorderSide(color: AppColors.hairline), left: BorderSide(color: AppColors.hairline), right: BorderSide(color: AppColors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 6),
              child: Row(
                children: [
                  MerangAvatar(mood: mood, size: 64),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.merangName, style: AppFonts.heading(fontSize: 24)),
                        const SizedBox(height: 2),
                        Text(l10n.merangTagline, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.3)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.hairline),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                children: [
                  for (final m in _messages) _Bubble(msg: m, mood: mood),
                  if (_typing) _Bubble(msg: const _Msg(true, '…'), mood: mood),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final q in MerangQuestion.values)
                    ActionChip(
                      label: Text(_label(q, l10n, phase), style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600)),
                      backgroundColor: AppColors.surfaceRaised,
                      side: BorderSide(color: AppColors.accent.withValues(alpha: 0.45)),
                      onPressed: _typing ? null : () => _ask(q),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(padding: EdgeInsets.only(top: 1), child: Icon(Icons.info_outline, size: 14, color: AppColors.textMuted)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l10n.merangDisclaimer, style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5, height: 1.4))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final _Msg msg;
  final MerangMood mood;
  const _Bubble({required this.msg, required this.mood});

  @override
  Widget build(BuildContext context) {
    final mine = !msg.fromMerang;
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 480),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: mine ? AppColors.accent.withValues(alpha: 0.2) : AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: mine ? AppColors.accent.withValues(alpha: 0.5) : AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(msg.text, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.45)),
          if (msg.byAi) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, size: 13, color: AppColors.accent),
                const SizedBox(width: 6),
                Flexible(child: Text(AppLocalizations.of(context)!.merangAiTag, style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5))),
              ],
            ),
          ],
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[MerangAvatar(mood: mood, size: 34), const SizedBox(width: 8)],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}
