import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siaga_app/core/api_client.dart';
import 'package:siaga_app/core/app_state.dart';
import 'package:siaga_app/core/fcm_service.dart';
import 'package:siaga_app/core/h3_service.dart';
import 'package:siaga_app/core/location_service.dart';
import 'package:siaga_app/core/offline_cache.dart';
import 'package:siaga_app/core/theme.dart';
import 'package:siaga_app/l10n/app_localizations.dart';
import 'package:siaga_app/core/explainer_service.dart';
import 'package:siaga_app/core/models.dart';
import 'package:siaga_app/widgets/merang_sheet.dart';

/// WCAG contrast ratio between two colours.
double _contrast(Color a, Color b) {
  double lum(Color c) {
    double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  final l1 = lum(a), l2 = lum(b);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

class _Cells implements CellComputer {
  @override
  String cellForPoint(double lat, double lon) => 'cellA';
}

const _facts = ExplainFacts(state: RiskState.warning);

void main() {
  group('text on the dark surfaces is readable outdoors', () {
    const backgrounds = {'top': AppColors.bgTop, 'bottom': AppColors.bgBottom, 'card': AppColors.surface, 'raised card': AppColors.surfaceRaised};

    test('secondary text clears AAA (7:1), muted text clears AA (4.5:1), on every surface', () {
      for (final e in backgrounds.entries) {
        expect(_contrast(AppColors.textSecondary, e.value), greaterThanOrEqualTo(7), reason: 'secondary on ${e.key}');
        expect(_contrast(AppColors.textMuted, e.value), greaterThanOrEqualTo(4.5), reason: 'muted on ${e.key}');
        expect(_contrast(AppColors.textPrimary, e.value), greaterThanOrEqualTo(12), reason: 'primary on ${e.key}');
      }
    });

    test('and the hierarchy is kept: primary is brighter than secondary, which is brighter than muted', () {
      final onCard = AppColors.surface;
      expect(_contrast(AppColors.textPrimary, onCard), greaterThan(_contrast(AppColors.textSecondary, onCard)));
      expect(_contrast(AppColors.textSecondary, onCard), greaterThan(_contrast(AppColors.textMuted, onCard)));
    });
  });

  testWidgets('Merang sits in the header, not floating over the page', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final app = AppState(
      api: ApiClient(),
      cache: OfflineCache(prefs),
      locationService: LocationService(h3Service: _Cells(), fcmService: FcmService(), prefs: prefs),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: app,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: SiagaTheme.dark(),
          builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(disableAnimations: true), child: child!),
          home: Scaffold(
            appBar: AppBar(title: const Text('SIAGA'), actions: [Padding(padding: const EdgeInsets.only(right: 12), child: MerangButton(compact: true, facts: _facts))]),
            body: const SizedBox.expand(),
          ),
        ),
      ),
    );
    final box = tester.getRect(find.byType(MerangButton));
    expect(box.top, greaterThanOrEqualTo(0));
    expect(box.bottom, lessThanOrEqualTo(kToolbarHeight)); // inside the title bar
    expect(box.width, lessThan(52)); // compact: it does not take over the bar
    expect(box.right, closeTo(430 - 12, 1));
    expect(tester.takeException(), isNull);
  });
}
