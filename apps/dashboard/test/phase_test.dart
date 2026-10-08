import 'package:flutter_test/flutter_test.dart';
import 'package:licurici_core/licurici_core.dart';
import 'package:licurici_dashboard/progress.dart';

void main() {
  test('linia de fază cade între ultima sesiune de dinainte și prima de după', () {
    final reports = demoChildren(sessions: 6).first.reports;
    final second = reports[1].record.start, third = reports[2].record.start;
    final between = second.add(third.difference(second) ~/ 2);
    expect(phaseX(reports, between), 2.5);
    // Înaintea primei sesiuni sau după ultima: nicio linie.
    expect(phaseX(reports, reports.first.record.start.subtract(const Duration(days: 1))), isNull);
    expect(phaseX(reports, reports.last.record.start.add(const Duration(days: 1))), isNull);
  });
}
