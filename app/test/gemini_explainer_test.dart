import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:siaga_app/core/explainer_service.dart';
import 'package:siaga_app/core/gemini_explainer.dart';
import 'package:siaga_app/core/models.dart';
import 'package:siaga_app/core/theme.dart';
import 'package:siaga_app/l10n/app_localizations.dart';
import 'package:siaga_app/l10n/app_localizations_en.dart';
import 'package:siaga_app/l10n/app_localizations_ms.dart';
import 'package:siaga_app/widgets/merang_sheet.dart';

const _facts = ExplainFacts(
  state: RiskState.warning,
  nodeName: 'Bench rig (live)',
  isRigNode: true,
  heightCm: 3.2456,
  risePerMin: 0.8123,
  age: Duration(seconds: 3),
);
final _en = AppLocalizationsEn();
final _ms = AppLocalizationsMs();
const _aiText = 'The water is 3.2 cm above its normal level and still rising, so the app shows Warning.';

http.Response _ok(String text) => http.Response(jsonEncode({'text': text, 'model': 'gemini-3.8-flash'}), 200, headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  test('a question about why goes to the function with only numbers and flags, and the reply is marked as AI', () async {
    late http.Request seen;
    final ex = GeminiExplainer(client: MockClient((r) async {
      seen = r;
      return _ok(_aiText);
    }));
    final a = await ex.ask(MerangQuestion.why, _facts, _en, 'Warning');
    expect(a.byAi, isTrue);
    expect(a.paragraphs, [_aiText]);
    expect(seen.method, 'POST');
    expect(seen.url.path, endsWith('/functions/v1/explain'));
    expect(seen.headers['Authorization'], startsWith('Bearer '));
    final body = jsonDecode(seen.body) as Map<String, dynamic>;
    expect(body.keys.toSet(), {'lang', 'question', 'facts'}); // no free text, nothing else
    expect(body['lang'], 'en');
    expect(body['question'], 'why');
    expect((body['facts'] as Map).keys.toSet(),
        {'state', 'nodeName', 'isRigNode', 'isDemoNode', 'forced', 'stale', 'ageSeconds', 'heightCm', 'risePerMin'});
    expect((body['facts'] as Map)['heightCm'], 3.25); // tidy numbers
  });

  test('no location can ever be in what is sent', () async {
    String? sent;
    final ex = GeminiExplainer(client: MockClient((r) async {
      sent = r.body;
      return _ok(_aiText);
    }));
    await ex.ask(MerangQuestion.data, _facts, _en, 'Warning');
    expect(sent, isNotNull);
    expect(sent!.toLowerCase(), isNot(contains('lat')));
    expect(sent!.toLowerCase(), isNot(contains('lon')));
    expect(sent!.toLowerCase(), isNot(contains('gps')));
    expect(sent!.toLowerCase(), isNot(contains('cell')));
  });

  test('old readings and hand-set levels are not sent as numbers', () async {
    final bodies = <Map<String, dynamic>>[];
    final ex = GeminiExplainer(client: MockClient((r) async {
      bodies.add((jsonDecode(r.body) as Map<String, dynamic>)['facts'] as Map<String, dynamic>);
      return _ok(_aiText);
    }));
    await ex.ask(MerangQuestion.why, const ExplainFacts(state: RiskState.normal, isRigNode: true, stale: true, age: Duration(hours: 20), heightCm: 3.2, risePerMin: 0.8), _en, 'Normal');
    await ex.ask(MerangQuestion.why, const ExplainFacts(state: RiskState.evacuate, isRigNode: true, forced: true, heightCm: 4.5, risePerMin: 0.0), _en, 'Evacuate');
    expect(bodies[0]['heightCm'], isNull);
    expect(bodies[0]['risePerMin'], isNull);
    expect(bodies[0]['ageSeconds'], 72000); // how old it is is still said
    expect(bodies[1]['heightCm'], isNull);
    expect(bodies[1]['risePerMin'], isNull);
  });

  test('the language follows the app', () async {
    String? lang;
    final ex = GeminiExplainer(client: MockClient((r) async {
      lang = (jsonDecode(r.body) as Map)['lang'] as String;
      return _ok(_aiText);
    }));
    await ex.ask(MerangQuestion.why, _facts, _ms, 'Amaran');
    expect(lang, 'ms');
  });

  test('safety advice and how Merang works never go to the model', () async {
    var calls = 0;
    final ex = GeminiExplainer(client: MockClient((r) async {
      calls++;
      return _ok(_aiText);
    }));
    final next = await ex.ask(MerangQuestion.next, _facts, _en, 'Warning');
    final how = await ex.ask(MerangQuestion.how, _facts, _en, 'Warning');
    expect(calls, 0);
    expect(next.byAi, isFalse);
    expect(next.paragraphs.join(' '), contains('Get ready to move'));
    expect(how.byAi, isFalse);
  });

  group('when anything goes wrong the fixed wording answers instead', () {
    final local = const LocalExplainer().answer(MerangQuestion.why, _facts, _en, 'Warning');

    Future<void> expectsFallback(http.Client client, {Duration timeout = const Duration(seconds: 2)}) async {
      final a = await GeminiExplainer(client: client, timeout: timeout).ask(MerangQuestion.why, _facts, _en, 'Warning');
      expect(a.byAi, isFalse);
      expect(a.paragraphs, local);
    }

    test('the function is not deployed or refuses', () async {
      await expectsFallback(MockClient((_) async => http.Response('not found', 404)));
      await expectsFallback(MockClient((_) async => http.Response('{"error":"upstream"}', 502)));
      await expectsFallback(MockClient((_) async => http.Response('{"error":"slow down"}', 429)));
    });

    test('the phone is offline', () async {
      await expectsFallback(MockClient((_) async => throw http.ClientException('Failed host lookup')));
    });

    test('the reply is slow', () async {
      await expectsFallback(
        MockClient((_) => Future.delayed(const Duration(milliseconds: 400), () => _ok(_aiText))),
        timeout: const Duration(milliseconds: 60),
      );
    });

    test('the reply is empty, too short, or not what was expected', () async {
      await expectsFallback(MockClient((_) async => _ok('')));
      await expectsFallback(MockClient((_) async => _ok('ok')));
      await expectsFallback(MockClient((_) async => http.Response('not json', 200)));
      await expectsFallback(MockClient((_) async => http.Response(jsonEncode({'text': 42}), 200)));
      await expectsFallback(MockClient((_) async => http.Response(jsonEncode(['x']), 200)));
    });
  });

  group('in the chat sheet', () {
    Future<void> open(WidgetTester tester, AsyncExplainer explainer) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: SiagaTheme.dark(),
          builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(disableAnimations: true), child: child!),
          home: Scaffold(body: const SizedBox.expand(), floatingActionButton: MerangButton(facts: _facts, explainer: explainer)),
        ),
      );
      await tester.tap(find.byType(MerangButton));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
    }

    testWidgets('an answer written by the model carries the AI tag', (tester) async {
      await open(tester, GeminiExplainer(client: MockClient((_) async => _ok(_aiText))));
      expect(find.textContaining('still rising, so the app shows Warning'), findsOneWidget);
      expect(find.text('Written by AI (Gemini). Check the official channels.'), findsOneWidget);
    });

    testWidgets('a fixed-wording answer carries no AI tag', (tester) async {
      await open(tester, GeminiExplainer(client: MockClient((_) async => http.Response('nope', 500))));
      expect(find.textContaining('3.2 cm above its normal level'), findsOneWidget);
      expect(find.textContaining('Written by AI'), findsNothing);
    });

    testWidgets('the sheet opens with a typing pause while the model thinks, and still answers', (tester) async {
      final gate = Completer<http.Response>();
      await open0(tester, GeminiExplainer(client: MockClient((_) => gate.future)));
      expect(find.text('…'), findsOneWidget); // Merang is thinking
      gate.complete(_ok(_aiText));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.textContaining('still rising, so the app shows Warning'), findsOneWidget);
      expect(find.text('…'), findsNothing);
    });
  });
}

/// Like the other helper but does not wait for the answer.
Future<void> open0(WidgetTester tester, AsyncExplainer explainer) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: SiagaTheme.dark(),
      builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(disableAnimations: true), child: child!),
      home: Scaffold(body: const SizedBox.expand(), floatingActionButton: MerangButton(facts: _facts, explainer: explainer)),
    ),
  );
  await tester.tap(find.byType(MerangButton));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}
