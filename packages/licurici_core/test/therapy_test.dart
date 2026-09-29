import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

/// Traseele reale, din `packages/game_content/trasee/`.
Map<String, Ladder> loadLadders() => {
      for (final f in Directory('../game_content/trasee').listSync().whereType<File>())
        if (f.path.endsWith('.json'))
          f.uri.pathSegments.last: Ladder.fromJson(jsonDecode(f.readAsStringSync()) as Map<String, Object?>),
    };

final t0 = DateTime.utc(2026, 10, 1, 10);

Trial trial(
  String session, {
  bool correct = true,
  PromptLevel prompt = PromptLevel.p0,
  int attempts = 1,
  String? set,
  int minute = 0,
  int? latency,
  TrialMode mode = TrialMode.plan,
}) =>
    Trial(
      sessionId: session,
      stepId: 'POT1',
      gameId: 'potriveste',
      correct: correct,
      promptLevel: prompt,
      attempts: attempts,
      stimulusSet: set,
      latencyMs: latency,
      mode: mode,
      at: t0.add(Duration(minutes: minute)),
    );

/// O sesiune de [n] încercări, dintre care [independent] independente (restul cu P2).
List<Trial> session(String id, int n, int independent, {String set = 'a', int day = 0}) => [
      for (var i = 0; i < n; i++)
        trial(
          id,
          prompt: i < independent ? PromptLevel.p0 : PromptLevel.p2,
          set: set,
          minute: day * 1440 + i,
        ),
    ];

void main() {
  group('trasee (JSON)', () {
    final ladders = loadLadders();

    test('cele 4 trasee din Sprint 2 există și sunt valide', () {
      expect(ladders.keys.toSet(), containsAll(['pot.json', 'lrc.json', 'emo.json', 'pac-n.json']));
      expect(ladders['pot.json']!.domain, Domain.pot);
      expect(ladders['pac-n.json']!.domain, Domain.pac);
      expect(ladders['pac-n.json']!.id, 'PAC-N');
      for (final l in ladders.values) {
        expect(l.steps, isNotEmpty);
        for (final s in l.steps) {
          expect(s.exercises, isNotEmpty, reason: s.id);
          expect(s.goal, isNotEmpty);
          expect(s.criterion.independence, 0.8);
        }
      }
    });

    test('navigare: următoarea / anterioara / treptele unui joc', () {
      final pot = ladders['pot.json']!;
      final p1 = pot.step('POT1')!;
      expect(pot.next(p1)!.id, 'POT2');
      expect(pot.previous(p1), isNull);
      expect(pot.next(pot.steps.last), isNull);
      expect(pot.stepsFor('potriveste').map((s) => s.id), ['POT1', 'POT2', 'POT4', 'POT5', 'POT6']);
    });

    test('date greșite sunt respinse', () {
      Map<String, Object?> ladder(List<Map<String, Object?>> steps) =>
          {'id': 'POT', 'domain': 'POT', 'title': 't', 'steps': steps};
      Map<String, Object?> step(String id) => {'id': id, 'title': 't', 'goal': 'g'};
      expect(() => Ladder.fromJson(ladder([step('POT1'), step('POT1')])), throwsFormatException);
      expect(() => Ladder.fromJson(ladder([step('LRC1')])), throwsFormatException);
      expect(() => Ladder.fromJson(ladder([])), throwsFormatException);
      expect(() => Ladder.fromJson({...ladder([step('POT1')]), 'domain': 'XYZ'}), throwsFormatException);
    });

    test('criteriul se poate suprascrie pe treaptă', () {
      final l = Ladder.fromJson({
        'id': 'EMO',
        'domain': 'EMO',
        'title': 't',
        'criterion': {'independence': 0.8, 'sessions': 3},
        'steps': [
          {'id': 'EMO1', 'title': 't', 'goal': 'g', 'criterion': {'independence': 0.9}},
        ],
      });
      expect(l.steps.single.criterion.independence, 0.9);
      expect(l.steps.single.criterion.sessions, 3);
    });
  });

  group('Trial', () {
    test('independent = corect, din prima, fără ajutor', () {
      expect(trial('s').independent, isTrue);
      expect(trial('s', attempts: 2).independent, isFalse);
      expect(trial('s', prompt: PromptLevel.p1).independent, isFalse);
      expect(trial('s', correct: false).independent, isFalse);
    });

    test('JSON dus-întors păstrează tot', () {
      final t = Trial(
        sessionId: 's1',
        stepId: 'POT4',
        gameId: 'potriveste',
        correct: true,
        at: t0,
        promptLevel: PromptLevel.p3,
        attempts: 2,
        latencyMs: 2400,
        seed: 83412,
        config: const {'mod': 'obiect'},
        axes: const {'asemanare': 2, 'variante': 3},
        rating: 1340,
        stimulusId: 'caine_2',
        stimulusSet: 'animale',
        offTargetTaps: 3,
        mode: TrialMode.evaluare,
      );
      final back = Trial.fromJson(jsonDecode(jsonEncode(t.toJson())) as Map<String, Object?>);
      expect(back.toJson(), t.toJson());
      expect(back.promptLevel, PromptLevel.p3);
      expect(back.at, t0);
    });

    test('nivelurile de ajutor se ordonează și se limitează', () {
      expect(PromptLevel.p0 + 2, PromptLevel.p2);
      expect(PromptLevel.p3 + 5, PromptLevel.p4);
      expect(PromptLevel.p1 - 3, PromptLevel.p0);
      expect(PromptLevel.p2 > PromptLevel.p1, isTrue);
      expect(PromptLevel.fromCode('P4'), PromptLevel.p4);
    });
  });

  group('PromptStrategy', () {
    test('puțin → mult: pornește fără ajutor, crește la greșeli și la pauze', () {
      const s = PromptStrategy();
      final plan = s.planFor(const []);
      expect(plan.start, PromptLevel.p0);
      expect(s.levelAt(plan, elapsed: Duration.zero), PromptLevel.p0);
      expect(s.levelAt(plan, elapsed: const Duration(seconds: 5)), PromptLevel.p1);
      expect(s.levelAt(plan, elapsed: Duration.zero, errors: 2), PromptLevel.p2);
      expect(s.levelAt(plan, elapsed: const Duration(seconds: 12), errors: 2), PromptLevel.p4);
      expect(s.levelAt(plan, elapsed: const Duration(minutes: 5), errors: 9), PromptLevel.p4);
    });

    test('plafonul specialistului nu e depășit niciodată', () {
      const s = PromptStrategy(order: PromptOrder.mostToLeast, maxLevel: PromptLevel.p3);
      final plan = s.planFor(const []);
      expect(plan.start, PromptLevel.p3);
      expect(s.levelAt(plan, elapsed: const Duration(minutes: 1), errors: 5), PromptLevel.p3);
    });

    test('mult → puțin: ajutorul se estompează după reușite, revine după greșeală', () {
      const s = PromptStrategy(order: PromptOrder.mostToLeast);
      final ok = trial('s', prompt: PromptLevel.p4);
      expect(s.planFor([]).start, PromptLevel.p4);
      expect(s.planFor([ok]).start, PromptLevel.p4);
      expect(s.planFor([ok, ok]).start, PromptLevel.p3);
      final okP3 = trial('s', prompt: PromptLevel.p3);
      expect(s.planFor([ok, ok, okP3, okP3]).start, PromptLevel.p2);
      expect(s.planFor([ok, ok, okP3, okP3, trial('s', correct: false)]).start, PromptLevel.p3);
      // după multe reușite ajunge la independent
      final many = List.generate(12, (_) => trial('s', prompt: PromptLevel.p0));
      expect(s.planFor(many).start, PromptLevel.p0);
    });

    test('întârziere progresivă: 0 s → 2 s → 4 s; ajutorul vine după întârziere', () {
      const s = PromptStrategy(order: PromptOrder.timeDelay);
      expect(s.planFor([]).delay, Duration.zero);
      final ok = trial('s');
      final plan = s.planFor([ok, ok]);
      expect(plan.delay, const Duration(seconds: 2));
      expect(s.levelAt(plan, elapsed: const Duration(seconds: 1)), PromptLevel.p0);
      expect(s.levelAt(plan, elapsed: const Duration(seconds: 2)), PromptLevel.p3);
      expect(s.planFor([ok, ok, ok, ok, ok, ok]).delay, const Duration(seconds: 4));
      expect(s.planFor([ok, ok, trial('s', correct: false)]).delay, Duration.zero);
    });

    test('implicit: treaptă nouă → mult la puțin; cunoscută → puțin la mult', () {
      expect(PromptStrategy.defaultFor([]).order, PromptOrder.mostToLeast);
      expect(PromptStrategy.defaultFor(session('s', 8, 7)).order, PromptOrder.leastToMost);
      expect(PromptStrategy.defaultFor(session('s', 8, 2)).order, PromptOrder.mostToLeast);
    });
  });

  group('MasteryEvaluator', () {
    const ev = MasteryEvaluator();
    const c = MasteryCriterion();

    test('fără sesiuni valide → date insuficiente', () {
      expect(ev.evaluate([], c).state, MasteryState.insufficientData);
      expect(ev.evaluate(session('s1', 4, 4), c).state, MasteryState.insufficientData);
    });

    test('2 sesiuni la rând ≥ 80% independent, pe 2 seturi → stăpânit', () {
      final r = ev.evaluate([
        ...session('s1', 10, 3, day: 0),
        ...session('s2', 10, 8, set: 'a', day: 1),
        ...session('s3', 10, 9, set: 'b', day: 2),
      ], c);
      expect(r.state, MasteryState.mastered);
      expect(r.sessionsMet, 2);
      expect(r.stimulusSets, 2);
      expect(r.sessions.map((s) => s.independence), [0.3, 0.8, 0.9]);
    });

    test('un singur set de stimuli = memorare, nu stăpânire', () {
      final r = ev.evaluate([...session('s1', 10, 9), ...session('s2', 10, 9, day: 1)], c);
      expect(r.state, MasteryState.inProgress);
      expect(r.sessionsMet, 2);
      expect(r.stimulusSets, 1);
    });

    test('sesiunea cea mai recentă sub prag rupe seria', () {
      final r = ev.evaluate([
        ...session('s1', 10, 9, set: 'a'),
        ...session('s2', 10, 9, set: 'b', day: 1),
        ...session('s3', 10, 5, set: 'a', day: 2),
      ], c);
      expect(r.state, MasteryState.inProgress);
      expect(r.sessionsMet, 0);
    });

    test('sesiunile scurte și sondajele de evaluare nu contează', () {
      final r = ev.evaluate([
        ...session('s1', 10, 9, set: 'a'),
        ...session('scurta', 3, 0, day: 1),
        for (final t in session('ev', 10, 0, day: 1))
          trial('ev', correct: false, mode: TrialMode.evaluare, minute: 1500 + t.at.minute),
        ...session('s2', 10, 9, set: 'b', day: 2),
      ], c);
      expect(r.state, MasteryState.mastered);
    });

    test('indicatori: acuratețe, independență, ajutor mediu, mediana latenței', () {
      final s = TrialStats.of([
        trial('s', latency: 1000),
        trial('s', prompt: PromptLevel.p2, latency: 3000),
        trial('s', correct: false, prompt: PromptLevel.p4, latency: 9000),
        trial('s', attempts: 2, latency: 2000),
      ]);
      expect(s.count, 4);
      expect(s.accuracy, 0.75);
      expect(s.independence, 0.25);
      expect(s.meanPrompt, 1.5);
      expect(s.medianLatencyMs, 2500);
    });
  });

  group('SkillRating (Elo)', () {
    test('probabilitatea: 50% la egalitate, ținta de 80% e sub rating', () {
      const r = SkillRating(1200);
      expect(r.expected(1200), closeTo(0.5, 1e-9));
      final d = r.targetDifficulty();
      expect(d, lessThan(1200));
      expect(r.expected(d), closeTo(0.8, 1e-9));
      expect(r.expected(r.targetDifficulty(0.9)), closeTo(0.9, 1e-9));
    });

    test('reușită grea urcă mult, greșeală ușoară coboară mult; ajutorul contează puțin', () {
      const r = SkillRating(1000, 50);
      final hard = r.update(1300, 1).value - 1000;
      final easy = r.update(1000, 1).value - 1000;
      expect(hard, greaterThan(easy));
      expect(r.update(700, 0).value - 1000, lessThan(r.update(1000, 0).value - 1000));
      final p0 = SkillRating.scoreOf(correct: true);
      final p3 = SkillRating.scoreOf(correct: true, prompt: PromptLevel.p3);
      final p4 = SkillRating.scoreOf(correct: true, prompt: PromptLevel.p4);
      expect(p0, 1);
      expect(p3, lessThan(0.5));
      expect(p4, 0);
      expect(SkillRating.scoreOf(correct: false), 0);
    });

    test('pasul scade cu numărul de încercări', () {
      expect(const SkillRating(1000, 0).k, greaterThan(const SkillRating(1000, 100).k));
    });

    test('converge spre abilitatea reală cu nivelurile țintite la 80%', () {
      // un copil simulat cu abilitate reală 1400, pornind de la 1000
      final rnd = Random(7);
      var r = const SkillRating();
      const truth = SkillRating(1400);
      var ok = 0;
      for (var i = 0; i < 400; i++) {
        final d = r.targetDifficulty();
        final correct = rnd.nextDouble() < truth.expected(d);
        if (i >= 200 && correct) ok++;
        r = r.update(d, correct ? 1 : 0);
      }
      expect(r.value, closeTo(1400, 120));
      expect(ok / 200, closeTo(0.8, 0.08)); // copilul chiar reușește ~80%
    });
  });

  group('DifficultyAxes', () {
    const axes = DifficultyAxes([
      AxisSpec('variante', [2, 3, 4, 5], weight: 300),
      AxisSpec('asemanare', [0, 1, 2, 3], weight: 400),
      AxisSpec('neidentic', [0, 1], weight: 200),
    ]);

    test('dificultatea crește monoton pe fiecare axă', () {
      for (final p in axes.grid()) {
        for (final a in axes.axes) {
          final i = a.values.indexOf(p[a.name]!);
          if (i + 1 < a.values.length) {
            expect(axes.difficultyOf({...p, a.name: a.values[i + 1]}), greaterThan(axes.difficultyOf(p)));
          }
        }
      }
    });

    test('treapta fixează și limitează axele', () {
      final g = axes.grid(fixed: {'neidentic': 0}, limits: {'variante': (3, 5)});
      expect(g, hasLength(3 * 4));
      expect(g.every((p) => p['neidentic'] == 0 && p['variante']! >= 3), isTrue);
      final (lo, hi) = axes.range(fixed: {'neidentic': 0}, limits: {'variante': (3, 5)});
      expect(lo, axes.base + 100);
      expect(hi, axes.base + 700);
      expect(() => axes.grid(limits: {'variante': (6, 9)}), throwsArgumentError);
      expect(() => axes.grid(fixed: {'variante': 7}), throwsArgumentError);
    });

    test('punctul ales e aproape de țintă, variat, și se limitează la capete', () {
      final rnd = Random(1);
      final target = axes.base + 450;
      final picks = {
        for (var i = 0; i < 50; i++) axes.pointFor(target, rnd).toString(),
      };
      expect(picks.length, greaterThan(1), reason: 'varietate');
      for (var i = 0; i < 50; i++) {
        expect((axes.difficultyOf(axes.pointFor(target, rnd)) - target).abs(), lessThanOrEqualTo(60));
      }
      expect(axes.pointFor(axes.base - 999, rnd), {'variante': 2, 'asemanare': 0, 'neidentic': 0});
      expect(axes.pointFor(axes.base + 9999, rnd), {'variante': 5, 'asemanare': 3, 'neidentic': 1});
    });
  });

  group('ExposureHistory + SpacedReview', () {
    test('combinația se recunoaște indiferent de ordinea distractorilor, nu și de așezare', () {
      final h = ExposureHistory();
      final k = ExposureHistory.keyOf('caine', ['pisica', 'minge'], ['minge', 'caine', 'pisica']);
      h.add(k, stimuli: ['caine', 'pisica', 'minge']);
      expect(h.seen(ExposureHistory.keyOf('caine', ['minge', 'pisica'], ['minge', 'caine', 'pisica'])), isTrue);
      expect(h.seen(ExposureHistory.keyOf('caine', ['minge', 'pisica'], ['caine', 'minge', 'pisica'])), isFalse);
      h.add('altceva', stimuli: ['minge']);
      expect(h.ago('caine'), 1);
      expect(h.ago('minge'), 0);
      expect(h.ago('elefant'), isNull);
    });

    test('capacitatea: cele mai vechi combinații se uită; JSON dus-întors', () {
      final h = ExposureHistory(capacity: 3);
      for (var i = 0; i < 5; i++) {
        h.add('k$i', stimuli: ['s$i']);
      }
      expect(h.seen('k0'), isFalse);
      expect(h.seen('k4'), isTrue);
      final back = ExposureHistory.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, Object?>);
      expect(back.seen('k2'), isTrue);
      expect(back.seen('k1'), isFalse);
      expect(back.ago('s3'), 1);
    });

    test('Leitner: greșit → revine mâine; reușitele îl mută la 3, 7, 30 de zile', () {
      final r = SpacedReview();
      r.record('caine', correct: true, now: t0);
      expect(r.boxOf('caine'), isNull, reason: 'reușit din prima: nu se repetă');
      r.record('caine', correct: false, now: t0);
      expect(r.due(t0), isEmpty);
      final d1 = t0.add(const Duration(days: 1));
      expect(r.due(d1), ['caine']);
      r.record('caine', correct: true, now: d1);
      expect(r.boxOf('caine'), 1);
      expect(r.due(d1.add(const Duration(days: 2))), isEmpty);
      expect(r.due(d1.add(const Duration(days: 3))), ['caine']);
      r.record('caine', correct: false, now: d1);
      expect(r.boxOf('caine'), 0);
      for (var i = 0; i < 3; i++) {
        r.record('caine', correct: true, now: d1);
      }
      expect(r.boxOf('caine'), 3);
      r.record('caine', correct: true, now: d1);
      expect(r.boxOf('caine'), isNull, reason: 'a trecut de 30 de zile: stăpânit');
    });
  });
}
