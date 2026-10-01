import 'dart:convert';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

final _t0 = DateTime.utc(2026, 10, 1, 16);

Trial _t(int i, bool ok, {String step = 'EMO3', PromptLevel p = PromptLevel.p0, int ms = 1500,
        String? target, String? chosen}) =>
    Trial(
      stepId: step,
      gameId: 'ce-simte',
      correct: ok,
      promptLevel: ok ? p : PromptLevel.p2,
      attempts: ok && p == PromptLevel.p0 ? 1 : 2,
      latencyMs: ms,
      stimulusSet: 'set-${i % 2}',
      at: _t0.add(Duration(seconds: 10 * i)),
      targetId: target,
      chosenId: chosen,
    );

SessionRecord _rec(List<Trial> trials, {List<SessionEvent> events = const [], Mood? before, Mood? after}) =>
    SessionRecord(
      id: 's',
      childId: 'c',
      start: _t0,
      end: _t0.add(const Duration(minutes: 12)),
      trials: trials,
      events: events,
      moodBefore: before,
      moodAfter: after,
    );

void main() {
  test('confuziile se numără pe perechi și se sortează', () {
    final r = SessionReport.from(_rec([
      _t(0, false, target: 'trist', chosen: 'suparat'),
      _t(1, false, target: 'trist', chosen: 'suparat'),
      _t(2, false, target: 'speriat', chosen: 'surprins'),
      _t(3, true, target: 'trist'),
    ]));
    expect(r.confusions.first.target, 'trist');
    expect(r.confusions.first.chosen, 'suparat');
    expect(r.confusions.first.count, 2);
    expect(r.confusions, hasLength(2));
  });

  test('oboseala: latența crește în a doua jumătate', () {
    final r = SessionReport.from(_rec([
      for (var i = 0; i < 6; i++) _t(i, true, ms: 1000),
      for (var i = 6; i < 12; i++) _t(i, true, ms: 1600),
    ]));
    expect(r.fatigue, closeTo(0.6, 1e-9));
    expect(r.specialistNotes.any((n) => n.startsWith('Oboseală')), isTrue);
    expect(r.parentSummary, contains('oboseală'));
  });

  test('progres față de sesiunea anterioară', () {
    final before = SessionReport.from(_rec([for (var i = 0; i < 10; i++) _t(i, i < 4)]));
    final now = SessionReport.from(_rec([for (var i = 0; i < 10; i++) _t(i, i < 8)]), previous: before);
    expect(now.independenceDelta('EMO3'), closeTo(40, 1e-9));
    expect(now.nearMastery.map((s) => s.stepId), ['EMO3']);
    expect(now.parentSummary, contains('progres'));
    expect(now.specialistNotes.join(' '), contains('+40 pp'));
  });

  test('rezumatul pentru părinte: pauza e prezentată pozitiv, dispoziția aleasă de copil', () {
    final r = SessionReport.from(_rec(
      [for (var i = 0; i < 6; i++) _t(i, true)],
      events: [SessionEvent(SessionEventKind.pause, _t0)],
      before: Mood.obosit,
      after: Mood.bucuros,
    ));
    expect(r.parentSummary, contains('A cerut o pauză'));
    expect(r.parentSummary, contains('😴'));
    expect(r.parentSummary, contains('😊'));
    for (final word in ['greșit', 'eșec', 'slab', 'rău']) {
      expect(r.parentSummary.toLowerCase(), isNot(contains(word)));
    }
  });

  test('datele pentru AI: fără nume, fără id-uri, fără date calendaristice; JSON valid', () {
    final kids = demoChildren();
    for (final h in kids) {
      for (final r in h.reports) {
        final json = jsonEncode(r.toAiJson());
        expect(json, isNot(contains(h.child.nickname)));
        expect(json, isNot(contains(h.child.id)));
        expect(json, isNot(contains('2026')));
      }
    }
  });

  group('date demo', () {
    final kids = demoChildren();

    test('deterministe și complete', () {
      final again = demoChildren();
      expect(kids, hasLength(3));
      for (var i = 0; i < kids.length; i++) {
        expect(kids[i].reports, hasLength(12));
        expect(kids[i].latest!.overall.accuracy, again[i].latest!.overall.accuracy);
        // Toate treptele folosite există în trasee (panoul le afișează obiectivul).
        for (final s in [...kids[i].child.activeSteps, ...kids[i].child.masteredSteps]) {
          expect(stepById(s), isNotNull, reason: s);
        }
      }
    });

    test('independența crește în timp pe obiectivele active (progres realist)', () {
      for (final h in kids) {
        final step = h.child.activeSteps.first;
        final series = h.independenceSeries(step);
        expect(series, hasLength(12));
        double avg(Iterable<(DateTime, double)> xs) => xs.map((e) => e.$2).reduce((a, b) => a + b) / xs.length;
        expect(avg(series.skip(8)), greaterThan(avg(series.take(4))), reason: '${h.child.nickname} $step');
      }
    });

    test('sesiunile sunt în ordine cronologică', () {
      for (final h in kids) {
        for (var i = 1; i < h.sessions.length; i++) {
          expect(h.sessions[i].start.isAfter(h.sessions[i - 1].start), isTrue);
        }
      }
    });
  });
}
