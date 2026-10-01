import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:licurici_core/licurici_core.dart';
import 'package:licurici_dashboard/app.dart';
import 'package:licurici_dashboard/data.dart';
import 'package:licurici_dashboard/shared.dart';
import 'package:licurici_dashboard/specialist.dart';

void main() {
  final children = demoChildren();
  Future<void> open(
    WidgetTester tester,
    String route, {
    Size size = const Size(1440, 1000),
    List<ChildHistory>? data,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = createRouter(initialLocation: route);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [childrenProvider.overrideWithValue(data ?? children)],
        child: DashboardApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Role selection opens parent summary and supports child selection',
    (tester) async {
      await open(tester, '/');
      await tester.tap(find.text('Sunt părinte'));
      await tester.pumpAndSettle();
      expect(find.text('Ultima sesiune'), findsOneWidget);
      expect(
        tester.widget<SummaryText>(find.byType(SummaryText).first).text,
        children.first.latest!.parentSummary,
      );
      expect(find.text('EMO3'), findsNothing);
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tudor').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<SummaryText>(find.byType(SummaryText).first).text,
        children[1].latest!.parentSummary,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Specialist lists three children, notes and ABA graph', (
    tester,
  ) async {
    await open(tester, '/specialist');
    for (final c in children) {
      expect(find.text(c.child.nickname), findsOneWidget);
    }
    await tester.tap(find.text('Ilinca'));
    await tester.pumpAndSettle();
    expect(
      find.text('•  ${children.first.latest!.specialistNotes.first}'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Generează rezumat cu AI'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Progres'));
    await tester.pumpAndSettle();
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData, hasLength(3));
    expect(chart.data.lineBarsData.first.spots, hasLength(12));
    expect(
      chart.data.lineBarsData.first.spots.last.y,
      children.first.independenceSeries('EMO3').last.$2 * 100,
    );
    expect(chart.data.extraLinesData.horizontalLines.single.y, 80);
    expect(
      chart.data.extraLinesData.horizontalLines.single.dashArray,
      isNotEmpty,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Session detail exposes notes, confusions and expandable AI preview',
    (tester) async {
      await open(tester, '/specialist/copil/${children.first.child.id}');
      await tester.tap(find.text('Sesiuni'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(dateLabel(children.first.latest!.record.start)).first,
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Confuzii în sesiune'), findsOneWidget);
      final preview = find.text('Date trimise la AI (pseudonimizate)');
      await tester.ensureVisible(preview);
      await tester.tap(preview);
      await tester.pumpAndSettle();
      final json = tester
          .widget<SelectableText>(find.byType(SelectableText))
          .data!;
      expect(json, contains('meanPromptLevel'));
      expect(json, isNot(contains('Ilinca')));
      expect(json, isNot(contains(children.first.child.id)));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Tablet uses drawer and selects a child', (tester) async {
    await open(tester, '/specialist', size: const Size(800, 1000));
    expect(find.text('Ilinca'), findsNothing);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('Mara'), findsOneWidget);
    await tester.tap(find.text('Mara'));
    await tester.pumpAndSettle();
    expect(find.text('Mara'), findsOneWidget);
    await tester.tap(find.text('Progres'));
    await tester.pumpAndSettle();
    expect(find.byType(LineChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Empty history and invalid child route are handled', (
    tester,
  ) async {
    await open(
      tester,
      '/parinte',
      data: [ChildHistory(children.first.child, [])],
    );
    expect(
      find.text('Primele momente de joacă vor apărea aici.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('Unknown child does not display another child', (tester) async {
    await open(tester, '/specialist/copil/necunoscut');
    expect(find.text('Copilul nu a fost găsit.'), findsOneWidget);
    expect(find.text('Observații pentru specialist'), findsNothing);
  });
  test('Confusion aggregation sums pairs and sorts descending', () {
    final result = aggregateConfusions(children.first);
    final pair = result.first;
    final expected = children.first.reports
        .expand((r) => r.confusions)
        .where((c) => c.target == pair.target && c.chosen == pair.chosen)
        .fold<int>(0, (sum, c) => sum + c.count);
    expect(pair.count, expected);
    for (var i = 1; i < result.length; i++) {
      expect(result[i - 1].count, greaterThanOrEqualTo(result[i].count));
    }
  });
}
