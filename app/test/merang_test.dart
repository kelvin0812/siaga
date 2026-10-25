import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siaga_app/core/explainer_service.dart';
import 'package:siaga_app/core/models.dart';
import 'package:siaga_app/core/theme.dart';
import 'package:siaga_app/l10n/app_localizations.dart';
import 'package:siaga_app/l10n/app_localizations_en.dart';
import 'package:siaga_app/l10n/app_localizations_ms.dart';
import 'package:siaga_app/widgets/merang_sheet.dart';

final _en = AppLocalizationsEn();
final _ms = AppLocalizationsMs();
const _explainer = LocalExplainer();

String _why(ExplainFacts f, [AppLocalizations? l10n, String phase = 'Warning']) =>
    _explainer.answer(MerangQuestion.why, f, l10n ?? _en, phase).join(' ');

void main() {
  group('the rise rate', () {
    final t0 = DateTime(2026, 10, 25, 12);
    RigPoint p(int seconds, double h) => RigPoint(time: t0.add(Duration(seconds: seconds)), heightCm: h, flow: 0, soilRaw: 0, tiltDeg: 0, phase: 1);

    test('is the change in height per minute over the last two minutes', () {
      final trend = [p(0, 1.0), p(60, 2.0), p(120, 3.0), p(180, 4.0)];
      expect(ExplainFacts.risePerMinute(trend), closeTo(1.0, 1e-9));
    });

    test('is negative when the water is going down', () {
      expect(ExplainFacts.risePerMinute([p(0, 3.0), p(60, 2.0), p(120, 1.0)]), closeTo(-1.0, 1e-9));
    });

    test('is unknown with too little data', () {
      expect(ExplainFacts.risePerMinute(const []), isNull);
      expect(ExplainFacts.risePerMinute([p(0, 1.0)]), isNull);
      expect(ExplainFacts.risePerMinute([p(0, 1.0), p(5, 1.2)]), isNull); // under a fifth of a minute apart
    });
  });

  group('why', () {
    test('quotes the real height and rise rate for the live rig', () {
      final text = _why(const ExplainFacts(state: RiskState.warning, isRigNode: true, heightCm: 3.24, risePerMin: 0.84, age: Duration(seconds: 3)));
      expect(text, contains('3.2 cm above its normal level'));
      expect(text, contains('rising, about 0.8 cm every minute'));
      expect(text, contains('Watch starts near 0.8 cm')); // the real band edges of the bench rig
      expect(text, contains('water level matters most'));
    });

    test('says steady, slow, or falling as the numbers say', () {
      String whenRising(double r) => _why(ExplainFacts(state: RiskState.watch, isRigNode: true, heightCm: 1.5, risePerMin: r));
      expect(whenRising(0.0), contains('steady'));
      expect(whenRising(0.1), contains('rising slowly'));
      expect(whenRising(-0.6), contains('going down, about 0.6 cm'));
    });

    test('calls a level near zero normal', () {
      expect(_why(const ExplainFacts(state: RiskState.normal, isRigNode: true, heightCm: 0.1, risePerMin: 0.0)), contains('at its normal level'));
    });

    test('is open about a phase that was forced for a demonstration', () {
      final text = _why(const ExplainFacts(state: RiskState.evacuate, isRigNode: true, forced: true, heightCm: 4.5));
      expect(text, contains('set by hand in Settings'));
      expect(text, isNot(contains('cm above its normal level'))); // the made-up numbers are not quoted as if live
    });

    test('says the data is old instead of explaining it as live', () {
      final text = _why(const ExplainFacts(state: RiskState.normal, isRigNode: true, stale: true, age: Duration(minutes: 14), heightCm: 2.0, risePerMin: 0.5));
      expect(text, contains('not sent anything for 14 min'));
      expect(text, isNot(contains('rising')));
      expect(text, isNot(contains('cm above its normal level'))); // the old numbers are not quoted as if current
      expect(text, contains('shows Normal rather than raising an alert'));
    });

    test('has only a summary for nodes that are not the rig', () {
      final text = _why(const ExplainFacts(state: RiskState.watch, nodeName: 'Lake bank (demo)', isDemoNode: true), _en, 'Watch');
      expect(text, contains('Lake bank (demo) is at Watch'));
      expect(text, contains('demo node'));
    });
  });

  group('what to do', () {
    test('matches the level and always points to the official channels', () {
      final expected = {
        RiskState.normal: 'Nothing to do right now',
        RiskState.watch: 'Stay alert',
        RiskState.warning: 'Get ready to move',
        RiskState.evacuate: 'Leave now',
      };
      for (final e in expected.entries) {
        final text = _explainer.answer(MerangQuestion.next, ExplainFacts(state: e.key), _en, '').join(' ');
        expect(text, contains(e.value));
        expect(text, contains('NADMA'));
        expect(text, contains('not an official warning'));
      }
    });

    test('does not tell anyone to act on old data', () {
      final text = _explainer.answer(MerangQuestion.next, const ExplainFacts(state: RiskState.evacuate, stale: true), _en, '').join(' ');
      expect(text, contains('data is old'));
      expect(text, isNot(contains('Leave now')));
    });
  });

  group('where the data comes from', () {
    test('the rig says how its numbers travel, a demo node says it is simulated', () {
      final rig = _explainer.answer(MerangQuestion.data, const ExplainFacts(state: RiskState.normal, isRigNode: true, age: Duration(seconds: 5)), _en, '').join(' ');
      expect(rig, contains('ESP32'));
      expect(rig, contains('Supabase'));
      expect(rig, contains('5 s ago'));
      final demo = _explainer.answer(MerangQuestion.data, const ExplainFacts(state: RiskState.normal, isDemoNode: true), _en, '').join(' ');
      expect(demo, contains('simulated'));
    });
  });

  test('how it works says that it never decides alerts and keeps location on the phone', () {
    final text = _explainer.answer(MerangQuestion.how, const ExplainFacts(state: RiskState.normal), _en, '').join(' ');
    expect(text, contains('not me'));
    expect(text, contains('location never leaves'));
  });

  test('every answer exists in Bahasa Malaysia too', () {
    for (final q in MerangQuestion.values) {
      for (final s in RiskState.values) {
        final facts = ExplainFacts(state: s, nodeName: 'Nod', isRigNode: true, heightCm: 2.5, risePerMin: 0.5, age: const Duration(seconds: 4));
        final ms = _explainer.answer(q, facts, _ms, 'Amaran').join(' ');
        final en = _explainer.answer(q, facts, _en, 'Warning').join(' ');
        expect(ms.trim(), isNotEmpty);
        expect(ms, isNot(equals(en)), reason: '$q $s is not translated');
      }
    }
  });

  test('the otter looks as the river looks', () {
    expect(merangMoodFor(const ExplainFacts(state: RiskState.normal)), MerangMood.calm);
    expect(merangMoodFor(const ExplainFacts(state: RiskState.watch)), MerangMood.watch);
    expect(merangMoodFor(const ExplainFacts(state: RiskState.warning)), MerangMood.alert);
    expect(merangMoodFor(const ExplainFacts(state: RiskState.evacuate)), MerangMood.alert);
    expect(merangMoodFor(const ExplainFacts(state: RiskState.evacuate, stale: true)), MerangMood.sleepy); // old data: not shouting
  });

  group('the chat sheet', () {
    const facts = ExplainFacts(state: RiskState.warning, nodeName: 'Bench rig (live)', isRigNode: true, heightCm: 3.2, risePerMin: 0.8, age: Duration(seconds: 3));

    Future<void> open(WidgetTester tester, {Locale locale = const Locale('en'), Size size = const Size(420, 900)}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: SiagaTheme.dark(),
          builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(disableAnimations: true), child: child!), // no endless pulse in tests
          home: const Scaffold(body: SizedBox.expand(), floatingActionButton: MerangButton(facts: facts), floatingActionButtonLocation: FloatingActionButtonLocation.endFloat),
        ),
      );
      await tester.tap(find.byType(MerangButton));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 600)); // the opening answer arrives after a short typing pause
      await tester.pumpAndSettle();
    }

    testWidgets('opens already answering why, and offers the other questions', (tester) async {
      await open(tester);
      expect(find.text('Merang'), findsOneWidget);
      expect(find.text('Why is it Warning?'), findsWidgets); // the opening question and its chip
      expect(find.textContaining('3.2 cm above its normal level'), findsOneWidget);
      for (final q in ['What should I do?', 'Where does this data come from?', 'How do you work?']) {
        expect(find.widgetWithText(ActionChip, q), findsOneWidget);
      }
      expect(find.textContaining('I do not decide or send alerts'), findsOneWidget);
    });

    testWidgets('a tapped question is answered after a short pause', (tester) async {
      await open(tester);
      await tester.ensureVisible(find.widgetWithText(ActionChip, 'What should I do?'));
      await tester.tap(find.widgetWithText(ActionChip, 'What should I do?'));
      await tester.pump();
      expect(find.widgetWithText(ActionChip, 'What should I do?').evaluate().isNotEmpty, isTrue);
      await tester.pump(const Duration(milliseconds: 600)); // the short "typing" pause
      await tester.pumpAndSettle();
      expect(find.textContaining('Get ready to move'), findsOneWidget);
      expect(find.textContaining('NADMA'), findsWidgets);
    });

    testWidgets('sits at the bottom right and can be tapped from any page', (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: SiagaTheme.dark(),
          builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(disableAnimations: true), child: child!),
          home: const Scaffold(body: SizedBox.expand(), floatingActionButton: MerangButton(facts: facts), floatingActionButtonLocation: FloatingActionButtonLocation.endFloat),
        ),
      );
      final box = tester.getRect(find.byType(MerangButton));
      expect(box.right, greaterThan(380)); // right edge of a 420 px screen
      expect(box.bottom, greaterThan(800)); // bottom of a 900 px screen
      expect(find.bySemanticsLabel('Ask Merang'), findsOneWidget);
    });

    testWidgets('pulses only when the level is Warning or higher, and not on old data', (tester) async {
      Future<bool> pulsing(ExplainFacts f) async {
        await tester.pumpWidget(MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: Center(child: MerangButton(facts: f))),
        ));
        await tester.pump(const Duration(milliseconds: 400));
        final animating = tester.binding.hasScheduledFrame;
        await tester.pumpWidget(const SizedBox()); // stop any repeating animation before the test ends
        return animating;
      }

      expect(await pulsing(const ExplainFacts(state: RiskState.warning)), isTrue);
      expect(await pulsing(const ExplainFacts(state: RiskState.normal)), isFalse);
      expect(await pulsing(const ExplainFacts(state: RiskState.evacuate, stale: true)), isFalse);
    });

    testWidgets('speaks Bahasa Malaysia when the app does', (tester) async {
      await open(tester, locale: const Locale('ms'));
      expect(find.text('Mengapa tahapnya Amaran?'), findsWidgets);
      expect(find.textContaining('3.2 cm di atas paras normalnya'), findsOneWidget);
    });

    testWidgets('fits a small phone without overflowing', (tester) async {
      await open(tester, size: const Size(320, 640));
      await tester.ensureVisible(find.widgetWithText(ActionChip, 'How do you work?'));
      await tester.tap(find.widgetWithText(ActionChip, 'How do you work?'));
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
    });
  });
}
