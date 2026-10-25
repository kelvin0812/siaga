import '../l10n/app_localizations.dart';
import 'app_state.dart';
import 'models.dart';
import 'rig_controller.dart' show kRigNodeId;

/// What Merang can be asked.
enum MerangQuestion { why, next, data, how }

/// What a typed question is really about.
enum MerangIntent { safety, how, data, why, other }

/// Works out what a typed question is about, in English and Bahasa Malaysia. Questions about what to DO or whether it is
/// SAFE are recognised first, and always get the fixed "what should I do" wording, never a model's opinion.
MerangIntent intentFor(String text) {
  final t = text.toLowerCase();
  bool has(String pattern) => RegExp(pattern).hasMatch(t);
  if (has(r'evacuat|\bleave\b|\bgo now\b|should i (go|stay|move|run|leave)|\bsafe\b|\bsafety\b|danger|what (should|do|can) i do|what to do|\bmove out\b|\brun\b|berpindah|pindah|keluar|selamat|bahaya|apa (yang )?(patut|perlu|harus) (saya )?(buat|lakukan)|patut saya|perlu saya')) {
    return MerangIntent.safety;
  }
  if (has(r'how (do|does|did) (you|merang)|who are you|are you (an )?ai|what are you|bagaimana (anda|kamu|awak) berfungsi|siapa (anda|kamu|awak)|adakah (anda|kamu|awak) ai')) {
    return MerangIntent.how;
  }
  if (has(r'where.*(data|number|reading|come)|data source|\bsource\b|sensor|supabase|esp32|dari mana|sumber')) return MerangIntent.data;
  if (has(r'\bwhy\b|how come|\breason\b|explain|kenapa|mengapa|sebab|terang')) return MerangIntent.why;
  return MerangIntent.other;
}

/// The fixed question a typed one maps to, or null when it is something else entirely.
MerangQuestion? questionForIntent(MerangIntent i) => switch (i) {
      MerangIntent.safety => MerangQuestion.next,
      MerangIntent.how => MerangQuestion.how,
      MerangIntent.data => MerangQuestion.data,
      MerangIntent.why => MerangQuestion.why,
      MerangIntent.other => null,
    };

/// Everything the explainer is allowed to know: the numbers the screens already show. It is deliberately a small,
/// read-only snapshot with no location in it, so whatever sits behind [Explainer] (today fixed wording, later perhaps a
/// language model reached through our backend) cannot see or do more than the person looking at the screen.
class ExplainFacts {
  final RiskState state;
  final String nodeName;
  final bool isRigNode;
  final bool isDemoNode;

  /// The phase was forced from Settings to rehearse an alert, so the readings are made up to match it.
  final bool forced;

  /// The rig has gone quiet and what is shown is the last known reading.
  final bool stale;
  final Duration? age;
  final double? heightCm;

  /// How fast the water is rising over the last couple of minutes (negative = falling), or null when unknown.
  final double? risePerMin;

  const ExplainFacts({
    required this.state,
    this.nodeName = '',
    this.isRigNode = false,
    this.isDemoNode = false,
    this.forced = false,
    this.stale = false,
    this.age,
    this.heightCm,
    this.risePerMin,
  });

  factory ExplainFacts.from(AppState app, SiagaNode? node) {
    final isRig = app.rigMode && node != null && node.id == kRigNodeId;
    final rig = isRig ? app.rigReading : null;
    return ExplainFacts(
      state: node?.state ?? RiskState.normal,
      nodeName: node?.name ?? '',
      isRigNode: isRig,
      isDemoNode: node?.simulated ?? false,
      forced: rig?.simulated ?? false,
      stale: rig?.isStale ?? false,
      age: rig?.age,
      heightCm: rig?.heightCm,
      risePerMin: isRig ? risePerMinute(app.rigTrend) : null,
    );
  }

  /// The snapshot that may be sent to the explain function. Numbers and flags only, plus a node name: never a location.
  Map<String, dynamic> toJson() {
    double? r(double? v) => v == null || !v.isFinite ? null : double.parse(v.toStringAsFixed(2));
    return {
      'state': state.name,
      'nodeName': nodeName,
      'isRigNode': isRigNode,
      'isDemoNode': isDemoNode,
      'forced': forced,
      'stale': stale,
      'ageSeconds': age?.inSeconds,
      // Old readings and hand-set demo levels are not current numbers, so they are not sent.
      'heightCm': stale || forced ? null : r(heightCm),
      'risePerMin': stale || forced ? null : r(risePerMin),
    };
  }

  /// Change in water height per minute across the last [window] of the trend, or null if there is too little to say.
  static double? risePerMinute(List<RigPoint> trend, {Duration window = const Duration(minutes: 2)}) {
    if (trend.length < 2) return null;
    final last = trend.last;
    final from = trend.firstWhere((p) => !p.time.isBefore(last.time.subtract(window)), orElse: () => trend.first);
    final minutes = last.time.difference(from.time).inMilliseconds / 60000.0;
    if (minutes < 0.2) return null;
    return (last.heightCm - from.heightCm) / minutes;
  }
}

/// An answer, and whether an AI model wrote it (so the screen can say so).
class ExplainAnswer {
  final List<String> paragraphs;
  final bool byAi;
  const ExplainAnswer(this.paragraphs, {this.byAi = false});
}

/// What the chat sheet talks to. It may take a moment (a model on the network), and it must never throw: when it cannot
/// answer it falls back to the fixed wording.
abstract class AsyncExplainer {
  Future<ExplainAnswer> ask(MerangQuestion q, ExplainFacts facts, AppLocalizations l10n, String phaseLabel);

  /// A question the resident typed. Questions about what to do or whether it is safe are always answered with the fixed
  /// wording, whatever implements this.
  Future<ExplainAnswer> askText(String text, ExplainFacts facts, AppLocalizations l10n, String phaseLabel);
}

/// Turns [ExplainFacts] into plain words. Today this is fixed wording filled with the real numbers, so it works offline
/// and can never say something the numbers do not support. A language model could implement the same interface behind
/// our backend later; it would receive only [ExplainFacts], and it would still only explain, never decide or send alerts.
abstract class Explainer {
  List<String> answer(MerangQuestion q, ExplainFacts facts, AppLocalizations l10n, String phaseLabel);
}

class LocalExplainer implements Explainer {
  const LocalExplainer();

  static String _ago(Duration d) {
    if (d.inSeconds < 90) return '${d.inSeconds} s';
    if (d.inMinutes < 90) return '${d.inMinutes} min';
    if (d.inHours < 48) return '${d.inHours} h';
    return '${d.inDays} d';
  }

  @override
  List<String> answer(MerangQuestion q, ExplainFacts f, AppLocalizations l10n, String phaseLabel) {
    switch (q) {
      case MerangQuestion.why:
        return _why(f, l10n, phaseLabel);
      case MerangQuestion.next:
        final byState = switch (f.state) {
          RiskState.normal => l10n.merangNextNormal,
          RiskState.watch => l10n.merangNextWatch,
          RiskState.warning => l10n.merangNextWarning,
          RiskState.evacuate => l10n.merangNextEvacuate,
        };
        return [if (f.stale) l10n.merangNextStale else byState, l10n.merangNextOfficial];
      case MerangQuestion.data:
        if (f.isRigNode) {
          return [l10n.merangDataRig, if (f.age != null && !f.forced) l10n.merangDataAgo(_ago(f.age!))];
        }
        if (f.isDemoNode) return [l10n.merangDataSim];
        return [l10n.merangDataOther];
      case MerangQuestion.how:
        return [l10n.merangHow];
    }
  }

  List<String> _why(ExplainFacts f, AppLocalizations l10n, String phaseLabel) {
    if (!f.isRigNode) {
      return [l10n.merangWhyNoRig(f.nodeName, phaseLabel), if (f.isDemoNode) l10n.merangWhyDemoNode];
    }
    if (f.forced) return [l10n.merangWhySimulated, l10n.merangWhyBands];
    final out = <String>[];
    if (f.stale && f.age != null) {
      // Old readings are not described as if they were happening now: say why the app shows Normal, and stop.
      return [l10n.merangWhyStale(_ago(f.age!)), l10n.merangWhyBands];
    }
    final h = f.heightCm;
    if (h != null) {
      out.add(h > 0.3 ? l10n.merangWhyLevel(h.toStringAsFixed(1)) : l10n.merangWhyLevelNormal);
    }
    final r = f.risePerMin;
    if (r != null) {
      if (r >= 0.3) {
        out.add(l10n.merangRiseFast(r.toStringAsFixed(1)));
      } else if (r >= 0.05) {
        out.add(l10n.merangRiseSlow);
      } else if (r > -0.05) {
        out.add(l10n.merangRiseSteady);
      } else {
        out.add(l10n.merangFalling((-r).toStringAsFixed(1)));
      }
    }
    out.add(l10n.merangWhyBands);
    out.add(l10n.merangWhyOthers);
    return out;
  }
}

class LocalAsyncExplainer implements AsyncExplainer {
  final LocalExplainer local;
  const LocalAsyncExplainer([this.local = const LocalExplainer()]);

  @override
  Future<ExplainAnswer> ask(MerangQuestion q, ExplainFacts facts, AppLocalizations l10n, String phaseLabel) async =>
      ExplainAnswer(local.answer(q, facts, l10n, phaseLabel));

  /// Without a model, a typed question is matched to the closest fixed answer, or Merang says it can only answer those.
  @override
  Future<ExplainAnswer> askText(String text, ExplainFacts facts, AppLocalizations l10n, String phaseLabel) async {
    final q = questionForIntent(intentFor(text));
    if (q == null) return ExplainAnswer([l10n.merangNoAi]);
    return ask(q, facts, l10n, phaseLabel);
  }
}
