import 'dart:math';

import 'package:licurici_core/licurici_core.dart';
import 'package:licurici_core/src/games/content.dart' show ortograme, stories;
import 'package:test/test.dart';

void main() {
  for (final game in allGames) {
    group(game.id, () {
      for (final tier in [1, 3, 6, 20]) {
        test('tier $tier: runde valide', () {
          for (var seed = 0; seed < 30; seed++) {
            final ctx = GameContext(
              difficulty: Difficulty(tier),
              grade: game.grades.first,
              random: Random(seed),
            );
            final lesson = game.build(ctx);
            expect(lesson.rounds, hasLength(ctx.difficulty.roundCount));
            for (final r in lesson.rounds) {
              expect(r.choices.where((c) => c.correct), hasLength(1));
              // Variantele fixe (ex. grupele din „Comparăm”, Da/Nu) nu se taie după tier.
              if (!r.fixedChoices) {
                expect(r.choices, hasLength(ctx.difficulty.optionCount));
              }
              expect(r.choices.length, greaterThanOrEqualTo(2));
              final keys = r.choices
                  .map(
                    (c) => '${c.label}|${c.art}|${c.color}|${c.objects?.count}|${c.scale}',
                  )
                  .toSet();
              expect(
                keys,
                hasLength(r.choices.length),
                reason: 'variante duplicate',
              );
              expect(r.speak, isNotEmpty);
            }
          }
        });
      }
    });
  }

  test('adunăm: răspunsul corect e suma, obiecte doar pentru sume mici', () {
    for (var seed = 0; seed < 50; seed++) {
      final ctx = GameContext(
        difficulty: const Difficulty(8),
        grade: Grade.clasa2,
        random: Random(seed),
      );
      for (final r in const AdunamGame().build(ctx).rounds) {
        final eq = r.visuals.whereType<TextVisual>().single.text;
        final m = RegExp(r'(\d+) \+ (\d+)').firstMatch(eq)!;
        final sum = int.parse(m[1]!) + int.parse(m[2]!);
        expect(r.choices.firstWhere((c) => c.correct).label, '$sum');
        expect(r.visuals.whereType<ObjectsVisual>().isNotEmpty, sum <= 20);
      }
    }
  });

  test('numărăm: numărul corect = obiectele afișate', () {
    final ctx = GameContext(
      difficulty: const Difficulty(4),
      grade: Grade.clasa1,
      random: Random(1),
    );
    for (final r in const NumaramGame().build(ctx).rounds) {
      final total = r.visuals.whereType<ObjectsVisual>().single.total;
      expect(r.choices.firstWhere((c) => c.correct).label, '$total');
    }
  });

  test(
    'emoții: răspunsul corect nu are alături o emoție ușor de confundat',
    () {
      const confusable = {
        ('Fericit', 'Mândru'),
        ('Fericit', 'Calm'),
        ('Speriat', 'Surprins'),
        ('Obosit', 'Calm'),
      };
      for (var seed = 0; seed < 200; seed++) {
        final ctx = GameContext(
          difficulty: const Difficulty(10),
          grade: Grade.clasa1,
          random: Random(seed),
        );
        for (final r in const EmotiiGame().build(ctx).rounds) {
          final correct = r.choices.firstWhere((c) => c.correct).label;
          final labels = r.choices.map((c) => c.label).toSet();
          for (final (a, b) in confusable) {
            if (correct == a) {
              expect(
                labels,
                isNot(contains(b)),
                reason: 'corect $a, apare și $b',
              );
            }
            if (correct == b) {
              expect(
                labels,
                isNot(contains(a)),
                reason: 'corect $b, apare și $a',
              );
            }
          }
        }
      }
    },
  );

  test('Lesson.art adună ilustrațiile din variante și stimuli', () {
    final lesson = Lesson(
      title: 't',
      rounds: [
        ChoiceRound(
          prompt: 'p',
          visuals: const [
            EmojiVisual('😊'),
            ObjectsVisual([ObjectGroup('🍎', 2), ObjectGroup('🍎', 1)]),
            TextVisual('1 + 2'),
          ],
          choices: const [
            Choice(label: 'a', art: '🐶', correct: true),
            Choice(label: 'b'),
          ],
        ),
      ],
    );
    expect(lesson.art, {'😊', '🍎', '🐶'});
  });

  test(
    'comparăm: grupa cu mai multe obiecte e corectă; „la fel” doar la egalitate',
    () {
      for (var seed = 0; seed < 50; seed++) {
        final ctx = GameContext(
          difficulty: const Difficulty(4),
          grade: Grade.clasa1,
          random: Random(seed),
        );
        for (final r in const ComparamGame().build(ctx).rounds) {
          final a = r.choices[0].objects!.count;
          final b = r.choices[1].objects!.count;
          expect(r.choices.map((c) => c.correct).toList(), [
            a > b,
            b > a,
            a == b,
          ]);
        }
      }
    },
  );

  test('scădem: rezultatul e corect și nu e negativ', () {
    for (var seed = 0; seed < 50; seed++) {
      final ctx = GameContext(
        difficulty: const Difficulty(6),
        grade: Grade.clasa2,
        random: Random(seed),
      );
      for (final r in const ScademGame().build(ctx).rounds) {
        final m = RegExp(
          r'(\d+) − (\d+)',
        ).firstMatch(r.visuals.whereType<TextVisual>().single.text)!;
        final rest = int.parse(m[1]!) - int.parse(m[2]!);
        expect(rest, greaterThan(0));
        expect(r.choices.firstWhere((c) => c.correct).label, '$rest');
      }
    }
  });

  test('da/nu: exact jumătate „da”; Da e mereu în stânga', () {
    for (var seed = 0; seed < 30; seed++) {
      final ctx = GameContext(
        difficulty: const Difficulty(2),
        grade: Grade.gradinita,
        random: Random(seed),
      );
      final rounds = const DaNuGame().build(ctx).rounds;
      expect(rounds.map((r) => r.choices.first.label).toSet(), {'Da'});
      final yes = rounds.where((r) => r.choices.first.correct).length;
      expect(yes, rounds.length ~/ 2);
    }
  });

  test('alfabetul: litera corectă corespunde cuvântului', () {
    for (var seed = 0; seed < 50; seed++) {
      final ctx = GameContext(
        difficulty: const Difficulty(5),
        grade: Grade.clasa1,
        random: Random(seed),
      );
      for (final r in const AlfabetulGame().build(ctx).rounds) {
        if (r.prompt != 'Cu ce literă începe?') continue;
        final word = r.visuals.whereType<TextVisual>().single.text;
        final letter = r.choices.firstWhere((c) => c.correct).label!;
        expect(
          word.toUpperCase().startsWith(letter),
          isTrue,
          reason: '$word / $letter',
        );
      }
    }
  });

  test('gamesForGrade grupează pe materii', () {
    final g = gamesForGrade(Grade.gradinita);
    expect(
      g.keys,
      containsAll([Subject.matematica, Subject.forme, Subject.emotii]),
    );
    expect(g[Subject.matematica]!.map((x) => x.id), isNot(contains('adunam')));
    expect(gameById('culori'), isA<CuloriGame>());
    expect(gameById('nu-exista'), isNull);
  });

  test('scriem corect: variantele sunt perechea ortogramei, iar propoziția are un gol', () {
    for (var seed = 0; seed < 40; seed++) {
      final ctx = GameContext(difficulty: const Difficulty(6), grade: Grade.clasa3, random: Random(seed));
      for (final r in const OrtografieGame().build(ctx).rounds) {
        final labels = r.choices.map((c) => c.label).toSet();
        expect(ortograme.any((o) => labels.containsAll({o.a, o.b})), isTrue, reason: '$labels');
        final sentence = (r.visuals.single as SceneVisual).text;
        expect('___'.allMatches(sentence), hasLength(1));
        final answer = r.choices.firstWhere((c) => c.correct).label!;
        expect(r.speak.last, sentence.replaceAll('___', answer));
      }
    }
  });

  test('povești: pașii sunt în ordine, finalul e mereu inclus, nimic nu se pierde din poveste', () {
    for (final tier in [1, 3, 8]) {
      for (var seed = 0; seed < 30; seed++) {
        final ctx = GameContext(difficulty: Difficulty(tier), grade: Grade.clasa1, random: Random(seed));
        final lesson = const PovestiGame().build(ctx);
        final story = stories.firstWhere((s) => lesson.title.startsWith(s.title));
        final spoken = [for (final r in lesson.rounds) ...r.speak];
        final narrations = [for (final s in story.steps) s.narration];
        expect(spoken.where(narrations.contains).toList(), narrations);
        expect(lesson.rounds.last.prompt, story.steps.last.question);
      }
    }
  });
}
