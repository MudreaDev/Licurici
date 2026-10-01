import 'dart:math';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

SessionRecord _session(int day, String step, int ok, {int n = 10, String set = 'a'}) {
  final start = DateTime.utc(2026, 9, day, 16);
  return SessionRecord(
    id: 's$day$step',
    childId: 'c',
    start: start,
    end: start.add(const Duration(minutes: 10)),
    trials: [
      for (var i = 0; i < n; i++)
        Trial(
          stepId: step,
          gameId: stepById(step)!.games.first,
          correct: i < ok,
          promptLevel: i < ok ? PromptLevel.p0 : PromptLevel.p3,
          stimulusSet: '$set${i % 2}',
          at: start.add(Duration(seconds: 20 * i)),
        ),
    ],
  );
}

void main() {
  test('stăpânirea apare după 2 sesiuni bune pe 2 seturi; rating-ul crește', () {
    final p = progressFromSessions([
      _session(1, 'EMO3', 4),
      _session(2, 'EMO3', 9),
      _session(3, 'EMO3', 9),
    ]).single;
    expect(p.stepId, 'EMO3');
    expect(p.mastered, isTrue);
    expect(p.masteredAt, DateTime.utc(2026, 9, 3, 16, 10));
    expect(p.rating, greaterThan(EloRating.start));
    expect(p.lastPracticed!.day, 3);
  });

  test('o treaptă grea rămâne obiectiv, cu rating mai mic', () {
    final p = progressFromSessions([_session(1, 'FEX2', 3), _session(2, 'FEX2', 4)]).single;
    expect(p.mastered, isFalse);
    expect(p.rating, lessThan(EloRating.start));
  });

  test('obiectivele implicite: prima treaptă nestăpânită pe fiecare arie disponibilă', () {
    final known = progressFromSessions([_session(1, 'EMO1', 9), _session(2, 'EMO1', 9)]);
    final objectives = defaultObjectives(known, {'emotii', 'ce-simte', 'pescarul'});
    final ids = objectives.map((o) => o.stepId).toList();
    expect(ids, contains('EMO1')); // stăpânită: rămâne pentru încălzire
    expect(ids, contains('EMO2')); // următoarea pe EMO
    expect(ids, contains('FEX2'));
    expect(ids, isNot(contains('ATN1'))); // jocul nu e disponibil
  });

  test('de la sesiuni la „Drumul de azi” cu SessionPlanner', () {
    final known = progressFromSessions([_session(1, 'EMO1', 9), _session(2, 'EMO1', 9)]);
    final games = {'emotii', 'ce-simte', 'pescarul'};
    final plan = const SessionPlanner().plan(
      progress: defaultObjectives(known, games),
      allowedGames: games,
      now: DateTime.utc(2026, 9, 9),
      random: Random(1),
    );
    expect(plan.activities.first.kind, ActivityKind.warmUp);
    expect(plan.activities.first.stepId, 'EMO1');
    expect(plan.activities.where((a) => a.kind == ActivityKind.target), isNotEmpty);
    expect(plan.schedule.every(games.contains), isTrue);
  });
}
