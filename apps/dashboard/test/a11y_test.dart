import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:licurici_core/licurici_core.dart';
import 'package:licurici_dashboard/app.dart';
import 'package:licurici_dashboard/data.dart';

/// WCAG 2.2, criteriul 2.5.8: ținte de cel puțin 24 × 24 px (panoul e pentru adulți, pe web).
const wcagTarget = MinimumTapTargetGuideline(
  size: Size(24, 24),
  link: 'https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum',
);

void main() {
  final children = demoChildren();

  Future<void> open(WidgetTester tester, String route, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = createRouter(initialLocation: route);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [childrenProvider.overrideWithValue(children)],
        child: DashboardApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> meetsAll(WidgetTester tester) async {
    final handle = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(wcagTarget));
    handle.dispose();
  }

  for (final (name, size) in [('desktop', const Size(1440, 1000)), ('telefon', const Size(390, 844))]) {
    for (final route in ['/', '/autentificare', '/parinte', '/specialist']) {
      testWidgets('accesibilitate $route ($name)', (tester) async {
        await open(tester, route, size);
        await meetsAll(tester);
      });
    }
  }

  testWidgets('accesibilitate: fișa copilului, pe toate taburile specialistului', (tester) async {
    await open(tester, '/specialist', const Size(1440, 1000));
    await tester.tap(find.text('Ilinca'));
    await tester.pumpAndSettle();
    await meetsAll(tester);
    for (final tab in ['Progres', 'Sesiuni', 'Confuzii', 'Jocuri']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      await meetsAll(tester);
    }
  });
}
