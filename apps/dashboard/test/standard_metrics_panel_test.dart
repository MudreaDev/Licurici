import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:licurici_core/licurici_core.dart';
import 'package:licurici_dashboard/progress.dart';

void main() {
  testWidgets('metricile standard ale copiilor demo: câte două jocuri măsurabile fiecare', (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final kids = demoChildren();
    final expected = {
      'Ilinca': ['linia-numerelor', 'stop'],
      'Tudor': ['atinge-rapid', 'paznicul-farului'],
      'Mara': ['cate-sunt', 'cat-de-tare'],
    };
    for (final h in kids) {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: StandardMetricsPanel(h)))));
      for (final game in expected[h.child.nickname]!) {
        expect(find.byKey(ValueKey('metric-$game')), findsOneWidget, reason: '${h.child.nickname}: $game');
      }
    }
  });
}
