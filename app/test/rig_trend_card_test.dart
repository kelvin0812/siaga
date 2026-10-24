import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siaga_app/core/models.dart';
import 'package:siaga_app/l10n/app_localizations.dart';
import 'package:siaga_app/widgets/rig_trend_card.dart';

Widget _host(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

List<RigPoint> _points(int n, {double height = 3, int phase = 2}) {
  final end = DateTime(2026, 10, 25, 12);
  return [
    for (var i = 0; i < n; i++)
      RigPoint(
        time: end.subtract(Duration(seconds: (n - 1 - i) * 3)),
        heightCm: height + i * 0.1,
        flow: 0,
        soilRaw: 435,
        tiltDeg: 5,
        phase: phase,
      ),
  ];
}

void main() {
  testWidgets('draws a chart with the latest value once there are readings', (tester) async {
    await tester.pumpWidget(_host(RigTrendCard(
      icon: Icons.waves,
      title: 'Water level',
      help: 'Rising water is the strongest warning sign.',
      color: Colors.amber,
      points: _points(60),
      valueOf: (p) => p.heightCm,
      latestText: '8.9 cm',
      unit: 'cm',
    )));
    await tester.pump();
    expect(find.text('WATER LEVEL'), findsOneWidget);
    expect(find.text('8.9 cm'), findsOneWidget);
    expect(find.text('Waiting for readings to draw this chart'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('says it is waiting, and does not draw, with fewer than two readings', (tester) async {
    await tester.pumpWidget(_host(RigTrendCard(
      icon: Icons.waves,
      title: 'Water level',
      help: 'help',
      color: Colors.amber,
      points: _points(1),
      valueOf: (p) => p.heightCm,
      latestText: '—',
    )));
    await tester.pump();
    expect(find.text('Waiting for readings to draw this chart'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a flat signal and the four-level risk chart both draw without errors', (tester) async {
    await tester.pumpWidget(_host(Column(children: [
      RigTrendCard(
        icon: Icons.water_drop_outlined,
        title: 'Water flow',
        help: 'help',
        color: Colors.blue,
        points: _points(40),
        valueOf: (p) => p.flow, // all zero: the chart must not divide by a zero range
        latestText: '0 pulses',
        decimals: 0,
        minSpan: 4,
      ),
      RigTrendCard(
        icon: Icons.shield_outlined,
        title: 'Risk level',
        help: 'help',
        color: Colors.orange,
        points: _points(40, phase: 3),
        valueOf: (p) => p.phase.toDouble(),
        latestText: 'Warning',
        phaseAxis: true,
      ),
    ])));
    await tester.pump();
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('Evacuate'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
