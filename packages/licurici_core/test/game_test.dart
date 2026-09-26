import 'dart:math';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

class _FakeGame extends GameSpec {
  const _FakeGame({this.fixed = false});

  final bool fixed;

  @override
  String get id => 'fake';
  @override
  String get name => 'Fake';
  @override
  String get emoji => '🧪';
  @override
  String get description => 'test';
  @override
  Subject get subject => Subject.forme;
  @override
  Set<Grade> get grades => Grade.values.toSet();
  @override
  Mechanic get mechanic => Mechanic.choice;
  @override
  bool get fixedRounds => fixed;

  @override
  Lesson generate(GameContext ctx) => Lesson(
    title: 'Test',
    rounds: [
      for (var i = 0; i < 10; i++)
        ChoiceRound(
          prompt: 'Runda $i',
          choices: [
            const Choice(label: 'corect', correct: true),
            for (var j = 0; j < 4; j++) Choice(label: 'greșit $j'),
          ],
        ),
    ],
  );
}

void main() {
  GameContext ctx(int tier) => GameContext(
    difficulty: Difficulty(tier),
    grade: Grade.clasa1,
    random: Random(42),
  );

  test('taie rundele și variantele după tier, păstrând corectul', () {
    for (var tier = 1; tier <= 8; tier++) {
      final c = ctx(tier);
      const game = _FakeGame();
      final lesson = scaleLesson(game.generate(c), game, c);
      expect(
        lesson.rounds.length,
        c.difficulty.roundCount,
        reason: 'tier $tier',
      );
      for (final r in lesson.rounds) {
        expect(
          r.choices.length,
          c.difficulty.optionCount,
          reason: 'tier $tier',
        );
        expect(r.choices.where((ch) => ch.correct).length, 1);
      }
    }
  });

  test('fixedRounds păstrează toate rundele', () {
    final c = ctx(1);
    const game = _FakeGame(fixed: true);
    expect(scaleLesson(game.generate(c), game, c).rounds.length, 10);
  });

  test('fixedChoices nu este tăiat', () {
    final c = ctx(1);
    final round = ChoiceRound(
      prompt: 'p',
      fixedChoices: true,
      choices: [
        const Choice(label: 'a', correct: true),
        const Choice(label: 'b'),
        const Choice(label: 'c'),
      ],
    );
    final lesson = scaleLesson(
      Lesson(title: 't', rounds: [round]),
      const _FakeGame(),
      c,
    );
    expect(lesson.rounds.single.choices.length, 3);
  });

  group('AdaptiveRule', () {
    const rule = AdaptiveRule();
    List<bool> results(int correct, int total) => [
      for (var i = 0; i < total; i++) i < correct,
    ];

    test('fereastră incompletă → păstrează', () {
      expect(rule.decide(results(0, 19)), AdaptiveDecision.keep);
    });
    test('< 60% → mai ușor', () {
      expect(rule.decide(results(11, 20)), AdaptiveDecision.easier);
    });
    test('60–90% → păstrează', () {
      expect(rule.decide(results(12, 20)), AdaptiveDecision.keep);
      expect(rule.decide(results(18, 20)), AdaptiveDecision.keep);
    });
    test('> 90% → mai greu', () {
      expect(rule.decide(results(19, 20)), AdaptiveDecision.harder);
      expect(rule.apply(const Difficulty(3), results(20, 20)).tier, 4);
    });
    test('folosește doar ultimele încercări', () {
      final history = [...List.filled(30, false), ...List.filled(20, true)];
      expect(rule.decide(history), AdaptiveDecision.harder);
    });
  });
}
