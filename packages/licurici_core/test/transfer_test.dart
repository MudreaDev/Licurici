import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  final sessions = demoChildren().first.sessions;

  test('export → import: aceleași sesiuni și aceleași rapoarte', () {
    final back = importSessions(exportSessions(sessions));
    expect(back, hasLength(sessions.length));
    expect(
      [for (final s in back) SessionReport.from(s).toAiJson()],
      [for (final s in sessions) SessionReport.from(s).toAiJson()],
    );
  });

  test('exportul nu conține porecla copilului', () {
    final kid = demoChildren().first.child;
    expect(exportSessions(sessions), isNot(contains(kid.nickname)));
  });

  test('text greșit → mesaj clar, fără excepții neprevăzute', () {
    for (final bad in ['', 'abc', '{"format":"altceva"}', '{"format":"licurici-sesiuni","version":9}',
        '{"format":"licurici-sesiuni","version":1,"sessions":[{"id":1}]}']) {
      expect(() => importSessions(bad), throwsA(isA<TransferFormatException>()), reason: bad);
    }
  });

  test('copilul importat: obiectivele și treptele stăpânite din progres', () {
    final h = importedChild(sessions);
    expect(h.reports, hasLength(sessions.length));
    expect([...h.child.activeSteps, ...h.child.masteredSteps], isNotEmpty);
    expect(h.child.activeSteps, contains('EMO3'));
    // EMO2 are doar 3 încercări pe sesiune în demo: sub minimul criteriului (10), deci nu e
    // declarată stăpânită — prea puține date nu devin concluzii.
    expect(h.child.masteredSteps, isNot(contains('EMO2')));
  });
}
