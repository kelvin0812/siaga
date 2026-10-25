import 'dart:convert';
import 'package:http/http.dart' as http;
import '../l10n/app_localizations.dart';
import 'bench_sensor_service.dart';
import 'explainer_service.dart';

/// Merang with Gemini behind it. The app never holds the Gemini key: it calls our own `explain` function on Supabase, which
/// holds the key, builds the prompt itself from a small read-only snapshot, and checks the reply.
///
/// Only the explain questions go to the model: "why", "where does the data come from", and a question the resident
/// typed that is about something else. "What should I do?", anything about whether it is safe, and "How do you work?" stay
/// fixed wording, because safety advice must not depend on a model. If the function is slow, offline, not deployed or
/// refuses, the answer is the fixed wording instead, so Merang never goes silent.
class GeminiExplainer implements AsyncExplainer {
  final http.Client _client;
  final Uri endpoint;
  final String _anonKey;
  final Duration timeout;
  final LocalExplainer local;

  GeminiExplainer({
    http.Client? client,
    Uri? endpoint,
    String? anonKey,
    this.timeout = const Duration(seconds: 11),
    this.local = const LocalExplainer(),
  })  : _client = client ?? http.Client(),
        endpoint = endpoint ?? Uri.parse('${BenchSensorService.baseUrl}/functions/v1/explain'),
        _anonKey = anonKey ?? BenchSensorService.anonKey;

  static bool _wantsAi(MerangQuestion q) => q == MerangQuestion.why || q == MerangQuestion.data;

  /// Posts a request to the function and returns the model's text, or null for any kind of failure.
  Future<String?> _post(Map<String, Object?> body) async {
    try {
      final res = await _client
          .post(
            endpoint,
            headers: {'Content-Type': 'application/json', 'apikey': _anonKey, 'Authorization': 'Bearer $_anonKey'},
            body: jsonEncode(body),
          )
          .timeout(timeout);
      if (res.statusCode != 200) return null;
      final text = (jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>)['text'];
      if (text is! String || text.trim().length < 20) return null;
      return text.trim();
    } catch (_) {
      return null; // offline, slow, not deployed, or an unexpected reply
    }
  }

  static String _lang(AppLocalizations l10n) => l10n.localeName == 'ms' ? 'ms' : 'en';

  @override
  Future<ExplainAnswer> ask(MerangQuestion q, ExplainFacts facts, AppLocalizations l10n, String phaseLabel) async {
    final fallback = ExplainAnswer(local.answer(q, facts, l10n, phaseLabel));
    if (!_wantsAi(q)) return fallback;
    final text = await _post({'lang': _lang(l10n), 'question': q.name, 'facts': facts.toJson()});
    return text == null ? fallback : ExplainAnswer([text], byAi: true);
  }

  @override
  Future<ExplainAnswer> askText(String text, ExplainFacts facts, AppLocalizations l10n, String phaseLabel) async {
    // A question we already have an answer for (including every safety question) takes the same path as the buttons.
    final known = questionForIntent(intentFor(text));
    if (known != null) return ask(known, facts, l10n, phaseLabel);
    final typed = text.trim();
    if (typed.isEmpty) return ExplainAnswer([l10n.merangNoAi]);
    final reply = await _post({
      'lang': _lang(l10n),
      'question': 'ask',
      'text': typed.length > 200 ? typed.substring(0, 200) : typed,
      'facts': facts.toJson(),
    });
    return reply == null ? ExplainAnswer([l10n.merangNoAi]) : ExplainAnswer([reply], byAi: true);
  }
}
