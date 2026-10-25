import 'dart:convert';
import 'package:http/http.dart' as http;
import '../l10n/app_localizations.dart';
import 'bench_sensor_service.dart';
import 'explainer_service.dart';

/// Merang with Gemini behind it. The app never holds the Gemini key: it calls our own `explain` function on Supabase, which
/// holds the key, builds the prompt itself from a small read-only snapshot, and checks the reply.
///
/// Only the two "explain" questions go to the model. "What should I do?" and "How do you work?" stay fixed wording, because
/// safety advice must not depend on a model. If the function is slow, offline, not deployed or refuses, the answer is
/// the fixed wording instead, so Merang never goes silent.
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
    this.timeout = const Duration(seconds: 9),
    this.local = const LocalExplainer(),
  })  : _client = client ?? http.Client(),
        endpoint = endpoint ?? Uri.parse('${BenchSensorService.baseUrl}/functions/v1/explain'),
        _anonKey = anonKey ?? BenchSensorService.anonKey;

  static bool _wantsAi(MerangQuestion q) => q == MerangQuestion.why || q == MerangQuestion.data;

  @override
  Future<ExplainAnswer> ask(MerangQuestion q, ExplainFacts facts, AppLocalizations l10n, String phaseLabel) async {
    final fallback = ExplainAnswer(local.answer(q, facts, l10n, phaseLabel));
    if (!_wantsAi(q)) return fallback;
    try {
      final res = await _client
          .post(
            endpoint,
            headers: {'Content-Type': 'application/json', 'apikey': _anonKey, 'Authorization': 'Bearer $_anonKey'},
            body: jsonEncode({'lang': l10n.localeName == 'ms' ? 'ms' : 'en', 'question': q.name, 'facts': facts.toJson()}),
          )
          .timeout(timeout);
      if (res.statusCode != 200) return fallback;
      final text = (jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>)['text'];
      if (text is! String || text.trim().length < 20) return fallback;
      return ExplainAnswer([text.trim()], byAi: true);
    } catch (_) {
      return fallback; // offline, slow, not deployed, or an unexpected reply
    }
  }
}
