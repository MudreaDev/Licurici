import 'dart:math';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  for (final game in allGames) {
    group(game.id, () {
      for (final tier in [1, 3, 6, 20]) {
        test('tier $tier: runde valide', () {
          for (var seed = 0; seed < 30; seed++) {
            final ctx = GameContext(
                difficulty: Difficulty(tier), grade: game.grades.first, random: Random(seed));
            final lesson = game.build(ctx);
            expect(lesson.rounds, hasLength(ctx.difficulty.roundCount));
            for (final r in lesson.rounds) {
              expect(r.choices.where((c) => c.correct), hasLength(1));
              expect(r.choices, hasLength(ctx.difficulty.optionCount));
              final keys = r.choices.map((c) => '${c.label}|${c.art}|${c.color}').toSet();
              expect(keys, hasLength(r.choices.length), reason: 'variante duplicate');
              expect(r.speak, isNotEmpty);
            }
          }
        });
      }
    });
  }

  test('adunăm: răspunsul corect e suma, obiecte doar pentru sume mici', () {
    for (var seed = 0; seed < 50; seed++) {
      final ctx = GameContext(difficulty: const Difficulty(8), grade: Grade.clasa2, random: Random(seed));
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
    final ctx = GameContext(difficulty: const Difficulty(4), grade: Grade.clasa1, random: Random(1));
    for (final r in const NumaramGame().build(ctx).rounds) {
      final total = r.visuals.whereType<ObjectsVisual>().single.total;
      expect(r.choices.firstWhere((c) => c.correct).label, '$total');
    }
  });

  test('emoții: răspunsul corect nu are alături o emoție ușor de confundat', () {
    const confusable = {
      ('Fericit', 'Mândru'),
      ('Fericit', 'Calm'),
      ('Speriat', 'Surprins'),
      ('Obosit', 'Calm'),
    };
    for (var seed = 0; seed < 200; seed++) {
      final ctx = GameContext(difficulty: const Difficulty(10), grade: Grade.clasa1, random: Random(seed));
      for (final r in const EmotiiGame().build(ctx).rounds) {
        final correct = r.choices.firstWhere((c) => c.correct).label;
        final labels = r.choices.map((c) => c.label).toSet();
        for (final (a, b) in confusable) {
          if (correct == a) expect(labels, isNot(contains(b)), reason: 'corect $a, apare și $b');
          if (correct == b) expect(labels, isNot(contains(a)), reason: 'corect $b, apare și $a');
        }
      }
    }
  });

  test('gamesForGrade grupează pe materii', () {
    final g = gamesForGrade(Grade.gradinita);
    expect(g.keys, containsAll([Subject.matematica, Subject.forme, Subject.emotii]));
    expect(g[Subject.matematica]!.map((x) => x.id), isNot(contains('adunam')));
    expect(gameById('culori'), isA<CuloriGame>());
    expect(gameById('nu-exista'), isNull);
  });
}
