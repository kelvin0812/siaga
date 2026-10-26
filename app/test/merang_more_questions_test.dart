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
const _local = LocalExplainer();
const _normal = ExplainFacts(state: RiskState.normal);
const _evacuate = ExplainFacts(state: RiskState.evacuate, nodeName: 'Bench rig (live)', isRigNode: true, heightCm: 4.5, risePerMin: 1.2, age: Duration(seconds: 3));

void main() {
  group('the survival and evacuation questions', () {
    test('each has fixed answers in both languages, and ends by pointing to the official channels', () {
      for (final q in [MerangQuestion.tips, MerangQuestion.where, MerangQuestion.bring, MerangQuestion.stuck]) {
        final en = _local.answer(q, _normal, _en, 'Normal');
        final ms = _local.answer(q, _normal, _ms, 'Normal');
        expect(en.length, greaterThanOrEqualTo(3), reason: '$q');
        expect(en.last, contains('NADMA'), reason: '$q');
        expect(ms.last, contains('NADMA'), reason: '$q');
        expect(ms.join(' '), isNot(equals(en.join(' '))), reason: '$q is not translated');
      }
    });

    test('the advice is general and careful: no go/no-go verdicts', () {
      final all = [for (final q in [MerangQuestion.tips, MerangQuestion.where, MerangQuestion.bring, MerangQuestion.stuck]) ..._local.answer(q, _normal, _en, '')].join(' ').toLowerCase();
      expect(all, contains('floodwater'));
      expect(all, contains('999'));
      expect(all, isNot(contains('you are safe')));
      expect(all, isNot(contains('no need to')));
    });

    test('the answers do not depend on the numbers, so they are the same when the data is old', () {
      final fresh = _local.answer(MerangQuestion.stuck, _evacuate, _en, 'Evacuate');
      final old = _local.answer(MerangQuestion.stuck, const ExplainFacts(state: RiskState.evacuate, stale: true), _en, 'Evacuate');
      expect(old, fresh);
    });
  });

  group('typed questions about getting to safety', () {
    test('are recognised, in English and Bahasa Malaysia', () {
      expect(intentFor('where should I go?'), MerangIntent.where);
      expect(intentFor('where is the nearest assembly point'), MerangIntent.where);
      expect(intentFor('where should I evacuate'), MerangIntent.where);
      expect(intentFor('ke mana saya patut pergi'), MerangIntent.where);
      expect(intentFor('what should I bring'), MerangIntent.bring);
      expect(intentFor('apa yang patut saya bawa'), MerangIntent.bring);
      expect(intentFor("what if I can't leave"), MerangIntent.stuck);
      expect(intentFor('what if I can’t leave?'), MerangIntent.stuck);
      expect(intentFor('the road is flooded'), MerangIntent.stuck);
      expect(intentFor('saya terperangkap'), MerangIntent.stuck);
      expect(intentFor('any survival tips?'), MerangIntent.tips);
      expect(intentFor('how do I stay safe'), MerangIntent.tips);
      expect(intentFor('petua keselamatan'), MerangIntent.tips);
    });

    test('the older safety questions are unchanged and still win for go/no-go wording', () {
      expect(intentFor('should I evacuate?'), MerangIntent.safety);
      expect(intentFor('is it safe?'), MerangIntent.safety);
      expect(intentFor('what should I do'), MerangIntent.safety);
      expect(intentFor('where does the data come from'), MerangIntent.data);
    });

    test('each maps to its fixed question, so none of them is ever sent to a model', () {
      expect(questionForIntent(MerangIntent.where), MerangQuestion.where);
      expect(questionForIntent(MerangIntent.bring), MerangQuestion.bring);
      expect(questionForIntent(MerangIntent.stuck), MerangQuestion.stuck);
      expect(questionForIntent(MerangIntent.tips), MerangQuestion.tips);
    });
  });

  group('the chips', () {
    test('every question has a chip, and at Warning or higher the "what to do" ones come first', () {
      for (final s in RiskState.values) {
        expect(merangChipOrder(ExplainFacts(state: s)).toSet(), MerangQuestion.values.toSet());
      }
      expect(merangChipOrder(const ExplainFacts(state: RiskState.normal)).first, MerangQuestion.why);
      expect(merangChipOrder(const ExplainFacts(state: RiskState.evacuate)).first, MerangQuestion.next);
      expect(merangChipOrder(const ExplainFacts(state: RiskState.warning)).first, MerangQuestion.next);
      expect(merangChipOrder(const ExplainFacts(state: RiskState.evacuate, stale: true)).first, MerangQuestion.why); // old data: not shouting
    });
  });

  group('in the chat sheet', () {
    Future<void> open(WidgetTester tester, ExplainFacts facts) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: SiagaTheme.dark(),
          builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(disableAnimations: true), child: child!),
          home: Scaffold(body: const SizedBox.expand(), floatingActionButton: MerangButton(facts: facts)),
        ),
      );
      await tester.tap(find.byType(MerangButton));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
    }

    testWidgets('a survival tip chip gives the tips', (tester) async {
      await open(tester, _normal);
      final chip = find.widgetWithText(ActionChip, 'Survival tips');
      await tester.scrollUntilVisible(chip, 100, scrollable: find.byType(Scrollable).last);
      await tester.tap(chip);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.textContaining('Never walk, swim or drive through floodwater'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('at Evacuate the sheet opens answering "what should I do?" and the face has a siren', (tester) async {
      await open(tester, _evacuate);
      expect(find.text('What should I do?'), findsWidgets);
      expect(find.textContaining('Leave now. Follow the route to the nearest assembly point'), findsOneWidget);
      expect(find.textContaining('4.5 cm above its normal level'), findsNothing); // the "why" answer was not what it opened with
      final faces = tester.widgetList<Image>(find.byType(Image)).map((i) => (i.image as AssetImage).assetName);
      expect(faces, contains('assets/mascot/otter_evacuate.png'));
    });

    testWidgets('each phase has its own face', (tester) async {
      expect(merangMoodFor(const ExplainFacts(state: RiskState.normal)), MerangMood.calm);
      expect(merangMoodFor(const ExplainFacts(state: RiskState.watch)), MerangMood.watch);
      expect(merangMoodFor(const ExplainFacts(state: RiskState.warning)), MerangMood.alert);
      expect(merangMoodFor(const ExplainFacts(state: RiskState.evacuate)), MerangMood.evacuate);
      expect({for (final s in RiskState.values) merangMoodFor(ExplainFacts(state: s))}.length, 4);
    });
  });
}
