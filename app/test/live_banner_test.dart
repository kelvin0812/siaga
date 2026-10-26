import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siaga_app/core/models.dart';
import 'package:siaga_app/core/theme.dart';
import 'package:siaga_app/l10n/app_localizations.dart';
import 'package:siaga_app/widgets/live_banner.dart';

SiagaNode _node(int id, String name, RiskState state) =>
    SiagaNode(id: id, name: name, lat: 2.9, lon: 101.6, state: state, lastSeen: null, batteryVolts: null);

void main() {
  Future<void> show(WidgetTester tester, List<SiagaNode> nodes, {bool reduceMotion = false, VoidCallback? onTap}) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: SiagaTheme.dark(),
        builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(disableAnimations: reduceMotion), child: child!),
        home: Scaffold(body: Column(children: [LiveBanner(nodes: nodes, onTap: onTap), const Expanded(child: SizedBox())])),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  test('only Warning and Evacuate make a headline, the most serious first', () {
    final risky = LiveBanner.atRisk([
      _node(1, 'Calm', RiskState.normal),
      _node(2, 'Watched', RiskState.watch),
      _node(3, 'Rising', RiskState.warning),
      _node(4, 'Flooding', RiskState.evacuate),
    ]);
    expect(risky.map((n) => n.name), ['Flooding', 'Rising']);
  });

  testWidgets('nothing is shown while every place is Normal or Watch', (tester) async {
    await show(tester, [_node(1, 'Calm', RiskState.normal), _node(2, 'Watched', RiskState.watch)]);
    expect(find.text('LIVE'), findsNothing);
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('it names the risky places under a LIVE tag, and a tap opens the map', (tester) async {
    var taps = 0;
    await show(tester, [_node(1, 'Lake bank (demo)', RiskState.warning), _node(2, 'Calm place', RiskState.normal)], onTap: () => taps++);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('Lake bank (demo)'), findsWidgets);
    expect(find.text('Warning'), findsWidgets);
    expect(find.text('Calm place'), findsNothing);
    await tester.tap(find.text('LIVE'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('it scrolls on its own, and stands still with reduce motion', (tester) async {
    await show(tester, [_node(1, 'Lake bank (demo)', RiskState.warning)]);
    final list = find.byType(ListView);
    final controller = tester.widget<ListView>(list).controller!;
    final before = controller.offset;
    await tester.pump(const Duration(seconds: 2));
    expect(controller.offset, greaterThan(before + 40)); // it moved

    await show(tester, [_node(1, 'Lake bank (demo)', RiskState.warning)], reduceMotion: true);
    final still = tester.widget<ListView>(find.byType(ListView)).controller!;
    final at = still.offset;
    await tester.pump(const Duration(seconds: 2));
    expect(still.offset, at); // no motion
    expect(tester.takeException(), isNull);
  });

  testWidgets('the ticker is announced as one readable line for screen readers', (tester) async {
    await show(tester, [_node(1, 'Lake bank (demo)', RiskState.evacuate), _node(2, 'Road', RiskState.warning)]);
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel(RegExp(r'^LIVE\. Evacuate: Lake bank \(demo\)\. Warning: Road$')), findsOneWidget);
    handle.dispose();
  });
}
