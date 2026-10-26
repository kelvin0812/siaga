import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../core/explainer_service.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import 'risk_badge.dart';

/// Merang, the otter. Its face follows the situation, so a glance tells you the mood of the river: calm, worried, alarmed,
/// shouting with a siren on its head (Evacuate), or fast asleep when the data is old.
enum MerangMood { calm, watch, alert, evacuate, sleepy }

MerangMood merangMoodFor(ExplainFacts f) {
  if (f.stale) return MerangMood.sleepy;
  return switch (f.state) {
    RiskState.normal => MerangMood.calm,
    RiskState.watch => MerangMood.watch,
    RiskState.warning => MerangMood.alert,
    RiskState.evacuate => MerangMood.evacuate,
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

  /// The small version for the header bar, where it covers nothing.
  final bool compact;
  const MerangButton({super.key, required this.facts, this.explainer = const LocalAsyncExplainer(), this.compact = false});

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
    final box = widget.compact ? 46.0 : 64.0;
    final circle = widget.compact ? 40.0 : 54.0;
    final face = widget.compact ? 34.0 : 46.0;
    final pad = widget.compact ? 3.0 : 4.0;
    final swell = widget.compact ? 6.0 : 10.0;
    return Semantics(
      button: true,
      label: l10n.merangAsk,
      child: Tooltip(
        message: l10n.merangAsk,
        child: SizedBox(
          width: box,
          height: box,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_urgent && !calm)
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) => Container(
                    width: circle + swell * _pulse.value,
                    height: circle + swell * _pulse.value,
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
                    width: circle,
                    height: circle,
                    child: Padding(padding: EdgeInsets.all(pad), child: MerangAvatar(mood: merangMoodFor(widget.facts), size: face)),
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
    builder: (sheetContext) {
      // Rises above the on-screen keyboard: the sheet is padded by the keyboard's height and shrinks to the room that is left.
      final m = MediaQuery.of(sheetContext);
      final room = m.size.height - m.viewInsets.bottom - m.padding.top - 8;
      return Padding(
        padding: EdgeInsets.only(bottom: m.viewInsets.bottom),
        child: SizedBox(
          height: math.min(m.size.height * 0.86, room),
          child: MerangSheet(facts: facts, explainer: explainer, typingDelay: typingDelay),
        ),
      );
    },
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
  final _input = TextEditingController();
  final _focus = FocusNode();
  bool _typing = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final l10n = AppLocalizations.of(context)!;
    final phase = riskStateLabel(context, widget.facts.state);
    // A greeting, then the question people most want answered, so the sheet is useful the moment it appears.
    // At Evacuate the first question is "what should I do?", because that is what someone in that moment needs.
    final first = !widget.facts.stale && widget.facts.state == RiskState.evacuate ? MerangQuestion.next : MerangQuestion.why;
    _messages.add(_Msg(true, l10n.merangHello));
    _messages.add(_Msg(false, _label(first, l10n, phase)));
    _typing = true;
    _deliver(() => widget.explainer.ask(first, widget.facts, l10n, phase));
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _label(MerangQuestion q, AppLocalizations l10n, String phase) => switch (q) {
        MerangQuestion.why => l10n.merangQWhy(phase),
        MerangQuestion.next => l10n.merangQNext,
        MerangQuestion.data => l10n.merangQData,
        MerangQuestion.how => l10n.merangQHow,
        MerangQuestion.tips => l10n.merangQTips,
        MerangQuestion.where => l10n.merangQWhere,
        MerangQuestion.bring => l10n.merangQBring,
        MerangQuestion.stuck => l10n.merangQStuck,
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
    await _deliver(() => widget.explainer.ask(q, widget.facts, l10n, phase));
  }

  /// Sends what was typed. The explainer decides how to answer; safety questions always get the fixed wording.
  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _typing) return;
    final l10n = AppLocalizations.of(context)!;
    final phase = riskStateLabel(context, widget.facts.state);
    _input.clear();
    setState(() {
      _messages.add(_Msg(false, text));
      _typing = true;
    });
    _toEnd();
    await _deliver(() => widget.explainer.askText(text, widget.facts, l10n, phase));
    if (mounted) _focus.requestFocus();
  }

  /// Shows the answer after at least a short "typing" pause, even when it is ready at once.
  Future<void> _deliver(Future<ExplainAnswer> Function() fetch) async {
    final both = await Future.wait<Object?>([fetch(), Future<void>.delayed(widget.typingDelay)]);
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
    // With the keyboard up there is little room, so the header shrinks and the small print waits.
    final compact = MediaQuery.of(context).viewInsets.bottom > 0;
    final canSend = !_typing && _input.text.trim().isNotEmpty;
    final chips = merangChipOrder(widget.facts);
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
            Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 8), decoration: BoxDecoration(color: AppColors.hairline, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: EdgeInsets.fromLTRB(18, compact ? 6 : 10, 8, compact ? 4 : 8),
              child: Row(
                children: [
                  MerangAvatar(mood: mood, size: compact ? 44 : 64),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.merangName, style: AppFonts.heading(fontSize: compact ? 20 : 24)),
                        if (!compact) ...[
                          const SizedBox(height: 2),
                          Text(l10n.merangTagline, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.3)),
                        ],
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
                  if (_typing) _TypingBubble(mood: mood),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (final q in chips) ...[
                      ActionChip(
                        label: Text(_label(q, l10n, phase), style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600)),
                        backgroundColor: AppColors.surfaceRaised,
                        side: BorderSide(color: AppColors.accent.withValues(alpha: 0.45)),
                        onPressed: _typing ? null : () => _ask(q),
                      ),
                      if (q != chips.last) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      focusNode: _focus,
                      maxLength: 200,
                      maxLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: l10n.merangInputHint,
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: const BorderSide(color: AppColors.hairline)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: canSend ? _send : null,
                    tooltip: l10n.merangSend,
                    icon: const Icon(Icons.arrow_upward_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.surfaceRaised,
                      disabledForegroundColor: AppColors.textMuted,
                      minimumSize: const Size(50, 50),
                    ),
                  ),
                ],
              ),
            ),
            if (!compact)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(padding: EdgeInsets.only(top: 1), child: Icon(Icons.info_outline, size: 14, color: AppColors.textMuted)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('${l10n.merangDisclaimer} ${l10n.merangTypedNote}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5, height: 1.4)),
                    ),
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
    const r = Radius.circular(AppRadius.md);
    const tail = Radius.circular(4);
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 480),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: mine ? AppColors.accent.withValues(alpha: 0.2) : AppColors.surfaceRaised,
        borderRadius: BorderRadius.only(topLeft: r, topRight: r, bottomLeft: mine ? r : tail, bottomRight: mine ? tail : r),
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

/// Three soft dots while Merang is "typing". With reduce-motion on they stand still, as an ellipsis.
class _TypingBubble extends StatefulWidget {
  final MerangMood mood;
  const _TypingBubble({required this.mood});

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    if (still) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
    final dots = still
        ? const Text('…', style: TextStyle(color: AppColors.textSecondary, fontSize: 20, height: 1))
        : AnimatedBuilder(
            animation: _c,
            builder: (context, child) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Opacity(
                      opacity: 0.35 + 0.65 * math.max(0.0, math.sin((_c.value - i * 0.18) * 2 * math.pi)),
                      child: const CircleAvatar(radius: 4, backgroundColor: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          MerangAvatar(mood: widget.mood, size: 34),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(AppRadius.md), topRight: Radius.circular(AppRadius.md), bottomRight: Radius.circular(AppRadius.md), bottomLeft: Radius.circular(4)),
              border: Border.all(color: AppColors.hairline),
            ),
            child: dots,
          ),
        ],
      ),
    );
  }
}
