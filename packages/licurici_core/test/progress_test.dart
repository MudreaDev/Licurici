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
  adaptiveTests();

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

SessionRecord _leveled(int day, String step, {required int level, required bool correct, int n = 10}) {
  final start = DateTime.utc(2026, 9, day, 16);
  return SessionRecord(
    id: 'l$day$step$level',
    childId: 'c',
    start: start,
    end: start.add(const Duration(minutes: 10)),
    trials: [
      for (var i = 0; i < n; i++)
        Trial(
          stepId: step,
          gameId: stepById(step)!.games.first,
          correct: correct,
          promptLevel: correct ? PromptLevel.p0 : PromptLevel.p3,
          level: level,
          at: start.add(Duration(seconds: 20 * i)),
        ),
    ],
  );
}

void adaptiveTests() {
  group('rating pe nivelul jocului', () {
    test('aceleași reușite valorează mai mult la un nivel mare decât la nivelul 1', () {
      final low = progressFromSessions([_leveled(1, 'FEX2', level: 1, correct: true)]).single;
      final high = progressFromSessions([_leveled(1, 'FEX2', level: 8, correct: true)]).single;
      expect(high.rating, greaterThan(low.rating + 50));
    });

    test('greșelile la un nivel mult prea greu costă puțin (erau de așteptat)', () {
      final easy = progressFromSessions([_leveled(1, 'FEX2', level: 1, correct: false)]).single;
      final hard = progressFromSessions([_leveled(1, 'FEX2', level: 12, correct: false)]).single;
      expect(EloRating.start - hard.rating, lessThan(EloRating.start - easy.rating));
    });

    test('nivelul ajunge în JSON și înapoi; sesiunile vechi (fără nivel) se citesc', () {
      final t = _leveled(1, 'FEX2', level: 5, correct: true).trials.first;
      expect(Trial.fromJson(t.toJson()).level, 5);
      final old = Map<String, Object?>.of(t.toJson())..remove('level');
      expect(Trial.fromJson(old).level, isNull);
      expect(Trial.fromJson(old).ratingDifficulty, EloRating.start);
    });

    test('nivelul de pornire din rating: prudent, null fără date sau sub nivelul 2', () {
      final game = stepById('FEX2')!.games.first;
      expect(skillLevel(game, const {}), isNull);
      expect(skillLevel(game, const {'FEX2': EloRating.start}), isNull);
      final strong = progressFromSessions([
        for (var d = 1; d <= 6; d++) _leveled(d, 'FEX2', level: 6, correct: true),
      ]).single;
      final l = skillLevel(game, {'FEX2': strong.rating})!;
      expect(l, greaterThanOrEqualTo(2));
      expect(l, lessThan(const EloRating().levelFor(strong.rating)));
    });
  });

  group('„Drumul de azi” adaptiv', () {
    final now = DateTime.utc(2026, 9, 20);

    test('după două sesiuni foarte grele: pas înapoi la treapta dinainte', () {
      final progress = progressFromSessions([
        _session(1, 'EMO1', 9),
        _session(2, 'EMO1', 9),
        _session(10, 'EMO2', 2),
        _session(12, 'EMO2', 1),
      ]);
      final emo2 = progress.firstWhere((p) => p.stepId == 'EMO2');
      expect(emo2.struggling, isTrue);
      final games = {...stepById('EMO1')!.games, ...stepById('EMO2')!.games};
      final plan = const SessionPlanner(config: SessionConfig(targetBlocks: 1))
          .plan(progress: progress, allowedGames: games, now: now, random: Random(3));
      final target = plan.activities.firstWhere((a) => a.kind == ActivityKind.target);
      expect(target.stepId, 'EMO1');
      expect(target.bridgeFor, 'EMO2');
    });

    test('o singură sesiune grea nu e încă un motiv de pas înapoi', () {
      final p = progressFromSessions([_session(10, 'EMO2', 1)]).single;
      expect(p.struggling, isFalse);
      // Nici o sesiune scurtă (sub 4 încercări) nu contează.
      final short = progressFromSessions([_session(10, 'EMO2', 0, n: 3), _session(11, 'EMO2', 0, n: 3)]).single;
      expect(short.recentIndependence, isEmpty);
      expect(short.struggling, isFalse);
    });

    test('obiectivul care merge trece pe alt joc al treptei; cel greu rămâne pe jocul cunoscut', () {
      StepProgress pot5(double rating) => StepProgress(
            stepId: 'POT5',
            rating: rating,
            gameTrials: const {'culori': 40},
            gameLastPlayed: {'culori': DateTime.utc(2026, 9, 18)},
          );
      for (final seed in [1, 2, 3, 4]) {
        String planFor(double rating) => const SessionPlanner(config: SessionConfig(targetBlocks: 1))
            .plan(progress: [pot5(rating)], allowedGames: const {'culori', 'forme'}, now: now, random: Random(seed))
            .activities
            .single
            .gameId;
        expect(planFor(1100), 'forme');
        expect(planFor(900), 'culori');
      }
    });
  });
}
