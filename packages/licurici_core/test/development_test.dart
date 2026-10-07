import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

Trial _t(bool correct, {PromptLevel p = PromptLevel.p0, int attempts = 1, String set = 'a', int? ms}) =>
    Trial(
      stepId: 'EMO3',
      gameId: 'ce-simte',
      correct: correct,
      promptLevel: p,
      attempts: attempts,
      stimulusSet: set,
      latencyMs: ms,
      at: DateTime.utc(2026, 10, 1),
    );

void main() {
  group('trasee', () {
    test('id-urile treptelor sunt unice și aparțin ariei lor', () {
      final ids = <String>{};
      for (final l in ladders) {
        for (final s in l.steps) {
          expect(ids.add(s.id), isTrue, reason: 'treaptă duplicată ${s.id}');
          expect(s.domain, l.domain, reason: s.id);
        }
      }
    });

    test('fiecare joc din trasee există, iar fiecare joc are cel puțin o treaptă', () {
      final known = {...allGames.map((g) => g.id), ...reactionGames.map((g) => g.id), const SimonGame().id, const MemoryGame().id, const SortGame().id, const BreathingGame().id, const ShellGame().id, const TraceGame().id, const ImitationGame().id, const WaitGame().id, const SwitchGame().id, const SearchGame().id, const GazeGame().id, const AacGame().id, const RhythmGame().id, const FeedGame().id, const CauseGame().id, const ChangeGame().id, const PuzzleGame().id, const MazeGame().id, const SpotDiffGame().id, const BuildGame().id, const ShopGame().id, ...orderGames.map((g) => g.id), ...exploreEpisodes.map((e) => e.id)};
      for (final l in ladders) {
        for (final s in l.steps) {
          for (final g in s.games) {
            expect(known, contains(g), reason: '${s.id} → $g');
          }
        }
      }
      for (final id in known) {
        expect(stepsForGame(id), isNotEmpty, reason: 'jocul $id nu e legat de nicio treaptă');
      }
    });

    test('after() urcă pe traseu', () {
      expect(ladderFor(Domain.emo).after('EMO3')!.id, 'EMO4');
      expect(ladderFor(Domain.emo).after('EMO6'), isNull);
      expect(stepById('PAC-N4')!.domain, Domain.pac);
    });
  });

  group('PromptLadder', () {
    test('least-to-most: pornește de la P0 și urcă la greșeli și inactivitate, plafonat', () {
      const l = PromptLadder();
      final start = l.initial();
      expect(start, PromptLevel.p0);
      expect(l.current(start: start, wrongAttempts: 1), PromptLevel.p1);
      expect(l.current(start: start, idleMs: 10000), PromptLevel.p2);
      expect(l.current(start: start, wrongAttempts: 9), PromptLevel.p4);
      const capped = PromptLadder(maxLevel: PromptLevel.p2);
      expect(capped.current(start: start, wrongAttempts: 9), PromptLevel.p2);
    });

    test('most-to-least: ajutorul scade pe măsură ce copilul reușește singur', () {
      const l = PromptLadder(strategy: PromptStrategy.mostToLeast);
      expect(l.initial(), PromptLevel.p3);
      expect(l.initial(independentStreak: 2), PromptLevel.p1);
      expect(l.initial(independentStreak: 9), PromptLevel.p0);
      expect([0, 1, 2, 5].map((s) => l.delayMs(independentStreak: s)), [0, 2000, 4000, 4000]);
    });

    test('treaptă nouă → most-to-least; după 5 reușite independente → least-to-most', () {
      SessionRecord session(List<Trial> trials) => SessionRecord(
            id: 's',
            childId: 'c',
            start: DateTime(2026),
            end: DateTime(2026),
            trials: trials,
            events: const [],
          );
      Trial t(String game, {bool correct = true, PromptLevel p = PromptLevel.p0}) =>
          Trial(stepId: stepFor(game), gameId: game, correct: correct, promptLevel: p, at: DateTime(2026));
      expect(promptStrategyFor('adunam', const []), PromptStrategy.mostToLeast);
      // Cu ajutor sau greșit nu contează; nici alt joc, pe altă treaptă.
      final mixed = session([
        for (var i = 0; i < 4; i++) t('adunam'),
        t('adunam', p: PromptLevel.p3),
        t('adunam', correct: false),
        for (var i = 0; i < 9; i++) t('emotii'),
      ]);
      expect(promptStrategyFor('adunam', [mixed]), PromptStrategy.mostToLeast);
      expect(promptStrategyFor('adunam', [mixed, session([t('adunam')])]), PromptStrategy.leastToMost);
    });
  });

  group('TrialStats', () {
    test('independența cere corect + din prima + P0', () {
      final s = TrialStats([
        _t(true, ms: 1000),
        _t(true, p: PromptLevel.p2, ms: 3000),
        _t(true, attempts: 2, ms: 2000),
        _t(false),
      ]);
      expect(s.accuracy, 0.75);
      expect(s.independence, 0.25);
      expect(s.medianLatencyMs, 2000);
      expect(s.meanPromptLevel, 0.5);
    });
  });

  group('MasteryCriterion', () {
    List<Trial> session(int ok, int total, {String set = 'a'}) =>
        [for (var i = 0; i < total; i++) _t(i < ok, set: set)];

    test('2 sesiuni la rând ≥ 80% pe 2 seturi → stăpânit', () {
      final r = const MasteryCriterion()
          .evaluate([session(5, 10), session(9, 10, set: 'a'), session(8, 10, set: 'b')]);
      expect(r.mastered, isTrue);
      expect(r.sessionStreak, 2);
    });

    test('un singur set de stimuli → nu e generalizare, nu e stăpânit', () {
      final r = const MasteryCriterion().evaluate([session(9, 10), session(10, 10)]);
      expect(r.mastered, isFalse);
      expect(r.stimulusSets, 1);
    });

    test('sesiunile prea scurte nu contează', () {
      final r = const MasteryCriterion().evaluate([session(3, 3), session(3, 3, set: 'b')]);
      expect(r.mastered, isFalse);
      expect(r.lastIndependence, isNull);
    });
  });

  group('EloRating', () {
    const elo = EloRating();

    test('reușita crește rating-ul, greșeala îl scade, ajutorul reduce câștigul', () {
      final up = elo.update(1000, 1000, correct: true);
      final helped = elo.update(1000, 1000, correct: true, prompt: PromptLevel.p3);
      final down = elo.update(1000, 1000, correct: false);
      expect(up, greaterThan(1000));
      expect(helped, lessThan(up));
      expect(down, lessThan(1000));
    });

    test('ținta: ~80% șanse de reușită', () {
      final d = elo.targetDifficulty(1200);
      expect(elo.expected(1200, d), closeTo(0.8, 1e-9));
      expect(d, lessThan(1200));
    });

    test('nivelul urmează rating-ul și nu coboară sub 1', () {
      expect(elo.levelFor(400), 1);
      expect(elo.levelFor(1600), greaterThan(elo.levelFor(1300)));
    });
  });
}
